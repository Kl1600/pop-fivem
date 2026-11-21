# SPEC — pop_territories

Guerre de territoires entre crews. Contrat commun des devs Serveur, Client et NUI : **les noms ci-dessous sont exacts et ne se changent pas.**
Base : `templates/pop_base` (lire `templates/pop_base/README.md`). API à utiliser : `Bridge.*`, `Callback.*`, `L()`, `Pop.*`.
Ressources liées : `pop_crew` (appartenance, optionnel, voir `resources/[pop]/pop_crew/SPEC.md` §3.3 et §6) et `pop_dealing` (appelle `RecordDrugSale`).

---

## 1. Description et fonctionnalités

Des zones (cercles ou polygones) sont définies dans `config.lua`. Dans chaque zone, chaque crew a une **influence** de 0 à 100.
La somme des influences d'une zone ne dépasse jamais 100 : gagner de l'influence fait reculer les rivaux.

1. **Gagner de l'influence**
   - Vente de drogue dans la zone (appel serveur `exports.pop_territories:RecordDrugSale`, fait par pop_dealing) : `+Config.Influence.PerSale`.
   - Présence : chaque minute, chaque crew ayant au moins un membre vivant dans la zone gagne `+Config.Influence.PerTick` (mort / à terre : `Bridge.IsDead(src)` si le bridge le fournit, sinon `GetEntityHealth(ped) <= 0`).
     La présence seule ne fait **pas** atteindre le seuil de prise : seul le crew propriétaire peut monter au-delà avec sa présence. Pour prendre une zone, il faut vendre.
2. **Perdre de l'influence** : chaque minute, un crew sans membre présent dans la zone perd `Config.Influence.Decay` (le tick ne tourne que s'il y a au moins un joueur connecté).
3. **Prise de contrôle** (avec hystérésis, pas de clignotement) :
   - un crew qui atteint `Config.Influence.Capture` (60) devient propriétaire ;
   - le propriétaire garde la zone tant que son influence reste ≥ `Config.Influence.Keep` (30) et qu'aucun autre crew n'atteint `Capture`.
   - Notifications au crew qui prend et au crew qui perd.
4. **Prix** (renvoyé à pop_dealing, pop_territories ne paie jamais rien lui-même) :
   - hors zone : ×1.0 ;
   - dans une zone : × `zone.price` (défaut 1.0 ; **se cumule** avec le `mult` de la zone de vente pop_dealing, appliqué avant par pop_dealing — laisser 1.0 si pop_dealing gère déjà le prix du quartier), puis × `Config.Prices.Owner` si le vendeur est du crew propriétaire, × `Config.Prices.Rival` si la zone a un propriétaire et que le vendeur n'en fait pas partie (avec ou sans crew).
5. **Risque pour les rivaux** : une vente rivale dans une zone tenue prévient les membres connectés du crew propriétaire (notification + zone approximative sur la carte pendant 60 s), au plus une fois par zone toutes les `Config.RivalAlertCooldown` secondes. `info.rival = true` est aussi renvoyé à pop_dealing (libre à lui d'augmenter son risque police).
6. **Blips de zone** (option `Config.ZoneBlips`) : une zone de rayon par territoire, colorée selon le propriétaire (gris si libre).
7. **HUD sobre** : en entrant dans une zone, petit panneau sur le côté (nom, propriétaire, influence de son crew) pendant `Config.HudDuration` secondes ; réapparaît quand le propriétaire change ou quand l'influence franchit `Capture` (une simple variation d'influence ne met à jour le panneau que s'il est déjà visible) ; commande `/territory` pour le réafficher.
8. **Commande admin** `/territoryadmin` (`Bridge.IsAdmin` ou console) : `info`, `reset`, `set`.
9. **Persistance** oxmysql (influence, propriétaire, nom/couleur des crews vus).
10. **Crew dissous** (pop_crew) : son influence est supprimée partout et ses zones redeviennent libres immédiatement.

### Appartenance à un crew (serveur, `server/crew.lua`)
Ordre de résolution, **évalué à chaque appel** (pop_crew peut démarrer après pop_territories) :
1. `GetResourceState('pop_crew') == 'started'` → `exports.pop_crew:GetPlayerCrew(src)` (appel protégé par `pcall`) → `{ id, name, color, rank, rankLabel }` ou nil.
   Clé de crew : `'crew:' .. id`. Label : `name`. Couleur : `color` (déjà `'#rrggbb'`).
   Si pop_crew est lancé mais renvoie nil → **pas de crew** (pas de repli sur les jobs).
2. Sinon, si `Config.UseJobsAsCrews == true` **et** `Bridge.Framework ~= 'standalone'` (pas de jobs en standalone) : job du joueur (`Bridge.GetJob(src).name`) présent dans `Config.JobCrews` → clé `'job:' .. jobName`, label = `job.label`, couleur = `Config.JobCrews[jobName]`.
3. Sinon : mode **désactivé** — un seul `print` au démarrage avec `L('crews_disabled')`. Les zones, blips et HUD fonctionnent (nom, propriétaire existant), l'influence ne bouge plus, `RecordDrugSale` applique seulement `zone.price` (et `Prices.Rival` si la zone a un propriétaire).

API de `server/crew.lua` (table globale `Crew`) :

| Fonction | Retour |
|---|---|
| `Crew.Get(src)` | crew interne \| nil (lecture fraîche, selon l'ordre ci-dessus) |
| `Crew.Mode()` | `'pop_crew'` \| `'jobs'` \| `'disabled'` |

Objet crew interne (utilisé partout, y compris dans les messages réseau) : `{ key = 'crew:12', label = 'Vice Kings', color = '#ff2e88' }`.
Sécurité de forme (même si pop_crew garantit déjà le format) : couleur acceptée seulement si `^#%x%x%x%x%x%x$` (mise en minuscules), sinon `'#ffffff'` ; label tronqué à 32 caractères, vide → `L('crew_unknown')`.
`GetCrewMembers` de pop_crew **n'est pas utilisé** : les membres connectés sont trouvés via le cache `crewOf[src]` (voir §10).

---

## 2. Arborescence et répartition

```
resources/[pop]/pop_territories/
  fxmanifest.lua          Serveur   (copié du template puis adapté, voir plus bas)
  config.lua              Serveur   (clés communes du template + clés §8)
  README.md               Serveur   (installation, config, exports, commande admin)
  SPEC.md                 Architecte
  bridge/
    server.lua            Serveur   COPIE À L'IDENTIQUE de templates/pop_base/bridge/server.lua
    client.lua            Client    COPIE À L'IDENTIQUE de templates/pop_base/bridge/client.lua
  shared/
    callback.lua          Serveur   COPIE À L'IDENTIQUE de templates/pop_base/shared/callback.lua
    locale.lua            Serveur   COPIE À L'IDENTIQUE de templates/pop_base/shared/locale.lua
    zones.lua             Serveur   propre au script (géométrie, utilisé client ET serveur, API §2.1)
  locales/
    en.lua fr.lua es.lua de.lua it.lua pt.lua nl.lua pl.lua tr.lua ar.lua
                          Serveur   copiés du template (clés communes intactes) + clés §9 sous "-- Textes propres au script :"
  server/
    crew.lua              Serveur   résolution du crew (§1)
    main.lua              Serveur   état, influence, tick, SQL, callback, exports, écoute pop_crew
    commands.lua          Serveur   /territoryadmin
  client/
    blips.lua             Client    blips de zone + blip d'alerte rivale (chargé avant main.lua, ordre alphabétique)
    main.lua              Client    état local, détection de zone, HUD, /territory, alertes, export
  web/
    index.html            NUI       repart de templates/pop_base/web/index.html, #app remplacé (§5)
    style.css             NUI
    script.js             NUI
    kit/pop.css           NUI       COPIE À L'IDENTIQUE de templates/pop_base/web/kit/pop.css
    kit/pop.js            NUI       COPIE À L'IDENTIQUE de templates/pop_base/web/kit/pop.js
  sql/
    install.sql           Serveur
```

Copie : « copie à l'identique » = lire le fichier du template et l'écrire tel quel, sans aucune modification.
`client/main.lua`, `server/main.lua` et `web/script.js` du template sont remplacés, pas conservés.

### fxmanifest.lua (Serveur)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_territories'
author 'POP'
version '1.0.0'
description 'POP Territories : crew turf wars'

dependency 'oxmysql'

shared_scripts {
    'config.lua',
    'shared/*.lua',      -- callback.lua, locale.lua, zones.lua
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/*.lua',      -- commands.lua, crew.lua, main.lua (les fonctions sont appelées à l'exécution, pas au chargement)
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
Note ordre serveur : `commands.lua` est chargé avant `main.lua` ; il ne doit appeler les fonctions de `main.lua` (table globale `Territories`, voir §10) qu'à l'intérieur du handler de commande.

### 2.1 API de `shared/zones.lua` (écrit par Serveur, utilisé par Client)
Table globale `Zones`. Construite une fois au chargement à partir de `Config.Zones` ; aucune boucle.

| Membre | Retour | Rôle |
|---|---|---|
| `Zones.List` | tableau | zones valides normalisées, dans l'ordre de la config |
| `Zones.Get(id)` | zone \| nil | par id |
| `Zones.At(coords)` | zone \| nil | première zone (ordre config) contenant `coords` (vector3 ou `{x,y}`), test 2D (x, y) |
| `Zones.Contains(zone, coords)` | bool | test d'une zone précise |

Zone normalisée : `{ id, label, price, center = vector3, radius = number, points = { vector2, ... } | nil, min = vector2, max = vector2 }`
- Cercle (`center` + `radius` en config) : boîte englobante puis distance 2D ≤ radius.
- Polygone (`points`, ≥ 3 `vec2`) : boîte englobante (`min`/`max`) puis ray casting. `center` = moyenne des points (z = 0.0), `radius` = distance max centre→point (sert aux blips).
- Validation : `id` = chaîne `^[%w_]+$` de 1 à 32 caractères, unique ; sinon la zone est ignorée avec un `print` (`[pop_territories] invalid zone #n`). `price` : nombre entre 0.1 et 10, défaut 1.0 (valeur fournie mais invalide → 1.0 avec un `print`). `label` : chaîne, défaut = `id`.
- Le nom affiché d'une zone est toujours `L(zone.label)` : si la clé existe dans les locales elle est traduite, sinon le texte brut est affiché (comportement natif de `L`).

---

## 3. Events

### 3.1 Client → serveur
**Aucun event.** Le client ne fait que lire (callback §4). Toute l'influence est calculée côté serveur.

### 3.2 Serveur → client (`RegisterNetEvent` côté client, `TriggerClientEvent` côté serveur)

| Event | Cible | Paramètres | Rôle |
|---|---|---|---|
| `pop_territories:client:state` | un joueur | `state` (format §4) | état complet, envoyé quand le crew du joueur change (`pop_crew:changed` ou détection au tick) |
| `pop_territories:client:owner` | `-1` (tous) | `zoneId` (string), `owner` (crew \| nil) | changement de propriétaire, ou label/couleur du propriétaire modifiés |
| `pop_territories:client:influence` | membres connectés du crew | `zoneId` (string), `value` (entier 0-100) | influence de son crew dans la zone ; envoyé seulement si la valeur arrondie a changé |
| `pop_territories:client:alert` | membres connectés du crew propriétaire | `zoneId` (string), `coords` (vector3 décalé au hasard de ±50 m sur x et y) | vente rivale dans leur zone |

### 3.3 Events serveur locaux (`TriggerEvent` / `AddEventHandler`, **jamais `RegisterNetEvent`**)

Émis par pop_territories :

| Event | Paramètres | Quand |
|---|---|---|
| `pop_territories:ownerChanged` | `zoneId`, `newOwner` (crew \| nil), `oldOwner` (crew \| nil) | après chaque changement de propriétaire |

Écoutés par pop_territories (`server/main.lua`), émis par pop_crew :

| Event | Paramètres | Réaction |
|---|---|---|
| `pop_crew:changed` | `src` (number), `crewId` (number \| nil) | `crewOf[src]` = `'crew:' .. crewId` ou `false` ; si différent de l'ancien cache → `TriggerClientEvent('pop_territories:client:state', src, BuildState(src))`. |
| `pop_crew:disbanded` | `crewId` (number) | clé `'crew:' .. crewId` : suppression de son influence dans toutes les zones (mémoire + `DELETE` SQL des lignes `pop_territories` et `pop_territories_crews` de cette clé) ; pour chaque zone dont il était propriétaire : `owners[zone] = nil`, diffusion `pop_territories:client:owner` (nil), `TriggerEvent('pop_territories:ownerChanged', zone, nil, ancien)`. Pas de notification `notify_lost` (le crew n'existe plus). Puis `UpdateOwner` des zones touchées (un autre crew ≥ `Capture` peut récupérer la zone). |

Pour ces deux handlers : ignorer l'appel si `GetInvokingResource() ~= 'pop_crew'` ; valider les types (`src` joueur connecté, `crewId` entier ou nil ; entiers lus via `math.tointeger(tonumber(x))`, ce qui accepte `12.0`). Le DELETE de dissolution passe par la file SQL (§7).

Les events `pop_territories:playerLoaded` / `playerDropped` et `pop_territories:bridge:notify` sont ceux du bridge (ne pas les redéfinir).

---

## 4. Callbacks (`shared/callback.lua`)

| Nom | Sens | Paramètres | Retour |
|---|---|---|---|
| `pop_territories:getState` | client → serveur | aucun | `state` |

Côté client : appelé dans `Bridge.OnPlayerLoaded` (`Callback.Await`). Côté serveur : met aussi à jour `crewOf[source]`.

Format `state` :
```lua
{
  enabled = true,                 -- false si Crew.Mode() == 'disabled'
  capture = 60,                   -- Config.Influence.Capture (marqueur de la barre HUD)
  crew    = { key = 'crew:12', label = 'Vice Kings', color = '#ff2e88' } | nil,
  zones   = {
    ['grove'] = { owner = { key, label, color } | nil, influence = 42 }, -- influence du crew du joueur, entier 0-100 (0 sans crew)
    ...                            -- une entrée pour chaque zone de Zones.List
  },
}
```

---

## 5. NUI

HUD uniquement : **jamais de `SetNuiFocus`**, aucun callback NUI propre au script.
Callbacks NUI existants (fournis par le bridge, ne pas redéclarer) : `pop:ready`, `close`.

### Lua → JS (`SendNUIMessage`)

| action | Données | Rôle |
|---|---|---|
| `territory:hud` | `{ show: true, zone, owner, color, mine, influence, capture }` | affiche / met à jour le panneau |
| `territory:hud` | `{ show: false }` | masque le panneau (fondu 150 ms) |

```json
{
  "action": "territory:hud",
  "show": true,
  "zone": "Grove Street",
  "owner": "Vice Kings",
  "color": "#ff2e88",
  "mine": false,
  "influence": 42,
  "capture": 60
}
```
- `zone` : nom déjà traduit (`L(zone.label)`).
- Un champ `null` peut aussi être **absent** (Lua `SendNUIMessage` omet les `nil`) : le JS traite `undefined` comme `null`.
- `owner` : label du crew propriétaire, ou `null` si zone libre. **Donnée joueur : insérer avec `textContent` uniquement.**
- `color` : `'#rrggbb'` ou `null`. Le JS n'applique la couleur que si elle respecte `/^#[0-9a-f]{6}$/i`.
- `mine` : `true` si le joueur est du crew propriétaire.
- `influence` : entier 0-100 (arrondi **inférieur** : 59.9 affiche 59 %), ou `null` si le joueur n'a pas de crew ou si `enabled == false` (bloc influence masqué).
- `capture` : entier, position du marqueur sur la barre (en %).

### Contenu de `#app` (NUI)
```html
<div id="app" class="pop-panel pop-fade territory">
  <div class="territory-zone"></div>
  <div class="territory-owner pop-small"><span class="territory-dot"></span><span class="territory-owner-name"></span></div>
  <div class="territory-influence">
    <div class="territory-row pop-small"><span data-locale="hud_influence"></span><span class="territory-pct"></span></div>
    <div class="territory-track"><div class="territory-fill"></div><div class="territory-mark"></div></div>
  </div>
</div>
```
Règles d'affichage :
- Ligne propriétaire : `owner == null` → `Pop.t('hud_unclaimed')`, point masqué ; `mine` → `Pop.t('hud_your_turf')` + point de la couleur du crew ; sinon `owner` + point coloré.
- `.territory-influence` masqué (`pop-hidden`) si `influence === null`.
- `.territory-pct` = `influence + '%'`. `.territory-fill` : largeur = influence %, couleur `var(--pop-accent)`, **sans transition** (seule animation autorisée : le fondu d'opacité du kit). `.territory-mark` : trait fin à `capture` % (`inset-inline-start` pour le RTL).
- Position : fixe, côté droit, `top: 22vh`, `right: 24px`, largeur ~ 220 px, texte qui passe à la ligne (allemand) sans débordement. En RTL (`[dir="rtl"]`) : côté gauche.
- Deux tailles de texte (celles du kit), fond `var(--pop-bg)`, pas d'ombre, pas d'icône.
- `Pop.show(app, data.show)` pour afficher / masquer. Masqué au chargement.

---

## 6. Exports publics

### Serveur : `exports.pop_territories:RecordDrugSale(src, coords, amount)` → `finalAmount, info`
Appelé par pop_dealing **avant** de payer le joueur ; pop_dealing paie `finalAmount`.
- `src` : source du vendeur ; `coords` : position de la vente (vector3, optionnel) ; `amount` : montant de base calculé par pop_dealing.
- `finalAmount` : entier ≥ 0 = `math.floor(amount * info.mult + 0.5)`.
- `info` :
  ```lua
  {
    zone  = 'grove' | nil,                       -- nil hors zone
    owner = { key, label, color } | nil,         -- propriétaire de la zone (avant la vente)
    mult  = 1.25,                                -- multiplicateur appliqué (arrondi à 2 décimales)
    rival = false,                               -- true : zone tenue par un autre crew que celui du vendeur
  }
  ```
Déroulé serveur :
1. `amount` : `tonumber`, fini, `0 ≤ amount ≤ 1e9`, sinon retourne `0, { mult = 1.0, rival = false }`. `src` doit être un joueur connecté (`GetPlayerName(src)`), sinon `math.floor(amount + 0.5), { mult = 1.0, rival = false }`.
2. Position : `Bridge.GetCoords(src)`. Si `coords` est fourni et à plus de 30 m de la position serveur → `coords` ignoré. Si la position serveur est introuvable → `coords` utilisé.
3. `zone = Zones.At(pos)`. Hors zone → `math.floor(amount + 0.5), { mult = 1.0, rival = false }`.
4. `crew = Crew.Get(src)` (frais, met à jour `crewOf[src]`). `owner` = propriétaire actuel.
5. `mult = zone.price` ; × `Config.Prices.Owner` si `owner and crew and owner.key == crew.key` ; × `Config.Prices.Rival` si `owner` et vendeur pas du crew propriétaire (`rival = true`).
6. Influence (si `crew`, `amount > 0`, mode ≠ `'disabled'` et `lastSale[src]` plus ancien que `Config.Influence.SaleCooldown`) : `AddInfluence(zone.id, crew, Config.Influence.PerSale)` puis `UpdateOwner(zone.id)` (§10). `lastSale[src] = os.time()`.
7. Si `rival` : alerte au crew propriétaire (cooldown par zone `Config.RivalAlertCooldown`, 0 = jamais) — `TriggerClientEvent('pop_territories:client:alert', memberSrc, zone.id, approxCoords)` pour chaque membre connecté du propriétaire.
8. Retour. Le multiplicateur est calculé avec le propriétaire **avant** la vente (la vente qui fait prendre la zone n'a pas encore le bonus).

### Serveur : `exports.pop_territories:GetZoneAt(coords)` → `zoneId | nil, label`
`label` = `L(zone.label)` (langue du serveur). `coords` : vector3 ou `{ x, y, z }` ; entrée invalide → nil.

### Serveur : `exports.pop_territories:GetZoneOwner(zoneId)` → `{ key, label, color } | nil`
Copie de la table (jamais la référence interne).

### Client : `exports.pop_territories:GetCurrentZone()` → `zoneId | nil`
Zone où se trouve le joueur selon la dernière détection (affichage seulement ; le serveur recalcule toujours).

---

## 7. Schéma SQL (`sql/install.sql`, Serveur)

Le serveur exécute aussi ces `CREATE TABLE IF NOT EXISTS` au démarrage (avant de charger) : l'import manuel est facultatif.

```sql
CREATE TABLE IF NOT EXISTS `pop_territories` (
    `zone`       VARCHAR(32) NOT NULL,
    `crew`       VARCHAR(64) NOT NULL,              -- clé : 'crew:<id>' ou 'job:<name>'
    `influence`  FLOAT       NOT NULL DEFAULT 0,    -- 0 à 100
    `owner`      TINYINT(1)  NOT NULL DEFAULT 0,    -- 1 = propriétaire de la zone (au plus une ligne par zone)
    `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`zone`, `crew`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `pop_territories_crews` (
    `crew`       VARCHAR(64) NOT NULL,              -- même clé
    `label`      VARCHAR(32) NOT NULL,
    `color`      CHAR(7)     NOT NULL DEFAULT '#ffffff',
    `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`crew`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
- Chargement au démarrage (`MySQL.query.await` dans un thread, flag `loaded`) : tout en mémoire ; les lignes de zones absentes de la config sont ignorées (pas supprimées). Avant `loaded`, `RecordDrugSale` applique les prix sans toucher à l'influence et `getState` renvoie un état sans propriétaires.
- **File SQL unique** : toutes les écritures (upserts différés, upserts de `pop_territories_crews`, `DELETE` de Reset et de dissolution) sont ajoutées à une file dépilée par **une seule coroutine** (`MySQL.transaction.await`), dans l'ordre mémoire : un upsert ancien ne peut jamais passer après un `DELETE`.
- Écritures : mémoire immédiatement, puis **écriture différée** : les couples (zone, crew) modifiés sont marqués « sales » et enregistrés à chaque tick (60 s) par `INSERT ... ON DUPLICATE KEY UPDATE influence = VALUES(influence), owner = VALUES(owner)`. Changement de propriétaire, commande admin et crew dissous : écriture immédiate. Influence tombée à 0 et non propriétaire → `DELETE` de la ligne. Si la transaction échoue, les couples envoyés redeviennent « sales » (ceux remarqués entre-temps le sont déjà) et sont réécrits au flush suivant ; idem pour les crews.
- `pop_territories_crews` : upsert quand un crew est vu (tick, vente, getState, `pop_crew:changed`) **et** que son label ou sa couleur a changé. Sert à afficher le propriétaire quand aucun membre n'est connecté.
- Requêtes paramétrées (`?`) uniquement.

---

## 8. `config.lua` (Serveur)

Clés communes du template **inchangées** (Locale, Debug, Framework, Inventory, Target, Notify, AccentColor, Keys, CallbackRateLimit), puis :

```lua
------------------------------------------------------------------------
-- pop_territories
------------------------------------------------------------------------

-- Appartenance : pop_crew est utilisé s'il est lancé. Sinon, les jobs listés ci-dessous servent de crews.
Config.UseJobsAsCrews = true
Config.JobCrews = {        -- nom du job = couleur du crew
    ballas   = '#8b5cf6',
    families = '#22c55e',
    vagos    = '#facc15',
}

-- Influence (0 à 100 par crew et par zone ; le total d'une zone ne dépasse jamais 100).
Config.Influence = {
    PerSale      = 2.0,  -- gagnée par vente dans la zone
    PerTick      = 0.5,  -- gagnée par minute de présence d'un membre (ne fait pas prendre la zone)
    Decay        = 0.1,  -- perdue par minute sans membre présent
    Capture      = 60,   -- influence pour prendre la zone
    Keep         = 30,   -- le propriétaire garde la zone tant qu'il reste au-dessus
    SaleCooldown = 10,   -- secondes minimum entre deux ventes comptées pour un même joueur
}

-- Multiplicateurs de prix, appliqués après le prix de la zone.
Config.Prices = {
    Owner = 1.25, -- vendeur du crew propriétaire
    Rival = 0.85, -- zone tenue par un autre crew
}

-- Secondes entre deux alertes "vente rivale" par zone (0 = désactivé).
Config.RivalAlertCooldown = 120

-- Zones colorées sur la carte selon le propriétaire.
Config.ZoneBlips = true

-- Durée d'affichage du HUD en entrant dans une zone, en secondes (0 = tant qu'on y est).
Config.HudDuration = 8

Config.Commands = {
    Info  = 'territory',      -- réaffiche le HUD de la zone actuelle
    Admin = 'territoryadmin', -- info | reset | set (admin)
}

-- Territoires. Cercle : center + radius. Polygone : points (au moins 3 vec2).
-- label : clé de traduction (ou texte brut). price : multiplicateur de prix de la zone (défaut 1.0, 0.1-10).
-- price se CUMULE avec le "mult" de la zone de vente pop_dealing (déjà 1.2 à Vespucci) puis Prices.Owner/Rival.
-- Les zones de vente de pop_dealing doivent recouvrir les territoires : sans vente possible, une zone est imprenable.
Config.Zones = {
    { id = 'grove',    label = 'zone_grove',    center = vec3(105.0, -1940.0, 20.8),  radius = 130.0 },
    { id = 'forum',    label = 'zone_forum',    center = vec3(-165.0, -1620.0, 33.0), radius = 110.0 },
    { id = 'vespucci', label = 'zone_vespucci', price = 1.0, points = {
        vec2(-1450.0, -1380.0), vec2(-1250.0, -1250.0), vec2(-1150.0, -1450.0), vec2(-1350.0, -1600.0),
    } },
    { id = 'sandy',    label = 'zone_sandy',    center = vec3(1850.0, 3700.0, 33.0),  radius = 250.0 },
}
```
Validation au démarrage (serveur, `print` si corrigé) : `Keep < Capture`, `Capture` entre 51 et 100 (au-dessus de 50 pour qu'un seul crew puisse l'atteindre), valeurs d'influence ≥ 0, prix > 0.
Constantes (dans le code, pas en config) : tick serveur 60 s ; détection de zone client 1000 ms ; alerte rivale ±50 m, blip 80 m pendant 60 s ; alpha des blips de zone 90.

---

## 9. Locales (Serveur écrit les 10 fichiers)

À ajouter sous `-- Textes propres au script :` dans `en.lua` (référence) et traduire dans fr, es, de, it, pt, nl, pl, tr, ar (`ar.lua` garde `_rtl = true` du template). Les `%s` restent dans le même ordre. Les noms de lieux GTA (Grove Street, Sandy Shores...) restent tels quels si aucune traduction n'est d'usage.

| Clé | en | fr |
|---|---|---|
| `zone_grove` | Grove Street | Grove Street |
| `zone_forum` | Forum Drive | Forum Drive |
| `zone_vespucci` | Vespucci Beach | Plage de Vespucci |
| `zone_sandy` | Sandy Shores | Sandy Shores |
| `hud_unclaimed` | Unclaimed | Libre |
| `hud_your_turf` | Your turf | Votre territoire |
| `hud_influence` | Your crew influence | Influence de votre crew |
| `crew_unknown` | Unknown crew | Crew inconnu |
| `notify_captured` | Your crew took control of %s | Votre crew contrôle maintenant %s |
| `notify_lost` | Your crew lost control of %s | Votre crew a perdu %s |
| `notify_rival` | Rival dealing spotted in %s | Deal rival repéré à %s |
| `notify_no_zone` | You are not in a territory | Vous n'êtes dans aucun territoire |
| `cmd_territory` | Show the current territory | Afficher le territoire actuel |
| `cmd_admin` | Manage territories (admin) | Gérer les territoires (admin) |
| `admin_usage` | Usage: /%s info [zone] \| reset <zone\|all> \| set <zone> <crew> <0-100> | Utilisation : /%s info [zone] \| reset <zone\|all> \| set <zone> <crew> <0-100> |
| `admin_unknown_zone` | Unknown zone: %s | Zone inconnue : %s |
| `admin_bad_value` | Invalid value | Valeur invalide |
| `admin_info` | %s, owner: %s, %s | %s, propriétaire : %s, %s |
| `admin_reset` | Territory reset: %s | Territoire réinitialisé : %s |
| `admin_reset_all` | All territories reset | Tous les territoires ont été réinitialisés |
| `admin_set` | Influence of %s in %s set to %s | Influence de %s à %s fixée à %s |
| `crews_disabled` | No crew system (pop_crew or Config.UseJobsAsCrews): influence is disabled | Aucun système de crew (pop_crew ou Config.UseJobsAsCrews) : l'influence est désactivée |

Clés communes du kit utilisées : `no_permission`, `error`.
Interface : seules `hud_unclaimed`, `hud_your_turf`, `hud_influence` sont lues par le JS (via `Pop.t` / `data-locale`).

---

## 10. Logique serveur détaillée (Serveur)

`server/main.lua` expose une table globale `Territories` (utilisée par `commands.lua`) : `Territories.AddInfluence`, `Territories.SetInfluence`, `Territories.UpdateOwner`, `Territories.Reset(zoneId)`, `Territories.GetZoneInfluence(zoneId)` → liste `{ key, label, value }` triée décroissante, `Territories.GetOwner(zoneId)`.

État mémoire :
- `influence[zoneId][crewKey] = number` ; `owners[zoneId] = crewKey | nil` ; `crews[crewKey] = { key, label, color }` (chargé depuis `pop_territories_crews`, mis à jour quand un crew est vu).
- `crewOf[src] = crewKey | false` (cache, rafraîchi par `pop_crew:changed`, au tick, à la vente et dans `getState` ; vidé dans `Bridge.OnPlayerDropped`, avec `lastSale[src]`).
- `lastSent[crewKey][zoneId] = entier` (dernière influence arrondie envoyée), `lastAlert[zoneId] = os.time()`.

`AddInfluence(zoneId, crew, amount, maxValue)` :
1. `v = min(maxValue or 100, current + amount)`, sans jamais descendre sous la valeur actuelle à cause de `maxValue`.
2. Somme des autres crews `S`. Si `v + S > 100` : retirer le dépassement aux autres **proportionnellement** à leur influence.
3. Valeurs < 0.01 → supprimées. Marquer « sales ». Enregistrer `crews[crew.key]` si nouveau ou modifié.

`SetInfluence(zoneId, crewKey, value)` (admin) : même logique avec une valeur fixée (0-100), réduction proportionnelle des autres si la somme dépasse 100.

`UpdateOwner(zoneId)` (après chaque modification) :
1. Si propriétaire et `influence < Keep` → plus de propriétaire.
2. Si un crew (≠ propriétaire) a `influence ≥ Capture` → il devient propriétaire.
3. Si changement : écriture SQL immédiate, `TriggerClientEvent('pop_territories:client:owner', -1, zoneId, ownerCrew)`, `Bridge.Notify` `notify_captured` (success) aux membres connectés du nouveau, `notify_lost` (error) à ceux de l'ancien (texte : `L(key, L(zone.label))`), puis `TriggerEvent('pop_territories:ownerChanged', zoneId, new, old)`.
4. Puis envoi `pop_territories:client:influence` aux membres connectés des crews dont la valeur arrondie a changé.

Tick (60 s, un seul thread `Wait(60000)`, ne fait rien s'il n'y a aucun joueur) :
1. Pour chaque joueur de `Bridge.GetPlayers()` : `Crew.Get(src)` → `crewOf` ; si la clé a changé depuis le cache → `TriggerClientEvent('pop_territories:client:state', src, BuildState(src))` (couvre le mode jobs et un éventuel event manqué).
2. Si le crew est connu et le joueur vivant (`not (Bridge.IsDead and Bridge.IsDead(src) or GetEntityHealth(ped) <= 0)`) : `Zones.At(Bridge.GetCoords(src))` → `present[zoneId][crewKey] = true`.
3. Mode `'disabled'` : s'arrêter là.
4. Pour chaque zone : chaque crew présent → `AddInfluence(zone, crew, PerTick, crew == owner and 100 or Capture - 0.01)` ; chaque crew ayant de l'influence et absent → `-Decay` (min 0). Puis `UpdateOwner`.
5. Si le label ou la couleur d'un propriétaire a changé, ou si un crew propriétaire jusque-là inconnu (« Crew inconnu ») est vu → re-diffuser `pop_territories:client:owner` (fait dans `seeCrew`).
6. Écrire les lignes « sales » en base (et les crews en attente après un échec).

`onResourceStop` (serveur) : écrire les lignes sales et les crews (au mieux, via la file).

`server/commands.lua` — `RegisterCommand(Config.Commands.Admin, fn, false)` :
- Autorisé si `src == 0` (console) ou `Bridge.IsAdmin(src)` ; sinon `Bridge.Notify(src, L('no_permission'), 'error')`.
- Réponse : `Bridge.Notify` au joueur, `print` en console.
- `info [zone]` : zone = argument, ou zone à la position de l'admin (console : argument obligatoire). Message `admin_info` : nom, propriétaire (label ou `hud_unclaimed`), liste `label 45%` des crews triés (5 max, séparés par `, `).
- `reset <zone|all>` : vide l'influence et le propriétaire de la ou des zones, `DELETE` SQL (via la file), diffusion `owner = nil`, event `ownerChanged`, `admin_reset` (zone) ou `admin_reset_all` (all).
- `set <zone> <crewKey> <0-100>` : `crewKey` doit respecter `^crew:%d+$` ou `^job:[%w_%-]+$` (≤ 64) ; `SetInfluence` puis `UpdateOwner`, `admin_set`. Label inconnu → la clé brute.
- Argument manquant / invalide → `admin_usage` (avec le nom de la commande), `admin_unknown_zone` ou `admin_bad_value`.

---

## 11. Logique client (Client)

`client/blips.lua` (table globale `Blips`, chargée avant `main.lua`) :
- `Blips.Refresh(state)` : supprime puis recrée ; si `Config.ZoneBlips`, un `AddBlipForRadius(zone.center, zone.radius)` par zone, alpha 90, couleur = propriétaire ou neutre. Polygones : cercle approché (centre/rayon de `Zones`).
- `Blips.SetOwner(zoneId, owner)` : `SetBlipColour` seulement.
- Couleur : la couleur hex du crew est convertie vers la couleur de blip GTA la plus proche (distance RVB) dans cette palette fixe :
  `0 #fefefe, 1 #e03232, 2 #72cc72, 3 #5db6e5, 5 #eec64e, 7 #9a6ac9, 8 #f28ec0, 17 #f0a35a, 25 #3a8a3a, 38 #2c6db8, 48 #e8358c` (48 = rose vif, pour l'accent `#ff2e88`) ; zone libre : `40` (gris foncé).
- `Blips.Alert(coords)` : `AddBlipForRadius(coords, 80.0)`, couleur 49 (hors palette des crews, pour ne pas être confondue avec une zone), alpha 120, retiré après 60 s (`SetTimeout`). Pas de blip à sprite.
- `onResourceStop` : `RemoveBlip` de tous les blips créés.

`client/main.lua` :
- `Bridge.OnPlayerLoaded` → `state = Callback.Await('pop_territories:getState')` (si nil, réessayer une fois après 5 s), puis `Blips.Refresh(state)`.
- Events §3.2 :
  - `client:state` → remplace `state`, `Blips.Refresh(state)`, réaffiche le HUD si dans une zone.
  - `client:owner` → `state.zones[zoneId].owner`, `Blips.SetOwner`, réaffiche le HUD si le joueur est dans cette zone.
  - `client:influence` → `state.zones[zoneId].influence` ; si le joueur est dans cette zone, met à jour le HUD **seulement s'il est déjà visible** ou si la valeur franchit `capture` (dans un sens ou l'autre).
  - `client:alert` → `Bridge.Notify(L('notify_rival', L(zone.label)), 'warning')` + `Blips.Alert(coords)`.
  - Toujours vérifier `Zones.Get(zoneId)` avant usage (zone inconnue → ignorer).
- Détection : un seul thread, `Wait(1000)`, `Zones.At(GetEntityCoords(PlayerPedId()))`. Entrée → HUD affiché ; sortie → `{ show = false }` immédiatement. Pas de `Wait(0)`.
- Masquage après `Config.HudDuration` secondes (si > 0) via un jeton (`SetTimeout`) : un nouvel affichage annule le précédent.
- `RegisterCommand(Config.Commands.Info, fn, false)` : dans une zone → HUD ; sinon `Bridge.Notify(L('notify_no_zone'), 'info')`.
  Suggestions chat (si `GetResourceState('chat') == 'started'`) : `TriggerEvent('chat:addSuggestion', '/' .. cmd, L('cmd_territory'))` et idem pour la commande admin avec `L('cmd_admin')`.
- `exports('GetCurrentZone', fn)`.
- `onResourceStop` : `SendNUIMessage({ action = 'territory:hud', show = false })`.

---

## 12. Règles de sécurité (vérifiées côté serveur, à contrôler par l'auditeur)

1. **Aucun event client → serveur** : le client ne peut ni ajouter d'influence, ni changer de propriétaire, ni choisir une zone ou un montant.
2. Zone toujours calculée par le serveur depuis la position serveur du ped (`Bridge.GetCoords`) ; `coords` de `RecordDrugSale` ignoré s'il est à plus de 30 m.
3. `RecordDrugSale` : `amount` validé (nombre fini, 0 à 1e9), `src` connecté, résultat entier ≥ 0. pop_territories ne donne jamais d'argent ni d'item.
4. Influence de vente limitée par joueur (`Config.Influence.SaleCooldown`) même si pop_dealing est mal configuré ou détourné.
5. Présence : seuls les joueurs chargés et vivants comptent ; elle ne permet pas de franchir `Capture` (seul le propriétaire peut monter au-dessus).
6. Crew relu côté serveur (pop_crew ou job) à chaque vente ; jamais transmis par le client.
7. `pop_crew:changed` / `pop_crew:disbanded` : `AddEventHandler` uniquement (jamais `RegisterNetEvent`), `GetInvokingResource() == 'pop_crew'` exigé, types validés. `pop_territories:ownerChanged` est émis par `TriggerEvent` uniquement.
8. Commande admin : `Bridge.IsAdmin(src)` ou console ; arguments validés (zone existante, clé de crew au bon format, valeur 0-100).
9. Callback `pop_territories:getState` : lecture seule, ne renvoie que l'influence du crew du joueur (pas celle des rivaux) ; protégé par `Config.CallbackRateLimit`.
10. SQL paramétré uniquement ; labels de crew tronqués à 32 caractères ; couleurs validées `#rrggbb`.
11. NUI : labels de crew affichés en `textContent`, couleur validée par regex avant usage.
12. Exports et appels à pop_crew protégés par `pcall` : une erreur de pop_crew ne casse pas pop_territories.

## 13. Performance

- Client : un seul thread à 1000 ms (détection de zone), aucun `Wait(0)` ; HUD piloté par events ; blips créés une fois.
- Serveur : un tick par minute ; écriture SQL groupée, différée et sérialisée (file unique) ; events d'influence envoyés seulement si la valeur arrondie change.
- Cible : 0.00-0.01 ms client au repos.

## 14. Vérification

`luacheck resources templates` à 0 erreur, `node --check web/script.js`. Démarrage testé : ESX, QBCore, Qbox, standalone ; avec et sans pop_crew ; sans pop_crew avec `Config.UseJobsAsCrews = false` (mode désactivé, aucune erreur) ; dissolution d'un crew propriétaire (zone libérée chez tous les clients).
