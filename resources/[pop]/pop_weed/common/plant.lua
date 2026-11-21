-- Logique partagée serveur / client : formules d'une plante, calculées à partir d'horodatages serveur.
-- Fonctions pures (aucune native, aucun effet de bord sauf Plant.Settle). `now` = secondes serveur
-- (serveur : os.time(), client : ServerNow()).

Plant = {}

Plant.ACTION_DISTANCE = 3.0   -- serveur : Bridge.IsNear pour planter / arroser / engrais / récolter / détruire
Plant.TARGET_DISTANCE = 1.8   -- client : distance des options de target
Plant.INFO_DISTANCE   = 2.0   -- client : affichage de la carte d'info
Plant.PLACE_FORWARD   = 1.0   -- client : distance de l'aperçu devant le joueur
Plant.THIRSTY_BELOW   = 90    -- arrosage possible seulement si eau < 90 %

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

--- Croissance de 0.0 à 1.0.
function Plant.Progress(p, now)
    return clamp((now - p.plantedAt) / Config.GrowTime, 0, 1)
end

--- Vrai quand la croissance atteint 100 %.
function Plant.IsReady(p, now)
    return Plant.Progress(p, now) >= 1.0
end

--- Stade visuel, de 1 à #Config.Stages.
function Plant.Stage(p, now)
    return math.min(#Config.Stages, math.floor(Plant.Progress(p, now) * #Config.Stages) + 1)
end

--- Niveau d'eau actuel (0.0-100.0).
function Plant.Water(p, now)
    return math.max(0, p.water - (now - p.waterAt) * 100 / Config.WaterDuration)
end

-- Temps passé à sec : seulement pendant la croissance (jusqu'à plantedAt + GrowTime).
function Plant.DrySeconds(p, now)
    local emptyAt = p.waterAt + p.water * Config.WaterDuration / 100
    local endAt = math.min(now, p.plantedAt + Config.GrowTime)
    return p.dry + math.max(0, endAt - math.max(emptyAt, p.waterAt))
end

--- Qualité entière 0-100.
function Plant.Quality(p, now)
    local Q = Config.Quality
    local q = Q.base + (p.fertilized and Q.fertilizer or 0) - Plant.DrySeconds(p, now) / Config.GrowTime * Q.dryPenalty
    return clamp(math.floor(q + 0.5), 0, 100)
end

--- Quantité récoltée pour une qualité donnée.
function Plant.HarvestAmount(quality)
    return Config.Harvest.min + math.floor((Config.Harvest.max - Config.Harvest.min) * quality / 100)
end

--- Serveur : fige le temps à sec et le niveau d'eau à `now` avant de modifier la plante.
function Plant.Settle(p, now)
    p.dry = math.floor(Plant.DrySeconds(p, now))
    p.water = Plant.Water(p, now)
    p.waterAt = now
    return p
end
