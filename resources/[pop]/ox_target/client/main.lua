if not lib.checkDependency('ox_lib', '3.21.0', true) then return end

lib.locale()

local utils = require 'client.utils'
local state = require 'client.state'
local options = require 'client.api'.getTargetOptions()

require 'client.debug'
require 'client.defaults'
require 'client.compat.qtarget'

local SendNuiMessage = SendNuiMessage
local GetEntityCoords = GetEntityCoords
local GetEntityType = GetEntityType
local HasEntityClearLosToEntity = HasEntityClearLosToEntity
local GetEntityBoneIndexByName = GetEntityBoneIndexByName
local GetEntityBonePosition_2 = GetEntityBonePosition_2
local GetEntityModel = GetEntityModel
local IsDisabledControlJustPressed = IsDisabledControlJustPressed
local DisableControlAction = DisableControlAction
local DisablePlayerFiring = DisablePlayerFiring
local GetModelDimensions = GetModelDimensions
local GetOffsetFromEntityInWorldCoords = GetOffsetFromEntityInWorldCoords
local currentTarget = {}
local currentMenu
local menuChanged
local menuHistory = {}
local nearbyZones

-- Toggle ox_target, instead of holding the hotkey
local toggleHotkey = GetConvarInt('ox_target:toggleHotkey', 0) == 1
local mouseButton = GetConvarInt('ox_target:leftClick', 1) == 1 and 24 or 25
local debug = GetConvarInt('ox_target:debug', 0) == 1
local vec0 = vec3(0, 0, 0)

---@param option OxTargetOption
---@param distance number
---@param endCoords vector3
---@param entityHit? number
---@param entityType? number
---@param entityModel? number | false
local function shouldHide(option, distance, endCoords, entityHit, entityType, entityModel)
    if option.menuName ~= currentMenu then
        return true
    end

    -- Entité marquée "location uniquement" : on ne garde que les options "rent_*"
    if entityHit and entityHit > 0 and option.name and not option.name:find('^rent_') then
        local entState = Entity(entityHit).state
        if entState and entState.onlyRentTarget then
            return true
        end
    end

    if distance > (option.distance or 7) then
        return true
    end

    if option.groups and not utils.hasPlayerGotGroup(option.groups) then
        return true
    end

    if option.items and not utils.hasPlayerGotItems(option.items, option.anyItem) then
        return true
    end

    local bone = entityModel and option.bones or nil

    if bone then
        ---@cast entityHit number
        ---@cast entityType number
        ---@cast entityModel number

        local _type = type(bone)

        if _type == 'string' then
            local boneId = GetEntityBoneIndexByName(entityHit, bone)

            if boneId ~= -1 and #(endCoords - GetEntityBonePosition_2(entityHit, boneId)) <= 2 then
                bone = boneId
            else
                return true
            end
        elseif _type == 'table' then
            local closestBone, boneDistance

            for j = 1, #bone do
                local boneId = GetEntityBoneIndexByName(entityHit, bone[j])

                if boneId ~= -1 then
                    local dist = #(endCoords - GetEntityBonePosition_2(entityHit, boneId))

                    if dist <= (boneDistance or 1) then
                        closestBone = boneId
                        boneDistance = dist
                    end
                end
            end

            if closestBone then
                bone = closestBone
            else
                return true
            end
        end
    end

    local offset = entityModel and option.offset or nil

    if offset then
        ---@cast entityHit number
        ---@cast entityType number
        ---@cast entityModel number

        if not option.absoluteOffset then
            local min, max = GetModelDimensions(entityModel)
            offset = (max - min) * offset + min
        end

        offset = GetOffsetFromEntityInWorldCoords(entityHit, offset.x, offset.y, offset.z)

        if #(endCoords - offset) > (option.offsetSize or 1) then
            return true
        end
    end

    if option.canInteract then
        local success, resp = pcall(option.canInteract, entityHit, distance, endCoords, option.name, bone)
        return not success or not resp
    end
end

-- Forward-déclaré : défini avec le gestionnaire de curseur de la checklist (plus bas).
-- Permet de relâcher SYNCHRONEMENT le curseur de la checklist avant le test
-- IsNuiFocused() ci-dessous (sinon le ciblage ne démarrerait jamais quand la croix
-- a le focus -> race condition d'origine).
local releaseChecklistFocus

local function startTargeting()
    if releaseChecklistFocus then releaseChecklistFocus() end
    if state.isDisabled() or state.isActive() or IsNuiFocused() or IsPauseMenuActive() then return end

    state.setActive(true)

    local flag = 511
    local hit, entityHit, endCoords, distance, lastEntity, entityType, entityModel, hasTarget, zonesChanged
    local zones = {}

    CreateThread(function()
        local dict, texture = utils.getTexture()
        local lastCoords

        while state.isActive() do
            lastCoords = endCoords == vec0 and lastCoords or endCoords or vec0

            if debug then
                DrawMarker(28, lastCoords.x, lastCoords.y, lastCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.2, 0.2,
                    0.2,
                    ---@diagnostic disable-next-line: param-type-mismatch
                    255, 42, 24, 100, false, false, 0, true, false, false, false)
            end

            utils.drawZoneSprites(dict, texture)
            DisablePlayerFiring(cache.playerId, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            if state.isNuiFocused() then
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)

                if not hasTarget or options and IsDisabledControlJustPressed(0, 25) then
                    state.setNuiFocus(false, false)
                end
            elseif hasTarget and IsDisabledControlJustPressed(0, mouseButton) then
                state.setNuiFocus(true, true)
            end

            Wait(0)
        end

        SetStreamedTextureDictAsNoLongerNeeded(dict)
    end)

    while state.isActive() do
        if not state.isNuiFocused() and lib.progressActive() then
            state.setActive(false)
            break
        end

        local playerCoords = GetEntityCoords(cache.ped)
        hit, entityHit, endCoords = lib.raycast.fromCamera(flag, 4, 20)
        distance = #(playerCoords - endCoords)

        if entityHit ~= 0 and entityHit ~= lastEntity then
            local success, result = pcall(GetEntityType, entityHit)
            entityType = success and result or 0
        end

        if entityType == 0 then
            local _flag = flag == 511 and 26 or 511
            local _hit, _entityHit, _endCoords = lib.raycast.fromCamera(_flag, 4, 20)
            local _distance = #(playerCoords - _endCoords)

            if _distance < distance then
                flag, hit, entityHit, endCoords, distance = _flag, _hit, _entityHit, _endCoords, _distance

                if entityHit ~= 0 then
                    local success, result = pcall(GetEntityType, entityHit)
                    entityType = success and result or 0
                end
            end
        end

        nearbyZones, zonesChanged = utils.getNearbyZones(endCoords)

        local entityChanged = entityHit ~= lastEntity
        local newOptions = (zonesChanged or entityChanged or menuChanged) and true

        if entityHit > 0 and entityChanged then
            currentMenu = nil

            if flag ~= 511 then
                local success, result = pcall(HasEntityClearLosToEntity, entityHit, cache.ped, 7)
                entityHit = (success and result) and entityHit or 0
            end

            if lastEntity ~= entityHit and debug then
                if lastEntity then
                    SetEntityDrawOutline(lastEntity, false)
                end

                if entityType ~= 1 then
                    SetEntityDrawOutline(entityHit, true)
                end
            end

            if entityHit > 0 then
                local success, result = pcall(GetEntityModel, entityHit)
                entityModel = success and result
            end
        end

        if hasTarget and (zonesChanged or entityChanged and hasTarget > 1) then
            SendNuiMessage('{"event": "leftTarget"}')

            if entityChanged then options:wipe() end

            if debug and lastEntity > 0 then SetEntityDrawOutline(lastEntity, false) end

            hasTarget = false
        end

        if newOptions and entityModel and entityHit > 0 then
            options:set(entityHit, entityType, entityModel)
        end

        lastEntity = entityHit
        currentTarget.entity = entityHit
        currentTarget.coords = endCoords
        currentTarget.distance = distance
        local hidden = 0
        local totalOptions = 0

        for k, v in pairs(options) do
            local optionCount = #v
            local dist = k == '__global' and 0 or distance
            totalOptions += optionCount

            for i = 1, optionCount do
                local option = v[i]
                local hide = shouldHide(option, dist, endCoords, entityHit, entityType, entityModel)

                if option.hide ~= hide then
                    option.hide = hide
                    newOptions = true
                end

                if hide then hidden += 1 end
            end
        end

        if zonesChanged then table.wipe(zones) end

        for i = 1, #nearbyZones do
            local zoneOptions = nearbyZones[i].options
            local optionCount = #zoneOptions
            totalOptions += optionCount
            zones[i] = zoneOptions

            for j = 1, optionCount do
                local option = zoneOptions[j]
                local hide = shouldHide(option, distance, endCoords, entityHit)

                if option.hide ~= hide then
                    option.hide = hide
                    newOptions = true
                end

                if hide then hidden += 1 end
            end
        end

        if newOptions then
            if hasTarget == 1 and options.size > 1 then
                hasTarget = true
            end

            if hasTarget and hidden == totalOptions then
                if hasTarget and hasTarget ~= 1 then
                    hasTarget = false
                    SendNuiMessage('{"event": "leftTarget"}')
                end
            elseif menuChanged or hasTarget ~= 1 and hidden ~= totalOptions then
                hasTarget = options.size

                if currentMenu and options.__global[1]?.name ~= 'builtin:goback' then
                    table.insert(options.__global, 1,
                        {
                            icon = 'fa-solid fa-circle-chevron-left',
                            label = locale('go_back'),
                            name = 'builtin:goback',
                            menuName = currentMenu,
                            openMenu = 'home'
                        })
                end

                SendNuiMessage(json.encode({
                    event = 'setTarget',
                    options = options,
                    zones = zones,
                }, { sort_keys = true }))
            end

            menuChanged = false
        end

        if toggleHotkey and IsPauseMenuActive() then
            state.setActive(false)
        end

        if not hasTarget or hasTarget == 1 then
            flag = flag == 511 and 26 or 511
        end

        Wait(hit and 50 or 100)
    end

    if lastEntity and debug then
        SetEntityDrawOutline(lastEntity, false)
    end

    state.setNuiFocus(false)
    SendNuiMessage('{"event": "visible", "state": false}')
    table.wipe(currentTarget)
    options:wipe()

    if nearbyZones then table.wipe(nearbyZones) end
end

do
    ---@type KeybindProps
    local keybind = {
        name = 'ox_target',
        defaultKey = GetConvar('ox_target:defaultHotkey', 'LMENU'),
        defaultMapper = 'keyboard',
        description = locale('toggle_targeting'),
    }

    if toggleHotkey then
        function keybind:onPressed()
            if state.isActive() then
                return state.setActive(false)
            end

            return startTargeting()
        end
    else
        keybind.onPressed = startTargeting

        function keybind:onReleased()
            state.setActive(false)
        end
    end

    lib.addKeybind(keybind)
end

---@generic T
---@param option T
---@param server? boolean
---@return T
local function getResponse(option, server)
    local response = table.clone(option)
    response.entity = currentTarget.entity
    response.zone = currentTarget.zone
    response.coords = currentTarget.coords
    response.distance = currentTarget.distance

    if server then
        response.entity = response.entity ~= 0 and NetworkGetEntityIsNetworked(response.entity) and
            NetworkGetNetworkIdFromEntity(response.entity) or 0
    end

    response.icon = nil
    response.groups = nil
    response.items = nil
    response.canInteract = nil
    response.onSelect = nil
    response.export = nil
    response.event = nil
    response.serverEvent = nil
    response.command = nil

    return response
end

RegisterNUICallback('select', function(data, cb)
    cb(1)

    local zone = data[3] and nearbyZones[data[3]]

    ---@type OxTargetOption?
    local option = zone and zone.options[data[2]] or options[data[1]][data[2]]

    if option then
        if option.openMenu then
            local menuDepth = #menuHistory

            if option.name == 'builtin:goback' then
                option.menuName = option.openMenu
                option.openMenu = menuHistory[menuDepth]

                if menuDepth > 0 then
                    menuHistory[menuDepth] = nil
                end
            else
                menuHistory[menuDepth + 1] = currentMenu
            end

            menuChanged = true
            currentMenu = option.openMenu ~= 'home' and option.openMenu or nil

            options:wipe()
        else
            state.setNuiFocus(false)
        end

        currentTarget.zone = zone?.id

        if option.onSelect then
            option.onSelect(option.qtarget and currentTarget.entity or getResponse(option))
        elseif option.export then
            exports[option.resource or zone.resource][option.export](nil, getResponse(option))
        elseif option.event then
            TriggerEvent(option.event, getResponse(option))
        elseif option.serverEvent then
            TriggerServerEvent(option.serverEvent, getResponse(option, true))
        elseif option.command then
            ExecuteCommand(option.command)
        end

        if option.menuName == 'home' then return end
    end

    if not option?.openMenu and IsNuiFocused() then
        state.setActive(false)
    end
end)

local isChecklistVisible = false
local currentVehicle = nil
local currentChecklist = nil

-- Pneus à changer, mémorisés PAR PLAQUE côté client (suivi NON destructif : on
-- n'éclate PAS le pneu pour de vrai, sinon le véhicule roulerait sur la jante et
-- resterait quasi immobile). [plaque] = { [0..3] = true }. Généré à la 1re analyse,
-- les pneus restants persistent après fermeture/réanalyse, ceux changés sont retirés,
-- et tout est purgé quand le véhicule est 100% réparé.
local tyreNeeds = {}
local function normPlate(p) return (tostring(p or '')):gsub('^%s*(.-)%s*$', '%1') end

-- Notification "à gauche" : la ressource `notification` (export ShowNotify) est le
-- système utilisé par tab_inventory. Le flux mécano passait par esx:showNotification,
-- qui n'est PAS routé vers cette ressource -> aucun retour visible pour le joueur.
local function mechNotify(message, icon)
    exports['notification']:ShowNotify({
        message = message,
        icon = icon or 'fas fa-wrench',
        duration = 5000
    })
end

-- =====================================================================
--  Curseur de la checklist (focus NUI géré en interne).
--  Avant : on utilisait exports.ox_lib:setExternalMouseToggle, un 2e gestionnaire
--  de focus qui entrait en conflit avec le focus natif du ciblage ox_target
--  (startTargeting baile sur IsNuiFocused()). Résultat : race condition sur Alt,
--  ciblage qui ne démarre pas (donc "Réparer la carrosserie" ne part jamais et
--  aucune notif) et croix non cliquable.
--
--  Modèle (intégré à l'état du ciblage) :
--   * checklist ouverte = curseur "armé" (mais pas pris : caméra libre pour réparer).
--   * CLIC GAUCHE (hors ciblage) -> prend le curseur pour cliquer la croix.
--   * ALT / ÉCHAP -> relâche le curseur (et permet de viser les pièces).
--   * Pendant le ciblage ox_target, on ne prend jamais le curseur (l'œil gère le sien).
-- =====================================================================
local checklistMouseArmed = false   -- la checklist est ouverte
local checklistFocused = false      -- on détient actuellement le curseur

-- (forward-déclaré plus haut pour startTargeting)
releaseChecklistFocus = function()
    if checklistFocused then
        checklistFocused = false
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end

local function setChecklistMouse(armed)
    checklistMouseArmed = armed and true or false
    if not armed then releaseChecklistFocus() end
    -- Remonte les notifications (ressource `notification`) au-dessus de la checklist
    -- tant qu'elle est affichée, sinon elles passent derrière (rendu ox_target dessus).
    TriggerEvent('notification:client:setRaised', checklistMouseArmed)
end

CreateThread(function()
    while true do
        if checklistMouseArmed then
            if state.isActive() then
                -- Ciblage en cours : l'œil ox_target gère son propre focus.
                if checklistFocused then releaseChecklistFocus() end
            elseif not checklistFocused then
                -- 24 = clic gauche (INPUT_ATTACK) -> prendre le curseur pour la croix.
                if IsControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 24) then
                    checklistFocused = true
                    SetCursorLocation(0.5, 0.5)
                    SetNuiFocus(true, true)
                    SetNuiFocusKeepInput(true)
                end
            else
                -- Curseur pris : on bloque caméra + tir (le clic ne doit pas tirer),
                -- et Alt/Échap le relâchent.
                DisableControlAction(0, 1, true)   -- look LR
                DisableControlAction(0, 2, true)   -- look UD
                DisableControlAction(0, 24, true)  -- attack
                DisableControlAction(0, 25, true)  -- aim
                DisablePlayerFiring(cache.playerId, true)
                if IsControlJustPressed(0, 19) or IsDisabledControlJustPressed(0, 19)
                    or IsControlJustPressed(0, 340) or IsDisabledControlJustPressed(0, 340)
                    or IsControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 177) then
                    releaseChecklistFocus()
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

local wheelBones = {
    [0] = 'wheel_lf',
    [1] = 'wheel_rf',
    [2] = 'wheel_lr',
    [3] = 'wheel_rr'
}

local wheelLabels = {
    [0] = 'avant gauche',
    [1] = 'avant droit',
    [2] = 'arrière gauche',
    [3] = 'arrière droit'
}

-- Checks if all items are done and completely restores vehicle
local function CheckIfChecklistCompleted(veh)
    local allDone = true
    for _, item in ipairs(currentChecklist) do
        if not item.done then
            allDone = false
            break
        end
    end
    if allDone then
        SetVehicleFixed(veh)
        -- Filet anti-blocage : on s'assure que le véhicule est conduisible (un freeze
        -- résiduel du minigame de pneu laissait la voiture immobile).
        FreezeEntityPosition(veh, false)
        SetVehicleUndriveable(veh, false)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        SetVehicleDirtLevel(veh, 0.0)
        tyreNeeds[normPlate(GetVehicleNumberPlateText(veh))] = nil

        currentChecklist = nil
        currentVehicle = nil
        isChecklistVisible = false
        setChecklistMouse(false)
        SendNuiMessage(json.encode({
            event = 'showChecklist',
            show = false
        }))
        mechNotify("Véhicule entièrement réparé et <span style='color:#2ecc71; font-weight:bold;'>remis à neuf</span> !", 'fas fa-circle-check')
    end
end

-- Exposé pour que d'autres ressources (ex: target "Analyser les dégâts") puissent
-- masquer leur option quand une checklist est déjà ouverte (évite de la réinitialiser).
exports('isMechanicChecklistActive', function()
    return isChecklistVisible == true
end)

exports('setMechanicChecklistHidden', function(hidden)
    if isChecklistVisible then
        if hidden then
            SendNuiMessage(json.encode({ event = 'showChecklist', show = false }))
        else
            SendNuiMessage(json.encode({ event = 'showChecklist', show = true, items = currentChecklist }))
        end
    end
end)


-- Cet événement est appelé par tab_inventory quand le joueur a monté une roue avec succès
RegisterNetEvent('vg_engine:client:wheelMountedChecklist', function(veh, wheel)
    -- Répare visuellement la crevaison si elle existait
    if IsVehicleTyreBurst(veh, wheel, false) then
        SetVehicleTyreFixed(veh, wheel)
    end
    
    -- Valide la tâche dans la checklist du mécano si elle est ouverte
    if currentChecklist and currentVehicle == veh then
        for _, item in ipairs(currentChecklist) do
            if item.id == 'wheel_' .. wheel then
                item.done = true
                item.pending = nil
                mechNotify("Tâche validée : <span style='color:#2ecc71; font-weight:bold;'>" .. item.label .. "</span>", 'fas fa-check-circle')
                break
            end
        end
        -- Retire ce pneu du suivi persistant
        local pk = normPlate(GetVehicleNumberPlateText(veh))
        if tyreNeeds[pk] then tyreNeeds[pk][wheel] = nil end
        SendNuiMessage(json.encode({
            event = 'showChecklist',
            show = true,
            items = currentChecklist
        }))
        CheckIfChecklistCompleted(veh)
    end
end)

-- 2. Moteur : AUCUN bouton "Réparer le moteur". Le joueur sait où est le moteur ;
-- il ouvre le capot (target "Ouvrir le capot") et remplace lui-même les pistons
-- cassés. Le serveur vérifie que tous les pistons sont là et coche la case ci-dessous.
RegisterNetEvent('vg_engine:client:engineRepaired', function(plate)
    local veh = currentVehicle
    if not veh or not DoesEntityExist(veh) or not currentChecklist then return end
    -- Vérifie que c'est bien le véhicule analysé (plaques normalisées).
    local vp = GetVehicleNumberPlateText(veh) or ''
    vp = vp:gsub('^%s*(.-)%s*$', '%1')
    local p = (plate or ''):gsub('^%s*(.-)%s*$', '%1')
    if p ~= '' and p ~= vp then return end
    -- Cherche une tâche moteur NON encore validée.
    local found = false
    for _, item in ipairs(currentChecklist) do
        if item.id == 'engine' and not item.done then
            item.done = true
            found = true
            mechNotify("Tâche validée : <span style='color:#2ecc71; font-weight:bold;'>" .. item.label .. "</span>", 'fas fa-check-circle')
            break
        end
    end
    if not found then return end
    SetVehicleEngineHealth(veh, 1000.0)
    SendNuiMessage(json.encode({
        event = 'showChecklist',
        show = true,
        items = currentChecklist
    }))
    CheckIfChecklistCompleted(veh)
    mechNotify("<span style='color:#2ecc71; font-weight:bold;'>Moteur réparé.</span>", 'fas fa-circle-check')
end)

-- 3. Bodywork option
exports.ox_target:addGlobalVehicle({
    {
        name = 'repair_bodywork_checklist',
        icon = 'fas fa-hammer',
        label = 'Réparer la carrosserie',
        distance = 2.0,
        canInteract = function(entity, distance, coords, name, boneId)
            if not currentVehicle or currentVehicle ~= entity then return false end
            if not currentChecklist then return false end
            for _, item in ipairs(currentChecklist) do
                -- item.pending : déjà cliqué et réparation en cours -> on ne re-propose pas.
                if item.id == 'bodywork' and not item.done and not item.pending then
                    return true
                end
            end
            return false
        end,
        onSelect = function(data)
            -- Cliqué -> on masque l'option (pending) le temps de la vérif + réparation.
            if currentChecklist then
                for _, item in ipairs(currentChecklist) do
                    if item.id == 'bodywork' then item.pending = true break end
                end
            end
            -- La réparation carrosserie nécessite une pièce de carrosserie : le serveur
            -- vérifie l'inventaire (autorisé/bloqué).
            TriggerServerEvent('vg_engine:server:tryRepairBody')
        end
    }
})

local function setBodyPending(value)
    if not currentChecklist then return end
    for _, item in ipairs(currentChecklist) do
        if item.id == 'bodywork' then item.pending = value break end
    end
end

-- Pas de pièce de carrosserie en inventaire : on relâche l'option (retry possible).
RegisterNetEvent('vg_engine:client:bodyRepairBlocked', function()
    setBodyPending(nil)
    mechNotify("Il vous faut une <span style='color:#E74C3C; font-weight:bold;'>pièce de carrosserie</span>.", 'fas fa-triangle-exclamation')
end)

-- Pièce disponible : réparation, consommation de la pièce, validation de la tâche.
RegisterNetEvent('vg_engine:client:bodyRepairAllowed', function()
    local veh = currentVehicle
    if not veh or not DoesEntityExist(veh) then return end
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_VEHICLE_MECHANIC', 0, true)
    if lib.progressBar({
        duration = 8000,
        label = 'Réparation de la carrosserie...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true }
    }) then
        ClearPedTasks(ped)
        TriggerServerEvent('vg_engine:server:consumeBodyPart')
        -- Efface les déformations visibles (bosses) en préservant les dégâts moteur
        -- et réservoir (sinon SetVehicleFixed réparerait tout). Les pneus restants sont
        -- suivis via tyreNeeds (non destructif), donc inutile de les ré-éclater ici.
        local eng = GetVehicleEngineHealth(veh)
        local pet = GetVehiclePetrolTankHealth(veh)
        SetVehicleFixed(veh)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehicleEngineHealth(veh, eng)
        SetVehiclePetrolTankHealth(veh, pet)
        if currentChecklist then
            for _, item in ipairs(currentChecklist) do
                if item.id == 'bodywork' then
                    item.done = true
                    item.pending = nil
                    mechNotify("Tâche validée : <span style='color:#2ecc71; font-weight:bold;'>" .. item.label .. "</span>", 'fas fa-check-circle')
                    break
                end
            end
        end
        SendNuiMessage(json.encode({
            event = 'showChecklist',
            show = true,
            items = currentChecklist
        }))
        CheckIfChecklistCompleted(veh)
    else
        ClearPedTasks(ped)
        setBodyPending(nil) -- annulé -> on peut recliquer
    end
end)

RegisterNetEvent('tab_hud:client:showDamageChecklist', function(show, vehicle)
    if not show then
        isChecklistVisible = false
        currentChecklist = nil
        currentVehicle = nil
        setChecklistMouse(false)
        SendNuiMessage(json.encode({
            event = 'showChecklist',
            show = false
        }))
        return
    end

    local veh = vehicle
    if not veh or not DoesEntityExist(veh) then
        veh = currentTarget.entity
    end
    if not veh or not DoesEntityExist(veh) then
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        veh = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    end

    if not veh or not DoesEntityExist(veh) then return end

    isChecklistVisible = true
    currentVehicle = veh

    currentChecklist = {}
    local plate = GetVehicleNumberPlateText(veh)
    local seed = 0
    if plate then
        for i = 1, #plate do
            seed = seed + string.byte(plate:sub(i, i))
        end
    end
    math.randomseed(seed)

    local bodyHealth = GetVehicleBodyHealth(veh)
    local engineHealth = GetVehicleEngineHealth(veh)
    local bodyDamaged = bodyHealth < 1000.0 or IsVehicleDamaged(veh)

    local pkey = normPlate(plate)
    if not tyreNeeds[pkey] then
        local t = {}
        for i = 0, 3 do
            if bodyDamaged and (math.random(1, 100) > 50) then t[i] = true end
        end
        tyreNeeds[pkey] = t
    end
    for i = 0, 3 do
        if IsVehicleTyreBurst(veh, i, false) then tyreNeeds[pkey][i] = true end
    end
    for i = 0, 3 do
        if tyreNeeds[pkey][i] then
            table.insert(currentChecklist, {
                id = 'wheel_' .. i,
                label = 'Changer pneu ' .. wheelLabels[i],
                done = false
            })
        end
    end

    if engineHealth < 1000.0 then
        table.insert(currentChecklist, {
            id = 'engine',
            label = 'Réparer le moteur',
            done = false
        })
        TriggerServerEvent('vg_engine:server:breakPiston', plate)
    end

    if bodyDamaged then
        table.insert(currentChecklist, {
            id = 'bodywork',
            label = 'Réparer la carrosserie',
            done = false
        })
    end

    if #currentChecklist == 0 then
        mechNotify("Le véhicule ne présente <span style='color:#2ecc71; font-weight:bold;'>aucun dégât</span> à réparer !", 'fas fa-circle-check')
        isChecklistVisible = false
        currentVehicle = nil
        currentChecklist = nil
        return
    end

    setChecklistMouse(true)
    SendNuiMessage(json.encode({
        event = 'showChecklist',
        show = true,
        items = currentChecklist
    }))
end)

RegisterNUICallback('checklistLayout', function(data, cb)
    if isChecklistVisible and data and data.bottom then
        TriggerEvent('notification:client:setRaised', true, math.floor(data.bottom + 0.5))
    end
    cb('ok')
end)

RegisterNUICallback('closeChecklist', function(data, cb)
    local hadTasks = currentChecklist ~= nil
    isChecklistVisible = false
    currentChecklist = nil
    currentVehicle = nil
    setChecklistMouse(false)
    SendNuiMessage(json.encode({ event = 'showChecklist', show = false }))
    if hadTasks then
        mechNotify("Analyse du véhicule <span style='color:#ECA95D; font-weight:bold;'>fermée</span>.", 'fas fa-clipboard-check')
    end
    cb('ok')
end)
