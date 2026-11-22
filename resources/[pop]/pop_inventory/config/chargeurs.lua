-- =====================================================
--  Module CHARGEURS (ex tab_chargeurs) — config dédiée.
--  Table séparée (ChargeursConfig) pour ne PAS écraser le Config de pop_inventory.
-- =====================================================
ChargeursConfig = {}

ChargeursConfig.CategoryLabels = {
    pistol = 'Pistolet',
    smg    = 'SMG',
    rifle  = 'Fusil',
}

ChargeursConfig.Weapons = {
    pistol   = { weaponHash = 'WEAPON_PISTOL',       category = 'pistol', magItem = 'chargeur_pistol', capacity = 12 },
    revolver = { weaponHash = 'WEAPON_REVOLVER',     category = 'pistol', magItem = 'chargeur_pistol', capacity = 6 },
    smg      = { weaponHash = 'WEAPON_SMG',          category = 'smg',    magItem = 'chargeur_smg',    capacity = 30 },
    carabine = { weaponHash = 'WEAPON_CARBINERIFLE', category = 'rifle',  magItem = 'chargeur_fusil',  capacity = 30 },
}

ChargeursConfig.AmmoBoxes = {
    munitions_pistolet = 'pistol',
    munitions_smg      = 'smg',
    munitions_fusil    = 'rifle',
}

ChargeursConfig.SyncCooldown      = 400
ChargeursConfig.EmptyHintCooldown = 4000
ChargeursConfig.MaxConsumePerTick = 100
