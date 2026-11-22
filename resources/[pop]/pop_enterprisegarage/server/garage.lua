-- pop_enterprisegarage — liste, sortie, clés et rangement

-- Clés autorisées : uniquement pour un véhicule que ce joueur vient de sortir.
local pendingKeys = {}
AddEventHandler('playerDropped', function() pendingKeys[source] = nil end)

-- ── Liste de la flotte ───────────────────────────────────────────────────────
RegisterNetEvent('pop_enterprisegarage:requestList', function(garageName)
    local src = source
    local garage = Garage.FindGarage(garageName)
    if not Garage.CanUse(src, garage) then return end

    MySQL.query(
        'SELECT model, label, plate, state FROM enterprise_garage_vehicles WHERE garage = ? ORDER BY label',
        { garageName },
        function(rows)
            TriggerClientEvent('pop_enterprisegarage:openMenu', src, {
                garage   = garageName,
                vehicles = rows or {},
            })
        end
    )
end)

-- ── Sortir un véhicule ───────────────────────────────────────────────────────
RegisterNetEvent('pop_enterprisegarage:takeOut', function(garageName, plate)
    local src = source
    local garage = Garage.FindGarage(garageName)
    if not Garage.CanUse(src, garage) then return end
    plate = Garage.NormalPlate(plate)

    MySQL.query(
        'SELECT model, props, state FROM enterprise_garage_vehicles WHERE garage = ? AND plate = ?',
        { garageName, plate },
        function(rows)
            local row = rows and rows[1]
            if not row then return end
            local fromState = 'in'
            if row.state ~= 'in' then
                -- Véhicule sorti : récupérable seulement s'il n'existe plus dans le monde
                -- (détruit, supprimé, ou rangé loin de tout joueur). Sinon : déjà sorti.
                local veh = Garage.FindVehicleByPlate(plate)
                if veh and not Garage.IsWrecked(veh) then
                    Bridge.Notify(src, L('already_out'))
                    return
                end
                if veh then DeleteEntity(veh) end
                Garage.ForgetPersistent(plate)
                fromState = row.state
            end
            -- Passage atomique -> 'out' : empêche une double sortie simultanée.
            MySQL.update(
                'UPDATE enterprise_garage_vehicles SET state = ? WHERE garage = ? AND plate = ? AND state = ?',
                { 'out', garageName, plate, fromState },
                function(affected)
                    if not affected or affected == 0 then return end
                    local props = nil
                    if row.props and row.props ~= '' then
                        local ok, decoded = pcall(json.decode, row.props)
                        if ok then props = decoded end
                    end
                    pendingKeys[src] = pendingKeys[src] or {}
                    pendingKeys[src][plate] = true
                    TriggerClientEvent('pop_enterprisegarage:spawn', src, {
                        model = row.model,
                        plate = plate,
                        props = props,
                        spawn = garage.spawn,
                    })
                end
            )
        end
    )
end)

-- ── Clés (pop_inventory) après spawn ─────────────────────────────────────────
RegisterNetEvent('pop_enterprisegarage:giveKeys', function(plate)
    local src = source
    plate = Garage.NormalPlate(plate)
    if not pendingKeys[src] or not pendingKeys[src][plate] then return end
    pendingKeys[src][plate] = nil
    Garage.GiveKeys(src, plate)
end)

-- ── Ranger un véhicule ───────────────────────────────────────────────────────
-- Contrôles serveur : véhicule de ce garage, sorti ('out'), entité réelle portant
-- cette plaque et ce modèle, à côté du joueur. Empêche la duplication.
local storing = {}

RegisterNetEvent('pop_enterprisegarage:store', function(garageName, plate, props, netId)
    local src = source
    local garage = Garage.FindGarage(garageName)
    if not Garage.CanUse(src, garage) then return end
    plate = Garage.NormalPlate(plate)
    if plate == '' or storing[plate] then return end

    local veh = tonumber(netId) and NetworkGetEntityFromNetworkId(tonumber(netId)) or 0
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2
        or Garage.NormalPlate(GetVehicleNumberPlateText(veh)) ~= plate then
        Bridge.Notify(src, L('nothing_to_store'))
        return
    end
    if not Bridge.IsNear(src, GetEntityCoords(veh), Config.StoreDistance) then
        Bridge.Notify(src, L('get_closer'))
        return
    end

    storing[plate] = true
    MySQL.query(
        'SELECT model, state FROM enterprise_garage_vehicles WHERE garage = ? AND plate = ?',
        { garageName, plate },
        function(rows)
            local row = rows and rows[1]
            if not row then
                storing[plate] = nil
                Bridge.Notify(src, L('not_this_garage'))
                return
            end
            if row.state ~= 'out' then
                storing[plate] = nil
                Bridge.Notify(src, L('already_in'))
                return
            end
            if math.tointeger(GetEntityModel(veh) % 4294967296) ~= math.tointeger(GetHashKey(row.model) % 4294967296) then
                storing[plate] = nil
                Bridge.Notify(src, L('not_this_garage'))
                return
            end

            -- Props : table de taille raisonnable, plaque et modèle forcés
            local propsJson = nil
            if type(props) == 'table' then
                props.plate = plate
                props.model = GetHashKey(row.model)
                local ok, encoded = pcall(json.encode, props)
                if ok and encoded and #encoded <= 16000 then propsJson = encoded end
            end

            MySQL.update(
                'UPDATE enterprise_garage_vehicles SET state = ?, props = ? WHERE garage = ? AND plate = ? AND state = ?',
                { 'in', propsJson, garageName, plate, 'out' },
                function(affected)
                    storing[plate] = nil
                    if not affected or affected == 0 then return end
                    -- Collaboration : retire la plaque de la persistance (mémoire + base).
                    Garage.ForgetPersistent(plate)
                    Garage.TakeKeys(src, plate)
                    TriggerClientEvent('pop_enterprisegarage:confirmStore', src, plate)
                    -- Filet de sécurité : supprime l'entité si le client ne l'a pas fait.
                    SetTimeout(2000, function()
                        if DoesEntityExist(veh) then DeleteEntity(veh) end
                    end)
                end
            )
        end
    )
end)
