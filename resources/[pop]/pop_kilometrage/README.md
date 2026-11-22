# pop_kilometrage

Compteur kilométrique des véhicules, sauvegardé par plaque.

## Fonctionnement
- Le conducteur calcule la distance parcourue (toutes les `Config.CheckInterval` ms, roues au sol et hors de l'eau) et la partage dans le statebag `vehicleMileage` du véhicule.
- Au-delà de `Config.ServerUpdateThreshold` km, la valeur est envoyée au serveur. Le serveur vérifie que le joueur conduit bien ce véhicule, lit la base avant d'accepter une première valeur, et n'accepte qu'une hausse d'au plus `Config.MaxStepKm` km.
- Les valeurs sont écrites en base en une requête groupée toutes les `Config.FlushInterval` ms (et à l'arrêt de la ressource). Table `vehicle_mileage` créée automatiquement.
- Une demande de kilométrage par seconde et par joueur maximum ; le client redemande toutes les 3 s si la réponse se perd.

## Dépendances
oxmysql. Lu par pop_speedometer (export client `GetMileage`).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | réglages communs POP + intervalles et limites |
| `locales/fr.lua` | textes communs (le script n'affiche rien) |
| `client/main.lua` | calcul de la distance, statebag, export client |
| `server/main.lua` | vérifications, tampon et écriture en base, export serveur |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Évènements et exports
| Nom | Sens | Rôle |
|---|---|---|
| `pop_kilometrage:server:requestMileage` (plate) | client → serveur | demande le kilométrage d'une plaque |
| `pop_kilometrage:client:receiveMileage` (plate, km) | serveur → client | réponse |
| `pop_kilometrage:server:updateMileage` (plate, km) | client → serveur | nouvelle valeur |
| export client `GetMileage()` | | km du véhicule courant (ou false) |
| export serveur `GetMileage(plate, cb)` | | km d'une plaque |

## Relancer
`restart pop_kilometrage`
