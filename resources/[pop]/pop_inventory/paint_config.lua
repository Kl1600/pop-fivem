-- =====================================================================
--  PISTOLET A PEINTURE  -  Configuration partagee (client + serveur)
-- =====================================================================
PaintGun = {}

-- Item (inventaire pop_inventory) qui represente le pistolet.
PaintGun.GunItem = 'pistolet_peinture'

-- Hash de l'arme utilisee pour le modele 3D (streamee par pressurewashermodels).
PaintGun.WeaponHash = 'WEAPON_PRESSURE1'

-- ---------------------------------------------------------------------
--  POTS DE COULEUR PRIMAIRE
--  On reutilise les items deja presents dans pop_inventory/config.lua.
--  Le cout de chaque pot est calcule a partir du RGB de la peinture
--  choisie (cf. PaintGun.GetPotCost plus bas).
-- ---------------------------------------------------------------------
PaintGun.Pots = {
  rouge = 'peinture_rouge',
  jaune = 'peinture_jaune',
  bleu  = 'peinture_bleue',
}

-- Quantite de pigment (par pot) necessaire pour une couleur a 100% sur
-- un canal. Ex : un blanc pur (255,255,255) coute UnitsPerCar de chaque
-- pot ; un rouge pur (255,0,0) coute seulement UnitsPerCar de rouge.
PaintGun.UnitsPerCar = 30

-- Capacite du reservoir = peinture pour UNE voiture entiere (100%).
PaintGun.ReservoirMax = 100.0

-- Vitesse de remplissage de la peinture sur la carrosserie (points de %
--  ajoutes par seconde de spray continu). Plus c'est bas, plus la
--  couleur apparait "petit a petit".
PaintGun.PaintRatePerSec = 22.0

-- Portee maximale du jet (metres).
PaintGun.SprayRange = 6.0

-- Particule du jet : effet "bombe de peinture" de GTA (vrai spray paint),
-- recolore a la couleur choisie. Le dict n'est pas "core" -> il est charge
-- a la demande par loadParticleAsset (cf. paint_client.lua).
PaintGun.ParticleDict = 'scr_recartheft'
PaintGun.ParticleName = 'scr_carsteal4_spraycan'
PaintGun.ParticleScale = 1.0

-- ---------------------------------------------------------------------
--  Cout en pigment d'une couleur (r,g,b -> {rouge, jaune, bleu})
--  Mapping simple et previsible :
--   - le canal Rouge consomme le pot Rouge
--   - le canal Vert  consomme le pot Jaune
--   - le canal Bleu  consomme le pot Bleu
-- ---------------------------------------------------------------------
function PaintGun.GetPotCost(r, g, b)
  local u = PaintGun.UnitsPerCar
  return {
    rouge = math.ceil((r / 255.0) * u),
    jaune = math.ceil((g / 255.0) * u),
    bleu  = math.ceil((b / 255.0) * u),
  }
end

-- ---------------------------------------------------------------------
--  LISTE COMPLETE DES PEINTURES GTA V
--  index = id couleur natif GTA (SetVehicleColours), name, r, g, b
-- ---------------------------------------------------------------------
PaintGun.Colors = {
  -- ===== Metallic =====
  { index = 0,   name = 'Noir Metal',            r = 10,  g = 10,  b = 10  },
  { index = 1,   name = 'Graphite',              r = 28,  g = 29,  b = 33  },
  { index = 2,   name = 'Noir Acier',            r = 50,  g = 56,  b = 61  },
  { index = 3,   name = 'Argent Sombre',         r = 69,  g = 76,  b = 79  },
  { index = 4,   name = 'Argent',                r = 153, g = 157, b = 160 },
  { index = 5,   name = 'Argent Bleute',         r = 194, g = 196, b = 198 },
  { index = 6,   name = 'Gris Acier',            r = 151, g = 154, b = 151 },
  { index = 7,   name = 'Gris Cuivre',           r = 135, g = 139, b = 146 },
  { index = 8,   name = 'Anthracite',            r = 111, g = 114, b = 117 },
  { index = 9,   name = 'Gris Mat',              r = 115, g = 123, b = 126 },
  { index = 10,  name = 'Gris Fer',              r = 122, g = 127, b = 127 },
  { index = 11,  name = 'Gris Cuivre Fonce',     r = 96,  g = 100, b = 97  },
  { index = 12,  name = 'Noir Cuivre',           r = 71,  g = 75,  b = 78  },
  { index = 13,  name = 'Gris Aluminium',        r = 60,  g = 63,  b = 71  },
  { index = 14,  name = 'Argent Pur',            r = 217, g = 217, b = 216 },
  -- ===== Rouge =====
  { index = 27,  name = 'Rouge',                 r = 192, g = 22,  b = 24  },
  { index = 28,  name = 'Rouge Torino',          r = 140, g = 27,  b = 29  },
  { index = 29,  name = 'Rouge Formule',         r = 111, g = 24,  b = 24  },
  { index = 30,  name = 'Rouge Feu',             r = 132, g = 27,  b = 27  },
  { index = 31,  name = 'Rouge Graphite',        r = 122, g = 29,  b = 33  },
  { index = 32,  name = 'Rouge Vif',             r = 213, g = 33,  b = 47  },
  { index = 33,  name = 'Rouge Cabernet',        r = 108, g = 28,  b = 40  },
  { index = 34,  name = 'Rouge Candy',           r = 138, g = 14,  b = 23  },
  { index = 35,  name = 'Rouge Sunrise',         r = 153, g = 84,  b = 88  },
  { index = 36,  name = 'Or Rouge',              r = 151, g = 84,  b = 41  },
  { index = 37,  name = 'Rouge Orange',          r = 226, g = 90,  b = 41  },
  { index = 38,  name = 'Orange',                r = 246, g = 144, b = 26  },
  -- ===== Jaune / Vert =====
  { index = 88,  name = 'Jaune',                 r = 255, g = 196, b = 0   },
  { index = 89,  name = 'Jaune Course',          r = 252, g = 234, b = 95  },
  { index = 39,  name = 'Beige',                 r = 119, g = 118, b = 110 },
  { index = 40,  name = 'Brun Fonce',            r = 99,  g = 86,  b = 73  },
  { index = 41,  name = 'Brun Clair',            r = 186, g = 142, b = 99  },
  { index = 42,  name = 'Brun Sapin',            r = 76,  g = 60,  b = 49  },
  { index = 43,  name = 'Brun Choco',            r = 64,  g = 46,  b = 30  },
  { index = 44,  name = 'Brun Doux',             r = 152, g = 108, b = 84  },
  { index = 45,  name = 'Brun Moka',             r = 88,  g = 70,  b = 53  },
  { index = 46,  name = 'Brun Bronze',           r = 117, g = 84,  b = 51  },
  { index = 47,  name = 'Brun Cuir',             r = 153, g = 122, b = 83  },
  { index = 48,  name = 'Brun Umber',            r = 84,  g = 56,  b = 31  },
  { index = 49,  name = 'Beige Os',              r = 191, g = 173, b = 143 },
  { index = 50,  name = 'Kaki',                  r = 161, g = 144, b = 113 },
  { index = 51,  name = 'Vert Bouteille',        r = 38,  g = 51,  b = 38  },
  { index = 52,  name = 'Vert Foret',            r = 37,  g = 41,  b = 32  },
  { index = 53,  name = 'Vert Olive',            r = 119, g = 124, b = 76  },
  { index = 54,  name = 'Vert Course',           r = 47,  g = 89,  b = 42  },
  { index = 55,  name = 'Vert Sea',              r = 51,  g = 79,  b = 75  },
  { index = 56,  name = 'Vert Olive Clair',      r = 98,  g = 145, b = 99  },
  { index = 57,  name = 'Vert Emeraude',         r = 0,   g = 95,  b = 45  },
  { index = 58,  name = 'Vert Gazon',            r = 22,  g = 86,  b = 51  },
  { index = 59,  name = 'Vert Citron',           r = 102, g = 184, b = 60  },
  -- ===== Bleu =====
  { index = 61,  name = 'Bleu Galaxie',          r = 71,  g = 88,  b = 122 },
  { index = 62,  name = 'Bleu Diamant',          r = 71,  g = 91,  b = 116 },
  { index = 63,  name = 'Bleu Surf',             r = 101, g = 132, b = 154 },
  { index = 64,  name = 'Bleu Nautique',         r = 89,  g = 102, b = 124 },
  { index = 65,  name = 'Bleu Racing',           r = 0,   g = 50,  b = 122 },
  { index = 66,  name = 'Bleu Ulysse',           r = 66,  g = 78,  b = 96  },
  { index = 67,  name = 'Bleu Schafter',         r = 30,  g = 41,  b = 56  },
  { index = 68,  name = 'Bleu Marine',           r = 71,  g = 89,  b = 116 },
  { index = 70,  name = 'Bleu Bavarois',         r = 53,  g = 94,  b = 156 },
  { index = 71,  name = 'Bleu Electrique',       r = 78,  g = 109, b = 201 },
  { index = 72,  name = 'Bleu Hot Pink',         r = 0,   g = 50,  b = 110 },
  { index = 73,  name = 'Bleu Spinnaker',        r = 35,  g = 49,  b = 85  },
  { index = 74,  name = 'Bleu Ciel',             r = 110, g = 169, b = 196 },
  { index = 75,  name = 'Bleu Mariner',          r = 53,  g = 80,  b = 122 },
  { index = 76,  name = 'Bleu Harbor',           r = 41,  g = 58,  b = 78  },
  { index = 77,  name = 'Bleu Diamant Clair',    r = 157, g = 181, b = 201 },
  { index = 78,  name = 'Bleu Surf Clair',       r = 110, g = 135, b = 161 },
  { index = 79,  name = 'Bleu Nautique 2',       r = 12,  g = 88,  b = 128 },
  { index = 80,  name = 'Bleu Ultra',            r = 36,  g = 64,  b = 122 },
  { index = 82,  name = 'Bleu Mauve',            r = 76,  g = 86,  b = 144 },
  -- ===== Violet / Rose =====
  { index = 83,  name = 'Mauve Fonce',           r = 35,  g = 34,  b = 40  },
  { index = 92,  name = 'Vert Lime',             r = 154, g = 204, b = 64  },
  { index = 135, name = 'Rose Vif',              r = 242, g = 24,  b = 150 },
  { index = 137, name = 'Rose',                  r = 191, g = 91,  b = 176 },
  { index = 145, name = 'Violet Fonce',          r = 98,  g = 38,  b = 153 },
  { index = 142, name = 'Violet',                r = 70,  g = 46,  b = 86  },
  -- ===== Blanc / Noir =====
  { index = 111, name = 'Blanc Pur',             r = 255, g = 255, b = 255 },
  { index = 112, name = 'Blanc Glace',           r = 234, g = 234, b = 234 },
  { index = 121, name = 'Blanc Casse',           r = 200, g = 196, b = 191 },
  { index = 134, name = 'Blanc Frost',           r = 159, g = 153, b = 140 },
  -- ===== Mate =====
  { index = 131, name = 'Blanc Mat',             r = 255, g = 255, b = 255 },
  { index = 132, name = 'Noir Mat',              r = 13,  g = 17,  b = 22  },
  { index = 133, name = 'Gris Mat',              r = 35,  g = 38,  b = 42  },
  { index = 147, name = 'Gris Fer Mat',          r = 30,  g = 32,  b = 33  },
  { index = 148, name = 'Bleu Mat',              r = 39,  g = 70,  b = 110 },
  { index = 149, name = 'Bleu Nuit Mat',         r = 35,  g = 49,  b = 85  },
  { index = 150, name = 'Rouge Mat',             r = 192, g = 23,  b = 28  },
  { index = 151, name = 'Rouge Sombre Mat',      r = 51,  g = 25,  b = 27  },
  { index = 152, name = 'Orange Mat',            r = 240, g = 152, b = 12  },
  { index = 153, name = 'Jaune Mat',             r = 240, g = 220, b = 13  },
  { index = 154, name = 'Lime Mat',              r = 154, g = 204, b = 64  },
  { index = 155, name = 'Vert Mat',              r = 45,  g = 48,  b = 41  },
  { index = 156, name = 'Vert Foret Mat',        r = 28,  g = 31,  b = 22  },
  -- ===== Metaux =====
  { index = 117, name = 'Or Brushed',            r = 178, g = 134, b = 95  },
  { index = 90,  name = 'Or Bronze',             r = 178, g = 134, b = 95  },
  { index = 91,  name = 'Or Champagne',          r = 222, g = 195, b = 151 },
  { index = 115, name = 'Acier Brushed',         r = 140, g = 144, b = 149 },
  { index = 116, name = 'Aluminium Brushed',     r = 145, g = 149, b = 152 },
  { index = 158, name = 'Aluminium Brushed 2',   r = 154, g = 159, b = 160 },
}

-- Lookup index -> {r,g,b} pour recuperer la couleur de depart d'un vehicule.
PaintGun.ColorByIndex = {}
for _, c in ipairs(PaintGun.Colors) do
  PaintGun.ColorByIndex[c.index] = c
end
