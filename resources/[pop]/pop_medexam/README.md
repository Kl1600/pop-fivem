# pop_medexam

Examen médical : l'EMS voit l'état de chaque zone du corps d'un joueur (tête, torse, bras, jambes) et peut le soigner.

## Fonctionnement
- Chaque joueur suit ses propres blessures : un dégât reçu est attribué à la zone touchée (`Config.BoneToPart`). L'état est partagé par statebag (`medInjuries`).
- Les blessures reviennent à 100 % à la réapparition ou à la réanimation.
- Sur un joueur (ox_target), l'EMS a deux options : **Examiner les blessures** (étiquettes affichées sur le corps, couleur selon la gravité) et **Soigner les blessures**.
- L'examen se ferme avec X (`Config.CloseControl`) ou si le patient s'éloigne de plus de `Config.MaxExamDistance` m.
- Le soin est vérifié par le serveur : métier EMS et patient à moins de `Config.MaxTreatDistance` m.

## Dépendances
es_extended, ox_target.

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | métiers EMS (`ambulance`, `ems`), distances, touche de fermeture, zones du corps et os |
| `locales/fr.lua` | tous les textes (options, noms des zones) |
| `client/injuries.lua` | suivi des blessures du joueur, soin reçu |
| `client/exam.lua` | examen (affichage NUI), options ox_target |
| `server/main.lua` | soin (contrôle du métier et de la distance) |
| `html/` | affichage des étiquettes sur le corps |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Évènements
| Nom | Sens | Rôle |
|---|---|---|
| `pop_medexam:treat` (targetId, part?) | client → serveur | demande de soin d'un joueur (une zone ou tout) |
| `pop_medexam:treated` (part?) | serveur → client | le patient remet la zone (ou tout) à 100 % |
| Options ox_target `pop_medexam_examine`, `pop_medexam_treat` | — | examen et soin sur les joueurs |

## Réglages utiles
`Config.DevMode = true` : tout le monde peut examiner (test). `Config.EmsJobs` : métiers autorisés.

## Relancer
`restart pop_medexam`
