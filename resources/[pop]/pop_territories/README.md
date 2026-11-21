# pop_territories

Crew territory control with influence by zone, captures, and sale-price bonuses for pop_dealing. Supports ESX Legacy and older ESX, QBCore, Qbox, and standalone. Ten languages. Idle target of ~0.00 ms.

## Installation

1. Install `oxmysql`. Optional integrations are `pop_crew` for player crews and `pop_dealing` for sales.
2. Copy `pop_territories` into `resources/[pop]/`.
3. Start the framework and oxmysql before `[pop]` in `server.cfg`:

   ```
   ensure oxmysql
   ensure es_extended   # or qb-core / qbx_core
   ensure [pop]
   add_ace group.admin pop.admin allow
   ```

4. The tables are created on startup. For a manual import, use `sql/install.sql`.

## Crew membership

The resource checks crew membership on every call:

1. With `pop_crew` running, `GetPlayerCrew` determines membership. A player without a crew there has no crew here.
2. Without `pop_crew`, if `Config.UseJobsAsCrews = true` on ESX, QBCore, or Qbox, jobs listed in `Config.JobCrews` act as crews.
3. Otherwise, including standalone without pop_crew, influence is disabled and zones, blips, and HUD remain active.

## How territories work

- Each crew has 0–100 influence per zone. The total for a zone cannot exceed 100.
- Sales add `PerSale` influence in the zone. One sale counts per player every `SaleCooldown` seconds.
- Each minute, living members in the zone add `PerTick`. Dead or downed players do not count. Presence stays below the capture threshold for crews that do not own the zone.
- Absence subtracts `Decay` each minute.
- A crew captures the zone at `Capture` (60) and holds it while influence stays at or above `Keep` (30).
- Prices apply `zone.price` and then `Prices.Owner` for sellers from the owning crew or `Prices.Rival` when another crew controls the zone. These multiply the pop_dealing area `mult`, which applies first. For example, Vespucci can apply 1.2 (pop_dealing) × 1.0 (`zone.price`) × 1.25 (owner). Keep `price = 1.0` if pop_dealing already sets the area's price.

## pop_dealing integration

A sale is required to capture a zone because presence caps below `Capture`. Cover each territory with a selling area in pop_dealing's `Config.Zones`. Update the selling areas when moving or adding a territory.

## Configuration (`config.lua`)

| Key | Purpose |
|---|---|
| `UseJobsAsCrews`, `JobCrews` | Job crews for servers without pop_crew, formatted as `job = '#rrggbb'` |
| `Influence` | `PerSale`, `PerTick`, `Decay`, `Capture` (51–100), `Keep` (< Capture), `SaleCooldown` |
| `Prices` | `Owner`, `Rival` |
| `RivalAlertCooldown` | Seconds between rival alerts per zone (0 disables rival alerts) |
| `ZoneBlips` | Colored zones on the map |
| `HudDuration` | HUD display time in seconds (0 keeps it visible inside the zone) |
| `Commands` | `Info` (`/territory`), `Admin` (`/territoryadmin`) |
| `Zones` | `{ id, label, center, radius }` or `{ id, label, points = { vec2, ... } }`, with optional `price` (0.1–10) |

`label` accepts a translation key from `locales/*.lua` or plain text.

## Server exports

```lua
-- Call before paying. Returns the final integer amount and territory details.
local final, info = exports.pop_territories:RecordDrugSale(source, coords, amount)
-- info = { zone = 'grove' | nil, owner = { key, label, color } | nil, mult = 1.25, rival = false }

local zoneId, label = exports.pop_territories:GetZoneAt(coords)
local owner = exports.pop_territories:GetZoneOwner('grove') -- { key, label, color } | nil
```

Local server event: `AddEventHandler('pop_territories:ownerChanged', function(zoneId, newOwner, oldOwner) end)`.

## Client export

```lua
local zoneId = exports.pop_territories:GetCurrentZone()
```

## Admin command

`/territoryadmin` is available through ACE `pop.admin`, the framework admin group, or the server console.

- `info [zone]` shows the owner and influence values. Omit the zone to use the current one.
- `reset <zone|all>` resets one or all zones.
- `set <zone> <crew> <0-100>` accepts `crew:<id>` or `job:<name>` for the crew.

## Security

The resource has no client-to-server events. The server reads the player's position and crew, validates the amount, limits sales influence per player, and uses parameterized SQL. The calling resource handles payments.
