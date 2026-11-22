-- Objets (4/5) : accessoires d'armes, mécanique, peinture.
-- Config.Items est rempli dans l'ordre par config/items_1.lua à items_5.lua.
Config.Items = Config.Items or {}

local items = {
  -- ============================================================
  --  ACCESSOIRES D'ARMES
  --  Items consommés lorsqu'attachés à une arme (cf. Config.WeaponAttachments).
  --  Le détachement les restitue dans l'inventaire.
  -- ============================================================
  suppressor_pistol = {
    label = 'Silencieux Pistolet',
    weight = 0.3,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'weapon_attachment', 'attachment_pistol' },
    gradientColor = 'rgba(50, 50, 50, 0.45)',
  },
  flashlight_pistol = {
    label = 'Lampe Pistolet',
    weight = 0.2,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'weapon_attachment', 'attachment_pistol' },
    gradientColor = 'rgba(220, 200, 100, 0.40)',
  },
  ext_clip_pistol = {
    label = 'Chargeur Étendu Pistolet',
    weight = 0.4,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'weapon_attachment', 'attachment_pistol' },
    gradientColor = 'rgba(100, 100, 100, 0.40)',
  },
  suppressor_rifle = {
    label = 'Silencieux Fusil',
    weight = 0.6,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'weapon_attachment', 'attachment_rifle' },
    gradientColor = 'rgba(50, 50, 50, 0.45)',
  },
  scope_rifle = {
    label = 'Viseur Fusil',
    weight = 0.5,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'weapon_attachment', 'attachment_rifle' },
    gradientColor = 'rgba(80, 110, 60, 0.40)',
  },
  flashlight_rifle = {
    label = 'Lampe Fusil',
    weight = 0.3,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'weapon_attachment', 'attachment_rifle' },
    gradientColor = 'rgba(220, 200, 100, 0.40)',
  },
  ext_clip_rifle = {
    label = 'Chargeur Étendu Fusil',
    weight = 0.7,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'weapon_attachment', 'attachment_rifle' },
    gradientColor = 'rgba(100, 100, 100, 0.40)',
  },
  grip_rifle = {
    label = 'Poignée Fusil',
    weight = 0.2,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'weapon_attachment', 'attachment_rifle' },
    gradientColor = 'rgba(100, 100, 100, 0.40)',
  },
  suppressor_smg = {
    label = 'Silencieux SMG',
    weight = 0.5,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'weapon_attachment', 'attachment_smg' },
    gradientColor = 'rgba(50, 50, 50, 0.45)',
  },
  scope_smg = {
    label = 'Viseur SMG',
    weight = 0.4,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'weapon_attachment', 'attachment_smg' },
    gradientColor = 'rgba(80, 110, 60, 0.40)',
  },
  flashlight_smg = {
    label = 'Lampe SMG',
    weight = 0.2,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'weapon_attachment', 'attachment_smg' },
    gradientColor = 'rgba(220, 200, 100, 0.40)',
  },
  ext_clip_smg = {
    label = 'Chargeur Étendu SMG',
    weight = 0.5,
    maxStack = 5,
    icon = 'img/unknown.webp',
    tags = { 'weapon_attachment', 'attachment_smg' },
    gradientColor = 'rgba(100, 100, 100, 0.40)',
  },

  -- ============================================================
  --  MÉCANIQUE / PIÈCES AUTO
  -- ============================================================
  huile_moteur = {
    label    = 'Huile Moteur',
    weight   = 1.5,
    maxStack = 10,
    icon     = 'img/motoroil.webp',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(30, 20, 10, 0.65)',
  },
  batterie = {
    label    = 'Batterie',
    weight   = 5.0,
    maxStack = 2,
    icon     = 'img/carbattery.webp',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(60, 80, 40, 0.55)',
  },
  pneu = {
    label    = 'Pneu',
    weight   = 8.0,
    maxStack = 4,
    icon     = 'img/wheel.webp',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(20, 20, 20, 0.65)',
  },
  freins = {
    label    = 'Freins',
    weight   = 3.0,
    maxStack = 4,
    icon     = 'img/brake.webp',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(180, 40, 40, 0.45)',
  },
  pieces_moteur = {
    label    = 'Pièces Moteur',
    weight   = 4.0,
    maxStack = 5,
    icon     = 'img/motorpart.webp',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(100, 80, 40, 0.50)',
  },
  pieces_transmission = {
    label    = 'Pièces Transmission',
    weight   = 3.5,
    maxStack = 5,
    icon     = 'img/transmissionpart.webp',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(80, 80, 80, 0.50)',
  },
  pieces_suspension = {
    label    = 'Pièces Suspension',
    weight   = 3.0,
    maxStack = 5,
    icon     = 'img/suspension.webp',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(60, 100, 120, 0.45)',
  },
  pieces_carrosserie = {
    label    = 'Pièces Carrosserie',
    weight   = 5.0,
    maxStack = 5,
    icon     = 'img/carpart.webp',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(120, 120, 130, 0.45)',
  },
  -- Moteur : pièce fixe du véhicule, occupe un bloc 3x3 ("carengine") dans le capot.
  -- gridSpan = { w, h } est lu par la grille NUI (standby) ET par la validation
  -- serveur (standbyPlacementError) pour réserver les 9 cases.
  moteur = {
    label    = 'Moteur',
    weight   = 150.0,
    maxStack = 1,
    icon     = 'img/carengine.webp',
    tags     = { 'mechanic', 'auto', 'carengine', 'container' },
    gridSpan = { w = 3, h = 3 },
    -- Le moteur est lui-même un conteneur : clic droit -> Ouvrir (sous-grille 6x2).
    -- Pré-rempli (cf. engine_server.lua) : bloc_moteur 2x2 centré + 4 motorparts.
    container = { slots = 12, maxWeight = 150.0 },
    gradientColor = 'rgba(90, 90, 100, 0.50)',
  },
  -- Bloc moteur (enginebloc) : noyau du moteur, occupe un bloc 2x2.
  bloc_moteur = {
    label    = 'Bloc Moteur',
    weight   = 90.0,
    maxStack = 1,
    icon     = 'img/enginebloc.webp',
    tags     = { 'mechanic', 'auto', 'carengine' },
    gridSpan = { w = 2, h = 2 },
    gradientColor = 'rgba(70, 70, 80, 0.50)',
  },
  -- Piston cassé : pièce défectueuse insérée dans le moteur quand il est endommagé.
  -- Il faut la retirer/changer pour valider la tâche "Réparer le moteur" (cf. analyse).
  piston_casse = {
    label    = 'Piston Cassé',
    weight   = 4.0,
    maxStack = 1,
    icon     = 'img/motorpart.webp',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(200, 40, 40, 0.50)',
  },

  -- ============================================================
  --  PEINTURE
  --  Le pot de peinture est un conteneur générique ; sa couleur
  --  est déterminée par le liquide (item de peinture) qu'il contient.
  --  Les items de peinture (rouge / jaune / bleue) se glissent dans
  --  le pot via le système de conteneur (tag 'peinture').
  -- ============================================================
  peinture_rouge = {
    label    = 'Peinture Rouge',
    weight   = 0.01,
    maxStack = 100,
    icon     = 'img/redpaint.webp',
    tags     = { 'peinture', 'material' },
    gradientColor = 'rgba(200, 40, 40, 0.55)',
  },
  peinture_jaune = {
    label    = 'Peinture Jaune',
    weight   = 0.01,
    maxStack = 100,
    icon     = 'img/yellowpaint.webp',
    tags     = { 'peinture', 'material' },
    gradientColor = 'rgba(220, 200, 40, 0.55)',
  },
  peinture_bleue = {
    label    = 'Peinture Bleue',
    weight   = 0.01,
    maxStack = 100,
    icon     = 'img/bluepaint.webp',
    tags     = { 'peinture', 'material' },
    gradientColor = 'rgba(40, 80, 200, 0.55)',
  },
  -- Pistolet a peinture (mecano) : arme longue, clic droit -> Utiliser pour
  -- choisir la couleur (cf. resource pressurewashermodels).
  pistolet_peinture = {
    label      = 'Pistolet a Peinture',
    weight     = 4.0,
    maxStack   = 1,
    icon       = 'img/paint_gun.webp',
    equipSlot  = 'weapon_long',
    tags       = { 'weapon', 'weapon_long', 'tool' },
    gradientColor = 'rgba(120, 90, 200, 0.40)',
    weaponHash = 'WEAPON_PRESSURE1',
    usable     = true,
    onUse = function(source, item, def)
      if Config.Debug then print('^3[PAINTGUN][SV]^7 onUse pistolet_peinture src=' .. tostring(source) .. ' itemId=' .. tostring(item and item.id)) end
      -- Ouvre l'interface NUI de selection de couleur (resource pressurewashermodels).
      TriggerClientEvent('pop_paint:client:openConfig', source, item.id, item.meta or {})
      return false -- ne consomme jamais le pistolet
    end,
  },
  -- Pot vide — peut accueillir n'importe quel liquide de peinture (tag 'peinture').
  -- Le label et la couleur reflètent automatiquement le contenu grâce au système
  -- de meta / conteneur de pop_inventory (customLabel géré côté script si besoin).
  pot_peinture = {
    label    = 'Pot de Peinture (vide)',
    weight   = 0.2,
    maxStack = 1,
    icon     = 'img/paintcontainer.webp',
    container = { slots = 1, maxWeight = 10.0 }, -- 1 slot x 100 unités x 0.1 kg = 10 kg
    tags     = { 'conteneur', 'peinture_container', 'container' },
    gradientColor = 'rgba(180, 180, 180, 0.40)',
  },

}

for id, def in pairs(items) do
  Config.Items[id] = def
end
