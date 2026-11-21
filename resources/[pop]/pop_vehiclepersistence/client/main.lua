-- pop_vehiclepersistence : client
-- Détecte la prise / la sortie du volant et envoie les propriétés visuelles au serveur.
-- Applique les propriétés posées par le serveur (statebag) quand ce client est le propriétaire réseau.
-- Aucun texte, aucune notification, aucune entité créée, aucun Wait(0).

local ENTER_DELAY = 3000 -- ms au volant avant le premier envoi
local APPLY_WAIT = 3000  -- ms max d'attente de l'entité / de la propriété réseau

local STATE_PROPS = 'pop_vehiclepersistence_props'
local CB_UPDATE = 'pop_vehiclepersistence:update'
local CB_APPLIED = 'pop_vehiclepersistence:applied'

local WAIT_ON_FOOT = 1500
local WAIT_IN_VEHICLE = 1000
local APPLY_STEP = 100
local GROUND_WAIT = 5000 -- ms max d'attente des collisions avant de poser le véhicule au sol

local tracked = nil   -- véhicule conduit actuellement suivi
local enteredAt = 0   -- GetGameTimer() de la prise du volant
local sent = false    -- premier envoi déjà fait pour ce trajet
local running = true

local function noop() end

local function isTemporary(veh)
    local state = Entity(veh).state
    return state and state.pop_temporary == true
end

-- Envoie les propriétés du véhicule au serveur (le serveur décide de tout).
local function sendUpdate(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if not NetworkGetEntityIsNetworked(veh) or isTemporary(veh) then return end
    local props = Props.Get(veh)
    if type(props) ~= 'table' then return end
    Callback.Trigger(CB_UPDATE, noop, VehToNet(veh), props)
end

-- Renvoie le véhicule réseau dont le joueur est conducteur vivant, sinon nil.
local function getDrivenVehicle(ped)
    if IsEntityDead(ped) or not IsPedInAnyVehicle(ped, false) then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    if not NetworkGetEntityIsNetworked(veh) then return nil end
    return veh
end

local function forget()
    tracked = nil
    enteredAt = 0
    sent = false
end

-- Boucle unique : 1500 ms à pied, 1000 ms en véhicule.
CreateThread(function()
    while running do
        local ped = PlayerPedId()
        local veh = getDrivenVehicle(ped)

        if tracked and veh ~= tracked then
            -- Sortie, changement de place, mort ou changement de véhicule.
            sendUpdate(tracked)
            forget()
        end

        if veh and not tracked then
            tracked = veh
            enteredAt = GetGameTimer()
            sent = false
        end

        if tracked and not sent and GetGameTimer() - enteredAt >= ENTER_DELAY then
            sent = true
            sendUpdate(tracked)
        end

        Wait(tracked and WAIT_IN_VEHICLE or WAIT_ON_FOOT)
    end
end)

-- Applique les props, attend le décor autour du véhicule, le pose au sol puis le dégèle (gelé à la création).
local function apply(veh, value)
    Props.Set(veh, value)
    local deadline = GetGameTimer() + GROUND_WAIT
    while running and DoesEntityExist(veh) and not HasCollisionLoadedAroundEntity(veh) and GetGameTimer() < deadline do
        RequestCollisionAtCoord(GetEntityCoords(veh))
        Wait(APPLY_STEP)
    end
    if not DoesEntityExist(veh) then return end
    SetVehicleOnGroundProperly(veh)
    FreezeEntityPosition(veh, false)
    Callback.Trigger(CB_APPLIED, noop, VehToNet(veh))
end

local applying = {} -- [bagName] = true pendant qu'un thread attend / applique

-- Application des propriétés posées par le serveur juste après la création.
-- On sonde jusqu'à APPLY_WAIT : la propriété réseau peut arriver ou migrer vers ce client entre-temps.
AddStateBagChangeHandler(STATE_PROPS, nil, function(bagName, _, value)
    if type(value) ~= 'table' or applying[bagName] then return end
    applying[bagName] = true
    CreateThread(function()
        local deadline = GetGameTimer() + APPLY_WAIT
        while running and GetGameTimer() < deadline do
            local veh = GetEntityFromStateBagName(bagName)
            if veh ~= 0 and DoesEntityExist(veh) then
                -- Déjà appliqué par un autre client entre-temps : rien à faire.
                if type(Entity(veh).state[STATE_PROPS]) ~= 'table' then break end
                if NetworkGetEntityOwner(veh) == PlayerId() then
                    apply(veh, value)
                    break
                end
            end
            Wait(APPLY_STEP)
        end
        applying[bagName] = nil
    end)
end)

-- Arrêt : stoppe la boucle (aucune entité, zone, blip ni focus NUI à nettoyer).
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    running = false
    forget()
end)
