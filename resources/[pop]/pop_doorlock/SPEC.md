# SPEC — pop_doorlock

Contrat commun des devs **Serveur**, **Client** et **NUI**. Les noms (events, callbacks, messages NUI, clés de
config et de locales) sont **exacts** : ne pas les renommer. En cas d'ambiguïté, choisir l'option la plus sûre
et la noter en commentaire `-- NOTE:`.

Fondation : `templates/pop_base` (lire `templates/pop_base/README.md`). API à utiliser : `Bridge.*`, `Callback.*`,
`L()`, `Pop.*`. Aucune commande git.

---

## 1. Description et fonctionnalités

Verrouillage de portes basé sur le **système natif de portes GTA** (`AddDoorToSystem` / `DoorSystemSetDoorState`),
avec un éditeur admin en jeu. Aucun thread par porte : **une seule boucle adaptative** côté client.

Vocabulaire :
- **Battant** (leaf) : une entité porte du jeu (modèle + position).
- **Porte** (door) : ce qui se verrouille d'un coup. 1 battant = porte simple, 2 battants = porte double.
  L'état (verrouillée ou non) est **par porte**.
- **Groupe** (group) : ensemble de portes qui partagent les mêmes règles (nom, accès, clé, sécurité, alerte,
  distance, état au démarrage). Un groupe peut contenir 0 à 50 portes.

Fonctionnalités :
1. **Verrouiller / déverrouiller** une porte : prompt « [E] Verrouiller » ou « [E] Déverrouiller », avec une petite icône
   d'état (cadenas fermé ou ouvert). Avec ox_target / qb-target : options de target, plus la même icône d'état.
2. **Accès** (vérifié par le serveur), au moins un des deux suffit :
   - **job / grade** : `{ police = 0, sheriff = 2 }` (grade minimum) via `Bridge.HasJob` ;
   - **clé** : item `Config.KeyItem` dont la metadata `pop_door` est égale à la clé du groupe. Réinitialiser la clé
     d'un groupe rend toutes les anciennes clés inutilisables.
   Un groupe sans job ni clé ne s'ouvre que par crochetage ou par export.
3. **Crochetage** (esprit GTA 6) : sur une porte verrouillée, si le joueur n'a pas l'accès, le prompt devient « [E] Crocheter ».
   Il faut l'item `Config.Lockpick.Item`. Le mini-jeu dure quelques secondes : un curseur fait des allers-retours et il faut appuyer
   quand il passe dans une zone, plusieurs fois de suite. Le serveur tire en plus une chance d'échec, et l'outil peut casser en cas d'échec.
   **Niveau de sécurité** (réglé sur le groupe, appliqué à chacune de ses portes) :
   - `0` = crochetable (facile)
   - `1` = difficile (plus de coups, zone plus petite, plus d'échecs et de bris)
   - `2` = impossible (pas d'option de crochetage)
   **Alerte** optionnelle par groupe : à chaque tentative, les joueurs des jobs `Config.Lockpick.AlertJobs` reçoivent une
   notification et un blip temporaire. Un event serveur local est aussi émis pour les scripts de dispatch.
4. **Éditeur admin** (`/doorlock`, réservé à `Bridge.IsAdmin`) : petit panneau sur le côté droit.
   - liste des groupes, création et suppression d'un groupe ;
   - réglages d'un groupe : nom, verrouillé au démarrage, distance, sécurité, alerte, jobs, clé (oui / non) ;
   - « Recevoir une clé » (donne la clé à l'admin), « Réinitialiser la clé » ;
   - ajout d'une porte en visant : on vise un battant, [E] le sélectionne (2 au maximum), [ENTRÉE] valide, [X] annule.
     Le battant visé et les battants sélectionnés sont surlignés (contour à la couleur d'accent) ;
   - retrait d'une porte du groupe.
5. **État synchronisé** : le serveur fait autorité. Les joueurs qui se connectent reçoivent l'état courant. Les modifications de
   l'éditeur s'appliquent tout de suite chez tout le monde, sans redémarrage.
6. **Persistance oxmysql** : groupes et portes en base. L'état courant n'est **pas** sauvegardé : au démarrage du serveur,
   chaque porte reprend l'état « verrouillé au démarrage » de son groupe.

Hors périmètre (volontairement) : portes en dur dans config.lua, codes / keypads, portails coulissants, verrouillage
automatique temporisé, portes de garage.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_doorlock/
  SPEC.md                    Architecte (ce fichier)
  fxmanifest.lua             SERVEUR   (copie du template, modifiée : voir §2.2)
  config.lua                 SERVEUR   (clés communes du template + clés du script, §8)
  README.md                  SERVEUR   (installation, items, ACE, exports)
  bridge/client.lua          CLIENT    copie telle quelle de templates/pop_base
  bridge/server.lua          SERVEUR   copie telle quelle de templates/pop_base
  shared/callback.lua        SERVEUR   copie telle quelle
  shared/locale.lua          SERVEUR   copie telle quelle
  locales/en.lua             SERVEUR   copie du template + clés du script (§9)
  locales/fr.lua es.lua de.lua it.lua pt.lua nl.lua pl.lua tr.lua ar.lua   SERVEUR (idem, traduits)
  client/main.lua            CLIENT    cache des portes, système natif, boucle de proximité, prompt, target, verrouillage, alerte, export
  client/lockpick.lua        CLIENT    crochetage (callbacks, anim, focus NUI)
  client/editor.lua          CLIENT    commande /doorlock, panneau, mode visée (raycast + contour)
  server/main.lua            SERVEUR   chargement SQL, cache, accès, setState, sync, exports
  server/keys.lua            SERVEUR   test et remise de clé avec metadata selon l'inventaire
  server/lockpick.lua        SERVEUR   sessions de crochetage, tirages, alerte
  server/editor.lua          SERVEUR   callbacks admin
  sql/install.sql            SERVEUR
  web/index.html             NUI       (remplace celui du template)
  web/style.css              NUI
  web/script.js              NUI
  web/kit/pop.css            NUI       copie telle quelle
  web/kit/pop.js             NUI       copie telle quelle
```

`client/main.lua` du template est remplacé, et il n'y a pas d'autre fichier client. Même chose pour `server/main.lua`.

### 2.1 Copie depuis le template (depuis la racine du dépôt, chacun copie sa part)

| Dev | Copie |
|---|---|
| Serveur | `templates/pop_base/bridge/server.lua` → `bridge/server.lua` ; `templates/pop_base/shared/` → `shared/` ; `templates/pop_base/locales/` → `locales/` ; `templates/pop_base/fxmanifest.lua` et `config.lua` (à modifier ensuite) |
| Client | `templates/pop_base/bridge/client.lua` → `bridge/client.lua` |
| NUI | `templates/pop_base/web/kit/` → `web/kit/` |

Interdit de modifier `bridge/`, `shared/` ou `web/kit/` dans le script. Un manque se signale en `-- NOTE:`, puis se corrige dans le template.

### 2.2 fxmanifest.lua (Serveur)

- `name 'pop_doorlock'`, `description 'Door lock system with in-game editor'`, `version '1.0.0'`.
- `dependency 'oxmysql'`, `'@oxmysql/lib/MySQL.lua'` décommenté en tête de `server_scripts`.
- Ordre **explicite** (les fichiers partagent une table locale au côté, voir §11) :
  ```lua
  client_scripts { 'bridge/client.lua', 'client/main.lua', 'client/lockpick.lua', 'client/editor.lua' }
  server_scripts { '@oxmysql/lib/MySQL.lua', 'bridge/server.lua', 'server/main.lua', 'server/keys.lua', 'server/lockpick.lua', 'server/editor.lua' }
  ```
- `shared_scripts`, `ui_page`, `files` et `escrow_ignore` sont ceux du template, inchangés.

---

## 3. Events réseau

Toutes les demandes du client au serveur passent par des **callbacks** (§4), pour avoir une réponse et le rate-limit
intégré. Il n'y a **aucun** event réseau client → serveur.

### Serveur → client

| Event | Cible | Paramètres | Rôle |
|---|---|---|---|
| `pop_doorlock:client:setState` | `-1` | `doorId` (int), `locked` (bool) | Nouvel état d'une porte → `DoorSystemSetDoorState` sur ses battants |
| `pop_doorlock:client:syncGroup` | `-1` | `group` (format public §4.1) | Ajout ou modification d'un groupe : le client retire toutes les portes connues de ce groupe, puis ajoute celles reçues |
| `pop_doorlock:client:removeGroup` | `-1` | `groupId` (int) | Groupe supprimé : retirer ses portes (système natif, zones target, cache) |
| `pop_doorlock:client:alert` | joueurs des jobs d'alerte | `coords` (`{x,y,z}`) | Notification `L('alert_lockpick')` (type warning) et blip temporaire |

Notifications serveur → joueur : `Bridge.Notify(src, L(key), type)` (event du bridge, ne pas recréer).

### Event serveur local (non réseau, pour les autres ressources)

| Event | Paramètres | Quand |
|---|---|---|
| `pop_doorlock:lockpickAlert` | `src`, `coords` (vector3), `groupId` | Tentative de crochetage sur un groupe avec `alert = true` (pour brancher un dispatch). `TriggerEvent`, côté serveur seulement |

---

## 4. Callbacks (`shared/callback.lua`)

Tous déclarés côté serveur par `Callback.Register(name, fn(source, ...))` et appelés côté client par `Callback.Await` / `Callback.Trigger`.
Les raisons d'échec sont des **clés de locale** (le client fait `L(reason)` ; la NUI fait `Pop.t(reason)`).
Les callbacks qui lisent le cache attendent la fin du chargement SQL (`while not ready do Wait(100) end`, au plus 10 s).

### 4.1 Formats

**Groupe public** (envoyé à tous, sans clé ni jobs) :
```json
{
  "id": 3, "distance": 2.0, "security": 1,
  "doors": [
    { "id": 12, "locked": true, "center": { "x": 434.7, "y": -980.6, "z": 30.8 },
      "leaves": [ { "model": -1215222675, "x": 434.7, "y": -981.9, "z": 30.8 },
                  { "model": 320433149,  "x": 434.7, "y": -979.3, "z": 30.8 } ] }
  ]
}
```
`center` : centre visuel de la porte. Il est calculé par le client à la création et sert pour la distance, le prompt, les zones target et `Bridge.IsNear`.

**Groupe admin** (éditeur seulement) :
```json
{
  "id": 3, "label": "Mission Row - Hall", "locked": true, "distance": 2.0,
  "security": 1, "alert": false, "jobs": { "police": 0, "sheriff": 2 }, "hasKey": true,
  "doors": [ { "id": 12, "double": true, "locked": true } ]
}
```
`jobs` vaut `{}` s'il n'y a aucun job. La valeur de la clé (`key_id`) n'est **jamais** envoyée au client.

### 4.2 Joueurs

| Nom | Paramètres | Retour | Vérifications serveur |
|---|---|---|---|
| `pop_doorlock:getDoors` | — | `groups` : liste de groupes publics | aucune (données publiques) |
| `pop_doorlock:getAccess` | `groupId` | `bool` : le joueur peut verrouiller ou déverrouiller ce groupe | groupe existant ; `HasAccess` |
| `pop_doorlock:setState` | `doorId`, `locked` (bool) | `ok` (bool), `reason` (clé, si `ok = false`) | voir §10 ; si l'état est déjà le bon : `true` sans diffusion |
| `pop_doorlock:lockpickStart` | `doorId` | `ok`, puis `params` si ok (`{ hits, zone, speed, time }`) ou `reason` sinon | voir §10 ; crée la session |
| `pop_doorlock:lockpickEnd` | `doorId`, `success` (bool), `cancelled` (bool) | `result` : `'unlocked'` \| `'failed'` \| `'broken'` \| `'cancelled'` \| `nil` (session invalide) | voir §10 |

Raisons possibles de `setState` : `too_far`, `door_no_access`, `cooldown`, `error`.
Raisons possibles de `lockpickStart` : `too_far`, `door_not_locked`, `lockpick_impossible`, `has_access`, `missing_item`, `cooldown`, `busy`, `error`.
`has_access` n'est pas une clé de locale : le joueur a l'accès, le client ouvre normalement (`setState`) au lieu de crocheter.
Toutes les raisons passent par `Doorlock.NotifyReason(reason, ...)` (client/main.lua) : pour `missing_item`, `L('missing_item', L('item_lockpick'))` ;
pour `cooldown`, `L('cooldown', Config.Lockpick.Cooldown)` (crochetage) ou `L('cooldown', 1)` (anti-spam de `setState`).

### 4.3 Admin (chacun commence par `if not Bridge.IsAdmin(source) then return nil / false, 'no_permission' end`)

| Nom | Paramètres | Retour |
|---|---|---|
| `pop_doorlock:admin:getGroups` | — | `nil` si pas admin ; sinon `{ groups = { groupe admin, ... }, keys = bool }` (`keys` = l'inventaire gère la metadata, §5 de server/keys) |
| `pop_doorlock:admin:saveGroup` | `data` = `{ id = int\|nil, label, locked, distance, security, alert, jobs, key }` | `ok`, puis `group` (admin) ou `reason`. `id = nil` → création. `key = true` sans clé existante → génère `key_id` ; `key = false` → `key_id = NULL` |
| `pop_doorlock:admin:deleteGroup` | `groupId` | `ok`, `reason` |
| `pop_doorlock:admin:addDoor` | `groupId`, `door` = `{ center = {x,y,z}, leaves = { {model,x,y,z}, ... } }` | `ok`, puis `group` (admin) ou `reason` |
| `pop_doorlock:admin:removeDoor` | `doorId` | `ok`, puis `group` (admin) ou `reason` |
| `pop_doorlock:admin:giveKey` | `groupId` | `ok`, `reason` (donne 1 `Config.KeyItem` avec metadata à l'admin) |
| `pop_doorlock:admin:resetKey` | `groupId` | `ok`, puis `group` ou `reason` (nouveau `key_id`, les anciennes clés ne marchent plus) |

Raisons admin : `no_permission`, `editor_invalid`, `editor_not_found`, `editor_door_exists`, `editor_leaves_far`,
`editor_too_many_doors`, `editor_key_unsupported`, `editor_no_key`, `inventory_full`, `too_far`, `error`.

Après chaque modification réussie, le serveur diffuse `pop_doorlock:client:syncGroup` (ou `removeGroup`) à `-1`.

---

## 5. Messages NUI

Une seule page : `web/index.html`. Le HUD du kit (`pop:prompt`, `pop:progress`, `pop:notify`) reste disponible, mais **pop_doorlock
ne s'en sert pas pour les portes** : il a son propre prompt, avec l'icône d'état.
Tout le texte affiché vient des locales (`data-locale`, `Pop.t`). Les noms de groupes sont insérés avec `textContent` (jamais `innerHTML`).

### 5.1 Lua → JS (`SendNUIMessage`)

| `action` | Données | Rôle |
|---|---|---|
| `pop_doorlock:prompt` | `{ show: true, key: "E" \| null, label: "Unlock", locked: true }` ou `{ show: false }` | Prompt de porte (à droite, style `pop-panel pop-prompt`) : `[E]` si `key`, puis le libellé déjà traduit, puis l'icône cadenas (fermé si `locked`, en couleur d'accent ; ouvert sinon, couleur atténuée). `key: null` = état seul, sans action |
| `pop_doorlock:lockpick` | `{ show: true, hits: 2, zone: 0.2, speed: 0.8, time: 6000, key: "E" }` ou `{ show: false }` | Lance ou ferme le mini-jeu (§5.3) |
| `pop_doorlock:editor` | `{ show: true, groups: [groupe admin...], keys: true }` ou `{ show: false }` | Ouvre (vue liste) ou ferme le panneau |
| `pop_doorlock:group` | `{ group: groupe admin }` | Groupe créé ou modifié : mettre à jour la liste et afficher son détail |
| `pop_doorlock:groupRemoved` | `{ id: 3 }` | Groupe supprimé : le retirer de la liste ; revenir à la liste seulement si c'est le groupe affiché |
| `pop_doorlock:aim` | `{ show: true, count: 0, max: 2, keys: { select: "E", confirm: "ENTER", cancel: "X" } }` ou `{ show: false }` | Mode visée : masquer le panneau, afficher l'aide de visée (compteur `editor_aim_count`). `show: false` → réafficher le panneau s'il était ouvert |

### 5.2 JS → Lua (`RegisterNUICallback`, via `Pop.post`)

| Nom | Corps JSON | Réponse | Côté Lua (client) |
|---|---|---|---|
| `lockpickResult` | `{ "success": true }` | `"ok"` | Rend le focus, appelle `pop_doorlock:lockpickEnd(doorId, success, false)` |
| `editorSave` | `{ "id": 3 \| null, "label": "...", "locked": true, "distance": 2.0, "security": 1, "alert": false, "jobs": { "police": 0 }, "key": true }` | `{ "ok": true, "group": {...} }` ou `{ "ok": false, "error": "<clé>" }` | `admin:saveGroup` |
| `editorDelete` | `{ "id": 3 }` | `{ "ok": bool, "error"? }` | `admin:deleteGroup` |
| `editorAddDoor` | `{ "id": 3 }` | `"ok"` | Rend le focus, envoie `pop_doorlock:aim` `show: true`, lance le mode visée |
| `editorRemoveDoor` | `{ "doorId": 12 }` | `{ "ok": bool, "group"?, "error"? }` | `admin:removeDoor` |
| `editorGiveKey` | `{ "id": 3 }` | `{ "ok": bool, "error"? }` | `admin:giveKey` |
| `editorResetKey` | `{ "id": 3 }` | `{ "ok": bool, "group"?, "error"? }` | `admin:resetKey` |
| `close` | — | (bridge) | Déjà géré par le bridge (Échap) → `Bridge.OnUiClose` : le client ferme l'éditeur ou annule le crochetage en cours |

Le Lua notifie aussi le joueur (`Bridge.Notify`) après chaque action de l'éditeur : `editor_saved`, `editor_deleted`,
`editor_door_added`, `editor_door_removed`, `editor_key_given`, `editor_key_reset`, ou la clé d'erreur.
La NUI n'affiche pas ses propres toasts.

### 5.3 Comportement de l'interface (NUI)

Tout est **sur le côté droit**, rien n'est centré. Le côté gauche est utilisé en RTL (`[dir="rtl"]`, comme le kit). Fond uni `--pop-bg`, accent `--pop-accent`, fondu de 150 ms
(`pop-fade` + `Pop.show`), deux tailles de texte, aucune dépendance externe.
- **Prompt** : une ligne `[E] Déverrouiller` + icône cadenas en SVG inline (deux variantes, `currentColor`, 14 px).
  Placé à droite, un peu sous le milieu de l'écran.
- **Crochetage** (panneau d'environ 240 px de large) : titre `lockpick_title`, barre horizontale fine, zone cible de largeur `zone`
  (fraction de 0 à 1) à une position aléatoire, curseur qui fait des allers-retours à `speed` allers-retours par seconde
  (`requestAnimationFrame`). Sous la barre : `hits` points (remplis quand réussis) et l'aide `[E] lockpick_hint`.
  Touche `key` (comparée à `e.key.toUpperCase()`) ou Espace : curseur dans la zone → coup réussi, nouvelle zone ;
  curseur hors zone → échec immédiat. Tous les coups réussis avant `time` ms → succès. Le temps écoulé → échec.
  Fin : `Pop.post('lockpickResult', { success })` **une seule fois**, puis masquer. Sur `show: false`, tout arrêter sans rien envoyer.
- **Éditeur** (panneau d'environ 340 px, hauteur max 80vh, liste qui défile, placé en haut à droite à `top: 10vh`, sans centrage vertical, pour ne pas masquer les notifications) :
  - *Liste* : titre `editor_title`, bouton `editor_new_group`, une ligne par groupe : `#id`, nom, nombre de portes, badge de sécurité
    (`editor_security_0/1/2`). `editor_empty` si la liste est vide. Clic sur une ligne → détail.
  - *Détail* : `#id` (ou `editor_new_group`), champs `editor_label` (texte, 32 caractères max), `editor_locked` (case),
    `editor_distance` (nombre de 1.0 à 5.0, pas de 0.5), `editor_security` (3 choix), `editor_alert` (case, désactivée si sécurité 2),
    `editor_jobs` (texte au format `police:0, sheriff:2`, placeholder `editor_jobs_hint`, converti en objet `{ police: 0 }` par le JS,
    entrées invalides ignorées), `editor_key` (case, désactivée avec l'info `editor_key_unsupported` si `keys = false`).
    Boutons : `editor_save`, `editor_give_key` et `editor_reset_key` (visibles seulement si `hasKey`), `editor_back`.
    Section `editor_doors` : une ligne par porte (`#id`, `editor_door_single` ou `editor_door_double`, bouton `editor_remove`),
    bouton `editor_add_door` (désactivé tant que le groupe n'est pas enregistré, c'est-à-dire `id = null`).
    `editor_delete` en bas : il faut cliquer deux fois (le libellé passe à `editor_confirm_delete` pendant 3 s).
  - *Visée* : petit panneau `editor_aim_title`, `editor_aim_count` (`count`/`max`), et une ligne par touche :
    `[E] editor_aim_select`, `[ENTER] editor_aim_confirm`, `[X] cancel`.
- Les nombres envoyés sont des `Number` et les booléens des `Boolean`. Le JS ne fait aucune validation de sécurité : c'est le rôle du serveur.

---

## 6. Exports publics

### Serveur
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_doorlock:GetDoorState(doorId)` | `bool \| nil` | `true` = verrouillée, `nil` = porte inconnue |
| `exports.pop_doorlock:SetDoorState(doorId, locked)` | `bool` | Change l'état et le diffuse (sans contrôle d'accès : réservé aux scripts) |
| `exports.pop_doorlock:SetGroupState(groupId, locked)` | `bool` | Toutes les portes du groupe (ex. braquage de banque) |
| `exports.pop_doorlock:HasAccess(src, groupId)` | `bool` | Même règle que §10 (job ou clé) |
| `exports.pop_doorlock:GiveKey(src, groupId)` | `bool` | Donne une clé du groupe (ex. location de motel) ; `false` si pas de clé ou si l'inventaire ne gère pas la metadata |

### Client
| Export | Retour |
|---|---|
| `exports.pop_doorlock:GetClosestDoor()` | `doorId \| nil`, `distance` (number), `locked` (bool) |

Les identifiants `#id` des groupes et des portes sont affichés dans l'éditeur, pour pouvoir les utiliser dans ces exports.

---

## 7. Schéma SQL (`sql/install.sql`)

Le serveur exécute aussi ces deux `CREATE TABLE IF NOT EXISTS` au démarrage, avant le chargement, pour que le fichier SQL reste facultatif.

```sql
CREATE TABLE IF NOT EXISTS `pop_doorlock_groups` (
  `id`       INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  `label`    VARCHAR(32)      NOT NULL,
  `locked`   TINYINT(1)       NOT NULL DEFAULT 1,   -- état au démarrage du serveur
  `distance` FLOAT            NOT NULL DEFAULT 2.0,
  `security` TINYINT UNSIGNED NOT NULL DEFAULT 2,   -- 0 crochetable, 1 difficile, 2 impossible
  `alert`    TINYINT(1)       NOT NULL DEFAULT 0,
  `jobs`     LONGTEXT         NULL,                 -- JSON {"police":0,"sheriff":2}, NULL = aucun
  `key_id`   VARCHAR(16)      NULL,                 -- NULL = pas de clé
  PRIMARY KEY (`id`),
  UNIQUE KEY `key_id` (`key_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `pop_doorlock_doors` (
  `id`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `group_id` INT UNSIGNED NOT NULL,
  `x`        FLOAT        NOT NULL,                 -- centre de la porte
  `y`        FLOAT        NOT NULL,
  `z`        FLOAT        NOT NULL,
  `leaves`   LONGTEXT     NOT NULL,                 -- JSON [{"model":123,"x":0.0,"y":0.0,"z":0.0}] (1 ou 2)
  PRIMARY KEY (`id`),
  KEY `group_id` (`group_id`),
  CONSTRAINT `pop_doorlock_doors_group` FOREIGN KEY (`group_id`)
    REFERENCES `pop_doorlock_groups` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

Règles : requêtes oxmysql **paramétrées** (`?`), asynchrones (`MySQL.insert`, `MySQL.update`, `MySQL.query` ; `.await` dans les
callbacks), jamais de concaténation. Le cache en mémoire est mis à jour seulement après une écriture SQL réussie.
`key_id` : 8 caractères `[a-z0-9]` générés par le serveur, uniques (on régénère en cas de collision).

---

## 8. config.lua

Garder **à l'identique** les clés communes du template (`Locale`, `Debug`, `Framework`, `Inventory`, `Target`, `Notify`,
`AccentColor`, `Keys`, `CallbackRateLimit`), puis ajouter à la suite :

```lua
-- pop_doorlock -------------------------------------------------------------

-- Commande de l'éditeur en jeu (réservée aux admins : ACE pop.admin ou groupe admin du framework).
Config.Command = 'doorlock'

-- Item clé. Chaque clé porte la metadata pop_door = clé du groupe
-- (ox_inventory, qs-inventory, qb-inventory, ps-inventory, pop_inventory ; pas l'inventaire ESX de base).
Config.KeyItem = 'door_key'

Config.Lockpick = {
    Item          = 'lockpick',
    Cooldown      = 5,                       -- secondes entre deux tentatives (par joueur)
    AlertJobs     = { 'police', 'sheriff' }, -- reçoivent l'alerte des groupes « alerte »
    AlertBlipTime = 60,                      -- secondes d'affichage du blip d'alerte
    -- Par niveau de sécurité. Le niveau 2 (impossible) n'a pas d'entrée.
    -- hits : coups à réussir | zone : largeur de la cible (0-1) | speed : allers-retours/s
    -- time : temps max (ms) | failChance : échec tiré par le serveur même si le mini-jeu est réussi
    -- breakChance : l'outil casse en cas d'échec
    Levels = {
        [0] = { hits = 2, zone = 0.20, speed = 0.8, time = 6000, failChance = 0.10, breakChance = 0.20 },
        [1] = { hits = 3, zone = 0.12, speed = 1.2, time = 7000, failChance = 0.30, breakChance = 0.40 },
    },
}
```

Rien d'autre dans la config. Valeurs fixes dans le code (constantes locales en tête de fichier, commentées) :

| Constante | Valeur | Où |
|---|---|---|
| Valeurs par défaut d'un nouveau groupe | `locked = true`, `distance = 2.0`, `security = 2`, `alert = false`, `jobs = {}`, `key = false` | serveur + NUI (état initial du formulaire) |
| Bornes de distance | 1.0 à 5.0 | serveur (clamp), NUI (min / max) |
| Tolérance de distance serveur | `group.distance + 1.0` m | server/main.lua, server/lockpick.lua |
| Portée de l'admin pour `addDoor` | 15.0 m du centre | server/editor.lua |
| Portes max par groupe | 50 | server/editor.lua |
| Écart max entre 2 battants | 4.0 m ; centre à moins de 3.0 m de chaque battant | server/editor.lua |
| Doublon | battant de même modèle à moins de 0.5 m d'un battant existant | serveur (et pré-contrôle client) |
| Anti-spam `setState` | 500 ms par joueur | server/main.lua |
| Durée min / max d'une session de crochetage | 1000 ms / `time + 3000` ms (`SESSION_EXTRA_MS`) | server/lockpick.lua |
| Rayon de proximité, cache d'accès | 30 m, 30 s | client/main.lua |
| Portée du raycast de l'éditeur | 10.0 m | client/editor.lua |
| Touche de validation de l'éditeur | contrôle 191, libellé `ENTER` | client/editor.lua (sélection : `Config.Keys.Interact`, annulation : `Config.Keys.Cancel`) |

---

## 9. Locales

Le Serveur écrit les 10 fichiers (`en` complet ; `fr es de it pt nl pl tr ar` traduits ; `ar` garde `_rtl = true` s'il est présent
dans le template). Les clés communes du template restent inchangées. Les clés ci-dessous vont sous `-- Textes propres au script :`.
Valeurs anglaises de référence :

```lua
    -- Portes
    door_lock            = 'Lock',
    door_unlock          = 'Unlock',
    door_lockpick        = 'Pick lock',
    door_locked          = 'Locked',
    door_unlocked        = 'Unlocked',
    door_now_locked      = 'Door locked',
    door_now_unlocked    = 'Door unlocked',
    door_no_access       = "You can't open this door",
    door_not_locked      = 'This door is not locked',
    -- Items
    item_lockpick        = 'Lockpick',
    item_key             = 'Door key',
    key_description      = 'Opens: %s',
    -- Crochetage
    lockpick_title       = 'Lockpicking',
    lockpick_hint        = 'Press in the zone',
    lockpick_success     = 'Lock picked',
    lockpick_failed      = 'The lock resisted',
    lockpick_broken      = 'Your lockpick broke',
    lockpick_impossible  = 'This lock cannot be picked',
    alert_lockpick       = 'Break-in attempt reported',
    alert_blip           = 'Break-in',
    -- Éditeur
    editor_title         = 'Doors',
    editor_new_group     = 'New group',
    editor_empty         = 'No groups yet',
    editor_label         = 'Name',
    editor_locked        = 'Locked on start',
    editor_distance      = 'Distance (m)',
    editor_security      = 'Security',
    editor_security_0    = 'Pickable',
    editor_security_1    = 'Hard',
    editor_security_2    = 'Unpickable',
    editor_alert         = 'Alert on lockpick',
    editor_jobs          = 'Jobs (job:min grade)',
    editor_jobs_hint     = 'police:0, sheriff:2',
    editor_key           = 'Key access',
    editor_key_unsupported = 'Keys need an inventory with item metadata',
    editor_give_key      = 'Get a key',
    editor_reset_key     = 'Reset key',
    editor_doors         = 'Doors',
    editor_door_single   = 'Single',
    editor_door_double   = 'Double',
    editor_add_door      = 'Add a door',
    editor_remove        = 'Remove',
    editor_save          = 'Save',
    editor_back          = 'Back',
    editor_delete        = 'Delete group',
    editor_confirm_delete = 'Click again to confirm',
    editor_aim_title     = 'Aim at a door',
    editor_aim_count     = 'Leaves: %s/%s',
    editor_aim_select    = 'Select',
    editor_aim_confirm   = 'Confirm',
    editor_not_door      = 'Aim at a door',
    editor_max_leaves    = 'Two leaves max per door',
    editor_door_open     = 'This door is not closed: close it for an accurate position',
    editor_saved         = 'Group saved',
    editor_deleted       = 'Group deleted',
    editor_door_added    = 'Door added',
    editor_door_removed  = 'Door removed',
    editor_key_given     = 'Key received',
    editor_key_reset     = 'Key reset: old keys no longer work',
    editor_no_key        = 'This group has no key',
    editor_door_exists   = 'This door is already registered',
    editor_leaves_far    = 'Both leaves must be next to each other',
    editor_too_many_doors = 'Too many doors in this group',
    editor_not_found     = 'Group not found',
    editor_invalid       = 'Invalid data',
```

Clés communes réutilisées : `cancel`, `no_permission`, `too_far`, `missing_item`, `cooldown`, `busy`, `inventory_full`, `error`.
Les logs console (admins, erreurs SQL) sont en anglais et ne passent pas par les locales : ils ne sont pas lus par les joueurs.

---

## 10. Sécurité (vérifiée côté serveur)

Règle générale : le serveur relit tout dans son cache (portes, groupes, config). Il n'utilise jamais une valeur du client sans
la valider (type, bornes), et vérifie que `source` est un joueur chargé (`Bridge.GetPlayer(src)`).

**HasAccess(src, group)** : `true` si (`next(group.jobs)` et `Bridge.HasJob(src, group.jobs)`) **ou** (`group.keyId`
et `HasDoorKey(src, group.keyId)`). Sinon `false`. Il n'y a aucun passe-droit admin : un admin se donne une clé.

**HasDoorKey(src, keyId)** (`server/keys.lua`, selon `Bridge.Inventory`) :
- `ox_inventory` : `exports.ox_inventory:Search(src, 'count', Config.KeyItem, { pop_door = keyId }) > 0` ;
- `qs-inventory` : `exports['qs-inventory']:GetInventory(src)`, chercher `name == Config.KeyItem` et `info.pop_door == keyId` ;
- `qb-inventory`, `ps-inventory`, ou `framework` avec qbcore/qbox : `Bridge.GetPlayer(src).PlayerData.items`, chercher `info.pop_door` ;
- `pop_inventory` : `exports.pop_inventory:GetItemCount(src, Config.KeyItem, { pop_door = keyId }) > 0`
  (`-- NOTE:` même signature qu'ox_inventory, à confirmer quand pop_inventory sera écrit) ;
- inventaire ESX de base, `none`, standalone : non géré → `false`. `KeysSupported() = false`, et un avertissement
  en console au démarrage s'il existe un groupe avec une clé.
Tout est protégé par `pcall`. La remise d'une clé se fait par `Bridge.AddItem(src, Config.KeyItem, 1, { pop_door = keyId, description = L('key_description', label) })` ;
en cas d'échec, la raison est `inventory_full`.

**`pop_doorlock:setState`** :
1. `doorId` est un entier connu, `locked` est un booléen ;
2. anti-spam de 500 ms par joueur (→ `cooldown`) ;
3. `Bridge.IsNear(src, door.center, group.distance + 1.0)` (→ `too_far`) ;
4. `HasAccess` (→ `door_no_access`) ;
5. mise à jour du cache, puis `TriggerClientEvent('pop_doorlock:client:setState', -1, doorId, locked)`.

**`pop_doorlock:lockpickStart`** :
1. porte connue et **verrouillée** (→ `door_not_locked`) ;
2. `Config.Lockpick.Levels[group.security]` existe (→ `lockpick_impossible`) ;
3. `Bridge.IsNear(src, door.center, group.distance + 1.0)` ;
3b. `HasAccess` → `has_access` (pas de session ni d'alerte : le client ouvre normalement) ;
4. cooldown par joueur `Config.Lockpick.Cooldown` (→ `cooldown`) ;
5. aucune session en cours pour ce joueur ni pour cette porte (→ `busy`) ;
6. `Bridge.HasItem(src, Config.Lockpick.Item)` (→ `missing_item`) ;
7. session créée `{ doorId, level, started = GetGameTimer() }`. Si `group.alert` : alerte (voir plus bas) ;
8. retour `true, { hits, zone, speed, time }` (lus dans la config, jamais fournis par le client).

**`pop_doorlock:lockpickEnd`** :
1. une session existe pour ce joueur **et** ce `doorId`, sinon `nil` ; elle est supprimée dans tous les cas ;
2. le cooldown démarre maintenant ;
3. `cancelled = true` → `'cancelled'` (pas de bris) ;
4. durée écoulée entre 1000 ms et `time + 3000` ms, porte toujours verrouillée, joueur toujours près de la porte,
   item toujours présent : sinon `'failed'` (sans bris) ;
5. réussite = `success == true` **et** `math.random() >= level.failChance` → la porte passe à déverrouillée (diffusion
   `client:setState`) → `'unlocked'` ;
6. sinon, si `math.random() < level.breakChance` → `Bridge.RemoveItem(src, Config.Lockpick.Item, 1)` → `'broken'`, sinon `'failed'`.
Les sessions sont nettoyées sur `Bridge.OnPlayerDropped`.

**Alerte** : pour chaque `p` de `Bridge.GetPlayers()` avec `Bridge.HasJob(p, Config.Lockpick.AlertJobs)` →
`TriggerClientEvent('pop_doorlock:client:alert', p, door.center)` ; puis `TriggerEvent('pop_doorlock:lockpickAlert', src, door.center, group.id)`.

**Callbacks admin** : `Bridge.IsAdmin(source)` à **chaque** appel. La commande client ne prouve rien.
- `label` : chaîne, espaces retirés au début et à la fin, longueur de 1 à 32 ;
- `locked`, `alert`, `key` : booléens ;
- `distance` : nombre fini, ramené entre 1.0 et 5.0 ;
- `security` : entier 0, 1 ou 2 ;
- `jobs` : table de 10 entrées max ; clé de 1 à 32 caractères correspondant à `^[%w_%-]+$` ; valeur entière de 0 à 50 ; les entrées invalides font refuser la sauvegarde (`editor_invalid`) ;
- `addDoor` : groupe existant ; 1 ou 2 battants ; `model` entier non nul ; coordonnées finies ; battants à moins de 4.0 m
  l'un de l'autre (`editor_leaves_far`) ; centre à moins de 3.0 m de chaque battant ; `Bridge.IsNear(src, center, 15.0)` ;
  pas de doublon (`editor_door_exists`) ; 50 portes max (`editor_too_many_doors`). Doublon et maximum sont revérifiés
  après l'`INSERT` (ajouts simultanés) : en cas de violation, la ligne est supprimée (`DELETE`) et la raison renvoyée ;
- `giveKey` : le groupe a une clé (`editor_no_key`), `KeysSupported()` (`editor_key_unsupported`) ;
- chaque action admin réussie est écrite en console : `[pop_doorlock] <nom> (<src>) <action> group #<id>`.

Le client ne décide jamais d'un résultat : il ne fait que demander (état, crochetage, éditeur) et afficher.

> NOTE : seule exception, le résultat du mini-jeu (`success` de `lockpickEnd`) est **déclaré par le client** et ne peut pas
> être prouvé. Il est encadré par la session (durée min / max), les revérifications (porte, distance, outil) et le tirage
> serveur `failChance`, appliqué même quand le client annonce un succès. Documenté dans le README.

> NOTE : `Bridge.HasJob` ignore le statut « en service » (`onDuty`) : un joueur hors service garde l'accès. Documenté dans le README.

---

## 11. Détails d'implémentation par côté

### Serveur (`server/*.lua`)

- Une table `Doorlock` est partagée par les fichiers serveur (définie dans `server/main.lua`, chargé en premier) :
  `Doorlock.groups[id]`, `Doorlock.doors[id]`, `Doorlock.ready`, `Doorlock.HasAccess`, `Doorlock.SetDoorState(doorId, locked)`,
  `Doorlock.PublicGroup(id)`, `Doorlock.AdminGroup(id)`, `Doorlock.SyncGroup(id)` ; dans `keys.lua` : `Doorlock.HasDoorKey`,
  `Doorlock.GiveKey(src, group)`, `Doorlock.KeysSupported()`.
- Cache : `groups[id] = { id, label, locked, distance, security, alert, jobs = {}, keyId = string|nil, doorIds = { id, ... } }` ;
  `doors[id] = { id, groupId, center = vector3, leaves = { {model,x,y,z} }, locked = bool }`.
- Démarrage : `CREATE TABLE IF NOT EXISTS`, `SELECT` des groupes et des portes, décodage JSON protégé par `pcall`
  (une ligne invalide est ignorée et signalée en console), état initial `door.locked = group.locked`, puis `ready = true`.
- `SetGroupState` et `SetDoorState` (exports) passent par `Doorlock.SetDoorState`, qui diffuse `client:setState`.
- Modifier un groupe ne change pas l'état courant de ses portes. `locked` ne s'applique qu'au démarrage et aux nouvelles portes.

### Client (`client/*.lua`)

- Une table `Doorlock` est partagée par les fichiers client : `doors[id] = { id, groupId, center = vec3, locked, hashes = {} }`,
  `groups[id] = { security, distance }`, `access[groupId] = { value = bool, t = GetGameTimer() }`.
- **Chargement** : `Bridge.OnPlayerLoaded` → `Callback.Await('pop_doorlock:getDoors')` (on vide d'abord le cache existant).
  `Bridge.OnJobUpdate` → vider `access`. `Doorlock.ClearAccess(groupId)` vide aussi l'accès d'un seul groupe (réponses
  en cours ignorées) sur `client:syncGroup`, `client:removeGroup`, et après `editorGiveKey` / `editorResetKey` réussis.
- **Système natif** : pour chaque battant `i` de la porte `id` : `hash = joaat(('pop_doorlock_%d_%d'):format(id, i))`,
  `AddDoorToSystem(hash, model, x, y, z, false, false, false)`, puis
  `DoorSystemSetDoorState(hash, locked and 1 or 0, false, true)`, précédé de `DoorSystemSetOpenRatio(hash, 0.0, false, true)`
  quand on verrouille (le battant est refermé). Pour retirer une porte : `RemoveDoorFromSystem(hash)`.
- **Boucle de proximité unique** (un seul `CreateThread`, aucun thread par porte) :
  - toutes les 1000 ms : liste `nearby` des portes à moins de 30 m (distance au `center`) ;
  - à chaque tour : porte la plus proche dans `nearby` ;
  - si elle est à 10 m ou moins et que l'accès de son groupe est inconnu ou date de plus de 30 s : `Callback.Trigger('pop_doorlock:getAccess', groupId, ...)`
    (une seule requête à la fois par groupe) ;
  - à portée (`dist <= group.distance`) : envoyer `pop_doorlock:prompt` **seulement si l'action, le libellé ou l'état changent**
    (rien n'est construit ni traduit sinon) :
    - accès `true` → `key = Config.Keys.Interact.label`, `label = L(locked and 'door_unlock' or 'door_lock')` ;
    - accès `false`, porte verrouillée, `security < 2` et joueur à pied → `key`, `label = L('door_lockpick')` ;
    - sinon (ou accès encore inconnu) → `key = nil`, `label = L(locked and 'door_locked' or 'door_unlocked')` ;
    - en mode `Bridge.TargetSystem ~= 'prompt'`, toujours `key = nil` (état seul : les actions passent par le target) ;
  - attente : rien à moins de 30 m → 1000 ms ; plus de 10 m → 500 ms ; plus loin que la portée → 100 ms ;
    à portée en mode prompt → `Wait(0)` (lecture de `IsControlJustReleased(0, Config.Keys.Interact.control)`, puis 500 ms
    d'anti-rebond après un appui) ; à portée en mode target → 250 ms ;
  - prompt masqué si : hors portée, mort, menu pause, `Bridge.IsBusy()`, crochetage ou éditeur en cours.
- **Mode target** (`Bridge.TargetSystem ~= 'prompt'`) : une zone par porte,
  `Bridge.Target.AddBoxZone('pop_doorlock_' .. doorId, center, size, heading, options)`. Simple : `size = vec3(1.2, 1.2, 2.4)`,
  `heading = 0.0`. Double : `size = vec3(longueur, 1.2, 2.4)` avec longueur = écart entre battants + 1.0 ;
  `heading = deg(atan(dy, dx))` avec ox_target, `deg(atan(dy, dx)) - 90.0` avec qb-target (`-- NOTE:` à vérifier en jeu).
  Options, avec `distance = group.distance` :
  1. `L('door_unlock')`, icône `fa-solid fa-lock-open`, si verrouillée et accès `true` ;
  2. `L('door_lock')`, icône `fa-solid fa-lock`, si déverrouillée et accès `true` ;
  3. `L('door_lockpick')`, icône `fa-solid fa-screwdriver`, si verrouillée, accès `false`, `security < 2` et joueur à pied.
  `canInteract` lit seulement le cache (jamais d'appel réseau). Zones retirées par `Bridge.Target.Remove` lors d'un sync ou d'un retrait.
- **Verrouiller** : `Callback.Await('pop_doorlock:setState', doorId, not locked)`. Si `ok` : anim
  `anim@mp_player_intmenu@key_fob@` / `fob_click` (flag 48, seulement à pied), `Bridge.Notify(L('door_now_locked' | 'door_now_unlocked'), 'success')`.
  Sinon : `Bridge.Notify(L(reason), 'error')`, et `access[groupId] = false` si `reason == 'door_no_access'`.
- **Crochetage** (`client/lockpick.lua`) : jamais en véhicule. Le cache d'accès peut être périmé : on revérifie d'abord
  `Callback.Await('pop_doorlock:getAccess', groupId)` ; accès `true` → `Doorlock.Toggle` (ouverture normale). Sinon
  `lockpickStart` → si refus, `Doorlock.NotifyReason` (§4.2) ; `has_access` → `Doorlock.Toggle`.
  Si accepté : `SetNuiFocus(true, false)`, envoyer `pop_doorlock:lockpick` `show: true` (+ `key = Config.Keys.Interact.label`)
  tout de suite, puis se tourner vers la porte (`TaskTurnPedToFaceCoord`, sans `Wait` bloquant avant le mini-jeu) ; l'anim en boucle
  `anim@amb@clubhouse@tutorial@bkr_tut_ig3@` / `machinic_loop_mechandplayer` (flag 1) démarre dans un thread après la rotation.
  `lockpickResult` ou `Bridge.OnUiClose` (alors `cancelled = true`) → `SetNuiFocus(false, false)`, `lockpick show: false`, arrêt de l'anim,
  `lockpickEnd`. Notifications : `unlocked` → `lockpick_success` (success) ; `failed` → `lockpick_failed` (error) ;
  `broken` → `lockpick_broken` (error) ; `cancelled` → rien. Après un échec, `access[groupId]` reste `false`.
- **Alerte** : `Bridge.Notify(L('alert_lockpick'), 'warning')`, blip (sprite 161, couleur 1, échelle 1.2, nom `L('alert_blip')`)
  retiré après `Config.Lockpick.AlertBlipTime` s (`SetTimeout`).
- **Éditeur** (`client/editor.lua`) : `RegisterCommand(Config.Command, ...)` → `admin:getGroups` ; `nil` → `L('no_permission')`.
  Sinon : `SetNuiFocus(true, true)` + `pop_doorlock:editor` `show: true`. Le message `pop_doorlock:prompt` est masqué tant que l'éditeur est ouvert.
  **Mode visée** (`Wait(0)` **seulement** pendant ce mode) : raycast depuis la caméra (`StartShapeTestLosProbe` ou `StartShapeTestRay`, flag 16,
  10 m) ; seuls les objets sont acceptés (`GetEntityType == 3`). Contour : `SetEntityDrawOutline(entity, true)` +
  `SetEntityDrawOutlineColor` à la couleur d'accent, sur le battant visé et les battants sélectionnés. Attaque désactivée (24, 25, 140, 141, 142, 257).
  [E] sélectionne ou désélectionne (2 max, `editor_max_leaves` sur un 3e ; refus `editor_door_exists` si le battant est déjà dans `doors`,
  contrôle à moins de 0.5 m et même modèle ; `editor_not_door` si rien n'est visé ; avertissement `editor_door_open` si le battant
  n'est pas fermé, `DoorSystemGetOpenRatio ~= 0` lu via une entrée temporaire du système natif) ; chaque changement renvoie `pop_doorlock:aim` avec `count`.
  [ENTER] (191), avec au moins 1 battant : centre de chaque battant = `GetOffsetFromEntityInWorldCoords(entity, (min + max) / 2)`
  à partir de `GetModelDimensions`, centre de la porte = moyenne de ces centres ; `admin:addDoor` dans un thread, avec un drapeau
  `confirming` (la boucle de visée continue, les touches sont ignorées pendant l'attente). [X] (`Config.Keys.Cancel`) annule.
  En sortie : retirer tous les contours, `aim show: false`, `SetNuiFocus(true, true)`, et `pop_doorlock:group` si une porte a été ajoutée.
  `Bridge.OnUiClose` → éditeur fermé (`editor show: false`).
- **Export** `GetClosestDoor` : lit le dernier calcul de la boucle (aucun calcul supplémentaire).
- **onResourceStop** : `RemoveDoorFromSystem` sur tous les hashes, retrait des contours et des blips, arrêt de l'anim,
  `SetNuiFocus(false, false)`. Les zones target sont nettoyées par le bridge.

### NUI (`web/*`)

- `index.html` : `kit/pop.css`, puis `style.css` ; `kit/pop.js`, puis `script.js`. Trois blocs masqués par défaut (`pop-fade`) :
  `#prompt`, `#lockpick`, `#editor` (vues `list`, `detail`, `aim`). Libellés fixes en `data-locale`.
- `script.js` : `Pop.on` pour chaque action du §5.1, `Pop.post` pour le §5.2. Il garde l'état local de la liste des groupes et de la vue courante.
  Le JS ne lit aucun texte en dur. Il ne touche pas au focus (c'est le rôle du Lua). Échap est déjà géré par le kit.
- `style.css` : seulement ce que le kit ne fournit pas (barre de crochetage, liste, champs). Mêmes variables, aucun dégradé,
  aucune ombre lourde. Textes longs (allemand) : retour à la ligne, aucun débordement. Unités en `rem` / `vh`.

---

## 12. Critères d'acceptation (pour l'audit)

- La ressource démarre sans erreur en ESX Legacy, ESX ancien, QBCore, Qbox et standalone (oxmysql seul requis).
- `luacheck resources templates` : 0 erreur ; `node --check web/script.js` : OK.
- Resmon au repos à moins de 0.02 ms (aucune porte à moins de 30 m : un tour par seconde) ; aucun `Wait(0)` en dehors de la portée en mode prompt, du mode visée et de `Bridge.Progress`.
- Aucun texte en dur côté joueur (Lua et NUI) ; les 10 locales ont toutes les clés du §9 ; l'arabe s'affiche en RTL.
- Un client modifié ne peut pas : ouvrir une porte sans accès ou à distance ; crocheter une porte de sécurité 2, sans item ou
  en contournant le cooldown ; utiliser un callback admin sans `Bridge.IsAdmin`.
- Après une réinitialisation de clé, l'ancienne clé ne fonctionne plus. Après un redémarrage du serveur, les groupes et les portes sont conservés.
