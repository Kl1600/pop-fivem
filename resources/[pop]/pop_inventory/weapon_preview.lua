-- =====================================================================
--  PREVISUALISATION 3D D'ARME  -  Section "Accessoires"
--  Crée l'objet arme (avec ses composants attachés) dans le ciel au-dessus du
--  joueur, pointe une caméra scriptée dessus, et la rend visible DERRIERE la NUI
--  (qui reste affichée). Le joueur fait tourner l'arme en glissant la souris sur
--  la zone centrale de la vue accessoires. L'UI existante est conservée.
-- =====================================================================

local obj = nil
local cam = nil
local active = false
local loadedAsset = nil
local appliedComponents = {}   -- [hash] = true
local rotPitch, rotYaw = 0.0, 130.0 -- vue 3/4 par défaut

-- Helpers vecteurs pour placer l'arme devant la caméra de jeu.
local function _dir(rot)
  local z = math.rad(rot.z)
  local x = math.rad(rot.x)
  local n = math.abs(math.cos(x))
  return vector3(-math.sin(z) * n, math.cos(z) * n, math.sin(x))
end
local function _cross(a, b)
  return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end
local function _norm(v)
  local len = #(v)
  if len == 0 then return v end
  return v / len
end

-- Distance de l'arme devant la caméra + remontée verticale (alignement cellules).
-- Plus PREVIEW_DIST est petit, plus l'arme paraît GROSSE.
local PREVIEW_DIST = 1.15
local PREVIEW_UP = 0.10

-- Positionne l'arme DEVANT la caméra de jeu chaque frame (aucune caméra scriptée
-- -> pas de téléportation de vue, on reste sur le perso) et applique la rotation.
CreateThread(function()
  while true do
    if active and obj and DoesEntityExist(obj) then
      local cc = GetGameplayCamCoord()
      local fwd = _dir(GetGameplayCamRot(2))
      local right = _norm(_cross(fwd, vector3(0.0, 0.0, 1.0)))
      local up = _cross(right, fwd)
      local pos = cc + fwd * PREVIEW_DIST + up * PREVIEW_UP
      SetEntityCoordsNoOffset(obj, pos.x, pos.y, pos.z, false, false, false)
      SetEntityRotation(obj, rotPitch, 0.0, rotYaw, 2, true)
      Wait(0)
    else
      Wait(200)
    end
  end
end)

local function applyComponentList(components)
  if not obj or not DoesEntityExist(obj) then return end
  local want = {}
  for _, c in ipairs(components or {}) do
    local h = (type(c) == 'string') and GetHashKey(c) or c
    if h and h ~= 0 then want[h] = true end
  end
  -- Retire les composants qui ne sont plus voulus.
  for h in pairs(appliedComponents) do
    if not want[h] then
      pcall(RemoveWeaponComponentFromWeaponObject, obj, h)
      appliedComponents[h] = nil
    end
  end
  -- Ajoute les nouveaux.
  for h in pairs(want) do
    if not appliedComponents[h] then
      pcall(GiveWeaponComponentToWeaponObject, obj, h)
      appliedComponents[h] = true
    end
  end
end

local function cleanup()
  active = false
  if cam then
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    cam = nil
  end
  if obj and DoesEntityExist(obj) then
    DeleteEntity(obj)
  end
  obj = nil
  appliedComponents = {}
  if loadedAsset then
    RemoveWeaponAsset(loadedAsset)
    loadedAsset = nil
  end
  -- Restaure le flou d'arrière-plan de l'inventaire.
  TriggerScreenblurFadeIn(150)
end

local function startPreview(weaponHashStr, components)
  cleanup()
  if not weaponHashStr then return end
  local hash = GetHashKey(weaponHashStr)

  RequestWeaponAsset(hash, 31, 0)
  local t = GetGameTimer() + 2000
  while not HasWeaponAssetLoaded(hash) and GetGameTimer() < t do Wait(0) end
  loadedAsset = hash

  -- Créée près du joueur ; le thread la repositionne aussitôt DEVANT la caméra de jeu.
  local pc = GetEntityCoords(PlayerPedId())
  obj = CreateWeaponObject(hash, 50, pc.x, pc.y, pc.z + 1.0, true, 1.0, 0)
  if not obj or obj == 0 then
    obj = nil
    return
  end
  SetEntityCollision(obj, false, false)
  FreezeEntityPosition(obj, true)
  SetEntityInvincible(obj, true)
  applyComponentList(components)

  rotPitch, rotYaw = 0.0, 130.0
  -- Pas de caméra scriptée : on coupe juste le flou d'arrière-plan pour une arme nette.
  TriggerScreenblurFadeOut(150)
  active = true
end

-- ------------------------------------------------------------------
--  Callbacks NUI (déclenchés par app.js dans la vue accessoires)
-- ------------------------------------------------------------------
RegisterNUICallback('weaponPreviewStart', function(data, cb)
  CreateThread(function()
    startPreview(data and data.weaponHash, data and data.components or {})
  end)
  cb('ok')
end)

-- Mise à jour des composants (attache/détache un accessoire -> reflet en 3D).
RegisterNUICallback('weaponPreviewUpdate', function(data, cb)
  if active then applyComponentList(data and data.components or {}) end
  cb('ok')
end)

-- Rotation par glisser de souris (dx/dy accumulés côté NUI).
RegisterNUICallback('weaponPreviewRotate', function(data, cb)
  if active and obj and DoesEntityExist(obj) then
    rotYaw = (rotYaw + (tonumber(data and data.dx) or 0.0) * 0.45) % 360.0
    rotPitch = math.max(-89.0, math.min(89.0, rotPitch - (tonumber(data and data.dy) or 0.0) * 0.45))
    SetEntityRotation(obj, rotPitch, 0.0, rotYaw, 2, true)
  end
  cb('ok')
end)

RegisterNUICallback('weaponPreviewStop', function(_, cb)
  cleanup()
  cb('ok')
end)

-- Sécurité : nettoyage si l'inventaire se ferme alors que la preview est active.
AddEventHandler('pop_inventory:client:weaponPreviewStop', cleanup)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then cleanup() end
end)
