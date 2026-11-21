# pop_doorlock

Door lock system based on the native GTA door system, with an in-game editor.
ESX (Legacy and old), QBCore, Qbox and standalone. ox_target / qb-target or native prompt. 10 languages.

## Installation

1. Requires **oxmysql**. The tables are created automatically on start (`sql/install.sql` is optional).
2. `server.cfg`, framework and inventory **before** `[pop]`:
   ```cfg
   ensure oxmysql
   ensure es_extended   # or qb-core / qbx_core
   ensure ox_inventory  # or your inventory
   ensure [pop]
   ```
3. Admin access to the editor (`/doorlock`): ACE `pop.admin` or the framework admin group.
   ```cfg
   add_ace group.admin pop.admin allow
   ```
4. Settings and language: `config.lua` (`Config.Locale = 'en'`).

## Items

| Item | Use |
|---|---|
| `lockpick` (`Config.Lockpick.Item`) | Lockpicking (security levels 0 and 1) |
| `door_key` (`Config.KeyItem`) | Door key, bound to a group by the `pop_door` metadata |

Item labels: use the translations of `item_lockpick` and `item_key` from `locales/<lang>.lua`
(English below: `Lockpick`, `Door key`).

Lockpicking needs an inventory to hold the `lockpick` item (ox_inventory works in standalone).

ox_inventory (`data/items.lua`):
```lua
['lockpick'] = { label = 'Lockpick', weight = 100 },
['door_key'] = { label = 'Door key', weight = 50, stack = false },
```

QBCore (`qb-core/shared/items.lua`):
```lua
lockpick = { name = 'lockpick', label = 'Lockpick', weight = 100, type = 'item', image = 'lockpick.png', unique = false, useable = false, shouldClose = true, description = '' },
door_key = { name = 'door_key', label = 'Door key', weight = 50, type = 'item', image = 'door_key.png', unique = true, useable = false, shouldClose = true, description = '' },
```

ESX (`items` table):
```sql
INSERT IGNORE INTO `items` (`name`, `label`, `weight`) VALUES ('lockpick', 'Lockpick', 1), ('door_key', 'Door key', 1);
```

Keys need an inventory that stores item metadata: ox_inventory, qs-inventory, qb-inventory, ps-inventory,
pop_inventory, or the QBCore / Qbox framework inventory. With the basic ESX inventory or in standalone, keys are
disabled: use jobs, lockpicking and exports.

## Usage

- `/doorlock`: create a group (name, locked on start, distance, security, alert, jobs, key), then **Add a door**:
  aim at a door leaf, [E] select (2 max for a double door), [ENTER] confirm, [X] cancel.
- Access: one of the group jobs (with minimum grade) **or** a key of the group. Resetting a key invalidates all old keys.
  Note: the job check (`Bridge.HasJob`) ignores on-duty status: an off-duty officer keeps access.
- Security: `0` pickable, `1` hard, `2` cannot be picked. No lockpicking from a vehicle.
  Note: the mini-game result is reported by the client. The server checks the session time, the door, the distance and
  the tool, and still rolls `failChance` (per level, `config.lua`) even on a success: raise it to make cheating pointless.
- The current state is not saved: on server start, each door takes the "locked on start" state of its group.

## Exports (server)

```lua
exports.pop_doorlock:GetDoorState(doorId)            -- true / false, nil = unknown door
exports.pop_doorlock:SetDoorState(doorId, locked)    -- bool (no access check)
exports.pop_doorlock:SetGroupState(groupId, locked)  -- bool, every door of the group
exports.pop_doorlock:HasAccess(source, groupId)      -- bool (job or key)
exports.pop_doorlock:GiveKey(source, groupId)        -- bool
```

## Export (client)

```lua
local doorId, distance, locked = exports.pop_doorlock:GetClosestDoor()
```

Group and door ids (`#id`) are shown in the editor.

## Event (server, local)

```lua
AddEventHandler('pop_doorlock:lockpickAlert', function(src, coords, groupId)
    -- lockpick attempt on a group with "alert" enabled: plug your dispatch here
end)
```
