-- Accès aux objets tablette du joueur : un seul endroit.
-- pop_inventory direct : le bridge agrège les objets par nom et perd les métadonnées (donc le serial),
-- on lit et on écrit donc la pile elle-même via les exports de pop_inventory (GetPlayerItems, UpdateItemMetadata, removeItemById).
-- Les autres inventaires gardent le comportement du bridge (Bridge.GetItems / RemoveItem / AddItem).

Tablet = Tablet or {}
Tablet.Inventory = {}
local Inv = Tablet.Inventory

--- true si l'inventaire actif est pop_inventory (accès direct aux piles).
function Inv.Direct()
    return Bridge.Inventory == 'pop_inventory'
end

local function copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

--- Tablettes portées : liste de { slot, id, metadata }. `slot` sert à viser une pile précise.
function Inv.List(src)
    if not Inv.Direct() then return Bridge.GetItems(src, Config.Item) end
    local out = {}
    for _, it in ipairs(exports.pop_inventory:GetPlayerItems(src, Config.Item) or {}) do
        out[#out + 1] = { slot = it.id, id = it.id, metadata = it.meta or {} }
    end
    return out
end

--- Écrit `meta` sur l'objet sans serial `bare`. Renvoie true, annulation | false.
--- pop_inventory : métadonnées remplacées sur place (aucun retrait ni ajout) ; l'annulation les restaure.
--- Autres inventaires : retrait puis ajout avec les métadonnées ; l'annulation retire le nouvel objet et restitue l'ancien.
function Inv.Stamp(src, bare, meta)
    local old = bare.metadata or {}
    if Inv.Direct() then
        if exports.pop_inventory:UpdateItemMetadata(src, bare.id, meta) ~= true then return false end
        return true, function() exports.pop_inventory:UpdateItemMetadata(src, bare.id, copy(old)) end
    end
    if not Bridge.RemoveItem(src, Config.Item, 1, nil, bare.slot) then return false end
    if not Bridge.AddItem(src, Config.Item, 1, meta) then
        Bridge.AddItem(src, Config.Item, 1, old)
        return false
    end
    return true, function()
        Bridge.RemoveItem(src, Config.Item, 1, { serial = meta.serial })
        Bridge.AddItem(src, Config.Item, 1, old)
    end
end

--- Retire la tablette portant ce serial (une seule). Renvoie true si retirée.
function Inv.RemoveBySerial(src, serial)
    if Inv.Direct() then
        for _, it in ipairs(Inv.List(src)) do
            if it.metadata.serial == serial then return exports.pop_inventory:removeItemById(src, it.id) == true end
        end
        return false
    end
    return Bridge.RemoveItem(src, Config.Item, 1, { serial = serial }) == true
end
