# pop_ems

Ambulance job for FiveM: duty and outfit, service vehicles, emergency calls, care menu (check-up, bandage, medical kit, revive), transport to hospital and billing.
ESX, QBCore, Qbox or standalone. 5 languages (fr, en, es, de, ar). ~0.00 ms at rest. No database.

[English](#english) | [Français](#français)

---

## English

### Installation (3 steps)
1. Copy `pop_ems` into `resources/[pop]/` and add `ensure pop_ems` to `server.cfg` **after** your framework, inventory and target resources.
2. Declare the items `bandage`, `kitsoins`, `defib` for your inventory using `install/` (`items_ox.lua`, `items_qb.lua`, `items_esx.sql` or `items_pop.lua`) and copy the images from `install/images/`.
3. Set `Config.Job.name` (default `ambulance`) and check the hospital coordinates in `config.lua`. Standalone: give the ACE `add_ace group.ems pop.ems allow`.

Optional: `pop_death` (calls and unconscious state), `pop_medexam` (body zones in the check-up), `pop_notify`, `pop_inventory`.

### Configuration
All settings are in `config.lua` (commented): language, job and minimum grade, call key (Y), items (`false` = no item required), action durations, prices (0 = free), revive and bandage health, distances, cooldown, calls, light injuries, vehicles, outfit, blips and hospitals.

The server is the only judge: job, duty, distances, items, money and action duration are all checked server side. Prices are only read from `config.lua`.
Billing: patient bank, then cash. Credited to the `society_<job>` account (esx_addonaccount, qb-banking, qb-management, Renewed-Banking) or to the medic's bank if no society system is found. No billing in standalone.

### Server exports
| Export | Parameters | Returns |
|---|---|---|
| `exports.pop_ems:isOnDuty(src)` | player id | bool |
| `exports.pop_ems:getOnDutyCount()` | none | int |
| `exports.pop_ems:createCall(src, coords?)` | player id, vector3 or nil | call id or nil |
| `exports.pop_ems:revive(src)` | player id | bool (forced revive, server scripts only) |

### Client exports
| Export | Returns |
|---|---|
| `exports.pop_ems:isOnDuty()` | bool |
| `exports.pop_ems:getInjuries()` | `{ bleeding = bool, limp = bool }` |

### Events
| Event | Side | Parameters |
|---|---|---|
| `pop_death:emsCalled` | server, listened (local only) | `src`, `coords` |
| `pop_ems:revived` | server, emitted | `patient`, `medic` (nil from the export) |
| `pop_ems:admitted` | server, emitted | `patient`, `medic`, `stationIndex` |

State bags: `popEmsDuty` (player), `popEmsTransport` (player), `popEmsPatient` (vehicle) are set by the server only; `popEmsInjury` is set by the patient's client (display only).

---

## Français

### Installation (3 étapes)
1. Copier `pop_ems` dans `resources/[pop]/` et ajouter `ensure pop_ems` dans `server.cfg` **après** le framework, l'inventaire et le système de ciblage.
2. Déclarer les objets `bandage`, `kitsoins`, `defib` dans votre inventaire avec `install/` (`items_ox.lua`, `items_qb.lua`, `items_esx.sql` ou `items_pop.lua`) et copier les images de `install/images/`.
3. Régler `Config.Job.name` (par défaut `ambulance`) et vérifier les coordonnées des hôpitaux dans `config.lua`. En standalone : donner l'ACE `add_ace group.ems pop.ems allow`.

Facultatif : `pop_death` (appels et état inconscient), `pop_medexam` (zones du corps dans le diagnostic), `pop_notify`, `pop_inventory`.

### Configuration
Tout est dans `config.lua` (commenté) : langue, métier et grade minimum, touche d'appel (Y), objets (`false` = aucun objet exigé), durées des actions, prix (0 = gratuit), santé rendue, distances, délai entre deux soins, appels, blessures légères, véhicules, tenue, blips et hôpitaux.

Le serveur est seul juge : métier, service, distances, objets, argent et durée des actions sont vérifiés côté serveur. Les prix sont lus uniquement dans `config.lua`.
Facture : banque du patient, sinon liquide. Crédit sur le compte `society_<métier>` (esx_addonaccount, qb-banking, qb-management, Renewed-Banking) ou sur la banque du secouriste si aucun système de société n'est trouvé. Pas de facture en standalone.

### Exports serveur
| Export | Paramètres | Retour |
|---|---|---|
| `exports.pop_ems:isOnDuty(src)` | id joueur | bool |
| `exports.pop_ems:getOnDutyCount()` | aucun | int |
| `exports.pop_ems:createCall(src, coords?)` | id joueur, vector3 ou nil | id d'appel ou nil |
| `exports.pop_ems:revive(src)` | id joueur | bool (réanimation forcée, scripts serveur uniquement) |

### Exports client
| Export | Retour |
|---|---|
| `exports.pop_ems:isOnDuty()` | bool |
| `exports.pop_ems:getInjuries()` | `{ bleeding = bool, limp = bool }` |

### Événements
| Événement | Côté | Paramètres |
|---|---|---|
| `pop_death:emsCalled` | serveur, écouté (local uniquement) | `src`, `coords` |
| `pop_ems:revived` | serveur, émis | `patient`, `medic` (nil depuis l'export) |
| `pop_ems:admitted` | serveur, émis | `patient`, `medic`, `stationIndex` |

Statebags : `popEmsDuty` (joueur), `popEmsTransport` (joueur), `popEmsPatient` (véhicule) posés par le serveur uniquement ; `popEmsInjury` posé par le client du patient (affichage seulement).
