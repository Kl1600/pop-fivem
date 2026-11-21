Config = {}

-- Langue : en, fr, es, de, it, pt, nl, pl, tr, ar (une clé absente retombe sur 'en').
Config.Locale = 'en'

-- Affiche les messages de diagnostic dans la console.
Config.Debug = false

-- 'auto' détecte ce qui est lancé. Sinon, forcer :
Config.Framework = 'auto' -- 'esx' | 'qbcore' | 'qbox' | 'standalone'
Config.Inventory = 'auto' -- 'pop_inventory' | 'ox_inventory' | 'qs-inventory' | 'qb-inventory' | 'ps-inventory' | 'framework' | 'none'
Config.Target    = 'auto' -- 'ox_target' | 'qb-target' | 'prompt'
Config.Notify    = 'auto' -- 'framework' | 'ox_lib' | 'pop' | 'native'

-- Couleur d'accent de l'interface. Rose néon par défaut, cyan : '#22d3ee'.
Config.AccentColor = '#ff2e88'

-- Touches (numéros de contrôle GTA : https://docs.fivem.net/docs/game-references/controls/).
Config.Keys = {
    Interact = { control = 38, label = 'E' }, -- prompt natif (sans ox_target / qb-target)
    Cancel   = { control = 73, label = 'X' }, -- annuler une barre de progression
}

-- Anti-spam des callbacks : appels max par seconde, par joueur et par callback (0 = illimité).
Config.CallbackRateLimit = 10

Config.MenuKey = 'F3'
Config.CancelKey = 'X'
Config.InviteDistance = 2.5
Config.InviteSeconds = 15
Config.InviteCooldown = 5

Config.Catalog = {
    wave = { label = 'emote_wave', dict = 'friends@frj@ig_1', clip = 'wave_a', duration = 3000, flag = 48 },
    thumbs = { label = 'emote_thumbs', dict = 'anim@mp_player_intselfiethumbs_up', clip = 'idle_a', duration = 2500, flag = 48 },
    salute = { label = 'emote_salute', dict = 'anim@mp_player_intincarsalutestd@ds@', clip = 'idle_a', duration = 3000, flag = 48 },
    clap = { label = 'emote_clap', dict = 'amb@world_human_cheering@male_a', clip = 'base', duration = 5000, flag = 49 },
    dance = { label = 'emote_dance', dict = 'anim@amb@nightclub@dancers@solomun_entourage@', clip = 'mi_dance_facedj_17_v1_male^2', duration = 8000, flag = 1 },
    celebrate = { label = 'emote_celebrate', dict = 'anim@mp_player_intcelebrationmale@air_guitar', clip = 'air_guitar', duration = 3500, flag = 0 },
    handshake = { label = 'emote_handshake', dict = 'mp_ped_interaction', clip = 'handshake_guy_a', reply = 'handshake_guy_b', duration = 3000, flag = 0, shared = true },
}
