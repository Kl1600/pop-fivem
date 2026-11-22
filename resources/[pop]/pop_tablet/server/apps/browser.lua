-- Navigateur : sites en jeu (RegisterSite, en mémoire : une ressource les redéclare à chaque démarrage), signets et historique
-- propres à la tablette. Un site s'affiche dans un cadre isolé (iframe sandbox) ; les liens externes passent par
-- Config.Browser.AllowedHosts. Aucune boucle, aucun polling.

Tablet = Tablet or {}
Tablet.Browser = Tablet.Browser or {} -- les limites viennent de shared/tablet.lua
local B = Tablet.Browser

local sites, order = {}, {}  -- [domaine] = { domain, title, page, resource }
local DOMAIN = '^[a-z0-9][a-z0-9%.%-]*$'

--- Déclare un site `pop://<domain>`. Mêmes règles de page que RegisterApp. Renvoie true, ou false + raison.
function B.RegisterSite(def, resource)
    if type(def) ~= 'table' or type(resource) ~= 'string' or resource == '' then return false, 'bad_definition' end
    local d = def.domain
    if type(d) ~= 'string' or #d < 3 or #d > 60 or not d:match(DOMAIN) or d:find('%.%.') then return false, 'bad_domain' end
    if type(def.title) ~= 'string' or #def.title < 1 or #def.title > Tablet.Browser.title then return false, 'bad_title' end
    local old = sites[d]
    if old and old.resource ~= resource then return false, 'domain_taken' end
    if not Tablet.Api.PageValid(def.page, resource) then return false, 'bad_page' end
    if not old then order[#order + 1] = d end
    sites[d] = { domain = d, title = def.title, page = def.page, resource = resource }
    return true
end

function B.UnregisterSite(domain, resource)
    local old = sites[domain]
    if not old or old.resource ~= resource then return false end
    sites[domain] = nil
    for i, v in ipairs(order) do if v == domain then table.remove(order, i) break end end
    return true
end

function B.UnregisterResource(resource)
    for _, d in ipairs({ table.unpack(order) }) do
        if sites[d] and sites[d].resource == resource then B.UnregisterSite(d, resource) end
    end
end

local function cleanList(list, max)
    local out = {}
    if type(list) ~= 'table' then return out end
    for _, e in ipairs(list) do
        if #out >= max then break end
        if type(e) == 'table' and type(e.url) == 'string' and #e.url >= 1 and #e.url <= Tablet.Browser.url and not e.url:find('[%c<>"\\]') then
            local title = type(e.title) == 'string' and e.title:sub(1, Tablet.Browser.title) or ''
            out[#out + 1] = { url = e.url, title = title }
        end
    end
    return out
end

--- pop_tablet:browser:sites : sites en jeu, hôtes externes autorisés, signets et historique de la tablette
function B.Sites(src)
    local s, err = Tablet.Guard(src, nil, { name = 'browserSites', rate = 3, online = true })
    if not s then return Tablet.Fail(err) end
    local list = {}
    for _, d in ipairs(order) do local x = sites[d] list[#list + 1] = { domain = x.domain, title = x.title, page = x.page } end
    local hosts = {}
    for _, h in ipairs((Config.Browser and Config.Browser.AllowedHosts) or {}) do if type(h) == 'string' then hosts[#hosts + 1] = h end end
    local d = Tablet.AppData.Get(s.serial, 'browser', {})
    return { ok = true, sites = list, hosts = hosts, bookmarks = cleanList(d.bookmarks, Tablet.Browser.bookmarks), history = cleanList(d.history, Tablet.Browser.history) }
end

--- pop_tablet:browser:save  { bookmarks?, history? } : signets (50) et historique (50) de la tablette
function B.Save(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'browserSave', rate = 2, payload = data, maxBytes = 12288 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local old = Tablet.AppData.Get(s.serial, 'browser', {})
    local out = {
        bookmarks = data.bookmarks ~= nil and cleanList(data.bookmarks, Tablet.Browser.bookmarks) or cleanList(old.bookmarks, Tablet.Browser.bookmarks),
        history = data.history ~= nil and cleanList(data.history, Tablet.Browser.history) or cleanList(old.history, Tablet.Browser.history),
    }
    if not Tablet.AppData.Set(s.serial, 'browser', out) then return Tablet.Fail('err_too_large') end
    return { ok = true }
end

Callback.Register('pop_tablet:browser:sites', function(src) return B.Sites(src) end)
Callback.Register('pop_tablet:browser:save', function(src, data) return B.Save(src, data) end)

exports('RegisterSite', function(def) return B.RegisterSite(def, GetInvokingResource()) end)
exports('UnregisterSite', function(domain) return B.UnregisterSite(domain, GetInvokingResource()) end)
AddEventHandler('onResourceStop', function(resource) B.UnregisterResource(resource) end)
