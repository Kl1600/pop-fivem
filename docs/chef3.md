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

### Fait (publication 2)
- chHyperSound : suppression, avec l'accord du client, des fichiers privés de `sounds/` (page Gmail sauvegardée, photos, vidéos .mp4, zips/rar). Vérifié par grep : aucun script ne les utilisait. Tous les .ogg et .mp3 sont gardés. Le déploiement (`mirror --delete`) les retire aussi du serveur.

### Gabarit POP (22/11/2026)
Restructuration selon `docs/gabarit-pop.md` (config.lua, locales/fr.lua, bridge/ + shared/ copiés du modèle, client/ et server/ découpés < 600 lignes, README.md), aucun changement visible en jeu. Un push par script.
- pop_bikerental, pop_voice_ui, pop_livraison : publiés. pop_voice_ui sans bridge (affichage seul, comme pop_notify). pop_bikerental garde `ESX.Game.SpawnVehicle` et `exports.ox_target:addLocalEntity` en direct (options `rent_` filtrées par ox_target). `/previewlivraison` via `Bridge.IsAdmin` (ACE pop.admin ou groupe admin ESX).
- pop_weed, pop_crew : publiés. `vg_crew_recruit` → `pop_crew_recruit` (plus aucun `vg_crew` dans le dépôt). pop_weed garde la license Cfx comme propriétaire des plantes (compatibilité plants.json).
- pop_territories, pop_dealing : publiés. Zones dans `pop_territories/shared/zones.lua` (fichier propre au script, à garder si `shared/` est recopié). pop_dealing garde l'évènement `pop_dealing:notify` (écouté par la checklist de pop_territories) ; les réponses console de `dealing_list` restent visibles.
- pop_grandtheftauto : restructuré (server/alert.lua découpé en common/mission/police/hack/delivery, crack.lua en hack.lua + pcb.lua, lasers à part, positions dans config.lua, 70 textes dans fr.lua). Audit de non-régression OK, publié. `/startheist` garde le contrôle ACE d'origine ; kit compté par licence. Callback interne `hasItem` à la place de `grandtheftauto:hasItem` (aucun autre script ne l'utilisait).

### Lasers maison (22/11/2026)
- kq_lasers (payant, licence absente : « You lack the required entitlement ») remplacé par nos lasers dans `pop_grandtheftauto/client/lasers.lua` : mêmes 23 segments, `DrawLine` rouge avec léger scintillement, dessin et détection seulement si actifs et à moins de 40 m du showroom (sinon veille `Wait(1000)`, boucle arrêtée quand les lasers sont éteints). Détection : distance pieds/bassin/tête – segment ≤ 0,25 m → `grandtheftauto:alarme` + 5 de dégâts, 10 s de délai. Mêmes évènements (startheist, mission:local:lasers, mission:local:reset, onResourceStop).
- `resources/[pop]/kq_lasers` supprimé (le déploiement le retire du serveur), exclusion retirée de lint.yml, mentions retirées de coordination-chefs.md, analyse-structure.md et gabarit-pop.md.

### Retours F8 du client (22/11/2026)
- pop_grandtheftauto : `/startheist` bloquée en mode production (commande client « restricted ») → `RegisterCommand(..., false)`, le serveur vérifie déjà l'ACE (`command.startheist` ou `pop.admin`). Suggestion de chat ajoutée.
- pop_crew : avertissement ox_target « Replacing existing target option 'pop_crew_recruit' » → option retirée (`removeGlobalPlayer`) avant d'être remise, et retirée à l'arrêt de la ressource.
- pop_grandtheftauto : au départ de la mission (Svetlana ou `/startheist`), point jaune « Showroom Benefactor » + itinéraire GPS ; retiré à 100 m du showroom, à la fin ou à l'arrêt.
- pop_grandtheftauto : test vocal « Inventez un mensonge » (pma_voice_challenge) retiré à la demande du client ; Thornton accepte directement après le plan caméra. pma_voice_challenge n'est plus une dépendance de la mission (ressource laissée dans le dépôt, plus utilisée).

### Guidage, piratage, Thornton (22/11/2026, retour du test en jeu)
Corrections :
- Thornton : `TaskGoStraightToCoord` (ligne droite dans les murs / portes gelées du showroom) → `TaskFollowNavMeshToCoord` ; s'il est bloqué plus de 8 s (30 s au total), il est placé au point d'arrivée avec un fondu. Aucune porte de pop_doorlock dans la zone (vérifié).
- Piratage : plus de focus NUI pendant le placement du module (la souris est lue par les contrôles du jeu) et `SetNuiFocusKeepInput(false)` à l'arrêt ; annulation par Échap ou Retour arrière, menu pause bloqué pendant le placement ; « DÉMARRER » reprend le verrou serveur avant le mini-jeu (avant, verrou expiré = refus sans fin) ; un refus du serveur à la fin du piratage rend le verrou ; la voiture attend le contrôle réseau avant d'être ouverte (le serveur la déverrouille aussi).
- Messages console derrière `Config.Debug` (client et serveur) : verrou pris/refusé/libéré, module placé, mini-jeu raté, fin du piratage acceptée/refusée avec la raison, entités du showroom enregistrées/refusées, livraison refusée avec la raison, camion prêt, Thornton bloqué.
- Guidage (nouveau `client/guide.lua`) : checklist pop_notify « Vol de voitures » (7 étapes), un seul point jaune avec itinéraire vers la prochaine destination, une notification courte par étape. Checklist et itinéraire retirés à la fin (après 6 s), à l'échec et au reset. Nouvel évènement serveur → équipe `mission:client:carDelivered`.

Parcours complet (déclencheur → ce que voit le joueur → ce qui le guide ensuite) :
1. **Rejoindre le showroom** — Svetlana [E] ou `/startheist` → kit flipper + pcb, notification « Rendez-vous au showroom », checklist affichée → point jaune « Showroom Benefactor » + itinéraire.
2. **Suivre M. Duggan** — à 100 m du showroom, le chef lance le casse (Thornton, voitures, portes, lasers) → étape 1 cochée, notification « Rejoignez M. Duggan » → point jaune + itinéraire vers Thornton (et son blip). À 4 m : dialogue, caméra, il marche vers la voiture de démo, ouvre le capot, repart.
3. **Couper le courant** — Thornton parti (`mission:setupBlips`) → étape 2 cochée, sous-titre « Piratez les verrous électriques », notification « Piratez le panneau électrique » → point jaune + itinéraire vers le panneau (+ marqueur rouge et [E] PIRATER à 10 m). Flipper + mini-jeu.
4. **Clés et garage** — panneau réussi → coupure, portes ouvertes, lasers éteints, minuteur 4 min, étape 3 cochée, notification « Récupérez les clés » → point jaune + itinéraire vers les clés (flèche verte, [E] RAMASSER) ; clés prises → notification « Ouvrez la porte du garage » → point jaune vers la porte ([E] OUVRIR).
5. **Pirater une voiture** — porte ouverte → étape 4 cochée, notification « Posez votre module pirate sur une sportive » → point jaune vers la sportive non piratée la plus proche (+ blips verts des 4 voitures). Module glissé sur la voiture / objet utilisé / `/voler_auto` → placement à la souris → [E] FIXER LE MODULE → mini-jeu → serveur valide (pcb consommé, voiture déverrouillée). En cas d'échec : « Revenez au véhicule pour le démarrer » → [E] DÉMARRER sur la voiture.
6. **Livrer au camion** — piratage réussi → étape 5 cochée chez toute l'équipe, notification « rendez-vous au point indiqué sur votre GPS » → point jaune « Livraison » + itinéraire (pirate, conducteur, et coéquipiers). À 150 m : camion → « Un camion vous attend… Reculez la voiture » → itinéraire vers le camion. Voiture reculée derrière le camion → paiement.
7. **Fin** — livraison → étape 6 cochée pour l'équipe, « Svetlana vous a payé… » ; « le casse se termine dans 5 min » si plus de voiture → fin : « Le casse est terminé », étape 7 cochée, checklist retirée après 6 s. Échec (45 min, chef parti) : message + checklist et itinéraire retirés tout de suite.

### Nouveau piratage (22/11/2026)
- Placement 3D à la souris supprimé. Nouveau déroulé : [E] « BRANCHER LE MODULE » près du capot → capot ouvert, 3 s d'animation (`Bridge.Progress`, annulable [X]) → fenêtre NUI « stop au bon moment » en bas au centre (style pop_notify : verre sombre flouté, TT Firs Neue, rond blanc, accent #5d90ec) : 3 manches, la zone rétrécit et le curseur accélère, manche ratée = on la recommence, 3 erreurs = `grandtheftauto:alarme`, module non consommé, nouvel essai après 20 s (vérifié aussi côté serveur : `mission:server:hackFailed` → refus `cooldown` du verrou). Réussite : même suite (finalizeHack serveur, pcb consommé, voiture déverrouillée, police, guidage livraison).
- Mini-jeu sans focus NUI : le jeu lit [E] et [Échap] (pas de focus bloqué). Le serveur reste seul juge (distance, plaque, mission, verrou, pcb).
- Panneau électrique : même mini-jeu (titre « Piratage du panneau ») à la place d'ultra-voltlab.
- `html/` : kit POP copié (`html/kit/`, nécessaire pour la barre `Bridge.Progress`) + fenêtre de piratage. `Config.AccentColor = '#5d90ec'`, réglages `Config.Hack`.
- ultra-voltlab plus utilisé : supprimé du dépôt (le déploiement le retire du serveur), retiré du manifest, de coordination-chefs.md et de gabarit-pop.md.

### pop_chat (22/11/2026, demande du client)
- Texte coupé à gauche (« STAFF] » au lieu de « [STAFF] ») : le chat FiveM de base décale la 1re ligne (`.multiline` : `text-indent` négatif) → annulé dans `html/chat_theme.css`.
- Saisie trop loin des messages : messages calés en bas de la fenêtre (le dernier juste au-dessus de la saisie), fenêtre 30vh, saisie 4 px dessous, même largeur que les cartes (414 px), hauteur fixe 30 px.

- pop_chat : icône de la saisie refaite (rond blanc 20 px comme les notifications, chevron dessiné en CSS et centré à la place de la flèche « ➤ » du chat de base).

- pop_chat : icône de la saisie centrée verticalement sur la barre (positionnée au milieu, quelle que soit la hauteur de la saisie).

### Chantier 5 langues + tous serveurs (25/11/2026)
- **pop_crew** (1.0.0) : textes du menu sortis de `html/app.js` vers `locales/` (NUI : message `locale` avec `GetLocaleTable()`, `data-i18n`, `T()`), en/es/de/ar ajoutés (ar en RTL vérifié : menu à gauche, textes à droite). Recrutement : ox_target, qb-target ou touche E selon ce qui est lancé (`client/recruit.lua` ; le bridge n'a pas de ciblage « tous les joueurs », signalé au Chef 1). `dependency 'oxmysql'`, `install/sql.sql`, README en + fr, accent `#5d90ec`, couleur par défaut d'un nouveau crew passée du rose (200,70,190) au bleu POP. Texte « utilise /crew disband » corrigé (cette sous-commande n'existe pas).

### Reste
- Tester la mission en jeu avec le client (après la restructuration).
- `pop.cfg` : `add_ace resource.object_gizmo command.add_ace allow` inutile et risqué (Chef 1).

### Bugs connus / à vérifier en jeu
- Le test vocal de Thornton demande un micro (push-to-talk) ; en coop, seul le chef déclenche la scène.
- Coordonnées des nouvelles zones de territoire et du point de location vélo à vérifier.
