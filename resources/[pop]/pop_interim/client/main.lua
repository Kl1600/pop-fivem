-- pop_interim : client. Blips, PNJ locaux, target, panneau NUI.
-- Le client ne décide de rien : il envoie un index de lieu et un id, le serveur valide.

local TARGET_DISTANCE = 2.0
local PED_DISTANCE = 40.0
local CLOSE_DISTANCE = 3.0

local blips = {}
local peds = {}    -- [i] = { entity, target }
local zones = {}   -- [i] = id de target
local isOpen = false
local session = 0
local openLoc = nil
local pending = false

------------------------------------------------------------------------
-- Panneau
------------------------------------------------------------------------

local function close()
    if not isOpen then return end
    isOpen, openLoc = false, nil
    session = session + 1
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'pop_interim:close' })
end

local function fail(reason, arg)
    Bridge.Notify(L(reason or 'error', arg), 'error')
end

local function watch(loc, activeSession)
    CreateThread(function()
        local coords = Config.Locations[loc].coords.xyz
        while isOpen and session == activeSession do
            local ped = PlayerPedId()
            if #(GetEntityCoords(ped) - coords) > CLOSE_DISTANCE or IsEntityDead(ped) then
                close()
                break
            end
            Wait(500)
        end
    end)
end

local function open(loc)
    if isOpen or pending or Bridge.IsBusy() then return end
    pending = true
    local ok, reason, arg, jobs, current, cooldown = Callback.Await('pop_interim:getJobs', loc)
    pending = false
    if not ok then return fail(reason, arg) end
    if isOpen then return end

    isOpen, openLoc = true, loc
    session = session + 1
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'pop_interim:open',
        jobs = jobs or {},
        current = current or { label = '', unemployed = true },
        cooldown = cooldown or 0,
    })
    watch(loc, session)
end

-- Échap ou bouton Fermer : le bridge a déjà rendu le focus.
Bridge.OnUiClose(close)

-- Appelle le serveur ; succès : fermeture, échec : notification et panneau laissé ouvert.
local function request(name, ...)
    if not isOpen then return false end
    local activeSession = session
    local ok, reason, arg = Callback.Await(name, openLoc, ...)
    if session ~= activeSession then return false end
    if ok then
        close()
        return true
    end
    fail(reason, arg)
    return false
end

RegisterNUICallback('pop_interim:select', function(data, cb)
    local id = type(data) == 'table' and data.id
    if type(id) ~= 'string' then return cb({ ok = false }) end
    cb({ ok = request('pop_interim:selectJob', id) })
end)

RegisterNUICallback('pop_interim:resign', function(_, cb)
    cb({ ok = request('pop_interim:resign') })
end)

------------------------------------------------------------------------
-- Lieux : blips, zones, PNJ
------------------------------------------------------------------------

local function options(i)
    return {
        {
            label = L('target_open'),
            icon = 'fa-solid fa-briefcase',
            distance = TARGET_DISTANCE,
            onSelect = function()
                CreateThread(function() open(i) end)
            end,
        },
    }
end

local function spawnPed(i, loc)
    local hash = joaat(loc.ped)
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then
            SetModelAsNoLongerNeeded(hash)
            return
        end
        Wait(50)
    end
    local c = loc.coords
    local ped = CreatePed(4, hash, c.x, c.y, c.z - 1.0, c.w, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return end
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    peds[i] = { entity = ped, target = Bridge.Target.AddLocalEntity(ped, options(i)) }
end

local function removePed(i)
    local p = peds[i]
    if not p then return end
    if p.target then Bridge.Target.Remove(p.target) end
    if DoesEntityExist(p.entity) then DeleteEntity(p.entity) end
    peds[i] = nil
end

CreateThread(function()
    for i, loc in ipairs(Config.Locations) do
        if loc.blip then
            local c = loc.coords
            local blip = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(blip, Config.Blip.sprite)
            SetBlipColour(blip, Config.Blip.color)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(L('blip_name'))
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end
        if not loc.ped then
            zones[i] = Bridge.Target.AddBoxZone('pop_interim_' .. i, loc.coords.xyz, vec3(1.5, 1.5, 2.0), loc.coords.w, options(i))
        end
    end

    -- Boucle unique et adaptative pour les PNJ locaux.
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local nearest = math.huge
        for i, loc in ipairs(Config.Locations) do
            if loc.ped then
                local dist = #(pos - loc.coords.xyz)
                if dist < nearest then nearest = dist end
                if dist <= PED_DISTANCE and not peds[i] then
                    spawnPed(i, loc)
                elseif dist > PED_DISTANCE + 10.0 and peds[i] then
                    removePed(i)
                end
            end
        end
        Wait(nearest < PED_DISTANCE and 1000 or 2500)
    end
end)

------------------------------------------------------------------------
-- Export et nettoyage
------------------------------------------------------------------------

exports('IsOpen', function() return isOpen end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for i in pairs(peds) do removePed(i) end
    for _, id in pairs(zones) do Bridge.Target.Remove(id) end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    if isOpen then close() end
end)
