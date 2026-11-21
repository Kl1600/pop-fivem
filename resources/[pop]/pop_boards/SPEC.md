# pop_boards — Specification

Players place writable canvases on walls, draw using the local brush editor, and edit their own boards. Nearby players see the saved artwork. From the legacy board editor, preserves placement, drawing, brush width/color, save, clear, edit and owner/admin removal.

## Files and dependencies

`fxmanifest.lua`, `config.lua`, `client/main.lua`, `client/surfaces.lua`, `server/main.lua`, `sql/install.sql`, `web/{index.html,script.js,style.css,display.html,display.js,display.css,drawing.js}`, `README.md`, and the unmodified Bridge, callback, locale and web kit files. Ten locales include template keys, with RTL for Arabic. Requires oxmysql. DUI uses native client APIs.

## Controls and configuration

The `pop_boards` key mapping (default unbound) finds a nearby wall and opens a canvas editor. Nearby boards have a Bridge target. Configuration defines `Command`, `WriteAce = false` (public creation by default), `Size = { width=1.2, height=0.9 }`, `ActionDistance=3.0`, `RenderDistance=22.0`, `MaxVisible=8`, `MaxPerOwner=8`, `MaxSurfaces=128`, `WriteDelay=1500`, `MaxStrokes=64`, `MaxPoints=1000`.

## Protocol

`pop_boards:nearby()` returns bounded public position metadata near the authoritative player. `pop_boards:content(id)` returns artwork only within render distance. `pop_boards:edit(id)` returns content and revision after checking owner/admin and distance. `pop_boards:access()` checks placement rights. `pop_boards:save(id?, revision?, position?, normal?, strokes)` and `pop_boards:remove(id, revision)` return success and a locale key. New boards use nil ID.

Lua sends NUI `open { title, editing, content, maxPoints, maxStrokes }` and `hide`; browser posts `save { content }`, `remove`, and kit `close`. A native DUI page posts `surfaceReady { key }` and gets `{ content }` as the NUI callback response. On character unload the server sends `pop_boards:client:unloaded` to clear the local form and surfaces. No public exports.

## Storage and safety

Use `pop_boards_surfaces` with auto-increment ID, server-derived owner, position, normal, revision and canonical JSON artwork. A stroke is `{ color='#aabbcc', width=1..32, points={ x1,y1,... } }`, with integer coordinates 0–511 and bounded total strokes and points. Artwork is validated and normalized server-side before storage. Both pages render it with Canvas paths. No uploaded image blobs or external assets. Saving an empty canvas clears its artwork. Edits never change the saved transform. SQL is parameterized. Edits and deletes require the revision displayed in the editor and atomically compare it in SQL. A stale editor closes with a localized message. Mutations check owner/admin, presence, dead state, distance, cooldown and lock; creation checks write rights, spacing and quotas. The server bounds the position and wall normal, while the client detects static wall collision.

Idle polling uses adaptive waits and capped visible artwork, activates native DUI only nearby and draws per-frame only while visible. Targets and browsers are cleaned up as the player leaves and on resource stop.

## Locale keys

`title, edit, command, find_wall, saved, removed, limit, bad_content, changed, remove, erase, brush, color`.
