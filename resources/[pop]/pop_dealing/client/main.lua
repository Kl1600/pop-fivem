-- pop_dealing : client (commande, PNJ client, IA, target/prompt, NUI, alerte police de secours).
-- Le client ne décide de rien : prix, quantité, paiement et vérifications sont faits par le serveur.
-- Aucune boucle quand le mode vente est inactif ; une seule boucle (500 / 250 ms) pendant qu'un client existe.

local RES = GetCurrentResourceName()

local selling = false     -- mode vente actif (confirmé par le serveur)
local negotiating = false -- panneau de négociation ouvert
local toggling = false    -- appel /sell en cours
local claiming = false    -- appel claim en cours
local proposing = false   -- appel propose en cours
local current = nil       -- client en cours : { id, ped, blip, targetId, ready, arrived, cancelled }
local alertBlips = {}     -- blips des alertes police (fallback)

------------------------------------------------------------------------
-- NUI : pastille de statut et panneau de négociation
------------------------------------------------------------------------

-- Pastille visible seulement en vente et hors négociation.
local function refreshStatus()
    if selling and not negotiating then
        SendNUIMessage({ action = 'pop_dealing:status', show = true, state = current and 'coming' or 'waiting', command = Config.Command })
    else
        SendNUIMessage({ action = 'pop_dealing:status', show = false })
    end
end

local function closeNegotiation()
    if not negotiating then return end
    negotiating, proposing = false, false
    SendNUIMessage({ action = 'pop_dealing:close' })
    SetNuiFocus(false, false)
    refreshStatus()
end

------------------------------------------------------------------------
-- Client PNJ
------------------------------------------------------------------------

local function removeMarkers(c)
    if c.targetId then
        Bridge.Target.Remove(c.targetId)
        c.targetId = nil
    end
    if c.blip then
        if DoesBlipExist(c.blip) then RemoveBlip(c.blip) end
        c.blip = nil
    end
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(50) end
    return HasAnimDictLoaded(dict)
end

-- Fait partir le PNJ (mode = 'walk' | 'sold' | 'flee' | nil pour aucune tâche).
local function leaveTask(ped, mode)
    CreateThread(function()
        local playerPed = PlayerPedId()
        if mode == 'sold' then
            if loadAnimDict('mp_common') then
                TaskPlayAnim(playerPed, 'mp_common', 'givetake1_a', 8.0, -8.0, 1500, 49, 0.0, false, false, false)
                TaskPlayAnim(ped, 'mp_common', 'givetake1_b', 8.0, -8.0, 1500, 49, 0.0, false, false, false)
                Wait(1500)
                RemoveAnimDict('mp_common')
            end
            if not DoesEntityExist(ped) then return end
            ClearPedTasks(ped)
            TaskWanderStandard(ped, 10.0, 10)
        elseif mode == 'flee' then
            TaskSmartFleePed(ped, playerPed, 100.0, -1, false, false)
        elseif mode == 'walk' then
            ClearPedTasks(ped)
            TaskWanderStandard(ped, 10.0, 10)
        end
        SetPedKeepTask(ped, true)
    end)
end

--- Oublie le client localement : retire target et blip, ferme la négociation, fait partir le PNJ.
-- Un PNJ jamais annoncé au serveur (pas encore « prêt ») est supprimé ici, le serveur ne le connaît pas.
local function release(c, mode)
    c.cancelled = true
    removeMarkers(c)
    if current == c then
        current = nil
        if negotiating then closeNegotiation() end
        claiming = false
    end
    refreshStatus()

    local ped = c.ped
    c.ped = nil
    if not ped or not DoesEntityExist(ped) then return end
    if not c.ready then
        DeleteEntity(ped)
        return
    end
    if mode and not IsEntityDead(ped) then leaveTask(ped, mode) end
    -- Filet : si le serveur n'a jamais accepté le PNJ (customerReady rejeté), il ne le supprimera pas.
    SetTimeout(20000, function()
        if DoesEntityExist(ped) then SetEntityAsNoLongerNeeded(ped) end
    end)
end

local function lost(c)
    TriggerServerEvent('pop_dealing:server:customerLost', c.id)
    release(c, nil)
end

local function goToPlayer(ped, playerPed)
    TaskGoToEntity(ped, playerPed, -1, 1.5, 1.0, 1073741824, 0)
    SetPedKeepTask(ped, true)
end

-- Verrouille le client auprès du serveur et ouvre la négociation.
local function claim()
    local c = current
    if not c or negotiating or claiming or not c.ready then return end
    claiming = true
    local offer = Callback.Await('pop_dealing:claim', c.id)
    claiming = false
    if current ~= c or type(offer) ~= 'table' or negotiating then return end

    negotiating, proposing = true, false
    refreshStatus()

    local playerPed = PlayerPedId()
    if c.ped and DoesEntityExist(c.ped) then
        TaskTurnPedToFaceEntity(playerPed, c.ped, 1500)
        TaskTurnPedToFaceEntity(c.ped, playerPed, -1)
    end

    SendNUIMessage({
        action = 'pop_dealing:open',
        label = L(offer.label),
        qty = offer.qty,
        hint = offer.hint,
        min = offer.min,
        max = offer.max,
        step = offer.step,
        attempts = offer.attempts,
        maxAttempts = offer.maxAttempts,
    })
    SetNuiFocus(true, true)
end

local function addTalkTarget(c)
    if c.targetId then return end
    c.targetId = Bridge.Target.AddLocalEntity(c.ped, {
        {
            label = L('target_talk'),
            icon = 'fas fa-comments',
            distance = 2.0,
            canInteract = function() return not negotiating end,
            onSelect = function() CreateThread(claim) end,
        },
    })
end

-- Boucle du client en cours uniquement (500 ms, 250 ms à moins de 15 m).
local function watchCustomer(c)
    CreateThread(function()
        while current == c do
            local ped = c.ped
            if not ped or not DoesEntityExist(ped) or IsEntityDead(ped) then
                lost(c)
                break
            end

            local playerPed = PlayerPedId()
            local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(ped))

            if not negotiating then
                if not c.arrived then
                    if dist < 3.0 and not IsPedInAnyVehicle(playerPed, false) then
                        c.arrived = true
                        ClearPedTasks(ped)
                        TaskTurnPedToFaceEntity(ped, playerPed, -1)
                        addTalkTarget(c)
                    end
                elseif dist > 6.0 then
                    c.arrived = false
                    goToPlayer(ped, playerPed)
                end
            end

            Wait(dist < 15.0 and 250 or 500)
        end
    end)
end

local function findSpawn(origin)
    local minD, maxD = Config.Customers.distance[1], Config.Customers.distance[2]
    local fallback
    for _ = 1, 10 do
        local angle = math.random() * 2.0 * math.pi
        local d = minD + math.random() * (maxD - minD)
        local found, pos = GetSafeCoordForPed(origin.x + math.cos(angle) * d, origin.y + math.sin(angle) * d, origin.z, true, 16)
        if found then
            local fromPlayer = #(pos - origin)
            if fromPlayer >= minD * 0.5 and fromPlayer <= maxD + 10.0 then
                if not IsSphereVisible(pos.x, pos.y, pos.z, 1.0) then return pos end
                fallback = fallback or pos
            end
        end
    end
    return fallback
end

local function spawnCustomer(data)
    if type(data) ~= 'table' or math.type(data.id) ~= 'integer' or type(data.model) ~= 'string' then return end
    if current then release(current, 'walk') end

    local c = { id = data.id }
    current = c
    refreshStatus()

    -- Modèle (timeout 5 s).
    local hash = joaat(data.model)
    if not IsModelInCdimage(hash) then return lost(c) end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(50) end
    if c.cancelled then
        SetModelAsNoLongerNeeded(hash)
        return
    end
    if not HasModelLoaded(hash) then return lost(c) end

    -- Point d'apparition (trottoir, de préférence hors champ).
    local playerPed = PlayerPedId()
    local origin = GetEntityCoords(playerPed)
    local pos = findSpawn(origin)
    if not pos then
        SetModelAsNoLongerNeeded(hash)
        return lost(c)
    end

    local heading = GetHeadingFromVector_2d(origin.x - pos.x, origin.y - pos.y)
    local ped = CreatePed(4, hash, pos.x, pos.y, pos.z, heading, true, true)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return lost(c) end
    c.ped = ped

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)

    -- Attendre la mise en réseau (max 2 s).
    timeout = GetGameTimer() + 2000
    while not NetworkGetEntityIsNetworked(ped) and GetGameTimer() < timeout do Wait(50) end
    if c.cancelled then
        if DoesEntityExist(ped) then DeleteEntity(ped) end
        return
    end
    if not NetworkGetEntityIsNetworked(ped) then return lost(c) end

    local netId = PedToNet(ped)
    SetNetworkIdCanMigrate(netId, false)
    c.ready = true
    TriggerServerEvent('pop_dealing:server:customerReady', c.id, netId)

    -- Blip discret sur le client.
    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 2)
    SetBlipScale(blip, 0.7)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(L('blip_customer'))
    EndTextCommandSetBlipName(blip)
    c.blip = blip

    goToPlayer(ped, PlayerPedId())
    watchCustomer(c)
end

------------------------------------------------------------------------
-- Commande /sell
------------------------------------------------------------------------

local function toggle()
    if toggling then return end
    toggling = true
    local active = Callback.Await('pop_dealing:toggle')
    toggling = false
    if active == nil then return end -- pas de réponse (limite d'appels, délai) : état inchangé
    selling = active == true
    if not selling and current then release(current, 'walk') end
    if not selling then closeNegotiation() end
    refreshStatus()
end

RegisterCommand(Config.Command, function()
    CreateThread(toggle)
end, false)
RegisterKeyMapping(Config.Command, L('keymap_toggle'), 'keyboard', '')

------------------------------------------------------------------------
-- Events serveur
------------------------------------------------------------------------

RegisterNetEvent('pop_dealing:client:customer', function(data)
    if not selling then
        -- Le serveur nous croit en vente : libérer ce client pour qu'il ne reste pas bloqué.
        if type(data) == 'table' and math.type(data.id) == 'integer' then
            TriggerServerEvent('pop_dealing:server:customerLost', data.id)
        end
        return
    end
    spawnCustomer(data)
end)

RegisterNetEvent('pop_dealing:client:customerLeave', function(customerId, mode)
    local c = current
    if not c or c.id ~= customerId then return end
    if mode ~= 'sold' and mode ~= 'flee' then mode = 'walk' end
    release(c, mode)
end)

-- Nettoyage commun à l'arrêt du mode vente et de la ressource.
local function cleanup(deletePed)
    selling = false
    closeNegotiation()
    local c = current
    if c then
        local ped = c.ped
        release(c, nil)
        if deletePed and ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    claiming, proposing = false, false
    SendNUIMessage({ action = 'pop_dealing:status', show = false })
end

RegisterNetEvent('pop_dealing:client:stop', function()
    cleanup(false)
end)

RegisterNetEvent('pop_dealing:client:policeAlert', function(coords, kind)
    if type(coords) ~= 'vector3' then return end
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
    Bridge.Notify(L(kind == 'bust' and 'police_alert_bust' or 'police_alert', street), 'warning')

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 51)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.0)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(L('dispatch_title'))
    EndTextCommandSetBlipName(blip)
    alertBlips[blip] = true

    SetTimeout((tonumber(Config.Police.blipTime) or 60) * 1000, function()
        if not alertBlips[blip] then return end
        alertBlips[blip] = nil
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

------------------------------------------------------------------------
-- Callbacks NUI
------------------------------------------------------------------------

RegisterNUICallback('propose', function(data, cb)
    local c = current
    local price = type(data) == 'table' and tonumber(data.price)
    if not c or not negotiating or proposing or not price then return cb(nil) end
    price = math.floor(price)
    proposing = true
    CreateThread(function()
        local result = Callback.Await('pop_dealing:propose', c.id, price)
        proposing = false
        cb(result)
        if current == c and (type(result) ~= 'table' or result.status ~= 'refused') then
            -- Pas de réponse : le serveur garde le client, on le libère explicitement.
            if result == nil then TriggerServerEvent('pop_dealing:server:refuse', c.id) end
            closeNegotiation()
        end
    end)
end)

local function refuseCurrent()
    local c = current
    if c then TriggerServerEvent('pop_dealing:server:refuse', c.id) end
    closeNegotiation()
end

RegisterNUICallback('refuse', function(_, cb)
    refuseCurrent()
    cb({ ok = true })
end)

-- Échap (kit) : traité comme un refus. Le focus est déjà rendu par le bridge.
Bridge.OnUiClose(function()
    if negotiating then refuseCurrent() end
end)

------------------------------------------------------------------------
-- Export et nettoyage
------------------------------------------------------------------------

exports('IsSelling', function()
    return selling
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    cleanup(true)
    SetNuiFocus(false, false)
    for blip in pairs(alertBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    alertBlips = {}
end)
