-- pop_ems : transport à l'hôpital (sortir le patient, admission).

Callback.Register('pop_ems:unloadPatient', function(src, vehicleNetId)
    if not Ems.isOnDuty(src) then return false, 'not_on_duty' end
    if math.type(vehicleNetId) ~= 'integer' then return false, 'error' end
    local veh = Ems.getServiceEntity(vehicleNetId)
    if not veh then return false, 'no_vehicle' end
    if not Bridge.IsNear(src, GetEntityCoords(veh), Config.Distances.vehicle) then return false, 'too_far' end

    local patient = Ems.patientInVehicle(vehicleNetId)
    if not patient then return false, 'no_patient' end

    Ems.releaseTransport(patient, true)
    Ems.log('%s unloaded %s', src, patient)
    return true
end)

Callback.Register('pop_ems:admit', function(src, stationIndex)
    if not Ems.isOnDuty(src) then return false, 'not_on_duty' end
    local station = math.type(stationIndex) == 'integer' and Config.Stations[stationIndex] or nil
    if not station then return false, 'error' end
    if not Bridge.IsNear(src, station.dropoff, Config.Distances.zone + 1.0) then return false, 'too_far' end

    -- Patient transporté par CE secouriste, ambulance près de l'entrée.
    local dropoff = vector3(station.dropoff.x, station.dropoff.y, station.dropoff.z)
    local patient
    for p, t in pairs(Ems.transported) do
        if t.medic == src then
            local veh = Ems.getServiceEntity(t.vehicle)
            if veh and GetPlayerName(p) and #(GetEntityCoords(veh) - dropoff) <= Config.Distances.admit then
                patient = p
                break
            end
        end
    end
    if not patient then return false, 'no_patient' end

    Ems.releaseTransport(patient, false) -- le client du patient se détache lui-même à l'admission
    TriggerClientEvent('pop_ems:client:admitted', patient, station.bed)
    if Ems.closeCallOf(patient) then Ems.broadcastCalls(nil) end
    Ems.bill(patient, src, 'admit')
    TriggerEvent('pop_ems:admitted', patient, src, stationIndex)

    Bridge.Notify(src, L('patient_admitted', station.label), 'success')
    Bridge.Notify(patient, L('admitted_you', station.label), 'info')
    Ems.log('%s admitted %s at station %d', src, patient, stationIndex)
    return true
end)
