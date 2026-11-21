-- pop_inventory : arme en main, munitions, rechargement, durabilité.
-- Le serveur choisit l'arme et ses munitions ; le client ne remonte que les munitions consommées (en baisse).
-- Une boucle par frame existe seulement tant qu'une arme est en main.

local AMMO_READ_INTERVAL = 250      -- ms entre deux lectures des munitions
local AMMO_SEND_INTERVAL = 750      -- ms minimum entre deux envois (au-dessus du throttle serveur)
local EQUIP_GRACE = 1000            -- ms après l'équipement avant de vérifier que l'arme est toujours en main
local RELOAD_CONTROL = 45           -- R
-- NOTE: roue d'armes (37), sélection 1-5 du jeu (157, 158, 160, 164, 165) et changement d'arme à la molette
-- à pied (14, 15, 16, 17) et en véhicule (99, 100) : seul l'inventaire change l'arme en main.
local WHEEL_CONTROLS = { 37, 157, 158, 160, 164, 165, 14, 15, 16, 17, 99, 100 }
local UNARMED = joaat('WEAPON_UNARMED')

PopInv = PopInv or {}

local current = nil      -- { slot, name, hash, uhash, hasAmmo, ammo, pending, equippedAt }

-- Hash ramené en non signé 32 bits (joaat et les natives peuvent renvoyer l'un signé, l'autre non).
local function uhash(h)
    return (math.tointeger(h) or 0) & 0xFFFFFFFF
end
local loopRunning = false
local reloading = false

local function sendAmmo(w)
    if w.hasAmmo and w.pending then
        w.pending = false
        TriggerServerEvent('pop_inventory:server:updateWeapon', w.ammo)
    end
end

-- Retire l'arme du ped (sans event).
local function removeCurrent(ped)
    local w = current
    if not w then return end
    sendAmmo(w)
    current = nil
    RemoveWeaponFromPed(ped, w.hash)
    SetCurrentPedWeapon(ped, UNARMED, true)
end

--- Range l'arme en main. lostLocally = true : rangée par le client seul (mort, jeu), le serveur la croit encore en main.
function PopInv.Holster(lostLocally)
    if not current then return end
    local slot = current.slot
    removeCurrent(PlayerPedId())
    PopInv.lostWeapon = lostLocally and slot or nil
    PopInv.weapon = nil
    TriggerEvent('pop_inventory:currentWeapon', nil)
end

--- { slot, name, metadata } de l'arme en main, metadata lue dans le cache (à jour).
function PopInv.GetCurrentWeapon()
    if not current then return nil end
    local item = PopInv.inventory and PopInv.inventory.items[current.slot]
    return { slot = current.slot, name = current.name, metadata = item and item.metadata or {} }
end

local function requestReload()
    if reloading then return end
    reloading = true
    Callback.Trigger('pop_inventory:reload', function(ok, reason)
        reloading = false
        if not ok then PopInv.NotifyFail(reason) end
    end)
end

local function startLoop()
    if loopRunning then return end
    loopRunning = true
    CreateThread(function()
        local lastRead, lastSent = 0, 0
        while current do
            local w = current
            local ped = PlayerPedId()

            for i = 1, #WHEEL_CONTROLS do DisableControlAction(0, WHEEL_CONTROLS[i], true) end

            if IsEntityDead(ped) then
                PopInv.Holster(true)
                break
            end

            local now = GetGameTimer()
            if now - lastRead >= AMMO_READ_INTERVAL then
                lastRead = now
                if now - w.equippedAt >= EQUIP_GRACE and (not HasPedGotWeapon(ped, w.hash, false)
                    or (not IsPedInAnyVehicle(ped, false) and uhash(GetSelectedPedWeapon(ped)) ~= w.uhash)) then
                    -- Arme retirée ou changée par le jeu / un autre script.
                    PopInv.Holster(true)
                    break
                end
                if w.hasAmmo then
                    local ammo = GetAmmoInPedWeapon(ped, w.hash)
                    if ammo < w.ammo then
                        w.ammo = ammo
                        w.pending = true
                    elseif ammo > w.ammo then
                        -- Munitions ajoutées hors inventaire (ramassage) : refusées.
                        SetPedAmmo(ped, w.hash, w.ammo)
                    end
                    if w.pending and now - lastSent >= AMMO_SEND_INTERVAL then
                        lastSent = now
                        sendAmmo(w)
                    end
                end
            end

            if w.hasAmmo and w.ammo <= 0 and IsControlJustPressed(0, RELOAD_CONTROL) then
                requestReload()
            end

            Wait(0)
        end
        loopRunning = false
    end)
end

--- Équipe l'arme décidée par le serveur : { slot, name, ammo, durability }.
function PopInv.EquipWeapon(weapon)
    if type(weapon) ~= 'table' or type(weapon.name) ~= 'string' then return end
    local ped = PlayerPedId()
    removeCurrent(ped)

    local name = weapon.name:lower()
    local hash = joaat(name:upper())
    local def = PopInv.items[name]
    local ammo = math.tointeger(tonumber(weapon.ammo) or 0) or 0
    if ammo < 0 then ammo = 0 end

    GiveWeaponToPed(ped, hash, 0, false, true)
    SetPedAmmo(ped, hash, ammo)
    SetCurrentPedWeapon(ped, hash, true)

    current = {
        slot = math.tointeger(tonumber(weapon.slot) or 0),
        name = name,
        hash = hash,
        uhash = uhash(hash),
        hasAmmo = def ~= nil and def.ammo ~= nil,
        ammo = ammo,
        pending = false,
        equippedAt = GetGameTimer(),
    }
    PopInv.lostWeapon = nil
    PopInv.weapon = PopInv.GetCurrentWeapon()
    TriggerEvent('pop_inventory:currentWeapon', PopInv.weapon)
    startLoop()
end

RegisterNetEvent('pop_inventory:client:useWeapon', function(weapon)
    PopInv.EquipWeapon(weapon)
end)

RegisterNetEvent('pop_inventory:client:holster', function()
    PopInv.Holster(false)
end)

RegisterNetEvent('pop_inventory:client:setAmmo', function(ammo)
    local w = current
    ammo = math.tointeger(tonumber(ammo) or -1)
    if not w or not ammo or ammo < 0 then return end
    local ped = PlayerPedId()
    w.ammo = ammo
    w.pending = false
    SetPedAmmo(ped, w.hash, ammo)
    MakePedReload(ped)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local w = current
    if w then
        current = nil
        RemoveWeaponFromPed(PlayerPedId(), w.hash)
    end
end)
