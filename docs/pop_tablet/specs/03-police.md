# 03 · Métiers > Police (MDT) — fiches de fonctionnalités

Périmètre : app **Police** de la branche Métiers (MDT = Mobile Data Terminal). Préfixe d'ID : `MET-POL-`.
Niveau visé : LB Tablet / Kartik MDT. Tout ce qui n'est pas écrit dans une fiche suit `_contexte.md`.

---

## 0. Conventions communes à toutes les fiches police (à coder une seule fois)

Les fiches renvoient à ces règles par leur code (RC1, RC2…). Elles s'appliquent toujours, même si la fiche ne les répète pas.

### 0.1 Métiers concernés
- `Config.Police.Jobs = { 'police' }` : liste des métiers (ESX, QBCore ou Qbox, lus par le bridge) qui ouvrent l'app Police. Chaque job est une entreprise ENT déjà créée (clé en main). Exemple d'ajout : `{ 'police', 'sheriff' }`.
- Toutes les données police (appels, fiches, rapports, casier, mandats, preuves, caméras) sont **partagées entre tous les jobs de la liste** (un seul fichier central, comme une vraie base police). Les droits restent ceux de l'entreprise de l'agent.
- Un « agent » = joueur dont le métier (principal sur Qbox) est dans `Config.Police.Jobs`. « En service » = prise de service active (ENT-GES, fiche Prise de service).

### 0.2 Règles serveur communes
- **RC1 Droit** : chaque appel serveur revérifie job, service actif (sauf mention contraire), droit du grade (clé de droit indiquée dans la fiche). Refus = code d'erreur `pas_droit` ou `hors_service`, jamais d'action partielle.
- **RC2 Fréquence** : limite par joueur et par action. Défaut écriture : `Config.Police.RateLimit.Ecriture = { n = 5, s = 10 }` (5 actions / 10 s). Défaut lecture/recherche : `Config.Police.RateLimit.Lecture = { n = 15, s = 10 }`. Dépassement = refus `trop_vite`.
- **RC3 Anti double clic** : chaque action d'écriture envoie un `actionId` (UUID v4 généré par la NUI). Le serveur garde les `actionId` vus 10 min en mémoire (règle de la base) ; un `actionId` déjà vu renvoie le résultat de la première exécution sans rien refaire. Le bouton est grisé dès le clic jusqu'à la réponse.
- **RC4 Nettoyage texte** : tout texte joueur est passé par `Sanitize.text()` de la base (BASE-MOT-12) côté serveur (suppression des balises `<...>`, des `javascript:`, des caractères de contrôle, espaces de début/fin), puis vérifié à la longueur max de la fiche (au-delà : refus `trop_long`, jamais de coupure silencieuse). La NUI affiche toujours en `textContent`, jamais en `innerHTML`.
- **RC5 Images** : une URL d'image n'est acceptée que si son domaine est dans `Config.Images.AllowedDomains` (réglage global de la tablette) ou si elle vient de la Galerie (`media:<id>`). Sinon refus `image`.
- **RC6 Proximité** : quand une cible « proche » est demandée, le serveur compare `GetEntityCoords(GetPlayerPed(source))` et celles de la cible : distance ≤ `Config.Limits.NearDistance = 3.0` m. Sinon refus `trop_loin`.
- **RC7 Archivage** : rien de police n'est supprimé en base. « Supprimer / retirer » = `archive = 1`, `archive_par`, `archive_le`, `archive_motif`. Les éléments archivés sont invisibles pour les agents, visibles par l'admin (app Admin > Journal / Archives) et par le Patron police dans un filtre « Archivés ».
- **RC8 Journal admin** : les actions marquées « Journal admin : oui » écrivent dans le journal commun : `qui` (identifier + nom RP + job + grade), `quoi` (code action ex. `police.casier.ajout`), `quand` (horodatage serveur), `avant` / `après` (JSON), `cible`. Envoi Discord si le webhook global est réglé (lien gardé côté serveur).
- **RC9 Identité** : un citoyen est identifié par l'identifiant du personnage renvoyé par le bridge : ESX `users.identifier` ; QBCore / Qbox `players.citizenid`. Nom affiché, date de naissance, sexe, taille : ESX `users.firstname` + `users.lastname`, `users.dateofbirth`, `users.sex` (`m` → « Homme », `f` → « Femme »), `users.height` (cm) ; QBCore / Qbox colonne JSON `players.charinfo` (`firstname` + `lastname`, `birthdate`, `gender` `0` → « Homme », `1` → « Femme » ; taille absente → « — »). La NUI ne reçoit jamais un identifier : le serveur lui donne un `ref` opaque (voir MET-POL-14).
- **RC10 Notifications** : une notification police n'est envoyée qu'aux joueurs concernés qui ont la tablette sur eux (item présent si inventaire à objets, sinon toujours). Tablette ouverte : bandeau en haut à droite 4 s (`Config.Notify.Duration`). Tablette fermée : notification native courte (ox_lib `notify` si présent, sinon `Bridge.Notify` : ESX `ESX.ShowNotification`, QBCore `QBCore.Functions.Notify`, Qbox `exports.qbx_core:Notify`) avec le préfixe « MDT · ».

### 0.3 Erreurs communes (textes affichés)
Codes et textes communs = référentiel unique de la fiche 01 (§0 « Codes d'erreur communs », repris dans `00-sommaire.md`) : `pas_droit`, `hors_service`, `trop_vite`, `trop_loin`, `image`, `introuvable`, `trop_long`, `champ_requis`, `serveur`, `hors_ligne`, `lecture_seule`. Le serveur les renvoie dans `err` ; la NUI affiche `commun.erreur.<code>`. Pour `pas_droit`, l'écran ajoute sous le bouton la bulle `commun.droit.grade_requis` « Grade requis : {grade} ». **Ton des textes : style Apple** (décision du client) : formulations neutres et courtes en priorité (« Facture envoyée. », « Code incorrect. », « Aucune facture. »), **vouvoiement** quand une adresse directe est nécessaire (« Vous n'avez pas les droits nécessaires. »), jamais de tutoiement. Les textes écrits entre guillemets dans les fiches sont déjà dans ce ton et se recopient tels quels dans `locales/fr.lua`.

### 0.4 États d'écran communs
- Chargement : formes grises à la place des lignes ; après 5 s : « Le chargement prend plus de temps que prévu. » (`commun.chargement.long`) + bouton « Réessayer » (`commun.bouton.reessayer`).
- Succès : bandeau 2 s en haut de l'écran (texte donné dans chaque fiche).
- Pas le droit : bouton grisé avec infobulle « Grade requis : {grade} » (`commun.droit.grade_requis`) ; un onglet entier sans droit de lecture est caché.
- Hors service : toute l'app est grisée sauf l'écran d'accueil qui affiche uniquement « Hors service. » (`commun.hors_service.titre`) et le bouton « Prendre mon service » (`commun.hors_service.bouton`).

### 0.5 Clés de droit police (réglables case par case par le Patron dans ENT-GES > Droits)
| Clé | Recrue | Membre | Chef | Patron |
|---|---|---|---|---|
| `police.service` (prendre son service) | Oui | Oui | Oui | Oui |
| `police.appels` (voir, prendre, clôturer un appel) | Oui | Oui | Oui | Oui |
| `police.unites.gerer` (créer une unité, y ajouter des agents) | Non | Oui | Oui | Oui |
| `police.citoyens.lire` / `police.vehicules.lire` | Oui | Oui | Oui | Oui |
| `police.notes` (écrire une note) | Oui | Oui | Oui | Oui |
| `police.vehicules.signaler` (signaler une plaque, enregistrer une plainte) | Oui | Oui | Oui | Oui |
| `police.amende` | Oui | Oui | Oui | Oui |
| `police.rapport` | Oui | Oui | Oui | Oui |
| `police.rapport.modeles` (modèles de rapport) | Non | Non | Non | Oui |
| `police.casier.ajouter` | Oui | Oui | Oui | Oui |
| `police.casier.retirer` | Non | Non | Non | Oui |
| `police.permis` (retirer / rendre un permis) | Non | Oui | Oui | Oui |
| `police.mandat.creer` (mandats et avis) | Non | Oui | Oui | Oui |
| `police.mandat.valider` | Non | Non | Oui | Oui |
| `police.codepenal.modifier` | Non | Non | Non | Oui |
| `police.annonce` | Non | Non | Oui | Oui |
| `police.heures.tous` (voir les heures des autres) | Non | Non | Oui | Oui |
| `police.preuves` (créer, déposer) | Oui | Oui | Oui | Oui |
| `police.preuves.gerer` (ouvrir un casier à preuves, sortir une preuve) | Non | Non | Oui | Oui |
| `police.cameras` (caméras fixes) | Non | Non | Oui | Oui |
| `police.camerapieton` | Non | Non | Oui | Oui |
| `police.formation.former` (formateur) | Non | Non | Oui | Oui |
| `police.formation.parcours` (modifier les étapes) | Non | Non | Non | Oui |
| `police.matricule` (attribuer les matricules) | Non | Non | Oui | Oui |
| `police.saisie` (fouiller une tablette saisie) | Oui | Oui | Oui | Oui |
| `police.avis.public` (avis de recherche sur toutes les tablettes, MET-POL-45) | Non | Non | Oui | Oui |
| `police.carte` (carte des crimes, MET-POL-46) | Non | Non | Oui | Oui |
| `police.infiltration` (lire une messagerie de gang sous mandat, MET-POL-47) | Non | Non | Oui | Oui |

L'admin serveur (ACE `pop.tablet.admin`) a toutes les clés, même sans job police, mais doit être en service pour les actions de terrain (amende, casier, saisie). Il peut toujours modifier code pénal, caméras, modèles de rapport et parcours de formation sans être en service.

### 0.6 Tables (préfixe `pop_tablet_police_`, créées automatiquement au premier démarrage)
`agents`, `appels`, `citoyens`, `notes`, `vehicules`, `historique`, `rapports`, `rapport_liens`, `rapport_modeles`, `amendes`, `casier`, `mandats`, `avis`, `codepenal`, `annonces`, `annonces_lues`, `preuves`, `preuves_casiers`, `preuves_journal`, `formation_etapes`, `formation_suivi`, `permis_historique`, `saisies`, `avis_publics`, `infiltration_journal`. Les colonnes sont données dans les fiches. Les caméras fixes utilisent la table commune `pop_tablet_cameras` du fichier 05 (§0.4, colonne `companies` = entreprises police autorisées) ; les heures de service viennent de `pop_tablet_ent_services` (fichier 02). Mandats : cette table `pop_tablet_police_mandats` est la seule table de mandats (l'app Justice y écrit, MET-JUS-07). Toutes ont `id INT AUTO_INCREMENT` (sauf mention) et `cree_le DATETIME DEFAULT CURRENT_TIMESTAMP`.

### 0.7 Navigation de l'app
Barre latérale gauche, dans cet ordre : Accueil · Dispatch · Effectifs · Unités · Citoyens · Véhicules · Rapports · Carte des crimes · Amendes · Casier · Mandats · Preuves · Caméras · Code pénal · Annonces · Heures · Formation. Un onglet sans droit de lecture est caché. Raccourci : `Ctrl+K` ouvre la recherche rapide (MET-POL-02). Échap : ferme la fenêtre ouverte, sinon revient à l'écran précédent, sinon ferme la tablette.

---

## 1. Service et accueil

### [MET-POL-01] Prise et fin de service dans le MDT
- **But** : permettre à l'agent de prendre ou quitter son service depuis le MDT, en réutilisant la prise de service commune ENT-GES.
- **Qui** : tout agent (`police.service`, Recrue+). Réglable par le Patron.
- **Où** : Police > Accueil > bouton « Prendre mon service » (hors service) ; Police > en-tête > bouton « Fin de service » (en service).
- **Parcours** :
  1. L'agent hors service ouvre l'app Police : seul l'écran hors service est visible (0.4).
  2. Il clique « Prendre mon service ». La NUI appelle le même callback serveur que ENT-GES (action `gestion.service.prendre`) avec `entreprise = job ESX`.
  3. Le serveur applique les règles d'ENT-GES (job, droit, fréquence), crée la session de service, puis la partie police ajoute l'agent à la liste en mémoire `PoliceEnService[source] = { identifier, nom, grade, matricule, statut = 'disponible', uniteId = nil, depuis = os.time() }`.
  4. Le serveur envoie l'événement `pop_tablet:police:effectifs:maj` aux agents en service qui ont l'app Police ouverte (mise à jour de la liste Effectifs).
  5. Si `Config.Police.Service.ChangerTenue = false` (défaut), rien d'autre. La tablette ne gère ni tenues ni armes.
  6. L'app se recharge sur l'Accueil (MET-POL-02). Bandeau succès.
  7. Fin : l'agent clique « Fin de service » → fenêtre « Terminer votre service ? » (`police.service.confirmer`) → « Oui » → action `gestion.service.quitter`. Le serveur ferme la session, retire l'agent de son unité (règle « dernier membre » de MET-POL-06), le retire des appels qu'il a pris (MET-POL-09), le retire de `PoliceEnService`, notifie les effectifs.
  8. Déconnexion ou changement de job ESX en service : le serveur fait l'étape 7 automatiquement (événements `playerDropped` et `Bridge.OnJobChange` : ESX `esx:setJob`, QBCore / Qbox `QBCore:Server:OnJobUpdate`).
- **Données** :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| Session de service | table ENT-GES | Oui | une seule ouverte par joueur | — |
| statut (mémoire) | enum `disponible`/`occupe`/`pause` | Oui | — | `disponible` |
| uniteId (mémoire) | int | Non | — | nil |
| depuis (mémoire) | timestamp | Oui | — | heure de prise |
- **Règles serveur** : RC1 (job dans `Config.Police.Jobs`, `police.service`), RC2, RC3. Une seule session ouverte par joueur : une 2e demande renvoie « déjà en service » sans créer de session. Pas de prise de service si le joueur est mort (état `isDead` lu via le bridge) : refus.
- **Textes et états** :
  - Hors service : « Vous n'êtes pas en service. » (`commun.hors_service.titre`), bouton « Prendre mon service » (`commun.hors_service.bouton`).
  - Succès prise : « Vous êtes en service. Bonne patrouille. » (`police.service.debut`).
  - Succès fin : « Service terminé. » (`police.service.fin`).
  - Erreur déjà en service : « Vous êtes déjà en service. » (`police.service.deja`).
  - Erreur mort : « Impossible tant que vous êtes inconscient. » (`police.service.inconscient`).
  - Pas le droit : 0.3 `pas_droit`.
- **Notifications** : aucune aux autres joueurs (seule la liste Effectifs se met à jour).
- **Liens** : ENT-GES prise de service (source de vérité), Annuaire (police « ouverte » si ≥ 1 agent en service), Dispatch (seuls les agents en service reçoivent les appels), Planning (présence), MET-POL-35 Heures. Signal serveur émis : `TriggerEvent('pop_tablet:police:service', source, true|false)`.
- **Réglages** : `Config.Police.Service.ChangerTenue = false` ; `Config.Police.Service.FinAutoDeconnexion = true`.
- **Journal admin** : oui (début et fin de service, avec durée en fin).
- **Performance** : aucune boucle ; liste en mémoire mise à jour par événement ; un seul événement réseau envoyé aux agents ayant l'app ouverte.
- **Cas limites** :
  - Joueur déconnecté en service : session fermée à l'heure de déconnexion, appels libérés.
  - Double clic sur « Prendre mon service » : RC3, une seule session.
  - Redémarrage du serveur : les sessions ouvertes sont fermées au démarrage avec l'heure du dernier enregistrement connu (règle ENT-GES) ; personne n'est en service.
  - Agent viré pendant le service : `esx:setJob` → fin automatique.
- **Critères d'acceptation** :
  - Étant donné un agent hors service, quand il clique « Prendre mon service », alors il apparaît dans Effectifs en « Disponible » chez tous les agents en service.
  - Étant donné un agent en service seul sur un appel, quand il se déconnecte, alors l'appel repasse en « Nouveau ».
  - Étant donné un joueur civil qui déclenche à la main l'événement de prise de service police, quand le serveur le reçoit, alors il refuse (`pas_droit`) et rien n'est créé.

### [MET-POL-02] Écran d'accueil (résumé + recherche rapide)
- **But** : donner en un coup d'œil l'état de la ville côté police et un accès direct à la recherche.
- **Qui** : tout agent en service (Recrue+), non réglable.
- **Où** : Police > Accueil (écran par défaut à l'ouverture de l'app).
- **Parcours** :
  1. À l'ouverture, la NUI appelle `pop_tablet:police:accueil` (un seul appel).
  2. Le serveur renvoie : nombre d'appels « Nouveau » et « Pris », les 5 derniers appels non clos, nombre d'agents en service par statut, nombre d'unités actives, mandats actifs (nombre + 5 derniers), avis de recherche actifs personnes et véhicules (nombre + 5 derniers), dernière annonce interne non lue (MET-POL-34), statut et unité de l'agent.
  3. La NUI affiche 4 tuiles chiffrées en haut : « Appels en attente », « Agents en service », « Mandats actifs », « Avis de recherche ». Clic sur une tuile = ouvre l'onglet correspondant.
  4. Dessous : à gauche les 5 derniers appels (clic → détail MET-POL-08), à droite mandats et avis (clic → fiche). Au-dessus, si une annonce non lue existe : bandeau avec son titre et le bouton « Lire » (MET-POL-34).
  5. En haut : barre « Rechercher un nom, une plaque, un n° de rapport ou de preuve » (`Ctrl+K`). Saisie ≥ 2 caractères + Entrée → `pop_tablet:police:recherche` → résultats groupés « Citoyens », « Véhicules », « Rapports », « Preuves » (5 max par groupe, lien « Voir tout » vers l'onglet filtré). Un texte au format `R-00001` ouvre directement le rapport, `P-00001` la preuve, `A-00001` l'appel.
  6. Le bloc « Mon statut » affiche les 3 boutons de statut (MET-POL-04) et l'unité avec ses boutons de statut (MET-POL-06).
  7. Les tuiles se mettent à jour par les événements déjà envoyés (nouvel appel, effectifs), sans rappel périodique.
- **Données** (affichées, rien de stocké) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| appelsAttente | int | Oui | ≥ 0 | 0 |
| agentsEnService | int + détail par statut | Oui | ≥ 0 | 0 |
| mandatsActifs | int + 5 lignes | Oui | — | 0 |
| avisActifs | int + 5 lignes | Oui | — | 0 |
| recherche | texte | Non | 2 à 50 caractères | vide |
- **Règles serveur** : RC1 (service), RC2 lecture. Recherche : texte nettoyé (RC4), requêtes préparées (jamais de concaténation), `%` et `_` échappés, 5 résultats par groupe.
- **Textes et états** :
  - Vide appels : « Aucun appel en attente. La ville est calme. » (`police.accueil.appels.vide`).
  - Vide mandats : « Aucun mandat actif. » (`police.accueil.mandats.vide`) ; avis : « Aucun avis de recherche. » (`police.accueil.avis.vide`).
  - Tuiles : « Appels en attente » (`police.accueil.tuile.appels`), « Agents en service » (`…tuile.agents`), « Mandats actifs » (`…tuile.mandats`), « Avis de recherche » (`…tuile.avis`).
  - Recherche : placeholder « Rechercher un nom, une plaque, un n° de rapport ou de preuve » (`police.recherche.placeholder`) ; sans résultat « Aucun résultat pour « {texte} ». Vérifiez l'orthographe ou cherchez la plaque. » (`police.recherche.vide`) ; trop courte « Tapez au moins 2 caractères. » (`police.recherche.court`).
  - Hors service : 0.4.
- **Notifications** : aucune.
- **Liens** : lit Dispatch, Effectifs, Unités, Mandats, Avis, Annonces, Rapports, Preuves.
- **Réglages** : `Config.Police.Accueil.NbLignes = 5`.
- **Journal admin** : non (voir `Config.Police.JournalRecherches`, MET-POL-14).
- **Performance** : un seul appel à l'ouverture ; compteurs lus en mémoire (appels, effectifs) et en cache serveur 30 s pour mandats/avis ; aucune boucle.
- **Cas limites** :
  - Seul agent en service : tuile « Agents en service » = 1.
  - Recherche avec `%` ou `_` : cherchés comme texte.
  - Annonce archivée entre deux ouvertures : non affichée.
- **Critères d'acceptation** :
  - Étant donné 3 appels « Nouveau », quand l'agent ouvre l'Accueil, alors la tuile « Appels en attente » affiche 3.
  - Étant donné un citoyen « John Doe », quand l'agent tape « doe » puis Entrée, alors John Doe apparaît dans « Citoyens ».
  - Étant donné un joueur hors service qui appelle à la main `pop_tablet:police:recherche`, quand le serveur le reçoit, alors il renvoie `hors_service` sans aucun résultat.

---

## 2. Effectifs et unités

### [MET-POL-03] Effectifs en service
- **But** : voir qui est en service, avec grade, matricule, unité et statut.
- **Qui** : tout agent en service (Recrue+), non réglable.
- **Où** : Police > Effectifs.
- **Parcours** :
  1. La NUI appelle `pop_tablet:police:effectifs` ; le serveur renvoie la liste `PoliceEnService` (mémoire).
  2. Tableau trié par grade (du plus haut au plus bas) puis matricule : colonnes « Matricule », « Nom », « Grade », « Unité », « Statut », « En service depuis ».
  3. Pastille de statut : Disponible (couleur d'accent pleine), Occupé (blanc plein), En pause (contour gris). Pas d'autre couleur.
  4. Filtres en haut : « Tous », « Disponibles », « Occupés », « En pause ». Champ « Filtrer par nom ou matricule » (filtrage côté NUI sur la liste reçue).
  5. Clic sur une ligne : panneau à droite avec nom, grade, matricule, unité, statut, temps en service, boutons « Voir sa caméra piéton » (MET-POL-41, si droit) et « Attribuer un matricule » (MET-POL-07, si droit).
  6. Mise à jour en direct : l'événement `pop_tablet:police:effectifs:maj` (envoyé seulement aux agents qui ont l'onglet Effectifs ou l'Accueil ouvert) remplace la ligne concernée.
- **Données** (mémoire, affichées) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| matricule | texte | Non | 1 à 8 car. | « — » |
| nom | texte | Oui | RC9 | — |
| grade | texte (label ESX) | Oui | — | — |
| unite | indicatif | Non | — | « Aucune » |
| statut | enum | Oui | 3 valeurs | `disponible` |
| depuis | durée | Oui | — | — |
- **Règles serveur** : RC1, RC2 lecture. Le serveur n'envoie jamais l'identifier ni l'ID serveur des autres agents à la NUI (clé interne opaque générée par session).
- **Textes et états** :
  - Vide (seul en service) : « Vous êtes le seul agent en service. » (`police.effectifs.seul`).
  - Colonnes : « Matricule » (`police.effectifs.col.matricule`), « Nom » (`…col.nom`), « Grade » (`…col.grade`), « Unité » (`…col.unite`), « Statut » (`…col.statut`), « En service depuis » (`…col.depuis`).
  - Statuts : « Disponible » (`police.statut.disponible`), « Occupé » (`police.statut.occupe`), « En pause » (`police.statut.pause`).
- **Notifications** : aucune.
- **Liens** : MET-POL-01, 04, 05, 07, 41.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : liste en mémoire, aucune requête SQL ; maj par événement ciblé ; pagination 20.
- **Cas limites** :
  - 60 agents en service : pagination 20 par page.
  - Agent qui se déconnecte pendant l'affichage : la ligne disparaît à l'événement suivant.
  - Grade ESX modifié en service : libellé relu à l'événement `Bridge.OnJobChange`, ligne mise à jour.
- **Critères d'acceptation** :
  - Étant donné 2 agents en service, quand l'un passe en pause, alors l'autre voit sa pastille « En pause » sans recharger.
  - Étant donné le filtre « Disponibles », quand un agent devient occupé, alors il disparaît de la vue filtrée.
  - Étant donné un civil qui appelle `pop_tablet:police:effectifs`, quand le serveur le reçoit, alors il renvoie `pas_droit` et aucune liste.

### [MET-POL-04] Statut personnel en 1 clic (disponible / occupé / pause)
- **But** : indiquer sa disponibilité au dispatch en un clic.
- **Qui** : tout agent en service, non réglable.
- **Où** : Police > Accueil > bloc « Mon statut » ; en-tête de l'app (3 boutons compacts toujours visibles en service).
- **Parcours** :
  1. L'agent clique « Disponible », « Occupé » ou « Pause ».
  2. La NUI appelle `pop_tablet:police:statut` `{ statut, actionId }`.
  3. Le serveur met à jour `PoliceEnService[source].statut`, puis envoie `effectifs:maj`.
  4. Le statut de l'unité n'est **pas** changé (l'unité a son propre statut, MET-POL-06).
  5. Prendre un appel (MET-POL-09) passe automatiquement l'agent en « Occupé » ; clôturer son dernier appel le repasse en « Disponible » s'il était « Occupé ».
- **Données** :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| statut | enum `disponible`/`occupe`/`pause` | Oui | 3 valeurs | `disponible` |
- **Règles serveur** : RC1, RC2 (limite propre : 10 changements / 10 s), RC3. Valeur hors liste refusée.
- **Textes et états** : boutons « Disponible » / « Occupé » / « Pause » (clés `police.statut.*`) ; le bouton actif est plein. Succès : pas de bandeau (changement visible immédiatement). Erreurs : 0.3.
- **Notifications** : aucune.
- **Liens** : Effectifs, Accueil, Dispatch (un agent « Pause » ne reçoit pas de notification pour les appels de priorité 3, MET-POL-08).
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : mémoire seulement.
- **Cas limites** : double clic (RC3) ; statut envoyé hors service (`hors_service`) ; agent en pause qui prend un appel → passe « Occupé ».
- **Critères d'acceptation** :
  - Étant donné un agent disponible, quand il clique « Pause », alors Effectifs affiche « En pause » chez tous.
  - Étant donné un agent occupé avec un seul appel, quand il le clôture, alors il repasse « Disponible ».
  - Étant donné un client qui envoie `statut = 'invisible'`, quand le serveur le reçoit, alors il refuse et le statut ne change pas.

### [MET-POL-05] Créer une unité (patrouille avec indicatif)
- **But** : regrouper des agents sous un indicatif radio (ex. « ADAM-12 ») pour le dispatch.
- **Qui** : `police.unites.gerer` (Membre+), réglable.
- **Où** : Police > Unités > bouton « Créer une unité ».
- **Parcours** :
  1. Fenêtre : « Indicatif » (liste de préfixes `Config.Police.Unites.Prefixes` + numéro 1–99, ou saisie libre si `Config.Police.Unites.IndicatifLibre = true`), « Type » (liste `Config.Police.Unites.Types`), « Membres » (cases à cocher parmi les agents en service sans unité ; le créateur est coché et non décochable).
  2. « Créer » → `pop_tablet:police:unite:creer`.
  3. Serveur : vérifie droits, indicatif unique parmi les unités actives, membres en service et sans unité, max `Config.Police.Unites.MaxMembres = 4`. Crée l'unité en mémoire `{ id, indicatif, type, membres, statut = 'disponible', appels = {}, creeePar }`, met `uniteId` sur chaque membre.
  4. Événement `pop_tablet:police:unites:maj` aux agents en service ; chaque membre ajouté reçoit une notification.
  5. L'unité apparaît en carte dans Police > Unités : indicatif en gros, type, membres (matricule + nom), statut, appel en cours.
- **Données** (mémoire ; les unités ne survivent pas à un redémarrage) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| indicatif | texte | Oui | 2 à 12 car., lettres/chiffres/tiret, majuscules forcées, unique | — |
| type | enum | Oui | `Config.Police.Unites.Types` | `Patrouille` |
| membres | liste d'agents | Oui | 1 à 4 | créateur |
| statut | enum | Oui | MET-POL-06 | `disponible` |
- **Règles serveur** : RC1, RC2, RC3, RC4. Indicatif déjà pris → refus. Membre déjà dans une unité → refus en le nommant. Le créateur doit être membre.
- **Textes et états** :
  - Vide : « Aucune unité. Créez la première patrouille. » (`police.unites.vide`) + bouton « Créer une unité » (`police.unites.creer`).
  - Succès : « Unité {indicatif} créée. » (`police.unites.cree`).
  - Erreur indicatif pris : « L'indicatif {indicatif} est déjà utilisé. » (`police.unites.indicatifpris`).
  - Erreur membre occupé : « {nom} est déjà dans l'unité {indicatif}. » (`police.unites.membredeja`).
  - Erreur trop de membres : « 4 agents maximum par unité. » (`police.unites.max`).
  - Pas le droit : bouton grisé « Grade requis : Membre ».
- **Notifications** : chaque membre ajouté : « MDT · Vous êtes affecté à l'unité {indicatif}. » (`police.notif.affecte`).
- **Liens** : Effectifs (colonne Unité), Dispatch (un appel peut être pris par une unité), Accueil.
- **Réglages** : `Config.Police.Unites.Prefixes = { 'ADAM', 'LINCOLN', 'MARY', 'DAVID', 'AIR', 'TOM' }` ; `Config.Police.Unites.Types = { 'Patrouille', 'Moto', 'Banalisée', 'Hélicoptère', 'Intervention', 'Enquête' }` ; `Config.Police.Unites.IndicatifLibre = false` ; `Config.Police.Unites.MaxMembres = 4`.
- **Journal admin** : non.
- **Performance** : mémoire, événements ciblés aux agents en service.
- **Cas limites** : deux agents créent le même indicatif à la même seconde → le premier traité gagne, le second reçoit « indicatif pris » ; membre coché qui se déconnecte avant validation → refus avec son nom ; redémarrage serveur → aucune unité.
- **Critères d'acceptation** :
  - Étant donné 2 agents sans unité, quand l'un crée « ADAM-12 » avec l'autre, alors les deux voient « ADAM-12 » dans la colonne Unité.
  - Étant donné « ADAM-12 » actif, quand un autre agent tente « ADAM-12 », alors il reçoit « L'indicatif ADAM-12 est déjà utilisé. ».
  - Étant donné une Recrue qui envoie à la main la création d'unité, quand le serveur la reçoit, alors il refuse `pas_droit`.

### [MET-POL-06] Statut d'unité en 1 clic, membres, dissolution
- **But** : changer le statut d'une unité d'un clic et gérer ses membres.
- **Qui** : statut : tout membre de l'unité (Recrue+) ou Chef+ ; ajouter/retirer un membre, dissoudre : membre de l'unité avec `police.unites.gerer`, ou Chef+ pour n'importe quelle unité ; quitter : tout membre.
- **Où** : Police > Unités > carte de l'unité ; Accueil > bloc « Mon statut » (statut de mon unité).
- **Parcours** :
  1. Boutons de statut sur la carte (un clic) : « Disponible » (10-8), « En route » (10-76), « Sur place » (10-23), « Occupé » (10-6), « Pause » (10-7). Le code 10 s'affiche à côté si `Config.Police.Unites.AfficherCodes10 = true`.
  2. Clic → `pop_tablet:police:unite:statut` → serveur met à jour, envoie `unites:maj`.
  3. « Ajouter un agent » → liste des agents en service sans unité → serveur vérifie le maximum.
  4. « Retirer » sur un membre → l'agent retiré reçoit une notification.
  5. « Quitter l'unité » → l'agent sort. Si c'était le dernier membre, l'unité est dissoute automatiquement.
  6. « Dissoudre » → confirmation « Dissoudre l'unité {indicatif} ? » (`police.unites.confirmerdissoudre`) → tous les membres sortent ; l'unité est retirée de ses appels ; un appel qui n'a plus aucun preneur repasse « Nouveau ».
- **Données** :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| statut unité | enum `disponible`/`enroute`/`surplace`/`occupe`/`pause` | Oui | 5 valeurs | `disponible` |
- **Règles serveur** : RC1, RC2 (statut : 10 / 10 s), RC3. Le serveur vérifie que l'agent est bien membre (ou Chef+). Prise d'appel par l'unité → statut auto « En route » ; clôture de son dernier appel → « Disponible ».
- **Textes et états** : libellés « Disponible », « En route », « Sur place », « Occupé », « Pause » (`police.unite.statut.*`). Succès quitter : « Vous avez quitté l'unité {indicatif}. » (`police.unites.quitte`). Succès dissoudre : « Unité {indicatif} dissoute. » (`police.unites.dissoute`). Erreur non membre : « Vous ne faites pas partie de cette unité. » (`police.unites.pasmembre`).
- **Notifications** : agent retiré : « MDT · Vous avez été retiré de l'unité {indicatif}. » (`police.notif.retire`) ; dissolution : chaque membre « MDT · L'unité {indicatif} a été dissoute. » (`police.notif.dissoute`).
- **Liens** : Dispatch, Effectifs, Accueil.
- **Réglages** : `Config.Police.Unites.AfficherCodes10 = true`.
- **Journal admin** : non.
- **Performance** : mémoire, événements ciblés.
- **Cas limites** : dernier membre se déconnecte → dissolution auto ; deux changements de statut simultanés → le dernier reçu gagne ; Chef non membre qui change le statut d'une unité → autorisé (supervision).
- **Critères d'acceptation** :
  - Étant donné ADAM-12 « Disponible », quand un membre clique « Sur place », alors tous les agents voient « Sur place » sur la carte.
  - Étant donné une unité à 1 membre, quand il quitte, alors l'unité disparaît.
  - Étant donné un agent non membre et non Chef, quand il envoie un changement de statut d'ADAM-12, alors le serveur refuse.

### [MET-POL-07] Matricule de l'agent (ajout)
- **But** : donner à chaque agent un matricule fixe affiché partout (effectifs, rapports, amendes), comme dans les vrais MDT.
- **Qui** : attribuer : `police.matricule` (Chef+), réglable. Chaque agent voit le sien.
- **Où** : Police > Effectifs > panneau agent > « Attribuer un matricule ».
- **Parcours** :
  1. Le Chef ouvre le panneau d'un agent en service, clique « Attribuer un matricule », saisit la valeur.
  2. `pop_tablet:police:matricule` → serveur vérifie l'unicité parmi tous les agents (table `agents`), enregistre, met à jour la mémoire, envoie `effectifs:maj`.
  3. Si `Config.Police.Matricule.Auto = true` (défaut), un agent sans matricule reçoit à sa première prise de service le prochain numéro libre au format `Config.Police.Matricule.Format = '%03d'` (001, 002…).
- **Données** (table `agents`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| identifier | varchar(60) PK | Oui | — | — |
| matricule | varchar(8) | Oui | lettres/chiffres/tiret, UNIQUE | auto |
| maj_par / maj_le | varchar(60) / datetime | Oui | — | — |
- **Règles serveur** : RC1, RC2, RC3, RC4 ; unicité ; un Chef ne change que le matricule d'un grade inférieur au sien (Patron et admin : tous).
- **Textes et états** : succès « Matricule {matricule} attribué à {nom}. » (`police.matricule.ok`) ; erreur « Le matricule {matricule} est déjà attribué. » (`police.matricule.pris`) ; erreur grade : « Vous ne pouvez modifier que les grades inférieurs au vôtre. » (`police.matricule.grade`) ; vide : `champ_requis`.
- **Notifications** : l'agent concerné : « MDT · Votre matricule est désormais {matricule}. » (`police.notif.matricule`).
- **Liens** : affiché dans Effectifs, Rapports, Amendes, Casier, Preuves (auteur = « {matricule} {nom} »).
- **Réglages** : `Config.Police.Matricule.Auto = true` ; `Config.Police.Matricule.Format = '%03d'`.
- **Journal admin** : oui (avant/après).
- **Performance** : lu une fois à la prise de service, gardé en mémoire.
- **Cas limites** : agent qui quitte la police puis revient → garde son ancien matricule (ligne conservée) ; doublon simultané → contrainte UNIQUE en base, le second est refusé ; matricule vide → `champ_requis`.
- **Critères d'acceptation** :
  - Étant donné un nouvel agent, quand il prend son service pour la première fois, alors il reçoit le matricule libre suivant.
  - Étant donné le matricule 012 pris, quand un Chef l'attribue à un autre agent, alors il est refusé.
  - Étant donné un Membre qui envoie la modification à la main, quand le serveur la reçoit, alors il refuse `pas_droit`.

---
## 3. Dispatch et alertes

Table `appels` (commune aux fiches 08 à 13) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| id | int PK | Oui | — | auto |
| numero | varchar(12) | Oui | format `A-` + 5 chiffres, unique | auto (A-00001) |
| code | varchar(12) | Oui | ex. `10-90` | selon type |
| titre | varchar(60) | Oui | — | — |
| description | varchar(500) | Non | — | vide |
| x, y, z | float | Oui | coordonnées monde | — |
| rue | varchar(80) | Non | nom de rue (voir 11 et 13) | vide |
| priorite | tinyint | Oui | 1 (urgent), 2 (normal), 3 (faible) | 2 |
| source | enum `tiers`/`agent`/`detresse` | Oui | — | — |
| ressource | varchar(50) | Non | nom de la ressource tierce | vide |
| signalements | int | Oui | ≥ 1 | 1 |
| statut | enum `nouveau`/`pris`/`clos` | Oui | — | `nouveau` |
| pris_par | JSON | Non | liste `{ type = 'agent'|'unite', ref, libelle }` | `[]` |
| clos_par, clos_le, cloture_motif, cloture_note | varchar(60) / datetime / enum / varchar(300) | Non | — | NULL |
| expire_le | datetime | Oui | création + `Config.Police.Dispatch.ExpirationMin` | +30 min |
Les appels non clos sont aussi gardés **en mémoire** (table Lua `AppelsOuverts`, rechargée au démarrage) ; la base n'est écrite qu'à la création, à la prise et à la clôture.

### [MET-POL-08] Dispatch : liste des appels en cours
- **But** : voir en direct les appels non clos, triés par priorité, avec la distance.
- **Qui** : `police.appels` (Recrue+), en service.
- **Où** : Police > Dispatch (onglet « En cours ») ; clic sur un appel depuis l'Accueil ou une notification.
- **Parcours** :
  1. Ouverture → `pop_tablet:police:appels:liste` → le serveur renvoie `AppelsOuverts` (mémoire).
  2. Liste triée : priorité 1 en premier, puis du plus récent au plus ancien. Chaque ligne : numéro, code + titre, rue, distance (calculée côté client avec la position du joueur au moment de l'affichage, arrondie à 10 m, en m sous 1 km, sinon en km à 1 décimale), « il y a X min », statut, qui l'a pris.
  3. Pastille de priorité : 1 = accent plein + mot « Urgent », 2 = blanc, 3 = gris.
  4. Clic sur une ligne → détail à droite : description, position sur mini-carte (image statique de la carte GTA fournie dans la ressource avec un point placé par calcul de coordonnées, pas de carte interactive), source, compteur de signalements, preneurs, boutons « Prendre » et « Itinéraire GPS » (MET-POL-09), « Clôturer » (MET-POL-10).
  5. Nouvel appel : le serveur pousse `pop_tablet:police:appel:nouveau` à chaque agent en service (RC10) ; la ligne apparaît en haut avec un fondu 150 ms ; son court natif `PlaySoundFrontend(-1, 'Event_Message_Purple', 'GTAO_FM_Events_Soundset', false)` si `Config.Police.Dispatch.Son = true`.
  6. Un agent en « Pause » ne reçoit ni son ni notification pour la priorité 3 (la ligne apparaît quand même dans la liste).
  7. Expiration : un appel « nouveau » qui dépasse `expire_le` sans preneur passe en clos avec motif `expire`. Pas de boucle : le serveur fait ce tri au moment de servir la liste et à chaque création d'appel.
- **Données** : table `appels` (affichage).
- **Règles serveur** : RC1, RC2 lecture. Les coordonnées ne sont envoyées qu'aux agents en service.
- **Textes et états** :
  - Vide : « Aucun appel en cours. » (`police.dispatch.vide`) + bouton « Créer un appel » (MET-POL-11).
  - Priorités : « Urgent » (`police.dispatch.prio.1`), « Normal » (`…prio.2`), « Faible » (`…prio.3`).
  - Statuts : « Nouveau » (`police.dispatch.statut.nouveau`), « Pris » (`…statut.pris`), « Clos » (`…statut.clos`).
  - Temps : « il y a {n} min » (`police.dispatch.ilya`), « à l'instant » (`police.dispatch.instant`).
  - Appel clos pendant la lecture : « Cet appel a été clôturé. » (`police.dispatch.dejaclos`), boutons retirés.
- **Notifications** : nouvel appel : « MDT · {code} {titre} — {rue} » (`police.notif.appel`).
- **Liens** : MET-POL-09, 10, 11, 12, 13 ; Accueil.
- **Réglages** : `Config.Police.Dispatch.Son = true` ; `Config.Police.Dispatch.ExpirationMin = 30` ; `Config.Police.Dispatch.MaxOuverts = 100` (au-delà, le plus ancien appel priorité 3 sans preneur est clos `expire`, sinon le plus ancien priorité 2 sans preneur).
- **Journal admin** : non.
- **Performance** : liste en mémoire, aucun SQL à l'affichage ; une notification réseau par agent concerné ; pagination 20.
- **Cas limites** : 100 appels ouverts atteints → règle MaxOuverts ; agent qui prend son service avec des appels déjà ouverts → il les voit à l'ouverture de la liste ; appel clos par un autre pendant qu'on lit le détail → message `dejaclos`.
- **Critères d'acceptation** :
  - Étant donné 2 agents en service, quand un script tiers envoie une alerte, alors les deux voient la ligne en haut de la liste sans recharger.
  - Étant donné un appel priorité 3 et un agent en pause, quand l'appel arrive, alors l'agent ne reçoit pas de notification mais la ligne est dans la liste.
  - Étant donné un civil qui appelle `pop_tablet:police:appels:liste`, quand le serveur le reçoit, alors il refuse et n'envoie aucune coordonnée.

### [MET-POL-09] Prendre un appel et GPS
- **But** : s'attribuer un appel (seul ou avec son unité) et poser l'itinéraire.
- **Qui** : `police.appels` (Recrue+), en service.
- **Où** : Police > Dispatch > détail d'un appel > « Prendre » et « Itinéraire GPS » ; notification d'appel (tablette ouverte) > bouton « Prendre ».
- **Parcours** :
  1. « Prendre » → `pop_tablet:police:appel:prendre { appelId, actionId }`.
  2. Serveur : appel existe et non clos ; si l'agent est dans une unité, c'est **l'unité** qui prend (ajout `{ type = 'unite' }` dans `pris_par`), sinon l'agent seul. Plusieurs agents/unités peuvent prendre le même appel (renfort) jusqu'à `Config.Police.Dispatch.MaxPreneurs = 4`.
  3. Statut appel → `pris` ; agent → « Occupé » ; unité → « En route ». Écriture en base ; événement `pop_tablet:police:appel:maj` à tous les agents en service.
  4. Le serveur renvoie les coordonnées ; le client pose `SetNewWaypoint(x, y)` et un blip temporaire (sprite 161, échelle 1.0, couleur blanche, nom « Appel {numero} ») supprimé à la clôture de l'appel, au retrait de l'agent ou à la fin de service.
  5. Si l'agent est dans une unité, chaque membre reçoit aussi le GPS et le blip.
  6. « Itinéraire GPS » seul (sans prendre) : pose le point GPS côté client, sans rien envoyer au serveur.
  7. « Me retirer » (visible si on a pris l'appel) → retire l'agent/unité de `pris_par` ; s'il n'y a plus personne, le statut repasse `nouveau` et `expire_le` repart de maintenant.
- **Données** : `pris_par` (voir table) ; blip client (non stocké).
- **Règles serveur** : RC1, RC2, RC3. Appel clos → refus. Déjà preneur → succès sans doublon. MaxPreneurs atteint → refus.
- **Textes et états** :
  - Succès : « Appel {numero} pris. GPS activé. » (`police.dispatch.pris`).
  - GPS seul : « Itinéraire posé sur votre GPS. » (`police.dispatch.gps`).
  - Retrait : « Vous vous êtes retiré de l'appel {numero}. » (`police.dispatch.retire`).
  - Erreur clos : « Cet appel a été clôturé. » (`police.dispatch.dejaclos`).
  - Erreur max : « Assez d'unités sont déjà sur cet appel (4). » (`police.dispatch.complet`).
- **Notifications** : membres de l'unité (sauf celui qui a cliqué) : « MDT · Votre unité a pris l'appel {numero}. » (`police.notif.uniteappel`).
- **Liens** : MET-POL-04, 06, 08, 10.
- **Réglages** : `Config.Police.Dispatch.MaxPreneurs = 4` ; `Config.Police.Dispatch.Blip = { sprite = 161, couleur = 0, echelle = 1.0 }`.
- **Journal admin** : non.
- **Performance** : aucun thread : blip créé et supprimé par événement.
- **Cas limites** : deux agents cliquent en même temps → les deux sont ajoutés (renfort autorisé) ; agent qui quitte le service → retiré de tous les appels, blips supprimés ; appel expiré entre l'affichage et le clic → refus `dejaclos`.
- **Critères d'acceptation** :
  - Étant donné un agent seul, quand il prend l'appel A-00012, alors le statut passe « Pris », il passe « Occupé » et un point GPS est posé.
  - Étant donné ADAM-12 à 2 membres, quand l'un prend un appel, alors les deux ont le GPS et l'unité passe « En route ».
  - Étant donné un client qui envoie `prendre` sur un appel clos, quand le serveur le reçoit, alors il refuse et l'appel reste clos.

### [MET-POL-10] Clôturer un appel et historique des appels
- **But** : terminer un appel avec un motif et retrouver les appels passés.
- **Qui** : clôturer : un preneur de l'appel (Recrue+) ou Chef+ pour n'importe quel appel ; historique : `police.appels`.
- **Où** : Police > Dispatch > détail > « Clôturer » ; Police > Dispatch > onglet « Historique ».
- **Parcours** :
  1. « Clôturer » → fenêtre : « Motif » (liste) + « Note » (facultative) + case « Créer un rapport à partir de cet appel ».
  2. `pop_tablet:police:appel:clore` → serveur vérifie, passe `clos`, enregistre motif/note/auteur/heure, retire de `AppelsOuverts`, envoie `appel:maj`, supprime les blips chez les preneurs, repasse les agents « Disponible » s'ils n'ont plus d'appel et les unités « Disponible ».
  3. Case rapport cochée : ouvre MET-POL-22 pré-rempli (titre = titre de l'appel, lieu = rue, lien vers l'appel).
  4. Historique : liste paginée des appels clos (20 par page, plus récent d'abord), filtres « Du… au… », « Motif », texte (numéro, titre, rue). Données lues en base.
- **Données** :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| cloture_motif | enum `traite`/`fausse_alerte`/`sans_suite`/`transfere`/`expire` | Oui | `expire` réservé au serveur | `traite` |
| cloture_note | texte | Non | 300 car. | vide |
- **Règles serveur** : RC1, RC2, RC3, RC4. Non-preneur sous Chef → refus. Appel déjà clos → succès sans rien changer.
- **Textes et états** :
  - Motifs : « Traité » (`police.dispatch.motif.traite`), « Fausse alerte » (`…fausse_alerte`), « Sans suite » (`…sans_suite`), « Transféré (EMS, autre service) » (`…transfere`), « Expiré » (`…expire`).
  - Succès : « Appel {numero} clôturé. » (`police.dispatch.clos`).
  - Historique vide : « Aucun appel clôturé sur cette période. » (`police.dispatch.historique.vide`).
  - Erreur non preneur : « Seuls les agents sur l'appel ou un Chef peuvent le clôturer. » (`police.dispatch.pasprenneur`).
- **Notifications** : les autres preneurs : « MDT · Appel {numero} clôturé par {matricule} {nom}. » (`police.notif.appelclos`).
- **Liens** : Rapports (MET-POL-22), Effectifs, Unités.
- **Réglages** : `Config.Police.Dispatch.HistoriqueJours = 30` (au-delà, les appels clos restent en base mais ne sont plus listés ; visibles par l'admin).
- **Journal admin** : oui seulement pour une clôture par un Chef non preneur (« clôture forcée »).
- **Performance** : historique en base, paginé 20, index sur `(statut, clos_le)`.
- **Cas limites** : deux clôtures simultanées → la première gagne, la seconde reçoit succès sans effet ; preneur déconnecté → un autre preneur ou un Chef clôture ; appel sans preneur → seul un Chef peut le clôturer (sinon expiration).
- **Critères d'acceptation** :
  - Étant donné un appel pris par moi, quand je le clôture « Traité », alors il disparaît de « En cours » et apparaît dans « Historique ».
  - Étant donné la case « Créer un rapport » cochée, quand je valide, alors le formulaire de rapport s'ouvre avec le titre et le lieu de l'appel.
  - Étant donné une Recrue non preneuse qui envoie la clôture à la main, quand le serveur la reçoit, alors il refuse.

### [MET-POL-11] Créer un appel manuel / demande de renfort (ajout)
- **But** : permettre à un agent de créer un appel (contrôle, renfort, poursuite) à sa position ou à son point GPS.
- **Qui** : `police.appels` (Recrue+), en service.
- **Où** : Police > Dispatch > bouton « Créer un appel » ; Police > en-tête > bouton « Renfort ».
- **Parcours** :
  1. « Créer un appel » → fenêtre : « Type » (liste `Config.Police.Dispatch.TypesAgent` qui fixe code + titre + priorité par défaut ; la priorité reste modifiable), « Description », « Position » : « Ma position » (défaut) ou « Mon point GPS actuel ».
  2. « Renfort » → confirmation « Demander du renfort à votre position ? » (`police.dispatch.confirmerrenfort`) → crée un appel type `renfort` (code 10-78, priorité 1) à la position de l'agent.
  3. **Le serveur prend lui-même la position** du ped pour « Ma position » ; pour « point GPS », le client envoie les coordonnées du waypoint (`GetFirstBlipInfoId(8)`), le serveur vérifie qu'elles sont dans la carte (x ∈ [-4000 ; 4500], y ∈ [-4500 ; 8000]).
  4. Le client calcule la rue (`GetStreetNameAtCoord` + `GetStreetNameFromHashKey`) et l'envoie ; le serveur la nettoie (RC4, 80 car.).
  5. Création comme MET-POL-08, `source = 'agent'` ; le créateur (ou son unité) est automatiquement preneur.
- **Données** :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| type | clé de `TypesAgent` | Oui | — | `controle` |
| priorite | 1 à 3 | Oui | — | celle du type |
| description | texte | Non | 500 car. | vide |
| position | enum `moi`/`gps` | Oui | — | `moi` |
- **Règles serveur** : RC1, RC2 (limite propre : 1 appel / 30 s par agent), RC3, RC4.
- **Textes et états** : succès « Appel {numero} créé. » (`police.dispatch.cree`) ; renfort « Renfort demandé. » (`police.dispatch.renfort`) ; erreur pas de GPS « Aucun point GPS posé sur votre carte. » (`police.dispatch.pasgps`) ; rue vide « Lieu inconnu » (`police.dispatch.rueinconnue`).
- **Notifications** : agents en service : « MDT · {code} {titre} — {rue} » ; renfort : « MDT · RENFORT demandé par {matricule} {nom} — {rue} » (`police.notif.renfort`).
- **Liens** : MET-POL-08.
- **Réglages** : `Config.Police.Dispatch.TypesAgent = { controle = { code = '10-38', titre = 'Contrôle routier', priorite = 3 }, renfort = { code = '10-78', titre = 'Demande de renfort', priorite = 1 }, poursuite = { code = '10-80', titre = 'Poursuite en cours', priorite = 1 }, suspect = { code = '10-37', titre = 'Individu suspect', priorite = 2 }, accident = { code = '10-50', titre = 'Accident de la route', priorite = 2 } }`.
- **Journal admin** : non.
- **Performance** : comme MET-POL-08.
- **Cas limites** : spam renfort → 1 / 30 s ; coordonnées GPS hors carte → refus `serveur` avec texte `pasgps` ; agent en intérieur (rue vide) → « Lieu inconnu ».
- **Critères d'acceptation** :
  - Étant donné un agent en service, quand il clique « Renfort » et confirme, alors tous les agents reçoivent « RENFORT demandé… » et un appel priorité 1 existe à sa position.
  - Étant donné « Mon point GPS actuel » sans point posé, quand il valide, alors il voit « Aucun point GPS posé sur votre carte. ».
  - Étant donné un client qui envoie de fausses coordonnées pour « Ma position », quand le serveur crée l'appel, alors il utilise la vraie position du ped.

### [MET-POL-12] Bouton de détresse agent (ajout)
- **But** : alerte maximale « agent en danger » en une touche, même tablette fermée.
- **Qui** : tout agent en service, non réglable.
- **Où** : Police > en-tête > bouton « Détresse » ; touche clavier `RegisterKeyMapping('poptablet_detresse', 'MDT : bouton de détresse', 'keyboard', Config.Police.Detresse.Touche)` (vide par défaut ; le joueur la choisit dans les paramètres GTA > Touches > FiveM).
- **Parcours** :
  1. Tablette ouverte : clic puis confirmation « Envoyer l'alerte de détresse ? » (`police.detresse.confirmer`). Touche clavier : envoi direct, sans confirmation.
  2. Le serveur vérifie le service, prend la position du ped, crée un appel `source = 'detresse'`, code `10-99`, titre « AGENT EN DÉTRESSE », priorité 1, aucun preneur.
  3. Tous les agents en service (même en pause) reçoivent la notification, le son `Config.Police.Detresse.Son` et un blip clignotant (sprite 526, `SetBlipFlashes`) qui suit l'agent pendant `Config.Police.Detresse.DureeSuiviSec = 60` s : le serveur renvoie la position toutes les 5 s via un `SetTimeout` en chaîne, arrêté au bout de 60 s ou à la clôture de l'appel.
- **Données** : table `appels`.
- **Règles serveur** : RC1, limite propre 1 / 30 s, RC3.
- **Textes et états** : succès « Alerte de détresse envoyée. » (`police.detresse.envoyee`) ; erreur fréquence « Alerte déjà envoyée. Attendez 30 secondes. » (`police.detresse.attente`) ; hors service (touche) : 0.3 `hors_service` en notification native.
- **Notifications** : agents en service : « MDT · 10-99 AGENT EN DÉTRESSE : {matricule} {nom} — {rue} » (`police.notif.detresse`). Si `Config.Police.Detresse.PrevenirEMS = true`, EMS en service : « Agent de police en détresse — {rue} » (`ems.notif.detresse`).
- **Liens** : Dispatch ; EMS (option).
- **Réglages** : `Config.Police.Detresse.Touche = ''` ; `Config.Police.Detresse.DureeSuiviSec = 60` ; `Config.Police.Detresse.Son = { nom = 'Beep_Red', set = 'DLC_HEIST_HACKING_SNAKE_SOUNDS' }` ; `Config.Police.Detresse.PrevenirEMS = false`.
- **Journal admin** : oui (qui, position, heure).
- **Performance** : aucun thread client ; suivi serveur limité à 60 s ; touche par `RegisterKeyMapping` (aucune boucle de touche).
- **Cas limites** : agent mort qui appuie → autorisé ; agent déconnecté pendant le suivi → suivi arrêté, dernière position gardée ; touche appuyée hors service → rien n'est créé.
- **Critères d'acceptation** :
  - Étant donné un agent en service tablette fermée, quand il appuie sur sa touche détresse, alors tous les agents reçoivent l'alerte et un blip clignotant.
  - Étant donné une alerte envoyée il y a 10 s, quand il réappuie, alors il voit « Alerte déjà envoyée. Attendez 30 secondes. ».
  - Étant donné un civil qui déclenche l'événement détresse à la main, quand le serveur le reçoit, alors rien n'est créé.

### [MET-POL-13] Alertes des scripts tiers (API dispatch)
- **But** : permettre à n'importe quel script (braquage, coups de feu, vol de voiture, téléphone 911) d'envoyer une alerte au dispatch police.
- **Qui** : scripts serveur et client ; reçue par les agents en service.
- **Où** : API documentée (fichier ouvert `docs/api.md`) : export serveur, export client, événement serveur.
- **Parcours** :
  1. Côté serveur (recommandé) : `exports['pop_tablet']:PoliceAlert(data)` (raccourci de `DispatchAlert` de la base, BASE-API-10, avec `service = 'police'`) ou `TriggerEvent('pop_tablet:dispatchAlert', data)`.
  2. Côté client (pour les scripts qui détectent sur le client, ex. coups de feu) : `exports['pop_tablet']:PoliceAlert(data)` client → le client complète `coords` (position du ped si absente) et `rue`, puis envoie `pop_tablet:dispatchFromClient` au serveur.
  3. Le serveur valide `data`, applique l'anti-spam et la fusion, crée l'appel `source = 'tiers'`, `ressource = GetInvokingResource()` (ou nom envoyé par le client, nettoyé), puis notifie comme MET-POL-08.
  4. Retour de l'export serveur : numéro de l'appel (`'A-00042'`) ou `false, raison` (`'invalid'`, `'spam'`, `'disabled'`).
  5. `data.jobs` facultatif envoie aussi à d'autres métiers de l'app Métiers (ex. `{ 'police', 'ambulance' }`) ; défaut `Config.Police.Jobs`.
  6. Si `Config.Police.Api.EcouterEvenementsConnus = true`, le serveur écoute aussi l'événement générique `pop_tablet:dispatchAlert` (même format).
  7. **Scripts écrits pour un autre dispatch** : les adaptateurs de compatibilité de la base (BASE-API-11, fichiers ouverts `bridge/dispatch/`) reprennent les exports et événements de ps-dispatch, cd_dispatch et core_dispatch (actifs par défaut si le vrai script n'est pas démarré, réglage `Config.Dispatch.Compat`) et les transforment en alertes de cette fiche (`ressource` = nom de l'adaptateur). Sans adaptateur, le dispatch fonctionne avec les appels manuels (MET-POL-11), la détresse (MET-POL-12) et les scripts qui appellent directement `PoliceAlert` / `DispatchAlert`.
- **Données** (`data`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| code | texte | Non | 12 car. | `10-90` |
| titre | texte | Oui | 60 car. | — |
| description | texte | Non | 500 car. | vide |
| coords | vector3 ou `{x,y,z}` | Oui côté serveur, auto côté client | dans la carte | ped du joueur source |
| rue | texte | Non | 80 car. | calculée côté client, sinon vide |
| priorite | 1, 2 ou 3 | Non | — | 2 |
| jobs | liste | Non | jobs existants | `Config.Police.Jobs` |
| blip | `{ sprite, couleur, echelle }` | Non | sprite 1–900 | `Config.Police.Dispatch.Blip` |
| expireMin | int | Non | 5 à 120 | 30 |
- **Règles serveur** :
  - Export serveur : appel de confiance, mais champs validés et nettoyés (RC4).
  - Événement client : **non fiable** → limite `Config.Police.Api.LimiteClient = { n = 3, s = 60 }` par joueur ; coordonnées remplacées par la position serveur du ped émetteur si l'écart dépasse 50 m ; ressource vérifiée dans `Config.Police.Api.RessourcesClientAutorisees` (liste vide = toutes acceptées).
  - Fusion : même `titre` + coordonnées à moins de `Config.Police.Api.FusionRayon = 50` m dans les `Config.Police.Api.FusionSec = 60` s → pas de nouvel appel ; l'appel existant reçoit `signalements + 1` (affiché « ×{n} ») et sa dernière heure d'alerte est mise à jour.
  - Aucun agent en service → l'appel est créé quand même (visible à la prise de service) ; l'export renvoie le numéro.
- **Textes et états** : textes fournis par le script (nettoyés). Compteur « ×{n} signalements » (`police.dispatch.signalements`). Ligne « Source : {ressource} » (`police.dispatch.source`).
- **Notifications** : comme MET-POL-08 ; aucune nouvelle notification pour une alerte fusionnée.
- **Liens** : Dispatch ; BASE-API-10 et BASE-API-11 (adaptateurs ps-dispatch, cd_dispatch, core_dispatch) ; écouté : `pop_tablet:dispatchAlert`, export `PoliceAlert` ; émis : `TriggerEvent('pop_tablet:callCreated', numero, data)`.
- **Réglages** : `Config.Police.Api.Active = true` ; `Config.Police.Api.LimiteClient = { n = 3, s = 60 }` ; `Config.Police.Api.FusionRayon = 50` ; `Config.Police.Api.FusionSec = 60` ; `Config.Police.Api.RessourcesClientAutorisees = {}` ; `Config.Police.Api.EcouterEvenementsConnus = true`.
- **Journal admin** : non (les refus pour spam client sont journalisés avec le joueur et la ressource).
- **Performance** : aucun coût tant qu'aucune alerte n'arrive ; fusion vérifiée sur la liste en mémoire (≤ 100 éléments).
- **Cas limites** : 50 alertes de coups de feu en 10 s au même endroit → 1 appel « ×50 » ; titre absent → `false, 'invalid'` ; `Config.Police.Api.Active = false` → `false, 'disabled'` ; coordonnées NaN → `invalid`.
- **Critères d'acceptation** :
  - Étant donné un script de braquage, quand il appelle `exports['pop_tablet']:PoliceAlert({ titre = 'Braquage supérette', coords = vec3(25.7, -1347.3, 29.5), priorite = 1 })`, alors les agents en service voient l'appel en haut avec « Source : {ressource} » et l'export renvoie son numéro.
  - Étant donné 5 alertes identiques en 20 s au même endroit, quand elles arrivent, alors un seul appel existe avec « ×5 signalements ».
  - Étant donné un tricheur qui envoie 20 alertes client en 1 min, quand le serveur les reçoit, alors seules 3 passent et le refus est journalisé.
  - Étant donné un script de braquage écrit pour ps-dispatch et ps-dispatch non installé, quand il appelle `exports['ps-dispatch']:StoreRobbery()`, alors l'appel apparaît dans le Dispatch avec « Source : ps-dispatch ».

---
## 4. Citoyens et véhicules

Table `citoyens` (complément police de `users`, une ligne créée à la première écriture) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| identifier | varchar(60) PK | Oui | — | — |
| photo | varchar(255) | Non | URL RC5 ou `media:<id>` | vide (silhouette grise) |
| empreinte | char(10) | Oui | `EMP-` + 6 caractères hexadécimaux, unique | calculé (MET-POL-37) |
| empreinte_fichee | bool | Oui | — | 0 |
| dangereux | bool | Oui | — | 0 |
| maj_le | datetime | Oui | — | — |

### [MET-POL-14] Recherche de citoyen
- **But** : retrouver un citoyen par nom, prénom, date de naissance, téléphone ou empreinte.
- **Qui** : `police.citoyens.lire` (Recrue+), en service.
- **Où** : Police > Citoyens > champ de recherche ; recherche rapide de l'Accueil.
- **Parcours** :
  1. L'agent tape au moins 2 caractères et appuie sur Entrée (pas de recherche à chaque frappe).
  2. `pop_tablet:police:citoyens:recherche { texte, page }`.
  3. Serveur : découpe le texte en mots ; requête préparée sur `users` : `CONCAT(firstname,' ',lastname) LIKE ?` ou `lastname LIKE ?` ou `dateofbirth = ?` (si le texte ressemble à une date JJ/MM/AAAA) ou `phone_number = ?` (si la colonne existe, détectée au démarrage) ; ou `citoyens.empreinte = ?` si le texte commence par `EMP-` **et** que `empreinte_fichee = 1`.
  4. Résultats paginés 20 : photo miniature, nom, date de naissance, sexe, pastilles « Mandat » (mandat actif), « Recherché » (avis actif), « Dangereux ».
  5. Clic → fiche citoyen (MET-POL-15).
- **Données** :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| texte | texte | Oui | 2 à 50 car. | — |
| page | int | Non | ≥ 1 | 1 |
- **Règles serveur** : RC1, RC2 lecture, RC4. Jamais d'identifier envoyé à la NUI : le serveur donne un `ref` opaque (hash HMAC de l'identifier avec une clé aléatoire générée au démarrage du serveur) et retrouve l'identifier à partir du `ref`.
- **Textes et états** :
  - Avant recherche : « Cherchez un citoyen par nom, date de naissance (JJ/MM/AAAA), téléphone ou empreinte. » (`police.citoyens.aide`).
  - Vide : « Aucun citoyen trouvé. Vérifiez l'orthographe. » (`police.citoyens.vide`).
  - Empreinte non fichée : « Empreinte inconnue au fichier. » (`police.citoyens.empreinteinconnue`).
  - Pastilles : « Mandat » (`police.citoyens.badge.mandat`), « Recherché » (`…badge.recherche`), « Dangereux » (`…badge.dangereux`).
- **Notifications** : aucune.
- **Liens** : MET-POL-15, 37 (empreintes), 28 et 31 (mandats et avis).
- **Réglages** : `Config.Police.JournalRecherches = false`.
- **Journal admin** : non par défaut ; oui si `JournalRecherches = true` (texte cherché, nombre de résultats).
- **Performance** : requête paginée 20 avec `LIMIT/OFFSET` ; index conseillé `users(lastname)` créé si absent ; pastilles calculées par une seule requête `IN (...)` sur la page.
- **Cas limites** : 1 000 « Smith » → pagination ; texte `%` → échappé ; joueur jamais connecté au MDT → trouvé quand même (lecture `users`).
- **Critères d'acceptation** :
  - Étant donné « John Doe » né le 01/02/1990, quand je cherche « 01/02/1990 », alors il apparaît.
  - Étant donné une empreinte non fichée, quand je la cherche, alors « Empreinte inconnue au fichier. » s'affiche.
  - Étant donné un client qui envoie `texte = "' OR 1=1 --"`, quand le serveur l'exécute, alors il cherche ce texte littéral et ne renvoie rien d'anormal.

### [MET-POL-15] Fiche citoyen
- **But** : tout savoir d'un citoyen sur un seul écran.
- **Qui** : `police.citoyens.lire` (Recrue+), en service. Les onglets d'écriture suivent leurs propres droits.
- **Où** : Police > Citoyens > clic sur un résultat ; liens depuis rapports, amendes, casier, mandats.
- **Parcours** :
  1. `pop_tablet:police:citoyen:fiche { ref }` → le serveur renvoie l'en-tête + le premier onglet uniquement (« Résumé »).
  2. En-tête : photo (MET-POL-16), nom, date de naissance + âge calculé, sexe, taille, métier ESX (label job), téléphone (si colonne détectée), empreinte (affichée seulement si fichée), pastilles Mandat / Recherché / Dangereux. Bouton « Marquer dangereux » (bascule, `police.mandat.creer`).
  3. Onglets (chacun chargé au clic, paginé 20) :
     - « Résumé » : 3 derniers éléments de casier, mandats actifs, avis actifs, amendes impayées (nombre + total), 3 dernières notes.
     - « Permis » : permis du framework (ESX `user_licenses` ; QBCore / Qbox `PlayerData.metadata.licences`, ex. `driver`, `weapon` ; types listés par `Config.Police.Permis.Libelles`), état « Valide » / « Retiré le {date} » (MET-POL-18).
     - « Véhicules » : `Bridge.GetVehicles(identifier)` (BASE-MOT-02 : ESX `owned_vehicles`, QBCore / Qbox `player_vehicles`) : plaque, modèle (nom d'affichage du modèle calculé côté client avec `GetDisplayNameFromVehicleModel` + `GetLabelText`), pastille « Signalé » ; clic → MET-POL-19.
     - « Casier » : MET-POL-26/27.
     - « Amendes » : MET-POL-25 filtré sur ce citoyen.
     - « Mandats et avis » : MET-POL-28 et MET-POL-31 filtrés.
     - « Rapports » : rapports où il est lié (MET-POL-22).
     - « Notes » : MET-POL-17.
     - « Certificats EMS » : certificats que l'app EMS a marqués `visible_police = 1` (type, date, médecin, validité, texte court). Lecture seule.
     - « Propriétés » : seulement si un script immobilier a déclaré la source `exports['pop_tablet']:RegisterPropertySource(fn)` (fonction qui renvoie la liste d'adresses) ; sinon l'onglet est caché.
  4. Boutons d'action en bas : « Nouvelle amende » (MET-POL-24), « Ajouter au casier » (MET-POL-26), « Créer un mandat » (MET-POL-28), « Nouveau rapport » (MET-POL-22, citoyen pré-lié), « Prendre la photo » (MET-POL-16). Chaque bouton suit son droit.
- **Données** (affichées) : `users` (RC9), `citoyens`, `user_licenses`, véhicules lus par `Bridge.GetVehicles` (`owned_vehicles` sur ESX, `player_vehicles` sur QBCore / Qbox), tables police, certificats EMS.
- **Règles serveur** : RC1, RC2 lecture. Chaque onglet revérifie son droit de lecture. Certificats EMS : seulement `visible_police = 1`. Le dossier médical complet n'est jamais envoyé à la police.
- **Textes et états** :
  - Onglets vides : Permis « Aucun permis. » (`police.fiche.permis.vide`) ; Véhicules « Aucun véhicule à son nom. » (`…vehicules.vide`) ; Casier « Casier judiciaire vierge. » (`…casier.vide`) ; Amendes « Aucune amende. » (`…amendes.vide`) ; Mandats « Aucun mandat ni avis. » (`…mandats.vide`) ; Rapports « Cité dans aucun rapport. » (`…rapports.vide`) ; Notes « Aucune note. Ajoutez la première. » (`…notes.vide`) ; Certificats « Aucun certificat transmis par les EMS. » (`…certificats.vide`).
  - Succès dangereux : « Citoyen marqué dangereux. » / « Mention dangereux retirée. » (`police.fiche.dangereux.on` / `.off`).
  - Introuvable : RC 0.3 `introuvable`.
- **Notifications** : aucune.
- **Liens** : EMS (certificats), Véhicules, Casier, Amendes, Mandats, Rapports, Justice (les affaires où il est partie sont listées dans « Rapports » avec la mention « Transmis à la justice »).
- **Réglages** : `Config.Police.Permis.Libelles = { dmv = 'Code de la route', drive = 'Permis voiture', drive_bike = 'Permis moto', drive_truck = 'Permis poids lourd', weapon = 'Permis de port d\'arme' }` ; `Config.Police.Fiche.AfficherTelephone = true`.
- **Journal admin** : non (marquage dangereux : oui).
- **Performance** : en-tête + résumé à l'ouverture (5 requêtes légères), onglets à la demande, pagination 20 ; rien en cache (données vivantes).
- **Cas limites** : citoyen supprimé de `users` (personnage effacé) → fiche « Ce citoyen n'existe plus. » (`police.fiche.supprime`) mais les rapports et casier restent consultables par l'admin ; colonne `phone_number` absente → ligne téléphone cachée ; app EMS désactivée → onglet Certificats caché.
- **Critères d'acceptation** :
  - Étant donné un citoyen avec 2 véhicules, quand j'ouvre l'onglet Véhicules, alors je vois 2 plaques cliquables.
  - Étant donné un certificat EMS non marqué visible police, quand j'ouvre l'onglet Certificats, alors il n'apparaît pas.
  - Étant donné un client qui envoie un `ref` inventé, quand le serveur le reçoit, alors il renvoie `introuvable`.

### [MET-POL-16] Photo d'identité du citoyen
- **But** : associer une photo au dossier (galerie, URL autorisée ou photo prise sur place).
- **Qui** : `police.citoyens.lire` + `police.rapport` (Recrue+), en service.
- **Où** : Police > fiche citoyen > clic sur la photo > « Changer la photo » ou bouton « Prendre la photo ».
- **Parcours** :
  1. « Changer la photo » → choix « Depuis la Galerie » (sélecteur de la Galerie de l'agent) ou « Lien d'image » (champ URL).
  2. « Prendre la photo » (visible si `screencapture` est démarré) : le serveur vérifie qu'un joueur dont l'identifier correspond est à ≤ 3 m (RC6) ; le client de l'agent fait face à la cible : caméra scriptée placée à 1,2 m devant la tête de la cible (bone `SKEL_Head`), FOV 35, 1 s, capture via `exports['screencapture']:serverCapture` déclenchée par le serveur sur le client de l'**agent**, image envoyée à l'hébergement d'images de la tablette, puis enregistrée en `media:id` dans la Galerie de l'agent.
  3. `pop_tablet:police:citoyen:photo { ref, image, actionId }` → serveur valide RC5, enregistre `citoyens.photo`, ajoute une ligne `historique` (« Photo mise à jour »).
- **Données** : `citoyens.photo` (voir table).
- **Règles serveur** : RC1, RC2, RC3, RC5, RC6 (pour « Prendre la photo »). Taille image max `Config.Images.TailleMaxKo = 500`.
- **Textes et états** : succès « Photo mise à jour. » (`police.photo.ok`) ; erreur domaine : RC 0.3 `image` ; erreur loin : `trop_loin` ; screencapture absent : bouton caché.
- **Notifications** : aucune.
- **Liens** : Galerie (lecture, écriture de la capture).
- **Réglages** : `Config.Police.Photo.CaptureActive = true`.
- **Journal admin** : oui (ancienne et nouvelle URL).
- **Performance** : caméra temporaire 1 s, détruite après ; aucun thread.
- **Cas limites** : cible qui s'éloigne pendant la capture → capture faite, le serveur revérifie la distance avant d'enregistrer et refuse si > 3 m ; URL d'un domaine interdit → refus ; échec d'envoi de l'image → « La photo n'a pas pu être envoyée. Réessayez. » (`police.photo.echec`).
- **Critères d'acceptation** :
  - Étant donné une photo de la Galerie, quand je la choisis, alors elle s'affiche sur la fiche chez tous les agents.
  - Étant donné un suspect à 2 m, quand je clique « Prendre la photo », alors une photo de son visage est enregistrée.
  - Étant donné une URL d'un domaine non autorisé envoyée à la main, quand le serveur la reçoit, alors il refuse `image`.

### [MET-POL-17] Notes sur un citoyen
- **But** : laisser des informations internes (comportement, contacts, signalements) sur un dossier.
- **Qui** : écrire : `police.notes` (Recrue+) ; archiver sa propre note : l'auteur ; archiver toute note : Chef+.
- **Où** : Police > fiche citoyen > onglet « Notes » > « Ajouter une note ».
- **Parcours** :
  1. Zone de texte + case « Importante » (épinglée en haut, accent).
  2. `pop_tablet:police:note:ajouter` → serveur enregistre, renvoie la note.
  3. Liste : plus récente d'abord, épinglées en premier ; chaque note : auteur (matricule + nom), date, texte.
  4. « Archiver » → confirmation → RC7.
- **Données** (table `notes`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| identifier | varchar(60) | Oui | citoyen | — |
| auteur | varchar(60) | Oui | identifier agent | — |
| texte | text | Oui | 1 à 1000 car. | — |
| importante | bool | Oui | — | 0 |
| archive, archive_par, archive_le | — | — | RC7 | 0 |
- **Règles serveur** : RC1, RC2, RC3, RC4, RC7. Max 200 notes actives par citoyen (au-delà, refus « Archivez d'anciennes notes »).
- **Textes et états** : vide (MET-POL-15) ; succès « Note ajoutée. » (`police.notes.ok`), « Note archivée. » (`police.notes.archivee`) ; erreur max : « Trop de notes sur ce dossier. Archivez les plus anciennes. » (`police.notes.max`).
- **Notifications** : aucune.
- **Liens** : fiche citoyen (Résumé).
- **Réglages** : `Config.Police.Notes.Max = 200`.
- **Journal admin** : oui pour l'archivage.
- **Performance** : paginé 20, chargé à l'ouverture de l'onglet.
- **Cas limites** : texte vide → `champ_requis` ; 1 001 caractères → `trop_long` ; auteur parti de la police → la note reste avec son nom.
- **Critères d'acceptation** :
  - Étant donné une note « Importante », quand j'ouvre l'onglet, alors elle est en haut.
  - Étant donné une note d'un collègue, quand une Recrue tente de l'archiver, alors le bouton est absent et le serveur refuse si forcé.
  - Étant donné un texte contenant `<img onerror=...>`, quand il est enregistré, alors il s'affiche comme texte sans balise.

### [MET-POL-18] Permis : retirer, suspendre, rendre (ajout)
- **But** : retirer ou rendre un permis (ESX, QBCore ou Qbox) depuis la fiche, avec trace.
- **Qui** : `police.permis` (Membre+), en service, réglable.
- **Où** : Police > fiche citoyen > onglet « Permis » > bouton « Retirer » / « Rendre » sur chaque permis.
- **Parcours** :
  1. « Retirer » → fenêtre : « Motif » (obligatoire), « Durée » (« Définitif » ou nombre de jours 1–90), case « Lier à un rapport » (sélecteur des rapports du citoyen).
  2. `pop_tablet:police:permis:retirer` → serveur retire le permis via le bridge (ESX : ligne `user_licenses (type, owner)` par `TriggerEvent('esx_license:removeLicense', ...)` si présent, sinon requête directe ; QBCore : `Player.Functions.SetMetaData('licences', …)` avec le type à `false` ; Qbox : `exports.qbx_core:SetMetadata(src, 'licences', …)` ; joueur hors ligne QBCore / Qbox : colonne JSON `players.metadata`), écrit `permis_historique`, ajoute `historique`.
  3. Durée en jours : à la connexion du joueur (événement `esx:playerLoaded`) et à l'ouverture de la fiche, le serveur vérifie les retraits expirés et rend le permis automatiquement (pas de boucle).
  4. « Rendre » (permis retiré) → remet la ligne `user_licenses`, met `rendu_le` et `rendu_par`.
- **Données** (table `permis_historique`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| identifier | varchar(60) | Oui | — | — |
| type | varchar(30) | Oui | clé `user_licenses` | — |
| motif | varchar(300) | Oui | — | — |
| jours | int | Non | 1 à 90, NULL = définitif | NULL |
| retire_par / retire_le | varchar / datetime | Oui | — | — |
| rendu_par / rendu_le | varchar / datetime | Non | — | NULL |
| rapport_id | int | Non | — | NULL |
- **Règles serveur** : RC1, RC2, RC3, RC4. Permis non possédé → refus. Permis déjà retiré → refus.
- **Textes et états** : succès « Permis retiré : {permis}. » (`police.permis.retire`), « Permis rendu : {permis}. » (`police.permis.rendu`) ; erreur « Ce citoyen n'a pas ce permis. » (`police.permis.absent`) ; état « Retiré jusqu'au {date} » / « Retiré définitivement » (`police.permis.etat.jusqua` / `.definitif`).
- **Notifications** : le citoyen (s'il est en ville, notification native même sans tablette) : « Votre {permis} a été retiré par la police. Motif : {motif}. » (`police.notif.permisretire`) ; rendu : « Votre {permis} vous a été rendu. » (`police.notif.permisrendu`).
- **Liens** : ESX licences (auto-école, armurerie lisent `user_licenses`), Rapports, Justice (un juge peut voir l'historique).
- **Réglages** : `Config.Police.Permis.DureeMaxJours = 90`.
- **Journal admin** : oui (permis, motif, durée).
- **Performance** : écriture unique ; vérification des expirations seulement à la connexion du joueur concerné et à l'ouverture de sa fiche.
- **Cas limites** : citoyen déconnecté → retrait fait en base, notification au prochain chargement ; double clic → RC3 ; retrait de 30 jours expiré pendant que le joueur est hors ligne → rendu à sa connexion.
- **Critères d'acceptation** :
  - Étant donné un permis voiture, quand je le retire 7 jours, alors il disparaît de `user_licenses` et réapparaît à la première connexion après 7 jours.
  - Étant donné un permis retiré, quand je clique « Rendre », alors il revient et l'historique garde le retrait.
  - Étant donné une Recrue qui envoie le retrait à la main, quand le serveur le reçoit, alors il refuse `pas_droit`.

### [MET-POL-19] Recherche et fiche véhicule
- **But** : tout savoir d'un véhicule à partir de sa plaque.
- **Qui** : `police.vehicules.lire` (Recrue+), en service.
- **Où** : Police > Véhicules > champ « Plaque » ; recherche rapide ; lien depuis la fiche citoyen ; bouton « Plaque du véhicule devant moi ».
- **Parcours** :
  1. L'agent tape une plaque (2 à 8 caractères, espaces ignorés, majuscules forcées) + Entrée → `pop_tablet:police:vehicule:recherche`.
  2. « Plaque du véhicule devant moi » : le client fait un rayon (`StartShapeTestCapsule` de la caméra vers l'avant, 20 m, une seule fois au clic), lit `GetVehicleNumberPlateText` et lance la recherche.
  3. Serveur : `Bridge.FindPlate(plaque)` (BASE-MOT-02 : ESX `owned_vehicles`, QBCore / Qbox `player_vehicles`, plaque normalisée) ; recherche partielle ≥ 3 caractères : même table, `LIKE` paginé 20 (requête fournie par le bridge pour le framework détecté).
  4. Fiche véhicule : plaque, modèle (nom d'affichage côté client à partir du hash dans `vehicle` JSON), couleur principale (index → libellé de `Config.Police.Vehicules.Couleurs`), type (`car`/`boat`/`aircraft`), propriétaire (nom cliquable → MET-POL-15, ou « Entreprise : {label} » si `ownerType = 'company'`), pastilles « SIGNALÉ », « Mandat sur le propriétaire ». Aucune mention « volé » : la tablette ne marque jamais un véhicule comme volé (décision du client : aucune fonction ne pénalise les biens des joueurs) ; une plainte pour vol est un rapport écrit (MET-POL-20).
  5. Onglets chargés au clic : « Carnet d'entretien » (seulement si `Config.Mechanic.Logbook.PoliceCanRead = true`, désactivé par défaut : le carnet est visible par le propriétaire et les garages, MET-MEC-05), « Historique » (table `historique` où `cible_type = 'vehicule'` : signalements, plaintes, amendes liées, rapports liés, fourrière si un script l'a déclarée via l'API), « Rapports » (rapports liés, dont les plaintes).
  6. Plaque inconnue (`Bridge.FindPlate` renvoie `nil`) : fiche « Véhicule non immatriculé au fichier » avec les seuls signalements éventuels (un agent peut signaler une plaque inconnue).
- **Données** : véhicules lus par `Bridge.FindPlate` (lecture seule, jamais modifiés), table `vehicules` :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| plaque | varchar(8) PK | Oui | majuscules, sans espace | — |
| signale | bool | Oui | — | 0 |
| motif | varchar(300) | Non | — | vide |
| maj_par / maj_le | varchar / datetime | Oui | — | — |
  Table `historique` (commune) : `cible_type` enum `citoyen`/`vehicule`, `cible_id` varchar(60), `type` varchar(30), `ref_id` int, `texte` varchar(300), `auteur`, `cree_le`.
- **Règles serveur** : RC1, RC2 lecture, RC4. Le nom du propriétaire n'est jamais déduit du client.
- **Textes et états** : avant recherche « Entrez une plaque ou visez un véhicule. » (`police.vehicules.aide`) ; vide « Aucun véhicule avec cette plaque. » (`police.vehicules.vide`) ; non immatriculé « Véhicule non immatriculé au fichier. » (`police.vehicules.inconnu`) ; aucun véhicule visé « Aucun véhicule devant vous. » (`police.vehicules.pasvise`) ; carnet vide « Aucun entretien enregistré. » (`police.vehicules.carnet.vide`) ; historique vide « Aucun historique. » (`police.vehicules.historique.vide`).
- **Notifications** : aucune.
- **Liens** : Mécano (carnet, lecture), fiche citoyen, Rapports, Amendes ; API `exports['pop_tablet']:VehicleHistoryAdd(plaque, type, texte)` pour les scripts fourrière/garage.
- **Réglages** : `Config.Police.Vehicules.Couleurs` (table index GTA → libellé, 160 entrées fournies) ; `Config.Police.Vehicules.DistanceVisee = 20.0`.
- **Journal admin** : non.
- **Performance** : requête par plaque exacte (index sur `owned_vehicles.plate` ou `player_vehicles.plate` créé si absent) ; rayon de visée exécuté une seule fois au clic.
- **Cas limites** : plaque avec espaces (`" AB 123 "`) → normalisée ; véhicule de société (ESX `owner = society_xxx`) → affiche l'entreprise ; app Mécano désactivée ou `PoliceCanRead = false` → onglet Carnet caché ; serveur Qbox → même fiche, lue dans `player_vehicles`.
- **Critères d'acceptation** :
  - Étant donné un véhicule possédé, quand je vise la voiture et clique « Plaque du véhicule devant moi », alors sa fiche s'ouvre avec le propriétaire.
  - Étant donné un serveur QBCore et un véhicule de `player_vehicles`, quand je cherche sa plaque, alors sa fiche s'ouvre avec le nom du propriétaire tiré de `players.charinfo`.
  - Étant donné un client qui envoie une plaque de 40 caractères, quand le serveur la reçoit, alors il refuse `trop_long`.

### [MET-POL-20] Signaler une plaque et enregistrer une plainte pour vol (rapport écrit)
- **But** : permettre à un agent de signaler une plaque recherchée pour une enquête, et d'enregistrer à la main la plainte d'un citoyen pour vol de véhicule, sans aucun marquage « volé » ni effet sur le véhicule.
- **Qui** : `police.vehicules.signaler` (Recrue+), en service.
- **Où** : Police > fiche véhicule > boutons « Signaler » / « Lever le signalement » et « Enregistrer une plainte ».
- **Parcours** :
  1. **Décision du client** : aucune fonction de la tablette ne pénalise les biens des joueurs (véhicules souvent payés en argent réel). Il n'existe donc **aucune** détection ou alerte automatique « véhicule volé », aucun export `ReportStolen`, aucun drapeau « volé » (ni dans la fiche véhicule, ni dans le carnet d'entretien, ni pour un concessionnaire ou une reprise), aucune notification de vol aux agents.
  2. « Enregistrer une plainte » → ouvre le formulaire de rapport (MET-POL-22) avec le modèle « Plainte pour vol de véhicule » (modèle par défaut de MET-POL-21 : champs « Plaignant », « Date et lieu des faits », « Récit », « Suspects éventuels ») ; la plaque est liée avec le rôle `plainte`, le plaignant est lié au rôle `plaignant`. Tout est écrit à la main par l'agent.
  3. À l'enregistrement, le serveur ajoute une ligne `historique` (`type = 'plainte'`, texte « Plainte enregistrée : rapport {numero} ») sur la plaque ; rien d'autre ne change : la fiche n'affiche aucun badge, le véhicule et son propriétaire ne subissent aucun effet.
  4. « Signaler » (plaque recherchée dans une enquête, motif obligatoire) → `pop_tablet:police:vehicule:flag { plaque, etat = true, motif, actionId }` : met `vehicules.signale = 1`, ajoute `historique`, met à jour le cache mémoire `PlaquesSignalees` ; « Lever le signalement » → `etat = false`. Le signalement n'est visible que dans l'app Police ; il ne bloque, ne retire ni ne modifie rien.
  5. API lecture pour un radar de plaques : `exports['pop_tablet']:IsVehicleFlagged(plaque)` renvoie `{ signale = bool, motif }` (lecture du cache). Aucun export d'écriture.
- **Données** : table `vehicules` (`plaque`, `signale`, `motif`, `maj_par`, `maj_le`) ; plainte = rapport (`rapports`, `rapport_liens` rôle `plainte`).
- **Règles serveur** : RC1, RC2, RC3, RC4. Lever un signalement : n'importe quel agent (Recrue+). Plaque normalisée (majuscules, sans espace). Toute action réseau ou export nommé `ReportStolen` ou contenant un champ `vole` est refusé `invalide` (le champ n'existe plus). Motif du signalement : 3 à 300 car.
- **Textes et états** : succès « Véhicule {plaque} signalé. » (`police.vehicules.signale.ok`), « Signalement levé. » (`police.vehicules.leve`), « Plainte enregistrée : rapport {numero}. » (`police.vehicules.plainte.ok`) ; bouton « Enregistrer une plainte » (`police.vehicules.plainte`) ; modèle « Plainte pour vol de véhicule » (`police.rapports.modele.plainte_vol`) ; erreur motif : `champ_requis`.
- **Notifications** : signalement : agents en service « MDT · Véhicule {plaque} signalé : {motif} » (`police.notif.vehicule`). Plainte : aucune notification.
- **Liens** : fiche véhicule (MET-POL-19), Rapports (MET-POL-21, MET-POL-22), Accueil (avis véhicules comptés dans « Avis de recherche »), API radar (lecture).
- **Réglages** : aucun (l'ancien `Config.Police.Vehicules.DeclarationCitoyen` est supprimé).
- **Journal admin** : oui (signalement, levée, plainte enregistrée).
- **Performance** : cache mémoire `PlaquesSignalees` chargé au démarrage (une requête), lu en O(1) ; plainte = une écriture de rapport.
- **Cas limites** : plaque déjà signalée → succès sans doublon ; plaque inconnue → signalement et plainte autorisés ; double clic → RC3 ; plaignant hors ville → le rapport est enregistré avec son nom tapé dans le champ « Plaignant ».
- **Critères d'acceptation** :
  - Étant donné un citoyen qui déclare le vol de sa voiture, quand l'agent clique « Enregistrer une plainte » et valide le rapport, alors un rapport « Plainte pour vol de véhicule » existe, lié à la plaque, et la fiche véhicule n'affiche aucun badge « volé ».
  - Étant donné une plaque signalée, quand un script appelle `IsVehicleFlagged('AB123CD')`, alors il reçoit `signale = true` et aucun champ `vole`.
  - Étant donné un script tiers qui appelle `exports['pop_tablet']:ReportStolen(source, plaque)`, quand il l'appelle, alors l'export n'existe pas (erreur « No such export » côté appelant) et aucun véhicule n'est marqué.
  - Étant donné un civil qui envoie `pop_tablet:police:vehicule:flag` à la main, quand le serveur le reçoit, alors il refuse `pas_droit`.

---
## 5. Rapports

### [MET-POL-21] Modèles de rapport réglables
- **But** : fournir des trames de rapport prêtes (arrestation, accident…) que le Patron peut créer et modifier.
- **Qui** : `police.rapport.modeles` (Patron), admin ; réglable.
- **Où** : Police > Rapports > bouton « Modèles » (icône engrenage).
- **Parcours** :
  1. Liste des modèles (nom, nombre de sections, actif oui/non). Boutons « Nouveau modèle », « Modifier », « Désactiver/Activer », flèches haut/bas pour l'ordre.
  2. Éditeur : « Nom », « Type de rapport » (liste fixe : `arrestation`, `incident`, `accident`, `enquete`, `saisie`, `plainte`, `autre`), sections ordonnées : chaque section a un « Titre » et un « Texte d'aide » (gris, affiché dans la zone vide) et un indicateur « Obligatoire ».
  3. « Enregistrer » → `pop_tablet:police:modele:sauver` → serveur valide, enregistre, recharge le cache.
  4. Modèles fournis au premier démarrage (ligne `systeme = 1`, modifiables, jamais supprimables, désactivables) :
     - « Rapport d'arrestation » : Circonstances (obligatoire) · Déroulé de l'interpellation (obligatoire) · Droits notifiés (obligatoire, aide « Heure et agent ayant notifié les droits ») · Fouille et saisies · Déclarations du suspect · Suites données (obligatoire).
     - « Rapport d'incident » : Faits (obligatoire) · Intervenants · Actions menées (obligatoire) · Suites données.
     - « Constat d'accident » : Lieu et heure (obligatoire) · Véhicules impliqués (obligatoire) · Blessés · Déroulé (obligatoire) · Témoignages.
     - « Rapport d'enquête » : Objet (obligatoire) · Éléments recueillis (obligatoire) · Hypothèses · Prochaines étapes.
     - « Procès-verbal de saisie » : Contexte (obligatoire) · Objets saisis (obligatoire) · Lieu de stockage.
     - « Plainte pour vol de véhicule » (type `plainte`, MET-POL-20) : Plaignant (obligatoire) · Date et lieu des faits (obligatoire) · Récit (obligatoire) · Suspects éventuels.
- **Données** (table `rapport_modeles`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| nom | varchar(50) | Oui | unique | — |
| type | enum (7 valeurs) | Oui | — | `autre` |
| sections | JSON | Oui | 1 à 12 sections ; titre 50 car., aide 200 car. | — |
| actif | bool | Oui | — | 1 |
| ordre | int | Oui | — | dernier + 1 |
| systeme | bool | Oui | — | 0 |
- **Règles serveur** : RC1 (service non requis pour Patron et admin), RC2, RC3, RC4. Max `Config.Police.Rapports.MaxModeles = 30` modèles. Modifier un modèle ne change pas les rapports déjà écrits (le rapport garde une copie des titres de sections).
- **Textes et états** : vide (si tout est désactivé) « Aucun modèle actif. Les agents écriront en texte libre. » (`police.modeles.vide`) ; succès « Modèle enregistré. » (`police.modeles.ok`) ; erreur nom pris « Un modèle porte déjà ce nom. » (`police.modeles.nompris`) ; erreur sections « Ajoutez au moins une section. » (`police.modeles.sections`) ; pas le droit : bouton caché.
- **Notifications** : aucune.
- **Liens** : MET-POL-22.
- **Réglages** : `Config.Police.Rapports.MaxModeles = 30`.
- **Journal admin** : oui (avant/après).
- **Performance** : modèles en cache serveur, envoyés avec la liste des rapports à l'ouverture de l'onglet.
- **Cas limites** : désactiver un modèle utilisé par des brouillons → les brouillons restent éditables avec leurs sections ; 13e section → refus ; deux Patrons modifient en même temps → le dernier enregistré gagne, le premier voit au rechargement.
- **Critères d'acceptation** :
  - Étant donné un nouveau modèle « Contrôle stupéfiants » à 3 sections, quand je l'enregistre, alors il apparaît dans la liste « Nouveau rapport » de tous les agents.
  - Étant donné un modèle système, quand je cherche le bouton supprimer, alors seul « Désactiver » existe.
  - Étant donné un Chef qui envoie la sauvegarde d'un modèle à la main, quand le serveur la reçoit, alors il refuse `pas_droit`.

### [MET-POL-22] Rédiger un rapport (liens citoyens, véhicules, agents, preuves) et le transmettre à la justice
- **But** : écrire un rapport structuré, relié aux personnes, véhicules, collègues, preuves et appels, et l'envoyer à la justice.
- **Qui** : créer/modifier son rapport : `police.rapport` (Recrue+) ; modifier le rapport d'un autre : Chef+ ; co-auteurs : agents liés avec le rôle « Co-rédacteur ». En service.
- **Où** : Police > Rapports > « Nouveau rapport » ; fiche citoyen > « Nouveau rapport » ; clôture d'appel (MET-POL-10).
- **Parcours** :
  1. Choix du modèle (liste des modèles actifs + « Texte libre »).
  2. Formulaire : « Titre », « Date et heure des faits » (défaut : maintenant, heure serveur), « Lieu » (texte, bouton « Ma position » qui remplit la rue), sections du modèle (zones de texte), puis 5 blocs de liens :
     - « Citoyens » : recherche (MET-POL-14) → ajout avec un rôle : `suspect`, `victime`, `temoin`, `autre`.
     - « Véhicules » : par plaque → rôle `implique`, `saisi`, `plainte` (véhicule objet d'une plainte, MET-POL-20).
     - « Agents » : liste des agents (en service ou non, recherche par nom/matricule) → rôle `present`, `coredacteur` (affiché « Présent », « Co-rédacteur »).
     - « Preuves » : liste des preuves existantes (MET-POL-36) ou « Créer une preuve » (ouvre MET-POL-36, lien auto).
     - « Appels » : numéro `A-xxxxx`.
     - Plus « Photos » : jusqu'à 10 images de la Galerie (RC5).
  3. « Enregistrer le brouillon » (statut `brouillon`, visible seulement par l'auteur et les co-rédacteurs) ou « Publier » (statut `publie`, visible par tous les agents). Sauvegarde automatique locale du brouillon dans la NUI toutes les 30 s **seulement quand le formulaire est ouvert** (stockage local navigateur, aucun appel serveur).
  4. `pop_tablet:police:rapport:sauver` → serveur valide, attribue le numéro `R-00001`, enregistre `rapports` + `rapport_liens`, ajoute une ligne `historique` sur chaque citoyen et véhicule lié.
  5. Rapport publié : modifiable par l'auteur/co-rédacteurs pendant `Config.Police.Rapports.ModifiableHeures = 24` h ; ensuite verrouillé (seul un Chef+ peut modifier, avec motif obligatoire). Chaque modification garde la version précédente dans la colonne JSON `versions` (20 versions max, la plus ancienne est retirée au-delà).
  6. « Transmettre à la justice » (rapport publié, Membre+) → le serveur crée une affaire dans l'app Justice (MET-JUS) avec copie du rapport, des liens et des preuves ; le rapport affiche « Transmis à la justice le {date} — affaire {numero} ». Une fois transmis, il ne peut plus être modifié (la justice reçoit des compléments via un nouveau rapport lié).
- **Données** (table `rapports`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| numero | varchar(12) | Oui | `R-` + 5 chiffres, unique | auto |
| modele_id | int | Non | — | NULL (texte libre) |
| type | enum (7 valeurs, MET-POL-21) | Oui | — | type du modèle / `autre` |
| titre | varchar(80) | Oui | — | — |
| faits_le | datetime | Oui | ≤ maintenant + 1 h | maintenant |
| lieu | varchar(100) | Non | — | vide |
| x, y | float | Non | position serveur (« Ma position » = ped de l'agent ; rapport créé depuis un appel = coordonnées de l'appel), jamais du client ; sert à la carte des crimes (MET-POL-46) | NULL |
| sections | JSON | Oui | titres copiés du modèle ; chaque texte ≤ 4000 car. ; total ≤ 20 000 car. | — |
| photos | JSON | Non | 10 max, RC5 | `[]` |
| statut | enum `brouillon`/`publie`/`transmis` | Oui | — | `brouillon` |
| auteur | varchar(60) | Oui | — | — |
| affaire_justice | varchar(20) | Non | — | NULL |
| versions | JSON | Non | 20 max | `[]` |
| archive… | RC7 | — | — | 0 |
  Table `rapport_liens` : `rapport_id`, `cible_type` enum `citoyen`/`vehicule`/`agent`/`preuve`/`appel`, `cible_id` varchar(60), `role` varchar(20). Max 30 liens par rapport.
- **Règles serveur** : RC1, RC2, RC3, RC4, RC5. Sections obligatoires vides → refus à la publication (autorisé en brouillon). Chaque lien est vérifié (citoyen existe, preuve existe et non archivée, agent est police). Un agent ne modifie que ses rapports ou ceux où il est co-rédacteur, sauf Chef+.
- **Textes et états** :
  - Succès brouillon « Brouillon enregistré. » (`police.rapports.brouillon`), publication « Rapport {numero} publié. » (`police.rapports.publie`), transmission « Rapport transmis à la justice (affaire {affaire}). » (`police.rapports.transmis`).
  - Erreur section obligatoire : « Remplissez la section « {section} » avant de publier. » (`police.rapports.sectionrequise`).
  - Erreur verrouillé : « Ce rapport est verrouillé. Demandez à un Chef de le modifier. » (`police.rapports.verrouille`).
  - Erreur transmis : « Rapport déjà transmis à la justice : il ne peut plus être modifié. » (`police.rapports.dejatransmis`).
  - Erreur trop de liens : « 30 éléments liés maximum. » (`police.rapports.maxliens`).
  - App Justice désactivée : bouton « Transmettre » caché.
- **Notifications** : agents ajoutés comme co-rédacteurs : « MDT · {nom} vous a ajouté au rapport {numero}. » (`police.notif.coredacteur`) ; justice (agents justice en service) : « Nouvelle affaire transmise par la police : {titre}. » (`justice.notif.nouvelleaffaire`).
- **Liens** : Justice (affaire), Preuves, fiche citoyen, fiche véhicule, Dispatch, Galerie ; signal émis `TriggerEvent('pop_tablet:reportPublished', numero, type)`.
- **Réglages** : `Config.Police.Rapports.ModifiableHeures = 24` ; `Config.Police.Rapports.MaxLiens = 30` ; `Config.Police.Rapports.MaxPhotos = 10`.
- **Journal admin** : oui pour publication, modification après verrouillage (avant/après) et transmission.
- **Performance** : formulaire chargé avec le cache des modèles ; liens chargés par recherche à la demande ; une seule écriture groupée (rapport + liens dans une transaction).
- **Cas limites** : déconnexion pendant la rédaction → brouillon local restauré à la réouverture (« Un brouillon non enregistré a été retrouvé. Le reprendre ? », `police.rapports.restaurer`) ; citoyen lié archivé entre-temps → lien conservé avec mention « (supprimé) » ; double clic sur « Publier » → RC3, un seul numéro.
- **Critères d'acceptation** :
  - Étant donné un rapport d'arrestation avec un suspect et une preuve liés, quand je publie, alors le rapport apparaît dans l'onglet « Rapports » de la fiche du suspect et dans la preuve.
  - Étant donné un rapport publié il y a 25 h, quand son auteur Recrue tente de le modifier, alors il voit « Ce rapport est verrouillé… ».
  - Étant donné un client qui envoie un lien vers une preuve inexistante, quand le serveur le reçoit, alors il refuse tout l'enregistrement.

### [MET-POL-23] Liste, recherche et archivage des rapports
- **But** : retrouver un rapport vite et retirer un rapport erroné sans l'effacer.
- **Qui** : lire : `police.rapport` (Recrue+) ; archiver : l'auteur tant qu'il est brouillon, sinon Patron (`police.casier.retirer` réutilisée : même niveau) ; voir les archivés : Patron, admin.
- **Où** : Police > Rapports.
- **Parcours** :
  1. Liste paginée 20 (plus récent d'abord) : numéro, titre, type, auteur, date des faits, statut, nombre de liens.
  2. Filtres : « Mes rapports », « Brouillons », type, « Du… au… », texte (numéro, titre, nom d'un citoyen lié, plaque liée).
  3. Clic → lecture : en-tête, sections, liens cliquables (fiche citoyen, véhicule, preuve, appel), photos (agrandissables), historique des versions (Chef+).
  4. « Archiver » → motif obligatoire → RC7. Un rapport transmis à la justice ne peut pas être archivé par la police.
- **Données** : tables `rapports`, `rapport_liens`.
- **Règles serveur** : RC1, RC2, RC3, RC4, RC7. Les brouillons des autres ne sont jamais envoyés.
- **Textes et états** : vide « Aucun rapport. Rédigez le premier. » (`police.rapports.vide`) + bouton « Nouveau rapport » ; filtre sans résultat « Aucun rapport ne correspond. » (`police.rapports.filtrevide`) ; succès « Rapport archivé. » (`police.rapports.archive`) ; erreur transmis « Ce rapport est entre les mains de la justice. » (`police.rapports.archivetransmis`).
- **Notifications** : auteur d'un rapport archivé par un Patron : « MDT · Votre rapport {numero} a été archivé. Motif : {motif}. » (`police.notif.rapportarchive`).
- **Liens** : fiche citoyen, fiche véhicule, Preuves, Justice.
- **Réglages** : aucun.
- **Journal admin** : oui (archivage, avec motif).
- **Performance** : requête paginée, index `(statut, faits_le)` et `numero` ; le contenu complet n'est chargé qu'à l'ouverture d'un rapport.
- **Cas limites** : 5 000 rapports → pagination + filtres ; recherche par nom lié → jointure `rapport_liens` + `users`, limitée à 20 ; rapport archivé ouvert depuis un vieux lien → `introuvable`.
- **Critères d'acceptation** :
  - Étant donné 3 rapports liés à la plaque « AB123CD », quand je filtre « AB123CD », alors les 3 apparaissent.
  - Étant donné un rapport archivé, quand un Membre parcourt la liste, alors il n'apparaît pas ; le Patron le voit avec le filtre « Archivés ».
  - Étant donné un Membre qui envoie l'archivage d'un rapport publié d'un autre agent, quand le serveur le reçoit, alors il refuse.

---

## 6. Amendes et casier

### [MET-POL-24] Émettre une amende à un joueur proche
- **But** : verbaliser un joueur à proximité à partir du code pénal ; l'amende devient une facture payable.
- **Qui** : `police.amende` (Recrue+, plafonnée pour la Recrue : `Config.Police.Amendes.PlafondRecrue = 2500` $), en service.
- **Où** : Police > Amendes > « Nouvelle amende » ; fiche citoyen > « Nouvelle amende » (la cible doit quand même être proche).
- **Parcours** :
  1. La NUI demande `pop_tablet:police:proches` → le serveur renvoie les joueurs à ≤ 3 m (RC6) de l'agent, sauf lui : nom RP si `Config.Police.Proches.AfficherNom = true`, sinon « Personne n°{id serveur} ».
  2. L'agent choisit la personne, puis coche une ou plusieurs infractions dans le code pénal (recherche + catégories, MET-POL-32). Le total se calcule (somme des montants, quantité réglable 1–5 par infraction).
  3. Il peut **baisser** le montant (circonstances) mais jamais dépasser le total du barème. Champ « Commentaire » facultatif. Case « Lier à un rapport » (sélecteur).
  4. « Émettre l'amende » → `pop_tablet:police:amende:emettre { cibleRef, infractions[{id, quantite}], montant, commentaire, rapportId, actionId }`.
  5. Serveur : recalcule le total à partir du code pénal en cache (ignore tout total envoyé), vérifie montant ≤ total, ≤ `Config.Police.Amendes.Max = 50000`, ≤ plafond Recrue si Recrue, distance ≤ 3 m, cible ≠ agent. Crée la ligne `amendes` (statut `impayee`), puis crée la facture via l'app Factures (`exports['pop_tablet']:CreateInvoice({ emetteur = job police, cible = identifier, montant, motif = 'Amende {numero}', type = 'amende', refExterne = 'amende:{id}' })`).
  6. La cible reçoit la facture dans son app Factures ; **sans tablette**, une fenêtre simple s'affiche à l'écran : « Amende de {montant} $ — {infractions}. » avec « Payer » et « Refuser » (refuser = reste impayée). Joueur inconscient : la fenêtre attend son réveil (règle Factures).
  7. Signal « facture payée » écouté : le serveur passe l'amende en `payee` avec la date.
  8. Si une infraction a `casier = 1` (délit/crime) dans le code pénal, une entrée de casier est créée automatiquement (MET-POL-26, peine 0, origine `amende`).
- **Données** (table `amendes`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| numero | varchar(12) | Oui | `F-` + 5 chiffres | auto |
| identifier | varchar(60) | Oui | cible | — |
| agent | varchar(60) | Oui | — | — |
| infractions | JSON | Oui | 1 à 10 lignes `{ id, code, libelle, montant, quantite }` (copie figée) | — |
| montant | int | Oui | 1 à `Config.Police.Amendes.Max`, ≤ total barème | total barème |
| commentaire | varchar(300) | Non | — | vide |
| facture_id | int | Oui | lien Factures | — |
| statut | enum `impayee`/`payee`/`annulee` | Oui | — | `impayee` |
| payee_le | datetime | Non | — | NULL |
| rapport_id | int | Non | — | NULL |
- **Règles serveur** : RC1, RC2 (limite propre : 3 amendes / 60 s par agent), RC3, RC4, RC6. Le serveur ne fait jamais confiance au montant ni à la liste de proches envoyés. Même cible, même agent, mêmes infractions dans les 60 s → refus doublon.
- **Textes et états** :
  - Aucun proche : « Personne à moins de 3 m. Rapprochez-vous de la personne. » (`police.amendes.personne`).
  - Succès : « Amende {numero} de {montant} $ envoyée à {nom}. » (`police.amendes.ok`).
  - Erreur montant : « Le montant ne peut pas dépasser le barème ({total} $). » (`police.amendes.depasse`) ; plafond : « Montant maximum pour votre grade : {plafond} $. » (`police.amendes.plafond`).
  - Erreur doublon : « Cette amende vient déjà d'être envoyée. » (`police.amendes.doublon`).
  - Erreur aucune infraction : « Choisissez au moins une infraction. » (`police.amendes.infraction`).
  - Fenêtre sans tablette : titre « Amende de police » (`police.amendes.popup.titre`), boutons « Payer » (`…popup.payer`), « Refuser » (`…popup.refuser`).
- **Notifications** : cible : via Factures (« Nouvelle amende de {montant} $ de la police. », `factures.notif.amende`) ; agent quand elle est payée : « MDT · Amende {numero} payée par {nom}. » (`police.notif.amendepayee`).
- **Liens** : Factures (création, signal « facture payée »), compte de l'entreprise police (géré par Factures, part agent `Config.Police.Amendes.PartAgentPct = 0`), Casier, Rapports, fiche citoyen.
- **Réglages** : `Config.Police.Amendes.Max = 50000` ; `Config.Police.Amendes.PlafondRecrue = 2500` ; `Config.Police.Amendes.PartAgentPct = 0` ; `Config.Police.Proches.AfficherNom = true` ; `Config.Police.Amendes.QuantiteMax = 5`.
- **Journal admin** : oui (cible, infractions, montant, facture).
- **Performance** : liste des proches calculée côté serveur au clic (boucle sur les joueurs connectés une seule fois) ; code pénal en cache.
- **Cas limites** : la cible s'éloigne pendant la saisie → refus `trop_loin` à l'envoi, le formulaire reste rempli ; la cible se déconnecte → `hors_ligne` ; app Factures désactivée par l'admin → l'amende est créée avec statut `impayee` et la fenêtre simple est quand même affichée, le paiement débite l'argent banque (via bridge) et crédite le compte société police.
- **Critères d'acceptation** :
  - Étant donné un joueur à 2 m, quand j'émets une amende « Excès de vitesse » de 250 $, alors il reçoit une facture de 250 $ et l'amende apparaît « Impayée ».
  - Étant donné l'amende payée, quand la facture est réglée, alors l'amende passe « Payée » et je reçois la notification.
  - Étant donné un client qui envoie `montant = 999999` pour une infraction à 250 $, quand le serveur le reçoit, alors il refuse `depasse` et aucune facture n'est créée.

### [MET-POL-25] Suivi des amendes (payées / impayées)
- **But** : suivre l'état de toutes les amendes et repérer les mauvais payeurs.
- **Qui** : voir : `police.amende` (Recrue+) ; annuler une amende impayée : Chef+ (motif obligatoire).
- **Où** : Police > Amendes (liste) ; fiche citoyen > onglet « Amendes ».
- **Parcours** :
  1. Liste paginée 20 : numéro, citoyen, agent, montant, date, statut (« Payée », « Impayée », « Impayée depuis {n} jours » au-delà de `Config.Police.Amendes.DelaiImpayeJours = 7`, « Annulée »).
  2. Filtres : statut, « Mes amendes », « Du… au… », nom du citoyen. Total affiché en bas : « Impayé : {somme} $ ».
  3. « Annuler » (Chef+) → motif → serveur annule l'amende **et** la facture liée (via Factures, statut `annulee`) ; rien n'est supprimé.
  4. Si `Config.Police.Amendes.SignalerImpayees = true` (défaut), un citoyen avec au moins une amende impayée depuis plus de 7 jours reçoit la pastille « Amendes impayées » sur sa fiche et dans les résultats de recherche.
  5. Relance : bouton « Relancer » (une fois par 24 h par amende) → la facture renvoie sa notification au citoyen.
- **Données** : table `amendes`.
- **Règles serveur** : RC1, RC2, RC3, RC4. Annulation d'une amende payée → refus (remboursement = geste manuel du Patron depuis le compte).
- **Textes et états** : vide « Aucune amende émise. » (`police.amendes.vide`) ; succès annulation « Amende {numero} annulée. » (`police.amendes.annulee`) ; relance « Relance envoyée. » (`police.amendes.relance`) ; erreur payée « Une amende payée ne peut pas être annulée. » (`police.amendes.dejapayee`) ; erreur relance « Déjà relancée aujourd'hui. » (`police.amendes.relancedeja`) ; pastille « Amendes impayées » (`police.citoyens.badge.impayes`).
- **Notifications** : relance au citoyen : « Rappel : amende de {montant} $ impayée. » (`factures.notif.relance`) ; annulation au citoyen : « Votre amende {numero} a été annulée. » (`police.notif.amendeannulee`).
- **Liens** : Factures (statut, annulation, relance), fiche citoyen, option « Factures impayées → Police ».
- **Réglages** : `Config.Police.Amendes.DelaiImpayeJours = 7` ; `Config.Police.Amendes.SignalerImpayees = true`.
- **Journal admin** : oui (annulation).
- **Performance** : paginé 20, index `(statut, cree_le)` et `identifier` ; total impayé calculé par une seule requête `SUM`.
- **Cas limites** : facture payée hors ligne (autre script) → le signal « facture payée » met à jour à réception ; citoyen supprimé → ligne gardée « Citoyen supprimé » ; double annulation → RC3.
- **Critères d'acceptation** :
  - Étant donné une amende impayée de 10 jours, quand j'ouvre la liste, alors elle affiche « Impayée depuis 10 jours » et le citoyen a la pastille.
  - Étant donné une amende impayée, quand un Chef l'annule, alors la facture liée disparaît des factures à payer du citoyen.
  - Étant donné une Recrue qui envoie l'annulation à la main, quand le serveur la reçoit, alors il refuse.

### [MET-POL-26] Ajouter au casier (inculpation, peine de prison, signal « peine prononcée »)
- **But** : inscrire une condamnation au casier et déclencher la prison via le signal API.
- **Qui** : `police.casier.ajouter` (Recrue+), en service ; aussi le serveur pour la Justice (verdict) et les amendes délictuelles.
- **Où** : Police > fiche citoyen > « Ajouter au casier » ; Police > Casier > « Nouvelle inscription ».
- **Parcours** :
  1. Formulaire : citoyen (pré-rempli ou recherche), infractions du code pénal (cases + quantité 1–5), totaux calculés : « Amende totale » et « Peine totale (mois) ».
  2. L'agent peut **baisser** l'amende et la peine (pas les monter). Champs : « Circonstances / commentaire », « Lier à un rapport », cases « Émettre l'amende maintenant » (exige la cible à ≤ 3 m, crée la facture comme MET-POL-24) et « Envoyer en prison maintenant » (exige la cible à ≤ `Config.Police.Casier.DistancePrison = 10` m et connectée).
  3. « Inscrire » → `pop_tablet:police:casier:ajouter`.
  4. Serveur : recalcule les totaux depuis le code pénal, vérifie les plafonds (`Config.Police.Casier.PeineMax = 120` mois), enregistre `casier`, ajoute `historique`, marque l'empreinte du citoyen comme fichée (`citoyens.empreinte_fichee = 1`).
  5. Si « Envoyer en prison » est coché et peine > 0 : émet le signal API **« peine prononcée »** :
     - le serveur appelle `exports.pop_tablet:EmitSentence(data)` de la base (BASE-API-08), qui émet `pop_tablet:sentencePronounced` ; `data` au format unique de BASE-API-08 : `{ identifier, source, jailMinutes = peine, fine, communityService = 0, charges = infractions, judge = { identifier, name } de l'agent, caseId = nil }` + champs en plus `origin = 'police'`, `recordId` (id du casier).
     - Le script de prison du serveur fait le reste. L'adaptateur prison est le réglage unique de la base `Config.Signals.SentenceJail` (adaptateurs ouverts dans `bridge/jail/`) ; `'none'` (défaut) = signal seul.
  6. Sans case « Envoyer en prison » : la peine est inscrite « Peine à exécuter » ; un bouton « Envoyer en prison » reste sur l'entrée jusqu'à exécution (même vérifications).
- **Données** (table `casier`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| identifier | varchar(60) | Oui | — | — |
| infractions | JSON | Oui | 1 à 15 lignes, copie figée | — |
| amende | int | Oui | 0 à total barème | total |
| peine_mois | int | Oui | 0 à min(total, `PeineMax`) | total |
| peine_executee | bool | Oui | — | 0 |
| commentaire | varchar(1000) | Non | — | vide |
| origine | enum `police`/`justice`/`amende` | Oui | — | `police` |
| agent | varchar(60) | Oui | (juge si justice) | — |
| rapport_id / amende_id / affaire_justice | int / int / varchar | Non | — | NULL |
| archive… | RC7 | — | — | 0 |
- **Règles serveur** : RC1, RC2 (3 / 60 s), RC3, RC4, RC6 (amende), distance prison 10 m. Le signal « peine prononcée » n'est émis **qu'une fois** par entrée (`peine_executee` passe à 1 dans la même transaction). Totaux du client ignorés.
- **Textes et états** :
  - Succès : « Inscription ajoutée au casier de {nom}. » (`police.casier.ok`) ; avec prison : « {nom} est envoyé en prison pour {mois} {unite}. » (`police.casier.prison`).
  - Erreur peine : « La peine ne peut pas dépasser le barème ({total}). » (`police.casier.depasse`).
  - Erreur prison loin : « La personne doit être à moins de 10 m pour être envoyée en prison. » (`police.casier.prisonloin`).
  - Erreur déjà exécutée : « Cette peine a déjà été exécutée. » (`police.casier.dejaexecutee`).
  - État : « Peine à exécuter » (`police.casier.aexecuter`), « Peine exécutée » (`police.casier.executee`).
- **Notifications** : la cible (notification native, même sans tablette) : « Vous êtes condamné à {mois} {unite} de prison. » (`police.notif.condamne`) — seulement si le script de prison n'affiche rien lui-même (`Config.Police.Prison.NotifierCible = true`).
- **Liens** : Justice (le verdict d'un juge appelle `exports['pop_tablet']:CasierAdd(data)` avec `origine = 'justice'` ; dans ce cas le casier n'émet pas le signal, c'est la Justice qui l'émet une seule fois), Amendes / Factures, Rapports, empreintes (MET-POL-37) ; signal émis `pop_tablet:sentencePronounced`.
- **Réglages** : `Config.Police.Casier.PeineMax = 120` ; `Config.Police.Casier.DistancePrison = 10.0` ; prison : `Config.Signals.SentenceJail` (base) ; `Config.Police.Prison.NotifierCible = true`.
- **Journal admin** : oui (cible, infractions, amende, peine, signal émis).
- **Performance** : une transaction ; code pénal en cache.
- **Cas limites** : cible déconnectée → inscription faite, prison impossible (`hors_ligne`), bouton « Envoyer en prison » reste ; double clic → RC3, un seul signal ; peine 0 → aucun signal.
- **Critères d'acceptation** :
  - Étant donné un suspect à 5 m et « Vol à main armée » (60 mois), quand j'inscris avec « Envoyer en prison », alors le casier montre l'entrée et l'événement `pop_tablet:sentencePronounced` est émis une seule fois avec `mois = 60`.
  - Étant donné une entrée « Peine à exécuter », quand je clique « Envoyer en prison » avec la cible proche, alors le signal part et l'état passe « Peine exécutée ».
  - Étant donné un client qui envoie `peine_mois = 999` pour une infraction à 10 mois, quand le serveur le reçoit, alors il refuse `depasse` et aucun signal n'est émis.

### [MET-POL-27] Historique du casier et retrait (archivage)
- **But** : consulter le casier d'un citoyen et retirer une inscription erronée ou amnistiée sans l'effacer.
- **Qui** : lire : `police.citoyens.lire` (Recrue+) ; retirer : `police.casier.retirer` (Patron) ; voir les retirées : Patron, admin, juges (app Justice).
- **Où** : fiche citoyen > onglet « Casier » ; Police > Casier (liste globale des dernières inscriptions).
- **Parcours** :
  1. Liste chronologique (plus récente d'abord), paginée 20 : date, infractions (codes + libellés), amende, peine, état de la peine, agent ou juge, origine, rapport lié (cliquable).
  2. Résumé en haut : « {n} inscriptions — {mois} mois de prison cumulés — {montant} $ d'amendes ».
  3. « Retirer » (Patron) → fenêtre : « Motif » (liste : `erreur`, `amnistie`, `decision_justice`, `autre` + texte obligatoire si `autre`) → RC7 (archivage). L'entrée disparaît pour les agents ; elle reste visible au Patron/admin/juges avec la mention « Retirée le {date} par {nom} — {motif} ».
  4. Police > Casier : liste globale des 20 dernières inscriptions de la ville, filtres type d'infraction et date.
- **Données** : table `casier` (colonnes RC7).
- **Règles serveur** : RC1, RC2, RC3, RC4, RC7. Un retrait n'annule ni l'amende ni la prison déjà exécutées (aucun signal inverse).
- **Textes et états** : vide « Casier judiciaire vierge. » (`police.fiche.casier.vide`) ; succès « Inscription retirée du casier. » (`police.casier.retiree`) ; motifs « Erreur de saisie » (`police.casier.motif.erreur`), « Amnistie » (`…amnistie`), « Décision de justice » (`…decision_justice`), « Autre » (`…autre`) ; pas le droit : bouton caché.
- **Notifications** : l'agent auteur : « MDT · Une inscription que vous aviez faite pour {nom} a été retirée. » (`police.notif.casierretire`).
- **Liens** : Justice (lecture complète), fiche citoyen.
- **Réglages** : aucun.
- **Journal admin** : oui (entrée complète avant retrait + motif).
- **Performance** : paginé 20, index `(identifier, archive, cree_le)`.
- **Cas limites** : retrait d'une entrée liée à une affaire justice en cours → autorisé mais l'affaire reçoit la note « Inscription retirée par la police » ; double retrait → RC3 ; citoyen supprimé → casier visible par l'admin seulement.
- **Critères d'acceptation** :
  - Étant donné 3 inscriptions, quand j'ouvre l'onglet Casier, alors je vois 3 lignes et le cumul correct.
  - Étant donné une inscription retirée par le Patron, quand un Membre ouvre la fiche, alors elle n'apparaît plus, et l'admin la voit avec le motif.
  - Étant donné un Chef qui envoie le retrait à la main, quand le serveur le reçoit, alors il refuse `pas_droit` et rien ne change.

---
## 7. Mandats et avis de recherche

Table `mandats` (fiches 28 à 30) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| numero | varchar(12) | Oui | `M-` + 5 chiffres | auto |
| type | enum `arret`/`perquisition`/`infiltration` | Oui | `infiltration` : MET-POL-47 | `arret` |
| identifier | varchar(60) | Oui sauf `infiltration` | citoyen visé | — |
| gang_id | int | Oui si `infiltration` | `pop_tablet_companies.id` d'une entreprise de modèle `gang` | NULL |
| adresse | varchar(100) | Oui si perquisition | — | vide |
| motif | varchar(1000) | Oui | — | — |
| infractions | JSON | Non | ids du code pénal, 10 max | `[]` |
| rapport_id | int | Non | — | NULL |
| statut | enum `attente`/`actif`/`refuse`/`leve`/`expire` | Oui | — | `attente` |
| demande_par | varchar(60) | Oui | — | — |
| valide_par / valide_le / valide_role | varchar / datetime / enum `police`/`juge` | Non | — | NULL |
| signature_code / signe_le | varchar(12) / datetime | Non | `SIG-` + 8 caractères, posé seulement quand un juge valide (MET-POL-29) | NULL |
| refus_motif | varchar(300) | Non | — | NULL |
| expire_le | datetime | Oui | validation + `Config.Police.Mandats.DureeJours` | +7 jours |
| leve_par / leve_le / leve_motif | — | Non | — | NULL |

### [MET-POL-28] Créer une demande de mandat
- **But** : demander un mandat d'arrêt ou de perquisition contre un citoyen.
- **Qui** : `police.mandat.creer` (Membre+), en service ; réglable.
- **Où** : Police > Mandats > « Demander un mandat » ; fiche citoyen > « Créer un mandat ».
- **Parcours** :
  1. Formulaire : « Type » (« Mandat d'arrêt » / « Mandat de perquisition » / « Mandat d'infiltration », ce dernier décrit dans MET-POL-47 : gang visé au lieu du citoyen), citoyen (recherche), « Adresse » (perquisition : texte libre, ou liste des propriétés si une source immobilière est déclarée, voir MET-POL-15), « Motif », « Infractions » (code pénal), « Rapport lié ».
  2. `pop_tablet:police:mandat:creer` → serveur enregistre en statut `attente`.
  3. Selon `Config.Police.Mandats.Validation` : `'grade_ou_juge'` (défaut) → la demande attend un Chef+ police ou un juge ; `'juge'` → seulement un juge ; `'grade'` → seulement un Chef+ police ; `'aucune'` → actif tout de suite.
  4. Si le créateur a lui-même `police.mandat.valider` et que `Config.Police.Mandats.AutoValidation = false` (défaut), il ne peut pas valider sa propre demande (quelqu'un d'autre doit le faire).
  5. La demande apparaît dans Police > Mandats > « En attente » et dans l'app Justice > Mandats.
- **Données** : table `mandats`.
- **Règles serveur** : RC1, RC2, RC3, RC4. Un seul mandat d'arrêt `attente` ou `actif` par citoyen (sinon refus en indiquant le numéro existant). Perquisition : max 1 actif par adresse. Infiltration : max 1 `attente` ou `actif` par gang (MET-POL-47).
- **Textes et états** : vide « Aucun mandat. » (`police.mandats.vide`) + bouton « Demander un mandat » (`police.mandats.demander`) ; succès « Demande de mandat {numero} envoyée pour validation. » (`police.mandats.demande`) ; sans validation « Mandat {numero} actif. » (`police.mandats.actif`) ; erreur doublon « Un mandat d'arrêt existe déjà pour ce citoyen ({numero}). » (`police.mandats.doublon`) ; erreur adresse « Indiquez l'adresse à perquisitionner. » (`police.mandats.adresse`).
- **Notifications** : valideurs possibles en service (Chef+ police et juges) : « MDT · Mandat {numero} à valider : {type} contre {nom}. » (`police.notif.mandatavalider`).
- **Liens** : Justice (visible et validable), fiche citoyen (pastille « Mandat » quand actif), Accueil.
- **Réglages** : `Config.Police.Mandats.Validation = 'grade_ou_juge'` ; `Config.Police.Mandats.AutoValidation = false` ; `Config.Police.Mandats.DureeJours = 7`.
- **Journal admin** : oui.
- **Performance** : écriture unique ; cache serveur des mandats actifs (liste courte) invalidé à chaque changement.
- **Cas limites** : citoyen sans propriété connue pour une perquisition → adresse en texte libre ; aucun valideur en service → la demande attend (pas d'expiration en `attente` avant `Config.Police.Mandats.AttenteMaxJours = 3` jours, puis `expire`) ; double clic → RC3.
- **Critères d'acceptation** :
  - Étant donné un Membre, quand il demande un mandat d'arrêt contre John Doe, alors la demande apparaît « En attente » chez les Chefs et dans l'app Justice.
  - Étant donné un mandat d'arrêt actif contre John Doe, quand un autre agent en demande un second, alors il est refusé avec le numéro existant.
  - Étant donné une Recrue qui envoie la création à la main, quand le serveur la reçoit, alors il refuse `pas_droit`.

### [MET-POL-29] Valider ou refuser un mandat (grade ou juge)
- **But** : faire contrôler chaque mandat par un supérieur ou un juge avant qu'il soit exécutable.
- **Qui** : `police.mandat.valider` (Chef+) et/ou juges de l'app Justice selon `Config.Police.Mandats.Validation`.
- **Où** : Police > Mandats > onglet « En attente » > « Valider » / « Refuser » ; Justice > Mandats (même action).
- **Parcours** :
  1. Le valideur ouvre la demande : motif, infractions, rapport lié (lecture), casier du citoyen (résumé).
  2. « Valider » → confirmation → `pop_tablet:police:mandat:valider` → statut `actif`, `valide_par`, `valide_role` (`police` ou `juge`), `expire_le` = maintenant + 7 jours.
  3. « Refuser » → motif obligatoire → statut `refuse`.
  4. Mandat actif : pastille « Mandat » sur la fiche citoyen, compté dans l'Accueil, affiché dans le détail du citoyen avec « Valable jusqu'au {date} ». Perquisition : l'adresse est affichée en gros.
  5. API : `exports['pop_tablet']:HasActiveWarrant(identifier, type)` → `true/false, numero, signe` (utile pour un script de serrures/portes ; `signe = true` si signé par un juge).
  6. **Signature du juge** : quand un juge valide (ici ou dans l'app Justice, MET-JUS-07), le mandat est signé : le serveur pose `signe_le` et `signature_code` = `SIG-` + 8 premiers caractères hexadécimaux en majuscules de `HMAC-SHA256(clé serveur, numero .. identifiant du juge .. signe_le)` (clé aléatoire générée au premier démarrage, gardée dans `pop_tablet_meta`, jamais envoyée au client). Le mandat affiche un bloc « Signé par le juge {nom} le {date} · {code} » ; un mandat validé par un Chef police affiche « Validé par {grade} {nom} » sans signature.
  7. **Types qui exigent un juge** : `Config.Police.Mandats.JugeRequis = { 'perquisition', 'infiltration' }` : pour ces types, seule la validation d'un juge est acceptée, quel que soit `Config.Police.Mandats.Validation` (bouton « Valider » caché pour le Chef police, refus serveur `police.mandats.juge_requis`). Avec `Validation = 'aucune'`, ces types restent en `attente` d'un juge. Exception (`Config.Police.Mandats.SansJugeSiAucunEnService = true` par défaut) : si aucun joueur ayant le grade juge n'est en service au moment de la demande, un Chef police peut valider ; le mandat porte `valide_role = 'chef_sans_juge'` et la mention « Validé sans juge » (`police.mandats.sans_juge`), visible par les juges et l'avocat de l'affaire, et la preuve obtenue reste recevable.
  8. **Recevabilité** : une preuve rattachée à un mandat (MET-POL-36, cadre « Mandat ») n'est recevable que si le mandat est signé par un juge et était `actif` au moment où la preuve a été créée ; sinon la preuve est marquée « Irrecevable » dans l'affaire (MET-JUS-03).
- **Données** : table `mandats` (champs de validation et de signature).
- **Règles serveur** : RC1 (service requis pour la police ; un juge doit avoir le grade juge de l'app Justice), RC2, RC3, RC4. Auto-validation interdite si `AutoValidation = false`. Demande déjà traitée → succès sans effet. Types de `JugeRequis` : validation acceptée seulement si `valide_role = 'juge'`. La signature n'est calculée que côté serveur ; un `signature_code` envoyé par le client est ignoré. Vérification d'une signature : `exports['pop_tablet']:VerifyWarrantSignature(numero, code)` → `true/false` (recalcul HMAC).
- **Textes et états** : « En attente de validation » (`police.mandats.statut.attente`), « Actif » (`…statut.actif`), « Refusé » (`…statut.refuse`), « Levé » (`…statut.leve`), « Expiré » (`…statut.expire`) ; succès « Mandat {numero} validé. » (`police.mandats.valide`), « Mandat {numero} refusé. » (`police.mandats.refuse`) ; erreur auto « Vous ne pouvez pas valider votre propre demande. » (`police.mandats.auto`) ; vide « Aucun mandat en attente. » (`police.mandats.attente.vide`) ; signature « Signé par le juge {nom} le {date} · {code} » (`police.mandats.signe`) ; validé sans signature « Validé par {grade} {nom} » (`police.mandats.valide_par`) ; juge requis « Ce type de mandat doit être signé par un juge. » (`police.mandats.juge_requis`) ; type « Mandat d'infiltration » (`police.mandats.type.infiltration`).
- **Notifications** : demandeur : « MDT · Votre mandat {numero} a été {validé|refusé}. » (`police.notif.mandattraite`) ; tous les agents en service si validé (arrêt) : « MDT · Mandat d'arrêt actif : {nom}. » (`police.notif.mandatactif`).
- **Liens** : Justice (validation par juge, lecture), fiche citoyen, Accueil, API serrures.
- **Réglages** : ceux de MET-POL-28 ; `Config.Police.Mandats.JugeRequis = { 'perquisition', 'infiltration' }`.
- **Journal admin** : oui (validation/refus, rôle du valideur, code de signature).
- **Performance** : cache des mandats actifs ; l'API lit le cache.
- **Cas limites** : un Chef et un juge valident au même moment → le premier gagne, l'autre reçoit succès sans effet ; valideur qui perd son grade avant de cliquer → refus `pas_droit` ; `Validation = 'juge'` et un Chef essaie → bouton caché et refus serveur.
- **Critères d'acceptation** :
  - Étant donné une demande d'un Membre, quand un juge la valide depuis l'app Justice, alors le mandat est « Actif » côté police avec « Validé par juge ».
  - Étant donné un Chef auteur d'une demande, quand il essaie de la valider, alors il voit « Vous ne pouvez pas valider votre propre demande. ».
  - Étant donné un Membre qui envoie la validation à la main, quand le serveur la reçoit, alors il refuse.
  - Étant donné une demande de perquisition, quand un Chef police tente de la valider, alors il voit « Ce type de mandat doit être signé par un juge. » ; quand un juge la valide, alors elle affiche « Signé par le juge {nom} le {date} · SIG-xxxxxxxx ».

### [MET-POL-30] Lever un mandat et expiration
- **But** : clore un mandat exécuté ou devenu inutile, et faire expirer automatiquement les anciens.
- **Qui** : lever : demandeur, `police.mandat.valider` (Chef+) ou juge.
- **Où** : Police > Mandats > mandat actif > « Lever » ; Justice > Mandats.
- **Parcours** :
  1. « Lever » → fenêtre « Motif » (liste : `execute` « Exécuté (personne arrêtée / perquisition faite) », `annule` « Annulé », `erreur` « Erreur ») + commentaire.
  2. Serveur : statut `leve`, champs `leve_*`, invalide le cache.
  3. Expiration : à chaque lecture du cache (ouverture d'onglet, API) et au démarrage du serveur, tout mandat `actif` dont `expire_le` est passé passe `expire` (pas de boucle).
  4. Prolonger (Chef+ ou juge) : bouton « Prolonger de 7 jours » sur un mandat actif, 2 fois maximum (`Config.Police.Mandats.ProlongationsMax = 2`).
- **Données** : table `mandats`.
- **Règles serveur** : RC1, RC2, RC3, RC4. Un mandat levé ou expiré ne peut pas être réactivé (il faut une nouvelle demande).
- **Textes et états** : succès « Mandat {numero} levé. » (`police.mandats.leve`), « Mandat prolongé jusqu'au {date}. » (`police.mandats.prolonge`) ; erreur « Ce mandat n'est plus actif. » (`police.mandats.inactif`) ; erreur prolongation « Prolongation maximale atteinte. » (`police.mandats.prolongmax`).
- **Notifications** : demandeur (si ce n'est pas lui qui lève) : « MDT · Le mandat {numero} a été levé. » (`police.notif.mandatleve`).
- **Liens** : Justice, fiche citoyen, Accueil, API.
- **Réglages** : `Config.Police.Mandats.ProlongationsMax = 2` ; `Config.Police.Mandats.AttenteMaxJours = 3`.
- **Journal admin** : oui.
- **Performance** : expiration calculée paresseusement sur le cache.
- **Cas limites** : redémarrage du serveur pendant 10 jours → au démarrage tous les mandats périmés passent `expire` ; levée simultanée par deux personnes → la première gagne ; Recrue → bouton caché.
- **Critères d'acceptation** :
  - Étant donné un mandat actif, quand le demandeur le lève « Exécuté », alors la pastille « Mandat » disparaît de la fiche citoyen.
  - Étant donné un mandat dont la date est passée, quand j'ouvre l'onglet Mandats, alors il apparaît « Expiré ».
  - Étant donné un mandat levé, quand un client envoie à la main une prolongation, alors le serveur refuse `inactif`.

### [MET-POL-31] Avis de recherche (personnes et véhicules)
- **But** : diffuser à tous les agents un individu ou un véhicule à rechercher (BOLO), même sans identité connue.
- **Qui** : créer et lever : `police.mandat.creer` (Membre+) ; validation : seulement si `Config.Police.Avis.Validation = true` (défaut `false`), alors même règle que MET-POL-29. Visible police et justice.
- **Où** : Police > Mandats > onglet « Avis de recherche » > « Nouvel avis » ; fiche citoyen et fiche véhicule > « Avis de recherche ».
- **Parcours** :
  1. Formulaire : « Cible » : « Citoyen connu » (recherche) / « Inconnu » (description) / « Véhicule » (plaque, modèle, couleur) ; « Motif » ; « Description » (signalement physique, tenue) ; « Dangerosité » (« Faible », « Moyenne », « Élevée — armé ») ; jusqu'à 3 photos (Galerie, RC5) ; « Dernière position connue » (texte + bouton « Ma position »).
  2. `pop_tablet:police:avis:creer` → statut `actif` (ou `attente` si validation activée).
  3. Diffusion : notification à tous les agents en service ; l'avis apparaît en tête de l'onglet et sur l'Accueil. Pour un véhicule, la plaque est aussi marquée « signalée » (MET-POL-20) pendant la durée de l'avis (jamais « volée »).
  4. « Lever » → motif (`retrouve`, `annule`) → statut `leve`. Expiration automatique après `Config.Police.Avis.DureeJours = 3` (même méthode paresseuse que MET-POL-30).
- **Données** (table `avis`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| numero | varchar(12) | Oui | `B-` + 5 chiffres | auto |
| cible_type | enum `citoyen`/`inconnu`/`vehicule` | Oui | — | — |
| identifier / plaque | varchar | Selon type | — | NULL |
| description | varchar(1000) | Oui si `inconnu` | — | vide |
| motif | varchar(300) | Oui | — | — |
| danger | enum `faible`/`moyen`/`eleve` | Oui | — | `moyen` |
| photos | JSON | Non | 3 max | `[]` |
| position | varchar(100) | Non | — | vide |
| statut | enum `attente`/`actif`/`leve`/`expire` | Oui | — | `actif` |
| expire_le | datetime | Oui | — | +3 jours |
| cree_par / leve_par / leve_motif | — | — | — | — |
- **Règles serveur** : RC1, RC2, RC3, RC4, RC5. Max `Config.Police.Avis.MaxActifs = 30` avis actifs (sinon refus « Levez d'anciens avis »).
- **Textes et états** : vide « Aucun avis de recherche. » (`police.avis.vide`) + bouton « Nouvel avis » (`police.avis.nouveau`) ; succès « Avis {numero} diffusé. » (`police.avis.diffuse`), « Avis levé. » (`police.avis.leve`) ; dangerosité « Faible » / « Moyenne » / « Élevée — armé » (`police.avis.danger.*`) ; erreur max « Trop d'avis actifs (30). Levez les anciens. » (`police.avis.max`).
- **Notifications** : agents en service : « MDT · Avis de recherche : {cible} — {motif} » (`police.notif.avis`) ; danger élevé : « MDT · ARMÉ — Avis de recherche : {cible} — {motif} » (`police.notif.avisarme`).
- **Liens** : Justice (lecture), fiche citoyen (pastille « Recherché »), fiche véhicule, Accueil, MET-POL-20, MET-POL-45 (diffusion d'un avis à toute la ville).
- **Réglages** : `Config.Police.Avis.Validation = false` ; `Config.Police.Avis.DureeJours = 3` ; `Config.Police.Avis.MaxActifs = 30`.
- **Journal admin** : oui.
- **Performance** : cache des avis actifs (≤ 30) ; photos chargées à l'ouverture du détail.
- **Cas limites** : avis « inconnu » puis identité trouvée → bouton « Associer à un citoyen » (change `cible_type` en `citoyen`) ; véhicule déjà signalé → l'avis s'ajoute sans retirer le signalement ; levée de l'avis véhicule → retire le marquage « signalé » seulement s'il venait de l'avis.
- **Critères d'acceptation** :
  - Étant donné un avis « Inconnu, sweat rouge, armé », quand je le diffuse, alors tous les agents en service reçoivent « ARMÉ — Avis de recherche… ».
  - Étant donné un avis véhicule sur « AB123CD », quand il est actif, alors la fiche véhicule affiche « SIGNALÉ ».
  - Étant donné une Recrue qui envoie la création à la main, quand le serveur la reçoit, alors il refuse.

---

## 8. Code pénal

Table `codepenal` :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| code | varchar(10) | Oui | unique, ex. `C-01` | — |
| libelle | varchar(80) | Oui | — | — |
| description | varchar(500) | Non | — | vide |
| categorie | enum `contravention`/`delit`/`crime` | Oui | — | `contravention` |
| amende | int | Oui | 0 à `Config.Police.Amendes.Max` | 0 |
| peine_mois | int | Oui | 0 à `Config.Police.Casier.PeineMax` | 0 |
| casier | bool | Oui | inscription automatique au casier | 0 pour contravention, 1 sinon |
| actif | bool | Oui | — | 1 |
| ordre | int | Oui | — | — |

Code fourni au premier démarrage (modifiable) :
| Code | Libellé | Catégorie | Amende ($) | Peine (mois) |
|---|---|---|---|---|
| C-01 | Excès de vitesse | contravention | 250 | 0 |
| C-02 | Grand excès de vitesse (+50 km/h) | contravention | 750 | 0 |
| C-03 | Feu rouge grillé | contravention | 200 | 0 |
| C-04 | Stationnement gênant | contravention | 100 | 0 |
| C-05 | Conduite sans permis | contravention | 1 000 | 0 |
| C-06 | Défaut de casque | contravention | 150 | 0 |
| C-07 | Trouble à l'ordre public | contravention | 300 | 0 |
| C-08 | Insulte à agent | contravention | 500 | 0 |
| D-01 | Refus d'obtempérer | délit | 2 000 | 10 |
| D-02 | Conduite dangereuse | délit | 1 500 | 5 |
| D-03 | Vol simple | délit | 1 500 | 10 |
| D-04 | Vol de véhicule | délit | 3 000 | 15 |
| D-05 | Port d'arme sans permis | délit | 5 000 | 20 |
| D-06 | Possession de stupéfiants | délit | 2 500 | 10 |
| D-07 | Violences volontaires | délit | 3 000 | 15 |
| D-08 | Outrage à agent | délit | 1 000 | 5 |
| D-09 | Délit de fuite | délit | 2 000 | 10 |
| K-01 | Trafic de stupéfiants | crime | 15 000 | 45 |
| K-02 | Vol à main armée | crime | 20 000 | 60 |
| K-03 | Prise d'otage | crime | 25 000 | 80 |
| K-04 | Tentative de meurtre | crime | 30 000 | 90 |
| K-05 | Meurtre | crime | 50 000 | 120 |
| K-06 | Meurtre d'un agent public | crime | 50 000 | 120 |

### [MET-POL-32] Consulter le code pénal
- **But** : trouver rapidement une infraction et son barème (amende, peine).
- **Qui** : tout agent en service (Recrue+) ; aussi lisible par l'app Justice.
- **Où** : Police > Code pénal ; sélecteur d'infractions des amendes, du casier et des mandats.
- **Parcours** :
  1. Liste groupée par catégorie (« Contraventions », « Délits », « Crimes »), triée par `ordre` : code, libellé, amende, peine, icône « casier » si `casier = 1`.
  2. Recherche instantanée côté NUI (la liste entière est reçue une fois, elle est petite).
  3. Clic → description complète.
- **Données** : table `codepenal` (lecture).
- **Règles serveur** : RC1, RC2 lecture. Seules les lignes `actif = 1` sont envoyées aux agents.
- **Textes et états** : vide « Le code pénal est vide. Demandez au Patron de le remplir. » (`police.codepenal.vide`) ; catégories « Contraventions » (`police.codepenal.cat.contravention`), « Délits » (`…cat.delit`), « Crimes » (`…cat.crime`) ; colonne peine « {n} mois » ou « — » (`police.codepenal.peine`).
- **Notifications** : aucune.
- **Liens** : Amendes, Casier, Mandats, Justice.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : cache serveur complet (≤ 300 lignes), envoyé une fois par ouverture de l'app et gardé dans la NUI jusqu'à fermeture ; version incrémentée à chaque modification pour invalider.
- **Cas limites** : 300 infractions → liste repliable par catégorie ; infraction désactivée pendant qu'un agent remplit une amende → refus serveur « Une infraction n'existe plus. Rechargez le code pénal. » (`police.codepenal.perime`) ; recherche sans accent (« peage » trouve « péage ») → comparaison sans accents.
- **Critères d'acceptation** :
  - Étant donné le code par défaut, quand je tape « vol », alors je vois D-03, D-04 et K-02.
  - Étant donné une infraction désactivée, quand j'ouvre le code pénal, alors elle n'apparaît pas.
  - Étant donné un civil qui demande le code pénal au serveur, quand le serveur le reçoit, alors il refuse.

### [MET-POL-33] Modifier le code pénal
- **But** : adapter les infractions, amendes et peines au serveur.
- **Qui** : `police.codepenal.modifier` (Patron), admin ; réglable. Pas besoin d'être en service.
- **Où** : Police > Code pénal > bouton « Modifier » (mode édition) ; Admin > Police > Code pénal (même écran).
- **Parcours** :
  1. Mode édition : chaque ligne devient modifiable ; boutons « Ajouter une infraction », « Désactiver », poignées de tri.
  2. Formulaire d'infraction : code, libellé, description, catégorie, amende, peine, case « Inscrire au casier ».
  3. « Enregistrer » → `pop_tablet:police:codepenal:sauver` (une ligne à la fois) → serveur valide, enregistre, recharge le cache, incrémente la version, envoie `pop_tablet:police:codepenal:maj` aux agents qui ont l'app ouverte.
  4. Bouton « Importer / Exporter » : export JSON (téléchargement depuis la NUI) et import JSON (collage) qui remplace le code entier après confirmation « Remplacer tout le code pénal ? Les anciennes infractions seront désactivées. ».
  5. Une infraction n'est jamais supprimée (désactivée) : amendes, casier et mandats passés gardent leur copie figée.
- **Données** : table `codepenal`.
- **Règles serveur** : RC1 (sans service), RC2, RC3, RC4. Code unique. Montants dans les bornes. Import : JSON validé ligne par ligne, refusé entièrement si une ligne est invalide (message avec le numéro de ligne), max 300 lignes.
- **Textes et états** : succès « Infraction enregistrée. » (`police.codepenal.ok`), « Code pénal importé ({n} infractions). » (`police.codepenal.importe`) ; erreur code pris « Le code {code} existe déjà. » (`police.codepenal.codepris`) ; erreur import « Import refusé : ligne {n} invalide ({champ}). » (`police.codepenal.importerreur`) ; erreur montant « Montant entre 0 et {max} $. » (`police.codepenal.montant`).
- **Notifications** : aucune (la liste se met à jour en direct).
- **Liens** : Amendes, Casier, Mandats, Justice.
- **Réglages** : `Config.Police.CodePenal.MaxLignes = 300` ; `Config.Police.CodePenal.Defaut = true` (insère le code fourni au premier démarrage).
- **Journal admin** : oui (avant/après de chaque ligne ; import complet résumé).
- **Performance** : écriture unitaire, rechargement du cache seulement après écriture.
- **Cas limites** : deux Patrons modifient la même ligne → le dernier gagne ; import de 301 lignes → refus ; amende d'une infraction modifiée pendant une saisie d'amende → le serveur recalcule avec la nouvelle valeur et l'agent voit le nouveau total dans la réponse.
- **Critères d'acceptation** :
  - Étant donné C-01 à 250 $, quand le Patron le passe à 300 $, alors la prochaine amende C-01 vaut 300 $ et les anciennes restent à 250 $.
  - Étant donné un import avec une amende négative à la ligne 4, quand il est envoyé, alors il est refusé avec « ligne 4 invalide ».
  - Étant donné un Chef qui envoie une modification à la main, quand le serveur la reçoit, alors il refuse `pas_droit`.

---

## 9. Vie du service

### [MET-POL-34] Annonces internes (commandement → agents)
- **But** : diffuser des consignes du commandement à tous les agents police.
- **Qui** : publier/archiver : `police.annonce` (Chef+) ; lire : tous les agents police (même hors service, voir 0.4 : l'annonce « Importante » s'affiche aussi sur l'écran hors service).
- **Où** : Police > Annonces ; bandeau Accueil.
- **Parcours** :
  1. « Nouvelle annonce » : « Titre », « Texte », « Importance » (« Normale » / « Importante »), « Épingler » (oui/non), « Visible jusqu'au » (date facultative), « Destinataires » : « Toute la police » (tous les jobs de `Config.Police.Jobs`) ou « Mon entreprise seulement ».
  2. `pop_tablet:police:annonce:publier` → enregistre, envoie la notification.
  3. Liste : épinglées d'abord, puis plus récentes ; pastille « Nouveau » sur les non lues ; ouverture = marquée lue (`annonces_lues`). Compteur de lecture visible par l'auteur et le Patron : « Lu par {n} agents ».
  4. « Archiver » (auteur ou Patron) → RC7.
- **Données** (table `annonces`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| titre | varchar(80) | Oui | — | — |
| texte | text | Oui | 2000 car. | — |
| importante | bool | Oui | — | 0 |
| epinglee | bool | Oui | 5 épinglées max | 0 |
| jusqua | datetime | Non | > maintenant | NULL |
| portee | enum `police`/`entreprise` | Oui | — | `police` |
| job | varchar(30) | Oui | job de l'auteur | — |
| auteur / archive… | — | — | — | — |
  Table `annonces_lues` : `annonce_id`, `identifier`, `lu_le` (clé primaire composée).
- **Règles serveur** : RC1 (publication en service), RC2 (1 annonce / 5 min par auteur), RC3, RC4.
- **Textes et états** : vide « Aucune annonce du commandement. » (`police.annonces.vide`) ; succès « Annonce publiée. » (`police.annonces.ok`) ; erreur épingle « 5 annonces épinglées maximum. Désépinglez-en une. » (`police.annonces.maxepingle`) ; « Lu par {n} agents » (`police.annonces.lus`) ; pastille « Nouveau » (`police.annonces.nouveau`).
- **Notifications** : agents ciblés ayant la tablette sur eux (en service ou non) : normale « MDT · Annonce : {titre} » (`police.notif.annonce`) ; importante « MDT · IMPORTANT : {titre} » (`police.notif.annonceimportante`) ; les agents connectés plus tard voient la pastille à l'ouverture.
- **Liens** : Accueil ; branche Annonces de l'Entreprise (ENT) : les annonces internes police ne vont jamais sur le site ni l'annuaire.
- **Réglages** : `Config.Police.Annonces.MaxEpinglees = 5` ; `Config.Police.Annonces.Frequence = 300` (secondes).
- **Journal admin** : oui (publication, archivage).
- **Performance** : liste paginée 20 ; nombre de non lues calculé par une requête à l'ouverture de l'app.
- **Cas limites** : date « visible jusqu'au » dépassée → annonce cachée (archivée automatiquement à la lecture suivante) ; agent changé d'entreprise → ne voit plus les annonces « Mon entreprise » de l'ancienne ; double publication → RC3.
- **Critères d'acceptation** :
  - Étant donné une annonce importante, quand elle est publiée, alors tous les agents police avec la tablette reçoivent « MDT · IMPORTANT : {titre} », même hors service.
  - Étant donné 10 agents dont 4 ont ouvert l'annonce, quand l'auteur la regarde, alors il voit « Lu par 4 agents ».
  - Étant donné un Membre qui envoie la publication à la main, quand le serveur la reçoit, alors il refuse `pas_droit`.

### [MET-POL-35] Heures de service (par agent et par semaine)
- **But** : voir le temps de service de chaque agent, semaine par semaine.
- **Qui** : ses propres heures : tout agent (Recrue+) ; celles des autres : `police.heures.tous` (Chef+).
- **Où** : Police > Heures.
- **Parcours** :
  1. Vue « Mes heures » : semaine en cours (lundi 00:00 → dimanche 23:59, heure du serveur), total, barre par jour (7 barres simples, couleur d'accent), liste des sessions (début, fin, durée). Flèches « Semaine précédente / suivante », jusqu'à `Config.Police.Heures.SemainesHistorique = 12` semaines en arrière.
  2. Vue « Tous les agents » (Chef+) : tableau des agents de l'entreprise (ou de toute la police pour le Patron et l'admin) : matricule, nom, grade, total de la semaine, nombre de sessions, dernier service. Tri par colonne. Clic → détail de l'agent (même vue que « Mes heures »).
  3. Objectif hebdomadaire : si `Config.Police.Heures.ObjectifHebdo = 0` (défaut, désactivé) ; si > 0 (en heures), les agents sous l'objectif ont le total en gris et la mention « Sous l'objectif ».
  4. Bouton « Copier vers le Tableur » (Chef+, si l'app Tableur est active) : crée une feuille « Heures police — semaine {n} » avec le tableau.
  5. Source des données : sessions de service ENT-GES (table commune des sessions). Une session en cours compte jusqu'à maintenant. Une session à cheval sur deux semaines est coupée à minuit dimanche.
- **Données** (lecture des sessions ENT-GES : `identifier`, `entreprise`, `debut`, `fin`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| semaine | ISO (AAAA-SS) | Oui | 12 semaines en arrière max | semaine en cours |
| total | durée h:min | — | calculé | — |
- **Règles serveur** : RC1, RC2 lecture. Un agent sans `police.heures.tous` qui demande les heures d'un autre → refus. Calcul toujours côté serveur.
- **Textes et états** : vide « Aucun service cette semaine. » (`police.heures.vide`) ; « Semaine du {lundi} au {dimanche} » (`police.heures.semaine`) ; « Total : {h} h {min} » (`police.heures.total`) ; « Sous l'objectif » (`police.heures.sousobjectif`) ; succès copie « Heures copiées dans le Tableur. » (`police.heures.copie`).
- **Notifications** : aucune.
- **Liens** : ENT-GES (sessions de service), Planning (présence), Tableur (copie).
- **Réglages** : `Config.Police.Heures.SemainesHistorique = 12` ; `Config.Police.Heures.ObjectifHebdo = 0`.
- **Journal admin** : non.
- **Performance** : une requête agrégée par semaine (`SUM(TIMESTAMPDIFF)` groupée par identifier), index sessions `(entreprise, debut)` ; résultat des semaines terminées mis en cache 10 min.
- **Cas limites** : session sans fin après un crash serveur → fermée par ENT-GES au redémarrage (heure du dernier enregistrement) ; agent ayant changé d'entreprise police → ses heures restent comptées dans l'ancienne entreprise pour les semaines passées ; 13e semaine demandée → refus, flèche grisée.
- **Critères d'acceptation** :
  - Étant donné 2 sessions de 1 h 30 cette semaine, quand j'ouvre « Mes heures », alors le total affiche « 3 h 00 ».
  - Étant donné une session du dimanche 23:00 au lundi 01:00, quand je regarde les deux semaines, alors chacune compte 1 h.
  - Étant donné une Recrue qui demande les heures d'un collègue à la main, quand le serveur la reçoit, alors il refuse.

---
## 10. Preuves

Table `preuves` (fiches 36 à 38) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| numero | varchar(12) | Oui | `P-` + 5 chiffres, unique | auto |
| type | enum `photo`/`objet`/`empreinte`/`document`/`tablette` | Oui | — | — |
| titre | varchar(80) | Oui | — | — |
| description | varchar(1000) | Non | — | vide |
| images | JSON | Oui si `photo` | 1 à 10, RC5 | `[]` |
| objet | JSON | Oui si `objet` | `{ item, label, quantite, metadata }` | NULL |
| empreinte | char(10) | Oui si `empreinte` | code `EMP-xxxxxx` | NULL |
| lieu | varchar(100) | Non | — | rue de l'agent |
| casier_id | int | Non | casier à preuves (seulement si `Config.Police.EvidenceLocker = true`, MET-POL-38) | NULL |
| statut | enum `enregistree`/`au_casier`/`sortie`/`restituee`/`detruite` | Oui | `au_casier` seulement avec MET-POL-38 | `enregistree` |
| cadre | enum `voie_publique`/`flagrant_delit`/`consentement`/`mandat`/`saisie_tablette`/`infiltration`/`sans_mandat` | Oui | cadre d'obtention déclaré par l'agent | `voie_publique` |
| mandat_id | int | Oui si `mandat` ou `infiltration` | `mandats.id` | NULL |
| recevable | enum `recevable`/`irrecevable`/`contestee` | Oui | calculé par le serveur, changé seulement par un juge (MET-JUS-12) | calculé |
| recevabilite_motif | varchar(300) | Non | — | NULL |
| responsable | varchar(60) | Oui | agent qui a la garde de la preuve | créateur |
| cree_par | varchar(60) | Oui | — | — |
| archive… | RC7 | — | — | 0 |
Table `preuves_journal` (chaîne de possession, jamais modifiée ni supprimée) : `preuve_id`, `action` (`creation`, `consultation`, `lien_rapport`, `transfert`, `transmission_justice`, `contestation`, `decision_juge`, `restitution`, `destruction`, et avec MET-POL-38 : `depot`, `sortie`, `consultation_casier`), `agent` (identifiant de la personne, policier ou magistrat ou avocat), `role` (`police`/`procureur`/`juge`/`avocat`/`admin`), `commentaire`, `cree_le`. Une preuve est liée à un ou plusieurs rapports via `rapport_liens` (MET-POL-22).

### [MET-POL-36] Créer une preuve (photo, objet saisi, document) et la lier à un rapport
- **But** : enregistrer une pièce à conviction numérotée et la rattacher à un rapport.
- **Qui** : `police.preuves` (Recrue+), en service.
- **Où** : Police > Preuves > « Nouvelle preuve » ; Rapport > bloc Preuves > « Créer une preuve ».
- **Parcours** :
  1. Choix du type :
     - « Photo » : sélection de 1 à 10 photos dans la Galerie de l'agent (photos prises avec l'appareil photo de la tablette ou importées) ; RC5.
     - « Objet saisi » : (avec ox_inventory ou qs-inventory) liste des objets de l'inventaire **de l'agent** (l'agent a d'abord pris l'objet sur le suspect par la fouille de son serveur) → choix de l'objet et de la quantité. Le serveur retire l'objet de l'inventaire de l'agent et le garde dans la preuve (dans le stash du casier physique seulement si MET-POL-38 est activé) ; sans inventaire compatible : saisie texte « Nom de l'objet » + « Quantité » (aucun objet retiré).
     - « Document » : texte libre (ex. lettre retrouvée) 1000 car. + photos facultatives.
     - « Empreinte » : créée seulement par MET-POL-37.
     - « Tablette » : créée seulement par MET-POL-44.
  2. Champs communs : « Titre », « Description », « Lieu » (défaut : rue actuelle), « Lier à un rapport » (sélecteur ; si ouvert depuis un rapport, lien automatique), « Cadre d'obtention » (obligatoire) : « Voie publique », « Flagrant délit », « Consentement de la personne », « Mandat » (choix d'un mandat actif dans la liste), « Sans mandat ». Les cadres « Saisie de tablette » et « Infiltration » sont posés seulement par MET-POL-44 et MET-POL-47.
  3. `pop_tablet:police:preuve:creer` → serveur valide, attribue `P-00001`, calcule la recevabilité (étape 6), enregistre, écrit `preuves_journal` (`creation`), lie au rapport.
  4. Fiche preuve : numéro en gros, type, titre, images (agrandissables), objet, statut, cadre, pastille de recevabilité (« Recevable » / « Irrecevable : {motif} » / « Contestée »), agent responsable, rapports liés (cliquables), onglet « Chaîne de possession ».
  5. « Lier à un autre rapport » disponible sur la fiche (max 10 rapports par preuve).
  6. **Recevabilité** (calcul serveur à la création, jamais par le client) : `voie_publique`, `flagrant_delit`, `consentement`, `saisie_tablette` → `recevable` ; `mandat` → `recevable` seulement si le mandat est signé par un juge (`signature_code` non vide, MET-POL-29), était `actif` à l'heure de création de la preuve et vise la même personne (arrêt) ou la même adresse (perquisition), sinon `irrecevable` avec le motif « Mandat absent, non signé ou expiré » ; `infiltration` → `recevable` seulement si le message est postérieur à la signature et antérieur à la fin du mandat (MET-POL-47) ; `sans_mandat` → `irrecevable` avec le motif « Obtenue sans mandat ». La pastille suit la preuve dans l'affaire (MET-JUS-03). Seul un juge peut changer la recevabilité, après contestation (MET-JUS-12).
  7. **Chaîne de possession** : chaque ouverture de la fiche par quiconque (agent, procureur, juge, avocat) écrit `consultation` (une ligne au plus par personne et par preuve toutes les 10 min) ; « Transférer la garde » (responsable actuel ou Chef+) → choix d'un agent en service → `responsable` changé, ligne `transfert` (« de {agent A} à {agent B} ») ; transmission à la justice (MET-POL-22) → `transmission_justice` ; restitution et destruction (Chef+, motif obligatoire) → `restitution` / `destruction`. L'onglet affiche toutes les lignes, plus récente d'abord, 20 par page : date, personne, rôle, action, commentaire.
- **Données** : tables `preuves`, `preuves_journal`, `rapport_liens`.
- **Règles serveur** : RC1, RC2, RC3, RC4, RC5. Objet saisi : le serveur vérifie que l'agent possède l'objet et la quantité (`Bridge.HasItem` / `exports.ox_inventory:GetItemCount`), le retire de l'inventaire de l'agent et l'enregistre dans la preuve (`objet` JSON avec métadonnées) en une opération ; si le casier physique est activé (`Config.Police.EvidenceLocker = true`, MET-POL-38), l'objet est placé dans le stash ; sinon il n'existe plus que dans la preuve et « Restituer » le rend par `Bridge.AddItem` au propriétaire proche (≤ 3 m) ; échec → aucune preuve créée. Cadre `mandat` sans `mandat_id` → `champ_requis` ; cadres `saisie_tablette` et `infiltration` refusés s'ils viennent de cette action (`invalide`). `preuves_journal` : écriture seule, aucune mise à jour ni suppression ; les lignes `consultation` passent par la file d'écriture groupée (BASE-MOT-04). Objets interdits à la saisie : `Config.Police.Preuves.ObjetsExclus = { 'pop_tablet', 'money' }` (l'argent liquide passe par l'item `money` : utiliser « Document » avec le montant ; la tablette passe par MET-POL-44).
- **Textes et états** : vide « Aucune preuve enregistrée. » (`police.preuves.vide`) + bouton « Nouvelle preuve » (`police.preuves.nouvelle`) ; succès « Preuve {numero} enregistrée. » (`police.preuves.ok`) ; cadres « Voie publique » (`police.preuves.cadre.voie_publique`), « Flagrant délit » (`…cadre.flagrant_delit`), « Consentement de la personne » (`…cadre.consentement`), « Mandat » (`…cadre.mandat`), « Saisie de tablette » (`…cadre.saisie_tablette`), « Infiltration » (`…cadre.infiltration`), « Sans mandat » (`…cadre.sans_mandat`) ; pastilles « Recevable » (`police.preuves.recevable`), « Irrecevable : {motif} » (`police.preuves.irrecevable`), « Contestée » (`police.preuves.contestee`) ; avertissement à la création sans mandat « Cette preuve sera marquée irrecevable : elle a été obtenue sans mandat. » (`police.preuves.avertissement_sans_mandat`) ; transfert « Garde transférée à {agent}. » (`police.preuves.transfert_ok`) ; chaîne vide impossible (au moins la création) ; onglet « Chaîne de possession » (`police.preuves.chaine`) ; erreur objet « Vous n'avez pas cet objet sur vous. » (`police.preuves.pasobjet`) ; erreur exclus « Cet objet ne peut pas être mis sous scellé ici. » (`police.preuves.exclu`) ; erreur photo « Choisissez au moins une photo. » (`police.preuves.photo`).
- **Notifications** : aucune.
- **Liens** : Galerie (lecture), inventaire (bridge), Rapports, Justice (les preuves des rapports transmis sont copiées dans l'affaire en lecture).
- **Réglages** : `Config.Police.Preuves.ObjetsExclus = { 'pop_tablet', 'money' }` ; `Config.Police.Preuves.MaxImages = 10` ; `Config.Police.Preuves.ConsultationEcartMin = 10` ; `Config.Police.EvidenceLocker = false` (MET-POL-38).
- **Journal admin** : oui (création d'une preuve objet : item, quantité ; preuve créée « Sans mandat » ; transfert de garde ; restitution ; destruction).
- **Performance** : écriture unique ; liste paginée 20 ; images chargées à l'ouverture de la fiche.
- **Cas limites** : l'agent jette l'objet entre le choix et l'envoi → refus `pasobjet` ; inventaire non compatible → mode texte ; photo de la Galerie supprimée ensuite → la preuve garde sa copie (la Galerie copie l'image dans le dossier « Preuves » protégé contre la suppression).
- **Critères d'acceptation** :
  - Étant donné un pistolet dans mon inventaire, quand je crée la preuve « Objet saisi » avec lui, alors il quitte mon inventaire et la preuve P-xxxxx indique « Pistolet ×1 ».
  - Étant donné une preuve créée depuis un rapport, quand j'ouvre ce rapport, alors la preuve est dans son bloc Preuves.
  - Étant donné un client qui déclare saisir 5 objets qu'il ne possède pas, quand le serveur le reçoit, alors il refuse et rien n'est créé.
  - Étant donné une preuve créée avec le cadre « Sans mandat », quand le procureur la lie à une affaire, alors elle y apparaît « Irrecevable : Obtenue sans mandat ».
  - Étant donné une preuve consultée par un procureur puis transférée d'un agent à un autre, quand on ouvre « Chaîne de possession », alors on voit la création, la consultation et le transfert avec les noms, rôles et heures.
  - Étant donné un client qui envoie `recevable = 'recevable'` avec une preuve « Sans mandat », quand le serveur la crée, alors il ignore ce champ et la marque irrecevable.

### [MET-POL-37] Relevé d'empreintes
- **But** : relever l'empreinte d'une personne proche et l'identifier si elle est déjà fichée.
- **Qui** : `police.preuves` (Recrue+), en service.
- **Où** : Police > Preuves > « Relever une empreinte ».
- **Parcours** :
  1. Liste des joueurs à ≤ 3 m (RC6), affichés « Personne n°{id serveur} » (jamais le nom : c'est le but du relevé).
  2. Clic → animation de l'agent 3 s (`anim@heists@prison_heiststation@cop_reactions` `cop_b_idle`), barre de progression dans la NUI ; annulation si l'agent bouge de plus de 1 m.
  3. `pop_tablet:police:empreinte:relever` → serveur revérifie la distance, lit le code d'empreinte du citoyen : `citoyens.empreinte` (créé à la première demande : `EMP-` + 6 premiers caractères hexadécimaux de `sha256(identifier .. Config.Police.Empreintes.Sel)`, en majuscules ; en cas de collision, on prend les 6 suivants).
  4. Résultat : si `empreinte_fichee = 1` → « Correspondance : {nom} » avec lien vers la fiche ; sinon → « Empreinte inconnue au fichier » et le code. Dans les deux cas une preuve type `empreinte` est créée (MET-POL-36) avec le code.
  5. Case « Ficher cette empreinte » (Membre+) : met `empreinte_fichee = 1` → la personne sera reconnue aux prochains relevés et trouvable en recherche par code. Inscription au casier fiche aussi l'empreinte automatiquement (MET-POL-26).
- **Données** : `citoyens.empreinte`, `citoyens.empreinte_fichee`, preuve type `empreinte`.
- **Règles serveur** : RC1, RC2 (limite propre : 1 relevé / 10 s), RC3, RC6. Le code d'empreinte n'est jamais calculable par le client (sel serveur `Config.Police.Empreintes.Sel`, généré aléatoirement au premier démarrage et stocké en base si laissé vide).
- **Textes et états** : aucun proche « Personne à moins de 3 m. » (`police.empreintes.personne`) ; en cours « Relevé en cours… » (`police.empreintes.encours`) ; annulé « Relevé annulé : ne bougez pas pendant le relevé. » (`police.empreintes.annule`) ; résultats « Correspondance : {nom} » (`police.empreintes.match`), « Empreinte inconnue au fichier » (`police.empreintes.inconnue`) ; fichée « Empreinte fichée. » (`police.empreintes.fichee`).
- **Notifications** : la personne relevée (notification native) : « La police relève vos empreintes. » (`police.notif.empreinte`).
- **Liens** : fiche citoyen (code affiché si fichée), recherche citoyen par code, Preuves, Casier.
- **Réglages** : `Config.Police.Empreintes.Sel = ''` (vide = généré) ; `Config.Police.Empreintes.DureeSec = 3`.
- **Journal admin** : oui (relevé, fichage).
- **Performance** : animation et barre locales 3 s, une seule vérification de mouvement à la fin (position de départ comparée à celle de fin), aucun thread permanent.
- **Cas limites** : la cible s'éloigne pendant les 3 s → refus `trop_loin` à l'envoi ; deux personnages du même joueur (multi-personnages) → identifiers différents donc empreintes différentes ; la cible est un agent → autorisé.
- **Critères d'acceptation** :
  - Étant donné un suspect déjà inscrit au casier, quand je relève son empreinte, alors je vois « Correspondance : {nom} ».
  - Étant donné une personne jamais fichée, quand je relève puis coche « Ficher », alors un relevé suivant affiche son nom.
  - Étant donné un client qui envoie un relevé sur un joueur à 50 m, quand le serveur le reçoit, alors il refuse `trop_loin`.

### [MET-POL-38] Casier à preuves numéroté (stockage physique, optionnel, désactivé par défaut)
- **But** : en option, ranger les objets saisis dans des casiers numérotés à un point physique du commissariat (coffre dans le monde). **Désactivé par défaut** (`Config.Police.EvidenceLocker = false`) : tout se passe alors dans la tablette (MET-POL-36 garde l'objet dans la preuve et trace la chaîne de possession) et aucun point, stash ni interaction n'est créé dans le monde.
- **Activation** : `Config.Police.EvidenceLocker = true` **et** ox_inventory démarré ; sinon l'onglet « Casiers » est caché, les actions `pop_tablet:police:casier:*` sont refusées `invalide` et aucune zone n'est enregistrée au démarrage.
- **Qui** : déposer : `police.preuves` (Recrue+) ; ouvrir un casier, sortir/restituer/détruire une preuve : `police.preuves.gerer` (Chef+). En service.
- **Où** : Police > Preuves > onglet « Casiers » ; point physique « Salle des preuves » (`Config.Police.Preuves.Points`) avec ox_target/qb-target ou touche E dans un rayon de 1,5 m.
- **Parcours** :
  1. Les casiers sont créés à la demande : « Nouveau casier » attribue `C-0001` (lié à une affaire : rapport principal facultatif, titre). Un casier contient de 1 à N preuves.
  2. Création d'une preuve « Objet » : l'objet va directement dans le stash `pop_preuve_{numero de casier}` (ox_inventory `RegisterStash`, 50 emplacements, 200 kg, enregistré au démarrage pour les casiers existants et à la création pour les nouveaux). Sans casier choisi, le serveur crée un casier automatique pour la preuve.
  3. Déposer une preuve existante dans un casier : « Ranger dans un casier » → choix du casier → statut `au_casier`, journal `depot`.
  4. Au point « Salle des preuves » : l'agent Chef+ ouvre la liste des casiers (NUI de la tablette ou menu ox_lib si présent) puis le stash (`exports.ox_inventory:forceOpenInventory(source, 'stash', id)`) ; chaque ouverture écrit `consultation_casier` dans le journal de toutes les preuves de ce casier. Sans inventaire compatible : pas de stash, le casier n'est qu'un registre.
  5. « Sortir la preuve » (Chef+) : motif obligatoire → statut `sortie` ; « Restituer » → statut `restituee` (l'objet est donné au propriétaire proche, ou reste dans le stash si absent) ; « Détruire » → statut `detruite`, l'objet est supprimé du stash.
  6. Ouvrir un casier hors du point physique est impossible (le serveur vérifie la distance au point ≤ 2 m).
- **Données** (table `preuves_casiers`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| numero | varchar(8) | Oui | `C-` + 4 chiffres | auto |
| titre | varchar(80) | Oui | — | « Casier {numero} » |
| rapport_id | int | Non | — | NULL |
| stash_id | varchar(40) | Non | `pop_preuve_C-0001` | auto si inventaire compatible |
| archive… | RC7 | — | — | 0 |
- **Règles serveur** : RC1, RC2, RC3, RC4 ; distance au point de la salle des preuves ≤ 2 m pour ouvrir le stash ; destruction et restitution journalisées ; un casier n'est archivable que si toutes ses preuves sont `restituee` ou `detruite`.
- **Textes et états** : vide « Aucun casier à preuves. » (`police.casiers.vide`) ; succès « Preuve rangée dans le casier {numero}. » (`police.casiers.range`), « Preuve sortie. » (`…sortie`), « Preuve restituée. » (`…restituee`), « Preuve détruite. » (`…detruite`) ; erreur loin « Allez à la salle des preuves pour ouvrir ce casier. » (`police.casiers.loin`) ; erreur archive « Le casier contient encore des preuves. » (`police.casiers.nonvide`) ; marqueur point : « Salle des preuves » (`police.casiers.point`).
- **Notifications** : aucune.
- **Liens** : inventaire (bridge), Preuves, Rapports, Justice (la chaîne de garde est visible dans l'affaire).
- **Réglages** : `Config.Police.EvidenceLocker = false` (interrupteur général de cette fiche) ; `Config.Police.Preuves.Points = { { coords = vec3(474.6, -996.3, 26.3), label = 'Salle des preuves' } }` (coordonnées du commissariat Mission Row MLO de base, à adapter) ; `Config.Police.Preuves.Stash = { emplacements = 50, poids = 200000 }` ; `Config.Police.Preuves.Interaction = 'auto'` (`'ox_target'`, `'qb-target'`, `'touche'`, ou `'auto'` = détecte).
- **Journal admin** : oui (sortie, restitution, destruction, ouverture de stash).
- **Performance** : interaction par ox_target/qb-target (zéro boucle) ; en mode `'touche'`, une `lib.points`/zone d'ox_lib si présent, sinon un thread de proximité **démarré seulement quand l'agent en service est à moins de 30 m** du point (détection via un seul point de déclenchement `PolyZone`/`lib.zones`, arrêté en sortant) ; les stashs sont enregistrés une fois.
- **Cas limites** : `EvidenceLocker = false` (défaut) → onglet caché, aucune zone, aucun thread, aucune erreur ; activation après coup → les preuves existantes restent sans casier et peuvent être rangées ; stash plein → dépôt refusé « Casier plein, créez-en un autre. » (`police.casiers.plein`) ; ox_inventory absent → registre seul, bouton « Ouvrir » caché ; agent qui prend un objet dans le stash sans passer par « Sortir » → ox_inventory hook `swapItems` journalise le retrait comme `sortie` avec l'agent.
- **Critères d'acceptation** :
  - Étant donné une preuve objet, quand un Chef ouvre le casier C-0001 à la salle des preuves, alors l'objet est dans le stash et la consultation est inscrite dans la chaîne de garde.
  - Étant donné un Chef à 40 m de la salle, quand il clique « Ouvrir », alors il voit « Allez à la salle des preuves pour ouvrir ce casier. ».
  - Étant donné une Recrue qui envoie à la main l'ouverture d'un stash de preuves, quand le serveur la reçoit, alors il refuse et rien ne s'ouvre.
  - Étant donné la configuration par défaut (`EvidenceLocker = false`), quand la ressource démarre, alors aucun point « Salle des preuves » n'existe dans le monde et l'onglet « Casiers » n'apparaît pas.

---

## 11. Caméras

### [MET-POL-39] Placer et gérer les caméras fixes (CCTV)
- **But** : permettre à l'admin d'installer des caméras de surveillance aux endroits voulus.
- **Qui** : admin serveur (ACE `pop.tablet.admin`) ; le Patron police peut seulement activer/désactiver une caméra (`police.cameras` + Patron).
- **Où** : placement et réglages = Admin > Caméras (fiches `ADM-12` / `ADM-13` du fichier 05, même écran, même table) ; commande `/tablette_camera` (admin) qui ouvre directement l'écran de placement de `ADM-12`. Cette fiche ajoute le côté police : liste dans Police > Caméras, aperçu, désactivation par le Patron, API pour les scripts et caméras fournies.
- **Parcours** :
  1. « Placer une caméra ici » : la tablette se ferme, l'admin passe en vue libre (caméra scriptée déplaçable : ZQSD/WASD pour bouger, souris pour orienter, molette pour le FOV, `Entrée` pour valider, `Échap` pour annuler). Aide affichée en bas : « Déplacez la vue, Entrée pour valider, Échap pour annuler » (`police.cameras.aide.placement`).
  2. À la validation : fenêtre « Nom » (ex. « Fleeca Legion — entrée »), « Groupe » (zone, ex. « Banques »), « Rotation autorisée » (gauche/droite en degrés, 0 à 90, défaut 45), « Vision de nuit autorisée » (oui/non).
  3. `pop_tablet:police:camera:creer { coords, rotation, fov, ... }` → serveur enregistre, met à jour le cache.
  4. Liste : nom, groupe, statut (« En ligne » / « Hors ligne »), boutons « Aperçu », « Modifier », « Désactiver », « Archiver ».
  5. API : `exports['pop_tablet']:SetCameraOnline(id, bool)` pour qu'un script de braquage coupe une caméra (ex. câbles coupés) ; `exports['pop_tablet']:AddCamera(data)` pour créer des caméras depuis un autre script.
  6. Caméras fournies au premier démarrage si `Config.Police.Cameras.Defaut = true` : 6 caméras (Fleeca Legion, Fleeca Route 68, Pacific Standard entrée, bijouterie Vangelico, supérette Strawberry, commissariat Mission Row entrée).
- **Données** (table commune `pop_tablet_cameras` du fichier 05 ; correspondance : nom = `name`, groupe = `zone`, rotation_max = `max_rotation`, vision_nuit = `night_vision`, en_ligne = `online`, archivage = `active = 0`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| nom | varchar(60) | Oui | unique | — |
| groupe | varchar(40) | Oui | — | « Général » |
| x, y, z | float | Oui | dans la carte | — |
| rot_x, rot_z | float | Oui | rot_x −89 à 89 | — |
| fov | float | Oui | 20 à 90 | 60 |
| rotation_max | int | Oui | 0 à 90 | 45 |
| vision_nuit | bool | Oui | — | 1 |
| en_ligne | bool | Oui | — | 1 |
| archive… | RC7 | — | — | 0 |
- **Règles serveur** : RC1 (admin ; Patron pour activer/désactiver), RC2, RC3, RC4. Max `Config.Police.Cameras.Max = 100`.
- **Textes et états** : vide « Aucune caméra installée. » (`police.cameras.vide`) + bouton « Placer une caméra ici » (`police.cameras.placer`) ; succès « Caméra « {nom} » installée. » (`police.cameras.ok`) ; statut « En ligne » / « Hors ligne » (`police.cameras.enligne` / `.horsligne`) ; erreur max « 100 caméras maximum. » (`police.cameras.max`).
- **Notifications** : aucune.
- **Liens** : MET-POL-40 ; API scripts de braquage.
- **Réglages** : `Config.Police.Cameras.Max = 100` ; `Config.Police.Cameras.Defaut = true`.
- **Journal admin** : oui.
- **Performance** : caméra libre active seulement pendant le placement (un thread pour lire les touches, arrêté à la validation/annulation) ; cache serveur des caméras.
- **Cas limites** : admin qui meurt pendant le placement → placement annulé ; nom en double → refus ; caméra archivée → disparaît de la liste des agents immédiatement.
- **Critères d'acceptation** :
  - Étant donné un admin devant la Fleeca, quand il place une caméra et valide, alors elle apparaît dans Police > Caméras pour les Chefs.
  - Étant donné un script de braquage qui appelle `SetCameraOnline(3, false)`, quand un agent regarde la caméra 3, alors il voit « Signal perdu ».
  - Étant donné un Patron non admin qui envoie la création d'une caméra à la main, quand le serveur la reçoit, alors il refuse.

### [MET-POL-40] Vue en direct des caméras fixes
- **But** : regarder en direct une caméra de surveillance depuis la tablette.
- **Qui** : `police.cameras` (Chef+), en service ; réglable.
- **Où** : Police > Caméras.
- **Parcours** :
  1. Liste par groupe : nom, statut. Clic sur une caméra en ligne → « Voir ».
  2. Client : la NUI de la tablette passe en mode plein écran transparent ; `SetFocusPosAndVel(x, y, z, 0, 0, 0)` pour charger la zone, création d'une caméra scriptée (`CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', ...)`), `RenderScriptCams(true, false, 0)`, filtre `SetTimecycleModifier('CAMERA_secuirity')` (force 0.6), ped du joueur gelé (`FreezeEntityPosition`) et commandes bloquées.
  3. Superposition sobre : nom de la caméra, groupe, date et heure du serveur, « REC » blanc, aide « ←/→ caméra précédente/suivante · souris : tourner · molette : zoom · N : vision de nuit · Échap : quitter » (`police.cameras.aide.vue`).
  4. Commandes : souris → rotation limitée à ± `rotation_max` autour de l'angle d'origine ; molette → FOV entre 20 et la valeur d'origine ; N → `SetNightvision` si autorisé ; flèches → caméra suivante du même groupe.
  5. Échap → `RenderScriptCams(false)`, `ClearFocus()`, `ClearTimecycleModifier()`, dégel du ped, retour à la liste.
  6. Sortie forcée si le joueur subit des dégâts, meurt, quitte le service ou si la caméra passe hors ligne (« Signal perdu » 2 s puis retour).
  7. Limite du jeu : les autres joueurs ne sont visibles que s'ils sont dans la zone de diffusion réseau du spectateur (environ 400 m de sa position). Une mention discrète l'indique sous l'image si la caméra est à plus de `Config.Police.Cameras.AlerteDistance = 400` m : « Personnes éloignées possiblement invisibles. » (`police.cameras.portee`).
- **Données** : cache des caméras (lecture).
- **Règles serveur** : RC1, RC2 (1 ouverture / 2 s). Le serveur renvoie les coordonnées de la caméra seulement si elle est en ligne et non archivée ; chaque ouverture est journalisée.
- **Textes et états** : vide « Aucune caméra installée. Demandez à un admin. » (`police.cameras.vide.agent`) ; hors ligne « Signal perdu » (`police.cameras.signalperdu`) ; pas le droit : onglet caché.
- **Notifications** : aucune.
- **Liens** : MET-POL-39 (API en ligne/hors ligne).
- **Réglages** : `Config.Police.Cameras.Filtre = 'CAMERA_secuirity'` ; `Config.Police.Cameras.FiltreForce = 0.6` ; `Config.Police.Cameras.AlerteDistance = 400`.
- **Journal admin** : oui (qui a regardé quelle caméra, durée).
- **Performance** : un thread client actif **seulement pendant la vue** (lecture souris/touches, `DisableAllControlActions`), arrêté à la sortie ; rien ensuite.
- **Cas limites** : ped attaqué pendant la vue → sortie immédiate ; tablette retirée de l'inventaire pendant la vue → sortie ; déconnexion pendant la vue → rien à nettoyer côté serveur.
- **Critères d'acceptation** :
  - Étant donné un Chef en service, quand il ouvre la caméra « Fleeca Legion », alors il voit l'image en direct avec le nom et l'heure et peut tourner de ± 45°.
  - Étant donné un agent en vue caméra, quand il reçoit une balle, alors la vue se ferme et il retrouve le contrôle.
  - Étant donné une Recrue qui demande à la main les coordonnées d'une caméra, quand le serveur la reçoit, alors il refuse.

### [MET-POL-41] Caméra piéton (voir ce que voit un agent en service)
- **But** : suivre en direct le point de vue d'un agent en intervention, dans un rayon limité.
- **Qui** : `police.camerapieton` (Chef+), en service ; réglable. Cible : tout agent en service si `Config.Police.BodyCam.Active = true`.
- **Où** : Police > Effectifs > panneau agent > « Voir sa caméra piéton » ; Police > Caméras > onglet « Caméras piéton » (liste des agents en service dans le rayon).
- **Parcours** :
  1. L'onglet liste les agents en service avec leur distance (calculée par le serveur) ; ceux au-delà de `Config.Police.BodyCam.Rayon = 300` m sont grisés « Hors de portée ».
  2. « Voir » → `pop_tablet:police:bodycam:ouvrir { agentRef }` → serveur vérifie droit, service des deux, distance ≤ rayon, renvoie le **NetID** du ped de la cible.
  3. Client : `NetToPed(netId)` ; si l'entité n'existe pas localement → « Hors de portée ». Sinon caméra scriptée attachée à la tête de la cible (`AttachCamToPedBone(cam, ped, 31086, 0.0, 0.15, 0.05, true)` → vue légèrement devant le visage), rotation recopiée à chaque image depuis `GetEntityRotation(ped)` (la caméra de jeu d'un autre joueur n'est pas lisible à distance : on suit l'orientation de son corps), FOV 70, filtre léger `'scanline_cam_cheap'` force 0.3, superposition « BODYCAM {matricule} — {date heure} ».
  4. Le ped du spectateur est gelé, commandes bloquées ; Échap quitte. Le serveur revérifie la distance toutes les 10 s pendant la vue (un `SetTimeout` en chaîne côté serveur limité à la durée de la vue) et coupe si la cible dépasse le rayon, quitte le service ou se déconnecte (« Signal perdu »).
  5. La cible n'est **pas** prévenue (comportement d'une vraie caméra piéton), sauf si `Config.Police.BodyCam.PrevenirCible = true` : la cible voit alors « MDT · Votre caméra piéton est consultée par {matricule}. ».
  6. Pas de son (FiveM ne permet pas de recevoir l'audio de proximité d'un autre point de vue).
- **Données** : aucune stockée (mémoire : liste des vues en cours `BodyCamVues[source] = cible`).
- **Règles serveur** : RC1 (spectateur et cible en service), RC2 (1 ouverture / 5 s), distance serveur entre les deux peds ≤ `Rayon` (limite du jeu : au-delà d'environ 400 m le ped n'est plus diffusé au spectateur ; maximum autorisé en config : 400) ; un agent ne peut pas se regarder lui-même ; max `Config.Police.BodyCam.MaxSpectateurs = 2` spectateurs par cible.
- **Textes et états** : vide « Aucun agent en service à portée. » (`police.bodycam.vide`) ; hors de portée « Hors de portée ({distance} m, maximum {rayon} m). » (`police.bodycam.horsportee`) ; coupure « Signal perdu » (`police.cameras.signalperdu`) ; max « Cette caméra est déjà consultée par 2 personnes. » (`police.bodycam.max`) ; superposition « BODYCAM {matricule} » (`police.bodycam.titre`).
- **Notifications** : seulement si `PrevenirCible = true` : cible « MDT · Votre caméra piéton est consultée par {matricule}. » (`police.notif.bodycam`).
- **Liens** : Effectifs, Caméras.
- **Réglages** : `Config.Police.BodyCam.Active = true` ; `Config.Police.BodyCam.Rayon = 300` (max 400) ; `Config.Police.BodyCam.PrevenirCible = false` ; `Config.Police.BodyCam.MaxSpectateurs = 2`.
- **Journal admin** : oui (spectateur, cible, durée).
- **Performance** : thread client seulement pendant la vue (recopie de la rotation chaque image, commandes bloquées), arrêté à la sortie ; vérification serveur toutes les 10 s seulement pendant une vue.
- **Cas limites** : cible qui entre dans un intérieur instancié (routing bucket différent) → le serveur coupe (« Signal perdu ») car le bucket diffère ; cible morte → la vue continue (caméra au sol) ; spectateur attaqué → sortie immédiate.
- **Critères d'acceptation** :
  - Étant donné un agent en service à 150 m, quand un Chef clique « Voir sa caméra piéton », alors il voit depuis la tête de l'agent avec « BODYCAM {matricule} ».
  - Étant donné un agent à 600 m, quand le Chef ouvre la liste, alors il est grisé « Hors de portée » et la vue est refusée.
  - Étant donné un Membre qui envoie à la main l'ouverture d'une caméra piéton, quand le serveur la reçoit, alors il refuse et ne renvoie aucun NetID.

---

## 12. Formation des recrues

### [MET-POL-42] Parcours de formation (étapes réglables)
- **But** : définir les étapes que chaque recrue doit valider.
- **Qui** : `police.formation.parcours` (Patron), admin ; sans service requis.
- **Où** : Police > Formation > bouton « Modifier le parcours ».
- **Parcours** :
  1. Liste ordonnée des étapes : titre, description (ce que la recrue doit savoir faire), « Validation » (toujours « Par un formateur », choix définitif, voir décisions), obligatoire oui/non.
  2. Ajouter / modifier / désactiver / réordonner. Une étape n'est jamais supprimée (désactivée).
  3. Parcours fourni au premier démarrage : 1 « Code pénal et procédures » · 2 « Radio et codes 10 » · 3 « Conduite et poursuite » · 4 « Interpellation et menottage » · 5 « Rédaction d'un rapport dans le MDT » · 6 « Amendes et casier dans le MDT » · 7 « Maniement des armes » · 8 « Patrouille encadrée (2 h) ».
  4. Une étape ajoutée plus tard apparaît « À faire » pour les recrues en cours ; les recrues déjà diplômées ne sont pas affectées.
- **Données** (table `formation_etapes`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| job | varchar(30) | Oui | entreprise police | job du Patron |
| titre | varchar(60) | Oui | — | — |
| description | varchar(500) | Non | — | vide |
| obligatoire | bool | Oui | — | 1 |
| actif | bool | Oui | — | 1 |
| ordre | int | Oui | — | dernier + 1 |
- **Règles serveur** : RC1 (sans service), RC2, RC3, RC4. Max `Config.Police.Formation.MaxEtapes = 20` étapes actives.
- **Textes et états** : vide « Aucune étape. Ajoutez la première étape du parcours. » (`police.formation.etapes.vide`) ; succès « Parcours enregistré. » (`police.formation.etapes.ok`) ; erreur max « 20 étapes maximum. » (`police.formation.etapes.max`).
- **Notifications** : aucune.
- **Liens** : MET-POL-43.
- **Réglages** : `Config.Police.Formation.MaxEtapes = 20` ; `Config.Police.Formation.ParcoursDefaut = true`.
- **Journal admin** : oui.
- **Performance** : étapes en cache par job.
- **Cas limites** : étape désactivée déjà validée par une recrue → validation conservée, l'étape ne compte plus dans la progression ; deux jobs police → un parcours par job ; parcours vide → les recrues voient « Aucun parcours défini ».
- **Critères d'acceptation** :
  - Étant donné le parcours par défaut, quand le Patron ajoute « Premiers secours », alors toutes les recrues en cours la voient « À faire ».
  - Étant donné une étape désactivée, quand une recrue ouvre sa progression, alors elle n'apparaît plus dans le total.
  - Étant donné un Chef qui envoie une modification de parcours à la main, quand le serveur la reçoit, alors il refuse.

### [MET-POL-43] Suivi des recrues (formateur responsable, validation des étapes)
- **But** : attribuer un formateur à chaque recrue et valider ses étapes jusqu'à la fin de formation.
- **Qui** : recrue : voit sa progression ; formateur : `police.formation.former` (Chef+) ; attribuer un formateur : Chef+ ; tous lisent la liste des recrues (Membre+).
- **Où** : Police > Formation.
- **Parcours** :
  1. Toute personne au grade le plus bas d'une entreprise police (Recrue) est automatiquement inscrite en formation à son embauche (événement ENT-GES « recrutement » ou premier `esx:setJob` vers ce job) : ligne `formation_suivi` statut `en_cours`.
  2. Vue recrue : barre de progression « {n}/{total} étapes », liste des étapes avec état (« À faire », « Validée le {date} par {formateur} »), formateur responsable.
  3. Vue formateur/Chef : liste des recrues (nom, formateur, progression, date d'entrée). « Attribuer un formateur » → liste des agents ayant `police.formation.former`.
  4. Valider une étape : le formateur responsable (ou tout Chef+) clique « Valider » sur une étape → commentaire facultatif → `pop_tablet:police:formation:valider`. « Annuler la validation » possible (Chef+) avec motif.
  5. Quand toutes les étapes obligatoires actives sont validées : statut `terminee`, notification au Patron et aux Chefs « prête pour promotion ». La promotion elle-même se fait dans ENT-GES (gestion des employés).
  6. Une recrue promue avant la fin : statut `dispensee` (automatique au changement de grade), historique conservé.
- **Données** (table `formation_suivi`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| identifier | varchar(60) | Oui | recrue | — |
| job | varchar(30) | Oui | — | — |
| formateur | varchar(60) | Non | agent avec `police.formation.former` | NULL |
| validations | JSON | Oui | `{ etapeId = { par, le, commentaire(300) } }` | `{}` |
| statut | enum `en_cours`/`terminee`/`dispensee` | Oui | — | `en_cours` |
| entree_le / fin_le | datetime | — | — | — |
- **Règles serveur** : RC1, RC2, RC3, RC4. Un formateur ne valide que ses recrues, sauf Chef+ (toutes). On ne valide pas sa propre formation. Étape inexistante ou désactivée → refus.
- **Textes et états** : vide (formateur) « Aucune recrue en formation. » (`police.formation.vide`) ; recrue sans formateur « Aucun formateur attribué. Demandez à un Chef. » (`police.formation.sansformateur`) ; succès « Étape « {etape} » validée. » (`police.formation.valide`), « Formateur attribué. » (`police.formation.attribue`) ; fin « Formation terminée. » (`police.formation.terminee`) ; erreur « Vous n'êtes pas le formateur de cette recrue. » (`police.formation.pasformateur`).
- **Notifications** : recrue : « MDT · Étape validée : {etape}. » (`police.notif.etape`) et « MDT · {formateur} est votre formateur. » (`police.notif.formateur`) ; formateur attribué : « MDT · Vous formez désormais {recrue}. » (`police.notif.nouvellerecrue`) ; Patron et Chefs à la fin : « MDT · {recrue} a terminé sa formation : prête pour promotion. » (`police.notif.formationfinie`).
- **Liens** : ENT-GES (recrutement, grades, promotion), Effectifs.
- **Réglages** : aucun en plus de MET-POL-42.
- **Journal admin** : oui (validations, annulations, attribution).
- **Performance** : liste paginée 20 ; une ligne par recrue.
- **Cas limites** : recrue virée → suivi archivé (RC7) ; formateur parti → recrues marquées « Aucun formateur attribué » ; double validation → RC3.
- **Critères d'acceptation** :
  - Étant donné une recrue avec formateur, quand celui-ci valide les 8 étapes, alors le statut passe « Terminée » et le Patron reçoit « prête pour promotion ».
  - Étant donné un Chef non formateur, quand il valide une étape d'une recrue, alors c'est accepté (Chef+).
  - Étant donné une recrue qui envoie à la main la validation de sa propre étape, quand le serveur la reçoit, alors il refuse.

---

## 13. Saisie

### [MET-POL-44] Saisie d'une tablette de suspect (icône déguisée, contenu protégé par code)
- **But** : permettre à la police d'examiner une tablette saisie sans pouvoir lire les apps protégées (gang) sans le code.
- **Qui** : `police.saisie` (Recrue+), en service.
- **Où** : objet `pop_tablet` saisi dans l'inventaire de l'agent > « Utiliser » ; ou Police > Preuves > preuve type « Tablette » > « Examiner ».
- **Parcours** :
  1. Condition : inventaire à métadonnées (ox_inventory ou qs-inventory). Chaque tablette porte la métadonnée `serial` (numéro de série unique `PT-XXXX-XXXX`, BASE-OBJ-03) ; le propriétaire est `owner_identifier` de la ligne `pop_tablet_devices` correspondante (lu côté serveur). Sans ce type d'inventaire, la fonction est désactivée (la tablette est liée au joueur, pas à un objet).
  2. L'agent prend la tablette du suspect par la fouille de son serveur, puis l'utilise. Le serveur voit `proprietaire ≠ agent` et agent police en service → ouvre la tablette en **mode saisie** (sinon, un non-policier qui utilise la tablette d'un autre obtient l'écran de verrouillage normal).
  3. À la première ouverture en mode saisie, le serveur crée automatiquement une preuve type `tablette` (MET-POL-36) avec le numéro de série, et une ligne `saisies`.
  4. Mode saisie : bandeau permanent « Tablette saisie — appartient à : {nom} — série {serie} » ; écran d'accueil du propriétaire avec **ses icônes telles qu'il les voit** : l'app Gang apparaît sous son icône et son nom déguisés (ex. « Météo »), indiscernable d'une app normale.
  5. Ouvrir une app : chaque app demande le **code de verrouillage de la tablette** du propriétaire (réglé dans Réglages, BASE-OBJ-04 ; 4 à 6 chiffres) ; si le propriétaire n'a pas de code, les apps non protégées s'ouvrent **en lecture seule** (aucun envoi, aucun paiement, aucune action). L'app Gang demande en plus **son propre code** (réglé dans l'app Gang) ; sans ce code, elle affiche son faux contenu de couverture (ex. l'écran météo) et rien d'autre.
  6. Essais : 5 codes faux → blocage 10 min de cette tablette pour tous les agents (`Config.Police.Saisie.EssaisMax = 5`, `Config.Police.Saisie.BlocageMin = 10`). Chaque essai est journalisé.
  7. Si le code est connu (aveux RP), le contenu s'affiche en lecture seule ; captures possibles via le bouton « Ajouter à la preuve » (capture d'écran de la NUI si screencapture présent, sinon texte copié dans la description de la preuve ; cadre `saisie_tablette`). Pour l'app Gang, le code du membre (aveu) n'ouvre que le **livre de comptes** du gang en lecture seule (MET-GANG-11) ; messagerie, coffre et membres restent fermés (messagerie : seulement par mandat d'infiltration, MET-POL-47).
  8. Restitution : la tablette est rendue par l'inventaire ; la preuve passe `restituee` (MET-POL-36, chaîne de possession). Le propriétaire récupère sa tablette intacte (aucune donnée modifiée).
  9. Option `Config.Police.Saisie.PrevenirGang = true` (défaut) : à la première ouverture en mode saisie d'une tablette contenant l'app Gang, le chef du gang (s'il est en ville et a sa tablette) reçoit dans l'app Gang : « Une tablette du groupe a été saisie par la police. » (sans nom d'agent).
- **Données** (table `saisies`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| serie | varchar(12) | Oui | `PT-XXXX-XXXX` | — |
| proprietaire | varchar(60) | Oui | — | — |
| agent | varchar(60) | Oui | premier agent qui l'ouvre | — |
| preuve_id | int | Oui | — | — |
| essais | int | Oui | — | 0 |
| bloque_jusqua | datetime | Non | — | NULL |
| code_trouve | bool | Oui | — | 0 |
- **Règles serveur** : RC1, RC2, RC3. Le code est vérifié **côté serveur uniquement** (haché, jamais envoyé au client). En mode saisie, le serveur refuse toute écriture faite au nom du propriétaire (factures, messages internes, transferts, publications) : chaque callback d'app vérifie `session.modeSaisie` et renvoie `lecture_seule`. Le serveur ne révèle jamais à la police qu'une app est l'app Gang (même icône, même nom, même taille de données renvoyée que le déguisement).
- **Textes et états** : bandeau « Tablette saisie — appartient à : {nom} — série {serie} » (`police.saisie.bandeau`) ; code « Code de la tablette » (`police.saisie.code`) ; erreur « Code incorrect. Essais restants : {n}. » (`police.saisie.codefaux`) ; blocage « Trop d'essais. Tablette bloquée pendant {min} min. » (`police.saisie.bloquee`) ; action refusée « Tablette saisie : lecture seule. » (`police.saisie.lectureseule`) ; inventaire incompatible : action « Utiliser » sur la tablette d'autrui affiche « Cette tablette ne vous appartient pas. » (`police.saisie.pasavous`).
- **Notifications** : chef de gang (option) : « Une tablette du groupe a été saisie par la police. » (`gang.notif.saisie`) ; aucune notification au propriétaire.
- **Liens** : Preuves (création auto, restitution), app Gang (déguisement, code propre), Apps perso (code de verrouillage), inventaire (métadonnées).
- **Réglages** : `Config.Police.Saisie.Active = true` ; `Config.Police.Saisie.EssaisMax = 5` ; `Config.Police.Saisie.BlocageMin = 10` ; `Config.Police.Saisie.PrevenirGang = true`.
- **Journal admin** : oui (ouverture, chaque essai de code, réussite, captures).
- **Performance** : rien tant que l'objet n'est pas utilisé ; données du propriétaire chargées écran par écran comme une tablette normale.
- **Cas limites** : propriétaire déconnecté → fonctionne (données en base) ; tablette d'un autre policier saisie → même règles (le code protège) ; l'agent garde la tablette et quitte le service → la tablette ne s'ouvre plus en mode saisie (écran verrouillé normal) ; double utilisation → une seule preuve créée (unicité sur `serie` + statut non restitué).
- **Critères d'acceptation** :
  - Étant donné la tablette d'un membre de gang avec l'app Gang déguisée en « Météo », quand un agent l'ouvre en mode saisie, alors il voit l'icône « Météo » et, en l'ouvrant sans le code du gang, seulement l'écran météo.
  - Étant donné 5 codes faux, quand l'agent en tape un 6e, alors il voit « Trop d'essais. Tablette bloquée pendant 10 min. ».
  - Étant donné un agent en mode saisie qui envoie à la main un paiement de facture au nom du propriétaire, quand le serveur le reçoit, alors il refuse `lecture_seule` et rien n'est payé.

---

## 14. Ajouts validés par le client (24/11/2026)

### [MET-POL-45] Avis de recherche public sur toutes les tablettes
- **But** : diffuser à toute la ville, sur chaque tablette, un avis de recherche (photo, description, plaque) créé par un Chef police, pour une durée limitée et retirable.
- **Qui** : diffuser et retirer : `police.avis.public` (Chef+), en service ; réglable. Voir : tout joueur qui a une tablette (aucun droit requis).
- **Où** : Police > Mandats > onglet « Avis de recherche » > avis actif > bouton « Diffuser à toute la ville » ; Police > « Avis publics » (sous-onglet, liste des diffusions). Côté ville : notification en bandeau, historique des notifications (BASE-ECR-05) et bloc « Avis de recherche » ajouté automatiquement en haut de la page d'accueil du site de la police (`lspd.rp`, Navigateur).
- **Parcours** :
  1. Le Chef ouvre un avis actif (MET-POL-31) et clique « Diffuser à toute la ville ». Fenêtre préremplie : « Titre public » (défaut « Avis de recherche »), « Description publique » (défaut : description de l'avis ; le motif interne n'est jamais repris), « Photo » (une des photos de l'avis, ou aucune), « Plaque » (avis véhicule : plaque de l'avis), case « Afficher le nom » (avis citoyen connu, cochée par défaut), « Durée » (1 à 72 h, défaut 24 h).
  2. `pop_tablet:police:avispublic:diffuser { avisNumero, titre, description, photo, afficherNom, heures, actionId }` → le serveur vérifie, crée la ligne `police_avis_publics` (numéro `AP-` + 5 chiffres), puis envoie une seule fois `pop_tablet:client:wanted` à tous les joueurs connectés qui ont la tablette (RC10) : bandeau « Avis de recherche · {titre} » avec la photo en miniature ; clic → fiche publique (photo, nom si affiché, description, plaque, « Diffusé le {date} », bouton « Transmettre une information »).
  3. « Transmettre une information » → formulaire de la boîte Demandes de l'entreprise police (ENT-DEM, type « Contact », texte ≤ 500, référence `AP-xxxxx` ajoutée par le serveur) ; aucune autre donnée n'est envoyée.
  4. Le site `lspd.rp` affiche le bloc « Avis de recherche » (liste des avis publics actifs, 5 max) tant qu'au moins un avis est actif ; le bloc disparaît sinon.
  5. « Retirer » (Chef+, motif `retrouve` / `annule`) → statut `retire` ; l'avis disparaît du site, de la fiche publique et de l'historique des notifications (la notification passe « Avis retiré »). Levée de l'avis interne (MET-POL-31) → l'avis public est retiré en même temps.
  6. Expiration : `fin_le` dépassé → statut `expire`, calculé à la lecture (ouverture de la fiche, du site, de la liste), sans boucle.
- **Données** (table `police_avis_publics`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| numero | varchar(10) | Oui | `AP-` + 5 chiffres, unique | auto |
| avis_id | int | Oui | avis actif (MET-POL-31) | — |
| titre | varchar(60) | Oui | RC4 | « Avis de recherche » |
| description | varchar(500) | Oui | RC4 | description de l'avis |
| photo | varchar(255) | Non | une photo de l'avis, RC5 | NULL |
| nom_affiche | varchar(64) | Non | nom du citoyen si « Afficher le nom » | NULL |
| plaque | varchar(8) | Non | avis véhicule | NULL |
| statut | enum `actif`/`retire`/`expire` | Oui | — | `actif` |
| debut_le / fin_le | datetime | Oui | durée 1 à 72 h | maintenant / +24 h |
| cree_par / retire_par / retire_motif | varchar | — | — | — |
- **Règles serveur** : RC1, RC2 (limite propre : 1 diffusion / 5 min par agent), RC3, RC4, RC5. Avis source `actif` ; un seul avis public actif par avis ; au plus `Config.Police.AvisPublic.MaxActifs = 5` avis publics actifs ; jamais d'identifiant, de motif interne, de dangerosité ou de nom d'agent envoyé aux citoyens ; photo obligatoirement choisie parmi celles de l'avis (aucune URL libre).
- **Textes et états** :
  - Bouton « Diffuser à toute la ville » (`police.avispublic.diffuser`) ; « Retirer » (`police.avispublic.retirer`).
  - Succès « Avis {numero} diffusé à toute la ville. » (`police.avispublic.ok`), « Avis retiré. » (`police.avispublic.retire`).
  - Vide (liste police) « Aucun avis public. » (`police.avispublic.vide`).
  - Erreurs : « 5 avis publics au maximum. Retirez-en un. » (`police.avispublic.max`) ; « Cet avis est déjà diffusé. » (`police.avispublic.deja`) ; « Durée : 1 à 72 heures. » (`police.avispublic.duree`).
  - Fiche publique : « Diffusé le {date} » (`avis.public.diffuse_le`), « Transmettre une information » (`avis.public.informer`), « Avis retiré. » (`avis.public.retire`), « Avis expiré. » (`avis.public.expire`).
- **Notifications** : tous les joueurs avec tablette : titre « Avis de recherche » (`avis.public.notif_titre`), texte « {titre} » (`avis.public.notif_texte`) ; agents en service : « MDT · Avis {numero} diffusé à toute la ville par {matricule} {nom}. » (`police.notif.avispublic`).
- **Liens** : MET-POL-31 (avis source), ENT-DEM (informations des citoyens), Navigateur / site `lspd.rp` (bloc auto), BASE-API-04 (notifications), BASE-ECR-05 (historique).
- **Réglages** : `Config.Police.AvisPublic.Active = true` ; `Config.Police.AvisPublic.MaxActifs = 5` ; `Config.Police.AvisPublic.DureeDefautHeures = 24` ; `Config.Police.AvisPublic.DureeMaxHeures = 72` ; `Config.Police.AvisPublic.BlocSite = true`.
- **Journal admin** : oui (diffusion, retrait, expiration ; Discord catégorie `police`).
- **Performance** : une seule diffusion réseau par avis ; avis publics actifs en cache serveur (≤ 5), lus par le site et la fiche ; photo chargée à l'ouverture de la fiche seulement.
- **Cas limites** : joueur qui se connecte après la diffusion → pas de bandeau, l'avis est visible sur `lspd.rp` et dans l'historique ; entreprise police sans site ou brique Demandes coupée → bloc et bouton « Transmettre » cachés ; avis interne levé pendant la diffusion → retrait immédiat ; double clic → RC3, une seule diffusion.
- **Critères d'acceptation** :
  - Étant donné un avis véhicule actif, quand un Chef le diffuse 24 h, alors chaque joueur connecté avec une tablette reçoit « Avis de recherche · {titre} » avec la plaque, et `lspd.rp` affiche le bloc.
  - Étant donné un avis public actif, quand le Chef le retire, alors il disparaît du site et la fiche publique affiche « Avis retiré. ».
  - Étant donné un avis public diffusé il y a 25 h pour 24 h, quand un citoyen ouvre le site, alors l'avis n'apparaît plus.
  - Étant donné un Membre qui envoie `pop_tablet:police:avispublic:diffuser` à la main, quand le serveur le reçoit, alors il refuse `pas_droit` et rien n'est diffusé.

### [MET-POL-46] Carte des crimes de la semaine
- **But** : montrer aux Chefs police, sur une carte de chaleur, où se concentrent les faits décrits dans les rapports de police de la tablette.
- **Qui** : `police.carte` (Chef+), en service ; réglable.
- **Où** : Police > onglet « Carte des crimes » (barre latérale, après « Rapports »).
- **Parcours** :
  1. Ouverture → `pop_tablet:police:carte:get { periode, type }` ; périodes : « Cette semaine » (7 derniers jours, défaut), « Semaine dernière » (jours 8 à 14), « 4 dernières semaines » ; type : « Tous » ou un type de rapport (MET-POL-21).
  2. Serveur : sélectionne les rapports `publie` ou `transmis`, non archivés, dont `faits_le` est dans la période et qui ont une position (`x`, `y` non vides) ; les regroupe en cases carrées de `Config.Police.CarteCrimes.Cellule = 100` m (`floor(x / 100)`, `floor(y / 100)`) et renvoie la liste `{ cx, cy, n }` + le nombre de rapports sans position + les 5 lieux (`lieu`) les plus cités.
  3. NUI : image statique de la carte GTA (celle de MET-POL-08) ; chaque case est un carré de la couleur d'accent à 4 niveaux d'opacité fixes selon `n` (1 → 20 %, 2–3 → 40 %, 4–6 → 60 %, 7 et plus → 80 %), sans dégradé ni flou ; légende des 4 niveaux ; total « {n} rapports sur la période ».
  4. Clic sur une case → liste des rapports de la case (numéro, titre, type, date), 20 par page ; clic → rapport (MET-POL-22, droits de lecture habituels).
  5. Position des rapports : colonnes `x`, `y` ajoutées à la table `rapports` (MET-POL-22), remplies par le serveur avec la position du ped de l'agent quand il clique « Ma position », ou avec les coordonnées de l'appel quand le rapport est créé depuis un appel (MET-POL-10) ; jamais envoyées par le client.
- **Données** : lecture de `rapports` (`faits_le`, `type`, `x`, `y`, `lieu`, `statut`, `archive`) ; colonnes ajoutées à `rapports` : `x FLOAT NULL`, `y FLOAT NULL` (migration BASE-MOT-17) ; index `(statut, faits_le)`. Réponse : `cases` (liste `{ cx, cy, n }`, 2 500 cases max), `sansPosition` (int), `lieux` (5 × `{ lieu, n }`).
- **Règles serveur** : RC1, RC2 lecture ; période dans la liste fixe ; type dans la liste des types ; aucune position de joueur n'est utilisée, seulement celles des rapports ; rapports en brouillon jamais comptés.
- **Textes et états** : onglet « Carte des crimes » (`police.carte.titre`) ; périodes « Cette semaine » (`police.carte.semaine`), « Semaine dernière » (`police.carte.semaine_derniere`), « 4 dernières semaines » (`police.carte.quatre_semaines`) ; total « {n} rapports sur la période » (`police.carte.total`) ; sans position « {n} rapports sans position ne sont pas sur la carte. » (`police.carte.sans_position`) ; vide « Aucun rapport sur cette période. » (`police.carte.vide`) ; lieux « Lieux les plus cités » (`police.carte.lieux`) ; pas le droit : onglet caché.
- **Notifications** : aucune.
- **Liens** : MET-POL-21 / MET-POL-22 (rapports et positions), MET-POL-10 (rapport créé depuis un appel).
- **Réglages** : `Config.Police.CarteCrimes.Active = true` ; `Config.Police.CarteCrimes.Cellule = 100` (m, 50 à 500) ; `Config.Police.CarteCrimes.CacheMinutes = 10`.
- **Journal admin** : non (lecture).
- **Performance** : une requête agrégée (`GROUP BY` des cases) par période et type, résultat en cache serveur 10 min, invalidé à la publication d'un rapport ; aucune boucle, aucun blip en jeu ; la liste d'une case est paginée 20.
- **Cas limites** : aucun rapport avec position → texte vide et compteur « sans position » ; rapport archivé après mise en cache → disparaît au plus tard 10 min après ou à la prochaine publication ; 3 000 rapports dans la semaine → la requête agrégée renvoie au plus 2 500 cases (les plus remplies) ; les rapports des autres cases sont comptés dans la ligne « {n} rapports hors des cases affichées. » (`police.carte.hors_cases`).
- **Critères d'acceptation** :
  - Étant donné 4 rapports publiés cette semaine à moins de 100 m l'un de l'autre, quand un Chef ouvre la carte, alors une case à 60 % d'opacité apparaît à cet endroit et un clic liste les 4 rapports.
  - Étant donné un rapport en brouillon avec position, quand la carte est chargée, alors il n'est pas compté.
  - Étant donné une Recrue qui envoie `pop_tablet:police:carte:get` à la main, quand le serveur la reçoit, alors il refuse `pas_droit` et ne renvoie aucune donnée.

### [MET-POL-47] Infiltration de la messagerie d'un gang (mandat signé par un juge)
- **But** : avec un mandat d'infiltration signé par un juge, donner à la police un accès en lecture secret à la messagerie d'un gang, à partir de la signature seulement, pour une durée limitée, et permettre de joindre les messages lus comme preuves.
- **Qui** : demander : `police.mandat.creer` (Membre+) ; signer : juge seulement (`Config.Police.Mandats.JugeRequis`, MET-POL-29 / MET-JUS-07) ; lire : l'agent qui a demandé le mandat et les agents ayant `police.infiltration` (Chef+), en service ; joindre comme preuve : les mêmes, avec `police.preuves`.
- **Où** : Police > Mandats > « Demander un mandat » > type « Mandat d'infiltration » ; Police > Mandats > mandat d'infiltration actif > bouton « Ouvrir la messagerie ».
- **Parcours** :
  1. Demande : « Gang » (liste des noms publics des entreprises de modèle `gang` non archivées, sans aucun membre), « Motif » (obligatoire), « Rapport lié » (obligatoire), « Durée demandée » (1 à 168 h, défaut 72 h). → `pop_tablet:police:mandat:creer { type = 'infiltration', gangId, … }` → statut `attente` ; les juges en service sont notifiés (MET-JUS-07).
  2. Signature par un juge (MET-POL-29 étape 6) → statut `actif`, `signe_le` = heure de signature, `expire_le` = `signe_le` + durée demandée. Le juge peut réduire la durée avant de signer.
  3. « Ouvrir la messagerie » → `pop_tablet:police:infiltration:list { mandatNumero, before }` : le serveur renvoie les messages du gang **non retirés, créés entre `signe_le` et `min(maintenant, expire_le)`**, 20 par page, du plus ancien au plus récent ; chaque message affiche le surnom de l'auteur (comme le voit le gang, jamais le vrai nom), la date et l'heure. Aucun message antérieur à la signature n'est jamais renvoyé, quel que soit le paramètre envoyé.
  4. En direct : tant que l'écran est ouvert et le mandat actif, les nouveaux messages du gang sont poussés à l'agent (abonnement de MET-GANG-04) ; désabonnement à la fermeture de l'écran ou de la tablette.
  5. **Secret** : le gang n'est jamais prévenu (aucune notification, aucune trace dans l'app Gang, `Config.Police.Saisie.PrevenirGang` ne s'applique pas) ; le mandat n'apparaît pas dans la fiche citoyen ni sur l'Accueil ; il est visible seulement dans Police > Mandats pour les agents autorisés ci-dessus, dans Justice > Mandats pour les juges et le procureur, et pour l'admin.
  6. « Joindre comme preuve » : l'agent coche 1 à 20 messages → `pop_tablet:police:infiltration:preuve { mandatNumero, messageIds, rapportId, actionId }` → le serveur crée une preuve type `document` (MET-POL-36) avec cadre `infiltration`, `mandat_id`, le texte copié et figé des messages (surnom, date, heure, texte) et la mention « Messagerie du gang {nom} · mandat {numero} signé par le juge {nom} » ; recevable puisque chaque message est dans la période du mandat ; chaîne de possession ouverte.
  7. Fin : à `expire_le` (vérifié à chaque requête, sans boucle) l'accès se ferme ; « Lever » (demandeur, Chef+ ou juge, MET-POL-30) le ferme tout de suite ; « Prolonger » (juge seulement, + durée initiale, 2 fois max) garde la continuité. Après la fin, seuls les messages déjà joints comme preuves restent lisibles, dans les preuves.
  8. Journal : chaque ouverture d'écran, chaque page chargée (ids des messages renvoyés) et chaque preuve créée est écrit dans `police_infiltration_journal` et dans le journal admin.
- **Données** : table `mandats` (type `infiltration`, `gang_id`, `signe_le`, `expire_le`) ; lecture de `pop_tablet_gang_messages` (MET-GANG-04) ; table `police_infiltration_journal` :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| id | int PK | Oui | — | auto |
| mandat_id | int | Oui | mandat d'infiltration | — |
| agent | varchar(60) | Oui | identifiant de l'agent | — |
| action | enum `ouverture`/`page`/`preuve` | Oui | — | — |
| message_ids | JSON | Non | ids renvoyés ou joints, 20 max | `[]` |
| preuve_id | int | Non | — | NULL |
| cree_le | datetime | Oui | — | maintenant |
- **Règles serveur** : RC1 (service, droits ci-dessus), RC2 lecture (15 / 10 s), RC3 pour la preuve, RC4. Mandat `actif`, type `infiltration`, `signature_code` non vide (signé par un juge) et `maintenant < expire_le` ; filtre SQL obligatoire `gang_id = mandat.gang_id AND withdrawn = 0 AND created_at >= signe_le AND created_at <= LEAST(NOW(), expire_le)`, aucune borne venant du client ; un seul mandat d'infiltration `attente` ou `actif` par gang ; durée 1 à `Config.Police.Infiltration.DureeMaxHeures = 168` h ; messages retirés par leur auteur jamais renvoyés (sauf copie déjà jointe à une preuve) ; aucune action d'écriture possible dans la messagerie du gang.
- **Textes et états** :
  - Titre de l'écran « Messagerie infiltrée · {gang} » (`police.infiltration.titre`) ; bandeau permanent « Lecture secrète · mandat {numero} · jusqu'au {date} » (`police.infiltration.bandeau`).
  - Vide « Aucun message depuis la signature du mandat. » (`police.infiltration.vide`).
  - Bouton « Ouvrir la messagerie » (`police.infiltration.ouvrir`) ; « Joindre comme preuve » (`police.infiltration.joindre`) ; succès « Preuve {numero} créée avec {n} messages. » (`police.infiltration.preuve_ok`).
  - Erreurs : « Mandat expiré. Accès fermé. » (`police.infiltration.expire`) ; « Ce mandat n'est pas signé par un juge. » (`police.infiltration.non_signe`) ; « Un mandat d'infiltration existe déjà pour ce gang ({numero}). » (`police.infiltration.doublon`) ; « 20 messages au maximum par preuve. » (`police.infiltration.max`) ; « Durée : 1 à 168 heures. » (`police.infiltration.duree`).
- **Notifications** : demandeur à la signature : « MDT · Mandat {numero} signé : accès ouvert jusqu'au {date}. » (`police.notif.infiltration_ouverte`) ; demandeur 1 h avant la fin : à l'ouverture de la tablette, « MDT · Le mandat {numero} expire dans moins d'une heure. » (`police.notif.infiltration_fin`) ; aucune notification au gang ni à ses membres.
- **Liens** : MET-POL-28 / 29 / 30 (mandat, signature, levée, prolongation), MET-JUS-07 (signature par le juge), MET-GANG-04 (messagerie), MET-POL-36 (preuve, recevabilité, chaîne de possession), MET-JUS-03 (preuves dans l'affaire), MET-GANG-11 (le mandat ouvre aussi le livre de comptes en lecture).
- **Réglages** : `Config.Police.Infiltration.Active = true` ; `Config.Police.Infiltration.DureeDefautHeures = 72` ; `Config.Police.Infiltration.DureeMaxHeures = 168` ; `Config.Police.Infiltration.MaxMessagesParPreuve = 20`.
- **Journal admin** : oui, catégorie `police` (demande, signature, chaque ouverture, chaque page, chaque preuve, levée, expiration) ; jamais affiché aux membres du gang.
- **Performance** : lecture paginée 20 sur l'index `(gang_id, withdrawn, id)` de MET-GANG-04 ; poussée en direct seulement aux agents qui ont l'écran ouvert ; écritures du journal par la file groupée (BASE-MOT-04) ; aucune boucle.
- **Cas limites** :
  - Mandat signé à 18 h 00 : un message envoyé à 17 h 59 n'est jamais visible, un message de 18 h 01 l'est.
  - Message retiré par son auteur après lecture par la police : il disparaît de l'écran ; s'il a déjà été joint, la preuve garde sa copie.
  - Gang archivé par l'admin pendant le mandat : accès fermé, mandat levé automatiquement (motif `annule`).
  - Agent qui perd son grade Chef pendant la lecture : la requête suivante est refusée `pas_droit`.
- **Critères d'acceptation** :
  - Étant donné un mandat d'infiltration signé par un juge à 18 h, quand l'agent ouvre la messagerie à 20 h, alors il voit seulement les messages envoyés entre 18 h et 20 h, et le gang ne reçoit aucune notification.
  - Étant donné un mandat de 72 h expiré, quand l'agent clique « Ouvrir la messagerie », alors il voit « Mandat expiré. Accès fermé. ».
  - Étant donné 3 messages cochés, quand l'agent clique « Joindre comme preuve », alors une preuve « Recevable » de cadre « Infiltration » contient les 3 messages figés et la chaîne de possession commence.
  - Étant donné un agent qui envoie à la main `before` = id d'un message antérieur à la signature, quand le serveur répond, alors aucun message antérieur à la signature n'est renvoyé et la tentative est journalisée.

---

## Décisions prises par défaut

1. **Données partagées entre jobs police** : tous les jobs de `Config.Police.Jobs` partagent un seul fichier (appels, casier, rapports, mandats). Choix des MDT du marché ; les droits restent par entreprise.
2. **Le barème d'amendes est le code pénal** : pas de barème séparé ; l'agent peut baisser une amende ou une peine, jamais la monter au-dessus du barème. Plafond par amende 50 000 $, Recrue plafonnée à 2 500 $, peine max 120 « mois ».
3. **Prison = signal seul** : la tablette n'emprisonne pas elle-même ; elle émet `pop_tablet:sentencePronounced` (une seule fois par inscription, cible à ≤ 10 m) ; adaptateur facultatif réglé une seule fois dans la base (`Config.Signals.SentenceJail`, fichiers `bridge/jail/`).
4. **Mandats validés, avis immédiats** : mandats « Chef+ ou juge » par défaut (sans auto-validation), 7 jours, 2 prolongations ; avis de recherche actifs tout de suite (validation activable), 3 jours.
5. **Unités et statuts en mémoire** : unités, statuts et effectifs ne survivent pas à un redémarrage ; toutes les autres données (appels, rapports, casier, amendes, mandats, preuves) sont en base.
6. **Recherche de citoyen par nom libre** : tout agent en service peut chercher n'importe quel citoyen par nom (pas de contrôle d'identité préalable) ; recherches non journalisées par défaut (`Config.Police.JournalRecherches = false`).
7. **Amende = facture** : toujours créée via l'app Factures ; fenêtre simple pour les joueurs sans tablette ; part agent 0 % par défaut ; impayée signalée sur la fiche après 7 jours, sans majoration.
8. **Caméra piéton** : rayon 300 m (max 400, limite de diffusion réseau du jeu), image seule sans son, cible non prévenue par défaut, 2 spectateurs max ; caméras fixes : décor partout, joueurs visibles seulement dans la zone de diffusion du spectateur.
9. **Saisie de tablette** : exige un inventaire à métadonnées (ox_inventory / qs-inventory), sinon désactivée ; lecture seule même avec le code ; app Gang protégée par son propre code en plus du code de la tablette ; 5 essais puis 10 min de blocage ; chef de gang prévenu par défaut.
10. **Formation** : validation par formateur uniquement, choix définitif (pas de quiz automatique : en RP sérieux, un humain valide) ; inscription automatique au grade le plus bas ; fin de formation = notification, la promotion reste manuelle dans ENT-GES.
11. **Preuves** : tout se passe dans la tablette par défaut (objet saisi gardé dans la preuve, chaîne de possession complète, cadre d'obtention et recevabilité) ; le casier physique avec coffre dans le monde (stashs ox_inventory `pop_preuve_C-xxxx`, salle des preuves) est optionnel et désactivé par défaut (`Config.Police.EvidenceLocker = false`, MET-POL-38).
14. **Aucun marquage « volé »** (décision du client : aucune fonction ne pénalise les biens des joueurs) : pas de détection ni d'alerte automatique de vol, pas d'export `ReportStolen` ; seule une plainte écrite à la main (rapport) existe (MET-POL-20).
15. **Mandats signés** : perquisition et infiltration exigent la signature d'un juge (`Config.Police.Mandats.JugeRequis`) ; une preuve obtenue sans mandat valide est marquée « Irrecevable » dans l'affaire.
16. **Ajouts validés par le client** : avis de recherche public sur toutes les tablettes (45), carte des crimes de la semaine (46), infiltration de la messagerie d'un gang sur mandat (47).
12. **Empreintes** : code dérivé de l'identifier avec un sel serveur ; identifiables seulement une fois « fichées » (inscription au casier ou fichage manuel).
13. **Ajouts** non demandés mais jugés indispensables : matricule agent (07), appel manuel / renfort (11), bouton de détresse (12), retrait de permis (18).


> **Relecture croisée (24/11/2026)** : ce fichier a été aligné sur les 5 autres. Les noms communs (signaux, tables, réglages, droits, textes d'erreur, constantes) sont listés dans `00-sommaire.md`, qui fait foi en cas de doute.
