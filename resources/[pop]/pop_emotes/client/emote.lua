-- luacheck: ignore 131 111
-- (fonctions et variables globales partagées entre les fichiers client ou exportées : exports du manifest)
preview_emote = nil

-- Notification au style d'origine (icône selon le type), envoyée par le bridge (pop_notify).
-- Les codes couleur GTA (~s, ~c, ~K…) des textes sont retirés.
function EmoteNotify(data)
    local msg = tostring(data.content or ''):gsub('~%a', ''):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    Bridge.Notify({
        message  = msg,
        icon     = data.type == 'ROUGE' and 'fas fa-triangle-exclamation' or 'fas fa-circle-info',
        duration = (data.duration or 4) * 1000,
    })
end
current_emote = nil
current_emote_name = nil
local attached_props = {}
local clone_attached_props = {}
local player_emoting_with = nil
emotePed = nil
emotePedTarget = nil
previewActive = false

-- Position du ped à l'écran : juste à gauche du menu NUI (qui est à droite)
-- Valeurs identiques à rpemotes-reborn pour coller exactement au menu.
local PREVIEW_SCREEN_X = 0.78
local PREVIEW_SCREEN_Y = 0.60
local PREVIEW_DEPTH = 4.3
local PREVIEW_HEADING_OFFSET = 190.0

-- Affiche un clone SOLIDE du joueur à l'écran et le maintient devant la caméra
-- chaque frame (méthode rpemotes-reborn). L'anim joue car c'est un vrai ped
-- simulé : GivePedToPauseMenu ne permet PAS de jouer une animation.
function StartPedPreview()
    if previewActive then return end
    previewActive = true

    CreateThread(function()
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed) - vector3(0.0, 0.0, 10.0)
        emotePed = CreatePed(26, GetEntityModel(playerPed), coords.x, coords.y, coords.z, 0, false, false)
        ClonePedToTarget(playerPed, emotePed)

        SetEntityInvincible(emotePed, true)
        SetEntityLocallyVisible(emotePed)
        NetworkSetEntityInvisibleToNetwork(emotePed, true)
        SetEntityCanBeDamaged(emotePed, false)
        SetBlockingOfNonTemporaryEvents(emotePed, true)
        SetEntityAlpha(emotePed, 254, false) -- solide, plus de ped transparent
        SetEntityCollision(emotePed, false, false)
        SetPedCanBeTargetted(emotePed, false)

        local positionBuffer = {}
        local bufferSize = 5

        while previewActive and emotePed ~= nil and DoesEntityExist(emotePed) do
            local world, normal = GetWorldCoordFromScreenCoord(PREVIEW_SCREEN_X, PREVIEW_SCREEN_Y)
            local target = world + normal * PREVIEW_DEPTH
            local camRot = GetGameplayCamRot(2)

            -- Lissage de la position pour éviter le tremblement
            positionBuffer[#positionBuffer + 1] = target
            if #positionBuffer > bufferSize then
                table.remove(positionBuffer, 1)
            end
            local averaged = vector3(0.0, 0.0, 0.0)
            for _, pos in ipairs(positionBuffer) do
                averaged = averaged + pos
            end
            averaged = averaged / #positionBuffer

            local zOffset = IsPedHuman(emotePed) and 0.0 or 0.5
            SetEntityCoords(emotePed, averaged.x, averaged.y, averaged.z + zOffset, false, false, false, false)
            SetEntityHeading(emotePed, camRot.z + PREVIEW_HEADING_OFFSET)
            SetEntityRotation(emotePed, camRot.x * (-1), 0.0, camRot.z + 150.0, 2, false)
            ForcePedMotionState(emotePed, GetHashKey('MotionState_None'), false, 1, true)

            Wait(4)
        end

        if emotePed ~= nil and DoesEntityExist(emotePed) then
            DeleteEntity(emotePed)
        end
        emotePed = nil
    end)
end

function StopPedPreview()
    if not previewActive then return end
    previewActive = false

    DestroyCloneAttachedProps()
    if emotePed ~= nil and DoesEntityExist(emotePed) then
        DeleteEntity(emotePed)
    end
    emotePed = nil
end

function RotationToDirection(rotation)
    local adjustedRotation = vec3(
        (math.pi / 180) * rotation.x,
        (math.pi / 180) * rotation.y,
        (math.pi / 180) * rotation.z
    )
    local direction = vec3(
        -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.sin(adjustedRotation.x)
    )
    return direction
end

local function LoadAnimDict(dict)
    local timer = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timer do
        RequestAnimDict(dict)
        Wait(10)
    end
end

function UpdateOrCreateClone()
    -- Garantit que le ped de prévisualisation (rendu pause-menu) est prêt
    if not previewActive or emotePed == nil or not DoesEntityExist(emotePed) then
        StartPedPreview()
    end
end

--[[ CreateThread(function()
    while true do
        Wait(10)
        if preview_emote ~= nil then
            local _ = GetGameplayCamCoord()
            -- Get the coordinates that are 5 units forward, 1 unit up and 1 unit right the coords _ depending on the rotation of the camera
            local rot = GetGameplayCamRot()
            local forward = RotationToDirection(rot)
            local right = RotationToDirection(vec3(rot.x, rot.y, rot.z - 90.0))
            local up = vec3(0.0, 0.0, 1.5)
            local coords = _ + forward * 5.0 + up * 0.8 + right * 1.2
            -- Set the ped coords to the coords we calculated
            SetEntityCoordsNoOffset(emotePed, coords, false, false, false)
            -- Make the ped look at the inverse of the camera
            SetEntityHeading(emotePed, rot.z + 180)
            SetEntityVisible(emotePed, true, false)
            -- Load the emote
            if not IsEntityPlayingAnim(emotePed, preview_emote[1], preview_emote[2], 3) then
                ClearPedTasks(emotePed)
                DestroyCloneAttachedProps()
                PreviewEmote(preview_emote)
            end
        else
            SetEntityVisible(emotePed, false, false)
            SetEntityCoordsNoOffset(emotePed, vec3(0.0, 0.0, 0.0), false, false, false)
        end
    end
end) ]]

function AttachProp(prop1, bone, off1, off2, off3, rot1, rot2, rot3, textureVariation, pedid)
    local Player = pedid or PlayerPedId()
    local x, y, z = table.unpack(GetEntityCoords(Player))

    if not IsModelValid(prop1) then
        return false
    end

    if not HasModelLoaded(prop1) then
        LoadPropDict(prop1)
    end

    prop = CreateObject(joaat(prop1), x, y, z + 0.2, true, true, true)
    if textureVariation ~= nil then
        SetObjectTextureVariation(prop, textureVariation)
    end
    AttachEntityToEntity(prop, Player, GetPedBoneIndex(Player, bone), off1, off2, off3, rot1, rot2, rot3, true, true,
        false, true, 1, true)
    if pedid ~= nil then
        table.insert(clone_attached_props, prop)
    else
        table.insert(attached_props, prop)
    end
    PlayerHasProp = true
    SetModelAsNoLongerNeeded(prop1)
end

function AttachPropLocal(prop1, bone, off1, off2, off3, rot1, rot2, rot3, textureVariation, pedid)
    local Player = pedid or PlayerPedId()
    local x, y, z = table.unpack(GetEntityCoords(Player))

    if not IsModelValid(prop1) then
        return false
    end

    if not HasModelLoaded(prop1) then
        LoadPropDict(prop1)
    end

    prop = CreateObject(joaat(prop1), x, y, z + 0.2, false, true, true)
    if textureVariation ~= nil then
        SetObjectTextureVariation(prop, textureVariation)
    end
    AttachEntityToEntity(prop, Player, GetPedBoneIndex(Player, bone), off1, off2, off3, rot1, rot2, rot3, true, true,
            false, true, 1, true)
    if pedid ~= nil then
        table.insert(clone_attached_props, prop)
    else
        table.insert(attached_props, prop)
    end
    PlayerHasProp = true
    SetModelAsNoLongerNeeded(prop1)
end

function DestroyAttachedProps()
    for i = 1, #attached_props do
        DeleteEntity(attached_props[i])
    end
    attached_props = {}
    PlayerHasProp = false
end

function DestroyCloneAttachedProps()
    for i = 1, #clone_attached_props do
        DeleteEntity(clone_attached_props[i])
    end
    clone_attached_props = {}
end

function PlayEmote(emote, emoteName)
    if not emote or not emote[1] or not emote[2] then return end

    current_emote = emote
    current_emote_name = emoteName or nil
    LocalPlayer.state:set('currentEmote', emoteName or '', true)
    player_emoting_with = nil
    local flag = 1
    local duration = -1
    LoadAnimDict(emote[1])
    if emote.AnimationOptions then

        if emote.AnimationOptions.EmoteDuration then
            duration = emote.AnimationOptions.EmoteDuration
        end

        if emote.AnimationOptions.Prop then
            local x, y, z, xR, yR, zR = table.unpack(emote.AnimationOptions.PropPlacement)
            AttachProp(emote.AnimationOptions.Prop, emote.AnimationOptions.PropBone, x, y, z, xR, yR, zR, emote.AnimationOptions.PropTextureVariation)
        end

        if emote.AnimationOptions.SecondProp then
            local x, y, z, xR, yR, zR = table.unpack(emote.AnimationOptions.SecondPropPlacement)
            AttachProp(emote.AnimationOptions.SecondProp, emote.AnimationOptions.SecondPropBone, x, y, z, xR, yR, zR, emote.AnimationOptions.SecondPropTextureVariation)
        end

        if emote.AnimationOptions.EmoteMoving or IsPedInVehicle(PlayerPedId(-1), GetVehiclePedIsIn(PlayerPedId(-1), false), false) then
            flag = 51
        elseif emote.AnimationOptions.EmoteLoop then
            flag = 1
        elseif emote.AnimationOptions.EmoteStuck then
            flag = 50
        end
    end
    TaskPlayAnim(PlayerPedId(), emote[1], emote[2], 8.0, 8.0, duration, flag, 0, false, false, false)
end

function PreviewEmote(emote, partnerEmote)
    if not emote or not emote[1] or not emote[2] then return end
    if emotePed == nil or not DoesEntityExist(emotePed) then return end

    ClearPedTasksImmediately(emotePed)
    DestroyCloneAttachedProps()

    local flag = 1
    local duration = -1
    LoadAnimDict(emote[1])

    if emote.AnimationOptions then
        if emote.AnimationOptions.EmoteDuration then
            duration = emote.AnimationOptions.EmoteDuration
        end

        if emote.AnimationOptions.Prop then
            local x, y, z, xR, yR, zR = table.unpack(emote.AnimationOptions.PropPlacement)
            AttachPropLocal(emote.AnimationOptions.Prop, emote.AnimationOptions.PropBone, x, y, z, xR, yR, zR, emote.AnimationOptions.PropTextureVariation, emotePed)
        end

        if emote.AnimationOptions.SecondProp then
            local x, y, z, xR, yR, zR = table.unpack(emote.AnimationOptions.SecondPropPlacement)
            AttachPropLocal(emote.AnimationOptions.SecondProp, emote.AnimationOptions.SecondPropBone, x, y, z, xR, yR, zR, emote.AnimationOptions.SecondPropTextureVariation, emotePed)
        end

        if emote.AnimationOptions.EmoteStuck then
            flag = 50
        end
    end

    -- Le ped est figé pour le rendu pause-menu : on force une anim en boucle
    TaskPlayAnim(emotePed, emote[1], emote[2], 8.0, 8.0, duration, flag, 0, false, false, false)
end

function PlaySharedEmote(emote, player)

    current_emote = emote
    player_emoting_with = player
    local flag = 1
    local duration = -1
    local pedInFront = GetPlayerPed(GetPlayerFromServerId(player))
    local ply = PlayerPedId()

    local SyncOffsetFront = 1.0
    local SyncOffsetSide = 0.0
    local SyncOffsetHeight = 0.0
    local SyncOffsetHeading = 180.1

    LoadAnimDict(emote[1])
    if emote.AnimationOptions then

        if emote.AnimationOptions.SyncOffsetFront then
            SyncOffsetFront = emote.AnimationOptions.SyncOffsetFront + 0.0
        end
        if emote.AnimationOptions.SyncOffsetSide then
            SyncOffsetSide = emote.AnimationOptions.SyncOffsetSide + 0.0
        end
        if emote.AnimationOptions.SyncOffsetHeight then
            SyncOffsetHeight = emote.AnimationOptions.SyncOffsetHeight + 0.0
        end
        if emote.AnimationOptions.SyncOffsetHeading then
            SyncOffsetHeading = emote.AnimationOptions.SyncOffsetHeading + 0.0
        end

        -- There is a priority to the source attached, if it is not set, it will use the target
        if (emote.AnimationOptions.Attachto) then
            local bone = emote.AnimationOptions.bone or -1 -- No bone
            local xPos = emote.AnimationOptions.xPos or 0.0
            local yPos = emote.AnimationOptions.yPos or 0.0
            local zPos = emote.AnimationOptions.zPos or 0.0
            local xRot = emote.AnimationOptions.xRot or 0.0
            local yRot = emote.AnimationOptions.yRot or 0.0
            local zRot = emote.AnimationOptions.zRot or 0.0
            AttachEntityToEntity(ply, pedInFront, GetPedBoneIndex(pedInFront, bone), xPos, yPos, zPos, xRot, yRot, zRot,
                false, false, false, true, 1, true)
        end

        if emote.AnimationOptions.EmoteDuration then
            duration = emote.AnimationOptions.EmoteDuration
        end

        if emote.AnimationOptions.Prop then
            local x, y, z, xR, yR, zR = table.unpack(emote.AnimationOptions.PropPlacement)
            AttachProp(emote.AnimationOptions.Prop, emote.AnimationOptions.PropBone, x, y, z, xR, yR, zR, emote.AnimationOptions.PropTextureVariation)
        end

        if emote.AnimationOptions.SecondProp then
            local x, y, z, xR, yR, zR = table.unpack(emote.AnimationOptions.SecondPropPlacement)
            AttachProp(emote.AnimationOptions.SecondProp, emote.AnimationOptions.SecondPropBone, x, y, z, xR, yR, zR, emote.AnimationOptions.SecondPropTextureVariation)
        end

        if emote.AnimationOptions.EmoteMoving or IsPedInVehicle(PlayerPedId(-1), GetVehiclePedIsIn(PlayerPedId(-1), false), false) then
            flag = 51
        elseif emote.AnimationOptions.EmoteLoop then
            flag = 1
        elseif emote.AnimationOptions.EmoteStuck then
            flag = 50
        end
    end

    if Config.Debug then print('[pop_emotes] emote partagée', duration, flag) end

    local coords = GetOffsetFromEntityInWorldCoords(pedInFront, SyncOffsetSide, SyncOffsetFront, SyncOffsetHeight)
    local heading = GetEntityHeading(pedInFront)
    SetEntityHeading(ply, heading - SyncOffsetHeading)
    SetEntityCoordsNoOffset(ply, coords.x, coords.y, coords.z, 0)
    TaskPlayAnim(PlayerPedId(), emote[1], emote[2], 8.0, 8.0, duration, flag, 0, false, false, false)
end

function StopEmote()
    if current_emote ~= nil then
        -- if entity is attached to another entity, detach it
        if current_emote.AnimationOptions ~= nil and current_emote.AnimationOptions.Attachto ~= nil then
            DetachEntity(PlayerPedId(), true, true)
        end
        -- if current emote is a shared emote, send a stop event to the other player
        if player_emoting_with then
            TriggerServerEvent("pop_emotes:StopEmote", player_emoting_with)
        end
        DestroyAttachedProps()
        if current_emote.AnimationOptions ~= nil and current_emote.AnimationOptions.ExitEmote ~= nil then
            local exitEmote = EmotesList[current_emote.AnimationOptions.ExitEmoteType or "Exits"][current_emote.AnimationOptions.ExitEmote]
            current_emote = nil
            PlayEmote(exitEmote)
        else
            ClearPedTasks(PlayerPedId())
        end
        current_emote = nil
    end
    current_emote = nil
    current_emote_name = nil
    LocalPlayer.state:set('currentEmote', '', true)
end

function RequestWalking(set)
    local timeout = GetGameTimer() + 5000
    while not HasAnimSetLoaded(set) and GetGameTimer() < timeout do
        RequestAnimSet(set)
        Wait(5)
    end
end

function pairsByKeys(t, f)
    local a = {}
    for n in pairs(t) do
        table.insert(a, n)
    end
    table.sort(a, f)
    local i = 0             -- iterator variable
    local iter = function() -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iter
end

function loadAnimDict2(dict)
    local timer = GetGameTimer() + 5000
	while not HasAnimDictLoaded(dict) and GetGameTimer() < timer do
		RequestAnimDict(dict)
		Wait(0)
	end
end

function LoadPropDict(model)
    -- load the model if it's not loaded and wait until it's loaded or timeout
    if not HasModelLoaded(joaat(model)) then
        RequestModel(joaat(model))
        local timeout = 2000
        while not HasModelLoaded(joaat(model)) and timeout > 0 do
            Wait(5)
            timeout = timeout - 5
        end
        if timeout == 0 then
            return
        end
    end
end

function CloneEmoteNearestPlayer()
    local ClosestPlayer, ClosestDistance = nil, nil
    local myCoords = GetEntityCoords(PlayerPedId())
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local distance = #(myCoords - GetEntityCoords(GetPlayerPed(player)))
            if ClosestDistance == nil or distance < ClosestDistance then
                ClosestPlayer = player
                ClosestDistance = distance
            end
        end
    end
    if ClosestPlayer ~= nil and ClosestDistance < Config.NearbyRadius then
        TriggerServerEvent("pop_emotes:CloneEmote", GetPlayerServerId(ClosestPlayer))
    else
        EmoteNotify({
            type = 'ROUGE',
            content = L('no_player_nearby')
        })
    end
end

function GetCurrentEmote()
    return current_emote
end

function GetCurrentEmoteName()
    return current_emote_name
end

function CopyEmoteFromPlayer(targetServerId)
    TriggerServerEvent("pop_emotes:CopyEmoteFromPlayer", targetServerId)
end

function GetClosestPlayer(radius)
    local ClosestPlayer, ClosestDistance = nil, nil
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local ped = GetPlayerPed(player)
            local coords = GetEntityCoords(ped)
            local distance = #(playerCoords - coords)
            if ClosestDistance == nil or distance < ClosestDistance then
                ClosestPlayer = player
                ClosestDistance = distance
            end
        end
    end

    if ClosestPlayer ~= nil and ClosestDistance <= radius then
        return ClosestPlayer
    else
        return nil
    end
end