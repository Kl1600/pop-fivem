-- Boutique : catalogue (applis natives + applis des autres ressources visibles pour le métier), installation et retrait réels.
-- La liste `apps` de la tablette est la seule source : une appli retirée disparaît de l'accueil au prochain démarrage.

Tablet = Tablet or {}
Tablet.Store = {}
local Store = Tablet.Store

local MAX_APPS = 60

local function nativeAvailable(app)
    return not app.option or (Config.Apps or {})[app.option] ~= 'off'
end

--- Applis natives proposées sur ce serveur (Config.Apps = 'off' retire Dictaphone ou Traduire).
function Store.Natives()
    local out = {}
    for _, app in ipairs(Tablet.NativeApps) do
        if nativeAvailable(app) then out[#out + 1] = app end
    end
    return out
end

function Store.DefaultApps()
    local ids = {}
    for _, app in ipairs(Store.Natives()) do ids[#ids + 1] = app.id end
    return ids
end

local function jobOk(src, app)
    return app.jobs == nil or (src ~= nil and Bridge.HasJob(src, app.jobs) == true)
end

--- true si `id` est une appli que `src` a le droit d'avoir (native disponible, ou API visible pour son métier).
function Store.Allowed(src, id)
    local native = Tablet.NativeById[id]
    if native then return nativeAvailable(native) end
    local api = Tablet.Api and Tablet.Api.Get(id)
    return api ~= nil and jobOk(src, api)
end

--- Liste effective des applis installées : liste enregistrée (vide = valeurs par défaut) filtrée par droits,
--- applis système toujours présentes, applis API `store = false` installées d'office.
function Store.Resolve(src, saved)
    local out, seen = {}, {}
    local function add(id)
        if not seen[id] and Store.Allowed(src, id) then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    if type(saved) ~= 'table' or #saved == 0 then saved = Store.DefaultApps() end
    for _, id in ipairs(saved) do
        if type(id) == 'string' then add(id) end
    end
    for _, app in ipairs(Tablet.NativeApps) do
        if app.system then add(app.id) end
    end
    if Tablet.Api then
        for _, api in ipairs(Tablet.Api.List()) do
            if api.store == false then add(api.id) end
        end
    end
    return out
end

local function lang(s)
    local l = s and s.settings and s.settings.lang
    return Tablet.LanguageSet[l] and l or Config.Locale
end

--- Fiche d'une appli pour l'interface (les applis natives n'ont besoin que de leur id : le texte est dans l'interface).
local function entry(app, installed)
    return { id = app.id, cat = app.cat, system = app.system == true, installed = installed }
end

local function apiEntry(api, installed, language)
    return {
        id = api.id, api = true, name = Tablet.Api.NameOf(api, language), icon = api.icon, color = api.color, page = api.page,
        cat = api.category, installed = installed, system = false,
    }
end

--- Descripteurs des applis API installées, pour le démarrage.
function Store.ApiDescriptors(src, ids, s)
    local out, language = {}, lang(s)
    for _, id in ipairs(ids) do
        local api = Tablet.Api and Tablet.Api.Get(id)
        if api then out[#out + 1] = apiEntry(api, true, language) end
    end
    return out
end

--- pop_tablet:store:list
function Store.List(src)
    local s, err = Tablet.Guard(src, nil, { online = true, name = 'storeList', rate = 3 })
    if not s then return Tablet.Fail(err) end
    local installed = {}
    for _, id in ipairs(s.apps or {}) do installed[id] = true end
    local items, language = {}, lang(s)
    for _, app in ipairs(Store.Natives()) do items[#items + 1] = entry(app, installed[app.id] == true) end
    for _, api in ipairs(Tablet.Api and Tablet.Api.List() or {}) do
        if jobOk(src, api) and (api.store ~= false or installed[api.id]) then
            items[#items + 1] = apiEntry(api, installed[api.id] == true or api.store == false, language)
        end
    end
    return { ok = true, items = items }
end

local function change(src, appId, install)
    local s, err = Tablet.Guard(src, nil, { online = true, name = 'storeChange', rate = 3 })
    if not s then return Tablet.Fail(err) end
    if type(appId) ~= 'string' or #appId < 3 or #appId > 32 or not appId:match('^[a-z0-9_]+$') then return Tablet.Fail('err_payload') end
    if not Store.Allowed(src, appId) then
        return Tablet.Fail((Tablet.Api and Tablet.Api.Get(appId)) and 'wrong_job' or 'err_app_unknown')
    end
    local native = Tablet.NativeById[appId]
    local api = Tablet.Api and Tablet.Api.Get(appId)
    if not install and ((native and native.system) or (api and api.store == false)) then return Tablet.Fail('err_app_system') end
    local list, present = {}, false
    for _, id in ipairs(s.apps or {}) do
        if id == appId then present = true end
        if install or id ~= appId then list[#list + 1] = id end
    end
    if install and not present then
        if #list >= MAX_APPS then return Tablet.Fail('err_too_large') end
        list[#list + 1] = appId
    end
    if not (install and present) then Tablet.DB.SetApps(s.serial, list) end
    s.apps = list
    return { ok = true, apps = list }
end

--- pop_tablet:store:install / :remove
function Store.Install(src, appId) return change(src, appId, true) end
function Store.Remove(src, appId) return change(src, appId, false) end

Tablet.BootHooks[#Tablet.BootHooks + 1] = function(serial, boot)
    local src = Tablet.Device.SrcOf(serial)
    local s = src and Tablet.Device.GetSession(src) or nil
    local ids = Store.Resolve(src, boot.apps)
    boot.apps = ids
    boot.apiApps = Store.ApiDescriptors(src, ids, s)
    if s then s.apps = ids end
end

Callback.Register('pop_tablet:store:list', function(src) return Store.List(src) end)
Callback.Register('pop_tablet:store:install', function(src, appId) return Store.Install(src, appId) end)
Callback.Register('pop_tablet:store:remove', function(src, appId) return Store.Remove(src, appId) end)
