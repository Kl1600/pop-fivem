-- Module pirate (pcb) : commande /voler_auto, utilisation depuis l'inventaire, glisser-déposer sur la voiture,
-- et GPS + camion pour le coéquipier qui prend le volant d'une voiture piratée.

RegisterCommand("voler_auto", function()
    local ped = PlayerPedId()
    if PCB.Active[ped] then return end

    local veh = PCB.FindVehicle(PCB.PATTERN)
    if not veh then return end

    CheckItem('pcb', function(hasItem) CreateThread(function()
        if hasItem then
            local plate = PCB.trim(GetVehicleNumberPlateText(veh))

            if PCB.Completed[plate] then
                MissionNotify(L('already_hacked'), 7000)
                return
            end

            if PCB.Hacked[plate] then
                MissionNotify(L('module_installed'), 7000)
                return
            end

            if #(GetEntityCoords(ped) - GetEntityCoords(veh)) < 5.0 then
                -- Le module pirate n'est consommé qu'à la réussite (côté serveur)
                PCB.StartCoop(veh)
            else
                MissionNotify(L('too_far_vehicle'), 7000)
            end
        else
            MissionNotify(L('need_pcb'), 5000)
        end
    end) end, 'pcb')
end, false)

RegisterNetEvent('grandtheftauto:usePCB')
AddEventHandler('grandtheftauto:usePCB', function()
    ExecuteCommand('voler_auto')
end)

-- (Commande de dev /voler_auto_dev retirée.)

-- =========================
-- DRAG & DROP INVENTORY INTEGRATION
-- =========================
local registeredDragVehs = {}

CreateThread(function()
    while true do
        Wait(2000)
        local vehicles = (IsCoopActive() and #(GetEntityCoords(PlayerPedId()) - Config.ShowroomPos) < 150.0) and GetGamePool("CVehicle") or {}

        for _, veh in ipairs(vehicles) do
            if not registeredDragVehs[veh] and GetResourceState('pop_inventory') == 'started' then
                local plate = GetVehicleNumberPlateText(veh)
                if plate and PCB.trim(plate):find(PCB.PATTERN) then
                    exports.pop_inventory:registerDragTarget(veh, 'pcb', function()
                        ExecuteCommand('pop_inventory') -- Force la fermeture de l'inventaire

                        local playerPed = PlayerPedId()
                        if PCB.Active[playerPed] then return end

                        CheckItem('pcb', function(hasItem) CreateThread(function()
                            if hasItem then
                                local plateEntity = PCB.trim(GetVehicleNumberPlateText(veh))

                                if PCB.Completed[plateEntity] then
                                    MissionNotify(L('already_hacked'), 7000)
                                    return
                                end

                                if PCB.Hacked[plateEntity] then
                                    MissionNotify(L('module_installed'), 7000)
                                    return
                                end

                                if #(GetEntityCoords(playerPed) - GetEntityCoords(veh)) < 5.0 then
                                    PCB.StartCoop(veh)
                                else
                                    MissionNotify(L('too_far_vehicle'), 7000)
                                end
                            else
                                MissionNotify(L('need_pcb'), 5000)
                            end
                        end) end, 'pcb')
                    end)
                    registeredDragVehs[veh] = true
                end
            end
        end

        for v, _ in pairs(registeredDragVehs) do
            if not DoesEntityExist(v) or not IsCoopActive() then
                pcall(function() exports.pop_inventory:unregisterDragTarget(v) end)
                registeredDragVehs[v] = nil
            end
        end
    end
end)
-- =========================
-- COOP : le coéquipier qui prend le volant d'une voiture piratée reçoit le GPS et son camion
-- =========================
CreateThread(function()
    while true do
        local wait = 2000
        if IsCoopActive() and not deliveryStarted then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                local plate = PCB.trim(GetVehicleNumberPlateText(veh))
                if PCB.Completed[plate] then
                    deliveryStarted = true
                    TriggerEvent('ondeliveryblip')
                    TriggerEvent('spawncamion')
                end
            end
            wait = 1000
        end
        Wait(wait)
    end
end)
