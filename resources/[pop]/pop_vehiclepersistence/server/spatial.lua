-- pop_vehiclepersistence — serveur : boucle spatiale (spawn/despawn autour des joueurs),
-- auto-save et expiration.

local P = Persist
local spawnedPlates, lastRespawn, grid, current = P.spawnedPlates, P.lastRespawn, P.grid, P.current
local num, isDriven = P.num, P.isDriven
local needsSave, saveVehicle = P.needsSave, P.saveVehicle
local floor = math.floor
local GRID_SIZE, CULL_RADIUS_SQ, DESPAWN_RADIUS_SQ = P.GRID_SIZE, P.CULL_RADIUS_SQ, P.DESPAWN_RADIUS_SQ
local CULL_CREATE_BUDGET, RESPAWN_RESEND_MS, CULL_INTERVAL_MS = P.CULL_CREATE_BUDGET, P.RESPAWN_RESEND_MS, P.CULL_INTERVAL_MS

-- ── Boucle spatiale (toutes les 2 s) ─────────────────────────────────────────
local function spatialTick()
    local players, cells = {}, {}
    for _, id in ipairs(GetPlayers()) do
        local pid = tonumber(id)
        local ped = GetPlayerPed(id)
        if ped ~= 0 then
            local pos = GetEntityCoords(ped)
            if pos.x ~= 0.0 or pos.y ~= 0.0 then
                players[#players + 1] = { pid = pid, pos = pos }
                local cx, cy = floor(pos.x / GRID_SIZE), floor(pos.y / GRID_SIZE)
                for dx = -1, 1 do
                    for dy = -1, 1 do cells[(cx + dx) .. ':' .. (cy + dy)] = true end
                end
            end
        end
    end

    if #players == 0 then
        for plate in pairs(spawnedPlates) do spawnedPlates[plate] = nil end
        return
    end

    local candidates = {}
    for key in pairs(cells) do
        local cell = grid[key]
        if cell then
            for plate, v in pairs(cell) do
                local vx, vy, vz = num(v.x), num(v.y), num(v.z)
                local best, bestPid = math.huge, nil
                for i = 1, #players do
                    local p = players[i].pos
                    local dx, dy, dz = p.x - vx, p.y - vy, p.z - vz
                    local d = dx * dx + dy * dy + dz * dz
                    if d < best then best, bestPid = d, players[i].pid end
                end
                if bestPid and best < DESPAWN_RADIUS_SQ then
                    candidates[plate] = { v = v, pid = bestPid, d = best }
                end
            end
        end
    end

    local budget, now = CULL_CREATE_BUDGET, GetGameTimer()
    for plate, c in pairs(candidates) do
        local claimer = spawnedPlates[plate]
        if claimer then
            if c.d < CULL_RADIUS_SQ and not isDriven(plate)
                and (not lastRespawn[plate] or now - lastRespawn[plate] > RESPAWN_RESEND_MS) then
                if GetPlayerName(claimer) then
                    TriggerClientEvent('respawnPlayerInVehicle', claimer, c.v, false)
                end
                lastRespawn[plate] = now
            end
        elseif c.d < CULL_RADIUS_SQ and budget > 0 then
            spawnedPlates[plate] = c.pid
            TriggerClientEvent('respawnPlayerInVehicle', c.pid, c.v, false)
            lastRespawn[plate] = now
            budget = budget - 1
        end
    end

    for plate, claimer in pairs(spawnedPlates) do
        if not candidates[plate] and not isDriven(plate) then
            spawnedPlates[plate] = nil
            lastRespawn[plate] = nil
            if GetPlayerName(claimer) then
                TriggerClientEvent('pop_vehiclepersistence:despawnVehicle', claimer, plate)
            end
        end
    end
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(500) end
    Wait(1000)
    P.initDatabase()

    -- Boucle spatiale
    CreateThread(function()
        while true do
            Wait(CULL_INTERVAL_MS)
            if P.ready then spatialTick() end
        end
    end)

    -- Auto-save (60 s, uniquement les véhicules modifiés, écritures espacées)
    CreateThread(function()
        while true do
            Wait(60000)
            local queue = {}
            for _, e in pairs(current) do
                if e.identifier then
                    for plate, v in pairs(e.vehicles) do
                        -- Seul le véhicule conduit compte comme une interaction
                        queue[#queue + 1] = { e.identifier, v, e.active == plate }
                    end
                end
            end
            for i = 1, #queue do
                if needsSave(queue[i][2]) then
                    saveVehicle(queue[i][1], queue[i][2], queue[i][3])
                    Wait(500)
                end
            end
        end
    end)

    -- Expiration (horaire)
    CreateThread(function()
        while true do
            Wait(3600000)
            P.purgeExpired()
        end
    end)
end)
