-- ─────────────────────────────────────────────
-- pop_territories - fonctions communes du serveur (chargé en premier, voir fxmanifest)
-- Parts de zone par crew, contrôle, synchro vers les clients.
-- La table Territories (getZoneAt, isDealZone, label) vient de shared/zones.lua.
-- ─────────────────────────────────────────────

Territories.shares   = {}   -- [zoneId] = { [crewId] = sharePct }
Territories.warState = {}   -- [zoneId] = { attacker = crewId, defender = crewId, startedAt = os.time() }
Territories.lastGain = {}   -- [src] = os.time() du dernier gain de part (cooldown)

local shares   = Territories.shares
local warState = Territories.warState

local ICON_INFO    = 'fas fa-circle-info'
local ICON_SUCCESS = 'fas fa-check'
local ICON_ERROR   = 'fas fa-triangle-exclamation'

Territories.ICON_INFO = ICON_INFO

function Territories.clampShare(v)
    if v < 0 then return 0.0 end
    if v > 100 then return 100.0 end
    return v
end

function Territories.getShare(zoneId, crewId)
    local z = shares[zoneId]
    return (z and z[crewId]) or 0.0
end

function Territories.setShare(zoneId, crewId, value)
    value = Territories.clampShare(value)
    shares[zoneId] = shares[zoneId] or {}
    shares[zoneId][crewId] = value
    MySQL.query('INSERT INTO territory_shares (zone_id, crew_id, share) VALUES (?, ?, ?) '
        .. 'ON DUPLICATE KEY UPDATE share = ?', { zoneId, crewId, value, value })
end

-- Crew en tête dans la zone (plus grosse part), quel que soit le seuil
function Territories.leaderOf(zoneId)
    local z = shares[zoneId]
    if not z then return nil, 0.0 end
    local topCrew, topShare = nil, 0.0
    for crewId, s in pairs(z) do
        if s > topShare then topCrew, topShare = crewId, s end
    end
    return topCrew, topShare
end

-- Crew qui CONTRÔLE la zone : le leader si sa part dépasse le seuil
function Territories.controllerOf(zoneId)
    local crewId, share = Territories.leaderOf(zoneId)
    if crewId and share >= Config.ControlThreshold then
        return crewId, share
    end
    return nil
end

--- Notification au style d'origine (pop_notify : titre + icône) pour un joueur.
function Territories.Notify(src, title, message, icon, duration)
    Bridge.Notify(src, { title = title, message = message, icon = icon, duration = duration })
end

function Territories.notifyCrew(crewId, title, message, ntype)
    local ok, sources = pcall(function() return exports.pop_crew:getOnlineMemberSources(crewId) end)
    if not ok or not sources then return end
    local icon = ICON_INFO
    if ntype == 'success' then icon = ICON_SUCCESS
    elseif ntype == 'error' then icon = ICON_ERROR end
    for _, src in ipairs(sources) do
        Territories.Notify(src, title, message, icon, Config.NotifyDuration)
    end
end

function Territories.zoneLabel(zoneId, zoneData)
    return (zoneData and zoneData.label) or zoneId
end

-- Zone d'un joueur à partir de la position de son ped (côté serveur)
function Territories.zoneOfPlayer(src)
    local coords = Bridge.GetCoords(src)
    if not coords then return nil end
    return Territories.getZoneAt(coords.x, coords.y)
end

-- ─────────────────────────────────────────────
-- Synchro vers les clients (survol carte + loadbar)
-- ─────────────────────────────────────────────

function Territories.controlPayload(zoneId)
    local crewId, share = Territories.leaderOf(zoneId)
    local crew = crewId and exports.pop_crew:getCrewById(crewId)
    return {
        crewId     = crewId,
        label      = crew and crew.label or nil,
        color      = crew and crew.color or nil,
        share      = share or 0.0,
        controlled = (crewId ~= nil and share >= Config.ControlThreshold),
        threshold  = Config.ControlThreshold,
        atWar      = warState[zoneId] ~= nil,
    }
end

-- Diffuse l'état de contrôle d'une zone à tous les clients (pour le survol carte)
function Territories.syncZoneControl(zoneId)
    TriggerClientEvent('pop_territories:control', -1, zoneId, Territories.controlPayload(zoneId))
end

-- Pousse la part du crew à ses membres en ligne (pour la loadbar)
function Territories.pushCrewProgress(crewId, zoneId, share)
    local crew = exports.pop_crew:getCrewById(crewId)
    local ok, sources = pcall(function() return exports.pop_crew:getOnlineMemberSources(crewId) end)
    if not ok or not sources then return end
    local data = {
        share      = share,
        threshold  = Config.ControlThreshold,
        color      = crew and crew.color or nil,
        controlled = share >= Config.ControlThreshold,
        inCrew     = true,
    }
    for _, src in ipairs(sources) do
        TriggerClientEvent('pop_territories:myProgress', src, zoneId, data)
    end
end
