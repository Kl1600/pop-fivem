-- TAB Doorlock | Doorbuilder | hub de gestion + sélection d'entités via raycast --

local selecting = false   -- mode sélection in-game (raycast) actif
local formOpen  = false   -- formulaire d'attribution affiché (gèle le raycast)
local selected  = {}      -- [entityHandle] = { model, coords{x,y,z} }

-- =====================================================================
--  NOTIF LOCALE
-- =====================================================================
local function notifyLocal(text, kind)
    if GetResourceState('pop_notify') == 'started' then
        local icon = (kind == 'error') and 'fas fa-triangle-exclamation' or 'fas fa-door-open'
        exports['pop_notify']:ShowNotify({ icon = icon, message = text, duration = 3000 })
    elseif ESX and ESX.ShowNotification then
        ESX.ShowNotification(text)
    elseif Config.ESX_Notify and GetResourceState('esx_notify') == 'started' then
        exports['esx_notify']:Notify(kind or 'info', 3000, text)
    else
        Config.Custom_Notify(text, 3000, kind or 'info')
    end
end
RegisterNetEvent('pop_doorlock:notifyLocal', notifyLocal)

-- =====================================================================
--  HELPERS RAYCAST / DESSIN
-- =====================================================================
local function rotationToDirection(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function raycastFromCam(dist)
    local camCoord = GetGameplayCamCoord()
    local camRot   = GetGameplayCamRot(2)
    local dir      = rotationToDirection(camRot)
    local dest     = camCoord + (dir * dist)
    local handle = StartShapeTestRay(
        camCoord.x, camCoord.y, camCoord.z,
        dest.x, dest.y, dest.z,
        16, PlayerPedId(), 0    -- 16 = objets / props (portes)
    )
    local _, hit, _, _, entity = GetShapeTestResult(handle)
    return hit == 1, entity
end

local function drawText2D(text, x, y, scale)
    SetTextFont(4)
    SetTextScale(scale or 0.4, scale or 0.4)
    SetTextColour(255, 255, 255, 220)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

local function drawText3D(coords, text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextFont(4)
    SetTextScale(0.32, 0.32)
    SetTextColour(255, 255, 255, 220)
    SetTextCentre(true)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

local function drawMarker(coords, c)
    DrawMarker(28, coords.x, coords.y, coords.z, 0,0,0, 0,0,0,
        0.35, 0.35, 0.35, c.r, c.g, c.b, 140, false, false, 2, false, nil, nil, false)
end

local function countSelected()
    local n = 0
    for _ in pairs(selected) do n = n + 1 end
    return n
end

-- =====================================================================
--  HUB DE GESTION (NUI)
-- =====================================================================
local function openHub()
    ESX.TriggerServerCallback('pop_doorlock:getGroups', function(groups)
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'hub', groups = groups })
    end)
end

local function refreshHub()
    ESX.TriggerServerCallback('pop_doorlock:getGroups', function(groups)
        SendNUIMessage({ action = 'hub', groups = groups })
    end)
end

-- =====================================================================
--  DÉTAIL / CONFIG D'UN GROUPE (NUI)
-- =====================================================================
local currentDetailGid = nil   -- gid actuellement affiché dans le panneau de config (ou nil)

local function openDetail(gid)
    ESX.TriggerServerCallback('pop_doorlock:getGroupDetail', function(detail)
        if not detail then
            currentDetailGid = nil
            openHub()
            return
        end
        currentDetailGid = gid
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'detail', detail = detail })
    end, gid)
end

local function refreshDetail()
    if not currentDetailGid then return end
    openDetail(currentDetailGid)
end

-- =====================================================================
--  MODE SÉLECTION (raycast)
-- =====================================================================
local function openForm()
    if countSelected() == 0 then
        notifyLocal(Config.Translate['builder_empty'], 'error')
        return
    end
    formOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'form', count = countSelected() })
end

local function stopSelection()
    selecting = false
    formOpen = false
    selected = {}
    SetNuiFocus(false, false)
end

local function selectionLoop()
    CreateThread(function()
        while selecting do
            Wait(0)

            if formOpen then goto continue end

            drawText2D('~w~DOORBUILDER~s~  |  Sélectionnées : ~g~' .. countSelected(), 0.36, 0.92, 0.45)
            drawText2D('[E] Sélectionner/Retirer    [ENTER] Valider & attribuer la clé    [X] Annuler', 0.265, 0.95, 0.38)

            for _, info in pairs(selected) do
                drawMarker(info.coords, Config.Builder.SelectedColor)
            end

            local hit, entity = raycastFromCam(Config.Builder.RayDistance)
            local aimedValid = false
            if hit and entity and entity ~= 0 and DoesEntityExist(entity)
               and not IsEntityAPed(entity) and not IsEntityAVehicle(entity) then
                aimedValid = true
                local coords  = GetEntityCoords(entity)
                local model   = GetEntityModel(entity)
                local already = selected[entity] ~= nil
                drawMarker(coords, already and Config.Builder.SelectedColor or Config.Builder.MarkerColor)
                drawText3D(coords + vector3(0,0,0.5),
                    ('~w~%s~s~\n%s'):format(model, already and '~g~SÉLECTIONNÉE' or '~w~[E] sélectionner'))

                if IsControlJustReleased(0, Config.Builder.SelectKey) then
                    if already then
                        selected[entity] = nil
                        notifyLocal((Config.Translate['builder_removed']):format(countSelected()), 'info')
                    else
                        selected[entity] = { model = model, coords = { x = coords.x, y = coords.y, z = coords.z } }
                        notifyLocal((Config.Translate['builder_added']):format(countSelected()), 'success')
                    end
                end
            end

            if not aimedValid and IsControlJustReleased(0, Config.Builder.SelectKey) then
                notifyLocal(Config.Translate['builder_not_door'], 'error')
            end

            if IsControlJustReleased(0, Config.Builder.ValidateKey) then
                openForm()
            end

            if IsControlJustReleased(0, Config.Builder.CancelKey) then
                stopSelection()
                notifyLocal(Config.Translate['builder_cancel'], 'info')
            end

            ::continue::
        end
    end)
end

-- =====================================================================
--  EVENTS SERVEUR
-- =====================================================================
RegisterNetEvent('pop_doorlock:builder:open', function()
    if selecting then return end
    notifyLocal(Config.Translate['builder_open'], 'success')
    openHub()
end)

RegisterNetEvent('pop_doorlock:builder:denied', function()
    notifyLocal(Config.Translate['builder_no_perm'], 'error')
end)

RegisterNetEvent('pop_doorlock:builder:saved', function(label, count)
    notifyLocal((Config.Translate['builder_saved']):format(label, count), 'success')
end)

RegisterNetEvent('pop_doorlock:builder:deleted', function(label)
    if label then
        notifyLocal((Config.Translate['builder_deleted']):format(label), 'success')
    else
        notifyLocal(Config.Translate['builder_delete_fail'], 'error')
    end
end)

RegisterNetEvent('pop_doorlock:keyResult', function(label, isRegen)
    if label then
        notifyLocal((isRegen and Config.Translate['key_regenerated'] or Config.Translate['key_received']):format(label), 'success')
    else
        notifyLocal(Config.Translate['key_fail'], 'error')
    end
end)

-- un groupe a été modifié (label/distance/locked/clé) -> on rafraîchit le panneau ouvert
RegisterNetEvent('pop_doorlock:builder:updated', function(gid)
    if currentDetailGid == gid then refreshDetail() end
end)

-- une porte a été retirée d'un groupe -> on rafraîchit, ou on revient au hub si le groupe a disparu
RegisterNetEvent('pop_doorlock:builder:doorRemoved', function(gid, emptied)
    if currentDetailGid ~= gid then return end
    if emptied then
        currentDetailGid = nil
        notifyLocal(Config.Translate['builder_group_emptied'], 'info')
        openHub()
    else
        refreshDetail()
    end
end)

-- =====================================================================
--  CALLBACKS NUI
-- =====================================================================
-- Hub : "Créer un groupe" -> passe en mode sélection in-game
RegisterNUICallback('startSelection', function(_, cb)
    SetNuiFocus(false, false)
    selected = {}
    selecting = true
    formOpen = false
    selectionLoop()
    notifyLocal(Config.Translate['builder_select'], 'info')
    cb('ok')
end)

-- Hub : supprimer un groupe (depuis la liste ou depuis le panneau de détail)
RegisterNUICallback('deleteGroup', function(data, cb)
    if data and data.gid then
        TriggerServerEvent('pop_doorlock:builder:delete', data.gid)
        if currentDetailGid == data.gid then currentDetailGid = nil end
        -- petit délai pour laisser le serveur répondre avant de rafraîchir
        SetTimeout(250, openHub)
    end
    cb('ok')
end)

-- Hub : fermer
RegisterNUICallback('closeHub', function(_, cb)
    currentDetailGid = nil
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Liste : ouvrir le panneau de configuration d'un groupe
RegisterNUICallback('openDetail', function(data, cb)
    if data and data.gid then openDetail(data.gid) end
    cb('ok')
end)

-- Détail : retour au hub
RegisterNUICallback('backToHub', function(_, cb)
    currentDetailGid = nil
    openHub()
    cb('ok')
end)

-- Détail : enregistrer les modifications (label / distance / verrouillage par défaut)
RegisterNUICallback('updateGroup', function(data, cb)
    if data and data.gid then
        TriggerServerEvent('pop_doorlock:builder:updateGroup', {
            gid      = data.gid,
            label    = data.label,
            distance = tonumber(data.distance) or 2.5,
            locked   = data.locked ~= false,
        })
        SetTimeout(250, refreshDetail)
    end
    cb('ok')
end)

-- Détail : retirer une porte précise du groupe
RegisterNUICallback('removeDoor', function(data, cb)
    if data and data.gid and data.doorId then
        TriggerServerEvent('pop_doorlock:builder:removeDoor', { gid = data.gid, doorId = data.doorId })
    end
    cb('ok')
end)

-- Détail : attribuer une clé à un groupe qui n'en a pas
RegisterNUICallback('assignKey', function(data, cb)
    if data and data.gid then
        TriggerServerEvent('pop_doorlock:builder:assignkey', data.gid)
        SetTimeout(250, refreshDetail)
    end
    cb('ok')
end)

-- Détail : régénérer la clé (invalide les clés déjà distribuées)
RegisterNUICallback('regenKey', function(data, cb)
    if data and data.gid then
        TriggerServerEvent('pop_doorlock:builder:regenkey', data.gid)
        SetTimeout(250, refreshDetail)
    end
    cb('ok')
end)

-- Formulaire : enregistrer le groupe
RegisterNUICallback('saveForm', function(data, cb)
    local doors = {}
    for _, info in pairs(selected) do
        doors[#doors + 1] = { model = info.model, coords = info.coords }
    end
    TriggerServerEvent('pop_doorlock:builder:save', {
        label    = data.label,
        distance = tonumber(data.distance) or 2.5,
        locked   = data.locked ~= false,
        doors    = doors,
    })
    stopSelection()
    cb('ok')
end)

-- Hub : récupérer (give) la clé d'un groupe
RegisterNUICallback('giveKey', function(data, cb)
    if data and data.gid then
        TriggerServerEvent('pop_doorlock:builder:givekey', data.gid)
    end
    cb('ok')
end)

-- Formulaire : annuler -> revenir au mode sélection
RegisterNUICallback('cancelForm', function(_, cb)
    formOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)
