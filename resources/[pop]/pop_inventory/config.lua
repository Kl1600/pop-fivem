Config = {}

------------------------------------------------------------------------
-- Réglages communs POP (ne pas supprimer)
------------------------------------------------------------------------
Config.Locale = 'fr'
Config.Debug = false
Config.Framework = 'esx'  -- pop_inventory : code ESX (multi-framework plus tard)
Config.Inventory = 'pop_inventory' -- pop_inventory est l'inventaire (fonctions internes pour objets et argent)
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
-- pop_inventory
-- Suite de la configuration dans config/ (objets, vêtements, boutiques, coffres, recettes, modules).
------------------------------------------------------------------------

-- Options de debug détaillées (Config.Debug = true pour les logs généraux).
Config.DebugOptions = {
  PrintActions = false,
  Commands = false,
}

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

Config.InventorySettings = {
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


Config.UI = {
  -- Choisissez le système d'aide (help notification) : 'pop_v3dui', 'esx', 'qbcore' ou 'pop_inventory'
  HelpNotificationType = 'pop_v3dui', -- 'pop_v3dui' = exports.pop_v3dui, 'esx' = ESX.ShowHelpNotification, 'qbcore' = QBCore.Functions.DrawText, 'pop_inventory' = notification basique
}
