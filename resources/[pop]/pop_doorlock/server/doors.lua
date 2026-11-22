-- Chargement des portes, liste pour les clients et changement d'état.

-- Init : Config.Doors (statique + overrides) puis doors.json (Doorbuilder)
CreateThread(function()
    Doorlock.LoadOverrides()
    for i, group in ipairs(Config.Doors) do
        Doorlock.RegisterGroup(group, 'config', i)
    end

    local raw = LoadResourceFile(Doorlock.resName, 'doors.json')
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            for _, group in ipairs(decoded) do
                Doorlock.RegisterGroup(group, 'json')
            end
        end
    end

    Doorlock.Debug(L('doors_loaded', Doorlock.nextDoorId - 1, Doorlock.nextGid - 1))
end)

Callback.Register('pop_doorlock:getDoors', function()
    local list = {}
    for id in pairs(Doorlock.doors) do
        list[#list + 1] = Doorlock.DoorPayload(id)
    end
    return list
end)

RegisterNetEvent('pop_doorlock:changeState', function(doorId, state)
    local src = source
    if type(state) ~= 'boolean' or type(doorId) ~= 'number' then return end
    if Doorlock.doorState[doorId] == nil then return end
    -- Le joueur doit être près de la porte
    local d = Doorlock.doors[doorId]
    if not Bridge.IsNear(src, d.coords, (d.distance or 2.5) + 5.0) then return end
    if not Doorlock.PlayerHasAccess(src, doorId) then
        TriggerClientEvent('pop_doorlock:denied', src)
        return
    end

    Doorlock.doorState[doorId] = state
    TriggerClientEvent('pop_doorlock:changeDoorState', -1, doorId, state)
    TriggerClientEvent('pop_doorlock:toggled', src, state)
end)
