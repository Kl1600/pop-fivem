# POP Character Creator

Create and preview a freemode character, register an identity, and pick an arrival point. Profiles are saved per character in ESX, QBCore and Qbox, and per license in standalone.

## Install

1. Start your framework if applicable and install oxmysql.
2. Place the resource in your resources directory and add `ensure oxmysql` followed by `ensure pop_charcreator` to `server.cfg`. The resource creates its profile table at startup. `sql/install.sql` is available for manual installs.
3. Set your arrival locations, birth-date rules and locale in `config.lua`. Use `Config.AutoCreate = false` to open the creator manually with `/character`.
4. If another resource controls identity, appearance, or spawning, decide which resource owns those actions. POP stores its own profile. It does not write to framework identity tables. Use the exports or events below for integrations.

An existing profile requires the `pop.charcreator.edit` ACE or Bridge admin privileges when `Config.AllowAdminEdit` is enabled. Example ACE setting:

```cfg
add_ace group.admin pop.charcreator.edit allow
```

## Integrate

- Server `exports.pop_charcreator:GetIdentity(source)` returns `firstName`, `lastName`, `dateOfBirth` (ISO date), and `model` for a loaded profile.
- Server `exports.pop_charcreator:GetAppearance(source)` returns the saved identity and appearance fields.
- Server local event `pop_charcreator:profileSaved` receives the player source after saving.
- Client local event `pop_charcreator:client:applied` fires after the saved appearance is applied. POP Clothes uses it to reapply saved variations.

In game, check creation, editing permissions, respawn, clothing reapplication, arrival positions and switching between both models.
