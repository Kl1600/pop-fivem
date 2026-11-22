-- Tenue et armes équipées appliquées au ped, réapplication après rechargement du skin.

local function applyComponents(ped, components)
  local setArms = false
  for compId, data in pairs(components or {}) do
    local id = tonumber(compId)
    if id and id >= 0 and id <= 11 and type(data) == 'table' then
      SetPedComponentVariation(ped, id, tonumber(data.drawable) or 0, tonumber(data.texture) or 0, tonumber(data.palette) or 0)
      if id == 3 then setArms = true end
    end
  end
  return setArms
end

local function applyProps(ped, props)
  for propId, data in pairs(props or {}) do
    local id = tonumber(propId)
    if id and type(data) == 'table' then
      local drawable = tonumber(data.drawable)
      if drawable == nil or drawable < 0 then
        ClearPedProp(ped, id)
      else
        SetPedPropIndex(ped, id, drawable, tonumber(data.texture) or 0, true)
      end
    end
  end
end

local function getGender()
  local model = GetEntityModel(PlayerPedId())
  if model == GetHashKey('mp_f_freemode_01') then
    return 'female'
  end
  return 'male'
end

Inv.applyNude = function()
  local ped = PlayerPedId()
  local gender = getGender()
  local nude = Config.Nude and Config.Nude[gender]
  if not nude then
    return
  end

  -- Si on n'a pas encore de customTorso, on essaie de le récupérer depuis le ped actuel (pour garder la synchro skinchanger)
  if Inv.customTorso == nil then
    Inv.customTorso = GetPedDrawableVariation(ped, 3)
  end

  local components = {}
  for k,v in pairs(nude.components) do components[k] = v end

  -- On force le torse choisi (ou celui du skin actuel) au lieu de celui par défaut de Config.Nude
  if Inv.customTorso ~= nil then
    components[3] = { drawable = Inv.customTorso, texture = 0, palette = 0 }
  end

  applyComponents(ped, components)
  applyProps(ped, nude.props)
end

Inv.applyClothing = function(equipment)
  local ped = PlayerPedId()
  Inv.applyNude()
  local armsFromClothes = false

  for _, item in pairs(equipment or {}) do
    local defId = item
    local meta = {}

    if type(item) == 'table' then
        defId = item.defId
        meta = item.meta or {}
    end

    if meta and (meta.components or meta.props) then
        if meta.components and applyComponents(ped, meta.components) then armsFromClothes = true end
        if meta.props then applyProps(ped, meta.props) end
    else
        local config = Config.Clothing and Config.Clothing[defId]
        if config then
          local gender = getGender()
          local data = config[gender]
          if data then
            if applyComponents(ped, data.components) then armsFromClothes = true end
            applyProps(ped, data.props)
          end
        end
    end
  end

  -- LES BRAS DOIVENT ÊTRE PERSISTANTS :
  -- Après l'application de TOUS les vêtements de l'inventaire, on écrase de force
  -- l'éventuelle texture de bras (component 3) chargée par un t-shirt pour garder
  -- 100% des bras choisis par l'utilisateur dans son menu inventaire.
  -- Exception : si un vêtement porté fixe lui-même les bras (haut du créateur ou
  -- de la boutique), on les garde, sinon le haut s'affiche avec des bras décalés.
  if Inv.customTorso ~= nil and not armsFromClothes then
    SetPedComponentVariation(ped, 3, Inv.customTorso, 0, 0)
  end
end

local function applyWeapons(equipment)
  CreateThread(function()
    local ped = PlayerPedId()
    local managedHashes = {}
    for _, itemDef in pairs(Config.Items or {}) do
      if itemDef.weaponHash then
        managedHashes[GetHashKey(itemDef.weaponHash)] = true
      end
    end

    local desiredHashes = {}
    local desiredAmmo = {}
    local desiredComponents = {}

    local briefcaseHash = GetHashKey('WEAPON_BRIEFCASE_02')
    managedHashes[briefcaseHash] = nil

    if equipment then
      for _, item in pairs(equipment) do
        local defId = (type(item) == 'table' and item.defId) or item
        local itemDef = Config.Items and Config.Items[defId]
        if itemDef and itemDef.weaponHash then
          local hash = GetHashKey(itemDef.weaponHash)
          if hash ~= briefcaseHash then
            desiredHashes[hash] = true
            local hasMagWell = (type(item) == 'table' and item.containerId ~= nil)
            desiredAmmo[hash] = hasMagWell and 0 or 9999
            desiredComponents[hash] = {}
            local meta = type(item) == 'table' and item.meta or nil
            local attachments = meta and meta.attachments or nil
            local mapping = Config.WeaponAttachments and Config.WeaponAttachments[itemDef.weaponHash] or nil
            if attachments and mapping then
              for slotName, accessoryDefId in pairs(attachments) do
                local slotDef = mapping[slotName]
                if slotDef and slotDef.item == accessoryDefId and slotDef.componentHash then
                  desiredComponents[hash][GetHashKey(slotDef.componentHash)] = true
                end
              end
            end
          end
        end
      end
    end

    -- 1. Supprimer les armes gérées que le joueur ne devrait plus avoir
    for hash, _ in pairs(managedHashes) do
      if HasPedGotWeapon(ped, hash, false) and not desiredHashes[hash] then
        SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
        Wait(50)
        RemoveWeaponFromPed(ped, hash)
        Wait(50)
        if HasPedGotWeapon(ped, hash, false) then
          RemoveWeaponFromPed(ped, hash)
        end
        if GetSelectedPedWeapon(ped) == hash then
          SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
        end
      end
    end

    -- 2. Donner les armes que le joueur doit avoir + synchroniser leurs accessoires
    for hash, _ in pairs(desiredHashes) do
      if not HasPedGotWeapon(ped, hash, false) then
        local isHeavyWeapon = false
        if equipment and equipment['weapon_long'] then
          local hItem = equipment['weapon_long']
          local hDefId = (type(hItem) == 'table' and hItem.defId) or hItem
          local hDef = Config.Items and Config.Items[hDefId]
          if hDef and hDef.weaponHash and GetHashKey(hDef.weaponHash) == hash then
            isHeavyWeapon = true
          end
        end

        GiveWeaponToPed(ped, hash, desiredAmmo[hash] or 9999, false, isHeavyWeapon)
        managedHashes[hash] = true
      end

      local wanted = desiredComponents[hash] or {}
      local mapping = nil
      for _, itemDef in pairs(Config.Items or {}) do
        if itemDef.weaponHash and GetHashKey(itemDef.weaponHash) == hash then
          mapping = Config.WeaponAttachments and Config.WeaponAttachments[itemDef.weaponHash]
          break
        end
      end
      if mapping then
        for _, slotDef in pairs(mapping) do
          if slotDef.componentHash then
            local cHash = GetHashKey(slotDef.componentHash)
            if HasPedGotWeaponComponent(ped, hash, cHash) and not wanted[cHash] then
              RemoveWeaponComponentFromPed(ped, hash, cHash)
            end
          end
        end
      end
      for cHash, _ in pairs(wanted) do
        if not HasPedGotWeaponComponent(ped, hash, cHash) then
          GiveWeaponComponentToPed(ped, hash, cHash)
        end
      end
    end

    -- Auto-équipe l'arme lourde
    if equipment and equipment['weapon_long'] then
      local defId = (type(equipment['weapon_long']) == 'table' and equipment['weapon_long'].defId) or equipment['weapon_long']
      local itemDef = Config.Items and Config.Items[defId]
      if itemDef and itemDef.weaponHash then
        local hash = GetHashKey(itemDef.weaponHash)
        if IsWeaponValid(hash) then
          if HasPedGotWeapon(ped, hash, false) then
            SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
            Wait(50)
            SetCurrentPedWeapon(ped, hash, true)
            -- Double vérification
            if GetSelectedPedWeapon(ped) ~= hash then
              SetCurrentPedWeapon(ped, hash, true)
            end
          end
        end
      end
    end
  end)
end

RegisterNetEvent('pop_inventory:client:applyEquipment', function(equipment)
  Inv.currentEquipment = equipment or {}
  Inv.applyClothing(equipment)
  applyWeapons(equipment)
end)

exports('RefreshEquipment', function()
    if Inv.currentEquipment then
        Inv.applyClothing(Inv.currentEquipment)
        applyWeapons(Inv.currentEquipment)
    end
end)

-- Réapplique la tenue portée après un rechargement du skin (ESX/skinchanger
-- remettent le skin sauvegardé, « nu », au spawn). Les appels rapprochés sont
-- regroupés en un seul. Rien pendant la création de perso.
local reapplyToken = 0
local function reapplyEquipment(delay)
  reapplyToken = reapplyToken + 1
  local token = reapplyToken
  SetTimeout(delay or 500, function()
    if token ~= reapplyToken then return end
    if LocalPlayer.state.charcreatorOpen then return end
    if Inv.currentEquipment then
      Inv.applyClothing(Inv.currentEquipment)
    end
  end)
end


local function playerReady()
  CreateThread(function()
    Wait(4000) -- laisse le temps au charcreator et à skinchanger de finir
    -- En ESX, on attend que le joueur soit chargé : sinon l'inventaire serait
    -- demandé trop tôt (vide). esx:playerLoaded relancera playerReady.
    if not Bridge.IsLoaded() then return end
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('pop_inventory:server:playerReady', { x = coords.x, y = coords.y, z = coords.z })
  end)
end

AddEventHandler('playerSpawned', function()
  playerReady()
  reapplyEquipment(1500)
end)

AddEventHandler('esx:onPlayerSpawn', function()
  reapplyEquipment(1500)
end)

AddEventHandler('skinchanger:modelLoaded', function()
  reapplyEquipment(500)
end)

-- Un rechargement du skin (esx_skin au spawn, coiffeur, admin…) remet le perso
-- « nu » : on remet la tenue de l'inventaire par-dessus.
AddEventHandler('skinchanger:loadSkin', function()
  reapplyEquipment(800)
end)

RegisterNetEvent('esx:playerLoaded', function()
  playerReady()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
  playerReady()
end)

AddEventHandler('onResourceStart', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end
  playerReady()
end)

-- Inventaire ouvert : rafraîchit le sol autour du joueur quand il s'est déplacé
-- (plus de 1,5 m) ou toutes les 5 s. Le serveur envoie déjà l'état après chaque action.
CreateThread(function()
  local lastCoords, lastSent = nil, 0
  while true do
    if Inv.isOpen then
      local coords = GetEntityCoords(PlayerPedId())
      local now = GetGameTimer()
      if not lastCoords or #(coords - lastCoords) > 1.5 or now - lastSent > 5000 then
        lastCoords, lastSent = coords, now
        TriggerServerEvent('pop_inventory:server:requestState', { x = coords.x, y = coords.y, z = coords.z })
      end
      Wait(1000)
    else
      lastCoords = nil
      Wait(500)
    end
  end
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then
    return
  end
  SetNuiFocus(false, false)
  if clearAllDropMarkers then
    clearAllDropMarkers()
  end
end)
