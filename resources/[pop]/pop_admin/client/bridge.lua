-- =====================================================================
--  PONTS : items (pop_inventory), jobs, véhicules, temps & météo
-- =====================================================================

-- ---------- ITEMS (catalogue fourni par pop_inventory) ----------
RegisterNetEvent('pop_inventory:client:setAdminItems', function(items)
    AdminSend('items', { list = items or {} })
end)

RegisterNUICallback('requestItems', function(_, cb)
    if GetResourceState('pop_inventory') == 'started' then
        TriggerServerEvent('pop_inventory:server:adminRequestItems')
    end
    cb({})
end)

RegisterNUICallback('giveItem', function(data, cb)
    local item = tostring(data.item or '')
    local qty = tonumber(data.qty) or 1
    if item == '' then cb({}); return end
    if data.target and tonumber(data.target) then
        TriggerServerEvent('pop_admin:playerAction', {
            action = 'giveitem', target = tonumber(data.target), item = item, qty = qty,
        })
    else
        TriggerServerEvent('pop_admin:giveSelf', item, qty)
    end
    cb({})
end)

-- ---------- JOBS ----------
RegisterNetEvent('pop_admin:receiveJobs', function(jobs)
    AdminSend('jobs', { list = jobs or {} })
end)

RegisterNUICallback('jobAction', function(data, cb)
    local do_ = data.do_
    if do_ == 'setself' then
        TriggerServerEvent('pop_admin:jobSetSelf', data.job, tonumber(data.grade) or 0)
    elseif do_ == 'setplayer' then
        TriggerServerEvent('pop_admin:playerAction', {
            action = 'setjob', target = tonumber(data.target),
            job = data.job, grade = tonumber(data.grade) or 0,
        })
    elseif do_ == 'create' then
        TriggerServerEvent('pop_admin:jobCreate', data.name, data.label)
    elseif do_ == 'addgrade' then
        TriggerServerEvent('pop_admin:jobAddGrade', data.job, tonumber(data.level) or 0,
            data.gname, data.glabel, tonumber(data.salary) or 0)
    elseif do_ == 'society' then
        TriggerServerEvent('pop_admin:jobSociety', data.job, tonumber(data.amount) or 0)
    elseif do_ == 'delete' then
        TriggerServerEvent('pop_admin:jobDelete', data.job)
    end
    SetTimeout(700, function() TriggerServerEvent('pop_admin:requestJobs') end)
    cb({})
end)

-- ---------- VÉHICULES PERSISTANTS ----------
RegisterNetEvent('pop_admin:receiveVehicles', function(list)
    AdminSend('vehicles', { list = list or {} })
end)

RegisterNetEvent('pop_admin:vehicleDeleted', function(_)
    SetTimeout(300, function() TriggerServerEvent('pop_admin:requestVehicles') end)
end)

RegisterNUICallback('vehicleAction', function(data, cb)
    if data.do_ == 'goto' and data.x then
        local x, y, z = data.x + 0.0, data.y + 0.0, data.z + 0.0
        AdminClose()
        local ped = PlayerPedId()
        SetEntityCoords(ped, x, y, z + 1.0, false, false, false, true)
        AdminNotify(('Téléporté au véhicule %s'):format(tostring(data.plate or '')), 'success')
    elseif data.do_ == 'delete' then
        TriggerServerEvent('pop_admin:deleteVehicle', data.plate)
    end
    cb({})
end)

-- ---------- TEMPS & MÉTÉO ----------
RegisterNUICallback('setTime', function(data, cb)
    TriggerServerEvent('pop_admin:setTime', tonumber(data.hour) or 12, tonumber(data.minute) or 0, data.frozen)
    cb({})
end)

RegisterNUICallback('freezeTime', function(data, cb)
    TriggerServerEvent('pop_admin:freezeTime', data.frozen == true)
    cb({})
end)

RegisterNUICallback('setWeather', function(data, cb)
    TriggerServerEvent('pop_admin:setWeather', data.weather)
    cb({})
end)

RegisterNUICallback('setBlackout', function(data, cb)
    TriggerServerEvent('pop_admin:setBlackout', data.state == true)
    cb({})
end)
