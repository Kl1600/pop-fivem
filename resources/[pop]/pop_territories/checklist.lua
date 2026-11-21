-- ─────────────────────────────────────────────
-- pop_territories - checklist.lua
-- Guide HUD à gauche — affiché dynamiquement
-- ─────────────────────────────────────────────

local stepsDone = { false, false, false, false }
local hasWeed = false
local shown = false
local inZone = false

-- ─────────────────────────────────────────────
-- Helpers NUI
-- ─────────────────────────────────────────────

local function nuiStep(n, done)
    if done then
        for i = 1, n - 1 do
            if not stepsDone[i] then
                stepsDone[i] = true
                SendNUIMessage({ type = 'cl_step', step = i, done = true })
            end
        end
    end
    if stepsDone[n] == done then return end
    stepsDone[n] = done
    SendNUIMessage({ type = 'cl_step', step = n, done = done })
end

local function nuiProgress(share, threshold, controlled)
    SendNUIMessage({ type = 'cl_progress', share = share, controlled = controlled })
    if share > 0 and not stepsDone[3] then nuiStep(3, true) end
    if controlled  and not stepsDone[4] then nuiStep(4, true) end
end

local function nuiShow(v)
    if shown == v then return end
    shown = v
    SendNUIMessage({ type = 'cl_show', visible = v })

    -- On décale les notifications dynamiquement pour ne pas superposer
    TriggerEvent('notification:client:setRaised', v, 420)
end

local function updateVisibility()
    if not hasWeed then
        if shown then
            nuiShow(false)
            SendNUIMessage({ type = 'cl_reset' })
            stepsDone = { false, false, false, false }
        end
        return
    end

    -- Si on a la weed :
    if not stepsDone[3] then
        -- Étape 3 pas encore validée : toujours affiché pour guider
        nuiShow(true)
    else
        -- Étape 3 validée : on n'affiche que si on est dans une zone
        if inZone then
            nuiShow(true)
        else
            nuiShow(false)
        end
    end
end

-- ─────────────────────────────────────────────
-- Détection inventaire via export pop_inventory client
-- ─────────────────────────────────────────────

CreateThread(function()
    Wait(4000) -- laisse les scripts se charger

    while true do
        local ok, count = pcall(function()
            return exports['pop_inventory']:getItemCount('pochonweed')
        end)

        local currentWeed = (ok and type(count) == 'number' and count > 0)

        if currentWeed ~= hasWeed then
            hasWeed = currentWeed
            if hasWeed then
                nuiStep(1, true)
            end
        end

        updateVisibility()
        Wait(1500)
    end
end)

-- ─────────────────────────────────────────────
-- Détection de zone
-- ─────────────────────────────────────────────

-- Évènement local envoyé par client.lua (contrôle de zone toutes les secondes)
AddEventHandler('pop_territories:zoneChanged', function(zoneId)
    local now = zoneId ~= nil
    if now == inZone then return end
    inZone = now
    updateVisibility()
end)

-- ─────────────────────────────────────────────
-- Étape 2 : activation du mode vente (notif pop_dealing)
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_dealing:notify', function(data)
    if not data or not shown then return end
    local msg = tostring(data.message or '')
    if msg:find('Vente activ') or msg:find('repère les clients') then
        nuiStep(2, true)
    end
end)

-- ─────────────────────────────────────────────
-- Étapes 3 + 4 : progression territoire
-- ─────────────────────────────────────────────

RegisterNetEvent('pop_territories:myProgress', function(zoneId, data)
    if not data or not shown then return end
    nuiProgress(data.share or 0.0, data.threshold or 80.0, data.controlled or false)
    updateVisibility() -- au cas où l'étape 3 vient d'être validée
end)

-- ─────────────────────────────────────────────
-- Nettoyage
-- ─────────────────────────────────────────────

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SendNUIMessage({ type = 'cl_show', visible = false })
    end
end)
