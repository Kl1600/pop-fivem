TabInventory = TabInventory or {}
TabInventory.resourceName = GetCurrentResourceName()

local serverModules = {
  'server/sv_framework.lua',
  'server/sv_database.lua',
  'server/sv_ground.lua',
  'server/sv_utils.lua',
  'server/sv_stores.lua',
  'server/sv_inventory_state.lua',
  'server/sv_sync.lua',
  'server/sv_actions.lua',
  'server/sv_exports.lua',
  'server/sv_remote_containers.lua',
  'server/sv_lockers.lua',
  'server/sv_player_items.lua',
  'server/sv_bank_vaults.lua',
  'server/sv_admin.lua'
}

for i = 1, #serverModules do
  local path = serverModules[i]
  local moduleSource = LoadResourceFile(TabInventory.resourceName, path)
  if not moduleSource then
    error(('[TAB_INVENTORY] Module serveur introuvable: %s'):format(path))
  end

  local chunk, err = load(moduleSource, ('@%s/%s'):format(TabInventory.resourceName, path), 't', _ENV)
  if not chunk then
    error(('[TAB_INVENTORY] Erreur de chargement module %s: %s'):format(path, err))
  end

  chunk()
end
