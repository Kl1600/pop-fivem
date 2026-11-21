local ESX = exports['es_extended']:getSharedObject()

local function notify(title, message, icon)
    exports['pop_notify']:ShowNotify({
        title    = title,
        message  = message,
        icon     = icon or 'fas fa-building-columns',
        duration = 6000,
    })
end

local function isBoss()
    local job = ESX.GetPlayerData().job
    return job and job.grade_name == 'boss'
end

-- Le serveur résout le bon coffre (perso: identifier, entreprise: job) et ne répond
-- ici que s'il a validé l'accès (boss requis côté serveur pour 'company', re-vérifié
-- indépendamment de l'affichage du bouton ci-dessous).
RegisterNetEvent('pop_bank:client:openAccount', function(chestId, label, slots, maxWeight)
    -- OpenStaticChestUI déclenche lui-même pop_inventory:server:openStaticChest et affiche
    -- le panneau coffre (canal _standby) : un simple SendNUIMessage({action='open'}) ouvre
    -- l'inventaire normal (équipement) et masque même activement le panneau coffre.
    exports.pop_inventory:OpenStaticChestUI(chestId, label, slots, maxWeight)
end)

local function openPersonalAccount()
    TriggerServerEvent('pop_bank:server:openAccount', 'personal')
end

local function openCompanyAccount()
    TriggerServerEvent('pop_bank:server:openAccount', 'company')
end

local function depositCheque()
    ESX.TriggerServerCallback('pop_bank:getMyChecks', function(checks)
        if not checks or #checks == 0 then
            notify('Banque', "Vous n'avez aucun chèque sur vous.", 'fas fa-circle-info')
            return
        end

        local options = {}
        for _, check in ipairs(checks) do
            local label = check.issuerCompanyLabel
                and ('Chèque entreprise (%s) : %s$ (à : %s)'):format(check.issuerCompanyLabel, check.amount, check.beneficiaire)
                or ('Chèque : %s$ (à : %s)'):format(check.amount, check.beneficiaire)

            options[#options + 1] = {
                title       = label,
                description = 'Cliquer pour déposer ce chèque',
                icon        = 'fas fa-money-check-dollar',
                onSelect    = function()
                    TriggerServerEvent('pop_bank:depositCheque', check.checkId)
                end
            }
        end

        lib.registerContext({
            id      = 'tab_bank_deposit_choice',
            title   = 'Déposer un chèque',
            options = options
        })
        lib.showContext('tab_bank_deposit_choice')
    end)
end

CreateThread(function()
    for _, location in ipairs(Config.Locations) do
        exports.ox_target:addBoxZone({
            name     = 'tab_bank_' .. location.id,
            coords   = location.coords,
            size     = Config.TargetZoneSize,
            rotation = location.heading,
            debug    = false,
            options  = {
                {
                    name     = 'tab_bank_personal_' .. location.id,
                    icon     = 'fas fa-wallet',
                    label    = 'Compte personnel',
                    onSelect = openPersonalAccount,
                },
                {
                    name        = 'tab_bank_company_' .. location.id,
                    icon        = 'fas fa-building-columns',
                    label       = "Compte de l'entreprise",
                    canInteract = isBoss,
                    onSelect    = openCompanyAccount,
                },
                {
                    name     = 'tab_bank_deposit_' .. location.id,
                    icon     = 'fas fa-money-check-dollar',
                    label    = 'Déposer un chèque',
                    onSelect = depositCheque,
                },
            }
        })
    end
end)
