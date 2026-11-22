local hasWeaponEquipped = false
local hasBoxEquipped = false
local hasSafeEquipped = false

local function isPlayerHoldingBriefcase()
    local ped = PlayerPedId()
    local weaponHash = GetHashKey('weapon_briefcase_02')
    return HasPedGotWeapon(ped, weaponHash, false)
end

local function equipBriefcaseWeapon(force)
    if hasWeaponEquipped and not force then
        return
    end

    local ped = PlayerPedId()
    local weaponHash = GetHashKey('weapon_briefcase_02')

    if not HasPedGotWeapon(ped, weaponHash, false) then
        GiveWeaponToPed(ped, weaponHash, 0, false, true)
        SetCurrentPedWeapon(ped, weaponHash, true)
    end

    hasWeaponEquipped = true
end

local function removeBriefcaseWeapon()
    if not hasWeaponEquipped then
        return
    end

    local ped = PlayerPedId()
    local weaponHash = GetHashKey('weapon_briefcase_02')

    RemoveWeaponFromPed(ped, weaponHash)

    hasWeaponEquipped = false
end

local function equipCardboardBox()
    if hasBoxEquipped then
        return
    end

    TriggerEvent('pop_inventory:client:equipCardboardBox')
    hasBoxEquipped = true
end

local function removeCardboardBox()
    if not hasBoxEquipped then
        return
    end

    TriggerEvent('pop_inventory:client:unequipCardboardBox')
    hasBoxEquipped = false
end

local function equipSafe()
    if hasSafeEquipped then
        return
    end

    TriggerEvent('pop_inventory:client:equipSafe')
    hasSafeEquipped = true
end

local function removeSafe()
    if not hasSafeEquipped then
        return
    end

    TriggerEvent('pop_inventory:client:unequipSafe')
    hasSafeEquipped = false
end

RegisterNetEvent('pop_inventory:client:applyEquipment', function(equipment)
    local briefcaseItem = equipment and equipment.briefcase

    local defId = briefcaseItem
    if type(briefcaseItem) == 'table' then
        defId = briefcaseItem.defId
    end

    -- Check what's equipped in briefcase slot
    if defId == 'briefcase' then
        if not hasWeaponEquipped or not isPlayerHoldingBriefcase() then
            equipBriefcaseWeapon(true)
        end
        if hasBoxEquipped then
            removeCardboardBox()
        end
        if hasSafeEquipped then
            removeSafe()
        end
    elseif defId == 'cardboard_box' then
        if hasWeaponEquipped then
            removeBriefcaseWeapon()
        end
        if not hasBoxEquipped then
            equipCardboardBox()
        end
        if hasSafeEquipped then
            removeSafe()
        end
    elseif defId == 'safe' then
        if hasWeaponEquipped then
            removeBriefcaseWeapon()
        end
        if hasBoxEquipped then
            removeCardboardBox()
        end
        if not hasSafeEquipped then
            equipSafe()
        end
    elseif defId == 'brancard' then
        if hasWeaponEquipped then
            removeBriefcaseWeapon()
        end
        if hasBoxEquipped then
            removeCardboardBox()
        end
        if hasSafeEquipped then
            removeSafe()
        end
    else
        if hasWeaponEquipped then
            removeBriefcaseWeapon()
        end
        if hasBoxEquipped then
            removeCardboardBox()
        end
        if hasSafeEquipped then
            removeSafe()
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)

        if hasWeaponEquipped then
            if not isPlayerHoldingBriefcase() then
                equipBriefcaseWeapon(true)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if hasWeaponEquipped then
        removeBriefcaseWeapon()
    end

    if hasBoxEquipped then
        removeCardboardBox()
    end

    if hasSafeEquipped then
        removeSafe()
    end
end)
