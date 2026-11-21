# pop_weed

Culture de cannabis : on plante un pot avec une graine, on arrose, la plante pousse en 6 stades, puis on récolte.

## Fonctionnement
- Plantation : utiliser l'objet **pot** (graine `grainecana` requise) ou la commande `/plantweed`, puis placer la plante avec le gizmo (object_gizmo). Le serveur vérifie la distance, le pot, la graine et la limite `Config.MaxPlantsPerPlayer`.
- Croissance : 30 min (`Config.TotalDuration`) en 6 stades (`Config.Stages`). Le temps ne compte que tant qu'il reste de l'eau (`Config.WaterDuration`) ; chaque stade franchi consomme la moitié de l'eau restante.
- Arrosage : utiliser la **bouteille** près d'une plante (3 m), ou la glisser sur la plante depuis l'inventaire.
- HUD 3D au-dessus de la plante (barre verte Croissance, barre bleue Eau), puis prompt **[E] Récolter** quand elle est prête. Option ox_target **Examiner** / **Récolter**.
- Récolte : barre ox_lib de 5 s, puis 5 `weed`.
- Les plantes sont enregistrées dans `data/plants.json` (pas de SQL). Le propriétaire est la license Cfx du joueur.

## Dépendances
ox_lib, ox_target, object_gizmo, pop_inventory (objets, glisser-déposer), pop_v3dui (prompt de récolte), pop_notify (notifications, via le bridge).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | durées, stades, objets, distances, durée des notifications |
| `locales/fr.lua` | tous les textes |
| `client/plants.lua` | calcul de croissance, props, cible ox_target, récolte, évènements réseau |
| `client/placement.lua` | placement au gizmo (`/plantweed`, utilisation du pot) |
| `client/hud.lua` | HUD 3D, prompt de récolte, création des props selon la distance |
| `server/common.lua` | fonctions partagées (`Weed.*`) : sauvegarde, croissance, notification |
| `server/main.lua` | chargement, synchronisation des clients, tick de croissance |
| `server/actions.lua` | arroser, planter, récolter |
| `data/plants.json` | plantes enregistrées |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes / touches
| Commande / touche | Rôle |
|---|---|
| `/plantweed` | placer une plante (pot + graine requis) |
| E (`Config.Keys.Interact`) | récolter une plante prête (à 2 m) |

## Évènements
| Nom | Sens | Rôle |
|---|---|---|
| `pop_weed:requestSync` | client → serveur | demande la liste des plantes |
| `pop_weed:syncAll` | serveur → client | liste des plantes |
| `pop_weed:spawnPlant` / `pop_weed:removePlant` / `pop_weed:updatePlant` | serveur → clients | plante ajoutée / récoltée / stade changé |
| `pop_weed:waterUpdate` | serveur → clients | plante arrosée |
| `pop_weed:plant` (x, y, z, heading) | client → serveur | planter |
| `pop_weed:water` (plantId) | client → serveur | arroser |
| `pop_weed:harvest` (plantId) | client → serveur | récolter |
| `pop_weed:usePot` | pop_inventory → client | utilisation du pot |
| `pop_weed:useWaterBottle` | pop_inventory → client | utilisation de la bouteille |
| `pop_weed:notify` (data) | serveur → client | ancienne notification, gardée pour compatibilité |

## Relancer
`restart pop_weed`
