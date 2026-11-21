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

local activePrompts = {}

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
-- CONFIGURATION ET CRÉATION DES 23 LASERS
-- ==========================================

-- LASER 1
-- Lasers (kq_lasers) : facultatifs. Si la ressource est absente ou refuse de démarrer
-- (licence), la mission continue sans lasers au lieu de planter.
local function SafeCreateLaser(id, data)
    local dummy = { SetActive = function() end }
    if GetResourceState('kq_lasers') ~= 'started' then return dummy end
    local ok, laser = pcall(function() return SafeCreateLaser(id, data) end)
    if ok and laser then return laser end
    return dummy
end

local laserData1 = {
    origin = vector3(-57.153, 64.519, 70.600),
    endPoint = vector3(-59.235, 66.098, 74.006),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser1 = SafeCreateLaser('thornton_laser1', laserData1)

-- LASER 2
local laserData2 = {
    origin = vector3(-62.561, 65.485, 70.616),
    endPoint = vector3(-55.872, 62.558, 73.966),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser2 = SafeCreateLaser('thornton_laser2', laserData2)

-- LASER 3
local laserData3 = {
    origin = vector3(-60.953, 70.252, 70.616),
    endPoint = vector3(-70.540, 70.550, 74.032),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser3 = SafeCreateLaser('thornton_laser3', laserData3)

-- LASER 4
local laserData4 = {
    origin = vector3(-73.168, 70.077, 70.615),
    endPoint = vector3(-71.556, 74.149, 74.033),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser4 = SafeCreateLaser('thornton_laser4', laserData4)

-- LASER 5
local laserData5 = {
    origin = vector3(-66.260, 72.684, 70.615),
    endPoint = vector3(-71.196, 66.654, 74.032),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser5 = SafeCreateLaser('thornton_laser5', laserData5)

-- LASER 6
local laserData6 = {
    origin = vector3(-72.306, 74.974, 70.615),
    endPoint = vector3(-74.276, 70.850, 74.032),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser6 = SafeCreateLaser('thornton_laser6', laserData6)

-- LASER 7
local laserData7 = {
    origin = vector3(-63.622, 71.386, 70.615),
    endPoint = vector3(-76.291, 69.335, 73.020),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser7 = SafeCreateLaser('thornton_laser7', laserData7)

-- LASER 8
local laserData8 = {
    origin = vector3(-56.634, 68.014, 70.616),
    endPoint = vector3(-63.154, 66.729, 74.006),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser8 = SafeCreateLaser('thornton_laser8', laserData8)

-- LASER 9
local laserData9 = {
    origin = vector3(-62.969, 65.034, 74.006),
    endPoint = vector3(-59.910, 68.502, 70.616),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser9 = SafeCreateLaser('thornton_laser9', laserData9)

-- LASER 10
local laserData10 = {
    origin = vector3(-68.120, 77.455, 72.918),
    endPoint = vector3(-71.873, 71.447, 70.629),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser10 = SafeCreateLaser('thornton_laser10', laserData10)

-- LASER 11
local laserData11 = {
    origin = vector3(-67.584, 71.863, 74.032),
    endPoint = vector3(-69.374, 65.338, 71.534),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser11 = SafeCreateLaser('thornton_laser11', laserData11)

-- LASER 12
local laserData12 = {
    origin = vector3(-79.970, 73.918, 71.704),
    endPoint = vector3(-76.041, 71.395, 70.615),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser12 = SafeCreateLaser('thornton_laser12', laserData12)

-- LASER 13
local laserData13 = {
    origin = vector3(-69.873, 74.781, 74.033),
    endPoint = vector3(-76.042, 76.807, 70.615),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser13 = SafeCreateLaser('thornton_laser13', laserData13)

-- LASER 14
local laserData14 = {
    origin = vector3(-74.655, 70.445, 70.615),
    endPoint = vector3(-76.440, 72.670, 74.020),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser14 = SafeCreateLaser('thornton_laser14', laserData14)

-- LASER 15
local laserData15 = {
    origin = vector3(-70.106, 73.888, 73.510),
    endPoint = vector3(-57.158, 68.629, 70.616),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser15 = SafeCreateLaser('thornton_laser15', laserData15)

-- LASER 16
local laserData16 = {
    origin = vector3(-56.238, 68.734, 74.033),
    endPoint = vector3(-63.947, 72.486, 70.615),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser16 = SafeCreateLaser('thornton_laser16', laserData16)

-- LASER 17
local laserData17 = {
    origin = vector3(-67.246, 64.109, 72.967),
    endPoint = vector3(-61.745, 67.988, 70.616),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser17 = SafeCreateLaser('thornton_laser17', laserData17)

-- LASER 18
local laserData18 = {
    origin = vector3(-58.657, 72.421, 74.032),
    endPoint = vector3(-59.259, 68.589, 70.616),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser18 = SafeCreateLaser('thornton_laser18', laserData18)

-- LASER 19
local laserData19 = {
    origin = vector3(-62.939, 75.054, 72.598),
    endPoint = vector3(-60.672, 72.811, 70.615),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser19 = SafeCreateLaser('thornton_laser19', laserData19)

-- LASER 20
local laserData20 = {
    origin = vector3(-56.502, 68.483, 70.616),
    endPoint = vector3(-53.087, 70.831, 73.388),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser20 = SafeCreateLaser('thornton_laser20', laserData20)

-- LASER 21
local laserData21 = {
    origin = vector3(-68.050, 67.081, 70.615),
    endPoint = vector3(-65.585, 65.563, 74.006),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser21 = SafeCreateLaser('thornton_laser21', laserData21)

-- LASER 22
local laserData22 = {
    origin = vector3(-66.985, 65.808, 70.615),
    endPoint = vector3(-69.140, 67.203, 74.006),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser22 = SafeCreateLaser('thornton_laser22', laserData22)

-- LASER 23
local laserData23 = {
    origin = vector3(-78.223, 78.288, 70.615),
    endPoint = vector3(-79.313, 71.184, 74.033),
    maxLength = 15.0,
    damage = 5,
    ragdoll = false,
    alarms = { 'lsia' },
    triggers = { { event = 'grandtheftauto:alarme', type = 'client', parameters = { title = 'Laser tripped!', message = 'a security laser at the LSIA has been tripped.', jobs = { 'police' } } } }
}
local laser23 = SafeCreateLaser('thornton_laser23', laserData23)


-- ==========================================
-- COMMANDES DE CONTRÔLE GLOBAL
-- ==========================================

RegisterCommand('laseron', function()
    laser1.SetActive(true)
    laser2.SetActive(true)
    laser3.SetActive(true)
    laser4.SetActive(true)
    laser5.SetActive(true)
    laser6.SetActive(true)
    laser7.SetActive(true)
    laser8.SetActive(true)
    laser9.SetActive(true)
    laser10.SetActive(true)
    laser11.SetActive(true)
    laser12.SetActive(true)
    laser13.SetActive(true)
    laser14.SetActive(true)
    laser15.SetActive(true)
    laser16.SetActive(true)
    laser17.SetActive(true)
    laser18.SetActive(true)
    laser19.SetActive(true)
    laser20.SetActive(true)
    laser21.SetActive(true)
    laser22.SetActive(true)
    laser23.SetActive(true)
end, false)

RegisterCommand('laseroff', function()
    laser1.SetActive(false)
    laser2.SetActive(false)
    laser3.SetActive(false)
    laser4.SetActive(false)
    laser5.SetActive(false)
    laser6.SetActive(false)
    laser7.SetActive(false)
    laser8.SetActive(false)
    laser9.SetActive(false)
    laser10.SetActive(false)
    laser11.SetActive(false)
    laser12.SetActive(false)
    laser13.SetActive(false)
    laser14.SetActive(false)
    laser15.SetActive(false)
    laser16.SetActive(false)
    laser17.SetActive(false)
    laser18.SetActive(false)
    laser19.SetActive(false)
    laser20.SetActive(false)
    laser21.SetActive(false)
    laser22.SetActive(false)
    laser23.SetActive(false)
end, false)



local API_ProgressBar = exports["clm_ProgressBar"]:GetAPI()
local missionTimerBar = nil

function StartMissionTimer()
    -- Temps total en secondes (4 minutes = 240s)
    local timeLeft = 30

    -- Initialisation de la barre de texte
    missionTimerBar = API_ProgressBar.add("TextTimerBar", "TEMPS RESTANT", "04:00")
    
    -- Personnalisation des couleurs (Blanc et Rouge)
    missionTimerBar.Func.setTitleColor({255, 255, 255, 255})
    missionTimerBar.Func.lib.TextTimerBar.setTextColor({255, 50, 50, 255})

    Citizen.CreateThread(function()
        while timeLeft > 0 do
            Citizen.Wait(1000) -- Attendre 1 seconde
            timeLeft = timeLeft - 1

            -- Calcul des minutes et secondes
            local minutes = math.floor(timeLeft / 60)
            local seconds = timeLeft % 60

            -- Formatage du texte (ex: 03:59)
            local timeText = string.format("%02d:%02d", minutes, seconds)
            
            -- Mise à jour de l'affichage
            missionTimerBar.Func.lib.TextTimerBar.setText(timeText)

            -- Alerte visuelle quand il reste moins de 30 secondes
            if timeLeft <= 30 then
                missionTimerBar.Func.setHighlightColor({255, 0, 0, 255})
            end
        end

        -- Une fois le temps écoulé
        ShowSubtitle("~r~Temps écoulé ! La police arrive !")
        ExecuteCommand('removeblc')
        Wait(500)
        ExecuteCommand('laseron')
        API_ProgressBar.remove(missionTimerBar._id)
    end)
end

RegisterNetEvent("grandtheftauto:alarme")
AddEventHandler("grandtheftauto:alarme", function()
    TriggerEvent('__chHyperSound:play', 0, "intrusion", false, 'alarm', 30)


    ExecuteCommand('laseroff')

    -- ALERTE POLICE SUR LES LIEUX
    local showroomCoords = vector3(-69.0, 64.0, 71.9)
    TriggerServerEvent('mission:server:alertPoliceLocation', showroomCoords)
end)

















