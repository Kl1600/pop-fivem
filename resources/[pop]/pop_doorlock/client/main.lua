-- pop_doorlock : cache des portes, système natif GTA, boucle de proximité unique,
-- prompt avec icône d'état, zones target, verrouillage, alerte de crochetage, export.

local PROXIMITY_RADIUS = 30.0   -- m : portes surveillées (liste "nearby" recalculée chaque seconde)
local ACCESS_RADIUS    = 10.0   -- m : en dessous, on demande l'accès au serveur si besoin
local ACCESS_TTL       = 30000  -- ms : durée de validité du cache d'accès
local ACCESS_RETRY     = 5000   -- ms : nouvel essai après un timeout du callback d'accès
local SCAN_INTERVAL    = 1000   -- ms : recalcul de la liste "nearby"
local PRESS_DEBOUNCE   = 500    -- ms : anti-rebond après un appui sur la touche d'interaction
local STATE_SPAM_S     = 1      -- s : affiché pour le refus "cooldown" de setState (anti-spam serveur de 500 ms)
local FOB_DICT, FOB_CLIP = 'anim@mp_player_intmenu@key_fob@', 'fob_click'
local ALERT_BLIP = { sprite = 161, colour = 1, scale = 1.2 }

-- Table partagée par les fichiers client (main.lua chargé en premier).
Doorlock = {
    doors = {},      -- [doorId] = { id, groupId, center = vec3, locked, hashes = {}, leaves = { { model, coords } }, double }
    groups = {},     -- [groupId] = { security, distance }
    access = {},     -- [groupId] = { value = bool|nil, t = GetGameTimer() }
    closest = { id = nil, dist = -1.0, locked = false }, -- dernier calcul de la boucle (export)
    lockpicking = false, -- crochetage en cours (client/lockpick.lua)
    editing = false,     -- éditeur ouvert (client/editor.lua)
    toggling = false,    -- demande setState en cours
    dirty = true,        -- force le recalcul de "nearby" au prochain tour
}

local TARGET_MODE = Bridge.TargetSystem ~= 'prompt'
local accessPending = {} -- [groupId] = true pendant une requête getAccess
local accessGen = 0      -- incrémenté quand tout le cache d'accès est vidé (ignore les réponses périmées)
local groupGen = {}      -- [groupId] = compteur, incrémenté quand l'accès de ce groupe est vidé
local alertBlips = {}    -- [blip] = true
local lastPrompt = nil   -- dernier prompt envoyé { action, label, locked } (nil = masqué)

------------------------------------------------------------------------
-- Utilitaires
------------------------------------------------------------------------

local function zoneId(doorId)
    return 'pop_doorlock_' .. doorId
end

local function toVec(v)
    if type(v) ~= 'table' and type(v) ~= 'vector3' then return nil end
    local x, y, z = tonumber(v.x), tonumber(v.y), tonumber(v.z)
    if not x or not y or not z then return nil end
    return vec3(x + 0.0, y + 0.0, z + 0.0)
end

--- Charge un dictionnaire d'animation (2 s max). Renvoie true s'il est prêt.
function Doorlock.LoadAnim(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end
    return HasAnimDictLoaded(dict)
end

--- Valeur d'accès en cache pour un groupe : true, false ou nil (inconnu).
function Doorlock.GetAccess(groupId)
    local a = Doorlock.access[groupId]
    return a and a.value
end

function Doorlock.SetAccess(groupId, value)
    Doorlock.access[groupId] = { value = value, t = GetGameTimer() }
end

--- Vide le cache d'accès : d'un groupe (groupId) ou de tous (nil). Les réponses en cours sont ignorées.
function Doorlock.ClearAccess(groupId)
    if groupId == nil then
        Doorlock.access = {}
        accessPending = {}
        accessGen = accessGen + 1
        return
    end
    Doorlock.access[groupId] = nil
    accessPending[groupId] = nil
    groupGen[groupId] = (groupGen[groupId] or 0) + 1
end

--- Notifie une raison de refus (clé de locale) avec le bon argument.
-- Les arguments supplémentaires remplacent ceux par défaut (missing_item : outil de crochetage ; cooldown : Config.Lockpick.Cooldown).
function Doorlock.NotifyReason(reason, ...)
    reason = type(reason) == 'string' and reason or 'error'
    if select('#', ...) > 0 then
        Bridge.Notify(L(reason, ...), 'error')
    elseif reason == 'missing_item' then
        Bridge.Notify(L('missing_item', L('item_lockpick')), 'error')
    elseif reason == 'cooldown' then
        Bridge.Notify(L('cooldown', Config.Lockpick.Cooldown), 'error')
    else
        Bridge.Notify(L(reason), 'error')
    end
end

local function refreshAccess(groupId)
    if accessPending[groupId] then return end
    accessPending[groupId] = true
    local gen, ggen = accessGen, groupGen[groupId]
    Callback.Trigger('pop_doorlock:getAccess', function(value)
        if gen ~= accessGen or ggen ~= groupGen[groupId] then return end
        accessPending[groupId] = nil
        if value == nil then
            -- Timeout ou refus du rate-limit : on garde l'ancienne valeur et on réessaie plus tard.
            local old = Doorlock.access[groupId]
            Doorlock.access[groupId] = { value = old and old.value, t = GetGameTimer() - ACCESS_TTL + ACCESS_RETRY }
            return
        end
        Doorlock.SetAccess(groupId, value == true)
    end, groupId)
end

local function needsAccess(groupId)
    local a = Doorlock.access[groupId]
    return not a or GetGameTimer() - a.t > ACCESS_TTL
end

--- Vrai si le joueur ne peut pas interagir avec une porte en ce moment.
local function blocked(ped)
    return Doorlock.lockpicking or Doorlock.editing or Doorlock.toggling or Bridge.IsBusy()
        or IsPauseMenuActive() or IsEntityDead(ped)
end

------------------------------------------------------------------------
-- Prompt (NUI) : envoyé seulement si son contenu change
------------------------------------------------------------------------

function Doorlock.HidePrompt()
    if lastPrompt == nil then return end
    lastPrompt = nil
    SendNUIMessage({ action = 'pop_doorlock:prompt', show = false })
end

--- action : 'toggle' | 'lockpick' | nil ; label : clé de locale. Rien n'est construit ni envoyé si rien ne change.
local function showPrompt(action, label, locked)
    local last = lastPrompt
    if last and last.action == action and last.label == label and last.locked == locked then return end
    lastPrompt = { action = action, label = label, locked = locked }
    -- NOTE: key = nil est omis du JSON (équivaut à null côté JS : état seul, sans action).
    SendNUIMessage({
        action = 'pop_doorlock:prompt', show = true,
        key = action and Config.Keys.Interact.label or nil, label = L(label), locked = locked,
    })
end

--- Vrai si le crochetage est possible depuis la position du joueur (jamais en véhicule).
function Doorlock.CanLockpickHere()
    return not IsPedInAnyVehicle(PlayerPedId(), false)
end

--- Action possible et libellé (clé de locale) pour une porte, d'après le cache d'accès.
local function promptState(door, group)
    local access = Doorlock.GetAccess(door.groupId)
    if not TARGET_MODE then
        if access == true then
            return 'toggle', door.locked and 'door_unlock' or 'door_lock'
        elseif access == false and door.locked and group.security < 2 and Doorlock.CanLockpickHere() then
            return 'lockpick', 'door_lockpick'
        end
    end
    -- Accès inconnu, aucune action, ou mode target (les actions passent par le target) : état seul.
    return nil, door.locked and 'door_locked' or 'door_unlocked'
end

------------------------------------------------------------------------
-- Verrouillage (le serveur décide)
------------------------------------------------------------------------

local function playFobAnim()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end
    if not Doorlock.LoadAnim(FOB_DICT) then return end
    TaskPlayAnim(ped, FOB_DICT, FOB_CLIP, 8.0, -8.0, -1, 48, 0.0, false, false, false)
    RemoveAnimDict(FOB_DICT)
end

--- Demande au serveur d'inverser l'état d'une porte. À appeler dans un thread.
function Doorlock.Toggle(doorId)
    local door = Doorlock.doors[doorId]
    if not door or Doorlock.toggling then return end
    Doorlock.toggling = true
    Doorlock.HidePrompt()
    local wanted = not door.locked
    local ok, reason = Callback.Await('pop_doorlock:setState', doorId, wanted)
    Doorlock.toggling = false
    if ok then
        playFobAnim()
        Bridge.Notify(L(wanted and 'door_now_locked' or 'door_now_unlocked'), 'success')
    else
        if reason == 'door_no_access' then Doorlock.SetAccess(door.groupId, false) end
        if reason == 'cooldown' then
            Doorlock.NotifyReason(reason, STATE_SPAM_S)
        else
            Doorlock.NotifyReason(reason)
        end
    end
end

------------------------------------------------------------------------
-- Zones target (seulement si ox_target / qb-target)
------------------------------------------------------------------------

local function addZone(door, group)
    local id = door.id
    local size, heading
    if door.double then
        local a, b = door.leaves[1].coords, door.leaves[2].coords
        local length = #(a.xy - b.xy) + 1.0
        local angle = math.deg(math.atan(b.y - a.y, b.x - a.x))
        size = vec3(length, 1.2, 2.4)
        if Bridge.TargetSystem == 'ox_target' then
            heading = angle
        else
            -- NOTE: à vérifier en jeu. PolyZone (qb-target) oriente la longueur sur l'axe Y du heading :
            -- on retire 90° pour aligner la zone sur l'axe des deux battants.
            heading = angle - 90.0
        end
    else
        size, heading = vec3(1.2, 1.2, 2.4), 0.0
    end

    local function usable()
        return not Doorlock.lockpicking and not Doorlock.editing and not Doorlock.toggling
    end

    Bridge.Target.AddBoxZone(zoneId(id), door.center, size, heading, {
        {
            label = L('door_unlock'), icon = 'fa-solid fa-lock-open', distance = group.distance,
            canInteract = function()
                local d = Doorlock.doors[id]
                return d ~= nil and d.locked and Doorlock.GetAccess(d.groupId) == true and usable()
            end,
            onSelect = function() CreateThread(function() Doorlock.Toggle(id) end) end,
        },
        {
            label = L('door_lock'), icon = 'fa-solid fa-lock', distance = group.distance,
            canInteract = function()
                local d = Doorlock.doors[id]
                return d ~= nil and not d.locked and Doorlock.GetAccess(d.groupId) == true and usable()
            end,
            onSelect = function() CreateThread(function() Doorlock.Toggle(id) end) end,
        },
        {
            label = L('door_lockpick'), icon = 'fa-solid fa-screwdriver', distance = group.distance,
            canInteract = function()
                local d = Doorlock.doors[id]
                if not d or not d.locked or Doorlock.GetAccess(d.groupId) ~= false or not usable()
                    or not Doorlock.CanLockpickHere() then return false end
                local g = Doorlock.groups[d.groupId]
                return g ~= nil and g.security < 2
            end,
            onSelect = function() CreateThread(function() Doorlock.StartLockpick(id) end) end,
        },
    })
end

------------------------------------------------------------------------
-- Cache des portes + système natif
------------------------------------------------------------------------

--- Applique un état aux battants natifs. Avant de verrouiller, le battant est refermé (sinon il reste bloqué ouvert).
local function applyState(hash, locked)
    if locked then DoorSystemSetOpenRatio(hash, 0.0, false, true) end
    DoorSystemSetDoorState(hash, locked and 1 or 0, false, true)
end

local function removeDoor(doorId)
    local door = Doorlock.doors[doorId]
    if not door then return end
    for _, hash in ipairs(door.hashes) do
        if IsDoorRegisteredWithSystem(hash) then
            DoorSystemSetDoorState(hash, 0, false, true)
            RemoveDoorFromSystem(hash)
        end
    end
    if TARGET_MODE then Bridge.Target.Remove(zoneId(doorId)) end
    Doorlock.doors[doorId] = nil
    Doorlock.dirty = true
end

local function removeGroupDoors(groupId)
    for id, door in pairs(Doorlock.doors) do
        if door.groupId == groupId then removeDoor(id) end
    end
end

local function addDoor(groupId, group, data)
    local doorId = math.tointeger(tonumber(type(data) == 'table' and data.id))
    if not doorId or type(data.leaves) ~= 'table' then return end
    removeDoor(doorId)

    local door = { id = doorId, groupId = groupId, locked = data.locked == true, hashes = {}, leaves = {} }
    local sum = vec3(0.0, 0.0, 0.0)
    for i, leaf in ipairs(data.leaves) do
        local coords, model = toVec(leaf), tonumber(type(leaf) == 'table' and leaf.model)
        if coords and model and i <= 2 then
            local hash = joaat(('pop_doorlock_%d_%d'):format(doorId, i))
            AddDoorToSystem(hash, model, coords.x, coords.y, coords.z, false, false, false)
            applyState(hash, door.locked)
            door.hashes[#door.hashes + 1] = hash
            door.leaves[#door.leaves + 1] = { model = model, coords = coords }
            sum = sum + coords
        end
    end
    if #door.leaves == 0 then return end
    door.double = #door.leaves == 2
    -- NOTE: le centre est calculé à la création (éditeur) ; repli sur la moyenne des battants s'il manque.
    door.center = toVec(data.center) or (sum / #door.leaves)

    Doorlock.doors[doorId] = door
    if TARGET_MODE then addZone(door, group) end
    Doorlock.dirty = true
end

local function addGroup(data)
    local groupId = math.tointeger(tonumber(type(data) == 'table' and data.id))
    if not groupId then return end
    local group = {
        security = math.tointeger(tonumber(data.security)) or 2,
        distance = tonumber(data.distance) or 2.0,
    }
    Doorlock.groups[groupId] = group
    if type(data.doors) == 'table' then
        for _, d in ipairs(data.doors) do addDoor(groupId, group, d) end
    end
end

local function clearAll()
    for id in pairs(Doorlock.doors) do removeDoor(id) end
    Doorlock.groups = {}
    Doorlock.ClearAccess()
    Doorlock.HidePrompt()
end

--- Vrai si un battant de même modèle est déjà enregistré à moins de 0.5 m (pré-contrôle de l'éditeur).
function Doorlock.IsLeafRegistered(model, coords)
    for _, door in pairs(Doorlock.doors) do
        for _, leaf in ipairs(door.leaves) do
            if leaf.model == model and #(leaf.coords - coords) < 0.5 then return true end
        end
    end
    return false
end

------------------------------------------------------------------------
-- Chargement et synchronisation (le serveur fait autorité)
------------------------------------------------------------------------

Bridge.OnPlayerLoaded(function()
    local groups = Callback.Await('pop_doorlock:getDoors')
    if type(groups) ~= 'table' then return end
    -- NOTE: le cache est vidé à la réception (et non avant l'appel) pour ne jamais rester sans portes en cas de timeout.
    clearAll()
    for _, g in ipairs(groups) do addGroup(g) end
end)

Bridge.OnJobUpdate(function()
    Doorlock.ClearAccess()
end)

RegisterNetEvent('pop_doorlock:client:setState', function(doorId, locked)
    local door = Doorlock.doors[doorId]
    if not door or type(locked) ~= 'boolean' then return end
    door.locked = locked
    for _, hash in ipairs(door.hashes) do applyState(hash, locked) end
end)

RegisterNetEvent('pop_doorlock:client:syncGroup', function(group)
    local groupId = math.tointeger(tonumber(type(group) == 'table' and group.id))
    if not groupId then return end
    removeGroupDoors(groupId)
    -- Règles du groupe peut-être modifiées (jobs, clé réinitialisée) : l'accès en cache n'est plus fiable.
    Doorlock.ClearAccess(groupId)
    addGroup(group)
end)

RegisterNetEvent('pop_doorlock:client:removeGroup', function(groupId)
    groupId = math.tointeger(tonumber(groupId))
    if not groupId then return end
    removeGroupDoors(groupId)
    Doorlock.groups[groupId] = nil
    Doorlock.ClearAccess(groupId)
    if Doorlock.editing then
        SendNUIMessage({ action = 'pop_doorlock:groupRemoved', id = groupId })
    end
end)

RegisterNetEvent('pop_doorlock:client:alert', function(coords)
    local pos = toVec(coords)
    if not pos then return end
    Bridge.Notify(L('alert_lockpick'), 'warning')

    local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(blip, ALERT_BLIP.sprite)
    SetBlipColour(blip, ALERT_BLIP.colour)
    SetBlipScale(blip, ALERT_BLIP.scale)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(L('alert_blip'))
    EndTextCommandSetBlipName(blip)
    alertBlips[blip] = true

    SetTimeout((tonumber(Config.Lockpick.AlertBlipTime) or 60) * 1000, function()
        if alertBlips[blip] then
            alertBlips[blip] = nil
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
    end)
end)

------------------------------------------------------------------------
-- Boucle de proximité unique
------------------------------------------------------------------------

CreateThread(function()
    local nearby, lastScan = {}, 0
    local interact = Config.Keys.Interact

    while true do
        local wait = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local now = GetGameTimer()

        -- Liste des portes à moins de 30 m (une fois par seconde, ou après un changement du cache).
        if Doorlock.dirty or now - lastScan >= SCAN_INTERVAL then
            Doorlock.dirty, lastScan = false, now
            nearby = {}
            for id, door in pairs(Doorlock.doors) do
                if #(pos - door.center) < PROXIMITY_RADIUS then nearby[#nearby + 1] = id end
            end
        end

        -- Porte la plus proche.
        local best, bestDist = nil, math.huge
        for i = 1, #nearby do
            local door = Doorlock.doors[nearby[i]]
            if door then
                local d = #(pos - door.center)
                if d < bestDist then best, bestDist = door, d end
            end
        end

        local group = best and Doorlock.groups[best.groupId]
        local closest = Doorlock.closest
        if best and group then
            closest.id, closest.dist, closest.locked = best.id, bestDist, best.locked

            if bestDist <= ACCESS_RADIUS and needsAccess(best.groupId) then refreshAccess(best.groupId) end

            if bestDist > ACCESS_RADIUS then
                Doorlock.HidePrompt()
                wait = 500
            elseif bestDist > group.distance then
                Doorlock.HidePrompt()
                wait = 100
            elseif blocked(ped) then
                Doorlock.HidePrompt()
                wait = 250
            else
                local action, label = promptState(best, group)
                showPrompt(action, label, best.locked)
                if TARGET_MODE then
                    wait = 250
                elseif action then
                    -- Seul cas de lecture à chaque frame : à portée, en mode prompt, avec une action possible.
                    -- NOTE: sans action (état seul), 250 ms suffisent : aucune touche à lire.
                    wait = 0
                    if IsControlJustReleased(0, interact.control) then
                        Doorlock.HidePrompt()
                        local id = best.id
                        if action == 'toggle' then
                            CreateThread(function() Doorlock.Toggle(id) end)
                        else
                            CreateThread(function() Doorlock.StartLockpick(id) end)
                        end
                        wait = PRESS_DEBOUNCE
                    end
                else
                    wait = 250
                end
            end
        else
            closest.id, closest.dist, closest.locked = nil, -1.0, false
            Doorlock.HidePrompt()
        end

        Wait(wait)
    end
end)

------------------------------------------------------------------------
-- Export
------------------------------------------------------------------------

--- doorId|nil, distance, locked : dernier calcul de la boucle (portes à moins de 30 m).
-- NOTE: sans porte proche, renvoie nil, -1.0, false (math.huge ne passe pas en JSON pour les ressources JS).
exports('GetClosestDoor', function()
    local c = Doorlock.closest
    return c.id, c.dist, c.locked
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, door in pairs(Doorlock.doors) do
        for _, hash in ipairs(door.hashes) do
            if IsDoorRegisteredWithSystem(hash) then
                DoorSystemSetDoorState(hash, 0, false, true)
                RemoveDoorFromSystem(hash)
            end
        end
    end
    for blip in pairs(alertBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    alertBlips = {}
    SetNuiFocus(false, false)
end)
