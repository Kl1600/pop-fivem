local ESX = exports['es_extended']:getSharedObject()
local INV = exports['pop_inventory']

local function notifyPlayer(source, title, message, icon)
    TriggerClientEvent('notification:client:ShowNotify', source, {
        title    = title,
        message  = message,
        icon     = icon or 'fas fa-building-columns',
        duration = 6000,
    })
end

-- Résout l'id du coffre pop_inventory (réutilise le mécanisme des coffres statiques,
-- cf. pop_inventory/server/sv_bank_vaults.lua) qui sert de compte bancaire.
local function personalChestId(identifier)
    return 'bank_personal_' .. identifier
end

local function companyChestId(jobName)
    return 'bank_company_' .. jobName
end

-- Anti-abus : les actions bancaires ne sont acceptées qu'à proximité d'une agence.
local function isNearBank(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    for i = 1, #Config.Locations do
        if #(coords - Config.Locations[i].coords) < 10.0 then return true end
    end
    return false
end

local function normalizeLabel(s)
    return tostring(s or ''):lower():match('^%s*(.-)%s*$')
end

-- Un chèque "à l'ordre" d'une entreprise (le bénéficiaire écrit correspond exactement au
-- label affiché dans SecuroServ, cf. pop_management) doit être crédité sur le coffre de
-- cette entreprise, jamais sur le compte perso de celui qui le dépose.
local function findJobByLabel(label)
    local target = normalizeLabel(label)
    if target == '' then return nil end

    for jobName, job in pairs(ESX.GetJobs()) do
        if normalizeLabel(job.label) == target then
            return jobName, job.label
        end
    end
    return nil
end

-- Ouvre la vue (NUI standby) d'un compte pour le joueur source. L'id du coffre n'est
-- jamais transmis par le client : il est recalculé ici à partir de son identifier/job,
-- pour qu'un client ne puisse jamais demander l'ouverture du coffre de quelqu'un d'autre.
RegisterNetEvent('pop_bank:server:openAccount', function(scope)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not isNearBank(src) then return end

    if scope == 'personal' then
        TriggerClientEvent('pop_bank:client:openAccount', src, personalChestId(xPlayer.identifier), 'Compte personnel', 50, 1000.0)
        return
    end

    if scope == 'company' then
        local job = xPlayer.getJob()
        if not job or job.grade_name ~= 'boss' then
            notifyPlayer(src, 'Banque', "Seul le patron de l'entreprise peut accéder à ce compte.", 'fas fa-triangle-exclamation')
            return
        end
        TriggerClientEvent('pop_bank:client:openAccount', src, companyChestId(job.name), "Compte entreprise : " .. (job.label or job.name), 50, 1000.0)
        return
    end
end)

ESX.RegisterServerCallback('pop_bank:getMyChecks', function(source, cb)
    local items = INV:GetPlayerItems(source, 'check')
    local results = {}

    if items then
        for _, item in ipairs(items) do
            local meta = item.meta or {}
            if meta.checkId then
                results[#results + 1] = {
                    checkId            = meta.checkId,
                    amount             = meta.montant,
                    beneficiaire       = meta.beneficiaire,
                    issuerCompanyLabel = meta.issuerCompanyLabel,
                }
            end
        end
    end

    cb(results)
end)

RegisterNetEvent('pop_bank:depositCheque')
AddEventHandler('pop_bank:depositCheque', function(checkId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(checkId) ~= 'string' and type(checkId) ~= 'number' then return end
    if not isNearBank(src) then return end

    MySQL.single('SELECT * FROM banking_checks WHERE unique_check_id = ?', { checkId }, function(row)
        if not row then
            notifyPlayer(src, 'Banque', 'Chèque introuvable.', 'fas fa-triangle-exclamation')
            return
        end

        if row.status ~= 'active' then
            notifyPlayer(src, 'Banque', 'Ce chèque a déjà été déposé.', 'fas fa-triangle-exclamation')
            return
        end

        -- Vérifie que le joueur porte bien l'item exact correspondant à ce chèque
        local items = INV:GetPlayerItems(src, 'check')
        local heldItem = nil
        if items then
            for _, item in ipairs(items) do
                if item.meta and item.meta.checkId == checkId then
                    heldItem = item
                    break
                end
            end
        end

        if not heldItem then
            notifyPlayer(src, 'Banque', "Vous n'avez pas ce chèque sur vous.", 'fas fa-triangle-exclamation')
            return
        end

        local amount = tonumber(row.amount)
        if not amount or amount <= 0 then
            notifyPlayer(src, 'Banque', 'Chèque invalide.', 'fas fa-triangle-exclamation')
            return
        end
        -- Émetteur : coffre entreprise si chèque d'entreprise, sinon compte ESX 'bank' de l'émetteur.
        local debitChestId = row.issuer_company and companyChestId(row.issuer_company) or nil

        -- Bénéficiaire : compte ESX 'bank' du joueur. Si le chèque est à l'ordre d'une
        -- entreprise existante, seul son patron peut l'encaisser, et les fonds vont au coffre entreprise.
        local creditChestId = nil
        local orderJobName, orderJobLabel = findJobByLabel(row.receiver_name)
        if orderJobName then
            local job = xPlayer.getJob()
            if job.name ~= orderJobName or job.grade_name ~= 'boss' then
                notifyPlayer(src, 'Banque', ("Seul le patron de %s peut déposer ce chèque."):format(orderJobLabel), 'fas fa-triangle-exclamation')
                return
            end
            creditChestId = companyChestId(orderJobName)
        end

        -- Vérification du solde de l'émetteur (avant de réserver le chèque)
        if debitChestId then
            local available = INV:GetStaticChestItemCount(debitChestId, 'cash')
            if not available or available < amount then
                notifyPlayer(src, 'Banque', "Fonds insuffisants chez l'émetteur du chèque.", 'fas fa-triangle-exclamation')
                return
            end
        else
            local issuer = ESX.GetPlayerFromIdentifier(row.issuer_identifier)
            if issuer and issuer.getAccount('bank').money < amount then
                notifyPlayer(src, 'Banque', "Fonds insuffisants chez l'émetteur du chèque.", 'fas fa-triangle-exclamation')
                return
            end
        end

        -- Claim atomique : si une autre requête a déjà déposé ce chèque entre temps,
        -- affected vaudra 0 et on s'arrête avant de toucher au moindre compte.
        MySQL.update(
            "UPDATE banking_checks SET status = 'deposited', deposited_at = NOW() WHERE unique_check_id = ? AND status = 'active'",
            { checkId },
            function(affected) CreateThread(function() -- thread : requêtes .await possibles
                if not affected or affected == 0 then
                    notifyPlayer(src, 'Banque', 'Ce chèque vient déjà d\'être traité.', 'fas fa-triangle-exclamation')
                    return
                end

                local function revertClaim()
                    MySQL.update("UPDATE banking_checks SET status = 'active', deposited_at = NULL WHERE unique_check_id = ?", { checkId })
                end

                -- 1) Débit de l'émetteur (solde revérifié au moment du débit)
                local removed = false
                local refundIssuer
                if debitChestId then
                    removed = INV:RemoveItemFromStaticChest(debitChestId, 'cash', amount)
                    refundIssuer = function() INV:AddItemToStaticChest(debitChestId, 'cash', amount) end
                else
                    local issuer = ESX.GetPlayerFromIdentifier(row.issuer_identifier)
                    if issuer then
                        if issuer.getAccount('bank').money >= amount then
                            issuer.removeAccountMoney('bank', amount, 'Chèque débité')
                            removed = true
                        end
                        refundIssuer = function()
                            local p = ESX.GetPlayerFromIdentifier(row.issuer_identifier)
                            if p then
                                p.addAccountMoney('bank', amount, 'Chèque annulé')
                            else
                                MySQL.update("UPDATE users SET accounts = JSON_SET(accounts, '$.bank', JSON_EXTRACT(accounts, '$.bank') + ?) WHERE identifier = ?", { amount, row.issuer_identifier })
                            end
                        end
                    else
                        -- Émetteur hors ligne : débit direct en base, seulement si le solde suffit
                        local changed = MySQL.update.await(
                            "UPDATE users SET accounts = JSON_SET(accounts, '$.bank', JSON_EXTRACT(accounts, '$.bank') - ?) WHERE identifier = ? AND JSON_EXTRACT(accounts, '$.bank') >= ?",
                            { amount, row.issuer_identifier, amount })
                        removed = (changed or 0) > 0
                        refundIssuer = function()
                            MySQL.update("UPDATE users SET accounts = JSON_SET(accounts, '$.bank', JSON_EXTRACT(accounts, '$.bank') + ?) WHERE identifier = ?", { amount, row.issuer_identifier })
                        end
                    end
                end

                if not removed then
                    notifyPlayer(src, 'Banque', "Fonds insuffisants chez l'émetteur du chèque.", 'fas fa-triangle-exclamation')
                    revertClaim()
                    return
                end

                -- 2) Crédit du bénéficiaire
                if creditChestId then
                    local credited = INV:AddItemToStaticChest(creditChestId, 'cash', amount)
                    if not credited then
                        refundIssuer() -- compensation : on rend les fonds débités
                        notifyPlayer(src, 'Banque', 'Le compte destinataire est plein, dépôt annulé.', 'fas fa-triangle-exclamation')
                        revertClaim()
                        return
                    end
                else
                    local receiver = ESX.GetPlayerFromId(src)
                    if not receiver then
                        refundIssuer()
                        revertClaim()
                        return
                    end
                    receiver.addAccountMoney('bank', amount, 'Chèque encaissé')
                end

                INV:removeItemById(src, heldItem.id)
                notifyPlayer(src, 'Banque', ('Chèque encaissé sur votre compte : %s$'):format(amount), 'fas fa-circle-check')
            end) end
        )
    end)
end)
