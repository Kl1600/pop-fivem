local ESX = exports['es_extended']:getSharedObject()
local spawnedPeds = {} -- [i] = { ped = , uiId = , loc = }
local isMenuOpen = false
local activePed = nil
local OpenExchangeMenu

-- Modèle de secours garanti valide si Config.PedModel ne charge pas
local FALLBACK_MODEL = 'a_m_y_business_01'
local INTERACT_DIST  = 2.0
local DRAW_DIST      = 8.0

-- ─────────────────────────────────────────────
-- Chargement de modèle (avec timeout)
-- ─────────────────────────────────────────────
local function loadModel(modelName, timeoutMs)
    local hash = type(modelName) == 'number' and modelName or GetHashKey(modelName)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        return nil
    end
    RequestModel(hash)
    local elapsed = 0
    while not HasModelLoaded(hash) do
        Wait(10)
        elapsed = elapsed + 10
        if elapsed >= (timeoutMs or 5000) then
            return nil
        end
    end
    return hash
end

-- ─────────────────────────────────────────────
-- Caméra braquée sur le vendeur (focus + DOF) façon pop_dealing
-- ─────────────────────────────────────────────
local exCam        = nil
local exCamPed     = nil
local camThread    = false

local CAM_OFFSET = 1.4
local CAM_SIDE   = 0.55
local CAM_HEIGHT = 0.55

local function aimCam(ped)
    if not DoesEntityExist(ped) or not DoesCamExist(exCam) then return end
    local pedCoords = GetEntityCoords(ped)
    local pedHead   = GetEntityHeading(ped)
    local rad       = math.rad(pedHead)

    local fwdX = -math.sin(rad)
    local fwdY =  math.cos(rad)
    local rightRad = math.rad(pedHead - 90.0)
    local rgtX = -math.sin(rightRad)
    local rgtY =  math.cos(rightRad)

    local cx = pedCoords.x + fwdX * CAM_OFFSET + rgtX * CAM_SIDE
    local cy = pedCoords.y + fwdY * CAM_OFFSET + rgtY * CAM_SIDE
    local cz = pedCoords.z + CAM_HEIGHT

    SetCamCoord(exCam, cx, cy, cz)
    PointCamAtCoord(exCam, pedCoords.x, pedCoords.y, pedCoords.z + CAM_HEIGHT - 0.05)
end

local function startCam(ped)
    if not DoesEntityExist(ped) then return end
    if exCam and DoesCamExist(exCam) then
        DestroyCam(exCam, false)
    end

    exCam    = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    exCamPed = ped
    SetCamFov(exCam, 32.0)
    SetCamActive(exCam, true)

    SetCamUseShallowDofMode(exCam, true)
    SetCamNearDof(exCam, 0.6)
    SetCamFarDof(exCam, CAM_OFFSET + 0.5)
    SetCamDofStrength(exCam, 0.8)

    aimCam(ped)
    RenderScriptCams(true, true, 400, true, true)

    camThread = true
    CreateThread(function()
        while camThread and DoesCamExist(exCam) do
            SetUseHiDof()
            if exCamPed and DoesEntityExist(exCamPed) then
                aimCam(exCamPed)
            end
            Wait(0)
        end
    end)
end

local function stopCam()
    camThread = false
    if exCam and DoesCamExist(exCam) then
        RenderScriptCams(false, true, 400, true, true)
        DestroyCam(exCam, false)
    end
    exCam    = nil
    exCamPed = nil
end

-- ─────────────────────────────────────────────
-- Blips
-- ─────────────────────────────────────────────
local function createBlips()
    for _, loc in ipairs(Config.Locations) do
        if loc.blip and loc.blip.enabled then
            local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
            SetBlipSprite(blip, loc.blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, loc.blip.scale)
            SetBlipColour(blip, loc.blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(loc.blip.label or 'Bureau de Change')
            EndTextCommandSetBlipName(blip)
        end
    end
end

-- ─────────────────────────────────────────────
-- Spawn d'un ped + prompt pop_v3dui
-- ─────────────────────────────────────────────
local function spawnPed(i, loc)
    local hash = loadModel(Config.PedModel, 5000)
    if not hash then
        print(('[pop_exchange] Modele "%s" introuvable, modele de secours utilise.'):format(tostring(Config.PedModel)))
        hash = loadModel(FALLBACK_MODEL, 5000)
    end
    if not hash then
        print('[pop_exchange] ERREUR: impossible de charger un modele de ped.')
        return
    end

    local ped = CreatePed(4, hash, loc.coords.x, loc.coords.y, loc.coords.z - 1.0, loc.heading or 0.0, false, true)

    local found, groundZ = GetGroundZFor_3dCoord(loc.coords.x, loc.coords.y, loc.coords.z, false)
    if found then
        SetEntityCoordsNoOffset(ped, loc.coords.x, loc.coords.y, groundZ, false, false, false)
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, true, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    SetModelAsNoLongerNeeded(hash)

    -- Prompt pop_v3dui au-dessus du PNJ
    local uiId = exports.pop_v3dui:Create({
        coords       = GetEntityCoords(ped),
        type         = 'prompt',
        content      = {
            key   = 'E',
            label = Config.Translate.target_label or 'Parler au changeur',
            icon  = 'fas fa-money-bill-transfer',
        },
        drawDistance = DRAW_DIST,
        offset       = vec3(0, 0, 1.0),
    })

    spawnedPeds[i] = { ped = ped, uiId = uiId, loc = loc, coords = GetEntityCoords(ped) }
end

-- ─────────────────────────────────────────────
-- Initialisation
-- ─────────────────────────────────────────────
CreateThread(function()
    while not ESX.IsPlayerLoaded() do
        Wait(250)
    end

    createBlips()
    for i, loc in ipairs(Config.Locations) do
        spawnPed(i, loc)
    end
end)

-- Nettoyage
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        stopCam()
        SetNuiFocus(false, false)
        for _, entry in pairs(spawnedPeds) do
            if entry.uiId then exports.pop_v3dui:Remove(entry.uiId) end
            if DoesEntityExist(entry.ped) then DeleteEntity(entry.ped) end
        end
    end
end)

-- ─────────────────────────────────────────────
-- Détection de proximité + touche E
-- ─────────────────────────────────────────────
CreateThread(function()
    while true do
        local sleep = 1000
        if not isMenuOpen then
            local playerCoords = GetEntityCoords(PlayerPedId())
            for _, entry in pairs(spawnedPeds) do
                if entry.coords then
                    -- PNJ figé : coordonnées mises en cache au spawn.
                    local dist = #(playerCoords - entry.coords)
                    if dist < DRAW_DIST then
                        sleep = 0
                        if dist < INTERACT_DIST and IsControlJustReleased(0, 38) then -- E
                            OpenExchangeMenu(entry.ped)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ─────────────────────────────────────────────
-- Menu NUI
-- ─────────────────────────────────────────────
OpenExchangeMenu = function(ped)
    if isMenuOpen then return end

    ESX.TriggerServerCallback('pop_exchange:getPlayerBalances', function(cashCount, pesosCount)
        isMenuOpen = true
        activePed = ped
        if ped and DoesEntityExist(ped) then
            startCam(ped)
        end
        SetNuiFocus(true, true)
        SendNUIMessage({
            type = 'toggle',
            display = true,
            rates = Config.Rates,
            balances = {
                cash = cashCount,
                pesos = pesosCount
            },
            translate = Config.Translate
        })
    end)
end

RegisterNUICallback('close', function(data, cb)
    isMenuOpen = false
    activePed = nil
    stopCam()
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = 'toggle',
        display = false
    })
    cb('ok')
end)

RegisterNUICallback('exchange', function(data, cb)
    local from = data.from
    local amount = tonumber(data.amount)

    if not amount or amount <= 0 then
        ESX.ShowNotification(Config.Translate.invalid_amount)
        cb({status = 'error', message = Config.Translate.invalid_amount})
        return
    end

    ESX.TriggerServerCallback('pop_exchange:processExchange', function(success, errorMsg, newBalances)
        if success then
            ESX.ShowNotification(Config.Translate.exchange_success)
            cb({status = 'success', balances = newBalances})
        else
            ESX.ShowNotification(errorMsg or Config.Translate.exchange_failed)
            cb({status = 'error', message = errorMsg})
        end
    end, from, amount)
end)
