# pop_boards

Tableaux à peindre posés sur les murs, visibles par tous les joueurs (panneaux DUI).

## Fonctionnement
- `/board_add` (ou l'objet de pop_inventory qui déclenche `pop_boards:client:placement`) : un aperçu suit le regard. Molette = taille, flèches = largeur/hauteur, Entrée ou clic gauche = poser, Retour arrière = annuler.
- Zone « Peindre » sur chaque tableau : ouvre l'éditeur (NUI). Le dessin est envoyé au serveur par morceaux puis enregistré.
- Le panneau DUI n'existe qu'à moins de `Config.LoadDistance` m et est détruit au-delà de `Config.UnloadDistance` m (mémoire GPU). L'image est demandée au serveur à l'approche.
- Sécurité serveur : distance au tableau, `Config.MaxBoardsPerPlayer` tableaux par joueur (admins illimités), déplacement/redimensionnement réservés au propriétaire ou aux admins, images limitées au dessin (`data:image/…`) ou aux fichiers du script, délais anti-spam.

## Dépendances
oxmysql (table `pop_boards`, créée automatiquement), pop_duiengine (panneaux), ox_target ou qb-target (sinon prompt natif), pop_notify (facultatif).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | distances, taille par défaut, limites anti-abus |
| `locales/fr.lua` | tous les textes |
| `client/panels.lua` | état partagé (`Boards.*`), création/destruction des panneaux, zone « Peindre » |
| `client/editor.lua` | éditeur NUI, envoi du dessin |
| `client/placement.lua` | placement d'un tableau, `/board_add` |
| `client/sync.lua` | liste au démarrage, boucle de proximité, réception des images |
| `server/common.lua` | fonctions partagées (`Boards.*`) |
| `server/database.lua` | création de la table et de la colonne `owner` |
| `server/boards.lua` | pose, peinture, réception des morceaux |
| `server/sync.lua` | envoi des images à la demande, suppression (admins) |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes
| Commande | Rôle |
|---|---|
| `/board_add` | poser un tableau |

## Évènements et callbacks
| Nom | Sens | Rôle |
|---|---|---|
| `pop_boards:client:placement` | → client | lance le placement (utilisé par pop_inventory) |
| `pop_boards:getBoards` (Callback) | client → serveur | liste des tableaux (sans images) |
| `pop_boards:server:saveBoard` | client → serveur | pose ou peinture |
| `pop_boards:server:uploadChunk` | client → serveur | morceau du dessin |
| `pop_boards:server:requestData` | client → serveur | demande l'image d'un tableau proche |
| `pop_boards:server:deleteBoard` | client → serveur | suppression (admins) |
| `pop_boards:client:notifyUpdate` / `receiveMetadata` / `syncBoardUrlChunk` / `removeBoard` | serveur → client | synchronisation |

## Relancer
`restart pop_boards`
