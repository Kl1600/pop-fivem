-- Cibles ox_target des cartons / coffres posés et des joueurs (fouille, etc.).

-- Gestion des targets ox_target pour les cartons et coffres
local CARDBOARD_BOX_MODEL = 'prop_cs_cardbox_01'
local SAFE_BOX_MODEL = 'prop_ld_int_safe_01'

local function setupCardboardBoxTargets()
  if GetResourceState('ox_target') ~= 'started' then
    return
  end

  -- Les colis YouTool (pop_management) utilisent le même modèle de carton mais
  -- ne sont PAS des conteneurs pop_inventory : on masque ces options dessus
  -- (flag d'état local 'ytColis' posé par pop_management).
  local function isNotYtColis(entity)
    return not (entity and DoesEntityExist(entity) and Entity(entity).state and Entity(entity).state.ytColis)
  end

  pcall(function()
    exports.ox_target:addModel(CARDBOARD_BOX_MODEL, {
      {
        label = L('target_move_box'),
        icon = 'fas fa-arrows-alt',
        distance = 5.5,
        canInteract = isNotYtColis,
        onSelect = function(data)
          if data and data.entity and DoesEntityExist(data.entity) then
            Inv.startMovingBox(data.entity)
          end
        end,
      },
      {
        label = L('target_open'),
        icon = 'fas fa-box-open',
        distance = 5.5,
        canInteract = isNotYtColis,
        onSelect = function(data)
          if data and data.entity and DoesEntityExist(data.entity) then
            local coords = GetEntityCoords(data.entity)
            TriggerEvent('standby_ui:client:openBox', { x = coords.x, y = coords.y, z = coords.z })
          end
        end,
      },
      {
        label = L('target_take'),
        icon = 'fas fa-hand',
        distance = 5.5,
        onSelect = function(data)
          if not (data and data.entity and DoesEntityExist(data.entity)) then return end
          -- Colis YouTool : route vers la prise de commande (pop_management).
          local st = Entity(data.entity).state
          if st and st.ytColis then
            TriggerServerEvent('pop_management:validateYouToolOrder', 'package', st.ytColis)
            return
          end
          -- Conteneur pop_inventory classique
          local coords = GetEntityCoords(data.entity)
          TriggerServerEvent('pop_inventory:server:takeRemoteContainer', coords)
        end,
      }
    })

    exports.ox_target:addModel(SAFE_BOX_MODEL, {
      {
        label = L('target_move_safe'),
        icon = 'fas fa-arrows-alt',
        distance = 5.5,
        onSelect = function(data)
          if data and data.entity and DoesEntityExist(data.entity) then
            Inv.startMovingBox(data.entity)
          end
        end,
      },
      {
        label = L('target_open'),
        icon = 'fas fa-door-open',
        distance = 5.5,
        onSelect = function(data)
          if data and data.entity and DoesEntityExist(data.entity) then
            local coords = GetEntityCoords(data.entity)
            TriggerEvent('standby_ui:client:openBox', { x = coords.x, y = coords.y, z = coords.z })
          end
        end,
      },
      {
        label = L('target_take'),
        icon = 'fas fa-hand',
        distance = 5.5,
        onSelect = function(data)
          if data and data.entity and DoesEntityExist(data.entity) then
            local coords = GetEntityCoords(data.entity)
            TriggerServerEvent('pop_inventory:server:takeRemoteContainer', coords)
          end
        end,
      }
    })

    -- Capot moteur : option sur le capot de tous les véhicules -> conteneur distant
    -- (moteur 3x3 + batterie), géré par standby_client.lua / engine_server.lua.
    -- Certains véhicules ont le moteur à l'ARRIÈRE (sportives, etc.) : le capot/coffre
    -- moteur correspond alors à la porte 5 et se trouve à l'arrière (au sens d'ox_target),
    -- pas à l'avant. On détecte le côté du moteur via la position du bone 'engine'.
    local function isRearEngine(vehicle)
        local bone = GetEntityBoneIndexByName(vehicle, 'engine')
        if bone == -1 then return false end
        local world = GetWorldPositionOfEntityBone(vehicle, bone)
        local off = GetOffsetFromEntityGivenWorldCoords(vehicle, world.x, world.y, world.z)
        return off.y < 0.0 -- bone moteur derrière le centre = moteur arrière
    end

    -- Porte du capot moteur (4 = capot avant, 5 = capot arrière).
    local function getEngineDoor(vehicle)
        return isRearEngine(vehicle) and 5 or 4
    end

    -- Vrai si le point visé par ox_target est bien du côté du moteur (et pas à l'autre bout).
    local function isHitOnEngineSide(vehicle, coords)
        if not coords then return true end
        local off = GetOffsetFromEntityGivenWorldCoords(vehicle, coords.x, coords.y, coords.z)
        if isRearEngine(vehicle) then
            return off.y < 0.0
        end
        return off.y > 0.0
    end

    -- Liste statique des modèles dont le capot ne s'ouvre JAMAIS (porte non animée
    -- en jeu, peu importe les bones présentes). À compléter au cas par cas quand un
    -- véhicule concerné est identifié. Aucune détection au runtime : fiable à 100%
    -- et zéro impact sur les véhicules classiques (comportement inchangé).
    local NoHoodModels = {
        [GetHashKey('adder')] = true,
    }

    local function hoodIsBroken(vehicle)
        return NoHoodModels[GetEntityModel(vehicle)] == true
    end

    exports.ox_target:addGlobalVehicle({
      {
        name = 'pop_inventory:open_hood_phys',
        label = L('target_open_hood'),
        icon = 'fas fa-arrow-up',
        bones = { 'engine', 'bonnet', 'boot' },
        distance = 1.8,
        canInteract = function(entity, distance, coords)
            if hoodIsBroken(entity) then return false end
            return GetVehicleDoorAngleRatio(entity, getEngineDoor(entity)) <= 0.0
                and isHitOnEngineSide(entity, coords)
        end,
        onSelect = function(data)
            SetVehicleDoorOpen(data.entity, getEngineDoor(data.entity), false, false)
        end
      },
      {
        name = 'pop_inventory:close_hood_phys',
        label = L('target_close_hood'),
        icon = 'fas fa-arrow-down',
        bones = { 'engine', 'bonnet', 'boot' },
        distance = 1.8,
        canInteract = function(entity, distance, coords)
            if hoodIsBroken(entity) then return false end
            return GetVehicleDoorAngleRatio(entity, getEngineDoor(entity)) > 0.0
                and isHitOnEngineSide(entity, coords)
        end,
        onSelect = function(data)
            SetVehicleDoorShut(data.entity, getEngineDoor(data.entity), false)
        end
      },
      {
        name = 'pop_inventory:capot',
        label = L('target_inspect_engine'),
        icon = 'fas fa-car-battery',
        bones = { 'engine', 'bonnet', 'boot' },
        distance = 1.8,
        canInteract = function(entity, distance, coords)
            if hoodIsBroken(entity) then return false end
            return GetVehicleDoorAngleRatio(entity, getEngineDoor(entity)) > 0.0
                and isHitOnEngineSide(entity, coords)
        end,
        onSelect = function(data)
          local veh = data and data.entity
          if not veh or not DoesEntityExist(veh) then return end
          local plate = GetVehicleNumberPlateText(veh)
          if not plate then return end
          TriggerEvent('pop_inventory:client:openHood', veh, plate, getEngineDoor(veh))
        end,
      }
    })

    -- Véhicules listés dans NoHoodModels : accès direct au moteur sans restriction
    -- de bone, visible UNIQUEMENT sur ceux-ci (les 3 options ci-dessus sont masquées).
    exports.ox_target:addGlobalVehicle({
      {
        name = 'pop_inventory:repair_engine_no_hood',
        label = L('target_inspect_engine'),
        icon = 'fas fa-car-battery',
        distance = 2.5,
        canInteract = function(entity)
            return hoodIsBroken(entity)
        end,
        onSelect = function(data)
          local veh = data and data.entity
          if not veh or not DoesEntityExist(veh) then return end
          local plate = GetVehicleNumberPlateText(veh)
          if not plate then return end
          TriggerEvent('pop_inventory:client:openHood', veh, plate, getEngineDoor(veh))
        end,
      }
    })

    -- Portes latérales : toggle ouvrir/fermer via la bone ciblée
    local doorBones = {
        { bone = 'door_dside_f', index = 0 },
        { bone = 'door_pside_f', index = 1 },
        { bone = 'door_dside_r', index = 2 },
        { bone = 'door_pside_r', index = 3 },
    }
    local doorOptions = {}
    for _, d in ipairs(doorBones) do
        local idx = d.index
        table.insert(doorOptions, {
            name = 'pop_inventory:door_toggle_' .. idx,
            label = L('target_door'),
            icon = 'fas fa-car-side',
            bones = { d.bone },
            distance = 3.0,
            onSelect = function(data)
                if GetVehicleDoorAngleRatio(data.entity, idx) <= 0.0 then
                    SetVehicleDoorOpen(data.entity, idx, false, false)
                else
                    SetVehicleDoorShut(data.entity, idx, false)
                end
            end,
        })
    end
    exports.ox_target:addGlobalVehicle(doorOptions)

    -- ADMIN : suppression d'un véhicule de la carte (persistant ou non)
    exports.ox_target:addGlobalVehicle({
        {
            name = 'pop_inventory:admin_delete_vehicle',
            label = L('target_delete_vehicle'),
            icon = 'fas fa-trash',
            distance = 5.0,
            canInteract = function(entity)
                return adminAllowed == true
            end,
            onSelect = function(data)
                local veh = data and data.entity
                if not veh or not DoesEntityExist(veh) then return end
                local netId = NetworkGetNetworkIdFromEntity(veh)
                TriggerServerEvent('pop_inventory:server:adminDeleteVehicle', netId)
            end,
        }
    })

    -- Gestion des targets ox_target pour l'armytanker
    exports.ox_target:addModel('armytanker', {
      {
        label = L('target_open'),
        icon = 'fas fa-box-open',
        distance = 5.5,
        onSelect = function(data)
          if data and data.entity and DoesEntityExist(data.entity) then
            local entity = data.entity
            local uniqueId = 'tank_unknown'

            if IsEntityAVehicle(entity) then
               local plate = GetVehicleNumberPlateText(entity)
               if plate then
                   plate = string.gsub(plate, "%s+", "")
                   uniqueId = 'tank_' .. plate
               end
            else
               local coords = GetEntityCoords(entity)
               uniqueId = string.format("tank_%d_%d", math.floor(coords.x), math.floor(coords.y))
            end

            local chestData = {
                id = uniqueId,
                label = 'Army Tanker',
                slots = 40,
                maxWeight = 500.0,
            }
            TriggerEvent('standby_ui:client:openArmyTanker', chestData)
          end
        end,
      }
    })

    -- Gestion des targets ox_target pour le brickadeta
    exports.ox_target:addModel('brickadeta', {
      {
        label = L('target_open'),
        icon = 'fas fa-box-open',
        distance = 5.5,
        onSelect = function(data)
          if data and data.entity and DoesEntityExist(data.entity) then
            local entity = data.entity
            local uniqueId = 'brickadeta_unknown'

            if IsEntityAVehicle(entity) then
               local plate = GetVehicleNumberPlateText(entity)
               if plate then
                   plate = string.gsub(plate, "%s+", "")
                   uniqueId = 'brickadeta_' .. plate
               end
            else
               local coords = GetEntityCoords(entity)
               uniqueId = string.format("brickadeta_%d_%d", math.floor(coords.x), math.floor(coords.y))
            end

            local chestData = {
                id = uniqueId,
                label = 'Brickadeta',
                slots = 2,
                maxWeight = 500.0,
            }
            TriggerEvent('standby_ui:client:openArmyTanker', chestData)
          end
        end,
      }
    })
    -- Coffre arrière de l'ambulance
    exports.ox_target:addModel('ambulance', {
      {
        name = 'ambulance_trunk_open',
        label = L('target_open_trunk'),
        icon = 'fas fa-truck-medical',
        bones = { 'boot', 'bodywork_rear_extras', 'bumper_r' },
        distance = 2.5,
        canInteract = function(entity)
            return GetVehicleDoorAngleRatio(entity, 5) <= 0.0
        end,
        onSelect = function(data)
            local veh = data and data.entity
            if not veh or not DoesEntityExist(veh) then return end
            local plate = GetVehicleNumberPlateText(veh)
            if not plate then return end
            plate = plate:gsub("^%s*(.-)%s*$", "%1")
            SetVehicleDoorOpen(veh, 5, false, false)
            TriggerEvent('pop_inventory:client:openAmbulanceTrunk', veh, plate)
        end,
      },
      {
        name = 'ambulance_trunk_close',
        label = L('target_close_trunk'),
        icon = 'fas fa-truck-medical',
        bones = { 'boot', 'bodywork_rear_extras', 'bumper_r' },
        distance = 2.5,
        canInteract = function(entity)
            return GetVehicleDoorAngleRatio(entity, 5) > 0.0
        end,
        onSelect = function(data)
            local veh = data and data.entity
            if not veh or not DoesEntityExist(veh) then return end
            SetVehicleDoorShut(veh, 5, false)
        end,
      },
    })

    -- Gestion des targets ox_target pour les Static Chests (Config.StaticChests)
    if Config.StaticChests then
      for _, chest in ipairs(Config.StaticChests) do
        local option = {
            label = chest.label or L('target_open'),
            icon = 'fas fa-box-open',
            onSelect = function()
                TriggerServerEvent('pop_inventory:server:openStaticChest', chest.id, chest.label, chest.slots, chest.maxWeight)
            end
        }
        if chest.jobs or chest.job then
            option.groups = chest.jobs or chest.job
        end
        exports.ox_target:addPoint({
            coords = chest.coords,
            radius = chest.radius or 2.0,
            debug = false,
            options = { option }
        })
      end
    end

    -- Les salles de casiers (Config.LockerRooms) ne passent PAS par ox_target :
    -- ce sont des points fixes, gérés par un prompt v3DUI + touche (E/G) dans
    -- standby_client.lua (même mécanique que Config.StaticChests).
  end)
end

-- Configurer les targets au démarrage
local function setupPlayerTargets()
  if GetResourceState('ox_target') ~= 'started' then
    return
  end

  exports.ox_target:addGlobalPlayer({
    {
      name = 'pop_inventory:fouiller',
      label = L('target_search'),
      icon = 'fas fa-search',
      distance = 2.0,
      canInteract = function(entity)
        if IsEntityDead(entity) then return true end
        -- Mains levées (X) via statebag réseau : fouille de n'importe quel joueur.
        if IsPedAPlayer(entity) then
          local sid = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
          if sid > 0 and Player(sid).state.handsup == true then return true end
        end
        -- Fallback animations.
        if IsEntityPlayingAnim(entity, "missminuteman_1ig_2", "handsup_enter", 3) then return true end
        if IsEntityPlayingAnim(entity, "missminuteman_1ig_2", "handsup_base", 3) then return true end
        if IsEntityPlayingAnim(entity, "random@mugging3", "handsup_standing_base", 3) then return true end
        return false
      end,
      onSelect = function(data)
        local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
        TriggerServerEvent('pop_inventory:server:startSearchingPlayer', targetId)
      end,
    },
    {
      name = 'pop_inventory:menotter',
      label = L('target_cuff'),
      icon = 'fas fa-handcuffs',
      distance = 2.5,
      canInteract = function(entity)
        if not IsPedAPlayer(entity) then return false end
        if entity == PlayerPedId() then return false end
        local count = exports.pop_inventory:getItemCount('menottes')
        return count and count > 0
      end,
      onSelect = function(data)
        local plyId = NetworkGetPlayerIndexFromPed(data.entity)
        if plyId == -1 then return end
        local targetServerId = GetPlayerServerId(plyId)
        local alreadyCuffed = Player(targetServerId).state.handcuffed == true
        TriggerServerEvent('pop_inventory:server:menottesPlayer', targetServerId, not alreadyCuffed)
      end,
    },
    {
      name = 'pop_inventory:escorter',
      label = L('target_escort'),
      icon = 'fas fa-people-arrows',
      distance = 2.5,
      canInteract = function(entity)
        if not IsPedAPlayer(entity) then return false end
        if entity == PlayerPedId() then return false end
        local plyId = NetworkGetPlayerIndexFromPed(entity)
        if plyId == -1 then return false end
        local serverId = GetPlayerServerId(plyId)
        -- Menotté ET pas déjà escorté par quelqu'un.
        return Player(serverId).state.handcuffed == true
           and not Player(serverId).state.escortedBy
      end,
      onSelect = function(data)
        local plyId = NetworkGetPlayerIndexFromPed(data.entity)
        if plyId == -1 then return end
        local targetServerId = GetPlayerServerId(plyId)
        TriggerServerEvent('pop_inventory:server:toggleEscort', targetServerId)
      end,
    },
    {
      name = 'pop_inventory:lacher',
      label = L('target_release'),
      icon = 'fas fa-hand-peace',
      distance = 2.5,
      canInteract = function(entity)
        if not IsPedAPlayer(entity) then return false end
        if entity == PlayerPedId() then return false end
        local plyId = NetworkGetPlayerIndexFromPed(entity)
        if plyId == -1 then return false end
        local serverId = GetPlayerServerId(plyId)
        -- Visible seulement si CE joueur est escorté par MOI.
        return Player(serverId).state.escortedBy == GetPlayerServerId(PlayerId())
      end,
      onSelect = function(data)
        local plyId = NetworkGetPlayerIndexFromPed(data.entity)
        if plyId == -1 then return end
        local targetServerId = GetPlayerServerId(plyId)
        TriggerServerEvent('pop_inventory:server:toggleEscort', targetServerId)
      end,
    }
  })
end

CreateThread(function()
  Wait(1000) -- Attendre que ox_target soit disponible
  setupCardboardBoxTargets()
  setupPlayerTargets()
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end
  Inv.stopCarryingBox()
  Inv.stopCarryingSafe()
  Inv.MovingBox.active = false
end)
