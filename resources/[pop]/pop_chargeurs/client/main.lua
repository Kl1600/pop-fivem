-- pop_chargeurs : client. Aucune boucle, tout se passe à l'utilisation d'un chargeur.
-- Le client ne décide de rien : il vérifie par confort, le serveur valide et retire le chargeur.

local UNARMED = joaat('WEAPON_UNARMED') & 0xFFFFFFFF

-- Hash non signé : joaat et les natives peuvent renvoyer des valeurs signées.
local function hash(h)
    return (tonumber(h) or 0) & 0xFFFFFFFF
end

-- compatible[item][hash] = true
local compatible = {}
for item, mag in pairs(Config.Magazines or {}) do
    local list = {}
    for _, weapon in ipairs(mag.weapons or {}) do
        list[hash(joaat(weapon))] = true
    end
    compatible[item] = list
end

local reloading = false

local function maxAmmo(ped, weapon)
    local _, max = GetMaxAmmo(ped, weapon)
    max = tonumber(max) or 0
    if max <= 0 then return Config.MaxAmmo end
    return math.min(Config.MaxAmmo, max)
end

local function reload(item)
    local list = compatible[item]
    if not list or reloading or Bridge.IsBusy() then return end

    local ped = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    local weaponHash = hash(weapon)

    if weaponHash == UNARMED then
        return Bridge.Notify(L('no_weapon'), 'error')
    end
    if not list[weaponHash] then
        return Bridge.Notify(L('wrong_weapon'), 'error')
    end

    local current = GetAmmoInPedWeapon(ped, weapon)
    if current >= maxAmmo(ped, weapon) then
        return Bridge.Notify(L('ammo_full'), 'error')
    end

    reloading = true

    local done = Bridge.Progress(L('reloading'), Config.ReloadTime, {
        disableMovement = false,
        disableCombat = true,
    })

    ped = PlayerPedId()
    if not done or hash(GetSelectedPedWeapon(ped)) ~= weaponHash then
        reloading = false
        return
    end

    local ok, reason, amount, total = Callback.Await('pop_chargeurs:reload', item, current)

    if ok then
        ped = PlayerPedId()
        if hash(GetSelectedPedWeapon(ped)) == weaponHash then
            if total ~= nil then
                SetPedAmmo(ped, weapon, math.floor(tonumber(total) or 0))
            else
                AddAmmoToPed(ped, weapon, math.floor(tonumber(amount) or 0))
            end
            MakePedReload(ped)
        end
    else
        Bridge.Notify(L(reason or 'error', amount), 'error')
    end

    reloading = false
end

RegisterNetEvent('pop_chargeurs:client:reload', function(item)
    if type(item) ~= 'string' then return end
    CreateThread(function() reload(item) end)
end)
