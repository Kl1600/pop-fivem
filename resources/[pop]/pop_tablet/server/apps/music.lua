-- Musique : radios et flux de Config.Music.Stations (lus par un élément audio dans la page de la tablette), favoris et listes de
-- lecture propres à la tablette. Le serveur ne diffuse rien et ne tourne pas : il valide la config, range les listes et retient
-- ce qui joue (en mémoire de session) pour le centre de contrôle. La lecture continue tablette fermée côté page, sans Lua.

Tablet = Tablet or {}
Tablet.Music = {}
local M = Tablet.Music
local ML = Tablet.MusicLimits

--- Stations valides de la config (https, nom 40 caractères), avec un identifiant stable `s<n>` = rang dans la config.
function M.Stations()
    local out = {}
    for i, st in ipairs((Config.Music and Config.Music.Stations) or {}) do
        if type(st) == 'table' and type(st.name) == 'string' and #st.name >= 1 and utf8.len(st.name) and utf8.len(st.name) <= ML.name
            and type(st.url) == 'string' and st.url:match('^https://[%w%.%-]+[:/%w%._%-%?=&%%~]*$') and #st.url <= 300 then
            out[#out + 1] = { id = 's' .. i, name = st.name, url = st.url, tag = type(st.tag) == 'string' and st.tag:sub(1, 12) or nil }
        end
    end
    return out
end

local function stationIds()
    local set = {}
    for _, st in ipairs(M.Stations()) do set[st.id] = true end
    return set
end

local function cleanIds(list, set, max)
    local out, seen = {}, {}
    if type(list) ~= 'table' then return out end
    for _, id in ipairs(list) do
        if #out >= max then break end
        if type(id) == 'string' and set[id] and not seen[id] then seen[id] = true out[#out + 1] = id end
    end
    return out
end

--- pop_tablet:music:stations : stations, favoris et listes de lecture de la tablette
function M.List(src)
    local s, err = Tablet.Guard(src, nil, { name = 'musicList', rate = 3, online = true })
    if not s then return Tablet.Fail(err) end
    local stations = M.Stations()
    local set = stationIds()
    local d = Tablet.AppData.Get(s.serial, 'music', {})
    local lists = {}
    for _, pl in ipairs(type(d.playlists) == 'table' and d.playlists or {}) do
        if type(pl) == 'table' and type(pl.name) == 'string' and #lists < ML.playlists then lists[#lists + 1] = { name = pl.name:sub(1, ML.name * 4), ids = cleanIds(pl.ids, set, ML.perList) } end
    end
    return { ok = true, stations = stations, favs = cleanIds(d.favs, set, ML.favs), playlists = lists }
end

--- pop_tablet:music:save  { favs?, playlists? } : favoris (30) et listes de lecture (10 de 50 stations)
function M.Save(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'musicSave', rate = 2, payload = data, maxBytes = 4096 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local set = stationIds()
    local old = Tablet.AppData.Get(s.serial, 'music', {})
    local out = { favs = old.favs or {}, playlists = old.playlists or {} }
    if data.favs ~= nil then out.favs = cleanIds(data.favs, set, ML.favs) end
    if data.playlists ~= nil then
        if type(data.playlists) ~= 'table' or #data.playlists > ML.playlists then return Tablet.Fail('err_limit') end
        local lists = {}
        for _, pl in ipairs(data.playlists) do
            if type(pl) ~= 'table' then return Tablet.Fail('err_payload') end
            local ok, ferr = Tablet.Limits.Field('folder', pl.name, { min = 1 })
            if not ok then return Tablet.Fail(ferr) end
            lists[#lists + 1] = { name = pl.name, ids = cleanIds(pl.ids, set, ML.perList) }
        end
        out.playlists = lists
    end
    if not Tablet.AppData.Set(s.serial, 'music', out) then return Tablet.Fail('err_too_large') end
    return { ok = true }
end

--- pop_tablet:music:state  { title?, artist?, playing } : retenu en mémoire de session (centre de contrôle à la réouverture)
function M.State(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'musicState', rate = 2, payload = data, maxBytes = 512 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or type(data.playing) ~= 'boolean' then return Tablet.Fail('err_payload') end
    for _, k in ipairs({ 'title', 'artist' }) do
        if data[k] ~= nil and not Tablet.Limits.Field('title', data[k]) then return Tablet.Fail('err_payload') end
    end
    s.music = data.title and { title = data.title, artist = data.artist or '', playing = data.playing } or nil
    return { ok = true }
end

Tablet.BootHooks[#Tablet.BootHooks + 1] = function(serial, boot)
    local src = Tablet.Device.SrcOf(serial)
    local s = src and Tablet.Device.GetSession(src)
    if s and s.music then boot.music = s.music end
end

Callback.Register('pop_tablet:music:stations', function(src) return M.List(src) end)
Callback.Register('pop_tablet:music:save', function(src, data) return M.Save(src, data) end)
Callback.Register('pop_tablet:music:state', function(src, data) return M.State(src, data) end)
