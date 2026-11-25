-- pop_ems : blessures légères (saignement, boiterie). Statebag popEmsInjury lu par le serveur
-- pour le diagnostic et le blocage de la réanimation (n'ouvre aucun droit).
-- Aucun thread tant qu'il n'y a pas de blessure.

local injury = { bleeding = false, limp = false }

function Ems.GetInjuries()
    return { bleeding = injury.bleeding, limp = injury.limp }
end

if not Config.Injuries.enabled then
    function Ems.ClearInjuries() end
    function Ems.ClearBleeding() end
    return
end

local CFG = Config.Injuries

-- Mêmes bone ids que pop_medexam/config.lua (jambes gauche et droite).
local LEG_BONES = {
    [58271] = true, [63931] = true, [14201] = true, [2108] = true,
    [51826] = true, [36864] = true, [52301] = true, [20781] = true,
}

local lastHealth = nil
local threadRunning = false
local limpApplied = false

local function publish()
    LocalPlayer.state:set('popEmsInjury', { bleeding = injury.bleeding, limp = injury.limp }, true)
end

local function applyLimp(ped)
    RequestAnimSet(CFG.limpClipset)
    local timeout = GetGameTimer() + 2000
    while not HasAnimSetLoaded(CFG.limpClipset) and GetGameTimer() < timeout do Wait(50) end
    if HasAnimSetLoaded(CFG.limpClipset) then
        SetPedMovementClipset(ped, CFG.limpClipset, 0.2)
        limpApplied = true
    end
end

local function removeLimp()
    if not limpApplied then return end
    ResetPedMovementClipset(PlayerPedId(), 0.2)
    RemoveAnimSet(CFG.limpClipset)
    limpApplied = false
end

function Ems.ClearInjuries()
    if not injury.bleeding and not injury.limp then return end
    injury.bleeding, injury.limp = false, false
    removeLimp()
    publish()
end

function Ems.ClearBleeding()
    if not injury.bleeding then return end
    injury.bleeding = false
    publish()
end

local function startThread()
    if threadRunning then return end
    threadRunning = true
    CreateThread(function()
        while injury.bleeding or injury.limp do
            Wait(CFG.interval * 1000)
            local ped = PlayerPedId()
            local health, max = GetEntityHealth(ped), GetEntityMaxHealth(ped)
            if health >= max then
                Ems.ClearInjuries()
                break
            end
            if not IsEntityDead(ped) then
                if injury.bleeding then
                    health = math.max(health - CFG.bleedLoss, 101)
                    SetEntityHealth(ped, health)
                end
                -- Un autre script (réapparition, tenue...) peut avoir remis la démarche normale.
                if injury.limp then applyLimp(ped) end
            end
            lastHealth = health
        end
        threadRunning = false
    end)
end

local function addInjury(bleeding, limp)
    local changed = false
    if bleeding and not injury.bleeding then
        injury.bleeding, changed = true, true
        Bridge.Notify(L('injury_bleeding'), 'warning')
    end
    if limp and not injury.limp then
        injury.limp, changed = true, true
        Bridge.Notify(L('injury_limp'), 'warning')
        local ped = PlayerPedId()
        if not IsEntityDead(ped) then applyLimp(ped) end
    end
    if changed then
        publish()
        startThread()
    end
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local ped = PlayerPedId()
    if args[1] ~= ped then return end

    local health = GetEntityHealth(ped)
    local previous = lastHealth or GetEntityMaxHealth(ped)
    lastHealth = health
    local damage = previous - health
    if damage <= 0 then return end

    local bleeding = damage >= CFG.bleedDamage
    local hit, bone = GetPedLastDamageBone(ped)
    local limp = hit and LEG_BONES[bone] == true
    if bleeding or limp then addInjury(bleeding, limp) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removeLimp()
    if injury.bleeding or injury.limp then
        LocalPlayer.state:set('popEmsInjury', nil, true)
    end
end)
