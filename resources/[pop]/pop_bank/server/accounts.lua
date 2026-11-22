-- Ouverture des comptes (coffres pop_inventory) et liste des chèques portés.

-- L'id du coffre est recalculé ici depuis l'identifier / le job : un client ne peut jamais
-- demander l'ouverture du coffre de quelqu'un d'autre.
RegisterNetEvent('pop_bank:server:openAccount', function(scope)
    local src = source
    local xPlayer = Bank.ESX.GetPlayerFromId(src)
    if not xPlayer or not Bank.IsNearBank(src) then return end

    if scope == 'personal' then
        TriggerClientEvent('pop_bank:client:openAccount', src, Bank.PersonalChestId(xPlayer.identifier),
            L('account_personal'), Config.AccountSlots, Config.AccountMaxWeight)
        return
    end

    if scope == 'company' then
        local boss, job = Bank.IsBoss(xPlayer)
        if not boss then
            Bank.Notify(src, L('company_boss_only'), Bank.ICON_WARN)
            return
        end
        TriggerClientEvent('pop_bank:client:openAccount', src, Bank.CompanyChestId(job.name),
            L('account_company', job.label or job.name), Config.AccountSlots, Config.AccountMaxWeight)
    end
end)

Callback.Register('pop_bank:getMyChecks', function(source)
    local results = {}
    for _, item in ipairs(Bank.GetHeldChecks(source)) do
        local meta = item.meta
        results[#results + 1] = {
            checkId            = meta.checkId,
            amount             = meta.montant,
            beneficiaire       = meta.beneficiaire,
            issuerCompanyLabel = meta.issuerCompanyLabel,
        }
    end
    return results
end)
