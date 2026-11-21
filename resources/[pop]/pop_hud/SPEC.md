# pop_hud

Replaces the old status and speed displays with two contextual HUD panels. Uses native GTA radar and map assets. Optional radar policy controls visibility and configured point blips; the resource does not change loading screens, pause menus, or streamed textures.

- Files: `fxmanifest.lua`, `config.lua`, `client/main.lua`, `README.md`, ten `locales/*.lua`, copied `bridge/`, `shared/`, `web/kit/`, and `web/{index.html,script.js,style.css}`.
- Client only. No network events, SQL, or remote callbacks. Client exports: `SetVisible(bool)`, `SetNeeds({ hunger?, thirst? })`; values are percentages. Optional local ESX event `esx_status:onTick(status)`; QB and Qbox use metadata via `Bridge.GetPlayerData()`.
- NUI `pop_hud:update` carries `visible`, optional `health`, `armor`, `hunger`, `thirst`, `clock`, and optional `speed`, `unit` (kmh or mph), `fuel`, all sanitized. The NUI ignores unknown fields. `pop_hud_ready` invalidates the snapshot.
- Config defaults: command `pophud`, `ShowClock=false`, `NeedThreshold=80`, `SpeedUnit='kmh'`, `Radar='unchanged'` (alternatives `vehicle`, `visible`, `hidden`), `Blips={}`. Clamp display values to 0–100, suppress at pause or while `LocalPlayer.state.charcreatorOpen` is true. Normalize health using the native pedestrian baseline of 100 when the maximum is greater than 100.
- Speed/fuel is driver-only. Fuel prefers an optional numeric vehicle `fuel` statebag as a percentage; otherwise computes native liters relative to the handling tank volume. Normal conditions hide vitals. Client sends only changed snapshots. Idle intervals 750 ms, 250 ms when a vital is showing, 125 ms while driving. Configured blips receive locale keys, removed on stop; restore any radar state owned by this resource on stop.
- Locales add `health`, `armor`, `hunger`, `thirst`, `fuel`, `kmh`, `mph`; retain kit keys and Arabic RTL.
