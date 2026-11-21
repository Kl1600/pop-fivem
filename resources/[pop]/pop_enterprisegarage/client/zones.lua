-- pop_enterprisegarage — client : blips, marker, touche d'ouverture, commande

-- ── Commande debug : ouvre le garage le plus proche autorisé ─────────────────
RegisterCommand(Config.Command, function()
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestDist
    for _, g in ipairs(Config.Garages) do
        local d = #(pos - g.coords)
        if not bestDist or d < bestDist then best = g; bestDist = d end
    end
    if best then Garage.OpenMenu(best.label) end
end, false)

-- ── Blips ────────────────────────────────────────────────────────────────────
CreateThread(function()
    for _, g in ipairs(Config.Garages) do
        if g.blip then
            local blip = AddBlipForCoord(g.coords.x, g.coords.y, g.coords.z)
            SetBlipSprite(blip, g.blip.sprite or 357)
            SetBlipColour(blip, g.blip.color or 38)
            SetBlipScale(blip, g.blip.scale or 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(g.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- ── Zone d'interaction (marker + touche) ─────────────────────────────────────
local function jobAllowed(garage)
    local job = Bridge.GetJob()
    return job ~= nil and job.name == garage.job
end

CreateThread(function()
    while true do
        local sleep = 1000
        local pos = GetEntityCoords(PlayerPedId())
        for _, g in ipairs(Config.Garages) do
            local d = #(pos - g.coords)
            if d < Config.DrawDistance then
                sleep = 0
                DrawMarker(36, g.coords.x, g.coords.y, g.coords.z + 0.4, 0,0,0, 0,0,0,
                    0.6,0.6,0.6, Config.MarkerColor[1], Config.MarkerColor[2], Config.MarkerColor[3], 180,
                    false, false, 2, true, nil, nil, false)
                if d < 2.0 and jobAllowed(g) then
                    if not Garage.nuiOpen then
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName(L('help_open'))
                        EndTextCommandDisplayHelp(0, false, true, -1)
                    end
                    if IsControlJustPressed(0, Config.OpenKey) and not Garage.nuiOpen then
                        Garage.OpenMenu(g.label)
                    end
                end
            end
        end
        if Garage.nuiOpen and IsControlJustPressed(0, 200) then Garage.CloseMenu() end
        Wait(sleep)
    end
end)
