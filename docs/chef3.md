# Notes du Chef 3

## Lot 3 (audit du 21/11/2026)

Scripts : pop_grandtheftauto, pma_voice_challenge, ultra-voltlab, kq_lasers (manifest), chHyperSound, interact-sound, pop_dealing, pop_weed, pop_crew, pop_territories, pop_bikerental, pop_voice_ui, pop_livraison, object_gizmo.

### Fait (publication 1)

**pop_grandtheftauto — mission faisable de bout en bout**
- Svetlana (docks) lance le casse : le serveur crée la mission, l'équipe = joueurs à 15 m (4 max), chacun reçoit 1 flipper + 1 module pirate s'il n'en a pas. Un joueur peut rejoindre l'équipe en lui parlant pendant le casse.
- GPS vers le showroom ; à 100 m le chef lance le casse (Thornton, voitures, lasers).
- Thornton : test vocal réparé (voir pma_voice_challenge). Délais max sur ses déplacements.
- Panneau électrique : flipper + ultra-voltlab (le rappel n'appelle plus Wait). Coupure de courant réelle (`SetArtificialLightsState`), minuteur 4 min (au lieu de 30 s affichées « 04:00 »).
- Clés : visibles seulement après le panneau, marqueur seulement à 30 m. Porte : anim native au lieu de `e mechanic4`.
- PCB : CircuitBreakerMinigame (absent) remplacé par ultra-voltlab ; le module pirate est consommé **par le serveur** à la réussite seulement.
- Livraison : seules les sportives piratées (plaque BEN validée serveur) sont acceptées derrière le camion ; récompense `Config.RewardPerCar` (15 000 $ en objet cash, banque en repli) ; emplacements de camion libérés.
- Fin de mission : toutes livrées, ou 5 min sans nouvelle voiture après la dernière livraison, ou 45 min, ou départ du chef. Reset complet chez tous les membres, entités supprimées par le serveur, cooldown 20 min.
- Sécurité : relais coop en liste blanche (équipe uniquement), plus de `heistStart` à tout le serveur, alertes police avec cooldown, véhicules suivis choisis par le serveur, `grandtheftauto:removeItem` retiré.
- Retiré : `/nightv` (touche N = push-to-talk, sautait Thornton), `/offnightv`, `/jouer`, `/andale`, `/dv100`, `/test_livraison`, `/voler_auto_dev`, commandes tapables `open1`, `opencapot`, `laseron`, `laseroff`, `removeblip1` (devenues des évènements internes). `/startheist` reste pour les admins (même chemin que Svetlana).
- Modèles : `turismoo` → turismo3 (repli turismor), `schweizer2` → repli schwarzer, `ig_valentina`/anim `amnilka` → repli vanilla. Tous les chargements ont un délai max.
- Lasers kq_lasers : appel corrigé (`exports['kq_lasers']:CreateLaser`), créés au lancement du casse et éteints hors casse.

**Autres**
- pma_voice_challenge / pop_voice_ui : `MumbleIsPlayerTalking(...) == 1` corrigé, plus de focus NUI (bloquait le push-to-talk), `/voice-ui` en double et `/spawn-thornton` retirés, `thornton.lua` (modèle inexistant) retiré.
- ultra-voltlab : état remis à zéro entre deux parties, ancien minuteur qui pouvait tuer la partie suivante, `/voltlab` retiré.
- kq_lasers : `/alarme`, `/stopalarm` retirés de config.lua (fichiers chiffrés non touchés).
- pop_territories : zones internes (centre + rayon) à la place de MapZones, +2 % par vente avec 60 s de délai par joueur.
- pop_dealing : PNJ seulement chez les joueurs concernés, alerte aux policiers seulement.
- pop_weed : l'eau compte, `HarvestAmount` respecté, 6 plantes max par joueur, props seulement à 80 m.
- pop_crew : tag et nom filtrés côté serveur.
- pop_bikerental : point de spawn décalé, `vehicle_keys` facultatif.
- pop_livraison : délais max de chargement, `/previewlivraison` réservé aux admins.
- interact-sound / chHyperSound : sons relayés limités (distance, volume, débit), relais client de chHyperSound coupé.

### Reste
- Tester la mission en jeu avec le client.
- `chHyperSound/sounds/` contient des fichiers privés (page Gmail, photos, zips) : à supprimer avec l'accord du client.
- `pop.cfg` : `add_ace resource.object_gizmo command.add_ace allow` inutile et risqué (Chef 1).

### Bugs connus / à vérifier en jeu
- Le test vocal de Thornton demande un micro (push-to-talk) ; en coop, seul le chef déclenche la scène.
- Coordonnées des nouvelles zones de territoire et du point de location vélo à vérifier.
- Si kq_lasers ne démarre pas (licence), la mission marche sans lasers.
