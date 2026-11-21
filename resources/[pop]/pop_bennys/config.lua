Config = {}

------------------------------------------------------------------------
-- Réglages communs POP (ne pas supprimer)
------------------------------------------------------------------------
Config.Locale = 'fr'
Config.Debug = false
Config.Framework = 'auto' -- 'esx' | 'qbcore' | 'qbox' | 'standalone'
Config.Inventory = 'auto' -- 'pop_inventory' | 'ox_inventory' | ...
Config.Target    = 'auto' -- 'ox_target' | 'qb-target' | 'prompt'
Config.Notify    = 'auto' -- pop_notify s'il est lancé
Config.AccentColor = '#ffffff'
Config.CashItem = 'cash'
Config.Keys = {
    Interact = { control = 38, label = 'E' },
    Cancel   = { control = 73, label = 'X' },
}
Config.CallbackRateLimit = 10

------------------------------------------------------------------------
-- pop_bennys
------------------------------------------------------------------------
-- Ressource d'inventaire qui fournit les icônes/labels (export GetItemDef) et le
-- nombre d'objets possédés affichés dans le menu. Le paiement passe par le bridge.
Config.ItemsResource = 'pop_inventory'

-- Base des assets NUI de l'inventaire (les icônes y sont rangées dans img/).
-- L'icône/label réels sont résolus dynamiquement via l'export GetItemDef de
-- pop_inventory si dispo ; sinon on retombe sur l'icône/label définis ci-dessous,
-- et si rien n'existe -> img/unknown.png ('?').
Config.ItemIconBase = 'nui://pop_inventory/html/'
Config.UnknownIcon  = 'img/unknown.png'

-- ─────────────────────────────────────────────────────────────────────────────
-- Coût en ITEMS par catégorie de modification.
-- Chaque entrée : { item = defId réel, qty = nombre, label = nom, icon = 'img/x.png' }.
-- 'item' = defId RÉEL d'un item de pop_inventory (cf. pop_inventory Config.Items).
-- 'body' est facturé PAR pièce de carrosserie modifiée (qty x nombre de pièces).
-- Mets une catégorie à {} pour la rendre gratuite.
-- ─────────────────────────────────────────────────────────────────────────────
Config.ItemCosts = {
    wheel = {
        { item = 'pneu', qty = 4, label = 'Pneu', icon = 'img/wheel.png' },
    },
    body = {
        { item = 'pieces_carrosserie', qty = 1, label = 'Pièces Carrosserie', icon = 'img/carpart.png' },
    },
    performance = {
        { item = 'pieces_moteur',       qty = 2, label = 'Pièces Moteur',       icon = 'img/motorpart.png' },
        { item = 'pieces_transmission', qty = 1, label = 'Pièces Transmission', icon = 'img/transmissionpart.png' },
        { item = 'freins',              qty = 1, label = 'Freins',              icon = 'img/brake.png' },
    },
    neon = {
        { item = 'pcb',      qty = 1, label = 'Circuit imprimé', icon = 'img/pcb.png' },
        { item = 'batterie', qty = 1, label = 'Batterie',        icon = 'img/carbattery.png' },
    },
    window = {
        { item = 'bouteille', qty = 1, label = 'Film teinté', icon = 'img/bouteille.png' },
    },
    plate = {
        { item = 'plaque', qty = 1, label = 'Plaque', icon = 'img/plaque.png' },
    },
    livery = {
        { item = 'pieces_carrosserie', qty = 1, label = 'Pièces Carrosserie', icon = 'img/carpart.png' },
    },
    extra = {
        { item = 'pieces_carrosserie', qty = 1, label = 'Pièces Carrosserie', icon = 'img/carpart.png' },
    },
}

-- Commande pour ouvrir (debug / admin)
Config.Command = 'bennys'

-- Localisation du point d'interaction Benny's
Config.BennysCoords  = vector3(-211.9412, -1324.5264, 30.4547)
Config.BennysHeading = 177.6473
Config.BennysRadius  = 3.0

-- Distance max (côté serveur) entre le joueur et le Benny's pour payer (admins exemptés).
Config.PayDistance   = 30.0

-- ─────────────────────────────────────────────────────────────────────────────
-- Caméra par option (catégorie). Décalages exprimés dans le repère LOCAL du
-- véhicule : { droite(+)/gauche(-), avant(+)/arrière(-), haut(+)/bas(-) }.
--   pos  = position de la caméra
--   look = point que la caméra vise
-- ─────────────────────────────────────────────────────────────────────────────
Config.CameraFov = 50.0
Config.Cameras = {
    wheels  = { pos = {  3.0,  1.6,  0.2 }, look = {  0.0,  1.6,  0.1 } },  -- roue avant, vue basse
    body    = { pos = {  4.4,  0.0,  1.0 }, look = {  0.0,  0.0,  0.5 } },  -- profil complet
    perf    = { pos = {  0.0,  4.4,  1.3 }, look = {  0.0,  1.6,  0.6 } },  -- capot / moteur de face
    neons   = { pos = {  3.2,  2.2,  0.1 }, look = {  0.0,  0.0, -0.3 } },  -- bas de caisse
    windows = { pos = {  2.6,  0.4,  1.3 }, look = {  0.0,  0.2,  1.0 } },  -- vitres latérales
    plate   = { pos = {  0.0, -4.2,  0.8 }, look = {  0.0, -2.2,  0.5 } },  -- plaque arrière
    liveries= { pos = {  4.8,  0.0,  1.4 }, look = {  0.0,  0.0,  0.5 } },  -- profil élevé, flanc/livrée
    extras  = { pos = {  3.2, -3.2,  1.4 }, look = {  0.0,  0.0,  0.6 } },  -- 3/4 arrière, accessoires
}
