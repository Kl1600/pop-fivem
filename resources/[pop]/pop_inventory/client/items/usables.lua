-- Objets utilisables : TPE, menottes (usage), AED, kit de soins, kit de réparation, ciseaux, clés de véhicule ; props au sol.

local function GetClosestPlayerObj()
    if ESX then
        return ESX.Game.GetClosestPlayer() -- ESX direct
    end
    return -1, -1
end


-- TPE Interaction (use)
RegisterNetEvent('pop_inventory:client:useTPE', function()
    local input = lib.inputDialog(L('tpe_title'), {
        {type = 'number', label = L('tpe_amount_label'), description = L('tpe_amount_desc'), required = true, min = 1}
    })

    if not input or not input[1] then return end

    local amount = input[1]

    local nearestPlayer, nearestDistance = GetClosestPlayerObj()
    if nearestPlayer ~= -1 and nearestDistance <= 3.0 then
        local targetServerId = GetPlayerServerId(nearestPlayer)
        TriggerServerEvent('pop_inventory:server:sendTpeRequest', targetServerId, amount)
        Inv.NotifyTyped({
            title = L('tpe_short'),
            message = L('tpe_request_sent', amount),
            type = 'info',
            duration = 5000
        })
    else
        Inv.NotifyTyped({
            title = L('tpe_short'),
            message = L('no_player_nearby'),
            type = 'error',
            duration = 5000
        })
    end
end)

-- TPE Interaction (receive)
RegisterNetEvent('pop_inventory:client:receiveTpeRequest', function(requesterId, amount)
    local alert = lib.alertDialog({
        header = L('tpe_request_title'),
        content = L('tpe_request_prompt', amount),
        centered = true,
        cancel = true
    })

    if alert == 'confirm' then
        TriggerServerEvent('pop_inventory:server:acceptTpeRequest', requesterId, amount)
    else
        TriggerServerEvent('pop_inventory:server:declineTpeRequest', requesterId)
    end
end)

-- Menottes Interaction (utilisation de l'item sur le joueur le plus proche)
RegisterNetEvent('pop_inventory:client:useMenottes', function()
    local nearestPlayer, nearestDistance = GetClosestPlayerObj()
    if nearestPlayer ~= -1 and nearestDistance <= 3.0 then
        local targetServerId = GetPlayerServerId(nearestPlayer)
        -- On menotte/démenotte selon l'état RÉEL de la cible (statebag réseau)
        local alreadyCuffed = Player(targetServerId).state.handcuffed == true
        TriggerServerEvent('pop_inventory:server:menottesPlayer', targetServerId, not alreadyCuffed)
    else
        Inv.NotifyTyped({
            title = L('handcuffs_title'),
            message = L('no_player_nearby'),
            type = 'error',
            duration = 5000
        })
    end
end)

-- Utilisation du Défibrillateur (AED)
RegisterNetEvent('pop_inventory:client:useAED', function()
    local nearestPlayer, nearestDistance = GetClosestPlayerObj()

    if nearestPlayer ~= -1 and nearestDistance <= 3.0 then
        local targetPed = GetPlayerPed(nearestPlayer)
        if IsPedDeadOrDying(targetPed, 1) or IsEntityDead(targetPed) then
            local targetServerId = GetPlayerServerId(nearestPlayer)

            -- Animation
            TaskStartScenarioInPlace(PlayerPedId(), 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
            Wait(5000)
            ClearPedTasks(PlayerPedId())

            TriggerServerEvent('pop_inventory:server:useAED', targetServerId)
        else
            Inv.NotifyTyped({
                title = L('aed_title'),
                message = L('aed_not_unconscious'),
                type = 'error',
                duration = 5000
            })
        end
    else
        Inv.NotifyTyped({
            title = L('aed_title'),
            message = L('no_player_nearby'),
            type = 'error',
            duration = 5000
        })
    end
end)

-- Utilisation d'un Kit de Soins
RegisterNetEvent('pop_inventory:client:useKitSoins', function()
    local ped = PlayerPedId()

    if GetEntityHealth(ped) >= GetEntityMaxHealth(ped) then
        Bridge.Notify({ message = L('already_full_health'), type = 'error' })
        -- On ne devrait pas consommer l'item si pas utilisé (géré par le retour false dans config si possible,
        -- mais ici on va juste annuler l'action)
        return
    end

    TaskStartScenarioInPlace(ped, 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)

    local success = lib.progressBar({
        duration = 5000,
        label = L('progress_heal_kit'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true }
    })

    ClearPedTasks(ped)

    if success then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        Bridge.Notify({ message = L('healed_self'), type = 'success' })
    else -- luacheck: ignore 542
        -- Le kit est consommé par Config.Items (usable=true + return true),
        -- pour éviter les exploits de cancel on laisse la consommation.
    end
end)

-- Régénère un peu de santé (items gastronomiques type plateau d'huîtres)
RegisterNetEvent('pop_inventory:client:addHealth', function(amount)
    local ped = PlayerPedId()
    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    local maxHealth = GetEntityMaxHealth(ped)
    local newHealth = math.min(GetEntityHealth(ped) + amount, maxHealth)
    SetEntityHealth(ped, newHealth)
end)

-- Utilisation d'un Kit de Réparation (via inventaire)
RegisterNetEvent('pop_inventory:client:useRepakit', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        -- Essayer le véhicule le plus proche devant
        local coords = GetEntityCoords(ped)
        veh = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    end

    if veh ~= 0 then
        -- On déclenche la réparation globale (partagée avec le target)
        TriggerEvent('pop_interacts:client:repairVehicle', veh)
    else
        Bridge.Notify({ message = L('no_vehicle_nearby'), type = 'error' })
    end
end)

RegisterNetEvent('pop_inventory:client:revivePlayer', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)

    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(playerPed), true, false)
    SetPlayerInvincible(PlayerId(), false)
    ClearPedBloodDamage(playerPed)
end)


-- Ciseaux Interaction
RegisterNetEvent('pop_inventory:client:useCiseaux', function()
    local nearestPlayer, nearestDistance = GetClosestPlayerObj()
    if nearestPlayer ~= -1 and nearestDistance <= 2.5 then
        local targetServerId = GetPlayerServerId(nearestPlayer)
        local ped = PlayerPedId()

        -- Animation
        RequestAnimDict("misshairdresser")
        while not HasAnimDictLoaded("misshairdresser") do Wait(0) end

        TaskPlayAnim(ped, "misshairdresser", "keep_hair_cut_player", 8.0, -8.0, -1, 49, 0, false, false, false)

        -- Petit son de ciseaux (on utilise un son court existant)
        TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 2.0, 'scissors', 0.5)
        -- Fallback si InteractSound non présent : chHyperSound
        TriggerEvent('chHyperSound:play', 'scissors_cut', '1t', false, GetEntityCoords(ped), 5.0)

        local success = lib.progressBar({
            duration = 4000,
            label = L('progress_haircut'),
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true }
        })

        ClearPedTasks(ped)

        if success then
            TriggerServerEvent('pop_inventory:server:cutHair', targetServerId)
        end
    else
        Inv.NotifyTyped({
            title = L('scissors_title'),
            message = L('no_player_nearby'),
            type = 'error',
            duration = 5000
        })
    end
end)

-- Force Bald (target)
RegisterNetEvent('pop_inventory:client:forceBald', function()
    TriggerEvent('skinchanger:getSkin', function(skin)
        skin['hair_1'] = 0
        skin['hair_2'] = 0
        TriggerEvent('skinchanger:loadSkin', skin)

        -- Enregistrer si permanent
        TriggerEvent('skinchanger:getSkin', function(newSkin)
            TriggerServerEvent('esx_skin:save', newSkin)
        end)
    end)
end)

-- Interaction Clés de voiture
RegisterNetEvent('pop_inventory:client:toggleVehicleLock', function(plate)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = ESX.Game.GetClosestVehicle(coords)

    if DoesEntityExist(vehicle) then
        local vehiclePlate = GetVehicleNumberPlateText(vehicle)
        -- Si une plaque est spécifiée sur la clé, on vérifie qu'elle correspond
        if not plate or string.gsub(vehiclePlate, "%s+", "") == string.gsub(plate, "%s+", "") then
            local lockStatus = GetVehicleDoorLockStatus(vehicle)

            -- Animation
            RequestAnimDict("anim@mp_player_intmenu@key_fob@")
            while not HasAnimDictLoaded("anim@mp_player_intmenu@key_fob@") do Wait(0) end
            TaskPlayAnim(ped, "anim@mp_player_intmenu@key_fob@", "fob_click", 8.0, 8.0, -1, 48, 1, false, false, false)

            if lockStatus == 1 then -- Unlocked
                SetVehicleDoorsLocked(vehicle, 2)
                PlayVehicleDoorCloseSound(vehicle, 1)
                Bridge.Notify({ message = L('vehicle_locked_plate', vehiclePlate), type = 'info' })
            else
                SetVehicleDoorsLocked(vehicle, 1)
                PlayVehicleDoorOpenSound(vehicle, 0)
                Bridge.Notify({ message = L('vehicle_unlocked_plate', vehiclePlate), type = 'success' })
            end

            -- Clignotants
            SetVehicleLights(vehicle, 2)
            Wait(200)
            SetVehicleLights(vehicle, 0)
            Wait(200)
            SetVehicleLights(vehicle, 2)
            Wait(200)
            SetVehicleLights(vehicle, 0)
        else
            Bridge.Notify({ message = L('wrong_keys'), type = 'error' })
        end
    else
        Bridge.Notify({ message = L('no_vehicle_nearby'), type = 'error' })
    end
end)


-- Ground drops freezing logic (using utility_lib events)
local groundPropHashes = {}
CreateThread(function()
    while not Config or not Config.GroundProps do Wait(100) end
    for k, modelName in pairs(Config.GroundProps) do
        if k ~= "default" then
            groundPropHashes[GetHashKey(modelName)] = true
        end
    end
    if Config.GroundProps.default then
        groundPropHashes[GetHashKey(Config.GroundProps.default)] = true
    end

    -- Audit : signaler au serveur les modèles que GTA ne connaît pas. Le serveur les
    -- remplace par le `default` (resolveGroundProp) pour ne jamais rendre un item
    -- invisible au sol, et les log pour correction. On dédoublonne par nom de modèle.
    local seen, invalid = {}, {}
    for _, modelName in pairs(Config.GroundProps) do
        if type(modelName) == 'string' and not seen[modelName] then
            seen[modelName] = true
            if not IsModelValid(GetHashKey(modelName)) then
                invalid[#invalid + 1] = modelName
            end
        end
    end
    if #invalid > 0 then
        print(('[pop_inventory] GroundProps invalides détectés (%d) -> fallback default: %s')
            :format(#invalid, table.concat(invalid, ', ')))
        TriggerServerEvent('pop_inventory:server:reportInvalidGroundProps', invalid)
    end
end)

AddEventHandler("Utility:Net:OnRender", function(uNetId, obj, model)
    local modelHash = type(model) == "string" and GetHashKey(model) or model
    if groundPropHashes[modelHash] then
        CreateThread(function()
            -- Sans gravité dès le départ : un prop lourd (coffre-fort) ne doit jamais
            -- être propulsé par le ped pendant la phase de stabilisation au sol.
            SetEntityHasGravity(obj, false)
            local count = 0
            while DoesEntityExist(obj) and count < 10 do
                FreezeEntityPosition(obj, false)
                SetEntityCollision(obj, true, true)
                PlaceObjectOnGroundProperly(obj)
                FreezeEntityPosition(obj, true)
                Wait(100)
                count = count + 1
            end
            if DoesEntityExist(obj) then
                FreezeEntityPosition(obj, true)
                SetEntityCollision(obj, true, true)
                SetEntityHasGravity(obj, false)
            end
        end)
    end
end)
