-- pop_bank : client.
-- Aucune boucle permanente : targets du bridge, surveillance à 500 ms seulement pendant l'ouverture.
-- Le client ne décide de rien : il transmet la demande au serveur et affiche la réponse.

local TARGET_DISTANCE = 1.5  -- m
local CLOSE_DISTANCE  = 3.0  -- m, fermeture automatique au-delà
local CARD_TIME       = 1500 -- ms, insertion de la carte
local WATCH_DELAY     = 500  -- ms

local isOpen = false
local opening = false
local session = 0
local place = nil       -- Place courante (jamais fournie par la NUI)
local placeCoords = nil -- vector3 du lieu, pour la surveillance de distance
local blips = {}
local targets = {}

------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------

--- Traduit une raison renvoyée par le serveur ; `arg` peut être une table d'arguments.
local function translate(reason, arg)
    reason = reason or 'error'
    if type(arg) == 'table' then return L(reason, table.unpack(arg)) end
    if arg == nil then return L(reason) end
    return L(reason, arg)
end

local function close()
    if not isOpen then return end
    isOpen = false
    session = session + 1
    place, placeCoords = nil, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'pop_bank:close' })
end

--- Surveille la distance et la mort tant que le panneau est ouvert.
local function watch(activeSession)
    CreateThread(function()
        while isOpen and session == activeSession do
            local ped = PlayerPedId()
            if not placeCoords or IsEntityDead(ped) or #(GetEntityCoords(ped) - placeCoords) > CLOSE_DISTANCE then
                close()
                break
            end
            Wait(WATCH_DELAY)
        end
    end)
end

local function open(newPlace, coords)
    local ok, reason, arg, data = Callback.Await('pop_bank:getData', newPlace)
    opening = false
    if not ok or type(data) ~= 'table' then
        Bridge.Notify(translate(ok == nil and 'error' or reason, arg), 'error')
        return
    end
    place, placeCoords = newPlace, coords
    isOpen = true
    session = session + 1
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'pop_bank:open', data = data })
    watch(session)
end

local function openBank(index)
    local coords = Config.Banks[index]
    if not coords or isOpen or opening or Bridge.IsBusy() then return end
    opening = true
    open({ type = 'bank', index = index }, vector3(coords.x, coords.y, coords.z))
end

local function atmIndex(entity)
    if not entity or not DoesEntityExist(entity) then return end
    local coords = GetEntityCoords(entity)
    local nearest, index = 1.0, nil
    for i, candidate in ipairs(Config.Atms) do
        local distance = #(coords - candidate)
        if distance < nearest then nearest, index = distance, i end
    end
    return index
end

local function openAtm(entity)
    if isOpen or opening or Bridge.IsBusy() or not entity or not DoesEntityExist(entity) then return end
    local index = atmIndex(entity)
    if not index then return end
    opening = true
    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, entity, 500)
    Wait(500)
    local done = Bridge.Progress(L('inserting_card'), CARD_TIME, {
        anim = { dict = 'amb@prop_human_atm@male@idle_a', clip = 'idle_a', flag = 1 },
    })
    ClearPedTasks(ped)
    if not done then
        opening = false
        Bridge.Notify(L('progress_cancelled'), 'error')
        return
    end
    open({ type = 'atm', index = index }, Config.Atms[index])
end

------------------------------------------------------------------------
-- Callbacks NUI
------------------------------------------------------------------------

--- Appelle le serveur et renvoie { ok, message, data } à la NUI.
local function action(name, ...)
    if not isOpen or not place then return { ok = false, message = L('error') } end
    local ok, reason, arg, data = Callback.Await('pop_bank:' .. name, place, ...)
    if ok == nil then reason, arg = 'error', nil end
    return { ok = ok == true, message = translate(reason, arg), data = data }
end

local function readPreset(body)
    return type(body) == 'table' and type(body.preset) == 'string' and body.preset or ''
end

RegisterNUICallback('pop_bank:deposit', function(body, cb)
    cb(action('deposit', readPreset(body)))
end)

RegisterNUICallback('pop_bank:withdraw', function(body, cb)
    cb(action('withdraw', readPreset(body)))
end)

RegisterNUICallback('pop_bank:transfer', function(body, cb)
    local target = type(body) == 'table' and body.target
    target = type(target) == 'string' and target:sub(1, 64) or ''
    cb(action('transfer', target, readPreset(body)))
end)

-- Échap ou bouton Fermer : le bridge a déjà rendu le focus.
Bridge.OnUiClose(function()
    if isOpen then close() end
end)

------------------------------------------------------------------------
-- Blips et targets
------------------------------------------------------------------------

local function setup()
    if #targets > 0 then return end

    if Config.Blip then
        for _, coords in ipairs(Config.Banks) do
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, Config.Blip.sprite)
            SetBlipColour(blip, Config.Blip.color)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(L('blip_name'))
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end
    end

    for i, coords in ipairs(Config.Banks) do
        targets[#targets + 1] = Bridge.Target.AddBoxZone('pop_bank_' .. i, coords, vec3(2.0, 2.0, 2.0), 0.0, {
            {
                label = L('target_bank'),
                icon = 'fa-solid fa-building-columns',
                distance = TARGET_DISTANCE,
                onSelect = function() CreateThread(function() openBank(i) end) end,
            },
        })
    end

    targets[#targets + 1] = Bridge.Target.AddModel(Config.AtmModels, {
        {
            label = L('target_atm'),
            icon = 'fa-solid fa-money-bill',
            distance = TARGET_DISTANCE,
            canInteract = function(entity) return not opening and not isOpen and atmIndex(entity) ~= nil end,
            onSelect = function(entity) CreateThread(function() openAtm(entity) end) end,
        },
    })
end

Bridge.OnPlayerLoaded(setup)

------------------------------------------------------------------------
-- Export et arrêt
------------------------------------------------------------------------

exports('IsOpen', function() return isOpen end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    blips = {}
    if isOpen then
        isOpen = false
        SetNuiFocus(false, false)
    end
    SendNUIMessage({ action = 'pop_bank:close' })
end)
