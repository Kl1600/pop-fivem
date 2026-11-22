-- =====================================================
--  tab_douilles - CLIENT
--  Detecte les tirs (-> signale au serveur), gere la fouille,
--  l'affichage des douilles revelees (prop + marker + ox_target),
--  le ramassage, la barre d'analyse et le rapport balistique.
-- =====================================================

local revealed  = {}     -- [id] = { coords, prop, zone } : douilles visibles (UV passée dessus)
local hidden    = {}     -- [id] = data brute  : douilles connues mais pas encore visibles
local searching = false
local analyzing = false
local lastSearch = 0

-- Etat de la lampe UV (mis à jour via event local depuis uvpocketlight_client.lua)
local uvLightOn = false
AddEventHandler('pop_uvlight:toggled', function(state) uvLightOn = state end)

-- Ensemble des armes ignorees (resolu par hash au demarrage)
local IgnoredHash = {}
CreateThread(function()
    for _, name in ipairs(DouillesConfig.IgnoredByName or {}) do
        IgnoredHash[GetHashKey(name)] = true
    end
end)

-- ---------- Helpers ----------

local NOTIF_ICONS = {
    success = 'fas fa-circle-check',
    error   = 'fas fa-triangle-exclamation',
    info    = 'fas fa-magnifying-glass',
}

local function notify(message, ntype)
    Bridge.Notify({
        title = L('casings_title'),
        message = message,
        icon = NOTIF_ICONS[ntype or 'info'] or NOTIF_ICONS.info,
        duration = 5000,
    })
end

local function loadAnim(dict, timeout)
    RequestAnimDict(dict)
    local t = GetGameTimer() + (timeout or 1000)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    return HasAnimDictLoaded(dict)
end

-- ---------- Detection des tirs (le coeur du lien "armes a feu") ----------

local lastShot = 0
CreateThread(function()
    local ped, nextPedCheck, armed = PlayerPedId(), 0, false
    while true do
        local now = GetGameTimer()
        if now >= nextPedCheck then
            ped = PlayerPedId()
            armed = IsPedArmed(ped, 4) -- 4 = armes a feu
            nextPedCheck = now + 250
        end
        if not armed then
            Wait(250)
        elseif IsPedShooting(ped) then
            local now = GetGameTimer() -- luacheck: ignore 421
            if now - lastShot >= DouillesConfig.Spawn.Cooldown then
                lastShot = now
                local has, weapon = GetCurrentPedWeapon(ped, true)
                if has and not IgnoredHash[weapon] and math.random() <= DouillesConfig.Spawn.Chance then
                    local c = GetEntityCoords(ped)
                    local r = DouillesConfig.Spawn.ScatterRadius
                    local gx, gy = c.x, c.y
                    if r > 0.0 then
                        gx = c.x + (math.random() - 0.5) * 2.0 * r
                        gy = c.y + (math.random() - 0.5) * 2.0 * r
                    end
                    local found, gz = GetGroundZFor_3dCoord(gx, gy, c.z + 1.0, false)
                    local z = (found and (c.z - gz) < 3.0) and gz or (c.z - 0.95)
                    z = z + DouillesConfig.Spawn.GroundOffset
                    TriggerServerEvent('pop_douilles:server:shotFired', weapon, gx, gy, z)
                end
            end
            Wait(0)
        else
            Wait(0) -- Doit ABSOLUMENT être à 0 quand armé, car IsPedShooting n'est VRAI que pendant 1 frame (16ms)
        end
    end
end)


-- ---------- Affichage d'une douille revelee ----------

local function spawnCasingProp(coords)
    if not DouillesConfig.Prop.Enabled then return nil end
    local model = DouillesConfig.Prop.Model
    model = (type(model) == 'number') and model or GetHashKey(model)
    if not IsModelValid(model) then return nil end -- modele inconnu -> marker seul

    RequestModel(model)
    local t = GetGameTimer() + 1500
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
    if not HasModelLoaded(model) then return nil end

    local obj = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    SetEntityCollision(obj, false, false)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(model)
    return obj
end

local function clearRevealed(id)
    local r = revealed[id]
    if r then
        if r.zone then exports.ox_target:removeZone(r.zone) end
        if r.prop and DoesEntityExist(r.prop) then DeleteEntity(r.prop) end
        revealed[id] = nil
    end
    hidden[id] = nil -- nettoyer aussi les douilles cachees
end

local function hideCasing(id)
    local r = revealed[id]
    if not r then return end
    hidden[id] = r.data
    if r.zone then exports.ox_target:removeZone(r.zone) end
    if r.prop and DoesEntityExist(r.prop) then DeleteEntity(r.prop) end
    revealed[id] = nil
end

local function pickupCasing(id)
    local r = revealed[id]
    if not r or analyzing then return end

    local ped = PlayerPedId()
    local playedAnim = loadAnim('anim@mp_snowball', 800)
    if playedAnim then
        TaskPlayAnim(ped, 'anim@mp_snowball', 'pickup_snow', 8.0, -8.0, -1, 0, 0, false, false, false)
    end

    local ok = lib.progressBar({
        duration = DouillesConfig.Pickup.Duration,
        label = L('pickup_casing_progress'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
    ClearPedTasks(ped)
    if ok then
        TriggerServerEvent('pop_douilles:server:pickup', id)
    end
end

-- Affiche physiquement une douille (prop + marker + zone ox_target)
-- Appelé uniquement par le scan UV.
local function showCasing(data)
    local id = data.id
    if revealed[id] then return end
    hidden[id] = nil
    local coords = vector3(data.x, data.y, data.z)

    local zone = exports.ox_target:addSphereZone({
        coords = coords,
        radius = 0.6,
        debug = false,
        options = {
            {
                name = 'tab_douille_' .. id,
                icon = 'fas fa-magnifying-glass',
                label = L('target_pickup_casing'),
                distance = DouillesConfig.Pickup.Distance,
                onSelect = function()
                    pickupCasing(id)
                end,
            }
        }
    })


    revealed[id] = {
        coords = coords,
        prop = nil,
        zone = zone,
        data = data,
        revealTime = GetGameTimer(),
    }

    CreateThread(function()
        local prop = spawnCasingProp(coords)
        if prop then
            if revealed[id] then
                revealed[id].prop = prop
            else
                DeleteEntity(prop)
            end
        end
    end)
end

-- Stocke une douille (reçue du serveur). Par défaut, ELLE EST CACHÉE !
local function revealCasing(data)
    local id = data.id
    if revealed[id] or hidden[id] then return end
    hidden[id] = data
end

-- Suppression diffusee par le serveur (ramassage / expiration)
RegisterNetEvent('pop_douilles:client:removeCasing', function(id)
    clearRevealed(id)
end)

-- Apparition diffusee par le serveur (tir) : douille visible immediatement au sol
RegisterNetEvent('pop_douilles:client:revealCasing', function(data)
    if not data or not data.id then return end
    revealCasing(data)
end)

-- A la connexion, on demande la liste des douilles actuelles pour afficher celles
-- qui existent deja (sinon on ne verrait que celles tombees apres notre arrivee).
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    Wait(2000)
    TriggerServerEvent('pop_douilles:server:requestExisting')
end)

RegisterNetEvent('pop_douilles:client:syncExisting', function(list)
    if not list then return end
    for _, data in ipairs(list) do
        revealCasing(data)
    end
end)

local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

CreateThread(function()
    while true do
        local sleep = 1000
        local now = GetGameTimer()

        -- Vérifie si des douilles révélées ont expiré (45 sec)
        local toHide = {}
        for id, r in pairs(revealed) do
            if now - (r.revealTime or now) > 45000 then
                table.insert(toHide, id)
            end
        end
        for _, id in ipairs(toHide) do
            hideCasing(id)
        end

        if next(revealed) or (showAllCasingsActive and allCasingsCache and #allCasingsCache > 0) then
            local pc = GetEntityCoords(PlayerPedId())
            local s = DouillesConfig.Marker.Scale * 0.5
            local col = DouillesConfig.Marker.Color

            -- Combine revealed and admin casings
            local toDraw = {}
            for k, v in pairs(revealed) do toDraw[k] = v.coords end
            if showAllCasingsActive and allCasingsCache then
                for _, v in ipairs(allCasingsCache) do toDraw[v.id] = vector3(v.x, v.y, v.z) end
            end

            for id, coords in pairs(toDraw) do
                if #(pc - coords) <= DouillesConfig.Marker.DrawDistance then
                    sleep = 0
                    if DouillesConfig.Marker.Enabled then
                        DrawMarker(DouillesConfig.Marker.Type,
                            coords.x, coords.y, coords.z + 0.02,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            s, s, s,
                            col.r, col.g, col.b, col.a,
                            DouillesConfig.Marker.BobUpAndDown, false, 2, false, nil, nil, false)
                    end
                    -- Add 3D UI text floating slightly above the casing
                    DrawText3D(coords.x, coords.y, coords.z + 0.2, showAllCasingsActive and L('casing_3d_admin', id) or L('casing_3d'))
                end
            end
        end
        Wait(sleep)
    end
end)

-- ---------- ADMIN SHOW CASINGS ----------

showAllCasingsActive = false
allCasingsCache = {}

RegisterNetEvent('pop_douilles:client:receiveAllCasings', function(list)
    allCasingsCache = list or {}
    if showAllCasingsActive then
        notify(L('casings_admin_loaded', #allCasingsCache), 'info')
    end
end)

RegisterCommand('showcasings', function()
    showAllCasingsActive = not showAllCasingsActive
    if showAllCasingsActive then
        TriggerServerEvent('pop_douilles:server:requestAllCasings')
        notify(L('casings_admin_on'), 'success')
    else
        allCasingsCache = {}
        notify(L('casings_admin_off'), 'info')
    end
end, false)

CreateThread(function()
    while true do
        Wait(5000)
        if showAllCasingsActive then
            TriggerServerEvent('pop_douilles:server:requestAllCasings')
        end
    end
end)

-- ---------- CHERCHER (commande / touche) ----------

local function doSearch()
    if searching or analyzing then return end
    if GetGameTimer() - lastSearch < DouillesConfig.Search.Cooldown then return end

    if DouillesConfig.Search.RequireItem and exports.pop_inventory:getItemCount(DouillesConfig.Search.Item) <= 0 then
        notify(L('missing_item', DouillesConfig.Search.Item), 'error')
        return
    end

    searching = true
    lastSearch = GetGameTimer()

    local ped = PlayerPedId()
    local playedAnim = loadAnim('amb@medic@standing@kneel@base', 800)
    if playedAnim then
        TaskPlayAnim(ped, 'amb@medic@standing@kneel@base', 'base', 8.0, -8.0, 1500, 1, 0, false, false, false)
    end

    -- Removed progress bar, instant search
    Wait(200)
    searching = false

    local c = GetEntityCoords(PlayerPedId())
    local list = Callback.Await('pop_douilles:search', c.x, c.y, c.z)
    if not list or #list == 0 then
        notify(L('casings_none_found'), 'info')
        return
    end

    for _, data in ipairs(list) do
        revealCasing(data)
    end
    notify(L('casings_found', #list), 'success')
end

RegisterCommand(DouillesConfig.Search.Command, function()
    doSearch()
end, false)
RegisterKeyMapping(DouillesConfig.Search.Command, L('key_search_casings'), 'keyboard', '')

-- ---------- ANALYSER (barre cote client puis finalisation serveur) ----------

RegisterNetEvent('pop_douilles:client:startAnalyze', function(itemId)
    if analyzing or not itemId then return end
    analyzing = true

    local ped = PlayerPedId()
    local playedAnim = loadAnim('amb@world_human_clipboard@male@base', 800)
    if playedAnim then
        TaskPlayAnim(ped, 'amb@world_human_clipboard@male@base', 'base', 8.0, -8.0, -1, 49, 0, false, false, false)
    end

    local ok = lib.progressBar({
        duration = DouillesConfig.Analyze.Duration,
        label = L('analysis_progress'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
    ClearPedTasks(ped)
    analyzing = false
    if ok then
        TriggerServerEvent('pop_douilles:server:finalizeAnalyze', itemId)
    end
end)

-- ---------- Rapport balistique ----------

RegisterNetEvent('pop_douilles:client:showReport', function(meta)
    if not meta then return end

    local lieu = L('unknown')
    if meta.sceneX and meta.sceneY then
        local streetHash = GetStreetNameAtCoord(meta.sceneX + 0.0, meta.sceneY + 0.0, (meta.sceneZ or 0.0) + 0.0)
        local name = GetStreetNameFromHashKey(streetHash)
        if name and name ~= '' then lieu = name end
    end

    local content = table.concat({
        L('report_caliber', meta.caliber or L('unknown')),
        L('report_weapon', meta.weaponLabel or L('report_unidentified')),
        L('report_signature', meta.signature or '------'),
        L('report_time', meta.timeStr or L('unknown')),
        L('report_place', lieu),
        '',
        L('report_note'),
    }, '  \n')

    lib.alertDialog({
        header = L('report_title'),
        content = content,
        centered = true,
        size = 'md',
    })
end)

-- ---------- Nettoyage ----------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(revealed) do clearRevealed(id) end
    revealed = {}
    hidden  = {}
end)

-- =====================================================
--  SCAN UV : révèle les douilles cachées à proximité
--  quand la lampe UV est allumée et pointée vers elles
-- =====================================================

local UV_RADIUS  = 2.0  -- portée de détection UV (max 2m devant)
local UV_DOT_MIN = 0.85 -- cosinus min = cône serré d'environ 30 degrés (il faut bien viser)
local lastUVNotif = 0

CreateThread(function()
    while true do
        if uvLightOn then
            local ped       = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            local fwd       = GetEntityForwardVector(ped)
            local found     = 0

            -- 1. Les douilles CACHÉES deviennent VISIBLES (et timer à 45s)
            local toShow = {}
            for _, data in pairs(hidden) do
                local casingPos = vector3(data.x, data.y, data.z)
                local dist      = #(pedCoords - casingPos)

                if dist <= UV_RADIUS then
                    local dx  = casingPos.x - pedCoords.x
                    local dy  = casingPos.y - pedCoords.y
                    local len = math.sqrt(dx * dx + dy * dy)
                    if len > 0 then
                        local dot = (fwd.x * dx + fwd.y * dy) / len
                        if dot >= UV_DOT_MIN then
                            table.insert(toShow, data)
                            found = found + 1
                        end
                    end
                end
            end
            for _, data in ipairs(toShow) do
                showCasing(data)
            end

            -- 2. Rafraîchir le timer des douilles DÉJÀ VISIBLES si on repasse dessus
            for _, r in pairs(revealed) do
                local casingPos = r.coords
                local dist      = #(pedCoords - casingPos)

                if dist <= UV_RADIUS then
                    local dx  = casingPos.x - pedCoords.x
                    local dy  = casingPos.y - pedCoords.y
                    local len = math.sqrt(dx * dx + dy * dy)
                    if len > 0 then
                        local dot = (fwd.x * dx + fwd.y * dy) / len
                        if dot >= UV_DOT_MIN then
                            r.revealTime = GetGameTimer()
                        end
                    end
                end
            end

            if found > 0 and GetGameTimer() - lastUVNotif > 3000 then
                lastUVNotif = GetGameTimer()
                notify(L('casings_uv_found', found), 'success')
            end

            Wait(150) -- scan rapide quand UV active
        else
            Wait(500)
        end
    end
end)
