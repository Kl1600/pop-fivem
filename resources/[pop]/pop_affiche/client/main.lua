local ESX = exports['es_extended']:getSharedObject()

local panels          = {}
local panelData       = {}
local placingMode     = false
local previewPanelId  = nil
local currentEditingId = nil
local pendingPlacement = nil

-- --- HELPERS (identiques à pop_boards) ---
local function RotToDir(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    return vector3(-math.sin(z) * math.abs(math.cos(x)), math.cos(z) * math.abs(math.cos(x)), math.sin(x))
end

local function RaycastFromCamera(dist)
    local camPos = GetGameplayCamCoord()
    local dir    = RotToDir(GetGameplayCamRot(2))
    local dest   = camPos + dir * dist
    local ray    = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    local _, hit, endCoords, surfaceNormal, _ = GetShapeTestResult(ray)
    return hit == 1, endCoords, surfaceNormal
end

local function URLEncode(str)
    if not str then return '' end
    str = string.gsub(str, "([^%w %-%_%.%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return string.gsub(str, " ", "+")
end

-- --- AFFICHE LIFECYCLE ---
local LOAD_DISTANCE = 40.0
local UNLOAD_DISTANCE = 60.0

local function IsVec(t)
    return type(t) == 'table' and type(t.x) == 'number' and type(t.y) == 'number' and type(t.z) == 'number'
end

local function AddAffiche(data)
    if not data or not data.dbId then return end
    data.dbId = tonumber(data.dbId)
    if not data.dbId or panels[data.dbId] then return end
    if type(data.image_url) ~= 'string' or data.image_url == '' then return end
    if not IsVec(data.pos) or not IsVec(data.normal) or type(data.width) ~= 'number' or type(data.height) ~= 'number' then return end

    local pos    = type(data.pos)    == 'table' and vector3(data.pos.x, data.pos.y, data.pos.z)    or data.pos
    local normal = type(data.normal) == 'table' and vector3(data.normal.x, data.normal.y, data.normal.z) or data.normal


    -- On passe uniquement dbId dans la query string pour éviter les URLs trop longues en CEF
    local baseUrl = "nui://pop_affiche/html/affiche.html?dbId=" .. data.dbId

    local id = exports["pop_duiengine"]:CreatePanel({
        url        = baseUrl,
        pos        = pos,
        normal     = normal,
        up         = vector3(0.0, 0.0, 1.0),
        width      = data.width,
        height     = data.height,
        alpha      = 255,
        resW       = 1024,
        resH       = 1024,
        faceCamera = false,
        frontOnly  = true,
        zOffset    = 0.002,
    })

    panels[data.dbId] = id

    -- Fallback/Mise à jour (le chargement principal se fait maintenant via URL ou duiReady handshake)
    local imageUrl = data.image_url
    CreateThread(function()
        Wait(800)
        exports["pop_duiengine"]:SendMessage(id, { type = 'setUrl', url = imageUrl })
    end)

    -- Interaction ox_target
    local heading = math.deg(math.atan2(normal.x, -normal.y))
    exports.ox_target:addBoxZone({
        name     = 'affiche_' .. data.dbId,
        coords   = pos,
        size     = vec3(data.width, 0.1, data.height),
        rotation = heading,
        debug    = false,
        options  = {
            {
                name     = 'edit_affiche_'   .. data.dbId,
                icon     = 'fas fa-edit',
                label    = 'Modifier l\'affiche',
                onSelect = function()
                    lib.callback('pop_affiche:server:isVIP', false, function(isVIP)
                        if isVIP then
                            currentEditingId = data.dbId
                            SetNuiFocus(true, true)
                            Wait(200)
                            SendNUIMessage({ action = 'openMenu', dbId = data.dbId, image_url = panelData[data.dbId].image_url or '' })
                        else
                            exports['pop_notify']:ShowNotify({
                                title = "Affiche",
                                message = "Seuls les membres <b>VIP</b> peuvent modifier les affiches.",
                                image = "https://static.wikia.nocookie.net/gta/images/4/4e/Bahama_Mamas-GTAV-Logo.png",
                                duration = 5000
                            })
                        end
                    end)
                end
            },
            {
                name     = 'delete_affiche_' .. data.dbId,
                icon     = 'fas fa-trash',
                label    = 'Supprimer l\'affiche',
                onSelect = function()
                    lib.callback('pop_affiche:server:isVIP', false, function(isVIP)
                        if isVIP then
                            CreateThread(function()
                                local ok = lib.alertDialog({ header = 'Supprimer', content = 'Supprimer cette affiche ?', centered = true, cancel = true })
                                if ok == 'confirm' then
                                    TriggerServerEvent('pop_affiche:server:deleteAffiche', data.dbId)
                                end
                            end)
                        else
                            exports['pop_notify']:ShowNotify({
                                title = "Affiche",
                                message = "Seuls les membres <b>VIP</b> peuvent supprimer les affiches.",
                                image = "https://static.wikia.nocookie.net/gta/images/4/4e/Bahama_Mamas-GTAV-Logo.png",
                                duration = 5000
                            })
                        end
                    end)
                end
            }
        }
    })
end

-- Détruit le panneau DUI (libère la mémoire) ; forget = oublie aussi les données
local function UnloadAffiche(dbId, forget)
    dbId = tonumber(dbId)
    if not dbId then return end
    if panels[dbId] then
        exports["pop_duiengine"]:DestroyPanel(panels[dbId])
        panels[dbId] = nil
        exports.ox_target:removeZone('affiche_' .. dbId)
    end
    if forget then panelData[dbId] = nil end
end

local function RemoveAffiche(dbId)
    UnloadAffiche(dbId, true)
end

-- --- NUI CALLBACKS ---
RegisterNUICallback('saveAffiche', function(data, cb)
    SetNuiFocus(false, false)
    local url = data.image_url or ''

    if currentEditingId then
        local pData = panelData[currentEditingId]
        if pData then
            pData.image_url = url
            local duiId = panels[currentEditingId]
            if duiId then
                exports["pop_duiengine"]:SendMessage(duiId, { type = 'setUrl', url = url })
            end
            TriggerServerEvent('pop_affiche:server:saveAffiche', { dbId = currentEditingId, image_url = url })
        end
        currentEditingId = nil
    elseif pendingPlacement then
        -- Destruction de la preview seulement maintenant que le joueur a confirmé
        if previewPanelId then
            exports["pop_duiengine"]:DestroyPanel(previewPanelId)
            previewPanelId = nil
        end
        local p = pendingPlacement
        pendingPlacement = nil
        TriggerServerEvent('pop_affiche:server:saveAffiche', {
            image_url = url,
            pos       = p.pos,
            normal    = p.normal,
            width     = p.width,
            height    = p.height,
        })
    end
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    -- Annulation : on détruit la preview si on était en train de placer
    if pendingPlacement and previewPanelId then
        exports["pop_duiengine"]:DestroyPanel(previewPanelId)
        previewPanelId = nil
    end
    currentEditingId = nil
    pendingPlacement = nil
    cb('ok')
end)

RegisterNUICallback('duiReady', function(data, cb)
    local dbId = tonumber(data.dbId)
    if dbId and panelData[dbId] and panelData[dbId].image_url then
        local duiId = panels[dbId]
        if duiId then
            exports["pop_duiengine"]:SendMessage(duiId, { type = 'setUrl', url = panelData[dbId].image_url })
        end
    end
    cb('ok')
end)

-- --- PLACEMENT ---
RegisterNetEvent('pop_affiche:client:placement', function()
    if placingMode then return end
    placingMode = true

    local defaultWidth  = 0.76
    local defaultHeight = 0.95

    previewPanelId = exports["pop_duiengine"]:CreatePanel({
        url        = 'nui://pop_affiche/html/affiche.html?preview=1',
        pos        = vector3(0, 0, 0),
        normal     = vector3(0, 1, 0),
        up         = vector3(0.0, 0.0, 1.0),
        width      = defaultWidth,
        height     = defaultHeight,
        alpha      = 150,
        resW       = 1024,
        resH       = 1024,
        faceCamera = false,
        frontOnly  = true,
        zOffset    = 0.0,
    })

    local alreadyConfirmed = false

    CreateThread(function()
        local scaleW, scaleH = 1.0, 1.0
        while placingMode do
            Wait(0)
            local hit, hitPos, hitNormal = RaycastFromCamera(10.0)
            if hit then
                local pos = hitPos + (hitNormal * 0.01)
                exports["pop_duiengine"]:SetPanelTransform(previewPanelId, pos, hitNormal, vector3(0.0, 0.0, 1.0))

                local changed = false
                if IsControlJustPressed(0, 15) then scaleW = scaleW + 0.1;              scaleH = scaleH + 0.1;              changed = true end
                if IsControlJustPressed(0, 14) then scaleW = math.max(0.1, scaleW-0.1); scaleH = math.max(0.1, scaleH-0.1); changed = true end
                if IsControlPressed(0, 172)    then scaleH = scaleH + 0.05;             changed = true end
                if IsControlPressed(0, 173)    then scaleH = math.max(0.1, scaleH-0.05); changed = true end
                if IsControlPressed(0, 174)    then scaleW = math.max(0.1, scaleW-0.05); changed = true end
                if IsControlPressed(0, 175)    then scaleW = scaleW + 0.05;             changed = true end
                if changed then
                    exports["pop_duiengine"]:SetPanelSize(previewPanelId, defaultWidth * scaleW, defaultHeight * scaleH)
                end

                if not alreadyConfirmed and (IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201) or IsControlJustPressed(0, 24)) then
                    alreadyConfirmed = true
                    placingMode      = false

                    -- On garde la preview visible pendant la saisie du lien
                    pendingPlacement = {
                        pos    = { x = pos.x,        y = pos.y,        z = pos.z        },
                        normal = { x = hitNormal.x,  y = hitNormal.y,  z = hitNormal.z  },
                        width  = defaultWidth * scaleW,
                        height = defaultHeight * scaleH,
                    }

                    Wait(200)
                    SetNuiFocus(true, true)
                    SendNUIMessage({ action = 'openMenu', dbId = nil, image_url = '' })
                    break
                end
            end

            if IsControlJustPressed(0, 177) then
                placingMode = false
                exports["pop_duiengine"]:DestroyPanel(previewPanelId)
                previewPanelId = nil
                break
            end
        end
    end)
end)

-- --- SYNC ---
RegisterNetEvent('pop_affiche:client:notifyUpdate', function(data)
    if not data or not data.dbId then return end
    data.dbId = tonumber(data.dbId)

    if type(data.pos)    == 'string' then data.pos    = json.decode(data.pos) end
    if type(data.normal) == 'string' then data.normal = json.decode(data.normal) end

    if not data.dbId or not IsVec(data.pos) then return end

    if panelData[data.dbId] then
        for k, v in pairs(data) do panelData[data.dbId][k] = v end
        local duiId = panels[data.dbId]
        if duiId then
            exports["pop_duiengine"]:SendMessage(duiId, { type = 'setUrl', url = data.image_url })
        end
    else
        panelData[data.dbId] = data
        -- Création immédiate du panel sans attendre la boucle de 1s
        local pCoords = GetEntityCoords(PlayerPedId())
        if #(pCoords - vector3(data.pos.x, data.pos.y, data.pos.z)) < LOAD_DISTANCE then
            AddAffiche(data)
        end
    end
end)

RegisterNetEvent('pop_affiche:client:removeAffiche', function(dbId)
    RemoveAffiche(dbId)
end)

-- --- COMMANDE ---
RegisterCommand('affiche_add', function()
    if not placingMode then
        lib.callback('pop_affiche:server:isVIP', false, function(isVIP)
            if isVIP then
                TriggerEvent('pop_affiche:client:placement')
            else
                exports['pop_notify']:ShowNotify({
                    title = "Affiche",
                    message = "Seuls les membres <b>VIP</b> peuvent poser des affiches.",
                    image = "https://static.wikia.nocookie.net/gta/images/4/4e/Bahama_Mamas-GTAV-Logo.png",
                    duration = 5000
                })
            end
        end)
    else
        exports['pop_notify']:ShowNotify({
            title = "Affiche",
            message = "Déjà en train de poser une affiche.",
            image = "https://static.wikia.nocookie.net/gta/images/4/4e/Bahama_Mamas-GTAV-Logo.png",
            duration = 4000
        })
    end
end, false)

-- --- BOUCLE PROXIMITE ---
CreateThread(function()
    while true do
        local pCoords = GetEntityCoords(PlayerPedId())
        for dbId, data in pairs(panelData) do
            if IsVec(data.pos) then
                local id = tonumber(dbId)
                local dist = #(pCoords - vector3(data.pos.x, data.pos.y, data.pos.z))
                if panels[id] then
                    -- Trop loin : on détruit le DUI (mémoire GPU), il sera recréé en revenant
                    if dist > UNLOAD_DISTANCE then UnloadAffiche(id, false) end
                elseif dist < LOAD_DISTANCE and data.image_url and data.image_url ~= '' then
                    AddAffiche(data)
                end
            end
        end
        Wait(1000)
    end
end)

-- --- CHARGEMENT INITIAL ---
CreateThread(function()
    while not ESX.IsPlayerLoaded() do Wait(100) end
    Wait(3000)
    local all = lib.callback.await('pop_affiche:server:getAffiches')
    if all then
        for _, a in ipairs(all) do
            a.dbId = a.id
            if type(a.pos)    == 'string' then a.pos    = json.decode(a.pos) end
            if type(a.normal) == 'string' then a.normal = json.decode(a.normal) end
            panelData[a.id] = a
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(panels) do UnloadAffiche(id, false) end
end)
