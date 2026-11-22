# pop_grandtheftauto

Casse de la concession Benefactor (Vinewood ouest) : une équipe vole des sportives du showroom et les livre aux docks.

## Fonctionnement

1. **Svetlana** (docks) : [E] PARLER. Le serveur crée la mission ; les joueurs à 15 m font partie de l'équipe (4 max) et reçoivent 1 flipper + 1 module pirate s'ils n'en ont pas (une fois par période de cooldown). Un joueur peut rejoindre l'équipe en lui parlant tant que le casse n'a pas commencé.
2. **GPS vers le showroom.** À 100 m, le chef lance le casse : Thornton, voitures du showroom, voiture de démo, portes fermées, lasers allumés.
3. **Thornton** : le chef s'approche, la caméra zoome et il faut parler au micro (pma_voice_challenge). Sans micro, Thornton accepte au 3e essai. Il ouvre le capot de la démo puis part dans sa voiture.
4. **Panneau électrique** : [E] PIRATER avec un flipper → mini-jeu ultra-voltlab. Réussi : coupure de courant, portes ouvertes, lasers éteints, minuteur de 4 min, blip des clés.
5. **Clés** puis **porte de garage** ([E] RAMASSER, [E] OUVRIR).
6. **Module pirate** sur une voiture (glisser-déposer depuis l'inventaire, utiliser l'objet ou `/voler_auto`) : placement du module à la souris, [E] FIXER LE MODULE → mini-jeu. Le serveur vérifie la voiture et consomme le pcb à la réussite, puis déverrouille la voiture. Alerte police + suivi GPS des voitures pendant 100 s.
7. **Livraison** : GPS vers les docks, un camion apparaît ; reculer la voiture dans le camion. Le serveur vérifie la voiture et paie `Config.RewardPerCar` en liquide (objet cash, banque en repli). Un coéquipier qui prend le volant d'une voiture piratée reçoit aussi le GPS et son camion.
8. **Fin** : toutes les voitures livrées, ou 5 min sans nouvelle voiture après la dernière livraison, ou 45 min, ou départ du chef. Le serveur supprime les entités, remet tout à zéro chez l'équipe ; nouveau casse possible après `Config.Cooldown`.

## Dépendances

`pma_voice_challenge`, `ultra-voltlab`, `clm_ProgressBar`, `chHyperSound`, `interact-sound`, `pop_inventory`, `pop_notify`, `pop_v3dui`. `kq_lasers` facultatif (la mission marche sans).

## Fichiers

| Fichier | Rôle |
|---|---|
| `config.lua` | réglages communs POP + positions, équipe, délais, récompense, voitures (`Cars`) |
| `locales/fr.lua` | tous les textes affichés |
| `bridge/`, `shared/` | copies du modèle POP (ne pas modifier) |
| `client/utils.lua` | synchro coop (`Relay`, `IsOwner`…), `CheckItem`, notifications, chargements, invites « E », coupure, minuteur, mini-jeu |
| `client/sync.lua` | réception des évènements serveur (départ, entités, relais, fin), blips police |
| `client/lasers.lua` | lasers kq_lasers |
| `client/scenario.lua` | Thornton et le test vocal |
| `client/doors.lua` | portes du showroom, voiture de démo, GPS de livraison |
| `client/spawn.lua` | voitures du showroom |
| `client/blips.lua` | blip du panneau, PNJ de décor |
| `client/interact.lua` | Svetlana, panneau électrique, clés, porte de garage, voiture de Thornton |
| `client/hack.lua` | piratage d'une voiture (verrou, caméra, mini-jeu, fin validée) |
| `client/pcb.lua` | `/voler_auto`, objet pcb, glisser-déposer, livraison du coéquipier |
| `client/delivery.lua` | camions de livraison |
| `server/common.lua` | état de la mission (`GTA`), outils, fin de mission, kit |
| `server/mission.lua` | Svetlana, départ, entités, relais coop (liste blanche), départ/délais |
| `server/police.lua` | alertes et suivi GPS police |
| `server/hack.lua` | verrous de piratage, fin du piratage (pcb consommé) |
| `server/delivery.lua` | camions, livraison payée, fin automatique |
| `server/items.lua` | callback `hasItem` (flipper/pcb), objet pcb utilisable |

## Commandes / touches

| Commande | Qui | Rôle |
|---|---|---|
| `/voler_auto` | tous | pose le module pirate sur la voiture Benefactor la plus proche (il faut un pcb) |
| `/startheist` | admin (`command.startheist` ou `pop.admin`) | lance un casse tout de suite (même chemin que Svetlana) |

Touche E : interactions. Mini-jeu : flèches + Entrée, Retour arrière pour abandonner. Placement du module : souris (clic gauche tourner, clic droit déplacer, molette avant/arrière), Échap/Retour arrière pour annuler.

## Évènements

| Évènement | Sens | Rôle |
|---|---|---|
| `mission:server:talkSvetlana` | client → serveur | parler à Svetlana |
| `mission:server:startHeist` | client → serveur | le chef est au showroom |
| `mission:server:relay` | client → serveur | action coop (liste blanche, équipe) |
| `mission:server:finalizeHack` | client → serveur | fin du piratage (plaque + netId) |
| `mission:server:delivered` | client → serveur | voiture livrée (netId + emplacement) |
| `mission:client:pending` / `heistStart` / `reset` | serveur → équipe | étapes de la mission |
| `grandtheftauto:usePCB` | serveur → client | objet pcb utilisé |
| `grandtheftauto:alarme` | kq_lasers → client | laser déclenché |

## Relancer

`restart pop_grandtheftauto` (une mission en cours est annulée proprement).
