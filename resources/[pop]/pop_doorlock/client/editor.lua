-- pop_doorlock : éditeur admin (commande, panneau NUI, mode visée avec raycast et contour).
-- Le client ne prouve rien : chaque callback admin est revérifié par le serveur (Bridge.IsAdmin).
-- luacheck: globals Doorlock

local RAY_DISTANCE  = 10.0 -- m : portée du raycast depuis la caméra
local RAY_FLAGS     = 16   -- objets
local MAX_LEAVES    = 2    -- battants par porte
local CONFIRM_KEY   = { control = 191, label = 'ENTER' } -- validation de la sélection
local ATTACK_CONTROLS = { 24, 25, 140, 141, 142, 257 }  -- désactivés pendant la visée
local OPEN_RATIO_EPS  = 0.01 -- au-delà, le battant visé est considéré comme ouvert (avertissement)
local PROBE_HASH      = joaat('pop_doorlock_editor_probe') -- entrée temporaire du système natif (lecture d'ouverture)

local aiming = false
local aimGroupId = nil
local selected = {}  -- entités sélectionnées (battants)
local hovered = nil  -- entité visée
local addedGroup = nil -- groupe admin renvoyé après un ajout réussi
local aimSession = 0 -- incrémenté à chaque entrée en visée (ignore une réponse addDoor d'une visée précédente)
local confirming = false -- envoi de admin:addDoor en cours (la boucle de visée continue, les touches sont ignorées)

------------------------------------------------------------------------
-- Utilitaires
------------------------------------------------------------------------

local function hexToRgb(hex)
    local h = (tostring(hex or ''):gsub('#', ''))
    if #h ~= 6 then return 255, 46, 136 end
    return tonumber(h:sub(1, 2), 16) or 255, tonumber(h:sub(3, 4), 16) or 46, tonumber(h:sub(5, 6), 16) or 136
end

local ACCENT_R, ACCENT_G, ACCENT_B = hexToRgb(Config.AccentColor)

local function setOutline(entity, on)
    if not entity or not DoesEntityExist(entity) then return end
    SetEntityDrawOutline(entity, on)
    if on then SetEntityDrawOutlineColor(ACCENT_R, ACCENT_G, ACCENT_B, 255) end
end

local function indexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
    return nil
end

local function notifyResult(ok, okKey, reason)
    if ok then
        Bridge.Notify(L(okKey), 'success')
    else
        Doorlock.NotifyReason(reason)
    end
end

local function rotationToDirection(rot)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local cx = math.abs(math.cos(rx))
    return vec3(-math.sin(rz) * cx, math.cos(rz) * cx, math.sin(rx))
end

------------------------------------------------------------------------
-- Panneau
------------------------------------------------------------------------

local function closeEditor()
    if not Doorlock.editing then return end
    Doorlock.editing = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'pop_doorlock:editor', show = false })
end

local function openEditor()
    if Doorlock.editing or Doorlock.lockpicking then return end
    local data = Callback.Await('pop_doorlock:admin:getGroups')
    if type(data) ~= 'table' then
        Bridge.Notify(L('no_permission'), 'error')
        return
    end
    Doorlock.editing = true
    Doorlock.HidePrompt()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'pop_doorlock:editor', show = true,
        groups = type(data.groups) == 'table' and data.groups or {},
        keys = data.keys == true,
    })
end

RegisterCommand(Config.Command, function()
    CreateThread(openEditor)
end, false)

-- Échap : le bridge a déjà rendu le focus.
Bridge.OnUiClose(function()
    if Doorlock.editing and not aiming then closeEditor() end
end)

------------------------------------------------------------------------
-- Mode visée (Wait(0) uniquement pendant ce mode)
------------------------------------------------------------------------

local function sendAim()
    SendNUIMessage({
        action = 'pop_doorlock:aim', show = true, count = #selected, max = MAX_LEAVES,
        keys = { select = Config.Keys.Interact.label, confirm = CONFIRM_KEY.label, cancel = Config.Keys.Cancel.label },
    })
end

local function setHovered(entity)
    if entity == hovered then return end
    if hovered and not indexOf(selected, hovered) then setOutline(hovered, false) end
    hovered = entity
    if hovered then setOutline(hovered, true) end
end

local function stopAim()
    if not aiming then return end
    aiming = false
    setHovered(nil)
    for _, e in ipairs(selected) do setOutline(e, false) end
    selected = {}
    SendNUIMessage({ action = 'pop_doorlock:aim', show = false })
    if Doorlock.editing then
        SetNuiFocus(true, true)
        if addedGroup then SendNUIMessage({ action = 'pop_doorlock:group', group = addedGroup }) end
    end
    addedGroup = nil
end

--- Vrai si le battant n'est pas fermé. Le battant n'est pas encore dans le système natif :
-- il y est ajouté le temps de lire son ouverture.
-- NOTE: à vérifier en jeu (la lecture juste après AddDoorToSystem peut renvoyer 0 sur certaines portes) :
-- ce n'est qu'un avertissement, la sélection reste possible.
local function isLeafOpen(entity)
    local p = GetEntityCoords(entity)
    AddDoorToSystem(PROBE_HASH, GetEntityModel(entity), p.x, p.y, p.z, false, false, false)
    local ratio = DoorSystemGetOpenRatio(PROBE_HASH) or 0.0
    RemoveDoorFromSystem(PROBE_HASH)
    return math.abs(ratio) > OPEN_RATIO_EPS
end

local function toggleSelection()
    if not hovered or not DoesEntityExist(hovered) then
        Bridge.Notify(L('editor_not_door'), 'error')
        return
    end
    local i = indexOf(selected, hovered)
    if i then
        table.remove(selected, i) -- le contour reste : l'entité est encore visée
    else
        if #selected >= MAX_LEAVES then
            Bridge.Notify(L('editor_max_leaves'), 'error')
            return
        end
        if Doorlock.IsLeafRegistered(GetEntityModel(hovered), GetEntityCoords(hovered)) then
            Bridge.Notify(L('editor_door_exists'), 'error')
            return
        end
        if isLeafOpen(hovered) then Bridge.Notify(L('editor_door_open'), 'warning') end
        selected[#selected + 1] = hovered
    end
    sendAim()
end

local function confirmSelection()
    if #selected == 0 then
        Bridge.Notify(L('editor_not_door'), 'error')
        return
    end
    local leaves, sum = {}, vec3(0.0, 0.0, 0.0)
    for i, entity in ipairs(selected) do
        if not DoesEntityExist(entity) then
            Bridge.Notify(L('editor_not_door'), 'error')
            return
        end
        local model = GetEntityModel(entity)
        local min, max = GetModelDimensions(model)
        local mid = (min + max) / 2
        sum = sum + GetOffsetFromEntityInWorldCoords(entity, mid.x, mid.y, mid.z)
        local p = GetEntityCoords(entity)
        leaves[i] = { model = model, x = p.x, y = p.y, z = p.z }
    end
    local center = sum / #selected

    -- Envoi dans un thread : la boucle de visée continue (contours, contrôles désactivés) pendant l'attente.
    confirming = true
    local groupId, token = aimGroupId, aimSession
    CreateThread(function()
        local ok, res = Callback.Await('pop_doorlock:admin:addDoor', groupId, {
            center = { x = center.x, y = center.y, z = center.z },
            leaves = leaves,
        })
        if token ~= aimSession then return end
        confirming = false
        if not aiming then return end -- visée quittée entre-temps (éditeur fermé, arrêt)
        notifyResult(ok, 'editor_door_added', res)
        if ok then
            addedGroup = type(res) == 'table' and res or nil
            stopAim()
        end
    end)
end

local function aimLoop()
    local probe = nil
    while aiming do
        if not Doorlock.editing then
            stopAim()
            break
        end
        local ped = PlayerPedId()
        for i = 1, #ATTACK_CONTROLS do DisableControlAction(0, ATTACK_CONTROLS[i], true) end
        DisablePlayerFiring(PlayerId(), true)

        -- Raycast asynchrone depuis la caméra : un résultat lu par frame.
        if not probe then
            local from = GetGameplayCamCoord()
            local to = from + rotationToDirection(GetGameplayCamRot(2)) * RAY_DISTANCE
            probe = StartShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, RAY_FLAGS, ped, 4)
        end
        local status, hit, _, _, entity = GetShapeTestResult(probe)
        if status ~= 1 then
            probe = nil
            local valid = status == 2 and (hit == true or hit == 1) and entity and entity ~= 0
                and DoesEntityExist(entity) and GetEntityType(entity) == 3
            setHovered(valid and entity or nil)
        end

        if not IsPauseMenuActive() and not confirming then
            if IsControlJustReleased(0, Config.Keys.Interact.control) then
                toggleSelection()
            elseif IsControlJustReleased(0, CONFIRM_KEY.control) then
                confirmSelection()
            elseif IsControlJustReleased(0, Config.Keys.Cancel.control) then
                stopAim()
            end
        end
        Wait(0)
    end
end

local function startAim(groupId)
    if aiming or not Doorlock.editing then return end
    aiming, aimGroupId, selected, hovered, addedGroup, confirming = true, groupId, {}, nil, nil, false
    aimSession = aimSession + 1
    SetNuiFocus(false, false)
    sendAim()
    CreateThread(aimLoop)
end

------------------------------------------------------------------------
-- Callbacks NUI
------------------------------------------------------------------------

local function int(v)
    return math.tointeger(tonumber(v))
end

RegisterNUICallback('editorSave', function(data, cb)
    if type(data) ~= 'table' then return cb({ ok = false, error = 'editor_invalid' }) end
    -- Mise en forme des types seulement : la validation est faite par le serveur.
    local jobs = {}
    if type(data.jobs) == 'table' then
        for name, grade in pairs(data.jobs) do
            jobs[tostring(name)] = int(grade) or tonumber(grade)
        end
    end
    local ok, res = Callback.Await('pop_doorlock:admin:saveGroup', {
        id = int(data.id),
        label = tostring(data.label or ''),
        locked = data.locked == true,
        distance = tonumber(data.distance),
        security = int(data.security),
        alert = data.alert == true,
        jobs = jobs,
        key = data.key == true,
    })
    notifyResult(ok, 'editor_saved', res)
    if ok then
        cb({ ok = true, group = res })
    else
        cb({ ok = false, error = type(res) == 'string' and res or 'error' })
    end
end)

RegisterNUICallback('editorDelete', function(data, cb)
    local id = type(data) == 'table' and int(data.id)
    if not id then return cb({ ok = false, error = 'editor_invalid' }) end
    local ok, reason = Callback.Await('pop_doorlock:admin:deleteGroup', id)
    notifyResult(ok, 'editor_deleted', reason)
    -- La liste est mise à jour par pop_doorlock:groupRemoved (event removeGroup diffusé par le serveur).
    cb({ ok = ok == true, error = not ok and (type(reason) == 'string' and reason or 'error') or nil })
end)

RegisterNUICallback('editorAddDoor', function(data, cb)
    cb('ok')
    local id = type(data) == 'table' and int(data.id)
    if id then startAim(id) end
end)

RegisterNUICallback('editorRemoveDoor', function(data, cb)
    local doorId = type(data) == 'table' and int(data.doorId)
    if not doorId then return cb({ ok = false, error = 'editor_invalid' }) end
    local ok, res = Callback.Await('pop_doorlock:admin:removeDoor', doorId)
    notifyResult(ok, 'editor_door_removed', res)
    if ok then
        cb({ ok = true, group = res })
    else
        cb({ ok = false, error = type(res) == 'string' and res or 'error' })
    end
end)

RegisterNUICallback('editorGiveKey', function(data, cb)
    local id = type(data) == 'table' and int(data.id)
    if not id then return cb({ ok = false, error = 'editor_invalid' }) end
    local ok, reason = Callback.Await('pop_doorlock:admin:giveKey', id)
    notifyResult(ok, 'editor_key_given', reason)
    if ok then Doorlock.ClearAccess(id) end -- la nouvelle clé donne l'accès : cache à relire
    cb({ ok = ok == true, error = not ok and (type(reason) == 'string' and reason or 'error') or nil })
end)

RegisterNUICallback('editorResetKey', function(data, cb)
    local id = type(data) == 'table' and int(data.id)
    if not id then return cb({ ok = false, error = 'editor_invalid' }) end
    local ok, res = Callback.Await('pop_doorlock:admin:resetKey', id)
    notifyResult(ok, 'editor_key_reset', res)
    if ok then Doorlock.ClearAccess(id) end -- l'ancienne clé ne marche plus (syncGroup le fait aussi)
    if ok then
        cb({ ok = true, group = res })
    else
        cb({ ok = false, error = type(res) == 'string' and res or 'error' })
    end
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if hovered then setOutline(hovered, false) end
    for _, e in ipairs(selected) do setOutline(e, false) end
    aiming, hovered, selected = false, nil, {}
    if Doorlock.editing then
        Doorlock.editing = false
        SetNuiFocus(false, false)
    end
end)
