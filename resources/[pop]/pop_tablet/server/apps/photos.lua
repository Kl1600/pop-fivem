-- Photos : prise de vue côté serveur (mode 'database'), photothèque, favoris, notes en étoiles, filtres, albums, corbeille.
-- Sert à l'Appareil photo, à Photos et à « Enregistrement » du centre de contrôle.
-- Le serveur demande la capture à screencapture (export serveur serverCapture) ; aucune clé ni URL d'envoi ne passe par le client.
-- Avec `crop` (zone du viseur, fractions 0..1) : capture pleine résolution renvoyée à l'interface avec un jeton à usage unique ;
-- l'interface recadre, ré-encode puis rend l'image par `photos:save` (le serveur ne l'enregistre qu'à ce moment).

Tablet = Tablet or {}
Tablet.Photos = {}
local P = Tablet.Photos

local MAX_BYTES = 150 * 1024 -- texte base64 de la capture
local SHOT_GAP = 3           -- secondes entre deux prises
local WAIT_MS = 10000
local PAGE = 30
local MAX_ID = 4294967295
local RAW_MAX = 3 * 1024 * 1024 -- capture brute (avant recadrage) renvoyée à l'interface
local TOKEN_TTL = 30            -- secondes de validité du jeton de recadrage
local CROP_MIN = 0.05
local CROP_EPS = 1e-6

local lastShot = {} -- [src] = seconde
local pending = {}  -- [src] = { token, serial, kind, exp } : un seul jeton en attente par joueur

local function photoId(v) return Tablet.Limits.Int(v, 1, MAX_ID) end

--- true si `img` est une image en data URI webp, jpeg ou png (base64 strict). Tout le reste (svg, html, autre type) est refusé.
function P.ImageValid(img)
    if type(img) ~= 'string' then return false end
    local mime = img:match('^data:image/(%a+);base64,[%w%+/=]+$')
    return mime == 'webp' or mime == 'jpeg' or mime == 'png'
end

--- Identifiant d'une charge `id` seul ou `{ id = ... }`.
local function idOf(data)
    if type(data) == 'table' then return photoId(data.id) end
    return photoId(data)
end

local function finite(v) return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge end

--- Zone de recadrage `{ x, y, w, h }` en fractions de la fenêtre : nombres finis, x,y >= 0, w,h > 0,05, x+w <= 1, y+h <= 1.
--- Renvoie la zone nettoyée (4 champs seulement) ou nil.
function P.CropValid(c)
    if type(c) ~= 'table' then return nil end
    local x, y, w, h = c.x, c.y, c.w, c.h
    if not (finite(x) and finite(y) and finite(w) and finite(h)) then return nil end
    if x < 0 or y < 0 or w <= CROP_MIN or h <= CROP_MIN then return nil end
    if x + w > 1 + CROP_EPS or y + h > 1 + CROP_EPS then return nil end
    return { x = x, y = y, w = w, h = h }
end

local function newToken()
    local chars, t = 'abcdefghijklmnopqrstuvwxyz0123456789', {}
    for i = 1, 24 do
        local k = math.random(#chars)
        t[i] = chars:sub(k, k)
    end
    return table.concat(t)
end

--- pop_tablet:photos:capture  { kind? = 'photo' | 'square' | 'portrait' | 'pano', crop? = { x, y, w, h } }
--- Sans `crop` : capture réduite (960) enregistrée directement { ok, id }. Avec `crop` : { ok, token, img, crop, kind },
--- rien n'est enregistré avant `photos:save`.
function P.Capture(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'photoCapture', rate = 2, payload = data, maxBytes = 384 })
    if not s then return Tablet.Fail(err) end
    local kind = 'photo'
    local crop
    if type(data) == 'table' and data.kind ~= nil then
        if not (type(data.kind) == 'string' and Tablet.Media.photoKinds[data.kind]) then return Tablet.Fail('err_payload') end
        kind = data.kind
    end
    if type(data) == 'table' and data.crop ~= nil then
        crop = P.CropValid(data.crop)
        if not crop then return Tablet.Fail('err_payload') end
    end
    if Config.Photos.Mode ~= 'database' then return Tablet.Fail('err_unavailable') end
    local now = Tablet.Now()
    if lastShot[src] and now - lastShot[src] < SHOT_GAP then return Tablet.Fail('err_rate') end
    if GetResourceState('screencapture') ~= 'started' then return Tablet.Fail('err_unavailable') end
    if Tablet.DB.CountPhotos(s.serial) >= Config.Photos.Max then return Tablet.Fail('err_photos_full') end
    lastShot[src] = now

    local p = promise.new()
    -- Recadrage demandé : capture pleine résolution, la qualité doit survivre au recadrage côté interface.
    local opts = crop and { encoding = 'webp', maxWidth = 1920, maxHeight = 1080 } or { encoding = 'webp', maxWidth = 960 }
    exports.screencapture:serverCapture(src, opts, function(img) p:resolve(img) end)
    SetTimeout(WAIT_MS, function() p:resolve(nil) end)
    local img = Citizen.Await(p)

    if type(img) ~= 'string' or img == '' then return Tablet.Fail('err_unavailable') end
    if #img > (crop and RAW_MAX or MAX_BYTES) then return Tablet.Fail('err_too_large') end
    if not P.ImageValid(img) then return Tablet.Fail('err_unavailable') end
    -- La session peut avoir disparu pendant l'attente : la photo n'est enregistrée que pour la tablette encore portée.
    if not Tablet.Device.GetSession(src) or Tablet.Device.SerialOf(src) ~= s.serial or not Tablet.Device.Carries(src, s.serial) then
        return Tablet.Fail('err_session')
    end
    if crop then
        local token = newToken()
        pending[src] = { token = token, serial = s.serial, kind = kind, exp = Tablet.Now() + TOKEN_TTL }
        return { ok = true, token = token, img = img, crop = crop, kind = kind }
    end
    local id = Tablet.DB.InsertPhoto(s.serial, img, Tablet.Now(), kind)
    return { ok = true, id = id }
end

--- pop_tablet:photos:save  { token, img } : image recadrée par l'interface, enregistrée si le jeton de la prise est valide.
--- Le jeton est lié au joueur et à la tablette, expire en 30 s et ne sert qu'une fois (consommé dès qu'il est présenté).
function P.Save(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'photoSave', rate = 2, payload = data, maxBytes = MAX_BYTES + 512 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or type(data.token) ~= 'string' or type(data.img) ~= 'string' then return Tablet.Fail('err_payload') end
    local tk = pending[src]
    if not tk or tk.token ~= data.token then return Tablet.Fail('err_payload') end
    pending[src] = nil
    if Tablet.Now() > tk.exp then return Tablet.Fail('err_payload') end
    if tk.serial ~= s.serial then return Tablet.Fail('err_session') end
    if #data.img > MAX_BYTES then return Tablet.Fail('err_too_large') end
    if not P.ImageValid(data.img) then return Tablet.Fail('err_payload') end
    if not Tablet.Device.Carries(src, s.serial) then return Tablet.Fail('err_session') end
    if Tablet.DB.CountPhotos(s.serial) >= Config.Photos.Max then return Tablet.Fail('err_photos_full') end
    return { ok = true, id = Tablet.DB.InsertPhoto(s.serial, data.img, Tablet.Now(), tk.kind) }
end

local function flag(v) return v == 1 or v == true end

--- pop_tablet:photos:list  { scope = 'all' | 'fav' | 'trash' | 'album', albumId?, offset? }
--- 30 vignettes par page ; la première page porte aussi les compteurs et les albums.
function P.List(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'photoList', rate = 6, payload = data, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    data = type(data) == 'table' and data or {}
    local scope = data.scope or 'all'
    if scope ~= 'all' and scope ~= 'fav' and scope ~= 'trash' and scope ~= 'album' then return Tablet.Fail('err_payload') end
    local offset = data.offset == nil and 0 or Tablet.Limits.Int(data.offset, 0, Config.Photos.Max)
    if not offset then return Tablet.Fail('err_payload') end
    local albumId
    if scope == 'album' then
        albumId = photoId(data.albumId)
        if not albumId or not Tablet.DB.AlbumOwned(s.serial, albumId) then return Tablet.Fail('err_not_found') end
    end
    if scope == 'trash' and offset == 0 then
        Tablet.DB.PurgePhotoTrash(s.serial, Tablet.Now() - Tablet.Media.trashDays * 86400)
    end
    local rows = Tablet.DB.ListPhotos(s.serial, scope, albumId, offset, PAGE)
    local items = {}
    for i, r in ipairs(rows) do
        items[i] = { id = r.id, kind = r.kind, rating = r.rating, fav = flag(r.favorite), fx = r.fx, taken = r.taken_at, thumb = r.thumb }
    end
    local res = { ok = true, items = items, more = #rows == PAGE }
    if offset == 0 then
        res.counts = Tablet.DB.PhotoCounts(s.serial)
        local albums = {}
        for i, a in ipairs(Tablet.DB.ListAlbums(s.serial)) do albums[i] = { id = a.id, name = a.name, n = tonumber(a.n) or 0 } end
        res.albums = albums
    end
    return res
end

--- pop_tablet:photos:get  id -> la photo entière (data URI) avec ses albums
function P.Get(src, id)
    local s, err = Tablet.Guard(src, nil, { name = 'photoGet', rate = 10, payload = id, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    id = idOf(id)
    if not id then return Tablet.Fail('err_payload') end
    local r = Tablet.DB.GetPhoto(s.serial, id)
    if not r then return Tablet.Fail('err_not_found') end
    return { ok = true, photo = { id = r.id, data = r.data, kind = r.kind, rating = r.rating, fav = flag(r.favorite), fx = r.fx,
        taken = r.taken_at, deleted = r.deleted_at ~= nil, albums = Tablet.DB.PhotoAlbums(r.id) } }
end

--- Si la photo supprimée servait de fond d'écran, le fond repasse en automatique.
local function resetWallpaper(s, id)
    local st = s.settings
    if type(st) == 'table' and st.wall == 'photo:' .. id then
        local merged = {}
        for k, v in pairs(st) do merged[k] = v end
        merged.wall = 'auto'
        Tablet.DB.SetSettings(s.serial, merged)
        s.settings = merged
        return true
    end
    return false
end

--- pop_tablet:photos:delete  id : première fois = corbeille, deuxième fois (déjà en corbeille) = suppression définitive
function P.Delete(src, id)
    local s, err = Tablet.Guard(src, nil, { name = 'photoDelete', rate = 5, payload = id, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    id = idOf(id)
    if not id then return Tablet.Fail('err_payload') end
    local r = Tablet.DB.GetPhoto(s.serial, id)
    if not r then return Tablet.Fail('err_not_found') end
    if r.deleted_at == nil then
        Tablet.DB.SetPhotoDeleted(s.serial, id, Tablet.Now())
        return { ok = true, permanent = false }
    end
    Tablet.DB.DeletePhoto(s.serial, id)
    return { ok = true, permanent = true, wallReset = resetWallpaper(s, id) }
end

--- pop_tablet:photos:restore  id
function P.Restore(src, id)
    local s, err = Tablet.Guard(src, nil, { name = 'photoDelete', rate = 5, payload = id, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    id = idOf(id)
    if not id or not Tablet.DB.PhotoOwned(s.serial, id) then return Tablet.Fail('err_not_found') end
    Tablet.DB.SetPhotoDeleted(s.serial, id, nil)
    return { ok = true }
end

--- pop_tablet:photos:favorite  id | { id, on? } (sans `on`, bascule)
function P.Favorite(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'photoEdit', rate = 6, payload = data, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    local id = idOf(data)
    if not id then return Tablet.Fail('err_payload') end
    local r = Tablet.DB.GetPhoto(s.serial, id)
    if not r then return Tablet.Fail('err_not_found') end
    local on = not flag(r.favorite)
    if type(data) == 'table' and data.on ~= nil then
        if type(data.on) ~= 'boolean' then return Tablet.Fail('err_payload') end
        on = data.on
    end
    Tablet.DB.SetPhotoField(s.serial, id, 'favorite', on and 1 or 0)
    return { ok = true, fav = on }
end

--- pop_tablet:photos:rate  { id, rating 0-5 }
function P.Rate(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'photoEdit', rate = 6, payload = data, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local id, rating = idOf(data), Tablet.Limits.Int(data.rating, 0, 5)
    if not id or not rating then return Tablet.Fail('err_payload') end
    if not Tablet.DB.SetPhotoField(s.serial, id, 'rating', rating) and not Tablet.DB.PhotoOwned(s.serial, id) then return Tablet.Fail('err_not_found') end
    return { ok = true, rating = rating }
end

--- pop_tablet:photos:filter  { id, fx = 'none' | 'vivid' | 'mono' | 'drama' | 'sepia' }
function P.Filter(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'photoEdit', rate = 6, payload = data, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local id = idOf(data)
    if not id or type(data.fx) ~= 'string' or not Tablet.Media.photoFx[data.fx] then return Tablet.Fail('err_payload') end
    if not Tablet.DB.SetPhotoField(s.serial, id, 'fx', data.fx) and not Tablet.DB.PhotoOwned(s.serial, id) then return Tablet.Fail('err_not_found') end
    return { ok = true, fx = data.fx }
end

--- pop_tablet:photos:thumb  { id, data } : vignette produite par l'interface (data URI image <= 24 Ko)
function P.Thumb(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'photoThumb', rate = 20, payload = data, maxBytes = Tablet.Media.thumbBytes + 512 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local id, img = idOf(data), data.data
    if not id or type(img) ~= 'string' or #img > Tablet.Media.thumbBytes then return Tablet.Fail('err_too_large') end
    if not P.ImageValid(img) then return Tablet.Fail('err_payload') end
    if not Tablet.DB.SetPhotoField(s.serial, id, 'thumb', img) and not Tablet.DB.PhotoOwned(s.serial, id) then return Tablet.Fail('err_not_found') end
    return { ok = true }
end

--- pop_tablet:photos:albums
function P.Albums(src)
    local s, err = Tablet.Guard(src, nil, { name = 'photoList', rate = 6 })
    if not s then return Tablet.Fail(err) end
    local albums = {}
    for i, a in ipairs(Tablet.DB.ListAlbums(s.serial)) do albums[i] = { id = a.id, name = a.name, n = tonumber(a.n) or 0 } end
    return { ok = true, albums = albums }
end

--- pop_tablet:photos:albumSave  { id?, name } : création (<= 20 albums) ou renommage
function P.AlbumSave(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'albumSave', rate = 3, payload = data, maxBytes = 512 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or type(data.name) ~= 'string' then return Tablet.Fail('err_payload') end
    local name = Tablet.Limits.Trim(data.name)
    if not Tablet.Limits.Field('folder', name, { min = 1 }) then return Tablet.Fail('err_payload') end
    if data.id ~= nil then
        local id = photoId(data.id)
        if not id or not Tablet.DB.RenameAlbum(s.serial, id, name) then return Tablet.Fail('err_not_found') end
        return { ok = true, id = id, name = name }
    end
    if Tablet.DB.CountAlbums(s.serial) >= Tablet.Media.albums then return Tablet.Fail('err_limit') end
    return { ok = true, id = Tablet.DB.InsertAlbum(s.serial, name, Tablet.Now()), name = name }
end

--- pop_tablet:photos:albumDelete  id : l'album disparaît, pas ses photos
function P.AlbumDelete(src, id)
    local s, err = Tablet.Guard(src, nil, { name = 'albumSave', rate = 3, payload = id, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    id = idOf(id)
    if not id or not Tablet.DB.DeleteAlbum(s.serial, id) then return Tablet.Fail('err_not_found') end
    return { ok = true }
end

--- pop_tablet:photos:albumLink  { albumId, photoId, on } : l'album et la photo doivent appartenir à la tablette
function P.AlbumLink(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'albumSave', rate = 6, payload = data, maxBytes = 256 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or type(data.on) ~= 'boolean' then return Tablet.Fail('err_payload') end
    local albumId, pid = photoId(data.albumId), photoId(data.photoId)
    if not albumId or not pid then return Tablet.Fail('err_payload') end
    if not Tablet.DB.AlbumOwned(s.serial, albumId) or not Tablet.DB.PhotoOwned(s.serial, pid) then return Tablet.Fail('err_not_found') end
    Tablet.DB.AlbumLink(albumId, pid, data.on)
    return { ok = true }
end

--- Photo d'une tablette pour un module voisin (Fichiers) : true si elle lui appartient.
function P.Owned(serial, id)
    id = photoId(id)
    return id ~= nil and Tablet.DB.PhotoOwned(serial, id)
end

Bridge.OnPlayerDropped(function(src) lastShot[src] = nil; pending[src] = nil end)

Callback.Register('pop_tablet:photos:capture', function(src, data) return P.Capture(src, data) end)
Callback.Register('pop_tablet:photos:save', function(src, data) return P.Save(src, data) end)
Callback.Register('pop_tablet:photos:list', function(src, data) return P.List(src, data) end)
Callback.Register('pop_tablet:photos:get', function(src, id) return P.Get(src, id) end)
Callback.Register('pop_tablet:photos:delete', function(src, id) return P.Delete(src, id) end)
Callback.Register('pop_tablet:photos:restore', function(src, id) return P.Restore(src, id) end)
Callback.Register('pop_tablet:photos:favorite', function(src, data) return P.Favorite(src, data) end)
Callback.Register('pop_tablet:photos:rate', function(src, data) return P.Rate(src, data) end)
Callback.Register('pop_tablet:photos:filter', function(src, data) return P.Filter(src, data) end)
Callback.Register('pop_tablet:photos:thumb', function(src, data) return P.Thumb(src, data) end)
Callback.Register('pop_tablet:photos:albums', function(src) return P.Albums(src) end)
Callback.Register('pop_tablet:photos:albumSave', function(src, data) return P.AlbumSave(src, data) end)
Callback.Register('pop_tablet:photos:albumDelete', function(src, id) return P.AlbumDelete(src, id) end)
Callback.Register('pop_tablet:photos:albumLink', function(src, data) return P.AlbumLink(src, data) end)
