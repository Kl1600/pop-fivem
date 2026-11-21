# pop_crew : SPEC (contrat commun)

Crews / gangs créés par les joueurs. Sobre, simple, ~0.00 ms au repos, ESX / QBCore / Qbox / standalone, 10 langues.
Base de pop_territories (contrat d'exports imposé, section 6 : ne pas renommer).

Ce fichier est la référence unique : noms d'events, callbacks, messages NUI, clés de config et de locales
doivent être recopiés **à l'identique**. Toute ambiguïté se tranche dans le sens « le serveur décide ».

---

## 1. Description et fonctionnalités

| # | Fonction | Qui | Résumé |
|---|---|---|---|
| F1 | Créer un crew | joueur sans crew | Nom (3 à 20 caractères, unique, insensible à la casse) + couleur choisie dans une palette. Coût `Config.CreateCost` prélevé sur `Config.CreateAccount`. Le créateur devient rang 1 (chef). |
| F2 | Inviter un joueur proche | permission `invite` | Le panneau liste les joueurs à moins de `Config.InviteDistance` m (calcul **serveur**), affichés par ID serveur + distance (pas de nom : pas de métagaming). L'invité reçoit une notification et répond dans son panneau. Expire après `Config.InviteTimeout` s. |
| F3 | Répondre à une invitation | invité | Accepter (rejoint au dernier rang) ou refuser. |
| F4 | Quitter | membre (hors chef) | Le chef ne peut pas quitter s'il reste d'autres membres (il doit nommer un autre chef) ; s'il est seul, quitter = dissoudre. |
| F5 | Exclure | permission `kick` | Uniquement un membre de rang inférieur (numéro plus grand). Fonctionne aussi sur un membre hors ligne. |
| F6 | Promouvoir / rétrograder | permission `manage` | Change le rang d'un membre de rang inférieur, vers un rang toujours inférieur au sien. Le chef peut nommer un membre chef : transfert (l'ancien chef passe rang 2). |
| F7 | Dissoudre | chef (rang 1) uniquement | Double confirmation dans l'interface. Supprime le crew et tous ses membres. |
| F8 | Panneau latéral | tous | Commande `/crew` + touche (`Config.Key`, modifiable par le joueur dans Paramètres > Raccourcis FiveM). Nom + couleur du crew, mon rang, membres en ligne / hors ligne, actions selon le rang. |
| F9 | Repère au-dessus des membres | option `Config.ShowTags = false` | Petit marqueur à la couleur du crew au-dessus des membres proches (désactivé par défaut). |

Rangs : liste ordonnée `Config.Ranks`, **index 1 = chef** (rang le plus haut), dernier index = nouveau membre.
Un crew a toujours exactement un membre de rang 1. Le rang 1 a toutes les permissions quelle que soit la config,
plus `disband` et le transfert de chef.

Hors périmètre (volontairement) : changement de nom/couleur après création, coffre, argent du crew, chat, blips.

Standalone : pas d'argent → la création est **gratuite** (`Config.CreateCost` ignoré si `Bridge.Framework == 'standalone'`).

---

## 2. Arborescence et répartition

Partir d'une copie de `templates/pop_base` (`cp -r templates/pop_base "resources/[pop]/pop_crew"`, puis supprimer
`README.md`, `client/main.lua`, `server/main.lua`, `web/script.js` du template avant de réécrire).
Les fichiers marqués **copie** sont repris tels quels depuis `templates/pop_base` et **ne sont jamais modifiés ici**.

```
resources/[pop]/pop_crew/
  SPEC.md                 architecte (ce fichier)
  fxmanifest.lua          SERVEUR   (contenu imposé §2.1)
  config.lua              SERVEUR   (contenu imposé §8)
  README.md               SERVEUR   (installation, config, exports, SQL)
  bridge/
    server.lua            SERVEUR   copie de templates/pop_base/bridge/server.lua
    client.lua            CLIENT    copie de templates/pop_base/bridge/client.lua
  shared/
    callback.lua          SERVEUR   copie de templates/pop_base/shared/callback.lua
    locale.lua            SERVEUR   copie de templates/pop_base/shared/locale.lua
  locales/
    en.lua fr.lua es.lua de.lua it.lua pt.lua nl.lua pl.lua tr.lua ar.lua
                          SERVEUR   copie des 10 fichiers du template (clés communes intactes)
                                    + clés du script §9 sous « -- Textes propres au script : »
  server/
    main.lua              SERVEUR   cache, SQL, callbacks, events, exports
  client/
    main.lua              CLIENT    état local, commande/touche, panneau NUI, export GetMyCrew
    tags.lua              CLIENT    repères au-dessus des membres (F9)
  web/
    index.html            NUI       (base : templates/pop_base/web/index.html, contenu de #app remplacé)
    style.css             NUI
    script.js             NUI
    kit/pop.css           NUI       copie de templates/pop_base/web/kit/pop.css
    kit/pop.js            NUI       copie de templates/pop_base/web/kit/pop.js
  sql/
    install.sql           SERVEUR   (§7)
```

### 2.1 fxmanifest.lua (imposé)

```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_crew'
author 'POP'
version '1.0.0'
description 'POP Crew : player-made crews'

dependency 'oxmysql'

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/*.lua',
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
    'sql/*.sql',
}
```

---

## 3. Events

### 3.1 Net events serveur → client (un seul)

| Event | Paramètres | Envoyé quand |
|---|---|---|
| `pop_crew:client:update` | `crew` : `CrewSummary` \| `nil` (format §3.3) | À **tous les membres en ligne** du crew concerné après toute modification (création, arrivée, départ, exclusion, changement de rang, dissolution, connexion/déconnexion d'un membre). Au joueur concerné quand il rejoint/quitte. À l'invité quand il reçoit une invitation (avec son état actuel, `nil`), pour rafraîchir son panneau s'il est ouvert. Au joueur à son `Bridge.OnPlayerLoaded` (serveur). |

Client : à réception, met à jour le cache local (`GetMyCrew`, repères) et, **si le panneau est ouvert**, redemande
`pop_crew:getPanel` puis envoie `crew:update` à la NUI (au plus une requête toutes les 500 ms : regrouper les rafales).

### 3.2 Net events client → serveur

**Aucun.** Toutes les actions passent par les callbacks (§4) : réponse au client + anti-spam `Config.CallbackRateLimit`.

### 3.3 Events serveur locaux (TriggerEvent, entre ressources, jamais RegisterNetEvent)

| Event | Paramètres | Déclenché |
|---|---|---|
| `pop_crew:changed` | `src` (number), `crewId` (number \| nil) | Pour un joueur **en ligne** dont l'appartenance change : création (`crewId`), invitation acceptée (`crewId`), départ (`nil`), exclusion s'il est en ligne (`nil`), dissolution (`nil` pour chaque membre en ligne). Aussi au `playerLoaded` si le crew du personnage diffère de celui en cache pour ce `src` (changement de personnage multichar). Pas déclenché à une simple connexion / déconnexion ni à un changement de rang. |
| `pop_crew:disbanded` | `crewId` (number) | Après suppression d'un crew (dissolution, ou chef seul qui quitte). Permet à pop_territories de libérer ses zones. |

Écoute (autre ressource) : `AddEventHandler('pop_crew:changed', function(src, crewId) ... end)`.

### 3.4 Formats communs

```lua
-- CrewSummary (event client:update, callback getMine). Le sous-ensemble { id, name, color, rank, rankLabel }
-- est exactement le format de l'export serveur GetPlayerCrew et de l'export client GetMyCrew.
{
    id = 12,                 -- number
    name = 'Vice Kings',     -- string
    color = '#ff2e88',       -- string hex '#rrggbb' minuscules (valeur de Config.Colors)
    rank = 1,                -- number, index dans Config.Ranks (1 = chef)
    rankLabel = 'Leader',    -- string, L('rank_' .. Config.Ranks[rank].name)
    perms = { invite = true, kick = true, manage = true, disband = true }, -- calculé serveur
    onlineIds = { 3, 17 },   -- ids serveur des membres en ligne (moi compris)
}
```

---

## 4. Callbacks (`shared/callback.lua`, client → serveur)

Tous enregistrés côté serveur par `Callback.Register(name, fn(source, ...))`, appelés côté client par `Callback.Await`.
**Convention des actions** : retour `ok, key, ...args` où `ok` est un booléen, `key` une clé de locale (§9) et
`args` ses arguments. Le client affiche `Bridge.Notify(L(key, ...args), ok and 'success' or 'error')`.
Un retour `nil` (timeout / anti-spam) = `L('error')`.

| Nom | Paramètres client | Retour | Rôle |
|---|---|---|---|
| `pop_crew:getMine` | — | `CrewSummary` \| `nil` | État au chargement du client (en plus du push serveur). |
| `pop_crew:getPanel` | — | `PanelData` (§4.1) | Données complètes du panneau. |
| `pop_crew:getNearby` | — | `{ { id = number, dist = number }, ... }` | Joueurs chargés à ≤ `Config.InviteDistance` du demandeur (positions serveur, même routing bucket, sans lui-même), triés par distance, `dist` arrondi à l'entier. Liste vide si pas la permission `invite`. |
| `pop_crew:create` | `name` (string), `color` (string) | `ok, key, ...` | F1. Succès : `true, 'crew_created', name`. |
| `pop_crew:invite` | `targetId` (number, id serveur) | `ok, key, ...` | F2. Succès : `true, 'invite_sent'`. |
| `pop_crew:respond` | `accept` (boolean) | `ok, key, ...` | F3. Succès : `true, 'joined', crewName` ou `true, 'invite_declined'`. |
| `pop_crew:leave` | — | `ok, key, ...` | F4. Succès : `true, 'left'` (ou `true, 'disbanded', name` si chef seul). |
| `pop_crew:kick` | `memberId` (number) | `ok, key, ...` | F5. Succès : `true, 'member_kicked', memberName`. |
| `pop_crew:setRank` | `memberId` (number), `rank` (number) | `ok, key, ...` | F6. Succès : `true, 'rank_changed', memberName, rankLabel`. |
| `pop_crew:disband` | — | `ok, key, ...` | F7. Succès : `true, 'disbanded', name`. |

`memberId` = colonne `pop_crew_members.id` (jamais l'identifiant framework/licence, qui ne quitte pas le serveur).

### 4.1 PanelData

```lua
{
    crew = nil or {
        id = 12, name = 'Vice Kings', color = '#ff2e88',
        rank = 1, rankLabel = 'Leader',
        perms = { invite = true, kick = true, manage = true, disband = true },
        maxMembers = 20,
        members = {           -- tri : en ligne d'abord, puis rang croissant, puis nom
            {
                id = 7,               -- memberId
                name = 'Tommy Vercetti',
                rank = 1, rankLabel = 'Leader',
                online = true,
                me = true,
                canKick = false,      -- calculés serveur pour CE demandeur
                canPromote = false,   -- rank - 1 autorisé (si rank - 1 == 1 : transfert, réservé au chef)
                canDemote = false,    -- rank + 1 autorisé (existe dans Config.Ranks)
            },
        },
    },
    invite = nil or { crew = 'Vice Kings', color = '#ff2e88', expires = 42 }, -- secondes restantes ; seulement si crew == nil
    create = {                -- seulement si crew == nil
        cost = 25000,         -- 0 si gratuit (standalone ou config 0)
        colors = { '#ff2e88', '#22d3ee', ... },  -- Config.Colors
        nameMin = 3, nameMax = 20,
    },
}
```

---

## 5. Messages NUI

### 5.1 Lua → JS (`SendNUIMessage`)

| action | Données | Effet |
|---|---|---|
| `crew:open` | `{ action = 'crew:open', data = PanelData }` | Affiche le panneau (`Pop.show`), rend la vue adaptée. |
| `crew:update` | `{ action = 'crew:update', data = PanelData }` | Re-rend si ouvert (garde la vue « inviter » si elle est affichée et que `crew.perms.invite` reste vrai). |
| `crew:close` | `{ action = 'crew:close' }` | Masque le panneau, réinitialise les confirmations en attente. |

Messages du kit (`pop:prompt`, `pop:progress`, `pop:notify`, `pop:locale`) : gérés par `kit/pop.js`, rien à faire.

### 5.2 JS → Lua (`Pop.post(name, data)` → `RegisterNUICallback(name)` dans `client/main.lua`)

Chaque callback Lua appelle le callback serveur correspondant (dans un thread), notifie le joueur selon la convention §4,
puis, si `ok`, redemande `pop_crew:getPanel` et envoie `crew:update`. Réponse JSON à la NUI :

| name | Corps JSON envoyé | Réponse JSON | Callback serveur |
|---|---|---|---|
| `create` | `{ "name": "Vice Kings", "color": "#ff2e88" }` | `{ "ok": true }` | `pop_crew:create` |
| `nearby` | `{}` | `{ "players": [ { "id": 17, "dist": 3 } ] }` | `pop_crew:getNearby` |
| `invite` | `{ "id": 17 }` | `{ "ok": true }` | `pop_crew:invite` |
| `respond` | `{ "accept": true }` | `{ "ok": true }` | `pop_crew:respond` |
| `leave` | `{}` | `{ "ok": true }` | `pop_crew:leave` |
| `kick` | `{ "memberId": 7 }` | `{ "ok": true }` | `pop_crew:kick` |
| `setRank` | `{ "memberId": 7, "rank": 2 }` | `{ "ok": true }` | `pop_crew:setRank` |
| `disband` | `{}` | `{ "ok": true }` | `pop_crew:disband` |
| `close` | `{}` | — | **déjà enregistré par `bridge/client.lua`** : ne pas le redéclarer ; le client utilise `Bridge.OnUiClose(cb)`. Bouton fermer et Échap → `Pop.post('close')`. |

`pop:ready` est aussi réservé au bridge. Le client convertit les valeurs reçues (`tostring`, `tonumber`, booléen strict)
avant de les transmettre ; le serveur revalide de toute façon.

### 5.3 Interface (NUI)

- Panneau unique `#app.pop-panel.pop-fade`, **à gauche**, centré verticalement (`left: 24px`), largeur 280 px,
  hauteur max 70vh, liste des membres défilante. RTL (`[dir="rtl"]`) : à droite. (La droite est occupée par le HUD du kit.)
- Focus souris pendant l'ouverture. Pas de grosse fenêtre, pas d'icônes externes (pas de CDN), police système, fondu 150 ms du kit.
- Vues (une seule visible) :
  - `view-invite` : si `data.invite` : « Invitation » + nom du crew (pastille couleur) + temps restant ; boutons Accepter / Refuser.
  - `view-create` : si pas de crew : champ nom (`maxlength = nameMax`), pastilles de couleur (`create.colors`, une sélectionnée,
    la première par défaut), coût (`create_cost` avec `money`, ou `create_free`), bouton Créer. Désactivé si longueur hors bornes (contrôle cosmétique).
    Si `invite` existe, `view-invite` s'affiche au-dessus de `view-create`.
  - `view-crew` : en-tête (pastille couleur + nom, mon `rankLabel`, `members_count`), liste des membres (point accent = en ligne,
    gris = hors ligne, nom, rang, mention `you`), boutons par membre selon `canPromote` / `canDemote` / `canKick`
    (libellé `transfer` à la place de `promote` quand `member.rank == 2` et `crew.rank == 1`).
    Pied : Inviter (si `perms.invite`), Quitter (si `crew.rank ~= 1` ou seul membre), Dissoudre (si `perms.disband`), Fermer.
  - `view-nearby` : liste `player_id` + `distance` (bouton par joueur → `invite`), `invite_none` si vide, bouton `back`.
- Confirmation des actions destructrices (quitter, dissoudre, exclure, transférer) : premier clic → le bouton affiche
  `Pop.t('confirm')` pendant 3 s ; second clic → envoi. Pas de modale.
- Tout texte vient de `Pop.t` / `data-locale`. Les noms (crew, membres) sont insérés avec `textContent` uniquement (jamais `innerHTML`).
- Couleur du crew utilisée seulement pour la pastille (et non comme accent global).
- Montant : `Pop.t('money', n.toLocaleString())`.

---

## 6. Exports publics

### 6.1 Serveur (contrat pop_territories, noms exacts)

| Export | Retour |
|---|---|
| `GetPlayerCrew(src)` | `{ id, name, color, rank, rankLabel }` ou `nil` (joueur sans crew, non chargé, ou données pas encore chargées) |
| `GetCrewMembers(crewId)` | liste triée par rang : `{ { id, identifier, name, rank, rankLabel, online, source }, ... }` (`source` = nil hors ligne) ; `{}` si crew inconnu |
| `GetCrew(crewId)` | `{ id, name, color, memberCount, onlineCount }` ou `nil` |
| `IsSameCrew(srcA, srcB)` | `true` si les deux sont dans le même crew, sinon `false` (aussi si l'un n'en a pas) |

Lecture seule sur le cache mémoire : aucun accès SQL, O(1) sauf `GetCrewMembers` (taille du crew). Les tables
renvoyées sont des **copies**. Usage : `exports.pop_crew:GetPlayerCrew(source)`.

### 6.2 Client

| Export | Retour |
|---|---|
| `GetMyCrew()` | `{ id, name, color, rank, rankLabel }` ou `nil` (copie du cache local mis à jour par `pop_crew:client:update`) |

---

## 7. Schéma SQL (`sql/install.sql`)

Le serveur exécute aussi ces deux `CREATE TABLE IF NOT EXISTS` au démarrage (avant de charger le cache) :
l'import manuel est facultatif.

```sql
CREATE TABLE IF NOT EXISTS `pop_crews` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name`       VARCHAR(32)  NOT NULL,
    `color`      CHAR(7)      NOT NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_pop_crews_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_crew_members` (
    `id`         INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `crew_id`    INT UNSIGNED     NOT NULL,
    `identifier` VARCHAR(64)      NOT NULL,
    `name`       VARCHAR(64)      NOT NULL DEFAULT '',
    `rank`       TINYINT UNSIGNED NOT NULL,
    `joined_at`  TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_pop_crew_members_identifier` (`identifier`),
    KEY `idx_pop_crew_members_crew` (`crew_id`),
    CONSTRAINT `fk_pop_crew_members_crew` FOREIGN KEY (`crew_id`) REFERENCES `pop_crews` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- `identifier` = `Bridge.GetIdentifier(src)` (identifier ESX, citizenid QB/Qbox, license standalone). **Jamais le source.**
- `name` = `Bridge.GetName(src)`, mis à jour à chaque `playerLoaded` (affichage des membres hors ligne).
- La collation `_ci` rend l'unicité du nom insensible à la casse.
- Requêtes toujours paramétrées (`?`). Lecture complète au démarrage, puis écritures ponctuelles uniquement.
- Au chargement : rang > `#Config.Ranks` → ramené au dernier rang ; crew sans rang 1 → le membre au plus petit rang
  (puis le plus ancien) devient rang 1 ; crew sans membre → supprimé. Corrections écrites en base.

---

## 8. config.lua (contenu complet imposé)

```lua
Config = {}

-- Langue : en, fr, es, de, it, pt, nl, pl, tr, ar (une clé absente retombe sur 'en').
Config.Locale = 'en'

-- Affiche les messages de diagnostic dans la console.
Config.Debug = false

-- 'auto' détecte ce qui est lancé. Sinon, forcer :
Config.Framework = 'auto' -- 'esx' | 'qbcore' | 'qbox' | 'standalone'
Config.Inventory = 'auto' -- 'pop_inventory' | 'ox_inventory' | 'qs-inventory' | 'qb-inventory' | 'ps-inventory' | 'framework' | 'none'
Config.Target    = 'auto' -- 'ox_target' | 'qb-target' | 'prompt'
Config.Notify    = 'auto' -- 'framework' | 'ox_lib' | 'pop' | 'native'

-- Couleur d'accent de l'interface. Rose néon par défaut, cyan : '#22d3ee'.
Config.AccentColor = '#ff2e88'

-- Touches (numéros de contrôle GTA : https://docs.fivem.net/docs/game-references/controls/).
Config.Keys = {
    Interact = { control = 38, label = 'E' }, -- prompt natif (sans ox_target / qb-target)
    Cancel   = { control = 73, label = 'X' }, -- annuler une barre de progression
}

-- Anti-spam des callbacks : appels max par seconde, par joueur et par callback (0 = illimité).
Config.CallbackRateLimit = 10

------------------------------------------------------------------------
-- pop_crew
------------------------------------------------------------------------

-- Commande du panneau ('' = repli sur 'crew') et touche par défaut ('' = aucune touche ;
-- chaque joueur peut la changer dans Paramètres > Raccourcis FiveM).
Config.Command = 'crew'
Config.Key     = 'F7'

-- Création : prix et compte débité ('cash' | 'bank'). 0 = gratuit. Toujours gratuit en standalone.
Config.CreateCost    = 25000
Config.CreateAccount = 'bank'

-- Nom du crew : longueur en caractères (max 32).
Config.NameLength = { min = 3, max = 20 }

-- Nombre maximum de membres par crew.
Config.MaxMembers = 20

-- Invitation : distance max (m) entre les deux joueurs, et durée de validité (s).
Config.InviteDistance = 5.0
Config.InviteTimeout  = 60

-- Couleurs proposées à la création (hex '#rrggbb').
Config.Colors = { '#ff2e88', '#22d3ee', '#a3e635', '#facc15', '#f97316', '#ef4444', '#8b5cf6', '#f5f5f5' }

-- Rangs, du plus haut (1 = chef, toutes permissions) au plus bas (rang des nouveaux membres). 3 ou 4 conseillés.
-- Libellé : clé de locale 'rank_<name>'. invite = inviter, kick = exclure, manage = changer les rangs inférieurs.
Config.Ranks = {
    { name = 'leader',  invite = true,  kick = true,  manage = true  },
    { name = 'officer', invite = true,  kick = true,  manage = false },
    { name = 'member',  invite = false, kick = false, manage = false },
    { name = 'recruit', invite = false, kick = false, manage = false },
}

-- Repère à la couleur du crew au-dessus des membres proches.
Config.ShowTags    = false
Config.TagDistance = 20.0
```

Aucune autre clé. Le serveur borne les valeurs absurdes au démarrage (ex. `NameLength.max` > 32 → 32, `#Config.Ranks` < 2 → erreur console).

---

## 9. Clés de traduction

Clés communes du template conservées et utilisées : `confirm`, `cancel`, `close`, `no_permission`, `too_far`,
`not_enough_money`, `error`.
Clés du script, à ajouter **dans les 10 fichiers** sous `-- Textes propres au script :`. Texte anglais de référence
ci-dessous ; le dev Serveur traduit les 9 autres langues (mêmes `%s`, même ordre). `ar.lua` garde `_rtl = true`.

```lua
    -- Panneau
    crew_title        = 'Crew',
    create_title      = 'Create a crew',
    create_name       = 'Crew name',
    create_color      = 'Color',
    create_cost       = 'Cost: %s',
    create_free       = 'Free',
    create_button     = 'Create',
    money             = '$%s',
    members           = 'Members',
    members_count     = '%s/%s',
    online            = 'Online',
    offline           = 'Offline',
    you               = 'You',
    invite_button     = 'Invite',
    invite_nearby     = 'Nearby players',
    invite_none       = 'No one nearby',
    player_id         = 'Player #%s',
    distance          = '%sm',
    promote           = 'Promote',
    demote            = 'Demote',
    transfer          = 'Make leader',
    kick              = 'Kick',
    leave             = 'Leave',
    disband           = 'Disband',
    back              = 'Back',
    invite_title      = 'Invitation',
    invite_expires    = 'Expires in %ss',
    accept            = 'Accept',
    decline           = 'Decline',
    keymap_open       = 'Open crew panel',

    -- Rangs (une clé par Config.Ranks[i].name)
    rank_leader       = 'Leader',
    rank_officer      = 'Officer',
    rank_member       = 'Member',
    rank_recruit      = 'Recruit',

    -- Notifications
    crew_created      = 'Crew %s created',
    name_invalid      = 'The name must be %s to %s characters',
    name_taken        = 'This name is already taken',
    color_invalid     = 'Invalid color',
    already_in_crew   = 'You are already in a crew',
    not_in_crew       = 'You are not in a crew',
    target_in_crew    = 'This player is already in a crew',
    target_not_found  = 'Player not found',
    invite_sent       = 'Invitation sent',
    invite_pending    = 'This player already has a pending invitation',
    invite_received   = 'You are invited to join %s. Type /%s to answer',
    invite_expired    = 'No pending invitation',
    invite_declined   = 'Invitation declined',
    crew_full         = 'The crew is full',
    joined            = 'You joined %s',
    member_joined     = '%s joined the crew',
    left              = 'You left the crew',
    member_left       = '%s left the crew',
    kicked            = 'You were kicked from %s',
    member_kicked     = '%s was kicked from the crew',
    rank_changed      = '%s is now %s',
    leader_must_transfer = 'Make another member leader before leaving',
    disbanded         = 'The crew %s has been disbanded',
```

Usage : le client Lua utilise `L()`, la NUI `Pop.t()` / `data-locale` (la table complète arrive par `pop:ready`).
`RegisterKeyMapping(Config.Command, L('keymap_open'), 'keyboard', Config.Key)`.

Notifications envoyées par le serveur à d'autres joueurs (`Bridge.Notify(src, L(...), type)`) :

| Destinataire | Clé |
|---|---|
| invité | `invite_received` (nom du crew, `Config.Command`), `info` |
| autres membres en ligne quand quelqu'un rejoint / quitte / est exclu | `member_joined` / `member_left` / `member_kicked` (nom), `info` |
| membre exclu (s'il est en ligne) | `kicked` (nom du crew), `error` |
| membre dont le rang change (s'il est en ligne) | `rank_changed` (son nom, nouveau libellé), `info` |
| tous les membres en ligne sauf le chef à la dissolution | `disbanded` (nom du crew), `error` |

---

## 10. Côté client (rappels pour le dev Client)

- `client/main.lua` :
  - `Bridge.OnPlayerLoaded` → `Callback.Await('pop_crew:getMine')` → cache. Net event `pop_crew:client:update` → cache (+ refresh panneau si ouvert, §3.1).
  - `RegisterCommand(Config.Command, toggle, false)` + `RegisterKeyMapping` si `Config.Key ~= ''`.
  - Ouverture : `Callback.Await('pop_crew:getPanel')` → `SendNUIMessage({ action = 'crew:open', data = ... })` → `SetNuiFocus(true, true)`.
    Ne pas ouvrir si `IsPauseMenuActive()` ou si `Bridge.IsBusy()`.
  - Fermeture : `Bridge.OnUiClose` (focus déjà rendu) → état fermé ; fermeture forcée → `SetNuiFocus(false, false)` + `crew:close`.
  - NUI callbacks §5.2 ; `exports('GetMyCrew', ...)` renvoie une copie `{ id, name, color, rank, rankLabel }`.
  - `onResourceStop` : `SetNuiFocus(false, false)` (le bridge le fait aussi).
- `client/tags.lua` (seulement si `Config.ShowTags`) : un thread démarré quand le cache contient un crew avec au moins un
  autre membre en ligne, arrêté sinon. Toutes les 500 ms : pour chaque id de `onlineIds` (hors moi),
  `GetPlayerFromServerId(id)` ≠ -1, ped existant, à ≤ `Config.TagDistance` → liste visible.
  Liste vide → `Wait(1000)`. Liste non vide → `DrawMarker` (type 2, retourné vers le bas, échelle 0.15, couleur du crew
  convertie depuis hex, alpha 200) à `tête + 0.35 m` chaque frame jusqu'au prochain recalcul. Rien ne tourne quand personne n'est visible.
- Aucune boucle `Wait(0)` permanente ; aucun texte en dur.

---

## 11. Côté serveur (rappels pour le dev Serveur)

- Cache mémoire chargé une fois au démarrage (`loaded = true` ensuite ; callbacks et exports renvoient `nil` / `false, 'error'` avant) :
  - `crews[crewId] = { id, name, color, members = { [identifier] = { id, name, rank } }, count }`
  - `crewOf[identifier] = crewId`, `nameIndex[nom en minuscules] = crewId`
  - `identOf[src] = identifier`, `srcOf[identifier] = src` (renseignés au `Bridge.OnPlayerLoaded`, vidés au `Bridge.OnPlayerDropped` et au `Bridge.OnPlayerUnloaded` s'il existe :
    on n'appelle pas `Bridge.GetIdentifier` dans `playerDropped`, le framework a pu décharger le joueur).
  - `invites[identifier] = { crewId, expires = os.time() + Config.InviteTimeout }` (supprimée au drop, à l'acceptation, au refus, à expiration).
- `playerLoaded` : attendre `loaded`, mettre à jour le cache et la colonne `name` si elle a changé, push
  `pop_crew:client:update` au joueur et aux membres en ligne (statut en ligne). `playerDropped` : push aux membres restants.
- Mutation : modifier d'abord le cache (synchrone), puis écrire en base ; en cas d'échec SQL, annuler le cache et renvoyer `false, 'error'`.
  Ainsi deux requêtes simultanées ne passent pas toutes deux les contrôles (MaxMembers, nom unique, invitation unique).
- Création : `RemoveMoney` **après** toutes les validations et la réservation du nom ; si l'INSERT échoue, rembourser (`AddMoney`) et libérer le nom.
- Ordre des events après une mutation réussie : SQL → notifications → `pop_crew:client:update` → `pop_crew:changed` → (`pop_crew:disbanded`).

---

## 12. Règles de sécurité (vérifiées côté serveur, à auditer)

Générales
1. Le client n'envoie jamais d'identifiant, de crewId, de rang du demandeur, de prix ou de distance : tout est relu du cache serveur via `source`.
2. Types stricts sur chaque paramètre : `name`/`color` string, `targetId`/`memberId`/`rank` entiers (`math.type == 'integer'` après `tonumber`), `accept` booléen. Sinon `false, 'error'`.
3. Joueur chargé obligatoire (`identOf[src]` présent) pour tout callback.
4. Anti-spam : `Config.CallbackRateLimit` (shared/callback.lua) + délai interne d'1 s entre deux actions de mutation par joueur (constante locale, pas de config).
5. Aucun identifiant framework / licence n'est envoyé à un client ; les membres sont désignés par `memberId`, les joueurs proches par id serveur.
6. SQL uniquement paramétré.

Création (`pop_crew:create`)
7. Pas déjà dans un crew (`already_in_crew`).
8. Nom : `trim`, espaces multiples réduits à un ; refus si caractères de contrôle (`%c`) ou l'un de `<>"'\`%` ; longueur `utf8.len` (nil = invalide) entre `NameLength.min` et `NameLength.max` (`name_invalid`, min, max) ; libre dans `nameIndex` en minuscules (`name_taken`).
9. Couleur strictement égale à une entrée de `Config.Colors` (`color_invalid`).
10. Coût : si `CreateCost > 0` et framework ≠ standalone, `Bridge.RemoveMoney(src, Config.CreateAccount, Config.CreateCost, 'pop_crew')` doit renvoyer true (`not_enough_money`).

Invitation (`pop_crew:getNearby`, `pop_crew:invite`, `pop_crew:respond`)
11. Inviteur dans un crew avec permission `invite` (`no_permission`) ; crew non plein en comptant les membres (`crew_full`).
12. Cible : id ≠ inviteur, joueur chargé (`target_not_found`), sans crew (`target_in_crew`), sans invitation non expirée (`invite_pending`).
13. Distance entre les **positions serveur** des deux joueurs (`Bridge.GetCoords`) ≤ `Config.InviteDistance` et même `GetPlayerRoutingBucket` (`too_far`).
14. Réponse : invitation existante et non expirée (`invite_expired`), crew toujours existant, non plein (`crew_full`), répondant toujours sans crew (`already_in_crew`). Rejoint au dernier rang.

Gestion (`pop_crew:kick`, `pop_crew:setRank`, `pop_crew:leave`, `pop_crew:disband`)
15. `memberId` doit appartenir au **même crew** que le demandeur, et ne pas être lui-même (`no_permission`).
16. Exclure : permission `kick` et `cible.rank > demandeur.rank`.
17. Changer de rang : permission `manage`, `cible.rank > demandeur.rank`, nouveau rang ∈ [1, #Config.Ranks] et ≠ rang actuel ;
    nouveau rang > demandeur.rank, **sauf** nouveau rang = 1 qui n'est permis qu'au chef (transfert : cible → 1, chef → 2, atomique).
18. Quitter : chef avec d'autres membres → `leader_must_transfer` ; chef seul → dissolution.
19. Dissoudre : rang 1 uniquement.
20. Permissions recalculées à chaque appel depuis `Config.Ranks` et le rang en cache (le rang 1 a toujours tout) ; `perms` / `can*` envoyés au client ne servent qu'à l'affichage.

Exports et events
21. `pop_crew:changed` et `pop_crew:disbanded` sont déclenchés par `TriggerEvent` (serveur local) et **jamais** enregistrés avec `RegisterNetEvent` : un client ne peut pas les simuler.
22. Exports en lecture seule, renvoyant des copies (un appelant ne peut pas modifier le cache).

---

## 13. Notes d'audit (corrections après audit, font foi)

- **Invitation** : l'ordre des contrôles de la cible est `target_not_found` → `too_far` → `target_in_crew` → `invite_pending`
  (un joueur éloigné n'apprend rien sur la cible).
- **`Bridge.OnPlayerUnloaded(cb(src))`** (si le bridge le fournit) : traité comme une déconnexion (identOf/srcOf/invitation
  vidés, push aux membres restants, `pop_crew:client:update` `nil` au joueur). Le crew du personnage déchargé est mémorisé
  pour que le `playerLoaded` suivant déclenche `pop_crew:changed` si le nouveau personnage a un autre crew (§3.3).
- **Échec SQL** : en plus de `false, 'error'`, le serveur renvoie l'état réel (`pushCrew` du crew s'il existe, push au
  demandeur / à la cible hors crew).
- **Crew verrouillé** : pendant une suppression (`closing`) ou un transfert de chef (`busy`), toute autre action sur ce
  crew renvoie `false, 'error'` (et non `busy`, réservé à la mutation en cours du joueur lui-même).
- **Création** : après la réservation dans `nameIndex`, `SELECT 1 FROM pop_crews WHERE name = ? LIMIT 1` (collation `_ci`)
  → `name_taken` **avant** tout débit ; le nom du membre est lu avant `RemoveMoney`.
- **Nom (§12.8)** : refus aussi de l'UTF-8 invalide et des caractères invisibles / bidi U+00A0, U+200B-200F, U+202A-202E,
  U+2066-2069, U+FEFF (`name_invalid`).
- **`Config.Command`** vide → repli sur `'crew'` (client et serveur) ; `Config.Key = ''` = pas de touche par défaut.
  `crew:open` n'envoie plus de champ `command` (inutilisé par la NUI).
- **Repères (§10)** : peds invisibles (`IsEntityVisible`) ignorés.
- **NUI** : titre du panneau `crew_title`, en-tête de liste `members`. Une confirmation armée survit à un `crew:update`
  tant que sa cible existe encore (même bouton, même membre, même type d'action) ; elle garde son échéance de 3 s.
