-- Animation « tablette en main » et objet tenu. Tout est supprimé à la fermeture et à l'arrêt de la ressource.

Tablet = Tablet or {}
Tablet.Client = Tablet.Client or {}
local C = Tablet.Client
C.Anim = {}
local A = C.Anim

local prop = nil
local playing = false
local generation = 0 -- invalide un démarrage en cours si la tablette est fermée entre-temps

-- Attente bornée (1 s au plus) du chargement d'une ressource du jeu.
local function waitFor(isLoaded)
    local tries = 0
    while not isLoaded() and tries < 100 do
        Wait(10)
        tries = tries + 1
    end
    return isLoaded()
end

--- Lance l'animation et attache l'objet. À appeler dans un thread (il attend le chargement).
function A.Start()
    generation = generation + 1
    local mine = generation
    local ped = PlayerPedId()
    local anim = Config.Anim
    RequestAnimDict(anim.dict)
    if waitFor(function() return HasAnimDictLoaded(anim.dict) end) and mine == generation then
        TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 49, 0.0, false, false, false)
        playing = true
    end
    local hash = joaat(Config.Prop.model)
    RequestModel(hash)
    if waitFor(function() return HasModelLoaded(hash) end) and mine == generation then
        local c = GetEntityCoords(ped)
        local o, r = Config.Prop.offset, Config.Prop.rot
        prop = CreateObject(hash, c.x, c.y, c.z, true, false, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, Config.Prop.bone),
            o.x, o.y, o.z, r.x, r.y, r.z, true, true, false, true, 1, true)
    end
    SetModelAsNoLongerNeeded(hash)
    if mine ~= generation then A.Stop() end
end

--- Arrête l'animation, supprime l'objet. Sans effet si rien n'est en cours.
function A.Stop()
    generation = generation + 1
    if prop then
        if DoesEntityExist(prop) then DeleteEntity(prop) end
        prop = nil
    end
    if playing then
        local anim = Config.Anim
        StopAnimTask(PlayerPedId(), anim.dict, anim.clip, 1.0)
        RemoveAnimDict(anim.dict)
        playing = false
    end
end

function A.HasProp()
    return prop ~= nil
end
