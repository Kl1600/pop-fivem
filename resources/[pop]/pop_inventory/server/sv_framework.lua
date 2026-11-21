ESX = nil
QBCore = nil

if Config.Framework == 'esx' then
  ESX = exports['es_extended']:getSharedObject()
elseif Config.Framework == 'qbcore' then
  if GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
  end
end

math.randomseed(os.time())

Stores = {}
GroundStore = { items = {}, containers = {}, itemLocations = {}, containerOwners = {} }
GroundPiles = {}
PlayerCoords = {}
PlayerGroundFocus = {}
StateSeq = {}
idCounter = 0
RemoteContainers = {}
StandbyContainers = {} -- [src] = containerId

