# pop_dealing

Vente de drogue façon Schedule 1 : des clients PNJ viennent acheter, le joueur glisse la marchandise sur eux et négocie le prix.

## Fonctionnement
- **Clients de zone** : dans chaque `Config.Zones`, jusqu'à `Config.MaxCustomersPerZone` clients. Ils ne sont créés que chez les joueurs à moins de `Config.CustomerStreamRange` m. Un client repère le joueur en zone qui porte la drogue et marche vers lui.
- **Mode vente** : utiliser un `pochonweed` (pop_inventory appelle l'export `toggleSelling`). Des clients immobiles avec un blip apparaissent autour du vendeur tant qu'il a de la drogue. Réutiliser le pochon arrête la vente.
- **Négociation** : glisser la drogue sur le client ouvre le menu (caméra sur le client). Le client accepte si le prix ≤ son prix max secret, sinon `Config.MaxAttempts` essais avant de partir.
- **Paiement** : objet `cash` de pop_inventory (`Config.CashItem`). Inventaire plein → marchandise rendue, deal annulé.
- **Territoires** : le prix final passe par `pop_territories:recordDrugSale` (multiplicateur de zone, parts du crew).
- **Flic infiltré** (`Config.BustChance`) : si le deal est accepté, « PIÈGE ! » et alerte aux joueurs des `Config.PoliceJobs` dans `Config.BustAlertRadius`.

## Dépendances
es_extended (via le bridge), ox_lib (modèles, animations, `cache.ped`), pop_inventory (drogue, cash, glisser-déposer), pop_notify (notifications), pop_v3dui (HUD 3D « GLISSER »), pop_territories (multiplicateur, facultatif).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | zones, drogues, prix, mode vente, durées, caméra |
| `locales/fr.lua` | tous les textes Lua (la NUI garde ses textes dans `html/`) |
| `client/common.lua` | état partagé et helpers (`Dealing.*`) |
| `client/camera.lua` | caméra de négociation |
| `client/offer.lua` | menu d'offre NUI, résultats, notifications |
| `client/customers.lua` | PNJ : spawn, glisser-déposer, sync, IA, HUD 3D |
| `server/common.lua` | fonctions partagées (`Dealing.*`) |
| `server/customers.lua` | clients de zone : spawn, streaming, sync |
| `server/selling.lua` | mode vente, export `toggleSelling`, déconnexion |
| `server/deals.lua` | claim, proposition, refus |
| `server/commands.lua` | commandes admin |
| `html/` | NUI de négociation |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes (ACE `pop.admin`)
| Commande | Rôle |
|---|---|
| `/dealing_spawn` | client juste devant soi |
| `/dealing_list` | liste des clients actifs (chat ou console) |
| `/dealing_clear` | supprime tous les clients |

## Évènements et exports
| Nom | Sens | Rôle |
|---|---|---|
| `pop_dealing:requestSync` / `pop_dealing:syncAll` | client ↔ serveur | clients existants à la connexion |
| `pop_dealing:spawnCustomer` / `pop_dealing:removeCustomer` | serveur → client | création / départ d'un PNJ |
| `pop_dealing:claim` / `pop_dealing:unclaim` | client → serveur | verrouille un client |
| `pop_dealing:offerDetails` | serveur → client | ouvre le menu d'offre |
| `pop_dealing:propose` / `pop_dealing:proposeResult` | client ↔ serveur | proposition de prix |
| `pop_dealing:refuse` | client → serveur | le client s'en va |
| `pop_dealing:dealComplete` / `pop_dealing:bust` | serveur → client | fin du deal |
| `pop_dealing:dispatchAlert` | serveur → police | alerte de deal suspect |
| `pop_dealing:notify` | serveur → client | notification (écouté aussi par pop_territories) |
| export `toggleSelling(src)` | serveur | active / coupe le mode vente (pop_inventory) |

## Relancer
`restart pop_dealing` (après `restart pop_territories` si les deux sont relancés)
