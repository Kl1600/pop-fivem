-- Socle du serveur pop_inventory, chargé juste après bridge/server.lua (voir fxmanifest).
-- Les fichiers server/sv_*.lua partagent leurs fonctions et leur état en globales
-- (même environnement que l'ancien chargement par server.lua) ; Inv regroupe les
-- fonctions communes ajoutées au découpage.

TabInventory = TabInventory or {}
TabInventory.resourceName = GetCurrentResourceName()

Inv = Inv or {}

-- ESX direct : comptes bancaires, sociétés, jobs, joueur par identifier (hors bridge).
-- pop_inventory est l'inventaire détecté par le bridge : pour les objets et l'argent
-- liquide, il utilise ses fonctions internes (jamais Bridge.AddItem / GetMoney ici).
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

local NOTIFY_ICONS = {
  success = 'fas fa-circle-check',
  error   = 'fas fa-triangle-exclamation',
  info    = 'fas fa-circle-info',
}

--- Notification { title, message, type, duration } : icône déduite du type si absente
--- (même rendu que l'ancien event 'notification:client:send').
function Inv.NotifyTyped(src, data)
  if not data.icon then data.icon = NOTIFY_ICONS[data.type or 'info'] or NOTIFY_ICONS.info end
  Bridge.Notify(src, data)
end
