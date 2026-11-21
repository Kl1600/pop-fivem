Police = Police or {}

Police.STATE_CUFFED = 'cuffed'         -- statebag joueur : true | nil (écrit par le serveur uniquement)
Police.STATE_ESCORT = 'popEscortedBy'  -- statebag joueur : server id de l'agent qui escorte | nil
Police.STATE_DUTY   = 'popPoliceDuty'  -- statebag joueur : true | nil (agent en service)

Police.TARGET_DISTANCE  = 2.5   -- client : joueur le plus proche pour le menu
Police.ACTION_DISTANCE  = 3.5   -- serveur : agent <-> cible (marge de latence comprise)
Police.VEHICLE_DISTANCE = 5.0   -- client : véhicule le plus proche
Police.VEHICLE_SERVER_DISTANCE = 7.0 -- serveur : centre du véhicule <-> agent et <-> cible
Police.STATION_DISTANCE = 2.0   -- client : options des points ; serveur : + 1.0
Police.ACTION_COOLDOWN  = 750   -- ms entre deux actions d'un même agent (serveur)
Police.FINE_COOLDOWN    = 10    -- s entre deux amendes d'un même agent (serveur)
Police.REASON_MIN, Police.REASON_MAX = 3, 100  -- motif d'amende (caractères)
Police.NOTE_MIN, Police.NOTE_MAX     = 3, 500  -- note de casier
Police.QUERY_MAX    = 50        -- recherche casier
Police.RESULTS_MAX  = 10        -- résultats de recherche
Police.HISTORY_MAX  = 50        -- notes et amendes affichées par fiche (les plus récentes)
Police.ESCORT_OFFSET = vec3(0.45, 0.45, 0.0) -- client : position de la personne escortée par rapport à l'agent

-- Sanitize on both sides so the fine selector reflects the server's valid options.
local function fallback(key, value)
    if IsDuplicityVersion() then print(('[pop_police] Invalid config: %s'):format(key)) end
    return value
end

local fines = Config.Fines
if math.type(fines.min) ~= 'integer' or fines.min < 1 or fines.min > 4294967295 then
    fines.min = fallback('Fines.min', 50)
end
if math.type(fines.max) ~= 'integer' or fines.max < fines.min or fines.max > 4294967295 then
    fines.max = fallback('Fines.max', math.max(fines.min, 10000))
end
if fines.account ~= 'cash' and fines.account ~= 'bank' then fines.account = fallback('Fines.account', 'bank') end
if math.type(fines.timeout) ~= 'integer' or fines.timeout < 10 or fines.timeout > 120 then
    fines.timeout = fallback('Fines.timeout', 30)
end

Police.fineAmounts = {}
for _, amount in ipairs(type(fines.amounts) == 'table' and fines.amounts or {}) do
    if math.type(amount) == 'integer' and amount >= fines.min and amount <= fines.max then
        Police.fineAmounts[#Police.fineAmounts + 1] = amount
    end
end
if #Police.fineAmounts == 0 then Police.fineAmounts[1] = fallback('Fines.amounts', fines.min) end
if Config.Theme ~= 'modern' and Config.Theme ~= 'retro80' then Config.Theme = fallback('Theme', 'modern') end
