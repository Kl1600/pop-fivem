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

-- ─── pop_exchange ───────────────────────────────────────────

-- Offres. from / to : { money = 'cash' | 'bank' | 'black' } ou { item = 'nom' }.
-- rate  : quantité reçue pour 1 donnée (résultat arrondi à l'inférieur).
-- limit : quantité max donnée par heure et par joueur.
-- alert : chance d'alerter la police à chaque échange (0 = jamais).
-- Libellés des monnaies : locales currency_<nom>.
Config.Offers = {
    usd_pesos = { from = { money = 'cash' }, to = { item = 'pesos' },  rate = 20.0,  limit = 10000,  alert = 0.0 },
    pesos_usd = { from = { item = 'pesos' }, to = { money = 'cash' },  rate = 0.045, limit = 200000, alert = 0.0 },
    launder   = { from = { money = 'black' }, to = { money = 'cash' }, rate = 0.7,   limit = 20000,  alert = 0.15 },
}

-- Quantités par défaut. Une offre peut définir son propre tableau amounts.
Config.Amounts = { 1, 10, 25, 100, 500, 1000, 5000, 10000 }

-- Bureaux. offers = ids proposés ici. ped = modèle du PNJ (false : zone). blip = afficher sur la carte.
Config.Locations = {
    { coords = vector4(-639.07, -180.47, 37.68, 33.0), ped = 's_m_m_cntrybar_01', blip = true,
      offers = { 'usd_pesos', 'pesos_usd' } },
    { coords = vector4(474.05, -1309.83, 29.21, 115.0), ped = 'g_m_m_armboss_01', blip = false,
      offers = { 'launder' } },
}

Config.Blip = { sprite = 500, color = 2, scale = 0.8 }

Config.Police = {
    jobs     = { 'police', 'sheriff' }, -- format Bridge.HasJob ; doivent être en service
    blipTime = 60,                      -- durée du blip d'alerte (secondes)
}
