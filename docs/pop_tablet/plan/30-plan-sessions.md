# POP Tablet · 30 · Plan de développement en sessions Claude Code

Version du 24/11/2026. Lecteur : le client (qui ne code pas) et Claude Code (qui fait tout). Sources : `specs/00-sommaire.md` et fiches 01 à 06 (363 fiches, dont 3 supprimées : 360 fiches actives), `tech/10-technique.md`, `design/20-design.md` et `design/maquette.html`, dépôt `pop-fivem` (`CLAUDE.md`, `docs/methode.md`, `.claude/agents/`).

**Principe** : construction en arbre. Base (S01 à S08) → branches Entreprises (S09 à S15), Sites (S23 à S27), Outils (S28, S29), Apps perso (S30, S31), Admin (S07, S22, S23, S27) → apps au bout : Police (S16 à S22), Gestion pro (S32 à S35), EMS, Mécano, Justice, Immobilier, Gang (S36 à S41), Navigateur et Annuaire (S26, S27) → finition et vente (S42 à S48). La V1 = l'arbre complet.

**Une session** = 1 à 4 h de Claude Code, se termine par un push sur `main` de code qui démarre sans erreur et par un test en jeu de 3 gestes. « 1 (longue) » = session qui remplit les 4 h. La nouvelle tablette **remplace** l'ancienne `resources/[pop]/pop_tablet` (retirée en S01, récupérable par git).

**Avant chaque test en jeu (toujours pareil)** : GitHub > Actions > « Deploy to test server » > Run workflow ; attendre la coche verte ; dans txAdmin, `restart pop_tablet` (ou redémarrer le serveur) ; se connecter. Puis faire les 3 gestes de la session et dire à Claude ce qui ne va pas, avec une capture si possible.

**Comment lancer une session** : ouvrir Claude Code sur le dépôt, copier-coller le prompt de la session (partie 4). Une session ne démarre que si toutes ses dépendances sont marquées « faite » dans `docs/pop_tablet-suivi.md`.

---

## 1. Tableau des sessions

Chaque fiche active apparaît dans exactement une ligne (vérifié par script, voir § 6). Durée en sessions.

| N° | Session | Objectif | Fiches couvertes | Dépend de | Durée | Test en jeu (3 gestes) | Critère de fin |
|---|---|---|---|---|---|---|---|
| S01 | Socle qui démarre | Retirer l'ancienne tablette et poser la nouvelle ressource vide : squelette, manifeste, config, contrôle des dépendances, 100 tables par migrations, outillage de tests et build NUI vide. | (2) BASE-MOT-17, BASE-MOT-19 | — | 1 | 1. Console txAdmin : ligne verte « [pop_tablet] ready » avec framework esx, aucune ligne rouge. 2. Si la console annonce d'anciennes tables : taper `pop_tablet_archive_legacy confirm` dans la console txAdmin, puis `restart pop_tablet`. 3. En jeu, `resmon 1` : pop_tablet à 0,00 ms. | La ressource démarre sans erreur sur le serveur ESX de test, les 100 tables existent, un 2e démarrage ne change rien, `scripts/verifier-pop-tablet.sh` est vert. |
| S02 | Moteur serveur et bridge | Construire le moteur commun : porte d'entrée unique et ses 13 contrôles, bridge ESX / QBCore / Qbox étendu, sauvegarde groupée, cache, limites, anti-spam, nettoyage des textes, images, journal, Discord, langues côté serveur, zéro boucle. | (13) BASE-MOT-01, BASE-MOT-02, BASE-MOT-03, BASE-MOT-04, BASE-MOT-05, BASE-MOT-06, BASE-MOT-07, BASE-MOT-08, BASE-MOT-11, BASE-MOT-12, BASE-MOT-13, BASE-MOT-16, BASE-MOT-18 | S01 | 1 (longue) | 1. En jeu (admin) : `/tablette_debug` → affiche « Framework : esx », l'inventaire et la cible détectés, « Fils actifs : 0 ». 2. Changer son métier avec la commande admin habituelle du serveur, puis `/tablette_debug` → nouveau métier affiché. 3. `resmon 1` : pop_tablet à 0,00 ms côté client et serveur. | Tests unitaires sanitize, schema, ratelimit, idem, gateway, writequeue, timers, i18n et bridge verts sur les 3 profils ; aucune boucle ; démarrage sans erreur. |
| S03 | Objet, coque NUI et kit de style | Ouvrir la vraie tablette en jeu : objet utilisable, animation, numéro de série, raccourci, mode sans métadonnées, fermeture forcée, écran Bienvenue, kit de style et les 6 états d'écran. | (10) BASE-OBJ-01, BASE-OBJ-02, BASE-OBJ-03, BASE-OBJ-13, BASE-OBJ-14, BASE-OBJ-15, BASE-OBJ-16, BASE-OBJ-17, BASE-MOT-09, BASE-MOT-10 | S02 | 1 | 1. Se donner l'objet `pop_tablet` avec la commande habituelle du serveur, l'utiliser → animation, la tablette s'ouvre sur « Bienvenue » avec son numéro PT-XXXX-XXXX. 2. Échap → elle se ferme en fondu ; F9 → elle se rouvre. 3. Tablette ouverte, entrer dans l'eau → elle se ferme toute seule. | Ouverture / fermeture fluides, série stable sur la même tablette, e2e shell, states, static, lazy et leaks verts, 0 fil client tablette fermée. |
| S04 | Verrou, bureau, barre du haut, notifications | Rendre la tablette utilisable au quotidien : code de verrouillage et blocage, bureau d'icônes rangeable, barre du haut, bandeau de notification et historique. | (9) BASE-OBJ-04, BASE-OBJ-05, BASE-OBJ-06, BASE-OBJ-07, BASE-ECR-01, BASE-ECR-02, BASE-ECR-03, BASE-ECR-04, BASE-ECR-05 | S03 | 1 | 1. Créer un code à 4 chiffres, fermer puis rouvrir → le code est demandé. 2. Taper 5 fois un faux code → « bloquée 5 minutes », secousse à chaque erreur. 3. Appui long sur une icône et la déplacer ; `/tablette_debug notif` → bandeau puis ligne dans la cloche. | Code haché côté serveur (jamais renvoyé), blocage 5 min tenu même après reconnexion, ordre des icônes gardé, notifications gardées 7 jours / 50 max. |
| S05 | Batterie, réseau, tablette posée | Ajouter la vie de l'objet : batterie qui baisse à l'usage, recharge en véhicule et au chargeur, zones sans réseau, tablette posée que d'autres regardent. | (8) BASE-ECR-06, BASE-ECR-07, BASE-ECR-08, BASE-ECR-09, BASE-ECR-17, BASE-OBJ-10, BASE-OBJ-11, BASE-OBJ-12 | S04 | 1 | 1. `/tablette_debug battery 5` puis garder la tablette ouverte → icône orange puis écran « Batterie vide ». 2. Monter dans une voiture → icône de recharge ; utiliser `pop_tablet_charger` → barre de 10 s. 3. Bouton « Poser » → la tablette est posée devant soi ; s'éloigner de plus de 30 m → elle revient dans l'inventaire. | Batterie calculée par le temps serveur (jamais une valeur client), aucune boucle hors véhicule + tablette ouverte, tablette posée retirée proprement. |
| S06 | Réglages, langues, fenêtre simple, assistant | Livrer l'app Réglages (fond, accent, luminosité, taille du texte, langue, son), la fenêtre simple pour les joueurs sans tablette et l'assistant de premier démarrage de l'admin. | (9) BASE-ECR-10, BASE-ECR-11, BASE-ECR-12, BASE-ECR-13, BASE-ECR-14, BASE-ECR-15, BASE-ECR-16, BASE-MOT-14, BASE-MOT-15 | S04 | 1 | 1. Réglages → changer le fond, la couleur d'accent et la taille du texte → appliqué tout de suite, gardé après reconnexion. 2. Langue → English puis العربية → interface traduite, puis inversée de droite à gauche. 3. `/tablette_setup` (admin) → assistant pas à pas ; `/tablette_debug doc` sur un joueur sans tablette → fenêtre simple (touche Y). | Réglages attachés au numéro de série, RTL correct sur le shell (e2e rtl.spec en fr, de, ar, th), assistant qui détecte framework, inventaire, banque et Justice. |
| S07 | Panneau Admin (socle) | Donner à l'admin son panneau : accès, couper une app, liste des tablettes, réinitialiser, débloquer, donner une tablette, journal et Discord, limites, performance, et les exports de réinitialisation / remplacement. | (12) BASE-OBJ-08, BASE-OBJ-09, ADM-01, ADM-02, ADM-03, ADM-04, ADM-05, ADM-06, ADM-07, ADM-08, ADM-11, ADM-14 | S04 | 1 | 1. `/tablette_admin` → panneau Admin. 2. Admin > Tablettes → retrouver sa tablette par son numéro, la réinitialiser → plus de code au prochain démarrage. 3. `/tablette_donner [son id]` → nouvelle tablette dans l'inventaire ; Admin > Journal → ces actions sont listées. | Toutes les actions admin revérifient l'ACE `pop.tablet.admin` à chaque appel et sont journalisées ; exports `ResetTablet`, `ReplaceTablet`, `TransferTabletData` testés. |
| S08 | API pour développeurs | Ouvrir l'API publique de la base : enregistrer une app, ouvrir un écran, notifier, lire le joueur, stocker des données, payer via le serveur ; ressource de test pour la vérifier en jeu. | (6) BASE-API-02, BASE-API-03, BASE-API-04, BASE-API-05, BASE-API-06, BASE-API-07 | S04 | 1 | 1. `/devtest_app` → une icône « Test » apparaît sur le bureau. 2. L'ouvrir puis bouton « Notifier » → bandeau de notification. 3. Bouton « Payer 10 $ » cliqué deux fois très vite → 10 $ retirés une seule fois. | Exports de BASE-API-02 à 07 documentés dans `docs/api.md` (brouillon), paiement idempotent testé sous double requête, base jouable de bout en bout. |
| S09 | Entreprises, service et droits | Poser la colonne vertébrale des métiers : table des entreprises et 7 entreprises par défaut reliées aux métiers, prise / fin de service unique, droits par grade réglables par le Patron. | (10) SITE-CRE-01, SITE-CRE-02, SITE-CRE-03, SITE-CRE-12, ENT-GES-01, ENT-GES-02, ENT-GES-03, ENT-GES-04, ENT-GES-18, ENT-GES-19 | S04 | 1 | 1. `/tablette_admin` > Entreprises → les 7 entreprises par défaut, « Police » reliée au métier police. 2. Avec le métier police : Gestion → « Prendre mon service » → barre du haut « En service ». 3. En Patron : Gestion > Droits → retirer une case à Recrue → une recrue voit le bouton grisé « Grade requis ». | Une seule table de service, state bag `popDuty`, métier jamais basculé, grille de droits du sommaire §3.7 appliquée et testée (`perm`), entreprises créées une seule fois. |
| S10 | Employés et grades | Gérer l'équipe : liste et fiche des employés, recrutement d'un joueur proche, promotion, rétrogradation, renvoi, démission, grades et salaires (création, renommage, suppression avec avertissement). | (13) ENT-GES-05, ENT-GES-06, ENT-GES-07, ENT-GES-08, ENT-GES-09, ENT-GES-10, ENT-GES-11, ENT-GES-12, ENT-GES-13, ENT-GES-14, ENT-GES-15, ENT-GES-16, ENT-GES-17 | S09 | 1 | 1. Recruter un joueur proche → il reçoit l'invitation et accepte → il apparaît dans la liste. 2. Le promouvoir puis le rétrograder → son grade change dans le framework. 3. Créer le grade « Stagiaire » et fixer son salaire → visible dans Grades et salaires. | Distance revérifiée par le serveur (3 m), « sous son grade » respecté pour le Chef, renumérotation avec avertissement, tout journalisé ; tests unitaires et e2e verts. |
| S11 | Compte d'entreprise et ventes | Brancher l'argent de l'entreprise : solde du compte société détecté, dépôt, retrait, historique des ventes par jour et par employé, prime à un employé. | (7) ENT-GES-20, ENT-GES-21, ENT-GES-22, ENT-GES-23, ENT-GES-24, ENT-GES-25, ENT-GES-26 | S10 | 1 | 1. Gestion > Compte → le solde est celui du compte société du serveur. 2. Déposer 100 $ puis retirer 50 $ → solde et historique à jour. 3. Verser une prime de 20 $ à un employé → il la reçoit, ligne dans l'historique. | Adaptateurs banque ESX, QBCore (2) et Qbox (2) écrits et testés par mocks, « Compte d'entreprise indisponible » sans système, aucune création ni perte d'argent sous double clic. |
| S12 | Factures : créer et payer | Faire et payer des factures : création avec lignes, choix d'un client proche, onglet Reçues, paiement sur tablette ou en fenêtre simple, refus, cas du joueur inconscient. | (7) ENT-FAC-01, ENT-FAC-02, ENT-FAC-03, ENT-FAC-04, ENT-FAC-05, ENT-FAC-06, ENT-FAC-07 | S09, S06 | 1 | 1. Factures > Nouvelle → choisir un joueur proche, 2 lignes → « Facture envoyée. » 2. Le joueur paie sur sa tablette → argent transféré une seule fois, même en double-cliquant. 3. Joueur sans tablette → fenêtre simple (touche Y) → payer ou refuser. | Totaux recalculés par le serveur, plafond Recrue 500 $ et 100 000 $ max, paiement unique sous double requête, facture d'un inconscient annulée après 60 min. |
| S13 | Factures : suivi, impayés et API | Suivre et régler les factures : liste, filtres, détail, annulation, part employé, relance, impayés (délai, majoration, transmission à la police), signal « facture payée » et création par l'API. | (13) ENT-FAC-08, ENT-FAC-09, ENT-FAC-10, ENT-FAC-11, ENT-FAC-12, ENT-FAC-13, ENT-FAC-14, ENT-FAC-15, ENT-FAC-16, ENT-FAC-17, ENT-FAC-18, ENT-FAC-19, BASE-API-09 | S12, S11 | 1 (longue) | 1. Factures > Suivi → filtrer « Impayées ». 2. Ouvrir une facture → la relancer puis l'annuler → statut et historique à jour. 3. `/devtest_facture` (création par l'API) puis payer → la ressource de test reçoit le signal « facture payée ». | Majoration unique 10 % appliquée à la lecture après le délai, part employé figée à la création, signaux `invoicePaid` et suivants émis côté serveur seulement. |
| S14 | Annonces et boîte Demandes | Publier des annonces (entreprise et toute la ville) et ouvrir la boîte Demandes : liste, détail, réception d'une demande. | (10) ENT-ANN-01, ENT-ANN-02, ENT-ANN-03, ENT-ANN-04, ENT-ANN-05, ENT-ANN-06, ENT-ANN-07, ENT-DEM-01, ENT-DEM-02, ENT-DEM-03 | S09 | 1 | 1. Annonces → publier une annonce, la modifier, la retirer. 2. En Patron : « Annonce à toute la ville » → bandeau chez tous les joueurs qui ont une tablette. 3. `/devtest_demande police` → la demande apparaît dans la boîte Demandes de la police. | Fréquences 30 min / 2 min respectées, expiration après 1 h sans minuterie permanente, 3 demandes ouvertes max par demandeur. |
| S15 | Demandes : traiter et suivre | Traiter les demandes de bout en bout : accepter avec GPS, assigner, refuser, clôturer, suivi et annulation par le demandeur, réglages de la boîte. | (6) ENT-DEM-04, ENT-DEM-05, ENT-DEM-06, ENT-DEM-07, ENT-DEM-08, ENT-DEM-09 | S14 | 1 | 1. Accepter une demande → point GPS posé sur la carte du jeu. 2. L'assigner à un employé → il reçoit une notification. 3. Côté demandeur : voir sa demande « Acceptée » puis l'annuler. | Droits `demandes.repondre` et `demandes.assigner` respectés, signaux `requestCreated` / `requestClosed`, tout journalisé. |
| S16 | Police 1 : service, effectifs, unités | Ouvrir le MDT : service, accueil avec recherche rapide, effectifs, statut en 1 clic, unités, matricule, annonces internes, heures de service. | (9) MET-POL-01, MET-POL-02, MET-POL-03, MET-POL-04, MET-POL-05, MET-POL-06, MET-POL-07, MET-POL-34, MET-POL-35 | S09 | 1 | 1. Ouvrir Police hors service → seul « Prendre mon service » est actif ; le prendre. 2. Passer « Occupé » en 1 clic, créer l'unité « ADAM-12 ». 3. En Chef : publier une annonce interne → les agents en service la reçoivent ; Heures → semaine affichée. | Chunk police chargé à la demande, état Hors service partout, effectifs mis à jour par push ciblé (jamais à tous les joueurs). |
| S17 | Police 2 : dispatch et alertes | Faire vivre le dispatch : appels en cours, prise d'appel avec GPS, clôture et historique, appel manuel / renfort, bouton de détresse, alertes des scripts tiers et adaptateurs ps-dispatch, cd_dispatch, core_dispatch, esx_service. | (8) MET-POL-08, MET-POL-09, MET-POL-10, MET-POL-11, MET-POL-12, MET-POL-13, BASE-API-10, BASE-API-11 | S16 | 1 | 1. `/devtest_alerte` (simule un script tiers qui appelle ps-dispatch) → l'appel arrive dans la liste. 2. Prendre l'appel → GPS ; le clôturer → il passe dans l'historique. 3. Bouton de détresse → tous les agents en service reçoivent l'alerte avec la position. | Format d'alerte unique (BASE-API-10, `title`, `priority`), adaptateurs chargés seulement si la vraie ressource est absente, coordonnées relues côté serveur, 3 / 10 s par joueur. |
| S18 | Police 3 : citoyens, véhicules, avis de recherche | Rechercher et consulter : citoyens (fiche, photo, notes, permis), véhicules (fiche, signalement de plaque, plainte écrite), avis de recherche interne et public. | (9) MET-POL-14, MET-POL-15, MET-POL-16, MET-POL-17, MET-POL-18, MET-POL-19, MET-POL-20, MET-POL-31, MET-POL-45 | S16 | 1 | 1. Rechercher un joueur par son nom → fiche citoyen ; ajouter une note. 2. Rechercher une plaque → fiche véhicule ; « Signaler la plaque ». 3. Publier un avis de recherche public → il apparaît sur la tablette d'un autre joueur. | Recherche à 300 ms / 2 caractères paginée, identifiants jamais exposés (refs opaques), aucun « volé » nulle part, avis public 24 h / 5 actifs max. |
| S19 | Police 4 : rapports, amendes, code pénal | Écrire et sanctionner : modèles de rapport, rapport lié (citoyens, véhicules, agents, preuves) et transmis à la justice, liste et archivage, amende à un joueur proche, suivi des amendes, code pénal (lecture et modification). | (7) MET-POL-21, MET-POL-22, MET-POL-23, MET-POL-24, MET-POL-25, MET-POL-32, MET-POL-33 | S18, S12 | 1 | 1. Rédiger un rapport lié à un citoyen et un véhicule → il apparaît dans la liste. 2. Amende à un joueur proche depuis le code pénal → il la paie sur sa tablette. 3. En Patron : modifier un article du code pénal → visible tout de suite. | Amende ≤ barème et ≤ 2 500 $ pour une Recrue (facture `kind = fine`), code pénal en cache invalidé à la modification, rapports archivés jamais supprimés. |
| S20 | Police 5 : casier, mandats, formation | Casier avec peine et signal « peine prononcée » (adaptateurs prison), historique et retrait, mandats (demande, validation par Chef ou juge, levée, expiration), parcours de formation et suivi des recrues. | (8) MET-POL-26, MET-POL-27, MET-POL-28, MET-POL-29, MET-POL-30, MET-POL-42, MET-POL-43, BASE-API-08 | S19 | 1 | 1. Ajouter au casier avec 5 mois de prison → casier mis à jour (et envoi en prison si un adaptateur est réglé). 2. Créer un mandat de perquisition → aucun juge en service → un Chef le valide, marqué « Validé sans juge ». 3. Formation : assigner une recrue à un formateur et valider une étape. | Peine ≤ 120 mois, mandat 7 jours / 2 prolongations, signal `sentencePronounced` au format unique, adaptateurs prison (esx_jail, qalle_jail, qb-prison, qbx_prison, rcore_prison) testés par mocks. |
| S21 | Police 6 : preuves, saisie, carte des crimes | Preuves (photo, objet, document) liées aux rapports avec cadre d'obtention, recevabilité et chaîne de possession, empreintes, casier à preuves physique optionnel, saisie d'une tablette de suspect, carte des crimes de la semaine. | (5) MET-POL-36, MET-POL-37, MET-POL-38, MET-POL-44, MET-POL-46 | S19 | 1 | 1. Créer une preuve photo (lien imgur) et la lier à un rapport → recevabilité affichée. 2. Saisir la tablette d'un suspect proche → elle apparaît dans « Saisies », contenu protégé par son code. 3. Ouvrir la carte des crimes de la semaine → les points des rapports apparaissent. | Recevabilité calculée par le serveur (« Irrecevable » sans mandat valide), chaîne de possession complète, casier physique désactivé par défaut et sans aucun fil quand il l'est. |
| S22 | Police 7 : caméras | Placer et gérer les caméras fixes (Admin), vue en direct par la police, caméra piéton d'un agent en service. | (5) MET-POL-39, MET-POL-40, MET-POL-41, ADM-12, ADM-13 | S16, S07 | 1 | 1. Admin > Caméras → placer une caméra à sa position et la tester. 2. Police (Chef) → Caméras → vue en direct, rotation, retour avec Échap. 3. Caméra piéton → voir ce que voit un autre agent en service à moins de 300 m. | Une seule table de caméras, fil client seulement pendant le visionnage, distances revérifiées par le serveur, exports `SetCameraOnline` / `AddCamera`. |
| S23 | Créateur d'entreprises | Créer et administrer ses entreprises : assistant en 3 étapes (identité, apps, grades), modifier, dupliquer, archiver / restaurer, exporter et importer en fichier. | (8) SITE-CRE-04, SITE-CRE-05, SITE-CRE-06, SITE-CRE-07, SITE-CRE-08, SITE-CRE-09, SITE-CRE-10, SITE-CRE-11 | S09, S07 | 1 | 1. Admin > Entreprises > Créer → 3 étapes → la nouvelle entreprise existe avec son métier. 2. La dupliquer puis l'archiver → elle disparaît des listes, restaurable. 3. Exporter une entreprise puis l'importer → copie identique. | Métiers et grades créés sur le framework et gardés (`company_grades.managed`), import en deux temps (ticket puis push), fichiers dans `data/exports` et `data/imports`. |
| S24 | Éditeur de site 1 : blocs et publication | Construire un site : adresse `.rp`, modèle, catalogue de blocs, ajouter / déplacer / modifier / supprimer un bloc, aperçu, publication, images autorisées, verrou d'édition. | (11) SITE-EDI-01, SITE-EDI-02, SITE-EDI-03, SITE-EDI-04, SITE-EDI-05, SITE-EDI-06, SITE-EDI-07, SITE-EDI-08, SITE-EDI-09, SITE-EDI-17, SITE-EDI-19 | S09 | 1 | 1. Éditeur de site → choisir l'adresse « garage.rp » et un modèle. 2. Ajouter 3 blocs, en déplacer un, modifier un texte → aperçu. 3. Publier → message de succès ; un deuxième employé qui ouvre l'éditeur voit « En cours de modification ». | Blocs validés par le serveur (64 Ko, 30 blocs / page), images seulement des domaines autorisés, un seul éditeur à la fois. |
| S25 | Éditeur de site 2 : pages, versions, visites | Compléter l'éditeur : pages (ajouter, renommer, réordonner, supprimer), historique et retour de version, visites, API de lecture neutre, formulaire de demande, réglages du site. | (10) SITE-EDI-10, SITE-EDI-11, SITE-EDI-12, SITE-EDI-13, SITE-EDI-14, SITE-EDI-15, SITE-EDI-16, SITE-EDI-18, SITE-EDI-20, SITE-EDI-21 | S24, S15 | 1 | 1. Ajouter une page « Tarifs » et la placer en 2e. 2. Historique → revenir à la version précédente. 3. Ajouter un bloc formulaire → l'envoyer → la demande arrive dans la boîte Demandes de l'entreprise. | 20 versions max, visites comptées sans écriture à chaque vue (file groupée), réglages type / description / caché / maintenance lus par l'API neutre. |
| S26 | Navigateur | Naviguer sur les sites de la ville : chargement page par page, barre d'adresse et suggestions, moteur de recherche fictif, sites par type, favoris, historique, 3 onglets, sites cachés, pages introuvable / maintenance, boutons de navigation. | (12) NAV-01, NAV-02, NAV-03, NAV-04, NAV-05, NAV-06, NAV-07, NAV-08, NAV-09, NAV-10, NAV-11, NAV-12 | S25 | 1 | 1. Navigateur → taper « garage.rp » → le site s'affiche. 2. Ajouter en favori, ouvrir un 2e onglet, faire Précédent / Suivant. 3. Taper une adresse qui n'existe pas → page « site introuvable ». | Une page envoyée à la fois depuis le cache serveur, favoris et historique attachés au numéro de série, contenu joueur affiché en texte seulement (xss.spec). |
| S27 | Annuaire et modération | Annuaire des entreprises (statut ouvert / fermé, fiche, lien vers le site, demande de contact) et modération (signaler, masquer, restaurer un site ou une annonce). | (8) ANNU-01, ANNU-02, ANNU-03, ANNU-04, ANNU-05, ADM-09, ADM-10, ADM-16 | S26, S15 | 1 | 1. Annuaire → la police apparaît « Ouvert » quand un agent est en service. 2. Fiche d'une entreprise → « Voir le site » puis « Demande de contact » → la demande arrive. 3. Signaler un site ; l'admin le masque puis le restaure. | Statut calculé depuis la seule table de service, masquage visible par l'admin seulement, signaux `siteHidden` / `siteRestored`, tout journalisé. |
| S28 | Notes et calculatrice | Livrer deux outils simples : Notes (liste, création, modification, recherche, épingler, supprimer, partager et recevoir) et Calculatrice (opérations, priorités, %, ±, erreurs, historique, clavier). | (16) OUT-NOT-01, OUT-NOT-02, OUT-NOT-03, OUT-NOT-04, OUT-NOT-05, OUT-NOT-06, OUT-NOT-07, OUT-NOT-08, OUT-CAL-01, OUT-CAL-02, OUT-CAL-03, OUT-CAL-04, OUT-CAL-05, OUT-CAL-06, OUT-CAL-07, OUT-CAL-08 | S04 | 1 | 1. Notes → créer une note, l'épingler, la retrouver par la recherche. 2. Partager la note avec un joueur proche → il la reçoit. 3. Calculatrice → 2 + 3 × 4 = 14 au clavier physique ; 1 ÷ 0 → message d'erreur. | Notes attachées au numéro de série, calculatrice 100 % NUI hors ligne avec tests unitaires du moteur. |
| S29 | Carte et galerie | Carte de la ville (points utiles, GPS en un clic, mes points, recherche) et Galerie (appareil photo, stockage sans exposer l'IP, grille et visionneuse, albums, suppression, envoi vers une app, image par lien, quota). | (13) OUT-CAR-01, OUT-CAR-02, OUT-CAR-03, OUT-CAR-04, OUT-CAR-05, OUT-GAL-01, OUT-GAL-02, OUT-GAL-03, OUT-GAL-04, OUT-GAL-05, OUT-GAL-06, OUT-GAL-07, OUT-GAL-08 | S04 | 1 (longue) | 1. Carte → cliquer un point utile → GPS posé. 2. Galerie → prendre une photo → elle apparaît dans la grille. 3. Envoyer la photo dans une note ou un rapport → elle s'y affiche (`media:<id>`). | Photos sur le disque du serveur (`data/photos`), envoi latent, cache images borné à 32 Mo serveur / 40 entrées NUI, fil client seulement en mode photo. |
| S30 | Apps perso : moteur | Permettre aux acheteurs d'ajouter leurs apps : dossier `apps_perso/` détecté, modèle vide, SDK `PopApp`, objet serveur `App` en environnement fermé, isolation des données, kit de style des apps perso. | (7) BASE-API-01, PERSO-01, PERSO-02, PERSO-04, PERSO-05, PERSO-06, PERSO-09 | S08 | 1 | 1. Copier `_modele` en `ma_app` (Claude le fait) puis `restart pop_tablet` → l'icône apparaît. 2. L'ouvrir → l'écran de l'app s'affiche dans le style de la tablette. 3. Bouton de l'app qui enregistre une valeur → valeur relue après fermeture. | Iframe `sandbox="allow-scripts"` sans `allow-same-origin`, appId pris de la table et jamais du message, `while true` coupé, e2e perso.spec vert. |
| S31 | Apps perso : guide IA, exemples, vérificateur | Rendre les apps perso faciles à créer avec une IA : guide `CLAUDE.md` livré, 3 apps d'exemple, outil de vérification `pop-check` (Node et Lua, même résultat). | (3) PERSO-03, PERSO-07, PERSO-08 | S30 | 1 | 1. Les 3 apps d'exemple (notes, tableau, pourboire) apparaissent sur le bureau. 2. Exemple pourboire → donner 5 $ à un joueur proche → reçu une seule fois. 3. Admin > Apps → couper une app d'exemple → elle disparaît du bureau. | `node tools/pop-check.js apps_perso` : 0 bloquant, 0 alerte ; parité Node / Lua sur les fixtures ; `pop_tablet/CLAUDE.md` ≤ 300 lignes, FR puis EN, sections de §8.6. |
| S32 | Tableur 1 : feuilles et formules | Tableur d'entreprise : liste des feuilles, création (vide ou modèle), modèles, cellules typées, gras et couleur, largeur des colonnes, formules, insertion / suppression de lignes et colonnes. | (8) PRO-TAB-01, PRO-TAB-02, PRO-TAB-03, PRO-TAB-04, PRO-TAB-05, PRO-TAB-06, PRO-TAB-07, PRO-TAB-15 | S09 | 1 | 1. Tableur → créer une feuille depuis un modèle. 2. Taper des montants puis `=SOMME(B2:B5)` → total correct. 3. Insérer une ligne au milieu → la formule s'ajuste. | Moteur de formules pur et testé (`formula.ts`), 200 × 26 par défaut, grille et formules en LTR même en arabe, chunk ≤ 80 Ko. |
| S33 | Tableur 2 : travail à plusieurs | Tableur partagé : import automatique (factures payées, mouvements du compte), droits par grade, verrou de cellule, modifications en direct, taille réglable, annuler / rétablir, renommer / dupliquer / archiver. | (7) PRO-TAB-08, PRO-TAB-09, PRO-TAB-10, PRO-TAB-11, PRO-TAB-12, PRO-TAB-13, PRO-TAB-14 | S32, S13 | 1 | 1. Deux employés ouvrent la même feuille → la saisie de l'un apparaît chez l'autre. 2. Activer l'import des factures payées → payer une facture → la ligne arrive dans la feuille. 3. Ctrl+Z / Ctrl+Y → annuler puis rétablir. | Push ciblé aux seuls lecteurs de la feuille, 20 / 5 s par cellule, verrou libéré à la fermeture, droits `tableur.*` respectés. |
| S34 | Stock | Stock d'entreprise : articles, archivage, entrées, sorties, inventaire, historique, déduction automatique par facture, alerte de seuil, lien avec le coffre de l'inventaire si possible. | (10) PRO-STO-01, PRO-STO-02, PRO-STO-03, PRO-STO-04, PRO-STO-05, PRO-STO-06, PRO-STO-07, PRO-STO-08, PRO-STO-09, PRO-STO-10 | S09, S13 | 1 | 1. Stock → créer l'article « Pneu » avec seuil 5. 2. Faire une entrée de 10 puis une sortie de 7 → alerte de seuil. 3. Activer la déduction par facture → une facture avec 2 pneus fait baisser le stock. | Stock jamais négatif (s'arrête à 0, manque noté et signalé), historique complet, lien coffre seulement si l'inventaire le permet. |
| S35 | Planning | Planning d'équipe : vue, horloge du mode heure du jeu, créneaux, affectations, disponibilités et absences, rappels, présence comparée aux prises de service. | (7) PRO-PLA-01, PRO-PLA-02, PRO-PLA-03, PRO-PLA-04, PRO-PLA-05, PRO-PLA-06, PRO-PLA-07 | S09 | 1 | 1. Planning → créer un créneau demain 20 h et y affecter un employé. 2. L'employé déclare une absence → visible sur le créneau. 3. Prendre son service pendant le créneau → présence affichée « À l'heure ». | Rappels par l'ordonnanceur unique (aucune minuterie quotidienne), présence lue dans la seule table de service (`debut` / `fin`). |
| S36 | EMS 1 : service, alertes, dossiers | App EMS : service et effectifs, alertes « joueur à terre », prise en charge avec GPS, dossier médical (lecture, écriture), rapport d'intervention et son modèle. | (8) MET-EMS-01, MET-EMS-02, MET-EMS-03, MET-EMS-04, MET-EMS-05, MET-EMS-06, MET-EMS-07, MET-EMS-08 | S17, S15 | 1 | 1. Prendre son service EMS. 2. Un joueur tombe à terre → alerte reçue → accepter → GPS. 3. Ouvrir son dossier médical, l'éditer, rédiger le rapport d'intervention. | Mort / réveil détectés par le bridge sans boucle (ESX, QBCore, Qbox par mocks), alerte au format DispatchAlert, `/secours` fonctionnel. |
| S37 | EMS 2 : soins, certificats, rendez-vous, tri | Facturer les soins et régler les tarifs, certificats d'aptitude et de décès (et révocation), heures de service, rendez-vous depuis le site de l'hôpital, tri des blessés partagé avec la police. | (9) MET-EMS-09, MET-EMS-10, MET-EMS-11, MET-EMS-12, MET-EMS-13, MET-EMS-14, MET-EMS-15, MET-EMS-16, MET-EMS-17 | S36, S12 | 1 | 1. Facturer des soins à un joueur proche depuis la grille des tarifs. 2. Délivrer un certificat d'aptitude port d'arme → visible par la police sur la fiche citoyen. 3. Ouvrir un afflux de blessés, ajouter un blessé « rouge » → la police le voit. | Tarifs depuis `defaults/price_lists.lua`, export `GetCertificate`, 3 afflux max / 60 victimes / fermeture auto 6 h par l'ordonnanceur. |
| S38 | Mécano et Carnet auto | App Mécano : service, dépannages par la boîte Demandes, diagnostic, carnet d'entretien simple, devis (création, réponse, facture en 1 clic), catalogue relié au stock, et app « Carnet auto » côté propriétaire. | (11) MET-MEC-01, MET-MEC-02, MET-MEC-03, MET-MEC-04, MET-MEC-05, MET-MEC-06, MET-MEC-07, MET-MEC-08, MET-MEC-09, MET-MEC-10, MET-MEC-11 | S15, S12, S34 | 1 (longue) | 1. Accepter un dépannage depuis Demandes → GPS ; diagnostiquer le véhicule proche. 2. Créer un devis → le client l'accepte → « Facturer » en 1 clic. 3. Côté propriétaire : app Carnet auto → l'entrée d'entretien est là. | Aucun drapeau « volé », carnet lisible par la police seulement si réglé, catalogue qui fait baisser le stock, adaptateurs essence (ox_fuel, LegacyFuel, cdn-fuel, ps-fuel, natif). |
| S39 | Justice 1 : affaires, audiences, verdicts | App Justice : service, ouverture d'une affaire, liaison des rapports et preuves de la police, consultation selon le rôle, audiences, verdict (casier + peine), validation des mandats. | (7) MET-JUS-01, MET-JUS-02, MET-JUS-03, MET-JUS-04, MET-JUS-05, MET-JUS-06, MET-JUS-07 | S20, S19 | 1 | 1. En procureur : ouvrir une affaire et y lier un rapport de police. 2. En juge : planifier une audience puis prononcer un verdict → casier du joueur mis à jour. 3. En juge : signer un mandat de perquisition demandé par la police. | Verdict unique par affaire, signal `sentencePronounced` partagé avec la police, rôles avocat / procureur / juge réglés par l'assistant (Tribunal, Cabinet). |
| S40 | Justice 2 et Immobilier | Avocats (clients, honoraires), effacement de casier, classement sans suite, contestation de preuve, accord de repenti ; cadastre et enregistrement des ventes immobilières. | (8) MET-JUS-08, MET-JUS-09, MET-JUS-10, MET-JUS-11, MET-JUS-12, MET-JUS-13, MET-IMM-01, MET-IMM-02 | S39, S21 | 1 | 1. En avocat : facturer des honoraires à un client. 2. Contester une preuve → le juge tranche → la preuve devient irrecevable. 3. Immobilier : créer un bien, enregistrer une vente par un vendeur qui n'est pas le propriétaire → alerte. | Réduction de repenti 10 à 75 %, effacement = archivage, exports `GetPropertyOwner` / `GetPropertiesOf`. |
| S41 | Gang et infiltration | App Gang déguisée : membres et rangs, recrutement, exclusion, messagerie jamais effacée, coffre d'argent sale, territoires, icône déguisée et ouverture par code, livre de comptes ; infiltration de la messagerie par la police sous mandat signé. | (11) MET-GANG-01, MET-GANG-02, MET-GANG-03, MET-GANG-04, MET-GANG-06, MET-GANG-07, MET-GANG-08, MET-GANG-09, MET-GANG-10, MET-GANG-11, MET-POL-47 | S20, S39, S09 | 1 (longue) | 1. L'app Gang apparaît comme « Météo » ; appui long sur le champ caché + code → l'app s'ouvre. 2. Déposer 1 000 $ d'argent sale au coffre puis en retirer 500 $ (Lieutenant). 3. Police : mandat d'infiltration signé par un juge → la police lit les messages à partir de la signature. | Argent sale par framework (`black_money` ou `markedbills`), plafond 10 000 $ par retrait et 3 / 24 h, messages jamais purgés, lecture d'infiltration seulement après signature. |
| S42 | Traductions des 10 langues | Traduire toutes les clés dans les 10 langues de sortie (en, pt-BR, fr, ar, de, th, tr, es, id, ro) et valider l'arabe (RTL) et le thaï sur tous les écrans. | — (aucune nouvelle fiche) | S40, S41 | 1 | 1. Réglages → Deutsch → les écrans longs (Police, Factures) ne débordent pas. 2. Réglages → العربية → tout est inversé, montants et plaques restent lisibles. 3. Réglages → ไทย → aucun carré vide à la place des lettres. | `locales.lua` : 0 clé manquante dans les 10 langues ; e2e rtl.spec sur un écran par app en fr, de, ar, th ; aucun texte en dur. |
| S43 | Recette complète sur ESX | Passer la grille de recette complète sur le serveur ESX de test (fiches, deux joueurs, triche, performance, adaptateurs) et corriger tout ce qui casse. | — (aucune nouvelle fiche) | S42 | 1 (longue) | 1. Suivre la check-list `docs/pop_tablet-recette.md` générée (une case par critère) : le client coche ce qu'il voit. 2. `resmon 1` après 50 ouvertures / fermetures → 0,00 ms tablette fermée. 3. `/devtest_triche` → toutes les attaques sont refusées et apparaissent dans Admin > Journal. | Grille ESX entièrement verte, ressource de triche 100 % refusée, mesure resmon notée dans le suivi. |
| S44 | Recette sur QBCore | Passer la même grille sur un serveur QBCore (qb-inventory, qb-target, qb-banking / qb-management, qb-prison) et corriger les écarts dans le bridge seulement. | — (aucune nouvelle fiche) | S43 | 1 | 1. Ouvrir la tablette sur le serveur QBCore → bureau et entreprises par défaut reliées. 2. Facture, service et compte d'entreprise → même résultat que sur ESX. 3. Mort puis réveil d'un joueur → alerte EMS une seule fois. | Grille QBCore verte avec les mêmes critères qu'ESX ; tous les correctifs dans `bridge/` ; mocks QBCore mis à jour. |
| S45 | Recette sur Qbox | Passer la même grille sur un serveur Qbox (ox_inventory, ox_target, Renewed-Banking, qbx_medical, qbx_vehicles) et corriger les écarts dans le bridge seulement. | — (aucune nouvelle fiche) | S43 | 1 | 1. Ouvrir la tablette sur le serveur Qbox → bureau et entreprises par défaut reliées. 2. Compte d'entreprise via Renewed-Banking → dépôt / retrait corrects. 3. Gang : coffre d'argent sale avec `markedbills` → montant juste. | Grille Qbox verte ; valeurs du sommaire §5 (state bag `isDead`, prison Qbox, colonnes `player_vehicles`) vérifiées et corrigées dans leur seul fichier d'adaptateur. |
| S46 | Audit final et couverture stricte | Audit complet par l'agent `fivem-auditeur` (sécurité, performance, cohérence, langues, simplicité) avec des sous-agents par branche, corrections, et couverture stricte des 360 fiches. | — (aucune nouvelle fiche) | S44, S45 | 1 (longue) | 1. Rouvrir 5 apps au hasard → rien de cassé après les corrections. 2. Admin > Performance → aucune action au-dessus de 5 ms en moyenne. 3. `resmon 1` tablette fermée → 0,00 ms. | Rapport d'audit sans point CRITIQUE ni IMPORTANT ouvert, `coverage.lua --strict` vert (360 IDs), `verifier-pop-tablet.sh` vert. |
| S47 | Livraison Tebex : escrow, docs, guide IA | Préparer le paquet vendu : manifeste escrow, script de release (zip), documentation acheteur (installation 5 minutes, mise à jour, API, adaptateurs, kit de style), README, guide IA final. | — (aucune nouvelle fiche) | S46 | 1 | 1. Le client télécharge le zip produit (artefact) et l'ouvre : dossiers `config.lua`, `docs/`, `apps_perso/` visibles. 2. Installer le zip sur un serveur propre en suivant `docs/installation.md` → ressource prête en 5 minutes. 3. Demander à une IA de créer une app perso avec le `CLAUDE.md` livré → elle passe `pop-check`. | `scripts/release-tablette.sh` produit un zip sans `ui/`, `tests/`, devtest ni secret ; fichiers ouverts conformes à §1.2 (`escrow_ignore`) ; docs relues. |
| S48 | Page de vente Tebex | Écrire la page de vente (FR et EN), la liste des fonctions par branche, la comparaison honnête, les captures et la vidéo à tourner, et la check-list de mise en ligne Tebex. | — (aucune nouvelle fiche) | S47 | 1 | 1. Lire `docs/pop_tablet-vente.md` : le texte est clair pour un admin de serveur. 2. Vérifier les captures proposées (une par branche) sur le serveur de test. 3. Suivre la check-list de mise en ligne Tebex jusqu'au bouton « Publier » (le client publie lui-même). | Page de vente FR / EN prête à coller, captures réelles, aucune promesse non vérifiée (perf mesurée en session 43, frameworks testés en 44 / 45). |

Récapitulatif par branche :

| Branche | Sessions | Fiches |
|---|---|---|
| Base (01) | S01, S02, S03, S04, S05, S06, S07, S08 (8) | 69 |
| Entreprises (02 + entreprises 05) | S09, S10, S11, S12, S13, S14, S15 (7) | 66 |
| Police (03) | S16, S17, S18, S19, S20, S21, S22 (7) | 51 |
| Sites, navigateur, annuaire, modération (05, 06) | S23, S24, S25, S26, S27 (5) | 49 |
| Outils (06) | S28, S29 (2) | 29 |
| Apps perso (05) | S30, S31 (2) | 10 |
| Gestion pro (06) | S32, S33, S34, S35 (4) | 32 |
| EMS, Mécano, Justice, Immobilier, Gang (04) | S36, S37, S38, S39, S40, S41 (6) | 54 |
| Finition et vente | S42, S43, S44, S45, S46, S47, S48 (7) | 0 |
| **Total** | **48 sessions** | **360 fiches actives** |

---

## 2. Parallélisme et chemin critique

Toutes les sessions écrivent dans des dossiers séparés (`server/apps/<app>/`, `ui/pop_tablet/src/apps/<app>/`, `locales/<langue>/<app>.json`) et le schéma des 100 tables est posé en entier dès S01 : deux branches peuvent avancer en même temps sans se marcher dessus. Points de friction prévus et désamorcés : `config.lua` (une section par app créée en S01), `registry.ts` (une ligne par app préparée en S03), `fiches_faites.txt` et `docs/pop_tablet-suivi.md` (ajouts de lignes, fusion simple).

**Mode de travail en parallèle** : une branche Git (ou un worktree) par session, nommée `session-NN-nom` ; la session fusionne dans `main` seulement après `verifier-pop-tablet.sh` vert sur `main` à jour. Le client déploie et teste une session à la fois (dans l'ordre des fusions).

| Groupe | Sessions | Remarque |
|---|---|---|
| Tronc (séquentiel) | S01 → S02 → S03 → S04 | Chaque session construit ce que la suivante utilise ; une seule équipe. |
| Base, fin | S05, S06, S07, S08 | Indépendantes entre elles après S04 : jusqu'à 4 agents en parallèle (fichiers et apps différents). |
| Outils | S28, S29 | Ne dépendent que de S04 : peuvent démarrer dès la fin de S04, en parallèle de tout le reste. |
| Entreprises | S09 → S10 → S11 ; S09 → S12 → S13 ; S09 → S14 → S15 | Trois fils après S09 (employés et compte / factures / annonces et demandes). S13 attend S11 et S12. |
| Police | S16 → (S17, S18, S22) ; S18 + S12 → S19 → (S20, S21) | Dès S09 ; S17, S18 et S22 en parallèle ; S20 et S21 en parallèle. |
| Sites | S23 ; S24 → S25 → S26 → S27 | S23 et S24 dès S09 ; S25 attend aussi S15 ; S27 attend S26. |
| Apps perso | S30 → S31 | Dès S08, totalement indépendant des métiers. |
| Gestion pro | S32 → S33 ; S34 ; S35 | S32 et S35 dès S09 ; S33 et S34 attendent S13 (factures). |
| Métiers | S36 → S37 ; S38 ; S39 → S40 ; S41 | EMS dès S17 + S15 ; Mécano dès S34 ; Justice dès S20 ; Gang dès S20 + S39. |
| Finition | S42 → S43 → (S44, S45) → S46 → S47 → S48 | S44 et S45 en parallèle (deux serveurs de test). S42 peut commencer langue par langue dès que les textes d'une branche sont stables. |

**Chemin critique** (la plus longue chaîne de dépendances, 17 sessions) : S01 → S02 → S03 → S04 → S09 → S16 → S18 → S19 → S20 → S39 → S40 → S42 → S43 → S44 (ou S45) → S46 → S47 → S48. S41 (Gang) attend aussi S39 et se place en parallèle de S40.

Avec une seule équipe, il faut 48 sessions à la suite. Avec 3 équipes en parallèle, le calendrier se resserre à 23 « créneaux » de session (tableau ci-dessous : le chemin critique plus quelques attentes) ; une 4e équipe ne gagne qu'un ou deux créneaux. Au-delà de 4 équipes, le gain est faible : le client teste une session à la fois et devient le goulot.

Planning conseillé à 3 équipes (chaque ligne = un créneau) :

| Créneau | Équipe A (chemin critique) | Équipe B | Équipe C |
|---|---|---|---|
| 1 | S01 | — | — |
| 2 | S02 | — | — |
| 3 | S03 | — | — |
| 4 | S04 | — | — |
| 5 | S09 | S05 | S06 |
| 6 | S16 | S07 | S08 |
| 7 | S18 | S12 | S10 |
| 8 | S19 | S17 | S11 |
| 9 | S20 | S13 | S14 |
| 10 | S21 | S22 | S15 |
| 11 | S39 | S36 | S24 |
| 12 | S40 | S41 | S25 |
| 13 | S37 | S34 | S23 |
| 14 | S38 | S32 | S26 |
| 15 | S33 | S35 | S27 |
| 16 | S30 | S28 | S29 |
| 17 | S31 | — | — |
| 18 | S42 | — | — |
| 19 | S43 | — | — |
| 20 | S44 | S45 | — |
| 21 | S46 | — | — |
| 22 | S47 | — | — |
| 23 | S48 | — | — |

Soit 23 créneaux à 3 équipes (contrôlé par script : chaque session placée une fois, après toutes ses dépendances).

---

## 3. Jalons

| Jalon | Atteint à la fin de | Ce que le client voit en jeu |
|---|---|---|
| **1. Démarre sans erreur** | S01 | La nouvelle ressource démarre sur le serveur ESX de test : ligne verte en console, 100 tables créées, ancienne tablette retirée, 0,00 ms. |
| **2. Base jouable** | S08 (S05 à S08 en parallèle après S04) | Une tablette complète sans métier : objet, code, bureau, notifications, batterie, tablette posée, réglages et langues, fenêtre simple, panneau Admin, API pour les autres scripts. |
| **3. Premier métier complet (police)** | S22 (avec S09 à S13 pour le service, les droits et les amendes) | MDT complet : service, dispatch et alertes des scripts tiers, citoyens et véhicules, rapports, amendes, casier et prison, mandats, preuves, caméras, formation. Seule l'infiltration de la messagerie de gang (MET-POL-47) arrive avec l'app Gang en S41, car elle lit ses messages. |
| **4. Tous métiers** | S41 | Police, EMS, Mécano (+ Carnet auto), Justice, Immobilier, Gang, plus Entreprises, Sites, Navigateur, Outils, Gestion pro et Apps perso : l'arbre V1 est complet (360 fiches). |
| **5. Tous frameworks testés** | S45 (S43 ESX, S44 QBCore, S45 Qbox) | La même grille de recette passe sur les trois frameworks, avec les mêmes critères. |
| **6. Prêt Tebex** | S48 (S46 audit, S47 escrow + docs + guide IA, S48 page de vente) | Zip vendable (cœur chiffré, fichiers ouverts), documentation d'installation en 5 minutes, guide pour l'IA, page de vente FR / EN : le client n'a plus qu'à publier. |

---

## 4. Prompts des sessions (à copier-coller dans Claude Code)

Chaque prompt est autonome : il dit quoi lire, quoi faire, les règles, quoi livrer, et finit par un résumé simple pour le client. Le client copie le bloc entier.

### S01 · Socle qui démarre

Dépend de : — · Durée : 1 · Fiches : BASE-MOT-17, BASE-MOT-19

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 01 du plan de la tablette POP : « Socle qui démarre ».

Objectif : Retirer l'ancienne tablette et poser la nouvelle ressource vide : squelette, manifeste, config, contrôle des dépendances, 100 tables par migrations, outillage de tests et build NUI vide.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §0, §1 (tout), §2.1, §2.2, §4 (tout), §6.1, §9.1 à 9.3, §10.
- `/mnt/project-files/pop_tablet/specs/01-base.md` : seulement les fiches BASE-MOT-17, BASE-MOT-19 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.

Fiches à implémenter entièrement (2) : BASE-MOT-17, BASE-MOT-19.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : aucune (première session).

Points propres à cette session :
- Retire l'ancienne tablette : `git rm -r "resources/[pop]/pop_tablet"` (décision du client, récupérable par git). Note le hash du dernier commit qui la contient dans `docs/pop_tablet-suivi.md`. Vérifie `scripts/verifier-tablette.ps1` : s'il ne sert qu'à l'ancienne tablette, retire-le aussi.
- Ne modifie pas `pop_inventory` : son objet `pop_tablet` (`resources/[pop]/pop_inventory/config/items_5.lua`) déclenche `pop_tablet:client:use` avec `meta.serial`. Note-le dans le suivi : la session 03 écoutera cet événement en plus de l'objet utilisable du bridge.
- Anciennes tables sur la base de test : l'ancienne tablette a créé 23 tables `pop_tablet_*` dont 4 portent le même nom qu'une table neuve (`pop_tablet_devices`, `pop_tablet_appdata`, `pop_tablet_notes`, `pop_tablet_sites`). Au démarrage, si `pop_tablet_meta` n'existe pas et qu'une de ces tables existe avec d'autres colonnes : ne rien toucher, refuser de démarrer avec un message console clair, et fournir la commande **console seulement** `pop_tablet_archive_legacy confirm` qui renomme les 23 anciennes tables en `pop_tablet_legacy_<nom>` (aucune donnée perdue). C'est la seule exception écrite à « jamais de RENAME », hors du système de migrations.
- Copie les 6 fichiers pop_base sans les modifier (tech D1, §6.1) ; `fxmanifest.lua` exact de §1.3 ; `config.lua` complet dès maintenant avec **une section commentée par app** (toutes les clés du sommaire §3.6 et des fiches), pour que les sessions parallèles n'éditent que leur section.
- `server/core/migrations.lua` : `Migrations[1]` = les 100 tables de §4.3, helpers `Migr.addColumn/addIndex/modifyColumn` via `information_schema`, contrôle MySQL 5.7.8 / MariaDB 10.3 ; `sql/install.sql` généré par `tests/pop_tablet/gen_install_sql.lua`.
- `tests/pop_tablet/` : lanceur `run.lua`, mocks FiveM / oxmysql / bridge (profils ESX, QBCore, Qbox), suites migrations et timers, `pop_base_sync.lua`, `static.lua`, `locales.lua`, `coverage.lua`. Écris `tests/pop_tablet/fiches.txt` (les 360 IDs actifs, un par ligne, depuis les fiches) et `tests/pop_tablet/fiches_faites.txt` (vide) : `coverage.lua` échoue si un ID de `fiches_faites.txt` n'a pas son commentaire `[ID]` ; le mode `--strict` (tous les IDs) sera activé en session 46.
- `scripts/verifier-pop-tablet.sh` : les 11 étapes de §9.1 dans l'ordre, arrêt au premier échec ; complète `.luacheckrc` (globales de §9.1).
- `ui/pop_tablet/` : `package.json` à versions exactes (preact, @preact/signals, esbuild, typescript, @playwright/test), `tsconfig` strict, `build.mjs` avec budgets, `main.tsx` minimal ; `web/index.html` de §2.2 ; `web/dist/` commité.
- Crée `docs/pop_tablet-suivi.md` : tableau des 48 sessions du plan (`/mnt/project-files/pop_tablet/plan/30-plan-sessions.md`) avec statut, écarts et décisions prises.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : La ressource démarre sans erreur sur le serveur ESX de test, les 100 tables existent, un 2e démarrage ne change rien, `scripts/verifier-pop-tablet.sh` est vert.
- Test en jeu que le client fera : (1) Console txAdmin : ligne verte « [pop_tablet] ready » avec framework esx, aucune ligne rouge. / (2) Si la console annonce d'anciennes tables : taper `pop_tablet_archive_legacy confirm` dans la console txAdmin, puis `restart pop_tablet`. / (3) En jeu, `resmon 1` : pop_tablet à 0,00 ms.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-01-socle` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 01 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Console txAdmin : ligne verte « [pop_tablet] ready » avec framework esx, aucune ligne rouge. / (2) Si la console annonce d'anciennes tables : taper `pop_tablet_archive_legacy confirm` dans la console txAdmin, puis `restart pop_tablet`. / (3) En jeu, `resmon 1` : pop_tablet à 0,00 ms.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S02 · Moteur serveur et bridge

Dépend de : S01 · Durée : 1 (longue) · Fiches : BASE-MOT-01 à 08, BASE-MOT-11 à 13, BASE-MOT-16, BASE-MOT-18

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 02 du plan de la tablette POP : « Moteur serveur et bridge ».

Objectif : Construire le moteur commun : porte d'entrée unique et ses 13 contrôles, bridge ESX / QBCore / Qbox étendu, sauvegarde groupée, cache, limites, anti-spam, nettoyage des textes, images, journal, Discord, langues côté serveur, zéro boucle.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §3 (tout), §5, §6 (tout), §7, §9.2, §9.3.
- `/mnt/project-files/pop_tablet/specs/01-base.md` : seulement les fiches BASE-MOT-01 à 08, BASE-MOT-11 à 13, BASE-MOT-16, BASE-MOT-18 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.

Fiches à implémenter entièrement (13) : BASE-MOT-01, BASE-MOT-02, BASE-MOT-03, BASE-MOT-04, BASE-MOT-05, BASE-MOT-06, BASE-MOT-07, BASE-MOT-08, BASE-MOT-11, BASE-MOT-12, BASE-MOT-13, BASE-MOT-16, BASE-MOT-18.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S01.

Points propres à cette session :
- Fichiers : `server/core/` (gateway, schema, sanitize, ratelimit, idem, session, registry, perm (niveaux seulement), refs, near, cache, writequeue, log, discord, notify (squelette), push, i18n, timers), `bridge/tablet/*`, `bridge/framework/{esx,qbcore,qbox}.lua`, `bridge/inventory/metadata.lua`, registre `PopAdapters` (§6.3) et dossiers d'adaptateurs avec leurs gardes.
- Langues : format JSON par espace de noms (tech D6, A4) ; crée `locales/fr/common.json` et `locales/en/common.json` avec les textes communs du sommaire §3.9 ; repli langue → `Config.Locale` → `fr` → clé.
- Ajoute l'action de test `base.ping` et la commande admin `/tablette_debug` (framework, adaptateurs, fils actifs, minuteries armées, taille du cache, file d'écriture). Cette commande sera enrichie par les sessions suivantes.
- Discord : liens seulement en convars (`pop_tablet_webhook*`), jamais dans le dépôt.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Tests unitaires sanitize, schema, ratelimit, idem, gateway, writequeue, timers, i18n et bridge verts sur les 3 profils ; aucune boucle ; démarrage sans erreur.
- Test en jeu que le client fera : (1) En jeu (admin) : `/tablette_debug` → affiche « Framework : esx », l'inventaire et la cible détectés, « Fils actifs : 0 ». / (2) Changer son métier avec la commande admin habituelle du serveur, puis `/tablette_debug` → nouveau métier affiché. / (3) `resmon 1` : pop_tablet à 0,00 ms côté client et serveur.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-02-moteur` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 02 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) En jeu (admin) : `/tablette_debug` → affiche « Framework : esx », l'inventaire et la cible détectés, « Fils actifs : 0 ». / (2) Changer son métier avec la commande admin habituelle du serveur, puis `/tablette_debug` → nouveau métier affiché. / (3) `resmon 1` : pop_tablet à 0,00 ms côté client et serveur.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S03 · Objet, coque NUI et kit de style

Dépend de : S02 · Durée : 1 · Fiches : BASE-OBJ-01 à 03, BASE-OBJ-13 à 17, BASE-MOT-09, BASE-MOT-10

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 03 du plan de la tablette POP : « Objet, coque NUI et kit de style ».

Objectif : Ouvrir la vraie tablette en jeu : objet utilisable, animation, numéro de série, raccourci, mode sans métadonnées, fermeture forcée, écran Bienvenue, kit de style et les 6 états d'écran.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §2 (tout), §3.5, §3.7, §1.2 (dossier client/).
- `/mnt/project-files/pop_tablet/specs/01-base.md` : seulement les fiches BASE-OBJ-01 à 03, BASE-OBJ-13 à 17, BASE-MOT-09, BASE-MOT-10 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : design/20-design.md en entier ; design/maquette.html (cadre, écran Bienvenue, composants) ; captures 01-accueil.png.

Fiches à implémenter entièrement (10) : BASE-OBJ-01, BASE-OBJ-02, BASE-OBJ-03, BASE-OBJ-13, BASE-OBJ-14, BASE-OBJ-15, BASE-OBJ-16, BASE-OBJ-17, BASE-MOT-09, BASE-MOT-10.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S02.

Points propres à cette session :
- Ouverture par l'objet du bridge **et** par l'événement `pop_tablet:client:use` déjà émis par pop_inventory (le numéro reçu n'est qu'un indice : le serveur revérifie l'objet et sa série).
- Kit : `web/kit/tokens.css` (seule source des couleurs) et `web/kit/tablet.css`, composants `src/kit/` de §2.5, `ScreenState` avec les 6 états ; propriétés CSS logiques uniquement.
- `src/core/registry.ts` : une ligne par app de §3.6, commentée tant que l'app n'existe pas ; chaque session décommente la sienne (évite les conflits entre branches).
- Fils client : seulement dans les fichiers permis (§9.2), créés à l'ouverture et tués à la fermeture ; `/tablette_debug` affiche leur nombre.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Ouverture / fermeture fluides, série stable sur la même tablette, e2e shell, states, static, lazy et leaks verts, 0 fil client tablette fermée.
- Test en jeu que le client fera : (1) Se donner l'objet `pop_tablet` avec la commande habituelle du serveur, l'utiliser → animation, la tablette s'ouvre sur « Bienvenue » avec son numéro PT-XXXX-XXXX. / (2) Échap → elle se ferme en fondu ; F9 → elle se rouvre. / (3) Tablette ouverte, entrer dans l'eau → elle se ferme toute seule.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-03-coque` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 03 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Se donner l'objet `pop_tablet` avec la commande habituelle du serveur, l'utiliser → animation, la tablette s'ouvre sur « Bienvenue » avec son numéro PT-XXXX-XXXX. / (2) Échap → elle se ferme en fondu ; F9 → elle se rouvre. / (3) Tablette ouverte, entrer dans l'eau → elle se ferme toute seule.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S04 · Verrou, bureau, barre du haut, notifications

Dépend de : S03 · Durée : 1 · Fiches : BASE-OBJ-04 à 07, BASE-ECR-01 à 05

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 04 du plan de la tablette POP : « Verrou, bureau, barre du haut, notifications ».

Objectif : Rendre la tablette utilisable au quotidien : code de verrouillage et blocage, bureau d'icônes rangeable, barre du haut, bandeau de notification et historique.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §2.3, §3.5 (Notify.Send), §4.3 (tables base), §7.1.
- `/mnt/project-files/pop_tablet/specs/01-base.md` : seulement les fiches BASE-OBJ-04 à 07, BASE-ECR-01 à 05 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : captures 00-verrouillage.png et 01-accueil.png ; maquette.html (verrou, bureau 6 × 4, barre du haut, volet notifications).

Fiches à implémenter entièrement (9) : BASE-OBJ-04, BASE-OBJ-05, BASE-OBJ-06, BASE-OBJ-07, BASE-ECR-01, BASE-ECR-02, BASE-ECR-03, BASE-ECR-04, BASE-ECR-05.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S03.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Code haché côté serveur (jamais renvoyé), blocage 5 min tenu même après reconnexion, ordre des icônes gardé, notifications gardées 7 jours / 50 max.
- Test en jeu que le client fera : (1) Créer un code à 4 chiffres, fermer puis rouvrir → le code est demandé. / (2) Taper 5 fois un faux code → « bloquée 5 minutes », secousse à chaque erreur. / (3) Appui long sur une icône et la déplacer ; `/tablette_debug notif` → bandeau puis ligne dans la cloche.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-04-verrou-bureau` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 04 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Créer un code à 4 chiffres, fermer puis rouvrir → le code est demandé. / (2) Taper 5 fois un faux code → « bloquée 5 minutes », secousse à chaque erreur. / (3) Appui long sur une icône et la déplacer ; `/tablette_debug notif` → bandeau puis ligne dans la cloche.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S05 · Batterie, réseau, tablette posée

Dépend de : S04 · Durée : 1 · Fiches : BASE-ECR-06 à 09, BASE-ECR-17, BASE-OBJ-10 à 12

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 05 du plan de la tablette POP : « Batterie, réseau, tablette posée ».

Objectif : Ajouter la vie de l'objet : batterie qui baisse à l'usage, recharge en véhicule et au chargeur, zones sans réseau, tablette posée que d'autres regardent.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §1.2 (client/charge.lua, network.lua, props.lua), §3.7 (événements de gestes), §5.4.
- `/mnt/project-files/pop_tablet/specs/01-base.md` : seulement les fiches BASE-ECR-06 à 09, BASE-ECR-17, BASE-OBJ-10 à 12 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (barre du haut : batterie, réseau).

Fiches à implémenter entièrement (8) : BASE-ECR-06, BASE-ECR-07, BASE-ECR-08, BASE-ECR-09, BASE-ECR-17, BASE-OBJ-10, BASE-OBJ-11, BASE-OBJ-12.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S04.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Batterie calculée par le temps serveur (jamais une valeur client), aucune boucle hors véhicule + tablette ouverte, tablette posée retirée proprement.
- Test en jeu que le client fera : (1) `/tablette_debug battery 5` puis garder la tablette ouverte → icône orange puis écran « Batterie vide ». / (2) Monter dans une voiture → icône de recharge ; utiliser `pop_tablet_charger` → barre de 10 s. / (3) Bouton « Poser » → la tablette est posée devant soi ; s'éloigner de plus de 30 m → elle revient dans l'inventaire.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-05-batterie-posee` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 05 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) `/tablette_debug battery 5` puis garder la tablette ouverte → icône orange puis écran « Batterie vide ». / (2) Monter dans une voiture → icône de recharge ; utiliser `pop_tablet_charger` → barre de 10 s. / (3) Bouton « Poser » → la tablette est posée devant soi ; s'éloigner de plus de 30 m → elle revient dans l'inventaire.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S06 · Réglages, langues, fenêtre simple, assistant

Dépend de : S04 · Durée : 1 · Fiches : BASE-ECR-10 à 16, BASE-MOT-14, BASE-MOT-15

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 06 du plan de la tablette POP : « Réglages, langues, fenêtre simple, assistant ».

Objectif : Livrer l'app Réglages (fond, accent, luminosité, taille du texte, langue, son), la fenêtre simple pour les joueurs sans tablette et l'assistant de premier démarrage de l'admin.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §2.6, §1.2 (client/simple.lua, server/core/documents.lua), §6.3.
- `/mnt/project-files/pop_tablet/specs/01-base.md` : seulement les fiches BASE-ECR-10 à 16, BASE-MOT-14, BASE-MOT-15 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : captures 02-accueil-arabe.png ; maquette.html (Réglages, fenêtre simple).

Fiches à implémenter entièrement (9) : BASE-ECR-10, BASE-ECR-11, BASE-ECR-12, BASE-ECR-13, BASE-ECR-14, BASE-ECR-15, BASE-ECR-16, BASE-MOT-14, BASE-MOT-15.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S04.

Points propres à cette session :
- Pour l'arabe à ce stade : `locales/ar/_meta.json` (rtl) et `common.json` ; les autres langues arrivent en session 42.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Réglages attachés au numéro de série, RTL correct sur le shell (e2e rtl.spec en fr, de, ar, th), assistant qui détecte framework, inventaire, banque et Justice.
- Test en jeu que le client fera : (1) Réglages → changer le fond, la couleur d'accent et la taille du texte → appliqué tout de suite, gardé après reconnexion. / (2) Langue → English puis العربية → interface traduite, puis inversée de droite à gauche. / (3) `/tablette_setup` (admin) → assistant pas à pas ; `/tablette_debug doc` sur un joueur sans tablette → fenêtre simple (touche Y).

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-06-reglages` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 06 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Réglages → changer le fond, la couleur d'accent et la taille du texte → appliqué tout de suite, gardé après reconnexion. / (2) Langue → English puis العربية → interface traduite, puis inversée de droite à gauche. / (3) `/tablette_setup` (admin) → assistant pas à pas ; `/tablette_debug doc` sur un joueur sans tablette → fenêtre simple (touche Y).
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S07 · Panneau Admin (socle)

Dépend de : S04 · Durée : 1 · Fiches : BASE-OBJ-08, BASE-OBJ-09, ADM-01 à 08, ADM-11, ADM-14

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 07 du plan de la tablette POP : « Panneau Admin (socle) ».

Objectif : Donner à l'admin son panneau : accès, couper une app, liste des tablettes, réinitialiser, débloquer, donner une tablette, journal et Discord, limites, performance, et les exports de réinitialisation / remplacement.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §3.6 (app admin), §7.2, §8.1 (exports tablette), §5.3 (pagination du journal).
- `/mnt/project-files/pop_tablet/specs/01-base.md` : seulement les fiches BASE-OBJ-08, BASE-OBJ-09 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- `/mnt/project-files/pop_tablet/specs/05-sites-admin-apps-perso.md` : seulement les fiches ADM-01 à 08, ADM-11, ADM-14 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Admin).

Fiches à implémenter entièrement (12) : BASE-OBJ-08, BASE-OBJ-09, ADM-01, ADM-02, ADM-03, ADM-04, ADM-05, ADM-06, ADM-07, ADM-08, ADM-11, ADM-14.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S04.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Toutes les actions admin revérifient l'ACE `pop.tablet.admin` à chaque appel et sont journalisées ; exports `ResetTablet`, `ReplaceTablet`, `TransferTabletData` testés.
- Test en jeu que le client fera : (1) `/tablette_admin` → panneau Admin. / (2) Admin > Tablettes → retrouver sa tablette par son numéro, la réinitialiser → plus de code au prochain démarrage. / (3) `/tablette_donner [son id]` → nouvelle tablette dans l'inventaire ; Admin > Journal → ces actions sont listées.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-07-admin-socle` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 07 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) `/tablette_admin` → panneau Admin. / (2) Admin > Tablettes → retrouver sa tablette par son numéro, la réinitialiser → plus de code au prochain démarrage. / (3) `/tablette_donner [son id]` → nouvelle tablette dans l'inventaire ; Admin > Journal → ces actions sont listées.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S08 · API pour développeurs

Dépend de : S04 · Durée : 1 · Fiches : BASE-API-02 à 07

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 08 du plan de la tablette POP : « API pour développeurs ».

Objectif : Ouvrir l'API publique de la base : enregistrer une app, ouvrir un écran, notifier, lire le joueur, stocker des données, payer via le serveur ; ressource de test pour la vérifier en jeu.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §8.1, §2.7 (apps tierces en iframe), §3.3 (RegisterAction).
- `/mnt/project-files/pop_tablet/specs/01-base.md` : seulement les fiches BASE-API-02 à 07 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.

Fiches à implémenter entièrement (6) : BASE-API-02, BASE-API-03, BASE-API-04, BASE-API-05, BASE-API-06, BASE-API-07.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S04.

Points propres à cette session :
- Ressource de test `resources/[pop]/pop_tablet_devtest/` : le déploiement ne copie que `resources/[pop]`, elle doit donc y vivre ; commandes réservées à l'ACE `pop.tablet.admin`, jamais incluse dans le zip Tebex (le script de release la refusera). Les sessions suivantes y ajoutent leurs commandes de test (`/devtest_*`).

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Exports de BASE-API-02 à 07 documentés dans `docs/api.md` (brouillon), paiement idempotent testé sous double requête, base jouable de bout en bout.
- Test en jeu que le client fera : (1) `/devtest_app` → une icône « Test » apparaît sur le bureau. / (2) L'ouvrir puis bouton « Notifier » → bandeau de notification. / (3) Bouton « Payer 10 $ » cliqué deux fois très vite → 10 $ retirés une seule fois.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-08-api` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 08 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) `/devtest_app` → une icône « Test » apparaît sur le bureau. / (2) L'ouvrir puis bouton « Notifier » → bandeau de notification. / (3) Bouton « Payer 10 $ » cliqué deux fois très vite → 10 $ retirés une seule fois.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S09 · Entreprises, service et droits

Dépend de : S04 · Durée : 1 · Fiches : SITE-CRE-01 à 03, SITE-CRE-12, ENT-GES-01 à 04, ENT-GES-18, ENT-GES-19

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 09 du plan de la tablette POP : « Entreprises, service et droits ».

Objectif : Poser la colonne vertébrale des métiers : table des entreprises et 7 entreprises par défaut reliées aux métiers, prise / fin de service unique, droits par grade réglables par le Patron.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §3.6 (gestion, companies), §4.3 (tables 02 et 05 concernées), §5.1, §6.2 (GetJobFull, GetJobs, OnJobChange, SetDutyFlag).
- `/mnt/project-files/pop_tablet/specs/05-sites-admin-apps-perso.md` : seulement les fiches SITE-CRE-01 à 03, SITE-CRE-12 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- `/mnt/project-files/pop_tablet/specs/02-entreprises.md` : seulement les fiches ENT-GES-01 à 04, ENT-GES-18, ENT-GES-19 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Entreprise : service, droits).

Fiches à implémenter entièrement (10) : SITE-CRE-01, SITE-CRE-02, SITE-CRE-03, SITE-CRE-12, ENT-GES-01, ENT-GES-02, ENT-GES-03, ENT-GES-04, ENT-GES-18, ENT-GES-19.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S04.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Une seule table de service, state bag `popDuty`, métier jamais basculé, grille de droits du sommaire §3.7 appliquée et testée (`perm`), entreprises créées une seule fois.
- Test en jeu que le client fera : (1) `/tablette_admin` > Entreprises → les 7 entreprises par défaut, « Police » reliée au métier police. / (2) Avec le métier police : Gestion → « Prendre mon service » → barre du haut « En service ». / (3) En Patron : Gestion > Droits → retirer une case à Recrue → une recrue voit le bouton grisé « Grade requis ».

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-09-entreprises-service` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 09 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) `/tablette_admin` > Entreprises → les 7 entreprises par défaut, « Police » reliée au métier police. / (2) Avec le métier police : Gestion → « Prendre mon service » → barre du haut « En service ». / (3) En Patron : Gestion > Droits → retirer une case à Recrue → une recrue voit le bouton grisé « Grade requis ».
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S10 · Employés et grades

Dépend de : S09 · Durée : 1 · Fiches : ENT-GES-05 à 17

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 10 du plan de la tablette POP : « Employés et grades ».

Objectif : Gérer l'équipe : liste et fiche des employés, recrutement d'un joueur proche, promotion, rétrogradation, renvoi, démission, grades et salaires (création, renommage, suppression avec avertissement).

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §6.2 (SetPlayerJob, GetEmployees, CreateJob, SaveGrades), §4.3 (company_grades, ent_invitations).
- `/mnt/project-files/pop_tablet/specs/02-entreprises.md` : seulement les fiches ENT-GES-05 à 17 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Entreprise : employés, grades).

Fiches à implémenter entièrement (13) : ENT-GES-05, ENT-GES-06, ENT-GES-07, ENT-GES-08, ENT-GES-09, ENT-GES-10, ENT-GES-11, ENT-GES-12, ENT-GES-13, ENT-GES-14, ENT-GES-15, ENT-GES-16, ENT-GES-17.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S09.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Distance revérifiée par le serveur (3 m), « sous son grade » respecté pour le Chef, renumérotation avec avertissement, tout journalisé ; tests unitaires et e2e verts.
- Test en jeu que le client fera : (1) Recruter un joueur proche → il reçoit l'invitation et accepte → il apparaît dans la liste. / (2) Le promouvoir puis le rétrograder → son grade change dans le framework. / (3) Créer le grade « Stagiaire » et fixer son salaire → visible dans Grades et salaires.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-10-employes-grades` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 10 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Recruter un joueur proche → il reçoit l'invitation et accepte → il apparaît dans la liste. / (2) Le promouvoir puis le rétrograder → son grade change dans le framework. / (3) Créer le grade « Stagiaire » et fixer son salaire → visible dans Grades et salaires.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S11 · Compte d'entreprise et ventes

Dépend de : S10 · Durée : 1 · Fiches : ENT-GES-20 à 26

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 11 du plan de la tablette POP : « Compte d'entreprise et ventes ».

Objectif : Brancher l'argent de l'entreprise : solde du compte société détecté, dépôt, retrait, historique des ventes par jour et par employé, prime à un employé.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §6.3 (banque), §1.2 (bridge/bank/), §4.3 (ent_mouvements).
- `/mnt/project-files/pop_tablet/specs/02-entreprises.md` : seulement les fiches ENT-GES-20 à 26 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : capture 07-entreprise-compte.png ; maquette.html (Entreprise : compte).

Fiches à implémenter entièrement (7) : ENT-GES-20, ENT-GES-21, ENT-GES-22, ENT-GES-23, ENT-GES-24, ENT-GES-25, ENT-GES-26.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S10.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Adaptateurs banque ESX, QBCore (2) et Qbox (2) écrits et testés par mocks, « Compte d'entreprise indisponible » sans système, aucune création ni perte d'argent sous double clic.
- Test en jeu que le client fera : (1) Gestion > Compte → le solde est celui du compte société du serveur. / (2) Déposer 100 $ puis retirer 50 $ → solde et historique à jour. / (3) Verser une prime de 20 $ à un employé → il la reçoit, ligne dans l'historique.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-11-compte` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 11 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Gestion > Compte → le solde est celui du compte société du serveur. / (2) Déposer 100 $ puis retirer 50 $ → solde et historique à jour. / (3) Verser une prime de 20 $ à un employé → il la reçoit, ligne dans l'historique.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S12 · Factures : créer et payer

Dépend de : S09, S06 · Durée : 1 · Fiches : ENT-FAC-01 à 07

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 12 du plan de la tablette POP : « Factures : créer et payer ».

Objectif : Faire et payer des factures : création avec lignes, choix d'un client proche, onglet Reçues, paiement sur tablette ou en fenêtre simple, refus, cas du joueur inconscient.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §3.3 (exemple factures.creer), §4.3 (factures, factures_evenements, payments), §1.2 (payments.lua, documents.lua).
- `/mnt/project-files/pop_tablet/specs/02-entreprises.md` : seulement les fiches ENT-FAC-01 à 07 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : capture 05-factures-nouvelle.png ; maquette.html (Factures).

Fiches à implémenter entièrement (7) : ENT-FAC-01, ENT-FAC-02, ENT-FAC-03, ENT-FAC-04, ENT-FAC-05, ENT-FAC-06, ENT-FAC-07.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S09, S06.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Totaux recalculés par le serveur, plafond Recrue 500 $ et 100 000 $ max, paiement unique sous double requête, facture d'un inconscient annulée après 60 min.
- Test en jeu que le client fera : (1) Factures > Nouvelle → choisir un joueur proche, 2 lignes → « Facture envoyée. » / (2) Le joueur paie sur sa tablette → argent transféré une seule fois, même en double-cliquant. / (3) Joueur sans tablette → fenêtre simple (touche Y) → payer ou refuser.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-12-factures-1` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 12 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Factures > Nouvelle → choisir un joueur proche, 2 lignes → « Facture envoyée. » / (2) Le joueur paie sur sa tablette → argent transféré une seule fois, même en double-cliquant. / (3) Joueur sans tablette → fenêtre simple (touche Y) → payer ou refuser.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S13 · Factures : suivi, impayés et API

Dépend de : S12, S11 · Durée : 1 (longue) · Fiches : ENT-FAC-08 à 19, BASE-API-09

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 13 du plan de la tablette POP : « Factures : suivi, impayés et API ».

Objectif : Suivre et régler les factures : liste, filtres, détail, annulation, part employé, relance, impayés (délai, majoration, transmission à la police), signal « facture payée » et création par l'API.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §8.1 (CreateInvoice, GetInvoice, OnInvoicePaid), §8.2, §5.3.
- `/mnt/project-files/pop_tablet/specs/02-entreprises.md` : seulement les fiches ENT-FAC-08 à 19 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- `/mnt/project-files/pop_tablet/specs/01-base.md` : seulement les fiches BASE-API-09 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : capture 06-factures-suivi.png ; maquette.html (Factures : suivi).

Fiches à implémenter entièrement (13) : ENT-FAC-08, ENT-FAC-09, ENT-FAC-10, ENT-FAC-11, ENT-FAC-12, ENT-FAC-13, ENT-FAC-14, ENT-FAC-15, ENT-FAC-16, ENT-FAC-17, ENT-FAC-18, ENT-FAC-19, BASE-API-09.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S12, S11.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Majoration unique 10 % appliquée à la lecture après le délai, part employé figée à la création, signaux `invoicePaid` et suivants émis côté serveur seulement.
- Test en jeu que le client fera : (1) Factures > Suivi → filtrer « Impayées ». / (2) Ouvrir une facture → la relancer puis l'annuler → statut et historique à jour. / (3) `/devtest_facture` (création par l'API) puis payer → la ressource de test reçoit le signal « facture payée ».

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-13-factures-2` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 13 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Factures > Suivi → filtrer « Impayées ». / (2) Ouvrir une facture → la relancer puis l'annuler → statut et historique à jour. / (3) `/devtest_facture` (création par l'API) puis payer → la ressource de test reçoit le signal « facture payée ».
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S14 · Annonces et boîte Demandes

Dépend de : S09 · Durée : 1 · Fiches : ENT-ANN-01 à 07, ENT-DEM-01 à 03

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 14 du plan de la tablette POP : « Annonces et boîte Demandes ».

Objectif : Publier des annonces (entreprise et toute la ville) et ouvrir la boîte Demandes : liste, détail, réception d'une demande.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §4.3 (ent_annonces, ent_demandes avec payload), §3.5 (cityBanner), §8.1 (CreateRequest).
- `/mnt/project-files/pop_tablet/specs/02-entreprises.md` : seulement les fiches ENT-ANN-01 à 07, ENT-DEM-01 à 03 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Annonces, Demandes).

Fiches à implémenter entièrement (10) : ENT-ANN-01, ENT-ANN-02, ENT-ANN-03, ENT-ANN-04, ENT-ANN-05, ENT-ANN-06, ENT-ANN-07, ENT-DEM-01, ENT-DEM-02, ENT-DEM-03.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S09.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Fréquences 30 min / 2 min respectées, expiration après 1 h sans minuterie permanente, 3 demandes ouvertes max par demandeur.
- Test en jeu que le client fera : (1) Annonces → publier une annonce, la modifier, la retirer. / (2) En Patron : « Annonce à toute la ville » → bandeau chez tous les joueurs qui ont une tablette. / (3) `/devtest_demande police` → la demande apparaît dans la boîte Demandes de la police.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-14-annonces-demandes` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 14 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Annonces → publier une annonce, la modifier, la retirer. / (2) En Patron : « Annonce à toute la ville » → bandeau chez tous les joueurs qui ont une tablette. / (3) `/devtest_demande police` → la demande apparaît dans la boîte Demandes de la police.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S15 · Demandes : traiter et suivre

Dépend de : S14 · Durée : 1 · Fiches : ENT-DEM-04 à 09

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 15 du plan de la tablette POP : « Demandes : traiter et suivre ».

Objectif : Traiter les demandes de bout en bout : accepter avec GPS, assigner, refuser, clôturer, suivi et annulation par le demandeur, réglages de la boîte.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §1.2 (client/gps.lua), §3.5.
- `/mnt/project-files/pop_tablet/specs/02-entreprises.md` : seulement les fiches ENT-DEM-04 à 09 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Demandes).

Fiches à implémenter entièrement (6) : ENT-DEM-04, ENT-DEM-05, ENT-DEM-06, ENT-DEM-07, ENT-DEM-08, ENT-DEM-09.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S14.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Droits `demandes.repondre` et `demandes.assigner` respectés, signaux `requestCreated` / `requestClosed`, tout journalisé.
- Test en jeu que le client fera : (1) Accepter une demande → point GPS posé sur la carte du jeu. / (2) L'assigner à un employé → il reçoit une notification. / (3) Côté demandeur : voir sa demande « Acceptée » puis l'annuler.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-15-demandes-2` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 15 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Accepter une demande → point GPS posé sur la carte du jeu. / (2) L'assigner à un employé → il reçoit une notification. / (3) Côté demandeur : voir sa demande « Acceptée » puis l'annuler.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S16 · Police 1 : service, effectifs, unités

Dépend de : S09 · Durée : 1 · Fiches : MET-POL-01 à 07, MET-POL-34, MET-POL-35

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 16 du plan de la tablette POP : « Police 1 : service, effectifs, unités ».

Objectif : Ouvrir le MDT : service, accueil avec recherche rapide, effectifs, statut en 1 clic, unités, matricule, annonces internes, heures de service.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §3.6 (police, un fichier par section), §4.3 (police_agents, police_annonces…), §3.4 (limites police), §3.5 (Push.ToPolice).
- `/mnt/project-files/pop_tablet/specs/03-police.md` : seulement les fiches MET-POL-01 à 07, MET-POL-34, MET-POL-35 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : capture 03-police-dispatch.png ; maquette.html (Police).

Fiches à implémenter entièrement (9) : MET-POL-01, MET-POL-02, MET-POL-03, MET-POL-04, MET-POL-05, MET-POL-06, MET-POL-07, MET-POL-34, MET-POL-35.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S09.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Chunk police chargé à la demande, état Hors service partout, effectifs mis à jour par push ciblé (jamais à tous les joueurs).
- Test en jeu que le client fera : (1) Ouvrir Police hors service → seul « Prendre mon service » est actif ; le prendre. / (2) Passer « Occupé » en 1 clic, créer l'unité « ADAM-12 ». / (3) En Chef : publier une annonce interne → les agents en service la reçoivent ; Heures → semaine affichée.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-16-police-1` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 16 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Ouvrir Police hors service → seul « Prendre mon service » est actif ; le prendre. / (2) Passer « Occupé » en 1 clic, créer l'unité « ADAM-12 ». / (3) En Chef : publier une annonce interne → les agents en service la reçoivent ; Heures → semaine affichée.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S17 · Police 2 : dispatch et alertes

Dépend de : S16 · Durée : 1 · Fiches : MET-POL-08 à 13, BASE-API-10, BASE-API-11

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 17 du plan de la tablette POP : « Police 2 : dispatch et alertes ».

Objectif : Faire vivre le dispatch : appels en cours, prise d'appel avec GPS, clôture et historique, appel manuel / renfort, bouton de détresse, alertes des scripts tiers et adaptateurs ps-dispatch, cd_dispatch, core_dispatch, esx_service.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §6.3 (dispatch), §1.2 (bridge/dispatch/), §3.7 (dispatchFromClient), §8.1 (DispatchAlert, PoliceAlert).
- `/mnt/project-files/pop_tablet/specs/03-police.md` : seulement les fiches MET-POL-08 à 13 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- `/mnt/project-files/pop_tablet/specs/01-base.md` : seulement les fiches BASE-API-10, BASE-API-11 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : capture 03-police-dispatch.png.

Fiches à implémenter entièrement (8) : MET-POL-08, MET-POL-09, MET-POL-10, MET-POL-11, MET-POL-12, MET-POL-13, BASE-API-10, BASE-API-11.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S16.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Format d'alerte unique (BASE-API-10, `title`, `priority`), adaptateurs chargés seulement si la vraie ressource est absente, coordonnées relues côté serveur, 3 / 10 s par joueur.
- Test en jeu que le client fera : (1) `/devtest_alerte` (simule un script tiers qui appelle ps-dispatch) → l'appel arrive dans la liste. / (2) Prendre l'appel → GPS ; le clôturer → il passe dans l'historique. / (3) Bouton de détresse → tous les agents en service reçoivent l'alerte avec la position.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-17-police-dispatch` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 17 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) `/devtest_alerte` (simule un script tiers qui appelle ps-dispatch) → l'appel arrive dans la liste. / (2) Prendre l'appel → GPS ; le clôturer → il passe dans l'historique. / (3) Bouton de détresse → tous les agents en service reçoivent l'alerte avec la position.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S18 · Police 3 : citoyens, véhicules, avis de recherche

Dépend de : S16 · Durée : 1 · Fiches : MET-POL-14 à 20, MET-POL-31, MET-POL-45

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 18 du plan de la tablette POP : « Police 3 : citoyens, véhicules, avis de recherche ».

Objectif : Rechercher et consulter : citoyens (fiche, photo, notes, permis), véhicules (fiche, signalement de plaque, plainte écrite), avis de recherche interne et public.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §6.2 (GetCharInfo, GetVehicles, FindPlate, GetLicenses), §1.2 (bridge/licenses/), §3.2 (refs).
- `/mnt/project-files/pop_tablet/specs/03-police.md` : seulement les fiches MET-POL-14 à 20, MET-POL-31, MET-POL-45 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : capture 04-police-fiche.png ; maquette.html (fiche citoyen, onglets soulignés).

Fiches à implémenter entièrement (9) : MET-POL-14, MET-POL-15, MET-POL-16, MET-POL-17, MET-POL-18, MET-POL-19, MET-POL-20, MET-POL-31, MET-POL-45.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S16.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Recherche à 300 ms / 2 caractères paginée, identifiants jamais exposés (refs opaques), aucun « volé » nulle part, avis public 24 h / 5 actifs max.
- Test en jeu que le client fera : (1) Rechercher un joueur par son nom → fiche citoyen ; ajouter une note. / (2) Rechercher une plaque → fiche véhicule ; « Signaler la plaque ». / (3) Publier un avis de recherche public → il apparaît sur la tablette d'un autre joueur.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-18-police-citoyens` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 18 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Rechercher un joueur par son nom → fiche citoyen ; ajouter une note. / (2) Rechercher une plaque → fiche véhicule ; « Signaler la plaque ». / (3) Publier un avis de recherche public → il apparaît sur la tablette d'un autre joueur.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S19 · Police 4 : rapports, amendes, code pénal

Dépend de : S18, S12 · Durée : 1 · Fiches : MET-POL-21 à 25, MET-POL-32, MET-POL-33

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 19 du plan de la tablette POP : « Police 4 : rapports, amendes, code pénal ».

Objectif : Écrire et sanctionner : modèles de rapport, rapport lié (citoyens, véhicules, agents, preuves) et transmis à la justice, liste et archivage, amende à un joueur proche, suivi des amendes, code pénal (lecture et modification).

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §4.3 (police_rapports, rapport_liens, rapport_modeles, amendes, codepenal), §1.2 (defaults/penal_code.lua, report_templates.lua).
- `/mnt/project-files/pop_tablet/specs/03-police.md` : seulement les fiches MET-POL-21 à 25, MET-POL-32, MET-POL-33 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Police : rapports).

Fiches à implémenter entièrement (7) : MET-POL-21, MET-POL-22, MET-POL-23, MET-POL-24, MET-POL-25, MET-POL-32, MET-POL-33.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S18, S12.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Amende ≤ barème et ≤ 2 500 $ pour une Recrue (facture `kind = fine`), code pénal en cache invalidé à la modification, rapports archivés jamais supprimés.
- Test en jeu que le client fera : (1) Rédiger un rapport lié à un citoyen et un véhicule → il apparaît dans la liste. / (2) Amende à un joueur proche depuis le code pénal → il la paie sur sa tablette. / (3) En Patron : modifier un article du code pénal → visible tout de suite.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-19-police-rapports` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 19 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Rédiger un rapport lié à un citoyen et un véhicule → il apparaît dans la liste. / (2) Amende à un joueur proche depuis le code pénal → il la paie sur sa tablette. / (3) En Patron : modifier un article du code pénal → visible tout de suite.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S20 · Police 5 : casier, mandats, formation

Dépend de : S19 · Durée : 1 · Fiches : MET-POL-26 à 30, MET-POL-42, MET-POL-43, BASE-API-08

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 20 du plan de la tablette POP : « Police 5 : casier, mandats, formation ».

Objectif : Casier avec peine et signal « peine prononcée » (adaptateurs prison), historique et retrait, mandats (demande, validation par Chef ou juge, levée, expiration), parcours de formation et suivi des recrues.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §6.3 (prison), §1.2 (bridge/jail/), §8.1 (EmitSentence, HasActiveWarrant, VerifyWarrantSignature, CasierAdd), §8.2.
- `/mnt/project-files/pop_tablet/specs/03-police.md` : seulement les fiches MET-POL-26 à 30, MET-POL-42, MET-POL-43 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- `/mnt/project-files/pop_tablet/specs/01-base.md` : seulement les fiches BASE-API-08 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Police).

Fiches à implémenter entièrement (8) : MET-POL-26, MET-POL-27, MET-POL-28, MET-POL-29, MET-POL-30, MET-POL-42, MET-POL-43, BASE-API-08.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S19.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Peine ≤ 120 mois, mandat 7 jours / 2 prolongations, signal `sentencePronounced` au format unique, adaptateurs prison (esx_jail, qalle_jail, qb-prison, qbx_prison, rcore_prison) testés par mocks.
- Test en jeu que le client fera : (1) Ajouter au casier avec 5 mois de prison → casier mis à jour (et envoi en prison si un adaptateur est réglé). / (2) Créer un mandat de perquisition → aucun juge en service → un Chef le valide, marqué « Validé sans juge ». / (3) Formation : assigner une recrue à un formateur et valider une étape.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-20-police-casier` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 20 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Ajouter au casier avec 5 mois de prison → casier mis à jour (et envoi en prison si un adaptateur est réglé). / (2) Créer un mandat de perquisition → aucun juge en service → un Chef le valide, marqué « Validé sans juge ». / (3) Formation : assigner une recrue à un formateur et valider une étape.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S21 · Police 6 : preuves, saisie, carte des crimes

Dépend de : S19 · Durée : 1 · Fiches : MET-POL-36 à 38, MET-POL-44, MET-POL-46

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 21 du plan de la tablette POP : « Police 6 : preuves, saisie, carte des crimes ».

Objectif : Preuves (photo, objet, document) liées aux rapports avec cadre d'obtention, recevabilité et chaîne de possession, empreintes, casier à preuves physique optionnel, saisie d'une tablette de suspect, carte des crimes de la semaine.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §4.3 (police_preuves, preuves_casiers, preuves_journal, saisies), §1.2 (client/evidence_locker.lua).
- `/mnt/project-files/pop_tablet/specs/03-police.md` : seulement les fiches MET-POL-36 à 38, MET-POL-44, MET-POL-46 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Police).

Fiches à implémenter entièrement (5) : MET-POL-36, MET-POL-37, MET-POL-38, MET-POL-44, MET-POL-46.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S19.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Recevabilité calculée par le serveur (« Irrecevable » sans mandat valide), chaîne de possession complète, casier physique désactivé par défaut et sans aucun fil quand il l'est.
- Test en jeu que le client fera : (1) Créer une preuve photo (lien imgur) et la lier à un rapport → recevabilité affichée. / (2) Saisir la tablette d'un suspect proche → elle apparaît dans « Saisies », contenu protégé par son code. / (3) Ouvrir la carte des crimes de la semaine → les points des rapports apparaissent.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-21-police-preuves` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 21 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Créer une preuve photo (lien imgur) et la lier à un rapport → recevabilité affichée. / (2) Saisir la tablette d'un suspect proche → elle apparaît dans « Saisies », contenu protégé par son code. / (3) Ouvrir la carte des crimes de la semaine → les points des rapports apparaissent.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S22 · Police 7 : caméras

Dépend de : S16, S07 · Durée : 1 · Fiches : MET-POL-39 à 41, ADM-12, ADM-13

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 22 du plan de la tablette POP : « Police 7 : caméras ».

Objectif : Placer et gérer les caméras fixes (Admin), vue en direct par la police, caméra piéton d'un agent en service.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §1.2 (client/camera_fixed.lua, bodycam.lua), §4.3 (cameras), §8.1.
- `/mnt/project-files/pop_tablet/specs/03-police.md` : seulement les fiches MET-POL-39 à 41 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- `/mnt/project-files/pop_tablet/specs/05-sites-admin-apps-perso.md` : seulement les fiches ADM-12, ADM-13 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Admin, Police).

Fiches à implémenter entièrement (5) : MET-POL-39, MET-POL-40, MET-POL-41, ADM-12, ADM-13.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S16, S07.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Une seule table de caméras, fil client seulement pendant le visionnage, distances revérifiées par le serveur, exports `SetCameraOnline` / `AddCamera`.
- Test en jeu que le client fera : (1) Admin > Caméras → placer une caméra à sa position et la tester. / (2) Police (Chef) → Caméras → vue en direct, rotation, retour avec Échap. / (3) Caméra piéton → voir ce que voit un autre agent en service à moins de 300 m.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-22-police-cameras` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 22 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Admin > Caméras → placer une caméra à sa position et la tester. / (2) Police (Chef) → Caméras → vue en direct, rotation, retour avec Échap. / (3) Caméra piéton → voir ce que voit un autre agent en service à moins de 300 m.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S23 · Créateur d'entreprises

Dépend de : S09, S07 · Durée : 1 · Fiches : SITE-CRE-04 à 11

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 23 du plan de la tablette POP : « Créateur d'entreprises ».

Objectif : Créer et administrer ses entreprises : assistant en 3 étapes (identité, apps, grades), modifier, dupliquer, archiver / restaurer, exporter et importer en fichier.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §6.2 (CreateJob, SaveGrades), §3.7 (upload latent), §10 (risque 12 : actions longues).
- `/mnt/project-files/pop_tablet/specs/05-sites-admin-apps-perso.md` : seulement les fiches SITE-CRE-04 à 11 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Admin).

Fiches à implémenter entièrement (8) : SITE-CRE-04, SITE-CRE-05, SITE-CRE-06, SITE-CRE-07, SITE-CRE-08, SITE-CRE-09, SITE-CRE-10, SITE-CRE-11.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S09, S07.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Métiers et grades créés sur le framework et gardés (`company_grades.managed`), import en deux temps (ticket puis push), fichiers dans `data/exports` et `data/imports`.
- Test en jeu que le client fera : (1) Admin > Entreprises > Créer → 3 étapes → la nouvelle entreprise existe avec son métier. / (2) La dupliquer puis l'archiver → elle disparaît des listes, restaurable. / (3) Exporter une entreprise puis l'importer → copie identique.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-23-createur` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 23 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Admin > Entreprises > Créer → 3 étapes → la nouvelle entreprise existe avec son métier. / (2) La dupliquer puis l'archiver → elle disparaît des listes, restaurable. / (3) Exporter une entreprise puis l'importer → copie identique.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S24 · Éditeur de site 1 : blocs et publication

Dépend de : S09 · Durée : 1 · Fiches : SITE-EDI-01 à 09, SITE-EDI-17, SITE-EDI-19

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 24 du plan de la tablette POP : « Éditeur de site 1 : blocs et publication ».

Objectif : Construire un site : adresse `.rp`, modèle, catalogue de blocs, ajouter / déplacer / modifier / supprimer un bloc, aperçu, publication, images autorisées, verrou d'édition.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §3.6 (sites, budget chunk 90 Ko), §4.3 (sites, site_versions), §5.1 (cache des sites).
- `/mnt/project-files/pop_tablet/specs/05-sites-admin-apps-perso.md` : seulement les fiches SITE-EDI-01 à 09, SITE-EDI-17, SITE-EDI-19 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (éditeur, sites).

Fiches à implémenter entièrement (11) : SITE-EDI-01, SITE-EDI-02, SITE-EDI-03, SITE-EDI-04, SITE-EDI-05, SITE-EDI-06, SITE-EDI-07, SITE-EDI-08, SITE-EDI-09, SITE-EDI-17, SITE-EDI-19.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S09.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Blocs validés par le serveur (64 Ko, 30 blocs / page), images seulement des domaines autorisés, un seul éditeur à la fois.
- Test en jeu que le client fera : (1) Éditeur de site → choisir l'adresse « garage.rp » et un modèle. / (2) Ajouter 3 blocs, en déplacer un, modifier un texte → aperçu. / (3) Publier → message de succès ; un deuxième employé qui ouvre l'éditeur voit « En cours de modification ».

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-24-editeur-1` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 24 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Éditeur de site → choisir l'adresse « garage.rp » et un modèle. / (2) Ajouter 3 blocs, en déplacer un, modifier un texte → aperçu. / (3) Publier → message de succès ; un deuxième employé qui ouvre l'éditeur voit « En cours de modification ».
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S25 · Éditeur de site 2 : pages, versions, visites

Dépend de : S24, S15 · Durée : 1 · Fiches : SITE-EDI-10 à 16, SITE-EDI-18, SITE-EDI-20, SITE-EDI-21

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 25 du plan de la tablette POP : « Éditeur de site 2 : pages, versions, visites ».

Objectif : Compléter l'éditeur : pages (ajouter, renommer, réordonner, supprimer), historique et retour de version, visites, API de lecture neutre, formulaire de demande, réglages du site.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §5.2 (écritures groupées), §8.1.
- `/mnt/project-files/pop_tablet/specs/05-sites-admin-apps-perso.md` : seulement les fiches SITE-EDI-10 à 16, SITE-EDI-18, SITE-EDI-20, SITE-EDI-21 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (éditeur).

Fiches à implémenter entièrement (10) : SITE-EDI-10, SITE-EDI-11, SITE-EDI-12, SITE-EDI-13, SITE-EDI-14, SITE-EDI-15, SITE-EDI-16, SITE-EDI-18, SITE-EDI-20, SITE-EDI-21.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S24, S15.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : 20 versions max, visites comptées sans écriture à chaque vue (file groupée), réglages type / description / caché / maintenance lus par l'API neutre.
- Test en jeu que le client fera : (1) Ajouter une page « Tarifs » et la placer en 2e. / (2) Historique → revenir à la version précédente. / (3) Ajouter un bloc formulaire → l'envoyer → la demande arrive dans la boîte Demandes de l'entreprise.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-25-editeur-2` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 25 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Ajouter une page « Tarifs » et la placer en 2e. / (2) Historique → revenir à la version précédente. / (3) Ajouter un bloc formulaire → l'envoyer → la demande arrive dans la boîte Demandes de l'entreprise.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S26 · Navigateur

Dépend de : S25 · Durée : 1 · Fiches : NAV-01 à 12

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 26 du plan de la tablette POP : « Navigateur ».

Objectif : Naviguer sur les sites de la ville : chargement page par page, barre d'adresse et suggestions, moteur de recherche fictif, sites par type, favoris, historique, 3 onglets, sites cachés, pages introuvable / maintenance, boutons de navigation.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §3.6 (nav), §4.3 (nav_history, nav_favorites).
- `/mnt/project-files/pop_tablet/specs/06-outils-navigateur-gestion-pro.md` : seulement les fiches NAV-01 à 12 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : capture 08-navigateur-dynasty8.png ; maquette.html (Navigateur).

Fiches à implémenter entièrement (12) : NAV-01, NAV-02, NAV-03, NAV-04, NAV-05, NAV-06, NAV-07, NAV-08, NAV-09, NAV-10, NAV-11, NAV-12.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S25.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Une page envoyée à la fois depuis le cache serveur, favoris et historique attachés au numéro de série, contenu joueur affiché en texte seulement (xss.spec).
- Test en jeu que le client fera : (1) Navigateur → taper « garage.rp » → le site s'affiche. / (2) Ajouter en favori, ouvrir un 2e onglet, faire Précédent / Suivant. / (3) Taper une adresse qui n'existe pas → page « site introuvable ».

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-26-navigateur` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 26 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Navigateur → taper « garage.rp » → le site s'affiche. / (2) Ajouter en favori, ouvrir un 2e onglet, faire Précédent / Suivant. / (3) Taper une adresse qui n'existe pas → page « site introuvable ».
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S27 · Annuaire et modération

Dépend de : S26, S15 · Durée : 1 · Fiches : ANNU-01 à 05, ADM-09, ADM-10, ADM-16

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 27 du plan de la tablette POP : « Annuaire et modération ».

Objectif : Annuaire des entreprises (statut ouvert / fermé, fiche, lien vers le site, demande de contact) et modération (signaler, masquer, restaurer un site ou une annonce).

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §3.6 (directory, reports), §4.3 (reports).
- `/mnt/project-files/pop_tablet/specs/06-outils-navigateur-gestion-pro.md` : seulement les fiches ANNU-01 à 05 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- `/mnt/project-files/pop_tablet/specs/05-sites-admin-apps-perso.md` : seulement les fiches ADM-09, ADM-10, ADM-16 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Annuaire, Admin).

Fiches à implémenter entièrement (8) : ANNU-01, ANNU-02, ANNU-03, ANNU-04, ANNU-05, ADM-09, ADM-10, ADM-16.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S26, S15.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Statut calculé depuis la seule table de service, masquage visible par l'admin seulement, signaux `siteHidden` / `siteRestored`, tout journalisé.
- Test en jeu que le client fera : (1) Annuaire → la police apparaît « Ouvert » quand un agent est en service. / (2) Fiche d'une entreprise → « Voir le site » puis « Demande de contact » → la demande arrive. / (3) Signaler un site ; l'admin le masque puis le restaure.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-27-annuaire-moderation` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 27 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Annuaire → la police apparaît « Ouvert » quand un agent est en service. / (2) Fiche d'une entreprise → « Voir le site » puis « Demande de contact » → la demande arrive. / (3) Signaler un site ; l'admin le masque puis le restaure.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S28 · Notes et calculatrice

Dépend de : S04 · Durée : 1 · Fiches : OUT-NOT-01 à 08, OUT-CAL-01 à 08

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 28 du plan de la tablette POP : « Notes et calculatrice ».

Objectif : Livrer deux outils simples : Notes (liste, création, modification, recherche, épingler, supprimer, partager et recevoir) et Calculatrice (opérations, priorités, %, ±, erreurs, historique, clavier).

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §3.6 (notes, calc offline), §4.3 (notes).
- `/mnt/project-files/pop_tablet/specs/06-outils-navigateur-gestion-pro.md` : seulement les fiches OUT-NOT-01 à 08, OUT-CAL-01 à 08 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Notes).

Fiches à implémenter entièrement (16) : OUT-NOT-01, OUT-NOT-02, OUT-NOT-03, OUT-NOT-04, OUT-NOT-05, OUT-NOT-06, OUT-NOT-07, OUT-NOT-08, OUT-CAL-01, OUT-CAL-02, OUT-CAL-03, OUT-CAL-04, OUT-CAL-05, OUT-CAL-06, OUT-CAL-07, OUT-CAL-08.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S04.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Notes attachées au numéro de série, calculatrice 100 % NUI hors ligne avec tests unitaires du moteur.
- Test en jeu que le client fera : (1) Notes → créer une note, l'épingler, la retrouver par la recherche. / (2) Partager la note avec un joueur proche → il la reçoit. / (3) Calculatrice → 2 + 3 × 4 = 14 au clavier physique ; 1 ÷ 0 → message d'erreur.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-28-notes-calc` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 28 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Notes → créer une note, l'épingler, la retrouver par la recherche. / (2) Partager la note avec un joueur proche → il la reçoit. / (3) Calculatrice → 2 + 3 × 4 = 14 au clavier physique ; 1 ÷ 0 → message d'erreur.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S29 · Carte et galerie

Dépend de : S04 · Durée : 1 (longue) · Fiches : OUT-CAR-01 à 05, OUT-GAL-01 à 08

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 29 du plan de la tablette POP : « Carte et galerie ».

Objectif : Carte de la ville (points utiles, GPS en un clic, mes points, recherche) et Galerie (appareil photo, stockage sans exposer l'IP, grille et visionneuse, albums, suppression, envoi vers une app, image par lien, quota).

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §1.2 (server/core/media.lua, client/photo.lua, map.lua), §3.7 (upload), §10 (risque 8).
- `/mnt/project-files/pop_tablet/specs/06-outils-navigateur-gestion-pro.md` : seulement les fiches OUT-CAR-01 à 05, OUT-GAL-01 à 08 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Galerie).

Fiches à implémenter entièrement (13) : OUT-CAR-01, OUT-CAR-02, OUT-CAR-03, OUT-CAR-04, OUT-CAR-05, OUT-GAL-01, OUT-GAL-02, OUT-GAL-03, OUT-GAL-04, OUT-GAL-05, OUT-GAL-06, OUT-GAL-07, OUT-GAL-08.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S04.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Photos sur le disque du serveur (`data/photos`), envoi latent, cache images borné à 32 Mo serveur / 40 entrées NUI, fil client seulement en mode photo.
- Test en jeu que le client fera : (1) Carte → cliquer un point utile → GPS posé. / (2) Galerie → prendre une photo → elle apparaît dans la grille. / (3) Envoyer la photo dans une note ou un rapport → elle s'y affiche (`media:<id>`).

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-29-carte-galerie` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 29 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Carte → cliquer un point utile → GPS posé. / (2) Galerie → prendre une photo → elle apparaît dans la grille. / (3) Envoyer la photo dans une note ou un rapport → elle s'y affiche (`media:<id>`).
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S30 · Apps perso : moteur

Dépend de : S08 · Durée : 1 · Fiches : BASE-API-01, PERSO-01, PERSO-02, PERSO-04 à 06, PERSO-09

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 30 du plan de la tablette POP : « Apps perso : moteur ».

Objectif : Permettre aux acheteurs d'ajouter leurs apps : dossier `apps_perso/` détecté, modèle vide, SDK `PopApp`, objet serveur `App` en environnement fermé, isolation des données, kit de style des apps perso.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §2.7, §7.3, §8.3, §8.4, §0.2 (A1, A2, A6, A13, A20).
- `/mnt/project-files/pop_tablet/specs/01-base.md` : seulement les fiches BASE-API-01 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- `/mnt/project-files/pop_tablet/specs/05-sites-admin-apps-perso.md` : seulement les fiches PERSO-01, PERSO-02, PERSO-04 à 06, PERSO-09 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (kit).

Fiches à implémenter entièrement (7) : BASE-API-01, PERSO-01, PERSO-02, PERSO-04, PERSO-05, PERSO-06, PERSO-09.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S08.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Iframe `sandbox="allow-scripts"` sans `allow-same-origin`, appId pris de la table et jamais du message, `while true` coupé, e2e perso.spec vert.
- Test en jeu que le client fera : (1) Copier `_modele` en `ma_app` (Claude le fait) puis `restart pop_tablet` → l'icône apparaît. / (2) L'ouvrir → l'écran de l'app s'affiche dans le style de la tablette. / (3) Bouton de l'app qui enregistre une valeur → valeur relue après fermeture.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-30-perso-moteur` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 30 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Copier `_modele` en `ma_app` (Claude le fait) puis `restart pop_tablet` → l'icône apparaît. / (2) L'ouvrir → l'écran de l'app s'affiche dans le style de la tablette. / (3) Bouton de l'app qui enregistre une valeur → valeur relue après fermeture.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S31 · Apps perso : guide IA, exemples, vérificateur

Dépend de : S30 · Durée : 1 · Fiches : PERSO-03, PERSO-07, PERSO-08

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 31 du plan de la tablette POP : « Apps perso : guide IA, exemples, vérificateur ».

Objectif : Rendre les apps perso faciles à créer avec une IA : guide `CLAUDE.md` livré, 3 apps d'exemple, outil de vérification `pop-check` (Node et Lua, même résultat).

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §8.5, §8.6, §9.1 (étape 8).
- `/mnt/project-files/pop_tablet/specs/05-sites-admin-apps-perso.md` : seulement les fiches PERSO-03, PERSO-07, PERSO-08 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.

Fiches à implémenter entièrement (3) : PERSO-03, PERSO-07, PERSO-08.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S30.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : `node tools/pop-check.js apps_perso` : 0 bloquant, 0 alerte ; parité Node / Lua sur les fixtures ; `pop_tablet/CLAUDE.md` ≤ 300 lignes, FR puis EN, sections de §8.6.
- Test en jeu que le client fera : (1) Les 3 apps d'exemple (notes, tableau, pourboire) apparaissent sur le bureau. / (2) Exemple pourboire → donner 5 $ à un joueur proche → reçu une seule fois. / (3) Admin > Apps → couper une app d'exemple → elle disparaît du bureau.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-31-perso-outils` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 31 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Les 3 apps d'exemple (notes, tableau, pourboire) apparaissent sur le bureau. / (2) Exemple pourboire → donner 5 $ à un joueur proche → reçu une seule fois. / (3) Admin > Apps → couper une app d'exemple → elle disparaît du bureau.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S32 · Tableur 1 : feuilles et formules

Dépend de : S09 · Durée : 1 · Fiches : PRO-TAB-01 à 07, PRO-TAB-15

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 32 du plan de la tablette POP : « Tableur 1 : feuilles et formules ».

Objectif : Tableur d'entreprise : liste des feuilles, création (vide ou modèle), modèles, cellules typées, gras et couleur, largeur des colonnes, formules, insertion / suppression de lignes et colonnes.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §2.2 (formula.ts, A21), §4.3 (sheets, sheet_cells), §1.2 (defaults/sheet_templates.lua).
- `/mnt/project-files/pop_tablet/specs/06-outils-navigateur-gestion-pro.md` : seulement les fiches PRO-TAB-01 à 07, PRO-TAB-15 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Tableur).

Fiches à implémenter entièrement (8) : PRO-TAB-01, PRO-TAB-02, PRO-TAB-03, PRO-TAB-04, PRO-TAB-05, PRO-TAB-06, PRO-TAB-07, PRO-TAB-15.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S09.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Moteur de formules pur et testé (`formula.ts`), 200 × 26 par défaut, grille et formules en LTR même en arabe, chunk ≤ 80 Ko.
- Test en jeu que le client fera : (1) Tableur → créer une feuille depuis un modèle. / (2) Taper des montants puis `=SOMME(B2:B5)` → total correct. / (3) Insérer une ligne au milieu → la formule s'ajuste.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-32-tableur-1` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 32 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Tableur → créer une feuille depuis un modèle. / (2) Taper des montants puis `=SOMME(B2:B5)` → total correct. / (3) Insérer une ligne au milieu → la formule s'ajuste.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S33 · Tableur 2 : travail à plusieurs

Dépend de : S32, S13 · Durée : 1 · Fiches : PRO-TAB-08 à 14

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 33 du plan de la tablette POP : « Tableur 2 : travail à plusieurs ».

Objectif : Tableur partagé : import automatique (factures payées, mouvements du compte), droits par grade, verrou de cellule, modifications en direct, taille réglable, annuler / rétablir, renommer / dupliquer / archiver.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §3.4, §3.5, §5.2.
- `/mnt/project-files/pop_tablet/specs/06-outils-navigateur-gestion-pro.md` : seulement les fiches PRO-TAB-08 à 14 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Tableur).

Fiches à implémenter entièrement (7) : PRO-TAB-08, PRO-TAB-09, PRO-TAB-10, PRO-TAB-11, PRO-TAB-12, PRO-TAB-13, PRO-TAB-14.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S32, S13.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Push ciblé aux seuls lecteurs de la feuille, 20 / 5 s par cellule, verrou libéré à la fermeture, droits `tableur.*` respectés.
- Test en jeu que le client fera : (1) Deux employés ouvrent la même feuille → la saisie de l'un apparaît chez l'autre. / (2) Activer l'import des factures payées → payer une facture → la ligne arrive dans la feuille. / (3) Ctrl+Z / Ctrl+Y → annuler puis rétablir.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-33-tableur-2` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 33 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Deux employés ouvrent la même feuille → la saisie de l'un apparaît chez l'autre. / (2) Activer l'import des factures payées → payer une facture → la ligne arrive dans la feuille. / (3) Ctrl+Z / Ctrl+Y → annuler puis rétablir.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S34 · Stock

Dépend de : S09, S13 · Durée : 1 · Fiches : PRO-STO-01 à 10

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 34 du plan de la tablette POP : « Stock ».

Objectif : Stock d'entreprise : articles, archivage, entrées, sorties, inventaire, historique, déduction automatique par facture, alerte de seuil, lien avec le coffre de l'inventaire si possible.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §4.3 (stock_items, stock_moves), §6.3 (inventaire).
- `/mnt/project-files/pop_tablet/specs/06-outils-navigateur-gestion-pro.md` : seulement les fiches PRO-STO-01 à 10 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Stock).

Fiches à implémenter entièrement (10) : PRO-STO-01, PRO-STO-02, PRO-STO-03, PRO-STO-04, PRO-STO-05, PRO-STO-06, PRO-STO-07, PRO-STO-08, PRO-STO-09, PRO-STO-10.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S09, S13.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Stock jamais négatif (s'arrête à 0, manque noté et signalé), historique complet, lien coffre seulement si l'inventaire le permet.
- Test en jeu que le client fera : (1) Stock → créer l'article « Pneu » avec seuil 5. / (2) Faire une entrée de 10 puis une sortie de 7 → alerte de seuil. / (3) Activer la déduction par facture → une facture avec 2 pneus fait baisser le stock.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-34-stock` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 34 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Stock → créer l'article « Pneu » avec seuil 5. / (2) Faire une entrée de 10 puis une sortie de 7 → alerte de seuil. / (3) Activer la déduction par facture → une facture avec 2 pneus fait baisser le stock.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S35 · Planning

Dépend de : S09 · Durée : 1 · Fiches : PRO-PLA-01 à 07

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 35 du plan de la tablette POP : « Planning ».

Objectif : Planning d'équipe : vue, horloge du mode heure du jeu, créneaux, affectations, disponibilités et absences, rappels, présence comparée aux prises de service.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §5.4 (rappels du Planning), §4.3 (planning_*, connections), §0.2 (A7).
- `/mnt/project-files/pop_tablet/specs/06-outils-navigateur-gestion-pro.md` : seulement les fiches PRO-PLA-01 à 07 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Planning).

Fiches à implémenter entièrement (7) : PRO-PLA-01, PRO-PLA-02, PRO-PLA-03, PRO-PLA-04, PRO-PLA-05, PRO-PLA-06, PRO-PLA-07.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S09.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Rappels par l'ordonnanceur unique (aucune minuterie quotidienne), présence lue dans la seule table de service (`debut` / `fin`).
- Test en jeu que le client fera : (1) Planning → créer un créneau demain 20 h et y affecter un employé. / (2) L'employé déclare une absence → visible sur le créneau. / (3) Prendre son service pendant le créneau → présence affichée « À l'heure ».

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-35-planning` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 35 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Planning → créer un créneau demain 20 h et y affecter un employé. / (2) L'employé déclare une absence → visible sur le créneau. / (3) Prendre son service pendant le créneau → présence affichée « À l'heure ».
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S36 · EMS 1 : service, alertes, dossiers

Dépend de : S17, S15 · Durée : 1 · Fiches : MET-EMS-01 à 08

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 36 du plan de la tablette POP : « EMS 1 : service, alertes, dossiers ».

Objectif : App EMS : service et effectifs, alertes « joueur à terre », prise en charge avec GPS, dossier médical (lecture, écriture), rapport d'intervention et son modèle.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §6.2 (OnPlayerDeath, OnPlayerRevived), §3.7 (bridge:died / revived), §4.3 (ems_*).
- `/mnt/project-files/pop_tablet/specs/04-ems-mecano-justice-gang.md` : seulement les fiches MET-EMS-01 à 08 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (EMS).

Fiches à implémenter entièrement (8) : MET-EMS-01, MET-EMS-02, MET-EMS-03, MET-EMS-04, MET-EMS-05, MET-EMS-06, MET-EMS-07, MET-EMS-08.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S17, S15.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Mort / réveil détectés par le bridge sans boucle (ESX, QBCore, Qbox par mocks), alerte au format DispatchAlert, `/secours` fonctionnel.
- Test en jeu que le client fera : (1) Prendre son service EMS. / (2) Un joueur tombe à terre → alerte reçue → accepter → GPS. / (3) Ouvrir son dossier médical, l'éditer, rédiger le rapport d'intervention.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-36-ems-1` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 36 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Prendre son service EMS. / (2) Un joueur tombe à terre → alerte reçue → accepter → GPS. / (3) Ouvrir son dossier médical, l'éditer, rédiger le rapport d'intervention.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S37 · EMS 2 : soins, certificats, rendez-vous, tri

Dépend de : S36, S12 · Durée : 1 · Fiches : MET-EMS-09 à 17

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 37 du plan de la tablette POP : « EMS 2 : soins, certificats, rendez-vous, tri ».

Objectif : Facturer les soins et régler les tarifs, certificats d'aptitude et de décès (et révocation), heures de service, rendez-vous depuis le site de l'hôpital, tri des blessés partagé avec la police.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §4.3 (ems_certificates, appointments, ems_triage*), §8.1.
- `/mnt/project-files/pop_tablet/specs/04-ems-mecano-justice-gang.md` : seulement les fiches MET-EMS-09 à 17 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (EMS).

Fiches à implémenter entièrement (9) : MET-EMS-09, MET-EMS-10, MET-EMS-11, MET-EMS-12, MET-EMS-13, MET-EMS-14, MET-EMS-15, MET-EMS-16, MET-EMS-17.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S36, S12.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Tarifs depuis `defaults/price_lists.lua`, export `GetCertificate`, 3 afflux max / 60 victimes / fermeture auto 6 h par l'ordonnanceur.
- Test en jeu que le client fera : (1) Facturer des soins à un joueur proche depuis la grille des tarifs. / (2) Délivrer un certificat d'aptitude port d'arme → visible par la police sur la fiche citoyen. / (3) Ouvrir un afflux de blessés, ajouter un blessé « rouge » → la police le voit.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-37-ems-2` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 37 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Facturer des soins à un joueur proche depuis la grille des tarifs. / (2) Délivrer un certificat d'aptitude port d'arme → visible par la police sur la fiche citoyen. / (3) Ouvrir un afflux de blessés, ajouter un blessé « rouge » → la police le voit.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S38 · Mécano et Carnet auto

Dépend de : S15, S12, S34 · Durée : 1 (longue) · Fiches : MET-MEC-01 à 11

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 38 du plan de la tablette POP : « Mécano et Carnet auto ».

Objectif : App Mécano : service, dépannages par la boîte Demandes, diagnostic, carnet d'entretien simple, devis (création, réponse, facture en 1 clic), catalogue relié au stock, et app « Carnet auto » côté propriétaire.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §1.2 (bridge/fuel/), §6.3 (essence), §4.3 (vehicle_logbook, quotes, mech_catalog).
- `/mnt/project-files/pop_tablet/specs/04-ems-mecano-justice-gang.md` : seulement les fiches MET-MEC-01 à 11 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Mécano).

Fiches à implémenter entièrement (11) : MET-MEC-01, MET-MEC-02, MET-MEC-03, MET-MEC-04, MET-MEC-05, MET-MEC-06, MET-MEC-07, MET-MEC-08, MET-MEC-09, MET-MEC-10, MET-MEC-11.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S15, S12, S34.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Aucun drapeau « volé », carnet lisible par la police seulement si réglé, catalogue qui fait baisser le stock, adaptateurs essence (ox_fuel, LegacyFuel, cdn-fuel, ps-fuel, natif).
- Test en jeu que le client fera : (1) Accepter un dépannage depuis Demandes → GPS ; diagnostiquer le véhicule proche. / (2) Créer un devis → le client l'accepte → « Facturer » en 1 clic. / (3) Côté propriétaire : app Carnet auto → l'entrée d'entretien est là.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-38-mecano` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 38 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Accepter un dépannage depuis Demandes → GPS ; diagnostiquer le véhicule proche. / (2) Créer un devis → le client l'accepte → « Facturer » en 1 clic. / (3) Côté propriétaire : app Carnet auto → l'entrée d'entretien est là.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S39 · Justice 1 : affaires, audiences, verdicts

Dépend de : S20, S19 · Durée : 1 · Fiches : MET-JUS-01 à 07

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 39 du plan de la tablette POP : « Justice 1 : affaires, audiences, verdicts ».

Objectif : App Justice : service, ouverture d'une affaire, liaison des rapports et preuves de la police, consultation selon le rôle, audiences, verdict (casier + peine), validation des mandats.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §4.3 (justice_*, police_mandats), §8.1, §8.2.
- `/mnt/project-files/pop_tablet/specs/04-ems-mecano-justice-gang.md` : seulement les fiches MET-JUS-01 à 07 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Justice).

Fiches à implémenter entièrement (7) : MET-JUS-01, MET-JUS-02, MET-JUS-03, MET-JUS-04, MET-JUS-05, MET-JUS-06, MET-JUS-07.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S20, S19.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Verdict unique par affaire, signal `sentencePronounced` partagé avec la police, rôles avocat / procureur / juge réglés par l'assistant (Tribunal, Cabinet).
- Test en jeu que le client fera : (1) En procureur : ouvrir une affaire et y lier un rapport de police. / (2) En juge : planifier une audience puis prononcer un verdict → casier du joueur mis à jour. / (3) En juge : signer un mandat de perquisition demandé par la police.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-39-justice-1` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 39 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) En procureur : ouvrir une affaire et y lier un rapport de police. / (2) En juge : planifier une audience puis prononcer un verdict → casier du joueur mis à jour. / (3) En juge : signer un mandat de perquisition demandé par la police.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S40 · Justice 2 et Immobilier

Dépend de : S39, S21 · Durée : 1 · Fiches : MET-JUS-08 à 13, MET-IMM-01, MET-IMM-02

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 40 du plan de la tablette POP : « Justice 2 et Immobilier ».

Objectif : Avocats (clients, honoraires), effacement de casier, classement sans suite, contestation de preuve, accord de repenti ; cadastre et enregistrement des ventes immobilières.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §4.3 (justice_contests, justice_deals, immo_*), §8.1.
- `/mnt/project-files/pop_tablet/specs/04-ems-mecano-justice-gang.md` : seulement les fiches MET-JUS-08 à 13, MET-IMM-01, MET-IMM-02 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : maquette.html (Justice).

Fiches à implémenter entièrement (8) : MET-JUS-08, MET-JUS-09, MET-JUS-10, MET-JUS-11, MET-JUS-12, MET-JUS-13, MET-IMM-01, MET-IMM-02.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S39, S21.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Réduction de repenti 10 à 75 %, effacement = archivage, exports `GetPropertyOwner` / `GetPropertiesOf`.
- Test en jeu que le client fera : (1) En avocat : facturer des honoraires à un client. / (2) Contester une preuve → le juge tranche → la preuve devient irrecevable. / (3) Immobilier : créer un bien, enregistrer une vente par un vendeur qui n'est pas le propriétaire → alerte.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-40-justice-2-immo` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 40 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) En avocat : facturer des honoraires à un client. / (2) Contester une preuve → le juge tranche → la preuve devient irrecevable. / (3) Immobilier : créer un bien, enregistrer une vente par un vendeur qui n'est pas le propriétaire → alerte.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S41 · Gang et infiltration

Dépend de : S20, S39, S09 · Durée : 1 (longue) · Fiches : MET-GANG-01 à 04, MET-GANG-06 à 11, MET-POL-47

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 41 du plan de la tablette POP : « Gang et infiltration ».

Objectif : App Gang déguisée : membres et rangs, recrutement, exclusion, messagerie jamais effacée, coffre d'argent sale, territoires, icône déguisée et ouverture par code, livre de comptes ; infiltration de la messagerie par la police sous mandat signé.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §6.2 (argent sale, gang natif), §4.3 (gang_*, police_infiltration_journal).
- `/mnt/project-files/pop_tablet/specs/04-ems-mecano-justice-gang.md` : seulement les fiches MET-GANG-01 à 04, MET-GANG-06 à 11 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- `/mnt/project-files/pop_tablet/specs/03-police.md` : seulement les fiches MET-POL-47 (Grep `^### \[ID\]` pour trouver le début de chaque fiche, lis jusqu'à la suivante), plus la section « Décisions prises par défaut » du fichier.
- Design (`/mnt/project-files/pop_tablet/design/`) : capture 09-meteo-code.png ; maquette.html (Météo).

Fiches à implémenter entièrement (11) : MET-GANG-01, MET-GANG-02, MET-GANG-03, MET-GANG-04, MET-GANG-06, MET-GANG-07, MET-GANG-08, MET-GANG-09, MET-GANG-10, MET-GANG-11, MET-POL-47.
Pour chaque fiche : comportement, textes exacts, réglages, droits, cas limites et critères d'acceptation tels qu'écrits. Organise le travail comme `docs/methode.md` : petit contrat d'abord (actions, schémas, pushes, clés de langue), puis serveur, client et NUI en parallèle par sous-agents, puis relecture par `fivem-auditeur` et corrections avant la fusion.
Dépendances déjà livrées : S20, S39, S09.

À livrer :
- Le code serveur, client et NUI des fiches ci-dessus, leurs clés de langue fr et en, leurs tests (unitaires Lua et e2e), leurs commandes de test éventuelles dans `pop_tablet_devtest`.
- Critère de fin : Argent sale par framework (`black_money` ou `markedbills`), plafond 10 000 $ par retrait et 3 / 24 h, messages jamais purgés, lecture d'infiltration seulement après signature.
- Test en jeu que le client fera : (1) L'app Gang apparaît comme « Météo » ; appui long sur le champ caché + code → l'app s'ouvre. / (2) Déposer 1 000 $ d'argent sale au coffre puis en retirer 500 $ (Lieutenant). / (3) Police : mandat d'infiltration signé par un juge → la police lit les messages à partir de la signature.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-41-gang` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 41 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) L'app Gang apparaît comme « Météo » ; appui long sur le champ caché + code → l'app s'ouvre. / (2) Déposer 1 000 $ d'argent sale au coffre puis en retirer 500 $ (Lieutenant). / (3) Police : mandat d'infiltration signé par un juge → la police lit les messages à partir de la signature.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S42 · Traductions des 10 langues

Dépend de : S40, S41 · Durée : 1 · Fiches : aucune nouvelle

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 42 du plan de la tablette POP : « Traductions des 10 langues ».

Objectif : Traduire toutes les clés dans les 10 langues de sortie (en, pt-BR, fr, ar, de, th, tr, es, id, ro) et valider l'arabe (RTL) et le thaï sur tous les écrans.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §2.6, §9.1 (étape 10), §10 (risque 10).
- Design (`/mnt/project-files/pop_tablet/design/`) : capture 02-accueil-arabe.png.

Cette session ne crée pas de nouvelle fiche : elle vérifie, corrige et prépare la livraison. Aucune fonction nouvelle hors de ce qui est décrit ci-dessous.
Dépendances déjà livrées : S40, S41.

Points propres à cette session :
- Prérequis : toutes les sessions S01 à S41 sont faites (tous les textes fr et en existent).
- Traduis à partir du français (référence) ; garde les paramètres `{nom}` et `%s` intacts ; ton neutre et poli dans chaque langue (équivalent du style Apple).
- Découpe le travail par langue avec des sous-agents en parallèle (une langue par agent), puis fais vérifier chaque fichier par un autre agent.

À livrer :
- Critère de fin : `locales.lua` : 0 clé manquante dans les 10 langues ; e2e rtl.spec sur un écran par app en fr, de, ar, th ; aucun texte en dur.
- Test en jeu que le client fera : (1) Réglages → Deutsch → les écrans longs (Police, Factures) ne débordent pas. / (2) Réglages → العربية → tout est inversé, montants et plaques restent lisibles. / (3) Réglages → ไทย → aucun carré vide à la place des lettres.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-42-langues` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 42 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Réglages → Deutsch → les écrans longs (Police, Factures) ne débordent pas. / (2) Réglages → العربية → tout est inversé, montants et plaques restent lisibles. / (3) Réglages → ไทย → aucun carré vide à la place des lettres.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S43 · Recette complète sur ESX

Dépend de : S42 · Durée : 1 (longue) · Fiches : aucune nouvelle

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 43 du plan de la tablette POP : « Recette complète sur ESX ».

Objectif : Passer la grille de recette complète sur le serveur ESX de test (fiches, deux joueurs, triche, performance, adaptateurs) et corriger tout ce qui casse.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §9.5 (recette en jeu), §7 (tout), §10.

Cette session ne crée pas de nouvelle fiche : elle vérifie, corrige et prépare la livraison. Aucune fonction nouvelle hors de ce qui est décrit ci-dessous.
Dépendances déjà livrées : S42.

Points propres à cette session :
- Génère `tests/pop_tablet/recette.csv` (une ligne par critère d'acceptation × framework) et sa version lisible pour le client `docs/pop_tablet-recette.md` (cases à cocher, phrases simples).
- Complète `pop_tablet_devtest` avec `/devtest_triche` (événements forgés, faux jetons, montants négatifs, actionId rejoué, cible lointaine, rafale de 1 000 requêtes).
- Vérifie en premier les valeurs dépendant des scripts installés (sommaire §5, tableau final) sur le serveur ESX.

À livrer :
- Critère de fin : Grille ESX entièrement verte, ressource de triche 100 % refusée, mesure resmon notée dans le suivi.
- Test en jeu que le client fera : (1) Suivre la check-list `docs/pop_tablet-recette.md` générée (une case par critère) : le client coche ce qu'il voit. / (2) `resmon 1` après 50 ouvertures / fermetures → 0,00 ms tablette fermée. / (3) `/devtest_triche` → toutes les attaques sont refusées et apparaissent dans Admin > Journal.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-43-recette-esx` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 43 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Suivre la check-list `docs/pop_tablet-recette.md` générée (une case par critère) : le client coche ce qu'il voit. / (2) `resmon 1` après 50 ouvertures / fermetures → 0,00 ms tablette fermée. / (3) `/devtest_triche` → toutes les attaques sont refusées et apparaissent dans Admin > Journal.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S44 · Recette sur QBCore

Dépend de : S43 · Durée : 1 · Fiches : aucune nouvelle

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 44 du plan de la tablette POP : « Recette sur QBCore ».

Objectif : Passer la même grille sur un serveur QBCore (qb-inventory, qb-target, qb-banking / qb-management, qb-prison) et corriger les écarts dans le bridge seulement.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §6 (tout), §9.5, §10 (risque 1).

Cette session ne crée pas de nouvelle fiche : elle vérifie, corrige et prépare la livraison. Aucune fonction nouvelle hors de ce qui est décrit ci-dessous.
Dépendances déjà livrées : S43.

Points propres à cette session :
- Prérequis : un serveur de test QBCore accessible. S'il n'existe pas, prépare d'abord un guide pas à pas pour le client (txAdmin, recette QBCore officielle, ressources à ajouter, secrets GitHub à créer pour le déploiement) et arrête-toi là : n'invente jamais un résultat de test.

À livrer :
- Critère de fin : Grille QBCore verte avec les mêmes critères qu'ESX ; tous les correctifs dans `bridge/` ; mocks QBCore mis à jour.
- Test en jeu que le client fera : (1) Ouvrir la tablette sur le serveur QBCore → bureau et entreprises par défaut reliées. / (2) Facture, service et compte d'entreprise → même résultat que sur ESX. / (3) Mort puis réveil d'un joueur → alerte EMS une seule fois.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-44-recette-qbcore` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 44 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Ouvrir la tablette sur le serveur QBCore → bureau et entreprises par défaut reliées. / (2) Facture, service et compte d'entreprise → même résultat que sur ESX. / (3) Mort puis réveil d'un joueur → alerte EMS une seule fois.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S45 · Recette sur Qbox

Dépend de : S43 · Durée : 1 · Fiches : aucune nouvelle

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 45 du plan de la tablette POP : « Recette sur Qbox ».

Objectif : Passer la même grille sur un serveur Qbox (ox_inventory, ox_target, Renewed-Banking, qbx_medical, qbx_vehicles) et corriger les écarts dans le bridge seulement.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §6 (tout), §9.5, §10 (risques 1 et 6).

Cette session ne crée pas de nouvelle fiche : elle vérifie, corrige et prépare la livraison. Aucune fonction nouvelle hors de ce qui est décrit ci-dessous.
Dépendances déjà livrées : S43.

Points propres à cette session :
- Même prérequis qu'en session 44 pour le serveur Qbox (guide pour le client s'il n'existe pas).

À livrer :
- Critère de fin : Grille Qbox verte ; valeurs du sommaire §5 (state bag `isDead`, prison Qbox, colonnes `player_vehicles`) vérifiées et corrigées dans leur seul fichier d'adaptateur.
- Test en jeu que le client fera : (1) Ouvrir la tablette sur le serveur Qbox → bureau et entreprises par défaut reliées. / (2) Compte d'entreprise via Renewed-Banking → dépôt / retrait corrects. / (3) Gang : coffre d'argent sale avec `markedbills` → montant juste.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-45-recette-qbox` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 45 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Ouvrir la tablette sur le serveur Qbox → bureau et entreprises par défaut reliées. / (2) Compte d'entreprise via Renewed-Banking → dépôt / retrait corrects. / (3) Gang : coffre d'argent sale avec `markedbills` → montant juste.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S46 · Audit final et couverture stricte

Dépend de : S44, S45 · Durée : 1 (longue) · Fiches : aucune nouvelle

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 46 du plan de la tablette POP : « Audit final et couverture stricte ».

Objectif : Audit complet par l'agent `fivem-auditeur` (sécurité, performance, cohérence, langues, simplicité) avec des sous-agents par branche, corrections, et couverture stricte des 360 fiches.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §7, §9 (tout), §10.

Cette session ne crée pas de nouvelle fiche : elle vérifie, corrige et prépare la livraison. Aucune fonction nouvelle hors de ce qui est décrit ci-dessous.
Dépendances déjà livrées : S44, S45.

Points propres à cette session :
- Lance un `fivem-auditeur` par branche (base, entreprises, police, métiers, sites, outils, pro, perso) en parallèle ; regroupe et corrige par gravité.
- Active `coverage.lua --strict` dans `verifier-pop-tablet.sh`.

À livrer :
- Critère de fin : Rapport d'audit sans point CRITIQUE ni IMPORTANT ouvert, `coverage.lua --strict` vert (360 IDs), `verifier-pop-tablet.sh` vert.
- Test en jeu que le client fera : (1) Rouvrir 5 apps au hasard → rien de cassé après les corrections. / (2) Admin > Performance → aucune action au-dessus de 5 ms en moyenne. / (3) `resmon 1` tablette fermée → 0,00 ms.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-46-audit` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 46 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Rouvrir 5 apps au hasard → rien de cassé après les corrections. / (2) Admin > Performance → aucune action au-dessus de 5 ms en moyenne. / (3) `resmon 1` tablette fermée → 0,00 ms.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S47 · Livraison Tebex : escrow, docs, guide IA

Dépend de : S46 · Durée : 1 · Fiches : aucune nouvelle

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 47 du plan de la tablette POP : « Livraison Tebex : escrow, docs, guide IA ».

Objectif : Préparer le paquet vendu : manifeste escrow, script de release (zip), documentation acheteur (installation 5 minutes, mise à jour, API, adaptateurs, kit de style), README, guide IA final.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §0.1 (D7), §1 (tout), §8 (tout).

Cette session ne crée pas de nouvelle fiche : elle vérifie, corrige et prépare la livraison. Aucune fonction nouvelle hors de ce qui est décrit ci-dessous.
Dépendances déjà livrées : S46.

Points propres à cette session :
- Le zip ne contient jamais `pop_tablet_devtest`, `ui/`, `tests/`, `data/`, ni lien Discord ; contrôle automatique dans le script.
- Vérifie avec `verifier-avant-affirmer` toute règle Tebex / escrow Cfx citée dans la doc (source officielle, date).

À livrer :
- Critère de fin : `scripts/release-tablette.sh` produit un zip sans `ui/`, `tests/`, devtest ni secret ; fichiers ouverts conformes à §1.2 (`escrow_ignore`) ; docs relues.
- Test en jeu que le client fera : (1) Le client télécharge le zip produit (artefact) et l'ouvre : dossiers `config.lua`, `docs/`, `apps_perso/` visibles. / (2) Installer le zip sur un serveur propre en suivant `docs/installation.md` → ressource prête en 5 minutes. / (3) Demander à une IA de créer une app perso avec le `CLAUDE.md` livré → elle passe `pop-check`.

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-47-tebex-livraison` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 47 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Le client télécharge le zip produit (artefact) et l'ouvre : dossiers `config.lua`, `docs/`, `apps_perso/` visibles. / (2) Installer le zip sur un serveur propre en suivant `docs/installation.md` → ressource prête en 5 minutes. / (3) Demander à une IA de créer une app perso avec le `CLAUDE.md` livré → elle passe `pop-check`.
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

### S48 · Page de vente Tebex

Dépend de : S47 · Durée : 1 · Fiches : aucune nouvelle

```text
Tu es Claude Code sur le dépôt `/home/user/pop-fivem`. Session 48 du plan de la tablette POP : « Page de vente Tebex ».

Objectif : Écrire la page de vente (FR et EN), la liste des fonctions par branche, la comparaison honnête, les captures et la vidéo à tourner, et la check-list de mise en ligne Tebex.

À lire d'abord (montage réseau : chemins exacts, barre finale sur les dossiers, ne parcours jamais tout /mnt/project-files) :
- Dépôt : `CLAUDE.md`, `docs/methode.md`, `.claude/agents/` (rôles fivem-architecte, dev-serveur, dev-client, dev-nui, auditeur), `docs/pop_tablet-suivi.md` (état des sessions précédentes ; absent en session 01).
- `/mnt/project-files/pop_tablet/specs/_contexte.md` et `/mnt/project-files/pop_tablet/specs/00-sommaire.md` (référentiel : noms, constantes, droits, décisions).
- `/mnt/project-files/pop_tablet/tech/10-technique.md` : §10 (pour les limites honnêtes).
- Design (`/mnt/project-files/pop_tablet/design/`) : design/20-design.md et captures pour le style des visuels.

Cette session ne crée pas de nouvelle fiche : elle vérifie, corrige et prépare la livraison. Aucune fonction nouvelle hors de ce qui est décrit ci-dessous.
Dépendances déjà livrées : S47.

Points propres à cette session :
- Tout chiffre (resmon, nombre d'apps, langues) vient d'une mesure ou d'un fichier du dépôt ; rien d'inventé.
- Le client publie lui-même sur Tebex : prépare tout, ne publie rien.

À livrer :
- Critère de fin : Page de vente FR / EN prête à coller, captures réelles, aucune promesse non vérifiée (perf mesurée en session 43, frameworks testés en 44 / 45).
- Test en jeu que le client fera : (1) Lire `docs/pop_tablet-vente.md` : le texte est clair pour un admin de serveur. / (2) Vérifier les captures proposées (une par branche) sur le serveur de test. / (3) Suivre la check-list de mise en ligne Tebex jusqu'au bouton « Publier » (le client publie lui-même).

Règles non négociables (projet vendu dans l'esprit « ~0,00 ms ») :
1. Performance : aucune boucle permanente ; tablette fermée = 0 fil client et serveur ; `CreateThread` et `SetTimeout` seulement dans les fichiers permis (tech §9.2) ; minuteries via l'ordonnanceur unique ; pagination 20 ; cache serveur et écritures groupées.
2. Sécurité : toute demande de la NUI passe par la porte unique `pop_tablet:request` (`Registry.Action` avec `schema`, `permission`, `rate`, `write` + `actionId`) ; le serveur revérifie montant, cible, distance, droit, service ; textes nettoyés et longueur max (refus `trop_long`, jamais coupés) ; SQL paramétré (`?`) ; `Log()` sur toute action sensible ; rien de sensible n'est supprimé (archivage) ; aucun secret dans le dépôt (convars).
3. Fichiers pop_base copiés jamais modifiés ; ESX / QBCore / Qbox seulement à travers `bridge/` (aucun `ESX.` ni `QBCore.` ailleurs).
4. Textes : aucune chaîne en dur ; clés dans `locales/fr/<app>.json` et `locales/en/<app>.json` ; ton style Apple (neutre, vouvoiement si besoin, jamais de tutoiement) ; CSS en propriétés logiques (RTL) ; couleurs seulement via `tokens.css`.
5. Chaque écran gère les 6 états (vide, chargement, succès, erreur, pas le droit, hors service) et respecte design/20-design.md et la maquette.
6. Chaque fiche implémentée porte un commentaire `-- [ID]` (Lua) ou `// [ID]` (TS) près de son code, et ses critères d'acceptation sont couverts par un test (Lua dans `tests/pop_tablet/`, Playwright dans `ui/pop_tablet/tests/e2e/apps/`). Ajoute ses IDs à `tests/pop_tablet/fiches_faites.txt`.
7. Reste dans ton périmètre : ton dossier `server/apps/<app>/`, ton dossier `ui/pop_tablet/src/apps/<app>/`, tes fichiers de langue, ta section de `config.lua`, ta ligne de `registry.ts`. Les noms publics, constantes et droits viennent du sommaire §3 (il fait foi) ; le technique vient de `10-technique.md` (il fait foi). En cas d'écart, applique la règle la plus prudente et note-la dans `docs/pop_tablet-suivi.md`.
8. Ne pose aucune question au client (il ne code pas) : décide, documente la décision dans le suivi, avance.

Vérification et livraison :
- Travaille sur la branche `session-48-page-vente` (worktree si d'autres sessions tournent en parallèle). Commits en anglais.
- Avant tout push : `bash scripts/verifier-pop-tablet.sh` doit être entièrement vert (luacheck 0/0, `luac5.4 -p`, tests Lua, build NUI et budgets, `node --check`, tests NUI, e2e, contrôles statiques, langues, couverture). Rien d'autre ne part sur `main` : seulement du code qui démarre sans erreur.
- Fusionne dans `main` (rebase sur `main` à jour, relance la vérification, puis push). Ne déploie pas : le client lance lui-même Actions > Deploy to test server > Run workflow.
- Mets à jour `docs/pop_tablet-suivi.md` (session 48 : faite, fiches livrées, écarts, décisions, commandes de test ajoutées).

Termine par un résumé en français simple pour le client (6 à 10 lignes, sans jargon technique) :
- ce qui marche maintenant dans la tablette ;
- les 3 gestes pour le vérifier en jeu après « Deploy to test server » : (1) Lire `docs/pop_tablet-vente.md` : le texte est clair pour un admin de serveur. / (2) Vérifier les captures proposées (une par branche) sur le serveur de test. / (3) Suivre la check-list de mise en ligne Tebex jusqu'au bouton « Publier » (le client publie lui-même).
- ce qui n'a pas pu être fait et pourquoi (s'il y en a) ;
- la prochaine session à lancer (numéro et titre, d'après le plan).
```

---

## 5. Total estimé et risques de planning

**Total prévu : 48 sessions** (dont 7 longues), 360 fiches actives réparties dans 41 sessions de construction et 7 sessions de finition et de vente.

**Total réaliste : 55 à 60 sessions.** On ajoute une marge d'environ 15 à 25 % (7 à 12 sessions) pour les retours du client après ses tests en jeu, les écarts entre frameworks et les reprises après audit. Chemin critique : 17 sessions ; avec 3 équipes, environ 23 créneaux, plus la marge.

| # | Risque de planning | Effet | Parade prévue dans le plan |
|---|---|---|---|
| 1 | Pas de serveur de test QBCore ni Qbox (le serveur actuel est ESX) | Jalon « tous frameworks testés » bloqué ; S44 et S45 impossibles | Prévenir le client dès maintenant ; S44 et S45 commencent par un guide pour monter les deux serveurs (txAdmin) s'ils n'existent pas ; les mocks des 3 frameworks testent le bridge à chaque session en attendant. Compter 1 session de plus si les serveurs sont à monter. |
| 2 | Anciennes tables `pop_tablet_*` sur la base de test (4 noms identiques aux nouveaux) | La nouvelle tablette lirait un ancien schéma | S01 refuse de démarrer sur un ancien schéma et fournit `pop_tablet_archive_legacy confirm` (renommage en `pop_tablet_legacy_*`, aucune perte). |
| 3 | Volume : 360 fiches, 100 tables, environ 60 écrans | Oublis, sessions qui débordent | Commentaires `[ID]` + `coverage.lua` à chaque session, couverture stricte en S46 ; sessions marquées « longue » à surveiller ; une session qui déborde se coupe en « a / b » plutôt que de pousser du code inachevé. |
| 4 | Le client devient le goulot (un test en jeu par session) | Le parallélisme ne sert à rien si les tests s'accumulent | 3 gestes par session, ordre de fusion = ordre de test ; ne pas dépasser 3 à 4 équipes. |
| 5 | Conflits de fusion entre sessions parallèles | Temps perdu, régressions | Dossiers séparés par app, schéma complet en S01, sections de `config.lua` et lignes de `registry.ts` préparées ; rebase + vérification complète avant chaque push. |
| 6 | Valeurs dépendant de scripts tiers (prison Qbox, `isDead`, ps-dispatch v2, `markedbills`…) | Correctifs tardifs en recette | Isolées dans un seul fichier d'adaptateur ouvert chacune ; contrôlées en premier en S43 à S45 (sommaire § 5). |
| 7 | Argent (double paiement, compte société indisponible) | Bugs graves, reprise de sessions | Idempotence et tests concurrents dès S08 (Pay) et S12 ; journal `money` sur Discord par défaut ; recette triche en S43. |
| 8 | Quota GitHub gratuit (déploiement et lint manuels) | Attente ou échec du déploiement | Vérification complète en local avant push (`verifier-pop-tablet.sh`) ; le déploiement reste manuel, sur le Mac du client par défaut. |
| 9 | Traductions (environ 5 000 clés × 10 langues, arabe RTL, thaï) | S42 plus longue que prévu | fr et en tenus à jour à chaque session ; S42 découpée par langue entre sous-agents ; prévoir 1 session de plus si besoin. |
| 10 | Interface NUI lourde (tableur, éditeur de site, MDT) | Budgets de build dépassés, lenteurs | Budgets bloquants dans `build.mjs`, chargement à la demande, e2e `leaks.spec` à chaque session. |
| 11 | Règles Tebex / escrow Cfx qui évoluent | Paquet refusé ou mal protégé | Vérification des sources officielles en S47 (skill « vérifier avant d'affirmer »). |

---

## 6. Vérification de couverture

Contrôle fait par script au moment d'écrire ce plan : liste des fiches actives extraite des fichiers 01 à 06 (`^### \[ID\]`, hors titres marqués « supprimée »), comparée aux IDs du tableau § 1.

- Fiches dans les fichiers : 363 ; supprimées exclues : 3 (BASE-OBJ-18, MET-GANG-05, ADM-15) ; actives : 360.
- IDs dans le tableau : 360 ; présents exactement une fois : 360 ; manquants : 0 ; en double : 0 ; inconnus : 0.
- Dépendances : chaque session ne dépend que de sessions de numéro inférieur ; le planning à 3 équipes du § 2 place chaque session une fois, après ses dépendances.

