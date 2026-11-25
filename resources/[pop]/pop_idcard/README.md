# pop_idcard

**EN** — ID card (US / Mexico) with the holder's photo. Works with ESX, QBCore, Qbox and standalone. 5 languages: fr, en, es, de, ar (RTL).
**FR** — Carte d'identité (US / Mexique) avec la photo du titulaire. Compatible ESX, QBCore, Qbox et standalone. 5 langues : fr, en, es, de, ar (RTL).

## Installation (3 steps / 3 étapes)
1. **EN** Drop `pop_idcard` in `resources/` and add `ensure pop_idcard` to `server.cfg` (after your framework and inventory).
   **FR** Place `pop_idcard` dans `resources/` et ajoute `ensure pop_idcard` dans `server.cfg` (après ton framework et ton inventaire).
2. **EN** Add the items for your inventory from `install/` (`items_ox.lua`, `items_qb.lua`, `items_esx.sql` or `items_pop.lua`) and copy `install/images/`.
   **FR** Ajoute les objets de ton inventaire depuis `install/` et copie `install/images/`.
3. **EN** Set `Config.Locale` in `config.lua` (`fr`, `en`, `es`, `de`, `ar`). No SQL table needed.
   **FR** Règle `Config.Locale` dans `config.lua`. Aucune table SQL nécessaire.

Dependencies / dépendances : none. Optional: `pop_inventory` (wallet container), `pop_notify`, `pop_charcreator`.

## Configuration
| Key | Default | EN | FR |
|---|---|---|---|
| `Config.Locale` | `'fr'` | Language | Langue |
| `Config.CardItem` / `CardItemMx` | `'idcard'` / `'idcard_mx'` | Item names | Noms des objets |
| `Config.MexicoNationality` | `'nuevopaso'` | Nationality giving the MX card | Nationalité qui donne la carte MX |
| `Config.HolderRange` / `HolderServerRange` | `15.0` / `20.0` | Photo range (m) | Portée de la photo (m) |
| `Config.GiveCommand` | `'giveidcard'` | Admin command | Commande admin |

## Command / commande
`/giveidcard [id]` — admin only (ACE `pop.admin` or framework admin group), also from the server console.

## Events / évènements
| Event | Side | EN | FR |
|---|---|---|---|
| `pop_idcard:display` (itemData) | client | Shows a card (`itemData.meta`) | Affiche une carte |
| `pop_idcard:server:issueCardInternal` (src, containerId?, data?) | server (AddEventHandler) | Issues a card (used by pop_charcreator) | Délivre une carte |
| `pop_idcard:server:issueCard` (src) | server, server-only | Issues a card from the player's character | Délivre une carte |

Item metadata: `firstname`, `lastname`, `sex`, `identifier`, `cardType` (`us`/`mx`), `description`.

## Credits
Author: KL — POP.
