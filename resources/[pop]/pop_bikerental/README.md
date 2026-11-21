# pop_bikerental

Rent bikes and scooters at fixed counters. The player pays **price + deposit** when renting, and gets the deposit
back when the vehicle is returned undamaged to **any** counter. Idle cost: no loop without an active rental.

## Requirements
- **OneSync** (vehicles are created server-side).
- Works with ESX, QBCore, Qbox or standalone (auto-detected). ox_target / qb-target optional (native prompt otherwise).
- Optional: `pop_vehiclekeys` (key given on rent, removed on return).
- No database.

## Installation
1. Drop `pop_bikerental` into `resources/[pop]/`.
2. In `server.cfg`, start your framework (and inventory / target) **before** `[pop]`:
   ```
   ensure es_extended   # or qb-core / qbx_core
   ensure [pop]
   ```
3. Edit `config.lua` (language, account, prices, locations).

## How it works
1. **Rent**: at a counter, pick a vehicle (`Rent BMX ($150)`). The server charges price + deposit and spawns the
   vehicle on the location's spot (the spot must be free).
2. **Ride**: a small timer shows while riding the rented vehicle, and always during the last 2 minutes.
   A warning is sent 2 minutes before the end.
3. **Return**: park next to any counter, get off, and choose `Return the vehicle`. The deposit is refunded if
   engine and body health are both above 300.
4. **Expiry** (`Config.Duration` minutes), destruction, disconnect or character switch: the vehicle is removed and
   the deposit is kept.

One rental per player. Rented vehicles carry the `pop_temporary = true` and `fuel = 100.0` state bags.
Rentals do not survive a resource restart (vehicles are deleted, no refund).
If the player disconnects while the vehicle is being created (a fraction of a second after paying), the rental is
cancelled and refunded only if the framework still knows the player; otherwise the amount cannot be refunded.
With `Config.Deposit = 0`, notifications simply say the vehicle was rented / returned.

## Configuration
| Key | Default | Description |
|---|---|---|
| `Config.Account` | `'cash'` | `'cash'` or `'bank'` |
| `Config.Duration` | `30` | rental length in minutes |
| `Config.Deposit` | `100` | deposit refunded on an undamaged return |
| `Config.Vehicles` | bmx, cruiser, faggio | `{ model, price, type }` (`type` = `GetVehicleType`, `'bike'` for bikes and scooters) |
| `Config.Locations` | 2 points | `{ coords = vec3 (counter), spawn = vec4 (spot + heading), blip = bool }` |

Common keys (`Config.Locale`, `Config.Framework`, `Config.Target`, `Config.AccentColor`, ...) are documented in the
POP base template.

**Standalone** (no money system): set every `price` and `Config.Deposit` to `0`, otherwise renting always fails
with "Not enough money".

## Languages
`en` (default and fallback), `fr`, `es`, `de`, `it`, `pt`, `nl`, `pl`, `tr`, `ar` (right-to-left) in `locales/`.
To add one, copy `locales/en.lua` and change the code.

## Server exports
```lua
exports.pop_bikerental:GetRental(src)  -- { plate, expires } | nil
exports.pop_bikerental:IsRental(plate) -- boolean
```

## Security
The client only sends a location index and a vehicle index. Model, price, deposit, spawn spot and plate come from
the config and the server. Distance, single rental, free spot and per-player lock are checked server-side; the
rental is cleared before the vehicle is deleted and before any refund (no double deposit).
