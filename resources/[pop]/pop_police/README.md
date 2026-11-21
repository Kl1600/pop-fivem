# POP Police

Police duty and lockers, restraints, vehicle placement, searches, fines, records and officer alerts. Supports ESX Legacy and older ESX, QBCore, Qbox and standalone.

## Install

1. Place `pop_police` in the server's resources and start `oxmysql` first. Start your framework and inventory before `ensure pop_police` (or `ensure [pop]`).
2. Set the jobs, station coordinates, uniforms and fine options in `config.lua`. The three records tables are created automatically. `sql/install.sql` is available for manual setup.
3. Register `handcuffs` as an ordinary item in your inventory. For ESX's built-in inventory, an optional item insert is included in the SQL. For POP, ox, QB, QS or PS inventory, add the item using that inventory's item registry. Set `Config.Handcuffs = false` to operate without a handcuffs item.
4. When running standalone, grant eligible players the ACE `add_ace group.police pop.police allow`. Assign their principal to the group in your server configuration.

Go on duty at the station, then press **F6** to open the menu. **F9** sends a panic alert. Fines can be accepted with **Y** or refused with **Backspace**. Players can remap these controls in FiveM. Fine amounts come from the server's `Config.Fines.amounts` list. Ten locales and an optional amber terminal theme are included.

Handcuffs clear when a player disconnects. Unpaid fines are recorded for reference. Standalone uses the bridge's zero-balance economy and therefore records accepted fines as unpaid. Full inventory search is available with POP Inventory, ox_inventory and qb-inventory v2. Other inventory modes show an item summary instead.

## Server integration

| Export | Purpose |
| --- | --- |
| `IsCuffed(src)` | Returns the server's cuff status. |
| `SetCuffed(src, state)` | Applies or removes cuffs from trusted server code. |
| `IsOnDuty(src)` | Checks the officer's current duty status. |
| `GetOfficers()` | Lists on-duty officer server IDs. |
| `Alert(coords, text)` | Sends localized text and a blip to on-duty officers. |

Client exports are `IsCuffed()`, `IsEscorted()` and `IsOnDuty()`.

| Local server event | Arguments |
| --- | --- |
| `pop_police:dutyChanged` | `src, onDuty` |
| `pop_police:cuffChanged` | `target, cuffed, officer` |
| `pop_police:finePaid` | `target, officer, amount, reason` |
| `pop_police:panic` | `src, coords` |
