-- Fonctions communes du serveur pop_passport (chargé en premier, voir fxmanifest).
-- Tout passe par le bridge : fonctionne avec ESX, QBCore, Qbox et standalone.

Passport = {}

local FEMALE = GetHashKey('mp_f_freemode_01')

-- Génère un numéro de passeport : 1 lettre + 8 chiffres
local function genNumber(prefix)
    local n = ''
    for _ = 1, 8 do n = n .. tostring(math.random(0, 9)) end
    return prefix .. n
end

--- Prénom et nom du personnage (bridge), séparés au premier espace.
local function splitName(src)
    local full = Bridge.GetName(src)
    if type(full) ~= 'string' or full == '' then return nil, nil end
    local first, last = full:match('^(%S+)%s+(.+)$')
    return first or full, last
end

--- Date de naissance si le framework la connaît (objet joueur renvoyé par le bridge).
local function birthDate(src)
    local p = Bridge.GetPlayer(src)
    if type(p) ~= 'table' then return nil end
    if type(p.get) == 'function' then
        local ok, v = pcall(p.get, 'dateofbirth')          -- ESX
        if ok and v then return v end
    end
    local info = p.PlayerData and p.PlayerData.charinfo    -- QBCore / Qbox
    return info and info.birthdate or nil
end

--- Sexe d'après le modèle du ped (freemode) : 'F' ou 'M'.
local function pedSex(src)
    local ped = GetPlayerPed(src)
    return (ped ~= 0 and GetEntityModel(ped) == FEMALE) and 'F' or 'M'
end

--- Métadonnées du passeport ('us' | 'mx') du joueur src, et nom de l'objet.
function Passport.BuildMetadata(src, passportType, firstname, lastname, sex, dob)
    local isMx = passportType == 'mx'
    local info = isMx and Config.Mexico or Config.USA
    return {
        firstname   = firstname or L('unknown'),
        lastname    = lastname or L('unknown'),
        sex         = sex or 'M',
        dob         = dob,
        identifier  = Bridge.GetIdentifier(src),
        number      = genNumber(info.numberPrefix),
        nationality = info.nationality,
        authority   = info.authority,
        pob         = info.placeOfBirth,
        issueDate   = os.date('%Y-%m-%d'),
        expiryDate  = os.date('%Y-%m-%d', os.time() + (Config.ValidityYears * 365 * 24 * 3600)),
        type        = isMx and 'mx' or 'us',
        description = L('passport_description', isMx and 'MX' or 'US', firstname or '?', lastname or '?'),
    }, info.item
end

--- Donne l'objet. Avec pop_inventory : conteneur possible (portefeuille) et pas de contrôle
--- de poids, comme à l'origine ; sinon inventaire détecté par le bridge.
local function give(src, item, metadata, containerId)
    if GetResourceState('pop_inventory') == 'started' then
        if containerId then
            exports['pop_inventory']:addItemToContainer(src, containerId, item, 1, metadata)
        else
            exports['pop_inventory']:GiveItem(src, item, 1, metadata)
        end
        return true
    end
    return Bridge.AddItem(src, item, 1, metadata)
end

-- type : 'us' | 'mx'. customData (pop_charcreator) : { firstname, lastname, skin, dob }.
function Passport.Issue(targetId, passportType, containerId, customData)
    passportType = (passportType == 'mx') and 'mx' or 'us'
    local src = tonumber(targetId)
    if not src or not Bridge.GetIdentifier(src) then return end

    local firstname, lastname, sex, dob
    if customData then
        firstname, lastname, dob = customData.firstname, customData.lastname, customData.dob
        local skin = type(customData.skin) == 'table' and customData.skin
            or (type(customData.skin) == 'string' and json.decode(customData.skin)) or nil
        sex = (skin and skin.sex == 1) and 'F' or (skin and 'M') or pedSex(src)
    else
        firstname, lastname = splitName(src)
        sex, dob = pedSex(src), birthDate(src)
        if not firstname and Config.Debug then
            print(('[pop_passport] aucun personnage pour %s'):format(src))
        end
    end

    local metadata, item = Passport.BuildMetadata(src, passportType, firstname, lastname, sex, dob)
    local ok = give(src, item, metadata, containerId)
    Bridge.Notify(src, { icon = 'fas fa-passport', message = L(ok and 'passport_received' or 'inventory_full'), duration = Config.NotifyReceived })
end

--- Source du joueur connecté qui a cet identifiant, ou nil.
function Passport.FindSource(identifier)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if Bridge.GetIdentifier(src) == identifier then return src end
    end
    return nil
end
