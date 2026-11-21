# pop_bank : SPEC (contrat commun Serveur / Client / NUI)

> Ce document est **la référence unique**. Les noms (fichiers, events, callbacks, clés de config, clés de locale,
> champs de données, messages NUI) doivent être repris **à l'identique**. En cas de doute : ce fichier fait foi.
> API commune à utiliser telle quelle : `Bridge.*`, `Callback.*`, `L()` (voir `templates/pop_base/README.md`).

---

## 1. Description et fonctionnalités

Banque simple sur le compte `bank` du framework : **dépôt**, **retrait**, **virement** et **historique**.
Aucun compte parallèle : le solde est celui du framework (`Bridge.GetMoney/AddMoney/RemoveMoney`).

**Où**
- **Guichets** (`Config.Banks`, agences Fleeca + Pacific Standard) : dépôt, retrait, virement, historique.
- **ATM** (`Config.AtmModels`, coordonnées autorisées dans `Config.Atms`) : retrait (plafonné par opération), dépôt,
  historique. **Pas de virement** à l'ATM.

**Gestes (esprit GTA 6)** : à l'ATM, courte étape « Insertion de la carte » (barre + animation) avant l'écran ;
au guichet, ouverture directe.

**Virement** : vers un joueur **en ligne**, désigné par son **ID serveur** ou son **identifiant** (citizenid
QBCore/Qbox, identifier ESX). Le destinataire est notifié avec le nom de l'émetteur.

**Historique** : les `Config.HistorySize` dernières opérations du personnage (oxmysql), purge des lignes de plus de
`Config.HistoryDays` jours au démarrage.

**UI** : panneau sobre à droite (≈ 320 px), focus NUI pendant l'ouverture. Soldes, 3 onglets (Dépôt / Retrait /
Virement), sélecteur de montants prédéfinis, liste d'historique compacte, ligne d'état (message traduit).

**Performance** : aucune boucle permanente côté client (targets du bridge ; surveillance de distance à 500 ms
seulement pendant l'ouverture). Serveur : aucune boucle ; une requête SQL par opération.

**Hors périmètre** : prêts, crypto, comptes entreprise, chèques, cartes bancaires, code PIN, braquage.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_bank/
  SPEC.md                 Architecte (ce fichier)
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR   (clés communes de pop_base + section 8)
  README.md               SERVEUR   (en ANGLAIS : installation, compatibilité, exports)
  sql/install.sql         SERVEUR
  locales/en.lua … ar.lua SERVEUR   10 fichiers, ar : _rtl = true
  server/main.lua         SERVEUR
  client/main.lua         CLIENT    blips, zones, ATM, ouverture, callbacks NUI
  web/index.html          NUI
  web/script.js           NUI
  web/style.css           NUI
```
`bridge/`, `shared/callback.lua`, `shared/locale.lua`, `web/kit/` : **copiés par l'intégrateur**.

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_bank'
author 'POP'
version '1.0.0'
description 'POP Bank - deposit, withdraw, transfer'

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

## 3. Données

### `Place` (client → serveur, désigne le lieu de l'opération)
```lua
{ type = 'bank', index = 3 }                    -- guichet : index de Config.Banks
{ type = 'atm', index = 1 } -- index dans Config.Atms
```

### `BankData` (serveur → client → NUI)
```lua
{
    cash    = 1250,            -- int, Bridge.GetMoney(src, 'cash')
    bank    = 48200,           -- int, Bridge.GetMoney(src, 'bank')
    atm     = false,           -- bool, place.type == 'atm'
    account = 'ABC12345' | nil,-- identifiant affichable : citizenid en QBCore/Qbox, nil en ESX et standalone
    presets = { deposit = { { id = 'preset_2', amount = 500 } }, withdraw = {}, transfer = {} },
    history = {                -- du plus récent au plus ancien, Config.HistorySize max
        { type = 'deposit', amount = 500, other = nil, time = 1773695584 },
        { type = 'transfer_in', amount = 2000, other = 'Jane Smith', time = 1773690000 },
    },
}
```
`type` ∈ `deposit` | `withdraw` | `transfer_out` | `transfer_in`. `other` : nom de l'autre partie (virements).
`time` : `os.time()` serveur ; la NUI l'affiche en date locale courte (`new Date(time * 1000).toLocaleDateString()`
+ heure `HH:MM`).

---

## 4. Events

Aucun event réseau propre au script : callbacks (section 5) et `Bridge.Notify` (destinataire d'un virement).
Bridge : `Bridge.OnPlayerDropped` / `Bridge.OnPlayerUnloaded` → libère `lastAction[src]`. Le verrou par identifiant reste actif jusqu’à la fin de l’opération.

---

## 5. Callbacks (`shared/callback.lua`)

Convention : `ok, reason, arg, data`. `data` (BankData à jour) est renvoyé **succès comme échec** quand le joueur est
valide (sinon nil). `nil` (timeout, anti-spam) = `error`.

| Nom | Paramètres (client → serveur) | Retour |
|---|---|---|
| `pop_bank:getData` | `place` (Place) | `ok, reason, arg, data` |
| `pop_bank:deposit` | `place`, `preset` (string) | `ok, reason, arg, data` |
| `pop_bank:withdraw` | `place`, `preset` (string) | `ok, reason, arg, data` |
| `pop_bank:transfer` | `place`, `target` (string), `preset` (string) | `ok, reason, arg, data` |

Raisons : `error`, `busy`, `too_far`, `invalid_amount`, `not_enough_money`, `atm_limit` (arg = plafond),
`transfer_limit` (arg = plafond), `transfer_atm`, `target_not_found`, `target_self`, `not_available`.

Messages de succès (renvoyés en `reason` quand `ok = true`, affichés dans la ligne d'état, **pas** de notification) :
`deposited` (arg = montant), `withdrawn` (arg = montant), `transferred` (arg = montant ; 2e arg = nom du destinataire,
voir section 9 : le serveur renvoie `arg` sous forme de table `{ amount, name }` pour cette clé uniquement).

> Simplification pour tous : le client traduit avec `L(reason, table.unpack(type(arg) == 'table' and arg or { arg }))`.

---

## 6. Messages NUI

Focus `SetNuiFocus(true, true)` à l'ouverture ; Échap → kit `close` → `Bridge.OnUiClose` → le client remet son
état à zéro et envoie `pop_bank:close`.

### Lua → JS
```json
{ "action": "pop_bank:open", "data": { "cash": 1250, "bank": 48200, "atm": false, "account": "ABC12345",
  "history": [ { "type": "deposit", "amount": 500, "other": null, "time": 1773695584 } ] } }
```
```json
{ "action": "pop_bank:close" }
```

### JS → Lua (`RegisterNUICallback`)
| Nom | Données | Réponse |
|---|---|---|
| `pop_bank:deposit` | `{ "preset": "preset_2" }` | `{ "ok": true, "message": "Deposited $500", "data": BankData }` |
| `pop_bank:withdraw` | `{ "preset": "preset_2" }` | idem |
| `pop_bank:transfer` | `{ "target": "12", "preset": "preset_2" }` | idem |
| `close` | (kit) | bridge |

Le client garde la `Place` courante (jamais envoyée par la NUI), transmet l'identifiant `preset`,
limite `target` à 64 caractères, appelle le callback serveur et répond : `ok`, `message = L(reason, ...)` déjà
traduit, `data` (peut être nil). Le JS désactive le bouton pendant l'attente.

### Interface (Dev NUI)
- `web/index.html` : `style.css` après `kit/pop.css`. `#bank` (`pop-panel pop-fade`, masqué) :
  - en-tête : `data-locale="ui_title"` (guichet) ou `ui_title_atm` (ATM) ; bouton `#bank-close` (`close`) ;
  - soldes : `ui_bank` + `Pop.t('money', bank)` (grand, accent) ; `ui_cash` + `Pop.t('money', cash)` (petit) ;
  - ligne `#bank-account` : `Pop.t('ui_account', account)` masquée si `account` est null ;
  - onglets `#tab-deposit` (`ui_deposit`), `#tab-withdraw` (`ui_withdraw`), `#tab-transfer` (`ui_transfer`,
    **masqué si `atm`**) ;
  - formulaire : champ `#bank-target` (onglet virement seulement, placeholder `Pop.t('ui_target_hint')`) ; champ
    `#bank-amount` (liste des choix de `BankData.presets` pour l’action courante) ; bouton `#bank-submit` (`confirm`) ;
  - ligne `#bank-status` (message ; `--pop-danger` si `ok = false`) ;
  - historique `#bank-history` (`ui_history`) : une ligne par opération : `Pop.t('history_' + type)`, `other` si
    présent, montant signé (`+` pour `deposit`/`transfer_in`, `−` sinon ; `deposit` et `withdraw` concernent le
    compte bancaire), date ; `ui_no_history` si vide. Max 30vh, défilement.
- Montants affichés : `Pop.t('money', n.toLocaleString())`. Entrée = valider. Aucun texte en dur.
- `web/style.css` : `position: fixed; right: 24px; top: 50%; transform: translateY(-50%); width: 320px;` onglet
  actif = soulignement 2 px accent ; champs fond `rgba(255,255,255,0.06)`, bordure 1 px, pas d'ombre ;
  masquer les flèches du `input[type=number]`. RTL : `right: auto; left: 24px`.

---

## 7. Exports publics

Serveur :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_bank:AddTransaction(identifier, type, amount, other?)` | bool | ajoute une ligne d'historique (salaires, factures d'autres scripts) ; `type` parmi les 4 valeurs, `amount` entier > 0 ; `balance` = 0 si le joueur n'est pas en ligne |
| `exports.pop_bank:GetHistory(identifier, limit?)` | tableau d'opérations (format `BankData.history`) | lecture ; `limit` défaut `Config.HistorySize`, max 100 |

Client :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_bank:IsOpen()` | bool | panneau ouvert |

---

## 8. config.lua (contenu exact)

Reprend **à l'identique** le `config.lua` de `templates/pop_base`, puis ajoute :

```lua
-- ─── pop_bank ───────────────────────────────────────────────

-- Guichets (zone d'interaction centrée sur le comptoir).
Config.Banks = {
    vector3(149.46, -1042.09, 29.37),   -- Legion Square
    vector3(314.23, -278.83, 54.17),    -- Hawick
    vector3(-350.80, -49.57, 49.04),    -- Burton
    vector3(-1213.00, -330.39, 37.79),  -- Rockford Hills
    vector3(-2962.71, 482.99, 15.70),   -- Great Ocean Highway
    vector3(1175.06, 2706.64, 38.09),   -- Route 68
    vector3(-112.20, 6469.20, 31.63),   -- Paleto Bay
    vector3(241.73, 220.70, 106.29),    -- Pacific Standard
}

Config.AtmModels = { 'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' }
Config.Atms = { -- positions de 121 props du jeu (liste intégrale dans config.lua)
    vector3(-301.657, -829.589, 31.420),
    -- ...
}

Config.Blip = { sprite = 108, color = 2, scale = 0.7 } -- guichets uniquement (false : pas de blip)

Config.MaxAmount   = 1000000 -- montant max par opération (dépôt, retrait au guichet)
Config.AtmWithdraw = 5000    -- retrait max par opération à l'ATM
Config.MaxTransfer = 100000  -- virement max par opération

Config.Amounts = { 100, 500, 1000, 5000, 10000, 100000, 1000000 }
Config.HistorySize = 20      -- opérations affichées
Config.HistoryDays = 30      -- les opérations plus anciennes sont supprimées au démarrage
```

Constantes (code) : `ACTION_DISTANCE = 3.0` (serveur), `TARGET_DISTANCE = 1.5` (client), `ACTION_DELAY = 1` seconde
minimum entre deux opérations d'un joueur (serveur), `CARD_TIME = 1500` ms (insertion de carte),
zone guichet `vec3(2.0, 2.0, 2.0)`, heading 0.

---

## 9. Locales

10 fichiers (en, fr, es, de, it, pt, nl, pl, tr, ar `_rtl = true`). Bloc « Kit commun » + clés ci-dessous.

| Clé | en | fr |
|---|---|---|
| `blip_name` | Bank | Banque |
| `target_bank` | Bank counter | Guichet |
| `target_atm` | Use ATM | Utiliser le distributeur |
| `inserting_card` | Inserting card... | Insertion de la carte... |
| `ui_title` | Bank | Banque |
| `ui_title_atm` | ATM | Distributeur |
| `ui_bank` | Bank account | Compte bancaire |
| `ui_cash` | Cash | Espèces |
| `ui_account` | Account no. %s | N° de compte %s |
| `ui_deposit` | Deposit | Dépôt |
| `ui_withdraw` | Withdraw | Retrait |
| `ui_transfer` | Transfer | Virement |
| `ui_amount` | Amount | Montant |
| `ui_target_hint` | Player ID or account no. | ID du joueur ou n° de compte |
| `ui_history` | History | Historique |
| `ui_no_history` | No transactions yet | Aucune opération |
| `history_deposit` | Deposit | Dépôt |
| `history_withdraw` | Withdrawal | Retrait |
| `history_transfer_out` | Transfer sent | Virement émis |
| `history_transfer_in` | Transfer received | Virement reçu |
| `money` | $%s | %s $ |
| `deposited` | Deposited $%s | Dépôt de %s $ effectué |
| `withdrawn` | Withdrew $%s | Retrait de %s $ effectué |
| `transferred` | Sent $%s to %s | %s $ envoyés à %s |
| `transfer_received` | You received $%s from %s | Vous avez reçu %s $ de %s |
| `invalid_amount` | Invalid amount | Montant invalide |
| `atm_limit` | ATM limit: $%s per withdrawal | Plafond du distributeur : %s $ par retrait |
| `transfer_limit` | Transfer limit: $%s | Plafond de virement : %s $ |
| `transfer_atm` | Transfers are only available at a bank counter | Les virements se font au guichet |
| `target_not_found` | Recipient not found or offline | Destinataire introuvable ou hors ligne |
| `target_self` | You can't transfer to yourself | Vous ne pouvez pas vous faire un virement |
| `not_available` | The bank is unavailable | La banque est indisponible |

Clés de base réutilisées : `confirm`, `close`, `too_far`, `not_enough_money`, `busy`, `error`, `progress_cancelled`.
Montants passés à `L()` côté Lua : entiers bruts (pas de séparateurs).

---

## 10. Schéma SQL

`sql/install.sql` (exécuté aussi au démarrage par le serveur : aucune action manuelle requise) :

```sql
CREATE TABLE IF NOT EXISTS `pop_bank_transactions` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64)  NOT NULL,
    `type`       VARCHAR(16)  NOT NULL,
    `amount`     INT UNSIGNED NOT NULL,
    `balance`    BIGINT       NOT NULL DEFAULT 0,
    `other`      VARCHAR(64)  NULL DEFAULT NULL,
    `created_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_identifier_time` (`identifier`, `created_at`)
);
```
- `balance` = solde bancaire après l'opération (pour un usage futur / admin ; non affiché).
- Démarrage : `CREATE TABLE IF NOT EXISTS`, puis `DELETE FROM pop_bank_transactions WHERE created_at < ?`
  (`os.time() - Config.HistoryDays * 86400`).
- Lecture : `SELECT type, amount, other, created_at FROM pop_bank_transactions WHERE identifier = ? ORDER BY id DESC
  LIMIT ?` (`MySQL.query.await`). Écriture : `MySQL.insert` (sans attendre) **après** le mouvement d'argent réussi.
- Requêtes toujours paramétrées.

---

## 11. Comportement attendu

### Serveur
- `toAmount(x)` accepte uniquement un nombre fini, entier et positif.
- `buildData(src, place)` : soldes, `atm`, `account` (`Bridge.GetIdentifier` si `Bridge.Framework` est `qbcore` ou
  `qbox`, sinon nil), historique.
- Virement réussi : `Bridge.Notify(target, L('transfer_received', amount, Bridge.GetName(src)), 'success')` ; deux
  lignes d'historique (`transfer_out` pour l'émetteur avec `other` = nom du destinataire, `transfer_in` pour le
  destinataire avec `other` = nom de l'émetteur).
- Démarrage : avertissement console si `Bridge.Framework == 'standalone'` (toutes les opérations → `not_available`).

### Client
- Blips (`Config.Blip`, nom `L('blip_name')`, short range) sur `Config.Banks`.
- `Bridge.Target.AddBoxZone('pop_bank_' .. i, coords, vec3(2.0, 2.0, 2.0), 0.0, { { label = L('target_bank'),
  icon = 'fa-solid fa-building-columns', distance = TARGET_DISTANCE, onSelect = openBank(i) } })`.
- `Bridge.Target.AddModel(Config.AtmModels, { { label = L('target_atm'), icon = 'fa-solid fa-money-bill',
  distance = TARGET_DISTANCE, onSelect = openAtm(entity) } })`.
- `openAtm(entity)` : `TaskTurnPedToFaceEntity` 500 ms, `Bridge.Progress(L('inserting_card'), CARD_TIME,
  { anim = { dict = 'amb@prop_human_atm@male@idle_a', clip = 'idle_a', flag = 1 } })`. Le client associe
  le prop à la position la plus proche dans `Config.Atms` (moins d’un mètre) et envoie l’index.
- Ouverture : ignorée si déjà ouvert ou `Bridge.IsBusy()` ; `Callback.Await('pop_bank:getData', place)` ; échec →
  notification ; sinon focus + `pop_bank:open`. Surveillance 500 ms tant qu'ouvert : distance au lieu > 3.0 ou mort →
  fermeture.
- Arrêt : blips supprimés, `pop_bank:close`.

---

## 12. Règles de sécurité (serveur, obligatoires)

Le serveur lit le montant dans `Config.Amounts` à partir de l’identifiant `preset`. Il borne le montant, vérifie
le lieu et lit les soldes lui-même.

**Commun à tous les callbacks**
1. `Bridge.Framework ~= 'standalone'` et `Bridge.GetIdentifier(src)` non nil, sinon `not_available` / `error`.
2. `place` contient un type (`bank` ou `atm`) et un index entier. Le serveur retrouve les coordonnées dans
   `Config.Banks` ou `Config.Atms` et vérifie `Bridge.IsNear` dans un rayon de 3 m. Échec → `too_far`.
3. Verrou par identifiant → `busy` ; libéré à la fin de l’opération. Délai `ACTION_DELAY` entre deux opérations
   (`lastAction[src]`) → `busy`. Anti-spam du template actif.
4. Joueur mort (`Bridge.IsDead`) → `error`.

**`deposit`** : `presetAmount`, ≤ `Config.MaxAmount`, sinon `invalid_amount` ; `Bridge.RemoveMoney(src, 'cash', n)`,
sinon `not_enough_money` ; `Bridge.AddMoney(src, 'bank', n)` ; si échec → rendre l'espèce et `error`.

**`withdraw`** : `presetAmount`, ≤ `Config.MaxAmount` ; à l'ATM ≤ `Config.AtmWithdraw`, sinon `atm_limit` (arg =
plafond) ; `RemoveMoney(src, 'bank', n)`, sinon `not_enough_money` ; `AddMoney(src, 'cash', n)` ; échec → recréditer
la banque, `error`.

**`transfer`**
1. `place.type == 'bank'`, sinon `transfer_atm`.
2. `presetAmount`, ≤ `Config.MaxTransfer`, sinon `transfer_limit` (arg = plafond) / `invalid_amount`.
3. `target` : string, longueur 1-64 après suppression des espaces. Si `^%d+$` et longueur ≤ 5 → ID serveur : doit
   figurer dans `Bridge.GetPlayers()`. Sinon → identifiant : comparé (égalité exacte) à `Bridge.GetIdentifier(p)`
   pour chaque joueur de `Bridge.GetPlayers()`. Introuvable → `target_not_found`.
4. Destinataire = émetteur (même src ou même identifiant) → `target_self`.
5. `RemoveMoney(src, 'bank', n)`, sinon `not_enough_money` ; `AddMoney(target, 'bank', n)` ; échec → recréditer
   l'émetteur, `error`.
6. Le nom du destinataire n'est révélé à l'émetteur **qu'après** un virement réussi (pas de sonde des joueurs).

**Historique** : un joueur ne lit que les lignes de **son** identifiant (jamais fourni par le client).

---

## 13. Checklist de livraison (auditeur)
- `luacheck resources templates` : 0 erreur ; `node --check web/script.js`.
- `bridge/`, `shared/`, `web/kit/` identiques à `templates/pop_base`.
- 10 locales complètes ; aucun texte en dur.
- Aucun `Wait(0)` hors `Bridge.Progress` ; focus rendu (Échap, éloignement, mort, arrêt).
- Identifiants de montant inconnus et montants fournis directement : refusés. Double clic : un seul mouvement.
- ESX (Legacy et ancien), QBCore, Qbox ; ox_target, qb-target, prompt natif.
