-- ─────────────────────────────────────────────
-- pop_territories - guerre des gangs
-- ─────────────────────────────────────────────

local shares   = Territories.shares
local warState = Territories.warState

function Territories.startWar(zoneId, attacker, defender, zoneData)
    warState[zoneId] = { attacker = attacker, defender = defender, startedAt = os.time() }
    local label = Territories.zoneLabel(zoneId, zoneData)
    local atk = exports.pop_crew:getCrewById(attacker)
    local def = exports.pop_crew:getCrewById(defender)

    Territories.notifyCrew(defender, L('war_title'),
        L('war_defender', atk and atk.label or L('unknown_crew'), label), 'error')
    Territories.notifyCrew(attacker, L('war_title'),
        L('war_attacker', label, def and def.label or L('unknown_crew')), 'inform')

    Territories.syncZoneControl(zoneId)

    -- Hook pour la phase combat / capture (à brancher : dispatch, blip, timer…)
    TriggerEvent('pop_territories:warStarted', zoneId, attacker, defender)
    if Config.Debug then
        print(('[pop_territories] GUERRE %s : crew %s attaque crew %s'):format(zoneId, attacker, defender))
    end
end

-- Termine une guerre (ex: appelé par la logique de capture en phase 2)
exports('endWar', function(zoneId, winnerCrewId)
    if not warState[zoneId] then return false end
    warState[zoneId] = nil
    if winnerCrewId then
        -- le vainqueur prend le contrôle total, les autres sont remis à zéro
        shares[zoneId] = {}
        Territories.setShare(zoneId, winnerCrewId, 100.0)
    end
    Territories.syncZoneControl(zoneId)
    TriggerEvent('pop_territories:warEnded', zoneId, winnerCrewId)
    return true
end)

exports('isAtWar', function(zoneId) return warState[zoneId] ~= nil end)
exports('getShares', function(zoneId) return shares[zoneId] or {} end)
exports('getController', function(zoneId)
    local crewId = Territories.controllerOf(zoneId)
    return crewId
end)
