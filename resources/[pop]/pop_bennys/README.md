# pop_bennys

Simple, clean vehicle customization workshop. Drive in, press **E**, tweak paint, wheels, body parts, performance,
lights and window tint with a live preview, then pay or cancel. Prices are always computed by the server.

## Requirements

- Nothing mandatory. ESX (Legacy and older), QBCore, Qbox or standalone are detected automatically.
- `oxmysql` (optional): only used to read and update the framework vehicle table (`owned_vehicles` / `player_vehicles`).
- OneSync (the server reads the vehicle type, plate and driver).

## Installation

1. Copy `pop_bennys` into your `resources/[pop]/` folder.
2. In `server.cfg`, start your framework, inventory and `oxmysql` **before** the POP scripts:
   ```
   ensure oxmysql
   ensure es_extended   # or qb-core / qbx_core
   ensure [pop]
   ```
3. Edit `config.lua` (language, account, shops, prices, palette). No SQL to import.

## Configuration

| Key | Default | Description |
|---|---|---|
| `Config.Locale` | `'en'` | en, fr, es, de, it, pt, nl, pl, tr, ar (missing keys fall back to English) |
| `Config.Account` | `'bank'` | account charged: `'cash'` or `'bank'` |
| `Config.SaveToFramework` | `true` | write purchased properties to the framework vehicle table when the vehicle is owned |
| `Config.Shops` | 1 shop | `{ coords, radius, jobs, blip }` |
| `Config.Prices` | see file | paint, wheels, body, performance levels, turbo, xenon, neon, tint |
| `Config.Colors` | 18 colors | paint palette (`id` = GTA color index, `hex` = UI preview) |
| `Config.NeonColors` | 8 colors | neon colors `{ r, g, b }` |

Performance prices are lists: one entry per level. The number of entries limits the levels offered.

## Mechanic mode

Set `jobs` on a shop to reserve it to a job (on duty), using the `Bridge.HasJob` format:

```lua
{ coords = vec3(-211.94, -1324.53, 30.45), radius = 4.0, jobs = { mechanic = 0 }, blip = true },
```

The mechanic drives the customer's vehicle into the workshop and pays for the modifications.

## Garage integration

After every successful purchase the server fires a **local server event**:

```lua
AddEventHandler('pop_bennys:saved', function(src, plate, props, owned)
    -- plate: normalized (no spaces, uppercase); props: workshop keys only (ESX / QBCore / ox_lib format)
    -- owned = true: framework properties + purchases; owned = false: PARTIAL props (only what was paid), merge them
end)
```

`props` only contains the keys the workshop can edit (colours, wheels, body and performance mods, turbo, xenon,
neons, window tint). When the vehicle is not in the framework table (`owned = false`), `props` only holds the
purchased lines: merge them into your saved state instead of replacing it.

`pop_vehiclepersistence` listens to it automatically. With `Config.SaveToFramework = true` and `oxmysql` started,
the `vehicle` column (ESX) or `mods` column (QBCore / Qbox) is also updated, keeping unknown keys, `plate` and `model`.

## Standalone

Without a framework there is no money: set every price in `Config.Prices` to `0`. Vehicles are then priced against
the state sent when opening the menu and nothing is written to a database; use the `pop_bennys:saved` event to save.

## Security

- The client only sends keys and values. Each value is validated against the config (palette, levels, ranges).
- Prices, account, palette and levels are read from the server config only.
- For owned vehicles, the price reference is the framework table, never the state sent by the client.
- Every purchase re-checks distance to the shop, job and driver seat on the server.

## Limits

- The live preview is applied by the client: a cheater could modify their vehicle locally without paying, but the
  saved data (event and framework table) only contains what was paid.
- Custom RGB paint is not offered (palette only); an original RGB paint is restored on cancel.
- Vehicles that are not in the framework table: `pop_bennys:saved` receives partial props (`owned = false`).
- Standalone: no money, so prices must be 0.

## Exports

Client: `exports.pop_bennys:IsOpen()` returns `true` while the menu is open. Server: none (use `pop_bennys:saved`).
