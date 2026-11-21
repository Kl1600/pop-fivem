Config = {}

-- ===== Clés communes POP (identiques au template) =====

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

-- ===== pop_dealing =====

-- Commande pour activer / arrêter la vente (assignable à une touche dans les paramètres GTA).
Config.Command = 'sell'

-- Drogues vendables : [nom de l'item] = { label = clé de locale, price = prix de la rue à l'unité, amount = { min, max } demandés }
Config.Drugs = {
    ['weed_white-widow'] = { label = 'drug_weed', price = 80,  amount = { 1, 3 } },
    ['cokebaggy']        = { label = 'drug_coke', price = 200, amount = { 1, 2 } },
    ['meth']             = { label = 'drug_meth', price = 150, amount = { 1, 2 } },
}

-- Paiement : 'black' (argent sale, repli sur 'cash' si le framework n'a pas ce compte) | 'cash' | 'item'
-- Standalone : utilisez 'item' (aucun compte d'argent sans framework).
Config.Payment = { type = 'black', item = 'black_money' } -- item : utilisé seulement si type = 'item'

-- Zones de deal. mult = multiplicateur du prix de la rue. Liste vide = vente possible partout.
-- Le mult se cumule avec le multiplicateur de pop_territories s'il est lancé : laissez 1.0 dans les zones couvertes par un territoire.
Config.Zones = {
    { coords = vec3(-1223.0, -1481.0, 4.4), radius = 100.0, mult = 1.0 }, -- Vespucci Beach
    { coords = vec3(167.0, -1717.0, 29.3),  radius = 90.0,  mult = 1.0 }, -- Strawberry
    { coords = vec3(80.0, -1956.0, 21.1),   radius = 100.0, mult = 1.0 }, -- Davis
    { coords = vec3(-165.0, -1620.0, 33.0), radius = 110.0, mult = 1.0 }, -- Forum Drive (= territoire pop_territories 'forum')
    { coords = vec3(1850.0, 3700.0, 33.0),  radius = 250.0, mult = 1.0 }, -- Sandy Shores (= territoire pop_territories 'sandy')
}

-- Clients PNJ (un à la fois par vendeur)
Config.Customers = {
    interval = { 20, 40 },     -- secondes avant le client suivant (aléatoire)
    distance = { 20.0, 45.0 }, -- distance d'apparition autour du joueur (m)
    timeout  = 90,             -- secondes avant qu'un client non servi reparte
    models = {
        'a_m_y_hipster_01', 'a_m_y_hipster_02', 'a_f_y_hipster_01', 'a_m_y_skater_01',
        'a_m_y_downtown_01', 'a_m_m_eastsa_01', 'a_f_y_runner_01', 'a_m_y_stbla_01',
    },
}

-- Négociation (multiplicateurs du prix de la rue)
Config.Negotiation = {
    attempts = 3,            -- propositions avant que le client parte
    range    = { 0.5, 2.0 }, -- bornes du prix proposable
    accept   = { 0.9, 1.4 }, -- prix maximum secret du client (tiré au hasard)
}

-- Flic infiltré : piège seulement si le deal est accepté
Config.Undercover = { chance = 0.05, seize = true, cooldown = 300 } -- seize : marchandise saisie ; cooldown en secondes

-- Témoins : chaque PNJ proche peut appeler la police lors d'une vente (risque x prix demandé / prix de la rue)
Config.Witnesses = { radius = 25.0, chance = 0.08, max = 5 }

-- Police
Config.Police = {
    jobs      = { 'police', 'sheriff' },
    minOnline = 0,      -- policiers en service requis pour vendre
    dispatch  = 'auto', -- 'auto' | 'ps-dispatch' | 'cd_dispatch' | 'qs-dispatch' | 'notify'
    blipTime  = 60,     -- secondes (blip du fallback 'notify' et de qs-dispatch)
}
