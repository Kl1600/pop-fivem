# pop_inventory

POP inventory with slots, weight, per-item metadata, a 1–5 hotbar, weapons as items, ground storage, trunks and gloveboxes by plate, stashes, shops, searches, and optional physical cash. Weapon items track serial number, ammunition, and durability. Supports ESX Legacy, older ESX, QBCore, Qbox (see below), and standalone. Ten languages, including RTL for Arabic.

## Installation

1. Install **oxmysql**, the only required dependency.
2. Copy `pop_inventory` into `resources/[pop]/`.
3. The resource creates its tables on startup. Use `sql/install.sql` if you prefer a manual import.
4. Start **pop_inventory before the other POP scripts**. The Bridge detects the inventory on startup.

   ```
   ensure oxmysql
   ensure es_extended        # or qb-core / qbx_core
   ensure pop_inventory
   ensure [pop]
   ```

5. Run a single inventory resource. Starting ox_inventory, qs-inventory, qb-inventory, or ps-inventory alongside pop_inventory produces a console error.
6. Grant admin access with `add_ace group.admin pop.admin allow` to use `/giveitem [id] [item] [count]`.

## Frameworks

- **ESX Legacy.** `Config.FrameworkHooks` routes `xPlayer` inventory methods such as `addInventoryItem` and `getInventoryItem` to pop_inventory. After a hot restart of pop_inventory, connected players must reconnect to restore these hooks. Set **`Config.CustomInventory = true`** in es_extended to prevent duplicate loading and saving by ESX, which produces a red console warning at startup. Check the setting against your ESX version and use the boolean `true` where supported.
- **Older ESX.** This version lacks the hook mechanism. Scripts must use the exports or Bridge to see items. The resource logs a warning.
- **QBCore.** `Player.Functions.AddItem`, `RemoveItem`, `GetItemByName`, `GetItemsByName`, `GetItemBySlot`, and `ClearInventory` route to pop_inventory. `PlayerData.items` stays current.
- **Qbox.** `qbx_core` requires ox_inventory. Uncomment `-- provide 'ox_inventory'` in `fxmanifest.lua` to run pop_inventory in its place. Validate this configuration against your server's Qbox version. The resource provides the common ox_inventory server exports. Register usable items through `RegisterUsableItem`. Items registered through `exports.qbx_core:CreateUseableItem` are called as a fallback, depending on your qbx_core version.
- **Standalone.** There are no money accounts. The optional cash item works like a normal item.

On a character's first load, the resource imports the previous framework inventory if `Config.ImportFramework` is enabled and imports framework item definitions missing from `data/items.lua`.

## Items

- Define items in `data/items.lua` with weights in grams. Fields include `label`, `weight`, `stack`, `close`, `description`, `image`, `consume`, `weapon`, `ammo`, `clip`, and `degrade`.
- `consume` sets how many items the inventory removes when a player uses an item registered with `RegisterUsableItem`. The inventory removes them before calling the callback and restores them if the callback returns `false` or throws. Set `consume = 0` when your own script handles removal.
- Translate labels with `item_<name>` and descriptions with `desc_<name>` in `locales/*.lua`.
- Place images in `web/images/<name>.png` or set `image` or `metadata.image`. Missing icons use the fallback image.
- Set `Config.CashItem = 'money'` to synchronize the item with the framework's `cash` account.

## Server exports

Common exports use ox_inventory names. `inv` accepts a server ID, an inventory ID (`'stash:<id>'`, `'trunk:<PLATE>'`, or `'glovebox:<PLATE>'`), a stash name, or `{ id, owner }`. Exports work on loaded inventories such as an online player, registered stash, or recently opened trunk. They do not query SQL.

| Export | Return value |
|---|---|
| `Items(name?)` | Item definition or definitions |
| `AddItem(inv, item, count, metadata?, slot?)` | `true` \| `false, reason` |
| `RemoveItem(inv, item, count, metadata?, slot?)` | `true` \| `false, reason` |
| `GetItemCount(inv, item, metadata?, strict?)` | number |
| `Search(inv, 'count' \| 'slots', items, metadata?)` | Same behavior as ox_inventory |
| `CanCarryItem(inv, item, count, metadata?)` / `CanCarryWeight(inv, weight)` | bool |
| `GetItem`, `GetSlot`, `GetSlotWithItem`, `GetSlotsWithItem` | Item or items |
| `SetMetadata(inv, slot, metadata)` / `SetDurability(inv, slot, value)` | bool |
| `GetInventory(inv)` / `GetInventoryItems(inv)` / `ClearInventory(inv, keep?)` | |
| `RegisterStash(id, label, slots, maxWeight, owner?, groups?, coords?)` | bool |
| `RegisterShop(id, data)` | bool |
| `forceOpenInventory(src, invType, data)` | bool |
| `RegisterUsableItem(item, cb(src, item, metadata, slot))` | true |
| `GetCurrentWeapon(src)` | Equipped weapon item in `GetSlot` format \| `nil` |

`RegisterStash` loads a shared stash in the background and retries on database failure. Exports may return `not_loaded` immediately after registration.

```lua
exports.pop_inventory:AddItem(source, 'water_bottle', 2)
exports.pop_inventory:RegisterUsableItem('bandage', function(src, item, metadata, slot)
    -- ...
end)
```

Server events are `pop_inventory:usedItem (src, name, slot, metadata)`, `pop_inventory:openedInventory (src, invId)`, and `pop_inventory:closedInventory (src, invId)`. Client events are `pop_inventory:itemCount (name, count)` and `pop_inventory:currentWeapon (weapon | nil)`. Setting the `invBusy` state bag to `true` blocks opening and using the inventory.

Client export `openInventory(type, data)` returns `true` once it sends the request to the server. It returns `false` for invalid arguments or an inventory that is still loading.

## Configuration

Set slots, weights, keys, ground storage, vehicles, stashes, shops, and save options in `config.lua`. Keep `Config.Inventory = 'none'`.

## Database

- If table creation fails, the server logs a red error and retries every 10 seconds. Loading and saving pause until the tables are ready. A container whose SQL query fails stays closed and its stored contents are preserved.
- On a hot restart with players connected (`restart pop_inventory`), the resource waits about 1.5 seconds before reloading inventories so pending saves can finish. Prefer a server restart, especially with ESX Legacy hooks.

## Performance

The server saves changed inventories every `Config.SaveInterval` seconds. The client runs a per-frame loop only while a weapon is equipped.
