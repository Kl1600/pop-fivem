# pop_chargeurs

Magazines as items: using one reloads the weapon you are holding with a fixed number of rounds.
A short progress bar shows up (you can walk, not shoot), the magazine is consumed and the rounds are added.

No mandatory dependency. No loop: nothing runs until a magazine is used.
Works with ESX (Legacy and older), QBCore, Qbox and standalone, with pop_inventory, ox_inventory, qs-inventory,
qb-inventory, ps-inventory or the framework inventory.

## Installation

1. Put `pop_chargeurs` in `resources/[pop]/`.
2. Start your framework and inventory **before** `[pop]` in `server.cfg`:
   ```
   ensure es_extended      # or qb-core / qbx_core
   ensure ox_inventory     # or your inventory
   ensure [pop]
   ```
3. Declare the magazine items in your inventory (below).
4. Adjust `config.lua`: language, magazines, `Config.MaxAmmo`, `Config.ReloadTime`.

## Items

Default names (keys of `Config.Magazines`): `pistol_magazine`, `smg_magazine`, `rifle_magazine`, `shotgun_shells`.
You can add more: a new key in `Config.Magazines` + an item with the same name in your inventory.

**ox_inventory** (`ox_inventory/data/items.lua`), with every framework:
```lua
-- consume = 0 is required: pop_chargeurs removes the magazine itself, only once the reload is validated.
['pistol_magazine'] = { label = 'Pistol magazine', weight = 200, stack = true, close = true, consume = 0 },
['smg_magazine']    = { label = 'SMG magazine', weight = 300, stack = true, close = true, consume = 0 },
['rifle_magazine']  = { label = 'Rifle magazine', weight = 350, stack = true, close = true, consume = 0 },
['shotgun_shells']  = { label = 'Shotgun shells', weight = 250, stack = true, close = true, consume = 0 },
```
Without `consume = 0`, ox_inventory removes a magazine on use as well: two magazines would be lost per reload.
Standalone with ox_inventory: also add `server = { export = 'pop_chargeurs.pistol_magazine' }` to each item
(with that item's name).

**pop_inventory** (`pop_inventory/data/items.lua`):
```lua
['pistol_magazine'] = { label = 'Pistol magazine', weight = 200, consume = 0 },
['smg_magazine']    = { label = 'SMG magazine', weight = 300, consume = 0 },
['rifle_magazine']  = { label = 'Rifle magazine', weight = 350, consume = 0 },
['shotgun_shells']  = { label = 'Shotgun shells', weight = 250, consume = 0 },
```

**qb-inventory / ps-inventory / qs-inventory / QBCore** (`qb-core/shared/items.lua`):
```lua
pistol_magazine = { name = 'pistol_magazine', label = 'Pistol magazine', weight = 200, type = 'item', image = 'pistol_magazine.png', unique = false, useable = true, shouldClose = true, description = '' },
```
(same line for `smg_magazine`, `rifle_magazine`, `shotgun_shells`).

**ESX** (`items` table):
```sql
INSERT INTO items (name, label, weight) VALUES
  ('pistol_magazine', 'Pistol magazine', 0.2),
  ('smg_magazine', 'SMG magazine', 0.3),
  ('rifle_magazine', 'Rifle magazine', 0.35),
  ('shotgun_shells', 'Shotgun shells', 0.25);
```

## Modes (chosen automatically)

| Mode | Inventories | Where the ammo is stored |
|---|---|---|
| `metadata` | ox_inventory, pop_inventory | `ammo` metadata of the weapon item, written by the server |
| `native` | qb-inventory, qs-inventory, ps-inventory, ESX / QBCore / Qbox inventory | ped ammo, added by the client after server validation |

The server always checks: known magazine, weapon in hand (read server side) compatible, magazine owned,
`Config.MaxAmmo` cap, delay between two reloads. In `metadata` mode the weapon item is read **before** the progress bar
(the player is told right away if it cannot be reloaded). The magazine is removed **before** the ammo is added; if
writing the metadata fails, it is given back only when reading the weapon again shows its ammo unchanged
(otherwise a console log is printed).

## Limits

- **Native mode**: the server cannot read the ped's ammo; the cap relies on the value sent by the client. The magazine
  is always removed server side before anything is added: this script cannot give ammo without a magazine.
- **qb-inventory / qs-inventory**: weapons are items, but their ammo is read back from the ped by the inventory
  (qb-weapons...): native mode works. If your version does not save the ped's ammo, it is lost on disconnect
  (inventory behaviour, not the script's).
- **ox_inventory**: its own ammo (`ammo-9`... items, R key) keeps working; magazines are an addition. To validate in
  game: the equipped weapon must take the new value after `SetMetadata` + `SetPedAmmo` (see "In-game test" below).
- **pop_inventory**: needs `GetCurrentWeapon` and `SetMetadata` (ox API), otherwise `not_supported`. A console warning
  is printed at startup if one of these exports is missing.
- **Standalone without an inventory**: no items, the script does nothing.

## In-game test (ox_inventory resync)

To do once on your server with ox_inventory (or pop_inventory):

1. Equip a `WEAPON_PISTOL` from the inventory, fire a few rounds, note the ammo shown on the HUD.
2. Use a `pistol_magazine`: the bar runs, `+N rounds` is shown, the HUD ammo goes up by N.
3. Open the inventory: the pistol tooltip shows the same ammo as the HUD.
4. Fire one round, then holster and re-equip the pistol: the ammo must stay the same (no reset to the old value).
5. Reconnect: the pistol keeps the ammo it had.
6. Press R with `ammo-9` in the inventory: the ox reload still works on top of the new value.

If step 4 or 5 shows the old value, the inventory did not take the new metadata: report it with your ox_inventory
version and `Config.Debug = true` logs.

## Languages

`Config.Locale`: en, fr, es, de, it, pt, nl, pl, tr, ar. A missing key falls back to English.
Add a language: copy `locales/en.lua`, change the language code and translate.

## Debugging

`Config.Debug = true` prints the detected mode and every reload (player, magazine, ammo) in the console.
