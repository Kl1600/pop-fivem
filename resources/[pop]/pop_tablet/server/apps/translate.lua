-- Traduire : le dictionnaire hors ligne est dans l'interface (l'appli n'est jamais masquée). Ici : service HTTP optionnel
-- (Config.Translate.Url), cache en mémoire, limites, et favoris par tablette. La clé du service vient de la convar serveur
-- `pop_tablet_translate_key` et n'est envoyée qu'à l'adresse configurée.

Tablet = Tablet or {}
Tablet.Translate = {}
local T = Tablet.Translate
local K = Tablet.Tools

local cache, cacheCount = {}, 0
local FAV_CHARS = 200

local function text(v, max)
    if type(v) ~= 'string' then return nil end
    local len = utf8.len(v)
    if not len or len < 1 or len > max then return nil end
    for i = 1, #v do
        local b = v:byte(i)
        if b == 127 or (b < 32 and b ~= 10) then return nil end
    end
    return v
end

local function languages(src, dst)
    return Tablet.Limits.Enum(src, Tablet.LanguageSet) and Tablet.Limits.Enum(dst, Tablet.LanguageSet) and src ~= dst
end

--- Appel du service : renvoie le texte traduit, ou nil. Aucune réponse n'est crue au-delà d'un texte de 2000 caractères.
local function request(cfg, source, q, dst)
    local body = { q = q, source = source, target = dst, format = 'text' }
    local key = GetConvar('pop_tablet_translate_key', '')
    if key ~= '' then body.api_key = key end
    local p, done = promise.new(), false
    local function finish(status, resp)
        if done then return end
        done = true
        p:resolve({ status, resp })
    end
    PerformHttpRequest(cfg.Url, function(status, resp) finish(status, resp) end, 'POST', json.encode(body), { ['Content-Type'] = 'application/json' })
    SetTimeout((cfg.TimeoutSeconds or 8) * 1000, function() finish(0, '') end)
    local res = Citizen.Await(p)
    if res[1] ~= 200 or type(res[2]) ~= 'string' then return nil end
    local ok, doc = pcall(json.decode, res[2])
    if not ok or type(doc) ~= 'table' or type(doc.translatedText) ~= 'string' or #doc.translatedText > 2000 then return nil end
    return doc.translatedText
end

--- pop_tablet:translate:run  { text, src, dst } : service configuré seulement (sinon err_unavailable, l'interface reste hors ligne)
function T.Run(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'translate', rate = 1, payload = data, maxBytes = 2048, online = true })
    if not s then return Tablet.Fail(err) end
    local cfg = Config.Translate or {}
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local q = text(data.text, cfg.MaxChars or K.translateChars)
    if not q or not languages(data.src, data.dst) then return Tablet.Fail('err_payload') end
    if type(cfg.Url) ~= 'string' or not cfg.Url:match('^https?://') then return Tablet.Fail('err_unavailable') end
    local k = data.src .. '|' .. data.dst .. '|' .. q
    if cache[k] then return { ok = true, text = cache[k], cached = true } end
    local out = request(cfg, data.src, q, data.dst)
    if not out then return Tablet.Fail('err_unavailable') end
    if cacheCount >= (cfg.CacheSize or 200) then cache, cacheCount = {}, 0 end
    cache[k] = out
    cacheCount = cacheCount + 1
    return { ok = true, text = out, cached = false }
end

local function loadFavs(serial)
    local out = {}
    for _, f in ipairs(Tablet.AppData.Get(serial, 'translate', {}).favs or {}) do
        if type(f) == 'table' and languages(f.src, f.dst) and text(f.s, FAV_CHARS) and text(f.t, FAV_CHARS) and #out < K.translateFavs then
            out[#out + 1] = { src = f.src, dst = f.dst, s = f.s, t = f.t }
        end
    end
    return out
end

--- pop_tablet:translate:favs
function T.Favs(src)
    local s, err = Tablet.Guard(src, nil, { name = 'translateFavs', rate = 4 })
    if not s then return Tablet.Fail(err) end
    return { ok = true, items = loadFavs(s.serial) }
end

--- pop_tablet:translate:fav  { src, dst, s, t, on }
function T.Fav(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'translateFav', rate = 3, payload = data, maxBytes = 2048 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or type(data.on) ~= 'boolean' or not languages(data.src, data.dst)
        or not text(data.s, FAV_CHARS) or not text(data.t, FAV_CHARS) then
        return Tablet.Fail('err_payload')
    end
    local out = {}
    for _, f in ipairs(loadFavs(s.serial)) do
        if not (f.src == data.src and f.dst == data.dst and f.s == data.s) then out[#out + 1] = f end
    end
    if data.on then
        if #out >= K.translateFavs then return Tablet.Fail('err_limit') end
        out[#out + 1] = { src = data.src, dst = data.dst, s = data.s, t = data.t }
    end
    if not Tablet.AppData.Set(s.serial, 'translate', { favs = out }) then return Tablet.Fail('err_too_large') end
    return { ok = true, items = out }
end

Callback.Register('pop_tablet:translate:run', function(src, data) return T.Run(src, data) end)
Callback.Register('pop_tablet:translate:favs', function(src) return T.Favs(src) end)
Callback.Register('pop_tablet:translate:fav', function(src, data) return T.Fav(src, data) end)
