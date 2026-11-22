-- pop_vehiclepersistence — client : notifications (pop_notify via le bridge POP).
-- Export Notify utilisé par pop_enterprisegarage.

local function Notify(msg, ntype)
    -- Override total possible via config (cas exotiques)
    if Config.CustomNotify then
        return Config.CustomNotify(msg, ntype)
    end
    Bridge.Notify(msg, ntype)
end

RegisterNetEvent('pop_vehiclepersistence:notify', function(msg, ntype)
    Notify(msg, ntype)
end)

exports('Notify', function(msg, ntype) Notify(msg, ntype) end)
