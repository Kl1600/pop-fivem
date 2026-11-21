# pop_interim

Public job center for FiveM. Players walk to the desk, pick a public job from a short list, confirm, and the
server assigns it in your framework. They can also resign (back to the unemployed job). A cooldown prevents
job hopping.

- ~0.00 ms idle: one adaptive client loop for local peds, no server loop.
- ESX (Legacy and older), QBCore, Qbox. Standalone starts without errors (job center disabled).
- ox_target, qb-target, or a built-in native prompt (`[E] Job Center`).
- 10 languages: en, fr, es, de, it, pt, nl, pl, tr, ar (RTL).
- No dependency, no database.

## Installation

1. Drop `pop_interim` into your resources folder.
2. Start it **after** your framework (and target, if any):
   ```cfg
   ensure qb-core          # or es_extended / qbx_core
   ensure ox_target        # optional
   ensure pop_interim
   ```
3. Edit `config.lua` (language, locations, jobs).

## Configuration

| Key | Description |
|---|---|
| `Config.Locale` | `en`, `fr`, `es`, `de`, `it`, `pt`, `nl`, `pl`, `tr`, `ar` |
| `Config.Locations` | Desks: `coords` (vector4), `ped` (model or `false` for a plain zone), `blip` |
| `Config.Blip` | `sprite`, `color`, `scale` |
| `Config.Jobs` | Offered jobs: `id`, `job` (exact framework job name), `grade` |
| `Config.Unemployed` | Job given on resignation (`job`, `grade`) |
| `Config.Cooldown` | Seconds between two job changes (per character, in memory) |
| `Config.AccentColor` | UI accent color |

Common keys (`Framework`, `Target`, `Notify`, `Debug`, ...) are auto-detected by default.

## Adding a job

1. Make sure the job exists in your framework (ESX `jobs` / `job_grades` tables, QBCore `shared/jobs.lua`,
   Qbox `shared/jobs.lua`) with the grade you want to give.
2. Add an entry to `Config.Jobs`:
   ```lua
   { id = 'miner', job = 'miner', grade = 0 },
   ```
3. Add two texts, at least in `locales/en.lua` (used as fallback):
   ```lua
   job_miner      = 'Miner',
   job_miner_desc = 'Dig for ore in the quarry',
   ```

Jobs that do not exist in the framework are hidden and a warning is printed in the server console at start.

## Security

The client only sends a desk index and a job `id`. The server checks distance, the whitelist, that the job
exists, a per-player lock and the cooldown. Job name and grade always come from `config.lua`.

## Exports

Server:
```lua
exports.pop_interim:GetCooldown(source)   -- seconds left before the next change (0 if none)
exports.pop_interim:ResetCooldown(source) -- removes the player's cooldown, returns true
```

Client:
```lua
exports.pop_interim:IsOpen() -- true while the panel is open
```

## Compatibility notes

- Old ESX without `ESX.DoesJobExist`: every configured job is assumed to exist.
- Qbox: jobs are assigned with `exports.qbx_core:SetJob`.
- Standalone: there is no job to assign, the desk answers "The job center is closed".
