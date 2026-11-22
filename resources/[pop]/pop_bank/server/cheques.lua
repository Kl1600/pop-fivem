-- Dépôt de chèques.
-- Émetteur débité : coffre entreprise (chèque d'entreprise) ou compte ESX 'bank' de l'émetteur.
-- Bénéficiaire crédité : compte ESX 'bank' du joueur, ou coffre de l'entreprise si le chèque
-- est à l'ordre d'une entreprise (seul son patron peut alors l'encaisser).

local ESX, INV = Bank.ESX, Bank.INV

local SQL_BANK_ADD = "UPDATE users SET accounts = JSON_SET(accounts, '$.bank', JSON_EXTRACT(accounts, '$.bank') + ?) WHERE identifier = ?"
local SQL_BANK_REMOVE = "UPDATE users SET accounts = JSON_SET(accounts, '$.bank', JSON_EXTRACT(accounts, '$.bank') - ?) WHERE identifier = ? AND JSON_EXTRACT(accounts, '$.bank') >= ?"

local function findHeldCheck(src, checkId)
    for _, item in ipairs(Bank.GetHeldChecks(src)) do
        if item.meta.checkId == checkId then return item end
    end
    return nil
end

-- Vérification du solde de l'émetteur avant de réserver le chèque.
local function issuerHasFunds(row, debitChestId, amount)
    if debitChestId then
        local available = INV:GetStaticChestItemCount(debitChestId, 'cash')
        return available ~= nil and available >= amount
    end
    local issuer = ESX.GetPlayerFromIdentifier(row.issuer_identifier)
    return not issuer or issuer.getAccount('bank').money >= amount
end

-- Débite l'émetteur (solde revérifié). Renvoie removed, refund().
local function debitIssuer(row, debitChestId, amount)
    if debitChestId then
        local removed = INV:RemoveItemFromStaticChest(debitChestId, 'cash', amount)
        return removed, function() INV:AddItemToStaticChest(debitChestId, 'cash', amount) end
    end

    local issuer = ESX.GetPlayerFromIdentifier(row.issuer_identifier)
    if issuer then
        local removed = false
        if issuer.getAccount('bank').money >= amount then
            issuer.removeAccountMoney('bank', amount, 'Chèque débité')
            removed = true
        end
        return removed, function()
            local p = ESX.GetPlayerFromIdentifier(row.issuer_identifier)
            if p then
                p.addAccountMoney('bank', amount, 'Chèque annulé')
            else
                MySQL.update(SQL_BANK_ADD, { amount, row.issuer_identifier })
            end
        end
    end

    -- Émetteur hors ligne : débit direct en base, seulement si le solde suffit.
    local changed = MySQL.update.await(SQL_BANK_REMOVE, { amount, row.issuer_identifier, amount })
    return (changed or 0) > 0, function()
        MySQL.update(SQL_BANK_ADD, { amount, row.issuer_identifier })
    end
end

-- Crédite le bénéficiaire. Renvoie true si crédité.
local function creditReceiver(src, creditChestId, amount)
    if creditChestId then
        return INV:AddItemToStaticChest(creditChestId, 'cash', amount) == true, 'receiver_full'
    end
    local receiver = ESX.GetPlayerFromId(src)
    if not receiver then return false end
    receiver.addAccountMoney('bank', amount, 'Chèque encaissé')
    return true
end

-- Après réservation du chèque en base : débit, crédit, retrait de l'objet. Annule tout en cas d'échec.
local function settle(src, checkId, row, heldItem, amount, debitChestId, creditChestId)
    local function revertClaim()
        MySQL.update("UPDATE banking_checks SET status = 'active', deposited_at = NULL WHERE unique_check_id = ?", { checkId })
    end

    local removed, refundIssuer = debitIssuer(row, debitChestId, amount)
    if not removed then
        Bank.Notify(src, L('issuer_no_funds'), Bank.ICON_WARN)
        revertClaim()
        return
    end

    local credited, reason = creditReceiver(src, creditChestId, amount)
    if not credited then
        refundIssuer()
        if reason then Bank.Notify(src, L(reason), Bank.ICON_WARN) end
        revertClaim()
        return
    end

    INV:removeItemById(src, heldItem.id)
    Bank.Notify(src, L('check_cashed', amount), Bank.ICON_OK)
end

RegisterNetEvent('pop_bank:depositCheque', function(checkId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(checkId) ~= 'string' and type(checkId) ~= 'number' then return end
    if not Bank.IsNearBank(src) then return end

    MySQL.single('SELECT * FROM banking_checks WHERE unique_check_id = ?', { checkId }, function(row)
        if not row then return Bank.Notify(src, L('check_not_found'), Bank.ICON_WARN) end
        if row.status ~= 'active' then return Bank.Notify(src, L('check_already_used'), Bank.ICON_WARN) end

        local heldItem = findHeldCheck(src, checkId)
        if not heldItem then return Bank.Notify(src, L('check_not_held'), Bank.ICON_WARN) end

        local amount = tonumber(row.amount)
        if not amount or amount <= 0 then return Bank.Notify(src, L('check_invalid'), Bank.ICON_WARN) end

        local debitChestId = row.issuer_company and Bank.CompanyChestId(row.issuer_company) or nil

        local creditChestId = nil
        local orderJobName, orderJobLabel = Bank.FindJobByLabel(row.receiver_name)
        if orderJobName then
            local boss, job = Bank.IsBoss(xPlayer)
            if not boss or job.name ~= orderJobName then
                return Bank.Notify(src, L('check_boss_only', orderJobLabel), Bank.ICON_WARN)
            end
            creditChestId = Bank.CompanyChestId(orderJobName)
        end

        if not issuerHasFunds(row, debitChestId, amount) then
            return Bank.Notify(src, L('issuer_no_funds'), Bank.ICON_WARN)
        end

        -- Réservation atomique : si une autre requête a déjà déposé ce chèque, affected = 0.
        MySQL.update(
            "UPDATE banking_checks SET status = 'deposited', deposited_at = NOW() WHERE unique_check_id = ? AND status = 'active'",
            { checkId },
            function(affected)
                if not affected or affected == 0 then
                    return Bank.Notify(src, L('check_just_used'), Bank.ICON_WARN)
                end
                CreateThread(function() -- thread : requêtes .await possibles
                    settle(src, checkId, row, heldItem, amount, debitChestId, creditChestId)
                end)
            end
        )
    end)
end)
