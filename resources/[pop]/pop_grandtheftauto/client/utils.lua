-- Outils communs du client : synchro coop, objets, chargements, invites « E », minuteur, mini-jeu.

-- ============================================================
-- SYNCHRO COOP (état partagé entre les fichiers client)
-- ============================================================
function EnsureMissionSync()
    _G.MissionSync = _G.MissionSync or {
        active = false,
        id = nil,
        owner = nil,
        isOwner = false,
        entities = {},
        flags = {}
    }
    return _G.MissionSync
end

function IsCoopActive()
    return EnsureMissionSync().active == true
end

function IsOwner()
    local MS = EnsureMissionSync()
    if not MS.active then return true end
    return MS.isOwner == true
end

-- Diffuse une action aux coéquipiers (le serveur filtre : équipe + liste blanche)
function Relay(action, data, includeSender)
    if EnsureMissionSync().active then
        TriggerServerEvent('mission:server:relay', action, data, includeSender == true)
    end
end

-- Vérifie côté serveur que le joueur possède un objet (flipper / pcb)
function CheckItem(item, cb)
    Callback.Trigger('hasItem', function(hasItem) cb(hasItem == true) end, item)
end

-- Notification de la mission (pop_notify via le bridge, même style qu'avant)
function MissionNotify(message, duration)
    Bridge.Notify({ message = message, icon = Config.NotifyIcon, duration = duration or 7000 })
end

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
    if Config.PromptUI == 'pop_v3dui' and GetResourceState('pop_v3dui') == 'started' then
        if not activePrompts[id] then
            activePrompts[id] = exports["pop_v3dui"]:Create({
                coords = coords,
                type = "prompt",
                content = { key = "E", label = text, icon = icon or "fas fa-hand-paper" },
                drawDistance = 10.0
            })
        end
    else
        -- Repli : aide native GTA (affichée à chaque image tant que l'invite est demandée)
        activePrompts[id] = true
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ ' .. text)
        EndTextCommandDisplayHelp(0, false, false, -1)
    end
end

function HidePrompt(id)
    if activePrompts[id] then
        if activePrompts[id] ~= true then
            pcall(function() exports["pop_v3dui"]:Remove(activePrompts[id]) end)
        end
        activePrompts[id] = nil
    end
end

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
        MissionNotify(L('voltlab_missing'), 5000)
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
        missionTimerBar = API_ProgressBar.add("TextTimerBar", L('timer_title'), string.format("%02d:%02d", math.floor(timeLeft / 60), timeLeft % 60))
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
        ShowSubtitle(L('time_up'))
        Blackout(false)
        Wait(500)
        TriggerEvent('mission:local:lasers', true)
        RemoveTimerBar()
    end)
end

-- Minuteur relayé aux coéquipiers (évènement local 'StartMissionTimer')
AddEventHandler('StartMissionTimer', function() StartMissionTimer() end)

RegisterNetEvent("grandtheftauto:alarme")
AddEventHandler("grandtheftauto:alarme", function()
    if not (_G.MissionSync and _G.MissionSync.active) then return end
    TriggerEvent('__chHyperSound:play', 0, "intrusion", false, Config.ShowroomPos, 30.0)
    TriggerEvent('mission:local:lasers', false)
    -- ALERTE POLICE SUR LES LIEUX (cooldown côté serveur)
    TriggerServerEvent('mission:server:alertPoliceLocation')
end)

-- Fin de mission / arrêt de la ressource : tout remettre comme avant
AddEventHandler('mission:local:reset', function()
    timerToken = timerToken + 1
    RemoveTimerBar()
    if blackoutOn then Blackout(false) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    RemoveTimerBar()
    if blackoutOn then Blackout(false) end
    for id in pairs(activePrompts) do HidePrompt(id) end
end)
