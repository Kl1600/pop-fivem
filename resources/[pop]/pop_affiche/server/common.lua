-- Fonctions communes du serveur pop_affiche (chargé en premier, voir fxmanifest).

Affiche = {}

-- ESX direct : groupe du joueur (getGroup) pour le statut VIP. À passer par le bridge
-- au moment du multi-framework.
function Affiche.IsPlayerVIP(src)
    local xPlayer = ESX and ESX.GetPlayerFromId(src)
    if not xPlayer then return false end

    if Config.VIPCheckMethod == 'group' then
        if Config.VIPGroups[xPlayer.getGroup()] then
            return true
        end
    elseif Config.VIPCheckMethod == 'custom' then
        -- Écrivez votre propre logique de vérification VIP ici
        -- Exemple : champ 'vip' dans la table 'users'
        -- return xPlayer.get('vip') == 1 or xPlayer.get('vip') == true
        return false
    end

    return false
end

-- Notification d'erreur ox_lib (style d'origine de ce script, gardé tel quel)
function Affiche.NotifyError(src, message)
    TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = message })
end

function Affiche.Debug(msg, ...)
    if Config.Debug then print(msg:format(...)) end
end

local lastAction = {}  -- [src] = GetGameTimer() du dernier enregistrement/suppression

function Affiche.OnCooldown(src)
    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < Config.ActionCooldown then return true end
    lastAction[src] = now
    return false
end

AddEventHandler('playerDropped', function() lastAction[source] = nil end)

function Affiche.IsVec(t)
    return type(t) == 'table' and type(t.x) == 'number' and type(t.y) == 'number' and type(t.z) == 'number'
        and t.x == t.x and t.y == t.y and t.z == t.z
end

-- Lien d'image : http(s) seulement, sans espace ni guillemet ni chevron
function Affiche.CleanUrl(url)
    if type(url) ~= 'string' or url == '' or #url > 2048 then return nil end
    if not url:match('^https?://[%w%-%.]+') then return nil end
    if url:find('[%s"\'<>`\\]') then return nil end
    return url
end

function Affiche.PlayerNear(src, p)
    return Bridge.IsNear(src, p, Config.MaxDistance)
end

function Affiche.GetRow(dbId)
    local ok, row = pcall(function() return MySQL.single.await('SELECT * FROM pop_affiche WHERE id = ?', { dbId }) end)
    if not ok or not row then return nil end
    if type(row.pos) == 'string' then row.pos = json.decode(row.pos) end
    if type(row.normal) == 'string' then row.normal = json.decode(row.normal) end
    return row
end
