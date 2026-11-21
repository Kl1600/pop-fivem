# pop_charcreator

Créateur de personnage : apparence (skinchanger), identité, lieu d'apparition et kit de départ.

## Fonctionnement
- À la connexion (`esx:playerLoaded`), le serveur ouvre le créateur si le personnage n'a pas de prénom en base. L'ouverture attend le clic « Accéder au plateau de jeu » de pop_loading (`vfw:loading:playerClickedJoin`).
- Pendant la création : joueur seul dans une instance (routing bucket `src + 1000`), caméra dédiée, pose figée, flag `LocalPlayer.state.charcreatorOpen` (lu par pop_inventory, pop_loading, pop_hud).
- Passage aux vêtements (pop_clothes) et aux tatouages puis retour au créateur (`pop_charcreator:reopen`).
- Validation : le serveur contrôle le skin (freemode seulement, valeurs bornées) et la tenue, refuse de réécrire un personnage déjà créé (sauf `/charcreator` admin), enregistre skin + identité, vide l'inventaire puis donne la tenue choisie, le portefeuille (500 cash, carte d'identité, passeport US ou MX) et le kit de départ (hotdog, bouteille).
- Lieux d'apparition : `Config.SpawnPoints` (Los Santos, Nuevo Paso).

## Dépendances
es_extended (globale ESX via `imports.lua`), oxmysql, skinchanger, pop_inventory, pop_idcard, pop_passport, pop_notify (notifications, facultatif).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | lieux d'apparition, mode 80s, taille, durée des notifications |
| `locales/fr.lua` | tous les textes |
| `client/camera.lua` | caméra du créateur (exports `CreateCamera`, `DestroyCamera`, `FocusOn`) |
| `client/creator.lua` | ouverture / fermeture, pose (`CharCreator.ApplyCreatorPose`), sortie vers le lieu choisi, ouverture auto |
| `client/appearance.lua` | callbacks NUI d'apparence, sexe, modèle, vêtements / tatouages |
| `server/common.lua` | état et contrôles partagés (`CharCreator.*` : `isValidSkin`, `isValidClothes`, `cleanText`) |
| `server/save.lua` | sauvegarde du personnage et kit de départ |
| `server/instance.lua` | instance, ouverture auto, commande admin |
| `html/` | interface (inchangée) |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes
| Commande | Rôle |
|---|---|
| `/charcreator` (admin ESX) | rouvre le créateur et autorise la réédition du personnage (sans redonner le kit) |

Touches dans le créateur : Q / E rotation, W / S zoom.

## Évènements et exports
| Nom | Sens | Rôle |
|---|---|---|
| `pop_charcreator:open` | serveur/client → client | ouvre le créateur |
| `pop_charcreator:reopen` | client (pop_clothes) → client | retour au créateur après vêtements / tatouages |
| `pop_charcreator:client:needCreator` | serveur → client | personnage sans prénom : ouverture au clic « Jouer » |
| `pop_charcreator:client:finishSuccess` | serveur → client | sauvegarde terminée |
| `pop_charcreator:save` | client → serveur | skin, identité, lieu, tenue |
| `pop_charcreator:server:enterInstance` / `exitInstance` | client → serveur | instance du créateur |
| `vfw:loading:playerClickedJoin` | pop_loading → client | clic « Accéder au plateau de jeu » |
| `ApplyCreatorPose` (export client) | | pose figée du créateur |
| `CreateCamera`, `DestroyCamera`, `FocusOn` (exports client) | | caméra |

## Relancer
`restart pop_charcreator`
