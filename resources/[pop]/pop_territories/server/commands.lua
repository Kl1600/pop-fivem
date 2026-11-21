-- /territoryadmin info [zone] | reset <zone|all> | set <zone> <crewKey> <0-100>
-- Admin (Bridge.IsAdmin) ou console. Chargé avant main.lua : la table Territories n'est utilisée
-- qu'à l'intérieur du handler, à l'exécution.

local RES = GetCurrentResourceName()
local CMD = Config.Commands and Config.Commands.Admin or 'territoryadmin'

-- Réponse : notification au joueur, print en console. Les actions sont toujours journalisées en console.
local function reply(src, msg, notifyType)
    if src == 0 then
        print(('[%s] %s'):format(RES, msg))
    else
        Bridge.Notify(src, msg, notifyType or 'info')
    end
end

local function audit(src, msg)
    if src ~= 0 then print(('[%s] admin %s (%s): %s'):format(RES, GetPlayerName(src) or '?', src, msg)) end
end

local function validCrewKey(key)
    if type(key) ~= 'string' or #key > 64 then return false end
    return key:match('^crew:%d+$') ~= nil or key:match('^job:[%w_%-]+$') ~= nil
end

local function cmdInfo(src, args)
    local zone
    if args[2] then
        zone = Zones.Get(args[2])
        if not zone then return reply(src, L('admin_unknown_zone', args[2]), 'error') end
    elseif src ~= 0 then
        zone = Zones.At(Bridge.GetCoords(src))
        if not zone then return reply(src, L('notify_no_zone'), 'error') end
    else
        return reply(src, L('admin_usage', CMD), 'error')
    end

    local owner = Territories.GetOwner(zone.id)
    local parts = {}
    for i, entry in ipairs(Territories.GetZoneInfluence(zone.id)) do
        if i > 5 then break end
        parts[#parts + 1] = ('%s %d%%'):format(entry.label, math.floor(entry.value + 0.5))
    end
    reply(src, L('admin_info', L(zone.label), owner and owner.label or L('hud_unclaimed'), #parts > 0 and table.concat(parts, ', ') or '-'))
end

local function cmdReset(src, args)
    local target = args[2]
    if not target then return reply(src, L('admin_usage', CMD), 'error') end
    if target == 'all' then
        for _, zone in ipairs(Zones.List) do Territories.Reset(zone.id) end
        audit(src, 'reset all')
        return reply(src, L('admin_reset_all'), 'success')
    end
    local zone = Zones.Get(target)
    if not zone then return reply(src, L('admin_unknown_zone', target), 'error') end
    Territories.Reset(zone.id)
    audit(src, 'reset ' .. zone.id)
    reply(src, L('admin_reset', L(zone.label)), 'success')
end

local function cmdSet(src, args)
    local zoneArg, key, valueArg = args[2], args[3], args[4]
    if not zoneArg or not key or not valueArg then return reply(src, L('admin_usage', CMD), 'error') end
    local zone = Zones.Get(zoneArg)
    if not zone then return reply(src, L('admin_unknown_zone', zoneArg), 'error') end
    local value = tonumber(valueArg)
    if not validCrewKey(key) or not value or value ~= value or value < 0 or value > 100 then
        return reply(src, L('admin_bad_value'), 'error')
    end
    Territories.SetInfluence(zone.id, key, value)
    Territories.UpdateOwner(zone.id)
    audit(src, ('set %s %s %s'):format(zone.id, key, value))
    reply(src, L('admin_set', Territories.GetCrewLabel(key), L(zone.label), ('%g'):format(value)), 'success')
end

local SUB = { info = cmdInfo, reset = cmdReset, set = cmdSet }

RegisterCommand(CMD, function(src, args)
    src = tonumber(src) or 0
    if src ~= 0 and not Bridge.IsAdmin(src) then
        return Bridge.Notify(src, L('no_permission'), 'error')
    end
    if not Territories.IsLoaded() then return reply(src, L('error'), 'error') end

    local handler = SUB[type(args[1]) == 'string' and args[1]:lower() or '']
    if not handler then return reply(src, L('admin_usage', CMD), 'error') end
    handler(src, args)
end, false)
