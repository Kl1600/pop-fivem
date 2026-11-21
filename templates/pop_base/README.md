# pop_base : fondation des scripts POP

Modèle de départ de chaque script POP. **Ce n'est pas une ressource déployée** : on le copie.
Les dossiers `bridge/`, `shared/`, `web/kit/` et `locales/` (clés communes) sont identiques dans tous les scripts :
on ne les modifie pas dans un script, on les corrige ici puis on recopie.

## Créer un nouveau script

```bash
cp -r templates/pop_base "resources/[pop]/pop_<nom>"
cd "resources/[pop]/pop_<nom>"
rm README.md   # réécrire un README propre au script
```

Puis :
1. `fxmanifest.lua` : `name 'pop_<nom>'`, `description`, et décommenter `@oxmysql/lib/MySQL.lua` seulement si le script stocke des données.
2. `config.lua` : garder les clés communes, ajouter celles du script à la suite.
3. `locales/*.lua` : ajouter les textes du script sous `-- Textes propres au script :` dans **les 10 fichiers**.
4. Remplacer `client/main.lua`, `server/main.lua`, `web/script.js` et le contenu de `#app` dans `web/index.html`.
   Styles propres au script : `web/style.css` (à ajouter dans `index.html` après `kit/pop.css`).
5. Préfixer events et callbacks par le nom du script : `pop_<nom>:server:action`, `pop_<nom>:getData`.

Ordre de chargement : `config.lua` → `shared/*.lua` → `locales/*.lua` → `bridge/<côté>.lua` → `client|server/*.lua`.

## Config commune

| Clé | Défaut | Valeurs |
|---|---|---|
| `Config.Locale` | `'en'` | en, fr, es, de, it, pt, nl, pl, tr, ar |
| `Config.Debug` | `false` | logs console |
| `Config.Framework` | `'auto'` | esx, qbcore, qbox, standalone |
| `Config.Inventory` | `'auto'` | pop_inventory, ox_inventory, qs-inventory, qb-inventory, ps-inventory, framework, none |
| `Config.Target` | `'auto'` | ox_target, qb-target, prompt |
| `Config.Notify` | `'auto'` | framework, ox_lib, pop (toast du kit), native |
| `Config.AccentColor` | `'#ff2e88'` | rose néon ; cyan `'#22d3ee'` |
| `Config.Keys` | E / X | touches du prompt natif et d'annulation |
| `Config.CallbackRateLimit` | `10` | appels/s par joueur et par callback (0 = illimité) |

Détection auto : premier lancé (`GetResourceState == 'started'`) dans l'ordre
qbx_core → es_extended → qb-core → standalone, et pop_inventory → ox_inventory → qs-inventory → qb-inventory → ps-inventory → framework.
Le framework et l'inventaire doivent donc être `ensure` **avant** `[pop]`.

## Traductions : `L`

| Fonction | Rôle |
|---|---|
| `L(key, ...)` | texte de `Config.Locale`, sinon anglais, sinon la clé ; arguments passés à `string.format` |
| `GetLocaleTable()` | toutes les clés (anglais + langue choisie) et `_rtl`, pour la NUI |

Clés communes : `cancel`, `confirm`, `close`, `interact`, `progress_cancelled`, `no_permission`, `wrong_job`,
`too_far`, `not_enough_money`, `missing_item` (%s), `inventory_full`, `cooldown` (%s secondes), `busy`, `error`.
Ajouter une langue : copier `en.lua`, changer le code. `_rtl = true` pour une langue de droite à gauche.

## Callbacks : `Callback`

Events préfixés par le nom de la ressource (aucune collision entre scripts). Timeout 10 s → `nil`.
Les valeurs de retour multiples sont transmises.

| Côté | Fonction | Rôle |
|---|---|---|
| serveur | `Callback.Register(name, fn(source, ...))` | répond aux clients (anti-spam : `Config.CallbackRateLimit`) |
| client | `Callback.Await(name, ...)` → `...` | appelle le serveur et attend (dans un thread) |
| client | `Callback.Trigger(name, cb, ...)` | idem, sans bloquer : `cb(...)` |
| client | `Callback.Register(name, fn(...))` | répond au serveur |
| serveur | `Callback.Await(name, playerId, ...)` → `...` | appelle un client et attend (seul ce joueur peut répondre) |
| serveur | `Callback.Trigger(name, playerId, cb, ...)` | idem, sans bloquer |

## Bridge serveur

| Fonction | Retour | Notes |
|---|---|---|
| `Bridge.Framework` / `Bridge.Inventory` | string | système détecté |
| `Bridge.GetPlayer(src)` | objet \| nil | xPlayer, Player QB/Qbox, `{ source }` en standalone |
| `Bridge.GetIdentifier(src)` | string \| nil | identifier ESX, citizenid QB/Qbox, license standalone |
| `Bridge.GetName(src)` | string \| nil | nom du personnage |
| `Bridge.GetJob(src)` | `{ name, label, grade, gradeLabel, onDuty }` \| nil | standalone : `unemployed`, 0, hors service |
| `Bridge.HasJob(src, jobs)` | bool | `'police'`, `{ 'police', 'sheriff' }` ou `{ police = 2 }` (grade min.) |
| `Bridge.GetMoney(src, account)` | number | `'cash'` \| `'bank'` \| `'black'` ; standalone : 0 |
| `Bridge.AddMoney(src, account, amount, reason?)` | bool | montant entier > 0 ; standalone : false |
| `Bridge.RemoveMoney(src, account, amount, reason?)` | bool | vérifie le solde avant |
| `Bridge.GetItemCount(src, item)` | number | |
| `Bridge.HasItem(src, item, count?)` | bool | count par défaut 1 |
| `Bridge.CanCarry(src, item, count?)` | bool | |
| `Bridge.AddItem(src, item, count?, metadata?)` | bool | vérifie CanCarry avant |
| `Bridge.RemoveItem(src, item, count?, metadata?, slot?)` | bool | vérifie la quantité avant ; `slot` : retire ce slot précis (vérifié via `GetItems`), ignoré si `SupportsMetadata()` est false |
| `Bridge.GetItems(src, item?)` | `{ { name, count, slot, metadata }, ... }` | toutes les piles, ou celles de `item` ; `metadata` jamais nil (`{}`) ; `slot` nil avec l'inventaire ESX de base ; `{}` si rien |
| `Bridge.SupportsMetadata()` | bool | true : pop_inventory, ox_inventory, qs/qb/ps-inventory, inventaire QBCore/Qbox ; false : inventaire ESX de base, standalone, `none` |
| `Bridge.RegisterUsableItem(item, cb(src, item, metadata))` | bool | |
| `Bridge.Notify(src, msg, type?, duration?)` | | type : info, success, error, warning |
| `Bridge.IsAdmin(src)` | bool | ACE `pop.admin` ou groupe admin/superadmin/god |
| `Bridge.GetPlayers()` | `{ src, ... }` | joueurs chargés |
| `Bridge.GetCoords(src)` | vector3 \| nil | position côté serveur |
| `Bridge.IsNear(src, coords, maxDist)` | bool | à utiliser pour toute action liée à un lieu |
| `Bridge.IsDead(src)` | bool | QBCore/Qbox metadata `isdead`/`inlaststand`, ESX statebag `isDead`/`dead`, sinon santé du ped <= 0 |
| `Bridge.OnPlayerLoaded(cb(src))` | | event `<ressource>:playerLoaded`, aussi émis au (re)démarrage pour les joueurs déjà connectés |
| `Bridge.OnPlayerUnloaded(cb(src))` | | event `<ressource>:playerUnloaded` : retour au choix du personnage sans quitter (ESX `esx:playerLogout`, QB/Qbox `OnPlayerUnload`) ; une fois par personnage, jamais lors d'un drop. Ensuite `GetPlayer`/`GetIdentifier` peuvent renvoyer nil : nettoyer ses données par src ici aussi |
| `Bridge.OnPlayerDropped(cb(src))` | | event `<ressource>:playerDropped` |

Correspondance des comptes : ESX `money` / `bank` / `black_money` ; QBCore/Qbox `cash` / `bank` / `black_money`
(si ce compte existe, sinon 0 et false).

ACE admin, dans `server.cfg` : `add_ace group.admin pop.admin allow`.

## Bridge client

| Fonction | Retour | Notes |
|---|---|---|
| `Bridge.Framework` / `Bridge.TargetSystem` / `Bridge.NotifySystem` | string | système détecté |
| `Bridge.GetPlayerData()` | table | données brutes du framework, `{}` en standalone |
| `Bridge.GetJob()` | `{ name, label, grade, gradeLabel, onDuty }` | |
| `Bridge.IsLoaded()` | bool | |
| `Bridge.OnPlayerLoaded(cb(playerData))` | | appelé tout de suite si déjà chargé |
| `Bridge.OnJobUpdate(cb(job))` | | job au format commun |
| `Bridge.Notify(msg, type?, duration?)` | | framework, sinon notification GTA |
| `Bridge.Target.AddBoxZone(id, coords, size, heading, options)` | id | size = vec3(longueur, largeur, hauteur) |
| `Bridge.Target.AddLocalEntity(entity, options)` | id | |
| `Bridge.Target.AddModel(models, options)` | id | nom, hash ou liste |
| `Bridge.Target.Remove(id)` | | |
| `Bridge.Progress(label, duration, opts?)` | bool | true si terminée ; `opts = { canCancel, disableMovement, disableCombat, anim = { dict, clip, flag } }` |
| `Bridge.CancelProgress()` / `Bridge.IsBusy()` | / bool | |
| `Bridge.OnUiClose(cb)` | | Échap ou `Pop.post('close')` ; le focus est déjà rendu |

Options de target : `{ { label, icon, distance, canInteract = fn(entity) → bool, onSelect = fn(entity) }, ... }`
(`entity` vaut nil pour une zone). Sans ox_target ni qb-target : prompt « [E] Texte » sur le côté, molette pour
changer d'option ; distance mesurée jusqu'à la boîte englobante de l'entité (props décalés compris) ou jusqu'au
bord de la zone (heading pris en compte) ; une seule boucle partagée (1000 ms au-delà de 30 m, 250 ms jusqu'à 5 m, 100 ms en approche,
chaque frame seulement à portée).

Tout est nettoyé à l'arrêt de la ressource (targets, prompt, animation, focus NUI).

## Kit NUI : `web/kit/`

`pop.css` : variables `--pop-accent`, `--pop-bg`, `--pop-radius`, `--pop-size`, `--pop-size-sm` ; classes
`pop-panel`, `pop-fade` + `is-visible`, `pop-key`, `pop-button`, `pop-small`.

`pop.js` :

| Fonction | Rôle |
|---|---|
| `Pop.post(name, data)` | `fetch` vers `RegisterNUICallback(name)` → Promise |
| `Pop.on(action, fn(data))` | reçoit `SendNUIMessage({ action = ... })` |
| `Pop.t(key, ...)` | texte traduit |
| `Pop.translate(root?)` | remplit les `[data-locale="clé"]` |
| `Pop.show(el, visible)` | fondu 150 ms |

Au chargement, le kit récupère langue, sens (RTL) et couleur via le callback `pop:ready` du bridge.
Messages HUD gérés par le kit : `pop:prompt`, `pop:progress`, `pop:notify`, `pop:locale`.

## Contrat de pop_inventory

Exports serveur appelés par le bridge (noms et signatures d'ox_inventory, arguments en plus facultatifs) :

| Export | Retour |
|---|---|
| `GetItemCount(inv, item, metadata?, strict?)` | number (filtre metadata : toutes les clés du filtre égales ; `strict` : égalité complète) |
| `AddItem(inv, item, count, metadata?, slot?)` | `true` \| `false, reason` |
| `RemoveItem(inv, item, count, metadata?, slot?)` | `true` \| `false, reason` (tout ou rien) |
| `CanCarryItem(inv, item, count, metadata?)` | bool |
| `Search(inv, 'slots', item)` | liste `{ name, count, slot, metadata }` (utilisé par `Bridge.GetItems`) |
| `GetInventoryItems(inv)` | liste d'items (`Bridge.GetItems` sans filtre) |
| `RegisterUsableItem(item, cb(src, item, metadata, slot))` | true |

`inv` = source du joueur pour le bridge. Ordre de démarrage : `ensure pop_inventory` **avant** `ensure [pop]`,
sinon les autres scripts ne le détectent pas (détection au démarrage du bridge).

## Vérifier

```bash
luacheck templates resources            # depuis la racine du dépôt (.luacheckrc)
node --check web/kit/pop.js
```
