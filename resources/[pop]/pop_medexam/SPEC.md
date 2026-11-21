# pop_medexam : SPEC (contrat commun Serveur / Client / NUI)

> Ce document est **la référence unique**. Les noms (fichiers, events, callbacks, clés de config, clés de locale,
> champs de données, messages NUI) doivent être repris **à l'identique**. En cas de doute : ce fichier fait foi.
> API commune à utiliser telle quelle : `Bridge.*`, `Callback.*`, `L()` (voir `templates/pop_base/README.md`).

---

## 1. Description et fonctionnalités

Visite médicale qui délivre un **certificat d'aptitude** (item avec métadonnées : nom, date, validité, médecin).
Utile pour d'autres scripts (permis, armes, pilote) via l'export `HasValidCertificate`.

**Deux façons de passer la visite** (`Config.Mode`)
- `'auto'` : borne / secrétaire de la clinique. Le joueur paie, puis enchaîne 3 étapes courtes :
  1. **Tension** : barre de progression avec animation (`Config.Durations.pressure`).
  2. **Vision** : mini-jeu de réflexe (curseur qui balaye une barre, appuyer sur `[E]` dans la zone).
  3. **Réflexes** : même mini-jeu, zone plus étroite.
  Les deux mini-jeux réussis → certificat. Un échec → « inapte », pas de certificat, délai avant de repasser.
- `'ems'` : un joueur EMS **en service** fait passer la visite au guichet. Il choisit le patient le plus proche ;
  le patient doit **accepter** (`[E] Accepter  [X] Refuser`) et paie ; l'EMS enchaîne les 3 étapes (barres de
  progression) ; le certificat est remis au patient, le prix va au médecin (compte `Config.Account`).
- `'mixed'` : comme `'ems'`, mais la borne automatique s'ouvre quand **aucun EMS n'est en service**.

**Certificat** : utiliser l'item affiche une petite carte (nom, délivré le, valide jusqu'au, médecin, valide/expiré)
au porteur **et** aux joueurs à ≤ 3 m pendant 8 s.

**Règles** : prix et validité en config ; délai entre deux visites par patient ; distance vérifiée ; tout est
validé par le serveur (session, temps minimal, argent, item).

**HUD** : sobre, côté droit, fondu 150 ms. Le mini-jeu prend le focus clavier seulement pendant ses ~3 s.

**Performance** : PNJ local par distance (boucle 1000/2500 ms). `Wait(0)` seulement pendant la demande de
consentement (15 s max) et dans `Bridge.Progress`. Serveur : aucune boucle.

**Hors périmètre** : suivi des blessures par zone, soins, dossiers médicaux en base.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_medexam/
  SPEC.md                 Architecte (ce fichier)
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR   (clés communes de pop_base + section 8)
  README.md               SERVEUR   (en ANGLAIS : installation, item par inventaire, modes, export)
  locales/en.lua … ar.lua SERVEUR   10 fichiers, ar : _rtl = true
  server/main.lua         SERVEUR
  client/main.lua         CLIENT    blip, PNJ, target, déroulé de l'examen, consentement, carte
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

name 'pop_medexam'
author 'POP'
version '1.0.0'
description 'POP Medical Exam - fitness certificate'

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
Pas d'oxmysql.

---

## 3. Données

### Métadonnées du certificat (item `Config.Item`)
```lua
{
    name        = 'John Doe',        -- Bridge.GetName(patient)
    issued      = 1773695584,        -- os.time() de délivrance
    expires     = 1776287584,        -- issued + Config.Validity * 86400, 0 = n'expire jamais
    doctor      = 'Jane Smith',      -- nom de l'EMS, ou L('auto_doctor') en mode auto
    description = 'John Doe - valid until 2026-04-15',  -- L('cert_description', name, date) : infobulle ox_inventory
}
```
Si `Bridge.SupportsMetadata()` est faux (ESX de base), l'item est remis **sans** métadonnées (avertissement console
au démarrage) : la carte n'est alors pas affichable et `HasValidCertificate` ne vérifie que la présence.

### `CertificateCard` (serveur → client)
```lua
{ name = 'John Doe', issued = '2026-03-16', expires = '2026-04-15' | nil, doctor = 'Jane Smith', valid = true }
```
Dates formatées **côté serveur** (`os.date('%Y-%m-%d', t)`). `expires = nil` si pas d'expiration.

---

## 4. Events

### Serveur → Client
| Event | Paramètres | Destinataire | Rôle |
|---|---|---|---|
| `pop_medexam:client:showCertificate` | `card` (CertificateCard) | porteur + joueurs à ≤ 3 m | Affiche la carte 8 s |
| `pop_medexam:client:sessionEnded` | `reason` (clé de locale) | médecin (mode EMS) | Le patient s'est déconnecté : le client annule la progression (`Bridge.CancelProgress()`) et notifie |

Aucun `RegisterNetEvent` serveur propre au script (tout passe par les callbacks).
Bridge : `Bridge.OnPlayerDropped` / `Bridge.OnPlayerUnloaded` → nettoie sessions et verrous (section 12).

---

## 5. Callbacks (`shared/callback.lua`)

Convention : `ok, reason, arg`. Échec → le client notifie `L(reason or 'error', arg)` en `error`. Succès → le serveur
notifie. `nil` = `error`.

### Client → serveur
| Nom | Paramètres | Retour | Qui |
|---|---|---|---|
| `pop_medexam:getState` | `loc` (int) | `autoOpen` (bool : la borne auto est utilisable maintenant), `isDoctor` (bool : EMS en service et mode ≠ auto) | tous |
| `pop_medexam:start` | `loc` (int) | `ok, reason, arg` | patient, mode auto (ou mixed sans EMS) |
| `pop_medexam:finish` | `passed` (bool) | `ok, reason, arg` | patient, mode auto |
| `pop_medexam:cancel` | aucun | `true` | patient, mode auto |
| `pop_medexam:emsStart` | `loc` (int) | `ok, reason, arg` (succès : `arg` = nom du patient) | EMS |
| `pop_medexam:emsFinish` | aucun | `ok, reason, arg` | EMS |
| `pop_medexam:emsCancel` | aucun | `true` | EMS |

### Serveur → client
| Nom | Paramètres | Retour |
|---|---|---|
| `pop_medexam:consent` | `price` (int), `doctor` (string) | `accepted` (bool) ; le client répond `false` au bout de 15 s |

Raisons possibles : `error`, `busy`, `too_far`, `wrong_job`, `not_enough_money`, `inventory_full`, `cooldown` (arg =
secondes), `exam_closed`, `no_patient`, `patient_refused`, `patient_gone`, `no_session`, `exam_too_fast`.

---

## 6. Messages NUI

### Lua → JS
**`pop_medexam:skill`** : mini-jeu. Le client appelle `SetNuiFocus(true, false)` juste avant (clavier seul).
```json
{ "action": "pop_medexam:skill", "show": true, "label": "step_vision", "key": "E", "zone": 0.18 }
```
```json
{ "action": "pop_medexam:skill", "show": false }
```
`label` : clé de locale (`step_vision` | `step_reflex`). `zone` : largeur de la zone (0-1) : vision `0.18`,
réflexes `0.12`. `key` = `Config.Keys.Interact.label`.

**`pop_medexam:consent`** : demande au patient (pas de focus ; touches lues côté Lua).
```json
{ "action": "pop_medexam:consent", "show": true, "doctor": "Jane Smith", "price": 250,
  "acceptKey": "E", "refuseKey": "X" }
```
```json
{ "action": "pop_medexam:consent", "show": false }
```

**`pop_medexam:certificate`** : carte (pas de focus).
```json
{ "action": "pop_medexam:certificate", "show": true, "name": "John Doe", "issued": "2026-03-16",
  "expires": "2026-04-15", "doctor": "Jane Smith", "valid": true }
```
```json
{ "action": "pop_medexam:certificate", "show": false }
```

### JS → Lua
| Nom | Données | Réponse |
|---|---|---|
| `pop_medexam:skillResult` | `{ "success": true }` | `"ok"` |
| `close` | (kit, Échap) | bridge → `Bridge.OnUiClose` : si un mini-jeu est en cours, compte comme **échec** |

### Mini-jeu (Dev NUI, logique entièrement JS)
- Barre de 240 px, hauteur 6 px. Zone (accent) de largeur `zone`, position de départ aléatoire dans
  `[0.35, 0.95 - zone]`. Curseur blanc 2 px qui fait un aller-retour complet en **1400 ms** (`requestAnimationFrame`).
- Un seul appui sur `key` (comparaison `event.key.toUpperCase()`) : succès si le curseur est dans la zone.
  Sans appui en **4000 ms** → échec. Résultat : zone en accent (succès) ou `--pop-danger` (échec) 300 ms, puis
  `Pop.post('pop_medexam:skillResult', { success })`. Les appuis suivants sont ignorés.
- Texte : `Pop.t(label)` au-dessus, `[E] Pop.t('skill_hint')` en dessous.

### Interface (Dev NUI)
- `web/index.html` : `style.css` après `kit/pop.css`. Trois blocs `pop-panel pop-fade` masqués par défaut :
  `#med-skill`, `#med-consent`, `#med-card`.
- `#med-consent` : `Pop.t('consent_text', doctor, Pop.t('money', price))` ; `[E] Pop.t('accept')  [X] Pop.t('refuse')`
  (`pop-key`).
- `#med-card` (260 px) : titre `data-locale="card_title"`, lignes `card_name`, `card_issued`, `card_expires`
  (ou `card_no_expiry` si `expires` vaut null), `card_doctor` ; statut `card_valid` (accent) ou `card_expired`
  (`--pop-danger`).
- `web/style.css` : tous les blocs `position: fixed; right: 24px;` : `#med-card` en `top: 28%`, `#med-skill` et
  `#med-consent` en `bottom: 14%`. RTL : `right: auto; left: 24px`. Pas de dégradé, pas d'image.

---

## 7. Exports publics

Serveur :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_medexam:HasValidCertificate(src)` | bool | une pile de `Config.Item` avec `expires == 0` ou `expires > os.time()` (`Bridge.GetItems`) ; sans métadonnées : présence de l'item |
| `exports.pop_medexam:GiveCertificate(src, doctorName?)` | bool | remet un certificat (métadonnées complètes), sans paiement ni contrôle de lieu |

Client : aucun.

---

## 8. config.lua (contenu exact)

Reprend **à l'identique** le `config.lua` de `templates/pop_base`, puis ajoute :

```lua
-- ─── pop_medexam ────────────────────────────────────────────

-- 'auto'  : borne en libre-service
-- 'ems'   : un EMS en service fait passer la visite
-- 'mixed' : EMS, ou borne automatique quand aucun EMS n'est en service
Config.Mode = 'mixed'

Config.EmsJobs = { 'ambulance' } -- format Bridge.HasJob ; doivent être en service

Config.Price    = 250      -- prix de la visite
Config.Account  = 'bank'   -- compte débité (patient) et crédité (médecin) : 'cash' | 'bank'
Config.Item     = 'medical_certificate'
Config.Validity = 30       -- jours de validité (0 = n'expire jamais)
Config.Cooldown = 300      -- secondes avant de repasser une visite (après un échec ou un certificat)

-- Durée des étapes en barre de progression (ms). En mode auto, seule la tension est une barre :
-- vision et réflexes sont des mini-jeux.
Config.Durations = { pressure = 4000, vision = 3000, reflex = 3000 }

-- Cliniques. ped = PNJ à l'accueil (false : simple zone). blip = afficher sur la carte.
Config.Locations = {
    { coords = vector4(311.2, -593.5, 43.28, 340.0), ped = 's_m_m_doctor_01', blip = true },
}

Config.Blip = { sprite = 61, color = 2, scale = 0.8 }
```

Constantes (code) : `ACTION_DISTANCE = 3.0` (serveur, joueur ↔ lieu), `PATIENT_DISTANCE = 3.0` (serveur, médecin ↔
patient), `SHOW_DISTANCE = 3.0` (carte), `TARGET_DISTANCE = 2.0`, `PED_DISTANCE = 40.0`, `CONSENT_TIMEOUT = 15000` ms,
`CARD_TIME = 8000` ms.

---

## 9. Locales

10 fichiers (en, fr, es, de, it, pt, nl, pl, tr, ar `_rtl = true`). Bloc « Kit commun » + clés ci-dessous.

| Clé | en | fr |
|---|---|---|
| `blip_name` | Medical exam | Visite médicale |
| `target_auto` | Take a medical exam ($%s) | Passer la visite médicale (%s $) |
| `target_ems` | Examine a patient | Faire passer une visite |
| `step_pressure` | Checking blood pressure... | Prise de tension... |
| `step_vision` | Vision test | Test de vision |
| `step_reflex` | Reflex test | Test de réflexes |
| `skill_hint` | Press in the zone | Appuyez dans la zone |
| `exam_started` | Exam started: %s | Visite commencée : %s |
| `exam_passed` | You are fit. Certificate issued | Vous êtes apte. Certificat délivré |
| `exam_failed` | Exam failed: you are unfit for now | Visite échouée : vous êtes inapte pour l'instant |
| `exam_done_doctor` | Certificate issued to %s (+$%s) | Certificat remis à %s (+%s $) |
| `exam_closed` | The self-service desk is closed: ask a doctor | La borne est fermée : demandez un médecin |
| `exam_too_fast` | The exam was too short | La visite a été trop courte |
| `no_patient` | No patient nearby | Aucun patient à proximité |
| `patient_refused` | The patient refused | Le patient a refusé |
| `patient_gone` | The patient left | Le patient est parti |
| `no_session` | No exam in progress | Aucune visite en cours |
| `consent_text` | %s offers you a medical exam (%s) | %s vous propose une visite médicale (%s) |
| `accept` | Accept | Accepter |
| `refuse` | Refuse | Refuser |
| `money` | $%s | %s $ |
| `auto_doctor` | Clinic | Clinique |
| `cert_description` | %s - valid until %s | %s - valide jusqu'au %s |
| `cert_no_data` | This certificate is unreadable | Ce certificat est illisible |
| `card_title` | Medical certificate | Certificat médical |
| `card_name` | Name: %s | Nom : %s |
| `card_issued` | Issued: %s | Délivré le : %s |
| `card_expires` | Valid until: %s | Valide jusqu'au : %s |
| `card_no_expiry` | No expiry | Sans expiration |
| `card_doctor` | Doctor: %s | Médecin : %s |
| `card_valid` | Valid | Valide |
| `card_expired` | Expired | Expiré |

Clés de base réutilisées : `too_far`, `busy`, `error`, `wrong_job`, `not_enough_money`, `inventory_full`, `cooldown`,
`progress_cancelled`. Pour `cert_description` sans expiration : 2e argument = `L('card_no_expiry')`.

---

## 10. Schéma SQL

Aucun. (Le certificat vit dans l'inventaire.) README : déclaration de l'item `medical_certificate` pour
ox_inventory, qb/qs-inventory et ESX (`INSERT INTO items`).

---

## 11. Comportement attendu

### Serveur
- Mémoire : `sessions[src] = { loc, startedAt }` (auto) ; `emsSessions[doctorSrc] = { loc, patient, startedAt }` ;
  `patientOf[patientSrc] = doctorSrc` ; `cooldowns[identifier] = os.time() + Config.Cooldown`.
- `emsOnDuty()` : un joueur de `Bridge.GetPlayers()` avec `Bridge.HasJob(src, Config.EmsJobs)` et `onDuty`.
- `autoOpen` = `Config.Mode == 'auto'` ou (`Config.Mode == 'mixed'` et pas `emsOnDuty()`).
- `isDoctor(src)` = `Config.Mode ~= 'auto'` et `Bridge.HasJob(src, Config.EmsJobs)` et `Bridge.GetJob(src).onDuty`.
- Délivrance (`issue(patient, doctorName)`) : métadonnées section 3 (si `SupportsMetadata`), `Bridge.AddItem`.
- Item utilisable : `Bridge.RegisterUsableItem(Config.Item, cb)` ; `metadata.name` absent → `cert_no_data` ;
  sinon `CertificateCard` envoyée au porteur et à chaque joueur de `Bridge.GetPlayers()` à ≤ `SHOW_DISTANCE`
  (`Bridge.GetCoords`). `valid = expires == 0 or expires > os.time()`.
- Notifications succès : auto → `exam_passed` (patient) ; EMS → `exam_passed` (patient) et
  `exam_done_doctor` (médecin, nom du patient, prix) ; `emsStart` → `exam_started` au médecin avec le nom.

### Client
- Blips, PNJ et zones : même schéma que les autres scripts POP (boucle 1000/2500 ms, `AddLocalEntity` sur le PNJ ou
  `AddBoxZone('pop_medexam_' .. i, xyz, vec3(1.5, 1.5, 2.0), w, opts)`). Scénario PNJ : `WORLD_HUMAN_CLIPBOARD`.
- Options (distance `TARGET_DISTANCE`), état lu une fois à l'approche via `pop_medexam:getState` (mis en cache
  10 s par lieu ; `canInteract` lit ce cache) :
  | label | icône | canInteract | action |
  |---|---|---|---|
  | `L('target_auto', Config.Price)` | `fa-solid fa-notes-medical` | `autoOpen` | déroulé auto |
  | `L('target_ems')` | `fa-solid fa-user-doctor` | `isDoctor` | déroulé EMS |
- **Déroulé auto** : `Callback.Await('pop_medexam:start', i)` → si ok :
  1. `Bridge.Progress(L('step_pressure'), Config.Durations.pressure, { anim = { dict = 'missheistdockssetup1clipboard@base', clip = 'base', flag = 49 } })` ;
  2. mini-jeu vision (`zone = 0.18`) ; 3. mini-jeu réflexes (`zone = 0.12`) — chaque mini-jeu attend
     `pop_medexam:skillResult` ou `close` (échec), puis `SetNuiFocus(false, false)` ; un échec arrête la suite.
  Progression annulée → `pop_medexam:cancel` ; sinon `pop_medexam:finish(passed)`.
- **Déroulé EMS** : `Callback.Await('pop_medexam:emsStart', i)` → si ok, 3 `Bridge.Progress` successives
  (`step_pressure`, `step_vision`, `step_reflex`, durées `Config.Durations.*`, anim clipboard ci-dessus) ;
  annulée → `pop_medexam:emsCancel`, sinon `pop_medexam:emsFinish`.
- **Consentement** (`Callback.Register('pop_medexam:consent', fn(price, doctor))`) : affiche `pop_medexam:consent`,
  boucle `Wait(0)` **limitée à `CONSENT_TIMEOUT`** : `IsControlJustReleased` sur `Config.Keys.Interact.control`
  (accepter) / `Config.Keys.Cancel.control` (refuser) ; masque le panneau ; renvoie le bool.
- **Carte** : `pop_medexam:client:showCertificate` → `pop_medexam:certificate` show, masquée après `CARD_TIME`
  (une nouvelle carte remplace l'ancienne et relance le minuteur).
- Arrêt : PNJ, blips, panneaux masqués, focus rendu.

---

## 12. Règles de sécurité (serveur, obligatoires)

Le client n'envoie qu'un index de lieu et, en fin d'examen auto, un booléen. Prix, item, métadonnées, médecin,
temps : serveur uniquement.

**Commun**
1. `loc` entier valide de `Config.Locations` ; `Bridge.IsNear(src, lieu, ACTION_DISTANCE)`, sinon `too_far`.
2. Verrou `busy[src]` pendant chaque traitement → `busy`. Un joueur ne peut être que dans **une** session (auto,
   médecin ou patient) → `busy`.
3. `Bridge.GetIdentifier` non nil, sinon `error`. Anti-spam du template actif.

**`start` (auto)**
1. `autoOpen`, sinon `exam_closed`. 2. Délai par identifiant → `cooldown`. 3. `Bridge.CanCarry(src, Config.Item, 1)`,
sinon `inventory_full`. 4. `Bridge.RemoveMoney(src, Config.Account, Config.Price, 'pop_medexam')`, sinon
`not_enough_money`. 5. Session créée (`startedAt = os.time()`).

**`finish` (auto)**
1. Session existante, sinon `no_session`. 2. `os.time() - startedAt >= floor(Config.Durations.pressure / 1000) + 2`,
sinon `exam_too_fast` (session supprimée, pas de remboursement). 3. Toujours près du lieu de la session.
4. Session supprimée **avant** la délivrance ; délai posé. 5. `passed ~= true` → `exam_failed` (pas de remboursement).
6. `issue` échoue → rembourser `Config.Price` (`Bridge.AddMoney`), `inventory_full`.

**`cancel` (auto)** : session supprimée, `Config.Price` remboursé, pas de délai.

**`emsStart`**
1. `isDoctor(src)`, sinon `wrong_job`. 2. Patient = joueur le plus proche du médecin (`Bridge.GetCoords`) à
≤ `PATIENT_DISTANCE`, différent du médecin, hors session, non mort (`Bridge.IsDead`), sinon `no_patient`.
3. Délai du patient → `cooldown`. 4. `Bridge.CanCarry(patient, Config.Item, 1)`, sinon `inventory_full`.
5. `Callback.Await('pop_medexam:consent', patient, Config.Price, Bridge.GetName(src))` ≠ `true` → `patient_refused`.
6. Revalider : médecin toujours `isDoctor` et près du lieu, patient toujours à ≤ `PATIENT_DISTANCE`.
7. `Bridge.RemoveMoney(patient, Config.Account, Config.Price, 'pop_medexam')`, sinon `not_enough_money` (notifié
   au médecin ; le patient reçoit aussi `not_enough_money`). 8. Session créée.

**`emsFinish`**
1. Session du médecin, sinon `no_session`. 2. `os.time() - startedAt >= floor((pressure + vision + reflex) / 1000) - 1`,
sinon `exam_too_fast` (patient remboursé). 3. Médecin près du lieu, patient à ≤ `PATIENT_DISTANCE` du médecin,
sinon `patient_gone` (patient remboursé). 4. Session supprimée avant délivrance ; `issue(patient, Bridge.GetName(src))` ;
échec → remboursement, `inventory_full`. 5. Succès → `Bridge.AddMoney(src, Config.Account, Config.Price,
'pop_medexam')`, délai posé pour le patient.

**`emsCancel`** : session supprimée, patient remboursé.

**Déconnexion / unload** : patient → session du médecin supprimée, `pop_medexam:client:sessionEnded(doctor,
'patient_gone')` (argent déjà payé par un joueur parti : non remboursé, rien n'est remis). Médecin → patient
remboursé, session supprimée. Session auto → supprimée sans remboursement.

**Exports** : `GiveCertificate` n'est appelable que côté serveur (export Lua, aucun event réseau).

---

## 13. Checklist de livraison (auditeur)
- `luacheck resources templates` : 0 erreur ; `node --check web/script.js`.
- `bridge/`, `shared/`, `web/kit/` identiques à `templates/pop_base`.
- 10 locales complètes ; aucun texte en dur.
- `Wait(0)` seulement : consentement (15 s max), `Bridge.Progress`. Focus rendu après chaque mini-jeu, à Échap,
  à l'arrêt.
- Modes auto / ems / mixed testés ; ESX, QBCore, Qbox ; ox / qb / qs-inventory et inventaire du framework.
