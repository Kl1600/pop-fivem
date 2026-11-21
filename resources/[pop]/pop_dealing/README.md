# pop_dealing

GTA 6-style drug sales to NPCs. Run `/sell` in a dealing area. Customers approach one at a time, and you have three attempts to negotiate a price. Watch for undercover officers and witnesses.

## Installation

1. Copy `pop_dealing` into `resources/[pop]/`.
2. In `server.cfg`, start the framework, inventory, target, and dispatch resources before `[pop]`:

   ```cfg
   ensure es_extended   # or qb-core / qbx_core (optional)
   ensure ox_inventory  # optional
   ensure [pop]
   ```

3. There are no required dependencies or database tables.

**OneSync is required** (enabled by default on FXServer). The server reads the client's NPC position and counts nearby NPCs.

## Items

`Config.Drugs` defaults to QBCore item names (`weed_white-widow`, `cokebaggy`, and `meth`). Replace them with items from your inventory:

```lua
Config.Drugs = {
    ['weed_pooch'] = { label = 'drug_weed', price = 80, amount = { 1, 3 } },
}
```

`label` is a locale key. For a new drug with a new key, add the key to at least `locales/en.lua` to avoid displaying the raw key. Add it to all ten locale files to translate it everywhere.

```lua
drug_lean = 'Lean',
```

## Payment

- `Config.Payment.type = 'black'` pays into the ESX `black_money` account. Frameworks without that account, such as QBCore by default, fall back to `cash`.
- `Config.Payment.type = 'cash'` pays in cash.
- `Config.Payment.type = 'item'` pays in the item set by `Config.Payment.item`, such as ox_inventory's `black_money`.

In standalone mode, use `'item'` with a supported inventory such as ox_inventory. Standalone has no money accounts.

## Dealing areas

`Config.Zones` contains circles defined by `coords` and `radius`. Each area's `mult` scales the street price. An empty list allows sales everywhere.

The default areas cover the default pop_territories territories. Forum Drive (`-165, -1620`, radius 110) and Sandy Shores (`1850, 3700`, radius 250) match the territory centers and radii in `config.lua`. Vespucci Beach sits within the `vespucci` polygon and Davis sits within the `grove` circle. Keep the selling areas aligned if you edit the territories.

When pop_territories is running, its territory `price` multiplies the total after the pop_dealing area `mult`. All dealing areas default to `mult = 1.0` because pop_territories already sets Vespucci's `price` to `1.2`. Use a different `mult` for an area outside any territory or when running without pop_territories.

## Optional integrations

- **Dispatch.** With `Config.Police.dispatch = 'auto'`, the script detects ps-dispatch, cd_dispatch, or qs-dispatch. The fallback sends a notification and blip to on-duty officers. See `server/police.lua` for the integration signatures.
- **pop_territories.** Each sale calls `RecordDrugSale`. The integration can adjust the final amount up to three times the computed amount.
- **Target.** Supports ox_target and qb-target, with a native E prompt as fallback.

## Server hook

```lua
AddEventHandler('pop_dealing:sold', function(src, item, qty, amount, coords) end)
```

## Exports

```lua
exports.pop_dealing:IsSelling(src)    -- server, boolean
exports.pop_dealing:StopSelling(src)  -- server, boolean
exports.pop_dealing:IsSelling()       -- client, boolean
```

## Languages

`Config.Locale` supports en, fr, es, de, it, pt, nl, pl, tr, and ar. Missing keys fall back to English. To add a language, copy `locales/en.lua` and change the language code.
