-- Livraison des voitures et fin de mission.

-- ============================================================
-- LIVRAISON
-- ============================================================

RegisterNetEvent('mission:server:requestDeliverySlot')
AddEventHandler('mission:server:requestDeliverySlot', function()
    local src = source
    if not GTA.Mission.active or not GTA.IsMember(src) then return end

    -- Libère les emplacements oubliés (plus de 15 min)
    for i, slot in pairs(GTA.DeliverySlots) do
        if os.time() - slot.t > 900 then GTA.DeliverySlots[i] = nil end
    end

    -- Un seul camion à la fois par joueur
    for _, slot in pairs(GTA.DeliverySlots) do
        if slot.src == src then
            TriggerClientEvent('mission:client:receiveDeliverySlot', src, nil)
            return
        end
    end

    local slotIndex = nil
    for i = 1, #Config.DeliverySlots do
        if not GTA.DeliverySlots[i] then
            GTA.DeliverySlots[i] = { src = src, t = os.time() }
            slotIndex = i
            break
        end
    end
    TriggerClientEvent('mission:client:receiveDeliverySlot', src, slotIndex)
end)

local function CheckEnd()
    if not GTA.Mission.active then return end
    local completed = 0
    for _ in pairs(GTA.HackCompleted) do completed = completed + 1 end
    if GTA.Mission.deliveredCount >= #Cars then
        GTA.EndMission('done')
        return
    end
    -- Toutes les voitures piratées sont livrées : 5 min pour en voler une autre, sinon fin.
    if completed > 0 and GTA.Mission.deliveredCount >= completed then
        local id = GTA.Mission.id
        GTA.Mission.endCheck = id
        for member in pairs(GTA.Mission.members) do
            GTA.Notify(member, L('ending_soon'), 9000)
        end
        SetTimeout(5 * 60 * 1000, function()
            if GTA.Mission.active and GTA.Mission.id == id and GTA.Mission.endCheck == id then
                local c = 0
                for _ in pairs(GTA.HackCompleted) do c = c + 1 end
                if GTA.Mission.deliveredCount >= c then GTA.EndMission('done') end
            end
        end)
    end
end

RegisterNetEvent('mission:server:delivered')
AddEventHandler('mission:server:delivered', function(netId, slotIndex)
    local src = source
    netId = tonumber(netId)
    slotIndex = tonumber(slotIndex)
    local function reply(ok) TriggerClientEvent('mission:client:deliveredResult', src, slotIndex, ok) end

    if not GTA.Mission.active or not GTA.IsMember(src) or not netId or not slotIndex then return reply(false) end
    local slotCfg = Config.DeliverySlots[slotIndex]
    if not slotCfg then return reply(false) end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return reply(false) end

    local plate = (GetVehicleNumberPlateText(veh) or ''):match("^%s*(.-)%s*$")
    if not GTA.ValidPlates[plate] or not GTA.HackCompleted[plate] or GTA.Mission.delivered[plate] then return reply(false) end
    if GTA.CarNetIdForPlate(plate) ~= netId then return reply(false) end
    if #(GetEntityCoords(veh) - slotCfg.pos) > 15.0 then return reply(false) end
    if not Bridge.IsNear(src, slotCfg.pos, 40.0) then return reply(false) end

    GTA.Mission.delivered[plate] = true
    GTA.Mission.deliveredCount = GTA.Mission.deliveredCount + 1
    GTA.DeliverySlots[slotIndex] = nil

    -- Le joueur sort du véhicule avant la suppression
    for seat = -1, 6 do
        local p = GetPedInVehicleSeat(veh, seat)
        if p ~= 0 then TaskLeaveVehicle(p, veh, 16) end
    end
    SetTimeout(1500, function()
        if DoesEntityExist(veh) then DeleteEntity(veh) end
    end)

    local paid = GTA.PayPlayer(src, Config.RewardPerCar)
    if paid then
        GTA.Notify(src, L('paid', Config.RewardPerCar, paid == 'bank' and L('paid_bank_suffix') or ''), 8000)
    end
    for member in pairs(GTA.Mission.members) do
        if member ~= src then
            GTA.Notify(member, L('team_delivered'), 6000)
        end
    end
    reply(true)
    CheckEnd()
end)
