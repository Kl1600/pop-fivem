# pop_death

Mort du joueur : écran « Vous êtes mort », appel des secours, réapparition à l'hôpital.

## Fonctionnement
- À la mort, un écran discret s'affiche en bas : compte à rebours (5 min par défaut) et touche **[G] Appeler les secours**.
- **Appel aux secours** : pas encore de métier EMS. L'appel déclenche l'évènement serveur `pop_death:emsCalled` (src, coords) que le futur script EMS écoutera. Un nouvel appel est possible après `Config.CallCooldown`.
- **Fin du délai** : le serveur vérifie que le temps est écoulé et renvoie le joueur à l'hôpital le plus proche (vie au max, faim et soif à 50 %).
- **Réanimation sur place** (défibrillateur pop_inventory, revive admin) : l'écran se ferme tout seul.
- **Déconnexion pendant le délai** : à la reconnexion, le joueur repart au sol avec le temps restant (jusqu'au redémarrage du serveur).
- Le godmode admin empêche la mort.

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | délai, touche, cooldown d'appel, hôpitaux, faim/soif à la réapparition |
| `locales/fr.lua` | textes |
| `client/main.lua` | détection, écran, appel, réapparition |
| `server/main.lua` | heure de la mort, contrôle du délai, choix de l'hôpital, appel |
| `html/index.html` | écran |
| `bridge/`, `shared/` | fichiers communs POP (`templates/pop_base`) |

## Touches
`G` : appeler les secours (modifiable : Paramètres > Raccourcis > FiveM).

## Exports et évènements
| Nom | Côté | Rôle |
|---|---|---|
| `exports.pop_death:isDead()` | client | le joueur local est-il mort |
| `exports.pop_death:isDead(src)` | serveur | le joueur est-il mort |
| `pop_death:emsCalled` (src, coords) | serveur (TriggerEvent) | appel aux secours, pour le futur EMS |

## Relancer
`restart pop_death`
