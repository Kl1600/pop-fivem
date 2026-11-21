# POP Clothes

Preview catalog choices at a clothing store, barber or tattoo parlor. Save purchases per character and freemode model, or per license and model on standalone.

## Install

1. Place the resource in your resources directory and start oxmysql and your framework (if used) before `ensure pop_clothes`. The resource creates its table at startup. `sql/install.sql` is available for manual installs.
2. Configure shops, account, currency and locale in `config.lua`. Use `Config.Account = false` for free purchases. Standalone shops are free.
3. Set each store's `kind` to `clothing`, `barber` or `tattoo`. Optional `job` and `onDuty` fields restrict access. Compatible target resources are optional. The Bridge prompt works without them.
4. Extend `Config.Catalog` with stable category and option IDs. Populate each option with its exact model-specific variations and price. Test added drawable and texture IDs against your server game build. Use a locale key for every label.

This resource can run independently. When POP Character Creator is available, its appearance event also reapplies managed outfits. For other skin resources, call `exports.pop_clothes:Reapply()` on the client after the new ped is ready. Tattoos are applied as a managed set and can replace tattoos assigned by another appearance resource.

The server export `exports.pop_clothes:GetSelections(source)` returns the loaded selection IDs for the player's current freemode model.

In game, check shop prompt range, cancellation, purchase and insufficient funds, saved appearance after relogging and the workflow on each configured framework.
