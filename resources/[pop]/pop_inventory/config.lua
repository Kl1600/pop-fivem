Config = {}

-- Langue : en, fr, es, de, it, pt, nl, pl, tr, ar (une clé absente retombe sur 'en').
Config.Locale = 'en'

-- Affiche les messages de diagnostic dans la console.
Config.Debug = false

-- 'auto' détecte ce qui est lancé. Sinon, forcer :
Config.Framework = 'auto' -- 'esx' | 'qbcore' | 'qbox' | 'standalone'
Config.Inventory = 'none' -- ne pas changer : pop_inventory ne passe jamais par le Bridge pour ses propres items
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
Config.CallbackRateLimit = 15

-- pop_inventory ------------------------------------------------------------

Config.OpenKey   = 'TAB'    -- touche par défaut (chaque joueur peut la changer dans les paramètres FiveM)
Config.Slots     = 40       -- slots du joueur (1 à 5 = hotbar)
Config.MaxWeight = 30000    -- poids max du joueur, en grammes

-- Argent physique : nom d'un item (ex. 'money') synchronisé avec le compte 'cash' du framework.
-- false = l'argent reste un compte du framework.
Config.CashItem = false

-- Importe les définitions d'items du framework absentes de data/items.lua,
-- et l'ancien inventaire d'un personnage à son premier chargement.
Config.ImportFramework = true

-- Les scripts tiers qui utilisent l'inventaire du framework (xPlayer / Player.Functions) passent par pop_inventory.
Config.FrameworkHooks = true

Config.SaveInterval  = 300   -- secondes entre deux sauvegardes des inventaires modifiés
Config.GiveDistance  = 3.0   -- mètres pour donner un item

-- Commande de fouille d'un joueur mort ou menotté (false = désactivée).
Config.SearchCommand = 'search'

Config.Drops = {
    Model     = 'prop_paper_bag_small',
    Slots     = 20,
    MaxWeight = 100000,
    Distance  = 2.0,     -- portée pour ouvrir un dépôt (mètres)
    Lifetime  = 1800,    -- secondes avant disparition d'un dépôt
}

Config.Vehicles = {
    Glovebox = { slots = 5, weight = 10000 },
    -- Coffre selon le type de véhicule (GetVehicleType côté serveur). Type absent = pas de coffre.
    Trunk = {
        automobile = { slots = 25, weight = 60000 },
        quadbike   = { slots = 5,  weight = 15000 },
        boat       = { slots = 20, weight = 50000 },
        heli       = { slots = 15, weight = 40000 },
        plane      = { slots = 20, weight = 60000 },
        trailer    = { slots = 50, weight = 200000 },
        submarine  = { slots = 10, weight = 20000 },
    },
    -- Surcharge du coffre par modèle : ['burrito3'] = { slots = 40, weight = 150000 },
    Models = {},
}

-- label : clé de locale si elle existe, sinon texte affiché tel quel.
-- jobs : format Bridge.HasJob (nil = tout le monde). owner = true : un stockage par personnage.
Config.Stashes = {
    { id = 'police_locker', label = 'stash_police', coords = vec3(461.45, -996.30, 30.69),
      slots = 50, weight = 100000, jobs = { police = 0 }, owner = true },
}

-- account : 'cash' ou 'bank'. blip : nil = aucun blip. Un article accepte aussi metadata = {} et jobs = {}.
Config.Shops = {
    { id = 'general', label = 'shop_general', account = 'cash',
      coords = { vec3(25.74, -1347.30, 29.49), vec3(-3039.0, 585.9, 7.9) },
      blip = { sprite = 52, color = 2 },
      items = {
          { name = 'water_bottle', price = 5 },
          { name = 'bread',        price = 6 },
          { name = 'bandage',      price = 25 },
      } },
    { id = 'ammunation', label = 'shop_ammunation', account = 'bank',
      coords = { vec3(22.0, -1107.2, 29.8) },
      blip = { sprite = 110, color = 1 },
      items = {
          { name = 'weapon_pistol', price = 2500 },
          { name = 'ammo_pistol',   price = 2 },
          { name = 'weapon_knife',  price = 200 },
      } },
}
