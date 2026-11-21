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

-- ─── pop_police ─────────────────────────────────────────────

-- Jobs de police (format Bridge.HasJob). En standalone : ACE 'pop.police' (voir README).
Config.Jobs = { 'police', 'sheriff' }

-- Thème de l'interface : 'modern' (couleur d'accent ci-dessus) ou 'retro80' (terminal ambre années 80).
Config.Theme = 'modern'

-- Touches par défaut (chaque joueur peut les changer dans les paramètres FiveM).
Config.KeyMappings = {
    menu        = 'F6',
    panic       = 'F9',
    acceptFine  = 'Y',
    declineFine = 'BACK',
}

-- Item requis pour menotter (non consommé). false = aucun item.
Config.Handcuffs = 'handcuffs'

-- Durée des actions (ms).
Config.Durations = { cuff = 2500, uncuff = 2000, search = 3000 }

-- Amendes : montant borné, compte débité ('bank' ou 'cash'), délai de réponse de la personne (secondes).
Config.Fines = { min = 50, max = 10000, account = 'bank', timeout = 30, amounts = { 50, 100, 250, 500, 1000, 2500, 5000, 10000 } }

-- Bouton panique : délai entre deux alertes d'un même agent et durée du blip (secondes).
Config.Panic = { cooldown = 30, blipTime = 90 }

-- Grade minimum pour supprimer la note d'un collègue (chacun peut supprimer les siennes).
Config.BossGrade = 3

-- Commissariats : point de service, et vestiaire (locker = nil : pas de vestiaire).
Config.Stations = {
    { duty = vec3(441.2, -981.9, 30.69), locker = vec3(452.6, -992.8, 30.69) }, -- Mission Row
}

-- Tenues du vestiaire. label = clé de locale. Composants / accessoires : [id] = { drawable, texture }.
Config.Outfits = {
    {
        label = 'outfit_patrol', grade = 0,
        male   = { components = { [3] = { 0, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 58, 0 }, [11] = { 55, 0 } }, props = {} },
        female = { components = { [3] = { 14, 0 }, [4] = { 34, 0 }, [6] = { 25, 0 }, [8] = { 35, 0 }, [11] = { 48, 0 } }, props = {} },
    },
    {
        label = 'outfit_command', grade = 3,
        male   = { components = { [3] = { 0, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 58, 0 }, [11] = { 55, 0 } }, props = { [0] = { 46, 0 } } },
        female = { components = { [3] = { 14, 0 }, [4] = { 34, 0 }, [6] = { 25, 0 }, [8] = { 35, 0 }, [11] = { 48, 0 } }, props = { [0] = { 45, 0 } } },
    },
}
