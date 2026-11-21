-- =====================================================
--  Module CHARGEURS (ex tab_chargeurs) — CLIENT
--  Munitions de l'arme = balles du chargeur inséré (serveur autoritaire), uniquement
--  pour les armes avec puits de chargeur. lib.callback remplacé par ESX callback.
-- =====================================================
local ESX = exports['es_extended']:getSharedObject()

local ManagedHashes = {}
CreateThread(function()
    for _, w in pairs(ChargeursConfig.Weapons or {}) do
        ManagedHashes[GetHashKey(w.weaponHash)] = true
    end
end)

local currentHash   = nil
local managedWeapon = false
local lastAmmo      = 0
local lastResync    = 0

-- Renvoie le nombre de balles, ou -1 si l'arme n'est pas gérée. ESX callback (sync via promise).
local function fetchRounds(hash)
    local p = promise.new()
    ESX.TriggerServerCallback('pop_chargeurs:getRounds', function(rounds)
        p:resolve(rounds)
    end, hash)
    local rounds = Citizen.Await(p)
    if type(rounds) == 'number' then return rounds end
    return -1
end

local function applyRounds(ped, hash, rounds)
    if rounds < 0 then
        managedWeapon = false
        lastAmmo = GetAmmoInPedWeapon(ped, hash)
        return
    end
    managedWeapon = true
    SetPedAmmo(ped, hash, rounds)
    lastAmmo = rounds
end

local function syncWeapon(ped, hash)
    local rounds = fetchRounds(hash)
    local stillHas, stillHash = GetCurrentPedWeapon(ped, true)
    if stillHas and stillHash == hash then
        applyRounds(ped, hash, rounds)
    end
end

local function resyncCurrent()
    if not currentHash then return end
    local ped = PlayerPedId()
    if IsPedShooting(ped) then return end
    local rounds = fetchRounds(currentHash)
    local stillHas, stillHash = GetCurrentPedWeapon(ped, true)
    if stillHas and stillHash == currentHash then
        applyRounds(ped, currentHash, rounds)
    end
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local has, hash = GetCurrentPedWeapon(ped, true)
        local managed = (has and ManagedHashes[hash]) and hash or nil

        if managed then
            if managed ~= currentHash then
                currentHash = managed
                syncWeapon(ped, managed)
            elseif managedWeapon then
                local cur = GetAmmoInPedWeapon(ped, managed)
                if cur < lastAmmo then
                    local delta = lastAmmo - cur
                    lastAmmo = cur
                    TriggerServerEvent('pop_chargeurs:server:consumed', managed, delta)
                elseif cur > lastAmmo then
                    lastAmmo = cur
                end
            end
            Wait(50) -- suivi par delta : pas besoin de chaque frame
        else
            currentHash = nil
            managedWeapon = false
            Wait(250)
        end
    end
end)

-- Resynchro sur changement d'inventaire (swap de chargeur).
RegisterNetEvent('pop_inventory:client:state', function()
    local now = GetGameTimer()
    if now - lastResync < ChargeursConfig.SyncCooldown then return end
    lastResync = now
    resyncCurrent()
end)
