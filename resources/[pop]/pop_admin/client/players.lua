-- =====================================================================
--  LISTE JOUEURS + ACTIONS + MODE SPEC + NOCLIP + SPECTATE
-- =====================================================================
local nameById = {}

RegisterNetEvent('pop_admin:receivePlayers', function(list)
    nameById = {}
    for _, p in ipairs(list or {}) do nameById[p.id] = p.name end
    AdminSend('players', { list = list })
end)

RegisterNUICallback('playerAction', function(data, cb)
    if data.action == 'spectate' then
        AdminStartSpectate(tonumber(data.target))
    else
        TriggerServerEvent('pop_admin:playerAction', data)
        if data.action == 'goto' or data.action == 'kick' or data.action == 'ban' then
            SetTimeout(400, function() TriggerServerEvent('pop_admin:requestPlayers') end)
        end
    end
    cb({})
end)

-- =====================================================================
--  NOCLIP
-- =====================================================================
function AdminToggleNoclip()
    Admin.noclip = not Admin.noclip
    local ped = PlayerPedId()
    if Admin.noclip then
        if not Admin.invisible then
            Admin.wasInvisible = false
            Admin.invisible = true
            SetEntityVisible(ped, false, false)
        else
            Admin.wasInvisible = true
        end
        AdminNotify('Noclip activé', 'success')
        CreateThread(function()
            local speed = 1.0
            while Admin.noclip do
                local p = PlayerPedId()
                local veh = GetVehiclePedIsIn(p, false)
                local ent = veh ~= 0 and veh or p
                SetEntityInvincible(p, true)
                SetEntityCollision(ent, false, false)
                FreezeEntityPosition(ent, true)
                SetEntityVisible(p, not Admin.invisible, false)

                local camRot = GetGameplayCamRot(2)
                local camCoord = GetEntityCoords(ent)
                local rz = math.rad(camRot.z)
                local rx = math.rad(camRot.x)
                local cosrx = math.abs(math.cos(rx))
                local fwd = vector3(-math.sin(rz) * cosrx, math.cos(rz) * cosrx, math.sin(rx))

                -- Vitesse (Shift rapide, Alt lent)
                speed = 1.0
                if IsControlPressed(0, 21) then speed = 4.0 end
                if IsControlPressed(0, 19) then speed = 0.3 end

                local dx, dy, dz = 0.0, 0.0, 0.0
                if IsControlPressed(0, 32) then dx = fwd.x * speed; dy = fwd.y * speed; dz = fwd.z * speed end       -- W
                if IsControlPressed(0, 33) then dx = -fwd.x * speed; dy = -fwd.y * speed; dz = -fwd.z * speed end    -- S
                if IsControlPressed(0, 34) then dx = dx + math.cos(rz) * -speed; dy = dy + math.sin(rz) * -speed end -- A
                if IsControlPressed(0, 35) then dx = dx + math.cos(rz) * speed; dy = dy + math.sin(rz) * speed end   -- D
                if IsControlPressed(0, 22) then dz = dz + speed end  -- Espace monte
                if IsControlPressed(0, 36) then dz = dz - speed end  -- Ctrl descend

                local np = camCoord + vector3(dx, dy, dz)
                SetEntityCoordsNoOffset(ent, np.x, np.y, np.z, true, true, true)
                SetEntityRotation(ent, 0.0, 0.0, camRot.z, 2, true)

                DisableControlAction(0, 30, true); DisableControlAction(0, 31, true)
                Wait(0)
            end
            local p = PlayerPedId()
            local veh = GetVehiclePedIsIn(p, false)
            local ent = veh ~= 0 and veh or p
            FreezeEntityPosition(ent, false)
            SetEntityCollision(ent, true, true)
            SetEntityInvincible(p, Admin.godmode)
            SetEntityVisible(p, not Admin.invisible, false)
        end)
    else
        if Admin.wasInvisible == false and Admin.invisible == true then
            Admin.invisible = false
        end
        AdminNotify('Noclip désactivé', 'success')
    end
end

-- =====================================================================
--  SPECTATE (suivre un joueur)
-- =====================================================================
function AdminStartSpectate(serverId)
    if not serverId then return end
    local target = GetPlayerFromServerId(serverId)
    if target == -1 then
        AdminNotify('Joueur hors de portée', 'error'); return
    end
    AdminClose()
    Admin.spec.spectating = serverId
    local myPed = PlayerPedId()
    local targetPed = GetPlayerPed(target)
    local tc = GetEntityCoords(targetPed)
    -- Rapproche pour garantir le scope
    RequestCollisionAtCoord(tc.x, tc.y, tc.z)
    NetworkSetInSpectatorMode(true, targetPed)
    SetEntityVisible(myPed, false, false)
    AdminNotify('Spectate : ' .. (nameById[serverId] or GetPlayerName(target)), 'success')

    CreateThread(function()
        while Admin.spec.spectating == serverId do
            local tp = GetPlayerFromServerId(serverId)
            if tp == -1 then break end
            local ped = GetPlayerPed(tp)
            if ped and ped ~= 0 then NetworkSetInSpectatorMode(true, ped) end
            -- Affichage info
            SetTextFont(4); SetTextScale(0.0, 0.45); SetTextColour(255, 255, 255, 220)
            SetTextOutline(); SetTextCentre(true)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName('~y~SPECTATE~s~ ' .. (nameById[serverId] or '') .. '  -  ~r~RETOUR ARRIÈRE~s~ pour quitter')
            EndTextCommandDisplayText(0.5, 0.92)
            if IsControlJustPressed(0, 177) then -- Backspace
                AdminStopSpectate()
                break
            end
            Wait(0)
        end
    end)
end

function AdminStopSpectate()
    if not Admin.spec.spectating then return end
    Admin.spec.spectating = nil
    NetworkSetInSpectatorMode(false, PlayerPedId())
    SetEntityVisible(PlayerPedId(), true, false)
    AdminNotify('Spectate terminé', 'success')
end

-- =====================================================================
--  MODE SPEC (point central + visée joueur + options)
-- =====================================================================
function AdminToggleSpec()
    if Admin.spec.active then AdminStopSpec() return end
    Admin.spec.active = true
    Admin.spec.target = nil
    Admin.minimized = false
    send_spec_state(true)
    AdminRefreshFocus()
    TriggerServerEvent('pop_admin:requestPlayers')
    AdminNotify('Mode spec — visez un joueur, ' .. (Config.SpecKey or 'F') .. ' pour les options', 'info')
    CreateThread(specLoop)
end

function AdminStopSpec()
    Admin.spec.active = false
    Admin.spec.target = nil
    send_spec_state(false)
    -- Réaffiche le menu rapide
    Admin.open = true
    AdminSend('open', { view = 'quick' })
    AdminRefreshFocus()
end

function send_spec_state(active)
    AdminSend('specMode', { active = active })
end

function specLoop()
    while Admin.spec.active do
        local myPed = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)
        local best, bestScore = nil, 0.0009  -- seuil ~ proximité du centre écran
        for _, p in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(p)
            if ped ~= myPed and ped ~= 0 and not IsEntityDead(ped) then
                local c = GetEntityCoords(ped)
                local dist = #(c - myCoords)
                if dist <= (Config.SpecMaxDist or 80.0) then
                    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(c.x, c.y, c.z + 0.35)
                    if onScreen then
                        local score = (sx - 0.5) * (sx - 0.5) + (sy - 0.5) * (sy - 0.5)
                        if score < bestScore then
                            bestScore = score
                            best = { sid = GetPlayerServerId(p), dist = dist }
                        end
                    end
                end
            end
        end

        if best then
            if not Admin.spec.target or Admin.spec.target.sid ~= best.sid then
                Admin.spec.target = best
            else
                Admin.spec.target.dist = best.dist
            end
            AdminSend('specTarget', {
                sid = best.sid,
                name = nameById[best.sid] or ('Joueur ' .. best.sid),
                dist = math.floor(best.dist + 0.5),
            })
        else
            if Admin.spec.target then Admin.spec.target = nil end
            AdminSend('specTarget', { sid = false })
        end

        Wait(0)
    end
end

-- Touche d'options du mode spec (ouvre le panneau d'actions sur la cible visée).
RegisterCommand('pop_admin_speckey', function()
    if Admin.spec.active and Admin.spec.target then
        local t = Admin.spec.target
        Admin.spec.active = false  -- fige la visée pendant le choix
        AdminSend('specOpen', {
            sid = t.sid,
            name = nameById[t.sid] or ('Joueur ' .. t.sid),
        })
        Admin.open = true
        AdminRefreshFocus()
    end
end, false)
RegisterKeyMapping('pop_admin_speckey', 'Admin : options sur la cible (mode spec)', 'keyboard', Config.SpecKey or 'F')

-- Reprise / fermeture du panneau d'options spec depuis la NUI.
RegisterNUICallback('specResume', function(_, cb)
    -- Relance la visée
    if not Admin.spec.spectating then
        Admin.spec.active = true
        send_spec_state(true)
        AdminRefreshFocus()
        CreateThread(specLoop)
    end
    cb({})
end)

RegisterNUICallback('specExit', function(_, cb)
    Admin.spec.active = false
    Admin.spec.target = nil
    send_spec_state(false)
    Admin.open = true
    AdminSend('open', { view = 'quick' })
    AdminRefreshFocus()
    cb({})
end)

local function DrawText3D(coords, text, r, g, b)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(r or 255, g or 255, b or 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(x, y)
        local factor = (string.len(text)) / 370
        DrawRect(x, y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
    end
end

function AdminToggleNames()
    Admin.shownames = not Admin.shownames
    if Admin.shownames then
        AdminNotify('Affichage des noms activé', 'success')
        TriggerServerEvent('pop_admin:requestPlayers')
        -- Thread pour le dessin des tags
        CreateThread(function()
            while Admin.shownames do
                local myPed = PlayerPedId()
                local myCoords = GetEntityCoords(myPed)
                for _, player in ipairs(GetActivePlayers()) do
                    local ped = GetPlayerPed(player)
                    if ped ~= 0 and ped ~= myPed then
                        local coords = GetEntityCoords(ped)
                        local dist = #(coords - myCoords)
                        if dist < 120.0 then
                            local serverId = GetPlayerServerId(player)
                            local name = nameById[serverId] or GetPlayerName(player) or ("Joueur " .. serverId)
                            local text = ("[%d] %s"):format(serverId, name)
                            DrawText3D(vector3(coords.x, coords.y, coords.z + 1.1), text, 255, 255, 255)
                        end
                    end
                end
                Wait(0)
            end
        end)
        -- Thread pour synchroniser régulièrement les noms
        CreateThread(function()
            local lastSync = GetGameTimer()
            while Admin.shownames do
                local now = GetGameTimer()
                if now - lastSync > 10000 then
                    TriggerServerEvent('pop_admin:requestPlayers')
                    lastSync = now
                end
                Wait(500)
            end
        end)
    else
        AdminNotify('Affichage des noms désactivé', 'success')
    end
end
