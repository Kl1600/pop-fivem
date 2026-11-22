-- État partagé, outils, affichage des panneaux DUI et synchronisation des affiches.

Affiche = {
    panels = {},          -- [dbId] = duiId
    data = {},            -- [dbId] = { ... }
    placing = false,
    previewPanelId = nil,
    editingId = nil,
    pendingPlacement = nil,
}

function Affiche.IsVec(t)
    return type(t) == 'table' and type(t.x) == 'number' and type(t.y) == 'number' and type(t.z) == 'number'
end

function Affiche.Notify(message, duration)
    Bridge.Notify({ title = L('affiche_title'), message = message, image = Config.NotifyImage, duration = duration or 5000 })
end

-- Ouvre l'éditeur de lien pour une affiche existante (VIP seulement)
local function EditAffiche(dbId)
    Callback.Trigger('pop_affiche:isVIP', function(isVIP)
        if isVIP then
            Affiche.editingId = dbId
            SetNuiFocus(true, true)
            Wait(200)
            local data = Affiche.data[dbId]
            SendNUIMessage({ action = 'openMenu', dbId = dbId, image_url = data and data.image_url or '' })
        else
            Affiche.Notify(L('affiche_vip_edit'))
        end
    end)
end

local function DeleteAffiche(dbId)
    Callback.Trigger('pop_affiche:isVIP', function(isVIP)
        if isVIP then
            CreateThread(function()
                local ok = lib.alertDialog({ header = L('affiche_delete_header'), content = L('affiche_delete_confirm'), centered = true, cancel = true })
                if ok == 'confirm' then
                    TriggerServerEvent('pop_affiche:server:deleteAffiche', dbId)
                end
            end)
        else
            Affiche.Notify(L('affiche_vip_delete'))
        end
    end)
end

function Affiche.Add(data)
    if not data or not data.dbId then return end
    data.dbId = tonumber(data.dbId)
    if not data.dbId or Affiche.panels[data.dbId] then return end
    if type(data.image_url) ~= 'string' or data.image_url == '' then return end
    if not Affiche.IsVec(data.pos) or not Affiche.IsVec(data.normal) or type(data.width) ~= 'number' or type(data.height) ~= 'number' then return end

    local pos = vector3(data.pos.x, data.pos.y, data.pos.z)
    local normal = vector3(data.normal.x, data.normal.y, data.normal.z)

    -- Seulement dbId dans l'adresse (évite les URLs trop longues en CEF)
    local id = exports["pop_duiengine"]:CreatePanel({
        url        = "nui://pop_affiche/html/affiche.html?dbId=" .. data.dbId,
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
    Affiche.panels[data.dbId] = id

    -- Secours si le handshake duiReady arrive avant l'image
    local imageUrl = data.image_url
    CreateThread(function()
        Wait(800)
        exports["pop_duiengine"]:SendMessage(id, { type = 'setUrl', url = imageUrl })
    end)

    local dbId = data.dbId
    local heading = math.deg(math.atan(normal.x, -normal.y))
    Bridge.Target.AddBoxZone('affiche_' .. dbId, pos, vec3(data.width, 0.1, data.height), heading, {
        { icon = 'fas fa-edit', label = L('affiche_edit'), onSelect = function() EditAffiche(dbId) end },
        { icon = 'fas fa-trash', label = L('affiche_delete'), onSelect = function() DeleteAffiche(dbId) end },
    })
end

-- Détruit le panneau DUI (libère la mémoire) ; forget = oublie aussi les données
function Affiche.Unload(dbId, forget)
    dbId = tonumber(dbId)
    if not dbId then return end
    if Affiche.panels[dbId] then
        exports["pop_duiengine"]:DestroyPanel(Affiche.panels[dbId])
        Affiche.panels[dbId] = nil
        Bridge.Target.Remove('affiche_' .. dbId)
    end
    if forget then Affiche.data[dbId] = nil end
end

RegisterNUICallback('duiReady', function(data, cb)
    local dbId = tonumber(data.dbId)
    local a = dbId and Affiche.data[dbId]
    if a and a.image_url and Affiche.panels[dbId] then
        exports["pop_duiengine"]:SendMessage(Affiche.panels[dbId], { type = 'setUrl', url = a.image_url })
    end
    cb('ok')
end)

RegisterNetEvent('pop_affiche:client:notifyUpdate', function(data)
    if not data or not data.dbId then return end
    data.dbId = tonumber(data.dbId)

    if type(data.pos) == 'string' then data.pos = json.decode(data.pos) end
    if type(data.normal) == 'string' then data.normal = json.decode(data.normal) end

    if not data.dbId or not Affiche.IsVec(data.pos) then return end

    if Affiche.data[data.dbId] then
        for k, v in pairs(data) do Affiche.data[data.dbId][k] = v end
        local duiId = Affiche.panels[data.dbId]
        if duiId then
            exports["pop_duiengine"]:SendMessage(duiId, { type = 'setUrl', url = data.image_url })
        end
    else
        Affiche.data[data.dbId] = data
        -- Création immédiate du panneau sans attendre la boucle de 1 s
        local pCoords = GetEntityCoords(PlayerPedId())
        if #(pCoords - vector3(data.pos.x, data.pos.y, data.pos.z)) < Config.LoadDistance then
            Affiche.Add(data)
        end
    end
end)

RegisterNetEvent('pop_affiche:client:removeAffiche', function(dbId)
    Affiche.Unload(dbId, true)
end)

-- Boucle de proximité (toutes les secondes)
CreateThread(function()
    while true do
        local pCoords = GetEntityCoords(PlayerPedId())
        for dbId, data in pairs(Affiche.data) do
            if Affiche.IsVec(data.pos) then
                local id = tonumber(dbId)
                local dist = #(pCoords - vector3(data.pos.x, data.pos.y, data.pos.z))
                if Affiche.panels[id] then
                    -- Trop loin : on détruit le DUI (mémoire GPU), il sera recréé en revenant
                    if dist > Config.UnloadDistance then Affiche.Unload(id, false) end
                elseif dist < Config.LoadDistance and data.image_url and data.image_url ~= '' then
                    Affiche.Add(data)
                end
            end
        end
        Wait(1000)
    end
end)

-- Chargement initial (une fois, quand le personnage est chargé)
local initialLoaded = false
Bridge.OnPlayerLoaded(function()
    if initialLoaded then return end
    initialLoaded = true
    Wait(3000)
    local all = Callback.Await('pop_affiche:getAffiches')
    if all then
        for _, a in ipairs(all) do
            a.dbId = a.id
            if type(a.pos) == 'string' then a.pos = json.decode(a.pos) end
            if type(a.normal) == 'string' then a.normal = json.decode(a.normal) end
            Affiche.data[a.id] = a
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Affiche.panels) do Affiche.Unload(id, false) end
end)
