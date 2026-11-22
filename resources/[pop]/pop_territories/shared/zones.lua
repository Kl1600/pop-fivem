-- ─────────────────────────────────────────────
-- pop_territories - zones (partagé client/serveur)
-- Zone d'un point : distance au centre ≤ rayon, la plus proche si chevauchement
-- ─────────────────────────────────────────────

Territories = {}

-- Retourne zoneId, zoneData (ou nil si hors territoire)
function Territories.getZoneAt(x, y)
    local bestId, bestZone, bestDist
    for id, z in pairs(Config.Zones) do
        local dx, dy = x - z.center.x, y - z.center.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d <= z.radius and (not bestDist or d < bestDist) then
            bestId, bestZone, bestDist = id, z, d
        end
    end
    return bestId, bestZone
end

function Territories.isDealZone(zoneData)
    return zoneData ~= nil and zoneData.dealZone ~= false
end

function Territories.label(zoneId)
    local z = zoneId and Config.Zones[zoneId]
    return (z and z.label) or zoneId
end
