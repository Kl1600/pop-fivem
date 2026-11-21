Config = {}

-- =====================================================================
--  ACCÈS / PERMISSIONS
-- =====================================================================
-- Groupes ESX autorisés à ouvrir le menu.
Config.AdminGroups = {
    ['owner']      = true,
    ['superadmin'] = true,
    ['admin']      = true,
    ['mod']        = true,
}

-- En complément des groupes ESX, ces permissions ACE donnent aussi accès.
Config.AcePermissions = {
    'pop_admin.menu',
    'group.admin',
}

-- Identifiants (license:, steam:, discord:, fivem:) toujours autorisés.
Config.AdminIdentifiers = {
    'license:fe6e44aa749ef26aa5a611c9b0602fe392d96c0a',
    'license:caa2d6470d9a1391a46e911ff992e81ab6257193'
}

-- =====================================================================
--  TOUCHES
-- =====================================================================
Config.OpenKey    = 'F6'   -- ouvre / ferme le menu
Config.RevealKey  = 'G'    -- révèle la fenêtre quand elle est minimisée
Config.SpecKey    = 'F'    -- (en mode spec) déclenche les options sur la cible visée
Config.NoclipKey  = 'F7'   -- active / désactive le noclip (admin uniquement)

-- =====================================================================
--  GÉNÉRAL
-- =====================================================================
Config.DefaultView   = 'quick'  -- 'quick' ou 'full' à l'ouverture
Config.NoclipSpeed    = 1.0
Config.SpecMaxDist    = 80.0     -- portée du raycast du mode spec (m)

-- Météos disponibles (gestion du temps style easytime).
Config.Weathers = {
    'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'OVERCAST', 'SMOG', 'FOGGY',
    'RAIN', 'THUNDER', 'CLEARING', 'NEUTRAL', 'SNOW', 'BLIZZARD',
    'SNOWLIGHT', 'XMAS', 'HALLOWEEN',
}

-- État du temps au démarrage du serveur.
Config.DefaultTime = { hour = 12, minute = 0, frozen = false }
Config.DefaultWeather = 'EXTRASUNNY'

-- Modèles de ped proposés pour « incarner » un perso admin.
Config.PedModels = {
    { label = 'Joueur (Michael)', model = 'player_zero' },
    { label = 'Joueur (Franklin)', model = 'player_one' },
    { label = 'Joueur (Trevor)',   model = 'player_two' },
    { label = 'Agent FIB',         model = 's_m_m_fibsec_01' },
    { label = 'Policier',          model = 's_m_y_cop_01' },
    { label = 'Médecin',           model = 's_m_m_doctor_01' },
    { label = 'Costume noir',      model = 'a_m_y_business_01' },
    { label = 'Civil aléatoire',   model = 'a_m_y_skater_01' },
}

-- Véhicules rapides du menu rapide.
Config.QuickVehicles = {
    'adder', 'sultanrs', 'kuruma', 'baller', 'police', 'ambulance',
}

-- =====================================================================
--  LOGS DE DÉCONNEXION
-- =====================================================================
-- Nombre maximum d'entrées conservées (les plus anciennes sont purgées).
Config.LogsMax = 300
