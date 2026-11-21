# pop_crew

Player-created crews with a compact interface and an idle target of ~0.00 ms. Supports ESX, QBCore, Qbox, standalone, and ten languages.

## Installation

1. Install `oxmysql`. Other dependencies such as ox_lib and ox_target are optional.
2. Copy `pop_crew` into `resources/[pop]/`.
3. Start oxmysql and the framework before `[pop]` in `server.cfg`:

   ```
   ensure oxmysql
   ensure es_extended   # or qb-core / qbx_core, or omit for standalone
   ensure [pop]
   ```

4. The resource creates its tables on first startup. For a manual import, use `sql/install.sql`.

## Usage

- Open the panel with `/crew` or F7. Change the key in Settings > Key Bindings > FiveM.
- Players without a crew can create one by choosing a name and color and paying `Config.CreateCost`, or respond to an invitation. Creation is free in standalone.
- Crew members can view the roster, invite nearby players, promote, demote, or remove members according to rank, or leave. The leader can disband the crew.

## Configuration (`config.lua`)

| Key | Default | Purpose |
|---|---|---|
| `Config.Locale` | `'en'` | en, fr, es, de, it, pt, nl, pl, tr, ar |
| `Config.Command` / `Config.Key` | `'crew'` / `'F7'` | Default command and key |
| `Config.CreateCost` / `Config.CreateAccount` | `25000` / `'bank'` | Creation cost and account (`'cash'` or `'bank'`) |
| `Config.NameLength` | `{ min = 3, max = 20 }` | Crew name length (hard maximum of 32) |
| `Config.MaxMembers` | `20` | Maximum members per crew |
| `Config.InviteDistance` / `Config.InviteTimeout` | `5.0` / `60` | Invitation distance in meters and validity in seconds |
| `Config.Colors` | 8 colors | Palette offered at creation |
| `Config.Ranks` | leader, officer, member, recruit | Highest to lowest ranks with `invite`, `kick`, and `manage` permissions |
| `Config.ShowTags` / `Config.TagDistance` | `false` / `20.0` | Marker above nearby members |

Rank index 1 is the leader, with all permissions including disbanding the crew and transferring leadership. Rank labels come from the `rank_<name>` locale key. To add a rank, add an entry to `Config.Ranks` and translate the key.

## Server exports

```lua
exports.pop_crew:GetPlayerCrew(src)      -- { id, name, color, rank, rankLabel } | nil
exports.pop_crew:GetCrewMembers(crewId)  -- { { id, identifier, name, rank, rankLabel, online, source }, ... }
exports.pop_crew:GetCrew(crewId)         -- { id, name, color, memberCount, onlineCount } | nil
exports.pop_crew:IsSameCrew(srcA, srcB)  -- boolean
```

Local server-only events use `AddEventHandler`:

```lua
AddEventHandler('pop_crew:changed', function(src, crewId) end) -- crewId is nil when the player has no crew
AddEventHandler('pop_crew:disbanded', function(crewId) end)
```

## Client export

```lua
exports.pop_crew:GetMyCrew() -- { id, name, color, rank, rankLabel } | nil
```

## Languages

`locales/<code>.lua` contains the translations. Missing keys fall back to English. To add a language, copy `en.lua`, change the language code, translate the values, and set `Config.Locale = '<code>'`.
