-- ─────────────────────────────────────────────
-- pop_territories - chargement DB, évènements de crew, synchro client, commande
-- ─────────────────────────────────────────────

local shares   = Territories.shares
local warState = Territories.warState
local lastGain = Territories.lastGain

-- ─────────────────────────────────────────────
-- Chargement DB
-- ─────────────────────────────────────────────

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS territory_shares (
            zone_id    VARCHAR(32) NOT NULL,
            crew_id    INT NOT NULL,
            share      FLOAT DEFAULT 0,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (zone_id, crew_id)
        )
    ]])

    for _, row in ipairs(MySQL.query.await('SELECT zone_id, crew_id, share FROM territory_shares') or {}) do
        shares[row.zone_id] = shares[row.zone_id] or {}
        shares[row.zone_id][row.crew_id] = row.share
    end
end)

-- Nettoyage des parts quand un crew est dissous
AddEventHandler('pop_crew:disbanded', function(crewId)
    local touched = {}
    for zoneId, z in pairs(shares) do
        if z[crewId] then
            z[crewId] = nil
            touched[#touched + 1] = zoneId
            if warState[zoneId] and (warState[zoneId].attacker == crewId or warState[zoneId].defender == crewId) then
                warState[zoneId] = nil
            end
        end
    end
    MySQL.query('DELETE FROM territory_shares WHERE crew_id = ?', { crewId })
    for _, zoneId in ipairs(touched) do Territories.syncZoneControl(zoneId) end
end)

-- Quand un crew change de couleur, on resynchronise les zones qu'il domine
AddEventHandler('pop_crew:colorChanged', function(crewId)
    for zoneId, z in pairs(shares) do
        if z[crewId] then Territories.syncZoneControl(zoneId) end
    end
end)

-- ─────────────────────────────────────────────
-- Synchro à la demande du client (snapshot complet + sa progression)
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_territories:requestControl', function()
    local src = source
    local snap = {}
    for zoneId in pairs(shares) do snap[zoneId] = Territories.controlPayload(zoneId) end
    TriggerClientEvent('pop_territories:controlSnapshot', src, snap)
end)

Callback.Register('pop_territories:hasWeed', function(source)
    return Bridge.GetItemCount(source, Config.WeedItem) > 0
end)

AddEventHandler('playerDropped', function()
    lastGain[source] = nil
end)

Callback.Register('pop_territories:getMyShare', function(source, zoneId)
    if type(zoneId) ~= 'string' or not Config.Zones[zoneId] then
        return { share = 0.0, threshold = Config.ControlThreshold, inCrew = false }
    end
    local crew = exports.pop_crew:getCrew(source)
    if not crew then
        return { share = 0.0, threshold = Config.ControlThreshold, inCrew = false }
    end
    return {
        share      = Territories.getShare(zoneId, crew.id),
        threshold  = Config.ControlThreshold,
        color      = crew.color,
        controlled = Territories.getShare(zoneId, crew.id) >= Config.ControlThreshold,
        inCrew     = true,
    }
end)

-- ─────────────────────────────────────────────
-- Commande d'info : état du territoire où se trouve le joueur
-- ─────────────────────────────────────────────

RegisterCommand('territory', function(src)
    if src == 0 then return end
    local zoneId, zoneData = Territories.zoneOfPlayer(src)

    if not zoneId then
        return Territories.Notify(src, L('territory_title'), L('cmd_no_zone'),
            Territories.ICON_INFO, Config.NoZoneNotifyDuration)
    end

    local msg
    if not Territories.isDealZone(zoneData) then
        msg = L('cmd_normal_zone', Territories.zoneLabel(zoneId, zoneData))
    else
        local mult = tonumber(zoneData.multiplier) or Config.DefaultMultiplier
        local ctrl = Territories.controllerOf(zoneId)
        local ctrlCrew = ctrl and exports.pop_crew:getCrewById(ctrl)
        local status = warState[zoneId] and L('cmd_war_tag') or ''
        msg = L('cmd_deal_zone',
            Territories.zoneLabel(zoneId, zoneData), mult,
            ctrlCrew and ctrlCrew.label or L('cmd_no_controller'), status)
    end
    Territories.Notify(src, L('territory_title'), msg, Territories.ICON_INFO, Config.CommandNotifyDuration)
end, false)
