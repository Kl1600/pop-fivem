# pop_vehiclepersistence

Persistance physique des véhicules : tout véhicule conduit (avec ses clés) est sauvegardé (position, état, mods, dégâts, carburant) et réapparaît là où il a été laissé, **uniquement autour des joueurs** (rayon `Config.CullRadius`, 250 m) pour économiser les ressources.

## Fonctionnement
- À l'entrée dans un véhicule, puis toutes les 10 s en roulant (30 s / 60 s à l'arrêt), le client envoie l'état du véhicule. Le serveur vérifie que le véhicule existe (netId), que le modèle et la plaque correspondent, prend la position côté serveur et borne toutes les valeurs.
- Seul un joueur qui a la clé (`carkeys` de pop_inventory avec `meta.plate`, ou `Config.HasVehicleKey`) fait sauvegarder un véhicule.
- Le serveur range les véhicules dans une grille spatiale et demande au joueur le plus proche de les faire apparaître ; il les fait disparaître quand plus personne n'est à proximité.
- À la connexion, seuls les véhicules proches du joueur apparaissent ; la connexion ne compte pas comme une utilisation.
- Un véhicule non utilisé depuis `Config.MaxPersistenceDays` jours est supprimé (0 = jamais).
- Table propre `persistent_vehicles` (créée et migrée automatiquement). Ne lit ni n'écrit `owned_vehicles`. Propriétaire suivi par license (`Config.OwnerKey`).

## Dépendances
oxmysql. Optionnel : pop_inventory (clés, `Config.UseTabInventory = true`), pop_notify (notifications).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | réglages communs POP + clés, expiration, propriétaire, rayons |
| `locales/fr.lua` | tous les textes (debug, HUD `/showvehicles`) |
| `client/notify.lua` | notifications, export `Notify` |
| `client/props.lua` | lecture / application des propriétés d'un véhicule (`PersistClient`) |
| `client/main.lua` | suivi du véhicule conduit, envoi au serveur, apparition / disparition |
| `client/debug_hud.lua` | outil admin `/showvehicles` (HUD + repères 3D) |
| `server/common.lua` | état partagé (`Persist`), grille spatiale, validation des données client |
| `server/keys.lua` | propriétaire (owner_id) et vérification des clés |
| `server/storage.lua` | base de données, export `Forget`, expiration |
| `server/spatial.lua` | boucle spatiale, auto-save, purge horaire |
| `server/events.lua` | évènements réseau, commande `debug_persistence` |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Réglages principaux
| Option | Défaut | Rôle |
|---|---|---|
| `UseTabInventory` | `true` | sauvegarde seulement avec la clé `carkeys` (sinon tout véhicule conduit) |
| `MaxPersistenceDays` | `30` | expiration d'un véhicule inutilisé (0 = jamais) |
| `OwnerKey` | `'license'` | `'license'` ou `'framework'` — **ne pas changer sur une base existante** |
| `CustomIdentifier` / `CustomNotify` / `HasVehicleKey` | `nil` | crochets avancés |
| `CullRadius` | `250.0` | rayon d'apparition autour des joueurs |
| `MaxClientDistance` | `75.0` | distance max joueur ↔ véhicule envoyé |

`UseTabInventory = true` sans pop_inventory = aucun véhicule sauvegardé.

## Commandes
| Commande | Qui | Rôle |
|---|---|---|
| `/showvehicles` | admin (ACE `command`) | HUD + affichage 3D des véhicules persistés |
| `debug_persistence` | console / admin | état (base, véhicules apparus, véhicules suivis) |

## Évènements et exports
| Nom | Sens | Rôle |
|---|---|---|
| `CurrentVehicle` (data \| nil) | client → serveur | véhicule conduit (nil = sortie) |
| `saveVehicleToDatabase` | client → serveur | sauvegarde immédiate |
| `requestSavedVehicle` | client → serveur | véhicules du joueur à la connexion |
| `respawnPlayerInVehicle` | serveur → client | faire apparaître un véhicule |
| `pop_vehiclepersistence:despawnVehicle` / `:despawnFailed` | serveur ↔ client | faire disparaître un véhicule |
| `pop_vehiclepersistence:vehicleSpawned` | client → serveur | véhicule apparu |
| `pop_vehiclepersistence:forceResync` | serveur → client | renvoyer le véhicule conduit (clé reçue) |
| `pop_vehiclepersistence:notify` | serveur → client | notification |
| export serveur `Forget(plate)` | | retire une plaque (monde, mémoire, base) — pop_enterprisegarage |
| export serveur `IsTracked(plate)` | | plaque suivie ? |
| export serveur `GetIdentifier(src)` | | owner_id du joueur |
| export serveur `PlayerHasKey(src, plate)` / `playerHasKeyCached(pid, plate)` | | vérification des clés |
| export serveur `OnKeyGranted(pid, plate)` | | à appeler quand une clé est donnée (pop_inventory) |
| export client `Notify(msg, type)` | | notification (pop_enterprisegarage) |

## Relancer
`restart pop_vehiclepersistence` (puis `restart pop_enterprisegarage` qui utilise ses exports).
