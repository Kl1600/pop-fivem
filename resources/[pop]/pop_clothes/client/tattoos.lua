-- Liste des tatouages (reçue du serveur) et tatouages portés par le joueur.

-- Tattoo List (Expanded)
local TattooList = { Head = {}, Torso = {}, LeftArm = {}, RightArm = {}, LeftLeg = {}, RightLeg = {} }

RegisterNetEvent('clothes:setTattooList')
AddEventHandler('clothes:setTattooList', function(rawJson)
    local rawTattoos = json.decode(rawJson)
    if rawTattoos then
        local mapping = {
            ZONE_HEAD = "Head",
            ZONE_TORSO = "Torso",
            ZONE_LEFT_ARM = "LeftArm",
            ZONE_RIGHT_ARM = "RightArm",
            ZONE_LEFT_LEG = "LeftLeg",
            ZONE_RIGHT_LEG = "RightLeg"
        }
        TattooList = { Head = {}, Torso = {}, LeftArm = {}, RightArm = {}, LeftLeg = {}, RightLeg = {} }
        for zoneId, tattoos in pairs(rawTattoos) do
            local mappedZone = mapping[zoneId]
            if mappedZone then
                for _, t in ipairs(tattoos) do
                    table.insert(TattooList[mappedZone], t)
                end
            end
        end
    else
        print("[pop_clothes] Error: Failed to decode tattoo list from server!")
    end
end)

CreateThread(function()
    Wait(1000)
    TriggerServerEvent('clothes:requestTattooList')
end)

function Clothes.BuildTattooList()
    local pedModel = GetEntityModel(PlayerPedId())
    local isFemale = pedModel == GetHashKey("mp_f_freemode_01")

    local ret = { Head = {}, Torso = {}, LeftArm = {}, RightArm = {}, LeftLeg = {}, RightLeg = {} }
    for zone, tattoos in pairs(TattooList) do
        for i, t in ipairs(tattoos) do
            local hashToUse = isFemale and t.hashFemale or t.hashMale
            if hashToUse and hashToUse ~= "" then
                table.insert(ret[zone], {
                    collection = t.collection,
                    hash = hashToUse,
                    label = t.label or L('tattoo_default', i)
                })
            end
        end
    end
    return ret
end

RegisterNetEvent('clothes:applyTattoos')
AddEventHandler('clothes:applyTattoos', function(tattoos)
    local ped = PlayerPedId()
    ClearPedDecorations(ped)
    Clothes.currentTattoos = {}
    for _, t in ipairs(tattoos or {}) do
        if t.collection and t.hash then
            local col = type(t.collection) == 'string' and GetHashKey(t.collection) or t.collection
            local hsh = type(t.hash) == 'string' and GetHashKey(t.hash) or t.hash
            AddPedDecorationFromHashes(ped, col, hsh)
            Clothes.currentTattoos[#Clothes.currentTattoos + 1] = t
        end
    end
end)

AddEventHandler('playerSpawned', function()
    Citizen.SetTimeout(2000, function()
        TriggerServerEvent('clothes:requestTattoos')
    end)
end)

AddEventHandler('esx:playerLoaded', function()
    Citizen.SetTimeout(3000, function()
        TriggerServerEvent('clothes:requestTattoos')
    end)
end)
