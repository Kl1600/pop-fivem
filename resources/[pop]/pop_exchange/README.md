# pop_exchange

Currency exchange desk. A money changer NPC converts one currency into another at a **fixed rate**: dollars to
pesos and back at a public desk, or dirty money to clean cash at a hidden spot (worse rate, risk of a police alert).
Each **offer** converts a money account (`cash`, `bank`, `black`) or an item into another account or item.
Idle cost: no `Wait(0)`, one local NPC loop (1000 / 2500 ms), no server loop.

## Requirements
- Works with ESX, QBCore, Qbox or standalone (auto-detected). ox_target / qb-target optional (native prompt otherwise).
- Inventory auto-detected: pop_inventory, ox_inventory, qs-inventory, qb-inventory, ps-inventory or the framework one.
- No database.

## Installation
1. Drop `pop_exchange` into `resources/[pop]/`.
2. In `server.cfg`, start your framework (and inventory / target) **before** `[pop]`:
   ```
   ensure es_extended   # or qb-core / qbx_core
   ensure ox_inventory  # optional
   ensure [pop]
   ```
3. Declare the `pesos` item (see below), or remove the peso offers.
4. Edit `config.lua` (language, offers, locations).

## How it works
1. Talk to the money changer (`[E] Talk to the money changer`).
2. A small panel on the right lists the offers of this desk, your balance, the amount still available this hour and
   a live "You receive" preview. `Max` fills in the largest possible amount.
3. Confirm (button or Enter): the server checks everything and exchanges. The result shows in the panel.

Rules:
- Amounts are whole numbers; the received amount is rounded down (an exchange giving less than 1 is refused).
- **Hourly limit** per player and per offer (sliding 60-minute window, counted in the currency given). Limits are
  kept in memory by character identifier: they survive a reconnect, not a resource restart.
- `alert` offers may warn on-duty police (`Config.Police.jobs`) with a notification and a temporary map blip.
- The exchange is atomic: if the player cannot receive the result, what was taken is given back.

## Configuration
| Key | Description |
|---|---|
| `Config.Offers` | `id = { from, to, rate, limit, alert }` |
| `Config.Locations` | `{ coords = vector4, ped = model or false, blip = bool, offers = { ids } }` |
| `Config.Blip` | `{ sprite, color, scale }` of desk blips |
| `Config.Police` | `jobs` (`Bridge.HasJob` format, must be on duty), `blipTime` (seconds) |

Common keys (`Config.Locale`, `Config.Framework`, `Config.Target`, `Config.AccentColor`, ...) are documented in the
POP base template.

### Writing an offer
```lua
Config.Offers = {
    -- from / to: { money = 'cash' | 'bank' | 'black' } or { item = 'item_name' }
    -- rate:  amount received for 1 given (rounded down)
    -- limit: max amount given per hour and per player (integer)
    -- alert: chance (0.0 - 1.0) to alert the police on each exchange
    gold_cash = { from = { item = 'goldbar' }, to = { money = 'cash' }, rate = 500.0, limit = 50, alert = 0.0 },
}
```
Then add its id to a location's `offers`. Each desk only proposes its own offers, so laundering can live away
from the public desk. Invalid offers (unknown id, `rate <= 0`, non-integer `limit`) are reported in the server
console at start.

Currency labels come from the locales: `currency_<name>` (`currency_cash`, `currency_pesos`, `currency_goldbar`...).
Add the key to the 10 files in `locales/` for any new currency.

### Dirty money on QBCore / Qbox (`markedbills`)
ESX has a `black_money` account, used by `{ money = 'black' }`. QBCore and Qbox have **no** black money account by
default: the bridge returns 0, so the `launder` offer always answers "You don't have enough". Use the
`markedbills` item instead:
```lua
launder = { from = { item = 'markedbills' }, to = { money = 'cash' }, rate = 0.7, limit = 20000, alert = 0.15 },
```
Note: `markedbills` usually carries a `worth` value in its metadata; this offer counts **items** (one bill = 1),
so adjust `rate` and `limit` to your economy (e.g. `rate = 700.0, limit = 20` if a bill is worth about $1,000).
The label `currency_markedbills` is already in every locale.

### The `pesos` item
**ox_inventory** (`ox_inventory/data/items.lua`):
```lua
['pesos'] = { label = 'Pesos', weight = 0, stack = true, close = true },
```
**qb-inventory / QBCore** (`qb-core/shared/items.lua`):
```lua
pesos = { name = 'pesos', label = 'Pesos', weight = 0, type = 'item', image = 'pesos.png', unique = false, useable = false, shouldClose = false, description = 'Mexican pesos' },
```
**qs-inventory**: add the same entry to its items file.
**ESX default inventory** (SQL):
```sql
INSERT INTO `items` (`name`, `label`, `weight`) VALUES ('pesos', 'Pesos', 0);
```

## Languages
`en` (default and fallback), `fr`, `es`, `de`, `it`, `pt`, `nl`, `pl`, `tr`, `ar` (right-to-left) in `locales/`.
To add one, copy `locales/en.lua` and change the code.

## Exports
Server:
```lua
exports.pop_exchange:GetRate(id)        -- number | nil
exports.pop_exchange:ResetLimits(src)   -- boolean: clears the player's hourly limits
```
Client:
```lua
exports.pop_exchange:IsOpen()           -- boolean: panel open
```
