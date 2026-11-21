-- ─────────────────────────────────────────────
-- pop_dealing - clients PNJ : spawn local, interaction (drag), sync, IA, HUD 3D
-- ─────────────────────────────────────────────

local spawnedCustomers = Dealing.customers

-- ─────────────────────────────────────────────
-- Spawn / suppression
-- ─────────────────────────────────────────────

local function spawnCustomer(data)
    if spawnedCustomers[data.id] then return end

    local hash = Dealing.loadModel(data.model)
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
        AddTextComponentSubstringPlayerName(b.label or L('blip_default'))
        EndTextCommandSetBlipName(blip)
    end

    spawnedCustomers[data.id] = {
        data        = data,
        ped         = ped,
        dragAnchor  = dragAnchor,
        blip        = blip,
        state       = Dealing.STATE_IDLE,
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

    if Dealing.currentOffer and Dealing.currentOffer.id == id then
        Dealing.currentOffer = nil
        Dealing.closeUi()
    end
    -- Sécurité : si la cam pointait sur ce ped, on coupe
    if Dealing.getDealCamPed() == entry.ped then Dealing.stopDealCam() end
end

-- ─────────────────────────────────────────────
-- Interaction : ox_target
-- ─────────────────────────────────────────────

local function attachTarget(entry)
    local id = entry.data.id
    -- Drag sur l'ancre invisible (pas sur le ped → évite crash SetEntityDrawOutline)
    local target = entry.dragAnchor or entry.ped
    exports.pop_inventory:registerDragTarget(target, entry.data.drugDefId, function()
        if entry.state ~= Dealing.STATE_WAITING then return end
        SetTimeout(150, function()
            TriggerServerEvent('pop_dealing:claim', id)
        end)
    end)
end

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
        entry.state = Dealing.STATE_LEAVING
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
    Dealing.stopDealCam()
    SetNuiFocus(false, false)
    for id in pairs(spawnedCustomers) do removeCustomer(id) end
end)

-- ─────────────────────────────────────────────
-- Comportement IA des clients
-- ─────────────────────────────────────────────

CreateThread(function()
    while true do
        local pc       = GetEntityCoords(cache.ped)
        local inZone   = Dealing.isPlayerInAnyZone()
        local anyClose = false

        for id, entry in pairs(spawnedCustomers) do
            if DoesEntityExist(entry.ped) then
                local epc  = GetEntityCoords(entry.ped)
                local dist = #(pc - epc)
                if dist < 60.0 then anyClose = true end

                if entry.state == Dealing.STATE_IDLE then
                    if entry.data.static then
                        -- Client immobile avec blip : c'est au joueur d'aller le voir.
                        if dist <= (Config.CustomerApproachRange or 1.8) + 1.5 then
                            ClearPedTasks(entry.ped)
                            TaskTurnPedToFaceEntity(entry.ped, cache.ped, -1)
                            entry.state     = Dealing.STATE_WAITING
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
                            entry.state     = Dealing.STATE_APPROACH
                            entry.spottedAt = GetGameTimer()
                            attachTarget(entry)
                        end
                    end

                elseif entry.state == Dealing.STATE_APPROACH then
                    if dist <= (Config.CustomerApproachRange or 1.8) + 0.5 then
                        ClearPedTasks(entry.ped)
                        TaskTurnPedToFaceEntity(entry.ped, cache.ped, -1)
                        entry.state     = Dealing.STATE_WAITING
                        entry.waitingAt = GetGameTimer()
                    elseif entry.spottedAt and (GetGameTimer() - entry.spottedAt) > Config.ApproachTimeout * 1000 then
                        -- timeout d'approche (joueur a fui) : un seul envoi
                        entry.state = Dealing.STATE_LEAVING
                        TriggerServerEvent('pop_dealing:refuse', id)
                    end

                elseif entry.state == Dealing.STATE_WAITING then
                    -- Timeout : le client s'en va si pas servi (sauf clients statiques, qui patientent à leur blip)
                    if not entry.data.static and entry.waitingAt and (GetGameTimer() - entry.waitingAt) > (Config.OfferTimeout or 25) * 1000 then
                        entry.state = Dealing.STATE_LEAVING
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
            if DoesEntityExist(entry.ped) and entry.state == Dealing.STATE_WAITING then
                hasActive = true
                local coords = GetEntityCoords(entry.ped)
                if not entry.uiId then
                    entry.uiId = exports.pop_v3dui:Create({
                        coords       = coords,
                        type         = 'prompt',
                        content      = {
                            key   = L('prompt_key'),
                            label = entry.data.drugLabel or L('prompt_default'),
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
