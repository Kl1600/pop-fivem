Callback.Register('pop_computer:open', function(src, index)
    if math.type(index) ~= 'integer' then return false, 'error' end
    local terminal = Config.Terminals[index]
    if not terminal or not Bridge.GetIdentifier(src) or Bridge.IsDead(src) then return false, 'error' end
    if terminal.bucket ~= nil and GetPlayerRoutingBucket(src) ~= terminal.bucket then return false, 'too_far' end
    if not Bridge.IsNear(src, terminal.coords, Config.InteractionDistance) then return false, 'too_far' end
    if terminal.ace and not IsPlayerAceAllowed(src, terminal.ace) then return false, 'no_permission' end
    if terminal.jobs and not Bridge.HasJob(src, terminal.jobs) then return false, 'wrong_job' end
    local job = Bridge.GetJob(src)
    if terminal.onDuty and (not job or not job.onDuty) then return false, 'wrong_job' end
    return true, nil, {
        name = Bridge.GetName(src) or GetPlayerName(src),
        job = job and job.label,
        time = os.date('!%Y-%m-%d %H:%M'),
    }
end)
