-- Fonctions communes du serveur pop_weed (chargé en premier, voir fxmanifest).

Weed = {}

Weed.plants = {}  -- [plantId] = plante
Weed.nextId = 1
Weed.dirty  = false

local dataPath = GetResourcePath(GetCurrentResourceName()) .. '/data/plants.json'

local ICON = 'fas fa-info'

--- Notification au style d'origine (icône info, sans titre).
function Weed.Notify(src, message, duration)
    Bridge.Notify(src, { icon = ICON, message = message, duration = duration })
end

-- Propriétaire d'une plante : license Cfx (et non l'identifier ESX) pour garder
-- la limite de plantes des plantes déjà enregistrées dans data/plants.json.
function Weed.OwnerOf(src)
    return GetPlayerIdentifierByType(src, 'license') or ('src:' .. src)
end

-- ─────────────────────────────────────────────
-- Persistence (data/plants.json)
-- ─────────────────────────────────────────────

function Weed.Save()
    Weed.dirty = false
    local list = {}
    for _, p in pairs(Weed.plants) do list[#list + 1] = p end
    local f = io.open(dataPath, 'w')
    if not f then
        if Config.Debug then print(L('log_save_failed')) end
        return
    end
    f:write(json.encode(list))
    f:close()
end

function Weed.Load()
    local f = io.open(dataPath, 'r')
    if not f then return end
    local raw = f:read('*all')
    f:close()
    if not raw or raw == '' then return end
    local data = json.decode(raw)
    if not data then return end
    local count = 0
    for _, plant in pairs(data) do
        if type(plant) ~= 'table' or not plant.id then goto skip end
        if not plant.wateredAt then plant.wateredAt = plant.plantedAt end
        -- Anciennes plantes (sans compteur de croissance) : on garde leur avancée actuelle
        if not plant.growth then
            plant.growth   = math.max(0, math.min(os.time() - plant.plantedAt, Config.TotalDuration))
            plant.lastTick = os.time()
        end
        Weed.plants[plant.id] = plant
        if plant.id >= Weed.nextId then Weed.nextId = plant.id + 1 end
        count = count + 1
        ::skip::
    end
    if Config.Debug then print(L('log_loaded', count)) end
end

-- ─────────────────────────────────────────────
-- Croissance
-- ─────────────────────────────────────────────

-- Croissance réelle : le temps ne compte que tant que la plante a de l'eau
function Weed.UpdateGrowth(plant, now)
    local last  = plant.lastTick or plant.plantedAt
    local dryAt = (plant.wateredAt or plant.plantedAt) + Config.WaterDuration
    local stop  = math.min(now, dryAt)
    if stop > last then plant.growth = (plant.growth or 0) + (stop - last) end
    plant.lastTick = now
end

-- Copie envoyée aux clients (sans l'identifiant du propriétaire)
function Weed.ClientView(plant)
    local v = {}
    for k, val in pairs(plant) do
        if k ~= 'owner' then v[k] = val end
    end
    return v
end

function Weed.ComputeStage(plant)
    local elapsed = plant.growth or 0
    local stage   = 1
    for i, s in ipairs(Config.Stages) do
        if elapsed >= s.minTime then stage = i end
    end
    return stage
end
