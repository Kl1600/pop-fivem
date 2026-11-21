-- Fonctions communes du serveur pop_bank (chargé en premier, voir fxmanifest).

Bank = {}

-- ESX direct : jobs (GetJobs), joueur par identifier, compte 'bank' hors ligne. À passer
-- par le bridge au moment du multi-framework.
Bank.ESX = exports['es_extended']:getSharedObject()
Bank.INV = exports['pop_inventory']

local ICON_INFO = 'fas fa-building-columns'

--- Notification au style d'origine (titre « Banque » + icône).
function Bank.Notify(src, message, icon)
    Bridge.Notify(src, {
        title    = L('bank_title'),
        message  = message,
        icon     = icon or ICON_INFO,
        duration = Config.NotifyDuration,
    })
end

Bank.ICON_WARN = 'fas fa-triangle-exclamation'
Bank.ICON_OK = 'fas fa-circle-check'

-- Id du coffre pop_inventory qui sert de compte bancaire
-- (cf. pop_inventory/server/sv_bank_vaults.lua). Jamais fourni par le client.
function Bank.PersonalChestId(identifier)
    return 'bank_personal_' .. identifier
end

function Bank.CompanyChestId(jobName)
    return 'bank_company_' .. jobName
end

-- Anti-abus : actions bancaires acceptées seulement près d'une agence.
function Bank.IsNearBank(src)
    for i = 1, #Config.Locations do
        if Bridge.IsNear(src, Config.Locations[i].coords, Config.MaxBankDistance) then return true end
    end
    return false
end

function Bank.IsBoss(xPlayer)
    local job = xPlayer and xPlayer.getJob()
    return job ~= nil and job.grade_name == 'boss', job
end

local function normalizeLabel(s)
    return tostring(s or ''):lower():match('^%s*(.-)%s*$')
end

-- Entreprise dont le label (SecuroServ, pop_management) correspond exactement au bénéficiaire.
function Bank.FindJobByLabel(label)
    local target = normalizeLabel(label)
    if target == '' then return nil end
    for jobName, job in pairs(Bank.ESX.GetJobs()) do
        if normalizeLabel(job.label) == target then
            return jobName, job.label
        end
    end
    return nil
end

-- Chèques portés par le joueur (objets 'check' de pop_inventory avec un checkId).
function Bank.GetHeldChecks(src)
    local out = {}
    for _, item in ipairs(Bank.INV:GetPlayerItems(src, 'check') or {}) do
        if item.meta and item.meta.checkId then out[#out + 1] = item end
    end
    return out
end
