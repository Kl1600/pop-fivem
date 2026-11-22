Config = {}

-- Langue du serveur : en, fr, es, de, it, pt, nl, pl, tr, ar (une clé absente retombe sur 'en').
-- Chaque tablette a sa propre langue (réglage de l'appareil) ; celle-ci sert aux messages serveur et au premier allumage.
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

------------------------------------------------------------------------
-- Textes propres à pop_tablet
------------------------------------------------------------------------

-- Objet d'inventaire. Il doit exister dans l'inventaire du serveur (voir README).
Config.Item = 'pop_tablet'

-- Touche d'ouverture par défaut (le joueur la change dans les paramètres de touches de FiveM).
Config.Key = 'F5'

-- Objet tenu en main et animation. Valeurs à valider en jeu (elles dépendent des fichiers du jeu).
Config.Prop = { model = 'prop_cs_tablet', bone = 28422, offset = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) }
Config.Anim = { dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', clip = 'base' }

-- Session : la tablette se reverrouille après ce délai sans appel (contrôlé à l'appel, sans minuterie).
Config.Session = { IdleLockSeconds = 120 }

-- Sécurité du code à 4 chiffres. Le poivre vient de la convar serveur `set pop_tablet_pepper "..."` (jamais setr).
Config.Security = {
    HashIterations   = 2000, -- itérations HMAC-SHA256 du code
    MaxFails         = 5,    -- échecs avant blocage
    LockBaseSeconds  = 60,   -- premier blocage, doublé à chaque échec suivant
    LockMaxSeconds   = 3600,
    UnlockRatePerSec = 2,    -- tentatives max par seconde et par joueur
}

-- Batterie calculée par horodatage, sans minuterie : -1 % par DrainMinutes ouvertes, +1 % par ChargeMinutes fermées.
Config.Battery = { Enabled = true, MinToOpen = 5, DrainMinutes = 6, ChargeMinutes = 1 }

-- Numéro de téléphone propre à chaque tablette : '#' = un chiffre.
Config.Phone = { Format = '###-####', ChannelBase = 9000, RingSeconds = 25 }

-- Adresses mail : <nom>@<Domain>.
Config.Mail = { Domain = 'pop.ls' }

-- Horloge : MsPerGameMinute sert si la native du jeu ne répond pas. Zones = horloges du monde fictives (décalage en heures).
Config.Clock = { Source = 'game', MsPerGameMinute = 2000, Zones = {} }

-- Photos : 'database' (défaut, aucun secret) ou 'remote' (clé en convar `set pop_tablet_photo_key`).
Config.Photos = { Mode = 'database', Url = '', FormField = 'file', UrlPath = 'url', Max = 200 }

-- Partage de proximité (mètres).
Config.Share = { Distance = 3.0 }

-- Applis optionnelles : 'on' | 'off' | 'auto'.
Config.Apps = { dictaphone = 'on', translate = 'on' }

-- Pages https autorisées pour les applis de l'API (RegisterApp) et pour le Navigateur : liste de noms d'hôte.
Config.Browser = { AllowedHosts = {} }

-- Météo : nom de ville affiché (nom propre, pas traduit). La température est déduite du type de météo du jeu et de l'heure.
Config.Weather = { City = 'Los Santos' }

-- Coque d'appareil autour de l'écran : réservée au navigateur de développement. Laisser false en jeu (plein écran).
Config.Shell = false

-- Messages et appels plus vieux que ce nombre de jours sont supprimés au démarrage du serveur (jamais en boucle).
Config.Retention = { Days = 90 }
