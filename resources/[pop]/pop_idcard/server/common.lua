-- Fonctions communes du serveur pop_idcard (chargé en premier, voir fxmanifest).

IdCard = {}

-- ESX direct : joueur par identifier (photo) et commande admin (ESX.RegisterCommand),
-- non couverts par le bridge. À passer par le bridge au moment du multi-framework.
IdCard.ESX = exports['es_extended']:getSharedObject()

-- pop_inventory direct : dépôt dans un conteneur (portefeuille) et don sans contrôle de poids,
-- comme à l'origine.
IdCard.INV = exports['pop_inventory']

local ICON = 'fas fa-id-card'

--- Crée la carte d'identité du joueur targetId. customData (pop_charcreator) :
--- { firstname, lastname, skin, nationality } ; sinon lecture de la table users.
function IdCard.Issue(targetId, containerId, customData)
    local src = tonumber(targetId)
    local identifier = src and Bridge.GetIdentifier(src)
    if not identifier then
        return
    end

    local function proceed(firstname, lastname, skin)
        local skinData = json.decode(skin or '{}')
        local sex = (skinData and skinData.sex == 1) and "F" or "M"

        -- Determine card type based on nationality
        local isMexico = (customData and customData.nationality == Config.MexicoNationality)
        local cardItem = isMexico and Config.CardItemMx or Config.CardItem

        -- Metadata for pop_inventory
        local metadata = {
            firstname = firstname or L('unknown_name'),
            lastname = lastname or L('unknown_name'),
            sex = sex,
            identifier = identifier,
            cardType = isMexico and 'mx' or 'us',
            description = L('card_description', firstname or "?", lastname or "?")
        }

        if containerId then
            IdCard.INV:addItemToContainer(src, containerId, cardItem, 1, metadata)
        else
            IdCard.INV:GiveItem(src, cardItem, 1, metadata)
        end

        Bridge.Notify(src, { icon = ICON, message = L('card_received'), duration = Config.NotifyReceivedDuration })
    end

    if customData then
        proceed(customData.firstname, customData.lastname, customData.skin)
    else
        MySQL.query('SELECT firstname, lastname, skin FROM users WHERE identifier = ?', {
            identifier
        }, function(result)
            if result and result[1] then
                local r = result[1]
                proceed(r.firstname, r.lastname, r.skin)
            elseif Config.Debug then
                print(('[pop_idcard] aucun personnage pour %s'):format(identifier))
            end
        end)
    end
end
