-- pop_radio : client. Aucune boucle : tout est piloté par les events, la NUI et la touche.
-- Le client ne pose jamais le canal pma-voice : c'est le serveur qui décide (setPlayerRadio).

local KVP_VOLUME = 'pop_radio:volume'
local KVP_LAST = 'pop_radio:last'

local ANIM_DICT = 'cellphone@'
local ANIM_CLIP = 'cellphone_text_read_base'
local PROP_MODEL = joaat('prop_cs_hand_radio')

local current = 0 -- canal actuel (0 = éteinte)
local volume = math.tointeger(tonumber(GetResourceKvpString(KVP_VOLUME))) or 50
local last = math.tointeger(tonumber(GetResourceKvpString(KVP_LAST))) or 0
local uiOpen = false
local opening = false -- ouverture en cours (attente du serveur)
local pending = false -- requête join / leave en cours

local prop = nil
local animToken = 0 -- invalide un chargement d'animation en cours si l'interface se ferme

volume = math.max(0, math.min(100, volume))

------------------------------------------------------------------------
-- pma-voice (appels protégés : le script démarre sans)
------------------------------------------------------------------------

local function voiceStarted()
    return GetResourceState('pma-voice') == 'started'
end

local function setRadioEnabled(enabled)
    if not voiceStarted() then return end
    pcall(function() exports['pma-voice']:setVoiceProperty('radioEnabled', enabled) end)
end

local function applyVolume()
    if not voiceStarted() then return end
    pcall(function() exports['pma-voice']:setRadioVolume(volume) end)
end

------------------------------------------------------------------------
-- Animation + prop (seulement interface ouverte, à pied)
------------------------------------------------------------------------

local function stopAnim()
    animToken = animToken + 1
    local ped = PlayerPedId()
    if IsEntityPlayingAnim(ped, ANIM_DICT, ANIM_CLIP, 3) then
        StopAnimTask(ped, ANIM_DICT, ANIM_CLIP, 1.0)
    end
    if prop then
        if DoesEntityExist(prop) then
            DetachEntity(prop, true, false)
            SetEntityAsMissionEntity(prop, true, true)
            DeleteEntity(prop)
        end
        prop = nil
    end
    RemoveAnimDict(ANIM_DICT)
end

local function loaded(check, timeoutMs)
    local timeout = GetGameTimer() + timeoutMs
    while not check() and GetGameTimer() < timeout do Wait(10) end
    return check()
end

local function startAnim()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end
    animToken = animToken + 1
    local token = animToken

    CreateThread(function()
        RequestAnimDict(ANIM_DICT)
        RequestModel(PROP_MODEL)
        local dictOk = loaded(function() return HasAnimDictLoaded(ANIM_DICT) end, 2000)
        local modelOk = loaded(function() return HasModelLoaded(PROP_MODEL) end, 2000)

        -- Interface fermée entre-temps : on abandonne.
        if token ~= animToken or not uiOpen then
            if modelOk then SetModelAsNoLongerNeeded(PROP_MODEL) end
            return
        end

        if dictOk then
            TaskPlayAnim(ped, ANIM_DICT, ANIM_CLIP, 3.0, 3.0, -1, 49, 0.0, false, false, false)
        end

        if modelOk then
            local c = GetEntityCoords(ped)
            local obj = CreateObject(PROP_MODEL, c.x, c.y, c.z, true, false, false)
            SetModelAsNoLongerNeeded(PROP_MODEL)
            -- Création refusée (verrouillage des entités du serveur) : pas de prop.
            if obj ~= 0 and DoesEntityExist(obj) then
                SetEntityCollision(obj, false, false)
                AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, 60309),
                    0.09, 0.03, -0.02, -80.0, 0.0, 0.0, true, true, false, true, 1, true)
                prop = obj
            end
        end
    end)
end

------------------------------------------------------------------------
-- Interface
------------------------------------------------------------------------

local function sendState()
    SendNUIMessage({ action = 'pop_radio:state', frequency = current, volume = volume })
end

local function closeUi()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'pop_radio:close' })
    stopAnim()
end

-- Mort pendant que l'interface est ouverte : fermeture (vérification toutes les 500 ms, interface ouverte seulement).
local watching = false
local function watchDeath()
    if watching then return end
    watching = true
    CreateThread(function()
        while uiOpen do
            Wait(500)
            if uiOpen and IsEntityDead(PlayerPedId()) then closeUi() end
        end
        watching = false
    end)
end

local function showUi()
    if uiOpen then return end
    uiOpen = true
    SendNUIMessage({
        action = 'pop_radio:open',
        frequency = current,
        last = last,
        volume = volume,
        max = Config.MaxFrequency,
    })
    SetNuiFocus(true, true)
    startAnim()
    watchDeath()
end

local function canOpenLocally()
    return not uiOpen and not opening and not IsNuiFocused() and not Bridge.IsBusy()
end

-- Item utilisé : le serveur a déjà vérifié l'item. L'inventaire peut encore tenir le focus NUI
-- quelques instants après l'utilisation : on attend jusqu'à 1 s qu'il le rende.
RegisterNetEvent('pop_radio:client:open', function()
    if uiOpen then
        if IsNuiFocused() then return end -- interface réellement ouverte
        uiOpen = false -- état orphelin (focus perdu) : on repart proprement
        stopAnim()
    end
    local timeout = GetGameTimer() + 1000
    while IsNuiFocused() and GetGameTimer() < timeout do Wait(50) end
    if not canOpenLocally() then return end
    showUi()
end)

-- Touche / commande : on demande d'abord au serveur.
RegisterCommand('pop_radio_open', function()
    if not canOpenLocally() then return end
    opening = true
    CreateThread(function()
        local ok, reason, serverChannel = Callback.Await('pop_radio:canOpen')
        opening = false
        if not ok then
            Bridge.Notify(L(reason or 'error', reason == 'missing_item' and L('item_radio') or nil), 'error')
            return
        end
        -- Le serveur fait foi pour le canal actuel.
        current = math.tointeger(serverChannel) or 0
        if not canOpenLocally() then return end
        showUi()
    end)
end, false)

RegisterKeyMapping('pop_radio_open', L('keymap_open'), 'keyboard', Config.OpenKey or '')

-- Échap ou Pop.post('close') : le focus est déjà rendu par le bridge.
Bridge.OnUiClose(function()
    if not uiOpen then return end
    uiOpen = false
    stopAnim()
end)

------------------------------------------------------------------------
-- Callbacks NUI
------------------------------------------------------------------------

RegisterNUICallback('pop_radio:join', function(data, cb)
    local freq = math.tointeger(tonumber(type(data) == 'table' and data.frequency or nil))
    if not freq or freq < 1 or freq > Config.MaxFrequency then
        Bridge.Notify(L('invalid_frequency', Config.MaxFrequency), 'error')
        return cb({ ok = false })
    end
    if pending then return cb({ ok = false }) end
    pending = true

    local ok, reason, arg = Callback.Await('pop_radio:join', freq)
    pending = false
    if not ok then
        Bridge.Notify(L(reason or 'error', arg), 'error')
        return cb({ ok = false })
    end

    current, last = freq, freq
    SetResourceKvp(KVP_LAST, tostring(freq))
    setRadioEnabled(true)
    sendState()
    cb({ ok = true })
end)

RegisterNUICallback('pop_radio:leave', function(_, cb)
    if pending then return cb({ ok = false }) end
    pending = true

    local ok, reason = Callback.Await('pop_radio:leave')
    pending = false
    if not ok then Bridge.Notify(L(reason or 'error'), 'error') end

    setRadioEnabled(false)
    current = 0
    sendState()
    cb({ ok = ok == true })
end)

RegisterNUICallback('pop_radio:volume', function(data, cb)
    local delta = math.tointeger(tonumber(type(data) == 'table' and data.delta or nil))
    if delta == 10 or delta == -10 then
        volume = math.max(0, math.min(100, volume + delta))
        applyVolume()
        SetResourceKvp(KVP_VOLUME, tostring(volume))
    end
    cb({ volume = volume })
end)

------------------------------------------------------------------------
-- Serveur : radio coupée (item ou job perdu, export TurnOff)
------------------------------------------------------------------------

RegisterNetEvent('pop_radio:client:forceOff', function(reason)
    setRadioEnabled(false)
    current = 0
    sendState()
    Bridge.Notify(L(type(reason) == 'string' and reason or 'error'), 'error')
end)

------------------------------------------------------------------------
-- Chargement, export, nettoyage
------------------------------------------------------------------------

Bridge.OnPlayerLoaded(function()
    applyVolume()
end)

-- Redémarrage du script : le serveur reprend les canaux encore autorisés (state bag pma-voice) ;
-- on réaligne l'état local et radioEnabled.
CreateThread(function()
    Wait(2000)
    local ch = math.tointeger(tonumber(LocalPlayer.state.radioChannel))
    if ch and ch > 0 and current == 0 then
        current = ch
        setRadioEnabled(true)
        applyVolume()
    end
end)

exports('GetFrequency', function()
    return current
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    closeUi()
    stopAnim()
    if current ~= 0 then setRadioEnabled(false) end
end)
