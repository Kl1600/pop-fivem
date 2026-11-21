# pop_management : SPEC (contrat commun Serveur / Client / NUI)

> Ce document est **la référence unique**. Les noms (fichiers, events, callbacks, clés de config, clés de locale,
> champs de données, messages NUI) doivent être repris **à l'identique**. En cas de doute : ce fichier fait foi.
> API commune à utiliser telle quelle : `Bridge.*`, `Callback.*`, `L()` (voir `templates/pop_base/README.md`).
> `bridge/`, `shared/`, `web/kit/` sont copiés tels quels depuis `templates/pop_base` (jamais modifiés ici).

---

## 1. Description et fonctionnalités

Gestion d'entreprise simple : un **panneau patron** sobre, sur le côté de l'écran, pour gérer les employés et le
compte de la société, plus des **factures** envoyées par les employés à leurs clients.

**Accès au panneau**
- À un **point configuré** par société (`Config.Societies[job].points`) : target (ox_target / qb-target) ou prompt
  natif `[E] Ouvrir la gestion`, visible seulement pour le job concerné et un grade `>= bossGrade`.
- Ou par **commande** `/society` (`Config.Command`, `false` = points seulement).
- Toujours revérifié côté serveur (job listé, grade, distance au point si ouvert depuis un point).

**Onglet Employés**
- Liste : nom, grade, en ligne / hors ligne (employés hors ligne inclus, 100 max).
- **Recruter** un joueur proche (≤ `Config.InteractDistance`) : choix parmi les joueurs proches (affichés
  « Citoyen n°ID », jamais de nom avant acceptation). La cible reçoit une **offre** à accepter `[E]` / refuser `[X]`.
  Recrutement au grade le plus bas.
- **Promouvoir / Rétrograder** d'un grade (grade existant suivant / précédent), en ligne ou hors ligne.
- **Virer** (en ligne ou hors ligne) : la personne repasse sans emploi.
- **Prime** ponctuelle (salaire / bonus) : du compte société vers le compte `bank` de l'employé **en ligne**.
- Interdits : agir sur soi-même, sur un grade `>=` au sien, promouvoir au niveau de son propre grade ou au-dessus.

**Onglet Compte**
- Solde, **dépôt** (argent du joueur → société), **retrait** (société → joueur), **historique** (30 dernières
  opérations : dépôts, retraits, primes, factures, mouvements externes).
- Compte société : **esx_addonaccount** (esx_society), **qb-banking** (qb-management récent), **qb-management**
  (ancien), **Renewed-Banking** (Qbox), détectés automatiquement et appelés via des fonctions locales protégées
  (`pcall`) ; sinon **repli** sur une table oxmysql propre (`pop_management_accounts`).
- L'historique est toujours dans `pop_management_transactions` (quel que soit le compte utilisé).

**Factures**
- Commande `/invoice` (`Config.InvoiceCommand`, `false` = désactivé) : tout employé d'une société listée, en
  service, de grade `>= invoiceGrade`.
- Petit formulaire : client proche (« Citoyen n°ID »), montant entier, motif facultatif (50 caractères).
- Le client reçoit une offre `[E] Payer` / `[X] Refuser` (30 s). S'il accepte : payé depuis son compte `bank`,
  argent versé **au compte de la société**, ligne d'historique, notifications des deux côtés.
- Pas de factures impayées persistantes : une facture refusée ou expirée disparaît.

**Performance**
- Client : aucune boucle permanente. Zones gérées par le bridge (boucle partagée adaptative). `Wait(0)` uniquement
  pendant une offre affichée (30 s max). Interface sans focus sauf panneau / formulaire de facture ouverts.
- Serveur : aucune boucle. Expiration des offres par `SetTimeout`. Cache des grades (300 s).

**Hors périmètre / fonctions de l'ancien script (tab_management) volontairement abandonnées**
- Ordinateur 3D (DUI `tab_duiengine`), faux OS et applications, styles « 80s / 2026 », caméras et gizmos d'écran,
  commandes `/lapclose`, `/lapside`, `/lapedity`. → remplacés par un panneau latéral simple.
- Tableau de bord (vue d'ensemble) → le solde et l'effectif sont dans l'en-tête du panneau.
- Concession PDM : catalogue, couleurs, achat avec les fonds société, commandes ciblées, imports avec délai,
  retrait au port, spawn, clés `tab_inventory`, écritures `owned_vehicles` / `persistent_vehicles`, onglet Flotte.
- YouTool / GoPostal : boutique B2B, panier, livraisons, étagère et cartons du port, commandes PNJ « bot »,
  prime livreur, app du job livreur.
- Chéquier d'entreprise, casiers (matricule / code, `ALTER TABLE users`), exports de casiers.
- Dynasty 8 (locataires, zones MLO, `d8_chests`), app Gouvernement (TVA en `GlobalState`, subventions, contrats
  de travail, annonces, conseil), blips centralisés et export `RegisterBlip`, territoires.
- Notifications / aides personnalisées (`notification`, `v3dui`), `Config.DevMode`, obligation d'un grade nommé
  `boss` (→ remplacé par `bossGrade` numérique), modification des tables du framework (`ALTER TABLE`).
- Modification du salaire des grades, double job (`job2`), comptes de gang, primes aux employés hors ligne.
- Failles corrigées par conception : retrait / licenciement / changement de grade sans contrôle de grade,
  montants non validés, société cible ou prix envoyés par le client, identifiants exposés à l'interface.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_management/
  SPEC.md                 Architecte (ce fichier)
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR   (clés communes de pop_base + clés de la section 8, à l'identique)
  README.md               SERVEUR   en ANGLAIS (installation, comptes société supportés, config, commandes)
  sql/install.sql         SERVEUR
  bridge/server.lua       SERVEUR   copie STRICTE de templates/pop_base/bridge/server.lua
  bridge/client.lua       CLIENT    copie STRICTE de templates/pop_base/bridge/client.lua
  shared/callback.lua     SERVEUR   copie STRICTE de templates/pop_base/shared/callback.lua
  shared/locale.lua       SERVEUR   copie STRICTE de templates/pop_base/shared/locale.lua
  locales/en.lua          SERVEUR   clés de base (pop_base) + clés de la section 9
  locales/fr.lua  es.lua  de.lua  it.lua  pt.lua  nl.lua  pl.lua  tr.lua  ar.lua   SERVEUR (idem, ar : _rtl = true)
  server/account.lua      SERVEUR   compte société (backends) + historique — table globale `Account` (section 11)
  server/framework.lua    SERVEUR   employés et grades par framework — table globale `Jobs` (section 11)
  server/main.lua         SERVEUR   callbacks, sessions, offres, sécurité, exports
  client/main.lua         CLIENT    zones, commandes, panneau, formulaire de facture, callbacks NUI
  client/offer.lua        CLIENT    affichage d'une offre reçue + touches [E] / [X]
  web/index.html          NUI
  web/script.js           NUI
  web/style.css           NUI
  web/kit/pop.css         NUI       copie STRICTE de templates/pop_base/web/kit/pop.css
  web/kit/pop.js          NUI       copie STRICTE de templates/pop_base/web/kit/pop.js
```

Ordre de chargement serveur (alphabétique) : `account.lua` → `framework.lua` → `main.lua`. `Account` et `Jobs`
ne sont utilisés par `main.lua` que dans des handlers (jamais au chargement du fichier).

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_management'
author 'POP'
version '1.0.0'
description 'POP Management - company boss panel, account and invoices'

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

---

## 3. Données échangées

Aucun identifiant de framework (identifier ESX, citizenid, license) n'est **jamais** envoyé au client.
Les employés sont désignés par un `id` entier opaque, valable pour la session de panneau en cours.

### `PanelData` (retour de `pop_management:getPanel`, transmis tel quel à la NUI)
```lua
{
    society   = { name = 'police', label = 'LSPD' },
    me        = { grade = 4, gradeLabel = 'Chief' },
    balance   = 125000,                 -- integer
    maxAmount = 1000000,                -- Config.MaxAmount
    now       = 1773695600,             -- os.time() serveur (pour les durées relatives de l'historique)
    grades    = { { grade = 0, label = 'Recruit' }, { grade = 1, label = 'Officer' } }, -- triés par grade croissant
    employees = {                       -- triés : grade décroissant puis nom
        { id = 1, name = 'John Doe', grade = 4, gradeLabel = 'Chief', online = true, me = true },
        { id = 2, name = 'Jane Roe', grade = 1, gradeLabel = 'Officer', online = false, me = false },
    },
    history   = {                       -- 30 max, plus récent en premier
        { type = 'deposit', amount = 500, actor = 'John Doe', target = nil, note = nil, at = 1773695500 },
        { type = 'invoice', amount = 250, actor = 'Jane Roe', target = 'Bob Smith', note = 'Repair', at = 1773695000 },
    },
}
```
- `type` ∈ `deposit`, `withdraw`, `bonus`, `invoice`, `add`, `remove` (`add` / `remove` : exports).
  Entrées (`deposit`, `invoice`, `add`) affichées `+`, sorties (`withdraw`, `bonus`, `remove`) affichées `−`.
- `amount` toujours **positif** ; `target` / `note` peuvent être `nil` (absents en JSON).

### Session de panneau (serveur uniquement)
`sessions[src] = { job = 'police', point = 2 | nil, employees = { [id] = identifier } }`
Créée / remplacée par chaque `getPanel`, supprimée par `pop_management:server:closePanel`, à la déconnexion,
au déchargement du personnage, et si le job du joueur ne correspond plus.

### Offre (serveur uniquement)
```lua
offers[offerId] = {
    id = 7, kind = 'recruit' | 'invoice',
    from = srcExpediteur, to = srcCible, job = 'police',
    amount = 250,        -- invoice uniquement
    note = 'Repair',     -- invoice uniquement, ou nil
    expires = os.time() + Config.OfferTimeout,
}
```
`offerId` : compteur entier croissant. Index : `offerByTarget[to] = offerId`, `offerBySender[from] = offerId`.

---

## 4. Events

Toutes les actions client → serveur passent par des **callbacks** (section 5), sauf la fermeture du panneau.

### Client → Serveur (`RegisterNetEvent` côté serveur)

| Event | Paramètres | Rôle |
|---|---|---|
| `pop_management:server:closePanel` | aucun | Supprime `sessions[source]` |

### Serveur → Client (`RegisterNetEvent` côté client)

| Event | Paramètres | Destinataire | Rôle |
|---|---|---|---|
| `pop_management:client:offer` | `offer` (table ci-dessous) | la cible | Affiche une offre (recrutement ou facture) |
| `pop_management:client:offerClosed` | `offerId` (int) | la cible | Offre expirée / annulée (expéditeur déconnecté) : masquer |

`offer` envoyé au client (jamais de source ni d'identifiant de l'expéditeur) :
```lua
{ id = 7, kind = 'invoice', society = 'LSPD', amount = 250, note = 'Repair', timeout = 30 }
{ id = 8, kind = 'recruit', society = 'LSPD', gradeLabel = 'Recruit', timeout = 30 }
```

### Évènements du bridge utilisés
- Serveur : `Bridge.OnPlayerDropped(src)` et `Bridge.OnPlayerUnloaded(src)` → supprime `sessions[src]`,
  `busy[src]`, les offres où `src` est expéditeur ou cible (si cible : rien à envoyer ; si expéditeur :
  `offerClosed` à la cible).
- Client : `Bridge.OnPlayerLoaded` / `Bridge.OnJobUpdate` → reconstruit les zones ; si le job change pendant que
  le panneau est ouvert → fermeture. `Bridge.OnUiClose` → fermeture panneau / formulaire.

---

## 5. Callbacks (`shared/callback.lua`)

Convention de retour des actions : `ok (bool), reason (string, clé de locale) | nil, arg | nil`.
En cas d'échec, le **client** affiche `Bridge.Notify(L(reason or 'error', arg), 'error')`.
En cas de succès, c'est le **serveur** qui notifie (`Bridge.Notify(src, ..., 'success')`).
`nil` (timeout 10 s ou anti-spam) = traiter comme `reason = 'error'`.

| Nom | Paramètres (client → serveur) | Retour |
|---|---|---|
| `pop_management:getPanel` | `point` (int, index dans `points`) \| nil (commande) | `PanelData` \| `nil, reason, arg` |
| `pop_management:recruit` | `targetId` (int, id serveur) | `ok, reason, arg` (envoie l'offre) |
| `pop_management:fire` | `employeeId` (int) | `ok, reason, arg` |
| `pop_management:promote` | `employeeId` (int) | `ok, reason, arg` |
| `pop_management:demote` | `employeeId` (int) | `ok, reason, arg` |
| `pop_management:pay` | `employeeId` (int), `amount` (int) | `ok, reason, arg` |
| `pop_management:deposit` | `amount` (int) | `ok, reason, arg` |
| `pop_management:withdraw` | `amount` (int) | `ok, reason, arg` |
| `pop_management:canInvoice` | aucun | `info` (`{ society = label, max = Config.MaxInvoice }`) \| `nil, reason, arg` |
| `pop_management:sendInvoice` | `targetId` (int), `amount` (int), `note` (string \| nil) | `ok, reason, arg` (envoie l'offre) |
| `pop_management:answerOffer` | `offerId` (int), `accept` (bool) | `ok, reason, arg` |

**Raisons possibles** (toutes sont des clés de locale existantes) :
`error`, `busy`, `too_far`, `no_permission`, `wrong_job`, `not_enough_money`, `off_duty`, `invalid_amount`,
`amount_too_high` (arg = `L('money', max)`), `society_no_money`, `society_no_account`, `employee_not_found`,
`employee_offline`, `cannot_self`, `rank_too_high`, `grade_max`, `grade_min`, `already_employee`,
`target_not_found`, `target_busy`, `offer_not_found`, `invoice_disabled`.

Aucun callback serveur → client.

---

## 6. Messages NUI

Le panneau et le formulaire de facture prennent le focus (`SetNuiFocus(true, true)` côté Lua à l'ouverture).
Fermeture : bouton `close` / Échap → `Pop.post('close')` (kit) → `Bridge.OnUiClose` (focus déjà rendu).
L'offre ne prend **jamais** le focus.

### Lua → JS (`SendNUIMessage`)

**`pop_management:panel`**
```json
{ "action": "pop_management:panel", "show": true, "data": { "...": "PanelData (section 3)" } }
```
```json
{ "action": "pop_management:panel", "show": false }
```
Renvoyé avec `show = true` après chaque action réussie (données rafraîchies) : la NUI garde l'onglet actif.

**`pop_management:invoice`**
```json
{ "action": "pop_management:invoice", "show": true, "society": "LSPD", "max": 50000,
  "players": [ { "id": 12, "dist": 1.4 }, { "id": 31, "dist": 2.7 } ] }
```
```json
{ "action": "pop_management:invoice", "show": false }
```

**`pop_management:offer`**
```json
{ "action": "pop_management:offer", "show": true, "kind": "invoice", "society": "LSPD",
  "amount": 250, "note": "Repair", "timeout": 30, "acceptKey": "E", "refuseKey": "X" }
```
```json
{ "action": "pop_management:offer", "show": true, "kind": "recruit", "society": "LSPD",
  "gradeLabel": "Recruit", "timeout": 30, "acceptKey": "E", "refuseKey": "X" }
```
```json
{ "action": "pop_management:offer", "show": false }
```
`acceptKey` = `Config.Keys.Interact.label`, `refuseKey` = `Config.Keys.Cancel.label`.

### JS → Lua (`RegisterNUICallback`, via `Pop.post`)

| Nom | Données envoyées | Réponse |
|---|---|---|
| `pop_management:action` | `{ "action": "fire" \| "promote" \| "demote" \| "pay" \| "deposit" \| "withdraw" \| "recruit", "employeeId": 2, "amount": 500, "targetId": 12 }` | `{ "ok": true }` \| `{ "ok": false, "reason": "invalid_amount" }` |
| `pop_management:nearby` | `{}` | `{ "players": [ { "id": 12, "dist": 1.4 } ] }` |
| `pop_management:sendInvoice` | `{ "targetId": 12, "amount": 250, "note": "Repair" }` | `{ "ok": true }` \| `{ "ok": false, "reason": "..." }` |
| `close` | (kit) | géré par le bridge |

Champs utilisés par `pop_management:action` : `fire` / `promote` / `demote` → `employeeId` ; `pay` →
`employeeId` + `amount` ; `deposit` / `withdraw` → `amount` ; `recruit` → `targetId`. Le Lua n'accepte que ces 7
actions (table blanche) et appelle le callback serveur du même nom (`pop_management:<action>`). Les notifications
sont faites côté Lua ; la NUI se contente de réactiver ses boutons à la réponse.

### Interface (Dev NUI)
- `web/index.html` : base de pop_base, `<link rel="stylesheet" href="style.css">` après `kit/pop.css`.
  Trois blocs masqués par défaut (`pop-panel pop-fade`) :
  - `#mgmt-panel` : en-tête (nom société `#mgmt-society`, `#mgmt-grade`, solde `#mgmt-balance`, bouton `close`) ;
    onglets `tab_employees` / `tab_account` ;
    - **Employés** : compteur `Pop.t('employees_count', n)`, bouton `recruit` → sous-vue « proches »
      (`nearby_title`, liste `Pop.t('player_id', id)` + distance `Pop.t('meters', dist)`, `nearby_none` si vide) ;
      lignes : nom, `gradeLabel`, pastille accent si `online` (`online` / `offline` en texte petit), `you` si `me`.
      Boutons `promote`, `demote`, `pay`, `fire` **masqués** si `me` ou `grade >= data.me.grade` ; `promote` masqué
      si le grade suivant de `data.grades` est `>= data.me.grade` ou n'existe pas ; `demote` masqué si aucun grade
      inférieur ; `pay` masqué si `online == false`. `pay` ouvre un champ montant inline + `confirm`.
      `fire` : premier clic → le bouton affiche `confirm` pendant 3 s, second clic → envoi.
    - **Compte** : solde, champ `amount` (entier, min 1, max `maxAmount`), boutons `deposit` / `withdraw`
      (`withdraw` avec la même confirmation à deux clics), titre `history`, lignes : `Pop.t('tx_' + type)`,
      montant `+`/`−` (`+` en accent, `−` en `--pop-danger`), `actor` (→ `target` si présent), `note` (petit),
      durée relative ; `history_empty` si vide.
  - `#mgmt-invoice` : titre `invoice_title` + société, select client (`Pop.t('player_id', id)`), champ `amount`
    (max `max`), champ `invoice_reason` (`maxlength="50"`), boutons `invoice_send` / `cancel` (`cancel` →
    `Pop.post('close')`). Liste vide → `nearby_none` et `invoice_send` désactivé.
  - `#mgmt-offer` : titre `Pop.t('offer_invoice', society)` ou `Pop.t('offer_recruit', society)` ; ligne
    `Pop.t('money', montant)` + note, ou `Pop.t('offer_grade', gradeLabel)` ; `[E] offer_accept   [X] offer_refuse`
    (classes `pop-key`) ; barre fine (3 px) qui se vide en `timeout` secondes (`transform: scaleX`, transition
    linéaire).
- `web/script.js` : `Pop.on('pop_management:panel' | 'pop_management:invoice' | 'pop_management:offer', ...)`,
  `Pop.show(el, visible)`. Montants : `Pop.t('money', new Intl.NumberFormat().format(n))`. Durées : `now - at`
  → `time_now` (< 60 s), `time_min`, `time_hour`, `time_day` (valeur entière). Tous les textes viennent des
  données ou de `data-locale` / `Pop.t` : **aucun texte en dur**. Données serveur (noms, notes) insérées via
  `textContent` uniquement (jamais `innerHTML`). Boutons désactivés pendant l'attente d'une réponse `Pop.post`.
  Montants envoyés : `parseInt(value, 10)` ; refuser localement NaN / ≤ 0 (le serveur revalide).
- `web/style.css` : `#mgmt-panel` largeur 380 px, `position: fixed; right: 24px; top: 10%; max-height: 80vh`,
  listes défilantes ; `#mgmt-invoice` 300 px même position ; `#mgmt-offer` 280 px `right: 24px; bottom: 14%`.
  Fond `--pop-bg`, texte blanc, accent `--pop-accent`, `--pop-radius`, police système, aucun dégradé, aucun flou,
  aucune ombre lourde ; seule transition = `.pop-fade` (et la barre de l'offre). Pas de grande fenêtre centrale.
  RTL : `[dir="rtl"]` → `right: auto; left: 24px`, barre `transform-origin: right`.

---

## 7. Exports publics

Serveur :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_management:GetSocietyMoney(job)` | integer \| nil | solde (nil si compte introuvable) |
| `exports.pop_management:AddSocietyMoney(job, amount, note?)` | bool | ajoute (montant entier > 0), historique `add` |
| `exports.pop_management:RemoveSocietyMoney(job, amount, note?)` | bool | retire si solde suffisant, historique `remove` |
| `exports.pop_management:IsBoss(src)` | bool | job listé dans `Config.Societies` et grade `>= bossGrade` |

Les exports d'argent passent par le même verrou de société que les actions (section 13), avec acteur `'-'`.
`note` : chaîne nettoyée (64 caractères max).

Client :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_management:OpenPanel()` | | comme la commande (point = nil ; refusé si `Config.Command == false`) |
| `exports.pop_management:OpenInvoice()` | | comme `/invoice` |
| `exports.pop_management:IsOpen()` | bool | panneau ou formulaire ouvert |

---

## 8. config.lua (contenu exact)

Le fichier reprend **à l'identique** le `config.lua` de `templates/pop_base` (Locale, Debug, Framework, Inventory,
Target, Notify, AccentColor, Keys, CallbackRateLimit), puis ajoute à la suite :

```lua
-- ─── pop_management ─────────────────────────────────────────

-- Sociétés gérées (clé = nom du job dans votre framework).
--   bossGrade    : grade minimum pour ouvrir le panneau patron
--   invoiceGrade : grade minimum pour envoyer des factures (false = pas de factures)
--   points       : où ouvrir le panneau (peut être vide si vous utilisez la commande)
Config.Societies = {
    police    = { bossGrade = 4, invoiceGrade = 0, points = { vector3(461.45, -986.2, 30.73) } },
    ambulance = { bossGrade = 4, invoiceGrade = 0, points = { vector3(335.2, -594.0, 43.28) } },
    mechanic  = { bossGrade = 4, invoiceGrade = 0, points = { vector3(-347.4, -133.2, 39.0) } },
}

Config.Command        = 'society' -- ouvre le panneau partout (false = seulement aux points)
Config.InvoiceCommand = 'invoice' -- formulaire de facture (false = factures désactivées)

-- Compte société : 'auto' | 'esx_addonaccount' | 'qb-banking' | 'qb-management' | 'renewed-banking' | 'pop'
Config.SocietyAccount = 'auto'

-- Comptes joueur utilisés ('cash' | 'bank').
Config.Accounts = {
    transfer = 'cash', -- dépôt / retrait au compte société
    bonus    = 'bank', -- primes reçues par les employés
    invoice  = 'bank', -- paiement des factures par le client
}

Config.MaxAmount        = 1000000 -- montant max par dépôt / retrait / prime
Config.MaxInvoice       = 50000   -- montant max d'une facture
Config.InteractDistance = 3.0     -- distance max pour recruter / facturer (mètres)
Config.OfferTimeout     = 30      -- secondes pour accepter une offre (recrutement, facture)
```

Aucune autre clé. Constantes internes (non configurables) :
- `server/main.lua` : `POINT_DISTANCE = 5.0` (tolérance serveur au point), `HISTORY_LIMIT = 30`,
  `HISTORY_DAYS = 30` (purge au démarrage), `NOTE_MAX = 50`, `MAX_EMPLOYEES = 100`.
- `client/main.lua` : `TARGET_DISTANCE = 2.0`, `ZONE_SIZE = vec3(1.2, 1.2, 2.0)`, `NEARBY_MAX = 6`.

---

## 9. Locales

10 fichiers : `en` (défaut + repli), `fr`, `es`, `de`, `it`, `pt`, `nl`, `pl`, `tr`, `ar` (`_rtl = true`).
Chaque fichier = bloc « Kit commun » de pop_base inchangé + les clés ci-dessous sous `-- Textes propres au script :`.
Les formats `%s` sont conservés dans toutes les langues (même nombre, même ordre). Montants côté Lua :
`L('money', montant)` puis injecté dans le message (ex. `L('deposited', L('money', 500))`).

| Clé | en | fr |
|---|---|---|
| `panel_title` | Management | Gestion |
| `open_panel` | Open management | Ouvrir la gestion |
| `tab_employees` | Employees | Employés |
| `tab_account` | Account | Compte |
| `employees_count` | %s employees | %s employés |
| `online` | Online | En ligne |
| `offline` | Offline | Hors ligne |
| `you` | You | Vous |
| `recruit` | Recruit | Recruter |
| `fire` | Fire | Virer |
| `promote` | Promote | Promouvoir |
| `demote` | Demote | Rétrograder |
| `pay` | Bonus | Prime |
| `nearby_title` | Nearby people | Personnes à proximité |
| `nearby_none` | Nobody nearby | Personne à proximité |
| `player_id` | Citizen #%s | Citoyen n°%s |
| `meters` | %s m | %s m |
| `balance` | Balance | Solde |
| `amount` | Amount | Montant |
| `deposit` | Deposit | Déposer |
| `withdraw` | Withdraw | Retirer |
| `history` | History | Historique |
| `history_empty` | No transactions yet | Aucune opération |
| `tx_deposit` | Deposit | Dépôt |
| `tx_withdraw` | Withdrawal | Retrait |
| `tx_bonus` | Bonus | Prime |
| `tx_invoice` | Invoice | Facture |
| `tx_add` | Income | Entrée |
| `tx_remove` | Expense | Sortie |
| `time_now` | just now | à l'instant |
| `time_min` | %s min ago | il y a %s min |
| `time_hour` | %s h ago | il y a %s h |
| `time_day` | %s d ago | il y a %s j |
| `money` | $%s | %s $ |
| `invoice_title` | Invoice | Facture |
| `invoice_to` | Customer | Client |
| `invoice_reason` | Reason (optional) | Motif (facultatif) |
| `invoice_send` | Send | Envoyer |
| `offer_invoice` | Invoice from %s | Facture de %s |
| `offer_recruit` | Job offer: %s | Offre d'emploi : %s |
| `offer_grade` | Position: %s | Poste : %s |
| `offer_accept` | Accept | Accepter |
| `offer_refuse` | Decline | Refuser |
| `offer_sent` | Offer sent, waiting for an answer | Offre envoyée, en attente de réponse |
| `offer_refused` | Your offer was declined | Votre offre a été refusée |
| `offer_expired` | Your offer expired | Votre offre a expiré |
| `deposited` | You deposited %s | Vous avez déposé %s |
| `withdrawn` | You withdrew %s | Vous avez retiré %s |
| `paid` | Bonus of %s paid to %s | Prime de %s versée à %s |
| `bonus_received` | You received a bonus of %s from %s | Vous avez reçu une prime de %s de %s |
| `recruited` | %s joined the company | %s a rejoint l'entreprise |
| `hired` | You now work for %s | Vous travaillez maintenant pour %s |
| `fired` | %s has been fired | %s a été renvoyé(e) |
| `fired_target` | You have been fired from %s | Vous avez été renvoyé(e) de %s |
| `grade_set` | %s is now %s | %s est maintenant %s |
| `grade_changed` | Your position at %s is now %s | Votre poste chez %s est maintenant %s |
| `invoice_paid` | Invoice of %s paid | Facture de %s payée |
| `invoice_paid_target` | You paid %s to %s | Vous avez payé %s à %s |
| `invoice_unpaid` | The customer couldn't pay | Le client n'a pas pu payer |
| `off_duty` | You must be on duty | Vous devez être en service |
| `invalid_amount` | Invalid amount | Montant invalide |
| `amount_too_high` | Maximum amount: %s | Montant maximum : %s |
| `society_no_money` | The company account has insufficient funds | Fonds insuffisants sur le compte de l'entreprise |
| `society_no_account` | Company account not found | Compte de l'entreprise introuvable |
| `employee_not_found` | This person no longer works here | Cette personne ne travaille plus ici |
| `employee_offline` | This employee is offline | Cet employé est hors ligne |
| `cannot_self` | You can't do that to yourself | Impossible sur vous-même |
| `rank_too_high` | Not allowed for this rank | Non autorisé pour ce grade |
| `grade_max` | No higher grade available | Aucun grade supérieur disponible |
| `grade_min` | Already at the lowest grade | Déjà au grade le plus bas |
| `already_employee` | This person already works here | Cette personne travaille déjà ici |
| `target_not_found` | This person is no longer nearby | Cette personne n'est plus à proximité |
| `target_busy` | This person already has a pending offer | Cette personne a déjà une offre en attente |
| `offer_not_found` | This offer is no longer valid | Cette offre n'est plus valable |
| `invoice_disabled` | Your company can't send invoices | Votre entreprise ne peut pas facturer |

Clés de base réutilisées : `cancel`, `confirm`, `close`, `no_permission`, `wrong_job`, `too_far`,
`not_enough_money`, `busy`, `error`. Les messages console (logs) restent en anglais et ne passent pas par `L()`.

---

## 10. Schéma SQL

`sql/install.sql` (le serveur exécute aussi ces `CREATE TABLE IF NOT EXISTS` au démarrage : aucune action manuelle
requise). Aucune table du framework n'est créée ni modifiée (pas d'`ALTER TABLE`).

```sql
CREATE TABLE IF NOT EXISTS `pop_management_accounts` (
    `society` VARCHAR(50)     NOT NULL,
    `balance` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`society`)
);

CREATE TABLE IF NOT EXISTS `pop_management_transactions` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `society`    VARCHAR(50)  NOT NULL,
    `type`       VARCHAR(16)  NOT NULL,
    `amount`     INT UNSIGNED NOT NULL,
    `actor`      VARCHAR(100) NOT NULL,
    `target`     VARCHAR(100) NULL DEFAULT NULL,
    `note`       VARCHAR(64)  NULL DEFAULT NULL,
    `created_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_society_time` (`society`, `created_at`)
);
```

- `pop_management_accounts` n'est utilisée que par le backend `pop`. Ligne créée à la demande
  (`INSERT IGNORE ... (society, 0)`). Retrait **atomique** :
  `UPDATE pop_management_accounts SET balance = balance - ? WHERE society = ? AND balance >= ?` → succès si
  `affectedRows == 1`. Ajout : `INSERT INTO ... VALUES (?, ?) ON DUPLICATE KEY UPDATE balance = balance + VALUES(balance)`.
- Historique : `MySQL.insert` (non bloquant) ; lecture
  `SELECT type, amount, actor, target, note, created_at FROM pop_management_transactions WHERE society = ? ORDER BY id DESC LIMIT 30`.
  Purge au démarrage : `DELETE ... WHERE created_at < ?` (`os.time() - HISTORY_DAYS * 86400`).
- Requêtes **toujours paramétrées** (`?`), jamais de concaténation de valeurs.

---

## 11. Modules serveur (Dev Serveur)

### `server/account.lua` : table globale `Account`

Backend choisi au chargement (`Config.SocietyAccount`, `'auto'` = premier disponible dans l'ordre) :

| Framework | Ordre auto |
|---|---|
| esx | `esx_addonaccount` → `pop` |
| qbcore | `qb-banking` → `qb-management` → `renewed-banking` → `pop` |
| qbox | `renewed-banking` → `qb-banking` → `pop` |
| standalone | `pop` |

« Disponible » = ressource `started` (`Renewed-Banking`, `qb-banking`, `qb-management`, `esx_addonaccount`).
Chaque backend = 3 fonctions locales appelées sous `pcall` (une erreur = `nil` / `false`, jamais de crash) :

| Backend | Compte | get | add | remove |
|---|---|---|---|---|
| `esx_addonaccount` (esx_society) | `'society_' .. job` | `TriggerEvent('esx_addonaccount:getSharedAccount', name, function(a) acc = a end)` (rappel synchrone) → `acc.money` | `acc.addMoney(n)` | `acc.money >= n` puis `acc.removeMoney(n)` |
| `qb-banking` | `job` | `exports['qb-banking']:GetAccountBalance(job)` | `AddMoney(job, n, reason)` | `RemoveMoney(job, n, reason)` |
| `qb-management` (ancien) | `job` | `exports['qb-management']:GetAccount(job)` | `AddMoney(job, n)` | `RemoveMoney(job, n)` |
| `renewed-banking` | `job` | `exports['Renewed-Banking']:getAccountMoney(job)` | `addAccountMoney(job, n)` | `removeAccountMoney(job, n)` |
| `pop` | `job` | SQL (section 10) | SQL | SQL atomique |

API :
| Fonction | Retour | Notes |
|---|---|---|
| `Account.Backend` | string | backend retenu (log au démarrage, en anglais) |
| `Account.Get(job)` | integer \| nil | nil = compte introuvable (get non nombre / `false` / erreur) ; `math.floor` |
| `Account.Add(job, amount, reason)` | bool | `amount` entier > 0 déjà validé ; résultat `false` explicite = échec |
| `Account.Remove(job, amount, reason)` | bool | vérifie `Account.Get(job) >= amount` avant (sauf `pop`, atomique) |
| `Account.Log(job, type, amount, actor, target?, note?)` | | insert asynchrone |
| `Account.History(job)` | tableau | 30 dernières lignes au format `history` de PanelData (`created_at` → `at`) |

Pour les backends externes, `Account.Get(job) == nil` sur une société listée → avertissement console une fois
par job (« create the society account `society_police` in addon_account » pour ESX).

### `server/framework.lua` : table globale `Jobs`

Récupère lui-même l'objet du framework (ESX : export `getSharedObject` sous `pcall`, sinon event
`esx:getSharedObject` ; QBCore : `exports['qb-core']:GetCoreObject()` ; Qbox : exports `qbx_core`), selon
`Bridge.Framework`. Toutes les fonctions sont protégées (`pcall`). En standalone : `Jobs.Supported = false`,
toutes les fonctions renvoient des valeurs vides / `false`, et `main.lua` affiche un avertissement console.

| Fonction | Retour | Notes |
|---|---|---|
| `Jobs.Supported` | bool | false en standalone |
| `Jobs.GetGrades(job)` | `{ { grade, label }, ... }` trié croissant | cache 300 s par job |
| `Jobs.GetLabel(job)` | string | label du job, sinon `job` |
| `Jobs.FindOnline(identifier)` | src \| nil | |
| `Jobs.GetEmployees(job)` | `{ { identifier, name, grade, src? }, ... }` | 100 max ; superpose les joueurs en ligne (nom et grade en direct) |
| `Jobs.GetEmployee(job, identifier)` | même format \| nil | nil si n'appartient plus au job |
| `Jobs.Hire(src, job, grade)` | bool | cible **en ligne** |
| `Jobs.SetGrade(job, identifier, grade)` | bool | en ligne ou hors ligne |
| `Jobs.Fire(job, identifier)` | bool | en ligne ou hors ligne → sans emploi |

Implémentation par framework :

| | ESX (Legacy et ancien) | QBCore | Qbox |
|---|---|---|---|
| Grades | `ESX.GetJobs()[job].grades` (`grade`, `label`) ; sinon SQL `SELECT grade, label FROM job_grades WHERE job_name = ?` | `QBCore.Shared.Jobs[job].grades` (clés `'0'`, champ `name`) | `exports.qbx_core:GetJob(job).grades` (clés numériques, champ `name`) |
| En ligne | `ESX.GetPlayerFromIdentifier(id)` | `QBCore.Functions.GetPlayerByCitizenId(cid)` | `exports.qbx_core:GetPlayerByCitizenId(cid)` |
| Liste | `SELECT identifier, firstname, lastname, job_grade FROM users WHERE job = ?` ; si erreur (ancien ESX sans firstname) : `SELECT identifier, name, job_grade ...` | `SELECT citizenid, charinfo, job FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ?` (nom depuis `charinfo`, grade depuis `job.grade.level`) | `exports.qbx_core:GetGroupMembers(job, 'job')` (accepter liste `{ citizenid, grade }` ou table `citizenid → grade`) + noms `SELECT citizenid, charinfo FROM players WHERE citizenid IN (?)` |
| Recruter (en ligne) | `xPlayer.setJob(job, grade)` | `Player.Functions.SetJob(job, grade)` | `AddPlayerToJob(cid, job, grade)` puis `SetPlayerPrimaryJob(cid, job)` |
| Grade en ligne | `xPlayer.setJob(job, grade)` | `Player.Functions.SetJob(job, grade)` | `AddPlayerToJob(cid, job, grade)` (met à jour le grade) |
| Grade hors ligne | `UPDATE users SET job_grade = ? WHERE identifier = ? AND job = ?` | `UPDATE players SET job = ? WHERE citizenid = ?` (JSON complet, voir ci-dessous) | `AddPlayerToJob(cid, job, grade)` (gère le hors ligne) |
| Virer | en ligne `setJob('unemployed', 0)` ; hors ligne `UPDATE users SET job = 'unemployed', job_grade = 0 WHERE identifier = ? AND job = ?` | en ligne `SetJob('unemployed', 0)` ; hors ligne JSON `unemployed` grade 0 | `RemovePlayerFromJob(cid, job)` |

QBCore hors ligne : JSON écrit = `{ name, label, payment, type, onduty = false, isboss, grade = { name, level } }`
construit depuis `QBCore.Shared.Jobs` (comme `SetJob` du framework), avec `json.encode`.
Les retours explicites `false` des exports Qbox sont traités comme un échec.

### `server/main.lua`
- **Démarrage** : `CREATE TABLE IF NOT EXISTS` (section 10), purge de l'historique, avertissements console
  (anglais) : standalone ; job de `Config.Societies` absent du framework (`Jobs.GetGrades(job)` vide) ; backend
  retenu.
- Helpers locaux : `validAmount(n, max)` → integer ou `nil, reason, arg` ; `cleanNote(s)` ; `isBoss(src)` →
  `cfg, job` ou `nil, reason` ; `withSocietyLock(job, fn)` ; `checkSession(src)` (section 13).
- **Callbacks** de la section 5 + event `closePanel` + exports de la section 7.
- Notifications de succès (`Bridge.Notify(src, L(...), 'success')`) :
  `deposited`, `withdrawn`, `paid` (+ `bonus_received` à l'employé), `offer_sent` (recrutement / facture),
  `recruited` (boss) + `hired` (cible), `fired` (+ `fired_target` si en ligne), `grade_set`
  (+ `grade_changed` si en ligne), `invoice_paid` (expéditeur) + `invoice_paid_target` (client),
  `offer_refused` / `offer_expired` (expéditeur, `'error'`), `invoice_unpaid` (expéditeur, `'error'`).
- **Expiration d'offre** : `SetTimeout(Config.OfferTimeout * 1000)` → si l'offre existe encore : suppression,
  `offerClosed` à la cible, `offer_expired` à l'expéditeur.

---

## 12. Comportement client (Dev Client)

### `client/main.lua`
- **Zones** : à `Bridge.OnPlayerLoaded` et `Bridge.OnJobUpdate` : supprime les zones existantes
  (`Bridge.Target.Remove`), puis si `Config.Societies[job.name]` existe : pour chaque point `i`,
  `Bridge.Target.AddBoxZone('pop_management_' .. i, point, ZONE_SIZE, 0.0, { { label = L('open_panel'),
  icon = 'fa-solid fa-briefcase', distance = TARGET_DISTANCE, canInteract = grade >= bossGrade,
  onSelect = openPanel(i) } })`. `canInteract` lit le job mis en cache (pas d'appel framework à chaque frame).
  Job changé pendant que le panneau est ouvert → `closeAll()`.
- **Commandes** : `RegisterCommand(Config.Command, openPanel(nil))` si `Config.Command` ;
  `RegisterCommand(Config.InvoiceCommand, openInvoice)` si `Config.InvoiceCommand`. Pas de touche par défaut.
- **openPanel(point)** : ignoré si déjà ouvert, `Bridge.IsBusy()` ou offre affichée. Thread :
  `Callback.Await('pop_management:getPanel', point)` ; `nil` → notification de la raison. Sinon `currentPoint =
  point`, `SetNuiFocus(true, true)`, message `pop_management:panel` (`show = true`).
- **refresh()** après chaque action réussie : `getPanel(currentPoint)` → message `panel` ; si `nil` → `closeAll()`
  + notification.
- **openInvoice()** : pré-filtre local (job listé, `invoiceGrade ~= false`) puis
  `Callback.Await('pop_management:canInvoice')` ; échec → notification. Sinon calcule les joueurs proches,
  `SetNuiFocus(true, true)`, message `pop_management:invoice`.
- **Joueurs proches** (`nearby()`) : `GetActivePlayers()` sauf `PlayerId()`, distance des peds
  `<= Config.InteractDistance`, `{ id = GetPlayerServerId(p), dist = arrondi 0.1 }`, tri par distance,
  `NEARBY_MAX` max.
- **Callbacks NUI** : `pop_management:action` (table blanche, `Callback.Await('pop_management:' .. action, ...)`
  avec les seuls champs autorisés, notification d'erreur, `refresh()` si ok, réponse `{ ok, reason }`) ;
  `pop_management:nearby` → `{ players = nearby() }` ; `pop_management:sendInvoice` → callback serveur, si ok :
  `closeAll()`. Les `Callback.Await` sont faits dans un thread, `cb(...)` appelé à la fin.
- **Fermeture** (`closeAll()`, appelée par `Bridge.OnUiClose`, changement de job, arrêt) : si le panneau était
  ouvert → `TriggerServerEvent('pop_management:server:closePanel')` ; messages `panel` et `invoice`
  `show = false` ; `SetNuiFocus(false, false)` ; état remis à zéro.
- **Arrêt** (`onResourceStop`) : `closeAll()`, offre masquée, zones supprimées (le bridge nettoie aussi).

### `client/offer.lua`
- `pop_management:client:offer` : ignoré si une offre est déjà affichée. Mémorise `offer`, envoie
  `pop_management:offer` (`show = true`), puis thread **temporaire** (`Wait(0)`, fin au plus tard à
  `offer.timeout` s) : `DisableControlAction(0, Config.Keys.Interact.control)` et `Cancel.control` chaque frame ;
  `IsDisabledControlJustReleased` → `Callback.Await('pop_management:answerOffer', offer.id, true|false)` ;
  échec → notification. Ignore les touches si `IsNuiFocused()` ou `IsPauseMenuActive()`. Fin (réponse, timeout,
  `offerClosed` du même id) → message `offer` `show = false`, boucle terminée.
- Export `IsOpen()` défini dans `main.lua`.

---

## 13. Règles de sécurité (serveur, toutes obligatoires)

Le client n'envoie que : un index de point, un `employeeId` opaque, un `targetId` (id serveur), un montant, une
note, un `offerId` et un booléen. Société, grades, soldes, noms : tout vient du serveur.

**Commun**
1. Types : `math.type(x) == 'integer'` pour `point`, `employeeId`, `targetId`, `offerId`, `amount` ; `accept`
   booléen ; sinon `error` (montant : `invalid_amount`).
2. Verrou par joueur `busy[src]` pendant tout traitement asynchrone → `busy` si occupé ; libéré dans tous les cas
   (`pcall` autour du traitement), à la déconnexion et au déchargement.
3. Verrou par société `societyLock[job]` autour de **toute** opération d'argent (actions, factures, exports) →
   `busy` si occupé ; libéré dans tous les cas.
4. Anti-spam du template (`Config.CallbackRateLimit`) actif.
5. `Bridge.GetIdentifier(src)` et `Bridge.GetJob(src)` non nil, sinon `error`. `Jobs.Supported`, sinon `error`.

**Contrôle patron** (`getPanel` et toutes les actions du panneau) — `checkSession(src)` :
1. `job = Bridge.GetJob(src)` ; `cfg = Config.Societies[job.name]`, sinon `wrong_job` ; `job.grade >=
   cfg.bossGrade`, sinon `no_permission`.
2. Actions : `sessions[src]` existe et `sessions[src].job == job.name`, sinon `no_permission` (session supprimée).
3. Point : `getPanel(point)` avec point → `cfg.points[point]` existe et `Bridge.IsNear(src, point, POINT_DISTANCE)`,
   sinon `too_far` ; sans point → `Config.Command` doit être une chaîne, sinon `too_far`. Les actions d'une session
   ouverte à un point revérifient `Bridge.IsNear` (sinon `too_far`).

**Montants** : entier, `>= 1` (sinon `invalid_amount`), `<= Config.MaxAmount` (factures : `<= Config.MaxInvoice`),
sinon `amount_too_high` + `L('money', max)`. Jamais de nombre décimal, NaN ou infini accepté.

**Employé visé** (`fire`, `promote`, `demote`, `pay`) :
1. `identifier = sessions[src].employees[employeeId]`, sinon `employee_not_found` ;
   `emp = Jobs.GetEmployee(job, identifier)` (relu au moment de l'action), sinon `employee_not_found`.
2. `identifier ~= Bridge.GetIdentifier(src)`, sinon `cannot_self`.
3. `emp.grade < job.grade` (grade de l'acteur), sinon `rank_too_high`.
4. `promote` : grade suivant existant dans `Jobs.GetGrades(job)`, sinon `grade_max` ; ce grade `< job.grade`,
   sinon `rank_too_high`. `demote` : grade précédent existant, sinon `grade_min`.
5. `pay` : `emp.src` en ligne, sinon `employee_offline`.
6. Échec de `Jobs.SetGrade` / `Jobs.Fire` → `error`.

**`deposit`** : `Bridge.RemoveMoney(src, Config.Accounts.transfer, n)` sinon `not_enough_money` ; puis
`Account.Add` ; si échec → rembourser le joueur (`Bridge.AddMoney`) et `society_no_account`. Historique `deposit`.

**`withdraw`** : `Account.Get(job)` nil → `society_no_account` ; `Account.Remove` sinon `society_no_money` ; puis
`Bridge.AddMoney(src, Config.Accounts.transfer, n)` ; si échec → `Account.Add` (remboursement) et `error`.
Historique `withdraw`.

**`pay`** : `Account.Remove` sinon `society_no_money` ; `Bridge.AddMoney(emp.src, Config.Accounts.bonus, n)` ; si
échec → `Account.Add` et `error`. Historique `bonus` (target = nom de l'employé).

**`recruit`** :
1. Contrôle patron (ci-dessus).
2. `targetId ~= src`, joueur connecté (`GetPlayerName`) et chargé (`Bridge.GetIdentifier(targetId)`), pas mort
   (`Bridge.IsDead`), sinon `target_not_found`.
3. Distance : `Bridge.IsNear(src, Bridge.GetCoords(targetId), Config.InteractDistance)`, sinon `too_far`.
4. Pas déjà employé (`Jobs.GetEmployee(job, identifierCible)` nil), sinon `already_employee`.
5. Aucune offre en attente pour la cible (`target_busy`) ni envoyée par `src` (`busy`).
6. Crée l'offre (grade = plus petit de `Jobs.GetGrades(job)` ; aucun grade → `error`), envoie
   `pop_management:client:offer`, `offer_sent` à l'expéditeur.

**`canInvoice` / `sendInvoice`** :
1. `cfg = Config.Societies[job.name]` sinon `wrong_job` ; `Config.InvoiceCommand` et `cfg.invoiceGrade ~= false`
   sinon `invoice_disabled` ; `job.grade >= cfg.invoiceGrade` sinon `no_permission` ; `job.onDuty` sinon `off_duty`.
2. `sendInvoice` : montant (max `Config.MaxInvoice`) ; `note` : `nil` ou chaîne, nettoyée (`cleanNote` :
   suppression des caractères de contrôle et de `<>`, espaces rognés, `NOTE_MAX` caractères max, vide → `nil`) ;
   cible validée comme pour `recruit` (points 2, 3, 5).
3. Crée l'offre `invoice`, l'envoie, `offer_sent`.

**`answerOffer`** :
1. `o = offers[offerId]` existe, `o.to == src`, `os.time() <= o.expires`, sinon `offer_not_found`.
2. **Retirer l'offre de toutes les tables avant tout traitement** (empêche la double acceptation).
3. Refus → `offer_refused` à l'expéditeur, retour `true`.
4. Expéditeur toujours connecté, sinon `offer_not_found`. Distance revérifiée :
   `Bridge.IsNear(src, Bridge.GetCoords(o.from), Config.InteractDistance + 2.0)`, sinon `too_far`.
5. `recruit` : l'expéditeur est toujours patron de `o.job` (job et grade), sinon `offer_not_found` ; la cible
   n'est pas déjà employée ; `Jobs.Hire(src, o.job, plus petit grade)` sinon `error`. Notifications `recruited` /
   `hired`.
6. `invoice` : l'expéditeur a toujours le job `o.job`, sinon `offer_not_found`. Sous `societyLock[o.job]` :
   `Bridge.RemoveMoney(src, Config.Accounts.invoice, o.amount)` sinon `not_enough_money` (et `invoice_unpaid`
   à l'expéditeur) ; `Account.Add(o.job, o.amount)` ; si échec → rembourser le client et `society_no_account`.
   Historique `invoice` (actor = nom de l'expéditeur, target = nom du client, note). Notifications.

**Données envoyées au client** : jamais d'identifier / citizenid / license ; les cibles sont désignées par leur id
serveur, les employés par un `id` de session. Les noms d'employés ne sont envoyés qu'au patron de la société.
Les messages console ne contiennent ni identifiant ni montant de joueurs en dehors de `Config.Debug`.

---

## 14. Checklist de livraison (pour l'auditeur)
- `luacheck resources templates` : 0 erreur ; `node --check web/script.js`.
- `bridge/`, `shared/`, `web/kit/` identiques octet pour octet à `templates/pop_base`.
- 10 locales présentes avec **toutes** les clés (base + section 9) ; aucun texte en dur (Lua et HTML/JS).
- Aucun `Wait(0)` hors affichage d'une offre / `Bridge.Progress` ; aucune boucle serveur ; < 0.02 ms au repos.
- Fonctionne avec ESX (Legacy et ancien), QBCore, Qbox ; esx_addonaccount, qb-banking, qb-management, Renewed-Banking
  et repli `pop` ; ox_target, qb-target et prompt natif ; standalone : démarre sans erreur (avertissement console).
- Tests de sécurité : montants négatifs / décimaux / énormes, `employeeId` d'une autre session, action après
  changement de job, double acceptation d'une offre, recrutement à distance, facture à soi-même, retrait
  simultané par deux patrons (verrou société).
