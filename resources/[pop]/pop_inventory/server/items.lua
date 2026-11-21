-- Registre des items : définitions normalisées (data/items.lua + import du framework), libellés traduits.

Items = Items or {}

local RES = GetCurrentResourceName()

local Registry = {}   -- [name] = def normalisée
local AmmoOf = {}     -- [nom de munition] = true (au moins une arme l'utilise)
local defsCache = nil -- ItemDefs prêtes pour le client (invalidées à chaque ajout)

local function debug(msg, ...)
    if Config.Debug then print(('[%s] items: ' .. msg):format(RES, ...)) end
end

-- Normalise une définition brute (SPEC §9.2).
local function normalize(name, d)
    local weapon = d.weapon == true
    local def = {
        name = name,
        label = type(d.label) == 'string' and d.label or name,
        weight = math.max(0, math.floor(tonumber(d.weight) or 0)),
        stack = not weapon and d.stack ~= false,
        close = d.close ~= false,
        description = type(d.description) == 'string' and d.description or nil,
        image = type(d.image) == 'string' and d.image or nil,
        consume = math.max(0, math.floor(tonumber(d.consume) or 0)),
        weapon = weapon,
        ammo = weapon and type(d.ammo) == 'string' and d.ammo:lower() or nil,
        clip = math.max(0, math.floor(tonumber(d.clip) or 0)),
        degrade = math.max(0, tonumber(d.degrade) or 0),
    }
    return def
end

--- Ajoute une définition. overwrite = false : ignorée si le nom existe déjà. Renvoie true si ajoutée.
function Items.Register(name, data, overwrite)
    if type(name) ~= 'string' or name == '' or type(data) ~= 'table' then return false end
    name = name:lower()
    if Registry[name] and not overwrite then return false end
    local def = normalize(name, data)
    Registry[name] = def
    if def.ammo then AmmoOf[def.ammo] = true end
    defsCache = nil
    return true
end

-- Chargement de data/items.lua (données seulement, aucune fonction d'un autre fichier).
for name, data in pairs(ItemList or {}) do
    Items.Register(name, data, true)
end

--- Définition normalisée (nom insensible à la casse) ou nil.
function Items.Get(name)
    if type(name) ~= 'string' then return nil end
    return Registry[name:lower()]
end

--- Table interne de toutes les définitions (lecture seule).
function Items.All()
    return Registry
end

--- Vrai si au moins une arme utilise cet item comme munitions.
function Items.IsAmmo(name)
    return type(name) == 'string' and AmmoOf[name:lower()] == true
end

-- Une clé de locale « existe » si L(key) ~= key.
local function localeOr(key, fallback)
    local text = L(key)
    if text ~= key then return text end
    return fallback
end

--- Libellé traduit : item_<nom>, sinon def.label, sinon le nom.
function Items.Label(name)
    if type(name) ~= 'string' then return '' end
    name = name:lower()
    local def = Registry[name]
    return localeOr('item_' .. name, def and def.label or name)
end

--- Description traduite : desc_<nom>, sinon def.description, sinon nil.
function Items.Description(name)
    if type(name) ~= 'string' then return nil end
    name = name:lower()
    local def = Registry[name]
    return localeOr('desc_' .. name, def and def.description or nil)
end

--- ItemDefs pour le client et la NUI (libellés traduits), calculée une fois.
function Items.Defs()
    if defsCache then return defsCache end
    local out = {}
    for name, def in pairs(Registry) do
        out[name] = {
            label = Items.Label(name),
            weight = def.weight,
            stack = def.stack,
            close = def.close,
            description = Items.Description(name),
            image = def.image,
            weapon = def.weapon,
            ammo = def.ammo,
        }
    end
    defsCache = out
    return out
end

--- Copie publique d'une définition (export Items) : format ItemDefs + consume, clip, degrade.
function Items.Public(name)
    local def = Items.Get(name)
    if not def then return nil end
    return {
        name = def.name,
        label = Items.Label(def.name),
        weight = def.weight,
        stack = def.stack,
        close = def.close,
        description = Items.Description(def.name),
        image = def.image,
        weapon = def.weapon,
        ammo = def.ammo,
        consume = def.consume,
        clip = def.clip,
        degrade = def.degrade,
    }
end

--- Libellé de config : texte de la clé de locale si elle existe, sinon le texte tel quel.
function LabelOf(text)
    if type(text) ~= 'string' then return '' end
    return localeOr(text, text)
end

--- Import des définitions du framework absentes du registre (bloquant : appelé dans un thread au démarrage).
function Items.Import()
    if not Config.ImportFramework then return end
    local count = 0

    if Bridge.Framework == 'esx' then
        local ok, rows = pcall(MySQL.query.await, 'SELECT name, label, weight FROM items')
        local kg = true
        if not ok or type(rows) ~= 'table' then
            -- Ancien ESX : pas de colonne weight.
            ok, rows = pcall(MySQL.query.await, 'SELECT name, label FROM items')
            kg = false
        end
        if ok and type(rows) == 'table' then
            for _, row in ipairs(rows) do
                if type(row.name) == 'string' and not Items.Get(row.name) then
                    -- NOTE: le poids ESX est en kg (Legacy) : converti en grammes.
                    local weight = kg and math.floor((tonumber(row.weight) or 0) * 1000) or 0
                    local isWeapon = row.name:lower():sub(1, 7) == 'weapon_'
                    if Items.Register(row.name, { label = row.label, weight = weight, weapon = isWeapon }) then
                        count = count + 1
                    end
                end
            end
        end
    elseif Bridge.Framework == 'qbcore' then
        local ok, shared = pcall(function() return exports['qb-core']:GetCoreObject().Shared.Items end)
        if ok and type(shared) == 'table' then
            for key, it in pairs(shared) do
                local name = type(it) == 'table' and (it.name or key) or nil
                if type(name) == 'string' and not Items.Get(name) then
                    local image = type(it.image) == 'string' and it.image:gsub('%.png$', '') or nil
                    if Items.Register(name, {
                        label = it.label,
                        weight = it.weight,
                        stack = it.unique ~= true,
                        close = it.shouldClose ~= false,
                        description = it.description,
                        image = image,
                        weapon = it.type == 'weapon',
                    }) then
                        count = count + 1
                    end
                end
            end
        end
    end
    -- Qbox / standalone : rien à importer.

    debug('%d item definitions imported from %s', count, Bridge.Framework)
end
