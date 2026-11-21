# pop_interim : SPEC (contrat commun Serveur / Client / NUI)

> Ce document est **la référence unique**. Les noms (fichiers, events, callbacks, clés de config, clés de locale,
> champs de données, messages NUI) doivent être repris **à l'identique**. En cas de doute : ce fichier fait foi.
> API commune à utiliser telle quelle : `Bridge.*`, `Callback.*`, `L()` (voir `templates/pop_base/README.md`).

---

## 1. Description et fonctionnalités

Agence d'intérim (pôle emploi) : le joueur va au guichet, choisit un métier **public** dans une courte liste
définie en config, confirme, et le serveur lui attribue ce job dans le framework. Il peut aussi démissionner
(retour au job « sans emploi »). Un délai empêche de changer de métier en boucle.

**Boucle de jeu**
1. **Aller au guichet** : PNJ (ou zone) à l'agence, blip sur la carte. Option `[E] Agence d'intérim`.
2. **Choisir** : petit panneau sur le côté droit, liste des métiers (nom + courte description). Un clic
   sélectionne la ligne (étape 1), le bouton **Confirmer** valide (étape 2). Jamais d'attribution en un clic.
3. **Le serveur valide** (distance, liste blanche, job existant dans le framework, délai) et appelle `setJob`.
   Notification de succès, fermeture du panneau.
4. **Démissionner** : bouton discret dans le panneau si le joueur a un job autre que `Config.Unemployed.job`.

**Règles**
- Seuls les métiers de `Config.Jobs` peuvent être obtenus : le client n'envoie qu'un `id` de cette liste.
- Un métier dont le job n'existe pas dans le framework est **masqué** (avertissement console au démarrage).
- Délai `Config.Cooldown` entre deux changements (prise de job ou démission), par identifiant, en mémoire.
- Standalone : aucun job à attribuer → l'agence répond `not_available` (avertissement console au démarrage).

**HUD / UI** : panneau `pop-panel` à droite (≈ 300 px), focus NUI pendant l'ouverture seulement. Fondu 150 ms.

**Performance** : un seul thread client adaptatif pour les PNJ (spawn local à ≤ 40 m) ; aucun `Wait(0)`.
Pendant l'ouverture, une vérification de distance toutes les 500 ms (fermeture si > 3 m). Serveur : aucune boucle.

**Hors périmètre** : caméras de prévisualisation, décors de PNJ/véhicules, job2, salaires, création de jobs en base.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_interim/
  SPEC.md                 Architecte (ce fichier)
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR   (clés communes de pop_base + section 8, à l'identique)
  README.md               SERVEUR   (en ANGLAIS : installation, ajout d'un métier, compatibilité)
  locales/en.lua … ar.lua SERVEUR   10 fichiers (en fr es de it pt nl pl tr ar), ar : _rtl = true
  server/main.lua         SERVEUR   callbacks, délai, verrous, exports
  server/jobs.lua         SERVEUR   fonctions locales au script : JobExists / SetJob par framework (section 11)
  client/main.lua         CLIENT    blip, PNJ, target, ouverture/fermeture, callbacks NUI
  web/index.html          NUI
  web/script.js           NUI
  web/style.css           NUI
```

`bridge/`, `shared/callback.lua`, `shared/locale.lua` et `web/kit/` sont **copiés par l'intégrateur** depuis
`templates/pop_base` (personne ne les écrit ni ne les modifie ici). Le Dev Serveur écrit les 10 locales en
fusionnant le bloc « Kit commun » de pop_base (inchangé) et les clés de la section 9.

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_interim'
author 'POP'
version '1.0.0'
description 'POP Interim - public job center'

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
}
```
Pas d'oxmysql (aucun stockage).

---

## 3. Données

### `JobOffer` (serveur → client)
```lua
{ id = 'taxi' }   -- id de Config.Jobs ; libellés via les locales job_<id> et job_<id>_desc
```

### `CurrentJob` (serveur → client)
```lua
{ id = 'taxi' | nil,   -- id de Config.Jobs si le job actuel (name + grade) y correspond, sinon nil
  label = 'Taxi',      -- Bridge.GetJob(src).label (texte du framework, affiché tel quel)
  unemployed = false } -- true si job.name == Config.Unemployed.job
```

---

## 4. Events

Aucun event réseau propre au script : tout passe par les callbacks (section 5) et `Bridge.Notify`.

Le verrou et le délai sont indexés par **identifiant**. Le délai survit à la reconnexion jusqu’à son expiration.

---

## 5. Callbacks (`shared/callback.lua`)

Convention : `ok (bool), reason (clé de locale) | nil, arg | nil`. Échec → le **client** affiche
`Bridge.Notify(L(reason or 'error', arg), 'error')`. Succès → le **serveur** notifie. `nil` (timeout, anti-spam)
= `reason = 'error'`.

| Nom | Paramètres (client → serveur) | Retour |
|---|---|---|
| `pop_interim:getJobs` | `loc` (int, index de `Config.Locations`) | `ok, reason, arg, jobs` (tableau séquentiel de JobOffer), `current` (CurrentJob), `cooldown` (int, secondes restantes, 0 si aucun) |
| `pop_interim:selectJob` | `loc` (int), `id` (string) | `ok, reason, arg` |
| `pop_interim:resign` | `loc` (int) | `ok, reason, arg` |

Raisons possibles : `error`, `busy`, `too_far`, `not_available`, `job_unknown`, `already_job`,
`already_unemployed`, `cooldown` (arg = secondes restantes).

Aucun callback serveur → client.

---

## 6. Messages NUI

Le panneau prend le focus (`SetNuiFocus(true, true)`) à l'ouverture ; le focus est rendu à la fermeture.
Échap → le kit envoie `close` → `Bridge.OnUiClose` (le client remet son état à zéro et envoie `pop_interim:close`).

### Lua → JS
```json
{ "action": "pop_interim:open",
  "jobs": [ { "id": "taxi" }, { "id": "trucker" } ],
  "current": { "id": null, "label": "Unemployed", "unemployed": true },
  "cooldown": 0 }
```
```json
{ "action": "pop_interim:close" }
```

### JS → Lua (`RegisterNUICallback`)
| Nom | Données envoyées | Réponse |
|---|---|---|
| `pop_interim:select` | `{ "id": "taxi" }` | `{ "ok": true }` ou `{ "ok": false }` |
| `pop_interim:resign` | `{}` | `{ "ok": true }` ou `{ "ok": false }` |
| `close` | (kit) | géré par le bridge |

Le client appelle le callback serveur correspondant ; succès → ferme le panneau (focus rendu, `pop_interim:close`) ;
échec → notification (section 5), panneau laissé ouvert. Le JS bloque les boutons tant que la réponse n'est pas
arrivée (pas de double envoi).

### Interface (Dev NUI)
- `web/index.html` : `<link rel="stylesheet" href="style.css">` après `kit/pop.css`. `#app` remplacé par
  `#interim` (`pop-panel pop-fade`, masqué par défaut) :
  - titre `data-locale="ui_title"` ; ligne `#interim-current` : `Pop.t('ui_current', current.label)` ;
  - liste `#interim-list` : une ligne par job : `Pop.t('job_' + id)` + en dessous, **seulement sur la ligne
    sélectionnée**, `Pop.t('job_' + id + '_desc')` en `pop-small` ; ligne du job actuel marquée
    `Pop.t('ui_current_tag')` (petit, accent) et non sélectionnable ;
  - pied : bouton `#interim-confirm` (`pop-button`, `data-locale="confirm"`), désactivé sans sélection ;
    lien `#interim-resign` (`pop-small`, `data-locale="ui_resign"`) masqué si `current.unemployed` ;
    ligne `#interim-cooldown` : `Pop.t('cooldown', s)` si `cooldown > 0` (décompte local chaque seconde,
    boutons désactivés jusqu'à 0) ;
  - bouton `#interim-close` (`data-locale="close"`) → `Pop.post('close')`.
- Clavier : ↑/↓ change la sélection, Entrée = Confirmer.
- `web/style.css` : `position: fixed; right: 24px; top: 50%; transform: translateY(-50%); width: 300px;`
  liste max 50vh avec défilement ; ligne sélectionnée = bordure gauche 2 px accent (`border-inline-start`) ;
  aucun dégradé, aucune image. RTL : `right: auto; left: 24px`.
- Aucun texte en dur.

---

## 7. Exports publics

Serveur :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_interim:GetCooldown(src)` | int | secondes restantes avant un nouveau changement (0 si aucun) |
| `exports.pop_interim:ResetCooldown(src)` | bool | supprime le délai du joueur (admin, autre script) |

Client :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_interim:IsOpen()` | bool | panneau ouvert |

---

## 8. config.lua (contenu exact)

Reprend **à l'identique** le `config.lua` de `templates/pop_base`, puis ajoute :

```lua
-- ─── pop_interim ────────────────────────────────────────────

-- Guichets. ped = modèle du PNJ (false : simple zone d'interaction). blip = afficher sur la carte.
Config.Locations = {
    { coords = vector4(-268.0, -957.0, 31.22, 205.0), ped = 'a_f_y_business_02', blip = true },
}

Config.Blip = { sprite = 407, color = 27, scale = 0.8 }

-- Métiers proposés. id = identifiant interne (libellés : locales job_<id> et job_<id>_desc).
-- job = nom EXACT du job dans le framework, grade = grade attribué.
Config.Jobs = {
    { id = 'taxi',    job = 'taxi',    grade = 0 },
    { id = 'trucker', job = 'trucker', grade = 0 },
    { id = 'tow',     job = 'tow',     grade = 0 },
    { id = 'garbage', job = 'garbage', grade = 0 },
}

-- Job attribué lors d'une démission.
Config.Unemployed = { job = 'unemployed', grade = 0 }

-- Délai entre deux changements de métier (secondes).
Config.Cooldown = 300
```

Constantes (dans le code, pas en config) : `ACTION_DISTANCE = 3.0` (serveur, `Bridge.IsNear`),
`TARGET_DISTANCE = 2.0` (client), `PED_DISTANCE = 40.0` (client, spawn du PNJ).

---

## 9. Locales

10 fichiers : `en` (défaut + repli), `fr`, `es`, `de`, `it`, `pt`, `nl`, `pl`, `tr`, `ar` (`_rtl = true`).
Bloc « Kit commun » inchangé + clés ci-dessous sous `-- Textes propres au script :`. Mêmes `%s` partout.

| Clé | en | fr |
|---|---|---|
| `blip_name` | Job Center | Agence d'intérim |
| `target_open` | Job Center | Agence d'intérim |
| `ui_title` | Job Center | Agence d'intérim |
| `ui_current` | Current job: %s | Métier actuel : %s |
| `ui_current_tag` | Current | Actuel |
| `ui_resign` | Resign | Démissionner |
| `job_taxi` | Taxi driver | Chauffeur de taxi |
| `job_taxi_desc` | Drive customers around the city | Conduire des clients en ville |
| `job_trucker` | Trucker | Routier |
| `job_trucker_desc` | Deliver goods across the state | Livrer des marchandises dans l'État |
| `job_tow` | Tow truck driver | Dépanneur |
| `job_tow_desc` | Tow broken-down and abandoned vehicles | Remorquer les véhicules en panne ou abandonnés |
| `job_garbage` | Garbage collector | Éboueur |
| `job_garbage_desc` | Keep the streets clean | Garder les rues propres |
| `job_set` | You are now: %s | Vous êtes maintenant : %s |
| `resigned` | You resigned | Vous avez démissionné |
| `not_available` | The job center is closed | L'agence d'intérim est fermée |
| `job_unknown` | This job is not available | Ce métier n'est pas disponible |
| `already_job` | You already have this job | Vous avez déjà ce métier |
| `already_unemployed` | You don't have a job | Vous n'avez pas de métier |

Clés de base réutilisées : `confirm`, `close`, `cooldown`, `too_far`, `busy`, `error`.
`job_set` reçoit le libellé traduit `L('job_' .. id)`. Ajouter un métier = une entrée dans `Config.Jobs` + 2 clés
(`job_<id>`, `job_<id>_desc`) au moins dans `en.lua` (repli). Logs console en anglais, sans `L()`.

---

## 10. Schéma SQL

Aucun.

---

## 11. Comportement attendu

### `server/jobs.lua` (Dev Serveur) : fonctions **locales au script** (globales `InterimJobs.*`)
| Fonction | Retour | Implémentation |
|---|---|---|
| `InterimJobs.Exists(job, grade)` | bool | ESX : `ESX.DoesJobExist(job, grade)` si la fonction existe, sinon `true` (NOTE: ancien ESX) ; QBCore : `QBCore.Shared.Jobs[job]` et `grades[tostring(grade)]` ; Qbox : `exports.qbx_core:GetJob(job)` et `grades[grade]` ; standalone : `false` |
| `InterimJobs.Set(src, job, grade)` | bool | ESX : `Bridge.GetPlayer(src).setJob(job, grade)` → `true` ; QBCore : `Bridge.GetPlayer(src).Functions.SetJob(job, grade)` (renvoie un bool) ; Qbox : `exports.qbx_core:SetJob(src, job, grade)` (signature `(identifier, jobName, grade)`, identifiant = source ou citizenid) ; standalone : `false` |

- Objet ESX : `pcall(exports.es_extended.getSharedObject)`, sinon `TriggerEvent('esx:getSharedObject', ...)` (NOTE).
  Objet QBCore : `exports['qb-core']:GetCoreObject()`. L’attribution est confirmée en relisant le métier et le grade via `Bridge.GetJob`.
- Au démarrage (thread, après 2 s) : pour chaque entrée de `Config.Jobs`, `available[id] = InterimJobs.Exists(...)` ;
  print anglais pour chaque job absent. Standalone : un seul print (« job center disabled in standalone »).

### Serveur (`server/main.lua`)
- `cooldowns[identifier] = os.time() + Config.Cooldown` après chaque succès.
- `getJobs` : contrôles communs (section 12, 1-3) puis renvoie les offres disponibles (`available[id]`), le job
  actuel et le délai restant.
- `selectJob` succès : `Bridge.Notify(src, L('job_set', L('job_' .. id)), 'success')`.
- `resign` succès : `Bridge.Notify(src, L('resigned'), 'success')`.

### Client (`client/main.lua`)
- Blips (`Config.Blip`, nom `L('blip_name')`, `SetBlipAsShortRange`) pour les lieux `blip = true`.
- Boucle unique : pour chaque lieu avec `ped`, crée le PNJ local à ≤ `PED_DISTANCE` (RequestModel timeout 3 s,
  `CreatePed(4, hash, x, y, z - 1.0, w, false, false)`, figé, invincible, `SetBlockingOfNonTemporaryEvents`,
  scénario `WORLD_HUMAN_CLIPBOARD`), supprime à > `PED_DISTANCE + 10`. Target : `Bridge.Target.AddLocalEntity(ped, opts)`
  à la création, `Remove` à la suppression. Lieux sans `ped` : `Bridge.Target.AddBoxZone('pop_interim_' .. i, xyz,
  vec3(1.5, 1.5, 2.0), w, opts)` au démarrage. `Wait(nearest < PED_DISTANCE and 1000 or 2500)`.
- Option : `{ label = L('target_open'), icon = 'fa-solid fa-briefcase', distance = TARGET_DISTANCE, onSelect = open(i) }`.
- `open(i)` : ignoré si déjà ouvert ou `Bridge.IsBusy()` ; `Callback.Await('pop_interim:getJobs', i)` ; échec →
  notification ; succès → `SetNuiFocus(true, true)`, `pop_interim:open`. Thread de surveillance (500 ms) tant
  qu'ouvert : distance au lieu > 3.0 ou joueur mort → fermeture.
- Arrêt de la ressource : PNJ, blips supprimés ; `pop_interim:close` (le bridge rend le focus et retire les targets).

---

## 12. Règles de sécurité (serveur, obligatoires)

Le client n'envoie qu'un index de lieu et un `id`. Job, grade, délai : config et serveur uniquement.
1. `loc` : `math.type(loc) == 'integer'` et `Config.Locations[loc]` existe, sinon `error`.
2. `Bridge.IsNear(src, Config.Locations[loc].coords, ACTION_DISTANCE)`, sinon `too_far`.
3. `Bridge.Framework ~= 'standalone'`, sinon `not_available`. `Bridge.GetIdentifier(src)` et `Bridge.GetJob(src)`
   non nil, sinon `error`.
4. Verrou par identifiant pendant le traitement → `busy` ; libéré à la fin de l’opération. Les joueurs morts sont refusés.
5. Délai : `cooldowns[identifier] > os.time()` → `cooldown`, arg = secondes restantes.
6. `selectJob` : `id` est une string présente dans `Config.Jobs` **et** `available[id]`, sinon `job_unknown` ;
   job actuel `name == entry.job` et `grade == entry.grade` → `already_job` ; `InterimJobs.Set` faux → `error`
   (pas de délai posé).
7. `resign` : job actuel `== Config.Unemployed.job` → `already_unemployed` ; puis `InterimJobs.Set(src,
   Config.Unemployed.job, Config.Unemployed.grade)`.
8. Anti-spam du template actif (`Config.CallbackRateLimit`).

---

## 13. Checklist de livraison (auditeur)
- `luacheck resources templates` : 0 erreur ; `node --check web/script.js`.
- `bridge/`, `shared/`, `web/kit/` identiques à `templates/pop_base`.
- 10 locales complètes ; aucun texte en dur (Lua, HTML, JS).
- Aucun `Wait(0)` ; PNJ locaux ; focus NUI rendu dans tous les cas (Échap, éloignement, mort, arrêt).
- ESX (Legacy et ancien), QBCore, Qbox ; ox_target, qb-target, prompt natif ; standalone : démarre sans erreur.
