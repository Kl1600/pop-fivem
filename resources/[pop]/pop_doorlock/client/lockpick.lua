-- pop_doorlock : crochetage (demande au serveur, animation, mini-jeu NUI, résultat décidé par le serveur).
-- NOTE: le résultat du mini-jeu (success) est déclaré par le client. Le serveur ne peut pas le prouver :
-- il borne la durée de session, revérifie porte / distance / outil, et tire failChance même si le mini-jeu est réussi.
-- luacheck: globals Doorlock

local ANIM_DICT = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@'
local ANIM_CLIP = 'machinic_loop_mechandplayer'
local TURN_TIME = 800 -- ms : durée de la rotation vers la porte (non bloquante, le mini-jeu s'ouvre tout de suite)

local session = nil -- { doorId, groupId } pendant le mini-jeu

local RESULT_NOTIFY = {
    unlocked = { 'lockpick_success', 'success' },
    failed   = { 'lockpick_failed', 'error' },
    broken   = { 'lockpick_broken', 'error' },
}

local function stopAnim()
    local ped = PlayerPedId()
    StopAnimTask(ped, ANIM_DICT, ANIM_CLIP, 1.0)
    RemoveAnimDict(ANIM_DICT)
end

--- Termine le mini-jeu et demande le résultat au serveur.
local function finish(success, cancelled)
    local s = session
    if not s then return end
    session = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'pop_doorlock:lockpick', show = false })
    stopAnim()

    CreateThread(function()
        local result = Callback.Await('pop_doorlock:lockpickEnd', s.doorId, success == true, cancelled == true)
        Doorlock.lockpicking = false
        local n = RESULT_NOTIFY[result]
        if n then Bridge.Notify(L(n[1]), n[2]) end
        -- 'cancelled' ou nil (session invalide) : rien à afficher. Après un échec, l'accès du groupe reste false.
    end)
end

--- Lance une tentative de crochetage. À appeler dans un thread.
function Doorlock.StartLockpick(doorId)
    if Doorlock.lockpicking or Doorlock.editing or Bridge.IsBusy() then return end
    if not Doorlock.CanLockpickHere() then return end -- jamais en véhicule
    local door = Doorlock.doors[doorId]
    if not door then return end

    Doorlock.lockpicking = true
    Doorlock.HidePrompt()

    -- Le cache d'accès peut être périmé (clé reçue, job changé) : on revérifie avant de crocheter.
    local access = Callback.Await('pop_doorlock:getAccess', door.groupId)
    if access == true then
        Doorlock.SetAccess(door.groupId, true)
        Doorlock.lockpicking = false
        Doorlock.Toggle(doorId) -- accès : on ouvre directement
        return
    end

    local ok, params = Callback.Await('pop_doorlock:lockpickStart', doorId)
    if not ok then
        Doorlock.lockpicking = false
        if params == 'has_access' then
            -- Le serveur voit l'accès (course avec getAccess) : ouverture normale.
            Doorlock.SetAccess(door.groupId, true)
            Doorlock.Toggle(doorId)
            return
        end
        Doorlock.NotifyReason(params)
        return
    end
    if type(params) ~= 'table' then
        -- Réponse inattendue : on libère la session côté serveur.
        Callback.Await('pop_doorlock:lockpickEnd', doorId, false, true)
        Doorlock.lockpicking = false
        Doorlock.NotifyReason('error')
        return
    end

    session = { doorId = doorId, groupId = door.groupId }

    SetNuiFocus(true, false)
    SendNUIMessage({
        action = 'pop_doorlock:lockpick', show = true,
        hits = params.hits, zone = params.zone, speed = params.speed, time = params.time,
        key = Config.Keys.Interact.label,
    })

    -- Rotation vers la porte sans bloquer l'ouverture du mini-jeu ; l'anim démarre une fois tourné
    -- (TaskPlayAnim remplacerait la rotation). La marge serveur SESSION_EXTRA_MS couvre ce délai.
    local s = session
    local ped = PlayerPedId()
    local c = door.center
    TaskTurnPedToFaceCoord(ped, c.x, c.y, c.z, TURN_TIME)
    CreateThread(function()
        Wait(TURN_TIME)
        if session ~= s or not Doorlock.LoadAnim(ANIM_DICT) then return end
        if session ~= s then return end -- fin du mini-jeu pendant le chargement
        TaskPlayAnim(PlayerPedId(), ANIM_DICT, ANIM_CLIP, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end)
end

RegisterNUICallback('lockpickResult', function(data, cb)
    cb('ok')
    finish(type(data) == 'table' and data.success == true, false)
end)

-- Échap : le bridge a déjà rendu le focus ; on annule le crochetage en cours.
Bridge.OnUiClose(function()
    if session then finish(false, true) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if session then
        session = nil
        stopAnim()
        SetNuiFocus(false, false)
    end
end)
