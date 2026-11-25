# POP Tablet · 1 · La base (système de la tablette + moteur invisible)

Fiches de fonctionnalités, préfixe `BASE-`. Sous-préfixes : `BASE-OBJ` (l'objet tablette), `BASE-ECR` (l'écran), `BASE-MOT` (le moteur invisible), `BASE-API` (API pour les apps).
À lire avec `_contexte.md`. Tout ce qui est écrit ici est une décision : le développeur l'applique tel quel.

---

## 0. Conventions communes à toutes les fiches de la base

Ces conventions sont valables pour toutes les fiches ci-dessous ; une fiche ne les répète pas, elle les applique.

**Ressource et fichiers**
- Nom de ressource : `pop_tablet`. Structure de `docs/methode.md` : `fxmanifest.lua`, `config.lua`, `bridge/`, `shared/`, `client/`, `server/`, `locales/`, `web/`, `sql/install.sql`, plus `apps/` (dossier « mes apps », ouvert) et `docs/` (guide pour l'IA, API).
- Ouverts (listés dans `escrow_ignore`) : `config.lua`, `locales/*.lua`, `apps/**`, `web/kit/**`, `docs/**`, `bridge/**`. Tout le reste est chiffré.
- APIs internes imposées : `Bridge.*` (framework, argent, items, job, target, notifications), `Callback.*` (sans ox_lib), `L(cle, params)` (traductions), `Pop.*` côté NUI.

**Objets d'inventaire**
| Objet | Nom technique | Libellé FR | Poids | Empilable |
|---|---|---|---|---|
| Tablette | `pop_tablet` | « Tablette » | 500 g | Non (inventaire à métadonnées) |
| Chargeur | `pop_tablet_charger` | « Chargeur de tablette » | 200 g | Oui |

**Tables SQL** (préfixe `pop_tablet_`, moteur InnoDB, `utf8mb4`) : `pop_tablet_meta`, `pop_tablet_devices`, `pop_tablet_notifications`, `pop_tablet_appdata`, `pop_tablet_logs`, `pop_tablet_payments`. Colonnes détaillées dans chaque fiche, schéma complet dans `BASE-MOT-17`.

**Échanges client ↔ serveur**
- Une seule porte d'entrée pour toutes les demandes de la NUI, **pour toute la tablette (fichiers 01 à 06)** : callback `pop_tablet:request` (via `Callback.*`, sans ox_lib) avec `{ token, app, action, data, actionId }`. Le serveur répond `{ ok = true, data = ... }` ou `{ ok = false, err = '<code ou clé>', args = {...} }`. Si `err` ne contient pas de point, c'est un code commun traduit avec la clé `commun.erreur.<code>` ; s'il contient un point, c'est une clé de langue complète (ex. `police.mandats.doublon`).
- Notation dans les fiches : `RPC gestion.service.prendre`, `pop_tablet:sites:addBlock`, `ems:duty:toggle` désignent tous **une action passée par `pop_tablet:request`** (premier segment après `pop_tablet:` éventuel = `app`, le reste = `action`). Ce ne sont jamais des événements réseau séparés.
- `token` = jeton de session de 32 caractères créé par le serveur à l'ouverture (`BASE-OBJ-01`), détruit à la fermeture. Toute demande sans jeton valide est refusée (`session`).
- `actionId` = identifiant unique généré par la NUI (UUID v4) pour chaque action qui modifie quelque chose ; le serveur garde en mémoire les `actionId` traités pendant 10 minutes : un `actionId` déjà vu renvoie **la même réponse que la première fois** sans rien refaire (anti double clic, valable pour tous les fichiers).
- Événements serveur → client : préfixe `pop_tablet:client:` ; événements internes du bridge : préfixe `pop_tablet:bridge:` ; signaux publics pour les autres scripts : `pop_tablet:<nomEnAnglais>` émis côté serveur seulement (liste unique dans `00-sommaire.md`) ; messages client → NUI : `SendNUIMessage({ type = 'pop:<nom>', ... })` ; callbacks NUI → client : `RegisterNUICallback('<nom>')`.

**Registre des textes** : style Apple (décision du client) : formulations neutres et courtes en priorité (« Facture envoyée. », « Code incorrect. », « Aucune facture. »), **vouvoiement** quand une adresse directe est nécessaire (« Vous n'avez pas les droits nécessaires. »), jamais de tutoiement. Les textes écrits entre guillemets dans les fiches sont déjà dans ce ton et se recopient tels quels dans `locales/fr.lua`.

**Codes d'erreur communs** (clé `commun.erreur.<code>`) : liste unique pour les 6 fichiers ; les autres fichiers y renvoient.
| Code | Texte FR |
|---|---|
| `session` | « La tablette a été fermée. Rouvrez-la pour continuer. » |
| `pas_tablette` | « Tablette introuvable dans l'inventaire. » |
| `pas_droit` | « Vous n'avez pas les droits nécessaires. » |
| `trop_vite` | « Trop d'actions. Réessayez dans quelques secondes. » |
| `doublon` | « Cette action a déjà été faite. » |
| `invalide` | « Certaines informations ne sont pas valides. » |
| `trop_loin` | « La personne est trop loin. » |
| `serveur` | « Un problème est survenu. Réessayez dans un instant. » |
| `reseau` | « Aucun réseau. » |
| `batterie` | « Batterie vide. Rechargez la tablette. » |
| `hors_service` | « Service requis pour utiliser cette app. » |
| `hors_ligne` | « Cette personne n'est plus en ville. » |
| `trop_long` | « Texte trop long : {max} caractères maximum. » |
| `champ_requis` | « Champ requis : « {champ} ». » |
| `image` | « Image refusée. Utilisez une photo de la galerie ou un lien d'un site autorisé. » |
| `introuvable` | « Élément introuvable. Il a peut-être été archivé. » |
| `jeton_expire` | « Fiche expirée. Relancez la recherche. » |
| `fonds_entreprise` | « Le compte de l'entreprise n'a pas assez d'argent. » |
| `admin_requis` | « Réservé aux administrateurs du serveur. » |
| `lecture_seule` | « Lecture seule. » |

Textes d'écran communs : `commun.droit.grade_requis` « Grade requis : {grade} » (bulle d'un bouton grisé) · `commun.chargement.long` « Le chargement prend plus de temps que prévu. » + `commun.bouton.reessayer` « Réessayer » · `commun.succes` « C'est fait. » · `commun.succes.enregistre` « Enregistré. » · `commun.hors_service.titre` « Hors service. » + `commun.hors_service.bouton` « Prendre mon service » · `commun.bouton.annuler` « Annuler » · `commun.bouton.confirmer` « Confirmer » · `commun.bouton.enregistrer` « Enregistrer » · `commun.bouton.supprimer` « Supprimer » · `commun.bouton.fermer` « Fermer » · `commun.bouton.retour` « Retour » · `commun.pagination.precedent` / `commun.pagination.suivant` « Précédent » / « Suivant » · `commun.entreprise.archivee` « Cette entreprise n'existe plus. ».

**Écran de la tablette** : 1180 × 760 px de référence, centré, mis à l'échelle pour occuper au plus 85 % de la hauteur et 90 % de la largeur de l'écran du joueur, coins arrondis 18 px, bord noir 14 px (cadre de l'appareil). Fondu d'ouverture et de fermeture 150 ms.

**Admin** : ACE `pop.tablet.admin` (vérifiée avec `IsPlayerAceAllowed`). La console serveur est toujours considérée comme admin.

**Secrets** : les liens Discord sont des convars dans `server.cfg` (`set pop_tablet_webhook "..."`), jamais dans `config.lua` ni dans le dépôt.

**Heure** : toutes les dates stockées en base sont des horodatages Unix en secondes (`INT UNSIGNED`) donnés par `os.time()` côté serveur. Les dates affichées sont formatées par la NUI au format `JJ/MM/AAAA HH:MM` (fr) ou `MM/DD/YYYY HH:MM` (en).

---

## 1. La tablette (l'objet)

### [BASE-OBJ-01] Ouvrir la tablette en utilisant l'objet
- **But** : utiliser l'objet « Tablette » dans l'inventaire ouvre la tablette du joueur.
- **Qui** : tout joueur qui possède l'objet `pop_tablet` ; pas de droit requis ; non réglable.
- **Où** : inventaire > objet « Tablette » > « Utiliser ». Même résultat via le raccourci clavier (`BASE-OBJ-13`) et la commande `/tablette`.
- **Parcours** :
  1. Le joueur utilise l'objet. L'inventaire appelle l'objet utilisable enregistré par `Bridge.RegisterUsableItem('pop_tablet', cb)` côté serveur ; `cb(source, item)` reçoit l'objet avec ses métadonnées quand l'inventaire en a.
  2. Le serveur vérifie dans l'ordre : joueur chargé (`Bridge.GetPlayer`), objet réellement possédé (`Bridge.HasItem`), joueur ni mort ni inconscient (`Bridge.IsDead`), pas déjà une session ouverte, anti-spam (1 ouverture par 2 s). Chaque échec arrête le parcours avec la notification correspondante.
  3. Le serveur récupère ou crée le numéro de série (`BASE-OBJ-03`), charge la fiche de l'appareil depuis le cache ou la base (`BASE-MOT-05`), calcule la batterie (`BASE-ECR-06`). Si batterie = 0 % : refus avec « Batterie vide. Rechargez la tablette. ».
  4. Le serveur crée le jeton de session, calcule la liste des apps autorisées (`BASE-ECR-01`) et envoie `pop_tablet:client:open` avec : jeton, numéro de série, réglages, batterie, état verrouillé ou non, liste des apps, nombre de notifications non lues, statut en service, langue.
  5. Le client vérifie les conditions locales (`BASE-OBJ-16`), lance l'animation (`BASE-OBJ-02`), met `SetNuiFocus(true, true)` et envoie `pop:open` à la NUI.
  6. La NUI affiche en fondu 150 ms l'écran de verrouillage si un code existe (`BASE-OBJ-05`), sinon le bureau. Au tout premier démarrage d'une tablette neuve, la NUI affiche l'écran « Bienvenue » (`BASE-OBJ-17`).
  7. Fermeture : touche Échap sur le bureau, bouton physique (rond en bas du cadre) ou rappel du raccourci. Le client envoie `pop_tablet:close` au serveur, arrête l'animation, retire le focus, la NUI se cache en 150 ms. Le serveur détruit le jeton, enregistre la consommation de batterie et marque l'appareil « à sauvegarder ».
- **Données** :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| token | chaîne | Oui | 32 caractères [a-zA-Z0-9] | généré |
| serial | chaîne | Oui | format `PT-XXXX-XXXX` | généré |
| openedAt | entier (horodatage) | Oui | — | `os.time()` |
| session en mémoire serveur | table `Sessions[source]` | Oui | 1 par joueur | — |
- **Règles serveur** : possession vérifiée à l'ouverture puis à chaque demande (`BASE-MOT-01`) ; 1 seule session par joueur ; 1 ouverture toutes les 2 s maximum ; refus si mort ; refus si batterie vide ; refus si appareil bloqué n'empêche pas l'ouverture (l'écran de verrouillage affiche le décompte).
- **Textes et états** :
  - « Aucune tablette. » `base.ouvrir.pas_objet`
  - « Impossible d'utiliser la tablette maintenant. » `base.ouvrir.impossible` (mort, menotté, nage, ragdoll)
  - « Batterie vide. Rechargez la tablette. » `commun.erreur.batterie`
  - « Trop d'actions. Réessayez dans quelques secondes. » `commun.erreur.trop_vite`
- **Notifications** : aucune (les messages ci-dessus passent par `Bridge.Notify` car la tablette n'est pas ouverte).
- **Liens** : point d'entrée de toutes les apps ; émet l'événement serveur local `pop_tablet:opened(source, serial)` et `pop_tablet:closed(source, serial, secondesOuvertes)` pour les autres modules.
- **Réglages** : `Config.Item.Name = 'pop_tablet'` · `Config.Open.Command = 'tablette'` · `Config.Open.Cooldown = 2` (secondes).
- **Journal admin** : non (ouverture trop fréquente) ; activable avec `Config.Log.Open = false`.
- **Performance** : rien n'est chargé avant l'utilisation ; à l'ouverture, seules la fiche appareil et la liste d'apps partent au client (pas les données des apps).
- **Cas limites** :
  - Le joueur se déconnecte tablette ouverte : `playerDropped` détruit la session, calcule la batterie, sauvegarde l'appareil immédiatement.
  - Double usage de l'objet en moins de 2 s : la seconde demande est ignorée sans message.
  - L'objet est retiré de l'inventaire pendant que la tablette est ouverte (vol, don, fouille) : à la demande suivante le serveur répond `pas_tablette`, la NUI affiche le message 2 s puis le client ferme la tablette.
  - La ressource redémarre tablette ouverte : `onResourceStop` côté client ferme la NUI, retire le focus, supprime le prop.
- **Critères d'acceptation** :
  - Étant donné un joueur avec l'objet et 50 % de batterie, quand il utilise l'objet, alors la tablette s'ouvre en moins de 300 ms avec l'animation en main.
  - Étant donné un joueur sans l'objet, quand il tape `/tablette`, alors rien ne s'ouvre et il voit « Aucune tablette. ».
  - Étant donné un tricheur qui déclenche `pop_tablet:request` sans session, quand le serveur reçoit la demande, alors elle est refusée avec `session` et rien n'est renvoyé.
  - Étant donné une tablette ouverte, quand le joueur appuie sur Échap depuis le bureau, alors la tablette se ferme, le focus est rendu et le prop disparaît.

### [BASE-OBJ-02] Animation en main
- **But** : le joueur tient visiblement une tablette pendant qu'il l'utilise.
- **Qui** : tout joueur qui ouvre la tablette ; non réglable par joueur, réglable par le serveur.
- **Où** : automatique à l'ouverture (`BASE-OBJ-01`), arrêtée à la fermeture.
- **Parcours** :
  1. À l'ouverture, le client charge le dictionnaire `amb@code_human_in_bus_passenger_idles@female@tablet@base` (attente max 1 s, sinon pas d'animation mais la tablette s'ouvre quand même).
  2. Le client crée le prop `prop_cs_tablet` (réseau, visible des autres), l'attache à l'os 60309 (main gauche) avec décalage `0.03, 0.002, -0.0` et rotation `10.0, 160.0, 0.0`.
  3. Le client joue l'animation `base` en boucle, drapeau 49 (haut du corps, le joueur peut marcher lentement).
  4. Si le joueur est conducteur d'un véhicule : pas d'animation ni de prop. Passager : animation et prop.
  5. À la fermeture : `StopAnimTask`, suppression du prop, `RemoveAnimDict`, `SetModelAsNoLongerNeeded`.
  6. En mode posée (`BASE-OBJ-10`), l'animation en main s'arrête et laisse place à l'objet au sol.
- **Données** : aucune donnée stockée. Valeurs de config uniquement.
- **Règles serveur** : aucune (purement visuel). Le prop est supprimé par le serveur s'il reste orphelin (joueur déconnecté) via `DeleteEntity` sur l'identifiant réseau gardé dans la session.
- **Textes et états** : aucun texte.
- **Notifications** : aucune.
- **Liens** : `BASE-OBJ-10` (mode posée), `BASE-OBJ-16` (fermeture forcée).
- **Réglages** : `Config.Anim.Enabled = true` · `Config.Anim.Dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base'` · `Config.Anim.Name = 'base'` · `Config.Anim.Prop = 'prop_cs_tablet'` · `Config.Anim.Bone = 60309` · `Config.Anim.Offset = vec3(0.03, 0.002, -0.0)` · `Config.Anim.Rotation = vec3(10.0, 160.0, 0.0)` · `Config.Anim.Flag = 49`.
- **Journal admin** : non.
- **Performance** : aucune boucle ; le dictionnaire est chargé à l'ouverture et libéré à la fermeture.
- **Cas limites** :
  - Le modèle du prop n'existe pas (config erronée) : pas de prop, avertissement console une seule fois, la tablette fonctionne.
  - Le joueur entre dans un véhicule tablette ouverte comme conducteur : le prop et l'animation sont retirés (événement d'entrée en véhicule), la tablette reste ouverte si le véhicule est à l'arrêt (`BASE-OBJ-16`).
  - Le joueur meurt : fermeture forcée et suppression du prop.
- **Critères d'acceptation** :
  - Étant donné un joueur à pied, quand il ouvre la tablette, alors un autre joueur voit le prop dans sa main gauche.
  - Étant donné une tablette ouverte, quand elle se ferme, alors aucun prop ne reste attaché ni au sol.
  - Étant donné un client modifié qui ne supprime pas le prop, quand le joueur se déconnecte, alors le serveur supprime le prop orphelin.

### [BASE-OBJ-03] Numéro de série
- **But** : chaque tablette a un identifiant unique qui porte ses données personnelles.
- **Qui** : attribué automatiquement ; visible par le propriétaire ; recherche par l'admin.
- **Où** : Réglages > À propos > « Numéro de série » ; description de l'objet dans l'inventaire (inventaires à métadonnées) ; app Admin (branche Admin) pour chercher une tablette.
- **Parcours** :
  1. À la première utilisation, le serveur lit la métadonnée `serial` de l'objet.
  2. Si elle est absente : il génère `PT-` + 4 caractères + `-` + 4 caractères pris dans l'alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (sans 0, O, 1, I), vérifie l'unicité dans `pop_tablet_devices` (nouvel essai jusqu'à 5 fois), insère la ligne de l'appareil, puis écrit la métadonnée sur l'objet avec `Bridge.SetItemMetadata(source, slot, { serial = 'PT-...', description = 'N° de série : PT-...' })`.
  3. Inventaire sans métadonnées : voir `BASE-OBJ-15` (un numéro de série par personnage).
  4. Le numéro est envoyé à la NUI à l'ouverture et affiché dans Réglages > À propos.
- **Données** (`pop_tablet_devices`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| serial | VARCHAR(12) clé primaire | Oui | `PT-XXXX-XXXX` | généré |
| owner_identifier | VARCHAR(64) | Non | identifiant framework du dernier utilisateur | NULL |
| mode | ENUM('item','character') | Oui | — | selon l'inventaire |
| pin_hash | VARCHAR(100) | Non | hachage bcrypt | NULL |
| pin_fails | TINYINT | Oui | 0 à 5 | 0 |
| locked_until | INT UNSIGNED | Oui | horodatage | 0 |
| battery | DECIMAL(5,2) | Oui | 0 à 100 | 100 |
| settings | LONGTEXT JSON | Oui | ≤ 16 Ko | `{}` |
| first_boot_done | TINYINT(1) | Oui | 0/1 | 0 |
| created_at | INT UNSIGNED | Oui | — | `os.time()` |
| reset_at | INT UNSIGNED | Non | — | NULL |
| disabled | TINYINT(1) | Oui | 0/1 ; 1 = tablette remplacée, ne s'ouvre plus (`BASE-OBJ-08`) | 0 |
| last_used_at | INT UNSIGNED | Oui | — | `os.time()` |
- **Règles serveur** : le numéro est toujours généré côté serveur ; un numéro envoyé par le client est ignoré ; un objet dont la métadonnée `serial` n'existe pas en base est traité comme une tablette neuve (nouvelle ligne avec ce numéro s'il respecte le format et n'est pas pris, sinon nouveau numéro).
- **Textes et états** : « Numéro de série » `base.reglages.apropos.serie` ; « N° de série : %s » `base.objet.description`.
- **Notifications** : aucune.
- **Liens** : données perso (`BASE-OBJ-14`), réinitialisation (`BASE-OBJ-08`, `BASE-OBJ-09`), journal admin.
- **Réglages** : `Config.Serial.Prefix = 'PT'`.
- **Journal admin** : oui, « tablette créée » (numéro, identifiant du joueur, date).
- **Performance** : génération uniquement à la première utilisation ; lecture depuis le cache ensuite.
- **Cas limites** :
  - Deux joueurs utilisent en même temps deux tablettes neuves : clé primaire unique, en cas de collision l'insertion échoue et un nouveau numéro est tiré.
  - Un admin donne une tablette avec une métadonnée `serial` inventée : traité comme décrit dans les règles serveur, jamais de partage des données d'une autre tablette si le format est invalide.
  - Un objet est dupliqué par un bug d'inventaire (deux objets, même numéro) : les deux ouvrent les mêmes données ; le journal enregistre « numéro utilisé par deux joueurs » si deux sessions avec le même numéro sont ouvertes en même temps, et la seconde ouverture est refusée avec « Cette tablette est déjà utilisée. » `base.ouvrir.deja_utilisee`.
- **Critères d'acceptation** :
  - Étant donné une tablette neuve dans ox_inventory, quand le joueur l'utilise, alors l'objet reçoit une métadonnée `serial` au bon format et une ligne est créée en base.
  - Étant donné une tablette donnée à un autre joueur, quand il l'ouvre, alors il voit le même numéro de série et les mêmes réglages.
  - Étant donné un client qui envoie un numéro de série dans une demande, quand le serveur traite la demande, alors il utilise uniquement le numéro lié à la session.

### [BASE-OBJ-04] Créer un code de verrouillage
- **But** : protéger les données personnelles de la tablette par un code de 4 à 6 chiffres.
- **Qui** : le joueur qui tient la tablette (déverrouillée) ; non réglable.
- **Où** : Réglages > Sécurité > « Créer un code » ; proposé aussi à l'écran « Bienvenue » (`BASE-OBJ-17`).
- **Parcours** :
  1. Le joueur touche « Créer un code ». La NUI affiche un pavé numérique (chiffres 0 à 9, « Effacer », « Valider ») et des points pour chaque chiffre tapé. Le clavier physique (chiffres, Retour arrière, Entrée) fonctionne aussi.
  2. Le joueur tape 4 à 6 chiffres puis « Valider » ; la NUI demande « Confirmer le code » et le joueur le retape.
  3. Si les deux saisies diffèrent : message d'erreur, retour à l'étape 2 vide.
  4. La NUI envoie l'action `base.pin.create` avec le code.
  5. Le serveur vérifie : session valide, aucun code déjà défini, format (`^%d%d%d%d%d?%d?$`), code non trivial interdit seulement si `Config.Lock.ForbidSimple = true` (refuse `0000`, `1234`, `1111`… : tous chiffres identiques ou suite croissante/décroissante).
  6. Le serveur calcule `GetPasswordHash(code)` (bcrypt natif FiveM), écrit `pin_hash` en base immédiatement (écriture non groupée), remet `pin_fails = 0`.
  7. La NUI affiche le bandeau succès 2 s et revient à Réglages > Sécurité qui montre maintenant « Changer le code » et « Retirer le code ».
- **Données** :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| code saisi | chaîne de chiffres | Oui | 4 à 6 chiffres | — |
| pin_hash | VARCHAR(100) | Oui | bcrypt | NULL |
- **Règles serveur** : format revérifié ; le code n'est jamais stocké en clair ni écrit dans les journaux ; anti-spam 3 essais par 30 s ; refus si un code existe déjà (`invalide`).
- **Textes et états** :
  - « Créer un code » `base.securite.creer` · « Code de 4 à 6 chiffres » `base.securite.choisir` · « Confirmer le code » `base.securite.confirmer`
  - Succès : « Code enregistré. » `base.securite.cree`
  - Erreur différence : « Les codes ne correspondent pas. » `base.securite.different`
  - Erreur format : « Le code doit contenir 4 à 6 chiffres. » `base.securite.format`
  - Erreur trop simple : « Code trop simple. » `base.securite.simple`
  - Vide (aucun code) : « Aucun code. N'importe qui peut ouvrir cette tablette. » `base.securite.aucun` + bouton « Créer un code ».
- **Notifications** : aucune.
- **Liens** : `BASE-OBJ-05`, `BASE-OBJ-06`, `BASE-OBJ-07`.
- **Réglages** : `Config.Lock.MinLength = 4` · `Config.Lock.MaxLength = 6` · `Config.Lock.ForbidSimple = false`.
- **Journal admin** : oui, « code créé » (numéro de série, joueur), jamais le code.
- **Performance** : une écriture en base, aucune autre charge.
- **Cas limites** :
  - Double clic sur « Valider » : `actionId` identique, la seconde demande renvoie `doublon` et n'affiche rien.
  - Le joueur ferme la tablette au milieu de la saisie : rien n'est enregistré.
  - Le joueur tape 7 chiffres : la NUI ignore le 7e chiffre ; si un client modifié l'envoie, le serveur refuse avec `base.securite.format`.
- **Critères d'acceptation** :
  - Étant donné une tablette sans code, quand le joueur crée `4821` et le confirme, alors à la réouverture l'écran de verrouillage demande le code.
  - Étant donné une saisie `4821` puis `4822`, quand il valide, alors il voit « Les codes ne correspondent pas. ».
  - Étant donné un client modifié qui envoie `abc`, quand le serveur reçoit, alors il refuse et rien n'est écrit.

### [BASE-OBJ-05] Déverrouiller la tablette avec le code
- **But** : n'ouvrir le bureau qu'après le bon code.
- **Qui** : tout joueur qui ouvre une tablette protégée par un code.
- **Où** : écran de verrouillage, affiché à chaque ouverture si un code existe.
- **Parcours** :
  1. La NUI affiche : heure du jeu en grand, batterie, numéro de série en petit, le texte « Saisir le code », le pavé numérique et des points vides (nombre non révélé : 6 emplacements gris, remplis au fur et à mesure).
  2. Le joueur tape le code puis « Valider » (ou Entrée). La NUI envoie `base.pin.unlock` avec le code.
  3. Le serveur vérifie : session valide ; appareil non bloqué (`locked_until <= os.time()`) ; `VerifyPasswordHash(code, pin_hash)`.
  4. Bon code : `pin_fails = 0`, la session passe à `unlocked = true`, le serveur renvoie `ok`. La NUI affiche le bureau en fondu 150 ms.
  5. Mauvais code : `pin_fails + 1`, le serveur renvoie le nombre d'essais restants. La NUI secoue les points (80 ms × 3) et affiche le message. À 5 échecs : `BASE-OBJ-07`.
  6. Tant que la session n'est pas `unlocked`, le serveur refuse toute demande d'app avec `session` (sauf `base.pin.unlock` et `base.close`).
  7. Le déverrouillage vaut jusqu'à la fermeture : chaque réouverture redemande le code. Le mode posée (`BASE-OBJ-10`) ne redemande pas le code au propriétaire tant que l'objet est posé.
- **Données** : `pin_fails` et `locked_until` de `pop_tablet_devices` ; `unlocked` dans la session mémoire.
- **Règles serveur** : vérification exclusivement serveur ; 1 essai par seconde maximum ; le compteur d'échecs est lié au numéro de série (pas au joueur) et survit aux reconnexions ; `pin_fails` écrit en base immédiatement.
- **Textes et états** :
  - « Saisir le code » `base.verrou.titre`
  - Mauvais code : « Code incorrect. Encore %d essai(s). » `base.verrou.faux`
  - « Code oublié ? Faites réinitialiser la tablette. » `base.verrou.oublie` (texte simple sous le pavé ; la réinitialisation se fait par l'admin, `BASE-OBJ-09`, ou par un script du serveur via l'export `ResetTablet`, `BASE-OBJ-08` ; le serveur peut adapter ce texte dans `locales/`, par exemple pour nommer sa boutique)
- **Notifications** : aucune.
- **Liens** : `BASE-OBJ-07`, `BASE-OBJ-08`.
- **Réglages** : aucun en plus de ceux de `BASE-OBJ-04` et `BASE-OBJ-07`.
- **Journal admin** : oui pour chaque échec (numéro de série, joueur, essai n°) ; non pour les réussites.
- **Performance** : une vérification bcrypt (≈ 50 ms) par essai, limitée à 1 par seconde.
- **Cas limites** :
  - Un voleur tente des codes, se déconnecte et revient : le compteur reste sur le numéro de série, pas de remise à zéro.
  - L'admin supprime le code pendant que l'écran de verrouillage est affiché : le prochain essai renvoie `ok` quel que soit le code tapé et ouvre le bureau.
  - Demande `base.pin.unlock` envoyée 10 fois en 1 s par un tricheur : 1 seule traitée, les autres `trop_vite` sans compter d'échec.
- **Critères d'acceptation** :
  - Étant donné une tablette avec le code `4821`, quand le joueur tape `4821`, alors le bureau s'affiche.
  - Étant donné un mauvais code, quand il valide, alors il voit « Code incorrect. Encore 4 essai(s). ».
  - Étant donné une session non déverrouillée, quand un client modifié appelle une action d'app, alors le serveur refuse avec `session`.

### [BASE-OBJ-06] Changer ou retirer le code
- **But** : modifier ou supprimer le code de verrouillage.
- **Qui** : le joueur qui tient la tablette déverrouillée et connaît le code actuel.
- **Où** : Réglages > Sécurité > « Changer le code » / « Retirer le code ».
- **Parcours** :
  1. « Changer le code » : la NUI demande « Code actuel », puis « Nouveau code », puis « Confirmer le code ». Action `base.pin.change` avec `{ old, new }`.
  2. « Retirer le code » : la NUI demande « Code actuel » puis une confirmation « Retirer le code ? Tout le monde pourra ouvrir cette tablette. » avec « Retirer » / « Annuler ». Action `base.pin.remove` avec `{ old }`.
  3. Le serveur vérifie l'ancien code avec `VerifyPasswordHash` ; un échec compte comme un essai raté (`BASE-OBJ-07`).
  4. Changement : nouveau hachage écrit immédiatement. Retrait : `pin_hash = NULL`.
  5. Bandeau succès 2 s, retour à Réglages > Sécurité.
- **Données** : identiques à `BASE-OBJ-04`.
- **Règles serveur** : mêmes règles de format que `BASE-OBJ-04` ; anti-spam 3 par 30 s ; l'ancien code est obligatoire même si la tablette est déverrouillée.
- **Textes et états** :
  - « Changer le code » `base.securite.changer` · « Retirer le code » `base.securite.retirer` · « Code actuel » `base.securite.actuel` · « Nouveau code » `base.securite.nouveau`
  - « Retirer le code ? Tout le monde pourra ouvrir cette tablette. » `base.securite.retirer_confirm`
  - Succès : « Code modifié. » `base.securite.modifie` · « Code retiré. » `base.securite.retire`
  - Erreur : « Code actuel incorrect. Encore %d essai(s). » `base.securite.actuel_faux`
- **Notifications** : aucune.
- **Liens** : `BASE-OBJ-07`.
- **Réglages** : aucun.
- **Journal admin** : oui, « code modifié » / « code retiré » (numéro de série, joueur).
- **Performance** : une écriture en base par action.
- **Cas limites** :
  - 5e mauvais « code actuel » : blocage 5 min, la tablette se ferme sur l'écran de blocage.
  - Nouveau code identique à l'ancien : accepté, sans message particulier.
  - Double clic sur « Retirer » : second `actionId` identique refusé `doublon`.
- **Critères d'acceptation** :
  - Étant donné le code `4821`, quand le joueur le change en `9073`, alors seul `9073` déverrouille ensuite.
  - Étant donné le code retiré, quand la tablette est rouverte, alors le bureau s'affiche directement.
  - Étant donné un client modifié qui appelle `base.pin.remove` sans ancien code, quand le serveur reçoit, alors il refuse avec `invalide` et le code reste.

### [BASE-OBJ-07] Blocage après 5 erreurs de code
- **But** : empêcher de deviner le code en essayant toutes les combinaisons.
- **Qui** : s'applique à toute tablette avec code ; réglable par le serveur.
- **Où** : écran de verrouillage et écrans de Réglages > Sécurité qui demandent le code actuel.
- **Parcours** :
  1. Au 5e échec consécutif, le serveur écrit `locked_until = os.time() + 300` et `pin_fails = 0`, immédiatement en base.
  2. Le serveur renvoie `{ ok = false, err = 'bloque', until = locked_until }`.
  3. La NUI remplace le pavé par « Tablette bloquée » et un décompte `mm:ss` mis à jour chaque seconde (minuterie JavaScript, uniquement tablette ouverte).
  4. Pendant le blocage, toute tentative `base.pin.unlock` est refusée par le serveur sans compter d'échec.
  5. À la fin du décompte, la NUI réaffiche le pavé ; le serveur accepte de nouveau les essais.
  6. Si la tablette est fermée puis rouverte pendant le blocage, l'écran de blocage s'affiche avec le temps restant calculé par le serveur.
- **Données** : `pin_fails`, `locked_until` (`pop_tablet_devices`).
- **Règles serveur** : le temps restant vient toujours du serveur ; le blocage concerne le numéro de série ; la réinitialisation (`BASE-OBJ-08`, `BASE-OBJ-09`) lève le blocage.
- **Textes et états** :
  - « Tablette bloquée » `base.verrou.bloque_titre`
  - « Trop d'essais. Réessayez dans %s. » `base.verrou.bloque` (%s = `mm:ss`)
- **Notifications** : aucune.
- **Liens** : `BASE-OBJ-05`, `BASE-OBJ-06`, `BASE-OBJ-08`.
- **Réglages** : `Config.Lock.MaxFails = 5` · `Config.Lock.LockSeconds = 300`.
- **Journal admin** : oui, « tablette bloquée » (numéro de série, joueur, date de fin).
- **Performance** : aucune minuterie serveur ; le serveur compare simplement `locked_until` à `os.time()` lors d'un essai.
- **Cas limites** :
  - Redémarrage du serveur pendant un blocage : le blocage continue (valeur en base).
  - Le joueur change l'heure de son PC : sans effet, le temps vient du serveur.
  - Blocage pendant la saisie de « Code actuel » dans Réglages : la NUI ferme Réglages et affiche l'écran de blocage.
- **Critères d'acceptation** :
  - Étant donné 4 échecs, quand le joueur se trompe une 5e fois, alors il voit « Trop d'essais. Réessayez dans 05:00. ».
  - Étant donné une tablette bloquée, quand le joueur tape le bon code, alors il est refusé jusqu'à la fin du décompte.
  - Étant donné un tricheur qui envoie le bon code via un client modifié pendant le blocage, quand le serveur reçoit, alors il refuse.

### [BASE-OBJ-08] Réinitialiser ou remplacer une tablette depuis un autre script (exports)
- **But** : laisser le script de boutique du serveur (ou un réparateur, un script de job) réinitialiser une tablette ou remplacer une tablette perdue, sans aucune boutique dans la tablette. **La tablette ne vend rien et ne gère aucun prix** : la vente de l'objet `pop_tablet` et du chargeur `pop_tablet_charger`, leur prix et le paiement d'un service (réinitialisation, remplacement) sont gérés par le script de boutique du serveur.
- **Qui** : n'importe quelle ressource serveur (exports serveur uniquement ; aucun événement réseau ne permet de les déclencher depuis un client). L'admin dispose des mêmes effets par `BASE-OBJ-09` / `ADM-04`.
- **Où** : exports serveur `exports.pop_tablet:ResetTablet(serial, opts)`, `exports.pop_tablet:ReplaceTablet(source, oldSerial, opts)` et `exports.pop_tablet:TransferTabletData(oldSerial, newSerial, opts)`, documentés dans `docs/api.md` avec un exemple pour une boutique (débiter, appeler l'export, rembourser si `ok == false`).
- **Parcours** :
  1. **`ResetTablet(serial, opts)`** → `ok, err`. `opts` (facultatif) = `{ by = 'nom lisible de l'auteur (ex. « Boutique Digital Den »)', source = id du joueur concerné ou nil }`. Le serveur vérifie le format `PT-XXXX-XXXX` et l'existence du numéro. Si la tablette est ouverte ou posée, sa session est fermée (objet posé retiré du monde, `BASE-OBJ-12`) avec la notification « Tablette réinitialisée. » `base.reset.notif`. Puis il efface : `pin_hash = NULL`, `pin_fails = 0`, `locked_until = 0`, `settings = '{}'`, `first_boot_done = 0`, `reset_at = os.time()` ; supprime les notifications du numéro de série ; supprime les données d'apps de portée `device` pour ce numéro (`BASE-API-06`) et les données des Outils de ce numéro (fichier 06, mêmes règles que `ADM-04` : une photo utilisée comme preuve est détachée et gardée) ; vide le cache de l'appareil. Le numéro de série est conservé. Signal `pop_tablet:tabletReset (serial, by, source)`.
  2. **`TransferTabletData(oldSerial, newSerial, opts)`** → `ok, err`. Déplace **toutes** les données perso de `oldSerial` vers `newSerial` (portée tablette, `BASE-OBJ-14` : code, réglages, notifications, notes, photos et albums, favoris, historique, points de carte) dans une transaction ; `newSerial` doit exister et ne contenir aucune donnée perso (tablette neuve ou réinitialisée), sinon refus `cible_occupee`. Puis `oldSerial` passe « Sans propriétaire » et est désactivé à vie (`locked_until = 4102444800`, colonne `disabled = 1`) : un objet portant encore ce numéro affiche « Cette tablette a été désactivée. » `base.ouvrir.desactivee` et ne s'ouvre plus.
  3. **`ReplaceTablet(source, oldSerial, opts)`** → `ok, newSerial | err`. Pour le joueur connecté `source` : vérifie que `oldSerial` existe, n'est pas désactivé et que le joueur n'a pas cet objet sur lui (sinon refus `sur_soi` : il faut réinitialiser, pas remplacer) ; vérifie la place (`Bridge.CanCarryItem`) ; crée un nouveau numéro, donne l'objet `pop_tablet` avec `metadata = { serial }` (mode sans métadonnées : rattache le nouveau numéro au personnage), puis appelle `TransferTabletData(oldSerial, newSerial)`. Si une étape échoue, l'objet donné est repris et rien n'est transféré. Signal `pop_tablet:tabletReplaced (oldSerial, newSerial, source, by)`.
  4. Codes d'erreur renvoyés (chaînes, pour le script appelant) : `introuvable`, `format`, `desactivee`, `sur_soi`, `inventaire_plein`, `cible_occupee`, `serveur`. Le script appelant affiche ses propres textes ; la tablette n'affiche rien au joueur en dehors de la notification de l'étape 1.
- **Données** : champs remis à zéro listés à l'étape 1 ; colonne `disabled TINYINT(1) NOT NULL DEFAULT 0` de `pop_tablet_devices` (`BASE-MOT-17`).
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| serial / oldSerial / newSerial | chaîne | Oui | `PT-XXXX-XXXX`, existant | — |
| opts.by | chaîne | Non | 1 à 40 caractères, nettoyé | nom de la ressource appelante (`GetInvokingResource()`) |
| opts.source / source | entier | Non (Oui pour `ReplaceTablet`) | joueur connecté | nil |
- **Règles serveur** : exports serveur seulement ; la ressource appelante est notée (`GetInvokingResource()`) ; aucune notion de prix ni d'argent dans ces exports ; données métier (`job`) jamais effacées ni déplacées ; anti-spam 1 appel par seconde et par numéro de série ; tout dans une transaction.
- **Textes et états** :
  - Notification au joueur qui utilisait la tablette : « Tablette réinitialisée. » `base.reset.notif`
  - Objet désactivé : « Cette tablette a été désactivée. » `base.ouvrir.desactivee`
- **Notifications** : seulement celle de l'étape 1, au joueur qui avait la tablette ouverte.
- **Liens** : `BASE-OBJ-09` et `ADM-04` (même effacement, déclenché par l'admin) ; `BASE-OBJ-14` (ce qui est perso) ; `BASE-API` (liste des exports) ; journal admin.
- **Réglages** : aucun (plus de `Config.Shop`).
- **Journal admin** : oui, « tablette réinitialisée » / « données transférées » / « tablette remplacée » (numéro(s) de série, ressource appelante, `opts.by`, joueur, état avant : code oui/non, nombre de notifications, de notes et de photos).
- **Performance** : aucune boucle, aucun PNJ, aucune zone ; une transaction par appel.
- **Cas limites** :
  - Numéro inexistant : `false, 'introuvable'`, rien n'est effacé.
  - Double appel rapide pour le même numéro (double clic dans la boutique) : le second renvoie `false, 'serveur'` sans rien refaire (anti-spam), le script appelant ne doit pas débiter deux fois.
  - Joueur qui réinitialise la tablette d'un autre (volée) : autorisé, c'est le principe RP ; journalisé avec l'ancien propriétaire.
  - `ReplaceTablet` avec l'inventaire plein : `false, 'inventaire_plein'`, ancien numéro intact.
- **Critères d'acceptation** :
  - Étant donné une tablette bloquée, quand un script appelle `ResetTablet('PT-7K3F-92QD')`, alors le code disparaît, le blocage est levé et l'export renvoie `true`.
  - Étant donné un joueur qui a perdu sa tablette `PT-7K3F-92QD`, quand la boutique appelle `ReplaceTablet(source, 'PT-7K3F-92QD')`, alors il reçoit une nouvelle tablette avec ses notes et l'ancien numéro ne s'ouvre plus.
  - Étant donné un client modifié qui cherche à déclencher une réinitialisation, quand il envoie un événement, alors rien ne se passe (aucun événement réseau n'existe pour ces exports).

### [BASE-OBJ-09] Réinitialiser une tablette par l'admin
- **But** : permettre à l'admin d'effacer les données personnelles d'une tablette ou d'en retirer le code.
- **Qui** : admin (ACE `pop.tablet.admin`) ou console serveur.
- **Où** : commande `/tablette_reset <serial|id_joueur> [code]` ; bouton « Réinitialiser » et « Retirer le code » dans l'app Admin > Tablettes (branche Admin, qui appelle les mêmes fonctions serveur).
- **Parcours** :
  1. L'admin tape `/tablette_reset PT-7K3F-92QD` (réinitialisation complète) ou `/tablette_reset PT-7K3F-92QD code` (retire seulement le code et lève le blocage). Avec un id joueur en ligne : toutes les tablettes de ce joueur sont listées dans le chat et l'admin relance la commande avec le numéro voulu.
  2. Le serveur vérifie l'ACE, l'existence du numéro de série.
  3. Si la tablette est ouverte par quelqu'un : sa session est fermée avec la notification « La tablette a été réinitialisée par un administrateur. ».
  4. Effacement identique à `BASE-OBJ-08` étape 1 (complet) ou `pin_hash = NULL`, `pin_fails = 0`, `locked_until = 0` (code).
  5. Réponse dans le chat (ou console) : « Tablette %s réinitialisée. » / « Code de la tablette %s retiré. ».
- **Données** : identiques à `BASE-OBJ-08`.
- **Règles serveur** : ACE vérifiée côté serveur ; format du numéro vérifié ; anti-spam 1 commande par seconde.
- **Textes et états** :
  - « Tablette %s réinitialisée. » `base.admin.reset_ok` · « Code de la tablette %s retiré. » `base.admin.code_ok`
  - « Aucune tablette avec ce numéro. » `base.admin.introuvable`
  - « Utilisation : /tablette_reset <numéro|id> [code] » `base.admin.usage`
  - Pas le droit : « Vous n'avez pas les droits nécessaires. » `commun.erreur.pas_droit`
- **Notifications** : au joueur qui utilisait la tablette : « La tablette a été réinitialisée par un administrateur. » `base.admin.reset_notif` (via `Bridge.Notify`).
- **Liens** : app Admin (branche Admin).
- **Réglages** : `Config.Admin.ResetCommand = 'tablette_reset'`.
- **Journal admin** : oui, « réinitialisation admin » (admin, numéro de série, type complet/code, état avant), envoyé sur Discord.
- **Performance** : aucune.
- **Cas limites** :
  - Numéro inexistant : message `base.admin.introuvable`.
  - Joueur non admin qui tape la commande : `pas_droit`, journalisé comme tentative.
  - Tablette ouverte en mode posée : l'objet posé est retiré du monde (`BASE-OBJ-12`) avant l'effacement.
- **Critères d'acceptation** :
  - Étant donné une tablette bloquée, quand l'admin tape `/tablette_reset PT-7K3F-92QD code`, alors elle s'ouvre sans code.
  - Étant donné un joueur sans ACE, quand il tape la commande, alors rien n'est effacé et une ligne « tentative refusée » apparaît au journal.
  - Étant donné la console serveur, quand elle tape la commande, alors elle fonctionne sans ACE.

### [BASE-OBJ-10] Poser la tablette (mode posée)
- **But** : poser la tablette devant soi pour montrer l'écran à d'autres joueurs.
- **Qui** : le joueur qui tient sa tablette déverrouillée ; désactivable par le serveur.
- **Où** : tablette ouverte > bouton « Poser » (icône en bas à droite du cadre) ; pas de touche dédiée.
- **Parcours** :
  1. Le joueur touche « Poser ». La NUI envoie l'action `base.place` avec l'écran courant `{ app, screen, params }`.
  2. Le serveur vérifie : app de l'écran déclarée `sharable = true` (sinon refus « Cet écran ne peut pas être montré. »), joueur à pied, pas dans l'eau, pas déjà une tablette posée par ce joueur, nombre de tablettes posées sur le serveur < `Config.Placed.MaxServer`.
  3. Le client arrête l'animation en main, joue `pickup_object` / `putdown_low` (1 s), crée le prop `prop_cs_tablet` en réseau posé au sol à 0,6 m devant le joueur (`PlaceObjectOnGroundProperly`), écran vers le haut, et renvoie son identifiant réseau au serveur.
  4. La NUI de l'utilisateur se ferme (focus rendu), la session reste ouverte en mode `placed` (la batterie continue de se vider). Le serveur garde : propriétaire, identifiant réseau, coordonnées, écran montré.
  5. Le serveur envoie `pop_tablet:client:placedAdd` aux joueurs à moins de 30 m (et à chaque joueur qui arrive plus tard via la vérification de `BASE-OBJ-11`). Ces clients ajoutent une interaction target « Regarder la tablette » / « Prendre la tablette » sur l'objet, ou un prompt natif à 1,5 m.
  6. Le propriétaire voit aussi l'interaction « Reprendre la tablette » (`BASE-OBJ-12`) ; il peut aussi « Regarder » pour réutiliser la tablette sans la reprendre (sans code).
- **Données** (mémoire serveur `Placed[serial]`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| owner | source joueur | Oui | — | — |
| netId | entier | Oui | — | — |
| coords | vec3 | Oui | à 2 m max du joueur | — |
| screen | `{ app, screen, params }` | Oui | params ≤ 2 Ko | écran courant |
| placedAt | horodatage | Oui | — | `os.time()` |
- **Règles serveur** : l'écran montré est vérifié (le propriétaire y a accès) ; coordonnées du prop vérifiées à moins de 2 m du propriétaire ; 1 tablette posée par joueur ; un minuteur serveur de 5 s (actif seulement tant qu'au moins une tablette est posée) retire l'objet si le propriétaire est à plus de 25 m, déconnecté, mort, ou n'a plus l'objet.
- **Textes et états** :
  - « Poser » `base.poser.bouton`
  - « Cet écran ne peut pas être montré. » `base.poser.non_partageable`
  - « Impossible de poser la tablette ici. » `base.poser.impossible`
  - « Tablette rangée. » `base.poser.rangee` (retrait automatique)
- **Notifications** : au propriétaire lors d'un retrait automatique : « Tablette rangée. ».
- **Liens** : `BASE-OBJ-11`, `BASE-OBJ-12`, `BASE-API-02` (champ `sharable`).
- **Réglages** : `Config.Placed.Enabled = true` · `Config.Placed.MaxServer = 30` · `Config.Placed.MaxOwnerDistance = 25.0` · `Config.Placed.ViewDistance = 2.0`.
- **Journal admin** : non.
- **Performance** : minuteur serveur de 5 s seulement si `Placed` n'est pas vide ; arrêté quand la dernière tablette est reprise. Côté client des spectateurs, aucune boucle avec target ; sans target, vérification de distance toutes les 500 ms seulement pour les joueurs à moins de 30 m d'une tablette posée, arrêtée quand elle disparaît.
- **Cas limites** :
  - Propriétaire déconnecté : objet supprimé par le serveur, session fermée, l'objet d'inventaire reste chez lui (il n'a jamais quitté l'inventaire).
  - Le propriétaire donne ou jette l'objet pendant qu'il est posé : au prochain passage du minuteur, l'objet posé disparaît.
  - Écran non partageable (ex. Réglages > Sécurité) : refus, la tablette reste en main.
- **Critères d'acceptation** :
  - Étant donné une tablette ouverte sur un écran partageable, quand le joueur touche « Poser », alors l'objet apparaît au sol devant lui et l'écran du joueur se ferme.
  - Étant donné une tablette posée, quand le propriétaire s'éloigne à 30 m, alors l'objet disparaît en 5 s maximum et il reçoit « Tablette rangée. ».
  - Étant donné un client modifié qui envoie des coordonnées à 200 m, quand le serveur reçoit, alors il refuse et supprime l'objet.

### [BASE-OBJ-11] Regarder une tablette posée
- **But** : un autre joueur voit l'écran montré par le propriétaire, sans pouvoir rien modifier.
- **Qui** : tout joueur à 2 m maximum d'une tablette posée.
- **Où** : objet posé > target « Regarder la tablette » (ou prompt natif « ~INPUT_CONTEXT~ Regarder la tablette »).
- **Parcours** :
  1. Le spectateur interagit. Le client envoie `pop_tablet:viewPlaced` avec le numéro de série.
  2. Le serveur vérifie la distance (≤ 2 m de `coords`), que la tablette est toujours posée, 1 demande par 2 s.
  3. Le serveur appelle le fournisseur de données de l'app pour l'écran montré, **avec l'identité et les droits du propriétaire**, en mode lecture seule (`ctx.readOnly = true`), puis envoie au spectateur une session spectateur (jeton à part, lecture seule).
  4. La NUI du spectateur s'ouvre avec le cadre de la tablette, le bandeau « Tablette de %s · lecture seule » en haut, l'écran montré ; tous les boutons d'action sont désactivés (la NUI ajoute `inert` à la zone d'actions et le serveur refuse toute action d'écriture avec ce jeton).
  5. Échap ferme la vue. Si la tablette est reprise ou rangée, la vue se ferme avec « La tablette a été reprise. ».
  6. Pas d'animation en main pour le spectateur (il se penche : animation `amb@world_human_bum_wash@male@low@idle_a` désactivée par défaut, `Config.Placed.ViewAnim = false`).
- **Données** : session spectateur en mémoire `{ token, viewer, serial, readOnly = true }`.
- **Règles serveur** : lecture seule garantie côté serveur (toute action marquée `write` par l'app est refusée `pas_droit`) ; distance revérifiée toutes les 5 s par le minuteur des tablettes posées ; au plus 6 spectateurs par tablette ; les données montrées sont celles de l'écran posé, pas d'autre écran (la navigation est bloquée).
- **Textes et états** :
  - « Regarder la tablette » `base.poser.regarder` · « Tablette de %s · lecture seule » `base.poser.bandeau` (%s = prénom RP du propriétaire)
  - « La tablette a été reprise. » `base.poser.reprise`
  - « Trop de monde regarde déjà cette tablette. » `base.poser.complet`
- **Notifications** : aucune.
- **Liens** : `BASE-OBJ-10`, `BASE-API-02`, `BASE-API-03`.
- **Réglages** : `Config.Placed.MaxViewers = 6` · `Config.Placed.ViewAnim = false`.
- **Journal admin** : non.
- **Performance** : données chargées une fois à l'ouverture de la vue ; pas de rafraîchissement automatique.
- **Cas limites** :
  - Le spectateur s'éloigne à 5 m : vue fermée au passage suivant du minuteur (5 s max).
  - Le propriétaire perd l'accès à l'app (changement de métier) : la vue se ferme et l'objet est rangé.
  - Spectateur qui essaie de payer une facture affichée via un client modifié : refus `pas_droit`.
- **Critères d'acceptation** :
  - Étant donné une tablette posée sur un devis, quand un autre joueur regarde, alors il voit le devis avec le bandeau « lecture seule » et aucun bouton actif.
  - Étant donné 6 spectateurs, quand un 7e essaie, alors il voit « Trop de monde regarde déjà cette tablette. ».
  - Étant donné un spectateur avec un client modifié, quand il envoie une action d'écriture, alors le serveur refuse.

### [BASE-OBJ-12] Reprendre ou prendre une tablette posée
- **But** : le propriétaire reprend sa tablette ; un autre joueur peut la prendre (vol RP).
- **Qui** : propriétaire ; autre joueur si `Config.Placed.AllowTake = true`.
- **Où** : objet posé > « Reprendre la tablette » (propriétaire) / « Prendre la tablette » (autre joueur).
- **Parcours** :
  1. Le joueur interagit ; le client joue `pickup_object` / `pickup_low` (1 s) et envoie `pop_tablet:takePlaced`.
  2. Le serveur vérifie distance ≤ 2 m, tablette toujours posée, 1 demande par 2 s.
  3. Propriétaire : objet supprimé, spectateurs fermés, session repasse en main et la NUI se rouvre sur l'écran montré (pas de code demandé).
  4. Autre joueur : objet supprimé, spectateurs fermés, session du propriétaire fermée ; l'objet d'inventaire est transféré : `Bridge.RemoveItem(owner, 'pop_tablet', 1, { serial })` puis `Bridge.AddItem(taker, 'pop_tablet', 1, { serial, description })`. Si l'ajout échoue (inventaire plein), l'objet est rendu au propriétaire et le preneur voit « Inventaire plein. ».
  5. Le propriétaire reçoit « Votre tablette a été prise. ».
- **Données** : aucune nouvelle donnée ; `owner_identifier` de l'appareil n'est pas modifié avant la première ouverture par le nouveau détenteur.
- **Règles serveur** : transfert fait uniquement par le serveur ; inventaire sans métadonnées : le transfert donne un objet `pop_tablet` sans données au preneur (qui ouvrira sa propre tablette de personnage, `BASE-OBJ-15`) et retire l'objet au propriétaire.
- **Textes et états** :
  - « Reprendre la tablette » `base.poser.reprendre` · « Prendre la tablette » `base.poser.prendre`
  - « Inventaire plein. » `base.poser.plein`
  - « Votre tablette a été prise. » `base.poser.volee`
- **Notifications** : propriétaire en cas de prise par un autre (via `Bridge.Notify`).
- **Liens** : `BASE-OBJ-10`, `BASE-OBJ-14`.
- **Réglages** : `Config.Placed.AllowTake = true`.
- **Journal admin** : oui pour une prise par un autre (preneur, propriétaire, numéro de série, position).
- **Performance** : le minuteur des tablettes posées s'arrête si c'était la dernière.
- **Cas limites** :
  - Deux joueurs prennent en même temps : la première demande traitée gagne, la seconde reçoit « La tablette a été reprise. ».
  - Le propriétaire n'a plus l'objet au moment de la prise : objet du monde supprimé, rien n'est donné.
  - `AllowTake = false` : seule l'interaction « Regarder » est proposée aux autres.
- **Critères d'acceptation** :
  - Étant donné une tablette posée, quand le propriétaire la reprend, alors la NUI se rouvre sur le même écran sans code.
  - Étant donné ox_inventory et `AllowTake = true`, quand un autre joueur la prend, alors l'objet avec le même numéro de série passe dans son inventaire.
  - Étant donné un tricheur à 40 m qui envoie `takePlaced`, quand le serveur reçoit, alors il refuse et rien ne bouge.

### [BASE-OBJ-13] Raccourci clavier réglable
- **But** : ouvrir et fermer la tablette avec une touche que chaque joueur peut changer.
- **Qui** : tout joueur qui a l'objet ; touche par défaut réglable par le serveur, touche personnelle réglable par chaque joueur.
- **Où** : touche par défaut `F9` ; modifiable dans GTA > Paramètres > Raccourcis > FiveM > « Ouvrir / fermer la tablette ».
- **Parcours** :
  1. Au démarrage du client : `RegisterCommand('+poptablet')` et `RegisterKeyMapping('+poptablet', L('base.raccourci.libelle'), 'keyboard', Config.Keybind.Default)`.
  2. Appui sur la touche : si tablette fermée, le client demande l'ouverture au serveur (même parcours que `BASE-OBJ-01` étapes 2 à 6, le serveur cherche l'objet dans l'inventaire ; si plusieurs tablettes, celle du premier emplacement) ; si ouverte, fermeture.
  3. Si un champ de texte de la NUI a le focus, la touche est ignorée par la NUI (pas de fermeture en tapant).
  4. Si `Config.Keybind.Default = ''`, aucune touche par défaut, le joueur choisit la sienne.
- **Données** : aucune côté tablette (GTA garde la touche du joueur).
- **Règles serveur** : identiques à `BASE-OBJ-01`.
- **Textes et états** : « Ouvrir / fermer la tablette » `base.raccourci.libelle`.
- **Notifications** : aucune.
- **Liens** : `BASE-OBJ-01`.
- **Réglages** : `Config.Keybind.Enabled = true` · `Config.Keybind.Default = 'F9'`.
- **Journal admin** : non.
- **Performance** : aucune boucle (le key mapping de FiveM déclenche la commande).
- **Cas limites** :
  - Joueur sans objet : « Aucune tablette. ».
  - Appuis répétés rapides : cooldown de 2 s côté serveur ; côté client, la touche est ignorée pendant l'animation d'ouverture (300 ms).
  - Touche déjà utilisée par un autre script : le joueur la change dans les paramètres GTA ; aucune action de la tablette.
- **Critères d'acceptation** :
  - Étant donné un joueur avec l'objet, quand il appuie sur F9, alors la tablette s'ouvre ; quand il rappuie, elle se ferme.
  - Étant donné un champ texte actif, quand il appuie sur F9, alors la tablette ne se ferme pas.
  - Étant donné un joueur sans l'objet qui exécute `+poptablet` dans la console F8, quand le serveur reçoit, alors il refuse.

### [BASE-OBJ-14] Séparer données perso (objet) et données métier (joueur)
- **But** : les données personnelles suivent la tablette, les données de travail suivent le joueur et son métier.
- **Qui** : règle système appliquée à toutes les apps ; non réglable.
- **Où** : moteur ; visible quand une tablette change de main.
- **Parcours** :
  1. **Données perso** (portée `device`, clé = numéro de série) : code, réglages (fond, accent, luminosité, taille du texte, langue, sons), ordre des icônes, historique des notifications, batterie, données d'apps perso rangées en portée `device`, et **toutes les données des Outils (fichier 06) : notes, photos et albums de la Galerie, favoris et historique du Navigateur, points de la Carte, historique de la Calculatrice**. Règle unique pour les 6 fichiers : ces données suivent l'objet. Perdre la tablette = les perdre, sauf remplacement par l'export `ReplaceTablet` / `TransferTabletData` (`BASE-OBJ-08`, appelé par la boutique du serveur ou un admin) qui les transfère vers le nouveau numéro ; la réinitialisation les efface. Exceptions qui ne sont pas des données perso : appartenance et messages de gang (au personnage, `MET-GANG`), données d'entreprise (à l'entreprise).
  2. **Données métier** (portée `job` = nom du métier du framework, et portée `player` = identifiant du personnage) : MDT, dossiers, factures, entreprises, planning, stocks. Elles sont lues avec le métier **actuel** du joueur au moment de la demande.
  3. À chaque ouverture, la liste des apps est recalculée avec le métier actuel : un voleur qui ouvre la tablette d'un policier ne voit pas le MDT ; un policier qui ouvre la tablette d'un civil voit le MDT.
  4. Les notifications métier (portée joueur/métier) sont envoyées au joueur concerné, et affichées sur la tablette qu'il tient ; l'historique stocké est celui de la tablette (portée `device`).
- **Données** : colonne `scope_type` (`device` | `player` | `job` | `global`) et `scope_id` de `pop_tablet_appdata` (`BASE-API-06`).
- **Règles serveur** : toute lecture de données métier recalcule le métier avec `Bridge.GetJob(source)` (cache invalidé à chaque changement de métier) ; aucune donnée métier n'est stockée en portée `device`.
- **Textes et états** : aucun texte propre.
- **Notifications** : aucune.
- **Liens** : toutes les apps ; `BASE-API-06`.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : la portée est une simple colonne indexée.
- **Cas limites** :
  - Changement de métier tablette ouverte : le serveur envoie `pop_tablet:client:apps` avec la nouvelle liste ; si l'app ouverte n'est plus autorisée, la NUI revient au bureau avec « Accès à cette app retiré. » `base.bureau.plus_acces`.
  - Tablette prise à un policier par un civil : le civil voit le fond et les réglages du policier (perso), pas le MDT.
  - Joueur multi-personnages : portée `player` = identifiant du personnage (ESX : `xPlayer.identifier` incluant le préfixe `char1:` ; QBCore / Qbox : `citizenid`, un par personnage), donc séparée par personnage.
- **Critères d'acceptation** :
  - Étant donné une tablette de policier prise par un civil, quand le civil l'ouvre, alors l'icône MDT n'apparaît pas.
  - Étant donné un policier qui ouvre une tablette neuve, quand il l'ouvre, alors il voit le MDT avec ses dossiers.
  - Étant donné un civil qui appelle une action du MDT via un client modifié, quand le serveur reçoit, alors il refuse avec `pas_droit`.

### [BASE-OBJ-15] Mode sans métadonnées : une tablette par personnage
- **But** : faire fonctionner la tablette avec un inventaire qui ne gère pas les métadonnées (inventaire ESX de base).
- **Qui** : automatique selon l'inventaire détecté.
- **Où** : moteur (détection au démarrage).
- **Parcours** :
  1. Au démarrage, `Bridge.InventoryHasMetadata()` renvoie `true` pour ox_inventory, qs-inventory, qb-inventory ; `false` pour l'inventaire ESX par défaut. Forçable par `Config.Item.Metadata = 'auto' | true | false`.
  2. Mode personnage : à l'utilisation, le serveur cherche la ligne `pop_tablet_devices` avec `mode = 'character'` et `owner_identifier = identifiant`. Si absente, il la crée avec un nouveau numéro de série.
  3. Avoir au moins 1 objet `pop_tablet` = avoir sa tablette. Donner l'objet ne transfère pas les données : le receveur ouvre sa propre tablette de personnage.
  4. La réinitialisation (`BASE-OBJ-08`) agit sur la tablette du personnage.
- **Données** : `mode = 'character'` dans `pop_tablet_devices` ; index unique `(mode, owner_identifier)` limité au mode personnage par la logique serveur.
- **Règles serveur** : une seule ligne `character` par identifiant ; l'objet reste empilable (le nombre n'a pas d'importance).
- **Textes et états** : aucun texte propre. Réglages > À propos affiche « Tablette personnelle » `base.reglages.apropos.perso` sous le numéro.
- **Notifications** : aucune.
- **Liens** : `BASE-OBJ-03`, `BASE-OBJ-12`.
- **Réglages** : `Config.Item.Metadata = 'auto'`.
- **Journal admin** : non.
- **Performance** : identique au mode objet.
- **Cas limites** :
  - Le serveur passe d'un inventaire sans métadonnées à ox_inventory : les tablettes neuves passent en mode `item` ; à la première utilisation d'un objet sans métadonnée par un joueur qui a déjà une ligne `character`, le serveur réutilise ce numéro et l'écrit sur l'objet (migration douce), puis passe la ligne en `item`.
  - Joueur avec 3 objets : une seule tablette.
  - Objet volé : le voleur ouvre sa propre tablette ; la victime n'a plus d'objet et ne peut plus ouvrir.
- **Critères d'acceptation** :
  - Étant donné l'inventaire ESX par défaut, quand deux personnages du même compte ouvrent la tablette, alors ils ont deux numéros de série différents.
  - Étant donné un joueur qui donne son objet, quand le receveur l'ouvre, alors il ne voit pas les réglages du donneur.
  - Étant donné un client qui demande à ouvrir la tablette d'un autre identifiant, quand le serveur reçoit, alors il ignore la demande et ouvre celle du joueur.

### [BASE-OBJ-16] Fermeture forcée et conditions d'usage (ajout)
- **But** : empêcher d'utiliser la tablette dans des situations impossibles (mort, menotté, nage, conduite rapide).
- **Qui** : tous ; réglable par le serveur.
- **Où** : automatique tablette ouverte.
- **Parcours** :
  1. À l'ouverture, le client refuse si : mort (`IsEntityDead` ou `Bridge.IsDead`), menotté (`IsPedCuffed` ou état `Bridge.IsHandcuffed`), en ragdoll, en train de nager, en chute, conducteur d'un véhicule à plus de 10 km/h.
  2. Tablette ouverte : une vérification légère toutes les 500 ms (uniquement tablette ouverte) teste les mêmes conditions. Si l'une devient vraie : fermeture immédiate avec le message.
  3. Événements aussi écoutés pour réagir sans attendre : les événements client de mort du bridge pour le framework détecté (ESX `esx:onPlayerDeath` ; QBCore / Qbox passage de `metadata.isdead` ou `inlaststand` à `true` dans `QBCore:Player:SetPlayerData`, BASE-MOT-02), et `baseevents:onPlayerDied` si présent.
  4. Le serveur ferme aussi la session à la mort (`Bridge.OnPlayerDeath`).
- **Données** : aucune.
- **Règles serveur** : session fermée côté serveur à la mort ; toute demande d'un joueur mort est refusée.
- **Textes et états** : « Impossible d'utiliser la tablette maintenant. » `base.ouvrir.impossible`.
- **Notifications** : aucune autre.
- **Liens** : `BASE-OBJ-01`, `BASE-OBJ-02`, `BASE-MOT-13`.
- **Réglages** : `Config.Use.AllowDriver = true` · `Config.Use.DriverMaxSpeed = 10` (km/h) · `Config.Use.AllowSwimming = false` · `Config.Use.CheckInterval = 500` (ms).
- **Journal admin** : non.
- **Performance** : la vérification de 500 ms n'existe que tablette ouverte, arrêtée à la fermeture.
- **Cas limites** :
  - Joueur réanimé : il peut rouvrir normalement.
  - Conducteur qui accélère au-delà de 10 km/h : fermeture en 500 ms max.
  - Script de menottes non standard : si `IsPedCuffed` ne détecte rien, `Bridge.IsHandcuffed` lit l'état `isHandcuffed` (state bag) s'il existe, sinon aucune restriction.
- **Critères d'acceptation** :
  - Étant donné une tablette ouverte, quand le joueur meurt, alors elle se ferme immédiatement.
  - Étant donné un conducteur à 50 km/h, quand il appuie sur F9, alors il voit « Impossible d'utiliser la tablette maintenant. ».
  - Étant donné un joueur mort qui envoie une demande via un client modifié, quand le serveur reçoit, alors il refuse.

### [BASE-OBJ-17] Écran « Bienvenue » au premier démarrage d'une tablette (ajout)
- **But** : guider le joueur à la première ouverture d'une tablette neuve ou réinitialisée.
- **Qui** : tout joueur qui ouvre une tablette avec `first_boot_done = 0`.
- **Où** : remplace le bureau à la première ouverture.
- **Parcours** :
  1. Étape 1 « Langue » : liste des langues disponibles, celle du serveur présélectionnée.
  2. Étape 2 « Code » : « Créer un code » (`BASE-OBJ-04`) ou « Plus tard ».
  3. Étape 3 « Couleur » : 8 pastilles d'accent (`BASE-ECR-12`), celle du serveur présélectionnée.
  4. « Terminer » : action `base.firstboot.done` avec les choix ; le serveur enregistre les réglages et `first_boot_done = 1` (écriture groupée), la NUI affiche le bureau.
  5. Fermer la tablette au milieu : l'écran revient à la prochaine ouverture.
- **Données** : `first_boot_done`, `settings.locale`, `settings.accent`.
- **Règles serveur** : langue doit exister dans les langues chargées ; couleur validée comme en `BASE-ECR-12`.
- **Textes et états** : « Bienvenue » `base.bienvenue.titre` · « Langue » `base.bienvenue.langue` · « Protéger la tablette » `base.bienvenue.code` · « Plus tard » `base.bienvenue.plus_tard` · « Couleur » `base.bienvenue.couleur` · « Terminer » `base.bienvenue.terminer` · « Suivant » `base.commun.suivant` · « Retour » `base.commun.retour`.
- **Notifications** : aucune.
- **Liens** : `BASE-OBJ-04`, `BASE-ECR-12`, `BASE-ECR-15`.
- **Réglages** : `Config.FirstBoot.Enabled = true`.
- **Journal admin** : non.
- **Performance** : écran statique, aucune donnée chargée.
- **Cas limites** :
  - Langue envoyée inexistante : remplacée par `Config.Locale`.
  - Tablette réinitialisée : l'écran revient.
  - `FirstBoot.Enabled = false` : `first_boot_done` est mis à 1 à la création.
- **Critères d'acceptation** :
  - Étant donné une tablette neuve, quand le joueur l'ouvre, alors il voit « Bienvenue ».
  - Étant donné l'écran terminé, quand il rouvre la tablette, alors il arrive sur le bureau.
  - Étant donné un client qui envoie une couleur `red;}` , quand le serveur reçoit, alors il garde la couleur par défaut.

### [BASE-OBJ-18] Acheter une tablette (supprimée : géré par la boutique du serveur)
- La tablette ne contient aucune boutique. L'objet `pop_tablet` (« Tablette », 500 g, non empilable, métadonnée `serial`) et l'objet `pop_tablet_charger` (« Chargeur de tablette », 200 g, empilable) sont déclarés dans l'inventaire du serveur (exemples fournis dans `docs/items/` pour ox_inventory, qs-inventory, qb-inventory, ESX `items`) ; leur prix et leur vente sont gérés par le script de boutique du serveur. Une tablette donnée par une boutique n'a pas encore de numéro de série : il est créé à la première utilisation (`BASE-OBJ-03`).

---

## 2. L'écran

### [BASE-ECR-01] Bureau : afficher les icônes des apps autorisées
- **But** : montrer au joueur uniquement les apps qu'il a le droit d'utiliser.
- **Qui** : tout joueur avec la tablette déverrouillée.
- **Où** : écran d'accueil après déverrouillage ; bouton physique du cadre (rond en bas) pour y revenir depuis n'importe quelle app.
- **Parcours** :
  1. À l'ouverture, le serveur parcourt les apps enregistrées (`BASE-API-02`) et garde celles dont les conditions sont remplies : `enabled`, `jobs` (métier et grade minimum), `ace`, `item` requis, `condition(source)` personnalisée (fonction serveur, 5 ms max).
  2. Le serveur trie selon l'ordre enregistré dans `settings.layout` de l'appareil ; les apps autorisées absentes de l'ordre sont ajoutées à la fin dans l'ordre `order` de leur définition ; les apps de l'ordre qui ne sont plus autorisées sont masquées (gardées dans l'ordre pour revenir à la même place).
  3. La NUI affiche une grille de 6 colonnes × 4 lignes par page (24 icônes), pages suivantes par flèches gauche/droite ou molette, points de page en bas. Icône 72 px, libellé dessous (1 ligne, coupé avec « … » au-delà de 14 caractères), pastille de non-lus en haut à droite de l'icône (nombre, « 9+ » au-delà de 9).
  4. Clic ou Entrée sur l'icône : ouverture de l'app (`BASE-API-03`) en fondu 150 ms. Navigation clavier : flèches pour se déplacer, Entrée pour ouvrir.
  5. L'app Réglages est toujours présente (non masquable).
- **Données** :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| apps (envoyé) | liste `{ id, label, icon, badge }` | Oui | ≤ 96 apps | — |
| settings.layout | liste d'ids d'apps | Non | ≤ 96 ids, id ≤ 32 caractères | ordre des définitions |
- **Règles serveur** : la liste est calculée côté serveur uniquement ; ouvrir une app non listée est refusé (`pas_droit`) ; recalcul à chaque changement de métier (`Bridge.OnJobChange`) et à chaque enregistrement/retrait d'app.
- **Textes et états** :
  - Vide (seulement Réglages) : « Aucune app pour l'instant. Les apps du métier apparaîtront ici. » `base.bureau.vide`
  - Pas le droit : les apps interdites sont cachées (jamais grisées sur le bureau).
  - « Accès à cette app retiré. » `base.bureau.plus_acces`
- **Notifications** : aucune.
- **Liens** : `BASE-API-02`, `BASE-ECR-02`, `BASE-ECR-05` (badges).
- **Réglages** : `Config.Desktop.Columns = 6` · `Config.Desktop.Rows = 4` · `Config.Desktop.HiddenApps = {}` (ids d'apps cachées pour tous).
- **Journal admin** : non.
- **Performance** : liste envoyée une fois à l'ouverture ; les icônes sont des fichiers locaux de la NUI (SVG ou PNG ≤ 20 Ko), chargées en paresseux par page.
- **Cas limites** :
  - Une app est enregistrée par une autre ressource pendant que la tablette est ouverte : la liste est renvoyée, l'icône apparaît à la fin.
  - Une ressource qui fournit une app s'arrête : l'app est retirée (`onResourceStop`) et l'icône disparaît.
  - Plus de 24 apps : pages supplémentaires.
- **Critères d'acceptation** :
  - Étant donné un policier, quand il ouvre la tablette, alors il voit l'icône MDT ; un civil ne la voit pas.
  - Étant donné 30 apps autorisées, quand le joueur ouvre le bureau, alors il y a 2 pages.
  - Étant donné un civil qui envoie `base.app.open` avec `mdt`, quand le serveur reçoit, alors il refuse.

### [BASE-ECR-02] Ranger les icônes du bureau
- **But** : laisser l'utilisateur choisir l'ordre de ses icônes.
- **Qui** : le joueur qui tient la tablette déverrouillée (données perso de l'appareil).
- **Où** : bureau > appui long 600 ms sur une icône (ou bouton « Ranger » en bas du bureau, ou touche R au clavier).
- **Parcours** :
  1. Le bureau passe en mode « Ranger » : les icônes oscillent légèrement (rotation ±1,5°, 300 ms, désactivée si `prefers-reduced-motion`), un bouton « Terminé » apparaît en bas.
  2. Le joueur glisse une icône vers une autre place (y compris sur la page suivante en la tenant 500 ms sur le bord). Au clavier : flèches pour choisir, Espace pour prendre/poser, flèches pour déplacer.
  3. Bouton « Réinitialiser l'ordre » en bas : remet l'ordre par défaut après confirmation « Remettre l'ordre par défaut ? ».
  4. « Terminé » (ou Échap) : la NUI envoie `base.layout.save` avec la liste complète des ids dans le nouvel ordre.
  5. Le serveur garde uniquement les ids d'apps existantes, supprime les doublons, enregistre dans `settings.layout` (écriture groupée) et répond `ok`.
- **Données** : `settings.layout` (voir `BASE-ECR-01`).
- **Règles serveur** : ids inconnus ignorés ; liste ≤ 96 ; 1 sauvegarde par 3 s.
- **Textes et états** : « Ranger » `base.bureau.ranger` · « Terminé » `base.commun.termine` · « Réinitialiser l'ordre » `base.bureau.reinit` · « Remettre l'ordre par défaut ? » `base.bureau.reinit_confirm` · succès silencieux (pas de bandeau).
- **Notifications** : aucune.
- **Liens** : `BASE-ECR-01`, `BASE-MOT-04`.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : une seule demande au clic sur « Terminé ».
- **Cas limites** :
  - Fermeture de la tablette en mode « Ranger » : l'ordre en cours est sauvegardé comme sur « Terminé ».
  - Envoi d'une liste avec un id inventé : ignoré.
  - Échec de sauvegarde : la NUI revient à l'ancien ordre et affiche `commun.erreur.serveur`.
- **Critères d'acceptation** :
  - Étant donné une icône déplacée en 1re position, quand le joueur rouvre la tablette, alors elle est toujours en 1re position.
  - Étant donné « Réinitialiser l'ordre », quand il confirme, alors l'ordre par défaut revient.
  - Étant donné un client qui envoie 5 000 ids, quand le serveur reçoit, alors il refuse avec `invalide`.

### [BASE-ECR-03] Barre du haut
- **But** : afficher en permanence l'heure du jeu, la batterie, le réseau et le statut en service.
- **Qui** : tout joueur, tablette ouverte (aussi sur l'écran de verrouillage, sans le statut).
- **Où** : bande de 28 px en haut de l'écran de la tablette.
- **Parcours** :
  1. À gauche : heure du jeu `HH:MM` (24 h en fr, 12 h `h:MM AM/PM` en en), lue côté client avec `GetClockHours()` / `GetClockMinutes()` et envoyée à la NUI à l'ouverture puis toutes les 2 s de jeu réel (minuterie client active seulement tablette ouverte).
  2. Au centre : nom de l'app ouverte (vide sur le bureau).
  3. À droite, dans cet ordre : pastille de service (« En service » avec point couleur d'accent / « Hors service » avec point gris ; affichée seulement si le métier du joueur est relié à une entreprise), icône réseau (`BASE-ECR-17`), icône cloche avec nombre de non-lus, batterie (icône + pourcentage entier).
  4. Clic sur la cloche ou glisser vers le bas depuis la barre : ouvre le volet historique (`BASE-ECR-05`).
  5. Batterie ≤ 20 % : icône et pourcentage en orange `#F5A524` ; ≤ 10 % : rouge `#E5484D`. En charge : petit éclair à côté.
- **Données** (affichées) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| time | chaîne `HH:MM` | Oui | — | heure du jeu |
| battery | entier | Oui | 0 à 100 | valeur serveur |
| network | entier | Oui | 0 à 4 barres | 4 |
| onDuty | booléen ou nul | Non | nul = pas d'entreprise | nul |
| unread | entier | Oui | ≥ 0 | 0 |
- **Règles serveur** : statut en service et non-lus fournis par le serveur ; la batterie affichée est une estimation client recalée par le serveur à chaque demande.
- **Textes et états** : « En service » `base.barre.en_service` · « Hors service » `base.barre.hors_service` · « En charge » `base.barre.en_charge` (info-bulle).
- **Notifications** : aucune.
- **Liens** : prise de service (branche Entreprises, qui appelle `exports.pop_tablet:SetDuty`, voir `BASE-API-05`), `BASE-ECR-06`, `BASE-ECR-17`.
- **Réglages** : `Config.TopBar.ShowDuty = true` · `Config.TopBar.Clock24h = 'auto'` (selon la langue).
- **Journal admin** : non.
- **Performance** : minuterie de 2 s pour l'heure seulement tablette ouverte ; batterie recalculée localement chaque minute (`BASE-ECR-06`).
- **Cas limites** :
  - Changement de service pendant que la tablette est ouverte : le serveur envoie `pop_tablet:client:duty`, la pastille change sans rechargement.
  - Joueur sans entreprise : pas de pastille.
  - Batterie désactivée par le serveur : l'icône batterie est cachée.
- **Critères d'acceptation** :
  - Étant donné 14:05 dans le jeu, quand la tablette est ouverte, alors la barre affiche « 14:05 ».
  - Étant donné un mécano en service, quand il ouvre la tablette, alors il voit « En service ».
  - Étant donné un client qui modifie la batterie affichée à 100 %, quand le serveur calcule, alors la vraie valeur s'applique au prochain recalage.

### [BASE-ECR-04] Notification en bandeau discret
- **But** : prévenir le joueur d'un événement (facture reçue, appel, alerte) sans le gêner.
- **Qui** : joueurs concernés qui ont l'objet tablette sur eux (ouverte ou fermée).
- **Où** : tablette ouverte : bandeau en haut de l'écran de la tablette ; tablette fermée : bandeau hors tablette en haut à droite de l'écran du jeu (NUI sans focus).
- **Parcours** :
  1. Un module serveur appelle `Notify` (`BASE-API-04`).
  2. Le serveur résout les destinataires, garde ceux qui possèdent l'objet (`Bridge.HasItem`, résultat gardé 30 s en cache par joueur), et pour chacun : ajoute la notification à l'historique de sa tablette (`BASE-ECR-05`) et envoie `pop_tablet:client:notify`.
  3. Le client affiche le bandeau : icône de l'app, titre (gras, 1 ligne), texte (2 lignes max), il y a « maintenant ». Durée 4 s (urgente : 8 s, bord gauche 3 px couleur d'accent). Joue le son si activé (`BASE-ECR-16`).
  4. Au plus 3 bandeaux empilés ; les suivants attendent leur tour.
  5. Tablette ouverte : clic sur le bandeau = ouvre l'écran lié (`link`) ; tablette fermée : le bandeau n'est pas cliquable (pas de focus) et affiche en petit « F9 pour ouvrir » (touche du joueur via `GetControlInstructionalButton`).
  6. Tablette fermée et joueur mort ou en cinématique : le bandeau n'est pas affiché, la notification va seulement dans l'historique.
- **Données** :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| app | chaîne (id d'app) | Oui | ≤ 32 | — |
| title | clé de langue ou texte | Oui | ≤ 60 caractères affichés | — |
| body | clé de langue ou texte | Non | ≤ 160 caractères | '' |
| params | table | Non | ≤ 10 valeurs | {} |
| priority | `normal` \| `urgent` | Non | — | `normal` |
| link | `{ screen, params }` | Non | params ≤ 1 Ko | nil |
- **Règles serveur** : envoi seulement aux joueurs concernés qui ont l'objet ; textes nettoyés (`BASE-MOT-12`) ; au plus 10 notifications par joueur par minute, les suivantes vont seulement dans l'historique sans bandeau.
- **Textes et états** : « maintenant » `base.notif.maintenant` · « %s pour ouvrir » `base.notif.ouvrir`.
- **Notifications** : c'est la fonctionnalité.
- **Liens** : `BASE-API-04`, `BASE-ECR-05`, `BASE-ECR-16`.
- **Réglages** : `Config.Notify.Duration = 4000` · `Config.Notify.UrgentDuration = 8000` · `Config.Notify.MaxStack = 3` · `Config.Notify.ShowWhenClosed = true` · `Config.Notify.Position = 'top-right'` (`top-right` | `top-left` | `bottom-right`) · `Config.Notify.PerMinute = 10`.
- **Journal admin** : non.
- **Performance** : aucun envoi aux joueurs sans l'objet ; la NUI de bandeau hors tablette est la même page, aucune boucle (minuterie JavaScript par bandeau, supprimée à la fin).
- **Cas limites** :
  - Joueur sans tablette : rien n'est envoyé (les documents passent par la fenêtre simple `BASE-MOT-14`).
  - 20 notifications en 1 s : 3 bandeaux, puis file ; au-delà de 10 par minute, historique seulement.
  - Joueur hors ligne : rien n'est envoyé ; si la notification vise un identifiant, elle est stockée dans l'historique de sa tablette (mode personnage) ou dans une boîte d'attente `pending` livrée à la prochaine ouverture (mode objet, voir `BASE-ECR-05`).
- **Critères d'acceptation** :
  - Étant donné une tablette fermée, quand une facture arrive, alors un bandeau apparaît 4 s en haut à droite.
  - Étant donné une notification urgente, quand elle arrive, alors elle reste 8 s avec le bord d'accent.
  - Étant donné un client qui déclenche `pop_tablet:client:notify` sur lui-même avec du HTML, quand le bandeau s'affiche, alors le HTML est affiché en texte brut.

### [BASE-ECR-05] Volet historique des notifications
- **But** : retrouver les notifications passées et ouvrir l'écran lié.
- **Qui** : le joueur qui tient la tablette déverrouillée.
- **Où** : barre du haut > cloche, ou glisser vers le bas depuis la barre.
- **Parcours** :
  1. Le volet descend (150 ms) sur 60 % de la hauteur. La NUI demande `base.notif.list` page 1.
  2. Le serveur renvoie les 20 plus récentes de l'appareil, triées par date décroissante, avec `read`.
  3. La NUI groupe par « Aujourd'hui », « Hier », puis date. Chaque ligne : icône, titre, texte (2 lignes), heure. Non lue = point d'accent à gauche.
  4. Défilement en bas : page suivante (20).
  5. Clic sur une ligne : marque comme lue, ferme le volet, ouvre l'écran lié (si l'app est encore autorisée, sinon `base.bureau.plus_acces`).
  6. À l'ouverture du volet, toutes les notifications affichées sont marquées lues (action `base.notif.read` avec l'id le plus récent : tout ce qui est plus ancien devient lu). Le compteur de la cloche et les pastilles d'app passent à 0.
  7. Bouton « Tout effacer » en haut : confirmation « Effacer toutes les notifications ? » puis `base.notif.clear` ; une ligne glissée vers la gauche se supprime seule (`base.notif.delete`).
- **Données** (`pop_tablet_notifications`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| id | BIGINT auto | Oui | — | — |
| serial | VARCHAR(12), index | Non | — | NULL |
| identifier | VARCHAR(64), index | Non | utilisé pour la boîte d'attente | NULL |
| app | VARCHAR(32) | Oui | — | — |
| title | VARCHAR(120) | Oui | clé ou texte | — |
| body | VARCHAR(320) | Non | — | '' |
| params | TEXT JSON | Non | ≤ 1 Ko | NULL |
| link | TEXT JSON | Non | ≤ 1 Ko | NULL |
| priority | TINYINT | Oui | 0 normal, 1 urgent | 0 |
| is_read | TINYINT(1) | Oui | — | 0 |
| created_at | INT UNSIGNED, index | Oui | — | `os.time()` |
- **Règles serveur** : on ne lit que les notifications du numéro de série de la session ; au plus `Config.Notify.HistoryMax = 50` par appareil (les plus anciennes sont supprimées à l'insertion) ; suppression automatique après `Config.Notify.HistoryDays = 7` jours (nettoyage au démarrage du serveur) ; boîte d'attente : notification visant un identifiant hors ligne → ligne avec `identifier` et `serial = NULL`, rattachée au numéro de série de la première tablette qu'il ouvre ; insertions groupées (`BASE-MOT-04`).
- **Textes et états** :
  - Titre : « Notifications » `base.notif.titre`
  - Vide : « Aucune notification. » `base.notif.vide` (pas de bouton, rien à commencer)
  - « Aujourd'hui » `base.date.aujourdhui` · « Hier » `base.date.hier`
  - « Tout effacer » `base.notif.effacer` · « Effacer toutes les notifications ? » `base.notif.effacer_confirm`
  - Chargement : 4 lignes grises ; au-delà de 5 s « Ça prend plus de temps que prévu. » + « Réessayer » (`BASE-MOT-10`)
  - Erreur : `commun.erreur.serveur`
- **Notifications** : aucune.
- **Liens** : `BASE-ECR-04`, `BASE-API-04`, `BASE-OBJ-08` (effacées à la réinitialisation).
- **Réglages** : `Config.Notify.HistoryMax = 50` · `Config.Notify.HistoryDays = 7` · `Config.Notify.PendingDays = 7`.
- **Journal admin** : non.
- **Performance** : chargé seulement à l'ouverture du volet, pagination 20 ; index `(serial, created_at)`.
- **Cas limites** :
  - Notification dont l'app n'existe plus : affichée avec l'icône générique, clic sans effet sauf marquer lue.
  - Double clic sur « Tout effacer » : `actionId`, une seule suppression.
  - Tablette réinitialisée : historique vide.
- **Critères d'acceptation** :
  - Étant donné 25 notifications, quand le joueur ouvre le volet, alors il en voit 20 et les 5 autres au défilement.
  - Étant donné une notification de facture, quand il la touche, alors l'app Factures s'ouvre sur la facture.
  - Étant donné un client qui demande les notifications d'un autre numéro de série, quand le serveur reçoit, alors il renvoie seulement celles de la session.

### [BASE-ECR-06] Batterie : consommation pendant l'usage
- **But** : la batterie se vide seulement quand la tablette est utilisée, pour un réalisme léger.
- **Qui** : toutes les tablettes ; désactivable par le serveur.
- **Où** : barre du haut ; Réglages > Batterie (pourcentage, « Environ %s d'utilisation restante »).
- **Parcours** :
  1. À l'ouverture, le serveur note `openedAt` dans la session.
  2. Le niveau consommé = minutes ouvertes × (100 / `Config.Battery.MinutesFull`). Défaut 120 min pour 100 % → 0,833 % par minute. Le mode posée consomme pareil.
  3. Côté client, une minuterie de 60 s (tablette ouverte seulement) baisse l'affichage d'autant ; le serveur recale la valeur réelle dans chaque réponse (`battery`).
  4. À la fermeture (ou déconnexion), le serveur calcule `battery = max(0, battery - consommé)` et marque l'appareil à sauvegarder (écriture groupée).
  5. Passage sous 10 % : notification une fois par ouverture « Batterie faible (10 %). ».
  6. À l'ouverture, le serveur programme un `SetTimeout` pour l'instant où la batterie atteint 0 ; il est annulé à la fermeture. À 0 : `BASE-ECR-07`.
  7. La batterie ne baisse jamais tablette fermée.
- **Données** : `battery` DECIMAL(5,2) de `pop_tablet_devices` ; `openedAt` en session.
- **Règles serveur** : calcul uniquement serveur ; le client ne peut jamais envoyer de valeur de batterie ; `Config.Battery.Enabled = false` → batterie toujours 100 et masquée.
- **Textes et états** : « Batterie » `base.reglages.batterie` · « Environ %s d'utilisation restante » `base.batterie.restant` (%s = « 1 h 20 min ») · « Batterie faible (%d %%). » `base.batterie.faible`.
- **Notifications** : au joueur, à 10 %, texte ci-dessus (bandeau, priorité normale).
- **Liens** : `BASE-ECR-03`, `BASE-ECR-07`, `BASE-ECR-08`, `BASE-ECR-09`.
- **Réglages** : `Config.Battery.Enabled = true` · `Config.Battery.MinutesFull = 120` · `Config.Battery.LowWarning = 10`.
- **Journal admin** : non.
- **Performance** : aucun calcul tablette fermée ; un seul `SetTimeout` serveur par tablette ouverte.
- **Cas limites** :
  - Redémarrage du serveur tablette ouverte : `onResourceStop` calcule et sauvegarde toutes les sessions.
  - Joueur qui crashe : `playerDropped` calcule et sauvegarde.
  - `MinutesFull` modifié : la nouvelle vitesse s'applique à la prochaine ouverture.
- **Critères d'acceptation** :
  - Étant donné 100 % et 60 minutes d'utilisation, quand la tablette se ferme, alors la batterie vaut 50 %.
  - Étant donné une tablette fermée pendant 3 heures, quand elle se rouvre, alors la batterie n'a pas bougé.
  - Étant donné un client qui envoie `battery = 100`, quand le serveur reçoit, alors la valeur est ignorée.

### [BASE-ECR-07] Batterie vide
- **But** : définir ce qui se passe quand la batterie atteint 0 %.
- **Qui** : toutes les tablettes avec batterie activée.
- **Où** : tablette ouverte ou tentative d'ouverture.
- **Parcours** :
  1. Tablette ouverte : à 0 %, le `SetTimeout` serveur ferme la session et envoie `pop_tablet:client:forceClose` avec la raison `batterie`.
  2. La NUI affiche 2 s un écran noir avec une icône de batterie vide et « Batterie vide », puis se ferme.
  3. Les actions en cours non validées sont perdues ; une action déjà envoyée au serveur se termine normalement.
  4. Tentative d'ouverture à 0 % : refus avec « Batterie vide. Rechargez la tablette. ».
  5. Les notifications continuent d'arriver dans l'historique (pas de bandeau quand batterie vide).
  6. La tablette n'est jamais « éteinte » au sens où ses données disparaîtraient : seulement inutilisable jusqu'à recharge.
- **Données** : `battery = 0`.
- **Règles serveur** : toute demande avec une batterie à 0 est refusée (`batterie`).
- **Textes et états** : « Batterie vide » `base.batterie.vide_titre` · « Batterie vide. Rechargez la tablette. » `commun.erreur.batterie`.
- **Notifications** : aucune.
- **Liens** : `BASE-ECR-08`, `BASE-ECR-09`, `BASE-MOT-14` (les documents à payer passent alors par la fenêtre simple).
- **Réglages** : aucun en plus.
- **Journal admin** : non.
- **Performance** : aucune.
- **Cas limites** :
  - Batterie vide pendant un paiement déjà envoyé : le paiement est traité, la réponse arrive après la fermeture et s'affiche en `Bridge.Notify`.
  - Batterie vide en mode posée : l'objet posé reste au sol mais les spectateurs voient l'écran noir « Batterie vide » et la vue se ferme.
  - Joueur qui a une facture à payer et une tablette vide : la facture lui est présentée en fenêtre simple.
- **Critères d'acceptation** :
  - Étant donné 1 % et la tablette ouverte, quand 72 s passent, alors la tablette se ferme avec « Batterie vide ».
  - Étant donné 0 %, quand le joueur essaie d'ouvrir, alors il voit « Batterie vide. Rechargez la tablette. ».
  - Étant donné un client qui garde la NUI ouverte malgré l'ordre de fermeture, quand il envoie une demande, alors le serveur refuse avec `session`.

### [BASE-ECR-08] Recharge en véhicule
- **But** : recharger la tablette en roulant, sans aucune boucle.
- **Qui** : tout joueur dans un véhicule à moteur (conducteur ou passager) qui a l'objet ; désactivable.
- **Où** : automatique en entrant / sortant d'un véhicule.
- **Parcours** :
  1. Le client écoute les événements d'entrée et de sortie de véhicule fournis par le bridge (`esx:enteredVehicle` / `esx:exitedVehicle` pour ESX ; `baseevents:enteredVehicle` / `baseevents:leftVehicle` sinon).
  2. Entrée dans un véhicule dont la classe n'est pas exclue (vélos classe 13, exclus par défaut) : le client envoie `pop_tablet:vehicleCharge` `{ state = true }`.
  3. Le serveur note `chargeStart = os.time()` pour ce joueur, s'il a l'objet.
  4. Sortie, déconnexion ou ouverture de la tablette : le serveur calcule `gain = minutes × (100 / Config.Battery.VehicleMinutesFull)` (défaut 30 min pour 100 %), l'ajoute à la batterie de la tablette du joueur (plafond 100), et remet `chargeStart` (si toujours dans le véhicule, nouveau départ maintenant).
  5. Tablette ouverte en véhicule : consommation et recharge s'additionnent (net = recharge - consommation), éclair affiché dans la barre.
- **Données** : `chargeStart` en mémoire serveur par joueur (pas en base).
- **Règles serveur** : le serveur vérifie au moment du calcul que le joueur est bien dans un véhicule (`GetVehiclePedIsIn(GetPlayerPed(source))`) ; sinon gain plafonné au temps jusqu'au dernier événement valide, et si aucun véhicule n'est trouvé à l'événement d'entrée, celui-ci est ignoré ; gain maximal par calcul = 100 %.
- **Textes et états** : « En charge » `base.barre.en_charge`.
- **Notifications** : aucune.
- **Liens** : `BASE-ECR-06`, `BASE-ECR-03`.
- **Réglages** : `Config.Battery.VehicleCharge = true` · `Config.Battery.VehicleMinutesFull = 30` · `Config.Battery.VehicleExcludedClasses = { 13 }`.
- **Journal admin** : non.
- **Performance** : aucune boucle ; deux événements par trajet.
- **Cas limites** :
  - Plusieurs tablettes sur le joueur (inventaire à métadonnées) : la recharge s'applique à toutes celles qu'il porte (lecture des numéros de série dans l'inventaire au moment du calcul).
  - Client modifié qui envoie `state = true` à pied : le serveur ne trouve pas de véhicule et ignore.
  - Batterie désactivée : les événements ne sont pas enregistrés.
- **Critères d'acceptation** :
  - Étant donné 20 % et 15 minutes en voiture, quand le joueur sort, alors la batterie vaut 70 %.
  - Étant donné un vélo, quand il roule 15 minutes, alors la batterie ne change pas.
  - Étant donné un tricheur qui envoie l'entrée en véhicule à pied, quand il attend 30 minutes, alors aucune recharge n'est appliquée.

### [BASE-ECR-09] Recharge au chargeur
- **But** : recharger la tablette avec l'objet « Chargeur de tablette ».
- **Qui** : tout joueur qui a l'objet `pop_tablet_charger` et une tablette ; désactivable.
- **Où** : inventaire > « Chargeur de tablette » > « Utiliser ».
- **Parcours** :
  1. Le joueur utilise le chargeur. Le serveur vérifie qu'il a une tablette dont la batterie est < 100 % (si plusieurs, celle avec la batterie la plus basse), anti-spam 1 par 5 s.
  2. Le client affiche une barre de progression « Recharge de la tablette… » de 10 s (`Bridge.Progress`, annulable avec X), animation `anim@heists@prison_heiststation@cop_reactions` / `cop_b_idle` désactivée par défaut, joueur immobile.
  3. Fin de la barre : le client envoie `pop_tablet:chargerDone` ; le serveur vérifie que 10 s se sont bien écoulées depuis le début (tolérance −0,5 s), met la batterie à 100 %, sauvegarde (écriture groupée).
  4. Le chargeur n'est pas consommé (`Config.Battery.ChargerConsumed = false`).
  5. Annulation : rien ne change.
- **Données** : `battery`.
- **Règles serveur** : durée vérifiée côté serveur ; objet chargeur et tablette revérifiés à la fin ; consommation du chargeur si réglée.
- **Textes et états** : « Recharge de la tablette… » `base.chargeur.encours` · « Tablette rechargée. » `base.chargeur.ok` · « Tablette déjà chargée. » `base.chargeur.pleine` · « Recharge annulée. » `base.chargeur.annule` · « Aucune tablette. » `base.ouvrir.pas_objet`.
- **Notifications** : messages ci-dessus via `Bridge.Notify`.
- **Liens** : `BASE-ECR-06` ; objet vendu par la boutique du serveur (`BASE-OBJ-18`, supprimée).
- **Réglages** : `Config.Battery.Charger = true` · `Config.Battery.ChargerItem = 'pop_tablet_charger'` · `Config.Battery.ChargerSeconds = 10` · `Config.Battery.ChargerConsumed = false`.
- **Journal admin** : non.
- **Performance** : aucune boucle hors barre de progression (10 s).
- **Cas limites** :
  - Tablette ouverte pendant la recharge : autorisé, la barre se joue tablette fermée (l'usage du chargeur ferme d'abord la tablette).
  - Client qui envoie `chargerDone` immédiatement : refusé (durée trop courte).
  - Joueur qui jette le chargeur pendant la barre : refusé à la fin.
- **Critères d'acceptation** :
  - Étant donné 5 % et un chargeur, quand le joueur termine la barre, alors la batterie vaut 100 %.
  - Étant donné 100 %, quand il utilise le chargeur, alors il voit « Tablette déjà chargée. ».
  - Étant donné un tricheur qui envoie `chargerDone` sans attendre, quand le serveur reçoit, alors la batterie ne change pas.

### [BASE-ECR-10] App Réglages
- **But** : regrouper tous les réglages personnels de la tablette.
- **Qui** : le joueur qui tient la tablette déverrouillée.
- **Où** : bureau > icône « Réglages » (toujours présente).
- **Parcours** :
  1. Écran liste à gauche (260 px) : « Apparence », « Langue », « Sons », « Sécurité », « Batterie », « À propos ». Détail à droite.
  2. Chaque changement s'applique immédiatement dans la NUI (aperçu en direct).
  3. Les changements sont envoyés au serveur groupés : à la sortie de l'app Réglages (retour bureau ou fermeture), la NUI envoie `base.settings.save` avec les seules valeurs modifiées.
  4. Le serveur valide chaque valeur (voir fiches dédiées), fusionne dans `settings`, marque l'appareil à sauvegarder et renvoie les valeurs retenues ; une valeur refusée revient à l'ancienne dans la NUI.
  5. « À propos » : numéro de série, « Tablette personnelle » si mode personnage, version de la ressource, nom du serveur (`GetConvar('sv_projectName')`, nettoyé).
- **Données** (`settings` JSON) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| wallpaper | chaîne | Non | id de fond ou URL autorisée ≤ 300 | `Config.Style.DefaultWallpaper` |
| accent | chaîne `#RRGGBB` | Non | contraste ≥ 3:1 | `Config.Style.DefaultAccent` |
| brightness | entier | Non | 40 à 100 | 100 |
| textSize | `s` \| `m` \| `l` | Non | — | `m` |
| locale | chaîne | Non | langue chargée | `Config.Locale` |
| sound | booléen | Non | — | true |
| soundId | entier | Non | 1 à 3 | 1 |
| volume | entier | Non | 0 à 100 | 50 |
| layout | liste | Non | voir `BASE-ECR-02` | — |
- **Règles serveur** : toute clé inconnue est ignorée ; taille totale de `settings` ≤ 16 Ko ; 1 sauvegarde par 3 s.
- **Textes et états** : « Réglages » `base.reglages.titre` · « Apparence » `base.reglages.apparence` · « Langue » `base.reglages.langue` · « Sons » `base.reglages.sons` · « Sécurité » `base.reglages.securite` · « Batterie » `base.reglages.batterie` · « À propos » `base.reglages.apropos` · « Version » `base.reglages.apropos.version` · succès : « Réglages enregistrés. » `base.reglages.ok` (bandeau 2 s, seulement si au moins une valeur a changé).
- **Notifications** : aucune.
- **Liens** : `BASE-ECR-11` à `BASE-ECR-16`, `BASE-OBJ-04`, `BASE-OBJ-06`, `BASE-ECR-06`.
- **Réglages** : `Config.Settings.AllowWallpaper = true` · `Config.Settings.AllowAccent = true` (si `false`, la section est cachée et la couleur du serveur s'impose).
- **Journal admin** : non.
- **Performance** : aucune demande réseau pendant les réglages ; une seule à la sortie.
- **Cas limites** :
  - Fermeture brutale (crash) avant la sortie de l'app : les changements non envoyés sont perdus (comportement accepté).
  - Valeur refusée : la NUI revient à l'ancienne valeur sans message bloquant, avec `commun.erreur.invalide` en bandeau.
  - Réglage désactivé par le serveur : section cachée.
- **Critères d'acceptation** :
  - Étant donné un accent changé, quand le joueur revient au bureau puis rouvre la tablette, alors l'accent est conservé.
  - Étant donné 5 réglages modifiés, quand il quitte Réglages, alors une seule demande part au serveur.
  - Étant donné un client qui envoie `brightness = 5`, quand le serveur reçoit, alors il garde l'ancienne valeur.

### [BASE-ECR-11] Fond d'écran
- **But** : personnaliser le fond du bureau.
- **Qui** : le joueur qui tient la tablette ; désactivable par le serveur.
- **Où** : Réglages > Apparence > « Fond d'écran ».
- **Parcours** :
  1. Grille de 8 vignettes : 6 fonds unis sombres (`uni-1` #0B0B0D, `uni-2` #101418, `uni-3` #14110F, `uni-4` #0F1412, `uni-5` #15101A, `uni-6` #1A1A1A) et 2 images sobres fournies (`img-1` ville de nuit sombre, `img-2` carte routière sombre), fichiers `web/img/wallpapers/img-1.webp`, `img-2.webp` (≤ 150 Ko chacun, 1180 × 760).
  2. Clic sur une vignette : aperçu immédiat, coche sur la vignette choisie.
  3. Si `Config.Settings.CustomWallpaper = true` : champ « Lien d'une image » + bouton « Utiliser ». La NUI vérifie le format, le serveur vérifie le domaine (`BASE-MOT-18`).
  4. Enregistrement avec les autres réglages (`BASE-ECR-10`).
  5. Le fond s'affiche sur le bureau et l'écran de verrouillage, avec un voile noir à 35 % au-dessus des images pour garder la lisibilité des icônes.
- **Données** : `settings.wallpaper` (id `uni-1` à `uni-6`, `img-1`, `img-2`, ou URL).
- **Règles serveur** : id dans la liste ou URL validée par `BASE-MOT-18` ; sinon valeur par défaut.
- **Textes et états** : « Fond d'écran » `base.apparence.fond` · « Lien d'une image » `base.apparence.lien` · « Utiliser » `base.commun.utiliser` · « Ce site d'images n'est pas autorisé sur le serveur. » `base.image.domaine` · « Ce lien n'est pas une image. » `base.image.format`.
- **Notifications** : aucune.
- **Liens** : `BASE-MOT-18`, `BASE-ECR-10`.
- **Réglages** : `Config.Style.DefaultWallpaper = 'uni-1'` · `Config.Settings.CustomWallpaper = false`.
- **Journal admin** : oui pour une URL personnalisée (numéro de série, joueur, URL).
- **Performance** : images locales ; URL externe chargée uniquement par la NUI de ce joueur.
- **Cas limites** :
  - Image externe qui ne charge plus : la NUI affiche `uni-1` à la place (événement `onerror`).
  - URL non autorisée : refus, ancien fond gardé.
  - `AllowWallpaper = false` : section cachée, fond du serveur imposé.
- **Critères d'acceptation** :
  - Étant donné le fond `uni-3`, quand le joueur rouvre la tablette, alors le fond est #14110F.
  - Étant donné une URL Imgur autorisée, quand il l'utilise, alors elle s'affiche.
  - Étant donné une URL `javascript:` envoyée par un client modifié, quand le serveur reçoit, alors elle est refusée.

### [BASE-ECR-12] Couleur d'accent
- **But** : choisir la seule couleur de mise en avant de l'interface.
- **Qui** : le joueur qui tient la tablette ; désactivable par le serveur.
- **Où** : Réglages > Apparence > « Couleur d'accent ».
- **Parcours** :
  1. 8 pastilles : `#4FA3FF` (bleu, défaut), `#3FB950` (vert), `#F5A524` (orange), `#E5484D` (rouge), `#A78BFA` (violet), `#2DD4BF` (turquoise), `#F2F2F2` (blanc), `#FACC15` (jaune).
  2. Champ « Couleur personnalisée » `#RRGGBB` (si `Config.Settings.CustomAccent = true`).
  3. Aperçu immédiat : la variable CSS `--pt-accent` change partout.
  4. Validation : format `^#%x%x%x%x%x%x$` et contraste ≥ 3:1 contre le fond `#0E0F12` (calcul de luminance relative WCAG), côté NUI et côté serveur.
- **Données** : `settings.accent`.
- **Règles serveur** : format et contraste revérifiés ; sinon accent par défaut.
- **Textes et états** : « Couleur d'accent » `base.apparence.accent` · « Couleur personnalisée » `base.apparence.accent_perso` · « Couleur trop sombre pour être lisible. » `base.apparence.accent_sombre`.
- **Notifications** : aucune.
- **Liens** : `BASE-MOT-09` (kit de style).
- **Réglages** : `Config.Style.DefaultAccent = '#4FA3FF'` · `Config.Settings.CustomAccent = true` · `Config.Style.AccentPresets = { ... les 8 valeurs ... }`.
- **Journal admin** : non.
- **Performance** : changement d'une variable CSS.
- **Cas limites** :
  - `#000000` saisi : refus avec le message « trop sombre ».
  - `#FFF` (3 caractères) : refus format.
  - Accent désactivé par le serveur : section cachée.
- **Critères d'acceptation** :
  - Étant donné la pastille verte, quand le joueur la touche, alors tous les boutons principaux deviennent verts immédiatement.
  - Étant donné `#101010`, quand il valide, alors il voit le message « trop sombre ».
  - Étant donné un client qui envoie `red;background:url(...)`, quand le serveur reçoit, alors il garde l'accent par défaut.

### [BASE-ECR-13] Luminosité
- **But** : régler la luminosité de l'écran de la tablette.
- **Qui** : le joueur qui tient la tablette.
- **Où** : Réglages > Apparence > « Luminosité » (curseur).
- **Parcours** :
  1. Curseur de 40 % à 100 %, pas de 5 %. Flèches gauche/droite au clavier.
  2. Appliqué immédiatement par `filter: brightness(x)` sur le conteneur de l'écran (pas sur le cadre).
  3. Enregistré avec les autres réglages.
- **Données** : `settings.brightness` entier 40 à 100, défaut 100.
- **Règles serveur** : entier entre 40 et 100, multiple de 5 ; sinon 100.
- **Textes et états** : « Luminosité » `base.apparence.luminosite`.
- **Notifications** : aucune.
- **Liens** : `BASE-ECR-10`.
- **Réglages** : `Config.Settings.MinBrightness = 40`.
- **Journal admin** : non.
- **Performance** : propriété CSS seule.
- **Cas limites** :
  - Valeur 37 envoyée : ramenée à 100.
  - Mode posée : les spectateurs voient la luminosité du propriétaire.
  - Écran de verrouillage : luminosité appliquée aussi.
- **Critères d'acceptation** :
  - Étant donné 60 %, quand le joueur rouvre la tablette, alors l'écran est à 60 %.
  - Étant donné le curseur à 40 %, quand il appuie sur flèche gauche, alors il reste à 40 %.
  - Étant donné un client qui envoie 0, quand le serveur reçoit, alors il enregistre 100.

### [BASE-ECR-14] Taille du texte
- **But** : agrandir ou réduire le texte pour le confort de lecture.
- **Qui** : le joueur qui tient la tablette.
- **Où** : Réglages > Apparence > « Taille du texte » (3 boutons).
- **Parcours** :
  1. Trois choix : « Petit » (taille de base 13 px), « Normal » (15 px), « Grand » (17 px).
  2. La variable CSS `--pt-font-size` change ; toutes les tailles du kit sont en `rem` relatives à cette base.
  3. Enregistré avec les autres réglages.
- **Données** : `settings.textSize` `s` | `m` | `l`, défaut `m`.
- **Règles serveur** : valeur dans la liste ; sinon `m`.
- **Textes et états** : « Taille du texte » `base.apparence.texte` · « Petit » `base.apparence.petit` · « Normal » `base.apparence.normal` · « Grand » `base.apparence.grand`.
- **Notifications** : aucune.
- **Liens** : `BASE-MOT-09`.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : variable CSS seule.
- **Cas limites** :
  - Texte « Grand » qui déborde d'un libellé d'icône : coupé avec « … ».
  - Apps tierces qui n'utilisent pas le kit : non concernées (documenté dans le guide).
  - Valeur inconnue : `m`.
- **Critères d'acceptation** :
  - Étant donné « Grand », quand le joueur ouvre une app du kit, alors le texte courant fait 17 px.
  - Étant donné « Petit », quand il rouvre, alors le choix est conservé.
  - Étant donné un client qui envoie `xxl`, quand le serveur reçoit, alors il enregistre `m`.

### [BASE-ECR-15] Langue de la tablette
- **But** : afficher la tablette dans la langue choisie par le joueur.
- **Qui** : le joueur qui tient la tablette.
- **Où** : Réglages > Langue ; écran « Bienvenue ».
- **Parcours** :
  1. Liste des langues chargées (fichiers `locales/*.lua` présents, nom affiché dans la langue elle-même : « Français », « English »).
  2. Choix : la NUI demande `base.locale.get` avec le code ; le serveur renvoie la table des textes de cette langue (mise en cache serveur) ; la NUI rafraîchit l'affichage.
  3. Enregistré dans `settings.locale`.
  4. Les notifications sont envoyées en clés + paramètres et traduites par la NUI dans la langue de la tablette ; les textes écrits par des joueurs ne sont jamais traduits.
  5. Les messages hors tablette (`Bridge.Notify`) utilisent la langue de la tablette du joueur si connue, sinon `Config.Locale`.
- **Données** : `settings.locale` (code `fr`, `en`).
- **Règles serveur** : code présent parmi les langues chargées ; sinon `Config.Locale`.
- **Textes et états** : « Langue » `base.reglages.langue` · « Langue modifiée. » `base.langue.ok`.
- **Notifications** : aucune.
- **Liens** : `BASE-MOT-16` (langues).
- **Réglages** : `Config.Locale = 'fr'` · `Config.Settings.AllowLocale = true`.
- **Journal admin** : non.
- **Performance** : table de langue envoyée une fois à l'ouverture (et au changement), gardée en mémoire par la NUI.
- **Cas limites** :
  - Clé absente dans `en` : repli `fr`, puis affichage de la clé elle-même (`BASE-MOT-16`).
  - Langue arabe ajoutée plus tard : `dir="rtl"` appliqué si la langue est déclarée `rtl = true`.
  - Fichier de langue supprimé alors qu'une tablette l'utilisait : repli `Config.Locale`.
- **Critères d'acceptation** :
  - Étant donné « English », quand le joueur la choisit, alors « Réglages » devient « Settings » immédiatement.
  - Étant donné une notification de facture, quand deux joueurs en fr et en la reçoivent, alors chacun la lit dans sa langue.
  - Étant donné un client qui envoie `../../server`, quand le serveur reçoit, alors il garde la langue par défaut.

### [BASE-ECR-16] Son des notifications
- **But** : choisir si les notifications font un son, lequel et à quel volume.
- **Qui** : le joueur qui tient la tablette.
- **Où** : Réglages > Sons.
- **Parcours** :
  1. Interrupteur « Son des notifications » (activé par défaut).
  2. Choix du son parmi 3 : « Discret », « Clair », « Double » (fichiers `web/sounds/notif-1.ogg`, `notif-2.ogg`, `notif-3.ogg`, ≤ 30 Ko, ≤ 1 s). Toucher un son le joue en aperçu.
  3. Curseur « Volume » 0 à 100, défaut 50.
  4. Le son est joué par la NUI (`Audio`) à chaque bandeau, tablette ouverte ou fermée ; pas de son si plus d'un bandeau dans la même seconde (un seul son).
- **Données** : `settings.sound`, `settings.soundId`, `settings.volume`.
- **Règles serveur** : booléen ; `soundId` 1 à 3 ; volume entier 0 à 100.
- **Textes et états** : « Son des notifications » `base.sons.notif` · « Discret » `base.sons.s1` · « Clair » `base.sons.s2` · « Double » `base.sons.s3` · « Volume » `base.sons.volume`.
- **Notifications** : aucune.
- **Liens** : `BASE-ECR-04`.
- **Réglages** : `Config.Sound.Enabled = true` (si `false`, aucun son pour personne et la section est cachée).
- **Journal admin** : non.
- **Performance** : sons préchargés par la NUI au démarrage du client (3 petits fichiers).
- **Cas limites** :
  - Volume 0 : aucun son, interrupteur laissé tel quel.
  - 5 notifications d'un coup : un seul son.
  - Son désactivé par le serveur : section cachée.
- **Critères d'acceptation** :
  - Étant donné le son « Double » à 80, quand une notification arrive, alors ce son est joué à 80 %.
  - Étant donné l'interrupteur coupé, quand une notification arrive, alors aucun son n'est joué.
  - Étant donné un client qui envoie `soundId = 9`, quand le serveur reçoit, alors il enregistre 1.

### [BASE-ECR-17] Indicateur de réseau et zones sans réseau (ajout)
- **But** : donner un sens à l'icône réseau : sous l'eau ou dans des zones choisies par le serveur, les apps en ligne ne marchent pas.
- **Qui** : tous ; désactivable.
- **Où** : barre du haut ; toutes les apps qui ne sont pas déclarées `offline = true`.
- **Parcours** :
  1. À l'ouverture et à chaque ouverture d'app, le client calcule : sous l'eau (`IsPedSwimmingUnderWater`) → 0 barre ; dans une zone de `Config.Network.DeadZones` (liste `{ coords, radius }`) → 0 ; intérieur dont le hash est dans `Config.Network.DeadInteriors` → 1 barre ; sinon 4 barres.
  2. Le client envoie le résultat avec chaque demande ; le serveur refait le test des zones (coordonnées serveur) et refuse avec `reseau` si 0.
  3. 0 barre : une app non `offline` affiche l'état « Pas de réseau » (icône, `commun.erreur.reseau`, bouton « Réessayer »). Réglages fonctionne toujours.
  4. Les notifications reçues sans réseau vont dans l'historique sans bandeau.
- **Données** : aucune stockée.
- **Règles serveur** : test serveur des zones mortes à chaque demande (simple calcul de distance sur une liste courte).
- **Textes et états** : « Pas de réseau » `base.reseau.titre` · `commun.erreur.reseau` · « Réessayer » `base.commun.reessayer`.
- **Notifications** : aucune.
- **Liens** : `BASE-ECR-03`, `BASE-API-02` (`offline`).
- **Réglages** : `Config.Network.Enabled = true` · `Config.Network.DeadZones = {}` · `Config.Network.DeadInteriors = {}` · `Config.Network.Underwater = true`.
- **Journal admin** : non.
- **Performance** : calcul seulement à l'ouverture d'un écran ; aucune boucle.
- **Cas limites** :
  - Liste vide (défaut) : réseau toujours plein sauf sous l'eau.
  - Joueur qui sort de la zone : « Réessayer » relance la demande.
  - Client qui ment (4 barres) dans une zone morte : refus serveur.
- **Critères d'acceptation** :
  - Étant donné une zone morte au bunker, quand le joueur ouvre le MDT dedans, alors il voit « Pas de réseau ».
  - Étant donné un joueur sous l'eau, quand il ouvre Réglages, alors Réglages fonctionne.
  - Étant donné un client modifié qui envoie 4 barres en zone morte, quand le serveur reçoit, alors il refuse avec `reseau`.

---

## 3. Le moteur (invisible)

### [BASE-MOT-01] Vérification serveur de chaque demande
- **But** : aucune demande de la NUI n'est exécutée sans contrôle complet par le serveur.
- **Qui** : système ; s'applique à toutes les apps, y compris celles du dossier « mes apps ».
- **Où** : callback unique `pop_tablet:request` côté serveur.
- **Parcours** :
  1. La NUI appelle `Pop.request(app, action, data)` ; le client relaie au serveur via `Callback.Trigger('pop_tablet:request', { token, app, action, data, actionId, network })`.
  2. Le serveur applique dans cet ordre, en s'arrêtant au premier échec :
     1. joueur chargé (`Bridge.GetPlayer`) → sinon `session` ;
     2. jeton = jeton de la session du joueur, session `unlocked` (sauf actions `base.pin.*`) → sinon `session` ;
     3. objet tablette possédé avec le numéro de série de la session (`Bridge.HasItem(source, 'pop_tablet', { serial })`, résultat gardé 10 s) → sinon `pas_tablette` puis fermeture ;
     4. batterie > 0 → sinon `batterie` ;
     5. réseau (`BASE-ECR-17`) si l'app n'est pas `offline` → sinon `reseau` ;
     6. action déclarée par l'app (`BASE-API-02`) → sinon `invalide` ;
     7. accès à l'app et droit de l'action (`HasAccess`, recalculé avec le métier actuel) → sinon `pas_droit` ;
     8. hors service : si l'action est déclarée `duty = true` et que le joueur est hors service → `hors_service` ;
     9. anti-spam (`BASE-MOT-11`) → sinon `trop_vite` ;
     10. `actionId` déjà vu (actions `write`) → sinon `doublon` ;
     11. schéma des données (types, longueurs, champs obligatoires) déclaré par l'action → sinon `invalide` ;
     12. nettoyage des textes (`BASE-MOT-12`) ;
     13. exécution du gestionnaire dans un `pcall` → en cas d'erreur Lua : `serveur` et trace console (jamais renvoyée au client).
  3. La réponse revient à la NUI ; un échec s'affiche avec le texte de `commun.erreur.<code>`.
- **Données** : schéma d'action :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| name | chaîne | Oui | ≤ 48, `[a-z0-9_.]` | — |
| write | booléen | Non | — | false |
| duty | booléen | Non | — | false |
| permission | chaîne (clé de droit) | Non | — | nil (accès app suffit) |
| rate | `{ n, s }` | Non | — | `Config.RateLimit.Default` |
| schema | table champ → `{ type, max, min, required, pattern }` | Non | — | {} |
| handler | fonction(source, data, ctx) | Oui | — | — |
- **Règles serveur** : décrites au parcours ; données reçues > 32 Ko refusées d'emblée ; tables imbriquées > 5 niveaux refusées.
- **Textes et états** : codes d'erreur communs (section 0).
- **Notifications** : aucune.
- **Liens** : toutes les apps ; `BASE-MOT-11`, `BASE-MOT-12`, `BASE-API-02`.
- **Réglages** : `Config.Security.MaxPayload = 32768` · `Config.Security.ItemCheckCache = 10` (secondes).
- **Journal admin** : oui pour les refus suspects : `session` avec un jeton faux, `pas_droit`, `doublon`, `invalide` (joueur, app, action, raison) ; regroupés par joueur (1 ligne par minute maximum avec un compteur).
- **Performance** : vérifications en mémoire (pas de requête SQL) ; seule la possession d'objet appelle l'inventaire, mise en cache 10 s.
- **Cas limites** :
  - Erreur Lua dans une app tierce : réponse `serveur`, la tablette continue de fonctionner.
  - Demande pendant la fermeture : `session`.
  - App retirée entre l'ouverture et la demande : `invalide`.
- **Critères d'acceptation** :
  - Étant donné une demande valide, quand elle arrive, alors le gestionnaire reçoit des données déjà nettoyées.
  - Étant donné une action `write` envoyée deux fois avec le même `actionId`, quand le serveur reçoit la seconde, alors il renvoie `doublon` sans exécuter.
  - Étant donné un tricheur qui appelle le callback avec un jeton inventé, quand le serveur reçoit, alors il renvoie `session` et journalise la tentative.

### [BASE-MOT-02] Adaptateur framework unique (bridge ESX / QBCore / Qbox)
- **But** : toute la tablette parle au framework par une seule couche, pour fonctionner **dès la sortie, au même niveau et testée à fond** avec ESX, QBCore et Qbox (aucune version expérimentale).
- **Qui** : système.
- **Où** : `bridge/server.lua`, `bridge/client.lua` et un fichier par framework (`bridge/esx.lua`, `bridge/qb.lua`, `bridge/qbx.lua`), fichiers ouverts copiés depuis `templates/pop_base`.
- **Parcours** :
  1. Au démarrage, détection selon `Config.Framework = 'auto'` : `es_extended` démarré → ESX ; sinon `qbx_core` → Qbox (exports natifs `qbx_core`, pas l'objet QBCore de compatibilité) ; sinon `qb-core` → QBCore ; sinon arrêt avec message console « [pop_tablet] No compatible framework found (ESX, QBCore, Qbox). ».
  2. Le reste du code n'appelle que les fonctions ci-dessous. Dans toutes les fiches, « métier ESX », « grade ESX », `xPlayer`, `users.*`, `job_grades` désignent ce que renvoie le bridge pour le framework détecté (colonnes ci-dessous).
  3. Fonctions serveur obligatoires :
| Fonction | ESX | QBCore | Qbox |
|---|---|---|---|
| `Bridge.GetPlayer(src)` | `ESX.GetPlayerFromId` | `QBCore.Functions.GetPlayer` | `exports.qbx_core:GetPlayer` |
| `Bridge.GetIdentifier(src)` | `xPlayer.identifier` | `PlayerData.citizenid` | `PlayerData.citizenid` |
| `Bridge.GetName(src)` / `GetCharName(identifier)` | `xPlayer.getName()` / `users.firstname` + `lastname` | `PlayerData.charinfo.firstname .. ' ' .. lastname` / colonne JSON `players.charinfo` | idem QBCore (table `players`) |
| `Bridge.GetJob(src)` → `{ name, label, grade, gradeName, gradeLabel, isBoss }` | `xPlayer.job` (`isBoss` = `grade_name == 'boss'`) | `PlayerData.job` (`grade.level`, `grade.name`, `isboss`) | `PlayerData.job` (même format ; métier principal si plusieurs métiers) |
| `Bridge.GetJobs()` → liste des métiers et grades | tables `jobs` + `job_grades` | `QBCore.Shared.Jobs` (grades indexés `'0'`, `'1'`… convertis en nombres) | `exports.qbx_core:GetJobs()` |
| `Bridge.GetMoney(src, account)` | `xPlayer.getAccount(account).money` (`money`, `bank`, `black_money`) | `PlayerData.money[cash|bank]` (`money` → `cash`) | `exports.qbx_core:GetMoney(src, 'cash'|'bank')` |
| `Bridge.AddMoney / RemoveMoney(src, account, amount, reason)` | `addAccountMoney` / `removeAccountMoney` | `Player.Functions.AddMoney` / `RemoveMoney` | `exports.qbx_core:AddMoney` / `RemoveMoney` |
| `Bridge.AddMoneyOffline(identifier, account, amount)` | `users.accounts` (JSON) | colonne JSON `players.money` | `exports.qbx_core:AddMoney(citizenid, …)` (accepte un joueur hors ligne) |
| `Bridge.GetSocietyMoney / AddSocietyMoney / RemoveSocietyMoney(job, amount, reason)` | `esx_addonaccount` / `esx_society`, compte `society_<job>` | détecté : `qb-banking` (v2 : `GetAccountBalance` / `AddMoney` / `RemoveMoney`), sinon `qb-management` (`GetAccount` / `AddMoney` / `RemoveMoney`) | détecté : `Renewed-Banking` (`getAccountMoney` / `addAccountMoney` / `removeAccountMoney`), sinon `qb-banking` |
| `Bridge.IsDead(src)` | état `isDead` (`esx_ambulancejob` : `users.is_dead` en cache) ou `GetEntityHealth <= 0` | `PlayerData.metadata.isdead` ou `inlaststand` | `PlayerData.metadata.isdead` ou `inlaststand` (qbx_medical) |
| `Bridge.GetPlayerFromIdentifier(id)` | `ESX.GetPlayerFromIdentifier` | `QBCore.Functions.GetPlayerByCitizenId` | `exports.qbx_core:GetPlayerByCitizenId` |
| `Bridge.SetPlayerJob(src|identifier, job, grade)` (en ligne ou hors ligne) | `xPlayer.setJob` / `UPDATE users SET job, job_grade` | `Player.Functions.SetJob` / colonne JSON `players.job` | `exports.qbx_core:SetPlayerPrimaryJob` / `AddPlayerToJob(citizenid, job, grade)` (hors ligne compris) |
| `Bridge.GetEmployees(job)` → `{ identifier, name, grade }` (en ligne et hors ligne) | `SELECT identifier, firstname, lastname, job_grade FROM users WHERE job = ?` | `SELECT citizenid, charinfo, job FROM players WHERE JSON_VALUE(job, '$.name') = ?` | `exports.qbx_core:GetGroupMembers(job, 'job')` + `players.charinfo` |
| `Bridge.SetDutyFlag(src, onDuty)` | `xPlayer.setJob(job, grade, onDuty)` si `Config.Duty.SyncFrameworkDuty` (ESX Legacy) | `Player.Functions.SetJobDuty(onDuty)` | `exports.qbx_core:SetJobDuty(src, onDuty)` |
| `Bridge.CreateJob / SaveGrades(job, label, grades)` (création de métier, création / renommage / suppression de grade, salaire) | `INSERT/UPDATE jobs`, `job_grades` + `ESX.RefreshJobs()` | `QBCore.Functions.AddJob` / `UpdateJob` (en mémoire) | `exports.qbx_core:CreateJob` / `UpsertJobGrade` / `RemoveJobGrade` (en mémoire) |
| `Bridge.OnPlayerLoaded(cb)` / `OnPlayerDropped(cb)` / `OnJobChange(cb)` | `esx:playerLoaded` / `playerDropped` / `esx:setJob` | `QBCore:Server:PlayerLoaded` / `playerDropped` / `QBCore:Server:OnJobUpdate` | `QBCore:Server:PlayerLoaded` (émis par qbx_core) / `playerDropped` / `QBCore:Server:OnJobUpdate` |
| `Bridge.OnPlayerDeath(cb(src))` (joueur tombé : mort ou à terre) | client de la tablette : `esx:onPlayerDeath` → événement interne `pop_tablet:bridge:died` au serveur | serveur : `hospital:server:SetDeathStatus(true)` et `hospital:server:SetLaststandStatus(true)` (qb-ambulancejob, `source` = joueur) ; client : `QBCore:Player:SetPlayerData` quand `metadata.isdead` ou `inlaststand` passe de `false` à `true` → `pop_tablet:bridge:died` | serveur : `AddStateBagChangeHandler('isDead')` sur l'état du joueur (qbx_medical) ; client : `QBCore:Player:SetPlayerData` (émis par qbx_core) quand `metadata.isdead` ou `inlaststand` passe à `true` → `pop_tablet:bridge:died` |
| `Bridge.OnPlayerRevived(cb(src))` (réveil) | client : `esx:onPlayerSpawn` et `esx_ambulancejob:revive` → `pop_tablet:bridge:revived` | serveur : `hospital:server:SetDeathStatus(false)` et `SetLaststandStatus(false)` ; client : `metadata.isdead` et `inlaststand` repassés à `false` dans `QBCore:Player:SetPlayerData` → `pop_tablet:bridge:revived` | serveur : state bag `isDead` repassé à `false` ; client : `metadata.isdead` et `inlaststand` à `false` dans `QBCore:Player:SetPlayerData` → `pop_tablet:bridge:revived` |
| `Bridge.GetVehicles(identifier)` → `{ plate, model, owner, stored }` (véhicules d'un personnage, en ligne ou hors ligne) | `SELECT plate, vehicle, owner, stored FROM owned_vehicles WHERE owner = ?` (`model` lu dans le JSON `vehicle`) | `SELECT plate, vehicle, mods, citizenid, state FROM player_vehicles WHERE citizenid = ?` (`model` = colonne `vehicle` ; `stored` = `state = 1`) | idem QBCore (table `player_vehicles` de qbx_vehicles) |
| `Bridge.FindPlate(plate)` → `{ plate, model, owner, ownerType }` ou `nil` (plaque normalisée : majuscules, espaces retirés) | `SELECT plate, vehicle, owner FROM owned_vehicles WHERE REPLACE(plate,' ','') = ?` ; `owner` commençant par `society_` → `ownerType = 'company'`, sinon `'player'` | `SELECT plate, vehicle, citizenid FROM player_vehicles WHERE REPLACE(plate,' ','') = ?` (`ownerType = 'player'`) | idem QBCore |
| `Bridge.GetDirtyMoney / AddDirtyMoney / RemoveDirtyMoney(src, amount)` (argent sale, forme `Config.Gang.DirtyMoney`, MET-GANG-07) | compte `black_money` (`getAccount` / `addAccountMoney` / `removeAccountMoney`) | objet `markedbills`, valeur = somme des `info.worth` (qb-inventory) ou `metadata.worth` (ox_inventory) | idem QBCore (ox_inventory) |
| `Bridge.Notify(src, text, type)` | `xPlayer.showNotification` | `QBCore:Notify` | `exports.qbx_core:Notify` |
  4. **Persistance des métiers et grades sur QBCore et Qbox** : leurs métiers sont définis dans un fichier Lua (`qb-core/shared/jobs.lua`, `qbx_core/shared/jobs.lua`) que la tablette ne modifie jamais. Ce que la tablette crée ou change (métier, grade, libellé, salaire = champ `payment` du grade) est enregistré dans `pop_tablet_company_grades` (fichier 05) et réappliqué par `Bridge.SaveGrades` à chaque démarrage, après le chargement du framework. Les grades des employés sont stockés par le framework (QBCore : colonne JSON `players.job` ; Qbox : table `player_groups`). La console affiche une fois « [pop_tablet] QBCore/Qbox: jobs created in the tablet are re-applied at each start. ».
  5. **Comptes société** : détection au démarrage dans l'ordre de la colonne (premier système démarré retenu) ; message console « [pop_tablet] Society account: %s ». Aucun système détecté sur QBCore / Qbox : le compte d'entreprise affiche « Compte d'entreprise indisponible » `commun.compte_indisponible`, les actions d'argent sur le compte sont refusées avec `fonds_entreprise`, le reste fonctionne ; adaptateur optionnel `bridge/bank/custom.lua` (non fourni) prioritaire s'il existe.
  6. **Mort et réveil sans boucle** : `OnPlayerDeath` et `OnPlayerRevived` ne s'appuient que sur des événements et des changements d'état (state bag, mise à jour de `PlayerData`) ; aucun test périodique de la santé. Le serveur garde en mémoire `Bridge.Down[src] = true/false` et n'appelle les `cb` qu'au **changement** d'état (deux événements « mort » de suite = un seul appel). Tout événement venant du client (`pop_tablet:bridge:died`, `pop_tablet:bridge:revived`) ne fait que déclencher une vérification serveur `Bridge.IsDead(src)` : si l'état réel ne correspond pas, rien ne se passe ; fréquence 1 / 5 s par joueur. La tablette envoie aussi `pop_tablet:bridge:revived` à chaque ouverture (filet si un script de mort ne déclenche aucun des événements ci-dessus). Pour un autre script de mort : `Config.Bridge.DeathEvent = 'auto'` et `Config.Bridge.ReviveEvent = 'auto'` acceptent le nom d'un événement client à écouter à la place.
  7. Fonctions client : `Bridge.Notify` (ESX `ESX.ShowNotification`, QBCore `QBCore.Functions.Notify`, Qbox `exports.qbx_core:Notify` ; ox_lib `notify` si présent), `Bridge.Progress(label, ms)` (ox_lib `progressBar` si présent, sinon barre NUI de la tablette), `Bridge.IsHandcuffed()` (ESX état `isHandcuffed`, QBCore / Qbox `PlayerData.metadata.ishandcuffed`), événements d'entrée/sortie de véhicule.
- **Données** : aucune propre (grades de QBCore / Qbox : `pop_tablet_company_grades`, fichier 05).
- **Règles serveur** : jamais d'appel direct à ESX/QB/Qbox en dehors du bridge (vérifié par l'auditeur avec une recherche `ESX%.` / `QBCore%.` / `qbx_core` hors `bridge/`) ; toute fonction absente pour un framework renvoie une valeur sûre (`nil`, `false`, `0`) et écrit un avertissement console une seule fois ; montant ≤ 0 refusé dans toutes les fonctions d'argent.
- **Textes et états** : messages console (non traduits, en anglais pour les développeurs) : « [pop_tablet] Framework detected: %s » ; « Compte d'entreprise indisponible » `commun.compte_indisponible`.
- **Notifications** : aucune.
- **Liens** : tout le reste ; `BASE-MOT-03`, `BASE-MOT-15` ; fichier 02 (grades, compte d'entreprise), fichier 05 (création de métier).
- **Réglages** : `Config.Framework = 'auto'` (`'auto'` | `'esx'` | `'qb'` | `'qbx'`) · `Config.SocietyAccount = 'auto'` (`'auto'` | `'esx_addonaccount'` | `'qb-banking'` | `'qb-management'` | `'Renewed-Banking'` | `'custom'`) · `Config.Bridge.DeathEvent = 'auto'` · `Config.Bridge.ReviveEvent = 'auto'` · `Config.Gang.DirtyMoney = 'auto'` · `Config.Vehicles.Table = 'auto'` (`'owned_vehicles'` | `'player_vehicles'`, pour un script de garage qui renomme la table).
- **Journal admin** : non.
- **Performance** : objets framework et système de compte récupérés une fois au démarrage.
- **Cas limites** :
  - ESX ancien (1.1) sans `xPlayer.getName` : repli `firstname` / `lastname` de la table `users`.
  - Framework démarré après `pop_tablet` : `fxmanifest` déclare `dependencies { 'oxmysql' }` et le bridge attend le framework détecté 10 s maximum avant d'abandonner.
  - Métier sans grade `boss` (ESX) ou sans `isboss` (QBCore / Qbox) : `isBoss` = grade le plus haut.
  - Qbox avec plusieurs métiers par joueur : la tablette utilise le métier principal ; les métiers secondaires alimentent le sélecteur d'entreprise des apps Gestion pro (fichier 06, C16).
  - Grade QBCore supprimé du fichier `jobs.lua` par le serveur alors que la tablette l'a en base : la tablette le recrée au démarrage et l'écrit au journal.
  - Joueur réanimé sur QBCore par un script qui met `metadata.isdead = false` sans déclencher `hospital:server:SetDeathStatus` : la mise à jour `QBCore:Player:SetPlayerData` côté client suffit à envoyer `pop_tablet:bridge:revived`.
  - Plaque présente deux fois dans la table des véhicules (doublon d'un script de garage) : `FindPlate` renvoie la première ligne et écrit un avertissement console une fois.
- **Critères d'acceptation** :
  - Étant donné un serveur ESX Legacy, QBCore ou Qbox, quand la ressource démarre, alors la console affiche « Framework detected: esx », « qb » ou « qbx ».
  - Étant donné un mécano promu par `/setjob` (ESX, QBCore ou Qbox), quand il ouvre la tablette, alors son nouveau grade est utilisé.
  - Étant donné un serveur QBCore où le patron a créé un grade dans la tablette, quand le serveur redémarre, alors le grade existe toujours avec son salaire.
  - Étant donné un appel `Bridge.AddMoney` avec un montant négatif, quand il est exécuté, alors il est refusé (montant ≤ 0 interdit dans le bridge).
  - Étant donné un joueur Qbox à terre puis réanimé par qbx_medical, quand son état change, alors `OnPlayerDeath` puis `OnPlayerRevived` sont appelés chacun une fois, sans aucune boucle.
  - Étant donné un client qui envoie `pop_tablet:bridge:revived` alors qu'il est encore mort, quand le serveur le reçoit, alors `Bridge.IsDead` est vrai et aucun `cb` n'est appelé.

### [BASE-MOT-03] Adaptateur inventaire et interactions (ajout)
- **But** : gérer l'objet tablette et les interactions de façon identique quel que soit l'inventaire et le système de ciblage.
- **Qui** : système.
- **Où** : `bridge/server.lua`, `bridge/client.lua`.
- **Parcours** :
  1. Détection inventaire (`Config.Inventory = 'auto'`) dans l'ordre : `ox_inventory`, `qs-inventory`, `qb-inventory`, sinon inventaire du framework.
  2. Fonctions : `Bridge.HasItem(src, name, metadata)`, `Bridge.GetItems(src, name)` (liste `{ slot, metadata }`), `Bridge.SetItemMetadata(src, slot, metadata)`, `Bridge.AddItem(src, name, count, metadata)`, `Bridge.RemoveItem(src, name, count, metadata)`, `Bridge.CanCarryItem(src, name, count)`, `Bridge.RegisterUsableItem(name, cb)`, `Bridge.InventoryHasMetadata()`.
  3. Détection ciblage (`Config.Target = 'auto'`) : `ox_target`, `qb-target`, sinon prompt natif. Fonctions : `Bridge.AddEntityTarget(entity, options)`, `Bridge.AddSphereZone(name, coords, radius, options)`, `Bridge.RemoveTarget(id)`.
  4. Prompt natif (sans ciblage) : texte d'aide GTA `~INPUT_CONTEXT~` affiché à moins de la distance de l'option ; la vérification de distance tourne toutes les 1000 ms et seulement tant qu'un point concerné existe à moins de 30 m (à chaque image seulement à moins de 2 m).
- **Données** : aucune.
- **Règles serveur** : les métadonnées sont toujours écrites par le serveur ; `RemoveItem` avec métadonnées retire exactement la tablette du numéro de série.
- **Textes et états** : aucun texte propre.
- **Notifications** : aucune.
- **Liens** : `BASE-OBJ-01`, `BASE-OBJ-03`, `BASE-OBJ-08`, `BASE-OBJ-10`, `BASE-OBJ-15`.
- **Réglages** : `Config.Inventory = 'auto'` · `Config.Target = 'auto'`.
- **Journal admin** : non.
- **Performance** : sans ciblage, la vérification de distance est adaptative et s'arrête quand aucun point n'est proche.
- **Cas limites** :
  - qs-inventory utilise `info` au lieu de `metadata` : le bridge convertit.
  - Inventaire du framework sans métadonnées : mode personnage (`BASE-OBJ-15`).
  - ox_target et qb-target tous deux présents : ox_target choisi.
- **Critères d'acceptation** :
  - Étant donné ox_inventory, quand une tablette est utilisée, alors sa métadonnée `serial` est lue et écrite par le bridge.
  - Étant donné l'absence de ciblage, quand le joueur s'approche d'une tablette posée, alors le prompt natif apparaît à 2 m.
  - Étant donné un client qui demande d'ajouter un objet, quand il appelle un événement, alors aucun événement client ne permet d'ajouter un objet (seul le serveur appelle `Bridge.AddItem`).

### [BASE-MOT-04] Sauvegarde des données (oxmysql, écritures groupées)
- **But** : écrire en base le moins souvent possible sans jamais perdre une donnée importante.
- **Qui** : système.
- **Où** : `server/storage.lua`.
- **Parcours** :
  1. **Écritures immédiates** (une requête tout de suite) : code de verrouillage, compteur d'échecs et blocage, paiements (`BASE-API-07`), réinitialisations, tout ce qu'une app déclare `critical = true`.
  2. **Écritures groupées** : réglages, batterie, ordre des icônes, notifications, journal, données d'apps non critiques. Elles sont placées dans une file en mémoire (`Dirty[table][clé] = valeur`, la dernière valeur gagne).
  3. Un minuteur `SetTimeout(10000)` est lancé quand la file passe de vide à non vide ; à son échéance, toutes les écritures sont envoyées en une transaction `MySQL.transaction` (insertions multiples par `INSERT ... VALUES (...), (...) ON DUPLICATE KEY UPDATE`). La file vide ne relance pas de minuteur.
  4. Vidage forcé : au `playerDropped` pour les données de ce joueur, à `onResourceStop` (attente synchrone `MySQL.transaction.await`, 5 s maximum), et quand la file dépasse 200 éléments.
  5. En cas d'échec SQL : les éléments restent dans la file, nouvel essai 10 s plus tard ; après 3 échecs, message console rouge et journal admin « échec de sauvegarde ».
- **Données** : file en mémoire, aucune table propre.
- **Règles serveur** : uniquement des requêtes préparées (paramètres `?`), jamais de concaténation de texte joueur dans une requête.
- **Textes et états** : messages console : « [pop_tablet] Save failed (%d items), retrying in 10s ».
- **Notifications** : aucune.
- **Liens** : `BASE-MOT-05`, `BASE-MOT-07`, `BASE-API-06`.
- **Réglages** : `Config.Storage.FlushInterval = 10` (secondes) · `Config.Storage.FlushMax = 200`.
- **Journal admin** : oui pour les échecs répétés.
- **Performance** : au plus une transaction toutes les 10 s, et aucune si rien n'a changé.
- **Cas limites** :
  - Arrêt brutal du serveur (crash) : perte au plus des 10 dernières secondes de données non critiques (accepté).
  - Même réglage modifié 5 fois en 10 s : une seule écriture.
  - Base indisponible au démarrage : la ressource attend oxmysql (`MySQL.ready`) avant d'ouvrir les tablettes ; message « Base de données indisponible. Réessayez dans un instant. » `commun.erreur.bdd` si un joueur ouvre trop tôt.
- **Critères d'acceptation** :
  - Étant donné 20 joueurs qui changent leurs réglages en 10 s, quand le minuteur expire, alors une seule transaction est envoyée.
  - Étant donné un `restart pop_tablet`, quand la ressource s'arrête, alors la file est vidée en base avant l'arrêt.
  - Étant donné un texte joueur contenant `'; DROP TABLE users; --`, quand il est sauvegardé, alors il est stocké tel quel comme texte, sans effet sur la base.

### [BASE-MOT-05] Cache serveur
- **But** : garder en mémoire ce qui est souvent lu pour éviter des requêtes SQL répétées.
- **Qui** : système, utilisable par les apps via `BASE-API-06`.
- **Où** : `server/cache.lua`.
- **Parcours** :
  1. Entrées en cache, avec leur durée de vie :
| Contenu | Chargé | Durée | Invalidé quand |
|---|---|---|---|
| Fiche appareil (`pop_tablet_devices`) | à la 1re ouverture | jusqu'à 10 min après la dernière fermeture | réinitialisation, écriture |
| Liste des apps enregistrées | au démarrage | permanente | enregistrement / retrait |
| Apps autorisées par joueur | à l'ouverture | jusqu'au changement de métier | `OnJobChange`, retrait d'app |
| Possession de l'objet | à la demande | 10 s | `RemoveItem` via le bridge |
| Métiers et grades (`GetJobs`) | au démarrage | 5 min | `esx:refreshJobs` si émis |
| Langues | au démarrage | permanente | — |
| Données d'apps portée `global` et `job` | à la 1re lecture | 10 min sans lecture | écriture via l'API |
  2. Fonctions internes : `Cache.Get(ns, key)`, `Cache.Set(ns, key, value, ttl)`, `Cache.Invalidate(ns, key)`, `Cache.InvalidateNs(ns)`.
  3. Le nettoyage des entrées expirées se fait à la lecture (expiration paresseuse) et par un passage unique toutes les 5 minutes **seulement si le cache contient au moins une entrée avec durée de vie**.
- **Données** : tables Lua en mémoire `{ value, expires }`.
- **Règles serveur** : toute écriture passe par le cache puis par la file (`BASE-MOT-04`) pour rester cohérente ; taille maximale 20 000 entrées, au-delà les plus anciennes lues sont retirées.
- **Textes et états** : aucun.
- **Notifications** : aucune.
- **Liens** : `BASE-MOT-04`, `BASE-API-06`.
- **Réglages** : `Config.Cache.DeviceTTL = 600` · `Config.Cache.AppDataTTL = 600` · `Config.Cache.MaxEntries = 20000`.
- **Journal admin** : non.
- **Performance** : lecture en O(1) ; aucun minuteur quand le cache n'a rien d'expirable.
- **Cas limites** :
  - Deux ressources modifient la même donnée : la dernière écriture gagne, le cache reflète toujours la dernière valeur écrite par l'API.
  - Modification directe en base par un admin (phpMyAdmin) : visible après expiration du cache ou `/tablette_cache clear` (ACE admin).
  - Mémoire : 20 000 entrées maximum.
- **Critères d'acceptation** :
  - Étant donné une fiche appareil en cache, quand le joueur rouvre la tablette, alors aucune requête SQL n'est faite.
  - Étant donné un changement de métier, quand le joueur ouvre la tablette, alors la liste des apps est recalculée.
  - Étant donné un joueur non admin qui tape `/tablette_cache clear`, quand le serveur reçoit, alors il refuse.

### [BASE-MOT-06] Limites réglables
- **But** : regrouper dans `config.lua` toutes les limites chiffrées, avec des valeurs par défaut sûres.
- **Qui** : propriétaire du serveur (fichier `config.lua`).
- **Où** : `config.lua`, section `Config.Limits` (et sections citées).
- **Parcours** :
  1. Le moteur lit les limites au démarrage et les applique partout ; les apps lisent les leurs via `exports.pop_tablet:GetLimit(cle)`.
  2. Valeurs par défaut :
| Clé | Défaut | Sens |
|---|---|---|
| `Config.Limits.PageSize` | 20 | éléments par page |
| `Config.Limits.TextShort` | 60 | titre, nom |
| `Config.Limits.TextMedium` | 255 | description courte |
| `Config.Limits.TextLong` | 4000 | rapport, note |
| `Config.Limits.MaxAmount` | 100000 | montant maximal d'une action d'argent |
| `Config.Limits.NearDistance` | 3.0 | distance « joueur proche » en mètres |
| `Config.Limits.AppDataValue` | 16384 | octets par valeur stockée |
| `Config.Limits.AppDataKeys` | 2000 | clés par app et par portée |
| `Config.Limits.UrlLength` | 300 | longueur d'un lien d'image |
| `Config.Limits.ActionIdMemory` | 600 | secondes de mémoire des `actionId` |
  3. Au démarrage, chaque valeur est vérifiée (type, plage) ; une valeur invalide est remplacée par le défaut avec un avertissement console « [pop_tablet] Config.Limits.%s invalid, using %s ».
- **Données** : aucune en base.
- **Règles serveur** : les limites sont toujours lues côté serveur ; la NUI reçoit une copie (pour afficher les compteurs de caractères) mais n'est pas crue.
- **Textes et états** : compteur de caractères dans les champs : « %d / %d » `base.commun.compteur`.
- **Notifications** : aucune.
- **Liens** : toutes les apps.
- **Réglages** : ceux du tableau.
- **Journal admin** : non.
- **Performance** : lecture unique au démarrage.
- **Cas limites** :
  - `PageSize = 500` : plafonné à 100.
  - `MaxAmount = -5` : remplacé par 100000.
  - Clé absente : défaut.
- **Critères d'acceptation** :
  - Étant donné `PageSize = 10`, quand le joueur ouvre l'historique, alors il voit 10 éléments par page.
  - Étant donné `MaxAmount = 5000`, quand une app demande un paiement de 6000, alors il est refusé.
  - Étant donné un client qui envoie un texte de 10 000 caractères dans un champ court, quand le serveur reçoit, alors il refuse avec `invalide`.

### [BASE-MOT-07] Journal des actions (admin)
- **But** : garder une trace de chaque action sensible : qui, quoi, quand, avant/après.
- **Qui** : écrit par le moteur et les apps ; lu par l'admin (app Admin, branche Admin).
- **Où** : `server/log.lua` ; fonction `exports.pop_tablet:Log(entry)`.
- **Parcours** :
  1. Un module appelle `Log({ source, app, action, category, target, targetIdentifier, companyId, summary, before, after, level })` (seule fonction de journal de toute la tablette : `Journal.Ecrire` du fichier 02, `AdminLog` du fichier 04, RC8 du fichier 03 et `PopTablet.Log.add` du fichier 05 désignent cette fonction ; le « type » du fichier 05 = `action`).
  2. Le serveur complète : identifiant et nom RP de l'acteur (ou « Console »), date, ressource appelante (`GetInvokingResource()`).
  3. L'entrée est ajoutée à la file groupée (`BASE-MOT-04`) et, si sa catégorie est activée, à la file Discord (`BASE-MOT-08`).
  4. Les entrées ne sont jamais modifiées ; suppression seulement si `Config.Log.RetentionDays > 0` (nettoyage au démarrage), défaut 0 = jamais.
- **Données** (`pop_tablet_logs`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| id | BIGINT auto | Oui | — | — |
| created_at | INT UNSIGNED, index | Oui | — | `os.time()` |
| actor_identifier | VARCHAR(64), index | Non | NULL = console | — |
| actor_name | VARCHAR(80) | Oui | — | — |
| app | VARCHAR(32), index | Oui | — | — |
| action | VARCHAR(48) | Oui | — | — |
| target | VARCHAR(120) | Non | — | NULL |
| target_identifier | VARCHAR(64), index | Non | joueur visé | NULL |
| target_name | VARCHAR(80) | Non | — | NULL |
| company_id | INT, index | Non | entreprise concernée (`pop_tablet_companies.id`) | NULL |
| summary | VARCHAR(255) | Non | résumé lisible (filtres du journal, `ADM-07`) | NULL |
| category | VARCHAR(20) | Oui | `admin`, `money`, `alert`, `police`, `service`, `triche`… (catégories Discord) | `admin` |
| before_data | TEXT JSON | Non | ≤ 8 Ko | NULL |
| after_data | TEXT JSON | Non | ≤ 8 Ko | NULL |
| level | ENUM('info','warn','alert') | Oui | — | `info` |
| resource | VARCHAR(64) | Oui | — | `pop_tablet` |
- **Règles serveur** : jamais de code de verrouillage, mot de passe ou lien Discord dans le journal ; `before`/`after` coupés à 8 Ko ; un joueur ne peut pas écrire au journal depuis le client (export serveur uniquement).
- **Textes et états** : les libellés d'actions sont des clés `log.<app>.<action>` traduites dans l'app Admin.
- **Notifications** : aucune (alertes Discord à part).
- **Liens** : `BASE-MOT-08`, app Admin.
- **Réglages** : `Config.Log.Enabled = true` · `Config.Log.RetentionDays = 0` · `Config.Log.Open = false`.
- **Journal admin** : c'est la fonctionnalité.
- **Performance** : écritures groupées ; index `(created_at)`, `(actor_identifier)`, `(app)` pour la recherche paginée côté Admin.
- **Cas limites** :
  - 1 000 entrées en 10 s : une transaction, insertions par paquets de 200.
  - `before` contenant une table circulaire : remplacé par `"[non sérialisable]"`.
  - Journal désactivé : les appels sont ignorés sans erreur.
- **Critères d'acceptation** :
  - Étant donné une réinitialisation admin, quand l'admin ouvre le journal, alors il voit l'admin, le numéro de série, la date et l'état avant.
  - Étant donné un changement de code, quand il est journalisé, alors le code n'apparaît nulle part.
  - Étant donné un client qui déclenche un événement pour écrire au journal, quand il essaie, alors aucun événement réseau ne le permet.

### [BASE-MOT-08] Envoi du journal sur Discord
- **But** : recevoir les actions sensibles dans un salon Discord du staff.
- **Qui** : propriétaire du serveur (configuration) ; personne d'autre.
- **Où** : `server/discord.lua` ; convars dans `server.cfg`.
- **Parcours** :
  1. Le lien est lu au démarrage : `GetConvar('pop_tablet_webhook', '')` ; liens par catégorie facultatifs `pop_tablet_webhook_money`, `pop_tablet_webhook_admin`, `pop_tablet_webhook_police`.
  2. Catégories envoyées par défaut : `admin` (actions admin), `money` (paiements, réinitialisations payantes), `alert` (niveau `alert` : triche suspectée, échecs de sauvegarde).
  3. Les entrées sont mises en file et envoyées par `PerformHttpRequest` en messages de 10 embeds maximum, toutes les 5 s tant que la file n'est pas vide (minuteur arrêté quand elle est vide).
  4. Embed : titre « %app% · %action% », couleur = accent du serveur, champs « Qui », « Cible », « Avant », « Après » (coupés à 1 000 caractères), pied « pop_tablet » + date.
  5. Réponse 429 (trop de messages) : attente du délai indiqué par Discord (`retry_after`) puis nouvel envoi.
- **Données** : file en mémoire.
- **Règles serveur** : lien jamais envoyé au client ni écrit dans un journal ; aucun envoi si le lien est vide.
- **Textes et états** : embed en langue du serveur (`Config.Locale`) ; « Qui » `base.discord.qui` · « Cible » `base.discord.cible` · « Avant » `base.discord.avant` · « Après » `base.discord.apres`.
- **Notifications** : aucune.
- **Liens** : `BASE-MOT-07`.
- **Réglages** : `Config.Discord.Categories = { admin = true, money = true, alert = true, police = false }` · `Config.Discord.Interval = 5`. Convars : `pop_tablet_webhook`, `pop_tablet_webhook_<categorie>`.
- **Journal admin** : non (c'est la sortie du journal).
- **Performance** : minuteur seulement quand la file n'est pas vide ; au plus 12 messages par minute.
- **Cas limites** :
  - Lien invalide (404) : message console une fois par heure, la file est vidée pour ne pas gonfler.
  - 500 entrées d'un coup : envoyées par paquets de 10, à raison d'un message toutes les 5 s ; au-delà de 1 000 en attente, les plus anciennes de niveau `info` sont abandonnées.
  - Lien placé par erreur dans `config.lua` : ignoré, avertissement console « Put the webhook in server.cfg ».
- **Critères d'acceptation** :
  - Étant donné un lien configuré, quand un admin réinitialise une tablette, alors un embed arrive sur Discord en moins de 10 s.
  - Étant donné aucun lien, quand des actions ont lieu, alors aucune requête HTTP n'est faite.
  - Étant donné un client qui cherche le lien dans les fichiers NUI ou les événements, quand il inspecte, alors le lien n'apparaît nulle part.

### [BASE-MOT-09] Kit de style
- **But** : donner à toutes les apps (officielles et « mes apps ») le même aspect sobre sans réécrire de CSS.
- **Qui** : développeurs d'apps (fichiers ouverts).
- **Où** : `web/kit/pop.css`, `web/kit/pop.js`, documenté dans `docs/kit.md`.
- **Parcours** :
  1. Variables CSS (sur `:root` de la tablette, recopiées dans chaque iframe d'app au chargement) :
| Variable | Valeur |
|---|---|
| `--pt-bg` | `#0E0F12` |
| `--pt-surface` | `#17191E` |
| `--pt-surface-2` | `#1F2228` |
| `--pt-border` | `#2A2E36` |
| `--pt-text` | `#FFFFFF` |
| `--pt-text-2` | `#A3A8B3` |
| `--pt-accent` | réglage du joueur (`#4FA3FF`) |
| `--pt-danger` | `#E5484D` |
| `--pt-warning` | `#F5A524` |
| `--pt-success` | `#3FB950` |
| `--pt-radius` | `8px` |
| `--pt-font` | `system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif` |
| `--pt-font-size` | `15px` (réglage taille du texte) |
| `--pt-fade` | `150ms` |
| espacements | `--pt-s1` 4px · `--pt-s2` 8px · `--pt-s3` 12px · `--pt-s4` 16px · `--pt-s5` 24px |
  2. Composants (classes) : `.pt-btn` (+ `--primary` fond accent texte noir/blanc selon contraste, `--ghost`, `--danger`), `.pt-input`, `.pt-select`, `.pt-textarea` (avec compteur), `.pt-list` / `.pt-list-item`, `.pt-card`, `.pt-badge`, `.pt-tabs`, `.pt-table` (en-tête collant), `.pt-modal` (confirmation), `.pt-toast`, `.pt-pager`, `.pt-skeleton`, `.pt-empty`, `.pt-search`.
  3. Fonctions `pop.js` : `Pop.request(action, data)`, `Pop.text(el, str)` (insertion texte sûre), `Pop.confirm(texte, libelleOk)` (promesse), `Pop.toast(texte, type)`, `Pop.state(el, etat, options)` (`BASE-MOT-10`), `Pop.t(cle, params)` (traduction), `Pop.formatMoney(n)`, `Pop.formatDate(ts)`, `Pop.paginate(el, total, page, onChange)`.
  4. Règles visuelles : aucun dégradé, aucun `backdrop-filter`, aucune ombre portée au-delà de `0 1px 0` ; une seule transition `opacity var(--pt-fade)` ; focus clavier visible (contour 2 px accent) ; zones cliquables ≥ 32 px.
- **Données** : aucune.
- **Règles serveur** : aucune.
- **Textes et états** : textes génériques du kit : « Annuler » `base.commun.annuler` · « Confirmer » `base.commun.confirmer` · « Enregistrer » `base.commun.enregistrer` · « Rechercher… » `base.commun.rechercher` · « Page %d sur %d » `base.commun.page`.
- **Notifications** : aucune.
- **Liens** : `BASE-MOT-10`, `BASE-API-01`, `BASE-ECR-12`, `BASE-ECR-14`.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : `pop.css` ≤ 25 Ko, `pop.js` ≤ 20 Ko, sans dépendance externe ni police téléchargée.
- **Cas limites** :
  - App tierce sans le kit : fonctionne, mais l'aspect n'est pas garanti (documenté).
  - Accent clair (blanc, jaune) : texte des boutons principaux en `#0E0F12` (calcul de contraste dans `pop.js`).
  - Taille « Grand » : composants en `rem`, rien ne déborde à 1180 × 760.
- **Critères d'acceptation** :
  - Étant donné une app d'exemple utilisant `.pt-btn--primary`, quand le joueur change d'accent, alors le bouton change de couleur.
  - Étant donné `Pop.text(el, '<img onerror=alert(1)>')`, quand il est appelé, alors le texte apparaît tel quel sans exécution.
  - Étant donné une app qui essaie d'utiliser `innerHTML` avec un texte joueur, quand l'auditeur relit, alors c'est refusé (règle du guide).

### [BASE-MOT-10] Les 6 états d'écran
- **But** : chaque écran de chaque app gère de la même façon le vide, le chargement, le succès, l'erreur, le « pas le droit » et le « hors service ».
- **Qui** : toutes les apps ; développeurs via `Pop.state`.
- **Où** : `web/kit/pop.js` > `Pop.state(el, etat, options)`.
- **Parcours** :
  1. **Vide** : `Pop.state(el, 'empty', { text, action: { label, onClick } })` → icône discrète, phrase, bouton principal pour commencer.
  2. **Chargement** : `Pop.state(el, 'loading', { rows = 5 })` → formes grises (`.pt-skeleton`, pulsation d'opacité 0,5 ↔ 0,8 sur 1 s, désactivée si `prefers-reduced-motion`). Après 5 s sans réponse : « Ça prend plus de temps que prévu. » + bouton « Réessayer » qui relance la dernière demande.
  3. **Succès** : `Pop.toast(texte, 'success')` → bandeau en haut de l'écran, 2 s, bord gauche vert.
  4. **Erreur** : `Pop.state(el, 'error', { code })` ou `Pop.toast(texte, 'error')` → message clair traduit depuis le code, bouton « Réessayer » si l'erreur est `serveur` ou `reseau`.
  5. **Pas le droit** : élément caché (actions) ou grisé avec info-bulle « Grade requis : %s » selon l'option `{ mode = 'hide' | 'disable', grade }` ; écran entier : `Pop.state(el, 'forbidden', { grade })`.
  6. **Hors service** (apps métier) : `Pop.state(el, 'offduty')` → écran grisé, seul le bouton « Prendre mon service » est actif ; il appelle l'action de prise de service de la branche Entreprises.
  7. Un délai de demande maximal de 15 s s'applique : au-delà, erreur `serveur`.
- **Données** : aucune.
- **Règles serveur** : le serveur reste la référence (un bouton visible n'autorise rien).
- **Textes et états** :
  - « Ça prend plus de temps que prévu. » `base.etat.lent` · « Réessayer » `base.commun.reessayer`
  - « Grade requis : %s » `base.etat.grade` · « Accès refusé. » `base.etat.interdit`
  - « Hors service. » `base.etat.hors_service` · « Prendre mon service » `base.etat.prendre_service`
  - « C'est fait. » `base.etat.succes` (texte de succès générique quand l'app n'en donne pas)
- **Notifications** : aucune.
- **Liens** : `BASE-MOT-09` ; branche Entreprises (prise de service).
- **Réglages** : `Config.UI.SlowAfter = 5000` · `Config.UI.RequestTimeout = 15000`.
- **Journal admin** : non.
- **Performance** : aucun coût hors écran affiché.
- **Cas limites** :
  - Réponse qui arrive après le délai de 15 s : ignorée par la NUI (identifiant de demande périmé).
  - Changement de service pendant que l'écran est en « Hors service » : l'écran se recharge automatiquement.
  - Deux erreurs successives : un seul bandeau (le dernier remplace le précédent).
- **Critères d'acceptation** :
  - Étant donné une liste vide, quand l'écran s'affiche, alors la phrase et le bouton pour commencer apparaissent.
  - Étant donné un serveur qui met 6 s à répondre, quand 5 s passent, alors « Ça prend plus de temps que prévu. » et « Réessayer » apparaissent.
  - Étant donné un bouton grisé réactivé par un client modifié, quand le joueur clique, alors le serveur refuse avec `pas_droit`.

### [BASE-MOT-11] Anti-spam (limite de fréquence)
- **But** : empêcher un joueur de surcharger le serveur ou d'abuser d'une action.
- **Qui** : système, toutes les actions.
- **Où** : `server/ratelimit.lua`, appelé par `BASE-MOT-01`.
- **Parcours** :
  1. Chaque action a une limite `{ n, s }` (n demandes par s secondes) ; défaut 5 par 10 s ; plus une limite globale par joueur de 30 demandes par 10 s.
  2. Le compteur est une fenêtre glissante simple : liste des horodatages (en millisecondes `GetGameTimer()`) par joueur et par action, on retire ceux plus vieux que s.
  3. Dépassement : refus `trop_vite`, la NUI affiche le message une fois (pas de cumul de bandeaux).
  4. Plus de 3 dépassements en 60 s : entrée au journal niveau `alert` « fréquence anormale » (joueur, action, nombre) ; aucune sanction automatique (`Config.RateLimit.KickOnAbuse = false`).
  5. Les compteurs d'un joueur sont supprimés à sa déconnexion.
- **Données** : mémoire `Rate[source][action] = { horodatages }`.
- **Règles serveur** : valeurs lues côté serveur ; une app peut demander une limite plus stricte mais pas plus large que `Config.RateLimit.MaxPerAction = { n = 40, s = 10 }`.
- **Textes et états** : `commun.erreur.trop_vite`.
- **Notifications** : aucune.
- **Liens** : `BASE-MOT-01`, `BASE-MOT-07`.
- **Réglages** : `Config.RateLimit.Default = { n = 5, s = 10 }` · `Config.RateLimit.Global = { n = 60, s = 10 }` · `Config.RateLimit.MaxPerAction = { n = 40, s = 10 }` (une fiche peut fixer sa propre limite par action dans ce plafond, ex. tableur 20 / 5 s) · `Config.RateLimit.KickOnAbuse = false`.
- **Journal admin** : oui pour les abus (au plus une entrée par minute et par joueur).
- **Performance** : listes courtes (≤ 20 valeurs) par action ; libérées à la déconnexion.
- **Cas limites** :
  - Recherche en tapant (une demande par frappe) : la NUI attend 300 ms après la dernière frappe avant d'envoyer, pour rester sous la limite.
  - Macro qui envoie 100 demandes par seconde : 5 acceptées, le reste refusé, une alerte au journal.
  - `KickOnAbuse = true` : expulsion avec le motif « Trop de demandes envoyées à la tablette. » `base.antispam.kick` au 10e dépassement en 60 s.
- **Critères d'acceptation** :
  - Étant donné 6 demandes de la même action en 2 s, quand la 6e arrive, alors elle est refusée avec `trop_vite`.
  - Étant donné 10 s d'attente, quand le joueur recommence, alors la demande passe.
  - Étant donné un script de triche qui envoie 1 000 demandes, quand le serveur les reçoit, alors au plus 30 sont exécutées en 10 s et une alerte est journalisée.

### [BASE-MOT-12] Nettoyage des textes
- **But** : aucun texte écrit par un joueur ne peut exécuter du code ou casser l'affichage.
- **Qui** : système, tous les champs texte de toutes les apps.
- **Où** : serveur `Sanitize.text(str, max)` appelé par `BASE-MOT-01` selon le schéma ; NUI `Pop.text()`.
- **Parcours** :
  1. Côté serveur, pour chaque champ de type `text` du schéma :
     1. conversion en chaîne, refus si ce n'est pas une chaîne ou un nombre ;
     2. suppression des caractères de contrôle (sauf saut de ligne pour les champs `multiline`), des caractères invisibles (U+200B à U+200F, U+202A à U+202E, U+2066 à U+2069, U+FEFF) ;
     3. suppression des codes couleur GTA (`~r~`, `~b~`, `^1`…) ;
     4. espaces en début et fin retirés, suites de plus de 2 sauts de ligne réduites à 2 ;
     5. refus si la longueur (en caractères UTF-8) dépasse la limite du champ (`trop_long`) — jamais de coupure silencieuse côté serveur ; la NUI empêche de taper ou de coller au-delà de la limite (`maxlength`) ;
     6. filtrage des mots interdits de `Config.Text.BannedWords` (remplacés par `***`).
  2. Le texte est stocké tel quel après nettoyage (pas d'échappement HTML en base).
  3. Côté NUI, tout texte venant d'un joueur est affiché uniquement par `textContent` (`Pop.text`) ; `innerHTML` est interdit pour ces textes (règle d'audit).
  4. Les apps qui affichent du texte mis en forme (sites web, branche Sites) utilisent leur propre liste blanche, hors base.
- **Données** : aucune.
- **Règles serveur** : nettoyage avant toute écriture et toute notification ; les noms de joueurs venant du framework passent aussi par le nettoyage avant affichage.
- **Textes et états** : `commun.erreur.invalide` ; « Ce texte est trop long (%d caractères maximum). » `base.texte.trop_long` (la NUI l'affiche sous le champ avant même l'envoi).
- **Notifications** : aucune.
- **Liens** : `BASE-MOT-01`, `BASE-MOT-09`, `BASE-ECR-04`.
- **Réglages** : `Config.Text.BannedWords = {}` · `Config.Text.StripGtaColors = true`.
- **Journal admin** : non (sauf refus répétés via `BASE-MOT-01`).
- **Performance** : traitement par motifs Lua, en une passe par champ.
- **Cas limites** :
  - Emoji : conservés (comptés comme des caractères).
  - Texte `<script>alert(1)</script>` : stocké tel quel, affiché comme du texte visible.
  - Texte composé uniquement d'espaces dans un champ obligatoire : vide après nettoyage → `invalide`.
- **Critères d'acceptation** :
  - Étant donné le titre `~r~ARGENT`, quand il est enregistré, alors il devient `ARGENT`.
  - Étant donné un texte de 61 caractères dans un champ de 60, quand la NUI l'affiche, alors le message « trop long » apparaît et l'envoi est bloqué.
  - Étant donné un client modifié qui envoie `<img src=x onerror=...>`, quand un autre joueur le voit, alors rien ne s'exécute.

### [BASE-MOT-13] Rien ne tourne quand la tablette est fermée
- **But** : garantir une consommation de ressources nulle tablette fermée (esprit « ~0,00 ms »).
- **Qui** : système ; vérifié par l'auditeur.
- **Où** : tout le code client et serveur.
- **Parcours** :
  1. Tablette fermée, côté client, il n'existe que : la commande et le key mapping, les gestionnaires d'événements (`AddEventHandler`, `RegisterNetEvent`), les callbacks NUI ; aucun `CreateThread` actif, aucun `SetTimeout` en attente.
  2. Créés à l'ouverture et détruits à la fermeture : vérification des conditions (500 ms, `BASE-OBJ-16`), minuterie d'heure (2 s), estimation de batterie (60 s), animation et prop.
  3. Exceptions autorisées, toutes déclenchées par un événement et arrêtées seules : spectateurs proches d'une tablette posée, barre de progression du chargeur, bandeaux de notification (minuterie JavaScript par bandeau).
  4. Côté serveur, tablette fermée par tous : aucun minuteur sauf ceux qui s'arrêtent quand leur file est vide (sauvegarde, Discord, tablettes posées, nettoyage du cache).
  5. La NUI cachée ne garde aucun `setInterval` ; les écrans d'apps sont détruits (iframes retirées du DOM) à la fermeture.
- **Données** : aucune.
- **Règles serveur** : aucune boucle `while true` sans condition de sortie liée à l'état ouvert ; aucun `Wait(0)` permanent.
- **Textes et états** : aucun.
- **Notifications** : aucune.
- **Liens** : toutes les fiches.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : cible `resmon` : 0,00 ms client tablette fermée ; ≤ 0,05 ms client tablette ouverte ; 0,00 ms serveur au repos.
- **Cas limites** :
  - Ouverture/fermeture 50 fois de suite : aucun fil ne reste actif (compteur de fils de debug à 0, voir critère).
  - Redémarrage de ressource tablette ouverte : tout est arrêté par `onResourceStop`.
  - Joueur mort tablette ouverte : fermeture, donc arrêt des fils.
- **Critères d'acceptation** :
  - Étant donné la tablette fermée, quand on lit `resmon 1`, alors `pop_tablet` affiche 0,00 ms côté client.
  - Étant donné `Config.Debug = true`, quand la tablette est fermée, alors la commande `/tablette_debug` affiche « Fils actifs : 0 ».
  - Étant donné un client qui force l'envoi d'événements d'ouverture sans objet, quand le serveur refuse, alors aucun fil n'est créé côté client (les fils sont créés seulement à la réception de `pop_tablet:client:open`).

### [BASE-MOT-14] Fenêtre simple pour les joueurs sans tablette
- **But** : un joueur sans tablette (ou avec une tablette vide) peut quand même accepter, refuser ou payer un devis, une facture ou une amende.
- **Qui** : tout joueur destinataire d'un document qui n'a pas l'objet tablette, ou dont la tablette est à 0 %.
- **Où** : carte NUI hors tablette, en bas au centre de l'écran (440 px de large).
- **Parcours** :
  1. Une app (Factures, Police, Mécano) appelle `exports.pop_tablet:OfferDocument(target, doc)` côté serveur.
  2. Le serveur regarde si le destinataire a une tablette utilisable : oui → notification tablette normale (`BASE-ECR-04`) avec lien vers le document ; non → fenêtre simple.
  3. Si le destinataire est mort ou inconscient (`Bridge.IsDead`) : le document est mis en attente et présenté à son réveil (événement de réanimation du bridge, ou au plus tard à la prochaine ouverture de session de jeu).
  4. Fenêtre : type (« Facture », « Devis », « Amende »), émetteur (nom de l'entreprise ou service), montant en grand, motif (3 lignes max, « Voir le détail » déplie les lignes du devis), date. En bas : « Payer » (facture, amende) ou « Accepter » (devis), et « Refuser » (facture, devis ; l'amende n'a pas de « Refuser » mais « Plus tard »). Info : « Y pour répondre ».
  5. La fenêtre s'affiche sans focus ; la touche `Y` (key mapping `+poptablet_doc`, réglable) donne le focus à la carte ; Échap rend le focus sans répondre.
  6. Réponse : le client envoie `pop_tablet:docAnswer` `{ docId, answer }` ; le serveur vérifie que le document est bien adressé à ce joueur et toujours en attente, puis appelle le gestionnaire de l'app émettrice (`doc.onAnswer(source, answer)`), qui fait le paiement via `BASE-API-07`.
  7. Résultat affiché 2 s dans la carte puis document suivant (file de 5 maximum ; au-delà, « Autres documents en attente » et la file reprend après).
  8. Sans réponse en 120 s : la carte se replie en petit rappel (« 1 document en attente · Y ») ; une facture ou une amende non payée reste impayée dans son app d'origine ; un devis sans réponse expire (`onAnswer(source, 'expired')`).
  9. À la connexion, si des documents impayés lui sont adressés et qu'il n'a pas de tablette : rappel « %d document(s) en attente. Y pour afficher. ».
- **Données** (doc envoyé par l'app, gardé en mémoire `PendingDocs[identifier]`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| id | chaîne | Oui | unique, ≤ 40 | — |
| type | `invoice` \| `quote` \| `fine` | Oui | — | — |
| issuer | chaîne | Oui | ≤ 60 | — |
| amount | entier | Oui | 1 à `Config.Limits.MaxAmount` | — |
| reason | chaîne | Oui | ≤ 255 | — |
| lines | liste `{ label, qty, price }` | Non | ≤ 20 lignes | {} |
| onAnswer | fonction serveur | Oui | — | — |
| expires | secondes | Non | 30 à 600 | 120 |
- **Règles serveur** : document lié à l'identifiant du destinataire, réponse acceptée une seule fois (verrou par `id`) ; argent vérifié et prélevé par le serveur ; montant jamais lu depuis le client ; distance non requise pour répondre (le document est déjà émis) ; 1 réponse par seconde.
- **Textes et états** :
  - « Facture » `base.doc.facture` · « Devis » `base.doc.devis` · « Amende » `base.doc.amende`
  - « Payer » `base.doc.payer` · « Accepter » `base.doc.accepter` · « Refuser » `base.doc.refuser` · « Plus tard » `base.doc.plus_tard` · « Voir le détail » `base.doc.detail`
  - « %s pour répondre » `base.doc.touche`
  - Succès : « Paiement effectué. » `base.doc.paye` · « Devis accepté. » `base.doc.accepte` · « Refusé. » `base.doc.refuse`
  - « Fonds insuffisants. » `base.doc.pas_argent`
  - « Ce document n'est plus valable. » `base.doc.expire`
  - « %d document(s) en attente. %s pour afficher. » `base.doc.attente`
- **Notifications** : à l'émetteur, par l'app d'origine (pas par la base).
- **Liens** : app Factures, Police (amendes), Mécano (devis) ; `BASE-API-07`, `BASE-API-09`.
- **Réglages** : `Config.Docs.Enabled = true` · `Config.Docs.Key = 'Y'` · `Config.Docs.Timeout = 120` · `Config.Docs.QueueMax = 5` · `Config.Docs.Account = 'bank'` (compte prélevé, repli `money` si `Config.Docs.FallbackCash = true`).
- **Journal admin** : oui, réponse à un document (joueur, document, réponse, montant).
- **Performance** : aucune boucle ; minuterie de 120 s par carte affichée seulement.
- **Cas limites** :
  - Joueur inconscient : document en attente, présenté à la réanimation.
  - Double appui sur « Payer » : verrou par `id`, un seul paiement.
  - Le joueur ramasse une tablette entre-temps : la carte reste valable jusqu'à sa réponse ; le document apparaît aussi dans la tablette (un seul paiement possible).
  - Déconnexion avec une carte affichée : les documents impayés restent dans leur app d'origine, rappel à la reconnexion.
- **Critères d'acceptation** :
  - Étant donné un joueur sans tablette qui reçoit une amende de 500 $, quand il appuie sur Y puis « Payer », alors 500 $ sont prélevés et l'amende est marquée payée.
  - Étant donné un joueur inconscient, quand une facture lui est envoyée, alors la carte apparaît seulement après sa réanimation.
  - Étant donné un tricheur qui envoie `docAnswer` pour le document d'un autre joueur, quand le serveur reçoit, alors il refuse et rien n'est payé.

### [BASE-MOT-15] Assistant de premier démarrage pour l'admin
- **But** : rendre la tablette prête en 5 minutes en détectant l'installation et en reliant les métiers du framework (ESX, QBCore ou Qbox) aux entreprises par défaut.
- **Qui** : admin (ACE `pop.tablet.admin`).
- **Où** : s'ouvre automatiquement à la première ouverture de la tablette par un admin tant que la configuration n'est pas terminée ; relançable avec `/tablette_setup` ou Réglages > « Assistant d'installation » (visible seulement pour l'admin).
- **Parcours** :
  1. Au démarrage du serveur, si `pop_tablet_meta.setup_done` est absent, la console affiche : « [pop_tablet] Première installation : connectez-vous avec un compte admin et ouvrez la tablette (ou tapez /tablette_setup). ».
  2. **Étape 1 « Détection »** : le serveur renvoie une liste avec un statut (vert = trouvé, gris = absent, rouge = obligatoire absent) : framework et version, oxmysql (obligatoire), inventaire, métadonnées oui/non, ciblage, ox_lib, screencapture, adaptateur banque personnalisé (`bridge/bank/custom.lua`, absent par défaut), objets `pop_tablet` et `pop_tablet_charger` déclarés (ESX : ligne dans la table `items` ; QBCore : `QBCore.Shared.Items['pop_tablet']` ; ox_inventory, utilisé par Qbox : `exports.ox_inventory:Items('pop_tablet')` ; qs-inventory : `exports['qs-inventory']:GetItemList()`).
  3. Si un objet est absent : ESX (table `items`) → bouton « Créer l'objet » qui insère `pop_tablet` et `pop_tablet_charger` dans `items` ; ox_inventory → bloc à copier dans `ox_inventory/data/items.lua` ; QBCore (qb-inventory) → bloc à copier dans `qb-core/shared/items.lua` ; qs-inventory → bloc à copier dans `qs-inventory/shared/items.lua` ; chaque bloc avec bouton « Copier » (la ressource n'écrit jamais dans les fichiers d'une autre ressource). La vente de ces objets reste au script de boutique du serveur (`BASE-OBJ-18`, supprimée).
  4. **Étape 2 « Métiers »** : liste des métiers du framework (`Bridge.GetJobs()` : ESX tables `jobs` / `job_grades`, QBCore `QBCore.Shared.Jobs`, Qbox `exports.qbx_core:GetJobs()` ; hors `unemployed`). Pour chacun, une proposition pré-cochée si le nom correspond à un modèle connu :
| Métier (nom contient) | Entreprise proposée |
|---|---|
| `police`, `sheriff`, `lspd`, `bcso` | Police (MDT) |
| `ambulance`, `ems`, `doctor` | EMS |
| `mechanic`, `bennys`, `lsc` | Mécano |
| `judge`, `justice`, `lawyer`, `avocat` | Justice |
| `taxi`, `realestateagent`, `cardealer`, autres | Entreprise générique |
  Le joueur peut décocher ou changer le modèle par liste déroulante. Les grades sont répartis automatiquement en Recrue / Membre / Chef / Patron (le plus bas = Recrue, le plus haut = Patron, intermédiaires coupés en deux moitiés, la moitié basse Membre, la haute Chef) ; tableau modifiable grade par grade.
  5. **Étape 3 « Justice »** (Tribunal et Cabinet d'avocats, qui n'existent pas sur tous les serveurs) : pour chacune des deux entreprises par défaut, le serveur cherche un métier existant parmi ses candidats (`SITE-CRE-01` : Tribunal `justice`, `judge`, `doj` ; Cabinet d'avocats `avocat`, `lawyer`).
     - Trouvé : ligne « Tribunal : relié au métier {metier} » `base.setup.justice_trouve`, cochée.
     - Absent : ligne « Tribunal : aucun métier trouvé » `base.setup.justice_absent` avec trois choix : « Créer le métier » `base.setup.justice_creer` (présélectionné ; crée le métier `justice` ou `avocat` avec les grades par défaut de `SITE-CRE-01`, par le même mécanisme que `SITE-CRE-06` : ESX tables `jobs` / `job_grades`, QBCore et Qbox création du métier par le bridge, voir `BASE-MOT-02`), « Relier à un métier existant » `base.setup.justice_relier` (liste des métiers non reliés), « Ne pas utiliser » `base.setup.justice_ignorer` (l'entreprise par défaut est archivée, l'app Justice n'apparaît pour personne).
     - Le nom de métier retenu est écrit dans `pop_tablet_settings.justice_roles` (prioritaire sur `Config.Justice.Roles`, fichier 04) pour que les rôles avocat / procureur / juge suivent le bon métier.
  6. **Étape 4 « Récapitulatif »** : liste de ce qui va être créé ; « Terminer ».
  7. Le serveur crée les métiers demandés, puis les entreprises via l'export de la branche Entreprises (`exports.pop_tablet:CompanyCreateFromJob(job, modele, grades)`), et écrit `setup_done = os.time()`.
  8. Succès : « La tablette est prête. » et retour au bureau.
- **Données** (`pop_tablet_meta`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| meta_key | VARCHAR(64) clé primaire | Oui | — | — |
| meta_value | TEXT | Oui | ≤ 64 Ko | — |
- **Règles serveur** : ACE vérifiée à chaque étape ; création d'objet en base uniquement si la ligne n'existe pas ; entreprise déjà existante pour un métier = ignorée (pas de doublon) ; tout l'assistant est rejouable sans casser l'existant.
- **Textes et états** : « Assistant d'installation » `base.setup.titre` · « Détection » `base.setup.detection` · « Métiers » `base.setup.metiers` · « Justice » `base.setup.justice` · « Tribunal : relié au métier {metier} » / « Cabinet d'avocats : relié au métier {metier} » `base.setup.justice_trouve` · « Tribunal : aucun métier trouvé » / « Cabinet d'avocats : aucun métier trouvé » `base.setup.justice_absent` · « Créer le métier » `base.setup.justice_creer` · « Relier à un métier existant » `base.setup.justice_relier` · « Ne pas utiliser » `base.setup.justice_ignorer` · « Récapitulatif » `base.setup.recap` · « Créer l'objet » `base.setup.creer_objet` · « Copier » `base.commun.copier` · « Obligatoire : installez oxmysql puis redémarrez le serveur. » `base.setup.oxmysql` · « Aucun métier trouvé. Les entreprises pourront être créées plus tard dans l'app Admin. » `base.setup.aucun_metier` (vide) · « La tablette est prête. » `base.setup.ok`.
- **Notifications** : aucune.
- **Liens** : branche Entreprises (création, `SITE-CRE-01`, `SITE-CRE-06`), branche Admin, `BASE-MOT-02`, `BASE-MOT-03`, Justice (fichier 04).
- **Réglages** : `Config.Setup.AutoOpen = true`.
- **Journal admin** : oui, « assistant terminé » (admin, métiers reliés, métiers créés, choix Justice), envoyé sur Discord.
- **Performance** : détection faite à la demande (pas au démarrage) ; liste des métiers lue une fois.
- **Cas limites** :
  - Deux admins lancent l'assistant en même temps : verrou serveur, le second voit « Un autre administrateur utilise déjà l'assistant. » `base.setup.occupe`.
  - Serveur sans aucun métier : étape 2 vide, l'assistant peut se terminer.
  - Assistant relancé après installation : les métiers déjà reliés apparaissent cochés et grisés « Déjà relié » `base.setup.deja`.
- **Critères d'acceptation** :
  - Étant donné un serveur neuf (ESX, QBCore ou Qbox) avec `police`, `ambulance`, `mechanic`, quand l'admin termine l'assistant sans rien changer, alors ces trois entreprises sont reliées avec les bons modèles et les grades répartis.
  - Étant donné un serveur sans métier `justice` ni `avocat`, quand l'admin garde « Créer le métier » pour les deux, alors les métiers `justice` et `avocat` existent dans le framework et les entreprises Tribunal et Cabinet d'avocats y sont reliées.
  - Étant donné un joueur non admin, quand il tape `/tablette_setup`, alors il voit `pas_droit`.
  - Étant donné un client qui envoie l'étape « Terminer » sans ACE, quand le serveur reçoit, alors rien n'est créé et la tentative est journalisée.

### [BASE-MOT-16] Langues et repli des textes manquants (ajout)
- **But** : charger les langues et ne jamais afficher un écran cassé si une traduction manque.
- **Qui** : système ; traducteurs (fichiers ouverts).
- **Où** : `locales/fr.lua`, `locales/en.lua`, `shared/locale.lua`, `L(cle, params)` côté Lua, `Pop.t(cle, params)` côté NUI.
- **Parcours** :
  1. Chaque fichier déclare `Locales['fr'] = { name = 'Français', rtl = false, texts = { ['base.verrou.titre'] = 'Entre ton code', ... } }`.
  2. Les apps du dossier « mes apps » ajoutent leurs textes avec `exports.pop_tablet:AddLocale('fr', { ['monapp.ecran.cle'] = '...' })` ou un fichier `apps/<id>/locales/<code>.lua` chargé automatiquement.
  3. Recherche d'un texte : langue demandée → `Config.Locale` → `fr` → la clé elle-même. Une clé manquante écrit un avertissement console une seule fois par clé et par langue (si `Config.Debug = true`).
  4. Paramètres : `%s` / `%d` remplacés dans l'ordre ; paramètres nommés `{nom}` aussi acceptés.
  5. Une commande admin `/tablette_locales` liste les clés présentes en `fr` et absentes dans les autres langues (console).
- **Données** : tables en mémoire.
- **Règles serveur** : les paramètres insérés sont nettoyés (`BASE-MOT-12`) avant insertion ; le texte de langue n'est jamais interprété comme du HTML.
- **Textes et états** : tous les textes de cette fiche sont ceux des autres fiches.
- **Notifications** : aucune.
- **Liens** : `BASE-ECR-15`, `BASE-API-01`.
- **Réglages** : `Config.Locale = 'fr'` · `Config.Debug = false`.
- **Journal admin** : non.
- **Performance** : langues chargées une fois ; la NUI ne reçoit que la langue utilisée.
- **Cas limites** :
  - Fichier de langue avec erreur de syntaxe : ignoré, message console, repli `fr`.
  - Paramètre manquant : `%s` laissé vide.
  - Clé en double entre deux apps : la dernière chargée gagne, avertissement console.
- **Critères d'acceptation** :
  - Étant donné une clé absente en `en`, quand un joueur anglais l'affiche, alors il voit le texte français.
  - Étant donné `/tablette_locales`, quand l'admin la tape, alors la console liste les clés manquantes.
  - Étant donné un paramètre contenant `<b>`, quand le texte s'affiche, alors `<b>` apparaît en clair.

### [BASE-MOT-17] Création des tables et mises à jour de la base (ajout)
- **But** : installer et mettre à jour les tables automatiquement, sans manipulation SQL par le client.
- **Qui** : système.
- **Où** : `sql/install.sql` (référence lisible) et `server/migrations.lua`.
- **Parcours** :
  1. Au démarrage (après `MySQL.ready`), le serveur exécute `CREATE TABLE IF NOT EXISTS` pour les 6 tables de la base.
  2. Il lit `pop_tablet_meta.db_version` (absent = 0) et applique dans l'ordre les migrations numérotées supérieures (`migrations[1]`, `migrations[2]`…), chacune dans une transaction, puis écrit la nouvelle version.
  3. Les apps peuvent enregistrer leurs propres migrations via `exports.pop_tablet:RegisterMigration(appId, version, sql)` (version gardée dans `pop_tablet_meta` sous la clé `db_version_<appId>`).
  4. Échec d'une migration : arrêt des suivantes, message console rouge « [pop_tablet] Migration %d failed: %s », la tablette refuse de s'ouvrir avec `commun.erreur.bdd`.
- **Données** : schéma de la base :
| Table | Clés et index |
|---|---|
| `pop_tablet_meta` | PK `meta_key` |
| `pop_tablet_devices` | PK `serial` ; index `(mode, owner_identifier)` |
| `pop_tablet_notifications` | PK `id` ; index `(serial, created_at)`, `(identifier)` |
| `pop_tablet_appdata` | PK `id` ; unique `(app_id, scope_type, scope_id, data_key)` ; index `(app_id, scope_type, scope_id)` |
| `pop_tablet_logs` | PK `id` ; index `(created_at)`, `(actor_identifier)`, `(app)` |
| `pop_tablet_payments` | PK `id` ; unique `(action_id)` ; index `(created_at)` |
- **Règles serveur** : jamais de `DROP` ni de suppression de colonne dans une migration (ajouts seulement) ; requêtes préparées.
- **Textes et états** : « Base de données indisponible. Réessayez dans un instant. » `commun.erreur.bdd`.
- **Notifications** : aucune.
- **Liens** : `BASE-MOT-04`, `BASE-API-06`, `BASE-API-07`.
- **Réglages** : aucun.
- **Journal admin** : oui, « migration appliquée » (version).
- **Performance** : exécuté une seule fois au démarrage.
- **Cas limites** :
  - Tables déjà présentes : rien n'est recréé.
  - Base en `utf8` (pas `utf8mb4`) : tables créées avec `utf8mb4` explicitement.
  - Mise à jour qui saute deux versions : migrations appliquées une à une.
- **Critères d'acceptation** :
  - Étant donné une base vide, quand le serveur démarre, alors les 6 tables existent et `db_version` vaut la dernière version.
  - Étant donné un redémarrage, quand le serveur démarre, alors aucune migration n'est rejouée.
  - Étant donné une app tierce qui enregistre une migration contenant `DROP TABLE users`, quand elle est enregistrée, alors elle est refusée (mots `DROP` et `TRUNCATE` interdits dans les migrations d'apps).

### [BASE-MOT-18] Contrôle des images autorisées (ajout)
- **But** : n'afficher que des images venant de sites autorisés par le serveur ou hébergées par lui.
- **Qui** : système ; toutes les apps qui acceptent un lien d'image (fond d'écran, galerie, annonces, sites).
- **Où** : serveur `Sanitize.imageUrl(url)` ; schéma de champ `type = 'image'`.
- **Parcours** :
  1. Le lien doit commencer par `https://`, faire au plus 300 caractères, ne contenir ni espace ni guillemet ni `<` `>`.
  2. Le domaine (partie entre `https://` et le premier `/`, sans port) doit être exactement dans `Config.Images.AllowedDomains` ou en être un sous-domaine.
  3. Le chemin doit finir par `.png`, `.jpg`, `.jpeg`, `.webp` ou `.gif` (paramètres `?…` autorisés après l'extension).
  4. Les images prises avec screencapture et envoyées par le serveur reçoivent un lien du domaine configuré `Config.Images.UploadDomain`, automatiquement autorisé.
  5. Refus : `invalide` avec le texte `base.image.domaine` ou `base.image.format`.
- **Données** : aucune.
- **Règles serveur** : contrôle serveur systématique ; la NUI applique aussi une `Content-Security-Policy` `img-src 'self' nui: https://<domaines autorisés>` générée au démarrage.
- **Textes et états** : « Ce site d'images n'est pas autorisé sur le serveur. » `base.image.domaine` · « Ce lien n'est pas une image. » `base.image.format`.
- **Notifications** : aucune.
- **Liens** : `BASE-ECR-11`, apps Galerie, Sites, Annonces.
- **Réglages** : `Config.Images.AllowedDomains = { 'i.imgur.com', 'r2.fivemanage.com' }` (liens Discord exclus : ils expirent) · `Config.Images.Extensions = { 'png', 'jpg', 'jpeg', 'webp', 'gif' }` · `Config.Images.UploadDomain = ''` (vide = photos de la Galerie stockées sur le disque du serveur et référencées `media:<id>`, fiche 06).
- **Journal admin** : non.
- **Performance** : vérification par motifs, sans requête réseau.
- **Cas limites** :
  - `https://i.imgur.com.evil.com/a.png` : refusé (le domaine n'est pas exactement autorisé ni sous-domaine).
  - `http://i.imgur.com/a.png` (sans s) : refusé.
  - Liste vide : seules les images hébergées par le serveur passent.
- **Critères d'acceptation** :
  - Étant donné `https://i.imgur.com/abc.png`, quand il est contrôlé, alors il est accepté.
  - Étant donné `https://exemple.com/a.png`, quand il est contrôlé, alors il est refusé avec `base.image.domaine`.
  - Étant donné un client qui envoie `javascript:alert(1)`, quand le serveur reçoit, alors il est refusé.

### [BASE-MOT-19] Contrôle des dépendances au démarrage (ajout)
- **But** : prévenir clairement le propriétaire du serveur si une pièce obligatoire manque ou est mal configurée.
- **Qui** : système ; lu dans la console par le propriétaire.
- **Où** : console serveur au démarrage de `pop_tablet`.
- **Parcours** :
  1. Vérifie : `oxmysql` démarré (obligatoire), framework trouvé (obligatoire), ordre de démarrage (`pop_tablet` après le framework et l'inventaire : `GetResourceState` = `started`), `config.lua` valide (`BASE-MOT-06`), convar Discord.
  2. Affiche un résumé en 6 lignes maximum : `[pop_tablet] v1.0.0 | esx | ox_inventory (metadata) | ox_target | discord: on | setup: done`.
  3. Pièce obligatoire absente : message rouge et la ressource n'enregistre ni objet ni commande.
- **Données** : aucune.
- **Règles serveur** : aucune action sur les autres ressources.
- **Textes et états** : messages console en anglais : « [pop_tablet] oxmysql is required. Start it before pop_tablet. », « [pop_tablet] No framework found. ».
- **Notifications** : aucune.
- **Liens** : `BASE-MOT-02`, `BASE-MOT-03`, `BASE-MOT-15`.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : une fois au démarrage.
- **Cas limites** :
  - oxmysql démarré après : `fxmanifest` le déclare en dépendance, FiveM refuse de démarrer `pop_tablet` sans lui.
  - Inventaire démarré après `pop_tablet` : message jaune « Start your inventory before pop_tablet », détection relancée à la première utilisation.
  - Assistant pas encore fait : rappel « setup: pending ».
- **Critères d'acceptation** :
  - Étant donné une installation complète, quand le serveur démarre, alors la ligne de résumé s'affiche en vert.
  - Étant donné oxmysql absent, quand le serveur démarre, alors le message rouge s'affiche et la ressource ne démarre pas.
  - Étant donné un joueur, quand il cherche à lire ce résumé, alors rien n'est envoyé aux clients.

---

## 4. L'API pour les apps

Règles communes à toutes les fiches `BASE-API` : exports serveur appelés `exports.pop_tablet:<Nom>(...)` ; chaque export renvoie `ok, resultat_ou_codeErreur` ; tout appel est attribué à la ressource appelante (`GetInvokingResource()`) et une ressource ne peut agir que sur les apps qu'elle a enregistrées (sauf `pop_tablet` lui-même) ; documentation complète et exemples dans `docs/api.md` et `docs/guide-ia.md`.

### [BASE-API-01] Dossier « mes apps »
- **But** : permettre au client (ou à Claude) d'ajouter une app à la tablette en déposant un dossier, sans toucher au cœur chiffré.
- **Qui** : propriétaire du serveur / développeur.
- **Où** : `pop_tablet/apps/<id>/` (ouvert, hors escrow).
- **Parcours** :
  1. Structure d'une app :
     - `apps/<id>/app.lua` (obligatoire) : `return { id, label, icon, order, jobs, ace, item, sharable, offline, version }` ;
     - `apps/<id>/server.lua` (facultatif) : actions serveur (`BASE-API-02`) ;
     - `apps/<id>/client.lua` (facultatif) ;
     - `apps/<id>/ui/index.html` (obligatoire) + `ui/*.js`, `ui/*.css` ; peut inclure `../../web/kit/pop.css` et `pop.js` ;
     - `apps/<id>/locales/fr.lua`, `en.lua` (facultatif) ;
     - `apps/<id>/icon.svg` (obligatoire, ≤ 20 Ko).
  2. `fxmanifest.lua` charge par motifs : `server_scripts { 'apps/*/server.lua' }`, `client_scripts { 'apps/*/client.lua' }`, `shared_scripts { 'apps/*/app.lua' }`, `files { 'apps/*/ui/**', 'apps/*/icon.svg' }`.
  3. Au démarrage, le moteur lit chaque `app.lua`, valide la définition (`BASE-API-02`) et l'enregistre ; une app invalide est ignorée avec un message console qui dit quoi corriger.
  4. L'interface de l'app est affichée dans une `iframe` plein écran de la tablette (sous la barre du haut), avec l'attribut `sandbox="allow-scripts allow-same-origin"`. La communication passe par `pop.js` (`postMessage` entre l'iframe et la tablette, la tablette relaie au client puis au serveur).
  5. 3 apps d'exemple livrées : `apps/exemple_notes` (notes perso, portée `device`), `apps/exemple_compteur` (données portée `job` + notification), `apps/exemple_caisse` (paiement via `BASE-API-07`).
  6. Désactiver une app sans la supprimer : `Config.Apps.Disabled = { 'exemple_compteur' }`.
- **Données** : définition (voir `BASE-API-02`).
- **Règles serveur** : l'`id` du dossier doit être identique à l'`id` déclaré ; ids réservés interdits (`base`, `settings`, `admin`, et les ids des apps officielles) ; l'iframe ne peut appeler que les actions de sa propre app (le moteur ajoute l'id de l'app à chaque demande selon l'iframe d'origine, pas selon ce que l'app déclare).
- **Textes et états** : messages console : « [pop_tablet] App '%s' ignored: %s ».
- **Notifications** : aucune.
- **Liens** : `BASE-API-02` à `BASE-API-10`, `BASE-MOT-09`, `BASE-MOT-16`.
- **Réglages** : `Config.Apps.Disabled = {}` · `Config.Apps.Examples = true` (les exemples sont désactivés si `false`).
- **Journal admin** : non.
- **Performance** : l'iframe d'une app n'est créée qu'à son ouverture et détruite à sa fermeture ; fichiers servis localement par FiveM.
- **Cas limites** :
  - Deux dossiers avec le même id : le second est ignoré.
  - `app.lua` avec erreur de syntaxe : app ignorée, les autres démarrent.
  - App qui tente d'appeler l'action d'une autre app : refus `pas_droit`.
- **Critères d'acceptation** :
  - Étant donné un dossier `apps/ma_app` valide, quand le serveur redémarre la ressource, alors l'icône apparaît chez les joueurs autorisés.
  - Étant donné `Config.Apps.Examples = false`, quand le serveur démarre, alors les apps d'exemple n'apparaissent pas.
  - Étant donné une app malveillante qui envoie une demande au nom de l'app `mdt`, quand le serveur reçoit, alors il utilise l'id de l'iframe d'origine et refuse.

### [BASE-API-02] Enregistrer une app
- **But** : déclarer une app (depuis le dossier « mes apps » ou depuis une autre ressource) avec ses conditions d'accès et ses actions.
- **Qui** : développeur ; ressources serveur.
- **Où** : `exports.pop_tablet:RegisterApp(def)` et `exports.pop_tablet:RegisterAction(appId, action)` côté serveur ; `exports.pop_tablet:UnregisterApp(appId)`.
- **Parcours** :
  1. La ressource appelle `RegisterApp(def)` (après l'événement `pop_tablet:ready`, émis par la base quand elle est prête ; le dossier « mes apps » est enregistré automatiquement).
  2. Le moteur valide la définition, l'ajoute à la liste, invalide le cache des apps autorisées, renvoie la liste à jour aux tablettes ouvertes.
  3. La ressource déclare ses actions avec `RegisterAction(appId, { name, write, duty, permission, rate, schema, handler })` (format `BASE-MOT-01`).
  4. Si la ressource s'arrête, ses apps et actions sont retirées automatiquement (`onResourceStop`).
- **Données** (définition) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| id | chaîne | Oui | 3 à 32, `[a-z0-9_]` | — |
| label | clé de langue | Oui | ≤ 64 | — |
| icon | chemin ou `nui://` | Oui | ≤ 200 | — |
| ui | chemin de l'`index.html` | Oui | `apps/<id>/ui/index.html` ou `nui://<ressource>/...` | — |
| order | entier | Non | 0 à 999 | 500 |
| jobs | table `{ [metier] = gradeMin }` ou nil | Non | — | nil = tout le monde |
| companyLevel | `recrue` \| `membre` \| `chef` \| `patron` | Non | niveau minimum dans l'entreprise | nil |
| ace | chaîne | Non | — | nil |
| item | chaîne (objet requis en plus) | Non | — | nil |
| condition | fonction(source) → booléen | Non | 5 ms max | nil |
| sharable | booléen | Non | — | false |
| offline | booléen | Non | — | false |
| duty | booléen (app métier) | Non | — | false |
| permissions | liste de clés de droits déclarées | Non | ≤ 50 | {} |
- **Règles serveur** : id unique ; une ressource ne peut pas remplacer l'app d'une autre ; une `condition` qui lève une erreur ou dépasse 5 ms (mesure `os.clock`) rend l'app invisible pour ce joueur et écrit un avertissement console ; au plus `Config.Apps.Max = 96` apps.
- **Textes et états** : aucun texte joueur ; erreurs renvoyées : `id_pris`, `id_invalide`, `champ_manquant:<champ>`.
- **Notifications** : aucune.
- **Liens** : `BASE-ECR-01`, `BASE-MOT-01`, branche Entreprises (`companyLevel` et droits case par case).
- **Réglages** : `Config.Apps.Max = 96`.
- **Journal admin** : oui, « app enregistrée / retirée » (id, ressource).
- **Performance** : enregistrement une fois ; calcul d'accès mis en cache par joueur.
- **Cas limites** :
  - Enregistrement avant que la base soit prête : mis en attente puis traité à `pop_tablet:ready`.
  - Redémarrage de la ressource tierce : app retirée puis réenregistrée, l'ordre de l'utilisateur est conservé.
  - Définition sans `ui` : refus `champ_manquant:ui`.
- **Critères d'acceptation** :
  - Étant donné `RegisterApp({ id = 'garage', jobs = { mechanic = 0 }, ... })`, quand un mécano ouvre la tablette, alors l'icône apparaît ; un policier ne la voit pas.
  - Étant donné une ressource arrêtée, quand un joueur ouvre la tablette, alors l'app n'apparaît plus.
  - Étant donné une ressource qui enregistre l'id `mdt` déjà pris, quand elle appelle, alors elle reçoit `id_pris`.

### [BASE-API-03] Ouvrir un écran
- **But** : ouvrir une app (et un écran précis) depuis une autre app, une notification ou un script.
- **Qui** : apps (NUI) ; scripts serveur et client.
- **Où** : NUI `Pop.open(appId, screen, params)` ; serveur `exports.pop_tablet:OpenScreen(source, appId, screen, params)` ; client `exports.pop_tablet:Open(appId, screen, params)`.
- **Parcours** :
  1. L'appel arrive au moteur, qui vérifie que le joueur a accès à l'app.
  2. Tablette fermée : ouverture normale (`BASE-OBJ-01`, avec code si nécessaire), puis l'écran demandé s'affiche après le déverrouillage.
  3. Tablette ouverte : l'iframe de l'app est créée (ou réutilisée si déjà ouverte) et reçoit le message `pop:navigate` `{ screen, params }`.
  4. L'app gère `Pop.onNavigate((screen, params) => ...)`.
  5. Retour : Échap ou bouton « Retour » remonte d'un écran dans l'app (pile gérée par `pop.js`) ; depuis le premier écran de l'app, retour au bureau.
- **Données** :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| appId | chaîne | Oui | app enregistrée | — |
| screen | chaîne | Non | ≤ 32 | `home` |
| params | table | Non | ≤ 2 Ko sérialisés | {} |
- **Règles serveur** : accès vérifié ; un script client ne peut ouvrir que la tablette de son propre joueur (le serveur revérifie à l'ouverture) ; `params` ne donnent aucun droit (l'app revérifie côté serveur ce qu'elle charge).
- **Textes et états** : `base.bureau.plus_acces` si l'accès est refusé.
- **Notifications** : aucune.
- **Liens** : `BASE-ECR-04` (lien des notifications), `BASE-ECR-05`, `BASE-OBJ-11`.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : une app ouverte à la fois ; l'iframe précédente est détruite (pas de multi-tâche) sauf `Config.UI.KeepLastApp = true` qui garde la dernière en mémoire pour un retour instantané.
- **Cas limites** :
  - Écran inconnu de l'app : l'app affiche son écran d'accueil.
  - Joueur sans tablette appelé par `OpenScreen` : refus silencieux côté serveur (le script appelant reçoit `false, 'pas_tablette'`).
  - Appel pendant que l'écran de verrouillage est affiché : l'écran est mémorisé et ouvert après déverrouillage.
- **Critères d'acceptation** :
  - Étant donné une notification de facture avec un lien, quand le joueur la touche, alors l'app Factures s'ouvre sur cette facture.
  - Étant donné `OpenScreen(src, 'mdt')` pour un civil, quand le serveur l'exécute, alors il renvoie `false, 'pas_droit'`.
  - Étant donné des `params` qui contiennent `{ admin = true }`, quand l'app les reçoit, alors aucun droit supplémentaire n'est accordé.

### [BASE-API-04] Notifier
- **But** : envoyer une notification aux bons joueurs depuis n'importe quel module.
- **Qui** : scripts serveur (apps officielles, « mes apps », ressources tierces).
- **Où** : `exports.pop_tablet:Notify(target, notif)`.
- **Parcours** :
  1. `target` peut être : un `source` (nombre) ; `{ identifier = '...' }` ; `{ job = 'police', onDuty = true, minGrade = 0 }` ; `{ company = id }` (branche Entreprises) ; une liste de `source`.
  2. Le moteur résout les joueurs en ligne concernés, garde ceux qui ont l'objet tablette (cache 30 s), puis applique `BASE-ECR-04` et `BASE-ECR-05`.
  3. Un `identifier` hors ligne : stocké en boîte d'attente (`BASE-ECR-05`), livré à la prochaine ouverture.
  4. Renvoie `true, nombreDeDestinataires`.
- **Données** : format `notif` de `BASE-ECR-04` ; `app` doit être une app de la ressource appelante (ou `pop_tablet`).
- **Règles serveur** : export serveur uniquement (aucun événement réseau équivalent) ; textes nettoyés ; au plus 200 destinataires par appel ; limite de 10 bandeaux par joueur par minute.
- **Textes et états** : définis par l'appelant (clé de langue de préférence).
- **Notifications** : c'est la fonctionnalité.
- **Liens** : `BASE-ECR-04`, `BASE-ECR-05`, `BASE-API-10`.
- **Réglages** : `Config.Notify.MaxTargets = 200`.
- **Journal admin** : non.
- **Performance** : résolution par métier faite sur la liste des joueurs en ligne gardée par le moteur (mise à jour aux événements de connexion et changement de métier), sans requête SQL.
- **Cas limites** :
  - `job = 'police'` avec 0 policier en ligne : renvoie `true, 0`.
  - `app` d'une autre ressource : refus `false, 'pas_droit'`.
  - Appel avec 1 000 sources : refus `false, 'trop_de_cibles'`.
- **Critères d'acceptation** :
  - Étant donné 3 policiers en service dont 1 sans tablette, quand on notifie `{ job = 'police', onDuty = true }`, alors 2 joueurs reçoivent le bandeau.
  - Étant donné un joueur hors ligne visé par identifiant, quand il ouvre sa tablette le lendemain, alors la notification est dans son historique.
  - Étant donné un client qui cherche un événement pour envoyer une notification à tout le serveur, quand il essaie, alors aucun événement réseau ne le permet.

### [BASE-API-05] Lire le joueur et son métier (et le statut en service)
- **But** : donner aux apps une vue unique et sûre du joueur, quel que soit le framework.
- **Qui** : scripts serveur ; côté NUI, version limitée.
- **Où** : serveur `exports.pop_tablet:GetPlayer(source)`, `GetPlayerByIdentifier(identifier)`, `IsOnDuty(source)`, `SetDuty(source, state)`, `HasAccess(source, appId, permission)` ; NUI `Pop.me()`.
- **Parcours** :
  1. `GetPlayer(source)` renvoie :
     `{ source, identifier, name, job = { name, label, grade, gradeLabel, level }, company = { id, label } ou nil, onDuty, serial, locale }` où `level` = `recrue` | `membre` | `chef` | `patron` (correspondance de la branche Entreprises, sinon calcul par défaut de `BASE-MOT-15`).
  2. `Pop.me()` côté NUI renvoie seulement `{ name, job = { label, gradeLabel, level }, onDuty, locale }` (jamais l'identifiant).
  3. `SetDuty(source, state)` est appelé par la branche Entreprises (prise de service) : le moteur garde l'état en mémoire, le met dans le state bag joueur `popDuty` (réplication en lecture pour les autres scripts), envoie `pop_tablet:client:duty` à la tablette ouverte et émet l'événement serveur local `pop_tablet:dutyChanged(source, { identifier, companyId, job, onDuty })` (format unique pour toute la tablette ; `popDuty` vaut l'id d'entreprise en service ou `false`).
  4. `HasAccess(source, appId, permission)` renvoie `true/false` selon la définition de l'app et les droits case par case de l'entreprise.
- **Données** : état en service en mémoire `Duty[source] = { state, job, since }` ; remis à « hors service » à la déconnexion et au changement de métier.
- **Règles serveur** : `SetDuty` réservé à la ressource `pop_tablet` (branche Entreprises intégrée) et aux ressources listées dans `Config.Duty.AllowedResources` ; le state bag est écrit côté serveur uniquement (le client ne peut pas le modifier : `SetStateBagValue` refusé par `AddStateBagChangeHandler` qui remet la valeur serveur).
- **Textes et états** : aucun.
- **Notifications** : aucune.
- **Liens** : `BASE-ECR-03`, `BASE-MOT-10` (hors service), branche Entreprises, dispatch, planning.
- **Réglages** : `Config.Duty.AllowedResources = {}` · `Config.Duty.SyncFrameworkDuty = true` (si `true`, la prise de service met aussi à jour l'indicateur de service du framework par `Bridge.SetDutyFlag` : QBCore / Qbox `job.onduty`, ESX Legacy `onDuty` ; le métier n'est jamais changé).
- **Journal admin** : non (la prise de service est journalisée par la branche Entreprises).
- **Performance** : lecture en mémoire ; `GetPlayer` mis en cache jusqu'au prochain changement de métier.
- **Cas limites** :
  - Joueur déconnecté : `GetPlayer` renvoie `nil`.
  - Changement de métier en service : passage hors service automatique.
  - Ressource non autorisée qui appelle `SetDuty` : refus `false, 'pas_droit'`.
- **Critères d'acceptation** :
  - Étant donné un policier grade 3 relié au niveau Chef, quand une app appelle `GetPlayer`, alors `job.level = 'chef'`.
  - Étant donné `SetDuty(src, true)`, quand la tablette est ouverte, alors la barre affiche « En service ».
  - Étant donné un client qui modifie son state bag `popDuty`, quand le serveur le détecte, alors la valeur serveur est remise.

### [BASE-API-06] Stocker des données rangées par app
- **But** : offrir aux apps un stockage clé/valeur simple, rangé par app et par portée, sans créer de table.
- **Qui** : scripts serveur des apps.
- **Où** : `exports.pop_tablet:DataGet(appId, scope, key)`, `DataSet(appId, scope, key, value, opts)`, `DataDelete(appId, scope, key)`, `DataList(appId, scope, { prefix, page, pageSize })`.
- **Parcours** :
  1. `scope` = `{ type = 'device' | 'player' | 'job' | 'global', id = ... }`. Raccourcis : `scope = 'device'` (numéro de série de la session du joueur, avec `opts.source`), `'player'` (identifiant), `'job'` (métier actuel).
  2. `DataSet` : vérifie que l'app appartient à la ressource appelante, sérialise en JSON, vérifie la taille, met à jour le cache, ajoute à la file groupée (`opts.critical = true` → écriture immédiate).
  3. `DataGet` : cache puis base.
  4. `DataList` : renvoie `{ items = { { key, value, updated_at } }, total, page }` triés par `updated_at` décroissant, 20 par page.
  5. `DataDelete` : suppression réelle, sauf si l'app est déclarée `sensitive = true` : alors la ligne est marquée `archived = 1` et n'apparaît plus dans `DataGet`/`DataList` (visible par l'admin seulement).
- **Données** (`pop_tablet_appdata`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| id | BIGINT auto | Oui | — | — |
| app_id | VARCHAR(32) | Oui | app enregistrée | — |
| scope_type | ENUM('device','player','job','global') | Oui | — | — |
| scope_id | VARCHAR(64) | Oui | `''` pour `global` | — |
| data_key | VARCHAR(64) | Oui | `[a-zA-Z0-9_.:-]` | — |
| data_value | LONGTEXT JSON | Oui | ≤ 16 Ko | — |
| archived | TINYINT(1) | Oui | — | 0 |
| updated_at | INT UNSIGNED | Oui | — | `os.time()` |
- **Règles serveur** : une ressource n'accède qu'aux données de ses apps ; au plus 2 000 clés par app et par portée (`Config.Limits.AppDataKeys`) ; valeur ≤ 16 Ko ; les textes contenus doivent avoir été nettoyés par l'action (le stockage ne réinterprète rien).
- **Textes et états** : erreurs renvoyées : `trop_grand`, `trop_de_cles`, `pas_droit`, `cle_invalide`.
- **Notifications** : aucune.
- **Liens** : `BASE-MOT-04`, `BASE-MOT-05`, `BASE-OBJ-08` (la réinitialisation efface la portée `device`).
- **Réglages** : `Config.Limits.AppDataValue = 16384` · `Config.Limits.AppDataKeys = 2000`.
- **Journal admin** : non par défaut ; `opts.log = true` enregistre avant/après.
- **Performance** : cache 10 min pour `job` et `global` ; `device` et `player` mis en cache pendant la session du joueur ; écritures groupées.
- **Cas limites** :
  - Valeur de 20 Ko : refus `trop_grand`.
  - Deux écritures de la même clé en 1 s : la dernière gagne, une seule écriture en base.
  - App retirée : ses données restent en base (rien n'est effacé).
- **Critères d'acceptation** :
  - Étant donné l'app d'exemple notes, quand le joueur enregistre une note puis rouvre la tablette, alors la note est là.
  - Étant donné une tablette réinitialisée, quand le joueur ouvre les notes, alors elles sont vides ; les données portée `job` restent.
  - Étant donné une ressource qui lit les données de l'app `mdt` qu'elle n'a pas enregistrée, quand elle appelle `DataGet`, alors elle reçoit `pas_droit`.

### [BASE-API-07] Payer via le serveur
- **But** : centraliser tous les mouvements d'argent de la tablette avec les mêmes protections.
- **Qui** : scripts serveur des apps (Factures, Police, Mécano, « mes apps »).
- **Où** : `exports.pop_tablet:Pay(req)`.
- **Parcours** :
  1. L'app appelle `Pay({ actionId, from, to, amount, reason, app, requireNear, payer })` :
     - `from` = `{ type = 'player', source, account = 'bank' }` ou `{ type = 'society', job }` ;
     - `to` = `{ type = 'player', identifier | source, account }` ou `{ type = 'society', job }` ou `{ type = 'void' }` (amende versée à l'État) ;
     - `requireNear` = source de l'autre joueur qui doit être à `Config.Limits.NearDistance` (3 m) ou nil.
  2. Le moteur vérifie : montant entier, > 0, ≤ `Config.Limits.MaxAmount` (ou plafond plus bas de l'app) ; `actionId` jamais utilisé (`pop_tablet_payments.action_id` unique) ; distance si demandée ; joueur payeur vivant et en ligne ; solde suffisant.
  3. Le moteur insère d'abord la ligne de paiement (`status = 'pending'`), retire l'argent (`Bridge.RemoveMoney` / `RemoveSocietyMoney`), ajoute l'argent (`AddMoney` / `AddSocietyMoney`), passe la ligne à `done`.
  4. Si l'ajout échoue après le retrait : remboursement automatique, ligne `refunded`, journal niveau `alert`.
  5. Renvoie `true, paymentId` ou `false, code` (`pas_argent`, `trop_loin`, `doublon`, `montant`, `serveur`).
  6. Comptes d'entreprise : via `Bridge.*SocietyMoney`, le compte société du framework détecté (ESX : `esx_addonaccount` / `esx_society` ; QBCore : `qb-banking` ou `qb-management` ; Qbox : `Renewed-Banking` ou `qb-banking` ; voir `BASE-MOT-02`). Un adaptateur banque optionnel (`bridge/bank/custom.lua`, ouvert, non fourni) peut remplacer ces trois fonctions ; `pop_bank` n'expose aucun export et n'est pas branché.
- **Données** (`pop_tablet_payments`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| id | BIGINT auto | Oui | — | — |
| action_id | VARCHAR(40) unique | Oui | — | — |
| app | VARCHAR(32) | Oui | — | — |
| from_type / from_id | VARCHAR(16) / VARCHAR(64) | Oui | — | — |
| to_type / to_id | VARCHAR(16) / VARCHAR(64) | Oui | — | — |
| amount | INT UNSIGNED | Oui | 1 à `MaxAmount` | — |
| reason | VARCHAR(255) | Oui | nettoyé | — |
| status | ENUM('pending','done','refunded','failed') | Oui | — | `pending` |
| created_at | INT UNSIGNED | Oui | — | `os.time()` |
- **Règles serveur** : écriture immédiate (jamais groupée) ; jamais de suppression (archive) ; aucun montant ne vient du client sans être recalculé par l'app côté serveur ; verrou par payeur pendant le paiement (deux paiements simultanés du même joueur sont traités l'un après l'autre).
- **Textes et états** : codes `commun.erreur.pas_argent` « Pas assez d'argent sur le compte. », `commun.erreur.montant` « Ce montant n'est pas autorisé. », `trop_loin`, `doublon`.
- **Notifications** : aucune par la base (l'app prévient payeur et receveur).
- **Liens** : `BASE-API-09` (signal « facture payée » émis par l'app Factures après un `Pay` réussi), `BASE-MOT-14`, journal.
- **Réglages** : `Config.Limits.MaxAmount = 100000` · `Config.Limits.NearDistance = 3.0`.
- **Journal admin** : oui, chaque paiement (de, vers, montant, motif, app, statut) ; catégorie Discord `money`.
- **Performance** : 2 à 3 requêtes par paiement, rien en dehors.
- **Cas limites** :
  - Double clic sur « Payer » : même `actionId`, le second renvoie `doublon`.
  - Payeur qui se déconnecte entre le retrait et l'ajout : l'ajout se fait quand même (receveur), sinon remboursement hors ligne via le compte en base (`Bridge.AddMoneyOffline`).
  - Montant 0 ou décimal : refus `montant`.
- **Critères d'acceptation** :
  - Étant donné 1 000 $ en banque et une facture de 300 $, quand le joueur paie, alors il a 700 $, l'entreprise reçoit 300 $ et une ligne `done` existe.
  - Étant donné `requireNear` et un receveur à 10 m, quand le paiement est demandé, alors il est refusé `trop_loin`.
  - Étant donné un tricheur qui rejoue le même `actionId`, quand le serveur reçoit, alors aucun argent ne bouge une seconde fois.

### [BASE-API-08] Signal « peine prononcée »
- **But** : prévenir les autres scripts (prison, travaux d'intérêt général) qu'une peine a été prononcée.
- **Qui** : émis par l'app Justice (verdict) et l'app Police (peine directe si la config le permet) ; écouté par n'importe quelle ressource serveur.
- **Où** : événement serveur local `pop_tablet:sentencePronounced` et export `exports.pop_tablet:OnSentence(cb)`.
- **Parcours** :
  1. Après validation et enregistrement du verdict, l'app appelle `exports.pop_tablet:EmitSentence(data)`.
  2. Le moteur vérifie que l'appelant est `pop_tablet` ou dans `Config.Signals.SentenceEmitters`, complète `sentenceId`, `at`, puis émet `TriggerEvent('pop_tablet:sentencePronounced', data)` et appelle chaque `cb` enregistré (dans un `pcall`).
  3. Si `Config.Signals.SentenceJail` est réglé (`'esx_jail'`, `'qalle_jail'`, `'qb-prison'` (QBCore), `'qbx_prison'` (Qbox ; nom de ressource et événement à vérifier, voir `00-sommaire.md` §5), `'rcore_prison'`, `'none'`), le moteur appelle aussi l'adaptateur de ce script (fichiers ouverts `bridge/jail/<nom>.lua`, seul réglage prison de toute la tablette, utilisé par la Police et la Justice) (ex. `TriggerEvent('esx_jail:sendToJail', target, minutes * 60)`) si le joueur est en ligne ; hors ligne, la peine est gardée et appliquée à sa connexion.
- **Données** (`data`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| sentenceId | chaîne | Oui | généré | — |
| identifier | chaîne | Oui | condamné | — |
| source | entier ou nil | Non | si en ligne | nil |
| jailMinutes | entier | Oui | 0 à 10 000 ; 1 « mois » RP affiché dans la tablette = 1 minute | 0 |
| fine | entier | Oui | 0 à `MaxAmount` | 0 |
| communityService | entier (heures de travaux d'intérêt général) | Oui | 0 à 100 | 0 |
| charges | liste `{ code, label }` | Oui | ≤ 30 | — |
| judge | `{ identifier, name }` | Oui | — | — |
| caseId | chaîne | Non | dossier Justice | nil |
| at | horodatage | Oui | — | `os.time()` |
- **Règles serveur** : émission refusée aux ressources non autorisées ; un même `sentenceId` n'est émis qu'une fois ; le signal ne transporte aucun lien Discord ni donnée privée hors celles du tableau.
- **Textes et états** : aucun texte joueur.
- **Notifications** : aucune par la base.
- **Liens** : Justice (verdict → casier), Police (casier, mandats), scripts de prison.
- **Réglages** : `Config.Signals.SentenceEmitters = {}` · `Config.Signals.SentenceJail = 'none'`.
- **Journal admin** : oui, « peine prononcée » (condamné, juge, peine) ; catégorie Discord `police`.
- **Performance** : un événement par verdict.
- **Cas limites** :
  - Aucun script n'écoute : sans effet, pas d'erreur.
  - Un écouteur plante : `pcall`, les autres écouteurs reçoivent quand même le signal.
  - Condamné hors ligne avec `SentenceJail` réglé : peine appliquée à sa prochaine connexion (stockée en `pop_tablet_meta` clé `pending_sentence:<identifier>`).
  - `SentenceJail = 'qbx_prison'` mais ressource `qbx_prison` absente : l'adaptateur n'est pas chargé, message console « [pop_tablet] Jail adapter qbx_prison: resource not started. », le signal part quand même.
- **Critères d'acceptation** :
  - Étant donné un verdict de 20 minutes, quand le juge le valide, alors `pop_tablet:sentencePronounced` est émis avec `jailMinutes = 20`.
  - Étant donné `SentenceJail = 'esx_jail'` et un condamné en ligne, quand le signal part, alors il est envoyé en prison 20 minutes.
  - Étant donné une ressource tierce non autorisée qui appelle `EmitSentence`, quand elle appelle, alors elle reçoit `pas_droit` et rien n'est émis.

### [BASE-API-09] Signal « facture payée »
- **But** : prévenir les autres scripts (immobilier, garages, concessionnaires) qu'une facture a été payée.
- **Qui** : émis par l'app Factures (et la fenêtre simple) ; écouté par n'importe quelle ressource serveur.
- **Où** : événement serveur local `pop_tablet:invoicePaid` et export `exports.pop_tablet:OnInvoicePaid(cb)`.
- **Parcours** :
  1. Après un `Pay` réussi pour une facture, l'app appelle `exports.pop_tablet:EmitInvoicePaid(data)`.
  2. Le moteur vérifie l'appelant (`pop_tablet` ou `Config.Signals.InvoiceEmitters`), puis émet l'événement et appelle les `cb`.
  3. Les scripts tiers peuvent créer leurs propres factures avec une référence (`externalRef`, ex. `garage:12`) via l'export de la branche Entreprises, et la retrouver dans le signal.
- **Données** (`data`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| invoiceId | entier | Oui | `pop_tablet_factures.id` | — |
| number | chaîne | Oui | numéro affiché de la facture | — |
| uid | chaîne | Oui | identifiant unique de la facture (fichier 02) | — |
| paymentId | entier | Oui | `pop_tablet_payments.id` | — |
| amount | entier | Oui | total payé | — |
| subtotal | entier | Oui | avant majoration | — |
| surcharge | entier | Oui | majoration d'impayé | 0 |
| method | `bank` \| `money` | Oui | — | — |
| payer | `{ identifier, source, name }` | Oui | `source` = nil si hors ligne | — |
| company | `{ id, job, label }` | Oui | `pop_tablet_companies` | — |
| employee | `{ identifier, source, name }` | Non | auteur de la facture | nil |
| lines | liste `{ label, qty, unitPrice, itemId }` | Oui | `itemId` = article Stock lié ou nil | — |
| metadata | table | Non | donnée libre du script créateur | nil |
| externalRef | chaîne | Non | ≤ 64 | nil |
| sourceScript | chaîne | Non | ressource qui a créé la facture | nil |
| kind | `invoice` \| `fine` \| `quote` | Oui | — | `invoice` |
| at | horodatage | Oui | — | `os.time()` |

Les signaux `pop_tablet:invoiceRefused`, `pop_tablet:invoiceCancelled`, `pop_tablet:invoiceUnpaid` et `pop_tablet:invoiceClosed` (fichier 02) utilisent le même format (sans `paymentId`, `method`).
- **Règles serveur** : émis une seule fois par facture (le statut « payée » est vérifié avant) ; émetteurs contrôlés.
- **Textes et états** : aucun.
- **Notifications** : aucune par la base.
- **Liens** : Factures → compte entreprise + part employé, → Stock (option), → Tableur (import) ; scripts tiers.
- **Réglages** : `Config.Signals.InvoiceEmitters = {}`.
- **Journal admin** : non (le paiement est déjà journalisé par `BASE-API-07`).
- **Performance** : un événement par paiement.
- **Cas limites** :
  - Facture payée deux fois (double clic) : `Pay` refuse le second, un seul signal.
  - Écouteur qui plante : `pcall`.
  - Facture payée via la fenêtre simple : même signal.
- **Critères d'acceptation** :
  - Étant donné une facture `externalRef = 'garage:12'`, quand elle est payée, alors le script garage reçoit le signal avec cette référence.
  - Étant donné une facture payée, quand on écoute, alors le signal arrive exactement une fois.
  - Étant donné une ressource tierce non autorisée qui appelle `EmitInvoicePaid`, quand elle appelle, alors elle reçoit `pas_droit`.

### [BASE-API-10] Envoyer une alerte au dispatch
- **But** : permettre à n'importe quel script (braquage, accident, appel PNJ) d'envoyer une alerte aux services sur leur tablette.
- **Qui** : scripts serveur et client tiers ; reçue par les joueurs du métier visé, en service, avec la tablette.
- **Où** : serveur `exports.pop_tablet:DispatchAlert(alert)` ; client `exports.pop_tablet:DispatchAlert(alert)` (relayée au serveur avec contrôles).
- **Parcours** :
  1. Le script envoie l'alerte.
  2. Côté client : le serveur reçoit `pop_tablet:dispatchFromClient`, remplace `coords` par la position serveur du joueur émetteur (jamais celle envoyée), applique l'anti-spam (1 alerte par 30 s par joueur et par code) et vérifie que la ressource appelante est dans `Config.Dispatch.ClientResources`.
  3. Le serveur crée l'alerte (id, date), la transmet à l'app Dispatch (branche Métiers) qui la stocke et l'affiche, et notifie les destinataires (`BASE-API-04`, priorité selon l'alerte) avec un lien vers l'alerte.
  4. Si `blip = true` : un blip temporaire (durée `blipTime`, défaut 60 s) est envoyé aux destinataires seulement.
  5. Renvoie `true, alertId`.
- **Données** (`alert`) :
| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| jobs | liste de métiers | Oui | ≤ 10 | — |
| code | chaîne | Oui | ≤ 16 (ex. `10-90`) | — |
| title | chaîne / clé | Oui | ≤ 60 | — |
| message | chaîne | Non | ≤ 255 | '' |
| coords | vec3 | Non | ignoré côté client | position de l'émetteur |
| priority | `low` \| `normal` \| `high` | Non | `high` = notification urgente | `normal` |
| blip | booléen | Non | — | true |
| blipSprite / blipColor | entiers | Non | — | 161 / 1 |
| blipTime | secondes | Non | 10 à 600 | 60 |
- **Règles serveur** : textes nettoyés ; alertes depuis le client limitées et coordonnées remplacées ; au plus `Config.Dispatch.MaxPerMinute = 60` alertes par minute pour tout le serveur, au-delà les alertes `low` sont abandonnées.
- **Textes et états** : définis par l'appelant ; titre par défaut « Alerte » `base.dispatch.alerte`.
- **Notifications** : aux joueurs des `jobs` en service avec la tablette : titre = `code · title`, texte = `message`.
- **Liens** : app Dispatch (branche Métiers), `BASE-API-04`, `BASE-API-05` (service), `BASE-API-11` (adaptateurs de compatibilité ps-dispatch, cd_dispatch, core_dispatch, esx_service).
- **Réglages** : `Config.Dispatch.ClientResources = {}` · `Config.Dispatch.ClientCooldown = 30` · `Config.Dispatch.MaxPerMinute = 60` · `Config.Dispatch.OnlyOnDuty = true` · `Config.Dispatch.Compat = { 'ps-dispatch', 'cd_dispatch', 'core_dispatch' }` (BASE-API-11).
- **Journal admin** : non (volume trop élevé) ; les alertes refusées pour abus sont journalisées.
- **Performance** : aucune requête si aucun destinataire ; blips gérés côté client par un `SetTimeout` de suppression.
- **Cas limites** :
  - Aucun destinataire en service : l'alerte est stockée dans l'app Dispatch, sans notification.
  - Client modifié qui envoie une alerte au nom d'un script non listé : refus.
  - Alerte depuis le client avec des coordonnées à l'autre bout de la carte : coordonnées remplacées par la vraie position.
- **Critères d'acceptation** :
  - Étant donné un script de braquage qui appelle `DispatchAlert({ jobs = { 'police' }, code = '10-90', title = 'Braquage' })`, quand 2 policiers sont en service avec la tablette, alors ils reçoivent « 10-90 · Braquage » et un blip.
  - Étant donné `OnlyOnDuty = true`, quand un policier hors service a la tablette, alors il ne reçoit rien.
  - Étant donné un tricheur qui déclenche `pop_tablet:dispatchFromClient` en boucle, quand le serveur reçoit, alors une seule alerte passe par 30 s et l'abus est journalisé.

### [BASE-API-11] Adaptateurs de compatibilité dispatch (alertes des scripts tiers)
- **But** : faire arriver sur la tablette, sans modifier les scripts du serveur, les alertes que les scripts de braquage, de coups de feu, de vol ou de téléphone envoient aux dispatchs courants (ps-dispatch, cd_dispatch, core_dispatch).
- **Qui** : système ; activé par l'admin dans `config.lua` ; alertes reçues par les joueurs des métiers visés, en service, avec la tablette (règles de BASE-API-10).
- **Où** : fichiers ouverts `bridge/dispatch/ps-dispatch.lua`, `bridge/dispatch/cd_dispatch.lua`, `bridge/dispatch/core_dispatch.lua`, `bridge/dispatch/esx_service.lua` ; réglage `Config.Dispatch.Compat`.
- **Parcours** :
  1. Au démarrage, pour chaque nom de `Config.Dispatch.Compat`, le serveur vérifie `GetResourceState(nom)` : si le vrai script est démarré, l'adaptateur **n'est pas chargé** (pas de conflit) et la console affiche « [pop_tablet] Dispatch compat skipped: %s is running. » ; sinon il charge `bridge/dispatch/<nom>.lua` et affiche « [pop_tablet] Dispatch compat enabled: %s ».
  2. Chaque adaptateur reprend les points d'entrée publics du dispatch d'origine, sans démarrer de ressource portant son nom :
     - **ps-dispatch** : exports client `CustomAlert(data)` et exports d'alertes prêtes à l'emploi les plus utilisés (`StoreRobbery`, `FleecaBankRobbery`, `PaletoBankRobbery`, `PacificBankRobbery`, `VangelicoRobbery`, `HouseRobbery`, `CarJacking`, `VehicleTheft`, `Shooting`, `VehicleShooting`, `Fight`, `DrugSale`, `SuspiciousActivity`, `InjuriedPerson`, `DeceasedPerson`, `OfficerDown`, `EmsDown`, `Explosion`) déclarés par `AddEventHandler('__cfx_export_ps-dispatch_<nom>', function(setCB) setCB(fn) end)` ; événement serveur `ps-dispatch:server:notify`.
     - **cd_dispatch** : événement serveur `cd_dispatch:AddNotification(data)` ; export client `GetPlayerInfo()` (renvoie `{ ped, coords, street_1, street_2, sex }` calculés côté client, utilisé par les scripts pour remplir l'alerte).
     - **core_dispatch** : export client `addCall(code, title, extraInfo, coords, job, cooldown, sprite, color)` et événement serveur `core_dispatch:addCall` (mêmes arguments).
     - **esx_service** (ESX seulement, facultatif) : rappels `esx_service:isInService(job)` et `esx_service:getInServiceList(job)` et événements `esx_service:activateService` / `esx_service:disableService`, redirigés vers le service de la tablette (`IsOnDuty`, `CountOnDuty`, `SetDuty`, ENT-GES-01/02), pour que les scripts ESX qui lisent esx_service voient les agents en service dans la tablette.
  3. L'adaptateur convertit l'alerte au format de `DispatchAlert` (BASE-API-10) et l'envoie par le même chemin : côté client, par `pop_tablet:dispatchFromClient` avec les contrôles de BASE-API-10 (coordonnées remplacées par la position serveur du joueur, anti-spam, ressource appelante) ; côté serveur, directement.
  4. Correspondance des champs (valeurs à vérifier sur la version installée de chaque script, voir `00-sommaire.md` §5) :
     | Tablette (`DispatchAlert`) | ps-dispatch | cd_dispatch | core_dispatch |
     |---|---|---|---|
     | `code` | `dispatchCode` | début de `title` avant « - » (ex. `10-15`) | `code` |
     | `title` | `message` | `title` | `title` |
     | `message` | `description` (+ `street`, `vehicle`, `plate` s'ils existent) | `message` | `extraInfo` (texte ou liste `{ icon, info }` mise bout à bout) |
     | `coords` | `coords` | `coords` | `coords` |
     | `jobs` | `jobs` : `'leo'` → `Config.Police.Jobs`, `'ems'` → `Config.EMS.Jobs`, autre nom → ce métier | `job_table` | `job` (texte ou liste) |
     | `priority` | `priority = 1` → `high`, sinon `normal` | `flash = 1` → `high`, sinon `normal` | `normal` |
     | `blipSprite` / `blipColor` / `blipTime` | `sprite` / `color` / `length` (minutes × 60) | `blip.sprite` / `blip.colour` / `blip.time` (minutes × 60) | `sprite` / `color` / 60 s |
  5. Retour aux scripts : les exports reprennent la valeur de retour d'origine quand elle existe (ps-dispatch : rien ; core_dispatch : rien) ; aucune erreur n'est renvoyée au script appelant (un refus est seulement journalisé s'il s'agit d'un abus).
  6. **Sans adaptateur** (liste vide, ou script tiers non couvert), le dispatch fonctionne quand même : appels manuels et renforts (MET-POL-11), bouton de détresse (MET-POL-12), commande `/secours` (MET-EMS-03), alertes « joueur à terre » automatiques (MET-EMS-03), et tout script qui appelle directement `exports.pop_tablet:DispatchAlert` (BASE-API-10).
- **Données** : aucune table propre ; les alertes converties sont stockées par l'app Dispatch comme celles de BASE-API-10 (champ `ressource` = nom de l'adaptateur, ex. `ps-dispatch`, affiché « Source : ps-dispatch »).
- **Règles serveur** : un adaptateur ne se charge jamais si le vrai script tourne ; toutes les règles de BASE-API-10 s'appliquent (nettoyage des textes, coordonnées client remplacées si l'écart dépasse 50 m, `Config.Dispatch.ClientCooldown = 30` s par joueur et par code, `Config.Dispatch.MaxPerMinute = 60`) ; pour un événement réseau (`cd_dispatch:AddNotification`, `ps-dispatch:server:notify`, `core_dispatch:addCall`), la ressource appelante est inconnue : elle est enregistrée sous le nom de l'adaptateur et limitée à `Config.Dispatch.CompatClientLimit = { n = 3, s = 60 }` par joueur ; métier inconnu dans `jobs` → ignoré, alerte gardée si au moins un métier reste, sinon refusée `invalid` ; `esx_service` : lecture libre, mais `activateService` / `disableService` passent par les règles d'ENT-GES-01/02 (droit `service`, fréquence 1 / 10 s).
- **Textes et états** : aucun texte joueur propre ; titre vide → « Alerte » (`base.dispatch.alerte`) ; ligne de source « Source : {ressource} » (`police.dispatch.source`). Messages console (anglais, non traduits) : voir étape 1 ; champ inconnu : « [pop_tablet] Dispatch compat %s: unknown field %s ignored. » (une fois par champ).
- **Notifications** : celles de BASE-API-10 (titre `code · title`, texte `message`).
- **Liens** : BASE-API-10 (format et contrôles), MET-POL-08 / MET-POL-13 (Dispatch police), MET-EMS-03 (alertes EMS), ENT-GES-01/02 (service, pour `esx_service`), BASE-MOT-19 (contrôle des dépendances : affiche les adaptateurs actifs).
- **Réglages** : `Config.Dispatch.Compat = { 'ps-dispatch', 'cd_dispatch', 'core_dispatch' }` (`'esx_service'` à ajouter à la main sur ESX ; `{}` pour tout couper) · `Config.Dispatch.CompatClientLimit = { n = 3, s = 60 }` · `Config.Dispatch.CompatJobs = { leo = 'police', ems = 'ems' }` (groupes de ps-dispatch : `'police'` = `Config.Police.Jobs`, `'ems'` = `Config.EMS.Jobs`).
- **Journal admin** : non pour les alertes (volume) ; oui pour chaque adaptateur chargé ou ignoré au démarrage et pour les refus pour abus (joueur, adaptateur, nombre).
- **Performance** : aucun coût tant qu'aucune alerte n'arrive ; un adaptateur = quelques gestionnaires d'événements enregistrés une fois ; aucune boucle, aucun thread.
- **Cas limites** :
  - Vrai ps-dispatch démarré en plus de la tablette : adaptateur ignoré, les alertes restent dans ps-dispatch (message console).
  - Script tiers qui teste `GetResourceState('ps-dispatch') == 'started'` avant d'appeler : il n'appelle pas l'adaptateur ; le guide (`docs/api.md`) montre la ligne à remplacer par `exports.pop_tablet:DispatchAlert`.
  - Export ps-dispatch non repris (alerte rare) : l'appel échoue dans le script tiers comme sans dispatch ; la liste des exports repris est documentée dans `bridge/dispatch/ps-dispatch.lua`, que le serveur peut compléter (fichier ouvert).
  - 30 scripts de coups de feu qui appellent `Shooting` au même endroit en 10 s : fusion de BASE-API-10 / MET-POL-13, un seul appel « ×30 ».
- **Critères d'acceptation** :
  - Étant donné ps-dispatch absent et `Compat` par défaut, quand un script de braquage appelle `exports['ps-dispatch']:StoreRobbery()`, alors les policiers en service avec la tablette reçoivent l'alerte avec « Source : ps-dispatch ».
  - Étant donné cd_dispatch absent, quand un script envoie `cd_dispatch:AddNotification` avec `job_table = { 'police' }`, alors l'alerte apparaît dans le Dispatch police avec le titre et la position du joueur.
  - Étant donné `Config.Dispatch.Compat = {}`, quand un agent crée un appel manuel ou appuie sur détresse, alors le dispatch fonctionne normalement.
  - Étant donné un tricheur qui déclenche `cd_dispatch:AddNotification` 20 fois en 1 min avec des coordonnées à l'autre bout de la carte, quand le serveur reçoit, alors 3 alertes au plus passent, placées à sa vraie position, et l'abus est journalisé.

---

## Décisions prises par défaut

1. **Code de verrouillage** : facultatif (proposé au premier démarrage, « Plus tard » possible), haché avec le bcrypt natif FiveM (`GetPasswordHash`), blocage lié au numéro de série (pas au joueur) et persistant en base.
2. **Raccourci clavier** : `F9` par défaut (modifiable par chaque joueur dans les paramètres GTA) ; touche `Y` pour la fenêtre simple des documents.
3. **Batterie** : 120 min d'utilisation pour 100 %, recharge en véhicule 30 min pour 100 % (vélos exclus), chargeur = objet réutilisable qui recharge à 100 % en 10 s ; tout est calculé par horodatages côté serveur, sans boucle.
4. **Pas de boutique dans la tablette** : la vente de la tablette et du chargeur (prix compris) est gérée par le script de boutique du serveur. La tablette fournit les objets à déclarer et trois exports serveur : `ResetTablet(serial)`, `ReplaceTablet(source, oldSerial)` et `TransferTabletData(oldSerial, newSerial)` (`BASE-OBJ-08`) ; l'admin réinitialise aussi par commande ou panneau (`BASE-OBJ-09`, `ADM-04`).
5. **Mode posée** : l'objet reste dans l'inventaire du propriétaire pendant qu'il est posé ; les spectateurs voient l'écran montré en lecture seule, chargé avec les droits du propriétaire ; un autre joueur peut prendre la tablette (`AllowTake = true`).
6. **Couleur d'accent par défaut** `#4FA3FF` et fond `#0E0F12` : à remplacer par les couleurs d'origine du client si elles existent (règle du dépôt : couleurs d'origine conservées).
7. **Réseau** : 4 barres partout sauf sous l'eau et dans des zones mortes configurables (liste vide par défaut) ; sans réseau, seules les apps `offline` (Réglages) fonctionnent.
8. **ESX, QBCore et Qbox au même niveau dès la sortie** : le bridge contient la correspondance complète pour les trois (`BASE-MOT-02`), chacun est testé à fond avec la même liste de critères d'acceptation avant la sortie, et annoncé comme compatible.
9. **Apps tierces** : affichées dans une iframe isolée par app, qui ne peut appeler que ses propres actions ; une app ouverte à la fois.
10. **Journal** : conservé sans limite de durée par défaut (`RetentionDays = 0`) ; Discord par convars, catégories `admin`, `money`, `alert` activées.
11. **Compatibilité dispatch** : adaptateurs ouverts `bridge/dispatch/` pour ps-dispatch, cd_dispatch et core_dispatch actifs par défaut (seulement si le vrai script n'est pas démarré), esx_service en option ; sans eux, le dispatch fonctionne avec les appels manuels, la détresse, `/secours` et l'export `DispatchAlert` (`BASE-API-11`).
12. **Mort et réveil** : détectés par le bridge (`Bridge.OnPlayerDeath` / `Bridge.OnPlayerRevived`) pour ESX, QBCore et Qbox, par événements et changements d'état uniquement, jamais par boucle (`BASE-MOT-02`).


> **Relecture croisée (24/11/2026)** : ce fichier a été aligné sur les 5 autres. Les noms communs (signaux, tables, réglages, droits, textes d'erreur, constantes) sont listés dans `00-sommaire.md`, qui fait foi en cas de doute.
