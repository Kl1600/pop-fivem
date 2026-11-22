# pop_enterprisegarage

Garage d'entreprise : une flotte de véhicules par job (police, EMS…), persistante et partagée entre les employés.

## Fonctionnement
- Chaque garage (`Config.Garages`) est réservé à un job ESX. Un marker et un blip indiquent le point d'interaction ; touche **E** (`Config.OpenKey`) pour ouvrir le menu.
- La flotte est stockée dans la table `enterprise_garage_vehicles` (créée et remplie au premier démarrage, plaques uniques).
- **Sortir** : le véhicule apparaît au point de sortie, le joueur reçoit une clé `carkeys` (pop_inventory) et `pop_vehiclepersistence` le sauvegarde.
- **Ranger** : le serveur vérifie le véhicule (netId, plaque, modèle de la flotte, à moins de `Config.StoreDistance` m, état « sorti »). Le véhicule est retiré du monde et de la persistance (`exports.pop_vehiclepersistence:Forget`), la clé est reprise.
- Un véhicule détruit ou disparu peut être ressorti (l'ancienne copie est oubliée).

## Dépendances
es_extended, oxmysql, pop_vehiclepersistence. pop_inventory pour les clés (facultatif).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | garages, flottes, touche, marker, distances |
| `locales/fr.lua` | tous les textes |
| `client/main.lua` | menu NUI, sortie, rangement |
| `client/zones.lua` | blips, marker, touche, commande |
| `server/common.lua` | fonctions partagées (`Garage.*`) : plaques, persistance, clés, accès |
| `server/fleet.lua` | création de la table et flotte initiale |
| `server/garage.lua` | liste, sortie, clés, rangement |
| `html/` | interface du menu |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes et touches
| Commande / touche | Rôle |
|---|---|
| `E` dans la zone | ouvre le garage (job requis) |
| `/entreprisegarage` (`Config.Command`) | ouvre le garage le plus proche (le serveur vérifie job et distance) |

## Évènements et exports
| Nom | Sens | Rôle |
|---|---|---|
| `pop_enterprisegarage:requestList` (garage) | client → serveur | demande la flotte |
| `pop_enterprisegarage:openMenu` | serveur → client | ouvre le menu |
| `pop_enterprisegarage:takeOut` (garage, plate) | client → serveur | sortie d'un véhicule |
| `pop_enterprisegarage:spawn` | serveur → client | fait apparaître le véhicule |
| `pop_enterprisegarage:giveKeys` (plate) | client → serveur | clé du véhicule qui vient de sortir |
| `pop_enterprisegarage:store` (garage, plate, props, netId) | client → serveur | rangement |
| `pop_enterprisegarage:confirmStore` | serveur → client | supprime le véhicule rangé |
| `exports.pop_enterprisegarage:open(label)` | client | ouvre un garage par son label |

## Relancer
`restart pop_enterprisegarage`
