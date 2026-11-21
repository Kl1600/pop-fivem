-- ─────────────────────────────────────────────
-- pop_territories - client
-- Loadbar de progression du crew (dans la zone) + indicateur de contrôle au survol carte
-- ─────────────────────────────────────────────

local ESX = exports['es_extended']:getSharedObject()

local control     = {}    -- [zoneId] = payload de contrôle (diffusé par le serveur)
local myProgress  = {}    -- [zoneId] = { share, threshold, color, controlled }
local playerZone  = nil   -- zone de vente où le joueur se trouve physiquement

-- ─────────────────────────────────────────────
-- Synchro serveur
-- ─────────────────────────────────────────────

-- Cercles des territoires sur la carte (remplacent les zones MapZones)
local zoneBlips = {}   -- [zoneId] = blip

-- Couleurs de blip GTA les plus courantes, pour approcher la couleur RGB d'un crew
local BLIP_PALETTE = {
    { 1,  224, 50, 50 },   { 2,  114, 204, 114 }, { 3,  93, 182, 229 },
    { 4,  240, 240, 240 }, { 5,  238, 198, 78 },  { 17, 234, 142, 80 },
    { 27, 171, 60, 230 },  { 38, 44, 109, 184 },  { 40, 75, 75, 75 },
    { 46, 236, 240, 41 },  { 52, 101, 185, 54 },  { 59, 157, 38, 38 },
}

local function nearestBlipColour(rgb)
    local best, bestD = 1, math.huge
    for _, c in ipairs(BLIP_PALETTE) do
        local dr = (tonumber(rgb[1]) or 0) - c[2]
        local dg = (tonumber(rgb[2]) or 0) - c[3]
        local db = (tonumber(rgb[3]) or 0) - c[4]
        local d = dr * dr + dg * dg + db * db
        if d < bestD then best, bestD = c[1], d end
    end
    return best
end

local function updateMapZoneColor(zoneId, payload)
    local blip = zoneBlips[zoneId]
    if not blip then return end
    local zone = Config.Zones[zoneId]
    local colour = (zone and zone.blipColor) or 1
    if payload and payload.controlled and type(payload.color) == 'table' then
        colour = nearestBlipColour(payload.color)
    end
    SetBlipColour(blip, colour)
end

CreateThread(function()
    if not Config.ShowZoneBlips then return end
    for id, z in pairs(Config.Zones) do
        if Territories.isDealZone(z) then
            local blip = AddBlipForRadius(z.center.x, z.center.y, z.center.z, z.radius)
            SetBlipColour(blip, z.blipColor or 1)
            SetBlipAlpha(blip, Config.BlipAlpha or 90)
            SetBlipAsShortRange(blip, true)
            zoneBlips[id] = blip
            updateMapZoneColor(id, control[id])
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, blip in pairs(zoneBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)

RegisterNetEvent('pop_territories:control', function(zoneId, payload)
    control[zoneId] = payload
    updateMapZoneColor(zoneId, payload)
end)

RegisterNetEvent('pop_territories:controlSnapshot', function(snap)
    control = snap or {}
    for zId, payload in pairs(control) do
        updateMapZoneColor(zId, payload)
    end
end)

RegisterNetEvent('pop_territories:myProgress', function(zoneId, data)
    myProgress[zoneId] = data
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('pop_territories:requestControl')
end)

-- ─────────────────────────────────────────────
-- Détection de zone (zones internes, contrôle toutes les secondes)
-- ─────────────────────────────────────────────

CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        local id, zone = Territories.getZoneAt(coords.x, coords.y)
        if not Territories.isDealZone(zone) then id = nil end

        if id ~= playerZone then
            playerZone = id
            -- checklist.lua écoute cet évènement local (entrée / sortie de zone)
            TriggerEvent('pop_territories:zoneChanged', id)
            if id then
                ESX.TriggerServerCallback('pop_territories:getMyShare', function(res)
                    myProgress[id] = res
                end, id)
            end
        end
        Wait(1000)
    end
end)

-- ─────────────────────────────────────────────
-- Loadbar de progression du crew (dans la zone)
-- ─────────────────────────────────────────────

local function drawHudText(text, x, y, scale, r, g, b)
    SetTextFont(4)
    SetTextScale(0.0, scale or 0.34)
    SetTextColour(r or 255, g or 255, b or 255, 230)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

-- Barre de progression NUI gérée par checklist.lua


-- ─────────────────────────────────────────────
-- Indicateur de contrôle sur la carte (pause) : territoire où se trouve le joueur
-- ─────────────────────────────────────────────

CreateThread(function()
    while true do
        if playerZone and IsPauseMenuActive() then
            local p = control[playerZone]
            local txt, r, g, b
            if p and p.label then
                local pct = math.floor((p.share or 0.0) + 0.5)
                if p.controlled then
                    txt = ('Contrôlé par %s — %d%%'):format(p.label, pct)
                else
                    txt = ('Disputé · %s en tête — %d%%'):format(p.label, pct)
                end
                if p.color then r, g, b = p.color[1], p.color[2], p.color[3] end
            else
                txt = ('%s — territoire non contrôlé'):format(Territories.label(playerZone))
            end
            if p and p.atWar then txt = txt .. '  [GUERRE]' end
            drawHudText(txt, 0.5, 0.062, 0.40, r, g, b)
            Wait(0)
        else
            Wait(200)
        end
    end
end)
