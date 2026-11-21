-- ─────────────────────────────────────────────
-- pop_dealing - logique client
-- Spawn local des clients NPC, interaction, HUD 3D
-- ─────────────────────────────────────────────

local spawnedCustomers = {} -- [id] = { data, ped, state, uiId, ... }
local currentOffer     = nil -- { id, drugLabel, ... }

-- Forward declarations
local closeUi, openUi

-- ─────────────────────────────────────────────
-- Caméra de négociation (focus + DOF) façon charcreator
-- ─────────────────────────────────────────────

local dealCam       = nil
local dealCamPed    = nil
local camDofThread  = false

-- Distances / offsets de la cam (modifiables)
local CAM_OFFSET    = 1.4
local CAM_SIDE      = 0.55
local CAM_HEIGHT    = 0.55

local function aimDealCam(ped)
    if not DoesEntityExist(ped) or not DoesCamExist(dealCam) then return end
    local pedCoords = GetEntityCoords(ped)
    local pedHead   = GetEntityHeading(ped)
    local rad       = math.rad(pedHead)

    -- "Devant" le ped client
    local fwdX = -math.sin(rad)
    local fwdY =  math.cos(rad)
    -- "Droite" du ped client
    local rightRad = math.rad(pedHead - 90.0)
    local rgtX = -math.sin(rightRad)
    local rgtY =  math.cos(rightRad)

    local cx = pedCoords.x + fwdX * CAM_OFFSET + rgtX * CAM_SIDE
    local cy = pedCoords.y + fwdY * CAM_OFFSET + rgtY * CAM_SIDE
    local cz = pedCoords.z + CAM_HEIGHT

    SetCamCoord(dealCam, cx, cy, cz)
    PointCamAtCoord(dealCam, pedCoords.x, pedCoords.y, pedCoords.z + CAM_HEIGHT - 0.05)
end

local function startDealCam(ped)
    if not DoesEntityExist(ped) then return end
    if dealCam and DoesCamExist(dealCam) then
        DestroyCam(dealCam, false)
    end

    dealCam    = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    dealCamPed = ped
    SetCamFov(dealCam, 32.0)
    SetCamActive(dealCam, true)

    -- DOF (flou d'arrière-plan) - réglages doux
    SetCamUseShallowDofMode(dealCam, true)
    SetCamNearDof(dealCam, 0.6)
    SetCamFarDof(dealCam, CAM_OFFSET + 0.5)
    SetCamDofStrength(dealCam, 0.8)

    aimDealCam(ped)
    RenderScriptCams(true, true, 400, true, true)

    -- Tick : maintenir le HiDof + re-viser le client en continu
    camDofThread = true
    CreateThread(function()
        while camDofThread and DoesCamExist(dealCam) do
            SetUseHiDof()
            if dealCamPed and DoesEntityExist(dealCamPed) then
                aimDealCam(dealCamPed)
            end
            Wait(0)
        end
    end)
end

local function stopDealCam()
    camDofThread = false
    if dealCam and DoesCamExist(dealCam) then
        RenderScriptCams(false, true, 400, true, true)
        DestroyCam(dealCam, false)
    end
    dealCam    = nil
    dealCamPed = nil
end

-- États du PNJ
local STATE_IDLE      = 'idle'      -- vient de spawn, pas encore vu le joueur
local STATE_APPROACH  = 'approach'  -- marche vers le joueur
local STATE_WAITING   = 'waiting'   -- arrivé face au joueur, attend l'interaction
local STATE_NEGO      = 'nego'      -- en discussion (menu ouvert)
local STATE_LEAVING   = 'leaving'   -- s'en va

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function notify(data)
    exports['pop_notify']:ShowNotify(data)
end

local function loadModel(modelName)
    local hash = type(modelName) == 'string' and GetHashKey(modelName) or modelName
    lib.requestModel(hash)
    return hash
end

local function isPlayerInAnyZone()
    local pc = GetEntityCoords(cache.ped)
    for _, z in ipairs(Config.Zones) do
        if #(pc - vec3(z.center.x, z.center.y, z.center.z)) <= z.radius then
            return true
        end
    end
    return false
end

-- ─────────────────────────────────────────────
-- Spawn / suppression
-- ─────────────────────────────────────────────

local function spawnCustomer(data)
    if spawnedCustomers[data.id] then return end

    local hash = loadModel(data.model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        if Config.Debug then print(('[pop_dealing] modèle invalide: %s'):format(tostring(data.model))) end
        return
    end

    -- Récupère le bon Z au sol pour pas spawn dans le sol / le ciel
    local groundZ = data.z
    local ok, zz = GetGroundZFor_3dCoord(data.x, data.y, data.z + 50.0, false)
    if ok then groundZ = zz end

    local ped = CreatePed(4, hash, data.x, data.y, groundZ, data.heading, false, true)
    if not DoesEntityExist(ped) then
        if Config.Debug then print(('[pop_dealing] CreatePed a échoué pour id=%d'):format(data.id)) end
        return
    end
    if Config.Debug then
        print(('[pop_dealing] ped spawn id=%d model=%s coords=%.2f,%.2f,%.2f'):format(data.id, data.model, data.x, data.y, groundZ))
    end
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanRagdoll(ped, false)
    SetEntityInvincible(ped, true)

    -- Objet invisible attaché au torse → cible safe pour drag-and-drop
    -- (SetEntityDrawOutline sur ped crash souvent à cause des shaders cloth/hair)
    local dragHash = GetHashKey('prop_dummy_01')
    lib.requestModel(dragHash)
    local dragAnchor = CreateObject(dragHash, data.x, data.y, groundZ + 0.5, false, true, false)
    SetEntityVisible(dragAnchor, false, false)
    SetEntityCollision(dragAnchor, false, false)
    SetEntityAlpha(dragAnchor, 0, false)
    AttachEntityToEntity(dragAnchor, ped, GetPedBoneIndex(ped, 24816),
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 2, true)

    -- Clients du mode vente : immobiles + blip sur la carte (le joueur vient à eux)
    local blip
    if data.static then
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
        local b = Config.CustomerBlip or {}
        blip = AddBlipForEntity(ped)
        SetBlipSprite(blip, b.sprite or 1)
        SetBlipColour(blip, b.color or 2)
        SetBlipScale(blip, b.scale or 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(b.label or 'Client')
        EndTextCommandSetBlipName(blip)
    end

    spawnedCustomers[data.id] = {
        data        = data,
        ped         = ped,
        dragAnchor  = dragAnchor,
        blip        = blip,
        state       = STATE_IDLE,
        spottedAt   = nil,
        waitingAt   = nil,
    }
end

local function removeCustomer(id)
    local entry = spawnedCustomers[id]
    if not entry then return end

    if entry.uiId then
        exports.pop_v3dui:Remove(entry.uiId)
    end
    if entry.dragAnchor and DoesEntityExist(entry.dragAnchor) then
        exports.pop_inventory:unregisterDragTarget(entry.dragAnchor)
        DetachEntity(entry.dragAnchor, true, true)
        DeleteEntity(entry.dragAnchor)
    end
    if entry.blip and DoesBlipExist(entry.blip) then
        RemoveBlip(entry.blip)
    end
    if DoesEntityExist(entry.ped) then
        DeletePed(entry.ped)
    end
    spawnedCustomers[id] = nil

    if currentOffer and currentOffer.id == id then
        currentOffer = nil
        closeUi()
    end
    -- Sécurité : si la cam pointait sur ce ped, on coupe
    if dealCamPed == entry.ped then stopDealCam() end
end

-- ─────────────────────────────────────────────
-- Interaction : ox_target
-- ─────────────────────────────────────────────

local function attachTarget(entry)
    local id = entry.data.id
    -- Drag sur l'ancre invisible (pas sur le ped → évite crash SetEntityDrawOutline)
    local target = entry.dragAnchor or entry.ped
    exports.pop_inventory:registerDragTarget(target, entry.data.drugDefId, function()
        if entry.state ~= STATE_WAITING then return end
        SetTimeout(150, function()
            TriggerServerEvent('pop_dealing:claim', id)
        end)
    end)
end

-- ─────────────────────────────────────────────
-- Menu d'offre (ox_lib context)
-- ─────────────────────────────────────────────

closeUi = function()
    SendNUIMessage({ action = 'hide' })
    SetNuiFocus(false, false)
    stopDealCam()
end

openUi = function(offer)
    -- Ferme l'inventaire si ouvert (on vient d'y glisser la weed)
    TriggerEvent('pop_inventory:client:forceClose')

    SendNUIMessage({
        action = 'show',
        offer  = {
            id           = offer.id,
            label        = offer.drugLabel,
            icon         = offer.drugIcon or 'fas fa-cannabis',
            qty          = offer.qty,
            hintUnit     = offer.hintUnit,
            attemptsLeft = offer.attemptsLeft,
            maxAttempts  = offer.maxAttempts,
        },
    })
    SetNuiFocus(true, true)

    local entry = spawnedCustomers[offer.id]
    if entry and DoesEntityExist(entry.ped) then
        startDealCam(entry.ped)
    end
end


RegisterNetEvent('pop_dealing:offerDetails', function(offer)
    if Config.Debug then
        print(('[pop_dealing] offerDetails id=%s drug=%s qty=%s hint=%s attempts=%s/%s'):format(
            tostring(offer.id), tostring(offer.drugLabel), tostring(offer.qty),
            tostring(offer.hintUnit), tostring(offer.attemptsLeft), tostring(offer.maxAttempts)))
    end
    currentOffer = offer
    local entry  = spawnedCustomers[offer.id]
    if entry then entry.state = STATE_NEGO end
    openUi(offer)
end)

RegisterNUICallback('propose', function(data, cb)
    if currentOffer and currentOffer.id == data.id then
        TriggerServerEvent('pop_dealing:propose', data.id, data.unitPrice)
    end
    cb({ ok = true })
end)

RegisterNUICallback('refuse', function(data, cb)
    if currentOffer and currentOffer.id == data.id then
        TriggerServerEvent('pop_dealing:refuse', data.id)
    end
    closeUi()
    currentOffer = nil
    cb({ ok = true })
end)

-- Résultat du serveur après une proposition
RegisterNetEvent('pop_dealing:proposeResult', function(data)
    SendNUIMessage({ action = 'result', status = data.status, hintDir = data.hintDir,
                     attemptsLeft = data.attemptsLeft, unitPrice = data.unitPrice, totalPrice = data.totalPrice })
    if data.status == 'accept' or data.status == 'walkaway' or data.status == 'cancel' then
        SetTimeout(900, function()
            if currentOffer and currentOffer.id == data.id then currentOffer = nil end
            closeUi()
        end)
    end
end)

-- ─────────────────────────────────────────────
-- Résultats serveur
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_dealing:dealComplete', function(data)
    notify({
        title    = 'Deal conclu',
        message  = ('Vendu : <b>%d %s</b> pour <b>$%d</b>'):format(data.qty, data.drugLabel, data.totalPrice),
        icon     = 'fas fa-money-bill-wave',
        badge    = '+$' .. data.totalPrice,
        badgeColor = '#3aa856',
        duration = 5000,
    })

    -- Petite anim de remerciement
    lib.requestAnimDict('mp_common')
    TaskPlayAnim(cache.ped, 'mp_common', 'givetake1_a', 4.0, -4.0, 1500, 49, 0, false, false, false)
end)

RegisterNetEvent('pop_dealing:bust', function(c)
    notify({
        title      = 'PIÈGE !',
        message    = 'Ce client était un flic infiltré...',
        icon       = 'fas fa-handcuffs',
        badge      = 'BUST',
        badgeColor = '#e74c3c',
        duration   = 6000,
    })
    currentOffer = nil
    closeUi()
end)

RegisterNetEvent('pop_dealing:dispatchAlert', function(data)
    -- À brancher sur ton script de dispatch police ; pour l'instant juste un log local
    local pc = GetEntityCoords(cache.ped)
    if #(pc - data.coords) <= data.radius then
        notify({
            title    = 'Signalement',
            message  = data.label,
            icon     = 'fas fa-walkie-talkie',
            badge    = 'POLICE',
            badgeColor = '#3498db',
            duration = 7000,
        })
    end
end)

RegisterNetEvent('pop_dealing:notify', notify)

-- ─────────────────────────────────────────────
-- Sync
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_dealing:syncAll', function(list)
    for _, data in pairs(list) do spawnCustomer(data) end
end)

RegisterNetEvent('pop_dealing:spawnCustomer', function(data)
    spawnCustomer(data)
end)

RegisterNetEvent('pop_dealing:removeCustomer', function(id)
    local entry = spawnedCustomers[id]
    if entry then
        entry.state = STATE_LEAVING
        -- petit délai pour effet visuel : le ped s'éloigne avant disparition
        CreateThread(function()
            if DoesEntityExist(entry.ped) then
                ClearPedTasks(entry.ped)
                local pc = GetEntityCoords(entry.ped)
                TaskWanderInArea(entry.ped, pc.x, pc.y, pc.z, 30.0, 1.0, 5.0)
            end
            Wait(2500)
            removeCustomer(id)
        end)
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(500)
    TriggerServerEvent('pop_dealing:requestSync')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopDealCam()
    SetNuiFocus(false, false)
    for id in pairs(spawnedCustomers) do removeCustomer(id) end
end)

-- ─────────────────────────────────────────────
-- Comportement IA des clients
-- ─────────────────────────────────────────────

CreateThread(function()
    while true do
        local pc       = GetEntityCoords(cache.ped)
        local inZone   = isPlayerInAnyZone()
        local anyClose = false

        for id, entry in pairs(spawnedCustomers) do
            if DoesEntityExist(entry.ped) then
                local epc  = GetEntityCoords(entry.ped)
                local dist = #(pc - epc)
                if dist < 60.0 then anyClose = true end

                if entry.state == STATE_IDLE then
                    if entry.data.static then
                        -- Client immobile avec blip : c'est au joueur d'aller le voir.
                        if dist <= (Config.CustomerApproachRange or 1.8) + 1.5 then
                            ClearPedTasks(entry.ped)
                            TaskTurnPedToFaceEntity(entry.ped, cache.ped, -1)
                            entry.state     = STATE_WAITING
                            entry.waitingAt = GetGameTimer()
                            attachTarget(entry)
                        end
                    else
                        -- Le client repère le joueur si en zone (ou dev), à portée, et a la drogue (ou dev)
                        local zoneOK = inZone or Config.DevIgnoreZone or (entry.data.zoneIdx == 0)
                        local rangeOK = dist <= (Config.CustomerDetectRange or 40.0)
                        local itemOK  = Config.DevIgnoreItemCheck
                                        or exports.pop_inventory:getItemCount(entry.data.drugDefId) >= entry.data.qty

                        if zoneOK and rangeOK and itemOK then
                            ClearPedTasks(entry.ped)
                            TaskGoToEntity(entry.ped, cache.ped, -1, Config.CustomerApproachRange or 1.8, Config.WalkSpeed or 1.0, 0, 0)
                            entry.state     = STATE_APPROACH
                            entry.spottedAt = GetGameTimer()
                            attachTarget(entry)
                        end
                    end

                elseif entry.state == STATE_APPROACH then
                    if dist <= (Config.CustomerApproachRange or 1.8) + 0.5 then
                        ClearPedTasks(entry.ped)
                        TaskTurnPedToFaceEntity(entry.ped, cache.ped, -1)
                        entry.state     = STATE_WAITING
                        entry.waitingAt = GetGameTimer()
                    elseif entry.spottedAt and (GetGameTimer() - entry.spottedAt) > 30000 then
                        -- timeout d'approche (joueur a fui) : un seul envoi
                        entry.state = STATE_LEAVING
                        TriggerServerEvent('pop_dealing:refuse', id)
                    end

                elseif entry.state == STATE_WAITING then
                    -- Timeout : le client s'en va si pas servi (sauf clients statiques, qui patientent à leur blip)
                    if not entry.data.static and entry.waitingAt and (GetGameTimer() - entry.waitingAt) > (Config.OfferTimeout or 25) * 1000 then
                        entry.state = STATE_LEAVING
                        TriggerServerEvent('pop_dealing:refuse', id)
                    end
                end
            end
        end

        Wait(anyClose and 500 or 2000)
    end
end)

-- ─────────────────────────────────────────────
-- HUD 3D au-dessus du client en attente
-- ─────────────────────────────────────────────

CreateThread(function()
    while true do
        local hasActive = false
        for _, entry in pairs(spawnedCustomers) do
            if DoesEntityExist(entry.ped) and entry.state == STATE_WAITING then
                hasActive = true
                local coords = GetEntityCoords(entry.ped)
                if not entry.uiId then
                    entry.uiId = exports.pop_v3dui:Create({
                        coords       = coords,
                        type         = 'prompt',
                        content      = {
                            key   = 'GLISSER',
                            label = entry.data.drugLabel or 'Marchandise',
                            icon  = entry.data.drugIcon or 'fas fa-hand-holding-dollar',
                        },
                        drawDistance = Config.DrawDistance or 6.0,
                        offset       = vec3(0, 0, 1.0),
                    })
                else
                    exports.pop_v3dui:UpdateCoords(entry.uiId, coords)
                end
            else
                if entry.uiId then
                    exports.pop_v3dui:Remove(entry.uiId)
                    entry.uiId = nil
                end
            end
        end
        Wait(hasActive and 500 or 1500)
    end
end)
