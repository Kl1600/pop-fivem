# POP Tablet · 3 · Métiers : EMS, Mécano, Justice, Gang, Immobilier

Fiches de fonctionnalités du périmètre **3 · Métiers** (hors police). Elles suivent `_modele.md` et respectent `_contexte.md`. Toute valeur écrite ici est la valeur à coder.

## Conventions communes à ce fichier (s'appliquent à toutes les fiches ci-dessous)

Ces règles évitent de répéter la même chose dans chaque fiche. Une fiche peut les préciser, jamais les contredire.

1. **Identité** : un joueur est désigné par l'identifiant de son personnage (ESX `identifier`, QBCore / Qbox `citizenid`), passé par le bridge (`Bridge.GetIdentifier(src)`). Le nom affiché est « Prénom Nom » du personnage (`Bridge.GetCharName(identifier)`).
2. **Rattachement métier** (modifiable dans `config.lua`, ouvert) :
   - EMS : `Config.EMS.Jobs = { 'ambulance' }` → entreprise « Services médicaux » (slug `ems`) créée par défaut (SITE-CRE-01).
   - Mécano : `Config.Mechanic.Jobs = { 'mechanic' }` → entreprise « Los Santos Customs » (slug `mecano`) créée par défaut (SITE-CRE-01). Chaque job listé = une entreprise mécano distincte.
   - Justice : `Config.Justice.Roles = { avocat = { job = 'avocat', minGrade = 0, maxGrade = 99 }, procureur = { job = 'justice', minGrade = 0, maxGrade = 1 }, juge = { job = 'justice', minGrade = 2, maxGrade = 99 } }` → entreprises « Cabinet d'avocats » (métier `avocat`) et « Tribunal » (métier `justice`).
   - Immobilier : brique `metier_immobilier` de toute entreprise de modèle `immobilier` (« Dynasty 8 » par défaut, SITE-CRE-01) ; aucun réglage de métier propre (`Config.RealEstate.*`).
   - Gang : appartenance gérée par la tablette (`Config.Gang.Source = 'tablet'`), valeurs possibles `'tablet'`, `'job'`, `'job2'` (second métier, ESX avec script `job2`), `'gang'` (gang natif de QBCore / Qbox : `PlayerData.gang`, écrit par `Player.Functions.SetGang` sur QBCore et `exports.qbx_core:AddPlayerToGang` sur Qbox). Les gangs sont créés par l'admin (branche Admin) ; aucun gang n'existe par défaut.
3. **Service** : une app métier (EMS, Mécano, Justice) n'est utilisable qu'en service (état « Hors service » du contexte). L'app Gang n'a pas de service.
4. **Fréquence** : chaque action serveur a une limite par joueur. Par défaut `Config.RateLimit.Default = { n = 5, s = 10 }` de la base (BASE-MOT-11). Une fiche peut fixer une autre valeur avec une clé dédiée (dans le plafond `Config.RateLimit.MaxPerAction`).
5. **Anti double clic** : chaque action qui écrit envoie un `actionId` (UUID v4 généré côté NUI). Le serveur garde les `actionId` traités 10 min en mémoire (règle de la base) ; un `actionId` déjà vu renvoie le résultat déjà obtenu sans rien refaire. Le bouton passe en état « en cours » (grisé + roue) jusqu'à la réponse.
6. **Nettoyage des textes** : tout texte joueur est passé dans `Sanitize.text(text, max, multiline)` de la base (BASE-MOT-12) côté serveur : suppression des balises `<...>`, des caractères de contrôle, espaces en trop retirés ; au-delà de la longueur max, refus `trop_long` (la NUI empêche de taper au-delà). L'affichage NUI utilise toujours `textContent`, jamais `innerHTML`.
7. **Pagination** : 20 éléments par page (`Config.Limits.PageSize = 20`), boutons « Précédent » / « Suivant ». Recherche côté serveur, déclenchée 300 ms après la dernière frappe, minimum 2 caractères.
8. **Textes d'erreur communs** : référentiel unique de la fiche 01 (§0 « Codes d'erreur communs », repris dans `00-sommaire.md`) : `commun.erreur.trop_vite`, `serveur`, `pas_droit` (+ bulle `commun.droit.grade_requis`), `hors_service`, `trop_loin`, `hors_ligne`, `champ_requis`, `trop_long`, `image`, `jeton_expire` ; `commun.chargement.long`, `commun.succes.enregistre`. Clé propre à ce fichier : `commun.duree` « {h} h {m} min ».
9. **Notifications** : passent par le système de notification de la base (`Notify(identifier, app, titre, texte)`), envoyées seulement aux joueurs connectés qui ont l'objet tablette (`Bridge.HasItem(src, Config.Item.Name = 'pop_tablet')`). Les autres les retrouvent dans la liste des notifications à la prochaine ouverture (gardées 7 jours).
10. **Fenêtre simple** (joueur sans tablette) : composant NUI de la base `SimplePrompt` (titre, lignes, boutons). Délai de réponse 60 s, sans réponse = refus.
11. **Journal admin** : `AdminLog(categorie, auteur, action, avant, apres)` de la base ; envoyé sur Discord si le webhook est réglé côté serveur. Toute requête refusée pour droit/distance/montant falsifié est enregistrée en catégorie `triche`.
12. **Tables** : préfixe `pop_tablet_`, moteur InnoDB, `utf8mb4`. Toute date est en `DATETIME` à l'heure du serveur (pas UTC), affichée au format « 24/11/2026 18:05 ».
13. **Montants** : entiers en dollars (`INT UNSIGNED`), affichés « 1 250 $ ».
14. **Mort / inconscient** : `Bridge.IsDead(src)` (ESX : statebag `isDead` d'esx_ambulancejob si présent ; QBCore : `metadata.isdead` ou `inlaststand` ; Qbox : `metadata.isdead` ou `inlaststand` de qbx_medical ; sinon santé du ped côté serveur `GetEntityHealth(GetPlayerPed(src)) <= 100`). Chute détectée par `Bridge.OnPlayerDeath` et réveil par `Bridge.OnPlayerRevived` (BASE-MOT-02), sans boucle : ESX `esx:onPlayerDeath` / `esx:onPlayerSpawn` et `esx_ambulancejob:revive` ; QBCore `hospital:server:SetDeathStatus` / `SetLaststandStatus` et changement de `metadata.isdead` / `inlaststand` ; Qbox state bag `isDead` et changement de `metadata.isdead` / `inlaststand` (qbx_medical). Dans les fiches, « événement de réveil » = `Bridge.OnPlayerRevived`.
15. **Jetons de cible** : le NUI ne reçoit jamais l'`identifier` brut d'un autre joueur ; il reçoit un jeton (`targetToken` / `recordToken` / `citizenToken`) valable 10 min, que le serveur retraduit. Un jeton expiré renvoie « Fiche expirée. Relancez la recherche. » (`commun.erreur.jeton_expire`).

---

# EMS

### [MET-EMS-01] Prendre et quitter son service EMS
- **But** : indiquer qu'on est en service pour recevoir les alertes et utiliser l'app EMS.
- **Qui** : tout membre d'un job de `Config.EMS.Jobs`, dès Recrue. Non réglable.
- **Où** : app EMS > en-tête > bouton « Prendre mon service » / « Quitter mon service ».
- **Parcours** :
  1. Le joueur ouvre l'app EMS hors service : seul le bouton « Prendre mon service » est actif, le reste est grisé.
  2. Clic → NUI envoie l'action `gestion.service.prendre { actionId }` de la fiche ENT-GES-01 (fichier 02) : **une seule implémentation du service pour toute la tablette**.
  3. Serveur (ENT-GES-01) : vérifie le job, le droit `service`, la fréquence, qu'il n'a pas déjà une session ouverte ; insère une ligne dans `pop_tablet_ent_services` ; `SetDuty(source, true)` (state bag `popDuty` = id de l'entreprise). Le métier ESX n'est **jamais** basculé (pas de job `offambulance`) : ESX continue de verser le salaire, la tablette ne paie rien.
  4. Serveur : met à jour l'annuaire (« Services médicaux » « Ouvert » dès qu'un EMS est en service), le dispatch et la présence du Planning (signal `pop_tablet:dutyChanged`).
  5. NUI : bandeau succès, l'app se débloque, la liste des alertes en cours se charge.
  6. Quitter : même bouton, confirmation « Quitter le service ? » (Oui / Non) → action `gestion.service.quitter` (ENT-GES-02) ; le serveur ferme la session et calcule la durée, met à jour annuaire / dispatch.
  7. Fin automatique : déconnexion, changement de job, arrêt de la ressource → ENT-GES-03 (raisons `deconnexion`, `changement_metier`, `arret`, `interrompu`).
- **Données** : table `pop_tablet_ent_services` définie par ENT-GES-01 (colonnes `company_id`, `identifier`, `nom`, `grade`, `debut`, `fin`, `duree`, `raison_fin`, `force_par`, dates en `INT UNSIGNED`). Aucune table de service propre à l'EMS.
- **Règles serveur** : celles d'ENT-GES-01 à 03 : job dans `Config.EMS.Jobs` ; une seule session ouverte par joueur ; fréquence 1 bascule / 10 s (`Config.Service.Frequence = 10`) ; à l'arrêt propre de la ressource les sessions sont fermées à l'heure réelle ; au démarrage, toute session restée ouverte (crash) est fermée « Interrompu » à 0 min (pas d'heures fantômes).
- **Textes et états** :
  - Hors service : « Hors service. » (`ems.service.hors`) + bouton « Prendre mon service » (`ems.service.prendre`).
  - Succès prise : « En service. » (`ems.service.succes_prise`).
  - Succès fin : « Service terminé : {duree}. » (`ems.service.succes_fin`), durée au format `commun.duree`.
  - Confirmation : « Quitter le service ? » (`ems.service.confirmer_fin`).
  - Erreur fréquence : `commun.erreur.trop_vite`. Pas le droit (job non EMS) : l'app n'apparaît pas sur l'accueil.
- **Notifications** : aucune par défaut. Si `Config.EMS.NotifyColleagues = true`, les EMS en service reçoivent « {nom} a pris son service. » (`ems.notif.collegue_prise`).
- **Liens** : Annuaire (ouvert/fermé), Dispatch, Planning (présence), Heures de service (MET-EMS-14). Signal API serveur émis (par ENT-GES-01) : `pop_tablet:dutyChanged(source, { identifier, companyId, job, onDuty })`.
- **Réglages** : `Config.EMS.Jobs = { 'ambulance' }`, `Config.EMS.NotifyColleagues = false` ; fréquence et durée max : `Config.Service.*` (fichier 02).
- **Journal admin** : oui, catégorie `service` : prise et fin (identifier, job, durée). Pas d'envoi Discord par défaut (`Config.Discord.Categories.service = false`).
- **Performance** : aucune boucle ; écriture d'une ligne par bascule ; liste des EMS en service gardée en mémoire serveur (table Lua `OnDuty[job]`), mise à jour sur événement.
- **Cas limites** :
  - Déconnexion en service → ENT-GES-03 ferme la session, raison `deconnexion`.
  - Double clic → `actionId` identique ignoré, une seule session.
  - Métier changé par un admin pendant le service → `Bridge.OnJobChange` (ESX `esx:setJob`, QBCore / Qbox `QBCore:Server:OnJobUpdate`) ferme la session, raison `changement_metier`, l'app repasse hors service si ouverte.
  - Joueur dont le serveur utilise des jobs `off…` (autre script) → la tablette ne les gère pas : seul le job listé dans `Config.EMS.Jobs` ouvre l'app.
- **Critères d'acceptation** :
  - Étant donné un EMS hors service, quand il clique « Prendre mon service », alors une session s'ouvre, l'app se débloque et « Services médicaux » passe « Ouvert » dans l'annuaire.
  - Étant donné un EMS en service, quand il se déconnecte, alors sa session est fermée avec la durée exacte et la raison `deconnexion`.
  - Étant donné un joueur mécano, quand il envoie à la main une prise de service EMS, alors le serveur refuse, rien n'est écrit et la tentative est journalisée (`triche`).

### [MET-EMS-02] Voir les effectifs EMS
- **But** : savoir qui est en service et sur quel appel.
- **Qui** : EMS en service, dès Recrue. Non réglable.
- **Où** : app EMS > onglet « Effectifs ».
- **Parcours** :
  1. Ouverture de l'onglet → `ems:staff:list`.
  2. Serveur renvoie la liste en mémoire `OnDuty['ambulance']` : nom, grade, heure de prise, statut (« Disponible » ou « Sur appel n°{id} »).
  3. NUI affiche la liste triée par grade décroissant puis nom ; compteur « {n} en service » en haut.
  4. Mise à jour en direct uniquement tant que l'onglet est ouvert : le serveur pousse `ems:staff:update` aux joueurs abonnés (abonnement à l'ouverture de l'onglet, désabonnement à la fermeture de l'onglet ou de la tablette).
- **Données** (affichées, rien de stocké en plus) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | nom | texte | oui | 64 car. | |
  | grade_label | texte | oui | | |
  | depuis | heure | oui | « depuis 14:05 » | |
  | statut | 'dispo' / 'appel' | oui | | 'dispo' |
  | appel_id | INT | non | | NULL |
- **Règles serveur** : demandeur EMS en service ; fréquence 1 / 2 s ; les abonnés sont retirés à `playerDropped` et à la fermeture de la tablette.
- **Textes et états** :
  - Vide (cas d'erreur seulement, le demandeur étant lui-même en service) : « Personne n'est en service. » (`ems.effectifs.vide`).
  - Titre : « {n} en service » (`ems.effectifs.compteur`).
  - Statuts : « Disponible » (`ems.effectifs.dispo`), « Sur appel n°{id} » (`ems.effectifs.sur_appel`).
  - Hors service : `commun.erreur.hors_service`.
- **Notifications** : aucune.
- **Liens** : MET-EMS-01 (prise/fin), MET-EMS-04 (statut sur appel).
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : lecture mémoire uniquement, aucune requête SQL ; pagination 20 au-delà de 20 lignes.
- **Cas limites** :
  - Un collègue se déconnecte → disparaît de la liste en direct.
  - Plus de 20 EMS en service → pagination.
  - Tablette fermée avec l'onglet ouvert → désabonnement, aucun envoi ensuite.
- **Critères d'acceptation** :
  - Étant donné 3 EMS en service, quand j'ouvre « Effectifs », alors je vois 3 lignes avec leur grade et l'heure de prise.
  - Étant donné l'onglet ouvert, quand un collègue accepte un appel, alors sa ligne affiche « Sur appel n°{id} » sans recharger.
  - Étant donné un civil, quand il envoie `ems:staff:list`, alors le serveur renvoie un refus et aucune donnée.

### [MET-EMS-03] Recevoir les alertes « joueur à terre »
- **But** : prévenir les EMS en service dès qu'un joueur tombe inconscient, avec sa position.
- **Qui** : création automatique pour tout joueur ; réception par les EMS en service dès Recrue.
- **Où** : automatique (événement de mort) ; affichage dans app EMS > onglet « Appels » + notification.
- **Parcours** :
  1. Détection : le serveur s'abonne une fois au démarrage à `Bridge.OnPlayerDeath(cb)` (BASE-MOT-02), qui couvre ESX (`esx:onPlayerDeath`), QBCore (`hospital:server:SetDeathStatus`, `SetLaststandStatus`, changement de `metadata.isdead` / `inlaststand`) et Qbox (state bag `isDead`, changement de `metadata.isdead` / `inlaststand`), sans boucle. Le client n'envoie plus d'événement propre à l'EMS : l'ancien `ems:alert:down` est remplacé par ce rappel serveur.
  2. Serveur (dans le `cb`) : vérifie `Bridge.IsDead(src)` (ignore sinon), qu'aucune alerte active n'existe déjà pour cette victime, prend la position côté serveur `GetEntityCoords(GetPlayerPed(src))` (aucune coordonnée du client n'est acceptée). Le nom de rue est calculé à l'affichage par le client de l'EMS (`GetStreetNameAtCoord`).
  3. Serveur : crée l'alerte (statut `ouverte`), l'ajoute au cache mémoire des alertes actives, notifie les EMS en service qui ont la tablette.
  4. Autres sources : un script tiers peut créer une alerte via l'export serveur `exports.pop_tablet:CreateEmsAlert({ coords, label })` (raccourci de `DispatchAlert` de la base, BASE-API-10, avec `service = 'ems'`) ; les scripts écrits pour ps-dispatch, cd_dispatch ou core_dispatch (ex. `InjuriedPerson`, `DeceasedPerson`, alertes avec `jobs = { 'ems' }`) arrivent par les adaptateurs de compatibilité de la base (BASE-API-11, `Config.Dispatch.Compat`), type `externe` ; sans adaptateur, les alertes automatiques « joueur à terre » et `/secours` fonctionnent seules ; la commande joueur `/secours` (`Config.EMS.HelpCommand = 'secours'`) crée une alerte « Demande de secours » à la position du joueur vivant, 1 fois / 120 s.
  5. Fin automatique : réveil de la victime (`Bridge.OnPlayerRevived`) → statut `terminee` (raison `reveil`) ; déconnexion → `terminee` (raison `deconnexion`) ; 15 min sans prise en charge → `expiree`.
- **Données** (`pop_tablet_ems_alerts`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT AUTO_INCREMENT | oui | | |
  | type | ENUM('a_terre','secours','externe') | oui | | 'a_terre' |
  | victim_identifier | VARCHAR(64) | non | NULL si externe | |
  | label | VARCHAR(80) | oui | nettoyé | « Personne à terre » |
  | x, y, z | FLOAT | oui | | |
  | status | ENUM('ouverte','prise','terminee','expiree') | oui | | 'ouverte' |
  | taken_by | VARCHAR(64) | non | | NULL |
  | created_at | DATETIME | oui | | NOW() |
  | closed_at | DATETIME | non | | NULL |
  | close_reason | VARCHAR(32) | non | | NULL |
- **Règles serveur** : victime réellement morte ou à terre pour `a_terre` (`Bridge.IsDead`) ; 1 alerte active max par victime ; 1 alerte `a_terre` / 30 s par victime ; `/secours` 1 / 120 s ; export limité à 1 alerte / 5 s par ressource appelante ; l'expiration à 15 min utilise un `SetTimeout` unique posé à la création (sans effet si l'alerte a changé de statut entre-temps), pas de boucle.
- **Textes et états** :
  - Vide : « Aucun appel en cours. Tout est calme. » (`ems.appels.vide`).
  - Libellés : « Personne à terre » (`ems.appels.type_a_terre`), « Demande de secours » (`ems.appels.type_secours`).
  - Ligne : « {type} · {rue} · il y a {minutes} min » (`ems.appels.ligne`).
  - Retour `/secours` : « Les secours ont été prévenus. » (`ems.secours.envoye`) ; si aucun EMS en service : « Aucun secours disponible pour le moment. » (`ems.secours.personne`).
  - Hors service : `commun.erreur.hors_service`.
- **Notifications** : EMS en service : titre « Appel d'urgence » (`ems.notif.alerte_titre`), texte « {type} · {rue} » (`ems.notif.alerte_texte`), son court de la base.
- **Liens** : Dispatch (l'alerte y apparaît aussi si le module dispatch commun est actif), signal API émis `pop_tablet:emsAlert (alertId, type, coords)`.
- **Réglages** : `Config.EMS.Alerts.Enabled = true`, `Config.EMS.Alerts.ExpireMinutes = 15`, `Config.EMS.HelpCommand = 'secours'` (`false` pour désactiver), `Config.EMS.Alerts.HelpCooldown = 120`.
- **Journal admin** : non (volume trop grand) ; refus pour triche seulement (`triche`).
- **Performance** : aucune boucle côté victime ni EMS ; alertes actives en mémoire serveur ; écriture SQL à la création et à la fermeture uniquement ; l'onglet « Appels » charge les alertes actives (mémoire) puis l'historique du jour paginé à la demande (« Voir l'historique », `ems.appels.historique`).
- **Cas limites** :
  - Victime réanimée avant toute prise en charge → alerte `terminee`, disparaît des listes en direct.
  - Aucun EMS en service → alerte créée quand même (visible au prochain qui prend son service si elle est encore active).
  - Client tricheur envoie `pop_tablet:bridge:died` vivant → `Bridge.IsDead` faux, aucune alerte, journalisé `triche`.
  - Victime « meurt » deux fois sans réveil (double événement) → une seule alerte.
- **Critères d'acceptation** :
  - Étant donné 2 EMS en service avec tablette, quand un joueur meurt, alors les deux reçoivent la notification et l'alerte apparaît dans « Appels » avec la rue.
  - Étant donné une alerte ouverte, quand la victime est réanimée, alors l'alerte passe `terminee` et disparaît des listes.
  - Étant donné un joueur vivant, quand il envoie `pop_tablet:bridge:died` à la main, alors aucune alerte n'est créée.
  - Étant donné un serveur QBCore et un joueur qui passe en « dernier souffle » (`inlaststand = true`), quand l'état change, alors les EMS en service reçoivent l'alerte une seule fois.

### [MET-EMS-04] Prendre en charge un appel (accepter, GPS, clôturer)
- **But** : s'attribuer un appel, obtenir le GPS et le clôturer.
- **Qui** : EMS en service dès Recrue.
- **Où** : app EMS > onglet « Appels » > ligne d'appel > boutons « Prendre l'appel », « GPS », « Terminer ».
- **Parcours** :
  1. Clic « Prendre l'appel » → `ems:alert:take { alertId, actionId }`.
  2. Serveur : alerte `ouverte` ou déjà `prise` (renfort autorisé) ; si `ouverte` → `prise`, `taken_by` = joueur ; ajoute le joueur aux intervenants de l'alerte (mémoire, max 6).
  3. Serveur renvoie les coordonnées ; le client pose le point GPS (`SetNewWaypoint`) ; le bouton « GPS » permet de le reposer.
  4. Les autres EMS voient « Pris par {nom} » et un bouton « Rejoindre » (même action, ajoute un renfort).
  5. La victime (si `a_terre`) reçoit « Un secouriste arrive. » (notification si tablette, sinon texte d'aide à l'écran 5 s via la base).
  6. « Terminer » → `ems:alert:close { alertId, actionId }` ; serveur passe `terminee`, raison `traitee`, propose d'ouvrir le Rapport d'intervention pré-rempli (MET-EMS-07).
- **Données** : champs `status`, `taken_by` de MET-EMS-03 ; intervenants en mémoire (`identifier[]`, max 6), copiés dans le rapport.
- **Règles serveur** : alerte existe et n'est pas `terminee`/`expiree` ; un EMS n'a qu'un appel en cours à la fois (prendre un nouvel appel le retire du précédent) ; seul un intervenant de l'appel ou un Chef+ peut « Terminer » ; fréquence 1 / 2 s.
- **Textes et états** :
  - Succès prise : « Appel pris. Point GPS posé. » (`ems.appels.succes_prise`).
  - Pris par un autre : « Pris par {nom} » (`ems.appels.pris_par`), bouton « Rejoindre » (`ems.appels.rejoindre`).
  - Erreur appel fini : « Cet appel est déjà terminé. » (`ems.appels.deja_termine`).
  - Erreur pas intervenant : « Seuls les secouristes de cet appel peuvent le terminer. » (`ems.appels.pas_intervenant`).
  - Succès fin : « Appel terminé. Rédiger le rapport ? » (`ems.appels.succes_fin`), boutons « Rédiger » (`ems.appels.rediger`) / « Plus tard » (`ems.appels.plus_tard`).
- **Notifications** : victime : « Un secouriste arrive. » (`ems.notif.secours_arrive`).
- **Liens** : MET-EMS-02 (statut sur appel), MET-EMS-07 (rapport pré-rempli : lieu, heure, patient, intervenants), Dispatch.
- **Réglages** : `Config.EMS.Alerts.MaxResponders = 6`.
- **Journal admin** : non.
- **Performance** : mémoire uniquement ; une écriture SQL à la prise et une à la fin.
- **Cas limites** :
  - Deux EMS cliquent « Prendre » en même temps → le premier traité devient `taken_by`, le second est ajouté comme renfort (pas d'erreur).
  - Victime se déconnecte pendant le trajet → alerte `terminee` raison `deconnexion`, les intervenants reçoivent « Le patient a quitté la ville. » (`ems.notif.patient_parti`) et le GPS est retiré.
  - EMS quitte son service avec un appel pris → retiré des intervenants ; s'il était seul, l'alerte repasse `ouverte` avec un nouveau délai d'expiration de 15 min.
- **Critères d'acceptation** :
  - Étant donné une alerte ouverte, quand je clique « Prendre l'appel », alors un point GPS est posé sur la position et les collègues voient « Pris par {mon nom} ».
  - Étant donné un appel pris, quand je clique « Terminer », alors l'appel disparaît des appels en cours et le rapport pré-rempli est proposé.
  - Étant donné un EMS hors service, quand il envoie `ems:alert:take`, alors le serveur refuse.

### [MET-EMS-05] Consulter le dossier médical d'un patient
- **But** : retrouver les informations médicales d'un citoyen (privées EMS).
- **Qui** : EMS en service dès Recrue (« EMS : lire dossier médical »), réglable par le patron (droit `ems.record.read`). Ni la police ni le patient n'y ont accès ; l'admin oui.
- **Où** : app EMS > onglet « Dossiers » > recherche ; ou bouton « Dossier » sur un appel ; ou « Patient proche ».
- **Parcours** :
  1. Recherche par nom (min 2 caractères) → `ems:record:search { q, page }` ; ou bouton « Patient proche » → serveur liste les joueurs à moins de 3 m (nom seulement).
  2. Serveur renvoie 20 résultats max : nom, date de naissance, groupe sanguin, et un `recordToken` par ligne.
  3. Clic sur un résultat → `ems:record:get { recordToken }` : fiche complète (infos fixes + 20 dernières interventions, pagination + certificats).
  4. Si aucun dossier n'existe, le serveur renvoie la fiche vide avec le bouton « Créer le dossier » (création = MET-EMS-06).
- **Données** (`pop_tablet_ems_records`, une ligne par citoyen) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | identifier | VARCHAR(64) PK | oui | | |
  | blood_type | ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-','inconnu') | oui | | 'inconnu' |
  | allergies | VARCHAR(500) | non | nettoyé | '' |
  | history | TEXT | non | 2 000 car., nettoyé (antécédents) | '' |
  | treatments | VARCHAR(500) | non | traitements en cours | '' |
  | emergency_contact | VARCHAR(80) | non | | '' |
  | updated_by | VARCHAR(64) | oui | | |
  | updated_at | DATETIME | oui | | NOW() |
  Interventions affichées = rapports MET-EMS-07 du patient (date, motif, auteur, résumé 120 car.).
- **Règles serveur** : demandeur EMS en service avec `ems.record.read` ; fréquence recherche 1 / 1 s ; jetons (Conventions §15).
- **Textes et états** :
  - Vide (aucune recherche) : « Rechercher un patient par son nom. » (`ems.dossiers.vide`).
  - Aucun résultat : « Aucun patient trouvé pour « {q} ». » (`ems.dossiers.aucun_resultat`).
  - Pas de dossier : « Aucun dossier médical pour {nom}. » + « Créer le dossier » (`ems.dossiers.pas_de_dossier`, `ems.dossiers.creer`).
  - Personne à moins de 3 m : « Personne à proximité. » (`ems.dossiers.personne_proche`).
  - Pas le droit : onglet grisé « Grade requis : {grade} » (`commun.droit.grade_requis`).
- **Notifications** : aucune.
- **Liens** : MET-EMS-07 (interventions), MET-EMS-11/12 (certificats affichés en bas de fiche).
- **Réglages** : aucun (la confidentialité EMS est fixe ; seule l'option certificats expose des informations à la police).
- **Journal admin** : oui, catégorie `ems_dossier` : chaque ouverture de fiche (qui, quel patient), gardée 30 jours, pas d'envoi Discord.
- **Performance** : requête paginée avec index sur nom/prénom de la table des personnages ; pas de cache (données privées, peu lues).
- **Cas limites** :
  - Patient déconnecté → la fiche reste consultable.
  - Homonymes → la date de naissance départage dans la liste.
  - Jeton expiré → `commun.erreur.jeton_expire`.
- **Critères d'acceptation** :
  - Étant donné un EMS en service, quand il cherche « Dup », alors il voit au plus 20 citoyens dont le nom contient « Dup ».
  - Étant donné un patient sans dossier, quand j'ouvre sa fiche, alors je vois « Aucun dossier médical » et le bouton « Créer le dossier ».
  - Étant donné un policier, quand il envoie `ems:record:get`, alors le serveur refuse et journalise `triche`.

### [MET-EMS-06] Créer ou modifier le dossier médical
- **But** : renseigner groupe sanguin, allergies, antécédents, traitements, contact d'urgence.
- **Qui** : EMS en service dès Membre (droit `ems.record.write`, réglable par le patron).
- **Où** : app EMS > fiche patient > bouton « Créer le dossier » ou « Modifier ».
- **Parcours** :
  1. Clic → formulaire pré-rempli (champs de MET-EMS-05).
  2. « Enregistrer » → `ems:record:save { recordToken, fields, updatedAt, actionId }`.
  3. Serveur : droit, nettoyage, longueurs ; insère ou met à jour ; garde l'ancienne version dans `pop_tablet_ems_records_history`.
  4. NUI : bandeau « Enregistré. », retour à la fiche.
- **Données** : celles de MET-EMS-05 ; historique `pop_tablet_ems_records_history (id, identifier, snapshot JSON, changed_by, changed_at, archived BOOL)` : les 20 dernières versions sont affichables par un Chef+ (« Historique »), les plus anciennes passent `archived = 1` (visibles admin), jamais supprimées.
- **Règles serveur** : droit `ems.record.write` ; groupe sanguin dans la liste ; allergies ≤ 500, antécédents ≤ 2 000, traitements ≤ 500, contact ≤ 80 ; fréquence 1 / 3 s ; si `updatedAt` envoyé ≠ `updated_at` en base (un collègue a modifié entre-temps), refus.
- **Textes et états** :
  - Succès : `commun.succes.enregistre`.
  - Conflit : « Dossier modifié par un collègue. Rechargez la fiche. » (`ems.dossiers.conflit`).
  - Trop long : `commun.erreur.trop_long`.
  - Pas le droit : bouton « Modifier » grisé « Grade requis : {grade} ».
- **Notifications** : aucune.
- **Liens** : aucun autre.
- **Réglages** : `Config.EMS.Records.MaxHistory = 20`.
- **Journal admin** : oui, `ems_dossier` : modification (qui, patient, champs changés avant/après).
- **Performance** : une écriture par enregistrement.
- **Cas limites** :
  - Double clic → `actionId`, une seule version.
  - Texte avec `<script>` → balises retirées, enregistré propre.
  - Citoyen supprimé de la base ESX → refus « Ce citoyen n'existe plus. » (`ems.dossiers.introuvable`).
- **Critères d'acceptation** :
  - Étant donné un Membre EMS, quand il saisit « O- » et « Pénicilline », alors la fiche affiche ces valeurs après enregistrement.
  - Étant donné deux EMS sur la même fiche, quand le second enregistre après le premier, alors il reçoit le message de conflit.
  - Étant donné une Recrue (droit refusé), quand elle envoie `ems:record:save`, alors le serveur refuse.

### [MET-EMS-07] Rédiger un rapport d'intervention
- **But** : tracer une intervention médicale ; elle apparaît dans le dossier du patient.
- **Qui** : EMS en service dès Recrue.
- **Où** : app EMS > onglet « Rapports » > « Nouveau rapport » ; ou après « Terminer » un appel.
- **Parcours** :
  1. Formulaire construit d'après le modèle actif (MET-EMS-08) ; champs fixes en haut : patient (recherche, « Patient proche » ou « Inconnu »), date/heure (pré-remplie), lieu (rue, pré-remplie depuis l'appel), intervenants (pré-remplis, modifiables parmi les EMS de l'entreprise), appel lié.
  2. Photos : bouton « Ajouter une photo » ouvre la Galerie (max 5 images, domaines autorisés).
  3. « Enregistrer » → `ems:report:create { fields, templateVersion, actionId }`.
  4. Serveur : contrôle chaque champ selon le modèle, nettoie, enregistre avec la version du modèle utilisée.
  5. Le rapport apparaît dans la fiche patient (MET-EMS-05) et dans la liste des rapports.
  6. Modification : l'auteur peut modifier pendant 30 min ; ensuite seul un Chef+ peut ajouter un « Complément » (texte ajouté, l'original ne change pas).
- **Données** (`pop_tablet_ems_reports`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT AUTO_INCREMENT | oui | | |
  | company_id | INT | oui | | |
  | patient_identifier | VARCHAR(64) | non | NULL = inconnu | |
  | alert_id | INT | non | | NULL |
  | author | VARCHAR(64) | oui | | |
  | responders | JSON | oui | 1 à 6 identifiers | [auteur] |
  | location | VARCHAR(80) | oui | nettoyé | rue |
  | occurred_at | DATETIME | oui | entre maintenant − 7 j et maintenant | NOW() |
  | template_version | INT | oui | | |
  | fields | JSON | oui | valeurs du modèle | |
  | summary | VARCHAR(120) | oui | 1er champ texte long coupé à 120 | |
  | images | JSON | non | 5 URL max | [] |
  | addenda | JSON | non | 10 compléments max, 1 000 car. chacun | [] |
  | archived | BOOL | oui | | 0 |
  | created_at | DATETIME | oui | | NOW() |
- **Règles serveur** : champs obligatoires du modèle présents ; types respectés (texte ≤ longueur du champ, liste = valeur parmi les choix, nombre dans les bornes, case = booléen) ; images sur domaines autorisés ; intervenants = EMS de l'entreprise ; fréquence 1 / 5 s ; modification par l'auteur seulement si `created_at` > maintenant − 30 min.
- **Textes et états** :
  - Vide : « Aucun rapport pour l'instant. » + « Nouveau rapport » (`ems.rapports.vide`, `ems.rapports.nouveau`).
  - Succès : « Rapport n°{id} enregistré. » (`ems.rapports.succes`).
  - Champ requis : `commun.erreur.champ_requis`. Image refusée : `commun.erreur.image`.
  - Modif expirée : « Délai de modification dépassé. Ajoutez un complément. » (`ems.rapports.modif_expiree`).
  - Archiver (Chef+) : bouton « Archiver » (`ems.rapports.archiver`), confirmation « Archiver ce rapport ? Il restera visible par l'admin. » (`ems.rapports.confirmer_archive`).
- **Notifications** : aucune.
- **Liens** : MET-EMS-05 (affiché dans le dossier), MET-EMS-04 (pré-remplissage), Galerie, MET-EMS-14 (compte des interventions par EMS).
- **Réglages** : `Config.EMS.Reports.EditMinutes = 30`, `Config.EMS.Reports.MaxImages = 5`.
- **Journal admin** : oui, `ems_rapport` : création, modification, complément, archivage (avant/après).
- **Performance** : liste paginée 20 (id, date, patient, auteur, résumé) ; détail chargé au clic ; modèle actif en cache serveur.
- **Cas limites** :
  - Le patron change le modèle pendant qu'un EMS rédige → enregistrement validé sur la version reçue par le formulaire (`templateVersion`), acceptée si cette version a été remplacée depuis moins de 1 h.
  - Patient inconnu → rapport enregistré sans patient, lié plus tard par un Chef+ (« Lier un patient », `ems.rapports.lier_patient`).
  - Double clic → un seul rapport.
- **Critères d'acceptation** :
  - Étant donné un appel terminé, quand je clique « Rédiger », alors le lieu, l'heure et les intervenants sont pré-remplis.
  - Étant donné un rapport enregistré pour un patient, quand j'ouvre son dossier, alors l'intervention apparaît en tête avec son résumé.
  - Étant donné un rapport vieux de 2 h, quand son auteur envoie une modification à la main, alors le serveur refuse.

### [MET-EMS-08] Régler le modèle de rapport d'intervention
- **But** : laisser le patron choisir les champs du rapport.
- **Qui** : Patron EMS (droit `ems.template.edit`, réglable).
- **Où** : app EMS > onglet « Réglages » > « Modèle de rapport ».
- **Parcours** :
  1. Liste des champs du modèle actif, ordre modifiable par glisser-déposer ou flèches haut/bas.
  2. « Ajouter un champ » : libellé, type (texte court, texte long, liste, nombre, case à cocher), obligatoire oui/non, choix (pour liste), bornes (pour nombre).
  3. « Enregistrer » → `ems:template:save { fields, actionId }` ; serveur crée une nouvelle version (l'ancienne est gardée, les anciens rapports restent lisibles avec leur version).
  4. « Revenir au modèle par défaut » remet le modèle livré (nouvelle version).
- **Données** (`pop_tablet_report_templates`, commune aux métiers) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | company_id | INT | oui | | |
  | kind | VARCHAR(16) | oui | 'ems' | |
  | version | INT | oui | +1 à chaque enregistrement | 1 |
  | fields | JSON | oui | 1 à 20 champs | modèle par défaut |
  | created_by / created_at | VARCHAR(64) / DATETIME | oui | | |
  Champ : `key` (généré, stable), `label` (≤ 40), `type`, `required`, `options` (2 à 15 choix ≤ 30 car.), `min`/`max`, `maxLength` (texte court 120, texte long 2 000).
  Modèle par défaut : « Motif de l'appel » (liste : Malaise, Accident de la route, Blessure par arme, Chute, Overdose, Autre ; obligatoire) · « Constat » (texte long, obligatoire) · « Soins effectués » (texte long, obligatoire) · « Transport à l'hôpital » (case) · « État à la sortie » (liste : Stable, Grave, Décédé ; obligatoire).
- **Règles serveur** : droit ; 1 à 20 champs ; libellés uniques ; nettoyage ; fréquence 1 / 10 s.
- **Textes et états** :
  - Succès : « Modèle enregistré (version {v}). » (`ems.modele.succes`).
  - Aucun champ : « Le modèle doit avoir au moins un champ. » (`ems.modele.vide`).
  - Trop de champs : « 20 champs maximum. » (`ems.modele.trop`).
  - Libellé en double : « Deux champs ont le même nom. » (`ems.modele.doublon`).
  - Pas le droit : onglet « Réglages » caché.
- **Notifications** : aucune.
- **Liens** : MET-EMS-07.
- **Réglages** : `Config.EMS.Reports.DefaultTemplate = { ... }` (modèle ci-dessus, fichier ouvert).
- **Journal admin** : oui, `ems_modele` : nouvelle version (avant/après).
- **Performance** : modèle actif en cache serveur, invalidé à l'enregistrement.
- **Cas limites** : suppression d'un champ utilisé par d'anciens rapports → les anciens rapports l'affichent toujours (lus avec leur version) ; modèle vide → refusé ; deux patrons enregistrent en même temps → deux versions successives, la dernière est active.
- **Critères d'acceptation** :
  - Étant donné le patron, quand il ajoute la liste « Gravité » et enregistre, alors le prochain rapport affiche ce champ.
  - Étant donné un rapport ancien, quand le modèle change, alors il s'affiche toujours avec ses champs d'origine.
  - Étant donné un Chef, quand il envoie `ems:template:save`, alors le serveur refuse.

### [MET-EMS-09] Facturer des soins
- **But** : faire payer des soins à un patient ; si le patient est inconscient, la facture attend son réveil.
- **Qui** : EMS en service ; Recrue plafonnée (`Config.EMS.Invoices.RecruitMax = 500`), Membre+ jusqu'au maximum.
- **Où** : app EMS > fiche patient ou appel > bouton « Facturer des soins ».
- **Parcours** :
  1. Choix du patient : joueurs à moins de 3 m (liste des noms) ; le patient de l'appel en cours est proposé en premier.
  2. Sélection des actes dans la grille de tarifs (MET-EMS-10), quantités (1 à 10) ; total calculé côté NUI à titre indicatif ; ligne libre possible (Chef+) avec libellé et montant.
  3. « Envoyer la facture » → `ems:invoice:create { targetToken, lines, actionId }`.
  4. Serveur : recalcule le total depuis la grille serveur (prix envoyés par le client ignorés), vérifie distance ≤ 3 m, plafond du grade, maximum, fréquence ; crée la facture dans l'app Factures (type `soins`, émetteur = Hôpital, auteur = EMS).
  5. Si `Bridge.IsDead(target)` → statut `attente_reveil` : rien n'est montré au patient. Au réveil du patient détecté par `Bridge.OnPlayerRevived` (BASE-MOT-02 : ESX `esx:onPlayerSpawn` ; QBCore / Qbox `metadata.isdead` et `inlaststand` repassés à `false` ou state bag `isDead` à `false` ; sans boucle), même mécanisme qu'ENT-FAC-07, le serveur passe la facture `en_attente` et la lui présente (notification tablette, ou fenêtre simple sans tablette).
  6. Sinon → `en_attente` tout de suite et présentée au patient.
  7. Le paiement et la répartition (compte Hôpital + part EMS) sont gérés par l'app Factures.
- **Données** (lignes envoyées à Factures) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | act_key | VARCHAR(32) | oui (sauf ligne libre) | doit exister et être actif dans la grille | |
  | label | VARCHAR(60) | oui | nettoyé (ligne libre) | libellé de l'acte |
  | qty | TINYINT | oui | 1 à 10 | 1 |
  | unit_price | INT | oui | prix grille ; ligne libre : 1 à 5 000 | |
  | total | INT | oui | ≤ `Config.EMS.Invoices.Max = 10000` | somme |
  | status | statuts Factures + 'attente_reveil' | oui | | |
- **Règles serveur** : EMS en service ; patient ≠ soi-même ; distance ≤ 3 m (`Config.EMS.Invoices.Distance = 3.0`) ; total ≤ plafond Recrue ou ≤ 10 000 $ ; 1 facture / 10 s par EMS ; 1 facture `attente_reveil` max par patient et par EMS (une deuxième remplace la première, l'ancienne passe `annulee`) ; une facture `attente_reveil` depuis plus de 60 min passe `annulee` à la prochaine lecture (pas de boucle) ; `actionId` obligatoire.
- **Textes et états** :
  - Vide (aucun patient proche) : « Aucun patient à moins de 3 m. » (`ems.facture.personne`).
  - Succès : « Facture envoyée : {montant}. » (`ems.facture.succes`).
  - Succès patient inconscient : « Le patient est inconscient. La facture lui sera présentée à son réveil. » (`ems.facture.attente_reveil`).
  - Plafond : « Montant trop élevé pour ce grade (maximum {max}). » (`ems.facture.plafond`).
  - Trop loin : `commun.erreur.trop_loin`.
  - Grille vide : « Aucun tarif défini. » (`ems.facture.grille_vide`).
- **Notifications** : patient : « Facture de soins · Hôpital : {montant}. » (`ems.notif.facture_patient`) ; EMS au paiement : « {nom} a payé sa facture de soins ({montant}). » (`ems.notif.facture_payee`).
- **Liens** : Factures (création, paiement, répartition), compte entreprise, signal `pop_tablet:invoicePaid` émis par Factures.
- **Réglages** : `Config.EMS.Invoices.Max = 10000`, `Config.EMS.Invoices.RecruitMax = 500`, `Config.EMS.Invoices.Distance = 3.0`, `Config.EMS.Invoices.WaitReviveMinutes = 60`, `Config.EMS.Invoices.FreeLineMinGrade = 'chef'`.
- **Journal admin** : oui, `facture` (par l'app Factures) : création, annulation, paiement.
- **Performance** : grille en cache ; une écriture par facture ; aucune boucle pour l'attente du réveil (événement).
- **Cas limites** :
  - Patient se déconnecte en `attente_reveil` → la facture reste ; à sa reconnexion vivant, elle lui est présentée si elle a moins de 60 min, sinon `annulee`.
  - Double clic → une facture.
  - Patient s'éloigne entre l'ouverture et l'envoi → refus distance.
- **Critères d'acceptation** :
  - Étant donné un patient debout à 2 m, quand j'envoie « Consultation » (150 $), alors il reçoit une facture de 150 $.
  - Étant donné un patient inconscient, quand j'envoie une facture, alors il ne voit rien ; quand il est réanimé, alors la facture lui apparaît.
  - Étant donné un client qui modifie le prix à 1 $ dans l'événement, quand la facture est créée, alors le serveur utilise le prix de la grille.

### [MET-EMS-10] Régler la grille des tarifs de soins
- **But** : fixer les actes et leurs prix utilisés par les factures de soins.
- **Qui** : Patron EMS (droit `ems.prices.edit`, réglable ; le patron peut l'ouvrir aux Chefs).
- **Où** : app EMS > « Réglages » > « Tarifs ».
- **Parcours** : liste des actes (libellé, prix, actif) ; « Ajouter un acte », modifier, désactiver ; « Enregistrer » → `ems:prices:save { acts, actionId }` ; le serveur valide et remplace la grille ; le cache est invalidé.
- **Données** (`pop_tablet_price_lists`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | company_id | INT | oui | | |
  | act_key | VARCHAR(32) | oui | généré, unique par entreprise | |
  | label | VARCHAR(60) | oui | nettoyé | |
  | price | INT | oui | 1 à `Config.EMS.Invoices.Max` | |
  | active | BOOL | oui | | 1 |
  | sort | SMALLINT | oui | | ordre de saisie |
  Grille par défaut : Consultation 150 $ · Soins légers 250 $ · Suture 400 $ · Réanimation 800 $ · Radiographie 300 $ · Opération 2 500 $ · Transport en ambulance 350 $.
- **Règles serveur** : droit ; 1 à 50 actes ; libellés uniques ; prix entier dans les bornes ; un acte n'est jamais supprimé, il est désactivé (anciennes factures lisibles) ; fréquence 1 / 10 s.
- **Textes et états** : succès « Tarifs enregistrés. » (`ems.tarifs.succes`) ; prix invalide « Le prix doit être entre 1 $ et {max}. » (`ems.tarifs.prix_invalide`) ; doublon « Cet acte existe déjà. » (`ems.tarifs.doublon`) ; vide « Aucun acte. » (`ems.tarifs.vide`) ; pas le droit : écran caché.
- **Notifications** : aucune.
- **Liens** : MET-EMS-09.
- **Réglages** : `Config.EMS.DefaultPrices = { ... }` (grille ci-dessus).
- **Journal admin** : oui, `tarifs` : avant/après.
- **Performance** : grille en cache serveur par entreprise.
- **Cas limites** : prix changé pendant qu'un EMS prépare une facture → le serveur applique le prix en vigueur à l'envoi ; acte désactivé envoyé → refus « Cet acte n'est plus proposé. » (`ems.tarifs.inactif`) ; 51e acte → refus « 50 actes maximum. » (`ems.tarifs.trop`).
- **Critères d'acceptation** :
  - Étant donné le patron, quand il passe « Consultation » à 200 $, alors la facture suivante utilise 200 $.
  - Étant donné un acte désactivé, quand on l'envoie dans une facture, alors le serveur refuse.
  - Étant donné un Membre, quand il envoie `ems:prices:save`, alors refus et journal `triche`.

### [MET-EMS-11] Délivrer un certificat d'aptitude (port d'arme, conduite)
- **But** : attester qu'un citoyen est apte au port d'arme ou à la conduite ; la police peut le lire si le serveur l'autorise.
- **Qui** : EMS en service dès Membre (droit `ems.certificate.create`, réglable).
- **Où** : app EMS > fiche patient > « Certificats » > « Nouveau certificat ».
- **Parcours** :
  1. Choix du type : « Aptitude au port d'arme » ou « Aptitude à la conduite ».
  2. Choix du résultat : « Apte » ou « Inapte » ; commentaire (≤ 300 car., privé EMS) ; validité (7, 30 ou 90 jours ; défaut 30).
  3. Le patient doit être à moins de 3 m (examen en personne).
  4. « Délivrer » → `ems:certificate:create { recordToken, type, result, days, comment, actionId }`.
  5. Serveur : droit, distance ; crée le certificat numéroté `CERT-AAAA-NNNNN` et l'ajoute au dossier ; un nouveau certificat du même type passe l'ancien `remplace`.
  6. Si `Config.EMS.Certificates.PoliceCanRead = true`, il est visible dans la fiche citoyen de l'app Police (type, résultat, date, validité, médecin ; jamais le commentaire).
  7. Si ox_inventory est présent et `Config.EMS.Certificates.GiveItem = true`, le patient reçoit l'objet `medical_certificate` avec les métadonnées (numéro, type, résultat, fin de validité).
- **Données** (`pop_tablet_ems_certificates`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | number | VARCHAR(16) | oui | unique | `CERT-AAAA-NNNNN` |
  | identifier | VARCHAR(64) | oui | | |
  | type | ENUM('arme','conduite','deces') | oui | | |
  | result | ENUM('apte','inapte','deces') | oui | | |
  | comment | VARCHAR(300) | non | nettoyé, privé EMS | '' |
  | valid_until | DATETIME | non | NULL pour décès | +30 j |
  | status | ENUM('valide','remplace','revoque') | oui | | 'valide' |
  | doctor | VARCHAR(64) | oui | | |
  | created_at | DATETIME | oui | | NOW() |
  | revoked_by / revoked_reason / revoked_at | VARCHAR(64) / VARCHAR(200) / DATETIME | non | cf. MET-EMS-13 | NULL |
  « Expiré » n'est pas stocké : calculé à la lecture (`valid_until` < maintenant).
- **Règles serveur** : droit ; distance ≤ 3 m ; type et résultat valides ; durée dans la liste ; fréquence 1 / 10 s ; un EMS ne peut pas se délivrer un certificat à lui-même.
- **Textes et états** :
  - Vide : « Aucun certificat. » (`ems.certificats.vide`).
  - Succès : « Certificat {numero} délivré. » (`ems.certificats.succes`).
  - Trop loin : `commun.erreur.trop_loin`.
  - Soi-même : « Impossible de se délivrer un certificat. » (`ems.certificats.soi_meme`).
  - Statuts affichés : « Valide jusqu'au {date} » (`ems.certificats.valide`), « Expiré » (`ems.certificats.expire`), « Remplacé » (`ems.certificats.remplace`), « Révoqué » (`ems.certificats.revoque`).
- **Notifications** : patient : « Certificat médical délivré : {type} · {resultat}. » (`ems.notif.certificat_patient`).
- **Liens** : App Police (fiche citoyen, lecture seule si autorisé), export serveur `exports.pop_tablet:GetCertificate(identifier, type)` → `{ result, validUntil, status }` (status `valide`, `expire`, `remplace`, `revoque` ou `nil`) pour les scripts d'armurerie / auto-école.
- **Réglages** : `Config.EMS.Certificates.PoliceCanRead = true`, `Config.EMS.Certificates.Durations = { 7, 30, 90 }`, `Config.EMS.Certificates.DefaultDays = 30`, `Config.EMS.Certificates.GiveItem = false`, `Config.EMS.Certificates.Item = 'medical_certificate'`.
- **Journal admin** : oui, `certificat` : création (numéro, type, résultat, médecin, patient).
- **Performance** : écrit à la création ; lu à l'ouverture de la fiche ; l'export lit en base avec index (`identifier`, `type`, `status`).
- **Cas limites** : certificat expiré → affiché « Expiré », l'export renvoie `expire` ; ox_inventory absent avec `GiveItem = true` → aucun objet, avertissement console au démarrage ; patient parti avant l'envoi → refus distance.
- **Critères d'acceptation** :
  - Étant donné un patient à 2 m, quand je délivre « Port d'arme · Apte · 30 jours », alors le certificat apparaît dans son dossier avec la date de fin.
  - Étant donné `PoliceCanRead = true`, quand un policier ouvre la fiche du citoyen, alors il voit le certificat sans le commentaire.
  - Étant donné une Recrue, quand elle envoie `ems:certificate:create`, alors le serveur refuse.

### [MET-EMS-12] Délivrer un certificat de décès
- **But** : constater officiellement la mort d'un personnage (fin de vie RP).
- **Qui** : EMS en service dès Chef (droit `ems.certificate.death`, réglable).
- **Où** : app EMS > fiche patient > « Certificats » > « Certificat de décès ».
- **Parcours** :
  1. Formulaire : cause (liste : Naturelle, Accident, Homicide, Suicide, Indéterminée), lieu (rue), date/heure, commentaire (≤ 300).
  2. Double confirmation : « Délivrer un certificat de décès pour {nom} ? Cette action prévient la police. » (`ems.deces.confirmer_titre`) puis saisie du mot « DÉCÈS ».
  3. Serveur : droit ; crée le certificat type `deces` (`valid_until` NULL), l'ajoute au dossier.
  4. Si `PoliceCanRead`, la fiche citoyen police affiche « Décédé (certificat {numero}) » (`ems.deces.police_mention`).
  5. Serveur émet le signal `pop_tablet:deathCertificate (identifier, number, cause)` ; la tablette ne supprime ni ne bloque le personnage (rôle d'un éventuel script de mort définitive).
- **Données** : celles de MET-EMS-11 avec `type = 'deces'`, `result = 'deces'` ; la cause est stockée au début de `comment` (« Cause : {cause}. »).
- **Règles serveur** : droit Chef+ ; un seul certificat de décès `valide` par citoyen ; le citoyen peut être hors ligne (pas de distance) ; mot de confirmation vérifié côté NUI et côté serveur (`confirm = 'DÉCÈS'`) ; fréquence 1 / 30 s.
- **Textes et états** : succès « Certificat de décès {numero} enregistré. » (`ems.deces.succes`) ; déjà décédé « Un certificat de décès existe déjà pour ce citoyen. » (`ems.deces.existe`) ; mot faux « Saisissez DÉCÈS pour confirmer. » (`ems.deces.confirmer`) ; pas le droit : bouton grisé « Grade requis : {grade} ».
- **Notifications** : policiers en service : « Décès constaté : {nom} ({cause}). » (`ems.notif.deces_police`) si `PoliceCanRead` et `Config.EMS.Certificates.NotifyPoliceOnDeath = true`.
- **Liens** : App Police (fiche citoyen), signal API ci-dessus.
- **Réglages** : `Config.EMS.Certificates.NotifyPoliceOnDeath = true`.
- **Journal admin** : oui, `certificat` + Discord par défaut (`Config.Discord.Categories.certificat_deces = true`).
- **Performance** : une écriture.
- **Cas limites** : erreur de saisie → révocation par MET-EMS-13 ; citoyen inconnu → refus `ems.dossiers.introuvable` ; double clic → un seul certificat (unicité + `actionId`).
- **Critères d'acceptation** :
  - Étant donné un Chef EMS, quand il confirme avec « DÉCÈS », alors le certificat est créé et le signal émis.
  - Étant donné un certificat de décès existant, quand on en crée un second, alors refus.
  - Étant donné un Membre, quand il envoie l'événement à la main, alors refus.

### [MET-EMS-13] Révoquer un certificat (ajout)
- **But** : corriger un certificat délivré par erreur sans l'effacer.
- **Qui** : Chef EMS et plus (droit `ems.certificate.revoke`).
- **Où** : app EMS > fiche patient > certificat > « Révoquer ».
- **Parcours** : motif obligatoire (10 à 200 car.) → `ems:certificate:revoke { id, reason, actionId }` → statut `revoque`, motif et auteur stockés ; la police voit « Révoqué » ; l'objet d'inventaire éventuel n'est pas retiré (impossible à garantir) mais l'export renvoie `revoque`.
- **Données** : `revoked_by`, `revoked_reason`, `revoked_at` de `pop_tablet_ems_certificates`.
- **Règles serveur** : droit ; certificat `valide` (expiré compris) ; motif 10–200 car. nettoyé ; fréquence 1 / 10 s.
- **Textes et états** : succès « Certificat révoqué. » (`ems.certificats.succes_revoque`) ; motif trop court « Raison requise (10 caractères minimum). » (`ems.certificats.motif_court`) ; déjà invalide « Ce certificat n'est plus valide. » (`ems.certificats.deja_invalide`).
- **Notifications** : patient : « Certificat {numero} révoqué. » (`ems.notif.certificat_revoque`).
- **Liens** : App Police, export `GetCertificate`.
- **Réglages** : aucun.
- **Journal admin** : oui, `certificat` : révocation (avant/après, motif).
- **Performance** : une écriture.
- **Cas limites** : certificat expiré → révocation possible ; patient hors ligne → notification à la reconnexion ; double clic → une seule révocation.
- **Critères d'acceptation** :
  - Étant donné un certificat valide, quand un Chef le révoque avec un motif, alors il passe « Révoqué » partout.
  - Étant donné un motif de 3 caractères, quand on valide, alors refus.
  - Étant donné une Recrue, quand elle envoie l'événement, alors refus.

### [MET-EMS-14] Consulter les heures de service
- **But** : voir le temps de service par semaine, pour soi et pour l'équipe.
- **Qui** : chaque EMS voit ses heures (dès Recrue) ; Chef+ voit toute l'équipe (droit `ems.hours.team`).
- **Où** : app EMS > onglet « Heures ».
- **Parcours** :
  1. Ouverture → `ems:hours:get { week }` (semaine courante par défaut, du lundi 00:00 au dimanche 23:59, heure serveur).
  2. Serveur additionne `duree` (secondes, `pop_tablet_ent_services`) des sessions fermées + la session en cours (jusqu'à maintenant).
  3. Vue perso : total de la semaine, détail par jour (barres simples), nombre d'interventions (rapports dont le joueur est intervenant).
  4. Vue équipe (Chef+) : tableau nom · grade · heures · interventions · dernière prise de service, trié par heures décroissantes ; flèches « Semaine précédente » / « Semaine suivante » (12 semaines en arrière max).
  5. Bouton « Exporter vers le Tableur » (Chef+) crée une feuille dans l'app Tableur de l'entreprise.
- **Données** (calculées depuis `pop_tablet_ent_services` et `pop_tablet_ems_reports`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | semaine | date du lundi | oui | ≤ 12 semaines en arrière | semaine courante |
  | total | durée | oui | `commun.duree` | 0 |
  | par_jour | 7 durées | oui | | |
  | interventions | INT | oui | | 0 |
- **Règles serveur** : vue équipe réservée à `ems.hours.team` ; une session à cheval sur deux semaines est coupée le lundi à 00:00 ; fréquence 1 / 2 s.
- **Textes et états** : vide « Aucune heure de service cette semaine. » (`ems.heures.vide`) ; succès export « Feuille « Heures EMS {semaine} » créée dans le Tableur. » (`ems.heures.export_succes`) ; ancien membre « Ancien » (`commun.ancien_membre`) ; pas le droit : vue équipe cachée.
- **Notifications** : aucune.
- **Liens** : Tableur (export), Planning (présence).
- **Réglages** : `Config.EMS.Hours.WeeksBack = 12`, `Config.Duty.WeekStart = 'monday'` (commun).
- **Journal admin** : oui pour l'export seulement (`heures`).
- **Performance** : une requête SQL agrégée (`GROUP BY identifier`) avec index (`company_id`, `debut`) ; résultat de la semaine courante en cache 60 s par entreprise.
- **Cas limites** : session ouverte après crash → fermée au démarrage avec 0 (MET-EMS-01) ; EMS renvoyé → apparaît pour les semaines où il a travaillé, marqué « Ancien » ; semaine sans données → texte vide.
- **Critères d'acceptation** :
  - Étant donné deux sessions de 1 h et 30 min cette semaine, quand j'ouvre « Heures », alors je vois « 1 h 30 min ».
  - Étant donné un Chef, quand il ouvre la vue équipe, alors il voit chaque EMS avec ses heures de la semaine.
  - Étant donné une Recrue, quand elle demande la vue équipe à la main, alors le serveur renvoie seulement ses propres heures.

### [MET-EMS-15] Demander un rendez-vous sur le site de l'hôpital
- **But** : permettre à un citoyen de demander un rendez-vous médical depuis le site de l'hôpital.
- **Qui** : tout joueur ayant une tablette (Navigateur).
- **Où** : app Navigateur > site de l'Hôpital > bloc « Prendre rendez-vous » (bloc livré activé sur le site par défaut de l'Hôpital).
- **Parcours** :
  1. Formulaire : motif (liste : Consultation, Certificat d'aptitude, Suivi de soins, Autre), créneau souhaité (date dans les 14 prochains jours + tranche : Matin 8 h–12 h, Après-midi 12 h–18 h, Soir 18 h–23 h, heure serveur), message (≤ 300 car.).
  2. « Envoyer » → la base crée une entrée dans la boîte « Demandes » de l'Hôpital, type `rendez_vous` (nom et identifiant du demandeur ajoutés par le serveur).
  3. Le citoyen voit le bandeau succès et suivra la réponse dans ses notifications.
- **Données** (table Demandes de la base, champ `payload` JSON) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | reason | ENUM('consultation','certificat','suivi','autre') | oui | | 'consultation' |
  | wished_date | DATE | oui | aujourd'hui à +14 j | |
  | wished_slot | ENUM('matin','apres_midi','soir') | oui | | 'apres_midi' |
  | message | VARCHAR(300) | non | nettoyé | '' |
- **Règles serveur** : 3 demandes de rendez-vous ouvertes max par citoyen et par entreprise ; 1 envoi / 60 s ; date dans la plage.
- **Textes et états** : succès « Demande envoyée. La réponse arrivera sur la tablette. » (`ems.rdv.envoye`) ; limite « 3 demandes déjà en attente. » (`ems.rdv.limite`) ; date invalide « Choisissez une date dans les 14 prochains jours. » (`ems.rdv.date_invalide`).
- **Notifications** : EMS en service Membre+ : « Nouvelle demande de rendez-vous de {nom}. » (`ems.notif.rdv_nouveau`).
- **Liens** : Sites web (bloc formulaire), Demandes, MET-EMS-16.
- **Réglages** : `Config.EMS.Appointments.MaxOpen = 3`, `Config.EMS.Appointments.DaysAhead = 14`, `Config.EMS.Appointments.Slots = { matin = '8-12', apres_midi = '12-18', soir = '18-23' }`.
- **Journal admin** : non.
- **Performance** : le site est en cache serveur ; une écriture par demande.
- **Cas limites** : aucun EMS en service → la demande est enregistrée, notification à la prochaine prise de service d'un Membre+ ; texte avec HTML → nettoyé ; double clic → une seule demande.
- **Critères d'acceptation** :
  - Étant donné le site de l'Hôpital, quand j'envoie un rendez-vous pour demain matin, alors il apparaît dans Demandes de l'Hôpital.
  - Étant donné 3 demandes ouvertes, quand j'en envoie une 4e, alors refus.
  - Étant donné une date à +30 jours forcée dans l'événement, quand j'envoie, alors refus.

### [MET-EMS-16] Traiter une demande de rendez-vous
- **But** : fixer ou refuser un rendez-vous demandé.
- **Qui** : EMS en service dès Membre (« Répondre aux demandes »).
- **Où** : app EMS > onglet « Rendez-vous » (filtre des Demandes type `rendez_vous` de l'Hôpital + rendez-vous à venir).
- **Parcours** :
  1. Liste des demandes ouvertes (nom, motif, souhait, ancienneté) et des rendez-vous à venir.
  2. « Fixer le rendez-vous » : date + heure (pas de 15 min), praticien (EMS de l'entreprise, défaut soi-même), lieu (≤ 60, défaut « Hôpital, accueil »).
  3. Serveur crée le rendez-vous, ferme la demande (statut `traitee`), ajoute un créneau au Planning du praticien si l'app Planning est active.
  4. Le citoyen reçoit la confirmation ; il peut « Annuler » depuis sa notification jusqu'à 1 h avant.
  5. « Refuser » : motif (Complet, Hors compétence, Autre + texte ≤ 100) → demande `refusee`, citoyen prévenu.
  6. Rappel : à l'ouverture de la tablette par le citoyen ou le praticien, si un rendez-vous a lieu dans moins de 2 h et `reminded = 0`, une notification de rappel est affichée et `reminded` passe à 1.
  7. Après l'heure : le praticien marque « Honoré » ou « Absent » ; sans action, il passe `passe` 24 h après (à la prochaine lecture).
- **Données** (`pop_tablet_appointments`, commune aux entreprises) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | company_id | INT | oui | | |
  | request_id | INT | non | | |
  | citizen | VARCHAR(64) | oui | | |
  | staff | VARCHAR(64) | oui | membre de l'entreprise | auteur |
  | at | DATETIME | oui | futur, ≤ +30 j | |
  | place | VARCHAR(60) | oui | nettoyé | « Hôpital, accueil » |
  | status | ENUM('prevu','annule','honore','absent','passe') | oui | | 'prevu' |
  | reminded | BOOL | oui | | 0 |
- **Règles serveur** : droit Membre+ ; praticien dans l'entreprise ; pas deux rendez-vous du même praticien à moins de 15 min d'écart ; fréquence 1 / 3 s ; annulation citoyen seulement si `at` > maintenant + 1 h.
- **Textes et états** : vide « Aucune demande de rendez-vous. » (`ems.rdv.vide`) ; succès « Rendez-vous fixé le {date} à {heure}. » (`ems.rdv.fixe`) ; conflit « {praticien} a déjà un rendez-vous à cette heure. » (`ems.rdv.conflit`) ; refus « Demande refusée. » (`ems.rdv.refuse`) ; annulation trop tard « Il est trop tard pour annuler (moins d'1 h). » (`ems.rdv.annulation_tard`) ; déjà traitée « Cette demande vient d'être traitée par {nom}. » (`ems.rdv.deja_traitee`).
- **Notifications** : citoyen : « Rendez-vous à l'hôpital le {date} à {heure} · {lieu}. » (`ems.notif.rdv_fixe`) ; refus : « Demande de rendez-vous refusée : {motif}. » (`ems.notif.rdv_refuse`) ; rappel aux deux : « Rappel : rendez-vous à {heure} · {lieu}. » (`ems.notif.rdv_rappel`) ; annulation → praticien : « {nom} a annulé son rendez-vous du {date}. » (`ems.notif.rdv_annule`).
- **Liens** : Demandes, Planning, Sites web.
- **Réglages** : `Config.EMS.Appointments.ReminderHours = 2`, `Config.EMS.Appointments.CancelLimitHours = 1`, `Config.EMS.Appointments.DefaultPlace = 'Hôpital, accueil'`.
- **Journal admin** : non.
- **Performance** : liste paginée ; rappels calculés à l'ouverture de la tablette (une requête indexée `citizen, at` / `staff, at`), aucun minuteur permanent.
- **Cas limites** : demande traitée en même temps par un collègue → `ems.rdv.deja_traitee` ; praticien renvoyé → ses rendez-vous futurs passent au patron, citoyen non prévenu (rien ne change pour lui) ; citoyen hors ligne → notification gardée 7 jours.
- **Critères d'acceptation** :
  - Étant donné une demande ouverte, quand je fixe un rendez-vous, alors le citoyen reçoit la date et la demande disparaît de la liste.
  - Étant donné un rendez-vous dans 1 h 30, quand le citoyen ouvre sa tablette, alors il reçoit le rappel une seule fois.
  - Étant donné une Recrue, quand elle envoie `ems:appointment:set`, alors le serveur refuse.

### [MET-EMS-17] Tri des blessés par couleur en cas d'afflux (liste partagée EMS et police)
- **But** : lors d'un afflux de blessés (fusillade, carambolage), classer chaque victime par couleur d'urgence dans une liste commune vue en direct par les EMS et la police.
- **Qui** : ouvrir et fermer un afflux : EMS en service dès Membre (ou l'EMS qui l'a ouvert pour le fermer) ; ajouter une victime et changer sa couleur : EMS en service dès Recrue ; police en service (`police.appels`, Recrue+) : voir la liste, ajouter une victime en vert, jaune ou rouge ; seul un EMS met une victime en noir ou la marque évacuée.
- **Où** : app EMS > onglet « Tri » > « Ouvrir un afflux » ; app Police > Dispatch > bouton « Tri des blessés » (visible quand un afflux est ouvert).
- **Parcours** :
  1. « Ouvrir un afflux » → titre (≤ 60, ex. « Fusillade Legion Square »), position = position serveur de l'EMS → `ems:triage:open { title, actionId }` → afflux `ouvert` ; notification aux EMS et policiers en service.
  2. « Ajouter une victime » → choix d'une personne à ≤ 10 m (liste « Personne n°{id serveur} », avec son nom seulement si le joueur est déjà dans un dossier médical lu par l'EMS) ou « Inconnu » (description ≤ 100) ; couleur ; note (≤ 200) → `ems:triage:addVictim { triageId, targetToken | description, color, note, actionId }`. Le serveur prend la position de la victime (ou de l'auteur pour « Inconnu ») et note si elle est à terre (`Bridge.IsDead`).
  3. Couleurs (fixes) : **Vert** « Blessé léger, peut attendre » ; **Jaune** « Urgent, état stable » ; **Rouge** « Urgence absolue » ; **Noir** « Décédé ou au-delà des soins ». Pastilles de couleur pleine, sans dégradé ; libellé toujours écrit à côté (lisible sans voir les couleurs).
  4. Liste : triée Rouge, Jaune, Vert, puis Noir ; dans chaque couleur, la plus ancienne en premier ; compteurs en haut « {r} rouges · {j} jaunes · {v} verts · {n} noirs » ; chaque ligne : couleur, nom ou description, rue (calculée côté client), « à terre » si vrai, statut, EMS qui s'en occupe.
  5. Actions sur une ligne : « Changer la couleur », « Je m'en occupe » (EMS : statut `pris_en_charge` par lui, GPS posé), « Évacuée » (EMS : statut `evacuee`, la ligne passe en fin de liste grisée).
  6. Mise à jour en direct pour tous les EMS et policiers en service qui ont l'onglet ouvert (abonnement ouvert à l'affichage, fermé en quittant l'onglet ou la tablette).
  7. « Fermer l'afflux » (Membre+ ou auteur) → confirmation « Fermer l'afflux ? Il sera archivé. » → statut `ferme` ; un résumé reste consultable dans « Afflux passés » (20 par page).
- **Données** : `pop_tablet_ems_triage` (`id`, `title` VARCHAR(60), `x`, `y`, `z`, `status` ENUM('ouvert','ferme'), `opened_by`, `opened_at`, `closed_by`, `closed_at`) et `pop_tablet_ems_triage_victims` :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | triage_id | INT | oui | index | |
  | identifier | VARCHAR(64) | non | NULL si « Inconnu » | NULL |
  | description | VARCHAR(100) | non | obligatoire si « Inconnu », nettoyée | '' |
  | color | ENUM('vert','jaune','rouge','noir') | oui | `noir` réservé aux EMS | 'jaune' |
  | note | VARCHAR(200) | non | nettoyée | '' |
  | status | ENUM('en_attente','pris_en_charge','evacuee') | oui | `pris_en_charge` et `evacuee` réservés aux EMS | 'en_attente' |
  | handled_by | VARCHAR(64) | non | EMS | NULL |
  | x, y, z | FLOAT | oui | position serveur | |
  | added_by / added_role | VARCHAR(64) / ENUM('ems','police') | oui | | |
  | updated_at | DATETIME | oui | | NOW() |
- **Règles serveur** : service vérifié pour chaque action (EMS ou police) ; distance ≤ `Config.EMS.Triage.AddDistance = 10.0` m pour ajouter une personne ; une victime (identifiant) une seule fois par afflux ; 3 afflux ouverts max (`Config.EMS.Triage.MaxOpen = 3`), 60 victimes max par afflux ; couleur `noir` et statuts `pris_en_charge` / `evacuee` refusés à la police ; fréquence 1 / 2 s par joueur ; la NUI ne reçoit jamais d'identifiant (jeton de cible) ; afflux ouvert depuis plus de 6 h → fermé à la lecture suivante (`Config.EMS.Triage.AutoCloseHours = 6`, sans boucle).
- **Textes et états** :
  - Vide : « Aucun afflux en cours. » (`ems.tri.vide`) + bouton « Ouvrir un afflux » (`ems.tri.ouvrir`).
  - Couleurs : « Vert · Blessé léger, peut attendre » (`ems.tri.vert`), « Jaune · Urgent, état stable » (`ems.tri.jaune`), « Rouge · Urgence absolue » (`ems.tri.rouge`), « Noir · Décédé ou au-delà des soins » (`ems.tri.noir`).
  - Compteurs : « {r} rouges · {j} jaunes · {v} verts · {n} noirs » (`ems.tri.compteurs`) ; « à terre » (`ems.tri.a_terre`) ; statuts « En attente » (`ems.tri.statut.en_attente`), « Pris en charge par {nom} » (`ems.tri.statut.pris`), « Évacuée » (`ems.tri.statut.evacuee`).
  - Succès : « Afflux ouvert. » (`ems.tri.ouvert_ok`), « Victime ajoutée. » (`ems.tri.ajoutee`), « Couleur mise à jour. » (`ems.tri.couleur_ok`), « Afflux fermé. » (`ems.tri.ferme_ok`).
  - Erreurs : « Personne à moins de 10 m. » (`ems.tri.personne`) ; « Cette personne est déjà dans la liste. » (`ems.tri.doublon`) ; « Réservé aux EMS. » (`ems.tri.reserve_ems`) ; « 3 afflux ouverts au maximum. » (`ems.tri.max`) ; hors service `commun.erreur.hors_service`.
- **Notifications** : ouverture : EMS et policiers en service avec tablette « Afflux de blessés : {titre} — {rue} » (`ems.notif.afflux`) ; nouvelle victime rouge : EMS en service « Urgence absolue ajoutée : {titre} » (`ems.notif.tri_rouge`), regroupée à 1 notification / 30 s par afflux.
- **Liens** : MET-EMS-03 (alertes « à terre » : bouton « Ajouter au tri » sur une alerte quand un afflux est ouvert), MET-EMS-04 (GPS), MET-POL-08 (bouton dans le Dispatch police), MET-EMS-12 (certificat de décès pour une victime noire).
- **Réglages** : `Config.EMS.Triage.Enabled = true`, `Config.EMS.Triage.AddDistance = 10.0`, `Config.EMS.Triage.MaxOpen = 3`, `Config.EMS.Triage.MaxVictims = 60`, `Config.EMS.Triage.AutoCloseHours = 6`, `Config.EMS.Triage.PoliceCanAdd = true`.
- **Journal admin** : oui, catégorie `ems` : ouverture, fermeture, passage en noir (qui, victime, heure).
- **Performance** : afflux ouverts et victimes en mémoire serveur, écrits en base à chaque changement (file groupée) ; envois en direct seulement aux abonnés ; aucune boucle.
- **Cas limites** :
  - Victime réanimée (`Bridge.OnPlayerRevived`) → la mention « à terre » disparaît, la couleur ne change pas toute seule.
  - Victime déconnectée → la ligne reste avec la mention « Absent » (`ems.tri.absent`).
  - Deux EMS cliquent « Je m'en occupe » en même temps → le premier gagne, le second voit « Pris en charge par {nom} ».
  - 61e victime → refus « 60 victimes au maximum. » (`ems.tri.max_victimes`).
- **Critères d'acceptation** :
  - Étant donné un afflux ouvert, quand un EMS ajoute une victime en rouge, alors tous les EMS et policiers en service qui ont l'onglet ouvert la voient en tête de liste sans recharger.
  - Étant donné un policier en service, quand il ajoute un blessé en vert, alors la ligne apparaît avec « Ajoutée par la police ».
  - Étant donné l'afflux fermé, quand un EMS ouvre « Afflux passés », alors il retrouve le résumé avec les compteurs par couleur.
  - Étant donné un policier qui envoie à la main `color = 'noir'`, quand le serveur le reçoit, alors il refuse « Réservé aux EMS. » et la couleur ne change pas.

---

# Mécano

### [MET-MEC-01] Prendre et quitter son service mécano (et voir l'équipe)
- **But** : se déclarer en service pour recevoir les dépannages et utiliser l'app ; voir les collègues en service.
- **Qui** : tout membre d'un job de `Config.Mechanic.Jobs`, dès Recrue.
- **Où** : app Mécano > en-tête > « Prendre mon service » / « Quitter mon service » ; onglet « Équipe ».
- **Parcours** : identique à MET-EMS-01 (actions `gestion.service.prendre` / `quitter` d'ENT-GES-01/02, table `pop_tablet_ent_services`, mêmes fins automatiques, jamais de bascule du job ESX), puis :
  1. Le garage passe « Ouvert » dans l'annuaire dès 1 mécano en service, « Fermé » quand le dernier quitte.
  2. Onglet « Équipe » : même fonctionnement que MET-EMS-02 (liste mémoire, statut « Disponible » ou « Sur dépannage n°{id} », mises à jour en direct tant que l'onglet est ouvert).
  3. Onglet « Heures » : même fonctionnement que MET-EMS-14 (droit équipe `meca.hours.team`, Chef+).
- **Données** : `pop_tablet_ent_services` (cf. MET-EMS-01) ; affichage équipe : nom, grade, depuis, statut.
- **Règles serveur** : job mécano (chaque job = son garage ; un mécano ne voit que son garage) ; une session ouverte max par joueur ; 1 bascule / 10 s.
- **Textes et états** : hors service « Hors service. » (`meca.service.hors`) + « Prendre mon service » (`meca.service.prendre`) ; succès « En service. » (`meca.service.succes_prise`) ; fin « Service terminé : {duree}. » (`meca.service.succes_fin`) ; équipe vide « Personne n'est en service. » (`meca.equipe.vide`) ; statuts « Disponible » (`meca.equipe.dispo`), « Sur dépannage n°{id} » (`meca.equipe.sur_depannage`) ; heures vides « Aucune heure de service cette semaine. » (`meca.heures.vide`).
- **Notifications** : aucune par défaut (option `Config.Mechanic.NotifyColleagues = false`, texte « {nom} a pris son service. » `meca.notif.collegue_prise`).
- **Liens** : Annuaire, Planning, signal `pop_tablet:dutyChanged`.
- **Réglages** : `Config.Mechanic.Jobs = { 'mechanic' }`, `Config.Mechanic.NotifyColleagues = false` ; fréquence : `Config.Service.Frequence` (fichier 02).
- **Journal admin** : oui, `service` (prise/fin, durée).
- **Performance** : aucune boucle, liste en mémoire.
- **Cas limites** : déconnexion → session fermée ; deux garages (deux jobs) → listes séparées ; double clic → une session.
- **Critères d'acceptation** :
  - Étant donné un mécano hors service, quand il prend son service, alors le garage passe « Ouvert » dans l'annuaire.
  - Étant donné le dernier mécano en service, quand il quitte, alors le garage passe « Fermé ».
  - Étant donné un EMS, quand il envoie `meca:duty:toggle`, alors refus.

### [MET-MEC-02] Accepter un dépannage (boîte Demandes + GPS)
- **But** : voir les demandes de dépannage et en accepter une avec GPS vers le client.
- **Qui** : mécano en service dès Membre (« Répondre aux demandes ») ; la Recrue voit la liste mais ne peut pas accepter (réglable par le patron).
- **Où** : app Mécano > onglet « Dépannages ».
- **Parcours** :
  1. Création côté citoyen (hors de cette app) : formulaire du site du garage, fiche annuaire « Demander un dépannage », ou export `exports.pop_tablet:CreateRequest(businessId, 'depannage', data)`. Le serveur enregistre dans la boîte « Demandes » du garage avec la position serveur du demandeur au moment de l'envoi, le message (≤ 200 car.) et la plaque du véhicule le plus proche du demandeur (≤ 5 m, lue côté serveur, sinon vide).
  2. L'onglet liste les demandes `ouverte` de type `depannage` : nom, distance approximative (calculée par le client du mécano), message, ancienneté.
  3. « Accepter » → `meca:tow:accept { requestId, actionId }`.
  4. Serveur : demande encore `ouverte` → `acceptee`, `assigned_to` = mécano ; renvoie la position ; le client pose le GPS.
  5. Le demandeur reçoit « Un dépanneur arrive : {nom}. ».
  6. Bouton « Mettre à jour la position » : le serveur relit la position actuelle du demandeur s'il est connecté et la renvoie (1 fois / 30 s).
- **Données** (table Demandes de la base, `payload` JSON) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | type | 'depannage' | oui | | |
  | requester | VARCHAR(64) | oui | | |
  | x, y, z | FLOAT | oui | position serveur | |
  | plate | VARCHAR(8) | non | | '' |
  | message | VARCHAR(200) | non | nettoyé | '' |
  | status | ENUM('ouverte','acceptee','terminee','annulee','expiree') | oui | | 'ouverte' |
  | assigned_to | VARCHAR(64) | non | | NULL |
- **Règles serveur** : droit ; demande `ouverte` ; un mécano n'a qu'un dépannage `acceptee` à la fois ; un citoyen a 1 demande de dépannage ouverte max par garage ; envoi citoyen 1 / 120 s ; expiration 30 min sans acceptation (vérifiée à la lecture, pas de boucle).
- **Textes et états** : vide « Aucune demande de dépannage. » (`meca.depannages.vide`) ; succès « Dépannage accepté. Point GPS posé. » (`meca.depannages.succes`) ; déjà pris « Ce dépannage a déjà été pris par {nom}. » (`meca.depannages.deja_pris`) ; un à la fois « Un dépannage est déjà en cours. » (`meca.depannages.un_seul`) ; pas le droit : bouton « Accepter » grisé « Grade requis : {grade} ».
- **Notifications** : mécanos en service à la création : « Dépannage demandé par {nom}. » (`meca.notif.depannage_nouveau`) ; demandeur à l'acceptation : « Un dépanneur arrive : {nom}. » (`meca.notif.depanneur_arrive`).
- **Liens** : Demandes, Sites web, Annuaire, MET-MEC-01 (statut).
- **Réglages** : `Config.Mechanic.Tow.ExpireMinutes = 30`, `Config.Mechanic.Tow.RecruitCanAccept = false`, `Config.Mechanic.Tow.RequestCooldown = 120`.
- **Journal admin** : non.
- **Performance** : liste paginée ; demandes ouvertes du garage en cache mémoire (mises à jour sur événement).
- **Cas limites** : deux mécanos acceptent en même temps → le premier gagne, le second voit « déjà pris » ; demandeur déconnecté → la demande reste, le GPS pointe la dernière position ; demande expirée → disparaît, le demandeur reçoit « Aucun dépanneur disponible. Réessayez plus tard. » (`meca.notif.depannage_expire`).
- **Critères d'acceptation** :
  - Étant donné une demande ouverte, quand je l'accepte, alors un point GPS est posé et le demandeur est prévenu.
  - Étant donné un dépannage déjà accepté par un collègue, quand je clique « Accepter », alors j'ai le message « déjà pris ».
  - Étant donné une Recrue, quand elle envoie `meca:tow:accept`, alors refus.

### [MET-MEC-03] Terminer, rendre ou annuler un dépannage (ajout)
- **But** : clore un dépannage accepté (fait ou annulé) pour libérer le mécano.
- **Qui** : le mécano assigné, ou un Chef+ du garage.
- **Où** : app Mécano > « Dépannages » > dépannage en cours > « Terminé », « Rendre » ou « Annuler ».
- **Parcours** : « Terminé » → statut `terminee`, proposition « Faire un devis ? » (ouvre MET-MEC-07 avec le client et la plaque pré-remplis) ; « Rendre » → statut `ouverte`, retour dans la liste, `assigned_to` vidé ; « Annuler » (motif : Client absent, Annulé par le client, Autre) → `annulee`, client prévenu.
- **Données** : `status`, `assigned_to` ; `closed_reason VARCHAR(32)`, `closed_at DATETIME`.
- **Règles serveur** : assigné ou Chef+ ; dépannage `acceptee` ; 1 / 2 s.
- **Textes et états** : « Dépannage terminé. » (`meca.depannages.termine`) ; « Dépannage remis dans la liste. » (`meca.depannages.rendu`) ; « Dépannage annulé. » (`meca.depannages.annule`) ; pas assigné « Seul le dépanneur assigné peut faire ça. » (`meca.depannages.pas_assigne`).
- **Notifications** : client à l'annulation : « Dépannage annulé : {motif}. » (`meca.notif.depannage_annule`).
- **Liens** : MET-MEC-07.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : une écriture.
- **Cas limites** : mécano qui quitte son service avec un dépannage accepté → rendu automatiquement (`ouverte`) ; client déconnecté → annulation possible, notification gardée 7 jours ; double clic → une action.
- **Critères d'acceptation** :
  - Étant donné un dépannage accepté, quand je clique « Terminé », alors il quitte la liste et le devis pré-rempli est proposé.
  - Étant donné un dépannage rendu, quand un collègue ouvre la liste, alors il le voit ouvert.
  - Étant donné un Membre non assigné, quand il envoie la fin, alors refus.

### [MET-MEC-04] Diagnostiquer un véhicule
- **But** : connaître l'état du moteur, de la carrosserie et l'essence d'un véhicule proche.
- **Qui** : mécano en service dès Recrue.
- **Où** : app Mécano > onglet « Diagnostic » > bouton « Lancer le diagnostic ».
- **Parcours** :
  1. Clic → le client cherche une seule fois le véhicule le plus proche du joueur (≤ 5 m) et envoie son `netId` et l'essence lue côté client (`GetVehicleFuelLevel`).
  2. Animation de 3 s côté client (le joueur se tourne vers le véhicule, animation « regarder sous le capot » ; annulable par Échap).
  3. Serveur : entité existe, distance ped–véhicule ≤ 5 m (calcul serveur), lit `GetVehicleEngineHealth`, `GetVehicleBodyHealth`, `GetVehiclePetrolTankHealth`, la plaque `GetVehicleNumberPlateText`, et l'essence depuis le statebag `Entity(veh).state.fuel` s'il existe (ox_fuel), sinon la valeur du client marquée « estimation ».
  4. Résultat : plaque, modèle (nom d'affichage côté client), Moteur {x} %, Carrosserie {y} %, Réservoir {z} %, Essence {e} % ; pastille par ligne (≥ 80 % « Bon », 40–79 % « Usé », < 40 % « Critique »).
  5. Boutons : « Créer un devis » (lignes suggérées : moteur < 80 % → « Réparation moteur », carrosserie < 80 % → « Réparation carrosserie », essence < 20 % → « Plein d'essence », prises dans le catalogue si elles existent) ; « Voir le carnet » (MET-MEC-05) ; « Noter au carnet » (MET-MEC-06).
  6. Le serveur garde le dernier diagnostic du joueur en mémoire 10 min (pour MET-MEC-06).
- **Données** (affichées ; stockées seulement via « Noter au carnet ») :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | plate | VARCHAR(8) | oui | | |
  | engine_pct | TINYINT | oui | `max(0, engine) / 10` arrondi | |
  | body_pct | TINYINT | oui | `max(0, body) / 10` | |
  | tank_pct | TINYINT | oui | `max(0, tank) / 10` | |
  | fuel_pct | TINYINT | oui | 0–100 | |
  | fuel_estimated | BOOL | oui | vrai si valeur client | |
- **Règles serveur** : en service ; distance ≤ 5 m (`Config.Mechanic.Diagnostic.Distance = 5.0`) ; fréquence 1 / 5 s ; refus si le joueur conduit un véhicule en mouvement.
- **Textes et états** : vide « Aucun véhicule à proximité. » (`meca.diag.vide`) ; aucun véhicule « Aucun véhicule à moins de 5 m. » (`meca.diag.aucun`) ; en cours « Diagnostic en cours… » (`meca.diag.en_cours`) ; annulé « Diagnostic annulé. » (`meca.diag.annule`) ; labels « Bon » (`meca.diag.bon`), « Usé » (`meca.diag.use`), « Critique » (`meca.diag.critique`), « estimation » (`meca.diag.estimation`) ; disparu « Le véhicule a disparu. » (`meca.diag.disparu`) ; hors service `commun.erreur.hors_service`.
- **Notifications** : aucune.
- **Liens** : MET-MEC-05, MET-MEC-06, MET-MEC-07.
- **Réglages** : `Config.Mechanic.Diagnostic.Distance = 5.0`, `Config.Mechanic.Diagnostic.Duration = 3000` (ms), `Config.Mechanic.Diagnostic.Thresholds = { good = 80, worn = 40 }`.
- **Journal admin** : non (sauf `triche`).
- **Performance** : une recherche de véhicule au clic, aucune boucle ; lecture serveur de natives, sans SQL.
- **Cas limites** : véhicule supprimé pendant l'animation → `meca.diag.disparu` ; plaque illisible → « INCONNUE », carnet indisponible ; distance falsifiée → le serveur recalcule et refuse.
- **Critères d'acceptation** :
  - Étant donné un véhicule abîmé à 3 m, quand je lance le diagnostic, alors je vois les pourcentages moteur, carrosserie, réservoir, essence.
  - Étant donné un véhicule à 8 m, quand je lance le diagnostic, alors « Aucun véhicule à moins de 5 m ».
  - Étant donné un client qui envoie le `netId` d'un véhicule à 50 m, quand le serveur traite, alors refus et journal `triche`.

### [MET-MEC-05] Consulter le carnet d'entretien d'un véhicule (carnet simple)
- **But** : voir le carnet d'entretien simple d'un véhicule, par plaque : réparations, entretiens, factures et garanties des garages ; visible par les garages et par le propriétaire.
- **Qui** : mécanos de tous les garages en service dès Recrue ; le propriétaire du véhicule (MET-MEC-11, sans service ni droit) ; police seulement si `Config.Mechanic.Logbook.PoliceCanRead = true` (désactivé par défaut).
- **Où** : app Mécano > onglet « Carnets » > recherche par plaque ; bouton « Voir le carnet » du diagnostic ; app « Carnet auto » du propriétaire (MET-MEC-11) ; app Police > fiche véhicule > bloc « Carnet d'entretien » (si activé).
- **Principe** (décision du client : aucune fonction ne pénalise les biens des joueurs) : le carnet ne contient **aucun** drapeau ni mention « volé », aucun contrôle de vol (ni au garage, ni chez un concessionnaire, ni à une reprise) et aucune alerte automatique ; il ne bloque jamais une réparation, une vente ou une reprise.
- **Parcours** :
  1. Saisie de la plaque (2 à 8 caractères, mise en majuscules, espaces retirés) → `meca:logbook:get { plate, page }`.
  2. Serveur renvoie les entrées triées par date décroissante, 20 par page : date, garage, mécano, type, résumé, montant, pastille « Sous garantie jusqu'au {date} » si `warranty_until` est futur.
  3. Clic sur une entrée → détail (lignes de travaux, montant, numéro de facture liée, diagnostic noté, note, garantie du garage : durée et date de fin).
  4. En-tête du carnet : plaque, modèle (nom d'affichage côté client), nombre d'interventions, dernière intervention, garanties en cours (garage, fin).
- **Données** (`pop_tablet_vehicle_logbook`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | plate | VARCHAR(8) | oui | index | |
  | company_id | INT | oui | | |
  | mechanic | VARCHAR(64) | oui | | |
  | kind | ENUM('reparation','entretien','diagnostic','note') | oui | | |
  | lines | JSON | non | 30 lignes max | [] |
  | diagnostic | JSON | non | pourcentages MET-MEC-04 | NULL |
  | note | VARCHAR(500) | non | nettoyé | '' |
  | amount | INT | non | | 0 |
  | invoice_id | INT | non | | NULL |
  | warranty_days | TINYINT | oui | 0 à `Config.Mechanic.Logbook.WarrantyMaxDays = 90` (0 = sans garantie) | 0 |
  | warranty_until | DATETIME | non | `created_at` + `warranty_days` | NULL |
  | archived | BOOL | oui | | 0 |
  | created_at | DATETIME | oui | | NOW() |
- **Règles serveur** : mécano en service, ou propriétaire (vérifié par `Bridge.FindPlate(plate).owner == identifier`, BASE-MOT-02 : ESX `owned_vehicles`, QBCore / Qbox `player_vehicles`), ou policier en service si `PoliceCanRead = true` ; la police ne voit pas `amount` si `Config.Mechanic.Logbook.PoliceSeesAmounts = false` ; fréquence 1 / 1 s ; entrées `archived` visibles seulement par l'admin ; aucune colonne ni action liée au vol.
- **Textes et états** : vide « Saisissez une plaque pour afficher son carnet. » (`meca.carnet.vide`) ; aucune entrée « Aucune intervention connue pour {plaque}. » (`meca.carnet.aucune`) ; plaque invalide « Plaque invalide (2 à 8 caractères). » (`meca.carnet.plaque_invalide`) ; garantie « Sous garantie jusqu'au {date} » (`meca.carnet.garantie`), « Garantie terminée » (`meca.carnet.garantie_finie`), « Sans garantie » (`meca.carnet.sans_garantie`) ; types « Réparation » (`meca.carnet.type.reparation`), « Entretien » (`…type.entretien`), « Diagnostic » (`…type.diagnostic`), « Note » (`…type.note`).
- **Notifications** : aucune.
- **Liens** : MET-MEC-06, MET-MEC-09, MET-MEC-11 (propriétaire) ; App Police (fiche véhicule, lecture seule, seulement si activé).
- **Réglages** : `Config.Mechanic.Logbook.PoliceCanRead = false`, `Config.Mechanic.Logbook.PoliceSeesAmounts = true`, `Config.Mechanic.Logbook.WarrantyMaxDays = 90`.
- **Journal admin** : non (lecture).
- **Performance** : requête paginée sur index `plate` ; pas de cache.
- **Cas limites** : fausse plaque → le carnet suit la plaque saisie, pas le véhicule ; plaque avec espaces → normalisée ; policier hors service ou `PoliceCanRead = false` → refus ; véhicule revendu → le nouveau propriétaire voit tout le carnet de la plaque (historique et garanties restantes).
- **Critères d'acceptation** :
  - Étant donné une plaque réparée deux fois, quand je la cherche, alors je vois deux entrées, la plus récente en haut.
  - Étant donné une réparation facturée avec 30 jours de garantie il y a 10 jours, quand un mécano d'un autre garage ouvre le carnet, alors il voit « Sous garantie jusqu'au {date} » avec le nom du garage.
  - Étant donné la configuration par défaut, quand un policier en service ouvre la fiche véhicule, alors l'onglet « Carnet d'entretien » est absent.
  - Étant donné un civil qui n'est pas propriétaire, quand il envoie `meca:logbook:get` pour une plaque, alors refus et aucune donnée.

### [MET-MEC-06] Ajouter une entrée au carnet d'entretien
- **But** : noter une intervention ; une entrée est aussi créée automatiquement au paiement d'une facture de garage.
- **Qui** : mécano en service dès Recrue (entrée manuelle) ; le serveur (entrée automatique).
- **Où** : app Mécano > « Carnets » > plaque > « Ajouter une entrée » ; ou « Noter au carnet » du diagnostic.
- **Parcours** :
  1. Manuel : type (« Entretien », « Diagnostic », « Note »), note (≤ 500), garantie du garage en jours (0 à 90, défaut 0 ; seulement pour « Entretien »), diagnostic joint si on vient de MET-MEC-04 → `meca:logbook:add { plate, kind, note, warrantyDays, actionId }`.
  2. Automatique : quand Factures émet `pop_tablet:invoicePaid` pour une facture de garage portant une plaque (MET-MEC-09), le serveur crée une entrée `reparation` avec les lignes, le montant, `invoice_id` et la garantie du devis (`warranty_days` du devis, MET-MEC-07) ; le propriétaire voit l'entrée dans « Carnet auto » (MET-MEC-11).
  3. L'auteur peut corriger sa note pendant 30 min ; ensuite seul un Chef+ peut archiver l'entrée (motif obligatoire, 10–200 car.).
- **Données** : celles de MET-MEC-05.
- **Règles serveur** : en service ; plaque 2–8 car. ; note nettoyée ; garantie 0 à 90 jours, entier, fixée à la création et non modifiable ensuite ; pour « Diagnostic », les valeurs viennent du dernier diagnostic serveur du joueur (moins de 10 min), jamais du client ; fréquence 1 / 5 s ; le type `reparation` n'est créé que par le serveur.
- **Textes et états** : succès « Entrée ajoutée au carnet de {plaque}. » (`meca.carnet.ajoute`) ; diagnostic expiré « Diagnostic expiré (plus de 10 minutes). » (`meca.carnet.diag_expire`) ; archivage « Entrée archivée. » (`meca.carnet.archivee`) ; note vide en type « Note » → `commun.erreur.champ_requis`.
- **Notifications** : aucune.
- **Liens** : MET-MEC-04, MET-MEC-09 (signal `pop_tablet:invoicePaid` écouté).
- **Réglages** : `Config.Mechanic.Logbook.EditMinutes = 30`, `Config.Mechanic.Logbook.AutoFromInvoice = true`.
- **Journal admin** : oui, `carnet` : archivage (avant, motif).
- **Performance** : une écriture.
- **Cas limites** : facture payée sans plaque → pas d'entrée ; une facture ne se paie qu'une fois (Factures) donc une seule entrée ; note vide en type « Note » → refus.
- **Critères d'acceptation** :
  - Étant donné un diagnostic fait il y a 2 min, quand je clique « Noter au carnet », alors l'entrée contient les pourcentages.
  - Étant donné une facture de garage payée avec plaque, quand le paiement passe, alors une entrée « Réparation » apparaît.
  - Étant donné un client qui envoie des pourcentages inventés, quand le serveur traite, alors il utilise le diagnostic serveur ou refuse.

### [MET-MEC-07] Créer un devis
- **But** : chiffrer des travaux, ligne par ligne, et l'envoyer au client.
- **Qui** : mécano en service dès Recrue (total plafonné à `Config.Mechanic.Quotes.RecruitMax = 1000`), Membre+ jusqu'au maximum.
- **Où** : app Mécano > onglet « Devis » > « Nouveau devis » ; ou depuis Diagnostic / Dépannage terminé.
- **Parcours** :
  1. Client : joueur à moins de 3 m (liste des noms) ; plaque (pré-remplie depuis le diagnostic, modifiable).
  2. Lignes : depuis le catalogue (MET-MEC-10, prix imposé) ou ligne libre (Chef+ ; libellé ≤ 60, prix 1–20 000) ; quantité 1–20 ; la main-d'œuvre est la ligne catalogue « Main-d'œuvre (heure) ».
  3. Total recalculé à chaque ligne (indicatif).
  4. « Envoyer au client » → `meca:quote:create { targetToken, plate, lines, send = true, actionId }`.
  5. Serveur : recalcule, vérifie distance, plafond, stock (MET-MEC-10) ; crée le devis `envoye` numéroté `DEV-AAAA-NNNNN` avec `expires_at` = maintenant + 24 h ; le présente au client (MET-MEC-08).
  6. « Enregistrer sans envoyer » → devis `brouillon` (le client est quand même choisi) ; envoi plus tard depuis la liste (distance revérifiée à l'envoi).
- **Données** (`pop_tablet_quotes`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | number | VARCHAR(16) | oui | unique | |
  | company_id | INT | oui | | |
  | author | VARCHAR(64) | oui | | |
  | client | VARCHAR(64) | oui | | |
  | plate | VARCHAR(8) | non | | '' |
  | warranty_days | TINYINT | oui | 0 à 90, champ « Garantie (jours) » du formulaire ; reprise au carnet au paiement (MET-MEC-06) | `Config.Mechanic.Quotes.DefaultWarrantyDays = 0` |
  | lines | JSON | oui | 1 à 30 lignes `{ part_key, label, qty, unit_price }` | |
  | total | INT | oui | ≤ `Config.Mechanic.Quotes.Max = 50000` | |
  | status | ENUM('brouillon','envoye','accepte','refuse','expire','facture','annule') | oui | | 'brouillon' |
  | expires_at | DATETIME | non | envoi + 24 h | |
  | answered_at | DATETIME | non | | |
  | refuse_reason | VARCHAR(100) | non | nettoyé | '' |
  | invoice_id | INT | non | | NULL |
- **Règles serveur** : en service ; client ≠ soi ; distance ≤ 3 m à l'envoi ; prix catalogue imposés ; plafond grade ; 1–30 lignes ; fréquence 1 / 10 s ; 3 devis `envoye` max par client et par garage ; l'auteur ou un Chef+ peut « Annuler » un devis `brouillon`/`envoye` (`annule`).
- **Textes et états** : vide « Aucun devis. » (`meca.devis.vide`) ; succès « Devis {numero} envoyé à {nom}. » (`meca.devis.envoye`) ; brouillon « Devis enregistré en brouillon. » (`meca.devis.brouillon`) ; plafond « Montant trop élevé pour ce grade (maximum {max}). » (`meca.devis.plafond`) ; sans ligne « Au moins une ligne requise. » (`meca.devis.sans_ligne`) ; trop loin `commun.erreur.trop_loin` ; stock « Plus de stock pour « {piece} ». » (`meca.devis.stock`) ; prix mis à jour « Les prix ont été mis à jour. » (`meca.devis.prix_maj`) ; limite « Ce client a déjà 3 devis en attente chez vous. » (`meca.devis.limite`).
- **Notifications** : cf. MET-MEC-08.
- **Liens** : MET-MEC-08, MET-MEC-10, Stock.
- **Réglages** : `Config.Mechanic.Quotes.Max = 50000`, `Config.Mechanic.Quotes.RecruitMax = 1000`, `Config.Mechanic.Quotes.ValidityHours = 24`, `Config.Mechanic.Quotes.Distance = 3.0`, `Config.Mechanic.Quotes.FreeLineMinGrade = 'chef'`, `Config.Mechanic.Quotes.MaxPending = 3`.
- **Journal admin** : oui, `devis` : création, envoi, annulation (lignes, total).
- **Performance** : catalogue en cache ; liste paginée ; une écriture par devis.
- **Cas limites** : client qui s'éloigne avant l'envoi → refus distance, le brouillon est gardé ; prix catalogue changé entre brouillon et envoi → recalcul au prix actuel + `meca.devis.prix_maj` ; double clic → un devis.
- **Critères d'acceptation** :
  - Étant donné un client à 2 m, quand j'envoie un devis de 2 lignes, alors il le reçoit avec le total exact.
  - Étant donné une Recrue, quand le total dépasse 1 000 $, alors le serveur refuse.
  - Étant donné un client qui modifie un prix catalogue dans l'événement, quand le devis est créé, alors le prix catalogue est utilisé.

### [MET-MEC-08] Répondre à un devis (client)
- **But** : laisser le client accepter ou refuser le devis, sur sa tablette ou par fenêtre simple.
- **Qui** : le client destinataire.
- **Où** : client avec tablette : notification → app Factures > onglet « Devis » ; sans tablette : fenêtre simple à l'écran.
- **Parcours** :
  1. Avec tablette : le devis s'ouvre (garage, mécano, plaque, lignes, total, validité) ; « Accepter » / « Refuser » (motif facultatif ≤ 100 car.).
  2. Sans tablette : fenêtre simple « Devis {garage} : {total} » + 5 premières lignes (« + {n} autres lignes ») ; « Accepter » / « Refuser » ; 60 s sans réponse = le devis reste `envoye` ; le mécano peut renvoyer la fenêtre (1 fois / 30 s, client à moins de 3 m) avec le bouton « Renvoyer au client ».
  3. → `quote:answer { quoteId, accept, reason, actionId }` ; serveur : bon destinataire, statut `envoye`, pas expiré → `accepte` ou `refuse`.
  4. Le mécano est prévenu ; sur `accepte`, le bouton « Facturer » apparaît (MET-MEC-09).
- **Données** : `status`, `answered_at`, `refuse_reason` de `pop_tablet_quotes`.
- **Règles serveur** : seul `client` peut répondre ; devis `envoye` et `expires_at` futur (sinon il passe `expire` à la lecture) ; une seule réponse ; pas de distance pour répondre depuis la tablette ; si le client est mort (`Bridge.IsDead`), la fenêtre simple n'est pas affichée et sera proposée à son réveil.
- **Textes et états** : vide (client) « Aucun devis reçu. » (`devis.client.vide`) ; accepté « Devis accepté. Le garage peut lancer les travaux. » (`devis.client.accepte`) ; refusé « Devis refusé. » (`devis.client.refuse`) ; expiré « Devis expiré. » (`devis.client.expire`) ; déjà répondu « Réponse déjà envoyée pour ce devis. » (`devis.client.deja`).
- **Notifications** : client : « Nouveau devis de {garage} : {total}. » (`meca.notif.devis_recu`) ; mécano : « {nom} a accepté le devis {numero}. » (`meca.notif.devis_accepte`) ou « {nom} a refusé le devis {numero}. » (`meca.notif.devis_refuse`).
- **Liens** : Factures (onglet Devis côté client), fenêtre simple, MET-MEC-09.
- **Réglages** : `Config.Mechanic.Quotes.ResendCooldown = 30`.
- **Journal admin** : oui, `devis` : réponse (accepté / refusé).
- **Performance** : liste client paginée ; aucune boucle (expiration à la lecture).
- **Cas limites** : client déconnecté → devis visible à la reconnexion tant qu'il n'a pas expiré ; client mort → attend son réveil ; double clic → une seule réponse.
- **Critères d'acceptation** :
  - Étant donné un client sans tablette à 2 m, quand le devis est envoyé, alors une fenêtre simple s'affiche avec Accepter / Refuser.
  - Étant donné un devis accepté, quand le mécano ouvre la liste, alors le bouton « Facturer » est actif.
  - Étant donné un autre joueur qui envoie `quote:answer` pour ce devis, alors refus et journal `triche`.

### [MET-MEC-09] Transformer un devis accepté en facture (1 clic)
- **But** : créer la facture d'un devis accepté sans ressaisie.
- **Qui** : mécano en service dès Recrue pour ses propres devis ; Membre+ du garage pour le devis d'un collègue.
- **Où** : app Mécano > « Devis » > devis `accepte` > bouton « Facturer ».
- **Parcours** :
  1. Clic → `meca:quote:invoice { quoteId, actionId }`.
  2. Serveur : devis `accepte` du garage ; crée la facture dans Factures (type `garage`, lignes et total du devis, plaque, référence devis) ; devis → `facture`, `invoice_id` renseigné.
  3. La facture est présentée au client (tablette ou fenêtre simple, règles de Factures). Aucune distance requise (le client a déjà accepté).
  4. Au paiement (`pop_tablet:invoicePaid`) : compte du garage + part employé (Factures), décompte du stock des pièces (MET-MEC-10), entrée au carnet (MET-MEC-06).
- **Données** : `invoice_id`, `status = 'facture'`.
- **Règles serveur** : devis `accepte` ; une seule facture par devis (verrou SQL `UPDATE ... SET status = 'facture' WHERE id = ? AND status = 'accepte'` : si 0 ligne modifiée, refus) ; fréquence 1 / 5 s.
- **Textes et états** : succès « Facture créée depuis le devis {numero}. » (`meca.devis.facture_ok`) ; déjà facturé « Ce devis est déjà facturé. » (`meca.devis.deja_facture`) ; pas accepté « Le client n'a pas encore accepté ce devis. » (`meca.devis.pas_accepte`).
- **Notifications** : client : « Facture de {garage} : {total}. » (`meca.notif.facture_client`) ; mécano au paiement : « {nom} a payé la facture {numero} ({total}). » (`meca.notif.facture_payee`).
- **Liens** : Factures, Stock, Carnet, compte entreprise, signal `pop_tablet:invoicePaid` (écouté).
- **Réglages** : aucun.
- **Journal admin** : oui, `facture` (par Factures).
- **Performance** : une écriture + appel Factures.
- **Cas limites** : client déconnecté → facture créée, présentée à la reconnexion ; deux mécanos cliquent ensemble → une seule facture (verrou) ; pièce retirée du catalogue entre-temps → facture créée avec le libellé et le prix du devis, pas de décompte de stock pour cette pièce.
- **Critères d'acceptation** :
  - Étant donné un devis accepté de 1 200 $, quand je clique « Facturer », alors le client reçoit une facture de 1 200 $ avec les mêmes lignes.
  - Étant donné un devis déjà facturé, quand on reclique, alors refus « déjà facturé ».
  - Étant donné un devis `envoye` non accepté, quand un mécano envoie `meca:quote:invoice` à la main, alors refus.

### [MET-MEC-10] Gérer le catalogue de pièces et tarifs (relié au stock)
- **But** : définir les pièces et prestations vendables, leurs prix et leur lien avec le stock.
- **Qui** : lecture dès Recrue ; modification Chef+ (« Tableur/stock modifier »), réglable.
- **Où** : app Mécano > onglet « Catalogue ».
- **Parcours** :
  1. Liste : libellé, catégorie, prix, stock disponible (si relié), actif.
  2. « Ajouter » / « Modifier » : libellé (≤ 60), catégorie (Moteur, Carrosserie, Pneus, Entretien, Main-d'œuvre, Esthétique, Autre), prix (1–20 000), article Stock lié (liste des articles de l'app Stock du garage, ou « Aucun »), quantité consommée par unité vendue (1–10).
  3. « Enregistrer » → `meca:catalog:save { item, actionId }`.
  4. Stock : au paiement d'une facture (MET-MEC-09), le serveur retire `qty × quantité consommée` de l'article lié via l'API de l'app Stock (mouvement « Vente facture {numero} »). Le stock ne descend jamais sous 0 (règle de l'app Stock, PRO-STO) : s'il manque des pièces, il s'arrête à 0, le mouvement note « manquant : {n} » et les Chefs sont prévenus.
  5. Au devis : si `Config.Mechanic.Catalog.BlockIfNoStock = true` et stock ≤ 0, la ligne est refusée.
- **Données** (`pop_tablet_mech_catalog`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | part_key | VARCHAR(32) | oui | unique par garage | |
  | company_id | INT | oui | | |
  | label | VARCHAR(60) | oui | nettoyé | |
  | category | ENUM(7 catégories ci-dessus) | oui | | 'Autre' |
  | price | INT | oui | 1 à 20 000 | |
  | stock_item_id | INT | non | article Stock du même garage | NULL |
  | stock_per_unit | TINYINT | oui | 1 à 10 | 1 |
  | active | BOOL | oui | | 1 |
  Catalogue par défaut : Réparation moteur 800 $ · Réparation carrosserie 600 $ · Pneu (l'unité) 150 $ · Vidange 200 $ · Plein d'essence 100 $ · Main-d'œuvre (heure) 250 $ · Kit de réparation 350 $ · Nettoyage 80 $ (aucun relié au stock par défaut).
- **Règles serveur** : droit de modification ; 200 articles max ; libellés uniques ; un article n'est jamais supprimé, il est désactivé ; article Stock du même garage ; fréquence 1 / 3 s.
- **Textes et états** : vide « Catalogue vide. » (`meca.catalogue.vide`) ; succès `commun.succes.enregistre` ; doublon « Cette pièce existe déjà. » (`meca.catalogue.doublon`) ; prix invalide « Le prix doit être entre 1 $ et 20 000 $. » (`meca.catalogue.prix_invalide`) ; stock négatif « Stock : {n} (à commander) » (`meca.catalogue.stock_negatif`) ; article introuvable « Article de stock introuvable. » (`meca.catalogue.stock_introuvable`) ; app Stock désactivée : colonne stock masquée ; pas le droit : boutons « Ajouter »/« Modifier » cachés.
- **Notifications** : Chefs+ en service : « Stock épuisé : {piece}. » (`meca.notif.stock_epuise`) quand un article arrive à 0.
- **Liens** : Stock (lecture des articles, mouvements), MET-MEC-07, MET-MEC-09.
- **Réglages** : `Config.Mechanic.Catalog.UseStock = true`, `Config.Mechanic.Catalog.BlockIfNoStock = false`, `Config.Mechanic.Catalog.MaxItems = 200`, `Config.Mechanic.DefaultCatalog = { ... }`.
- **Journal admin** : oui, `catalogue` : création, modification, désactivation (avant/après).
- **Performance** : catalogue en cache serveur par garage, invalidé à l'enregistrement ; stock lu à l'ouverture de l'onglet seulement.
- **Cas limites** : article Stock supprimé → lien vidé + avertissement ; facture payée avec l'app Stock désactivée → pas de décompte, pas d'erreur ; deux Chefs modifient le même article → la dernière version gagne, journalisée.
- **Critères d'acceptation** :
  - Étant donné « Pneu » relié à l'article Stock « Pneus » (10), quand une facture de 4 pneus est payée, alors le stock passe à 6.
  - Étant donné `BlockIfNoStock = true` et un stock à 0, quand j'ajoute la pièce à un devis, alors refus.
  - Étant donné un Membre, quand il envoie `meca:catalog:save`, alors refus.

### [MET-MEC-11] Carnet d'entretien côté propriétaire (app « Carnet auto »)
- **But** : permettre au propriétaire d'un véhicule de consulter le carnet d'entretien simple de ses véhicules (réparations, factures, garanties des garages) depuis sa tablette.
- **Qui** : tout joueur qui possède au moins un véhicule (aucun droit, aucun service) ; non réglable par grade.
- **Où** : bureau de la tablette > app « Carnet auto » (icône clé, visible par tous si `Config.Mechanic.OwnerApp = true`).
- **Parcours** :
  1. Ouverture → `meca:owner:vehicles { page }` → le serveur lit `Bridge.GetVehicles(identifier)` (BASE-MOT-02 : ESX `owned_vehicles`, QBCore / Qbox `player_vehicles`) et renvoie, 20 par page : plaque, modèle (nom d'affichage calculé côté client), date de la dernière intervention, pastille « Sous garantie » si une entrée du carnet a `warranty_until` futur.
  2. Clic sur un véhicule → `meca:logbook:get { plate, page }` (MET-MEC-05) en mode propriétaire : entrées en lecture seule (date, garage, type, résumé, montant, numéro de facture, garantie).
  3. Clic sur une entrée liée à une facture → ouvre la facture dans l'app Factures (ENT-FAC, lecture).
  4. Bouton « Contacter le garage » sur une entrée sous garantie → formulaire de la boîte Demandes du garage (ENT-DEM, type « Rendez-vous », texte ≤ 500 ; référence de l'entrée et plaque ajoutées par le serveur).
- **Données** : lecture seule de `pop_tablet_vehicle_logbook` (MET-MEC-05) et des véhicules par `Bridge.GetVehicles` ; rien de stocké en plus.
- **Règles serveur** : identifiant du demandeur lu par le bridge ; une plaque n'est lisible en mode propriétaire que si `Bridge.FindPlate(plate).owner == identifier` (jamais sur la parole du client) ; véhicules de société non listés ; fréquence 1 / 1 s ; entrées archivées jamais renvoyées ; aucun drapeau ni mention « volé » (décision du client).
- **Textes et états** : titre « Carnet auto » (`meca.proprio.titre`) ; vide « Aucun véhicule à votre nom. » (`meca.proprio.vide`) ; véhicule sans entrée « Aucune intervention pour ce véhicule. » (`meca.proprio.aucune`) ; pastille « Sous garantie » (`meca.proprio.garantie`) ; bouton « Contacter le garage » (`meca.proprio.contacter`) ; succès demande « Demande envoyée à {garage}. » (`meca.proprio.demande_ok`) ; plaque d'un autre `commun.erreur.introuvable`.
- **Notifications** : propriétaire en ville avec tablette, à chaque entrée automatique au paiement (MET-MEC-06) : « Carnet auto · {plaque} : intervention ajoutée par {garage}. » (`meca.notif.carnet_proprio`) si `Config.Mechanic.NotifyOwner = true`.
- **Liens** : MET-MEC-05 / 06 (carnet), MET-MEC-07 (garantie du devis), ENT-FAC (factures), ENT-DEM (demande au garage), BASE-MOT-02 (`GetVehicles`, `FindPlate`).
- **Réglages** : `Config.Mechanic.OwnerApp = true`, `Config.Mechanic.NotifyOwner = true`.
- **Journal admin** : non (lecture).
- **Performance** : liste des véhicules lue à l'ouverture de l'app (une requête paginée), carnet chargé au clic ; aucun cache, aucune boucle.
- **Cas limites** : véhicule vendu → il disparaît de la liste de l'ancien propriétaire et apparaît chez le nouveau avec tout l'historique ; garage archivé → ses entrées restent avec son nom et la mention « Entreprise archivée » (`commun.entreprise.archivee`) ; joueur avec 45 véhicules → 3 pages.
- **Critères d'acceptation** :
  - Étant donné un joueur avec 2 véhicules dont un réparé avec 30 jours de garantie, quand il ouvre « Carnet auto », alors il voit 2 lignes et la pastille « Sous garantie » sur le bon véhicule.
  - Étant donné ce véhicule, quand il clique « Contacter le garage », alors le garage reçoit une demande avec la plaque et la référence de l'entrée.
  - Étant donné un joueur qui envoie `meca:logbook:get` avec la plaque d'un véhicule qui ne lui appartient pas, quand le serveur le reçoit, alors il répond `introuvable` et ne renvoie aucune entrée.

---

# Justice

Rôles (cf. Conventions §2) : **avocat**, **procureur**, **juge**. Le rôle est calculé par le serveur à chaque action à partir du métier et du grade (ESX, QBCore ou Qbox, via le bridge) ; les métiers utilisés sont ceux de `pop_tablet_settings.justice_roles` s'il existe (choix de l'assistant, BASE-MOT-15), sinon `Config.Justice.Roles`. Une seule app « Justice » ; les onglets visibles dépendent du rôle.

### [MET-JUS-01] Prendre et quitter son service justice
- **But** : se déclarer en service comme avocat, procureur ou juge.
- **Qui** : tout joueur dont le job/grade correspond à un rôle de `Config.Justice.Roles`.
- **Où** : app Justice > en-tête > « Prendre mon service » / « Quitter mon service » ; onglet « Effectifs ».
- **Parcours** : identique à MET-EMS-01 (actions d'ENT-GES-01/02, table `pop_tablet_ent_services`, fins automatiques). En plus :
  1. L'en-tête affiche le rôle : « Avocat », « Procureur » ou « Juge ».
  2. Onglet « Effectifs » : liste en mémoire des gens de justice en service, groupée par rôle (Juges, Procureurs, Avocats), visible par tous les rôles ; un avocat est affiché avec son cabinet.
  3. Annuaire : le Cabinet passe « Ouvert » dès 1 avocat en service ; le Tribunal dès 1 juge ou procureur.
- **Données** : `pop_tablet_ent_services` ; affichage : nom, rôle, entreprise, depuis.
- **Règles serveur** : rôle calculé serveur ; 1 session ouverte max ; 1 bascule / 10 s (`Config.Service.Frequence`) ; le job ESX n'est jamais basculé.
- **Textes et états** : hors service « Hors service. » (`justice.service.hors`) ; succès « En service ({role}). » (`justice.service.succes_prise`) ; fin « Service terminé : {duree}. » (`justice.service.succes_fin`) ; rôles « Avocat » (`justice.role.avocat`), « Procureur » (`justice.role.procureur`), « Juge » (`justice.role.juge`) ; effectifs vides par groupe « Aucun {role} en service. » (`justice.effectifs.vide`).
- **Notifications** : aucune.
- **Liens** : Annuaire, Planning, Heures (vue commune, `justice.hours.team` pour les juges et le patron du Cabinet), signal `pop_tablet:dutyChanged`.
- **Réglages** : `Config.Justice.Roles` (cf. Conventions).
- **Journal admin** : oui, `service`.
- **Performance** : aucune boucle, mémoire.
- **Cas limites** : grade changé de 1 à 2 dans le job `justice` pendant le service → le rôle devient « Juge » à la prochaine action (session conservée) ; joueur sans rôle → app absente ; déconnexion → session fermée.
- **Critères d'acceptation** :
  - Étant donné un joueur `justice` grade 2, quand il prend son service, alors l'en-tête affiche « Juge ».
  - Étant donné un avocat en service, quand j'ouvre « Effectifs », alors il apparaît dans « Avocats » avec son cabinet.
  - Étant donné un civil, quand il envoie `justice:duty:toggle`, alors refus.

### [MET-JUS-02] Ouvrir une affaire
- **But** : créer un dossier judiciaire avec ses parties et ses intervenants.
- **Qui** : procureur ou juge en service (droit `justice.case.create`) ; un avocat peut ouvrir une affaire civile pour son client (type « Civile » seulement).
- **Où** : app Justice > onglet « Affaires » > « Nouvelle affaire » ; ou depuis une transmission police (MET-JUS-03).
- **Parcours** :
  1. Formulaire : titre (≤ 80), type (« Pénale », « Civile »), résumé (≤ 2 000), parties (1 à 10 : citoyen recherché par nom + qualité « Accusé », « Plaignant », « Témoin », « Victime »), juge (liste des juges, défaut aucun), procureur (pour une pénale ; défaut l'auteur s'il est procureur).
  2. « Créer » → `justice:case:create { fields, actionId }`.
  3. Serveur : rôle, nettoyage, parties existantes ; numéro `AFF-AAAA-NNNN` ; statut `ouverte`.
  4. Les parties et intervenants sont notifiés ; une partie qui a un avocat (MET-JUS-08) voit son avocat ajouté automatiquement à la ligne de la partie (statut « en attente » : l'avocat confirme qu'il la représente dans cette affaire en un clic).
- **Données** (`pop_tablet_justice_cases` + `pop_tablet_justice_case_parties`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | number | VARCHAR(16) | oui | unique | |
  | title | VARCHAR(80) | oui | nettoyé | |
  | kind | ENUM('penale','civile') | oui | | 'penale' |
  | summary | TEXT | non | 2 000 car. | '' |
  | status | ENUM('ouverte','audience','jugee','classee') | oui | | 'ouverte' |
  | judge | VARCHAR(64) | non | rôle juge | NULL |
  | prosecutor | VARCHAR(64) | non | rôle procureur | NULL |
  | created_by / created_at | | oui | | |
  | archived | BOOL | oui | | 0 |
  Parties : `case_id`, `identifier`, `quality ENUM('accuse','plaignant','temoin','victime')`, `lawyer VARCHAR(64) NULL`, `lawyer_status ENUM('aucun','en_attente','confirme')`.
- **Règles serveur** : rôle ; 1 à 10 parties, sans doublon ; une affaire pénale a au moins 1 accusé ; juge et procureur ont bien ce rôle ; avocat : seulement « Civile » et son client doit être partie ; fréquence 1 / 10 s.
- **Textes et états** : vide « Aucune affaire. » (`justice.affaires.vide`) ; succès « Affaire {numero} ouverte. » (`justice.affaires.creee`) ; sans accusé « Une affaire pénale doit avoir au moins un accusé. » (`justice.affaires.sans_accuse`) ; partie en double « Cette personne est déjà dans l'affaire. » (`justice.affaires.doublon`) ; pas le droit : bouton caché.
- **Notifications** : chaque partie : « Vous êtes cité(e) dans l'affaire {numero} : {titre} ({qualite}). » (`justice.notif.partie_citee`) ; juge et procureur désignés : « Vous êtes désigné(e) sur l'affaire {numero}. » (`justice.notif.designe`) ; avocat d'une partie : « Votre client {nom} est cité dans l'affaire {numero}. Représentation à confirmer. » (`justice.notif.avocat_client_cite`).
- **Liens** : MET-JUS-03, MET-JUS-05, MET-JUS-08.
- **Réglages** : `Config.Justice.Cases.MaxParties = 10`, `Config.Justice.Cases.LawyerCanOpenCivil = true`.
- **Journal admin** : oui, `justice_affaire` : création (numéro, parties, intervenants).
- **Performance** : une transaction SQL ; liste paginée.
- **Cas limites** : partie hors ligne → notification gardée 7 jours ; juge désigné qui perd son rôle → affaire sans juge, alerte aux juges en service « L'affaire {numero} n'a plus de juge. » (`justice.notif.sans_juge`) ; double clic → une affaire.
- **Critères d'acceptation** :
  - Étant donné un procureur, quand il crée une affaire pénale avec un accusé, alors elle a un numéro et l'accusé est notifié.
  - Étant donné un accusé ayant un avocat, quand l'affaire est créée, alors l'avocat apparaît « en attente » et reçoit la notification.
  - Étant donné un avocat, quand il envoie une création d'affaire « Pénale », alors refus.

### [MET-JUS-03] Lier des rapports et preuves de la police à une affaire
- **But** : rattacher à l'affaire les rapports et preuves de l'app Police, qu'ils soient transmis par la police ou cherchés par la justice.
- **Qui** : procureur et juge de l'affaire (ou tout juge/procureur en service) ; avocats de l'affaire en lecture seulement.
- **Où** : app Justice > affaire > onglet « Pièces » > « Lier un rapport » / « Lier une preuve » ; onglet « Transmissions police » (boîte de réception).
- **Parcours** :
  1. Transmission : l'app Police (bouton « Transmettre à la justice ») crée une transmission (rapport ou preuve + message ≤ 300). Elle apparaît dans « Transmissions police » pour les procureurs et juges.
  2. Sur une transmission : « Rattacher à une affaire » (liste des affaires ouvertes) ou « Ouvrir une affaire » (MET-JUS-02 pré-rempli : titre = titre du rapport, parties = personnes citées dans le rapport) ou « Classer » (motif ≤ 200).
  3. Recherche directe : numéro de rapport ou de preuve police → `justice:case:link { caseId, kind, refId, actionId }`.
  4. Serveur : la pièce existe dans l'app Police, n'est pas archivée, pas déjà liée à cette affaire ; crée le lien.
  5. Affichage : la pièce est montrée en lecture seule, telle qu'elle est dans l'app Police au moment de l'affichage (pas de copie) ; si la police l'archive ensuite, elle reste affichée avec la mention « Archivée par la police ».
  6. **Recevabilité et chaîne de possession** (preuves) : chaque preuve affiche sa pastille calculée par la police (MET-POL-36) : « Recevable », « Irrecevable : {motif} » (ex. « Obtenue sans mandat », « Mandat absent, non signé ou expiré ») ou « Contestée » ; une preuve irrecevable reste visible dans l'affaire mais est grisée et marquée « Ne peut pas fonder le verdict » ; l'onglet « Chaîne de possession » de la preuve est lisible par le juge, le procureur et les avocats confirmés ; chaque ouverture d'une preuve depuis l'app Justice écrit une ligne `consultation` (rôle `juge`, `procureur` ou `avocat`) dans `pop_tablet_police_preuves_journal`. Un avocat peut contester une preuve (MET-JUS-12).
- **Données** (`pop_tablet_justice_links`, `pop_tablet_justice_transmissions`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | case_id | INT | oui | | |
  | kind | ENUM('rapport','preuve') | oui | | |
  | ref_id | INT | oui | id dans l'app Police | |
  | linked_by / linked_at | | oui | | |
  | transmission.id / kind / ref_id | | oui | | |
  | transmission.message | VARCHAR(300) | non | nettoyé | '' |
  | transmission.from_officer | VARCHAR(64) | oui | | |
  | transmission.status | ENUM('nouvelle','rattachee','classee') | oui | | 'nouvelle' |
- **Règles serveur** : rôle juge/procureur en service ; avocat : lecture seulement des pièces des affaires où il est `confirme` ; 100 pièces max par affaire ; pas de doublon ; affaire non `jugee`/`classee` pour ajouter ; fréquence 1 / 2 s.
- **Textes et états** : pastilles « Recevable » (`police.preuves.recevable`), « Irrecevable : {motif} » (`police.preuves.irrecevable`), « Contestée » (`police.preuves.contestee`) ; mention « Ne peut pas fonder le verdict » (`justice.pieces.irrecevable_mention`) ; vide pièces « Aucune pièce liée. » (`justice.pieces.vide`) ; vide transmissions « Aucune transmission de la police. » (`justice.transmissions.vide`) ; succès « Pièce liée à l'affaire. » (`justice.pieces.liee`) ; introuvable « Aucun rapport ou preuve avec ce numéro. » (`justice.pieces.introuvable`) ; déjà liée « Cette pièce est déjà dans l'affaire. » (`justice.pieces.deja`) ; affaire close « L'affaire est close : impossible d'ajouter une pièce. » (`justice.pieces.close`).
- **Notifications** : procureurs et juges en service à chaque transmission : « Nouvelle transmission de la police : {titre}. » (`justice.notif.transmission`) ; policier auteur au rattachement : « Transmission rattachée à l'affaire {numero}. » (`justice.notif.transmission_rattachee`).
- **Liens** : App Police (rapports, preuves, Galerie des preuves), MET-JUS-02.
- **Réglages** : `Config.Justice.Cases.MaxLinks = 100`.
- **Journal admin** : oui, `justice_affaire` : lien ajouté/retiré, transmission classée.
- **Performance** : la liste des pièces charge titre + date seulement ; le contenu se charge au clic ; transmissions paginées.
- **Cas limites** : rapport police supprimé (archivé) → affiché « Archivée par la police » ; pièce retirée d'une affaire par erreur → « Retirer » (juge/procureur) archive le lien (visible admin) ; transmission traitée par deux magistrats ensemble → le premier gagne, le second voit « Déjà traitée par {nom}. » (`justice.transmissions.deja`).
- **Critères d'acceptation** :
  - Étant donné un rapport police transmis, quand le procureur le rattache à l'affaire, alors il apparaît dans « Pièces » et le policier est prévenu.
  - Étant donné un avocat confirmé sur l'affaire, quand il ouvre « Pièces », alors il voit les pièces sans pouvoir en ajouter.
  - Étant donné un avocat qui envoie `justice:case:link`, alors refus.
  - Étant donné une preuve créée par la police avec le cadre « Sans mandat », quand le procureur la lie à l'affaire, alors elle apparaît grisée « Irrecevable : Obtenue sans mandat » et l'ouverture par le juge est inscrite dans sa chaîne de possession.

### [MET-JUS-04] Consulter les affaires (liste, fiche, visibilité par rôle)
- **But** : retrouver une affaire et son état ; chaque rôle ne voit que ce qu'il a le droit de voir.
- **Qui** : juges et procureurs : toutes les affaires ; avocat : seulement les affaires où un de ses clients est partie et où il est `confirme` ; parties : rien dans l'app Justice (elles reçoivent les notifications).
- **Où** : app Justice > onglet « Affaires ».
- **Parcours** :
  1. Liste paginée : numéro, titre, type, statut, prochaine audience ; filtres « Ouvertes », « Mes affaires », « Toutes » (« Toutes » caché pour l'avocat) ; recherche par numéro, titre ou nom de partie.
  2. Fiche : en-tête (numéro, titre, statut, juge, procureur), onglets « Parties », « Pièces » (MET-JUS-03), « Audiences » (MET-JUS-05), « Notes », « Verdict » (MET-JUS-06).
  3. « Notes » : chaque intervenant ajoute des notes horodatées (≤ 1 000 car.) ; une note peut être « Privée » (visible seulement par son auteur et, pour un avocat, par les autres avocats du même cabinet) ; les notes du parquet (procureur) ne sont jamais visibles des avocats.
  4. « Classer l'affaire » : voir MET-JUS-11.
- **Données** : tables MET-JUS-02 ; `pop_tablet_justice_notes (id, case_id, author, role, private BOOL, text VARCHAR(1000), created_at)`.
- **Règles serveur** : filtrage côté serveur dans la requête SQL (jamais côté NUI) ; un avocat qui demande une affaire hors périmètre reçoit « introuvable » (pas « interdit », pour ne pas révéler son existence) ; fréquence 1 / 1 s.
- **Textes et états** : vide « Aucune affaire. » (`justice.affaires.vide`) ; vide avocat « Aucune affaire pour vos clients. » (`justice.affaires.vide_avocat`) ; introuvable « Affaire introuvable. » (`justice.affaires.introuvable`) ; statuts « Ouverte » (`justice.statut.ouverte`), « Audience prévue » (`justice.statut.audience`), « Jugée » (`justice.statut.jugee`), « Classée » (`justice.statut.classee`) ; note ajoutée `commun.succes.enregistre`.
- **Notifications** : aucune (hors notes : aucune notification).
- **Liens** : MET-JUS-03, 05, 06, 08, 11.
- **Réglages** : aucun.
- **Journal admin** : oui pour la consultation par un avocat d'une affaire (`justice_consultation`, 30 jours) ; non pour juges/procureurs.
- **Performance** : liste paginée avec index (`status`, `created_at`) et table de jointure parties indexée (`identifier`) ; fiche chargée onglet par onglet.
- **Cas limites** : avocat dont le client retire son mandat (MET-JUS-08) → l'affaire disparaît de sa liste immédiatement ; affaire archivée par l'admin → invisible pour tous sauf admin ; recherche d'un nom avec apostrophe → requête paramétrée.
- **Critères d'acceptation** :
  - Étant donné un juge, quand il ouvre « Toutes », alors il voit toutes les affaires.
  - Étant donné un avocat confirmé sur 2 affaires, quand il ouvre « Affaires », alors il voit exactement ces 2 affaires.
  - Étant donné un avocat qui demande à la main la fiche d'une autre affaire, alors le serveur répond « introuvable ».

### [MET-JUS-05] Planifier une audience
- **But** : fixer date, heure et salle d'une audience et prévenir les participants.
- **Qui** : juge en service (droit `justice.hearing.set`), réglable pour ouvrir au procureur.
- **Où** : app Justice > affaire > onglet « Audiences » > « Planifier une audience ».
- **Parcours** :
  1. Formulaire : date et heure (pas de 15 min, futur, ≤ +60 jours), salle (liste `Config.Justice.Rooms`), objet (« Comparution », « Plaidoirie », « Délibéré », « Autre »), participants pré-cochés (juge, procureur, parties, avocats confirmés ; décocher possible sauf juge).
  2. « Planifier » → `justice:hearing:create`.
  3. Serveur : vérifie que la salle et le juge sont libres à ± 30 min ; crée l'audience ; affaire → `audience` ; ajoute un créneau au Planning du Tribunal si actif.
  4. Notifications aux participants ; rappel à l'ouverture de la tablette si l'audience est dans moins de 2 h (une fois).
  5. Après l'audience : le juge marque « Tenue », « Reportée » (nouvelle date → nouvelle audience) ou « Annulée » ; il peut joindre un compte rendu (≤ 3 000 car.).
- **Données** (`pop_tablet_justice_hearings`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | case_id | INT | oui | | |
  | at | DATETIME | oui | futur, ≤ +60 j | |
  | room | VARCHAR(40) | oui | dans `Config.Justice.Rooms` | 1re salle |
  | subject | ENUM('comparution','plaidoirie','delibere','autre') | oui | | 'comparution' |
  | participants | JSON | oui | 1 à 20 identifiers | |
  | status | ENUM('prevue','tenue','reportee','annulee') | oui | | 'prevue' |
  | minutes | TEXT | non | 3 000 car. | '' |
  | reminded | JSON | oui | identifiers déjà rappelés | [] |
- **Règles serveur** : rôle juge ; affaire `ouverte` ou `audience` ; salle libre et juge libre ± 30 min ; fréquence 1 / 5 s.
- **Textes et états** : vide « Aucune audience prévue. » (`justice.audiences.vide`) ; succès « Audience fixée le {date} à {heure}, {salle}. » (`justice.audiences.fixee`) ; salle prise « La salle {salle} est déjà réservée à cette heure. » (`justice.audiences.salle_prise`) ; juge pris « Une audience est déjà prévue à cette heure. » (`justice.audiences.juge_pris`) ; date invalide « Choisissez une date dans les 60 prochains jours. » (`justice.audiences.date_invalide`).
- **Notifications** : participants : « Audience · affaire {numero} : {date} à {heure}, {salle} ({objet}). » (`justice.notif.audience`) ; rappel : « Rappel : audience à {heure}, {salle}. » (`justice.notif.audience_rappel`) ; changement : « L'audience du {date} (affaire {numero}) est {statut}. » (`justice.notif.audience_modifiee`).
- **Liens** : Planning, MET-JUS-04.
- **Réglages** : `Config.Justice.Rooms = { 'Salle 1', 'Salle 2' }`, `Config.Justice.Hearings.ReminderHours = 2`, `Config.Justice.Hearings.DaysAhead = 60`, `Config.Justice.Hearings.ProsecutorCanSchedule = false`.
- **Journal admin** : oui, `justice_audience` : création, report, annulation.
- **Performance** : vérification de conflit = une requête indexée (`room`, `at`) ; rappels calculés à l'ouverture de la tablette.
- **Cas limites** : participant hors ligne → notification gardée 7 jours ; partie retirée de l'affaire → retirée des audiences futures ; heure du serveur changée (fuseau) → les dates restent celles enregistrées (heure du serveur au moment de l'écriture).
- **Critères d'acceptation** :
  - Étant donné un juge, quand il fixe une audience demain 15 h salle 1, alors tous les participants cochés sont notifiés.
  - Étant donné la salle 1 réservée à 15 h, quand un autre juge réserve 15 h 15 salle 1, alors refus.
  - Étant donné un procureur (option désactivée), quand il envoie `justice:hearing:create`, alors refus.

### [MET-JUS-06] Prononcer un verdict (inscription au casier + signal « peine prononcée »)
- **But** : rendre la décision d'une affaire et l'inscrire automatiquement au casier.
- **Qui** : juge en service seulement (tableau des droits : « Justice : verdict » = Juge). Non réglable.
- **Où** : app Justice > affaire > onglet « Verdict » > « Prononcer le verdict ».
- **Parcours** :
  1. Pour chaque accusé : décision « Coupable », « Non coupable », « Relaxé » ; si coupable : infractions (sélection dans le code pénal de l'app Police, plusieurs), peine de prison en mois (0–`Config.Justice.Verdict.MaxPrisonMonths = 120`), amende (0–`Config.Justice.Verdict.MaxFine = 100000`), travaux d'intérêt général en heures (0–100), motivation (≤ 3 000, obligatoire).
  2. Les valeurs du code pénal sont proposées par défaut (somme des peines et amendes des infractions), modifiables dans les bornes.
  3. Récapitulatif + confirmation « Ce verdict est définitif. Confirmer ? ».
  4. `justice:verdict:create { caseId, decisions, actionId }`.
  5. Serveur, en transaction : enregistre le verdict ; pour chaque coupable, ajoute une entrée au casier (app Police) « Condamnation · affaire {numero} » avec infractions, peine, amende, juge ; crée l'amende dans Factures (type `amende_judiciaire`, émetteur « Trésor public », payable par le condamné, en attente de réveil si inconscient) ; affaire → `jugee`.
  6. Signal serveur émis pour chaque coupable via `exports.pop_tablet:EmitSentence(data)` de la base (BASE-API-08), qui émet `pop_tablet:sentencePronounced` ; `data` au format unique de BASE-API-08 : `{ identifier, source, jailMinutes = mois de prison, fine, communityService = heures, charges, judge = { identifier, name }, caseId = numéro d'affaire }` + `origin = 'justice'`. L'adaptateur prison est le réglage unique de la base `Config.Signals.SentenceJail` (fichiers `bridge/jail/`).
- **Données** (`pop_tablet_justice_verdicts`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | case_id | INT | oui | unique (1 verdict par affaire) | |
  | judge | VARCHAR(64) | oui | | |
  | decisions | JSON | oui | 1 par accusé `{ identifier, decision, offenses[], months, fine, community_hours }` | |
  | reasoning | TEXT | oui | 3 000 car. | |
  | created_at | DATETIME | oui | | NOW() |
- **Règles serveur** : rôle juge, juge désigné de l'affaire ou n'importe quel juge si l'affaire n'en a pas ; affaire non `jugee`/`classee` ; aucune contestation de preuve `ouverte` (MET-JUS-12, sinon refus `justice.verdict.contestations`) ; accord de repenti `homologue` d'un accusé → valeurs proposées et bornes multipliées par (1 − réduction / 100) (MET-JUS-13) ; preuves irrecevables affichées grisées dans le récapitulatif ; tous les accusés ont une décision ; bornes des peines ; infractions existantes dans le code pénal ; un seul verdict (contrainte unique) ; fréquence 1 / 30 s.
- **Textes et états** : vide « Aucun verdict pour l'instant. » (`justice.verdict.vide`) ; succès « Verdict prononcé. Casier mis à jour. » (`justice.verdict.succes`) ; décision manquante « Décision requise pour {nom}. » (`justice.verdict.manquant`) ; motivation vide `commun.erreur.champ_requis` ; déjà jugée « Cette affaire est déjà jugée. » (`justice.verdict.deja`) ; borne « La peine dépasse le maximum ({max}). » (`justice.verdict.borne`) ; pas le droit : onglet en lecture seule « Seul un juge peut prononcer le verdict. » (`justice.verdict.pas_juge`).
- **Notifications** : chaque accusé : « Verdict · affaire {numero} : {decision}. {peine} » (`justice.notif.verdict_accuse`), où {peine} = « Prison : {mois} mois. Amende : {montant}. » (`justice.notif.verdict_peine`) ; procureur, avocats, plaignants : « Verdict rendu dans l'affaire {numero}. » (`justice.notif.verdict_rendu`) ; police en service si prison > 0 : « Peine de prison prononcée contre {nom} : {mois} mois. » (`justice.notif.verdict_police`).
- **Liens** : Casier (app Police), Factures (amende), signal « peine prononcée », Code pénal (lecture, cache).
- **Réglages** : `Config.Justice.Verdict.MaxPrisonMonths = 120`, `Config.Justice.Verdict.MaxFine = 100000`, `Config.Justice.Verdict.MaxCommunityHours = 100`, `Config.Justice.Verdict.NotifyPolice = true`.
- **Journal admin** : oui, `justice_verdict` + Discord par défaut : verdict complet.
- **Performance** : une transaction ; code pénal en cache.
- **Cas limites** : accusé hors ligne → casier et amende enregistrés, notification et signal émis (le script de prison décide quoi faire d'un joueur hors ligne : le signal contient `online = false`) ; erreur de verdict → non modifiable dans la tablette, l'admin peut archiver le verdict et rouvrir l'affaire (journalisé) ; double clic → un seul verdict (contrainte unique + `actionId`).
- **Critères d'acceptation** :
  - Étant donné une affaire avec un accusé, quand le juge prononce « Coupable, 12 mois, 5 000 $ », alors le casier contient l'entrée, une amende de 5 000 $ est créée et le signal est émis avec `months = 12`.
  - Étant donné une affaire jugée, quand on tente un second verdict, alors refus.
  - Étant donné un procureur, quand il envoie `justice:verdict:create`, alors refus et journal `triche`.

### [MET-JUS-07] Valider ou refuser un mandat demandé par la police
- **But** : permettre au juge d'autoriser ou non un mandat (arrêt, perquisition) créé dans l'app Police.
- **Qui** : juge en service. Le Chef/Patron police valide aussi côté Police (`police.mandat.valider`) selon `Config.Police.Mandats.Validation = 'grade_ou_juge'` (défaut, fichier 03) ; avec `'juge'`, seul le juge valide.
- **Où** : app Justice > onglet « Mandats » (badge = nombre en attente).
- **Parcours** : c'est la même action et la même table que MET-POL-29 / MET-POL-30 (fichier 03, qui fait foi) ; l'app Justice n'en est qu'un deuxième écran.
  1. La police crée une demande (MET-POL-28) : type « Mandat d'arrêt » ou « Mandat de perquisition », citoyen, adresse, motif, infractions, rapport lié ; statut `attente`.
  2. Le juge voit la liste des mandats `attente` (date, type, cible, demandeur, motif), ouvre le détail (rapport lié consultable).
  3. « Signer et valider » → action `police.mandat.valider` (MET-POL-29) → statut `actif`, `valide_par`, `valide_role = 'juge'`, `expire_le` = maintenant + 7 jours (`Config.Police.Mandats.DureeJours = 7` ; mandat d'infiltration : maintenant + durée demandée, que le juge peut réduire, MET-POL-47), et **signature** du juge (`signe_le`, `signature_code` = `SIG-xxxxxxxx`, MET-POL-29 étape 6) affichée « Signé par le juge {nom} le {date} · {code} ». Perquisition et infiltration ne peuvent être validées que par un juge (`Config.Police.Mandats.JugeRequis`).
  4. « Refuser » : motif obligatoire (10–300 car.) → statut `refuse`.
  5. « Lever » un mandat actif (motif « Annulé » ou « Erreur ») et « Prolonger de 7 jours » (2 fois max) : actions de MET-POL-30, ouvertes au juge.
  6. Une demande non traitée passe `expire` au bout de 3 jours (`Config.Police.Mandats.AttenteMaxJours = 3`), calculé à la lecture.
- **Données** : table `pop_tablet_police_mandats` (fichier 03) ; aucune colonne en plus.
- **Règles serveur** : rôle juge en service ; mandat `attente` (ou `actif` pour lever / prolonger) ; un juge ne peut pas décider d'un mandat qui le vise ; fréquence 1 / 3 s ; premier qui décide gagne.
- **Textes et états** : vide « Aucun mandat en attente. » (`justice.mandats.vide`) ; bouton « Signer et valider » (`justice.mandats.signer`) ; signature « Signé par le juge {nom} le {date} · {code} » (`police.mandats.signe`) ; validé « Mandat {numero} validé. » (`police.mandats.valide`) ; refusé « Mandat {numero} refusé. » (`police.mandats.refuse`) ; déjà traité « Ce mandat vient d'être traité par {nom}. » (`justice.mandats.deja`) ; conflit « Impossible de statuer sur un mandat qui vous concerne. » (`justice.mandats.conflit`).
- **Notifications** : juges en service à la création : « Mandat demandé par {agent} : {type}. » (`justice.notif.mandat_demande`) ; demandeur et police : notifications de MET-POL-29.
- **Liens** : App Police (MET-POL-28 à 30), lien « Juge → mandats police » du contexte.
- **Réglages** : ceux de la police (`Config.Police.Mandats.*`, fichier 03) ; aucun réglage propre.
- **Journal admin** : oui, `mandat` : validation, refus, levée, prolongation (rôle `juge`).
- **Performance** : nombre en attente gardé en mémoire (badge) ; liste paginée.
- **Cas limites** : aucun juge en ligne → le Chef police valide (mode `grade_ou_juge`) ; sinon la demande expire au bout de 3 jours et le demandeur est prévenu « Mandat expiré sans décision. » (`justice.notif.mandat_expire`) ; deux juges décident en même temps → le premier gagne ; double clic → une décision.
- **Critères d'acceptation** :
  - Étant donné un mandat en attente, quand le juge le valide, alors le policier est prévenu et le mandat est « Actif » 7 jours avec « Signé par le juge {nom} le {date} · SIG-xxxxxxxx ».
  - Étant donné un refus sans motif, quand on valide le formulaire, alors refus.
  - Étant donné un avocat, quand il envoie la validation à la main, alors refus `pas_droit`.

### [MET-JUS-08] Gérer ses clients (avocat)
- **But** : établir la liste des clients d'un avocat, base de ce qu'il peut voir.
- **Qui** : avocat en service.
- **Où** : app Justice > onglet « Mes clients ».
- **Parcours** :
  1. « Ajouter un client » : soit un citoyen à moins de 3 m, soit depuis une Demande reçue par le Cabinet (type `contact` ou `rendez_vous`).
  2. → `justice:client:propose { targetToken, actionId }` ; le citoyen reçoit une proposition « {avocat} propose de vous représenter. » avec « Accepter » / « Refuser » (tablette, ou fenêtre simple sans tablette).
  3. Accepté → lien client `actif` ; l'avocat est proposé automatiquement sur les affaires (existantes et futures) où le client est partie, statut « en attente » de confirmation par l'avocat (MET-JUS-02).
  4. Liste : nom, depuis, affaires en cours, honoraires facturés.
  5. Fin : l'avocat (« Ne plus représenter ») ou le client (depuis sa notification ou l'annuaire > Cabinet > « Retirer mon avocat ») → lien `termine` ; l'avocat est retiré de toutes les affaires non jugées de ce client.
- **Données** (`pop_tablet_justice_clients`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | lawyer | VARCHAR(64) | oui | | |
  | company_id | INT | oui | cabinet | |
  | client | VARCHAR(64) | oui | | |
  | status | ENUM('propose','actif','refuse','termine') | oui | | 'propose' |
  | created_at / ended_at | DATETIME | | | |
- **Règles serveur** : rôle avocat ; distance ≤ 3 m pour une proposition directe (pas de distance depuis une Demande) ; un citoyen a au maximum `Config.Justice.Clients.MaxLawyers = 2` avocats actifs ; pas de doublon ; un avocat ne peut pas être son propre client ; proposition sans réponse sous 10 min → `refuse` à la lecture ; fréquence 1 / 10 s.
- **Textes et états** : vide « Aucun client. » (`justice.clients.vide`) ; proposition envoyée « Proposition envoyée à {nom}. » (`justice.clients.propose`) ; accepté « {nom} est maintenant votre client. » (`justice.clients.accepte`) ; refusé « {nom} a refusé la proposition. » (`justice.clients.refuse`) ; limite « Cette personne a déjà 2 avocats. » (`justice.clients.limite`) ; fin « Représentation de {nom} terminée. » (`justice.clients.fin`).
- **Notifications** : client : « {avocat} propose de vous représenter. » (`justice.notif.proposition`) ; avocat à la réponse (textes ci-dessus) ; avocat si le client met fin : « {nom} a mis fin à la représentation. » (`justice.notif.client_fin`).
- **Liens** : MET-JUS-02, MET-JUS-04 (visibilité), MET-JUS-09 (honoraires), Demandes.
- **Réglages** : `Config.Justice.Clients.MaxLawyers = 2`, `Config.Justice.Clients.ProposalMinutes = 10`, `Config.Justice.Clients.Distance = 3.0`.
- **Journal admin** : oui, `justice_client` : ajout et fin.
- **Performance** : liste paginée ; liens clients d'un avocat en cache mémoire pendant son service (pour filtrer les affaires vite).
- **Cas limites** : client hors ligne → proposition impossible en direct (« commun.erreur.hors_ligne »), possible depuis une Demande (notification gardée) ; avocat qui change de job → tous ses liens passent `termine` ; double clic → une proposition.
- **Critères d'acceptation** :
  - Étant donné un citoyen à 2 m, quand il accepte la proposition, alors il apparaît dans « Mes clients ».
  - Étant donné un client cité dans une affaire, quand l'avocat ouvre « Affaires » après confirmation, alors il voit l'affaire.
  - Étant donné un avocat qui envoie la proposition pour un citoyen à 40 m, alors refus distance.

### [MET-JUS-09] Facturer des honoraires d'avocat
- **But** : faire payer un client via l'app Factures.
- **Qui** : avocat en service ; Recrue du Cabinet plafonnée (`Config.Justice.Fees.RecruitMax = 2000`), Membre+ jusqu'à `Config.Justice.Fees.Max = 50000`.
- **Où** : app Justice > « Mes clients » > client > « Facturer des honoraires ».
- **Parcours** : objet (≤ 80, ex. « Défense affaire AFF-2026-0012 »), affaire liée (facultatif, parmi celles du client), montant → `justice:fee:create { clientId, amount, label, caseId, actionId }` ; serveur crée la facture dans Factures (type `honoraires`, émetteur = Cabinet, part avocat selon Factures) ; présentée au client (tablette ou fenêtre simple ; attente du réveil si inconscient).
- **Données** : lignes Factures `{ label, qty = 1, unit_price = amount }` + `case_id`.
- **Règles serveur** : lien client `actif` ; montant entier 1–max, plafond Recrue ; pas de distance (client consentant) ; 1 facture / 30 s par avocat ; 5 factures d'honoraires impayées max par client et par avocat.
- **Textes et états** : succès « Facture d'honoraires envoyée : {montant}. » (`justice.honoraires.succes`) ; plafond « Montant trop élevé pour ce grade (maximum {max}). » (`justice.honoraires.plafond`) ; pas client « Cette personne n'est pas votre client. » (`justice.honoraires.pas_client`) ; limite « Ce client a déjà 5 factures impayées. » (`justice.honoraires.limite`).
- **Notifications** : client : « Honoraires de {avocat} : {montant}. » (`justice.notif.honoraires`) ; avocat au paiement : « {nom} a réglé vos honoraires ({montant}). » (`justice.notif.honoraires_payes`).
- **Liens** : Factures, Compte entreprise, signal `pop_tablet:invoicePaid`.
- **Réglages** : `Config.Justice.Fees.Max = 50000`, `Config.Justice.Fees.RecruitMax = 2000`, `Config.Justice.Fees.MaxUnpaid = 5`.
- **Journal admin** : oui, `facture` (par Factures).
- **Performance** : une écriture.
- **Cas limites** : client hors ligne → facture visible à la reconnexion ; lien client terminé après facture → la facture reste due ; double clic → une facture.
- **Critères d'acceptation** :
  - Étant donné un client actif, quand j'envoie 3 000 $ d'honoraires, alors il reçoit la facture et le Cabinet est crédité au paiement.
  - Étant donné une Recrue, quand elle facture 5 000 $, alors refus.
  - Étant donné un avocat qui facture un citoyen qui n'est pas son client en forgeant l'événement, alors refus et journal `triche`.

### [MET-JUS-10] Effacer un casier judiciaire (décision du juge, archivage)
- **But** : retirer des entrées du casier visible par la police, sur décision d'un juge, sans rien supprimer.
- **Qui** : juge en service seulement (en plus du Patron police côté app Police selon le tableau des droits).
- **Où** : app Justice > onglet « Casiers » > recherche citoyen > « Effacer des entrées ».
- **Parcours** :
  1. Recherche du citoyen par nom ; affichage de son casier (lecture via l'app Police).
  2. Cocher les entrées à effacer (ou « Tout le casier ») ; motif (« Réhabilitation », « Erreur judiciaire », « Amnistie », « Autre ») + motivation (20–1 000 car.) ; affaire liée facultative.
  3. Confirmation « Les entrées cochées ne seront plus visibles par la police. Confirmer ? ».
  4. `justice:record:expunge { citizenToken, entryIds, reason, text, actionId }` ; serveur passe chaque entrée à `efface` (champ `expunged_by`, `expunged_at`, `expunge_reason`), crée une « Décision d'effacement » numérotée `EFF-AAAA-NNNN`.
  5. Les entrées effacées disparaissent pour la police ; visibles seulement par les juges (avec la mention « Effacée le {date} ») et l'admin.
  6. Annulation : l'admin seul peut restaurer (branche Admin).
- **Données** (`pop_tablet_justice_expunges` + champs ajoutés à la table du casier) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | number | VARCHAR(16) | oui | unique | |
  | citizen | VARCHAR(64) | oui | | |
  | entry_ids | JSON | oui | 1 à 200 | |
  | reason | ENUM('rehabilitation','erreur','amnistie','autre') | oui | | |
  | text | VARCHAR(1000) | oui | 20–1 000, nettoyé | |
  | judge | VARCHAR(64) | oui | | |
  | created_at | DATETIME | oui | | NOW() |
  Casier : `expunged BOOL DEFAULT 0`, `expunged_by`, `expunged_at`, `expunge_ref`.
- **Règles serveur** : rôle juge ; entrées appartenant bien au citoyen et non déjà effacées ; motivation 20–1 000 ; fréquence 1 / 30 s.
- **Textes et états** : vide casier « Casier vierge. » (`justice.casier.vierge`) ; succès « {n} entrée(s) effacée(s). Décision {numero}. » (`justice.casier.efface`) ; aucune case « Au moins une entrée requise. » (`justice.casier.aucune`) ; motivation courte « Motivation requise (20 caractères minimum). » (`justice.casier.motif_court`) ; pas le droit : onglet caché.
- **Notifications** : citoyen : « Casier mis à jour par décision de justice ({numero}). » (`justice.notif.casier_efface`).
- **Liens** : Casier (app Police : filtre `expunged = 0` pour la police), MET-JUS-04.
- **Réglages** : `Config.Justice.Expunge.JudgesSeeExpunged = true`.
- **Journal admin** : oui, `casier` + Discord par défaut : décision complète (entrées avant/après).
- **Performance** : mise à jour groupée (`UPDATE ... WHERE id IN (...)`), une transaction.
- **Cas limites** : entrée liée à une amende impayée → l'entrée est effacée, l'amende reste due (Factures) ; police qui consulte au même instant → voit l'état d'avant jusqu'au rechargement ; entrée déjà effacée envoyée → ignorée, compte réel affiché.
- **Critères d'acceptation** :
  - Étant donné un casier de 3 entrées, quand le juge en efface 2, alors la police n'en voit plus qu'1.
  - Étant donné une entrée effacée, quand un juge ouvre le casier, alors il la voit marquée « Effacée le {date} ».
  - Étant donné un procureur, quand il envoie `justice:record:expunge`, alors refus et journal `triche`.

### [MET-JUS-11] Classer une affaire sans suite (ajout)
- **But** : clore une affaire qui ne sera pas jugée (abandon des poursuites, accord entre parties).
- **Qui** : procureur ou juge de l'affaire ; pour une affaire civile ouverte par un avocat, cet avocat peut la classer s'il n'y a pas d'audience prévue.
- **Où** : app Justice > affaire > « Classer l'affaire ».
- **Parcours** : motif (« Abandon des poursuites », « Accord entre les parties », « Preuves insuffisantes », « Autre ») + texte (20–1 000) → affaire `classee` ; audiences futures `annulee` avec notification ; rien n'est inscrit au casier ; réouverture possible par un juge (« Rouvrir », motif obligatoire) → `ouverte`.
- **Données** : `closed_reason ENUM(...)`, `closed_text VARCHAR(1000)`, `closed_by`, `closed_at` dans `pop_tablet_justice_cases`.
- **Règles serveur** : rôle selon ci-dessus ; affaire non `jugee` ; texte 20–1 000 ; 1 / 10 s.
- **Textes et états** : succès « Affaire classée. » (`justice.affaires.classee`) ; rouverte « Affaire rouverte. » (`justice.affaires.rouverte`) ; déjà jugée « Une affaire jugée ne peut pas être classée. » (`justice.affaires.classement_impossible`).
- **Notifications** : parties et intervenants : « L'affaire {numero} est classée sans suite. » (`justice.notif.classee`).
- **Liens** : MET-JUS-05 (annulation des audiences).
- **Réglages** : aucun.
- **Journal admin** : oui, `justice_affaire` : classement, réouverture.
- **Performance** : une transaction.
- **Cas limites** : audience en cours au moment du classement → annulée ; double clic → une action ; affaire déjà classée → « Déjà classée. » (`justice.affaires.deja_classee`).
- **Critères d'acceptation** :
  - Étant donné une affaire ouverte avec une audience prévue, quand le procureur la classe, alors l'audience passe « Annulée » et les participants sont prévenus.
  - Étant donné une affaire jugée, quand on tente de la classer, alors refus.
  - Étant donné un avocat non auteur de l'affaire, quand il envoie le classement, alors refus.

### [MET-JUS-12] Contester une preuve (avocat) et trancher (juge)
- **But** : permettre à l'avocat d'une partie de contester une preuve de l'affaire (obtention, chaîne de possession, authenticité) et au juge de décider si elle est recevable.
- **Qui** : déposer : avocat `confirme` d'une partie de l'affaire, en service ; observations : procureur de l'affaire ; trancher : juge de l'affaire (ou tout juge si l'affaire n'en a pas), en service. Non réglable.
- **Où** : app Justice > affaire > onglet « Pièces » > preuve > bouton « Contester » (avocat) ; onglet « Contestations » de l'affaire (juge, procureur, avocats).
- **Parcours** :
  1. L'avocat ouvre la preuve (sa chaîne de possession est lisible, MET-JUS-03) et clique « Contester » : motif (liste : « Obtenue sans mandat valide », « Chaîne de possession rompue », « Preuve falsifiée ou modifiée », « Autre »), argumentaire (20 à 2 000 car.), éléments cités de la chaîne de possession (cases à cocher sur ses lignes, 10 max) → `justice:evidence:contest { caseId, evidenceId, reason, text, journalIds, actionId }`.
  2. Serveur : contestation `ouverte` ; la preuve passe `recevable = 'contestee'` (l'ancienne valeur est gardée dans la contestation) ; ligne `contestation` dans la chaîne de possession ; notification au juge et au procureur.
  3. Le procureur peut ajouter une fois ses observations (≤ 2 000 car.) → `justice:evidence:observe`.
  4. Le juge clique « Trancher » : décision « Recevable » ou « Irrecevable » + motivation (20 à 1 000 car.) → `justice:evidence:decide { contestId, decision, text, actionId }` → la preuve prend `recevable` = décision, `recevabilite_motif` = motivation ; ligne `decision_juge` dans la chaîne de possession ; contestation `rejetee` (preuve recevable) ou `acceptee` (preuve irrecevable).
  5. Tant qu'une contestation est `ouverte`, le verdict de l'affaire est bloqué (MET-JUS-06 : « Tranchez d'abord les contestations en cours. »).
  6. Une décision est définitive dans la tablette ; une nouvelle contestation de la même preuve n'est possible qu'avec un motif différent (1 par motif et par avocat).
- **Données** (`pop_tablet_justice_contests`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | case_id | INT | oui | | |
  | evidence_id | INT | oui | `pop_tablet_police_preuves.id` liée à l'affaire | |
  | lawyer | VARCHAR(64) | oui | avocat confirmé | |
  | reason | ENUM('sans_mandat','chaine_rompue','falsification','autre') | oui | | |
  | text | TEXT | oui | 20 à 2 000 car., nettoyé | |
  | journal_ids | JSON | non | 10 max | [] |
  | previous | ENUM('recevable','irrecevable') | oui | valeur avant contestation | |
  | observations | TEXT | non | 2 000 car. | NULL |
  | status | ENUM('ouverte','acceptee','rejetee') | oui | | 'ouverte' |
  | decided_by / decision_text / decided_at | VARCHAR(64) / VARCHAR(1000) / DATETIME | non | | NULL |
  | created_at | DATETIME | oui | | NOW() |
- **Règles serveur** : rôle et service vérifiés ; preuve liée à l'affaire ; affaire ni `jugee` ni `classee` ; avocat `confirme` sur une partie de l'affaire ; une contestation `ouverte` max par preuve ; le juge qui tranche n'est pas partie ; recevabilité modifiable seulement par cette fiche (jamais par la police ni le client) ; fréquence 1 / 10 s.
- **Textes et états** : bouton « Contester » (`justice.contestation.contester`) ; motifs « Obtenue sans mandat valide » (`justice.contestation.motif.sans_mandat`), « Chaîne de possession rompue » (`…motif.chaine_rompue`), « Preuve falsifiée ou modifiée » (`…motif.falsification`), « Autre » (`…motif.autre`) ; vide « Aucune contestation. » (`justice.contestation.vide`) ; succès dépôt « Contestation déposée. » (`justice.contestation.deposee`) ; succès décision « Décision enregistrée : preuve {decision}. » (`justice.contestation.decidee`) ; déjà ouverte « Une contestation est déjà en cours sur cette preuve. » (`justice.contestation.deja`) ; verdict bloqué « Tranchez d'abord les contestations en cours. » (`justice.verdict.contestations`) ; statuts « En cours » (`justice.contestation.statut.ouverte`), « Acceptée » (`…statut.acceptee`), « Rejetée » (`…statut.rejetee`).
- **Notifications** : juge et procureur : « Contestation déposée sur la preuve {numero} (affaire {affaire}). » (`justice.notif.contestation`) ; avocat, procureur et agent responsable de la preuve à la décision : « Preuve {numero} déclarée {decision} par le juge. » (`justice.notif.contestation_decidee`).
- **Liens** : MET-POL-36 (recevabilité, chaîne de possession), MET-JUS-03 (pièces), MET-JUS-06 (verdict bloqué tant qu'une contestation est ouverte).
- **Réglages** : `Config.Justice.Contests.MaxPerEvidence = 4` (une par motif).
- **Journal admin** : oui, `justice_affaire` : dépôt, observations, décision (avant/après de la recevabilité).
- **Performance** : une écriture par action ; onglet « Contestations » paginé 20 ; aucune boucle.
- **Cas limites** : affaire jugée pendant que la contestation est ouverte → impossible (verdict bloqué) ; avocat qui perd la représentation → sa contestation reste et le juge la tranche ; preuve archivée par la police → contestation tranchable, preuve affichée « Archivée par la police ».
- **Critères d'acceptation** :
  - Étant donné un avocat confirmé, quand il conteste une preuve « Chaîne de possession rompue », alors la preuve passe « Contestée » et le juge est notifié.
  - Étant donné une contestation ouverte, quand le juge tente de prononcer le verdict, alors il voit « Tranchez d'abord les contestations en cours. ».
  - Étant donné le juge qui tranche « Irrecevable », quand on ouvre la preuve, alors elle affiche « Irrecevable : {motivation} » et la chaîne de possession contient la décision.
  - Étant donné un procureur qui envoie `justice:evidence:decide` à la main, quand le serveur le reçoit, alors il refuse `pas_droit` et la recevabilité ne change pas.

### [MET-JUS-13] Accord de repenti (peine réduite contre informations ou témoignage)
- **But** : permettre au procureur de proposer à un accusé un accord écrit (peine réduite contre informations ou témoignage), signé par l'accusé dans la tablette ou en fenêtre simple, puis homologué par le juge.
- **Qui** : proposer, retirer, demander la révocation : procureur de l'affaire, en service ; signer ou refuser : l'accusé visé (aucun droit ni service) ; lire : avocats confirmés de l'accusé ; homologuer, refuser, révoquer : juge de l'affaire (ou tout juge si l'affaire n'en a pas). Non réglable.
- **Où** : app Justice > affaire pénale > onglet « Accords » > « Proposer un accord de repenti » ; côté accusé : notification → écran « Accord proposé » (ouvert depuis la notification, sans l'app Justice) ; sans tablette : fenêtre simple « Présenter en personne ».
- **Parcours** :
  1. Le procureur remplit : accusé (parmi les parties « Accusé »), engagements de l'accusé (20 à 2 000 car. : informations à fournir, témoignage à l'audience), contrepartie : « Réduction de peine » en % (10 à `Config.Justice.Repenti.MaxReduction = 75`, défaut 50) appliquée à la prison et à l'amende, conditions de révocation (≤ 1 000 car.), validité de l'offre (1 à 72 h, défaut 24 h) → `justice:deal:propose { caseId, identifier, terms, reduction, revokeTerms, hours, actionId }` → statut `proposee` ; le serveur fige le texte et calcule son empreinte (`text_hash` = SHA-256 du texte complet).
  2. L'accusé reçoit la notification ; l'écran « Accord proposé » montre le texte complet, la réduction, la date limite, et les boutons « Signer » / « Refuser ». « Signer » demande de taper son nom RP exact (« Prénom Nom ») et de cocher « J'ai lu et j'accepte cet accord. » → `justice:deal:sign { dealId, typedName, actionId }`.
  3. Sans tablette : le procureur ou l'avocat de l'accusé clique « Présenter en personne » (accusé à ≤ 3 m) → fenêtre simple (BASE-MOT-14) : texte complet défilant, réduction, « Signer » / « Refuser » ; 120 s sans réponse = rien n'est signé ; la fenêtre se renvoie 1 fois / 30 s.
  4. Signature : le serveur vérifie que le signataire est bien l'accusé (identifiant), que le nom tapé correspond (sans tenir compte des majuscules et accents), que l'offre n'a pas expiré ; il enregistre `signed_at` et `signature_code` = `SIG-` + 8 caractères de `HMAC-SHA256(clé serveur, dealId .. identifier .. text_hash .. signed_at)` → statut `signee` ; juge et procureur notifiés.
  5. Le juge ouvre l'accord signé : « Homologuer » ou « Refuser l'homologation » (motivation ≤ 1 000 car.) → `homologue` ou `refuse_juge`.
  6. Au verdict (MET-JUS-06), pour un accusé avec un accord `homologue`, les valeurs proposées et les bornes maximales de prison et d'amende sont multipliées par (1 − réduction / 100), arrondies à l'entier inférieur ; le récapitulatif affiche « Accord de repenti homologué : peine réduite de {n} %. ».
  7. Révocation (avant le verdict) : le procureur « Demande la révocation » (motif ≤ 1 000) → le juge décide → `revoque` (la réduction ne s'applique plus) ou maintien. Le procureur peut « Retirer » une offre `proposee` non signée → `retiree`.
- **Données** (`pop_tablet_justice_deals`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | case_id | INT | oui | affaire pénale | |
  | identifier | VARCHAR(64) | oui | partie « Accusé » | |
  | prosecutor | VARCHAR(64) | oui | | |
  | terms | TEXT | oui | 20 à 2 000 car., nettoyé | |
  | revoke_terms | VARCHAR(1000) | non | nettoyé | '' |
  | reduction | TINYINT | oui | 10 à 75 | 50 |
  | text_hash | CHAR(64) | oui | SHA-256 du texte figé | |
  | status | ENUM('proposee','signee','homologue','refuse_accuse','refuse_juge','expiree','retiree','revoque') | oui | | 'proposee' |
  | expires_at | DATETIME | oui | 1 à 72 h | +24 h |
  | signed_at / signature_code | DATETIME / VARCHAR(12) | non | | NULL |
  | judge / judge_text / judged_at | VARCHAR(64) / VARCHAR(1000) / DATETIME | non | | NULL |
- **Règles serveur** : rôle et service (procureur, juge) ; affaire pénale ni `jugee` ni `classee` ; un seul accord `proposee`, `signee` ou `homologue` par accusé et par affaire ; texte figé dès la proposition (aucune modification : retirer et reproposer) ; signature uniquement par l'accusé, jamais par un tiers ni par le client pour un autre ; offre expirée calculée à la lecture ; distance ≤ 3 m pour « Présenter en personne » ; fréquence 1 / 10 s.
- **Textes et états** : onglet « Accords » (`justice.accord.onglet`) ; vide « Aucun accord. » (`justice.accord.vide`) ; bouton « Proposer un accord de repenti » (`justice.accord.proposer`) ; écran accusé « Accord proposé » (`justice.accord.titre_accuse`) ; case « J'ai lu et j'accepte cet accord. » (`justice.accord.case`) ; champ « Tapez votre nom complet pour signer » (`justice.accord.nom`) ; succès « Accord proposé. » (`justice.accord.propose_ok`), « Accord signé. » (`justice.accord.signe_ok`), « Accord homologué. » (`justice.accord.homologue_ok`) ; erreurs « Le nom ne correspond pas. » (`justice.accord.nom_faux`), « Offre expirée. » (`justice.accord.expire`), « Un accord est déjà en cours pour cet accusé. » (`justice.accord.deja`) ; récapitulatif verdict « Accord de repenti homologué : peine réduite de {n} %. » (`justice.accord.reduction`) ; statuts (`justice.accord.statut.<statut>`) : « Proposé », « Signé », « Homologué », « Refusé par l'accusé », « Refusé par le juge », « Expiré », « Retiré », « Révoqué ».
- **Notifications** : accusé : « Accord proposé · affaire {numero}. Réponse avant le {date}. » (`justice.notif.accord_propose`) ; avocats de l'accusé : « Un accord a été proposé à votre client {nom}. » (`justice.notif.accord_avocat`) ; juge et procureur à la signature : « Accord signé par {nom} (affaire {numero}). » (`justice.notif.accord_signe`) ; procureur et accusé à l'homologation, au refus ou à la révocation : « Accord {statut} (affaire {numero}). » (`justice.notif.accord_statut`).
- **Liens** : MET-JUS-02 (parties), MET-JUS-06 (réduction au verdict), BASE-MOT-14 (fenêtre simple), MET-JUS-08 (avocats).
- **Réglages** : `Config.Justice.Repenti.Enabled = true`, `Config.Justice.Repenti.MaxReduction = 75`, `Config.Justice.Repenti.DefaultReduction = 50`, `Config.Justice.Repenti.OfferHours = 24`, `Config.Justice.Repenti.PromptSeconds = 120`.
- **Journal admin** : oui, `justice_affaire` : proposition, signature (code), homologation, refus, révocation ; Discord catégorie `police`.
- **Performance** : une écriture par étape ; onglet chargé au clic ; aucune boucle (expiration à la lecture).
- **Cas limites** : accusé hors ligne → notification gardée 7 jours, l'offre peut expirer avant ; accusé mort (`Bridge.IsDead`) → fenêtre simple non affichée, proposée à son réveil ; double clic sur « Signer » → une signature (`actionId`) ; verdict prononcé alors que l'accord est seulement `signee` → la réduction ne s'applique pas (homologation requise) et le juge est averti avant de confirmer.
- **Critères d'acceptation** :
  - Étant donné un accord à 50 % homologué et un code pénal proposant 40 mois et 10 000 $, quand le juge ouvre le verdict, alors il voit 20 mois et 5 000 $ proposés et des bornes réduites de moitié.
  - Étant donné un accusé sans tablette à 2 m, quand le procureur clique « Présenter en personne » et que l'accusé signe, alors l'accord passe « Signé » avec un code `SIG-xxxxxxxx`.
  - Étant donné un accord signé, quand le juge refuse l'homologation, alors aucune réduction ne s'applique au verdict.
  - Étant donné un autre joueur qui envoie `justice:deal:sign` pour cet accord, quand le serveur le reçoit, alors il refuse et la tentative est journalisée (`triche`).

---

# Gang

Principe : un gang est une entreprise de modèle `gang` créée par l'admin dans le créateur d'entreprises (fichier 05, SITE-CRE-04 à 06 ; nom, couleur d'accent, rangs). Dans les tables de gang, `gang_id` = `pop_tablet_companies.id` de cette entreprise ; `pop_tablet_gangs` (clé primaire `gang_id`) ne porte que les réglages propres au gang (`vault`, code d'accès) ; les rangs de gang (`pop_tablet_gang_ranks`) remplacent les niveaux Recrue/Membre/Chef/Patron pour l'app Gang. L'appartenance est gérée par la tablette (`Config.Gang.Source = 'tablet'`, cf. Conventions §2) ; avec `'job'` ou `'job2'`, la liste des membres suit le job ESX et les fiches Recruter/Exclure modifient ce job. Les données du gang sont liées au **personnage**, jamais à l'objet tablette. L'app Gang n'a pas de prise de service.

Rangs par défaut (4 niveaux du contexte, libellés propres au gang) : « Recrue » (Recrue) · « Soldat » (Membre) · « Lieutenant » (Chef) · « Chef » (Patron). Le Chef renomme les rangs et règle les droits case par case.

| Action gang | Recrue | Soldat | Lieutenant | Chef |
|---|---|---|---|---|
| Lire la messagerie / écrire | Oui | Oui | Oui | Oui |
| Voir la liste des membres | Oui | Oui | Oui | Oui |
| Voir le coffre (solde + mouvements) | Non | Oui | Oui | Oui |
| Déposer au coffre | Oui | Oui | Oui | Oui |
| Retirer du coffre | Non | Non | Plafonné | Oui |
| Recruter | Non | Non | Oui | Oui |
| Exclure / changer de rang | Non | Non | Sous son rang | Oui |
| Régler l'icône, les rangs | Non | Non | Non | Oui |
| Lire le livre de comptes (MET-GANG-11) | Non | Non | Oui | Oui |
| Écrire dans le livre de comptes | Non | Non | Oui | Oui |
| Voir la carte des territoires | Oui | Oui | Oui | Oui |

### [MET-GANG-01] Voir les membres et les rangs
- **But** : connaître les membres du gang, leur rang et s'ils sont en ville.
- **Qui** : tout membre dès Recrue.
- **Où** : app Gang (une fois déverrouillée, MET-GANG-10) > onglet « Membres ».
- **Parcours** :
  1. Ouverture → `gang:members:list { page }`.
  2. Serveur renvoie : surnom (affiché à la place du vrai nom si renseigné), rang, en ville oui/non (pastille), date d'entrée. Le vrai nom du personnage n'est visible que du Chef.
  3. Chaque membre peut régler son surnom (≤ 24 car.) depuis « Mon profil ».
  4. Le Chef a l'écran « Rangs » : renommer les 4 rangs (≤ 24 car.), cocher les droits du tableau ci-dessus, plafond de retrait du Lieutenant.
- **Données** (`pop_tablet_gang_members`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | gang_id | INT | oui | | |
  | identifier | VARCHAR(64) | oui | unique (1 gang max par personnage) | |
  | rank | TINYINT | oui | 1 à 4 | 1 |
  | nickname | VARCHAR(24) | non | nettoyé | '' |
  | pin_hash | VARCHAR(128) | non | cf. MET-GANG-10 | NULL |
  | joined_at | DATETIME | oui | | NOW() |
  | status | ENUM('actif','exclu','parti') | oui | | 'actif' |
  Rangs/droits : `pop_tablet_gang_ranks (gang_id, rank, label, perms JSON, withdraw_cap INT)`.
- **Règles serveur** : membre `actif` et session déverrouillée (MET-GANG-10) pour toute requête gang ; un personnage appartient à un seul gang ; fréquence 1 / 2 s ; droits de l'écran « Rangs » = Chef.
- **Textes et états** : vide (impossible, au moins le Chef) « Aucun membre. » (`gang.membres.vide`) ; en ville « En ville » (`gang.membres.en_ville`), absent « Absent » (`gang.membres.absent`) ; surnom enregistré `commun.succes.enregistre` ; rangs enregistrés « Rangs enregistrés. » (`gang.rangs.succes`).
- **Notifications** : aucune.
- **Liens** : MET-GANG-02, 03.
- **Réglages** : `Config.Gang.Source = 'tablet'`, `Config.Gang.DefaultRanks = { 'Recrue', 'Soldat', 'Lieutenant', 'Chef' }`, `Config.Gang.MaxMembers = 40`.
- **Journal admin** : oui pour la modification des rangs/droits (`gang`, avant/après) ; jamais le contenu des messages.
- **Performance** : liste des membres du gang en cache serveur (invalidée à chaque recrutement/exclusion) ; « en ville » calculé depuis la liste des joueurs connectés en mémoire.
- **Cas limites** : membre supprimé de la base ESX → ligne `parti` au démarrage ; Chef seul qui se rétrograde → refus « Le gang doit garder un Chef. » (`gang.rangs.dernier_chef`) ; surnom avec HTML → nettoyé.
- **Critères d'acceptation** :
  - Étant donné un gang de 5 membres, quand j'ouvre « Membres », alors je vois 5 lignes avec surnom et rang.
  - Étant donné un Soldat, quand il ouvre la liste, alors il ne voit pas les vrais noms.
  - Étant donné un non-membre, quand il envoie `gang:members:list`, alors refus et aucune donnée.

### [MET-GANG-02] Recruter un membre
- **But** : faire entrer un joueur dans le gang.
- **Qui** : Lieutenant et Chef (droit `gang.recruit`, réglable).
- **Où** : app Gang > « Membres » > « Recruter ».
- **Parcours** :
  1. Liste des joueurs à moins de 3 m (nom visible seulement par proximité, pas de recherche à distance).
  2. → `gang:recruit:propose { targetToken, actionId }`.
  3. La cible reçoit une fenêtre simple (même avec tablette, pour ne rien laisser dans ses notifications) : « {surnom du recruteur} vous propose de rejoindre « {gang} ». » « Accepter » / « Refuser », 60 s.
  4. Accepté → ligne membre rang 1 ; si `Source = 'job'`/`'job2'`, le métier (ou second métier) est changé par le bridge (grade 0) ; si `Source = 'gang'`, le gang natif QBCore / Qbox est attribué (grade 0) ; l'app Gang apparaît sur sa tablette sous l'icône déguisée, et lui demande de créer son code au premier lancement (MET-GANG-10).
- **Données** : `pop_tablet_gang_members` (cf. MET-GANG-01).
- **Règles serveur** : droit ; distance ≤ 3 m (`Config.Gang.RecruitDistance = 3.0`) ; cible sans gang ; cible n'a pas un job de `Config.Gang.ForbiddenJobs = { 'police', 'ambulance', 'justice' }` (réglable, vide pour désactiver) ; nombre de membres < `MaxMembers` ; fréquence 1 / 30 s ; une cible ne reçoit qu'une proposition à la fois.
- **Textes et états** : aucun joueur proche « Personne à moins de 3 m. » (`gang.recruter.personne`) ; succès « {nom} a rejoint le gang. » (`gang.recruter.succes`) ; refus « {nom} a refusé. » (`gang.recruter.refuse`) ; déjà dans un gang « Cette personne fait déjà partie d'un groupe. » (`gang.recruter.deja`) ; job interdit « Cette personne ne peut pas être recrutée. » (`gang.recruter.interdit`) ; plein « Le gang est complet ({max} membres). » (`gang.recruter.complet`).
- **Notifications** : membres connectés : « {surnom} a rejoint le gang. » (`gang.notif.nouveau_membre`) — notification affichée sous le nom de l'icône déguisée (« Météo » / « Calculatrice ») avec le texte neutre « Nouvelle mise à jour disponible. » (`gang.notif.neutre`) ; le vrai texte n'est visible qu'en ouvrant l'app déverrouillée.
- **Liens** : MET-GANG-10.
- **Réglages** : `Config.Gang.RecruitDistance = 3.0`, `Config.Gang.ForbiddenJobs = { 'police', 'ambulance', 'justice' }`, `Config.Gang.MaxMembers = 40`.
- **Journal admin** : oui, `gang` : recrutement (gang, recruteur, recrue).
- **Performance** : une écriture ; cache des membres invalidé.
- **Cas limites** : cible qui s'éloigne avant de répondre → le serveur revérifie la distance à l'acceptation, refus si > 3 m ; cible sans réponse en 60 s → refus ; ancien membre exclu → peut être recruté de nouveau (nouvelle ligne `actif`, l'ancienne reste `exclu`).
- **Critères d'acceptation** :
  - Étant donné un joueur à 2 m sans gang, quand il accepte, alors il apparaît comme « Recrue » et l'icône déguisée apparaît sur sa tablette.
  - Étant donné un joueur policier, quand on le propose, alors refus « ne peut pas être recruté ».
  - Étant donné un Soldat, quand il envoie `gang:recruit:propose`, alors refus.

### [MET-GANG-03] Exclure un membre ou changer son rang
- **But** : promouvoir, rétrograder ou exclure ; un membre peut aussi quitter le gang.
- **Qui** : Chef (tous) ; Lieutenant sur les rangs inférieurs au sien (réglable) ; chaque membre pour lui-même (« Quitter le gang »).
- **Où** : app Gang > « Membres » > membre > « Changer de rang » / « Exclure » ; « Mon profil » > « Quitter le gang ».
- **Parcours** :
  1. Changer de rang : choix du rang → `gang:member:setRank` → mise à jour, notification.
  2. Exclure : confirmation « Exclure {surnom} ? » → statut `exclu` ; si `Source = 'job'`, métier remis à `unemployed` par le bridge ; si `Source = 'gang'`, gang natif QBCore / Qbox retiré (`none`) ; l'app disparaît de sa tablette au prochain affichage de l'accueil (le serveur pousse `gang:revoked` s'il est connecté, ce qui ferme l'app si elle est ouverte).
  3. Quitter : confirmation « Quitter le gang ? » → statut `parti`.
  4. Pas de distance requise.
- **Données** : `rank`, `status` de `pop_tablet_gang_members`.
- **Règles serveur** : droits ; un Lieutenant ne peut ni promouvoir au-dessus de son propre rang moins un, ni toucher un rang ≥ au sien ; le dernier Chef ne peut ni partir ni être rétrogradé (il doit d'abord nommer un autre Chef) ; fréquence 1 / 5 s.
- **Textes et états** : succès rang « {surnom} est maintenant {rang}. » (`gang.membres.rang_ok`) ; exclusion « {surnom} a été exclu. » (`gang.membres.exclu`) ; départ « Gang quitté. » (`gang.membres.parti`) ; refus rang « Impossible de modifier un membre de rang égal ou supérieur. » (`gang.membres.rang_interdit`) ; dernier chef `gang.rangs.dernier_chef`.
- **Notifications** : membre concerné (texte neutre en notification, cf. MET-GANG-02) : « Rang : {rang}. » (`gang.notif.rang`) ; exclu : aucune notification (l'app disparaît simplement).
- **Liens** : MET-GANG-06 (un exclu ne peut plus retirer).
- **Réglages** : aucun en plus.
- **Journal admin** : oui, `gang` : changement de rang, exclusion, départ.
- **Performance** : une écriture, cache invalidé.
- **Cas limites** : membre exclu pendant qu'il a l'app ouverte → fermeture immédiate et retour à l'accueil ; exclu déconnecté → app absente à sa reconnexion ; double clic → une action.
- **Critères d'acceptation** :
  - Étant donné un Chef, quand il exclut un Soldat, alors l'app Gang disparaît de la tablette du Soldat.
  - Étant donné un Lieutenant, quand il tente de rétrograder un autre Lieutenant, alors refus.
  - Étant donné un membre exclu, quand il envoie une requête gang, alors refus.

### [MET-GANG-04] Messagerie du gang
- **But** : échanger des messages entre membres ; les messages ne sont jamais effacés (décision du client).
- **Qui** : tout membre dès Recrue ; retirer un message : son auteur seulement ; lecture secrète par la police seulement avec un mandat d'infiltration actif (MET-POL-47).
- **Où** : app Gang > onglet « Messages » (fil unique du gang).
- **Parcours** :
  1. Ouverture → `gang:msg:list { before }` : les 20 derniers messages non retirés, du plus ancien au plus récent ; « Charger plus » affiche les 20 précédents (`Config.Limits.PageSize = 20`).
  2. Écrire (≤ 300 car.) + Entrée → `gang:msg:send { text, actionId }` ; le serveur nettoie, enregistre, pousse le message aux membres connectés **qui ont l'app ouverte et déverrouillée** (abonnement) ; les autres reçoivent la notification neutre. Si un mandat d'infiltration est actif sur ce gang (MET-POL-47), le message est aussi poussé aux agents abonnés à l'écran d'infiltration, sans rien changer côté gang.
  3. Chaque message affiche le surnom de l'auteur, la date et l'heure (« 24/11/2026 18:05 »).
  4. « Retirer » (sur ses propres messages, confirmation) → `gang:msg:withdraw { messageId, actionId }` : le message n'est pas effacé ; il est archivé (`withdrawn = 1`, `withdrawn_at`), disparaît pour tous les membres et pour la police, et reste visible par l'admin seulement (Admin > Archives). Un message retiré ne peut pas être remis.
  5. Pas d'images, pas de liens cliquables (texte brut).
- **Données** (`pop_tablet_gang_messages`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | BIGINT AUTO_INCREMENT | oui | | |
  | gang_id | INT | oui | index (`gang_id`, `withdrawn`, `id`) | |
  | author | VARCHAR(64) | oui | identifiant du personnage | |
  | text | VARCHAR(300) | oui | nettoyé | |
  | withdrawn | BOOL | oui | | 0 |
  | withdrawn_at | DATETIME | non | | NULL |
  | created_at | DATETIME | oui | | NOW() |
- **Règles serveur** : membre actif déverrouillé (MET-GANG-10) ; 1 message / 2 s, 20 messages / minute par joueur ; texte non vide après nettoyage ; aucun `DELETE` sur cette table, jamais (ni purge, ni « tout effacer ») ; retrait : l'auteur seulement (`author = identifier` du demandeur), message non déjà retiré ; les lectures des membres filtrent `withdrawn = 0` ; pagination par curseur `id < before`, 20 par page.
- **Textes et états** :
  - Vide : « Aucun message. » (`gang.messages.vide`) ; champ « Message… » (`gang.messages.placeholder`) ; bouton « Charger plus » (`gang.messages.plus`).
  - Retirer : bouton « Retirer » (`gang.messages.retirer`) ; confirmation « Retirer ce message ? Il ne sera plus visible par le gang. » (`gang.messages.confirmer_retrait`) ; succès « Message retiré. » (`gang.messages.retire`) ; message d'un autre : bouton absent, refus serveur `commun.erreur.pas_droit`.
  - Trop long : `commun.erreur.trop_long` ; trop vite : `commun.erreur.trop_vite`.
- **Notifications** : membres connectés sans l'app ouverte : notification neutre « Nouvelle mise à jour disponible. » (`gang.notif.neutre`) sous le nom de l'icône déguisée, 1 notification max toutes les 5 min par membre (regroupement). Aucune notification au gang en cas d'infiltration policière.
- **Liens** : MET-GANG-10 (déverrouillage) ; MET-POL-47 (lecture secrète sur mandat, preuve) ; Admin > Archives (messages retirés).
- **Réglages** : `Config.Gang.Messages.MaxLength = 300`, `Config.Gang.Messages.NotifyEveryMinutes = 5` ; pagination `Config.Limits.PageSize = 20`.
- **Journal admin** : jamais le contenu ; « message retiré » (gang, auteur, id du message, heure) en catégorie `gang`.
- **Performance** : aucun envoi aux membres sans l'app ouverte (hors notification regroupée) ; lecture paginée 20 sur index ; pas de cache des messages ; table qui grossit sans fin : index `(gang_id, withdrawn, id)` obligatoire, aucune requête sans `LIMIT`.
- **Cas limites** :
  - Membre exclu → n'accède plus aux messages, ses anciens messages restent avec son surnom.
  - Double clic sur « Retirer » → un seul retrait (`actionId`) ; deuxième envoi → succès sans effet.
  - Gang archivé par l'admin → messages gardés, lisibles par l'admin seulement.
  - 10 000 messages dans le fil → seules 20 lignes sont chargées par page.
- **Critères d'acceptation** :
  - Étant donné deux membres avec l'onglet ouvert, quand l'un envoie un message, alors l'autre le voit sans recharger.
  - Étant donné un message envoyé il y a 30 jours, quand un membre ouvre le fil et charge les pages, alors il le retrouve.
  - Étant donné un message retiré par son auteur, quand un membre recharge, alors il ne le voit plus ; quand l'admin ouvre Admin > Archives, alors il le voit avec « Retiré le {date} ».
  - Étant donné un Soldat qui envoie `gang:msg:withdraw` sur le message d'un autre, quand le serveur le reçoit, alors il refuse `pas_droit` et le message reste visible.

### [MET-GANG-05] Régler l'effacement automatique des messages (supprimée : messages jamais effacés, décision client)
ID gardé pour ne pas décaler la numérotation. Aucun réglage d'effacement, aucune colonne `msg_ttl_hours`, aucune purge : voir MET-GANG-04.

### [MET-GANG-06] Voir le coffre du gang et ses mouvements
- **But** : connaître le solde d'argent sale du gang et l'historique tracé.
- **Qui** : Soldat et plus (réglable).
- **Où** : app Gang > onglet « Coffre ».
- **Parcours** : ouverture → `gang:vault:get { page }` ; affichage solde + mouvements (date, surnom, type « Dépôt »/« Retrait », montant, motif), 20 par page, filtres « Dépôts », « Retraits », « Tout ».
- **Données** (`pop_tablet_gangs.vault INT UNSIGNED` + `pop_tablet_gang_vault_moves`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | BIGINT | oui | | |
  | gang_id | INT | oui | | |
  | identifier | VARCHAR(64) | oui | | |
  | kind | ENUM('depot','retrait','admin') | oui | | |
  | amount | INT UNSIGNED | oui | | |
  | balance_after | INT UNSIGNED | oui | | |
  | reason | VARCHAR(60) | non | nettoyé | '' |
  | created_at | DATETIME | oui | | NOW() |
- **Règles serveur** : droit ; mouvements jamais supprimés (archivage seulement, visible admin).
- **Textes et états** : vide « Le coffre est vide. Aucun mouvement. » (`gang.coffre.vide`) ; solde « Solde : {montant} » (`gang.coffre.solde`) ; pas le droit : onglet grisé « Rang requis : {rang} ».
- **Notifications** : aucune.
- **Liens** : MET-GANG-07.
- **Réglages** : aucun.
- **Journal admin** : non (lecture).
- **Performance** : solde en mémoire serveur par gang (chargé au premier accès) ; mouvements paginés.
- **Cas limites** : coffre à 0 → texte vide avec solde 0 ; membre parti → ses anciens mouvements restent avec son surnom ; plus de 20 mouvements → pagination.
- **Critères d'acceptation** :
  - Étant donné 3 dépôts, quand un Soldat ouvre le coffre, alors il voit le solde et les 3 lignes.
  - Étant donné une Recrue, quand elle ouvre l'onglet, alors il est grisé.
  - Étant donné une Recrue qui envoie `gang:vault:get`, alors refus.

### [MET-GANG-07] Déposer ou retirer de l'argent sale au coffre
- **But** : alimenter ou utiliser le coffre commun, chaque mouvement étant tracé.
- **Qui** : dépôt dès Recrue ; retrait Lieutenant (plafonné à `withdraw_cap`, défaut 10 000 $ par retrait) et Chef.
- **Où** : app Gang > « Coffre » > « Déposer » / « Retirer ».
- **Parcours** :
  1. Montant (entier) + motif (≤ 60, facultatif) → `gang:vault:move { kind, amount, reason, actionId }`.
  2. Serveur : droits, montant, fréquence ; option `Config.Gang.Vault.RequireLocation = true` : le joueur doit être à moins de 5 m du point de planque du gang (réglé par l'admin à la création du gang) ; sinon possible partout (défaut `false`).
  3. Forme de l'argent sale : réglage `Config.Gang.DirtyMoney`, détecté par défaut (`'auto'`) au démarrage par le bridge (`Bridge.GetDirtyMoney / AddDirtyMoney / RemoveDirtyMoney`, BASE-MOT-02) :
     - ESX → `{ type = 'account', name = 'black_money' }` (compte du joueur ; avec ox_inventory, l'objet `black_money` lu par le même compte) ;
     - QBCore et Qbox → `{ type = 'item', name = 'markedbills' }` : la valeur de chaque liasse est dans ses métadonnées (`info.worth` sur qb-inventory, `metadata.worth` sur ox_inventory) ; le solde du joueur = somme des `worth` de ses liasses.
     Le serveur peut forcer l'une ou l'autre forme dans `config.lua` (ex. `{ type = 'item', name = 'black_money' }` pour un objet empilable sans métadonnées : 1 objet = 1 $). Message console au démarrage : « [pop_tablet] Gang dirty money: %s (%s) ».
  4. Dépôt : retire l'argent sale du joueur puis crédite le coffre, dans cet ordre, en vérifiant le retour ; si le retrait joueur échoue, rien n'est crédité. Forme `account` : `Bridge.RemoveMoney(src, name, amount)`. Forme `item` avec valeur en métadonnées : le serveur retire des liasses entières, de la plus petite à la plus grande, jusqu'à couvrir le montant ; s'il retire plus que le montant, il rend la différence dans une nouvelle liasse (`worth` = différence) ; si le joueur n'a pas assez de valeur totale, refus `pas_assez_joueur`.
  5. Retrait : débite le coffre (`UPDATE ... SET vault = vault - ? WHERE id = ? AND vault >= ?`, une ligne modifiée sinon refus) puis donne l'argent sale au joueur (forme `account` : `Bridge.AddMoney` ; forme `item` : une liasse `markedbills` avec `worth = montant`) ; si le don échoue (inventaire plein), le coffre est recrédité et le mouvement n'est pas écrit.
  6. Mouvement écrit, solde mis à jour, bandeau succès.
- **Données** : MET-GANG-06 ; réglage `Config.Gang.DirtyMoney`.
- **Règles serveur** : montant entier 1 à `Config.Gang.Vault.MaxMove = 100000` ; retrait Lieutenant ≤ `withdraw_cap` ; somme des retraits d'un Lieutenant ≤ 3 × `withdraw_cap` par 24 h ; fréquence 1 / 5 s ; `actionId` obligatoire ; joueur vivant (`Bridge.IsDead` = faux) ; pas pendant qu'il est menotté (statebag `isCuffed` si présent).
- **Textes et états** : succès dépôt « {montant} déposés. » (`gang.coffre.depot_ok`) ; succès retrait « {montant} retirés. » (`gang.coffre.retrait_ok`) ; pas assez sur soi « Argent sale insuffisant. » (`gang.coffre.pas_assez_joueur`) ; coffre insuffisant « Le coffre ne contient pas assez. » (`gang.coffre.pas_assez_coffre`) ; plafond « Retrait limité à {max} pour ce rang. » (`gang.coffre.plafond`) ; trop loin « Coffre accessible uniquement à la planque. » (`gang.coffre.planque`) ; inventaire plein « Inventaire plein. » (`gang.coffre.inventaire_plein`).
- **Notifications** : Chef (texte neutre en notification) pour tout retrait > 50 % du plafond : « {surnom} a retiré {montant} du coffre. » (`gang.notif.retrait`).
- **Liens** : MET-GANG-06 ; signal serveur `pop_tablet:gangVaultMove (gangId, identifier, kind, amount)` pour les scripts tiers (blanchiment).
- **Réglages** : `Config.Gang.DirtyMoney = 'auto'` (ESX : `{ type = 'account', name = 'black_money' }` ; QBCore / Qbox : `{ type = 'item', name = 'markedbills', worthKey = 'worth' }`), `Config.Gang.Vault.MaxMove = 100000`, `Config.Gang.Vault.DefaultWithdrawCap = 10000`, `Config.Gang.Vault.RequireLocation = false`, `Config.Gang.Vault.LocationDistance = 5.0`.
- **Journal admin** : oui, `gang_coffre` : chaque mouvement (avant/après solde) ; Discord si montant ≥ 50 000 $.
- **Performance** : une transaction par mouvement ; solde en mémoire synchronisé avec la base à chaque mouvement.
- **Cas limites** : double clic → un seul mouvement (`actionId`) ; deux retraits simultanés vidant le coffre → la mise à jour conditionnelle n'en laisse passer qu'un ; joueur déconnecté pendant le retrait → transaction annulée, coffre intact ; QBCore avec 3 liasses de 400 $ et dépôt de 1 000 $ → les 3 liasses sont retirées et une liasse de 200 $ est rendue ; objet `markedbills` absent des objets déclarés → message console au démarrage et onglet Coffre en lecture seule « Coffre indisponible sur ce serveur. » (`gang.coffre.indisponible`).
- **Critères d'acceptation** :
  - Étant donné 5 000 $ d'argent sale sur moi, quand je dépose 5 000, alors j'ai 0 sur moi et le coffre a +5 000 avec un mouvement à mon nom.
  - Étant donné un serveur Qbox avec des liasses `markedbills` d'une valeur totale de 2 000 $, quand je dépose 2 000, alors les liasses quittent mon inventaire et le coffre a +2 000.
  - Étant donné un Lieutenant plafonné à 10 000, quand il retire 15 000, alors refus.
  - Étant donné un client qui envoie un dépôt de 1 000 000 sans avoir l'argent, alors rien n'est crédité et la tentative est journalisée.

### [MET-GANG-08] Carte des territoires
- **But** : voir les zones contrôlées par chaque gang et poser un GPS.
- **Qui** : tout membre dès Recrue.
- **Où** : app Gang > onglet « Territoires ».
- **Parcours** :
  1. Ouverture → `gang:territories:get`.
  2. Source des zones, dans cet ordre :
     a. Si `Config.Gang.Territories.Resource` est réglé et démarré (ex. un script de territoires), le serveur appelle l'adaptateur ouvert `bridge/territories.lua` qui doit renvoyer `{ { id, label, owner (nom du gang ou nil), coords = vec3, radius } }` ; adaptateur fourni vide, documenté dans le guide pour l'IA.
     b. Sinon, zones de la tablette réglées par l'admin (branche Admin) : nom, centre, rayon (50–500 m), gang propriétaire.
  3. Affichage : carte de GTA (image de carte statique de la base) avec cercles colorés (couleur d'accent de chaque gang ; zone libre en gris), légende ; mes zones en surbrillance.
  4. Clic sur une zone → nom, propriétaire, bouton « GPS » (`SetNewWaypoint` au centre).
  5. Le Chef peut renommer l'affichage de ses propres zones (≤ 30 car.) uniquement en mode tablette (b).
- **Données** (`pop_tablet_gang_territories`, mode b) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | label | VARCHAR(30) | oui | nettoyé | |
  | x, y, z | FLOAT | oui | | |
  | radius | SMALLINT | oui | 50 à 500 | 150 |
  | owner_gang | INT | non | | NULL |
- **Règles serveur** : membre déverrouillé ; les zones ne révèlent que le nom public des gangs (pas leurs membres) ; fréquence 1 / 5 s.
- **Textes et états** : vide « Aucun territoire n'est défini sur ce serveur. » (`gang.territoires.vide`) ; zone libre « Zone libre » (`gang.territoires.libre`) ; succès GPS « Point GPS posé. » (`gang.territoires.gps`) ; source externe en panne « Les territoires sont indisponibles pour le moment. » (`gang.territoires.indispo`).
- **Notifications** : aucune.
- **Liens** : script de territoires tiers (adaptateur), Admin (zones).
- **Réglages** : `Config.Gang.Territories.Enabled = true`, `Config.Gang.Territories.Resource = false`, `Config.Gang.Territories.CacheSeconds = 60`.
- **Journal admin** : oui pour le renommage d'une zone (`gang`).
- **Performance** : zones en cache serveur 60 s ; aucune boucle de dessin en jeu (pas de blips permanents ; seulement la carte dans la NUI et un point GPS au clic).
- **Cas limites** : adaptateur qui renvoie une erreur → message « indisponibles », pas de plantage (`pcall`) ; aucune zone → texte vide ; gang propriétaire supprimé → zone affichée « Zone libre ».
- **Critères d'acceptation** :
  - Étant donné 3 zones dont 1 à mon gang, quand j'ouvre la carte, alors je vois 3 cercles et la mienne en surbrillance.
  - Étant donné une zone, quand je clique « GPS », alors un point est posé à son centre.
  - Étant donné un non-membre, quand il envoie `gang:territories:get`, alors refus.

### [MET-GANG-09] Choisir l'icône déguisée de l'app Gang
- **But** : faire apparaître l'app Gang sous une fausse identité (« Météo » ou « Calculatrice »).
- **Qui** : réglage pour le gang par le Chef ; chaque membre peut choisir sa propre icône si `Config.Gang.Disguise.PerMember = true` (défaut `true`).
- **Où** : app Gang > « Réglages » > « Apparence de l'app ».
- **Parcours** :
  1. Choix : « Météo » ou « Calculatrice » (défaut Calculatrice).
  2. → `gang:settings:disguise { icon, actionId }` ; enregistré sur la ligne membre (ou le gang) ; l'accueil de la tablette affiche l'icône et le nom choisis, rangée parmi les apps outils, avec le même style que les vraies apps (aucun signe distinctif).
  3. Il n'existe **aucune** autre app Météo ou Calculatrice livrée qui pourrait trahir le doublon : si l'app Outils « Calculatrice » de la base est activée, l'icône déguisée **remplace** son entrée sur la tablette du membre (une seule Calculatrice visible) et reste une vraie calculatrice tant que le code n'est pas saisi (MET-GANG-10).
- **Données** : `pop_tablet_gang_members.disguise ENUM('meteo','calculatrice') DEFAULT 'calculatrice'`.
- **Règles serveur** : membre déverrouillé ; valeur dans la liste ; 1 / 10 s.
- **Textes et états** : libellés « Météo » (`gang.deguisement.meteo`), « Calculatrice » (`gang.deguisement.calculatrice`) ; succès « Apparence changée. » (`gang.deguisement.ok`).
- **Notifications** : aucune.
- **Liens** : MET-GANG-10, app Outils (Calculatrice de la base).
- **Réglages** : `Config.Gang.Disguise.Choices = { 'meteo', 'calculatrice' }`, `Config.Gang.Disguise.Default = 'calculatrice'`, `Config.Gang.Disguise.PerMember = true`.
- **Journal admin** : non.
- **Performance** : lu avec la liste des apps à l'ouverture de la tablette (déjà chargée), aucune requête en plus.
- **Cas limites** : membre exclu → l'icône disparaît ; valeur inconnue envoyée → refus ; Calculatrice de la base désactivée → l'icône déguisée s'affiche seule.
- **Critères d'acceptation** :
  - Étant donné un membre qui choisit « Météo », quand il rouvre la tablette, alors une app « Météo » est sur l'accueil et aucune app « Gang ».
  - Étant donné un non-membre, quand il ouvre sa tablette, alors il ne voit aucune app de gang.
  - Étant donné une valeur « gang » envoyée, alors refus.

### [MET-GANG-10] Ouvrir l'app déguisée par code (et protection en cas de saisie)
- **But** : n'afficher le contenu du gang qu'après un code personnel ; un policier qui a la tablette ne voit rien.
- **Qui** : membres actifs.
- **Où** : accueil > icône « Météo » ou « Calculatrice ».
- **Parcours** :
  1. L'icône ouvre une vraie fausse app :
     - « Calculatrice » : calculatrice fonctionnelle (4 opérations, %, C). Saisir le code puis appuyer sur « = » déclenche la vérification.
     - « Météo » : écran météo de Los Santos (météo et heure du jeu lues côté client, prévisions fictives sur 3 jours). Un appui long de 1 s sur le nom de la ville ouvre un champ « Code postal » de 4 à 6 chiffres ; Entrée déclenche la vérification.
  2. Premier lancement : à la première saisie, si le membre n'a pas de code, le serveur répond « créer » : la NUI demande deux fois un code de 4 à 6 chiffres (écran déguisé en « Réglages de l'unité »), le serveur enregistre son empreinte (`pin_hash` = SHA-256 de `sel serveur + identifier + code`, sel aléatoire généré au premier démarrage et gardé dans la base).
  3. Vérification : `gang:unlock { code }` ; le serveur vérifie que le personnage qui envoie est un membre actif **et** que le code correspond ; si oui, ouvre une session de déverrouillage côté serveur (mémoire, liée au `src` et à l'`identifier`, valable jusqu'à la fermeture de la tablette ou 10 min sans action) et la NUI bascule dans l'app Gang.
  4. Mauvais code : la calculatrice affiche simplement le résultat du calcul (ou « Erreur » si l'expression est invalide), la météo affiche « Code postal inconnu » : rien ne révèle qu'un code existe. Après 5 échecs en 15 min, toute vérification est refusée 15 min (même affichage neutre) et le Chef reçoit une notification neutre.
  5. Saisie par la police : les données du gang sont liées au personnage. Un policier qui ouvre une tablette saisie (objet donné ou inspection de l'app Police) voit **ses propres** apps, ou, en mode inspection, la liste des apps du propriétaire où l'app déguisée apparaît comme une Météo/Calculatrice ordinaire et fonctionne comme telle ; le serveur refuse toute requête `gang:*` d'un personnage non membre, même avec le bon code. **Seule exception** : en mode saisie (MET-POL-44), un agent qui saisit le bon code du membre propriétaire (obtenu par aveu RP) ouvre le **livre de comptes** du gang en lecture seule (action dédiée `police.saisie.ledger`, MET-GANG-11) ; la messagerie, le coffre et les membres restent fermés (la messagerie ne s'ouvre qu'avec un mandat d'infiltration, MET-POL-47).
  6. Code oublié : le Chef peut « Réinitialiser le code » d'un membre (MET-GANG-01 > membre) ; le membre recrée un code au lancement suivant. Le Chef qui oublie le sien passe par l'admin.
  7. Fermeture : Échap, fermeture de la tablette ou 10 min sans action → session fermée, retour à la fausse app.
- **Données** :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | pin_hash | VARCHAR(128) | non | empreinte, jamais le code | NULL |
  | pin_fails | TINYINT (mémoire) | | 0 à 5 | 0 |
  | locked_until | horodatage (mémoire) | | | |
  | session | mémoire `{ src, identifier, gangId, lastAction }` | | | |
- **Règles serveur** : membre actif ; code 4–6 chiffres ; 5 essais / 15 min (`Config.Gang.Unlock.MaxFails = 5`, `Config.Gang.Unlock.LockMinutes = 15`) ; codes trop simples refusés à la création (`0000`, `1234`, 4 chiffres identiques, suites) ; toute requête `gang:*` exige une session valide ; la session est détruite à `playerDropped`, à la fermeture de la tablette et à l'exclusion ; aucune donnée gang n'est envoyée au client avant le déverrouillage (la NUI de la fausse app ne contient aucune donnée réelle).
- **Textes et états** :
  - Création : « Code d'unité (4 à 6 chiffres). » (`gang.code.creer`) ; « Confirmer le code. » (`gang.code.confirmer`) ; différents « Les deux codes ne correspondent pas. » (`gang.code.different`) ; trop simple « Ce code est trop simple. » (`gang.code.simple`).
  - Météo : « Code postal » (`gang.code.meteo_champ`), « Code postal inconnu » (`gang.code.meteo_inconnu`).
  - Succès : aucun bandeau (passage direct à l'app, fondu 150 ms).
  - Réinitialisation par le Chef : « Code de {surnom} réinitialisé. » (`gang.code.reinitialise`).
- **Notifications** : Chef, notification neutre (« Nouvelle mise à jour disponible. ») puis, dans l'app déverrouillée, la ligne « 5 essais de code ratés sur le compte de {surnom} à {heure}. » (`gang.alerte.essais`).
- **Liens** : MET-GANG-09 ; app Police (inspection de tablette : doit afficher l'app déguisée sous son faux nom et ne jamais appeler `gang:*`).
- **Réglages** : `Config.Gang.Unlock.MaxFails = 5`, `Config.Gang.Unlock.LockMinutes = 15`, `Config.Gang.Unlock.IdleMinutes = 10`, `Config.Gang.Unlock.CodeLength = { 4, 6 }`.
- **Journal admin** : oui, `gang` : réinitialisation de code, verrouillage après 5 échecs (qui, quand) ; jamais le code.
- **Performance** : vérification = une lecture de la ligne membre (en cache avec la liste des membres) ; sessions en mémoire ; la minuterie d'inactivité de 10 min est vérifiée à chaque requête (`lastAction`), pas de boucle.
- **Cas limites** : policier qui connaît le code d'un membre → refus, car il n'est pas membre ; membre qui prête sa tablette à un autre joueur → le serveur raisonne sur le personnage connecté, l'autre joueur ne voit rien ; serveur redémarré → sessions effacées, il faut ressaisir le code ; double envoi de code → compté une fois (`actionId`).
- **Critères d'acceptation** :
  - Étant donné un membre avec le code 482915 et l'icône Calculatrice, quand il tape 482915 puis « = », alors l'app Gang s'ouvre.
  - Étant donné un mauvais code, quand il appuie sur « = », alors la calculatrice affiche juste le nombre et rien n'indique un code.
  - Étant donné un policier qui inspecte la tablette saisie et tape le bon code, alors le serveur refuse `gang:unlock` (non-membre) et n'ouvre que le livre de comptes en lecture seule (MET-GANG-11) ; messages, coffre et membres restent inaccessibles.

### [MET-GANG-11] Livre de comptes du gang (entrées, dettes, partages)
- **But** : tenir dans l'app Gang un livre de comptes écrit à la main (entrées, dépenses, dettes, partages entre membres), lisible par la police seulement dans deux cas encadrés.
- **Qui** : lire et écrire : Lieutenant et Chef (droits « Lire / Écrire dans le livre de comptes » du tableau du gang, réglables par le Chef) ; corriger (archiver) une ligne : son auteur dans les 30 min, ensuite le Chef. Police, lecture seule : (a) agent en mode saisie d'une tablette d'un membre (MET-POL-44) qui saisit le bon code de gang de ce membre (aveu RP), droit `police.saisie` ; (b) agent autorisé par un mandat d'infiltration actif signé par un juge sur ce gang (MET-POL-47), lignes créées après la signature seulement.
- **Où** : app Gang (déverrouillée) > onglet « Comptes » ; police : mode saisie > app déguisée > code du membre ; ou Police > Mandats > mandat d'infiltration > onglet « Comptes ».
- **Parcours** :
  1. Ouverture → `gang:ledger:list { page, kind }` : résumé du mois (« Entrées », « Dépenses », « Dettes à recevoir », « Dettes à payer ») puis lignes, plus récente d'abord, 20 par page ; filtres « Tout », « Entrées », « Dépenses », « Dettes », « Partages ».
  2. « Nouvelle ligne » → type :
     - « Entrée » / « Dépense » : libellé (≤ 60), montant (1 à 10 000 000), date (défaut aujourd'hui), membre lié (facultatif).
     - « Dette » : sens (« On nous doit » / « On doit »), personne (texte libre ≤ 40 ou membre), montant, échéance (facultative) ; bouton « Marquer remboursée » ensuite.
     - « Partage » : montant total, membres et parts (montant par membre, la somme doit égaler le total), libellé.
     → `gang:ledger:add { kind, fields, actionId }`.
  3. Le livre est un registre écrit : **aucun argent ne bouge** (le coffre réel est MET-GANG-07) ; un lien facultatif vers un mouvement du coffre peut être ajouté (numéro du mouvement).
  4. Correction : rien n'est effacé ; « Corriger » archive la ligne (motif ≤ 100) et propose une nouvelle ligne préremplie ; les lignes archivées sont visibles par le Chef (filtre « Archivées ») et l'admin.
  5. Lecture police (a) : en mode saisie, la saisie du bon code de gang du membre propriétaire de la tablette appelle `police:seizure:ledger { serial, code }` ; le serveur vérifie le code (même empreinte que MET-GANG-10), ouvre le livre complet en lecture seule pour cette session de saisie, sans ouvrir messagerie, coffre ni membres ; bouton « Ajouter à la preuve » (copie figée des lignes affichées, cadre `saisie_tablette`, MET-POL-36).
  6. Lecture police (b) : avec un mandat d'infiltration actif (MET-POL-47), onglet « Comptes » de l'écran d'infiltration : lignes créées entre `signe_le` et `min(maintenant, expire_le)`, en lecture seule ; « Joindre comme preuve » (cadre `infiltration`).
  7. Le gang n'est pas prévenu de la lecture par la police (en dehors de l'avis de saisie de tablette de MET-POL-44, s'il est activé).
- **Données** (`pop_tablet_gang_ledger`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | BIGINT | oui | | |
  | gang_id | INT | oui | index (`gang_id`, `archived`, `id`) | |
  | kind | ENUM('entree','depense','dette','partage') | oui | | |
  | label | VARCHAR(60) | oui | nettoyé | |
  | amount | INT UNSIGNED | oui | 1 à 10 000 000 | |
  | direction | ENUM('a_recevoir','a_payer') | non | dettes seulement | NULL |
  | counterpart | VARCHAR(40) | non | nettoyé | '' |
  | member | VARCHAR(64) | non | membre lié | NULL |
  | shares | JSON | non | partages : 1 à 40 `{ member, amount }`, somme = `amount` | NULL |
  | due_date | DATE | non | | NULL |
  | debt_status | ENUM('ouverte','remboursee') | non | dettes seulement | 'ouverte' |
  | vault_move_id | BIGINT | non | mouvement du coffre | NULL |
  | author | VARCHAR(64) | oui | | |
  | archived / archive_reason | BOOL / VARCHAR(100) | oui | | 0 |
  | created_at | DATETIME | oui | | NOW() |
- **Règles serveur** : membre actif déverrouillé avec le droit du rang pour toute action `gang:ledger:*` ; montants entiers ; somme des parts = total ; 1 ligne / 5 s, 2 000 lignes actives max par gang (au-delà, l'archivage des plus anciennes est proposé) ; aucune suppression ; police (a) : session de saisie valide, code vérifié côté serveur, 5 essais puis blocage (règles de MET-POL-44), lecture seule ; police (b) : mandat `actif`, type `infiltration`, signé, non expiré, filtre `created_at >= signe_le` imposé par le serveur.
- **Textes et états** :
  - Onglet « Comptes » (`gang.comptes.titre`) ; vide « Aucune ligne. » (`gang.comptes.vide`) ; types « Entrée » (`gang.comptes.entree`), « Dépense » (`gang.comptes.depense`), « Dette » (`gang.comptes.dette`), « Partage » (`gang.comptes.partage`) ; sens « On nous doit » (`gang.comptes.a_recevoir`), « On doit » (`gang.comptes.a_payer`) ; « Marquer remboursée » (`gang.comptes.rembourser`) ; résumé « Entrées · Dépenses · Dettes à recevoir · Dettes à payer » (`gang.comptes.resume`).
  - Succès « Ligne ajoutée. » (`gang.comptes.ajoutee`), « Ligne corrigée. » (`gang.comptes.corrigee`), « Dette remboursée. » (`gang.comptes.remboursee`).
  - Erreurs : « La somme des parts doit égaler le total. » (`gang.comptes.parts`) ; « Montant invalide. » (`gang.comptes.montant`) ; pas le droit : onglet grisé « Rang requis : {rang} ».
  - Police : bandeau « Livre de comptes · lecture seule » (`police.saisie.comptes`) ; vide sous mandat « Aucune ligne depuis la signature du mandat. » (`police.infiltration.comptes_vide`).
- **Notifications** : aucune (ni au gang, ni à la police).
- **Liens** : MET-GANG-07 (coffre réel, lien facultatif), MET-GANG-10 (code, exception police), MET-POL-44 (saisie), MET-POL-47 (mandat d'infiltration), MET-POL-36 (preuves).
- **Réglages** : `Config.Gang.Ledger.Enabled = true`, `Config.Gang.Ledger.MaxLines = 2000`, `Config.Gang.Ledger.EditMinutes = 30`, `Config.Gang.Ledger.MaxAmount = 10000000`.
- **Journal admin** : oui, `gang` : correction (archivage) d'une ligne ; `police` : chaque ouverture du livre par la police (agent, voie a ou b, gang) ; jamais le contenu dans Discord.
- **Performance** : lecture paginée 20 sur index ; résumé du mois calculé par une requête `SUM` groupée à l'ouverture de l'onglet ; aucune boucle, aucun cache.
- **Cas limites** : membre exclu → ses lignes restent avec son surnom ; police avec le code d'un membre exclu → refus (membre non actif) ; mandat expiré pendant la lecture → la requête suivante est refusée ; partage avec un membre parti → autorisé, affiché « (parti) ».
- **Critères d'acceptation** :
  - Étant donné un Lieutenant, quand il ajoute un partage de 9 000 $ en 3 parts de 3 000 $, alors la ligne apparaît et le résumé du mois est à jour, sans aucun mouvement d'argent.
  - Étant donné un agent en mode saisie qui tape le bon code du membre, quand il ouvre l'app déguisée, alors il voit seulement le livre de comptes en lecture seule ; messagerie et coffre restent fermés.
  - Étant donné un mandat d'infiltration signé hier à 18 h, quand l'agent ouvre l'onglet « Comptes », alors il ne voit que les lignes créées depuis 18 h hier.
  - Étant donné une Recrue qui envoie `gang:ledger:list` à la main, quand le serveur la reçoit, alors il refuse et ne renvoie aucune ligne.

---

# Immobilier

Principe : app métier « Immobilier » (brique `metier_immobilier`, fichier 05 §0.5), cochée par défaut pour le modèle `immobilier` (entreprise par défaut « Dynasty 8 »). Elle tient le **cadastre** de la ville dans la tablette : aucun script immobilier n'est requis. Elle ne crée, ne retire et ne bloque jamais l'accès à un bien d'un autre script : c'est un registre. Droits (réglables par le Patron, `pop_tablet_ent_permissions`) :

| Clé | Recrue | Membre | Chef | Patron |
|---|---|---|---|---|
| `immo.cadastre.lire` (consulter le cadastre) | Oui | Oui | Oui | Oui |
| `immo.biens.gerer` (créer, modifier un bien) | Non | Oui | Oui | Oui |
| `immo.ventes` (enregistrer une vente) | Non | Oui | Oui | Oui |
| `immo.proprietaire.corriger` (corriger le propriétaire enregistré) | Non | Non | Oui | Oui |

### [MET-IMM-01] Cadastre : registre des biens et de leurs propriétaires
- **But** : tenir le registre des biens immobiliers de la ville (adresse, type, position, propriétaire enregistré, historique des propriétaires).
- **Qui** : employés de l'agence en service ; lecture `immo.cadastre.lire` (Recrue+) ; création et modification `immo.biens.gerer` (Membre+) ; correction du propriétaire `immo.proprietaire.corriger` (Chef+).
- **Où** : app Immobilier > onglet « Cadastre » ; recherche par adresse, référence ou nom de propriétaire ; bouton « Nouveau bien ».
- **Parcours** :
  1. Liste : référence, adresse, type, propriétaire (nom ou « Agence »), statut, 20 par page ; recherche serveur (300 ms, 2 caractères).
  2. « Nouveau bien » → adresse (5 à 100 car.), type (« Maison », « Appartement », « Local commercial », « Garage », « Terrain »), position (bouton « Ma position » : position serveur du ped), propriétaire initial (« Agence » par défaut, ou citoyen trouvé par nom via le bridge), prix de référence (facultatif) → `immo:property:create { fields, actionId }` → référence `BIEN-00001`, ligne de mutation `creation`.
  3. Fiche d'un bien : informations, mini-carte (image statique avec un point), propriétaire actuel, historique des propriétaires (`pop_tablet_immo_mutations` : date, ancien, nouveau, type, prix, agent), ventes signalées (MET-IMM-02).
  4. « Corriger le propriétaire » (Chef+) : nouveau propriétaire + motif obligatoire (10 à 300 car.) → mutation `correction`, journalisée ; jamais utilisé pour une vente (MET-IMM-02).
  5. Lien police : si aucun script n'a déclaré `RegisterPropertySource`, le cadastre devient la source de l'onglet « Propriétés » de la fiche citoyen (MET-POL-15) et de la liste d'adresses des mandats de perquisition (MET-POL-28) ; lecture seule.
  6. API lecture : `exports.pop_tablet:GetPropertyOwner(ref)` → `identifier | 'agency', adresse` ; `exports.pop_tablet:GetPropertiesOf(identifier)` → liste `{ ref, adresse, type }`.
- **Données** (`pop_tablet_immo_properties` et `pop_tablet_immo_mutations`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | ref | VARCHAR(10) | oui | `BIEN-` + 5 chiffres, unique | auto |
  | company_id | INT | oui | agence qui a créé le bien | |
  | address | VARCHAR(100) | oui | unique parmi les biens non archivés, nettoyée | |
  | kind | ENUM('maison','appartement','local','garage','terrain') | oui | | 'maison' |
  | x, y, z | FLOAT | non | position serveur | NULL |
  | owner | VARCHAR(64) | non | identifiant du personnage ; NULL = agence | NULL |
  | ref_price | INT UNSIGNED | non | 0 à 100 000 000 | 0 |
  | status | ENUM('libre','vendu','loue') | oui | | 'libre' |
  | archived | BOOL | oui | | 0 |
  Mutations : `property_id`, `kind ENUM('creation','vente','correction')`, `from_owner`, `to_owner`, `price`, `agent`, `reason VARCHAR(300)`, `sale_id`, `created_at`.
- **Règles serveur** : brique `metier_immobilier` active ; service et droits vérifiés ; adresse unique ; propriétaire = identifiant d'un personnage existant (bridge) ou NULL ; jamais d'identifiant envoyé à la NUI (jeton de cible) ; un bien n'est jamais supprimé (archivage, admin) ; fréquence 1 / 5 s en écriture.
- **Textes et états** : onglet « Cadastre » (`immo.cadastre.titre`) ; vide « Aucun bien enregistré. » (`immo.cadastre.vide`) + bouton « Nouveau bien » (`immo.cadastre.nouveau`) ; types (`immo.type.<type>`) « Maison », « Appartement », « Local commercial », « Garage », « Terrain » ; propriétaire agence « Agence » (`immo.cadastre.agence`) ; succès « Bien {ref} enregistré. » (`immo.cadastre.ok`), « Propriétaire corrigé. » (`immo.cadastre.corrige`) ; erreur « Cette adresse est déjà au cadastre ({ref}). » (`immo.cadastre.doublon`) ; hors service `commun.erreur.hors_service`.
- **Notifications** : aucune.
- **Liens** : MET-IMM-02 (ventes), MET-POL-15 et MET-POL-28 (propriétés, lecture), fichier 05 (brique `metier_immobilier`), Factures (commission de vente, MET-IMM-02).
- **Réglages** : `Config.RealEstate.Enabled = true`, `Config.RealEstate.MaxProperties = 2000`, `Config.RealEstate.PoliceSource = true`.
- **Journal admin** : oui, catégorie `immo` : création, modification, correction de propriétaire (avant/après).
- **Performance** : liste paginée 20 avec index (`address`), (`owner`) ; fiche chargée au clic ; aucune boucle.
- **Cas limites** : deux agences créent la même adresse en même temps → contrainte unique, la seconde reçoit `doublon` ; propriétaire dont le personnage est supprimé → affiché « Personnage supprimé », correction par un Chef ; 2 001e bien → refus « Nombre maximum de biens atteint (2 000). » (`immo.cadastre.max`).
- **Critères d'acceptation** :
  - Étant donné un Membre en service, quand il enregistre « 12 Grove Street, Maison, Agence », alors le bien BIEN-00001 apparaît avec le propriétaire « Agence ».
  - Étant donné un bien appartenant à John Doe, quand un policier ouvre la fiche de John Doe, alors l'onglet « Propriétés » liste ce bien.
  - Étant donné une Recrue qui envoie `immo:property:create` à la main, quand le serveur la reçoit, alors il refuse `pas_droit`.

### [MET-IMM-02] Enregistrer une vente (alerte si le vendeur n'est pas le propriétaire enregistré)
- **But** : enregistrer la vente d'un bien au cadastre avec l'accord des deux parties, et alerter quand un agent tente d'enregistrer une vente par quelqu'un qui n'est pas le propriétaire enregistré.
- **Qui** : `immo.ventes` (Membre+), en service ; vendeur et acheteur confirment eux-mêmes (aucun droit requis).
- **Où** : app Immobilier > fiche d'un bien > bouton « Enregistrer une vente ».
- **Parcours** :
  1. Formulaire : vendeur (« Agence » ou citoyen à ≤ 3 m de l'agent), acheteur (citoyen à ≤ 3 m), prix (1 à 100 000 000), commission de l'agence (0 à 10 % du prix, défaut `Config.RealEstate.CommissionPercent = 3`), case « Facturer la commission à l'acheteur ».
  2. `immo:sale:create { propertyRef, sellerToken | 'agency', buyerToken, price, commission, actionId }` → le serveur compare le vendeur au propriétaire enregistré du bien (`owner`, NULL = agence).
  3. **Vendeur ≠ propriétaire enregistré** : la vente est refusée et rien ne change au cadastre ; le serveur crée une alerte `immo_sales.status = 'alerte'` (bien, agent, vendeur présenté, heure) ; l'agent voit « Vente refusée : le vendeur n'est pas le propriétaire enregistré de ce bien. » ; les Chefs et le Patron de l'agence en service reçoivent une notification ; l'alerte est inscrite au journal admin et dans l'onglet « Ventes signalées » de la fiche du bien. Le nom du vrai propriétaire n'est pas montré à l'agent s'il n'a pas `immo.cadastre.lire` (il l'a par défaut).
  4. **Vendeur = propriétaire** : vente `en_attente_signatures` ; le vendeur puis l'acheteur reçoivent une confirmation (tablette : notification → écran « Confirmer la vente » ; sans tablette : fenêtre simple, BASE-MOT-14) avec l'adresse, le prix et les noms ; « Confirmer » / « Refuser », 120 s chacun.
  5. Les deux confirment : en une transaction, `owner` = acheteur, `status = 'vendu'`, mutation `vente` (prix, agent, sale_id), vente `enregistree` ; si la case est cochée, facture de commission créée dans Factures (émetteur l'agence, payeur l'acheteur, `externalRef = 'immo:<ref>'`). Aucun argent du prix ne passe par la tablette (le paiement du prix se fait entre joueurs ou par le script immobilier du serveur).
  6. Un refus ou un délai dépassé → vente `annulee`, rien ne change.
- **Données** (`pop_tablet_immo_sales`) :
  | Champ | Type | Obligatoire | Limites | Défaut |
  |---|---|---|---|---|
  | id | INT | oui | | |
  | property_id | INT | oui | | |
  | company_id | INT | oui | agence | |
  | agent | VARCHAR(64) | oui | | |
  | seller | VARCHAR(64) | non | NULL = agence | |
  | registered_owner | VARCHAR(64) | non | propriétaire au moment de la demande | |
  | buyer | VARCHAR(64) | oui | ≠ vendeur | |
  | price | INT UNSIGNED | oui | 1 à 100 000 000 | |
  | commission | INT UNSIGNED | oui | 0 à 10 % du prix | 3 % |
  | status | ENUM('alerte','en_attente_signatures','enregistree','annulee') | oui | | |
  | seller_confirmed_at / buyer_confirmed_at | DATETIME | non | | NULL |
  | invoice_id | INT | non | facture de commission | NULL |
  | created_at | DATETIME | oui | | NOW() |
- **Règles serveur** : service et droit ; vendeur et acheteur réellement à ≤ 3 m de l'agent (sauf vendeur « Agence ») ; acheteur ≠ vendeur ; comparaison vendeur / propriétaire faite par le serveur sur l'identifiant (jamais sur un nom envoyé par le client) ; une seule vente `en_attente_signatures` par bien ; confirmations uniquement par le vendeur et l'acheteur eux-mêmes ; 3 alertes d'un même agent en 24 h → notification renforcée au Patron « {agent} a tenté 3 ventes non conformes en 24 h. » ; fréquence 1 / 10 s.
- **Textes et états** : bouton « Enregistrer une vente » (`immo.vente.bouton`) ; refus alerte « Vente refusée : le vendeur n'est pas le propriétaire enregistré de ce bien. » (`immo.vente.pas_proprietaire`) ; attente « En attente des confirmations du vendeur et de l'acheteur. » (`immo.vente.attente`) ; écran partie « Confirmer la vente de {adresse} pour {prix} à {acheteur} ? » (`immo.vente.confirmer`) ; succès « Vente enregistrée. {acheteur} est le nouveau propriétaire. » (`immo.vente.ok`) ; annulée « Vente annulée. » (`immo.vente.annulee`) ; onglet « Ventes signalées » (`immo.vente.signalees`) ; vide « Aucune vente signalée. » (`immo.vente.signalees_vide`) ; personne proche « Personne à moins de 3 m. » (`immo.vente.personne`).
- **Notifications** : Chefs et Patron de l'agence en service : « Alerte cadastre · {agent} a tenté d'enregistrer la vente de {adresse} par une personne qui n'en est pas le propriétaire. » (`immo.notif.alerte`) ; propriétaire enregistré (s'il a une tablette) : « Une vente de votre bien {adresse} a été refusée : vendeur non conforme. » (`immo.notif.alerte_proprietaire`) ; vendeur et acheteur à l'enregistrement : « Vente enregistrée : {adresse}. » (`immo.notif.vente`).
- **Liens** : MET-IMM-01 (cadastre, mutations), Factures (commission, signal `pop_tablet:invoicePaid` avec `externalRef`), BASE-MOT-14 (fenêtre simple), journal admin.
- **Réglages** : `Config.RealEstate.CommissionPercent = 3`, `Config.RealEstate.CommissionMaxPercent = 10`, `Config.RealEstate.ConfirmSeconds = 120`, `Config.RealEstate.SaleDistance = 3.0`, `Config.RealEstate.AlertThreshold = 3`.
- **Journal admin** : oui, catégorie `immo` : chaque alerte (bien, agent, vendeur présenté, propriétaire enregistré), chaque vente enregistrée ou annulée ; Discord catégorie `alert` pour les alertes.
- **Performance** : une lecture du bien et une transaction à l'enregistrement ; aucune boucle (délais de confirmation par `SetTimeout` unique par vente).
- **Cas limites** : propriétaire corrigé par un Chef pendant qu'une vente attend les signatures → la vente est annulée ; acheteur qui s'éloigne avant de confirmer → confirmation acceptée depuis sa tablette (la distance n'est vérifiée qu'à la demande) ; double clic → une seule vente (`actionId`) ; vendeur mort (`Bridge.IsDead`) → fenêtre proposée à son réveil dans le délai, sinon annulée.
- **Critères d'acceptation** :
  - Étant donné un bien appartenant à John Doe, quand un agent enregistre sa vente avec Jane Roe comme vendeuse, alors la vente est refusée, rien ne change au cadastre et les Chefs reçoivent l'alerte.
  - Étant donné John Doe vendeur et Jane Roe acheteuse à 2 m, quand les deux confirment, alors Jane Roe devient propriétaire et l'historique montre la mutation « vente ».
  - Étant donné un client modifié qui envoie le nom « John Doe » comme vendeur alors que la cible est Jane Roe, quand le serveur compare, alors il utilise l'identifiant réel de la cible et crée l'alerte.

---

## Décisions prises par défaut

1. **Rôles Justice** : avocat = métier `avocat` ; procureur = métier `justice` grades 0–1 ; juge = métier `justice` grade 2 et plus (`Config.Justice.Roles`, modifiable ; métiers ESX, QBCore ou Qbox). Deux entreprises créées par défaut : « Cabinet d'avocats » et « Tribunal ». Ces métiers n'existent pas sur tous les serveurs : l'assistant de premier démarrage (BASE-MOT-15, étape « Justice ») les détecte ; s'ils sont absents, il propose « Créer le métier » (présélectionné), « Relier à un métier existant » ou « Ne pas utiliser » ; le nom de métier retenu est écrit dans `pop_tablet_settings.justice_roles`, prioritaire sur `Config.Justice.Roles`.
2. **Appartenance aux gangs gérée par la tablette** (`Config.Gang.Source = 'tablet'`), pour que les membres gardent leur job légal ; `'job'`, `'job2'` et `'gang'` (gang natif QBCore / Qbox) disponibles. Aucun gang créé par défaut (création par l'admin). Interdits de gang par défaut : police, ambulance, justice.
3. **Messagerie de gang jamais effacée** (décision du client) : aucun délai, aucune purge ; l'auteur peut retirer son message, qui est archivé et visible par l'admin seulement ; pagination 20 messages ; la police n'y accède qu'avec un mandat d'infiltration signé par un juge, à partir de la signature et jamais avant (MET-POL-47) ; le journal admin ne contient jamais le contenu des messages ni les codes.
4. **Données de gang liées au personnage**, pas à l'objet tablette, avec un code personnel de 4 à 6 chiffres par membre (empreinte salée côté serveur) : une tablette saisie ne révèle rien, même avec le code.
5. **Alertes « joueur à terre » automatiques** sur `Bridge.OnPlayerDeath` (ESX, QBCore, Qbox ; mort revérifiée côté serveur), plus la commande `/secours` et un export pour les scripts tiers ; expiration 15 min.
6. **Facture de soins sur inconscient** : statut `attente_reveil`, présentée au réveil, annulée après 60 min sans réveil. Même règle pour les devis et amendes présentés à un joueur mort.
7. **Verdict définitif** : non modifiable dans la tablette (correction par l'admin seulement) ; il écrit au casier, crée l'amende (Trésor public) et émet `pop_tablet:sentencePronounced` ; la prison effective reste au script de prison (adaptateur facultatif `Config.Signals.SentenceJail` de la base, fichiers `bridge/jail/`).
8. **Mandats** : une seule table et une seule règle, celles de la police (fichier 03) : validité 7 jours, 2 prolongations, demande non traitée expirée après 3 jours ; le juge ou le Chef police valide (`Config.Police.Mandats.Validation = 'grade_ou_juge'`).
9. **Visibilité avocat** : un avocat ne voit une affaire que si un de ses clients (lien accepté par le client) est partie et qu'il a confirmé la représentation ; 2 avocats max par citoyen. Une affaire hors périmètre répond « introuvable ».
10. **Effacement de casier** = masquage pour la police (`expunged = 1`) avec décision numérotée ; visible des juges et de l'admin ; restauration par l'admin seulement.
11. **Certificats lisibles par la police** par défaut (`PoliceCanRead = true`), sans le commentaire médical ; le dossier médical, lui, n'est jamais lisible par la police.
12. **Diagnostic** : moteur, carrosserie et réservoir lus côté serveur ; essence lue dans le statebag `fuel` (ox_fuel), sinon valeur du client marquée « estimation ».
13. **Stock mécano** décompté au paiement de la facture (pas au devis) ; le stock ne devient jamais négatif (règle unique de l'app Stock, PRO-STO) : il s'arrête à 0, le manque est noté dans le mouvement et les Chefs sont prévenus ; au devis, une pièce sans stock n'est refusée que si `BlockIfNoStock = true` (défaut `false`).
14. **Calculatrice déguisée** : remplace l'app Calculatrice de la base sur la tablette du membre pour éviter un doublon visible ; icône par défaut « Calculatrice », choix par membre.
15. **Carnet d'entretien simple** (décision du client : aucune fonction ne pénalise les biens des joueurs) : réparations, factures et garantie du garage (0 à 90 jours), visible par les garages et le propriétaire (app « Carnet auto », MET-MEC-11) ; aucun drapeau « volé » ; lecture police désactivée par défaut (`Config.Mechanic.Logbook.PoliceCanRead = false`).
16. **Argent sale du gang** : forme détectée par framework (`Config.Gang.DirtyMoney = 'auto'` : ESX compte `black_money`, QBCore / Qbox objet `markedbills` avec valeur en métadonnées), réglable.
17. **Ajouts validés par le client** : tri des blessés par couleur partagé EMS / police (MET-EMS-17), contestation des preuves (MET-JUS-12), accord de repenti signé et homologué (MET-JUS-13), livre de comptes du gang lisible par la police seulement sur saisie + code ou mandat (MET-GANG-11), cadastre de l'agence immobilière avec alerte de vente non conforme (MET-IMM-01, MET-IMM-02).


> **Relecture croisée (24/11/2026)** : ce fichier a été aligné sur les 5 autres. Les noms communs (signaux, tables, réglages, droits, textes d'erreur, constantes) sont listés dans `00-sommaire.md`, qui fait foi en cas de doute.
