-- Accessoires d'armes (chargé après config/items_*.lua).

-- ============================================================
--  CONFIG.WEAPONATTACHMENTS
--  Mapping arme (weaponHash) -> slot d'accessoire -> item compatible + componentHash GTA natif.
--  Chaque slot n'accueille qu'un seul accessoire. 'label' = libellé du slot dans l'UI.
--  Les items (token 'item') sont réutilisés entre armes d'une même catégorie : c'est le
--  componentHash, propre à chaque arme/slot, qui détermine le composant réellement appliqué.
--  Tous les items référencés ici sont générés automatiquement plus bas (icône unknown.webp).
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
--  qui n'existe pas déjà — tous avec l'icône unknown.webp.
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
        icon = 'img/unknown.webp',
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
