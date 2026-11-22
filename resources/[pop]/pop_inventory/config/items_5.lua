-- Objets (5/5) : restauration, drogues, banque.
-- Config.Items est rempli dans l'ordre par config/items_1.lua à items_5.lua.
Config.Items = Config.Items or {}

local items = {
  -- ============================================================
  --  LUCKY PLUCKER (poulet frit rétro)
  -- ============================================================

  -- Ingrédients / contenants
  raw_chicken = {
    label = 'Poulet cru',
    weight = 0.4,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(220, 180, 150, 0.40)',
  },
  secret_breadcrumbs = {
    label = 'Chapelure secrète',
    weight = 0.2,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(200, 160, 90, 0.40)',
  },
  cooking_oil = {
    label = 'Huile de friture',
    weight = 0.5,
    maxStack = 20,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(210, 190, 80, 0.40)',
  },
  lucky_box = {
    label = 'Boîte en carton Lucky',
    weight = 0.1,
    maxStack = 100,
    icon = 'img/unknown.webp',
    tags = { 'misc', 'packaging' },
    gradientColor = 'rgba(180, 60, 50, 0.40)',
  },
  bbq_sauce = {
    label = 'Sauce barbecue',
    weight = 0.15,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(120, 50, 30, 0.45)',
  },
  paper_bag = {
    label = 'Sachet en papier',
    weight = 0.05,
    maxStack = 100,
    icon = 'img/unknown.webp',
    tags = { 'misc', 'packaging' },
    gradientColor = 'rgba(190, 160, 110, 0.40)',
  },
  lemon = {
    label = 'Citron',
    weight = 0.1,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(220, 215, 70, 0.40)',
  },
  sparkling_water = {
    label = 'Eau pétillante',
    weight = 0.4,
    maxStack = 20,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(150, 200, 220, 0.40)',
  },
  sugar_syrup = {
    label = 'Sirop de sucre',
    weight = 0.2,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(230, 220, 200, 0.40)',
  },
  plastic_cup = {
    label = 'Gobelet en plastique',
    weight = 0.05,
    maxStack = 100,
    icon = 'img/unknown.webp',
    tags = { 'misc', 'packaging' },
    gradientColor = 'rgba(200, 200, 200, 0.40)',
  },

  -- Produits finaux Lucky Plucker
  seau_du_coq = {
    label = 'Seau du Coq',
    weight = 0.9,
    maxStack = 5,
    icon = 'img/unknown.webp',
    usable = true,
    tags = { 'food' },
    gradientColor = 'rgba(180, 60, 50, 0.45)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('esx_status:add', source, 'hunger', 1000000) -- nourrit à 100%
        TriggerClientEvent('esx_basicneeds:onEat', source)
        return true
    end,
  },
  nuggets_poulailler = {
    label = 'Nuggets du Poulailler',
    weight = 0.25,
    maxStack = 10,
    icon = 'img/unknown.webp',
    usable = true,
    tags = { 'food' },
    gradientColor = 'rgba(200, 160, 90, 0.45)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('esx_status:add', source, 'hunger', 600000) -- nourrit à 60% (resto > LTD)
        TriggerClientEvent('esx_basicneeds:onEat', source)
        return true
    end,
  },
  limonade_fermiere = {
    label = 'Limonade Fermière',
    weight = 0.35,
    maxStack = 10,
    icon = 'img/unknown.webp',
    usable = true,
    tags = { 'food' },
    gradientColor = 'rgba(220, 215, 70, 0.45)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('esx_status:add', source, 'thirst', 600000) -- hydrate à 60%
        TriggerClientEvent('esx_basicneeds:onDrink', source)
        return true
    end,
  },

  -- ============================================================
  --  PEARLS SEAFOOD RESTAURANT (produits de la mer)
  -- ============================================================

  -- Ingrédients / contenants
  fresh_oysters = {
    label = 'Huîtres fraîches',
    weight = 0.3,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(170, 190, 180, 0.40)',
  },
  lemon_slice = {
    label = 'Rondelle de citron',
    weight = 0.05,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(220, 215, 70, 0.40)',
  },
  crushed_ice = {
    label = 'Glace pilée',
    weight = 0.2,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(190, 220, 230, 0.40)',
  },
  porcelain_plate = {
    label = 'Assiette en porcelaine',
    weight = 0.4,
    maxStack = 20,
    icon = 'img/unknown.webp',
    tags = { 'misc', 'packaging' },
    gradientColor = 'rgba(230, 230, 230, 0.40)',
  },
  fresh_lobster = {
    label = 'Homard frais',
    weight = 0.6,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(200, 70, 60, 0.40)',
  },
  brioche_bun = {
    label = 'Pain brioché',
    weight = 0.15,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(210, 170, 110, 0.40)',
  },
  lemon_butter = {
    label = 'Beurre citronné',
    weight = 0.1,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(230, 215, 130, 0.40)',
  },
  pearls_wrapper = {
    label = 'Emballage Pearls',
    weight = 0.05,
    maxStack = 100,
    icon = 'img/unknown.webp',
    tags = { 'misc', 'packaging' },
    gradientColor = 'rgba(150, 200, 220, 0.40)',
  },
  blue_curacao_syrup = {
    label = 'Sirop de curaçao bleu',
    weight = 0.2,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(60, 120, 220, 0.45)',
  },
  pineapple_juice = {
    label = "Jus d'ananas",
    weight = 0.3,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(230, 200, 70, 0.40)',
  },
  tonic_water = {
    label = 'Schweppes / Tonic',
    weight = 0.35,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(200, 220, 230, 0.40)',
  },
  cocktail_glass = {
    label = 'Verre à cocktail',
    weight = 0.2,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'misc', 'packaging' },
    gradientColor = 'rgba(210, 210, 220, 0.40)',
  },

  -- Produits finaux Pearls Seafood
  plateau_huitres = {
    label = "Plateau d'Huîtres Del Perro",
    weight = 0.8,
    maxStack = 5,
    icon = 'img/unknown.webp',
    usable = true,
    tags = { 'food' },
    gradientColor = 'rgba(170, 190, 180, 0.45)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('esx_status:add', source, 'hunger', 650000) -- nourrit à 65% (resto > LTD)
        TriggerClientEvent('esx_basicneeds:onEat', source)
        TriggerClientEvent('pop_inventory:client:addHealth', source, 30) -- régénère un peu de santé
        return true
    end,
  },
  sandwich_homard = {
    label = 'Sandwich au Homard',
    weight = 0.4,
    maxStack = 10,
    icon = 'img/unknown.webp',
    usable = true,
    tags = { 'food' },
    gradientColor = 'rgba(200, 70, 60, 0.45)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('esx_status:add', source, 'hunger', 800000) -- nourrit à 80%
        TriggerClientEvent('esx_basicneeds:onEat', source)
        return true
    end,
  },
  mocktail_lagon_bleu = {
    label = 'Mocktail Lagon Bleu',
    weight = 0.35,
    maxStack = 10,
    icon = 'img/unknown.webp',
    usable = true,
    tags = { 'food' },
    gradientColor = 'rgba(60, 120, 220, 0.45)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('esx_status:add', source, 'thirst', 700000) -- hydrate à 70%
        TriggerClientEvent('esx_basicneeds:onDrink', source)
        return true
    end,
  },

  -- ============================================================
  --  DROGUES (circuit simplifié)
  -- ============================================================

  -- Contenant commun
  empty_baggy = {
    label = 'Pochon vide',
    weight = 0.01,
    maxStack = 100,
    icon = 'img/pochon.webp',
    tags = { 'misc' },
    gradientColor = 'rgba(200, 200, 200, 0.40)',
  },

  -- Ingrédients
  chemical_substance = {
    label = 'Produit chimique',
    weight = 0.3,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'material', 'drug' },
    gradientColor = 'rgba(120, 220, 120, 0.40)',
  },
  battery_acid = {
    label = 'Acide de batterie',
    weight = 0.4,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'material', 'drug' },
    gradientColor = 'rgba(200, 200, 60, 0.40)',
  },
  cocaine_powder = {
    label = 'Poudre de cocaïne',
    weight = 0.2,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'material', 'drug' },
    gradientColor = 'rgba(240, 240, 240, 0.45)',
  },
  baking_soda = {
    label = 'Bicarbonate de soude',
    weight = 0.2,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'material', 'drug' },
    gradientColor = 'rgba(230, 230, 230, 0.40)',
  },

  -- Produits finaux
  meth_pure = {
    label = 'Cristaux Bleus (Meth)',
    weight = 0.05,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'drugs' },
    gradientColor = 'rgba(60, 120, 220, 0.55)',
  },
  crack_rock = {
    label = 'Caillou de Crack',
    weight = 0.05,
    maxStack = 50,
    icon = 'img/unknown.webp',
    tags = { 'drugs' },
    gradientColor = 'rgba(230, 220, 200, 0.55)',
  },
  -- Système bancaire : chéquier (achetable en banque) et chèque (rempli via le chéquier)
  checkbook = {
    label    = 'Chéquier',
    weight   = 0.5,
    maxStack = 1,
    icon     = 'img/checkbook.webp',
    tags     = { 'chéquier', 'carnet de chèque' },
    usable   = true,
    close    = true,
    clientEvent = 'pop_inventory:openNUIcheck',
    onUse    = function() return false end, -- réutilisable : ne se consomme pas à l'écriture d'un chèque
  },

  -- Chéquier d'entreprise : commandé via SecuroServ (pop_management), livré au patron.
  -- Fonctionne exactement comme le chéquier perso, mais chaque chèque émis porte
  -- automatiquement l'ordre de l'entreprise (meta.company / meta.companyLabel).
  checkbook_company = {
    label    = 'Chéquier d\'entreprise',
    weight   = 0.5,
    maxStack = 1,
    icon     = 'img/checkbook.webp',
    tags     = { 'chéquier', 'carnet de chèque', 'entreprise' },
    usable   = true,
    close    = true,
    clientEvent = 'pop_inventory:openNUIcheck',
    onUse    = function() return false end,
  },

  check = {
    label    = 'Chèque',
    weight   = 0.1,
    maxStack = 1,
    icon     = 'img/check.webp',
    tags     = { 'chèque', 'banque' },
    usable   = false,
  },
}

for id, def in pairs(items) do
  Config.Items[id] = def
end
