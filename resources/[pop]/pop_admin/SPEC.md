# pop_admin : SPEC (contrat commun Serveur / Client / NUI)

> Ce document est **la référence unique**. Les noms (fichiers, events, callbacks, clés de config, clés de locale,
> champs de données, messages NUI) doivent être repris **à l'identique**. En cas de doute : ce fichier fait foi.
> API commune à utiliser telle quelle : `Bridge.*`, `Callback.*`, `L()` (voir `templates/pop_base/README.md`).
> `bridge/`, `shared/callback.lua`, `shared/locale.lua` et `web/kit/` sont copiés par l'intégrateur depuis
> `templates/pop_base` : **personne ne les écrit ni ne les modifie**.

---

## 1. Description et fonctionnalités

Panneau d'administration sobre (panneau latéral droit), réservé au staff, **entièrement contrôlé par le serveur** :
le client n'est qu'une télécommande, chaque action est revérifiée (droit + cible + données + anti-spam).

**Ouverture** : commande `Config.Command` (défaut `/popadmin`) ou touche `Config.OpenKey` (défaut F10,
modifiable par chaque joueur dans Paramètres → Raccourcis FiveM). Touche de noclip directe : `Config.NoclipKey`.

**Accès** : `Bridge.IsAdmin(src)` (ACE `pop.admin` ou groupe admin/superadmin/god du framework). Puis chaque action
exige son droit (section 3) : ACE `pop.admin.<droit>` (héritée de `pop.admin`, refusable une par une avec `deny`),
ou, pour un admin du framework sans ACE `pop.admin`, tous les droits si `Config.FrameworkAdmins = true`.

**Onglets** (un onglet / un bouton n'apparaît que si le droit est accordé ; le serveur revérifie quand même)
1. **Joueurs** : liste filtrable (ID ou nom), colonnes ID, nom, ping. Clic → fiche : nom du personnage, nom FiveM,
   ping, nombre d'avertissements, état gelé, et les actions :
   téléporter vers (`goto`), ramener (`bring`), observer (`spectate`), geler / dégeler (`freeze`), soigner (`heal`),
   réanimer (`revive`), avertir (`warn`, raison), expulser (`kick`, raison), bannir (`ban`, raison + durée).
   Kick et ban demandent un **second clic de confirmation**.
2. **Moi** : noclip, invisible (interrupteurs), me soigner, me réanimer ; véhicule : nom du modèle + Faire apparaître,
   Réparer, Supprimer (véhicule occupé, sinon le plus proche à 5 m).
3. **Serveur** : météo + heure (heure, minute, heure figée) synchronisées par `GlobalState` ; annonce à tous.
4. **Bans** : bans actifs (100 plus récents) avec bouton Lever le ban.

**Règles**
- Les admins ne peuvent pas se sanctionner entre eux : `freeze`, `warn`, `kick`, `ban` refusés si la cible est
  `Bridge.IsAdmin` (`target_immune`). Aucune action sur soi-même sauf `heal` / `revive`.
- Bans **temporaires ou permanents** (durées de `Config.BanDurations`), en base oxmysql, vérifiés à la connexion
  (`playerConnecting` + deferrals) sur **tous** les identifiants du joueur (license, license2, steam, discord, fivem,
  xbl, live ; jamais l'IP). Cache mémoire : aucune requête SQL à la connexion.
- Avertissements stockés en base (historique), compteur affiché sur la fiche, message affiché au joueur averti.
- Noclip et invisible : **autorisés et activés par le serveur** (event `setMode`), exécutés côté client.
- Spectate : le serveur valide, passe l'admin dans le routing bucket de la cible, envoie les coordonnées ;
  le client observe ; arrêt par `[BACKSPACE]` ou automatiquement si la cible quitte.
- Heal / revive : events connus des scripts de mort (esx_ambulancejob, qb-ambulancejob, qbx_medical) ou event
  personnalisé (`Config.ReviveEvent`), sinon natives GTA. Déclenchés **uniquement** par le serveur après contrôle.
- Météo / heure : implémentation propre au script (aucune dépendance) ; désactivable (`Config.WorldSync = false`)
  pour les serveurs qui ont déjà un script météo.
- Logs : chaque action réussie → console + webhook Discord optionnel (`Config.Webhook` dans `config_server.lua`,
  fichier **serveur uniquement** ; URL vide = désactivé). Refus de droit → console seulement.
- Anti-spam : limite du template (`Config.CallbackRateLimit`) + délai serveur entre deux actions par admin.

**HUD** (sobre, petit, côté droit, fondu 150 ms) : indicateur noclip / invisible / spectate avec touches ;
bannière d'annonce et bannière d'avertissement (en haut à droite, quelques secondes).

**Performance**
- Au repos (non-admin, aucune action) : **0 boucle** côté client hormis la synchro météo (1 boucle à 1000 ms,
  seulement si `Config.WorldSync`). Serveur : aucune boucle.
- `Wait(0)` **uniquement** pendant noclip, invisible ou spectate (modes admin temporaires), arrêté dès la sortie.
- Joueur gelé : 1 boucle à 1000 ms tant qu'il est gelé.

**Hors périmètre (volontairement)** : argent, items, jobs, groupes, ban hors ligne, menu de logs en jeu, godmode,
kill, blips de joueurs, rapports, captures d'écran.

**Prérequis** : OneSync (activé par défaut sur les serveurs récents), oxmysql.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_admin/
  SPEC.md                 Architecte (ce fichier)
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR   (clés communes de pop_base + clés de la section 8, à l'identique)
  config_server.lua       SERVEUR   chargé côté serveur uniquement (webhook), section 8
  README.md               SERVEUR   en ANGLAIS : installation, ACE / niveaux, config, scripts de mort supportés
  sql/install.sql         SERVEUR
  bridge/server.lua       (copie intégrateur, ne pas toucher)
  bridge/client.lua       (copie intégrateur, ne pas toucher)
  shared/callback.lua     (copie intégrateur, ne pas toucher)
  shared/locale.lua       (copie intégrateur, ne pas toucher)
  locales/en.lua          SERVEUR   bloc « Kit commun » de pop_base + clés de la section 9
  locales/fr.lua  es.lua  de.lua  it.lua  pt.lua  nl.lua  pl.lua  tr.lua  ar.lua   SERVEUR (idem, ar : _rtl = true)
  server/bans.lua         SERVEUR   bans + avertissements (SQL, cache, playerConnecting)
  server/log.lua          SERVEUR   console + webhook
  server/main.lua         SERVEUR   droits, callbacks, actions, météo, exports
  client/main.lua         CLIENT    ouverture, NUI, touches, events reçus (teleport, freeze, heal, revive, warn,
                                    announce, fixVehicle)
  client/modes.lua        CLIENT    noclip, invisible, spectate, HUD des modes
  client/world.lua        CLIENT    application météo / heure depuis GlobalState
  web/index.html          NUI
  web/script.js           NUI
  web/style.css           NUI
  web/kit/pop.css         (copie intégrateur, ne pas toucher)
  web/kit/pop.js          (copie intégrateur, ne pas toucher)
```

Ordre de chargement des fichiers serveur (`server/*.lua`, alphabétique) : `bans.lua` → `log.lua` → `main.lua`.
Les tables globales partagées (section 11) ne sont utilisées **qu'à l'exécution** (dans des fonctions), jamais au
chargement d'un autre fichier.

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_admin'
author 'POP'
version '1.0.0'
description 'POP Admin - simple and secure admin panel'

dependencies { 'oxmysql' }

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
    'config_server.lua',
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
    'config_server.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
```

---

## 3. Droits et actions

### Calcul d'un droit (serveur, fonction locale `HasPermission(src, perm)`, aussi exportée)
```lua
local function HasPermission(src, perm)
    if not PERMS[perm] or not Bridge.IsAdmin(src) then return false end
    if IsPlayerAceAllowed(src, 'pop.admin') then
        return IsPlayerAceAllowed(src, 'pop.admin.' .. perm) -- hérité de pop.admin, refusable par deny
    end
    return Config.FrameworkAdmins == true                  -- admin du framework sans ACE pop.admin
end
```
`PERMS` = ensemble des 15 droits ci-dessous. Exemple README (niveaux) :
```
add_ace group.admin pop.admin allow
add_ace group.mod   pop.admin allow
add_ace group.mod   pop.admin.ban deny
add_ace group.mod   pop.admin.unban deny
add_ace group.mod   pop.admin.world deny
```

### Table des actions (`ACTIONS` dans `server/main.lua`)

`target` : `required` = un autre joueur connecté ; `self_ok` = un joueur connecté, soi-même accepté ;
`optional` = spectate (nombre = démarrer, `nil` = arrêter) ; `none` = aucune cible (ignorée si envoyée).
`immune` : refusé si la cible est `Bridge.IsAdmin`.

| `action` (envoyé) | droit `perm` | target | immune | `data` attendu |
|---|---|---|---|---|
| `goto` | `goto` | required | non | — |
| `bring` | `bring` | required | non | — |
| `spectate` | `spectate` | optional | non | — |
| `freeze` | `freeze` | required | oui | — (bascule) |
| `heal` | `heal` | self_ok | non | — |
| `revive` | `revive` | self_ok | non | — |
| `warn` | `warn` | required | oui | `{ reason }` |
| `kick` | `kick` | required | oui | `{ reason }` |
| `ban` | `ban` | required | oui | `{ reason, duration }` (heures, valeur de `Config.BanDurations`) |
| `unban` | `unban` | none | — | `{ banId }` |
| `noclip` | `noclip` | none | — | — (bascule) |
| `invisible` | `invisible` | none | — | — (bascule) |
| `vehicle_spawn` | `vehicle` | none | — | `{ model, vtype }` (ajoutés par le client Lua) |
| `vehicle_fix` | `vehicle` | none | — | `{ netId }` (ajouté par le client Lua) |
| `vehicle_delete` | `vehicle` | none | — | `{ netId }` (ajouté par le client Lua) |
| `world` | `world` | none | — | `{ weather, hour, minute, frozen }` |
| `announce` | `announce` | none | — | `{ message }` |

Les 15 droits : `goto`, `bring`, `spectate`, `freeze`, `heal`, `revive`, `warn`, `kick`, `ban`, `unban`, `noclip`,
`invisible`, `vehicle`, `world`, `announce`.

---

## 4. Events

Les actions client → serveur passent **toutes par des callbacks** (section 5). Il n'y a **aucun**
`RegisterNetEvent` serveur propre au script (rien à spoofer).

### Serveur → Client (`RegisterNetEvent` côté client)

| Event | Paramètres | Destinataire | Fichier client | Rôle |
|---|---|---|---|---|
| `pop_admin:client:teleport` | `coords` (`{ x, y, z }`) | joueur déplacé (admin pour goto, cible pour bring) | main.lua | Téléportation |
| `pop_admin:client:freeze` | `state` (bool) | cible | main.lua | Geler / dégeler |
| `pop_admin:client:heal` | aucun | cible | main.lua | Soin |
| `pop_admin:client:revive` | aucun | cible | main.lua | Réanimation |
| `pop_admin:client:warn` | `reason` (string) | cible | main.lua | Bannière + notification d'avertissement |
| `pop_admin:client:announce` | `message` (string) | `-1` | main.lua | Bannière d'annonce |
| `pop_admin:client:fixVehicle` | `netId` (int) | propriétaire réseau du véhicule | main.lua | Réparation |
| `pop_admin:client:setMode` | `mode` (`'noclip'` \| `'invisible'`), `enabled` (bool) | l'admin | modes.lua | Active / coupe un mode |
| `pop_admin:client:spectate` | `target` (int \| `false`), `coords` (`{ x, y, z }` \| nil), `name` (string \| nil) | l'admin | modes.lua | Démarre (`target` int) ou arrête (`false`) l'observation |

### Statebag global
- `GlobalState['pop_admin:world']` = `{ weather = 'CLEAR', hour = 12, minute = 0, frozen = false, t = 1773695584 }`
  (`t` = `os.time()` serveur au moment du réglage). Écrit **uniquement** par le serveur, lu par `client/world.lua`
  (`AddStateBagChangeHandler('pop_admin:world', 'global', ...)` + lecture initiale).

### Évènements du bridge / natifs utilisés
- Serveur : `Bridge.OnPlayerDropped(src)` → nettoie `frozen[src]`, `modes[src]`, `spectating[src]`, `busy[src]`,
  `lastAction[src]`, `lastAnnounce[src]`, `spawned[src]` ; arrête le spectate des admins qui observaient `src`.
- Serveur : `AddEventHandler('playerConnecting', function(name, setKick, deferrals) ...)` (section 11).
- Client : `Bridge.OnUiClose` → ferme le panneau.

---

## 5. Callbacks (`shared/callback.lua`)

Convention des actions : retour `ok (bool), reason (string, clé de locale) | nil, arg | nil`.
En cas d'échec, le **client Lua** affiche `Bridge.Notify(L(reason or 'error', arg), 'error')`.
En cas de succès, le **serveur** notifie l'admin (`Bridge.Notify(src, L('done_...'), 'success')`).
`nil` (timeout ou anti-spam) = `reason = 'error'`.

| Nom | Paramètres (client → serveur) | Retour |
|---|---|---|
| `pop_admin:open` | aucun | `false` si non admin ; sinon `OpenData` (ci-dessous) |
| `pop_admin:getPlayers` | aucun | `false` si non admin ; sinon tableau **séquentiel** de `PlayerRow`, trié par `id` |
| `pop_admin:getBans` | aucun | `false` sans droit `unban` ; sinon tableau séquentiel de `BanRow` (100 max, plus récent d'abord) |
| `pop_admin:action` | `action` (string), `target` (int \| nil), `data` (table \| nil) | `ok, reason, arg` |

### `OpenData`
```lua
{
    self         = 3,                                   -- source de l'admin
    perms        = { goto = true, bring = true, ban = false, ... }, -- les 15 droits, booléens
    weathers     = Config.Weathers,
    banDurations = Config.BanDurations,
    worldSync    = Config.WorldSync,
    world        = { weather = 'CLEAR', hour = 14, minute = 32, frozen = false }, -- heure ACTUELLE calculée
    modes        = { noclip = false, invisible = false, spectating = false },
}
```

### `PlayerRow`
```lua
{ id = 12, name = 'John Doe', fivem = 'johnny', ping = 45, frozen = false, warns = 2, admin = false }
```
`id` = source ; `name` = `Bridge.GetName(id)` sinon `GetPlayerName(id)` ; `fivem` = `GetPlayerName(id)` ;
`warns` = compteur par license (cache) ; `admin` = `Bridge.IsAdmin(id)` (l'UI grise freeze/warn/kick/ban).
Source de la liste : native `GetPlayers()` (tous les connectés, même au choix du personnage), ids convertis en nombre.
**Aucun identifiant** (license, IP, steam…) n'est envoyé au client.

### `BanRow`
```lua
{ id = 42, name = 'John Doe', reason = 'Cheating', admin = 'Staff Name',
  createdAt = '2026-11-21 18:04', expiresAt = '2026-11-28 18:04' } -- expiresAt = nil si permanent
```
Dates formatées par le serveur : `os.date('%Y-%m-%d %H:%M', ts)`.

### Raisons possibles (toutes des clés de locale)
`error`, `busy`, `no_permission`, `cooldown` (arg = secondes restantes, entier ≥ 1), `invalid_target`,
`player_not_found`, `self_target`, `target_immune`, `invalid_reason`, `invalid_duration`, `invalid_model`,
`vehicle_not_found`, `too_far`, `ban_not_found`, `invalid_weather`, `world_disabled`, `invalid_message`,
`not_spectating`.

### Retour de succès particulier
- `freeze`, `noclip`, `invisible` : `true, nil, state` (bool, nouvel état).
- `ban` : `true, nil, banId`.

Aucun callback serveur → client.

---

## 6. Messages NUI

L'UI prend le focus **uniquement panneau ouvert** : `SetNuiFocus(true, true)` à l'ouverture, `false, false` à la
fermeture (Échap via le kit → `Bridge.OnUiClose`, ou commande / touche à nouveau, ou action qui ferme).

### Lua → JS (`SendNUIMessage`)

**`pop_admin:open`** : ouvre le panneau. Contenu = `OpenData` + `action`.
```json
{ "action": "pop_admin:open", "self": 3,
  "perms": { "goto": true, "bring": true, "spectate": true, "freeze": true, "heal": true, "revive": true,
             "warn": true, "kick": true, "ban": false, "unban": false, "noclip": true, "invisible": true,
             "vehicle": true, "world": false, "announce": true },
  "weathers": ["EXTRASUNNY", "CLEAR"], "banDurations": [1, 24, 72, 168, 720, 0],
  "worldSync": true, "world": { "weather": "CLEAR", "hour": 14, "minute": 32, "frozen": false },
  "modes": { "noclip": false, "invisible": false, "spectating": false } }
```

**`pop_admin:close`** : `{ "action": "pop_admin:close" }`

**`pop_admin:modes`** : état des interrupteurs de l'onglet Moi (envoyé à chaque changement de mode).
```json
{ "action": "pop_admin:modes", "noclip": true, "invisible": false, "spectating": false }
```

**`pop_admin:hud`** : indicateur des modes (envoyé à chaque changement ; tout à false/null = masqué).
```json
{ "action": "pop_admin:hud", "noclip": true, "invisible": false,
  "spectate": { "id": 12, "name": "John Doe" }, "stopKey": "BACKSPACE" }
```
`spectate` = `null` hors observation. Texte : `hud_noclip` + touches `[W A S D] hud_move`, `[Q / E] hud_updown`,
`[SHIFT] hud_fast`, `[ALT] hud_slow` ; `hud_invisible` ; `Pop.t('hud_spectating', name, id)` + `[stopKey] hud_stop`.
Les noms de touches (`W A S D`, `Q / E`, `SHIFT`, `ALT`, `stopKey`) sont des codes clavier, pas du texte traduit.

**`pop_admin:announce`** : `{ "action": "pop_admin:announce", "message": "Restart in 5 minutes", "duration": 8000 }`

**`pop_admin:warn`** : `{ "action": "pop_admin:warn", "reason": "Fail RP", "duration": 10000 }`

`duration` en ms : `Config.AnnounceDuration * 1000` ; avertissement fixe 10000.

### JS → Lua (`RegisterNUICallback` dans `client/main.lua`)

| Nom | Body JSON | Réponse JSON | Côté Lua |
|---|---|---|---|
| `players` | `{}` | `{ "players": [PlayerRow...] }` ou `{ "players": [] }` | `Callback.Await('pop_admin:getPlayers')` |
| `bans` | `{}` | `{ "bans": [BanRow...] }` ou `{ "bans": [] }` | `Callback.Await('pop_admin:getBans')` |
| `action` | `{ "action": "kick", "target": 12, "data": { "reason": "..." } }` | `{ "ok": true, "reason": null, "arg": null }` | voir ci-dessous |
| `close` | (kit) | — | géré par le bridge → `Bridge.OnUiClose` |

Body envoyé par le JS selon l'action :
- `goto`, `bring`, `spectate`, `freeze`, `heal`, `revive` : `{ action, target }` (self : `target = self`).
- `warn`, `kick` : `{ action, target, data: { reason } }` ; `ban` : `{ action, target, data: { reason, duration } }`.
- `unban` : `{ action, data: { banId } }`.
- `noclip`, `invisible`, `vehicle_fix`, `vehicle_delete` : `{ action }`.
- `vehicle_spawn` : `{ action, data: { model } }`.
- `world` : `{ action, data: { weather, hour, minute, frozen } }` (nombres entiers, booléen).
- `announce` : `{ action, data: { message } }`.

Traitement de `action` côté client Lua (`client/main.lua`) :
1. `target` = `tonumber(body.target)` (ou nil), `data` = table ou `{}`.
2. **Enrichissement** (le JS n'envoie pas ces champs) :
   - `vehicle_spawn` : `data.model` = saisie en minuscules, sans espaces autour. Validation locale :
     `IsModelInCdimage(hash)` et `IsModelAVehicle(hash)`, sinon échec local `invalid_model` (aucun appel serveur).
     `data.vtype` (types de `CreateVehicleServerSetter`), dans cet ordre :
     modèle ∈ { `submersible`, `submersible2`, `kosatka`, `avisa` } → `submarine` ;
     `IsThisModelAHeli` → `heli` ; `IsThisModelAPlane` → `plane` ;
     `IsThisModelABoat` ou `IsThisModelAJetski` → `boat` ;
     `IsThisModelABike` ou `IsThisModelABicycle` → `bike` ;
     sinon `automobile` (voitures, quads, utilitaires). Trains et remorques non gérés.
   - `vehicle_fix` / `vehicle_delete` : véhicule occupé (`GetVehiclePedIsIn(ped, false)`), sinon le plus proche
     ≤ `VEHICLE_SEARCH` (`GetGamePool('CVehicle')`, scan unique au clic) ; aucun, ou non mis en réseau
     (`NetworkGetEntityIsNetworked`) → échec local `vehicle_not_found`. `data.netId = VehToNet(veh)`.
3. `local ok, reason, arg = Callback.Await('pop_admin:action', body.action, target, data)`.
4. Échec → `Bridge.Notify(L(reason or 'error', arg), 'error')`.
5. Succès de `goto`, `spectate` (avec cible), `noclip` (activé), `vehicle_spawn` → **fermer le panneau**.
6. Réponse NUI : `cb({ ok = ok == true, reason = reason, arg = arg })`.

### Interface (Dev NUI)

**`web/index.html`** : base de pop_base, `<link rel="stylesheet" href="style.css">` après `kit/pop.css`.
Remplacer `#app` par :
- `#admin` (`pop-panel pop-fade`, masqué par défaut) : panneau latéral.
  - En-tête : `data-locale="title"` + bouton fermer (`data-locale="close"`, `Pop.post('close')`).
  - Onglets (boutons `data-tab`) : `players` (`tab_players`), `self` (`tab_self`), `server` (`tab_server`),
    `bans` (`tab_bans`). Onglet masqué si aucun droit concerné : self = noclip/invisible/heal/revive/vehicle ;
    server = world/announce ; bans = unban.
  - **players** : champ `#search` (placeholder `search`), bouton `refresh`, liste `#player-list` (lignes
    `ID · nom · NN ms` ; `Pop.t('ping_ms', ping)`), `no_players` si vide.
    Fiche `#player-card` : bouton `back`, nom, `fivem` (petit), ping, `Pop.t('player_warns', warns)`, badge
    `frozen` si gelé ; boutons des actions autorisées (`act_goto`, `act_bring`, `act_spectate`,
    `act_freeze`/`act_unfreeze`, `act_heal`, `act_revive`) ; zone sanction : champ `#reason` (placeholder `reason`,
    `maxlength=200`), select `#duration` (libellé `duration`), boutons `act_warn`, `act_kick`, `act_ban`.
    Si `self === id` : masquer goto, bring, spectate, freeze, warn, kick, ban. Si `admin` : désactiver freeze, warn,
    kick, ban (le serveur refuse de toute façon). Si le joueur affiché disparaît de la liste → retour à la liste.
  - **self** : interrupteurs `self_noclip`, `self_invisible` (état `state_on`/`state_off`) → action `noclip` /
    `invisible` ; boutons `self_heal`, `self_revive` → action `heal`/`revive` avec `target = self` ;
    bloc `vehicle_title` : champ `#vehicle-model` (placeholder `vehicle_model`, `maxlength=32`), boutons
    `vehicle_spawn`, `vehicle_fix`, `vehicle_delete`.
  - **server** : bloc `world_title` (si `worldSync`, sinon texte `world_disabled`) : select `world_weather`
    (libellé `Pop.t('weather_' + w.toLowerCase())`, ou le code brut si la clé n'existe pas), `world_hour` (0-23),
    `world_minute` (0-59), case `world_freeze`, bouton `world_apply` ; valeurs pré-remplies avec `world` ;
    bloc `announce_title` : `textarea` (placeholder `announce_placeholder`, `maxlength=200`), bouton `announce_send`.
  - **bans** : liste (nom, raison, `Pop.t('ban_by', admin)`, `Pop.t('ban_until', expiresAt)` ou `ban_permanent`),
    bouton `act_unban` (confirmation) ; `bans_empty` si vide. Chargé à chaque ouverture de l'onglet.
- `#admin-hud` (`pop-panel pop-fade`) : indicateur des modes.
- `#admin-announce` (`pop-panel pop-fade`) : `announce_header` (accent) + message.
- `#admin-warn` (`pop-panel pop-fade`) : `warn_header` (`--pop-danger`) + raison.

**`web/script.js`**
- `Pop.on('pop_admin:open' | 'pop_admin:close' | 'pop_admin:modes' | 'pop_admin:hud' | 'pop_admin:announce' |
  'pop_admin:warn', ...)`, `Pop.show(el, visible)`.
- Ouverture : onglet `players`, `Pop.post('players')`, puis rafraîchissement **toutes les 5 s** tant que le panneau
  est ouvert sur l'onglet players (timer arrêté à la fermeture / changement d'onglet), et après chaque action réussie.
- Filtre local : `id` commence par la saisie, ou `name` / `fivem` contient la saisie (insensible à la casse).
- Durées : `0` → `duration_permanent` ; multiple de 24 → `Pop.t('duration_days', h / 24)` ; sinon
  `Pop.t('duration_hours', h)`.
- Confirmation (kick, ban, unban) : 1er clic → le bouton affiche `confirm` pendant 3 s ; 2e clic → envoi.
- Anti double-clic : boutons désactivés jusqu'à la réponse de `Pop.post('action', ...)`.
- **Sécurité XSS** : noms, raisons, messages viennent des joueurs → **toujours `textContent`**, jamais
  `innerHTML` avec des données.
- Annonce / avertissement : affichés `duration` ms, une seule bannière de chaque à la fois (la nouvelle remplace).
- Tous les libellés via `data-locale` / `Pop.t` : **aucun texte en dur** (placeholders compris :
  `el.placeholder = Pop.t(...)`, appliqué à chaque `pop_admin:open`).

**`web/style.css`**
- `#admin` : `position: fixed; top: 6vh; bottom: 6vh; right: 24px; width: 380px; display: flex;
  flex-direction: column;` liste défilante (`overflow-y: auto`), lignes 32 px, ligne survolée = bordure
  `--pop-accent` à gauche. Fond `--pop-bg`, texte `--pop-size`, secondaire `--pop-size-sm` `--pop-muted`.
  Onglet actif : texte et soulignement `--pop-accent`. Boutons `pop-button` ; boutons de sanction : bordure
  `--pop-danger`.
- `#admin-hud` : `right: 24px; bottom: 12%`. `#admin-announce` et `#admin-warn` : `top: 24px; right: 24px;
  width: 320px`, empilés (warn sous announce), `border-inline-start: 3px solid` accent / danger.
- Aucun dégradé, aucune ombre lourde, aucune animation autre que `.pop-fade`.
- RTL : `[dir="rtl"]` → panneaux à gauche (`right: auto; left: 24px`).

---

## 7. Exports publics

Serveur :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_admin:HasPermission(src, perm)` | bool | même calcul que le panneau (section 3) |
| `exports.pop_admin:IsBanned(src)` | `BanRow` \| nil | ban actif de ce joueur connecté (tous ses identifiants) |
| `exports.pop_admin:BanPlayer(src, reason, hours, by?)` | `ok, banId \| reason` | pour un anticheat ; `hours` = entier ≥ 0 (0 = permanent, **pas** limité à `Config.BanDurations`) ; `by` = nom affiché (défaut `'System'`) ; mêmes contrôles de raison ; log `ban` ; drop du joueur |

Client :
| Export | Retour |
|---|---|
| `exports.pop_admin:IsOpen()` | bool |
| `exports.pop_admin:IsNoclip()` | bool |
| `exports.pop_admin:IsInvisible()` | bool |
| `exports.pop_admin:IsSpectating()` | bool |

---

## 8. config.lua (contenu exact)

`config.lua` reprend **à l'identique** le `config.lua` de `templates/pop_base` (Locale, Debug, Framework, Inventory,
Target, Notify, AccentColor, Keys, CallbackRateLimit), puis ajoute à la suite :

```lua
-- ─── pop_admin ──────────────────────────────────────────────

-- Ouverture du panneau : commande et touche par défaut (chaque joueur peut la changer dans
-- Paramètres > Raccourcis > FiveM). Touche de noclip directe : '' = aucune par défaut.
Config.Command   = 'popadmin'
Config.OpenKey   = 'F10'
Config.NoclipKey = ''

-- Droits : avec l'ACE pop.admin, chaque action se règle par pop.admin.<action> (voir README).
-- true : un admin du framework (groupe admin/superadmin/god) SANS ACE pop.admin a tous les droits.
Config.FrameworkAdmins = true

-- Durées de ban proposées, en heures (0 = permanent).
Config.BanDurations = { 1, 24, 72, 168, 720, 0 }

-- Météo et heure synchronisées par ce script. Mettre false si un autre script gère déjà la météo.
Config.WorldSync = true
Config.Weathers = {
    'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'OVERCAST', 'SMOG', 'FOGGY',
    'RAIN', 'THUNDER', 'CLEARING', 'SNOW', 'XMAS',
}
Config.DefaultWorld = { weather = 'CLEAR', hour = 12, minute = 0, frozen = false }

-- Durée d'affichage d'une annonce (secondes).
Config.AnnounceDuration = 8

-- Event client de votre script de mort pour la réanimation ('' = détection automatique, voir README).
Config.ReviveEvent = ''
```

Aucune autre clé dans `config.lua`.

### config_server.lua (contenu exact, chargé côté serveur uniquement)
```lua
-- Chargé uniquement par le serveur : ce fichier n'est jamais envoyé aux joueurs.

-- Webhook Discord des logs admin ('' = désactivé).
Config.Webhook = ''
```
Le webhook n'est **jamais** dans `config.lua` (fichier partagé, téléchargé par les clients).

### Constantes (dans le code, pas en config)
`server/main.lua` :
```lua
local ACTION_COOLDOWN   = 1000   -- ms entre deux actions d'un même admin (open / getPlayers / getBans exclus)
local ANNOUNCE_COOLDOWN = 10000  -- ms entre deux annonces d'un même admin
local VEHICLE_RANGE     = 10.0   -- m : vehicle_fix / vehicle_delete
local GAME_MINUTE       = 2      -- secondes réelles par minute de jeu
local TEXT_MIN, TEXT_MAX = 3, 200 -- raison / message (caractères UTF-8)
```
`client/modes.lua` :
```lua
local NOCLIP_SPEED = 1.0          -- m par frame (× 4 avec SHIFT, × 0.25 avec ALT)
local STOP_CONTROL = 177          -- BACKSPACE / clic droit : arrêter le spectate
local STOP_LABEL   = 'BACKSPACE'
```
`client/main.lua` : `local VEHICLE_SEARCH = 5.0`.

---

## 9. Locales

10 fichiers : `en` (défaut + repli), `fr`, `es`, `de`, `it`, `pt`, `nl`, `pl`, `tr`, `ar` (`_rtl = true`).
Chaque fichier = bloc « Kit commun » de pop_base inchangé + les clés ci-dessous sous `-- Textes propres au script :`.
Les `%s` sont conservés dans toutes les langues (même nombre, même ordre). `\n` autorisé seulement dans
`ban_message`. Les messages console / webhook restent en anglais et ne passent pas par `L()`.

### Interface
| Clé | en | fr |
|---|---|---|
| `title` | Admin | Administration |
| `tab_players` | Players | Joueurs |
| `tab_self` | Me | Moi |
| `tab_server` | Server | Serveur |
| `tab_bans` | Bans | Bans |
| `search` | Search by ID or name | Rechercher par ID ou nom |
| `refresh` | Refresh | Actualiser |
| `no_players` | No players | Aucun joueur |
| `ping_ms` | %s ms | %s ms |
| `player_warns` | Warnings: %s | Avertissements : %s |
| `frozen` | Frozen | Gelé |
| `back` | Back | Retour |
| `act_goto` | Go to | Aller à |
| `act_bring` | Bring | Ramener |
| `act_spectate` | Spectate | Observer |
| `act_freeze` | Freeze | Geler |
| `act_unfreeze` | Unfreeze | Dégeler |
| `act_heal` | Heal | Soigner |
| `act_revive` | Revive | Réanimer |
| `act_warn` | Warn | Avertir |
| `act_kick` | Kick | Expulser |
| `act_ban` | Ban | Bannir |
| `act_unban` | Unban | Lever le ban |
| `reason` | Reason | Raison |
| `duration` | Duration | Durée |
| `duration_hours` | %s h | %s h |
| `duration_days` | %s d | %s j |
| `duration_permanent` | Permanent | Permanent |
| `self_noclip` | Noclip | Noclip |
| `self_invisible` | Invisible | Invisible |
| `self_heal` | Heal me | Me soigner |
| `self_revive` | Revive me | Me réanimer |
| `state_on` | On | Activé |
| `state_off` | Off | Désactivé |
| `vehicle_title` | Vehicle | Véhicule |
| `vehicle_model` | Model name (e.g. adder) | Nom du modèle (ex. adder) |
| `vehicle_spawn` | Spawn | Faire apparaître |
| `vehicle_fix` | Repair | Réparer |
| `vehicle_delete` | Delete | Supprimer |
| `world_title` | Weather & time | Météo et heure |
| `world_weather` | Weather | Météo |
| `world_hour` | Hour | Heure |
| `world_minute` | Minute | Minute |
| `world_freeze` | Freeze time | Figer l'heure |
| `world_apply` | Apply | Appliquer |
| `weather_extrasunny` | Extra sunny | Grand soleil |
| `weather_clear` | Clear | Dégagé |
| `weather_clouds` | Clouds | Nuageux |
| `weather_overcast` | Overcast | Couvert |
| `weather_smog` | Smog | Brume de pollution |
| `weather_foggy` | Foggy | Brouillard |
| `weather_rain` | Rain | Pluie |
| `weather_thunder` | Thunderstorm | Orage |
| `weather_clearing` | Clearing | Éclaircies |
| `weather_snow` | Snow | Neige |
| `weather_xmas` | Christmas snow | Neige de Noël |
| `announce_title` | Announcement | Annonce |
| `announce_placeholder` | Message to all players | Message à tous les joueurs |
| `announce_send` | Send | Envoyer |
| `bans_empty` | No active bans | Aucun ban actif |
| `ban_by` | By %s | Par %s |
| `ban_until` | Until %s | Jusqu'au %s |
| `ban_permanent` | Permanent | Permanent |
| `hud_noclip` | Noclip | Noclip |
| `hud_invisible` | Invisible | Invisible |
| `hud_move` | Move | Déplacer |
| `hud_updown` | Up / down | Monter / descendre |
| `hud_fast` | Faster | Plus vite |
| `hud_slow` | Slower | Plus lent |
| `hud_spectating` | Spectating %s (ID %s) | Observation : %s (ID %s) |
| `hud_stop` | Stop | Arrêter |
| `announce_header` | Server announcement | Annonce du serveur |
| `warn_header` | Staff warning | Avertissement du staff |
| `keymap_open` | Open the admin panel | Ouvrir le panneau admin |
| `keymap_noclip` | Admin noclip | Noclip admin |

### Messages (Lua)
| Clé | en | fr |
|---|---|---|
| `invalid_target` | Invalid player | Joueur invalide |
| `player_not_found` | Player not found | Joueur introuvable |
| `self_target` | You can't do that to yourself | Impossible sur vous-même |
| `target_immune` | You can't do that to another admin | Impossible sur un autre admin |
| `invalid_reason` | Enter a reason (3 to 200 characters) | Saisissez une raison (3 à 200 caractères) |
| `invalid_duration` | Invalid duration | Durée invalide |
| `invalid_model` | Unknown vehicle model | Modèle de véhicule inconnu |
| `vehicle_not_found` | No vehicle nearby | Aucun véhicule à proximité |
| `ban_not_found` | Ban not found | Ban introuvable |
| `invalid_weather` | Invalid weather or time | Météo ou heure invalide |
| `world_disabled` | Weather sync is disabled | La synchro météo est désactivée |
| `invalid_message` | Enter a message (3 to 200 characters) | Saisissez un message (3 à 200 caractères) |
| `not_spectating` | You are not spectating | Vous n'observez personne |
| `done_goto` | Teleported to %s | Téléporté vers %s |
| `done_bring` | %s brought to you | %s amené à vous |
| `done_spectate` | Spectating %s | Observation de %s |
| `done_spectate_stop` | Spectating ended | Observation terminée |
| `done_freeze` | %s frozen | %s gelé |
| `done_unfreeze` | %s unfrozen | %s dégelé |
| `done_heal` | %s healed | %s soigné |
| `done_revive` | %s revived | %s réanimé |
| `done_warn` | %s warned | %s averti |
| `done_kick` | %s kicked | %s expulsé |
| `done_ban` | %s banned | %s banni |
| `done_unban` | Ban #%s lifted | Ban n°%s levé |
| `done_noclip_on` | Noclip enabled | Noclip activé |
| `done_noclip_off` | Noclip disabled | Noclip désactivé |
| `done_invisible_on` | You are invisible | Vous êtes invisible |
| `done_invisible_off` | You are visible | Vous êtes visible |
| `done_vehicle_spawn` | Vehicle spawned | Véhicule apparu |
| `done_vehicle_fix` | Vehicle repaired | Véhicule réparé |
| `done_vehicle_delete` | Vehicle deleted | Véhicule supprimé |
| `done_world` | Weather and time updated | Météo et heure mises à jour |
| `done_announce` | Announcement sent | Annonce envoyée |
| `you_frozen` | You have been frozen by staff | Vous avez été gelé par le staff |
| `you_unfrozen` | You have been unfrozen | Vous avez été dégelé |
| `you_healed` | You have been healed | Vous avez été soigné |
| `you_revived` | You have been revived | Vous avez été réanimé |
| `you_warned` | Staff warning: %s | Avertissement du staff : %s |
| `kick_message` | You were kicked: %s | Vous avez été expulsé : %s |
| `ban_message` | You are banned.\nReason: %s\nExpires: %s\nBan ID: %s | Vous êtes banni.\nRaison : %s\nExpiration : %s\nN° de ban : %s |
| `ban_checking` | Checking bans... | Vérification des bans... |

Clés de base réutilisées : `no_permission`, `cooldown`, `busy`, `error`, `confirm`, `close`.

---

## 10. Schéma SQL

`sql/install.sql` (le serveur exécute aussi ces `CREATE TABLE IF NOT EXISTS` au démarrage : aucune action manuelle) :

```sql
CREATE TABLE IF NOT EXISTS `pop_admin_bans` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `license`       VARCHAR(64)  NOT NULL,
    `identifiers`   TEXT         NOT NULL,             -- JSON : tableau des identifiants du joueur (sans IP)
    `name`          VARCHAR(64)  NOT NULL,
    `reason`        VARCHAR(255) NOT NULL,
    `admin`         VARCHAR(64)  NOT NULL,             -- nom affiché de l'admin (ou 'System' / by)
    `admin_license` VARCHAR(64)  NULL DEFAULT NULL,
    `created_at`    INT UNSIGNED NOT NULL,
    `expires_at`    INT UNSIGNED NULL DEFAULT NULL,    -- NULL = permanent
    `active`        TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    KEY `idx_active` (`active`),
    KEY `idx_license` (`license`)
);

CREATE TABLE IF NOT EXISTS `pop_admin_warns` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `license`       VARCHAR(64)  NOT NULL,
    `name`          VARCHAR(64)  NOT NULL,
    `reason`        VARCHAR(255) NOT NULL,
    `admin`         VARCHAR(64)  NOT NULL,
    `admin_license` VARCHAR(64)  NULL DEFAULT NULL,
    `created_at`    INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_license` (`license`)
);
```

**Identifiants** : `license` = `GetPlayerIdentifierByType(src, 'license')` (repli : parcours de
`GetPlayerIdentifiers`). Jamais `Bridge.GetIdentifier` (le citizenid change selon le personnage).
`identifiers` = tous les `GetPlayerIdentifiers(src)` dont le préfixe est `license`, `license2`, `steam`, `discord`,
`fivem`, `xbl`, `live` (**jamais `ip:`**). Noms tronqués à 64 caractères.

**Requêtes** : toujours paramétrées (`?`). Démarrage : `SELECT * FROM pop_admin_bans WHERE active = 1` → cache ;
`SELECT license, COUNT(*) AS n FROM pop_admin_warns GROUP BY license` → compteurs. Ban : `MySQL.insert.await`
(pour l'id). Unban / expiration : `MySQL.update('UPDATE pop_admin_bans SET active = 0 WHERE id = ?', { id })`.
Warn : `MySQL.insert`. Aucune requête dans `playerConnecting`.

---

## 11. Comportement attendu

### Serveur : `server/bans.lua` (table globale `Bans`)
```lua
Bans = {}
Bans.Ready                                     -- bool : cache chargé
Bans.Identifiers(src)          -> license, list   -- license (string|nil), list (identifiants filtrés)
Bans.Find(list)                -> ban | nil       -- ban actif non expiré correspondant à un identifiant ; expiré → Bans.Remove
Bans.Add(src, reason, hours, adminName, adminLicense) -> ban | nil   -- insert + cache (hours 0 = permanent)
Bans.Remove(banId)             -> bool            -- update active = 0 + retrait du cache
Bans.List()                    -> { BanRow, ... } -- 100 plus récents
Bans.ToRow(ban)                -> BanRow
Bans.Warn(src, reason, adminName, adminLicense)   -- insert + compteur + 1
Bans.WarnCount(license)        -> number
Bans.Message(ban)              -> string          -- L('ban_message', reason, expiresAt formaté ou L('ban_permanent'), id)
```
Cache : `bans[id] = { id, license, identifiers = { ... }, name, reason, admin, createdAt, expiresAt }` et index
`byIdentifier[identifiant] = id` (tous les identifiants de chaque ban).
`Bans.Ready = true` est posé par `server/main.lua` après le chargement (section suivante) ; `bans.lua` fournit la
fonction `Bans.Load()` (CREATE TABLE ×2 + SELECT ×2) appelée par `main.lua` au démarrage.

**`playerConnecting`** (dans `bans.lua`) :
```lua
AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update(L('ban_checking'))
    -- attendre Bans.Ready (max 10 s, Wait(100)) ; si jamais prêt : laisser entrer + log console
    local _, list = Bans.Identifiers(src)
    local ban = Bans.Find(list)
    if ban then deferrals.done(Bans.Message(ban)) else deferrals.done() end
end)
```
Expiration : `expiresAt ~= nil and expiresAt <= os.time()` → `Bans.Remove(id)` (silencieux) et le joueur entre.

### Serveur : `server/log.lua` (fonctions globales `AdminLog`, `AdminDenied`)
`AdminLog(src, action, target, details)` :
- Console : `[pop_admin] <adminName> (#src) <action> -> <targetName> (#target) | <details>` (partie cible / détails
  omise si absente). Pour les exports : `src = 0`, `adminName` = `by`.
- Webhook si `Config.Webhook` commence par `https://` : `PerformHttpRequest(url, function() end, 'POST', body,
  { ['Content-Type'] = 'application/json' })`, avec
  `body = json.encode({ username = 'pop_admin', allowed_mentions = { parse = {} }, embeds = { { title = action,
  description = <lignes Admin / Target / Details, avec license de l'admin et de la cible>, color = <Config.AccentColor
  converti en entier>, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') } } })`. Texte tronqué à 1000 caractères,
  `@` remplacé par `@\u{200B}` (anti-mention). Aucune donnée du webhook n'est renvoyée aux clients.
- `AdminDenied(src, action)` : console uniquement `[pop_admin] DENIED <name> (#src) <action>`, au plus une ligne
  toutes les 10 s par `src`.

### Serveur : `server/main.lua`
- **Démarrage** (thread) : `Bans.Load()` puis `Bans.Ready = true`.
  Avertissement console (anglais) si `GetConvar('onesync', 'off') == 'off'`. Si `Config.WorldSync` et qu'une
  ressource connue est lancée (`qb-weathersync`, `cd_easytime`, `vSync`, `Renewed-Weathersync`, `av_weather`) →
  avertissement console (on n'arrête rien). Si `Config.WorldSync` et `GlobalState['pop_admin:world'] == nil` →
  l'initialiser avec `Config.DefaultWorld` + `t = os.time()` (conservé lors d'un restart de la ressource).
- **État en mémoire** (par src) : `frozen[src] = true`, `modes[src] = { noclip = bool, invisible = bool }`,
  `spectating[src] = { target = int, bucket = int }`, `busy[src]`, `lastAction[src] = ms`,
  `lastAnnounce[src] = ms`, `spawned[src] = netId`.
- **Heure courante** : `WorldNow()` → `{ weather, hour, minute, frozen }` avec
  `total = (s.hour * 60 + s.minute + (s.frozen and 0 or math.floor((os.time() - s.t) / GAME_MINUTE))) % 1440`.
- **`pop_admin:open`** : `Bridge.IsAdmin` sinon `false` (+ `AdminDenied`). Renvoie `OpenData`.
- **`pop_admin:getPlayers`** : `Bridge.IsAdmin` sinon `false`. `PlayerRow` pour chaque `GetPlayers()`.
- **`pop_admin:getBans`** : `HasPermission(src, 'unban')` sinon `false`. `Bans.List()`.
- **`pop_admin:action`** : pipeline unique (section 12), puis exécution :

| action | Exécution (après contrôles) | Notif admin | Log |
|---|---|---|---|
| `goto` | si bucket différent : `SetPlayerRoutingBucket(src, GetPlayerRoutingBucket(target))` ; `TriggerClientEvent('pop_admin:client:teleport', src, coords cible + (1.0, 0, 0))` | `done_goto` | oui |
| `bring` | bucket cible ← bucket admin ; `teleport` à `target` avec coords admin + (1.0, 0, 0) | `done_bring` | oui |
| `spectate` (target) | si `modes[src].noclip` → couper (event `setMode`) ; `spectating[src] = { target, bucket = bucket admin }` ; bucket admin ← bucket cible ; `TriggerClientEvent('pop_admin:client:spectate', src, target, coords, name)` | `done_spectate` | oui |
| `spectate` (nil) | si pas `spectating[src]` → `not_spectating` ; rétablir le bucket ; `spectate` → `false` ; effacer | `done_spectate_stop` | non |
| `freeze` | bascule `frozen[target]` ; `TriggerClientEvent('pop_admin:client:freeze', target, state)` ; `Bridge.Notify(target, L(state and 'you_frozen' or 'you_unfrozen'), 'warning')` | `done_freeze` / `done_unfreeze` | oui |
| `heal` | `pop_admin:client:heal` à `target` ; `Bridge.Notify(target, L('you_healed'), 'success')` | `done_heal` | oui |
| `revive` | `pop_admin:client:revive` à `target` ; `you_revived` | `done_revive` | oui |
| `warn` | `Bans.Warn(...)` ; `pop_admin:client:warn` à `target` avec la raison | `done_warn` | oui (raison) |
| `kick` | `DropPlayer(target, L('kick_message', reason))` (log **avant** le drop) | `done_kick` | oui (raison) |
| `ban` | `Bans.Add(...)` (busy) ; échec → `error` ; puis `DropPlayer(target, Bans.Message(ban))` | `done_ban` | oui (raison, durée, id) |
| `unban` | `Bans.Remove(banId)` ; absent → `ban_not_found` | `done_unban` | oui (id) |
| `noclip` | refus pendant un spectate → `busy` ; bascule `modes[src].noclip` ; `setMode('noclip', state)` | `done_noclip_on/off` | oui |
| `invisible` | bascule `modes[src].invisible` ; `setMode('invisible', state)` | `done_invisible_on/off` | oui |
| `vehicle_spawn` | supprimer `spawned[src]` s'il existe encore ; `CreateVehicleServerSetter(joaat(model), vtype, x, y, z, heading)` aux coords / heading serveur de l'admin ; attendre `DoesEntityExist` (2 s max, `Wait(50)`) sinon `invalid_model` ; `SetEntityRoutingBucket(veh, bucket admin)` ; `SetPedIntoVehicle(ped, veh, -1)` ; `spawned[src] = NetworkGetNetworkIdFromEntity(veh)` | `done_vehicle_spawn` | oui (modèle) |
| `vehicle_fix` | `TriggerClientEvent('pop_admin:client:fixVehicle', NetworkGetEntityOwner(veh), netId)` | `done_vehicle_fix` | oui |
| `vehicle_delete` | `DeleteEntity(veh)` ; si `spawned[src]` = ce netId → effacer | `done_vehicle_delete` | oui |
| `world` | `GlobalState['pop_admin:world'] = { weather, hour, minute, frozen, t = os.time() }` | `done_world` | oui |
| `announce` | `TriggerClientEvent('pop_admin:client:announce', -1, message)` | `done_announce` | oui (message) |

- **Déconnexion** (`Bridge.OnPlayerDropped(src)`) : nettoyage de l'état ; pour chaque admin `a` avec
  `spectating[a].target == src` : rétablir son bucket, `spectate` → `false`, `Bridge.Notify(a, L('done_spectate_stop'))`.

### Client : `client/main.lua`
- **Touches** : `RegisterCommand(Config.Command, toggle)` + `RegisterKeyMapping(Config.Command, L('keymap_open'),
  'keyboard', Config.OpenKey)`. Commande `popadmin_noclip` → `Callback.Await('pop_admin:action', 'noclip')`
  (échec → notification) + `RegisterKeyMapping('popadmin_noclip', L('keymap_noclip'), 'keyboard', Config.NoclipKey)`.
  Aucune vérification d'admin côté client : le serveur répond.
- **Ouvrir** : `Callback.Await('pop_admin:open')` → `false`/nil → `Bridge.Notify(L('no_permission'), 'error')` ;
  sinon `SendNUIMessage(pop_admin:open)` + `SetNuiFocus(true, true)`. **Fermer** : `SetNuiFocus(false, false)` +
  `pop_admin:close`. `Bridge.OnUiClose` → `open = false` (le focus est déjà rendu).
- **NUI callbacks** : `players`, `bans`, `action` (section 6).
- **`teleport`** : `RequestCollisionAtCoord` ; conducteur d'un véhicule → `SetEntityCoords` du véhicule, sinon du
  ped ; attendre `HasCollisionLoadedAroundEntity` (2 s max, `Wait(50)`).
- **`freeze`** : `FreezeEntityPosition(ped, state)` (+ véhicule occupé) ; tant que gelé : boucle `Wait(1000)` qui
  réapplique (nouveau ped après respawn) ; dégel → arrêt de la boucle et `FreezeEntityPosition(false)`.
- **`heal`** : `SetEntityHealth(ped, GetEntityMaxHealth(ped))`, `ClearPedBloodDamage(ped)` ; puis, selon la
  ressource lancée : `esx_basicneeds` → `TriggerEvent('esx_basicneeds:healPlayer')` ; `qb-ambulancejob` →
  `TriggerEvent('hospital:client:adminHeal')`. (NOTE: qbx_medical : pas d'event de soin confirmé, natives seules.)
- **`revive`** : `Config.ReviveEvent ~= ''` → `TriggerEvent(Config.ReviveEvent)` ; sinon `esx_ambulancejob` →
  `TriggerEvent('esx_ambulancejob:revive')` ; `qb-ambulancejob` → `TriggerEvent('hospital:client:Revive')` ;
  `qbx_medical` → `TriggerEvent('qbx_medical:client:playerRevived')` (NOTE: nom à confirmer selon la version de
  qbx_medical) ; aucun → natives : `NetworkResurrectLocalPlayer(coords, heading, true, false)`,
  `SetEntityHealth(max)`, `ClearPedTasksImmediately`, `ClearPedBloodDamage`. Le README documente
  `Config.ReviveEvent` pour les autres scripts de mort (wasabi_ambulance, etc.).
- **`warn`** : `Bridge.Notify(L('you_warned', reason), 'warning')` + NUI `pop_admin:warn`.
- **`announce`** : NUI `pop_admin:announce` (`duration = Config.AnnounceDuration * 1000`).
- **`fixVehicle`** : `NetToVeh(netId)` existant → `SetVehicleFixed`, `SetVehicleDeformationFixed`,
  `SetVehicleEngineHealth(veh, 1000.0)`, `SetVehicleDirtLevel(veh, 0.0)`.
- **Arrêt** : fermer le panneau, dégeler, `pop_admin:close`.

### Client : `client/modes.lua` (table globale `Modes = { noclip = false, invisible = false, spectating = nil }`)
- **`setMode`** : met à jour `Modes`, envoie `pop_admin:modes` + `pop_admin:hud`, démarre la boucle si besoin.
- **Boucle des modes** (une seule, `Wait(0)`, **uniquement** si `Modes.noclip or Modes.invisible or
  Modes.spectating`, s'arrête d'elle-même sinon) :
  - **invisible** (ou noclip) : `SetEntityVisible(ped, false, false)` à l'activation ; chaque frame
    `SetEntityLocallyVisible(ped)` + `SetEntityAlpha(ped, 102, false)` (l'admin se voit en transparence, les autres
    ne le voient pas). En spectate : invisible, sans visibilité locale.
  - **noclip** : à l'activation `SetEntityCollision(ent, false, false)`, `FreezeEntityPosition(ent, true)`,
    `SetEntityInvincible(ent, true)` (ent = véhicule si conducteur, sinon ped). Chaque frame : direction caméra
    (`GetGameplayCamRot`), W/S (32/33) avant/arrière, A/D (34/35) latéral, Q/E (44/38) bas/haut, SHIFT (21) × 4,
    ALT (19) × 0.25 ; `SetEntityCoordsNoOffset`, `SetEntityHeading` = cap caméra ; `DisableControlAction` sur ces
    touches et 24/25/140/141/142 (combat).
  - **spectate** : `IsControlJustPressed(0, STOP_CONTROL)` → `Callback.Await('pop_admin:action', 'spectate')`
    (dans un thread séparé, une seule demande à la fois).
  - Désactivation d'un mode : restaurer collision, gel, invincibilité, alpha (`ResetEntityAlpha`), visibilité
    (`SetEntityVisible(ped, true, false)` seulement si plus aucun mode qui cache).
- **`spectate`** (target int) : sauvegarder coords + heading ; masquer, figer, sans collision ;
  `SetEntityCoords(ped, coords.x, coords.y, coords.z - 15.0)` ; attendre `GetPlayerFromServerId(target) ~= -1` et
  son ped (5 s max, `Wait(100)`) sinon demander l'arrêt ; `NetworkSetInSpectatorMode(true, targetPed)`. Thread
  `Wait(1000)` : replacer l'admin sous la cible (streaming) ; cible introuvable 5 s → demander l'arrêt.
  `pop_admin:hud` avec `spectate = { id, name }`.
- **`spectate`** (`false`) : `NetworkSetInSpectatorMode(false, 0)`, retour aux coords sauvegardées (collision
  chargée), restaurer l'état selon `Modes.invisible` / `Modes.noclip`, HUD mis à jour.
- **Arrêt de la ressource** : sortir du spectate, restaurer collision / gel / visibilité / alpha / invincibilité,
  `pop_admin:hud` tout à false.

### Client : `client/world.lua`
- Si `not Config.WorldSync` → rien (aucune boucle).
- Lecture de `GlobalState['pop_admin:world']` + `AddStateBagChangeHandler('pop_admin:world', 'global', fn)`.
- Changement de météo : `ClearOverrideWeather()`, `ClearWeatherTypePersist()`, `SetWeatherTypeOverTime(w, 15.0)`,
  puis après 15 s : `SetWeatherTypePersist(w)`, `SetWeatherTypeNow(w)`, `SetWeatherTypeNowPersist(w)`.
  `XMAS` → `SetForceVehicleTrails(true)`, `SetForcePedFootstepsTracks(true)`, sinon `false`.
  Première application (connexion) : directe, sans transition.
- Boucle unique `Wait(1000)` : `total = (s.hour * 60 + s.minute + (s.frozen and 0 or math.floor((GetCloudTimeAsInt()
  - s.t) / 2))) % 1440` → `NetworkOverrideClockTime(total // 60, total % 60, 0)` ; hors transition :
  `SetWeatherTypeNowPersist(s.weather)`.
- Arrêt : `ClearOverrideWeather()`, `ClearWeatherTypePersist()`.

---

## 12. Règles de sécurité (serveur, toutes obligatoires)

Le client n'est jamais cru. Le JS et le client Lua n'ont **aucun** pouvoir : ils n'envoient que `action`, `target`
et `data`, tout est revérifié. Aucun `RegisterNetEvent` serveur.

**Pipeline de `pop_admin:action`** (dans cet ordre, premier échec = retour immédiat) :
1. `type(action) == 'string'` et `ACTIONS[action]` existe, sinon `error`.
2. `HasPermission(src, ACTIONS[action].perm)` (revérifié **à chaque appel**, jamais mis en cache), sinon
   `no_permission` + `AdminDenied`.
3. Anti-spam : `GetGameTimer() - lastAction[src] < ACTION_COOLDOWN` → `cooldown` (arg = `math.ceil(reste / 1000)`).
   `announce` : en plus `ANNOUNCE_COOLDOWN` (`lastAnnounce`). `lastAction[src]` mis à jour dès que l'étape 2 est
   passée. L'anti-spam du template (`Config.CallbackRateLimit`) reste actif sur tous les callbacks.
4. `busy[src]` → `busy` ; posé pendant les attentes (SQL, création de véhicule) et libéré **dans tous les cas**
   (pcall ou libération avant chaque `return`) et à la déconnexion.
5. **Cible** selon `ACTIONS[action].target` :
   - `required` / `self_ok` : `math.type(target) == 'integer'`, sinon `invalid_target` ; `GetPlayerName(target)`
     non nil et `GetPlayerPed(target) ~= 0`, sinon `player_not_found` ; `required` et `target == src` →
     `self_target`.
   - `optional` (spectate) : `nil` = arrêt ; sinon mêmes règles que `required`.
   - `none` : `target` ignoré.
   - `immune` et `Bridge.IsAdmin(target)` → `target_immune`.
6. **`data`** : `type(data) == 'table'` sinon `{}` ; chaque champ contrôlé :
   - `reason` (warn, kick, ban) / `message` (announce) : string ; caractères de contrôle remplacés
     (`gsub('%c', ' ')`), trim ; `utf8.len` valide et entre `TEXT_MIN` et `TEXT_MAX`, sinon `invalid_reason` /
     `invalid_message`.
   - `duration` (ban) : `math.type == 'integer'` **et** présent dans `Config.BanDurations`, sinon
     `invalid_duration`. `0` = permanent (`expires_at = NULL`), sinon `os.time() + duration * 3600`.
   - `banId` (unban) : entier > 0 présent dans le cache, sinon `ban_not_found`.
   - `model` (vehicle_spawn) : string, 1-32 caractères, motif `^[%w_]+$`, sinon `invalid_model` ;
     `vtype` ∈ `{ automobile, bike, boat, heli, plane, submarine }`, sinon `invalid_model`.
   - `netId` (vehicle_fix / delete) : entier ; `NetworkGetEntityFromNetworkId(netId)` existe
     (`DoesEntityExist`) et `GetEntityType(veh) == 2`, sinon `vehicle_not_found` ;
     `Bridge.IsNear(src, GetEntityCoords(veh), VEHICLE_RANGE)`, sinon `too_far`.
   - `world` : `Config.WorldSync` sinon `world_disabled` ; `weather` présent dans `Config.Weathers` ; `hour` entier
     0-23 ; `minute` entier 0-59 ; `frozen` booléen strict ; sinon `invalid_weather`.
7. Exécution (section 11), notification de succès, `AdminLog`.

**Règles complémentaires**
- Coordonnées, buckets, noms, licences : **toujours lus côté serveur** (`GetEntityCoords(GetPlayerPed(x))`,
  `GetPlayerRoutingBucket`), jamais reçus du client.
- Noclip / invisible / spectate : seul le serveur envoie `setMode` / `spectate` ; l'état fait foi côté serveur
  (`modes`, `spectating`), remis à zéro à la déconnexion. Un client qui appelle `noclip` sans droit reçoit
  `no_permission` et rien n'est envoyé.
- Heal / revive / freeze / teleport / fixVehicle : events client déclenchés **uniquement** par le serveur après le
  pipeline ; les events de framework (esx_ambulancejob, qb-ambulancejob, qbx_medical, esx_basicneeds) sont
  appelés en local (`TriggerEvent`) par le client **ciblé**, à réception de l'event serveur.
- Ban : le cache est mis à jour **après** un `insert` réussi ; échec SQL → `error` et pas de drop. Les admins ne
  peuvent pas se bannir entre eux (immune). `DropPlayer` toujours après le log.
- `playerConnecting` : aucune requête SQL, aucune donnée client ; identifiants lus par le serveur, IP ignorée.
- Données envoyées aux clients : jamais d'identifiant (license, steam, discord, IP), jamais le webhook.
  `getBans` exige le droit `unban`.
- Webhook : uniquement dans `config_server.lua` (serveur), mentions Discord neutralisées
  (`allowed_mentions.parse = {}` + `@` échappé).
- NUI : toutes les données joueur affichées en `textContent` (noms et raisons = entrées hostiles).
- Exports serveur : appelables uniquement par d'autres ressources serveur ; `BanPlayer` valide `src` (connecté),
  `reason` (mêmes règles) et `hours` (entier ≥ 0).

---

## 13. Checklist de livraison (pour l'auditeur)
- `luacheck resources templates` : 0 erreur ; `node --check web/script.js`.
- `bridge/`, `shared/`, `web/kit/` identiques octet pour octet à `templates/pop_base`.
- 10 locales avec **toutes** les clés (base + section 9) ; aucun texte en dur (Lua, HTML, JS, placeholders).
- Aucun `RegisterNetEvent` serveur ; chaque branche de `pop_admin:action` passe par le pipeline complet.
- Le webhook n'apparaît que dans `config_server.lua` (absent de `config.lua` et de tout fichier client).
- Aucun `Wait(0)` hors modes noclip / invisible / spectate ; aucune boucle client au repos sauf météo (1000 ms).
- Kick / ban / freeze / warn impossibles sur un admin et sur soi ; ban vérifié à la connexion sur tous les
  identifiants (sauf IP), expiration respectée.
- Fonctionne avec ESX (Legacy et ancien), QBCore, Qbox et standalone (ACE `pop.admin` seule).
