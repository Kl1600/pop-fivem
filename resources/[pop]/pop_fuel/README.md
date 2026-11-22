# pop_fuel

Essence : les véhicules consomment, tombent en panne sèche, et se remplissent aux stations-service.

## Fonctionnement
- **Consommation** : chaque seconde, selon le régime moteur et la classe du véhicule. Les vélos, trains et véhicules électriques (`Config.Electric`) ne consomment pas. À 0, le moteur s'arrête.
- **Niveau** : celui de GTA (`GetVehicleFuelLevel`), donc sauvegardé par pop_vehiclepersistence et affiché par pop_speedometer. Partagé entre joueurs par le statebag `state.fuel`.
- **Faire le plein** : viser une pompe (ox_target) avec un véhicule à moins de 5 m, **moteur coupé** → petite fenêtre au style du serveur : espèces ou carte → remplissage (annulable avec X, rien n'est payé avant la fin) → le serveur calcule le prix, vérifie la station et la distance, puis encaisse.
- Stations affichées sur la carte (`Config.ShowBlips`).

## Dépendances
ox_target (via le bridge), pop_inventory (espèces = objet `cash`).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | prix du litre, durée du plein, consommation, électriques, pompes, stations |
| `locales/fr.lua` | textes |
| `client/consumption.lua` | consommation, panne sèche, partage du niveau |
| `client/stations.lua` | pompes, menu de paiement, remplissage, icônes carte |
| `server/main.lua` | calcul du prix et encaissement |

## Exports
| Nom | Côté | Rôle |
|---|---|---|
| `exports.pop_fuel:GetFuel(vehicle)` | client | niveau (0 à 100) |
| `exports.pop_fuel:SetFuel(vehicle, level)` | client | change le niveau (local et partagé) |

## Relancer
`restart pop_fuel`
