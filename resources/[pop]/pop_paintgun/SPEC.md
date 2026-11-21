# pop_paintgun : SPEC (contrat commun Serveur / Client / NUI)

> Référence unique : noms repris **à l'identique**. API commune : `Bridge.*`, `Callback.*`, `L()`
> (voir `templates/pop_base/README.md`). Modèle lu (pas copié) : `tab_inventory/paint_*.lua`, `html/paint_picker.js`.

---

## 1. Description et fonctionnalités

Pistolet à peinture pour repeindre un véhicule, simple et lisible.

1. **Utiliser** l'item `Config.Item` près d'un véhicule (job `Config.Jobs` requis si défini).
2. **Choisir** dans un petit sélecteur sur le côté : la zone (primaire, secondaire, les deux) et une couleur parmi
   `Config.Colors` (pastilles, sans noms).
3. **Peindre** : barre de progression avec animation, bombe en main et jet de peinture coloré.
4. Le serveur valide (item, job, distance, couleur autorisée, durée) et retire 1 `Config.PaintItem` s'il est défini ;
   le serveur fait appliquer la couleur par le **propriétaire réseau** du véhicule (couleurs natives du jeu, donc
   reprises par les sauvegardes de garage).

**Pas de réservoir ni de pigments** (l'ancien système rouge/jaune/bleu est retiré : trop complexe).
**Performance** : aucune boucle permanente ; `Wait(0)` seulement pendant la barre (bridge).

**Hors périmètre** : couleur RGB libre, nacré, jantes, finitions mates séparées, peinture progressive.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_paintgun/
  SPEC.md                 Architecte
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR
  README.md               SERVEUR   (items, event pour les garages)
  bridge/server.lua       SERVEUR   copie STRICTE du template
  bridge/client.lua       CLIENT    copie STRICTE
  shared/callback.lua     SERVEUR   copie STRICTE
  shared/locale.lua       SERVEUR   copie STRICTE
  locales/*.lua (10)      SERVEUR   kit commun + section 9 (ar : _rtl = true)
  server/main.lua         SERVEUR
  client/main.lua         CLIENT    ouverture, NUI, barre, effets, application
  web/index.html          NUI
  web/script.js           NUI
  web/style.css           NUI
  web/kit/pop.css, pop.js NUI       copie STRICTE
```

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_paintgun'
author 'POP'
version '1.0.0'
description 'POP Paint Gun - repaint vehicles'

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua' }
client_scripts { 'bridge/client.lua', 'client/*.lua' }
server_scripts { 'bridge/server.lua', 'server/*.lua' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/**' }

escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
```

Constantes (en tête de `client/main.lua` et `server/main.lua`) : `VEHICLE_DISTANCE = 4.0` (client : recherche),
`ACTION_DISTANCE = 6.0` (serveur), `SESSION_TIMEOUT = 120` (secondes).

---

## 3. Données

- `target` : `'primary'` | `'secondary'` | `'both'`.
- `color` : entier, doit être un `id` de `Config.Colors`.
- Serveur : `sessions[src] = { t = os.time() }`, créée à l'utilisation de l'item (une session encore valide n'est
  **pas** écrasée, pour ne pas fausser la durée minimale d'une peinture en cours), consommée par `pop_paintgun:paint`.

---

## 4. Events

| Event | Sens | Paramètres | Destinataire | Rôle |
|---|---|---|---|---|
| `pop_paintgun:client:open` | S → C | aucun | le joueur | Item utilisé et contrôles OK : chercher le véhicule, ouvrir le sélecteur |
| `pop_paintgun:client:apply` | S → C | `netId`, `color`, `target` | propriétaire réseau du véhicule (`NetworkGetEntityOwner`, repli : le peintre) | Appliquer la couleur validée |
| `pop_paintgun:painted` | serveur local (`TriggerEvent`, **non réseau**) | `src`, `netId`, `color`, `target`, `plate` | autres ressources serveur | Pour les garages qui sauvegardent les couleurs (`plate` = `GetVehicleNumberPlateText`) |

Aucun event client → serveur.

---

## 5. Callbacks

| Nom | Paramètres | Retour |
|---|---|---|
| `pop_paintgun:paint` | `netId` (int), `color` (int), `target` (string) | `ok, reason, arg` |

Échec → le client notifie `L(reason or 'error', arg)` ; succès → le serveur notifie `painted` et envoie
`pop_paintgun:client:apply` au propriétaire réseau (le client peintre n'applique rien lui-même).
Raisons : `error`, `wrong_job`, `no_vehicle`, `too_far`, `invalid_color`, `missing_item` (arg = `L('item_gun')` ou
`L('item_paint')`), `busy`.

---

## 6. Messages NUI

### Lua → JS
**`pop_paintgun:open`**
```json
{ "action": "pop_paintgun:open",
  "colors": [ { "id": 0, "hex": "#0a0a0a" }, { "id": 27, "hex": "#c01618" } ],
  "current": { "primary": 27, "secondary": 0 } }
```
**`pop_paintgun:close`** : `{ "action": "pop_paintgun:close" }`

### JS → Lua (`RegisterNUICallback`)
| Nom | Données | Réponse | Effet Lua |
|---|---|---|---|
| `pop_paintgun:apply` | `{ "color": 27, "target": "both" }` | `{ "ok": true }` | `SetNuiFocus(false, false)`, ferme l'UI, lance la barre |
| `close` (kit) | `{}` | géré par le bridge | `Bridge.OnUiClose` → annule (aucune barre) |

Le Lua vérifie que `color` est un entier présent dans `Config.Colors` et `target` une des 3 valeurs, sinon ignore.

### Interface (Dev NUI)
- `index.html` : base pop_base + `style.css`. `#app` → `#paint` (`pop-panel pop-fade`, masqué) :
  - titre `data-locale="title"` ;
  - 3 boutons de zone (`pop-button pop-small`, `data-target`) : `target_primary`, `target_secondary`,
    `target_both` (actif = bordure couleur d'accent ; défaut `both`) ;
  - `#paint-grid` : pastilles 28 px, 6 par ligne, `background` = `hex`, pastille de la couleur actuelle de la zone
    marquée d'un petit point ; sélection = contour accent ;
  - boutons `data-locale="apply"` (désactivé tant qu'aucune couleur choisie) et `data-locale="cancel"`.
- `script.js` : `Pop.on('pop_paintgun:open', ...)` remplit et affiche ; `Pop.on('pop_paintgun:close', ...)` masque.
  Appliquer → `Pop.post('pop_paintgun:apply', { color, target })` puis masque. Annuler / Échap → `Pop.post('close')`
  puis masque. Construction du DOM sans `innerHTML` pour les données. Aucun texte en dur.
- `style.css` : panneau 260 px, `position: fixed; right: 24px; top: 40%; transform: translateY(-50%)` (au-dessus du
  centre pour ne pas chevaucher les notifications du kit), fond
  `--pop-bg`, aucun dégradé ni ombre lourde. RTL : à gauche.

---

## 7. Exports publics

Aucun. Intégration garages : event serveur local `pop_paintgun:painted` (section 4).

---

## 8. config.lua

`config.lua` du template à l'identique, puis :

```lua
-- ─── pop_paintgun ────────────────────────────────────────────

-- Pistolet à peinture (non consommé) et pot de peinture consommé à chaque utilisation (nil = aucun).
Config.Item      = 'spray_gun'
Config.PaintItem = 'paint_can'

-- false = tout porteur de l'item ; sinon jobs requis (format Bridge.HasJob, en service). Ex. { 'mechanic' }
Config.Jobs = false

-- Durée de la peinture (ms).
Config.Duration = 8000

-- Couleurs proposées : id = couleur native GTA, hex = aperçu de la pastille.
Config.Colors = {
    { id = 0,   hex = '#0a0a0a' }, { id = 1,   hex = '#1c1d21' }, { id = 4,   hex = '#999da0' },
    { id = 111, hex = '#ffffff' }, { id = 112, hex = '#eaeaea' }, { id = 158, hex = '#9a9fa0' },
    { id = 27,  hex = '#c01618' }, { id = 28,  hex = '#8c1b1d' }, { id = 150, hex = '#c0171c' },
    { id = 37,  hex = '#e25a29' }, { id = 38,  hex = '#f6901a' }, { id = 88,  hex = '#ffc400' },
    { id = 89,  hex = '#fcea5f' }, { id = 92,  hex = '#9acc40' }, { id = 53,  hex = '#777c4c' },
    { id = 54,  hex = '#2f592a' }, { id = 49,  hex = '#bfad8f' }, { id = 45,  hex = '#584635' },
    { id = 64,  hex = '#59667c' }, { id = 70,  hex = '#355e9c' }, { id = 71,  hex = '#4e6dc9' },
    { id = 74,  hex = '#6ea9c4' }, { id = 135, hex = '#f21896' }, { id = 137, hex = '#bf5bb0' },
    { id = 145, hex = '#622699' }, { id = 132, hex = '#0d1116' }, { id = 91,  hex = '#dec397' },
}
```

---

## 9. Locales

10 fichiers (écrits par le Dev Serveur).

| Clé | en | fr |
|---|---|---|
| `title` | Paint | Peinture |
| `target_primary` | Primary | Primaire |
| `target_secondary` | Secondary | Secondaire |
| `target_both` | Both | Les deux |
| `apply` | Paint | Peindre |
| `item_gun` | Paint gun | Pistolet à peinture |
| `item_paint` | Paint can | Pot de peinture |
| `no_vehicle` | No vehicle nearby | Aucun véhicule à proximité |
| `invalid_color` | This color isn't available | Cette couleur n'est pas disponible |
| `painting` | Painting... | Peinture en cours... |
| `painted` | Vehicle repainted | Véhicule repeint |

Clés de base réutilisées : `cancel`, `wrong_job`, `too_far`, `missing_item`, `busy`, `error`, `progress_cancelled`.

---

## 10. Schéma SQL

Aucun.

---

## 11. Comportement client (`client/main.lua`)

- **`open`** : si `uiOpen` et `IsNuiFocused()` → ignoré ; si `uiOpen` sans focus (état orphelin) → `closeUi()` puis
  on continue. Ignoré si peinture en cours, `Bridge.IsBusy()` ou en véhicule. Attente que `IsNuiFocused()` soit faux
  (1 s max, pas de 50 ms), sinon ignoré (autre interface). Véhicule le plus proche
  (`GetGamePool('CVehicle')`, ≤ `VEHICLE_DISTANCE`, réseau) ; aucun → `no_vehicle`. Mémorise `netId` ;
  `GetVehicleColours(veh)` → `current` ; préchargement du prop et des particules (`RequestModel`,
  `RequestNamedPtfxAsset`, libérés si annulé) ; `SendNUIMessage(pop_paintgun:open)` ; `SetNuiFocus(true, true)`.
- **`pop_paintgun:apply`** : valide les données, ferme l'UI, puis :
  - bombe en main : prop local `prop_cs_spray_can` (création refusée, `0` → pas de prop) attaché main droite (os 57005, offset `0.12, 0.0, -0.04`,
    rotation `-70.0, 0.0, 0.0`) ;
  - jet : `RequestNamedPtfxAsset('scr_recartheft')` (timeout 3 s), `UseParticleFxAsset`,
    `StartParticleFxLoopedOnEntity('scr_carsteal4_spraycan', prop, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0, 1.0, false, false, false)`,
    couleur via `SetParticleFxLoopedColour` (hex → 0-1) ;
  - `TaskTurnPedToFaceEntity(ped, veh, 500)` puis `Bridge.Progress(L('painting'), Config.Duration, { anim =
    { dict = 'switch@franklin@lamar_tagging_wall', clip = 'lamar_tagging_wall_loop_lamar', flag = 49 } })` ;
  - fin (terminée ou non) : arrêt du jet, suppression du prop, `RemoveNamedPtfxAsset` ;
  - si terminée → `Callback.Await('pop_paintgun:paint', netId, color, target)` ; échec → notification. Aucune
    application locale.
- **`pop_paintgun:client:apply(netId, color, target)`** (reçu par le propriétaire réseau) : revalide `color` /
  `target`, puis `NetworkRequestControlOfEntity(veh)` (attente 1 s max, pas de 100 ms), `ClearVehicleCustomPrimaryColour` /
  `ClearVehicleCustomSecondaryColour` selon la zone, puis `SetVehicleColours(veh, p, s)` en gardant la couleur
  actuelle de la zone non peinte.
- **`Bridge.OnUiClose`** : UI fermée, rien d'autre.
- **Arrêt** : `SetNuiFocus(false, false)`, message `close`, prop et jet supprimés.

---

## 12. Sécurité serveur (`server/main.lua`)

**Item utilisable** `Config.Item` → si `Config.Jobs` : `Bridge.HasJob(src, Config.Jobs)` **et** en service, sinon
notification `wrong_job`. Puis `sessions[src] = { t = os.time() }` (sauf session encore valide, conservée) et `open`.
Rien n'est retiré.

**`pop_paintgun:paint(netId, color, target)`**
1. Verrou `busy[src]` (libéré dans tous les cas).
2. Session : `sessions[src]` existe et `os.time() - t <= SESSION_TIMEOUT`, sinon `error`. Durée minimale :
   `os.time() - t >= Config.Duration / 1000 - 1`, sinon `error`. Session supprimée dès ce contrôle (une peinture par
   utilisation d'item).
3. Types : `math.type(netId) == 'integer'`, `math.type(color) == 'integer'`, `target` dans les 3 valeurs, sinon `error`.
4. `color` présente dans `Config.Colors`, sinon `invalid_color`.
5. Véhicule : `NetworkGetEntityFromNetworkId`, existe, `GetEntityType == 2`, sinon `no_vehicle` ;
   `Bridge.IsNear(src, GetEntityCoords(veh), ACTION_DISTANCE)`, sinon `too_far`.
6. Job (si `Config.Jobs`) revérifié, sinon `wrong_job`. `Bridge.HasItem(src, Config.Item)`, sinon `missing_item` +
   `L('item_gun')`.
7. Si `Config.PaintItem` : `Bridge.RemoveItem(src, Config.PaintItem, 1)`, sinon `missing_item` + `L('item_paint')`.
8. Succès : `owner = NetworkGetEntityOwner(veh)` (repli `src`), `TriggerClientEvent('pop_paintgun:client:apply',
   owner, netId, color, target)`, notification `painted`, `TriggerEvent('pop_paintgun:painted', src, netId, color,
   target, GetVehicleNumberPlateText(veh))`, log debug.

`sessions` et `busy` nettoyés dans `Bridge.OnPlayerDropped` / `Bridge.OnPlayerUnloaded`.

---

## 13. Limites (README)
- La couleur est appliquée, sur ordre du serveur, par le propriétaire réseau du véhicule (le jeu la synchronise) ;
  un tricheur pourrait peindre sans le script, mais ne gagne aucun item ni argent. Le serveur protège les items.
- La barre de progression est côté client : un tricheur peut la sauter, mais le serveur impose la durée minimale et
  le pot de peinture est consommé quand même.
- Pour garder la couleur après un rangement au garage, le garage doit sauvegarder les propriétés du véhicule (la
  plupart le font) ou écouter `pop_paintgun:painted`.

## 14. Checklist auditeur
- Copies strictes ; 10 locales ; aucun texte en dur (Lua, HTML, JS) ; pas de `innerHTML` avec des données.
- Le focus NUI est toujours rendu (appliquer, annuler, Échap, arrêt de la ressource).
- Aucune boucle permanente.
