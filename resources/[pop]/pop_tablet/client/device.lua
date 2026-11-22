-- Horloge du jeu envoyée à l'interface : un instantané à l'ouverture, l'interface avance l'heure seule.
-- Resynchronisation toutes les 60 s seulement tant que Horloge/Météo est au premier plan (chaîne de SetTimeout, pas de boucle).

Tablet = Tablet or {}
Tablet.Client = Tablet.Client or {}
local C = Tablet.Client

local RESYNC_MS = 60000
local resyncGeneration = 0
local resyncActive = false

--- Millisecondes réelles par minute de jeu : native du jeu, sinon la config.
function C.MsPerGameMinute()
    local ms = GetMillisecondsPerGameMinute()
    if type(ms) == 'number' and ms > 0 then return ms end
    return Config.Clock.MsPerGameMinute
end

--- Instantané de l'horloge du jeu. Convention unique : mois 1 à 12 partout (le natif GetClockMonth va de 0 à 11, à valider en jeu).
function C.ClockSnapshot()
    return {
        h = GetClockHours(), m = GetClockMinutes(), s = GetClockSeconds(),
        d = GetClockDayOfMonth(), mo = GetClockMonth() + 1, y = GetClockYear(),
        msPerMin = C.MsPerGameMinute(),
    }
end

--- Date du jeu 'AAAA-MM-JJ HH:MM' envoyée au serveur à l'ouverture (filtre des widgets, aucun droit).
function C.GameStamp()
    local s = C.ClockSnapshot()
    return ('%04d-%02d-%02d %02d:%02d'):format(s.y, s.mo, s.d, s.h, s.m)
end

-- Types de météo du jeu (noms de SET_WEATHER_TYPE_NOW) rangés dans les 6 familles de l'interface.
local WEATHER_KINDS = {
    EXTRASUNNY = 'clear', CLEAR = 'clear', NEUTRAL = 'clear', SMOG = 'fog', FOGGY = 'fog', OVERCAST = 'clouds',
    CLOUDS = 'clouds', CLEARING = 'clouds', RAIN = 'rain', THUNDER = 'thunder', SNOW = 'snow', BLIZZARD = 'snow',
    SNOWLIGHT = 'snow', XMAS = 'snow', HALLOWEEN = 'fog',
}
local BASE_TEMP = { clear = 27, clouds = 22, rain = 17, thunder = 16, fog = 15, snow = -1 }
local TEMP_SWING = 4
local byHash

local function hashKind(hash)
    if not byHash then
        byHash = {}
        for name, kind in pairs(WEATHER_KINDS) do byHash[joaat(name) & 0xFFFFFFFF] = kind end
    end
    return byHash[hash & 0xFFFFFFFF]
end

--- Température fictive : le jeu n'en donne pas. Base du type de météo + variation du jour (maximum à 15 h).
function C.TempAt(kind, hour)
    local base = BASE_TEMP[kind] or 22
    return math.floor(base + TEMP_SWING * math.cos((hour - 15) / 24 * 2 * math.pi) + 0.5)
end

--- Météo du jeu : { temp, kind, hi, lo, city }. Type = météo suivante si la transition a dépassé la moitié, sinon la précédente.
--- Natives : GetPrevWeatherTypeHashName, GetNextWeatherTypeHashName, GetWeatherTypeTransition, GetRainLevel (à valider en jeu).
function C.WeatherSnapshot()
    local prev, nxt = hashKind(GetPrevWeatherTypeHashName()), hashKind(GetNextWeatherTypeHashName())
    local _, _, pct = GetWeatherTypeTransition()
    local kind = ((tonumber(pct) or 1) >= 0.5 and nxt or prev) or nxt or prev or 'clear'
    if kind == 'clear' and (GetRainLevel() or 0) > 0.3 then kind = 'rain' end
    local base = BASE_TEMP[kind] or 22
    local rain = GetRainLevel() or 0
    -- Vent : GetWindSpeed (m/s, converti en km/h) et GetWindDirection (vecteur, cap en degrés). À valider en jeu.
    local speed = tonumber(GetWindSpeed()) or 0
    local dir = GetWindDirection()
    local deg = 0
    if type(dir) == 'vector3' or type(dir) == 'table' then deg = math.floor((math.deg(math.atan(dir.x or 0, dir.y or 0)) % 360) + 0.5) end
    return {
        temp = C.TempAt(kind, GetClockHours()), kind = kind, hi = base + TEMP_SWING, lo = base - TEMP_SWING, city = Config.Weather.City,
        rain = math.floor(rain * 100 + 0.5) / 100, wind = math.floor(speed * 3.6 + 0.5), deg = deg,
    }
end

local function tick(mine)
    if mine ~= resyncGeneration or not resyncActive or not C.IsOpen() then return end
    C.Post('tablet:weather', C.WeatherSnapshot())
    C.Post('tablet:clock', C.ClockSnapshot())
    SetTimeout(RESYNC_MS, function() tick(mine) end)
end

--- Démarre (active = true) ou arrête la resynchronisation ; envoie tout de suite un instantané au démarrage.
function C.SetResync(active)
    resyncGeneration = resyncGeneration + 1
    resyncActive = active == true
    if resyncActive and C.IsOpen() then
        local mine = resyncGeneration
        C.Post('tablet:weather', C.WeatherSnapshot())
        C.Post('tablet:clock', C.ClockSnapshot())
        SetTimeout(RESYNC_MS, function() tick(mine) end)
    end
end

function C.StopResync()
    C.SetResync(false)
end
