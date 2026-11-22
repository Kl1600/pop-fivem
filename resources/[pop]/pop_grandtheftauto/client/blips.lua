-- cl_blips.lua

-- ============================================================
-- BLIP L('blip_panel') (anti-doublon)
-- ============================================================

local panelBlipId = nil
local panelBlipCreated = false

RegisterNetEvent('mission:setupBlips')
AddEventHandler('mission:setupBlips', function()
    if not (_G.MissionSync and _G.MissionSync.active) then return end
    if panelBlipCreated and panelBlipId and DoesBlipExist(panelBlipId) then
        return
    end

    panelBlipId = AddBlipForCoord(-54.8242, 78.8582, 71.6542)
    SetBlipSprite(panelBlipId, 461)
    SetBlipScale(panelBlipId, 0.9)
    SetBlipColour(panelBlipId, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(L('blip_panel'))
    EndTextCommandSetBlipName(panelBlipId)

    panelBlipCreated = true
end)

local function RemovePanelBlip()
    if panelBlipId and DoesBlipExist(panelBlipId) then
        RemoveBlip(panelBlipId)
    end
    panelBlipId = nil
    panelBlipCreated = false
end
AddEventHandler('mission:local:removeblip1', RemovePanelBlip)
AddEventHandler('mission:local:reset', RemovePanelBlip)



-- ============================================================
-- PED DÉCOR (local, inchangé)
-- ============================================================

local decorPed = nil
Citizen.CreateThread(function()
    local hash = LoadFirstModel({ 'ig_valentina', 'a_f_y_business_04' })
    if not hash then return end

    local ped = CreatePed(4, hash, -1029.3354, -2966.0518, 13.9468, 347.2004, false, true)
    SetModelAsNoLongerNeeded(hash)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    decorPed = ped

    local anim = "amb@business_talk@male_b@base"
    if LoadAnimDict(anim) then
        TaskPlayAnim(ped, anim, "base", 15.0, 8.0, -1, 1, 0, 0, 0, 0)
    end
end)

-- (Commande de dev /dv100 retirée : elle supprimait tous les véhicules à 100 m.)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    RemovePanelBlip()
    if decorPed and DoesEntityExist(decorPed) then DeleteEntity(decorPed) end
end)
