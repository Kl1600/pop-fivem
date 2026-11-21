-- Liste des tatouages (tattoos.json), tatouages du joueur (variable ESX + colonne users.tattoos).

local tattooListRaw = nil

CreateThread(function()
    tattooListRaw = LoadResourceFile(GetCurrentResourceName(), "tattoos.json")
    if not tattooListRaw then
        print("^1[pop_clothes] Error: Failed to load tattoos.json on the server!^0")
        return
    end
    local ok, list = pcall(json.decode, tattooListRaw)
    if ok and type(list) == 'table' then
        local allowed = Clothes.AllowedTattoos
        for _, zoneList in pairs(list) do
            for _, t in ipairs(zoneList) do
                if t.collection then
                    if t.hashMale and t.hashMale ~= '' then allowed[t.collection .. '|' .. t.hashMale] = true end
                    if t.hashFemale and t.hashFemale ~= '' then allowed[t.collection .. '|' .. t.hashFemale] = true end
                end
            end
        end
    end
end)

RegisterNetEvent('clothes:requestTattooList')
AddEventHandler('clothes:requestTattooList', function()
    local src = source
    if tattooListRaw then
        TriggerClientEvent('clothes:setTattooList', src, tattooListRaw)
    end
end)

RegisterNetEvent('clothes:requestTattoos')
AddEventHandler('clothes:requestTattoos', function()
    local src = source
    local xPlayer = Clothes.ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local memTattoos = xPlayer.get('tattoos')
    if memTattoos then
        TriggerClientEvent('clothes:applyTattoos', src, memTattoos)
    else
        if MySQL then
            MySQL.query('SELECT tattoos FROM users WHERE identifier = ?', {xPlayer.identifier}, function(result)
                local tattoos = {}
                if result and result[1] and result[1].tattoos then
                    tattoos = json.decode(result[1].tattoos) or {}
                end
                xPlayer.set('tattoos', tattoos)
                TriggerClientEvent('clothes:applyTattoos', src, tattoos)
            end)
        else
            xPlayer.set('tattoos', {})
            TriggerClientEvent('clothes:applyTattoos', src, {})
        end
    end
end)

RegisterNetEvent('clothes:clearTattoos')
AddEventHandler('clothes:clearTattoos', function()
    local src = source
    local xPlayer = Clothes.ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    xPlayer.set('tattoos', {})
    MySQL.update('UPDATE users SET tattoos = ? WHERE identifier = ?', { '[]', xPlayer.identifier })
    TriggerClientEvent('clothes:applyTattoos', src, {})
end)

CreateThread(function()
    while not MySQL do Wait(500) end
    MySQL.query('SHOW COLUMNS FROM users LIKE "tattoos"', {}, function(result)
        if not result or #result == 0 then
            MySQL.query('ALTER TABLE users ADD COLUMN tattoos LONGTEXT NULL')
            print('^2[pop_clothes] Added tattoos column to users table.^0')
        end
    end)
end)
