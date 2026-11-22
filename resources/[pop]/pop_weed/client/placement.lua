-- Placement d'une plante au gizmo : commande /plantweed et utilisation du pot.

-- zOffset : hauteur du fantôme par rapport au joueur (/plantweed : -1.05, pot : 0.0).
local function placePlant(zOffset)
    local hash = GetHashKey(Config.Stages[1].model)
    lib.requestModel(hash)

    local pedCoords = GetEntityCoords(cache.ped)
    local heading   = GetEntityHeading(cache.ped)
    local rad       = math.pi / 180.0
    local spawnPos  = vector3(
        pedCoords.x - math.sin(heading * rad) * 1.5,
        pedCoords.y + math.cos(heading * rad) * 1.5,
        pedCoords.z + zOffset
    )

    local ghost = CreateObject(hash, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false)
    SetEntityHeading(ghost, heading)

    local result = exports.object_gizmo:useGizmo(ghost)

    -- Le gizmo peut invalider le ghost : on le supprime quoi qu'il arrive
    if DoesEntityExist(ghost) then DeleteEntity(ghost) end

    if not result then return end

    -- Respawn un placeholder à la position confirmée, visible jusqu'à la réponse serveur
    lib.requestModel(hash)
    local pending = CreateObject(hash, result.position.x, result.position.y, result.position.z, false, false, false)
    Weed.pendingGhost = pending
    SetEntityHeading(pending, result.rotation.z)
    SetEntityAlpha(pending, 180, false)
    FreezeEntityPosition(pending, true)
    SetEntityCollision(pending, false, false)

    TriggerServerEvent('pop_weed:plant', result.position.x, result.position.y, result.position.z, result.rotation.z)

    -- Fallback : supprime le placeholder après 3s si le serveur ne répond pas
    CreateThread(function()
        Wait(3000)
        if Weed.pendingGhost == pending then
            DeleteEntity(pending)
            Weed.pendingGhost = nil
        end
    end)
end

-- ─────────────────────────────────────────────
-- Commande /plantweed
-- ─────────────────────────────────────────────

RegisterCommand('plantweed', function()
    placePlant(-1.05)
end, false)

-- Utilisation du pot depuis l'inventaire → lance le placement gizmo
RegisterNetEvent('pop_weed:usePot', function()
    -- pop_inventory direct (le bridge client ne lit pas l'inventaire)
    if exports.pop_inventory:getItemCount(Config.Items.Seed) < 1 then
        Weed.Notify(L('need_seed_for_pot'), Config.NotifyDuration.Normal)
        return
    end
    placePlant(0.0)
end)
