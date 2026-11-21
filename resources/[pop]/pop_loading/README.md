# pop_loading

Écran de chargement du serveur, puis écran « Accéder au plateau de jeu » et transition caméra vers le joueur.

## Fonctionnement
- `loadscreen` : `html/index.html` s'affiche pendant le chargement (musique, images, barre de progression via `loadingscreen:saveData`). Fermeture manuelle (`loadscreen_manual_shutdown`).
- Dès `esx:playerLoaded` (+1 s), ou au plus tard 15 s après le démarrage du client, `vfw:loading:showJoinNUI` ferme l'écran natif et affiche l'écran « Accéder au plateau » (même page en `ui_page`, focus souris).
- Clic (`closeUI`, un seul pris en compte) : écran noir, caméra vers le ciel (`SwitchOutPlayer`), révélation des nuages, retour au joueur (`SwitchInPlayer`), puis `vfw:loading:playerClickedJoin` et `esx:loadingScreenOff`, joueur dégelé.
- Le joueur reste gelé jusqu'à la fin de la transition. Si `LocalPlayer.state.charcreatorOpen` est vrai (pop_charcreator), la caméra et le ped ne sont pas touchés.
- L'auto-spawn de spawnmanager est désactivé (le spawn reste celui d'ESX).

## Dépendances
Aucune obligatoire. Écoute `esx:playerLoaded` (ESX) ; utilisé avec pop_charcreator.

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | réglages communs POP (aucun réglage propre) |
| `locales/fr.lua` | clés communes (aucun texte côté Lua) |
| `client/main.lua` | écran « Accéder au plateau », transition, gel du joueur |
| `html/index.html` | page de chargement et écran « Accéder au plateau » (textes, styles, scripts) |
| `html/img/`, `html/music.mp3` | images (JPG/WebP) et musique (MP3 128 kbps) |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes / touches
Aucune commande. Dans la page : `M` coupe / remet la musique.

## Évènements
| Nom | Sens | Rôle |
|---|---|---|
| `loadingscreen:saveData` (name, value) | client (local) | transmet une donnée à la page |
| `vfw:loading:showJoinNUI` | client (local ou réseau) | affiche l'écran « Accéder au plateau » |
| `vfw:loading:playerClickedJoin` | émis en local | fin de la transition (écouté par pop_charcreator) |
| `esx:loadingScreenOff` | émis en local | réactive le HUD |
| `closeUI` (NUI) | page → client | clic sur « Accéder au plateau » |

## Relancer
Écran de chargement : se teste en se reconnectant (un `restart pop_loading` ne réaffiche pas l'écran).
