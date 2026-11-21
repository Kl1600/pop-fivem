# SPEC — pop_dealing

Vente de drogue aux PNJ, façon GTA 6. Contrat commun des devs **Serveur**, **Client** et **NUI**.
Les noms (events, callbacks, messages NUI, clés de config et de locales) sont **à reprendre à l'identique**.

Fondation : `templates/pop_base` (lire `templates/pop_base/README.md`). API à utiliser telle quelle :
`Bridge.*`, `Callback.*`, `L()`, `Pop.*`. Aucun appel direct à un framework, un inventaire ou une notification.

---

## 1. Description et fonctionnalités

Le joueur active un **mode vente** (commande `/sell`) dans une zone de deal. Des clients PNJ viennent à lui un par un.
Il leur parle, **négocie le prix** dans un petit panneau à droite de l'écran, puis conclut ou refuse.

1. **Mode vente** : `/sell` active ou arrête la vente (aussi assignable à une touche dans les paramètres GTA, sans touche par défaut).
   Conditions vérifiées par le serveur : à pied, dans une zone (`Config.Zones`), au moins une drogue de `Config.Drugs`
   sur soi, pas policier en service, assez de policiers en service (`Config.Police.minOnline`), pas en délai après un piège.
2. **Clients PNJ** : **un seul client à la fois** par vendeur, toutes les `Config.Customers.interval` secondes.
   Le serveur choisit la drogue (parmi celles que le joueur possède), la quantité et le prix maximum secret.
   Le client du jeu fait apparaître un PNJ **réseau** à 20-45 m, qui marche vers le joueur (petit blip sur la carte).
3. **Verrouillage (claim)** : parler au client le verrouille pour la négociation (serveur). Un client ne sert que son vendeur.
4. **Négociation** : prix à l'unité réglable par `+` / `-` entre 50 % et 200 % du prix de la rue, prix de la rue affiché
   comme repère, **3 tentatives**. Refus avec **indice** : « beaucoup trop cher » ou « presque ». Plus de tentatives : le client part.
5. **Flic infiltré** (5 %) : il joue le jeu ; si le deal est **accepté**, c'est un piège : marchandise saisie, alerte police
   immédiate, mode vente coupé, délai de 5 min avant de revendre.
6. **Témoins (esprit GTA 6)** : à chaque vente conclue, le serveur compte les PNJ proches (25 m). Chaque témoin peut appeler
   la police ; le risque augmente avec le **prix demandé** (vendre cher = plus risqué). Ruelle vide = discret.
7. **Alerte police** : ps-dispatch, cd_dispatch ou qs-dispatch s'il est lancé, sinon notification + blip aux joueurs
   policiers en service (`Bridge.HasJob`). Position volontairement imprécise (± 20 m).
8. **Multiplicateur de territoire** : chaque zone a un `mult` (prix de la rue). Si `pop_territories` est lancé, la vente
   lui est déclarée (export `RecordDrugSale`) et il peut modifier le montant final.
9. **Paiement** configurable : argent sale (compte `black`, repli automatique sur `cash` si le framework n'a pas
   de compte sale, ex. QBCore), `cash`, ou un item (ex. `black_money` d'ox_inventory).
10. **HUD sobre** à droite : petite pastille « Vente en cours » (avec l'état du client) et panneau de négociation.

Hors périmètre (volontairement) : caméra de négociation, plusieurs clients simultanés, réputation, base de données.

**Prérequis** : OneSync (activé par défaut sur FXServer) car le serveur lit la position du PNJ client et compte les PNJ
proches. Aucune dépendance obligatoire. **Pas de SQL, pas d'oxmysql.**

---

## 2. Arborescence et répartition

```
resources/[pop]/pop_dealing/
  fxmanifest.lua          SERVEUR   (copie du template, adapté : voir §2.2)
  config.lua              SERVEUR   (clés communes du template + clés §8)
  README.md               SERVEUR   (installation, items, OneSync, intégrations optionnelles)
  bridge/
    server.lua            SERVEUR   COPIE STRICTE de templates/pop_base/bridge/server.lua
    client.lua            CLIENT    COPIE STRICTE de templates/pop_base/bridge/client.lua
  shared/
    callback.lua          SERVEUR   COPIE STRICTE de templates/pop_base/shared/callback.lua
    locale.lua            SERVEUR   COPIE STRICTE de templates/pop_base/shared/locale.lua
  locales/
    en.lua fr.lua es.lua de.lua it.lua pt.lua nl.lua pl.lua tr.lua ar.lua
                          SERVEUR   (clés communes du template + clés §9, dans les 10 fichiers ; ar : _rtl = true)
  server/
    main.lua              SERVEUR   (mode vente, clients, négociation, paiement, exports)
    police.lua            SERVEUR   (comptage police, témoins, alertes / dispatch)
  client/
    main.lua              CLIENT    (commande, PNJ, IA, target/prompt, NUI, alerte police fallback)
  web/
    index.html            NUI
    style.css             NUI
    script.js             NUI
    kit/pop.css           NUI       COPIE STRICTE de templates/pop_base/web/kit/pop.css
    kit/pop.js            NUI       COPIE STRICTE de templates/pop_base/web/kit/pop.js
```

Pas de dossier `sql/`.

### 2.1 Copies à faire (chaque dev fait les siennes, sans rien modifier)
- **Serveur** : `bridge/server.lua`, `shared/callback.lua`, `shared/locale.lua`, et part de `fxmanifest.lua`,
  `config.lua`, `locales/*.lua` du template.
- **Client** : `bridge/client.lua`.
- **NUI** : `web/kit/pop.css`, `web/kit/pop.js` (et part de `web/index.html` du template).

Un manque dans bridge/shared/kit ne se corrige pas ici : le signaler (`-- NOTE:`) pour correction dans `templates/pop_base`.

### 2.2 fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_dealing'
author 'POP'
version '1.0.0'
description 'Drug selling to NPCs with negotiation'

-- Aucune dépendance obligatoire. OneSync requis (activé par défaut).

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

### 2.3 Partage entre fichiers serveur
`server/police.lua` définit une seule table globale `Police` (autorisée par `.luacheckrc`, `allow_defined_top`) :

| Fonction | Retour | Rôle |
|---|---|---|
| `Police.Count()` | integer | policiers en service : `Bridge.HasJob(p, Config.Police.jobs)` **et** `Bridge.GetJob(p).onDuty` |
| `Police.CountWitnesses(coords, ignoreEntity)` | integer | PNJ vivants non joueurs à moins de `Config.Witnesses.radius`, plafonné à `Config.Witnesses.max` (voir §10.4) |
| `Police.Alert(coords, kind)` | — | `kind` = `'deal'` \| `'bust'` ; décale la position de ± 20 m puis envoie au dispatch (§6.3) |

`server/main.lua` ne les appelle qu'à l'exécution (jamais au chargement) : l'ordre alphabétique de chargement convient.

---

## 3. Events

Préfixe : `pop_dealing:`. Toute donnée reçue du client est **revalidée** par le serveur (§10).

### 3.1 Client → Serveur (`RegisterNetEvent` côté serveur)

| Event | Paramètres | Quand | Effet serveur |
|---|---|---|---|
| `pop_dealing:server:customerReady` | `customerId: integer`, `netId: integer` | le PNJ client vient d'être créé et est en réseau | valide l'entité (§10.3), mémorise `entity`, le client devient « prêt » |
| `pop_dealing:server:customerLost` | `customerId: integer` | le client du jeu n'a pas pu créer le PNJ, ou le PNJ est mort / a disparu | retire le client (mode `'walk'`), planifie le suivant. Aucune notification |
| `pop_dealing:server:refuse` | `customerId: integer` | bouton Refuser ou Échap pendant la négociation | retire le client (mode `'walk'`), planifie le suivant |

### 3.2 Serveur → Client (`RegisterNetEvent` côté client)

| Event | Paramètres | Rôle client |
|---|---|---|
| `pop_dealing:client:customer` | `data: { id: integer, model: string }` | créer le PNJ client (§7.2) puis envoyer `customerReady` |
| `pop_dealing:client:customerLeave` | `customerId: integer`, `mode: 'walk' \| 'sold' \| 'flee'` | fermer la NUI si elle concerne ce client, retirer target + blip, faire partir le PNJ (§7.4). **Ne pas supprimer le PNJ** : le serveur le supprime 15 s plus tard |
| `pop_dealing:client:stop` | — | le serveur a coupé le mode vente : `selling = false`, cacher la pastille, fermer la NUI. Le message est déjà notifié par le serveur |
| `pop_dealing:client:policeAlert` | `coords: vector3`, `kind: 'deal' \| 'bust'` | fallback dispatch, envoyé seulement aux policiers en service : notification + blip (§7.6) |

### 3.3 Event local serveur (hook pour d'autres scripts / logs)

| Event | Paramètres | Émis |
|---|---|---|
| `pop_dealing:sold` (`TriggerEvent`, non réseau) | `src`, `item: string`, `qty: integer`, `amount: integer` (montant final payé), `coords: vector3` | après chaque vente réussie |

Le serveur ne fait **aucun** `RegisterNetEvent` sur `pop_dealing:sold`.

---

## 4. Callbacks (`shared/callback.lua`)

Enregistrés côté serveur avec `Callback.Register(name, fn(source, ...))`, appelés côté client avec `Callback.Await` (dans un thread).
Timeout ou erreur : le client reçoit `nil` et revient à un état propre (fermer la NUI si ouverte).

### `pop_dealing:toggle`
- Paramètres : aucun.
- Retour : `active: boolean` (nouvel état du mode vente).
- Si actif : arrête (retire le client en cours en mode `'walk'`), notifie `selling_stopped`, renvoie `false`.
- Sinon, vérifie dans l'ordre et notifie la première erreur (renvoie `false`) :
  1. délai après piège en cours → `cooldown` (secondes restantes) ;
  2. policier en service → `police_cannot_sell` ;
  3. dans un véhicule (`GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0`) → `in_vehicle` ;
  4. hors zone → `not_in_zone` ;
  5. aucune drogue de `Config.Drugs` → `no_drugs` ;
  6. `Police.Count() < Config.Police.minOnline` → `not_enough_police`.
- Succès : crée la session, premier client dans `interval` secondes, notifie `selling_started`, renvoie `true`.

### `pop_dealing:claim`
- Paramètres : `customerId: integer`.
- Retour : `offer | nil`.
  ```lua
  offer = {
      id = 12,              -- customerId
      label = 'drug_weed',  -- CLÉ de locale (le client fait L(offer.label))
      qty = 2,
      hint = 96,            -- prix de la rue à l'unité (prix x mult de zone)
      min = 48, max = 192,  -- bornes du prix proposable
      step = 5,             -- pas des boutons +/-
      attempts = 3,         -- tentatives restantes
      maxAttempts = 3,
  }
  ```
- Échecs (renvoie `nil`) : client inconnu / pas à lui / déjà verrouillé / pas prêt → rien ; trop loin → notifie `too_far` ;
  plus assez de marchandise → notifie `not_enough_drug` et retire le client (`'walk'`).
- Succès : `claimed = true`, `expiresAt` repoussé de `Config.Customers.timeout`.

### `pop_dealing:propose`
- Paramètres : `customerId: integer`, `price: integer` (prix à l'unité).
- Retour : `result | nil`.
  ```lua
  result = { status = 'refused', hint = 'too_high' | 'almost', attempts = 2 } -- négociation continue
  result = { status = 'accepted' }  -- vendu (notification sold envoyée par le serveur)
  result = { status = 'walkaway' }  -- plus de tentatives (notification deal_walkaway)
  result = { status = 'bust' }      -- flic infiltré (notification bust)
  result = { status = 'error' }     -- refusé par une vérification (notification selon le cas)
  ```
- Logique serveur : voir §10.2. Tous les statuts sauf `refused` retirent le client (`customerLeave`).

---

## 5. Messages NUI

Le nom de ressource côté JS vient de `GetParentResourceName()` (déjà géré par `Pop.post`).
Tous les textes affichés passent par `Pop.t(clé, ...)` / `data-locale`. Les montants : `Pop.t('money', n)`.

### 5.1 Lua → JS (`SendNUIMessage`, reçus avec `Pop.on`)

**Pastille de statut** (mode vente actif, hors négociation) :
```json
{ "action": "pop_dealing:status", "show": true, "state": "waiting", "command": "sell" }
{ "action": "pop_dealing:status", "show": true, "state": "coming",  "command": "sell" }
{ "action": "pop_dealing:status", "show": false }
```
Affichage : ligne 1 `hud_selling` (accent) ; ligne 2 `hud_waiting` ou `hud_coming` ; ligne 3 petite `hud_stop` avec `command`.

**Ouvrir la négociation** (`label` déjà traduit par le Lua) :
```json
{ "action": "pop_dealing:open", "label": "Weed", "qty": 2, "hint": 96, "min": 48, "max": 192, "step": 5, "attempts": 3, "maxAttempts": 3 }
```

**Fermer la négociation** :
```json
{ "action": "pop_dealing:close" }
```

### 5.2 JS → Lua (`RegisterNUICallback` dans `client/main.lua`)

| Callback | Corps envoyé | Réponse | Rôle |
|---|---|---|---|
| `propose` | `{ "price": 96 }` (entier, borné à [min, max] par le JS) | l'objet `result` du §4 tel quel, ou `null` si timeout | le Lua appelle `Callback.Await('pop_dealing:propose', currentId, price)` **dans un `CreateThread`** puis `cb(result)` |
| `refuse` | `{}` | `{ "ok": true }` | le Lua envoie `pop_dealing:server:refuse`, ferme la NUI, rend le focus |
| `close` | (kit : Échap) | géré par le bridge | le client le traite comme `refuse` via `Bridge.OnUiClose` |

Le JS n'envoie **jamais** d'id de client : le Lua connaît le client en cours.

### 5.3 Comportement attendu de l'interface (NUI)
- Placement : colonne de droite comme le HUD du kit (largeur 260 px, `right: 24px`), en bas pour ne pas chevaucher le HUD du kit (`bottom: 18vh`) ;
  en RTL (`dir="rtl"`), à gauche. Fond `--pop-bg`, accent `--pop-accent`, police du kit, 2 tailles (`--pop-size`, `--pop-size-sm`),
  fondu `pop-fade` 150 ms, aucune icône.
- Panneau de négociation, de haut en bas :
  1. `ui_title` à gauche, `ui_attempts` (tentatives restantes / max) à droite, petit ;
  2. `ui_qty` (qty, label) ;
  3. `ui_market` + `Pop.t('money', hint)`, petit ;
  4. `[-]  Pop.t('money', prix)  ui_unit  [+]` (prix en grand, accent) ;
  5. `ui_total` + `Pop.t('money', prix * qty)` ;
  6. boutons `ui_propose` (accent) et `ui_refuse` ;
  7. ligne de retour (vide par défaut) : `ui_thinking` pendant l'attente, puis `deal_refused_high` (`hint = too_high`)
     ou `deal_refused_close` (`hint = almost`).
- Prix de départ = `hint`. `+`/`-` ajoutent/retirent `step`, bornés à [min, max]. Clavier : `←`/`-` baisse, `→`/`+` monte,
  `Entrée` propose. Échap : le kit envoie `close`.
- Après `propose` : boutons désactivés + `ui_thinking` jusqu'à la réponse. `refused` : met à jour les tentatives, affiche
  l'indice, réactive. Autre statut ou `null` : réactive ; la fermeture vient du Lua (`pop_dealing:close`).
- Pastille et panneau ne sont jamais visibles en même temps (le Lua cache la pastille à l'ouverture).
- Textes longs (allemand) : retour à la ligne, aucun débordement.

---

## 6. Exports et intégrations

### 6.1 Exports fournis
| Côté | Export | Retour |
|---|---|---|
| serveur | `exports.pop_dealing:IsSelling(src)` | `boolean` |
| serveur | `exports.pop_dealing:StopSelling(src)` | `boolean` (true si une session a été arrêtée ; notifie `selling_stopped` et envoie `pop_dealing:client:stop`) |
| client | `exports.pop_dealing:IsSelling()` | `boolean` |

### 6.2 Contrat attendu de `pop_territories` (à implémenter par l'équipe territories)
```lua
-- serveur pop_territories
exports('RecordDrugSale', function(src, coords, amount)
    -- src    : joueur vendeur
    -- coords : vector3, lieu de la vente
    -- amount : integer > 0, montant calculé par pop_dealing (prix x quantité, mult de zone pop_dealing inclus)
    -- Enregistre la vente (influence, gang...) et renvoie :
    return finalAmount, { mult = 1.25, zone = 'grove' }
    -- finalAmount : integer >= 0 (montant réellement payé au joueur)
    -- info        : table optionnelle { mult: number, zone: string|nil } (utilisée seulement pour les logs)
end)
```
Utilisation dans pop_dealing (serveur) : seulement si `GetResourceState('pop_territories') == 'started'`, appel dans `pcall`.
Si erreur ou retour non numérique / négatif : on garde `amount`. Sinon `math.floor`, plafonné à `amount * 3` (sécurité).
`finalAmount == 0` : vente valide, rien n'est payé.

### 6.3 Dispatch police (dans `server/police.lua`)
`Config.Police.dispatch = 'auto'` : premier lancé parmi `ps-dispatch`, `cd_dispatch`, `qs-dispatch`, sinon `'notify'`.
Appels côté serveur avec `TriggerEvent` dans un `pcall`. Textes : `title = L('dispatch_title')`,
`message = L(kind == 'bust' and 'dispatch_bust' or 'dispatch_deal')`. Jobs : `Config.Police.jobs`.

```lua
-- ps-dispatch (v2) ; 'leo' = type de job ps-dispatch, on ajoute aussi les noms de jobs
TriggerEvent('ps-dispatch:server:notify', {
    message = message, codeName = 'drugsell', code = '10-31', icon = 'fas fa-cannabis',
    priority = kind == 'bust' and 1 or 2, coords = coords, street = '', jobs = { 'leo', table.unpack(Config.Police.jobs) },
})

-- cd_dispatch
TriggerEvent('cd_dispatch:AddNotification', {
    job_table = Config.Police.jobs, coords = coords, title = title, message = message,
    flash = 0, unique_id = ('pop_dealing_%d'):format(os.time()), sound = 1,
    blip = { sprite = 51, scale = 1.0, colour = 1, flashes = kind == 'bust', text = title, time = 5, radius = 0 },
})

-- qs-dispatch
TriggerEvent('qs-dispatch:server:CreateDispatchCall', {
    job = Config.Police.jobs, callLocation = coords,
    callCode = { code = '10-31', snippet = title }, message = message, flashes = kind == 'bust', image = nil,
    blip = { sprite = 51, scale = 1.0, colour = 1, flashes = kind == 'bust', text = title, time = Config.Police.blipTime * 1000 },
})

-- 'notify' (fallback) : à chaque joueur policier en service (même test que Police.Count)
TriggerClientEvent('pop_dealing:client:policeAlert', policeSrc, coords, kind)
```
`-- NOTE:` dans le code : formats valables pour les versions courantes de ces ressources ; à ajuster dans ce seul fichier si besoin.

---

## 7. Comportement client (`client/main.lua`)

Aucune boucle quand le mode vente est inactif. Aucun `Wait(0)` permanent. Ped et coords mis en cache dans les boucles.

### 7.1 Commande et état
- `RegisterCommand(Config.Command, toggle)` + `RegisterKeyMapping(Config.Command, L('keymap_toggle'), 'keyboard', '')`.
- `toggle` : `Callback.Await('pop_dealing:toggle')` → `selling = (résultat == true)` ; si vrai, pastille `state = 'waiting'`.
- `pop_dealing:client:stop` : nettoyage complet (§7.5).

### 7.2 Apparition du client (`pop_dealing:client:customer`)
1. Si un client existe déjà localement : le faire partir (`'walk'`) avant.
2. Charger le modèle (timeout 5 s, sinon `customerLost`).
3. Point d'apparition : jusqu'à 10 essais, angle aléatoire, distance aléatoire dans `Config.Customers.distance`,
   `GetSafeCoordForPed` (trottoir), de préférence hors champ (`not IsSphereVisible`). Échec → `customerLost`.
4. `CreatePed(4, hash, x, y, z, heading, true, true)` (réseau), `SetNetworkIdCanMigrate(netId, false)`,
   `SetEntityAsMissionEntity`, `SetBlockingOfNonTemporaryEvents(ped, true)`, `SetPedKeepTask`, `SetModelAsNoLongerNeeded`.
   Attendre que l'entité soit en réseau (max 2 s), puis `TriggerServerEvent('pop_dealing:server:customerReady', id, netId)`.
5. Blip sur l'entité : sprite 280, couleur 2, échelle 0.7, courte portée, nom `L('blip_customer')`.
6. Pastille `state = 'coming'` ; `TaskGoToEntity(ped, playerPed, -1, 1.5, 1.0, 1073741824, 0)`.

### 7.3 Approche et interaction
Boucle du client en cours uniquement : `Wait(500)`, `Wait(250)` à moins de 15 m.
- PNJ mort ou disparu → `customerLost`, nettoyage local.
- À moins de 3 m et joueur à pied : `ClearPedTasks`, `TaskTurnPedToFaceEntity(ped, playerPed, -1)`, une seule fois
  `Bridge.Target.AddLocalEntity(ped, { { label = L('target_talk'), icon = 'fas fa-comments', distance = 2.0,
  canInteract = function() return not negotiating end, onSelect = claim } })`.
- Joueur à plus de 6 m d'un client arrivé : relancer `TaskGoToEntity`.
- `claim` : `Callback.Await('pop_dealing:claim', id)` ; si `offer` : `negotiating = true`, cacher la pastille, faire se
  regarder joueur et PNJ, `SendNUIMessage({ action = 'pop_dealing:open', label = L(offer.label), ... })`, `SetNuiFocus(true, true)`.
- `propose` (NUI) : voir §5.2. Si `status` ≠ `refused` (ou `nil`) : fermer la négociation.
- Fermer la négociation = `SendNUIMessage({ action = 'pop_dealing:close' })`, `SetNuiFocus(false, false)`,
  `negotiating = false`, pastille réaffichée si toujours en vente.

### 7.4 Départ (`pop_dealing:client:customerLeave`)
Retirer target et blip, fermer la négociation si elle concerne ce client, pastille `'waiting'`, puis :
- `'sold'` : anim `mp_common` `givetake1_a` sur le joueur et `givetake1_b` sur le PNJ (1,5 s), puis `TaskWanderStandard(ped, 10.0, 10)` ;
- `'walk'` : `TaskWanderStandard` ;
- `'flee'` : `TaskSmartFleePed(ped, playerPed, 100.0, -1, false, false)`.
Le PNJ est ensuite oublié côté client (le serveur le supprime).

### 7.5 Nettoyage
`pop_dealing:client:stop` et `onResourceStop` : fermer la NUI et rendre le focus, cacher la pastille, retirer target/blip,
arrêter la boucle. À `onResourceStop` seulement : `DeleteEntity` du PNJ local s'il existe encore.

### 7.6 Alerte police fallback (`pop_dealing:client:policeAlert`)
Nom de rue : `GetStreetNameFromHashKey(GetStreetNameAtCoord(x, y, z))`.
`Bridge.Notify(L(kind == 'bust' and 'police_alert_bust' or 'police_alert', rue), 'warning')`.
Blip aux coords : sprite 51, couleur 1, échelle 1.0, clignotant, nom `L('dispatch_title')`, retiré après
`Config.Police.blipTime` secondes (`SetTimeout`).

---

## 8. config.lua (contenu complet)

```lua
Config = {}

-- ===== Clés communes POP (identiques au template) =====
Config.Locale = 'en'
Config.Debug = false
Config.Framework = 'auto' -- 'esx' | 'qbcore' | 'qbox' | 'standalone'
Config.Inventory = 'auto' -- 'pop_inventory' | 'ox_inventory' | 'qs-inventory' | 'qb-inventory' | 'ps-inventory' | 'framework' | 'none'
Config.Target    = 'auto' -- 'ox_target' | 'qb-target' | 'prompt'
Config.Notify    = 'auto' -- 'framework' | 'ox_lib' | 'pop' | 'native'
Config.AccentColor = '#ff2e88'
Config.Keys = {
    Interact = { control = 38, label = 'E' },
    Cancel   = { control = 73, label = 'X' },
}
Config.CallbackRateLimit = 10

-- ===== pop_dealing =====

-- Commande pour activer / arrêter la vente (assignable à une touche dans les paramètres GTA).
Config.Command = 'sell'

-- Drogues vendables : [nom de l'item] = { label = clé de locale, price = prix de la rue à l'unité, amount = { min, max } demandés }
Config.Drugs = {
    ['weed_white-widow'] = { label = 'drug_weed', price = 80,  amount = { 1, 3 } },
    ['cokebaggy']        = { label = 'drug_coke', price = 200, amount = { 1, 2 } },
    ['meth']             = { label = 'drug_meth', price = 150, amount = { 1, 2 } },
}

-- Paiement : 'black' (argent sale, repli sur 'cash' si le framework n'a pas ce compte) | 'cash' | 'item'
-- Standalone : utilisez 'item' (aucun compte d'argent sans framework).
Config.Payment = { type = 'black', item = 'black_money' } -- item : utilisé seulement si type = 'item'

-- Zones de deal. mult = multiplicateur du prix de la rue. Liste vide = vente possible partout.
-- Le mult se cumule avec le multiplicateur de pop_territories s'il est lancé : laissez 1.0 dans les zones couvertes par un territoire.
Config.Zones = {
    { coords = vec3(-1223.0, -1481.0, 4.4), radius = 100.0, mult = 1.0 }, -- Vespucci Beach
    { coords = vec3(167.0, -1717.0, 29.3),  radius = 90.0,  mult = 1.0 }, -- Strawberry
    { coords = vec3(80.0, -1956.0, 21.1),   radius = 100.0, mult = 1.0 }, -- Davis
    { coords = vec3(-165.0, -1620.0, 33.0), radius = 110.0, mult = 1.0 }, -- Forum Drive (= territoire pop_territories 'forum')
    { coords = vec3(1850.0, 3700.0, 33.0),  radius = 250.0, mult = 1.0 }, -- Sandy Shores (= territoire pop_territories 'sandy')
}

-- Clients PNJ (un à la fois par vendeur)
Config.Customers = {
    interval = { 20, 40 },     -- secondes avant le client suivant (aléatoire)
    distance = { 20.0, 45.0 }, -- distance d'apparition autour du joueur (m)
    timeout  = 90,             -- secondes avant qu'un client non servi reparte
    models = {
        'a_m_y_hipster_01', 'a_m_y_hipster_02', 'a_f_y_hipster_01', 'a_m_y_skater_01',
        'a_m_y_downtown_01', 'a_m_m_eastsa_01', 'a_f_y_runner_01', 'a_m_y_stbla_01',
    },
}

-- Négociation (multiplicateurs du prix de la rue)
Config.Negotiation = {
    attempts = 3,            -- propositions avant que le client parte
    range    = { 0.5, 2.0 }, -- bornes du prix proposable
    accept   = { 0.9, 1.4 }, -- prix maximum secret du client (tiré au hasard)
}

-- Flic infiltré : piège seulement si le deal est accepté
Config.Undercover = { chance = 0.05, seize = true, cooldown = 300 } -- seize : marchandise saisie ; cooldown en secondes

-- Témoins : chaque PNJ proche peut appeler la police lors d'une vente (risque x prix demandé / prix de la rue)
Config.Witnesses = { radius = 25.0, chance = 0.08, max = 5 }

-- Police
Config.Police = {
    jobs      = { 'police', 'sheriff' },
    minOnline = 0,      -- policiers en service requis pour vendre
    dispatch  = 'auto', -- 'auto' | 'ps-dispatch' | 'cd_dispatch' | 'qs-dispatch' | 'notify'
    blipTime  = 60,     -- secondes (blip du fallback 'notify' et de qs-dispatch)
}
```
Les noms d'items par défaut sont ceux de QBCore ; le README explique comment les remplacer.

---

## 9. Locales

Chaque fichier : clés communes du template (`cancel`, `confirm`, `close`, `interact`, `progress_cancelled`, `no_permission`,
`wrong_job`, `too_far`, `not_enough_money`, `missing_item`, `inventory_full`, `cooldown`, `busy`, `error`) **inchangées**, puis
sous `-- Textes propres au script :` les clés ci-dessous. Le **dev serveur écrit les 10 fichiers** (traductions es, de, it, pt,
nl, pl, tr, ar à partir de l'anglais ; `ar` garde `_rtl = true`). Les devs client et NUI n'utilisent **que** ces clés
(ou les communes) et n'en ajoutent aucune.

`%s` = argument `string.format` / `Pop.t`, dans l'ordre indiqué.

| Clé | Utilisée par | en | fr |
|---|---|---|---|
| `selling_started` | serveur | You are selling. Customers will come to you. | Vente activée. Des clients vont venir vers toi. |
| `selling_stopped` | serveur | You stopped selling. | Vente arrêtée. |
| `no_drugs` | serveur | You have nothing to sell. | Tu n'as rien à vendre. |
| `out_of_drugs` | serveur | Out of stock, selling stopped. | Plus de marchandise, vente arrêtée. |
| `not_in_zone` | serveur | Nobody buys around here. | Personne n'achète dans le coin. |
| `left_zone` | serveur | You left the area, selling stopped. | Tu as quitté le secteur, vente arrêtée. |
| `in_vehicle` | serveur | Get out of the vehicle first. | Sors d'abord du véhicule. |
| `not_enough_police` | serveur | Not enough police in town. | Pas assez de policiers en ville. |
| `police_cannot_sell` | serveur | You can't sell while on duty. | Tu ne peux pas vendre en service. |
| `customer_left` | serveur | The customer left. | Le client est parti. |
| `not_enough_drug` | serveur | You don't have %sx %s anymore. (qty, label traduit) | Tu n'as plus %sx %s. |
| `sold` | serveur | Sold %sx %s for %s (qty, label traduit, `L('money', montant)`) | Vendu %sx %s pour %s |
| `deal_walkaway` | serveur | Forget it. The customer walks away. | Laisse tomber. Le client s'en va. |
| `bust` | serveur | It was an undercover cop! | C'était un flic infiltré ! |
| `witness_called` | serveur | Someone saw you. The police have been called. | Quelqu'un t'a vu. La police est prévenue. |
| `payment_failed` | serveur | Payment failed, deal cancelled. | Paiement impossible, deal annulé. |
| `dispatch_title` | serveur, client | Drug deal | Deal de drogue |
| `dispatch_deal` | serveur | Suspected drug deal reported | Deal de drogue suspect signalé |
| `dispatch_bust` | serveur | Undercover officer: drug deal busted | Agent infiltré : deal interrompu |
| `police_alert` | client | Suspected drug deal: %s (rue) | Deal de drogue suspect : %s |
| `police_alert_bust` | client | Undercover officer needs backup: %s (rue) | Agent infiltré, renforts demandés : %s |
| `target_talk` | client | Talk | Discuter |
| `blip_customer` | client | Customer | Client |
| `keymap_toggle` | client | Toggle drug selling | Activer / arrêter la vente |
| `drug_weed` | serveur, client | Weed | Weed |
| `drug_coke` | serveur, client | Cocaine | Cocaïne |
| `drug_meth` | serveur, client | Meth | Meth |
| `money` | serveur, NUI | $%s | %s $ |
| `hud_selling` | NUI | Selling | Vente en cours |
| `hud_waiting` | NUI | Waiting for a customer | En attente d'un client |
| `hud_coming` | NUI | A customer is coming | Un client arrive |
| `hud_stop` | NUI | /%s to stop | /%s pour arrêter |
| `ui_title` | NUI | Deal | Deal |
| `ui_attempts` | NUI | %s/%s (restantes, max) | %s/%s |
| `ui_qty` | NUI | %sx %s (qty, label) | %sx %s |
| `ui_market` | NUI | Street price | Prix de la rue |
| `ui_unit` | NUI | / unit | / unité |
| `ui_total` | NUI | Total | Total |
| `ui_propose` | NUI | Offer | Proposer |
| `ui_refuse` | NUI | Refuse | Refuser |
| `ui_thinking` | NUI | Thinking... | Il réfléchit... |
| `deal_refused_high` | NUI | Way too expensive. | Beaucoup trop cher. |
| `deal_refused_close` | NUI | Almost... go a bit lower. | Presque... baisse un peu. |

Une drogue ajoutée par l'admin dans `Config.Drugs` avec une nouvelle clé `label` doit être ajoutée au moins dans `en.lua`
(sinon `L()` affiche la clé brute) : à écrire dans le README.

---

## 10. Sécurité et logique serveur (`server/main.lua`)

### 10.1 État serveur (mémoire uniquement)
```lua
sellers[src]   = { zone = index | 0, nextAt = os.time() + n, customer = id | nil }
customers[id]  = { id, owner = src, item, qty, ref, maxUnit, min, max, step, attempts, isCop,
                   model, entity = nil, claimed = false, readyBy = os.time() + 15, expiresAt = os.time() + timeout }
bustUntil[identifier] = os.time() + Config.Undercover.cooldown   -- Bridge.GetIdentifier(src) ; sans identifiant, toggle refusé ; entrées expirées purgées au toggle
```
- `ref = math.floor(Config.Drugs[item].price * zone.mult + 0.5)` (mult = 1.0 si `Config.Zones` est vide).
- `maxUnit = math.floor(ref * rand(accept[1], accept[2]) + 0.5)` ; `min = math.max(1, math.floor(ref * range[1]))` ;
  `max = math.ceil(ref * range[2])` ; `step = math.max(1, math.floor(ref * 0.05 + 0.5))`.
- Drogue choisie au hasard parmi celles de `Config.Drugs` dont le joueur a au moins 1 ; `qty` = aléatoire dans `amount`,
  plafonnée au stock. `isCop = math.random() < Config.Undercover.chance`. Modèle aléatoire de `Config.Customers.models`.
- Zone : le joueur est dans la zone `i` si `Bridge.IsNear(src, zone.coords, zone.radius)` (marge de 10 m dans la boucle).

### 10.2 Boucle serveur
Un seul thread, lancé quand le premier vendeur s'active, terminé quand il n'y en a plus. `Wait(2000)`. Pour chaque vendeur :
1. Ped introuvable ou mort (`GetEntityHealth(GetPlayerPed(src)) <= 0`) → arrêt (`selling_stopped`).
   Vendeur qui prend son service police (`Police.IsOnDuty`) → arrêt (`police_cannot_sell`).
2. Hors de toute zone (rayon + 10 m) → arrêt (`left_zone`). Aucune drogue → arrêt (`out_of_drugs`).
3. Client en cours : pas prêt après `readyBy` → retiré sans message ; entité disparue → retiré ;
   `expiresAt` dépassé → retiré (`'walk'`) + notification `customer_left`.
4. Pas de client et `os.time() >= nextAt` → créer le client, `TriggerClientEvent('pop_dealing:client:customer', src, { id, model })`.

Retirer un client (fonction unique) : `TriggerClientEvent('pop_dealing:client:customerLeave', owner, id, mode)`, vider
`sellers[owner].customer`, `nextAt = os.time() + rand(interval)`, puis `SetTimeout(15000, DeleteEntity si l'entité existe)`.
Arrêter une session : retirer le client (`'walk'`), `sellers[src] = nil`, `TriggerClientEvent('pop_dealing:client:stop', src)`, notification.

### 10.3 Règles à vérifier
1. **Source** : `src = source` ; chaque event / callback vérifie que `customers[id]` existe et que `owner == src`.
   `customerId` doit être un entier (`math.type`), sinon ignoré.
2. **customerReady** : client non encore prêt ; `netId` entier ; `NetworkGetEntityFromNetworkId(netId)` existe
   (réessayer jusqu'à 5 x 200 ms) ; `GetEntityType(ent) == 1` ; `not IsPedAPlayer(ent)` ;
   `GetEntityModel(ent) == joaat(customer.model)` ; `NetworkGetEntityOwner(ent) == src` ;
   `Bridge.IsNear(src, GetEntityCoords(ent), Config.Customers.distance[2] + 20.0)`. Échec → client retiré sans message.
   Ne **jamais** supprimer une entité qui ne remplit pas ces conditions (un tricheur pourrait viser un véhicule ou un joueur).
3. **Distance à chaque action** (`claim`, `propose`) : `Bridge.IsNear(src, GetEntityCoords(customer.entity), 4.0)`,
   sinon `too_far` (et `status = 'error'`). Jamais de coordonnées venant du client.
4. **Claim** : client prêt, non verrouillé, `Bridge.HasItem(src, item, qty)`.
5. **Propose** : client verrouillé ; `price` entier, `min <= price <= max` (sinon `error` sans décompter de tentative) ;
   `attempts > 0` ; `Bridge.HasItem(src, item, qty)` (sinon `not_enough_drug`, client retiré `'walk'`, `error`). Puis :
   - `price > maxUnit` : `attempts - 1` ; à 0 → retiré (`'walk'`), notification `deal_walkaway`, `walkaway` ;
     sinon `refused` avec `hint = price > maxUnit * 1.2 and 'too_high' or 'almost'`.
   - `price <= maxUnit` et `isCop` : si `seize`, `Bridge.RemoveItem(src, item, qty)` ; `Police.Alert(coordsDuDeal, 'bust')` ;
     `bustUntil` ; client retiré (`'flee'`) ; notification `bust` (type `error`) ; session arrêtée **sans** `selling_stopped` ; `bust`.
   - sinon **vente** :
     1. si `Config.Payment.type == 'item'` : `Bridge.CanCarry(src, Config.Payment.item, price * qty)` sinon `inventory_full`, `error` ;
     2. `Bridge.RemoveItem(src, item, qty)` sinon `not_enough_drug`, `error` ;
     3. `amount = price * qty`, puis `pop_territories` (§6.2) ;
     4. paiement si `amount >= 1` : `'black'` → `Bridge.AddMoney(src, 'black', amount)`, si `false` → `'cash'` ;
        `'cash'` → `AddMoney(src, 'cash', ...)` ; `'item'` → `Bridge.AddItem(src, Config.Payment.item, amount)`.
        Échec → **rendre la drogue** (`Bridge.AddItem(src, item, qty)`), notification `payment_failed`, client retiré `'walk'`, `error` ;
     5. client retiré (`'sold'`), notification `sold` (type `success`), `TriggerEvent('pop_dealing:sold', ...)`, log si `Config.Debug` ;
     6. témoins : `w = Police.CountWitnesses(coordsDuDeal, customer.entity)` ;
        `chance = math.min(0.9, w * Config.Witnesses.chance * (price / ref))` ; si tirage réussi → `Police.Alert(coordsDuDeal, 'deal')`
        et notification `witness_called` (type `warning`) ;
     7. si le joueur n'a plus aucune drogue → session arrêtée (`out_of_drugs`) ; `accepted`.
6. **Aucun montant client** : le seul nombre accepté est `price`, borné par le serveur ; le total et le paiement sont calculés serveur.
   Le prix maximum secret (`maxUnit`) et `isCop` ne sont **jamais** envoyés au client.
7. **Anti-spam** : rate limit du callback (template) + tentatives limitées + un seul client à la fois + `interval` serveur.
   `refuse` / `customerLost` ignorés si le client n'est pas au joueur.
8. **Toggle** : toutes les conditions de §4 revérifiées serveur ; délai après piège stocké par identifiant (survit à une reconnexion).
9. **Coordonnées du deal** : `GetEntityCoords(customer.entity)`, à défaut `Bridge.GetCoords(src)`.
10. **Déconnexion** (`Bridge.OnPlayerDropped`) : supprimer immédiatement l'entité du client en cours (`DeleteEntity`),
    `sellers[src] = nil`. **Arrêt de la ressource** (`onResourceStop`) : supprimer toutes les entités clients.
11. **Logs** (`Config.Debug`) : activation/arrêt, ventes (src, item, qty, prix, montant final), pièges, alertes.

### 10.4 Témoins (`Police.CountWitnesses`)
Parcourir `GetAllPeds()` (appelé seulement au moment d'une vente) : garder les entités `~= ignoreEntity`,
`not IsPedAPlayer(ped)`, `GetEntityHealth(ped) > 0`, à moins de `Config.Witnesses.radius` de `coords`. S'arrêter à `Config.Witnesses.max`.

---

## 11. Performance (rappel pour l'audit)
- Client inactif : 0 thread actif. Vendeur sans client : aucune boucle client (la pastille NUI est statique).
- Client en cours : une boucle à 500 / 250 ms. Prompt natif géré par le bridge (target sinon).
- Serveur : un thread à 2 s seulement s'il y a des vendeurs. `GetAllPeds()` uniquement lors d'une vente conclue.
