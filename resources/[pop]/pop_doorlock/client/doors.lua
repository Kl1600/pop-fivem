-- Portes : chargement (serveur autoritaire), synchronisation et options ox_target Verrouiller / Déverrouiller.

Doorlock = {
    doors = {},   -- doorId -> { model, coords(vec3), distance, item, key, jobs, state }
}

--- Notification au style d'origine (icône clé ou alerte). icon : icône pour une info.
function Doorlock.Notify(text, kind, time, icon)
    Bridge.Notify({
        icon = (kind == 'error') and 'fas fa-triangle-exclamation' or (icon or 'fas fa-key'),
        message = text,
        type = kind or 'info',
        duration = time or 3000,
    })
end

-- vector3 fiable (le réseau sérialise en table {x,y,z})
local function toVec3(c)
    if type(c) == 'vector3' then return c end
    return vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0)
end

local ensureTargetModel  -- défini plus bas (section ox_target)

local function applyDoor(d)
    local coords = toVec3(d.coords)
    Doorlock.doors[d.id] = {
        model    = d.model,
        coords   = coords,
        distance = d.distance or 2.5,
        item     = d.item,
        key      = d.key,
        jobs     = d.jobs,
        state    = d.state and 1 or 0,
    }
    AddDoorToSystem(d.id, d.model, coords)
    DoorSystemSetDoorState(d.id, d.state and 1 or 0)
    ensureTargetModel(d.model, d.distance or 2.5)
end

-- Le joueur a-t-il accès à cette porte ? (affichage local ; le serveur revérifie)
local function hasAccess(d)
    if d.item and d.item ~= '' and d.item ~= false then
        local ok, count = pcall(function() return exports.pop_inventory:getItemCount(d.item) end)
        return ok and (tonumber(count) or 0) > 0, true
    end
    local jobs = d.jobs
    if jobs == false or jobs == nil then return true, false end
    if jobs == true then return false, false end
    local job = Bridge.GetJob()
    if type(jobs) == 'table' then
        for _, j in ipairs(jobs) do
            if job and job.name == j then return true, false end
        end
        return false, false
    end
    return (job and job.name == jobs), false
end

local function playFob(ped)
    local dict = 'anim@mp_player_intmenu@key_fob@'
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end
    if HasAnimDictLoaded(dict) and not IsPedInAnyVehicle(ped, true) then
        TaskPlayAnim(ped, dict, 'fob_click_fp', 1.0, 1.0, -1, 48, 1, false, false, false)
    end
end

-- Chargement des portes (une fois, quand le personnage est chargé)
local loaded = false
Bridge.OnPlayerLoaded(function()
    if loaded then return end
    loaded = true
    Callback.Trigger('pop_doorlock:getDoors', function(list)
        for _, d in ipairs(list or {}) do
            applyDoor(d)
        end
    end)
end)

-- Ajout live des portes créées par le Doorbuilder (sans restart)
RegisterNetEvent('pop_doorlock:addDoors', function(created)
    for _, d in ipairs(created) do
        applyDoor(d)
    end
end)

-- Suppression live des portes supprimées via le Doorbuilder
RegisterNetEvent('pop_doorlock:removeDoors', function(ids)
    for _, id in ipairs(ids) do
        if Doorlock.doors[id] then
            RemoveDoorFromSystem(id)
            Doorlock.doors[id] = nil
        end
    end
end)

RegisterNetEvent('pop_doorlock:changeDoorState', function(doorId, state)
    DoorSystemSetDoorState(doorId, state and 1 or 0)
    if Doorlock.doors[doorId] then
        Doorlock.doors[doorId].state = state and 1 or 0
    end
end)

-- Confirmation serveur (le joueur avait le droit) : anim + notif
RegisterNetEvent('pop_doorlock:toggled', function(state)
    playFob(PlayerPedId())
    Doorlock.Notify(state and L('closed_door') or L('opened_door'), 'info')
end)

-- Refus serveur (pas la bonne clé / job)
RegisterNetEvent('pop_doorlock:denied', function()
    Doorlock.Notify(L('need_key'), 'error')
end)

------------------------------------------------------------------------
-- ALT CLICK : verrouiller (rouge) / déverrouiller (vert)
-- ox_target direct : les couleurs d'icône (iconColor) ne passent pas par le bridge.
------------------------------------------------------------------------

-- Porte la plus proche de l'entité visée
local function findDoor(entity)
    if not entity or entity == 0 then return nil end
    local coords = GetEntityCoords(entity)
    local bestId, bestDist
    for id, d in pairs(Doorlock.doors) do
        local dist = #(coords - d.coords)
        if dist <= 1.5 and (not bestDist or dist < bestDist) then
            bestId, bestDist = id, dist
        end
    end
    return bestId
end

-- Portes à clé (meta) : option toujours affichée, le serveur valide. Portes job/item : filtre local.
local function canShow(d)
    if d.key and d.key ~= '' then return true end
    return (hasAccess(d))
end

local function targetToggle(entity, lock)
    local id = findDoor(entity)
    if not id then return end
    -- pas de notif/anim optimiste : le serveur valide puis confirme (toggled/denied)
    TriggerServerEvent('pop_doorlock:changeState', id, lock)
end

local doorTargetOptions = {
    {   -- VERROUILLER (rouge) : visible seulement si la porte est ouverte
        name        = 'tabdoor_lock',
        icon        = 'fa-solid fa-lock',
        iconColor   = '#ff4d4d',
        label       = L('target_lock'),
        distance    = 2.5,
        canInteract = function(entity)
            local id = findDoor(entity)
            if not id then return false end
            local d = Doorlock.doors[id]
            return d.state == 0 and canShow(d)
        end,
        onSelect = function(data)
            targetToggle(data.entity, true)
        end,
    },
    {   -- DÉVERROUILLER (vert) : visible seulement si la porte est verrouillée
        name        = 'tabdoor_unlock',
        icon        = 'fa-solid fa-lock-open',
        iconColor   = '#4dff88',
        label       = L('target_unlock'),
        distance    = 2.5,
        canInteract = function(entity)
            local id = findDoor(entity)
            if not id then return false end
            local d = Doorlock.doors[id]
            return d.state == 1 and canShow(d)
        end,
        onSelect = function(data)
            targetToggle(data.entity, false)
        end,
    },
}

local targetModels = {}   -- model -> true (pas d'enregistrement en double)

ensureTargetModel = function(model, distance)
    if not model or targetModels[model] then return end
    targetModels[model] = true
    if distance and distance > 2.5 then
        for _, opt in ipairs(doorTargetOptions) do opt.distance = distance end
    end
    exports.ox_target:addModel(model, doorTargetOptions)
end
