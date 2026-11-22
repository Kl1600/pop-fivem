-- Brancard côté serveur.

-- =============================================================
-- SERVEUR : GESTION DES BRANCARDS (EMS STRETCHERS)
-- =============================================================

RegisterNetEvent('pop_inventory:server:removeBrancard', function()
    local src = source
    exports.pop_inventory:removeItem(src, 'brancard', 1)
end)

RegisterNetEvent('pop_inventory:server:dropBrancard', function()
    local src = source
    local identifier = getIdentifier(src)
    if not identifier then return end
    local store = ensureStore(identifier)

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading)
    local forwardX = -math.sin(rad)
    local forwardY = math.cos(rad)
    local dropCoords = vector3(coords.x + forwardX * 1.5, coords.y + forwardY * 1.5, coords.z)

    local ok, err = dropToGround(src, store, { type = 'equipment', slot = 'briefcase' }, 1, dropCoords)
    if not ok then
        notify(src, L('drop_error', err or L('unknown_lower')))
        TriggerClientEvent('pop_inventory:client:applyEquipment', src, buildEquipmentDefs(store))
    else
        TriggerClientEvent('pop_inventory:client:applyEquipment', src, buildEquipmentDefs(store))
        sendState(src, { x = coords.x, y = coords.y, z = coords.z })
    end
end)

RegisterNetEvent('pop_inventory:server:pickupStretcherProp', function(propCoords)
    local src = source
    local identifier = getIdentifier(src)
    if not identifier then return end

    local store = ensureStore(identifier)

    -- Chercher une pile au sol avec un brancard
    local pile = getNearbyGroundPile(src, propCoords, 3.0)
    local groundContainer = pile and GroundStore.containers[pile.containerId]
    local targetSlot = nil
    local targetItemId = nil

    if groundContainer then
        for slot, itemId in pairs(groundContainer.items) do
            local item = GroundStore.items[itemId]
            if item and item.defId == 'brancard' then
                targetSlot = slot
                targetItemId = itemId
                break
            end
        end
    end

    -- Anti-duplication : pas de brancard au sol à cet endroit -> rien à ramasser
    if not targetItemId then return end

    local ok, err = autoInsertItem(store, 'brancard', 1, {})
    if not ok then
        notify(src, err or L('not_enough_space'))
        return
    end

    if targetItemId then
        groundContainer.items[targetSlot] = nil
        groundContainer.items[tostring(targetSlot)] = nil
        GroundStore.items[targetItemId] = nil
        GroundStore.itemLocations[targetItemId] = nil

        pruneEmptyGroundPiles()
        markGroundDirty()
    end

    syncGroundDropEntities()

    notify(src, L('stretcher_picked'))
    local ped = GetPlayerPed(src)
    local pedCoords = GetEntityCoords(ped)
    sendState(src, { x = pedCoords.x, y = pedCoords.y, z = pedCoords.z })
end)

RegisterNetEvent('pop_inventory:server:pushStretcherProp', function(propCoords)
    local src = source
    local identifier = getIdentifier(src)
    if not identifier then return end

    local store = ensureStore(identifier)

    -- Check if briefcase slot is occupied.
    if store.equipment['briefcase'] then
        -- Unequip the current briefcase item first.
        local ok, err = unequipItem(store, 'briefcase') -- luacheck: ignore 211
        if not ok then
            notify(src, L('hands_full_no_space'))
            return
        end
    end

    -- Chercher la pile au sol avec un brancard pour la consommer/supprimer
    local pile = getNearbyGroundPile(src, propCoords, 3.0)
    local groundContainer = pile and GroundStore.containers[pile.containerId]
    local targetSlot = nil
    local targetItemId = nil

    if groundContainer then
        for slot, itemId in pairs(groundContainer.items) do
            local item = GroundStore.items[itemId]
            if item and item.defId == 'brancard' then
                targetSlot = slot
                targetItemId = itemId
                break
            end
        end
    end

    -- Anti-duplication : il faut un brancard réellement posé au sol à cet endroit
    if not targetItemId then return end

    -- Créer le brancard dans le store du joueur et l'équiper
    local itemId = createItem(store, 'brancard', 1, {})
    if not itemId then
        notify(src, L('item_create_error'))
        return
    end

    local ok, err = equipItem(store, itemId)
    if not ok then
        -- Cleanup created item if it failed
        store.items[itemId] = nil
        notify(src, err or L('stretcher_equip_error'))
        return
    end

    -- Supprimer le brancard du sol
    if targetItemId then
        groundContainer.items[targetSlot] = nil
        groundContainer.items[tostring(targetSlot)] = nil
        GroundStore.items[targetItemId] = nil
        GroundStore.itemLocations[targetItemId] = nil

        pruneEmptyGroundPiles()
        markGroundDirty()
    end

    syncGroundDropEntities()

    TriggerClientEvent('pop_inventory:client:applyEquipment', src, buildEquipmentDefs(store))
    notify(src, L('stretcher_pushing'))
    local ped = GetPlayerPed(src)
    local pedCoords = GetEntityCoords(ped)
    sendState(src, { x = pedCoords.x, y = pedCoords.y, z = pedCoords.z })
end)


RegisterNetEvent('pop_inventory:server:useBrancard', function()
    local src = source
    local identifier = getIdentifier(src)
    if not identifier then return end
    local store = ensureStore(identifier)

    local itemId = nil
    for id, item in pairs(store.items) do
        if item.defId == 'brancard' then
            itemId = id
            break
        end
    end

    if not itemId then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading)
    local forwardX = -math.sin(rad)
    local forwardY = math.cos(rad)
    local dropCoords = vector3(coords.x + forwardX * 1.5, coords.y + forwardY * 1.5, coords.z)

    local origin = nil
    local found = false
    for slot, eqId in pairs(store.equipment) do
        if eqId == itemId then
            origin = { type = 'equipment', slot = slot }
            found = true
            break
        end
    end

    if not found then
        for containerId, container in pairs(store.containers) do
            for slot, cItemId in pairs(container.items) do
                if cItemId == itemId then
                    origin = { type = 'container', containerId = containerId, slot = slot }
                    found = true
                    break
                end
            end
            if found then break end
        end
    end

    if origin then
        local ok, err = dropToGround(src, store, origin, 1, dropCoords)
        if not ok then
            notify(src, L('drop_error', err or L('unknown_lower')))
        end
    end
end)

-- Anti-triche brancard : renvoie l'entité du brancard si elle existe et si le joueur
-- est à côté (distance serveur), sinon nil.
local function getNearbyStretcher(src, stretcherNetId, maxDist)
    stretcherNetId = tonumber(stretcherNetId)
    if not stretcherNetId then return nil end
    local ent = NetworkGetEntityFromNetworkId(stretcherNetId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    if #(GetEntityCoords(ped) - GetEntityCoords(ent)) > (maxDist or 5.0) then return nil end
    return ent
end

-- Cible incapable de résister : morte / inconsciente ou menottée.
-- NOTE: esx_ambulancejob est absent ; aucun état "mort" serveur fiable n'est connu dans
-- pop_inventory. On lit les state bags usuels s'ils existent, sinon la santé serveur
-- (GetEntityHealth <= 101 = mort ou à terre). 'handcuffed' est posé par ce fichier.
local function isTargetHelpless(targetId)
    local st = Player(targetId).state
    if st.handcuffed == true or st.isDead == true or st.dead == true or st.unconscious == true then
        return true
    end
    local ped = GetPlayerPed(targetId)
    return ped ~= 0 and GetEntityHealth(ped) <= 101
end

RegisterNetEvent('pop_inventory:server:setStretcherPlayer', function(stretcherNetId, hasPlayer)
    local ent = getNearbyStretcher(source, stretcherNetId, 5.0)
    if ent then
        Entity(ent).state:set('hasPlayer', hasPlayer == true, true)
    end
end)

RegisterNetEvent('pop_inventory:server:placePlayerOnStretcher', function(targetServerId, stretcherNetId)
    local src = source
    local targetServerIdInt = tonumber(targetServerId)
    if not targetServerIdInt or targetServerIdInt <= 0 then return end
    -- La cible doit exister, être à moins de 3 m et ne pas pouvoir résister.
    -- NOTE: se placer soi-même reste permis (aucun risque pour autrui).
    if not GetPlayerName(targetServerIdInt) then return end
    if targetServerIdInt ~= src then
        local sp, tp = GetPlayerPed(src), GetPlayerPed(targetServerIdInt)
        if sp == 0 or tp == 0 or #(GetEntityCoords(sp) - GetEntityCoords(tp)) > 3.0 then return end
        if not isTargetHelpless(targetServerIdInt) then return end
    end
    local ent = getNearbyStretcher(src, stretcherNetId, 5.0)
    if not ent then return end

    TriggerClientEvent('pop_inventory:client:forcedOnStretcher', targetServerIdInt, stretcherNetId)

    Entity(ent).state:set('hasPlayer', true, true)
    Entity(ent).state:set('attachedPlayerId', targetServerIdInt, true)
end)

RegisterNetEvent('pop_inventory:server:detachPlayerFromStretcher', function(stretcherNetId)
    local src = source
    local ent = NetworkGetEntityFromNetworkId(tonumber(stretcherNetId) or 0)
    -- Seul un joueur proche du brancard (ou la personne attachée) peut détacher
    if ent and ent ~= 0 and DoesEntityExist(ent)
        and (Entity(ent).state.attachedPlayerId == src or getNearbyStretcher(src, stretcherNetId, 5.0)) then
        local targetServerId = Entity(ent).state.attachedPlayerId
        if targetServerId then
            TriggerClientEvent('pop_inventory:client:forcedOffStretcher', targetServerId)
        end
        Entity(ent).state:set('hasPlayer', false, true)
        Entity(ent).state:set('attachedPlayerId', nil, true)
    end
end)
