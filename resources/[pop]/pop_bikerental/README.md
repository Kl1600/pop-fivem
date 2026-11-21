# pop_bikerental

Location de vélos (Inductor) et de Ventoso, payée en espèces.

## Fonctionnement
- Deux points de location (`Config.Locations`) avec des véhicules d'exposition figés et verrouillés. Sur ces véhicules, ox_target ne montre que l'option **Louer ... (150$)**.
- Location : le client vérifie que le point de spawn est libre (`Config.SpawnClearRadius`), puis le serveur retrouve lui-même le point de location proche du joueur (`Config.MaxRentDistance`) qui propose ce modèle. Le modèle et les coordonnées envoyés par le client ne sont jamais utilisés tels quels.
- Paiement : `Config.Price` en objet `cash` de pop_inventory (`Bridge.GetMoney/RemoveMoney(src, 'cash')`). Le véhicule apparaît au point de spawn avec le joueur au volant.
- Ventoso : si `vehicle_keys` est lancé, le joueur reçoit les clés.

## Dépendances
es_extended (spawn du véhicule loué), ox_lib (`cache.ped`), ox_target (filtre `onlyRentTarget`), pop_inventory (cash). Optionnel : vehicle_keys, pop_notify.

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | prix, points de location, rayons, durée des notifications |
| `locales/fr.lua` | tous les textes |
| `client/main.lua` | véhicules d'exposition, option de location, spawn du véhicule loué |
| `server/common.lua` | fonctions partagées (`BikeRental.*`) |
| `server/main.lua` | paiement et validation de la location |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes / touches
Aucune (ox_target sur les véhicules d'exposition).

## Évènements
| Nom | Sens | Rôle |
|---|---|---|
| `pop_bikerental:server:buyVehicle` (model) | client → serveur | demande de location |
| `pop_bikerental:client:spawnVehicle` (model, x, y, z, h) | serveur → client | spawn du véhicule payé |
| `vehicle_keys:server:giveKey` (plate, label) | client → serveur | clés du Ventoso (si vehicle_keys est lancé) |

## Relancer
`restart pop_bikerental`
