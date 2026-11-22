-- Objets côté serveur : TPE, menottes, escorte, AED, ciseaux, roues.

-- ESX / QBCore : globales de server/common.lua (ESX direct pour les comptes bancaires et sociétés).


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

RegisterNetEvent('pop_inventory:server:acceptTpeRequest', function(requesterId, amount) -- luacheck: ignore 312
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
                exports['qb-banking']:AddMoney(jobName, amountInt, L('tpe_payment_title'))
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
        Inv.NotifyTyped(src, {
            title = L('tpe_payment_title'),
            message = L('tpe_paid', amountInt),
            type = 'success',
            duration = 5000
        })
        Inv.NotifyTyped(requesterId, {
            title = L('tpe_payment_title'),
            message = L('tpe_client_paid', amountInt),
            type = 'success',
            duration = 5000
        })
    else
        Inv.NotifyTyped(src, {
            title = L('tpe_payment_title'),
            message = L('tpe_no_funds'),
            type = 'error',
            duration = 5000
        })
        Inv.NotifyTyped(requesterId, {
            title = L('tpe_payment_title'),
            message = L('tpe_client_no_funds'),
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
    Inv.NotifyTyped(src, {
        title = L('tpe_payment_title'),
        message = L('tpe_refused'),
        type = 'error',
        duration = 5000
    })
    if requesterId then
        Inv.NotifyTyped(requesterId, {
            title = L('tpe_payment_title'),
            message = L('tpe_client_refused'),
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
    Inv.NotifyTyped(targetId, {
        title = L('handcuffs_title'),
        message = shouldCuff and L('cuffed_you') or L('uncuffed_you'),
        type = 'info',
        duration = 5000
    })
    if byId then
        Inv.NotifyTyped(byId, {
            title = L('handcuffs_title'),
            message = shouldCuff and L('cuffed_target') or L('uncuffed_target'),
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
        shouldCuff = not (Player(targetId).state.handcuffed == true) -- luacheck: ignore 581
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

    Inv.NotifyTyped(src, {
        title = L('aed_title'),
        message = L('aed_revived_target'),
        type = 'success',
        duration = 5000
    })

    Inv.NotifyTyped(targetId, {
        title = L('aed_title'),
        message = L('aed_revived_you'),
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

    Inv.NotifyTyped(targetId, {
        title = L('scissors_title'),
        message = L('haircut_you'),
        type = 'warning',
        duration = 5000
    })

    Inv.NotifyTyped(src, {
        title = L('scissors_title'),
        message = L('haircut_target'),
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
