# POP Tablet : fiches 05 : créateur d'entreprises, éditeur de site, admin serveur, apps perso

Fichier rédigé selon `_modele.md` et `_contexte.md`. Préfixes : `SITE-CRE-` (créateur d'entreprises), `SITE-EDI-` (éditeur de site), `ADM-` (admin serveur), `PERSO-` (apps perso / Claude friendly). Les fiches marquées « (ajout) » ne figuraient pas dans la demande mais sont indispensables.

---

## 0. Conventions communes à ce fichier (s'appliquent à toutes les fiches ci-dessous)

### 0.1 Appels client → serveur
- Tous les appels passent par la porte d'entrée unique de la base : callback `pop_tablet:request` (`Callback.*`, fiche 01 §0). Dans ce fichier, `pop_tablet:<domaine>:<action>` (ex. `pop_tablet:sites:addBlock`) désigne l'app `<domaine>` et l'action `<action>` passées par ce callback, pas un événement séparé.
- Réponse toujours au format `{ ok = true, data = ... }` ou `{ ok = false, err = '<cle.de.langue>' }`. L'interface affiche le texte de la clé `err`, jamais un code technique.
- Toute action qui modifie quelque chose porte un `actionId` (UUID v4 généré par l'interface). Le serveur garde en mémoire les `actionId` vus pendant 10 min (règle de la base) : un `actionId` déjà vu renvoie la même réponse que la première fois sans refaire l'action (anti double clic).
- Limite de fréquence par défaut si une fiche n'en précise pas : `Config.RateLimit.Default = { n = 5, s = 10 }` de la base (5 actions par fenêtre de 10 s, par joueur et par action). Au-delà : `{ ok = false, err = 'trop_vite' }` → `commun.erreur.trop_vite`.
- Droit admin = ACE `pop.tablet.admin`, revérifié par le serveur à **chaque** appel admin (`IsPlayerAceAllowed(src, 'pop.tablet.admin')`). L'interface cache les écrans admin aux non-admins, mais ce n'est jamais la protection.

### 0.2 Textes communs
Référentiel unique de la fiche 01 (§0 « Codes d'erreur communs », repris dans `00-sommaire.md`) : `commun.erreur.trop_vite`, `serveur`, `pas_droit`, `admin_requis`, `trop_long`, `champ_requis` ; `commun.chargement.long`, `commun.succes.enregistre`, `commun.bouton.annuler` / `confirmer` / `enregistrer` / `retour`, `commun.droit.grade_requis`, `commun.pagination.precedent` / `suivant`. Aucune clé commune propre à ce fichier.

### 0.3 Nettoyage des textes
- Fonction serveur unique `Sanitize.text(value, max, multiline)` de la base (BASE-MOT-12) : convertit en chaîne, retire les caractères de contrôle (sauf retour ligne si `multiline`), retire `<` et `>`, coupe les espaces de début/fin, refuse si longueur > `max` (pas de coupure silencieuse : erreur `commun.erreur.trop_long`). L'interface affiche toujours les textes joueurs via `textContent`, jamais `innerHTML`.
- URL d'image : `Sanitize.imageUrl(url)` de la base (BASE-MOT-18, règles reprises en SITE-EDI-17).

### 0.4 Tables créées par ce fichier (oxmysql, créées automatiquement au démarrage si absentes, `CREATE TABLE IF NOT EXISTS`)
Ce fichier **définit** `pop_tablet_companies` (l'identifiant d'entreprise de toute la tablette est `pop_tablet_companies.id`, colonne `company_id INT` partout) et `pop_tablet_company_grades` (niveau de chaque grade). Les droits par grade ne sont pas ici : ils sont dans `pop_tablet_ent_permissions` (fichier 02, ENT-GES-18). Les tables `pop_tablet_devices`, `pop_tablet_logs` et `pop_tablet_appdata` sont définies par la base (fichier 01, BASE-MOT-17) et ne sont pas redéfinies ici.

```sql
pop_tablet_companies (
  id INT AUTO_INCREMENT PRIMARY KEY,
  slug VARCHAR(32) NOT NULL UNIQUE,          -- identifiant texte, a-z 0-9 _
  name VARCHAR(40) NOT NULL,
  logo_url VARCHAR(255) NULL,
  color CHAR(7) NOT NULL DEFAULT '#3B82F6',  -- #RRGGBB
  template VARCHAR(20) NOT NULL,             -- police|ems|mecano|immobilier|concession|commerce|service|institution|gang|vide
  job_name VARCHAR(50) NULL UNIQUE,
  apps JSON NOT NULL,                        -- liste des briques actives
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  archived TINYINT(1) NOT NULL DEFAULT 0,
  archived_at DATETIME NULL,
  archived_by VARCHAR(64) NULL,
  created_by VARCHAR(64) NOT NULL,           -- identifiant license ou 'system'
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
)
pop_tablet_company_grades (
  company_id INT NOT NULL, grade INT NOT NULL, label VARCHAR(40) NOT NULL,
  level ENUM('recrue','membre','chef','patron') NOT NULL,
  PRIMARY KEY (company_id, grade)
)
pop_tablet_sites (
  id INT AUTO_INCREMENT PRIMARY KEY,
  company_id INT NOT NULL UNIQUE,
  address VARCHAR(40) NOT NULL UNIQUE,       -- ex. dynasty8.rp (nom 3 à 24 caractères + « .rp »)
  site_type VARCHAR(20) NOT NULL DEFAULT 'entreprise', -- un de Config.Browser.SiteTypes (navigateur, fichier 06)
  description VARCHAR(140) NULL,             -- résumé affiché dans la recherche du navigateur
  unlisted TINYINT(1) NOT NULL DEFAULT 0,    -- 1 = site caché : accessible par son adresse seulement
  maintenance TINYINT(1) NOT NULL DEFAULT 0, maintenance_message VARCHAR(200) NULL, -- SITE-EDI-21
  address_changed_at DATETIME NULL,
  template VARCHAR(20) NOT NULL,             -- vitrine|annonces|catalogue|services|institution
  draft JSON NOT NULL,                       -- contenu en cours d'édition
  published_version_id INT NULL,
  status ENUM('brouillon','publie','masque') NOT NULL DEFAULT 'brouillon',
  hidden_reason VARCHAR(200) NULL, hidden_by VARCHAR(64) NULL, hidden_at DATETIME NULL,
  lock_identifier VARCHAR(64) NULL, lock_name VARCHAR(60) NULL, lock_until DATETIME NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
)
pop_tablet_site_versions (
  id INT AUTO_INCREMENT PRIMARY KEY, site_id INT NOT NULL, number INT NOT NULL,
  content JSON NOT NULL, kind ENUM('publication','restauration','import') NOT NULL,
  author_identifier VARCHAR(64) NOT NULL, author_name VARCHAR(60) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY (site_id, number)
)
pop_tablet_site_visits (site_id INT NOT NULL, day DATE NOT NULL, visits INT NOT NULL DEFAULT 0, PRIMARY KEY (site_id, day))
pop_tablet_reports (
  id INT AUTO_INCREMENT PRIMARY KEY, target_type ENUM('site','annonce') NOT NULL, target_id INT NOT NULL,
  reporter_identifier VARCHAR(64) NOT NULL, reason VARCHAR(40) NOT NULL, comment VARCHAR(300) NULL,
  status ENUM('ouvert','traite','rejete') NOT NULL DEFAULT 'ouvert', handled_by VARCHAR(64) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY (target_type, target_id, reporter_identifier)
)
pop_tablet_settings (setting_key VARCHAR(64) PRIMARY KEY, value JSON NOT NULL, updated_by VARCHAR(64) NOT NULL, updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)
pop_tablet_cameras (
  id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(40) NOT NULL, zone VARCHAR(40) NULL,
  x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, rot_x FLOAT NOT NULL, rot_y FLOAT NOT NULL, rot_z FLOAT NOT NULL,
  fov FLOAT NOT NULL DEFAULT 60, companies JSON NOT NULL, active TINYINT(1) NOT NULL DEFAULT 1,
  max_rotation INT NOT NULL DEFAULT 45, night_vision TINYINT(1) NOT NULL DEFAULT 1, online TINYINT(1) NOT NULL DEFAULT 1, -- colonnes police (MET-POL-39)
  created_by VARCHAR(64) NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
)
-- (table pop_tablet_shops supprimée : la vente de la tablette et du chargeur est gérée par la boutique du serveur, voir ADM-15)
```

### 0.5 Briques (apps) d'une entreprise : identifiants fixes
| Identifiant | Nom affiché (clé `briques.<id>.nom`) | Remarque |
|---|---|---|
| `gestion` | « Gestion » | Obligatoire, ne peut pas être décochée (employés, grades, compte). |
| `factures` | « Factures » | |
| `annonces` | « Annonces » | |
| `demandes` | « Demandes » | |
| `site` | « Site web » | Crée la ligne `pop_tablet_sites` à l'activation. |
| `tableur` | « Tableur » | |
| `stock` | « Stock » | |
| `planning` | « Planning » | |
| `metier_police` | « Police » | Une seule brique `metier_*` par entreprise. |
| `metier_ems` | « EMS » | |
| `metier_mecano` | « Mécano » | |
| `metier_justice` | « Justice » | |
| `metier_gang` | « Gang » | |
| `metier_immobilier` | « Immobilier » | Cadastre et ventes de biens (MET-IMM-01, MET-IMM-02, fichier 04). |

### 0.6 Correspondance automatique grades du métier (ESX, QBCore, Qbox) → niveaux tablette
Fonction serveur `PopTablet.Companies.autoLevels(grades)` (grades du métier triés par numéro croissant, lus par `Bridge.GetJobs()` : ESX, QBCore ou Qbox) :
1. 1 grade : ce grade = Patron.
2. 2 grades : le plus bas = Recrue, le plus haut = Patron.
3. 3 grades ou plus : plus bas = Recrue, plus haut = Patron ; les `n` intermédiaires : les `ceil(n/2)` premiers = Membre, les suivants = Chef. Exemple 5 grades (0 à 4) : 0 Recrue, 1 Membre, 2 Membre, 3 Chef, 4 Patron.

### 0.7 Écran d'entrée de l'admin
Tout ce qui est admin (créateur d'entreprises compris) vit dans l'app « Admin » (icône bouclier), visible seulement pour les joueurs ACE `pop.tablet.admin`. Onglets dans cet ordre : « Entreprises », « Tablettes », « Journal », « Modération », « Apps », « Limites », « Caméras », « Performance ». Voir ADM-01.

---

## 1. Créateur d'entreprises (admin, optionnel) : `SITE-CRE-`

### [SITE-CRE-01] Entreprises par défaut créées au premier démarrage
- **But** : que la tablette soit utilisable en 5 minutes avec les entreprises courantes déjà créées, reliées aux métiers et avec un site déjà rempli.
- **Qui** : automatique (serveur), aucun joueur. Désactivable par réglage.
- **Où** : démarrage de la ressource côté serveur (après connexion oxmysql et chargement du framework).
- **Parcours** :
  1. Au démarrage, le serveur crée les tables (0.4) si absentes.
  2. Il lit la clé `pop_tablet_settings.defaults_installed`. Si elle vaut `true`, il s'arrête là (jamais de réinstallation, même si l'admin a supprimé/archivé une entreprise par défaut).
  3. Si `Config.Companies.CreateDefaults = false`, il écrit `defaults_installed = true` et s'arrête.
  4. Sinon, il lit la liste des métiers (`Bridge.GetJobs()`) et, pour chacune des 7 entreprises du tableau ci-dessous, cherche le premier métier existant dans la liste `jobs candidats`. Trouvé et pas déjà relié : `job_name` = ce métier ; sinon `job_name = NULL` (entreprise « non reliée »).
  5. Il crée l'entreprise (`is_default = 1`, `created_by = 'system'`), ses grades (repris du métier relié avec 0.6 ; si non reliée, les grades par défaut du modèle, voir tableau), son site (adresse, modèle, contenu prérempli du modèle, `status = 'publie'`, version n° 1 de type `publication`, auteur `system` / « Système »).
  6. Tout se fait dans une seule transaction ; en cas d'échec, rien n'est gardé, un message est écrit dans la console serveur et la création sera retentée au prochain démarrage.
  7. Il écrit `defaults_installed = true`, un message console « [POP Tablet] 7 entreprises par défaut créées (X reliées à un métier, Y à relier dans Admin > Entreprises). » et une ligne au journal.
- **Données** (entreprises installées) :

| Slug | Nom | Modèle | Couleur | Jobs candidats (ordre) | Briques | Adresse site | Modèle de site | Grades si non reliée |
|---|---|---|---|---|---|---|---|---|
| `police` | « Police de Los Santos » | `police` | `#2563EB` | `police`, `lspd`, `sheriff` | gestion, factures, annonces, demandes, site, planning, metier_police | `lspd.rp` | institution | 0 Cadet, 1 Agent, 2 Sergent, 3 Lieutenant, 4 Commandant |
| `ems` | « Services médicaux » | `ems` | `#DC2626` | `ambulance`, `ems` | gestion, factures, annonces, demandes, site, planning, metier_ems | `ems.rp` | institution | 0 Stagiaire, 1 Ambulancier, 2 Médecin, 3 Chef de service, 4 Directeur |
| `mecano` | « Los Santos Customs » | `mecano` | `#F59E0B` | `mechanic`, `bennys`, `lscustoms` | gestion, factures, annonces, demandes, site, stock, planning, metier_mecano | `lscustoms.rp` | services | 0 Apprenti, 1 Mécanicien, 2 Chef d'atelier, 3 Patron |
| `immobilier` | « Dynasty 8 » | `immobilier` | `#16A34A` | `realestateagent`, `realestate`, `dynasty8` | gestion, factures, annonces, demandes, site, tableur, planning, metier_immobilier | `dynasty8.rp` | annonces | 0 Stagiaire, 1 Agent, 2 Agent confirmé, 3 Directeur |
| `concession` | « Premium Deluxe Motorsport » | `concession` | `#7C3AED` | `cardealer`, `dealer`, `pdm` | gestion, factures, annonces, demandes, site, stock, tableur | `pdm.rp` | catalogue | 0 Vendeur stagiaire, 1 Vendeur, 2 Chef des ventes, 3 Directeur |
| `tribunal` | « Tribunal de Los Santos » | `institution` | `#475569` | `justice`, `judge`, `doj` | gestion, factures, annonces, demandes, site, planning, metier_justice | `tribunal.rp` | institution | 0 Procureur adjoint, 1 Procureur, 2 Juge, 3 Président du tribunal |
| `avocats` | « Cabinet d'avocats » | `service` | `#0EA5E9` | `avocat`, `lawyer` | gestion, factures, annonces, demandes, site, planning, metier_justice | `avocats.rp` | services | 0 Avocat stagiaire, 1 Avocat, 2 Associé, 3 Associé gérant |

  Contenu prérempli des sites : celui du modèle de site (SITE-EDI-02), avec le nom de l'entreprise injecté dans le bloc titre, et pour `lspd.rp` / `ems.rp` un bloc texte « Pour toute urgence, utilisez le numéro d'urgence de votre téléphone. Pour une demande non urgente, utilisez le formulaire ci-dessous. ».
  Logos par défaut : fichiers `html/img/defaults/<slug>.png` hébergés par la ressource (`logo_url = 'nui://pop_tablet/html/img/defaults/<slug>.png'`).
- **Règles serveur** : une transaction unique ; un même métier ne peut être relié qu'à une entreprise (colonne UNIQUE) ; adresse de site en collision (cas d'une base partagée) → suffixe `-2`, `-3` ; aucune exécution si `defaults_installed = true`.
- **Textes et états** : aucun écran joueur. Console : voir étape 7 ; en échec : « [POP Tablet] Création des entreprises par défaut impossible : base de données indisponible. Nouvel essai au prochain démarrage. ».
- **Notifications** : aucune.
- **Liens** : alimente l'annuaire (navigateur), le créateur (SITE-CRE-12), le navigateur (sites publiés), les apps métier.
- **Réglages** : `Config.Companies.CreateDefaults = true`.
- **Journal admin** : oui, type `entreprise.defauts_installes`, acteur `system`, résumé « 7 entreprises par défaut créées », `after_data` = liste slug → job_name.
- **Performance** : exécuté une seule fois dans la vie du serveur ; ensuite une seule lecture de clé au démarrage. Les entreprises sont ensuite mises en cache mémoire par le module entreprises.
- **Cas limites** :
  - Aucun métier correspondant : les 7 entreprises sont créées non reliées, avec grades par défaut ; un bandeau dans le créateur invite à les relier (SITE-CRE-03).
  - Tribunal et Cabinet d'avocats non reliés (métiers `justice` / `avocat` absents, cas fréquent) : l'assistant de premier démarrage (BASE-MOT-15, étape « Justice ») propose pour chacun « Créer le métier » (présélectionné, mécanisme de SITE-CRE-06), « Relier à un métier existant » (SITE-CRE-03) ou « Ne pas utiliser » (entreprise archivée).
  - Base de données coupée pendant la création : transaction annulée, rien d'écrit, nouvel essai au prochain démarrage.
  - Le serveur avait déjà une version antérieure de la tablette avec des entreprises : `defaults_installed` absent mais table non vide → on n'installe **pas** les défauts, on écrit `defaults_installed = true`.
  - Deux entreprises candidates au même métier (ex. `sheriff` déjà pris) : la première du tableau gagne, la suivante prend le candidat suivant ou reste non reliée.
- **Critères d'acceptation** :
  - Étant donné une base vide et les métiers `police`, `ambulance`, `mechanic`, quand la ressource démarre, alors 7 entreprises existent, 3 reliées, 4 non reliées, 7 sites publiés accessibles par leur adresse.
  - Étant donné `defaults_installed = true` et l'entreprise `police` archivée, quand la ressource redémarre, alors aucune entreprise n'est recréée.
  - Étant donné un joueur qui déclenche à la main l'événement d'installation depuis son client, quand l'événement arrive, alors il est ignoré (aucun événement réseau n'existe pour cette action : elle n'est appelable que côté serveur).

### [SITE-CRE-02] Détection des métiers non reliés
- **But** : montrer à l'admin les métiers qui n'ont pas encore d'entreprise, pour lui proposer de les relier.
- **Qui** : admin serveur (ACE `pop.tablet.admin`). Non réglable.
- **Où** : Admin > onglet « Entreprises » > encart « Métiers sans entreprise » en haut de la liste (visible seulement s'il y en a au moins un) ; bouton « Actualiser » dans l'encart.
- **Parcours** :
  1. À l'ouverture de l'onglet, l'interface appelle `pop_tablet:companies:listUnlinkedJobs`.
  2. Le serveur vérifie l'ACE, lit `Bridge.GetJobs()`, retire les métiers listés dans `Config.Companies.IgnoredJobs` et ceux déjà présents dans `pop_tablet_companies.job_name` (y compris entreprises archivées), et renvoie pour chaque métier restant : nom technique, libellé, nombre de grades, nombre de joueurs en base ayant ce métier (`Bridge.GetEmployees(job)` compté par métier (ESX `SELECT job, COUNT(*) FROM users GROUP BY job` ; QBCore / Qbox équivalent sur `players` / `player_groups`), mis en cache 5 minutes).
  3. L'interface affiche une ligne par métier : libellé, nom technique en petit, « {n} grades · {m} joueurs », et deux boutons : « Créer l'entreprise » (ouvre SITE-CRE-04 avec nom = libellé, métier lié = ce métier, grades = ESX) et « Relier à une entreprise existante » (SITE-CRE-03).
  4. Bouton « Ignorer » sur chaque ligne : ajoute le métier à la liste ignorée stockée en base (`pop_tablet_settings.ignored_jobs`), la ligne disparaît.
  5. Lien « Voir les métiers ignorés » en bas de l'encart : liste avec bouton « Ne plus ignorer ».
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| name (métier) | texte | oui | 50 car. | lu par le bridge |
| label | texte | oui | 50 car. | lu par le bridge |
| gradesCount | entier | oui | ≥ 1 | lu par le bridge |
| playersCount | entier | oui | ≥ 0 | requête users |
| ignored_jobs (réglage) | liste de textes | non | 200 entrées | `{'unemployed'}` |

- **Règles serveur** : ACE vérifiée ; `unemployed` toujours ignoré ; limite de fréquence 1 appel / 3 s (bouton « Actualiser ») ; ajout à la liste ignorée : le nom doit exister dans `Bridge.GetJobs()`.
- **Textes et états** :
  - Titre encart : « Métiers sans entreprise ({n}) » (`admin.entreprises.metiers.titre`).
  - Ligne : « {grades} grades · {joueurs} joueurs » (`admin.entreprises.metiers.ligne`).
  - Boutons : « Créer l'entreprise » (`admin.entreprises.metiers.creer`), « Relier à une entreprise existante » (`admin.entreprises.metiers.relier`), « Ignorer » (`admin.entreprises.metiers.ignorer`), « Actualiser » (`admin.entreprises.metiers.actualiser`), « Voir les métiers ignorés » (`admin.entreprises.metiers.voir_ignores`), « Ne plus ignorer » (`admin.entreprises.metiers.ne_plus_ignorer`).
  - Vide : l'encart n'est pas affiché ; dans la liste des ignorés vide : « Aucun métier ignoré. » (`admin.entreprises.metiers.ignores_vide`).
  - Succès ignorer : « Métier ignoré. » (`admin.entreprises.metiers.ignore_ok`).
  - Erreur framework : « Impossible de lire les métiers. Vérifiez que le framework est démarré. » (`admin.entreprises.metiers.erreur_esx`).
  - Pas le droit : onglet invisible ; appel forcé → `commun.erreur.admin_requis`.
- **Notifications** : aucune.
- **Liens** : SITE-CRE-03, SITE-CRE-04.
- **Réglages** : `Config.Companies.IgnoredJobs = { 'unemployed' }` (valeurs de départ, complétées par la liste en base).
- **Journal admin** : oui pour « Ignorer » / « Ne plus ignorer » (type `entreprise.metier_ignore`, résumé « Métier {name} ignoré » / « réactivé »). Non pour la simple lecture.
- **Performance** : calcul seulement à l'ouverture de l'onglet ; comptage des joueurs en cache 5 min ; aucun calcul tablette fermée.
- **Cas limites** :
  - Un métier est supprimé de la base alors qu'une entreprise y est reliée : l'entreprise affiche l'étiquette « Métier introuvable » dans la liste (SITE-CRE-12), le métier n'apparaît évidemment pas dans l'encart.
  - Plus de 50 métiers non reliés : pagination à 20 par page.
  - Un autre admin crée l'entreprise pendant ce temps : au clic sur « Créer l'entreprise », le serveur refuse (métier déjà relié) avec « Ce métier vient d'être relié à une autre entreprise. » (`admin.entreprises.metiers.deja_relie`) et la liste se recharge.
- **Critères d'acceptation** :
  - Étant donné le métier `taxi` sans entreprise, quand l'admin ouvre l'onglet, alors une ligne « Taxi » apparaît avec ses grades et son nombre de joueurs.
  - Étant donné l'admin qui clique « Ignorer » sur `taxi`, quand il recharge l'onglet, alors `taxi` n'apparaît plus et figure dans les métiers ignorés.
  - Étant donné un joueur non admin qui appelle `pop_tablet:companies:listUnlinkedJobs`, quand le serveur répond, alors il reçoit `commun.erreur.admin_requis` et aucune donnée.

### [SITE-CRE-03] Relier un métier à une entreprise existante (ou délier)
- **But** : rattacher une entreprise (par défaut ou créée) à un métier, pour que ses employés et grades suivent le framework.
- **Qui** : admin serveur.
- **Où** : (a) encart SITE-CRE-02 > « Relier à une entreprise existante » ; (b) fiche entreprise (SITE-CRE-07) > champ « Métier lié » > bouton « Changer ».
- **Parcours** :
  1. Une fenêtre s'ouvre : liste déroulante des entreprises non reliées (cas a) ou des métiers non reliés + option « Aucun (délier) » (cas b).
  2. Après choix, l'interface affiche un aperçu de la correspondance des grades calculée par le serveur (`pop_tablet:companies:previewLink`) : tableau « Grade du métier → Niveau tablette » (0.6), chaque niveau modifiable par liste déroulante (Recrue, Membre, Chef, Patron).
  3. Clic « Relier » → `pop_tablet:companies:link { companyId, job, levels = { [grade] = level }, actionId }`.
  4. Le serveur vérifie : ACE, entreprise existante et non archivée, métier existant dans le framework et non relié à une autre entreprise, au moins un grade au niveau Patron.
  5. Il remplace les lignes `pop_tablet_company_grades` de l'entreprise par les grades du métier (libellés du framework, niveaux choisis, `permissions = NULL`), met à jour `job_name`, vide le cache de l'entreprise et envoie à toutes les tablettes ouvertes des joueurs ayant ce métier un rafraîchissement des droits.
  6. Délier : `job_name = NULL`, les grades sont gardés tels quels (copie figée), plus aucun joueur n'est considéré employé tant qu'elle n'est pas reliée de nouveau ; confirmation obligatoire.
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| companyId | entier | oui | entreprise existante | — |
| job | texte ou null | oui | métier existant | — |
| levels | table grade → niveau | oui | 1 niveau parmi 4 par grade, ≥ 1 Patron | calcul 0.6 |

- **Règles serveur** : ACE ; unicité du métier (contrainte UNIQUE + vérification avant écriture) ; au moins un Patron ; `actionId` ; fréquence par défaut (0.1).
- **Textes et états** :
  - Titre : « Relier un métier » (`admin.entreprises.relier.titre`).
  - Colonnes : « Grade du métier » / « Niveau tablette » (`admin.entreprises.relier.col_grade` / `.col_niveau`). Niveaux : « Recrue », « Membre », « Chef », « Patron » (`niveaux.recrue`, `niveaux.membre`, `niveaux.chef`, `niveaux.patron`).
  - Bouton : « Relier » (`admin.entreprises.relier.valider`).
  - Succès : « Entreprise reliée au métier {job}. » (`admin.entreprises.relier.ok`).
  - Erreur pas de patron : « Il faut au moins un grade au niveau Patron. » (`admin.entreprises.relier.sans_patron`).
  - Erreur métier pris : « Ce métier est déjà relié à {entreprise}. » (`admin.entreprises.relier.deja_relie`).
  - Erreur entreprise archivée : « Entreprise archivée. Restaurez-la d'abord. » (`admin.entreprises.archivee`).
  - Délier, confirmation : « Délier {entreprise} de {job} ? Ses employés n'y auront plus accès tant qu'elle n'est pas reliée de nouveau. » (`admin.entreprises.delier.confirmer`) ; succès « Entreprise déliée. » (`admin.entreprises.delier.ok`).
  - Vide (aucune entreprise non reliée) : « Toutes les entreprises sont déjà reliées. Créez une entreprise pour ce métier. » + bouton « Créer l'entreprise » (`admin.entreprises.relier.vide`).
- **Notifications** : les joueurs connectés ayant ce métier et la tablette sur eux reçoivent « Tablette mise à jour : {entreprise} est maintenant disponible. » (`notif.entreprise.reliee`).
- **Liens** : toutes les apps de l'entreprise (droits) ; annuaire (ouvert/fermé selon service des joueurs du métier).
- **Réglages** : aucun.
- **Journal admin** : oui, type `entreprise.relie` / `entreprise.delie`, `before_data` = ancien job et grades, `after_data` = nouveau job et grades.
- **Performance** : aperçu calculé à la demande ; rafraîchissement envoyé seulement aux joueurs concernés tablette ouverte (les autres liront le cache à l'ouverture).
- **Cas limites** :
  - Deux admins relient le même métier à deux entreprises à la même seconde : la contrainte UNIQUE fait échouer la seconde → `admin.entreprises.relier.deja_relie`.
  - Le métier a changé de grades depuis (grade ajouté dans le framework) : à chaque démarrage et à chaque ouverture de la fiche entreprise, le serveur compare ; un grade du métier inconnu est ajouté au niveau Membre et l'admin voit le bandeau « Les grades du métier ont changé. Vérifiez les niveaux. » (`admin.entreprises.grades_changes`).
  - Entreprise reliée puis déliée avec des factures en cours : les factures restent liées à l'entreprise (pas au métier), rien n'est perdu.
- **Critères d'acceptation** :
  - Étant donné l'entreprise « Dynasty 8 » non reliée et le métier `realestateagent` à 4 grades, quand l'admin relie avec les niveaux proposés, alors les grades 0/1/2/3 deviennent Recrue/Membre/Chef/Patron et un joueur `realestateagent` grade 3 voit les apps de Dynasty 8.
  - Étant donné des niveaux sans aucun Patron, quand l'admin clique « Relier », alors le serveur refuse avec « Il faut au moins un grade au niveau Patron. ».
  - Étant donné un joueur non admin qui envoie `pop_tablet:companies:link` avec un faux `companyId`, quand le serveur le reçoit, alors il refuse (`commun.erreur.admin_requis`) et rien ne change.

### [SITE-CRE-04] Créer une entreprise : étape 1 « Identité »
- **But** : saisir l'identité d'une nouvelle entreprise (nom, logo, couleur, modèle de départ, métier lié).
- **Qui** : admin serveur. Réglable : le créateur peut être désactivé (`Config.Companies.CreatorEnabled = false` cache le bouton, les entreprises par défaut restent).
- **Où** : Admin > Entreprises > bouton « Nouvelle entreprise » (en haut à droite) ou « Créer l'entreprise » depuis SITE-CRE-02. Assistant en 3 étapes avec un fil « 1 Identité · 2 Apps · 3 Grades » en haut ; boutons « Retour » et « Suivant » en bas.
- **Parcours** :
  1. L'admin remplit les champs (tableau). L'aperçu à droite montre la carte de l'entreprise (logo, nom, couleur d'accent) mise à jour à chaque frappe.
  2. Choisir un modèle de départ pré-coche les briques de l'étape 2 et pré-remplit les grades de l'étape 3 (si pas de métier lié) selon le tableau des modèles ci-dessous.
  3. « Suivant » → `pop_tablet:companies:validateIdentity` : le serveur vérifie les champs et l'unicité (nom, slug, métier) sans rien créer, renvoie le slug calculé et, si un métier est lié, ses grades du métier avec les niveaux 0.6.
  4. Les 3 étapes sont gardées dans l'interface (brouillon en mémoire de l'interface, perdu si la tablette est fermée) ; rien n'est écrit en base avant la validation finale de l'étape 3 (SITE-CRE-06).
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| name | texte | oui | 3 à 40 car., unique (insensible à la casse) parmi les entreprises non archivées | — |
| slug | texte | auto | `^[a-z0-9_]{3,32}$`, dérivé du nom (minuscules, accents retirés, espaces → `_`), suffixe `_2`, `_3` si pris | calculé |
| logo_url | URL | non | règles SITE-EDI-17 | logo générique `nui://pop_tablet/html/img/defaults/entreprise.png` |
| color | texte | oui | `^#[0-9A-Fa-f]{6}$` ; choisi parmi 12 pastilles ou saisi | `#3B82F6` |
| template | liste | oui | `commerce`, `service`, `police`, `ems`, `mecano`, `immobilier`, `concession`, `institution`, `gang`, `vide` | `commerce` |
| job_name | liste | non | métiers non reliés + « Aucun » + « Créer un nouveau métier » | « Aucun » |

  Modèles de départ :

| Modèle | Libellé | Briques pré-cochées | Modèle de site | Grades par défaut |
|---|---|---|---|---|
| commerce | « Commerce » | gestion, factures, annonces, demandes, site, stock | catalogue | Employé, Vendeur, Gérant, Patron |
| service | « Service » | gestion, factures, annonces, demandes, site, planning | services | Employé, Confirmé, Gérant, Patron |
| police | « Police » | gestion, factures, annonces, demandes, site, planning, metier_police | institution | Cadet, Agent, Sergent, Lieutenant, Commandant |
| ems | « EMS » | gestion, factures, annonces, demandes, site, planning, metier_ems | institution | Stagiaire, Ambulancier, Médecin, Chef de service, Directeur |
| mecano | « Garage » | gestion, factures, annonces, demandes, site, stock, planning, metier_mecano | services | Apprenti, Mécanicien, Chef d'atelier, Patron |
| immobilier | « Agence immobilière » | gestion, factures, annonces, demandes, site, tableur, planning, metier_immobilier | annonces | Stagiaire, Agent, Agent confirmé, Directeur |
| concession | « Concession » | gestion, factures, annonces, demandes, site, stock, tableur | catalogue | Vendeur stagiaire, Vendeur, Chef des ventes, Directeur |
| institution | « Institution » | gestion, annonces, demandes, site, planning, metier_justice | institution | Greffier, Avocat, Procureur, Juge |
| gang | « Gang » | gestion, stock, planning, metier_gang | (pas de brique site) | Recrue, Membre, Bras droit, Chef |
| vide | « Vide » | gestion | vitrine | Employé, Patron |

- **Règles serveur** : ACE ; créateur activé ; nettoyage du nom (0.3) ; nom unique ; métier existant et non relié ; « Créer un nouveau métier » : nom technique = slug, refusé si un métier de ce nom existe déjà ; couleur au format strict ; logo validé par SITE-EDI-17 ; fréquence 1 validation / s.
- **Textes et états** :
  - Titre : « Nouvelle entreprise » (`admin.creer.titre`) ; fil : « Identité », « Apps », « Grades » (`admin.creer.etape.identite`, `.apps`, `.grades`).
  - Libellés : « Nom » (`admin.creer.nom`), « Logo (lien d'image) » (`admin.creer.logo`), « Couleur » (`admin.creer.couleur`), « Modèle de départ » (`admin.creer.modele`), « Métier lié » (`admin.creer.metier`), options « Aucun » (`admin.creer.metier_aucun`) et « Créer un nouveau métier » (`admin.creer.metier_nouveau`).
  - Aide sous le métier : « Les joueurs qui ont ce métier dans le framework deviennent employés de l'entreprise. » (`admin.creer.metier_aide`).
  - Erreurs : « Ce nom est déjà utilisé par une autre entreprise. » (`admin.creer.nom_pris`), « Le nom doit faire entre 3 et 40 caractères. » (`admin.creer.nom_longueur`), « Couleur invalide. Choisissez une pastille ou saisissez un code comme #3B82F6. » (`admin.creer.couleur_invalide`), « Ce métier est déjà relié à {entreprise}. » (`admin.entreprises.relier.deja_relie`), « Un métier porte déjà ce nom. Sélectionnez-le dans la liste. » (`admin.creer.metier_existe`), erreurs de logo : voir SITE-EDI-17.
  - Créateur désactivé : bouton caché ; appel forcé → « Le créateur d'entreprises est désactivé sur ce serveur. » (`admin.creer.desactive`).
- **Notifications** : aucune à cette étape.
- **Liens** : SITE-CRE-05, SITE-CRE-06.
- **Réglages** : `Config.Companies.CreatorEnabled = true`, `Config.Companies.Colors = { '#3B82F6','#2563EB','#0EA5E9','#14B8A6','#16A34A','#84CC16','#F59E0B','#F97316','#DC2626','#E11D48','#7C3AED','#64748B' }`, `Config.Companies.Max = 100` (entreprises non archivées).
- **Journal admin** : non (rien n'est créé à cette étape).
- **Performance** : une validation serveur au clic sur « Suivant », pas de vérification à chaque frappe.
- **Cas limites** :
  - Limite `Config.Companies.Max` atteinte : « Nombre maximum d'entreprises atteint ({max}). Archivez une entreprise ou augmentez la limite. » (`admin.creer.max_atteint`) dès l'ouverture de l'assistant.
  - Nom avec emoji ou `<script>` : `<` `>` retirés, emoji gardés, slug calculé uniquement avec a-z 0-9 _ ; si le slug fait moins de 3 caractères → slug `entreprise_<id aléatoire 4 chiffres>`.
  - Tablette fermée en cours d'assistant : brouillon perdu, rien en base (comportement voulu, assistant court).
- **Critères d'acceptation** :
  - Étant donné l'admin qui saisit « Burger Shot », modèle Commerce, aucun métier, quand il clique « Suivant », alors il arrive à l'étape Apps avec gestion, factures, annonces, demandes, site, stock cochés.
  - Étant donné une entreprise « Burger Shot » existante, quand l'admin saisit « burger shot », alors le serveur répond « Ce nom est déjà utilisé par une autre entreprise. ».
  - Étant donné un joueur non admin qui appelle `pop_tablet:companies:validateIdentity`, quand le serveur répond, alors c'est `commun.erreur.admin_requis`.

### [SITE-CRE-05] Créer une entreprise : étape 2 « Choisir ses apps »
- **But** : choisir les briques (apps) que l'entreprise aura.
- **Qui** : admin serveur. Même écran réutilisé dans la modification (SITE-CRE-07).
- **Où** : assistant de création > étape « Apps ».
- **Parcours** :
  1. L'écran affiche une grille de cartes (icône, nom, une phrase d'explication), une par brique de 0.5, en deux groupes : « Apps de base » (gestion, factures, annonces, demandes, site, tableur, stock, planning) et « App métier (une seule) » (police, EMS, mécano, justice, gang, immobilier) présentées comme boutons radio avec une option « Aucune ».
  2. `gestion` est cochée et grisée avec la mention « Toujours incluse ».
  3. Une brique désactivée par l'admin serveur (ADM-02) est visible mais grisée avec « Coupée par l'admin ».
  4. « Suivant » : contrôle local (au moins `gestion`) puis passage à l'étape 3 ; le serveur revalide tout à la création finale.
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| apps | liste d'identifiants | oui | identifiants de 0.5 uniquement, `gestion` toujours présent, au plus 1 `metier_*` | selon modèle de départ |

  Phrases d'explication (`briques.<id>.aide`) : gestion « Employés, grades, salaires et compte de l'entreprise. » ; factures « Créer et encaisser des factures. » ; annonces « Publier des annonces dans la ville. » ; demandes « Recevoir les demandes des clients (rendez-vous, devis, dépannage, contact). » ; site « Un site web visible dans le navigateur. » ; tableur « Des tableaux simples pour les comptes et listes. » ; stock « Suivre les quantités de marchandises. » ; planning « Organiser les horaires de l'équipe. » ; metier_police « Amendes, rapports, casiers, mandats, caméras. » ; metier_ems « Dossiers médicaux et certificats. » ; metier_mecano « Carnet d'entretien et devis. » ; metier_justice « Affaires, audiences et verdicts. » ; metier_gang « Territoires, membres et réserves. » ; metier_immobilier « Cadastre des biens et ventes. ».
- **Règles serveur** (à la création ou modification) : liste filtrée sur les identifiants connus ; doublons retirés ; `gestion` forcée ; 2 `metier_*` → refus ; une brique coupée par l'admin peut être cochée (elle sera inactive tant qu'elle est coupée) ; un `metier_police` sur une seconde entreprise est autorisé (ex. LSPD et BCSO).
- **Textes et états** :
  - Titres de groupes : « Apps de base » (`admin.creer.apps.base`), « App métier (une seule) » (`admin.creer.apps.metier`), option « Aucune » (`admin.creer.apps.metier_aucune`).
  - Mentions : « Toujours incluse » (`admin.creer.apps.toujours`), « Coupée par l'admin » (`admin.creer.apps.coupee`).
  - Erreur : « Une seule app métier par entreprise. » (`admin.creer.apps.un_metier`).
- **Notifications** : aucune.
- **Liens** : décocher `site` sur une entreprise existante (SITE-CRE-07) masque le site (status inchangé en base, non servi tant que la brique est absente) sans le supprimer.
- **Réglages** : aucun.
- **Journal admin** : non à la création (la création globale est journalisée en SITE-CRE-06) ; oui en modification (SITE-CRE-07).
- **Performance** : écran statique, aucune requête.
- **Cas limites** :
  - Une app perso (PERSO-01) peut aussi être proposée : section « Apps perso » sous les briques, cases à cocher, identifiants `perso:<appId>` ; même règles de filtrage (l'app doit être chargée).
  - Modèle Gang sans site : si l'admin coche `site`, autorisé.
  - Interface trafiquée qui envoie `apps = {'gestion','metier_police','metier_ems'}` : refus serveur `admin.creer.apps.un_metier`.
- **Critères d'acceptation** :
  - Étant donné le modèle Garage, quand l'étape Apps s'affiche, alors « Mécano » est sélectionné dans App métier et stock et planning sont cochés.
  - Étant donné l'admin qui tente de décocher Gestion, quand il clique, alors rien ne change.
  - Étant donné une requête forgée avec deux apps métier, quand le serveur crée l'entreprise, alors il refuse avec « Une seule app métier par entreprise. ».

### [SITE-CRE-06] Créer une entreprise : étape 3 « Grades de départ » et création finale
- **But** : définir les grades de départ (repris du framework ou créés) et créer l'entreprise.
- **Qui** : admin serveur.
- **Où** : assistant de création > étape « Grades » > bouton « Créer l'entreprise ».
- **Parcours** :
  1. Cas métier lié existant : tableau des grades du métier (numéro, libellé, salaire du métier en lecture seule) avec le niveau calculé par 0.6, niveau modifiable par liste déroulante. Les libellés et salaires ne sont pas modifiables ici (ils viennent du framework ; le patron les règle ensuite dans Gestion).
  2. Cas « Aucun » ou « Créer un nouveau métier » : tableau éditable prérempli avec les grades du modèle de départ : pour chaque ligne libellé (texte), niveau (liste), salaire (entier, seulement si nouveau métier) ; boutons « Ajouter un grade » et icône corbeille par ligne ; ordre = de la plus basse à la plus haute, flèches haut/bas pour réordonner. Numéros de grade attribués automatiquement 0, 1, 2…
  3. Clic « Créer l'entreprise » → `pop_tablet:companies:create { identity, apps, grades, actionId }`.
  4. Le serveur revalide tout (SITE-CRE-04, SITE-CRE-05, règles ci-dessous), puis dans une transaction : crée l'entreprise ; si « nouveau métier », le crée par `Bridge.CreateJob(slug, nom, grades)` (BASE-MOT-02) : ESX insère dans les tables `jobs` (`name` = slug, `label` = nom) et `job_grades` (`job_name`, `grade`, `name` = libellé en minuscules sans accents avec `_`, `label`, `salary`, `skin_male = '{}'`, `skin_female = '{}'`) puis appelle `ESX.RefreshJobs()` si la fonction existe ; QBCore `QBCore.Functions.AddJob(slug, { label, defaultDuty = true, grades = { ['0'] = { name, payment }, … } })` (dernier grade `isboss = true`) ; Qbox `exports.qbx_core:CreateJob(slug, …)` même format ; sur QBCore et Qbox le métier est aussi écrit dans `pop_tablet_company_grades` et recréé à chaque démarrage ; crée les grades tablette ; si la brique `site` est cochée, crée le site avec une adresse proposée `<slug avec _ remplacés par ->.rp` (suffixe `-2` si prise), le modèle de site du modèle de départ, `status = 'brouillon'`.
  5. L'interface affiche le succès puis ouvre la fiche de l'entreprise (SITE-CRE-07).
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| grades[].grade | entier | oui | 0 à 20, continus | auto |
| grades[].label | texte | oui | 2 à 40 car. | modèle |
| grades[].level | liste | oui | recrue/membre/chef/patron | 0.6 |
| grades[].salary | entier | si nouveau métier | 0 à `Config.Companies.MaxSalary` | 0 |
| nombre de grades | entier | oui | 1 à 20 | modèle |

- **Règles serveur** : ACE ; au moins 1 grade, au plus 20 ; au moins un Patron ; le grade le plus haut doit être Patron ; libellés nettoyés et uniques dans l'entreprise ; salaire entier ≤ `Config.Companies.MaxSalary` ; `actionId` (double clic → une seule entreprise) ; transaction complète (rien de partiel) ; `Config.Companies.Max` revérifiée.
- **Textes et états** :
  - Titre : « Grades de départ » (`admin.creer.grades.titre`) ; aide cas ESX : « Les grades viennent du métier. Seul le niveau de chacun se règle ici. » (`admin.creer.grades.aide_esx`) ; aide cas manuel : « Du plus bas au plus haut. Le plus haut doit être Patron. » (`admin.creer.grades.aide_manuel`).
  - Colonnes : « Grade », « Niveau », « Salaire » (`admin.creer.grades.col_grade`, `.col_niveau`, `.col_salaire`) ; boutons « Ajouter un grade » (`admin.creer.grades.ajouter`), « Créer l'entreprise » (`admin.creer.valider`).
  - Succès : « Entreprise {nom} créée. » (`admin.creer.ok`) ; si `ESX.RefreshJobs` absent (ESX ancien) : succès + « Redémarrez le serveur pour activer le nouveau métier. » (`admin.creer.redemarrage_esx`) ; QBCore et Qbox : actif tout de suite.
  - Erreurs : « Il faut au moins un grade au niveau Patron. » (`admin.entreprises.relier.sans_patron`), « Le grade le plus haut doit être Patron. » (`admin.creer.grades.haut_patron`), « Deux grades ont le même nom. » (`admin.creer.grades.doublon`), « Salaire trop élevé ({max} maximum). » (`admin.creer.grades.salaire_max`), « 20 grades maximum. » (`admin.creer.grades.max`), « Échec de la création. Rien n'a été enregistré. » (`admin.creer.echec`).
- **Notifications** : si métier lié, joueurs connectés avec ce métier et tablette sur eux : `notif.entreprise.reliee` (SITE-CRE-03).
- **Liens** : crée les données de base pour toutes les briques cochées ; le site apparaîtra dans le navigateur une fois publié (SITE-EDI-09) ; l'annuaire liste l'entreprise immédiatement.
- **Réglages** : `Config.Companies.MaxSalary = 5000`, `Config.Companies.MaxGrades = 20`, `Config.Companies.SiteSuffix = 'rp'`.
- **Journal admin** : oui, type `entreprise.creee`, `after_data` = identité, briques, grades, métier, adresse du site.
- **Performance** : une transaction ; cache des entreprises invalidé pour cette entreprise seulement.
- **Cas limites** :
  - Double clic sur « Créer l'entreprise » : même `actionId` → une seule entreprise, la seconde réponse est identique à la première.
  - Échec d'écriture dans `job_grades` (table ESX absente ou colonnes différentes) : transaction annulée, message `admin.creer.echec`, console : « [POP Tablet] Création du métier impossible : table job_grades introuvable. » (ESX seulement ; QBCore / Qbox : échec de `AddJob` / `CreateJob` → même message `admin.creer.echec`, console « [POP Tablet] Job creation failed (%s). »).
  - Métier relié entre l'étape 1 et 3 par un autre admin : refus `admin.entreprises.relier.deja_relie`, l'assistant revient à l'étape 1.
- **Critères d'acceptation** :
  - Étant donné « Burger Shot » avec « Créer un nouveau métier » et 3 grades (Employé/Membre, Gérant/Chef, Patron/Patron), quand l'admin crée, alors le métier `burger_shot` et ses 3 grades existent dans le framework (ESX : tables `jobs` / `job_grades` ; QBCore / Qbox : `GetJobs()` le renvoie, et il existe toujours après un redémarrage) et l'entreprise apparaît dans la liste.
  - Étant donné un grade le plus haut au niveau Chef, quand l'admin crée, alors refus « Le grade le plus haut doit être Patron. ».
  - Étant donné une requête forgée avec un salaire de 999999, quand le serveur la reçoit, alors refus « Salaire trop élevé (5000 maximum). » et aucune entreprise créée.

### [SITE-CRE-07] Modifier une entreprise existante (ajout)
- **But** : changer après coup le nom, le logo, la couleur, les briques ou les niveaux des grades d'une entreprise.
- **Qui** : admin serveur (tout) ; le patron de l'entreprise peut changer logo et couleur depuis Gestion (géré par la fiche Gestion, appelle le même serveur avec un droit `gestion.identite` réservé Patron).
- **Où** : Admin > Entreprises > clic sur une ligne > fiche entreprise avec onglets « Identité », « Apps », « Grades », « Site », « Actions ».
- **Parcours** :
  1. Chaque onglet réutilise l'écran correspondant de l'assistant (SITE-CRE-04/05/06) prérempli ; l'onglet Site affiche l'adresse, le statut et un bouton « Ouvrir l'éditeur » (ouvre SITE-EDI avec les droits admin) ; l'onglet Actions regroupe Dupliquer, Exporter, Archiver, Relier/délier.
  2. Bouton « Enregistrer » par onglet → `pop_tablet:companies:update { companyId, section, values, actionId }`.
  3. Le serveur valide avec les mêmes règles que la création, enregistre, invalide le cache de l'entreprise et pousse le rafraîchissement aux tablettes ouvertes des employés.
  4. Retirer une brique : confirmation « Retirer {brique} ? Les données sont conservées et reviendront si la brique est remise. » ; les données ne sont jamais supprimées.
  5. Grades d'une entreprise reliée à un métier : seul le niveau est modifiable ici ; libellés/salaires = framework.
- **Données** : identiques à SITE-CRE-04/05/06, plus `section` (`identite` | `apps` | `grades`).
- **Règles serveur** : ACE (ou Patron + section identite limitée à logo/couleur) ; mêmes validations ; impossible de retirer le dernier Patron ; `actionId`.
- **Textes et états** :
  - Onglets : « Identité », « Apps », « Grades », « Site », « Actions » (`admin.entreprise.onglet.identite`, `.apps`, `.grades`, `.site`, `.actions`).
  - Succès : `commun.succes.enregistre`.
  - Confirmation retrait : « Retirer {brique} ? Les données sont conservées et reviendront si la brique est remise. » (`admin.entreprise.retirer_brique`).
  - Erreur : « Entreprise archivée. Restaurez-la d'abord. » (`admin.entreprises.archivee`).
- **Notifications** : employés connectés tablette sur eux, si briques changées : « Les apps de {entreprise} ont été mises à jour. » (`notif.entreprise.apps_maj`).
- **Liens** : toutes les apps de l'entreprise.
- **Réglages** : aucun.
- **Journal admin** : oui, type `entreprise.modifiee`, `before_data`/`after_data` limités à la section modifiée.
- **Performance** : chargement de la fiche à l'ouverture seulement (une requête) ; cache invalidé ciblé.
- **Cas limites** :
  - Un employé utilise une brique au moment où elle est retirée : son prochain appel à cette brique renvoie « Cette app n'est plus disponible pour cette entreprise. » (`commun.erreur.brique_retiree`) et l'app se ferme.
  - Changement de nom vers un nom pris : `admin.creer.nom_pris`.
  - Deux admins modifient la même section : le dernier qui enregistre gagne ; le premier voit le bandeau « Modifiée par {admin} il y a un instant. Rechargez pour voir sa version. » (`admin.entreprise.modifiee_ailleurs`) si `updated_at` a changé depuis l'ouverture (le serveur compare l'`updated_at` envoyé).
- **Critères d'acceptation** :
  - Étant donné l'entreprise « Burger Shot », quand l'admin coche Planning et enregistre, alors les employés connectés voient l'app Planning sans reconnecter.
  - Étant donné un patron qui envoie `section = 'apps'`, quand le serveur le reçoit, alors refus `commun.erreur.pas_droit`.
  - Étant donné l'admin qui passe l'unique grade Patron en Chef, quand il enregistre, alors refus « Il faut au moins un grade au niveau Patron. ».

### [SITE-CRE-08] Dupliquer une entreprise
- **But** : créer rapidement une entreprise semblable (ex. deuxième garage) en copiant les réglages d'une existante.
- **Qui** : admin serveur.
- **Où** : fiche entreprise > onglet « Actions » > bouton « Dupliquer ».
- **Parcours** :
  1. Fenêtre : « Nom de la copie » (prérempli « {nom} (copie) »), « Métier lié » (liste des non reliés + « Aucun » + « Créer un nouveau métier »), case « Copier aussi le site » (cochée).
  2. « Dupliquer » → `pop_tablet:companies:duplicate { companyId, name, job, copySite, actionId }`.
  3. Le serveur copie : couleur, logo, modèle, briques, grades (libellés et niveaux, droits personnalisés `permissions`) ; si `copySite`, le **brouillon** et la version publiée du site deviennent le brouillon de la copie (`status = 'brouillon'`, nouvelle adresse proposée comme en SITE-CRE-06), sans l'historique des versions ni les visites.
  4. Ne sont **jamais** copiés : employés, compte, factures, annonces, demandes, stock, tableur, planning, données des apps métier.
  5. L'interface ouvre la fiche de la copie.
- **Données** : name (mêmes règles que SITE-CRE-04), job (idem), copySite (booléen, défaut vrai).
- **Règles serveur** : ACE ; entreprise source existante (archivée autorisée) ; mêmes validations que la création ; si métier lié, les grades sont repris du framework (0.6) et non de la source ; limite `Config.Companies.Max` ; `actionId`.
- **Textes et états** :
  - Titre : « Dupliquer {nom} » (`admin.dupliquer.titre`) ; champs : « Nom de la copie » (`admin.dupliquer.nom`), « Copier aussi le site » (`admin.dupliquer.site`) ; aide « Les employés, l'argent et les documents ne sont jamais copiés. » (`admin.dupliquer.aide`) ; bouton « Dupliquer » (`admin.dupliquer.valider`).
  - Succès : « Copie créée : {nom}. » (`admin.dupliquer.ok`).
  - Erreurs : celles de SITE-CRE-04 et SITE-CRE-06.
- **Notifications** : aucune (sauf liaison à un métier : `notif.entreprise.reliee`).
- **Liens** : site (brouillon), SITE-EDI.
- **Réglages** : aucun.
- **Journal admin** : oui, type `entreprise.dupliquee`, résumé « {source} dupliquée en {copie} ».
- **Performance** : une transaction.
- **Cas limites** :
  - Site source masqué par la modération : la copie reçoit le contenu en brouillon mais pas le statut masqué ; ses images sont revalidées (SITE-EDI-17), les images devenues interdites sont retirées des blocs.
  - Nom par défaut « {nom} (copie) » trop long (> 40) : le nom est tronqué à 33 caractères + « (copie) ».
  - Double clic : un seul duplicata (`actionId`).
- **Critères d'acceptation** :
  - Étant donné « Los Santos Customs » avec 12 employés et 3 factures, quand l'admin la duplique en « Garage Nord », alors la copie a les mêmes briques et grades, 0 employé, 0 facture, un site en brouillon.
  - Étant donné « Copier aussi le site » décoché, quand l'admin duplique, alors la copie a un site vide au modèle de départ.
  - Étant donné un joueur non admin qui appelle `pop_tablet:companies:duplicate`, quand le serveur répond, alors c'est `commun.erreur.admin_requis`.

### [SITE-CRE-09] Archiver et restaurer une entreprise
- **But** : retirer une entreprise du jeu sans rien effacer, et pouvoir la remettre.
- **Qui** : admin serveur.
- **Où** : fiche entreprise > « Actions » > « Archiver » ; liste des entreprises > filtre « Archivées » > ligne > « Restaurer ».
- **Parcours** :
  1. « Archiver » → confirmation qui demande de taper le nom de l'entreprise.
  2. `pop_tablet:companies:archive { companyId, actionId }` ; le serveur passe `archived = 1`, remplit `archived_at`, `archived_by`, **garde** `job_name` mais l'entreprise n'est plus considérée reliée (le métier réapparaît dans SITE-CRE-02 avec la mention « (lié à une entreprise archivée) » et ne peut pas être relié ailleurs sans délier d'abord), le site n'est plus servi (lecture renvoie « introuvable »), les annonces de l'entreprise ne s'affichent plus, les factures impayées émises restent payables par les clients (l'argent va au compte gelé de l'entreprise archivée).
  3. Les employés connectés avec la tablette : leurs apps de l'entreprise se ferment.
  4. « Restaurer » → `pop_tablet:companies:restore` : remet `archived = 0` si le nom n'est pas pris par une entreprise active et si `Config.Companies.Max` n'est pas dépassé ; le site revient avec son dernier statut.
- **Données** : companyId (entier), confirmation (texte = nom exact, vérifiée dans l'interface ET le serveur).
- **Règles serveur** : ACE ; confirmation comparée sans tenir compte de la casse ; les entreprises par défaut peuvent être archivées ; `actionId`.
- **Textes et états** :
  - Confirmation : « Archiver {nom} ? Le site, les annonces et les apps seront retirés du jeu. Rien n'est effacé. Saisissez le nom de l'entreprise pour confirmer. » (`admin.archiver.confirmer`) ; bouton « Archiver » (`admin.archiver.valider`).
  - Succès : « {nom} est archivée. » (`admin.archiver.ok`) ; « {nom} est restaurée. » (`admin.restaurer.ok`).
  - Erreurs : « Le nom tapé ne correspond pas. » (`admin.archiver.nom_faux`), « Une entreprise active porte déjà ce nom. Renommez-la avant de restaurer. » (`admin.restaurer.nom_pris`), `admin.creer.max_atteint`.
  - Filtre : « Actives » / « Archivées » (`admin.entreprises.filtre.actives`, `.archivees`) ; vide archivées : « Aucune entreprise archivée. » (`admin.entreprises.archivees_vide`).
- **Notifications** : employés connectés tablette sur eux : « {entreprise} a été fermée par l'administration. » (`notif.entreprise.archivee`).
- **Liens** : annuaire (retirée), navigateur (site introuvable), annonces (cachées), factures (restent payables), API site (`getSite` renvoie `nil, 'introuvable'`).
- **Réglages** : aucun.
- **Journal admin** : oui, types `entreprise.archivee` / `entreprise.restauree`.
- **Performance** : caches entreprise, site et annuaire invalidés pour cette entreprise.
- **Cas limites** :
  - Employé en service au moment de l'archivage : il est sorti du service côté tablette (pas d'effet sur le métier).
  - Archivage d'une entreprise ayant un mandat ou une affaire justice en cours : les documents restent consultables par les autres entreprises concernées (ils appartiennent au dossier, pas à l'émetteur).
  - Restaurer alors que son métier a été supprimé du framework : restaurée, étiquette « Métier introuvable ».
- **Critères d'acceptation** :
  - Étant donné « Dynasty 8 » archivée, quand un joueur ouvre `dynasty8.rp`, alors il voit « Ce site n'existe pas. ».
  - Étant donné « Dynasty 8 » archivée, quand l'admin la restaure, alors le site publié revient tel quel.
  - Étant donné une requête forgée d'archivage par un patron, quand le serveur la reçoit, alors refus `commun.erreur.admin_requis`.

### [SITE-CRE-10] Exporter une entreprise vers un fichier
- **But** : sauvegarder ou partager les réglages d'une entreprise et son site dans un fichier, pour les réimporter (autre serveur, autre entreprise).
- **Qui** : admin serveur.
- **Où** : fiche entreprise > « Actions » > « Exporter ».
- **Parcours** :
  1. Clic → `pop_tablet:companies:export { companyId }`.
  2. Le serveur construit le JSON (format ci-dessous), l'écrit avec `SaveResourceFile` dans `pop_tablet/exports/<slug>-<AAAAMMJJ-HHMM>.json` (dossier ouvert, non chiffré) et le renvoie aussi à l'interface.
  3. L'interface affiche : le nom du fichier créé, une zone de texte en lecture seule avec le JSON et un bouton « Copier » (copie dans le presse-papiers via la NUI).
- **Données** (format `pop_tablet_company`, version 1) :

```json
{
  "format": "pop_tablet_company",
  "version": 1,
  "exported_at": "2026-11-24T18:30:00Z",
  "tablet_version": "1.0.0",
  "company": {
    "name": "Dynasty 8", "logo_url": "https://i.imgur.com/abc.png", "color": "#16A34A",
    "template": "immobilier", "apps": ["gestion","factures","annonces","demandes","site","tableur","planning"],
    "job_name_hint": "realestateagent",
    "grades": [ { "grade": 0, "label": "Stagiaire", "level": "recrue", "salary": 50, "permissions": null } ]
  },
  "site": { "address": "dynasty8.rp", "template": "annonces", "content": { "schema": 1, "pages": [] } }
}
```
  `site` vaut `null` si l'entreprise n'a pas la brique site. `site.content` = version publiée si elle existe, sinon le brouillon.
- **Règles serveur** : ACE ; jamais d'employés, argent, documents, visites, identifiants de joueurs ; taille max 256 Ko (sinon refus) ; fréquence 1 export / 10 s.
- **Textes et états** :
  - Titre : « Exporter {nom} » (`admin.exporter.titre`) ; texte : « Fichier enregistré : exports/{fichier} » (`admin.exporter.fichier`) ; bouton « Copier » (`admin.exporter.copier`) ; succès copie « Copié dans le presse-papiers. » (`admin.exporter.copie_ok`).
  - Aide : « Contient les réglages et le site. Jamais les employés, l'argent ni les documents. » (`admin.exporter.aide`).
  - Erreurs : « Export trop volumineux (256 Ko maximum). » (`admin.exporter.trop_gros`), « Impossible d'écrire le fichier. Le texte reste copiable ci-dessous. » (`admin.exporter.ecriture_ko`).
- **Notifications** : aucune.
- **Liens** : SITE-CRE-11.
- **Réglages** : `Config.Companies.ExportFolder = 'exports'`.
- **Journal admin** : oui, type `entreprise.exportee`, résumé « Export de {nom} ».
- **Performance** : à la demande uniquement.
- **Cas limites** :
  - Échec de `SaveResourceFile` : le JSON reste affiché et copiable, message `admin.exporter.ecriture_ko`.
  - Entreprise archivée : export autorisé.
  - Deux exports dans la même minute : nom de fichier suffixé `-2`.
- **Critères d'acceptation** :
  - Étant donné « Dynasty 8 » avec un site publié, quand l'admin exporte, alors le fichier `exports/dynasty8-…json` existe et contient `format`, `company`, `site` mais aucun identifiant de joueur.
  - Étant donné l'admin qui clique « Copier », quand il colle ailleurs, alors le JSON complet est collé.
  - Étant donné un non-admin qui appelle `pop_tablet:companies:export`, quand le serveur répond, alors c'est `commun.erreur.admin_requis`.

### [SITE-CRE-11] Importer une entreprise depuis un fichier
- **But** : créer une entreprise (ou remplacer les réglages d'une existante) à partir d'un fichier d'export.
- **Qui** : admin serveur.
- **Où** : Admin > Entreprises > bouton « Importer » (à côté de « Nouvelle entreprise ») ; fiche entreprise > « Actions » > « Importer des réglages ».
- **Parcours** :
  1. Fenêtre avec deux onglets : « Coller le texte » (zone de texte) et « Fichier du dossier imports » (champ « Nom du fichier », ex. `dynasty8.json`, lu dans `pop_tablet/imports/`).
  2. « Vérifier » → `pop_tablet:companies:importPreview { text | fileName }` : le serveur lit (via `LoadResourceFile` pour un fichier), parse, valide, et renvoie un résumé : nom, briques, nombre de grades, adresse du site, liste des problèmes corrigés automatiquement (images retirées car domaine non autorisé, blocs inconnus retirés, briques inconnues retirées, adresse prise → nouvelle adresse proposée).
  3. L'admin choisit le mode : « Nouvelle entreprise » (depuis la liste) ou « Remplacer les réglages » (depuis une fiche) ; choisit le métier lié (le `job_name_hint` est présélectionné s'il existe et est libre).
  4. « Importer » → `pop_tablet:companies:import { payloadId, mode, companyId?, job, actionId }` (`payloadId` = identifiant du contenu vérifié gardé 5 minutes en mémoire serveur ; le texte n'est pas renvoyé une seconde fois).
  5. Nouvelle entreprise : même création que SITE-CRE-06, site en **brouillon** avec le contenu importé (version n° 1 de type `import` non publiée : le patron publie). Remplacer : identité, briques et niveaux de grades remplacés (les grades du métier restent ceux d'ESX si reliée) ; le contenu importé devient le brouillon du site, l'ancien brouillon est d'abord sauvé comme version (`kind = 'import'`) pour pouvoir revenir en arrière.
- **Données** : text (≤ 256 Ko), fileName (`^[%w_%-]+%.json$`, 64 car. max), mode (`nouvelle` | `remplacer`), job.
- **Règles serveur** : ACE ; `format == 'pop_tablet_company'` ; `version` ≤ version supportée (1) ; tous les champs revalidés comme une saisie manuelle (noms, couleur, briques, grades, blocs du site via le même validateur que l'éditeur SITE-EDI-06, limites de pages/blocs) ; nom pris → suffixe « (2) » proposé ; aucun champ inconnu conservé ; fréquence 1 vérification / 3 s ; `payloadId` expiré après 5 min.
- **Textes et états** :
  - Titre : « Importer une entreprise » (`admin.importer.titre`) ; onglets « Coller le texte » (`admin.importer.onglet_texte`), « Fichier du dossier imports » (`admin.importer.onglet_fichier`) ; boutons « Vérifier » (`admin.importer.verifier`), « Importer » (`admin.importer.valider`).
  - Résumé : « {nom} · {n} apps · {g} grades · site {adresse} » (`admin.importer.resume`) ; titre des corrections : « Corrigé automatiquement : » (`admin.importer.corrections`) ; lignes : « {n} image(s) retirée(s) : domaine non autorisé » (`admin.importer.corr_images`), « {n} bloc(s) inconnu(s) retiré(s) » (`admin.importer.corr_blocs`), « Adresse déjà prise, nouvelle adresse : {adresse} » (`admin.importer.corr_adresse`).
  - Succès : « Import terminé. Le site est en brouillon. » (`admin.importer.ok`).
  - Erreurs : « Ce texte n'est pas un export POP Tablet. » (`admin.importer.format_ko`), « Cet export vient d'une version plus récente de la tablette. Mettez la tablette à jour. » (`admin.importer.version_ko`), « Fichier introuvable dans le dossier imports. » (`admin.importer.fichier_ko`), « Fichier trop volumineux (256 Ko maximum). » (`admin.importer.trop_gros`), « Vérification expirée. » (`admin.importer.expire`).
- **Notifications** : aucune.
- **Liens** : SITE-EDI (brouillon), SITE-EDI-13 (version d'import).
- **Réglages** : `Config.Companies.ImportFolder = 'imports'`, `Config.Companies.ImportMaxSize = 262144`.
- **Journal admin** : oui, type `entreprise.importee`, résumé « Import de {nom} ({mode}) », `after_data` = résumé et corrections.
- **Performance** : parse à la demande ; contenu vérifié gardé en mémoire 5 min max puis libéré (minuterie unique créée à la vérification, aucune boucle).
- **Cas limites** :
  - JSON mal formé : `admin.importer.format_ko`.
  - Import « remplacer » sur une entreprise reliée à un métier avec des grades différents : les niveaux importés sont appliqués par numéro de grade ; les grades du métier absents du fichier gardent leur niveau actuel.
  - Fichier contenant `<script>` dans un texte de bloc : `<` `>` retirés par le nettoyage, import accepté.
- **Critères d'acceptation** :
  - Étant donné l'export de « Dynasty 8 » d'un autre serveur, quand l'admin l'importe en nouvelle entreprise, alors l'entreprise existe avec son site en brouillon identique.
  - Étant donné un export contenant une image `https://exemple-pirate.com/x.png`, quand l'admin vérifie, alors le résumé indique « 1 image(s) retirée(s) : domaine non autorisé ».
  - Étant donné un non-admin qui appelle `pop_tablet:companies:import`, quand le serveur répond, alors c'est `commun.erreur.admin_requis`.

### [SITE-CRE-12] Liste des entreprises dans l'admin (ajout)
- **But** : voir toutes les entreprises, leur état et accéder à leur fiche.
- **Qui** : admin serveur.
- **Où** : Admin > onglet « Entreprises » (écran d'arrivée).
- **Parcours** :
  1. Ouverture → `pop_tablet:companies:adminList { page, filter, search }`.
  2. Le serveur renvoie 20 entreprises par page, triées par nom : logo, nom, métier (ou « Non reliée » / « Métier introuvable »), nombre d'employés (joueurs en base avec ce métier, cache 5 min), nombre d'employés en service maintenant, briques (icônes), statut du site (« Publié », « Brouillon », « Masqué », « Sans site »), étiquette « Par défaut » si `is_default`.
  3. Barre de recherche (nom ou slug, à partir de 2 caractères, envoyée 300 ms après la dernière frappe) ; filtres « Actives » / « Archivées ».
  4. Clic sur une ligne : fiche entreprise (SITE-CRE-07).
- **Données** : page (entier ≥ 1), filter (`actives` | `archivees`), search (0 à 40 car.).
- **Règles serveur** : ACE ; search nettoyé et utilisé en paramètre SQL (`LIKE ?` avec `%` ajoutés côté serveur, caractères `%` et `_` du joueur échappés) ; fréquence 5 / 5 s.
- **Textes et états** :
  - Vide (aucune entreprise active) : « Aucune entreprise pour l'instant. » + bouton « Nouvelle entreprise » (`admin.entreprises.vide`).
  - Recherche sans résultat : « Aucune entreprise ne correspond à « {texte} ». » (`admin.entreprises.recherche_vide`).
  - Étiquettes : « Non reliée » (`admin.entreprises.non_reliee`), « Métier introuvable » (`admin.entreprises.metier_introuvable`), « Par défaut » (`admin.entreprises.par_defaut`), « {n} en service » (`admin.entreprises.en_service`), statuts du site `site.statut.publie` « Publié », `site.statut.brouillon` « Brouillon », `site.statut.masque` « Masqué », `site.statut.aucun` « Sans site ».
  - Chargement : 6 lignes grises.
- **Notifications** : aucune.
- **Liens** : SITE-CRE-02 à 11.
- **Réglages** : `Config.Limits.PageSize = 20`.
- **Journal admin** : non (lecture).
- **Performance** : une requête paginée ; liste des entreprises lue depuis le cache mémoire serveur ; compte « en service » lu dans l'état mémoire du service.
- **Cas limites** :
  - 0 entreprise et créateur désactivé : texte vide sans bouton.
  - Plus de 20 résultats : boutons Précédent/Suivant.
  - Recherche « %% » : échappée, aucun résultat aberrant.
- **Critères d'acceptation** :
  - Étant donné 25 entreprises actives, quand l'admin ouvre l'onglet, alors il voit 20 lignes et un bouton « Suivant ».
  - Étant donné la recherche « dyn », quand il attend 300 ms, alors seule « Dynasty 8 » s'affiche.
  - Étant donné un non-admin qui appelle `pop_tablet:companies:adminList`, quand le serveur répond, alors c'est `commun.erreur.admin_requis`.

---

## 2. Éditeur de site (patron et gérants) : `SITE-EDI-`

Principes communs à toutes les fiches de l'éditeur :
- Les sites sont faits **uniquement de blocs préfaits** (SITE-EDI-03). Aucun HTML, CSS ou script saisi par le joueur, jamais.
- Le contenu vit côté serveur (`pop_tablet_sites.draft` pour le brouillon, `pop_tablet_site_versions.content` pour les versions). Le navigateur de la tablette et le futur téléphone POP lisent seulement la **version publiée** via l'API neutre (SITE-EDI-18).
- Droit « Modifier le site » (clé `site.modifier`) : Chef et Patron par défaut, réglable par le patron case par case. L'admin serveur peut toujours éditer.
- Chaque opération sur un bloc ou une page est envoyée tout de suite au serveur, qui l'applique au brouillon après validation et renvoie le brouillon à jour (ou seulement la page concernée). Il n'y a pas de bouton « Enregistrer le brouillon » : tout est enregistré à chaque action.
- Écran de l'éditeur : app « Site web » > colonne de gauche = liste des pages ; centre = la page en cours avec ses blocs empilés (chaque bloc affiché comme sur le site, avec au survol une barre : « Modifier », flèche haut, flèche bas, « Supprimer ») ; entre deux blocs un bouton « + Ajouter un bloc » ; en haut : adresse du site, statut, boutons « Aperçu », « Publier », « Versions », « Visites », « Réglages ».

### Format du contenu d'un site (`schema` 1), commun au brouillon, aux versions, à l'export et à l'API
```json
{
  "schema": 1,
  "pages": [
    { "id": "p_7f3a9c1d", "slug": "accueil", "title": "Accueil",
      "blocks": [ { "id": "b_1a2b3c4d", "type": "titre", "data": { "text": "Dynasty 8", "size": "grand", "align": "centre" } } ] }
  ]
}
```
- `id` de page : `p_` + 8 caractères `[a-z0-9]` générés par le serveur. `id` de bloc : `b_` + 8 caractères générés par le serveur.
- La première page a toujours `slug = "accueil"` et ne peut être ni supprimée ni déplacée.
- Taille max du JSON d'un site : `Config.Sites.MaxContentSize = 65536` octets.

### [SITE-EDI-01] Choisir et changer l'adresse du site
- **But** : donner au site une adresse courte et unique, du type `dynasty8.rp`, tapée dans le navigateur.
- **Qui** : Patron (non réglable, plus restrictif que `site.modifier` car l'adresse est l'identité publique) ; admin serveur.
- **Où** : Site web > bouton « Réglages » > champ « Adresse du site » > bouton « Changer ».
- **Parcours** :
  1. Le champ affiche la partie avant le point (ex. `dynasty8`) et le suffixe fixe `.rp` à droite (non modifiable).
  2. À la frappe (300 ms après la dernière touche), l'interface appelle `pop_tablet:sites:checkAddress { address }` : le serveur répond `libre`, `prise`, `reservee` ou `invalide` ; l'interface affiche une coche verte ou le message correspondant.
  3. « Changer » → confirmation → `pop_tablet:sites:setAddress { siteId, address, actionId }`.
  4. Le serveur revérifie tout, écrit l'adresse, met `address_changed_at = NOW()`, met à jour le cache des adresses (table mémoire adresse → siteId) et émet l'événement serveur `pop_tablet:siteAddressChanged (siteId, oldAddress, newAddress)`.
  5. L'ancienne adresse est libérée immédiatement ; pendant 7 jours, ouvrir l'ancienne adresse affiche « Ce site a déménagé : {nouvelle adresse} » avec un lien (table mémoire + réglage en base `pop_tablet_settings.site_redirects`, entrées purgées au démarrage si plus vieilles que 7 jours), sauf si une autre entreprise la reprend.
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| address (partie avant le suffixe) | texte | oui | `^[a-z0-9]([a-z0-9-]{1,22}[a-z0-9])$` (3 à 24 car., minuscules, chiffres, tiret, pas de tiret au début/fin ni deux tirets de suite) | slug de l'entreprise |
| suffixe | texte | auto | `Config.Sites.Suffix` | `rp` |
| address_changed_at | date | auto | — | NULL |

- **Règles serveur** : Patron ou admin ; format strict ; unicité (insensible à la casse, contrainte UNIQUE) ; mots réservés `Config.Sites.ReservedNames` refusés sauf pour l'admin ; un changement par entreprise tous les `Config.Sites.AddressCooldownDays = 7` jours (admin non limité) ; fréquence de `checkAddress` : 10 / 10 s ; `actionId`.
- **Textes et états** :
  - Libellé : « Adresse du site » (`site.reglages.adresse`) ; bouton « Changer » (`site.reglages.adresse_changer`).
  - Vérification : « Adresse libre » (`site.adresse.libre`), « Cette adresse est déjà prise. » (`site.adresse.prise`), « Cette adresse est réservée. » (`site.adresse.reservee`), « 3 à 24 caractères : lettres minuscules, chiffres et tirets. » (`site.adresse.invalide`).
  - Confirmation : « Changer l'adresse en {adresse} ? Elle ne pourra plus être changée pendant 7 jours. » (`site.adresse.confirmer`).
  - Succès : « Adresse changée : {adresse}. » (`site.adresse.ok`).
  - Erreur délai : « Adresse modifiable à partir du {date}. » (`site.adresse.delai`).
  - Redirection (navigateur) : « Ce site a déménagé : {adresse} » (`navigateur.site.demenage`).
  - Pas le droit (Chef) : champ grisé + `commun.droit.grade_requis` avec « Patron ».
- **Notifications** : aucune.
- **Liens** : annuaire (affiche l'adresse), annonces (lien vers le site), navigateur, API (SITE-EDI-18), événement `pop_tablet:siteAddressChanged`.
- **Réglages** : `Config.Sites.Suffix = 'rp'`, `Config.Sites.AddressCooldownDays = 7`, `Config.Sites.RedirectDays = 7`, `Config.Sites.ReservedNames = { 'admin', 'pop', 'tablette', 'tablet', 'system', 'systeme', 'gouv', 'gouvernement', 'www', 'test', 'annuaire', 'aide' }`.
- **Journal admin** : oui, type `site.adresse`, `before_data` = ancienne adresse, `after_data` = nouvelle.
- **Performance** : vérification par lecture du cache mémoire des adresses (aucune requête SQL par frappe).
- **Cas limites** :
  - Deux patrons valident la même adresse au même instant : la contrainte UNIQUE fait échouer le second → `site.adresse.prise`.
  - Adresse identique à l'actuelle : bouton « Changer » désactivé.
  - Entreprise archivée : son adresse reste réservée (l'entreprise peut être restaurée) ; seul l'admin peut la libérer en changeant l'adresse de l'entreprise archivée.
- **Critères d'acceptation** :
  - Étant donné un patron de Dynasty 8 dont l'adresse est `dynasty8.rp`, quand il change pour `dynasty-8`, alors `dynasty-8.rp` ouvre le site et `dynasty8.rp` affiche « Ce site a déménagé : dynasty-8.rp ».
  - Étant donné une adresse changée il y a 2 jours, quand le patron essaie encore, alors il voit « Adresse modifiable à partir du {date}. ».
  - Étant donné un Chef qui envoie `pop_tablet:sites:setAddress` à la main, quand le serveur le reçoit, alors refus `commun.erreur.pas_droit`.

### [SITE-EDI-02] Choisir un modèle de site
- **But** : partir d'une structure toute prête (pages et blocs) adaptée au métier.
- **Qui** : `site.modifier` (Chef et Patron par défaut) ; admin.
- **Où** : (a) premier lancement de l'éditeur sur un site vide : écran « Choisir un modèle » ; (b) Réglages > « Changer de modèle ».
- **Parcours** :
  1. L'écran montre 5 cartes (nom, phrase, miniature schématique faite de rectangles gris).
  2. Clic sur une carte → aperçu du modèle (rendu avec les blocs exemples).
  3. « Utiliser ce modèle » → (cas b) confirmation, car le brouillon est remplacé → `pop_tablet:sites:applyTemplate { siteId, template, actionId }`.
  4. Le serveur sauvegarde d'abord le brouillon actuel comme version (`kind = 'restauration'`, libellé auto « Avant changement de modèle ») si le brouillon n'est pas vide, puis remplace le brouillon par le contenu du modèle, avec le nom de l'entreprise injecté dans le premier bloc titre et le logo dans le premier bloc image si le logo existe. La version publiée n'est pas touchée.
- **Données** (contenu des modèles) :

| Modèle | Libellé / phrase (`site.modele.<id>.nom` / `.aide`) | Pages et blocs |
|---|---|---|
| `vitrine` | « Vitrine » / « Présenter l'entreprise simplement. » | Accueil : titre (nom), image (logo), texte (« Bienvenue chez {nom}. Présentez ici votre entreprise. »), horaires, bouton contact |
| `annonces` | « Annonces » / « Mettre en avant vos annonces (biens, offres, recrutement). » | Accueil : titre, texte, liste d'annonces (6, grille), bouton contact ; Contact : titre « Nous contacter », formulaire de demande (type contact) |
| `catalogue` | « Catalogue » / « Montrer vos produits avec leurs prix. » | Accueil : titre, image, texte, bouton contact (vers page Catalogue) ; Catalogue : titre « Catalogue », catalogue (3 articles exemples « Article 1/2/3 », prix 100/200/300) ; Contact : formulaire (type devis) |
| `services` | « Services » / « Présenter vos prestations et prendre des rendez-vous. » | Accueil : titre, texte, horaires, bouton contact ; Services : titre « Nos services », catalogue (3 prestations exemples) ; Rendez-vous : titre, formulaire (type rendez-vous) |
| `institution` | « Institution » / « Pour la police, l'hôpital, la justice : informations et démarches. » | Accueil : titre, texte, image ; Informations : titre « Informations », texte, horaires ; Démarches : titre « Faire une demande », formulaire (type contact) |

- **Règles serveur** : `site.modifier` ; modèle dans la liste ; la création des pages respecte `MaxPages` (si le réglage est inférieur au nombre de pages du modèle, les pages en trop ne sont pas créées) ; site non masqué par la modération (sinon lecture seule) ; `actionId`.
- **Textes et états** :
  - Titre : « Choisir un modèle » (`site.modele.titre`) ; bouton « Utiliser ce modèle » (`site.modele.utiliser`).
  - Confirmation : « Remplacer le brouillon par le modèle {modele} ? L'ancien brouillon est gardé dans les versions. » (`site.modele.confirmer`).
  - Succès : « Modèle appliqué. » (`site.modele.ok`).
  - Pas le droit : écran en lecture seule avec bandeau « Grade requis : {grade} ».
- **Notifications** : aucune.
- **Liens** : SITE-EDI-13 (version de sauvegarde).
- **Réglages** : aucun.
- **Journal admin** : oui, type `site.modele`, résumé « Modèle {modele} appliqué ».
- **Performance** : modèles définis dans un fichier Lua du cœur, en mémoire.
- **Cas limites** :
  - Brouillon vide : pas de version de sauvegarde créée.
  - Verrou d'édition tenu par un autre (SITE-EDI-19) : refus `site.verrou.pris`.
  - Double clic : `actionId`, une seule application et une seule version de sauvegarde.
- **Critères d'acceptation** :
  - Étant donné un site vide, quand le chef choisit « Catalogue », alors le brouillon contient 3 pages Accueil, Catalogue, Contact.
  - Étant donné un brouillon rempli, quand le chef applique « Vitrine », alors une version « Avant changement de modèle » apparaît dans l'historique.
  - Étant donné une Recrue qui envoie `pop_tablet:sites:applyTemplate`, quand le serveur le reçoit, alors refus `commun.erreur.pas_droit`.

### [SITE-EDI-03] Catalogue des blocs disponibles (définition et validation)
- **But** : définir précisément chaque bloc préfait, ses champs, ses limites et son rendu, utilisés par l'éditeur, le validateur serveur, l'import et l'API.
- **Qui** : référence technique (aucune action joueur directe).
- **Où** : fenêtre « Ajouter un bloc » (SITE-EDI-04) et formulaire « Modifier » (SITE-EDI-06).
- **Parcours** : le validateur serveur `PopTablet.Sites.validateBlock(type, data, companyId)` est appelé à chaque ajout/modification, à l'import et à la publication ; il renvoie le `data` nettoyé ou une erreur (clé de langue + nom du champ).
- **Données** (par type ; tous les textes sont nettoyés 0.3 ; toute image validée par SITE-EDI-17) :

| Type (`site.bloc.<type>.nom`) | Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|---|
| `titre` « Titre » | text | texte | oui | 1 à 80 car. | « Titre » |
| | size | liste | oui | `grand`, `moyen` | `grand` |
| | align | liste | oui | `gauche`, `centre` | `gauche` |
| `texte` « Texte » | text | texte multiligne | oui | 1 à 2000 car. ; mise en forme autorisée : `**gras**`, `*italique*`, ligne commençant par `- ` = puce ; tout le reste affiché tel quel | « Votre texte ici. » |
| `image` « Image » | url | URL | oui | SITE-EDI-17 | — |
| | caption | texte | non | 0 à 120 car. | vide |
| | size | liste | oui | `pleine`, `moyenne` | `pleine` |
| `galerie` « Galerie » | images | liste | oui | 2 à 12 éléments `{ url, caption (0 à 80 car.) }` | — |
| | columns | entier | oui | 2 ou 3 | 3 |
| `annonces` « Liste d'annonces » | count | entier | oui | 1 à 20 | 6 |
| | layout | liste | oui | `liste`, `grille` | `grille` |
| | category | texte | non | catégorie d'annonce de l'app Annonces, ou vide = toutes | vide |
| `catalogue` « Catalogue avec prix » | items | liste | oui | 1 à 50 éléments | 1 exemple |
| | items[].name | texte | oui | 1 à 60 car. | — |
| | items[].description | texte | non | 0 à 200 car. | vide |
| | items[].price | entier | oui | 0 à `Config.Sites.MaxPrice` | — |
| | items[].image | URL | non | SITE-EDI-17 | vide |
| | items[].available | booléen | oui | — | vrai |
| | currency | texte | auto | `Config.Currency` | `$` |
| `horaires` « Horaires » | days | table de 7 jours (`lundi`…`dimanche`) | oui | chaque jour : `ferme` = vrai, ou 1 à 2 plages `{ from: "HH:MM", to: "HH:MM" }`, `to` > `from` ou `to` = `"24:00"` | lun-ven 09:00-18:00, sam-dim fermé |
| | live | booléen | oui | afficher « Ouvert maintenant » si au moins un employé est en service | vrai |
| | note | texte | non | 0 à 120 car. | vide |
| `contact` « Bouton contact » | label | texte | oui | 1 à 30 car. | « Nous contacter » |
| | action | liste | oui | `formulaire` (ouvre la boîte Demandes de l'entreprise en type contact), `page` (va à une page du site), `annuaire` (ouvre la fiche annuaire de l'entreprise) | `formulaire` |
| | pageId | texte | si action = page | id d'une page du site | — |
| `formulaire` « Formulaire de demande » | title | texte | oui | 1 à 60 car. | « Faire une demande » |
| | requestType | liste | oui | `contact`, `rendez-vous`, `devis`, `depannage` | `contact` |
| | askPhone | booléen | oui | affiche un champ téléphone facultatif | vrai |
| | askDate | booléen | oui | affiche un champ date/heure souhaitée (forcé vrai pour `rendez-vous`) | faux |
| | askPosition | booléen | oui | joint la position GPS du joueur (forcé vrai pour `depannage`) | faux |
| | confirmText | texte | non | 0 à 120 car. | « Merci, votre demande a été envoyée. » |

  Rendu : fond sombre uni, texte blanc, accent = couleur de l'entreprise ; titres en police système grasse (grand 28 px, moyen 20 px) ; images avec coins arrondis 4 px ; prix alignés à droite ; jours fermés en gris ; « Ouvert maintenant » en accent, « Fermé » en gris.
- **Règles serveur** : type inconnu refusé (ou retiré à l'import) ; champs inconnus supprimés ; chaque champ validé selon le tableau ; parsing de la mise en forme du texte fait côté interface par une fonction qui ne produit que des nœuds texte (`<strong>`, `<em>`, `<li>` créés par `document.createElement`) ; un bloc `annonces` sur une entreprise sans brique `annonces` est autorisé mais affiche le vide ; un bloc `formulaire` sur une entreprise sans brique `demandes` est refusé (« Ce bloc nécessite l'app Demandes. ») ; max 1 bloc `formulaire` par page.
- **Textes et états** :
  - Noms et aides des blocs (`site.bloc.<type>.aide`) : titre « Un titre de section. » ; texte « Un paragraphe, avec gras, italique et listes. » ; image « Une image avec légende. » ; galerie « De 2 à 12 images côte à côte. » ; annonces « Vos dernières annonces, à jour automatiquement. » ; catalogue « Vos produits ou services avec leurs prix. » ; horaires « Vos horaires d'ouverture. » ; contact « Un bouton pour vous joindre. » ; formulaire « Un formulaire qui arrive dans vos Demandes. ».
  - Erreurs de validation : « {champ} : {max} caractères maximum. » (`site.bloc.erreur.longueur`), « {champ} est obligatoire. » (`site.bloc.erreur.requis`), « Prix invalide (entre 0 et {max}). » (`site.bloc.erreur.prix`), « Horaire invalide : l'heure de fin doit être après l'heure de début. » (`site.bloc.erreur.horaire`), « Une galerie contient entre 2 et 12 images. » (`site.bloc.erreur.galerie`), « Ce bloc nécessite l'app Demandes. » (`site.bloc.erreur.demandes_inactive`), « Un seul formulaire par page. » (`site.bloc.erreur.un_formulaire`).
  - Rendu vide d'une liste d'annonces : « Aucune annonce pour le moment. » (`site.bloc.annonces.vide`) ; horaires : « Ouvert maintenant » (`site.bloc.horaires.ouvert`), « Fermé » (`site.bloc.horaires.ferme`), noms des jours `jours.lundi` … `jours.dimanche`.
- **Notifications** : aucune.
- **Liens** : liste d'annonces lue en direct depuis l'app Annonces (annonces publiées et non masquées de l'entreprise) ; horaires « live » lus dans l'état du service ; formulaire → SITE-EDI-20 → Demandes ; bouton contact → Demandes / annuaire.
- **Réglages** : `Config.Sites.MaxPrice = 10000000`, `Config.Currency.Symbol = '$'`, `Config.Sites.MaxBlocksPerPage = 30`.
- **Journal admin** : non (les actions qui utilisent les blocs sont journalisées dans leurs fiches).
- **Performance** : validateur pur, sans requête SQL, sauf vérification de la brique `demandes` (cache entreprise).
- **Cas limites** :
  - Texte avec `**` non fermé : affiché tel quel avec les astérisques.
  - Horaires `22:00` → `02:00` (nuit) : refusé ; il faut deux plages sur deux jours (`22:00`-`24:00` et `00:00`-`02:00` le lendemain). Aide affichée sous le champ : « Pour une ouverture de nuit, coupe à minuit sur deux jours. » (`site.bloc.horaires.aide_nuit`).
  - Catalogue avec prix décimal `9.99` envoyé : refusé (`site.bloc.erreur.prix`), seuls les entiers sont acceptés.
- **Critères d'acceptation** :
  - Étant donné un bloc texte contenant `**Promo** <b>test</b>`, quand il est affiché, alors « Promo » est en gras et `btest/b` (sans chevrons) apparaît en texte simple.
  - Étant donné un catalogue de 51 articles envoyé à la main, quand le serveur valide, alors il refuse.
  - Étant donné un champ `onclick` ajouté au `data` d'un bloc titre par une requête forgée, quand le serveur valide, alors le champ est supprimé du bloc enregistré.

### [SITE-EDI-04] Ajouter un bloc
- **But** : insérer un nouveau bloc préfait dans une page.
- **Qui** : `site.modifier` ; admin.
- **Où** : éditeur > bouton « + Ajouter un bloc » (entre deux blocs, ou en bas de page).
- **Parcours** :
  1. Fenêtre « Ajouter un bloc » : grille des 9 types (icône, nom, aide).
  2. Clic sur un type → `pop_tablet:sites:addBlock { siteId, pageId, index, type, actionId }` (`index` = position d'insertion, 0 = tout en haut).
  3. Le serveur vérifie, crée le bloc avec ses valeurs par défaut (SITE-EDI-03), l'insère, enregistre le brouillon, renvoie la page à jour.
  4. L'interface affiche la page et ouvre directement le formulaire « Modifier » du nouveau bloc (SITE-EDI-06), sauf pour `annonces` et `horaires` dont les valeurs par défaut sont utilisables.
  5. Pour `image` et `galerie` (champ URL obligatoire sans défaut) : le bloc n'est créé qu'après validation du formulaire ; le parcours est alors : choix du type → formulaire → « Ajouter » → `addBlock` avec `data`.
- **Données** : siteId, pageId (id existant), index (0 à nombre de blocs), type (SITE-EDI-03), data (facultatif sauf image/galerie).
- **Règles serveur** : `site.modifier` ; verrou d'édition détenu par ce joueur (SITE-EDI-19) ; page existante ; `MaxBlocksPerPage` (30) ; taille totale ≤ `MaxContentSize` ; 1 formulaire max par page ; site non masqué ; fréquence `Config.Sites.EditRate = { n = 10, s = 10 }` ; `actionId`.
- **Textes et états** :
  - Titre : « Ajouter un bloc » (`site.editeur.ajouter.titre`) ; bouton entre blocs : « + Ajouter un bloc » (`site.editeur.ajouter`).
  - Erreurs : « Cette page contient déjà {max} blocs. » (`site.editeur.max_blocs`), « Site trop lourd. » (`site.editeur.trop_lourd`), `site.bloc.erreur.un_formulaire`.
  - Page vide : « Cette page est vide. » + bouton « Ajouter un premier bloc » (`site.editeur.page_vide`).
- **Notifications** : aucune.
- **Liens** : aucun en dehors du brouillon (le public ne voit rien avant publication).
- **Réglages** : `Config.Sites.MaxBlocksPerPage = 30`, `Config.Sites.EditRate = { n = 10, s = 10 }`.
- **Journal admin** : non pour les opérations de brouillon (trop nombreuses) ; la publication est journalisée (SITE-EDI-09).
- **Performance** : écriture du brouillon en base regroupée : le serveur garde le brouillon en mémoire et l'écrit au plus une fois toutes les 5 s par site (minuterie créée à la première modification, détruite après écriture), et immédiatement à la fermeture de l'éditeur, à la publication et à l'arrêt de la ressource.
- **Cas limites** :
  - Index hors limites envoyé : ramené entre 0 et le nombre de blocs.
  - Page supprimée par un autre entre-temps (impossible avec le verrou, mais si l'admin a forcé) : « Cette page n'existe plus. » (`site.editeur.page_introuvable`), rechargement.
  - Joueur qui perd son grade pendant l'édition : refus `commun.erreur.pas_droit`, éditeur passé en lecture seule.
- **Critères d'acceptation** :
  - Étant donné une page avec 2 blocs, quand le chef ajoute un bloc Titre entre les deux, alors il apparaît en 2e position avec le texte « Titre ».
  - Étant donné une page à 30 blocs, quand le chef ajoute un bloc, alors il voit « Cette page contient déjà 30 blocs. ».
  - Étant donné une requête forgée `type = 'html'`, quand le serveur la reçoit, alors refus et rien n'est ajouté.

### [SITE-EDI-05] Déplacer un bloc
- **But** : changer l'ordre des blocs d'une page.
- **Qui** : `site.modifier` ; admin.
- **Où** : éditeur > barre d'un bloc > flèche haut / flèche bas ; au clavier, bloc sélectionné + `Alt+↑` / `Alt+↓`.
- **Parcours** :
  1. Clic sur une flèche → l'interface déplace visuellement le bloc tout de suite (fondu 150 ms) et appelle `pop_tablet:sites:moveBlock { siteId, pageId, blockId, direction ('haut'|'bas'), actionId }`.
  2. Le serveur échange le bloc avec son voisin, enregistre, renvoie l'ordre des `id` de la page.
  3. Si la réponse diffère de l'ordre affiché ou est une erreur, l'interface remet l'ordre renvoyé par le serveur.
- **Données** : blockId (id existant dans la page), direction.
- **Règles serveur** : `site.modifier` ; verrou ; bloc existant dans la page ; premier bloc + haut ou dernier + bas : aucune modification, réponse `ok` ; fréquence `EditRate` ; `actionId`.
- **Textes et états** : infobulles « Monter » / « Descendre » (`site.editeur.monter` / `.descendre`) ; flèche grisée en bout de liste ; erreur `commun.erreur.serveur` avec retour à l'ordre serveur.
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : `Config.Sites.EditRate`.
- **Journal admin** : non.
- **Performance** : écriture regroupée (voir SITE-EDI-04).
- **Cas limites** :
  - Clics rapides répétés : chaque clic a son `actionId`, au-delà de 10 en 10 s → `commun.erreur.trop_vite` et l'ordre serveur est réaffiché.
  - Bloc supprimé pendant le déplacement (onglet double ouvert par le même joueur) : « Ce bloc n'existe plus. » (`site.editeur.bloc_introuvable`), page rechargée.
  - Déplacement vers une autre page : non proposé, choix définitif (copier le contenu manuellement).
- **Critères d'acceptation** :
  - Étant donné les blocs A, B, C, quand le chef clique « Descendre » sur A, alors l'ordre devient B, A, C après rechargement.
  - Étant donné le bloc C en dernier, quand le chef clique « Descendre », alors rien ne change et la flèche est grisée.
  - Étant donné un joueur sans `site.modifier` qui envoie `moveBlock`, quand le serveur le reçoit, alors refus `commun.erreur.pas_droit`.

### [SITE-EDI-06] Modifier un bloc
- **But** : changer le contenu d'un bloc existant.
- **Qui** : `site.modifier` ; admin.
- **Où** : éditeur > barre d'un bloc > « Modifier » (ou double clic sur le bloc).
- **Parcours** :
  1. Un panneau à droite s'ouvre avec le formulaire du type (champs de SITE-EDI-03 ; compteur de caractères sous chaque texte ; pour catalogue et galerie, liste d'éléments avec « Ajouter », flèches et corbeille par élément ; pour horaires, une ligne par jour avec case « Fermé » et 1 ou 2 plages).
  2. L'aperçu du bloc au centre se met à jour pendant la frappe (rendu local, sans serveur).
  3. « Enregistrer » → `pop_tablet:sites:updateBlock { siteId, pageId, blockId, data, actionId }` ; le serveur valide (SITE-EDI-03), remplace `data`, enregistre, renvoie le bloc nettoyé tel qu'enregistré.
  4. L'interface affiche le bloc renvoyé par le serveur (si le nettoyage a retiré des caractères, c'est visible tout de suite) et ferme le panneau. « Annuler » ou Échap ferme sans enregistrer (confirmation si des champs ont changé).
- **Données** : celles du type (SITE-EDI-03).
- **Règles serveur** : `site.modifier` ; verrou ; bloc existant ; validation complète ; images validées (SITE-EDI-17) ; taille totale ≤ `MaxContentSize` ; fréquence `EditRate` ; `actionId`.
- **Textes et états** :
  - Titre du panneau : « Modifier : {nom du bloc} » (`site.editeur.modifier.titre`) ; compteur « {n} / {max} » (`commun.compteur`).
  - Succès : bandeau `commun.succes.enregistre`.
  - Erreurs : celles de SITE-EDI-03 affichées sous le champ concerné ; SITE-EDI-17 pour les images.
  - Confirmation à l'annulation : « Abandonner les modifications de ce bloc ? » (`site.editeur.modifier.abandonner`).
- **Notifications** : aucune.
- **Liens** : aucun avant publication.
- **Réglages** : ceux de SITE-EDI-03.
- **Journal admin** : non.
- **Performance** : aperçu local ; un seul appel serveur par enregistrement.
- **Cas limites** :
  - Verrou expiré pendant la saisie (inactivité > 10 min) : à l'enregistrement, si personne d'autre n'a pris le verrou, il est repris automatiquement ; sinon `site.verrou.pris` et le texte saisi reste dans le panneau pour être copié.
  - Champ image avec un domaine non autorisé : erreur sous le champ, rien d'enregistré.
  - Tablette fermée pendant la saisie : modifications non enregistrées perdues (comportement voulu).
- **Critères d'acceptation** :
  - Étant donné un bloc titre « Bienvenue », quand le chef le change en « Nos offres » et enregistre, alors le brouillon contient « Nos offres ».
  - Étant donné un texte de 2001 caractères, quand le chef enregistre, alors il voit « Texte : 2000 caractères maximum. » et rien n'est enregistré.
  - Étant donné une requête forgée qui met `price = -50` dans un catalogue, quand le serveur valide, alors refus « Prix invalide (entre 0 et 10000000). ».

### [SITE-EDI-07] Supprimer un bloc
- **But** : retirer un bloc d'une page.
- **Qui** : `site.modifier` ; admin.
- **Où** : éditeur > barre d'un bloc > « Supprimer » ; au clavier, bloc sélectionné + `Suppr`.
- **Parcours** :
  1. Clic → le bloc disparaît tout de suite et un bandeau « Bloc supprimé. Annuler » reste 5 s.
  2. `pop_tablet:sites:deleteBlock { siteId, pageId, blockId, actionId }` est envoyé immédiatement ; le serveur retire le bloc du brouillon et garde en mémoire, pendant 5 min, le bloc supprimé et sa position (corbeille courte, par site, 10 derniers blocs).
  3. « Annuler » → `pop_tablet:sites:undoDelete { siteId, blockId, actionId }` : le serveur remet le bloc à sa position (ou en fin de page si la position n'existe plus).
- **Données** : blockId.
- **Règles serveur** : `site.modifier` ; verrou ; bloc existant ; « Annuler » accepté seulement dans les 5 min et si `MaxBlocksPerPage` n'est pas atteint ; `actionId`.
- **Textes et états** : bandeau « Bloc supprimé. » + bouton « Annuler » (`site.editeur.supprime` / `site.editeur.annuler_suppression`) ; erreur annulation trop tard : « Trop tard pour annuler. Le bloc reste dans la dernière version publiée. » (`site.editeur.annulation_expiree`).
- **Notifications** : aucune.
- **Liens** : aucun avant publication ; un bloc supprimé du brouillon reste dans les versions publiées.
- **Réglages** : `Config.Sites.UndoSeconds = 300`.
- **Journal admin** : non.
- **Performance** : corbeille courte en mémoire, vidée par une minuterie unique de 5 min créée à la suppression.
- **Cas limites** :
  - Suppression du seul bloc de la page : autorisé, la page affiche l'état vide.
  - Ressource redémarrée : la corbeille courte est perdue (brouillon déjà écrit en base).
  - Double clic sur « Supprimer » : un seul retrait (`actionId`).
- **Critères d'acceptation** :
  - Étant donné un bloc image, quand le chef le supprime puis clique « Annuler » dans les 5 s, alors le bloc revient à la même place.
  - Étant donné un bloc supprimé il y a 6 min, quand `undoDelete` est envoyé, alors refus « Trop tard pour annuler… ».
  - Étant donné un membre sans `site.modifier` qui envoie `deleteBlock`, quand le serveur le reçoit, alors refus et le bloc reste.

### [SITE-EDI-08] Aperçu avant publication
- **But** : voir le brouillon exactement comme les visiteurs le verront, avant de le publier.
- **Qui** : `site.modifier` ; admin.
- **Où** : éditeur > bouton « Aperçu » (en haut).
- **Parcours** :
  1. L'éditeur passe en plein écran avec le rendu du navigateur (même composant que le navigateur public, alimenté par le brouillon au lieu de la version publiée), barre d'adresse grisée affichant « {adresse} · Aperçu », menu des pages cliquable.
  2. Les blocs dynamiques sont réels : liste d'annonces (annonces actuelles), horaires « live » (état du service actuel). Le formulaire est affiché mais son bouton « Envoyer » est désactivé avec l'infobulle « Désactivé dans l'aperçu ».
  3. Un bouton « Comparer avec la version en ligne » alterne entre brouillon et version publiée (si elle existe).
  4. Boutons en haut : « Retour à l'édition » et « Publier » (SITE-EDI-09). Échap = retour à l'édition.
- **Données** : lecture seule du brouillon (`pop_tablet:sites:getDraft { siteId }`) et de la version publiée (`pop_tablet:sites:getPublished { siteId }`).
- **Règles serveur** : `site.modifier` pour lire le brouillon ; la version publiée est publique ; images invalides (domaine retiré depuis) remplacées par le cadre « Image non autorisée ».
- **Textes et états** :
  - Barre : « {adresse} · Aperçu » (`site.apercu.barre`) ; boutons « Retour à l'édition » (`site.apercu.retour`), « Comparer avec la version en ligne » (`site.apercu.comparer`), « Voir le brouillon » (`site.apercu.voir_brouillon`).
  - Infobulle : « Désactivé dans l'aperçu » (`site.apercu.formulaire_inactif`).
  - Aucune version en ligne : bouton « Comparer » grisé avec « Pas encore publié » (`site.apercu.jamais_publie`).
  - Image interdite : « Image non autorisée » (`site.image.interdite`).
- **Notifications** : aucune.
- **Liens** : rendu identique au navigateur ; aucun visiteur compté (SITE-EDI-15 ne compte pas les aperçus).
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : le brouillon est déjà en mémoire dans l'éditeur ; seule la version publiée est demandée au clic sur « Comparer » (cache serveur).
- **Cas limites** :
  - Brouillon identique à la version publiée : bouton « Publier » grisé avec « Aucune modification à publier » (`site.apercu.rien_a_publier`) ; comparaison faite côté serveur par un hachage du JSON renvoyé avec le brouillon.
  - Brouillon vide (aucun bloc) : aperçu affiche « Ce site est vide. » (`site.apercu.vide`).
  - Site masqué par la modération : aperçu possible, bandeau « Site masqué par l'administration : {raison} » (`site.masque.bandeau`).
- **Critères d'acceptation** :
  - Étant donné un brouillon avec un nouveau bloc, quand le chef ouvre l'aperçu, alors le bloc est visible, alors qu'un visiteur ne le voit pas encore.
  - Étant donné l'aperçu ouvert, quand le chef clique « Envoyer » sur le formulaire, alors rien n'est envoyé.
  - Étant donné un joueur sans `site.modifier` qui appelle `getDraft`, quand le serveur répond, alors refus `commun.erreur.pas_droit`.

### [SITE-EDI-09] Publier le site (ajout)
- **But** : rendre le brouillon visible par tous, et créer une version dans l'historique.
- **Qui** : `site.modifier` (Chef et Patron par défaut) ; admin.
- **Où** : éditeur > bouton « Publier » (en haut) ou depuis l'aperçu.
- **Parcours** :
  1. Clic → fenêtre « Publier le site ? » avec champ facultatif « Note de version » (ex. « Nouveaux prix »).
  2. « Publier » → `pop_tablet:sites:publish { siteId, note, actionId }`.
  3. Le serveur valide **tout** le brouillon (chaque bloc par SITE-EDI-03, images SITE-EDI-17, limites), crée une ligne `pop_tablet_site_versions` (`number` = dernier + 1, `kind = 'publication'`, `content` = brouillon), met `published_version_id`, `status = 'publie'`, met à jour le cache public du site, supprime les versions au-delà de `MaxVersions` (les plus anciennes, jamais celle publiée), émet `pop_tablet:sitePublished (siteId, address, versionNumber)`.
  4. Le brouillon reste égal au contenu publié ; l'éditeur affiche « Publié » et la date.
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| note | texte | non | 0 à 80 car. | vide |
| number | entier | auto | ≥ 1 | dernier + 1 |

  La note est stockée dans `content.note` de la version (champ réservé, non affiché sur le site).
- **Règles serveur** : `site.modifier` ; brique `site` active ; entreprise non archivée ; site non masqué (sinon « Site masqué par l'administration : {raison}. ») ; brouillon différent de la version publiée ; au moins 1 bloc sur la page Accueil ; fréquence `Config.Sites.PublishRate = { n = 1, s = 30 }` ; `actionId`.
- **Textes et états** :
  - Fenêtre : « Publier le site ? » (`site.publier.titre`), « Note de version (facultatif) » (`site.publier.note`), bouton « Publier » (`site.publier.valider`).
  - Succès : « Site publié. Il est visible à l'adresse {adresse}. » (`site.publier.ok`).
  - Erreurs : « La page Accueil est vide. » (`site.publier.accueil_vide`), « Aucune modification à publier. » (`site.apercu.rien_a_publier`), « Site masqué par l'administration : {raison}. » (`site.publier.masque`), « Un bloc contient une erreur (page {page}, bloc {n}). » (`site.publier.bloc_invalide`), « 30 secondes minimum entre deux publications. » (`site.publier.trop_vite`).
  - Statut en haut : « Publié le {date} » (`site.statut.publie_le`), « Modifications non publiées » (`site.statut.modifie`).
- **Notifications** : les autres membres de l'entreprise ayant `site.modifier`, connectés avec la tablette : « {joueur} a publié le site {adresse}. » (`notif.site.publie`).
- **Liens** : navigateur (nouvelle version servie), annuaire, API (SITE-EDI-18), événement `pop_tablet:sitePublished` (le futur téléphone peut vider son cache).
- **Réglages** : `Config.Sites.MaxVersions = 20`, `Config.Sites.PublishRate = { n = 1, s = 30 }`.
- **Journal admin** : oui, type `site.publie`, résumé « {adresse} publiée (version {n}) », `after_data` = note et nombre de blocs.
- **Performance** : cache public remplacé en mémoire (lectures suivantes sans SQL) ; une insertion + une mise à jour.
- **Cas limites** :
  - Bloc devenu invalide depuis son ajout (domaine d'image retiré) : publication refusée avec l'emplacement exact du bloc.
  - Double clic : `actionId`, une seule version.
  - Entreprise sans brique site (retirée par l'admin pendant l'édition) : « Cette app n'est plus disponible pour cette entreprise. ».
- **Critères d'acceptation** :
  - Étant donné un brouillon modifié, quand le chef publie, alors un visiteur qui ouvre l'adresse voit le nouveau contenu et l'historique contient une version de plus.
  - Étant donné 20 versions, quand le chef publie, alors la plus ancienne non publiée est supprimée et il en reste 20.
  - Étant donné une requête forgée `publish` par un Membre, quand le serveur la reçoit, alors refus `commun.erreur.pas_droit` et rien ne change.

### [SITE-EDI-10] Ajouter une page
- **But** : créer une page supplémentaire dans le site (ex. « Catalogue », « Contact »).
- **Qui** : `site.modifier` ; admin.
- **Où** : éditeur > colonne des pages > bouton « + Nouvelle page ».
- **Parcours** :
  1. Fenêtre : champ « Nom de la page » ; l'adresse de la page (`slug`) est calculée et affichée en dessous : « {adresse}/{slug} ».
  2. « Créer » → `pop_tablet:sites:addPage { siteId, title, actionId }`.
  3. Le serveur calcule le `slug` (minuscules, accents retirés, espaces → `-`, `^[a-z0-9-]{1,24}$`, suffixe `-2` si pris dans le site), crée la page vide à la fin de la liste, renvoie la liste des pages ; l'interface ouvre la nouvelle page.
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| title | texte | oui | 1 à 30 car. | — |
| slug | texte | auto | `^[a-z0-9-]{1,24}$`, unique dans le site, `accueil` interdit | calculé |
| nombre de pages | entier | — | 1 à `Config.Sites.MaxPages` | — |

- **Règles serveur** : `site.modifier` ; verrou ; `MaxPages` (5 par défaut, réglable par l'admin de 1 à 20, ADM-11) ; nettoyage ; taille totale ; fréquence `EditRate` ; `actionId`.
- **Textes et états** :
  - Bouton : « + Nouvelle page » (`site.pages.ajouter`) ; fenêtre « Nouvelle page » (`site.pages.ajouter_titre`), champ « Nom de la page » (`site.pages.nom`), aide « Adresse : {adresse}/{slug} » (`site.pages.adresse`), bouton « Créer » (`site.pages.creer`).
  - Erreur : « Nombre maximum de pages atteint ({max}). » (`site.pages.max`).
  - Limite atteinte : bouton grisé avec l'infobulle « {max} pages maximum ».
- **Notifications** : aucune.
- **Liens** : le menu des pages du site est généré automatiquement depuis la liste des pages (ordre de la colonne).
- **Réglages** : `Config.Sites.MaxPages = 5`.
- **Journal admin** : non.
- **Performance** : écriture regroupée (SITE-EDI-04).
- **Cas limites** :
  - Nom fait uniquement de caractères spéciaux (« !!! ») : slug `page`, puis `page-2`.
  - L'admin baisse `MaxPages` à 3 alors qu'un site en a 5 : les pages existantes restent (aucune suppression), l'ajout est bloqué jusqu'à revenir sous la limite ; bandeau dans l'éditeur « Ce site dépasse la limite de {max} pages. Les pages restent, mais aucune ne peut être ajoutée. » (`site.pages.au_dessus_limite`).
  - Double clic : une seule page.
- **Critères d'acceptation** :
  - Étant donné un site avec 1 page, quand le chef crée « Nos Véhicules », alors une page de slug `nos-vehicules` apparaît en 2e position.
  - Étant donné un site à 5 pages et `MaxPages = 5`, quand le chef crée une page, alors il voit « Nombre maximum de pages atteint (5). ».
  - Étant donné une requête forgée avec `slug = 'accueil'`, quand le serveur la reçoit, alors il ignore le slug fourni et calcule le sien depuis le titre.

### [SITE-EDI-11] Renommer et réordonner les pages
- **But** : changer le nom d'une page ou sa place dans le menu du site.
- **Qui** : `site.modifier` ; admin.
- **Où** : colonne des pages > icône crayon (renommer) ; flèches haut/bas au survol (réordonner).
- **Parcours** :
  1. Renommer : champ en place, Entrée valide → `pop_tablet:sites:renamePage { siteId, pageId, title, actionId }` ; le serveur change le titre **et** recalcule le slug (sauf pour l'accueil, slug fixe) ; les boutons contact qui pointent vers cette page restent valides (ils utilisent `pageId`).
  2. Réordonner : `pop_tablet:sites:movePage { siteId, pageId, direction, actionId }` ; l'accueil reste toujours en premier (ses flèches sont absentes ; la page 2 ne peut pas monter au-dessus).
- **Données** : title (1 à 30 car.), direction (`haut` | `bas`).
- **Règles serveur** : `site.modifier` ; verrou ; page existante ; accueil non déplaçable ; fréquence `EditRate` ; `actionId`.
- **Textes et états** : infobulles « Renommer » (`site.pages.renommer`), « Monter », « Descendre » ; succès silencieux (la liste se met à jour) ; erreur `commun.erreur.trop_long`.
- **Notifications** : aucune.
- **Liens** : menu du site.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : écriture regroupée.
- **Cas limites** :
  - Renommer avec un titre vide : `commun.erreur.champ_requis`, ancien titre remis.
  - Renommer l'accueil en « Bienvenue » : titre changé, slug reste `accueil`.
  - Échap pendant le renommage : annulé sans appel serveur.
- **Critères d'acceptation** :
  - Étant donné les pages Accueil, Contact, Catalogue, quand le chef monte Catalogue, alors le menu affiche Accueil, Catalogue, Contact.
  - Étant donné la page Contact renommée « Écrivez-nous », quand le site est publié, alors son adresse devient `{adresse}/ecrivez-nous`.
  - Étant donné une requête forgée qui monte la page 2 au-dessus de l'accueil, quand le serveur la reçoit, alors rien ne change.

### [SITE-EDI-12] Supprimer une page
- **But** : retirer une page du site.
- **Qui** : `site.modifier` ; admin.
- **Où** : colonne des pages > icône corbeille (absente sur l'accueil).
- **Parcours** :
  1. Confirmation : « Supprimer la page {titre} et ses {n} blocs ? Elle reste dans les versions publiées. ».
  2. `pop_tablet:sites:deletePage { siteId, pageId, actionId }` ; le serveur retire la page du brouillon ; les blocs `contact` d'autres pages qui pointaient vers elle passent en `action = 'formulaire'` si la brique Demandes est active, sinon `annuaire` ; le serveur renvoie la liste des blocs modifiés.
  3. L'interface affiche l'accueil et un bandeau listant les boutons modifiés si besoin.
- **Données** : pageId.
- **Règles serveur** : `site.modifier` ; verrou ; page existante et différente de l'accueil ; `actionId`.
- **Textes et états** : confirmation `site.pages.supprimer_confirmer` (texte ci-dessus) ; succès « Page supprimée. » (`site.pages.supprimee`) ; bandeau « {n} bouton(s) qui menaient à cette page ont été redirigés vers le formulaire de contact. » (`site.pages.boutons_rediriges`) ; erreur « La page d'accueil ne peut pas être supprimée. » (`site.pages.accueil_protegee`).
- **Notifications** : aucune.
- **Liens** : versions (la page reste dans l'historique, restaurable par SITE-EDI-14).
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : écriture regroupée.
- **Cas limites** :
  - Page avec un formulaire : supprimée normalement ; les demandes déjà reçues restent dans Demandes.
  - Double clic : `actionId`.
  - Visiteur sur cette page publiée au moment de la suppression : aucune incidence tant que le brouillon n'est pas publié ; après publication, l'URL de la page renvoie l'accueil avec « Cette page n'existe plus. » (`navigateur.page_introuvable`).
- **Critères d'acceptation** :
  - Étant donné une page Contact, quand le chef la supprime et confirme, alors elle disparaît du brouillon mais reste visible dans la version publiée tant qu'il ne republie pas.
  - Étant donné un bouton contact vers Contact sur l'accueil, quand Contact est supprimée, alors le bouton ouvre le formulaire de demande.
  - Étant donné une requête forgée qui supprime l'accueil, quand le serveur la reçoit, alors refus « La page d'accueil ne peut pas être supprimée. ».

### [SITE-EDI-13] Historique des versions
- **But** : voir la liste des versions publiées (et sauvegardes automatiques) du site.
- **Qui** : `site.modifier` ; admin.
- **Où** : éditeur > bouton « Versions ».
- **Parcours** :
  1. `pop_tablet:sites:listVersions { siteId, page }` → 20 versions par page, de la plus récente à la plus ancienne : numéro, date, auteur (nom RP), type (« Publication », « Restauration », « Import », « Sauvegarde automatique »), note, nombre de pages et de blocs, étiquette « En ligne » sur la version publiée.
  2. Clic sur une version → aperçu en lecture seule de cette version (même rendu que SITE-EDI-08), avec les boutons de SITE-EDI-14.
- **Données** : lecture de `pop_tablet_site_versions` (id, number, kind, author_name, created_at, note, compte de pages/blocs calculé à la volée sur le JSON de la page demandée).
- **Règles serveur** : `site.modifier` ; fréquence 5 / 5 s.
- **Textes et états** :
  - Titre : « Versions du site » (`site.versions.titre`) ; types : « Publication » (`site.versions.type.publication`), « Restauration » (`site.versions.type.restauration`), « Import » (`site.versions.type.import`) ; ligne « Version {n} · {date} · {auteur} » (`site.versions.ligne`) ; étiquette « En ligne » (`site.versions.en_ligne`).
  - Vide : « Aucune version pour l'instant. » + bouton « Publier » (`site.versions.vide`).
- **Notifications** : aucune.
- **Liens** : SITE-EDI-14.
- **Réglages** : `Config.Sites.MaxVersions = 20`.
- **Journal admin** : non (lecture).
- **Performance** : liste paginée sans le JSON complet (colonnes légères + compteurs stockés) ; le contenu complet n'est chargé qu'au clic sur une version. Pour éviter de parser le JSON, `pages_count` et `blocks_count` sont calculés une fois à l'écriture de la version et stockés dans `content` sous `meta` (`{ "meta": { "pages": 3, "blocks": 14 } }`), et lus par `JSON_EXTRACT`.
- **Cas limites** :
  - Auteur dont le personnage a été supprimé : nom gardé tel qu'enregistré (`author_name`).
  - Plus de 20 versions impossibles (purge), donc une seule page en pratique ; pagination prévue quand même.
  - Version d'import jamais publiée : visible avec le type « Import ».
- **Critères d'acceptation** :
  - Étant donné 3 publications, quand le chef ouvre « Versions », alors il voit 3 lignes, la plus récente marquée « En ligne ».
  - Étant donné un clic sur la version 1, quand l'aperçu s'ouvre, alors il montre le contenu de la version 1.
  - Étant donné un joueur extérieur à l'entreprise qui appelle `listVersions` avec le `siteId`, quand le serveur répond, alors refus `commun.erreur.pas_droit`.

### [SITE-EDI-14] Revenir à une version précédente
- **But** : annuler des modifications en reprenant le contenu d'une ancienne version.
- **Qui** : `site.modifier` ; admin.
- **Où** : Versions > aperçu d'une version > boutons « Reprendre comme brouillon » et « Remettre en ligne ».
- **Parcours** :
  1. « Reprendre comme brouillon » → confirmation → `pop_tablet:sites:restoreVersion { siteId, versionId, mode = 'brouillon', actionId }` : le serveur sauvegarde le brouillon actuel comme version `restauration` (note auto « Brouillon avant retour à la version {n} ») s'il diffère de toutes les versions, puis copie le contenu de la version dans le brouillon. Rien ne change pour les visiteurs.
  2. « Remettre en ligne » → confirmation → même appel avec `mode = 'en_ligne'` : le serveur fait l'étape 1 puis publie immédiatement (nouvelle version `restauration`, note « Retour à la version {n} »), avec toutes les validations de SITE-EDI-09.
- **Données** : versionId (version du même site), mode.
- **Règles serveur** : `site.modifier` ; verrou ; la version appartient au site ; contenu revalidé (images de domaines retirés → blocs refusés : le serveur retire ces images et renvoie la liste ; en mode `en_ligne` la publication est refusée tant qu'une image obligatoire manque, l'utilisateur doit passer par le brouillon) ; `PublishRate` pour `en_ligne` ; `actionId`.
- **Textes et états** :
  - Boutons : « Reprendre comme brouillon » (`site.versions.reprendre`), « Remettre en ligne » (`site.versions.remettre`).
  - Confirmations : « Remplacer le brouillon par la version {n} ? Le brouillon actuel est gardé dans les versions. » (`site.versions.reprendre_confirmer`) ; « Remettre la version {n} en ligne pour tout le monde ? » (`site.versions.remettre_confirmer`).
  - Succès : « Version {n} reprise dans le brouillon. » (`site.versions.reprendre_ok`) ; « Version {n} remise en ligne. » (`site.versions.remettre_ok`).
  - Erreur : « Cette version contient des images qui ne sont plus autorisées. » (`site.versions.images_interdites`).
- **Notifications** : en mode `en_ligne`, comme SITE-EDI-09 (`notif.site.publie`).
- **Liens** : SITE-EDI-09, API.
- **Réglages** : aucun en plus.
- **Journal admin** : oui, type `site.restaure`, résumé « {adresse} : retour à la version {n} ({mode}) ».
- **Performance** : une lecture de version + écritures.
- **Cas limites** :
  - Version supprimée par la purge entre l'affichage et le clic : « Cette version n'existe plus. » (`site.versions.introuvable`).
  - Restaurer la version déjà en ligne en mode `en_ligne` : « Cette version est déjà en ligne. » (`site.versions.deja_en_ligne`).
  - Version ayant plus de pages que `MaxPages` actuel : acceptée en brouillon avec le bandeau `site.pages.au_dessus_limite` ; publication autorisée (la limite bloque seulement l'ajout).
- **Critères d'acceptation** :
  - Étant donné la version 2 en ligne et un brouillon cassé, quand le chef reprend la version 2 comme brouillon, alors le brouillon redevient la version 2 et l'ancien brouillon apparaît dans les versions.
  - Étant donné la version 1, quand le chef la remet en ligne, alors les visiteurs voient la version 1 et une version 4 de type « Restauration » est créée.
  - Étant donné un `versionId` d'un autre site envoyé à la main, quand le serveur le reçoit, alors refus `site.versions.introuvable`.

### [SITE-EDI-15] Compter les visites
- **But** : compter combien de joueurs différents visitent le site chaque jour, sans coût de performance.
- **Qui** : automatique (serveur), déclenché par le navigateur de la tablette et par l'API (futur téléphone).
- **Où** : à chaque ouverture d'un site publié dans le navigateur (page d'accueil ou autre page par lien direct).
- **Parcours** :
  1. Le navigateur demande le site via `pop_tablet:browser:openSite { address, pageSlug }` ; le serveur renvoie le contenu (cache) et appelle `PopTablet.Sites.recordVisit(siteId, visitorKey)` avec `visitorKey` = identifiant license du joueur.
  2. `recordVisit` : si la paire (siteId, visitorKey) n'est pas dans l'ensemble mémoire du jour, l'ajoute et incrémente le compteur mémoire `pending[siteId]`.
  3. Écriture en base par paquets : à la première incrémentation, une minuterie de `Config.Sites.VisitFlushSeconds = 300` s est créée ; à son échéance, une seule requête `INSERT … ON DUPLICATE KEY UPDATE visits = visits + VALUES(visits)` pour tous les sites en attente, puis la minuterie disparaît. Écriture aussi à l'arrêt de la ressource.
  4. Au changement de jour (détecté à la prochaine visite : date du jour ≠ date de l'ensemble), l'ensemble est vidé.
  5. Purge : au démarrage, suppression des lignes plus vieilles que `Config.Sites.VisitRetentionDays = 90`.
- **Données** : `pop_tablet_site_visits (site_id, day, visits)` ; mémoire : `visitorsToday[siteId] = { [license] = true }`, `pending[siteId] = n`.
- **Règles serveur** : une visite = un joueur différent par site et par jour ; les membres de l'entreprise propriétaire ne sont pas comptés ; les aperçus (SITE-EDI-08) ne sont pas comptés ; les appels de l'API externe comptent seulement s'ils fournissent un `visitorKey` (SITE-EDI-18).
- **Textes et états** : aucun écran.
- **Notifications** : aucune.
- **Liens** : SITE-EDI-16 ; API `recordVisit`.
- **Réglages** : `Config.Sites.VisitFlushSeconds = 300`, `Config.Sites.VisitRetentionDays = 90`, `Config.Sites.CountOwnVisits = false`.
- **Journal admin** : non.
- **Performance** : aucune requête SQL par visite ; une requête groupée toutes les 5 min au plus, seulement s'il y a eu des visites ; ensemble mémoire borné (au-delà de 5000 visiteurs pour un site dans la journée, on arrête de stocker les clés et on compte seulement les visites restantes une fois par session de jeu).
- **Cas limites** :
  - Crash du serveur : au plus 5 minutes de visites perdues (acceptable, documenté).
  - Même joueur qui rouvre 50 fois le site : compté une fois.
  - Site masqué ou archivé : non servi, donc non compté.
- **Critères d'acceptation** :
  - Étant donné 3 joueurs différents qui ouvrent `dynasty8.rp` aujourd'hui, dont un deux fois, quand le compteur est écrit, alors la ligne du jour vaut 3.
  - Étant donné un agent de Dynasty 8 qui ouvre son propre site, quand le compteur est écrit, alors il n'est pas compté.
  - Étant donné un client qui envoie 1000 fois `openSite`, quand le serveur traite, alors la limite de fréquence (`Config.Browser.OpenRate = { n = 10, s = 10 }`) bloque au-delà et la visite n'est comptée qu'une fois.

### [SITE-EDI-16] Voir les visites du site
- **But** : montrer au patron et aux gérants le nombre de visites par jour.
- **Qui** : `site.modifier` ; admin.
- **Où** : éditeur > bouton « Visites ».
- **Parcours** :
  1. `pop_tablet:sites:visits { siteId, range (7|30|90) }` → le serveur renvoie la liste jour par jour (jours sans visite = 0) en ajoutant le compteur en attente du jour (`pending` mémoire + base).
  2. L'écran affiche trois chiffres en haut (« Aujourd'hui », « 7 derniers jours », « 30 derniers jours ») et un graphique en barres verticales simples (une barre par jour, couleur d'accent, survol = date + nombre), sélecteur 7 / 30 / 90 jours (défaut 30).
- **Données** : range (7, 30 ou 90) ; points `{ day: 'AAAA-MM-JJ', visits: n }`.
- **Règles serveur** : `site.modifier` ; range limité aux 3 valeurs ; fréquence 5 / 10 s.
- **Textes et états** :
  - Titre : « Visites » (`site.visites.titre`) ; chiffres « Aujourd'hui » (`site.visites.aujourdhui`), « 7 derniers jours » (`site.visites.7j`), « 30 derniers jours » (`site.visites.30j`) ; infobulle « {date} : {n} visites » (`site.visites.infobulle`) ; aide « Un visiteur est compté une fois par jour. Les membres de l'entreprise ne sont pas comptés. » (`site.visites.aide`).
  - Vide : « Aucune visite. » (`site.visites.vide`).
  - Jamais publié : « Visites comptées après publication. » (`site.visites.jamais_publie`).
- **Notifications** : aucune.
- **Liens** : SITE-EDI-15.
- **Réglages** : `Config.Sites.VisitRetentionDays = 90`.
- **Journal admin** : non.
- **Performance** : une requête indexée sur (site_id, day) à l'ouverture, au plus 90 lignes.
- **Cas limites** :
  - Range forgé à 3650 : refusé, ramené à 30.
  - Jour courant : inclut les visites non encore écrites.
  - Site masqué : statistiques toujours visibles.
- **Critères d'acceptation** :
  - Étant donné 5 visites aujourd'hui non encore écrites en base, quand le patron ouvre Visites, alors « Aujourd'hui » affiche 5.
  - Étant donné le sélecteur sur 7 jours, quand il clique, alors 7 barres s'affichent.
  - Étant donné un joueur d'une autre entreprise qui appelle `visits` avec ce `siteId`, quand le serveur répond, alors refus `commun.erreur.pas_droit`.

### [SITE-EDI-17] Images autorisées (liste de domaines)
- **But** : n'accepter dans les sites (et partout dans la tablette) que des images venant de domaines approuvés par le serveur.
- **Qui** : gestion de la liste : admin serveur ; vérification : automatique à chaque saisie d'image par un joueur.
- **Où** : Admin > onglet « Limites » > section « Images autorisées » (liste + champ « Ajouter un domaine » + corbeille par ligne) ; vérification dans tout champ URL d'image.
- **Parcours** :
  1. L'admin ajoute un domaine → `pop_tablet:admin:addImageDomain { domain, actionId }` ; retire → `removeImageDomain`.
  2. Le serveur enregistre la liste dans `pop_tablet_settings.image_domains` (remplace celle de `config.lua`), met à jour la liste en mémoire, l'envoie aux tablettes ouvertes (pour l'aide à la saisie uniquement).
  3. Validation `PopTablet.Sanitize.imageUrl(url)` : longueur ≤ 255 ; schéma `https://` obligatoire (sauf `nui://pop_tablet/` pour les images de la ressource) ; hôte = un domaine de la liste exactement, ou sous-domaine si l'entrée commence par `*.` ; pas d'identifiants dans l'URL (`@`), pas de port ; chemin se terminant par `.png`, `.jpg`, `.jpeg`, `.webp` ou `.gif` (avant `?`) ; images hébergées par le serveur (galerie de la tablette via screencapture) toujours acceptées par leur domaine configuré `Config.Images.HostedDomain`.
  4. À l'affichage, le serveur filtre aussi : une image d'un domaine retiré depuis est remplacée par `{ blocked = true }` dans la réponse, et l'interface affiche le cadre gris « Image non autorisée ».
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| domain | texte | oui | `^(\*\.)?[a-z0-9-]+(\.[a-z0-9-]+)+$`, 100 car. max | — |
| liste | liste | oui | 50 domaines max | `Config.Images.AllowedDomains` |

- **Règles serveur** : ACE pour modifier ; doublon refusé ; `*.com` (joker sur un domaine de premier niveau seul) refusé ; validation à chaque enregistrement d'image (blocs, logos, catalogue, galerie, import) et filtrage à chaque lecture publique.
- **Textes et états** :
  - Section : « Images autorisées » (`admin.limites.images.titre`) ; aide « Les joueurs ne peuvent mettre que des images venant de ces sites. *.exemple.com autorise tous les sous-domaines. » (`admin.limites.images.aide`) ; champ « Ajouter un domaine » (`admin.limites.images.ajouter`).
  - Erreurs admin : « Domaine invalide. Exemple : i.imgur.com » (`admin.limites.images.invalide`), « Ce domaine est déjà dans la liste. » (`admin.limites.images.doublon`), « 50 domaines maximum. » (`admin.limites.images.max`).
  - Erreurs joueur (sous le champ URL) : « Cette image vient d'un site non autorisé. Sites acceptés : {liste} » (`image.erreur.domaine`), « Le lien doit commencer par https:// » (`image.erreur.https`), « Le lien doit finir par .png, .jpg, .jpeg, .webp ou .gif » (`image.erreur.extension`), « Lien trop long (255 caractères maximum). » (`image.erreur.longueur`).
  - Affichage : « Image non autorisée » (`site.image.interdite`).
- **Notifications** : aucune.
- **Liens** : toutes les apps qui affichent des images (sites, annonces, logos, galerie, catalogue).
- **Réglages** : `Config.Images.AllowedDomains = { 'i.imgur.com', 'r2.fivemanage.com' }`, `Config.Images.HostedDomain = nil` (rempli si screencapture est configuré), `Config.Images.Extensions = { 'png', 'jpg', 'jpeg', 'webp', 'gif' }`.
- **Journal admin** : oui, types `admin.image_domaine_ajoute` / `admin.image_domaine_retire`, résumé avec le domaine.
- **Performance** : liste en mémoire (table de correspondance) ; validation sans requête.
- **Cas limites** :
  - Domaine retiré : les sites existants ne sont pas modifiés en base, l'image est seulement bloquée à l'affichage ; la publication suivante exige de remplacer l'image (SITE-EDI-09).
  - URL `https://i.imgur.com.pirate.net/a.png` : refusée (hôte exact).
  - URL `https://user@i.imgur.com/a.png` : refusée.
- **Critères d'acceptation** :
  - Étant donné la liste par défaut, quand un chef met `https://i.imgur.com/abc.png`, alors l'image est acceptée.
  - Étant donné `i.imgur.com` retiré par l'admin, quand un visiteur ouvre un site qui l'utilisait, alors il voit « Image non autorisée ».
  - Étant donné une requête forgée avec `javascript:alert(1)` comme URL d'image, quand le serveur valide, alors refus « Le lien doit commencer par https:// ».

### [SITE-EDI-18] API de lecture neutre des sites (pour le navigateur et le futur téléphone POP)
- **But** : permettre à n'importe quelle ressource (navigateur de la tablette, futur téléphone POP, autre script) de lire les sites publiés sans dépendre de l'interface de la tablette.
- **Qui** : ressources serveur (exports) ; aucune action joueur directe.
- **Où** : exports serveur de `pop_tablet`, documentés dans `docs/api-sites.md` (dossier ouvert).
- **Parcours** : la ressource appelante utilise les exports ci-dessous côté serveur et transmet elle-même le résultat à son interface. La tablette utilise les mêmes fonctions en interne pour son navigateur.
- **Données** (exports serveur, signatures exactes) :

| Export | Retour | Description |
|---|---|---|
| `getSite(address)` | `site` ou `nil, err` | Version publiée d'un site. `err` ∈ `introuvable`, `masque`, `non_publie`. |
| `getSitePage(address, pageSlug)` | `page` ou `nil, err` | Une seule page (`err` en plus : `page_introuvable`). |
| `listSites(page, perPage)` | `{ items, total }` | Sites publiés et visibles, triés par nom d'entreprise ; `perPage` ≤ 50, défaut 20. |
| `searchSites(text, page)` | `{ items, total }` | Recherche sur adresse et nom d'entreprise (2 à 40 car.). |
| `recordVisit(address, visitorKey)` | `true` ou `false` | Compte une visite (SITE-EDI-15) ; `visitorKey` = identifiant license du joueur. |
| `getSchemaVersion()` | `1` | Version du format. |

  Objet `site` renvoyé (neutre : aucune donnée d'interface, aucun identifiant de joueur) :
```lua
{
  schema = 1,
  address = 'dynasty8.rp',
  company = { name = 'Dynasty 8', logo = 'https://i.imgur.com/abc.png', color = '#16A34A', open = true },
  version = 7, publishedAt = '2026-11-24T18:30:00Z',
  pages = { { id = 'p_7f3a9c1d', slug = 'accueil', title = 'Accueil', blocks = { --[[ blocs SITE-EDI-03, images bloquées remplacées par { blocked = true } ]] } } },
  dynamic = { annonces = { --[[ pour chaque bloc annonces : blockId → liste { id, title, price, image, createdAt } ]] }, openNow = true }
}
```
  Exemple :
```lua
local site, err = exports.pop_tablet:getSite('dynasty8.rp')
if not site then print('Site indisponible : ' .. err) return end
print(site.company.name, #site.pages)
```
  Événements serveur émis (pour vider un cache côté appelant) : `pop_tablet:sitePublished (siteId, address, version)`, `pop_tablet:siteAddressChanged (siteId, oldAddress, newAddress)`, `pop_tablet:siteHidden (siteId, address)`, `pop_tablet:siteRestored (siteId, address)`.
- **Règles serveur** : exports lisant le cache public (version publiée seulement, jamais le brouillon) ; filtrage des images (SITE-EDI-17) ; site masqué → `nil, 'masque'` ; entreprise archivée ou brique site absente → `nil, 'introuvable'` ; textes déjà nettoyés ; l'appelant reste responsable d'afficher en texte (pas de HTML).
- **Textes et états** : l'API ne renvoie aucun texte affiché, seulement des codes `err` ; la tablette les traduit : `introuvable` → « Ce site n'existe pas. » (`navigateur.site.introuvable`), `masque` → « Ce site est indisponible pour le moment. » (`navigateur.site.masque`), `non_publie` → « Ce site est en construction. » (`navigateur.site.construction`).
- **Notifications** : aucune.
- **Liens** : navigateur, annuaire, futur téléphone POP, SITE-EDI-15.
- **Réglages** : `Config.Sites.ApiEnabled = true` (si faux, les exports renvoient `nil, 'desactive'`, la tablette utilise des fonctions internes identiques).
- **Journal admin** : non.
- **Performance** : cache public en mémoire : sites publiés chargés à la première lecture (pas au démarrage), conservés tant que le serveur tourne, remplacés à chaque publication ; partie `dynamic` calculée à la demande avec un cache de 30 s par site.
- **Cas limites** :
  - Adresse avec majuscules ou espaces (`" Dynasty8.RP "`) : normalisée (trim + minuscules) avant recherche.
  - Ancienne adresse redirigée : `getSite` renvoie `nil, 'introuvable', { movedTo = 'dynasty-8.rp' }` (3e valeur).
  - Appel en boucle par un script tiers : aucune limite de fréquence sur les exports (code serveur de confiance), mais réponses depuis le cache sans SQL.
- **Critères d'acceptation** :
  - Étant donné `dynasty8.rp` publié, quand une autre ressource appelle `exports.pop_tablet:getSite('dynasty8.rp')`, alors elle reçoit `schema = 1` et les pages publiées, sans le brouillon.
  - Étant donné un site masqué, quand `getSite` est appelé, alors le retour est `nil, 'masque'`.
  - Étant donné un client qui tente d'appeler l'export depuis son côté client, quand il essaie, alors rien ne se passe : les exports n'existent que côté serveur et aucun événement réseau ne les relaie sans la limite de fréquence du navigateur.

### [SITE-EDI-19] Verrou d'édition (un seul éditeur à la fois) (ajout)
- **But** : éviter que deux gérants modifient le même site en même temps et s'écrasent mutuellement.
- **Qui** : automatique pour tout joueur `site.modifier` ; l'admin et le Patron peuvent reprendre la main.
- **Où** : ouverture de l'éditeur (app Site web).
- **Parcours** :
  1. À l'ouverture : `pop_tablet:sites:openEditor { siteId }`. Si personne ne tient le verrou ou s'il a expiré, le serveur l'attribue (`lock_identifier`, `lock_name`, `lock_until = maintenant + 10 min`) et renvoie le brouillon.
  2. Chaque action d'édition réussie repousse `lock_until` à maintenant + 10 min (en mémoire, écrit avec le brouillon).
  3. Si le verrou est tenu par un autre : l'éditeur s'ouvre en lecture seule avec un bandeau et, pour le Patron/admin, un bouton « Prendre la main ».
  4. Fermeture de l'éditeur, de la tablette ou déconnexion : le serveur libère le verrou (`pop_tablet:sites:closeEditor` ou événement `playerDropped`).
  5. « Prendre la main » → `pop_tablet:sites:takeLock` : le verrou passe au demandeur ; l'ancien éditeur reçoit un message et passe en lecture seule (ses modifications déjà enregistrées sont gardées).
- **Données** : lock_identifier, lock_name, lock_until (voir 0.4).
- **Règles serveur** : toutes les opérations d'édition (SITE-EDI-02, 04 à 07, 10 à 12, 14) vérifient que l'appelant tient le verrou ; « Prendre la main » réservé Patron et admin.
- **Textes et états** :
  - Bandeau : « {joueur} modifie le site. Lecture seule. » (`site.verrou.pris`) ; bouton « Prendre la main » (`site.verrou.prendre`).
  - Message à l'ancien éditeur : « {joueur} a pris la main sur l'édition du site. Vos modifications sont enregistrées. » (`site.verrou.perdu`).
- **Notifications** : `site.verrou.perdu` à l'ancien éditeur (si tablette ouverte).
- **Liens** : toutes les fiches d'édition.
- **Réglages** : `Config.Sites.LockMinutes = 10`.
- **Journal admin** : oui pour « Prendre la main » (type `site.verrou_repris`).
- **Performance** : verrou en mémoire, écrit en base avec le brouillon ; aucune minuterie (l'expiration est vérifiée au moment où quelqu'un demande le verrou).
- **Cas limites** :
  - Crash du serveur : à la relance, les verrous en base sont ignorés s'ils sont expirés (10 min) ; tous les verrous sont remis à zéro au démarrage.
  - Même joueur sur deux sessions (reconnexion rapide) : même identifiant, verrou repris automatiquement.
  - Joueur qui perd son grade : verrou libéré à sa prochaine action refusée.
- **Critères d'acceptation** :
  - Étant donné le Chef A dans l'éditeur, quand le Chef B l'ouvre, alors B voit « A modifie le site en ce moment. ».
  - Étant donné A inactif depuis 11 min, quand B ouvre l'éditeur, alors B obtient le verrou.
  - Étant donné B en lecture seule qui envoie `addBlock` à la main, quand le serveur le reçoit, alors refus `site.verrou.pris`.

### [SITE-EDI-20] Envoyer un formulaire de demande depuis un site
- **But** : qu'un visiteur envoie une demande (contact, rendez-vous, devis, dépannage) qui arrive dans la boîte « Demandes » de l'entreprise.
- **Qui** : tout joueur ayant une tablette (navigateur) ; plus tard le téléphone POP via l'export `submitSiteForm`.
- **Où** : navigateur > site > bloc « Formulaire de demande » > bouton « Envoyer ».
- **Parcours** :
  1. Le visiteur remplit : nom (prérempli avec le nom RP, non modifiable), téléphone (si `askPhone`), date/heure souhaitée (si `askDate`), message ; si `askPosition`, une case cochée « Joindre ma position » (décochable sauf type dépannage).
  2. « Envoyer » → `pop_tablet:browser:submitForm { address, pageId, blockId, phone, date, message, attachPosition, actionId }`.
  3. Le serveur vérifie le bloc dans la **version publiée** (le type de demande vient du bloc, jamais du client), nettoie, lit la position du joueur côté serveur (`GetEntityCoords(GetPlayerPed(src))`) si demandée, crée la demande via l'API interne de l'app Demandes (`PopTablet.Requests.create(companyId, { type, fromIdentifier, fromName, phone, date, message, coords, source = 'site' })`).
  4. Le visiteur voit le texte de confirmation du bloc ; les membres concernés sont notifiés par l'app Demandes.
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| phone | texte | non | 0 à 20 car., chiffres, espaces, `+`, `-` | vide |
| date | date-heure | si askDate | dans le futur, au plus 30 jours | — |
| message | texte multiligne | oui | 10 à 1000 car. | — |
| attachPosition | booléen | non | forcé vrai pour dépannage | selon bloc |

- **Règles serveur** : bloc existant dans la version publiée et de type `formulaire` ; site visible ; entreprise avec brique `demandes` active ; fréquence `Config.Sites.FormRate = { n = 1, s = 600 }` par joueur et par entreprise (1 demande / 10 min) ; un joueur ne peut pas écrire à sa propre entreprise ; nettoyage ; `actionId`.
- **Textes et états** :
  - Champs : « Nom » (`site.form.nom`), « Téléphone (facultatif) » (`site.form.telephone`), « Date souhaitée » (`site.form.date`), « Message » (`site.form.message`), « Joindre ma position » (`site.form.position`), bouton « Envoyer » (`site.form.envoyer`).
  - Succès : texte `confirmText` du bloc, sinon « Merci, votre demande a été envoyée. » (`site.form.ok`).
  - Erreurs : « Le message doit faire au moins 10 caractères. » (`site.form.message_court`), « Demande déjà envoyée à cette entreprise. Réessayez dans {minutes} min. » (`site.form.trop_tot`), « Cette entreprise ne reçoit pas de demandes pour le moment. » (`site.form.indisponible`), « Choisissez une date dans les 30 prochains jours. » (`site.form.date_invalide`), « Impossible d'envoyer une demande à sa propre entreprise. » (`site.form.propre_entreprise`).
- **Notifications** : gérées par l'app Demandes (membres ayant « Répondre aux demandes », tablette sur eux).
- **Liens** : Demandes (une seule boîte par entreprise) ; dispatch mécano si type dépannage (géré par Demandes).
- **Réglages** : `Config.Sites.FormRate = { n = 1, s = 600 }`.
- **Journal admin** : non (la demande elle-même est tracée dans Demandes).
- **Performance** : un appel, une insertion faite par l'app Demandes.
- **Cas limites** :
  - Bloc supprimé du brouillon mais encore dans la version publiée : la demande est acceptée (seule la version publiée compte).
  - `requestType` forgé dans la requête : ignoré, le type vient du bloc.
  - Visiteur sans tablette (futur téléphone) : export serveur `submitSiteForm(source, address, blockId, fields)` avec les mêmes règles.
- **Critères d'acceptation** :
  - Étant donné le formulaire « devis » de `lscustoms.rp`, quand un visiteur envoie un message de 40 caractères, alors une demande de type devis apparaît dans les Demandes de Los Santos Customs.
  - Étant donné une demande envoyée il y a 3 min, quand le même joueur réessaie, alors il voit « Demande déjà envoyée à cette entreprise. Réessayez dans 7 min. ».
  - Étant donné une requête forgée avec des coordonnées GPS fausses, quand le serveur traite, alors il ignore les coordonnées reçues et utilise la position serveur du joueur.

---

### [SITE-EDI-21] Réglages du site : type, description, site caché, maintenance (ajout relecture)
- **But** : donner au navigateur (fichier 06, NAV-01 à NAV-12) les informations qu'il affiche : type de site, résumé, site caché (non répertorié) et page de maintenance.
- **Qui** : `site.modifier` (Chef et Patron par défaut, réglable) ; admin serveur.
- **Où** : Éditeur de site > bouton « Réglages du site » (icône engrenage) en haut à droite.
- **Parcours** :
  1. Fenêtre « Réglages du site » : « Type de site » (liste `Config.Browser.SiteTypes` : « Entreprise », « Service public », « Média », « Boutique », « Loisirs », « Association », « Autre »), « Description » (140 car., affichée dans la recherche), interrupteur « Site caché » (« Accessible seulement par son adresse : absent de la recherche, des suggestions, de la carte et de l'annuaire »), interrupteur « Maintenance » + « Message de maintenance » (200 car., facultatif).
  2. « Enregistrer » → `pop_tablet:sites:settings { siteId, siteType, description, unlisted, maintenance, maintenanceMessage, actionId }`.
  3. Serveur : droit, nettoyage (BASE-MOT-12), valeurs dans les listes ; écrit `site_type`, `description`, `unlisted`, `maintenance`, `maintenance_message` de `pop_tablet_sites` ; vide le cache du site ; émet `pop_tablet:sitePublished` (le navigateur recharge son cache).
  4. Correspondance avec le navigateur (fichier 06) : `status = 'online'` = site `publie` sans maintenance ; `'maintenance'` = site `publie` avec `maintenance = 1` ; `'offline'` = site `brouillon` ou `masque` (masqué par l'admin) ; `hidden` du navigateur = `unlisted`.
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| site_type | texte | oui | une clé de `Config.Browser.SiteTypes` | `entreprise` (`service_public` pour le modèle `institution`) |
| description | texte | non | 140 car. | vide |
| unlisted | booléen | oui | — | faux |
| maintenance | booléen | oui | — | faux |
| maintenance_message | texte | non | 200 car. | vide (texte par défaut du navigateur) |

- **Règles serveur** : `site.modifier` ; verrou d'édition non requis (réglages séparés du contenu) ; fréquence 1 / 5 s ; un site masqué par l'admin reste `offline` quels que soient ces réglages.
- **Textes et états** : titre « Réglages du site » (`site.reglages.titre`) ; champs `site.reglages.type`, `site.reglages.description`, `site.reglages.cache` « Site caché », `site.reglages.cache_aide` « Accessible seulement par son adresse. », `site.reglages.maintenance` « Maintenance », `site.reglages.message` « Message de maintenance » ; succès « Réglages enregistrés. » (`site.reglages.ok`) ; pas le droit : bouton grisé + `commun.droit.grade_requis`.
- **Notifications** : aucune.
- **Liens** : Navigateur (NAV-01, NAV-03, NAV-04, NAV-11), Carte (OUT-CAR), Annuaire (ANNU).
- **Réglages** : `Config.Browser.SiteTypes` (fichier 06).
- **Journal admin** : oui, type `site.reglages`, `before_data` / `after_data`.
- **Performance** : une écriture ; cache du site invalidé.
- **Cas limites** : description vide → la recherche affiche seulement le nom ; site caché déjà en favori d'un joueur → reste accessible par son adresse ; maintenance activée pendant qu'un joueur visite → il voit la page de maintenance à sa prochaine navigation.
- **Critères d'acceptation** :
  - Étant donné un site caché, quand un civil tape le début de son nom, alors il n'apparaît pas dans les suggestions, mais l'adresse complète l'ouvre.
  - Étant donné un site en maintenance, quand un civil l'ouvre, alors il voit la page de maintenance ; un Chef de l'entreprise voit l'aperçu.
  - Étant donné une Recrue qui envoie `sites:settings` à la main, alors refus `pas_droit`.

## 3. Admin serveur : `ADM-`

### [ADM-01] Accès au panneau admin (ajout)
- **But** : donner aux administrateurs du serveur un accès unique et sûr à tous les outils d'administration.
- **Qui** : joueurs ACE `pop.tablet.admin`. Non réglable (le nom de l'ACE est fixe).
- **Où** : (a) app « Admin » sur l'écran d'accueil de la tablette, visible seulement pour les admins ; (b) commande `/tablette_admin` (nom réglable) qui ouvre la tablette directement sur l'app Admin, même sans tablette dans l'inventaire.
- **Parcours** :
  1. À l'ouverture de la tablette, le serveur ajoute `isAdmin = true` dans le contexte envoyé à l'interface si l'ACE est présente (vérifiée à chaque ouverture, pas mise en cache).
  2. L'app Admin affiche les onglets dans l'ordre de 0.7 ; l'onglet par défaut est « Entreprises ».
  3. Commande `/tablette_admin` : le serveur vérifie l'ACE ; sinon message `commun.erreur.admin_requis` en notification simple.
  4. Chaque appel `pop_tablet:admin:*` et `pop_tablet:companies:*` (admin) revérifie l'ACE côté serveur.
- **Données** : aucune stockée. Contexte : `isAdmin` (booléen).
- **Règles serveur** : `IsPlayerAceAllowed(src, 'pop.tablet.admin')` à chaque appel ; un admin qui perd l'ACE en cours de session est refusé dès l'appel suivant.
- **Textes et états** :
  - Nom de l'app : « Admin » (`admin.nom`) ; onglets : « Entreprises », « Tablettes », « Journal », « Modération », « Apps », « Limites », « Caméras », « Performance » (`admin.onglet.entreprises`, `.tablettes`, `.journal`, `.moderation`, `.apps`, `.limites`, `.cameras`, `.performance`).
  - Pas le droit : app invisible ; commande → « Réservé aux administrateurs du serveur. » (`commun.erreur.admin_requis`).
  - Aide d'installation (console au démarrage si aucun joueur n'a l'ACE dans `server.cfg` : impossible à savoir, donc toujours affiché une fois) : « [POP Tablet] Pour donner l'accès admin : add_ace group.admin pop.tablet.admin allow ».
- **Notifications** : aucune.
- **Liens** : tous les onglets ADM et SITE-CRE.
- **Réglages** : `Config.Admin.Command = 'tablette_admin'` (`false` pour désactiver la commande).
- **Journal admin** : oui, type `admin.ouverture`, une ligne par ouverture du panneau (au plus une par admin toutes les 10 min pour ne pas noyer le journal).
- **Performance** : aucune donnée admin chargée tant que l'app Admin n'est pas ouverte ; chaque onglet charge ses données à son ouverture.
- **Cas limites** :
  - Admin sans tablette qui utilise la commande : la tablette s'ouvre en mode admin seul (seule l'app Admin est disponible), aucun numéro de série associé.
  - ACE retirée pendant que le panneau est ouvert : appel suivant refusé, l'app se ferme avec le message `commun.erreur.admin_requis`.
  - Client qui force `isAdmin = true` dans l'interface : il voit les écrans, mais chaque appel serveur est refusé, aucune donnée n'est renvoyée.
- **Critères d'acceptation** :
  - Étant donné un joueur ACE `pop.tablet.admin`, quand il ouvre la tablette, alors l'app Admin apparaît.
  - Étant donné un joueur normal qui tape `/tablette_admin`, quand la commande s'exécute, alors il voit « Réservé aux administrateurs du serveur. ».
  - Étant donné un joueur normal qui appelle `pop_tablet:admin:listTablets` depuis son client, quand le serveur répond, alors c'est `commun.erreur.admin_requis` sans données.

### [ADM-02] Couper ou rallumer une app
- **But** : désactiver une app (brique ou app perso) pour tout le serveur, par exemple en cas de bug ou d'abus, sans redémarrer.
- **Qui** : admin serveur.
- **Où** : Admin > onglet « Apps » > liste des apps avec un interrupteur par ligne.
- **Parcours** :
  1. L'onglet liste : les briques de 0.5, les outils (galerie, navigateur, annuaire…), les apps perso chargées (PERSO-01) ; pour chacune : icône, nom, interrupteur « Active / Coupée », nombre de tablettes l'ayant ouverte dans la dernière heure.
  2. Basculer sur « Coupée » → fenêtre avec champ « Message affiché aux joueurs » (facultatif) → `pop_tablet:admin:setAppEnabled { appId, enabled = false, message, actionId }`.
  3. Le serveur enregistre dans `pop_tablet_settings.disabled_apps` (`{ [appId] = { message, by, at } }`), met à jour la table mémoire, envoie l'événement client `pop_tablet:client:appState (appId, false, message)` aux seuls joueurs dont la tablette est ouverte ; une app ouverte se ferme avec le message.
  4. Tous les appels serveur de cette app sont refusés tant qu'elle est coupée (vérification centralisée dans le routeur des rappels, par préfixe `pop_tablet:<appId>:`).
  5. Rallumer : interrupteur → `setAppEnabled { enabled = true }`, retrait de la liste, même diffusion.
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| appId | texte | oui | app connue | — |
| enabled | booléen | oui | — | vrai |
| message | texte | non | 0 à 120 car. | « Cette app est temporairement indisponible. » |

- **Règles serveur** : ACE ; l'app « Admin » ne peut pas être coupée ; les liens automatiques continuent pour les données déjà émises (une amende déjà créée reste payable si Factures est active) ; si Factures est coupée, les autres apps qui créent des factures (amende police, devis mécano) reçoivent un refus « L'app Factures est coupée par l'administration. » ; `actionId`.
- **Textes et états** :
  - Interrupteur : « Active » / « Coupée » (`admin.apps.active` / `.coupee`) ; colonne « Ouvertures (1 h) » (`admin.apps.ouvertures`).
  - Fenêtre : « Couper {app} ? » (`admin.apps.couper_titre`), « Message affiché aux joueurs » (`admin.apps.message`).
  - Message joueur par défaut : « Cette app est temporairement indisponible. » (`commun.app_coupee`) ; sur l'icône d'accueil : icône grisée + cadenas.
  - Erreur : « L'app Admin ne peut pas être coupée. » (`admin.apps.admin_protegee`) ; erreur inter-app : « L'app {app} est coupée par l'administration. » (`commun.app_coupee_lien`).
  - Succès : « {app} coupée. » / « {app} rallumée. » (`admin.apps.coupee_ok` / `.rallumee_ok`).
- **Notifications** : joueurs tablette ouverte dans l'app : fermeture avec le message.
- **Liens** : toutes les apps ; signaux API : export `isAppEnabled(appId)` pour les scripts tiers.
- **Réglages** : `Config.Apps.Disabled = {}` (apps coupées dès l'installation, fusionnées avec la liste en base).
- **Journal admin** : oui, types `admin.app_coupee` / `admin.app_rallumee`, avec le message.
- **Performance** : vérification par table mémoire (O(1)) dans le routeur ; compteur « ouvertures 1 h » = petit tableau mémoire par app (horodatages des 60 dernières minutes, nettoyé à la lecture).
- **Cas limites** :
  - Joueur en train de payer une facture quand Factures est coupée : l'appel de paiement est refusé, rien n'est débité.
  - App perso qui a des appels en cours : refusés avec le message.
  - Redémarrage : l'état coupé est relu en base.
- **Critères d'acceptation** :
  - Étant donné l'app Stock coupée, quand un employé ouvre la tablette, alors l'icône Stock est grisée et l'ouverture affiche « Cette app est temporairement indisponible. ».
  - Étant donné Stock coupée, quand un client envoie `pop_tablet:stock:update`, alors le serveur refuse.
  - Étant donné un non-admin qui appelle `setAppEnabled`, quand le serveur répond, alors c'est `commun.erreur.admin_requis`.

### [ADM-03] Liste des tablettes
- **But** : voir toutes les tablettes existantes avec leur numéro et leur propriétaire.
- **Qui** : admin serveur.
- **Où** : Admin > onglet « Tablettes ».
- **Parcours** :
  1. `pop_tablet:admin:listTablets { page, search, filter }` → 20 par page, triées par dernière utilisation décroissante : numéro de série, propriétaire (nom RP + identifiant license en petit), en ligne (pastille), dernière utilisation, état (« Normale », « Bloquée jusqu'à {heure} », « Réinitialisée »).
  2. Recherche par numéro, nom ou identifiant (2 à 40 car.) ; filtres « Toutes », « Bloquées », « En ligne ».
  3. Clic sur une ligne → détail avec boutons « Réinitialiser » (ADM-04), « Débloquer » (ADM-05, visible si bloquée).
  4. Bouton « Donner une tablette » en haut (ADM-06).
- **Données** : colonnes de `pop_tablet_devices` (0.4). Le numéro est au format `PT-` + 6 caractères parmi `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (sans 0/O/1/I), généré par le serveur, unique.
  Rattachement d'une tablette : si l'inventaire gère les métadonnées (ox_inventory, qs-inventory, qb-inventory), chaque objet `pop_tablet` porte `metadata.serial` ; sinon (inventaire ESX de base), la tablette est rattachée au personnage : une tablette par personnage, numéro attribué à la première ouverture.
- **Règles serveur** : ACE ; recherche nettoyée et échappée ; fréquence 5 / 5 s.
- **Textes et états** :
  - Colonnes : « Numéro », « Propriétaire », « Dernière utilisation », « État » (`admin.tablettes.col_numero`, `.col_proprietaire`, `.col_derniere`, `.col_etat`) ; états « Normale » (`admin.tablettes.etat.normale`), « Bloquée jusqu'à {heure} » (`admin.tablettes.etat.bloquee`), « Réinitialisée » (`admin.tablettes.etat.reinitialisee`), « Sans propriétaire » (`admin.tablettes.sans_proprietaire`).
  - Vide : « Aucune tablette pour l'instant. » + bouton « Donner une tablette » (`admin.tablettes.vide`) ; recherche vide « Aucune tablette ne correspond. » (`admin.tablettes.recherche_vide`).
- **Notifications** : aucune.
- **Liens** : ADM-04, ADM-05, ADM-06 ; exports `ResetTablet` / `ReplaceTablet` (BASE-OBJ-08).
- **Réglages** : `Config.Item.Name = 'pop_tablet'`.
- **Journal admin** : non (lecture).
- **Performance** : requête paginée indexée ; pastille « en ligne » calculée depuis la table mémoire des joueurs connectés.
- **Cas limites** :
  - Tablette dont l'objet a été détruit/jeté : la ligne reste (historique), « Dernière utilisation » ancienne.
  - Propriétaire supprimé (personnage effacé) : affiché « Sans propriétaire ».
  - 10 000 tablettes : pagination, aucune lecture complète.
- **Critères d'acceptation** :
  - Étant donné 45 tablettes, quand l'admin ouvre l'onglet, alors il voit 20 lignes et la pagination.
  - Étant donné la recherche « PT-7K », quand il tape, alors seules les tablettes dont le numéro contient « PT-7K » s'affichent.
  - Étant donné un non-admin qui appelle `listTablets`, quand le serveur répond, alors c'est `commun.erreur.admin_requis`.

### [ADM-04] Réinitialiser une tablette
- **But** : remettre une tablette à neuf (données personnelles effacées, code retiré, propriétaire retiré), par exemple après une revente ou un vol RP.
- **Qui** : admin serveur. Le même effacement est disponible pour tout script du serveur (boutique, réparateur) par l'export `exports.pop_tablet:ResetTablet(serial)` (BASE-OBJ-08) ; la tablette ne vend rien elle-même.
- **Où** : Tablettes > détail > « Réinitialiser ».
- **Parcours** :
  1. Confirmation : « Réinitialiser {numéro} ? Le code, les réglages, les notes et la galerie personnelle de cette tablette seront effacés. Les données des entreprises ne sont pas touchées. ».
  2. `pop_tablet:admin:resetTablet { serial, actionId }`.
  3. Le serveur : met `owner_identifier`, `owner_name`, `pin_hash` à NULL, `failed_attempts = 0`, `locked_until = NULL`, `wiped_at = NOW()` ; supprime les données personnelles liées au numéro (réglages perso, notes perso, photos de la galerie personnelle non utilisées comme preuve ; les photos utilisées dans un rapport ou une preuve sont détachées de la tablette et gardées) ; supprime les données `pop_tablet_appdata` de scope `player` rattachées à ce numéro (si l'app perso stocke par numéro ; par défaut le scope player est rattaché au personnage, donc non touché).
  4. Si la tablette est ouverte par quelqu'un, elle se ferme ; au prochain allumage, l'assistant de premier démarrage s'affiche (choix du code) et le joueur qui l'allume en devient propriétaire.
- **Données** : serial.
- **Règles serveur** : ACE ; tablette existante ; `actionId` ; aucune donnée sensible effacée (factures, casier, preuves, mouvements d'argent appartiennent aux entreprises, pas à la tablette).
- **Textes et états** :
  - Confirmation `admin.tablettes.reinitialiser_confirmer` (texte ci-dessus) ; bouton « Réinitialiser » (`admin.tablettes.reinitialiser`).
  - Succès : « Tablette {numéro} réinitialisée. » (`admin.tablettes.reinitialiser_ok`).
  - Erreur : « Tablette introuvable. » (`admin.tablettes.introuvable`).
- **Notifications** : ancien propriétaire connecté : « Tablette {numéro} réinitialisée par l'administration. » (`notif.tablette.reinitialisee`).
- **Liens** : galerie (photos personnelles), réglages ; BASE-OBJ-08 (export `ResetTablet`, même effacement), BASE-OBJ-09 (commande `/tablette_reset`).
- **Réglages** : aucun.
- **Journal admin** : oui, type `admin.tablette_reinitialisee`, `before_data` = propriétaire, nombre de photos supprimées.
- **Performance** : une transaction.
- **Cas limites** :
  - Tablette en cours d'utilisation : fermée immédiatement, le joueur reçoit la notification.
  - Double clic : `actionId`.
  - Tablette rattachée au personnage (inventaire sans métadonnées) : même effet ; le personnage garde le même numéro.
- **Critères d'acceptation** :
  - Étant donné la tablette PT-7KQ2MX avec un code, quand l'admin la réinitialise, alors au prochain allumage l'assistant de premier démarrage s'affiche.
  - Étant donné une photo utilisée comme preuve dans une affaire, quand la tablette est réinitialisée, alors la preuve reste visible dans l'affaire.
  - Étant donné un non-admin qui appelle `resetTablet`, quand le serveur répond, alors c'est `commun.erreur.admin_requis`.

### [ADM-05] Débloquer une tablette
- **But** : rendre l'accès à une tablette bloquée après trop de codes faux, ou retirer un code oublié.
- **Qui** : admin serveur.
- **Où** : Tablettes > détail > « Débloquer » (si bloquée) et « Retirer le code » (si un code existe).
- **Parcours** :
  1. « Débloquer » → `pop_tablet:admin:unlockTablet { serial, removePin = false, actionId }` : `failed_attempts = 0`, `locked_until = NULL`.
  2. « Retirer le code » → même appel avec `removePin = true` : en plus `pin_hash = NULL` ; au prochain allumage le propriétaire est invité à choisir un nouveau code (facultatif).
  3. Si la tablette est ouverte sur l'écran de code, l'écran se met à jour immédiatement (événement client au propriétaire).
- **Données** : serial, removePin (booléen).
- **Règles serveur** : ACE ; tablette existante ; `actionId`. Règle de blocage (rappel, définie dans la fiche de base) : 5 codes faux → bloquée `Config.Lock.LockSeconds = 300` secondes (5 min).
- **Textes et états** : boutons « Débloquer » (`admin.tablettes.debloquer`), « Retirer le code » (`admin.tablettes.retirer_code`) ; succès « Tablette {numéro} débloquée. » (`admin.tablettes.debloquer_ok`), « Code retiré de {numéro}. » (`admin.tablettes.code_retire_ok`) ; « Cette tablette n'est pas bloquée. » (`admin.tablettes.pas_bloquee`).
- **Notifications** : propriétaire connecté : « Tablette débloquée par l'administration. » (`notif.tablette.debloquee`).
- **Liens** : écran de verrouillage de la base.
- **Réglages** : `Config.Lock.MaxFails = 5`, `Config.Lock.LockSeconds = 300`.
- **Journal admin** : oui, type `admin.tablette_debloquee` (avec `removePin`).
- **Performance** : une mise à jour.
- **Cas limites** :
  - Tablette non bloquée : « Débloquer » masqué ; appel forcé → `admin.tablettes.pas_bloquee`.
  - Tablette sans code : « Retirer le code » masqué.
  - Blocage expiré naturellement entre l'affichage et le clic : réponse `ok`, rien à faire.
- **Critères d'acceptation** :
  - Étant donné une tablette bloquée 5 min, quand l'admin clique « Débloquer », alors le propriétaire peut retaper son code immédiatement.
  - Étant donné « Retirer le code », quand le propriétaire rallume, alors aucun code n'est demandé.
  - Étant donné un non-admin qui appelle `unlockTablet`, quand le serveur répond, alors c'est `commun.erreur.admin_requis`.

### [ADM-06] Donner une tablette à un joueur
- **But** : remettre une tablette neuve à un joueur connecté (dépannage, récompense, début d'emploi).
- **Qui** : admin serveur.
- **Où** : Tablettes > bouton « Donner une tablette » ; commande console/joueur `/tablette_donner [id]` (nom réglable).
- **Parcours** :
  1. Fenêtre : liste des joueurs connectés (id serveur + nom RP, recherche) ; case « Remplacer sa tablette actuelle » (si le joueur en a déjà une rattachée à son personnage).
  2. « Donner » → `pop_tablet:admin:giveTablet { targetId, replace, actionId }`.
  3. Le serveur génère un numéro unique, crée la ligne `pop_tablet_devices` (`owner` = cible, `created_by` = admin) et ajoute l'objet via le bridge d'inventaire avec `metadata = { serial }` (si métadonnées gérées) ; sans métadonnées : rattache le numéro au personnage (l'ancien numéro passe sans propriétaire si `replace`).
  4. Commande : même logique ; utilisable en console serveur (`source = 0`, journal acteur « console »).
- **Données** : targetId (id serveur connecté), replace (booléen, défaut faux).
- **Règles serveur** : ACE (sauf console) ; cible connectée ; inventaire non plein (sinon refus) ; sans métadonnées et sans `replace`, refus si le personnage a déjà une tablette ; `actionId`.
- **Textes et états** :
  - Fenêtre : « Donner une tablette » (`admin.donner.titre`), « Joueur » (`admin.donner.joueur`), « Remplacer sa tablette actuelle » (`admin.donner.remplacer`), bouton « Donner » (`admin.donner.valider`).
  - Succès : « Tablette {numéro} donnée à {joueur}. » (`admin.donner.ok`).
  - Erreurs : « Ce joueur n'est plus connecté. » (`admin.donner.deconnecte`), « L'inventaire du joueur est plein. » (`admin.donner.inventaire_plein`), « Ce joueur a déjà une tablette. Cochez Remplacer. » (`admin.donner.deja`).
  - Vide (aucun joueur connecté) : « Aucun joueur connecté. » (`admin.donner.vide`).
- **Notifications** : cible : « Tablette reçue ({numéro}). » (`notif.tablette.recue`).
- **Liens** : ADM-03.
- **Réglages** : `Config.Admin.GiveCommand = 'tablette_donner'` (`false` pour désactiver).
- **Journal admin** : oui, type `admin.tablette_donnee`, cible, numéro.
- **Performance** : liste des joueurs depuis la mémoire (pas de SQL).
- **Cas limites** :
  - Cible déconnectée entre l'affichage et le clic : `admin.donner.deconnecte`.
  - Double clic : une seule tablette (`actionId`).
  - Collision de numéro (improbable) : nouveau tirage, 5 essais max, sinon `commun.erreur.serveur`.
- **Critères d'acceptation** :
  - Étant donné un joueur connecté sans tablette avec ox_inventory, quand l'admin la lui donne, alors il a un objet `pop_tablet` avec `metadata.serial` au format `PT-XXXX-XXXX`.
  - Étant donné un inventaire plein, quand l'admin donne, alors il voit « L'inventaire du joueur est plein. ».
  - Étant donné un non-admin qui appelle `giveTablet` sur lui-même, quand le serveur répond, alors c'est `commun.erreur.admin_requis` et aucun objet n'est donné.

### [ADM-07] Journal admin et filtres
- **But** : retrouver qui a fait quoi, quand, avec l'état avant/après, en filtrant par joueur, date et type.
- **Qui** : admin serveur.
- **Où** : Admin > onglet « Journal ».
- **Parcours** :
  1. Écriture (toutes les apps) : `PopTablet.Log.add({ type, app, actor = src|identifier|'system', target, companyId, summary, before, after })`. Les lignes sont mises dans une file mémoire et écrites par paquets : minuterie de `Config.Log.FlushSeconds = 10` s créée à la première ligne, ou écriture immédiate dès 50 lignes en attente ; une seule requête `INSERT` multi-lignes. Écriture aussi à l'arrêt de la ressource.
  2. Lecture : `pop_tablet:admin:logs { page, filters }` → 20 lignes par page, plus récentes en premier : date-heure, type (libellé traduit), app, acteur, cible, entreprise, résumé.
  3. Filtres en haut : « Joueur » (nom RP ou identifiant, cherche acteur OU cible), « Du » / « Au » (dates, défaut : 7 derniers jours), « Type » (liste à choix multiples groupée par app), « Entreprise » (liste) ; bouton « Filtrer » et « Effacer les filtres ».
  4. Clic sur une ligne → détail : tous les champs + tableau « Avant » / « Après » (clé, ancienne valeur, nouvelle valeur ; valeurs différentes surlignées en accent).
  5. Purge : au démarrage, suppression des lignes plus vieilles que `Config.Log.RetentionDays`.
- **Données** : `pop_tablet_logs` (0.4) ; filtres : player (0 à 60 car.), from/to (dates, écart max 90 jours), types (liste de types connus, max 20), companyId.
  Types principaux (liste complète exportée par `PopTablet.Log.types()`, chaque type a un libellé `journal.type.<type>`) : `entreprise.*`, `site.*`, `admin.*`, `facture.*`, `argent.*`, `police.*`, `ems.*`, `justice.*`, `mecano.*`, `gang.*`, `annonce.*`, `stock.*`, `planning.*`, `perso.*` (apps perso, PERSO-05 `log`).
- **Règles serveur** : ACE ; filtres nettoyés et passés en paramètres SQL ; écart de dates borné à 90 jours ; fréquence 5 / 5 s ; le journal ne peut être ni modifié ni supprimé depuis la tablette.
- **Textes et états** :
  - Filtres : « Joueur », « Du », « Au », « Type », « Entreprise », « Filtrer », « Effacer les filtres » (`admin.journal.filtre_joueur`, `.filtre_du`, `.filtre_au`, `.filtre_type`, `.filtre_entreprise`, `.filtrer`, `.effacer`).
  - Colonnes : « Date », « Type », « Par », « Sur », « Résumé » (`admin.journal.col_date`, `.col_type`, `.col_par`, `.col_sur`, `.col_resume`) ; détail « Avant » / « Après » (`admin.journal.avant` / `.apres`).
  - Vide : « Aucune action sur cette période. » (`admin.journal.vide`) ; avec filtres : « Aucune action ne correspond à ces filtres. » + bouton « Effacer les filtres » (`admin.journal.vide_filtres`).
  - Erreur : « La période ne peut pas dépasser 90 jours. » (`admin.journal.periode_max`).
- **Notifications** : aucune (l'envoi Discord est ADM-08).
- **Liens** : toutes les apps (écriture) ; ADM-08 (copie Discord).
- **Réglages** : `Config.Log.RetentionDays = 0`, `Config.Log.FlushSeconds = 10`, `Config.Log.FlushCount = 50`.
- **Journal admin** : la consultation n'est pas journalisée.
- **Performance** : écriture groupée ; lecture paginée sur colonnes indexées ; aucune minuterie quand la file est vide.
- **Cas limites** :
  - Crash serveur : au plus 10 s de journal perdu (documenté).
  - Valeurs `before`/`after` trop grosses (> 8 Ko) : tronquées avec `"_tronque": true`.
  - Filtre joueur avec `%` : échappé.
- **Critères d'acceptation** :
  - Étant donné une facture payée par Jean Dupont hier, quand l'admin filtre « Joueur = Dupont » et « Type = Facture payée », alors la ligne apparaît avec l'avant/après du compte.
  - Étant donné 60 actions en 1 s, quand la file atteint 50, alors une écriture groupée est faite immédiatement, puis les 10 restantes 10 s plus tard.
  - Étant donné un non-admin qui appelle `pop_tablet:admin:logs`, quand le serveur répond, alors c'est `commun.erreur.admin_requis`.

### [ADM-08] Envoi du journal sur Discord
- **But** : recopier les actions sensibles dans un salon Discord, avec le lien gardé côté serveur.
- **Qui** : configuration : propriétaire du serveur (fichier `server.cfg`) ; choix des types envoyés : admin serveur.
- **Où** : `server.cfg` (convars) ; Admin > onglet « Journal » > bouton « Envoi Discord » (réglages et test).
- **Parcours** :
  1. Liens dans `server.cfg` uniquement (jamais dans `config.lua`, jamais envoyés au client) : `set pop_tablet_webhook "https://discord.com/api/webhooks/…"` (salon par défaut) et, facultatif, un lien par groupe : `pop_tablet_webhook_money`, `pop_tablet_webhook_police`, `pop_tablet_webhook_admin`, `pop_tablet_webhook_sites`.
  2. Écran « Envoi Discord » : pour chaque groupe (Argent, Police et justice, Admin, Sites et annonces, Entreprises, Apps perso), un interrupteur « Envoyer » et l'état du lien (« Lien configuré » / « Aucun lien : salon par défaut » / « Aucun lien configuré ») ; bouton « Envoyer un test ».
  3. À chaque ligne de journal dont le groupe est activé, le serveur ajoute un message dans la file Discord. Envoi par paquets : minuterie de 2 s créée à la première entrée ; jusqu'à 10 messages (embeds) par requête HTTP (`PerformHttpRequest`, POST JSON) ; en réponse 429, attente `retry_after` puis nouvel essai (3 essais max, puis abandon avec message console).
  4. Format de l'embed : titre = libellé du type, description = résumé, champs « Par » (nom RP + identifiant), « Sur », « Entreprise », « Avant » et « Après » (JSON court, 1000 caractères max chacun), couleur = accent de la tablette, horodatage.
- **Données** : `pop_tablet_settings.discord_groups` = `{ argent = true, police = true, admin = true, sites = true, entreprises = true, perso = false }`.
- **Règles serveur** : ACE pour l'écran ; liens lus uniquement par `GetConvar` côté serveur ; un lien qui ne commence pas par `https://discord.com/api/webhooks/` ou `https://discordapp.com/api/webhooks/` est ignoré (message console) ; échappement des mentions (`@everyone`, `@here` et `<@…>` neutralisés par un caractère invisible) ; file bornée à 500 messages (les plus anciens abandonnés au-delà) ; test : 1 / 30 s.
- **Textes et états** :
  - Titre : « Envoi Discord » (`admin.discord.titre`) ; groupes `admin.discord.groupe.argent` « Argent », `.police` « Police et justice », `.admin` « Admin », `.sites` « Sites et annonces », `.entreprises` « Entreprises », `.perso` « Apps perso » ; états « Lien configuré » (`admin.discord.lien_ok`), « Aucun lien : salon par défaut » (`admin.discord.lien_defaut`), « Aucun lien configuré » (`admin.discord.lien_absent`) ; bouton « Envoyer un test » (`admin.discord.test`).
  - Aide : « Les liens Discord se mettent dans server.cfg (set pop_tablet_webhook \"…\"). Ils ne sont jamais visibles en jeu. » (`admin.discord.aide`).
  - Succès test : « Message de test envoyé. » (`admin.discord.test_ok`) ; erreur test : « Message refusé par Discord. Vérifiez le lien dans server.cfg. » (`admin.discord.test_ko`).
  - Texte du message de test (dans Discord) : « Test POP Tablet : l'envoi du journal fonctionne. » (`admin.discord.test_message`).
- **Notifications** : aucune en jeu.
- **Liens** : ADM-07.
- **Réglages** : convars ci-dessus ; `Config.Discord.Interval = 5` (réglage de la base, BASE-MOT-08), `Config.Discord.MaxQueue = 500`, `Config.Discord.Username = 'POP Tablet'`.
- **Journal admin** : oui, type `admin.discord_reglages` (groupes avant/après) ; le test n'est pas journalisé.
- **Performance** : aucune minuterie quand la file est vide ; requêtes regroupées.
- **Cas limites** :
  - Discord en panne : 3 essais puis abandon ; le journal en base reste complet.
  - Aucun lien configuré : groupes affichés grisés, aucun envoi, aucune erreur.
  - Résumé contenant `@everyone` écrit par un joueur : neutralisé, aucune mention déclenchée.
- **Critères d'acceptation** :
  - Étant donné `pop_tablet_webhook` configuré et le groupe Argent actif, quand une facture est payée, alors un embed « Facture payée » arrive dans le salon dans les 2 à 3 s.
  - Étant donné l'admin qui clique « Envoyer un test », quand le lien est valide, alors le message de test arrive.
  - Étant donné un client qui cherche le lien dans les fichiers ou événements de la tablette, quand il inspecte, alors le lien n'apparaît nulle part côté client.

### [ADM-09] Masquer un site ou une annonce (modération)
- **But** : retirer de la vue publique un site ou une annonce qui enfreint les règles du serveur, sans rien effacer.
- **Qui** : admin serveur.
- **Où** : Admin > onglet « Modération » ; deux sous-onglets « Sites » et « Annonces » (liste des éléments publiés, signalements en tête, recherche) ; bouton « Masquer » sur chaque ligne. Raccourci : dans le navigateur, un admin voit un bouton « Masquer ce site » dans la barre d'adresse.
- **Parcours** :
  1. « Masquer » → fenêtre : « Raison » (liste : « Contenu choquant », « Arnaque », « Hors RP », « Image interdite », « Autre ») + « Précision » (facultatif) → `pop_tablet:admin:hide { targetType ('site'|'annonce'), targetId, reason, detail, actionId }`.
  2. Site : `status = 'masque'`, `hidden_reason`, `hidden_by`, `hidden_at` ; cache public vidé ; événement `pop_tablet:siteHidden`. L'éditeur reste accessible au patron (bandeau, publication refusée : SITE-EDI-09).
  3. Annonce : le serveur appelle `PopTablet.Ads.setHidden(adId, true, reason, adminIdentifier)` (API de l'app Annonces) ; l'annonce disparaît des listes, du site, de l'annuaire ; l'auteur la voit encore avec le bandeau.
  4. Les signalements ouverts sur cet élément passent en `traite`.
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| targetType | liste | oui | `site`, `annonce` | — |
| targetId | entier | oui | élément existant | — |
| reason | liste | oui | `choquant`, `arnaque`, `hors_rp`, `image`, `autre` | — |
| detail | texte | si reason = autre | 0 à 200 car. | vide |

- **Règles serveur** : ACE ; élément existant et non déjà masqué ; nettoyage ; `actionId`.
- **Textes et états** :
  - Sous-onglets : « Sites », « Annonces » (`admin.moderation.sites`, `.annonces`) ; étiquette « {n} signalement(s) » (`admin.moderation.signalements`) ; bouton « Masquer » (`admin.moderation.masquer`).
  - Raisons : « Contenu choquant » (`moderation.raison.choquant`), « Arnaque » (`moderation.raison.arnaque`), « Hors RP » (`moderation.raison.hors_rp`), « Image interdite » (`moderation.raison.image`), « Autre » (`moderation.raison.autre`).
  - Succès : « Masqué. » (`admin.moderation.masque_ok`).
  - Erreur : « Déjà masqué. » (`admin.moderation.deja_masque`).
  - Visiteur : « Ce site est indisponible pour le moment. » (`navigateur.site.masque`).
  - Bandeau patron : « Site masqué par l'administration : {raison} » (`site.masque.bandeau`) ; auteur d'annonce : « Annonce masquée par l'administration : {raison} » (`annonces.masquee.bandeau`).
  - Vide : « Aucun site publié. » (`admin.moderation.sites_vide`), « Aucune annonce publiée. » (`admin.moderation.annonces_vide`).
- **Notifications** : patron de l'entreprise (site) ou auteur (annonce), connecté avec la tablette : « Site {adresse} masqué par l'administration : {raison}. » (`notif.site.masque`) / « Annonce « {titre} » masquée par l'administration : {raison}. » (`notif.annonce.masquee`).
- **Liens** : navigateur, annuaire, annonces, API (événement `pop_tablet:siteHidden`), ADM-16.
- **Réglages** : aucun.
- **Journal admin** : oui, types `moderation.site_masque` / `moderation.annonce_masquee`, raison et précision.
- **Performance** : listes paginées 20 ; signalements comptés par une requête groupée à l'ouverture.
- **Cas limites** :
  - Patron qui republie pendant le masquage : refusé (SITE-EDI-09).
  - Annonce expirée entre-temps : masquage accepté (pour l'historique).
  - Double clic : `actionId`.
- **Critères d'acceptation** :
  - Étant donné `arnaque.rp` publié, quand l'admin le masque pour « Arnaque », alors un visiteur voit « Ce site est indisponible pour le moment. » et le patron reçoit la notification.
  - Étant donné une annonce masquée, quand un joueur ouvre la liste des annonces, alors elle n'y figure pas.
  - Étant donné un non-admin qui appelle `pop_tablet:admin:hide`, quand le serveur répond, alors c'est `commun.erreur.admin_requis`.

### [ADM-10] Restaurer un site ou une annonce masqué
- **But** : remettre en ligne un élément masqué par erreur ou après correction.
- **Qui** : admin serveur.
- **Où** : Modération > filtre « Masqués » > ligne > « Restaurer ».
- **Parcours** :
  1. Clic → confirmation → `pop_tablet:admin:unhide { targetType, targetId, actionId }`.
  2. Site : `status` redevient `publie` si une version publiée existe, sinon `brouillon` ; champs `hidden_*` vidés ; événement `pop_tablet:siteRestored`. Annonce : `PopTablet.Ads.setHidden(adId, false)` (si l'annonce a expiré entre-temps, elle reste expirée).
- **Données** : targetType, targetId.
- **Règles serveur** : ACE ; élément masqué ; `actionId`.
- **Textes et états** : filtre « Masqués » (`admin.moderation.filtre_masques`) ; colonnes supplémentaires « Raison », « Par », « Le » ; bouton « Restaurer » (`admin.moderation.restaurer`) ; succès « Remis en ligne. » (`admin.moderation.restaure_ok`) ; erreur « Cet élément n'est pas masqué. » (`admin.moderation.pas_masque`) ; vide « Rien n'est masqué. » (`admin.moderation.masques_vide`).
- **Notifications** : patron ou auteur : « Site {adresse} de nouveau en ligne. » (`notif.site.restaure`) / « Annonce « {titre} » de nouveau visible. » (`notif.annonce.restauree`).
- **Liens** : comme ADM-09.
- **Réglages** : aucun.
- **Journal admin** : oui, types `moderation.site_restaure` / `moderation.annonce_restauree`.
- **Performance** : identique à ADM-09.
- **Cas limites** :
  - Entreprise archivée : restauration du masquage acceptée mais le site reste introuvable tant que l'entreprise est archivée (message « Site restauré, mais l'entreprise est archivée. » `admin.moderation.restaure_archivee`).
  - Site sans version publiée : passe en brouillon.
  - Double clic : `actionId`.
- **Critères d'acceptation** :
  - Étant donné `arnaque.rp` masqué avec une version publiée, quand l'admin le restaure, alors le site est de nouveau visible.
  - Étant donné une annonce expirée et masquée, quand l'admin la restaure, alors elle reste expirée (non affichée) mais n'est plus marquée masquée.
  - Étant donné un non-admin qui appelle `unhide`, quand le serveur répond, alors c'est `commun.erreur.admin_requis`.

### [ADM-11] Régler les limites
- **But** : changer en jeu, sans redémarrer, les limites de sécurité et de taille de la tablette.
- **Qui** : admin serveur.
- **Où** : Admin > onglet « Limites ».
- **Parcours** :
  1. L'onglet affiche les réglages groupés (tableau ci-dessous), chacun avec sa valeur actuelle, sa valeur par défaut en gris et un bouton « Par défaut ».
  2. « Enregistrer » (un par groupe) → `pop_tablet:admin:setLimits { values = { [cle] = valeur }, actionId }`.
  3. Le serveur valide chaque valeur (min/max), enregistre dans `pop_tablet_settings` (une ligne par clé), met à jour `Config` en mémoire (les valeurs en base priment sur `config.lua`), et envoie aux tablettes ouvertes les seules valeurs utiles à l'interface (tailles max des champs, pagination).
- **Données** (clé de réglage | libellé | min | max | défaut) :

| Clé | Libellé (`admin.limites.<cle>`) | Min | Max | Défaut |
|---|---|---|---|---|
| `Invoices.MaxAmount` | « Montant maximum d'une facture » | 1 | 100000000 | 50000 |
| `Invoices.RecruitMaxAmount` | « Plafond de facture d'une Recrue » | 0 | 100000000 | 1000 |
| `Security.PayDistance` | « Distance pour payer ou facturer (m) » | 1 | 20 | 3 |
| `Security.DefaultRate.count` | « Actions max par fenêtre » | 1 | 50 | 5 |
| `Security.DefaultRate.window` | « Durée de la fenêtre (s) » | 1 | 120 | 10 |
| `UI.PageSize` | « Éléments par page » | 10 | 50 | 20 |
| `Sites.MaxPages` | « Pages par site » | 1 | 20 | 5 |
| `Sites.MaxBlocksPerPage` | « Blocs par page » | 5 | 50 | 30 |
| `Sites.MaxVersions` | « Versions gardées par site » | 5 | 50 | 20 |
| `Sites.FormRate.window` | « Délai entre deux demandes d'un joueur (s) » | 30 | 3600 | 600 |
| `Ads.MaxActivePerCompany` | « Annonces actives par entreprise » | 1 | 50 | 10 |
| `Companies.MaxSalary` | « Salaire maximum d'un grade » | 0 | 1000000 | 5000 |
| `Companies.Max` | « Nombre maximum d'entreprises » | 1 | 500 | 100 |
| `Apps.StorageMaxKeys` | « Clés max par app perso et par propriétaire » | 10 | 5000 | 200 |
| `Logs.RetentionDays` | « Durée de conservation du journal (jours) » | 7 | 365 | 90 |
| `Cameras.Max` | « Caméras fixes maximum » | 0 | 300 | 100 |

  La section « Images autorisées » (SITE-EDI-17) est dans le même onglet.
- **Règles serveur** : ACE ; uniquement les clés de la liste (les autres sont ignorées) ; entiers bornés ; `actionId`. Baisser une limite ne supprime jamais de données existantes (voir SITE-EDI-10 pour les pages).
- **Textes et états** :
  - Groupes : « Argent et sécurité », « Affichage », « Sites », « Entreprises », « Apps perso », « Journal », « Caméras » (`admin.limites.groupe.argent`, `.affichage`, `.sites`, `.entreprises`, `.perso`, `.journal`, `.cameras`).
  - Bouton « Par défaut » (`admin.limites.par_defaut`) ; texte « Défaut : {valeur} » (`admin.limites.defaut`).
  - Succès : `commun.succes.enregistre`.
  - Erreur : « {libellé} : valeur entre {min} et {max}. » (`admin.limites.hors_bornes`).
- **Notifications** : aucune.
- **Liens** : toutes les apps qui lisent ces réglages.
- **Réglages** : ceux du tableau (valeurs de `config.lua` = valeurs de départ).
- **Journal admin** : oui, type `admin.limites`, `before_data`/`after_data` des clés changées.
- **Performance** : réglages en mémoire ; lecture en base une seule fois au démarrage.
- **Cas limites** :
  - Valeur décimale ou texte : refusée.
  - Deux admins modifient la même clé : le dernier gagne, les deux lignes au journal.
  - Valeur en base hors des nouvelles bornes après une mise à jour de la tablette : ramenée à la borne la plus proche au démarrage, message console.
- **Critères d'acceptation** :
  - Étant donné « Montant maximum d'une facture » passé à 20000, quand un employé fait une facture de 25000, alors elle est refusée sans redémarrage.
  - Étant donné « Pages par site » à 25, quand l'admin enregistre, alors il voit « Pages par site : valeur entre 1 et 20. ».
  - Étant donné un non-admin qui appelle `setLimits`, quand le serveur répond, alors c'est `commun.erreur.admin_requis`.

### [ADM-12] Placer une caméra fixe
- **But** : installer en jeu une caméra fixe (vue d'une rue, d'une banque…) que la police (ou une autre entreprise autorisée) pourra regarder.
- **Qui** : admin serveur.
- **Où** : Admin > onglet « Caméras » > bouton « Placer une caméra ».
- **Parcours** :
  1. Clic → la tablette se réduit et un mode placement s'active : la vue passe en caméra libre partant de la position de l'admin (caméra script `DEFAULT_SCRIPTED_CAMERA`) ; commandes affichées en bas : souris = orienter, Z/Q/S/D = déplacer, A/E = monter/descendre, molette = champ de vision (30° à 90°), Entrée = valider, Échap = annuler. La boucle de contrôle de la caméra tourne **seulement** pendant ce mode et s'arrête à la sortie.
  2. Entrée → la tablette revient avec le formulaire : « Nom », « Zone » (facultatif), « Entreprises autorisées » (cases ; police cochée par défaut, liste des entreprises ayant `metier_police`, `metier_justice`, `metier_gang` ou toutes au choix).
  3. « Enregistrer » → `pop_tablet:admin:addCamera { name, zone, coords, rot, fov, companies, actionId }`.
  4. Le serveur vérifie, et refuse si les coordonnées sont à plus de `Config.Cameras.MaxPlaceDistance = 100` m de la position serveur de l'admin (anti-forgeage), enregistre, met à jour la liste en cache.
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| name | texte | oui | 2 à 40 car., unique | « Caméra {n} » |
| zone | texte | non | 0 à 40 car. | vide |
| coords | x, y, z | oui | ≤ 100 m de l'admin | position de la caméra libre |
| rot | x, y, z (degrés) | oui | x entre -89 et 89 | rotation de la caméra libre |
| fov | décimal | oui | 30 à 90 | 60 |
| companies | liste d'id | oui | au moins 1 entreprise existante | entreprises ayant `metier_police` |

- **Règles serveur** : ACE ; nom unique ; distance ; `Config.Cameras.Max` ; `actionId`.
- **Textes et états** :
  - Bouton : « Placer une caméra » (`admin.cameras.placer`) ; aide du mode : « Souris : orienter · ZQSD : déplacer · A/E : hauteur · Molette : zoom · Entrée : valider · Échap : annuler » (`admin.cameras.aide_placement`).
  - Formulaire : « Nom », « Zone », « Entreprises autorisées » (`admin.cameras.nom`, `.zone`, `.entreprises`).
  - Succès : « Caméra {nom} placée. » (`admin.cameras.ok`).
  - Erreurs : « Une caméra porte déjà ce nom. » (`admin.cameras.nom_pris`), « Nombre maximum de caméras atteint ({max}). » (`admin.cameras.max`), « Position trop éloignée. » (`admin.cameras.trop_loin`), « Au moins une entreprise requise. » (`admin.cameras.sans_entreprise`).
  - Vide (liste) : « Aucune caméra fixe. » + bouton « Placer une caméra » (`admin.cameras.vide`).
- **Notifications** : aucune.
- **Liens** : app Police > caméras (lecture des caméras autorisées, droit « valider mandat, caméras » = Chef+) ; ADM-13.
- **Réglages** : `Config.Cameras.Max = 100`, `Config.Cameras.MaxPlaceDistance = 100`, `Config.Cameras.DefaultFov = 60`.
- **Journal admin** : oui, type `admin.camera_ajoutee` (nom, coordonnées, entreprises).
- **Performance** : liste des caméras mise en cache serveur ; aucune entité créée dans le monde (la caméra est seulement une position) ; boucle de placement active seulement en mode placement.
- **Cas limites** :
  - Admin qui ferme la tablette pendant le placement : le mode placement s'arrête, la vue revient au joueur, rien n'est enregistré.
  - Admin tué ou téléporté pendant le placement : mode annulé.
  - Rotation forgée à 180° en x : ramenée entre -89 et 89.
- **Critères d'acceptation** :
  - Étant donné l'admin en mode placement devant la banque, quand il valide « Banque Pacific », alors un agent de police Chef voit « Banque Pacific » dans sa liste de caméras.
  - Étant donné Échap en mode placement, quand l'admin appuie, alors la vue revient au joueur et rien n'est créé.
  - Étant donné une requête forgée avec des coordonnées à 3 km de l'admin, quand le serveur la reçoit, alors refus « Position trop éloignée. ».

### [ADM-13] Modifier, tester, désactiver ou supprimer une caméra fixe (ajout)
- **But** : entretenir les caméras existantes.
- **Qui** : admin serveur.
- **Où** : Caméras > liste (nom, zone, entreprises, état) > clic sur une ligne > boutons « Tester », « Replacer », « Modifier », « Désactiver/Activer », « Supprimer ».
- **Parcours** :
  1. « Tester » : la vue passe sur la caméra (même rendu que l'app Police : filtre gris léger, nom et heure en surimpression) ; Échap revient.
  2. « Replacer » : relance le mode placement de ADM-12 en partant de la caméra ; Entrée → `pop_tablet:admin:updateCamera { id, coords, rot, fov, actionId }`.
  3. « Modifier » : nom, zone, entreprises → `updateCamera`.
  4. « Désactiver » : `active = 0`, la caméra disparaît des listes Police ; un agent qui la regarde est renvoyé à la liste avec « Cette caméra n'est plus disponible. ».
  5. « Supprimer » : confirmation → `pop_tablet:admin:deleteCamera { id, actionId }` → suppression de la ligne (une caméra n'est pas une donnée sensible).
- **Données** : celles de ADM-12 + active.
- **Règles serveur** : ACE ; caméra existante ; mêmes validations que ADM-12 ; `actionId`.
- **Textes et états** : boutons « Tester », « Replacer », « Modifier », « Désactiver », « Activer », « Supprimer » (`admin.cameras.tester`, `.replacer`, `.modifier`, `.desactiver`, `.activer`, `.supprimer`) ; confirmation « Supprimer la caméra {nom} ? » (`admin.cameras.supprimer_confirmer`) ; succès `commun.succes.enregistre` / « Caméra supprimée. » (`admin.cameras.supprimee`) ; message agent « Cette caméra n'est plus disponible. » (`police.cameras.indisponible`).
- **Notifications** : agents en train de regarder la caméra : message ci-dessus.
- **Liens** : app Police > caméras.
- **Réglages** : ceux de ADM-12.
- **Journal admin** : oui, types `admin.camera_modifiee`, `admin.camera_desactivee`, `admin.camera_supprimee` (avant/après).
- **Performance** : cache serveur mis à jour ; liste paginée 20.
- **Cas limites** :
  - Suppression pendant qu'un agent regarde : il est renvoyé à la liste.
  - Entreprise autorisée archivée : retirée automatiquement de la liste `companies` à l'affichage ; si plus aucune, la caméra est marquée « Sans entreprise » dans l'admin.
  - Double clic sur supprimer : `actionId`.
- **Critères d'acceptation** :
  - Étant donné une caméra mal orientée, quand l'admin la replace, alors la nouvelle vue est celle vue par la police.
  - Étant donné une caméra désactivée, quand un agent ouvre la liste, alors elle n'y figure pas.
  - Étant donné un non-admin qui appelle `deleteCamera`, quand le serveur répond, alors c'est `commun.erreur.admin_requis`.

### [ADM-14] Tableau de performance
- **But** : montrer à l'admin que la tablette ne coûte rien et repérer une action lente.
- **Qui** : admin serveur.
- **Où** : Admin > onglet « Performance ».
- **Parcours** :
  1. Mesure (serveur, permanente mais passive) : le routeur des rappels enregistre pour chaque appel la durée de traitement (`os.clock()` avant/après, en ms) dans un tampon circulaire de 200 valeurs par nom d'appel ; aucune minuterie ; la table des tablettes ouvertes est tenue par les événements d'ouverture/fermeture (`pop_tablet:server:opened` / `closed` et `playerDropped`).
  2. À l'ouverture de l'onglet : `pop_tablet:admin:perf` → le serveur calcule et renvoie : tablettes ouvertes maintenant ; joueurs ayant une tablette sur eux (connectés) ; temps de réponse moyen et 95e centile sur les 200 derniers appels toutes actions confondues ; les 5 actions les plus lentes (nom, moyenne, max, nombre d'appels) ; files d'attente (journal, Discord, visites, brouillons de sites) ; tailles des caches (sites, entreprises) ; apps perso : nombre d'appels et temps moyen par app ; état : « Tablette fermée = 0 thread actif ».
  3. Mise à jour : bouton « Actualiser » ; case « Actualiser toutes les 5 s » (minuterie côté interface uniquement, arrêtée dès que l'onglet est quitté ou la tablette fermée).
  4. Bouton « Remettre les compteurs à zéro ».
- **Données** (affichées) : openTablets (entier), carriers (entier), avgMs (décimal 2), p95Ms, slowest (liste 5), queues (table), caches (table), appsStats (liste).
- **Règles serveur** : ACE ; fréquence 1 / 2 s ; aucune donnée de joueur nominative.
- **Textes et états** :
  - Tuiles : « Tablettes ouvertes » (`admin.perf.ouvertes`), « Tablettes sur les joueurs » (`admin.perf.portees`), « Temps de réponse moyen » (`admin.perf.moyenne`) « {n} ms », « 95 % des réponses en moins de » (`admin.perf.p95`) « {n} ms ».
  - Tableau « Actions les plus lentes » (`admin.perf.lentes`) ; colonnes « Action », « Moyenne », « Max », « Appels ».
  - Seuils colorés : < 5 ms texte normal, 5 à 20 ms orange « À surveiller » (`admin.perf.surveiller`), > 20 ms rouge « Lent » (`admin.perf.lent`).
  - Aide : « Le temps resmon dépend aussi des autres scripts. Ici : temps de traitement des actions de la tablette côté serveur. » (`admin.perf.aide`).
  - Boutons : « Actualiser » (`admin.perf.actualiser`), « Actualiser toutes les 5 s » (`admin.perf.auto`), « Remettre les compteurs à zéro » (`admin.perf.reset`).
  - Vide : « Aucune action mesurée depuis le démarrage. » (`admin.perf.vide`).
- **Notifications** : aucune.
- **Liens** : PERSO-08 (une app perso lente apparaît ici).
- **Réglages** : `Config.Perf.SampleSize = 200`, `Config.Perf.WarnMs = 5`, `Config.Perf.SlowMs = 20`.
- **Journal admin** : non (sauf « Remettre à zéro » : type `admin.perf_reset`).
- **Performance** : mesure = deux appels `os.clock()` et une écriture dans un tableau par action ; calculs seulement à l'ouverture de l'onglet.
- **Cas limites** :
  - Action jamais appelée : absente du tableau.
  - Action d'app perso > `Config.Perf.SlowMs` plus de 10 fois : message console « [POP Tablet] L'app perso {app} est lente ({n} ms en moyenne). ».
  - Serveur redémarré : compteurs à zéro.
- **Critères d'acceptation** :
  - Étant donné 3 joueurs tablette ouverte, quand l'admin ouvre l'onglet, alors « Tablettes ouvertes » affiche 3.
  - Étant donné la case « toutes les 5 s » cochée, quand l'admin change d'onglet, alors plus aucune requête `perf` n'est envoyée.
  - Étant donné un non-admin qui appelle `pop_tablet:admin:perf`, quand le serveur répond, alors c'est `commun.erreur.admin_requis`.

### [ADM-15] Vente de tablettes (supprimée : géré par la boutique du serveur)
- La tablette n'a plus d'onglet de vente, de PNJ, de prix ni de commande de boutique. Le script de boutique du serveur vend les objets `pop_tablet` et `pop_tablet_charger` (déclarés dans l'inventaire, BASE-OBJ-18 supprimée) et peut appeler les exports serveur `ResetTablet(serial)`, `ReplaceTablet(source, oldSerial)` et `TransferTabletData(oldSerial, newSerial)` (BASE-OBJ-08) pour vendre une réinitialisation ou un remplacement. Côté admin : ADM-04 (réinitialiser), ADM-05 (débloquer), ADM-06 (donner une tablette).

### [ADM-16] Signaler un site ou une annonce (ajout)
- **But** : permettre aux joueurs de signaler un contenu abusif pour que les admins le voient dans la modération.
- **Qui** : tout joueur ayant une tablette.
- **Où** : navigateur > menu « ⋯ » de la barre d'adresse > « Signaler ce site » ; annonce > menu « ⋯ » > « Signaler ».
- **Parcours** :
  1. Fenêtre : raison (liste de ADM-09) + commentaire facultatif → `pop_tablet:reports:create { targetType, targetId, reason, comment, actionId }`.
  2. Le serveur enregistre dans `pop_tablet_reports` (un signalement par joueur et par élément, contrainte UNIQUE).
  3. Quand un élément atteint `Config.Reports.AlertThreshold = 3` signalements ouverts, les admins connectés avec la tablette reçoivent une notification.
  4. Dans Modération (ADM-09), les éléments signalés remontent en tête avec le nombre et le détail ; boutons « Masquer » (ADM-09) ou « Rejeter les signalements » (`status = 'rejete'`).
- **Données** : targetType, targetId, reason, comment (0 à 300 car.).
- **Règles serveur** : élément existant et visible ; un joueur ne signale pas le contenu de sa propre entreprise ; 1 signalement par joueur et élément ; fréquence 3 / 10 min par joueur ; nettoyage.
- **Textes et états** :
  - « Signaler ce site » (`navigateur.signaler`), « Signaler » (`annonces.signaler`) ; fenêtre « Signaler » (`signalement.titre`), « Raison » (`signalement.raison`), « Commentaire (facultatif) » (`signalement.commentaire`), bouton « Envoyer » (`signalement.envoyer`).
  - Succès : « Signalement transmis aux administrateurs. » (`signalement.ok`).
  - Erreurs : « Contenu déjà signalé. » (`signalement.deja`), « Impossible de signaler le contenu de sa propre entreprise. » (`signalement.propre_entreprise`).
  - Admin : bouton « Rejeter les signalements » (`admin.moderation.rejeter`), succès « Signalements rejetés. » (`admin.moderation.rejete_ok`).
- **Notifications** : admins connectés tablette sur eux, au seuil : « {n} signalements sur {cible}. » (`notif.admin.signalements`).
- **Liens** : ADM-09, ADM-10.
- **Réglages** : `Config.Reports.AlertThreshold = 3`, `Config.Reports.Rate = { n = 3, s = 600 }`.
- **Journal admin** : oui pour le rejet (type `moderation.signalements_rejetes`) ; le signalement lui-même est stocké dans sa table (pas au journal).
- **Performance** : une insertion ; comptage par requête indexée seulement au moment d'un nouveau signalement.
- **Cas limites** :
  - Élément masqué entre-temps : signalement refusé avec « Ce contenu n'est plus visible. » (`signalement.plus_visible`).
  - Brigade de faux signalements : seuil = 3 joueurs différents ; le rejet clôt tous les signalements ouverts.
  - Joueur déconnecté : sans effet sur le signalement déjà envoyé.
- **Critères d'acceptation** :
  - Étant donné 3 joueurs qui signalent `arnaque.rp`, quand le troisième envoie, alors les admins connectés reçoivent la notification.
  - Étant donné un joueur qui signale deux fois le même site, quand il envoie la 2e fois, alors il voit « Contenu déjà signalé. ».
  - Étant donné une requête forgée qui signale 50 éléments en boucle, quand le serveur traite, alors seuls 3 sont acceptés en 10 min.

---

## 4. Apps perso / Claude friendly : `PERSO-`

Principes communs :
- Le cœur de la tablette est chiffré (escrow Cfx). Sont **ouverts** (déclarés dans `escrow_ignore`) : `config/`, `locales/`, `apps/` (dossier « mes apps », SDK, modèle, exemples), `docs/`, `tools/`, `CLAUDE.md`, `AGENTS.md`.
- Une app perso = un dossier `pop_tablet/apps/<id>/`. Son interface tourne dans une `iframe` isolée ; son code serveur (facultatif) tourne dans un environnement Lua fermé fourni par la tablette. Elle ne parle au reste de la tablette que par l'API documentée (PERSO-04, PERSO-05).
- Une app perso ne peut ni lire ni écrire les données d'une autre app (PERSO-06).

### [PERSO-01] Dossier « mes apps » et détection automatique
- **But** : qu'un serveur ajoute une app en déposant un dossier dans `apps/` puis en redémarrant la ressource, sans toucher au code chiffré.
- **Qui** : propriétaire / développeur du serveur (fichiers) ; admin serveur pour voir l'état et couper (ADM-02).
- **Où** : dossier `pop_tablet/apps/` ; console serveur au démarrage ; Admin > onglet « Apps » (section « Apps perso »).
- **Parcours** :
  1. Structure d'une app :
     ```
     apps/<id>/
       app.lua          -- obligatoire : uniquement l'appel PopApp.register({...})
       index.html       -- obligatoire : interface
       app.js           -- facultatif (nom libre, référencé par index.html)
       style.css        -- facultatif
       icon.svg         -- obligatoire : icône 64x64 (svg ou png)
       server.lua       -- facultatif : code serveur (chargé dans l'environnement fermé)
       locales/fr.json  -- conseillé : textes ; locales/en.json idem
     ```
  2. Le `fxmanifest.lua` (lisible, non chiffré) contient déjà : `server_scripts { '@oxmysql/lib/MySQL.lua', 'core/server/*.lua', 'apps/*/app.lua' }` (le cœur avant les apps) et `files { 'apps/*/*.html', 'apps/*/*.js', 'apps/*/*.css', 'apps/*/*.svg', 'apps/*/*.png', 'apps/*/locales/*.json', 'apps/_sdk/*' }`. Les fichiers `.lua` ne sont **jamais** envoyés aux clients.
  3. Au démarrage, chaque `app.lua` appelle `PopApp.register(manifest)`. Le cœur vérifie le manifeste (tableau ci-dessous), la présence de `apps/<id>/index.html` et `apps/<id>/icon.*` via `LoadResourceFile`, puis lance l'outil de vérification intégré (PERSO-08).
  4. Si `server = true`, le cœur lit `apps/<id>/server.lua` avec `LoadResourceFile` et l'exécute avec `load(code, '@apps/<id>/server.lua', 't', env)` où `env` est l'environnement fermé de PERSO-05.
  5. Chaque app reçoit un état : « Chargée », « Refusée » (avec raisons) ou « Coupée » (ADM-02). Console : « [POP Tablet] Apps perso : 3 chargées, 1 refusée (mon_app : PERF-01 boucle infinie dans server.lua ligne 12). ».
  6. Visibilité : selon `access` du manifeste : `tous` (toute tablette), `entreprise` (proposée comme brique `perso:<id>` dans SITE-CRE-05 ; visible seulement pour les entreprises qui l'ont cochée, à partir du niveau `minLevel`), `admin` (admins seulement).
  7. L'app apparaît sur l'écran d'accueil après les apps de la tablette, avec son icône et son nom (traduit selon la langue du joueur).
- **Données** (manifeste) :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| id | texte | oui | `^[a-z][a-z0-9_]{2,31}$`, unique, égal au nom du dossier, ne commence pas par `pop_` (réservé) | — |
| name | table langue → texte | oui | 1 à 24 car. par langue, `fr` obligatoire | — |
| description | table langue → texte | non | 0 à 120 car. | vide |
| version | texte | oui | `^%d+%.%d+%.%d+$` | — |
| apiVersion | entier | oui | versions supportées : `1` | — |
| author | texte | non | 0 à 40 car. | vide |
| icon | texte | oui | nom de fichier du dossier (`.svg` ou `.png`) | `icon.svg` |
| access | table | non | `{ type = 'tous' }`, `{ type = 'entreprise', minLevel = 'recrue'|'membre'|'chef'|'patron' }`, `{ type = 'admin' }` | `{ type = 'tous' }` |
| scopes | liste | non | parmi `player`, `company`, `global` | `{ 'player' }` |
| server | booléen | non | — | faux |
| template | booléen | non | si vrai, l'app est ignorée (réservé au modèle vide) | faux |

- **Règles serveur** : manifeste invalide → app refusée ; doublon d'`id` → la seconde est refusée ; `apiVersion` inconnue → refusée ; app refusée = aucun fichier servi à l'interface, aucun appel accepté ; nombre max d'apps perso `Config.Apps.Max = 30`.
- **Textes et états** :
  - Admin > Apps, section « Apps perso » (`admin.apps.perso`) : colonnes « App », « Version », « Auteur », « État » ; états « Chargée » (`admin.apps.etat.chargee`), « Refusée » (`admin.apps.etat.refusee`), « Coupée » (`admin.apps.etat.coupee`) ; bouton « Voir le rapport » (`admin.apps.rapport`) qui affiche les lignes de PERSO-08.
  - Vide : « Aucune app perso. Déposez un dossier dans apps/ puis redémarrez la ressource. Le guide CLAUDE.md explique comment en créer une. » (`admin.apps.perso_vide`).
  - Console : message de l'étape 5 ; refus : « [POP Tablet] App {id} refusée : {raison}. ».
- **Notifications** : aucune.
- **Liens** : SITE-CRE-05 (brique `perso:<id>`), ADM-02, ADM-14, PERSO-08.
- **Réglages** : `Config.Apps.Enabled = true` (faux : aucune app perso chargée), `Config.Apps.Max = 30`, `Config.Apps.TrustedApps = {}` (voir PERSO-05).
- **Journal admin** : oui, au démarrage, type `perso.chargement`, résumé « {n} apps perso chargées, {m} refusées » (une ligne par démarrage).
- **Performance** : chargement une seule fois au démarrage ; l'interface d'une app n'est chargée (iframe créée) qu'à son ouverture et détruite à sa fermeture ; tablette fermée = aucune iframe.
- **Cas limites** :
  - Dossier ajouté sans redémarrer : non détecté (documenté dans le guide : « redémarrez la ressource : `ensure pop_tablet` »).
  - Erreur Lua dans `server.lua` au chargement : capturée (`pcall`), app refusée avec le message d'erreur et la ligne.
  - App supprimée alors que des entreprises l'avaient cochée : la brique `perso:<id>` est ignorée silencieusement, ses données restent en base.
- **Critères d'acceptation** :
  - Étant donné le dossier `apps/exemple_notes/` valide, quand la ressource démarre, alors l'app « Notes » apparaît sur l'accueil de toutes les tablettes.
  - Étant donné un manifeste avec `id = 'pop_hack'`, quand la ressource démarre, alors l'app est refusée avec la raison « id réservé ».
  - Étant donné un client qui demande `nui://pop_tablet/apps/mon_app/server.lua`, quand il essaie, alors le fichier n'est pas servi (il n'est pas dans `files`).

### [PERSO-02] Modèle d'app vide
- **But** : fournir un point de départ minimal et correct à copier pour créer une app.
- **Qui** : développeur du serveur, humain ou IA.
- **Où** : dossier `pop_tablet/apps/_modele/`.
- **Parcours** :
  1. Copier `apps/_modele/` en `apps/<mon_id>/`.
  2. Dans `app.lua` : remplacer `id`, `name`, et **supprimer** la ligne `template = true`.
  3. Redémarrer la ressource ; l'app « Mon app » s'affiche avec un écran « Bonjour {nom du joueur} » et un bouton « Tester le serveur » qui appelle l'action `ping`.
  Contenu exact du modèle :
  - `app.lua` :
    ```lua
    PopApp.register({
      id = 'mon_app',
      template = true, -- SUPPRIMER cette ligne dans ta copie
      name = { fr = 'Mon app', en = 'My app' },
      description = { fr = 'Description courte.', en = 'Short description.' },
      version = '1.0.0',
      apiVersion = 1,
      author = '',
      icon = 'icon.svg',
      access = { type = 'tous' },
      scopes = { 'player' },
      server = true,
    })
    ```
  - `server.lua` :
    ```lua
    -- Code serveur de l'app. Seul l'objet App est disponible (voir docs/api-apps.md).
    App.onCall('ping', function(ctx, data)
      return { message = App.t(ctx, 'ping.reponse', { name = ctx.name }) }
    end)
    ```
  - `index.html` : page HTML5 avec `<link rel="stylesheet" href="../_sdk/pop-app.css">`, `<script src="../_sdk/pop-app.js"></script>`, `<script src="app.js"></script>`, un conteneur `<main id="app" class="pop-app"></main>`.
  - `app.js` :
    ```js
    PopApp.ready().then((ctx) => {
      const root = document.getElementById('app');
      root.append(
        PopApp.el('h1', { class: 'pop-titre' }, PopApp.t('accueil.bonjour', { name: ctx.player.name })),
        PopApp.el('button', { class: 'pop-bouton pop-bouton--principal', onclick: async () => {
          try { const r = await PopApp.call('ping'); PopApp.notify(r.message, 'succes'); }
          catch (e) { PopApp.notify(e.message, 'erreur'); }
        } }, PopApp.t('accueil.tester'))
      );
    });
    ```
  - `locales/fr.json` : `{ "accueil.bonjour": "Bonjour {name}", "accueil.tester": "Tester le serveur", "ping.reponse": "Le serveur répond, {name}." }` ; `locales/en.json` équivalent anglais.
  - `icon.svg` : carré arrondi neutre 64x64 (contour blanc, pas de couleur).
  - `README.md` : 10 lignes reprenant les 3 étapes ci-dessus.
- **Données** : fichiers ci-dessus.
- **Règles serveur** : `template = true` → ignorée par la détection (PERSO-01) ; l'outil de vérification (PERSO-08) doit passer sur le modèle sans aucune alerte (testé avant chaque version de la tablette).
- **Textes et états** : textes de l'app = ceux de `locales/*.json` ci-dessus ; vide/chargement gérés par le SDK (PERSO-09).
- **Notifications** : aucune.
- **Liens** : PERSO-03, PERSO-04, PERSO-05, PERSO-09.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : aucune boucle ; un seul appel serveur au clic.
- **Cas limites** :
  - Copie sans retirer `template = true` : app ignorée ; message console « [POP Tablet] App {id} ignorée : c'est un modèle (retirez template = true). ».
  - Copie avec `id` non changé (`mon_app`) et dossier différent : refusée (« le dossier doit s'appeler comme l'id »).
  - Deux copies avec le même id : la seconde refusée.
- **Critères d'acceptation** :
  - Étant donné une copie `apps/test_app/` avec `id = 'test_app'` et `template` retiré, quand la ressource redémarre, alors l'app s'affiche et le bouton répond « Le serveur répond, {nom}. ».
  - Étant donné le modèle lui-même, quand `node tools/pop-check.js apps/_modele` est lancé, alors 0 bloquant et 0 alerte.
  - Étant donné un joueur qui envoie `PopApp.call('ping')` à une app non chargée, quand le serveur reçoit, alors refus « Cette app n'est pas disponible. » (`perso.erreur.indisponible`).

### [PERSO-03] Guide pour l'IA (fichier d'instructions à la racine)
- **But** : qu'une IA (Claude Code ou autre) puisse créer une app perso correcte et sûre en lisant un seul fichier.
- **Qui** : développeurs du serveur et leurs assistants IA.
- **Où** : `pop_tablet/CLAUDE.md` (et `pop_tablet/AGENTS.md`, une ligne : « Lisez CLAUDE.md. » pour les autres outils).
- **Parcours** : le fichier est livré avec la tablette, en français et anglais (deux sections, français d'abord), 300 lignes maximum, avec ces sections dans cet ordre :
  1. « Ce qui peut être modifié » : `config/`, `locales/`, `apps/` (sauf `apps/_sdk/`), rien d'autre ; le cœur est chiffré, ne pas essayer de le modifier.
  2. « Créer une app en 5 étapes » : copier `_modele`, renommer l'id, retirer `template`, écrire l'interface et le serveur, lancer `node tools/pop-check.js apps/<id>`, redémarrer `ensure pop_tablet`.
  3. « Règles obligatoires » (reprises mot pour mot) :
     - « Aucune boucle permanente : pas de `while true`, pas de `setInterval` rapide. Réagissez aux clics et aux événements. »
     - « Le client ment : l'identité du joueur vient toujours de `ctx` côté serveur, jamais de `data`. Tout montant, cible ou quantité reçu dans `data` est revérifié côté serveur (type, bornes, distance). »
     - « Affichez les textes des joueurs avec `textContent` ou `PopApp.el`, jamais `innerHTML`. »
     - « Pas d'appel réseau externe (`fetch` vers internet interdit). »
     - « Stockez avec `PopApp.storage` / `App.storage` uniquement ; pas de SQL. »
     - « Tous les textes affichés passent par `locales/*.json`. »
     - « Style : utilisez les classes du kit (`pop-…`), une seule couleur d'accent (`var(--pop-accent)`), pas de dégradé ni de flou. »
  4. « API » : renvoi vers `docs/api-apps.md` + tableau résumé des fonctions (nom, une ligne).
  5. « Exemples » : description des 3 apps d'exemple et quel exemple copier selon le besoin (données perso → `exemple_notes`, données d'équipe → `exemple_tableau`, argent → `exemple_pourboire`).
  6. « Erreurs fréquentes » : 8 erreurs avec la correction (ex. « App ignorée : template = true »).
  7. « Vérifier avant de livrer » : liste à cocher (pop-check sans bloquant, textes en fr et en, testée tablette fermée/rouverte, testée avec un second joueur).
- **Données** : fichier Markdown statique.
- **Règles serveur** : aucune (documentation) ; à chaque nouvelle version de l'API, le guide est mis à jour dans la même livraison (critère de livraison de la tablette).
- **Textes et états** : textes ci-dessus, non traduits par le système de langues (fichier bilingue).
- **Notifications** : aucune.
- **Liens** : PERSO-02, PERSO-04, PERSO-05, PERSO-07, PERSO-08, PERSO-09.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : sans objet.
- **Cas limites** :
  - L'utilisateur copie le guide dans un autre dossier : le guide utilise des chemins relatifs à `pop_tablet/`, précisé en tête.
  - IA qui tente de modifier `apps/_sdk/` : le guide l'interdit ; une mise à jour de la tablette écrase `_sdk/` (précisé).
  - Version de l'API différente de celle du guide : la tête du guide indique « API version 1 ».
- **Critères d'acceptation** :
  - Étant donné Claude Code ouvert dans `pop_tablet/` sans autre consigne, quand on lui demande « Créer une app de liste de courses d'entreprise », alors il produit une app qui passe `pop-check` sans bloquant au premier essai (test de recette fait par l'équipe avant la sortie).
  - Étant donné le guide, quand on cherche les 7 règles obligatoires, alors elles sont toutes présentes mot pour mot.
  - Étant donné une app générée qui utilise `data.identifier` côté serveur (triche possible), quand `pop-check` tourne, alors il la signale en BLOQUANT (SEC-04), comme le guide l'annonce.

### [PERSO-04] API côté interface (`PopApp`, JavaScript)
- **But** : donner aux apps perso une liste fermée et documentée de fonctions côté interface.
- **Qui** : code JavaScript des apps perso.
- **Où** : `apps/_sdk/pop-app.js` (ouvert), documenté dans `docs/api-apps.md`.
- **Parcours** :
  1. La tablette ouvre l'app dans `<iframe sandbox="allow-scripts" src="nui://pop_tablet/apps/<id>/index.html">` (pas de `allow-same-origin` : l'app n'a accès ni à la tablette, ni aux autres apps, ni au stockage du navigateur).
  2. `pop-app.js` communique avec la tablette par `window.parent.postMessage` ; la tablette identifie l'app **par l'iframe émettrice** (`event.source`), jamais par un champ du message, puis relaie au serveur avec l'`id` de l'app.
  3. Toutes les fonctions asynchrones renvoient une `Promise` ; en cas d'erreur, la promesse est rejetée avec un `Error` dont `message` est un texte traduit prêt à afficher.
- **Données** (liste exacte des fonctions, API version 1) :

| Fonction | Signature | Rôle | Exemple |
|---|---|---|---|
| `ready` | `PopApp.ready(): Promise<Context>` | Attend que la tablette ait envoyé le contexte. | `const ctx = await PopApp.ready();` |
| `context` | `PopApp.context: Context` | Contexte après `ready` : `{ appId, locale, accent, player: { name, level, gradeLabel }, company: { id, name, color } \| null }`. | `PopApp.context.player.name` |
| `t` | `PopApp.t(key: string, vars?: object): string` | Texte traduit depuis `locales/<langue>.json` (repli `fr`, puis la clé). | `PopApp.t('liste.vide')` |
| `call` | `PopApp.call(action: string, data?: object): Promise<any>` | Appelle `App.onCall(action)` du serveur de l'app. `data` ≤ 16 Ko. | `await PopApp.call('post', { text })` |
| `storage.get` | `PopApp.storage.get(scope, key): Promise<any \| null>` | Lit une valeur. `scope` : `'player'` ou `'company'` (lecture `'global'` aussi). | `await PopApp.storage.get('player', 'notes')` |
| `storage.set` | `PopApp.storage.set(scope, key, value): Promise<true>` | Écrit (JSON ≤ 16 Ko). Écriture `'global'` interdite depuis l'interface. | `await PopApp.storage.set('player', 'theme', 'sombre')` |
| `storage.remove` | `PopApp.storage.remove(scope, key): Promise<true>` | Supprime une clé. | `await PopApp.storage.remove('player', 'n_12')` |
| `storage.list` | `PopApp.storage.list(scope, { prefix?, page? }): Promise<{ items: {key, value, updatedAt}[], total }>` | Liste paginée (20 par page) des clés, filtrable par préfixe. | `await PopApp.storage.list('player', { prefix: 'n_', page: 1 })` |
| `notify` | `PopApp.notify(text: string, kind?: 'info'\|'succes'\|'erreur')` | Bandeau de la tablette (2 s). | `PopApp.notify('Enregistré', 'succes')` |
| `confirm` | `PopApp.confirm(text: string): Promise<boolean>` | Fenêtre de confirmation de la tablette. | `if (await PopApp.confirm('Supprimer ?')) …` |
| `setTitle` | `PopApp.setTitle(text: string)` | Titre dans la barre de la tablette (≤ 30 car.). | `PopApp.setTitle('Mes notes')` |
| `pickImage` | `PopApp.pickImage(): Promise<string \| null>` | Ouvre la galerie de la tablette, renvoie une URL autorisée ou `null`. | `const url = await PopApp.pickImage();` |
| `el` | `PopApp.el(tag: string, props?: object, ...children): HTMLElement` | Crée un élément ; les enfants texte passent par `textContent` ; `props` : attributs, `class`, `onclick`… (attributs `on*` acceptent seulement des fonctions). | `PopApp.el('li', {}, note.title)` |
| `on` / `off` | `PopApp.on(event, handler)` / `PopApp.off(event, handler)` | Événements : `'show'` (app affichée), `'hide'` (app masquée : arrêtez les minuteries), `'theme'` (`{ accent }`), `'push'` (`{ event, data }` envoyé par `App.push`). | `PopApp.on('hide', () => clearTimeout(t))` |
| `close` | `PopApp.close()` | Revient à l'accueil de la tablette. | `PopApp.close()` |
| `version` | `PopApp.version: number` | Version de l'API (`1`). | `if (PopApp.version < 1) …` |

- **Règles serveur** (appliquées par la tablette et le serveur à chaque appel) : app chargée et non coupée ; joueur ayant accès à l'app (`access`) ; `scope` autorisé par le manifeste ; `company` exige que le joueur appartienne à une entreprise qui a l'app (si `access.type = 'entreprise'`) ; taille ≤ 16 Ko ; fréquence `Config.Apps.CallRate = { n = 20, s = 10 }` par joueur et par app ; quotas de stockage (PERSO-06).
- **Textes et états** (erreurs renvoyées en `Error.message`) : « Cette app n'est pas disponible. » (`perso.erreur.indisponible`), « Trop d'actions. Réessayez dans quelques secondes. » (`commun.erreur.trop_vite`), « Données trop volumineuses. » (`perso.erreur.trop_gros`), « Espace de stockage plein pour cette app. » (`perso.erreur.quota`), « Accès à cette app refusé. » (`perso.erreur.acces`), « Le serveur n'a pas répondu. Réessayez dans un instant. » (`commun.erreur.serveur`), « Action inconnue. » (`perso.erreur.action_inconnue`).
- **Notifications** : `notify` = bandeau local ; notifications vers d'autres joueurs uniquement côté serveur (`App.notify`).
- **Liens** : PERSO-05 (serveur), PERSO-06 (stockage), PERSO-09 (style), galerie (pickImage).
- **Réglages** : `Config.Apps.CallRate = { n = 20, s = 10 }`, `Config.Apps.MaxPayload = 16384`.
- **Journal admin** : non (l'app journalise elle-même via `App.log`).
- **Performance** : aucune communication tant que l'app n'appelle rien ; l'iframe est détruite à la fermeture (toutes les minuteries de l'app meurent avec elle).
- **Cas limites** :
  - Appel avant `ready()` : mis en attente jusqu'au contexte.
  - Tablette fermée pendant un appel : la promesse est rejetée avec `commun.erreur.serveur`, sans effet secondaire côté interface.
  - App qui tente `window.parent.document` : bloqué par le navigateur (origine isolée), erreur dans la console de l'app.
- **Critères d'acceptation** :
  - Étant donné l'app Notes, quand elle appelle `PopApp.storage.set('player','n_1',{title:'A'})` puis `get`, alors elle relit `{title:'A'}`.
  - Étant donné une app qui appelle `PopApp.storage.set('global', 'x', 1)` depuis l'interface, quand la tablette relaie, alors le serveur refuse avec « Accès à cette app refusé. ».
  - Étant donné une app A qui envoie un `postMessage` en se faisant passer pour l'app B (`appId: 'b'` dans le message), quand la tablette relaie, alors c'est l'id A (déduit de l'iframe) qui est utilisé.

### [PERSO-05] API côté serveur (`App`, Lua, environnement fermé)
- **But** : donner au code serveur des apps perso une liste fermée de fonctions sûres, sans accès direct à la base, au framework ou aux autres apps.
- **Qui** : `server.lua` des apps perso.
- **Où** : objet global `App` dans l'environnement de `server.lua` (PERSO-01, étape 4), documenté dans `docs/api-apps.md`.
- **Parcours** :
  1. Le cœur construit pour chaque app un environnement contenant **uniquement** : `App` (lié à l'id de l'app, non modifiable), `print` (préfixé `[app:<id>]`), `pairs`, `ipairs`, `next`, `type`, `tostring`, `tonumber`, `select`, `error`, `assert`, `pcall`, `string`, `table`, `math`, `utf8`, `json` (`encode`/`decode`), `os.time`, `os.date`, `os.clock`. Pas de `Citizen`, `CreateThread`, `Wait`, `TriggerEvent`, `RegisterNetEvent`, `exports`, `MySQL`, natives, `load`, `require`, `debug`, `io`, `os.execute`, `_G`.
  2. Chaque appel `PopApp.call(action, data)` arrive dans le gestionnaire enregistré par `App.onCall(action, fn)`, exécuté dans un `pcall` avec un compteur d'instructions (`debug.sethook` posé par le cœur, limite `Config.Apps.MaxInstructions = 5000000`) ; au-delà, l'appel est interrompu (« boucle ») et compté.
  3. Après 3 interruptions en 10 minutes, l'app est coupée automatiquement (comme ADM-02) avec le message « Cette app a été coupée automatiquement car elle bloquait. », ligne au journal et message console.
  4. Applis de confiance : une app listée dans `Config.Apps.TrustedApps` reçoit en plus `_G` complet (accès au framework, natives, exports). Réservé aux développeurs qui savent ce qu'ils font ; affiché « De confiance » dans Admin > Apps.
- **Données** (liste exacte des fonctions, API version 1 ; `ctx` = contexte du joueur appelant construit par le serveur) :

  `ctx` = `{ source = 12, identifier = 'license:…', name = 'Jean Dupont', companyId = 3 | nil, companyName = 'Dynasty 8' | nil, level = 'recrue'|'membre'|'chef'|'patron'|nil, grade = 2 | nil, onDuty = true|false, isAdmin = false, locale = 'fr' }`.

| Fonction | Signature | Rôle | Exemple |
|---|---|---|---|
| `App.id` | `string` | Identifiant de l'app. | `print(App.id)` |
| `App.onCall` | `App.onCall(action: string, fn(ctx, data) -> result \| nil, errKey)` | Déclare une action appelable par l'interface. Retourner `nil, 'cle'` envoie l'erreur traduite (clé de `locales/`). | `App.onCall('post', function(ctx, data) … end)` |
| `App.t` | `App.t(ctxOrLocale, key, vars?) -> string` | Traduit une clé de l'app. | `App.t(ctx, 'ok')` |
| `App.storage.get` | `App.storage.get(ctx, scope, key) -> value \| nil` | Lit pour le joueur (`player`) ou son entreprise (`company`) ou `global`. | `App.storage.get(ctx, 'company', 'tableau')` |
| `App.storage.set` | `App.storage.set(ctx, scope, key, value) -> true \| nil, err` | Écrit (≤ 16 Ko). `global` autorisé côté serveur. | `App.storage.set(ctx, 'company', 'm_'..id, msg)` |
| `App.storage.remove` | `App.storage.remove(ctx, scope, key) -> true` | Supprime. | `App.storage.remove(ctx, 'company', 'm_4')` |
| `App.storage.list` | `App.storage.list(ctx, scope, { prefix?, page? }) -> { items, total }` | Liste paginée (20). | `App.storage.list(ctx, 'company', { prefix = 'm_' })` |
| `App.getPlayer` | `App.getPlayer(source) -> { source, name, companyId, companyName, level, onDuty, hasTablet } \| nil` | Infos publiques d'un joueur connecté (jamais son identifiant). | `App.getPlayer(ctx.source)` |
| `App.getNearbyPlayers` | `App.getNearbyPlayers(source, radius) -> { { source, name, distance } }` | Joueurs proches, calcul serveur, `radius` ≤ 10 m. | `App.getNearbyPlayers(ctx.source, 3)` |
| `App.hasPermission` | `App.hasPermission(ctx, permKey) -> boolean` | Droit de l'entreprise du joueur (clés du tableau des droits, ex. `facture.creer`, grille unique de `00-sommaire.md`). | `App.hasPermission(ctx, 'site.modifier')` |
| `App.isAtLeast` | `App.isAtLeast(ctx, level) -> boolean` | Niveau minimum (`'membre'`…). | `App.isAtLeast(ctx, 'chef')` |
| `App.notify` | `App.notify(target, text)` ; `target` = `source`, liste de `source`, ou `{ companyId = n, minLevel = 'membre', onDutyOnly = false }` | Notification aux tablettes concernées (seulement joueurs ayant la tablette sur eux). | `App.notify({ companyId = ctx.companyId }, 'Nouveau message')` |
| `App.push` | `App.push(target, event, data)` | Envoie un événement `'push'` à l'interface de l'app si elle est ouverte. | `App.push(src, 'nouveau', { id = 4 })` |
| `App.createInvoice` | `App.createInvoice(ctx, targetSource, amount, label) -> invoiceId \| nil, errKey` | Crée une vraie facture via l'app Factures au nom de l'entreprise du joueur, avec **toutes** ses règles (droit, montant max, distance 3 m, anti double paiement). | `App.createInvoice(ctx, cible, 50, 'Pourboire')` |
| `App.log` | `App.log(ctx, summary, data?)` | Ligne au journal admin, type `perso.<id>`. | `App.log(ctx, 'Message supprimé', { id = 4 })` |
| `App.rateLimit` | `App.rateLimit(ctx, name, count, windowSeconds) -> boolean` | Vrai si l'action est permise, faux si trop rapide. | `if not App.rateLimit(ctx, 'post', 1, 30) then return nil, 'trop_vite' end` |
| `App.sanitize` | `App.sanitize(text, max, multiline?) -> string \| nil, errKey` | Nettoyage standard (0.3). | `local t, e = App.sanitize(data.text, 200)` |
| `App.setTimeout` | `App.setTimeout(ms, fn)` | Minuterie unique, `ms` ≥ 1000, 20 en attente max par app. | `App.setTimeout(60000, nettoyer)` |
| `App.onPlayerDropped` | `App.onPlayerDropped(fn(source))` | Prévenu quand un joueur se déconnecte. | `App.onPlayerDropped(function(s) … end)` |
| `App.settings` | `table` (lecture seule) | Valeurs de `apps/<id>/settings.lua` (fichier facultatif retournant une table). | `App.settings.maxMessages` |

- **Règles serveur** : `ctx` est construit par le serveur à partir de `source` (jamais du client) ; toutes les fonctions refusent un `ctx` qui n'a pas été fourni par le cœur pour l'appel en cours (table marquée interne, non copiable) ; `App.storage.*` utilise l'id de l'app lié à l'environnement (impossible de viser une autre app) ; `App.createInvoice` passe par les mêmes contrôles qu'une facture manuelle ; erreurs Lua dans un gestionnaire → réponse `commun.erreur.serveur` + message console avec la ligne.
- **Textes et états** : clés d'erreur de l'app (dans ses `locales/`) ; erreurs du cœur : `perso.erreur.*` (PERSO-04) ; coupure automatique : « Cette app a été coupée automatiquement car elle bloquait. » (`perso.erreur.coupee_auto`).
- **Notifications** : celles envoyées par `App.notify`.
- **Liens** : Factures (`createInvoice`), journal (`log`), ADM-02 (coupure auto), ADM-14 (temps par app).
- **Réglages** : `Config.Apps.MaxInstructions = 5000000`, `Config.Apps.MaxTimers = 20`, `Config.Apps.TrustedApps = {}`, `Config.Apps.AutoCutStrikes = 3`.
- **Journal admin** : oui pour les coupures automatiques (type `perso.coupure_auto`) et pour chaque `App.log`.
- **Performance** : aucune minuterie sauf celles demandées par `App.setTimeout` ; temps de chaque appel mesuré (ADM-14).
- **Cas limites** :
  - `debug.sethook` indisponible sur la version du serveur : le compteur d'instructions est désactivé, la protection reste l'outil de vérification + coupure si un appel dépasse 500 ms trois fois (mesure `os.clock`), message console au démarrage.
  - Gestionnaire qui ne renvoie rien : réponse `{ ok = true, data = nil }`.
  - Deux `App.onCall` avec le même nom : le second remplace le premier, avertissement console.
- **Critères d'acceptation** :
  - Étant donné un gestionnaire contenant `while true do end`, quand l'action est appelée, alors elle est interrompue, le joueur voit « Le serveur n'a pas répondu… » et le serveur ne gèle pas.
  - Étant donné `server.lua` qui appelle `MySQL.query(...)`, quand il est chargé, alors `MySQL` vaut `nil` et l'app est refusée avec l'erreur et la ligne.
  - Étant donné un client qui envoie `data.amount = 999999` à `exemple_pourboire`, quand `App.createInvoice` est appelé avec ce montant, alors la facture est refusée par les règles Factures (montant max) et rien n'est débité.

### [PERSO-06] Isolation des données entre apps perso
- **But** : garantir qu'une app perso ne peut pas lire ni modifier les données d'une autre app, ni celles de la tablette.
- **Qui** : automatique.
- **Où** : stockage `pop_tablet_appdata`, routeur des appels, iframes.
- **Parcours** :
  1. Côté interface : chaque app dans sa propre iframe sans `allow-same-origin` ; la tablette déduit l'app émettrice de l'iframe ; les messages vers une app sont envoyés à son iframe uniquement (`iframe.contentWindow.postMessage(msg, '*')` sur la seule iframe de l'app).
  2. Côté serveur : la clé primaire du stockage commence par `app_id`, rempli par le cœur à partir de l'environnement de l'app (PERSO-05) ou de l'app identifiée par la tablette (PERSO-04) ; aucune fonction ne prend d'`app_id` en paramètre.
  3. Propriétaire (`owner`) calculé par le serveur : `player` → identifiant license du joueur appelant ; `company` → id de l'entreprise du joueur (refus s'il n'en a pas ou si l'entreprise n'a pas l'app) ; `global` → `'global'`.
  4. Un joueur tricheur qui forge des appels au nom d'une autre app n'obtient que ce qu'il aurait en ouvrant cette app normalement (mêmes contrôles d'accès) : pas d'élévation.
  5. Quotas : `Config.Apps.StorageMaxKeys = 200` clés par (app, scope, owner) ; `Config.Apps.MaxValueSize = 16384` octets par valeur.
- **Données** : `pop_tablet_appdata` (0.4).
- **Règles serveur** : ci-dessus ; écriture en base groupée (file + minuterie de 5 s créée à la première écriture, écriture immédiate dès 50 en attente, et à l'arrêt) ; lectures servies depuis un cache mémoire par (app, scope, owner) chargé au premier accès et libéré 10 min après le dernier accès (minuterie unique par entrée, détruite à l'expiration).
- **Textes et états** : « Espace de stockage plein pour cette app. » (`perso.erreur.quota`), « Accès à cette app refusé. » (`perso.erreur.acces`), « Fonction réservée aux membres d'une entreprise. » (`perso.erreur.sans_entreprise`).
- **Notifications** : aucune.
- **Liens** : PERSO-04, PERSO-05 ; admin : bouton « Effacer les données de cette app » dans Admin > Apps (confirmation, journalisé `perso.donnees_effacees`).
- **Réglages** : `Config.Apps.StorageMaxKeys = 200`, `Config.Apps.MaxValueSize = 16384`.
- **Journal admin** : oui pour l'effacement par l'admin.
- **Performance** : cache mémoire, écritures groupées.
- **Cas limites** :
  - Joueur qui change d'entreprise : il ne voit plus les données `company` de l'ancienne, voit celles de la nouvelle.
  - App supprimée puis remise avec le même id : elle retrouve ses données (même `app_id`).
  - App renommée (nouvel id) : nouvelles données vides ; l'ancienne reste en base jusqu'à effacement par l'admin.
- **Critères d'acceptation** :
  - Étant donné l'app A qui a écrit `player/notes`, quand l'app B lit `player/notes` pour le même joueur, alors elle reçoit `null`.
  - Étant donné un joueur de Dynasty 8, quand il lit `company/tableau` dans `exemple_tableau`, alors il voit les messages de Dynasty 8 et jamais ceux de la police.
  - Étant donné un client qui forge un appel de stockage avec `owner = 'license:autre_joueur'`, quand le serveur traite, alors le champ est ignoré et l'owner reste celui du joueur appelant.

### [PERSO-07] Apps d'exemple (3)
- **But** : montrer trois cas typiques, propres et sûrs, que l'on peut copier.
- **Qui** : développeurs et IA.
- **Où** : `apps/exemple_notes/`, `apps/exemple_tableau/`, `apps/exemple_pourboire/` (chargées par défaut ; désactivables par `Config.Apps.LoadExamples = true`).
- **Parcours et contenu** :
  1. **`exemple_notes` « Notes »** (access `tous`, scope `player`, **sans** `server.lua`) : liste paginée de notes personnelles (titre ≤ 60, texte ≤ 2000), créer, modifier, supprimer avec `PopApp.confirm`, stockage clé `n_<horodatage>`, 50 notes max (contrôle dans l'interface + quota serveur). Montre : `storage.list` paginé, états vide/chargement/erreur, `PopApp.el`, traductions.
     Textes : vide « Aucune note. » + bouton « Nouvelle note » ; succès « Note enregistrée. » ; erreur limite « 50 notes maximum. ».
  2. **`exemple_tableau` « Tableau d'équipe »** (access `entreprise`, `minLevel = 'recrue'`, scope `company`, avec `server.lua`) : messages d'équipe (texte ≤ 200), lecture par tous, publication dès Membre, suppression dès Chef ou par l'auteur, 1 message / 30 s par joueur, 100 messages max (les plus anciens supprimés), notification aux collègues ayant la tablette, `App.push` pour rafraîchir les tablettes ouvertes, `App.log` sur suppression. Montre : identité depuis `ctx`, droits avec `App.isAtLeast`, `App.rateLimit`, `App.sanitize`.
     Actions serveur : `list(page)`, `post({ text })`, `remove({ id })`.
     Textes : vide « Aucun message. » ; « Message publié. » ; « Grade requis : Membre » ; « 30 secondes minimum entre deux messages. ».
  3. **`exemple_pourboire` « Pourboire »** (access `entreprise`, `minLevel = 'recrue'`, scope aucun, avec `server.lua`) : l'employé choisit un client proche et un montant ; le client reçoit une vraie facture « Pourboire ». Montre : ne jamais faire confiance au client.
     Actions serveur : `nearby()` → `App.getNearbyPlayers(ctx.source, 3)` (liste calculée côté serveur, renvoyée avec des numéros temporaires valables 60 s) ; `send({ ref, amount })` → le serveur retrouve le joueur depuis `ref` dans **sa** liste mémorisée (jamais un `source` envoyé par le client), vérifie `amount` entier entre 1 et `App.settings.maxTip` (100 par défaut), vérifie l'entreprise et le service (`ctx.onDuty`), puis `App.createInvoice(ctx, cible, amount, 'Pourboire')`.
     Textes : vide « Personne à proximité. » ; « Pourboire demandé à {nom}. » ; « Montant entre 1 et {max} $. » ; « Ce client n'est plus à proximité. ».
- **Données** : stockage des exemples comme décrit ; `exemple_pourboire/settings.lua` : `return { maxTip = 100 }`.
- **Règles serveur** : celles décrites dans chaque app ; chacune passe `pop-check` avec 0 bloquant et 0 alerte.
- **Textes et états** : textes listés ci-dessus dans les `locales/fr.json` et `en.json` de chaque exemple.
- **Notifications** : `exemple_tableau` : « Nouveau message de {nom} sur le tableau d'équipe. » aux membres de l'entreprise ayant la tablette ; `exemple_pourboire` : la facture est notifiée par l'app Factures.
- **Liens** : Factures (pourboire), journal (tableau).
- **Réglages** : `Config.Apps.LoadExamples = true`.
- **Journal admin** : `exemple_tableau` journalise les suppressions (`perso.exemple_tableau`).
- **Performance** : aucune minuterie dans les 3 exemples ; chargement à l'ouverture.
- **Cas limites** :
  - Pourboire à un joueur qui s'éloigne entre `nearby` et `send` : refus (distance revérifiée par `createInvoice`).
  - Tableau : joueur qui quitte l'entreprise : n'a plus accès ; ses messages restent.
  - Notes : 50 notes et quota serveur à 200 : l'interface bloque à 50.
- **Critères d'acceptation** :
  - Étant donné un employé de Dynasty 8 en service et un client à 2 m, quand il envoie un pourboire de 20, alors le client reçoit une facture « Pourboire » de 20 $ émise par Dynasty 8.
  - Étant donné une Recrue, quand elle publie sur le tableau, alors elle voit « Grade requis : Membre ».
  - Étant donné un client qui envoie `send({ ref = 'x', amount = 1000000 })`, quand le serveur traite, alors refus « Montant entre 1 et 100 $. ».

### [PERSO-08] Outil de vérification des apps
- **But** : signaler automatiquement une app qui boucle, qui fait confiance au client ou qui contourne l'isolation, avant qu'elle n'abîme le serveur.
- **Qui** : développeurs (outil local), serveur (au démarrage), admin (console).
- **Où** : (a) `node tools/pop-check.js apps/<id>` (ou `apps/` pour tout vérifier) ; (b) automatiquement au démarrage pour chaque app (même règles, implémentées en Lua sur le texte des fichiers lu par `LoadResourceFile`) ; (c) commande console serveur `pop_tablet_check <id>` ; (d) Admin > Apps > « Voir le rapport ».
- **Parcours** :
  1. L'outil lit `app.lua`, `server.lua`, `settings.lua`, tous les `.js` et `.html` du dossier, `locales/*.json`.
  2. Il applique les règles ci-dessous (recherche de motifs, commentaires `--` / `//` / `/* */` ignorés).
  3. Sortie : une ligne par problème `[BLOQUANT|ALERTE] CODE fichier:ligne Message. Correction.` puis le total. Code de sortie Node : 1 s'il y a au moins un BLOQUANT, sinon 0.
  4. Au démarrage : une app avec au moins un BLOQUANT est refusée (PERSO-01) ; les ALERTES sont affichées en console et dans le rapport admin, l'app est chargée.
- **Données** (règles, version 1) :

| Code | Niveau | Ce qui est détecté | Message |
|---|---|---|---|
| MAN-01 | BLOQUANT | Champ obligatoire du manifeste absent ou invalide | « Manifeste incomplet : {champ}. » |
| MAN-02 | BLOQUANT | `id` différent du nom du dossier, ou commençant par `pop_` | « L'id doit être le nom du dossier et ne pas commencer par pop_. » |
| MAN-03 | BLOQUANT | `apiVersion` non supportée | « Version d'API {n} non supportée (versions : 1). » |
| MAN-04 | BLOQUANT | `app.lua` contient autre chose qu'un seul appel `PopApp.register({...})` | « app.lua ne doit contenir que PopApp.register. Placez le code dans server.lua. » |
| MAN-05 | BLOQUANT | `index.html` ou icône absente | « Fichier manquant : {fichier}. » |
| PERF-01 | BLOQUANT | Lua : `while true`, `while 1`, `repeat … until false` | « Boucle infinie. Réagissez à un appel ou utilisez App.setTimeout. » |
| PERF-02 | BLOQUANT | JS : `while (true)`, `while(1)`, `for (;;)` | « Boucle infinie dans l'interface : elle gèlerait la tablette. » |
| PERF-03 | ALERTE | JS : `setInterval(` avec un délai < 1000 ou sans `clearInterval` dans le même fichier | « Minuterie répétée : arrêtez-la dans PopApp.on('hide'). » |
| PERF-04 | ALERTE | JS : `requestAnimationFrame` | « Animation permanente : évitez-la ou arrêtez-la sur 'hide'. » |
| PERF-05 | ALERTE | Lua : `App.setTimeout` appelé dans sa propre fonction avec < 5000 ms | « Minuterie qui se relance trop souvent (boucle déguisée). » |
| PERF-06 | ALERTE | Fichier `.js` > 300 Ko | « Fichier lourd : l'ouverture de l'app sera lente. » |
| SEC-01 | ALERTE | JS : `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `document.write` | « Risque d'injection : utilisez textContent ou PopApp.el. » |
| SEC-02 | BLOQUANT | JS : `eval(`, `new Function(`, `setTimeout('…')` avec une chaîne | « Exécution de code dynamique interdite. » |
| SEC-03 | BLOQUANT | JS : `fetch(`, `XMLHttpRequest`, `WebSocket`, `EventSource`, `import(` vers `http` | « Appel réseau externe interdit. » |
| SEC-04 | BLOQUANT | Lua : `data.identifier`, `data.source`, `data.companyId`, `data.level`, `data.grade`, `data.isAdmin`, `data.owner` | « Identité venue du client : utilisez ctx.{champ}. » |
| SEC-05 | ALERTE | Lua : `data.amount`, `data.montant`, `data.price`, `data.prix`, `data.quantity`, `data.quantite`, `data.target`, `data.cible` utilisé sans `tonumber`/`math.floor` et sans comparaison `<`/`>` dans le même gestionnaire | « Valeur du client non vérifiée : contrôle le type et les bornes. » |
| SEC-06 | ALERTE | Lua : gestionnaire qui écrit en scope `global` sans `App.isAtLeast`/`App.hasPermission`/`ctx.isAdmin` | « Écriture globale sans contrôle de droit. » |
| ISO-01 | BLOQUANT | Chaîne `pop_tablet_appdata`, `apps/<autre id>/`, `MySQL`, `oxmysql`, `exports`, `TriggerServerEvent`, `TriggerClientEvent`, `RegisterNetEvent` (hors app de confiance) | « Accès hors de l'API des apps. » |
| ISO-02 | ALERTE | JS : `window.parent`, `top.`, `window.opener`, `localStorage`, `sessionStorage`, `indexedDB`, `document.cookie` | « Inaccessible dans une app perso : utilisez PopApp.storage. » |
| LANG-01 | ALERTE | `locales/fr.json` absent, ou clé utilisée par `PopApp.t`/`App.t` absente de `fr.json` | « Texte sans traduction : {clé}. » |

- **Règles serveur** : outil en lecture seule (n'écrit jamais dans les apps) ; commande console réservée à la console serveur ou à l'ACE `pop.tablet.admin` ; les apps de confiance (`TrustedApps`) sont dispensées de ISO-01 seulement.
- **Textes et états** :
  - Résumé : « {id} : {b} bloquant(s), {a} alerte(s). » (`perso.check.resume`) ; tout bon : « {id} : aucun problème. » (`perso.check.ok`).
  - Rapport admin vide : « Aucun problème détecté. » (`admin.apps.rapport_vide`).
  - Messages des règles : colonne « Message » (clés `perso.check.<code>`, ex. `perso.check.PERF-01`).
- **Notifications** : aucune.
- **Liens** : PERSO-01 (refus au démarrage), PERSO-03 (guide), ADM-02 (rapport).
- **Réglages** : `Config.Apps.CheckOnStart = true`, `Config.Apps.RefuseOnBlocking = true` (faux : les apps avec bloquant sont chargées quand même avec un avertissement rouge en console ; déconseillé).
- **Journal admin** : non (la ligne de démarrage PERSO-01 suffit).
- **Performance** : exécuté au démarrage une fois par app (quelques millisecondes) ; jamais pendant le jeu.
- **Cas limites** :
  - Faux positif dans une chaîne de caractères (ex. texte « while true » dans une traduction) : les fichiers `locales/*.json` ne sont pas analysés pour PERF/SEC ; dans le code, l'auteur peut ajouter le commentaire `-- pop-check: ignore PERF-01` (ou `// pop-check: ignore …`) sur la ligne pour les ALERTES uniquement (les BLOQUANTS ne sont jamais ignorables).
  - Node absent sur la machine du développeur : la vérification au démarrage du serveur reste active ; la commande console donne le même rapport.
  - Code minifié sur une seule ligne : les règles s'appliquent, les numéros de ligne valent 1.
- **Critères d'acceptation** :
  - Étant donné un `server.lua` contenant `while true do Wait(0) end`, quand la ressource démarre, alors l'app est refusée avec « PERF-01 … Boucle infinie ».
  - Étant donné un gestionnaire qui fait `App.storage.set({identifier = data.identifier}, …)`, quand `pop-check` tourne, alors il signale SEC-04 en BLOQUANT.
  - Étant donné un `app.js` qui fait `el.innerHTML = msg.text`, quand `pop-check` tourne, alors il signale SEC-01 en ALERTE et l'app est quand même chargée.

### [PERSO-09] Kit de style des apps perso (ajout)
- **But** : que les apps perso ressemblent à la tablette (sobre, HUD GTA 6) sans recopier son code.
- **Qui** : développeurs et IA.
- **Où** : `apps/_sdk/pop-app.css` (ouvert, écrasé à chaque mise à jour), documenté dans `docs/kit-de-style.md`.
- **Parcours** :
  1. L'app inclut `../_sdk/pop-app.css`.
  2. La tablette envoie à l'ouverture et à chaque changement l'événement `theme` ; `pop-app.js` met à jour `--pop-accent` sur `:root`.
  3. Variables fournies : `--pop-fond` (fond de l'app), `--pop-surface` (cartes, champs), `--pop-bordure`, `--pop-texte`, `--pop-texte-2` (secondaire), `--pop-accent` (couleur de l'entreprise ou de la tablette), `--pop-danger`, `--pop-succes`, `--pop-rayon: 4px`, `--pop-espace: 8px`, `--pop-police: system-ui, sans-serif`, `--pop-fondu: 150ms`. Les valeurs sont celles du thème de la tablette (fiche de base), copiées à l'identique.
  4. Classes fournies : `pop-app` (conteneur), `pop-titre`, `pop-sous-titre`, `pop-texte-2`, `pop-bouton`, `pop-bouton--principal`, `pop-bouton--danger`, `pop-champ` (input/textarea/select), `pop-etiquette`, `pop-liste`, `pop-ligne`, `pop-carte`, `pop-vide` (état vide : phrase + bouton), `pop-squelette` (forme grise de chargement), `pop-bandeau--erreur`, `pop-grise` (pas le droit), `pop-pagination`.
  5. Le SDK fournit aussi `PopApp.ui.empty(text, buttonText, onClick)`, `PopApp.ui.skeleton(lines)`, `PopApp.ui.error(text, onRetry)` qui produisent les 6 états d'écran standard (avec « Réessayer » au-delà de 5 s de chargement).
- **Données** : fichiers CSS/JS du SDK.
- **Règles serveur** : aucune.
- **Textes et états** : textes standard du SDK traduits par la tablette : « Réessayer » (`commun.bouton.reessayer`), « Le chargement prend du temps. » (`commun.chargement.long`), « Précédent » / « Suivant ».
- **Notifications** : aucune.
- **Liens** : PERSO-02, PERSO-03, PERSO-04 (`ui.*` complète la liste de fonctions de PERSO-04).
- **Réglages** : aucun (l'accent suit la tablette).
- **Journal admin** : non.
- **Performance** : CSS < 15 Ko, aucune police externe, aucune image.
- **Cas limites** :
  - App qui redéfinit les variables : autorisé, mais `pop-check` ne le signale pas (liberté de style).
  - Accent très clair : le texte des boutons principaux passe en noir si la luminance de l'accent > 0,6 (calcul dans `pop-app.js`).
  - App sans le kit : fonctionne, mais l'aspect n'est pas garanti.
- **Critères d'acceptation** :
  - Étant donné l'app modèle dans une tablette Dynasty 8 (accent vert), quand elle s'ouvre, alors son bouton principal est vert.
  - Étant donné `PopApp.ui.skeleton(3)` affiché plus de 5 s, quand le délai passe, alors le message « Le chargement prend du temps. » et « Réessayer » apparaissent.
  - Étant donné une app qui tente de charger une police depuis internet, quand `pop-check` tourne, alors SEC-03 la signale si c'est un appel `fetch`, et la police ne charge pas (pas de réseau externe dans le kit).

---

## Décisions prises par défaut

1. **Préfixe `SITE-CRE-` pour le créateur d'entreprises** : appliqué tel que demandé (créateur = « CRE »), bien qu'il ne s'agisse pas de sites.
2. **Tables et noms** : toutes les tables de ce fichier sont préfixées `pop_tablet_` ; si la fiche de base ou la fiche Entreprises définit déjà `pop_tablet_companies` / `pop_tablet_company_grades`, leur définition fait foi et les colonnes d'ici y sont ajoutées.
3. **Créer un métier depuis la tablette** : autorisé sur les trois frameworks (ESX : insertion dans `jobs` / `job_grades` + `ESX.RefreshJobs()` si disponible, sinon redémarrage demandé ; QBCore `QBCore.Functions.AddJob` ; Qbox `exports.qbx_core:CreateJob` ; QBCore / Qbox : métier gardé dans `pop_tablet_company_grades` et recréé à chaque démarrage). Une entreprise sans métier lié n'a pas d'employés. L'assistant de premier démarrage utilise ce mécanisme pour proposer de créer les métiers du Tribunal et du Cabinet d'avocats s'ils n'existent pas (BASE-MOT-15).
4. **Entreprises par défaut** : 7 (police, EMS « Services médicaux », mécano « Los Santos Customs », immobilier « Dynasty 8 », concession « Premium Deluxe Motorsport », « Tribunal de Los Santos » et « Cabinet d'avocats », reliées aux métiers `justice` et `avocat` de l'app Justice, fichier 04), installées une seule fois de toute la vie du serveur ; une entreprise dont le métier n'existe pas est créée « non reliée ». Pour le Tribunal et le Cabinet d'avocats, souvent absents, l'assistant de premier démarrage (BASE-MOT-15, étape « Justice ») propose de créer le métier, de le relier à un métier existant ou de ne pas les utiliser. Aucun gang par défaut (créés par l'admin avec le modèle `gang`).
5. **Brique `gestion` obligatoire** pour toute entreprise ; **une seule app métier** par entreprise.
6. **Export / import** : fichier JSON écrit dans `pop_tablet/exports/` et lu dans `pop_tablet/imports/` (plus copier/coller), jamais d'employés, d'argent ni de documents ; tout contenu importé arrive en brouillon.
7. **Adresse de site** : suffixe unique `.rp`, 3 à 24 caractères, changement réservé au Patron, une fois tous les 7 jours, ancienne adresse redirigée 7 jours.
8. **Édition** : chaque action sur un bloc est envoyée tout de suite au serveur (pas de bouton « Enregistrer le brouillon ») ; un seul éditeur à la fois (verrou de 10 min) ; publication explicite avec historique de 20 versions.
9. **Limites des sites** : 5 pages (réglable 1 à 20), 30 blocs par page, 50 articles par catalogue, 12 images par galerie, 64 Ko par site, prix entiers uniquement, catalogue de site non relié au stock (choix définitif : le stock reste interne à l'entreprise).
10. **Visites** : un visiteur = un joueur différent par site et par jour ; les membres de l'entreprise et les aperçus ne comptent pas ; écriture groupée toutes les 5 min (jusqu'à 5 min perdues en cas de crash).
11. **Domaines d'images par défaut** : `i.imgur.com` et `r2.fivemanage.com` (les liens Discord expirent, donc exclus), https obligatoire, extensions png/jpg/jpeg/webp/gif.
12. **Tablettes** : numéro `PT-XXXX-XXXX` ; avec ox_inventory / qs-inventory le numéro est dans les métadonnées de l'objet, sans métadonnées une tablette par personnage.
13. **Discord** : liens uniquement dans `server.cfg` (convars `pop_tablet_webhook*`), envoi groupé toutes les 2 s, mentions neutralisées.
14. **Pas de boutique dans la tablette** : ADM-15 est supprimée ; la vente de la tablette et du chargeur (prix compris) est gérée par le script de boutique du serveur. Réinitialisation par l'admin (ADM-04, `/tablette_reset`) et par l'export `ResetTablet(serial)` ; remplacement d'une tablette perdue par l'export `ReplaceTablet(source, oldSerial)` (BASE-OBJ-08).
15. **Apps perso** : détection par `apps/*/app.lua` dans le fxmanifest (redémarrage nécessaire) ; code serveur exécuté dans un environnement Lua fermé (pas de framework, de SQL ni de natives) avec compteur d'instructions et coupure automatique après 3 blocages ; option `Config.Apps.TrustedApps` pour lever ces limites app par app ; pas de `client.lua` pour les apps perso (choix de sécurité définitif : tout le code client d'une app perso est dans son iframe NUI).
16. **Guide IA** : `CLAUDE.md` à la racine de la ressource, avec un `AGENTS.md` qui y renvoie ; outil de vérification livré en double (Node `tools/pop-check.js` + contrôle Lua au démarrage).


> **Relecture croisée (24/11/2026)** : ce fichier a été aligné sur les 5 autres. Les noms communs (signaux, tables, réglages, droits, textes d'erreur, constantes) sont listés dans `00-sommaire.md`, qui fait foi en cas de doute.
