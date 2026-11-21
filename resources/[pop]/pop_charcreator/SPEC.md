# pop_charcreator

Create a freemode character with an identity, ancestry, face details, eye color and hair. Preview changes on a local ped, rotate the preview and select a configured arrival point. The creator opens for a loaded character without a profile. A permission-controlled command can reopen an existing profile. Existing profiles load automatically. ESX, QBCore, Qbox and standalone identify players through Bridge. Identity and appearance are stored in this resource's own table.

## Files

`fxmanifest.lua`, `config.lua`, `common/profile.lua`, `server/main.lua`, `client/main.lua`, `sql/install.sql`, `README.md`, template copies in `bridge/`, `shared/` and `web/kit/`, ten Lua locale files and `web/{index.html,script.js,style.css}`. oxmysql is required. Framework appearance and spawn resources require an explicit integration if they also manage a player's model.

## Contract

- `pop_charcreator:load` returns `{ profile = profile?, canCreate = true }` after initialization. `profile` contains `firstName`, `lastName`, `dateOfBirth` (ISO date) and the appearance fields listed in config. No identifier is sent.
- `pop_charcreator:begin` returns `{ token, profile?, birth, spawns }` or `nil, reason`. `birth` contains minimum and maximum ISO birth dates. `spawns` is a list of configured ID and locale key pairs and is empty when editing an existing profile.
- `pop_charcreator:save(token, profile, spawn)` returns `true, profile, spawn?` or `false, reason`. Server validates the token, loaded identifier, expiry, life state, edit permission, configured spawn ID and all profile fields.
- `pop_charcreator:cancel(token)` clears a matching session. Both load and cancel are callable by the player for their own data.
- Server-only local event `pop_charcreator:profileSaved(src)` is emitted after persistence. Local client event `pop_charcreator:client:applied` follows applying an appearance to the player ped.
- Server exports `GetIdentity(src)` → firstname, lastname, birth date and model as `{ firstName, lastName, dateOfBirth, model }` or nil. `GetAppearance(src)` returns a copy of the canonical saved profile or nil.
- Server sends `pop_charcreator:client:unloaded` after character unload to clear the local editor.
- NUI receives `pop_charcreator:panel` with `show`, `profile`, `limits`, `birth` and `spawns`. NUI posts `pop_charcreator:preview` with appearance, `pop_charcreator:rotate` with direction -1 or 1, `pop_charcreator:save` with profile and spawn. `close` uses the template.

## Data and permissions

`pop_charcreator_profiles` stores one row per Bridge identifier, with profile JSON. SQL values are parameterized. A per-identifier lock serializes writes. Sessions expire after 600 seconds and are cleared on unload/drop. First creation requires no existing row; subsequent editing requires `pop.charcreator.edit` ACE or Bridge admin when enabled. Names are validated as UTF-8, bounded to 2–24 codepoints and reject control/bidi characters. Date validation includes leap years and configured minimum age. Appearance fields are integers enforced against model-specific bounds. Position and cost are never provided as numbers by the client.

Config defines `Command`, `AutoCreate`, `AllowAdminEdit`, `SessionSeconds`, `Birth`, `Spawns`, `DefaultSpawn` and `Models`. Default models are male/female freemode. Appearance fields are `model`, `mother`, `father`, `blend`, `skin`, `nose`, `jaw`, `chin`, `eyes`, `hair` and `hairColor`. The camera, clone and focus are released on close, death, unload or resource stop. Player appearance is touched only after loading or saving a validated profile. No idle frame loop.

## Locales and verification

Ten locale files extending the exact kit, with Arabic RTL. Script keys cover UI labels and character validation. Audit initial creation and reopen, permission loss, invalid date and model, concurrent save, disconnect, respawn, camera exit, all four framework identifiers and all ten languages.
