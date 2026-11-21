# pop_enterprisegarage : SPEC (contrat commun Serveur / Client / NUI)

> Référence unique : noms repris **à l'identique**. API commune : `Bridge.*`, `Callback.*`, `L()`, `Pop.*`
> (voir `templates/pop_base/README.md`). Modèle lu (pas copié) : `[system]/tab_enterprisegarage/`.
> **OneSync obligatoire** (création de véhicules côté serveur).

---

## 1. Description et fonctionnalités

Garage de société : les membres d'un job en service sortent un véhicule de service, puis le rangent.

1. **Sortir** : au comptoir du garage (target / prompt), un petit panneau liste les véhicules autorisés **pour son
   grade**. Clic → le serveur crée le véhicule sur une place libre, avec une **plaque générée** (préfixe du garage),
   et remet la clé via `pop_vehiclekeys` s'il est démarré.
2. **Ranger** : au volant, dans la zone de rangement du garage : `[E] Ranger le véhicule`. Le véhicule est
   **supprimé** (et la clé reprise). Tout membre du job peut ranger un véhicule de ce garage.
3. **Limite** : `Config.MaxPerPlayer` véhicules sortis en même temps par joueur.
4. **Nettoyage** : un véhicule détruit ou supprimé libère la place ; un véhicule dont le preneur est déconnecté ou
   n'a plus le job est supprimé dès qu'il est vide.

Pas de flotte persistante ni de sauvegarde des mods (simplicité) : chaque sortie donne un véhicule neuf.
Les véhicules portent le statebag `pop_temporary = true` (contrat POP : jamais repris par pop_vehiclepersistence).

**Hors périmètre** : achat de véhicules par la société, livrées par grade, carburant payant, fourrière.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_enterprisegarage/
  SPEC.md                 Architecte
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR   (clés communes pop_base + section 8)
  README.md               SERVEUR   (installation, OneSync, ajout d'un garage, intégration pop_vehiclekeys)
  bridge/ shared/         copiés par l'intégrateur (ne pas modifier)
  locales/*.lua (10)      SERVEUR   kit commun + section 9 (ar : _rtl = true)
  server/main.lua         SERVEUR
  client/main.lua         CLIENT    blips, targets, zone de rangement, NUI
  web/index.html          NUI
  web/script.js           NUI
  web/style.css           NUI
  web/kit/                copié par l'intégrateur (ne pas modifier)
```

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_enterprisegarage'
author 'POP'
version '1.0.0'
description 'POP Enterprise Garage - job service vehicles'

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua' }
client_scripts { 'bridge/client.lua', 'client/*.lua' }
server_scripts { 'bridge/server.lua', 'server/*.lua' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/**' }

escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
```

Constantes (en tête des fichiers concernés) :
| Constante | Valeur | Fichier |
|---|---|---|
| `ACTION_DISTANCE` | 3.0 m (+ 1.0 de tolérance serveur) | client (target), serveur |
| `STORE_RADIUS` | 5.0 m (+ 2.0 de tolérance serveur) | client (zone), serveur |
| `SPAWN_CLEAR` | 3.0 m (aucun véhicule à moins de cette distance d'une place) | serveur |
| `SPAWN_TIMEOUT` | 3000 ms | serveur |
| `CLEAN_TICK` | 30000 ms (boucle active seulement s'il y a des véhicules sortis) | serveur |

---

## 3. Données

Serveur :
```lua
Active[plate] = { src = 12, identifier = 'char1:abc', garage = 'lspd', entity = 1234 }
```
`plate` : 8 caractères, `garage.plate` (préfixe, 1 à 4 caractères alphanumériques en majuscules ; mis en majuscules,
caractères non alphanumériques retirés par `gsub('[^%w]', '')`) complété par des chiffres aléatoires ; unique (absent
de `Active`, de `reserved` et de `GetAllVehicles()`), 10 essais max sinon `error`.

Statebags d'entité posés à la création (serveur, répliqués) : `pop_temporary = true`,
`pop_enterprisegarage = '<id du garage>'` (le client n'affiche le prompt de rangement que pour ces véhicules),
`fuel = 100.0` (ox_fuel et compatibles).

Accès à un garage : `Bridge.HasJob(src, { [garage.job] = 0 })` **et** `Bridge.GetJob(src).onDuty`.
Véhicule autorisé : `Bridge.GetJob(src).grade >= vehicle.grade`.

---

## 4. Events

Aucun event réseau propre (tout passe par les callbacks).

---

## 5. Callbacks

Convention : `ok, reason | nil, arg | nil`. Échec → le client notifie `L(reason or 'error', arg)` ; succès → le
serveur notifie. `nil` = `error`.

| Nom | Paramètres | Retour |
|---|---|---|
| `pop_enterprisegarage:list` | `garage` (string, id) | `ok, reason, data` ; `data = { vehicles = { { index = 1, model = 'police' }, ... }, out = 0, max = 1 }` (seulement les véhicules du grade) |
| `pop_enterprisegarage:takeOut` | `garage` (string), `index` (int, index dans `garage.vehicles`) | `ok, reason, arg` |
| `pop_enterprisegarage:store` | `netId` (int) | `ok, reason` |

Raisons : `error`, `busy`, `too_far`, `wrong_job`, `grade_too_low`, `limit_reached` (arg = `Config.MaxPerPlayer`),
`spawn_blocked`, `not_service_vehicle`, `wrong_garage`, `not_driver`.

---

## 6. Messages NUI

### Lua → JS
**`pop_enterprisegarage:open`** (le Lua ajoute `name` = `GetLabelText(GetDisplayNameFromVehicleModel(joaat(model)))`,
ou le modèle si le libellé vaut `NULL`) :
```json
{ "action": "pop_enterprisegarage:open",
  "vehicles": [ { "index": 1, "name": "Police Cruiser" }, { "index": 2, "name": "Police Buffalo" } ],
  "out": 0, "max": 1 }
```
**`pop_enterprisegarage:close`** : `{ "action": "pop_enterprisegarage:close" }`.

### JS → Lua (`RegisterNUICallback`)
| Nom | Corps | Réponse | Effet Lua |
|---|---|---|---|
| `pop_enterprisegarage:takeOut` | `{ "index": 1 }` | `{ "ok": true }` ou `{ "ok": false, "error": "<clé>" }` | ferme l'UI (focus rendu), `Callback.Await('pop_enterprisegarage:takeOut', garageId, index)` ; échec → notification |
| `close` (kit) | `{}` | bridge | `Bridge.OnUiClose` → état fermé |

`garageId` est mémorisé côté Lua à l'ouverture (jamais envoyé par la NUI).

### Interface (Dev NUI)
- `index.html` : base pop_base + `style.css`. `#app` → `#garage` (`pop-panel pop-fade`, masqué) : titre
  `data-locale="title"`, liste `#garage-list` (une ligne par véhicule : nom + bouton `pop-button pop-small`
  `Pop.t('take_out')`, désactivé si `out >= max`), pied `#garage-count` = `Pop.t('out_count', out, max)`, bouton
  `data-locale="close"`.
- `script.js` : `Pop.on('pop_enterprisegarage:open')` remplit et affiche ; bouton → `Pop.post('pop_enterprisegarage:takeOut', { index })`
  puis masque ; fermer / Échap → `Pop.post('close')` puis masque ; `Pop.on('pop_enterprisegarage:close')` masque.
  `textContent` uniquement, aucun texte en dur.
- `style.css` : panneau 280 px, `position: fixed; right: 24px; top: 30%; transform: translateY(-50%)`, fond `--pop-bg`,
  une couleur d'accent, aucun dégradé ni ombre lourde, transition `.pop-fade`. RTL : à gauche.

---

## 7. Exports publics (serveur)

| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_enterprisegarage:IsServiceVehicle(plate)` | bool | plaque sortie par ce script |
| `exports.pop_enterprisegarage:GetPlayerVehicles(src)` | liste de plaques | véhicules sortis par ce joueur |

---

## 8. config.lua

`config.lua` du template à l'identique, puis :

```lua
-- ─── pop_enterprisegarage ────────────────────────────────────

-- Véhicules sortis en même temps par joueur.
Config.MaxPerPlayer = 1

-- Garages. id : unique. job : nom du job (en service). coords : comptoir (à pied).
-- spawns : places de sortie (x, y, z, cap). store : centre de la zone de rangement (au volant).
-- plate : préfixe de plaque (4 caractères max). blip : nil = aucun.
-- vehicles : model, grade minimum, type (GetVehicleType : 'automobile' par défaut, 'bike', 'heli', 'boat'...).
Config.Garages = {
    {
        id = 'lspd', job = 'police', plate = 'LSPD',
        coords = vec3(454.6, -1017.4, 28.4),
        spawns = { vec4(438.6, -1018.6, 28.4, 90.0), vec4(438.6, -1022.4, 28.4, 90.0) },
        store  = vec3(446.0, -1020.0, 28.4),
        blip   = { sprite = 357, color = 38 },
        vehicles = {
            { model = 'police',  grade = 0 },
            { model = 'police2', grade = 1 },
            { model = 'police3', grade = 2 },
            { model = 'policeb', grade = 2, type = 'bike' },
        },
    },
    {
        id = 'ems', job = 'ambulance', plate = 'EMS',
        coords = vec3(294.9, -574.6, 43.2),
        spawns = { vec4(294.6, -603.9, 43.1, 0.0) },
        store  = vec3(294.6, -598.0, 43.1),
        blip   = { sprite = 357, color = 1 },
        vehicles = {
            { model = 'ambulance', grade = 0 },
        },
    },
}
```

---

## 9. Locales

10 fichiers (Dev Serveur) : kit commun inchangé + clés ci-dessous.

| Clé | en | fr |
|---|---|---|
| `title` | Service vehicles | Véhicules de service |
| `blip` | Service garage | Garage de service |
| `open_target` | Service vehicles | Véhicules de service |
| `store_hint` | Store vehicle | Ranger le véhicule |
| `take_out` | Take out | Sortir |
| `out_count` | Out: %s / %s | Sortis : %s / %s |
| `taken_out` | Vehicle ready, plate %s | Véhicule prêt, plaque %s |
| `stored` | Vehicle stored | Véhicule rangé |
| `grade_too_low` | Your rank is too low for this vehicle | Votre grade est trop bas pour ce véhicule |
| `limit_reached` | You already have %s service vehicle(s) out | Vous avez déjà %s véhicule(s) de service sorti(s) |
| `spawn_blocked` | All parking spots are taken | Toutes les places sont occupées |
| `not_service_vehicle` | This isn't a service vehicle | Ce n'est pas un véhicule de service |
| `wrong_garage` | This vehicle belongs to another garage | Ce véhicule appartient à un autre garage |
| `not_driver` | You must be driving the vehicle | Vous devez être au volant |

Clés de base réutilisées : `close`, `too_far`, `wrong_job`, `busy`, `error`.

---

## 10. Schéma SQL

Aucun (aucune donnée persistante).

---

## 11. Comportement client (`client/main.lua`)

- **Blips** : un par garage avec `blip` (échelle 0.8, `SetBlipAsShortRange`, nom `L('blip')`).
- **Comptoir** : `Bridge.Target.AddBoxZone('pop_enterprisegarage_' .. g.id, g.coords, vec3(1.5, 1.5, 2.0), 0.0,
  { { label = L('open_target'), icon = 'fa-solid fa-warehouse', distance = ACTION_DISTANCE,
  canInteract = job local == g.job **et** en service (`myJob` / `myDuty` lus par Bridge.GetJob(), mis à jour par Bridge.OnJobUpdate), onSelect = open(g.id) } })`.
- **`open(id)`** : ignoré si UI ouverte ou `Bridge.IsBusy()` ; `Callback.Await('pop_enterprisegarage:list', id)` ;
  échec → notification ; succès → noms des véhicules, message `open`, `SetNuiFocus(true, true)`.
- **Rangement** : une boucle : distance à la zone `store` la plus proche **d'un garage de son job, en service** (aucun
  → `Wait(2000)`) : > 30 m → `Wait(1500)` ; ≤ 30 m → `Wait(500)` ; dans `STORE_RADIUS`, **conducteur** d'un
  véhicule dont `Entity(veh).state.pop_enterprisegarage` est défini → `Wait(0)` (seulement là) :
  prompt du kit `SendNUIMessage({ action = 'pop:prompt', show = true, key = Config.Keys.Interact.label, label = L('store_hint') })`
  (une fois à l'entrée, `show = false` à la sortie), `DisableControlAction(0, 86, true)` ;
  `IsDisabledControlJustReleased(0, 86)` ou `IsControlJustReleased(0, Config.Keys.Interact.control)` →
  `Callback.Await('pop_enterprisegarage:store', VehToNet(veh))` ; échec → notification ; puis `Wait(1000)`.
- **Arrêt** : focus rendu, UI et prompt masqués, blips supprimés.

---

## 12. Comportement serveur et sécurité (`server/main.lua`)

Au démarrage : avertissement console (anglais) si `Config.Garages` contient un `id` en double, un préfixe invalide ou
aucune place.

**`pop_enterprisegarage:list(garage)`** : garage connu (sinon `error`) ; accès (sinon `wrong_job`) ;
`Bridge.IsNear(src, g.coords, ACTION_DISTANCE + 1.0)` (sinon `too_far`) ; véhicules filtrés par grade ;
`out` = véhicules de `Active` dont `identifier` est celui du joueur.

**`pop_enterprisegarage:takeOut(garage, index)`**
1. Verrou `busy[src]` (libéré dans tous les cas) ; garage connu ; `math.type(index) == 'integer'` et
   `g.vehicles[index]` existe, sinon `error`.
2. Accès (`wrong_job`), proximité du comptoir (`too_far`), grade (`grade_too_low`).
3. Véhicules disparus ou épaves de l'identifiant libérés (`release`), puis véhicules sortis `< Config.MaxPerPlayer`, sinon `limit_reached` (arg = max).
4. Première place de `g.spawns` non réservée et sans véhicule à moins de `SPAWN_CLEAR` (`GetAllVehicles()`), sinon
   `spawn_blocked`.
5. Plaque générée (section 3 ; ni active ni réservée). `reserved[plate] = place` pendant la création, retiré ensuite
   dans tous les cas.
6. `veh = CreateVehicleServerSetter(joaat(v.model), v.type or 'automobile', x, y, z, w)` ; attente `DoesEntityExist`
   (`SPAWN_TIMEOUT`), sinon `error` (si l'entité apparaît plus tard, elle est supprimée). `SetEntityOrphanMode(veh, 2)`, `SetVehicleNumberPlateText(veh, plate)`,
   `SetVehicleDoorsLocked(veh, 1)`, statebags de la section 3.
7. `Active[plate] = { src, identifier, garage = g.id, entity = veh }`.
8. Si `GetResourceState('pop_vehiclekeys') == 'started'` : `exports.pop_vehiclekeys:GiveKey(src, plate)` (dans un `pcall`).
9. Notification `L('taken_out', plate)`, retour `true, nil, NetworkGetNetworkIdFromEntity(veh)`.

**`pop_enterprisegarage:store(netId)`**
1. netId entier, entité existante ; plaque serveur ; `Active[plate]` avec `entity == veh`, sinon `not_service_vehicle`.
2. Accès au garage **de ce véhicule** (`wrong_job`) ; `Bridge.IsNear(src, g.store, STORE_RADIUS + 2.0)`, sinon :
   près de la zone d'un autre garage → `wrong_garage`, sinon `too_far`.
3. Conducteur (`GetPedInVehicleSeat(veh, -1) == GetPlayerPed(src)`), sinon `not_driver`.
4. `release(plate)` : `Active[plate] = nil` **puis** `DeleteEntity(veh)` ; clé reprise
   (`exports.pop_vehiclekeys:RemoveKey(a.src, plate, true)` si démarré et preneur en ligne, `pcall`).
5. Notification `stored`, `true`.

**Nettoyage (`CLEAN_TICK`, seulement si `Active` n'est pas vide)** : pour chaque véhicule : entité disparue →
`Active[plate] = nil` + clé reprise ; épave (`GetVehicleEngineHealth <= -3999` ou `GetVehicleBodyHealth <= 0`) → `release` ; preneur déconnecté (`GetPlayerName(src)` nil) ou qui n'a plus accès au garage,
et véhicule vide (aucun siège occupé) → `release`.
`Bridge.OnPlayerDropped` / `Bridge.OnPlayerUnloaded` : `busy[src]` nettoyé, clé reprise pour **tous** ses véhicules,
et ses véhicules **vides** relâchés tout de suite (les autres au prochain nettoyage).
**Arrêt de la ressource** : pour chaque véhicule de `Active`, clé reprise puis `DeleteEntity`.

**Règles générales**
- Le client n'envoie qu'un id de garage, un index ou un netId : modèle, type, place, plaque, grade sont lus dans la
  config et côté serveur.
- **Anti-duplication** : verrou par joueur pendant la sortie, limite par identifiant, place vérifiée libre, plaque
  unique, suppression de `Active` avant `DeleteEntity`.
- Aucun `RegisterNetEvent` serveur ; anti-spam du template actif. `Config.Debug` : log des sorties / rangements.

---

## 13. Performance
- Client : boucle de rangement à 2000 / 1500 / 500 ms ; `Wait(0)` seulement au volant d'un véhicule de service dans
  la zone. Comptoirs via le bridge (target ou prompt partagé).
- Serveur : aucune boucle sans véhicule sorti ; nettoyage toutes les 30 s sinon.

## 14. Checklist auditeur
- `luacheck resources templates` : 0 erreur ; `node --check web/script.js`. 10 locales, aucun texte en dur.
- Impossible de sortir sans job / en service / grade, au-delà de la limite, ou loin du comptoir ; aucune double sortie
  par double clic.
- Focus NUI toujours rendu.
