# pop_clothes

Clothing stores, barbers and tattoo parlors provide a local preview and a server-authorized purchase. This resource manages clothing, selected hair settings and configured tattoos for freemode peds. Each appearance is stored for the current Bridge identifier and model. The catalog and shop locations are configurable and work without charcreator. Optional local integration reapplies saved clothing when `pop_charcreator:client:applied` fires.

## Files

`fxmanifest.lua`, `config.lua`, `common/catalog.lua`, `server/main.lua`, `client/main.lua`, `sql/install.sql`, `README.md`, template copies in `bridge/`, `shared/` and `web/kit/`, ten Lua locale files and `web/{index.html,script.js,style.css}`. oxmysql is required for persistence.

## Contract

- `pop_clothes:load` → `{ selections = { [categoryId] = optionId }, model }` for the player's current freemode model.
- `pop_clothes:open(shopId)` → `{ token, kind, selections, model }` or `nil, reason`. The target is registered with Bridge. Server verifies shop distance and model from the player's ped.
- `pop_clothes:buy(token, selections)` → `true, selections` or `false, reason`. Payload is a bounded table of category IDs to catalog option IDs, never prices or drawables. Only categories for the current shop qualify. Server revalidates session, life, identifier, model, routing bucket, shop distance, optional job/duty and price from config.
- `pop_clothes:cancel(token)` clears a matching session. Sessions and per-character locks prevent overlapping purchases. On a database failure, the server refunds the charge when the same character is still loaded.
- Server sends `pop_clothes:client:unloaded` after character unload to close the local shop.
- NUI receives `pop_clothes:panel` with `show`, `categories` and `currency`. Categories contain a locale key, the saved option ID, and available options with their label keys and display prices. NUI posts `pop_clothes:preview` and `pop_clothes:buy` with selections, `pop_clothes:rotate` with direction -1 or 1, and kit `close`.
- Server export `GetSelections(src)` returns a copy of loaded selections for the current model or nil. Client export `Reapply()` reloads and reapplies the currently saved selections.

## Data

`pop_clothes_outfits` stores one JSON selection map per identifier and model. Purchases update only changed categories. Already active selections cost nothing. Catalog entries supply the component or prop slot, gender-specific drawable/texture or tattoo hash, locale key and price. Preview validates native model limits before applying. Tattoos are limited to managed categories and may replace decorations from other resources when enabled. In standalone, configured catalog selections are free; supported frameworks charge the selected Bridge account unless the operator disables charging.

Config defines `Account`, `Currency`, `ShopDistance`, `SessionSeconds`, `Shops` and `Catalog`. A shop can define a job and require active duty. No permanent frame loop. A temporary clone and camera are cleaned up on close, death, unload and resource stop. No local preview is committed until persistence succeeds.

## Locales and verification

Ten locale files extending the exact kit, with Arabic RTL. Verify each shop class, preview cancellation, insufficient funds, invalid option/shop/model, concurrent attempts, saved reload, restart, standalone mode and character-creator integration.
