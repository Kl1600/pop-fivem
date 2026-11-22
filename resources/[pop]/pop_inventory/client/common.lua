-- Table commune du client pop_inventory : état et fonctions partagés entre les fichiers client/.
-- Chargé juste après bridge/client.lua (voir fxmanifest).

Inv = Inv or {}

-- ESX direct : utilisé par les modules pour ce que le bridge ne couvre pas
-- (ESX.Game.*, KeyboardInput, ShowHelpNotification, DrawMissionText, données radio).
ESX = exports['es_extended']:getSharedObject()

--- Notification simple du script (style d'origine : icône info, 4 s).
function Inv.Notify(message)
  Bridge.Notify({ message = message, icon = 'fas fa-info', duration = 4000 })
end

local NOTIFY_ICONS = {
  success = 'fas fa-circle-check',
  error   = 'fas fa-triangle-exclamation',
  info    = 'fas fa-circle-info',
}

--- Notification { title, message, type, duration } : icône déduite du type si absente
--- (même rendu que l'ancien pont 'notification:client:send').
function Inv.NotifyTyped(data)
  if not data.icon then data.icon = NOTIFY_ICONS[data.type or 'info'] or NOTIFY_ICONS.info end
  Bridge.Notify(data)
end
