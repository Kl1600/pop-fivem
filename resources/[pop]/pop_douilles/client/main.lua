-- pop_douilles : détection des tirs, fouille, props locaux, ramassage, rapport balistique.
-- Le client ne décide de rien : il signale des tirs et demande au serveur (fouille, ramassage).

local RES = GetCurrentResourceName()

------------------------------------------------------------------------
-- Tables par hash (construites une fois)
------------------------------------------------------------------------

-- Hash signé 32 bits : joaat et GetSelectedPedWeapon peuvent renvoyer signé ou non signé.
local function normHash(h)
    h = math.tointeger(h)
    if not h then return nil end
    h = h & 0xFFFFFFFF
    if h >= 0x80000000 then h = h - 0x100000000 end
    return h
end

local ignored = {}
for _, name in ipairs(Config.IgnoredWeapons or {}) do
    ignored[normHash(joaat(name))] = true
end

------------------------------------------------------------------------
-- Job (état local, utilisé seulement à l'appui sur la touche)
------------------------------------------------------------------------

local jobCache = nil -- dernier job reçu par OnJobUpdate (plus frais que PlayerData juste après SetDuty)

-- Même formats que Bridge.HasJob : 'police', { 'police', 'sheriff' } ou { police = 2 }.
local function jobAllowed(job)
    local jobs = Config.PoliceJobs
    if type(job) ~= 'table' or not job.name then return false end
    if type(jobs) == 'string' then return job.name == jobs end
    if type(jobs) ~= 'table' then return false end
    for k, v in pairs(jobs) do
        if type(k) == 'number' then
            if v == job.name then return true end
        elseif k == job.name then
            return (tonumber(job.grade) or 0) >= (tonumber(v) or 0)
        end
    end
    return false
end

local function isPoliceOnDuty()
    local job = jobCache or Bridge.GetJob()
    return job.onDuty == true and jobAllowed(job)
end

------------------------------------------------------------------------
-- Douilles affichées (props locaux + interaction)
------------------------------------------------------------------------

local shown = {}    -- [id] = { prop = handle | nil, target = id, batch = n }
local batchNo = 0
local picking = false

local function removeCasing(id)
    local c = shown[id]
    if not c then return end
    shown[id] = nil
    if c.target then Bridge.Target.Remove(c.target) end
    if c.prop and DoesEntityExist(c.prop) then DeleteEntity(c.prop) end
end

local function removeAll()
    for id in pairs(shown) do removeCasing(id) end
end

-- Mort ou en véhicule : ni fouille ni ramassage.
local function canAct()
    local ped = PlayerPedId()
    return not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false)
end

local function pickup(id)
    if picking or not shown[id] or Bridge.IsBusy() or not canAct() then return end
    picking = true
    local done = Bridge.Progress(L('picking_up'), Config.PickupDuration, {
        anim = { dict = 'pickup_object', clip = 'pickup_low', flag = 0 },
    })
    if done and canAct() then
        local ok, reason, arg = Callback.Await('pop_douilles:pickup', id)
        if not ok then
            Bridge.Notify(L(reason or 'error', arg), 'error')
            if reason == 'casing_not_found' then removeCasing(id) end
        end
        -- Succès : le serveur notifie et diffuse 'removed' (retire le prop).
    end
    picking = false
end

local function loadModel(hash)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + 2000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(50) end
    return HasModelLoaded(hash)
end

-- Aucun Wait ici : le modèle est chargé avant le callback, donc un 'removed' reçu pendant la fouille
-- ne peut pas laisser de douille fantôme.
-- La zone d'interaction est toujours une box zone : le prop (sans collision) n'est que visuel,
-- ox_target / qb-target ne le détectent pas.
local function reveal(list, hash, hasModel)
    batchNo = batchNo + 1
    local batch = batchNo

    for _, c in ipairs(list) do
        local id, x, y, z = c.id, tonumber(c.x), tonumber(c.y), tonumber(c.z)
        if id and x and y and z then
            if shown[id] then
                shown[id].batch = batch -- de nouveau trouvée : prolonge l'affichage
            else
                local options = {
                    {
                        label = L('target_pickup'),
                        icon = 'fa-solid fa-magnifying-glass',
                        distance = Casing.TARGET_DISTANCE,
                        canInteract = function() return not picking and not Bridge.IsBusy() and canAct() end,
                        onSelect = function() pickup(id) end,
                    },
                }
                local entry = { batch = batch }
                if hasModel then
                    local prop = CreateObject(hash, x, y, z, false, false, false)
                    if prop ~= 0 then
                        PlaceObjectOnGroundProperly(prop)
                        FreezeEntityPosition(prop, true)
                        SetEntityCollision(prop, false, false)
                        entry.prop = prop
                    end
                end
                entry.target = Bridge.Target.AddBoxZone(RES .. '_' .. id, vec3(x, y, z),
                    vec3(0.6, 0.6, 0.6), 0.0, options)
                shown[id] = entry
            end
        end
    end

    SetTimeout((tonumber(Config.RevealTime) or 120) * 1000, function()
        for id, c in pairs(shown) do
            if c.batch == batch then removeCasing(id) end
        end
    end)
end

------------------------------------------------------------------------
-- Fouille
------------------------------------------------------------------------

local searching = false

RegisterCommand('pop_douilles_search', function()
    -- Pas policier en service : rien (la touche reste libre pour les autres scripts).
    if searching or not isPoliceOnDuty() then return end
    if not canAct() or Bridge.IsBusy() then return end
    searching = true
    CreateThread(function()
        local done = Bridge.Progress(L('searching'), Config.SearchDuration, {
            anim = { dict = 'amb@medic@standing@kneel@base', clip = 'base', flag = 1 },
        })
        if done and canAct() then
            -- Modèle chargé AVANT le callback : reveal() ne cède plus la main ensuite.
            local hash = joaat(Config.Prop or '')
            local hasModel = loadModel(hash)
            local ok, reason, list = Callback.Await('pop_douilles:search')
            if not ok then
                Bridge.Notify(L(reason or 'error', list), 'error')
            elseif type(list) ~= 'table' or #list == 0 then
                Bridge.Notify(L('nothing_found'), 'info')
            else
                Bridge.Notify(L('found_casings', #list), 'success')
                reveal(list, hash, hasModel)
            end
            if hasModel then SetModelAsNoLongerNeeded(hash) end
        end
        searching = false
    end)
end, false)

RegisterKeyMapping('pop_douilles_search', L('keymap_search'), 'keyboard', Config.SearchKey)

Bridge.OnPlayerLoaded(function()
    jobCache = nil -- nouveau personnage : relire le job depuis le framework
    removeAll()
end)

Bridge.OnJobUpdate(function(job)
    jobCache = job
    if not (job.onDuty == true and jobAllowed(job)) then removeAll() end
end)

RegisterNetEvent('pop_douilles:client:removed', function(id)
    removeCasing(id)
end)

------------------------------------------------------------------------
-- Rapport balistique (carte NUI, sans focus)
------------------------------------------------------------------------

local reportToken = 0

local function report(data)
    if type(data) ~= 'table' then return end
    local street = ''
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if x and y and z then
        local streetHash = GetStreetNameAtCoord(x, y, z)
        if streetHash and streetHash ~= 0 then
            street = GetStreetNameFromHashKey(streetHash) or ''
        end
    end

    SendNUIMessage({
        action = 'pop_douilles:report', show = true,
        caliber = data.caliber, signature = data.signature, time = data.time,
        street = street, count = data.count,
    })

    reportToken = reportToken + 1
    local token = reportToken
    SetTimeout(Casing.REPORT_TIME, function()
        if token == reportToken then
            SendNUIMessage({ action = 'pop_douilles:report', show = false })
        end
    end)
end

RegisterNetEvent('pop_douilles:client:report', report)

------------------------------------------------------------------------
-- Détection des tirs : baisse de munitions, 250 ms arme en main, sinon 1000 ms
-- Arme changée ou rangée avec des tirs en attente : envoi dès que l'intervalle le permet, marqué
-- « arme précédente » (le serveur utilise alors la dernière arme qu'il a lue, si elle date de < 1,5 s).
------------------------------------------------------------------------

CreateThread(function()
    local baseline, baseWeapon = nil, nil
    local pending, lastSent = 0, 0
    local previous = false -- tirs en attente faits avec l'arme précédente

    while true do
        local ped = PlayerPedId()
        local weapon = normHash(GetSelectedPedWeapon(ped))
        local armed = IsPedArmed(ped, 4) and not ignored[weapon]
        local wait = 1000

        if pending > 0 and baseWeapon and (not armed or weapon ~= baseWeapon) then
            previous = true
        end

        if armed then
            local ammo = GetAmmoInPedWeapon(ped, weapon)
            if weapon == baseWeapon and baseline and ammo < baseline then
                pending = pending + (baseline - ammo)
            end
            baseline, baseWeapon = ammo, weapon
            wait = 250
        else
            baseline, baseWeapon = nil, nil
        end

        local now = GetGameTimer()
        if pending > 0 and now - lastSent >= Casing.REPORT_INTERVAL then
            local pos = GetEntityCoords(ped)
            local found, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)
            local z = found and groundZ or (pos.z - 0.95)
            TriggerServerEvent('pop_douilles:server:shot', { x = pos.x, y = pos.y, z = z },
                math.min(pending, Casing.MAX_SHOTS), previous)
            pending, lastSent, previous = 0, now, false
        end
        if pending > 0 then wait = 250 end -- envoi rapide après un changement d'arme

        Wait(wait)
    end
end)

------------------------------------------------------------------------
-- Nettoyage
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for _, c in pairs(shown) do
        if c.prop and DoesEntityExist(c.prop) then DeleteEntity(c.prop) end
    end
    shown = {}
end)
