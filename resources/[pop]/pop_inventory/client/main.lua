-- pop_inventory : client principal.
-- Cache de l'inventaire, ouverture / fermeture, contexte (véhicule, sol, coffre), NUI, hotbar, fouille, exports.
-- Le client ne décide jamais d'un résultat : il décrit le contexte, le serveur vérifie tout.

local HOTBAR = 5                     -- slots 1 à 5 = hotbar (touches 1-5)
local TRUNK_CLIENT_DISTANCE = 2.5    -- mètres entre le joueur et l'arrière du véhicule
local TRUNK_VEHICLE_RADIUS = 6.0     -- mètres : véhicules candidats pour le coffre
local SEARCH_DISTANCE = 2.5          -- mètres pour la fouille (le serveur ajoute sa tolérance)
local WATCH_INTERVAL = 500           -- ms : contrôle de distance pendant l'ouverture
local INIT_RETRY_DELAY = 2000        -- ms entre deux essais de pop_inventory:init
local INIT_RETRIES = 5               -- essais supplémentaires au maximum
local USE_RETRY_DELAY = 600          -- ms (> USE_COOLDOWN serveur) avant de ressortir une arme rangée localement
local TRUNK_DOOR = 5                 -- index de la porte du coffre

PopInv = PopInv or {}
PopInv.items = {}
PopInv.inventory = { slots = Config.Slots, maxWeight = Config.MaxWeight, weight = 0, items = {} }
PopInv.open = false
PopInv.secondary = nil
PopInv.watch = nil
PopInv.weapon = nil
PopInv.drops = PopInv.drops or {}
PopInv.nuiItems = false
PopInv.loaded = false
PopInv.lostWeapon = nil              -- slot d'une arme rangée localement sans que le serveur le sache (weapons.lua)

local generation = 0                 -- incrémenté à chaque changement de personnage
local initializing = false
local initToken = 0                  -- identifie le thread d'init courant (un nouvel init remplace l'ancien)
local bufferedUpdates = nil          -- updates reçues pendant pop_inventory:init (rejouées ensuite)
local opening = false
local useBusy = false
local watchRunning = false
local trunkVehicle = nil             -- véhicule dont la porte du coffre a été ouverte

------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------

local function toInt(v)
    v = tonumber(v)
    return v and math.tointeger(v) or nil
end

local function toVec3(c)
    if type(c) ~= 'table' and type(c) ~= 'vector3' then return nil end
    local x, y, z = tonumber(c.x or c[1]), tonumber(c.y or c[2]), tonumber(c.z or c[3])
    if not x or not y or not z then return nil end
    return vector3(x, y, z)
end
PopInv.ToVec3 = toVec3

--- Notifie un échec renvoyé par le serveur (clé de locale).
function PopInv.NotifyFail(reason)
    reason = type(reason) == 'string' and reason or 'error'
    if reason == 'cooldown' then
        Bridge.Notify(L('cooldown', 1), 'error')
    else
        Bridge.Notify(L(reason), 'error')
    end
end
local notifyFail = PopInv.NotifyFail

--- Touches et interactions ignorées (menu pause, progression en cours, autre interface).
function PopInv.CanAct()
    return not IsPauseMenuActive() and not Bridge.IsBusy()
end

--- Mort ou statebag invBusy (compatibilité ox).
function PopInv.IsBlocked()
    return LocalPlayer.state.invBusy == true or IsEntityDead(PlayerPedId())
end

function PopInv.IsWeapon(name)
    local def = name and PopInv.items[name]
    return def ~= nil and def.weapon == true
end

local function deepEqual(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

-- Filtre metadata : toutes les clés du filtre sont égales dans l'item.
local function matches(metadata, filter)
    if filter == nil then return true end
    if type(filter) == 'string' then filter = { type = filter } end
    if type(filter) ~= 'table' then return true end
    metadata = type(metadata) == 'table' and metadata or {}
    for k, v in pairs(filter) do
        if not deepEqual(metadata[k], v) then return false end
    end
    return true
end

-- Totaux par nom d'item du cache joueur.
local function totals()
    local t = {}
    for _, item in pairs(PopInv.inventory.items) do
        t[item.name] = (t[item.name] or 0) + (item.count or 0)
    end
    return t
end

local function normalizeItem(item)
    if type(item) ~= 'table' or type(item.name) ~= 'string' then return nil end
    item.slot = toInt(item.slot)
    if not item.slot then return nil end
    item.count = tonumber(item.count) or 0
    if type(item.metadata) ~= 'table' then item.metadata = {} end
    return item
end

------------------------------------------------------------------------
-- NUI
------------------------------------------------------------------------

--- Envoie les définitions d'items à la NUI une seule fois, avant le premier message qui en a besoin.
function PopInv.EnsureNuiItems()
    if PopInv.nuiItems or not PopInv.loaded then return end
    PopInv.nuiItems = true
    SendNUIMessage({ action = 'pop_inventory:items', items = PopInv.items })
end

local function showHotbar(active)
    if not PopInv.loaded then return end
    PopInv.EnsureNuiItems()
    -- NOTE: slots vides = nil : selon les trous, le tableau arrive en JSON comme un tableau (null, raccourci si
    -- les derniers slots sont vides) ou comme un objet à clés "1".."5". La NUI gère les deux et se fie à item.slot.
    local list = {}
    for i = 1, HOTBAR do list[i] = PopInv.inventory.items[i] end
    SendNUIMessage({ action = 'pop_inventory:hotbar', items = list, active = active })
end

------------------------------------------------------------------------
-- Cache et changements
------------------------------------------------------------------------

-- Prévient les autres ressources (et la NUI si fermée) des totaux modifiés.
local function emitCountChanges(before, notifyNui)
    local after = totals()
    local function changed(name, total, delta)
        TriggerEvent('pop_inventory:itemCount', name, total)
        if notifyNui and not PopInv.open and PopInv.loaded then
            PopInv.EnsureNuiItems()
            SendNUIMessage({ action = 'pop_inventory:itemNotify', name = name, count = math.abs(delta), added = delta > 0 })
        end
    end
    for name, total in pairs(after) do
        local old = before[name] or 0
        if total ~= old then changed(name, total, total - old) end
    end
    for name, old in pairs(before) do
        if after[name] == nil then changed(name, 0, -old) end
    end
end

-- Remplace le cache par une vue complète (InvView du joueur).
local function replaceInventory(view)
    if type(view) ~= 'table' then return end
    local before = totals()
    local inv = PopInv.inventory
    inv.slots = toInt(view.slots) or inv.slots
    inv.maxWeight = tonumber(view.maxWeight) or inv.maxWeight
    inv.weight = tonumber(view.weight) or 0
    inv.items = {}
    if type(view.items) == 'table' then
        for _, item in pairs(view.items) do
            item = normalizeItem(item)
            if item then inv.items[item.slot] = item end
        end
    end
    emitCountChanges(before, false)
end

local function applyChanges(data)
    local before = totals()
    local inv = PopInv.inventory
    if type(data.changes) == 'table' then
        for _, c in ipairs(data.changes) do
            local slot = type(c) == 'table' and c.side == 'player' and toInt(c.slot)
            if slot then
                inv.items[slot] = normalizeItem(c.item) -- false -> nil (slot vidé)
            end
        end
    end
    if type(data.weights) == 'table' and data.weights.player then
        inv.weight = tonumber(data.weights.player) or inv.weight
    end
    if PopInv.loaded then
        PopInv.EnsureNuiItems()
        SendNUIMessage({ action = 'pop_inventory:update', changes = data.changes, weights = data.weights })
    end
    emitCountChanges(before, true)
end

RegisterNetEvent('pop_inventory:client:update', function(data)
    if type(data) ~= 'table' then return end
    if bufferedUpdates then
        -- Les changements sont absolus (contenu d'un slot) : les rejouer après la vue complète est sans risque.
        bufferedUpdates[#bufferedUpdates + 1] = data
        return
    end
    applyChanges(data)
end)

------------------------------------------------------------------------
-- Chargement
------------------------------------------------------------------------

--- Charge l'inventaire (à appeler dans un thread). Sans effet si un chargement est déjà en cours.
local function init()
    if initializing or PopInv.loaded then return end
    initializing = true
    initToken = initToken + 1
    local token = initToken

    local function beginBuffers()
        bufferedUpdates = {}
        if PopInv.BufferDrops then PopInv.BufferDrops() end
    end
    beginBuffers()

    local data
    local attempt = 0
    while attempt <= INIT_RETRIES do
        if attempt > 0 then Wait(INIT_RETRY_DELAY) end
        if token ~= initToken then return end -- remplacé par un init plus récent
        local gen = generation
        local res = Callback.Await('pop_inventory:init')
        if token ~= initToken then return end
        if gen ~= generation then
            -- Personnage changé pendant la requête : on relance avec la nouvelle génération.
            attempt = 0
            beginBuffers()
        elseif type(res) == 'table' then
            data = res
            break
        else
            attempt = attempt + 1
        end
    end

    local pending = bufferedUpdates or {}
    bufferedUpdates = nil
    initializing = false
    if not data then
        if PopInv.CancelDropBuffer then PopInv.CancelDropBuffer() end
        if Config.Debug then print('[pop_inventory] init failed') end
        return
    end

    PopInv.items = type(data.items) == 'table' and data.items or {}
    PopInv.nuiItems = false
    PopInv.loaded = true
    replaceInventory(data.inventory)
    for _, upd in ipairs(pending) do applyChanges(upd) end

    if PopInv.SetupWorld then PopInv.SetupWorld(data) end
    if PopInv.FlushDrops then PopInv.FlushDrops() end
    if type(data.weapon) == 'table' and PopInv.EquipWeapon then PopInv.EquipWeapon(data.weapon) end
end

Bridge.OnPlayerLoaded(function()
    init()
end)

------------------------------------------------------------------------
-- Ouverture / fermeture
------------------------------------------------------------------------

local function closeTrunkDoor()
    local veh = trunkVehicle
    trunkVehicle = nil
    if veh and DoesEntityExist(veh) then
        SetVehicleDoorShut(veh, TRUNK_DOOR, false)
    end
end

-- Contrôle de la portée décrite par le serveur (watch).
local function watchOk(ped)
    local w = PopInv.watch
    if type(w) ~= 'table' then return true end
    local dist = tonumber(w.distance) or 3.0
    local pos = GetEntityCoords(ped)

    local coords = w.coords and toVec3(w.coords)
    if coords and #(pos - coords) > dist then return false end

    local netId = toInt(w.netId)
    if netId then
        if not NetworkDoesNetworkIdExist(netId) then return false end
        local veh = NetToVeh(netId)
        if veh == 0 or not DoesEntityExist(veh) or #(pos - GetEntityCoords(veh)) > dist then return false end
    end

    local target = toInt(w.target)
    if target then
        local player = GetPlayerFromServerId(target)
        if player == -1 then return false end
        local tped = GetPlayerPed(player)
        if tped == 0 or not DoesEntityExist(tped) or #(pos - GetEntityCoords(tped)) > dist then return false end
    end
    return true
end

local function startWatch()
    if watchRunning then return end
    watchRunning = true
    CreateThread(function()
        while PopInv.open do
            Wait(WATCH_INTERVAL)
            if not PopInv.open then break end
            local ped = PlayerPedId()
            if PopInv.IsBlocked() or not watchOk(ped) then
                PopInv.Close(true)
                break
            end
        end
        watchRunning = false
    end)
end

--- Ferme l'interface. notifyServer = false pour client:close / client:reset (le serveur a déjà fermé).
function PopInv.Close(notifyServer)
    local wasOpen = PopInv.open
    PopInv.open = false
    PopInv.secondary, PopInv.watch = nil, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'pop_inventory:close' })
    closeTrunkDoor()
    if wasOpen and notifyServer then
        Callback.Trigger('pop_inventory:close', function() end)
    end
end

local function showInventory(payload, vehicle)
    if type(payload) ~= 'table' or type(payload.player) ~= 'table' then return false end
    PopInv.secondary = payload.secondary
    PopInv.watch = type(payload.watch) == 'table' and payload.watch or nil

    closeTrunkDoor()
    if vehicle and DoesEntityExist(vehicle) then
        -- NOTE: n'a d'effet que si ce client contrôle l'entité.
        SetVehicleDoorOpen(vehicle, TRUNK_DOOR, false, false)
        trunkVehicle = vehicle
    end

    PopInv.nuiItems = false -- définitions renvoyées à chaque ouverture (NUI rechargée, items ajoutés)
    PopInv.EnsureNuiItems()
    SendNUIMessage({ action = 'pop_inventory:open', player = payload.player, secondary = payload.secondary })
    if not PopInv.open then
        PopInv.open = true
        SetNuiFocus(true, true)
    end
    startWatch()
    return true
end

--- Demande l'ouverture au serveur (à appeler dans un thread). vehicle : coffre à ouvrir visuellement.
--- quiet = true : pas de notification en cas d'échec (l'appelant décide). Retour : true | false, reason
--- (reason = nil si le personnage a changé pendant la demande).
function PopInv.Open(request, vehicle, quiet)
    if opening then return false, 'busy' end
    if not PopInv.loaded then return false, 'not_loaded' end
    if PopInv.IsBlocked() then
        if not quiet then notifyFail('cannot_now') end
        return false, 'cannot_now'
    end
    opening = true
    local gen = generation
    local ok, payload = Callback.Await('pop_inventory:open', request)
    opening = false
    if gen ~= generation then return false, nil end
    if not ok then
        local reason = type(payload) == 'string' and payload or 'error'
        if not quiet then notifyFail(reason) end
        return false, reason
    end
    if not showInventory(payload, vehicle) then
        if not quiet then notifyFail('error') end
        return false, 'error'
    end
    return true
end

local NO_STORAGE_CLASSES = { [8] = true, [13] = true } -- motos, vélos

-- Véhicule sans boîte à gants ni coffre (moto, vélo, quad).
local function noStorage(veh)
    return NO_STORAGE_CLASSES[GetVehicleClass(veh)] == true
end

local function isQuad(veh)
    return IsThisModelAQuadbike(GetEntityModel(veh)) == true
end

-- Véhicule à pied dont l'arrière est à portée.
local function findTrunkVehicle(pos)
    local best, bestDist = nil, TRUNK_VEHICLE_RADIUS
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local d = #(pos - GetEntityCoords(veh))
        if d <= bestDist then best, bestDist = veh, d end
    end
    if not best or not NetworkGetEntityIsNetworked(best) then return nil end
    if noStorage(best) or GetVehicleDoorLockStatus(best) > 1 then return nil end
    local min = GetModelDimensions(GetEntityModel(best))
    local rear = GetOffsetFromEntityInWorldCoords(best, 0.0, min.y, 0.0)
    if #(pos - rear) > TRUNK_CLIENT_DISTANCE then return nil end
    return best
end

-- Essaie un conteneur ; en cas d'échec (hors busy / cooldown), retombe sans notification sur l'inventaire seul.
local function openOrFallback(request, vehicle)
    local ok, reason = PopInv.Open(request, vehicle, true)
    if ok or reason == nil or reason == 'not_loaded' then return ok end
    if reason == 'busy' or reason == 'cooldown' then
        notifyFail(reason)
        return false
    end
    return PopInv.Open(nil)
end

local function contextRequest(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        if NetworkGetEntityIsNetworked(veh) and not noStorage(veh) and not isQuad(veh) then
            return { type = 'glovebox', netId = VehToNet(veh) }
        end
        return nil
    end

    local pos = GetEntityCoords(ped)
    local dropId = PopInv.NearestDrop and PopInv.NearestDrop(pos, Config.Drops.Distance)
    if dropId then return { type = 'drop', id = dropId } end

    local trunk = findTrunkVehicle(pos)
    if trunk then return { type = 'trunk', netId = VehToNet(trunk) }, trunk end
    return nil
end

-- Ouverture par la touche : véhicule, drop, coffre, sinon inventaire + sol.
local function openFromContext()
    local request, vehicle = contextRequest(PlayerPedId())
    if request then return openOrFallback(request, vehicle) end
    return PopInv.Open(nil)
end

------------------------------------------------------------------------
-- Joueurs proches
------------------------------------------------------------------------

local function closestPlayer(maxDist)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local me = PlayerId()
    local best, bestDist = nil, maxDist
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= me then
            local tped = GetPlayerPed(player)
            if tped ~= 0 and DoesEntityExist(tped) then
                local d = #(pos - GetEntityCoords(tped))
                if d <= bestDist then best, bestDist = player, d end
            end
        end
    end
    return best and GetPlayerServerId(best) or nil
end

local function searchPlayer()
    if PopInv.open or not PopInv.loaded or not PopInv.CanAct() then return end
    local target = closestPlayer(SEARCH_DISTANCE)
    if not target then
        notifyFail('no_player_nearby')
        return
    end
    CreateThread(function()
        PopInv.Open({ type = 'player', target = target })
    end)
end

------------------------------------------------------------------------
-- Utilisation
------------------------------------------------------------------------

--- Utilise un slot du joueur (à appeler dans un thread). Retour : ok, reason, close.
function PopInv.UseSlot(slot)
    local item = PopInv.inventory.items[slot]
    local lost = item ~= nil and PopInv.lostWeapon == slot and PopInv.IsWeapon(item.name)
    local ok, reason, close = Callback.Await('pop_inventory:use', slot)
    if ok and lost and not PopInv.weapon then
        -- NOTE: arme rangée localement (mort, jeu) alors que le serveur la croyait en main :
        -- son "use" vient de la ranger côté serveur, on la redemande une fois.
        PopInv.lostWeapon = nil
        Wait(USE_RETRY_DELAY)
        ok, reason, close = Callback.Await('pop_inventory:use', slot)
    end
    return ok, reason, close
end

local function useHotbar(slot)
    if not PopInv.loaded or PopInv.open or useBusy or IsNuiFocused() then return end
    if not PopInv.CanAct() or PopInv.IsBlocked() then return end
    if not PopInv.inventory.items[slot] then
        showHotbar(slot)
        return
    end
    useBusy = true
    CreateThread(function()
        local ok, reason = PopInv.UseSlot(slot)
        useBusy = false
        if not ok then notifyFail(reason) end
        showHotbar(slot)
    end)
end

------------------------------------------------------------------------
-- Touches et commandes
------------------------------------------------------------------------

RegisterCommand('pop_inventory', function()
    if PopInv.open then
        PopInv.Close(true)
        return
    end
    if not PopInv.loaded then
        notifyFail('not_loaded')
        CreateThread(init) -- sans effet si un chargement est déjà en cours
        return
    end
    if opening or IsNuiFocused() or not PopInv.CanAct() then return end
    CreateThread(openFromContext)
end, false)
RegisterKeyMapping('pop_inventory', L('keymap_open'), 'keyboard', Config.OpenKey)

for i = 1, HOTBAR do
    local cmd = 'pop_inventory_slot' .. i
    RegisterCommand(cmd, function() useHotbar(i) end, false)
    RegisterKeyMapping(cmd, L('keymap_slot', i), 'keyboard', tostring(i))
end

if Config.SearchCommand then
    RegisterCommand(Config.SearchCommand, function() searchPlayer() end, false)
end

CreateThread(function()
    TriggerEvent('chat:removeSuggestion', '/pop_inventory')
    for i = 1, HOTBAR do TriggerEvent('chat:removeSuggestion', '/pop_inventory_slot' .. i) end
end)

------------------------------------------------------------------------
-- Callbacks NUI
------------------------------------------------------------------------

local function reply(cb, ok, reason)
    if not PopInv.open then
        -- Interface fermée pendant la requête : rien à afficher.
        cb({ ok = false, error = 'error' })
        return
    end
    if ok then
        cb({ ok = true })
        return
    end
    reason = type(reason) == 'string' and reason or 'error'
    notifyFail(reason)
    cb({ ok = false, error = reason })
end

local SIDES = { player = true, secondary = true }

RegisterNUICallback('move', function(body, cb)
    if not PopInv.open or type(body) ~= 'table' then return reply(cb, false, 'error') end
    local fromSlot = toInt(body.fromSlot)
    if not SIDES[body.from] or not SIDES[body.to] or not fromSlot then return reply(cb, false, 'error') end
    local count = toInt(body.count)
    if count and count <= 0 then count = nil end
    local toSlot = toInt(body.toSlot)
    local sec = PopInv.secondary
    local toNewDrop = body.to == 'secondary' and type(sec) == 'table' and sec.type == 'newdrop'
    local ok, reason = Callback.Await('pop_inventory:move', body.from, fromSlot, body.to, toSlot, count)
    if ok and toNewDrop and PopInv.open and PopInv.watch == nil then
        -- Le panneau « Sol » est devenu un drop à nos pieds : fermer si l'on s'en éloigne.
        PopInv.watch = { coords = GetEntityCoords(PlayerPedId()), distance = Config.Drops.Distance + 1.0 }
    end
    reply(cb, ok, reason)
end)

RegisterNUICallback('buy', function(body, cb)
    if not PopInv.open or type(body) ~= 'table' then return reply(cb, false, 'error') end
    local index = toInt(body.index)
    if not index then return reply(cb, false, 'error') end
    local count = toInt(body.count)
    if not count or count <= 0 then count = 1 end
    reply(cb, Callback.Await('pop_inventory:buy', index, count, toInt(body.toSlot)))
end)

RegisterNUICallback('use', function(body, cb)
    if not PopInv.open or type(body) ~= 'table' then return reply(cb, false, 'error') end
    local slot = toInt(body.slot)
    if not slot then return reply(cb, false, 'error') end
    if useBusy then
        -- Une utilisation est déjà en cours : réponse silencieuse (pas d'avalanche de notifications).
        cb({ ok = false, error = 'busy' })
        return
    end
    useBusy = true
    local gen = generation
    local ok, reason, close = PopInv.UseSlot(slot)
    if gen == generation then useBusy = false end
    reply(cb, ok, reason)
    if ok and close and PopInv.open then PopInv.Close(true) end
end)

RegisterNUICallback('give', function(body, cb)
    if not PopInv.open or type(body) ~= 'table' then return reply(cb, false, 'error') end
    local slot = toInt(body.slot)
    if not slot then return reply(cb, false, 'error') end
    local count = toInt(body.count)
    if count and count <= 0 then count = nil end
    local target = closestPlayer(Config.GiveDistance)
    if not target then return reply(cb, false, 'no_player_nearby') end
    reply(cb, Callback.Await('pop_inventory:give', slot, count, target))
end)

-- Échap, TAB ou I (Pop.post('close')) : le bridge a déjà rendu le focus.
Bridge.OnUiClose(function()
    if PopInv.open then PopInv.Close(true) end
end)

------------------------------------------------------------------------
-- Events serveur
------------------------------------------------------------------------

RegisterNetEvent('pop_inventory:client:open', function(payload)
    if not PopInv.loaded then
        -- Session ouverte côté serveur alors qu'on ne peut rien afficher : on la referme.
        Callback.Trigger('pop_inventory:close', function() end)
        return
    end
    showInventory(payload, nil)
end)

RegisterNetEvent('pop_inventory:client:close', function()
    PopInv.Close(false)
end)

RegisterNetEvent('pop_inventory:client:reset', function()
    generation = generation + 1
    PopInv.Close(false)
    if PopInv.Holster then PopInv.Holster(false) end
    PopInv.lostWeapon = nil
    local before = totals()
    PopInv.inventory = { slots = Config.Slots, maxWeight = Config.MaxWeight, weight = 0, items = {} }
    emitCountChanges(before, false)
    PopInv.loaded = false
    PopInv.nuiItems = false
    opening, useBusy = false, false
    initializing = false -- un init en cours relance avec la nouvelle génération (ou est remplacé)
end)

RegisterNetEvent('pop_inventory:client:searched', function()
    Bridge.Notify(L('being_searched'), 'warning')
end)

------------------------------------------------------------------------
-- Exports client
------------------------------------------------------------------------

local function countOf(name, metadata)
    local n = 0
    for _, item in pairs(PopInv.inventory.items) do
        if item.name == name and matches(item.metadata, metadata) then n = n + item.count end
    end
    return n
end

local function slotsOf(name, metadata)
    local list = {}
    local inv = PopInv.inventory
    for slot = 1, inv.slots do
        local item = inv.items[slot]
        if item and item.name == name and matches(item.metadata, metadata) then list[#list + 1] = item end
    end
    return list
end

-- NOTE: la demande part dans un thread : true = demande envoyée (pas encore ouverte), false = arguments invalides
-- ou inventaire non chargé. Le résultat réel arrive par l'ouverture de l'interface (ou une notification d'échec).
exports('openInventory', function(invType, data)
    local request
    if invType == nil then
        request = nil
    elseif invType == 'stash' or invType == 'shop' then
        local id = type(data) == 'table' and data.id or data
        if type(id) ~= 'string' and type(id) ~= 'number' then return false end
        request = { type = invType, id = tostring(id) }
    elseif invType == 'player' then
        local target = toInt(type(data) == 'table' and data.id or data)
        if not target then return false end
        request = { type = 'player', target = target }
    else
        return false
    end
    if not PopInv.loaded then return false end
    CreateThread(function() PopInv.Open(request) end)
    return true
end)

exports('closeInventory', function()
    if PopInv.open then PopInv.Close(true) end
end)

exports('GetItemCount', function(item, metadata)
    if type(item) ~= 'string' then return 0 end
    return countOf(item:lower(), metadata)
end)

exports('Search', function(kind, items, metadata)
    if kind ~= 'count' and kind ~= 'slots' then return nil end
    local fn = kind == 'count' and countOf or slotsOf
    if type(items) == 'string' then return fn(items:lower(), metadata) end
    if type(items) ~= 'table' then return nil end
    local out = {}
    for _, name in ipairs(items) do
        if type(name) == 'string' then out[name] = fn(name:lower(), metadata) end
    end
    return out
end)

exports('Items', function(name)
    if name == nil then return PopInv.items end
    if type(name) ~= 'string' then return nil end
    return PopInv.items[name:lower()]
end)

exports('GetCurrentWeapon', function()
    return PopInv.GetCurrentWeapon and PopInv.GetCurrentWeapon() or nil
end)

exports('searchPlayer', function()
    searchPlayer()
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if PopInv.open then
        PopInv.open = false
        SetNuiFocus(false, false)
    end
    closeTrunkDoor()
end)
