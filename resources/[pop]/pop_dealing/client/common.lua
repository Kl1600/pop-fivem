-- ─────────────────────────────────────────────
-- pop_dealing - état et helpers communs du client (chargé en premier, voir fxmanifest)
-- ─────────────────────────────────────────────

Dealing = {}

Dealing.customers    = {}  -- [id] = { data, ped, state, uiId, ... }
Dealing.currentOffer = nil -- { id, drugLabel, ... }

-- États du PNJ
Dealing.STATE_IDLE     = 'idle'      -- vient de spawn, pas encore vu le joueur
Dealing.STATE_APPROACH = 'approach'  -- marche vers le joueur
Dealing.STATE_WAITING  = 'waiting'   -- arrivé face au joueur, attend l'interaction
Dealing.STATE_NEGO     = 'nego'      -- en discussion (menu ouvert)
Dealing.STATE_LEAVING  = 'leaving'   -- s'en va

--- Notification au style d'origine (pop_notify : titre, icône, badge).
function Dealing.notify(data)
    Bridge.Notify(data)
end

function Dealing.loadModel(modelName)
    local hash = type(modelName) == 'string' and GetHashKey(modelName) or modelName
    lib.requestModel(hash)
    return hash
end

function Dealing.isPlayerInAnyZone()
    local pc = GetEntityCoords(cache.ped)
    for _, z in ipairs(Config.Zones) do
        if #(pc - vec3(z.center.x, z.center.y, z.center.z)) <= z.radius then
            return true
        end
    end
    return false
end
