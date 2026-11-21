# POP Admin

A side-panel for player moderation, vehicle support, announcements, and optional weather and time synchronization.

## Installation

1. Enable OneSync and start `oxmysql` and your framework before `pop_admin`.
2. Add `ensure pop_admin` to `server.cfg`. The resource creates its tables on startup. Database administrators can also run `sql/install.sql` manually.
3. Grant staff access with ACE. Press **F10** or run `/popadmin` to open the panel.

```cfg
add_ace group.admin pop.admin allow
add_ace group.mod pop.admin allow
add_ace group.mod pop.admin.ban deny
add_ace group.mod pop.admin.unban deny
add_ace group.mod pop.admin.world deny
```

The panel supports ESX Legacy and older ESX, QBCore, Qbox, and standalone through ACE. Set `Config.FrameworkAdmins = false` to require ACE for framework admins. Action permissions use `pop.admin.<action>`, with `vehicle` covering spawn, repair, and delete.

## Configuration

Set the language, shortcuts, ban duration options, and default weather in `config.lua`. Disable `Config.WorldSync` when another resource controls the clock or weather. The Discord webhook is optional and belongs in the server-only `config_server.lua`.

The resource detects ESX Ambulance Job, QB Ambulance Job, and Qbox Medical for revive. Set `Config.ReviveEvent` to an appropriate **client event** if your medical resource requires a different integration. Configure the direct noclip shortcut with `Config.NoclipKey`.

Ban checks require a loaded database cache. The resource matches platform identifiers and excludes IP addresses. Expired bans stop blocking connections automatically.

## Integration

Server exports are `HasPermission(playerId, permission)`, `IsBanned(playerId)`, and `BanPlayer(playerId, reason, hours, by)`. Use zero hours for a permanent ban. Client exports are `IsOpen()`, `IsNoclip()`, `IsInvisible()`, and `IsSpectating()`.
