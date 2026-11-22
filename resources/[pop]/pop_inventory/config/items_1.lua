-- Objets (1/5) : santé, papiers, vêtements, téléphone, menottes, clés, douilles.
-- Config.Items est rempli dans l'ordre par config/items_1.lua à items_5.lua.
Config.Items = Config.Items or {}

local items = {
  -- EMS Items
  civiere = {
    label    = 'Civière',
    weight   = 2.0,
    maxStack = 5,
    icon     = 'img/civiere.webp',
    tags     = { 'misc', 'ems' },
  },
  bequille = {
    label    = 'Béquille',
    weight   = 1.0,
    maxStack = 5,
    icon     = 'img/bequille.webp',
    tags     = { 'misc', 'ems' },
  },
  defib = {
    label    = 'Défibrillateur',
    weight   = 5.0,
    maxStack = 1,
    icon     = 'img/defib.webp',
    tags     = { 'misc', 'ems' },
  },
  lucas = {
    label    = 'Lucas (CPR)',
    weight   = 4.0,
    maxStack = 1,
    icon     = 'img/lucas.webp',
    tags     = { 'misc', 'ems' },
  },
  brancard = {
    label    = 'Brancard',
    weight   = 15.0,
    maxStack = 1,
    icon     = 'img/brancard.webp',
    tags     = { 'misc', 'ems' },
    usable   = true,
    clientEvent = 'pop_inventory:client:useBrancard',
    gridSpan = { w = 4, h = 3 },
    equipSlot = 'briefcase',
  },
  fauteuil = {
    label    = 'Fauteuil roulant',
    weight   = 10.0,
    maxStack = 1,
    icon     = 'img/fauteuil.webp',
    tags     = { 'misc', 'ems' },
  },

  pot = {
    label       = 'Pot de fleur',
    weight      = 1.0,
    maxStack    = 10,
    icon        = 'img/pot.webp',
    tags        = { 'misc' },
    usable      = true,
    onUse       = function(source, itemData, itemDef) return false end,
    gradientColor = 'rgba(180, 140, 90, 0.40)',
    clientEvent = 'pop_weed:usePot',
  },
  idcard = {
    label    = 'Carte d\'identité',
    weight   = 0.05,
    maxStack = 1,
    icon     = 'img/idcard.webp',
    tags     = { 'misc', 'identity' },
    usable   = true,
    gradientColor = 'rgba(60, 94, 133, 0.7)',
    onUse    = function(source, itemData, itemDef)
        TriggerClientEvent('pop_idcard:display', source, itemData)
        return false -- Keep the card
    end,
  },
  idcard_mx = {
    label    = 'Credencial INE',
    weight   = 0.05,
    maxStack = 1,
    icon     = 'img/idcard.webp',
    tags     = { 'misc', 'identity' },
    usable   = true,
    gradientColor = 'rgba(0, 104, 56, 0.7)',
    onUse    = function(source, itemData, itemDef)
        TriggerClientEvent('pop_idcard:display', source, itemData)
        return false -- Keep the card
    end,
  },
  passport_us = {
    label    = 'Passeport US',
    weight   = 0.10,
    maxStack = 1,
    icon     = 'img/idcard.webp',
    tags     = { 'misc', 'identity', 'passport' },
    usable   = true,
    gradientColor = 'rgba(28, 52, 134, 0.75)',
    onUse    = function(source, itemData, itemDef)
        TriggerClientEvent('pop_passport:display:us', source, itemData)
        return false
    end,
  },
  passport_mx = {
    label    = 'Pasaporte MX',
    weight   = 0.10,
    maxStack = 1,
    icon     = 'img/idcard.webp',
    tags     = { 'misc', 'identity', 'passport' },
    usable   = true,
    gradientColor = 'rgba(24, 107, 58, 0.75)',
    onUse    = function(source, itemData, itemDef)
        TriggerClientEvent('pop_passport:display:mx', source, itemData)
        return false
    end,
  },
  grainecana = {
    label    = 'Graine de cannabis',
    weight   = 0.1,
    maxStack = 50,
    icon     = 'img/grainecana.webp',
    tags     = { 'misc' },
  },
  weed = {
    label    = 'Weed',
    weight   = 0.3,
    maxStack = 50,
    icon     = 'img/weed.webp',
    tags     = { 'misc', 'drug' },
  },
  panta = {
    label = 'Pantalon',
    weight = 1.2,
    maxStack = 1,
    icon = 'img/pants.webp',
    equipSlot = 'panta',
    container = { slots = 10, maxWeight = 25.0 },
    tags = { 'clothing', 'container' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  hoddie = {
    label = 'Hoodie',
    weight = 1.0,
    maxStack = 1,
    icon = 'img/hoddie.webp',
    equipSlot = 'hoddie',
    container = { slots = 10, maxWeight = 25.0 },
    tags = { 'clothing', 'container' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  backpack = {
    label = 'Sac',
    weight = 1.8,
    maxStack = 1,
    icon = 'img/backpack.webp',
    equipSlot = 'backpack',
    container = { slots = 22, maxWeight = 20.0 },
    tags = { 'clothing', 'container' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
  },
  briefcase = {
    label = 'Malette',
    weight = 2.0,
    maxStack = 1,
    icon = 'img/briefcase.webp',
    equipSlot = 'briefcase',
    container = { slots = 15, maxWeight = 15.0 },
    tags = { 'clothing', 'container' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
    weaponHash = 'WEAPON_BRIEFCASE_02',
  },
  cardboard_box = {
    label = 'Boite en Carton',
    weight = 1.5,
    maxStack = 1,
    icon = 'img/cardboard_box.webp',
    equipSlot = 'briefcase',
    container = { slots = 20, maxWeight = 30.0 },
    tags = { 'clothing', 'container' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  wallet = {
    label = 'Portefeuille',
    weight = 0.2,
    maxStack = 1,
    icon = 'img/wallet.webp',
    equipSlot = 'wallet',
    container = { slots = 4, maxWeight = 2.0 },
    tags = { 'clothing', 'container' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
  },
  kevlar = {
    label = 'Kevlar',
    weight = 2.5,
    maxStack = 1,
    icon = 'img/kevlar.webp',
    equipSlot = 'kevlar',
    container = { slots = 12, maxWeight = 15.0 },
    tags = { 'clothing', 'container' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
  },
  tshirt = {
    label = 'T-Shirt',
    weight = 0.3,
    maxStack = 1,
    icon = 'img/tshirt.webp',
    equipSlot = 'tshirt',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  shoes = {
    label = 'Chaussures',
    weight = 0.8,
    maxStack = 1,
    icon = 'img/shoes.webp',
    equipSlot = 'shoes',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  hat = {
    label = 'Chapeau',
    weight = 0.3,
    maxStack = 1,
    icon = 'img/hat.webp',
    equipSlot = 'hat',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  glasses = {
    label = 'Lunettes',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/glasses.webp',
    equipSlot = 'glasses',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  mask = {
    label = 'Masque',
    weight = 0.2,
    maxStack = 1,
    icon = 'img/mask.webp',
    equipSlot = 'mask',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  tie = {
    label = 'Cravate',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/unknown.webp',
    equipSlot = 'tie',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  phone = {
    label = 'Téléphone',
    weight = 0.2,
    maxStack = 1,
    icon = 'img/phone.webp',
    equipSlot = 'phone',
    usable = true,
    container = { slots = 1, maxWeight = 0.1 }, -- 1 case pour la carte SIM
    tags = { 'communication', 'container' },
    gradientColor = 'rgba(60, 94, 133, 0.7)',
    onUse = function(source, item, def)
      if Config.Debug then print(('^6[pop_inventory] phone.onUse source=%s — routing to lb-phone^7'):format(tostring(source))) end
      -- IMPORTANT: must always `return false` so pop_inventory does not consume
      -- the phone. Wrap any export call in pcall so a failure does not abort
      -- this function before reaching the return statement.
      if GetResourceState('lb-phone') == 'started' then
        local ok, err = pcall(function()
          exports['lb-phone']:OpenPhoneWithSim(source)
        end)
        if not ok then
          print('^1[pop_inventory] phone.onUse: OpenPhoneWithSim export failed: ' .. tostring(err) .. '^7')
          TriggerClientEvent('phone:toggleOpen', source, true)
        end
      else
        if Config.Debug then print('^3[pop_inventory] phone.onUse: lb-phone not started, using fallback^7') end
        TriggerClientEvent('phone:toggleOpen', source, true)
      end
      return false
    end,
  },
  sim_card = {
    label = 'Carte SIM',
    weight = 0.01,
    maxStack = 1,
    icon = 'img/sim_card.webp',
    tags = { 'communication', 'sim_card' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
  },
  radio = {
    label = 'Radio',
    weight = 0.5,
    icon = 'img/radio.webp',
    equipSlot = 'radio',
    usable = true,
    -- L'alimentation est gérée par l'équipement (slot radio). « Utiliser » ouvre
    -- seulement le panneau radio.
    onUse = function(source)
      TriggerClientEvent('pop_inventory:client:openRadioPanel', source)
      return false -- ne pas consommer l'item
    end,
    tags = { 'communication' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
  },
  bouteille = {
    label       = 'Bouteille',
    weight      = 0.6,
    maxStack    = 5,
    icon        = 'img/bouteille.webp',
    usable      = true,
    onUse       = function(source, itemData, itemDef)
        TriggerClientEvent('esx_status:add', source, 'thirst', 200000)
        TriggerClientEvent('esx_basicneeds:onDrink', source)
        TriggerClientEvent('pop_weed:useWaterBottle', source)
        return true
    end,
    tags        = { 'food' },
    gradientColor = 'rgba(60, 94, 133, 0.7)',
  },
  tpe = {
    label = 'Terminal de Paiement',
    weight = 0.5,
    maxStack = 1,
    icon = 'img/tpe.webp',
    usable = true,
    tags = { 'tools' },
    gradientColor = 'rgba(200, 200, 200, 0.4)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('pop_inventory:client:useTPE', source)
        return false -- Ne pas consommer l'item
    end,
  },
  menottes = {
    label = 'Menottes',
    weight = 0.2,
    maxStack = 5,
    icon = 'img/menottes.webp',
    usable = true,
    tags = { 'police', 'tools' },
    gradientColor = 'rgba(120, 120, 120, 0.4)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('pop_inventory:client:useMenottes', source)
        return false -- Ne pas consommer l'item directement
    end,
  },
  sabot = {
    label = 'Sabot de roue',
    weight = 5.0,
    maxStack = 5,
    icon = 'img/clamp.webp', -- remplace par img/sabot.webp si tu ajoutes l'icone
    usable = true,
    tags = { 'police', 'tools' },
    gradientColor = 'rgba(90, 90, 90, 0.4)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('pop_sabot:client:useSabot', source)
        return false -- la pose/consommation est geree par tab_sabot
    end,
  },
  cle_sabot = {
    label = 'Cle de sabot',
    weight = 0.2,
    maxStack = 1,
    icon = 'img/carkeys.webp',
    usable = true,
    tags = { 'police', 'tools' },
    gradientColor = 'rgba(200, 180, 50, 0.4)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('pop_sabot:client:useCle', source)
        return false
    end,
  },
  -- Clé Doorbuilder (pop_doorlock) : UN SEUL item pour toutes les portes.
  -- Le groupe de portes ouvert est porté par la métadonnée meta.doorgroup
  -- (même principe que carkeys avec meta.plate). On ne crée jamais d'autre item.
  cle = {
    label = 'Clé',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/carkeys.webp',
    tags = { 'misc', 'doorlock' },
    gradientColor = 'rgba(200, 180, 50, 0.4)',
  },
  douille = {
    label = 'Douille',
    weight = 0.05,
    maxStack = 1, -- chaque douille est une preuve unique (meta differente -> ne se stacke jamais)
    icon = 'img/douille.webp', -- remplace par img/douille.webp si tu ajoutes l'icone
    usable = true,
    tags = { 'police', 'indice' },
    gradientColor = 'rgba(212, 175, 55, 0.4)',
    -- onUse garantit qu'on ne consomme JAMAIS la douille (meme si tab_douilles est arrete).
    onUse = function(source, itemData, itemDef)
        return false
    end,
    -- L'analyse balistique est geree par la ressource tab_douilles (appel pcall-protege).
    export = 'pop_inventory:onUseDouille',
  },

}

for id, def in pairs(items) do
  Config.Items[id] = def
end
