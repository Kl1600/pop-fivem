-- Blips de zone (couleur du propriétaire) et blip temporaire d'alerte rivale.
-- Aucune boucle : tout est piloté par client/main.lua.

Blips = {}

local RES = GetCurrentResourceName()

local ZONE_ALPHA = 90
local NEUTRAL_COLOUR = 40
local ALERT_RADIUS = 80.0
local ALERT_COLOUR = 49 -- distincte des couleurs de crews (palette ci-dessous)
local ALERT_ALPHA = 120
local ALERT_DURATION = 60000

-- Palette fixe : couleur de blip GTA -> RVB.
local PALETTE = {
    { id = 0,  r = 0xfe, g = 0xfe, b = 0xfe },
    { id = 1,  r = 0xe0, g = 0x32, b = 0x32 },
    { id = 2,  r = 0x72, g = 0xcc, b = 0x72 },
    { id = 3,  r = 0x5d, g = 0xb6, b = 0xe5 },
    { id = 5,  r = 0xee, g = 0xc6, b = 0x4e },
    { id = 7,  r = 0x9a, g = 0x6a, b = 0xc9 },
    { id = 8,  r = 0xf2, g = 0x8e, b = 0xc0 },
    { id = 48, r = 0xe8, g = 0x35, b = 0x8c }, -- rose vif (accent POP #ff2e88)
    { id = 17, r = 0xf0, g = 0xa3, b = 0x5a },
    { id = 25, r = 0x3a, g = 0x8a, b = 0x3a },
    { id = 38, r = 0x2c, g = 0x6d, b = 0xb8 },
}

local zoneBlips = {}  -- [zoneId] = blip
local alertBlips = {} -- [blip] = true
local colourCache = {} -- [hex] = id

--- Couleur de blip GTA la plus proche d'une couleur '#rrggbb' (nil ou invalide -> neutre).
local function blipColour(owner)
    local hex = type(owner) == 'table' and type(owner.color) == 'string' and owner.color:lower() or nil
    if not hex then return NEUTRAL_COLOUR end
    if colourCache[hex] then return colourCache[hex] end

    local r, g, b = hex:match('^#(%x%x)(%x%x)(%x%x)$')
    if not r then return NEUTRAL_COLOUR end
    r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)

    local best, bestDist = NEUTRAL_COLOUR, math.huge
    for _, c in ipairs(PALETTE) do
        local d = (c.r - r) ^ 2 + (c.g - g) ^ 2 + (c.b - b) ^ 2
        if d < bestDist then best, bestDist = c.id, d end
    end
    colourCache[hex] = best
    return best
end

local function clearZones()
    for id, blip in pairs(zoneBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        zoneBlips[id] = nil
    end
end

--- Supprime puis recrée les blips de zone selon l'état reçu du serveur (state peut être nil).
function Blips.Refresh(state)
    clearZones()
    if not Config.ZoneBlips then return end
    local zones = type(state) == 'table' and type(state.zones) == 'table' and state.zones or {}
    for _, zone in ipairs(Zones.List) do
        local c = zone.center
        local blip = AddBlipForRadius(c.x, c.y, c.z or 0.0, zone.radius + 0.0)
        SetBlipAlpha(blip, ZONE_ALPHA)
        SetBlipColour(blip, blipColour(zones[zone.id] and zones[zone.id].owner))
        zoneBlips[zone.id] = blip
    end
end

--- Change seulement la couleur du blip d'une zone.
function Blips.SetOwner(zoneId, owner)
    local blip = zoneBlips[zoneId]
    if blip and DoesBlipExist(blip) then SetBlipColour(blip, blipColour(owner)) end
end

--- Zone approximative d'une vente rivale, retirée après 60 s.
function Blips.Alert(coords)
    local blip = AddBlipForRadius(coords.x + 0.0, coords.y + 0.0, (coords.z or 0.0) + 0.0, ALERT_RADIUS)
    SetBlipColour(blip, ALERT_COLOUR)
    SetBlipAlpha(blip, ALERT_ALPHA)
    alertBlips[blip] = true
    SetTimeout(ALERT_DURATION, function()
        if not alertBlips[blip] then return end
        alertBlips[blip] = nil
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    clearZones()
    for blip in pairs(alertBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    alertBlips = {}
end)
