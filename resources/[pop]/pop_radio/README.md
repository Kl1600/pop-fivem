# pop_radio

Item radio (talkie-walkie) for **pma-voice**, with a small, clean interface.
Works with ESX, QBCore, Qbox and standalone (auto-detected). No database.

## Requirements
- **pma-voice** (required for voice). The script starts without it but refuses every connection.
- An inventory that knows the `radio` item (ox_inventory, qb/qs/ps-inventory, pop_inventory or the framework inventory).

## Installation
```cfg
ensure pma-voice
ensure ox_inventory   # or your inventory / framework
ensure [pop]          # pop_radio must start after pma-voice and the framework
```

## The item
Declare `Config.Item` (default `radio`) in your inventory:

- **ox_inventory** (`data/items.lua`): `['radio'] = { label = 'Radio', weight = 200, stack = false, close = true },`
- **QBCore** (`qb-core/shared/items.lua`): `radio = { name = 'radio', label = 'Radio', weight = 200, type = 'item', image = 'radio.png', unique = true, useable = true, shouldClose = true },`
- **ESX** (SQL): `INSERT INTO items (name, label, weight) VALUES ('radio', 'Radio', 1);`

Using the item opens the radio. Players can also bind a key in FiveM settings (command `pop_radio_open`,
default key `Config.OpenKey`).

## Configuration (`config.lua`)
| Key | Default | Role |
|---|---|---|
| `Config.Item` | `'radio'` | radio item |
| `Config.OpenKey` | `''` | default key (empty = none) |
| `Config.MaxFrequency` | `999` | frequencies 1 to max (integers) |
| `Config.Reserved` | police/sheriff 1-10, ambulance 11-20 | reserved ranges, `Bridge.HasJob` format, on duty only |
| `Config.CheckInterval` | `15` | seconds between item/job checks for players on the radio |

## Security
- The server places players on channels (`setPlayerRadio`) and adds a pma-voice `addChannelCheck` on every
  channel: no channel can be joined without the item (and the job + on duty for reserved ranges).
- Players who lose the item, the job or duty are disconnected at the next check.

## Exports
```lua
-- client
exports.pop_radio:GetFrequency()      -- int, 0 = off
-- server
exports.pop_radio:GetFrequency(src)   -- int
exports.pop_radio:TurnOff(src)        -- bool, false if not on the radio
```

## Limits
- pma-voice is mandatory for voice.
- Another script calling `setPlayerRadio` server-side bypasses these checks (trusted server export).
- Integer frequencies only.
- pma-voice keeps a single `addChannelCheck` per channel: another script that adds checks on channels
  1 to `Config.MaxFrequency` replaces ours (or ours replaces theirs, depending on start order).
- The hand radio prop is a networked object (visible to everyone). On servers that lock client entity creation
  (entity lockdown), it is simply not shown; voice is unaffected.
- Stopping or restarting `pop_radio` disconnects every radio; on start, players still on a pma-voice channel they are
  allowed to use are kept, the others are disconnected.
- Languages: `Config.Locale` (en, fr, es, de, it, pt, nl, pl, tr, ar).
