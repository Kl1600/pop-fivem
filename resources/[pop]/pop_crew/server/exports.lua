-- Exports utilisés par pop_territories (et autres scripts). Noms et retours inchangés.

-- Crew d'un joueur (par source). Retourne nil si sans crew.
exports('getCrew', function(src)
    local id = Crew.IdentifierOf(src)
    if not id then return nil end
    local cid = Crew.memberOf[id]
    local c = cid and Crew.crewsById[cid]
    if not c then return nil end
    return { id = c.id, name = c.name, label = c.label, color = c.color }
end)

exports('getCrewById', function(crewId)
    local c = Crew.crewsById[crewId]
    if not c then return nil end
    return { id = c.id, name = c.name, label = c.label, color = c.color }
end)

exports('getCrewIdByIdentifier', function(identifier)
    return Crew.memberOf[identifier]
end)

-- Sources des membres du crew actuellement connectés (pour notifications)
exports('getOnlineMemberSources', function(crewId)
    return Crew.GetOnlineMemberSources(crewId)
end)
