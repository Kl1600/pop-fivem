# SPEC — pop_inventory

Contrat commun des **4 lots** (Serveur cœur, Serveur conteneurs, Client, NUI), qui travaillent en parallèle sans se parler.
Les noms (fichiers, fonctions partagées, events, callbacks, messages NUI, champs JSON, clés de config et de locales)
sont **exacts** : ne pas les renommer. En cas d'ambiguïté, choisir l'option la plus sûre et la noter en commentaire `-- NOTE:`.

Fondation : `templates/pop_base` (lire `templates/pop_base/README.md`). API à utiliser : `Bridge.*`, `Callback.*`, `L()`, `Pop.*`.
Aucune commande git. Modèle fonctionnel lu (tab_inventory) : on n'en reprend **aucun code** ni ses modules annexes
(chargeurs, douilles, sabot, peinture, radio, clés de véhicule, lampe UV). Ceux-ci deviennent des scripts séparés qui
passent uniquement par l'API Bridge (items avec metadata, items utilisables, events standards ci-dessous).

Plan : 1 Description · 2 Arborescence et lots · 3 Formats · 4 Events · 5 Callbacks · 6 NUI · 7 Exports · 8 SQL ·
9 Config · 10 Locales · 11 Contrat interne par lot · 12 Sécurité · 13 Critères d'acceptation.

---

## 1. Description et fonctionnalités

Inventaire complet POP, à **slots + poids**, autonome (remplace ox/qb/qs-inventory), compatible ESX Legacy / ancien ESX,
QBCore, Qbox (voir §1.3) et standalone. Sobre : deux panneaux sur les côtés, le centre de l'écran reste libre.

### 1.1 Fonctionnalités (périmètre complet, rien de plus)
1. **Inventaire joueur** : `Config.Slots` slots, poids max `Config.MaxWeight` (grammes). Items empilables ou non,
   **metadata par item** (durabilité, série, plaque, qualité, munitions, libellé/description/image personnalisés).
2. **Hotbar 1-5** : les slots 1 à 5 du joueur. Touches 1-5 = utiliser le slot ; une petite barre s'affiche 2,5 s.
3. **Utilisation d'items** : armes (équiper / ranger), munitions (recharger), items enregistrés par
   `RegisterUsableItem` (scripts POP via le Bridge, ou autres), puis repli sur les items utilisables du framework.
4. **Donner** à un joueur proche (glisser sur « Donner » ; joueur le plus proche à `Config.GiveDistance`).
5. **Sol** : déposer = glisser vers le panneau « Sol ». Les dépôts (drops) sont visibles par tous (petit prop local,
   streamé par distance), expirent après `Config.Drops.Lifetime`, disparaissent quand ils sont vides.
6. **Véhicules** : boîte à gants (dans le véhicule) et coffre (à l'arrière, véhicule non verrouillé), **par plaque**.
   Taille selon le type de véhicule (serveur), surcharge possible par modèle. Sauvegardés seulement pour les véhicules
   possédés (table du framework) ; en standalone, tous.
7. **Stockages (stashes)** : définis dans `Config.Stashes` ou par export `RegisterStash` (casiers, coffres de société).
   Option `jobs` (format `Bridge.HasJob`) et `owner = true` (un stockage par personnage au même endroit).
8. **Boutiques** simples par config (`Config.Shops`) ou export `RegisterShop` : achat payé par `Bridge.RemoveMoney`
   (`cash` ou `bank`), ou par l'item d'argent si `Config.CashItem`.
9. **Armes comme items** : série unique, munitions dans `metadata.ammo` (chargeur), durabilité qui baisse au tir
   (`degrade`), arme cassée inutilisable. Une seule arme en main, suivie par le serveur.
10. **Fouille** d'un joueur mort ou menotté (`/search` ou export client), si `Config.SearchCommand ~= false`.
11. **Persistance oxmysql** (tables `pop_inventory_players`, `pop_inventory_stashes`) : sauvegarde différée
    (inventaires modifiés seulement, toutes les `Config.SaveInterval` s), à la déconnexion, au changement de personnage,
    à l'arrêt.
12. **Argent** : compte du framework (défaut) **ou** item physique synchronisé avec le compte `cash` (`Config.CashItem`).
13. **Items** définis dans `data/items.lua` ; import automatique des définitions et des anciens inventaires du framework
    (`Config.ImportFramework`).
14. **Exports serveur compatibles ox_inventory** pour les fonctions courantes + `RegisterUsableItem` (contrat Bridge).
15. **Interface** : grille, glisser-déposer, quantité au clavier, info-bulle simple, images `web/images/<item>.png`
    avec image par défaut, RTL arabe.

Hors périmètre (volontairement) : craft, sacs / conteneurs imbriqués, vêtements, accessoires d'armes, licences, hooks
`registerHook`, `ConfiscateInventory`, `metadata.weight`, menu admin graphique, drops persistants après redémarrage.

### 1.2 Contrat Bridge (déjà attendu par `templates/pop_base/bridge/server.lua`) — respecté exactement
| Export appelé par le Bridge | Signature pop_inventory | Retour |
|---|---|---|
| `GetItemCount(src, item)` | `GetItemCount(inv, item, metadata?, strict?)` | `number` |
| `AddItem(src, item, count, metadata)` | `AddItem(inv, item, count, metadata?, slot?)` | `true` ou `false, reason` |
| `RemoveItem(src, item, count, metadata)` | `RemoveItem(inv, item, count, metadata?, slot?)` | `true` ou `false, reason` |
| `CanCarryItem(src, item, count)` | `CanCarryItem(inv, item, count, metadata?)` | `bool` |
| `RegisterUsableItem(item, cb(src, item, metadata))` | `RegisterUsableItem(item, cb)` ; `cb(src, item, metadata, slot)` (4e argument en plus) | `true` |

Les arguments en plus sont facultatifs : les appels du Bridge restent valides tels quels.
`pop_doorlock` appelle déjà `GetItemCount(src, 'door_key', { pop_door = keyId })` : le filtre metadata est supporté (§7).
**Écart documenté** : le Bridge des autres scripts ne détecte `pop_inventory` que s'il est **démarré avant eux**
(`ensure pop_inventory` avant `ensure [pop]` dans `server.cfg`, écrit dans le README).

### 1.3 Frameworks et autres inventaires
- **ESX Legacy / ancien ESX, QBCore, standalone** : identité, argent, jobs, mort via `Bridge.*`.
- **Scripts tiers** qui appellent directement l'inventaire du framework (`xPlayer.addInventoryItem`,
  `Player.Functions.AddItem`…) : couche de compatibilité `server/framework.lua` (`Config.FrameworkHooks`, §11.1.5).
  Ancien ESX : pas de mécanisme de surcharge → seuls les scripts passant par les exports / le Bridge voient les items
  (avertissement console, documenté dans le README).
- **Qbox** : `qbx_core` exige `ox_inventory`. Le `fxmanifest.lua` contient la ligne commentée `-- provide 'ox_inventory'` ;
  le README explique de la décommenter (et de ne pas lancer ox_inventory) pour Qbox.
  `-- NOTE:` mode à valider en jeu : pop_inventory expose les exports serveur courants d'ox_inventory (§7), pas son API complète.
- **Conflit** : au démarrage, si `ox_inventory`, `qs-inventory`, `qb-inventory` ou `ps-inventory` est `started`,
  afficher une erreur console claire (anglais) : deux inventaires ne doivent pas tourner ensemble.

---

## 2. Arborescence, lots et attribution

```
resources/[pop]/pop_inventory/
  SPEC.md                    Architecte (ce fichier)
  fxmanifest.lua             LOT 1   (§2.2)
  config.lua                 LOT 1   (clés communes du template + §9)
  README.md                  LOT 1   (installation, ordre ensure, Qbox, images, exports, items)
  sql/install.sql            LOT 1   (§8)
  data/items.lua             LOT 1   (§9.2)
  bridge/server.lua          LOT 1   copie STRICTE de templates/pop_base
  bridge/client.lua          LOT 3   copie STRICTE de templates/pop_base
  shared/callback.lua        LOT 1   copie STRICTE
  shared/locale.lua          LOT 1   copie STRICTE
  locales/en.lua … ar.lua    LOT 1   10 fichiers : bloc « Kit commun » inchangé + §10
  server/items.lua           LOT 1   registre des items, import des définitions du framework, libellés
  server/inventory.lua       LOT 1   objet Inventory : slots, poids, add/remove/move, metadata, synchro, dirty
  server/database.lua        LOT 1   tables, chargement / sauvegarde, migration des anciens inventaires, arrêt
  server/framework.lua       LOT 1   surcharges ESX / QBCore, miroir PlayerData.items, items utilisables du framework
  server/players.lua         LOT 1   cycle de vie joueur, callbacks init/move/use/give/reload, armes, argent, /giveitem
  server/containers.lua      LOT 2   sessions d'ouverture, accès, callbacks open/close, forceOpen, déchargement
  server/drops.lua           LOT 2   dépôts au sol
  server/vehicles.lua        LOT 2   coffre et boîte à gants
  server/stashes.lua         LOT 2   stockages (config + RegisterStash)
  server/shops.lua           LOT 2   boutiques (config + RegisterShop), callback buy
  server/search.lua          LOT 2   règles de fouille (menotté / mort)
  server/exports.lua         LOT 1   tous les exports serveur (§7.1), délèguent à Inventory / Containers
  client/main.lua            LOT 3   init, cache, ouverture/fermeture, contexte (véhicule, sol), NUI, hotbar, fouille, exports
  client/weapons.lua         LOT 3   arme en main, munitions, rechargement, durabilité
  client/world.lua           LOT 3   props des drops (streaming), zones stashes/boutiques, blips
  web/index.html             LOT 4
  web/style.css              LOT 4
  web/script.js              LOT 4
  web/images/default.svg     LOT 4   image par défaut (SVG simple, une couleur)
  web/kit/pop.css, pop.js    LOT 4   copie STRICTE de templates/pop_base/web/kit
```

Les fichiers `client/main.lua`, `server/main.lua` et `web/script.js` du template sont remplacés : il n'existe **pas**
de `server/main.lua`, ni d'autre fichier que ceux listés.

### 2.1 Découpage en 4 lots indépendants
| Lot | Rôle | Fichiers | Dépend de (contrat seulement) |
|---|---|---|---|
| **1 — Serveur cœur** | items, inventaires, persistance, exports, actions joueur, armes, argent, framework | `fxmanifest.lua`, `config.lua`, `README.md`, `sql/`, `data/`, `bridge/server.lua`, `shared/`, `locales/`, `server/items.lua`, `inventory.lua`, `database.lua`, `framework.lua`, `players.lua`, `exports.lua` | `Containers.*` (§11.2.1) |
| **2 — Serveur conteneurs** | sol, véhicules, stashes, boutiques, fouille, sessions | `server/containers.lua`, `drops.lua`, `vehicles.lua`, `stashes.lua`, `shops.lua`, `search.lua` | `Inventory.*`, `Items.*`, `LabelOf`, `ReconcileCash` (§11.1.2) |
| **3 — Client** | tout le Lua client | `bridge/client.lua`, `client/*.lua` | events §4, callbacks §5, messages NUI §6 |
| **4 — NUI** | interface | `web/**` | messages NUI §6 |

Le lot 1 écrit **toutes** les clés de config et de locales (y compris celles utilisées par les lots 2, 3, 4).
Le lot 2 ne crée aucune table SQL : il passe par `Inventory.Load` / `Inventory.Save` (lot 1), sauf la lecture des tables
de véhicules possédés du framework (§11.2.3).

### 2.2 fxmanifest.lua (exact, LOT 1)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_inventory'
author 'POP'
version '1.0.0'
description 'POP Inventory - slots, weight, metadata, vehicles, stashes, shops'

dependencies { 'oxmysql' }

-- Qbox uniquement (voir README) : décommenter pour remplacer ox_inventory, que qbx_core exige.
-- provide 'ox_inventory'

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
    'client/weapons.lua',
    'client/world.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'data/items.lua',
    'server/items.lua',
    'server/inventory.lua',
    'server/database.lua',
    'server/framework.lua',
    'server/players.lua',
    'server/containers.lua',
    'server/drops.lua',
    'server/vehicles.lua',
    'server/stashes.lua',
    'server/shops.lua',
    'server/search.lua',
    'server/exports.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/**',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
    'data/*.lua',
}
```

### 2.3 Globales partagées et luacheck
Côté serveur, les fichiers partagent les tables globales `Items` (lot 1), `Inventory` (lot 1), `Containers` (lot 2), et les
fonctions globales `LabelOf` et `ReconcileCash` (lot 1). Chaque fichier qui ajoute des fonctions à une table commence par
`Items = Items or {}` / `Inventory = Inventory or {}` / `Containers = Containers or {}` (définition au niveau supérieur :
acceptée par `allow_defined_top` de `.luacheckrc`). Les fonctions ne s'appellent entre fichiers **qu'à l'exécution**
(jamais au chargement d'un fichier) : l'ordre du manifest suffit.
`data/items.lua` définit la globale `ItemList = { ... }`. Côté client, une table globale `PopInv` est partagée par les 3 fichiers.

---

## 3. Formats de données (communs à tous les lots)

**Noms d'items** : toujours en minuscules (`name:lower()` à chaque entrée d'export, de config ou de commande).
Une arme s'appelle `weapon_pistol` ; son hash est `joaat(name:upper())`.

**Poids** : entiers en grammes. Affichage en kg avec une décimale.

**Item (serveur et réseau)** :
```json
{ "slot": 3, "name": "weapon_pistol", "count": 1,
  "metadata": { "serial": "POP482913", "ammo": 12, "durability": 87.5, "registered": "John Doe" } }
```
`metadata` est toujours une table côté Lua. Attention : `json.encode({})` donne `[]` → la NUI traite un tableau comme un objet vide.

**Clés de metadata reconnues** (affichées dans l'info-bulle si présentes, toutes facultatives) :
`label` (remplace le libellé), `description` (remplace la description), `image` (nom de fichier sans extension),
`durability` (0-100), `ammo` (entier), `serial` (texte), `plate` (texte), `quality` (0-100), `registered` (texte).
Les autres clés (ex. `pop_door`) sont conservées mais **jamais affichées**.
Armes : à la création, `serial` (`'POP'` + 6 chiffres aléatoires), `ammo = 0`, `durability = 100` sont ajoutés s'ils manquent.

**Définition d'item envoyée au client et à la NUI** (`ItemDefs`, table indexée par nom) :
```json
{ "water_bottle": { "label": "Water bottle", "weight": 500, "stack": true, "close": true,
                    "description": null, "image": null, "weapon": false, "ammo": null } }
```
`label` et `description` sont **déjà traduits** par le serveur (règle `Items.Label`, §9.2).

**Vue d'inventaire** (`InvView`) : les items sont une **liste** (jamais une table indexée par slot, à cause de JSON).
```json
{ "type": "player", "label": "Inventory", "slots": 40, "maxWeight": 30000, "weight": 1250,
  "items": [ { "slot": 1, "name": "water_bottle", "count": 3, "metadata": {} } ] }
```
`type` ∈ `player` | `stash` | `trunk` | `glovebox` | `drop` | `newdrop`. `newdrop` = panneau « Sol » vide
(aucun drop proche) : `label = L('inv_ground')`, `slots = Config.Drops.Slots`, `maxWeight = Config.Drops.MaxWeight`, `items = []`.
Un joueur fouillé apparaît à droite avec `type = 'player'` et `label = L('inv_searched')`.

**Vue de boutique** (`ShopView`) : le `slot` est l'index de l'article dans la boutique (1..n, articles autorisés seulement).
```json
{ "type": "shop", "label": "24/7", "account": "cash", "slots": 3,
  "items": [ { "slot": 1, "name": "water_bottle", "count": 1, "price": 5, "metadata": {} } ] }
```

**Changements** (`Changes`, envoyés après chaque opération) :
```json
{ "changes": [ { "side": "player", "slot": 3, "item": { "slot": 3, "name": "bread", "count": 2, "metadata": {} } },
               { "side": "secondary", "slot": 7, "item": false } ],
  "weights": { "player": 1450, "secondary": 800 } }
```
`side` est calculé **par destinataire** : `player` = son propre inventaire, `secondary` = l'inventaire ouvert à droite.
`item: false` = slot vidé. `weights` ne contient que les côtés concernés.

**Identifiants d'inventaire** (internes et colonne SQL) :
| Inventaire | `inv.id` | Clé SQL |
|---|---|---|
| joueur | `src` (number) | `identifier` dans `pop_inventory_players` |
| stash partagé | `'stash:<id>'` | même chaîne dans `pop_inventory_stashes` |
| stash par personnage | `'stash:<id>:<identifier>'` | idem |
| coffre | `'trunk:<PLAQUE>'` | idem (si possédé) |
| boîte à gants | `'glovebox:<PLAQUE>'` | idem (si possédé) |
| drop | `'drop:<n>'` | jamais sauvegardé |

`PLAQUE` = `GetVehicleNumberPlateText` serveur, espaces retirés aux extrémités, en majuscules.
Les exports acceptent aussi un nom de stash sans préfixe (`'police_locker'` → `'stash:police_locker'`) et
`{ id = 'police_locker', owner = identifier }` (compatibilité ox).

---

## 4. Events réseau

Les demandes du client passent par des **callbacks** (§5), sauf la remontée des munitions (fréquente, sans réponse).

### 4.1 Client → serveur
| Event | Paramètres | Rôle (LOT 1, `server/players.lua`) |
|---|---|---|
| `pop_inventory:server:updateWeapon` | `ammo` (int) | Munitions restantes de l'arme en main. Throttle serveur `WEAPON_UPDATE_THROTTLE`. Accepté seulement si une arme est équipée et `0 <= ammo <= metadata.ammo` (baisse uniquement). Durabilité -= `(ancien - ammo) * def.degrade`, bornée à 0 |

### 4.2 Serveur → client
| Event | Cible | Paramètres | Émis par | Rôle côté client (LOT 3) |
|---|---|---|---|---|
| `pop_inventory:client:update` | joueur | `data` (format `Changes`) | LOT 1 | Met à jour le cache (côté `player`), transmet à la NUI `pop_inventory:update`, calcule les variations (§11.3) |
| `pop_inventory:client:open` | joueur | `payload` (même format que le retour de `pop_inventory:open`) | LOT 2 (`forceOpenInventory`) | Ouvre comme une ouverture demandée |
| `pop_inventory:client:close` | joueur | — | LOT 2 | Ferme l'interface (sans rappeler le serveur) |
| `pop_inventory:client:reset` | joueur | — | LOT 1 | Changement de personnage : ferme, range l'arme, vide le cache |
| `pop_inventory:client:addDrop` | `-1` | `drop` = `{ id, coords = {x,y,z} }` | LOT 2 | Ajoute le drop au streaming |
| `pop_inventory:client:removeDrop` | `-1` | `id` (int) | LOT 2 | Supprime le prop et sa cible |
| `pop_inventory:client:useWeapon` | joueur | `weapon` = `{ slot, name, ammo, durability }` | LOT 1 | Équipe l'arme (§11.3) |
| `pop_inventory:client:holster` | joueur | — | LOT 1 | Range / retire l'arme en main |
| `pop_inventory:client:setAmmo` | joueur | `ammo` (int) | LOT 1 | `SetPedAmmo` de l'arme en main (après rechargement) |
| `pop_inventory:client:searched` | joueur fouillé | — | LOT 2 | `Bridge.Notify(L('being_searched'), 'warning')` |

Notifications : toujours `Bridge.Notify(src, L(key, ...), type)` (event du bridge, ne pas recréer).

### 4.3 Events locaux pour les autres ressources
| Côté | Event | Paramètres | Quand |
|---|---|---|---|
| serveur | `pop_inventory:usedItem` | `src`, `name`, `slot`, `metadata` | Après une utilisation réussie (tout type) |
| serveur | `pop_inventory:openedInventory` | `src`, `invId` | Ouverture d'un inventaire secondaire (pas `newdrop` ni boutique) |
| serveur | `pop_inventory:closedInventory` | `src`, `invId` | Fermeture de cet inventaire |
| client | `pop_inventory:itemCount` | `name`, `count` | Total d'un item du joueur modifié |
| client | `pop_inventory:currentWeapon` | `weapon` (`{ slot, name, metadata }`) ou `nil` | Arme équipée / rangée |

**Statebag** (compatibilité ox) : `invBusy`. Si `LocalPlayer.state.invBusy` (client) ou `Player(src).state.invBusy`
(serveur) vaut `true`, ouverture et utilisation sont refusées (`cannot_now`), et une interface ouverte se ferme.

---

## 5. Callbacks (`shared/callback.lua`)

Tous déclarés côté serveur par `Callback.Register` et appelés côté client par `Callback.Await` / `Callback.Trigger`.
Convention : `ok (bool), reason (clé de locale) | nil, ...`. `nil` (timeout / anti-spam) = `reason = 'error'`.
Le client affiche les échecs : `Bridge.Notify(L(reason or 'error'), 'error')` (`cooldown` : `L('cooldown', 1)`).
Les succès sont notifiés par le serveur si besoin. Aucun callback serveur → client.

| Nom | Lot | Paramètres | Retour |
|---|---|---|---|
| `pop_inventory:init` | 1 | — | `nil` si pas encore chargé (attente serveur `PLAYER_LOAD_TIMEOUT`), sinon `data` : `{ items = ItemDefs, inventory = InvView (player), drops = { {id, coords}, ... }, stashes = { {id, label, coords}, ... }, shops = { {id, label, coords = { {x,y,z}, ... }, blip = {sprite, color} \| nil}, ... }, weapon = { slot, name, ammo, durability } \| nil }` ; `drops`, `stashes`, `shops` viennent de `Containers.GetPoints()` |
| `pop_inventory:open` | 2 | `request` (voir ci-dessous) ou `nil` | `true, payload` ou `false, reason` |
| `pop_inventory:close` | 2 | — | `true` |
| `pop_inventory:move` | 1 | `from` (`'player'`\|`'secondary'`), `fromSlot` (int), `to` (idem), `toSlot` (int\|nil), `count` (int\|nil) | `ok, reason` |
| `pop_inventory:give` | 1 | `slot` (int), `count` (int\|nil), `target` (server id) | `ok, reason` |
| `pop_inventory:use` | 1 | `slot` (int) | `ok, reason, close` (`close` = bool, si `ok` : fermer l'interface) |
| `pop_inventory:reload` | 1 | — | `ok, reason` (le client reçoit aussi `client:setAmmo`) |
| `pop_inventory:buy` | 2 | `index` (int), `count` (int), `toSlot` (int\|nil) | `ok, reason` |

**`request` de `pop_inventory:open`** (le client décrit le contexte, le serveur vérifie tout) :
```lua
nil                                    -- inventaire seul + panneau Sol (newdrop)
{ type = 'glovebox', netId = 1234 }
{ type = 'trunk',    netId = 1234 }
{ type = 'drop',     id = 7 }
{ type = 'stash',    id = 'police_locker' }
{ type = 'shop',     id = 'general' }
{ type = 'player',   target = 5 }      -- fouille
```

**`payload`** :
```json
{ "player": InvView, "secondary": InvView | ShopView,
  "watch": { "coords": {"x":0,"y":0,"z":0} | null, "netId": 1234 | null, "target": 5 | null, "distance": 3.0 } | null }
```
`secondary` est la vue `newdrop` quand `request = nil`. `watch` sert au client à fermer l'interface s'il s'éloigne
(`null` pour `newdrop`, la boîte à gants et les sessions forcées). `distance` = portée du type + 1.0 m.

Raisons possibles : `error`, `busy`, `cooldown`, `cannot_now`, `too_far`, `wrong_job`, `not_loaded`,
`invalid_item`, `item_not_found`, `item_not_usable`, `inventory_full`, `container_full`, `target_full`,
`no_player_nearby`, `vehicle_locked`, `no_trunk`, `cannot_search`, `weapon_broken`, `weapon_needed`, `no_ammo`,
`ammo_full`, `not_enough_money`.

---

## 6. Messages NUI

Page unique `web/index.html`. Le HUD du kit (`pop:prompt`, `pop:progress`, `pop:notify`) reste disponible.
Tout le texte vient des locales (`data-locale`, `Pop.t`) ou des libellés déjà traduits envoyés par le Lua.
Insertion de texte **uniquement** par `textContent`.

### 6.1 Lua → JS (`SendNUIMessage`)
| `action` | Données | Rôle |
|---|---|---|
| `pop_inventory:items` | `{ items: ItemDefs }` | Définitions. Envoyé une fois, **avant** le premier message qui en a besoin (fonction client `PopInv.EnsureNuiItems()`) |
| `pop_inventory:open` | `{ player: InvView, secondary: InvView \| ShopView }` | Affiche l'interface |
| `pop_inventory:close` | `{}` | Masque tout (idempotent), annule un glisser en cours |
| `pop_inventory:update` | format `Changes` | Met à jour les slots et les poids affichés |
| `pop_inventory:hotbar` | `{ items: [Item \| null ×5], active: 1-5 \| null }` | Barre 1-5 affichée 2,5 s (`active` en accent) |
| `pop_inventory:itemNotify` | `{ name: "bread", count: 2, added: true }` | Petit rappel « +2 Pain » (interface fermée seulement) |

### 6.2 JS → Lua (`RegisterNUICallback`, via `Pop.post`)
| Nom | Corps JSON | Réponse | Côté Lua (LOT 3) |
|---|---|---|---|
| `move` | `{ "from": "player", "fromSlot": 3, "to": "secondary", "toSlot": 7, "count": 0 }` | `{ "ok": true }` ou `{ "ok": false, "error": "<clé>" }` | `pop_inventory:move` ; `count` 0 → `nil` (pile entière) ; `toSlot` absent → `nil` (placement auto) |
| `buy` | `{ "index": 1, "count": 2, "toSlot": 4 }` | idem | `pop_inventory:buy` ; `count` 0 → 1 |
| `use` | `{ "slot": 3 }` | idem | `pop_inventory:use` ; si `close` → fermeture |
| `give` | `{ "slot": 3, "count": 0 }` | idem | joueur le plus proche à `Config.GiveDistance` (client) ; aucun → `{ ok: false, error: "no_player_nearby" }` ; sinon `pop_inventory:give` |
| `close` | — | (bridge) | Déjà géré par le bridge (Échap, ou `Pop.post('close')` pour TAB / I) → `Bridge.OnUiClose` → fermeture côté client + `pop_inventory:close` |

En cas d'échec, le **Lua** notifie (`Bridge.Notify(L(error), 'error')`) ; la NUI n'affiche pas de toast. La NUI ne modifie
jamais elle-même les slots : seul `pop_inventory:update` les change (le serveur fait autorité).

### 6.3 Interface (LOT 4)
DA POP : fond uni `--pop-bg`, texte blanc, **une** couleur d'accent `--pop-accent`, police système, aucun dégradé,
aucun glassmorphism, aucune ombre lourde, fondu 150 ms (`pop-fade` + `Pop.show`). Unités en `vh` pour suivre la résolution.

- **Disposition** : `#inventory` contient trois blocs ; le centre de l'écran reste libre.
  - `#panel-player` collé à gauche (`left: 3vw`, centré verticalement), `#panel-secondary` collé à droite (`right: 3vw`).
  - `#center` : colonne étroite (≈ 9vh de large) **juste à côté du panneau joueur** : champ `#amount`
    (`type="number"`, min 0, placeholder `ui_amount_hint`, libellé `ui_amount`), boutons `#btn-use` (`ui_use`) et
    `#btn-give` (`ui_give`), qui sont aussi des zones de dépôt.
  - RTL (`[dir="rtl"]`) : les côtés s'inversent (joueur à droite, secondaire à gauche, colonne centrale côté intérieur du joueur).
- **Panneau** : en-tête = `label` reçu, poids `Pop.t('ui_weight_value', kg(weight), kg(maxWeight))` ; barre de poids
  **fine** (3 px) en accent, `--pop-danger` au-delà de 90 % ; grille de 5 colonnes, slots carrés (≈ 7vh), défilement
  vertical si nécessaire (hauteur max 70vh). Boutique : pas de poids ni de barre.
- **Slot** : image (contain), quantité en bas à droite si `count > 1` (`x3`), numéro 1-5 discret en haut à gauche pour
  les slots 1-5 du joueur, barre fine de durabilité en bas si `metadata.durability` est un nombre (`--pop-danger` sous 20).
  Boutique : prix en bas (`Pop.t('ui_price', price)`). Slot survolé : bordure accent.
- **Image** : `images/<metadata.image || def.image || name>.png` ; `onerror` → `images/default.svg` (une seule fois, pas de boucle).
- **Glisser-déposer** à la souris (mousedown → fantôme qui suit le curseur → mouseup ; pas l'API HTML5 drag) :
  - sur un slot du même panneau ou de l'autre → `move` (`count` = valeur de `#amount`, 0 = tout) ;
  - depuis la boutique vers un slot joueur → `buy` (`count` = `#amount` ou 1) ;
  - sur `#btn-use` (depuis le joueur) → `use` ; sur `#btn-give` (depuis le joueur) → `give` ;
  - ailleurs, ou vers la boutique → annulé.
- **Raccourcis souris** : double-clic sur un slot joueur → `use` ; Maj + clic → `move` vers l'autre panneau sans `toSlot`
  (depuis la boutique : `buy` sans `toSlot`).
- **Clavier** : chiffres saisis dans `#amount` ; TAB et I → `Pop.post('close')` (ignorer `e.repeat`) ; Échap est déjà géré
  par le kit. `#amount` garde sa valeur entre deux ouvertures.
- **Info-bulle** `#tooltip` (après 250 ms de survol, masquée pendant un glisser) : libellé (`metadata.label || def.label`),
  description, poids de la pile (`ui_weight` : `Pop.t('ui_kg', …)`), puis une ligne par clé de metadata reconnue présente :
  `meta_durability` (`%`), `meta_ammo`, `meta_serial`, `meta_plate`, `meta_quality` (`%`), `meta_registered` ;
  boutique : `Pop.t('ui_price', price)`. Petite, bord accent côté début (`border-inline-start`), suit la souris sans sortir de l'écran.
- **Hotbar** `#hotbar` : en bas au centre, 5 petits slots (≈ 5.5vh), masquée après 2,5 s (minuterie relancée à chaque message).
- **Rappels** `#notify` : en bas à gauche (à droite en RTL), 4 lignes max : image 3vh + `+2 Pain` / `-1 Pain`
  (`+` en accent, `-` atténué), 2,5 s chacune. Libellé = `defs[name].label`.
- Le JS ne fait **aucune** validation de sécurité, ne touche pas au focus, n'a aucun texte en dur ni dépendance externe.

---

## 7. Exports publics

### 7.1 Serveur (LOT 1, `server/exports.lua`) — noms et comportement d'ox_inventory
`inv` = `src` (number) | id d'inventaire (§3) | nom de stash | `{ id, owner }`. Les exports ne s'appliquent qu'aux
inventaires **chargés** (joueur en ligne, stash enregistré, coffre ouvert récemment) ; sinon `false, 'not_loaded'`
(ou `0` / `nil` selon le retour). **Écart ox documenté** : aucun chargement SQL dans un export (un export ne peut pas attendre).
`metadata` en entrée : table, ou chaîne → `{ type = chaîne }` (comme ox). Copie profonde en entrée et en sortie.
Filtre metadata : toutes les clés du filtre sont égales dans l'item ; `strict = true` : égalité complète.

| Export | Retour | Notes |
|---|---|---|
| `Items(name?)` | def \| table de toutes les defs | copie (format `ItemDefs` + `consume`, `clip`, `degrade`) |
| `AddItem(inv, item, count, metadata?, slot?)` | `true` \| `false, reason` | `reason` : `invalid_item`, `invalid_metadata`, `inventory_full`, `not_loaded` |
| `RemoveItem(inv, item, count, metadata?, slot?)` | `true` \| `false, reason` | tout ou rien ; `reason` : `item_not_found`, `not_loaded` |
| `GetItemCount(inv, item, metadata?, strict?)` | `number` | |
| `Search(inv, 'count' \| 'slots', items, metadata?)` | comme ox | `items` chaîne → nombre / liste d'items ; table de noms → table `{ [name] = … }` |
| `CanCarryItem(inv, item, count, metadata?)` | `bool` | poids + slot libre ou pile compatible |
| `CanCarryWeight(inv, weight)` | `bool` | |
| `GetItem(inv, item, metadata?, returnsCount?)` | item agrégé `{ name, label, weight, count, metadata }` \| `number` | |
| `GetSlot(inv, slot)` | item \| `nil` | avec `label` et `weight` (de la pile) |
| `GetSlotWithItem(inv, item, metadata?, strict?)` | item \| `nil` | premier slot |
| `GetSlotsWithItem(inv, item, metadata?, strict?)` | liste d'items | |
| `SetMetadata(inv, slot, metadata)` | `bool` | remplace la metadata ; synchro + dirty |
| `SetDurability(inv, slot, durability)` | `bool` | bornée 0-100 |
| `GetInventory(inv)` | `{ id, type, label, slots, maxWeight, weight, owner }` \| `nil` | |
| `GetInventoryItems(inv)` | liste d'items | |
| `ClearInventory(inv, keep?)` | `bool` | `keep` = nom ou liste de noms conservés |
| `RegisterStash(id, label, slots, maxWeight, owner?, groups?, coords?)` | `bool` | délègue à `Containers.RegisterStash` ; `owner = true` → un stockage par personnage |
| `RegisterShop(id, data)` | `bool` | `data` = une entrée `Config.Shops` sans `id` ; délègue à `Containers.RegisterShop` |
| `forceOpenInventory(src, invType, data)` | `bool` | `invType` ∈ `stash` (data = id ou `{ id, owner }`), `trunk`/`glovebox` (data = plaque), `drop` (data = id), `shop` (data = id), `player` (data = server id) ; sans contrôle de distance ni de job (réservé aux scripts) ; délègue à `Containers.ForceOpen` |
| `RegisterUsableItem(item, cb)` | `true` | `cb(src, item, metadata, slot)` ; un seul cb par item (le dernier remplace) ; retiré quand la ressource appelante s'arrête (`GetInvokingResource`) |
| `GetCurrentWeapon(src)` | item (comme `GetSlot`) \| `nil` | arme équipée suivie par le serveur, même slot / nom / série ; `nil` si le ped tient une autre arme (`GetSelectedPedWeapon(ped) & 0xFFFFFFFF` comparé à `joaat(nom) & 0xFFFFFFFF`, ignoré si la native renvoie 0) |

### 7.2 Client (LOT 3, `client/main.lua`)
| Export | Retour |
|---|---|
| `openInventory(invType?, data?)` | `bool` — `invType` ∈ `nil`, `stash` (data = id), `shop` (data = id), `player` (data = server id) : passe par `pop_inventory:open` (contrôles serveur normaux) |
| `closeInventory()` | — |
| `GetItemCount(item, metadata?)` | `number` (cache local) |
| `Search('count' \| 'slots', items, metadata?)` | comme le serveur, sur le cache |
| `Items(name?)` | defs (cache) |
| `GetCurrentWeapon()` | `{ slot, name, metadata }` \| `nil` |
| `searchPlayer()` | ouvre la fouille du joueur le plus proche (le serveur vérifie) |

---

## 8. Schéma SQL (`sql/install.sql`, LOT 1)

Le serveur exécute aussi ces `CREATE TABLE IF NOT EXISTS` au démarrage (le fichier reste facultatif).
```sql
CREATE TABLE IF NOT EXISTS `pop_inventory_players` (
  `identifier` VARCHAR(64) NOT NULL,
  `items`      LONGTEXT    NOT NULL,              -- JSON [{"slot":1,"name":"bread","count":2,"metadata":{...}}]
  `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `pop_inventory_stashes` (
  `id`         VARCHAR(100) NOT NULL,             -- 'stash:police_locker', 'stash:police_locker:<identifier>', 'trunk:ABC123', 'glovebox:ABC123'
  `items`      LONGTEXT     NOT NULL,
  `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
Règles :
- Requêtes **paramétrées** (`?`), jamais de concaténation. JSON : `metadata` omis s'il est vide.
- Écriture : `INSERT INTO … (…) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)`. Conteneur vide → `DELETE`
  (l'inventaire joueur vide est écrit `[]`, jamais supprimé).
- Chargement : `MySQL.single.await`. Item inconnu (absent du registre) : ignoré en mémoire + avertissement console
  (clé, nom, quantité). Slot hors limites ou en double : l'item va dans le premier slot libre.
- Aucune table pour les items, les boutiques ou les drops.

---

## 9. config.lua (LOT 1)

Garder **à l'identique** les clés communes du template, avec deux valeurs propres au script :
`Config.Inventory = 'none'` (commentaire : « ne pas changer : pop_inventory ne passe jamais par le Bridge pour ses propres items »)
et `Config.CallbackRateLimit = 15`. Puis ajouter à la suite :

```lua
-- pop_inventory ------------------------------------------------------------

Config.OpenKey   = 'TAB'    -- touche par défaut (chaque joueur peut la changer dans les paramètres FiveM)
Config.Slots     = 40       -- slots du joueur (1 à 5 = hotbar)
Config.MaxWeight = 30000    -- poids max du joueur, en grammes

-- Argent physique : nom d'un item (ex. 'money') synchronisé avec le compte 'cash' du framework.
-- false = l'argent reste un compte du framework.
Config.CashItem = false

-- Importe les définitions d'items du framework absentes de data/items.lua,
-- et l'ancien inventaire d'un personnage à son premier chargement.
Config.ImportFramework = true

-- Les scripts tiers qui utilisent l'inventaire du framework (xPlayer / Player.Functions) passent par pop_inventory.
Config.FrameworkHooks = true

Config.SaveInterval  = 300   -- secondes entre deux sauvegardes des inventaires modifiés
Config.GiveDistance  = 3.0   -- mètres pour donner un item

-- Commande de fouille d'un joueur mort ou menotté (false = désactivée).
Config.SearchCommand = 'search'

Config.Drops = {
    Model     = 'prop_paper_bag_small',
    Slots     = 20,
    MaxWeight = 100000,
    Distance  = 2.0,     -- portée pour ouvrir un dépôt (mètres)
    Lifetime  = 1800,    -- secondes avant disparition d'un dépôt
}

Config.Vehicles = {
    Glovebox = { slots = 5, weight = 10000 },
    -- Coffre selon le type de véhicule (GetVehicleType côté serveur). Type absent = pas de coffre.
    Trunk = {
        automobile = { slots = 25, weight = 60000 },
        quadbike   = { slots = 5,  weight = 15000 },
        boat       = { slots = 20, weight = 50000 },
        heli       = { slots = 15, weight = 40000 },
        plane      = { slots = 20, weight = 60000 },
        trailer    = { slots = 50, weight = 200000 },
        submarine  = { slots = 10, weight = 20000 },
    },
    -- Surcharge du coffre par modèle : ['burrito3'] = { slots = 40, weight = 150000 },
    Models = {},
}

-- label : clé de locale si elle existe, sinon texte affiché tel quel.
-- jobs : format Bridge.HasJob (nil = tout le monde). owner = true : un stockage par personnage.
Config.Stashes = {
    { id = 'police_locker', label = 'stash_police', coords = vec3(461.45, -996.30, 30.69),
      slots = 50, weight = 100000, jobs = { police = 0 }, owner = true },
}

-- account : 'cash' ou 'bank'. blip : nil = aucun blip. Un article accepte aussi metadata = {} et jobs = {}.
Config.Shops = {
    { id = 'general', label = 'shop_general', account = 'cash',
      coords = { vec3(25.74, -1347.30, 29.49), vec3(-3039.0, 585.9, 7.9) },
      blip = { sprite = 52, color = 2 },
      items = {
          { name = 'water_bottle', price = 5 },
          { name = 'bread',        price = 6 },
          { name = 'bandage',      price = 25 },
      } },
    { id = 'ammunation', label = 'shop_ammunation', account = 'bank',
      coords = { vec3(22.0, -1107.2, 29.8) },
      blip = { sprite = 110, color = 1 },
      items = {
          { name = 'weapon_pistol', price = 2500 },
          { name = 'ammo_pistol',   price = 2 },
          { name = 'weapon_knife',  price = 200 },
      } },
}
```
Rien d'autre dans la config.

### 9.1 Constantes (en tête de fichier, commentées, pas dans la config)
| Constante | Valeur | Fichier(s) |
|---|---|---|
| `HOTBAR` | 5 | client/main.lua, server/players.lua |
| `TOLERANCE` (marge serveur sur toute distance, latence) | 1.0 m | server/* |
| `POINT_DISTANCE` (stash / boutique ; serveur : + `TOLERANCE`) | 2.0 m | client/world.lua, server/stashes.lua, server/shops.lua |
| `TRUNK_CLIENT_DISTANCE` (arrière du véhicule, client) | 2.5 m | client/main.lua |
| `TRUNK_SERVER_DISTANCE` (centre du véhicule, serveur) | 6.0 m | server/vehicles.lua |
| `SEARCH_DISTANCE` (serveur : + `TOLERANCE`) | 2.5 m | client/main.lua, server/search.lua |
| `USE_COOLDOWN` | 500 ms par joueur | server/players.lua |
| `WEAPON_UPDATE_THROTTLE` | 500 ms | server/players.lua |
| `DROP_MERGE_DISTANCE` (réutiliser un drop proche) | 1.5 m | server/drops.lua |
| `DROP_MAX` (drops simultanés) | 300 | server/drops.lua |
| `DROP_PER_PLAYER` (drops actifs créés par un même personnage) | 10 | server/drops.lua |
| `FORCED_RANGE` (session forcée : distance max au point d'ouverture, + `TOLERANCE`) | 15.0 m | server/containers.lua |
| `COUNT_MAX` (quantité max d'une pile / d'un ajout) | 1e9 | server/inventory.lua |
| `SAVE_FALLBACK` (écriture sans réponse : clé libérée + log) | 30 s | server/database.lua |
| `DROP_STREAM_DISTANCE` | 25.0 m | client/world.lua |
| `CONTAINER_UNLOAD_DELAY` (coffre / stash par personnage sans spectateur) | 600 s | server/containers.lua |
| `METADATA_MAX_LENGTH` (JSON d'une metadata) | 4096 caractères | server/inventory.lua |
| `PLAYER_LOAD_TIMEOUT` (attente dans `init`) | 10 s | server/players.lua |
| `BUY_MAX` (quantité max par achat) | 1000 | server/shops.lua |
| `GIVEITEM_MAX` (commande admin) | 10000 | server/players.lua |

### 9.2 `data/items.lua` (LOT 1)
```lua
-- Champs : label (anglais, repli), weight (g), stack (true), close (true), description, image (fichier sans extension),
-- consume (0 : quantité retirée après une utilisation réussie par un cb RegisterUsableItem),
-- weapon (false), ammo (nom de l'item munitions), clip (taille du chargeur), degrade (durabilité perdue par tir).
ItemList = {
    ['money']            = { label = 'Cash', weight = 0 },
    ['water_bottle']     = { label = 'Water bottle', weight = 500 },
    ['bread']            = { label = 'Bread', weight = 200 },
    ['bandage']          = { label = 'Bandage', weight = 100 },
    ['lockpick']         = { label = 'Lockpick', weight = 150 },
    ['door_key']         = { label = 'Door key', weight = 50, stack = false },
    ['weed_pot']         = { label = 'Pot', weight = 800 },
    ['weed_seed']        = { label = 'Cannabis seed', weight = 10 },
    ['weed_fertilizer']  = { label = 'Fertilizer', weight = 500 },
    ['weed']             = { label = 'Weed', weight = 50 },
    ['ammo_pistol']      = { label = 'Pistol ammo', weight = 10 },
    ['ammo_smg']         = { label = 'SMG ammo', weight = 10 },
    ['ammo_rifle']       = { label = 'Rifle ammo', weight = 15 },
    ['ammo_shotgun']     = { label = 'Shotgun shells', weight = 30 },
    ['weapon_pistol']        = { label = 'Pistol', weight = 1000, weapon = true, ammo = 'ammo_pistol', clip = 12, degrade = 0.05 },
    ['weapon_combatpistol']  = { label = 'Combat pistol', weight = 1000, weapon = true, ammo = 'ammo_pistol', clip = 12, degrade = 0.05 },
    ['weapon_smg']           = { label = 'SMG', weight = 2500, weapon = true, ammo = 'ammo_smg', clip = 30, degrade = 0.03 },
    ['weapon_carbinerifle']  = { label = 'Carbine rifle', weight = 3500, weapon = true, ammo = 'ammo_rifle', clip = 30, degrade = 0.03 },
    ['weapon_pumpshotgun']   = { label = 'Pump shotgun', weight = 3500, weapon = true, ammo = 'ammo_shotgun', clip = 8, degrade = 0.1 },
    ['weapon_stungun']       = { label = 'Taser', weight = 500, weapon = true },
    ['weapon_knife']         = { label = 'Knife', weight = 300, weapon = true },
    ['weapon_bat']           = { label = 'Baseball bat', weight = 1000, weapon = true },
    ['weapon_flashlight']    = { label = 'Flashlight', weight = 300, weapon = true },
}
```
Les items attendus par `pop_weed` et `pop_doorlock` y sont déjà. Une arme sans `ammo` n'a ni munitions ni rechargement.

**Normalisation** (`server/items.lua`) : nom en minuscules ; `weight` entier ≥ 0 ; `stack = false` forcé pour les armes ;
`close` défaut `true` ; `consume`, `clip`, `degrade` défaut 0.
**`Items.Label(name)`** : texte de la clé de locale `item_<name>` si elle existe (langue choisie ou anglais), sinon `def.label`,
sinon `name`. Même règle pour `description` (clé `desc_<name>`). **`LabelOf(text)`** (libellés de config) : `L(text)` si la
clé existe, sinon `text`. Une clé « existe » si `L(key) ~= key`.

**Import des définitions** (`Config.ImportFramework`, au démarrage, seulement les noms absents de `ItemList`) :
- ESX : `SELECT name, label, weight FROM items` (poids en kg ×1000) ; repli ancien ESX `SELECT name, label FROM items` (poids 0).
- QBCore : `QBCore.Shared.Items` (poids en grammes, `unique` → `stack = false`, `description`, `image` sans `.png`,
  `type == 'weapon'` → `weapon = true`, sans munitions).
- Qbox / standalone : rien. Tout est protégé par `pcall` ; le nombre d'items importés est affiché en console si `Config.Debug`.

---

## 10. Locales (LOT 1)

10 fichiers : `en` (défaut + repli), `fr`, `es`, `de`, `it`, `pt`, `nl`, `pl`, `tr`, `ar` (`_rtl = true`).
Bloc « Kit commun » inchangé + clés ci-dessous sous `-- Textes propres au script :`. Mêmes `%s`, même ordre, dans toutes
les langues. Les logs console restent en anglais, hors locales.

| Clé | en | fr |
|---|---|---|
| `inv_player` | Inventory | Inventaire |
| `inv_ground` | Ground | Sol |
| `inv_glovebox` | Glovebox | Boîte à gants |
| `inv_trunk` | Trunk | Coffre |
| `inv_stash` | Storage | Stockage |
| `inv_shop` | Shop | Boutique |
| `inv_searched` | Searched person | Personne fouillée |
| `ui_amount` | Amount | Quantité |
| `ui_amount_hint` | 0 = all | 0 = tout |
| `ui_use` | Use | Utiliser |
| `ui_give` | Give | Donner |
| `ui_weight` | Weight | Poids |
| `ui_weight_value` | %s / %s kg | %s / %s kg |
| `ui_kg` | %s kg | %s kg |
| `ui_price` | $%s | %s $ |
| `meta_durability` | Durability | Durabilité |
| `meta_ammo` | Ammo | Munitions |
| `meta_serial` | Serial | N° de série |
| `meta_plate` | Plate | Plaque |
| `meta_quality` | Quality | Qualité |
| `meta_registered` | Registered to | Enregistrée à |
| `keymap_open` | Open inventory | Ouvrir l'inventaire |
| `keymap_slot` | Use hotbar slot %s | Utiliser l'emplacement %s |
| `target_drop` | Search the ground | Fouiller le sol |
| `target_stash` | Open storage | Ouvrir le stockage |
| `target_shop` | Browse the shop | Voir la boutique |
| `invalid_item` | Unknown item | Objet inconnu |
| `item_not_found` | Item not found | Objet introuvable |
| `item_not_usable` | This item can't be used | Cet objet ne s'utilise pas |
| `container_full` | Not enough space | Pas assez de place |
| `target_full` | They can't carry that | Cette personne ne peut pas le porter |
| `no_player_nearby` | Nobody nearby | Personne à proximité |
| `cannot_now` | You can't do that right now | Impossible pour le moment |
| `not_loaded` | Inventory is loading, try again | Inventaire en chargement, réessayez |
| `vehicle_locked` | The vehicle is locked | Le véhicule est verrouillé |
| `no_trunk` | This vehicle has no trunk | Ce véhicule n'a pas de coffre |
| `cannot_search` | This person can't be searched | Cette personne ne peut pas être fouillée |
| `being_searched` | Someone is searching you | Quelqu'un vous fouille |
| `weapon_broken` | This weapon is broken | Cette arme est cassée |
| `weapon_needed` | Equip the matching weapon first | Équipez d'abord l'arme correspondante |
| `no_ammo` | No ammo for this weapon | Pas de munitions pour cette arme |
| `ammo_full` | This weapon is fully loaded | Cette arme est déjà chargée |
| `gave_item` | You gave %sx %s | Vous avez donné %sx %s |
| `received_item` | You received %sx %s | Vous avez reçu %sx %s |
| `bought_item` | Bought %sx %s | Acheté : %sx %s |
| `admin_usage` | Usage: /giveitem [id] [item] [count] | Utilisation : /giveitem [id] [objet] [quantité] |
| `admin_given` | Gave %sx %s to %s | %sx %s donné à %s |
| `shop_general` | 24/7 | 24/7 |
| `shop_ammunation` | Ammu-Nation | Ammu-Nation |
| `stash_police` | Police locker | Casier police |
| `item_money` | Cash | Argent liquide |
| `item_water_bottle` | Water bottle | Bouteille d'eau |
| `item_bread` | Bread | Pain |
| `item_bandage` | Bandage | Bandage |
| `item_lockpick` | Lockpick | Crochet |
| `item_door_key` | Door key | Clé de porte |
| `item_weed_pot` | Pot | Pot |
| `item_weed_seed` | Cannabis seed | Graine de cannabis |
| `item_weed_fertilizer` | Fertilizer | Engrais |
| `item_weed` | Weed | Cannabis |
| `item_ammo_pistol` | Pistol ammo | Munitions de pistolet |
| `item_ammo_smg` | SMG ammo | Munitions de SMG |
| `item_ammo_rifle` | Rifle ammo | Munitions de fusil |
| `item_ammo_shotgun` | Shotgun shells | Cartouches |
| `item_weapon_pistol` | Pistol | Pistolet |
| `item_weapon_combatpistol` | Combat pistol | Pistolet de combat |
| `item_weapon_smg` | SMG | SMG |
| `item_weapon_carbinerifle` | Carbine rifle | Carabine |
| `item_weapon_pumpshotgun` | Pump shotgun | Fusil à pompe |
| `item_weapon_stungun` | Taser | Taser |
| `item_weapon_knife` | Knife | Couteau |
| `item_weapon_bat` | Baseball bat | Batte de baseball |
| `item_weapon_flashlight` | Flashlight | Lampe torche |

Clés communes réutilisées : `cancel`, `close`, `wrong_job`, `too_far`, `not_enough_money`, `inventory_full`, `cooldown`,
`busy`, `error`. `invalid_metadata` est une raison d'export (console), pas une clé de locale.

---

## 11. Contrat interne et comportement par lot

### 11.1 LOT 1 — Serveur cœur

#### 11.1.1 Objet inventaire (mémoire, jamais envoyé tel quel)
```lua
inv = {
    id = 12 | 'stash:police_locker' | 'trunk:ABC123' | 'glovebox:ABC123' | 'drop:7',
    type = 'player' | 'stash' | 'trunk' | 'glovebox' | 'drop',
    label = 'Inventory',            -- déjà traduit
    slots = 40, maxWeight = 30000, weight = 0,
    items = { [slot] = { name, count, slot, metadata } },
    owner = 'char1:abc' | nil,      -- joueur : identifiant ; stash par personnage : identifiant
    persist = true, dirty = false,
    viewers = { [src] = true },     -- joueurs qui l'ont ouvert à droite (géré par le LOT 2 via AddViewer / RemoveViewer)
    coords = vector3 | nil,         -- stash, drop
    netId = nil, plate = nil,       -- véhicules
    groups = nil,                   -- stash : jobs (format Bridge.HasJob)
    closing = false,                -- déchargement en cours : toute opération refusée
}
```

#### 11.1.2 Fonctions partagées fournies par le LOT 1 (utilisées par le LOT 2)
| Fonction | Retour | Rôle |
|---|---|---|
| `Items.Get(name)` | def \| nil | nom normalisé en minuscules |
| `Items.Label(name)` | string | §9.2 |
| `Items.Defs()` | `ItemDefs` | table prête pour le client (labels traduits), calculée une fois |
| `LabelOf(text)` | string | globale, §9.2 |
| `ReconcileCash(src)` | — | globale, §11.1.7 ; ne fait rien si `Config.CashItem == false` |
| `Inventory.Get(ref)` | inv \| nil | `ref` = src (number) ou id (string). Jamais de chargement |
| `Inventory.Create(id, data)` | inv | `data = { type, label, slots, maxWeight, owner?, coords?, groups?, netId?, plate?, persist?, items? }` ; `items` = liste au format SQL ; remplace un inventaire existant de même id |
| `Inventory.Load(id, data)` | inv \| nil | **bloquant** (dans un thread / callback) : renvoie l'inventaire en mémoire, sinon lit `pop_inventory_stashes` (si `data.persist`) puis `Create`. Deux appels simultanés pour le même id attendent la **même** promesse |
| `Inventory.Remove(id, save)` | bool | décharge (sauvegarde d'abord si `save` et `dirty`) ; refuse (`false`) si des viewers restent |
| `Inventory.Save(inv)` | — | écrit si `persist` et `dirty` (§11.1.4) |
| `Inventory.AddItem(inv, name, count, metadata?, slot?)` | `ok, reason` | piles compatibles d'abord (même nom + metadata égale), puis slots libres ; vérifie poids et place **avant** d'écrire |
| `Inventory.RemoveItem(inv, name, count, metadata?, slot?)` | `ok, reason` | tout ou rien |
| `Inventory.GetItemCount(inv, name, metadata?, strict?)` | number | |
| `Inventory.CanCarry(inv, name, count, metadata?)` | bool | |
| `Inventory.Move(src, fromInv, fromSlot, toInv, toSlot, count)` | `ok, reason` | §11.1.3 |
| `Inventory.SetMetadata(inv, slot, metadata)` | bool | |
| `Inventory.IsEmpty(inv)` | bool | |
| `Inventory.View(inv)` | `InvView` | |
| `Inventory.AddViewer(inv, src)` / `Inventory.RemoveViewer(inv, src)` | — | |

Chaque opération qui modifie un inventaire (`AddItem`, `RemoveItem`, `Move`, `SetMetadata`, `Clear`) se termine par
**une seule synchro par inventaire touché** : `client:update` au propriétaire (côté `player`) et à chaque viewer
(côté `secondary`), `dirty = true`, puis : si `inv.type ~= 'player'` → `Containers.OnChanged(inv)` ; si `inv.type == 'player'` →
contrôle de l'arme équipée (§11.1.6), synchro de l'argent (§11.1.7) et miroir framework (§11.1.5).

#### 11.1.3 Règles de `Inventory.Move`
1. `fromInv.items[fromSlot]` existe (sinon `item_not_found`) ; `count` nil → pile entière, sinon entier 1..`item.count`.
2. `toSlot` nil → première pile compatible, sinon premier slot libre ; aucun → `inventory_full` (destination joueur) / `container_full`.
3. Même inventaire, même slot → `true` sans rien faire.
4. Slot de destination vide → déplacement (séparation si `count < item.count`, metadata copiée).
5. Même nom, empilable, metadata égale → fusion.
6. Item différent → échange **seulement** si `count` = pile entière ; sinon `error`.
7. Entre deux inventaires : le poids de chacun après l'opération (échange compris) ≤ `maxWeight`, sinon
   `inventory_full` (destination joueur) / `container_full`.
8. Items non empilables : `count` toujours 1.
9. Aucune attente (`Wait`, `Await`, SQL) entre la première vérification et la dernière écriture.

#### 11.1.4 Persistance (`server/database.lua`)
- Démarrage : `CREATE TABLE IF NOT EXISTS` (échec → erreur rouge en console, nouvel essai toutes les 10 s,
  `Database.ready` reste faux : aucun chargement, aucune écriture), import des définitions (§9.2), démarrage à chaud
  (joueurs déjà connectés) : attente de 1,5 s pour laisser arriver les écritures de l'instance précédente, puis
  `Database.ready = true` (et chargement des joueurs restés sans inventaire si les tables ont dû être recréées).
- **`Database.LoadStash(id)`** : liste d'items ; `nil` si aucune ligne ; `false, err` si erreur SQL (ou base pas prête).
  `Inventory.Load` ne crée **rien** sur `false` (renvoie `nil` → ouverture `error`) ; stash partagé : nouvel essai après 10 s.
- **Joueur** (`Bridge.OnPlayerLoaded`) : thread → attendre la fin d'une sauvegarde en cours du même identifiant
  (`pendingSaves[clé]`, promesse) — un inventaire « fantôme » du même identifiant sous un autre `src` est d'abord
  déchargé et sauvegardé (un seul inventaire par personnage) → `SELECT` → si aucune ligne et `Config.ImportFramework` : migration (ci-dessous),
  puis `INSERT` immédiat → `Inventory.Create(src, { type = 'player', label = L('inv_player'), slots = Config.Slots, maxWeight = Config.MaxWeight, owner = identifier, persist = true })`
  → `ReconcileCash(src)` → enregistrement des méthodes QBCore (§11.1.5).
- **Migration** (une seule fois par personnage, `pcall`) : ESX Legacy `users.inventory` (JSON `{ nom = quantité }`)
  + `users.loadout` (armes → items arme, `ammo` bornée à `clip`, seulement si l'arme a des munitions) ; ancien ESX
  `user_inventory` (`item`, `count`) + `users.loadout` lu par une 2e requête ;
  QBCore / Qbox `players.inventory` (liste `{ name, amount|count, info|metadata, slot }`). Items inconnus ignorés (log),
  slots respectés, poids ignoré. Plus de piles que de slots (slots réduits) : `inv.slots` agrandi temporairement, rien n'est perdu.
- **Sauvegarde** : boucle `SetTimeout` toutes les `Config.SaveInterval` s → tous les inventaires `dirty` et `persist`.
  À la sauvegarde : instantané JSON pris **tout de suite** (synchrone), `dirty = false`, puis écriture asynchrone ;
  `pendingSaves[clé]` est résolue à la fin de l'écriture. Écriture échouée (ou sans réponse après `SAVE_FALLBACK`, log) :
  inventaire encore en mémoire → `dirty = true` (réécrit à la prochaine sauvegarde) ; déjà déchargé → un nouvel essai après 5 s.
- **Déchargement joueur** (`Bridge.OnPlayerUnloaded` et `Bridge.OnPlayerDropped`) : `closing = true`,
  `Containers.Close(src)` (ferme aussi les fouilles qui le visent), sauvegarde, `Inventory.Remove`, nettoyage des tables
  par `src` (`Equipped`, `lastCash`, `pendingAmmo`, cooldowns) ; unload seulement : `client:reset` ; déconnexion : `loadToken[src] = nil`. L'identifiant est lu dans `inv.owner`
  (le Bridge peut déjà renvoyer nil).
- **Arrêt** : `txAdmin:events:serverShuttingDown` et `onResourceStop` (cette ressource) → sauvegarde de tout ce qui est `dirty`.

#### 11.1.5 Framework (`server/framework.lua`, si `Config.FrameworkHooks`)
Tout est protégé par `pcall`, avec un avertissement console unique en cas d'échec. `-- NOTE:` à vérifier en jeu selon les versions.
- **ESX Legacy** : `ESX.RegisterPlayerFunctionOverrides('pop_inventory', overrides)` puis `ESX.SetPlayerFunctionOverride('pop_inventory')`
  (chaque entrée = `function(self) return function(...) … end end`). Méthodes : `getInventory(minimal)`,
  `getInventoryItem(name)` → `{ name, label, count, weight, usable }`, `addInventoryItem(name, count, metadata)`,
  `removeInventoryItem(name, count, metadata)`, `setInventoryItem(name, count)`, `canCarryItem(name, count)`,
  `canSwapItem(...)` → `false`, `hasItem(name)` → `item, count`, `getWeight()`, `getMaxWeight()`.
  Elles lisent / modifient l'inventaire chargé via `Inventory.*`. Fonctions absentes (ancien ESX) → avertissement (§1.3).
  README : redémarrer pop_inventory à chaud casse ces surcharges pour les joueurs connectés (reconnexion requise).
- **QBCore** : au chargement de chaque joueur, `QBCore.Functions.AddPlayerMethod(src, nom, fn)` pour `AddItem(item, amount, slot, info)`,
  `RemoveItem(item, amount, slot)`, `GetItemByName(item)`, `GetItemsByName(item)`, `GetItemBySlot(slot)`, `ClearInventory()`
  (format QB : `{ name, amount, info, label, slot, weight, type, unique, image, description }`).
  **Miroir** : après chaque changement de l'inventaire joueur (regroupé, au plus 1 fois / 250 ms),
  `Player.Functions.SetPlayerData('items', itemsQB)` pour que `PlayerData.items` reste juste (client et serveur).
- **Items utilisables du framework** (repli de `use`, §11.1.6) : ESX `ESX.GetUsableItems()[name]` → `ESX.UseItem(src, name, { metadata = md, slot = slot })` ;
  QBCore `QBCore.Functions.CanUseItem(name)` → `QBCore.Functions.UseItem(src, itemQB)`. Qbox (`-- NOTE:` repli à vérifier) :
  `exports.qbx_core:CanUseItem(name)` → callback appelé avec `(src, itemQB)`. Standalone : aucun.
  ESX : avertissement console si `ESX.GetConfig().CustomInventory` est faux.

#### 11.1.6 Actions joueur (`server/players.lua`)
- **`pop_inventory:init`** : attend l'inventaire du joueur (max `PLAYER_LOAD_TIMEOUT`), `ReconcileCash(src)`, renvoie `data` (§5).
- **`pop_inventory:move`** : `from`/`to` ∈ {`player`, `secondary`} ; `secondary` = `Containers.GetSecondary(src)` :
  `nil` → `error` ; `'newdrop'` → seulement si `to == 'secondary'` et `from == 'player'` : `Containers.CreateDrop(src)`
  (échec → sa raison) ; `'shop'` → `error` (achat = `buy`). Tout inventaire secondaire passe par
  `Containers.CanAccess(src, inv)` (échec → sa raison). Puis `Inventory.Move`.
- **`pop_inventory:give`** : cible ≠ soi, joueur chargé avec inventaire, les deux à `Config.GiveDistance + TOLERANCE`
  (positions serveur), aucun des deux mort (→ `cannot_now`) ; `Inventory.CanCarry(cible)` (→ `target_full`) → retrait du
  slot → ajout chez la cible (échec → restauration). Notifications `gave_item` / `received_item` (`count`, `Items.Label`).
- **`pop_inventory:use`** : `USE_COOLDOWN` (→ `cooldown`), pas `invBusy` ni `Bridge.IsDead` (→ `cannot_now`),
  item présent dans le slot (→ `item_not_found`). Ordre :
  1. **arme** : `durability <= 0` → `weapon_broken` ; même slot déjà équipé → `Equipped[src] = nil` + `client:holster` ;
     sinon `Equipped[src] = { slot, name, serial }` et `client:useWeapon` `{ slot, name, ammo, durability }` ;
  2. **munitions** (un def d'arme a `ammo == name`) → `Reload(src)` ;
  3. **`RegisterUsableItem`** : si `def.consume > 0` : `Inventory.RemoveItem(inv, name, def.consume, nil, slot)` **avant** le cb
     (échec → `item_not_found`) ; puis `pcall(cb, src, name, copie(metadata), slot)` ; cb qui renvoie `false` ou plante →
     quantité rendue au même slot (`false` → `true, nil, false` sans `usedItem` ; erreur → `error`) ;
  4. **framework** (§11.1.5) ; 5. sinon `item_not_usable`.
  Succès → `TriggerEvent('pop_inventory:usedItem', src, name, slot, metadata)`, retour `true, nil, def.close`.
- **Arme équipée** : après tout changement de l'inventaire joueur, si l'item au slot `Equipped[src].slot` n'a plus le même
  `name` + `serial` → `Equipped[src] = nil` + `client:holster`. À la mort, le client range l'arme seul ; le serveur remet
  `Equipped[src] = nil` quand il reçoit le prochain `use` d'une arme ou au déchargement.
- **`Reload(src)`** (callback `pop_inventory:reload` et utilisation de munitions) : arme équipée avec `def.ammo` (→ `weapon_needed`),
  `metadata.ammo < def.clip` (→ `ammo_full`), munitions présentes (→ `no_ammo`) ; `n = min(clip - ammo, nombre)` ;
  `RemoveItem(ammo, n)` puis `metadata.ammo += n` (via `Inventory.SetMetadata`) ; `client:setAmmo`.
- **`pop_inventory:server:updateWeapon`** : §4.1 ; durabilité ≤ 0 → `Equipped[src] = nil` + `client:holster`.
  Throttle : une valeur reçue pendant la fenêtre est gardée dans `pendingAmmo[src]` (la dernière gagne) et appliquée à la fin
  de la fenêtre (`SetTimeout`) ; vidée au rangement / changement d'arme et au déchargement.
- **`pop_inventory:give`** : cible `invBusy` → `cannot_now`.
- **Argent physique dans `move` / `give` / `buy`** : `ReconcileCash(src)` au début ; si des billets quittent l'inventaire joueur,
  `Bridge.GetMoney(src, 'cash') >=` quantité, sinon `not_enough_money`.
- **Usables** : `Usable[name] = { cb, resource }` ; `onResourceStop(res)` retire ceux de `res`.
- **Commande admin** `giveitem` : `RegisterCommand('giveitem', …, false)` ; console (`src == 0`) ou `Bridge.IsAdmin(src)` ;
  arguments validés (id en ligne et chargé, item connu, quantité entière 1..`GIVEITEM_MAX`, défaut 1) ; `admin_usage` / `admin_given`.

#### 11.1.7 Argent (`Config.CashItem`, `server/players.lua`)
- L'item `Config.CashItem` doit exister dans le registre (sinon avertissement et option ignorée).
- **Inventaire → framework** : après tout changement de l'inventaire joueur, si le total de l'item ≠ `lastCash[src]` et que
  `syncing[src]` est faux : `Bridge.AddMoney` / `Bridge.RemoveMoney(src, 'cash', |delta|, 'pop_inventory')`, puis `lastCash[src] = total`.
- **Framework → inventaire** (`ReconcileCash(src)`) : `syncing[src] = true`, ajuste l'item (sans contrôle de poids) pour égaler
  `Bridge.GetMoney(src, 'cash')`, `lastCash[src] = total`, `syncing[src] = false`. Appelée : au chargement, dans `init`, à chaque
  `pop_inventory:open` (LOT 2), et sur `esx:setAccountMoney`, `esx:addAccountMoney`, `esx:removeAccountMoney` (ESX) et
  `QBCore:Server:OnMoneyChange` (QBCore / Qbox) quand `syncing` est faux. `-- NOTE:` noms d'events à confirmer selon la version.
- Standalone : aucun compte, l'item est un item normal (et sert à payer les boutiques `cash`).

### 11.2 LOT 2 — Serveur conteneurs

#### 11.2.1 Fonctions partagées fournies par le LOT 2 (utilisées par le LOT 1)
| Fonction | Retour | Rôle |
|---|---|---|
| `Containers.Open(src, request)` | `true, payload` \| `false, reason` | logique du callback `pop_inventory:open` (bloquante : charge si besoin) |
| `Containers.ForceOpen(src, invType, data)` | bool | sans distance ni job ; charge si besoin dans un thread, puis envoie `client:open` ; renvoie `true` si la demande est valide |
| `Containers.Close(src)` | — | ferme la session de `src` **et** celles des joueurs qui fouillent `src` (`client:close`) |
| `Containers.GetSecondary(src)` | inv \| `'newdrop'` \| `'shop'` \| nil | |
| `Containers.CreateDrop(src)` | inv \| `nil, reason` | drop à la position serveur du joueur (réutilise un drop à `DROP_MERGE_DISTANCE`) ; met la session sur ce drop + `AddViewer` |
| `Containers.CanAccess(src, inv)` | `bool, reason` | revérifie les règles du type (§12) |
| `Containers.OnChanged(inv)` | — | drop vide → suppression ; coffre non possédé vide sans viewer → déchargé |
| `Containers.GetPoints()` | `{ drops, stashes, shops }` | listes publiques (stashes avec `coords` seulement, sans `jobs`) |
| `Containers.RegisterStash(id, label, slots, maxWeight, owner, groups, coords)` | bool | |
| `Containers.RegisterShop(id, data)` | bool | |

#### 11.2.2 Sessions (`server/containers.lua`)
`Sessions[src] = { kind = 'inv' | 'newdrop' | 'shop', inv = inv | nil, shopId = id | nil, forced = bool }`.
- **`pop_inventory:open`** : verrou `opening[src]` (→ `busy`), `Bridge.GetPlayer(src)` et inventaire joueur chargé
  (→ `not_loaded`), pas `Bridge.IsDead` ni `invBusy` (→ `cannot_now`), ferme la session précédente, valide selon le type
  (§11.2.3, §12), `Inventory.Load` si besoin, `Inventory.AddViewer`, `TriggerEvent('pop_inventory:openedInventory', src, inv.id)`,
  `ReconcileCash(src)`, puis renvoie `payload` (`player = Inventory.View(inventaire joueur)`).
- **`pop_inventory:close`** / `Containers.Close` : `RemoveViewer`, `closedInventory`, et si l'inventaire n'a plus de viewer :
  coffre ou stash par personnage → `Inventory.Save`, puis déchargement après `CONTAINER_UNLOAD_DELAY` s s'il n'a toujours
  aucun viewer. Stashes de config / `RegisterStash` sans owner : jamais déchargés.
- **Fin de session** : l'inventaire joueur, s'il est `dirty`, est sauvegardé tout de suite.
- **Session forcée** (`forceOpenInventory`) : `s.origin` = position du joueur à l'ouverture ; chaque action (`CanAccess`, `buy`)
  est refusée (`too_far`, session fermée) au-delà de `FORCED_RANGE` + `TOLERANCE`, et si le joueur est mort (`cannot_now`).
- **Fermeture forcée** (`client:close` + session supprimée) : drop expiré, joueur fouillé déconnecté ou plus fouillable
  (constaté au prochain `CanAccess`), véhicule supprimé.
- **Drop vidé** : ses viewers passent d'abord en session `newdrop` (`RemoveViewer`, rien à envoyer : le panneau « Sol » vide
  reste juste), puis `Inventory.Remove`, puis `client:removeDrop`.

#### 11.2.3 Types
- **Drops** (`drops.lua`) : `Drops[id] = { id, coords, expires }`, inventaire `drop:<id>` (label `L('inv_ground')`,
  `Config.Drops.Slots`, `Config.Drops.MaxWeight`, `persist = false`). Coordonnées = position serveur du ped, `z - 0.98`.
  Création → `client:addDrop` (-1) ; suppression → `client:removeDrop` (-1). Une minuterie toutes les 60 s, **active seulement
  s'il existe des drops**, supprime les expirés (viewers : `client:close`). `DROP_MAX` atteint, ou `DROP_PER_PLAYER` drops
  actifs créés par le même personnage → `cannot_now`.
- **Véhicules** (`vehicles.lua`) : `NetworkGetEntityFromNetworkId(netId)`, `DoesEntityExist`, `GetEntityType == 2`, plaque serveur.
  Coffre : `Config.Vehicles.Models[nom]` (table `joaat(nom) → taille` construite au démarrage, comparée à `GetEntityModel`), sinon
  `Config.Vehicles.Trunk[GetVehicleType(vehicle)]` (absent → `no_trunk`). Boîte à gants : `Config.Vehicles.Glovebox`, sauf types
  `bike` et `quadbike` (→ `cannot_now`). Label `L('inv_trunk')` / `L('inv_glovebox')`. `inv.netId` et `inv.plate` renseignés.
  `persist` = plaque possédée : ESX `SELECT 1 FROM owned_vehicles WHERE TRIM(plate) = ?`, QBCore / Qbox
  `SELECT 1 FROM player_vehicles WHERE TRIM(plate) = ?` (cache par plaque : 600 s si possédée, 30 s sinon ; erreur SQL → `true`,
  non mis en cache) ; standalone → `true`.
- **Stashes** (`stashes.lua`) : au démarrage, chaque entrée de `Config.Stashes` → `Containers.RegisterStash`.
  `Stashes[id] = { id, label, slots, weight, owner, groups, coords }`. Sans owner : `Inventory.Load('stash:'..id, …)` en tâche
  de fond à l'enregistrement. Avec owner : chargé à l'ouverture, id `stash:<id>:<identifier>`. Label `LabelOf(label)`
  (défaut `L('inv_stash')`). `RegisterStash` est **asynchrone** pour un stash partagé : tant qu'il n'est pas chargé, les
  exports sur ce stash renvoient `not_loaded` / `0` (une ouverture joueur le charge à la demande).
- **Boutiques** (`shops.lua`) : `Shops[id] = { id, label, account, coords = { vector3, ... }, blip, jobs, items }`. `ShopView`
  construit à l'ouverture (articles avec `jobs` non autorisés retirés, la session garde la correspondance `slot → article`).
  Libellé `LabelOf(label)` (défaut `L('inv_shop')`). Callback `pop_inventory:buy` (§12). Articles dont l'item est inconnu :
  ignorés au démarrage (avertissement console).
- **Fouille** (`search.lua`) : fournit `Search.CanBeSearched(target)` : mort (`Bridge.IsDead`) ou menotté (QB / Qbox
  `PlayerData.metadata.ishandcuffed`, ou statebag `Player(target).state` `isCuffed` / `cuffed` / `handcuffed` à `true`).
  Utilisée par `Containers.Open` (type `player`) et `CanAccess`. Envoie `client:searched` au fouillé à l'ouverture.
  La commande `Config.SearchCommand` est enregistrée côté **client** (LOT 3).

### 11.3 LOT 3 — Client
Table `PopInv = { items = ItemDefs, inventory = { slots, maxWeight, weight, items = { [slot] = item } }, open = false,
secondary = nil, watch = nil, weapon = nil, drops = {}, nuiItems = false }`.
- **Chargement** : `Bridge.OnPlayerLoaded` → `Callback.Await('pop_inventory:init')` ; `nil` → nouvel essai toutes les 2 s (5 fois max).
  Remplit le cache, crée drops / zones / blips (`world.lua`), rééquipe `weapon` si présent.
- **Touches** : `RegisterKeyMapping('pop_inventory', L('keymap_open'), 'keyboard', Config.OpenKey)` ;
  `pop_inventory_slot1` … `pop_inventory_slot5` (`L('keymap_slot', n)`, touches `1` … `5`) → `pop_inventory:use`, puis message
  `pop_inventory:hotbar` (`active = n`). Ignorées si mort, `invBusy`, `Bridge.IsBusy()`, menu pause ou interface ouverte.
  Si `Config.SearchCommand` : `RegisterCommand(Config.SearchCommand, searchPlayer)` (joueur le plus proche à `SEARCH_DISTANCE`,
  sinon `no_player_nearby`).
- **Ouverture (touche)** : déjà ouvert → fermer. Sinon contexte, dans cet ordre :
  1. dans un véhicule → `{ type = 'glovebox', netId = VehToNet(veh) }` ;
  2. drop le plus proche à `Config.Drops.Distance` → `{ type = 'drop', id }` ;
  3. à pied, véhicule le plus proche (≤ 6 m) dont l'arrière (`GetOffsetFromEntityInWorldCoords` à `min.y` des dimensions
     du modèle) est à `TRUNK_CLIENT_DISTANCE` → `{ type = 'trunk', netId }` (le serveur vérifie le verrouillage) ;
  4. sinon `nil`.
  `Callback.Await('pop_inventory:open', request)` → succès : `EnsureNuiItems()`, `pop_inventory:open` à la NUI,
  `SetNuiFocus(true, true)` ; coffre : `SetVehicleDoorOpen(veh, 5, false, false)` (refermé à la fermeture ; `-- NOTE:` n'a
  d'effet que si le client contrôle l'entité). Échec : notification.
- **Pendant l'ouverture** : une boucle **à 500 ms**, seulement tant que c'est ouvert, ferme si mort, `invBusy`, ou si `watch`
  est dépassé (coords, entité `NetToVeh(netId)`, ou ped de `GetPlayerFromServerId(target)`).
- **Fermeture** (`Bridge.OnUiClose`, `client:close`, `client:reset`, `closeInventory`) : `SetNuiFocus(false, false)`,
  `pop_inventory:close` à la NUI, porte du coffre refermée, `Callback.Trigger('pop_inventory:close')` (sauf sur
  `client:close` / `client:reset`).
- **NUI callbacks** : §6.2 ; chaque échec → `Bridge.Notify(L(reason), 'error')` et réponse `{ ok = false, error = reason }`.
- **`client:update`** : applique au cache (`side == 'player'`), relaie à la NUI, puis pour chaque nom dont le total change :
  `TriggerEvent('pop_inventory:itemCount', name, total)` et, si l'interface est fermée, `pop_inventory:itemNotify`.
- **Armes** (`weapons.lua`) : `useWeapon` → retire l'arme précédente, `GiveWeaponToPed(ped, joaat(name:upper()), 0, false, true)`,
  `SetPedAmmo`, `SetCurrentPedWeapon`, event `pop_inventory:currentWeapon`. Une boucle `Wait(0)` **seulement tant qu'une arme
  est en main** : désactive la roue d'armes (contrôles 37, 157, 158, 160, 164, 165) ; touche R (45) avec 0 munition →
  `pop_inventory:reload` ; toutes les 250 ms lit `GetAmmoInPedWeapon` et envoie `server:updateWeapon` si la valeur a baissé
  (au plus 1 fois / 500 ms, et une dernière fois à l'arrêt du tir). Mort, `holster`, arme changée par le jeu →
  `RemoveWeaponFromPed`, fin de boucle, `pop_inventory:currentWeapon` `nil`.
- **Monde** (`world.lua`) : drops — une seule boucle (2000 ms sans drop proche, 1000 ms sinon, 500 ms à moins de 10 m) crée
  des props **locaux** (`CreateObject(hash, x, y, z, false, false, false)`, `PlaceObjectOnGroundProperly`, figés) à moins de
  `DROP_STREAM_DISTANCE`, les supprime au-delà de +5 m, et ajoute
  `Bridge.Target.AddLocalEntity(prop, { { label = L('target_drop'), icon = 'fa-solid fa-box-open', distance = Config.Drops.Distance, onSelect = ouvrir le drop } })`.
  Stashes / boutiques : `Bridge.Target.AddBoxZone('pop_inventory_stash_' .. id` ou `'pop_inventory_shop_' .. id .. '_' .. i,
  coords, vec3(1.5, 1.5, 2.0), 0.0, options)`, `distance = POINT_DISTANCE`, libellés `L('target_stash')` / `L('target_shop')`,
  icônes `fa-solid fa-box` / `fa-solid fa-cart-shopping`. Blips de boutique (`blip.sprite`, `blip.color`, échelle 0.7, nom = label,
  courte portée).
- **Exports client** §7.2. **onResourceStop** : props, blips, arme, focus, porte de coffre.

### 11.4 LOT 4 — NUI
Voir §6.3. `index.html` : `kit/pop.css`, puis `style.css` ; `kit/pop.js`, puis `script.js`. Blocs masqués par défaut :
`#inventory` (pop-fade), `#tooltip`, `#hotbar` (pop-fade), `#notify`. Libellés fixes en `data-locale`.
`script.js` garde `defs` (de `pop_inventory:items`), `player` et `secondary` (vues), et applique `pop_inventory:update` slot par slot.
`images/default.svg` : carré arrondi neutre avec une petite boîte au trait, une couleur, sans texte.

---

## 12. Sécurité (vérifiée côté serveur, LOTS 1 et 2)

Règle générale : le client n'envoie que des **slots, quantités, un id de point, un netId, un server id**. Jamais d'item,
de metadata, de prix, de poids, de coordonnées ni d'id d'inventaire. Tout est relu dans la mémoire serveur et la config.

**Commun à toutes les actions**
1. `source` est un joueur chargé (`Bridge.GetPlayer`) dont l'inventaire est en mémoire et pas `closing` (sinon `not_loaded`).
2. Types : `math.type(slot) == 'integer'`, `1 <= slot <= inv.slots` ; `count` nil ou entier `>= 1` (borné à la pile) ;
   `from` / `to` exactement `'player'` ou `'secondary'` ; `target`, `netId`, `index` entiers ; ids de point = chaînes connues.
   Sinon `error`.
3. Anti-spam : `Config.CallbackRateLimit` (15/s par callback) + `USE_COOLDOWN` + throttle de `updateWeapon`.
4. **Anti-duplication** : aucune attente entre vérification et écriture (§11.1.3) ; chargements dédupliqués (promesse partagée) ;
   déchargement `closing` + instantané de sauvegarde ; le rechargement d'un joueur attend sa sauvegarde en cours ; verrou
   `opening[src]` ; un drop / coffre supprimé n'est plus accessible (session vérifiée à chaque action).
5. Les inventaires secondaires ne sont accessibles **que** via la session du joueur (`Containers.GetSecondary`) et après
   `Containers.CanAccess(src, inv)` à **chaque** action.

**`Containers.CanAccess` / ouverture par type** (positions serveur, + `TOLERANCE`)
- `drop` : existe, `Bridge.IsNear(src, drop.coords, Config.Drops.Distance + TOLERANCE)`.
- `glovebox` : véhicule existe, `GetVehiclePedIsIn(GetPlayerPed(src), false) == vehicle`, plaque inchangée.
- `trunk` : véhicule existe, joueur à pied, distance au véhicule ≤ `TRUNK_SERVER_DISTANCE`, `GetVehicleDoorLockStatus(vehicle) <= 1`
  (sinon `vehicle_locked` ; `-- NOTE:` dépend de la synchro du verrouillage par le script de clés), type avec coffre, plaque inchangée.
- `stash` : existe ; `groups` → `Bridge.HasJob` (→ `wrong_job`) ; `coords` → `IsNear(coords, POINT_DISTANCE + TOLERANCE)` (→ `too_far`) ;
  stash **sans** `coords` : jamais ouvrable par un client (seulement `forceOpenInventory`) ; owner → id construit avec
  l'identifiant **serveur** du joueur.
- `shop` : existe ; `jobs` (→ `wrong_job`) ; près d'une de ses coordonnées (→ `too_far`).
- `player` (fouille) : `Config.SearchCommand ~= false`, cible ≠ soi, chargée, à `SEARCH_DISTANCE + TOLERANCE`,
  `Search.CanBeSearched(target)`, sinon `cannot_search` ; le fouilleur n'est ni mort ni menotté.
- Sessions ouvertes par `forceOpenInventory` (`forced = true`) : dispensées des contrôles de distance et de job.
- Échec de distance → `too_far`.

**`pop_inventory:give`** : §11.1.6 ; quantité ≤ pile ; poids de la cible ; les deux vivants ; jamais vers soi.

**`pop_inventory:use`** : uniquement l'inventaire du joueur ; le serveur suit `Equipped[src]`, le client ne choisit ni l'arme
ni ses munitions ; munitions : seulement en baisse depuis le client, rechargement calculé par le serveur.

**`pop_inventory:buy`** : session `shop` active et `CanAccess` ; `index` = article de la session ; `count` entier 1..`BUY_MAX`
(1 pour un item non empilable) ; prix = `price * count` lu dans la config (entier ≥ 0) ; `Inventory.CanCarry` (→ `inventory_full`)
**avant** de payer ; paiement : si `Config.CashItem` et `account == 'cash'` → `Inventory.RemoveItem(Config.CashItem, prix)`,
sinon `Bridge.RemoveMoney(src, account, prix, 'pop_inventory')` (→ `not_enough_money`) ; puis `Inventory.AddItem(…, metadata copiée, toSlot)`
(armes : `registered = Bridge.GetName(src)`) ; échec de l'ajout → remboursement intégral. Prix 0 : aucun paiement.
Notification `bought_item`.

**Exports** : appelés par du code serveur de confiance, mais entrées validées (nom connu, quantité entière > 0,
metadata = table dont le JSON fait moins de `METADATA_MAX_LENGTH` caractères, sinon `false, 'invalid_metadata'`).
`forceOpenInventory`, `RegisterStash`, `RegisterShop` : aucune exposition réseau.

**Données envoyées** : jamais d'identifiant de joueur, de nom (sauf `metadata.registered` déjà présent), ni de `jobs` de stash.

**Commande admin** : `Bridge.IsAdmin` à chaque appel ; console autorisée ; journal console
`[pop_inventory] <admin> gave <count>x <item> to <id>`.

---

## 13. Critères d'acceptation (audit)

- Démarre sans erreur en ESX Legacy, ancien ESX, QBCore, standalone (oxmysql seul requis) ; Qbox avec `provide` décommenté (à tester).
- `luacheck resources templates` : 0 erreur ; `node --check web/script.js` : OK. `bridge/`, `shared/`, `web/kit/` identiques au template.
- Les exports du contrat Bridge (§1.2) fonctionnent depuis `pop_weed` et `pop_doorlock` (clé `door_key` avec `pop_door`,
  récolte avec `quality`, items utilisables `weed_pot` / `weed_seed`).
- Resmon < 0.02 ms au repos (interface fermée, sans arme) ; aucun `Wait(0)` hors arme en main et `Bridge.Progress` ;
  serveur : aucune boucle rapide (sauvegarde à `Config.SaveInterval`, minuterie des drops seulement s'il y en a).
- Aucun texte en dur (Lua et NUI) ; 10 locales complètes ; arabe en RTL (panneaux inversés).
- Un client modifié ne peut pas : dupliquer un item (double clic, latence, déconnexion pendant un échange, ouverture simultanée
  d'un même coffre), ouvrir un coffre verrouillé ou distant, un stash sans le job ou sans `coords`, fouiller un joueur debout,
  acheter à un prix choisi, recharger sans munitions, augmenter ses munitions, utiliser un item absent.
- Après déconnexion / reconnexion rapide et après redémarrage du serveur : inventaire joueur, stashes et coffres possédés conservés.
