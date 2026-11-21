# pop_chat

A proximity roleplay action command based on the old /me feature, displayed over the speaker and briefly in a nearby activity list. Compatible with the default FiveM chat command input and F8.

- Files: `fxmanifest.lua`, `config.lua`, `client/main.lua`, `server/main.lua`, `README.md`, ten locales and unmodified POP bridge, shared files and kit, `web/{index.html,script.js,style.css}`.
- Config defaults: `Command='me'`, `Distance=20.0`, `Duration=6000`, `MaxLength=160` Unicode code points, `Cooldown=2500`, `MaxVisible=6`.
- Server command validates a live loaded sender, sanitizes UTF-8, controls and whitespace, rate-limits before broadcast, and checks server coordinates and routing bucket per recipient. Register no client-submitted network event. `pop_chat:client:action(senderId, pedNetId, text, duration)` is server-to-client only.
- Client renders through `pop_chat:frame({ markers, messages })`; markers contain `id, text, x, y` with normalized screen positions, messages contain `id, text`. Client expires entries and rechecks the speaker ped network ID, local distance and on-screen status. Latest per sender, bounded capacity, faster projection only with active messages. Use textContent and no focus. Chat command suggestion is optional and removed on stop.
- No SQL, exports or dependence on third-party chat. Locale keys `action_arg`, `action_help`, `action_invalid`. Bridge handles feedback; kit strings retained in all ten languages with RTL in Arabic.
