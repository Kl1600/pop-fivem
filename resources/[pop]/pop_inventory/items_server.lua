local ESX = nil
local QBCore = nil

if Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
elseif Config.Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
end


-- Vérifie que deux joueurs sont proches (anti-triche : cible arbitraire envoyée par le client).
-- Si la position serveur n'est pas fiable (ped non synchro), on ne bloque pas.
local function arePlayersClose(a, b, maxDist)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if not pa or not pb or pa == 0 or pb == 0 then return false end
    local ca, cb = GetEntityCoords(pa), GetEntityCoords(pb)
    if #(ca) < 1.0 or #(cb) < 1.0 then return true end
    return #(ca - cb) <= (maxDist or 5.0)
end

local function hasItem(src, defId)
    local count = exports.pop_inventory:getItemCount(src, defId)
    return count and count > 0
end

-- TPE Interaction
-- Demandes TPE en attente : [client] = { requester, amount, expires }.
-- L'acceptation n'est valide que si elle correspond à une demande réellement émise.
local pendingTpe = {}

AddEventHandler('playerDropped', function()
    pendingTpe[source] = nil
end)

RegisterNetEvent('pop_inventory:server:sendTpeRequest', function(targetId, amount)
    local src = source
    local targetIdInt = tonumber(targetId)
    local amountInt = tonumber(amount)
    if not targetIdInt or not amountInt then return end
    amountInt = math.floor(amountInt)
    if targetIdInt <= 0 or targetIdInt == src or amountInt <= 0 then return end
    if not GetPlayerName(targetIdInt) then return end

    -- Le demandeur doit posséder un TPE et être à proximité du client
    local count = exports.pop_inventory:getItemCount(src, 'tpe')
    if not count or count <= 0 then return end
    local p1, p2 = GetPlayerPed(src), GetPlayerPed(targetIdInt)
    if p1 ~= 0 and p2 ~= 0 and #(GetEntityCoords(p1) - GetEntityCoords(p2)) > 5.0 then return end

    pendingTpe[targetIdInt] = { requester = src, amount = amountInt, expires = os.time() + 60 }
    TriggerClientEvent('pop_inventory:client:receiveTpeRequest', targetIdInt, src, amountInt)
end)

RegisterNetEvent('pop_inventory:server:acceptTpeRequest', function(requesterId, amount)
    local src = source
    local pending = pendingTpe[src]
    pendingTpe[src] = nil
    requesterId = tonumber(requesterId)
    if not pending or pending.requester ~= requesterId or os.time() > pending.expires then return end
    amount = pending.amount -- le montant fait foi côté serveur, jamais celui renvoyé par le client
    local xTarget = nil
    local xRequester = nil
    if ESX then
        xTarget = ESX.GetPlayerFromId(src)
        xRequester = ESX.GetPlayerFromId(requesterId)
    elseif QBCore then
        xTarget = QBCore.Functions.GetPlayer(src)
        xRequester = QBCore.Functions.GetPlayer(requesterId)
    end
    
    local amountInt = tonumber(amount)

    if not xTarget or not xRequester or not amountInt or amountInt <= 0 then return end

    local targetBank = 0
    if ESX then
        targetBank = xTarget.getAccount('bank').money
    elseif QBCore then
        targetBank = xTarget.PlayerData.money['bank']
    end
    
    if targetBank >= amountInt then
        if ESX then
            xTarget.removeAccountMoney('bank', amountInt)
            local societyName = xRequester.job.name
            local society = nil
            pcall(function()
                society = exports['esx_society']:GetSociety(societyName)
            end)
            
            local accountName = society and society.account or ('society_' .. societyName)
            TriggerEvent('esx_addonaccount:getSharedAccount', accountName, function(account)
                if account then
                    account.addMoney(amountInt)
                else
                    xRequester.addAccountMoney('bank', amountInt)
                end
            end)
        elseif QBCore then
            xTarget.Functions.RemoveMoney('bank', amountInt)
            local jobName = xRequester.PlayerData.job.name
            local success = false
            pcall(function()
                exports['qb-banking']:AddMoney(jobName, amountInt, 'Paiement TPE')
                success = true
            end)
            if not success then
                pcall(function()
                    exports['qb-management']:AddMoney(jobName, amountInt)
                    success = true
                end)
            end
            if not success then
                xRequester.Functions.AddMoney('bank', amountInt)
            end
        end
        
        -- Notifications Custom "notification"
        TriggerClientEvent('notification:client:send', src, {
            title = 'Paiement TPE',
            message = ('Vous avez payé %s$ par carte.'):format(amountInt),
            type = 'success',
            duration = 5000
        })
        TriggerClientEvent('notification:client:send', requesterId, {
            title = 'Paiement TPE',
            message = ('Le client a payé %s$ par carte.'):format(amountInt),
            type = 'success',
            duration = 5000
        })
    else
        TriggerClientEvent('notification:client:send', src, {
            title = 'Paiement TPE',
            message = 'Fonds insuffisants sur le compte bancaire.',
            type = 'error',
            duration = 5000
        })
        TriggerClientEvent('notification:client:send', requesterId, {
            title = 'Paiement TPE',
            message = 'Le client n\'a pas les fonds nécessaires.',
            type = 'error',
            duration = 5000
        })
    end
end)

RegisterNetEvent('pop_inventory:server:declineTpeRequest', function(requesterId)
    local src = source
    local pending = pendingTpe[src]
    requesterId = tonumber(requesterId)
    if not pending or pending.requester ~= requesterId then return end
    pendingTpe[src] = nil
    TriggerClientEvent('notification:client:send', src, {
        title = 'Paiement TPE',
        message = 'Vous avez refusé le paiement.',
        type = 'error',
        duration = 5000
    })
    if requesterId then
        TriggerClientEvent('notification:client:send', requesterId, {
            title = 'Paiement TPE',
            message = 'Le client a refusé le paiement.',
            type = 'error',
            duration = 5000
        })
    end
end)

-- =====================================================
-- MENOTTES (logique serveur autoritaire + statebag réseau)
-- =====================================================

local function getPlayer(id)
    if ESX then return ESX.GetPlayerFromId(id) end
    if QBCore then return QBCore.Functions.GetPlayer(id) end
    return nil
end

-- Applique/retire les menottes de façon autoritaire.
-- targetId : cible / state : true=menotter, false=démenotter / byId : auteur (peut être nil)
-- Les visuels (anim + prop + son) sont délégués à SmartCuffs (Client:CuffLocal).
-- Notre statebag 'handcuffed' reste la source de vérité pour ox_target/escorte.
local function applyHandcuffs(targetId, state, byId)
    targetId = tonumber(targetId)
    if not targetId then return false end
    if not getPlayer(targetId) then return false end

    local shouldCuff = state and true or false
    local currentlyCuffed = Player(targetId).state.handcuffed == true
    -- No-op si déjà dans l'état demandé : évite la dérive avec l'état interne SmartCuffs.
    if shouldCuff == currentlyCuffed then return true end

    -- Statebag réseau (lisible par tous les clients, ex: ox_target canInteract)
    Player(targetId).state:set('handcuffed', shouldCuff, true)
    if not shouldCuff then
        Player(targetId).state:set('escortedBy', nil, true)
    end

    -- Anim + prop streamé (modèle p_cs_cuffs_02_s fourni par SmartCuffs).
    TriggerClientEvent('pop_inventory:client:setHandcuffed', targetId, shouldCuff)

    -- Notifications
    TriggerClientEvent('notification:client:send', targetId, {
        title = 'Menottes',
        message = shouldCuff and 'On vous a placé les menottes.' or 'On vous a retiré les menottes.',
        type = 'info',
        duration = 5000
    })
    if byId then
        TriggerClientEvent('notification:client:send', byId, {
            title = 'Menottes',
            message = shouldCuff and 'Vous avez menotté l\'individu.' or 'Vous avez démenotté l\'individu.',
            type = 'success',
            duration = 5000
        })
    end
    return true
end

-- Export réutilisable par les autres ressources (ex: tab_interactions)
exports('SetPlayerHandcuffed', function(targetId, state, byId)
    return applyHandcuffs(targetId, state, byId)
end)


-- Escorter : un joueur menotté est attaché à l'escorteur.
-- Statebags : Player(target).state.escortedBy = serverId de l'escorteur, et
-- Player(escorter).state.escorting = serverId de la cible (pour lookup côté client).
local function stopEscortFor(escorterSrc)
    -- Cherche la cible que cet escorteur escorte et la libère.
    for _, pid in ipairs(GetPlayers()) do
        local id = tonumber(pid)
        if id and Player(id) and Player(id).state.escortedBy == escorterSrc then
            Player(id).state:set('escortedBy', nil, true)
        end
    end
    if Player(escorterSrc) then
        Player(escorterSrc).state:set('escorting', nil, true)
    end
end

RegisterNetEvent('pop_inventory:server:toggleEscort', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or targetId == src then return end
    if not getPlayer(targetId) then return end
    if Player(targetId).state.handcuffed ~= true then return end

    local current = Player(targetId).state.escortedBy
    if current and current == src then
        Player(targetId).state:set('escortedBy', nil, true)
        Player(src).state:set('escorting', nil, true)
    else
        -- Libère toute escorte précédente de cet escorteur avant d'en démarrer une nouvelle.
        stopEscortFor(src)
        Player(targetId).state:set('escortedBy', src, true)
        Player(src).state:set('escorting', targetId, true)
    end
end)

-- L'escorteur signale qu'il doit arrêter (ragdoll/sprint/véhicule).
RegisterNetEvent('pop_inventory:server:stopEscort', function()
    stopEscortFor(source)
end)

AddEventHandler('playerDropped', function()
    stopEscortFor(source)
end)

-- Path "utilisation de l'item menottes" sur le joueur le plus proche
RegisterNetEvent('pop_inventory:server:menottesPlayer', function(targetId, state)
    local src = source
    targetId = tonumber(targetId)
    if not targetId then return end

    if targetId == src or not GetPlayerName(targetId) then return end
    if not arePlayersClose(src, targetId, 5.0) then return end

    local shouldCuff
    if state == nil then
        -- Rétro-compat : bascule selon l'état courant
        shouldCuff = not (Player(targetId).state.handcuffed == true)
    else
        shouldCuff = state and true or false
    end

    if shouldCuff then
        -- Pour menotter, l'auteur doit réellement posséder des menottes
        local count = exports.pop_inventory:getItemCount(src, 'menottes')
        if not count or count <= 0 then return end
    else
        -- Pour démenotter, la cible doit déjà être menottée
        if Player(targetId).state.handcuffed ~= true then return end
    end

    applyHandcuffs(targetId, shouldCuff, src)
end)

-- Défibrillateur
RegisterNetEvent('pop_inventory:server:useAED', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or not hasItem(src, 'aed') or not arePlayersClose(src, targetId, 5.0) then return end
    local xTarget = nil
    if ESX then
        xTarget = ESX.GetPlayerFromId(targetId)
    elseif QBCore then
        xTarget = QBCore.Functions.GetPlayer(targetId)
    end
    if not xTarget then return end
    
    TriggerClientEvent('pop_inventory:client:revivePlayer', targetId)
    
    TriggerClientEvent('notification:client:send', src, {
        title = 'AED',
        message = 'Vous avez réanimé la personne.',
        type = 'success',
        duration = 5000
    })
    
    TriggerClientEvent('notification:client:send', targetId, {
        title = 'AED',
        message = 'Vous avez été réanimé par le défibrillateur.',
        type = 'success',
        duration = 5000
    })
end)

-- Ciseaux
RegisterNetEvent('pop_inventory:server:cutHair', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId or not hasItem(src, 'ciseaux') or not arePlayersClose(src, targetId, 5.0) then return end
    local xTarget = nil
    if ESX then
        xTarget = ESX.GetPlayerFromId(targetId)
    elseif QBCore then
        xTarget = QBCore.Functions.GetPlayer(targetId)
    end
    if not xTarget then return end
    
    TriggerClientEvent('pop_inventory:client:forceBald', targetId)
    
    TriggerClientEvent('notification:client:send', targetId, {
        title = 'Ciseaux',
        message = 'On vient de vous couper les cheveux !',
        type = 'warning',
        duration = 5000
    })
    
    TriggerClientEvent('notification:client:send', src, {
        title = 'Ciseaux',
        message = 'Vous avez coupé les cheveux de la personne.',
        type = 'success',
        duration = 5000
    })
end)

-- Démontage d'une roue : le client donne TOUJOURS un pneu usé (isBurst = true).
-- Sécurité : jamais de pneu neuf depuis le client, véhicule requis à proximité, anti-spam.
local lastWheelGive = {}
AddEventHandler('playerDropped', function() lastWheelGive[source] = nil end)

RegisterNetEvent('pop_inventory:server:giveWheel', function(_)
    local src = source
    local now = os.time()
    if lastWheelGive[src] and now - lastWheelGive[src] < 5 then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local pc = GetEntityCoords(ped)
    local near = false
    for _, veh in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(veh) - pc) <= 6.0 then near = true; break end
    end
    if not near then return end
    lastWheelGive[src] = now
    exports.pop_inventory:addItem(src, 'tyre_burst', 1)
end)

RegisterNetEvent('pop_inventory:server:removeWheel', function()
    local src = source
    exports.pop_inventory:removeItem(src, 'tyre', 1)
end)

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
        notify(src, 'Erreur de pose: ' .. (err or 'inconnu'))
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
        notify(src, err or 'Pas assez de place dans votre inventaire.')
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
    
    notify(src, 'Brancard ramassé.')
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
        local ok, err = unequipItem(store, 'briefcase')
        if not ok then
            notify(src, "Vos mains sont encombrées et vous n'avez pas de place dans l'inventaire.")
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
        notify(src, "Erreur lors de la création de l'objet.")
        return
    end
    
    local ok, err = equipItem(store, itemId)
    if not ok then
        -- Cleanup created item if it failed
        store.items[itemId] = nil
        notify(src, err or "Impossible d'équiper le brancard.")
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
    notify(src, 'Vous poussez le brancard.')
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
            notify(src, 'Erreur de pose: ' .. (err or 'inconnu'))
        end
    end
end)

RegisterNetEvent('pop_inventory:server:setStretcherPlayer', function(stretcherNetId, hasPlayer)
    local ent = NetworkGetEntityFromNetworkId(stretcherNetId)
    if DoesEntityExist(ent) then
        Entity(ent).state:set('hasPlayer', hasPlayer, true)
    end
end)

RegisterNetEvent('pop_inventory:server:placePlayerOnStretcher', function(targetServerId, stretcherNetId)
    local targetServerIdInt = tonumber(targetServerId)
    if not targetServerIdInt or targetServerIdInt <= 0 then return end
    
    TriggerClientEvent('pop_inventory:client:forcedOnStretcher', targetServerIdInt, stretcherNetId)
    
    local ent = NetworkGetEntityFromNetworkId(stretcherNetId)
    if DoesEntityExist(ent) then
        Entity(ent).state:set('hasPlayer', true, true)
        Entity(ent).state:set('attachedPlayerId', targetServerIdInt, true)
    end
end)

RegisterNetEvent('pop_inventory:server:detachPlayerFromStretcher', function(stretcherNetId)
    local ent = NetworkGetEntityFromNetworkId(stretcherNetId)
    if DoesEntityExist(ent) then
        local targetServerId = Entity(ent).state.attachedPlayerId
        if targetServerId then
            TriggerClientEvent('pop_inventory:client:forcedOffStretcher', targetServerId)
        end
        Entity(ent).state:set('hasPlayer', false, true)
        Entity(ent).state:set('attachedPlayerId', nil, true)
    end
end)
