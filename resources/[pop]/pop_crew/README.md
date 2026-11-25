# pop_crew

**EN** — Simple crew system: create a crew (tag + name), recruit nearby players, choose a color, leave or disband. Works on ESX, QBCore, Qbox and standalone. 5 languages: fr, en, es, de, ar.
**FR** — Système de crew simple : créer un crew (tag + nom), recruter un joueur proche, choisir une couleur, quitter ou dissoudre. Fonctionne sur ESX, QBCore, Qbox et standalone. 5 langues : fr, en, es, de, ar.

## Installation (3 steps / 3 étapes)
1. Drop `pop_crew` in your resources (dépose le dossier dans tes ressources).
2. Make sure `oxmysql` starts before it, then add `ensure pop_crew` to your server.cfg (tables are created automatically / tables créées automatiquement).
3. Pick your language in `config.lua`: `Config.Locale = 'en'` (choisis ta langue).

Optional (facultatif): ox_target or qb-target (otherwise the E key is used / sinon touche E), pop_notify (notifications), pop_territories (map colors / couleurs sur la carte).

## Usage / Utilisation
- `/crew` opens the menu (ouvre le menu): create a crew, accept or decline an invite, see members, change the color (leader), leave or disband.
- Recruit (recruter): the leader targets a nearby player (ox_target / qb-target) and picks **Recruit into crew**, or walks up to them and presses **E**. The server checks the distance (`Config.RecruitMaxDistance`).

## Configuration
| Setting | Default | |
|---|---|---|
| `Config.Locale` | `'fr'` | fr, en, es, de, ar |
| `Config.Framework` / `Inventory` / `Target` / `Notify` | `'auto'` | auto-detected (détection automatique) |
| `Config.Command` | `'crew'` | menu command |
| `Config.MaxTagLen` / `MaxLabelLen` | 12 / 32 | tag and name length |
| `Config.DefaultColor` | `{93,144,236}` | color of a new crew |
| `Config.RecruitTargetDistance` / `RecruitMaxDistance` | 2.5 / 10.0 | recruit distances |

## Exports (server)
| Export | Returns |
|---|---|
| `exports.pop_crew:getCrew(src)` | crew of a player `{ id, name, label, color }` or nil |
| `exports.pop_crew:getCrewById(crewId)` | crew table or nil |
| `exports.pop_crew:getCrewIdByIdentifier(identifier)` | crew id or nil |
| `exports.pop_crew:getOnlineMemberSources(crewId)` | list of online player sources |

## Events (server)
| Event | Args |
|---|---|
| `pop_crew:disbanded` | crewId |
| `pop_crew:colorChanged` | crewId, color |

## Files / Fichiers
`config.lua` settings · `locales/` 5 languages · `bridge/` + `shared/` POP kit (do not edit) · `client/main.lua` menu · `client/recruit.lua` recruiting (target or E) · `server/` crews, database, exports · `html/` menu · `install/` SQL.
