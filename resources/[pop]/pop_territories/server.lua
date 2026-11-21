-- ─────────────────────────────────────────────
-- pop_territories - guerre de territoires
-- Parts de zone par crew + multiplicateurs sur la vente de drogue (pop_dealing)
-- Détection de zone côté serveur via l'export MapZones:getZoneAt
-- ─────────────────────────────────────────────

local ESX = exports['es_extended']:getSharedObject()

local shares   = {}   -- [zoneId] = { [crewId] = sharePct }
local warState = {}   -- [zoneId] = { attacker = crewId, defender = crewId, startedAt = os.time() }

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function clampShare(v)
    if v < 0 then return 0.0 end
    if v > 100 then return 100.0 end
    return v
end

local function getShare(zoneId, crewId)
    local z = shares[zoneId]
    return (z and z[crewId]) or 0.0
end

local function setShare(zoneId, crewId, value)
    value = clampShare(value)
    shares[zoneId] = shares[zoneId] or {}
    shares[zoneId][crewId] = value
    MySQL.query('INSERT INTO territory_shares (zone_id, crew_id, share) VALUES (?, ?, ?) '
        .. 'ON DUPLICATE KEY UPDATE share = ?', { zoneId, crewId, value, value })
end

-- Crew en tête dans la zone (plus grosse part), quel que soit le seuil
local function leaderOf(zoneId)
    local z = shares[zoneId]
    if not z then return nil, 0.0 end
    local topCrew, topShare = nil, 0.0
    for crewId, s in pairs(z) do
        if s > topShare then topCrew, topShare = crewId, s end
    end
    return topCrew, topShare
end

-- Crew qui CONTRÔLE la zone : le leader si sa part dépasse le seuil
local function controllerOf(zoneId)
    local crewId, share = leaderOf(zoneId)
    if crewId and share >= Config.ControlThreshold then
        return crewId, share
    end
    return nil
end

local function notifyCrew(crewId, title, message, ntype)
    local ok, sources = pcall(function() return exports.pop_crew:getOnlineMemberSources(crewId) end)
    if not ok or not sources then return end
    local icon = 'fas fa-circle-info'
    if ntype == 'success' then icon = 'fas fa-check'
    elseif ntype == 'error' then icon = 'fas fa-triangle-exclamation' end
    for _, src in ipairs(sources) do
        TriggerClientEvent('notification:client:ShowNotify', src, {
            title = title, message = message, icon = icon, duration = 6000,
        })
    end
end

local function zoneLabel(zoneId, zoneData)
    return (zoneData and zoneData.name) or zoneId
end

-- ─────────────────────────────────────────────
-- Synchro vers les clients (survol carte + loadbar)
-- ─────────────────────────────────────────────

local function controlPayload(zoneId)
    local crewId, share = leaderOf(zoneId)
    local crew = crewId and exports.pop_crew:getCrewById(crewId)
    return {
        crewId     = crewId,
        label      = crew and crew.label or nil,
        color      = crew and crew.color or nil,
        share      = share or 0.0,
        controlled = (crewId ~= nil and share >= Config.ControlThreshold),
        threshold  = Config.ControlThreshold,
        atWar      = warState[zoneId] ~= nil,
    }
end

-- Diffuse l'état de contrôle d'une zone à tous les clients (pour le survol carte)
local function syncZoneControl(zoneId)
    TriggerClientEvent('pop_territories:control', -1, zoneId, controlPayload(zoneId))
end

-- Pousse la part du crew à ses membres en ligne (pour la loadbar)
local function pushCrewProgress(crewId, zoneId, share)
    local crew = exports.pop_crew:getCrewById(crewId)
    local ok, sources = pcall(function() return exports.pop_crew:getOnlineMemberSources(crewId) end)
    if not ok or not sources then return end
    local data = {
        share      = share,
        threshold  = Config.ControlThreshold,
        color      = crew and crew.color or nil,
        controlled = share >= Config.ControlThreshold,
        inCrew     = true,
    }
    for _, src in ipairs(sources) do
        TriggerClientEvent('pop_territories:myProgress', src, zoneId, data)
    end
end

-- ─────────────────────────────────────────────
-- Guerre des gangs
-- ─────────────────────────────────────────────

local function startWar(zoneId, attacker, defender, zoneData)
    warState[zoneId] = { attacker = attacker, defender = defender, startedAt = os.time() }
    local label = zoneLabel(zoneId, zoneData)
    local atk = exports.pop_crew:getCrewById(attacker)
    local def = exports.pop_crew:getCrewById(defender)

    notifyCrew(defender, 'Guerre de territoire',
        ('%s attaque votre territoire %s !'):format(atk and atk.label or '?', label), 'error')
    notifyCrew(attacker, 'Guerre de territoire',
        ('Vous lancez l\'assaut sur %s (tenu par %s).'):format(label, def and def.label or '?'), 'inform')

    syncZoneControl(zoneId)

    -- Hook pour la phase combat / capture (à brancher : dispatch, blip, timer…)
    TriggerEvent('pop_territories:warStarted', zoneId, attacker, defender)
    if Config.Debug then
        print(('[pop_territories] GUERRE %s : crew %s attaque crew %s'):format(zoneId, attacker, defender))
    end
end

-- Termine une guerre (ex: appelé par la logique de capture en phase 2)
exports('endWar', function(zoneId, winnerCrewId)
    if not warState[zoneId] then return false end
    warState[zoneId] = nil
    if winnerCrewId then
        -- le vainqueur prend le contrôle total, les autres sont remis à zéro
        shares[zoneId] = {}
        setShare(zoneId, winnerCrewId, 100.0)
    end
    syncZoneControl(zoneId)
    TriggerEvent('pop_territories:warEnded', zoneId, winnerCrewId)
    return true
end)

exports('isAtWar', function(zoneId) return warState[zoneId] ~= nil end)
exports('getShares', function(zoneId) return shares[zoneId] or {} end)
exports('getController', function(zoneId)
    local crewId = controllerOf(zoneId)
    return crewId
end)

-- ─────────────────────────────────────────────
-- Point d'entrée : une vente de drogue a eu lieu (appelé par pop_dealing)
-- src        = vendeur
-- baseAmount = montant calculé par pop_dealing AVANT multiplicateur
-- retourne   : finalAmount, info
-- ─────────────────────────────────────────────

exports('recordDrugSale', function(src, baseAmount)
    baseAmount = tonumber(baseAmount) or 0

    -- Position serveur du vendeur → territoire
    local ped = GetPlayerPed(src)
    if ped == 0 then return baseAmount, { zone = nil } end
    local coords = GetEntityCoords(ped)

    local zoneId, zoneData
    local ok = pcall(function() zoneId, zoneData = exports.MapZones:getZoneAt(coords.x, coords.y) end)
    if not ok or not zoneId then
        -- Hors territoire
        if Config.Debug then TriggerClientEvent('notification:client:ShowNotify', src, { title = '[DEBUG] Territoire', message = 'Hors territoire — vente sans zone', icon = 'fas, fa-bug', duration = 5000 }) end
        return math.floor(baseAmount * Config.OutsideMultiplier + 0.5), { zone = nil }
    end

    -- Zone de vente ? Le flag vient de l'éditeur MapZones (zoneData.dealZone),
    -- avec fallback sur une éventuelle entrée Config.Zones (compat).
    local zoneCfg  = Config.Zones[zoneId]
    local isDeal   = (zoneData and zoneData.dealZone == true) or (zoneCfg ~= nil)
    if not isDeal then
        -- Territoire normal : aucune vente comptabilisée, pas de multiplicateur
        if Config.Debug then TriggerClientEvent('notification:client:ShowNotify', src, { title = '[DEBUG] Territoire', message = ('Zone %s détectée MAIS dealZone=false'):format(zoneId), icon = 'fas fa-bug', duration = 5000 }) end
        return math.floor(baseAmount * Config.OutsideMultiplier + 0.5), { zone = zoneId, dealZone = false }
    end

    local baseMult = (zoneData and tonumber(zoneData.multiplier))
                  or (zoneCfg and tonumber(zoneCfg.multiplier))
                  or Config.DefaultMultiplier

    local crew = exports.pop_crew:getCrew(src)
    if not crew then
        -- Vendeur sans crew : multiplicateur de base, aucune prise de part
        if Config.Debug then TriggerClientEvent('notification:client:ShowNotify', src, { title = '[DEBUG] Territoire', message = ('Zone %s OK mais tu n\'as PAS de crew !'):format(zoneId), icon = 'fas fa-bug', duration = 6000 }) end
        return math.floor(baseAmount * baseMult + 0.5), { zone = zoneId, mult = baseMult }
    end

    -- Contrôleur AVANT la vente (pour détecter le déclenchement de guerre)
    local ctrlBefore = controllerOf(zoneId)

    -- Gain de part pour le crew du vendeur
    local newShare = clampShare(getShare(zoneId, crew.id) + Config.SharePerSale)
    setShare(zoneId, crew.id, newShare)

    -- Érosion optionnelle des parts des autres crews
    if Config.ErosionFactor and Config.ErosionFactor > 0 then
        local z = shares[zoneId]
        for cid, s in pairs(z) do
            if cid ~= crew.id then
                setShare(zoneId, cid, s - Config.SharePerSale * Config.ErosionFactor)
            end
        end
    end

    local ctrlAfter = controllerOf(zoneId)

    -- Multiplicateur : contrôleur → ControlMultiplier, sinon multiplicateur de base
    local mult = baseMult
    if ctrlAfter == crew.id and newShare >= Config.ControlThreshold then
        mult = Config.ControlMultiplier
    end

    -- Debug notification : part enregistrée
    if Config.Debug then
        TriggerClientEvent('notification:client:ShowNotify', src, {
            title = '[DEBUG] Part enregistrée',
            message = ('Zone %s | Crew %s | Part: %.0f%% | Contrôle: %s'):format(
                zoneId, crew.name, newShare, ctrlAfter == crew.id and 'OUI ✓' or 'non'
            ),
            icon = 'fas fa-chart-pie', duration = 6000
        })
    end

    -- Prise de contrôle (ce crew vient de passer au-dessus du seuil)
    if ctrlAfter == crew.id and ctrlBefore ~= crew.id then
        notifyCrew(crew.id, 'Territoire',
            ('Votre crew contrôle désormais %s !'):format(zoneLabel(zoneId, zoneData)), 'success')
    end

    -- Déclenchement de guerre : un rival pousse sa part au-dessus du seuil
    -- dans une zone contrôlée par un AUTRE crew
    if ctrlBefore and ctrlBefore ~= crew.id
       and newShare >= Config.WarThreshold and not warState[zoneId] then
        startWar(zoneId, crew.id, ctrlBefore, zoneData)
    end

    -- Synchro clients : contrôle de la zone (survol carte) + progression du crew (loadbar)
    syncZoneControl(zoneId)
    TriggerClientEvent('pop_territories:client:drugSold', src)
    pushCrewProgress(crew.id, zoneId, newShare)

    local finalAmount = math.floor(baseAmount * mult + 0.5)
    return finalAmount, { zone = zoneId, mult = mult, share = newShare, crew = crew.id }
end)

-- ─────────────────────────────────────────────
-- Chargement DB
-- ─────────────────────────────────────────────

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS territory_shares (
            zone_id    VARCHAR(32) NOT NULL,
            crew_id    INT NOT NULL,
            share      FLOAT DEFAULT 0,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (zone_id, crew_id)
        )
    ]])

    for _, row in ipairs(MySQL.query.await('SELECT zone_id, crew_id, share FROM territory_shares') or {}) do
        shares[row.zone_id] = shares[row.zone_id] or {}
        shares[row.zone_id][row.crew_id] = row.share
    end
end)

-- Nettoyage des parts quand un crew est dissous
AddEventHandler('pop_crew:disbanded', function(crewId)
    local touched = {}
    for zoneId, z in pairs(shares) do
        if z[crewId] then
            z[crewId] = nil
            touched[#touched + 1] = zoneId
            if warState[zoneId] and (warState[zoneId].attacker == crewId or warState[zoneId].defender == crewId) then
                warState[zoneId] = nil
            end
        end
    end
    MySQL.query('DELETE FROM territory_shares WHERE crew_id = ?', { crewId })
    for _, zoneId in ipairs(touched) do syncZoneControl(zoneId) end
end)

-- Quand un crew change de couleur, on resynchronise les zones qu'il domine
AddEventHandler('pop_crew:colorChanged', function(crewId)
    for zoneId, z in pairs(shares) do
        if z[crewId] then syncZoneControl(zoneId) end
    end
end)

-- ─────────────────────────────────────────────
-- Synchro à la demande du client (snapshot complet + sa progression)
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_territories:requestControl', function()
    local src = source
    local snap = {}
    for zoneId in pairs(shares) do snap[zoneId] = controlPayload(zoneId) end
    TriggerClientEvent('pop_territories:controlSnapshot', src, snap)
end)

ESX.RegisterServerCallback('pop_territories:hasWeed', function(source, cb)
    local ok, count = pcall(function()
        return exports.pop_inventory:getItemCount(source, 'pochonweed')
    end)
    cb(ok and type(count) == 'number' and count > 0)
end)

ESX.RegisterServerCallback('pop_territories:getMyShare', function(source, cb, zoneId)
    local crew = exports.pop_crew:getCrew(source)
    if not crew then
        return cb({ share = 0.0, threshold = Config.ControlThreshold, inCrew = false })
    end
    cb({
        share      = getShare(zoneId, crew.id),
        threshold  = Config.ControlThreshold,
        color      = crew.color,
        controlled = getShare(zoneId, crew.id) >= Config.ControlThreshold,
        inCrew     = true,
    })
end)

-- ─────────────────────────────────────────────
-- Commande d'info : état du territoire où se trouve le joueur
-- ─────────────────────────────────────────────

RegisterCommand('territory', function(src)
    if src == 0 then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local coords = GetEntityCoords(ped)

    local zoneId, zoneData
    pcall(function() zoneId, zoneData = exports.MapZones:getZoneAt(coords.x, coords.y) end)

    if not zoneId then
        return TriggerClientEvent('notification:client:ShowNotify', src,
            { title = 'Territoire', message = 'Tu n\'es dans aucun territoire.', icon = 'fas fa-circle-info', duration = 5000 })
    end

    local zoneCfg = Config.Zones[zoneId]
    local isDeal  = (zoneData and zoneData.dealZone == true) or (zoneCfg ~= nil)

    local msg
    if not isDeal then
        msg = ('%s — zone normale (pas de vente)'):format(zoneLabel(zoneId, zoneData))
    else
        local mult = (zoneData and zoneData.multiplier) or (zoneCfg and zoneCfg.multiplier) or Config.DefaultMultiplier
        local ctrl = controllerOf(zoneId)
        local ctrlCrew = ctrl and exports.pop_crew:getCrewById(ctrl)
        local status = warState[zoneId] and ' [EN GUERRE]' or ''
        msg = ('%s — vente x%.2f — contrôle: %s%s'):format(
            zoneLabel(zoneId, zoneData), mult,
            ctrlCrew and ctrlCrew.label or 'aucun', status)
    end
    TriggerClientEvent('notification:client:ShowNotify', src,
        { title = 'Territoire', message = msg, icon = 'fas fa-circle-info', duration = 7000 })
end, false)
