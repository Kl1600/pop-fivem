# POP Passport

Issue US and MX roleplay documents and show them to a nearby player. The interface appears beside the game for a few seconds and returns control to the player throughout.

## Installation

1. Start `oxmysql`, your framework if used, and your inventory before this resource. Enable OneSync for server-side distance checks.
2. Register `pop_passport_us` and `pop_passport_mx` as non-stackable usable items in a metadata-capable inventory. Players can use either the item or the display command. In plain ESX inventory, configure the items normally. Presentation resolves the item to its registered owner's document.
3. Add `ensure pop_passport`. Tables are created on startup. The optional `pop_charcreator` integration reads the character name, date of birth and model. With standalone, use a supported inventory.

## Commands

- `/poppassport_issue 12 mx` issues the MX variant to player 12. The command is available to console, framework admins, and staff granted `add_ace group.staff pop.passport.issue allow`.
- `/poppassport us` shows your US document to you.
- `/poppassport mx 12` shows your MX document to nearby player 12.

Server resources can call `exports.pop_passport:Issue(playerId, variant)` to issue one document as part of a trusted onboarding flow.

`Config.ValidDays` controls validity. Set it to zero for indefinite validity. A staff reissue renews an expired record. Configure language, item names, display duration and distance in `config.lua`.
