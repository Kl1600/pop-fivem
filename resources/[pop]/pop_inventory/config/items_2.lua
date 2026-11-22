-- Objets (2/5) : chargeurs, soins, argent, accessoires, armes, coffres.
-- Config.Items est rempli dans l'ordre par config/items_1.lua à items_5.lua.
Config.Items = Config.Items or {}

local items = {
  -- ===== CHARGEURS (s'inserent dans le conteneur de l'arme, cf. tab_chargeurs) =====
  -- Le tag 'magazine' + Config.ContainerRestrictions controlent quelle arme accepte quoi.
  -- meta.rounds / meta.customLabel sont geres par tab_chargeurs.
  chargeur_pistol = {
    label = 'Chargeur Pistolet',
    weight = 0.25,
    maxStack = 1, -- chaque chargeur a son propre compteur de balles (meta)
    icon = 'img/chargeurpistolet.webp',
    tags = { 'magazine' },
    gradientColor = 'rgba(70, 70, 80, 0.5)',
  },
  chargeur_smg = {
    label = 'Chargeur SMG',
    weight = 0.4,
    maxStack = 1,
    icon = 'img/chargeurmitraillette.webp',
    tags = { 'magazine' },
    gradientColor = 'rgba(70, 70, 80, 0.5)',
  },
  chargeur_fusil = {
    label = 'Chargeur Fusil',
    weight = 0.5,
    maxStack = 1,
    icon = 'img/chargeurfusil.webp',
    tags = { 'magazine' },
    gradientColor = 'rgba(70, 70, 80, 0.5)',
  },


  aed = {
    label = 'Défibrillateur',
    weight = 2.0,
    maxStack = 1,
    icon = 'img/aed.webp',
    usable = true,
    tags = { 'ems', 'medical' },
    gradientColor = 'rgba(230, 50, 50, 0.4)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('pop_inventory:client:useAED', source)
        return false
    end,
  },
  kitsoins = {
    label = 'Kit de Soins',
    weight = 1.0,
    maxStack = 5,
    icon = 'img/kitsoins.webp',
    usable = true,
    tags = { 'ems', 'medical' },
    gradientColor = 'rgba(50, 230, 50, 0.4)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('pop_inventory:client:useKitSoins', source)
        return true -- Consomme le kit de soin
    end,
  },
  repakit = {
    label = 'Kit de Réparation',
    weight = 2.0,
    maxStack = 5,
    icon = 'img/unknown.webp',
    usable = true,
    tags = { 'tools', 'mechanic' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('pop_inventory:client:useRepakit', source)
        return false -- Consommé manuellement après le target
    end,
  },
  tyre = {
    label = 'Pneu neuf',
    weight = 5.0,
    maxStack = 1,
    icon = 'img/wheel.webp',
    usable = true,
    tags = { 'tools', 'mechanic' },
    gradientColor = 'rgba(50, 50, 50, 0.60)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('pop_inventory:client:useTyre', source)
        return false
    end,
  },
  tyre_burst = {
    label = 'Pneu usé',
    weight = 5.0,
    maxStack = 1,
    icon = 'img/wheel.webp',
    usable = false,
    tags = { 'tools', 'mechanic' },
    gradientColor = 'rgba(200, 30, 30, 0.60)', -- Fond rouge pour indiquer qu'il est cassé
  },
  cash = {
    label = 'Argent',
    weight = 0.001,
    maxStack = 100000,
    icon = 'img/dollar.webp',
    tags = { 'cash' },
    gradientColor = 'rgba(70, 146, 81, 0.59)',
  },
  -- Objet gardé seulement pour que les anciens pesos restent visibles (et jetables) :
  -- plus aucune boutique ne les vend ni ne les accepte.
  pesos = {
    label = 'Pesos',
    weight = 0.001,
    maxStack = 100000,
    icon = 'img/pesos.webp',
    tags = { 'cash' },
    gradientColor = 'rgba(200, 160, 40, 0.59)',
  },
  creditcard = {
    label = 'Carte de Crédit',
    weight = 0.01,
    maxStack = 10,
    icon = 'img/creditcard.webp',
    tags = { 'creditcard' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  ears = {
    label = 'Oreilles',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/unknown.webp',
    equipSlot = 'ears',
    tags = { 'clothing' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
  },
  watch = {
    label = 'Montre',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/watch.webp',
    equipSlot = 'watch',
    tags = { 'clothing' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
  },
  bracelet = {
    label = 'Bracelet',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/unknown.webp',
    equipSlot = 'bracelet',
    tags = { 'clothing' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
  },
  accessory = {
    label = 'Accessoire',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/unknown.webp',
    equipSlot = 'accessory',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  decal = {
    label = 'Sticker / Écusson',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/unknown.webp',
    equipSlot = 'decal',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  file = {
    label = 'Document',
    weight = 0.01,
    maxStack = 10,
    icon = 'img/file.webp',
    tags = { 'misc' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  methylamine = {
    label = 'Methylamine',
    weight = 1.0,
    maxStack = 10,
    icon = 'img/unknown.webp',
    tags = { 'chimique' },
    gradientColor = 'rgba(60, 94, 133, 0.7)',
  },
  carburant = {
    label = 'Carburant',
    weight = 0.02,
    maxStack = 5000,
    icon = 'img/carburant.webp',
    tags = { 'ressource' },
    gradientColor = 'rgba(30, 30, 30, 0.68)',
  },
  baril = {
    label = 'Baril',
    weight = 10.0,
    maxStack = 2,
    icon = 'img/unknown.webp',
    tags = { 'conteneur' },
    gradientColor = 'rgba(120, 120, 120, 0.40)',
  },
  smg = {
    label = 'SMG',
    weight = 5.5,
    maxStack = 1, -- a un chargeur interne (conteneur) -> instance unique
    icon = 'img/smg.webp',
    equipSlot = 'weapon_long',
    container = { slots = 1, maxWeight = 2.0 }, -- puits de chargeur (cf. tab_chargeurs)
    tags = { 'weapon', 'weapon_long', 'container' },
    gradientColor = 'rgba(169, 128, 71, 0.350)',
    weaponHash = 'WEAPON_SMG',
  },
  carabine = {
    label = 'Carabine',
    weight = 6.5,
    maxStack = 1, -- a un chargeur interne (conteneur) -> instance unique
    icon = 'img/smg.webp',
    equipSlot = 'weapon_long',
    container = { slots = 1, maxWeight = 2.0 }, -- puits de chargeur (cf. tab_chargeurs)
    tags = { 'weapon', 'weapon_long', 'container' },
    gradientColor = 'rgba(169, 128, 71, 0.350)',
    weaponHash = 'WEAPON_CARBINERIFLE',
  },
  carkeys = {
    label = 'Clés de Voiture',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/carkeys.webp',
    tags = { 'misc' },
    usable = true,
    onUse = function(source, itemData)
      TriggerClientEvent('pop_inventory:client:toggleVehicleLock', source, itemData.meta and itemData.meta.plate)
      return false
    end,
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  lampe = {
    label = 'Lampe Torche',
    weight = 0.2,
    maxStack = 4,
    icon = 'img/lampe.webp',
    tags = { 'tool' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  uvpocketlight = {
    label       = 'Lampe UV',
    weight      = 0.4,
    maxStack    = 1,
    icon        = 'img/uvpocketlight.webp',
    equipSlot   = 'weapon_tool', -- slot outil (dernier slot de la section Armes)
    tags        = { 'tool', 'police' },
    gradientColor = 'rgba(100, 50, 200, 0.50)',
    weaponHash  = 'WEAPON_POCKETLIGHT',
    usable      = true,
    onUse = function(source, item, def)
      TriggerClientEvent('pop_inventory:client:toggleUVLight', source)
      return false
    end,
  },
  megaphone = {
    label = 'Mégaphone',
    weight = 0.5,
    maxStack = 1,
    icon = 'img/megaphone.webp',
    tags = { 'tool' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  pistol = {
    label = 'Pistolet',
    weight = 1.2,
    maxStack = 1, -- a un chargeur interne (conteneur) -> instance unique
    icon = 'img/pistol.webp',
    equipSlot = 'weapon_pistol',
    container = { slots = 1, maxWeight = 2.0 }, -- puits de chargeur (cf. tab_chargeurs)
    tags = { 'weapon', 'container' },
    gradientColor = 'rgba(169, 128, 71, 0.350)',
    weaponHash = 'WEAPON_PISTOL',
  },
  revolver = {
    label = 'Revolver',
    weight = 1.5,
    maxStack = 1,
    icon = 'img/pistol.webp',
    equipSlot = 'weapon_pistol',
    container = { slots = 1, maxWeight = 2.0 },
    tags = { 'weapon', 'container' },
    gradientColor = 'rgba(169, 128, 71, 0.350)',
    weaponHash = 'WEAPON_REVOLVER',
  },
  policevest = {
    label = 'Gilet Pare-balles',
    weight = 3.0,
    maxStack = 4,
    icon = 'img/policevest.webp',
    equipSlot = 'kevlar',
    container = { slots = 12, maxWeight = 15.0 },
    tags = { 'clothing', 'container', 'police' },
    gradientColor = 'rgba(60, 94, 133, 0.7)',
  },
  safe = {
    label = 'Coffre-fort',
    weight = 10.0,
    maxStack = 1,
    icon = 'img/safe.webp',
    equipSlot = 'briefcase',
    container = { slots = 5, maxWeight = 100.0 },
    tags = { 'misc', 'container' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  -- Casier individuel d'une salle de casiers (Config.LockerRooms). Jamais équipable :
  -- chaque instance est générée par le serveur avec meta.lockerNumber = matricule de
  -- l'employé. L'ouverture est protégée par code sauf pour le propriétaire (cf.
  -- server/sv_actions.lua, action 'open').
  casier = {
    label = 'Casier',
    weight = 0,
    maxStack = 1,
    icon = 'img/safe.webp',
    container = { slots = 8, maxWeight = 15.0 },
    tags = { 'misc', 'container', 'casier' },
    gradientColor = 'rgba(90, 110, 180, 0.40)',
  },
}

for id, def in pairs(items) do
  Config.Items[id] = def
end
