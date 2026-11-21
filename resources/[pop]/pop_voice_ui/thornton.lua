local thorntonModel = GetHashKey('u_m_m_thornton')
-- Coordinates for Diamond Casino Management Office (where he is often found in heist setups)
local thorntonCoords = vector4(1087.72, 214.28, -49.0, 180.0)

-- Spawn local (non réseau) du PNJ de la scène
RegisterCommand('spawnthornton', function()
    RequestModel(thorntonModel)
    while not HasModelLoaded(thorntonModel) do
        Wait(0)
    end

    local ped = CreatePed(4, thorntonModel, thorntonCoords.x, thorntonCoords.y, thorntonCoords.z, thorntonCoords.w, false, true)

    -- Presets: Default variation is usually his specific suit
    SetPedDefaultComponentVariation(ped)

    -- No Interaction / Ambience behavior
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true) -- Won't run away or react to combat
    SetPedCanBeTargetted(ped, false)
    SetEntityCanBeDamaged(ped, false)
    SetPedAsEnemy(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    FreezeEntityPosition(ped, true) -- Optional: keep him strictly in place if needed

    -- Cosmetic: Set some props if necessary, but Default usually handles it

    SetModelAsNoLongerNeeded(thorntonModel)
end)
