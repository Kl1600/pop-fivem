-- pop_passport server side
local ESX = exports['es_extended']:getSharedObject()

local function dbQuery(query, params, cb)
    if MySQL then
        MySQL.query(query, params, cb)
    elseif exports.oxmysql then
        exports.oxmysql:query(query, params, cb)
    else
        print('^1[pop_passport] CRITICAL: MySQL et oxmysql sont NIL !^7')
    end
end

-- Génère un numéro de passeport : 1 lettre + 8 chiffres
local function genNumber(prefix)
    local n = ''
    for _ = 1, 8 do n = n .. tostring(math.random(0, 9)) end
    return prefix .. n
end

-- type : 'us' | 'mx'
local function issuePassport(targetId, passportType, containerId, customData)
    passportType = (passportType == 'mx') and 'mx' or 'us'
    local xPlayer = ESX.GetPlayerFromId(targetId)
    if not xPlayer then
        return
    end

    local function proceed(firstname, lastname, skin, dob)
        local skinData = json.decode(skin or '{}')
        local sex = (skinData and skinData.sex == 1) and 'F' or 'M'

        local isMx = (passportType == 'mx')
        local item = isMx and 'passport_mx' or 'passport_us'

        -- Validité : 10 ans
        local today  = os.date('%Y-%m-%d')
        local expiry = os.date('%Y-%m-%d', os.time() + (10 * 365 * 24 * 3600))

        local metadata = {
            firstname   = firstname or 'Inconnu',
            lastname    = lastname or 'Inconnu',
            sex         = sex,
            dob         = dob,
            identifier  = xPlayer.identifier,
            number      = genNumber(isMx and 'G' or 'A'),
            nationality = isMx and 'MEXICANA' or 'USA',
            authority   = isMx and 'SRE CHIHUAHUA' or 'DOS SAN ANDREAS',
            pob         = isMx and 'MEXICO' or 'SAN ANDREAS',
            issueDate   = today,
            expiryDate  = expiry,
            type        = passportType,
            description = string.format('Passeport %s — %s %s', isMx and 'MX' or 'US', firstname or '?', lastname or '?')
        }

        if containerId then
            exports['pop_inventory']:addItemToContainer(xPlayer.source, containerId, item, 1, metadata)
        else
            exports['pop_inventory']:GiveItem(xPlayer.source, item, 1, metadata)
        end

        TriggerClientEvent('esx:showNotification', xPlayer.source, 'Vous avez reçu votre passeport.')
    end

    if customData then
        proceed(customData.firstname, customData.lastname, customData.skin, customData.dob)
    else
        dbQuery('SELECT firstname, lastname, skin, dateofbirth FROM users WHERE identifier = ?', {
            xPlayer.identifier
        }, function(result)
            if result and result[1] then
                local r = result[1]
                proceed(r.firstname, r.lastname, r.skin, r.dateofbirth)
            else
                print('[pop_passport] Aucun user en DB pour:', xPlayer.identifier)
            end
        end)
    end
end

AddEventHandler('pop_passport:server:issueInternal', function(targetId, passportType, containerId, customData)
    issuePassport(targetId, passportType, containerId, customData)
end)

ESX.RegisterCommand('givepassport', 'admin', function(xPlayer, args, showError)
    local target = args.id or xPlayer.source
    issuePassport(target, args.type or 'us')
end, true, {
    help = 'Donner un passeport (us/mx)',
    arguments = {
        { name = 'id',   help = 'ID du joueur',  type = 'number' },
        { name = 'type', help = 'us ou mx',      type = 'string' }
    }
})
