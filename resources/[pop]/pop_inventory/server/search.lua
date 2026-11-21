-- pop_inventory : fouille d'un joueur mort ou menotté (SPEC §11.2.3, §12).
-- La commande Config.SearchCommand est enregistrée côté client (LOT 3) ; ici, seulement les règles serveur.

Containers = Containers or {}
Containers.Types = Containers.Types or {}
Search = Search or {}

local TOLERANCE = 1.0       -- m : marge serveur (latence)
local SEARCH_DISTANCE = 2.5 -- m : portée de la fouille (serveur : + TOLERANCE)

--- Menotté : QBCore / Qbox PlayerData.metadata.ishandcuffed, ou statebag isCuffed / cuffed / handcuffed.
-- NOTE: les scripts de menottes n'ont pas de standard ; ces clés couvrent les plus courants.
function Search.IsCuffed(src)
    if Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox' then
        local ok, cuffed = pcall(function()
            local p = Bridge.GetPlayer(src)
            local m = p and p.PlayerData and p.PlayerData.metadata
            return m ~= nil and m.ishandcuffed == true
        end)
        if ok and cuffed then return true end
    end
    local ok, cuffed = pcall(function()
        local st = Player(src).state
        return st.isCuffed == true or st.cuffed == true or st.handcuffed == true
    end)
    return ok and cuffed == true
end

--- Mort ou menotté.
function Search.CanBeSearched(target)
    return Bridge.IsDead(target) or Search.IsCuffed(target)
end

Containers.Types.player = {
    open = function(src, request, s)
        local target = request.target
        if math.type(target) ~= 'integer' or target == src then return nil, 'cannot_search' end
        if not s.forced and Config.SearchCommand == false then return nil, 'cannot_search' end
        local tinv = Inventory.Get(target)
        if not tinv or tinv.closing or tinv.type ~= 'player' or not Bridge.GetPlayer(target) then
            return nil, 'cannot_search'
        end
        s.target = target
        return tinv
    end,

    -- Le fouilleur n'est ni mort (vérifié par Containers) ni menotté ; la cible reste fouillable et proche.
    access = function(src, inv, s)
        local target = s.target
        if inv.id ~= target or not Bridge.GetPlayer(target) then return false, 'cannot_search' end
        if s.forced then return true end
        if Config.SearchCommand == false then return false, 'cannot_search' end
        if Search.IsCuffed(src) then return false, 'cannot_now' end
        local tpos = Bridge.GetCoords(target)
        if not tpos or not Bridge.IsNear(src, tpos, SEARCH_DISTANCE + TOLERANCE) then return false, 'too_far' end
        if not Search.CanBeSearched(target) then return false, 'cannot_search' end
        return true
    end,

    view = function(view)
        view.label = L('inv_searched')
    end,

    watch = function(_, _, s)
        return { target = s.target, distance = SEARCH_DISTANCE + 1.0 }
    end,

    opened = function(_, _, s)
        TriggerClientEvent('pop_inventory:client:searched', s.target)
    end,

    -- data = server id.
    forceRequest = function(data)
        local n = tonumber(data)
        local target = n and math.tointeger(n)
        return target and { target = target } or nil
    end,
}
