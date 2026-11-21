# pop_voiceui

Read-only local microphone activity with optional current range, using native voice detection. No voice routing, fake volume display, or modification of another voice resource.

- Files: `fxmanifest.lua`, `config.lua`, `client/main.lua`, `README.md`, ten locales, copied POP Bridge/shared/kit and `web/{index.html,script.js,style.css}`.
- Config defaults: `Command='popvoice'`, `Enabled=true`, `ShowRange=true`, `HangTime=250`. Exports `SetVisible(bool)`, `IsTalking()`. Uses `NetworkIsPlayerTalking` with a Mumble fallback when pma-voice is running, plus local `proximity.distance` if provided by the voice resource. Shows radio only when local `radioActive` or the legacy pma-voice radio event is active. No other players, server code, dependencies, RPC or SQL.
- Poll at 125 ms idle, 75 ms while showing, 1000 ms when disabled or paused. Output only when state changes; `pop_voiceui:update` is `{ show, radio, range? }`, with range a localized label for the rounded distance in metres. `pop_voiceui_ready` invalidates the snapshot; no focus or click actions. Pause and character creator hide overlay.
- Extra locale keys `speaking`, `radio_speaking`, `voice_range` (one %s), with base keys and Arabic RTL.
