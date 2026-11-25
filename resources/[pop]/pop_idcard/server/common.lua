-- Fonctions communes du serveur pop_idcard (chargé en premier, voir fxmanifest).
-- Tout passe par le bridge : fonctionne avec ESX, QBCore, Qbox et standalone.

IdCard = {}

local ICON = 'fas fa-id-card'
local FEMALE = GetHashKey('mp_f_freemode_01')

--- Prénom et nom du personnage (bridge), séparés au premier espace.
local function splitName(src)
    local full = Bridge.GetName(src)
    if type(full) ~= 'string' or full == '' then return nil, nil end
    local first, last = full:match('^(%S+)%s+(.+)$')
    return first or full, last
end

--- Sexe d'après le modèle du ped (freemode) : 'F' ou 'M'.
local function pedSex(src)
    local ped = GetPlayerPed(src)
    return (ped ~= 0 and GetEntityModel(ped) == FEMALE) and 'F' or 'M'
end

--- Métadonnées de la carte du joueur src.
function IdCard.BuildMetadata(src, firstname, lastname, sex, nationality)
    local isMexico = nationality == Config.MexicoNationality
    return {
        firstname = firstname or L('unknown_name'),
        lastname = lastname or L('unknown_name'),
        sex = sex or 'M',
        identifier = Bridge.GetIdentifier(src),
        cardType = isMexico and 'mx' or 'us',
        description = L('card_description', firstname or '?', lastname or '?'),
    }, isMexico and Config.CardItemMx or Config.CardItem
end

--- Donne l'objet. Avec pop_inventory, dépôt possible dans un conteneur (portefeuille)
--- et sans contrôle de poids comme à l'origine ; sinon inventaire détecté par le bridge.
local function giveCard(src, item, metadata, containerId)
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

--- Crée la carte d'identité du joueur targetId. customData (pop_charcreator) :
--- { firstname, lastname, skin, nationality } ; sinon nom du personnage (bridge).
function IdCard.Issue(targetId, containerId, customData)
    local src = tonumber(targetId)
    if not src or not Bridge.GetIdentifier(src) then return end

    local firstname, lastname, sex, nationality
    if customData then
        firstname, lastname, nationality = customData.firstname, customData.lastname, customData.nationality
        local skin = type(customData.skin) == 'table' and customData.skin
            or (type(customData.skin) == 'string' and json.decode(customData.skin)) or nil
        sex = (skin and skin.sex == 1) and 'F' or (skin and 'M') or pedSex(src)
    else
        firstname, lastname = splitName(src)
        sex = pedSex(src)
        if not firstname and Config.Debug then
            print(('[pop_idcard] aucun personnage pour %s'):format(src))
        end
    end

    local metadata, item = IdCard.BuildMetadata(src, firstname, lastname, sex, nationality)
    if giveCard(src, item, metadata, containerId) then
        Bridge.Notify(src, { icon = ICON, message = L('card_received'), duration = Config.NotifyReceivedDuration })
    else
        Bridge.Notify(src, { icon = ICON, message = L('inventory_full'), duration = Config.NotifyReceivedDuration })
    end
end

--- Source du joueur connecté qui a cet identifiant, ou nil.
function IdCard.FindSource(identifier)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if Bridge.GetIdentifier(src) == identifier then return src end
    end
    return nil
end
