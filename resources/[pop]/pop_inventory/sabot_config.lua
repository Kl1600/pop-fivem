-- =====================================================
--  Module SABOT DE ROUE (ex tab_sabot) — config dédiée.
--  Table séparée (SabotConfig) pour ne PAS écraser le Config de pop_inventory.
-- =====================================================
SabotConfig = {}

-- Prop streamé depuis stream/. Ne pas changer sauf si tu remplaces le modèle.
SabotConfig.PropModel    = 'prop_clamp'

-- Roue sur laquelle se pose le sabot.
-- Bones possibles : wheel_lf (avant gauche), wheel_rf, wheel_lr, wheel_rr
SabotConfig.WheelBone    = 'wheel_lf'

-- Placement du prop (offsets d'origine extraits du smartclamp C#).
SabotConfig.PropOffset   = vector3(-0.1, 0.15, -0.3)
SabotConfig.PropRotation = vector3(180.0, 200.0, 90.0)

-- Items utilisés (doivent exister dans config.lua)
SabotConfig.SabotItem    = 'sabot'      -- item pour POSER le sabot
SabotConfig.KeyItem      = 'cle_sabot'  -- item (clé) pour RETIRER le sabot

-- Durées des barres de progression (ms)
SabotConfig.PlaceDuration  = 4000
SabotConfig.RemoveDuration = 4000

-- Portée de détection du véhicule quand on utilise l'item depuis l'inventaire
SabotConfig.Distance = 4.0

-- Restriction d'accès
SabotConfig.PoliceOnly = false   -- true = seule la police peut poser/retirer le sabot
SabotConfig.PoliceJob  = 'police'
