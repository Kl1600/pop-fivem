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

-- Couleur d'accent de l'interface. Bleu POP Tab par défaut.
Config.AccentColor = '#0088FF'

-- Objet « argent liquide » de pop_inventory (lu par le bridge ; pop_tablet ne touche pas à l'argent).
Config.CashItem = 'cash'

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
Config.Key = 'F2'

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
    HashBudgetPerSec = 20,   -- hachages de code max par seconde, tous joueurs confondus
}

-- Batterie calculée par horodatage, sans minuterie : -1 % par DrainMinutes ouvertes, +1 % par ChargeMinutes fermées.
Config.Battery = { Enabled = true, MinToOpen = 5, DrainMinutes = 6, ChargeMinutes = 1 }

-- Numéro de téléphone propre à chaque tablette : '#' = un chiffre.
Config.Phone = { Format = '###-####', ChannelBase = 9000, RingSeconds = 25 }

-- Adresses mail : <nom>@<Domain>.
Config.Mail = { Domain = 'pop.ls' }

-- Horloge : heure réelle du joueur (GetLocalTime), rien à régler.

-- Photos : 'database' (défaut, aucun secret). 'remote' n'est PAS disponible (renvoie err_unavailable), voir README.
Config.Photos = { Mode = 'database', Url = '', FormField = 'file', UrlPath = 'url', Max = 200 }

-- Appareil photo : 'scripted' (défaut : caméra CreateCam à hauteur des yeux, aucun téléphone en main) ou 'native'
-- (CreateMobilePhone + CellCamActivate : un téléphone apparaît en main). Fov = champs de vision pour 0,5x, 1x, 2x ;
-- Selfie = position relative à la tête (droite, avant, haut), inclinaison et champ de vision ; Sens = vitesse de l'orientation libre (Alt).
Config.Camera = { mode = 'scripted', Fov = { 75.0, 50.0, 25.0 }, Selfie = { Offset = { 0.05, 0.55, 0.0 }, Pitch = 10.0, Fov = 60.0 }, Sens = 8.0 }

-- Partage de proximité (mètres).
Config.Share = { Distance = 3.0 }

-- Applis optionnelles : 'on' | 'off' | 'auto'.
Config.Apps = { dictaphone = 'on', translate = 'on' }

-- Pages https autorisées pour les applis de l'API (RegisterApp) et pour le Navigateur : liste de noms d'hôte.
Config.Browser = { AllowedHosts = {} }

-- Musique : radios et flux lus par un élément audio dans la page de la tablette (https obligatoire).
-- `name` : 40 caractères au plus ; `tag` : genre affiché (facultatif, 12 caractères). Remplacer par vos propres flux.
Config.Music = {
    Stations = {
        { name = 'Groove Salad', tag = 'CHILL', url = 'https://ice1.somafm.com/groovesalad-128-mp3' },
        { name = 'Secret Agent', tag = 'LOUNGE', url = 'https://ice1.somafm.com/secretagent-128-mp3' },
        { name = 'Space Station', tag = 'ELECTRO', url = 'https://ice1.somafm.com/spacestation-128-mp3' },
    },
}

-- Météo : nom de ville affiché (nom propre, pas traduit). La température est déduite du type de météo du jeu et de l'heure.
Config.Weather = { City = 'Los Santos' }

-- Plans : lieux ajoutés à ceux de shared/places.lua (même format ; un `id` identique remplace le lieu d'origine).
-- Exemple : { id = 'mairie', name = 'Mairie', short = 'Mairie', area = 'Rockford', cat = 'public', addr = '1 Main St',
--             phone = '(555) 0001', hours = 'h24', icon = 'shield', col = '#30509c', x = -540.0, y = -200.0, z = 38.0, mx = 1000, my = 600 }
Config.Places = {}

-- Traduire : sans service, l'appli traduit hors ligne (dictionnaire embarqué, jamais masquée).
-- Url : adresse d'un service compatible LibreTranslate (POST JSON { q, source, target, format, api_key }, réponse { translatedText }).
-- La clé éventuelle se règle dans la convar serveur `set pop_tablet_translate_key "..."` (jamais dans ce fichier).
Config.Translate = { Url = '', MaxChars = 500, CacheSize = 200, TimeoutSeconds = 8 }

-- Bourse : pas de la simulation en secondes réelles. Elle ne tourne que si une tablette a l'appli ouverte.
Config.Market = { TickSeconds = 5 }

-- Coque d'appareil (bords, boutons marche et volume) autour de l'écran. false = écran seul.
Config.Shell = true

-- Messages et appels plus vieux que ce nombre de jours sont supprimés au démarrage du serveur (jamais en boucle).
Config.Retention = { Days = 90 }
