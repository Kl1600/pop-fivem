-- =====================================================
--  Module CLÉS DE VÉHICULE (ex vehicle_keys) — config dédiée.
--  Table séparée (VehicleKeysConfig) pour ne PAS écraser le Config de pop_inventory.
-- =====================================================
VehicleKeysConfig = {}

VehicleKeysConfig.Debug = false
VehicleKeysConfig.KeyItemName = 'carkeys' -- doit correspondre à l'item dans config.lua
VehicleKeysConfig.InteractionDistance = 2.5

VehicleKeysConfig.Animations = {
    lock = {
        dict = 'anim@mp_player_intmenu@key_fob@',
        anim = 'fob_click',
        duration = 1000
    }
}
