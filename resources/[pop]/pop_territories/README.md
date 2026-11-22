# pop_territories

Guerre de territoires : chaque vente de drogue (pop_dealing) donne des parts de zone au crew du vendeur. Le crew qui dépasse le seuil contrôle la zone et vend plus cher.

## Fonctionnement
- Territoires internes (`Config.Zones` : centre + rayon), cercles sur la carte colorés à la couleur du crew qui contrôle.
- Chaque vente dans une zone de vente donne `Config.SharePerSale` % au crew du vendeur (un gain par joueur toutes les `Config.ShareCooldown` s). Parts stockées dans la table SQL `territory_shares`.
- À `Config.ControlThreshold` % le crew contrôle la zone : multiplicateur `Config.ControlMultiplier` sur ses ventes. Sinon multiplicateur de la zone (`multiplier` ou `Config.DefaultMultiplier`).
- Si un rival atteint `Config.WarThreshold` % dans une zone contrôlée : guerre (notifications aux deux crews, évènement `pop_territories:warStarted`).
- Menu pause : texte « Contrôlé par … / Disputé … » pour le territoire où se trouve le joueur.
- Guide à gauche (checklist NUI) tant que le joueur porte un `pochonweed` : étapes vente, part, contrôle.

## Dépendances
oxmysql, pop_crew (crews, couleurs, membres en ligne), pop_inventory (objet `pochonweed`), pop_notify (notifications), es_extended (via le bridge). Appelé par pop_dealing.

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | seuils, multiplicateurs, territoires, réglages techniques |
| `locales/fr.lua` | tous les textes |
| `shared/zones.lua` | zone d'une position (`Territories.getZoneAt`), partagé client/serveur |
| `client/main.lua` | cercles de carte, détection de zone, texte du menu pause |
| `client/checklist.lua` | guide NUI à gauche |
| `server/common.lua` | parts, contrôle, notifications, synchro (`Territories.*`) |
| `server/war.lua` | guerre des gangs, exports `endWar` / `isAtWar` / `getShares` / `getController` |
| `server/sales.lua` | exports `getZoneAt` et `recordDrugSale` (pop_dealing) |
| `server/main.lua` | chargement SQL, évènements pop_crew, callbacks, commande `/territory` |
| `html/checklist.html` | NUI du guide |
| `bridge/`, `shared/locale.lua`, `shared/callback.lua` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes
| Commande | Rôle |
|---|---|
| `/territory` | état du territoire où se trouve le joueur |

## Évènements, callbacks et exports
| Nom | Sens | Rôle |
|---|---|---|
| `pop_territories:requestControl` | client → serveur | demande l'état de toutes les zones |
| `pop_territories:controlSnapshot` | serveur → client | état de toutes les zones |
| `pop_territories:control` | serveur → clients | état d'une zone |
| `pop_territories:myProgress` | serveur → client | part du crew (guide) |
| `pop_territories:client:drugSold` | serveur → client | une vente vient d'être comptée |
| `pop_territories:zoneChanged` | client (local) | entrée / sortie de zone |
| `pop_territories:warStarted` / `warEnded` | serveur (local) | début / fin de guerre |
| `pop_territories:getMyShare` (Callback) | client → serveur | part du crew dans une zone |
| `pop_territories:hasWeed` (Callback) | client → serveur | le joueur porte un pochon |
| `pop_crew:disbanded` / `pop_crew:colorChanged` | écoutés | nettoyage / recoloration |
| `pop_dealing:notify` | écouté (client) | étape 2 du guide (« Vente activée ») |
| export `getZoneAt(x, y)` | serveur | `zoneId, label` |
| export `recordDrugSale(src, baseAmount)` | serveur | `finalAmount, info` |
| exports `endWar(zoneId, winner)`, `isAtWar(zoneId)`, `getShares(zoneId)`, `getController(zoneId)` | serveur | guerre et parts |

## Relancer
`restart pop_territories`
