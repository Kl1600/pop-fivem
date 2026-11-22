-- Guidage du joueur : checklist persistante pop_notify, un point GPS avec itinéraire vers
-- la prochaine destination, et une notification courte à chaque étape.
-- Ordre réel de la mission : showroom → Thornton → courant → clés + garage → piratage → livraison → fin.

Guide = {}

local STEPS = { 'guide_step1', 'guide_step2', 'guide_step3', 'guide_step4', 'guide_step5', 'guide_step6', 'guide_step7' }
local shown = false
local current = 0
local routeBlip = nil

-- ---------- Checklist ----------
function Guide.Show()
    TriggerEvent('notification:client:checklist', { type = 'show', visible = false })
    TriggerEvent('notification:client:checklist', { type = 'show', visible = true, title = L('guide_title') })
    for i, key in ipairs(STEPS) do
        TriggerEvent('notification:client:checklist', { type = 'step', step = i, label = L(key), done = false })
    end
    shown, current = true, 0
end

-- Coche toutes les étapes jusqu'à n (incluse)
function Guide.Done(n)
    if not shown then Guide.Show() end
    for i = current + 1, math.min(n, #STEPS) do
        TriggerEvent('notification:client:checklist', { type = 'step', step = i, label = L(STEPS[i]), done = true })
    end
    if n > current then current = n end
    Debug(('guide : étape %d terminée'):format(n))
end

function Guide.Hide()
    if shown then TriggerEvent('notification:client:checklist', { type = 'show', visible = false }) end
    shown, current = false, 0
end

-- ---------- Itinéraire ----------
function Guide.ClearRoute()
    if routeBlip and DoesBlipExist(routeBlip) then
        SetBlipRoute(routeBlip, false)
        RemoveBlip(routeBlip)
    end
    routeBlip = nil
end

-- Point jaune + itinéraire vers des coordonnées (remplace le précédent)
function Guide.Route(coords, labelKey, sprite)
    Guide.ClearRoute()
    if not coords then return end
    routeBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(routeBlip, sprite or 1)
    SetBlipColour(routeBlip, 5)
    SetBlipScale(routeBlip, 0.8)
    SetBlipAsShortRange(routeBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(L(labelKey))
    EndTextCommandSetBlipName(routeBlip)
    SetBlipRoute(routeBlip, true)
    SetBlipRouteColour(routeBlip, 5)
end

-- Itinéraire vers une entité (ex. camion de livraison)
function Guide.RouteEntity(entity, labelKey, sprite)
    Guide.ClearRoute()
    if not entity or not DoesEntityExist(entity) then return end
    routeBlip = AddBlipForEntity(entity)
    SetBlipSprite(routeBlip, sprite or 1)
    SetBlipColour(routeBlip, 5)
    SetBlipScale(routeBlip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(L(labelKey))
    EndTextCommandSetBlipName(routeBlip)
    SetBlipRoute(routeBlip, true)
    SetBlipRouteColour(routeBlip, 5)
end

-- Voiture du showroom la plus proche qui n'est pas encore piratée
local function NearestCarToHack()
    local p = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, math.huge
    for _, car in ipairs(Cars) do
        if not (PCB and PCB.Completed[car.plate]) then
            local d = #(p - vector3(car.pos.x, car.pos.y, car.pos.z))
            if d < bestDist then best, bestDist = car, d end
        end
    end
    return best and vector3(best.pos.x, best.pos.y, best.pos.z) or nil
end

-- ---------- Étapes ----------
-- 1. Rejoindre le showroom (l'itinéraire est géré par sync.lua)
AddEventHandler('mission:client:pending', function()
    if not shown then Guide.Show() end
end)

-- 2. Suivre M. Duggan
AddEventHandler('startheist', function()
    if not shown then Guide.Show() end
    Guide.Done(1)
    Guide.Route(Config.Positions.ThorntonStart, 'blip_thornton', 280)
    MissionNotify(L('guide_thornton'), 7000)
end)

-- 3. Couper le courant (Thornton parti : panneau électrique)
AddEventHandler('mission:setupBlips', function()
    if not IsCoopActive() or current >= 2 then return end
    Guide.Done(2)
    Guide.Route(Config.Positions.Panel, 'blip_panel', 354)
    MissionNotify(L('guide_panel'), 7000)
end)

-- 4. Clés puis porte du garage
AddEventHandler('mission:local:guide', function(stage)
    if not IsCoopActive() then return end
    if stage == 'power' and current < 3 then
        Guide.Done(3)
        Guide.Route(Config.Positions.Keys, 'blip_keys', 134)
        MissionNotify(L('guide_keys'), 7000)
    elseif stage == 'keys' and current < 4 then
        Guide.Done(3)
        Guide.Route(Config.Positions.GarageDoor, 'blip_garage', 357)
        MissionNotify(L('guide_door'), 7000)
    elseif stage == 'door' and current < 4 then
        Guide.Done(4)
        Guide.Route(NearestCarToHack(), 'blip_car', 225)
        MissionNotify(L('guide_car'), 7000)
    elseif stage == 'hacked' and current < 5 then
        -- 6. Livrer au camion (l'itinéraire vers la zone de livraison est posé par 'ondeliveryblip')
        Guide.Done(5)
    elseif stage == 'truck' then
        -- camion apparu : itinéraire vers le camion (fait dans delivery.lua)
        Guide.Done(5)
    elseif stage == 'delivered' then
        Guide.Done(6)
        Guide.ClearRoute()
    end
end)

AddEventHandler('mission:keysBlipOn', function() TriggerEvent('mission:local:guide', 'power') end)
AddEventHandler('mission:setKeysTaken', function() TriggerEvent('mission:local:guide', 'keys') end)
AddEventHandler('mission:setDoorOpened', function() TriggerEvent('mission:local:guide', 'door') end)

-- Un coéquipier a piraté une voiture : les autres sont aussi guidés vers la livraison
RegisterNetEvent('mission:client:hackState')
AddEventHandler('mission:client:hackState', function(_, completed)
    if completed == true and IsCoopActive() and current < 5 then
        TriggerEvent('mission:local:guide', 'hacked')
        -- Le pirate / conducteur a déjà son itinéraire de livraison ('ondeliveryblip')
        if not deliveryStarted then Guide.Route(Config.DeliveryPos, 'blip_delivery', 1) end
    end
end)

RegisterNetEvent('mission:client:carDelivered')
AddEventHandler('mission:client:carDelivered', function()
    TriggerEvent('mission:local:guide', 'delivered')
end)

-- 7. Fin : tout coché, puis la checklist disparaît ; échec / reset : disparaît tout de suite
AddEventHandler('mission:local:reset', function(reason)
    Guide.ClearRoute()
    if reason == 'done' and shown then
        Guide.Done(7)
        SetTimeout(6000, function()
            if not IsCoopActive() then Guide.Hide() end
        end)
    else
        Guide.Hide()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Guide.ClearRoute()
    Guide.Hide()
end)
