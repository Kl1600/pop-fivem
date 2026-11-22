# pop_affiche

Affiches posées sur les murs avec un lien d'image (http/https), réservées aux joueurs VIP.

## Fonctionnement
- `/affiche_add` (VIP) : un aperçu suit le regard. Molette = taille, flèches = largeur/hauteur, Entrée ou clic gauche = poser, Retour arrière = annuler. Une fenêtre demande ensuite le lien de l'image.
- Zone sur chaque affiche : **Modifier l'affiche** (nouveau lien) et **Supprimer l'affiche** (confirmation ox_lib), VIP seulement.
- Le panneau DUI n'existe qu'à moins de `Config.LoadDistance` m et est détruit au-delà de `Config.UnloadDistance` m (mémoire GPU).
- Sécurité serveur : statut VIP vérifié à chaque action, lien http(s) sans caractère dangereux, distance à l'affiche, délai entre deux actions.

## Dépendances
es_extended (groupe du joueur pour le statut VIP), oxmysql (table `pop_affiche`, créée automatiquement), ox_lib (fenêtre de confirmation, notifications d'erreur), pop_duiengine (panneaux), ox_target ou qb-target (sinon prompt natif), pop_notify (facultatif).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | groupes VIP, distances, taille par défaut, délai |
| `locales/fr.lua` | tous les textes |
| `client/panels.lua` | état partagé (`Affiche.*`), panneaux, zones, synchronisation, chargement initial |
| `client/editor.lua` | fenêtre de saisie du lien (NUI) |
| `client/placement.lua` | pose d'une affiche, `/affiche_add` |
| `server/common.lua` | fonctions partagées (`Affiche.*`), statut VIP |
| `server/database.lua` | création de la table et de la colonne `image_url` |
| `server/affiches.lua` | liste, pose, modification, suppression |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes
| Commande | Rôle |
|---|---|
| `/affiche_add` | poser une affiche (VIP) |

## Évènements et callbacks
| Nom | Sens | Rôle |
|---|---|---|
| `pop_affiche:isVIP` (Callback) | client → serveur | statut VIP du joueur |
| `pop_affiche:getAffiches` (Callback) | client → serveur | liste des affiches |
| `pop_affiche:server:saveAffiche` | client → serveur | pose ou nouveau lien |
| `pop_affiche:server:deleteAffiche` | client → serveur | suppression |
| `pop_affiche:client:placement` | → client | lance la pose |
| `pop_affiche:client:notifyUpdate` / `removeAffiche` | serveur → client | synchronisation |

## Relancer
`restart pop_affiche`
