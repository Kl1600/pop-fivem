local ESX = exports['es_extended']:getSharedObject()

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `banking_checks` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `unique_check_id` VARCHAR(50) NOT NULL UNIQUE,
            `issuer_identifier` VARCHAR(50) NOT NULL,
            `account_number` VARCHAR(20) NOT NULL,
            `receiver_name` VARCHAR(100) NOT NULL,
            `issuer_company` VARCHAR(50) DEFAULT NULL,
            `amount` INT NOT NULL,
            `status` VARCHAR(20) DEFAULT 'active',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `deposited_at` TIMESTAMP NULL DEFAULT NULL
        );
    ]], {}, function()
        print("[Info] La base de données pour les chèques a été vérifiée/créée.")
    end)

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `bank_accounts` (
            `identifier` VARCHAR(60) NOT NULL PRIMARY KEY,
            `account_number` VARCHAR(20) NOT NULL UNIQUE,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    ]], {}, function()
        print("[Info] La base de données des numéros de compte a été vérifiée/créée.")
    end)
end)

local function generateAccountNumber()
    local digits = ''
    for _ = 1, (Config.AccountNumberDigits or 10) do
        digits = digits .. tostring(math.random(0, 9))
    end
    return (Config.AccountNumberPrefix or 'FB') .. '-' .. digits
end

-- Renvoie (via callback) le numéro de compte de cet identifier, en le créant s'il n'existe pas encore.
-- Source de vérité unique pour le numéro de compte : jamais saisi par le joueur, toujours
-- résolu/généré côté serveur à partir de l'identifier ESX.
function EnsureAccountNumber(identifier, cb)
    MySQL.query('SELECT account_number FROM bank_accounts WHERE identifier = ?', { identifier }, function(rows)
        if rows and rows[1] then
            cb(rows[1].account_number)
            return
        end

        local function tryInsert()
            local accountNumber = generateAccountNumber()
            MySQL.insert(
                'INSERT INTO bank_accounts (identifier, account_number) VALUES (?, ?)',
                { identifier, accountNumber },
                function(insertId)
                    if insertId then
                        cb(accountNumber)
                    else
                        tryInsert() -- collision sur account_number (UNIQUE) : on retente avec un autre
                    end
                end
            )
        end
        tryInsert()
    end)
end

exports('EnsureAccountNumber', EnsureAccountNumber)

-- Verrou par joueur : empêche le spam de l'événement de dépasser la limite du chéquier
-- (le compteur n'est mis à jour qu'après les requêtes SQL asynchrones).
local chequeBusy = {}

AddEventHandler('playerDropped', function()
    chequeBusy[source] = nil
end)

RegisterNetEvent("pop_inventory:createCheque")
AddEventHandler("pop_inventory:createCheque", function(cheque)

    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer or type(cheque) ~= 'table' then
        return
    end

    if chequeBusy[src] then
        return
    end

    local amount = tonumber(cheque.montant)
    amount = amount and math.floor(amount)

    if not amount or amount <= 0 then
        TriggerClientEvent('esx:showNotification', src, 'Montant invalide.')
        return
    end

    if type(cheque.beneficiaire) ~= 'string' or cheque.beneficiaire == '' then
        TriggerClientEvent('esx:showNotification', src, 'Bénéficiaire invalide.')
        return
    end
    cheque.beneficiaire = cheque.beneficiaire:sub(1, 100)

    -- L'item exact utilisé fait foi : jamais de defId/entreprise envoyés par le client.
    -- checkbook -> chèque personnel (débite le coffre perso de xPlayer au dépôt).
    -- checkbook_company -> chèque d'entreprise (débite le coffre de l'entreprise au dépôt),
    -- l'entreprise étant celle figée dans la meta du chéquier au moment de sa livraison
    -- (cf. pop_management SecuroServ), jamais choisie librement par le joueur.
    local heldItems = exports.pop_inventory:GetPlayerItems(src, nil) or {}
    local heldItem = nil
    for _, item in ipairs(heldItems) do
        if item.id == cheque.itemId then
            heldItem = item
            break
        end
    end

    if not heldItem or (heldItem.defId ~= 'checkbook' and heldItem.defId ~= 'checkbook_company') then
        TriggerClientEvent('esx:showNotification', src, "Vous n'avez pas ce chéquier sur vous.")
        return
    end

    -- Limite de chèques par chéquier : le compteur est stocké dans la meta de l'item
    -- lui-même (chequesIssued), donc propre à cette instance précise de chéquier.
    local checkbookMeta = heldItem.meta or {}
    local chequesIssued = tonumber(checkbookMeta.chequesIssued) or 0
    local maxCheques = Config.MaxChequesPerCheckbook or 20

    if chequesIssued >= maxCheques then
        TriggerClientEvent('esx:showNotification', src, ('Ce chéquier est épuisé (limite de %d chèques atteinte).'):format(maxCheques))
        return
    end

    local issuerCompany = nil
    local issuerCompanyLabel = nil
    if heldItem.defId == 'checkbook_company' then
        if not checkbookMeta.company then
            TriggerClientEvent('esx:showNotification', src, 'Chéquier d\'entreprise invalide.')
            return
        end
        issuerCompany = checkbookMeta.company
        issuerCompanyLabel = checkbookMeta.companyLabel or checkbookMeta.company
    end

    chequeBusy[src] = true
    EnsureAccountNumber(issuerCompany and ('company_' .. issuerCompany) or xPlayer.identifier, function(accountNumber)
        local uniqueCheckId = ("CHK-%s-%s"):format(
            os.time(),
            math.random(1000, 9999)
        )

        MySQL.insert([[
            INSERT INTO banking_checks (
                unique_check_id,
                issuer_identifier,
                account_number,
                receiver_name,
                issuer_company,
                amount,
                status
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]],
        {
            uniqueCheckId,
            xPlayer.identifier,
            accountNumber,
            cheque.beneficiaire,
            issuerCompany,
            amount,
            "active"
        },
        function(insertId)

            chequeBusy[src] = nil
            if not insertId then
                TriggerClientEvent('esx:showNotification', src, 'Erreur lors de la création du chèque.')
                return
            end

            local given = exports.pop_inventory:addItem(
                src,
                "check",
                1,
                {
                    checkId = uniqueCheckId,
                    beneficiaire = cheque.beneficiaire,
                    montant = amount,
                    numeroCompte = accountNumber,
                    issuerCompany = issuerCompany,
                    issuerCompanyLabel = issuerCompanyLabel,
                }
            )

            if not given then
                -- L'item n'a pas pu être remis (inventaire plein) : on annule la ligne en
                -- base pour ne pas laisser un chèque "actif" sans chèque physique associé.
                MySQL.query('DELETE FROM banking_checks WHERE id = ?', { insertId })
                TriggerClientEvent('esx:showNotification', src, "Inventaire plein : impossible de vous remettre le chèque.")
                return
            end

            checkbookMeta.chequesIssued = chequesIssued + 1
            exports.pop_inventory:UpdateItemMetadata(src, heldItem.id, checkbookMeta)

            TriggerClientEvent(
                'esx:showNotification',
                src,
                ('Chèque créé : %s$'):format(amount)
            )

            if checkbookMeta.chequesIssued >= maxCheques then
                exports.pop_inventory:removeItemById(src, heldItem.id)
                TriggerClientEvent('esx:showNotification', src, 'Le chéquier est maintenant vide et a été jeté.')
            end

            print(('[CHEQUE] %s a créé le chèque %s'):format(
                xPlayer.identifier,
                uniqueCheckId
            ))
        end)
    end)
end)
