-- ─────────────────────────────────────────────
-- pop_territories - client
-- Loadbar de progression du crew (dans la zone) + indicateur de contrôle au survol carte
-- ─────────────────────────────────────────────

local ESX = exports['es_extended']:getSharedObject()

local control     = {}    -- [zoneId] = payload de contrôle (diffusé par le serveur)
local myProgress  = {}    -- [zoneId] = { share, threshold, color, controlled }
local playerZone  = nil   -- zone de vente où le joueur se trouve physiquement
local hoverZone   = nil   -- zone de vente survolée par le curseur (carte en pause)

-- ─────────────────────────────────────────────
-- Synchro serveur
-- ─────────────────────────────────────────────

local function deepCopyZone(zData)
    local copy = {}
    for k, v in pairs(zData) do
        if type(v) == 'table' then
            local t = {}
            for i, val in pairs(v) do t[i] = val end
            copy[k] = t
        else
            copy[k] = v
        end
    end
    -- deep copy points
    if zData.points then
        copy.points = {}
        for i, p in ipairs(zData.points) do
            copy.points[i] = { x = p.x, y = p.y }
        end
    end
    return copy
end

local function updateMapZoneColor(zoneId, payload)
    local ok, mzZones = pcall(function() return exports.MapZones:getZones() end)
    if not ok or type(mzZones) ~= 'table' or not mzZones[zoneId] then return end

    local zData = mzZones[zoneId]

    -- Sauvegarde la couleur d'origine une seule fois
    if not zData.originalColor then
        local c = zData.color or {255, 0, 0}
        zData.originalColor = { c[1], c[2], c[3] }
    end

    -- Détermine la nouvelle couleur (crew si contrôlé, originale sinon)
    local newColor
    if payload and payload.controlled and payload.color then
        newColor = { payload.color[1], payload.color[2], payload.color[3] }
    else
        newColor = { zData.originalColor[1], zData.originalColor[2], zData.originalColor[3] }
    end

    -- Ne rien faire si la couleur n'a pas changé
    local cur = zData.color
    if cur and cur[1] == newColor[1] and cur[2] == newColor[2] and cur[3] == newColor[3] then
        return
    end

    -- Copie profonde pour éviter la corruption lors du removeZone interne à addZone
    local dataCopy = deepCopyZone(zData)
    dataCopy.color = newColor
    -- Propage aussi sur l'original pour les prochains appels
    zData.color = newColor

    exports.MapZones:addZone(dataCopy, zoneId)
end

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
-- Détection de zone (via MapZones)
-- ─────────────────────────────────────────────

AddEventHandler('mapzones:onPlayerEnter', function(zone, id)
    if zone and zone.dealZone then
        playerZone = id
        ESX.TriggerServerCallback('pop_territories:getMyShare', function(res)
            myProgress[id] = res
        end, id)
    end
end)

AddEventHandler('mapzones:onPlayerExit', function(_, id)
    if playerZone == id then playerZone = nil end
end)

AddEventHandler('mapzones:onMapEnter', function(zone, id)
    hoverZone = (zone and zone.dealZone) and id or nil
end)

AddEventHandler('mapzones:onMapExit', function(_, id)
    if hoverZone == id then hoverZone = nil end
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
-- Indicateur de contrôle au survol de la carte (pause)
-- ─────────────────────────────────────────────

CreateThread(function()
    while true do
        if IsPauseMenuActive() and hoverZone then
            local p = control[hoverZone]
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
                txt = 'Territoire non contrôlé'
            end
            if p and p.atWar then txt = txt .. '  [GUERRE]' end
            drawHudText(txt, 0.5, 0.062, 0.40, r, g, b)
            Wait(0)
        else
            Wait(200)
        end
    end
end)
