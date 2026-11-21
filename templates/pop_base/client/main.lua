-- Exemple minimal : à remplacer par le code du script.
-- Un point d'interaction qui lance une barre de progression puis demande une récompense au serveur.

local POINT = vec3(215.76, -810.12, 30.73) -- exemple : parking de Legion Square

Bridge.OnPlayerLoaded(function()
    Bridge.Target.AddBoxZone('pop_base_example', POINT, vec3(1.5, 1.5, 2.0), 0.0, {
        {
            label = L('interact'),
            icon = 'fa-solid fa-hand',
            distance = 2.0,
            onSelect = function()
                if not Bridge.Progress(L('interact'), 3000, { anim = { dict = 'mp_common', clip = 'givetake1_a' } }) then
                    return
                end
                local ok, reason, arg = Callback.Await('pop_base:example')
                if not ok then Bridge.Notify(L(reason or 'error', arg), 'error') end
            end,
        },
    })
end)
