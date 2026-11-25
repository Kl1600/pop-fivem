# 02 · Entreprises : fiches de fonctionnalités

Périmètre : les quatre apps communes à **toutes** les entreprises (police et EMS compris) : **Gestion**, **Factures**, **Annonces**, **Demandes**. À lire avec `_contexte.md`. Chaque fiche suit `_modele.md`.

---

## 0. Conventions communes à ce fichier (valables pour toutes les fiches ci-dessous)

Ces conventions évitent de répéter les mêmes règles 60 fois. Une fiche qui dit « règles communes » applique tout ce bloc.

### 0.1 Entreprise = métier du framework (ESX, QBCore ou Qbox)
- **Trois frameworks au même niveau** : tout passe par le bridge (BASE-MOT-02). Dans ce fichier, les noms ESX écrits dans les fiches ont toujours leur équivalent, appliqué par le bridge :

| Écrit dans les fiches (ESX) | QBCore | Qbox |
|---|---|---|
| métier `jobs.name`, `xPlayer.job.name` | clé de `QBCore.Shared.Jobs`, `PlayerData.job.name` | `exports.qbx_core:GetJobs()`, `PlayerData.job.name` (métier principal) |
| grades `job_grades` (`grade`, `label`, `salary`) | `QBCore.Shared.Jobs[job].grades['n']` (`name`, `payment`, `isboss`) | même format via `qbx_core` |
| grade d'un joueur hors ligne `users.job_grade` | colonne JSON `players.job` (`grade.level`) | table `player_groups` (`grade`) |
| `xPlayer.setJob` / `ESX.RefreshJobs()` | `Player.Functions.SetJob` / `QBCore.Functions.UpdateJob` | `exports.qbx_core:SetPlayerPrimaryJob`, `AddPlayerToJob` / `UpsertJobGrade` |
| compte société `esx_addonaccount` / `esx_society` | `qb-banking` (v2) sinon `qb-management` | `Renewed-Banking` sinon `qb-banking` |
| `users.firstname` / `lastname`, `users.accounts` | `players.charinfo` / `players.money` | `players.charinfo` / `players.money` |
| paie ESX (`Config.PaycheckInterval`) | paie QBCore (`QBCore.Config.Money.PayCheckTimeOut`) | paie Qbox (`config/server.lua`, `money.paycheckTimeout`) |

  Sur QBCore et Qbox, les grades créés ou modifiés dans la tablette sont enregistrés dans `pop_tablet_company_grades` et réappliqués à chaque démarrage (BASE-MOT-02 étape 4), car leurs métiers vivent dans un fichier Lua que la tablette ne modifie jamais.
- Une entreprise = un métier du framework (ex. `police`, `ambulance`, `mechanic`). L'identifiant interne d'entreprise est `pop_tablet_companies.id` (INT, table définie par le fichier 05, colonne `job_name` = nom du métier) : dans ce fichier, `company` désigne cet identifiant et toutes les tables ont une colonne `company_id INT`. Le serveur retrouve l'entreprise du joueur par `job_name = Bridge.GetJob(source).name` (cache mémoire).
- Un joueur appartient à une seule entreprise : celle de son métier actuel (métier principal sur Qbox ; les métiers secondaires Qbox servent seulement au sélecteur des apps Gestion pro, fichier 06 C16). Le métier `unemployed` (Config.Entreprises.MetierSansEmploi = `'unemployed'`) n'est pas une entreprise : les apps Gestion, Factures (onglet émission), Annonces, Demandes (boîte) lui sont cachées.
- Le serveur relit le métier et le grade **à chaque appel** via le bridge (`Bridge.GetJob(source)` → `{ name, grade, gradeLabel }`). Jamais la valeur envoyée par le client.
- Compte d'entreprise : `Bridge.Society.GetMoney(company)`, `Bridge.Society.AddMoney(company, montant, motif)`, `Bridge.Society.RemoveMoney(company, montant, motif)`. Compte société du framework détecté : ESX `esx_addonaccount` / `esx_society` (compte `society_<job_name>`), QBCore `qb-banking` ou `qb-management`, Qbox `Renewed-Banking` ou `qb-banking` (compte au nom du métier). `pop_bank` n'expose aucun export et n'est pas branché ; un adaptateur banque optionnel non fourni peut remplacer ces fonctions (voir ENT-GES-23).
- Argent du joueur : `Bridge.GetMoney(source, 'bank'|'money')`, `Bridge.RemoveMoney(...)`, `Bridge.AddMoney(...)`. Joueur hors ligne : `Bridge.AddMoneyOffline(identifier, 'bank', montant)` (ESX `users.accounts`, QBCore / Qbox `players.money`).
- Nom affiché d'un joueur : prénom + nom RP (ESX `users.firstname` + `users.lastname`, QBCore / Qbox `players.charinfo`), jamais le nom Steam/FiveM.

### 0.2 Niveaux et droits
- Les grades du métier (ESX `job_grades.grade`, QBCore / Qbox niveau du grade) d'une entreprise sont triés par numéro. Le plus bas = niveau **Recrue**, le plus haut = niveau **Patron**. Les intermédiaires (n grades) : les `ceil(n/2)` premiers = **Membre**, les suivants = **Chef**. Exemples : 2 grades → Recrue, Patron ; 3 → Recrue, Membre, Patron ; 5 → Recrue, Membre, Membre, Chef, Patron.
- Clés de droit utilisées dans ce fichier (stockées dans `pop_tablet_ent_permissions`, voir ENT-GES-18) et valeurs par défaut :

| Clé | Libellé affiché | Recrue | Membre | Chef | Patron |
|---|---|---|---|---|---|
| `service` | « Prendre son service » | Oui | Oui | Oui | Oui |
| `facture.creer` | « Faire une facture » | Oui (plafond 500 $) | Oui | Oui | Oui |
| `facture.voir_toutes` (ajout) | « Voir toutes les factures » | Non | Non | Oui | Oui |
| `facture.regler` (ajout) | « Régler les factures (part, impayés) » | Non | Non | Non | Oui |
| `demandes.repondre` | « Répondre aux demandes » | Non | Oui | Oui | Oui |
| `demandes.assigner` (ajout) | « Assigner les demandes » | Non | Non | Oui | Oui |
| `annonce.publier` | « Publier une annonce » | Non | Non | Oui | Oui |
| `annonce.ville` | « Annonce à toute la ville » | Non | Non | Non | Oui |
| `compte.voir` | « Voir le compte » | Non | Non | Oui | Oui |
| `compte.mouvement` | « Déposer / retirer » | Non | Non | Non | Oui |
| `compte.prime` (ajout) | « Verser une prime » | Non | Non | Non | Oui |
| `ventes.voir` (ajout) | « Voir l'historique des ventes » | Non | Non | Oui | Oui |
| `employes.voir` (ajout) | « Voir les employés » | Non | Non | Oui | Oui |
| `recruter` | « Recruter » | Non | Non | Oui | Oui |
| `membres.gerer` | « Promouvoir / rétrograder / virer » | Non | Non | Sous son grade | Oui |
| `grades.gerer` | « Grades, salaires, droits » | Non | Non | Non | Oui |

- Le grade le plus haut (Patron) a **toujours** tous les droits ; sa colonne n'est pas modifiable.
- L'admin serveur (ACE `pop.tablet.admin`) passe toutes les vérifications de droit et de grade ; chacune de ses actions est journalisée avec `admin = true`. Il doit quand même choisir l'entreprise visée (sélecteur visible seulement pour lui en haut de l'app Gestion, Factures, Annonces, Demandes).
- Fonction serveur unique : `Perm.Has(source, company, cle)` → `true/false` (lit le cache mémoire, voir ENT-GES-18). Elle sert aussi aux clés ajoutées par les fichiers 03 (police), 04 (EMS, mécano, justice), 05 (`site.modifier`) et 06 (`tableur.*`, `stock.*`, `planning.*`, `annuaire.fermer`) : toutes sont dans la même table `pop_tablet_ent_permissions` et dans l'écran Droits (ENT-GES-18). Grille complète fusionnée : `00-sommaire.md`.

### 0.3 Appels client → serveur
- Un seul canal pour toute la tablette : le callback `pop_tablet:request` de la base (fiche 01, §0). « RPC `gestion.service.prendre` » = action `service.prendre` de l'app `gestion` passée par ce callback ; les « codes » des fiches sont le champ `err` de la réponse (codes communs de la fiche 01).
- `actionId` : UUID v4 généré par l'interface à chaque clic de validation. Le serveur garde en mémoire les `actionId` déjà traités pendant 10 minutes (table Lua `{[actionId] = os.time()}`, nettoyée à chaque insertion des entrées de plus de 10 min, pas de boucle). Un `actionId` déjà vu renvoie la **même réponse** que la première fois, sans rejouer l'action (anti double clic).
- Le bouton cliqué passe en état « chargement » (désactivé) jusqu'à la réponse ; au-delà de 5 s, voir état Chargement.
- Limite de fréquence par défaut : `Config.RateLimit.Default = { n = 5, s = 10 }` (5 actions par 10 s, par joueur et par action, fiche BASE-MOT-11). Dépassement → code `trop_vite`. Certaines fiches fixent une limite plus stricte.

### 0.4 Nettoyage des textes
Tout texte saisi par un joueur : suppression de tout ce qui ressemble à une balise (`<...>`), échappement de `& < > " '` à l'affichage, suppression des caractères de contrôle, espaces de début/fin retirés, plus de 2 retours à la ligne consécutifs ramenés à 2, longueur max vérifiée **après** nettoyage. Texte vide après nettoyage = champ vide. L'interface affiche toujours le texte en mode texte (jamais `innerHTML`).

### 0.5 Images
URL acceptée seulement si `https://` et domaine dans `Config.Images.AllowedDomains = { 'i.imgur.com', 'r2.fivemanage.com' }` (réglage de la base, BASE-MOT-18), ou image de la Galerie de la tablette (identifiant `media:<id>`). Extension `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`. Longueur max 300 caractères.

### 0.6 Proximité
« Joueur proche » = calculé **par le serveur** (OneSync) : distance entre `GetEntityCoords(GetPlayerPed(a))` et `GetEntityCoords(GetPlayerPed(b))` ≤ `Config.Limits.NearDistance = 3.0` m, même instance de routage (`GetPlayerRoutingBucket`). La liste « personnes proches » est toujours fournie par le serveur.

### 0.7 Tablette sur soi, notifications, fenêtre simple
- `Bridge.HasTablet(source)` (défini par la base, fiche 01) dit si le joueur a la tablette sur lui.
- Notification tablette : envoyée uniquement aux joueurs concernés, en ligne, qui ont la tablette sur eux. Si la tablette est fermée, la notification s'affiche en petit encart en haut à droite de l'écran de jeu pendant 4 s (`Config.Notify.Duration = 4000`) et reste dans le centre de notifications de la tablette (historique de la base : 50 dernières, gardées 7 jours en base, `Config.Notify.HistoryMax = 50`, `Config.Notify.HistoryDays = 7`, fiche BASE-ECR-05).
- **Fenêtre simple** : petite fenêtre centrée hors tablette (même NUI, composant `FenetreSimple`), fond sombre, titre, texte, 1 à 3 boutons, prend le focus souris, Échap = « Plus tard » (ferme sans répondre). Utilisée pour les joueurs sans tablette. Une seule fenêtre simple à la fois par joueur : les suivantes attendent dans une file côté client (max 5, au-delà les plus anciennes sont ignorées, elles restent consultables par relance).

### 0.8 Textes communs (clés partagées)
Les textes communs (`commun.erreur.*`, `commun.droit.grade_requis`, `commun.chargement.long`, `commun.succes`, `commun.bouton.*`, `commun.hors_service.*`, `commun.pagination.*`) sont ceux de la fiche 01 (§0 « Codes d'erreur communs »), référentiel unique repris dans `00-sommaire.md`. **Ton des textes : style Apple** (décision du client) : formulations neutres et courtes en priorité (« Facture envoyée. », « Code incorrect. », « Aucune facture. »), **vouvoiement** quand une adresse directe est nécessaire (« Vous n'avez pas les droits nécessaires. »), jamais de tutoiement. Les textes écrits entre guillemets dans les fiches sont déjà dans ce ton et se recopient tels quels dans `locales/fr.lua`.

### 0.9 Format d'affichage
- Montants : entier, espace fine pour les milliers, symbole après : « 12 500 $ » (`Config.Currency.Symbol = '$'`). Aucun centime : tous les montants sont des entiers ≥ 0.
- Dates : heure du serveur, format « JJ/MM/AAAA HH:MM ». Stockage en base : entier `INT UNSIGNED` = horodatage Unix en secondes (`os.time()` serveur).
- Durées : « 3 h 25 min », « 45 min ».
- Semaine = du lundi 00:00 au dimanche 23:59:59, heure du serveur.

### 0.10 Journal admin
`Journal.Ecrire({ categorie, action, auteur = identifier, auteurNom, entreprise, cible, avant, apres, details })` = fonction de journal de la base (BASE-MOT-07, table `pop_tablet_logs`). Envoi Discord si la convar `pop_tablet_webhook` est réglée et la catégorie active dans `Config.Discord.Categories` (lien gardé côté serveur, jamais envoyé au client).

### 0.11 Tables créées par ce fichier
| Table | Rôle |
|---|---|
| `pop_tablet_ent_services` | Prises et fins de service |
| `pop_tablet_ent_invitations` | Invitations de recrutement (historique) |
| `pop_tablet_ent_permissions` | Droits par grade |
| `pop_tablet_ent_reglages` | Réglages par entreprise (part employé, impayés…) |
| `pop_tablet_ent_mouvements` | Entrées/sorties du compte faites via la tablette |
| `pop_tablet_factures` | Factures |
| `pop_tablet_factures_evenements` | Historique de chaque facture (créée, relancée, payée…) |
| `pop_tablet_ent_annonces` | Annonces (entreprise et ville) |
| `pop_tablet_ent_demandes` | Demandes |

Toutes ont un index sur `company_id`. Création automatique au démarrage (`CREATE TABLE IF NOT EXISTS`). `pop_tablet_ent_services` est **la seule table de service de toute la tablette** : les apps Police, EMS, Mécano, Justice, le Planning et l'Annuaire la lisent et appellent les actions `gestion.service.prendre` / `gestion.service.quitter` de ce fichier (pas de table de service à part). Les dates de ces tables sont en `INT UNSIGNED` (Unix), comme la base.

---

## 1. Gestion d'entreprise (app « Gestion »)

L'app « Gestion » (clé `gestion.titre` : « Gestion ») a un menu à gauche : « Service », « Employés », « Grades et salaires », « Droits », « Compte », « Ventes ». Chaque entrée n'apparaît que si le joueur a le droit correspondant (« Service » toujours visible pour un employé). L'app est cachée aux joueurs sans entreprise.

### [ENT-GES-01] Prendre son service
- **But** : passer « en service » pour son entreprise, avec l'heure enregistrée, ce qui ouvre l'entreprise dans l'annuaire et rend le joueur visible du dispatch et du planning.
- **Qui** : tout employé ayant le droit `service` (par défaut tous les niveaux) ; réglable dans Droits.
- **Où** : Gestion > Service > gros bouton « Prendre mon service » ; aussi le bouton « Prendre mon service » de l'état Hors service de toutes les apps métier ; aussi l'interrupteur dans la barre du haut de la tablette (pastille « Hors service » cliquable).
- **Parcours** :
  1. Le joueur clique « Prendre mon service ».
  2. L'interface envoie RPC `gestion.service.prendre` (sans données autres que `actionId`).
  3. Serveur : relit le métier ; vérifie droit `service` ; vérifie que le joueur n'est pas déjà en service (sinon renvoie `ok` avec l'état actuel, sans nouvelle ligne).
  4. Serveur : insère une ligne `pop_tablet_ent_services` (`debut = os.time()`, `fin = NULL`), met en mémoire `Service.Actifs[source] = { company, identifier, debut, idLigne }`, pose le state bag `Player(source).state.popDuty = company` (répliqué, lu par les autres scripts).
  5. Serveur : met à jour le compteur `Service.Compte[company]` (+1). Si le compteur passe de 0 à 1, l'entreprise devient « Ouverte » dans le cache annuaire.
  6. Serveur : appelle `SetDuty(source, true)` de la base (BASE-API-05), qui émet `pop_tablet:dutyChanged(source, { identifier, companyId, job, onDuty })` avec `onDuty = true`, écouté par dispatch, planning, annuaire.
  7. Réponse `ok` → l'interface affiche le bandeau succès, la pastille du haut passe à « En service » (couleur d'accent) avec le chrono « depuis 0 min » (calculé localement à l'affichage, recalculé seulement quand l'écran est ouvert, via un minuteur de l'interface arrêté à la fermeture).
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `id` | INT AUTO_INCREMENT | Oui | — | — |
| `company_id` | INT | Oui | `pop_tablet_companies.id` | — |
| `identifier` | VARCHAR(60) | Oui | identifiant du personnage (ESX `identifier`, QBCore / Qbox `citizenid`) | — |
| `nom` | VARCHAR(100) | Oui | nom RP au moment de la prise | — |
| `grade` | INT | Oui | grade au moment de la prise | — |
| `debut` | INT UNSIGNED | Oui | horodatage | `os.time()` |
| `fin` | INT UNSIGNED | Non | ≥ `debut` | NULL |
| `duree` | INT UNSIGNED | Non | secondes, plafonnée à `Config.Service.DureeMax` | NULL |
| `raison_fin` | ENUM(`manuel`,`deconnexion`,`renvoi`,`changement_metier`,`force`,`arret`,`interrompu`) | Non | — | NULL |
| `force_par` | VARCHAR(60) | Non | identifiant de celui qui a forcé | NULL |

  Index : (`company`, `debut`), (`identifier`, `debut`).
- **Règles serveur** : métier ≠ sans emploi ; droit `service` ; pas déjà en service (idempotent) ; fréquence : 1 changement d'état de service toutes les 10 s par joueur (`Config.Service.Frequence = 10`) ; un joueur ne peut être en service que pour son métier actuel.
- **Textes et états** :
  - Bouton : « Prendre mon service » (`gestion.service.prendre`).
  - Succès : « Vous êtes en service. » (`gestion.service.succes_prise`).
  - Déjà en service : pas d'erreur, l'écran se met à jour.
  - Pas le droit : bouton grisé + « Réservé au grade : {grade}. » (`commun.droit.grade_requis`).
  - Fréquence : `commun.erreur.trop_vite`.
  - Écran Service vide (jamais pris de service) : « Aucun service cette semaine. » (`gestion.service.vide`) sous le bouton.
- **Notifications** : aucune pour les collègues (évite le bruit). Option `Config.Service.NotifierCollegues = false` : si `true`, les collègues en service reçoivent « {nom} a pris son service. » (`gestion.service.notif_prise`).
- **Liens** : Annuaire (ouvert/fermé), Dispatch (agent disponible), Planning (présence réelle), state bag `popDuty`, export `exports.pop_tablet:IsOnDuty(source)` → `company|false`, export `exports.pop_tablet:CountOnDuty(company)` → entier. Événement serveur émis : `pop_tablet:dutyChanged`.
- **Réglages** : `Config.Service.Frequence = 10` ; `Config.Service.NotifierCollegues = false` ; `Config.Service.DureeMax = 43200` (12 h).
- **Journal admin** : non (trop fréquent) ; la table `pop_tablet_ent_services` sert d'historique.
- **Performance** : une insertion SQL par prise ; état en mémoire ; aucun minuteur serveur ; chrono affiché seulement écran ouvert.
- **Cas limites** :
  - Double clic : même `actionId` → même réponse, une seule ligne ; deux `actionId` différents → le 2e voit « déjà en service ».
  - Joueur change de métier pendant le service : écoute de `Bridge.OnJobChange` côté serveur (ESX `esx:setJob`, QBCore / Qbox `QBCore:Server:OnJobUpdate`) → fin de service `changement_metier` (voir ENT-GES-03).
  - Base injoignable à l'insertion : réponse `commun.erreur.serveur`, l'état mémoire n'est pas modifié.
  - Joueur sans tablette : peut prendre son service par l'export `exports.pop_tablet:SetDuty(source, true)` (pour un point de pointage d'un autre script) ; mêmes règles.
- **Critères d'acceptation** :
  - Étant donné un employé hors service, quand il clique « Prendre mon service », alors une ligne `pop_tablet_ent_services` est créée avec `fin = NULL` et `Player(src).state.popDuty` vaut son métier.
  - Étant donné une entreprise sans personne en service, quand un employé prend son service, alors l'annuaire affiche l'entreprise « Ouverte » sans redémarrage.
  - Étant donné un joueur qui envoie `gestion.service.prendre` alors qu'il est sans emploi (triche par console), quand le serveur reçoit l'appel, alors il répond `droit` et rien n'est écrit.
  - Étant donné un joueur qui reclique dans les 10 s, alors il reçoit `commun.erreur.trop_vite`.

### [ENT-GES-02] Quitter son service
- **But** : passer « hors service » et enregistrer la durée du service.
- **Qui** : tout employé en service (aucun droit requis pour arrêter).
- **Où** : Gestion > Service > bouton « Quitter mon service » (remplace « Prendre mon service » quand en service) ; pastille « En service » de la barre du haut.
- **Parcours** :
  1. Clic sur « Quitter mon service » → fenêtre de confirmation dans la tablette : « Quitter votre service ? » (`gestion.service.confirm_fin`) / « Confirmer » / « Annuler ».
  2. RPC `gestion.service.quitter`.
  3. Serveur : si pas en service → `ok` avec état actuel. Sinon met à jour la ligne : `fin = os.time()`, `duree = min(fin - debut, Config.Service.DureeMax)`, `raison_fin = 'manuel'`.
  4. Serveur : supprime `Service.Actifs[source]`, `Player(source).state.popDuty = false`, compteur −1 ; si le compteur arrive à 0, l'entreprise passe « Fermée » dans l'annuaire.
  5. Serveur : `SetDuty(source, false)` → `pop_tablet:dutyChanged(source, { identifier, companyId, job, onDuty })` avec `onDuty = false`.
  6. Interface : bandeau « Fin de service : {duree}. » (`gestion.service.succes_fin`), pastille « Hors service » grise, les apps métier passent à l'état Hors service.
- **Données** : mise à jour de `pop_tablet_ent_services` (voir ENT-GES-01). Affiché : durée du service qui vient de finir.
- **Règles serveur** : fréquence `Config.Service.Frequence` ; durée plafonnée à 12 h.
- **Textes et états** : bouton « Quitter mon service » (`gestion.service.quitter`) ; succès ci-dessus ; erreurs : `commun.erreur.trop_vite`, `commun.erreur.serveur`.
- **Notifications** : comme ENT-GES-01 si `NotifierCollegues = true` : « {nom} a quitté son service. » (`gestion.service.notif_fin`).
- **Liens** : Annuaire, Dispatch (l'agent quitte ses appels en cours : le dispatch les remet « non attribués »), Planning.
- **Réglages** : ceux de ENT-GES-01.
- **Journal admin** : non.
- **Performance** : une mise à jour SQL.
- **Cas limites** :
  - Service de plus de 12 h : durée enregistrée 12 h, la ligne garde le vrai `fin`.
  - Dernier employé qui quitte alors que des demandes sont « nouvelles » : rien ne change pour elles (elles attendent la réouverture).
  - Double clic : une seule mise à jour (idempotent).
- **Critères d'acceptation** :
  - Étant donné un employé en service depuis 2 h, quand il quitte, alors `duree` vaut 7200 (± 2) et `raison_fin = 'manuel'`.
  - Étant donné le seul employé en service, quand il quitte, alors l'annuaire affiche « Fermée ».
  - Étant donné un joueur qui envoie `gestion.service.quitter` pour un autre joueur (paramètre falsifié), alors le serveur ignore tout paramètre et n'agit que sur l'appelant.

### [ENT-GES-03] Fin de service automatique
- **But** : ne jamais laisser un service ouvert à tort (déconnexion, changement de métier, renvoi, arrêt du script, crash).
- **Qui** : système (serveur), aucun clic.
- **Où** : aucun écran ; visible dans l'historique (ENT-GES-06) par la raison de fin.
- **Parcours** :
  1. `playerDropped` : si `Service.Actifs[source]` existe → fin avec `raison_fin = 'deconnexion'`.
  2. `esx:setJob` (serveur) : si le nouveau métier ≠ entreprise du service → fin avec `changement_metier` (ou `renvoi` si le changement vient de ENT-GES-11).
  3. `onResourceStop` (pop_tablet) : toutes les lignes ouvertes sont fermées en une seule requête `UPDATE ... SET fin = ?, duree = LEAST(? - debut, DureeMax), raison_fin = 'arret' WHERE fin IS NULL`.
  4. Démarrage du script : toute ligne encore ouverte (crash serveur) est fermée avec `fin = debut`, `duree = 0`, `raison_fin = 'interrompu'`. Les joueurs déjà connectés (redémarrage du script seul) repartent hors service.
  5. Chaque fin déclenche `pop_tablet:dutyChanged` et la mise à jour du compteur annuaire.
- **Données** : `pop_tablet_ent_services.raison_fin`.
- **Règles serveur** : aucune action client ; écritures groupées au stop/démarrage.
- **Textes et états** : libellés des raisons dans l'historique : « Manuel » (`gestion.service.raison.manuel`), « Déconnexion » (`.deconnexion`), « Renvoi » (`.renvoi`), « Changement de métier » (`.changement_metier`), « Forcé par {nom} » (`.force`), « Arrêt du serveur » (`.arret`), « Interrompu (0 min comptée) » (`.interrompu`).
- **Notifications** : aucune.
- **Liens** : Annuaire, Dispatch, Planning.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : uniquement sur événements ; aucune boucle.
- **Cas limites** :
  - Crash serveur : heures de ce service perdues (0 min) ; affichage explicite « Interrompu ».
  - Joueur qui se reconnecte : il revient hors service, doit reprendre son service.
  - Arrêt du script avec 50 joueurs en service : une seule requête SQL.
- **Critères d'acceptation** :
  - Étant donné un employé en service, quand il se déconnecte, alors sa ligne est fermée avec `deconnexion`.
  - Étant donné un `ensure pop_tablet` pendant que 3 joueurs sont en service, alors après redémarrage aucune ligne n'a `fin = NULL` et les 3 joueurs sont hors service.
  - Étant donné un client qui envoie un faux événement `esx:setJob`, alors rien ne se passe (l'écoute est serveur uniquement, `AddEventHandler` sans `RegisterNetEvent`).

### [ENT-GES-04] Forcer la fin de service d'un employé (ajout)
- **But** : permettre à un responsable de sortir du service un employé qui a oublié de pointer (heures gonflées, entreprise affichée ouverte à tort).
- **Qui** : droit `membres.gerer`, sur un employé de grade strictement inférieur (le patron sur tout employé non patron) ; admin sur tous.
- **Où** : Gestion > Employés > ligne d'un employé « En service » > bouton « Terminer son service ».
- **Parcours** :
  1. Clic → confirmation « Terminer le service de {nom} ? » (`gestion.employes.confirm_fin_force`).
  2. RPC `gestion.service.forcer` `{ identifier }`.
  3. Serveur : vérifie droit + grade cible ; cherche le service actif de cet identifiant ; le ferme avec `raison_fin = 'force'`, `force_par = identifiant de l'acteur`.
  4. Le joueur visé reçoit la notification ; ses apps métier passent Hors service.
  5. La liste des employés se met à jour.
- **Données** : `pop_tablet_ent_services.force_par`.
- **Règles serveur** : même entreprise ; grade cible < grade acteur (sauf patron/admin) ; on ne peut pas se forcer soi-même (utiliser ENT-GES-02) ; fréquence 1/s.
- **Textes et états** : bouton « Terminer son service » (`gestion.employes.fin_force`) ; succès « Service de {nom} terminé. » (`gestion.employes.fin_force_succes`) ; erreur « Cette personne n'est plus en service. » (`gestion.employes.plus_en_service`) ; pas le droit : bouton caché.
- **Notifications** : employé visé : « {acteur} a terminé votre service. » (`gestion.service.notif_force`).
- **Liens** : Annuaire, Dispatch, Planning.
- **Réglages** : aucun.
- **Journal admin** : oui : acteur, cible, début du service, durée comptée.
- **Performance** : une mise à jour.
- **Cas limites** : cible déconnectée entre-temps → `gestion.employes.plus_en_service` ; cible de grade égal → `commun.erreur.pas_droit` ; double clic → une seule fin.
- **Critères d'acceptation** :
  - Étant donné un chef et une recrue en service, quand le chef termine son service, alors la ligne a `raison_fin = 'force'` et `force_par` = chef.
  - Étant donné un chef qui vise un autre chef, alors refus `commun.erreur.pas_droit`.
  - Étant donné une recrue qui appelle le RPC par console, alors refus `droit`, rien n'est écrit.

### [ENT-GES-05] Liste des employés
- **But** : voir tous les employés de l'entreprise avec leur grade, leur état de service et leurs heures de la semaine.
- **Qui** : droit `employes.voir` (Chef, Patron par défaut).
- **Où** : Gestion > Employés.
- **Parcours** :
  1. Ouverture de l'onglet → RPC `gestion.employes.liste` `{ page, tri, recherche }`.
  2. Serveur : lit les employés par `Bridge.GetEmployees(job)` (ESX `SELECT identifier, firstname, lastname, job_grade FROM users WHERE job = ?` ; QBCore `SELECT citizenid, charinfo, job FROM players WHERE JSON_VALUE(job, '$.name') = ?` ; Qbox `exports.qbx_core:GetGroupMembers(job, 'job')` + `players.charinfo`), joint le libellé du grade (cache des métiers du bridge), l'état en service (mémoire `Service.Actifs`), l'état connecté, et les heures de la semaine (somme des `duree` des services commencés depuis lundi 00:00 + durée en cours pour ceux en service).
  3. Interface : tableau paginé 20 par page. Colonnes : « Nom », « Grade », « État » (pastille « En service » accent / « Connecté » blanc / « Absent » gris), « Heures (semaine) ». Recherche par nom (3 caractères min). Tri : grade (défaut, du plus haut au plus bas), nom, heures.
  4. Clic sur une ligne → fiche employé (ENT-GES-06).
  5. En haut : « {n} employés · {m} en service » et bouton « Recruter » (si droit `recruter`).
- **Données** (affichées) :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `identifier` | VARCHAR(60) | Oui | caché | — |
| `nom` | texte | Oui | prénom + nom | — |
| `grade` / `gradeLabel` | INT / texte | Oui | — | — |
| `etat` | `service`/`connecte`/`absent` | Oui | — | — |
| `heuresSemaine` | INT (secondes) | Oui | — | 0 |

- **Règles serveur** : droit `employes.voir` ; pagination 20 ; recherche nettoyée, max 30 caractères ; fréquence 1/s.
- **Textes et états** :
  - Titre « Employés » (`gestion.employes.titre`).
  - Vide (seul employé = soi) : « Vous êtes seul dans l'entreprise. » + bouton « Recruter » (`gestion.employes.vide`).
  - Recherche sans résultat : « Aucun employé à ce nom. » (`gestion.employes.recherche_vide`).
  - Pas le droit : entrée de menu cachée.
- **Notifications** : aucune.
- **Liens** : Recruter (ENT-GES-07), fiche employé, Planning (lit les mêmes heures via export `exports.pop_tablet:GetWeeklyHours(company, identifier)`).
- **Réglages** : `Config.Limits.PageSize = 20` (global).
- **Journal admin** : non.
- **Performance** : une requête paginée (`LIMIT 20 OFFSET`) sur `users` + une requête agrégée sur `pop_tablet_ent_services` limitée aux 20 identifiants de la page ; libellés de grades depuis le cache ESX ; rien n'est chargé tant que l'onglet n'est pas ouvert.
- **Cas limites** : entreprise de 300 employés → pagination ; employé dont le grade n'existe plus dans `job_grades` → libellé « Grade inconnu ({n}) » (`gestion.employes.grade_inconnu`) ; joueur qui perd le droit pendant qu'il regarde → page suivante refusée `commun.erreur.pas_droit` et retour à l'accueil de l'app.
- **Critères d'acceptation** :
  - Étant donné 25 employés, quand le chef ouvre la liste, alors il voit 20 lignes et « Suivant ».
  - Étant donné un employé en service depuis 1 h lundi, alors ses heures affichent « 1 h 00 min » (au moins).
  - Étant donné une recrue qui appelle `gestion.employes.liste` par console, alors refus `droit`.

### [ENT-GES-06] Fiche d'un employé
- **But** : voir le détail d'un employé : grade, heures de la semaine et des 4 semaines précédentes, derniers services, et accéder aux actions (promouvoir, rétrograder, virer, prime, terminer son service).
- **Qui** : droit `employes.voir` ; boutons d'action selon leurs propres droits.
- **Où** : Gestion > Employés > clic sur une ligne.
- **Parcours** :
  1. RPC `gestion.employes.fiche` `{ identifier }`.
  2. Serveur : vérifie que l'identifiant est bien dans l'entreprise ; renvoie nom, grade, date d'embauche (première ligne `pop_tablet_ent_invitations` acceptée, sinon « Inconnue »), état, heures par semaine sur 5 semaines (semaine en cours + 4), 10 derniers services (début, fin, durée, raison).
  3. Interface : en-tête (nom, grade, pastille d'état), barre de 5 semaines (chiffres, pas de graphique obligatoire), liste des services, boutons en bas : « Promouvoir », « Rétrograder », « Virer », « Verser une prime », « Terminer son service ». Chaque bouton n'apparaît que si l'acteur a le droit **et** si la cible est sous son grade (règle de ENT-GES-09).
  4. Bouton « Voir plus » charge 10 services de plus (max 100).
- **Données** (affichées) : `nom`, `gradeLabel`, `embauche` (date), `etat`, `heures[5]` (secondes), `services[]` (`debut`, `fin`, `duree`, `raison_fin`).
- **Règles serveur** : droit ; même entreprise ; fréquence 1/s.
- **Textes et états** : titres « Heures par semaine » (`gestion.fiche.heures`), « Derniers services » (`gestion.fiche.services`), « Embauché le {date} » (`gestion.fiche.embauche`) ; vide : « Aucun service enregistré. » (`gestion.fiche.services_vide`) ; erreur cible partie : « Cette personne ne fait plus partie de l'entreprise. » (`gestion.fiche.plus_membre`).
- **Notifications** : aucune.
- **Liens** : ENT-GES-04, 09, 10, 11, 26.
- **Réglages** : `Config.Gestion.SemainesHistorique = 5`.
- **Journal admin** : non.
- **Performance** : 2 requêtes indexées (`identifier`, `debut`), limitées à 5 semaines et 10 lignes.
- **Cas limites** : employé hors ligne → fonctionne (données en base) ; service en cours → affiché « En cours » avec durée jusqu'à maintenant ; identifiant d'une autre entreprise envoyé par console → `gestion.fiche.plus_membre`.
- **Critères d'acceptation** :
  - Étant donné un employé avec 3 services cette semaine (1 h, 2 h, 30 min), alors la semaine en cours affiche « 3 h 30 min ».
  - Étant donné un chef qui ouvre la fiche d'un autre chef, alors les boutons Promouvoir/Rétrograder/Virer ne sont pas affichés.
  - Étant donné un chef d'une entreprise A qui demande la fiche d'un employé de B, alors refus et aucune donnée renvoyée.

### [ENT-GES-07] Recruter : inviter un joueur proche
- **But** : proposer à un joueur à côté de soi de rejoindre l'entreprise au grade le plus bas.
- **Qui** : droit `recruter` (Chef, Patron) ; réglable.
- **Où** : Gestion > Employés > bouton « Recruter ».
- **Parcours** :
  1. Clic → RPC `gestion.recrutement.proches`. Le serveur renvoie les joueurs à 3 m ou moins (règle 0.6), sauf soi et sauf ceux déjà dans l'entreprise : nom RP + identifiant temporaire (`source`, jamais l'identifiant ESX).
  2. Fenêtre « Recruter » : liste des personnes proches (nom + métier actuel, ex. « Jean Dupont · Mécano »). Bouton « Actualiser ». Si vide : texte vide.
  3. Le recruteur choisit une personne → « Inviter ».
  4. RPC `gestion.recrutement.inviter` `{ cible = source }`.
  5. Serveur : revérifie droit, distance (3 m), cible pas déjà membre, cible sans invitation en cours, plafond d'employés ; crée une invitation en mémoire `Invitations[cible] = { company, par, expire = os.time() + 60 }` et une ligne `pop_tablet_ent_invitations` (`statut = 'envoyee'`).
  6. Serveur : envoie l'invitation à la cible (tablette si `Bridge.HasTablet`, sinon fenêtre simple) → ENT-GES-08.
  7. Recruteur : bandeau « Invitation envoyée à {nom}. » ; il reçoit plus tard la réponse en notification.
- **Données** (`pop_tablet_ent_invitations`) :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `id` | INT AUTO_INCREMENT | Oui | — | — |
| `company_id` | INT | Oui | `pop_tablet_companies.id` | — |
| `par` | VARCHAR(60) | Oui | identifiant recruteur | — |
| `cible` | VARCHAR(60) | Oui | identifiant cible | — |
| `cible_nom` | VARCHAR(100) | Oui | — | — |
| `ancien_metier` | VARCHAR(50) | Oui | métier de la cible à l'envoi | — |
| `statut` | ENUM(`envoyee`,`acceptee`,`refusee`,`expiree`) | Oui | — | `envoyee` |
| `cree_le` | INT UNSIGNED | Oui | — | `os.time()` |
| `repondu_le` | INT UNSIGNED | Non | — | NULL |

- **Règles serveur** : droit `recruter` ; distance ≤ 3 m à l'envoi ; cible connectée ; cible ≠ soi ; cible pas déjà membre ; une seule invitation en cours par cible (toutes entreprises confondues) ; expiration 60 s (`Config.Recrutement.Expiration = 60`) ; plafond `Config.Entreprises.Liste[company].MaxEmployes` (0 = illimité, défaut 0) ; fréquence : 1 invitation toutes les 10 s par recruteur (`Config.Recrutement.Frequence = 10`).
- **Textes et états** :
  - Titre « Recruter » (`gestion.recrutement.titre`).
  - Vide : « Personne à moins de 3 m. Approchez-vous de la personne puis actualisez. » + « Actualiser » (`gestion.recrutement.vide`).
  - Succès : « Invitation envoyée à {nom}. » (`gestion.recrutement.envoyee`).
  - Erreurs : `commun.erreur.trop_loin` ; « {nom} a déjà une invitation en attente. » (`gestion.recrutement.deja_invite`) ; « {nom} fait déjà partie de l'entreprise. » (`gestion.recrutement.deja_membre`) ; « Nombre maximum d'employés atteint ({max}). » (`gestion.recrutement.plein`) ; `commun.erreur.hors_ligne` ; `commun.erreur.trop_vite`.
  - Pas le droit : bouton « Recruter » caché.
- **Notifications** : au recruteur après réponse : « {nom} a accepté votre invitation. » (`gestion.recrutement.notif_acceptee`) / « {nom} a refusé votre invitation. » (`gestion.recrutement.notif_refusee`) / « L'invitation de {nom} a expiré. » (`gestion.recrutement.notif_expiree`).
- **Liens** : ENT-GES-08.
- **Réglages** : `Config.Recrutement.Expiration = 60` ; `Config.Recrutement.Frequence = 10` ; `Config.Entreprises.Liste[company].MaxEmployes = 0`.
- **Journal admin** : oui à l'acceptation seulement (voir ENT-GES-08).
- **Performance** : calcul de proximité seulement au clic (boucle sur les joueurs connectés une fois) ; invitations en mémoire ; l'expiration est vérifiée à la réponse (pas de minuteur) et un `SetTimeout` unique de 60 s par invitation envoie la notification « expirée » s'il n'y a pas eu de réponse.
- **Cas limites** : cible qui s'éloigne après l'envoi → l'invitation reste valable 60 s (la distance compte à l'envoi) ; cible qui se déconnecte → invitation supprimée, statut `expiree` ; recruteur qui perd son droit avant la réponse → l'acceptation est refusée (ENT-GES-08) ; double clic → une seule invitation.
- **Critères d'acceptation** :
  - Étant donné un chef à 2 m d'un joueur sans emploi, quand il clique « Recruter », alors ce joueur apparaît dans la liste.
  - Étant donné un joueur à 10 m, alors il n'apparaît pas et une invitation forcée par console est refusée `loin`.
  - Étant donné une invitation en attente pour Jean, quand un autre recruteur invite Jean, alors refus `deja_invite`.

### [ENT-GES-08] Répondre à une invitation de recrutement
- **But** : la personne invitée accepte ou refuse, sur sa tablette ou en fenêtre simple.
- **Qui** : la cible de l'invitation uniquement.
- **Où** : notification tablette « Invitation » qui ouvre une fenêtre dans la tablette ; ou fenêtre simple sans tablette.
- **Parcours** :
  1. La cible voit : titre « Offre d'emploi », texte « {entreprise} vous propose de rejoindre l'équipe au grade {grade}. » ; si elle a déjà un métier (autre que sans emploi) : ligne en plus « Vous quitterez votre emploi actuel : {metier}. » ; compte à rebours 60 s ; boutons « Accepter » / « Refuser ».
  2. RPC `gestion.recrutement.repondre` `{ accepte = true|false }` (pas d'identifiant d'invitation venant du client : le serveur prend `Invitations[source]`).
  3. Serveur si refus : statut `refusee`, notification au recruteur, fin.
  4. Serveur si accepte : vérifie que l'invitation existe et n'est pas expirée ; revérifie que le recruteur a toujours le droit `recruter` dans cette entreprise (s'il est déconnecté, on vérifie le droit de son grade en base) ; plafond d'employés ; puis `Bridge.SetJob(source, company, gradeLePlusBas)`.
  5. Si la cible était en service ailleurs → fin de service `changement_metier` (ENT-GES-03).
  6. Statut `acceptee`, `repondu_le`. Journal. Notification au recruteur et aux employés ayant `employes.voir` en service : « {nom} rejoint l'entreprise. ».
  7. La tablette de la cible recharge ses apps (nouveaux droits).
- **Données** : `pop_tablet_ent_invitations.statut`, `repondu_le`.
- **Règles serveur** : invitation existante pour cet appelant ; non expirée (`os.time() <= expire`) ; plafond ; recruteur toujours autorisé ; fréquence 1/s ; « Plus tard » / Échap = aucune réponse (expire à 60 s).
- **Textes et états** :
  - Titre « Offre d'emploi » (`gestion.invitation.titre`) ; texte (`gestion.invitation.texte`) ; ligne métier (`gestion.invitation.quitte_metier`).
  - Boutons « Accepter » (`gestion.invitation.accepter`), « Refuser » (`gestion.invitation.refuser`).
  - Succès accepté : « Bienvenue chez {entreprise} ! » (`gestion.invitation.bienvenue`).
  - Succès refusé : « Offre refusée. » (`gestion.invitation.refusee`).
  - Erreurs : « Cette offre a expiré. » (`gestion.invitation.expiree`) ; « Cette offre n'est plus valable. » (`gestion.invitation.invalide`, recruteur sans droit ou entreprise pleine).
- **Notifications** : recruteur (voir ENT-GES-07) ; responsables en service : « {nom} rejoint l'entreprise. » (`gestion.invitation.notif_equipe`).
- **Liens** : ESX (`setJob`), annuaire (nombre d'employés), Planning (nouvel employé disponible).
- **Réglages** : ceux de ENT-GES-07.
- **Journal admin** : oui : recruteur, nouvel employé, ancien métier, nouveau métier et grade.
- **Performance** : une écriture ESX + une mise à jour SQL.
- **Cas limites** : réponse après 60 s → `expiree` ; deux clics « Accepter » → un seul `setJob` (action unique + invitation supprimée de la mémoire au premier traitement) ; cible inconsciente → la fenêtre s'affiche quand même (aucun argent en jeu) ; cible policier invité par un garage → accepté, il perd son métier de policier (texte d'avertissement affiché).
- **Critères d'acceptation** :
  - Étant donné une invitation valable, quand la cible accepte, alors son métier ESX devient l'entreprise au grade le plus bas.
  - Étant donné une cible sans tablette, alors l'offre s'affiche en fenêtre simple et le choix fonctionne de la même façon.
  - Étant donné un joueur sans invitation qui envoie `gestion.recrutement.repondre { accepte = true }`, alors refus `invalide` et son métier ne change pas.

### [ENT-GES-09] Promouvoir un employé
- **But** : faire monter un employé d'un ou plusieurs grades.
- **Qui** : droit `membres.gerer`. Un Chef (ou tout grade non patron ayant ce droit) agit seulement sur un employé de grade **strictement inférieur** au sien et ne peut pas le faire monter **au-delà du grade juste en dessous du sien**. Le Patron agit sur tout employé non patron et peut nommer un autre Patron (confirmation renforcée). Admin : tout.
- **Où** : Gestion > Employés > fiche employé > « Promouvoir ».
- **Parcours** :
  1. Clic → fenêtre « Promouvoir {nom} » avec une liste déroulante des grades autorisés (de grade actuel + 1 jusqu'au maximum permis), présélection = grade actuel + 1. Le salaire de chaque grade est affiché à côté (« Vendeur · 450 $ »).
  2. Si le grade choisi est le grade Patron : texte d'avertissement « {nom} aura tous les droits, comme vous. » et le bouton devient « Nommer patron ».
  3. « Confirmer » → RPC `gestion.membres.promouvoir` `{ identifier, grade }`.
  4. Serveur : relit le grade actuel de la cible (ESX si connectée, sinon `users.job_grade`) ; vérifie cible dans l'entreprise, `grade > gradeActuel`, grade existant, règles de grade de l'acteur.
  5. Cible connectée : `Bridge.SetJob(cibleSource, company, grade)`. Hors ligne : `Bridge.SetJobOffline(identifier, company, grade)` (ESX `UPDATE users SET job_grade = ? WHERE identifier = ? AND job = ?` ; QBCore mise à jour de la colonne JSON `players.job` ; Qbox `exports.qbx_core:AddPlayerToJob(citizenid, job, grade)`).
  6. Journal, notification à la cible, la fiche se met à jour, bandeau succès.
- **Données** : aucune nouvelle table ; ESX `users.job_grade`. Affiché : liste `{ grade, label, salaire }`.
- **Règles serveur** : droit ; même entreprise ; règle de grade (ci-dessus) ; grade cible > grade actuel ; on ne se promeut jamais soi-même ; fréquence 1/s ; si un Patron promeut au grade Patron et que `Config.Gestion.PlusieursPatrons = false` → refus.
- **Textes et états** :
  - Titre « Promouvoir {nom} » (`gestion.membres.promouvoir_titre`) ; bouton « Promouvoir » (`gestion.membres.promouvoir`) ; avertissement patron (`gestion.membres.avert_patron`) ; bouton « Nommer patron » (`gestion.membres.nommer_patron`).
  - Succès : « {nom} est maintenant {grade}. » (`gestion.membres.succes_grade`).
  - Erreurs : « Grade déjà atteint ou dépassé. » (`gestion.membres.grade_invalide`) ; « Vous ne pouvez pas donner un grade égal ou supérieur au vôtre. » (`gestion.membres.au_dessus`) ; « Un seul patron est autorisé. » (`gestion.membres.un_patron`) ; `gestion.fiche.plus_membre`.
  - Aucun grade possible (cible juste sous l'acteur) : bouton caché.
- **Notifications** : cible : « Vous êtes promu {grade} chez {entreprise}. » (`gestion.membres.notif_promu`).
- **Liens** : ESX ; Droits (les nouveaux droits s'appliquent aussitôt) ; Planning.
- **Réglages** : `Config.Gestion.PlusieursPatrons = true`.
- **Journal admin** : oui : acteur, cible, grade avant, grade après.
- **Performance** : une écriture.
- **Cas limites** : cible hors ligne → mise à jour en base, notification perdue (pas de file) ; deux chefs promeuvent la même cible en même temps → le serveur traite dans l'ordre, la 2e demande relit le grade et peut être refusée `grade_invalide` ; cible virée entre-temps → `plus_membre`.
- **Critères d'acceptation** :
  - Étant donné un chef de grade 3 et une recrue de grade 0, quand il la promeut, alors il ne peut choisir que les grades 1 et 2.
  - Étant donné un employé hors ligne, quand le patron le promeut, alors `users.job_grade` est mis à jour et il a le nouveau grade à sa connexion.
  - Étant donné un chef qui envoie par console `{ grade = 5 }` (patron), alors refus `au_dessus`.

### [ENT-GES-10] Rétrograder un employé
- **But** : faire descendre un employé d'un ou plusieurs grades.
- **Qui** : droit `membres.gerer` ; cible de grade strictement inférieur à l'acteur ; le Patron agit sur tout employé non patron ; un Patron ne peut pas rétrograder un autre Patron (seul l'admin le peut).
- **Où** : Gestion > Employés > fiche employé > « Rétrograder ».
- **Parcours** :
  1. Fenêtre « Rétrograder {nom} » : liste des grades de 0 à grade actuel − 1, présélection grade actuel − 1 ; champ « Motif » facultatif.
  2. RPC `gestion.membres.retrograder` `{ identifier, grade, motif }`.
  3. Serveur : mêmes vérifications que ENT-GES-09, avec `grade < gradeActuel` et `grade >= 0`.
  4. `Bridge.SetJob` ou `SetJobOffline`. Journal. Notification.
- **Données** : `motif` : texte, facultatif, 100 caractères max, nettoyé (stocké seulement dans le journal).
- **Règles serveur** : comme ENT-GES-09 ; cible patron interdite sauf admin ; pas soi-même.
- **Textes et états** : titre « Rétrograder {nom} » (`gestion.membres.retrograder_titre`) ; bouton « Rétrograder » (`gestion.membres.retrograder`) ; champ « Motif (facultatif) » (`gestion.membres.motif`) ; succès `gestion.membres.succes_grade` ; erreurs : `gestion.membres.grade_invalide`, « Seul l'administrateur peut agir sur un patron. » (`gestion.membres.cible_patron`) ; cible déjà au grade le plus bas : bouton caché.
- **Notifications** : cible : « Vous êtes rétrogradé {grade} chez {entreprise}. » (`gestion.membres.notif_retrograde`) ; le motif est ajouté s'il existe : « Motif : {motif} ».
- **Liens** : ESX, Droits, Planning.
- **Réglages** : aucun.
- **Journal admin** : oui : acteur, cible, avant, après, motif.
- **Performance** : une écriture.
- **Cas limites** : dernier patron qui voudrait se rétrograder lui-même → interdit (pas soi-même) ; cible en service : reste en service ; motif de 500 caractères → `commun.erreur.trop_long`.
- **Critères d'acceptation** :
  - Étant donné un employé grade 2, quand le patron le rétrograde au grade 0, alors son grade ESX vaut 0.
  - Étant donné un patron qui vise un autre patron, alors refus `cible_patron`.
  - Étant donné un motif contenant `<script>`, alors il est enregistré sans balise.

### [ENT-GES-11] Virer un employé
- **But** : retirer un employé de l'entreprise (il redevient sans emploi).
- **Qui** : droit `membres.gerer` ; cible de grade strictement inférieur ; patron sur tout non-patron ; admin sur tous.
- **Où** : Gestion > Employés > fiche employé > « Virer » (bouton rouge discret, texte blanc sur fond d'erreur).
- **Parcours** :
  1. Fenêtre « Virer {nom} ? » + champ « Motif » facultatif + rappel « Cette action est immédiate. ».
  2. RPC `gestion.membres.virer` `{ identifier, motif }`.
  3. Serveur : vérifications de grade ; si la cible est en service → fin `renvoi` ; `Bridge.SetJob(cible, Config.Entreprises.MetierSansEmploi, 0)` ou hors ligne `SetJobOffline`.
  4. Les demandes assignées à la cible (`pop_tablet_ent_demandes.assigne_a`) repassent non assignées ; ses factures en attente restent valables, sa part employé future reviendra à l'entreprise (ENT-FAC-13).
  5. Journal, notification, retour à la liste.
- **Données** : `motif` 100 caractères max, facultatif.
- **Règles serveur** : droit ; grades ; pas soi-même (voir ENT-GES-12) ; fréquence 1/s.
- **Textes et états** : titre « Virer {nom} ? » (`gestion.membres.virer_titre`) ; rappel (`gestion.membres.virer_rappel`) ; bouton « Virer » (`gestion.membres.virer`) ; succès « {nom} ne fait plus partie de l'entreprise. » (`gestion.membres.succes_vire`) ; erreurs comme ENT-GES-10.
- **Notifications** : cible : « Vous avez été renvoyé de {entreprise}. » + motif éventuel (`gestion.membres.notif_vire`).
- **Liens** : ESX ; Service (fin `renvoi`) ; Demandes (désassignation) ; Factures (part employé) ; Planning (créneaux futurs de la cible supprimés par le Planning sur l'événement serveur `pop_tablet:memberLeft` (`company, identifier`)).
- **Réglages** : aucun.
- **Journal admin** : oui : acteur, cible, grade avant, motif.
- **Performance** : 1 écriture ESX + 1 mise à jour demandes.
- **Cas limites** : cible hors ligne → base mise à jour, elle est sans emploi à sa connexion ; double clic → une seule action ; cible déjà partie → `gestion.fiche.plus_membre`.
- **Critères d'acceptation** :
  - Étant donné une recrue en service, quand le chef la vire, alors son service est fermé avec `renvoi` et son métier est `unemployed`.
  - Étant donné 2 demandes assignées à la cible, alors elles repassent sans assignation.
  - Étant donné un membre (sans droit) qui appelle `gestion.membres.virer` par console, alors refus `droit`.

### [ENT-GES-12] Démissionner (ajout)
- **But** : permettre à un employé de quitter lui-même l'entreprise sans dépendre d'un responsable.
- **Qui** : tout employé, sauf le dernier Patron de l'entreprise.
- **Où** : Gestion > Service > lien discret en bas « Quitter l'entreprise ».
- **Parcours** :
  1. Fenêtre « Quitter {entreprise} ? » + « Vous deviendrez sans emploi. » + « Confirmer ».
  2. RPC `gestion.membres.demissionner`.
  3. Serveur : si l'appelant est au grade Patron et qu'il n'existe aucun autre employé au grade Patron (en base) → refus. Sinon : fin de service `changement_metier`, `Bridge.SetJob(source, 'unemployed', 0)`, désassignation des demandes, événement `pop_tablet:memberLeft`.
  4. La tablette recharge les apps ; bandeau.
- **Données** : aucune nouvelle.
- **Règles serveur** : métier ≠ sans emploi ; dernier patron interdit ; fréquence 1 toutes les 10 s.
- **Textes et états** : lien « Quitter l'entreprise » (`gestion.membres.demission`) ; titre « Quitter {entreprise} ? » (`gestion.membres.demission_titre`) ; texte (`gestion.membres.demission_texte`) ; succès « Vous avez quitté {entreprise}. » (`gestion.membres.demission_succes`) ; erreur « Nommez d'abord un autre patron : une entreprise ne peut pas rester sans patron. » (`gestion.membres.dernier_patron`).
- **Notifications** : employés ayant `employes.voir` en service : « {nom} a quitté l'entreprise. » (`gestion.membres.notif_demission`).
- **Liens** : comme ENT-GES-11.
- **Réglages** : `Config.Gestion.DemissionAutorisee = true` (si `false`, le lien est caché, pour les serveurs qui veulent passer par un PNJ emploi).
- **Journal admin** : oui : employé, grade avant.
- **Performance** : une écriture.
- **Cas limites** : dernier patron → refus ; patron alors qu'un autre patron existe → autorisé ; double clic → une seule action.
- **Critères d'acceptation** :
  - Étant donné un membre, quand il démissionne, alors son métier devient `unemployed`.
  - Étant donné le seul patron, quand il démissionne, alors refus `dernier_patron`.
  - Étant donné `DemissionAutorisee = false`, quand un joueur appelle le RPC par console, alors refus `droit`.

### [ENT-GES-13] Écran Grades et salaires
- **But** : voir la liste des grades de l'entreprise avec leur salaire ESX et le nombre d'employés par grade.
- **Qui** : droit `grades.gerer` (Patron) ; réglable.
- **Où** : Gestion > Grades et salaires.
- **Parcours** :
  1. RPC `gestion.grades.liste`. Serveur lit les grades de l'entreprise (`Bridge.GetJobs()` : ESX `job_grades`, QBCore `QBCore.Shared.Jobs`, Qbox `GetJobs()`), compte les employés par grade (résultat de `Bridge.GetEmployees(job)` regroupé par grade, mis en cache 60 s).
  2. Tableau du plus haut au plus bas : « Grade », « Niveau » (Recrue/Membre/Chef/Patron, calculé règle 0.2), « Salaire », « Employés », boutons « Renommer », « Salaire », « Supprimer » par ligne ; bouton « Ajouter un grade » en haut.
  3. Bandeau d'information fixe en haut : « Les salaires sont versés par le serveur. La tablette change seulement le montant. ».
- **Données** (affichées) : `grade` (INT), `name` (nom interne), `label`, `salaire` (INT), `employes` (INT), `niveau`.
- **Règles serveur** : droit ; fréquence 1/s.
- **Textes et états** : titre « Grades et salaires » (`gestion.grades.titre`) ; info (`gestion.grades.info_salaire`) ; libellés de niveau `gestion.niveau.recrue` « Recrue », `.membre` « Membre », `.chef` « Chef », `.patron` « Patron ». Vide impossible (une entreprise ESX a au moins 1 grade) ; si 1 seul grade : « Ajoutez un grade pour organiser votre équipe. » (`gestion.grades.un_seul`).
- **Notifications** : aucune.
- **Liens** : ENT-GES-14 à 17.
- **Réglages** : `Config.Grades.Modifiables = true` (si `false`, tableau en lecture seule pour tous sauf admin).
- **Journal admin** : non.
- **Performance** : cache ESX + 1 requête groupée.
- **Cas limites** : métier créé hors tablette avec trous dans la numérotation (0, 1, 4) → affiché tel quel, niveaux calculés sur l'ordre ; `Modifiables = false` → boutons cachés ; grade sans employé → « 0 ».
- **Critères d'acceptation** :
  - Étant donné une entreprise à 4 grades, alors le tableau montre 4 lignes avec niveaux Recrue, Membre, Chef, Patron.
  - Étant donné un chef, alors l'entrée de menu « Grades et salaires » est cachée.
  - Étant donné un chef qui appelle `gestion.grades.liste` par console, alors refus `droit`.

### [ENT-GES-14] Créer un grade
- **But** : ajouter un nouveau grade au métier de l'entreprise (ESX, QBCore ou Qbox), à la position choisie, y compris au milieu de la liste.
- **Qui** : droit `grades.gerer` (Patron) ; admin.
- **Où** : Grades et salaires > « Ajouter un grade ».
- **Parcours** :
  1. Fenêtre : « Nom du grade » (texte), « Salaire » (nombre), « Position » : liste « Juste au-dessus de {grade} » pour chaque grade sauf le Patron (le nouveau grade ne peut pas devenir le plus haut ni le plus bas, sauf si l'entreprise n'a qu'un grade : alors il est créé sous le Patron et devient le plus bas).
  2. **Avertissement avant validation** (toujours affiché dans la fenêtre, car toute création décale au moins le numéro du grade Patron) : encadré sobre au-dessus du bouton, texte « Les numéros des grades situés au-dessus vont changer. Les scripts qui utilisent ces numéros peuvent être affectés. » (`gestion.grades.avertissement_renumerotation`). Le bouton « Créer » devient « Créer quand même » (`gestion.grades.creer_quand_meme`) ; « Annuler » (`commun.bouton.annuler`) ferme sans rien faire. Le serveur exige `confirmeRenumerotation = true`, sinon refus `invalide`.
  3. RPC `gestion.grades.creer` `{ label, salaire, auDessusDe, confirmeRenumerotation }`.
  4. Serveur, dans une transaction SQL : décale de +1 les grades dont le numéro est > `auDessusDe` (`job_grades` puis `users.job_grade` pour ce métier, du plus haut au plus bas pour éviter les doublons de clé) ; insère le nouveau grade au numéro `auDessusDe + 1` avec `name` = label en minuscules sans accents ni espaces (ex. « Chef d'atelier » → `chef_datelier`, suffixe `_2` si déjà pris), `skin_male = '{}'`, `skin_female = '{}'`.
  5. Serveur : décale aussi les clés de `pop_tablet_ent_permissions` (les droits suivent le grade) et copie pour le nouveau grade les droits du grade juste en dessous.
  6. `Bridge.SaveGrades(job, grades)` puis rafraîchissement (ESX `ESX.RefreshJobs()` après l'écriture dans `job_grades` / `users` ; QBCore `QBCore.Functions.UpdateJob` + mise à jour de `players.job` des employés hors ligne décalés ; Qbox `exports.qbx_core:UpsertJobGrade` + `player_groups`) ; sur QBCore et Qbox la nouvelle liste est aussi écrite dans `pop_tablet_company_grades` (réappliquée au démarrage). Pour chaque employé connecté dont le numéro a changé : `Bridge.SetPlayerJob(src, company, nouveauNumero)` (aucun changement visible pour lui).
  7. Journal ; tableau rechargé ; bandeau.
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `label` | VARCHAR(50) | Oui | 2 à 30 caractères, nettoyé, unique dans l'entreprise (sans tenir compte des majuscules) | — |
| `salaire` | INT | Oui | 0 à `Config.Grades.SalaireMax` | 0 |
| `auDessusDe` | INT | Oui | numéro d'un grade existant ≠ Patron | grade le plus bas |

- **Règles serveur** : droit ; `Config.Grades.Modifiables` ; nombre de grades < `Config.Grades.Max` ; libellé unique ; salaire entier dans les bornes ; fréquence : 1 modification de grades toutes les 5 s par entreprise (`Config.Grades.Frequence = 5`) ; transaction annulée entièrement si une étape échoue.
- **Textes et états** : titre « Ajouter un grade » (`gestion.grades.creer_titre`) ; avertissement « Les numéros des grades situés au-dessus vont changer. Les scripts qui utilisent ces numéros peuvent être affectés. » (`gestion.grades.avertissement_renumerotation`) ; bouton « Créer quand même » (`gestion.grades.creer_quand_meme`) ; champs « Nom du grade » (`gestion.grades.champ_nom`), « Salaire » (`gestion.grades.champ_salaire`), « Position » (`gestion.grades.champ_position`), option « Juste au-dessus de {grade} » (`gestion.grades.au_dessus_de`) ; succès « Grade {grade} créé. » (`gestion.grades.cree`) ; erreurs « Ce nom de grade existe déjà. » (`gestion.grades.nom_pris`), « Nombre maximum de grades atteint ({max}). » (`gestion.grades.max`), « Salaire entre 0 et {max} $. » (`gestion.grades.salaire_borne`).
- **Notifications** : aucune.
- **Liens** : framework via le bridge (ESX `job_grades`, `users` ; QBCore `QBCore.Shared.Jobs`, `players` ; Qbox `qbx_core`, `player_groups`), Droits (copie), Planning (lit les grades par le bridge).
- **Réglages** : `Config.Grades.Max = 15` ; `Config.Grades.SalaireMax = 5000` ; `Config.Grades.Frequence = 5` ; `Config.Grades.Modifiables = true`.
- **Journal admin** : oui : acteur, libellé, salaire, position, liste des numéros décalés.
- **Performance** : une transaction ; rafraîchissement ESX une fois.
- **Cas limites** : deux créations simultanées dans la même entreprise → verrou mémoire par entreprise (`Grades.Verrou[company]`), la 2e reçoit `commun.erreur.trop_vite` ; ESX sans `RefreshJobs` (version ancienne) → le bridge recharge les métiers par sa propre requête et prévient en console « [pop_tablet] ESX.RefreshJobs absent : redémarrage conseillé pour les salaires » ; libellé « <b>Chef</b> » → enregistré « Chef ».
- **Critères d'acceptation** :
  - Étant donné les grades 0 Recrue, 1 Vendeur, 2 Patron, quand le patron crée « Chef » au-dessus de Vendeur, alors les grades deviennent 0 Recrue, 1 Vendeur, 2 Chef, 3 Patron et les anciens patrons ont `job_grade = 3`.
  - Étant donné 15 grades, alors la création est refusée `max`.
  - Étant donné un salaire de 999999 envoyé par console, alors refus `salaire_borne`.

### [ENT-GES-15] Renommer un grade
- **But** : changer le nom affiché d'un grade.
- **Qui** : droit `grades.gerer` ; admin.
- **Où** : Grades et salaires > ligne > « Renommer ».
- **Parcours** : 1. Champ prérempli avec le libellé actuel. 2. RPC `gestion.grades.renommer` `{ grade, label }`. 3. Serveur : `Bridge.SaveGrades` (ESX `UPDATE job_grades SET label = ? WHERE job_name = ? AND grade = ?` + `ESX.RefreshJobs()` ; QBCore `UpdateJob` ; Qbox `UpsertJobGrade` ; QBCore / Qbox : aussi écrit dans `pop_tablet_company_grades`) ; le `name` interne ne change pas ; pour chaque employé connecté de ce grade `Bridge.SetPlayerJob(src, company, grade)` pour rafraîchir le libellé. 4. Journal, bandeau.
- **Données** : `label` 2 à 30 caractères, nettoyé, unique dans l'entreprise.
- **Règles serveur** : droit ; `Modifiables` ; grade existant ; unicité ; fréquence `Config.Grades.Frequence`.
- **Textes et états** : bouton « Renommer » (`gestion.grades.renommer`) ; succès « Grade renommé en {grade}. » (`gestion.grades.renomme`) ; erreurs `gestion.grades.nom_pris`, `commun.erreur.champ_requis`, `commun.erreur.trop_long`.
- **Notifications** : aucune.
- **Liens** : ESX ; tout écran affichant un grade (cache vidé).
- **Réglages** : ceux de ENT-GES-14.
- **Journal admin** : oui : grade, libellé avant/après.
- **Performance** : une mise à jour.
- **Cas limites** : même nom → `ok` sans écriture ; grade supprimé entre-temps → « Ce grade n'existe plus. » (`gestion.grades.inexistant`) ; libellé vide après nettoyage → `texte_vide`.
- **Critères d'acceptation** :
  - Étant donné le grade « Vendeur », quand le patron le renomme « Conseiller », alors les employés connectés voient « Conseiller » sans se reconnecter.
  - Étant donné un nom déjà utilisé par un autre grade, alors refus `nom_pris`.
  - Étant donné un chef qui appelle le RPC par console, alors refus `droit`.

### [ENT-GES-16] Fixer le salaire d'un grade
- **But** : changer le salaire que **le framework** (ESX, QBCore ou Qbox) verse aux employés de ce grade, sans que la tablette verse quoi que ce soit.
- **Qui** : droit `grades.gerer` ; admin.
- **Où** : Grades et salaires > ligne > « Salaire ».
- **Parcours** :
  1. Champ nombre prérempli + rappel « Versé par le serveur toutes les {n} minutes. » ({n} = `Config.Grades.IntervalleAffiche`, valeur purement informative à régler comme l'intervalle de paie du framework : ESX `Config.PaycheckInterval`, QBCore `QBCore.Config.Money.PayCheckTimeOut`, Qbox `paycheckTimeout`).
  2. RPC `gestion.grades.salaire` `{ grade, salaire }`.
  3. Serveur : `Bridge.SaveGrades` (ESX `UPDATE job_grades SET salary = ? WHERE job_name = ? AND grade = ?` + `ESX.RefreshJobs()`, ESX lit le salaire dans son cache à chaque paie ; QBCore champ `payment` du grade par `UpdateJob` ; Qbox champ `payment` par `UpsertJobGrade` ; QBCore / Qbox : aussi écrit dans `pop_tablet_company_grades`).
  4. Journal ; bandeau.
- **Données** : `salaire` INT 0 à `Config.Grades.SalaireMax` (5000).
- **Règles serveur** : droit ; `Modifiables` ; borne ; entier ; fréquence ; **aucun versement** par la tablette (ni rattrapage, ni paie immédiate) ; aucun minuteur de paie dans la tablette.
- **Textes et états** : bouton « Salaire » (`gestion.grades.salaire`) ; rappel (`gestion.grades.rappel_paie`) ; succès « Salaire de {grade} : {montant}. » (`gestion.grades.salaire_ok`) ; erreur `gestion.grades.salaire_borne`.
- **Notifications** : employés connectés de ce grade : « Votre salaire passe à {montant}. » (`gestion.grades.notif_salaire`).
- **Liens** : paie du framework. Si le framework est réglé pour payer depuis le compte société (ESX `Config.EnableSocietyPayouts` ; QBCore / Qbox : paie depuis le compte du métier si activée dans leur config), le compte de l'entreprise baisse à chaque paie : c'est le framework qui le fait, pas la tablette.
- **Réglages** : `Config.Grades.SalaireMax = 5000` ; `Config.Grades.IntervalleAffiche = 7` (minutes).
- **Journal admin** : oui : grade, salaire avant/après.
- **Performance** : une mise à jour.
- **Cas limites** : salaire négatif ou décimal par console → refus `salaire_borne` ; même valeur → `ok` sans écriture ; double clic → une seule mise à jour.
- **Critères d'acceptation** :
  - Étant donné le grade Recrue à 200 $, quand le patron met 300 $, alors le salaire du grade vaut 300 $ dans le framework (ESX `job_grades.salary`, QBCore / Qbox `payment`) et la paie suivante verse 300 $.
  - Étant donné ce changement, alors aucun argent n'est versé par la tablette (compte joueur inchangé jusqu'à la paie ESX).
  - Étant donné `salaire = -50` envoyé par console, alors refus.

### [ENT-GES-17] Supprimer un grade (ajout)
- **But** : retirer un grade devenu inutile.
- **Qui** : droit `grades.gerer` ; admin.
- **Où** : Grades et salaires > ligne > « Supprimer » (caché pour le grade le plus haut et le plus bas).
- **Parcours** :
  1. Si le grade a des employés → bouton grisé avec « Changez d'abord le grade des {n} employés concernés. ».
  2. Sinon confirmation « Supprimer le grade {grade} ? ».
  3. RPC `gestion.grades.supprimer` `{ grade }`.
  4. Serveur, transaction : revérifie 0 employé (ESX `users`, QBCore `players.job`, Qbox `player_groups`) ; supprime le grade ; décale de −1 les grades supérieurs (grades du métier, grades des employés, `pop_tablet_ent_permissions`, du plus bas au plus haut) ; supprime les droits du grade supprimé ; `Bridge.SaveGrades` (QBCore / Qbox : `RemoveJobGrade` / `UpdateJob` et `pop_tablet_company_grades`) ; `Bridge.SetPlayerJob` des connectés décalés. Avant validation, la confirmation affiche le même avertissement que ENT-GES-14 (`gestion.grades.avertissement_renumerotation`).
- **Données** : aucune nouvelle.
- **Règles serveur** : droit ; ni plus haut ni plus bas ; 0 employé ; minimum 2 grades restants ; verrou par entreprise ; fréquence.
- **Textes et états** : bouton « Supprimer » (`gestion.grades.supprimer`) ; grisé (`gestion.grades.supprimer_occupe`) ; confirmation (`gestion.grades.supprimer_confirm`) ; succès « Grade supprimé. » (`gestion.grades.supprime`) ; erreur « Des employés ont encore ce grade. » (`gestion.grades.occupe`).
- **Notifications** : aucune.
- **Liens** : ESX, Droits, Planning.
- **Réglages** : ceux de ENT-GES-14.
- **Journal admin** : oui : grade supprimé (numéro, libellé, salaire).
- **Performance** : une transaction.
- **Cas limites** : un employé hors ligne a ce grade → compté (requête sur `users`), refus ; recrutement au même moment → verrou ; tentative sur le grade Patron par console → refus `droit`.
- **Critères d'acceptation** :
  - Étant donné un grade intermédiaire vide, quand le patron le supprime, alors les grades au-dessus descendent d'un numéro et les employés gardent le même libellé.
  - Étant donné un grade avec 1 employé hors ligne, alors refus `occupe`.
  - Étant donné un appel console sur le grade 0, alors refus.

### [ENT-GES-18] Droits par grade
- **But** : choisir, case par case, ce que chaque grade peut faire dans la tablette, et le plafond de facture par grade.
- **Qui** : droit `grades.gerer` (Patron) ; admin.
- **Où** : Gestion > Droits.
- **Parcours** :
  1. RPC `gestion.droits.lire`. Serveur renvoie la grille : lignes = clés de droit (tableau 0.2 + droits des apps métier de l'entreprise, ex. police : `police.mandat.creer`, déclarés par chaque app dans `Perm.Declarer(cle, libelle, defautsParNiveau)`), colonnes = grades du plus bas au plus haut.
  2. Interface : tableau de cases à cocher, en-têtes de colonne = libellé du grade + niveau. Colonne Patron cochée et grisée. Ligne « Plafond de facture » sous la ligne `facture.creer` : un champ nombre par grade (0 = pas de plafond propre ; le plafond global `Config.Factures.TotalMax` reste appliqué).
  3. Les modifications ne sont pas envoyées une par une : barre en bas « {n} modifications » + « Enregistrer » / « Annuler les modifications ».
  4. RPC `gestion.droits.enregistrer` `{ changements = [{ grade, cle, valeur }], plafonds = [{ grade, montant }] }`.
  5. Serveur : vérifie droit, ignore toute ligne visant le grade Patron, vérifie que chaque clé est déclarée et chaque grade existe ; écrit en une requête groupée (`INSERT ... ON DUPLICATE KEY UPDATE`) ; met à jour le cache mémoire `Perm.Cache[company]`.
  6. Les employés connectés de l'entreprise reçoivent l'événement `pop_tablet:permissionsChanged` (sans contenu sensible) : leur tablette redemande ses droits la prochaine fois qu'une app est ouverte.
- **Données** (`pop_tablet_ent_permissions`) :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `company_id` | INT | Oui | `pop_tablet_companies.id` | — |
| `grade` | INT | Oui | grade existant | — |
| `cle` | VARCHAR(60) | Oui | clé déclarée | — |
| `valeur` | TINYINT(1) | Oui | 0/1 | défaut du niveau |
| `plafond` | INT | Non | seulement pour `cle = 'facture.creer'` ; 0 à `Config.Factures.TotalMax` | Recrue : 500 ; autres : 0 |

  Clé primaire (`company`, `grade`, `cle`). Une ligne absente = valeur par défaut du niveau (tableau 0.2). On n'écrit que les lignes différentes du défaut ou déjà présentes.
- **Règles serveur** : droit ; colonne Patron non modifiable ; clés inconnues rejetées ; 200 changements max par envoi ; fréquence 1 enregistrement toutes les 5 s ; `Perm.Has` lit uniquement le cache.
- **Textes et états** : titre « Droits par grade » (`gestion.droits.titre`) ; ligne « Plafond de facture ($, 0 = sans plafond) » (`gestion.droits.plafond`) ; barre « {n} modifications » (`gestion.droits.modifs`) ; boutons « Enregistrer » (`gestion.droits.enregistrer`), « Annuler les modifications » (`gestion.droits.annuler`) ; succès « Droits enregistrés. » (`gestion.droits.ok`) ; info sous la colonne Patron « Le patron a toujours tous les droits. » (`gestion.droits.patron`) ; quitter l'écran avec des modifications non enregistrées → « Quitter sans enregistrer ? » (`gestion.droits.quitter`).
- **Notifications** : aucune (mise à jour silencieuse).
- **Liens** : toutes les apps (lisent `Perm.Has`) ; export `exports.pop_tablet:HasPermission(source, cle)` pour les scripts tiers.
- **Réglages** : aucun propre ; la grille par défaut vient du tableau 0.2.
- **Journal admin** : oui : une entrée par enregistrement avec la liste des cases avant/après.
- **Performance** : cache chargé au démarrage du script (une requête pour toutes les entreprises), rafraîchi seulement par enregistrement ; aucune lecture SQL lors d'une vérification de droit.
- **Cas limites** : grade créé après la grille → ses droits sont copiés (ENT-GES-14) ; un chef retire au patron… impossible (colonne verrouillée et serveur ignore) ; 2 patrons enregistrent en même temps → le dernier enregistrement gagne, chacun voit le résultat final au rechargement.
- **Critères d'acceptation** :
  - Étant donné la grille par défaut, quand le patron coche « Publier une annonce » pour Membre et enregistre, alors un membre peut publier sans se reconnecter.
  - Étant donné un plafond Recrue de 500 $, quand une recrue fait une facture de 600 $, alors refus (ENT-FAC-01).
  - Étant donné un envoi console qui décoche `grades.gerer` pour le grade Patron, alors la ligne est ignorée et le patron garde le droit.

### [ENT-GES-19] Rétablir les droits par défaut (ajout)
- **But** : revenir à la grille par défaut du contexte en un clic après des essais.
- **Qui** : droit `grades.gerer` ; admin.
- **Où** : Gestion > Droits > bouton « Rétablir les droits par défaut » en bas à gauche.
- **Parcours** : 1. Confirmation « Remettre tous les droits et plafonds par défaut ? ». 2. RPC `gestion.droits.reinitialiser`. 3. Serveur : `DELETE FROM pop_tablet_ent_permissions WHERE company = ?`, cache vidé pour l'entreprise (retour aux défauts par niveau), événement `pop_tablet:permissionsChanged`. 4. Grille rechargée.
- **Données** : aucune.
- **Règles serveur** : droit ; fréquence 1 toutes les 30 s.
- **Textes et états** : bouton (`gestion.droits.defaut`) ; confirmation (`gestion.droits.defaut_confirm`) ; succès « Droits par défaut rétablis. » (`gestion.droits.defaut_ok`).
- **Notifications** : aucune.
- **Liens** : toutes les apps.
- **Réglages** : aucun.
- **Journal admin** : oui : grille complète avant réinitialisation (JSON).
- **Performance** : une requête.
- **Cas limites** : grille déjà par défaut → `ok` ; niveaux recalculés si le nombre de grades a changé ; double clic → une seule suppression.
- **Critères d'acceptation** :
  - Étant donné des droits modifiés, quand le patron rétablit, alors `pop_tablet_ent_permissions` ne contient plus aucune ligne pour l'entreprise.
  - Étant donné ce rétablissement, alors une recrue a de nouveau un plafond de 500 $.
  - Étant donné un chef qui appelle le RPC par console, alors refus `droit`.

### [ENT-GES-20] Voir le compte de l'entreprise
- **But** : voir le solde du compte de l'entreprise et la liste de ses entrées et sorties.
- **Qui** : droit `compte.voir` (Chef, Patron) ; admin.
- **Où** : Gestion > Compte.
- **Parcours** :
  1. RPC `gestion.compte.lire` `{ page, filtre }`.
  2. Serveur : solde via `Bridge.Society.GetMoney(company)` ; mouvements : `pop_tablet_ent_mouvements` (mouvements faits via la tablette ; chaque insertion émet le signal serveur `pop_tablet:accountMovement`, écouté par l'import du Tableur PRO-TAB-08).
  3. Interface : grand chiffre « Solde » en haut ; sous-titre « Source : {nom} » : « Compte société ESX », « qb-banking », « qb-management », « Renewed-Banking » ou le nom de l'adaptateur personnalisé (ENT-GES-23) ; boutons « Déposer », « Retirer » (si `compte.mouvement`), « Verser une prime » (si `compte.prime`) ; filtres « Tout / Entrées / Sorties » ; liste paginée 20 : date, libellé, personne, montant (« + 1 200 $ » en blanc, « − 300 $ » en gris clair, pas de rouge/vert pour rester sobre), solde après si connu.
  4. Pour tous les adaptateurs fournis (ESX, QBCore, Qbox) : note fixe sous la liste « Seuls les mouvements faits avec la tablette sont listés. Les salaires versés par le serveur n'y figurent pas. ».
- **Données** (`pop_tablet_ent_mouvements`) :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `id` | INT AUTO_INCREMENT | Oui | — | — |
| `company_id` | INT | Oui | `pop_tablet_companies.id` | — |
| `type` | ENUM(`depot`,`retrait`,`prime`,`facture`,`part_employe`,`annonce_ville`) | Oui | — | — |
| `montant` | INT | Oui | positif = entrée, négatif = sortie | — |
| `solde_apres` | INT | Non | lu juste après l'opération | NULL |
| `acteur` | VARCHAR(60) | Non | identifiant | NULL |
| `acteur_nom` | VARCHAR(100) | Non | — | NULL |
| `cible_nom` | VARCHAR(100) | Non | bénéficiaire ou client | NULL |
| `libelle` | VARCHAR(120) | Oui | nettoyé | — |
| `ref` | VARCHAR(40) | Non | n° de facture | NULL |
| `cree_le` | INT UNSIGNED | Oui | — | `os.time()` |

  Index (`company`, `cree_le`). Jamais supprimé.
- **Règles serveur** : droit ; pagination 20 ; filtre parmi `tout|entrees|sorties` ; fréquence 1/s.
- **Textes et états** : titre « Compte » (`gestion.compte.titre`) ; « Solde » (`gestion.compte.solde`) ; source (`gestion.compte.source_esx` / `gestion.compte.source_popbank`) ; note (`gestion.compte.note_esx`) ; filtres « Tout » / « Entrées » / « Sorties » (`gestion.compte.filtre.*`) ; vide : « Aucun mouvement pour l'instant. Déposez de l'argent pour commencer. » + bouton « Déposer » si droit (`gestion.compte.vide`) ; libellés de type : « Dépôt », « Retrait », « Prime à {nom} », « Facture {n°} », « Part employé {nom} », « Annonce à toute la ville » (`gestion.compte.type.*`) ; pas le droit : menu caché.
- **Notifications** : aucune.
- **Liens** : Factures (entrées), Primes, Annonces ville (sortie si payante), Banque (ENT-GES-23), Tableur (import des mouvements, app 3).
- **Réglages** : aucun propre.
- **Journal admin** : non (lecture).
- **Performance** : solde lu à l'ouverture seulement ; liste paginée indexée ; pas de rafraîchissement automatique (bouton « Actualiser »).
- **Cas limites** : compte société ESX inexistant (`society_<job>` absent) → le bridge le crée à 0 au premier accès et l'écrit en console ; solde négatif (autre script) → affiché tel quel ; adaptateur banque en erreur pendant la lecture → message « Banque indisponible. Réessayez dans un instant. » (`gestion.compte.repli`), aucune opération faite.
- **Critères d'acceptation** :
  - Étant donné un compte à 10 000 $, quand le chef ouvre Compte, alors il voit « 10 000 $ ».
  - Étant donné 30 mouvements, alors 20 s'affichent avec « Suivant ».
  - Étant donné une recrue qui appelle `gestion.compte.lire` par console, alors refus `droit`.

### [ENT-GES-21] Déposer de l'argent sur le compte
- **But** : verser son propre argent (liquide ou banque) sur le compte de l'entreprise.
- **Qui** : droit `compte.mouvement` (Patron) ; admin.
- **Où** : Gestion > Compte > « Déposer ».
- **Parcours** :
  1. Fenêtre : « Montant », choix « Depuis : Liquide / Banque » (défaut Liquide), affichage de l'argent disponible du joueur dans chaque source, motif facultatif.
  2. RPC `gestion.compte.deposer` `{ montant, source = 'money'|'bank', motif, actionId }`.
  3. Serveur : droit ; montant entier 1 à `Config.Compte.OperationMax` ; argent suffisant ; zone si `Config.Compte.ZoneRequise` ; retire au joueur (`Bridge.RemoveMoney`) **puis** ajoute à l'entreprise (`Bridge.Society.AddMoney`) ; si l'ajout échoue, rend l'argent au joueur et répond erreur.
  4. Écrit `pop_tablet_ent_mouvements` (`type = 'depot'`, `montant > 0`, `solde_apres`), journal.
  5. Bandeau ; solde et liste rechargés.
- **Données** : `montant` INT 1 à 1 000 000 (`Config.Compte.OperationMax`) ; `source` `money|bank` ; `motif` 60 caractères max, facultatif, défaut « Dépôt ».
- **Règles serveur** : droit ; entier positif ; plafond ; fonds du joueur ; anti double clic par `actionId` ; fréquence 1 toutes les 3 s (`Config.Compte.Frequence = 3`) ; zone : si `Config.Compte.ZoneRequise = true`, le joueur doit être à moins de `Config.Compte.ZoneRayon = 30.0` m du point `Config.Entreprises.Liste[company].Coords` (sinon pas de contrôle).
- **Textes et états** : titre « Déposer » (`gestion.compte.deposer`) ; champs « Montant » (`gestion.compte.montant`), « Depuis » (`gestion.compte.depuis`), « Liquide » (`commun.liquide`), « Banque » (`commun.banque`), « Motif (facultatif) » (`gestion.compte.motif`) ; succès « {montant} déposés. » (`gestion.compte.depot_ok`) ; erreurs « Vous n'avez pas assez d'argent. » (`gestion.compte.fonds_joueur`), « Montant entre 1 et {max} $. » (`gestion.compte.montant_borne`), « Faites cette opération dans les locaux de l'entreprise. » (`gestion.compte.zone`).
- **Notifications** : aucune (le patron agit lui-même).
- **Liens** : Banque ; Tableur.
- **Réglages** : `Config.Compte.OperationMax = 1000000` ; `Config.Compte.Frequence = 3` ; `Config.Compte.ZoneRequise = false` ; `Config.Compte.ZoneRayon = 30.0`.
- **Journal admin** : oui : acteur, montant, source, solde entreprise avant/après.
- **Performance** : 2 appels bridge + 1 insertion.
- **Cas limites** : double clic → un seul dépôt (`actionId`) ; argent dépensé entre l'affichage et la validation → `fonds_joueur` ; échec d'écriture côté société → remboursement automatique et `commun.erreur.serveur` + journal « dépôt annulé ».
- **Critères d'acceptation** :
  - Étant donné un patron avec 5 000 $ en liquide, quand il dépose 2 000 $, alors son liquide passe à 3 000 $ et le compte augmente de 2 000 $.
  - Étant donné deux envois avec le même `actionId`, alors un seul dépôt a lieu.
  - Étant donné `montant = -1000` ou `1.5` envoyé par console, alors refus `montant_borne` et rien ne bouge.

### [ENT-GES-22] Retirer de l'argent du compte
- **But** : sortir de l'argent du compte de l'entreprise vers son liquide ou sa banque.
- **Qui** : droit `compte.mouvement` (Patron) ; admin.
- **Où** : Gestion > Compte > « Retirer ».
- **Parcours** :
  1. Fenêtre : « Montant », « Vers : Liquide / Banque » (défaut Banque), solde de l'entreprise affiché, motif **obligatoire**.
  2. RPC `gestion.compte.retirer` `{ montant, vers, motif, actionId }`.
  3. Serveur : droit ; montant entier 1 à `OperationMax` ; plafond journalier ; solde entreprise suffisant ; retire de l'entreprise (`RemoveMoney` renvoie `false` si insuffisant) **puis** ajoute au joueur.
  4. Mouvement `retrait` (montant négatif), journal, bandeau.
- **Données** : `montant` INT ; `vers` `money|bank` ; `motif` 3 à 60 caractères, obligatoire.
- **Règles serveur** : comme ENT-GES-21 ; plus plafond journalier par acteur `Config.Compte.RetraitJourMax = 0` (0 = pas de plafond ; sinon somme des retraits de l'acteur depuis 00:00 lue dans `pop_tablet_ent_mouvements`).
- **Textes et états** : titre « Retirer » (`gestion.compte.retirer`) ; « Vers » (`gestion.compte.vers`) ; « Motif » (`gestion.compte.motif_obligatoire`) ; succès « {montant} retirés. » (`gestion.compte.retrait_ok`) ; erreurs `commun.erreur.fonds_entreprise`, `gestion.compte.montant_borne`, « Plafond de retrait du jour atteint ({max}). » (`gestion.compte.plafond_jour`), `commun.erreur.champ_requis`, `gestion.compte.zone`.
- **Notifications** : les autres employés ayant `compte.voir` et en ligne avec tablette : « {nom} a retiré {montant} du compte. » (`gestion.compte.notif_retrait`) si `Config.Compte.NotifierRetraits = true`.
- **Liens** : Banque ; Tableur.
- **Réglages** : ceux de ENT-GES-21 ; `Config.Compte.RetraitJourMax = 0` ; `Config.Compte.NotifierRetraits = true`.
- **Journal admin** : oui : acteur, montant, destination, motif, solde avant/après.
- **Performance** : 2 appels bridge + 1 insertion (+ 1 somme indexée si plafond actif).
- **Cas limites** : deux patrons retirent en même temps plus que le solde → l'opération de retrait société est atomique côté bridge (ESX `account.removeMoney` après vérification dans le même tick), le second reçoit `fonds_entreprise` ; échec de l'ajout au joueur → l'argent est remis sur le compte ; double clic → un seul retrait.
- **Critères d'acceptation** :
  - Étant donné un compte à 1 000 $, quand le patron retire 1 500 $, alors refus `fonds_entreprise`.
  - Étant donné un retrait de 500 $ vers la banque, alors la banque du patron augmente de 500 $ et un mouvement `−500 $` apparaît.
  - Étant donné un chef (sans `compte.mouvement`) qui appelle le RPC par console, alors refus `droit` et le compte ne bouge pas.

### [ENT-GES-23] Compte bancaire de l'entreprise (comptes société ESX, QBCore, Qbox, adaptateur optionnel)
- **But** : faire passer tout l'argent d'entreprise par un seul point, le compte société du framework détecté (ESX, QBCore ou Qbox), et permettre à un serveur d'écrire son propre adaptateur banque sans toucher au cœur chiffré.
- **Qui** : système ; affichage pour `compte.voir`.
- **Où** : Gestion > Compte > sous-titre « Source ».
- **Parcours** :
  1. Au démarrage, le bridge charge l'adaptateur fourni du framework détecté : `bridge/bank/esx.lua` (compte `society_<job_name>` de `esx_addonaccount` / `esx_society`), `bridge/bank/qb.lua` (QBCore : `qb-banking` v2 `GetAccountBalance` / `AddMoney` / `RemoveMoney`, sinon `qb-management` `GetAccount` / `AddMoney` / `RemoveMoney`), `bridge/bank/qbx.lua` (Qbox : `Renewed-Banking` `getAccountMoney` / `addAccountMoney` / `removeAccountMoney`, sinon `qb-banking`). Il fournit `Bridge.Society.GetMoney(company)`, `AddMoney(company, montant, motif)`, `RemoveMoney(company, montant, motif)`. Aucun système trouvé sur QBCore / Qbox : « Compte d'entreprise indisponible » (`commun.compte_indisponible`), opérations du compte refusées, le reste fonctionne.
  2. Si le fichier ouvert `bridge/bank/custom.lua` existe et renvoie une table `{ name, GetMoney, AddMoney, RemoveMoney }` complète, il remplace les trois fonctions (adaptateur optionnel **non fourni** ; le guide pour l'IA explique comment l'écrire). `pop_bank` n'expose aucun export : il n'est jamais détecté ni appelé.
  3. L'historique affiché vient toujours de `pop_tablet_ent_mouvements`.
- **Données** : aucune table ; état mémoire `Banque.Source = 'esx'|'qb-banking'|'qb-management'|'Renewed-Banking'|'custom'|'aucun'`, `Banque.Nom`.
- **Règles serveur** : toutes les opérations d'argent passent par `Bridge.Society.*` (jamais d'appel direct au framework ni au script de banque dans les apps) ; une fonction d'adaptateur qui renvoie autre chose que `true` (ou un entier pour `GetMoney`) = échec, opération annulée et journalisée.
- **Textes et états** : « Source : Compte société ESX » (`gestion.compte.source_esx`), « Source : qb-banking » / « Source : qb-management » / « Source : Renewed-Banking » (`gestion.compte.source_framework`, nom du script détecté), « Compte d'entreprise indisponible » (`commun.compte_indisponible`), « Source : {nom} » (`gestion.compte.source_custom`), « Banque indisponible. Réessayez dans un instant. » (`gestion.compte.repli`).
- **Notifications** : aucune.
- **Liens** : toutes les fiches qui bougent de l'argent d'entreprise (GES-21, 22, 26, FAC-04, 05, 13, ANN-06) ; paiement de la base (BASE-API-07).
- **Réglages** : aucun (présence du fichier `bridge/bank/custom.lua`).
- **Journal admin** : oui au démarrage si un adaptateur personnalisé est chargé (« banque : adaptateur {nom} ») et à chaque échec d'opération.
- **Performance** : choix fait une fois au démarrage ; aucune vérification par appel.
- **Cas limites** : `custom.lua` incomplet (fonction manquante) → ignoré, message console « [pop_tablet] bridge/bank/custom.lua incomplet, adaptateur du framework utilisé. » ; compte `society_<job_name>` absent → créé à 0 au premier accès ; `RemoveMoney` de l'adaptateur qui renvoie `nil` → échec, rien n'est débité côté tablette.
- **Critères d'acceptation** :
  - Étant donné aucun adaptateur, quand le patron dépose 500 $, alors `society_<job_name>` augmente de 500 $ et le sous-titre affiche « Source : Compte société ESX ».
  - Étant donné `pop_bank` démarré, quand la tablette démarre, alors aucun export `pop_bank` n'est appelé et les comptes du framework sont utilisés.
  - Étant donné un serveur QBCore avec `qb-banking`, quand le patron dépose 500 $, alors le compte `qb-banking` du métier augmente de 500 $ et le sous-titre affiche « Source : qb-banking » ; même essai sur Qbox avec `Renewed-Banking`.
  - Étant donné un client modifié qui envoie un retrait de 1 000 000 $ sans `compte.mouvement`, alors refus `pas_droit` et l'adaptateur n'est pas appelé.

### [ENT-GES-24] Historique des ventes par jour
- **But** : voir le chiffre d'affaires de l'entreprise jour par jour (factures payées).
- **Qui** : droit `ventes.voir` (Chef, Patron) ; admin.
- **Où** : Gestion > Ventes > onglet « Par jour » (onglet par défaut).
- **Parcours** :
  1. RPC `gestion.ventes.jours` `{ periode = 7|30|90 }` (défaut 30).
  2. Serveur : `SELECT DATE(FROM_UNIXTIME(paye_le)) AS jour, COUNT(*), SUM(total), SUM(part_employe_montant) FROM pop_tablet_factures WHERE company = ? AND statut = 'payee' AND paye_le >= ? GROUP BY jour ORDER BY jour DESC`.
  3. Interface : en haut 3 chiffres « Total de la période », « Nombre de ventes », « Panier moyen » ; dessous un histogramme simple en barres de la couleur d'accent (une barre par jour, valeur au survol) ; dessous la liste des jours : « Date », « Ventes », « Total », « Parts employés », « Net entreprise ». Clic sur un jour → liste des factures payées ce jour (ouvre le Suivi des factures filtré sur ce jour, ENT-FAC-09).
- **Données** (affichées) : `jour`, `nombre`, `total`, `parts`, `net = total − parts`.
- **Règles serveur** : droit ; période parmi 7, 30, 90 ; fréquence 1/s ; les factures annulées, refusées ou en attente ne comptent pas ; une facture compte le jour de son paiement ; la majoration (ENT-FAC-16) est incluse dans le total.
- **Textes et états** : titre « Ventes » (`gestion.ventes.titre`) ; onglets « Par jour » (`gestion.ventes.par_jour`), « Par employé » (`gestion.ventes.par_employe`) ; choix « 7 jours », « 30 jours », « 90 jours » (`gestion.ventes.periode.*`) ; chiffres « Total de la période », « Nombre de ventes », « Panier moyen » (`gestion.ventes.total`, `.nombre`, `.moyen`) ; colonnes (`gestion.ventes.col.*`) ; vide : « Aucune vente sur cette période. Faites votre première facture dans l'app Factures. » + bouton « Ouvrir Factures » (`gestion.ventes.vide`).
- **Notifications** : aucune.
- **Liens** : Factures (source des données) ; Tableur (bouton « Exporter vers le tableur » si l'app Tableur est installée : crée une feuille avec ces lignes).
- **Réglages** : `Config.Ventes.Periodes = { 7, 30, 90 }`.
- **Journal admin** : non.
- **Performance** : une requête groupée indexée (`company`, `statut`, `paye_le`) ; résultat gardé en cache serveur 60 s par (entreprise, période), vidé à chaque facture payée de l'entreprise.
- **Cas limites** : jour sans vente → pas de barre (l'histogramme montre la date avec 0) ; entreprise sans facture → état vide ; changement d'heure → on regroupe sur l'heure du serveur MySQL (`DATE(FROM_UNIXTIME())`), documenté.
- **Critères d'acceptation** :
  - Étant donné 3 factures payées aujourd'hui (100, 200, 300 $), alors la ligne du jour affiche 3 ventes et 600 $.
  - Étant donné une facture refusée de 1 000 $, alors elle n'apparaît dans aucun total.
  - Étant donné une recrue qui appelle `gestion.ventes.jours` par console, alors refus `droit`.

### [ENT-GES-25] Historique des ventes par employé
- **But** : voir combien chaque employé a vendu sur une période, et ce qu'il a touché en part employé.
- **Qui** : droit `ventes.voir` ; admin. Tout employé voit en plus **ses propres** chiffres dans Gestion > Service (bloc « Mes ventes cette semaine »).
- **Où** : Gestion > Ventes > onglet « Par employé ».
- **Parcours** :
  1. RPC `gestion.ventes.employes` `{ periode = 'semaine'|'mois'|'30j', page }` (défaut semaine en cours).
  2. Serveur : `SELECT auteur, auteur_nom, COUNT(*), SUM(total), SUM(part_employe_montant) FROM pop_tablet_factures WHERE company = ? AND statut = 'payee' AND paye_le >= ? GROUP BY auteur ORDER BY SUM(total) DESC LIMIT 20 OFFSET ?`.
  3. Liste : rang, nom, ventes, total, part touchée. Clic → Suivi des factures filtré sur cet employé.
- **Données** (affichées) : `auteur_nom`, `nombre`, `total`, `parts`. Les anciens employés apparaissent avec la mention « (ancien) ».
- **Règles serveur** : droit (sauf bloc « Mes ventes » limité à soi) ; périodes autorisées ; pagination 20 ; fréquence 1/s.
- **Textes et états** : colonnes « Employé », « Ventes », « Total », « Part touchée » (`gestion.ventes.emp.*`) ; « (ancien) » (`gestion.ventes.ancien`) ; périodes « Cette semaine », « Ce mois », « 30 jours » (`gestion.ventes.periode_emp.*`) ; bloc perso « Mes ventes cette semaine : {n} ventes, {total}, part touchée {part}. » (`gestion.service.mes_ventes`) ; vide : `gestion.ventes.vide`.
- **Notifications** : aucune.
- **Liens** : Factures ; Tableur (export).
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : requête groupée indexée, cache 60 s comme ENT-GES-24.
- **Cas limites** : facture créée par l'API sans auteur → regroupée sous « Système » (`gestion.ventes.systeme`) ; employé renommé → nom enregistré sur la facture au moment de la création ; 50 vendeurs → pagination.
- **Critères d'acceptation** :
  - Étant donné A (2 ventes, 500 $) et B (1 vente, 800 $), alors B apparaît en premier.
  - Étant donné une recrue, quand elle ouvre Service, alors elle voit seulement ses propres chiffres.
  - Étant donné une recrue qui appelle `gestion.ventes.employes` par console, alors refus `droit`.

### [ENT-GES-26] Verser une prime à un employé
- **But** : donner une prime à un employé, prise sur le compte de l'entreprise.
- **Qui** : droit `compte.prime` (Patron) ; admin.
- **Où** : Gestion > Employés > fiche employé > « Verser une prime » ; ou Gestion > Compte > « Verser une prime » (choix de l'employé dans une liste).
- **Parcours** :
  1. Fenêtre : employé (prérempli depuis la fiche), « Montant », « Motif » obligatoire, solde de l'entreprise affiché.
  2. Confirmation « Verser {montant} à {nom} ? ».
  3. RPC `gestion.compte.prime` `{ identifier, montant, motif, actionId }`.
  4. Serveur : droit ; cible membre de l'entreprise ; montant entier 1 à `Config.Primes.Max` ; solde suffisant ; `Bridge.Society.RemoveMoney` **puis** banque du bénéficiaire (`Bridge.AddMoney(src, 'bank')` s'il est en ligne, sinon `Bridge.AddMoneyOffline`). Échec du versement → argent remis sur le compte.
  5. Mouvement `prime` (négatif, `cible_nom`), journal, notification, bandeau.
- **Données** : `identifier` (cible) ; `montant` INT 1 à 10 000 ; `motif` 3 à 60 caractères.
- **Règles serveur** : droit ; cible dans l'entreprise (en base) ; borne ; fonds ; `actionId` ; fréquence 1 prime toutes les 10 s par acteur (`Config.Primes.Frequence = 10`) ; se verser une prime à soi-même : autorisé seulement si `Config.Primes.SoiMeme = true` (défaut `false` : interdit, utiliser Retirer).
- **Textes et états** : titre « Verser une prime » (`gestion.prime.titre`) ; champs « Employé », « Montant », « Motif » (`gestion.prime.employe`, `.montant`, `.motif`) ; confirmation (`gestion.prime.confirm`) ; succès « Prime de {montant} versée à {nom}. » (`gestion.prime.ok`) ; erreurs `commun.erreur.fonds_entreprise`, « Montant entre 1 et {max} $. » (`gestion.prime.borne`), « Utilisez Retirer pour vous verser de l'argent. » (`gestion.prime.soi_meme`), `gestion.fiche.plus_membre`.
- **Notifications** : bénéficiaire (en ligne, tablette) : « Prime de {montant} reçue de {entreprise} : {motif}. » (`gestion.prime.notif`).
- **Liens** : Compte (mouvement) ; Tableur.
- **Réglages** : `Config.Primes.Max = 10000` ; `Config.Primes.Frequence = 10` ; `Config.Primes.SoiMeme = false`.
- **Journal admin** : oui : acteur, bénéficiaire, montant, motif, solde avant/après.
- **Performance** : 2 appels bridge + 1 insertion.
- **Cas limites** : bénéficiaire hors ligne → versé en banque hors ligne, pas de notification ; double clic → une prime ; bénéficiaire viré entre l'ouverture et la validation → `plus_membre`.
- **Critères d'acceptation** :
  - Étant donné un compte à 5 000 $, quand le patron verse 1 000 $ à un employé, alors le compte passe à 4 000 $ et la banque de l'employé augmente de 1 000 $.
  - Étant donné un compte à 500 $, quand il tente 1 000 $, alors refus `fonds_entreprise` et rien ne bouge.
  - Étant donné un envoi console vers un joueur d'une autre entreprise, alors refus `plus_membre`.

---

## 2. Factures (app « Factures »)

L'app « Factures » (`factures.titre` : « Factures ») est visible par **tout porteur de tablette** :
- onglet « Reçues » (ENT-FAC-03) pour tout le monde, y compris sans emploi ;
- onglets « Nouvelle facture », « Suivi », « Réglages » seulement pour les employés, selon leurs droits.

Statuts d'une facture : `attente` (« En attente »), `payee` (« Payée »), `refusee` (« Refusée »), `annulee` (« Annulée »). Indicateurs en plus : `en_retard` (calculé : `attente` et échéance dépassée, libellé « En retard ») et `transmise_police` (libellé « Transmise à la police »).

### [ENT-FAC-01] Créer une facture
- **But** : établir une facture à lignes (article, quantité, prix) pour un client.
- **Qui** : droit `facture.creer` (tous niveaux par défaut, Recrue plafonnée à 500 $ par facture via le plafond du grade, ENT-GES-18) ; en service obligatoire si `Config.Factures.ServiceRequis = true`.
- **Où** : Factures > onglet « Nouvelle facture » ; aussi bouton « Facturer » depuis une demande (ENT-DEM-07) qui préremplit le client.
- **Parcours** :
  1. Écran en deux blocs : « Client » (ENT-FAC-02) et « Articles ».
  2. Bloc Articles : une ligne vide au départ avec « Article », « Quantité » (défaut 1), « Prix unitaire » ; bouton « Ajouter une ligne » ; icône corbeille par ligne ; total de chaque ligne et total général recalculés en direct par l'interface (pour affichage seulement).
  3. Champ « Note pour le client » facultatif.
  4. Si l'entreprise a un catalogue d'articles (app Stock, option) : le champ Article propose une liste déroulante qui remplit le prix ; le prix reste modifiable sauf si `Config.Factures.PrixCatalogueFixe = true`.
  5. Bouton « Envoyer la facture » actif quand client choisi + au moins une ligne complète.
  6. RPC `factures.creer` `{ client = { type = 'proche', source } | { type = 'nom', identifier }, lignes = [{ article, quantite, prix }], note, actionId }`.
  7. Serveur : vérifie droit, service, fréquence, client (ENT-FAC-02), nettoie et vérifie chaque ligne, **recalcule** le total (`somme(quantite × prix)`), vérifie plafond du grade et plafond global, nombre de factures en attente du client pour cette entreprise.
  8. Serveur : insère la facture avec `uid = actionId` (colonne unique : un 2e envoi du même `actionId` renvoie la facture existante), `numero = 'F-' .. id sur 6 chiffres`, `part_pct` = part employé actuelle de l'entreprise (ENT-FAC-12), `echeance = cree_le + delai_impaye × 3600` (réglage de l'entreprise, ENT-FAC-15), ligne `pop_tablet_factures_evenements` (`creee`).
  9. Serveur : livraison au client : en ligne et conscient → notification tablette ou fenêtre simple (ENT-FAC-05), `livree = 1` ; inconscient → ENT-FAC-07 ; hors ligne → `livree = 0`, livraison à sa prochaine connexion (événement `esx:playerLoaded`).
  10. Créateur : bandeau « Facture {numero} envoyée à {client}. », formulaire vidé, lien « Voir dans le suivi ».
- **Données** (`pop_tablet_factures`) :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `id` | INT AUTO_INCREMENT | Oui | — | — |
| `uid` | CHAR(36) UNIQUE | Oui | `actionId` de création | — |
| `numero` | VARCHAR(12) UNIQUE | Oui | `F-000123` | — |
| `company_id` | INT | Oui | `pop_tablet_companies.id` | — |
| `auteur` | VARCHAR(60) | Non | identifiant ; NULL si API sans auteur | — |
| `auteur_nom` | VARCHAR(100) | Oui | nom RP ou « Système » | — |
| `client` | VARCHAR(60) | Oui | identifiant | — |
| `client_nom` | VARCHAR(100) | Oui | nom RP à la création | — |
| `lignes` | JSON | Oui | 1 à 20 lignes `{ article, quantite, prix }` | — |
| `sous_total` | INT | Oui | recalculé serveur | — |
| `majoration` | INT | Oui | ≥ 0 | 0 |
| `total` | INT | Oui | `sous_total + majoration` | — |
| `note` | VARCHAR(200) | Non | nettoyée | NULL |
| `statut` | ENUM(`attente`,`payee`,`refusee`,`annulee`) | Oui | — | `attente` |
| `transmise_police` | TINYINT(1) | Oui | — | 0 |
| `moyen` | ENUM(`bank`,`money`) | Non | rempli au paiement | NULL |
| `payeur` | VARCHAR(60) | Non | identifiant de celui qui a payé | NULL |
| `part_pct` | TINYINT | Oui | 0 à 50, figé à la création | réglage entreprise |
| `part_employe_montant` | INT | Oui | rempli au paiement | 0 |
| `source` | ENUM(`tablette`,`api`) | Oui | — | `tablette` |
| `source_script` | VARCHAR(50) | Non | nom de la ressource si API | NULL |
| `metadata` | JSON | Non | données libres API, 2 Ko max | NULL |
| `refus_autorise` | TINYINT(1) | Oui | — | 1 |
| `echeance` | INT UNSIGNED | Oui | — | voir parcours |
| `livree` | TINYINT(1) | Oui | client prévenu ou non | 0 |
| `relances` | TINYINT | Oui | 0 à 5 | 0 |
| `derniere_relance` | INT UNSIGNED | Non | — | NULL |
| `refus_motif` | VARCHAR(100) | Non | — | NULL |
| `cree_le`, `paye_le`, `refuse_le`, `annule_le` | INT UNSIGNED | — | — | NULL sauf `cree_le` |
| `annule_par` | VARCHAR(60) | Non | — | NULL |

  Index : (`company`, `statut`, `cree_le`), (`client`, `statut`), (`company`, `statut`, `paye_le`), (`auteur`). Jamais supprimée (une facture se termine par un statut, pas une suppression).

  `pop_tablet_factures_evenements` : `id`, `facture_id`, `type` ENUM(`creee`,`livree`,`relancee`,`payee`,`refusee`,`annulee`,`majoree`,`transmise_police`), `par` VARCHAR(60) NULL, `details` VARCHAR(200) NULL, `cree_le`. Index (`facture_id`).

  Ligne : `article` texte 1 à 40 caractères nettoyé ; `quantite` entier 1 à 100 ; `prix` entier 1 à `Config.Factures.PrixLigneMax`.
- **Règles serveur** :
  - Droit `facture.creer` ; service si `ServiceRequis` ; métier ≠ sans emploi.
  - Client ≠ soi-même ; client existant ; règles de ENT-FAC-02.
  - 1 à 20 lignes (`Config.Factures.LignesMax = 20`), chaque valeur entière et bornée ; total recalculé, valeur envoyée par le client ignorée.
  - Total ≤ plafond du grade s'il est > 0 ; total ≤ `Config.Factures.TotalMax = 250000`.
  - Factures en attente du même client pour la même entreprise ≤ `Config.Factures.AttenteMaxParClient = 5`.
  - Fréquence : 1 facture toutes les 5 s par créateur (`Config.Factures.Frequence = 5`).
  - Anti doublon : `uid` unique.
- **Textes et états** :
  - Onglet « Nouvelle facture » (`factures.nouvelle.titre`) ; champs « Article » (`factures.nouvelle.article`), « Quantité » (`.quantite`), « Prix unitaire » (`.prix`), « Ajouter une ligne » (`.ajouter_ligne`), « Note pour le client (facultatif) » (`.note`), « Total » (`.total`), bouton « Envoyer la facture » (`.envoyer`).
  - Succès : « Facture {numero} envoyée à {client}. » (`factures.nouvelle.ok`) ; si client hors ligne : « Facture {numero} créée : {client} la recevra à sa prochaine connexion. » (`factures.nouvelle.ok_hors_ligne`) ; si inconscient : « Facture {numero} créée : {client} la verra à son réveil. » (`factures.nouvelle.ok_inconscient`).
  - Erreurs : « Ajoutez au moins un article. » (`factures.nouvelle.aucune_ligne`) ; « 20 lignes maximum. » (`factures.nouvelle.trop_lignes`) ; « Quantité entre 1 et 100. » (`factures.nouvelle.quantite_borne`) ; « Prix entre 1 et {max} $. » (`factures.nouvelle.prix_borne`) ; « Votre grade limite les factures à {max}. » (`factures.nouvelle.plafond_grade`) ; « Montant maximum d'une facture : {max}. » (`factures.nouvelle.plafond_global`) ; « Ce client a déjà {n} factures en attente chez vous. » (`factures.nouvelle.trop_attente`) ; « Vous ne pouvez pas vous facturer vous-même. » (`factures.nouvelle.soi_meme`) ; « Choisissez un client. » (`factures.nouvelle.sans_client`).
  - Hors service (si `ServiceRequis`) : onglet affiche `commun.hors_service.titre` + bouton.
  - Pas le droit : onglet caché.
- **Notifications** : client : « Nouvelle facture de {entreprise} : {total}. » (`factures.notif.nouvelle`), clic → ouvre la facture dans « Reçues ».
- **Liens** : Demandes (préremplissage), Stock (catalogue, option), Ventes, Compte. Export équivalent pour les autres scripts : ENT-FAC-19.
- **Réglages** : `Config.Factures.ServiceRequis = true` ; `Config.Factures.LignesMax = 20` ; `Config.Factures.PrixLigneMax = 100000` ; `Config.Factures.TotalMax = 250000` ; `Config.Factures.AttenteMaxParClient = 5` ; `Config.Factures.Frequence = 5` ; `Config.Factures.PrixCatalogueFixe = false`.
- **Journal admin** : oui si total ≥ `Config.Log.SeuilFacture = 10000` : auteur, client, total, numéro ; sinon non (la table sert d'historique).
- **Performance** : 2 insertions ; aucune donnée chargée tant que l'onglet n'est pas ouvert ; catalogue chargé à l'ouverture de l'onglet seulement si l'app Stock est installée.
- **Cas limites** :
  - Double clic sur « Envoyer » : même `uid` → une seule facture, la 2e réponse renvoie la même facture.
  - Client qui se déconnecte entre le choix et l'envoi : facture créée, livrée à la reconnexion (`ok_hors_ligne`).
  - Ligne avec prix 0 ou quantité 0 : refus `prix_borne` / `quantite_borne`.
  - Créateur viré pendant la saisie : refus `commun.erreur.pas_droit`.
  - Lignes JSON trafiquées (21 lignes, texte de 500 caractères) : refus, rien n'est créé.
- **Critères d'acceptation** :
  - Étant donné 2 lignes (2 × 50 $, 1 × 300 $), quand l'employé envoie, alors la facture enregistrée a `sous_total = 400` et le client reçoit « Nouvelle facture de {entreprise} : 400 $ ».
  - Étant donné une recrue plafonnée à 500 $, quand elle envoie 600 $, alors refus `plafond_grade`.
  - Étant donné un client qui envoie par console un `total = 1` avec des lignes valant 5 000 $, alors le serveur enregistre 5 000 $ (le total client est ignoré).
  - Étant donné un employé hors service avec `ServiceRequis = true`, alors l'onglet affiche l'état Hors service et le RPC répond `service`.

### [ENT-FAC-02] Choisir le client d'une facture
- **But** : désigner le client soit parmi les personnes proches, soit par son nom.
- **Qui** : comme ENT-FAC-01.
- **Où** : Factures > Nouvelle facture > bloc « Client » : deux onglets « À côté de moi » (défaut) et « Par nom ».
- **Parcours** :
  1. « À côté de moi » : RPC `factures.clients.proches` → serveur renvoie les joueurs à 3 m ou moins (règle 0.6), sauf soi : nom RP + `source`. Bouton « Actualiser ».
  2. « Par nom » (si `Config.Factures.RechercheParNom = true`) : champ de recherche, 3 caractères minimum, envoi 400 ms après la dernière frappe ; RPC `factures.clients.recherche` `{ texte }` → serveur : `SELECT identifier, firstname, lastname, dateofbirth FROM users WHERE CONCAT(firstname, ' ', lastname) LIKE ? LIMIT 10` (texte échappé pour `LIKE`). Résultat : nom + date de naissance (pour distinguer les homonymes) + pastille « En ville » si connecté.
  3. Le choix remplit le bloc Client : « Client : {nom} » + lien « Changer ».
  4. À l'envoi (ENT-FAC-01), le serveur **revérifie** : `proche` → la cible est toujours connectée et à 3 m (sinon refus `commun.erreur.trop_loin`) ; `nom` → l'identifiant existe dans `users`.
- **Données** : `client.type` `proche|nom` ; `client.source` (INT, proche) ; `client.identifier` (VARCHAR(60), par nom) ; `texte` recherche 3 à 30 caractères.
- **Règles serveur** : recherche : fréquence 2 par seconde par joueur, résultats limités à 10, aucune donnée autre que nom, date de naissance et « en ville » ; jamais l'identifiant ESX affiché (il est renvoyé à l'interface pour la sélection mais pas montré) ; client ≠ soi.
- **Textes et états** : onglets « À côté de moi » (`factures.client.proche`), « Par nom » (`factures.client.par_nom`) ; champ « Nom du client » (`factures.client.recherche`) ; vide proche : « Personne à moins de 3 m. Approchez-vous ou cherchez par nom. » (`factures.client.vide_proche`) ; vide recherche : « Aucune personne à ce nom. » (`factures.client.vide_nom`) ; moins de 3 caractères : « Tapez au moins 3 lettres. » (`factures.client.min`) ; « En ville » (`factures.client.en_ville`) ; « Changer » (`factures.client.changer`).
- **Notifications** : aucune.
- **Liens** : ENT-FAC-01.
- **Réglages** : `Config.Factures.RechercheParNom = true` (si `false`, onglet caché et type `nom` refusé par le serveur).
- **Journal admin** : non.
- **Performance** : proximité calculée seulement au clic ; recherche limitée à 10 lignes, index conseillé sur (`firstname`, `lastname`) créé au démarrage si absent (`CREATE INDEX IF NOT EXISTS` pour MariaDB, ignoré sinon).
- **Cas limites** : homonymes → départagés par la date de naissance ; client choisi « à côté » qui s'éloigne avant l'envoi → refus `loin`, l'interface propose « Envoyer par nom » qui bascule sur le même client par identifiant ; texte avec `%` ou `_` → échappés, pas de recherche joker.
- **Critères d'acceptation** :
  - Étant donné un joueur à 2 m, alors il apparaît dans « À côté de moi ».
  - Étant donné la recherche « dup », alors au plus 10 résultats « Dupont » avec date de naissance.
  - Étant donné `RechercheParNom = false`, quand un client console envoie `type = 'nom'`, alors refus `droit`.

### [ENT-FAC-03] Onglet Reçues : mes factures (ajout)
- **But** : permettre à tout joueur de retrouver et payer les factures qu'il a reçues.
- **Qui** : tout porteur de tablette (client de la facture uniquement).
- **Où** : Factures > onglet « Reçues » (onglet par défaut si le joueur a au moins une facture en attente, sinon « Nouvelle facture » pour un employé) ; pastille avec le nombre de factures en attente sur l'icône de l'app.
- **Parcours** :
  1. RPC `factures.recues.liste` `{ filtre = 'attente'|'toutes', page }` (défaut `attente`).
  2. Serveur : traite d'abord les retards du joueur (ENT-FAC-16/17, traitement « à la lecture ») puis lit `WHERE client = ?`, tri : en attente d'abord (échéance la plus proche en premier), puis les autres par date décroissante ; 20 par page.
  3. Ligne : entreprise, numéro, date, total, statut (+ « En retard » / « Transmise à la police »).
  4. Clic → détail : lignes, note, émetteur (nom de l'employé), échéance, majoration éventuelle ; boutons « Payer » et « Refuser » si en attente (ENT-FAC-04, ENT-FAC-06).
- **Données** (affichées) : `numero`, `company` (libellé ESX), `auteur_nom`, `lignes`, `note`, `total`, `majoration`, `statut`, `echeance`, `transmise_police`.
- **Règles serveur** : on ne renvoie que les factures où `client = identifiant de l'appelant` ; fréquence 1/s.
- **Textes et états** : onglet « Reçues » (`factures.recues.titre`) ; filtres « À payer » / « Toutes » (`factures.recues.filtre.*`) ; vide : « Vous n'avez aucune facture à payer. » (`factures.recues.vide`) ; libellés de statut (`factures.statut.attente` « En attente », `.payee` « Payée », `.refusee` « Refusée », `.annulee` « Annulée », `.en_retard` « En retard », `.transmise` « Transmise à la police ») ; « À payer avant le {date} » (`factures.recues.echeance`) ; « Majoration de retard : {montant} » (`factures.recues.majoration`).
- **Notifications** : aucune (l'onglet lit).
- **Liens** : ENT-FAC-04, 06.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : requête indexée (`client`, `statut`), paginée ; le nombre de la pastille est envoyé au client à l'ouverture de la tablette (1 `COUNT` indexé) et mis à jour par les notifications.
- **Cas limites** : facture annulée par l'entreprise pendant que le client la regarde → « Payer » renvoie « Cette facture a été annulée. » ; client sans emploi → seul cet onglet est visible ; 0 facture → état vide.
- **Critères d'acceptation** :
  - Étant donné 2 factures en attente et 3 payées, alors le filtre « À payer » montre 2 lignes.
  - Étant donné un joueur sans emploi, alors l'app Factures s'ouvre sur « Reçues » et les autres onglets sont absents.
  - Étant donné un joueur qui demande par console le détail d'une facture d'un autre client, alors refus et aucune donnée.

### [ENT-FAC-04] Payer une facture sur sa tablette
- **But** : régler une facture reçue, par banque ou en liquide, une seule fois.
- **Qui** : le client de la facture (ou, si `Config.Factures.PayerPourAutrui = false`, personne d'autre ; valeur par défaut).
- **Où** : Factures > Reçues > détail > « Payer » ; ou bouton « Payer » de la notification.
- **Parcours** :
  1. Fenêtre « Payer {total} à {entreprise} ? » avec choix « Banque » (défaut) / « Liquide » ; affichage de l'argent disponible dans chaque source ; « Liquide » grisé avec explication si la règle de proximité n'est pas remplie.
  2. RPC `factures.payer` `{ numero, moyen, actionId }`.
  3. Serveur : verrou mémoire `Factures.Verrou[id]` (si déjà pris → `commun.erreur.trop_vite`) ; lit la facture ; vérifie `client = appelant`, `statut = 'attente'`, joueur conscient (`Bridge.IsDead`), moyen autorisé, proximité si liquide, fonds suffisants.
  4. Serveur : `Bridge.RemoveMoney(client, moyen, total)` ; puis `UPDATE pop_tablet_factures SET statut='payee', moyen=?, payeur=?, paye_le=?, part_employe_montant=? WHERE id=? AND statut='attente'` ; si 0 ligne modifiée → rembourse le client et répond « déjà réglée ».
  5. Serveur : verse à l'entreprise `total − part` (`Bridge.Society.AddMoney`, mouvement `facture`) et la part à l'auteur (ENT-FAC-13).
  6. Serveur : événement `payee`, notification à l'auteur, signal API (ENT-FAC-18), si `transmise_police` → prévient la police (ENT-FAC-17), cache ventes vidé, verrou libéré.
  7. Client : bandeau succès, la facture passe « Payée ».
- **Données** : `moyen` `bank|money` ; mise à jour de `pop_tablet_factures` ; `pop_tablet_ent_mouvements` (type `facture`).
- **Règles serveur** :
  - Une facture ne se paie qu'une fois : verrou mémoire + `UPDATE ... WHERE statut='attente'` + `actionId`.
  - Le montant payé est **toujours** le `total` lu en base (jamais un montant envoyé par le client).
  - Moyens autorisés : `Config.Factures.Moyens = { 'bank', 'money' }`.
  - Liquide : si `Config.Factures.LiquideProximite = true`, un employé en service de l'entreprise doit être à 3 m ou moins du client (preuve RP de la remise d'argent).
  - Joueur inconscient : refus.
  - Fréquence 1 paiement toutes les 2 s par joueur.
  - Si l'ajout au compte entreprise échoue après le retrait au client : le client est remboursé, la facture repasse `attente` (requête inverse), journal « paiement annulé ».
- **Textes et états** :
  - Titre « Payer {total} à {entreprise} ? » (`factures.payer.titre`) ; choix « Banque » (`commun.banque`), « Liquide » (`commun.liquide`) ; « Disponible : {montant} » (`factures.payer.disponible`) ; bouton « Payer » (`factures.payer.bouton`).
  - Succès : « Facture {numero} payée. » (`factures.payer.ok`).
  - Erreurs : « Vous n'avez pas assez d'argent ({moyen}). » (`factures.payer.fonds`) ; « Cette facture est déjà réglée. » (`factures.payer.deja`) ; « Cette facture a été annulée. » (`factures.payer.annulee`) ; « Pour payer en liquide, un employé de {entreprise} doit être à côté de vous. » (`factures.payer.liquide_loin`) ; « Vous ne pouvez pas payer dans cet état. » (`factures.payer.inconscient`).
- **Notifications** : auteur (en ligne, tablette) : « {client} a payé la facture {numero} : {total}. » (`factures.notif.payee`) ; si part > 0, voir ENT-FAC-13.
- **Liens** : Compte (entrée), part employé, Ventes, Stock (option : retrait des articles du catalogue vendus si `Config.Factures.DeduireStock = true`, défaut `false`), Tableur (import), signal API, Police si transmise.
- **Réglages** : `Config.Factures.Moyens = { 'bank', 'money' }` ; `Config.Factures.LiquideProximite = true` ; `Config.Factures.PayerPourAutrui = false` ; `Config.Factures.DeduireStock = false`.
- **Journal admin** : oui si total ≥ `Config.Log.SeuilFacture` : client, entreprise, total, moyen.
- **Performance** : 1 lecture, 1 mise à jour, 2 ou 3 appels bridge, 2 insertions.
- **Cas limites** :
  - Double clic / deux onglets / tablette + fenêtre simple en même temps : un seul paiement (verrou + condition SQL), l'autre reçoit `deja`.
  - Auteur déconnecté : la part est versée en banque hors ligne.
  - Entreprise supprimée de la config ESX entre-temps : le compte société est quand même crédité (le bridge crée le compte s'il manque) et le journal le signale.
  - Facture majorée pendant que la fenêtre est ouverte : le serveur prend le total en base ; si différent de celui affiché, refus « Le montant a changé : {total}. Confirmez à nouveau. » (`factures.payer.montant_change`) — l'interface envoie le total vu pour cette seule comparaison.
- **Critères d'acceptation** :
  - Étant donné une facture de 400 $ et un client avec 1 000 $ en banque, quand il paie par banque, alors il lui reste 600 $, la facture est `payee` et le compte entreprise reçoit 400 $ moins la part employé.
  - Étant donné deux appels simultanés `factures.payer` avec deux `actionId` différents, alors un seul débit a lieu et le second reçoit `deja`.
  - Étant donné un joueur qui tente de payer la facture d'un autre client par console, alors refus et rien ne bouge.
  - Étant donné un paiement en liquide sans employé à 3 m, alors refus `liquide_loin`.

### [ENT-FAC-05] Payer une facture en fenêtre simple (sans tablette)
- **But** : permettre à un joueur sans tablette d'accepter et payer, ou refuser, une facture.
- **Qui** : client de la facture, en ligne, sans tablette sur lui.
- **Où** : fenêtre simple (règle 0.7) ouverte à la livraison de la facture et à chaque relance.
- **Parcours** :
  1. Fenêtre « Facture de {entreprise} » : liste compacte des lignes (5 premières + « et {n} autres »), total, note, boutons « Payer par banque », « Payer en liquide » (si autorisé), « Refuser » (si `refus_autorise`), et « Plus tard » (Échap).
  2. Le clic envoie les mêmes RPC que la tablette (`factures.payer` ou `factures.refuser`) : mêmes règles serveur que ENT-FAC-04 / ENT-FAC-06.
  3. Résultat affiché dans un encart de notification de jeu (pas de tablette) : succès ou erreur avec les mêmes textes.
  4. « Plus tard » : la facture reste `attente` ; elle reviendra à la prochaine relance (ENT-FAC-14) ou à la prochaine connexion du joueur s'il n'a toujours pas de tablette (une fois par connexion, toutes ses factures en attente l'une après l'autre, max 5).
- **Données** : aucune nouvelle.
- **Règles serveur** : identiques à ENT-FAC-04 / 06 ; le serveur ne fait pas confiance au fait que le joueur « n'a pas de tablette » : il applique les mêmes contrôles quel que soit l'affichage.
- **Textes et états** : titre « Facture de {entreprise} » (`factures.fenetre.titre`) ; « Total : {total} » (`factures.fenetre.total`) ; « et {n} autres articles » (`factures.fenetre.autres`) ; boutons « Payer par banque » (`factures.fenetre.banque`), « Payer en liquide » (`factures.fenetre.liquide`), « Refuser » (`factures.fenetre.refuser`), « Plus tard » (`factures.fenetre.plus_tard`) ; erreurs : celles de ENT-FAC-04.
- **Notifications** : comme ENT-FAC-04 / 06.
- **Liens** : ENT-FAC-04, 06, 14.
- **Réglages** : `Config.Factures.FenetreALaConnexion = true`.
- **Journal admin** : comme ENT-FAC-04.
- **Performance** : la fenêtre est un composant de la NUI déjà chargée, sans thread Lua ; à la connexion, 1 requête indexée `client, statut`.
- **Cas limites** : joueur qui ramasse une tablette pendant que la fenêtre est ouverte → la fenêtre reste, et la facture est aussi visible dans la tablette (paiement unique garanti) ; joueur en voiture qui conduit → la fenêtre prend le focus souris mais le joueur peut faire Échap ; 7 factures en attente → 5 fenêtres l'une après l'autre, les 2 autres à la relance.
- **Critères d'acceptation** :
  - Étant donné un client sans tablette, quand une facture lui est envoyée, alors la fenêtre simple s'affiche avec le total.
  - Étant donné « Plus tard », alors la facture reste `attente` et se réaffiche à la relance.
  - Étant donné un clic « Payer par banque » répété 3 fois rapidement, alors un seul débit.

### [ENT-FAC-06] Refuser une facture
- **But** : permettre au client de refuser une facture qu'il conteste.
- **Qui** : client de la facture, si `refus_autorise = 1` (copie de `Config.Factures.RefusAutorise` à la création ; les factures API peuvent l'interdire).
- **Où** : Factures > Reçues > détail > « Refuser » ; fenêtre simple « Refuser ».
- **Parcours** : 1. Fenêtre « Refuser la facture {numero} ? » + champ « Raison » facultatif. 2. RPC `factures.refuser` `{ numero, motif, actionId }`. 3. Serveur : vérifie client = appelant, `statut = 'attente'`, `refus_autorise` ; `UPDATE ... SET statut='refusee', refuse_le=?, refus_motif=? WHERE id=? AND statut='attente'` ; événement `refusee`. 4. Notification à l'auteur.
- **Données** : `refus_motif` 100 caractères max, nettoyé, facultatif.
- **Règles serveur** : client = appelant ; statut ; autorisation ; fréquence 1/s ; un refus est définitif (pas de retour en attente) ; l'entreprise peut refaire une nouvelle facture.
- **Textes et états** : bouton « Refuser » (`factures.refuser.bouton`) ; titre (`factures.refuser.titre`) ; champ « Raison (facultatif) » (`factures.refuser.raison`) ; succès « Facture refusée. » (`factures.refuser.ok`) ; erreurs « Cette facture ne peut pas être refusée. » (`factures.refuser.interdit`), `factures.payer.deja`, `factures.payer.annulee`.
- **Notifications** : auteur : « {client} a refusé la facture {numero}. » + « Raison : {motif} » si présente (`factures.notif.refusee`).
- **Liens** : Suivi (filtre Refusées). Une facture refusée n'est **pas** transmise automatiquement à la police ; le responsable peut la transmettre à la main si l'option police est active (ENT-FAC-17).
- **Réglages** : `Config.Factures.RefusAutorise = true`.
- **Journal admin** : non.
- **Performance** : 1 mise à jour + 1 insertion.
- **Cas limites** : refus et paiement simultanés → le premier `UPDATE` gagne, l'autre reçoit `deja` ; facture API avec refus interdit → bouton caché, RPC refusé ; client inconscient → refus impossible tant qu'il n'est pas réveillé (même règle que le paiement).
- **Critères d'acceptation** :
  - Étant donné une facture en attente, quand le client refuse avec « Prix abusif », alors le statut est `refusee` et l'auteur reçoit la raison.
  - Étant donné `refus_autorise = 0`, alors le bouton « Refuser » n'apparaît pas.
  - Étant donné un tiers qui envoie `factures.refuser` par console sur la facture d'un autre, alors refus.

### [ENT-FAC-07] Facture adressée à un joueur inconscient
- **But** : ne jamais faire payer un joueur inconscient : la facture attend son réveil.
- **Qui** : système.
- **Où** : aucun écran ; message au créateur (`ok_inconscient`).
- **Parcours** :
  1. À la livraison (création ou relance), le serveur teste `Bridge.IsDead(clientSource)` (BASE-MOT-02) : ESX état `isDead` d'esx_ambulancejob ; QBCore `PlayerData.metadata.isdead` ou `inlaststand` ; Qbox `metadata.isdead` ou `inlaststand` (qbx_medical) ; repli `GetEntityHealth(GetPlayerPed(src)) <= 0` côté serveur.
  2. Inconscient → `livree = 0`, identifiant ajouté à `Factures.AttenteReveil[identifier] = { id1, id2 }` (mémoire).
  3. Au réveil : détecté par `Bridge.OnPlayerRevived` (BASE-MOT-02), sans boucle : ESX `esx:onPlayerSpawn` (et `esx_ambulancejob:revive`) côté client → `pop_tablet:bridge:revived` ; QBCore `hospital:server:SetDeathStatus(false)` / `SetLaststandStatus(false)` côté serveur, ou passage de `metadata.isdead` et `inlaststand` à `false` dans `QBCore:Player:SetPlayerData` côté client ; Qbox retour du state bag `isDead` à `false` ou de `metadata.isdead` / `inlaststand` à `false`. Le serveur revérifie `Bridge.IsDead(src) == false`, puis livre les factures en file (notification ou fenêtre simple), `livree = 1`.
  4. Toute tentative de paiement ou de refus pendant l'inconscience est refusée (`factures.payer.inconscient`).
  5. Déconnexion pendant l'inconscience → la file mémoire est vidée ; les factures `livree = 0` seront livrées à la reconnexion (comme un joueur hors ligne).
- **Données** : `pop_tablet_factures.livree` ; mémoire `Factures.AttenteReveil`.
- **Règles serveur** : l'événement `pop_tablet:bridge:revived` ne fait que déclencher une vérification (si le joueur est encore mort, rien ne se passe) ; fréquence 1 toutes les 5 s.
- **Textes et états** : créateur : `factures.nouvelle.ok_inconscient` ; client au réveil : notification normale `factures.notif.nouvelle` (une par facture, max 5, puis « Et {n} autres factures en attente. » `factures.notif.autres`).
- **Notifications** : voir ci-dessus.
- **Liens** : Bridge `Bridge.IsDead` / `Bridge.OnPlayerRevived` (BASE-MOT-02 : ESX `esx_ambulancejob` ou tout script qui déclenche `esx:onPlayerSpawn` ; QBCore `hospital:server:SetDeathStatus` / `metadata.isdead` / `inlaststand` ; Qbox `qbx_medical`, state bag `isDead`, `metadata.isdead` / `inlaststand`) ; s'applique aussi aux amendes police (ENT-FAC-19) et aux factures de soins (MET-EMS-09).
- **Réglages** : `Config.Bridge.DeathEvent = 'auto'` ; `Config.Bridge.ReviveEvent = 'auto'` (BASE-MOT-02 ; `'auto'` = événements du framework détecté, ou nom d'un événement client d'un autre script de mort).
- **Journal admin** : non.
- **Performance** : aucun thread ; uniquement des événements.
- **Cas limites** : faux événement `pop_tablet:bridge:revived` envoyé par un joueur mort → vérification santé, rien n'est livré ; joueur réanimé par un script qui ne déclenche aucun événement connu du bridge → livraison à la prochaine ouverture de la tablette (la tablette envoie aussi `pop_tablet:bridge:revived` à l'ouverture) ou à la prochaine connexion ; 3 factures en file → 3 notifications au réveil.
- **Critères d'acceptation** :
  - Étant donné un client inconscient, quand une facture lui est envoyée, alors il ne voit rien et `livree = 0`.
  - Étant donné ce client réanimé, alors il reçoit la notification « Nouvelle facture… » dans la seconde.
  - Étant donné un client QBCore à terre (`inlaststand = true`) réanimé par un EMS, quand `inlaststand` repasse à `false`, alors la facture en file lui est livrée sans qu'aucune boucle ne tourne.
  - Étant donné un client mort qui appelle `factures.payer` par console, alors refus `inconscient` et aucun débit.

### [ENT-FAC-08] Suivi des factures : liste
- **But** : voir les factures émises par l'entreprise et leur état.
- **Qui** : droit `facture.creer` pour voir **ses propres** factures ; droit `facture.voir_toutes` (Chef, Patron) pour voir toutes celles de l'entreprise.
- **Où** : Factures > onglet « Suivi ».
- **Parcours** :
  1. RPC `factures.suivi.liste` `{ statut, periode, employe, recherche, page }` (filtres : ENT-FAC-09 ; défaut : statut « Toutes », période 30 jours).
  2. Serveur : traite les retards de l'entreprise (ENT-FAC-16/17, au plus 100 factures par passage) ; lit `pop_tablet_factures WHERE company = ?` (+ `AND auteur = ?` si pas `voir_toutes`) avec filtres, tri par `cree_le` décroissant, 20 par page ; renvoie aussi les compteurs par statut pour les onglets.
  3. Interface : onglets de statut avec compteur « Toutes (42) », « En attente (5) », « Payées (35) », « Refusées (2) », « Annulées (0) » ; liste : numéro, date, client, auteur (si `voir_toutes`), total, statut + indicateurs « En retard » / « Transmise à la police ». Clic → détail (ENT-FAC-10).
- **Données** (affichées) : `numero`, `cree_le`, `client_nom`, `auteur_nom`, `total`, `statut`, `en_retard`, `transmise_police`.
- **Règles serveur** : droit ; périmètre (propres ou toutes) appliqué côté serveur ; pagination 20 ; fréquence 1/s.
- **Textes et états** : onglet « Suivi » (`factures.suivi.titre`) ; onglets statut (`factures.suivi.onglet.*`) ; colonnes « N° », « Date », « Client », « Employé », « Total », « État » (`factures.suivi.col.*`) ; vide : « Aucune facture pour ces critères. » + bouton « Nouvelle facture » (`factures.suivi.vide`) ; pas le droit : onglet caché.
- **Notifications** : aucune.
- **Liens** : Ventes (clic sur un jour/un employé ouvre cette liste filtrée).
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : requête indexée (`company`, `statut`, `cree_le`) ; compteurs par `GROUP BY statut` sur la même période ; traitement des retards limité à 100 lignes par appel.
- **Cas limites** : employé sans `voir_toutes` → ne voit que ses factures, colonne « Employé » cachée ; 10 000 factures → pagination et période par défaut 30 jours ; ancien employé → ses factures restent visibles des responsables.
- **Critères d'acceptation** :
  - Étant donné un membre qui a fait 3 factures et un collègue 4, quand le membre ouvre Suivi, alors il en voit 3.
  - Étant donné le patron, alors il en voit 7 et la colonne Employé.
  - Étant donné un membre qui envoie par console `employe = <collègue>`, alors le serveur ignore le filtre et ne renvoie que les siennes.

### [ENT-FAC-09] Suivi des factures : filtres
- **But** : retrouver vite une facture par statut, période, employé ou client.
- **Qui** : comme ENT-FAC-08 (filtre Employé seulement avec `facture.voir_toutes`).
- **Où** : Factures > Suivi > barre de filtres au-dessus de la liste.
- **Parcours** :
  1. Filtres : « État » (onglets), « Période » (Aujourd'hui / 7 jours / 30 jours / Tout / « Jour précis » avec sélecteur de date), « Employé » (liste des employés + anciens auteurs, si `voir_toutes`), « Client ou n° » (champ texte).
  2. Chaque changement relance RPC `factures.suivi.liste` (page 1) ; le champ texte attend 400 ms après la dernière frappe et 2 caractères minimum.
  3. Bouton « Effacer les filtres ».
  4. Les filtres choisis sont gardés en mémoire de l'interface pendant la session (perdus à la déconnexion).
- **Données** : `statut` ∈ {`toutes`,`attente`,`payee`,`refusee`,`annulee`,`en_retard`,`transmise`} ; `periode` ∈ {`jour`,`7`,`30`,`tout`,`date:AAAA-MM-JJ`} ; `employe` identifiant ou vide ; `recherche` 2 à 30 caractères (cherche dans `client_nom` et `numero`).
- **Règles serveur** : valeurs hors liste → filtre par défaut ; `employe` ignoré sans `voir_toutes` ; texte échappé pour `LIKE` ; fréquence 2/s.
- **Textes et états** : « État », « Période », « Employé », « Client ou n° » (`factures.filtres.*`) ; périodes « Aujourd'hui », « 7 jours », « 30 jours », « Tout », « Jour précis » (`factures.filtres.periode.*`) ; « Effacer les filtres » (`factures.filtres.effacer`) ; « En retard » et « Transmises » ajoutés aux onglets d'état si au moins une facture existe dans ce cas.
- **Notifications** : aucune.
- **Liens** : Ventes (ouvre avec `periode = date:` ou `employe`).
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : mêmes index ; recherche `LIKE` limitée à la période choisie.
- **Cas limites** : filtres sans résultat → `factures.suivi.vide` ; date future → aucun résultat ; recherche d'un numéro exact « F-000123 » → 1 résultat.
- **Critères d'acceptation** :
  - Étant donné le filtre « En attente » + « 7 jours », alors seules les factures en attente créées depuis 7 jours s'affichent.
  - Étant donné la recherche « F-000123 », alors cette facture apparaît seule.
  - Étant donné une recrue qui envoie un filtre `employe` par console, alors il est ignoré.

### [ENT-FAC-10] Suivi des factures : détail
- **But** : voir tout d'une facture émise (lignes, historique) et agir dessus.
- **Qui** : l'auteur, ou `facture.voir_toutes`.
- **Où** : Factures > Suivi > clic sur une facture.
- **Parcours** :
  1. RPC `factures.suivi.detail` `{ numero }`.
  2. Serveur : vérifie l'entreprise et le périmètre ; renvoie la facture + ses événements (`pop_tablet_factures_evenements`, ordre chronologique).
  3. Écran : en-tête (numéro, statut, client, auteur, dates), tableau des lignes, sous-total, majoration, total, part employé (« Part employé : {pct} % = {montant} »), note, moyen de paiement, raison du refus ; frise « Historique » (« Créée par {nom} », « Reçue par le client », « Relancée par {nom} », « Majorée de {montant} », « Transmise à la police », « Payée par banque », « Refusée », « Annulée par {nom} ») avec date.
  4. Boutons selon l'état et les droits : « Relancer » (ENT-FAC-14), « Annuler la facture » (ENT-FAC-11), « Transmettre à la police » (ENT-FAC-17, manuel), « Refaire une facture » (copie les lignes et le client dans Nouvelle facture).
- **Données** (affichées) : toutes les colonnes utiles de `pop_tablet_factures` + événements (`type`, `par_nom`, `details`, `cree_le`).
- **Règles serveur** : même entreprise ; auteur ou `voir_toutes` ; fréquence 1/s.
- **Textes et états** : libellés d'historique (`factures.historique.*`) ; « Sous-total », « Majoration », « Total », « Part employé : {pct} % = {montant} », « Payée par {moyen} le {date} » (`factures.detail.*`) ; « Refaire une facture » (`factures.detail.refaire`) ; erreur facture introuvable : « Facture introuvable. » (`factures.detail.introuvable`).
- **Notifications** : aucune.
- **Liens** : ENT-FAC-11, 14, 17, 01.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : 2 requêtes indexées.
- **Cas limites** : facture d'une autre entreprise demandée par console → `introuvable` ; facture sans événement (ancienne) → historique minimal tiré des dates ; auteur viré → son nom reste.
- **Critères d'acceptation** :
  - Étant donné une facture créée, relancée puis payée, alors la frise montre 4 étapes dans l'ordre.
  - Étant donné une facture payée, alors les boutons Relancer et Annuler sont absents.
  - Étant donné un membre qui demande le détail de la facture d'un collègue (sans `voir_toutes`), alors `introuvable`.

### [ENT-FAC-11] Annuler une facture (ajout)
- **But** : retirer une facture envoyée par erreur, tant qu'elle n'est pas payée, sans jamais l'effacer.
- **Qui** : l'auteur pour ses propres factures ; `facture.voir_toutes` (Chef, Patron) pour toutes celles de l'entreprise ; admin.
- **Où** : Factures > Suivi > détail > « Annuler la facture ».
- **Parcours** : 1. Fenêtre « Annuler la facture {numero} ? » + champ « Raison » obligatoire. 2. RPC `factures.annuler` `{ numero, motif, actionId }`. 3. Serveur : vérifie droit, `statut = 'attente'` ; `UPDATE ... SET statut='annulee', annule_le=?, annule_par=? WHERE id=? AND statut='attente'` ; événement `annulee` avec la raison ; si `transmise_police` → prévient la police que le dossier est clos (événement `pop_tablet:invoiceClosed`). 4. Notification au client. 5. Signal serveur `pop_tablet:invoiceCancelled` (`numero, company, metadata`).
- **Données** : `motif` 3 à 100 caractères (stocké dans `pop_tablet_factures_evenements.details`).
- **Règles serveur** : statut `attente` uniquement (une facture payée ne s'annule pas : un remboursement se fait par Retirer ou Prime) ; périmètre ; fréquence 1/s ; une facture API avec `metadata.annulableTablette = false` ne peut être annulée que par l'admin.
- **Textes et états** : bouton « Annuler la facture » (`factures.annuler.bouton`) ; titre (`factures.annuler.titre`) ; champ « Raison » (`factures.annuler.raison`) ; succès « Facture {numero} annulée. » (`factures.annuler.ok`) ; erreurs `factures.payer.deja`, « Cette facture ne peut pas être annulée ici. » (`factures.annuler.interdit`), `commun.erreur.champ_requis`.
- **Notifications** : client (en ligne, tablette) : « {entreprise} a annulé la facture {numero}. » (`factures.notif.annulee`) ; s'il a une fenêtre simple en attente pour cette facture, elle est retirée de sa file.
- **Liens** : Police (dossier clos), signal API.
- **Réglages** : aucun.
- **Journal admin** : oui : acteur, numéro, total, raison.
- **Performance** : 1 mise à jour + 1 insertion.
- **Cas limites** : annulation et paiement au même instant → le premier `UPDATE` gagne ; facture déjà refusée → bouton caché (statut final) ; double clic → une annulation.
- **Critères d'acceptation** :
  - Étant donné une facture en attente, quand son auteur l'annule avec une raison, alors le statut est `annulee` et la ligne reste en base.
  - Étant donné une facture payée, alors le bouton n'existe pas et le RPC répond `deja`.
  - Étant donné un membre qui annule par console la facture d'un collègue, alors refus `droit`.

### [ENT-FAC-12] Régler la part employé
- **But** : fixer le pourcentage de chaque facture payée reversé à l'employé qui l'a faite.
- **Qui** : droit `facture.regler` (Patron) ; admin.
- **Où** : Factures > onglet « Réglages » > bloc « Part employé ».
- **Parcours** :
  1. RPC `factures.reglages.lire` → réglages de l'entreprise (`pop_tablet_ent_reglages`) ou défauts de config.
  2. Curseur + champ « Part employé (%) » de 0 à `Config.Factures.PartMax` ; exemple calculé en direct : « Sur une facture de 1 000 $ : 100 $ pour l'employé, 900 $ pour l'entreprise. ».
  3. RPC `factures.reglages.part` `{ pct }`.
  4. Serveur : borne, écrit `pop_tablet_ent_reglages (company, 'factures.part_pct', pct)`, cache mémoire mis à jour.
  5. Le nouveau pourcentage s'applique aux factures **créées après** (le pourcentage est figé sur chaque facture à sa création).
- **Données** (`pop_tablet_ent_reglages`) :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `company_id` | INT | Oui | `pop_tablet_companies.id` | — |
| `cle` | VARCHAR(60) | Oui | clé connue | — |
| `valeur` | VARCHAR(100) | Oui | — | — |
| `modifie_par` | VARCHAR(60) | Oui | — | — |
| `modifie_le` | INT UNSIGNED | Oui | — | — |

  Clé primaire (`company`, `cle`). Clés de ce fichier : `factures.part_pct` (défaut `Config.Factures.PartDefaut = 10`), `factures.delai_h`, `factures.mode_impaye`, `factures.majoration_pct` (ENT-FAC-15).
- **Règles serveur** : droit ; entier 0 à `Config.Factures.PartMax = 50` ; fréquence 1 toutes les 5 s.
- **Textes et états** : onglet « Réglages » (`factures.reglages.titre`) ; « Part employé (%) » (`factures.reglages.part`) ; exemple (`factures.reglages.part_exemple`) ; info « S'applique aux nouvelles factures. » (`factures.reglages.part_info`) ; succès « Part employé : {pct} %. » (`factures.reglages.part_ok`) ; erreur « Entre 0 et {max} %. » (`factures.reglages.part_borne`) ; pas le droit : onglet caché.
- **Notifications** : employés de l'entreprise en ligne avec tablette : « Nouvelle part employé : {pct} % sur vos ventes. » (`factures.notif.part`).
- **Liens** : ENT-FAC-01 (figé), ENT-FAC-13 (versement).
- **Réglages** : `Config.Factures.PartDefaut = 10` ; `Config.Factures.PartMax = 50`.
- **Journal admin** : oui : avant/après.
- **Performance** : réglages en cache mémoire (chargés au démarrage en une requête).
- **Cas limites** : 0 % → aucune part, aucune ligne de mouvement `part_employe` ; valeur décimale par console → refus ; police/EMS : fonctionne pareil (la part peut être mise à 0).
- **Critères d'acceptation** :
  - Étant donné une part réglée à 20 %, quand une facture est créée, alors `part_pct = 20` y est enregistré.
  - Étant donné une facture créée à 10 % puis la part passée à 30 %, quand elle est payée, alors la part versée est 10 %.
  - Étant donné un chef qui envoie `pct = 90` par console, alors refus `droit` (et `part_borne` pour un patron).

### [ENT-FAC-13] Versement de la part employé
- **But** : verser automatiquement à l'employé auteur sa part quand une facture est payée.
- **Qui** : système, au paiement (ENT-FAC-04 / 05).
- **Où** : aucun écran ; visible dans le détail de la facture, dans le compte (mouvement) et dans « Mes ventes ».
- **Parcours** :
  1. Au paiement : `part = floor(sous_total × part_pct / 100)` (la majoration de retard reste entièrement à l'entreprise).
  2. Si `part > 0` et que l'auteur fait **toujours** partie de l'entreprise (métier ESX = `company`, lu en ligne ou en base) : l'entreprise reçoit `total − part`, l'auteur reçoit `part` en banque (`Bridge.AddMoney` ou `AddMoneyOffline`).
  3. Sinon (auteur parti, facture API sans auteur) : `part = 0`, l'entreprise reçoit tout.
  4. `part_employe_montant` enregistré ; deux mouvements `pop_tablet_ent_mouvements` : `facture` (+ total) et `part_employe` (− part), pour que le compte affiche le détail.
- **Données** : `pop_tablet_factures.part_employe_montant` ; mouvements.
- **Règles serveur** : calcul uniquement serveur ; arrondi à l'entier inférieur ; part jamais versée deux fois (fait dans le même traitement verrouillé que le paiement) ; l'argent de la part ne transite pas par le compte société (versement direct, pour éviter un échec si le compte est bas).
- **Textes et états** : libellé de mouvement « Part employé {nom} · {numero} » (`gestion.compte.type.part_employe`).
- **Notifications** : auteur (en ligne, tablette) : « Part de {part} reçue pour la facture {numero}. » (`factures.notif.part_recue`).
- **Liens** : Compte, Ventes par employé.
- **Réglages** : ceux de ENT-FAC-12.
- **Journal admin** : non (inclus dans la ligne du paiement si journalisé).
- **Performance** : inclus dans le paiement.
- **Cas limites** : auteur hors ligne → banque hors ligne ; auteur viré avant le paiement → part à l'entreprise ; auteur passé dans une autre entreprise puis revenu → il touche la part (il est de nouveau membre).
- **Critères d'acceptation** :
  - Étant donné une facture de 1 000 $ à 10 %, quand elle est payée, alors l'auteur reçoit 100 $ en banque et l'entreprise 900 $.
  - Étant donné l'auteur viré entre-temps, alors l'entreprise reçoit 1 000 $ et l'auteur rien.
  - Étant donné une majoration de 100 $ sur cette facture, alors l'auteur reçoit toujours 100 $ et l'entreprise 1 000 $.

### [ENT-FAC-14] Relancer une facture
- **But** : rappeler au client qu'une facture est en attente.
- **Qui** : l'auteur ou `facture.voir_toutes`.
- **Où** : Factures > Suivi > détail > « Relancer » (aussi icône « cloche » sur la ligne d'une facture en attente).
- **Parcours** : 1. RPC `factures.relancer` `{ numero, actionId }`. 2. Serveur : vérifie périmètre, `statut = 'attente'`, délai depuis la dernière relance, nombre de relances ; incrémente `relances`, `derniere_relance` ; événement `relancee`. 3. Client en ligne et conscient : notification tablette, ou fenêtre simple s'il n'a pas de tablette ; inconscient : file réveil (ENT-FAC-07) ; hors ligne : rien d'autre (il la verra dans Reçues / fenêtre à la connexion). 4. Bandeau pour l'employé.
- **Données** : `relances` (0 à `Config.Factures.RelancesMax`), `derniere_relance`.
- **Règles serveur** : 1 relance par facture toutes les 30 min (`Config.Factures.RelanceDelai = 1800`) ; 5 relances max (`Config.Factures.RelancesMax = 5`) ; statut `attente` ; fréquence 1/s par employé.
- **Textes et états** : bouton « Relancer » (`factures.relancer.bouton`) ; succès « Relance envoyée à {client}. » (`factures.relancer.ok`) ; client hors ligne : « Relance enregistrée : {client} n'est pas en ville. » (`factures.relancer.ok_hors_ligne`) ; erreurs « Prochaine relance possible dans {minutes} min. » (`factures.relancer.trop_tot`), « Nombre maximum de relances atteint. » (`factures.relancer.max`) ; bouton grisé dans ces deux cas avec le même texte.
- **Notifications** : client : « Rappel : facture {numero} de {entreprise}, {total} à régler. » (`factures.notif.relance`).
- **Liens** : ENT-FAC-05 (fenêtre simple).
- **Réglages** : `Config.Factures.RelanceDelai = 1800` ; `Config.Factures.RelancesMax = 5`.
- **Journal admin** : non.
- **Performance** : 1 mise à jour + 1 insertion.
- **Cas limites** : client hors ligne → relance comptée quand même ; double clic → une relance ; facture payée entre-temps → `factures.payer.deja`.
- **Critères d'acceptation** :
  - Étant donné une facture relancée il y a 10 min, alors une nouvelle relance est refusée `trop_tot` (20 min restantes).
  - Étant donné un client sans tablette en ligne, alors la relance ouvre la fenêtre simple.
  - Étant donné 5 relances déjà faites, quand un employé force une 6e par console, alors refus `max`.

### [ENT-FAC-15] Réglages des impayés (délai et mode)
- **But** : choisir après combien de temps une facture en attente devient impayée et ce qui se passe alors.
- **Qui** : droit `facture.regler` (Patron) ; admin.
- **Où** : Factures > Réglages > bloc « Impayés ».
- **Parcours** :
  1. Champs : « Délai avant impayé » (liste : 24 h, 48 h, 72 h, 7 jours ; défaut `Config.Factures.Impayes.DelaiDefaut`) ; « Que faire ensuite ? » (choix uniques parmi les modes autorisés par l'admin) : « Rien », « Majorer la facture », « Transmettre à la police », « Majorer puis transmettre » ; « Majoration (%) » (visible si un mode avec majoration est choisi), de 1 à `Config.Factures.Impayes.MajorationMax`.
  2. RPC `factures.reglages.impayes` `{ delai_h, mode, majoration_pct }`.
  3. Serveur : vérifie que le mode est dans `Config.Factures.Impayes.ModesAutorises` et que la police est disponible si besoin (`Config.Factures.Impayes.PoliceActive = true` et métier police configuré) ; écrit 3 clés dans `pop_tablet_ent_reglages`.
  4. Le délai s'applique aux factures créées après (échéance figée à la création) ; le mode s'applique à toutes les factures en retard non encore traitées.
- **Données** : `factures.delai_h` ∈ {24, 48, 72, 168} ; `factures.mode_impaye` ∈ {`aucun`,`majoration`,`police`,`les_deux`} ; `factures.majoration_pct` 1 à 50.
- **Règles serveur** : droit ; valeurs dans les listes ; police : la police ne peut pas se transmettre ses propres factures si `Config.Factures.Impayes.PoliceSurPolice = false` (défaut : `true`, les amendes impayées vont dans la liste des impayés de la police) ; fréquence 1 toutes les 5 s.
- **Textes et états** : « Délai avant impayé » (`factures.reglages.delai`), options « 24 heures », « 48 heures », « 72 heures », « 7 jours » (`factures.reglages.delai.*`) ; « Que faire ensuite ? » (`factures.reglages.mode`), options « Rien » / « Majorer la facture » / « Transmettre à la police » / « Majorer puis transmettre » (`factures.reglages.mode.*`) ; « Majoration (%) » (`factures.reglages.majoration`) ; succès « Réglages des impayés enregistrés. » (`factures.reglages.impayes_ok`) ; erreur « Option désactivée par le serveur. » (`factures.reglages.mode_interdit`) ; info « Le délai compte en temps réel, serveur allumé ou non. » (`factures.reglages.delai_info`).
- **Notifications** : aucune.
- **Liens** : ENT-FAC-16, 17 ; Police.
- **Réglages** : `Config.Factures.Impayes.DelaiDefaut = 72` ; `Config.Factures.Impayes.ModeDefaut = 'aucun'` ; `Config.Factures.Impayes.MajorationDefaut = 10` ; `Config.Factures.Impayes.MajorationMax = 50` ; `Config.Factures.Impayes.ModesAutorises = { 'aucun', 'majoration', 'police', 'les_deux' }` ; `Config.Factures.Impayes.PoliceActive = true` ; `Config.Factures.Impayes.MetierPolice = 'police'` ; `Config.Factures.Impayes.PoliceSurPolice = true`.
- **Journal admin** : oui : avant/après.
- **Performance** : cache mémoire.
- **Cas limites** : l'admin retire le mode `police` de la config alors qu'une entreprise l'avait choisi → traité comme `aucun` (ou `majoration` si `les_deux`) et l'écran affiche « Option désactivée par le serveur. » ; pas de métier police sur le serveur → options police cachées ; délai 7 jours sur une facture déjà créée à 72 h → la facture garde 72 h.
- **Critères d'acceptation** :
  - Étant donné le mode « Majorer » à 10 %, quand une facture passe en retard, alors elle est majorée de 10 % (ENT-FAC-16).
  - Étant donné `PoliceActive = false`, alors les options police n'apparaissent pas.
  - Étant donné un patron qui envoie `mode = 'police'` par console alors que c'est désactivé, alors refus `mode_interdit`.

### [ENT-FAC-16] Majoration des factures impayées
- **But** : ajouter une seule fois une pénalité à une facture restée en attente après son échéance.
- **Qui** : système.
- **Où** : aucun écran ; visible dans Reçues, Suivi, détail (« Majoration de retard »).
- **Parcours** :
  1. Pas de minuteur : traitement « à la lecture » par la fonction serveur `Impayes.Traiter(filtre)` appelée : à l'ouverture de Suivi (filtre entreprise), de Reçues (filtre client), à la connexion d'un joueur (filtre client), avant chaque paiement (filtre facture), à l'ouverture de la liste des impayés police (tout, 100 max), au démarrage du script (tout, par paquets de 500).
  2. Pour chaque facture `statut = 'attente' AND echeance < now AND majoration = 0` dont le mode de l'entreprise inclut la majoration : `majoration = floor(sous_total × pct / 100)` (minimum 1 $), `total = sous_total + majoration`, événement `majoree`.
  3. Requête unique : `UPDATE pop_tablet_factures SET majoration = FLOOR(sous_total * ? / 100), total = sous_total + FLOOR(sous_total * ? / 100) WHERE ... AND majoration = 0` (une par entreprise concernée) puis insertion groupée des événements.
  4. Client prévenu s'il est en ligne.
- **Données** : `majoration`, `total`.
- **Règles serveur** : une seule majoration par facture (`majoration = 0` dans la condition) ; jamais sur une facture payée, refusée ou annulée ; pas de majoration composée.
- **Textes et états** : « Majoration de retard : {montant} » (`factures.recues.majoration`) ; historique « Majorée de {montant} » (`factures.historique.majoree`).
- **Notifications** : client : « La facture {numero} de {entreprise} est en retard : nouveau total {total}. » (`factures.notif.majoree`).
- **Liens** : Ventes (le total payé inclut la majoration), part employé (calculée sur le sous-total).
- **Réglages** : ceux de ENT-FAC-15.
- **Journal admin** : non (l'historique de la facture suffit).
- **Performance** : aucun thread ; traitement par requêtes groupées limitées.
- **Cas limites** : client qui ouvre la fenêtre de paiement juste avant l'échéance et valide juste après → le paiement relance le traitement, le total change, refus `factures.payer.montant_change` puis le client confirme le nouveau total ; serveur éteint pendant l'échéance → majoration appliquée au premier traitement suivant ; mode changé en « Rien » avant traitement → pas de majoration.
- **Critères d'acceptation** :
  - Étant donné une facture de 500 $ échue et une majoration de 10 %, quand le client ouvre Reçues, alors le total affiché est 550 $.
  - Étant donné cette facture rouverte 3 fois, alors elle reste à 550 $.
  - Étant donné un client qui envoie par console un paiement à l'ancien total de 500 $, alors refus `montant_change`.

### [ENT-FAC-17] Transmission des impayés à la police
- **But** : envoyer automatiquement (ou à la main) une facture impayée à la police, qui la voit dans sa liste des impayés.
- **Qui** : système (mode `police` ou `les_deux`) ; à la main : `facture.regler` sur une facture en retard ou refusée, si `PoliceActive`.
- **Où** : automatique : aucun écran ; manuel : Factures > Suivi > détail > « Transmettre à la police ».
- **Parcours** :
  1. Automatique : pendant `Impayes.Traiter`, les factures `attente`, échues depuis au moins `Config.Factures.Impayes.DelaiPoliceApresMajoration = 0` h de plus (si `les_deux`), `transmise_police = 0` → `transmise_police = 1`, événement `transmise_police`.
  2. Manuel : RPC `factures.transmettre_police` `{ numero, actionId }` ; vérifie droit, facture en retard ou refusée, pas déjà transmise.
  3. Pour chaque facture transmise : événement serveur `pop_tablet:invoiceUnpaid` (`{ numero, company, entrepriseLabel, client, clientNom, total, cree_le, echeance, statut }`) que l'app Police (fiche 03) enregistre dans sa liste « Impayés » et sur la fiche citoyen.
  4. La facture reste payable par le client ; quand elle est payée (ou annulée), événement `pop_tablet:invoiceClosed` (`numero, raison = 'payee'|'annulee'`) : la police la voit « Réglée ».
- **Données** : `transmise_police`.
- **Règles serveur** : jamais deux transmissions ; une facture refusée n'est transmise qu'à la main ; police absente ou option coupée → rien ; fréquence manuelle 1/s.
- **Textes et états** : bouton « Transmettre à la police » (`factures.police.bouton`) ; confirmation « Envoyer cette facture impayée à la police ? » (`factures.police.confirm`) ; succès « Facture transmise à la police. » (`factures.police.ok`) ; erreurs « Déjà transmise. » (`factures.police.deja`), « Seules les factures en retard ou refusées peuvent être transmises. » (`factures.police.pas_retard`), `factures.reglages.mode_interdit`.
- **Notifications** : client : « La facture {numero} de {entreprise} a été transmise à la police. » (`factures.notif.transmise`) ; policiers en service avec tablette : aucune notification individuelle (la liste suffit, évite le spam).
- **Liens** : Police (impayés, fiche citoyen) ; ENT-FAC-04 (fermeture côté police au paiement).
- **Réglages** : ceux de ENT-FAC-15 ; `Config.Factures.Impayes.DelaiPoliceApresMajoration = 0`.
- **Journal admin** : oui pour la transmission manuelle (acteur, numéro, client, total) ; non pour l'automatique.
- **Performance** : traitement groupé ; événement serveur interne (pas de réseau).
- **Cas limites** : app Police non installée/désactivée → l'option est cachée et le serveur n'émet rien ; facture payée juste après transmission → police notifiée « Réglée » ; double clic manuel → une seule transmission.
- **Critères d'acceptation** :
  - Étant donné le mode « Transmettre à la police » et une facture échue, quand le traitement passe, alors `transmise_police = 1` et la police la voit dans ses impayés.
  - Étant donné cette facture payée ensuite, alors la police la voit « Réglée ».
  - Étant donné un membre (sans `facture.regler`) qui appelle `factures.transmettre_police` par console, alors refus `droit`.

### [ENT-FAC-18] Signal API « facture payée »
- **But** : prévenir les autres scripts (immobilier, garages, concessions…) qu'une facture a été payée, avec assez d'infos pour agir.
- **Qui** : système ; consommé par des ressources serveur tierces.
- **Où** : serveur uniquement.
- **Parcours** :
  1. Juste après un paiement réussi (tout est écrit), `TriggerEvent('pop_tablet:invoicePaid', donnees)` côté serveur (événement local, pas réseau : un client ne peut pas le déclencher ni l'écouter).
  2. Émission par `exports.pop_tablet:EmitInvoicePaid(donnees)` de la base ; `donnees` au format unique de BASE-API-09 (`invoiceId, number, uid, paymentId, amount, subtotal, surcharge, method, payer, company, employee, lines, metadata, externalRef, sourceScript, kind, at`).
  3. Même format pour `pop_tablet:invoiceRefused`, `pop_tablet:invoiceCancelled`, `pop_tablet:invoiceUnpaid` et `pop_tablet:invoiceClosed`.
  4. Export de lecture `exports.pop_tablet:GetInvoice(numeroOuUid)` → mêmes champs + `statut`, ou `nil`.
  5. Documenté dans le guide API ouvert (`docs/api.md` de la ressource) avec un exemple : un script immobilier crée la facture avec `metadata = { maison = 12 }` puis donne les clés en écoutant `pop_tablet:invoicePaid`.
- **Données** : voir ci-dessus.
- **Règles serveur** : émis une seule fois par facture (dans le traitement verrouillé) ; une erreur dans un script écouteur ne doit pas casser le paiement (l'émission se fait après la réponse au client, dans un `CreateThread` court qui se termine aussitôt) ; `metadata` renvoyée telle qu'enregistrée.
- **Textes et états** : aucun texte joueur.
- **Notifications** : aucune.
- **Liens** : ENT-FAC-19 (création API), Police (amendes payées), Mécano (devis payé).
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : un événement local par paiement.
- **Cas limites** : aucun écouteur → rien ; script écouteur qui plante → paiement déjà validé, erreur seulement en console de ce script ; facture payée pendant un redémarrage de l'écouteur → l'écouteur peut rattraper via `GetInvoice`.
- **Critères d'acceptation** :
  - Étant donné un script qui écoute `pop_tablet:invoicePaid`, quand une facture est payée, alors il reçoit le numéro, le total et la `metadata`.
  - Étant donné deux paiements concurrents de la même facture, alors le signal n'est émis qu'une fois.
  - Étant donné un client qui fait `TriggerServerEvent('pop_tablet:invoicePaid', ...)`, alors rien ne se passe (aucun `RegisterNetEvent` sur ce nom).

### [ENT-FAC-19] Créer une facture par l'API (ajout)
- **But** : permettre aux autres apps de la tablette (amendes police, devis mécano acceptés) et aux scripts tiers de créer une facture qui suit exactement les mêmes règles.
- **Qui** : ressources serveur (export serveur uniquement).
- **Où** : `exports.pop_tablet:CreateInvoice(params)`.
- **Parcours** :
  1. `params` = `{ company (obligatoire), auteur = source | identifier | nil, client = source | identifier (obligatoire), lignes (obligatoire), note, refusAutorise = true, metadata, partPct = nil, echeanceHeures = nil, verifierGrade = false }`.
  2. Le serveur applique les règles de ENT-FAC-01 sauf droit/service/plafond du grade (appliqués seulement si `verifierGrade = true` et `auteur` est une source) ; `source = 'api'`, `source_script = GetInvokingResource()`.
  3. `partPct = nil` → réglage de l'entreprise ; `echeanceHeures = nil` → réglage de l'entreprise.
  4. Livraison au client identique (tablette, fenêtre simple, inconscient, hors ligne).
  5. Retour : `{ ok = true, numero, uid }` ou `{ ok = false, code = 'client_inconnu'|'lignes'|'plafond'|'trop_attente'|'company_inconnue' }`.
- **Données** : mêmes colonnes ; `metadata` JSON 2 Ko max.
- **Règles serveur** : company existante (métier ESX) ; plafond global ; nombre de factures en attente ; aucune limite de fréquence côté API (ressources de confiance) mais 1 facture par seconde maximum par client cible.
- **Textes et états** : identiques à ENT-FAC-01 côté client ; l'auteur affiché est « {entreprise} » si `auteur = nil`.
- **Notifications** : comme ENT-FAC-01.
- **Liens** : Police amende (`refusAutorise = false`, company `police`), Mécano devis (`metadata = { devis = id }`), ENT-FAC-18.
- **Réglages** : `Config.API.CreateInvoiceEnabled = true`.
- **Journal admin** : oui : ressource appelante, entreprise, client, total.
- **Performance** : identique à ENT-FAC-01.
- **Cas limites** : `client` hors ligne (identifiant) → créée, livrée à la connexion ; `company` inconnue → `company_inconnue` ; `metadata` trop grosse → refus `lignes`.
- **Critères d'acceptation** :
  - Étant donné l'app Police qui crée une amende avec `refusAutorise = false`, alors le citoyen ne voit pas « Refuser ».
  - Étant donné un appel avec 25 lignes, alors `{ ok = false, code = 'lignes' }`.
  - Étant donné un client joueur qui tente d'appeler l'export (impossible côté client), alors il n'existe pas côté client (export déclaré dans `server.lua` uniquement).

---

## 3. Annonces (app « Annonces »)

L'app « Annonces » (`annonces.titre` : « Annonces ») sert à l'entreprise. Elle n'est visible qu'aux employés ayant `annonce.publier` ou `annonce.ville` (les autres voient les annonces dans le Navigateur / l'Annuaire, branche 3).

Table commune `pop_tablet_ent_annonces` :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `id` | INT AUTO_INCREMENT | Oui | — | — |
| `company_id` | INT | Oui | `pop_tablet_companies.id` | — |
| `type` | ENUM(`entreprise`,`ville`) | Oui | — | `entreprise` |
| `titre` | VARCHAR(60) | Oui | 3 à 60 caractères, nettoyé | — |
| `texte` | VARCHAR(500) | Oui | `entreprise` : 10 à 500 ; `ville` : 10 à 150 | — |
| `image` | VARCHAR(300) | Non | règle 0.5 ; jamais pour `ville` | NULL |
| `auteur` | VARCHAR(60) | Oui | identifiant | — |
| `auteur_nom` | VARCHAR(100) | Oui | — | — |
| `debut` | INT UNSIGNED | Oui | — | `os.time()` |
| `fin` | INT UNSIGNED | Oui | > `debut` | voir fiches |
| `statut` | ENUM(`active`,`expiree`,`retiree`) | Oui | — | `active` |
| `modifie_le` | INT UNSIGNED | Non | — | NULL |
| `modifie_par` | VARCHAR(60) | Non | — | NULL |
| `retiree_par` | VARCHAR(60) | Non | — | NULL |
| `retiree_le` | INT UNSIGNED | Non | — | NULL |
| `cout` | INT | Oui | prix payé (ville) | 0 |

Index (`company`, `statut`, `fin`), (`type`, `statut`, `fin`). Jamais supprimée (retrait = statut `retiree`, visible par l'admin).

Cache serveur : `Annonces.Actives[company] = { ... }` et `Annonces.Ville = { ... }`, chargés au démarrage, mis à jour à chaque publication, modification, retrait. Le Navigateur (sites) et l'Annuaire lisent ce cache, jamais la base.

### [ENT-ANN-01] Liste des annonces de l'entreprise (ajout)
- **But** : voir les annonces actives, expirées et retirées de son entreprise pour les gérer.
- **Qui** : droit `annonce.publier` ou `annonce.ville`.
- **Où** : Annonces > écran d'accueil.
- **Parcours** :
  1. RPC `annonces.liste` `{ filtre = 'active'|'terminee', page }` (défaut `active`).
  2. Serveur : marque d'abord comme `expiree` les annonces de l'entreprise dont `fin < now` (ENT-ANN-05) ; puis lit 20 annonces, tri `debut` décroissant.
  3. Écran : boutons en haut « Nouvelle annonce » (si `annonce.publier`) et « Annonce à toute la ville » (si `annonce.ville`) ; onglets « En cours » / « Terminées » ; cartes : image miniature (si présente), titre, début du texte (80 caractères), type (« Entreprise » / « Toute la ville »), « Se termine le {date} » ou « Terminée le {date} » / « Retirée par {nom} », auteur ; boutons « Modifier » et « Retirer » sur les annonces actives de type `entreprise`.
  4. Compteur « {n} / {max} annonces en cours ».
- **Données** (affichées) : colonnes de `pop_tablet_ent_annonces`.
- **Règles serveur** : droit ; même entreprise ; pagination 20 ; fréquence 1/s.
- **Textes et états** : onglets « En cours » (`annonces.liste.en_cours`), « Terminées » (`annonces.liste.terminees`) ; boutons « Nouvelle annonce » (`annonces.liste.nouvelle`), « Annonce à toute la ville » (`annonces.liste.ville`) ; types « Entreprise » / « Toute la ville » (`annonces.type.*`) ; « Se termine le {date} » (`annonces.liste.fin`), « Terminée le {date} » (`annonces.liste.terminee`), « Retirée par {nom} » (`annonces.liste.retiree`) ; compteur (`annonces.liste.compteur`) ; vide : « Aucune annonce en cours. Publiez la première pour apparaître sur votre site et dans l'annuaire. » + bouton « Nouvelle annonce » (`annonces.liste.vide`) ; pas le droit : app cachée.
- **Notifications** : aucune.
- **Liens** : ENT-ANN-02 à 06.
- **Réglages** : aucun propre.
- **Journal admin** : non.
- **Performance** : onglet « En cours » lu depuis le cache ; « Terminées » en base, paginé.
- **Cas limites** : entreprise sans annonce → vide ; annonce expirée pendant que l'écran est ouvert → elle passe dans « Terminées » au prochain chargement ; employé sans `annonce.publier` mais avec `annonce.ville` → seul le 2e bouton visible.
- **Critères d'acceptation** :
  - Étant donné 2 annonces actives et 1 expirée, alors « En cours » en montre 2 et « Terminées » 1.
  - Étant donné un membre sans droit, alors l'app Annonces n'apparaît pas.
  - Étant donné un appel console `annonces.liste` pour une autre entreprise, alors seule l'entreprise de l'appelant est lue.

### [ENT-ANN-02] Publier une annonce
- **But** : publier une annonce (titre, texte, image, durée) visible sur le site de l'entreprise et dans l'annuaire.
- **Qui** : droit `annonce.publier` (Chef, Patron) ; admin.
- **Où** : Annonces > « Nouvelle annonce ».
- **Parcours** :
  1. Formulaire : « Titre », « Texte », « Image » (champ lien + bouton « Choisir dans la Galerie »), « Durée » (1 h, 6 h, 24 h, 3 jours, 7 jours ; défaut 24 h) ; aperçu en direct à droite (rendu identique à celui du site, texte affiché en texte brut).
  2. Bouton « Publier ».
  3. RPC `annonces.publier` `{ titre, texte, image, duree_h, actionId }`.
  4. Serveur : droit ; nettoyage ; longueurs ; image (règle 0.5) ; durée dans la liste ; nombre d'annonces actives < max ; fréquence.
  5. Insertion (`type = 'entreprise'`, `fin = debut + duree_h × 3600`) ; ajout au cache ; événement serveur `pop_tablet:announcementChanged` (`company`) écouté par le Navigateur et l'Annuaire.
  6. Bandeau ; retour à la liste.
- **Données** : `titre` 3–60 ; `texte` 10–500 ; `image` facultative ; `duree_h` ∈ `Config.Annonces.Durees = { 1, 6, 24, 72, 168 }`.
- **Règles serveur** : droit ; textes nettoyés (règle 0.4) ; image autorisée ; max `Config.Annonces.MaxActives = 5` annonces actives par entreprise ; fréquence 1 publication toutes les 60 s par entreprise (`Config.Annonces.Frequence = 60`) ; `actionId` anti doublon.
- **Textes et états** : titre « Nouvelle annonce » (`annonces.publier.titre`) ; champs « Titre » (`annonces.champ.titre`), « Texte » (`annonces.champ.texte`), « Image (facultatif) » (`annonces.champ.image`), « Choisir dans la Galerie » (`annonces.champ.galerie`), « Durée » (`annonces.champ.duree`), options « 1 heure », « 6 heures », « 24 heures », « 3 jours », « 7 jours » (`annonces.duree.*`) ; « Aperçu » (`annonces.publier.apercu`) ; bouton « Publier » (`annonces.publier.bouton`) ; succès « Annonce publiée jusqu'au {date}. » (`annonces.publier.ok`) ; erreurs « Titre : 3 à 60 caractères. » (`annonces.erreur.titre`), « Texte : 10 à {max} caractères. » (`annonces.erreur.texte`), `commun.erreur.image`, « Maximum {max} annonces en cours. Retirez-en une d'abord. » (`annonces.erreur.max`), « Attendez {secondes} s avant une nouvelle annonce. » (`annonces.erreur.frequence`) ; pas le droit : bouton caché.
- **Notifications** : aucune (l'annonce est publique).
- **Liens** : Navigateur (page de l'entreprise : bloc « Annonces »), Annuaire (fiche entreprise : dernière annonce active), Galerie (image).
- **Réglages** : `Config.Annonces.Durees = { 1, 6, 24, 72, 168 }` ; `Config.Annonces.DureeDefaut = 24` ; `Config.Annonces.MaxActives = 5` ; `Config.Annonces.Frequence = 60`.
- **Journal admin** : oui : auteur, entreprise, titre, texte, image, durée.
- **Performance** : 1 insertion ; cache mis à jour ; les sites lisent le cache.
- **Cas limites** : image d'un domaine non autorisé → refus `commun.erreur.image` ; double clic → une annonce ; texte avec `<img onerror>` → enregistré sans balise ; entreprise à 5 annonces → `annonces.erreur.max`.
- **Critères d'acceptation** :
  - Étant donné un chef, quand il publie une annonce de 24 h, alors elle apparaît sur le site et dans l'annuaire de l'entreprise sans redémarrage.
  - Étant donné une image `https://exemple.com/a.png` non autorisée, alors refus.
  - Étant donné un membre (sans droit) qui appelle `annonces.publier` par console, alors refus `droit`.

### [ENT-ANN-03] Modifier une annonce
- **But** : corriger le titre, le texte ou l'image d'une annonce en cours, ou prolonger sa durée.
- **Qui** : droit `annonce.publier` ; admin.
- **Où** : Annonces > liste > « Modifier » sur une annonce active de type `entreprise`.
- **Parcours** : 1. Formulaire prérempli (comme ENT-ANN-02) ; champ « Durée » remplacé par « Prolonger » (« Ne pas changer » par défaut, ou 1 h / 6 h / 24 h / 3 jours / 7 jours **à partir de maintenant**). 2. RPC `annonces.modifier` `{ id, titre, texte, image, prolonger_h, actionId }`. 3. Serveur : droit ; annonce de l'entreprise, `statut = 'active'`, `fin > now`, type `entreprise` ; mêmes contrôles que la publication ; si `prolonger_h` : `fin = now + prolonger_h × 3600` (ne peut pas dépasser `now + 168 h`). 4. Mise à jour, `modifie_le`, `modifie_par`, cache, événement `pop_tablet:announcementChanged`. 5. Bandeau.
- **Données** : comme ENT-ANN-02 + `prolonger_h` ∈ {0, 1, 6, 24, 72, 168}.
- **Règles serveur** : droit ; annonce active ; fréquence 1 modification toutes les 10 s par annonce ; une annonce `ville` ne se modifie pas (elle se retire seulement par l'admin).
- **Textes et états** : titre « Modifier l'annonce » (`annonces.modifier.titre`) ; « Prolonger » (`annonces.modifier.prolonger`), « Ne pas changer » (`annonces.modifier.inchange`) ; bouton « Enregistrer » (`annonces.modifier.bouton`) ; succès « Annonce modifiée. » (`annonces.modifier.ok`) ; erreurs comme ENT-ANN-02 + « Cette annonce est terminée. » (`annonces.erreur.terminee`).
- **Notifications** : aucune.
- **Liens** : Navigateur, Annuaire.
- **Réglages** : ceux de ENT-ANN-02.
- **Journal admin** : oui : avant/après (titre, texte, image, fin).
- **Performance** : 1 mise à jour.
- **Cas limites** : annonce expirée pendant l'édition → `annonces.erreur.terminee` ; aucun champ changé → `ok` sans écriture ; id d'une autre entreprise par console → `annonces.erreur.terminee` (même message, aucune info divulguée).
- **Critères d'acceptation** :
  - Étant donné une annonce active, quand le chef change le titre, alors le site affiche le nouveau titre aussitôt.
  - Étant donné « Prolonger 7 jours », alors `fin = maintenant + 7 jours`.
  - Étant donné un chef d'une autre entreprise qui envoie l'id par console, alors refus et rien n'est modifié.

### [ENT-ANN-04] Retirer une annonce
- **But** : arrêter tout de suite une annonce en cours (archivée, pas effacée).
- **Qui** : droit `annonce.publier` pour les annonces `entreprise` ; admin pour toute annonce (y compris `ville`).
- **Où** : Annonces > liste > « Retirer » ; admin : Admin > Annonces (branche 5).
- **Parcours** : 1. Confirmation « Retirer cette annonce ? Elle disparaîtra du site et de l'annuaire. ». 2. RPC `annonces.retirer` `{ id, actionId }`. 3. Serveur : `UPDATE ... SET statut='retiree', retiree_par=?, retiree_le=? WHERE id=? AND company=? AND statut='active'` ; cache ; `pop_tablet:announcementChanged` ; pour une annonce `ville` retirée par l'admin, événement réseau aux tablettes pour retirer le bandeau (ENT-ANN-07). 4. Bandeau.
- **Données** : `statut`, `retiree_par`, `retiree_le`.
- **Règles serveur** : droit ; annonce active ; fréquence 1/s ; pas de remboursement du coût d'une annonce ville.
- **Textes et états** : bouton « Retirer » (`annonces.retirer.bouton`) ; confirmation (`annonces.retirer.confirm`) ; succès « Annonce retirée. » (`annonces.retirer.ok`) ; erreur `annonces.erreur.terminee`.
- **Notifications** : aucune.
- **Liens** : Navigateur, Annuaire, toutes les tablettes (bandeau ville).
- **Réglages** : aucun.
- **Journal admin** : oui : acteur, annonce (titre, texte), type.
- **Performance** : 1 mise à jour.
- **Cas limites** : déjà expirée → `terminee` ; double clic → une seule mise à jour ; annonce ville retirée par un patron par console → refus `droit` (seul l'admin).
- **Critères d'acceptation** :
  - Étant donné une annonce active, quand le chef la retire, alors elle disparaît du site et reste visible dans « Terminées » avec « Retirée par {nom} ».
  - Étant donné l'admin qui retire une annonce ville, alors le bandeau disparaît des tablettes ouvertes.
  - Étant donné un appel console sur l'annonce d'une autre entreprise, alors rien ne change.

### [ENT-ANN-05] Expiration des annonces (ajout)
- **But** : faire disparaître automatiquement les annonces à leur date de fin, sans boucle.
- **Qui** : système.
- **Où** : aucun écran.
- **Parcours** :
  1. Toute lecture du cache (site, annuaire, liste, bandeau) ignore les annonces dont `fin <= now`.
  2. Quand une lecture rencontre une annonce échue, elle la retire du cache et l'ajoute à une liste `Annonces.AExpirer` ; la liste est écrite en base en une seule requête (`UPDATE ... SET statut='expiree' WHERE id IN (...)`) au plus une fois toutes les 60 s (au moment d'une lecture suivante, pas de minuteur).
  3. Au démarrage du script : `UPDATE pop_tablet_ent_annonces SET statut='expiree' WHERE statut='active' AND fin <= ?`.
- **Données** : `statut`.
- **Règles serveur** : aucune intervention client.
- **Textes et états** : « Terminée le {date} » dans la liste (`annonces.liste.terminee`).
- **Notifications** : aucune (option `Config.Annonces.PrevenirFin = false` : si `true`, l'auteur reçoit « Votre annonce « {titre} » est terminée. » `annonces.notif.fin` à la première lecture qui la fait expirer, s'il est en ligne).
- **Liens** : Navigateur, Annuaire.
- **Réglages** : `Config.Annonces.PrevenirFin = false`.
- **Journal admin** : non.
- **Performance** : aucun thread ; écritures groupées.
- **Cas limites** : personne ne lit pendant 3 jours → statut mis à jour à la lecture suivante ou au démarrage (sans effet visible : elle était déjà filtrée) ; annonce prolongée juste avant sa fin → `fin` mise à jour, pas d'expiration ; horloge serveur changée → on se base toujours sur `os.time()`.
- **Critères d'acceptation** :
  - Étant donné une annonce de 1 h, quand 1 h est passée, alors elle n'apparaît plus sur le site à la lecture suivante.
  - Étant donné un redémarrage, alors toutes les annonces échues ont `statut = 'expiree'`.
  - Étant donné aucune lecture, alors aucun traitement ne tourne (vérifiable : 0 thread actif, resmon à 0,00 ms).

### [ENT-ANN-06] Annonce à toute la ville
- **But** : afficher un bandeau court sur toutes les tablettes de la ville, avec un délai minimum anti-spam.
- **Qui** : droit `annonce.ville` (Patron) ; admin.
- **Où** : Annonces > « Annonce à toute la ville ».
- **Parcours** :
  1. Formulaire : « Titre », « Message » (150 caractères max), pas d'image, aperçu du bandeau ; si payante : « Coût : {prix}, payé par le compte de l'entreprise. » ; indication du prochain envoi possible si le délai court encore (« Prochain envoi possible dans {minutes} min. », bouton grisé).
  2. RPC `annonces.ville` `{ titre, texte, actionId }`.
  3. Serveur : droit ; nettoyage ; longueurs ; délai entreprise (`now − derniere_ville[company] ≥ Config.AnnonceVille.DelaiEntreprise`) ; délai global (`now − derniere_ville_globale ≥ Config.AnnonceVille.DelaiGlobal`) ; si `Prix > 0` : `Bridge.Society.RemoveMoney(company, prix)` (mouvement `annonce_ville`) ou refus si fonds insuffisants.
  4. Insertion (`type = 'ville'`, `fin = now + Config.AnnonceVille.Duree`), cache `Annonces.Ville`, mémorise les deux horodatages.
  5. Envoi réseau `pop_tablet:client:cityBanner` à chaque joueur connecté qui a la tablette sur lui (une boucle sur la liste des joueurs au moment de l'envoi) → ENT-ANN-07.
  6. Bandeau succès pour l'émetteur.
- **Données** : `titre` 3–60 ; `texte` 10–150 ; `cout` = prix payé.
- **Règles serveur** : droit ; délai entreprise 30 min ; délai global 2 min (toutes entreprises confondues) ; prix ; `actionId` ; textes nettoyés ; police et EMS : mêmes règles (l'admin peut leur donner un délai plus court par `Config.AnnonceVille.DelaiParEntreprise = { police = 300, ambulance = 300 }`).
- **Textes et états** : titre « Annonce à toute la ville » (`annonces.ville.titre`) ; champs « Titre », « Message » (`annonces.champ.titre`, `annonces.ville.message`) ; coût (`annonces.ville.cout`) ; attente (`annonces.ville.attente`) ; bouton « Envoyer à toute la ville » (`annonces.ville.bouton`) ; succès « Annonce envoyée à toute la ville. » (`annonces.ville.ok`) ; erreurs « Une autre annonce vient d'être diffusée. Réessayez dans {secondes} s. » (`annonces.ville.delai_global`), `annonces.ville.attente`, `commun.erreur.fonds_entreprise`, `annonces.erreur.titre`, `annonces.erreur.texte`.
- **Notifications** : le bandeau lui-même (ENT-ANN-07).
- **Liens** : toutes les tablettes ; Compte (sortie si payante) ; Annuaire (bloc « Annonces de la ville » liste les annonces ville actives).
- **Réglages** : `Config.AnnonceVille.DelaiEntreprise = 1800` ; `Config.AnnonceVille.DelaiGlobal = 120` ; `Config.AnnonceVille.DelaiParEntreprise = {}` ; `Config.AnnonceVille.Prix = 0` ; `Config.AnnonceVille.Duree = 3600` (s, durée pendant laquelle les tablettes ouvertes plus tard la voient encore).
- **Journal admin** : oui : auteur, entreprise, titre, texte, coût.
- **Performance** : 1 insertion ; un envoi réseau par joueur porteur de tablette au moment de l'envoi ; horodatages en mémoire (au redémarrage : relus depuis la dernière annonce `ville` en base).
- **Cas limites** : deux patrons de deux entreprises envoient dans la même seconde → le premier passe, le second reçoit `delai_global` ; débit du compte réussi mais insertion échouée → remboursement et `commun.erreur.serveur` ; joueur qui ramasse la tablette après l'envoi → il voit l'annonce à l'ouverture tant qu'elle est active (ENT-ANN-07).
- **Critères d'acceptation** :
  - Étant donné un patron, quand il envoie une annonce ville, alors tous les joueurs connectés avec tablette voient le bandeau.
  - Étant donné une annonce envoyée il y a 10 min par la même entreprise, alors refus avec 20 min restantes.
  - Étant donné un chef (sans droit) qui appelle `annonces.ville` par console, alors refus `droit` et personne ne reçoit de bandeau.

### [ENT-ANN-07] Recevoir le bandeau « Annonce à toute la ville »
- **But** : afficher l'annonce ville de façon visible mais non gênante, une seule fois par joueur.
- **Qui** : tout joueur porteur de tablette.
- **Où** : haut de l'écran de la tablette (si ouverte) ; encart de notification de jeu (si fermée) ; Annuaire > « Annonces de la ville ».
- **Parcours** :
  1. Réception de `pop_tablet:client:cityBanner` `{ id, entreprise, titre, texte, fin }`.
  2. Tablette ouverte : bandeau en haut, fond de la couleur d'accent, « {entreprise} · {titre} » + texte, croix pour fermer, disparaît seul après 10 s (`Config.AnnonceVille.DureeBandeau = 10000`).
  3. Tablette fermée : encart de notification de jeu 5 s (« Annonce de {entreprise} : {titre} ») + ajout au centre de notifications.
  4. Le client garde en mémoire les `id` déjà vus (table Lua, pas de stockage disque) : une annonce n'est jamais montrée deux fois dans la même session.
  5. À l'ouverture de la tablette, le client reçoit avec ses données de démarrage la liste des annonces ville actives (cache serveur) et affiche celles qu'il n'a pas encore vues (au plus 1 bandeau, les autres vont au centre de notifications).
  6. Réglage joueur dans Apps perso > Réglages : « Bandeaux de la ville : Afficher / Centre de notifications seulement » (sauvegardé avec les préférences du joueur, défaut Afficher).
- **Données** : affiché : `entreprise` (libellé), `titre`, `texte`.
- **Règles serveur** : envoi uniquement aux porteurs de tablette ; textes déjà nettoyés ; le client affiche en texte brut.
- **Textes et états** : bandeau « {entreprise} · {titre} » (`annonces.bandeau.titre`) ; encart « Annonce de {entreprise} : {titre} » (`annonces.bandeau.encart`) ; réglage « Bandeaux de la ville » (`perso.reglages.bandeaux`), options « Afficher » / « Centre de notifications seulement » (`perso.reglages.bandeaux.*`).
- **Notifications** : voir parcours.
- **Liens** : Annuaire ; Apps perso (réglage).
- **Réglages** : `Config.AnnonceVille.DureeBandeau = 10000`.
- **Journal admin** : non.
- **Performance** : aucun thread : le minuteur de 10 s est un `setTimeout` de l'interface, seulement si la tablette est ouverte.
- **Cas limites** : 3 annonces reçues pendant que la tablette est fermée → à l'ouverture 1 bandeau (la plus récente) + 2 dans le centre de notifications ; annonce retirée par l'admin → événement `pop_tablet:client:cityBannerRemoved` (`id`) qui la retire de l'écran et du centre ; joueur qui se reconnecte → reçoit à l'ouverture les annonces encore actives (déjà vues avant la déconnexion : elles peuvent réapparaître une fois, mémoire perdue).
- **Critères d'acceptation** :
  - Étant donné une tablette ouverte, quand une annonce ville arrive, alors le bandeau s'affiche 10 s puis disparaît.
  - Étant donné une tablette ouverte 20 min après l'envoi (durée 60 min), alors le joueur voit l'annonce une fois.
  - Étant donné un client qui déclenche localement `pop_tablet:client:cityBanner` avec du HTML, alors le texte s'affiche en brut sans exécuter quoi que ce soit (et aucun autre joueur ne le reçoit).

---

## 4. Demandes (app « Demandes »)

**Une seule boîte « Demandes » par entreprise** (`demandes.titre` : « Demandes ») qui reçoit les quatre types : dépannage, rendez-vous, devis, contact. Visible des employés ayant `demandes.repondre` ou `demandes.assigner`.

Statuts : `nouvelle` (« Nouvelle »), `acceptee` (« En cours »), `refusee` (« Refusée »), `cloturee` (« Terminée »), `annulee` (« Annulée par le demandeur »).

Table `pop_tablet_ent_demandes` :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `id` | INT AUTO_INCREMENT | Oui | — | — |
| `numero` | VARCHAR(12) UNIQUE | Oui | `D-000123` | — |
| `uid` | CHAR(36) UNIQUE | Oui | `actionId` d'envoi | — |
| `company_id` | INT | Oui | `pop_tablet_companies.id` | — |
| `type` | ENUM(`depannage`,`rendez_vous`,`devis`,`contact`) | Oui | type accepté par l'entreprise | — |
| `source` | ENUM(`site`,`annuaire`,`api`) | Oui | — | — |
| `demandeur` | VARCHAR(60) | Oui | identifiant | — |
| `demandeur_nom` | VARCHAR(100) | Oui | — | — |
| `contact` | VARCHAR(40) | Non | numéro ou moyen de contact libre, nettoyé | NULL |
| `message` | VARCHAR(500) | Oui | 10 à 500, nettoyé | — |
| `pos_x`, `pos_y`, `pos_z` | FLOAT | Non | lues par le serveur | NULL |
| `lieu` | VARCHAR(100) | Non | nom de rue calculé côté client (affichage seulement) | NULL |
| `date_souhaitee` | INT UNSIGNED | Non | rendez-vous : entre maintenant + 15 min et + 30 jours | NULL |
| `statut` | ENUM(`nouvelle`,`acceptee`,`refusee`,`cloturee`,`annulee`) | Oui | — | `nouvelle` |
| `assigne_a` / `assigne_nom` / `assigne_par` | VARCHAR(60) / VARCHAR(100) / VARCHAR(60) | Non | — | NULL |
| `pris_par` / `pris_par_nom` | VARCHAR(60) / VARCHAR(100) | Non | — | NULL |
| `motif_refus` | VARCHAR(200) | Non | — | NULL |
| `note_cloture` | VARCHAR(200) | Non | — | NULL |
| `facture_numero` | VARCHAR(12) | Non | facture liée | NULL |
| `cree_le`, `pris_le`, `refuse_le`, `cloture_le`, `annule_le` | INT UNSIGNED | — | — | NULL sauf `cree_le` |

Index (`company`, `statut`, `cree_le`), (`demandeur`, `cree_le`), (`assigne_a`). Jamais supprimée ; au-delà de `Config.Demandes.ArchiveJours = 30` jours, les demandes terminées/refusées/annulées ne sont plus listées (filtre `cree_le`), mais restent en base pour l'admin.

### [ENT-DEM-01] Boîte de demandes : liste et filtres
- **But** : voir toutes les demandes reçues par l'entreprise, les nouvelles en premier.
- **Qui** : `demandes.repondre` (Membre, Chef, Patron) ou `demandes.assigner` ; lecture possible hors service, actions seulement en service si `Config.Demandes.ServiceRequis = true`.
- **Où** : Demandes > écran d'accueil ; pastille sur l'icône = nombre de demandes `nouvelle`.
- **Parcours** :
  1. RPC `demandes.liste` `{ statut, type, assigne, page }` (défaut : statut « À traiter » = `nouvelle` + `acceptee`, type « Tous », assigné « Tous »).
  2. Serveur : lit 20 demandes de l'entreprise, tri : `nouvelle` d'abord (plus anciennes en premier, pour traiter dans l'ordre), puis `acceptee`, puis le reste par date décroissante ; renvoie aussi les compteurs par statut.
  3. Écran : onglets « À traiter ({n}) », « Mes demandes » (assignées à moi ou prises par moi), « Terminées », « Toutes » ; filtres « Type » (Tous, Dépannage, Rendez-vous, Devis, Contact) et « Assigné à » (Tous, Personne, liste des employés) ; lignes : icône du type, numéro, nom du demandeur, début du message (60 caractères), « il y a {durée} », statut, assigné, pastille « GPS » si position.
  4. Clic → détail (ENT-DEM-02).
  5. Bouton « Actualiser » ; la liste se met aussi à jour quand une notification de nouvelle demande arrive alors que l'écran est ouvert (rechargement de la page 1).
- **Données** (affichées) : `numero`, `type`, `demandeur_nom`, `message` (extrait), `cree_le`, `statut`, `assigne_nom`, `pris_par_nom`, présence de position.
- **Règles serveur** : droit ; même entreprise ; pagination 20 ; filtres dans les listes autorisées (sinon défaut) ; fréquence 1/s.
- **Textes et états** : onglets « À traiter », « Mes demandes », « Terminées », « Toutes » (`demandes.liste.onglet.*`) ; filtres « Type », « Assigné à », « Personne » (`demandes.filtre.*`) ; types « Dépannage », « Rendez-vous », « Devis », « Contact » (`demandes.type.*`) ; statuts (`demandes.statut.*`) ; « il y a {durée} » (`commun.il_y_a`) ; vide : « Aucune demande à traiter. Les demandes envoyées depuis votre site et l'annuaire arriveront ici. » (`demandes.liste.vide`) ; hors service : la liste s'affiche, un bandeau en haut « Prenez votre service pour répondre aux demandes. » + bouton « Prendre mon service » (`demandes.liste.hors_service`) ; pas le droit : app cachée.
- **Notifications** : voir ENT-DEM-03 (arrivée).
- **Liens** : Site / Annuaire (sources), Dispatch (les demandes de type `depannage` peuvent aussi apparaître dans le dispatch des entreprises qui l'utilisent, via l'événement `pop_tablet:requestCreated`).
- **Réglages** : `Config.Demandes.ServiceRequis = true` ; `Config.Demandes.ArchiveJours = 30`.
- **Journal admin** : non.
- **Performance** : requête indexée paginée ; compteur de la pastille envoyé à l'ouverture de la tablette (1 `COUNT` indexé) puis mis à jour par les notifications.
- **Cas limites** : 200 demandes nouvelles → pagination, les plus anciennes d'abord ; employé sans `demandes.repondre` mais avec `demandes.assigner` → voit la liste et peut assigner, pas accepter ; filtre sur un employé viré → liste vide.
- **Critères d'acceptation** :
  - Étant donné 3 demandes nouvelles et 2 en cours, alors « À traiter (5) » et les nouvelles s'affichent avant les en cours.
  - Étant donné le filtre « Dépannage », alors seules les demandes de ce type apparaissent.
  - Étant donné une recrue (sans droit) qui appelle `demandes.liste` par console, alors refus `droit`.

### [ENT-DEM-02] Détail d'une demande
- **But** : lire une demande en entier et accéder aux actions possibles.
- **Qui** : comme ENT-DEM-01.
- **Où** : Demandes > liste > clic sur une demande.
- **Parcours** :
  1. RPC `demandes.detail` `{ numero }`.
  2. Écran : type, numéro, statut, demandeur (nom), contact s'il est donné, message complet, lieu (« Près de {lieu} ») et bouton « GPS » si position, date souhaitée (rendez-vous), source (« Envoyée depuis votre site » / « depuis l'annuaire »), assignation (« Assignée à {nom} par {nom} »), prise en charge (« Prise par {nom} le {date} »), refus/clôture avec motif ou note, facture liée (lien vers ENT-FAC-10).
  3. Boutons selon statut et droits : `nouvelle` → « Accepter », « Refuser », « Assigner » ; `acceptee` → « GPS », « Clôturer », « Facturer », « Assigner » (réassigner) ; statuts finaux → aucun bouton.
- **Données** : toutes les colonnes de `pop_tablet_ent_demandes` sauf `uid` et identifiants (seuls les noms sont affichés).
- **Règles serveur** : droit ; même entreprise ; fréquence 1/s.
- **Textes et états** : « Près de {lieu} » (`demandes.detail.lieu`) ; « Rendez-vous souhaité : {date} » (`demandes.detail.date`) ; « Envoyée depuis votre site » / « Envoyée depuis l'annuaire » (`demandes.detail.source.*`) ; « Assignée à {nom} par {nom} » (`demandes.detail.assignee`) ; « Prise par {nom} le {date} » (`demandes.detail.prise`) ; « Contact : {contact} » (`demandes.detail.contact`) ; « Facture liée : {numero} » (`demandes.detail.facture`) ; introuvable : « Demande introuvable. » (`demandes.detail.introuvable`) ; hors service : boutons d'action grisés avec `commun.erreur.hors_service`.
- **Notifications** : aucune.
- **Liens** : ENT-DEM-04 à 07 ; Factures.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : 1 requête par clé unique.
- **Cas limites** : demande annulée par le demandeur pendant la lecture → au clic sur une action : « Le demandeur a annulé cette demande. » (`demandes.erreur.annulee`) ; demande sans position → pas de bouton GPS ; demande d'une autre entreprise par console → `introuvable`.
- **Critères d'acceptation** :
  - Étant donné une demande de dépannage avec position, alors le bouton « GPS » est visible.
  - Étant donné une demande clôturée, alors aucun bouton d'action n'est affiché.
  - Étant donné un numéro d'une autre entreprise envoyé par console, alors `introuvable` sans aucune donnée.

### [ENT-DEM-03] Envoyer une demande (formulaire du site et de l'annuaire)
- **But** : permettre à n'importe quel joueur d'envoyer une demande à une entreprise depuis son site ou sa fiche annuaire.
- **Qui** : tout porteur de tablette (y compris employés d'autres entreprises et sans emploi) ; pas d'envoi à sa propre entreprise.
- **Où** : Navigateur > site d'une entreprise > bloc « Nous contacter » ; Annuaire > fiche entreprise > « Envoyer une demande ».
- **Parcours** :
  1. Formulaire : « Type de demande » (seulement les types acceptés par l'entreprise, ENT-DEM-09) ; « Message » ; « Contact (facultatif) » avec l'aide « Votre numéro de téléphone, par exemple » ; case « Partager ma position » (cochée par défaut et obligatoire pour « Dépannage ») ; « Date et heure souhaitées » (seulement pour « Rendez-vous », sélecteur date + heure par pas de 15 min). En haut, l'état de l'entreprise : « Ouverte » ou « Fermée : votre demande sera traitée à la réouverture. ».
  2. Bouton « Envoyer ». Si « Partager ma position » est coché, le client joint le nom de rue (`GetStreetNameAtCoord`) pour l'affichage.
  3. RPC `demandes.envoyer` `{ company, type, message, contact, partagerPosition, lieu, dateSouhaitee, source, actionId }`.
  4. Serveur : entreprise existante, boîte ouverte, type accepté ; demandeur ≠ employé de cette entreprise ; textes nettoyés et bornés ; date dans les bornes ; limites anti-spam ; si position : coordonnées lues **côté serveur** (`GetEntityCoords(GetPlayerPed(source))`), `lieu` client gardé pour l'affichage uniquement (40 caractères max, nettoyé).
  5. Insertion (`uid = actionId`, `numero = 'D-' .. id sur 6 chiffres`) ; événement serveur `pop_tablet:requestCreated` (`company, numero, type`).
  6. Notification aux employés concernés (voir Notifications) ; pastille mise à jour.
  7. Demandeur : bandeau « Demande {numero} envoyée à {entreprise}. » + lien « Suivre ma demande » (ENT-DEM-08).
- **Données** : voir table ; `source` ∈ {`site`,`annuaire`}.
- **Règles serveur** :
  - Fréquence : 1 demande toutes les 5 min par demandeur et par entreprise (`Config.Demandes.DelaiParEntreprise = 300`) ; 5 demandes par 10 min tous destinataires confondus (`Config.Demandes.MaxGlobal = 5`, fenêtre `Config.Demandes.FenetreGlobal = 600`).
  - 3 demandes ouvertes (`nouvelle` ou `acceptee`) max par demandeur et par entreprise (`Config.Demandes.OuvertesMax = 3`).
  - Position obligatoire pour `depannage`.
  - Date souhaitée obligatoire pour `rendez_vous`, entre now + 15 min et now + 30 jours.
  - `uid` unique (anti double clic).
- **Textes et états** :
  - Titre « Envoyer une demande à {entreprise} » (`demandes.form.titre`) ; « Type de demande » (`demandes.form.type`) ; « Message » (`demandes.form.message`) ; « Contact (facultatif) » (`demandes.form.contact`) + aide (`demandes.form.contact_aide`) ; « Partager ma position » (`demandes.form.position`) ; « Date et heure souhaitées » (`demandes.form.date`) ; « Envoyer » (`demandes.form.envoyer`) ; « Ouverte » / « Fermée : votre demande sera traitée à la réouverture. » (`demandes.form.ouverte`, `demandes.form.fermee`).
  - Succès : « Demande {numero} envoyée à {entreprise}. » (`demandes.form.ok`) + « Suivre ma demande » (`demandes.form.suivre`).
  - Erreurs : « Message : 10 à 500 caractères. » (`demandes.erreur.message`) ; « La position est nécessaire pour un dépannage. » (`demandes.erreur.position`) ; « Choisissez une date entre dans 15 minutes et dans 30 jours. » (`demandes.erreur.date`) ; « Vous avez déjà envoyé une demande à {entreprise} il y a peu. Réessayez dans {minutes} min. » (`demandes.erreur.delai`) ; « Vous avez déjà {n} demandes en cours chez {entreprise}. » (`demandes.erreur.ouvertes`) ; « Cette entreprise ne reçoit pas de demandes pour le moment. » (`demandes.erreur.boite_fermee`) ; « Ce type de demande n'est pas proposé. » (`demandes.erreur.type`) ; « Vous ne pouvez pas écrire à votre propre entreprise. » (`demandes.erreur.propre`) ; « Trop de demandes envoyées. Patientez quelques minutes. » (`demandes.erreur.global`).
- **Notifications** : employés de l'entreprise **en service**, avec tablette et `demandes.repondre` : « Nouvelle demande ({type}) de {demandeur}. » (`demandes.notif.nouvelle`), clic → détail. Si personne n'est en service : aucune notification ; à la prochaine prise de service d'un employé ayant le droit, il reçoit une seule notification « {n} demandes en attente. » (`demandes.notif.attente`).
- **Liens** : Navigateur (site), Annuaire, Dispatch (événement `pop_tablet:requestCreated`), Service (notification à la prise de service).
- **Réglages** : `Config.Demandes.DelaiParEntreprise = 300` ; `Config.Demandes.MaxGlobal = 5` ; `Config.Demandes.FenetreGlobal = 600` ; `Config.Demandes.OuvertesMax = 3` ; `Config.Demandes.RdvMinMinutes = 15` ; `Config.Demandes.RdvMaxJours = 30`.
- **Journal admin** : non (la table est l'historique).
- **Performance** : 1 insertion ; notifications seulement aux employés en service (liste mémoire `Service.Actifs` filtrée par entreprise) ; formulaire chargé seulement à l'ouverture.
- **Cas limites** : entreprise fermée → demande acceptée avec message « Fermée » ; double clic → une demande ; demandeur qui envoie depuis l'intérieur d'un intérieur instancié → position enregistrée telle quelle (le GPS mènera à l'entrée la plus proche fixée par le jeu) ; type `depannage` sans position par console → refus `position`.
- **Critères d'acceptation** :
  - Étant donné un joueur qui envoie un dépannage, alors la demande est créée avec les coordonnées lues par le serveur et les employés en service avec droit reçoivent la notification.
  - Étant donné une deuxième demande à la même entreprise 2 min après, alors refus `delai` avec 3 min restantes.
  - Étant donné un client qui envoie par console des coordonnées falsifiées dans les données, alors elles sont ignorées (seules celles lues par le serveur comptent).

### [ENT-DEM-04] Accepter une demande et lancer le GPS
- **But** : prendre en charge une demande, prévenir le demandeur et poser le point GPS sur sa position.
- **Qui** : `demandes.repondre`, en service si `ServiceRequis` ; si la demande est assignée à quelqu'un, seuls l'assigné et les détenteurs de `demandes.assigner` peuvent l'accepter.
- **Où** : Demandes > détail > « Accepter » ; aussi bouton « Accepter » dans la notification de nouvelle demande. Bouton « GPS » sur une demande `acceptee`.
- **Parcours** :
  1. RPC `demandes.accepter` `{ numero, actionId }`.
  2. Serveur : droit, service, même entreprise ; `UPDATE ... SET statut='acceptee', pris_par=?, pris_par_nom=?, pris_le=?, assigne_a=COALESCE(assigne_a, ?) WHERE id=? AND statut='nouvelle'` ; 0 ligne modifiée → déjà prise.
  3. Réponse avec les coordonnées si présentes → le client pose le point GPS (`SetNewWaypoint(x, y)`) et affiche « Point GPS posé. ».
  4. Notification au demandeur ; les autres employés voient la demande « En cours » au prochain chargement.
  5. Bouton « GPS » (demande `acceptee`) : RPC `demandes.gps` `{ numero }` → le serveur renvoie les coordonnées si l'appelant a le droit → point GPS reposé.
- **Données** : `statut`, `pris_par`, `pris_par_nom`, `pris_le`, `assigne_a`.
- **Règles serveur** : une demande ne peut être prise qu'une fois (condition SQL) ; droit et service ; fréquence 1/s ; les coordonnées ne sont envoyées qu'aux employés autorisés de l'entreprise.
- **Textes et états** : bouton « Accepter » (`demandes.accepter.bouton`) ; « GPS » (`demandes.gps.bouton`) ; succès « Demande acceptée. Point GPS posé. » (`demandes.accepter.ok_gps`) ou « Demande acceptée. » (`demandes.accepter.ok`) sans position ; « Point GPS posé. » (`demandes.gps.ok`) ; erreurs « {nom} a déjà pris cette demande. » (`demandes.erreur.deja_prise`), « Cette demande est assignée à {nom}. » (`demandes.erreur.assignee_autre`), `demandes.erreur.annulee`, `commun.erreur.hors_service`.
- **Notifications** : demandeur (en ligne, tablette ; sinon encart de jeu même sans tablette, car il attend une réponse) : « {entreprise} a accepté votre demande {numero}. {nom} s'en occupe. » (`demandes.notif.acceptee`).
- **Liens** : Dispatch (la demande passe « attribuée » si elle y figure) ; Planning (rendez-vous : bouton « Ajouter au planning » visible sur une demande `rendez_vous` acceptée, crée un créneau à `date_souhaitee` si l'app Planning est installée).
- **Réglages** : aucun propre.
- **Journal admin** : non.
- **Performance** : 1 mise à jour conditionnelle.
- **Cas limites** : deux employés acceptent en même temps → un seul réussit, l'autre reçoit `deja_prise` ; demandeur déconnecté → acceptation possible, notification perdue, statut visible dans « Mes demandes » à sa reconnexion ; demande sans position → pas de GPS, succès `ok`.
- **Critères d'acceptation** :
  - Étant donné une demande de dépannage nouvelle, quand un employé en service l'accepte, alors son point GPS est posé sur la position enregistrée et le demandeur est prévenu.
  - Étant donné deux acceptations simultanées, alors une seule réussit.
  - Étant donné un employé hors service avec `ServiceRequis = true` qui appelle `demandes.accepter` par console, alors refus `service`.

### [ENT-DEM-05] Assigner une demande à un employé
- **But** : confier une demande à un employé précis.
- **Qui** : `demandes.assigner` (Chef, Patron) ; admin.
- **Où** : Demandes > détail > « Assigner ».
- **Parcours** :
  1. Liste des employés ayant `demandes.repondre`, en service en premier (pastille « En service »), puis connectés, puis absents ; option « Personne » pour retirer l'assignation.
  2. RPC `demandes.assigner` `{ numero, identifier | nil }`.
  3. Serveur : droit ; demande `nouvelle` ou `acceptee` ; cible membre de l'entreprise avec `demandes.repondre` ; met `assigne_a`, `assigne_nom`, `assigne_par`. Si la demande était `acceptee` par quelqu'un d'autre, `pris_par` devient la cible (réassignation) et le statut reste `acceptee`.
  4. Notification à l'assigné ; bandeau.
- **Données** : `assigne_a`, `assigne_nom`, `assigne_par`.
- **Règles serveur** : droit ; cible valide ; statut non final ; fréquence 1/s.
- **Textes et états** : bouton « Assigner » (`demandes.assigner.bouton`) ; titre « Assigner la demande {numero} » (`demandes.assigner.titre`) ; « Personne » (`demandes.filtre.personne`) ; succès « Demande assignée à {nom}. » (`demandes.assigner.ok`) / « Assignation retirée. » (`demandes.assigner.retiree`) ; erreurs « Cet employé ne peut pas répondre aux demandes. » (`demandes.erreur.cible_droit`), `gestion.fiche.plus_membre`, « Cette demande est terminée. » (`demandes.erreur.terminee`).
- **Notifications** : assigné (en ligne, tablette) : « {nom} vous a assigné la demande {numero} ({type}). » (`demandes.notif.assignee`) ; ancien preneur en cas de réassignation : « La demande {numero} a été confiée à {nom}. » (`demandes.notif.reassignee`).
- **Liens** : ENT-GES-11 (désassignation automatique si l'assigné est viré).
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : 1 mise à jour ; liste des employés : 1 requête sur `users` limitée à l'entreprise (même code que ENT-GES-05, sans les heures).
- **Cas limites** : assigné absent → assignation possible, il la verra dans « Mes demandes » ; assigné qui perd le droit ensuite → la demande reste assignée, un responsable peut réassigner ; double clic → une seule mise à jour.
- **Critères d'acceptation** :
  - Étant donné une demande nouvelle, quand le chef l'assigne à un membre, alors le membre reçoit la notification et la voit dans « Mes demandes ».
  - Étant donné une recrue sans `demandes.repondre`, alors elle n'apparaît pas dans la liste et un envoi console vers elle est refusé `cible_droit`.
  - Étant donné un membre (sans `demandes.assigner`) qui appelle le RPC par console, alors refus `droit`.

### [ENT-DEM-06] Refuser une demande
- **But** : décliner une demande, avec une raison communiquée au demandeur.
- **Qui** : `demandes.repondre`, en service si `ServiceRequis`.
- **Où** : Demandes > détail > « Refuser » (statut `nouvelle` seulement).
- **Parcours** : 1. Fenêtre « Refuser la demande {numero} ? » + « Raison » (facultative) avec 3 raisons rapides cliquables : « Nous ne faisons pas ce service. », « Pas disponible pour le moment. », « Merci de nous recontacter plus tard. » (`demandes.refuser.rapide.*`). 2. RPC `demandes.refuser` `{ numero, motif, actionId }`. 3. Serveur : `UPDATE ... SET statut='refusee', motif_refus=?, refuse_le=? WHERE id=? AND statut='nouvelle'`. 4. Notification au demandeur.
- **Données** : `motif_refus` 200 caractères max, nettoyé.
- **Règles serveur** : droit ; service ; statut `nouvelle` ; fréquence 1/s.
- **Textes et états** : bouton « Refuser » (`demandes.refuser.bouton`) ; titre (`demandes.refuser.titre`) ; champ « Raison (facultatif) » (`demandes.refuser.raison`) ; succès « Demande refusée. » (`demandes.refuser.ok`) ; erreurs `demandes.erreur.deja_prise`, `demandes.erreur.annulee`.
- **Notifications** : demandeur : « {entreprise} a refusé votre demande {numero}. » + « Raison : {motif} » (`demandes.notif.refusee`).
- **Liens** : Dispatch (retirée si présente).
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : 1 mise à jour.
- **Cas limites** : refus et acceptation simultanés → le premier gagne ; demande déjà acceptée → bouton caché (on clôture à la place) ; raison avec HTML → nettoyée.
- **Critères d'acceptation** :
  - Étant donné une demande nouvelle, quand un employé la refuse avec une raison rapide, alors le demandeur reçoit cette raison.
  - Étant donné une demande acceptée, alors « Refuser » n'apparaît pas.
  - Étant donné une recrue sans droit qui appelle `demandes.refuser` par console, alors refus `droit`.

### [ENT-DEM-07] Clôturer une demande
- **But** : marquer une demande en cours comme terminée, avec une note et éventuellement une facture.
- **Qui** : celui qui l'a prise (`pris_par`) ou `demandes.assigner` ; en service si `ServiceRequis`.
- **Où** : Demandes > détail > « Clôturer » (statut `acceptee`) ; bouton « Facturer » à côté.
- **Parcours** :
  1. « Facturer » : ouvre Factures > Nouvelle facture avec le client prérempli par identifiant (type `nom`) et un lien vers la demande ; à l'envoi de la facture, le serveur écrit `facture_numero` sur la demande (le RPC `factures.creer` accepte `demande = numero` en plus, vérifié : même entreprise, demande `acceptee`).
  2. « Clôturer » : fenêtre « Clôturer la demande {numero} » + « Note (facultative) ».
  3. RPC `demandes.cloturer` `{ numero, note, actionId }`.
  4. Serveur : `UPDATE ... SET statut='cloturee', note_cloture=?, cloture_le=? WHERE id=? AND statut='acceptee'` ; événement `pop_tablet:requestClosed` (pour le dispatch).
  5. Notification au demandeur ; retour à la liste.
- **Données** : `note_cloture` 200 caractères max (interne, **non** montrée au demandeur) ; `facture_numero`.
- **Règles serveur** : statut `acceptee` ; preneur ou `demandes.assigner` ; service ; fréquence 1/s.
- **Textes et états** : bouton « Clôturer » (`demandes.cloturer.bouton`) ; « Facturer » (`demandes.cloturer.facturer`) ; titre (`demandes.cloturer.titre`) ; champ « Note interne (facultatif) » (`demandes.cloturer.note`) ; succès « Demande terminée. » (`demandes.cloturer.ok`) ; erreurs « Seul {nom} ou un responsable peut clôturer cette demande. » (`demandes.erreur.pas_preneur`), `demandes.erreur.terminee`.
- **Notifications** : demandeur : « Votre demande {numero} chez {entreprise} est terminée. » (`demandes.notif.cloturee`).
- **Liens** : Factures (préremplissage et lien), Dispatch.
- **Réglages** : `Config.Demandes.ClotureAuto = false` (si `true`, une demande liée à une facture payée se clôture automatiquement à l'écoute de `pop_tablet:invoicePaid`).
- **Journal admin** : non.
- **Performance** : 1 mise à jour.
- **Cas limites** : facture faite mais demande non clôturée → la demande garde le lien ; preneur viré → un responsable clôture ; double clic → une clôture.
- **Critères d'acceptation** :
  - Étant donné une demande prise par A, quand A la clôture, alors le statut est `cloturee` et le demandeur est prévenu.
  - Étant donné « Facturer » puis l'envoi de la facture, alors la demande affiche « Facture liée : F-… ».
  - Étant donné un membre B (pas preneur, sans `demandes.assigner`) qui appelle `demandes.cloturer` par console, alors refus `pas_preneur`.

### [ENT-DEM-08] Suivre et annuler ses demandes envoyées (ajout)
- **But** : permettre au demandeur de voir où en sont ses demandes et d'annuler celles devenues inutiles.
- **Qui** : tout porteur de tablette, pour ses propres demandes.
- **Où** : Annuaire > « Mes demandes » ; lien « Suivre ma demande » après envoi ; clic sur les notifications de réponse.
- **Parcours** :
  1. RPC `demandes.mes` `{ page }` → demandes `WHERE demandeur = ?` des 30 derniers jours, 20 par page, tri date décroissante.
  2. Ligne : entreprise, type, numéro, date, statut (« Envoyée », « Acceptée par {entreprise} », « Refusée », « Terminée », « Annulée »), raison du refus si présente.
  3. Bouton « Annuler ma demande » sur les statuts `nouvelle` et `acceptee` → confirmation → RPC `demandes.annuler` `{ numero, actionId }` → serveur : `demandeur = appelant`, `UPDATE ... SET statut='annulee', annule_le=? WHERE id=? AND statut IN ('nouvelle','acceptee')`.
  4. Si la demande était acceptée : le preneur est prévenu.
- **Données** : affichées : `company` (libellé), `type`, `numero`, `cree_le`, `statut`, `motif_refus`. Jamais : `note_cloture`, noms internes autres que le preneur.
- **Règles serveur** : uniquement ses demandes ; fréquence 1/s.
- **Textes et états** : titre « Mes demandes » (`demandes.mes.titre`) ; statuts côté demandeur « Envoyée », « Acceptée par {entreprise} », « Refusée », « Terminée », « Annulée » (`demandes.mes.statut.*`) ; bouton « Annuler ma demande » (`demandes.mes.annuler`) ; confirmation « Annuler la demande {numero} ? » (`demandes.mes.annuler_confirm`) ; succès « Demande annulée. » (`demandes.mes.annulee_ok`) ; vide : « Vous n'avez envoyé aucune demande. Trouvez une entreprise dans l'annuaire. » + bouton « Ouvrir l'annuaire » (`demandes.mes.vide`) ; erreur `demandes.erreur.terminee`.
- **Notifications** : preneur (si `acceptee`) : « {demandeur} a annulé la demande {numero}. » (`demandes.notif.annulee`).
- **Liens** : Annuaire ; Dispatch (retrait si présente, via `pop_tablet:requestClosed`).
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : requête indexée (`demandeur`, `cree_le`), paginée.
- **Cas limites** : demande clôturée pendant l'annulation → `terminee` ; double clic → une seule annulation ; demande annulée ne compte plus dans la limite `OuvertesMax`.
- **Critères d'acceptation** :
  - Étant donné 2 demandes envoyées, alors « Mes demandes » en affiche 2 avec leur statut.
  - Étant donné une demande acceptée annulée par le demandeur, alors le preneur reçoit la notification et la demande passe « Annulée ».
  - Étant donné un joueur qui annule par console la demande d'un autre, alors refus et rien ne change.

### [ENT-DEM-09] Réglages de la boîte de demandes (ajout)
- **But** : laisser le patron choisir quels types de demandes son entreprise accepte, ou fermer la boîte.
- **Qui** : droit `grades.gerer` (Patron) ; admin.
- **Où** : Demandes > icône engrenage « Réglages ».
- **Parcours** : 1. Interrupteur « Recevoir des demandes » (défaut activé) et cases « Dépannage », « Rendez-vous », « Devis », « Contact » (défaut : types de `Config.Entreprises.Liste[company].Demandes`, sinon les 4). 2. RPC `demandes.reglages` `{ ouverte, types }`. 3. Serveur : au moins un type si ouverte ; écrit `pop_tablet_ent_reglages` (`demandes.ouverte`, `demandes.types` = liste séparée par des virgules) ; cache mis à jour ; événement `pop_tablet:announcementChanged` (le site et l'annuaire mettent à jour le formulaire).
- **Données** : `demandes.ouverte` 0/1 ; `demandes.types` sous-ensemble de {`depannage`,`rendez_vous`,`devis`,`contact`}.
- **Règles serveur** : droit ; types valides ; au moins 1 type si ouverte ; fréquence 1 toutes les 5 s ; les demandes déjà reçues ne sont pas touchées.
- **Textes et états** : titre « Réglages des demandes » (`demandes.reglages.titre`) ; « Recevoir des demandes » (`demandes.reglages.ouverte`) ; succès « Réglages enregistrés. » (`demandes.reglages.ok`) ; erreur « Choisissez au moins un type de demande. » (`demandes.reglages.aucun_type`) ; info boîte fermée : « Le formulaire est masqué sur votre site et dans l'annuaire. » (`demandes.reglages.fermee_info`).
- **Notifications** : aucune.
- **Liens** : Navigateur, Annuaire (formulaire masqué si fermée, types filtrés).
- **Réglages** : `Config.Entreprises.Liste[company].Demandes = { 'depannage', 'rendez_vous', 'devis', 'contact' }`.
- **Journal admin** : oui : avant/après.
- **Performance** : cache mémoire.
- **Cas limites** : boîte fermée pendant qu'un visiteur remplit le formulaire → envoi refusé `demandes.erreur.boite_fermee` ; aucun type coché avec boîte ouverte → refus ; police/EMS : peuvent garder seulement « Contact » et « Rendez-vous ».
- **Critères d'acceptation** :
  - Étant donné « Dépannage » décoché, alors le formulaire du site ne le propose plus et un envoi console de ce type est refusé `type`.
  - Étant donné la boîte fermée, alors le bouton « Envoyer une demande » disparaît de l'annuaire.
  - Étant donné un chef qui appelle `demandes.reglages` par console, alors refus `droit`.

---

## Décisions prises par défaut

1. **Prise de service gérée par la tablette, sans toucher au métier** (ESX, QBCore ou Qbox) : on ne bascule pas vers un métier « off » et on ne bloque pas la paie hors service (le framework verse toujours les salaires, jamais la tablette) ; seul l'indicateur de service du framework est synchronisé (`Config.Duty.SyncFrameworkDuty = true` : QBCore / Qbox `job.onduty`, ESX Legacy `onDuty`) pour que les autres scripts voient qui est en service. Crash serveur = service fermé à 0 min (« Interrompu »).
2. **Niveaux Recrue/Membre/Chef/Patron calculés sur l'ordre des grades** (moitié basse des intermédiaires = Membre, moitié haute = Chef) ; le Patron a toujours tout ; un patron ne peut ni rétrograder ni virer un autre patron (admin seulement) ; plusieurs patrons autorisés ; le dernier patron ne peut pas démissionner.
3. **Créer ou supprimer un grade au milieu est autorisé (confirmé par le client)** : les grades sont renumérotés (ESX `job_grades` / `users`, QBCore `players.job`, Qbox `player_groups`, et les droits) ; avant validation, un avertissement s'affiche : « Les numéros des grades situés au-dessus vont changer. Les scripts qui utilisent ces numéros peuvent être affectés. » (`gestion.grades.avertissement_renumerotation`) et le bouton devient « Créer quand même » ; libellés uniques ; max 15 grades ; salaire max 5 000 $.
4. **Factures** : part employé figée à la création (défaut 10 %, max 50 %), calculée sur le sous-total (la majoration reste à l'entreprise) et versée directement en banque à l'auteur s'il est encore membre ; paiement en liquide seulement si un employé en service est à 3 m ; facture payée non annulable (remboursement par Retirer/Prime) ; facture refusée = définitive, jamais transmise automatiquement à la police.
5. **Impayés traités « à la lecture »**, sans minuteur (ouverture des listes, connexion, paiement, démarrage) ; mode par défaut « Rien », délai 72 h, majoration unique 10 % ; transmission police = option, la police reçoit aussi ses propres amendes impayées.
6. **Le client voit ses factures dans l'onglet « Reçues » de l'app Factures** (visible par tout porteur de tablette, même sans emploi) ; le demandeur suit ses demandes dans **Annuaire > Mes demandes**.
7. **Banque** : le compte d'entreprise est le compte société du framework détecté : ESX `esx_addonaccount` / `esx_society`, QBCore `qb-banking` (v2) sinon `qb-management`, Qbox `Renewed-Banking` sinon `qb-banking`. `pop_bank` n'expose aucun export (agences et chèques seulement) : aucun branchement, aucun export supposé. Un adaptateur banque optionnel, non fourni, peut être écrit dans `bridge/bank/custom.lua` (ENT-GES-23).
8. **Annonce à toute la ville** : 30 min entre deux envois d'une même entreprise, 2 min entre deux envois de toute la ville, gratuite par défaut (prix réglable payé par le compte), visible 1 h pour les tablettes ouvertes plus tard ; max 5 annonces d'entreprise actives, durées 1 h à 7 jours.
9. **Demandes** : position obligatoire et lue par le serveur pour un dépannage ; 1 demande / 5 min par entreprise et 3 ouvertes max par demandeur ; notifications seulement aux employés en service ; note de clôture interne non montrée au demandeur.
10. **Droits ajoutés** au tableau du contexte : `facture.voir_toutes`, `facture.regler`, `demandes.assigner`, `compte.prime`, `ventes.voir`, `employes.voir` (valeurs par défaut au tableau 0.2).


> **Relecture croisée (24/11/2026)** : ce fichier a été aligné sur les 5 autres. Les noms communs (signaux, tables, réglages, droits, textes d'erreur, constantes) sont listés dans `00-sommaire.md`, qui fait foi en cas de doute.
