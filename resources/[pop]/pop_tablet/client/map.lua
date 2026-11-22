-- Plans : position, rue, itinéraire GPS natif et carte du menu pause. Callback NUI `tablet:map` (action = position | route |
-- clear | pause). Aucune boucle permanente : la seule attente (carte du menu pause) s'arrête à la fermeture de ce menu.
-- Natives : GetStreetNameAtCoord, GetStreetNameFromHashKey, GetNameOfZone, SetNewWaypoint, SetWaypointOff, IsWaypointActive,
-- CalculateTravelDistanceBetweenPoints, ActivateFrontendMenu, PauseMenuceptionGoDeeper, IsPauseMenuActive, GetFirstBlipInfoId (à valider en jeu).

Tablet = Tablet or {}
Tablet.Client = Tablet.Client or {}
local C = Tablet.Client

local PAUSE_MENU = 'FE_MENU_VERSION_MP_PAUSE'
local WAYPOINT_SPRITE = 8
local PAUSE_MAX_MS = 600000
local pausing = false

local function coord(v) return type(v) == 'number' and v == v and v > -10000 and v < 10000 end

local function here()
    local p = GetEntityCoords(PlayerPedId())
    return p.x, p.y, p.z
end

--- Nom de rue et de quartier (textes du jeu, noms propres).
local function placeNames(x, y, z)
    local h = GetStreetNameAtCoord(x, y, z)
    local street = (h and h ~= 0) and GetStreetNameFromHashKey(h) or ''
    local zone = GetNameOfZone(x, y, z) or ''
    local label = zone ~= '' and GetLabelText(zone) or ''
    if label == 'NULL' then label = '' end
    return street or '', label
end

--- Distance par la route si le jeu la calcule (100000.0 = échec), sinon à vol d'oiseau.
local function travelDistance(x, y, z, tx, ty, tz)
    local straight = math.sqrt((x - tx) ^ 2 + (y - ty) ^ 2)
    local d = CalculateTravelDistanceBetweenPoints(x, y, z, tx, ty, tz)
    if type(d) ~= 'number' or d <= 0 or d >= 100000.0 then return straight, false end
    return d, true
end

--- Rend la main à l'interface après la carte du menu pause et renvoie le point posé (s'il y en a un).
local function afterPause()
    pausing = false
    if not C.IsOpen() then return end
    SetNuiFocus(true, true)
    local point
    if IsWaypointActive() then
        local blip = GetFirstBlipInfoId(WAYPOINT_SPRITE)
        local pos = blip and blip ~= 0 and GetBlipInfoIdCoord(blip) or nil
        if pos and (pos.x ~= 0.0 or pos.y ~= 0.0) then point = { x = pos.x, y = pos.y } end
    end
    C.Post('tablet:waypoint', point or {})
end

--- Ouvre la carte du menu pause. Le focus NUI est rendu au jeu pendant ce temps, puis repris à la fermeture.
function C.OpenPauseMap()
    if pausing or not C.IsOpen() then return false end
    pausing = true
    SetNuiFocus(false, false)
    ActivateFrontendMenu(joaat(PAUSE_MENU), false, -1)
    CreateThread(function()
        Wait(300)
        PauseMenuceptionGoDeeper(0)
        local waited = 0
        while IsPauseMenuActive() and waited < PAUSE_MAX_MS do
            Wait(250)
            waited = waited + 250
        end
        afterPause()
    end)
    return true
end

RegisterNUICallback('tablet:map', function(data, cb)
    if not C.IsOpen() then return cb({ ok = false, err = 'err_session' }) end
    local action = type(data) == 'table' and data.action or nil
    if action == 'position' then
        local x, y, z = here()
        local street, zone = placeNames(x, y, z)
        local mx, my = Tablet.MapPoint(x, y)
        return cb({ ok = true, x = x, y = y, z = z, mx = mx, my = my, street = street, zone = zone })
    elseif action == 'route' then
        if not coord(data.x) or not coord(data.y) or (data.z ~= nil and not coord(data.z)) then return cb({ ok = false, err = 'err_payload' }) end
        local x, y, z = here()
        SetNewWaypoint(data.x + 0.0, data.y + 0.0)
        local meters, byRoad = travelDistance(x, y, z, data.x + 0.0, data.y + 0.0, (data.z or z) + 0.0)
        return cb({ ok = true, meters = math.floor(meters + 0.5), road = byRoad })
    elseif action == 'clear' then
        SetWaypointOff()
        return cb({ ok = true })
    elseif action == 'pause' then
        return cb({ ok = C.OpenPauseMap() })
    end
    cb({ ok = false, err = 'err_payload' })
end)

-- Arrêt de la ressource (appelé par client/main.lua) : jamais de focus NUI perdu.
function C.StopMap()
    if pausing then SetNuiFocus(false, false) end
    pausing = false
end
