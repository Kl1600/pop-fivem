-- Fonctions communes du serveur pop_charcreator (chargé en premier, voir fxmanifest).
-- ESX direct : la globale ESX vient de @es_extended/imports.lua (xPlayer.set, setName, commande admin).

CharCreator = {}

-- Sécurité : un personnage déjà créé ne peut pas être réécrit par le client.
-- adminReopen[src] = true uniquement si un admin a ouvert le créateur (/charcreator).
CharCreator.adminReopen = {}
CharCreator.saving = {}
CharCreator.inCreatorInstance = {}

-- Contrôle du skin envoyé par le client : modèle freemode seulement et valeurs
-- dans les limites normales de skinchanger. Renvoie false si quelque chose cloche.
local FREEMODE = { [0] = GetHashKey('mp_m_freemode_01'), [1] = GetHashKey('mp_f_freemode_01') }
local FREEMODE_NAMES = { mp_m_freemode_01 = 0, mp_f_freemode_01 = 1 }

function CharCreator.isValidSkin(src, skin)
    local sex = tonumber(skin.sex)
    if sex ~= 0 and sex ~= 1 then return false end

    -- Champ « model » éventuel : seulement les deux modèles freemode, cohérent avec sex
    if skin.model ~= nil and FREEMODE_NAMES[skin.model] ~= sex then return false end

    -- Ped réel du joueur (vu par le serveur) : doit être le freemode du bon sexe
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local model = GetEntityModel(ped)
        if model ~= FREEMODE[0] and model ~= FREEMODE[1] then return false end
    end

    local count = 0
    for k, v in pairs(skin) do
        count = count + 1
        if count > 150 or type(k) ~= 'string' or #k > 32 then return false end
        if k ~= 'model' then
            local n = tonumber(v)
            if not n or n ~= n then return false end -- nombre obligatoire (pas de table, pas de NaN)
            if k == 'height' then
                if n < 80 or n > 120 then return false end
            elseif n < -1 or n > 1000 then
                return false
            end
        end
    end
    return true
end

-- Tenue choisie (numéros de vêtements) : mêmes limites que le skin.
function CharCreator.isValidClothes(clothes)
    if clothes == nil then return true end
    local count = 0
    for k, v in pairs(clothes) do
        count = count + 1
        local n = tonumber(v)
        if count > 60 or type(k) ~= 'string' or not n or n ~= n or n < -1 or n > 1000 then return false end
    end
    return true
end

function CharCreator.cleanText(value, maxLen)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%c<>]', ''):match('^%s*(.-)%s*$')
    if value == '' then return nil end
    return value:sub(1, maxLen)
end
