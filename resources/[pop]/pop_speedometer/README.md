# pop_speedometer

Compteur affiché en voiture moteur allumé : vitesse, carburant et kilométrage (lu dans `pop_kilometrage`).

## Fonctionnement
- Visible seulement en véhicule, moteur allumé. Mise à jour toutes les `Config.RefreshDriving` ms, et envoi à l'interface seulement si une valeur change.
- Kilométrage lu via `exports.pop_kilometrage:GetMileage()` environ une fois par seconde.
- Masqué quand un script envoie `hud:toggleui` avec `false` (ex. menu Benny's).

## Dépendances
`pop_kilometrage`.

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | unité, fréquences de mise à jour |
| `client/main.lua` | lecture du véhicule, envoi à l'interface |
| `ui/` | interface (inchangée) |

## Évènements
| Évènement | Côté | Rôle |
|---|---|---|
| `hud:toggleui` (show) | client | `false` masque le compteur |

## Réglages
`Config.UseMetric` suit la convar `sh_miles` (0 = km/h, 1 = mph).

## Relancer
`restart pop_speedometer`
