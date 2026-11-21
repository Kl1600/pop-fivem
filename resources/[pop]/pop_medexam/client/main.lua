-- pop_medexam : client. Blips, PNJ, target, déroulé de l'examen, consentement et carte.
-- Le client ne décide de rien : il envoie un index de lieu (et le résultat des mini-jeux en mode auto).

local TARGET_DISTANCE = 2.0
local PED_DISTANCE    = 40.0
local STATE_DISTANCE  = 10.0  -- lecture de l'état à l'approche
local STATE_TTL       = 10000 -- cache de l'état par lieu (ms)
-- NOTE: SPEC indique 15000 ms, mais les callbacks internes expirent à 10 s (serveur -> patient, et médecin -> serveur).
-- 8 s laissent une marge : au-delà, le serveur considère la demande refusée et le médecin ne reçoit plus de réponse.
local CONSENT_TIMEOUT = 8000
local CARD_TIME       = 8000
local SKILL_SAFETY    = 8000  -- filet si la NUI ne répond pas (le mini-jeu échoue seul à 4 s)

local ANIM = { dict = 'missheistdockssetup1clipboard@base', clip = 'base', flag = 49 }

local blips = {}
local peds = {}       -- [i] = { ped, targetId }
local zones = {}      -- [i] = id de zone (lieux sans PNJ)
local states = {}     -- [i] = { autoOpen, isDoctor, at }
local fetching = {}
local ready = false
local running = false
local consentActive = false
local skillPromise = nil
local cardToken = 0

------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------

local function notifyFail(reason, arg)
    Bridge.Notify(L(reason or 'error', arg), 'error')
end

local function fresh(i)
    local s = states[i]
    return s and GetGameTimer() - s.at < STATE_TTL and s or nil
end

local function refreshState(i)
    if fetching[i] or fresh(i) or not Bridge.IsLoaded() then return end
    fetching[i] = true
    Callback.Trigger('pop_medexam:getState', function(autoOpen, isDoctor)
        fetching[i] = nil
        states[i] = { autoOpen = autoOpen == true, isDoctor = isDoctor == true, at = GetGameTimer() }
    end, i)
end

------------------------------------------------------------------------
-- Mini-jeu (NUI)
------------------------------------------------------------------------

local function endSkill(success)
    local p = skillPromise
    if not p then return end
    skillPromise = nil
    p:resolve(success == true)
end

RegisterNUICallback('pop_medexam:skillResult', function(data, cb)
    endSkill(type(data) == 'table' and data.success == true)
    cb('ok')
end)

-- Échap pendant un mini-jeu : échec.
Bridge.OnUiClose(function()
    endSkill(false)
end)

local function skill(label, zone)
    local p = promise.new()
    skillPromise = p
    SetNuiFocus(true, false)
    SendNUIMessage({ action = 'pop_medexam:skill', show = true, label = label, key = Config.Keys.Interact.label, zone = zone })
    SetTimeout(SKILL_SAFETY, function()
        if skillPromise == p then endSkill(false) end
    end)
    local success = Citizen.Await(p)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'pop_medexam:skill', show = false })
    return success == true
end

------------------------------------------------------------------------
-- Déroulés
------------------------------------------------------------------------

local function runAuto(i)
    if running or Bridge.IsBusy() then return end
    running = true
    states[i] = nil

    local ok, reason, arg = Callback.Await('pop_medexam:start', i)
    if not ok then
        -- Pas de réponse : on annule par sécurité (rembourse si la session a été créée).
        if ok == nil then Callback.Await('pop_medexam:cancel') end
        notifyFail(reason, arg)
        running = false
        return
    end

    if not Bridge.Progress(L('step_pressure'), Config.Durations.pressure, { anim = ANIM }) then
        Callback.Await('pop_medexam:cancel')
        running = false
        return
    end

    local passed = skill('step_vision', 0.18) and skill('step_reflex', 0.12)
    ok, reason, arg = Callback.Await('pop_medexam:finish', passed)
    if not ok then notifyFail(reason, arg) end
    running = false
end

local function runEms(i)
    if running or Bridge.IsBusy() then return end
    running = true
    states[i] = nil

    local ok, reason, arg = Callback.Await('pop_medexam:emsStart', i)
    if not ok then
        if ok == nil then Callback.Await('pop_medexam:emsCancel') end
        notifyFail(reason, arg)
        running = false
        return
    end

    local d = Config.Durations
    local steps = { { 'step_pressure', d.pressure }, { 'step_vision', d.vision }, { 'step_reflex', d.reflex } }
    for _, step in ipairs(steps) do
        if not Bridge.Progress(L(step[1]), step[2], { anim = ANIM }) then
            Callback.Await('pop_medexam:emsCancel')
            running = false
            return
        end
    end

    ok, reason, arg = Callback.Await('pop_medexam:emsFinish')
    if not ok then notifyFail(reason, arg) end
    running = false
end

local function options(i)
    return {
        {
            label = L('target_auto', Config.Price),
            icon = 'fa-solid fa-notes-medical',
            distance = TARGET_DISTANCE,
            canInteract = function()
                local s = fresh(i)
                return not running and s ~= nil and s.autoOpen
            end,
            onSelect = function() CreateThread(function() runAuto(i) end) end,
        },
        {
            label = L('target_ems'),
            icon = 'fa-solid fa-user-doctor',
            distance = TARGET_DISTANCE,
            canInteract = function()
                local s = fresh(i)
                return not running and s ~= nil and s.isDoctor
            end,
            onSelect = function() CreateThread(function() runEms(i) end) end,
        },
    }
end

------------------------------------------------------------------------
-- PNJ et zones
------------------------------------------------------------------------

local function spawnPed(i, loc)
    local hash = joaat(loc.ped)
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(50) end
    if not HasModelLoaded(hash) then return end

    local c = loc.coords
    local ped = CreatePed(4, hash, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return end
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    peds[i] = { ped = ped, targetId = Bridge.Target.AddLocalEntity(ped, options(i)) }
end

local function deletePed(i)
    local p = peds[i]
    if not p then return end
    peds[i] = nil
    if p.targetId then Bridge.Target.Remove(p.targetId) end
    if DoesEntityExist(p.ped) then DeleteEntity(p.ped) end
end

local function setup()
    if ready then return end
    ready = true

    for i, loc in ipairs(Config.Locations) do
        if not loc.ped then
            local c = loc.coords
            zones[i] = Bridge.Target.AddBoxZone('pop_medexam_' .. i, vec3(c.x, c.y, c.z), vec3(1.5, 1.5, 2.0), c.w, options(i))
        end
    end

    -- Boucle de distance : PNJ et lecture de l'état (1000 ms près d'une clinique, 2500 ms sinon).
    CreateThread(function()
        while ready do
            local pos = GetEntityCoords(PlayerPedId())
            local near = false
            for i, loc in ipairs(Config.Locations) do
                local c = loc.coords
                local dist = #(pos - vec3(c.x, c.y, c.z))
                if dist < PED_DISTANCE then
                    near = true
                    if loc.ped and not peds[i] then spawnPed(i, loc) end
                    if dist < STATE_DISTANCE then refreshState(i) end
                elseif peds[i] then
                    deletePed(i)
                end
            end
            Wait(near and 1000 or 2500)
        end
    end)
end

CreateThread(function()
    local b = Config.Blip
    for _, loc in ipairs(Config.Locations) do
        if loc.blip then
            local c = loc.coords
            local blip = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(blip, b.sprite)
            SetBlipColour(blip, b.color)
            SetBlipScale(blip, b.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(L('blip_name'))
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end
    end
end)

Bridge.OnPlayerLoaded(setup)

-- Changement de job / service : l'état sera relu.
Bridge.OnJobUpdate(function()
    states = {}
end)

------------------------------------------------------------------------
-- Consentement du patient (serveur -> client)
------------------------------------------------------------------------

Callback.Register('pop_medexam:consent', function(price, doctor)
    if consentActive or running then return false end
    consentActive = true
    local keys = Config.Keys
    SendNUIMessage({
        action = 'pop_medexam:consent', show = true, doctor = tostring(doctor or ''),
        price = tonumber(price) or 0, acceptKey = keys.Interact.label, refuseKey = keys.Cancel.label,
    })

    local accepted = false
    local deadline = GetGameTimer() + CONSENT_TIMEOUT
    while consentActive and GetGameTimer() < deadline do
        -- Touches désactivées pour ne pas déclencher le prompt ou une autre action en même temps.
        DisableControlAction(0, keys.Interact.control, true)
        DisableControlAction(0, keys.Cancel.control, true)
        if IsDisabledControlJustReleased(0, keys.Interact.control) then
            accepted = true
            break
        end
        if IsDisabledControlJustReleased(0, keys.Cancel.control) then break end
        Wait(0)
    end

    SendNUIMessage({ action = 'pop_medexam:consent', show = false })
    consentActive = false
    return accepted
end)

------------------------------------------------------------------------
-- Events serveur
------------------------------------------------------------------------

RegisterNetEvent('pop_medexam:client:sessionEnded', function(reason)
    Bridge.CancelProgress()
    Bridge.Notify(L(type(reason) == 'string' and reason or 'error'), 'error')
end)

RegisterNetEvent('pop_medexam:client:showCertificate', function(card)
    if type(card) ~= 'table' then return end
    cardToken = cardToken + 1
    local token = cardToken
    SendNUIMessage({
        action = 'pop_medexam:certificate', show = true,
        name = tostring(card.name or ''), issued = tostring(card.issued or ''),
        expires = card.expires and tostring(card.expires) or nil,
        doctor = tostring(card.doctor or ''), valid = card.valid == true,
    })
    SetTimeout(CARD_TIME, function()
        if cardToken == token then
            SendNUIMessage({ action = 'pop_medexam:certificate', show = false })
        end
    end)
end)

------------------------------------------------------------------------
-- Arrêt
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    ready = false
    consentActive = false
    endSkill(false)
    SetNuiFocus(false, false)
    for i in pairs(peds) do deletePed(i) end
    for _, id in pairs(zones) do Bridge.Target.Remove(id) end
    zones = {}
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    blips = {}
    SendNUIMessage({ action = 'pop_medexam:skill', show = false })
    SendNUIMessage({ action = 'pop_medexam:consent', show = false })
    SendNUIMessage({ action = 'pop_medexam:certificate', show = false })
end)
