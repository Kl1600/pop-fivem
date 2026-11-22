-- =====================================================
-- RADIO (importée depuis l'ex-resource [interact]/radio)
-- NUI inline dans pop_inventory (html/radio/* + #radio-root dans index.html).
-- SendNUIMessage cible directement la page de l'inventaire -> pas de relais.
-- Alimentation pilotée par l'équipement (pop_inventory:client:setRadioPower).
-- =====================================================
-- ESX direct (client/common.lua) : données du job pour les fréquences réservées.
local PlayerData = {}

CreateThread(function()
    while ESX.GetPlayerData().job == nil do
        Wait(500)
    end
    PlayerData = ESX.GetPlayerData()
end)

local function SetFieldValueFromNameEncode(stringName, data)
    SetResourceKvp(stringName, json.encode(data))
end

local function GetFieldValueFromName(stringName)
    local data = GetResourceKvpString(stringName)
    return data and json.decode(data) or {}
end

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
end)

local radioOpen = false

--- Vrai si le panneau radio est affiché (utilisé par la fermeture NUI, client/main.lua).
function Inv.isRadioOpen()
    return radioOpen
end
local currentVolume = 75
local radioFreq = 0
local radioActif = false
local RadioActived = false
local RadioMute = false

local FrequenceJob = {
    {job = "police", freq = 1},
    {job = "police", freq = 2},
    {job = "police", freq = 3},
    {job = "police", freq = 4},
    {job = "police", freq = 5},
    {job = "ems", freq = 6},
    {job = "ems", freq = 7},
    {job = "ems", freq = 8},
    {job = "ems", freq = 9},
    {job = "ems", freq = 10}
}

local controlDisabled = {1, 2, 3, 4, 5, 6, 18, 24, 25, 37, 68, 69, 70, 91, 92, 182, 199, 200, 257}
local KEEP_FOCUS = false
local threadCreated = false

function SetKeepInputMode(bool)
    if SetNuiFocusKeepInput then
        SetNuiFocusKeepInput(bool)
    end
    KEEP_FOCUS = bool
    if not threadCreated and bool then
        threadCreated = true
        CreateThread(function()
            while KEEP_FOCUS do
                Wait(0)
                for _, v in pairs(controlDisabled) do
                    DisableControlAction(0, v, true)
                end
            end
            threadCreated = false
        end)
    end
end

local function inventoryHasFocus()
    -- L'inventaire et la radio partagent la même NUI : ne pas relâcher le focus
    -- si l'inventaire est ouvert (sinon le curseur de l'inventaire disparaît).
    local ok, open = pcall(function() return exports.pop_inventory:IsInventoryOpen() end)
    return ok and open == true
end

local radioPropEntity = nil

local function startRadioOpenAnim()
    local playerPed = PlayerPedId()
    if IsPedInVehicle(playerPed, GetVehiclePedIsIn(playerPed, false), false) then return end

    local animDict = "cellphone@"
    local animName = "cellphone_text_read_base"

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end

    TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)

    local propModel = GetHashKey('prop_cs_hand_radio')
    RequestModel(propModel)
    while not HasModelLoaded(propModel) do
        Wait(10)
    end

    local coords = GetEntityCoords(playerPed)
    radioPropEntity = CreateObject(propModel, coords.x, coords.y, coords.z, true, true, true)

    local boneIndex = GetPedBoneIndex(playerPed, 60309) -- Left hand
    AttachEntityToEntity(radioPropEntity, playerPed, boneIndex,
        0.09, 0.03, -0.02,
        -80.0, 0.0, 0.0,
        true, true, false, true, 1, true)
end

local function stopRadioOpenAnim()
    local playerPed = PlayerPedId()
    if IsEntityPlayingAnim(playerPed, "cellphone@", "cellphone_text_read_base", 3) then
        StopAnimTask(playerPed, "cellphone@", "cellphone_text_read_base", 3.0)
    end

    if radioPropEntity and DoesEntityExist(radioPropEntity) then
        DeleteEntity(radioPropEntity)
        radioPropEntity = nil
    end
end

function closeRadio()
    radioOpen = false
    SendNUIMessage({ type = 'showradio', toggle = false })
    if not inventoryHasFocus() then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
    SetKeepInputMode(false)
    stopRadioOpenAnim()
    -- Disable ESC for a few frames to prevent pause menu from popping up
    CreateThread(function()
        local ticks = 15
        while ticks > 0 do
            Wait(0)
            ticks = ticks - 1
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 322, true)
        end
    end)
end

function IconeRadioMute()
    SendNUIMessage({ type = 'showMuteIcon', toggle = true })
    SendNUIMessage({ type = 'IconRadio', toggle = true })
    SendNUIMessage({ type = 'IconMicro', toggle = true })
    SendNUIMessage({ type = 'setFrequence', data = "" })
end

-- Pousse le skin choisi (Config.RadioSkin) vers la NUI : 'modern' ou '80s'.
local function pushRadioSkin()
    SendNUIMessage({ type = 'radioSkin', skin = (Config and Config.RadioSkin) or 'modern' })
end

function toggleRadio()
    -- Ne pas interférer avec l'inventaire ouvert (P ne doit pas voler le curseur).
    if inventoryHasFocus() then return end

    -- La radio est toujours active et allumée par défaut
    radioActif = true
    RadioActived = true
    pushRadioSkin()
    SendNUIMessage({ type = "showIconsRadioOn" })

    radioOpen = not radioOpen
    SendNUIMessage({ type = 'showradio', toggle = radioOpen })
    SetNuiFocus(radioOpen, radioOpen)
    SetNuiFocusKeepInput(radioOpen)
    SetKeepInputMode(radioOpen)

    if radioOpen then
        startRadioOpenAnim()
    else
        stopRadioOpenAnim()
    end
end

-- Allumage/extinction DÉTERMINISTE piloté par l'inventaire (slot radio équipé/retiré).
RegisterNetEvent('pop_inventory:client:setRadioPower')
AddEventHandler('pop_inventory:client:setRadioPower', function(enabled)
    enabled = enabled and true or false
    if enabled == radioActif then return end
    radioActif = enabled
    LocalPlayer.state:set("hasRadio", enabled, true)
    if enabled then
        -- Allumage automatique de la radio à l'équipement
        RadioActived = true
        SendNUIMessage({ type = "showIconsRadioOn" })

        -- Restauration automatique de la dernière fréquence utilisée
        local savedFreq = GetFieldValueFromName("zroleplayFreqRadio")
        if savedFreq and json.encode(savedFreq) ~= "[]" then
            local freq = tonumber(savedFreq)
            if freq and freq > 0 then
                local restricted = false
                if PlayerData and PlayerData.job and PlayerData.job.name then
                    for _, v in pairs(FrequenceJob) do
                        if freq == v.freq and PlayerData.job.name ~= v.job then
                            restricted = true
                            break
                        end
                    end
                end

                if not restricted then
                    SendNUIMessage({ type = 'setFrequence', data = tostring(freq) })
                    exports["pma-voice"]:setVoiceProperty("radioEnabled", true)
                    exports["pma-voice"]:SetRadioChannel(freq)
                    radioFreq = 1
                    RadioMute = true
                    TriggerEvent("CallRadioDefault")
                end
            end
        end
    else
        exports["pma-voice"]:setVoiceProperty("radioEnabled", false)
        exports["pma-voice"]:SetRadioChannel(0)
        radioFreq = 0
        RadioActived = false
        RadioMute = false
        IconeRadioMute()
        closeRadio()
        SetKeepInputMode(false)
    end
end)

-- « Utiliser » la radio depuis l'inventaire : ouvre/ferme le panneau.
-- Si l'inventaire est ouvert (clic sur « Utiliser »), on le ferme D'ABORD pour
-- qu'aucune UI n'en gêne une autre, puis on ouvre la radio une fois le focus rendu.
RegisterNetEvent('pop_inventory:client:openRadioPanel')
AddEventHandler('pop_inventory:client:openRadioPanel', function()
    if inventoryHasFocus() then
        TriggerEvent('pop_inventory:client:forceClose')
        CreateThread(function()
            -- on attend que l'inventaire relâche le focus NUI avant d'ouvrir la radio
            local tries = 60
            while IsNuiFocused() and tries > 0 do
                Wait(10)
                tries = tries - 1
            end
            Wait(50)
            toggleRadio()
        end)
    else
        toggleRadio()
    end
end)

-- Compat : ancien event toggle (au cas où une autre resource l'appellerait encore).
RegisterNetEvent('setActiveRadio')
AddEventHandler('setActiveRadio', function()
    TriggerEvent('pop_inventory:client:setRadioPower', not radioActif)
end)

RegisterKeyMapping("+volumeUp", L('key_radio_volume_up'), "keyboard", "PAGEUP")
RegisterCommand("+volumeUp", function()
    if radioFreq == 1 and currentVolume >= 0 and currentVolume < 100 then
        currentVolume = currentVolume + 5
        exports['pma-voice']:setRadioVolume(currentVolume)
        ESX.DrawMissionText(L('radio_volume', math.floor(currentVolume)), 2000)
    end
end)

RegisterKeyMapping("+volumeDown", L('key_radio_volume_down'), "keyboard", "PAGEDOWN")
RegisterCommand("+volumeDown", function()
    if radioFreq == 1 and currentVolume > 0 then
        currentVolume = currentVolume - 5
        exports['pma-voice']:setRadioVolume(currentVolume)
        ESX.DrawMissionText(L('radio_volume', math.floor(currentVolume)), 2000)
    end
end)

RegisterKeyMapping("+radio", L('key_radio'), "keyboard", "P")
RegisterCommand("+radio", function()
    -- Ne pas OUVRIR la radio par-dessus une autre interface (NUI) déjà active.
    -- (Si la radio est déjà ouverte, on autorise la bascule pour la fermer.)
    if not radioOpen and IsNuiFocused() then return end
    toggleRadio()
end)

RegisterNetEvent('IconeMuteRadio')
AddEventHandler('IconeMuteRadio', function(status)
    SendNUIMessage({ type = 'showMuteIcon', toggle = status })
    SendNUIMessage({ type = 'IconRadio', toggle = status })
    SendNUIMessage({ type = 'IconMicro', toggle = status })
end)

RegisterNUICallback('requestFreq', function(data, cb)
    RadioActived = true
    SendNUIMessage({ type = "showIconsRadioOn" })
    if ESX.KeyboardInput then
        SetNuiFocus(false, false)
        local frequence = ESX.KeyboardInput(L('radio_freq_label'), 5)

        for _, v in pairs(FrequenceJob) do
            if tonumber(frequence) == v.freq and PlayerData.job.name ~= v.job then
                SetNuiFocus(true, true)
                Inv.Notify(L('radio_private_freq'))
                cb('ok')
                return
            end
        end

        if frequence ~= '' and tonumber(frequence) and frequence ~= nil then
            SendNUIMessage({ type = 'setFrequence', data = frequence })
            Inv.Notify(L('radio_connected', frequence))
            exports["pma-voice"]:setVoiceProperty("radioEnabled", true)
            exports["pma-voice"]:SetRadioChannel(frequence)
            SetFieldValueFromNameEncode("zroleplayFreqRadio", frequence)
            radioFreq = 1
            RadioMute = true
            SetNuiFocus(true, true)
            PlaySoundFrontend(-1, "OK", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
            TriggerEvent("CallRadioDefault")
        else
            SetNuiFocus(true, true)
        end
    else
        Inv.Notify(L('radio_no_keyboard'))
    end
    cb('ok')
end)

RegisterNUICallback('setRadioFreq', function(data, cb)
    RadioActived = true
    SendNUIMessage({ type = "showIconsRadioOn" })
    local frequence = tonumber(data.frequence)

    if frequence and frequence > 0 then
        for _, v in pairs(FrequenceJob) do
            if frequence == v.freq and PlayerData.job.name ~= v.job then
                Inv.Notify(L('radio_private_freq'))
                if cb then cb('ok') end
                return
            end
        end

        SendNUIMessage({ type = 'setFrequence', data = tostring(frequence) })
        Inv.Notify(L('radio_connected', frequence))
        exports["pma-voice"]:setVoiceProperty("radioEnabled", true)
        exports["pma-voice"]:SetRadioChannel(frequence)
        SetFieldValueFromNameEncode("zroleplayFreqRadio", frequence)
        radioFreq = 1
        RadioMute = true
        PlaySoundFrontend(-1, "OK", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
        TriggerEvent("CallRadioDefault")
    else
        Inv.Notify(L('radio_invalid_freq'))
    end
    if cb then cb('ok') end
end)

RegisterNUICallback('closeRadio', function(data, cb)
    closeRadio()
    if cb then cb('ok') end
end)

RegisterNUICallback('muteRadio', function(data, cb)
    RadioActived = true
    SendNUIMessage({ type = "showIconsRadioOn" })
    if RadioMute then
        ExecuteCommand("-muteradio")
        PlaySoundFrontend(-1, "NAV_LEFT_RIGHT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    end
    if cb then cb('ok') end
end)

RegisterNUICallback('offRadio', function(data, cb)
    if RadioActived then
        exports["pma-voice"]:setVoiceProperty("radioEnabled", false)
        exports["pma-voice"]:SetRadioChannel(0)
        Inv.Notify(L('radio_disabled'))
        radioFreq = 0
        RadioActived = false
        RadioMute = false
        SendNUIMessage({ type = 'IconRadio', toggle = true })
        PlaySoundFrontend(-1, "NAV_LEFT_RIGHT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    else
        Inv.Notify(L('radio_enabled'))
        RadioActived = true
        SendNUIMessage({ type = "showIconsRadioOn" })
        PlaySoundFrontend(-1, "NAV_LEFT_RIGHT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
        if json.encode(GetFieldValueFromName("zroleplayFreqRadio")) ~= "[]" then
            local freq = GetFieldValueFromName("zroleplayFreqRadio")

            for _, v in pairs(FrequenceJob) do
                if tonumber(freq) == v.freq and PlayerData.job.name ~= v.job then
                    SetNuiFocus(true, true)
                    if cb then cb('ok') end
                    return
                end
            end

            SendNUIMessage({ type = 'setFrequence', data = freq })
            Inv.Notify(L('radio_connected', freq))
            exports["pma-voice"]:setVoiceProperty("radioEnabled", true)
            exports["pma-voice"]:SetRadioChannel(freq)
            SetFieldValueFromNameEncode("zroleplayFreqRadio", freq)
            radioFreq = 1
            RadioMute = true
            SetNuiFocus(true, true)
            PlaySoundFrontend(-1, "OK", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
            TriggerEvent("CallRadioDefault")
        end
    end
    if cb then cb('ok') end
end)

RegisterNUICallback('volumeUp', function(data, cb)
    if radioFreq and RadioActived and currentVolume >= 0 and currentVolume < 100 then
        currentVolume = currentVolume + 5
        exports['pma-voice']:setRadioVolume(currentVolume)
        ESX.DrawMissionText(L('radio_volume_nui', math.floor(currentVolume)), 2000)
        PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    end
    if cb then cb('ok') end
end)

RegisterNUICallback('volumeDown', function(data, cb)
    if radioFreq and RadioActived and currentVolume > 0 then
        currentVolume = currentVolume - 5
        exports['pma-voice']:setRadioVolume(currentVolume)
        ESX.DrawMissionText(L('radio_volume_nui', math.floor(currentVolume)), 2000)
        PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    end
    if cb then cb('ok') end
end)
