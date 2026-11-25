-- Recrutement d'un joueur proche par le chef du crew.
-- ox_target ou qb-target s'ils sont lancés (option sur tous les joueurs), sinon touche E.
-- (Le bridge n'a pas encore de ciblage « tous les joueurs » : petit adaptateur local.)

local OPTION = 'pop_crew_recruit'

local function canRecruit()
    local s = CrewState()
    return s.inCrew == true and s.isOwner == true
end

local function invite(targetPed)
    local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(targetPed))
    if targetId and targetId > 0 then
        TriggerServerEvent('pop_crew:invite', targetId)
    else
        Bridge.Notify({
            title = L('crew_title'), message = L('player_unknown'), type = 'error', duration = Config.ClientNotifyDuration,
        })
    end
end

-- ---------- ox_target / qb-target ----------
local function addTarget()
    local sys = Bridge.TargetSystem
    if sys == 'ox_target' and GetResourceState('ox_target') == 'started' then
        pcall(function() exports.ox_target:removeGlobalPlayer(OPTION) end)
        exports.ox_target:addGlobalPlayer({ {
            name = OPTION, icon = 'fas fa-user-plus', label = L('target_recruit'),
            distance = Config.RecruitTargetDistance,
            canInteract = function() return canRecruit() end,
            onSelect = function(data) invite(data.entity) end,
        } })
    elseif sys == 'qb-target' and GetResourceState('qb-target') == 'started' then
        pcall(function() exports['qb-target']:RemoveGlobalPlayer(L('target_recruit')) end)
        exports['qb-target']:AddGlobalPlayer({
            options = { {
                icon = 'fas fa-user-plus', label = L('target_recruit'),
                canInteract = function() return canRecruit() end,
                action = function(entity) invite(entity) end,
            } },
            distance = Config.RecruitTargetDistance,
        })
    end
end

local function removeTarget()
    if GetResourceState('ox_target') == 'started' then
        pcall(function() exports.ox_target:removeGlobalPlayer(OPTION) end)
    end
    if GetResourceState('qb-target') == 'started' then
        pcall(function() exports['qb-target']:RemoveGlobalPlayer(L('target_recruit')) end)
    end
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() and resourceName ~= Bridge.TargetSystem then return end
    addTarget()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then removeTarget() end
end)

-- ---------- Touche E (aucun système de ciblage) ----------
-- Boucle seulement pour le chef d'un crew ; Wait long quand personne n'est proche.
local function closestPlayerPed(maxDist)
    local myPed = PlayerPedId()
    local myPos = GetEntityCoords(myPed)
    local best, bestDist = nil, maxDist
    for _, pid in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pid)
        if ped ~= myPed and DoesEntityExist(ped) then
            local d = #(GetEntityCoords(ped) - myPos)
            if d < bestDist then best, bestDist = ped, d end
        end
    end
    return best
end

CreateThread(function()
    if Bridge.TargetSystem ~= 'prompt' then return end
    local key = Config.Keys.Interact.control
    while true do
        local wait = 1500
        if canRecruit() then
            local ped = closestPlayerPed(Config.RecruitTargetDistance)
            if ped then
                wait = 0
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ ' .. L('target_recruit'))
                EndTextCommandDisplayHelp(0, false, false, -1)
                if IsControlJustReleased(0, key) then
                    invite(ped)
                    wait = 1000
                end
            else
                wait = 500
            end
        end
        Wait(wait)
    end
end)
