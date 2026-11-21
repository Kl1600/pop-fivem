# pop_enterprisegarage

Job garage for service vehicles. On-duty members of a job take a service vehicle out at the garage counter, then
store it again in the garage's parking zone. Each take-out gives a brand-new vehicle with a generated plate.

- Frameworks: ESX (Legacy and older), QBCore, Qbox, standalone (auto-detected).
- Interaction: ox_target, qb-target, otherwise a native [E] prompt.
- No dependency, no database. **OneSync is required** (vehicles are created server-side).
- Optional: `pop_vehiclekeys` (the key is given on take-out and taken back on storing).
- Server: no loop while no vehicle is out. Client: 2000 / 1500 / 500 ms loop, every frame only while driving a
  service vehicle inside a storage zone.
- 10 languages (`Config.Locale`): en, fr, es, de, it, pt, nl, pl, tr, ar.

## Installation

1. Put `pop_enterprisegarage` in `resources/[pop]/`.
2. `server.cfg`: enable OneSync (`set onesync on`), then `ensure` your framework (and `pop_vehiclekeys` if used)
   **before** `ensure [pop]`.
3. Edit `Config.Garages` in `config.lua`.

## How it works

1. **Take out**: at the counter, a small panel lists the vehicles allowed for your rank. The server picks the first
   free parking spot, creates the vehicle with a plate built from the garage prefix (e.g. `LSPD4821`) and gives the
   key through `pop_vehiclekeys` when it is started.
2. **Store**: drive the vehicle into the garage storage zone and press `[E] Store vehicle`. The vehicle is deleted
   and the key taken back. Any on-duty member of the job can store a vehicle of that garage.
3. **Limit**: `Config.MaxPerPlayer` vehicles out at the same time per character.
4. **Cleanup** (every 30 s while vehicles are out): a destroyed or deleted vehicle frees its slot; a vehicle whose
   owner disconnected, switched character or lost the job (or went off duty) is deleted as soon as it is empty.

The server checks everything: job, duty, rank, distance to the counter or storage zone, driver seat, limit and
free spot. The client only sends a garage id, a list index or a network id.

Service vehicles carry the entity state bags `pop_temporary = true` (never saved by `pop_vehiclepersistence`),
`pop_enterprisegarage = '<garage id>'` and `fuel = 100.0` (ox_fuel and compatible scripts).

## Adding a garage

```lua
{
    id = 'mechanic', job = 'mechanic', plate = 'MECH', -- unique id, job name, plate prefix (1-4 A-Z / 0-9)
    coords = vec3(-347.3, -133.6, 39.0),                -- counter (on foot)
    spawns = { vec4(-370.5, -107.8, 38.7, 70.0) },      -- parking spots (x, y, z, heading)
    store  = vec3(-365.0, -110.0, 38.7),                -- center of the storage zone (5 m radius)
    blip   = { sprite = 357, color = 47 },              -- nil = no blip
    vehicles = {
        { model = 'flatbed', grade = 0 },               -- grade = minimum job grade
        { model = 'towtruck', grade = 1 },
        -- type = 'bike' | 'heli' | 'boat' | ... when it is not an 'automobile' (needed by CreateVehicleServerSetter)
    },
},
```

Invalid ids, prefixes or garages without spawn points are reported in the server console at start.

## Server exports

```lua
exports.pop_enterprisegarage:IsServiceVehicle(plate)   -- true if the plate was taken out by this script
exports.pop_enterprisegarage:GetPlayerVehicles(src)    -- { 'LSPD4821', ... } plates taken out by this player
```

## Configuration

| Key | Default | Role |
|---|---|---|
| `Config.MaxPerPlayer` | `1` | service vehicles out at the same time per character |
| `Config.Garages` | LSPD, EMS | garages (see above) |

Common keys (`Config.Locale`, `Config.Framework`, `Config.Target`, `Config.Notify`, `Config.AccentColor`,
`Config.Keys`, ...) are described at the top of `config.lua`.

## Notes

- Stopping or restarting the resource deletes every service vehicle that is out.
- Without a framework (standalone), nobody has a job on duty: the garages stay closed.
