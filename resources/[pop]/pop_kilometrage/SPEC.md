# pop_kilometrage : SPEC (contrat commun Serveur / Client / NUI)

> Référence unique : noms repris **à l'identique**. API commune : `Bridge.*`, `Callback.*`, `L()`, `Pop.*`
> (voir `templates/pop_base/README.md`). Modèle lu (pas copié) : `[system]/tab_kilometrage/`.

---

## 1. Description et fonctionnalités

Compteur kilométrique par plaque, persistant, affiché discrètement en voiture.

- **Calcul côté serveur** (le client n'envoie rien) : toutes les 2 s, pour chaque joueur **conducteur**, le serveur
  mesure la distance parcourue par son véhicule (positions serveur). Les sauts impossibles (téléportation, mise en
  fourrière) sont ignorés. Faille de l'ancien script corrigée : `updateMileage` acceptait n'importe quelle valeur.
- **Persistance oxmysql** par plaque (table `pop_kilometrage`), écriture groupée toutes les 60 s et à la sortie du
  véhicule. Un véhicule n'est enregistré qu'à partir de `MIN_SAVE_KM` (évite de stocker chaque voiture PNJ empruntée).
- **Affichage** : petite pastille en bas à droite, visible seulement à bord (conducteur ou passager) :
  `12 345.6 km` (ou `mi`). Valeur transmise par statebag d'entité : aucun échange réseau dédié.
- **Exports** : `GetMileage(plate)` (serveur), `SetMileage(plate, km)` (serveur), `GetMileage()` (client).
- Ignorés : véhicules `pop_temporary` (contrat POP, voir pop_vehiclepersistence), hélicoptères, avions, bateaux,
  sous-marins, trains.

**Hors périmètre** : entretien / usure, compteur journalier, affichage de la vitesse.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_kilometrage/
  SPEC.md                 Architecte
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR   (clés communes pop_base + section 8)
  README.md               SERVEUR   (installation, exports, exemple concession : SetMileage(plate, 0))
  sql/install.sql         SERVEUR
  bridge/ shared/         copiés par l'intégrateur (ne pas modifier)
  locales/*.lua (10)      SERVEUR   kit commun + section 9 (ar : _rtl = true)
  server/main.lua         SERVEUR
  client/main.lua         CLIENT    lecture du statebag, message NUI, export client
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

name 'pop_kilometrage'
author 'POP'
version '1.0.0'
description 'POP Kilometrage - per-plate odometer'

dependencies { 'oxmysql' }

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua' }
client_scripts { 'bridge/client.lua', 'client/*.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'bridge/server.lua', 'server/*.lua' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/**' }

escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
```

Constantes serveur (en tête de `server/main.lua`) :
| Constante | Valeur | Rôle |
|---|---|---|
| `TICK` | 2000 ms | mesure des distances |
| `SAVE_TICK` | 60000 ms | écriture des plaques modifiées |
| `MAX_SPEED` | 120.0 m/s | au-delà (distance / temps écoulé), l'échantillon est ignoré |
| `MIN_SAVE_KM` | 1.0 | kilométrage minimal pour créer une ligne SQL |
| `STATE_STEP` | 0.1 km | mise à jour du statebag seulement si la valeur arrondie au dixième change |
| `CACHE_TTL` | 600 s | une plaque non utilisée ni modifiée depuis ce délai sort du cache |
| `EXCLUDED_TYPES` | `{ heli = true, plane = true, boat = true, submarine = true, train = true }` | `GetVehicleType` |

Constante client : `KM_TO_MI = 0.621371`.

---

## 3. Données

`Plate.Normalize(plate)` (en tête de `server/main.lua`, même règle que pop_vehiclekeys) : espaces retirés, majuscules,
1 à 8 caractères alphanumériques, sinon `nil`.

Serveur, en mémoire :
```lua
Cache[plate] = {
    km      = 0.0,    -- kilométrage total (km, nombre décimal)
    loaded  = false,  -- valeur SQL reçue
    pending = 0.0,    -- km parcourus avant la fin du chargement (ajoutés au chargement)
    dirty   = false,  -- à écrire
    row     = false,  -- une ligne SQL existe pour cette plaque (lue au chargement ou après une écriture réussie)
    used    = 0,      -- os.time() du dernier usage
}
Track[src] = { veh = entity, plate = 'ABC123', pos = vector3, t = GetGameTimer() }
```

Statebag d'entité **`pop_kilometrage`** (posé par le serveur, répliqué) : kilométrage en km arrondi au dixième
(`math.floor(km * 10 + 0.5) / 10`).

---

## 4. Events

Aucun event réseau. Le serveur → client passe par le statebag `pop_kilometrage`.

---

## 5. Callbacks

Aucun.

---

## 6. Messages NUI

L'interface ne prend **jamais** le focus. Aucun callback JS → Lua propre (seuls ceux du kit).

### Lua → JS
**`pop_kilometrage:hud`** : envoyé seulement si `show` ou `value` change.
```json
{ "action": "pop_kilometrage:hud", "show": true, "value": 12345.6, "unit": "km" }
```
```json
{ "action": "pop_kilometrage:hud", "show": false }
```
`value` est déjà converti dans l'unité (`Config.Unit`) et arrondi au dixième par le Lua. `unit` : `"km"` | `"mi"`.

### Interface (Dev NUI)
- `index.html` : base pop_base + `<link rel="stylesheet" href="style.css">` après `kit/pop.css`. `#app` remplacé par
  `<div id="km" class="pop-panel pop-fade"><span id="km-value"></span> <span id="km-unit" class="pop-small"></span></div>`.
- `script.js` : `Pop.on('pop_kilometrage:hud', d => ...)`. Valeur : partie entière groupée par 3 chiffres avec une
  espace fine insécable (` `), puis `.` et une décimale (`12 345.6`) ; unité : `Pop.t('unit_' + d.unit)`.
  `Pop.show(km, d.show)`. Aucun texte en dur, `textContent` uniquement.
- `style.css` : `#km { position: fixed; right: 24px; bottom: 24px; font-variant-numeric: tabular-nums; }`, fond
  `--pop-bg`, texte `--pop-size`, unité `--pop-size-sm` en `--pop-muted`, aucun dégradé ni ombre, transition = celle de
  `.pop-fade`. RTL : `[dir="rtl"] #km { right: auto; left: 24px; }`.

---

## 7. Exports publics

Serveur :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_kilometrage:GetMileage(plate)` | number (km, 1 décimale) | cache si chargé, sinon `MySQL.scalar.await` (**bloquant** : appeler dans un thread) ; 0 si inconnu ou plaque invalide |
| `exports.pop_kilometrage:SetMileage(plate, km)` | bool | `km` nombre fini ≥ 0 et ≤ 9 999 999 ; met à jour le cache, écrit tout de suite (même sous `MIN_SAVE_KM`), met à jour le statebag si le véhicule est conduit |

Client :
| Export | Retour |
|---|---|
| `exports.pop_kilometrage:GetMileage()` | km du véhicule actuel (statebag), ou `nil` à pied / valeur inconnue |

---

## 8. config.lua

`config.lua` du template à l'identique, puis :

```lua
-- ─── pop_kilometrage ─────────────────────────────────────────

-- Unité affichée : 'km' ou 'mi' (la base stocke toujours des km).
Config.Unit = 'km'

-- Affiche le compteur à bord d'un véhicule.
Config.Hud = true
```

---

## 9. Locales

10 fichiers (Dev Serveur) : kit commun inchangé + clés ci-dessous.

| Clé | en | fr |
|---|---|---|
| `unit_km` | km | km |
| `unit_mi` | mi | mi |

---

## 10. Schéma SQL

`sql/install.sql` (aussi exécuté au démarrage) :
```sql
CREATE TABLE IF NOT EXISTS `pop_kilometrage` (
    `plate`      VARCHAR(8)   NOT NULL,
    `km`         DOUBLE       NOT NULL DEFAULT 0,
    `updated_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`plate`)
);
```
Lecture : `MySQL.scalar('SELECT km FROM pop_kilometrage WHERE plate = ?', { plate })`.
Écriture : `INSERT INTO pop_kilometrage (plate, km, updated_at) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE km = VALUES(km), updated_at = VALUES(updated_at)`.
Requêtes **paramétrées**.

---

## 11. Comportement client (`client/main.lua`)

- Si `Config.Hud` est faux : aucune boucle (l'export client reste disponible).
- **Une boucle** : à pied → `Wait(1000)`, envoie `show = false` une seule fois. À bord (`GetVehiclePedIsIn(ped, false) ~= 0`) :
  `km = Entity(veh).state.pop_kilometrage` ; nombre → `value = Config.Unit == 'mi' and km * KM_TO_MI or km`,
  arrondi au dixième ; envoi `pop_kilometrage:hud` si `show` ou `value` a changé ; pas de nombre → `show = false`.
  `Wait(1000)`.
- Pause menu (`IsPauseMenuActive`) → `show = false`.
- Arrêt de la ressource : `show = false`.

---

## 12. Comportement serveur et sécurité (`server/main.lua`)

- **Démarrage** : `CREATE TABLE IF NOT EXISTS` dans un `pcall` (en cas d'échec : message console invitant à lancer
  `sql/install.sql`).
- **OneSync requis** : positions et véhicules des joueurs lus côté serveur (`GetPlayerPed`, `GetVehiclePedIsIn`).
- **Boucle `TICK`** : pour chaque `src` de `Bridge.GetPlayers()` :
  1. `ped = GetPlayerPed(src)`, `veh = GetVehiclePedIsIn(ped, false)`. Pas de véhicule, ou
     `GetPedInVehicleSeat(veh, -1) ~= ped`, ou `Entity(veh).state.pop_temporary`, ou `EXCLUDED_TYPES[GetVehicleType(veh)]`,
     ou plaque invalide → `stopTrack(src)` et suivant.
  2. `Track[src]` absent ou `veh` / plaque différents → `stopTrack(src)` puis nouveau `Track[src]` ; si la plaque n'est
     pas en cache : entrée créée et chargement SQL **asynchrone** (`km = valeur SQL + pending`, `loaded = true`).
  3. Sinon : `d = #(pos - Track.pos)`, `dt = (now - Track.t) / 1000` ; si `d <= MAX_SPEED * dt` et `d > 0.5` :
     ajouter `d / 1000` (à `km` si chargé, sinon à `pending`), `dirty = true`. Toujours `Track.pos, Track.t = pos, now`.
  4. Si chargé et `arrondi(km) ~= Entity(veh).state.pop_kilometrage` (pas de `STATE_STEP`) :
     `Entity(veh).state:set('pop_kilometrage', arrondi, true)` (comparaison au statebag de l'entité, pas à un cache).
- `stopTrack(src)` : si une plaque était suivie, la marquer pour écriture immédiate (si `dirty`), `Track[src] = nil`.
- **Écriture** (`save`) : entrée chargée et `dirty`, et (`row` ou `km >= MIN_SAVE_KM` ou écriture forcée par
  `SetMileage`) → `dirty = false` puis `MySQL.prepare` ; le callback pose `row = true`, ou remet `dirty = true` en cas
  d'échec (l'entrée est remise en cache si elle avait été retirée).
- **Boucle `SAVE_TICK`** : écrit les entrées selon la règle ci-dessus ; retire du cache les entrées inutilisées depuis
  `CACHE_TTL` si elles ne sont pas `dirty`, ou si elles n'ont pas de ligne et `km < MIN_SAVE_KM`.
- `Bridge.OnPlayerDropped` / `Bridge.OnPlayerUnloaded` : `stopTrack(src)`.
- **Arrêt** (`onResourceStop` de cette ressource, `txAdmin:events:serverShuttingDown`) : écriture de toutes les
  entrées selon la même règle.

**Sécurité**
- Aucune donnée client : distance, plaque et conducteur sont lus côté serveur.
- Un échantillon dont la vitesse moyenne dépasse `MAX_SPEED` est ignoré (téléportation, respawn, fourrière).
- Aucun `RegisterNetEvent` serveur ; exports accessibles uniquement aux autres ressources serveur (entrées validées).

---

## 13. Performance
- Client : une boucle à 1000 ms, une lecture de statebag, un message NUI seulement si la valeur change. Aucun `Wait(0)`.
- Serveur : une boucle de 2 s, quelques natives par joueur conducteur ; SQL groupé toutes les 60 s.

## 14. Checklist auditeur
- `luacheck resources templates` : 0 erreur ; `node --check web/script.js`.
- 10 locales ; aucun texte en dur (Lua, HTML, JS) ; RTL testé.
- Le client ne peut ni augmenter ni remettre à zéro un compteur.
