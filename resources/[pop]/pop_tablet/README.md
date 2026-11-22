# pop_tablet : POP Tab

Tablette en objet d'inventaire (système « POP OS »). Les données (code, réglages, applis) sont liées à l'objet, pas au joueur.
Cahier des charges : `SPEC.md`. Avancement : `PROGRESS.md`, `feature_list.json`. API pour les autres ressources : `docs/api-applis.md`.

## Installation

1. `ensure oxmysql`, le framework et l'inventaire **avant** `ensure [pop]`, puis `ensure pop_tablet`.
2. Base de données : les tables sont créées au premier démarrage (`sql/install.sql`, aussi exécutable à la main).
3. Ajouter l'objet `pop_tablet` à l'inventaire du serveur (utilisable, empilable à 1, avec métadonnées). Exemple ox_inventory (`data/items.lua`) :
   - **ox_inventory** (`data/items.lua`) : `['pop_tablet'] = { label = 'POP Tab', weight = 500, stack = false, close = true }` ; le serial voyage dans `metadata.serial`, l'usage de l'objet est enregistré par pop_tablet.
   - **qb-inventory / ps-inventory** (`shared/items.lua`) : `['pop_tablet'] = { name = 'pop_tablet', label = 'POP Tab', weight = 500, type = 'item', image = 'pop_tablet.png', unique = true, useable = true, shouldClose = true, description = 'Tablette POP Tab' }`.
   - **qs-inventory** (`shared/items.lua`) : `['pop_tablet'] = { name = 'pop_tablet', label = 'POP Tab', weight = 500, type = 'item', image = 'pop_tablet.png', unique = true, useable = true, shouldClose = true, description = 'Tablette POP Tab' }`.
   - **pop_inventory** : l'objet `pop_tablet` est déjà dans `Config.Items` (utilisable, prop `prop_cs_tablet`, `onUse` qui ouvre la tablette). Ce dépôt ne gère presque pas les métadonnées : si `Bridge.SupportsMetadata()` est faux, le mode « une tablette par personnage » s'applique.
4. `server.cfg` :
   - `set pop_tablet_pepper "<chaîne aléatoire longue>"` (jamais `setr`). Sans elle, un poivre aléatoire est généré et conservé dans le KVP du serveur (avertissement en console).
   - `add_ace group.admin pop.admin allow` pour `/pop_tablet_give`.

## Utilisation

- Utiliser l'objet dans l'inventaire, ou la touche `Config.Key` (F5 par défaut, réglable dans les touches de FiveM) si l'on porte une tablette.
- Premier allumage : choix du code à 4 chiffres, du nom et de l'adresse mail.
- `/pop_tablet_give [id]` (admin) : crée une tablette avec son numéro de série.
- Inventaire sans métadonnées (ESX de base, standalone) : repli « une tablette par personnage », annoncé en console au démarrage.

## Règles

- Jamais de build sur le serveur : l'interface construite est versionnée dans `web/dist/`.
- `bridge/`, `shared/callback.lua`, `shared/locale.lua` et `web/kit/` sont copiés de `templates/pop_base` : ne pas les modifier ici.
- Tests Lua autonomes : `lua tests/run.lua` depuis ce dossier.

## Applis d'autres ressources

`exports.pop_tablet:RegisterApp`, `Notify`, `OpenApp`, `AppEvent` : voir `docs/api-applis.md`. Pages `https` autorisées : `Config.Browser.AllowedHosts`. Photos : `screencapture` doit être démarré (mode `database`).
