Config = Config or {}
Config.GouvUSAccount = 'society_gouv'
Config.GouvMXAccount = 'society_gouv2'
Config.EnablePagerSlot = true

-- =============================================
--  RADIO / TALKIE-WALKIE : apparence du panneau
--  'modern' = talkie moderne d'origine (par défaut)
--  '80s'    = skin rétro SECURECOM (talkie de base remplacé visuellement)
--  Le talkie de base n'est PAS supprimé : il suffit de remettre 'modern' ici.
-- =============================================
Config.RadioSkin = '80s'

-- =============================================
--  ADMIN : Sélecteur d'items
--  Accès au bouton admin (rouge) de l'inventaire : plus de licences écrites ici.
--  Ont accès : les admins de pop_admin, et les permissions ACE 'pop.admin'
--  (group.admin dans pop.cfg) ou 'pop_inventory.admin'.
--  Liste de secours si besoin (license:..., discord:...), à laisser vide de préférence.
-- =============================================
Config.AdminIdentifiers = {}

Config.Inventory = {
  ContainerOrder = { 
    'panta', 'hoddie', 'backpack', 'briefcase', 'cardboard_box', 'safe',
    'wallet', 'kevlar', 'pot_peinture'
  },
  WeightMode = 'A',
  AutoSaveIntervalMs = 30000,
}

Config.Ground = {
  Slots = 12,
  MaxWeight = 100.0,
  Radius = 3.0,
  ViewRadius = 3.0,
  MergeDistance = 2.0,
  Marker = {
    Enabled = true,
    Type = 2,
    Scale = { x = 0.32, y = 0.32, z = 0.2 },
    Color = { r = 255, g = 255, b = 255, a = 180 },
    DrawDistance = 20.0,
    OffsetZ = 0.1,
  },
}

Config.Persistence = {
  UseDatabase = true,
  GroundToDatabase = true,
  GroundSaveId = 'ground',
  GroundSaveIntervalMs = 30000,
  InventoriesTable = 'tab_inventory_inventories',
  GroundTable = 'tab_inventory_ground',
}

Config.GroundProps = {
  default = 'prop_overalls_01',
  backpack = 'prop_big_bag_01',
  briefcase = 'prop_ld_case_01',
  cardboard_box = 'prop_cs_cardbox_01',
  safe = 'prop_ld_int_safe_01',
  wallet = 'prop_ld_wallet_01',
  smg = 'w_sb_smg',
  phone = 'prop_phone_ing',
  radio = 'prop_cs_hand_radio',
  bouteille = 'prop_ld_flow_bottle',
  cash = 'prop_anim_cash_pile_01',
  carkeys = 'p_car_keys_01',
  tyre = 'prop_wheel_tyre',
  tyre_burst = 'prop_wheel_tyre',
  
  -- EMS Props
  civiere = 'combicarrier2',
  bequille = 'crutch',
  defib = 'lifepak15',
  lucas = 'lucas3',
  brancard = 'strykergurney',
  fauteuil = 'iak_wheelchair',
  aed = 'lifepak15',
  kitsoins = 'prop_ld_case_01',
  repakit = 'prop_ld_case_01',

  -- =========================================================================
  -- Régularisation props au sol (>=80% des items).
  -- Les VETEMENTS (panta, hoddie, tshirt, shoes, hat, glasses, mask, tie,
  -- kevlar, policevest, ears, watch, bracelet, accessory, decal) sont laissés
  -- volontairement sur `default = prop_overalls_01`, qui leur convient déjà.
  -- Tout nom de modèle inconnu de GTA est auto-remplacé par `default` et loggué
  -- (audit client -> pop_inventory:server:reportInvalidGroundProps).
  -- Les génériques s'appuient sur des props déjà éprouvés (cardbox/case/bag/bottle).
  -- =========================================================================

  -- Documents / papier / cartes / électronique
  idcard            = 'prop_notepad_01',
  idcard_mx         = 'prop_notepad_01',
  passport_us       = 'prop_notepad_01',
  passport_mx       = 'prop_notepad_01',
  creditcard        = 'prop_ld_wallet_01',
  file              = 'prop_notepad_01',
  newspaper         = 'prop_notepad_01',
  paper             = 'prop_notepad_01',
  print_document    = 'prop_notepad_01',
  notepad           = 'prop_notepad_01',
  tableau           = 'prop_cs_cardbox_01',
  plaque            = 'prop_cs_cardbox_01',
  polaroid_card     = 'prop_notepad_01',
  polaroid_cam      = 'prop_pap_camera_01',
  printer           = 'prop_cs_cardbox_01',
  sim_card          = 'prop_phone_ing',
  tpe               = 'prop_cs_tablet',
  pcb               = 'prop_cs_cardbox_01',
  pager             = 'prop_phone_ing',
  retrophone        = 'prop_phone_ing',
  walkman           = 'prop_phone_ing',
  megaphone         = 'prop_cs_hand_radio',

  -- Cassettes / pièces audio (custom, pas d'équivalent natif -> petite boîte)
  cassette_duz_it                  = 'prop_cs_cardbox_01',
  cassette_tnt                     = 'prop_cs_cardbox_01',
  cassette_bad_boys                = 'prop_cs_cardbox_01',
  cassette_smooth_criminal         = 'prop_cs_cardbox_01',
  cassette_cant_c_me               = 'prop_cs_cardbox_01',
  cassette_think_about_the_way     = 'prop_cs_cardbox_01',
  cassette_get_a_way               = 'prop_cs_cardbox_01',
  composant_cassette               = 'prop_cs_cardbox_01',
  bande_magnetique                 = 'prop_cs_cardbox_01',

  -- Argent

  -- Drogues / chimie
  pot               = 'prop_meth_bag_01',
  grainecana        = 'prop_meth_bag_01',
  weed              = 'bkr_prop_weed_bag_01',
  pochon            = 'prop_meth_bag_01',
  pochonweed        = 'bkr_prop_weed_bag_01',
  empty_baggy       = 'prop_meth_bag_01',
  cocaine_powder    = 'prop_meth_bag_01',
  baking_soda       = 'prop_meth_bag_01',
  meth_pure         = 'prop_meth_bag_01',
  crack_rock        = 'prop_meth_bag_01',
  methylamine       = 'prop_ld_flow_bottle',
  chemical_substance= 'prop_ld_flow_bottle',
  battery_acid      = 'prop_ld_flow_bottle',

  -- Armes (modèles d'arme = props valides)
  pistol            = 'w_pi_pistol',
  revolver          = 'w_pi_revolver',
  carabine          = 'w_ar_carbinerifle',
  tazer             = 'w_pi_stungun',
  flipper           = 'prop_cs_cardbox_01',

  -- Accessoires d'arme / chargeurs (composants -> boîte générique, sûr)
  chargeur_pistol   = 'prop_cs_cardbox_01',
  chargeur_smg      = 'prop_cs_cardbox_01',
  chargeur_fusil    = 'prop_cs_cardbox_01',
  suppressor_pistol = 'prop_cs_cardbox_01',
  flashlight_pistol = 'prop_cs_cardbox_01',
  ext_clip_pistol   = 'prop_cs_cardbox_01',
  suppressor_rifle  = 'prop_cs_cardbox_01',
  scope_rifle       = 'prop_cs_cardbox_01',
  flashlight_rifle  = 'prop_cs_cardbox_01',
  ext_clip_rifle    = 'prop_cs_cardbox_01',
  grip_rifle        = 'prop_cs_cardbox_01',
  suppressor_smg    = 'prop_cs_cardbox_01',
  scope_smg         = 'prop_cs_cardbox_01',
  flashlight_smg    = 'prop_cs_cardbox_01',
  ext_clip_smg      = 'prop_cs_cardbox_01',

  -- Outils / serrurerie
  menottes          = 'prop_cs_cardbox_01',
  sabot             = 'prop_cs_cardbox_01',
  cle_sabot         = 'p_car_keys_01',
  cle               = 'p_car_keys_01',
  house_key         = 'p_car_keys_01',
  lockpick          = 'prop_tool_screwdvr01',
  pliers            = 'prop_tool_adjspanner',
  ciseaux           = 'prop_tool_screwdvr01',
  insulating_tape   = 'prop_cs_cardbox_01',
  ressort           = 'prop_cs_cardbox_01',
  cylindre          = 'prop_cs_cardbox_01',
  police_barrier    = 'prop_barrier_work06a',
  police_stormram   = 'prop_ld_case_01',
  lampe             = 'prop_cs_hand_radio',
  uvpocketlight     = 'prop_cs_hand_radio',
  douille           = 'prop_cs_cardbox_01',

  -- Pièces véhicule / carburant
  huile_moteur          = 'prop_jerrycan_01a',
  carburant             = 'prop_jerrycan_01a',
  jerry                 = 'prop_jerrycan_01a',
  baril                 = 'prop_barrel_02a',
  batterie              = 'prop_car_battery_01',
  pneu                  = 'prop_wheel_tyre',
  freins                = 'prop_cs_cardbox_01',
  pieces_moteur         = 'prop_cs_cardbox_01',
  pieces_transmission   = 'prop_cs_cardbox_01',
  pieces_suspension     = 'prop_cs_cardbox_01',
  pieces_carrosserie    = 'prop_cs_cardbox_01',
  moteur                = 'prop_cs_cardbox_01',
  bloc_moteur           = 'prop_cs_cardbox_01',
  piston_casse          = 'prop_cs_cardbox_01',
  kit_reparation_vegatech = 'prop_ld_case_01',

  -- Peinture
  peinture_rouge    = 'prop_cs_cardbox_01',
  peinture_jaune    = 'prop_cs_cardbox_01',
  peinture_bleue    = 'prop_cs_cardbox_01',
  pistolet_peinture = 'prop_cs_cardbox_01',
  pot_peinture      = 'prop_paints_can01',

  -- Nourriture / boissons (générique boîte/sac/bouteille/canette)
  hotdog            = 'prop_cs_burger_01',
  soda              = 'prop_ecola_can',
  cola              = 'prop_ecola_can',
  sparkling_water   = 'prop_ld_flow_bottle',
  sugar_syrup       = 'prop_ld_flow_bottle',
  blue_curacao_syrup= 'prop_ld_flow_bottle',
  pineapple_juice   = 'prop_ld_flow_bottle',
  tonic_water       = 'prop_ld_flow_bottle',
  limonade_fermiere = 'prop_ld_flow_bottle',
  mocktail_lagon_bleu = 'prop_ld_flow_bottle',
  cooking_oil       = 'prop_ld_flow_bottle',
  bbq_sauce         = 'prop_ld_flow_bottle',
  lemon_butter      = 'prop_paper_bag_01',
  cocktail_glass    = 'prop_cs_cardbox_01',
  plastic_cup       = 'prop_cs_cardbox_01',
  porcelain_plate   = 'prop_cs_cardbox_01',
  raw_chicken       = 'prop_paper_bag_01',
  nuggets_poulailler= 'prop_paper_bag_01',
  seau_du_coq       = 'prop_paper_bag_01',
  brioche_bun       = 'prop_paper_bag_01',
  sandwich_homard   = 'prop_paper_bag_01',
  lemon             = 'prop_paper_bag_01',
  lemon_slice       = 'prop_paper_bag_01',
  crushed_ice       = 'prop_paper_bag_01',
  fresh_oysters     = 'prop_paper_bag_01',
  fresh_lobster     = 'prop_paper_bag_01',
  plateau_huitres   = 'prop_paper_bag_01',
  pearls_wrapper    = 'prop_paper_bag_01',
  paper_bag         = 'prop_paper_bag_01',
  lucky_box         = 'prop_cs_cardbox_01',
  secret_breadcrumbs= 'prop_paper_bag_01',
}

Config.VehicleTrunks = {
  default = { slots = 60, maxWeight = 200.0 },
  ['ambulance'] = { slots = 80, maxWeight = 500.0 },
}

Config.Items = {
  -- EMS Items
  civiere = {
    label    = 'Civière',
    weight   = 2.0,
    maxStack = 5,
    icon     = 'img/civiere.png',
    tags     = { 'misc', 'ems' },
  },
  bequille = {
    label    = 'Béquille',
    weight   = 1.0,
    maxStack = 5,
    icon     = 'img/bequille.png',
    tags     = { 'misc', 'ems' },
  },
  defib = {
    label    = 'Défibrillateur',
    weight   = 5.0,
    maxStack = 1,
    icon     = 'img/defib.png',
    tags     = { 'misc', 'ems' },
  },
  lucas = {
    label    = 'Lucas (CPR)',
    weight   = 4.0,
    maxStack = 1,
    icon     = 'img/lucas.png',
    tags     = { 'misc', 'ems' },
  },
  brancard = {
    label    = 'Brancard',
    weight   = 15.0,
    maxStack = 1,
    icon     = 'img/brancard.png',
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
    icon     = 'img/fauteuil.png',
    tags     = { 'misc', 'ems' },
  },

  pot = {
    label       = 'Pot de fleur',
    weight      = 1.0,
    maxStack    = 10,
    icon        = 'img/pot.png',
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
    icon     = 'img/idcard.png',
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
    icon     = 'img/idcard.png',
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
    icon     = 'img/idcard.png',
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
    icon     = 'img/idcard.png',
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
    icon     = 'img/grainecana.png',
    tags     = { 'misc' },
  },
  weed = {
    label    = 'Weed',
    weight   = 0.3,
    maxStack = 50,
    icon     = 'img/weed.png',
    tags     = { 'misc', 'drug' },
  },
  panta = {
    label = 'Pantalon',
    weight = 1.2,
    maxStack = 1,
    icon = 'img/pants.png',
    equipSlot = 'panta',
    container = { slots = 10, maxWeight = 25.0 },
    tags = { 'clothing', 'container' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  hoddie = {
    label = 'Hoodie',
    weight = 1.0,
    maxStack = 1,
    icon = 'img/hoddie.png',
    equipSlot = 'hoddie',
    container = { slots = 10, maxWeight = 25.0 },
    tags = { 'clothing', 'container' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  backpack = {
    label = 'Sac',
    weight = 1.8,
    maxStack = 1,
    icon = 'img/backpack.png',
    equipSlot = 'backpack',
    container = { slots = 22, maxWeight = 20.0 },
    tags = { 'clothing', 'container' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
  },
  briefcase = {
    label = 'Malette',
    weight = 2.0,
    maxStack = 1,
    icon = 'img/briefcase.png',
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
    icon = 'img/cardboard_box.png',
    equipSlot = 'briefcase',
    container = { slots = 20, maxWeight = 30.0 },
    tags = { 'clothing', 'container' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  wallet = {
    label = 'Portefeuille',
    weight = 0.2,
    maxStack = 1,
    icon = 'img/wallet.png',
    equipSlot = 'wallet',
    container = { slots = 4, maxWeight = 2.0 },
    tags = { 'clothing', 'container' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
  },
  kevlar = {
    label = 'Kevlar',
    weight = 2.5,
    maxStack = 1,
    icon = 'img/kevlar.png',
    equipSlot = 'kevlar',
    container = { slots = 12, maxWeight = 15.0 },
    tags = { 'clothing', 'container' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
  },
  tshirt = {
    label = 'T-Shirt',
    weight = 0.3,
    maxStack = 1,
    icon = 'img/tshirt.png',
    equipSlot = 'tshirt',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  shoes = {
    label = 'Chaussures',
    weight = 0.8,
    maxStack = 1,
    icon = 'img/shoes.png',
    equipSlot = 'shoes',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  hat = {
    label = 'Chapeau',
    weight = 0.3,
    maxStack = 1,
    icon = 'img/hat.png',
    equipSlot = 'hat',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  glasses = {
    label = 'Lunettes',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/glasses.png',
    equipSlot = 'glasses',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  mask = {
    label = 'Masque',
    weight = 0.2,
    maxStack = 1,
    icon = 'img/mask.png',
    equipSlot = 'mask',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  tie = {
    label = 'Cravate',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/unknown.png',
    equipSlot = 'tie',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  phone = {
    label = 'Téléphone',
    weight = 0.2,
    maxStack = 1,
    icon = 'img/phone.png',
    equipSlot = 'phone',
    usable = true,
    container = { slots = 1, maxWeight = 0.1 }, -- 1 case pour la carte SIM
    tags = { 'communication', 'container' },
    gradientColor = 'rgba(60, 94, 133, 0.7)',
    onUse = function(source, item, def)
      print(('^6[pop_inventory] phone.onUse source=%s — routing to lb-phone^7'):format(tostring(source)))
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
        print('^3[pop_inventory] phone.onUse: lb-phone not started, using fallback^7')
        TriggerClientEvent('phone:toggleOpen', source, true)
      end
      return false
    end,
  },
  sim_card = {
    label = 'Carte SIM',
    weight = 0.01,
    maxStack = 1,
    icon = 'img/sim_card.png',
    tags = { 'communication', 'sim_card' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
  },
  radio = {
    label = 'Radio',
    weight = 0.5,
    icon = 'img/radio.png',
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
    icon        = 'img/bouteille.png',
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
    icon = 'img/tpe.png',
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
    icon = 'img/menottes.png',
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
    icon = 'img/clamp.png', -- remplace par img/sabot.png si tu ajoutes l'icone
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
    icon = 'img/carkeys.png',
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
    icon = 'img/carkeys.png',
    tags = { 'misc', 'doorlock' },
    gradientColor = 'rgba(200, 180, 50, 0.4)',
  },
  douille = {
    label = 'Douille',
    weight = 0.05,
    maxStack = 1, -- chaque douille est une preuve unique (meta differente -> ne se stacke jamais)
    icon = 'img/douille.png', -- remplace par img/douille.png si tu ajoutes l'icone
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

  -- ===== CHARGEURS (s'inserent dans le conteneur de l'arme, cf. tab_chargeurs) =====
  -- Le tag 'magazine' + Config.ContainerRestrictions controlent quelle arme accepte quoi.
  -- meta.rounds / meta.customLabel sont geres par tab_chargeurs.
  chargeur_pistol = {
    label = 'Chargeur Pistolet',
    weight = 0.25,
    maxStack = 1, -- chaque chargeur a son propre compteur de balles (meta)
    icon = 'img/chargeurpistolet.png',
    tags = { 'magazine' },
    gradientColor = 'rgba(70, 70, 80, 0.5)',
  },
  chargeur_smg = {
    label = 'Chargeur SMG',
    weight = 0.4,
    maxStack = 1,
    icon = 'img/chargeurmitraillette.png',
    tags = { 'magazine' },
    gradientColor = 'rgba(70, 70, 80, 0.5)',
  },
  chargeur_fusil = {
    label = 'Chargeur Fusil',
    weight = 0.5,
    maxStack = 1,
    icon = 'img/chargeurfusil.png',
    tags = { 'magazine' },
    gradientColor = 'rgba(70, 70, 80, 0.5)',
  },

 
  aed = {
    label = 'Défibrillateur',
    weight = 2.0,
    maxStack = 1,
    icon = 'img/aed.png',
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
    icon = 'img/kitsoins.png',
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
    icon = 'img/unknown.png',
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
    icon = 'img/wheel.png',
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
    icon = 'img/wheel.png',
    usable = false,
    tags = { 'tools', 'mechanic' },
    gradientColor = 'rgba(200, 30, 30, 0.60)', -- Fond rouge pour indiquer qu'il est cassé
  },
  cash = {
    label = 'Argent',
    weight = 0.001,
    maxStack = 100000,
    icon = 'img/dollar.png',
    tags = { 'cash' },
    gradientColor = 'rgba(70, 146, 81, 0.59)',
  },
  -- Objet gardé seulement pour que les anciens pesos restent visibles (et jetables) :
  -- plus aucune boutique ne les vend ni ne les accepte.
  pesos = {
    label = 'Pesos',
    weight = 0.001,
    maxStack = 100000,
    icon = 'img/pesos.png',
    tags = { 'cash' },
    gradientColor = 'rgba(200, 160, 40, 0.59)',
  },
  creditcard = {
    label = 'Carte de Crédit',
    weight = 0.01,
    maxStack = 10,
    icon = 'img/creditcard.png',
    tags = { 'creditcard' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  ears = {
    label = 'Oreilles',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/unknown.png',
    equipSlot = 'ears',
    tags = { 'clothing' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
  },
  watch = {
    label = 'Montre',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/watch.png',
    equipSlot = 'watch',
    tags = { 'clothing' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
  },
  bracelet = {
    label = 'Bracelet',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/unknown.png',
    equipSlot = 'bracelet',
    tags = { 'clothing' },
    gradientColor = 'rgba(71, 23, 68, 0.40)',
  },
  accessory = {
    label = 'Accessoire',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/unknown.png',
    equipSlot = 'accessory',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  decal = {
    label = 'Sticker / Écusson',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/unknown.png',
    equipSlot = 'decal',
    tags = { 'clothing' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },
  file = {
    label = 'Document',
    weight = 0.01,
    maxStack = 10,
    icon = 'img/file.png',
    tags = { 'misc' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  methylamine = {
    label = 'Methylamine',
    weight = 1.0,
    maxStack = 10,
    icon = 'img/unknown.png',
    tags = { 'chimique' },
    gradientColor = 'rgba(60, 94, 133, 0.7)',
  },
  carburant = {
    label = 'Carburant',
    weight = 0.02,
    maxStack = 5000,
    icon = 'img/carburant.png',
    tags = { 'ressource' },
    gradientColor = 'rgba(30, 30, 30, 0.68)',
  },
  baril = {
    label = 'Baril',
    weight = 10.0,
    maxStack = 2,
    icon = 'img/unknown.png',
    tags = { 'conteneur' },
    gradientColor = 'rgba(120, 120, 120, 0.40)',
  },
  smg = {
    label = 'SMG',
    weight = 5.5,
    maxStack = 1, -- a un chargeur interne (conteneur) -> instance unique
    icon = 'img/smg.png',
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
    icon = 'img/smg.png',
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
    icon = 'img/carkeys.png',
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
    icon = 'img/lampe.png',
    tags = { 'tool' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  uvpocketlight = {
    label       = 'Lampe UV',
    weight      = 0.4,
    maxStack    = 1,
    icon        = 'img/uvpocketlight.png',
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
    icon = 'img/megaphone.png',
    tags = { 'tool' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  pistol = {
    label = 'Pistolet',
    weight = 1.2,
    maxStack = 1, -- a un chargeur interne (conteneur) -> instance unique
    icon = 'img/pistol.png',
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
    icon = 'img/pistol.png',
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
    icon = 'img/policevest.png',
    equipSlot = 'kevlar',
    container = { slots = 12, maxWeight = 15.0 },
    tags = { 'clothing', 'container', 'police' },
    gradientColor = 'rgba(60, 94, 133, 0.7)',
  },
  safe = {
    label = 'Coffre-fort',
    weight = 10.0,
    maxStack = 1,
    icon = 'img/safe.png',
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
    icon = 'img/safe.png',
    container = { slots = 8, maxWeight = 15.0 },
    tags = { 'misc', 'container', 'casier' },
    gradientColor = 'rgba(90, 110, 180, 0.40)',
  },
  tazer = {
    label = 'Tazer',
    weight = 1.0,
    maxStack = 4,
    icon = 'img/tazer.png',
    equipSlot = 'weapon_tazer',
    tags = { 'weapon', 'police' },
    gradientColor = 'rgba(88, 160, 60, 0.35)',
    weaponHash = 'WEAPON_STUNGUN',
  },
  flipper = {
    label = 'Flipper',
    weight = 0.2,
    maxStack = 2,
    icon = 'img/flipper.png',
    tags = { 'tool' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  pcb = {
    label = 'Module pirate',
    weight = 0.2,
    maxStack = 2,
    icon = 'img/pcb.png',
    tags = { 'tool' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  hotdog = {
    label = 'Hotdog',
    weight = 0.2,
    maxStack = 5,
    icon = 'img/hotdog.png',
    usable = true,
    tags = { 'food' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('esx_status:add', source, 'hunger', 250000)
        TriggerClientEvent('esx_basicneeds:onEat', source)
        return true
    end,
  },
  jerry = {
    label = "Bidon D'essence",
    weight = 0.2,
    maxStack = 2,
    icon = 'img/jerry.png',
    tags = { 'tool' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  soda = {
    label = 'Soda',
    weight = 0.35,
    maxStack = 5,
    icon = 'img/soda.png',
    usable = true,
    tags = { 'food' },
    gradientColor = 'rgba(60, 94, 133, 0.7)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('esx_status:add', source, 'thirst', 200000)
        TriggerClientEvent('esx_basicneeds:onDrink', source)
        return true
    end,
  },
  cola = {
    label = 'Cola',
    weight = 0.35,
    maxStack = 5,
    icon = 'img/cola.png',
    usable = true,
    tags = { 'food' },
    gradientColor = 'rgba(180, 50, 50, 0.350)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('esx_status:add', source, 'thirst', 200000)
        TriggerClientEvent('esx_basicneeds:onDrink', source)
        return true
    end,
  },
  house_key = {
    label = 'Housing Key',
    weight = 0.01,
    maxStack = 1,
    icon = 'img/unknown.png',
    tags = { 'misc' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  lockpick = {
    label = 'Lockpick',
    weight = 0.8,
    maxStack = 5,
    icon = 'img/unknown.png',
    tags = { 'tool' },
    usable = true,
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  police_barrier = {
    label = 'Police Barrier',
    weight = 0.3,
    maxStack = 5,
    icon = 'img/unknown.png',
    tags = { 'police', 'tool' },
    usable = true,
    gradientColor = 'rgba(60, 94, 133, 0.7)',
  },
  police_stormram = {
    label = 'Police Storm Ram',
    weight = 5.0,
    maxStack = 1,
    icon = 'img/unknown.png',
    tags = { 'police', 'tool' },
    usable = true,
    gradientColor = 'rgba(60, 94, 133, 0.7)',
  },
  pliers = {
    label = 'Pliers',
    weight = 0.5,
    maxStack = 5,
    icon = 'img/unknown.png',
    tags = { 'tool' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  insulating_tape = {
    label = 'Insulating Tape',
    weight = 0.2,
    maxStack = 5,
    icon = 'img/unknown.png',
    tags = { 'tool' },
    gradientColor = 'rgba(180, 140, 90, 0.40)',
  },
  weed = {
    label = 'Weed',
    weight = 0.05,
    maxStack = 50,
    icon = 'img/weed.png',
    tags = { 'drugs' },
    gradientColor = 'rgba(88, 160, 60, 0.45)',
  },
  
  pochon = {
    label = 'Pochon Vide',
    weight = 0.01,
    maxStack = 100,
    icon = 'img/pochon.png',
    tags = { 'misc' },
    gradientColor = 'rgba(200, 200, 200, 0.40)',
  },
  pochonweed = {
    label = 'Pochon de Weed',
    weight = 0.06,
    maxStack = 50,
    icon = 'img/pochonweed.png',
    tags = { 'drugs' },
    gradientColor = 'rgba(88, 160, 60, 0.55)',
    usable = true,
    onUse = function(source, itemData, itemDef)
        -- Active/désactive le mode "vente de drogue" (clients viennent à toi)
        local ok = pcall(function() exports.pop_dealing:toggleSelling(source) end)
        if not ok then
            TriggerClientEvent('notification:client:send', source, {
                title = 'Vente', message = 'Système de vente indisponible.', type = 'error',
            })
        end
        return false -- ne pas consommer le pochon
    end,
  },
  plaque = {
    label = 'Plaque en métal',
    weight = 0.5,
    maxStack = 50,
    icon = 'img/plaque.png',
    tags = { 'material' },
    gradientColor = 'rgba(120, 120, 120, 0.40)',
  },
  cylindre = {
    label = 'Cylindre en acier',
    weight = 0.8,
    maxStack = 20,
    icon = 'img/cylindre.png',
    tags = { 'material' },
    gradientColor = 'rgba(120, 120, 120, 0.40)',
  },
  ressort = {
    label = 'Ressort en acier',
    weight = 0.1,
    maxStack = 50,
    icon = 'img/ressort.png',
    tags = { 'material' },
    gradientColor = 'rgba(120, 120, 120, 0.40)',
  },
  newspaper = {
    label = 'Journal',
    weight = 0.2,
    maxStack = 20,
    icon = 'img/unknown.png',
    weaponHash = 'WEAPON_ACIDPACKAGE',
    tags = { 'weapon' },
    gradientColor = 'rgba(240, 240, 240, 0.40)',
  },
  ciseaux = {
    label = 'Ciseaux',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/ciseaux.png',
    usable = true,
    tags = { 'tools' },
    gradientColor = 'rgba(180, 180, 180, 0.4)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('pop_inventory:client:useCiseaux', source)
        return false -- Do not consume the item directly
    end,
  },
  printer = {
    label = 'Imprimante',
    weight = 5.0,
    maxStack = 1,
    icon = 'img/printer.png',
    usable = true,
    tags = { 'tools' },
    gradientColor = 'rgba(180, 180, 180, 0.4)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('mt_printers:client:usePrinter', source, itemData)
        return false 
    end,
  },
  paper = {
    label = 'Rame de papier',
    weight = 0.5,
    maxStack = 10,
    icon = 'img/paper.png',
        gradientColor = 'rgba(180, 180, 180, 0.4)',
    tags = { 'misc' },
  },
  print_document = {
    label = 'Document imprimé',
    weight = 0.05,
    maxStack = 50,
    icon = 'img/file.png',
    gradientColor = 'rgba(180, 180, 180, 0.4)',
    usable = true,
    tags = { 'misc' },
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('mt_printers:client:useDocument', source, itemData)
        return false
    end,
  },
  tableau = {
    label = 'Châssis Entoilé',
    weight = 1.0,
    maxStack = 5,
    icon = 'img/unknown.png',
    usable = true,
    tags = { 'misc' },
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('pop_boards:client:placement', source)
        return false 
    end,
  },
  notepad = {
    label = 'Carnet',
    weight = 0.2,
    maxStack = 10,
    icon = 'img/notepad.png',
    usable = true,
    tags = { 'misc' },
        gradientColor = 'rgba(180, 140, 90, 0.40)',
    onUse = function(source, itemData, itemDef)
        TriggerClientEvent('lkrp_notepad:note', source)
        TriggerClientEvent('lkrp_notepad:OpenNotepadGui', source, itemData)
        return false 
    end,
  },
  pager = {
    label = 'Pager',
    weight = 0.1,
    maxStack = 1,
    icon = 'img/pager.png',
    equipSlot = Config.EnablePagerSlot and 'pager' or nil,
    tags = { 'communication' },
    usable = true,
    gradientColor = 'rgba(60, 94, 133, 0.7)',
    onUse = function(source, itemData, itemDef)
      exports['plt_pager']:openPager('usingItem', itemData, { id = source, owner = true }, itemData.id)
      return false
    end,
  },
  retrophone = {
    label = 'Téléphone Rétro',
    weight = 0.2,
    maxStack = 1,
    icon = 'img/retrophone.png',
    equipSlot = 'phone',
    tags = { 'communication' },
    usable = true,
    gradientColor = 'rgba(60, 94, 133, 0.7)',
    onUse = function(source, itemData, itemDef)
      exports['plt_retrophone']:openRetrophone('usingItem', itemData, { id = source, owner = true }, itemData.id)
      return false
    end,
  },
  walkman = {
    label = 'Walkman',
    weight = 0.3,
    maxStack = 1,
    icon = 'img/walkman.png',
    tags = { 'misc' },
    usable = true,
    gradientColor = 'rgba(180, 140, 90, 0.40)',
    onUse = function(source, itemData, itemDef)
      exports['plt_walkman']:openWalkman('usingItem', itemData, { id = source, owner = true }, itemData.id)
      return false
    end,
  },
  polaroid_cam = {
    label = 'Polaroid Davis 1992',
    weight = 0.5,
    maxStack = 1,
    icon = 'img/polaroid_cam.png',
    tags = { 'misc' },
    usable = true,
    gradientColor = 'rgba(180, 140, 90, 0.40)',
    clientEvent = 'polaroid:useCamera',
  },
  polaroid_card = {
    label = 'Photo Polaroid',
    weight = 0.01,
    maxStack = 10,
    icon = 'img/polaroid_card.png',
    tags = { 'misc' },
    usable = true,
    gradientColor = 'rgba(230, 230, 230, 0.40)',
    clientEvent = 'polaroid:viewCard',
  },
  cassette_duz_it = {
    label = 'Cassette - Duz It',
    weight = 0.1,
    maxStack = 5,
    icon = 'img/cassette.png',
    tags = { 'misc' },
  },
  cassette_tnt = {
    label = 'Cassette - TNT',
    weight = 0.1,
    maxStack = 5,
    icon = 'img/cassette.png',
    tags = { 'misc' },
  },
  cassette_bad_boys = {
    label = 'Cassette - Bad Boys',
    weight = 0.1,
    maxStack = 5,
    icon = 'img/cassette.png',
    tags = { 'misc' },
  },
  cassette_smooth_criminal = {
    label = 'Cassette - Smooth Criminal',
    weight = 0.1,
    maxStack = 5,
    icon = 'img/cassette.png',
    tags = { 'misc' },
  },
  cassette_cant_c_me = {
    label = 'Cassette - Cant C Me',
    weight = 0.1,
    maxStack = 5,
    icon = 'img/cassette.png',
    tags = { 'misc' },
  },
  cassette_think_about_the_way = {
    label = 'Cassette - Think About The Way',
    weight = 0.1,
    maxStack = 5,
    icon = 'img/cassette.png',
    tags = { 'misc' },
  },
  cassette_get_a_way = {
    label = 'Cassette - Get A Way',
    weight = 0.1,
    maxStack = 5,
    icon = 'img/cassette.png',
    tags = { 'misc' },
  },
  composant_cassette = {
    label = 'Composant de Cassette',
    weight = 0.05,
    maxStack = 100,
    icon = 'img/unknown.png',
    tags = { 'material' },
    gradientColor = 'rgba(120, 120, 120, 0.40)',
  },
  bande_magnetique = {
    label = 'Bande Magnétique',
    weight = 0.02,
    maxStack = 100,
    icon = 'img/unknown.png',
    tags = { 'material' },
    gradientColor = 'rgba(120, 120, 120, 0.40)',
  },
  kit_reparation_vegatech = {
    label = 'Kit de Réparation Vega Tech',
    weight = 0.8,
    maxStack = 10,
    icon = 'img/unknown.png',
    tags = { 'tool' },
    gradientColor = 'rgba(92, 58, 86, 0.64)',
  },


  -- ============================================================
  --  ACCESSOIRES D'ARMES
  --  Items consommés lorsqu'attachés à une arme (cf. Config.WeaponAttachments).
  --  Le détachement les restitue dans l'inventaire.
  -- ============================================================
  suppressor_pistol = {
    label = 'Silencieux Pistolet',
    weight = 0.3,
    maxStack = 5,
    icon = 'img/unknown.png',
    tags = { 'weapon_attachment', 'attachment_pistol' },
    gradientColor = 'rgba(50, 50, 50, 0.45)',
  },
  flashlight_pistol = {
    label = 'Lampe Pistolet',
    weight = 0.2,
    maxStack = 5,
    icon = 'img/unknown.png',
    tags = { 'weapon_attachment', 'attachment_pistol' },
    gradientColor = 'rgba(220, 200, 100, 0.40)',
  },
  ext_clip_pistol = {
    label = 'Chargeur Étendu Pistolet',
    weight = 0.4,
    maxStack = 5,
    icon = 'img/unknown.png',
    tags = { 'weapon_attachment', 'attachment_pistol' },
    gradientColor = 'rgba(100, 100, 100, 0.40)',
  },
  suppressor_rifle = {
    label = 'Silencieux Fusil',
    weight = 0.6,
    maxStack = 5,
    icon = 'img/unknown.png',
    tags = { 'weapon_attachment', 'attachment_rifle' },
    gradientColor = 'rgba(50, 50, 50, 0.45)',
  },
  scope_rifle = {
    label = 'Viseur Fusil',
    weight = 0.5,
    maxStack = 5,
    icon = 'img/unknown.png',
    tags = { 'weapon_attachment', 'attachment_rifle' },
    gradientColor = 'rgba(80, 110, 60, 0.40)',
  },
  flashlight_rifle = {
    label = 'Lampe Fusil',
    weight = 0.3,
    maxStack = 5,
    icon = 'img/unknown.png',
    tags = { 'weapon_attachment', 'attachment_rifle' },
    gradientColor = 'rgba(220, 200, 100, 0.40)',
  },
  ext_clip_rifle = {
    label = 'Chargeur Étendu Fusil',
    weight = 0.7,
    maxStack = 5,
    icon = 'img/unknown.png',
    tags = { 'weapon_attachment', 'attachment_rifle' },
    gradientColor = 'rgba(100, 100, 100, 0.40)',
  },
  grip_rifle = {
    label = 'Poignée Fusil',
    weight = 0.2,
    maxStack = 5,
    icon = 'img/unknown.png',
    tags = { 'weapon_attachment', 'attachment_rifle' },
    gradientColor = 'rgba(100, 100, 100, 0.40)',
  },
  suppressor_smg = {
    label = 'Silencieux SMG',
    weight = 0.5,
    maxStack = 5,
    icon = 'img/unknown.png',
    tags = { 'weapon_attachment', 'attachment_smg' },
    gradientColor = 'rgba(50, 50, 50, 0.45)',
  },
  scope_smg = {
    label = 'Viseur SMG',
    weight = 0.4,
    maxStack = 5,
    icon = 'img/unknown.png',
    tags = { 'weapon_attachment', 'attachment_smg' },
    gradientColor = 'rgba(80, 110, 60, 0.40)',
  },
  flashlight_smg = {
    label = 'Lampe SMG',
    weight = 0.2,
    maxStack = 5,
    icon = 'img/unknown.png',
    tags = { 'weapon_attachment', 'attachment_smg' },
    gradientColor = 'rgba(220, 200, 100, 0.40)',
  },
  ext_clip_smg = {
    label = 'Chargeur Étendu SMG',
    weight = 0.5,
    maxStack = 5,
    icon = 'img/unknown.png',
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
    icon     = 'img/motoroil.png',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(30, 20, 10, 0.65)',
  },
  batterie = {
    label    = 'Batterie',
    weight   = 5.0,
    maxStack = 2,
    icon     = 'img/carbattery.png',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(60, 80, 40, 0.55)',
  },
  pneu = {
    label    = 'Pneu',
    weight   = 8.0,
    maxStack = 4,
    icon     = 'img/wheel.png',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(20, 20, 20, 0.65)',
  },
  freins = {
    label    = 'Freins',
    weight   = 3.0,
    maxStack = 4,
    icon     = 'img/brake.png',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(180, 40, 40, 0.45)',
  },
  pieces_moteur = {
    label    = 'Pièces Moteur',
    weight   = 4.0,
    maxStack = 5,
    icon     = 'img/motorpart.png',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(100, 80, 40, 0.50)',
  },
  pieces_transmission = {
    label    = 'Pièces Transmission',
    weight   = 3.5,
    maxStack = 5,
    icon     = 'img/transmissionpart.png',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(80, 80, 80, 0.50)',
  },
  pieces_suspension = {
    label    = 'Pièces Suspension',
    weight   = 3.0,
    maxStack = 5,
    icon     = 'img/suspension.png',
    tags     = { 'mechanic', 'auto' },
    gradientColor = 'rgba(60, 100, 120, 0.45)',
  },
  pieces_carrosserie = {
    label    = 'Pièces Carrosserie',
    weight   = 5.0,
    maxStack = 5,
    icon     = 'img/carpart.png',
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
    icon     = 'img/carengine.png',
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
    icon     = 'img/enginebloc.png',
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
    icon     = 'img/motorpart.png',
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
    icon     = 'img/redpaint.png',
    tags     = { 'peinture', 'material' },
    gradientColor = 'rgba(200, 40, 40, 0.55)',
  },
  peinture_jaune = {
    label    = 'Peinture Jaune',
    weight   = 0.01,
    maxStack = 100,
    icon     = 'img/yellowpaint.png',
    tags     = { 'peinture', 'material' },
    gradientColor = 'rgba(220, 200, 40, 0.55)',
  },
  peinture_bleue = {
    label    = 'Peinture Bleue',
    weight   = 0.01,
    maxStack = 100,
    icon     = 'img/bluepaint.png',
    tags     = { 'peinture', 'material' },
    gradientColor = 'rgba(40, 80, 200, 0.55)',
  },
  -- Pistolet a peinture (mecano) : arme longue, clic droit -> Utiliser pour
  -- choisir la couleur (cf. resource pressurewashermodels).
  pistolet_peinture = {
    label      = 'Pistolet a Peinture',
    weight     = 4.0,
    maxStack   = 1,
    icon       = 'img/paint_gun.png',
    equipSlot  = 'weapon_long',
    tags       = { 'weapon', 'weapon_long', 'tool' },
    gradientColor = 'rgba(120, 90, 200, 0.40)',
    weaponHash = 'WEAPON_PRESSURE1',
    usable     = true,
    onUse = function(source, item, def)
      print('^3[PAINTGUN][SV]^7 onUse pistolet_peinture src=' .. tostring(source) .. ' itemId=' .. tostring(item and item.id))
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
    icon     = 'img/paintcontainer.png',
    container = { slots = 1, maxWeight = 10.0 }, -- 1 slot x 100 unités x 0.1 kg = 10 kg
    tags     = { 'conteneur', 'peinture_container', 'container' },
    gradientColor = 'rgba(180, 180, 180, 0.40)',
  },

  -- ============================================================
  --  LUCKY PLUCKER (poulet frit rétro)
  -- ============================================================

  -- Ingrédients / contenants
  raw_chicken = {
    label = 'Poulet cru',
    weight = 0.4,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(220, 180, 150, 0.40)',
  },
  secret_breadcrumbs = {
    label = 'Chapelure secrète',
    weight = 0.2,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(200, 160, 90, 0.40)',
  },
  cooking_oil = {
    label = 'Huile de friture',
    weight = 0.5,
    maxStack = 20,
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(210, 190, 80, 0.40)',
  },
  lucky_box = {
    label = 'Boîte en carton Lucky',
    weight = 0.1,
    maxStack = 100,
    icon = 'img/unknown.png',
    tags = { 'misc', 'packaging' },
    gradientColor = 'rgba(180, 60, 50, 0.40)',
  },
  bbq_sauce = {
    label = 'Sauce barbecue',
    weight = 0.15,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(120, 50, 30, 0.45)',
  },
  paper_bag = {
    label = 'Sachet en papier',
    weight = 0.05,
    maxStack = 100,
    icon = 'img/unknown.png',
    tags = { 'misc', 'packaging' },
    gradientColor = 'rgba(190, 160, 110, 0.40)',
  },
  lemon = {
    label = 'Citron',
    weight = 0.1,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(220, 215, 70, 0.40)',
  },
  sparkling_water = {
    label = 'Eau pétillante',
    weight = 0.4,
    maxStack = 20,
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(150, 200, 220, 0.40)',
  },
  sugar_syrup = {
    label = 'Sirop de sucre',
    weight = 0.2,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(230, 220, 200, 0.40)',
  },
  plastic_cup = {
    label = 'Gobelet en plastique',
    weight = 0.05,
    maxStack = 100,
    icon = 'img/unknown.png',
    tags = { 'misc', 'packaging' },
    gradientColor = 'rgba(200, 200, 200, 0.40)',
  },

  -- Produits finaux Lucky Plucker
  seau_du_coq = {
    label = 'Seau du Coq',
    weight = 0.9,
    maxStack = 5,
    icon = 'img/unknown.png',
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
    icon = 'img/unknown.png',
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
    icon = 'img/unknown.png',
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
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(170, 190, 180, 0.40)',
  },
  lemon_slice = {
    label = 'Rondelle de citron',
    weight = 0.05,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(220, 215, 70, 0.40)',
  },
  crushed_ice = {
    label = 'Glace pilée',
    weight = 0.2,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(190, 220, 230, 0.40)',
  },
  porcelain_plate = {
    label = 'Assiette en porcelaine',
    weight = 0.4,
    maxStack = 20,
    icon = 'img/unknown.png',
    tags = { 'misc', 'packaging' },
    gradientColor = 'rgba(230, 230, 230, 0.40)',
  },
  fresh_lobster = {
    label = 'Homard frais',
    weight = 0.6,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(200, 70, 60, 0.40)',
  },
  brioche_bun = {
    label = 'Pain brioché',
    weight = 0.15,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(210, 170, 110, 0.40)',
  },
  lemon_butter = {
    label = 'Beurre citronné',
    weight = 0.1,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(230, 215, 130, 0.40)',
  },
  pearls_wrapper = {
    label = 'Emballage Pearls',
    weight = 0.05,
    maxStack = 100,
    icon = 'img/unknown.png',
    tags = { 'misc', 'packaging' },
    gradientColor = 'rgba(150, 200, 220, 0.40)',
  },
  blue_curacao_syrup = {
    label = 'Sirop de curaçao bleu',
    weight = 0.2,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(60, 120, 220, 0.45)',
  },
  pineapple_juice = {
    label = "Jus d'ananas",
    weight = 0.3,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(230, 200, 70, 0.40)',
  },
  tonic_water = {
    label = 'Schweppes / Tonic',
    weight = 0.35,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'food', 'ingredient' },
    gradientColor = 'rgba(200, 220, 230, 0.40)',
  },
  cocktail_glass = {
    label = 'Verre à cocktail',
    weight = 0.2,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'misc', 'packaging' },
    gradientColor = 'rgba(210, 210, 220, 0.40)',
  },

  -- Produits finaux Pearls Seafood
  plateau_huitres = {
    label = "Plateau d'Huîtres Del Perro",
    weight = 0.8,
    maxStack = 5,
    icon = 'img/unknown.png',
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
    icon = 'img/unknown.png',
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
    icon = 'img/unknown.png',
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
    icon = 'img/pochon.png',
    tags = { 'misc' },
    gradientColor = 'rgba(200, 200, 200, 0.40)',
  },

  -- Ingrédients
  chemical_substance = {
    label = 'Produit chimique',
    weight = 0.3,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'material', 'drug' },
    gradientColor = 'rgba(120, 220, 120, 0.40)',
  },
  battery_acid = {
    label = 'Acide de batterie',
    weight = 0.4,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'material', 'drug' },
    gradientColor = 'rgba(200, 200, 60, 0.40)',
  },
  cocaine_powder = {
    label = 'Poudre de cocaïne',
    weight = 0.2,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'material', 'drug' },
    gradientColor = 'rgba(240, 240, 240, 0.45)',
  },
  baking_soda = {
    label = 'Bicarbonate de soude',
    weight = 0.2,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'material', 'drug' },
    gradientColor = 'rgba(230, 230, 230, 0.40)',
  },

  -- Produits finaux
  meth_pure = {
    label = 'Cristaux Bleus (Meth)',
    weight = 0.05,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'drugs' },
    gradientColor = 'rgba(60, 120, 220, 0.55)',
  },
  crack_rock = {
    label = 'Caillou de Crack',
    weight = 0.05,
    maxStack = 50,
    icon = 'img/unknown.png',
    tags = { 'drugs' },
    gradientColor = 'rgba(230, 220, 200, 0.55)',
  },
  -- Système bancaire : chéquier (achetable en banque) et chèque (rempli via le chéquier)
  checkbook = {
    label    = 'Chéquier',
    weight   = 0.5,
    maxStack = 1,
    icon     = 'img/checkbook.png',
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
    icon     = 'img/checkbook.png',
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
    icon     = 'img/check.png',
    tags     = { 'chèque', 'banque' },
    usable   = false,
  },
}

-- ============================================================
--  CONFIG.WEAPONATTACHMENTS
--  Mapping arme (weaponHash) -> slot d'accessoire -> item compatible + componentHash GTA natif.
--  Chaque slot n'accueille qu'un seul accessoire. 'label' = libellé du slot dans l'UI.
--  Les items (token 'item') sont réutilisés entre armes d'une même catégorie : c'est le
--  componentHash, propre à chaque arme/slot, qui détermine le composant réellement appliqué.
--  Tous les items référencés ici sont générés automatiquement plus bas (icône unknown.png).
-- ============================================================
local function _barrel(item, hash)     return { label = 'Canon',    item = item, componentHash = hash } end
local function _scope(item, hash)      return { label = 'Viseur',   item = item, componentHash = hash } end
local function _flashlight(item, hash) return { label = 'Lampe',    item = item, componentHash = hash } end
local function _grip(item, hash)       return { label = 'Poignée',  item = item, componentHash = hash } end
local function _magazine(item, hash)   return { label = 'Chargeur étendu', item = item, componentHash = hash } end

Config.WeaponAttachments = {
  -- ===== PISTOLETS =====
  WEAPON_PISTOL = {
    barrel     = _barrel('suppressor_pistol', 'COMPONENT_AT_PI_SUPP_02'),
    flashlight = _flashlight('flashlight_pistol', 'COMPONENT_AT_PI_FLSH'),
    magazine   = _magazine('ext_clip_pistol', 'COMPONENT_PISTOL_CLIP_02'),
  },
  WEAPON_REVOLVER = {
    magazine   = _magazine('chargeur_pistol', 0),
  },
  WEAPON_COMBATPISTOL = {
    barrel     = _barrel('suppressor_pistol', 'COMPONENT_AT_PI_SUPP'),
    flashlight = _flashlight('flashlight_pistol', 'COMPONENT_AT_PI_FLSH'),
    magazine   = _magazine('ext_clip_pistol', 'COMPONENT_COMBATPISTOL_CLIP_02'),
  },
  WEAPON_APPISTOL = {
    barrel     = _barrel('suppressor_pistol', 'COMPONENT_AT_PI_SUPP'),
    flashlight = _flashlight('flashlight_pistol', 'COMPONENT_AT_PI_FLSH'),
    magazine   = _magazine('ext_clip_pistol', 'COMPONENT_APPISTOL_CLIP_02'),
  },
  WEAPON_PISTOL50 = {
    barrel     = _barrel('suppressor_pistol', 'COMPONENT_AT_AR_SUPP_02'),
    flashlight = _flashlight('flashlight_pistol', 'COMPONENT_AT_PI_FLSH'),
    magazine   = _magazine('ext_clip_pistol', 'COMPONENT_PISTOL50_CLIP_02'),
  },
  WEAPON_SNSPISTOL = {
    barrel     = _barrel('suppressor_pistol', 'COMPONENT_AT_PI_SUPP'),
    flashlight = _flashlight('flashlight_pistol', 'COMPONENT_AT_PI_FLSH'),
    magazine   = _magazine('ext_clip_pistol', 'COMPONENT_SNSPISTOL_CLIP_02'),
  },
  WEAPON_HEAVYPISTOL = {
    barrel     = _barrel('suppressor_pistol', 'COMPONENT_AT_PI_SUPP'),
    flashlight = _flashlight('flashlight_pistol', 'COMPONENT_AT_PI_FLSH'),
    magazine   = _magazine('ext_clip_pistol', 'COMPONENT_HEAVYPISTOL_CLIP_02'),
  },
  WEAPON_VINTAGEPISTOL = {
    barrel     = _barrel('suppressor_pistol', 'COMPONENT_AT_PI_SUPP'),
    flashlight = _flashlight('flashlight_pistol', 'COMPONENT_AT_PI_FLSH'),
    magazine   = _magazine('ext_clip_pistol', 'COMPONENT_VINTAGEPISTOL_CLIP_02'),
  },

  -- ===== PISTOLETS-MITRAILLEURS (SMG) =====
  WEAPON_MICROSMG = {
    barrel     = _barrel('suppressor_smg', 'COMPONENT_AT_AR_SUPP_02'),
    scope      = _scope('scope_smg', 'COMPONENT_AT_SCOPE_MACRO'),
    flashlight = _flashlight('flashlight_pistol', 'COMPONENT_AT_PI_FLSH'),
    magazine   = _magazine('ext_clip_smg', 'COMPONENT_MICROSMG_CLIP_02'),
  },
  WEAPON_SMG = {
    barrel     = _barrel('suppressor_smg', 'COMPONENT_AT_AR_SUPP_02'),
    scope      = _scope('scope_smg', 'COMPONENT_AT_SCOPE_MACRO_02'),
    flashlight = _flashlight('flashlight_rifle', 'COMPONENT_AT_AR_FLSH'),
    magazine   = _magazine('ext_clip_smg', 'COMPONENT_SMG_CLIP_02'),
  },
  WEAPON_ASSAULTSMG = {
    barrel     = _barrel('suppressor_smg', 'COMPONENT_AT_AR_SUPP_02'),
    scope      = _scope('scope_smg', 'COMPONENT_AT_SCOPE_MACRO'),
    flashlight = _flashlight('flashlight_rifle', 'COMPONENT_AT_AR_FLSH'),
    magazine   = _magazine('ext_clip_smg', 'COMPONENT_ASSAULTSMG_CLIP_02'),
  },
  WEAPON_COMBATPDW = {
    scope      = _scope('scope_smg', 'COMPONENT_AT_SCOPE_SMALL'),
    grip       = _grip('grip_rifle', 'COMPONENT_AT_AR_AFGRIP'),
    flashlight = _flashlight('flashlight_rifle', 'COMPONENT_AT_AR_FLSH'),
    magazine   = _magazine('ext_clip_smg', 'COMPONENT_COMBATPDW_CLIP_02'),
  },
  WEAPON_MACHINEPISTOL = {
    barrel     = _barrel('suppressor_pistol', 'COMPONENT_AT_PI_SUPP'),
    flashlight = _flashlight('flashlight_pistol', 'COMPONENT_AT_PI_FLSH'),
    magazine   = _magazine('ext_clip_smg', 'COMPONENT_MACHINEPISTOL_CLIP_02'),
  },
  WEAPON_MINISMG = {
    magazine   = _magazine('ext_clip_smg', 'COMPONENT_MINISMG_CLIP_02'),
  },

  -- ===== FUSILS D'ASSAUT =====
  WEAPON_ASSAULTRIFLE = {
    barrel     = _barrel('suppressor_rifle', 'COMPONENT_AT_AR_SUPP_02'),
    scope      = _scope('scope_rifle', 'COMPONENT_AT_SCOPE_MACRO'),
    flashlight = _flashlight('flashlight_rifle', 'COMPONENT_AT_AR_FLSH'),
    grip       = _grip('grip_rifle', 'COMPONENT_AT_AR_AFGRIP'),
    magazine   = _magazine('ext_clip_rifle', 'COMPONENT_ASSAULTRIFLE_CLIP_02'),
  },
  WEAPON_CARBINERIFLE = {
    barrel     = _barrel('suppressor_rifle', 'COMPONENT_AT_AR_SUPP'),
    scope      = _scope('scope_rifle', 'COMPONENT_AT_SCOPE_MEDIUM'),
    flashlight = _flashlight('flashlight_rifle', 'COMPONENT_AT_AR_FLSH'),
    grip       = _grip('grip_rifle', 'COMPONENT_AT_AR_AFGRIP'),
    magazine   = _magazine('ext_clip_rifle', 'COMPONENT_CARBINERIFLE_CLIP_02'),
  },
  WEAPON_ADVANCEDRIFLE = {
    barrel     = _barrel('suppressor_rifle', 'COMPONENT_AT_AR_SUPP'),
    scope      = _scope('scope_rifle', 'COMPONENT_AT_SCOPE_SMALL'),
    flashlight = _flashlight('flashlight_rifle', 'COMPONENT_AT_AR_FLSH'),
    magazine   = _magazine('ext_clip_rifle', 'COMPONENT_ADVANCEDRIFLE_CLIP_02'),
  },
  WEAPON_SPECIALCARBINE = {
    barrel     = _barrel('suppressor_rifle', 'COMPONENT_AT_AR_SUPP_02'),
    scope      = _scope('scope_rifle', 'COMPONENT_AT_SCOPE_MEDIUM'),
    flashlight = _flashlight('flashlight_rifle', 'COMPONENT_AT_AR_FLSH'),
    grip       = _grip('grip_rifle', 'COMPONENT_AT_AR_AFGRIP'),
    magazine   = _magazine('ext_clip_rifle', 'COMPONENT_SPECIALCARBINE_CLIP_02'),
  },
  WEAPON_BULLPUPRIFLE = {
    barrel     = _barrel('suppressor_rifle', 'COMPONENT_AT_AR_SUPP'),
    scope      = _scope('scope_rifle', 'COMPONENT_AT_SCOPE_SMALL'),
    flashlight = _flashlight('flashlight_rifle', 'COMPONENT_AT_AR_FLSH'),
    grip       = _grip('grip_rifle', 'COMPONENT_AT_AR_AFGRIP'),
    magazine   = _magazine('ext_clip_rifle', 'COMPONENT_BULLPUPRIFLE_CLIP_02'),
  },
  WEAPON_COMPACTRIFLE = {
    magazine   = _magazine('ext_clip_rifle', 'COMPONENT_COMPACTRIFLE_CLIP_02'),
  },

  -- ===== MITRAILLEUSES (LMG) =====
  WEAPON_MG = {
    scope    = _scope('scope_mg', 'COMPONENT_AT_SCOPE_SMALL_02'),
    magazine = _magazine('ext_clip_mg', 'COMPONENT_MG_CLIP_02'),
  },
  WEAPON_COMBATMG = {
    scope    = _scope('scope_mg', 'COMPONENT_AT_SCOPE_MEDIUM'),
    grip     = _grip('grip_rifle', 'COMPONENT_AT_AR_AFGRIP'),
    magazine = _magazine('ext_clip_mg', 'COMPONENT_COMBATMG_CLIP_02'),
  },

  -- ===== FUSILS À POMPE =====
  WEAPON_PUMPSHOTGUN = {
    barrel     = _barrel('suppressor_shotgun', 'COMPONENT_AT_SR_SUPP'),
    flashlight = _flashlight('flashlight_rifle', 'COMPONENT_AT_AR_FLSH'),
  },
  WEAPON_ASSAULTSHOTGUN = {
    barrel     = _barrel('suppressor_shotgun', 'COMPONENT_AT_AR_SUPP'),
    flashlight = _flashlight('flashlight_rifle', 'COMPONENT_AT_AR_FLSH'),
    grip       = _grip('grip_rifle', 'COMPONENT_AT_AR_AFGRIP'),
    magazine   = _magazine('ext_clip_shotgun', 'COMPONENT_ASSAULTSHOTGUN_CLIP_02'),
  },
  WEAPON_BULLPUPSHOTGUN = {
    barrel     = _barrel('suppressor_shotgun', 'COMPONENT_AT_AR_SUPP'),
    flashlight = _flashlight('flashlight_rifle', 'COMPONENT_AT_AR_FLSH'),
    grip       = _grip('grip_rifle', 'COMPONENT_AT_AR_AFGRIP'),
  },
  WEAPON_HEAVYSHOTGUN = {
    flashlight = _flashlight('flashlight_rifle', 'COMPONENT_AT_AR_FLSH'),
    grip       = _grip('grip_rifle', 'COMPONENT_AT_AR_AFGRIP'),
    magazine   = _magazine('ext_clip_shotgun', 'COMPONENT_HEAVYSHOTGUN_CLIP_02'),
  },

  -- ===== SNIPERS / TIREUR D'ÉLITE =====
  WEAPON_SNIPERRIFLE = {
    barrel = _barrel('suppressor_sniper', 'COMPONENT_AT_AR_SUPP_02'),
    scope  = _scope('scope_sniper', 'COMPONENT_AT_SCOPE_LARGE'),
  },
  WEAPON_HEAVYSNIPER = {
    scope  = _scope('scope_sniper', 'COMPONENT_AT_SCOPE_LARGE'),
  },
  WEAPON_MARKSMANRIFLE = {
    barrel     = _barrel('suppressor_sniper', 'COMPONENT_AT_AR_SUPP'),
    scope      = _scope('scope_sniper', 'COMPONENT_AT_SCOPE_LARGE_FIXED_ZOOM'),
    flashlight = _flashlight('flashlight_rifle', 'COMPONENT_AT_AR_FLSH'),
    grip       = _grip('grip_rifle', 'COMPONENT_AT_AR_AFGRIP'),
    magazine   = _magazine('ext_clip_sniper', 'COMPONENT_MARKSMANRIFLE_CLIP_02'),
  },
}

-- ============================================================
--  AUTO-GÉNÉRATION DES ITEMS D'ACCESSOIRES
--  Crée dans Config.Items tout token 'item' référencé par Config.WeaponAttachments
--  qui n'existe pas déjà — tous avec l'icône unknown.png.
--  (Les items définis manuellement plus haut conservent leur style.)
-- ============================================================
local _attachmentItemDefs = {
  suppressor_pistol  = { label = 'Silencieux (Pistolet)',          weight = 0.3 },
  suppressor_smg     = { label = 'Silencieux (SMG)',               weight = 0.5 },
  suppressor_rifle   = { label = 'Silencieux (Fusil)',             weight = 0.6 },
  suppressor_shotgun = { label = 'Silencieux (Fusil à pompe)',     weight = 0.6 },
  suppressor_sniper  = { label = 'Silencieux (Sniper)',            weight = 0.7 },
  scope_smg          = { label = 'Viseur (SMG)',                   weight = 0.4 },
  scope_rifle        = { label = 'Viseur (Fusil)',                 weight = 0.5 },
  scope_sniper       = { label = 'Lunette de précision',           weight = 0.6 },
  scope_mg           = { label = 'Viseur (Mitrailleuse)',          weight = 0.5 },
  flashlight_pistol  = { label = 'Lampe (Pistolet)',               weight = 0.2 },
  flashlight_rifle   = { label = 'Lampe (Arme longue)',            weight = 0.3 },
  grip_rifle         = { label = 'Poignée',                        weight = 0.2 },
  ext_clip_pistol    = { label = 'Chargeur Étendu (Pistolet)',     weight = 0.4 },
  ext_clip_smg       = { label = 'Chargeur Étendu (SMG)',          weight = 0.5 },
  ext_clip_rifle     = { label = 'Chargeur Étendu (Fusil)',        weight = 0.7 },
  ext_clip_shotgun   = { label = 'Chargeur Étendu (Fusil à pompe)', weight = 0.8 },
  ext_clip_sniper    = { label = 'Chargeur Étendu (Sniper)',       weight = 0.7 },
  ext_clip_mg        = { label = 'Boîte de Munitions',             weight = 1.0 },
}

for _, slots in pairs(Config.WeaponAttachments) do
  for slotName, slotDef in pairs(slots) do
    local id = slotDef.item
    if id and not Config.Items[id] then
      local meta = _attachmentItemDefs[id] or { label = id, weight = 0.4 }
      local tags = { 'weapon_attachment' }
      if slotName == 'magazine' then tags[#tags + 1] = 'magazine' end
      Config.Items[id] = {
        label = meta.label,
        weight = meta.weight or 0.4,
        maxStack = 10,
        icon = 'img/unknown.png',
        tags = tags,
        gradientColor = 'rgba(120, 120, 120, 0.40)',
      }
    end
  end
end

-- Tout chargeur (slot 'magazine' / préfixe ext_clip_) est marqué du tag 'magazine'
-- afin qu'il puisse être attaché dans l'emplacement chargeur de n'importe quelle arme
-- disposant d'un slot magazine. (cf. sv_actions.lua : weapon_attach)
local function _hasTag(def, tag)
  for _, t in ipairs(def.tags or {}) do if t == tag then return true end end
  return false
end
for defId, def in pairs(Config.Items) do
  if type(defId) == 'string' and defId:sub(1, 9) == 'ext_clip_' and not _hasTag(def, 'magazine') then
    def.tags = def.tags or {}
    def.tags[#def.tags + 1] = 'magazine'
  end
end

Config.Animations = {
  cardboard_box = { anim = 'carry_box', dict = 'anim@heists@box_carry@' },
  safe = { anim = 'carry_box', dict = 'anim@heists@box_carry@' },
}

Config.ContainerRestrictions = {
  backpack = {
    denyItems = {
      'policevest',
      'kevlar',
    }
  }
}

Config.Nude = {
  male = {
    components = {
      [1] = { drawable = 0, texture = 0, palette = 0 }, -- mask
      [3] = { drawable = 15, texture = 0, palette = 0 }, -- arms
      [4] = { drawable = 61, texture = 0, palette = 0 }, -- pants
      [5] = { drawable = 0, texture = 0, palette = 0 }, -- bags
      [6] = { drawable = 34, texture = 0, palette = 0 }, -- shoes
      [7] = { drawable = 0, texture = 0, palette = 0 }, -- chain/tie
      [8] = { drawable = 15, texture = 0, palette = 0 }, -- undershirt
      [9] = { drawable = 0, texture = 0, palette = 0 }, -- bproof
      [10] = { drawable = 0, texture = 0, palette = 0 }, -- decals
      [11] = { drawable = 15, texture = 0, palette = 0 }, -- torso
    },
    props = {
      [0] = { drawable = -1, texture = 0 },
      [1] = { drawable = -1, texture = 0 },
      [2] = { drawable = -1, texture = 0 },
    },
  },
  female = {
    components = {
      [1] = { drawable = 0, texture = 0, palette = 0 }, -- mask
      [3] = { drawable = 15, texture = 0, palette = 0 },
      [4] = { drawable = 17, texture = 0, palette = 0 },
      [5] = { drawable = 0, texture = 0, palette = 0 }, -- bags
      [6] = { drawable = 35, texture = 0, palette = 0 },
      [7] = { drawable = 0, texture = 0, palette = 0 }, -- chain/tie
      [8] = { drawable = 2, texture = 0, palette = 0 },
      [9] = { drawable = 0, texture = 0, palette = 0 }, -- bproof
      [10] = { drawable = 0, texture = 0, palette = 0 }, -- decals
      [11] = { drawable = 15, texture = 0, palette = 0 },
    },
    props = {
      [0] = { drawable = -1, texture = 0 },
      [1] = { drawable = -1, texture = 0 },
      [2] = { drawable = -1, texture = 0 },
    },
  },
}

Config.Clothing = {
  panta = {
    male = { components = { [4] = { drawable = 173, texture = 0, palette = 0 } } },
    female = { components = { [4] = { drawable = 0, texture = 0, palette = 0 } } },
  },
  hoddie = {
    male = { components = { [11] = { drawable = 524, texture = 6, palette = 0 } } },
    female = { components = { [11] = { drawable = 0, texture = 0, palette = 0 } } },
  },
  -- T-shirt simple : haut (11) + sous-haut vide (8) + bras assortis (3).
  -- Avant : composant 38 inexistant (homme) et haut 15 = torse nu (femme).
  tshirt = {
    male = { components = { [11] = { drawable = 0, texture = 0, palette = 0 }, [8] = { drawable = 15, texture = 0, palette = 0 }, [3] = { drawable = 0, texture = 0, palette = 0 } } },
    female = { components = { [11] = { drawable = 0, texture = 0, palette = 0 }, [8] = { drawable = 14, texture = 0, palette = 0 }, [3] = { drawable = 0, texture = 0, palette = 0 } } },
  },
  shoes = {
    male = { components = { [6] = { drawable = 1, texture = 0, palette = 0 } } },
    female = { components = { [6] = { drawable = 1, texture = 0, palette = 0 } } },
  },
  hat = {
    male = { props = { [0] = { drawable = 0, texture = 0 } } },
    female = { props = { [0] = { drawable = 0, texture = 0 } } },
  },
  glasses = {
    male = { props = { [1] = { drawable = 0, texture = 0 } } },
    female = { props = { [1] = { drawable = 0, texture = 0 } } },
  },
  mask = {
    male = { components = { [1] = { drawable = 0, texture = 0, palette = 0 } } },
    female = { components = { [1] = { drawable = 0, texture = 0, palette = 0 } } },
  },
  tie = {
    male = { components = { [7] = { drawable = 0, texture = 0, palette = 0 } } },
    female = { components = { [7] = { drawable = 0, texture = 0, palette = 0 } } },
  },
  cardboard_box = {
    male = { props = { [5] = { drawable = 0, texture = 0 } } },
    female = { props = { [5] = { drawable = 0, texture = 0 } } },
  },
  safe = {
    male = { props = { [5] = { drawable = 0, texture = 0 } } },
    female = { props = { [5] = { drawable = 0, texture = 0 } } },
  },
}

Config.Framework = 'esx' -- 'esx', 'qbcore' or 'none'

Config.UI = {
  -- Choisissez le système d'aide (help notification) : 'pop_v3dui', 'esx', 'qbcore' ou 'pop_inventory'
  HelpNotificationType = 'pop_v3dui', -- 'pop_v3dui' = exports.pop_v3dui, 'esx' = ESX.ShowHelpNotification, 'qbcore' = QBCore.Functions.DrawText, 'pop_inventory' = notification basique
}

Config.Notifications = {
  -- Choisissez le système de notification : 'notification', 'esx', 'qbcore' ou 'pop_inventory'
  Type = 'notification', -- 'notification' = script perso "notification", 'esx' = ESX.ShowNotification, 'qbcore' = QBCore.Functions.Notify, 'pop_inventory' = notification basique
}

Config.Debug = {
  PrintActions = false,
  Commands = false,
}

Config.Shops = {
  ["LTD"] = {
    { id = "bouteille", price = 40, label = "Bouteille d'eau", icon = "img/bouteille.png" },
    { id = "hotdog", price = 50, label = "Hotdog", icon = "img/hotdog.png" },
    { id = "jerry", price = 40, label = "Bidon d'essence", icon = "img/jerry.png" },
    { id = "briefcase", price = 40, label = "Malette", icon = "img/briefcase.png" },
    { id = "wallet", price = 40, label = "Portefeuille", icon = "img/wallet.png" },
    { id = "pochon", price = 40, label = "Pochon", icon = "img/pochon.png" },
    { id = "phone", price = 800, label = "Téléphone", icon = "img/phone.png" },
    { id = "file", price = 800, label = "Dossier", icon = "img/file.png" },
    { id = "notepad", price = 40, label = "Carnet", icon = "img/notepad.png" },
  },
  ["24/7"] = {
    { id = "bouteille", price = 40, label = "Bouteille d'eau", icon = "img/bouteille.png" },
    { id = "hotdog", price = 50, label = "Hotdog", icon = "img/hotdog.png" },
    { id = "jerry", price = 40, label = "Bidon d'essence", icon = "img/jerry.png" },
    { id = "briefcase", price = 40, label = "Malette", icon = "img/briefcase.png" },
    { id = "wallet", price = 40, label = "Portefeuille", icon = "img/wallet.png" },
    { id = "pochon", price = 40, label = "Pochon", icon = "img/pochon.png" },
    { id = "phone", price = 800, label = "Téléphone", icon = "img/phone.png" },
    { id = "file", price = 800, label = "Dossier", icon = "img/file.png" },
  },
  ["ifruit"] = {
     { id = "phone", price = 1200, label = "iFruit 9ix", icon = "img/phone.png" },
     { id = "sim_card", price = 150, label = "SIM iFruit Connect", icon = "img/sim_card.png" },
  },

  ["vegatech"] = {
     { id = "cassette_duz_it", price = 150, label = "Cassette - Duz It", icon = "img/unknown.png" },
     { id = "cassette_tnt", price = 150, label = "Cassette - TNT", icon = "img/unknown.png" },
     { id = "cassette_bad_boys", price = 150, label = "Cassette - Bad Boys", icon = "img/unknown.png" },
     { id = "cassette_smooth_criminal", price = 150, label = "Cassette - Smooth Criminal", icon = "img/unknown.png" },
     { id = "cassette_cant_c_me", price = 150, label = "Cassette - Cant C Me", icon = "img/unknown.png" },
     { id = "cassette_think_about_the_way", price = 150, label = "Cassette - Think About The Way", icon = "img/unknown.png" },
     { id = "cassette_get_a_way", price = 150, label = "Cassette - Get A Way", icon = "img/unknown.png" },
     { id = "walkman", price = 600, label = "Walkman", icon = "img/unknown.png" },
  },

  ["BANK"] = {
     { id = "checkbook", price = 250, label = "Chéquier", icon = "img/checkbook.png" },
  }
}


Config.ShopZones = {
    -- 24/7 Stores
    { id = 'SHOP_1', shopId = '24/7', label = '24/7', coords = vector3(372.6, 326.9, 103.5 + 1.0), radius = 3.5 },
    { id = 'SHOP_2', shopId = '24/7', label = '24/7', coords = vector3(2556.6, 380.8, 108.6 + 1.0), radius = 3.5 },
    { id = 'SHOP_3', shopId = '24/7', label = '24/7', coords = vector3(-3039.5, 584.3, 7.9 + 1.0), radius = 3.5 },
    { id = 'SHOP_4', shopId = '24/7', label = '24/7', coords = vector3(-3242.9, 1000.0, 12.8 + 1.0), radius = 3.5 },
    { id = 'SHOP_5', shopId = '24/7', label = '24/7', coords = vector3(549.1, 2670.8, 42.1 + 1.0), radius = 3.5 },
    { id = 'SHOP_6', shopId = '24/7', label = '24/7', coords = vector3(1959.8, 3740.4, 32.3 + 1.0), radius = 3.5 },
    { id = 'SHOP_7', shopId = '24/7', label = '24/7', coords = vector3(2677.4, 3279.7, 55.2 + 1.0), radius = 3.5 },
    { id = 'SHOP_8', shopId = '24/7', label = '24/7', coords = vector3(1728.0, 6415.6, 35.0 + 1.0), radius = 3.5 },
    { id = 'SHOP_9', shopId = '24/7', label = '24/7', coords = vector3(24.4, -1346.6, 29.5 + 1.0), radius = 3.5 },

    -- Robs Liquor (utilisent shopId LTD pour le moment)
    { id = 'SHOP_10', shopId = 'LTD', label = "Robs Liquor", coords = vector3(1134.2, -982.9, 46.4 + 1.0), radius = 3.5 },
    { id = 'SHOP_11', shopId = 'LTD', label = "Robs Liquor", coords = vector3(-1221.5, -908.1, 12.3 + 1.0), radius = 3.5 },
    { id = 'SHOP_12', shopId = 'LTD', label = "Robs Liquor", coords = vector3(-1486.5, -377.6, 40.1 + 1.0), radius = 3.5 },
    { id = 'SHOP_13', shopId = 'LTD', label = "Robs Liquor", coords = vector3(-2966.3, 391.4, 15.0 + 1.0), radius = 3.5 },
    { id = 'SHOP_14', shopId = 'LTD', label = "Robs Liquor", coords = vector3(1165.1, 2710.8, 38.1 + 1.0), radius = 3.5 },

    -- LTD Stores
    { id = 'SHOP_15', shopId = 'LTD', label = 'LTD', coords = vector3(-47.0, -1758.2, 29.4 + 1.0), radius = 3.5 },
    { id = 'SHOP_16', shopId = 'LTD', label = 'LTD', coords = vector3(1164.7, -322.9, 69.2 + 1.0), radius = 3.5 },
    { id = 'SHOP_17', shopId = 'LTD', label = 'LTD', coords = vector3(-706.0, -913.9, 19.2 + 1.0), radius = 3.5 },
    { id = 'SHOP_18', shopId = 'LTD', label = 'LTD', coords = vector3(-1820.0, 794.0, 138.0 + 1.0), radius = 3.5 },
    { id = 'SHOP_19', shopId = 'LTD', label = 'LTD', coords = vector3(1697.8, 4922.9, 42.0 + 1.0), radius = 3.5 },

    -- iFruit Store
    { id = 'SHOP_IFRUIT', shopId = 'ifruit', label = 'iFruit Store', coords = vector3(-1243.76, -805.85, 18.32), radius = 4.0 },

    -- Vega Tech Store
    { id = 'SHOP_VEGATECH', shopId = 'vegatech', label = 'Vega Tech Store', coords = vector3(2650.8787, 3467.1035, 55.6173), radius = 4.0 },

    -- Banques (achat de chéquier) -- USA : Fleeca Bank réelle (cf. pop_management Config.Blips)
    { id = 'SHOP_BANK_USA', shopId = 'BANK', label = 'Banque', coords = vector3(150.2, -1040.2, 29.3 + 1.0), radius = 3.5 },
    -- Mexique : emplacement provisoire (aucune banque modélisée dans la zone), à ajuster
    { id = 'SHOP_BANK_MEXICO', shopId = 'BANK', label = 'Banque', coords = vector3(2469.0, 4070.0, 38.0 + 1.0), radius = 3.5 },
}

-- Conteneurs distants configurables (inventaires partagés, sans prop physique).
-- Chaque entrée définit une zone interactive dans le monde.
-- L'inventaire est persistant et partagé entre tous les joueurs.
Config.StaticChests = {
  -- Exemple de conteneur : supprimer ou modifier selon vos besoins
  {
    id        = 'depot_central',       -- Identifiant unique (clé DB)
    label     = 'Dépôt Central',       -- Nom affiché dans l'UI
    coords    = vector3(492.4869, -992.4598, 27.6993), -- Position dans le monde
    slots     = 40,                    -- Nombre de slots
    maxWeight = 200.0,                 -- Poids max en kg
    radius    = 1.0,                   -- Rayon d'interaction (en mètres)
    marker = {
      enabled = false,
      type    = 1,                     -- Type de marqueur GTA (1 = cylindre)
      color   = { r = 50, g = 200, b = 255, a = 180 },
    },
  },

  {
    id        = 'sams',
    label     = 'le dépôt Médical',
    coords    = vector3(-820.0074, -1242.9933, 7.3374),
    slots     = 40,
    maxWeight = 200.0,
    radius    = 1.0,
    jobs      = { 'ambulance' },       -- Restreint aux ambulanciers
    marker = {
      enabled = false,
      type    = 1,
      color   = { r = 50, g = 200, b = 255, a = 180 },
    },
  },

  {
    id        = 'bennys',
    label     = 'le dépôt',
    coords    = vector3(-820.0074, -1242.9933, 7.3374),
    slots     = 40,
    maxWeight = 200.0,
    radius    = 1.0,
    jobs      = { 'mechanic' },        -- Restreint aux mécanos/bennys
    marker = {
      enabled = false,
      type    = 1,
      color   = { r = 50, g = 200, b = 255, a = 180 },
    },
  },

  {
    id        = 'cleelspd',
    label     = 'le coffret à clés',
    coords    = vector3(469.1551, -974.7968, 27.2727),
    slots     = 40,
    maxWeight = 200.0,
    radius    = 1.0,
    jobs      = { 'police' },          -- Restreint aux policiers
    marker = {
      enabled = false,
      type    = 1,
      color   = { r = 50, g = 200, b = 255, a = 180 },
    },
  },

  {
    id        = 'armurerielspd',
    label     = "l'Armurerie LSPD",
    coords    = vector3(364.6354, -1604.0372, 25.4517),
    heading   = 219.6837,
    slots     = 80,
    maxWeight = 500.0,
    radius    = 1.5,
    jobs      = { 'police', 'lspd', 'bcso', 'sasp' },
    marker = {
      enabled = false,
      type    = 1,
      color   = { r = 50, g = 200, b = 255, a = 180 },
    },
  },

  {
    id        = 'saisieslspd',
    label     = 'les Saisies LSPD',
    coords    = vector3(381.1659, -1609.1726, 30.2028),
    heading   = 228.9951,
    slots     = 100,
    maxWeight = 1000.0,
    radius    = 1.5,
    jobs      = { 'police', 'lspd', 'bcso', 'sasp' },
    marker = {
      enabled = false,
      type    = 1,
      color   = { r = 50, g = 200, b = 255, a = 180 },
    },
  },

  -- {
  --   id        = 'entrepot_sud',
  --   label     = 'Entrepôt Sud',
  --   coords    = vector3(0.0, 0.0, 0.0),
  --   slots     = 20,
  --   maxWeight = 100.0,
  --   radius    = 2.5,
  --   marker    = { enabled = true, type = 1, color = { r = 255, g = 150, b = 50, a = 180 } },
  -- },
}

-- ==========================================
-- SALLES DE CASIERS (matricule = numéro de casier)
-- ==========================================
-- Chaque salle est un conteneur distant persistant et partagé, peuplé automatiquement
-- de `count` items 'casier' (un par matricule possible). Point FIXE : l'interaction se
-- fait par prompt v3DUI + touche (pas d'ox_target), géré dans standby_client.lua. Deux
-- touches sur le même point :
--  - [E] "Mon casier" -> ouvre DIRECTEMENT le contenu de VOTRE casier (matricule = votre
--    numéro d'employé pour ce job), sans liste ni code (sous-conteneur ouvert d'office).
--  - [G] "Parcourir les casiers" -> ouvre la salle entière (grille de tous les casiers) ;
--    ouvrir un casier qui n'est pas le vôtre demande le code (géré dans pop_management,
--    fiche employé).
-- Le matricule/code de chaque employé est attribué et consultable via pop_management.
-- NB : le help-notification suit Config.UI.HelpNotificationType ('pop_v3dui' recommandé).
Config.LockerRooms = {
  {
    id        = 'lspd_lockers',
    label     = 'les Casiers du LSPD',
    coords    = vector3(452.6, -984.5, 30.69),
    job       = 'police',              -- Job requis + filtre matricule/code
    count     = 20,                    -- Nombre de casiers (matricules 1 à 20)
    slots     = 8,                     -- Slots par casier
    maxWeight = 15.0,
    radius    = 1.5,                   -- Rayon d'interaction (touche E/G)
  },
}

-- ==========================================
-- SYSTÈME DE LANGUES (LOCALES)
-- ==========================================
Config.Locale = 'fr' -- 'fr' ou 'en'

Config.Locales = {
    ['fr'] = {
        -- UI & Textes
        ['ui_inventory'] = 'Inventaire',
        ['ui_weapons'] = 'Armes',
        ['ui_clothing'] = 'Vêtements',
        ['ui_head'] = 'Tête',
        ['ui_body'] = 'Corps',
        ['ui_bottom'] = 'Bas',
        ['ui_utility'] = 'Utilitaire',
        ['ui_communication'] = 'Communication',
        ['ui_nearby'] = 'À proximité',
        ['ui_change_torso'] = 'Changer le torse',
        ['ui_torsos'] = 'Torses',
        ['ui_return'] = 'Retour',
        
        -- Notifications Serveur
        ['action_impossible'] = 'Action impossible',
        ['item_unknown'] = 'Item inconnu',
        ['equip_error'] = "Impossible d'équiper",
        ['creation_error'] = "Erreur création item",
        ['no_space'] = "Pas de place dans les containers",
        ['inventory_full'] = "Inventaire plein !",
        ['invalid_object'] = "Erreur: Objet introuvable ou invalide",
        ['item_given'] = "Objet donné",
        ['item_received'] = "Objet reçu",
        ['transfer_impossible'] = "Transfert impossible",
        ['too_far'] = "Trop loin",
        ['no_box_nearby'] = "Aucune boite à proximité"
    },
    ['en'] = {
        -- UI & Texts
        ['ui_inventory'] = 'Inventory',
        ['ui_weapons'] = 'Weapons',
        ['ui_clothing'] = 'Clothing',
        ['ui_head'] = 'Head',
        ['ui_body'] = 'Body',
        ['ui_bottom'] = 'Bottom',
        ['ui_utility'] = 'Utility',
        ['ui_communication'] = 'Communication',
        ['ui_nearby'] = 'Nearby',
        ['ui_change_torso'] = 'Change torso',
        ['ui_torsos'] = 'Torsos',
        ['ui_return'] = 'Return',

        -- Server Notifications
        ['action_impossible'] = 'Action impossible',
        ['item_unknown'] = 'Unknown item',
        ['equip_error'] = "Cannot equip",
        ['creation_error'] = "Item creation error",
        ['no_space'] = "No space in containers",
        ['inventory_full'] = "Inventory full!",
        ['invalid_object'] = "Error: Invalid object",
        ['item_given'] = "Item given",
        ['item_received'] = "Item received",
        ['transfer_impossible'] = "Transfer impossible",
        ['too_far'] = "Too far",
        ['no_box_nearby'] = "No box nearby"
    }
}

-- ===== CRAFT =====

Config.Recipes = {
    {
        id = 'pochonweed',
        output = { defId = 'pochonweed', qty = 1 },
        ingredients = {
            { defId = 'weed', qty = 1 },
            { defId = 'pochon', qty = 1 },
        },
    },
    {
        id = 'safe',
        output = { defId = 'safe', qty = 1 },
        ingredients = {
            { defId = 'hotdog', qty = 8 }, -- avant : 6 + 1 + 1 sur trois lignes, mal compté
        },
    },
    {
        id = 'pistol',
        output = { defId = 'pistol', qty = 1 },
        ingredients = {
            { defId = 'cylindre', qty = 2 },
            { defId = 'plaque', qty = 4 },
            { defId = 'ressort', qty = 1 },
        },
    },
    {
        id = 'revolver',
        output = { defId = 'revolver', qty = 1 },
        ingredients = {
            { defId = 'cylindre', qty = 4 },
            { defId = 'plaque', qty = 6 },
            { defId = 'ressort', qty = 2 },
        },
    },
    {
        id = 'carabine',
        output = { defId = 'carabine', qty = 1 },
        ingredients = {
            { defId = 'cylindre', qty = 15 },
            { defId = 'plaque', qty = 25 },
            { defId = 'ressort', qty = 12 },
        },
    },
    {
        id = 'cassette_duz_it',
        output = { defId = 'cassette_duz_it', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 1 },
            { defId = 'bande_magnetique', qty = 1 },
        },
    },
    {
        id = 'cassette_tnt',
        output = { defId = 'cassette_tnt', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 1 },
            { defId = 'bande_magnetique', qty = 1 },
        },
    },
    {
        id = 'cassette_bad_boys',
        output = { defId = 'cassette_bad_boys', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 1 },
            { defId = 'bande_magnetique', qty = 1 },
        },
    },
    {
        id = 'cassette_smooth_criminal',
        output = { defId = 'cassette_smooth_criminal', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 1 },
            { defId = 'bande_magnetique', qty = 1 },
        },
    },
    {
        id = 'cassette_cant_c_me',
        output = { defId = 'cassette_cant_c_me', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 1 },
            { defId = 'bande_magnetique', qty = 1 },
        },
    },
    {
        id = 'cassette_think_about_the_way',
        output = { defId = 'cassette_think_about_the_way', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 1 },
            { defId = 'bande_magnetique', qty = 1 },
        },
    },
    {
        id = 'cassette_get_a_way',
        output = { defId = 'cassette_get_a_way', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 1 },
            { defId = 'bande_magnetique', qty = 1 },
        },
    },
    {
        id = 'walkman',
        output = { defId = 'walkman', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 3 },
            { defId = 'kit_reparation_vegatech', qty = 1 },
        },
    },

    -- ===== Lucky Plucker =====
    {
        id = 'seau_du_coq',
        output = { defId = 'seau_du_coq', qty = 1 },
        ingredients = {
            { defId = 'raw_chicken', qty = 3 },
            { defId = 'secret_breadcrumbs', qty = 1 },
            { defId = 'cooking_oil', qty = 1 },
            { defId = 'lucky_box', qty = 1 },
        },
    },
    {
        id = 'nuggets_poulailler',
        output = { defId = 'nuggets_poulailler', qty = 1 },
        ingredients = {
            { defId = 'raw_chicken', qty = 1 },
            { defId = 'bbq_sauce', qty = 1 },
            { defId = 'paper_bag', qty = 1 },
        },
    },
    {
        id = 'limonade_fermiere',
        output = { defId = 'limonade_fermiere', qty = 1 },
        ingredients = {
            { defId = 'lemon', qty = 2 },
            { defId = 'sparkling_water', qty = 1 },
            { defId = 'sugar_syrup', qty = 1 },
            { defId = 'plastic_cup', qty = 1 },
        },
    },

    -- ===== Pearls Seafood Restaurant =====
    {
        id = 'plateau_huitres',
        output = { defId = 'plateau_huitres', qty = 1 },
        ingredients = {
            { defId = 'fresh_oysters', qty = 3 },
            { defId = 'lemon_slice', qty = 1 },
            { defId = 'crushed_ice', qty = 1 },
            { defId = 'porcelain_plate', qty = 1 },
        },
    },
    {
        id = 'sandwich_homard',
        output = { defId = 'sandwich_homard', qty = 1 },
        ingredients = {
            { defId = 'fresh_lobster', qty = 1 },
            { defId = 'brioche_bun', qty = 1 },
            { defId = 'lemon_butter', qty = 1 },
            { defId = 'pearls_wrapper', qty = 1 },
        },
    },
    {
        id = 'mocktail_lagon_bleu',
        output = { defId = 'mocktail_lagon_bleu', qty = 1 },
        ingredients = {
            { defId = 'blue_curacao_syrup', qty = 1 },
            { defId = 'pineapple_juice', qty = 1 },
            { defId = 'tonic_water', qty = 1 },
            { defId = 'cocktail_glass', qty = 1 },
        },
    },

    -- ===== Drogues =====
    {
        id = 'meth_pure',
        output = { defId = 'meth_pure', qty = 1 },
        ingredients = {
            { defId = 'chemical_substance', qty = 1 },
            { defId = 'battery_acid', qty = 1 },
            { defId = 'empty_baggy', qty = 1 },
        },
    },
    {
        id = 'crack_rock',
        output = { defId = 'crack_rock', qty = 1 },
        ingredients = {
            { defId = 'cocaine_powder', qty = 1 },
            { defId = 'baking_soda', qty = 1 },
            { defId = 'empty_baggy', qty = 1 },
        },
    },
}

Config.CraftZones = {
    {
        coords = vector3(953.9382, -1254.5359, 27.0907), -- TODO: remplacer par les vraies coordonnées de l'établi
        radius = 2.0,
        label = 'Établi',
        recipes = { 'pochonweed', 'safe' },
    },

        {
        coords = vector3(753.0419, -1287.5027, 27.4669), -- TODO: remplacer par les vraies coordonnées de l'établi
        radius = 2.0,
        label = 'Établi',
        recipes = { 'pochonweed', 'safe' },
    },
    {
        coords = vector3(853.0880, -2381.1292, 31.5236),
        radius = 2.0,
        label = 'Établi du Warehouse',
        recipes = { 'pistol', 'revolver', 'carabine' },
    },
    {
        coords = vector3(2650.8787, 3467.1035, 55.6173),
        radius = 3.0,
        label = 'Établi Vega Tech',
        recipes = {
            'cassette_duz_it',
            'cassette_tnt',
            'cassette_bad_boys',
            'cassette_smooth_criminal',
            'cassette_cant_c_me',
            'cassette_think_about_the_way',
            'cassette_get_a_way',
            'walkman',
        },
    },
    {
        coords = vector3(0.0, 0.0, 0.0), -- TODO: coordonnées de la cuisine Lucky Plucker
        radius = 2.5,
        label = 'Cuisine Lucky Plucker',
        recipes = {
            'seau_du_coq',
            'nuggets_poulailler',
            'limonade_fermiere',
        },
    },
    {
        coords = vector3(0.0, 0.0, 0.0), -- TODO: coordonnées de la cuisine Pearls Seafood
        radius = 2.5,
        label = 'Cuisine Pearls Seafood',
        recipes = {
            'plateau_huitres',
            'sandwich_homard',
            'mocktail_lagon_bleu',
        },
    },
    {
        coords = vector3(0.0, 0.0, 0.0), -- TODO: coordonnées du laboratoire de drogue
        radius = 2.5,
        label = 'Laboratoire',
        recipes = {
            'meth_pure',
            'crack_rock',
        },
    },
}

-- Fonction Helper
function _U(str)
    if Config.Locales[Config.Locale] and Config.Locales[Config.Locale][str] then
        return Config.Locales[Config.Locale][str]
    end
    return str
end
