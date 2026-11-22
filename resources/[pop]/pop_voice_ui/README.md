# pop_voice_ui

Barre d'activité vocale à l'écran (« PARLEZ DANS VOTRE MICRO »). Aucun framework requis.

## Fonctionnement
- `/voice-ui` affiche ou cache la barre.
- Barre affichée : toutes les 50 ms, si le joueur parle (`MumbleIsPlayerTalking`), un débit simulé entre 60 % et 100 % est envoyé à la NUI ; un seul message « silence » quand il se tait.
- Barre cachée : vérification toutes les 500 ms, aucune animation côté NUI.

Script d'affichage sans framework : pas de bridge (rien à notifier, pas d'argent, pas de job).

## Dépendances
Aucune (chat vocal Mumble / pma-voice pour que le micro soit détecté).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | debug, nom de la commande, cadences, débit simulé |
| `client/main.lua` | commande et boucle micro → NUI |
| `ui/` | affichage (inchangé) : texte, barre, animation |

## Commandes / touches
| Commande | Rôle |
|---|---|
| `/voice-ui` | affiche / cache la barre (nom réglable : `Config.Command`) |

## Messages NUI
| `action` | Rôle |
|---|---|
| `show` / `hide` | affiche / cache la barre |
| `voiceLevel` (volume 0 à 1) | niveau du micro |

## Relancer
`restart pop_voice_ui`
