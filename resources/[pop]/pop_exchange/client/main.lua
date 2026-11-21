-- pop_exchange : client. Blips, PNJ locaux, target, panneau NUI et alerte police.
-- Le client ne décide de rien : il envoie l'index du lieu, l'id de l'offre et le montant au serveur.

local ACTION_DISTANCE = 3.0
local TARGET_DISTANCE = 2.0
local PED_DISTANCE    = 40.0

local isOpen = false
local pending = false    -- attente de getOffers (évite le double clic)
local openLoc = nil      -- index du lieu ouvert
local blips = {}
local alertBlips = {}
local peds = {}          -- [i] = { ped, target }
local zones = {}         -- ids de zones (lieux sans PNJ)
local ready = false

------------------------------------------------------------------------
-- Panneau
------------------------------------------------------------------------

local function close()
    if not isOpen then return end
    isOpen = false
    openLoc = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'pop_exchange:close' })
end

-- Surveillance pendant l'ouverture : éloignement ou mort → fermeture.
local function watch(i)
    local center = Config.Locations[i].coords.xyz
    CreateThread(function()
        while isOpen and openLoc == i do
            local ped = PlayerPedId()
            if IsEntityDead(ped) or #(GetEntityCoords(ped) - center) > ACTION_DISTANCE then
                close()
                break
            end
            Wait(500)
        end
    end)
end

local function open(i)
    if isOpen or pending or Bridge.IsBusy() then return end
    pending = true
    local ok, reason, arg, offers = Callback.Await('pop_exchange:getOffers', i)
    pending = false
    if not ok then
        Bridge.Notify(L(reason or 'error', arg), 'error')
        return
    end
    isOpen = true
    openLoc = i
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'pop_exchange:open', offers = offers or {} })
    watch(i)
end

local function translate(reason, arg)
    return L(reason or 'error', table.unpack(type(arg) == 'table' and arg or { arg }))
end

RegisterNUICallback('pop_exchange:exchange', function(data, cb)
    if not isOpen or not openLoc then
        cb({ ok = false, message = L('error') })
        return
    end
    data = type(data) == 'table' and data or {}
    local amount = math.floor(tonumber(data.amount) or 0)
    local ok, reason, arg, offers = Callback.Await('pop_exchange:exchange', openLoc, tostring(data.id or ''), amount)
    cb({ ok = ok == true, message = translate(reason, arg), offers = offers })
end)

-- Échap / bouton fermer : le bridge a déjà rendu le focus.
Bridge.OnUiClose(function()
    if isOpen then close() end
end)

exports('IsOpen', function() return isOpen end)

------------------------------------------------------------------------
-- Interaction
------------------------------------------------------------------------

local function options(i)
    return {
        {
            label = L('target_talk'),
            icon = 'fa-solid fa-money-bill-transfer',
            distance = TARGET_DISTANCE,
            canInteract = function() return not isOpen and not pending end,
            onSelect = function() open(i) end,
        },
    }
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(50)
    end
    return hash
end

local function spawnPed(i, loc)
    local hash = loadModel(loc.ped)
    if not hash then return end
    local c = loc.coords
    local ped = CreatePed(4, hash, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetModelAsNoLongerNeeded(hash)
    if ped == 0 then return end
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    peds[i] = { ped = ped, target = Bridge.Target.AddLocalEntity(ped, options(i)) }
end

local function deletePed(i)
    local p = peds[i]
    if not p then return end
    if p.target then Bridge.Target.Remove(p.target) end
    if DoesEntityExist(p.ped) then DeleteEntity(p.ped) end
    peds[i] = nil
end

local function setup()
    if ready then return end
    ready = true

    local withPed = {}
    for i, loc in ipairs(Config.Locations) do
        if loc.ped then
            withPed[#withPed + 1] = i
        else
            zones[#zones + 1] = Bridge.Target.AddBoxZone('pop_exchange_' .. i, loc.coords.xyz,
                vec3(1.5, 1.5, 2.0), loc.coords.w, options(i))
        end
    end
    if #withPed == 0 then return end

    -- Une seule boucle pour tous les PNJ : apparition / suppression selon la distance.
    CreateThread(function()
        while ready do
            local pos = GetEntityCoords(PlayerPedId())
            local nearest = math.huge
            for _, i in ipairs(withPed) do
                local dist = #(pos - Config.Locations[i].coords.xyz)
                if dist < nearest then nearest = dist end
                if dist < PED_DISTANCE then
                    if not peds[i] or not DoesEntityExist(peds[i].ped) then
                        deletePed(i)
                        spawnPed(i, Config.Locations[i])
                    end
                elseif peds[i] then
                    deletePed(i)
                end
            end
            Wait(nearest < PED_DISTANCE and 1000 or 2500)
        end
    end)
end

Bridge.OnPlayerLoaded(setup)

-- Blips de la carte.
CreateThread(function()
    for _, loc in ipairs(Config.Locations) do
        if loc.blip then
            local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
            SetBlipSprite(blip, Config.Blip.sprite)
            SetBlipColour(blip, Config.Blip.color)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(L('blip_name'))
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end
    end
end)

------------------------------------------------------------------------
-- Alerte police (envoyée par le serveur aux policiers en service)
------------------------------------------------------------------------

RegisterNetEvent('pop_exchange:client:policeAlert', function(coords)
    if type(coords) ~= 'table' or not tonumber(coords.x) or not tonumber(coords.y) then return end
    Bridge.Notify(L('police_alert'), 'warning')
    local blip = AddBlipForCoord(coords.x + 0.0, coords.y + 0.0, (tonumber(coords.z) or 0) + 0.0)
    SetBlipSprite(blip, 500)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.0)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(L('police_blip'))
    EndTextCommandSetBlipName(blip)
    alertBlips[blip] = true
    SetTimeout((tonumber(Config.Police.blipTime) or 60) * 1000, function()
        if alertBlips[blip] then
            alertBlips[blip] = nil
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
    end)
end)

------------------------------------------------------------------------
-- Arrêt
------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    close()
    ready = false
    for i in pairs(peds) do deletePed(i) end
    for _, id in ipairs(zones) do Bridge.Target.Remove(id) end
    zones = {}
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    blips = {}
    for blip in pairs(alertBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    alertBlips = {}
end)
