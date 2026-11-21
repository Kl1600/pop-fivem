-- Constantes et utilitaires partagés (chargé côté client et serveur).

Keys = {}
Keys.ACTION_DISTANCE = 3.0    -- serrurier (serveur : Bridge.IsNear)
Keys.LOCK_TOLERANCE  = 2.0    -- marge serveur ajoutée à Config.LockDistance
Keys.FX_RADIUS       = 30.0   -- joueurs qui reçoivent bip + feux
Keys.LOCK_COOLDOWN   = 1000   -- ms entre deux verrouillages d'un même joueur (serveur)
Keys.ENGINE_RECHECK  = 5000   -- ms : nouvelle demande au serveur tant qu'on est au volant sans clé
Keys.ENGINE_RECHECK_OWNED = 30000 -- ms : revérification même avec la clé (clé donnée / retirée en route)
Keys.ENGINE_RETRY    = 500    -- ms : nouvelle demande quand le serveur ne voit pas encore le joueur dans le véhicule

-- Plaque comparable : sans espaces, en majuscules, 8 caractères max. nil si vide ou invalide.
function Keys.Normalize(plate)
    if type(plate) ~= 'string' then return nil end
    plate = plate:gsub('%s+', ''):upper()
    if plate == '' or #plate > 8 or plate:find('[^%w]') then return nil end
    return plate
end
