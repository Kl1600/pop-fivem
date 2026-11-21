-- TAB Doorlock | Doorbuilder edition --

local Doors = {}        -- doorId -> { model, coords(vec3), distance, item, jobs, state }

-- =====================================================================
--  HELPERS
-- =====================================================================
local function notify(text, kind, time)
    if Config.ESX_Notify then
        exports['esx_notify']:Notify(kind or 'info', time or 2000, text)
    elseif GetResourceState('pop_notify') == 'started' then
        local icon = (kind == 'error') and 'fas fa-triangle-exclamation' or 'fas fa-key'
        exports['pop_notify']:ShowNotify({ icon = icon, message = text, duration = time or 3000 })
    elseif ESX and ESX.ShowNotification then
        ESX.ShowNotification(text)
    else
        Config.Custom_Notify(text, time or 2000, kind or 'info')
    end
end

-- reconstruit un vector3 fiable (le réseau sérialise en table {x,y,z})
local function toVec3(c)
    if type(c) == 'vector3' then return c end
    return vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0)
end

local ensureTargetModel  -- défini plus bas (section ox_target)

local function applyDoor(d)
    local coords = toVec3(d.coords)
    Doors[d.id] = {
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

-- Le joueur a-t-il accès à cette porte ? (feedback local ; le serveur revérifie)
local function hasAccess(d)
    if d.item and d.item ~= '' and d.item ~= false then
        return (exports.pop_inventory:getItemCount(d.item) or 0) > 0, true
    end
    local jobs = d.jobs
    if jobs == false or jobs == nil then return true, false end
    if jobs == true then return false, false end
    local job = ESX.GetPlayerData().job
    if type(jobs) == 'table' then
        for _, j in ipairs(jobs) do
            if job and job.name == j then return true, false end
        end
        return false, false
    end
    return (job and job.name == jobs), false
end

local function playFob(ped)
    ESX.Streaming.RequestAnimDict('anim@mp_player_intmenu@key_fob@', function()
        if not IsPedInAnyVehicle(ped, true) then
            TaskPlayAnim(ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click_fp', 1.0, 1.0, -1, 48, 1, false, false, false)
        end
    end)
end

-- =====================================================================
--  CHARGEMENT DES PORTES (serveur autoritaire)
-- =====================================================================
CreateThread(function()
    while not ESX or not ESX.IsPlayerLoaded() do Wait(250) end
    ESX.TriggerServerCallback('pop_doorlock:getDoors', function(list)
        for _, d in ipairs(list) do
            applyDoor(d)
        end
    end)
end)

-- ajout live des portes créées par le Doorbuilder (sans restart)
RegisterNetEvent('pop_doorlock:addDoors', function(created)
    for _, d in ipairs(created) do
        applyDoor(d)
    end
end)

-- suppression live des portes supprimées via le Doorbuilder
RegisterNetEvent('pop_doorlock:removeDoors', function(ids)
    for _, id in ipairs(ids) do
        if Doors[id] then
            RemoveDoorFromSystem(id)
            Doors[id] = nil
        end
    end
end)

-- =====================================================================
--  SYNC ÉTAT
-- =====================================================================
RegisterNetEvent('pop_doorlock:changeDoorState', function(doorId, state)
    DoorSystemSetDoorState(doorId, state and 1 or 0)
    if Doors[doorId] then
        Doors[doorId].state = state and 1 or 0
    end
end)

-- confirmation serveur (le joueur avait le droit) : anim + notif
RegisterNetEvent('pop_doorlock:toggled', function(state)
    playFob(PlayerPedId())
    notify(state and Config.Translate['closed_door'] or Config.Translate['opened_door'], 'info')
end)

-- refus serveur (pas la bonne clé / job)
RegisterNetEvent('pop_doorlock:denied', function()
    notify(Config.Translate['need_key'], 'error')
end)

-- =====================================================================
--  ALT CLICK (ox_target) : verrouiller (rouge) / déverrouiller (vert)
-- =====================================================================

-- retrouve la porte la plus proche de l'entité visée
local function findDoor(entity)
    if not entity or entity == 0 then return nil end
    local coords = GetEntityCoords(entity)
    local bestId, bestDist
    for id, d in pairs(Doors) do
        local dist = #(coords - d.coords)
        if dist <= 1.5 and (not bestDist or dist < bestDist) then
            bestId, bestDist = id, dist
        end
    end
    return bestId
end

-- la porte est-elle interactive pour ce joueur ? (affichage de l'option)
-- portes à clé (meta) : on affiche toujours, le serveur valide (logique clé voiture).
-- portes job/item simple : on filtre côté client.
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
        label       = 'Verrouiller',
        distance    = 2.5,
        canInteract = function(entity)
            local id = findDoor(entity)
            if not id then return false end
            local d = Doors[id]
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
        label       = 'Déverrouiller',
        distance    = 2.5,
        canInteract = function(entity)
            local id = findDoor(entity)
            if not id then return false end
            local d = Doors[id]
            return d.state == 1 and canShow(d)
        end,
        onSelect = function(data)
            targetToggle(data.entity, false)
        end,
    },
}

local targetModels = {}   -- model -> true (pour ne pas enregistrer 2x)

-- forward declaration assignée ici (utilisée par applyDoor plus haut)
ensureTargetModel = function(model, distance)
    if not model or targetModels[model] then return end
    targetModels[model] = true
    if distance and distance > 2.5 then
        for _, opt in ipairs(doorTargetOptions) do opt.distance = distance end
    end
    exports.ox_target:addModel(model, doorTargetOptions)
end
