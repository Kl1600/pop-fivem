-- Alertes police (cooldown, équipe uniquement).

-- ============================================================
-- ALERTES POLICE (cooldown, équipe uniquement)
-- ============================================================

RegisterNetEvent('mission:server:alertPoliceLocation')
AddEventHandler('mission:server:alertPoliceLocation', function()
    local src = source
    if not GTA.Mission.active or not GTA.IsMember(src) then return end
    if os.time() - GTA.lastShowroomAlert < Config.PoliceAlertCooldown then return end
    GTA.lastShowroomAlert = os.time()

    local coords = Config.ShowroomPos
    local policePlayers = GTA.GetPolicePlayers()
    for _, p in pairs(policePlayers) do
        Bridge.Notify(p, {
            icon = Config.NotifyIcon,
            message = L('police_showroom'),
            duration = 20000
        })
        TriggerClientEvent('mission:client:policeShowroomBlip', p, coords)
    end

    SetTimeout(100000, function()
        for _, p in pairs(policePlayers) do
            TriggerClientEvent('mission:client:removeShowroomBlip', p)
        end
    end)
end)

RegisterNetEvent('mission:server:alertPolice')
AddEventHandler('mission:server:alertPolice', function()
    local src = source
    if not GTA.Mission.active or not GTA.IsMember(src) then return end
    if os.time() - GTA.lastTrackingAlert < Config.PoliceAlertCooldown then return end
    GTA.lastTrackingAlert = os.time()

    -- Les véhicules suivis viennent du serveur, pas du client
    local vehicleNetIds = {}
    for key, payload in pairs(GTA.Mission.entities) do
        if key:match('^showroom_car_%d$') and type(payload) == 'table' and payload.netId then
            table.insert(vehicleNetIds, payload.netId)
        end
    end

    local policePlayers = GTA.GetPolicePlayers()
    for _, p in pairs(policePlayers) do
        Bridge.Notify(p, {
            icon = Config.NotifyIcon,
            message = L('police_theft'),
            duration = 10000
        })
    end

    GTA.trackingToken = GTA.trackingToken + 1
    local myToken = GTA.trackingToken
    CreateThread(function()
        local dureeEnSecondes = 100 -- durée du suivi GPS
        for _ = 1, dureeEnSecondes do
            if myToken ~= GTA.trackingToken then return end
            local trackingData = {}
            for _, netId in ipairs(vehicleNetIds) do
                local entity = NetworkGetEntityFromNetworkId(netId)
                if entity ~= 0 and DoesEntityExist(entity) then
                    table.insert(trackingData, { netId = netId, coords = GetEntityCoords(entity) })
                end
            end
            for _, p in pairs(GTA.GetPolicePlayers()) do
                TriggerClientEvent('mission:client:startPoliceTracking', p, trackingData)
            end
            Wait(1000)
        end
        if myToken == GTA.trackingToken then GTA.StopTracking() end
    end)
end)

RegisterNetEvent('mission:server:stopPoliceTracking')
AddEventHandler('mission:server:stopPoliceTracking', function()
    local src = source
    if not GTA.IsMember(src) or not Bridge.IsNear(src, Config.DeliveryPos, 80.0) then return end
    GTA.StopTracking()
end)
