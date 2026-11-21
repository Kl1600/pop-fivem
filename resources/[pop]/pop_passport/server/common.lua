-- Fonctions communes du serveur pop_passport (chargé en premier, voir fxmanifest).

Passport = {}

-- ESX direct : joueur par identifier (GetPlayerFromIdentifier) et commande admin (RegisterCommand),
-- non couverts par le bridge. À passer par le bridge au moment du multi-framework.
Passport.ESX = exports['es_extended']:getSharedObject()

-- pop_inventory direct : ajout dans un conteneur (portefeuille) ou don simple, comme à l'origine.
Passport.INV = exports['pop_inventory']

-- Génère un numéro de passeport : 1 lettre + 8 chiffres
local function genNumber(prefix)
    local n = ''
    for _ = 1, 8 do n = n .. tostring(math.random(0, 9)) end
    return prefix .. n
end

-- type : 'us' | 'mx'
function Passport.Issue(targetId, passportType, containerId, customData)
    passportType = (passportType == 'mx') and 'mx' or 'us'
    local xPlayer = Bridge.GetPlayer(targetId)
    if not xPlayer then
        return
    end
    local src = xPlayer.source
    local identifier = Bridge.GetIdentifier(src)

    local function proceed(firstname, lastname, skin, dob)
        local skinData = json.decode(skin or '{}')
        local sex = (skinData and skinData.sex == 1) and 'F' or 'M'

        local isMx = (passportType == 'mx')
        local item = isMx and 'passport_mx' or 'passport_us'

        -- Validité : Config.ValidityYears (10 ans)
        local today  = os.date('%Y-%m-%d')
        local expiry = os.date('%Y-%m-%d', os.time() + (Config.ValidityYears * 365 * 24 * 3600))

        local metadata = {
            firstname   = firstname or L('unknown'),
            lastname    = lastname or L('unknown'),
            sex         = sex,
            dob         = dob,
            identifier  = identifier,
            number      = genNumber(isMx and 'G' or 'A'),
            nationality = isMx and 'MEXICANA' or 'USA',
            authority   = isMx and 'SRE CHIHUAHUA' or 'DOS SAN ANDREAS',
            pob         = isMx and 'MEXICO' or 'SAN ANDREAS',
            issueDate   = today,
            expiryDate  = expiry,
            type        = passportType,
            description = L('passport_description', isMx and 'MX' or 'US', firstname or '?', lastname or '?')
        }

        if containerId then
            Passport.INV:addItemToContainer(src, containerId, item, 1, metadata)
        else
            Passport.INV:GiveItem(src, item, 1, metadata)
        end

        Bridge.Notify(src, { icon = 'fas fa-passport', message = L('passport_received'), duration = Config.NotifyReceived })
    end

    if customData then
        proceed(customData.firstname, customData.lastname, customData.skin, customData.dob)
    else
        MySQL.query('SELECT firstname, lastname, skin, dateofbirth FROM users WHERE identifier = ?', {
            identifier
        }, function(result)
            if result and result[1] then
                local r = result[1]
                proceed(r.firstname, r.lastname, r.skin, r.dateofbirth)
            else
                print('[pop_passport] Aucun user en DB pour:', identifier)
            end
        end)
    end
end
