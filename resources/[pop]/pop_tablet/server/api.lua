-- Exports serveur : RegisterApp, UnregisterApp, Notify, OpenApp, AppEvent, GetSerial, GetApiVersion (docs/api-applis.md).
-- Aucune boucle : le registre est un tableau en mémoire, les applis API ne coûtent rien au repos.

Tablet = Tablet or {}
Tablet.Api = {}
local Api = Tablet.Api

local APP_ID = '^[a-z0-9_]+$'
local NOTIFY_PER_SECOND = 5

local registry = {}   -- [id] = définition validée (avec .resource, .onCall)
local order = {}      -- ids dans l'ordre d'enregistrement

function Api.Get(id) return registry[id] end

function Api.List()
    local out = {}
    for _, id in ipairs(order) do out[#out + 1] = registry[id] end
    return out
end

local function validId(id)
    return type(id) == 'string' and #id >= 3 and #id <= 32 and id:match(APP_ID) ~= nil
end

local function hostAllowed(host)
    for _, h in ipairs((Config.Browser and Config.Browser.AllowedHosts) or {}) do
        if h == host then return true end
    end
    return false
end

--- La page doit venir de la ressource appelante (nui://<ressource>/...) ou d'un hôte https de Config.Browser.AllowedHosts.
function Api.PageValid(page, resource)
    if type(page) ~= 'string' or #page > 200 or page:find('[%s"\'<>\\]') then return false end
    if page:sub(1, #resource + 7) == 'nui://' .. resource .. '/' and #page > #resource + 7 and not page:find('%.%.') then return true end
    local host = page:match('^https://([%w%.%-]+)[/:]?') or page:match('^https://([%w%.%-]+)$')
    return host ~= nil and hostAllowed(host)
end

--- Nom affiché dans la langue : texts[lang][nameKey], sinon anglais, sinon `name`, sinon l'id.
function Api.NameOf(def, lang)
    local texts = def.texts
    if def.nameKey and type(texts) == 'table' then
        local t = type(texts[lang]) == 'table' and texts[lang][def.nameKey] or nil
        if type(t) ~= 'string' and type(texts.en) == 'table' then t = texts.en[def.nameKey] end
        if type(t) == 'string' then return t end
    end
    return def.name or def.id
end

local function validJobs(jobs)
    if jobs == nil then return true end
    if type(jobs) == 'string' then return #jobs <= 32 end
    if type(jobs) ~= 'table' or not Tablet.Limits.Payload(jobs, 512) then return false end
    for k, v in pairs(jobs) do
        if type(k) == 'number' then
            if type(v) ~= 'string' then return false end
        elseif type(k) ~= 'string' or type(v) ~= 'number' then
            return false
        end
    end
    return true
end

--- Valide et enregistre une appli. Renvoie true, ou false + raison.
function Api.Register(def, resource)
    if type(def) ~= 'table' or type(resource) ~= 'string' or resource == '' then return false, 'bad_definition' end
    if not validId(def.id) then return false, 'bad_id' end
    if Tablet.NativeById[def.id] then return false, 'id_taken' end
    local old = registry[def.id]
    if old and old.resource ~= resource then return false, 'id_taken' end
    if def.name == nil and def.nameKey == nil then return false, 'bad_name' end
    if def.name ~= nil and (type(def.name) ~= 'string' or #def.name > 40 or #def.name == 0) then return false, 'bad_name' end
    if def.nameKey ~= nil and (type(def.nameKey) ~= 'string' or #def.nameKey > 48) then return false, 'bad_name' end
    if def.texts ~= nil and (type(def.texts) ~= 'table' or not Tablet.Limits.Payload(def.texts, 4096)) then return false, 'bad_texts' end
    if not Api.PageValid(def.page, resource) then return false, 'bad_page' end
    if def.icon ~= nil and (type(def.icon) ~= 'string' or #def.icon > 120 or def.icon:find('[%s"\'<>\\]')) then return false, 'bad_icon' end
    if def.color ~= nil and (type(def.color) ~= 'string' or not def.color:match('^#%x%x%x%x%x%x$')) then return false, 'bad_color' end
    if def.category ~= nil and (type(def.category) ~= 'string' or not def.category:match('^[a-z]+$') or #def.category > 16) then return false, 'bad_category' end
    if not validJobs(def.jobs) then return false, 'bad_jobs' end
    if def.onCall ~= nil and type(def.onCall) ~= 'function' and type(def.onCall) ~= 'table' then return false, 'bad_oncall' end
    local entry = {
        id = def.id, resource = resource, name = def.name, nameKey = def.nameKey, texts = def.texts,
        icon = def.icon, color = def.color, page = def.page, jobs = def.jobs, store = def.store ~= false,
        category = def.category or 'work', onCall = def.onCall,
    }
    if not old then order[#order + 1] = def.id end
    registry[def.id] = entry
    return true
end

--- Retire une appli (ressource propriétaire seulement). Prévient les tablettes ouvertes.
function Api.Unregister(id, resource)
    local old = registry[id]
    if not old or old.resource ~= resource then return false end
    registry[id] = nil
    for i, v in ipairs(order) do
        if v == id then table.remove(order, i) break end
    end
    Api.BroadcastApps()
    return true
end

function Api.UnregisterResource(resource)
    local gone = false
    for i = #order, 1, -1 do
        if registry[order[i]].resource == resource then
            registry[order[i]] = nil
            table.remove(order, i)
            gone = true
        end
    end
    if gone then Api.BroadcastApps() end
    return gone
end

--- Dit aux tablettes ouvertes que le catalogue a changé : l'interface relit `store:list`.
function Api.BroadcastApps()
    for _, src in ipairs(Tablet.Device.Sources()) do Tablet.Push.To(src, 'apps', {}) end
end

------------------------------------------------------------------------
-- OpenApp
------------------------------------------------------------------------

--- Demande au client `src` d'ouvrir la tablette sur l'appli `appId`. Le code reste exigé : aucun contournement.
--- L'appli doit exister et être permise à son métier ; l'installation est revérifiée par l'interface et par `app:call`.
local function openApp(src, appId, data)
    if not validId(appId) then return false end
    if data ~= nil and not Tablet.Limits.Payload(data, 2048) then return false end
    if not Bridge.GetPlayer(src) or not Tablet.Device.HasTablet(src) then return false end
    if Tablet.Store and not Tablet.Store.Allowed(src, appId) then return false end
    return (Tablet.Push.To(src, 'open', { app = appId, data = data }, true))
end

------------------------------------------------------------------------
-- Notify
------------------------------------------------------------------------

local function resolveText(texts, key, lang)
    if type(texts) ~= 'table' then return nil end
    local t = type(texts[lang]) == 'table' and texts[lang][key] or nil
    if type(t) ~= 'string' and type(texts.en) == 'table' then t = texts.en[key] end
    return type(t) == 'string' and t or nil
end

local function fill(text, args)
    if type(args) ~= 'table' then return text end
    local i = 0
    return (text:gsub('%%[sd]', function(m)
        i = i + 1
        return args[i] ~= nil and tostring(args[i]) or m
    end))
end

--- Notification venue d'une autre ressource. Renvoie true si une tablette (ou le joueur) a été prévenue.
function Api.Notify(target, n, resource)
    if type(n) ~= 'table' then return false end
    if not Tablet.Limits.Rate('res:' .. tostring(resource), 'notify', NOTIFY_PER_SECOND) then return false end
    local app = n.app
    if type(app) ~= 'string' or not validId(app) then return false end
    local registered = registry[app]
    if registered and registered.resource ~= resource then return false end
    if not registered and not Tablet.NativeById[app] then return false end
    local src
    if type(target) == 'string' then src = Tablet.Device.SrcOf(target) else src = tonumber(target) end
    if not src or not Bridge.GetPlayer(src) or not Tablet.Device.HasTablet(src) then return false end
    local s = Tablet.Device.GetSession(src)
    if type(target) == 'string' and (not s or s.serial ~= target) then return false end
    local lang = s and s.settings and s.settings.lang
    if not Tablet.LanguageSet[lang] then lang = Config.Locale end
    local args = type(n.args) == 'table' and n.args or nil
    if args and #args > 4 then return false end
    local title = n.titleKey and resolveText(n.texts, n.titleKey, lang) or n.title
    local body = n.bodyKey and resolveText(n.texts, n.bodyKey, lang) or n.body
    if type(title) ~= 'string' then title = registered and Api.NameOf(registered, lang) or nil end
    if body ~= nil and type(body) ~= 'string' then return false end
    title, body = title and fill(title, args), fill(body or '', args)
    if (title and #title > 60) or #body > 200 then return false end
    if s and s.settings and type(s.settings.notif) == 'table' and s.settings.notif[app] == false then return false end
    if s then
        return (Tablet.Push.To(src, 'notify', { app = app, title = title, text = body, sound = n.sound == true or nil }))
    end
    -- Tablette fermée (aucune session) : notification du jeu, la tablette ne peut rien afficher.
    Bridge.Notify(src, (title and body ~= '') and (title .. ' : ' .. body) or (title or body), 'info')
    return true
end

------------------------------------------------------------------------
-- Appel de l'appli vers sa ressource, événements vers la page
------------------------------------------------------------------------

local function installed(s, id)
    for _, v in ipairs(s.apps or {}) do
        if v == id then return true end
    end
    return false
end

--- pop_tablet:app:call : routage vers la ressource propriétaire ; elle revérifie ses propres règles.
function Api.Call(src, data)
    local s, err = Tablet.Guard(src, nil, { payload = data, maxBytes = 4096, name = 'appCall', rate = 10 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' or not validId(data.appId) or type(data.action) ~= 'string' or #data.action > 32
        or not data.action:match('^[%w_.%-]+$') then
        return Tablet.Fail('err_payload')
    end
    local app = registry[data.appId]
    if not app or not app.onCall then return Tablet.Fail('err_app_unknown') end
    if not installed(s, app.id) then return Tablet.Fail('err_app_unknown') end
    if app.jobs ~= nil and not Bridge.HasJob(src, app.jobs) then return Tablet.Fail('wrong_job') end
    local ok, res = pcall(app.onCall, src, s.serial, data.action, data.data)
    if not ok then
        if Config.Debug then print(('[pop_tablet] onCall %s: %s'):format(app.id, tostring(res))) end
        return Tablet.Fail('error')
    end
    if res == nil then res = {} end
    if type(res) ~= 'table' or not Tablet.Limits.Payload(res, 16384) then return Tablet.Fail('err_too_large') end
    return { ok = true, data = res }
end

--- pop_tablet:app:focus : l'interface dit quelle appli API est au premier plan (nil = aucune).
function Api.Focus(src, appId)
    local s, err = Tablet.Guard(src, nil, { name = 'appFocus', rate = 5 })
    if not s then return Tablet.Fail(err) end
    if appId ~= nil and (not validId(appId) or not registry[appId]) then return Tablet.Fail('err_payload') end
    s.current = appId
    return { ok = true }
end

--- Événement vers la page d'une appli ouverte (ressource propriétaire seulement, paquet <= 1 Ko).
function Api.Event(src, appId, name, data, resource)
    local app = registry[appId]
    if not app or app.resource ~= resource or type(name) ~= 'string' or #name > 32 then return false end
    local s = Tablet.Device.GetSession(tonumber(src))
    if not s or s.current ~= appId then return false end
    return (Tablet.Push.To(tonumber(src), 'appEvent', { appId = appId, name = name, data = data }))
end

exports('GetApiVersion', function() return 1 end)
exports('GetSerial', function(src) return Tablet.Device.SerialOf(src) end)
exports('OpenApp', function(src, appId, data) return openApp(tonumber(src), appId, data) end)
exports('RegisterApp', function(def) return Api.Register(def, GetInvokingResource()) end)
exports('UnregisterApp', function(id) return Api.Unregister(id, GetInvokingResource()) end)
exports('Notify', function(target, n) return Api.Notify(target, n, GetInvokingResource()) end)
exports('AppEvent', function(src, appId, name, data) return Api.Event(src, appId, name, data, GetInvokingResource()) end)

-- Appel du client (export client OpenApp) : mêmes contrôles, anti-spam en plus.
Callback.Register('pop_tablet:app:open', function(src, appId, data)
    if not Tablet.Limits.Rate(src, 'appOpen', 2) then return false end
    return openApp(src, appId, data)
end)
Callback.Register('pop_tablet:app:call', function(src, data) return Api.Call(src, data) end)
Callback.Register('pop_tablet:app:focus', function(src, appId) return Api.Focus(src, appId) end)

-- Une ressource qui s'arrête voit ses applis retirées.
AddEventHandler('onResourceStop', function(resource) Api.UnregisterResource(resource) end)
