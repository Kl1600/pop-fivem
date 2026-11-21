-- =====================================================================
--  GESTION DU TEMPS & MÉTÉO (style easytime) — application côté client
-- =====================================================================
local tw = {
    hour = 12, minute = 0, frozen = false,
    weather = 'EXTRASUNNY', blackout = false,
}
local hasState = false
local appliedWeather = nil
local lastTick = 0

RegisterNetEvent('pop_admin:syncTimeWeather', function(state)
    if type(state) ~= 'table' then return end
    tw.hour     = tonumber(state.hour) or tw.hour
    tw.minute   = tonumber(state.minute) or tw.minute
    tw.frozen   = state.frozen == true
    tw.weather  = tostring(state.weather or tw.weather)
    tw.blackout = state.blackout == true
    hasState = true
    lastTick = GetGameTimer()

    -- Météo (réappliquée seulement si elle change)
    if tw.weather ~= appliedWeather then
        appliedWeather = tw.weather
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        SetWeatherTypePersist(tw.weather)
        SetWeatherTypeNow(tw.weather)
        SetWeatherTypeNowPersist(tw.weather)
    end
    SetArtificialLightsState(tw.blackout)

    -- Met à jour le panneau si ouvert
    if Admin and Admin.open then
        AdminSend('timeWeather', {
            hour = tw.hour, minute = tw.minute, frozen = tw.frozen,
            weather = tw.weather, blackout = tw.blackout,
        })
    end
end)

-- Applique l'heure en continu (force le rendu, gère le gel).
CreateThread(function()
    while true do
        if hasState then
            -- Avance locale (1 min IG / 2 s), resynchronisée par le serveur chaque minute
            if not tw.frozen and GetGameTimer() - lastTick >= 2000 then
                lastTick = lastTick + 2000
                tw.minute = tw.minute + 1
                if tw.minute >= 60 then
                    tw.minute = 0
                    tw.hour = (tw.hour + 1) % 24
                end
            end
            NetworkOverrideClockTime(tw.hour, tw.minute, 0)
            if tw.blackout then SetArtificialLightsState(true) end
        end
        Wait(tw.frozen and 200 or 1000)
    end
end)
