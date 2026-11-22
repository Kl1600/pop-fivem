-- Agences bancaires : zones d'interaction, ouverture des comptes et dépôt de chèques.

local function notify(message, icon)
    Bridge.Notify({
        title    = L('bank_title'),
        message  = message,
        icon     = icon or 'fas fa-building-columns',
        duration = Config.NotifyDuration,
    })
end

-- Affichage seulement : le serveur revérifie que le joueur est patron.
local function isBoss()
    local job = Bridge.GetPlayerData().job
    return job ~= nil and job.grade_name == 'boss'
end

-- Le serveur a validé l'accès et résolu le bon coffre.
-- OpenStaticChestUI ouvre le panneau coffre de pop_inventory (canal _standby).
RegisterNetEvent('pop_bank:client:openAccount', function(chestId, label, slots, maxWeight)
    exports.pop_inventory:OpenStaticChestUI(chestId, label, slots, maxWeight)
end)

local function depositCheque()
    Callback.Trigger('pop_bank:getMyChecks', function(checks)
        if not checks or #checks == 0 then
            notify(L('no_checks'), 'fas fa-circle-info')
            return
        end

        local options = {}
        for _, check in ipairs(checks) do
            options[#options + 1] = {
                title       = check.issuerCompanyLabel
                    and L('check_company_line', check.issuerCompanyLabel, check.amount, check.beneficiaire)
                    or L('check_line', check.amount, check.beneficiaire),
                description = L('deposit_click'),
                icon        = 'fas fa-money-check-dollar',
                onSelect    = function() TriggerServerEvent('pop_bank:depositCheque', check.checkId) end,
            }
        end

        lib.registerContext({ id = 'pop_bank_deposit_choice', title = L('deposit_menu_title'), options = options })
        lib.showContext('pop_bank_deposit_choice')
    end)
end

CreateThread(function()
    for _, location in ipairs(Config.Locations) do
        Bridge.Target.AddBoxZone('pop_bank_' .. location.id, location.coords, Config.TargetZoneSize, location.heading, {
            {
                icon     = 'fas fa-wallet',
                label    = L('target_personal'),
                onSelect = function() TriggerServerEvent('pop_bank:server:openAccount', 'personal') end,
            },
            {
                icon        = 'fas fa-building-columns',
                label       = L('target_company'),
                canInteract = isBoss,
                onSelect    = function() TriggerServerEvent('pop_bank:server:openAccount', 'company') end,
            },
            {
                icon     = 'fas fa-money-check-dollar',
                label    = L('target_deposit'),
                onSelect = depositCheque,
            },
        })
    end
end)
