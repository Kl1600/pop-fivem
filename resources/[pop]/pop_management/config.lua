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

-- ─── pop_management ─────────────────────────────────────────

-- Sociétés gérées (clé = nom du job dans votre framework).
--   bossGrade    : grade minimum pour ouvrir le panneau patron
--   invoiceGrade : grade minimum pour envoyer des factures (false = pas de factures)
--   points       : où ouvrir le panneau (peut être vide si vous utilisez la commande)
Config.Societies = {
    police    = { bossGrade = 4, invoiceGrade = 0, points = { vector3(461.45, -986.2, 30.73) } },
    ambulance = { bossGrade = 4, invoiceGrade = 0, points = { vector3(335.2, -594.0, 43.28) } },
    mechanic  = { bossGrade = 4, invoiceGrade = 0, points = { vector3(-347.4, -133.2, 39.0) } },
}

Config.Command        = 'society' -- ouvre le panneau partout (false = seulement aux points)
Config.InvoiceCommand = 'invoice' -- formulaire de facture (false = factures désactivées)

-- Compte société : 'auto' | 'esx_addonaccount' | 'qb-banking' | 'qb-management' | 'renewed-banking' | 'pop'
Config.SocietyAccount = 'auto'

-- Comptes joueur utilisés ('cash' | 'bank').
Config.Accounts = {
    transfer = 'cash', -- dépôt / retrait au compte société
    bonus    = 'bank', -- primes reçues par les employés
    invoice  = 'bank', -- paiement des factures par le client
}

Config.MaxAmount        = 1000000 -- montant max par dépôt / retrait / prime
Config.MaxInvoice       = 50000   -- montant max d'une facture
Config.InteractDistance = 3.0     -- distance max pour recruter / facturer (mètres)
Config.OfferTimeout     = 30      -- secondes pour accepter une offre (recrutement, facture)
