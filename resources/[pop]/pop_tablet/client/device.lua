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

--- Instantané de l'horloge du jeu. Le mois natif va de 0 à 11 (à valider en jeu), l'interface reçoit 1 à 12.
function C.ClockSnapshot()
    return {
        h = GetClockHours(), m = GetClockMinutes(), s = GetClockSeconds(),
        d = GetClockDayOfMonth(), mo = GetClockMonth() + 1, y = GetClockYear(),
        msPerMin = C.MsPerGameMinute(),
    }
end

local function tick(mine)
    if mine ~= resyncGeneration or not resyncActive or not C.IsOpen() then return end
    C.Post('tablet:clock', C.ClockSnapshot())
    SetTimeout(RESYNC_MS, function() tick(mine) end)
end

--- Démarre (active = true) ou arrête la resynchronisation ; envoie tout de suite un instantané au démarrage.
function C.SetResync(active)
    resyncGeneration = resyncGeneration + 1
    resyncActive = active == true
    if resyncActive and C.IsOpen() then
        local mine = resyncGeneration
        C.Post('tablet:clock', C.ClockSnapshot())
        SetTimeout(RESYNC_MS, function() tick(mine) end)
    end
end

function C.StopResync()
    C.SetResync(false)
end
