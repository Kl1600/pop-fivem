-- Adaptateur armes : seul fichier qui appelle directement un inventaire (le Bridge ne gère pas les armes).
-- Mode 'metadata' (ox_inventory, pop_inventory) : munitions dans la métadonnée `ammo` de l'arme-item.
-- Mode 'native' (tous les autres) : munitions du ped, ajoutées par le client après validation serveur.

-- NOTE: pop_inventory doit exposer GetCurrentWeapon et SetMetadata comme ox_inventory (exports serveur).
-- Format attendu de GetCurrentWeapon(src) (ox_inventory et pop_inventory) :
-- { slot, name, count, metadata, label, weight } ; seuls slot, name et metadata.ammo sont utilisés ici.

Weapons = {}
Weapons.Mode = (Bridge.Inventory == 'ox_inventory' or Bridge.Inventory == 'pop_inventory') and 'metadata' or 'native'

local RES = GetCurrentResourceName()
local warned = {} -- [nom de fonction] = true : un seul log par fonction

-- Log console unique par fonction (anglais) quand l'inventaire n'expose pas l'API attendue.
local function warnUnsupported(fn, err)
    if warned[fn] then return end
    warned[fn] = true
    print(('[%s] %s:%s failed (export missing or error): %s'):format(RES, Bridge.Inventory, fn, tostring(err)))
end

-- Appel protégé de exports[inventaire]:GetCurrentWeapon(src). Renvoie ok, item brut.
local function readCurrent(src)
    local inv = Bridge.Inventory
    local ok, res = pcall(function() return exports[inv]:GetCurrentWeapon(src) end)
    if not ok then warnUnsupported('GetCurrentWeapon', res) end
    return ok, res
end

--- Arme-item en main (mode metadata) : { slot = int, name = 'WEAPON_PISTOL', ammo = int, metadata = table }
--- ou nil, reason ('not_supported' si l'export manque ; nil si pas d'arme ou arme sans munitions).
function Weapons.GetCurrent(src)
    if Weapons.Mode ~= 'metadata' then return nil, 'not_supported' end
    local ok, item = readCurrent(src)
    if not ok then return nil, 'not_supported' end
    if type(item) ~= 'table' or type(item.name) ~= 'string' then return nil end

    local slot = math.tointeger(tonumber(item.slot))
    local md = type(item.metadata) == 'table' and item.metadata or nil
    local ammo = md and math.tointeger(tonumber(md.ammo))
    -- Arme sans munitions (mêlée, lancer) ou slot inconnu : rien à recharger.
    if not slot or not ammo then return nil end

    return { slot = slot, name = item.name:upper(), ammo = math.max(0, ammo), metadata = md }
end

--- Fixe les munitions de l'arme-item au slot donné (mode metadata).
--- Renvoie ok, attempted : ok = valeur bien écrite (relue) ; attempted = false si rien n'a été envoyé à l'inventaire.
function Weapons.SetAmmo(src, slot, ammo)
    if Weapons.Mode ~= 'metadata' then return false, false end
    ammo = math.tointeger(tonumber(ammo))
    if not ammo or ammo < 0 then return false, false end

    -- Relit l'arme pour récupérer la métadonnée complète : seul `ammo` change.
    local w = Weapons.GetCurrent(src)
    if not w or w.slot ~= slot then return false, false end
    local md = {}
    for k, v in pairs(w.metadata) do md[k] = v end
    md.ammo = ammo

    local inv = Bridge.Inventory
    local ok, err = pcall(function() return exports[inv]:SetMetadata(src, slot, md) end)
    if not ok then
        warnUnsupported('SetMetadata', err)
        return false, true
    end

    -- NOTE: ox_inventory:SetMetadata ne renvoie rien ; on vérifie en relisant l'arme (lecture synchrone en mémoire).
    local check = Weapons.GetCurrent(src)
    return check ~= nil and check.slot == slot and check.ammo == ammo, true
end

-- Test au démarrage (mode metadata) : les exports attendus existent-ils ? Avertissement console sinon.
-- NOTE: indexer un export absent lève une erreur ("No such export") : le pcall suffit, rien n'est appelé.
if Weapons.Mode == 'metadata' then
    CreateThread(function()
        local inv = Bridge.Inventory
        local timeout = GetGameTimer() + 10000
        while GetResourceState(inv) ~= 'started' and GetGameTimer() < timeout do Wait(500) end
        for _, fn in ipairs({ 'GetCurrentWeapon', 'SetMetadata' }) do
            local ok, export = pcall(function() return exports[inv][fn] end)
            if not ok or export == nil then
                warnUnsupported(fn, 'export not found at startup: magazines will answer "not_supported"')
            end
        end
    end)
end
