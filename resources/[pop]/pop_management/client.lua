-- tab_duiengine_laptopdemo/client.lua
-- Laptop demo using ReplaceTexture render path + direct mouse forwarding (no raycast UV, no NUI overlay).
-- Multi-laptop placement + single-open enforcement:
--  - /lapplace places another CLOSED laptop (does not delete previous)
--  - Only ONE laptop may be OPEN (and interactive) at a time on this client
--  - When you stop interacting (ESC / walk away), the laptop closes back to CLOSED model

local CR3D = CR3D
Config = Config or {}

local shelfObj = nil
local shelfCartons = {}        -- cartons d'aperçu DEV (commande /ytcarton)
local orderCartons = {}        -- [orderId] = entity : cartons des commandes en cours

-- =============================
-- CONFIG
-- =============================
local CLOSED_MODEL
local OPEN_MODEL
local REPLACE_CANDIDATES

if Config.Style == '80s' then
  CLOSED_MODEL = GetHashKey('computer')
  OPEN_MODEL   = GetHashKey('computer')
  REPLACE_CANDIDATES = {
    {"prop_monitor_03b", "prop_monitor_03b"},
    {"prop_monitor_03b", "prop_monitor_03"},
    {"prop_monitor_03b", "prop_screen"},
    {"prop_monitor_03b", "screen"},
    {"prop_monitor_03b", "tvscreen"},
    {"prop_monitor_03b", "script_rt"},
    {"prop_monitor_03b", "prop_monitor_03b_overlay"},
    {"prop_monitor_03b", "prop_monitor_03_overlay"},
    {"prop_monitor_03", "prop_monitor_03b"},
    {"prop_monitor_03", "prop_monitor_03"},
    {"prop_monitor_03", "prop_screen"},
    {"prop_monitor_03", "screen"},
    {"prop_monitor_03", "tvscreen"},
    {"prop_monitor_03", "script_rt"},
    {"prop_monitor_03", "prop_monitor_03b_overlay"},
    {"prop_monitor_03", "prop_monitor_03_overlay"},
  }
else
  CLOSED_MODEL = GetHashKey('prop_laptop_02_closed')
  OPEN_MODEL   = GetHashKey('prop_laptop_lester')
  REPLACE_CANDIDATES = {
    -- {txd, txn} pairs (from model dictionaries)
    {"prop_laptop_lester", "prop_lester_screen"},
    {"prop_laptop_lester", "prop_laptop_lester"},
    {"prop_laptop_lester", "prop_screen"},
    {"prop_laptop_lester", "screen"},
    {"prop_laptop_lester", "laptop_screen"},
    {"prop_laptop_02", "prop_laptop_02"},
    {"prop_laptop_02", "screen"},
    {"prop_laptop_02", "laptop_screen"},
    {"prop_laptop_02_closed", "prop_laptop_02_closed"},
    {"prop_laptop_02_closed", "screen"},
  }
end

-- Mouse sensitivity for virtual cursor (bigger = faster)
local CURSOR_SENS = 0.090

-- Small delay after swapping models / creating DUI before entering focus
-- (helps avoid a 1-frame black RT while the DUI paints its first frame)
local OPEN_FOCUS_DELAY_MS = 200

-- Some models have forward vector pointing *away* from the screen.
-- If focus gate feels backwards, toggle with /lapside
local SCREEN_SIDE = 1 -- 1 or -1

-- =============================
-- STATE
-- =============================
-- Each laptop entry:
-- { closedEnt = <entity>, openEnt = <entity or 0> }
local laptops = {}

-- Only ONE active open laptop at a time
local activeLaptop = nil

-- Single ReplaceTexture on this client (ReplaceTexture is global per slot)
local replaceId = nil
local panelId = nil
local replaceIdx = 1
local duiResW = 1024
local duiResH = (Config.Style == '80s') and 768 or 576

local focused = false
local focusThread = nil

local cursorX, cursorY = 0.5, 0.5
local lmbDown = false
local currentPromptId = nil -- pop_v3dui prompt ID
local keyboardOpen = false
local spawnedVan = nil
local spawnedPed = nil
local spawnedBoxProp = nil
local spawnedBlip = nil

-- Forward declarations (used by endFocus/closeActive before camera funcs are defined)
local startLaptopCam, stopLaptopCam, beginFocus

-- =============================
-- HELPERS
-- =============================
-- URLs lore-friendly GTA (square) pour les notifs imagées.
local NOTIF_IMG = {
    laptop  = "https://static.wikia.nocookie.net/gta/images/c/c4/Lifeinvader-GTAV-Logo.png",
    bank    = "https://static.wikia.nocookie.net/gta/images/8/82/MazeBankLogo-GTAV.png",
    youtool = "nui://pop_management/html/gopostal.png",
    car     = "nui://pop_management/html/46001a-12.webp",
    gov     = "https://static.wikia.nocookie.net/gta/images/4/4f/CityHallLS-GTAV-Logo.png",
    contract= "https://static.wikia.nocookie.net/gta/images/9/91/Auction-GTAO.png",
    print   = "https://static.wikia.nocookie.net/gta/images/9/91/Auction-GTAO.png",
}

-- Nettoie les codes couleur GTA (~y~, ~b~, ...) — non rendus par le système notif custom.
local function stripGtaColors(s)
    if type(s) ~= 'string' then return s end
    return (s:gsub('~[a-zA-Z]~', ''))
end

local function notify(msg, opts)
    opts = opts or {}
    msg = stripGtaColors(msg)
    if Config.NotificationType == 'esx' then
        ESX.ShowNotification(msg)
    else
        local payload = {
            title    = opts.title,
            message  = msg,
            image    = opts.image,
            icon     = opts.icon or (not opts.image and "fas fa-info" or nil),
            duration = opts.duration or 3000,
        }
        exports["pop_notify"]:ShowNotify(payload)
    end
end



local function reqModel(model)
  if not IsModelInCdimage(model) then return false end
  RequestModel(model)
  local t0 = GetGameTimer()
  while not HasModelLoaded(model) do
    if GetGameTimer() - t0 > 5000 then return false end
    Wait(0)
  end
  return true
end

local function vNorm(v)
  local l = math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
  if l < 0.000001 then return vector3(0.0, 0.0, 1.0) end
  return vector3(v.x/l, v.y/l, v.z/l)
end

local function vDot(a,b)
  return a.x*b.x + a.y*b.y + a.z*b.z
end

local function vCross(a, b)
  return vector3(
    a.y * b.z - a.z * b.y,
    a.z * b.x - a.x * b.z,
    a.x * b.y - a.y * b.x
  )
end

local function vLen(v)
  return math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
end

-- Rodrigues : rotation du vecteur v autour de l'axe (unitaire) par angleDeg.
-- v' = v cosθ + (a × v) sinθ + a (a · v)(1 − cosθ)
local function vRotateAxisAngle(v, axis, angleDeg)
  if angleDeg == 0 or angleDeg == 0.0 then return v end
  local rad = math.rad(angleDeg)
  local cos = math.cos(rad)
  local sin = math.sin(rad)
  local a = vNorm(axis)
  local cross = vCross(a, v)
  local dot = vDot(a, v)
  return vector3(
    v.x * cos + cross.x * sin + a.x * dot * (1 - cos),
    v.y * cos + cross.y * sin + a.y * dot * (1 - cos),
    v.z * cos + cross.z * sin + a.z * dot * (1 - cos)
  )
end

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

local function rotToAxes(rot)
  local x = math.rad(rot.x or 0.0)
  local y = math.rad(rot.y or 0.0)
  local z = math.rad(rot.z or 0.0)

  local cosx, sinx = math.cos(x), math.sin(x)
  local cosy, siny = math.cos(y), math.sin(y)
  local cosz, sinz = math.cos(z), math.sin(z)

  -- Forward vector
  local forward = vector3(-sinz * cosx, cosz * cosx, sinx)
  -- Right vector
  local right = vector3(
    cosz * cosy + sinz * sinx * siny,
    sinz * cosy - cosz * sinx * siny,
    -cosx * siny
  )
  -- Up vector
  local up = vector3(
    cosz * siny - sinz * sinx * cosy,
    sinz * siny + cosz * sinx * cosy,
    cosx * cosy
  )

  return right, forward, up
end

local function axesLocalToWorld(right, forward, up, v)
  return right * v.x + forward * v.y + up * v.z
end


local function safeDelete(ent)
  if ent and ent ~= 0 and DoesEntityExist(ent) then
    SetEntityAsMissionEntity(ent, true, true)
    DeleteEntity(ent)
  end
end

local function destroyReplace()
  if replaceId then
    pcall(function()
      exports['pop_duiengine']:DestroyReplaceTexture(replaceId)
    end)
    replaceId = nil
  end
end

local function currentPair()
  local p = REPLACE_CANDIDATES[replaceIdx]
  return p[1], p[2]
end

local function printCandidate()
  local txd, txn = currentPair()
  print(("ReplaceTexture candidate %d/%d: %s / %s"):format(replaceIdx, #REPLACE_CANDIDATES, txd, txn))
end

-- player must be on the screen side of the laptop/monitor
local function isPlayerOnScreenSide(ent)
  if not DoesEntityExist(ent) then return false end

  if Config.Style == '80s' then
    return true
  end

  local pPed = PlayerPedId()
  local pPos = GetEntityCoords(pPed)
  local ePos = GetEntityCoords(ent)

  local toPlayer = vNorm(pPos - ePos)

  -- GetEntityMatrix returns forwardVector as the 1st value
  local forward = select(1, GetEntityMatrix(ent))
  forward = vNorm(forward)

  local currentScreenSide = SCREEN_SIDE
  local screenNormal = vNorm(vector3(-forward.x, -forward.y, -forward.z)) * currentScreenSide

  local d = vDot(screenNormal, toPlayer)
  return d > 0.05
end

-- =============================
-- LAPTOP PLACE / OPEN / CLOSE
-- =============================
local function placeClosed(customPos, customHeading)
  if not reqModel(CLOSED_MODEL) then
    print('Failed to load closed laptop model')
    return
  end

  local pos, heading
  if customPos then
      pos = customPos
      heading = customHeading or 0.0
  else
      local ped = PlayerPedId()
      local p = GetEntityCoords(ped)
      local f = GetEntityForwardVector(ped)
      pos = p + (f * 1.0) + vector3(0.0, 0.0, -0.05)
      heading = GetEntityHeading(ped)
  end

  local closed = CreateObject(CLOSED_MODEL, pos.x, pos.y, pos.z, true, true, false)
  SetEntityHeading(closed, heading)
  FreezeEntityPosition(closed, true)

  table.insert(laptops, { id = #laptops + 1, closedEnt = closed, openEnt = 0 })
  print(('Placed closed laptop #%d. Walk up and press E.'):format(#laptops))
end

local function openLaptop(entry)
  if not entry or not DoesEntityExist(entry.closedEnt) then
    print('Invalid laptop.')
    return false
  end

  if not reqModel(OPEN_MODEL) then
    print('Failed to load open laptop model')
    return false
  end

  local pos = GetEntityCoords(entry.closedEnt)
  local heading = GetEntityHeading(entry.closedEnt)

  -- spawn open model at same transform
  safeDelete(entry.openEnt)
  entry.openEnt = CreateObject(OPEN_MODEL, pos.x, pos.y, pos.z, true, true, false)
  SetEntityHeading(entry.openEnt, heading)
  FreezeEntityPosition(entry.openEnt, true)

  -- hide closed model (we keep the entity to "close" back later)
  SetEntityVisible(entry.closedEnt, false, false)
  SetEntityCollision(entry.closedEnt, false, false)

  return true
end

local function closeLaptop(entry)
  if not entry then return end

  safeDelete(entry.openEnt)
  entry.openEnt = 0

  if DoesEntityExist(entry.closedEnt) then
    SetEntityVisible(entry.closedEnt, true, false)
    SetEntityCollision(entry.closedEnt, true, true)
  end
end

local function ensureReplace(entry)
  -- Always recreate ReplaceTexture so UI reloads with correct lap id
  destroyReplace()

  local txd, txn = currentPair()
  local lapId = entry and entry.id or 0

  local theme = (Config and Config.Style) or '2026'
  replaceId = exports['pop_duiengine']:CreateReplaceTexture({
    url = ('nui://%s/html/index.html?lap=%d&theme=%s'):format(GetCurrentResourceName(), lapId, theme),
    resW = 1024,
    resH = 576,

    model = OPEN_MODEL,
    owner = GetCurrentResourceName(),

    origTxd = txd,
    origTxn = txn,
  })

  printCandidate()
  return replaceId ~= nil
end

-- Lecture du Config par style. Si une clé manque, fallback hardcoded
-- pour ne pas crasher sur une vieille version de config.lua.
local _stKey   = (Config and Config.Style) or '2026'
local _stTbl   = (Config and Config.ScreenTransform and Config.ScreenTransform[_stKey]) or {}
local testOffset = _stTbl.offset      or vector3(0.1690, 0.3460, 0.2693)
local testNormal = _stTbl.localNormal or vector3(-0.9944, 0.0697, -0.0763)
local testUp     = _stTbl.localUp     or vector3(0.0164, 0.0122, -0.9924)
local testWidth  = _stTbl.width       or 0.4400
local testHeight = _stTbl.height      or ((_stKey == '80s') and 0.3300 or 0.2800)

-- Rotations additives de l'écran (degrés) appliquées sur localNormal / localUp.
-- Ordre intrinsèque : yaw (autour de U), puis pitch (autour de R), puis roll
-- (autour de N). Permet d'ajuster l'inclinaison sans recalculer les vecteurs.
do
  local sPitch = _stTbl.screenPitch or 0.0
  local sYaw   = _stTbl.screenYaw   or 0.0
  local sRoll  = _stTbl.screenRoll  or 0.0
  if sPitch ~= 0 or sYaw ~= 0 or sRoll ~= 0 then
    local N = vNorm(testNormal)
    local U = vNorm(testUp)
    -- "Right" du plan écran : R = U × N (convention droite-main).
    local R = vNorm(vCross(U, N))

    -- Yaw autour de U : N tourne, U fixe, R recalculé.
    if sYaw ~= 0 then
      N = vNorm(vRotateAxisAngle(N, U, sYaw))
      R = vNorm(vCross(U, N))
    end
    -- Pitch autour de R : N et U tournent, R fixe.
    if sPitch ~= 0 then
      N = vNorm(vRotateAxisAngle(N, R, sPitch))
      U = vNorm(vRotateAxisAngle(U, R, sPitch))
    end
    -- Roll autour de N : U tourne (Dutch angle dans le plan), N fixe.
    if sRoll ~= 0 then
      U = vNorm(vRotateAxisAngle(U, N, sRoll))
    end

    testNormal = N
    testUp     = U
  end
end

local function ensurePanel(entry, entityOverride)
  if panelId then
    pcall(function() exports['pop_duiengine']:DestroyPanel(panelId) end)
    panelId = nil
  end

  local ent = entityOverride or (entry and entry.openEnt)
  if not ent or ent == 0 or not DoesEntityExist(ent) then return false end

  local lapId = entry and entry.id or 0
  local theme = (Config and Config.Style) or '2026'

  panelId = exports['pop_duiengine']:AttachPanelToEntity({
    entity = ent,
    url = ('nui://%s/html/index.html?lap=%d&theme=%s'):format(GetCurrentResourceName(), lapId, theme),
    resW = duiResW,
    resH = duiResH,
    width = testWidth,
    height = testHeight,
    offset = testOffset, 
    localNormal = testNormal, 
    localUp = testUp,
    depthCompensation = "screen",
  })

  return panelId ~= nil
end

local function DrawText2D(x, y, text, scale)
  SetTextFont(0)
  SetTextProportional(1)
  SetTextScale(scale, scale)
  SetTextColour(255, 255, 255, 255)
  SetTextEntry("STRING")
  AddTextComponentString(text)
  DrawText(x, y)
end

local editing = false
local editingGizmo = false
local dummyEnt = nil
local testPanelPos = nil
local testPanelNormal = nil

local function ensurePanelOnDummy(ent)
  if panelId then
    pcall(function() exports['pop_duiengine']:DestroyPanel(panelId) end)
    panelId = nil
  end

  local lapId = activeLaptop and activeLaptop.id or 0
  local theme = (Config and Config.Style) or '2026'

  panelId = exports['pop_duiengine']:AttachPanelToEntity({
    entity = ent,
    url = ('nui://%s/html/index.html?lap=%d&theme=%s'):format(GetCurrentResourceName(), lapId, theme),
    resW = duiResW,
    resH = duiResH,
    width = testWidth,
    height = testHeight,
    offset = vector3(0.0, 0.0, 0.0), 
    localNormal = vector3(0.0, -1.0, 0.0), 
    localUp = vector3(0.0, 0.0, 1.0),
    depthCompensation = "screen",
  })
end

CreateThread(function()
  while true do
    if editingGizmo then
      Wait(0)
      
      -- Disable WASD movement so that the player doesn't move when pressing W to Translate
      DisableControlAction(0, 32, true) -- W
      DisableControlAction(0, 33, true) -- S
      DisableControlAction(0, 34, true) -- A
      DisableControlAction(0, 35, true) -- D
      DisableControlAction(0, 266, true) -- Move left/right
      DisableControlAction(0, 267, true)
      DisableControlAction(0, 268, true)
      DisableControlAction(0, 269, true)

      local changed = false
      local scaleSpeed = 0.001

      -- Width - Numpad Plus (Key 96) / Numpad Minus (Key 97)
      if IsDisabledControlPressed(0, 96) or IsControlPressed(0, 96) then -- Num +
        testWidth = testWidth + scaleSpeed
        changed = true
      elseif IsDisabledControlPressed(0, 97) or IsControlPressed(0, 97) then -- Num -
        testWidth = math.max(0.05, testWidth - scaleSpeed)
        changed = true
      end

      -- Height - Numpad Multiply (Key 98) / Numpad Divide (Key 99)
      if IsDisabledControlPressed(0, 98) or IsControlPressed(0, 98) then -- Num *
        testHeight = testHeight + scaleSpeed
        changed = true
      elseif IsDisabledControlPressed(0, 99) or IsControlPressed(0, 99) then -- Num /
        testHeight = math.max(0.05, testHeight - scaleSpeed)
        changed = true
      end

      if changed and dummyEnt and DoesEntityExist(dummyEnt) then
        ensurePanelOnDummy(dummyEnt)
      end

      -- Draw UI instructions
      DrawText2D(0.015, 0.015, "~g~[GIZMO EDITOR]~w~", 0.45)
      DrawText2D(0.015, 0.040, string.format("Width: %.4f | Height: %.4f", testWidth, testHeight), 0.40)
      DrawText2D(0.015, 0.065, "Num+/- : Adjust Width | Num*/ / : Adjust Height", 0.35)
      DrawText2D(0.015, 0.090, "[W]: Translate | [R]: Rotate | [ENTER]: Save & Exit", 0.35)
    else
      Wait(500)
    end
  end
end)

-- =============================
-- ÉDITEUR PAR COINS (corner editor) — placement 3D précis du quad DUI
-- via 3 coins. BR est dérivé pour forcer un rectangle. Le code en sort
-- des valeurs offset / localNormal / localUp / width / height propres,
-- décorrélées (pas de coupling pitch/yaw comme avec localNormal brut).
--
-- Repère de déplacement : ENTITÉ LOCAL (X = right, Y = forward, Z = up).
-- Donc peu importe l'orientation du PC dans le monde, "flèche droite"
-- bouge toujours le coin vers la droite du PC.
-- =============================
local cornerEditorActive = false

local function startCornerEditor()
  if cornerEditorActive then return end
  if not Config.DevMode then return end

  -- Trouver l'entité PC (même logique que /lapedity).
  local monitorEnt = nil
  if activeLaptop and DoesEntityExist(activeLaptop.openEnt) then
    monitorEnt = activeLaptop.openEnt
  else
    local ped = PlayerPedId()
    local pPos = GetEntityCoords(ped)
    local obj = GetClosestObjectOfType(pPos.x, pPos.y, pPos.z, 5.0, OPEN_MODEL, false, false, false)
    if (obj == 0 or not DoesEntityExist(obj)) and CLOSED_MODEL ~= OPEN_MODEL then
      obj = GetClosestObjectOfType(pPos.x, pPos.y, pPos.z, 5.0, CLOSED_MODEL, false, false, false)
    end
    if obj ~= 0 and DoesEntityExist(obj) then
      monitorEnt = obj
    end
  end

  if not monitorEnt then
    print(('[lapcorners] Aucun PC trouvé à proximité (5m). Modèles cherchés : OPEN=%s CLOSED=%s'):format(OPEN_MODEL, CLOSED_MODEL))
    notify('Aucun PC à proximité (5m).')
    return
  end

  -- Backup pour cancel (ESC).
  local origOffset, origNormal, origUp = testOffset, testNormal, testUp
  local origWidth,  origHeight        = testWidth,  testHeight

  -- Calcul des 3 coins initiaux depuis la transform courante.
  -- Repère écran : N (normal), U (up), R = N × U (right vu de l'extérieur).
  local C = testOffset
  local N = vNorm(testNormal)
  local U = vNorm(testUp)
  local R = vNorm(vCross(N, U))
  local halfW, halfH = testWidth / 2.0, testHeight / 2.0

  local corners = {
    TL = C + R * -halfW + U *  halfH,
    TR = C + R *  halfW + U *  halfH,
    BL = C + R * -halfW + U * -halfH,
  }
  local order = { 'TL', 'TR', 'BL' }
  local activeIdx = 1
  local normalFlipped = false -- toggle pour retourner localNormal si auto-derivé pointe à l'envers

  cornerEditorActive = true
  notify('Corner Editor ON — Tab cycle, flèches/PgUp-Dn move, Shift=fin, Space=flip, ENTER=save, ESC=cancel.')
  print('[lapcorners] Corner editor démarré. Le repère est entity-local du PC.')

  CreateThread(function()
    while cornerEditorActive do
      Wait(0)

      -- Bloquer WASD pour pas marcher pendant l'édition.
      DisableControlAction(0, 32, true)
      DisableControlAction(0, 33, true)
      DisableControlAction(0, 34, true)
      DisableControlAction(0, 35, true)

      local activeKey = order[activeIdx]
      -- Step : 1mm si Shift maintenu (fine), 1cm sinon (coarse).
      local step = (IsControlPressed(0, 21) or IsDisabledControlPressed(0, 21)) and 0.001 or 0.01

      -- Cycle Tab (37) / Shift+Tab pour reculer.
      if IsControlJustPressed(0, 37) or IsDisabledControlJustPressed(0, 37) then
        if IsControlPressed(0, 21) or IsDisabledControlPressed(0, 21) then
          activeIdx = activeIdx - 1
          if activeIdx < 1 then activeIdx = #order end
        else
          activeIdx = activeIdx % #order + 1
        end
      end

      -- Déplacement du coin actif en repère ENTITY-LOCAL.
      -- Convention : X = right entité, Y = forward, Z = up.
      local dx, dy, dz = 0.0, 0.0, 0.0
      if IsDisabledControlPressed(0, 175) or IsControlPressed(0, 175) then dx =  step end -- →
      if IsDisabledControlPressed(0, 174) or IsControlPressed(0, 174) then dx = -step end -- ←
      if IsDisabledControlPressed(0, 172) or IsControlPressed(0, 172) then dy =  step end -- ↑ (forward)
      if IsDisabledControlPressed(0, 173) or IsControlPressed(0, 173) then dy = -step end -- ↓
      if IsControlPressed(0, 10) or IsDisabledControlPressed(0, 10) then dz =  step end -- PageUp
      if IsControlPressed(0, 11) or IsDisabledControlPressed(0, 11) then dz = -step end -- PageDown

      if dx ~= 0 or dy ~= 0 or dz ~= 0 then
        corners[activeKey] = corners[activeKey] + vector3(dx, dy, dz)
      end

      -- Dérivation. BR forcé = TR + (BL - TL) pour garantir un rectangle.
      local TL = corners.TL
      local TR = corners.TR
      local BL = corners.BL
      local BR = TR + (BL - TL)

      local widthVec  = TR - TL
      local heightVec = TL - BL
      local w = vLen(widthVec)
      local h = vLen(heightVec)
      local center = (TR + BL) * 0.5
      local newUp     = (h > 0.0001) and vNorm(heightVec) or U
      local newNormal = vNorm(vCross(widthVec, heightVec))
      if normalFlipped then newNormal = -newNormal end

      -- Flip normal (SPACE = control 22).
      if IsControlJustPressed(0, 22) or IsDisabledControlJustPressed(0, 22) then
        normalFlipped = not normalFlipped
      end

      -- Conversion entity-local → monde pour le rendu des markers et lignes.
      local function lw(p) return GetOffsetFromEntityInWorldCoords(monitorEnt, p.x, p.y, p.z) end
      local wTL, wTR, wBL, wBR = lw(TL), lw(TR), lw(BL), lw(BR)

      -- Markers (sphères) : vert = actif, rouge = autres, gris = BR auto-dérivé.
      local function drawCorner(key, pos)
        local isActive = (key == activeKey)
        local r, g, b
        if isActive then r, g, b = 0, 255, 0
        else             r, g, b = 255, 50, 50 end
        DrawMarker(28, pos.x, pos.y, pos.z, 0, 0, 0, 0, 0, 0, 0.018, 0.018, 0.018,
                   r, g, b, 220, false, true, 2, false, nil, nil, false)
      end
      drawCorner('TL', wTL)
      drawCorner('TR', wTR)
      drawCorner('BL', wBL)
      DrawMarker(28, wBR.x, wBR.y, wBR.z, 0, 0, 0, 0, 0, 0, 0.012, 0.012, 0.012,
                 130, 130, 130, 170, false, true, 2, false, nil, nil, false)

      -- Bordure cyan du quad.
      DrawLine(wTL.x, wTL.y, wTL.z, wTR.x, wTR.y, wTR.z, 0, 220, 220, 255)
      DrawLine(wTR.x, wTR.y, wTR.z, wBR.x, wBR.y, wBR.z, 0, 220, 220, 255)
      DrawLine(wBR.x, wBR.y, wBR.z, wBL.x, wBL.y, wBL.z, 0, 220, 220, 255)
      DrawLine(wBL.x, wBL.y, wBL.z, wTL.x, wTL.y, wTL.z, 0, 220, 220, 255)

      -- Visualiser la normale : ligne du centre dans la direction sortante (10cm).
      local wCenter = lw(center)
      local nWorld = GetOffsetFromEntityInWorldCoords(monitorEnt, center.x + newNormal.x * 0.10,
                                                                    center.y + newNormal.y * 0.10,
                                                                    center.z + newNormal.z * 0.10)
      DrawLine(wCenter.x, wCenter.y, wCenter.z, nWorld.x, nWorld.y, nWorld.z, 255, 255, 0, 255)

      -- HUD.
      DrawText2D(0.015, 0.015, "~g~[CORNER EDITOR]~w~  Coin actif: ~y~" .. activeKey .. "~w~", 0.45)
      DrawText2D(0.015, 0.040, string.format("TL: %.3f, %.3f, %.3f",  TL.x, TL.y, TL.z), 0.35)
      DrawText2D(0.015, 0.060, string.format("TR: %.3f, %.3f, %.3f",  TR.x, TR.y, TR.z), 0.35)
      DrawText2D(0.015, 0.080, string.format("BL: %.3f, %.3f, %.3f",  BL.x, BL.y, BL.z), 0.35)
      DrawText2D(0.015, 0.100, string.format("center: %.3f,%.3f,%.3f   W: %.3f   H: %.3f",
                 center.x, center.y, center.z, w, h), 0.35)
      DrawText2D(0.015, 0.120, string.format("normal: %.3f,%.3f,%.3f  up: %.3f,%.3f,%.3f%s",
                 newNormal.x, newNormal.y, newNormal.z, newUp.x, newUp.y, newUp.z,
                 normalFlipped and "  (FLIPPED)" or ""), 0.35)
      DrawText2D(0.015, 0.140, "Step: " .. math.floor(step * 1000 + 0.5) .. "mm  (Shift = fin)", 0.35)
      DrawText2D(0.015, 0.160, "[Tab] cycle  [Arrows] X/Y  [PgUp/Dn] Z  [Space] flip normal  [ENTER] save  [ESC] cancel", 0.32)

      -- ENTER = save : applique au runtime + print F8 prêt à coller.
      if IsControlJustPressed(0, 191) or IsControlJustPressed(0, 18)
         or IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 18) then
        testOffset = center
        testNormal = newNormal
        testUp     = newUp
        testWidth  = w
        testHeight = h

        -- Refresh la DUI si on est focus.
        if focused and activeLaptop then
          ensurePanel(activeLaptop)
        end

        print('----------------------------------------')
        print('CORNER EDITOR — copier dans config.lua, bloc Config.ScreenTransform :')
        print(string.format('offset      = vector3(%.4f, %.4f, %.4f),', center.x, center.y, center.z))
        print(string.format('localNormal = vector3(%.4f, %.4f, %.4f),', newNormal.x, newNormal.y, newNormal.z))
        print(string.format('localUp     = vector3(%.4f, %.4f, %.4f),', newUp.x, newUp.y, newUp.z))
        print(string.format('width       = %.4f,', w))
        print(string.format('height      = %.4f,', h))
        print('-- Si tu utilises screenPitch/Yaw/Roll, repars de 0 — la nouvelle')
        print('-- base localNormal/localUp est déjà alignée sur tes coins.')
        print('----------------------------------------')
        notify('Coords printées en F8.')
        cornerEditorActive = false
        break
      end

      -- ESC = cancel : restaure les valeurs d'origine.
      if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 194)
         or IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 194) then
        testOffset = origOffset
        testNormal = origNormal
        testUp     = origUp
        testWidth  = origWidth
        testHeight = origHeight
        if focused and activeLaptop then
          ensurePanel(activeLaptop)
        end
        notify('Édition coins annulée.')
        cornerEditorActive = false
        break
      end
    end
  end)
end

-- =============================
-- ÉDITEUR CLAVIER (fallback gizmo) — extrait en fonction pour pouvoir être
-- appelé soit directement (si object_gizmo n'est pas chargé), soit en
-- secours après un crash du gizmo (export manquant, ox_lib HS, etc.).
-- =============================
local function startKeyboardEditor()
  editing = not editing
  if not editing then return end

  print('--- Screen Editor Started (Keyboard fallback) ---')
  print('Controls:')
  print('  - Arrow Up/Down : Shift Up/Down (Z)')
  print('  - Arrow Left/Right : Shift Left/Right (X)')
  print('  - Numpad 7/9 : Shift Forward/Backward (Y)')
  print('  - Numpad Plus/Minus : Scale Width')
  print('  - Numpad Multiply/Divide : Scale Height')
  print('  - ENTER : Save & print coordinates to F8')
  print('  - BACKSPACE / ESC : Exit editor')

  CreateThread(function()
    while editing do
      Wait(0)

      DisableControlAction(0, 32, true) -- W
      DisableControlAction(0, 33, true) -- S
      DisableControlAction(0, 34, true) -- A
      DisableControlAction(0, 35, true) -- D

      local speed = 0.001
      local scaleSpeed = 0.001
      local changed = false

      if IsDisabledControlPressed(0, 172) or IsControlPressed(0, 172) then
        testOffset = testOffset + vector3(0.0, 0.0, speed); changed = true
      elseif IsDisabledControlPressed(0, 173) or IsControlPressed(0, 173) then
        testOffset = testOffset - vector3(0.0, 0.0, speed); changed = true
      end

      if IsDisabledControlPressed(0, 174) or IsControlPressed(0, 174) then
        testOffset = testOffset - vector3(speed, 0.0, 0.0); changed = true
      elseif IsDisabledControlPressed(0, 175) or IsControlPressed(0, 175) then
        testOffset = testOffset + vector3(speed, 0.0, 0.0); changed = true
      end

      if IsControlPressed(0, 117) then
        testOffset = testOffset - vector3(0.0, speed, 0.0); changed = true
      elseif IsControlPressed(0, 118) then
        testOffset = testOffset + vector3(0.0, speed, 0.0); changed = true
      end

      if IsControlPressed(0, 96) then
        testWidth = testWidth + scaleSpeed; changed = true
      elseif IsControlPressed(0, 97) then
        testWidth = math.max(0.05, testWidth - scaleSpeed); changed = true
      end

      if IsControlPressed(0, 98) then
        testHeight = testHeight + scaleSpeed; changed = true
      elseif IsControlPressed(0, 99) then
        testHeight = math.max(0.05, testHeight - scaleSpeed); changed = true
      end

      if changed and focused and activeLaptop then
        ensurePanel(activeLaptop)
      end

      DrawText2D(0.015, 0.015, "~g~[SCREEN EDITOR]~w~", 0.45)
      DrawText2D(0.015, 0.040, string.format("Offset: vector3(%.4f, %.4f, %.4f)", testOffset.x, testOffset.y, testOffset.z), 0.40)
      DrawText2D(0.015, 0.065, string.format("Width: %.4f | Height: %.4f", testWidth, testHeight), 0.40)
      DrawText2D(0.015, 0.095, "Controls: Arrows (X/Z) | Num7/9 (Y) | Num+/- (Width) | Num*/ / (Height)", 0.35)
      DrawText2D(0.015, 0.120, "~g~ENTER~w~: Save & Print to F8 | ~r~BACKSPACE~w~: Exit", 0.35)

      if IsControlJustPressed(0, 191) or IsControlJustPressed(0, 18) then
        print('----------------------------------------')
        print('SAVED SCREEN TRANSFORMS (Fallback):')
        print(string.format('offset = vector3(%.4f, %.4f, %.4f),', testOffset.x, testOffset.y, testOffset.z))
        print(string.format('width = %.4f,', testWidth))
        print(string.format('height = %.4f,', testHeight))
        print('----------------------------------------')
        editing = false
        break
      end

      if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 194) then
        editing = false
        break
      end
    end
  end)
end

RegisterCommand('lapedity', function()
  if not Config.DevMode then return end

  -- Check stricte : l'ancien fallback `exports.object_gizmo ~= nil` était
  -- toujours truthy (proxy metatable FiveM). On se fie uniquement à
  -- GetResourceState ; le pcall plus bas attrape les cas où le resource
  -- est started mais l'export useGizmo a échoué à s'enregistrer.
  local gizmoAvailable = GetResourceState('object_gizmo') == 'started'
  if gizmoAvailable then
    if editingGizmo then return end

    local monitorEnt = nil
    if activeLaptop and DoesEntityExist(activeLaptop.openEnt) then
      monitorEnt = activeLaptop.openEnt
    else
      -- Cherche d'abord le modèle OUVERT (computer / prop_laptop_lester),
      -- puis le modèle FERMÉ (computer / prop_laptop_02_closed). Si 80s
      -- les deux sont identiques (`computer`), donc une seule recherche
      -- suffit.
      local ped = PlayerPedId()
      local pPos = GetEntityCoords(ped)
      local obj = GetClosestObjectOfType(pPos.x, pPos.y, pPos.z, 5.0, OPEN_MODEL, false, false, false)
      if (obj == 0 or not DoesEntityExist(obj)) and CLOSED_MODEL ~= OPEN_MODEL then
        obj = GetClosestObjectOfType(pPos.x, pPos.y, pPos.z, 5.0, CLOSED_MODEL, false, false, false)
      end
      if obj ~= 0 and DoesEntityExist(obj) then
        monitorEnt = obj
      end
    end

    if not monitorEnt then
      print(('No laptop/PC entity found nearby! (looked for OPEN=%s CLOSED=%s within 5m)'):format(OPEN_MODEL, CLOSED_MODEL))
      notify('Aucun laptop/PC trouvé à proximité (5m).')
      return
    end

    local monitorPos = GetEntityCoords(monitorEnt)
    local monitorRot = GetEntityRotation(monitorEnt, 2)

    -- Calculate initial world position of the screen based on current offset
    local posWorld = GetOffsetFromEntityInWorldCoords(monitorEnt, testOffset.x, testOffset.y, testOffset.z)

    -- Le dummy doit utiliser le même modèle que l'entité hôte pour que
    -- la rotation/orientation calculées en sortie de gizmo soient
    -- cohérentes. On s'assure qu'il est chargé.
    local dummyModel = OPEN_MODEL
    if not HasModelLoaded(dummyModel) then
      if not reqModel(dummyModel) then
        print(('Failed to load dummy model %s for gizmo editor.'):format(dummyModel))
        notify('Échec chargement modèle dummy.')
        editingGizmo = false
        return
      end
    end

    editingGizmo = true
    notify('Starting Gizmo Editor. Use mouse handles, Num+/- for size, ENTER to save.')

    -- Spawn dummy entity exactly at the current screen's position in world space
    dummyEnt = CreateObject(dummyModel, posWorld.x, posWorld.y, posWorld.z, true, true, false)
    SetEntityRotation(dummyEnt, monitorRot.x, monitorRot.y, monitorRot.z, 2, true)
    
    -- Crucial: disable collision and gravity, make invisible, do NOT freeze so matrix/coordinates updates run natively
    SetEntityCollision(dummyEnt, false, false)
    SetEntityHasGravity(dummyEnt, false)
    SetEntityVelocity(dummyEnt, 0.0, 0.0, 0.0)
    SetEntityVisible(dummyEnt, false, false)

    -- Temporarily destroy the monitor panel and attach it to the dummy entity at 0,0,0
    if panelId then
      pcall(function() exports['pop_duiengine']:DestroyPanel(panelId) end)
      panelId = nil
    end
    ensurePanelOnDummy(dummyEnt)

    -- Call object_gizmo to manipulate the dummy entity (blocking call).
    -- Wrap in pcall : si l'export useGizmo n'est pas enregistré (ox_lib
    -- absent au load, resource crashée, version incompatible), on ne crash
    -- pas le script — on nettoie et on tombe sur le fallback clavier.
    local ok, data = pcall(function()
      return exports.object_gizmo:useGizmo(dummyEnt)
    end)

    if not ok then
      print(('^1[lapedity] object_gizmo:useGizmo failed: %s^7'):format(tostring(data)))
      print('^3[lapedity] Vérifie : (1) `ensure object_gizmo` est dans server.cfg ; (2) ox_lib démarre AVANT object_gizmo ; (3) version object_gizmo récente.^7')
      notify('Gizmo HS — fallback clavier (voir F8).')

      editingGizmo = false

      if panelId then
        pcall(function() exports['pop_duiengine']:DestroyPanel(panelId) end)
        panelId = nil
      end
      safeDelete(dummyEnt)
      dummyEnt = nil

      if activeLaptop and DoesEntityExist(activeLaptop.openEnt) then
        ensurePanel(activeLaptop)
      end

      startKeyboardEditor()
      return
    end

    -- Done editing (ENTER was pressed)
    editingGizmo = false

    -- Read final position and rotation
    local finalPos = GetEntityCoords(dummyEnt)
    local finalRot = GetEntityRotation(dummyEnt, 2)

    -- Calculate relative offset from physical monitor to dummy position (which represents screen position)
    local relOffset = GetOffsetFromEntityGivenWorldCoords(monitorEnt, finalPos.x, finalPos.y, finalPos.z)

    -- Calculate relative orientation vectors (localNormal and localUp)
    local r1, f1, u1 = rotToAxes(monitorRot)
    local r2, f2, u2 = rotToAxes(finalRot)

    -- dummyNormal is the screen normal pointing out (negative forward vector of dummy Y)
    local dummyNormal = -f2
    local dummyUp = u2

    local relNormal = vector3(vDot(dummyNormal, r1), vDot(dummyNormal, f1), vDot(dummyNormal, u1))
    local relUp = vector3(vDot(dummyUp, r1), vDot(dummyUp, f1), vDot(dummyUp, u1))

    -- Save new values
    testOffset = relOffset
    testNormal = relNormal
    testUp = relUp

    -- Print result to F8 console
    print('----------------------------------------')
    print('GIZMO SCREEN TRANSFORMS:')
    print(string.format('offset = vector3(%.4f, %.4f, %.4f),', testOffset.x, testOffset.y, testOffset.z))
    print(string.format('localNormal = vector3(%.4f, %.4f, %.4f),', testNormal.x, testNormal.y, testNormal.z))
    print(string.format('localUp = vector3(%.4f, %.4f, %.4f),', testUp.x, testUp.y, testUp.z))
    print(string.format('width = %.4f,', testWidth))
    print(string.format('height = %.4f,', testHeight))
    print('----------------------------------------')

    notify('Layout saved! Coordinates printed to F8.')

    -- Cleanup
    if panelId then
      pcall(function() exports['pop_duiengine']:DestroyPanel(panelId) end)
      panelId = nil
    end

    safeDelete(dummyEnt)
    dummyEnt = nil

    -- Re-attach panel back to the monitor prop
    if activeLaptop and DoesEntityExist(activeLaptop.openEnt) then
      ensurePanel(activeLaptop)
    end
  else
    print('WARNING: object_gizmo resource is not started — using keyboard editor fallback.')
    notify('object_gizmo non démarré — fallback clavier.')
    startKeyboardEditor()
  end
end)

RegisterCommand('lapoffset', function(source, args)
  if not Config.DevMode then return end
  local x = tonumber(args[1]) or testOffset.x
  local y = tonumber(args[2]) or testOffset.y
  local z = tonumber(args[3]) or testOffset.z
  local w = tonumber(args[4]) or testWidth
  local h = tonumber(args[5]) or testHeight

  testOffset = vector3(x, y, z)
  testWidth = w
  testHeight = h

  print(('Offset adjusted: X=%.3f Y=%.3f Z=%.3f W=%.3f H=%.3f'):format(x, y, z, w, h))

  if focused and activeLaptop then
    -- Recreate panel with new values
    if ensurePanel(activeLaptop) then
      print('Panel updated successfully.')
    end
  end
end)

local testingPanel = false
RegisterCommand('laptest', function()
  if not Config.DevMode then return end
  testingPanel = not testingPanel
  if testingPanel then
    local ped = PlayerPedId()
    local pPos = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    
    -- Position it 1.5 meters in front of the player, elevated to eye/chest level (1.2 instead of 0.2)
    testPanelPos = pPos + (forward * 1.5) + vector3(0.0, 0.0, 1.2)
    testPanelNormal = -forward -- face the player
    
    local theme = (Config and Config.Style) or '2026'

    panelId = exports['pop_duiengine']:CreatePanel({
      url = ('nui://%s/html/index.html?lap=0&theme=%s'):format(GetCurrentResourceName(), theme),
      resW = duiResW,
      resH = duiResH,
      pos = testPanelPos,
      normal = testPanelNormal,
      -- Do NOT pass localUp/up so it uses the camera-aligned orientation lock (no upside-down flips)
      width = testWidth,
      height = testHeight,
    })

    notify('Test panel spawned. Focusing...')
    print('Test panel spawned at: ' .. tostring(testPanelPos))
    
    -- Focus input and zoom camera onto it
    Wait(200)
    beginFocus(nil, true)
  else
    if panelId then
      pcall(function() exports['pop_duiengine']:DestroyPanel(panelId) end)
      panelId = nil
    end
    focused = false
    stopLaptopCam()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    notify('Test panel removed.')
  end
end)



-- =============================
-- CAMERA FOCUS
-- =============================
local focusCam = nil

startLaptopCam = function(ent, isTestMode)
  if focusCam then return end

  -- camMode = 'none' → on ne crée AUCUNE caméra scriptée.
  -- Le joueur garde sa vue (FPV/TPV) et peut bouger la tête.
  -- Bypass uniquement en mode normal (le mode test panel garde
  -- toujours sa cam scriptée car le panel flotte en l'air).
  if not isTestMode then
    local _camKey  = (Config and Config.Style) or '2026'
    local _camTbl  = (Config and Config.CameraTransform and Config.CameraTransform[_camKey]) or {}
    local _camMode = _camTbl.camMode or 'scripted'
    if _camMode == 'none' then
      return
    end
  end

  -- =============================================================
  -- 2026 LAPTOP : code copié VERBATIM de pos/client.lua (snapshot
  -- avant le refacto du repère plan-écran). Le user veut exactement
  -- cette cam-là pour le prop_laptop_lester, donc on bypass toute
  -- la nouvelle pipeline Config.CameraTransform pour ce style. Le
  -- 80s continue de passer dans la nouvelle pipeline plus bas.
  -- Ne pas toucher sans demander.
  -- =============================================================
  if not isTestMode and Config.Style == '2026' then
    if not DoesEntityExist(ent) then return end

    local right, _, _, pos = GetEntityMatrix(ent)
    right = vNorm(right)

    local screenNormal = vNorm(vector3(-right.x, -right.y, -right.z)) * SCREEN_SIDE
    local camPos2026 = pos + (screenNormal * 0.48) + vector3(0.0, 0.0, 0.40)

    focusCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(focusCam, camPos2026.x, camPos2026.y, camPos2026.z)
    PointCamAtEntity(focusCam, ent, 0.0, 0.0, 0.15, true)
    SetCamFov(focusCam, 30.0)
    RenderScriptCams(true, true, 1000, true, true)
    return
  end

  local camPos, lookAtPos, fov
  -- Hoistés hors du if/else pour être lus après PointCamAtCoord.
  local camPitchOuter, camYawOuter, camRollOuter = 0.0, 0.0, 0.0

  if isTestMode then
    if not testPanelPos or not testPanelNormal then return end
    camPos = testPanelPos + (testPanelNormal * 0.55)
    lookAtPos = testPanelPos
    fov = 38.0
  else
    if not DoesEntityExist(ent) then return end

    -- Use the entity's TRUE screen face normal.
    -- GetEntityMatrix returns forwardVector as 1st value
    local forward, _, _, pos = GetEntityMatrix(ent)
    forward = vNorm(forward)

    local currentScreenSide = SCREEN_SIDE
    if Config.Style == '80s' then
      currentScreenSide = SCREEN_SIDE
    end

    local screenNormal = vNorm(vector3(-forward.x, -forward.y, -forward.z)) * currentScreenSide

    -- Repère de l'écran : N (normale sortante), R (droite), U (haut).
    -- R = N × worldUp (perpendiculaire à N et horizontal).
    -- U = R × N (haut "vrai" du plan de l'écran, tient compte de l'inclinaison).
    -- Si l'écran est presque vertical (cas normal), U ≈ worldUp.
    -- Si N est colinéaire à worldUp (écran horizontal au plafond/sol),
    -- on tombe sur un cas dégénéré → fallback sur l'axe X monde.
    local worldUp = vector3(0.0, 0.0, 1.0)
    local right = vCross(screenNormal, worldUp)
    if vLen(right) < 0.001 then
      right = vector3(1.0, 0.0, 0.0)
    else
      right = vNorm(right)
    end
    local up = vNorm(vCross(right, screenNormal))

    -- Lecture du Config.CameraTransform par style. Fallback hardcoded
    -- si la clé manque, pour ne pas crasher sur une vieille config.lua.
    local _camKey = (Config and Config.Style) or '2026'
    local _camTbl = (Config and Config.CameraTransform and Config.CameraTransform[_camKey]) or {}
    local _stTblCam = (Config and Config.ScreenTransform and Config.ScreenTransform[_camKey]) or {}

    -- camPos en LOCAL ENTITÉ (vector3). Fallback si absent.
    local camPosLocal = _camTbl.camPos or
      ((_camKey == '80s') and vector3(-0.45, 0.00, 0.25) or vector3(-0.48, 0.00, 0.40))

    -- lookAt en LOCAL ENTITÉ. Si nil → vise le centre de l'écran
    -- (= ScreenTransform.offset). Si même ça manque → vise l'entité.
    local lookAtLocal = _camTbl.lookAt or _stTblCam.offset or vector3(0.0, 0.0, 0.0)

    -- Ajustements additifs dans le plan de l'écran.
    local camOffsetRight   = _camTbl.camOffsetRight   or 0.00
    local camOffsetUp      = _camTbl.camOffsetUp      or 0.00
    local pointOffsetRight = _camTbl.pointOffsetRight or 0.00
    local pointOffsetUp    = _camTbl.pointOffsetUp    or 0.00
    camPitchOuter          = _camTbl.camPitch         or 0.00
    camYawOuter            = _camTbl.camYaw           or 0.00
    camRollOuter           = _camTbl.camRoll          or 0.00
    fov                    = _camTbl.fov              or ((_camKey == '80s') and 25.0 or 30.0)

    -- Position caméra : base local entité + ajustements plan-écran.
    -- GetOffsetFromEntityInWorldCoords convertit le local entité → monde.
    local camBaseWorld = GetOffsetFromEntityInWorldCoords(ent, camPosLocal.x, camPosLocal.y, camPosLocal.z)
    camPos = camBaseWorld
           + right * camOffsetRight
           + up    * camOffsetUp

    -- Point visé : base local entité + ajustements plan-écran.
    local lookBaseWorld = GetOffsetFromEntityInWorldCoords(ent, lookAtLocal.x, lookAtLocal.y, lookAtLocal.z)
    lookAtPos = lookBaseWorld
              + right * pointOffsetRight
              + up    * pointOffsetUp
  end

  focusCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
  SetCamCoord(focusCam, camPos.x, camPos.y, camPos.z)
  PointCamAtCoord(focusCam, lookAtPos.x, lookAtPos.y, lookAtPos.z)
  SetCamFov(focusCam, fov)

  -- Surcharges de rotation (additives sur la rotation calculée par
  -- PointCamAtCoord). Convention GTA : x=pitch, y=roll, z=yaw.
  -- Roll par défaut = 0 après PointCamAtCoord, donc additif ou
  -- absolu donnent le même résultat sur ce champ.
  if camPitchOuter ~= 0.0 or camYawOuter ~= 0.0 or camRollOuter ~= 0.0 then
    local rot = GetCamRot(focusCam, 2)
    SetCamRot(focusCam,
      rot.x + camPitchOuter,
      rot.y + camRollOuter,
      rot.z + camYawOuter,
      2
    )
  end

  RenderScriptCams(true, true, 1000, true, true)
end

stopLaptopCam = function()
  if focusCam then
    RenderScriptCams(false, true, 1000, true, true)
    DestroyCam(focusCam, false)
    focusCam = nil
  end
end

-- =============================
-- FOCUS / INPUT FORWARD
-- =============================
local function closeActive()
  -- Always end focus + teardown replace + swap model back to closed
  if focused then
    focused = false
    TriggerEvent('hud:toggleui', true)
  end

  if stopLaptopCam then stopLaptopCam() end
  focusThread = nil

  -- Release LMB if we had it down
  if Config.Style == '80s' then
    if panelId and lmbDown then
      pcall(function() exports['pop_duiengine']:SendMouseUp(panelId, 'left') end)
    end
  else
    if replaceId and lmbDown then
      pcall(function() exports['pop_duiengine']:SendReplaceMouseUp(replaceId, 0) end)
    end
  end
  lmbDown = false

  -- Restore controls/input
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)

  -- remove global replace mapping / panel
  if Config.Style == '80s' then
    if panelId then
      pcall(function() exports['pop_duiengine']:DestroyPanel(panelId) end)
      panelId = nil
    end
  else
    destroyReplace()
  end

  -- close active laptop model
  if activeLaptop then
    closeLaptop(activeLaptop)
    activeLaptop = nil
  end

  -- Empêche le menu pause de s'ouvrir avec le MÊME appui sur Échap qui ferme le laptop,
  -- quelle que soit l'origine de la fermeture (thread focus, callback NUI, etc.).
  CreateThread(function()
    local ticks = 25
    while ticks > 0 do
      ticks = ticks - 1
      DisableControlAction(0, 200, true) -- pause (alt / Échap)
      DisableControlAction(0, 199, true) -- pause
      DisableControlAction(0, 322, true) -- Échap
      Wait(0)
    end
    -- On garde laptopOpen actif pendant la fenêtre ci-dessus pour que le MÊME appui
    -- sur Échap (qui ferme le laptop) n'ouvre pas le menu pause juste après.
    LocalPlayer.state:set('laptopOpen', false, false)
  end)
end

beginFocus = function(entry, isTestMode)
  if focused then return end

  -- Signale aux autres ressources (ex: natal_pausemenu) que le laptop est ouvert,
  -- pour qu'elles n'ouvrent pas leur menu sur Échap.
  LocalPlayer.state:set('laptopOpen', true, false)

  if not isTestMode then
    if not entry or not DoesEntityExist(entry.openEnt) then
      print('Laptop is not open.')
      return
    end

    local ok = false
    if Config.Style == '80s' then
      ok = ensurePanel(entry)
    else
      ok = ensureReplace(entry)
    end

    if not ok then
      print('Failed to initialize DUI.')
      return
    end

    if not isPlayerOnScreenSide(entry.openEnt) then
      print('Stand on the screen side to use it.')
      return
    end
  end

  focused = true
  cursorX, cursorY = 0.5, 0.5
  lmbDown = false

  if not isTestMode then
    TriggerEvent('hud:toggleui', false)
  end

  if isTestMode then
    startLaptopCam(nil, true)
  else
    startLaptopCam(entry.openEnt)
  end

  -- We do NOT open any NUI overlay. We just forward input into the DUI.
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(true)

  if isTestMode then
    print('Floating test panel focused. ESC to exit.')
  else
    print('Laptop focused. ESC to exit (auto-closes).')
  end

  focusThread = CreateThread(function()
    local function isActive()
      if isTestMode then
        return focused and panelId and testingPanel
      end
      if Config.Style == '80s' then
        return focused and panelId and activeLaptop == entry
      else
        return focused and replaceId and activeLaptop == entry
      end
    end

    local initialPosWorld = nil
    if isTestMode then
      initialPosWorld = testPanelPos
    end

    while isActive() do
      Wait(0)

      -- hard block pause menu + most controls
      DisableAllControlActions(0)
      DisableAllControlActions(1)
      DisableAllControlActions(2)
      DisableControlAction(0, 200, true) -- pause
      DisableControlAction(0, 199, true)
      DisableControlAction(0, 322, true)

      -- ESC exits + closes
      if not keyboardOpen and (IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 177)) then
        if isTestMode then
          testingPanel = false
          pcall(function() exports['pop_duiengine']:DestroyPanel(panelId) end)
          panelId = nil
          focused = false
          stopLaptopCam()
          SetNuiFocus(false, false)
          SetNuiFocusKeepInput(false)
          notify('Test panel removed.')
          break
        else
          closeActive()
          -- Disable ESC for a few frames to prevent pause menu from popping up
          CreateThread(function()
              local ticks = 15
              while ticks > 0 do
                  Wait(0)
                  ticks = ticks - 1
                  DisableControlAction(0, 200, true)
                  DisableControlAction(0, 199, true)
                  DisableControlAction(0, 322, true)
              end
          end)
          break
        end
      end

      -- mouse delta -> virtual cursor
      local dx = GetDisabledControlNormal(0, 1)
      local dy = GetDisabledControlNormal(0, 2)

      if dx ~= 0.0 or dy ~= 0.0 then
        cursorX = clamp(cursorX + (dx * CURSOR_SENS), 0.0, 1.0)
        cursorY = clamp(cursorY + (dy * CURSOR_SENS), 0.0, 1.0)
        if isTestMode or Config.Style == '80s' then
          pcall(function() exports['pop_duiengine']:SendMouseMove(panelId, cursorX, cursorY) end)
        else
          pcall(function() exports['pop_duiengine']:SendReplaceMouseMove(replaceId, cursorX, cursorY) end)
        end
      end

      -- scroll with arrows (must go to DUI, not NUI page)
      if isTestMode or Config.Style == '80s' then
        if panelId then
          if IsDisabledControlPressed(0, 172) then -- Arrow Up
              exports['pop_duiengine']:SendMessage(panelId, { action = 'scroll', delta = -20 })
          elseif IsDisabledControlPressed(0, 173) then -- Arrow Down
              exports['pop_duiengine']:SendMessage(panelId, { action = 'scroll', delta = 20 })
          elseif IsDisabledControlPressed(0, 10) then -- Page Up
              exports['pop_duiengine']:SendMessage(panelId, { action = 'scroll', delta = -100 })
          elseif IsDisabledControlPressed(0, 11) then -- Page Down
              exports['pop_duiengine']:SendMessage(panelId, { action = 'scroll', delta = 100 })
          end
        end
      else
        if replaceId then
          if IsDisabledControlPressed(0, 172) then -- Arrow Up
              exports['pop_duiengine']:SendReplaceMessage(replaceId, { action = 'scroll', delta = -20 })
          elseif IsDisabledControlPressed(0, 173) then -- Arrow Down
              exports['pop_duiengine']:SendReplaceMessage(replaceId, { action = 'scroll', delta = 20 })
          elseif IsDisabledControlPressed(0, 10) then -- Page Up
              exports['pop_duiengine']:SendReplaceMessage(replaceId, { action = 'scroll', delta = -100 })
          elseif IsDisabledControlPressed(0, 11) then -- Page Down
              exports['pop_duiengine']:SendReplaceMessage(replaceId, { action = 'scroll', delta = 100 })
          end
        end
      end

      -- click
      if IsDisabledControlJustPressed(0, 24) then
        lmbDown = true
        if isTestMode or Config.Style == '80s' then
          pcall(function() exports['pop_duiengine']:SendMouseDown(panelId, 'left') end)
        else
          pcall(function() exports['pop_duiengine']:SendReplaceMouseDown(replaceId, 0) end)
        end
      elseif IsDisabledControlJustReleased(0, 24) then
        lmbDown = false
        if isTestMode or Config.Style == '80s' then
          pcall(function() exports['pop_duiengine']:SendMouseUp(panelId, 'left') end)
        else
          pcall(function() exports['pop_duiengine']:SendReplaceMouseUp(replaceId, 0) end)
        end
      end

      -- scroll (weapon wheel next/prev)
      if IsDisabledControlJustPressed(0, 15) then
        if isTestMode or Config.Style == '80s' then
          pcall(function() exports['pop_duiengine']:SendMouseWheel(panelId, -1) end)
          pcall(function() exports['pop_duiengine']:SendMessage(panelId, { action = 'scroll', delta = -100 }) end)
        else
          pcall(function() exports['pop_duiengine']:SendReplaceMouseWheel(replaceId, -1) end)
          pcall(function() exports['pop_duiengine']:SendReplaceMessage(replaceId, { action = 'scroll', delta = -100 }) end)
        end
      elseif IsDisabledControlJustPressed(0, 14) then
        if isTestMode or Config.Style == '80s' then
          pcall(function() exports['pop_duiengine']:SendMouseWheel(panelId, 1) end)
          pcall(function() exports['pop_duiengine']:SendMessage(panelId, { action = 'scroll', delta = 100 }) end)
        else
          pcall(function() exports['pop_duiengine']:SendReplaceMouseWheel(replaceId, 1) end)
          pcall(function() exports['pop_duiengine']:SendReplaceMessage(replaceId, { action = 'scroll', delta = 100 }) end)
        end
      end

      -- Check distance in test mode, or side in normal mode
      if not isTestMode then
        if not isPlayerOnScreenSide(entry.openEnt) then
          print('Moved behind the screen. Closing.')
          closeActive()
          break
        end
      else
        local pPed = PlayerPedId()
        if #(GetEntityCoords(pPed) - initialPosWorld) > 3.0 then
          testingPanel = false
          pcall(function() exports['pop_duiengine']:DestroyPanel(panelId) end)
          panelId = nil
          focused = false
          stopLaptopCam()
          SetNuiFocus(false, false)
          SetNuiFocusKeepInput(false)
          notify('Test panel removed (walked away).')
          break
        end
      end
    end
  end)
end

-- =============================
-- CONTROLS
-- =============================
CreateThread(function()
  while true do
    -- Sleep adaptatif : 500ms quand on est loin de tout laptop (coût idle quasi nul),
    -- 0 dès qu'on est à portée (prompt + touche E restent réactifs). Comportement identique.
    local sleep = 500

    -- If focused but active laptop got deleted, clean up
    if focused and not testingPanel and (not activeLaptop or not DoesEntityExist(activeLaptop.openEnt)) then
      closeActive()
    end

    if not focused then
      local ped = PlayerPedId()
      local p = GetEntityCoords(ped)

      -- If there is an active open laptop but we're not focused (shouldn't happen), close it.
      if activeLaptop and DoesEntityExist(activeLaptop.openEnt) then
        -- keep it simple: force-close
        closeActive()
      end

      -- Find nearest CLOSED laptop and allow E to open+focus
      local foundLaptop = false
      for _, entry in ipairs(laptops) do
        if entry and DoesEntityExist(entry.closedEnt) and IsEntityVisible(entry.closedEnt) then
          local e = GetEntityCoords(entry.closedEnt)
          if #(p - e) < 2.0 then
            foundLaptop = true
            sleep = 0 -- proche d'un laptop : boucle réactive

            -- Créer le prompt s'il n'existe pas
            -- Utilisation de pop_v3dui prompt ou ESX
            if Config.HelpNotificationType == 'esx' then
                ESX.ShowHelpNotification('Appuyez sur ~INPUT_CONTEXT~ pour gérer l\'organisation')
            else
                if not currentPromptId then
                     currentPromptId = exports['pop_v3dui']:Create({
                        coords = e + vector3(0, 0, 0.2),
                        type = "prompt",
                        content = {
                            key = "E",
                            label = "Gérer Organisation",
                            icon = Config.Style == '80s' and "fas fa-desktop" or "fas fa-laptop"
                        },
                        drawDistance = 5.0
                    })
                end
            end

            if IsControlJustPressed(0, 38) then
              -- close any existing open laptop first (single-open enforcement)
              if activeLaptop and activeLaptop ~= entry then
                closeActive()
              end

              -- open this one
              if openLaptop(entry) then
                activeLaptop = entry
                Wait(OPEN_FOCUS_DELAY_MS)
                beginFocus(entry)
              end
            end
            break
          end
        end
      end
      
      -- Nettoyage du prompt si on s'éloigne ou si le laptop n'est plus valide
      if not foundLaptop and currentPromptId then
          exports['pop_v3dui']:Remove(currentPromptId)
          currentPromptId = nil
      end
    else
      -- Si on est focus, s'assurer que le prompt est retiré
      if currentPromptId then
          exports['pop_v3dui']:Remove(currentPromptId)
          currentPromptId = nil
      end
    end

    Wait(sleep)
  end
end)

RegisterCommand('lapplace', function()
  if not Config.DevMode then return end
  placeClosed()
end)

RegisterCommand('lapnext', function()
  if not Config.DevMode then return end
  replaceIdx = replaceIdx + 1
  if replaceIdx > #REPLACE_CANDIDATES then replaceIdx = 1 end
  printCandidate()

  -- If currently open/focused, reapply replace (recreate mapping)
  if activeLaptop and DoesEntityExist(activeLaptop.openEnt) then
    destroyReplace()
    ensureReplace(activeLaptop)
  end
end)

RegisterCommand('lapside', function()
  if not Config.DevMode then return end
  SCREEN_SIDE = -SCREEN_SIDE
  print(('SCREEN_SIDE flipped: %d'):format(SCREEN_SIDE))
end)

RegisterCommand('lapclose', function()
  closeActive()
end)

-- =============================
-- KEY BINDINGS (contournent le chat — utiles quand DisableAllControlActions
-- est actif pendant le focus DUI, ou si le chat est désactivé sur le serveur).
-- Toutes rebindables par le joueur dans : Paramètres > Touches > FiveM.
-- =============================
-- Touches par défaut choisies pour ne pas entrer en conflit avec les autres scripts
-- (F5 emotes, F6 admin, F7 noclip, F10 police). Outils de placement : sans touche.
RegisterKeyMapping('lapedity',  'Editeur position écran DUI (laptop/PC)', 'KEYBOARD', '')
RegisterKeyMapping('lapclose',  'Fermer le laptop / PC', 'KEYBOARD', 'F3')
RegisterKeyMapping('lapplace',  'Placer un laptop / PC devant le joueur', 'KEYBOARD', '')
RegisterKeyMapping('lapnext',   'Cycle texture cible (debug)', 'KEYBOARD', '')
RegisterKeyMapping('lapside',   'Inverser le côté écran (debug)', 'KEYBOARD', '')
RegisterKeyMapping('lapcorners','Editeur 3D par 4 coins (snap)', 'KEYBOARD', '')

RegisterCommand('lapcorners', function()
  startCornerEditor()
end)

AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  closeActive()

  for _, entry in ipairs(laptops) do
    if entry then
      safeDelete(entry.openEnt)
      safeDelete(entry.closedEnt)
    end
  end
  laptops = {}
end)

-- Auto place from Config
CreateThread(function()
  Wait(1000) -- Attendre un peu que tout soit chargé
  if Config.Laptops and #Config.Laptops > 0 then
    for i, data in ipairs(Config.Laptops) do
       placeClosed(data.pos, data.heading)
    end
  else
    print('No laptops in Config.Laptops, placing one near player for dev/test.')
    placeClosed()
  end
end)

-- =============================
-- ESX INTEGRATION
-- =============================
ESX = nil

-- Méthode 1 : exports (ESX Legacy)
local success, result = pcall(function()
    return exports["es_extended"]:getSharedObject()
end)

if success and result then
    ESX = result
    print('^2[LAPTOP] ESX chargé via exports^0')
else
    -- Méthode 2 : TriggerEvent (ESX ancien)
    print('^3[LAPTOP] Tentative de chargement ESX via TriggerEvent...^0')
    CreateThread(function()
        while ESX == nil do
            TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
            Wait(100)
        end
        print('^2[LAPTOP] ESX chargé via TriggerEvent^0')
    end)
end

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
  ESX.PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
  ESX.PlayerData.job = job
end)

-- Callback NUI: Demander les données de la société
RegisterNUICallback('requestSocietyData', function(data, cb)
  -- On demande au serveur de nous envoyer les données de notre job actuel
  -- On ne se fie pas au cache client ESX qui peut être lent
  TriggerServerEvent('cr-laptop:getSocietyData')
  
  -- Attendre un peu pour que le serveur réponde et que storedLaptopData soit mis à jour
  local ClientWaitTime = 0
  while storedLaptopData == nil and ClientWaitTime < 40 do
      Citizen.Wait(50)
      ClientWaitTime = ClientWaitTime + 1
  end
  
  -- Renvoyer les données stockées
  if storedLaptopData then
    cb(storedLaptopData)
  else
    -- Si pas de réponse rapide, renvoyer des données vides temporaires
    -- Le polling suivant mettra à jour
    cb({
      action = 'updateSocietyData',
      societyData = {
        money = 0,
        employees = {},
        transactions = {},
        playerGrade = 0,
        playerGradeLabel = 'Chargement...',
        societyLabel = 'Chargement...'
      },
      societyName = 'loading'
    })
  end
end)

-- Callback NUI: Déposer de l'argent
RegisterNUICallback('depositMoney', function(data, cb)
  local playerData = ESX.GetPlayerData()
  if playerData.job and playerData.job.name then
    TriggerServerEvent('cr-laptop:depositMoney', playerData.job.name, data.amount)
  end
  cb('ok')
end)

-- Callback NUI: Retirer de l'argent
RegisterNUICallback('withdrawMoney', function(data, cb)
  local playerData = ESX.GetPlayerData()
  if playerData.job and playerData.job.name then
    TriggerServerEvent('cr-laptop:withdrawMoney', playerData.job.name, data.amount)
  end
  cb('ok')
end)

-- Callback NUI: Commander un chéquier d'entreprise (livré au patron via pop_inventory)
RegisterNUICallback('orderCompanyCheckbook', function(data, cb)
  local playerData = ESX.GetPlayerData()
  if playerData.job and playerData.job.name then
    TriggerServerEvent('pop_management:orderCompanyCheckbook', playerData.job.name)
  end
  cb('ok')
end)

-- Callback NUI: Payer un salaire
RegisterNUICallback('paySalary', function(data, cb)
  local playerData = ESX.GetPlayerData()
  if playerData.job and playerData.job.name then
    TriggerServerEvent('cr-laptop:paySalary', playerData.job.name, data.identifier, data.amount)
  end
  cb('ok')
end)

-- Callback NUI: Virer un employé
RegisterNUICallback('fireEmployee', function(data, cb)
  local playerData = ESX.GetPlayerData()
  if playerData.job and playerData.job.name then
    TriggerServerEvent('cr-laptop:fireEmployee', playerData.job.name, data.identifier)
  end
  cb('ok')
end)

-- Marqueur de chargement : si tu vois cette ligne en F8 client console
-- après /restart pop_management, le script Lua s'est bien parsé.
-- Si tu ne la vois PAS → erreur de syntaxe quelque part (cherche au-dessus).
print('^2[contract] script loaded — RegisterNUICallback generateEmployeeContract registered^7')

-- Callback NUI: Générer un contrat de travail (version minimale debug).
-- Strictement aligné sur le pattern fireEmployee qui marche chez toi.
-- Si CE callback ne répond pas non plus → c'est un souci de bridge/registration,
-- pas de logique. Si ça répond → on rajoute la logique progressivement.
RegisterNUICallback('generateEmployeeContract', function(data, cb)
  print('[contract] CALLBACK HIT')
  
  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local printerObject = GetClosestObjectOfType(coords.x, coords.y, coords.z, 3.0, GetHashKey('prop_printer_01'), false, false, false)

  if not DoesEntityExist(printerObject) then
    notify("Aucune imprimante posée à moins de 3 mètres !", {
      title = 'Imprimante',
      icon  = "fas fa-exclamation-triangle",
      duration = 5000
    })
    cb('error')
    return
  end

  -- /!\ Côté client FiveM, le module `os` est sandboxé (nil). On NE PEUT PAS
  -- utiliser os.date / os.time ici. La date arrive depuis le JS (data.date).
  -- ESX.GetPlayerData() en revanche fonctionne client-side.
  data = data or {}

  -- Champs employé.
  local firstname = data.firstname or ''
  local lastname  = data.lastname  or ''
  local fullName  = (firstname .. ' ' .. lastname):gsub('^%s+', ''):gsub('%s+$', '')
  if fullName == '' then fullName = 'Employé inconnu' end

  local gradeLabel = (data.gradeLabel ~= nil and data.gradeLabel ~= '') and data.gradeLabel
                     or ('Grade ' .. tostring(data.job_grade or 0))
  local jobGrade   = tostring(data.job_grade or 0)
  local society    = (data.societyLabel ~= nil and data.societyLabel ~= '') and data.societyLabel
                     or "l'entreprise"
  local date       = data.date or 'date inconnue'

  -- Nom du patron (signataire) = le joueur qui imprime.
  local playerData = ESX and ESX.GetPlayerData() or nil
  local bossName = 'Représentant légal'
  if playerData then
    local fn = (playerData.firstName or playerData.firstname or '')
    local ln = (playerData.lastName  or playerData.lastname  or '')
    local concat = (fn .. ' ' .. ln):gsub('^%s+', ''):gsub('%s+$', '')
    if concat ~= '' then bossName = concat end
  end

  -- Numéro de référence pseudo-officiel : hash modulo 1M de l'identifier +
  -- timer, formaté LSE-YYYY-XXXXXX. Déterministe par session, lisible.
  local refSeed = (data.identifier or 'XXX') .. tostring(GetGameTimer())
  local refHash = 0
  for i = 1, #refSeed do
    refHash = (refHash * 31 + string.byte(refSeed, i)) % 1000000
  end
  local year   = (#date >= 4) and date:sub(-4) or '0000'
  local refNum = string.format('LSE-%s-%06d', year, refHash)

  local contractText = string.format([[
===========================================
      REPUBLIQUE DE LOS SANTOS
   MINISTERE DU TRAVAIL ET DE L'EMPLOI
===========================================

         CONTRAT DE TRAVAIL
       A DUREE INDETERMINEE (CDI)

  Reference : %s
  Date      : %s

-------------------------------------------
       ENTRE LES SOUSSIGNES
-------------------------------------------

L'EMPLOYEUR :
  Raison sociale : %s
  Represente par : %s
  Qualite        : Dirigeant

ci-apres denomme " L'EMPLOYEUR ",
              D'UNE PART,

ET

L'EMPLOYE(E) :
  Nom complet  : %s
  Identifiant  : %s
  Poste        : %s
  Grade        : %s

ci-apres denomme " L'EMPLOYE ",
              D'AUTRE PART.

-------------------------------------------
    IL A ETE CONVENU CE QUI SUIT
-------------------------------------------

ARTICLE 1 — OBJET DU CONTRAT
Le present contrat a pour objet de definir
les conditions d'emploi de l'employe au sein
de la societe.

ARTICLE 2 — ENGAGEMENT
L'employe est engage en qualite de %s,
a compter du %s, pour une duree indeterminee.

ARTICLE 3 — PERIODE D'ESSAI
Une periode d'essai de quinze (15) jours est
prevue, renouvelable une fois par accord
mutuel des deux parties.

ARTICLE 4 — LIEU DE TRAVAIL
L'employe exercera ses fonctions au siege
social de la societe ou en tout autre lieu
defini par l'employeur dans le cadre du
service.

ARTICLE 5 — REMUNERATION
L'employe percevra un salaire conforme a la
grille des grades en vigueur, verse sur son
compte bancaire a intervalles reguliers.

ARTICLE 6 — DUREE DU TRAVAIL
La duree hebdomadaire de travail est definie
selon les besoins du service, dans le respect
de la legislation en vigueur sur le
territoire de Los Santos.

ARTICLE 7 — CONGES PAYES
L'employe beneficiera des conges payes selon
les dispositions legales applicables.

ARTICLE 8 — OBLIGATIONS DE L'EMPLOYE
L'employe s'engage a :
 - Executer consciencieusement ses fonctions
 - Respecter le reglement interieur
 - Faire preuve de loyaute envers l'entreprise
 - Respecter la confidentialite des informations

ARTICLE 9 — RESILIATION
Le present contrat peut etre resilie par
chacune des parties, dans le respect des
procedures legales en vigueur.

ARTICLE 10 — JURIDICTION COMPETENTE
En cas de litige relatif a l'execution ou a
l'interpretation du present contrat, les
parties s'engagent a saisir les tribunaux
competents de Los Santos.

-------------------------------------------

Fait a Los Santos, le %s,
en deux (2) exemplaires originaux,
chacune des parties reconnaissant en avoir
recu un exemplaire.


L'EMPLOYEUR :                L'EMPLOYE :

%s

%s

_______________              _______________
    Signature                    Signature


===========================================
  Document genere electroniquement
  Reference systeme : %s
  Certifie conforme par la Republique
  de Los Santos — Ministere du Travail
===========================================
]],
    refNum, date,
    society, bossName,
    fullName, data.identifier or '?', gradeLabel, jobGrade,
    gradeLabel, date,
    date,
    bossName, fullName,
    refNum
  )

  local title = 'Contrat de travail - ' .. fullName

  TriggerServerEvent('mt_printers:server:printDocument',
    'document', title, contractText, '', 0, 0
  )

  notify("Contrat de travail certifié envoyé à l'imprimante…", {
      title    = 'Imprimante',
      image    = NOTIF_IMG.print,
      duration = 5000,
  })
  cb('ok')
end)

-- Callback NUI: Changer le grade d'un employé
RegisterNUICallback('setGrade', function(data, cb)
  local playerData = ESX.GetPlayerData()
  if playerData.job and playerData.job.name then
    TriggerServerEvent('cr-laptop:setGrade', playerData.job.name, data.identifier, data.grade)
  end
  cb('ok')
end)

-- Callback NUI: Définir le matricule / code casier d'un employé (pop_inventory)
RegisterNUICallback('setEmployeeLocker', function(data, cb)
  local playerData = ESX.GetPlayerData()
  if playerData.job and playerData.job.name then
    TriggerServerEvent('cr-laptop:setEmployeeLocker', playerData.job.name, data.identifier, data.matricule, data.code)
  end
  cb('ok')
end)

-- Callback NUI: Obtenir le job du joueur
RegisterNUICallback('getPlayerJob', function(data, cb)
    local playerData = ESX.GetPlayerData()
    if playerData and playerData.job then
         cb({job = playerData.job.name})
    else
         cb({job = 'unknown'})
    end
end)

-- Callback NUI: Acheter un véhicule
RegisterNUICallback('buyVehicle', function(data, cb)
    TriggerServerEvent('pop_management:buyVehicle', data)
    cb('ok')
end)

-- Callback NUI: Acheter un item YouTool B2B (achat individuel — conservé pour compatibilité)
RegisterNUICallback('buyYouToolItem', function(data, cb)
    local pCoords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('pop_management:buyYouToolItem', data.model, data.label, data.quantity, data.price, { x = pCoords.x, y = pCoords.y, z = pCoords.z })
    cb('ok')
end)

-- Callback NUI: Commander le panier YouTool B2B (commande groupée)
RegisterNUICallback('buyYouToolCart', function(data, cb)
    local items = data and data.items
    if not items or type(items) ~= 'table' or #items == 0 then
        cb({ ok = false, reason = 'Panier vide ou données invalides.' })
        return
    end
    local pCoords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('pop_management:buyYouToolCart', items, { x = pCoords.x, y = pCoords.y, z = pCoords.z })
    cb({ ok = true })
end)

-- Callback NUI (app job YouTool) : liste des commandes à traiter (véhicules + colis)
RegisterNUICallback('getYTJobOrders', function(data, cb)
    ESX.TriggerServerCallback('pop_management:getYouToolJobOrders', function(orders)
        cb(orders or {})
    end)
end)

-- Callback NUI (app job YouTool) : valider une commande (pending -> ready)
RegisterNUICallback('validateYTOrder', function(data, cb)
    TriggerServerEvent('pop_management:validateYouToolOrder', data.type, data.id)
    cb('ok')
end)

-- Callback NUI: Fermer le laptop
RegisterNUICallback('closeLaptop', function(data, cb)
  closeActive()
  cb('ok')
end)

-- Callback NUI: Recherche de joueurs pour suggestions (Dynasty 8)
RegisterNUICallback('getPlayersForSuggestion', function(data, cb)
    ESX.TriggerServerCallback('pop_management:getPlayersForSuggestion', function(players)
        cb(players)
    end, data.search)
end)

RegisterNUICallback('setD8Tenant', function(data, cb)
    TriggerServerEvent('pop_management:setD8Tenant', data)
    cb('ok')
end)

-- IMPORTANT: l'UI tourne en DUI (ReplaceTexture), pas en NUI page.
-- SendNUIMessage cible la ui_page (input.html, vide) -> n'arrive jamais à app.js.
-- On doit utiliser pop_duiengine:SendReplaceMessage(replaceId, ...) qui appelle SendDuiMessage.
local function sendToDui(tbl)
    if Config.Style == '80s' then
        if not panelId then return false end
        local ok, err = pcall(function()
            exports['pop_duiengine']:SendMessage(panelId, tbl)
        end)
        if not ok then
            print(('[pop_management] SendMessage failed: %s'):format(tostring(err)))
        end
        return ok
    else
        if not replaceId then return false end
        local ok, err = pcall(function()
            exports['pop_duiengine']:SendReplaceMessage(replaceId, tbl)
        end)
        if not ok then
            print(('[pop_management] SendReplaceMessage failed: %s'):format(tostring(err)))
        end
        return ok
    end
end

RegisterNUICallback('openKeyboard', function(data, cb)
    if keyboardOpen then
        cb({ ok = false, reason = 'busy' })
        return
    end

    data = data or {}
    local title       = data.title and tostring(data.title) or 'Saisie'
    local defaultText = data.defaultValue and tostring(data.defaultValue) or ''
    local maxLength   = tonumber(data.maxLength) or 60
    if maxLength < 1 then maxLength = 1 end
    if maxLength > 254 then maxLength = 254 end
    local fieldId   = data.fieldId
    local requestId = data.requestId
    local legacyPropId = data.propId -- backward compat: existing D8 caller

    keyboardOpen = true

    -- Register a dynamic GXT entry so the native keyboard shows our title text instead of "FMMC_MPM_NA"
    AddTextEntry('TAB_MGMT_KBD_TITLE', title)
    DisplayOnscreenKeyboard(1, 'TAB_MGMT_KBD_TITLE', '', defaultText, '', '', '', maxLength)

    CreateThread(function()
        local status = UpdateOnscreenKeyboard()
        while status == 0 do
            Wait(0)
            status = UpdateOnscreenKeyboard()
        end

        keyboardOpen = false

        -- status: 1 = done, 2 = cancelled, 3 = invalid initial
        if status == 1 then
            local result = GetOnscreenKeyboardResult() or ''
            if requestId or fieldId then
                sendToDui({
                    action    = 'keyboardResult',
                    requestId = requestId,
                    fieldId   = fieldId,
                    value     = result,
                    cancelled = false,
                })
            else
                -- Legacy shape (used by existing Dynasty 8 search handler)
                sendToDui({
                    action = 'keyboardResult',
                    propId = legacyPropId,
                    value  = result,
                })
            end
        elseif (requestId or fieldId) and status == 2 then
            sendToDui({
                action    = 'keyboardResult',
                requestId = requestId,
                fieldId   = fieldId,
                value     = nil,
                cancelled = true,
            })
        end
    end)

    cb('ok')
end)

RegisterNUICallback('setFocus', function(data, cb)
    SetNuiFocus(data.status, data.status)
    cb('ok')
end)

-- =============================
-- GOUV (ADMINISTRATION BC)
-- =============================
RegisterNUICallback('requestGouvData', function(data, cb)
    TriggerServerEvent('pop_management:requestGouvData')
    
    local ClientWaitTime = 0
    while storedGouvData == nil and ClientWaitTime < 40 do
        Citizen.Wait(50)
        ClientWaitTime = ClientWaitTime + 1
    end
    
    if storedGouvData then
        cb(storedGouvData)
    else
        cb({
            action = 'updateGouvData',
            gouvData = {
                money = 0,
                employees = {},
                vehicles = {},
                playerGradeLabel = 'Chargement...',
                isBoss = false
            }
        })
    end
end)

RegisterNUICallback('changeTva', function(data, cb)
    TriggerServerEvent('pop_management:changeTva', data.tva)
    cb('ok')
end)

RegisterNUICallback('grantSubsidy', function(data, cb)
    TriggerServerEvent('pop_management:grantSubsidy', data.requestId)
    cb('ok')
end)

RegisterNUICallback('refuseSubsidy', function(data, cb)
    TriggerServerEvent('pop_management:refuseSubsidy', data.requestId)
    cb('ok')
end)

RegisterNUICallback('createAndGrantSubsidy', function(data, cb)
    TriggerServerEvent('pop_management:createAndGrantSubsidy', data)
    cb('ok')
end)

RegisterNUICallback('createWorkContract', function(data, cb)
    TriggerServerEvent('pop_management:createWorkContract', data)
    cb('ok')
end)

RegisterNUICallback('publishGouvNews', function(data, cb)
    TriggerServerEvent('pop_management:publishGouvNews', data)
    cb('ok')
end)

RegisterNUICallback('scheduleCouncil', function(data, cb)
    TriggerServerEvent('pop_management:scheduleCouncil')
    cb('ok')
end)

RegisterNUICallback('startCouncil', function(data, cb)
    TriggerServerEvent('pop_management:startCouncil')
    cb('ok')
end)

RegisterNUICallback('pauseCouncil', function(data, cb)
    TriggerServerEvent('pop_management:pauseCouncil')
    cb('ok')
end)

RegisterNUICallback('endCouncil', function(data, cb)
    TriggerServerEvent('pop_management:endCouncil')
    cb('ok')
end)

-- Variable globale pour stocker les données GOUV
storedGouvData = nil

RegisterNetEvent('pop_management:receiveGouvData')
AddEventHandler('pop_management:receiveGouvData', function(gouvData)
    storedGouvData = {
        action = 'updateGouvData',
        gouvData = gouvData
    }
end)


-- Variable globale pour stocker les données
storedLaptopData = nil

-- Recevoir les données de la société depuis le serveur
RegisterNetEvent('cr-laptop:receiveSocietyData')
AddEventHandler('cr-laptop:receiveSocietyData', function(societyData)
  print('[LAPTOP CLIENT] Données reçues du serveur!')
  print('[LAPTOP CLIENT] Argent:', societyData.money)
  print('[LAPTOP CLIENT] Nombre d\'employés:', #societyData.employees)
  
  -- Résoudre les hashs de modèles de véhicules
  if societyData.vehicles then
      for _, v in ipairs(societyData.vehicles) do
          if type(v.model) == 'number' then
              local modelName = GetDisplayNameFromVehicleModel(v.model)
              -- Essayer d'avoir le label (ex: "Police Cruiser") sinon le nom technique (ex: "POLICE")
              -- Mais pour la config JS, on veut souvent le nom technique en minuscule ("police").
              -- GetDisplayNameFromVehicleModel renvoie "POLICE".
              if modelName and modelName ~= "CARNOTFOUND" then
                  v.model = string.lower(modelName)
              else
                  v.model = tostring(v.model) -- Fallback string
              end
          end
      end
  end
  
  -- Utiliser le societyName envoyé par le serveur (fresh via xPlayer.getJob)
  -- plutot que le cache client ESX.PlayerData.job.name qui peut etre stale apres setJob.
  local resolvedSocietyName = societyData.societyName
  if not resolvedSocietyName or resolvedSocietyName == '' then
    local playerData = ESX.GetPlayerData()
    resolvedSocietyName = playerData and playerData.job and playerData.job.name or 'unknown'
  end

  storedLaptopData = {
    action = 'updateSocietyData',
    societyData = societyData,
    societyName = resolvedSocietyName
  }

  print('[LAPTOP CLIENT] Données stockées pour le prochain callback NUI (society=' .. tostring(resolvedSocietyName) .. ')')
end)

-- Notification
RegisterNetEvent('cr-laptop:notify')
AddEventHandler('cr-laptop:notify', function(msg)
    msg = stripGtaColors(msg)
    if Config.NotificationType == 'esx' then
        ESX.ShowNotification(msg)
    else
        exports["pop_notify"]:ShowNotify({
            title    = "Laptop",
            message  = msg,
            image    = NOTIF_IMG.laptop,
            duration = 4500,
        })
    end
end)

RegisterNetEvent('cr-laptop:notifyLogo')
AddEventHandler('cr-laptop:notifyLogo', function(data)
    if Config.NotificationType == 'esx' then
        ESX.ShowNotification(data.message)
    else
        exports["pop_notify"]:ShowNotify(data)
    end
end)
RegisterNetEvent('cr-laptop:forceUpdate')
AddEventHandler('cr-laptop:forceUpdate', function()
  print('[LAPTOP CLIENT] Mise à jour forcée demandée par le serveur')
  TriggerServerEvent('cr-laptop:getSocietyData')
end)

-- Creation des blips (TOUS les blips statiques du serveur — cf. Config.Blips)
CreateThread(function()
    if Config.Blips then
        for _, info in pairs(Config.Blips) do
            info.blip = AddBlipForCoord(info.coords.x, info.coords.y, info.coords.z)
            SetBlipSprite(info.blip, info.id or 1)
            SetBlipDisplay(info.blip, 4)
            SetBlipScale(info.blip, info.scale or Config.DefaultBlipScale or 0.9)
            SetBlipColour(info.blip, info.colour or info.color or 0)
            SetBlipAsShortRange(info.blip, info.shortRange ~= false)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(info.title or "")
            EndTextCommandSetBlipName(info.blip)
        end
    end

    if Config.Territories then
        for _, zone in pairs(Config.Territories) do
            for _, area in ipairs(zone.areas) do
                -- Créer la zone (carré)
                local areaBlip = AddBlipForArea(area.coords.x, area.coords.y, area.coords.z, area.width, area.height)
                SetBlipRotation(areaBlip, math.ceil(area.heading))
                SetBlipColour(areaBlip, zone.color)
                SetBlipAlpha(areaBlip, zone.alpha or 128)
                
                -- Créer le blip avec le texte centré sur la zone
                local textBlip = AddBlipForCoord(area.coords.x, area.coords.y, area.coords.z)
                SetBlipSprite(textBlip, 119) -- Transparent marker ou point
                SetBlipColour(textBlip, zone.color)
                SetBlipScale(textBlip, 0.0) -- Rendre l'icône invisible
                SetBlipAsShortRange(textBlip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(zone.title)
                EndTextCommandSetBlipName(textBlip)
            end
        end
    end
end)


-- =============================
-- SYSTÈME DE LIVRAISON (PORT)
-- =============================
local portPed = nil

CreateThread(function()
    if not Config.EnableDeliverySystem then return end
    
    -- Spawn PNJ
    local pedModel = Config.Port.Ped.model
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do Wait(10) end
    
    if not portPed then
        portPed = CreatePed(4, pedModel, Config.Port.Ped.coords, false, false)
        SetEntityHeading(portPed, Config.Port.Ped.coords.w)
        FreezeEntityPosition(portPed, true)
        SetEntityInvincible(portPed, true)
        SetBlockingOfNonTemporaryEvents(portPed, true)
    end
    


    -- Interaction
    local portPromptId = nil
    local employeePromptId = nil
    local portPos = vector3(Config.Port.Ped.coords.x, Config.Port.Ped.coords.y, Config.Port.Ped.coords.z)

    while true do
        local sleep = 1000

        if portPed and DoesEntityExist(portPed) then
            local pCoords = GetEntityCoords(PlayerPedId())
            local dist = #(pCoords - portPos)

            if dist < 5.0 then
                sleep = 250
                if dist < 2.5 then
                    sleep = 0
                    local pJob = ESX.GetPlayerData().job
                    local isYouTool = (pJob and pJob.name == (Config.YouToolJob or 'youtool'))
                    
                    if Config.HelpNotificationType == 'esx' then
                        if isYouTool then
                            ESX.ShowHelpNotification('Appuyez sur ~INPUT_CONTEXT~ pour réceptionner votre commande\nAppuyez sur ~INPUT_DETONATE~ (G) pour préparer toutes les commandes clients')
                        else
                            ESX.ShowHelpNotification('Appuyez sur ~INPUT_CONTEXT~ pour réceptionner votre commande')
                        end
                    else
                        if not portPromptId then
                             portPromptId = exports['pop_v3dui']:Create({
                                coords = vector3(Config.Port.Ped.coords.x, Config.Port.Ped.coords.y, Config.Port.Ped.coords.z + 1.9),
                                type = "prompt",
                                content = {
                                    key = "E",
                                    label = "Réceptionner ma commande",
                                    icon = "fas fa-box-open"
                                },
                                drawDistance = 5.0
                            })
                        end
                        if isYouTool and not employeePromptId then
                            employeePromptId = exports['pop_v3dui']:Create({
                                coords = vector3(Config.Port.Ped.coords.x, Config.Port.Ped.coords.y, Config.Port.Ped.coords.z + 1.7),
                                type = "prompt",
                                content = {
                                    key = "G",
                                    label = "Préparer les commandes GoPostal",
                                    icon = "fas fa-truck-fast"
                                },
                                drawDistance = 5.0
                            })
                        end
                        if not isYouTool and employeePromptId then
                            exports['pop_v3dui']:Remove(employeePromptId)
                            employeePromptId = nil
                        end
                    end

                    if IsControlJustPressed(0, 38) then
                        -- Retrait au Port : véhicules ET colis prêts du client (commettant)
                        TriggerServerEvent('pop_management:portPickup')
                        Wait(500)
                    elseif isYouTool and IsControlJustPressed(0, 47) then -- Touche G
                        PlayEmployeeCameraSequence()
                        Wait(500)
                    end
                else
                    if portPromptId then
                        exports['pop_v3dui']:Remove(portPromptId)
                        portPromptId = nil
                    end
                    if employeePromptId then
                        exports['pop_v3dui']:Remove(employeePromptId)
                        employeePromptId = nil
                    end
                end
            else
                 if portPromptId then
                    exports['pop_v3dui']:Remove(portPromptId)
                    portPromptId = nil
                end
                if employeePromptId then
                    exports['pop_v3dui']:Remove(employeePromptId)
                    employeePromptId = nil
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('pop_management:openClaimMenu')
AddEventHandler('pop_management:openClaimMenu', function(orders)
    if not orders or #orders == 0 then
        notify('Aucune commande prête à récupérer.')
        return
    end

    local elements = {}
    for _, order in ipairs(orders) do
        table.insert(elements, {
            label = order.vehicle_model .. ' - ' .. order.vehicle_color,
            value = order.id
        })
    end

    -- S'assurer que le menu UI est dispo, sinon fallback
    if ESX.UI and ESX.UI.Menu then
        ESX.UI.Menu.CloseAll()
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'claim_vehicle', {
            title = 'Véhicules Arrivés',
            align = 'top-left',
            elements = elements
        }, function(data, menu)
            menu.close()
            TriggerServerEvent('pop_management:claimVehicle', data.current.value)
        end, function(data, menu)
            menu.close()
        end)
    else
        print('ESX Menu non disponible')
    end
end)

local clientPickupCartons = {}
local cameraActive = false

local function DrawText3DSequence(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

local function PlayYouToolCameraSequence(packages)
    if cameraActive then return end
    cameraActive = true

    local cfg = Config.YouToolShelf
    if not cfg or not cfg.enabled then 
        for _, order in ipairs(packages) do
            TriggerServerEvent('pop_management:claimYouToolOrder', order.id)
        end
        cameraActive = false
        return 
    end

    for _, obj in pairs(clientPickupCartons) do
        if DoesEntityExist(obj) then 
            if GetResourceState('ox_target') == 'started' then
                exports.ox_target:removeLocalEntity(obj)
            end
            DeleteEntity(obj) 
        end
    end
    clientPickupCartons = {}

    local myShelfObj = GetClosestObjectOfType(cfg.coords.x, cfg.coords.y, cfg.coords.z, 2.0, cfg.model, false, false, false)
    if not myShelfObj or not DoesEntityExist(myShelfObj) then 
        for _, order in ipairs(packages) do
            TriggerServerEvent('pop_management:claimYouToolOrder', order.id)
        end
        cameraActive = false
        return 
    end

    local slots = cfg.cartons and cfg.cartons.list or {}
    local model = cfg.cartons and cfg.cartons.model or GetHashKey('prop_cs_cardbox_01')
    
    CreateThread(function()
        RequestModel(model)
        local timer = 0
        while not HasModelLoaded(model) and timer < 200 do 
            Wait(10)
            timer = timer + 1
        end

        for i, order in ipairs(packages) do
            local slotIndex = ((i - 1) % math.max(#slots, 1)) + 1
            local off = slots[slotIndex]
            if off then
                local box = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
                AttachEntityToEntity(box, myShelfObj, 0, off.x, off.y, off.z, 0.0, 0.0, off.w or 0.0, false, false, true, false, 2, true)
                SetEntityCollision(box, true, true)
                
                if GetResourceState('ox_target') == 'started' then
                    exports.ox_target:addLocalEntity(box, {
                        {
                            name = 'pickup_client_order_' .. order.id,
                            icon = 'fas fa-box-open',
                            label = 'Récupérer ma commande',
                            onSelect = function()
                                TriggerServerEvent('pop_management:claimYouToolOrder', order.id)
                                exports.ox_target:removeLocalEntity(box)
                                DeleteEntity(box)
                                clientPickupCartons[order.id] = nil
                                
                                RequestAnimDict('anim@heists@box_carry@')
                                local animTimer = 0
                                while not HasAnimDictLoaded('anim@heists@box_carry@') and animTimer < 100 do Wait(10) animTimer = animTimer + 1 end
                                TaskPlayAnim(PlayerPedId(), 'anim@heists@box_carry@', 'idle', 8.0, -8.0, 1500, 49, 0, false, false, false)
                            end
                        }
                    })
                end
                clientPickupCartons[order.id] = box
            end
        end

        local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        if cfg.camera then
            SetCamCoord(cam, cfg.camera.coords.x, cfg.camera.coords.y, cfg.camera.coords.z)
            SetCamRot(cam, cfg.camera.rot.x, cfg.camera.rot.y, cfg.camera.rot.z, 2)
            SetCamFov(cam, cfg.camera.fov or 74.0)
        else
            local camFwd = GetEntityForwardVector(myShelfObj)
            local camPos = cfg.coords.xyz + vector3(0.0, 0.0, 1.2) + camFwd * 1.8
            SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
            PointCamAtEntity(cam, myShelfObj, 0.0, 0.0, 0.0, true)
        end
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 1000, true, false)
        
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 5000 do
            Wait(0)
            local labels = {}
            for id, box in pairs(clientPickupCartons) do
                if DoesEntityExist(box) then
                    local bc = GetEntityCoords(box)
                    local onScreen, sx, sy = World3dToScreen2d(bc.x, bc.y, bc.z + 0.15)
                    if onScreen then
                        table.insert(labels, { id = id, onScreen = true, x = sx, y = sy })
                    end
                end
            end
            SendNUIMessage({ action = 'ytDraw3DLabels', labels = labels })
        end
        
        SendNUIMessage({ action = 'ytDraw3DLabels', labels = {} })
        RenderScriptCams(false, true, 1000, true, false)
        DestroyCam(cam, false)
        cameraActive = false
        notify("Allez récupérer votre commande sur l'étagère !")
    end)
end

function PlayEmployeeCameraSequence()
    if cameraActive then return end
    cameraActive = true

    local cfg = Config.YouToolShelf
    if not cfg or not cfg.enabled then 
        cameraActive = false
        return 
    end

    local myShelfObj = GetClosestObjectOfType(cfg.coords.x, cfg.coords.y, cfg.coords.z, 2.0, cfg.model, false, false, false)
    if not myShelfObj or not DoesEntityExist(myShelfObj) then 
        cameraActive = false
        return 
    end

    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    if cfg.camera then
        SetCamCoord(cam, cfg.camera.coords.x, cfg.camera.coords.y, cfg.camera.coords.z)
        SetCamRot(cam, cfg.camera.rot.x, cfg.camera.rot.y, cfg.camera.rot.z, 2)
        SetCamFov(cam, cfg.camera.fov or 74.0)
    else
        local camFwd = GetEntityForwardVector(myShelfObj)
        local camPos = cfg.coords.xyz + vector3(0.0, 0.0, 1.2) + camFwd * 1.8
        SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
        PointCamAtEntity(cam, myShelfObj, 0.0, 0.0, 0.0, true)
    end
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 1000, true, false)
    
    local startTime = GetGameTimer()
    CreateThread(function()
        while GetGameTimer() - startTime < 5000 do
            Wait(0)
            local labels = {}
            for id, box in pairs(orderCartons) do
                if DoesEntityExist(box) then
                    local bc = GetEntityCoords(box)
                    local onScreen, sx, sy = World3dToScreen2d(bc.x, bc.y, bc.z + 0.15)
                    if onScreen then
                        table.insert(labels, { id = id, onScreen = true, x = sx, y = sy })
                    end
                end
            end
            SendNUIMessage({ action = 'ytDraw3DLabels', labels = labels })
        end

        SendNUIMessage({ action = 'ytDraw3DLabels', labels = {} })
        RenderScriptCams(false, true, 1000, true, false)
        DestroyCam(cam, false)
        cameraActive = false
        
        notify("Allez préparer les commandes sur l'étagère !")
    end)
end

-- Retrait au Port : véhicules + colis prêts du client (commettant).
-- Pas de menu ESX (esx_menu absent sur ce serveur) -> récupération directe :
-- on prend tous les colis d'un coup, et on sort un véhicule par appui (évite les
-- collisions au point de spawn).
RegisterNetEvent('pop_management:openPortMenu')
AddEventHandler('pop_management:openPortMenu', function(vehicles, packages, hasPending)
    vehicles = vehicles or {}
    packages = packages or {}

    if #vehicles == 0 and #packages == 0 then
        if hasPending then
            notify('Votre commande est en cours de préparation par GoPostal.')
        else
            notify('Aucune commande prête à récupérer.')
        end
        return
    end

    -- Colis : séquence caméra et pose sur l'étagère (retrait manuel via ox_target)
    if #packages > 0 then
        PlayYouToolCameraSequence(packages)
    end

    -- Véhicules : on sort le premier prêt ; réappuyer sur E sortira le suivant
    if #vehicles > 0 then
        TriggerServerEvent('pop_management:claimVehicle', vehicles[1].id)
        if #vehicles > 1 then
            notify(('%d autre(s) véhicule(s) à récupérer — réappuyez sur E.'):format(#vehicles - 1))
        end
    end
end)

RegisterNetEvent('pop_management:spawnClaimedVehicle')
AddEventHandler('pop_management:spawnClaimedVehicle', function(model, color, society)
    local spawnPoint = Config.Port.SpawnPoint
    ESX.Game.SpawnVehicle(model, spawnPoint, spawnPoint.w, function(vehicle)
        if DoesEntityExist(vehicle) then
            -- Générer une plaque aléatoire (3 Lettres 3 Chiffres)
            local function GenerateRandomPlate()
                local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                local plate = ""
                for i = 1, 8 do
                    local rand = math.random(1, #charset)
                    plate = plate .. string.sub(charset, rand, rand)
                end
                return plate
            end
            
            SetVehicleNumberPlateText(vehicle, GenerateRandomPlate())
            local plate = GetVehicleNumberPlateText(vehicle)

            -- Appliquer couleur (basique - mapping simple ou ID direct)
            local colorId = tonumber(color)
            
            if not colorId then
                local colorMap = {
                    black = 0, white = 111, grey = 4, silver = 1,
                    red = 27, blue = 64, green = 50, yellow = 88,
                    orange = 38, pink = 135, purple = 145, brown = 105, matteblack = 12
                }
                if color and colorMap[color] then
                    colorId = colorMap[color]
                end
            end
            
            if colorId then
                SetVehicleColours(vehicle, colorId, colorId)
            else
                SetVehicleColours(vehicle, 0, 0) -- Noir par défaut
            end
            
            TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)

            -- Enregistrer le véhicule en BDD pour persistence (owned_vehicles)
            local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
            TriggerServerEvent('pop_management:registerVehicle', plate, model, society, vehicleProps)

            -- Demander la clé au serveur (pop_inventory) après l'enregistrement de la plaque
            TriggerServerEvent('pop_management:giveVehicleKey', plate)
            
            notify('Véhicule sorti. Plaque : <b>' .. plate .. '</b>', {
                title    = 'Concessionnaire',
                image    = NOTIF_IMG.car,
                duration = 6000,
            })
        end
    end)
end)

-- Cleanup PNJ
-- =============================================
-- ÉTAGÈRE DE RÉCEPTION YOUTOOL (Port) + CARTONS
-- =============================================
local function clearShelfCartons()
    for _, obj in ipairs(shelfCartons) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    shelfCartons = {}
end

local function clearOrderCartons()
    for _, ent in pairs(orderCartons) do
        if ent and DoesEntityExist(ent) then
            if GetResourceState('ox_target') == 'started' then
                exports.ox_target:removeLocalEntity(ent)
            end
            DeleteEntity(ent)
        end
    end
    orderCartons = {}
end

local function clearShelf()
    clearShelfCartons()
    clearOrderCartons()
    if shelfObj and DoesEntityExist(shelfObj) then DeleteEntity(shelfObj) end
    shelfObj = nil
end

-- (re)place l'étagère depuis la config et repose les cartons enregistrés.
local function spawnShelf()
    local cfg = Config.YouToolShelf
    if not cfg or not cfg.enabled then return end

    clearShelf()

    local c = cfg.coords
    if not reqModel(cfg.model) then
        print('[pop_management] Modèle étagère introuvable: ' .. tostring(cfg.model))
        return
    end
    -- Spawn à l'origine = coords EXACTES. Pas de calcul de pivot (le pivot de
    -- v_med_cor_shelfrack n'est pas à sa base) : c'est /ytshelf (gizmo) qui sert
    -- à positionner l'étagère visuellement, les coords dumpées sont alors pile
    -- où elle apparaît -> WYSIWYG, rien à deviner.
    shelfObj = CreateObject(cfg.model, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(shelfObj, c.w)
    FreezeEntityPosition(shelfObj, true)
    SetEntityAsMissionEntity(shelfObj, true, true)
    SetModelAsNoLongerNeeded(cfg.model)

    -- Étagère VIDE par défaut. Les cartons n'apparaissent que pour les commandes
    -- colis en attente (voir thread "cartons de commande" plus bas).
end

CreateThread(function()
    Wait(1000)
    spawnShelf()
end)

-- =============================================
-- COMMANDE DEV : placer l'étagère au GIZMO (souris) + dump des coords
-- -------------------------------------------------------------
-- Déplace/pivote l'étagère avec object_gizmo, ENTRÉE valide. Les coords
-- dumpées (F8) correspondent pile à où l'étagère apparaît -> à coller dans
-- Config.YouToolShelf.coords. WYSIWYG, aucun calcul de pivot.
-- =============================================
local shelfEditing = false

RegisterCommand('ytshelf', function()
    if shelfEditing then return end
    if GetResourceState('object_gizmo') ~= 'started' then
        notify("object_gizmo non démarré (ensure object_gizmo).")
        return
    end
    if not shelfObj or not DoesEntityExist(shelfObj) then
        spawnShelf()
    end
    if not shelfObj or not DoesEntityExist(shelfObj) then
        notify("Aucune étagère (Config.YouToolShelf.enabled = false ?).")
        return
    end

    shelfEditing = true
    CreateThread(function()
        FreezeEntityPosition(shelfObj, false) -- le gizmo a besoin de bouger l'entité
        local ok = pcall(function() return exports.object_gizmo:useGizmo(shelfObj) end)
        FreezeEntityPosition(shelfObj, true)
        shelfEditing = false
        if not ok then notify('Gizmo HS — voir F8.'); return end

        local co = GetEntityCoords(shelfObj)
        local h  = GetEntityHeading(shelfObj)
        Config.YouToolShelf.coords = vector4(co.x, co.y, co.z, h)
        local line = string.format('coords  = vector4(%.4f, %.4f, %.4f, %.4f),', co.x, co.y, co.z, h)
        print('[ytshelf] ----- Config.YouToolShelf -----')
        print(line)
        print('[ytshelf] -------------------------------')
        notify('Position étagère enregistrée. Bloc copiable en F8.')
    end)
end, false)

-- =============================================
-- COMMANDE DEV : placer/enregistrer les cartons sur l'étagère (GIZMO)
-- -------------------------------------------------------------
-- Utilise object_gizmo (mêmes poignées souris que /lapedity).
--   • on déplace/pivote le carton avec le gizmo, ENTRÉE valide.
--   • après chaque carton : ENTRÉE = en placer un autre, RETOUR = annuler
--     le dernier, /ytcartonfin = terminer + dump du bloc à coller (F8).
-- =============================================
local cartonEditing = false
local cartonFinish  = false

RegisterCommand('ytcartonfin', function()
    if not cartonEditing then
        notify("Aucune édition de cartons en cours.")
        return
    end
    cartonFinish = true
end, false)

local function ytcartonDump(saved)
    print('[ytcarton] ----- Config.YouToolShelf.cartons.list -----')
    print('list = {')
    for _, off in ipairs(saved) do
        print(string.format('    vector4(%.3f, %.3f, %.3f, %.1f),', off.x, off.y, off.z, off.w))
    end
    print('}')
    print('[ytcarton] -------------------------------------------')
end

RegisterCommand('ytcarton', function()
    if cartonEditing then
        notify('Édition cartons déjà en cours.')
        return
    end
    if GetResourceState('object_gizmo') ~= 'started' then
        notify("object_gizmo non démarré (ensure object_gizmo).")
        return
    end
    if not shelfObj or not DoesEntityExist(shelfObj) then
        spawnShelf()
    end
    if not shelfObj or not DoesEntityExist(shelfObj) then
        notify("Aucune étagère (Config.YouToolShelf.enabled = false ?).")
        return
    end

    local cartonCfg = Config.YouToolShelf.cartons
    if not reqModel(cartonCfg.model) then
        notify('Modèle carton introuvable.')
        return
    end

    cartonEditing = true
    cartonFinish  = false

    -- repart des offsets déjà en config, reposés en props visibles
    local saved = {}
    for _, off in ipairs(cartonCfg.list) do
        saved[#saved + 1] = { x = off.x, y = off.y, z = off.z, w = off.w or 0.0 }
    end
    clearShelfCartons()
    for _, off in ipairs(saved) do
        local box = CreateObject(cartonCfg.model, 0.0, 0.0, 0.0, false, false, false)
        AttachEntityToEntity(box, shelfObj, 0, off.x, off.y, off.z, 0.0, 0.0, off.w,
            false, false, false, false, 2, true)
        table.insert(shelfCartons, box)
    end

    CreateThread(function()
        local shelfH = GetEntityHeading(shelfObj)

        while cartonEditing do
            -- carton à placer : démarre au-dessus du centre de l'étagère
            local startW = GetOffsetFromEntityInWorldCoords(shelfObj, 0.0, 0.0, 0.6)
            local box = CreateObject(cartonCfg.model, startW.x, startW.y, startW.z, false, false, false)
            SetEntityHeading(box, shelfH)
            SetEntityCollision(box, false, false)
            SetEntityHasGravity(box, false)

            -- gizmo bloquant (poignées souris + ENTRÉE pour valider)
            local ok = pcall(function() return exports.object_gizmo:useGizmo(box) end)
            if not ok then
                notify('Gizmo HS — voir F8.')
                if DoesEntityExist(box) then DeleteEntity(box) end
                cartonEditing = false
                break
            end

            -- offset final RELATIF à l'étagère
            local fp  = GetEntityCoords(box)
            local fr  = GetEntityRotation(box, 2)
            local rel = GetOffsetFromEntityGivenWorldCoords(shelfObj, fp.x, fp.y, fp.z)
            local off = { x = rel.x, y = rel.y, z = rel.z, w = fr.z - shelfH }
            saved[#saved + 1] = off

            -- on ré-attache la boîte à l'étagère à l'offset enregistré : l'aperçu
            -- correspond ainsi EXACTEMENT au rendu final de spawnShelf.
            SetEntityCollision(box, true, true)
            AttachEntityToEntity(box, shelfObj, 0, off.x, off.y, off.z, 0.0, 0.0, off.w,
                false, false, false, false, 2, true)
            table.insert(shelfCartons, box)
            notify(('Carton #%d placé. ~b~Entrée~s~=nouveau  ~b~Retour~s~=annuler  ~b~/ytcartonfin~s~=terminer'):format(#saved))

            -- mini-prompt entre deux cartons
            local decided = nil
            while cartonEditing and not decided do
                DisableControlAction(0, 191, true) -- Entrée
                DisableControlAction(0, 177, true) -- Retour
                SetTextFont(4); SetTextScale(0.34, 0.34); SetTextColour(255,255,255,255)
                SetTextDropshadow(2, 0,0,0,255); SetTextOutline()
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(
                    ('~y~CARTONS GOPOSTAL~s~ (%d placés)\n'):format(#saved)
                    .. '~b~Entrée~s~ nouveau carton   ~b~Retour~s~ annuler le dernier   ~b~/ytcartonfin~s~ terminer'
                )
                EndTextCommandDisplayText(0.5, 0.04)

                if cartonFinish then decided = 'done' end
                if IsControlJustPressed(0, 191) then decided = 'next' end
                if IsControlJustPressed(0, 177) then decided = 'undo' end
                Wait(0)
            end

            if decided == 'undo' and #saved > 0 then
                saved[#saved] = nil
                local last = shelfCartons[#shelfCartons]
                if last and DoesEntityExist(last) then DeleteEntity(last) end
                shelfCartons[#shelfCartons] = nil
                notify('Dernier carton annulé.')
            elseif decided == 'done' then
                cartonEditing = false
            end
        end

        SetModelAsNoLongerNeeded(cartonCfg.model)

        -- applique en mémoire (pour spawnShelf) + dump F8
        cartonCfg.list = {}
        for _, o in ipairs(saved) do
            cartonCfg.list[#cartonCfg.list + 1] = vector4(o.x, o.y, o.z, o.w)
        end
        ytcartonDump(saved)
        notify(('Édition terminée : %d slot(s). Bloc copiable en F8.'):format(#saved))
        -- on retire l'aperçu DEV : l'étagère reste vide tant qu'aucune commande.
        clearShelfCartons()
    end)
end, false)

-- =============================================
-- CARTONS DE COMMANDE (dynamiques)
-- -------------------------------------------------------------
-- L'étagère est vide par défaut. Pour chaque commande COLIS "en attente"
-- (pending), un vrai carton est POSÉ sur un slot configuré
-- (Config.YouToolShelf.cartons.list), visible par TOUS, dès la commande.
-- Seul le livreur (job youtool) peut le prendre : ox_target ->
-- validateYouToolOrder('package', id) lui remet le carton container (items
-- dedans) à livrer, et le prop disparaît.
-- =============================================

-- Pose/retire les cartons pour coller à la liste des commandes en attente.
-- pkgs = liste de { id, label, qty } (déjà triée par id côté serveur).
local function syncOrderCartons(pkgs)
    local cfg = Config.YouToolShelf
    if not cfg or not shelfObj or not DoesEntityExist(shelfObj) then return end
    local slots = cfg.cartons and cfg.cartons.list or {}
    local model = cfg.cartons and cfg.cartons.model
    if #slots == 0 then return end

    -- map commande -> slot (1ère commande = slot 1), limité au nombre de slots
    local desired = {}
    for i, o in ipairs(pkgs) do
        if i > #slots then break end
        desired[o.id] = i
    end

    -- retire les cartons dont la commande n'est plus en attente
    for id, ent in pairs(orderCartons) do
        if not desired[id] then
            if ent and DoesEntityExist(ent) then
                if GetResourceState('ox_target') == 'started' then
                    exports.ox_target:removeLocalEntity(ent)
                end
                DeleteEntity(ent)
            end
            orderCartons[id] = nil
        end
    end

    -- ajoute les nouveaux cartons
    if not model or not reqModel(model) then return end
    for orderId, idx in pairs(desired) do
        if not orderCartons[orderId] or not DoesEntityExist(orderCartons[orderId]) then
            local off = slots[idx]
            local box = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
            -- collision = true (12e arg) : sinon le raycast d'ox_target traverse
            -- le carton et l'interaction "Prendre le colis" n'apparaît jamais.
            AttachEntityToEntity(box, shelfObj, 0, off.x, off.y, off.z, 0.0, 0.0, off.w or 0.0,
                false, false, true, false, 2, true)
            SetEntityCollision(box, true, true)
            -- flag local lu par pop_inventory : son action "Prendre" route vers
            -- validateYouToolOrder pour ce colis (l'id est stocké ici). Les autres
            -- options globales (Déplacer/Ouvrir) sont masquées sur ce carton.
            Entity(box).state:set('ytColis', orderId, false)
            orderCartons[orderId] = box
        end
    end
end

-- Re-synchronise les cartons posés sur l'étagère depuis le serveur.
local function refreshShelfCartons()
    local cfg = Config.YouToolShelf
    if not (cfg and cfg.enabled and shelfObj and DoesEntityExist(shelfObj)) then
        if next(orderCartons) then clearOrderCartons() end
        return
    end
    local pc = GetEntityCoords(PlayerPedId())
    local sc = cfg.coords
    if #(pc - vector3(sc.x, sc.y, sc.z)) > 100.0 then
        if next(orderCartons) then clearOrderCartons() end
        return
    end
    ESX.TriggerServerCallback('pop_management:getShelfColis', function(orders)
        syncOrderCartons(orders or {})
    end)
end

-- Refresh immédiat quand le serveur signale un changement (commande passée/prise).
RegisterNetEvent('pop_management:shelfRefresh', function()
    refreshShelfCartons()
end)

-- Filet de sécurité : re-sync périodique (gère aussi l'arrivée près de l'étagère).
CreateThread(function()
    while true do
        refreshShelfCartons()
        Wait(5000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        clearShelf()
        if portPed then
            DeleteEntity(portPed)
        end
        if spawnedVan then
            DeleteEntity(spawnedVan)
        end
        if spawnedPed then
            DeleteEntity(spawnedPed)
        end
        if spawnedBoxProp then
            DeleteEntity(spawnedBoxProp)
        end
        if spawnedBlip then
            RemoveBlip(spawnedBlip)
        end
        if currentPromptId then
            exports['pop_v3dui']:Remove(currentPromptId)
        end
    end
end)

-- Ajout fonctionnalité ox_target pour recrutement boss
CreateThread(function()
    exports.ox_target:addGlobalPlayer({
        {
            name = 'recruter_employe_boss',
            icon = 'fas fa-file-signature',
            label = 'Recruter dans l\'entreprise',
            canInteract = function(entity, distance, coords, name, bone)
                local playerData = ESX.GetPlayerData()
                if playerData and playerData.job and playerData.job.grade_name == 'boss' and playerData.job.name ~= 'unemployed' then
                    return true
                end
                return false
            end,
            onSelect = function(data)
                local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
                if targetId > 0 then
                    TriggerServerEvent('pop_management:recruitEmployee', targetId)
                else
                    notify('Erreur: Joueur introuvable.')
                end
            end
        }
    })
end)

-- =============================================
-- SYSTÈME DE LIVRAISON YOUTOOL B2B
-- =============================================
local activeYouToolOrders = {}
local lastQueryTime = 0

local function cleanupYouToolEntities()
    if spawnedVan and DoesEntityExist(spawnedVan) then
        DeleteEntity(spawnedVan)
        spawnedVan = nil
    end
    if spawnedPed and DoesEntityExist(spawnedPed) then
        DeleteEntity(spawnedPed)
        spawnedPed = nil
    end
    if spawnedBoxProp and DoesEntityExist(spawnedBoxProp) then
        DeleteEntity(spawnedBoxProp)
        spawnedBoxProp = nil
    end
    if spawnedBlip then
        RemoveBlip(spawnedBlip)
        spawnedBlip = nil
    end
    if currentPromptId then
        exports['pop_v3dui']:Remove(currentPromptId)
        currentPromptId = nil
    end
end

RegisterNetEvent('pop_management:client:updateYouToolOrders')
AddEventHandler('pop_management:client:updateYouToolOrders', function()
    lastQueryTime = 0 -- Reset cooldown to force immediate query
end)

RegisterNetEvent('pop_management:client:claimYouToolOrderSuccess')
AddEventHandler('pop_management:client:claimYouToolOrderSuccess', function(orderId)
    local updatedOrders = {}
    for _, order in ipairs(activeYouToolOrders) do
        -- comparaison tolérante au type (DB INT vs string réseau)
        if tostring(order.id) ~= tostring(orderId) then
            table.insert(updatedOrders, order)
        end
    end
    activeYouToolOrders = updatedOrders
    if #activeYouToolOrders == 0 then
        cleanupYouToolEntities()
    end
    lastQueryTime = 0 -- force un re-check au prochain tick pour rester sync
end)

local function getYouToolDeliveryConfig()
    if not Config.YouToolDeliveries then return nil end
    local playerData = ESX.GetPlayerData()
    local job = playerData and playerData.job
    local jobName = job and job.name or 'default'
    return Config.YouToolDeliveries[jobName] or Config.YouToolDeliveries['default']
end

CreateThread(function()
    -- Désactivé quand le système job YouTool est actif : les colis se récupèrent
    -- désormais au Port (comme les véhicules), via le blip "Ma commande" + le menu
    -- de retrait. L'ancienne zone société (ped/van) n'est plus utilisée.
    if Config.YouToolJob and Config.YouToolJob ~= '' then return end

    while true do
        local sleep = 2000
        local deliveryConfig = getYouToolDeliveryConfig()

        if deliveryConfig then
            local now = GetGameTimer()
            
            -- Check for active/ready orders globally every 10 seconds or when forced
            if now - lastQueryTime > 10000 or lastQueryTime == 0 then
                lastQueryTime = now
                ESX.TriggerServerCallback('pop_management:getReadyYouToolOrders', function(orders)
                    local safeOrders = orders or {}
                    local hadOrders = (activeYouToolOrders and #activeYouToolOrders > 0)
                    activeYouToolOrders = safeOrders
                    
                    if #activeYouToolOrders > 0 and not hadOrders then
                        local pedCoords = deliveryConfig.Ped.coords
                        SetNewWaypoint(pedCoords.x, pedCoords.y)
                        notify('GPS mis à jour vers la zone de livraison.', {
                            title    = 'Livraison YouTool',
                            image    = NOTIF_IMG.youtool,
                            duration = 6000,
                        })
                    end
                end)
            end
            
            if activeYouToolOrders and #activeYouToolOrders > 0 then
                local pedCoords = deliveryConfig.Ped.coords
                local vanCoords = deliveryConfig.Van.coords
                local pCoords = GetEntityCoords(PlayerPedId())
                local dist = #(pCoords - vector3(pedCoords.x, pedCoords.y, pedCoords.z))
                
                -- Global Blip
                if not spawnedBlip then
                    spawnedBlip = AddBlipForCoord(pedCoords.x, pedCoords.y, pedCoords.z)
                    SetBlipSprite(spawnedBlip, 473)
                    SetBlipColour(spawnedBlip, 47)
                    SetBlipScale(spawnedBlip, 0.8)
                    SetBlipAsShortRange(spawnedBlip, false)
                    BeginTextCommandSetBlipName("STRING")
                    AddTextComponentString("Livraison YouTool")
                    EndTextCommandSetBlipName(spawnedBlip)
                end
                
                if dist < 100.0 then
                    sleep = 500
                    
                    -- Spawns
                    if not spawnedVan or not DoesEntityExist(spawnedVan) then
                        local vanModel = deliveryConfig.Van.model or GetHashKey('speedo')
                        RequestModel(vanModel)
                        while not HasModelLoaded(vanModel) do Wait(10) end
                        
                        spawnedVan = CreateVehicle(vanModel, vanCoords.x, vanCoords.y, vanCoords.z, vanCoords.w, false, false)
                        SetEntityAsMissionEntity(spawnedVan, true, true)
                        SetVehicleOnGroundProperly(spawnedVan)
                        FreezeEntityPosition(spawnedVan, true)
                        SetVehicleDoorsLocked(spawnedVan, 2)
                    end
                    
                    if not spawnedPed or not DoesEntityExist(spawnedPed) then
                        local pedModel = deliveryConfig.Ped.model or GetHashKey('s_m_m_dockwork_01')
                        RequestModel(pedModel)
                        while not HasModelLoaded(pedModel) do Wait(10) end
                        
                        spawnedPed = CreatePed(4, pedModel, pedCoords.x, pedCoords.y, pedCoords.z, pedCoords.w, false, false)
                        SetEntityAsMissionEntity(spawnedPed, true, true)
                        FreezeEntityPosition(spawnedPed, true)
                        SetEntityInvincible(spawnedPed, true)
                        SetBlockingOfNonTemporaryEvents(spawnedPed, true)
                        
                        -- Carry box animation
                        RequestAnimDict('anim@heists@box_carry@')
                        while not HasAnimDictLoaded('anim@heists@box_carry@') do Wait(10) end
                        TaskPlayAnim(spawnedPed, 'anim@heists@box_carry@', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
                        
                        -- Attached Cardboard Box Prop
                        local propModel = GetHashKey('prop_cs_cardbox_01')
                        RequestModel(propModel)
                        while not HasModelLoaded(propModel) do Wait(10) end
                        spawnedBoxProp = CreateObject(propModel, pedCoords.x, pedCoords.y, pedCoords.z, false, false, false)
                        AttachEntityToEntity(spawnedBoxProp, spawnedPed, GetPedBoneIndex(spawnedPed, 28422), 0.0, 0.1, -0.08, 100.0, 0.0, 150.0, true, true, false, true, 1, true)
                    end
                    
                    -- Interaction
                    if dist < 2.5 then
                        sleep = 0
                        if not currentPromptId then
                            if Config.HelpNotificationType == 'esx' then
                                ESX.ShowHelpNotification('Appuyez sur ~INPUT_CONTEXT~ pour prendre le carton')
                            else
                                currentPromptId = exports['pop_v3dui']:Create({
                                    coords = vector3(pedCoords.x, pedCoords.y, pedCoords.z + 1.2),
                                    type = "prompt",
                                    content = {
                                        key = "E",
                                        label = "Prendre le carton",
                                        icon = "fas fa-box"
                                    },
                                    drawDistance = 5.0
                                })
                            end
                        end
                        
                        if IsControlJustPressed(0, 38) then
                            local order = activeYouToolOrders[1]
                            if order then
                                local claimedId = order.id
                                -- Play player pickup anim
                                RequestAnimDict('anim@heists@box_carry@')
                                while not HasAnimDictLoaded('anim@heists@box_carry@') do Wait(10) end
                                TaskPlayAnim(PlayerPedId(), 'anim@heists@box_carry@', 'idle', 8.0, -8.0, 1500, 49, 0, false, false, false)

                                TriggerServerEvent('pop_management:claimYouToolOrder', claimedId)

                                -- Nettoyage optimiste local: on retire la commande qu'on
                                -- vient de réclamer pour faire disparaître le blip tout de
                                -- suite. Si l'attribution échoue côté serveur (inventaire
                                -- plein, etc.), le prochain poll re-fetchera la commande
                                -- et le blip réapparaîtra naturellement.
                                local remaining = {}
                                for _, o in ipairs(activeYouToolOrders) do
                                    -- comparaison tolérante au type (DB INT vs string)
                                    if tostring(o.id) ~= tostring(claimedId) then
                                        table.insert(remaining, o)
                                    end
                                end
                                activeYouToolOrders = remaining
                                if #activeYouToolOrders == 0 then
                                    cleanupYouToolEntities()
                                end
                                lastQueryTime = 0 -- force un re-check au prochain tick

                                Wait(1200)
                            end
                        end
                    else
                        if currentPromptId then
                            exports['pop_v3dui']:Remove(currentPromptId)
                            currentPromptId = nil
                        end
                    end
                else
                    -- Far away: clean up physical entities but KEEP the blip
                    if spawnedVan and DoesEntityExist(spawnedVan) then DeleteEntity(spawnedVan); spawnedVan = nil; end
                    if spawnedPed and DoesEntityExist(spawnedPed) then DeleteEntity(spawnedPed); spawnedPed = nil; end
                    if spawnedBoxProp and DoesEntityExist(spawnedBoxProp) then DeleteEntity(spawnedBoxProp); spawnedBoxProp = nil; end
                    if currentPromptId then exports['pop_v3dui']:Remove(currentPromptId); currentPromptId = nil; end
                end
            else
                cleanupYouToolEntities()
            end
        else
            cleanupYouToolEntities()
        end

        Wait(sleep)
    end
end)

-- =============================================
-- BLIP "MA COMMANDE" (commettant)
-- ---------------------------------------------
-- Le client qui a passé une commande (véhicule ou colis) voit un blip + un
-- itinéraire vers le Port DÈS la commande, même tant qu'elle est en attente
-- de validation, jusqu'à ce qu'il la récupère.
-- =============================================
local myOrderBlip = nil
local forceMyOrdersCheck = true

RegisterNetEvent('pop_management:client:refreshMyOrders')
AddEventHandler('pop_management:client:refreshMyOrders', function()
    forceMyOrdersCheck = true
end)

CreateThread(function()
    if not (Config.YouToolJob and Config.YouToolJob ~= '') then return end
    local portCoords = Config.Port.Ped.coords
    local lastCheck = 0
    while true do
        local now = GetGameTimer()
        if forceMyOrdersCheck or (now - lastCheck) > 15000 then
            forceMyOrdersCheck = false
            lastCheck = now
            ESX.TriggerServerCallback('pop_management:getMyActiveOrders', function(count)
                count = tonumber(count) or 0
                if count > 0 then
                    if not myOrderBlip then
                        myOrderBlip = AddBlipForCoord(portCoords.x, portCoords.y, portCoords.z)
                        SetBlipSprite(myOrderBlip, 478)
                        SetBlipColour(myOrderBlip, 47)
                        SetBlipScale(myOrderBlip, 0.9)
                        SetBlipAsShortRange(myOrderBlip, false)
                        SetBlipRoute(myOrderBlip, true)
                        SetBlipRouteColour(myOrderBlip, 47)
                        BeginTextCommandSetBlipName("STRING")
                        AddTextComponentString("Ma commande (Port)")
                        EndTextCommandSetBlipName(myOrderBlip)
                    end
                else
                    if myOrderBlip then
                        RemoveBlip(myOrderBlip)
                        myOrderBlip = nil
                    end
                end
            end)
        end
        Wait(2000)
    end
end)

-- =============================================
-- LIVRAISON PHYSIQUE DU LIVREUR (checklist + blip/PNJ)
-- -------------------------------------------------------------
-- Déclenché juste après que le livreur a récupéré le carton (étape 1,
-- déjà acquise à ce stade). La checklist est une carte persistante dans la
-- pile de notifications (tab_basehud), donc alignée nativement avec elles
-- (même largeur/position/échelle) sans calcul manuel de décalage.
-- Guide ensuite le livreur jusqu'au client (blip) ou jusqu'au PNJ (commande
-- bot) pour l'étape finale de remise.
-- =============================================
local activeDelivery = nil -- { orderId, label, coords, isBot }
local deliveryBlip = nil
local deliveryPed = nil
local deliveryPromptId = nil

local function nuiDelivery(msg)
    TriggerEvent('notification:client:checklist', msg)
end

local function clearDeliveryEntities()
    if deliveryBlip then RemoveBlip(deliveryBlip); deliveryBlip = nil end
    if deliveryPed and DoesEntityExist(deliveryPed) then DeleteEntity(deliveryPed) end
    deliveryPed = nil
    if deliveryPromptId then exports['pop_v3dui']:Remove(deliveryPromptId); deliveryPromptId = nil end
end

local function endDelivery()
    clearDeliveryEntities()
    nuiDelivery({ type = 'show', visible = false })
    activeDelivery = nil
end

RegisterNetEvent('pop_management:client:startDelivery', function(data)
    if not (data and data.coords) then return end
    clearDeliveryEntities()
    activeDelivery = {
        orderId = data.orderId,
        label   = data.label,
        coords  = vector3(data.coords.x, data.coords.y, data.coords.z),
        isBot   = data.isBot,
        pedModel = data.pedModel
    }

    nuiDelivery({ type = 'reset' })
    nuiDelivery({ type = 'show', visible = true, title = 'LIVRAISON GOPOSTAL' })
    nuiDelivery({ type = 'step', step = 1, done = true, label = 'Carton récupéré' })
    nuiDelivery({ type = 'step', step = 2, done = false, label = activeDelivery.isBot and 'Se rendre au point de livraison' or 'Se rendre chez le client' })
    nuiDelivery({ type = 'step', step = 3, done = false, label = 'Remettre le colis' })

    deliveryBlip = AddBlipForCoord(activeDelivery.coords.x, activeDelivery.coords.y, activeDelivery.coords.z)
    SetBlipSprite(deliveryBlip, 478)
    SetBlipColour(deliveryBlip, 5)
    SetBlipScale(deliveryBlip, 0.9)
    SetBlipAsShortRange(deliveryBlip, false)
    SetBlipRoute(deliveryBlip, true)
    SetBlipRouteColour(deliveryBlip, 5)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(activeDelivery.isBot and "Livraison GoPostal (client)" or "Livraison GoPostal")
    EndTextCommandSetBlipName(deliveryBlip)

    notify('Livraison en cours : rendez-vous au point indiqué par le blip.', {
        title = 'GoPostal', image = NOTIF_IMG.youtool, duration = 6000,
    })
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if activeDelivery then
            local pCoords = GetEntityCoords(PlayerPedId())
            local dist = #(pCoords - activeDelivery.coords)

            if dist < 60.0 then
                sleep = 300

                if activeDelivery.isBot and (not deliveryPed or not DoesEntityExist(deliveryPed)) and dist < 40.0 then
                    local model = activeDelivery.pedModel or GetHashKey('a_m_m_business_01')
                    if reqModel(model) then
                        deliveryPed = CreatePed(4, model, activeDelivery.coords.x, activeDelivery.coords.y, activeDelivery.coords.z - 1.0, 0.0, false, true)
                        SetEntityAsMissionEntity(deliveryPed, true, true)
                        FreezeEntityPosition(deliveryPed, true)
                        SetEntityInvincible(deliveryPed, true)
                        SetBlockingOfNonTemporaryEvents(deliveryPed, true)
                        SetModelAsNoLongerNeeded(model)
                    end
                end

                if dist < 2.5 then
                    sleep = 0
                    if not deliveryPromptId then
                        nuiDelivery({ type = 'step', step = 2, done = true })
                        deliveryPromptId = exports['pop_v3dui']:Create({
                            coords = vector3(activeDelivery.coords.x, activeDelivery.coords.y, activeDelivery.coords.z + 1.0),
                            type = "prompt",
                            content = { key = "E", label = "Remettre le colis", icon = "fas fa-box" },
                            drawDistance = 5.0
                        })
                    end

                    if IsControlJustPressed(0, 38) then
                        local order = activeDelivery
                        TriggerServerEvent('pop_management:completeDelivery', order.orderId)
                        nuiDelivery({ type = 'step', step = 3, done = true })
                        Wait(800)
                        endDelivery()
                    end
                elseif deliveryPromptId then
                    exports['pop_v3dui']:Remove(deliveryPromptId)
                    deliveryPromptId = nil
                end
            elseif deliveryPed or deliveryPromptId then
                if deliveryPed and DoesEntityExist(deliveryPed) then DeleteEntity(deliveryPed) end
                deliveryPed = nil
                if deliveryPromptId then exports['pop_v3dui']:Remove(deliveryPromptId); deliveryPromptId = nil end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        clearDeliveryEntities()
        TriggerEvent('notification:client:checklist', { type = 'show', visible = false })
    end
end)

-- =============================
-- DYNASTY 8 — MLO CLIENT
-- =============================

-- Props coffres spawnés localement (indexed by property_id)
local d8ChestProps = {}
-- Zone active (la propriété D8 dans laquelle se trouve le joueur)
local d8ActiveZone = nil
-- Zones ox_lib actives
local d8OxZones = {}

-- Modèle du prop coffre (même que les coffres statiques job)
local D8_CHEST_MODEL = GetHashKey('prop_box_woodcrate01a')

-- Spawner le prop visuel d'un coffre D8
local function d8SpawnChestProp(chest)
    if d8ChestProps[chest.property_id] and DoesEntityExist(d8ChestProps[chest.property_id]) then return end
    RequestModel(D8_CHEST_MODEL)
    local timeout = 0
    while not HasModelLoaded(D8_CHEST_MODEL) and timeout < 100 do
        Wait(50)
        timeout = timeout + 1
    end
    local prop = CreateObjectNoOffset(D8_CHEST_MODEL, chest.x, chest.y, chest.z, false, false, false)
    if prop and prop ~= 0 then
        SetEntityHeading(prop, chest.heading)
        FreezeEntityPosition(prop, true)
        SetEntityCollision(prop, true, false)
        PlaceObjectOnGroundProperly(prop)
        d8ChestProps[chest.property_id] = prop

        -- ox_target sur le prop (interaction coffre)
        if GetResourceState('ox_target') == 'started' then
            local options = {
                {
                    label = chest.name or 'Coffre',
                    icon  = 'fas fa-box-open',
                    onSelect = function()
                        TriggerServerEvent('pop_management:d8OpenChest', chest.property_id)
                    end
                }
            }
            exports.ox_target:addLocalEntity(prop, options)
        end
    end
end

-- Despawner un prop coffre
local function d8DespawnChestProp(propertyId)
    local prop = d8ChestProps[propertyId]
    if prop and DoesEntityExist(prop) then
        if GetResourceState('ox_target') == 'started' then
            exports.ox_target:removeLocalEntity(prop)
        end
        DeleteEntity(prop)
    end
    d8ChestProps[propertyId] = nil
end

-- Réception de la liste complète des coffres au spawn
RegisterNetEvent('pop_management:client:d8LoadChests')
AddEventHandler('pop_management:client:d8LoadChests', function(chests)
    -- Nettoyer les anciens props
    for pid, _ in pairs(d8ChestProps) do
        d8DespawnChestProp(pid)
    end
    -- Spawner tous les coffres reçus
    if chests then
        for _, chest in pairs(chests) do
            d8SpawnChestProp(chest)
        end
    end
end)

-- Réception d'un nouveau coffre placé en live
RegisterNetEvent('pop_management:client:d8SpawnChest')
AddEventHandler('pop_management:client:d8SpawnChest', function(chest)
    d8SpawnChestProp(chest)
end)

-- Suppression d'un coffre en live
RegisterNetEvent('pop_management:client:d8DespawnChest')
AddEventHandler('pop_management:client:d8DespawnChest', function(propertyId)
    d8DespawnChestProp(propertyId)
end)

-- Initialiser les zones ox_lib sphere pour chaque propriété D8
CreateThread(function()
    if not Config.D8Zones or #Config.D8Zones == 0 then return end
    -- Attendre que ox_lib soit prêt
    Wait(2000)
    for _, zone in ipairs(Config.D8Zones) do
        local zoneRef = lib.zones.sphere({
            coords  = zone.coords,
            radius  = zone.radius,
            debug   = false,
            onEnter = function()
                d8ActiveZone = zone
                -- Notifier le NUI de la zone active
                sendToDui({ action = 'd8ZoneEnter', zoneId = zone.id, zoneName = zone.name })
            end,
            onExit = function()
                d8ActiveZone = nil
                sendToDui({ action = 'd8ZoneExit' })
            end,
        })
        table.insert(d8OxZones, zoneRef)
    end
end)

-- NUI callback : placer un coffre à la position courante
RegisterNUICallback('d8PlaceChest', function(data, cb)
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local head   = GetEntityHeading(ped)
    if not d8ActiveZone then
        cb({ ok = false, reason = 'Vous n\'etes pas dans une zone D8.' })
        return
    end
    TriggerServerEvent('pop_management:d8PlaceChest', {
        propertyId = d8ActiveZone.id,
        name       = data.name or 'Coffre',
        x          = coords.x,
        y          = coords.y,
        z          = coords.z,
        heading    = head,
    })
    cb({ ok = true })
end)

-- NUI callback : supprimer le coffre d'une propriété
RegisterNUICallback('d8RemoveChest', function(data, cb)
    TriggerServerEvent('pop_management:d8RemoveChest', { propertyId = data.propertyId })
    cb({ ok = true })
end)

-- NUI callback : générer une clé item pour une propriété
RegisterNUICallback('d8GenerateKey', function(data, cb)
    TriggerServerEvent('pop_management:d8GenerateKey', { propertyId = data.propertyId, propertyName = data.propertyName })
    cb({ ok = true })
end)

-- NUI callback : récupérer les données coffre d'une propriété
RegisterNUICallback('d8GetPropertyData', function(data, cb)
    ESX.TriggerServerCallback('pop_management:d8GetPropertyData', function(result)
        cb(result or {})
    end, tonumber(data.propertyId))
end)

-- Commande debug : afficher les coords pour remplir Config.D8Zones
RegisterCommand('d8coords', function()
    local coords = GetEntityCoords(PlayerPedId())
    print(string.format('[D8] coords = vector3(%.4f, %.4f, %.4f)', coords.x, coords.y, coords.z))
    notify(string.format('D8 Coords: %.2f, %.2f, %.2f', coords.x, coords.y, coords.z), { icon = 'fas fa-map-pin' })
end, false)
-- Réception du signal serveur : ouvrir l'inventaire du coffre D8
RegisterNetEvent('pop_management:client:d8OpenChestUI')
AddEventHandler('pop_management:client:d8OpenChestUI', function(chestId, label)
    TriggerServerEvent('pop_inventory:server:openStaticChest', chestId, label, 30, 150.0)
end)