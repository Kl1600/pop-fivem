# pop_police : SPEC (contrat commun Serveur / Client / NUI)

> Ce document est **la référence unique**. Les noms (fichiers, events, callbacks, statebags, clés de config, clés de
> locale, champs JSON, messages NUI) sont repris **à l'identique**. En cas de doute : ce fichier fait foi ; en cas
> d'ambiguïté, choisir l'option la plus sûre et la noter en commentaire `-- NOTE:`.
> API commune, à utiliser telle quelle : `Bridge.*`, `Callback.*`, `L()`, `Pop.*` (voir `templates/pop_base/README.md`).
> Modèle lu, **aucun code repris** : `tab_police` (tablette dispatch ESX). On n'en garde que l'idée d'un thème visuel
> optionnel (`Config.Theme`, qui remplace la variante `tab_police80`). Patrouilles, indicatifs, positions des agents en
> direct, détection de tirs et avis de recherche sont **hors périmètre**.
> Aucune commande git. `bridge/`, `shared/`, `web/kit/` sont copiés par l'intégrateur depuis `templates/pop_base`.

Plan : 1 Description · 2 Arborescence et répartition · 3 Données et statebags · 4 Events · 5 Callbacks · 6 NUI ·
7 Exports · 8 SQL · 9 Config · 10 Locales · 11 Comportement Serveur · 12 Comportement Client · 13 Sécurité ·
14 Checklist audit.

---

## 1. Description et fonctionnalités

Outils du métier de policier, sobres et réalistes, façon GTA 6 : quelques actions courtes et bien faites, un casier
minimaliste, et des contre-jeux pour les suspects (on peut s'enfuir pendant qu'on vous passe les menottes).

**Qui** : un joueur dont le job est dans `Config.Jobs` (format `Bridge.HasJob`) ; en standalone, un joueur qui a
l'ACE `pop.police`. Toutes les actions exigent d'être **en service**.

**Fonctionnalités (périmètre complet, rien de plus)**
1. **Service** : point « Prendre / Terminer son service » dans chaque commissariat (`Config.Stations`). Fin de service
   possible aussi depuis le menu. QBCore / Qbox : le service du framework est utilisé et mis à jour. ESX / standalone :
   service géré par le script (hors service à chaque connexion).
2. **Vestiaire (optionnel)** : point `locker` d'un commissariat (absent = pas de vestiaire). Tenues de `Config.Outfits`
   (filtrées par grade) et « Tenue civile » (retour à la tenue portée avant la première tenue de service).
   Purement visuel, côté client, sans framework de vêtements.
3. **Menu police** (touche `Config.KeyMappings.menu`, F6) : petite liste sur le côté droit. Les actions proposées
   dépendent de la situation (personne la plus proche, menottée ou non, en véhicule ou non) :
   - **Menotter** en deux temps : barre de `Config.Durations.cuff` ms ; la cible est prévenue dès le début et peut
     s'éloigner pour faire échouer l'action. Item `Config.Handcuffs` requis (non consommé) ; `false` = pas d'item.
     Statebag `cuffed` sur la cible, lisible par tous les scripts.
   - **Démenotter** (barre de `Config.Durations.uncuff` ms).
   - **Escorter / Lâcher** une personne menottée (attachée à l'agent).
   - **Mettre dans le véhicule** (le plus proche, place arrière libre en priorité) / **Sortir du véhicule** (personne
     menottée uniquement).
   - **Fouiller** une personne menottée ou à terre : ouvre son inventaire (pop_inventory, ox_inventory, qb-inventory
     v2) ; sinon notification avec la liste des objets trouvés.
   - **Amende** : formulaire (montant borné par `Config.Fines`, motif court). La cible reçoit une carte
     « [Y] Payer  [BACK] Refuser » pendant `Config.Fines.timeout` s. Paiement par `Bridge.RemoveMoney` sur
     `Config.Fines.account`. Tout est enregistré au casier (payée, refusée, impayée, expirée).
   - **Casier** (MDT minimaliste) : recherche par nom ou ID serveur, fiche (notes, amendes, total impayé), ajout et
     suppression de notes.
   - **Bouton panique** (aussi touche `Config.KeyMappings.panic`, F9) : notification, son et blip chez tous les agents
     en service.
   - **Fin de service**.
4. **Effets sur la personne menottée** : animation, pas d'arme, pas de sprint / saut / combat / entrée ou sortie de
   véhicule, inventaire bloqué (statebag `invBusy`, compatible pop_inventory et ox_inventory).
5. **Alertes externes** : export serveur `Alert(coords, text)` pour les autres scripts (notification + blip chez les
   agents en service).
6. **Thème visuel optionnel** : `Config.Theme = 'modern'` (POP, couleur d'accent de la config) ou `'retro80'`
   (terminal ambre années 80 : fond noir uni, texte ambre, police monospace, coins droits). Même HTML, seul le CSS change.
7. **Persistance oxmysql** : casier (personnes, notes, amendes). Tables créées automatiquement au démarrage.

**Performance**
- Repos (ni menotté, ni escorté, ni escorte en cours, interface fermée) : **aucune boucle** propre au script.
  Les seules boucles du repos sont celles du bridge (prompt des points de commissariat).
- `Wait(0)` **uniquement** pendant qu'on est menotté (désactivation des contrôles, obligatoire chaque frame) et dans
  `Bridge.Progress`. Escorte : boucle à 500 ms seulement pendant l'escorte.
- Aucune entité créée. Serveur : aucune boucle ; minuteries `SetTimeout` uniquement pour l'expiration des amendes.

**Hors périmètre (volontairement)** : dispatch / appels, patrouilles, GPS des collègues, prison, fourrière, permis,
avis de recherche, photos, paiement différé des amendes impayées, compte de société (un event serveur permet de le
brancher, §4.3), mise à terre (tackle), radio.

---

## 2. Arborescence et répartition

```
resources/[pop]/pop_police/
  SPEC.md                 Architecte (ce fichier)
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR   clés communes de pop_base + §9, à l'identique
  README.md               SERVEUR   EN ANGLAIS : installation, ACE pop.police, item handcuffs, inventaires, exports, events
  sql/install.sql         SERVEUR   §8
  bridge/server.lua       intégrateur  copie STRICTE de templates/pop_base
  bridge/client.lua       intégrateur  copie STRICTE
  shared/callback.lua     intégrateur  copie STRICTE
  shared/locale.lua       intégrateur  copie STRICTE
  common/police.lua       SERVEUR   constantes partagées (chargé des deux côtés, §3.1)
  locales/en.lua … ar.lua SERVEUR   10 fichiers : bloc « Kit commun » inchangé + §10 (ar : _rtl = true)
  server/main.lua         SERVEUR   état officier / service, statebags, garde des statebags, panique, alerte, exports, nettoyage
  server/actions.lua      SERVEUR   menottes, escorte, véhicule, fouille
  server/fines.lua        SERVEUR   amendes (en attente, réponse, enregistrement)
  server/mdt.lua          SERVEUR   tables SQL, casier (recherche, fiche, notes), Police.GetCitizenId
  client/main.lua         CLIENT    état local, touches, menu et NUI, points de commissariat, vestiaire, panique / alertes
  client/actions.lua      CLIENT    choix de la cible, déroulé des actions de l'agent, escorte côté agent
  client/effects.lua      CLIENT    effets sur soi : menotté, escorté, mis en / sorti du véhicule, carte d'amende
  web/index.html          NUI
  web/script.js           NUI
  web/style.css           NUI       thèmes modern et retro80
  web/kit/pop.css, pop.js intégrateur  copie STRICTE
```

Les fichiers `client/main.lua`, `server/main.lua` et `web/script.js` du template sont remplacés. Aucun autre fichier.

### 2.1 Répartition

| Dev | Fichiers | Dépend de (contrat seulement) |
|---|---|---|
| **Serveur** | `fxmanifest.lua`, `config.lua`, `README.md`, `sql/`, `common/`, `locales/` (les 10, **toutes** les clés, y compris celles du client et de la NUI), `server/*` | §3 à §5, §7 à §11, §13 |
| **Client** | `client/*` | §3 à §6, §9, §10, §12 |
| **NUI** | `web/index.html`, `web/script.js`, `web/style.css` | §6, §10 |

### 2.2 fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_police'
author 'POP'
version '1.0.0'
description 'POP Police - police job tools'

dependencies { 'oxmysql' }

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
    'common/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
    'client/actions.lua',
    'client/effects.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/main.lua',
    'server/actions.lua',
    'server/fines.lua',
    'server/mdt.lua',
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
}
```

### 2.3 Globales partagées
- Une seule table globale par côté : `Police` (créée dans `common/police.lua`). Chaque fichier qui y ajoute des
  fonctions commence par `Police = Police or {}`. Les fonctions ne s'appellent entre fichiers **qu'à l'exécution**
  (jamais au chargement).
- Serveur : fonctions et tables partagées listées en §11.1. Client : état et fonctions listés en §12.1.

---

## 3. Données et statebags

### 3.1 `common/police.lua` (exact, Dev Serveur)
```lua
Police = Police or {}

Police.STATE_CUFFED = 'cuffed'         -- statebag joueur : true | nil (écrit par le serveur uniquement)
Police.STATE_ESCORT = 'popEscortedBy'  -- statebag joueur : server id de l'agent qui escorte | nil
Police.STATE_DUTY   = 'popPoliceDuty'  -- statebag joueur : true | nil (agent en service)

Police.TARGET_DISTANCE  = 2.5   -- client : joueur le plus proche pour le menu
Police.ACTION_DISTANCE  = 3.5   -- serveur : agent <-> cible (marge de latence comprise)
Police.VEHICLE_DISTANCE = 5.0   -- client : véhicule le plus proche
Police.VEHICLE_SERVER_DISTANCE = 7.0 -- serveur : centre du véhicule <-> agent et <-> cible
Police.STATION_DISTANCE = 2.0   -- client : options des points ; serveur : + 1.0
Police.ACTION_COOLDOWN  = 750   -- ms entre deux actions d'un même agent (serveur)
Police.FINE_COOLDOWN    = 10    -- s entre deux amendes d'un même agent (serveur)
Police.REASON_MIN, Police.REASON_MAX = 3, 100  -- motif d'amende (caractères)
Police.NOTE_MIN, Police.NOTE_MAX     = 3, 500  -- note de casier
Police.QUERY_MAX    = 50        -- recherche casier
Police.RESULTS_MAX  = 10        -- résultats de recherche
Police.HISTORY_MAX  = 50        -- notes et amendes affichées par fiche (les plus récentes)
Police.ESCORT_OFFSET = vec3(0.45, 0.45, 0.0) -- client : position de la personne escortée par rapport à l'agent
```

### 3.2 Statebags (tous écrits **uniquement par le serveur**, répliqués : `state:set(key, value, true)`)
| Clé | Porté par | Valeur | Lu par |
|---|---|---|---|
| `cuffed` (`Police.STATE_CUFFED`) | la personne menottée | `true` ou `nil` | client de la personne (effets), clients des agents (menu), **autres scripts** (pop_inventory : fouille) |
| `popEscortedBy` (`Police.STATE_ESCORT`) | la personne escortée | server id de l'agent ou `nil` | client de la personne (attache), clients des agents (menu) |
| `popPoliceDuty` (`Police.STATE_DUTY`) | l'agent | `true` ou `nil` | client de l'agent (menu, points), autres scripts |
| `invBusy` | la personne menottée | `true` à la pose, `false` au retrait | pop_inventory, ox_inventory (bloque l'inventaire) |

Compatibilité QBCore / Qbox : en plus du statebag, `Player.Functions.SetMetaData('ishandcuffed', bool)` (dans un `pcall`)
à chaque changement de `cuffed`.

### 3.3 Fine (amende en attente, serveur uniquement)
```lua
fines[id] = {
    id = 7,                       -- entier croissant (mémoire)
    target = 12, officer = 3,     -- server ids
    targetIdentifier = '...', targetName = 'John Doe',
    officerIdentifier = '...', officerName = 'Jane Smith',
    amount = 250, reason = 'Speeding',
    expires = os.time() + Config.Fines.timeout,
}
```
Une seule amende en attente par cible (`pendingByTarget[target] = id`). Tables locales à `server/fines.lua`.

---

## 4. Events

Toutes les demandes client → serveur passent par des **callbacks** (§5). Il n'y a **aucun** `RegisterNetEvent` serveur
propre au script.

### 4.1 Serveur → client (`RegisterNetEvent` côté client)
| Event | Paramètres | Destinataire | Fichier client | Rôle |
|---|---|---|---|---|
| `pop_police:client:beingCuffed` | aucun | la cible | effects.lua | `Bridge.Notify(L('being_cuffed'), 'warning')` (elle peut fuir) |
| `pop_police:client:leaveVehicle` | aucun | la cible | effects.lua | Sortir du véhicule (§12.4) |
| `pop_police:client:fineRequest` | `data` = `{ id, amount, reason, officer }` (`officer` = nom) | la cible | effects.lua | Affiche la carte d'amende |
| `pop_police:client:fineClosed` | `id` (int) | la cible | effects.lua | Amende expirée : masque la carte si c'est la même |
| `pop_police:client:panic` | `data` = `{ coords = { x, y, z }, name }` | agents en service | main.lua | Notification `panic_alert`, son, blip, point GPS |
| `pop_police:client:alert` | `data` = `{ coords = { x, y, z }, text }` | agents en service | main.lua | Notification `text`, blip `alert_blip` |

Notifications serveur → joueur : toujours `Bridge.Notify(src, L(key, ...), type)` (event du bridge, ne pas recréer).

### 4.2 Statebags (pas d'event réseau) : voir §3.2. Le client suit ses propres clés avec
`AddStateBagChangeHandler(key, ('player:%s'):format(GetPlayerServerId(PlayerId())), fn)`.

### 4.3 Events serveur locaux (pour les autres ressources, `TriggerEvent`, jamais réseau)
| Event | Paramètres | Quand |
|---|---|---|
| `pop_police:dutyChanged` | `src`, `onDuty` (bool) | Prise / fin de service par le script |
| `pop_police:cuffChanged` | `target`, `cuffed` (bool), `officer` (server id \| nil si export) | Pose / retrait des menottes |
| `pop_police:finePaid` | `target`, `officer` (server id, peut être déconnecté), `amount`, `reason` | Amende payée (brancher ici un compte de société) |
| `pop_police:panic` | `src`, `coords` (vector3) | Bouton panique accepté |

### 4.4 Évènements du bridge utilisés
- Serveur : `Bridge.OnPlayerLoaded(src)` → `Police.RefreshDuty(src)` ; `Bridge.OnPlayerUnloaded(src)` et
  `Bridge.OnPlayerDropped(src)` → nettoyage (§11.6).
- Client : `Bridge.OnPlayerLoaded` et `Bridge.OnJobUpdate` → `Police.RefreshState()` (§12.1) ; `Bridge.OnUiClose` →
  fermeture de l'interface.

---

## 5. Callbacks (`shared/callback.lua`)

Convention des actions : retour `ok (bool), reason (clé de locale) | nil, arg | nil`.
Échec → le **client** affiche `Bridge.Notify(L(reason or 'error', arg), 'error')`. Succès → c'est le **serveur** qui
notifie si besoin. `nil` (timeout 10 s ou anti-spam) = `reason = 'error'`.
Callbacks qui renvoient des données : `true, nil, data` ou `false, reason`.

### 5.1 Client → serveur (`Callback.Register` serveur, `Callback.Await` client)
| Nom | Fichier serveur | Paramètres | Retour |
|---|---|---|---|
| `pop_police:getState` | main.lua | aucun | `{ officer = bool, onDuty = bool, grade = int }` (rafraîchit aussi le statebag de service) |
| `pop_police:setDuty` | main.lua | `state` (bool), `station` (int \| nil : index dans `Config.Stations`, requis si `state == true`) | `ok, reason` |
| `pop_police:cuff` | actions.lua | `target` (server id), `phase` (`'start'` \| `'finish'`) | `ok, reason, arg` |
| `pop_police:uncuff` | actions.lua | `target` | `ok, reason` |
| `pop_police:escort` | actions.lua | `target`, `state` (bool : true = escorter, false = lâcher) | `ok, reason` |
| `pop_police:putInVehicle` | actions.lua | `target`, `netId` (int) | `ok, reason` |
| `pop_police:takeOutVehicle` | actions.lua | `target` | `ok, reason` |
| `pop_police:search` | actions.lua | `target` | `ok, reason` |
| `pop_police:fine` | fines.lua | `target`, `amount` (int), `reason` (string) | `ok, reason, arg` |
| `pop_police:respondFine` | fines.lua | `id` (int), `accept` (bool) | `ok, reason, status` (`status` ∈ `'paid'`, `'unpaid'`, `'refused'` si ok) |
| `pop_police:panic` | main.lua | aucun | `ok, reason, arg` |
| `pop_police:mdtSearch` | mdt.lua | `query` (string) | `true, nil, results` \| `false, reason` |
| `pop_police:mdtProfile` | mdt.lua | `ref` = `{ citizenId = int }` ou `{ serverId = int }` | `true, nil, profile` \| `false, reason` |
| `pop_police:mdtAddNote` | mdt.lua | `citizenId` (int), `text` (string) | `true, nil, profile` \| `false, reason` |
| `pop_police:mdtDeleteNote` | mdt.lua | `noteId` (int) | `true, nil, profile` \| `false, reason` |

`cuff` en deux temps : `'start'` **avant** la barre (contrôles, prévient la cible), `'finish'` **après** la barre
(revérifie et applique). Le serveur refuse un `finish` trop tôt ou trop tard (§13).

### 5.2 Serveur → client (`Callback.Register` client, `Callback.Await` serveur)
| Nom | Fichier client | Paramètres | Retour |
|---|---|---|---|
| `pop_police:enterVehicle` | effects.lua | `netId` (int) | `true` si la personne a été placée, sinon `false` (aucune place) |

### 5.3 Formats de données
**`results`** (tableau séquentiel, au plus `Police.RESULTS_MAX`) :
```json
[ { "citizenId": 4, "serverId": 12, "name": "John Doe" },
  { "citizenId": null, "serverId": 15, "name": "Jane Roe" },
  { "citizenId": 9, "serverId": null, "name": "Mike Doe" } ]
```
`serverId` = joueur en ligne ; `citizenId` = fiche déjà en base. Jamais d'identifiant de joueur.

**`profile`** :
```json
{ "citizenId": 4, "name": "John Doe", "online": true, "serverId": 12, "unpaid": 250,
  "notes": [ { "id": 31, "text": "Arrested for robbery", "author": "Jane Smith", "createdAt": 1773695584, "canDelete": true } ],
  "fines": [ { "id": 18, "amount": 250, "reason": "Speeding", "status": "unpaid", "officer": "Jane Smith", "createdAt": 1773695000 } ] }
```
`notes` et `fines` : plus récents d'abord, au plus `Police.HISTORY_MAX` chacun. `unpaid` = somme des amendes `unpaid`.
`status` ∈ `paid`, `refused`, `unpaid`, `expired`. `createdAt` = `os.time()` serveur (secondes).
`serverId` vaut `null` hors ligne.

**Raisons possibles** (toutes des clés de locale existantes) :
`error`, `busy`, `cooldown` (arg = secondes), `too_far`, `wrong_job`, `no_permission`, `missing_item`
(arg = `L('item_handcuffs')`), `not_on_duty`, `cannot_now`, `invalid_target`, `already_cuffed`, `not_cuffed`,
`target_in_vehicle`, `target_not_in_vehicle`, `already_escorted`, `no_vehicle`, `vehicle_full`, `cannot_search`,
`fine_pending`, `invalid_amount`, `invalid_reason`, `fine_not_found`, `invalid_query`, `citizen_not_found`,
`invalid_note`, `note_not_found`.

---

## 6. Messages NUI

Page unique `web/index.html`. Le HUD du kit (`pop:prompt`, `pop:progress`, `pop:notify`) reste disponible.
Tout le texte vient des locales (`data-locale`, `Pop.t`) ou des données envoyées par le Lua. Insertion de texte
**uniquement** par `textContent` (jamais `innerHTML` avec des données).

**Focus** : le menu, le formulaire d'amende et le casier prennent le focus (`SetNuiFocus(true, true)`, côté Lua).
La carte d'amende de la cible **ne prend jamais** le focus. Échap (kit) → `close` → `Bridge.OnUiClose` (le focus est
déjà rendu) → le client envoie `pop_police:close`.

Chaque message `show: true` du menu, du formulaire, du casier et de la carte porte `theme` (`'modern'` | `'retro80'`) ;
le JS l'applique à chaque fois (idempotent, §6.3).

### 6.1 Lua → JS (`SendNUIMessage`)

**`pop_police:menu`** : liste d'actions (le Lua a déjà filtré selon la situation, ordre §12.2).
```json
{ "action": "pop_police:menu", "show": true, "theme": "modern",
  "target": { "serverId": 12 },
  "actions": ["cuff", "fine", "mdt", "panic", "duty_off"] }
```
`target` vaut `null` si personne n'est à portée. Ids possibles : `cuff`, `uncuff`, `escort`, `stop_escort`,
`put_in_vehicle`, `take_out_vehicle`, `search`, `fine`, `mdt`, `panic`, `duty_off`. Libellé = `Pop.t('action_' + id)`.

**`pop_police:fineForm`** : formulaire d'amende (remplace le menu dans le même emplacement).
```json
{ "action": "pop_police:fineForm", "show": true, "theme": "modern", "target": { "serverId": 12 }, "min": 50, "max": 10000 }
```

**`pop_police:mdt`** : ouvre le casier (masque le menu). Vide à l'ouverture (champ de recherche focalisé).
```json
{ "action": "pop_police:mdt", "show": true, "theme": "modern" }
```

**`pop_police:close`** : masque menu, formulaire et casier (idempotent). `{ "action": "pop_police:close" }`

**`pop_police:fineRequest`** : carte d'amende chez la cible.
```json
{ "action": "pop_police:fineRequest", "show": true, "theme": "modern",
  "id": 7, "amount": 250, "reason": "Speeding", "officer": "Jane Smith",
  "acceptKey": "Y", "declineKey": "BACK", "timeout": 30 }
```
```json
{ "action": "pop_police:fineRequest", "show": false }
```
`acceptKey` / `declineKey` = `Config.KeyMappings.acceptFine` / `.declineFine` (`-- NOTE:` le joueur peut les
changer dans les raccourcis FiveM ; le libellé affiché reste celui de la config). `timeout` = `Config.Fines.timeout`.

### 6.2 JS → Lua (`RegisterNUICallback`, via `Pop.post`) — tous dans `client/main.lua`
| Nom | Corps JSON | Réponse | Côté Lua |
|---|---|---|---|
| `action` | `{ "id": "cuff" }` | `{ "ok": true }` | `id` doit faire partie des `actions` envoyées en dernier, sinon `{ "ok": false }` et rien. `fine` → `pop_police:fineForm` ; `mdt` → `pop_police:mdt` ; autres → fermeture de l'interface puis déroulé §12.3 (dans un thread) |
| `fine` | `{ "amount": 250, "reason": "Speeding" }` | `{ "ok": true }` ou `{ "ok": false, "error": "<clé>" }` | `pop_police:fine` sur `Police.menuTarget` ; succès → fermeture |
| `mdtSearch` | `{ "query": "john" }` | `{ "ok": true, "results": [...] }` ou `{ "ok": false, "error": "<clé>" }` | `pop_police:mdtSearch` |
| `mdtProfile` | `{ "citizenId": 4 }` ou `{ "serverId": 12 }` | `{ "ok": true, "profile": {...} }` ou erreur | `pop_police:mdtProfile` |
| `mdtAddNote` | `{ "citizenId": 4, "text": "..." }` | idem (fiche à jour) | `pop_police:mdtAddNote` |
| `mdtDeleteNote` | `{ "noteId": 31 }` | idem (fiche à jour) | `pop_police:mdtDeleteNote` |
| `close` | — | (bridge) | Géré par le bridge (Échap, ou `Pop.post('close')` des boutons Fermer / Annuler) |

En cas d'échec, le **Lua** notifie (`Bridge.Notify(L(error), 'error')`) ; la NUI n'affiche pas de toast, elle réactive
simplement ses boutons. Le Lua convertit les nombres (`math.tointeger(tonumber(x))`) et vérifie les types (`string`)
avant tout appel serveur ; entrée invalide → `{ ok = false, error = 'error' }` sans appel.

### 6.3 Interface (Dev NUI)
DA POP : fond uni `--pop-bg`, texte blanc, **une** couleur d'accent `--pop-accent`, police système, aucun dégradé,
aucun glassmorphism, aucune ombre lourde, transitions = `.pop-fade` du kit uniquement. Taille de texte `--pop-size`
/ `--pop-size-sm`.

**`index.html`** : base pop_base, `<link rel="stylesheet" href="style.css">` après `kit/pop.css`. `#app` remplacé par
quatre blocs, masqués par défaut (`pop-panel pop-fade`) :
- `#police-menu` : en-tête `data-locale="menu_title"`, ligne `#menu-target` (petite) ; liste `#menu-actions`
  (boutons construits par le JS).
- `#police-fine` : titre `fine_title`, `#fine-target` (petite), libellé `fine_amount` + `<input id="fine-amount"
  type="number">`, `#fine-bounds` (petite), libellé `fine_reason` + `<input id="fine-reason" maxlength="100">`,
  boutons `#fine-send` (`fine_send`, `pop-button`) et `#fine-cancel` (`cancel`).
- `#police-mdt` : en-tête `mdt_title` + bouton `#mdt-close` (`close`) ; ligne de recherche `<input id="mdt-query"
  maxlength="50">` (placeholder `mdt_search_hint`, posé par le JS) + `#mdt-search-btn` (`mdt_search`) ; `#mdt-results`
  (liste) ; `#mdt-profile` (masqué tant qu'aucune fiche) : `#mdt-back` (`mdt_back`), `#mdt-name`, `#mdt-status`,
  `#mdt-unpaid`, section `mdt_notes` (`#mdt-notes`, `<textarea id="mdt-note" maxlength="500">` placeholder
  `mdt_note_hint`, `#mdt-add-note` `mdt_add_note`), section `mdt_fines` (`#mdt-fines`).
- `#police-fine-request` : titre `fine_request_title`, `#fr-amount` (grand, accent), `#fr-reason`, `#fr-officer`
  (petite, `Pop.t('fine_from', officer)`), ligne touches `[acceptKey] fine_pay   [declineKey] fine_decline`
  (classes `pop-key`), barre fine `#fr-timer` (3 px).

**`script.js`**
- Thème : `document.documentElement.dataset.theme = data.theme` ; si `retro80` → `Pop.setAccent('#ffb000')`.
- `pop_police:menu` : `#menu-target` = `Pop.t('menu_target', target.serverId)` ou `Pop.t('menu_no_target')` ;
  un bouton par id (`Pop.t('action_' + id)`), `panic` en `--pop-danger`. Clavier : ↑ / ↓ déplacent la sélection
  (accent), Entrée valide ; clic = valide. Valider → `Pop.post('action', { id })`. Affiche `#police-menu`, masque les autres.
- `pop_police:fineForm` : `#fine-target` = `Pop.t('menu_target', serverId)`, `#fine-bounds` =
  `Pop.t('fine_bounds', Pop.t('money', min), Pop.t('money', max))`, `min` / `max` sur l'input, focus sur le montant.
  Envoi : montant entier dans les bornes et motif de 3 à 100 caractères (après `trim`), sinon bordure `--pop-danger`
  sur le champ fautif et rien n'est envoyé ; sinon `Pop.post('fine', { amount, reason })`, boutons désactivés jusqu'à
  la réponse. Entrée dans un champ = envoyer. Annuler → `Pop.post('close')`.
- `pop_police:mdt` : vide résultats et fiche, focus sur `#mdt-query`. Recherche (bouton ou Entrée) →
  `Pop.post('mdtSearch', { query })` → une ligne par résultat : nom + `Pop.t('mdt_online', serverId)` ou
  `Pop.t('mdt_offline')` ; aucun → `Pop.t('mdt_no_results')`. Clic → `Pop.post('mdtProfile', citizenId ?
  { citizenId } : { serverId })`. Fiche : nom, statut, `Pop.t('mdt_unpaid', Pop.t('money', unpaid))` (masqué si 0),
  notes (texte, `auteur · date`, bouton `mdt_delete` si `canDelete`), amendes (`Pop.t('money', amount)` · motif ·
  `Pop.t('status_' + status)` · `officier · date` ; `unpaid` en `--pop-danger`). Listes vides → `Pop.t('mdt_empty')`.
  Ajout de note → `Pop.post('mdtAddNote', { citizenId, text })` → fiche réaffichée, textarea vidée.
  Suppression → `Pop.post('mdtDeleteNote', { noteId })`. Retour → liste des résultats.
  Dates : `new Date(createdAt * 1000).toLocaleString(Pop.t('date_locale'))` (repli `toLocaleString()` si exception).
  `#mdt-close` → `Pop.post('close')`.
- `pop_police:close` : masque `#police-menu`, `#police-fine`, `#police-mdt`.
- `pop_police:fineRequest` : remplit, affiche ; `#fr-timer` : `transform: scaleX(1)` → `scaleX(0)` en
  `timeout` s linéaire (même technique que la barre du kit). `show: false` → masque.
- Les entrées clavier dans les champs ne déclenchent pas la navigation du menu. Aucune validation de sécurité, aucun
  texte en dur, aucune dépendance externe, aucun appel de focus.

**`style.css`**
- `#police-menu`, `#police-fine` : 260 px, `position: fixed; right: 24px; top: 22%`. `#police-mdt` : 440 px,
  `right: 24px; top: 10vh; max-height: 80vh`, listes à défilement vertical. `#police-fine-request` : 260 px,
  `right: 24px; top: 22%`.
- Lignes du menu : pleine largeur, fond transparent, sélection = bordure de début 3 px accent
  (`border-inline-start`) + texte accent.
- RTL (`[dir="rtl"]`) : panneaux à gauche (`right: auto; left: 24px`), barres `transform-origin: right`.
- **Thème `retro80`** (`[data-theme="retro80"]`) : `--pop-bg: #0b0802` (opaque), `--pop-text: #ffb000`,
  `--pop-muted: rgba(255, 176, 0, 0.6)`, `--pop-radius: 0`, `--pop-font: "Courier New", ui-monospace, monospace` ;
  panneaux avec bordure 1 px `--pop-accent` ; titres en majuscules avec `letter-spacing: 0.08em`. Aucun effet de
  scanlines animé, aucun dégradé, aucune lueur (`text-shadow` interdit).

---

## 7. Exports publics

### 7.1 Serveur (`server/main.lua`)
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_police:IsCuffed(src)` | bool | lit `Police.cuffed` (référence serveur) |
| `exports.pop_police:SetCuffed(src, state)` | bool | pose / retire sans job ni item ni distance (prison, admin, autre script) ; `false` si joueur absent ; retirer libère aussi l'escorte |
| `exports.pop_police:IsOnDuty(src)` | bool | `Police.IsOnDuty(src)` |
| `exports.pop_police:GetOfficers()` | `{ src, ... }` | agents en service |
| `exports.pop_police:Alert(coords, text)` | bool | `coords` (vector3 ou `{x,y,z}`, nombres finis), `text` chaîne déjà traduite par l'appelant (tronquée à 150) → `pop_police:client:alert` à chaque agent en service ; `false` si entrée invalide |

### 7.2 Client
| Export | Fichier | Retour |
|---|---|---|
| `exports.pop_police:IsCuffed()` | effects.lua | bool (`LocalPlayer.state.cuffed == true`) |
| `exports.pop_police:IsEscorted()` | effects.lua | bool |
| `exports.pop_police:IsOnDuty()` | main.lua | bool (état local, §12.1) |

---

## 8. Schéma SQL (`sql/install.sql`, Dev Serveur)

Le serveur exécute aussi ces `CREATE TABLE IF NOT EXISTS` au démarrage (`server/mdt.lua`) : aucune action manuelle.
```sql
CREATE TABLE IF NOT EXISTS `pop_police_citizens` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64)  NOT NULL,
    `name`       VARCHAR(100) NOT NULL,
    `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_identifier` (`identifier`),
    KEY `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `pop_police_notes` (
    `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizen_id`        INT UNSIGNED NOT NULL,
    `text`              VARCHAR(500) NOT NULL,
    `author`            VARCHAR(100) NOT NULL,
    `author_identifier` VARCHAR(64)  NOT NULL,
    `created_at`        INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_citizen` (`citizen_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `pop_police_fines` (
    `id`                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizen_id`         INT UNSIGNED NOT NULL,
    `amount`             INT UNSIGNED NOT NULL,
    `reason`             VARCHAR(100) NOT NULL,
    `status`             VARCHAR(16)  NOT NULL,   -- paid | refused | unpaid | expired
    `officer`            VARCHAR(100) NOT NULL,
    `officer_identifier` VARCHAR(64)  NOT NULL,
    `created_at`         INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_citizen` (`citizen_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ESX uniquement (inventaire du framework), à décommenter si besoin :
-- INSERT IGNORE INTO `items` (`name`, `label`, `weight`) VALUES ('handcuffs', 'Handcuffs', 1);
```
Règles :
- Requêtes **toujours paramétrées** (`?`). Recherche : `WHERE name LIKE ? ORDER BY name LIMIT ?` avec
  `'%' .. échappé .. '%'` (`%`, `_` et `\` échappés par `\`).
- `Police.GetCitizenId(identifier, name)` (bloquant) :
  `INSERT INTO pop_police_citizens (identifier, name) VALUES (?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name), id = LAST_INSERT_ID(id)`
  via `MySQL.insert.await` → id (existant ou nouveau). Nom à jour à chaque appel. Nom tronqué à 100.
- Amende : une ligne **seulement à sa résolution** (payée, refusée, impayée, expirée) : aucune ligne « en attente »
  ne survit à un redémarrage.
- Aucune suppression d'amende. Note supprimée : `DELETE` de la ligne.

---

## 9. config.lua (contenu exact)

Le fichier reprend **à l'identique** le `config.lua` de `templates/pop_base` (Locale, Debug, Framework, Inventory,
Target, Notify, AccentColor, Keys, CallbackRateLimit), puis ajoute à la suite :

```lua
-- ─── pop_police ─────────────────────────────────────────────

-- Jobs de police (format Bridge.HasJob). En standalone : ACE 'pop.police' (voir README).
Config.Jobs = { 'police', 'sheriff' }

-- Thème de l'interface : 'modern' (couleur d'accent ci-dessus) ou 'retro80' (terminal ambre années 80).
Config.Theme = 'modern'

-- Touches par défaut (chaque joueur peut les changer dans les paramètres FiveM).
Config.KeyMappings = {
    menu        = 'F6',
    panic       = 'F9',
    acceptFine  = 'Y',
    declineFine = 'BACK',
}

-- Item requis pour menotter (non consommé). false = aucun item.
Config.Handcuffs = 'handcuffs'

-- Durée des actions (ms).
Config.Durations = { cuff = 2500, uncuff = 2000, search = 3000 }

-- Amendes : montant borné, compte débité ('bank' ou 'cash'), délai de réponse de la personne (secondes).
Config.Fines = { min = 50, max = 10000, account = 'bank', timeout = 30 }

-- Bouton panique : délai entre deux alertes d'un même agent et durée du blip (secondes).
Config.Panic = { cooldown = 30, blipTime = 90 }

-- Grade minimum pour supprimer la note d'un collègue (chacun peut supprimer les siennes).
Config.BossGrade = 3

-- Commissariats : point de service, et vestiaire (locker = nil : pas de vestiaire).
Config.Stations = {
    { duty = vec3(441.2, -981.9, 30.69), locker = vec3(452.6, -992.8, 30.69) }, -- Mission Row
}

-- Tenues du vestiaire. label = clé de locale. Composants / accessoires : [id] = { drawable, texture }.
Config.Outfits = {
    {
        label = 'outfit_patrol', grade = 0,
        male   = { components = { [3] = { 0, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 58, 0 }, [11] = { 55, 0 } }, props = {} },
        female = { components = { [3] = { 14, 0 }, [4] = { 34, 0 }, [6] = { 25, 0 }, [8] = { 35, 0 }, [11] = { 48, 0 } }, props = {} },
    },
    {
        label = 'outfit_command', grade = 3,
        male   = { components = { [3] = { 0, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 58, 0 }, [11] = { 55, 0 } }, props = { [0] = { 46, 0 } } },
        female = { components = { [3] = { 14, 0 }, [4] = { 34, 0 }, [6] = { 25, 0 }, [8] = { 35, 0 }, [11] = { 48, 0 } }, props = { [0] = { 45, 0 } } },
    },
}
```
Aucune autre clé. Les distances et limites fixes sont des constantes de `common/police.lua` (§3.1).
Validation au démarrage (serveur, avertissement console en anglais, valeur par défaut appliquée) :
`Config.Fines.min` entier ≥ 1, `max` ≥ `min`, `account` ∈ `bank` | `cash`, `timeout` 10..120 ;
`Config.Theme` ∈ `modern` | `retro80`.

---

## 10. Locales

10 fichiers : `en` (défaut + repli), `fr`, `es`, `de`, `it`, `pt`, `nl`, `pl`, `tr`, `ar` (`_rtl = true`).
Chaque fichier = bloc « Kit commun » de pop_base inchangé + les clés ci-dessous sous `-- Textes propres au script :`.
Les `%s` sont conservés dans toutes les langues (même nombre, même ordre). Les logs console restent en anglais.
`date_locale` = code BCP 47 de la langue (`en-US`, `fr-FR`, `es-ES`, `de-DE`, `it-IT`, `pt-PT`, `nl-NL`, `pl-PL`,
`tr-TR`, `ar`). `money` : format monétaire de la langue.

| Clé | en | fr |
|---|---|---|
| `menu_title` | Police | Police |
| `menu_target` | Nearby: #%s | À proximité : n°%s |
| `menu_no_target` | No one nearby | Personne à proximité |
| `action_cuff` | Handcuff | Menotter |
| `action_uncuff` | Remove handcuffs | Démenotter |
| `action_escort` | Escort | Escorter |
| `action_stop_escort` | Release | Lâcher |
| `action_put_in_vehicle` | Put in vehicle | Mettre dans le véhicule |
| `action_take_out_vehicle` | Take out of vehicle | Sortir du véhicule |
| `action_search` | Search | Fouiller |
| `action_fine` | Issue a fine | Amende |
| `action_mdt` | Records | Casier |
| `action_panic` | Panic button | Bouton panique |
| `action_duty_off` | Go off duty | Fin de service |
| `fine_title` | Issue a fine | Dresser une amende |
| `fine_amount` | Amount | Montant |
| `fine_bounds` | Between %s and %s | Entre %s et %s |
| `fine_reason` | Reason | Motif |
| `fine_send` | Send | Envoyer |
| `fine_request_title` | Fine received | Amende reçue |
| `fine_from` | Officer: %s | Agent : %s |
| `fine_pay` | Pay | Payer |
| `fine_decline` | Refuse | Refuser |
| `money` | $%s | %s $ |
| `mdt_title` | Records | Casier judiciaire |
| `mdt_search_hint` | Name or ID | Nom ou ID |
| `mdt_search` | Search | Rechercher |
| `mdt_no_results` | No results | Aucun résultat |
| `mdt_online` | Online · #%s | En ligne · n°%s |
| `mdt_offline` | Offline | Hors ligne |
| `mdt_unpaid` | Unpaid: %s | Impayé : %s |
| `mdt_notes` | Notes | Notes |
| `mdt_fines` | Fines | Amendes |
| `mdt_note_hint` | Add a note... | Ajouter une note... |
| `mdt_add_note` | Add | Ajouter |
| `mdt_delete` | Delete | Supprimer |
| `mdt_empty` | Nothing on record | Rien au dossier |
| `mdt_back` | Back | Retour |
| `status_paid` | Paid | Payée |
| `status_refused` | Refused | Refusée |
| `status_unpaid` | Unpaid | Impayée |
| `status_expired` | Expired | Expirée |
| `date_locale` | en-US | fr-FR |
| `not_on_duty` | You are not on duty | Vous n'êtes pas en service |
| `duty_on` | You are now on duty | Vous êtes en service |
| `duty_off` | You are now off duty | Vous n'êtes plus en service |
| `cannot_now` | You can't do that right now | Impossible pour le moment |
| `invalid_target` | No valid person nearby | Aucune personne valide à proximité |
| `already_cuffed` | This person is already handcuffed | Cette personne est déjà menottée |
| `not_cuffed` | This person isn't handcuffed | Cette personne n'est pas menottée |
| `target_in_vehicle` | This person is in a vehicle | Cette personne est dans un véhicule |
| `target_not_in_vehicle` | This person isn't in a vehicle | Cette personne n'est pas dans un véhicule |
| `already_escorted` | This person is already being escorted | Cette personne est déjà escortée |
| `no_vehicle` | No vehicle nearby | Aucun véhicule à proximité |
| `vehicle_full` | No free seat in this vehicle | Aucune place libre dans ce véhicule |
| `cannot_search` | Handcuff this person first | Menottez d'abord cette personne |
| `item_handcuffs` | Handcuffs | Menottes |
| `cuffing` | Handcuffing... | Menottage... |
| `uncuffing` | Removing handcuffs... | Retrait des menottes... |
| `searching` | Searching... | Fouille... |
| `cuffed_done` | Person handcuffed | Personne menottée |
| `uncuffed_done` | Handcuffs removed | Menottes retirées |
| `being_cuffed` | Someone is handcuffing you! | On vous passe les menottes ! |
| `you_are_cuffed` | You are handcuffed | Vous êtes menotté |
| `you_are_uncuffed` | Your handcuffs were removed | Vos menottes ont été retirées |
| `being_searched` | You are being searched | Vous êtes fouillé |
| `search_summary` | Found: %s | Trouvé : %s |
| `search_empty` | Nothing found | Rien trouvé |
| `fine_sent` | Fine sent, waiting for an answer | Amende envoyée, en attente de réponse |
| `fine_pending` | This person already has a fine to answer | Cette personne a déjà une amende en attente |
| `invalid_amount` | Invalid amount | Montant invalide |
| `invalid_reason` | Enter a reason (3 to 100 characters) | Indiquez un motif (3 à 100 caractères) |
| `fine_not_found` | This fine is no longer valid | Cette amende n'est plus valable |
| `fine_paid_officer` | Fine of %s paid | Amende de %s payée |
| `fine_refused_officer` | The fine was refused | L'amende a été refusée |
| `fine_unpaid_officer` | Fine accepted but not paid (insufficient funds) | Amende acceptée mais non payée (fonds insuffisants) |
| `fine_expired_officer` | No answer: the fine expired | Pas de réponse : l'amende a expiré |
| `fine_paid_target` | You paid a fine of %s | Vous avez payé une amende de %s |
| `fine_refused_target` | You refused the fine | Vous avez refusé l'amende |
| `fine_unpaid_target` | Not enough money: the fine is recorded as unpaid | Fonds insuffisants : l'amende est enregistrée comme impayée |
| `panic_sent` | Panic alert sent | Alerte panique envoyée |
| `panic_alert` | PANIC: %s needs help! | PANIQUE : %s a besoin d'aide ! |
| `panic_blip` | Officer in distress | Agent en détresse |
| `alert_blip` | Police alert | Alerte police |
| `invalid_query` | Type a name (2+ letters) or an ID | Tapez un nom (2 lettres min.) ou un ID |
| `citizen_not_found` | Person not found | Personne introuvable |
| `invalid_note` | A note must be 3 to 500 characters | Une note doit faire de 3 à 500 caractères |
| `note_not_found` | Note not found | Note introuvable |
| `note_added` | Note added | Note ajoutée |
| `note_deleted` | Note deleted | Note supprimée |
| `target_duty_on` | Go on duty | Prendre son service |
| `target_duty_off` | Go off duty | Terminer son service |
| `target_civilian` | Civilian clothes | Tenue civile |
| `outfit_patrol` | Patrol uniform | Tenue de patrouille |
| `outfit_command` | Command uniform | Tenue de commandement |
| `outfit_changed` | Outfit changed | Tenue changée |
| `outfit_unavailable` | No outfit for this character model | Aucune tenue pour ce modèle de personnage |
| `no_saved_outfit` | No civilian outfit saved | Aucune tenue civile enregistrée |
| `keymap_menu` | Police menu | Menu police |
| `keymap_panic` | Police panic button | Bouton panique police |
| `keymap_accept` | Pay a fine | Payer une amende |
| `keymap_decline` | Refuse a fine | Refuser une amende |

Clés de base réutilisées : `cancel`, `close`, `no_permission`, `wrong_job`, `too_far`, `not_enough_money`,
`missing_item`, `cooldown`, `busy`, `error`, `progress_cancelled`.
`fine_paid_officer` / `fine_paid_target` reçoivent le montant déjà formaté : `L('money', amount)`.
`search_summary` reçoit une chaîne `"2x bread, 1x lockpick"` (noms d'items bruts, au plus 10 piles, puis `…`).

---

## 11. Comportement Serveur

### 11.1 Fonctions et tables partagées (`Police.*`, serveur)
| Fonction | Fichier | Retour | Rôle |
|---|---|---|---|
| `Police.IsOfficer(src)` | main | bool | standalone : `IsPlayerAceAllowed(src, 'pop.police')` ; sinon `Bridge.HasJob(src, Config.Jobs)` |
| `Police.IsOnDuty(src)` | main | bool | `IsOfficer` **et** : QBCore / Qbox → `Bridge.GetJob(src).onDuty == true` ; ESX / standalone → `duty[src] == true` |
| `Police.RefreshDuty(src)` | main | bool | calcule `IsOnDuty` et met le statebag `popPoliceDuty` à `true` / `nil` s'il diffère ; renvoie la valeur |
| `Police.CheckOfficer(src)` | main | `ok, reason` | `IsOfficer` (→ `wrong_job`), `IsOnDuty` (→ `not_on_duty`), vivant (`not Bridge.IsDead(src)`) et non menotté (→ `cannot_now`) ; appelle `RefreshDuty` |
| `Police.CheckTarget(src, target, skipDistance?)` | main | `ok, reason, targetPed` | `math.type(target) == 'integer'`, `target ~= src`, `GetPlayerName(target)` et `Bridge.GetPlayer(target)` non nil (→ `invalid_target`) ; sauf `skipDistance` : `Bridge.IsNear(src, Bridge.GetCoords(target), Police.ACTION_DISTANCE)` (→ `too_far`) |
| `Police.OnFoot(src)` | main | bool | `GetVehiclePedIsIn(GetPlayerPed(src), false) == 0` |
| `Police.Lock(src)` / `Police.Unlock(src)` | main | bool / — | verrou `Police.busy[src]` (refus → `busy`) ; **toujours** libéré (traitement dans un `pcall`) |
| `Police.Cooldown(src)` | main | bool | `GetGameTimer() - (lastAction[src] or 0) >= Police.ACTION_COOLDOWN`, puis met à jour (refus → `busy`) |
| `Police.SetCuffed(target, state, officer?)` | main | bool | écrit `Police.cuffed[target]`, statebags `cuffed` (`true`/`nil`) et `invBusy` (`true`/`false`), métadonnée QB/Qbox `ishandcuffed` (`pcall`) ; `false` → `Police.ReleaseTarget(target)` ; `TriggerEvent('pop_police:cuffChanged', target, state, officer)` |
| `Police.SetEscort(officer, target)` | main | — | `target = nil` → libère l'escorte de `officer` ; met à jour `Police.escorts[officer]`, `Police.escortedBy[target]` et le statebag `popEscortedBy` de la cible |
| `Police.ReleaseTarget(target)` | main | — | si `Police.escortedBy[target]` → `Police.SetEscort(Police.escortedBy[target], nil)` |
| `Police.GetOfficers()` | main | `{ src, ... }` | `Bridge.GetPlayers()` filtrés par `IsOnDuty` |
| `Police.GetCitizenId(identifier, name)` | mdt | int \| nil | bloquant (§8) ; attend `ready` |

Tables partagées (créées dans `main.lua`) : `Police.cuffed[src] = true`, `Police.escorts[officer] = target`,
`Police.escortedBy[target] = officer`, `Police.busy[src] = true`. Locales à `main.lua` : `duty[src]`, `lastAction[src]`,
`lastPanic[src]`. Locale à `actions.lua` : `cuffing[src]`.

**Squelette commun d'une action** (`actions.lua`, `fines.lua`) : `CheckOfficer` → `Cooldown` (sauf exceptions
indiquées) → `Lock` → `pcall(traitement)` → `Unlock` → retour du traitement (erreur Lua → `false, 'error'`).

### 11.2 `server/main.lua`
- **Validation de la config** au démarrage (§9).
- **Garde des statebags** : `AddStateBagChangeHandler(key, nil, fn(bagName, _, value))` pour `cuffed`, `popEscortedBy`,
  `popPoliceDuty`. `src = GetPlayerFromStateBagName(bagName)` (0 → ignorer). Si `value` diffère de la référence
  serveur (`Police.cuffed[src]`, `Police.escortedBy[src]`, état de service ; `nil` et `false` équivalents) → rétablir
  la référence (`SetTimeout(0, …)` pour ne pas écrire pendant le handler). `-- NOTE:` un client peut écrire ses propres
  statebags répliqués : c'est ce garde qui fait foi.
- **`pop_police:getState`** : `{ officer = IsOfficer, onDuty = RefreshDuty, grade = (Bridge.GetJob(src) or {}).grade or 0 }`.
  Si le joueur n'est plus en service : libère l'escorte qu'il donne.
- **`pop_police:setDuty(state, station)`** : `state` booléen (sinon `error`) ; `IsOfficer` (→ `wrong_job`) ;
  - `true` : `station` entier valide dans `Config.Stations` (→ `error`) et `Bridge.IsNear(src, station.duty,
    Police.STATION_DISTANCE + 1.0)` (→ `too_far`) ;
  - écriture : QBCore / Qbox → `Bridge.GetPlayer(src).Functions.SetJobDuty(state)` puis
    `TriggerClientEvent('QBCore:Client:SetDuty', src, state)` (dans un `pcall`, `-- NOTE:` Qbox à vérifier) ;
    ESX / standalone → `duty[src] = state or nil` ;
  - `false` : libère l'escorte qu'il donne ;
  - `RefreshDuty`, `TriggerEvent('pop_police:dutyChanged', src, state)`, notification `duty_on` / `duty_off` (success).
- **`pop_police:panic`** : `CheckOfficer` ; délai `Config.Panic.cooldown` par agent (`lastPanic[src]`, `os.time()`)
  → `cooldown`, arg = secondes restantes ; `coords = Bridge.GetCoords(src)` (position **serveur**) ;
  `pop_police:client:panic` `{ coords = { x, y, z }, name = Bridge.GetName(src) or ('#' .. src) }` à chaque agent de
  `Police.GetOfficers()` (lui compris) ; `TriggerEvent('pop_police:panic', src, coords)` ; notification `panic_sent`.
- **Exports** §7.1.
- **Chargement joueur** : `Bridge.OnPlayerLoaded(src)` → `duty[src] = nil` puis `RefreshDuty(src)`.

### 11.3 `server/actions.lua`
Toutes : squelette §11.1, `CheckTarget`, et agent à pied (`Police.OnFoot(src)`, sinon `cannot_now`).
- **`cuff(target, phase)`** : `phase` ∈ `'start'`, `'finish'` (sinon `error`).
  - `start` : cible non menottée (`already_cuffed`) ; cible à pied (`target_in_vehicle`) ; si `Config.Handcuffs` :
    `Bridge.HasItem(src, Config.Handcuffs)` (→ `missing_item`, arg `L('item_handcuffs')`) ;
    `cuffing[src] = { target = target, t = GetGameTimer() }` ; `pop_police:client:beingCuffed` à la cible ; `true`.
  - `finish` (exempté de `Police.Cooldown`, il suit forcément `start`) : `cuffing[src]` existe et même `target` ;
    `elapsed = GetGameTimer() - t`, `Config.Durations.cuff - 500 <= elapsed <= Config.Durations.cuff + 5000` (sinon
    `error`) ; `cuffing[src] = nil` **avant** les contrôles suivants ; cible toujours non menottée et à pied ; distance
    revérifiée par `CheckTarget` (→ `too_far` : la cible s'est enfuie) ; item revérifié ;
    `Police.SetCuffed(target, true, src)` ; notifications `cuffed_done` (agent, success) et `you_are_cuffed` (cible, error).
- **`uncuff(target)`** : cible menottée (`not_cuffed`) ; `Police.SetCuffed(target, false, src)` ; notifications
  `uncuffed_done` / `you_are_uncuffed` (success). Aucun item rendu ni demandé.
- **`escort(target, state)`** : `state` booléen (sinon `error`).
  - `true` : cible menottée (`not_cuffed`), à pied (`target_in_vehicle`), pas déjà escortée (`already_escorted`),
    l'agent n'escorte personne (`busy`) → `Police.SetEscort(src, target)`.
  - `false` : `CheckTarget(src, target, true)` (sans distance) ; `Police.escorts[src] == target` (sinon `error`) →
    `Police.SetEscort(src, nil)`. Exempté de `Police.Cooldown` et de l'exigence « à pied ».
- **`putInVehicle(target, netId)`** : cible menottée (`not_cuffed`) ; cible à pied (`target_in_vehicle`) ;
  `math.type(netId) == 'integer'`, `veh = NetworkGetEntityFromNetworkId(netId)`, `DoesEntityExist(veh)`,
  `GetEntityType(veh) == 2` (→ `no_vehicle`) ; véhicule à `Police.VEHICLE_SERVER_DISTANCE` de l'agent **et** de la cible
  (→ `too_far`) ; `Police.ReleaseTarget(target)` ; `ok = Callback.Await('pop_police:enterVehicle', target, netId)`
  **verrou conservé pendant l'attente** (≤ 10 s) ; `ok ~= true` → `vehicle_full`. `-- NOTE:` le placement est fait par
  le client de la cible (natives de sièges client uniquement).
- **`takeOutVehicle(target)`** : `CheckTarget(src, target, true)` ; cible menottée (`not_cuffed`) ;
  `veh = GetVehiclePedIsIn(targetPed, false)` ≠ 0 (→ `target_not_in_vehicle`) ; véhicule à
  `Police.VEHICLE_SERVER_DISTANCE` de l'agent (→ `too_far`) ; `pop_police:client:leaveVehicle` à la cible.
- **`search(target)`** : cible menottée **ou** `Bridge.IsDead(target)` (→ `cannot_search`) ; selon `Bridge.Inventory`
  (dans un `pcall`, échec → repli) :
  - `pop_inventory` → `exports.pop_inventory:forceOpenInventory(src, 'player', target)` ;
  - `ox_inventory` → `exports.ox_inventory:forceOpenInventory(src, 'player', target)` ;
  - `qb-inventory` → `exports['qb-inventory']:OpenInventoryById(src, target)` (`-- NOTE:` v2 seulement) ;
  - autres (qs-inventory, ps-inventory, framework, none) ou échec → **repli** : `Bridge.GetItems(target)` →
    `Bridge.Notify(src, L('search_summary', liste), 'info', 10000)` ou `L('search_empty')`.
  Puis `Bridge.Notify(target, L('being_searched'), 'warning')`.

### 11.4 `server/fines.lua`
- **`fine(target, amount, reason)`** : squelette §11.1, `CheckTarget` ; `math.type(amount) == 'integer'` et
  `Config.Fines.min <= amount <= Config.Fines.max` (→ `invalid_amount`) ; `reason` chaîne, caractères de contrôle
  retirés (`%c`), espaces aux extrémités retirés, longueur (`utf8.len`, repli `#`) entre `Police.REASON_MIN` et
  `Police.REASON_MAX` (→ `invalid_reason`) ; pas d'amende en attente pour la cible (→ `fine_pending`) ; délai
  `Police.FINE_COOLDOWN` par agent (→ `cooldown`, arg secondes restantes) ; identifiants `Bridge.GetIdentifier` des deux
  non nil (→ `error`). Crée `fines[id]` (§3.3, noms par `Bridge.GetName`), `pendingByTarget[target] = id`, envoie
  `pop_police:client:fineRequest` `{ id, amount, reason, officer = officerName }` à la cible,
  `SetTimeout(Config.Fines.timeout * 1000, function() expire(id) end)`, notification `fine_sent` à l'agent.
- **`expire(id)`** : si toujours en attente → retirée (`fines`, `pendingByTarget`), enregistrée `expired`,
  `pop_police:client:fineClosed(id)` à la cible (si en ligne), `fine_expired_officer` à l'agent (si en ligne).
- **`respondFine(id, accept)`** (pas d'officier requis : c'est la cible qui répond) : `math.type(id) == 'integer'`,
  `fines[id]` existe et `fines[id].target == src` (→ `fine_not_found`) ; `accept` booléen (sinon `error`).
  **Retirer l'amende de la mémoire avant** tout paiement (anti double réponse). Puis :
  - `accept` et `Bridge.RemoveMoney(src, Config.Fines.account, amount, 'pop_police_fine')` → `paid` :
    `fine_paid_target` (cible, success), `fine_paid_officer` (agent, success),
    `TriggerEvent('pop_police:finePaid', src, officer, amount, reason)` ;
  - `accept` mais paiement refusé → `unpaid` : `fine_unpaid_target` (error), `fine_unpaid_officer` (warning) ;
  - refus → `refused` : `fine_refused_target` (info), `fine_refused_officer` (warning).
  Agent notifié seulement s'il est en ligne. Enregistrement (thread) : `citizenId =
  Police.GetCitizenId(targetIdentifier, targetName)` puis `INSERT INTO pop_police_fines`. Retour `true, nil, status`.
- **Nettoyage** (`OnPlayerDropped` / `OnPlayerUnloaded`) : amende en attente **visant** ce joueur → enregistrée
  `expired`, agent prévenu ; les amendes **données** par ce joueur restent valables (nom et identifiant déjà copiés).
  Délais `lastFine[src]` effacés.

### 11.5 `server/mdt.lua`
- **Démarrage** : thread → les 3 `CREATE TABLE IF NOT EXISTS` (§8) → `ready = true`. Chaque callback MDT attend
  `ready` (`Wait(100)`, au plus 10 s, sinon `error`). Tous exigent `CheckOfficer` (pas de `Police.Cooldown` : l'anti-spam
  du template suffit ; `Lock` pour les écritures).
- **`mdtSearch(query)`** : chaîne, contrôles retirés, `trim`, longueur ≤ `Police.QUERY_MAX` ; si
  `math.tointeger(tonumber(query))` → joueur en ligne de cet ID uniquement ; sinon longueur ≥ 2 (→ `invalid_query`).
  Résultats : (1) joueurs en ligne de `Bridge.GetPlayers()` dont `Bridge.GetName` contient la requête (insensible à la
  casse, `string.find(nom:lower(), query:lower(), 1, true)`) ; (2) `SELECT id, name, identifier FROM
  pop_police_citizens WHERE name LIKE ? ORDER BY name LIMIT ?` ; fusion par identifiant (une personne en ligne **et**
  en base = une seule ligne avec les deux ids) ; tri par nom ; au plus `Police.RESULTS_MAX`. L'identifiant ne sort
  **jamais** du serveur.
- **`mdtProfile(ref)`** : `ref` table avec exactement un entier `citizenId` ou `serverId` (→ `error`).
  `serverId` : joueur en ligne et chargé, identifiant non nil (→ `citizen_not_found`) → `Police.GetCitizenId(identifier,
  Bridge.GetName(serverId))`. `citizenId` : ligne existante (→ `citizen_not_found`). Construit `profile` (§5.3) :
  `online` / `serverId` en cherchant l'identifiant parmi les joueurs en ligne ; `canDelete` = `author_identifier ==
  identifiant de src` ou `grade >= Config.BossGrade` ou `Bridge.IsAdmin(src)`.
- **`mdtAddNote(citizenId, text)`** : `citizenId` entier existant (→ `citizen_not_found`) ; texte nettoyé comme un motif,
  longueur `Police.NOTE_MIN`..`Police.NOTE_MAX` (→ `invalid_note`) ; `Lock` ; `INSERT` (auteur = `Bridge.GetName(src)`,
  identifiant de `src`, `os.time()`) ; notification `note_added` ; renvoie le profil à jour.
- **`mdtDeleteNote(noteId)`** : entier, note existante (→ `note_not_found`) ; même règle que `canDelete`
  (→ `no_permission`) ; `Lock` ; `DELETE` ; notification `note_deleted` ; renvoie le profil de la personne concernée.

### 11.6 Nettoyage (`Bridge.OnPlayerUnloaded` et `Bridge.OnPlayerDropped`, dans chaque fichier pour ses tables)
- `main.lua` : unload → si menotté `Police.SetCuffed(src, false)`, statebag de service retiré ; drop → seulement les
  tables. Dans les deux cas : escorte donnée **et** subie libérée (`Police.SetEscort(src, nil)`,
  `Police.ReleaseTarget(src)`), `Police.cuffed[src]`, `duty[src]`, `Police.busy[src]`, `lastAction[src]`,
  `lastPanic[src]` effacés.
- `actions.lua` : `cuffing[src]` effacé, et toute entrée `cuffing[*].target == src`.
- `fines.lua` : §11.4. `mdt.lua` : rien.
- `onResourceStop` (cette ressource) : pour chaque joueur concerné, statebags `cuffed`, `popEscortedBy`, `popPoliceDuty`
  remis à `nil` et `invBusy = false` (la ressource ne doit laisser personne bloqué).

---

## 12. Comportement Client

### 12.1 État local (`client/main.lua`)
```lua
Police.state = { officer = false, onDuty = false, grade = 0 }
Police.uiOpen = false      -- menu / formulaire / casier ouvert (focus pris)
Police.menuActions = {}    -- derniers ids envoyés à la NUI (set)
Police.menuTarget = nil    -- server id de la cible au moment de l'ouverture
Police.escorting = nil     -- server id escorté par moi (écrit par client/actions.lua)
```
- `Police.RefreshState()` : `Callback.Await('pop_police:getState')` → `Police.state` ; si plus officier ou plus en
  service → `Police.CloseUi()`. Appelée par `Bridge.OnPlayerLoaded` et `Bridge.OnJobUpdate`. Le handler du statebag
  `popPoliceDuty` sur soi met `Police.state.onDuty` à jour sans appel serveur.
- **Touches** : `RegisterCommand('pop_police_menu', …)` + `RegisterKeyMapping('pop_police_menu', L('keymap_menu'),
  'keyboard', Config.KeyMappings.menu)` ; idem `pop_police_panic` (`keymap_panic`, `.panic`),
  `pop_police_accept` (`keymap_accept`, `.acceptFine`), `pop_police_decline` (`keymap_decline`, `.declineFine`) —
  ces deux dernières sont enregistrées dans `effects.lua` et ne font rien sans amende affichée.
  Menu et panique : **rien** (aucun message) si pas officier ; `not_on_duty` si officier hors service.

### 12.2 Menu (`client/main.lua`)
- Ouverture refusée (sans message) si mort, menotté, `Bridge.IsBusy()`, menu pause. Interface déjà ouverte → fermer.
- `target = Police.GetTarget()` (§12.3), `Police.menuTarget = target`. Actions, **dans cet ordre**, avec `c` = cible
  menottée (`Player(target).state.cuffed == true`), `v` = cible en véhicule :

  | id | condition |
  |---|---|
  | `cuff` | cible, non `c`, non `v` |
  | `uncuff` | cible et `c` |
  | `escort` | cible, `c`, non `v`, `Police.escorting == nil`, `Player(target).state.popEscortedBy == nil` |
  | `stop_escort` | `Police.escorting ~= nil` (même sans cible proche) |
  | `put_in_vehicle` | cible, `c`, non `v`, véhicule à `Police.VEHICLE_DISTANCE` |
  | `take_out_vehicle` | cible, `c`, `v` |
  | `search` | cible et (`c` ou `IsEntityDead(ped de la cible)`) |
  | `fine` | cible |
  | `mdt`, `panic`, `duty_off` | toujours |

  `Police.menuActions` = ces ids ; `SendNUIMessage(pop_police:menu)` ; `SetNuiFocus(true, true)` ; `Police.uiOpen = true`.
- **`Police.CloseUi()`** (Bridge.OnUiClose, action exécutée, amende envoyée, perte du service, menotté, mort) :
  `SetNuiFocus(false, false)`, `pop_police:close`, `Police.uiOpen = false`, `Police.menuActions = {}`.
  Pendant que l'interface est ouverte : **aucune** boucle (le focus NUI suffit).

### 12.3 Actions de l'agent (`client/actions.lua`)
- `Police.GetTarget()` : parmi `GetActivePlayers()` (sauf soi), ped à moins de `Police.TARGET_DISTANCE` (distance entre
  peds ; un ped en véhicule compte jusqu'à `Police.TARGET_DISTANCE + 1.5`), le plus proche →
  `GetPlayerServerId(player)` ou `nil`.
- `Police.GetVehicle()` : véhicule de `GetGamePool('CVehicle')` le plus proche à `Police.VEHICLE_DISTANCE`, réseau
  (`NetworkGetEntityIsNetworked`) → `veh, VehToNet(veh)` ou `nil`.
- `Police.RunAction(id)` (appelée par le callback NUI `action`, dans un thread) : `Bridge.IsBusy()` → `busy` ; pour les
  actions avec cible, `t = Police.menuTarget` encore à moins de `Police.TARGET_DISTANCE + 1.5` (→ `too_far`).
- Déroulés (barres : `Bridge.Progress(label, durée, { anim = … })` ; `false` → arrêt, le bridge a notifié) :

  | id | Déroulé |
  |---|---|
  | `cuff` | `pop_police:cuff(t, 'start')` → si ok : `TaskTurnPedToFaceEntity` (500 ms), barre `Config.Durations.cuff`, `L('cuffing')`, anim `mp_arresting` / `a_uncuff` flag 49 → `pop_police:cuff(t, 'finish')` |
  | `uncuff` | barre `Config.Durations.uncuff`, `L('uncuffing')`, même anim → `pop_police:uncuff(t)` |
  | `escort` | `pop_police:escort(t, true)` → ok : `Police.escorting = t`, démarre la boucle d'escorte |
  | `stop_escort` | `pop_police:escort(Police.escorting, false)` → dans tous les cas `Police.escorting = nil` |
  | `put_in_vehicle` | `Police.GetVehicle()` (aucun → `no_vehicle`) → `pop_police:putInVehicle(t, netId)` → ok et `Police.escorting == t` : `Police.escorting = nil` |
  | `take_out_vehicle` | `pop_police:takeOutVehicle(t)` |
  | `search` | barre `Config.Durations.search`, `L('searching')`, anim `anim@gangops@facility@servers@bodysearch@` / `player_search` flag 49 → `pop_police:search(t)` |
  | `panic` | `pop_police:panic()` |
  | `duty_off` | `pop_police:setDuty(false)` |

  Échec d'un callback : `Bridge.Notify(L(reason or 'error', arg), 'error')`.
- **Commande panique** (`pop_police_panic`) : mêmes conditions que le menu (officier, en service, vivant) →
  `pop_police:panic()`.
- **Boucle d'escorte (agent)** : seulement tant que `Police.escorting ~= nil`, `Wait(500)` : si l'agent est mort, entre
  dans un véhicule, ou si `Player(escorting).state.popEscortedBy ~= GetPlayerServerId(PlayerId())` →
  `pop_police:escort(escorting, false)` (échec ignoré) et `Police.escorting = nil`.

### 12.4 Effets sur soi (`client/effects.lua`)
- Handlers de statebag sur **soi** (`cuffed`, `popEscortedBy`), plus lecture initiale de `LocalPlayer.state` au
  chargement et au démarrage de la ressource.
- **Menotté** (`cuffed == true`) : `Police.CloseUi()`, `SetEnableHandcuffs(ped, true)`,
  `SetCurrentPedWeapon(ped, \`WEAPON_UNARMED\`, true)`, anim `mp_arresting` / `idle` flag 49. Une boucle
  **seulement tant que menotté** : chaque frame `DisablePlayerFiring(PlayerId(), true)` et `DisableControlAction(0, c,
  true)` pour `21, 22, 23, 24, 25, 37, 44, 45, 47, 58, 75, 140, 141, 142, 143, 257, 263, 264` ; toutes les 1000 ms :
  rejoue l'anim si `IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3)` est faux et que le ped n'est pas mort,
  remet `WEAPON_UNARMED`. Fin (`nil`) : `ClearPedSecondaryTask(ped)`, `SetEnableHandcuffs(ped, false)`,
  `RemoveAnimDict('mp_arresting')`. Notifications envoyées par le serveur (pas ici).
- **Escorté** (`popEscortedBy = id`) : boucle `Wait(500)` **seulement pendant l'escorte** :
  `officerPed = GetPlayerPed(GetPlayerFromServerId(id))` ; si le joueur est connu (`GetPlayerFromServerId ~= -1`), son
  ped existe et n'est pas en véhicule, et que je ne suis pas en véhicule → si pas encore attaché :
  `AttachEntityToEntity(ped, officerPed, 11816, Police.ESCORT_OFFSET.x, Police.ESCORT_OFFSET.y, Police.ESCORT_OFFSET.z,
  0.0, 0.0, 0.0, false, false, false, false, 2, true)` ; sinon → `DetachEntity(ped, true, false)`. Fin (`nil`) : `DetachEntity`.
- **`pop_police:enterVehicle(netId)`** (callback S→C) : `veh = NetToVeh(netId)` ; inexistant → `false`. Détache si
  attaché. Sièges essayés dans l'ordre `1, 2, 0` : siège `< GetVehicleMaxNumberOfPassengers(veh)` et
  `IsVehicleSeatFree(veh, seat)` → `TaskWarpPedIntoVehicle(ped, veh, seat)`, renvoie `true`. Aucun → `false`.
- **`pop_police:client:leaveVehicle`** : `TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)` ; l'anim de menottes
  est rejouée par la boucle.
- **Carte d'amende** : `fineRequest` → `pendingFine = data`, message `pop_police:fineRequest` (`show = true`, §6.1).
  `pop_police_accept` / `pop_police_decline` : si `pendingFine` → `Callback.Await('pop_police:respondFine',
  pendingFine.id, true|false)` ; **dans tous les cas** masquer la carte et `pendingFine = nil` (le serveur notifie le
  résultat). Échec (`fine_not_found`…) → notification. `fineClosed(id)` du même id → masquer. Minuterie locale de
  sécurité : masquer après `Config.Fines.timeout + 2` s.

### 12.5 Points de commissariat et vestiaire (`client/main.lua`)
- Une fois au chargement, pour chaque `Config.Stations[i]` (pour tous les joueurs ; `canInteract` filtre) :
  - `Bridge.Target.AddBoxZone('pop_police_duty_' .. i, duty, vec3(1.2, 1.2, 2.0), 0.0, options)` :
    `L('target_duty_on')` (`canInteract` : officier et hors service) → `pop_police:setDuty(true, i)` ;
    `L('target_duty_off')` (officier et en service) → `pop_police:setDuty(false)`. Icône `fa-solid fa-id-badge`,
    `distance = Police.STATION_DISTANCE`.
  - si `locker` : `Bridge.Target.AddBoxZone('pop_police_locker_' .. i, locker, vec3(1.2, 1.2, 2.0), 0.0, options)` :
    une option par tenue (`L(outfit.label)`, `canInteract` : en service et `Police.state.grade >= outfit.grade`) +
    `L('target_civilian')` (en service). Icône `fa-solid fa-shirt`, même distance.
- **Tenue** (immédiate, sans barre) : modèle `mp_m_freemode_01` → `male`, `mp_f_freemode_01` → `female`, autre →
  `outfit_unavailable`. Avant la **première** tenue (si `civilian == nil`) : sauvegarde des composants 0..11
  (drawable, texture, palette) et des accessoires 0, 1, 2, 6, 7 (index, texture ; -1 = aucun). Application :
  `SetPedComponentVariation(ped, id, d, t, 0)` et `SetPedPropIndex(ped, id, d, t, true)` (d = -1 → `ClearPedProp`).
  Notification `outfit_changed`. Tenue civile : restaure la sauvegarde puis `civilian = nil` ; aucune sauvegarde →
  `no_saved_outfit`.

### 12.6 Panique et alertes (`client/main.lua`)
- `pop_police:client:panic` : `Bridge.Notify(L('panic_alert', data.name), 'error', 10000)`,
  `PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)`, blip `AddBlipForCoord` (sprite 161,
  couleur 1, échelle 1.2, `PulseBlip`, nom `L('panic_blip')`, pas de courte portée), `SetNewWaypoint(x, y)` ; blip
  supprimé après `Config.Panic.blipTime` s.
- `pop_police:client:alert` : `Bridge.Notify(data.text, 'warning', 8000)`, blip (sprite 161, couleur 3, échelle 1.0,
  nom `L('alert_blip')`) supprimé après `Config.Panic.blipTime` s.
- **Arrêt de la ressource** : blips supprimés, interface fermée, détaché, menottes visuelles retirées
  (`ClearPedSecondaryTask`, `SetEnableHandcuffs(false)`), carte masquée.

---

## 13. Règles de sécurité (serveur, toutes obligatoires)

Le client n'envoie que : un **server id** de cible, un **netId**, un **index** de commissariat, un **montant** et un
**motif** (bornés et nettoyés), une **requête** / un **texte** de note, des **ids** entiers, des booléens. Jamais de
coordonnées, d'identifiant, de nom, de prix ni d'état : tout est relu côté serveur.

**Commun à toutes les actions de police**
1. `Police.CheckOfficer` : job (ou ACE en standalone) **et** service relus à chaque appel ; agent vivant et non menotté.
2. `Police.CheckTarget` : cible entière, ≠ soi, en ligne et chargée ; distance mesurée sur les **positions serveur**
   (`Bridge.IsNear` + `Bridge.GetCoords(target)`), `Police.ACTION_DISTANCE`.
3. Anti-spam : `Config.CallbackRateLimit` (template) + `Police.ACTION_COOLDOWN` par agent + verrou `Police.busy[src]`
   (toujours libéré) + `Police.FINE_COOLDOWN` + `Config.Panic.cooldown`.
4. États de référence en mémoire serveur (`Police.cuffed`, `Police.escorts`, `Police.escortedBy`, service). Les
   statebags en sont une copie : écrits **uniquement** par le serveur, rétablis par le garde (§11.2) si un client les
   modifie.
5. Aucun texte reçu n'est diffusé à d'autres joueurs sans nettoyage (contrôles retirés, longueur bornée) : motif
   d'amende (vers la cible), notes (vers les agents). La NUI insère tout en `textContent`.

**Menottes** : deux temps, `finish` borné dans le temps (`cuff - 500` à `cuff + 5000` ms après `start`), distance et
item revérifiés à `finish` (la cible peut fuir). Pas sur une cible en véhicule.
**Escorte / véhicule** : cible menottée obligatoire ; véhicule réel (`GetEntityType == 2`) près de l'agent **et** de la
cible ; une seule escorte par agent et par cible.
**Fouille** : cible menottée ou morte ; ouverture forcée seulement après ces contrôles ; le repli ne renvoie que des
noms et quantités.
**Amendes** : montant entier dans `Config.Fines` (jamais de montant non borné), motif nettoyé, une seule amende en
attente par cible, seule la cible peut répondre, amende retirée **avant** le paiement (pas de double paiement),
paiement uniquement par `Bridge.RemoveMoney` (qui vérifie le solde), compte lu dans la config.
**Casier** : agents en service uniquement ; requêtes SQL paramétrées, `LIKE` échappé, résultats bornés ; aucun
identifiant de joueur envoyé au client (seulement `citizenId` interne et server id) ; suppression de note : auteur,
`Config.BossGrade` ou admin.
**Service** : prise de service seulement près d'un point `Config.Stations` (position serveur) ; fin de service partout.
**Exports** : appelés par du code serveur de confiance, entrées quand même validées (`SetCuffed` : joueur en ligne ;
`Alert` : coordonnées finies, texte tronqué).
**Données diffusées** : panique et alerte vont **uniquement** aux agents en service ; le nom d'un agent n'est envoyé
qu'aux agents (panique) et à la personne verbalisée (carte d'amende).

---

## 14. Checklist de livraison (auditeur)
- `luacheck resources templates` : 0 erreur ; `node --check web/script.js`.
- `bridge/`, `shared/`, `web/kit/` identiques octet pour octet à `templates/pop_base`.
- 10 locales avec **toutes** les clés (base + §10) ; aucun texte en dur (Lua, HTML, JS) ; arabe en RTL.
- Repos : aucune boucle propre au script ; `Wait(0)` seulement menotté et dans `Bridge.Progress` ; < 0.02 ms.
- Fonctionne en ESX (Legacy et ancien), QBCore, Qbox, standalone (ACE `pop.police`) ; ox_target, qb-target et prompt ;
  fouille avec pop_inventory, ox_inventory, qb-inventory v2, et repli notification ailleurs.
- Un client modifié ne peut pas : menotter à distance ou sans item, finir un menottage instantanément, se démenotter
  en écrivant son statebag, verbaliser d'un montant hors bornes, payer deux fois, répondre à l'amende d'un autre, lire
  le casier hors service, supprimer la note d'un collègue sans grade, prendre son service loin d'un commissariat.
- Thème `retro80` : mêmes éléments, seul le CSS change ; aucun dégradé ni lueur.
- `README.md` en anglais : ordre `ensure` (oxmysql, framework, inventaire avant `[pop]`), ACE standalone
  (`add_ace group.police pop.police allow`), item `handcuffs` par inventaire, events §4.3, exports §7, limites
  (menottes perdues à la reconnexion, amende impayée seulement enregistrée, standalone = amendes toujours impayées
  faute d'argent, qs-inventory / ps-inventory / inventaire du framework = fouille en notification).
