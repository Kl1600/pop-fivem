local ESX = nil
local QBCore = nil

if Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
elseif Config.Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
end

function ShowNotification(msg, duration)
    -- Remove HTML for non-custom notifications
    local cleanMsg = msg:gsub("<[^>]+>", "")
    
    local notifType = Config.Notifications or 'esx'
    if notifType == 'notification' then
        exports["pop_notify"]:ShowNotify({  
            message = msg,
            icon = "fas fa-info",
            duration = duration or 7000,
        })
    elseif notifType == 'qbcore' and QBCore then
        QBCore.Functions.Notify(cleanMsg, 'primary', duration or 7000)
    elseif ESX then
        ESX.ShowNotification(cleanMsg)
    end
end

RegisterNetEvent('grandtheftauto:client:ShowNotify')
AddEventHandler('grandtheftauto:client:ShowNotify', function(data)
    ShowNotification(data.message, data.duration)
end)

-- Chargements avec délai max (plus de boucle infinie si un modèle n'existe pas)
function LoadModel(model, timeoutMs)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local limit = GetGameTimer() + (timeoutMs or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > limit then return nil end
        Wait(10)
    end
    return hash
end

-- Renvoie le hash du premier modèle disponible parmi la liste
function LoadFirstModel(list)
    for _, m in ipairs(list) do
        if m then
            local hash = LoadModel(m)
            if hash then return hash end
        end
    end
    return nil
end

function LoadAnimDict(dict, timeoutMs)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local limit = GetGameTimer() + (timeoutMs or 5000)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > limit then return false end
        Wait(10)
    end
    return true
end

activePrompts = {}

function ShowPrompt(id, coords, text, icon)
    local uiType = Config.UI or 'esx'
    
    if uiType == 'pop_v3dui' then
        if not activePrompts[id] then
            activePrompts[id] = exports["pop_v3dui"]:Create({
                coords = coords,
                type = "prompt",
                content = { key = "E", label = text, icon = icon or "fas fa-hand-paper" },
                drawDistance = 10.0
            })
        end
    elseif uiType == 'qbcore' and QBCore then
        if not activePrompts[id] then
            activePrompts[id] = true
            exports['qb-core']:DrawText('[E] ' .. text, 'left')
        end
    elseif ESX then
        if not activePrompts[id] then
            activePrompts[id] = true
            ESX.ShowHelpNotification('Appuyez sur ~INPUT_CONTEXT~ pour ' .. text)
        end
    end
end

function HidePrompt(id)
    local uiType = Config.UI or 'esx'
    if activePrompts[id] then
        if uiType == 'pop_v3dui' then
            exports["pop_v3dui"]:Remove(activePrompts[id])
        elseif uiType == 'qbcore' and QBCore then
            exports['qb-core']:HideText()
        end
        activePrompts[id] = nil
    end
end

-- ==========================================
-- LASERS DE SÉCURITÉ (kq_lasers, facultatif)
-- ==========================================
-- Créés au lancement du casse (pas au démarrage de la ressource) et éteints par défaut.
-- Si kq_lasers est absent ou ne démarre pas (licence), la mission continue sans lasers.

local LaserPoints = {
    { vector3(-57.153, 64.519, 70.600), vector3(-59.235, 66.098, 74.006) },
    { vector3(-62.561, 65.485, 70.616), vector3(-55.872, 62.558, 73.966) },
    { vector3(-60.953, 70.252, 70.616), vector3(-70.540, 70.550, 74.032) },
    { vector3(-73.168, 70.077, 70.615), vector3(-71.556, 74.149, 74.033) },
    { vector3(-66.260, 72.684, 70.615), vector3(-71.196, 66.654, 74.032) },
    { vector3(-72.306, 74.974, 70.615), vector3(-74.276, 70.850, 74.032) },
    { vector3(-63.622, 71.386, 70.615), vector3(-76.291, 69.335, 73.020) },
    { vector3(-56.634, 68.014, 70.616), vector3(-63.154, 66.729, 74.006) },
    { vector3(-62.969, 65.034, 74.006), vector3(-59.910, 68.502, 70.616) },
    { vector3(-68.120, 77.455, 72.918), vector3(-71.873, 71.447, 70.629) },
    { vector3(-67.584, 71.863, 74.032), vector3(-69.374, 65.338, 71.534) },
    { vector3(-79.970, 73.918, 71.704), vector3(-76.041, 71.395, 70.615) },
    { vector3(-69.873, 74.781, 74.033), vector3(-76.042, 76.807, 70.615) },
    { vector3(-74.655, 70.445, 70.615), vector3(-76.440, 72.670, 74.020) },
    { vector3(-70.106, 73.888, 73.510), vector3(-57.158, 68.629, 70.616) },
    { vector3(-56.238, 68.734, 74.033), vector3(-63.947, 72.486, 70.615) },
    { vector3(-67.246, 64.109, 72.967), vector3(-61.745, 67.988, 70.616) },
    { vector3(-58.657, 72.421, 74.032), vector3(-59.259, 68.589, 70.616) },
    { vector3(-62.939, 75.054, 72.598), vector3(-60.672, 72.811, 70.615) },
    { vector3(-56.502, 68.483, 70.616), vector3(-53.087, 70.831, 73.388) },
    { vector3(-68.050, 67.081, 70.615), vector3(-65.585, 65.563, 74.006) },
    { vector3(-66.985, 65.808, 70.615), vector3(-69.140, 67.203, 74.006) },
    { vector3(-78.223, 78.288, 70.615), vector3(-79.313, 71.184, 74.033) },
}

local lasers = {}

local function CreateLasers()
    if #lasers > 0 then return end
    if GetResourceState('kq_lasers') ~= 'started' then return end
    for i, pts in ipairs(LaserPoints) do
        local ok, laser = pcall(function()
            return exports['kq_lasers']:CreateLaser('thornton_laser' .. i, {
                origin = pts[1],
                endPoint = pts[2],
                maxLength = 15.0,
                damage = 5,
                ragdoll = false,
                cooldown = 10000,
                active = false,
                triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = {} } }
            })
        end)
        if ok and laser then lasers[#lasers + 1] = laser end
    end
end

local function SetLasers(active)
    if active then CreateLasers() end
    for _, laser in ipairs(lasers) do
        pcall(function() laser.SetActive(active) end)
    end
end

local function DeleteLasers()
    for _, laser in ipairs(lasers) do
        pcall(function() laser.Delete() end)
    end
    lasers = {}
end

AddEventHandler('mission:local:lasers', function(active) SetLasers(active == true) end)

-- ==========================================
-- COUPURE DE COURANT
-- ==========================================
local blackoutOn = false
function Blackout(state)
    blackoutOn = state == true
    SetArtificialLightsState(blackoutOn)
    SetArtificialLightsStateAffectsVehicles(false)
end
AddEventHandler('mission:local:blackout', function(state) Blackout(state) end)

-- ==========================================
-- MINI-JEU (ultra-voltlab)
-- ==========================================
-- Lance le mini-jeu et attend le résultat. Renvoie true si réussi.
-- (Le rappel n'appelle pas Wait : on attend ici, dans notre propre thread.)
function RunVoltlab(seconds)
    if GetResourceState('ultra-voltlab') ~= 'started' then
        ShowNotification("Mini-jeu indisponible (<span style='color:#E74C3C; font-weight:bold;'>ultra-voltlab</span> non démarré).", 5000)
        return false
    end
    local p = promise.new()
    TriggerEvent('ultra-voltlab', seconds or 40, function(outcome)
        p:resolve(outcome)
    end)
    local outcome = Citizen.Await(p)
    return outcome == 1
end

-- ==========================================
-- MINUTEUR (après la coupure de courant)
-- ==========================================
local API_ProgressBar = nil
local missionTimerBar = nil
local timerToken = 0

local function RemoveTimerBar()
    if missionTimerBar and API_ProgressBar then
        pcall(function() API_ProgressBar.remove(missionTimerBar._id) end)
    end
    missionTimerBar = nil
end

function StartMissionTimer()
    if missionTimerBar then return end
    local timeLeft = Config.Timer or 240
    timerToken = timerToken + 1
    local myToken = timerToken

    if GetResourceState('clm_ProgressBar') == 'started' then
        API_ProgressBar = API_ProgressBar or exports["clm_ProgressBar"]:GetAPI()
        missionTimerBar = API_ProgressBar.add("TextTimerBar", "TEMPS RESTANT", string.format("%02d:%02d", math.floor(timeLeft / 60), timeLeft % 60))
        missionTimerBar.Func.setTitleColor({255, 255, 255, 255})
        missionTimerBar.Func.lib.TextTimerBar.setTextColor({255, 50, 50, 255})
    end

    Citizen.CreateThread(function()
        while timeLeft > 0 do
            Citizen.Wait(1000)
            if myToken ~= timerToken then return end
            timeLeft = timeLeft - 1

            if missionTimerBar then
                missionTimerBar.Func.lib.TextTimerBar.setText(string.format("%02d:%02d", math.floor(timeLeft / 60), timeLeft % 60))
                if timeLeft <= 30 then
                    missionTimerBar.Func.setHighlightColor({255, 0, 0, 255})
                end
            end
        end

        -- Une fois le temps écoulé : retour du courant et des lasers
        ShowSubtitle("~r~Temps écoulé ! La police arrive !")
        Blackout(false)
        Wait(500)
        SetLasers(true)
        RemoveTimerBar()
    end)
end

-- Minuteur relayé aux coéquipiers (évènement local 'StartMissionTimer')
AddEventHandler('StartMissionTimer', function() StartMissionTimer() end)

RegisterNetEvent("grandtheftauto:alarme")
AddEventHandler("grandtheftauto:alarme", function()
    if not (_G.MissionSync and _G.MissionSync.active) then return end
    TriggerEvent('__chHyperSound:play', 0, "intrusion", false, Config.ShowroomPos, 30.0)
    SetLasers(false)
    -- ALERTE POLICE SUR LES LIEUX (cooldown côté serveur)
    TriggerServerEvent('mission:server:alertPoliceLocation')
end)

-- Lasers allumés au lancement du casse (avant la coupure de courant)
AddEventHandler('startheist', function()
    SetLasers(true)
end)

-- Fin de mission / arrêt de la ressource : tout remettre comme avant
AddEventHandler('mission:local:reset', function()
    timerToken = timerToken + 1
    RemoveTimerBar()
    if blackoutOn then Blackout(false) end
    SetLasers(false)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    RemoveTimerBar()
    if blackoutOn then Blackout(false) end
    DeleteLasers()
    for id in pairs(activePrompts) do HidePrompt(id) end
end)
