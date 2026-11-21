# POP Passport

Two in-game document variants, US and MX, inspired by the legacy identity resources. Staff issue a document to a connected character. The holder can inspect their copy or show it to an adjacent player in the same routing bucket. The interface is a small, timed side panel with no focus.

## Files

`fxmanifest.lua`, `config.lua`, `README.md`, `sql/install.sql`, `server/main.lua`, `client/main.lua`, `web/index.html`, `web/style.css` and `web/script.js`. Ten locale files supplement the template. The bridge, callback, locale helper and web kit are byte-identical copies of pop_base.

## Commands, callback and export

| Entry point | Arguments and result |
|---|---|
| Server command `poppassport_issue` | `<playerId> <us or mx>`. Only console and authorized staff. Uses the same server issuance path as the export. |
| Client command `poppassport` | Optional variant (default us) and optional positive integer viewer ID. |
| Callback `pop_passport:show` | `variant, viewerId?` → `ok, localeKey?`. Sends the card only after entitlement and recipient checks. |
| Server export `Issue` | `playerId, variant` → `ok, localeKey?`. Server resource callers are trusted. |
| Client event `pop_passport:client:show` | Document payload `{ name, variant, serial, birthDate?, sex?, issuedAt, expiresAt? }`. Server origin required. |
| NUI message `pop_passport:card` | `{ action, document, duration }`. Text comes from the locale table. |
| NUI message `pop_passport:hide` | Hides the panel. The HUD never takes focus. |

Usable items show the owner's document when the selected inventory supports usable items. The command is always available.

## Config and storage

Template defaults plus `Config.Command = 'poppassport'`, `Config.Items = { us = 'pop_passport_us', mx = 'pop_passport_mx' }`, `Config.ShowDistance = 3.0`, `Config.DisplayMs = 8000`, `Config.ValidDays = 3650`. Zero valid days produces a document with no expiry.

SQL table `pop_passport_documents` has an auto-increment unsigned integer serial, owner ID, variant, display name, optional date of birth, issue time and nullable expiry. A unique constraint on owner and variant makes issuance idempotent. The same serial may be reissued while valid. Expired records renew after an authorized issuance without assigning a second serial.

Identity comes from the optional pop_charcreator server export, then the Bridge character name. Dates are displayed only when the character creator supplies them. Standalone uses the player's server name and a supported inventory.

## Authority and performance

- Issuance requires admin through Bridge or ACE `pop.passport.issue`, or a trusted server export. Clients cannot select the recipient of an issuance.
- One in-flight mutation per owner. Recheck the connected character after SQL yields and avoid adding a second item when one already exists. The inventory receives only serial and display-oriented metadata.
- Showing requires the current character's SQL record and the corresponding item. A metadata-capable inventory must contain the matching serial. Without metadata the document item resolves only to the current owner's existing record.
- Before responding, verify the character, item, expiry, same routing bucket and server-to-server ped distance. Limit requests per source and clear the limiter on disconnect. Never include an account identifier in client data.
- No permanent loop. Uses the mandatory oxmysql dependency only for the document record.
- Product locale keys cover title, variants, displayed fields, issuing, expiry, identity and ownership errors, missing inventory and invalid recipient or variant. Arabic uses RTL.
