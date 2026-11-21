# pop_radio : SPEC (contrat commun Serveur / Client / NUI)

> Référence unique : noms repris **à l'identique**. API commune : `Bridge.*`, `Callback.*`, `L()`
> (voir `templates/pop_base/README.md`). Modèle lu (pas copié) : `tab_inventory/radio_client.lua`, `html/radio/`.

---

## 1. Description et fonctionnalités

Radio talkie-walkie en item, branchée sur **pma-voice**, avec une petite interface sobre.

- **Ouvrir** : utiliser l'item `Config.Item`, ou la touche `Config.OpenKey` (si le joueur possède l'item).
- **Interface** (en bas à droite) : fréquence actuelle (ou « OFF »), champ de saisie, boutons Connecter / Éteindre,
  volume − / +. Entrée = connecter, Échap = fermer.
- **Fréquences** : entiers de 1 à `Config.MaxFrequency`. Plages réservées par job (`Config.Reserved`), en service.
- **Le serveur décide** : il place le joueur sur le canal avec l'export serveur pma-voice `setPlayerRadio`, et pose
  un contrôle pma-voice (`addChannelCheck`) sur **chaque** canal : impossible de rejoindre un canal sans l'item (ou
  sans le job pour un canal réservé), même en appelant pma-voice directement.
- **Perte de l'item** : vérification toutes les `Config.CheckInterval` secondes des seuls joueurs connectés à une
  radio ; plus d'item → radio coupée.
- Dernière fréquence et volume gardés côté client (KVP) ; la fréquence est **proposée** à l'ouverture, pas rejointe
  automatiquement.
- Parler : touche radio de pma-voice (non gérée ici).

**Performance** : aucune boucle client ; une boucle serveur légère (`Config.CheckInterval`) sur les seuls joueurs en
radio. Animation + prop seulement quand l'interface est ouverte.

**Hors périmètre** : autres systèmes vocaux (SaltyChat, TokoVoip), fréquences décimales, liste des membres, sons de
clic, skins.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_radio/
  SPEC.md                 Architecte
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR
  README.md               SERVEUR   (pma-voice requis, item, plages réservées)
  bridge/server.lua       SERVEUR   copie STRICTE du template
  bridge/client.lua       CLIENT    copie STRICTE
  shared/callback.lua     SERVEUR   copie STRICTE
  shared/locale.lua       SERVEUR   copie STRICTE
  locales/*.lua (10)      SERVEUR   kit commun + section 9 (ar : _rtl = true)
  server/main.lua         SERVEUR
  client/main.lua         CLIENT
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

name 'pop_radio'
author 'POP'
version '1.0.0'
description 'POP Radio - item radio for pma-voice'

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua' }
client_scripts { 'bridge/client.lua', 'client/*.lua' }
server_scripts { 'bridge/server.lua', 'server/*.lua' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/**' }

escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
```
pma-voice n'est **pas** déclaré en `dependency` (le script démarre sans) ; il doit être `ensure` avant `[pop]`.

---

## 3. Données

- Serveur : `channels[src] = freq` (int) pour les joueurs connectés via le script.
- Client : `current` (0 = éteinte), `volume` (0-100, KVP `pop_radio:volume`, défaut 50), `last` (KVP
  `pop_radio:last`, 0 si absent), `uiOpen`.
- Fonction partagée côté serveur `reservedJobs(freq)` → liste de jobs ou nil (première plage de `Config.Reserved`
  qui contient `freq`).

---

## 4. Events

| Event | Sens | Paramètres | Destinataire | Rôle |
|---|---|---|---|---|
| `pop_radio:client:open` | S → C | aucun | le joueur | Item utilisé : ouvrir l'interface |
| `pop_radio:client:forceOff` | S → C | `reason` (clé de locale) | le joueur | Radio coupée par le serveur (item perdu, job perdu) |

Aucun event client → serveur.

---

## 5. Callbacks

Convention : `ok, reason, arg`. Échec → le client notifie `L(reason or 'error', arg)`. Succès → le serveur notifie.

| Nom | Paramètres | Retour |
|---|---|---|
| `pop_radio:canOpen` | aucun | `ok, reason, current` (`current` = canal serveur ou 0) |
| `pop_radio:join` | `freq` (int) | `ok, reason, arg` |
| `pop_radio:leave` | aucun | `ok` |

Raisons : `error`, `missing_item` (arg = `L('item_radio')`), `invalid_frequency` (arg = `Config.MaxFrequency`),
`reserved_frequency`, `voice_missing`.

---

## 6. Messages NUI

### Lua → JS
```json
{ "action": "pop_radio:open", "frequency": 0, "last": 12, "volume": 50, "max": 999 }
```
```json
{ "action": "pop_radio:state", "frequency": 12, "volume": 60 }
```
```json
{ "action": "pop_radio:close" }
```
`frequency` 0 = éteinte. `last` préremplit le champ (vide si 0).

### JS → Lua (`RegisterNUICallback`)
| Nom | Données | Réponse | Effet Lua |
|---|---|---|---|
| `pop_radio:join` | `{ "frequency": 12 }` | `{ "ok": true }` | `Callback.Await('pop_radio:join', freq)` ; si ok : `current`, KVP `last`, `pma-voice` `setVoiceProperty('radioEnabled', true)`, message `state` |
| `pop_radio:leave` | `{}` | `{ "ok": true }` | `Callback.Await('pop_radio:leave')`, `setVoiceProperty('radioEnabled', false)`, `current = 0`, `state` |
| `pop_radio:volume` | `{ "delta": 10 }` | `{ "volume": 60 }` | `delta` ∈ {-10, 10} sinon ignoré ; volume borné 0-100, `exports['pma-voice']:setRadioVolume(volume)`, KVP |
| `close` (kit) | `{}` | bridge | `Bridge.OnUiClose` → arrêt anim + prop, `uiOpen = false` |

Le Lua convertit `frequency` avec `math.tointeger(tonumber(...))` ; invalide → notification `invalid_frequency`.

### Interface (Dev NUI)
- `index.html` : base pop_base + `style.css`. `#app` → `#radio` (`pop-panel pop-fade`, masqué) :
  en-tête `data-locale="title"` ; `#radio-freq` (grand chiffre, couleur d'accent, ou `Pop.t('off')`) ;
  `<input id="radio-input" type="number" min="1">` (placeholder `Pop.t('frequency')`, `max` = `data.max`) ;
  boutons `data-locale="connect"`, `data-locale="turn_off"` ; ligne volume : `−` `#radio-vol` (`NN%`) `+`
  (libellé `data-locale="volume"`).
- `script.js` : `Pop.on('pop_radio:open' | 'pop_radio:state' | 'pop_radio:close')` ; Entrée dans le champ =
  connecter ; Échap → `Pop.post('close')` et masquer. Aucun texte en dur.
- `style.css` : panneau 220 px, `position: fixed; right: 24px; bottom: 12%`, fond `--pop-bg`, pas de dégradé.
  RTL : à gauche. Le style peut évoquer un écran LCD discret (chiffres en police monospace), sans image.

---

## 7. Exports publics

Client :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_radio:GetFrequency()` | int | canal actuel (0 = éteinte), pour un HUD |

Serveur :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_radio:GetFrequency(src)` | int | |
| `exports.pop_radio:TurnOff(src)` | bool | coupe la radio d'un joueur (menottes, mort…) |

---

## 8. config.lua

`config.lua` du template à l'identique, puis :

```lua
-- ─── pop_radio ───────────────────────────────────────────────

-- Item radio (à déclarer dans votre inventaire, voir README).
Config.Item = 'radio'

-- Touche par défaut pour ouvrir la radio ('' = aucune ; chaque joueur peut la choisir dans les raccourcis FiveM).
Config.OpenKey = ''

-- Fréquences disponibles : 1 à MaxFrequency (entiers).
Config.MaxFrequency = 999

-- Plages réservées (format Bridge.HasJob, en service).
Config.Reserved = {
    { min = 1,  max = 10, jobs = { 'police', 'sheriff' } },
    { min = 11, max = 20, jobs = { 'ambulance' } },
}

-- Secondes entre deux vérifications de l'item pour les joueurs en radio.
Config.CheckInterval = 15
```

---

## 9. Locales

10 fichiers (écrits par le Dev Serveur).

| Clé | en | fr |
|---|---|---|
| `title` | Radio | Radio |
| `item_radio` | Radio | Radio |
| `keymap_open` | Open the radio | Ouvrir la radio |
| `frequency` | Frequency | Fréquence |
| `connect` | Connect | Connecter |
| `turn_off` | Turn off | Éteindre |
| `off` | OFF | OFF |
| `volume` | Volume | Volume |
| `joined` | Connected to frequency %s | Connecté à la fréquence %s |
| `left` | Radio turned off | Radio éteinte |
| `invalid_frequency` | Choose a frequency between 1 and %s | Choisissez une fréquence entre 1 et %s |
| `reserved_frequency` | This frequency is reserved | Cette fréquence est réservée |
| `radio_lost` | You no longer have a radio | Vous n'avez plus de radio |
| `voice_missing` | Voice system unavailable | Système vocal indisponible |

Clés de base réutilisées : `missing_item`, `error`.

---

## 10. Schéma SQL

Aucun (préférences en KVP côté client).

---

## 11. Comportement client (`client/main.lua`)

- **Ouvrir** (`open` du serveur, ou commande `pop_radio_open` + `RegisterKeyMapping('pop_radio_open',
  L('keymap_open'), 'keyboard', Config.OpenKey)`) : ignoré si `uiOpen`, `IsNuiFocused()` (autre interface) ou
  `Bridge.IsBusy()`. Par l'item : si `uiOpen` sans focus (état orphelin) → `stopAnim()`, `uiOpen = false` ; puis
  attente jusqu'à 1 s que `IsNuiFocused()` soit faux (l'inventaire rend le focus). Par la touche : `Callback.Await('pop_radio:canOpen')` d'abord (échec → notification). Puis
  `SendNUIMessage(open)`, `SetNuiFocus(true, true)`, `uiOpen = true`.
- **Animation** (à pied seulement) : `cellphone@` / `cellphone_text_read_base`, flag 49 ; prop
  `prop_cs_hand_radio` créé **réseau** (`CreateObject(hash, x, y, z, true, false, false)`) attaché main gauche
  (os 60309, offset `0.09, 0.03, -0.02`, rotation `-80.0, 0.0, 0.0`) ; si la création échoue (verrouillage des
  entités du serveur), pas de prop. Supprimés à la fermeture.
- **Au chargement** : volume KVP appliqué (`setRadioVolume`).
- **`forceOff(reason)`** : `setVoiceProperty('radioEnabled', false)`, `current = 0`, message `state`, notification
  `L(reason)` (`error`).
- **Mort** : tant que `uiOpen`, vérification toutes les 500 ms ; joueur mort → fermeture (focus rendu, anim/prop).
- **Démarrage** : après 2 s, si `LocalPlayer.state.radioChannel > 0` (canal repris par le serveur) → `current`,
  `radioEnabled` true.
- **Arrêt** : focus rendu, `close`, prop/anim supprimés, `setVoiceProperty('radioEnabled', false)` si `current ~= 0`.
- Le client n'appelle **jamais** `setRadioChannel` lui-même : le canal est posé par le serveur.

---

## 12. Sécurité serveur (`server/main.lua`)

**Démarrage**
- `voice = GetResourceState('pma-voice') == 'started'` ; sinon avertissement console (anglais) et tous les
  callbacks répondent `voice_missing`.
- Pour `ch = 1, Config.MaxFrequency` : `exports['pma-voice']:addChannelCheck(ch, function(source) return
  canUse(source, ch) end)`.
- `canUse(src, freq)` = `Bridge.HasItem(src, Config.Item)` et (`reservedJobs(freq) == nil` ou
  (`Bridge.HasJob(src, jobs)` et `Bridge.GetJob(src).onDuty`)).

- Reprise : (après 1 s) pour chaque joueur, `Player(src).state.radioChannel` > 0 → remis dans `channels` s'il y a
  droit (`canUse`), sinon `setPlayerRadio(src, 0)`.
- Arrêt du script : `setPlayerRadio(src, 0)` pour tous les joueurs de `channels`.

**Item utilisable** `Config.Item` → `open` (aucun retrait).

**`pop_radio:canOpen`** : `Bridge.HasItem`, sinon `missing_item` ; renvoie `true, nil, channels[src] or 0`.

**`pop_radio:join(freq)`**
1. `math.type(freq) == 'integer'` et `1 ≤ freq ≤ Config.MaxFrequency`, sinon `invalid_frequency` (arg max).
2. `Bridge.HasItem(src, Config.Item)`, sinon `missing_item` + `L('item_radio')`.
3. Plage réservée : job et en service, sinon `reserved_frequency`.
4. `exports['pma-voice']:setPlayerRadio(src, freq)`, `channels[src] = freq`, notification `joined` (freq).

**`pop_radio:leave`** : `setPlayerRadio(src, 0)`, `channels[src] = nil`, notification `left`, `true`.

**Boucle** (toutes les `Config.CheckInterval` s, sur `channels` uniquement) : si `not canUse(src, freq)` →
`setPlayerRadio(src, 0)`, `channels[src] = nil`, `forceOff` avec `'radio_lost'` (item absent) ou
`'reserved_frequency'` (job ou service perdu).

**Nettoyage** : `channels[src] = nil` dans `Bridge.OnPlayerDropped` ; dans `Bridge.OnPlayerUnloaded` →
`setPlayerRadio(src, 0)` puis nil.

**Exports** : `TurnOff(src)` = même effet que la boucle avec `'left'` ; renvoie false si le joueur n'était pas en radio.

---

## 13. Limites (README)
- pma-voice obligatoire pour la voix (le script démarre sans, mais refuse toute connexion).
- Un autre script qui appelle `setPlayerRadio` côté serveur passe outre nos contrôles (export serveur de confiance).
- Fréquences entières uniquement (simplicité et contrôles pma-voice par canal).
- pma-voice garde un seul `addChannelCheck` par canal : un autre script qui en pose sur les mêmes canaux remplace
  le nôtre (ou l'inverse, selon l'ordre de démarrage).
- Prop radio réseau : invisible (pas créé) sur les serveurs qui verrouillent la création d'entités côté client.

## 14. Checklist auditeur
- Copies strictes ; 10 locales ; aucun texte en dur ; focus toujours rendu.
- `addChannelCheck` posé sur tous les canaux ; aucun `setRadioChannel` côté client.
- Aucune boucle client ; boucle serveur limitée aux joueurs en radio.
