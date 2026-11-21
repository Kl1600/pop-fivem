# pop_affiche — Specification

Authorized players place image posters on walls and replace or remove their own posters nearby. Other players can view posters. Reuses the legacy poster workflow with fixed-size, front-facing posters and configured image hosts.

## Files and dependencies

`fxmanifest.lua`, `config.lua`, `client/main.lua`, `client/surfaces.lua`, `server/main.lua`, `sql/install.sql`, `web/{index.html,script.js,style.css,display.html,display.js,display.css}`, `README.md`, and the unmodified Bridge, callback, locale and web kit files. Ten locales include the template keys, with RTL for Arabic. Requires oxmysql. DUI uses native client APIs and does not require an external engine.

## Controls and configuration

The `pop_affiche` key mapping (default unbound) first finds a nearby vertical surface at the camera crosshair and then opens the image URL editor. Nearby posters provide a Bridge target to edit or remove. Configuration defines `Command`, `WriteAce = 'pop.affiche.write'`, `Hosts = { cdn.discordapp.com, media.discordapp.net }`, `Size = { width=1.2, height=0.8 }`, `ActionDistance=3.0`, `RenderDistance=22.0`, `MaxVisible=8`, `MaxPerOwner=8`, `MaxSurfaces=128`, `WriteDelay=1500`.

## Protocol

All network requests use shared callbacks. `pop_affiche:nearby()` returns bounded public position metadata near the authoritative player position. `pop_affiche:content(id)` returns the URL only within render distance. `pop_affiche:edit(id)` returns content and revision upon a successful owner/admin and distance check. `pop_affiche:access()` checks permissions before placement. `pop_affiche:save(id?, revision?, position?, normal?, url)` returns success and locale key. `pop_affiche:remove(id, revision)` uses the same return format. A nil ID creates a new poster; saved coordinates, owner and dimensions are immutable.

Lua sends NUI `open` with `{ title, editing, content }` and `hide`; browser posts `save { content }`, `remove`, and kit `close`. A native DUI page posts `surfaceReady { key }` and gets `{ content, allowedHosts }` as the NUI callback response. On character unload the server sends `pop_affiche:client:unloaded` to clear the local form and surfaces. No public exports.

## Storage and checks

Use `pop_affiche_surfaces` with auto-increment ID, server-derived owner, bounded coordinates and normal components, revision, and URL in max 1024 bytes. The migration is idempotent. Every mutation checks dead state, write permission, proximity, ownership, cooldown and a write lock. SQL is parameterized. Edits and deletes require the revision displayed in the editor and atomically compare it in SQL. A stale editor closes with a localized message. Creation also checks limits, finite bounded vectors, a normalized vertical wall normal and spacing. Image URLs must use HTTPS with an exact configured hostname, no credentials or port, and a supported raster extension. No server-side fetch. The DUI fetches images without credentials or referrer, denies redirects, requires CORS and a raster MIME type, and caps response bodies at 5 MiB. The game's local collision data supplies the wall preview. The server enforces geometry bounds and player reach.

Idle polling checks nearby metadata every few seconds. Native DUI, targets and render loops are limited to nearby entries, and released when out of range, on replacing a screen, and on stop. Display text uses the locale kit; no CDN code.

## Locale keys

`title, edit, command, find_wall, saved, removed, limit, bad_content, changed, content, remove`.
