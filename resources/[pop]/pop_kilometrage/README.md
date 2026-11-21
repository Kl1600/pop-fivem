# pop_kilometrage

Persistent per-plate odometer for FiveM. The distance is measured **server-side only** (the client sends nothing),
saved with oxmysql and shown as a small, discreet badge at the bottom right while you are in a vehicle.

- ESX, QBCore, Qbox and standalone (auto-detected).
- ~0.00 ms: one 1 s client loop, one 2 s server loop, batched SQL writes every 60 s.
- 10 languages (en, fr, es, de, it, pt, nl, pl, tr, ar with RTL).
- Ignored: helicopters, planes, boats, submarines, trains and vehicles flagged `pop_temporary`.
- Teleports, respawns and impounds are ignored (samples above 120 m/s are discarded).

## Installation

1. Requires [oxmysql](https://github.com/overextended/oxmysql) and **OneSync** (enabled by default on recent servers;
   the distance is read from server-side entity positions).
2. Copy `pop_kilometrage` into `resources/[pop]/`.
3. The table is created automatically on start (or run `sql/install.sql`).
4. In `server.cfg`, start your framework and oxmysql **before** the POP scripts:
   ```cfg
   ensure oxmysql
   ensure es_extended   # or qb-core / qbx_core
   ensure [pop]
   ```

## Configuration (`config.lua`)

| Key | Default | Description |
|---|---|---|
| `Config.Locale` | `'en'` | en, fr, es, de, it, pt, nl, pl, tr, ar |
| `Config.Unit` | `'km'` | `'km'` or `'mi'` (the database always stores km) |
| `Config.Hud` | `true` | show the odometer while in a vehicle |
| `Config.AccentColor` | `'#ff2e88'` | UI accent colour |

A vehicle is only stored in the database once it reaches 1 km, so borrowed NPC cars do not fill the table.

## Exports

### Server

```lua
-- Mileage in km (1 decimal). Blocking if the plate is not cached: call it inside a thread.
local km = exports.pop_kilometrage:GetMileage('ABC123')

-- Set the mileage (0 to 9 999 999 km). Saved immediately. Returns true on success.
exports.pop_kilometrage:SetMileage('ABC123', 0)
```

Example: a dealership resets the odometer of a brand-new car.

```lua
local plate = GetVehicleNumberPlateText(vehicle)
exports.pop_kilometrage:SetMileage(plate, 0)
```

### Client

```lua
-- Mileage (km) of the current vehicle, or nil on foot / unknown.
local km = exports.pop_kilometrage:GetMileage()
```

The value is also available as the replicated entity state bag `pop_kilometrage`
(`Entity(vehicle).state.pop_kilometrage`, km rounded to 0.1).

## Security

- Distance, plate and driver are read on the server; there is no network event a client could abuse.
- Exports are server-side and validate their inputs.
