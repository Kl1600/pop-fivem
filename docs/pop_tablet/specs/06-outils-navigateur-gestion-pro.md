# 06 · Outils, Navigateur, Annuaire, Gestion pro

Fiches de fonctionnalités de POP Tablet pour : Notes, Calculatrice, Carte, Galerie (branche Outils), Navigateur, Annuaire, Tableur, Stock, Planning (Gestion pro). À lire avec `_contexte.md`, dont toutes les règles s'appliquent ici. « (ajout) » marque une fonctionnalité qui n'était pas dans la demande mais qu'il faut pour que l'app marche bien.

---

## 0. Conventions communes à ce fichier

Elles valent pour **toutes** les fiches ci-dessous. Quand une fiche dit « voir C3 », c'est la règle C3 ci-dessous.

- **C1 · Appels** : NUI → client Lua (`RegisterNUICallback`) → serveur par la porte d'entrée unique de la base, le callback `pop_tablet:request` (`Callback.*`, fiche 01 §0) ; `pop_tablet:<app>:<action>` dans les fiches = l'app et l'action passées par ce callback, pas un événement séparé. Le client Lua ne fait que transmettre, il ne vérifie rien d'important. Chaque réponse serveur est `{ ok = true, data = ... }` ou `{ ok = false, err = "<code commun ou clé de langue>", args = {...} }` (règle de la base : sans point = `commun.erreur.<code>`).
- **C2 · Identité** : `identifier` = identifiant du personnage renvoyé par le bridge (ESX `xPlayer.identifier`, QBCore / Qbox `citizenid` ; un par personnage en multi-personnage). Tout ce qui est « personnel » (notes, photos et albums, favoris, historique, points de carte) appartient à **la tablette** (numéro de série, colonne `owner` = `serial` de `pop_tablet_devices`), règle unique de la base (BASE-OBJ-14) : celui qui utilise la tablette d'un autre (vol, saisie police en lecture seule) voit ces données ; perdre la tablette les fait perdre, sauf remplacement par l'export `ReplaceTablet` / `TransferTabletData` (BASE-OBJ-08, appelé par la boutique du serveur ou un admin) qui les transfère vers le nouveau numéro ; la réinitialisation les efface. Sans inventaire à métadonnées, il y a une tablette par personnage (BASE-OBJ-15). Nom affiché d'un joueur = `Prénom N.` (prénom + initiale du nom ESX), jamais l'identifiant.
- **C3 · Tablette sur soi** : chaque callback commence par `Bridge.HasTablet(src)` (objet `Config.Item.Name = 'pop_tablet'` dans l'inventaire, fonction de la base). Sinon : `{ ok = false, err = 'commun.erreur.pas_tablette' }` → « Tablette introuvable dans l'inventaire. ».
- **C4 · Fréquence** : chaque callback passe par `RateLimit(src, '<app>:<action>')`. Défaut `Config.RateLimit.Default = { n = 5, s = 10 }` de la base (5 appels par 10 secondes ; plafond par action `Config.RateLimit.MaxPerAction = { n = 40, s = 10 }`). Dépassement : refus, texte `commun.erreur.trop_vite` « Trop d'actions. Réessayez dans quelques secondes. », et au 3e dépassement en 60 s une ligne au journal admin `rate_limit` (joueur, action). Les fiches donnent les valeurs spécifiques.
- **C5 · Nettoyage du texte** : tout texte joueur passe par `Sanitize.text(texte, max, multiline)` de la base (BASE-MOT-12) côté serveur : refus `trop_long` au-delà de `max` caractères (comptés en caractères Unicode, pas en octets ; la NUI empêche de taper ou coller au-delà), retire les caractères de contrôle (sauf saut de ligne `\n` quand le champ est multiligne), retire les espaces en début/fin, remplace les suites de plus de 2 sauts de ligne par 2. La NUI affiche **toujours** avec `textContent` (jamais `innerHTML`) : une balise tapée s'affiche en texte brut.
- **C6 · Images** : une image est soit une photo de la Galerie (référence `media:<id>`), soit une URL `https://` dont le domaine est dans `Config.Images.AllowedDomains` (défini dans la base) et qui finit par `.png`, `.jpg`, `.jpeg`, `.webp` ou `.gif` (`Config.Images.Extensions`), longueur max 300. Toute autre valeur est refusée : `commun.erreur.image` « Image refusée. Utilisez une photo de la galerie ou un lien d'un site autorisé. ».
- **C7 · Droits d'entreprise** : `Perm.Has(src, companyId, '<cle>')` lit le niveau (Recrue / Membre / Chef / Patron) du grade du joueur (ESX, QBCore ou Qbox, via le bridge) et la grille de droits de l'entreprise (branche Entreprises). Clés utilisées ici : `tableur.lire` (défaut Membre), `tableur.modifier` (Chef), `stock.lire` (Membre), `stock.modifier` (Chef), `planning.voir` (ajout, défaut Recrue), `planning.remplir` (Chef), `compte.voir` (Chef), `grades.gerer` (Patron), `demandes.repondre` (Membre), `site.modifier` (Chef). L'admin ACE `pop.tablet.admin` a tout, ses actions sont journalisées. Pas le droit : le bouton est **grisé** avec la bulle `commun.droit.grade_requis` « Grade requis : {grade} » ({grade} = nom du plus bas grade ESX de l'entreprise qui a le droit), et le serveur refuse avec `commun.erreur.pas_droit` « Vous n'avez pas les droits nécessaires. Grade requis : {grade}. ».
- **C8 · Service** : les apps de cette fiche (Outils, Navigateur, Annuaire, Gestion pro) **ne demandent pas** d'être en service (ce ne sont pas des apps métier) ; seul `Config.Pro.RequireDuty = false` peut l'imposer aux trois apps Gestion pro. Si `true` : hors service, l'app affiche l'écran Hors service de la base (« Hors service. » + bouton « Prendre mon service ») et le serveur refuse avec `commun.erreur.hors_service` « Service requis pour utiliser cette app. ».
- **C9 · Joueur proche** : le serveur calcule la distance avec `GetEntityCoords(GetPlayerPed(id))` (OneSync), jamais avec une position envoyée par le client. Défaut `Config.Limits.NearDistance = 3.0` mètres. La cible doit être connectée, avoir chargé son personnage, et ne pas être soi-même.
- **C10 · Anti double clic** : chaque action qui crée quelque chose envoie un `actionId` (UUID v4 généré par la NUI). Le serveur garde les `actionId` traités 10 min en mémoire (règle de la base) ; un `actionId` déjà vu renvoie la **même réponse** que la première fois sans refaire l'action. Le bouton passe aussi en état « chargement » (grisé) jusqu'à la réponse.
- **C11 · Base de données** : tables préfixées `pop_tablet_`, moteur InnoDB, `utf8mb4`. Dates stockées en `DATETIME` heure du serveur. Toutes les requêtes passent par oxmysql avec paramètres (`?`), jamais de texte concaténé. Écritures groupées : `WriteQueue.Push(sql, params)` = file d'écriture de la base (BASE-MOT-04 : minuterie de `Config.Storage.FlushInterval = 10` s lancée seulement quand la file n'est pas vide, ou dès `Config.Storage.FlushMax = 200` éléments, et à l'arrêt de la ressource) — utilisée quand la fiche le dit ; jusqu'à 10 s de saisies peuvent être perdues en cas de crash.
- **C12 · Dates et nombres affichés** : format de la langue. Français : `24/11/2026 14:05`, nombres `1 234,56` (espace fine insécable U+202F pour les milliers, virgule décimale), montants **entiers** `1 234 $` (aucun centime dans toute la tablette ; `Config.Currency.Symbol = '$'`, `Config.Currency.Position = 'after'`). Anglais : `11/24/2026 2:05 PM`, `1,234.56`, `$1,234`. Seul le Tableur affiche des montants à décimales (format Montant d'une cellule, sans effet sur l'argent du jeu).
- **C13 · États d'écran** : chaque écran suit les 6 états du contexte. Chargement : formes grises à la place des éléments, au-delà de 5 s texte `commun.chargement.long` (« Le chargement prend plus de temps que prévu. », fiche 01) + bouton « Réessayer » (`commun.bouton.reessayer`). Succès : bandeau 2 s en haut. Erreur : bandeau rouge sobre qui reste jusqu'à la prochaine action. Textes communs : référentiel unique de la fiche 01 (§0, repris dans `00-sommaire.md`) : `commun.erreur.*`, `commun.chargement.long`, `commun.bouton.annuler` / `enregistrer` / `supprimer` / `fermer`, `commun.pagination.suivant` / `precedent`, `commun.droit.grade_requis`, `commun.entreprise.archivee`.
- **C14 · Notifications** : `Notify.Send(identifier, { app, titre, texte, action })` de la base : n'envoie qu'aux joueurs connectés qui ont la tablette sur eux (C3). Tablette ouverte : bandeau en haut de la tablette 4 s, cliquable (ouvre `action`). Tablette fermée : notification du jeu (ox_lib `notify` si présent, sinon `Bridge.Notify` : ESX `ESX.ShowNotification`, QBCore `QBCore.Functions.Notify`, Qbox `exports.qbx_core:Notify`) avec le titre seul + pastille sur l'icône de l'app.
- **C15 · Entreprise archivée** : si l'entreprise du joueur est archivée (branche Entreprises), ses données Gestion pro restent en base, en lecture seule pour l'admin seulement ; pour les joueurs les apps affichent `commun.entreprise.archivee` « Cette entreprise n'existe plus. ».
- **C16 · Joueur de plusieurs entreprises** : si le joueur a un métier principal et des métiers secondaires (Qbox : plusieurs métiers natifs, `player_groups` ; ESX / QBCore : seulement si un script de second métier est relié au bridge), les apps Gestion pro affichent en haut un sélecteur « Entreprise : {nom} » listant ses entreprises ; sinon pas de sélecteur. L'entreprise choisie est renvoyée à chaque appel (`companyId`) et **revérifiée** par le serveur (le joueur doit vraiment en faire partie).

---

## 1. Notes (Outils)

Table commune à toutes les fiches Notes :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `id` | INT auto | oui | — | — |
| `owner` | VARCHAR(12), index | oui | numéro de série de la tablette (C2) | — |
| `title` | VARCHAR(60) | non | 0–`Config.Notes.MaxTitle` (60) car. | `''` |
| `content` | TEXT | non | 0–`Config.Notes.MaxContent` (5 000) car. | `''` |
| `pinned` | TINYINT(1) | oui | 0/1 | 0 |
| `shared_from` | VARCHAR(60) | non | nom affiché de l'expéditeur au moment du partage | NULL |
| `created_at` / `updated_at` | DATETIME | oui | — | maintenant |

Table `pop_tablet_notes`, index `(owner, pinned, updated_at)`.

### [OUT-NOT-01] Liste des notes
- **But** : voir toutes ses notes, les épinglées en premier.
- **Qui** : tout joueur avec la tablette. Non réglable.
- **Où** : Accueil > branche Outils > icône « Notes ».
- **Parcours** :
  1. Le joueur ouvre l'app. La NUI affiche l'état Chargement (6 lignes grises).
  2. Appel `pop_tablet:notes:list { page = 1 }`.
  3. Serveur : C3, C4 (10 / 5 s), lit `SELECT id, title, LEFT(content, 120), pinned, shared_from, updated_at FROM pop_tablet_notes WHERE owner = ? ORDER BY pinned DESC, updated_at DESC LIMIT 20 OFFSET ?` + le total.
  4. La NUI affiche : en haut le champ de recherche (OUT-NOT-04) et le bouton « + Nouvelle note » ; dessous une section « Épinglées » (si au moins une) puis « Toutes les notes ». Chaque ligne : titre (ou « Sans titre » en gris), 1re ligne du contenu coupée à 80 caractères avec « … », date relative (« À l'instant », « Il y a 5 min », « Aujourd'hui 14:05 », « Hier 09:12 », sinon date courte), icône punaise si épinglée, mention « Partagée par {nom} » si `shared_from`.
  5. Clic sur une ligne → ouvre l'éditeur (OUT-NOT-03). Pied de liste : pagination 20 par page, « {n} / {max} notes » (ex. « 12 / 100 notes »).
- **Données** : affichées = colonnes ci-dessus ; aucune écriture.
- **Règles serveur** : ne renvoie que les notes dont `owner` = identifiant du demandeur. `page` entier ≥ 1, sinon 1.
- **Textes et états** :
  - Vide : `notes.liste.vide` « Aucune note pour l'instant. » + bouton `notes.liste.creer` « Créer ma première note ».
  - Titre absent : `notes.liste.sans_titre` « Sans titre ».
  - Sections : `notes.liste.epinglees` « Épinglées », `notes.liste.toutes` « Toutes les notes ».
  - Compteur : `notes.liste.compteur` « {n} / {max} notes ».
  - Partage : `notes.liste.partagee_par` « Partagée par {nom} ».
  - Erreur : `commun.erreur.serveur`.
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : `Config.Notes.PageSize = 20`.
- **Journal admin** : non (données personnelles non sensibles).
- **Performance** : rien n'est chargé tant que l'app n'est pas ouverte ; seulement 120 caractères de contenu par note dans la liste ; la note complète est chargée à l'ouverture.
- **Cas limites** :
  - 0 note → état Vide.
  - Note créée sur un autre écran pendant que la liste est ouverte → la liste se recharge au retour sur l'écran (pas de push).
  - Page demandée au-delà de la dernière (note supprimée entre-temps) → le serveur renvoie la dernière page existante.
- **Critères d'acceptation** :
  - Étant donné 3 notes dont 1 épinglée, quand j'ouvre Notes, alors l'épinglée est en tête dans « Épinglées » et les 2 autres sont triées de la plus récente à la plus ancienne.
  - Étant donné 25 notes, quand j'ouvre Notes, alors 20 s'affichent et « Suivant » mène aux 5 autres.
  - Étant donné un client modifié qui envoie `notes:list` avec `owner` d'un autre joueur, quand le serveur répond, alors il ignore ce champ et ne renvoie que mes notes.

### [OUT-NOT-02] Créer une note
- **But** : écrire une nouvelle note.
- **Qui** : tout joueur avec la tablette.
- **Où** : Notes > liste > bouton « + Nouvelle note » (ou raccourci clavier `Ctrl+N` dans l'app).
- **Parcours** :
  1. Clic → l'éditeur s'ouvre vide : champ titre (placeholder « Titre »), zone de texte multiligne (placeholder « Note… »), en haut bouton retour « ← Notes », compteur « 0 / 5 000 ».
  2. Rien n'est créé en base tant que titre **et** contenu sont vides.
  3. Dès la première frappe, la NUI attend 2 s sans frappe (minuterie relancée à chaque touche, pas de boucle) puis appelle `pop_tablet:notes:save { id = nil, title, content, actionId }`.
  4. Serveur : C3, C4 (`notes:save` 10 / 10 s), C10, C5 (titre 60 sans saut de ligne, contenu 5 000 avec sauts de ligne), vérifie `COUNT(*) < Config.Notes.MaxPerPlayer`, `INSERT`, renvoie `{ id, updated_at }`.
  5. La NUI garde l'`id` : les sauvegardes suivantes sont des modifications (OUT-NOT-03). Indicateur discret sous le titre : « Enregistrement… » puis « Enregistré ».
  6. Le retour à la liste (bouton, Échap) force une sauvegarde immédiate si une frappe est en attente.
- **Données** : voir table. Le titre est coupé net à 60 caractères à la saisie (attribut `maxlength`), le contenu à 5 000.
- **Règles serveur** : limite du nombre de notes ; nettoyage C5 ; `actionId` obligatoire pour la création (C10) pour ne jamais créer 2 notes sur un double envoi.
- **Textes et états** :
  - `notes.editeur.titre_placeholder` « Titre », `notes.editeur.contenu_placeholder` « Note… ».
  - `notes.editeur.enregistrement` « Enregistrement… », `notes.editeur.enregistre` « Enregistré ».
  - `notes.editeur.compteur` « {n} / {max} ».
  - Limite : `notes.erreur.limite` « Limite de {max} notes atteinte. » (le bouton « + Nouvelle note » est aussi grisé dans la liste quand le compteur est plein).
  - Échec : `notes.erreur.non_enregistre` « Note non enregistrée. Restez sur cet écran et réessayez. » + bouton « Réessayer ».
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : `Config.Notes.MaxPerPlayer = 100`, `Config.Notes.MaxTitle = 60`, `Config.Notes.MaxContent = 5000`, `Config.Notes.AutosaveDelayMs = 2000`.
- **Journal admin** : non.
- **Performance** : une seule requête par pause de 2 s, jamais par touche.
- **Cas limites** :
  - Joueur qui ferme la tablette pendant l'attente des 2 s → la fermeture déclenche la sauvegarde avant de vider la NUI.
  - Joueur déconnecté avant la réponse → la note est créée si la requête est arrivée ; sinon rien (pas de brouillon).
  - Collage d'un texte de 8 000 caractères → la zone garde les 5 000 premiers, le compteur passe en couleur d'accent et affiche « 5 000 / 5 000 ».
- **Critères d'acceptation** :
  - Étant donné l'éditeur vide, quand je tape « Courses » puis attends 2 s, alors une note « Courses » existe en base et « Enregistré » s'affiche.
  - Étant donné 100 notes, quand je clique « + Nouvelle note », alors le bouton est grisé et le message de limite s'affiche.
  - Étant donné un client modifié qui envoie un contenu de 20 000 caractères, quand le serveur enregistre, alors seuls 5 000 caractères sont stockés.
  - Étant donné deux envois avec le même `actionId`, quand le serveur les reçoit, alors une seule note est créée.

### [OUT-NOT-03] Modifier une note
- **But** : ouvrir une note et la changer.
- **Qui** : le propriétaire de la note uniquement.
- **Où** : Notes > liste > clic sur une note.
- **Parcours** :
  1. Clic → `pop_tablet:notes:get { id }` → serveur vérifie `owner` et renvoie la note entière.
  2. L'éditeur affiche titre et contenu, la date « Modifiée le {date} », et une barre d'actions : « Épingler » (OUT-NOT-05), « Partager » (OUT-NOT-07), « Supprimer » (OUT-NOT-06).
  3. Chaque pause de 2 s après une frappe → `pop_tablet:notes:save { id, title, content }`.
  4. Serveur : C3, C4, vérifie `owner`, C5, `UPDATE ... SET title, content, updated_at = NOW() WHERE id = ? AND owner = ?`.
  5. Si titre et contenu deviennent tous les deux vides et que le joueur quitte l'éditeur, la NUI propose : « Cette note est vide. La supprimer ? » [Supprimer] [Garder].
- **Données** : voir table.
- **Règles serveur** : propriétaire obligatoire ; sinon `notes.erreur.introuvable`.
- **Textes et états** :
  - `notes.editeur.modifiee_le` « Modifiée le {date} ».
  - `notes.erreur.introuvable` « Cette note n'existe plus. » (retour automatique à la liste).
  - `notes.editeur.vide_supprimer` « Cette note est vide. La supprimer ? », boutons `commun.bouton.supprimer`, `notes.editeur.garder` « Garder ».
  - Succès : indicateur « Enregistré » (pas de bandeau).
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : ceux de OUT-NOT-02.
- **Journal admin** : non.
- **Performance** : 1 lecture à l'ouverture, 1 écriture par pause de frappe.
- **Cas limites** :
  - Note supprimée depuis un autre écran (ex. deux onglets impossibles ici, mais suppression par l'admin) → message introuvable et retour liste.
  - Tablette prise par un autre joueur : il voit les notes de cette tablette ; ses propres notes restent sur sa tablette à lui (C2).
  - Échec réseau sur une sauvegarde → le texte reste dans l'éditeur, message `notes.erreur.non_enregistre`, nouvelle tentative à la frappe suivante ou au clic « Réessayer ».
- **Critères d'acceptation** :
  - Étant donné une note, quand je change son titre et attends 2 s, alors la liste montre le nouveau titre en tête (date de modification la plus récente).
  - Étant donné un client modifié qui envoie `notes:save` avec l'`id` d'une note d'un autre joueur, quand le serveur traite, alors rien n'est modifié et la réponse est `notes.erreur.introuvable`.
  - Étant donné une note vidée, quand je quitte l'éditeur, alors la question « La supprimer ? » s'affiche.

### [OUT-NOT-04] Rechercher dans ses notes
- **But** : retrouver une note par un mot du titre ou du contenu.
- **Qui** : tout joueur avec la tablette.
- **Où** : Notes > liste > champ « Rechercher une note » en haut (raccourci `Ctrl+F`).
- **Parcours** :
  1. Le joueur tape. À partir de 2 caractères, la NUI attend 300 ms sans frappe puis appelle `pop_tablet:notes:search { q, page }`.
  2. Serveur : C3, C4 (10 / 5 s), nettoie `q` (C5, 40 car.), échappe `%`, `_` et `\`, requête `WHERE owner = ? AND (title LIKE ? OR content LIKE ?)` avec `%q%`, insensible à la casse et aux accents (collation `utf8mb4_unicode_ci`), même tri que la liste, 20 par page.
  3. La NUI affiche les résultats avec le mot trouvé surligné en couleur d'accent (surlignage fait en découpant le texte et en créant des `<mark>` via `textContent`, jamais `innerHTML`).
  4. Croix dans le champ ou champ vidé → retour à la liste normale.
- **Données** : `q` texte 2–40 caractères.
- **Règles serveur** : ne cherche que dans les notes du joueur ; `q` < 2 caractères → renvoie la liste normale.
- **Textes et états** :
  - `notes.recherche.placeholder` « Rechercher une note ».
  - Aucun résultat : `notes.recherche.vide` « Aucune note ne contient « {q} ». ».
  - Résultats : `notes.recherche.resultats` « {n} résultat(s) ».
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : `Config.Notes.SearchMinChars = 2`, `Config.Notes.SearchDebounceMs = 300`.
- **Journal admin** : non.
- **Performance** : 1 requête par pause de 300 ms ; index sur `owner` limite la recherche aux ≤ 100 notes du joueur.
- **Cas limites** :
  - Recherche « 100% » → le `%` est cherché comme caractère, pas comme joker.
  - Recherche « eleve » trouve « Élève » (accents ignorés).
  - Résultat ouvert puis retour → la recherche et la page restent affichées.
- **Critères d'acceptation** :
  - Étant donné une note dont le contenu contient « garage », quand je tape « gara », alors elle apparaît avec « gara » surligné.
  - Étant donné la recherche « <b>x</b> », quand les résultats s'affichent, alors aucune mise en gras n'apparaît (texte brut).
  - Étant donné un client modifié qui envoie `q = "%"`, quand le serveur cherche, alors seules les notes contenant le caractère « % » sortent.

### [OUT-NOT-05] Épingler / désépingler une note
- **But** : garder une note importante en haut de la liste.
- **Qui** : le propriétaire.
- **Où** : Notes > éditeur > bouton « Épingler » / « Désépingler » ; Notes > liste > clic droit (ou appui long 500 ms) sur une ligne > « Épingler ».
- **Parcours** :
  1. Clic → `pop_tablet:notes:pin { id, pinned = true|false }`.
  2. Serveur : C3, C4, vérifie `owner`, si `pinned = true` vérifie `COUNT(pinned) < Config.Notes.MaxPinned`, `UPDATE pinned` (ne change pas `updated_at`).
  3. Bandeau succès, la liste se réordonne.
- **Données** : `pinned` 0/1.
- **Règles serveur** : propriétaire ; maximum 10 épinglées.
- **Textes et états** :
  - Boutons `notes.action.epingler` « Épingler », `notes.action.desepingler` « Désépingler ».
  - Succès : `notes.succes.epinglee` « Note épinglée. », `notes.succes.desepinglee` « Note désépinglée. ».
  - Limite : `notes.erreur.limite_epingle` « {max} notes épinglées maximum. ».
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : `Config.Notes.MaxPinned = 10`.
- **Journal admin** : non.
- **Performance** : 1 requête.
- **Cas limites** :
  - Épingler une note déjà épinglée → réponse ok sans changement.
  - Double clic → C4 + l'état final est le même (opération idempotente).
  - Note partagée reçue → épinglable comme les autres.
- **Critères d'acceptation** :
  - Étant donné une note non épinglée, quand je clique « Épingler », alors elle passe dans « Épinglées ».
  - Étant donné 10 notes épinglées, quand j'en épingle une 11e, alors le message de limite s'affiche et rien ne change.
  - Étant donné un client modifié qui épingle l'`id` d'un autre joueur, alors le serveur refuse avec `notes.erreur.introuvable`.

### [OUT-NOT-06] Supprimer une note
- **But** : effacer une note devenue inutile.
- **Qui** : le propriétaire.
- **Où** : Notes > éditeur > « Supprimer » ; Notes > liste > clic droit / appui long > « Supprimer ».
- **Parcours** :
  1. Clic → fenêtre de confirmation : « Supprimer cette note ? Elle sera définitivement effacée. » [Supprimer] [Annuler]. Entrée = Supprimer, Échap = Annuler.
  2. `pop_tablet:notes:delete { id }` → serveur : C3, C4, `DELETE FROM pop_tablet_notes WHERE id = ? AND owner = ?`.
  3. Retour à la liste, bandeau succès.
- **Données** : suppression réelle de la ligne (les notes ne sont pas des données sensibles au sens du contexte).
- **Règles serveur** : propriétaire uniquement.
- **Textes et états** :
  - `notes.supprimer.confirmer` « Supprimer cette note ? Elle sera définitivement effacée. ».
  - Succès : `notes.succes.supprimee` « Note supprimée. ».
  - Erreur : `notes.erreur.introuvable`.
- **Notifications** : aucune.
- **Liens** : aucun. Les copies déjà partagées à d'autres joueurs (OUT-NOT-07) ne sont pas touchées.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : 1 requête.
- **Cas limites** :
  - Double clic sur « Supprimer » → la 2e requête ne trouve plus la note : la NUI ignore l'erreur introuvable si elle suit une suppression réussie du même `id`.
  - Note déjà supprimée → message introuvable, retour liste.
  - Suppression pendant une sauvegarde automatique en attente → la NUI annule la minuterie avant d'envoyer la suppression.
- **Critères d'acceptation** :
  - Étant donné une note, quand je confirme la suppression, alors elle disparaît de la liste et de la base.
  - Étant donné la fenêtre de confirmation, quand j'appuie sur Échap, alors la note est gardée.
  - Étant donné un client modifié qui supprime l'`id` d'un autre joueur, alors aucune ligne n'est effacée.

### [OUT-NOT-07] Partager une note avec un joueur proche
- **But** : donner une copie de sa note à quelqu'un à côté de soi.
- **Qui** : le propriétaire ; destinataire = joueur à moins de 3 m qui a une tablette.
- **Où** : Notes > éditeur > bouton « Partager ».
- **Parcours** :
  1. Clic → `pop_tablet:notes:nearby` → serveur : C3, C4 (3 / 10 s), liste les joueurs à ≤ `Config.Limits.NearDistance` (C9) **qui ont la tablette** (C3 appliqué à eux), triés par distance, max 8.
  2. La NUI affiche une liste. Si `Config.Tools.ShowNearbyNames = false` (défaut) chaque ligne affiche « Personne proche · {distance} m » (distance arrondie à 0,1 m) ; si `true`, le nom affiché (C2) + distance. Le serveur renvoie pour chaque ligne un jeton à usage unique (`token`, valable 30 s) et **pas** l'ID serveur du joueur.
  3. Le joueur choisit → `pop_tablet:notes:share { id, token, actionId }`.
  4. Serveur : C3, C4, C10, vérifie le propriétaire, retrouve la cible par `token`, revérifie distance et tablette, vérifie qu'aucune proposition de cette note vers cette cible n'est déjà en attente, garde en mémoire `{ from, to, noteId, expire = maintenant + 60 s }`.
  5. Le destinataire reçoit la proposition (OUT-NOT-08). L'expéditeur voit « Proposition envoyée. En attente de réponse… » puis le résultat.
- **Données** : `token` (32 car. aléatoires, mémoire serveur), proposition en mémoire (non stockée en base).
- **Règles serveur** : distance revérifiée à l'envoi **et** à l'acceptation ; max `Config.Notes.MaxPendingShares = 3` propositions en attente par expéditeur ; une note vide (titre et contenu vides) ne se partage pas.
- **Textes et états** :
  - Titre fenêtre : `notes.partage.titre` « Partager avec… ».
  - Ligne : `notes.partage.personne` « Personne proche · {distance} m ».
  - Personne : `notes.partage.personne_absente` « Personne avec une tablette à moins de {distance} m. ».
  - Envoyé : `notes.partage.envoye` « Proposition envoyée. En attente de réponse… ».
  - Acceptée : `notes.partage.acceptee` « La note a été acceptée. ». Refusée : `notes.partage.refusee` « La note a été refusée. ». Expirée : `notes.partage.expiree` « Pas de réponse : partage annulé. ».
  - Trop loin : `commun.erreur.trop_loin` « Cette personne est trop loin (maximum {distance} m). ».
  - Note vide : `notes.erreur.partage_vide` « Note vide. ».
  - Déjà en attente : `notes.erreur.partage_en_attente` « Une proposition est déjà en attente pour cette personne. ».
- **Notifications** : voir OUT-NOT-08.
- **Liens** : aucun.
- **Réglages** : `Config.Limits.NearDistance = 3.0`, `Config.Tools.ShowNearbyNames = false`, `Config.Notes.ShareTimeoutSec = 60`, `Config.Notes.MaxPendingShares = 3`.
- **Journal admin** : non.
- **Performance** : liste des joueurs proches calculée seulement au clic, en parcourant les joueurs du même routing bucket uniquement ; propositions en mémoire, nettoyées à leur expiration par un `SetTimeout` unique par proposition.
- **Cas limites** :
  - Destinataire déconnecté avant de répondre → proposition annulée, l'expéditeur reçoit `notes.partage.expiree`.
  - Destinataire parti à 10 m avant d'accepter → acceptation refusée, les deux voient `commun.erreur.trop_loin`.
  - Joueur dans un autre routing bucket à 1 m (instance) → n'apparaît pas.
  - Jeton réutilisé ou expiré → `commun.erreur.serveur` et la liste des proches est rechargée.
- **Critères d'acceptation** :
  - Étant donné un joueur avec tablette à 2 m, quand je partage ma note et qu'il accepte, alors il a une copie avec « Partagée par … » et ma note est inchangée.
  - Étant donné personne à moins de 3 m, quand je clique « Partager », alors le message « Personne avec une tablette… » s'affiche.
  - Étant donné un client modifié qui envoie l'ID serveur d'un joueur à 200 m au lieu d'un jeton, alors le serveur refuse et rien n'est proposé.

### [OUT-NOT-08] Recevoir une note partagée (ajout)
- **But** : accepter ou refuser une note qu'on vous propose.
- **Qui** : destinataire d'une proposition (OUT-NOT-07).
- **Où** : fenêtre qui s'ouvre sur la tablette (si ouverte) ou notification.
- **Parcours** :
  1. Serveur → client du destinataire : `pop_tablet:notes:offer { offerId, fromLabel, title }`. `fromLabel` = « Une personne proche » si `ShowNearbyNames = false`, sinon le nom affiché.
  2. Tablette ouverte : fenêtre « {fromLabel} vous partage une note : « {titre} » » [Accepter] [Refuser], compte à rebours de 60 s. Tablette fermée : notification du jeu « Note proposée. Ouvrez la tablette pour répondre. » et la fenêtre s'affiche à l'ouverture si la proposition n'a pas expiré.
  3. Accepter → `pop_tablet:notes:answer { offerId, accept = true }` → serveur revérifie distance (C9) et tablette des deux, vérifie la limite de 100 notes du destinataire, `INSERT` d'une copie (titre, contenu, `shared_from` = nom affiché de l'expéditeur si `ShowNearbyNames`, sinon `'—'`, `pinned = 0`).
  4. Refuser ou expiration → proposition effacée, expéditeur prévenu.
- **Données** : copie complète de la note ; aucune liaison entre la note d'origine et la copie.
- **Règles serveur** : proposition existante, destinée à ce joueur, non expirée ; limite de notes du destinataire.
- **Textes et états** :
  - `notes.reception.question` « {de} vous partage une note : « {titre} » ».
  - `notes.reception.une_personne` « Une personne proche ».
  - Boutons `notes.reception.accepter` « Accepter », `notes.reception.refuser` « Refuser ».
  - Succès : `notes.reception.ajoutee` « Note ajoutée. ».
  - Limite : `notes.reception.limite` « Limite de {max} notes atteinte. » (l'expéditeur reçoit `notes.partage.refusee`).
  - Expirée : `notes.reception.expiree` « Cette proposition a expiré. ».
- **Notifications** : destinataire tablette fermée : titre `notes.notif.proposee` « Note proposée. Ouvrez la tablette pour répondre. ».
- **Liens** : aucun.
- **Réglages** : ceux de OUT-NOT-07.
- **Journal admin** : non.
- **Performance** : rien tant qu'aucune proposition n'existe.
- **Cas limites** :
  - Deux propositions reçues en même temps → affichées l'une après l'autre (file, max 3).
  - Accepter deux fois (double clic) → la 2e réponse ne trouve plus la proposition et est ignorée par la NUI.
  - Destinataire sans place → refus propre, aucune note créée.
- **Critères d'acceptation** :
  - Étant donné une proposition, quand je clique « Accepter » sous 60 s, alors la note apparaît dans ma liste.
  - Étant donné une proposition, quand 60 s passent, alors la fenêtre se ferme avec « Cette proposition a expiré. ».
  - Étant donné un client modifié qui envoie `answer` avec l'`offerId` destiné à un autre joueur, alors le serveur refuse.

---

## 2. Calculatrice (Outils)

Calculatrice 100 % côté NUI : aucun appel serveur, aucune donnée en base, pas d'argent en jeu. Le calcul n'utilise **jamais** `eval()` ni `new Function()` : la NUI découpe la saisie en éléments (nombres, opérateurs) et calcule elle-même.

Écran unique : en haut la ligne « expression » (petite, gris clair, ex. `12 + 3 × 4`), dessous la ligne « résultat / saisie en cours » (grande, blanche) ; à droite un bouton « Historique » (icône horloge). Clavier 4 colonnes × 5 lignes :

```
 C    ⌫    %    ÷
 7    8    9    ×
 4    5    6    −
 1    2    3    +
 ±    0    ,    =
```
La touche décimale affiche `,` en français et `.` en anglais ; en interne c'est toujours un point.

### [OUT-CAL-01] Saisie des nombres (touches 0–9 et virgule)
- **But** : taper un nombre.
- **Qui** : tout joueur avec la tablette.
- **Où** : Outils > Calculatrice > touches 0 à 9 et `,`.
- **Parcours** :
  1. Chaque chiffre s'ajoute à droite du nombre en cours, affiché sur la grande ligne avec séparateur de milliers (C12).
  2. Un `0` seul en début est remplacé par le chiffre suivant (`0` puis `7` → `7`) ; `0` puis `,` → `0,`.
  3. `,` sur un nombre vide → `0,`. Une 2e `,` dans le même nombre est ignorée (petite vibration visuelle de la touche : décalage 2 px pendant 100 ms).
  4. Après un `=` (OUT-CAL-03), taper un chiffre ou `,` commence un nouveau calcul (l'expression est effacée).
- **Données** : nombre en cours : 15 chiffres significatifs max (hors virgule et signe), dont 10 décimales max. Au-delà, la touche est ignorée avec la même vibration.
- **Règles serveur** : aucune (rien n'est envoyé).
- **Textes et états** : aucun texte ; état initial « 0 » sur la grande ligne, expression vide.
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : `Config.Calculator.MaxDigits = 15`, `Config.Calculator.MaxDecimals = 10`.
- **Journal admin** : non.
- **Performance** : aucune requête ; rendu limité à la mise à jour de 2 lignes de texte.
- **Cas limites** :
  - 16e chiffre → ignoré.
  - `,` tapée deux fois → une seule virgule.
  - `0000` → affiche `0`.
- **Critères d'acceptation** :
  - Étant donné l'écran à 0, quand je tape 1, 2, 3, 4, alors s'affiche « 1 234 ».
  - Étant donné « 3,1 », quand je tape `,`, alors l'affichage reste « 3,1 ».
  - Étant donné 15 chiffres tapés, quand j'en tape un 16e, alors rien ne s'ajoute.

### [OUT-CAL-02] Opérateurs + − × ÷ et priorité des opérations
- **But** : enchaîner des opérations avec la bonne priorité.
- **Qui** : tout joueur avec la tablette.
- **Où** : Calculatrice > touches `+`, `−`, `×`, `÷`.
- **Parcours** :
  1. Un opérateur termine le nombre en cours et l'ajoute avec l'opérateur à la ligne expression (ex. `12 +`). La grande ligne garde le nombre jusqu'à la frappe suivante.
  2. Deux opérateurs de suite : le 2e **remplace** le 1er (`12 +` puis `×` → `12 ×`).
  3. Opérateur sur un écran vide (« 0 » initial) : le premier nombre vaut 0 (`0 −`).
  4. Après `=`, un opérateur continue à partir du résultat (`= 15` puis `+` → `15 +`).
  5. Le calcul suit la priorité : `×` et `÷` d'abord, de gauche à droite, puis `+` et `−` de gauche à droite. Ex. `2 + 3 × 4 = 14`, `20 ÷ 4 × 2 = 10`, `10 − 4 − 3 = 3`. Pas de parenthèses dans la calculatrice.
  6. Pendant la saisie, la grande ligne n'affiche pas de résultat intermédiaire (on ne calcule qu'au `=`).
- **Données** : expression = liste d'au plus 30 éléments (nombres + opérateurs). Au-delà, les opérateurs sont ignorés (vibration).
- **Règles serveur** : aucune.
- **Textes et états** : symboles affichés `+`, `−` (U+2212), `×`, `÷`.
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : `Config.Calculator.MaxTokens = 30`.
- **Journal admin** : non.
- **Performance** : calcul en deux passes sur ≤ 30 éléments.
- **Cas limites** :
  - `5 × −` : remplace `×` par `−` (pas de nombre négatif tapé ainsi ; utiliser `±`, OUT-CAL-05).
  - 31e élément → ignoré.
  - Opérateur juste après `±` sur un nombre vide → `0` négatif devient `0`.
- **Critères d'acceptation** :
  - Étant donné `2 + 3 × 4`, quand j'appuie sur `=`, alors s'affiche 14.
  - Étant donné `8 ÷ 2 ÷ 2`, quand j'appuie sur `=`, alors s'affiche 2.
  - Étant donné `12 +`, quand j'appuie sur `×`, alors l'expression devient `12 ×`.

### [OUT-CAL-03] Touche égal et affichage du résultat
- **But** : obtenir le résultat.
- **Qui** : tout joueur avec la tablette.
- **Où** : Calculatrice > touche `=` (ou Entrée).
- **Parcours** :
  1. `=` ajoute le nombre en cours, ignore un opérateur final sans nombre (`12 + =` → calcule `12`).
  2. Calcul avec la priorité d'OUT-CAL-02.
  3. Arrondi : 10 décimales max, puis suppression des zéros inutiles (`0,1 + 0,2` → `0,3`, `10 ÷ 3` → `3,3333333333`).
  4. Ligne expression : `12 + 3 × 4 =` ; grande ligne : `24`.
  5. Le calcul complet est ajouté à l'historique (OUT-CAL-07).
  6. `=` à nouveau sans nouvelle saisie : ne fait rien.
- **Données** : résultat affiché avec séparateurs (C12). Si |résultat| ≥ 10^15 → erreur « Nombre trop grand » (OUT-CAL-06). Si |résultat| < 10^-10 et ≠ 0 → affiche `0`.
- **Règles serveur** : aucune.
- **Textes et états** : aucun texte hors erreurs (OUT-CAL-06).
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : `Config.Calculator.ResultDecimals = 10`.
- **Journal admin** : non.
- **Performance** : instantané.
- **Cas limites** :
  - `=` sur l'écran initial → rien ne change, rien dans l'historique.
  - `5 =` → résultat 5, ajouté à l'historique.
  - Résultat négatif → signe `−` devant (`3 − 5 = −2`).
- **Critères d'acceptation** :
  - Étant donné `0,1 + 0,2`, quand j'appuie sur `=`, alors s'affiche « 0,3 ».
  - Étant donné un résultat affiché, quand je tape 7, alors un nouveau calcul commence avec 7.
  - Étant donné `12 +`, quand j'appuie sur `=`, alors s'affiche 12.

### [OUT-CAL-04] Effacer : touches C et ⌫
- **But** : corriger une saisie.
- **Qui** : tout joueur avec la tablette.
- **Où** : Calculatrice > touche `C` (ou Suppr), touche `⌫` (ou Retour arrière).
- **Parcours** :
  1. `C` : efface tout (expression + nombre en cours), affiche `0`. Ne touche pas à l'historique.
  2. `⌫` : retire le dernier caractère du nombre en cours (`1 234` → `123`) ; si le nombre en cours est vide, retire le dernier opérateur de l'expression et remet le nombre précédent en saisie (`12 +` → `12` modifiable).
  3. Après `=`, `⌫` ne modifie pas le résultat (rien ne se passe) ; `C` remet à zéro.
  4. Après une erreur (OUT-CAL-06), `C` ou `⌫` remettent à `0`.
- **Données** : aucune.
- **Règles serveur** : aucune.
- **Textes et états** : aucun.
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : instantané.
- **Cas limites** :
  - `⌫` sur `0` → reste `0`.
  - `⌫` sur `0,` → `0`.
  - `⌫` sur `−5` (après ±) → `−` retiré avec le 5 : affiche `0`.
- **Critères d'acceptation** :
  - Étant donné `12 + 34`, quand j'appuie sur `⌫`, alors s'affiche `12 + 3`.
  - Étant donné `12 +`, quand j'appuie sur `⌫`, alors l'expression devient `12` en saisie.
  - Étant donné n'importe quel état, quand j'appuie sur `C`, alors s'affiche `0` et l'historique est intact.

### [OUT-CAL-05] Touches % et ± (ajout)
- **But** : calculer un pourcentage et changer le signe.
- **Qui** : tout joueur avec la tablette.
- **Où** : Calculatrice > touches `%` et `±`.
- **Parcours** :
  1. `±` : inverse le signe du nombre en cours (`5` → `−5` → `5`). Sur un nombre vide, ne fait rien. Après `=`, inverse le signe du résultat et le remet en saisie.
  2. `%` sur le nombre en cours B :
     - si l'opérateur juste avant est `+` ou `−` et qu'il y a un nombre A avant : B devient A × B ÷ 100 (ex. `200 + 10 %` → `200 + 20`, `=` → 220 ; `200 − 10 %` → `200 − 20`) ;
     - si l'opérateur juste avant est `×` ou `÷`, ou s'il n'y a pas d'opérateur : B devient B ÷ 100 (ex. `50 × 10 %` → `50 × 0,1` → 5 ; `10 %` seul → `0,1`).
  3. La grande ligne affiche immédiatement la nouvelle valeur de B.
- **Données** : valeur arrondie à 10 décimales.
- **Règles serveur** : aucune.
- **Textes et états** : aucun.
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : instantané.
- **Cas limites** :
  - `%` sur un nombre vide → ignoré.
  - `%` deux fois → appliqué deux fois (`10 %` → `0,1` → `0,001`).
  - `±` sur `0` → reste `0`.
- **Critères d'acceptation** :
  - Étant donné `200 + 10`, quand j'appuie sur `%` puis `=`, alors s'affiche 220.
  - Étant donné `50 × 10`, quand j'appuie sur `%` puis `=`, alors s'affiche 5.
  - Étant donné `7`, quand j'appuie sur `±`, alors s'affiche `−7`.

### [OUT-CAL-06] Erreurs de calcul (division par zéro, nombre trop grand)
- **But** : dire clairement quand un calcul est impossible.
- **Qui** : tout joueur avec la tablette.
- **Où** : Calculatrice > au `=`.
- **Parcours** :
  1. Division par zéro n'importe où dans l'expression (`5 ÷ 0`, `1 + 4 ÷ 0 × 2`) → la grande ligne affiche le message d'erreur en taille réduite, l'expression reste visible. Rien n'entre dans l'historique.
  2. |résultat| ≥ 10^15 (ou un calcul intermédiaire le dépasse) → message « Nombre trop grand ».
  3. La touche suivante : `C`/`⌫` → `0` ; un chiffre → nouveau calcul ; un opérateur → part de `0`.
- **Données** : aucune.
- **Règles serveur** : aucune.
- **Textes et états** :
  - `calculatrice.erreur.division_zero` « Division par zéro impossible ».
  - `calculatrice.erreur.trop_grand` « Nombre trop grand ».
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : `Config.Calculator.MaxAbsValue = 1e15`.
- **Journal admin** : non.
- **Performance** : instantané.
- **Cas limites** :
  - `0 ÷ 0` → division par zéro.
  - `0 ÷ 5` → 0 (pas d'erreur).
  - `999999999999999 × 9` → trop grand.
- **Critères d'acceptation** :
  - Étant donné `5 ÷ 0`, quand j'appuie sur `=`, alors s'affiche « Division par zéro impossible » et l'historique ne change pas.
  - Étant donné l'erreur affichée, quand je tape 3, alors s'affiche 3.
  - Étant donné un résultat de 10^16, alors s'affiche « Nombre trop grand ».

### [OUT-CAL-07] Historique des calculs
- **But** : revoir et réutiliser ses derniers calculs.
- **Qui** : tout joueur avec la tablette.
- **Où** : Calculatrice > bouton « Historique » (icône horloge).
- **Parcours** :
  1. Chaque `=` réussi ajoute `{ expression, resultat, date }` en tête de liste.
  2. Le bouton ouvre un panneau latéral (droite, 40 % de la largeur) avec les 20 derniers calculs : expression en gris, résultat en blanc, heure.
  3. Clic sur une ligne → le résultat devient le nombre en cours (nouveau calcul, expression vide), le panneau se ferme.
  4. Bouton « Effacer l'historique » en bas → confirmation « Effacer tout l'historique ? » [Effacer] [Annuler].
  5. Stockage : `localStorage` de la NUI, clé `pop_tablet_calc_history_<serial>` (numéro de série de la tablette ouverte, envoyé par le client Lua à l'ouverture ; historique local à l'ordinateur du joueur, non transféré). Rien n'est envoyé au serveur.
- **Données** : 20 entrées max (la plus ancienne sort), expression ≤ 120 caractères.
- **Règles serveur** : aucune.
- **Textes et états** :
  - Titre : `calculatrice.historique.titre` « Historique ».
  - Vide : `calculatrice.historique.vide` « Aucun calcul pour l'instant. » (pas de bouton : on commence en calculant).
  - `calculatrice.historique.effacer` « Effacer l'historique », `calculatrice.historique.confirmer` « Effacer tout l'historique ? », bouton `calculatrice.historique.bouton_effacer` « Effacer ».
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : `Config.Calculator.HistorySize = 20`.
- **Journal admin** : non.
- **Performance** : lecture du `localStorage` à l'ouverture de l'app seulement.
- **Cas limites** :
  - `localStorage` vidé (cache FiveM effacé) → historique vide, pas d'erreur.
  - 21e calcul → le plus ancien disparaît.
  - `localStorage` corrompu (JSON illisible) → remis à vide.
- **Critères d'acceptation** :
  - Étant donné 3 calculs faits, quand j'ouvre l'historique, alors ils apparaissent du plus récent au plus ancien.
  - Étant donné une ligne de l'historique avec résultat 42, quand je clique dessus, alors 42 devient le nombre en cours.
  - Étant donné une erreur de division par zéro, alors rien n'est ajouté à l'historique.

### [OUT-CAL-08] Clavier physique (ajout)
- **But** : utiliser la calculatrice au clavier.
- **Qui** : tout joueur avec la tablette.
- **Où** : Calculatrice, quand l'app est au premier plan et qu'aucun champ texte n'a le focus.
- **Parcours** : correspondances :
  - `0`–`9` (rangée et pavé numérique) → chiffres ;
  - `,` et `.` (et `Décimal` du pavé) → virgule ;
  - `+`, `-`, `*`, `/` (et pavé) → `+`, `−`, `×`, `÷` ;
  - `x` → `×` ; `%` → `%` ;
  - `Entrée`, `=` → `=` ;
  - `Retour arrière` → `⌫` ; `Suppr` → `C` ;
  - `F9` → `±` ;
  - `Échap` → règle générale (retour / fermeture), jamais « effacer ».
  La touche à l'écran s'allume 100 ms (couleur d'accent) à chaque frappe.
- **Données** : aucune.
- **Règles serveur** : aucune.
- **Textes et états** : aucun.
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : un seul écouteur `keydown` posé à l'ouverture de l'app et retiré à sa fermeture.
- **Cas limites** :
  - Panneau Historique ouvert → les touches chiffres continuent de saisir ; Échap ferme le panneau.
  - Touche maintenue → répétition du navigateur acceptée (même limites de longueur).
  - Disposition AZERTY : on lit `event.key` (le caractère), pas `event.code`.
- **Critères d'acceptation** :
  - Étant donné la calculatrice ouverte, quand je tape `2*3` puis Entrée, alors s'affiche 6.
  - Étant donné un calcul en cours, quand j'appuie sur Échap, alors l'app revient à l'écran précédent sans effacer.
  - Étant donné `Suppr`, alors tout est remis à 0.

---

## 3. Carte (Outils)

Carte affichée avec **Leaflet 1.9.4** livré dans la ressource (`html/vendor/leaflet/`, aucun CDN), en mode `L.CRS.Simple`. Tuiles livrées dans `html/img/map/{z}/{x}/{y}.webp`, zoom 0 à 5, 256 px, style sombre (`Config.Map.Style = 'sombre'`, autre valeur possible `'satellite'` si le dossier `html/img/map_satellite/` est fourni). Conversion position du jeu → carte (valeurs de calibrage modifiables) :

```
lng = Config.Map.Calib.centerX + Config.Map.Calib.scaleX * x     -- centerX = 117.3, scaleX = 0.02072
lat = Config.Map.Calib.centerY + Config.Map.Calib.scaleY * y     -- centerY = 172.8, scaleY = 0.0205
```
(transformation Leaflet `L.Transformation(1, 0, -1, 0)` sur un CRS de base 256). Le développeur vérifie le calage sur 3 points connus (commissariat Mission Row, hôpital Pillbox, aéroport LSIA) et ajuste ces 4 valeurs si l'écart dépasse 15 m.

### [OUT-CAR-01] Afficher la carte de la ville
- **But** : voir la ville et sa propre position.
- **Qui** : tout joueur avec la tablette.
- **Où** : Accueil > branche Outils > icône « Carte ».
- **Parcours** :
  1. Ouverture → la NUI crée la carte, centrée sur la position du joueur, zoom 3.
  2. Le client Lua envoie la position (`GetEntityCoords(PlayerPedId())`) et le cap (`GetEntityHeading`) à l'ouverture, puis toutes les `Config.Map.PositionRefreshMs` (1 000 ms) **uniquement tant que l'écran Carte est affiché et la tablette ouverte** (un seul thread créé à l'ouverture de l'écran, arrêté par un drapeau à sa fermeture).
  3. La position est un point de couleur d'accent avec une flèche de direction.
  4. Contrôles : molette = zoom, glisser = déplacer, boutons « + » / « − », bouton « Me centrer » (icône cible) qui recentre sur le joueur.
  5. En bas à gauche : coordonnées du centre de la carte affichées seulement si l'admin le veut (`Config.Map.ShowCoords = false`).
- **Données** : position et cap du joueur (non stockés).
- **Règles serveur** : aucune (rien n'est demandé au serveur pour la carte elle-même).
- **Textes et états** :
  - Chargement : fond gris uni tant que les tuiles ne sont pas chargées.
  - Bouton : `carte.bouton.centrer` « Me centrer ».
  - Tuiles manquantes (dossier absent) : `carte.erreur.tuiles` « Impossible de charger la carte. » (une seule fois).
  - Joueur à l'intérieur d'un bâtiment instancié (routing bucket ≠ 0) : la position affichée reste la dernière position extérieure connue, avec la mention `carte.position.interieur` « Position approximative ».
- **Notifications** : aucune.
- **Liens** : points de l'annuaire (OUT-CAR-02).
- **Réglages** : `Config.Map.Style = 'sombre'`, `Config.Map.PositionRefreshMs = 1000`, `Config.Map.DefaultZoom = 3`, `Config.Map.ShowCoords = false`, `Config.Map.Calib = { centerX = 117.3, scaleX = 0.02072, centerY = 172.8, scaleY = 0.0205 }`.
- **Journal admin** : non.
- **Performance** : tuiles chargées à la demande par Leaflet ; un thread de 1 s seulement pendant l'affichage de la carte ; tablette fermée ou autre écran = 0 thread.
- **Cas limites** :
  - Tablette fermée pendant que la carte est affichée → le thread s'arrête (drapeau remis à faux dans le gestionnaire de fermeture).
  - Joueur mort → la position continue d'être affichée.
  - Joueur hors limites de la carte (île de Cayo Perico) → le point est placé au bord de la carte avec la mention « Hors carte » (`carte.position.hors_carte`).
- **Critères d'acceptation** :
  - Étant donné la carte ouverte, quand je me déplace de 50 m, alors mon point bouge dans la seconde.
  - Étant donné la carte ouverte puis la tablette fermée, alors aucun thread de la ressource ne tourne côté client (vérifié avec `resmon` à 0,00 ms).
  - Étant donné « Me centrer », quand je clique, alors la carte se recentre sur moi.

### [OUT-CAR-02] Points utiles sur la carte
- **But** : voir les lieux importants (entreprises, services publics, lieux ajoutés par l'admin, mes points).
- **Qui** : tout joueur avec la tablette.
- **Où** : Carte > icônes sur la carte ; bouton « Filtres » en haut à droite.
- **Parcours** :
  1. À l'ouverture de la carte, `pop_tablet:map:points` → serveur : C3, C4 (3 / 10 s), renvoie depuis le cache :
     - les entreprises visibles dans l'annuaire qui ont une position (`id`, `nom`, `categorie`, `x`, `y`, `ouvert` (ANNU-02), `site` si non caché) ;
     - les points de `Config.Map.Points` (liste fixe) ;
     - les points personnels du joueur (OUT-CAR-04).
  2. Chaque point a une icône par catégorie (jeu d'icônes SVG monochromes livré). Entreprise ouverte : icône blanche ; fermée : icône grise à 50 %.
  3. Points rapprochés regroupés (cluster : cercle avec le nombre) en dessous du zoom 3.
  4. Bouton « Filtres » → panneau avec une case à cocher par catégorie (toutes cochées par défaut) + « Uniquement les entreprises ouvertes ». Le choix est gardé dans `localStorage`.
  5. Clic sur un point → bulle : nom, catégorie, « Ouvert » / « Fermé » (entreprises), distance à vol d'oiseau (« 1,2 km » / « 350 m »), boutons « GPS » (OUT-CAR-03), « Voir le site » (si site non caché, ouvre NAV-01 dans un nouvel onglet), « Fiche » (entreprises, ouvre ANNU-03).
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `Config.Map.Points[i].label` | texte (clé de langue ou texte) | oui | 40 car. | — |
| `.category` | texte | oui | une de `Config.Map.Categories` | — |
| `.coords` | vector3 | oui | — | — |
| `.icon` | texte | non | nom d'icône livrée | icône de la catégorie |

  Catégories par défaut (`Config.Map.Categories`) : `services_publics` « Services publics », `sante` « Santé », `police` « Police », `garages` « Garages », `commerces` « Commerces », `restauration` « Restauration », `loisirs` « Loisirs », `transports` « Transports », `entreprises` « Autres entreprises », `perso` « Mes points ». Points fournis par défaut : commissariat Mission Row, hôpital Pillbox Hill, mairie (City Hall), Pôle emploi (job center), aéroport LSIA, gare Union Depot, LS Customs Burton.
- **Règles serveur** : n'envoie pas les entreprises archivées ou masquées de l'annuaire ; n'envoie jamais l'adresse d'un site caché ; points personnels = ceux du demandeur uniquement.
- **Textes et états** :
  - `carte.filtres.titre` « Filtres », `carte.filtres.ouvertes` « Uniquement les entreprises ouvertes ».
  - `carte.point.ouvert` « Ouvert », `carte.point.ferme` « Fermé ».
  - Boutons : `carte.point.gps` « GPS », `carte.point.site` « Voir le site », `carte.point.fiche` « Fiche ».
  - Aucun point affiché (tous filtrés) : `carte.filtres.aucun` « Aucun lieu avec ces filtres. » en bandeau.
- **Notifications** : aucune.
- **Liens** : Annuaire (positions, statut ouvert), Navigateur (site), Points personnels.
- **Réglages** : `Config.Map.Points` (liste ci-dessus), `Config.Map.Categories`, `Config.Map.ClusterBelowZoom = 3`.
- **Journal admin** : non.
- **Performance** : liste mise en cache serveur (reconstruite à chaque modification d'entreprise) ; statut ouvert lu dans le compteur mémoire d'ANNU-02 ; un seul appel à l'ouverture de la carte, pas de mise à jour en direct (bouton « Me centrer » ne recharge pas les points ; fermer/rouvrir la carte recharge).
- **Cas limites** :
  - Entreprise sans position → absente de la carte (présente dans l'annuaire).
  - Plus de 300 points → regroupement obligatoire à tous les zooms < 4.
  - Point de config mal écrit (sans coordonnées) → ignoré au démarrage avec un avertissement console `[pop_tablet] Point de carte ignoré : {label}`.
- **Critères d'acceptation** :
  - Étant donné un garage avec un employé en service, quand j'ouvre la carte, alors son icône est blanche et sa bulle dit « Ouvert ».
  - Étant donné le filtre « Garages » décoché, alors aucune icône de garage n'est affichée.
  - Étant donné un client modifié qui demande les points personnels d'un autre identifiant, alors le serveur renvoie les miens uniquement.

### [OUT-CAR-03] GPS en un clic
- **But** : mettre un itinéraire GPS du jeu vers un lieu en un clic.
- **Qui** : tout joueur avec la tablette.
- **Où** : Carte > bulle d'un point > « GPS » ; clic droit n'importe où sur la carte > « Mettre le GPS ici » ; Annuaire > fiche > « GPS » (ANNU-03).
- **Parcours** :
  1. Clic « GPS » → la NUI envoie au client Lua `{ x, y }` (position du point, pas de serveur).
  2. Client : `SetNewWaypoint(x, y)`.
  3. Bandeau succès. La bulle remplace « GPS » par « Retirer le GPS » tant que ce point est la destination.
  4. « Retirer le GPS » → `SetWaypointOff()`.
  5. Clic droit sur la carte → menu avec « Mettre le GPS ici » (convertit la position carte → jeu avec la formule inverse) et « Ajouter un point ici » (OUT-CAR-04).
- **Données** : aucune stockée.
- **Règles serveur** : aucune (action purement locale, sans effet sur les autres joueurs).
- **Textes et états** :
  - Succès : `carte.gps.defini` « GPS défini vers {nom}. » ; pour un clic droit : `carte.gps.defini_ici` « GPS défini. ».
  - `carte.gps.retirer` « Retirer le GPS », succès `carte.gps.retire` « GPS retiré. ».
  - Menu : `carte.menu.gps_ici` « Mettre le GPS ici », `carte.menu.point_ici` « Ajouter un point ici ».
- **Notifications** : aucune.
- **Liens** : Annuaire (bouton GPS de la fiche).
- **Réglages** : `Config.Map.CloseOnGps = false` (si `true`, la tablette se ferme après avoir mis le GPS).
- **Journal admin** : non.
- **Performance** : un appel natif.
- **Cas limites** :
  - Destination modifiée depuis la carte du jeu (menu pause) → au prochain affichage de la bulle, le bouton se base sur `IsWaypointActive()` et la position du waypoint (`GetBlipInfoIdCoord(GetFirstBlipInfoId(8))`, tolérance 5 m).
  - Clic droit hors de la ville (mer) → GPS posé quand même (le jeu gère l'itinéraire le plus proche).
  - Double clic sur « GPS » → même destination, aucun effet en double.
- **Critères d'acceptation** :
  - Étant donné la bulle de l'hôpital, quand je clique « GPS », alors le waypoint du jeu est sur l'hôpital et « GPS défini vers Hôpital Pillbox Hill. » s'affiche.
  - Étant donné le GPS actif vers ce point, quand je clique « Retirer le GPS », alors le waypoint disparaît.
  - Étant donné un clic droit sur un carrefour, quand je choisis « Mettre le GPS ici », alors le waypoint est posé à moins de 15 m de ce carrefour.

### [OUT-CAR-04] Mes points sur la carte (ajout)
- **But** : enregistrer ses propres lieux (planque, rendez-vous, client).
- **Qui** : tout joueur avec la tablette.
- **Où** : Carte > clic droit > « Ajouter un point ici » ; bulle d'un point perso > « Renommer » / « Supprimer ».
- **Parcours** :
  1. Clic → petite fenêtre : champ « Nom du point » (placeholder « Ex. : Rendez-vous client »), choix d'icône parmi 6 (étoile, maison, drapeau, voiture, valise, point), [Enregistrer] [Annuler].
  2. `pop_tablet:map:addPoint { label, icon, x, y, actionId }` → serveur : C3, C4 (5 / 30 s), C10, C5 (label 30), vérifie `x` entre −4 500 et 4 500, `y` entre −4 500 et 8 500, compte < 20, `INSERT`.
  3. Le point apparaît (catégorie « Mes points »). Renommer = même fenêtre (`map:updatePoint`), supprimer = confirmation « Supprimer ce point ? » puis `map:deletePoint`.
- **Données** : table `pop_tablet_map_points` :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `id` | INT auto | oui | — | — |
| `owner` | VARCHAR(12), index | oui | numéro de série de la tablette (C2) | — |
| `label` | VARCHAR(30) | oui | 1–30 car. | — |
| `icon` | VARCHAR(16) | oui | une des 6 | `etoile` |
| `x`, `y` | FLOAT | oui | bornes ci-dessus | — |
| `created_at` | DATETIME | oui | — | maintenant |

- **Règles serveur** : propriétaire pour modifier/supprimer ; 20 points max ; bornes de coordonnées (la position vient du clic sur la carte, elle n'a pas d'effet de jeu, seules les bornes sont contrôlées).
- **Textes et états** :
  - `carte.point_perso.nom` « Nom du point », placeholder `carte.point_perso.exemple` « Ex. : Rendez-vous client ».
  - Succès : `carte.point_perso.ajoute` « Point ajouté. », `carte.point_perso.modifie` « Point modifié. », `carte.point_perso.supprime` « Point supprimé. ».
  - Limite : `carte.point_perso.limite` « Limite de {max} points atteinte. ».
  - Nom vide : `carte.point_perso.nom_vide` « Nom du point requis. ».
  - Confirmation : `carte.point_perso.confirmer` « Supprimer ce point ? ».
- **Notifications** : aucune.
- **Liens** : OUT-CAR-02 (affichage), OUT-CAR-03 (GPS).
- **Réglages** : `Config.Map.MaxPersonalPoints = 20`.
- **Journal admin** : non.
- **Performance** : points perso envoyés avec la liste d'OUT-CAR-02, aucun appel supplémentaire.
- **Cas limites** :
  - 21e point → refus avec message de limite.
  - Coordonnées hors bornes envoyées par un client modifié → refus `commun.erreur.serveur`.
  - Double clic sur « Enregistrer » → un seul point (C10).
- **Critères d'acceptation** :
  - Étant donné un clic droit sur la carte, quand j'enregistre « Planque », alors une étoile « Planque » apparaît et reste après reconnexion.
  - Étant donné 20 points, quand j'en ajoute un, alors le message de limite s'affiche.
  - Étant donné un client modifié qui supprime le point d'un autre joueur, alors rien n'est supprimé.

### [OUT-CAR-05] Rechercher un lieu sur la carte (ajout)
- **But** : trouver vite un lieu par son nom.
- **Qui** : tout joueur avec la tablette.
- **Où** : Carte > champ « Rechercher un lieu » en haut à gauche.
- **Parcours** :
  1. Le joueur tape (≥ 2 caractères) ; la NUI filtre **localement** les points déjà chargés (OUT-CAR-02) par nom, sans accents ni casse.
  2. Liste déroulante de 8 résultats max : icône, nom, catégorie, distance.
  3. Clic sur un résultat (ou flèches + Entrée) → la carte se centre sur le point au zoom 4 et ouvre sa bulle.
- **Données** : aucune.
- **Règles serveur** : aucune.
- **Textes et états** :
  - `carte.recherche.placeholder` « Rechercher un lieu ».
  - `carte.recherche.vide` « Aucun lieu trouvé. ».
- **Notifications** : aucune.
- **Liens** : OUT-CAR-02.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : filtre local, aucune requête.
- **Cas limites** :
  - Lieu filtré par les filtres actifs → il apparaît quand même dans la recherche ; le cliquer réactive temporairement sa catégorie.
  - Recherche « hopital » trouve « Hôpital Pillbox Hill ».
  - 1 seul caractère → pas de liste.
- **Critères d'acceptation** :
  - Étant donné la recherche « pill », quand je clique sur « Hôpital Pillbox Hill », alors la carte se centre dessus et ouvre la bulle.
  - Étant donné « zzz », alors « Aucun lieu trouvé. » s'affiche.
  - Étant donné un site caché, alors aucune recherche de la carte ne révèle son adresse.

---

## 4. Galerie (Outils)

**Principe de stockage (aucune IP de joueur exposée)** : en mode par défaut `Config.Gallery.Storage = 'local'`, les photos ne quittent jamais le serveur du jeu : capture faite **par le serveur** via `screencapture` (`exports.screencapture:serverCapture`), fichier écrit sur le disque du serveur, et images envoyées aux joueurs **par les événements du jeu** (`TriggerLatentClientEvent`), jamais par une adresse web. Aucun joueur ne se connecte à un hébergeur tiers, aucun lien d'envoi n'est connu du client. Mode `'external'` possible (hébergeur choisi par l'admin) avec avertissement dans la config : « En mode external, chaque joueur qui affiche une photo se connecte à cet hébergeur, qui voit son adresse IP. ».

Tables communes :

`pop_tablet_media` (une ligne = un fichier stocké)

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `id` | CHAR(32) | oui | identifiant aléatoire hexadécimal | — |
| `storage` | ENUM('local','external') | oui | — | `local` |
| `path_or_url` | VARCHAR(300) | oui | chemin relatif `data/photos/<id>.webp` ou URL | — |
| `bytes` | INT | oui | ≤ `Config.Gallery.MaxBytes` | — |
| `width`, `height` | SMALLINT | oui | ≤ 1 280 × 720 | — |
| `refs` | INT | oui | nombre d'utilisations (galerie + pièces jointes) | 1 |
| `locked` | TINYINT(1) | oui | 1 = utilisé comme preuve, jamais supprimé | 0 |
| `created_by` | VARCHAR(60) | oui | identifiant | — |
| `created_at` | DATETIME | oui | — | maintenant |

`pop_tablet_gallery` (une ligne = une photo dans la galerie d'un joueur) : `id` INT auto, `owner` VARCHAR(12) index (numéro de série, C2), `media_id` CHAR(32), `album_id` INT NULL, `caption` VARCHAR(100) défaut `''`, `source` ENUM('camera','link'), `created_at` DATETIME.

`pop_tablet_gallery_albums` : `id` INT auto, `owner` VARCHAR(12) index (numéro de série, C2), `name` VARCHAR(30), `created_at` DATETIME.

### [OUT-GAL-01] Prendre une photo (appareil photo)
- **But** : photographier une scène du jeu et la garder dans sa galerie.
- **Qui** : tout joueur avec la tablette, si la ressource `screencapture` est démarrée et `Config.Gallery.Camera = true`.
- **Où** : Outils > Galerie > bouton « Appareil photo » (icône appareil) en haut à droite.
- **Parcours** :
  1. À l'ouverture de la Galerie, le serveur indique `cameraAvailable = (GetResourceState('screencapture') == 'started' and Config.Gallery.Camera)`. Si faux, le bouton est **caché** (pas grisé) et seul « Ajouter par lien » (OUT-GAL-07) reste.
  2. Clic → la tablette se cache (fondu 150 ms, focus NUI rendu au jeu), le mode photo démarre : un thread côté client tourne **seulement pendant ce mode** : il désactive les tirs et attaques (contrôles 24, 25, 140, 141, 142, 257, 263), force la vue première personne si `Config.Gallery.ForceFirstPerson = true`, et affiche en bas un petit texte : « Clic gauche : photo · Molette : zoom · Clic droit ou Échap : annuler ». La molette ajuste le champ de vision de la caméra de jeu entre 20 et 70 (caméra scriptée posée sur la caméra de jeu).
  3. Clic gauche → le texte d'aide est masqué pendant 1 image, puis le client appelle `pop_tablet:gallery:capture { actionId }`.
  4. Serveur : C3, C4 (`gallery:capture` 1 / 5 s), C10, vérifie le quota du joueur (OUT-GAL-08) et la limite par jour, puis `exports.screencapture:serverCapture(src, { encoding = 'webp', quality = 0.8, maxWidth = 1280, maxHeight = 720 }, cb, 'base64')`.
  5. Dans `cb` : le serveur décode, vérifie l'en-tête du fichier (`RIFF....WEBP`), la taille ≤ `Config.Gallery.MaxBytes`, écrit `data/photos/<id>.webp` (mode local) ou l'envoie à l'hébergeur (mode external, OUT-GAL-02), crée `pop_tablet_media` + `pop_tablet_gallery` (`source = 'camera'`, album = album ouvert au moment du clic ou aucun).
  6. Le serveur renvoie la photo au joueur (latent event), la NUI fabrique une miniature 320 × 180 (canvas, webp qualité 0.7) et l'envoie `pop_tablet:gallery:thumb { mediaId, data }` ; le serveur vérifie l'en-tête webp et taille ≤ 40 Ko et la stocke `data/photos/<id>_t.webp`.
  7. Le mode photo se termine, la tablette se rouvre sur la Galerie avec la nouvelle photo en premier et un bandeau succès. Clic droit / Échap → sortie sans photo.
- **Données** : voir tables ; photo ≤ 1 280 × 720, ≤ 600 Ko.
- **Règles serveur** : quota (50 photos), limite par jour (30 captures par personnage par jour réel, compteur mémoire remis à zéro à minuit serveur), délai entre deux captures 5 s, contrôle du format du fichier, capture **demandée par le serveur** (le client n'envoie jamais l'image complète).
- **Textes et états** :
  - Bouton : `galerie.bouton.appareil` « Appareil photo ».
  - Aide : `galerie.camera.aide` « Clic gauche : photo · Molette : zoom · Clic droit ou Échap : annuler ».
  - Succès : `galerie.succes.photo` « Photo enregistrée. ».
  - Quota : `galerie.erreur.quota` « Galerie pleine ({max} photos). ».
  - Limite jour : `galerie.erreur.limite_jour` « Limite de photos du jour atteinte. ».
  - Échec capture : `galerie.erreur.capture` « Impossible de prendre la photo. ».
  - Trop lourde : `galerie.erreur.trop_lourde` « Photo trop lourde, non enregistrée. ».
- **Notifications** : aucune.
- **Liens** : OUT-GAL-06 (envoyer la photo vers une app).
- **Réglages** : `Config.Gallery.Camera = true`, `Config.Gallery.ForceFirstPerson = true`, `Config.Gallery.MaxBytes = 600000`, `Config.Gallery.MaxPerDay = 30`, `Config.Gallery.CaptureCooldownSec = 5`, `Config.Gallery.Quality = 0.8`, `Config.Gallery.MaxWidth = 1280`, `Config.Gallery.MaxHeight = 720`.
- **Journal admin** : oui, ligne légère `gallery_capture` (qui, id média, taille) — permet à l'admin de retrouver l'auteur d'une image choquante.
- **Performance** : thread client seulement pendant le mode photo ; écriture disque d'un fichier par photo ; miniature produite côté joueur pour ne pas redimensionner en Lua.
- **Cas limites** :
  - `screencapture` arrêté pendant le mode photo → `galerie.erreur.capture`, sortie du mode photo.
  - Joueur qui meurt ou monte dans un véhicule pendant le mode photo → la photo reste possible (dans un véhicule) ; s'il meurt, le mode photo s'arrête sans photo.
  - Pas de réponse de `screencapture` sous 10 s → abandon, message d'échec, `actionId` libéré.
  - Miniature jamais reçue (déconnexion) → la grille utilise la photo complète réduite par la NUI.
- **Critères d'acceptation** :
  - Étant donné `screencapture` démarré, quand je prends une photo, alors elle apparaît en tête de ma galerie et le fichier existe dans `data/photos/`.
  - Étant donné `screencapture` absent, quand j'ouvre la Galerie, alors le bouton « Appareil photo » n'existe pas.
  - Étant donné un client modifié qui envoie une image en base64 à `gallery:capture`, alors le serveur l'ignore (il ne prend que l'image qu'il capture lui-même).
  - Étant donné une 2e capture 2 s après la 1re, alors elle est refusée par la limite de fréquence.

### [OUT-GAL-02] Stockage et affichage des photos sans exposer l'IP
- **But** : garder les photos et les montrer aux joueurs autorisés sans adresse web publique.
- **Qui** : système (aucune action joueur directe).
- **Où** : tout endroit qui affiche une photo (Galerie, rapports, preuves, annonces, sites, stock).
- **Parcours** :
  1. La NUI qui doit afficher `media:<id>` appelle `pop_tablet:media:get { id, thumb = true|false }`.
  2. Serveur : C3, C4 (`media:get` 20 / 10 s), vérifie le droit de voir (`Media.CanView(src, id)`) : propriétaire dans sa galerie, ou média attaché à un élément que le joueur a le droit de voir (rapport, preuve, annonce publiée, site en ligne, article de stock de son entreprise). Chaque app qui attache un média enregistre le lien dans `pop_tablet_media_links (media_id, target_type, target_id)` ; `CanView` interroge la règle de lecture de l'app concernée.
  3. Mode local : le serveur lit le fichier (cache mémoire LRU de `Config.Gallery.ServerCacheMb = 32` Mo) et l'envoie avec `TriggerLatentClientEvent('pop_tablet:media:data', src, Config.Gallery.LatentBps = 200000, id, base64)`. La NUI l'affiche en `data:image/webp;base64,...` et le garde dans un cache mémoire de 30 images (LRU) jusqu'à la fermeture de la session de jeu.
  4. Mode external : le serveur envoie l'image par HTTP (`PerformHttpRequest`, POST multipart) à `Config.Gallery.External.Url` avec la clé lue dans la convar `pop_tablet_upload_key` (définie dans `server.cfg` par `set pop_tablet_upload_key "..."`, jamais dans le dépôt ni dans la config), récupère l'URL renvoyée (champ `Config.Gallery.External.UrlField = 'url'`), vérifie que son domaine est dans `Config.Images.AllowedDomains`, et stocke l'URL. Affichage : `media:get` renvoie l'URL, la NUI la charge directement.
  5. Une photo est supprimée du disque seulement quand `refs` tombe à 0 **et** `locked = 0`.
- **Données** : tables `pop_tablet_media`, `pop_tablet_media_links` (`media_id` CHAR(32), `target_type` VARCHAR(20), `target_id` VARCHAR(40), `created_at`).
- **Règles serveur** : droit de voir revérifié à chaque demande ; jamais de chemin disque envoyé au client ; noms de fichier = id aléatoire (pas devinable) ; la clé de l'hébergeur ne quitte jamais le serveur.
- **Textes et états** :
  - Image en cours d'arrivée : rectangle gris.
  - Pas le droit / introuvable : rectangle gris avec `galerie.media.indisponible` « Image indisponible ».
- **Notifications** : aucune.
- **Liens** : toutes les apps qui affichent des images (Police, Justice, Annonces, Sites web, Stock).
- **Réglages** : `Config.Gallery.Storage = 'local'`, `Config.Gallery.LocalPath = 'data/photos/'`, `Config.Gallery.ServerCacheMb = 32`, `Config.Gallery.LatentBps = 200000`, `Config.Gallery.External = { Url = '', UrlField = 'url', FileField = 'file' }`, convar `pop_tablet_upload_key`.
- **Journal admin** : non pour l'affichage ; oui pour les erreurs d'envoi vers l'hébergeur (`media_upload_error`, code HTTP).
- **Performance** : envoi latent (ne bloque pas le réseau du jeu) ; miniatures (≈ 20 Ko) pour les grilles, photo complète seulement en visionneuse ; cache serveur et client.
- **Cas limites** :
  - Fichier supprimé à la main sur le disque → `galerie.media.indisponible`, ligne au journal admin `media_missing`.
  - Hébergeur externe en panne → la capture échoue proprement (`galerie.erreur.capture`) ; aucune photo à moitié créée.
  - Joueur qui ouvre 50 images d'un coup → C4 étale les demandes ; la NUI met en file et demande au fur et à mesure de l'affichage (images visibles seulement).
- **Critères d'acceptation** :
  - Étant donné le mode local, quand j'ouvre ma galerie, alors aucune requête web sortante n'est faite par mon jeu (vérifiable dans l'outil réseau de la NUI : uniquement des `data:`).
  - Étant donné une photo attachée à un rapport de police, quand un civil demande ce média avec son id, alors le serveur refuse (`Image indisponible`).
  - Étant donné une photo utilisée comme preuve puis supprimée de la galerie, alors le fichier reste sur le disque.

### [OUT-GAL-03] Voir ses photos (grille et visionneuse)
- **But** : parcourir ses photos et en ouvrir une en grand.
- **Qui** : tout joueur avec la tablette.
- **Où** : Outils > Galerie.
- **Parcours** :
  1. Ouverture → `pop_tablet:gallery:list { albumId = nil, page = 1 }` → serveur : C3, C4, renvoie 24 photos (id, media_id, légende, album, date) triées de la plus récente à la plus ancienne + albums (OUT-GAL-04) + compteur.
  2. En haut : onglets « Toutes » puis un onglet par album ; boutons « Appareil photo », « Ajouter par lien », « Nouvel album ».
  3. Grille de miniatures 4 colonnes ; les miniatures se chargent à l'apparition à l'écran (OUT-GAL-02).
  4. Clic → visionneuse plein écran tablette : photo complète, légende modifiable (clic sur « Ajouter une légende », 100 caractères, enregistrée par `gallery:caption`), date, flèches ← → (et touches fléchées) pour la précédente/suivante, barre d'actions : « Envoyer vers… » (OUT-GAL-06), « Déplacer vers un album » (OUT-GAL-04), « Supprimer » (OUT-GAL-05). Échap ferme la visionneuse.
  5. Sélection multiple : appui long 500 ms ou case en coin de miniature → barre « {n} sélectionnée(s) » avec « Déplacer » et « Supprimer ».
- **Données** : 24 par page (6 lignes de 4) ; légende VARCHAR(100) nettoyée (C5).
- **Règles serveur** : uniquement les photos du joueur ; `page` ≥ 1.
- **Textes et états** :
  - Vide (aucune photo) : `galerie.liste.vide` « Galerie vide. » + bouton `galerie.liste.prendre` « Prendre une photo » (ou `galerie.liste.ajouter_lien` « Ajouter une image par lien » si pas d'appareil).
  - Album vide : `galerie.album.vide` « Album vide. ».
  - Compteur : `galerie.liste.compteur` « {n} / {max} photos ».
  - `galerie.visionneuse.legende` « Ajouter une légende », succès `galerie.succes.legende` « Légende enregistrée. ».
  - Sélection : `galerie.selection.compteur` « {n} sélectionnée(s) ».
- **Notifications** : aucune.
- **Liens** : OUT-GAL-02, 04, 05, 06.
- **Réglages** : `Config.Gallery.PageSize = 24`.
- **Journal admin** : non.
- **Performance** : liste paginée sans données d'image ; miniatures à la demande.
- **Cas limites** :
  - Photo dont le fichier a disparu → miniature « Image indisponible », toujours supprimable.
  - Flèche → sur la dernière photo de la page → charge la page suivante.
  - Légende avec balises → affichée en texte brut.
- **Critères d'acceptation** :
  - Étant donné 30 photos, quand j'ouvre la galerie, alors 24 miniatures s'affichent et « Suivant » mène aux 6 autres.
  - Étant donné la visionneuse, quand j'appuie sur →, alors la photo suivante s'affiche.
  - Étant donné un client modifié qui demande la liste d'un autre joueur, alors seules mes photos reviennent.

### [OUT-GAL-04] Albums
- **But** : ranger ses photos par thème.
- **Qui** : tout joueur avec la tablette.
- **Où** : Galerie > « Nouvel album » ; onglet d'album > menu « ⋯ » > « Renommer » / « Supprimer l'album » ; visionneuse ou sélection > « Déplacer vers un album ».
- **Parcours** :
  1. Créer : fenêtre « Nom de l'album » (30 caractères) → `gallery:albumCreate { name, actionId }` → serveur : C3, C4, C10, C5, nombre d'albums < 10, nom unique pour ce joueur (sans casse) → `INSERT`.
  2. Renommer : même fenêtre pré-remplie → `gallery:albumRename`.
  3. Supprimer l'album : confirmation « Supprimer l'album « {nom} » ? Les photos restent dans « Toutes ». » → `gallery:albumDelete` → les photos passent à `album_id = NULL`, l'album est effacé.
  4. Déplacer : liste des albums + « Aucun album » → `gallery:move { galleryIds[], albumId }` (50 photos max par appel). Une photo est dans un seul album à la fois.
- **Données** : table `pop_tablet_gallery_albums` (voir plus haut) ; `name` 1–30 caractères.
- **Règles serveur** : propriétaire de l'album et de chaque photo déplacée (les autres ids sont ignorés) ; 10 albums max ; nom unique.
- **Textes et états** :
  - `galerie.album.nouveau` « Nouvel album », `galerie.album.nom` « Nom de l'album ».
  - Succès : `galerie.succes.album_cree` « Album créé. », `galerie.succes.album_renomme` « Album renommé. », `galerie.succes.album_supprime` « Album supprimé. », `galerie.succes.deplace` « {n} photo(s) déplacée(s). ».
  - Erreurs : `galerie.erreur.album_limite` « Limite de {max} albums atteinte. », `galerie.erreur.album_existe` « Un album porte déjà ce nom. », `galerie.erreur.album_nom_vide` « Nom de l'album requis. ».
  - Confirmation : `galerie.album.confirmer_suppression` « Supprimer l'album « {nom} » ? Les photos restent dans « Toutes ». ».
  - Destination : `galerie.album.aucun` « Aucun album ».
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : `Config.Gallery.MaxAlbums = 10`.
- **Journal admin** : non.
- **Performance** : 1 requête par action ; déplacement groupé en une requête `UPDATE ... WHERE id IN (...) AND owner = ?`.
- **Cas limites** :
  - Suppression de l'album affiché → retour à l'onglet « Toutes ».
  - Déplacer 60 photos d'un coup → la NUI envoie 2 appels (50 + 10).
  - Album supprimé pendant que la visionneuse d'une de ses photos est ouverte → la photo reste visible, son album devient « Aucun album ».
- **Critères d'acceptation** :
  - Étant donné « Nouvel album » nommé « Enquête », quand je déplace 3 photos dedans, alors l'onglet « Enquête » montre ces 3 photos.
  - Étant donné l'album supprimé, alors les 3 photos sont toujours dans « Toutes ».
  - Étant donné un client modifié qui déplace des photos d'un autre joueur, alors elles ne bougent pas.

### [OUT-GAL-05] Supprimer des photos
- **But** : retirer des photos de sa galerie.
- **Qui** : propriétaire.
- **Où** : visionneuse > « Supprimer » ; sélection multiple > « Supprimer ».
- **Parcours** :
  1. Confirmation « Supprimer {n} photo(s) ? Les copies déjà envoyées vers d'autres apps sont gardées. » [Supprimer] [Annuler].
  2. `gallery:delete { galleryIds[] }` (50 max) → serveur : C3, C4, ne garde que les lignes du joueur, les efface de `pop_tablet_gallery`, décrémente `refs` des médias ; pour chaque média à `refs = 0` et `locked = 0` : efface le fichier (local) ou l'oublie (external, pas d'appel de suppression à l'hébergeur), puis la ligne média.
  3. Bandeau succès, grille rechargée.
- **Données** : suppression réelle dans la galerie (donnée personnelle) ; médias utilisés ailleurs conservés.
- **Règles serveur** : propriétaire ; preuve = jamais supprimée (`locked`).
- **Textes et états** :
  - `galerie.supprimer.confirmer` « Supprimer {n} photo(s) ? Les copies déjà envoyées vers d'autres apps sont gardées. ».
  - Succès : `galerie.succes.supprimees` « {n} photo(s) supprimée(s). ».
- **Notifications** : aucune.
- **Liens** : OUT-GAL-06 (copies gardées).
- **Réglages** : aucun.
- **Journal admin** : non (la photo reste dans le journal de capture).
- **Performance** : une transaction par appel.
- **Cas limites** :
  - Photo envoyée comme annonce puis supprimée → l'annonce garde l'image.
  - Double clic → la 2e demande ne trouve plus rien, réponse ok avec 0.
  - Erreur d'effacement du fichier (droits disque) → ligne média gardée avec `refs = 0`, avertissement console ; nouvelle tentative au démarrage suivant (nettoyage des médias `refs = 0` au lancement de la ressource).
- **Critères d'acceptation** :
  - Étant donné 2 photos sélectionnées, quand je confirme, alors elles disparaissent et le compteur baisse de 2.
  - Étant donné une photo envoyée en preuve, quand je la supprime de ma galerie, alors la preuve affiche toujours l'image.
  - Étant donné un client modifié qui supprime des photos d'un autre joueur, alors rien n'est supprimé.

### [OUT-GAL-06] Envoyer une photo vers une app (rapport, preuve, annonce, site)
- **But** : utiliser une photo comme pièce jointe dans une autre app.
- **Qui** : propriétaire de la photo ; chaque destination exige son propre droit.
- **Où** : visionneuse > « Envoyer vers… » ; dans les autres apps, bouton « Ajouter une photo » qui ouvre un sélecteur de galerie (même règle, sens inverse).
- **Parcours** :
  1. Clic → `gallery:targets` → serveur renvoie les destinations possibles **pour ce joueur** :
     - « Rapport de police » : si le joueur est de la police et a le droit « rapport » → liste de ses rapports en brouillon ou ouverts (20 derniers) + « Nouveau rapport » ;
     - « Preuve d'une affaire » : police ou justice avec le droit d'ajouter une preuve → affaires ouvertes (20 dernières) ;
     - « Annonce » : droit « Publier une annonce » dans une de ses entreprises → crée/ouvre le brouillon d'annonce de cette entreprise ;
     - « Site de l'entreprise » : droit `site.modifier` → ajoute à la bibliothèque d'images du site ;
     - « Article de stock » : droit `stock.modifier` → choisir l'article (PRO-STO-02).
     Destinations sans droit : non affichées.
  2. Le joueur choisit la destination puis l'élément → `gallery:send { galleryId, targetType, targetId, actionId }`.
  3. Serveur : C3, C4 (5 / 10 s), C10, propriétaire de la photo, revérifie le droit sur la cible (appel de l'app cible `Attachments.CanAttach(src, targetType, targetId)`), limite de pièces jointes de la cible (définie par l'app cible, ex. 10 photos par rapport), crée `pop_tablet_media_links`, `refs + 1` ; si `targetType = 'preuve'` → `locked = 1` (définitif).
  4. Bandeau succès avec le bouton « Ouvrir » qui ouvre l'élément cible.
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `targetType` | texte | oui | `rapport`, `preuve`, `annonce`, `site`, `stock` | — |
| `targetId` | texte | oui | id de l'élément cible | — |

- **Règles serveur** : le média est **partagé par référence** (pas de copie du fichier) ; une preuve verrouille le média ; une même photo ne s'attache qu'une fois au même élément (`UNIQUE(media_id, target_type, target_id)`).
- **Textes et états** :
  - `galerie.envoyer.titre` « Envoyer vers… ».
  - Destinations : `galerie.envoyer.rapport` « Rapport de police », `galerie.envoyer.preuve` « Preuve d'une affaire », `galerie.envoyer.annonce` « Annonce », `galerie.envoyer.site` « Site de l'entreprise », `galerie.envoyer.stock` « Article de stock ».
  - Aucune destination : `galerie.envoyer.aucune` « Aucune app ne peut recevoir de photo avec ce grade. ».
  - Succès : `galerie.succes.envoyee` « Photo ajoutée à {destination}. » + bouton `galerie.envoyer.ouvrir` « Ouvrir ».
  - Preuve : avant l'envoi, avertissement `galerie.envoyer.preuve_avertissement` « Une photo envoyée en preuve ne pourra plus jamais être supprimée. Continuer ? ».
  - Déjà jointe : `galerie.erreur.deja_jointe` « Cette photo est déjà jointe à cet élément. ».
  - Limite cible : `galerie.erreur.limite_cible` « Cet élément a déjà le nombre maximum de photos ({max}). ».
- **Notifications** : aucune.
- **Liens** : Police (rapports), Justice (preuves), Annonces, Sites web, Stock. Signal interne `pop_tablet:media:attached { mediaId, targetType, targetId }` pour que l'app cible rafraîchisse ses joueurs qui regardent l'élément.
- **Réglages** : aucun propre (limites dans chaque app cible).
- **Journal admin** : oui pour `preuve` (`media_evidence` : qui, média, affaire) ; non pour les autres.
- **Performance** : liste des destinations calculée au clic ; 20 éléments par destination.
- **Cas limites** :
  - Joueur rétrogradé entre l'ouverture de la liste et l'envoi → refus `commun.erreur.pas_droit`.
  - Rapport clôturé entre-temps → refus `galerie.erreur.cible_fermee` « Cet élément est clôturé, il ne peut plus recevoir de photo. ».
  - Photo ajoutée par lien (OUT-GAL-07) envoyée en preuve → autorisée, l'URL est verrouillée de la même façon (si l'image disparaît chez l'hébergeur, la preuve affiche « Image indisponible »).
- **Critères d'acceptation** :
  - Étant donné un policier avec un rapport ouvert, quand il envoie une photo vers ce rapport, alors la photo apparaît dans le rapport.
  - Étant donné un mécano, quand il ouvre « Envoyer vers… », alors « Rapport de police » n'apparaît pas.
  - Étant donné un client modifié qui envoie `targetType = 'preuve'` pour un civil, alors le serveur refuse avec `commun.erreur.pas_droit`.

### [OUT-GAL-07] Ajouter une image par lien (ajout)
- **But** : ajouter une image hébergée ailleurs quand l'appareil photo n'est pas disponible.
- **Qui** : tout joueur avec la tablette, si `Config.Gallery.AllowLinks = true`.
- **Où** : Galerie > bouton « Ajouter par lien ».
- **Parcours** :
  1. Fenêtre : champ « Lien de l'image (https://…) », aperçu affiché seulement après validation serveur.
  2. `gallery:addLink { url, actionId }` → serveur : C3, C4 (3 / 30 s), C10, C6 (domaine autorisé, extension, `https`, ≤ 300), quota (OUT-GAL-08), crée `pop_tablet_media` (`storage = 'external'`, `bytes = 0`, `width/height = 0`) + ligne de galerie (`source = 'link'`).
  3. La photo apparaît dans la grille (la NUI charge l'URL, autorisée car le domaine est dans la liste ; l'avertissement IP de la config s'applique).
- **Données** : `url` VARCHAR(300).
- **Règles serveur** : C6 strict ; le serveur ne télécharge pas l'image.
- **Textes et états** :
  - `galerie.lien.titre` « Ajouter par lien », `galerie.lien.placeholder` « Lien de l'image (https://…) ».
  - Succès : `galerie.succes.lien` « Image ajoutée. ».
  - Refus : `commun.erreur.image`.
  - Désactivé : bouton caché.
- **Notifications** : aucune.
- **Liens** : OUT-GAL-06.
- **Réglages** : `Config.Gallery.AllowLinks = true`.
- **Journal admin** : oui, `gallery_link` (qui, URL).
- **Performance** : 1 requête.
- **Cas limites** :
  - URL `http://` → refusée.
  - Domaine autorisé mais image supprimée chez l'hébergeur → « Image indisponible » (événement `error` de la balise image).
  - URL avec `javascript:` ou `data:` → refusée.
- **Critères d'acceptation** :
  - Étant donné un lien `https://` d'un domaine autorisé finissant par `.png`, quand je valide, alors l'image apparaît.
  - Étant donné un domaine non autorisé, alors le message d'image refusée s'affiche.
  - Étant donné un client modifié qui envoie `data:image/png;base64,...`, alors le serveur refuse.

### [OUT-GAL-08] Quota de stockage (ajout)
- **But** : éviter que le disque du serveur se remplisse.
- **Qui** : système ; réglage admin.
- **Où** : vérifié à chaque capture ou ajout ; compteur affiché dans la Galerie.
- **Parcours** :
  1. Avant chaque ajout, le serveur compte les photos du joueur (`COUNT(*)` sur `pop_tablet_gallery`).
  2. Si ≥ `Config.Gallery.MaxPhotosPerPlayer` → refus `galerie.erreur.quota`.
  3. Au démarrage de la ressource, le serveur calcule la taille totale des médias locaux ; si elle dépasse `Config.Gallery.MaxTotalMb`, les nouvelles captures sont refusées pour tous avec `galerie.erreur.disque_plein` « Stockage des photos du serveur plein. », et un message console + journal admin `media_disk_full`.
- **Données** : compteur (non stocké).
- **Règles serveur** : voir parcours ; la taille totale est tenue à jour en mémoire (+ à chaque ajout, − à chaque suppression).
- **Textes et états** : `galerie.erreur.quota`, `galerie.erreur.disque_plein`, compteur `galerie.liste.compteur`.
- **Notifications** : aucune.
- **Liens** : aucun.
- **Réglages** : `Config.Gallery.MaxPhotosPerPlayer = 50`, `Config.Gallery.MaxTotalMb = 2048`.
- **Journal admin** : oui quand le stockage total est plein.
- **Performance** : un `COUNT` indexé par ajout ; total en mémoire.
- **Cas limites** :
  - Admin qui baisse le quota sous le nombre de photos d'un joueur → ses photos restent ; il ne peut plus en ajouter tant qu'il n'est pas repassé sous la limite.
  - Photos en preuve : comptent dans le disque total, pas dans le quota du joueur après suppression de sa galerie.
  - Ressource redémarrée → total recalculé.
- **Critères d'acceptation** :
  - Étant donné 50 photos, quand je prends une photo, alors le message de galerie pleine s'affiche.
  - Étant donné le stockage total plein, alors personne ne peut prendre de photo et le journal admin contient `media_disk_full`.
  - Étant donné un client modifié qui envoie plusieurs captures en parallèle à 49 photos, alors une seule est acceptée (vérification + insertion dans la même transaction).

---

## 5. Navigateur

Pas de vrai internet : le Navigateur n'affiche que les sites créés dans la branche Sites web (fiches de la branche Sites web pour la création et l'édition). Il ne charge **jamais** d'iframe ni d'URL externe ; les pages sont des blocs (titre, texte, image, bouton, formulaire…) rendus par la NUI à partir de données JSON envoyées par le serveur.

Données lues dans la branche Sites web (cache serveur `SiteCache`, clé = adresse) : `id`, `address` (ex. `bennys.rp`), `name` (40 car.), `type` (un de `Config.Browser.SiteTypes`), `description` (140 car.), `company_id` ou NULL, `hidden` (0/1), `status` (`online` / `maintenance` / `offline`), `maintenance_message` (200 car.), `pages` (liste `{ path, title, blocks }`, `path = '/'` pour l'accueil). Le cache est invalidé par les signaux serveur `pop_tablet:sitePublished`, `pop_tablet:siteHidden`, `pop_tablet:siteRestored` et `pop_tablet:siteAddressChanged` (fichier 05, avec l'adresse) émis par la branche Sites web. Source des données : API de lecture des sites SITE-EDI-18 et colonnes de `pop_tablet_sites` (fichier 05) ; correspondance : `type` = `site_type`, `description` = `description`, `hidden` = `unlisted`, `status` : `online` = site `publie` sans maintenance, `maintenance` = `publie` avec `maintenance = 1` (message `maintenance_message`), `offline` = `brouillon` ou `masque` ; ces réglages sont faits par l'entreprise dans SITE-EDI-21.

**Format d'adresse** : `<nom>.<extension>`, `nom` = 3 à 24 caractères `a-z`, `0-9`, `-` (pas en début ni fin), extension `Config.Sites.Suffix = 'rp'`. Chemin optionnel `/page` (`a-z0-9-/`, 60 car.). **Normalisation** (NUI et serveur, même fonction) : minuscules, retrait de `http://`, `https://`, `www.`, des espaces, de la barre finale ; si pas d'extension, ajout de `.rp`. Ex. `HTTPS://www.Bennys.RP/` → `bennys.rp`.

Types de site par défaut (`Config.Browser.SiteTypes`) : `entreprise` « Entreprise », `service_public` « Service public », `media` « Média », `boutique` « Boutique », `loisirs` « Loisirs », `association` « Association », `autre` « Autre ».

### [NAV-01] Charger une page (le serveur envoie une page à la fois)
- **But** : afficher une page de site à partir de son adresse.
- **Qui** : tout joueur avec la tablette.
- **Où** : Navigateur > barre d'adresse (Entrée), clic sur un lien, résultat de recherche, favori, historique, bouton « Voir le site » d'une autre app.
- **Parcours** :
  1. La NUI normalise l'adresse et affiche une barre de progression fine (couleur d'accent) sous la barre d'adresse.
  2. `pop_tablet:nav:open { address, path, tabId }`.
  3. Serveur : C3, C4 (`nav:open` 10 / 10 s), normalise, cherche dans `SiteCache` :
     - site absent, ou `status = 'offline'`, ou entreprise propriétaire archivée → `{ status = 'notfound' }` (NAV-10) ;
     - `status = 'maintenance'` et joueur **sans** `site.modifier` sur l'entreprise propriétaire (ni admin) → `{ status = 'maintenance', name, message }` (NAV-11) ;
     - page `path` absente du site → `{ status = 'pagenotfound', site }` (NAV-10) ;
     - sinon `{ status = 'ok', site = { address, name, type, hidden }, page = { path, title, blocks }, menu = [{ path, title }], preview = (status == 'maintenance') }`.
  4. Le serveur ajoute la visite à l'historique du joueur (NAV-07) sauf pour `notfound`.
  5. La NUI rend les blocs (texte via `textContent`, images via OUT-GAL-02 ou URL autorisée C6), met le titre de la page dans l'onglet, l'adresse finale dans la barre, et une icône d'étoile pleine/vide (NAV-06).
  6. Liens internes d'un bloc (`{ link = '/tarifs' }` ou `{ link = 'autre.rp/page' }`) → nouvel appel `nav:open` dans le même onglet. Un lien ne peut viser qu'une adresse `.rp` : tout autre lien est affiché comme du texte.
- **Données** : réponse JSON ≤ `Config.Browser.MaxPageKb = 64` Ko (au-delà, la branche Sites web refuse l'enregistrement de la page, donc jamais envoyé).
- **Règles serveur** : C3, C4 ; aucune page d'un site `offline` ; aperçu maintenance réservé aux gérants ; les formulaires d'un site envoient vers la boîte Demandes par la branche Sites web (pas par le Navigateur).
- **Textes et états** :
  - Chargement : barre de progression + formes grises à la place des blocs ; au-delà de 5 s, C13.
  - Aperçu maintenance : bandeau `navigateur.apercu_maintenance` « Aperçu : ce site est en maintenance, seuls les gérants le voient. ».
  - Erreur réseau : `navigateur.erreur.chargement` « La page n'a pas pu être chargée. » + « Réessayer ».
- **Notifications** : aucune.
- **Liens** : Sites web (source des pages, invalidation du cache), Annuaire (« Voir le site »), Carte (« Voir le site »).
- **Réglages** : `Config.Sites.Suffix = 'rp'`, `Config.Browser.MaxPageKb = 64`, `Config.Browser.ClientCacheSec = 60`.
- **Journal admin** : non.
- **Performance** : une seule page envoyée par appel ; cache serveur des sites en mémoire ; cache client des 10 dernières pages pendant 60 s (retour arrière instantané) ; images à la demande.
- **Cas limites** :
  - Site modifié pendant qu'un joueur le lit → il voit l'ancienne version jusqu'à son prochain chargement (pas de push).
  - Site supprimé entre deux clics → `notfound`.
  - Adresse tapée avec majuscules et `https://` → normalisée, page trouvée.
  - Bloc image dont le domaine n'est plus autorisé → « Image indisponible ».
- **Critères d'acceptation** :
  - Étant donné le site `bennys.rp` en ligne, quand je tape `Bennys` puis Entrée, alors la page d'accueil s'affiche et la barre montre `bennys.rp`.
  - Étant donné un site en maintenance, quand un gérant l'ouvre, alors il voit le site avec le bandeau d'aperçu ; un civil voit la page de maintenance.
  - Étant donné un client modifié qui demande une page d'un site `offline`, alors le serveur renvoie `notfound`.
  - Étant donné un bloc contenant `<script>`, alors il s'affiche en texte et ne s'exécute pas.

### [NAV-02] Barre d'adresse
- **But** : aller directement à un site en tapant son adresse.
- **Qui** : tout joueur avec la tablette.
- **Où** : Navigateur > barre d'adresse en haut de chaque onglet.
- **Parcours** :
  1. Clic dans la barre → tout le texte est sélectionné ; le panneau de suggestions s'ouvre (NAV-03).
  2. Le joueur tape. Entrée :
     - si le texte ressemble à une adresse (après normalisation il correspond au format d'adresse, ou contient un point) → NAV-01 ;
     - sinon (mot avec espace, ou mot sans point de moins de 3 caractères) → recherche (NAV-04) avec ce texte.
     - un mot seul de 3 à 30 caractères valides sans point (ex. `bennys`) → essai de l'adresse `bennys.rp` ; si `notfound`, la NUI bascule automatiquement sur la recherche de « bennys » **sans** afficher la page introuvable.
  3. Échap dans la barre → remet l'adresse de la page affichée et quitte la barre (n'applique pas la règle « retour »).
- **Données** : texte 0–100 caractères (`maxlength`).
- **Règles serveur** : celles de NAV-01 et NAV-04.
- **Textes et états** :
  - Placeholder : `navigateur.adresse.placeholder` « Adresse ou recherche ».
- **Notifications** : aucune.
- **Liens** : NAV-01, NAV-03, NAV-04.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : aucune requête avant Entrée (hors suggestions).
- **Cas limites** :
  - Texte vide + Entrée → page d'accueil du moteur (NAV-04).
  - `bennys.com` → normalisé en nom `bennys.com` invalide (mauvaise extension) → page introuvable avec proposition de rechercher « bennys ».
  - 100 caractères atteints → la saisie s'arrête.
- **Critères d'acceptation** :
  - Étant donné `bennys.rp` en ligne, quand je tape `bennys` et Entrée, alors le site s'ouvre.
  - Étant donné `pizza livraison` et Entrée, alors la page de résultats de recherche s'ouvre pour ces mots.
  - Étant donné `inconnu` et Entrée, alors la recherche « inconnu » s'affiche (pas la page introuvable).

### [NAV-03] Suggestions de la barre d'adresse
- **But** : proposer des adresses pendant la frappe.
- **Qui** : tout joueur avec la tablette.
- **Où** : Navigateur > barre d'adresse > panneau sous la barre.
- **Parcours** :
  1. Barre vide et ouverte : le panneau montre les 4 derniers sites visités (historique) et les 4 premiers favoris.
  2. À partir d'1 caractère : la NUI filtre **localement** favoris et historique (chargés à l'ouverture du Navigateur, NAV-06/07) par début d'adresse, de nom ou de titre (sans accents ni casse).
  3. À partir de 2 caractères, après 200 ms sans frappe : `pop_tablet:nav:suggest { q }` → serveur : C4 (10 / 5 s), cherche dans `SiteCache` les sites `online` et `hidden = 0` dont l'adresse ou le nom **commence** par `q` (puis contiennent `q`), 6 max.
  4. Fusion : 8 lignes max, ordre : favoris, historique, sites publics, sans doublon d'adresse. Chaque ligne : icône (étoile / horloge / globe), nom, adresse en gris. La dernière ligne est toujours « Rechercher « {q} » ».
  5. Flèches haut/bas pour se déplacer, Entrée pour ouvrir, clic pour ouvrir.
- **Données** : `q` 1–100 caractères.
- **Règles serveur** : **jamais** de site caché dans les suggestions serveur ; un site caché n'apparaît que s'il est déjà dans l'historique ou les favoris du joueur (filtre local).
- **Textes et états** :
  - `navigateur.suggestions.rechercher` « Rechercher « {q} » ».
  - Sections (barre vide) : `navigateur.suggestions.recents` « Récents », `navigateur.suggestions.favoris` « Favoris ».
- **Notifications** : aucune.
- **Liens** : NAV-06, NAV-07.
- **Réglages** : `Config.Browser.SuggestDebounceMs = 200`, `Config.Browser.SuggestMax = 8`.
- **Journal admin** : non.
- **Performance** : filtre local immédiat ; requête serveur seulement à partir de 2 caractères et après 200 ms ; recherche en mémoire sur le cache (pas de base).
- **Cas limites** :
  - Aucun site ne correspond → seule la ligne « Rechercher « {q} » ».
  - Site devenu caché alors qu'il est dans mes favoris → reste suggéré (je connais l'adresse).
  - Réponse serveur arrivée après une nouvelle frappe → ignorée (numéro de requête comparé).
- **Critères d'acceptation** :
  - Étant donné `bennys.rp` public, quand je tape `ben`, alors « Benny's · bennys.rp » est proposé.
  - Étant donné un site caché `secret.rp` jamais visité, quand je tape `sec`, alors il n'apparaît pas.
  - Étant donné un client modifié qui appelle `nav:suggest` avec `includeHidden = true`, alors le serveur ignore ce champ.

### [NAV-04] Moteur de recherche fictif
- **But** : trouver des sites par nom, mot ou type.
- **Qui** : tout joueur avec la tablette.
- **Où** : page d'accueil du Navigateur (adresse `Config.Browser.EngineAddress = 'recherche.rp'`), nouvel onglet, Entrée sur une recherche.
- **Parcours** :
  1. Page d'accueil : nom du moteur `Config.Browser.EngineName = 'Recherche LS'` centré, grand champ « Rechercher un site », dessous les types de site en pastilles cliquables (NAV-05) et « Sites les plus visités cette semaine » (5 sites publics, calcul NAV-07).
  2. Recherche → `pop_tablet:nav:search { q, type = nil, page }` → serveur : C3, C4 (5 / 5 s), nettoie `q` (C5, 50 car.), cherche dans `SiteCache` les sites `online` + `maintenance`, `hidden = 0`, dont le nom, l'adresse, le libellé du type ou la description contient chaque mot de `q` (tous les mots, sans accents ni casse).
  3. Classement : nom exactement égal → nom qui commence par `q` → adresse qui commence par `q` → nom contient → description contient ; à égalité, sites d'entreprises ouvertes (ANNU-02) d'abord, puis ordre alphabétique.
  4. 20 résultats par page : nom (lien), adresse en gris, type, description coupée à 140 caractères, pastille « En maintenance » si c'est le cas. Total « {n} résultat(s) pour « {q} » ».
  5. Clic → NAV-01.
- **Données** : `q` 2–50 caractères ; `type` facultatif.
- **Règles serveur** : jamais de site caché ni `offline`.
- **Textes et états** :
  - `navigateur.recherche.placeholder` « Rechercher un site ».
  - `navigateur.recherche.resultats` « {n} résultat(s) pour « {q} » ».
  - Vide : `navigateur.recherche.vide` « Aucun site trouvé pour « {q} ». ».
  - Trop court : `navigateur.recherche.trop_court` « 2 caractères minimum. ».
  - `navigateur.recherche.maintenance` « En maintenance ».
  - `navigateur.recherche.populaires` « Sites les plus visités cette semaine ».
  - Aucun site sur le serveur : `navigateur.accueil.aucun_site` « Aucun site n'existe encore sur ce serveur. ».
- **Notifications** : aucune.
- **Liens** : NAV-05, NAV-07 (popularité), Annuaire (statut ouvert pour le classement).
- **Réglages** : `Config.Browser.EngineName = 'Recherche LS'`, `Config.Browser.EngineAddress = 'recherche.rp'`, `Config.Browser.PageSize = 20`.
- **Journal admin** : non.
- **Performance** : recherche en mémoire sur le cache (quelques centaines de sites max) ; index de recherche (texte sans accents) préparé une fois à chaque changement de site.
- **Cas limites** :
  - Recherche « garage » trouve les sites dont le type ou la description contient « garage ».
  - 0 site sur le serveur → message `aucun_site` sur l'accueil.
  - Site passé en caché pendant la lecture des résultats → le clic l'ouvre quand même (adresse exacte connue).
- **Critères d'acceptation** :
  - Étant donné 3 sites dont « Benny's Original Motor Works », quand je cherche « benny », alors il est premier.
  - Étant donné un site caché dont le nom contient « benny », alors il n'apparaît pas dans les résultats.
  - Étant donné « a » seul, alors « 2 caractères minimum. » s'affiche sans requête.

### [NAV-05] Liste des sites par type
- **But** : parcourir les sites par catégorie sans savoir quoi chercher.
- **Qui** : tout joueur avec la tablette.
- **Où** : page d'accueil du moteur > pastilles de type ; page de résultats > filtre « Type » (liste déroulante).
- **Parcours** :
  1. Clic sur une pastille → `nav:search { q = '', type, page }` → liste des sites publics de ce type, ordre alphabétique, 20 par page, mêmes lignes qu'en NAV-04.
  2. Pastille « Tous » → tous les sites publics, alphabétique.
  3. Sur une page de résultats, le filtre « Type » restreint les résultats déjà demandés.
- **Données** : `type` ∈ `Config.Browser.SiteTypes` ou `tous`.
- **Règles serveur** : type inconnu → traité comme `tous` ; jamais de site caché.
- **Textes et états** :
  - `navigateur.types.tous` « Tous », libellés de types (clés `navigateur.type.<cle>`).
  - Vide : `navigateur.types.vide` « Aucun site de ce type pour l'instant. ».
- **Notifications** : aucune.
- **Liens** : NAV-04.
- **Réglages** : `Config.Browser.SiteTypes` (liste plus haut).
- **Journal admin** : non.
- **Performance** : listes par type pré-triées dans le cache.
- **Cas limites** :
  - Type ajouté par l'admin dans la config sans traduction → affiche la clé brute du type, avertissement console au démarrage.
  - Site avec un type supprimé de la config → classé dans « Autre ».
  - 0 site du type → message vide.
- **Critères d'acceptation** :
  - Étant donné 2 sites « Boutique », quand je clique « Boutique », alors ces 2 sites s'affichent par ordre alphabétique.
  - Étant donné un site caché de type « Boutique », alors il n'est pas listé.
  - Étant donné un type inconnu envoyé par un client modifié, alors la liste de tous les sites publics revient.

### [NAV-06] Favoris
- **But** : garder ses sites préférés à portée de clic.
- **Qui** : tout joueur avec la tablette.
- **Où** : Navigateur > étoile dans la barre d'adresse ; menu « ☰ » > « Favoris ».
- **Parcours** :
  1. Clic sur l'étoile vide → `nav:favAdd { address, path, title, actionId }` → serveur : C3, C4 (5 / 10 s), C10, vérifie que la page existe (`SiteCache`), nombre < 30, pas déjà en favori (`UNIQUE(owner, address, path)`), `INSERT`. Étoile pleine.
  2. Clic sur l'étoile pleine → `nav:favRemove { address, path }` → suppression.
  3. Écran « Favoris » : liste (titre, adresse), ordre manuel (glisser-déposer → `nav:favOrder { ids[] }`), bouton « Renommer » (titre 40 car.), bouton « Supprimer ».
  4. Les favoris sont chargés une fois à l'ouverture du Navigateur (`nav:init`, voir NAV-07) pour les suggestions.
- **Données** : table `pop_tablet_nav_favorites` :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `id` | INT auto | oui | — | — |
| `owner` | VARCHAR(12), index | oui | numéro de série de la tablette (C2) | — |
| `address` | VARCHAR(40) | oui | format d'adresse | — |
| `path` | VARCHAR(60) | oui | — | `/` |
| `title` | VARCHAR(40) | oui | 1–40 car. | titre de la page |
| `position` | SMALLINT | oui | 0–29 | dernier |
| `created_at` | DATETIME | oui | — | maintenant |

- **Règles serveur** : propriétaire ; 30 max ; adresse existante au moment de l'ajout ; titre nettoyé (C5).
- **Textes et états** :
  - Titre écran : `navigateur.favoris.titre` « Favoris ».
  - Vide : `navigateur.favoris.vide` « Aucun favori. » + bouton `navigateur.favoris.aller_accueil` « Aller à l'accueil ».
  - Succès : `navigateur.favoris.ajoute` « Ajouté aux favoris. », `navigateur.favoris.retire` « Retiré des favoris. », `navigateur.favoris.renomme` « Favori renommé. ».
  - Limite : `navigateur.favoris.limite` « Limite de {max} favoris atteinte. ».
  - Favori vers un site disparu : la ligne reste, en gris, avec `navigateur.favoris.indisponible` « Site indisponible ».
- **Notifications** : aucune.
- **Liens** : NAV-03.
- **Réglages** : `Config.Browser.MaxFavorites = 30`.
- **Journal admin** : non.
- **Performance** : favoris chargés une fois par ouverture du Navigateur ; écritures directes (rares).
- **Cas limites** :
  - Ajout d'une page introuvable → étoile désactivée sur les pages d'erreur.
  - Site caché mis en favori → reste accessible ; le favori ne révèle rien aux autres joueurs.
  - Double clic sur l'étoile → C10 + unicité en base, un seul favori.
- **Critères d'acceptation** :
  - Étant donné une page ouverte, quand je clique l'étoile, alors elle apparaît dans « Favoris » et l'étoile est pleine.
  - Étant donné 30 favoris, quand j'en ajoute un, alors le message de limite s'affiche.
  - Étant donné un client modifié qui ajoute un favori vers une adresse inexistante, alors le serveur refuse avec `navigateur.erreur.introuvable` « Ce site n'existe pas. ».

### [NAV-07] Historique de navigation
- **But** : retrouver un site visité.
- **Qui** : tout joueur avec la tablette.
- **Où** : Navigateur > menu « ☰ » > « Historique » (raccourci `Ctrl+H`).
- **Parcours** :
  1. À l'ouverture du Navigateur, `nav:init` renvoie favoris + 20 dernières entrées d'historique (pour les suggestions).
  2. Chaque page chargée avec succès (NAV-01) est ajoutée par le serveur via `WriteQueue` (C11), sauf si la dernière entrée du joueur est la même page (pas de doublon consécutif). À l'écriture du paquet, le serveur supprime les entrées au-delà des 100 plus récentes du joueur.
  3. Écran Historique : entrées groupées par jour (« Aujourd'hui », « Hier », date), chaque ligne : heure, titre, adresse ; 20 par page (`nav:history { page }`).
  4. Croix sur une ligne → `nav:historyDelete { id }`. Bouton « Effacer l'historique » → confirmation « Effacer tout l'historique ? » → `nav:historyClear`.
  5. Popularité (NAV-04) : le serveur garde en mémoire un compteur de visites par site public sur 7 jours glissants (seaux journaliers), reconstruit au démarrage depuis la table.
- **Données** : table `pop_tablet_nav_history` : `id` INT auto, `owner` VARCHAR(60), `address` VARCHAR(40), `path` VARCHAR(60), `title` VARCHAR(60), `visited_at` DATETIME ; index `(owner, visited_at)`.
- **Règles serveur** : propriétaire ; 100 entrées max par joueur ; aucune entrée pour les pages introuvables.
- **Textes et états** :
  - Titre : `navigateur.historique.titre` « Historique ».
  - Groupes : `commun.date.aujourdhui` « Aujourd'hui », `commun.date.hier` « Hier ».
  - Vide : `navigateur.historique.vide` « Aucun site visité pour l'instant. » + bouton `navigateur.favoris.aller_accueil` « Aller à l'accueil ».
  - `navigateur.historique.effacer` « Effacer l'historique », confirmation `navigateur.historique.confirmer` « Effacer tout l'historique ? », succès `navigateur.historique.efface` « Historique effacé. ».
- **Notifications** : aucune.
- **Liens** : NAV-03, NAV-04.
- **Réglages** : `Config.Browser.HistorySize = 100`.
- **Journal admin** : non (l'historique n'est pas une donnée sensible ni visible par l'admin dans la tablette).
- **Performance** : écritures groupées toutes les 5 s ; lecture paginée ; suppression des surplus faite pendant l'écriture groupée.
- **Cas limites** :
  - Joueur déconnecté avant l'écriture du paquet → la file est vidée à l'écriture suivante (elle ne dépend pas du joueur).
  - Arrêt de la ressource → `onResourceStop` vide la file.
  - Effacement pendant qu'une écriture est en file → la file retire d'abord les entrées en attente de ce joueur.
- **Critères d'acceptation** :
  - Étant donné 3 pages visitées, quand j'ouvre l'historique, alors elles sont sous « Aujourd'hui », la plus récente en haut.
  - Étant donné « Effacer l'historique » confirmé, alors la liste est vide et les suggestions n'affichent plus de récents.
  - Étant donné un client modifié qui supprime l'entrée d'un autre joueur, alors rien n'est supprimé.

### [NAV-08] Onglets (3 maximum)
- **But** : garder jusqu'à 3 pages ouvertes en même temps.
- **Qui** : tout joueur avec la tablette.
- **Où** : Navigateur > barre d'onglets en haut > bouton « + » ; croix sur chaque onglet.
- **Parcours** :
  1. Au premier lancement, 1 onglet sur la page d'accueil du moteur.
  2. « + » → nouvel onglet sur l'accueil du moteur, il devient actif. Raccourci `Ctrl+T`.
  3. Clic sur un onglet → le rend actif (sa page est réaffichée depuis le cache client si < 60 s, sinon rechargée).
  4. Croix (ou `Ctrl+W`) → ferme l'onglet ; l'onglet à sa gauche devient actif (ou à droite s'il n'y en a pas). Fermer le dernier onglet le remplace par un onglet sur l'accueil (il y a toujours au moins 1 onglet).
  5. Clic molette sur un lien, ou « Voir le site » depuis une autre app → nouvel onglet s'il en reste, sinon remplace la page de l'onglet actif.
  6. État des onglets (adresse, chemin, historique ← → de chaque onglet) gardé dans la mémoire du client Lua pour la session de jeu : fermer/rouvrir la tablette retrouve les mêmes onglets. Perdu à la déconnexion.
- **Données** : par onglet : `id`, `address`, `path`, `title`, pile de retour (20 max), pile d'avance.
- **Règles serveur** : aucune (état local) ; chaque chargement passe par NAV-01.
- **Textes et états** :
  - Limite : `navigateur.onglets.limite` « 3 onglets maximum. » (bouton « + » grisé avec cette bulle).
  - Titre d'un onglet sur l'accueil : `navigateur.onglets.nouveau` « Nouvel onglet ».
- **Notifications** : aucune.
- **Liens** : NAV-01, NAV-12.
- **Réglages** : `Config.Browser.MaxTabs = 3`.
- **Journal admin** : non.
- **Performance** : seul l'onglet actif est rendu ; les autres gardent juste leurs données.
- **Cas limites** :
  - 3 onglets + « Voir le site » depuis l'Annuaire → l'onglet actif est remplacé.
  - Titre de page trop long → coupé avec « … » à 20 caractères dans l'onglet, complet en bulle.
  - Ressource redémarrée → onglets remis à 1 onglet d'accueil.
- **Critères d'acceptation** :
  - Étant donné 3 onglets, quand je clique « + », alors rien ne s'ouvre et le message de limite apparaît.
  - Étant donné 2 onglets ouverts, quand je ferme et rouvre la tablette, alors je retrouve les 2 onglets.
  - Étant donné 1 seul onglet, quand je le ferme, alors un onglet « Nouvel onglet » le remplace.

### [NAV-09] Sites cachés
- **But** : permettre des sites secrets, absents de la recherche, accessibles seulement à qui connaît l'adresse exacte.
- **Qui** : visite : tout joueur avec la tablette. Le réglage « caché » est fait dans la branche Sites web par un gérant du site.
- **Où** : Navigateur > barre d'adresse (adresse exacte).
- **Parcours** :
  1. Un site `hidden = 1` n'apparaît jamais dans : recherche (NAV-04), types (NAV-05), suggestions serveur (NAV-03), popularité, Annuaire (pas de bouton « Voir le site », ANNU-04), Carte (pas de bouton site).
  2. Le joueur tape l'adresse exacte (`nom.rp`, normalisation C appliquée : majuscules et `https://` tolérés, **aucune** correction de faute) → NAV-01 l'affiche normalement.
  3. Le site reste dans l'historique et les favoris du joueur qui l'a visité.
  4. Anti-devinette : chaque réponse `notfound` compte pour le joueur ; au-delà de `Config.Browser.NotFoundLimit = 10` adresses introuvables en 60 s, le joueur reçoit pendant 60 s `navigateur.erreur.trop_essais` sur toute adresse (même existante).
- **Données** : champ `hidden` (Sites web).
- **Règles serveur** : filtre `hidden = 0` appliqué **côté serveur** à toutes les listes ; compteur d'introuvables par joueur en mémoire.
- **Textes et états** :
  - `navigateur.erreur.trop_essais` « Trop d'adresses introuvables. Réessayez dans une minute. ».
  - Aucune mention « site caché » n'est affichée au visiteur (le site ressemble à un site normal).
- **Notifications** : aucune.
- **Liens** : Sites web (champ caché), Annuaire, Carte.
- **Réglages** : `Config.Browser.NotFoundLimit = 10`, `Config.Browser.NotFoundWindowSec = 60`, `Config.Browser.NotFoundBlockSec = 60`.
- **Journal admin** : oui si le blocage anti-devinette se déclenche (`nav_bruteforce` : joueur, nombre d'essais).
- **Performance** : compteur mémoire par joueur, effacé à la déconnexion.
- **Cas limites** :
  - Adresse à une lettre près → page introuvable (aucune suggestion du site caché).
  - Joueur qui partage l'adresse en RP → l'autre joueur y accède normalement.
  - Site caché en maintenance → page de maintenance (même règle), ce qui confirme l'existence : accepté.
- **Critères d'acceptation** :
  - Étant donné `planque.rp` caché, quand je cherche « planque », alors aucun résultat.
  - Étant donné `planque.rp` caché, quand je tape `planque.rp`, alors le site s'ouvre.
  - Étant donné un client modifié qui tape 50 adresses au hasard en 30 s, alors après 10 introuvables il est bloqué 60 s et le journal admin contient `nav_bruteforce`.

### [NAV-10] Page « site introuvable »
- **But** : dire clairement qu'une adresse ou une page n'existe pas.
- **Qui** : tout joueur avec la tablette.
- **Où** : Navigateur > réponse `notfound` ou `pagenotfound` de NAV-01.
- **Parcours** :
  1. `notfound` → page centrée : grand titre « Site introuvable », texte, bouton « Rechercher « {nom} » » (lance NAV-04 avec le nom sans extension), bouton « Accueil ».
  2. `pagenotfound` → titre « Page introuvable », texte, bouton « Accueil du site » (ouvre `/` du même site).
  3. La barre d'adresse garde l'adresse tapée ; l'étoile favori est désactivée ; l'onglet a pour titre « Introuvable ».
- **Données** : aucune.
- **Règles serveur** : NAV-01, NAV-09 (compteur).
- **Textes et états** :
  - `navigateur.introuvable.titre` « Site introuvable ».
  - `navigateur.introuvable.texte` « L'adresse « {adresse} » ne correspond à aucun site. ».
  - `navigateur.introuvable.rechercher` « Rechercher « {nom} » », `navigateur.introuvable.accueil` « Accueil ».
  - `navigateur.page_introuvable.titre` « Page introuvable », `navigateur.page_introuvable.texte` « Cette page n'existe pas ou a été retirée du site {site}. », `navigateur.page_introuvable.accueil_site` « Accueil du site ».
  - Onglet : `navigateur.onglets.introuvable` « Introuvable ».
- **Notifications** : aucune.
- **Liens** : NAV-04.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : page statique de la NUI, aucune requête de plus.
- **Cas limites** :
  - Adresse invalide (`a.rp`, trop courte) → même page introuvable, sans requête serveur.
  - Site `offline` → introuvable (on ne dit pas qu'il a existé).
  - Entreprise propriétaire archivée → introuvable.
- **Critères d'acceptation** :
  - Étant donné `inexistant.rp`, quand je l'ouvre, alors « Site introuvable » s'affiche avec « Rechercher « inexistant » ».
  - Étant donné `bennys.rp/xyz`, alors « Page introuvable » et « Accueil du site » mènent à `bennys.rp`.
  - Étant donné un site supprimé, alors on voit « Site introuvable » et pas « en maintenance ».

### [NAV-11] Page « site en maintenance »
- **But** : prévenir qu'un site est temporairement fermé.
- **Qui** : tout joueur sauf gérants du site (`site.modifier`) et admin, qui voient l'aperçu (NAV-01).
- **Où** : Navigateur > réponse `maintenance` de NAV-01.
- **Parcours** :
  1. Page centrée : nom du site, titre « Site en maintenance », message du propriétaire (si rempli, texte nettoyé C5, 200 car.) sinon message par défaut, bouton « Réessayer » (recharge) et « Accueil ».
  2. L'étoile favori reste active (on peut garder en favori un site en maintenance).
- **Données** : `maintenance_message` (Sites web).
- **Règles serveur** : NAV-01.
- **Textes et états** :
  - `navigateur.maintenance.titre` « Site en maintenance ».
  - Par défaut : `navigateur.maintenance.texte` « Site momentanément indisponible. ».
  - Boutons : `commun.bouton.reessayer` « Réessayer », `navigateur.introuvable.accueil` « Accueil ».
- **Notifications** : aucune.
- **Liens** : Sites web (statut, message).
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : aucun bloc de page envoyé, seulement nom + message.
- **Cas limites** :
  - Site remis en ligne pendant que la page est affichée → « Réessayer » affiche le site.
  - Message contenant du HTML → texte brut.
  - Gérant hors de son entreprise depuis peu (viré) → voit la page de maintenance (droit revérifié à chaque chargement).
- **Critères d'acceptation** :
  - Étant donné un site en maintenance avec le message « Retour lundi », quand un civil l'ouvre, alors il voit « Site en maintenance » et « Retour lundi ».
  - Étant donné le même site, quand un Chef de l'entreprise l'ouvre, alors il voit le site avec le bandeau d'aperçu.
  - Étant donné un client modifié qui demande `preview = true`, alors le serveur l'ignore et renvoie la page de maintenance.

### [NAV-12] Précédent, suivant, actualiser, accueil (ajout)
- **But** : naviguer comme dans un vrai navigateur.
- **Qui** : tout joueur avec la tablette.
- **Où** : Navigateur > boutons ←, →, ⟳, ⌂ à gauche de la barre d'adresse ; souris boutons 4/5 ; `Alt+←` / `Alt+→` ; `F5`.
- **Parcours** :
  1. ← : ouvre la page précédente de la pile de l'onglet (depuis le cache client si < 60 s). Grisé si pile vide.
  2. → : page suivante. Grisé si pile vide. Toute nouvelle navigation vide la pile « suivant ».
  3. ⟳ : recharge la page actuelle depuis le serveur (ignore le cache client).
  4. ⌂ : page d'accueil du moteur.
  5. Échap dans le Navigateur (hors barre d'adresse et hors fenêtre) : agit comme ← si la pile n'est pas vide, sinon règle générale (retour à l'accueil de la tablette).
- **Données** : piles par onglet, 20 entrées max chacune.
- **Règles serveur** : chaque rechargement passe par NAV-01.
- **Textes et états** : bulles `navigateur.bouton.precedent` « Précédent », `navigateur.bouton.suivant` « Suivant », `navigateur.bouton.actualiser` « Actualiser », `navigateur.bouton.accueil` « Accueil ».
- **Notifications** : aucune.
- **Liens** : NAV-08.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : retour arrière sans requête quand le cache est valide.
- **Cas limites** :
  - Retour vers une page dont le site est passé en maintenance (cache expiré) → page de maintenance.
  - 21e page → la plus ancienne sort de la pile.
  - ⟳ répété → C4 limite à 10 / 10 s.
- **Critères d'acceptation** :
  - Étant donné A puis B ouverts, quand je clique ←, alors A s'affiche, puis → réaffiche B.
  - Étant donné une page en cache, quand je clique ⟳, alors le serveur est interrogé.
  - Étant donné la pile vide, alors ← est grisé.

---

## 6. Annuaire

Données lues dans la branche Entreprises (cache serveur `CompanyCache`) : `id`, `name` (40 car.), `category` (une de `Config.Directory.Categories`), `description` (500 car.), `logo` (image C6), `address_label` (80 car., ex. « Strawberry Ave, garage bleu »), `coords` (vector3 ou NULL), `site_address` (ou NULL), `directory_visible` (0/1), `archived` (0/1), `force_closed` (0/1, ajout ANNU-02).

Catégories par défaut (`Config.Directory.Categories`) : `services_publics` « Services publics », `sante` « Santé », `securite` « Sécurité », `automobile` « Automobile », `restauration` « Restauration », `commerce` « Commerce », `immobilier` « Immobilier », `loisirs` « Loisirs », `transport` « Transport », `autre` « Autre ».

### [ANNU-01] Liste des entreprises
- **But** : voir toutes les entreprises de la ville.
- **Qui** : tout joueur avec la tablette.
- **Où** : Accueil > branche Navigateur > icône « Annuaire » ; aussi lien « Annuaire » sur la page d'accueil du moteur de recherche.
- **Parcours** :
  1. Ouverture → `pop_tablet:directory:list { category = 'toutes', q = '', openOnly = false, page = 1 }`.
  2. Serveur : C3, C4 (10 / 10 s), filtre `CompanyCache` (`directory_visible = 1`, `archived = 0`), applique la catégorie, la recherche `q` (2–40 car., sur le nom et la description, sans accents ni casse) et « ouvertes seulement », ajoute le statut (ANNU-02), trie : ouvertes d'abord, puis alphabétique ; 20 par page.
  3. Écran : champ « Rechercher une entreprise », pastilles de catégories (« Toutes » + catégories qui ont au moins une entreprise), interrupteur « Ouvertes seulement », liste de cartes : logo (carré 48 px, initiale du nom sur fond d'accent si pas de logo), nom, catégorie, pastille « Ouvert » (couleur d'accent) / « Fermé » (gris).
  4. Clic sur une carte → fiche (ANNU-03).
  5. Pendant que l'Annuaire est ouvert, le joueur est inscrit comme « spectateur » ; les changements de statut lui sont poussés (ANNU-02).
- **Données** : affichage seul.
- **Règles serveur** : entreprises archivées ou masquées jamais renvoyées ; `page` ≥ 1.
- **Textes et états** :
  - `annuaire.recherche.placeholder` « Rechercher une entreprise ».
  - `annuaire.categories.toutes` « Toutes », `annuaire.filtre.ouvertes` « Ouvertes seulement ».
  - Pastilles : `annuaire.statut.ouvert` « Ouvert », `annuaire.statut.ferme` « Fermé ».
  - Vide (aucune entreprise sur le serveur) : `annuaire.liste.vide` « Aucune entreprise n'est inscrite dans l'annuaire. » (pas de bouton : l'inscription se fait par la branche Entreprises).
  - Vide (filtres) : `annuaire.liste.vide_filtre` « Aucune entreprise ne correspond. » + bouton `annuaire.liste.effacer_filtres` « Effacer les filtres ».
- **Notifications** : aucune.
- **Liens** : Entreprises (données), Prise de service (statut), Carte, Navigateur.
- **Réglages** : `Config.Directory.Categories`, `Config.Directory.PageSize = 20`, `Config.Directory.ShowOnDutyCount = false` (si `true`, la carte affiche « {n} en service »).
- **Journal admin** : non.
- **Performance** : tout en mémoire (cache) ; une requête par changement de filtre ou de page ; recherche avec attente de 300 ms après frappe.
- **Cas limites** :
  - Entreprise archivée pendant que la liste est affichée → disparaît au prochain chargement ; sa fiche ouverte affiche `commun.entreprise.archivee`.
  - Logo d'un domaine retiré de la liste autorisée → initiale à la place.
  - 0 entreprise dans une catégorie → la pastille de cette catégorie n'est pas affichée.
- **Critères d'acceptation** :
  - Étant donné 2 garages dont 1 ouvert, quand je filtre « Automobile », alors l'ouvert est en premier.
  - Étant donné « Ouvertes seulement » activé, alors seules les entreprises ouvertes s'affichent.
  - Étant donné une entreprise masquée de l'annuaire, quand un client modifié demande la liste avec `includeHidden = true`, alors elle n'apparaît pas.

### [ANNU-02] Statut ouvert / fermé
- **But** : savoir si une entreprise peut répondre maintenant.
- **Qui** : affichage pour tous ; « Fermer temporairement » (ajout) pour le Patron (réglable par la grille de droits sous la clé `annuaire.fermer`, défaut Patron).
- **Où** : Annuaire (liste et fiche), Carte (couleur des icônes), Recherche du Navigateur (classement).
- **Parcours** :
  1. Le serveur tient en mémoire `OnDuty[companyId] = nombre d'employés en service et connectés`, mis à jour par les événements de la base `pop_tablet:dutyChanged(source, { identifier, companyId, job, onDuty })` et à la déconnexion d'un joueur en service.
  2. Statut = « Ouvert » si `OnDuty >= 1` **et** `force_closed = 0` ; sinon « Fermé ».
  3. Quand le statut d'une entreprise **change** (0 ↔ ≥ 1, ou fermeture forcée), le serveur attend 5 s (regroupe les changements rapides) puis envoie `pop_tablet:directory:status { id, open }` aux seuls spectateurs de l'Annuaire (ANNU-01) et met à jour le cache de la carte.
  4. (ajout) Fiche de l'entreprise, pour qui a `annuaire.fermer` : interrupteur « Fermer temporairement l'entreprise » → `directory:forceClosed { companyId, value }` → serveur : C3, C4 (3 / 30 s), C7, met à jour `force_closed` (branche Entreprises), applique l'étape 3. Remis à 0 automatiquement quand le dernier employé en service le quitte (pour ne pas oublier l'entreprise fermée).
- **Données** : `OnDuty` (mémoire), `force_closed` (base, branche Entreprises).
- **Règles serveur** : statut toujours calculé par le serveur ; seuls les employés réellement en service et connectés comptent.
- **Textes et états** :
  - `annuaire.statut.ouvert` « Ouvert », `annuaire.statut.ferme` « Fermé ».
  - `annuaire.fermer.interrupteur` « Fermer temporairement l'entreprise », succès `annuaire.fermer.ferme` « L'entreprise apparaît fermée dans l'annuaire. », `annuaire.fermer.ouvert` « L'entreprise apparaît de nouveau selon le service. ».
  - Pas le droit : interrupteur caché.
- **Notifications** : aucune (mise à jour visuelle seulement).
- **Liens** : Prise de service (base), Carte, Navigateur (classement), Demandes (message « fermée » en ANNU-05).
- **Réglages** : `Config.Directory.StatusDebounceSec = 5`, droit `annuaire.fermer` (défaut Patron).
- **Journal admin** : oui pour la fermeture forcée (`directory_force_closed` : qui, entreprise, valeur).
- **Performance** : compteur en mémoire, aucune requête base pour le statut ; push seulement aux spectateurs ; regroupement de 5 s.
- **Cas limites** :
  - Seul employé en service qui crashe → `playerDropped` décrémente, statut « Fermé » 5 s plus tard.
  - Redémarrage de la ressource → compteur reconstruit à partir des joueurs connectés en service (base).
  - Employé en service de deux entreprises (si la base le permet) → compte pour les deux.
- **Critères d'acceptation** :
  - Étant donné une entreprise fermée, quand un employé prend son service, alors en 6 s max l'Annuaire ouvert d'un autre joueur la montre « Ouvert ».
  - Étant donné « Fermer temporairement » activé avec 2 employés en service, alors elle apparaît « Fermé ».
  - Étant donné un client modifié qui envoie `forceClosed` pour une autre entreprise que la sienne, alors le serveur refuse avec `commun.erreur.pas_droit`.

### [ANNU-03] Fiche d'une entreprise (ajout)
- **But** : voir les infos d'une entreprise et agir (GPS, site, demande).
- **Qui** : tout joueur avec la tablette.
- **Où** : Annuaire > clic sur une carte ; Carte > bulle > « Fiche ».
- **Parcours** :
  1. `directory:get { id }` → serveur : C3, C4, renvoie depuis le cache : nom, logo, catégorie, statut, description, adresse texte, a une position (oui/non), site public (adresse si `site_address` non caché et en ligne/maintenance), droit du joueur à fermer temporairement.
  2. Écran : logo + nom + statut en en-tête, catégorie, description (texte nettoyé, sauts de ligne gardés), adresse, boutons : « GPS » (si position, OUT-CAR-03), « Voir le site » (ANNU-04), « Faire une demande » (ANNU-05).
- **Données** : affichage seul.
- **Règles serveur** : entreprise visible et non archivée.
- **Textes et états** :
  - Boutons : `annuaire.fiche.gps` « GPS », `annuaire.fiche.site` « Voir le site », `annuaire.fiche.demande` « Faire une demande ».
  - Pas de description : `annuaire.fiche.sans_description` « Cette entreprise n'a pas encore de description. ».
  - Pas d'adresse : ligne masquée.
  - Introuvable : `annuaire.fiche.introuvable` « Cette entreprise n'est plus dans l'annuaire. » (retour liste).
- **Notifications** : aucune.
- **Liens** : Carte, Navigateur, Demandes.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : lecture du cache.
- **Cas limites** :
  - Pas de position → bouton GPS caché.
  - Site caché → bouton « Voir le site » caché.
  - Entreprise masquée entre la liste et le clic → message introuvable.
- **Critères d'acceptation** :
  - Étant donné une entreprise avec position et site public, quand j'ouvre sa fiche, alors les 3 boutons sont visibles.
  - Étant donné « GPS », quand je clique, alors le waypoint est posé sur sa position.
  - Étant donné un client modifié qui demande la fiche d'une entreprise masquée, alors le serveur renvoie introuvable.

### [ANNU-04] Lien vers le site de l'entreprise
- **But** : ouvrir le site de l'entreprise depuis l'annuaire.
- **Qui** : tout joueur avec la tablette.
- **Où** : Annuaire > fiche > « Voir le site » ; aussi petite icône globe sur la carte de l'entreprise dans la liste.
- **Parcours** :
  1. Clic → la tablette ouvre le Navigateur sur `site_address` dans un nouvel onglet (NAV-08 ; remplace l'onglet actif si 3 sont ouverts).
  2. Le chargement suit NAV-01 (introuvable / maintenance gérés là).
- **Données** : `site_address`.
- **Règles serveur** : l'adresse n'est envoyée au client que si le site est public (`hidden = 0`) et `online` ou `maintenance`.
- **Textes et états** : bouton `annuaire.fiche.site` « Voir le site » ; bulle de l'icône globe `annuaire.liste.site` « Site web ».
- **Notifications** : aucune.
- **Liens** : Navigateur.
- **Réglages** : aucun.
- **Journal admin** : non.
- **Performance** : aucune requête de plus côté annuaire.
- **Cas limites** :
  - Site supprimé depuis l'ouverture de la fiche → page introuvable du Navigateur.
  - Site passé caché → bouton caché au prochain chargement de la fiche.
  - Navigateur désactivé par l'admin (`Config.Apps.Browser = false`) → bouton caché.
- **Critères d'acceptation** :
  - Étant donné une entreprise avec site public, quand je clique « Voir le site », alors le Navigateur s'ouvre sur ce site.
  - Étant donné 3 onglets ouverts, alors l'onglet actif est remplacé par le site.
  - Étant donné un site caché, alors l'annuaire n'envoie jamais son adresse au client (vérifiable dans la réponse).

### [ANNU-05] Demande de contact
- **But** : écrire à une entreprise ; la demande arrive dans sa boîte « Demandes ».
- **Qui** : tout joueur avec la tablette, sauf les employés de l'entreprise visée.
- **Où** : Annuaire > fiche > « Faire une demande ».
- **Parcours** :
  1. Formulaire : « Objet » (liste : Contact, Rendez-vous, Devis, Dépannage ; défaut Contact), « Message » (zone de texte, 10–500 caractères, compteur), « Téléphone (facultatif) » (20 caractères, chiffres, espaces, `+`, `-`, pour les serveurs avec téléphone), case « Partager ma position actuelle » (cochée par défaut si l'objet est Dépannage, sinon décochée), bouton « Envoyer ».
  2. Si l'entreprise est fermée, un encadré au-dessus du bouton : « Entreprise fermée. La demande sera lue au retour d'un employé. »
  3. `directory:request { companyId, type, message, phone, sharePos, actionId }`.
  4. Serveur : C3, C4 (`directory:request` 1 / 60 s), C10, entreprise visible et non archivée, le joueur n'en est pas employé, C5 (message 500 multiligne, phone 20 et caractères autorisés), longueur min 10, limite anti-spam (au plus 1 demande vers la même entreprise toutes les 10 min, et au plus 3 demandes ouvertes du même joueur vers la même entreprise), position lue **par le serveur** si `sharePos` (`GetEntityCoords`).
  5. Le serveur crée la demande par la fonction de la branche Entreprises `Requests.Create({ companyId, type, fromIdentifier, fromName, message, phone, coords, source = 'annuaire' })` (boîte unique « Demandes »).
  6. Bandeau succès, retour à la fiche ; le joueur suit sa demande dans « Mes demandes » de la branche Entreprises (réponses de l'entreprise).
- **Données** :

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `type` | ENUM('contact','rendez_vous','devis','depannage') | oui | — | `contact` |
| `message` | TEXT | oui | 10–500 car. | — |
| `phone` | VARCHAR(20) | non | `[0-9 +-]` | NULL |
| `coords` | vector3 | non | lue par le serveur | NULL |
| `source` | VARCHAR(20) | oui | `annuaire` | `annuaire` |

  (stockés dans la table de la boîte Demandes de la branche Entreprises).
- **Règles serveur** : voir parcours ; `fromName` = nom RP complet ESX (l'entreprise doit savoir qui écrit).
- **Textes et états** :
  - Titre : `annuaire.demande.titre` « Faire une demande à {entreprise} ».
  - Champs : `annuaire.demande.objet` « Objet », options `annuaire.demande.type.contact` « Contact », `annuaire.demande.type.rendez_vous` « Rendez-vous », `annuaire.demande.type.devis` « Devis », `annuaire.demande.type.depannage` « Dépannage » ; `annuaire.demande.message` « Message », placeholder `annuaire.demande.message_placeholder` « Décrivez votre demande en quelques phrases. » ; `annuaire.demande.telephone` « Téléphone (facultatif) » ; `annuaire.demande.position` « Partager ma position actuelle » ; bouton `annuaire.demande.envoyer` « Envoyer ».
  - Fermée : `annuaire.demande.fermee` « Entreprise fermée. La demande sera lue au retour d'un employé. ».
  - Succès : `annuaire.demande.envoyee` « Demande envoyée. La réponse apparaîtra dans « Mes demandes ». ».
  - Trop court : `annuaire.demande.trop_court` « 10 caractères minimum. ».
  - Délai : `annuaire.demande.trop_tot` « Message déjà envoyé à cette entreprise. Réessayez dans {minutes} min. ».
  - Trop de demandes ouvertes : `annuaire.demande.trop_ouvertes` « Déjà {max} demandes en attente auprès de cette entreprise. ».
  - Employé : `annuaire.demande.employe` « Vous faites partie de cette entreprise. Utilisez sa boîte Demandes. » (bouton « Faire une demande » remplacé par ce texte).
  - Téléphone invalide : `annuaire.demande.telephone_invalide` « Le numéro ne peut contenir que des chiffres, des espaces, + et -. ».
- **Notifications** : employés de l'entreprise **en service**, avec le droit `demandes.repondre` et la tablette (C14) : titre `demandes.notif.nouvelle` « Nouvelle demande : {objet} », texte `demandes.notif.texte` « {nom} a écrit via l'annuaire. », action = ouvrir la demande. Si personne n'est en service : aucune notification immédiate ; la pastille de la boîte Demandes s'allume pour les employés à leur prochaine ouverture de tablette.
- **Liens** : Demandes (branche Entreprises), Prise de service. Signal API `pop_tablet:requestCreated { companyId, type, source }` (émis par `Requests.Create`).
- **Réglages** : `Config.Directory.RequestCooldownMin = 10`, `Config.Directory.MaxOpenRequests = 3`, `Config.Directory.RequestMinLength = 10`, `Config.Directory.RequestMaxLength = 500`, `Config.Directory.AllowPhone = true`.
- **Journal admin** : non (la boîte Demandes garde la trace).
- **Performance** : 1 écriture ; notifications aux seuls employés en service concernés.
- **Cas limites** :
  - Double clic sur « Envoyer » → une seule demande (C10).
  - Entreprise archivée entre l'ouverture et l'envoi → `commun.entreprise.archivee`.
  - Joueur à l'intérieur instancié qui partage sa position → la position extérieure du ped est envoyée telle quelle (le serveur ne corrige pas).
  - `Config.Directory.AllowPhone = false` → champ téléphone caché et ignoré par le serveur.
- **Critères d'acceptation** :
  - Étant donné un garage ouvert, quand j'envoie une demande « Dépannage » avec position, alors elle apparaît dans la boîte Demandes du garage avec ma position et les mécanos en service reçoivent la notification.
  - Étant donné une demande envoyée il y a 2 min, quand j'en envoie une autre au même garage, alors le message de délai s'affiche.
  - Étant donné un client modifié qui envoie `coords` d'un autre endroit, alors le serveur ignore ce champ et prend ma vraie position.
  - Étant donné un employé du garage, alors il ne voit pas le bouton « Faire une demande » sur la fiche de son entreprise.

---

## 7. Tableur (Gestion pro)

Tables communes :

`pop_tablet_sheets`

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `id` | INT auto | oui | — | — |
| `company_id` | INT, index | oui | — | — |
| `name` | VARCHAR(40) | oui | 1–40 car., unique dans l'entreprise parmi les non archivées | — |
| `template` | VARCHAR(20) | oui | `vide`, `compta`, `ventes`, `clients` | `vide` |
| `col_widths` | JSON | oui | tableau de `MaxCols` entiers 40–400 | 100 partout |
| `read_level` | TINYINT NULL | non | 1 Recrue, 2 Membre, 3 Chef, 4 Patron ; NULL = droit `tableur.lire` de l'entreprise | NULL |
| `edit_level` | TINYINT NULL | non | idem, ≥ `read_level` ; NULL = droit `tableur.modifier` | NULL |
| `import_source` | VARCHAR(10) NULL | non | `factures`, `compte` | NULL |
| `import_paused` | TINYINT(1) | oui | 1 = feuille pleine | 0 |
| `created_by` | VARCHAR(60) | oui | — | — |
| `created_at`, `updated_at` | DATETIME | oui | — | maintenant |
| `archived_at` / `archived_by` | DATETIME / VARCHAR(60) NULL | non | — | NULL |

`pop_tablet_sheet_cells` (stockage creux : seules les cellules non vides ou mises en forme existent)

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `sheet_id` | INT | oui | clé primaire (`sheet_id`, `r`, `c`) | — |
| `r` | SMALLINT | oui | 1–`MaxRows` | — |
| `c` | SMALLINT | oui | 1–`MaxCols` (1 = A) | — |
| `raw` | VARCHAR(500) | oui | saisie brute (texte, nombre ou formule commençant par `=`) | `''` |
| `fmt` | ENUM('auto','texte','nombre','montant','date') | oui | — | `auto` |
| `bold` | TINYINT(1) | oui | 0/1 | 0 |
| `bg` | TINYINT | oui | 0 = aucun, 1–8 = palette | 0 |
| `updated_by` | VARCHAR(60) | oui | — | — |
| `updated_at` | DATETIME | oui | — | maintenant |

Limites (C : configurables) : `Config.Sheets.MaxSheetsPerCompany = 20` (plafond dur 100), `Config.Sheets.MaxRows = 200` (plafond dur 1 000), `Config.Sheets.MaxCols = 26` (A à Z, plafond dur 26), `Config.Sheets.MaxCellLength = 500`, `Config.Sheets.PerCompany = {}` (surcharges par nom de métier ESX, ex. `{ mechanic = { MaxRows = 500 } }`).

Le serveur **ne calcule jamais** les formules : il stocke la saisie brute. Le calcul est fait par un module JavaScript unique `html/js/formula.js` (même code pour tous les joueurs, donc même résultat partout). Une formule n'a aucun effet sur l'argent ni sur le jeu.

### [PRO-TAB-01] Liste des feuilles de l'entreprise
- **But** : voir et ouvrir les feuilles de calcul de son entreprise.
- **Qui** : employés avec `tableur.lire` (défaut Membre) ; chaque feuille peut avoir son propre niveau (PRO-TAB-09).
- **Où** : Accueil > branche Entreprises > Gestion pro > « Tableur ».
- **Parcours** :
  1. Ouverture → `pop_tablet:sheets:list { companyId, archived = false, page = 1 }` (C16 pour l'entreprise).
  2. Serveur : C3, C4, C7/C8, C15, renvoie les feuilles non archivées que le joueur peut lire (niveau du joueur ≥ niveau de lecture de la feuille), triées par `updated_at` décroissant, 20 par page, avec : nom, modèle, import actif, dernière modification (date + nom), droit de modifier (booléen), compteur « {n} / {max} feuilles ».
  3. Écran : bouton « + Nouvelle feuille » (PRO-TAB-02, visible si `tableur.modifier`), liste en lignes (icône du modèle, nom, « Modifiée {date relative} par {nom} », pastille « Import : factures » / « Import : compte » si actif, pastille « Pleine » si `import_paused`), menu « ⋯ » par ligne (PRO-TAB-14). Onglet « Archivées » visible pour le Patron et l'admin.
  4. Clic → ouvre la feuille (PRO-TAB-04).
- **Données** : affichage seul.
- **Règles serveur** : membre de l'entreprise (C16) ; filtre de lecture par feuille appliqué côté serveur.
- **Textes et états** :
  - Vide : `tableur.liste.vide` « Aucune feuille pour l'instant. » + bouton `tableur.liste.creer` « Créer une feuille » (si droit ; sinon `tableur.liste.vide_lecture` « Aucune feuille partagée avec ce grade. »).
  - `tableur.liste.modifiee` « Modifiée {date} par {nom} », `tableur.liste.compteur` « {n} / {max} feuilles ».
  - Pastilles : `tableur.liste.import_factures` « Import : factures », `tableur.liste.import_compte` « Import : compte », `tableur.liste.pleine` « Pleine ».
  - Onglets : `tableur.liste.actives` « Feuilles », `tableur.liste.archivees` « Archivées ».
  - Pas le droit (grade < `tableur.lire`) : l'icône Tableur est grisée avec `commun.droit.grade_requis`.
- **Notifications** : aucune.
- **Liens** : Entreprises (droits, membres).
- **Réglages** : voir limites plus haut ; `Config.Sheets.PageSize = 20`.
- **Journal admin** : non (lecture).
- **Performance** : liste sans cellules ; index `(company_id, archived_at, updated_at)`.
- **Cas limites** :
  - Joueur viré pendant qu'il regarde la liste → prochain appel refusé, retour à l'accueil avec `commun.erreur.pas_droit`.
  - Entreprise à 20 feuilles → « + Nouvelle feuille » grisé avec la bulle `tableur.erreur.limite_feuilles`.
  - Feuille dont le niveau de lecture est Patron → invisible pour un Chef.
- **Critères d'acceptation** :
  - Étant donné un Membre et 3 feuilles dont 1 réservée au Patron, quand il ouvre le Tableur, alors il voit 2 feuilles.
  - Étant donné une Recrue (défaut), alors l'icône Tableur est grisée avec « Grade requis : … ».
  - Étant donné un client modifié qui demande la liste d'une autre entreprise, alors le serveur refuse avec `commun.erreur.pas_droit`.

### [PRO-TAB-02] Créer une feuille (vide ou modèle)
- **But** : démarrer une nouvelle feuille.
- **Qui** : `tableur.modifier` (défaut Chef).
- **Où** : Tableur > liste > « + Nouvelle feuille ».
- **Parcours** :
  1. Fenêtre : champ « Nom de la feuille » (40 car., pré-rempli selon le modèle choisi), choix du modèle en 4 cartes : « Feuille vide », « Compta mensuelle », « Suivi des ventes », « Liste clients » (aperçu des colonnes sous chaque carte), [Créer] [Annuler].
  2. `sheets:create { companyId, name, template, actionId }` → serveur : C3, C4 (3 / 30 s), C7, C10, C5, nombre de feuilles non archivées < limite, nom unique (sans casse) parmi les non archivées, `INSERT` de la feuille puis des cellules du modèle (PRO-TAB-03) en une transaction.
  3. La feuille s'ouvre directement, bandeau succès.
- **Données** : `name`, `template` (voir table).
- **Règles serveur** : droit, limite, unicité, modèle connu (sinon `vide`).
- **Textes et états** :
  - `tableur.creer.titre` « Nouvelle feuille », `tableur.creer.nom` « Nom de la feuille ».
  - Modèles : `tableur.modele.vide` « Feuille vide », `tableur.modele.compta` « Compta mensuelle », `tableur.modele.ventes` « Suivi des ventes », `tableur.modele.clients` « Liste clients ».
  - Noms pré-remplis : vide « Feuille {n} », compta « Compta {mois} {année} » (mois réel en toutes lettres, ex. « Compta novembre 2026 »), ventes « Ventes {mois} {année} », clients « Clients ».
  - Succès : `tableur.succes.creee` « Feuille créée. ».
  - Erreurs : `tableur.erreur.limite_feuilles` « Limite de {max} feuilles atteinte. », `tableur.erreur.nom_existe` « Une feuille porte déjà ce nom. », `tableur.erreur.nom_vide` « Nom de la feuille requis. ».
- **Notifications** : aucune.
- **Liens** : PRO-TAB-03, PRO-TAB-08 (proposition d'import après création d'une compta ou d'un suivi des ventes : « Remplir automatiquement cette feuille ? » [Oui, configurer] [Plus tard]).
- **Réglages** : limites générales.
- **Journal admin** : oui, `sheet_create` (qui, entreprise, nom, modèle).
- **Performance** : une transaction ; insertion groupée des cellules du modèle (une seule requête multi-lignes).
- **Cas limites** :
  - Nom pré-rempli « Compta novembre 2026 » déjà pris → la NUI ajoute « (2) », puis « (3) ».
  - Double clic sur « Créer » → une seule feuille (C10).
  - Entreprise avec `MaxRows` réglé à 40 et modèle qui utilise 50 lignes → le modèle est coupé à 40 lignes (formules des lignes coupées non créées, totaux ajustés à la dernière ligne existante).
- **Critères d'acceptation** :
  - Étant donné un Chef, quand il crée « Compta mensuelle », alors la feuille s'ouvre avec les en-têtes et formules du modèle.
  - Étant donné 20 feuilles, quand il clique « + Nouvelle feuille », alors le message de limite s'affiche.
  - Étant donné un Membre avec un client modifié qui appelle `sheets:create`, alors le serveur refuse avec `commun.erreur.pas_droit`.

### [PRO-TAB-03] Modèles de feuille
- **But** : fournir 3 feuilles prêtes à l'emploi.
- **Qui** : choix lors de PRO-TAB-02.
- **Où** : fenêtre « Nouvelle feuille ».
- **Parcours** : à la création, le serveur insère exactement ces cellules (ligne 1 = en-têtes en gras avec fond 1 « gris ») :
  - **Compta mensuelle** (`compta`) : A1 « Date » (fmt date), B1 « Libellé », C1 « Catégorie », D1 « Entrée » (montant), E1 « Sortie » (montant), F1 « Solde » (montant), G1 « Par ». Colonnes A, D, E, F formatées pour les lignes 2 à 50 (`fmt` posé sur ces cellules vides). F2 `=D2-E2` ; F3 à F50 `=F{r-1}+D{r}-E{r}`. Résumé : I1 « Total entrées » (gras), J1 `=SOMME(D2:D50)` ; I2 « Total sorties » (gras), J2 `=SOMME(E2:E50)` ; I3 « Résultat » (gras), J3 `=J1-J2` ; J1 à J3 en montant. Largeurs : A 90, B 200, C 110, D/E/F 100, G 110, I 120, J 110.
  - **Suivi des ventes** (`ventes`) : A1 « Date » (date), B1 « Article », C1 « Quantité » (nombre), D1 « Prix unitaire » (montant), E1 « Total » (montant), F1 « Vendeur », G1 « Client », H1 « N° facture ». E2 à E100 `=C{r}*D{r}`. Résumé : J1 « Chiffre d'affaires » / K1 `=SOMME(E2:E100)` (montant) ; J2 « Nombre de ventes » / K2 `=NB(C2:C100)` ; J3 « Vente moyenne » / K3 `=MOYENNE(E2:E100)` (montant) ; J4 « Plus grosse vente » / K4 `=MAX(E2:E100)` (montant). Largeurs : A 90, B 180, C 80, D 100, E 100, F 110, G 140, H 100, J 140, K 110.
  - **Liste clients** (`clients`) : A1 « Nom », B1 « Prénom », C1 « Téléphone », D1 « Adresse », E1 « Dernière visite » (date, lignes 2–200), F1 « Total dépensé » (montant, lignes 2–200), G1 « Notes ». Largeurs : A 120, B 120, C 110, D 180, E 110, F 110, G 260.
  - **Feuille vide** : aucune cellule, largeurs 100.
  La règle « formule sur cellules vides = cellule vide » (PRO-TAB-07) fait que ces formules n'affichent rien tant que les lignes sont vides.
- **Données** : définies dans `shared/sheet_templates.lua` (fichier ouvert, modifiable par le serveur ; chaque cellule : `{ r, c, raw, fmt, bold, bg }`, libellés par clé de langue `tableur.modele.<modele>.<colonne>` traduits à la création dans la langue du serveur).
- **Règles serveur** : modèle tronqué aux limites de taille de l'entreprise.
- **Textes et états** : libellés ci-dessus (clés `tableur.modele.compta.date`, `tableur.modele.compta.libelle`, `tableur.modele.ventes.article`, `tableur.modele.clients.nom` : une clé par en-tête).
- **Notifications** : aucune.
- **Liens** : PRO-TAB-08 (les colonnes d'import correspondent à ces modèles).
- **Réglages** : `shared/sheet_templates.lua` (modèles ajoutables par le serveur : clé, libellé, cellules).
- **Journal admin** : non (inclus dans `sheet_create`).
- **Performance** : modèle chargé une fois au démarrage.
- **Cas limites** :
  - Serveur en anglais → en-têtes « Date, Label, Category, In, Out, Balance, By » et fonctions affichées `SUM`, `AVERAGE` (les deux noms sont acceptés, PRO-TAB-07).
  - Modèle ajouté par le serveur avec une colonne au-delà de Z → cellule ignorée, avertissement console.
  - Limite de lignes < 2 → seule la ligne d'en-têtes est créée.
- **Critères d'acceptation** :
  - Étant donné « Suivi des ventes » créé, quand je tape C2 = 2 et D2 = 15, alors E2 affiche « 30,00 $ » et K1 « 30,00 $ ».
  - Étant donné « Compta mensuelle » vide, alors F2 à F50 et J1 à J3 n'affichent rien.
  - Étant donné un modèle inconnu envoyé par un client modifié, alors une feuille vide est créée.

### [PRO-TAB-04] Ouvrir une feuille et modifier une cellule (types texte, nombre, montant, date)
- **But** : saisir des données dans les cellules.
- **Qui** : lecture : niveau de lecture de la feuille ; modification : niveau de modification.
- **Où** : Tableur > clic sur une feuille.
- **Parcours** :
  1. `sheets:open { sheetId }` → serveur : C3, C4, droit de lecture, renvoie la feuille (nom, largeurs, limites, droits du joueur, import) **et toutes ses cellules non vides en une fois** (au plus `MaxRows × MaxCols` = 5 200 par défaut, compressées en tableau `[r, c, raw, fmt, bold, bg]`) + les verrous en cours (PRO-TAB-10). Le joueur devient spectateur de la feuille (PRO-TAB-11).
  2. Écran : barre d'outils (Format, Gras, Fond, Annuler, Rétablir, Réglages de la feuille), barre de formule (affiche la saisie brute de la cellule sélectionnée, ex. `=SOMME(D2:D50)`), grille avec en-têtes de colonnes A–Z et de lignes 1–N, rendu **virtualisé** (seules les lignes visibles + 10 au-dessus/au-dessous sont dans la page).
  3. Sélection : clic sur une cellule ; flèches ; Maj+clic ou glisser pour un rectangle (max 500 cellules).
  4. Édition (si droit) : double clic, Entrée, F2, ou commencer à taper (remplace le contenu). La NUI demande d'abord le verrou (PRO-TAB-10).
  5. Validation : Entrée (descend d'une ligne), Tab (va à droite), clic ailleurs ; Échap annule et libère le verrou. Envoi `sheets:setCell { sheetId, r, c, raw }`.
  6. Serveur : C3, C4 (`sheets:setCell` 20 / 5 s), droit de modification, verrou détenu par ce joueur, `r`/`c` dans les limites, `raw` nettoyé (C5 sans saut de ligne, 500 car. ; une formule fait au plus 200 car.), mise à jour mémoire de la feuille, écriture via `WriteQueue` (C11), envoi du changement aux spectateurs (PRO-TAB-11), libération du verrou.
  7. Type d'affichage (`fmt`) : en `auto`, la NUI détecte : commence par `=` → formule ; nombre (`-1234,5`, `1 234.5`, `1234`) → nombre ; nombre avec `$` (symbole de la config) devant ou derrière → montant ; `JJ/MM/AAAA` (ou `MM/DD/YYYY` en anglais) valide → date ; sinon texte. Liste « Format » de la barre d'outils : « Auto », « Texte », « Nombre », « Montant », « Date » → `sheets:setFormat { sheetId, range, fmt }` sur la sélection.
  8. Affichage par type (C12) : texte à gauche ; nombre à droite, jusqu'à 6 décimales sans zéros inutiles ; montant à droite, 2 décimales + symbole ; date `JJ/MM/AAAA`. Une saisie qui ne correspond pas au format forcé (ex. « abc » dans une cellule Montant) est gardée et affichée en texte avec un petit triangle d'avertissement et la bulle « Cette valeur n'est pas un montant. ».
- **Données** : table `pop_tablet_sheet_cells` ; une cellule dont `raw = ''`, `bold = 0`, `bg = 0`, `fmt = 'auto'` est supprimée de la table (stockage creux).
- **Règles serveur** : droits revérifiés à chaque écriture ; limites de taille ; nettoyage ; verrou.
- **Textes et états** :
  - Chargement : grille grise ; au-delà de 5 s, C13.
  - Lecture seule : bandeau `tableur.feuille.lecture_seule` « Lecture seule. » ; la barre d'outils est grisée.
  - Format : `tableur.format.auto` « Auto », `tableur.format.texte` « Texte », `tableur.format.nombre` « Nombre », `tableur.format.montant` « Montant », `tableur.format.date` « Date ».
  - Avertissements : `tableur.cellule.pas_nombre` « Cette valeur n'est pas un nombre. », `tableur.cellule.pas_montant` « Cette valeur n'est pas un montant. », `tableur.cellule.pas_date` « Cette valeur n'est pas une date (JJ/MM/AAAA). ».
  - Trop long : la saisie s'arrête à 500 caractères (200 pour une formule) ; message `tableur.erreur.trop_long` « 500 caractères maximum par cellule (200 pour une formule). ».
  - Échec d'enregistrement : la cellule revient à l'ancienne valeur, `tableur.erreur.non_enregistre` « Modification non enregistrée. ».
  - Feuille archivée entre-temps : `tableur.erreur.archivee` « Cette feuille a été archivée. » (retour liste).
- **Notifications** : aucune.
- **Liens** : PRO-TAB-07 (formules), PRO-TAB-10, PRO-TAB-11.
- **Réglages** : `Config.Sheets.MaxCellLength = 500`, `Config.Sheets.MaxFormulaLength = 200`.
- **Journal admin** : non par cellule (trop volumineux) ; `updated_by`/`updated_at` gardés sur chaque cellule (visibles en bulle au survol 1 s : « Modifiée par {nom} le {date} »).
- **Performance** : une seule lecture à l'ouverture (pas de pagination de cellules : 5 200 cellules max ≈ 150 Ko) ; feuille gardée en mémoire serveur tant qu'au moins un spectateur l'a ouverte (+ 5 min) ; écritures groupées ; rendu virtualisé.
- **Cas limites** :
  - Joueur rétrogradé sous le niveau de modification pendant l'édition → `setCell` refusé, bandeau lecture seule affiché.
  - Collage d'un texte de 1 000 caractères → coupé à 500.
  - Cellule hors limites envoyée par un client modifié (r = 5 000) → refus `commun.erreur.serveur`.
  - Coupure du serveur entre deux écritures groupées → au plus 5 s de saisies perdues (accepté, rappelé dans le guide admin).
- **Critères d'acceptation** :
  - Étant donné un Chef, quand il tape « 1250 $ » dans B2, alors B2 affiche « 1 250,00 $ » aligné à droite et la valeur est en base dans les 5 s.
  - Étant donné un Membre (lecture), quand il double-clique une cellule, alors rien ne s'édite et le bandeau lecture seule est visible.
  - Étant donné un client modifié qui envoie `setCell` sans détenir le verrou d'une cellule verrouillée par un autre, alors le serveur refuse.

### [PRO-TAB-05] Gras et couleur de fond
- **But** : mettre en valeur des cellules.
- **Qui** : niveau de modification de la feuille.
- **Où** : Feuille > barre d'outils > bouton « G » (gras, `Ctrl+B`) et bouton « Fond » (palette).
- **Parcours** :
  1. Sélection d'une cellule ou d'un rectangle (≤ 500 cellules).
  2. « G » : si toutes les cellules sélectionnées sont en gras → retire le gras, sinon met tout en gras. `sheets:setStyle { sheetId, range = { r1, c1, r2, c2 }, bold = 0|1 }`.
  3. « Fond » : palette de 9 cases : « Aucun » (0), 1 gris `#3A3A3A`, 2 rouge `#5A2A2A`, 3 orange `#5A422A`, 4 jaune `#55502A`, 5 vert `#2A4A33`, 6 bleu `#2A3A55`, 7 violet `#43305A`, 8 accent (couleur d'accent à 35 % d'opacité). Teintes sombres pour garder le texte blanc lisible. `sheets:setStyle { ..., bg = 0..8 }`.
  4. Serveur : C3, C4 (10 / 5 s), droit, rectangle dans les limites et ≤ 500 cellules, ignore les cellules verrouillées par un autre (renvoie leur liste), met à jour mémoire + `WriteQueue`, envoie aux spectateurs.
- **Données** : `bold`, `bg` dans `pop_tablet_sheet_cells`.
- **Règles serveur** : voir parcours.
- **Textes et états** :
  - Bulles : `tableur.outil.gras` « Gras (Ctrl+B) », `tableur.outil.fond` « Couleur de fond », `tableur.fond.aucun` « Aucun ».
  - Cellules ignorées : `tableur.style.ignorees` « {n} cellule(s) en cours de modification par d'autres n'ont pas été changées. ».
  - Trop de cellules : `tableur.erreur.selection_trop_grande` « 500 cellules maximum. ».
- **Notifications** : aucune.
- **Liens** : PRO-TAB-11.
- **Réglages** : `Config.Sheets.MaxRangeCells = 500`, `Config.Sheets.Palette` (8 couleurs ci-dessus, modifiables).
- **Journal admin** : non.
- **Performance** : une requête par action quelle que soit la taille de la sélection.
- **Cas limites** :
  - Sélection mixte (gras et non gras) → tout passe en gras.
  - Fond sur des cellules vides → les cellules sont créées en base avec `raw = ''`.
  - Fond « Aucun » + pas de gras + vide → la cellule est retirée de la base.
- **Critères d'acceptation** :
  - Étant donné A1:G1 sélectionnées, quand j'appuie sur Ctrl+B, alors les 7 cellules passent en gras chez moi et chez les autres joueurs qui ont la feuille ouverte.
  - Étant donné une cellule verrouillée par un collègue dans la sélection, alors elle garde son style et le message des cellules ignorées s'affiche.
  - Étant donné un client modifié qui envoie `bg = 42`, alors le serveur refuse.

### [PRO-TAB-06] Largeur des colonnes
- **But** : ajuster la largeur d'une colonne à son contenu.
- **Qui** : niveau de modification de la feuille.
- **Où** : Feuille > bord droit d'un en-tête de colonne (curseur ↔).
- **Parcours** :
  1. Glisser le bord → largeur en direct (40 à 400 px).
  2. Au relâchement → `sheets:setWidth { sheetId, c, width }`.
  3. Double clic sur le bord → largeur remise à 100.
  4. Serveur : C3, C4 (10 / 5 s), droit, `c` valide, `width` entier borné 40–400, met à jour `col_widths`, envoie aux spectateurs.
- **Données** : `col_widths` (JSON).
- **Règles serveur** : bornes ; droit.
- **Textes et états** : bulle `tableur.colonne.largeur` « Glisser pour changer la largeur · double clic pour réinitialiser ».
- **Notifications** : aucune.
- **Liens** : PRO-TAB-11.
- **Réglages** : `Config.Sheets.MinColWidth = 40`, `Config.Sheets.MaxColWidth = 400`, `Config.Sheets.DefaultColWidth = 100`.
- **Journal admin** : non.
- **Performance** : une requête au relâchement, jamais pendant le glissement.
- **Cas limites** :
  - Largeur hors bornes envoyée → ramenée dans les bornes.
  - Lecteur sans droit → le curseur ↔ n'apparaît pas.
  - Deux éditeurs changent la même colonne → la dernière valeur reçue par le serveur gagne et est renvoyée à tous.
- **Critères d'acceptation** :
  - Étant donné la colonne B, quand je la glisse à 220 px, alors elle fait 220 px pour tous les spectateurs et après réouverture.
  - Étant donné un double clic sur le bord, alors elle revient à 100 px.
  - Étant donné un Membre (lecture) avec un client modifié qui envoie `setWidth`, alors le serveur refuse.

### [PRO-TAB-07] Formules
- **But** : calculer automatiquement à partir d'autres cellules.
- **Qui** : saisie : niveau de modification ; affichage : tous les lecteurs.
- **Où** : Feuille > cellule dont la saisie commence par `=`.
- **Parcours** :
  1. Le joueur tape `=` : la NUI passe en mode formule (cellule en couleur d'accent, liste des fonctions proposées sous la cellule en tapant les premières lettres). Clic sur une autre cellule pendant la saisie → insère sa référence (`B4`) ; glisser → insère une plage (`B4:B10`).
  2. À la validation, la saisie est enregistrée telle quelle (PRO-TAB-04) ; chaque joueur calcule le résultat avec `formula.js`.
  3. **Syntaxe** :
     - références `A1` à `Z{MaxRows}` (lettres sans casse), plages `A1:C10` (rectangle, ≤ 1 000 cellules) ;
     - nombres `12`, `12,5` ou `12.5` ;
     - opérateurs `+`, `-`, `*`, `/` (et `×`, `÷`, `−` acceptés), `-` devant un nombre ou une référence (négatif), parenthèses `( )` ;
     - priorité : parenthèses, puis signe négatif, puis `*` `/`, puis `+` `-`, de gauche à droite ;
     - fonctions (nom français ou anglais, sans casse) : `SOMME`/`SUM`, `MOYENNE`/`AVERAGE`, `MIN`, `MAX`, `NB`/`COUNT` ; arguments séparés par `;` (et aussi `,` quand la langue du serveur est l'anglais) ; un argument = plage, référence, nombre ou expression ; 1 à 30 arguments ; pas de fonction dans une fonction (ex. `=SOMME(A1;MAX(B1:B3))` → `#ERREUR!`) — mais une fonction peut être dans une expression (`=SOMME(A1:A3)*2`).
  4. **Valeurs des cellules lues** : nombre, montant (valeur numérique), date (nombre de jours depuis le 01/01/1970, pour pouvoir soustraire deux dates), formule (son résultat), texte, vide.
  5. **Règles de calcul** :
     - `SOMME`, `MOYENNE`, `MIN`, `MAX`, `NB` ignorent les cellules vides et le texte ; `NB` compte les cellules qui ont une valeur numérique ;
     - `MOYENNE`, `MIN`, `MAX` sans aucune valeur numérique → résultat vide ;
     - opération `+ - * /` avec une référence vers une cellule vide : la cellule vaut 0, **sauf** si toutes les références de la formule sont vides → résultat vide (la cellule n'affiche rien et est ignorée par les fonctions) ;
     - opération avec une référence vers du texte → `#VALEUR!` ;
     - résultat arrondi à 10 décimales, affiché selon le format de la cellule (en `auto`, montant si au moins une cellule référencée est un montant, sinon nombre).
  6. **Erreurs** (affichées dans la cellule en gris italique, bulle explicative au survol) :
     - `#DIV/0!` : division par zéro ;
     - `#REF!` : référence hors de la feuille (ex. `AA1`, `A9999`) ;
     - `#NOM?` : fonction inconnue ;
     - `#VALEUR!` : texte utilisé dans un calcul ;
     - `#CYCLE!` : la formule dépend d'elle-même (directement ou par d'autres cellules) ; toutes les cellules du cycle affichent `#CYCLE!` ;
     - `#ERREUR!` : syntaxe invalide (parenthèse manquante, opérateur en trop, fonction imbriquée, plage > 1 000 cellules) ;
     - une erreur dans une cellule lue se propage (la formule affiche la même erreur).
  7. **Recalcul** : la NUI tient un graphe de dépendances ; à chaque changement (local ou reçu d'un autre joueur), seules les cellules qui dépendent de la cellule changée sont recalculées.
- **Données** : la formule est dans `raw` (≤ 200 car.) ; le résultat n'est jamais stocké.
- **Règles serveur** : longueur ≤ 200 ; aucune évaluation serveur ; le serveur ne fait aucune confiance à un résultat envoyé par le client (il n'en reçoit pas).
- **Textes et états** :
  - Bulles d'erreur : `tableur.formule.div0` « Division par zéro. », `tableur.formule.ref` « Cette formule vise une cellule qui n'existe pas. », `tableur.formule.nom` « Fonction inconnue. Fonctions possibles : SOMME, MOYENNE, MIN, MAX, NB. », `tableur.formule.valeur` « Une cellule utilisée contient du texte. », `tableur.formule.cycle` « Cette formule dépend d'elle-même. », `tableur.formule.erreur` « Formule incorrecte. Vérifiez les parenthèses et les ; entre les éléments. ».
  - Aide des fonctions (liste sous la cellule) : `tableur.fonction.somme` « SOMME(plage) : additionne », `tableur.fonction.moyenne` « MOYENNE(plage) : moyenne », `tableur.fonction.min` « MIN(plage) : plus petite valeur », `tableur.fonction.max` « MAX(plage) : plus grande valeur », `tableur.fonction.nb` « NB(plage) : compte les nombres ».
- **Notifications** : aucune.
- **Liens** : PRO-TAB-03, PRO-TAB-08.
- **Réglages** : `Config.Sheets.MaxFormulaLength = 200`, `Config.Sheets.MaxRangeInFormula = 1000`.
- **Journal admin** : non.
- **Performance** : calcul côté joueur uniquement ; recalcul partiel par graphe ; aucun `eval`.
- **Cas limites** :
  - `=A1` où A1 contient « bonjour » → affiche « bonjour » : une référence seule vers du texte affiche le texte (seule exception à `#VALEUR!`, car aucun calcul n'est fait).
  - `=SOMME(A1:A3` (parenthèse manquante) → `#ERREUR!`.
  - `=A1+1` dans A1 → `#CYCLE!`.
  - `=somme(b2:b4)` → accepté, la barre de formule l'affiche tel que tapé, le calcul est correct.
- **Critères d'acceptation** :
  - Étant donné B2 = 10, B3 = 20, B4 = « x », quand je tape `=SOMME(B2:B4)`, alors s'affiche 30.
  - Étant donné `=B2/C2` avec C2 = 0, alors s'affiche `#DIV/0!` avec la bulle « Division par zéro. ».
  - Étant donné `=2+3*4`, alors s'affiche 14 ; `=(2+3)*4` affiche 20.
  - Étant donné un client modifié qui envoie une formule de 5 000 caractères, alors le serveur refuse au-delà de 200.

### [PRO-TAB-08] Import automatique (factures payées ou mouvements du compte)
- **But** : remplir une feuille toute seule à chaque facture payée ou mouvement du compte de l'entreprise.
- **Qui** : configurer : `tableur.modifier` **et** (pour la source « compte ») `compte.voir` (défaut Chef). Lire une feuille avec import « compte » : niveau ≥ `compte.voir`.
- **Où** : Feuille > « Réglages de la feuille » (icône engrenage) > section « Remplissage automatique ».
- **Parcours** :
  1. Section : choix « Aucun » / « Factures payées » / « Mouvements du compte » ; case « Importer aussi les 30 derniers jours » ; bouton « Enregistrer ».
  2. `sheets:setImport { sheetId, source, backfill }` → serveur : C3, C4 (2 / 30 s), droits, au plus `Config.Sheets.MaxImportSheetsPerSource = 3` feuilles par source et par entreprise ; si `source = 'compte'`, le niveau de lecture de la feuille est relevé au niveau de `compte.voir` s'il est plus bas (message à l'écran) ; enregistre `import_source`.
  3. Si `backfill` : le serveur lit les factures payées (ou mouvements) des 30 derniers jours de l'entreprise, du plus ancien au plus récent, et les ajoute (étape 5) dans la limite de place.
  4. Ensuite, à chaque événement serveur interne :
     - `pop_tablet:invoicePaid` (émis par Factures, format unique de BASE-API-09 : `company.id`, `number`, `lines`, `amount`, `employee.name`, `payer.name`, `at`) ;
     - `pop_tablet:accountMovement { movementId, companyId, type, label, amountIn, amountOut, byName, at }` (émis par le compte d'entreprise) ;
     le serveur ajoute une ligne à chaque feuille liée de cette entreprise.
  5. **Ligne ajoutée** = première ligne après la dernière ligne dont la colonne A n'est pas vide (en ignorant la ligne 1), colonnes :
     - Factures : A date de paiement (date), B libellé de la facture, C `1` (nombre), D montant (montant), E `=C{r}*D{r}` **seulement si E est vide**, F employé, G client (nom RP), H numéro de facture ;
     - Compte : A date (date), B libellé, C catégorie (`Dépôt`, `Retrait`, `Facture`, `Salaire`, `Virement`, `Autre`), D entrée (montant ou vide), E sortie (montant ou vide), F **non touchée** (formule de solde du modèle), G par (nom).
     Ces colonnes correspondent aux modèles « Suivi des ventes » et « Compta mensuelle ».
  6. Écritures groupées (`WriteQueue`), envoi aux spectateurs comme une modification normale (`updated_by = 'import'`, affiché « Import automatique »).
  7. Une même facture / un même mouvement n'est jamais ajouté deux fois dans la même feuille : table `pop_tablet_sheet_imports (sheet_id, source, source_id)` avec clé unique.
  8. Feuille pleine (ligne cible > `MaxRows`) → `import_paused = 1`, plus aucun ajout, notification unique aux employés avec `tableur.modifier` en service ; la pastille « Pleine » s'affiche. Repasser l'import à « Aucun » puis le réactiver sur une nouvelle feuille relance l'import.
- **Données** : `import_source`, `import_paused` ; table `pop_tablet_sheet_imports` (`sheet_id` INT, `source` VARCHAR(10), `source_id` VARCHAR(40), `created_at`).
- **Règles serveur** : n'ajoute que les événements de **la même entreprise** ; ne modifie jamais une cellule non vide (sauf aucune) ; ignore les cellules verrouillées en ajoutant à la ligne suivante libre ; feuille archivée → plus d'import.
- **Textes et états** :
  - `tableur.import.titre` « Remplissage automatique », options `tableur.import.aucun` « Aucun », `tableur.import.factures` « Factures payées », `tableur.import.compte` « Mouvements du compte », case `tableur.import.retro` « Importer aussi les 30 derniers jours ».
  - Succès : `tableur.import.active` « Remplissage automatique activé. », `tableur.import.desactive` « Remplissage automatique désactivé. », `tableur.import.retro_fait` « {n} ligne(s) importée(s). ».
  - Niveau relevé : `tableur.import.niveau_releve` « Les mouvements du compte sont confidentiels : cette feuille est maintenant réservée au grade {grade} et plus. ».
  - Limite : `tableur.import.limite` « {max} feuilles reçoivent déjà cet import. ».
  - Pleine (bandeau dans la feuille) : `tableur.import.pleine` « Feuille pleine. Import automatique en pause. ».
  - Bulle de cellule : `tableur.import.auteur` « Import automatique ».
- **Notifications** : feuille pleine → employés avec `tableur.modifier`, en service, avec tablette : titre `tableur.notif.pleine` « Tableur : la feuille « {nom} » est pleine », texte `tableur.notif.pleine_texte` « L'import automatique est en pause. », action = ouvrir la feuille.
- **Liens** : Factures (signal `pop_tablet:invoicePaid`), Compte entreprise (signal `pop_tablet:accountMovement`). Aucun signal émis.
- **Réglages** : `Config.Sheets.MaxImportSheetsPerSource = 3`, `Config.Sheets.BackfillDays = 30`.
- **Journal admin** : oui, `sheet_import_set` (qui, feuille, source, avant/après) et `sheet_import_paused`.
- **Performance** : rien ne tourne en attente ; l'ajout se fait sur l'événement ; index mémoire `ImportTargets[companyId][source] = { sheetIds }` construit au démarrage et mis à jour à chaque réglage ; écritures groupées.
- **Cas limites** :
  - Facture payée alors que la feuille n'est ouverte par personne → la feuille est chargée en mémoire juste pour l'ajout puis libérée 5 min après.
  - 50 factures payées en même temps (paie de masse) → toutes ajoutées en un seul paquet d'écriture.
  - Événement reçu deux fois (rejoué) → ignoré grâce à la clé unique.
  - Ligne visée contient une cellule verrouillée par un joueur → l'import prend la ligne libre suivante.
- **Critères d'acceptation** :
  - Étant donné une feuille « Suivi des ventes » avec import « Factures payées », quand un client paie une facture de 500 $, alors une ligne avec la date, le libellé, 1, 500,00 $ et le total apparaît en moins de 6 s chez les spectateurs.
  - Étant donné une feuille de 200 lignes pleine, quand une facture est payée, alors rien n'est ajouté, la pastille « Pleine » s'affiche et une notification part une seule fois.
  - Étant donné un Membre avec un client modifié qui active l'import « compte », alors le serveur refuse avec `commun.erreur.pas_droit`.
  - Étant donné une facture payée d'une autre entreprise, alors elle n'apparaît dans aucune feuille de mon entreprise.

### [PRO-TAB-09] Droits de lecture et de modification par grade
- **But** : choisir qui peut lire ou modifier chaque feuille.
- **Qui** : `grades.gerer` (défaut Patron) et admin.
- **Où** : Feuille > « Réglages de la feuille » > section « Accès ».
- **Parcours** :
  1. Section : « Peut lire : » liste (Par défaut de l'entreprise ({niveau}) / Recrue et plus / Membre et plus / Chef et plus / Patron seulement) ; « Peut modifier : » même liste. Chaque niveau affiche entre parenthèses les grades ESX correspondants de l'entreprise (ex. « Chef et plus (Chef d'atelier, Patron) »).
  2. `sheets:setAccess { sheetId, readLevel, editLevel }` → serveur : C3, C4 (3 / 30 s), droit `grades.gerer`, `editLevel ≥ readLevel` (sinon `editLevel` est relevé), feuille avec import « compte » → `readLevel ≥ niveau compte.voir`.
  3. Les spectateurs qui perdent la lecture reçoivent `pop_tablet:sheets:kicked` (retour liste avec message) ; ceux qui perdent la modification passent en lecture seule.
- **Données** : `read_level`, `edit_level` (NULL = valeur par défaut de l'entreprise, qui suit les changements de la grille de droits).
- **Règles serveur** : voir parcours ; le créateur de la feuille n'a pas de droit spécial.
- **Textes et états** :
  - `tableur.acces.titre` « Accès », `tableur.acces.lire` « Peut lire », `tableur.acces.modifier` « Peut modifier », options `tableur.acces.defaut` « Par défaut de l'entreprise ({niveau}) », `tableur.acces.recrue` « Recrue et plus », `tableur.acces.membre` « Membre et plus », `tableur.acces.chef` « Chef et plus », `tableur.acces.patron` « Patron seulement ».
  - Succès : `tableur.acces.enregistre` « Accès enregistrés. ».
  - Expulsé : `tableur.acces.retire` « Accès à cette feuille retiré. ».
  - Pas le droit : section visible mais grisée avec `commun.droit.grade_requis`.
- **Notifications** : aucune (hors expulsion à l'écran).
- **Liens** : Entreprises (grille de droits, grades).
- **Réglages** : aucun propre.
- **Journal admin** : oui, `sheet_access` (qui, feuille, avant/après).
- **Performance** : vérification en mémoire.
- **Cas limites** :
  - Patron qui se retire la modification (Patron seulement reste toujours au Patron) → impossible de se bloquer : le niveau Patron a toujours lecture et modification.
  - Grille de droits de l'entreprise modifiée → les feuilles « par défaut » suivent immédiatement.
  - `editLevel` < `readLevel` envoyé → relevé automatiquement à `readLevel`.
- **Critères d'acceptation** :
  - Étant donné une feuille passée à « Patron seulement » en lecture, quand un Chef l'a ouverte, alors il est renvoyé à la liste avec « Accès à cette feuille retiré. ».
  - Étant donné « Peut modifier : Membre et plus », quand un Membre ouvre la feuille, alors il peut éditer.
  - Étant donné un Chef avec un client modifié qui appelle `setAccess`, alors le serveur refuse.

### [PRO-TAB-10] Verrou de cellule en cours d'édition
- **But** : éviter que deux personnes modifient la même cellule en même temps.
- **Qui** : tout éditeur.
- **Où** : Feuille > passage en mode édition d'une cellule.
- **Parcours** :
  1. Entrée en édition → `sheets:lock { sheetId, r, c }` → serveur : C4 (20 / 5 s), droit de modification, cellule libre ou déjà à ce joueur ; enregistre en mémoire `Locks[sheetId][r..':'..c] = { identifier, name, expires = maintenant + 60 s }` ; un joueur a **un seul** verrou à la fois (prendre un nouveau verrou libère l'ancien) ; envoie `lock` aux spectateurs.
  2. Si refusé (cellule à un autre) → la NUI n'entre pas en édition et affiche le message.
  3. Pendant l'édition, la NUI renouvelle le verrou toutes les 30 s (`sheets:lock` à nouveau, minuterie active seulement pendant l'édition).
  4. Libération : validation (`setCell` libère), Échap (`sheets:unlock`), changement de cellule, fermeture de la feuille ou de la tablette, déconnexion (`playerDropped`), ou expiration à 60 s sans renouvellement (vérifiée à la demande : un verrou expiré est considéré libre ; un `SetTimeout` unique par verrou envoie `unlock` aux spectateurs à l'expiration).
  5. Chez les autres : la cellule verrouillée a un cadre de 2 px de couleur d'accent et une étiquette avec `Prénom N.` au-dessus ; elle ne peut pas être éditée ni restylée.
- **Données** : verrous en mémoire uniquement.
- **Règles serveur** : `setCell`, `setStyle`, `setFormat` sur une cellule verrouillée par un autre → refusé/ignoré ; un admin peut forcer : clic droit sur la cellule > « Forcer le déverrouillage » (journalisé).
- **Textes et états** :
  - Refus : `tableur.verrou.occupe` « Cette cellule est en cours de modification par {nom}. ».
  - Étiquette : `tableur.verrou.etiquette` « {nom} ».
  - Admin : `tableur.verrou.forcer` « Forcer le déverrouillage ».
- **Notifications** : aucune.
- **Liens** : PRO-TAB-11.
- **Réglages** : `Config.Sheets.LockTtlSec = 60`, `Config.Sheets.LockRenewSec = 30`.
- **Journal admin** : oui seulement pour le déverrouillage forcé (`sheet_lock_forced`).
- **Performance** : table mémoire ; aucun thread permanent ; une minuterie par verrou actif.
- **Cas limites** :
  - Joueur qui crashe en pleine édition → verrou libéré par `playerDropped`.
  - Joueur qui reste 10 min en édition sans taper → le renouvellement continue tant que la cellule est en édition ; au bout de `Config.Sheets.LockMaxSec = 300` s d'édition sans frappe, la NUI annule l'édition et libère le verrou.
  - Deux demandes de verrou à la même milliseconde → le serveur (mono-thread) attribue au premier traité ; le second reçoit le refus.
- **Critères d'acceptation** :
  - Étant donné Alice en édition sur B3, quand Bob double-clique B3, alors il voit « Cette cellule est en cours de modification par Alice D. ».
  - Étant donné Alice qui valide B3, alors le cadre disparaît chez Bob et il peut l'éditer.
  - Étant donné un client modifié de Bob qui envoie `setCell` sur B3 pendant le verrou d'Alice, alors le serveur refuse.

### [PRO-TAB-11] Modifications visibles en direct par les autres (ajout)
- **But** : que plusieurs employés voient les changements des autres sans recharger.
- **Qui** : tous les spectateurs d'une feuille (lecteurs et éditeurs).
- **Où** : Feuille ouverte.
- **Parcours** :
  1. À `sheets:open`, le serveur ajoute le joueur à `Viewers[sheetId]` ; il l'en retire à `sheets:close` (fermeture de la feuille, retour liste, fermeture de la tablette) et à la déconnexion.
  2. Chaque changement accepté (cellule, style, format, largeur, verrou, import, accès) est envoyé à `Viewers[sheetId]` sauf l'auteur, par `pop_tablet:sheets:update { sheetId, kind, payload }`. Les changements d'un même auteur dans la même seconde sont regroupés en un envoi.
  3. En haut à droite de la feuille : pastilles rondes avec les initiales des autres spectateurs (5 max + « +{n} »), bulle avec les noms.
- **Données** : `Viewers` en mémoire.
- **Règles serveur** : un spectateur doit avoir le droit de lecture au moment de l'envoi (sinon il est retiré, PRO-TAB-09).
- **Textes et états** : bulle `tableur.spectateurs.liste` « Aussi sur cette feuille : {noms} ».
- **Notifications** : aucune.
- **Liens** : PRO-TAB-04 à 10.
- **Réglages** : `Config.Sheets.BroadcastBatchMs = 1000`.
- **Journal admin** : non.
- **Performance** : envoi aux seuls spectateurs ; regroupement par seconde ; feuille libérée de la mémoire serveur 5 min après le départ du dernier spectateur (après écriture de la file).
- **Cas limites** :
  - Spectateur qui ferme la tablette sans quitter la feuille → la fermeture de la tablette envoie `sheets:close`.
  - Paquet perdu (rare) → bouton « Recharger » dans le menu de la feuille ; à la réouverture, la feuille est relue entièrement.
  - 15 spectateurs → pastilles « 5 + {10} ».
- **Critères d'acceptation** :
  - Étant donné Alice et Bob sur la même feuille, quand Alice modifie C4, alors Bob voit la nouvelle valeur (et les formules dépendantes recalculées) en moins de 2 s.
  - Étant donné Bob qui ferme sa tablette, alors il ne reçoit plus aucune mise à jour.
  - Étant donné un client modifié qui s'inscrit comme spectateur d'une feuille sans droit de lecture, alors le serveur refuse.

### [PRO-TAB-12] Taille maximale réglable
- **But** : protéger la base et la mémoire du serveur.
- **Qui** : admin serveur (config) ; l'admin en jeu peut voir les valeurs dans le panneau Admin (branche Admin).
- **Où** : `config.lua` > `Config.Sheets` ; affichage dans Réglages de la feuille (« Taille : {lignes} lignes × {colonnes} colonnes »).
- **Parcours** :
  1. Au démarrage, le serveur lit les limites, les borne aux plafonds durs (lignes ≤ 1 000, colonnes ≤ 26, feuilles ≤ 100) et écrit un avertissement console si une valeur est ramenée.
  2. La taille effective d'une entreprise = `Config.Sheets.PerCompany[job]` sinon valeurs générales.
  3. La grille affiche exactement `MaxRows` lignes et `MaxCols` colonnes ; aucune saisie possible au-delà (le serveur refuse).
  4. Baisse des limites après coup : les cellules au-delà restent en base mais ne sont ni envoyées ni affichées ; les formules qui les visent affichent `#REF!` ; si la limite remonte, elles réapparaissent.
- **Données** : config.
- **Règles serveur** : toute écriture hors limites refusée ; feuilles au-delà du nombre max (après baisse) restent lisibles, création bloquée.
- **Textes et états** :
  - `tableur.reglages.taille` « Taille : {lignes} lignes × {colonnes} colonnes ».
  - Hors limites : `commun.erreur.serveur`.
- **Notifications** : aucune.
- **Liens** : PRO-TAB-08 (feuille pleine).
- **Réglages** : `Config.Sheets.MaxRows = 200`, `Config.Sheets.MaxCols = 26`, `Config.Sheets.MaxSheetsPerCompany = 20`, `Config.Sheets.PerCompany = {}`.
- **Journal admin** : non.
- **Performance** : la limite garantit au plus 5 200 cellules par feuille par défaut (≤ 26 000 au plafond dur) envoyées à l'ouverture.
- **Cas limites** :
  - `MaxCols = 40` dans la config → ramené à 26 avec avertissement.
  - `MaxRows = 0` → ramené à 10 (minimum).
  - Entreprise surchargée à 500 lignes → seules ses feuilles ont 500 lignes.
- **Critères d'acceptation** :
  - Étant donné `MaxRows = 100`, quand j'ouvre une feuille, alors la grille s'arrête à la ligne 100.
  - Étant donné la limite baissée de 200 à 100 avec des données en ligne 150, alors elles ne s'affichent plus et `=SOMME(A1:A200)` affiche `#REF!`.
  - Étant donné un client modifié qui écrit en ligne 150 avec `MaxRows = 100`, alors le serveur refuse.

### [PRO-TAB-13] Annuler / rétablir (ajout)
- **But** : revenir sur une erreur de saisie.
- **Qui** : éditeur de la feuille.
- **Où** : Feuille > boutons « Annuler » (`Ctrl+Z`) et « Rétablir » (`Ctrl+Y`) de la barre d'outils.
- **Parcours** :
  1. La NUI garde les 20 dernières modifications **du joueur** sur cette feuille pendant qu'elle est ouverte (cellule, style, format, largeur) avec la valeur avant/après.
  2. Annuler → renvoie l'ancienne valeur par l'appel normal (`setCell`, `setStyle`…), donc avec verrou et droits. Rétablir → renvoie la nouvelle valeur.
  3. Si la cellule a été modifiée entre-temps par quelqu'un d'autre, l'annulation est refusée par la NUI (la valeur actuelle ≠ la valeur « après » mémorisée).
- **Données** : pile locale, effacée à la fermeture de la feuille.
- **Règles serveur** : celles de chaque appel.
- **Textes et états** :
  - Bulles `tableur.outil.annuler` « Annuler (Ctrl+Z) », `tableur.outil.retablir` « Rétablir (Ctrl+Y) ».
  - Conflit : `tableur.annuler.conflit` « Impossible d'annuler : {nom} a modifié cette cellule depuis. ».
  - Boutons grisés quand la pile est vide.
- **Notifications** : aucune.
- **Liens** : PRO-TAB-04 à 06.
- **Réglages** : `Config.Sheets.UndoSteps = 20`.
- **Journal admin** : non.
- **Performance** : local.
- **Cas limites** :
  - Lignes ajoutées par l'import automatique → ne sont pas dans la pile (pas faites par le joueur).
  - Annuler pendant que la cellule est verrouillée par un autre → refus verrou (PRO-TAB-10).
  - Joueur passé en lecture seule → boutons grisés.
- **Critères d'acceptation** :
  - Étant donné B2 changé de 10 à 50, quand j'appuie sur Ctrl+Z, alors B2 revient à 10 pour tous les spectateurs.
  - Étant donné B2 modifié ensuite par Bob, quand j'annule, alors le message de conflit s'affiche.
  - Étant donné une feuille fermée puis rouverte, alors « Annuler » est grisé.

### [PRO-TAB-14] Renommer, dupliquer, archiver et restaurer une feuille (ajout)
- **But** : gérer les feuilles sans jamais perdre de données comptables.
- **Qui** : renommer / dupliquer : niveau de modification de la feuille ; archiver : `tableur.modifier` ; restaurer et voir les archives : Patron (`grades.gerer`) et admin.
- **Où** : Tableur > liste > menu « ⋯ » d'une feuille ; onglet « Archivées ».
- **Parcours** :
  1. « Renommer » → fenêtre nom (40 car., unique) → `sheets:rename`.
  2. « Dupliquer » → crée « {nom} (copie) » avec toutes les cellules, largeurs et accès, **sans** l'import → `sheets:duplicate { sheetId, actionId }` (compte dans la limite de feuilles).
  3. « Archiver » → confirmation « Archiver « {nom} » ? Elle disparaîtra de la liste. Le patron pourra la restaurer. » → `sheets:archive` → `archived_at`, `archived_by`, import coupé, spectateurs renvoyés à la liste.
  4. Onglet « Archivées » : liste (nom, archivée le, par) en lecture seule (ouverture possible en lecture), bouton « Restaurer » → `sheets:restore` (vérifie limite de feuilles et unicité du nom, sinon ajoute « (restaurée) »).
  5. Aucune suppression définitive par les joueurs ; l'admin peut supprimer définitivement depuis la branche Admin (journalisé).
- **Données** : `name`, `archived_at`, `archived_by`.
- **Règles serveur** : droits, limites, unicité.
- **Textes et états** :
  - Menu : `tableur.menu.renommer` « Renommer », `tableur.menu.dupliquer` « Dupliquer », `tableur.menu.archiver` « Archiver », `tableur.menu.restaurer` « Restaurer ».
  - Confirmation : `tableur.archiver.confirmer` « Archiver « {nom} » ? Elle disparaîtra de la liste. Le patron pourra la restaurer. ».
  - Succès : `tableur.succes.renommee` « Feuille renommée. », `tableur.succes.dupliquee` « Feuille dupliquée. », `tableur.succes.archivee` « Feuille archivée. », `tableur.succes.restauree` « Feuille restaurée. ».
  - Archives vides : `tableur.archives.vide` « Aucune feuille archivée. ».
  - Suffixes : `tableur.nom.copie` « {nom} (copie) », `tableur.nom.restauree` « {nom} (restaurée) ».
- **Notifications** : aucune.
- **Liens** : PRO-TAB-08 (import coupé à l'archivage).
- **Réglages** : aucun propre.
- **Journal admin** : oui pour `sheet_rename`, `sheet_duplicate`, `sheet_archive`, `sheet_restore`, `sheet_delete_admin` (qui, feuille, avant/après).
- **Performance** : duplication en une requête `INSERT ... SELECT`.
- **Cas limites** :
  - Archivage pendant qu'un collègue édite → son verrou est libéré, il est renvoyé à la liste avec `tableur.erreur.archivee`.
  - Restauration avec 20 feuilles actives → `tableur.erreur.limite_feuilles`.
  - Duplication d'une feuille avec import compte → la copie garde le niveau de lecture relevé mais pas l'import.
- **Critères d'acceptation** :
  - Étant donné une feuille archivée, quand le patron ouvre « Archivées », alors il la voit et peut la restaurer avec toutes ses cellules.
  - Étant donné un Chef, alors il ne voit pas l'onglet « Archivées ».
  - Étant donné un client modifié qui envoie `sheets:delete`, alors le serveur ne connaît pas cette action pour un joueur et refuse.

---

### [PRO-TAB-15] Insérer et supprimer des lignes ou des colonnes (ajout relecture)
- **But** : réorganiser une feuille sans tout ressaisir, comme dans un vrai tableur.
- **Qui** : niveau de modification de la feuille (`tableur.modifier`, Chef par défaut).
- **Où** : Feuille > clic droit sur un en-tête de ligne (1, 2, 3…) ou de colonne (A, B, C…) > « Insérer une ligne au-dessus », « Insérer une ligne en dessous », « Supprimer la ligne » (et l'équivalent « colonne à gauche / à droite / Supprimer la colonne »).
- **Parcours** :
  1. Clic sur l'action → pour une suppression, confirmation « Supprimer la ligne {n} ? Son contenu sera perdu. » (Annuler / Supprimer).
  2. `sheets:insert { sheetId, axis = 'row'|'col', index, position = 'before'|'after', actionId }` ou `sheets:remove { sheetId, axis, index, actionId }`.
  3. Serveur : C3, C4 (3 / 10 s), droit de modification ; refuse si une cellule de la feuille est verrouillée par un autre éditeur (PRO-TAB-10) ; insertion refusée si la dernière ligne (ou colonne) de la feuille n'est pas vide (la feuille ne grandit pas au-delà de `MaxRows` / `MaxCols`).
  4. Serveur, en une transaction : décale `r` (ou `c`) de +1 ou −1 pour toutes les cellules au-delà de l'index ; supprime les cellules de la ligne/colonne supprimée ; réécrit chaque formule de la feuille avec le module de lecture des formules (même grammaire que `html/js/formula.js`, porté côté serveur dans `server/formula_refs.lua`) : une référence ou une plage après l'index est décalée ; une plage qui contient l'index s'agrandit (insertion) ou se réduit (suppression) ; une référence vers une cellule supprimée devient `#REF!` et la formule affiche « #REF! ».
  5. Le serveur envoie la feuille entière mise à jour aux spectateurs (PRO-TAB-11) ; la pile Annuler/Rétablir de chaque joueur sur cette feuille est vidée (PRO-TAB-13).
  6. Feuille avec import automatique (PRO-TAB-08) : l'import continue d'écrire sous la dernière ligne non vide.
- **Données** : `pop_tablet_sheet_cells` (`r`, `c`, `raw` des formules réécrites), `pop_tablet_sheets.col_widths` (décalé pour une colonne).
- **Règles serveur** : droits ; verrous ; limites de taille ; une seule opération de structure à la fois par feuille (verrou mémoire de la feuille, les autres reçoivent « Réessayez dans un instant. ») ; écriture immédiate (pas de file groupée).
- **Textes et états** :
  - Menu : `tableur.structure.inserer_ligne_avant` « Insérer une ligne au-dessus », `tableur.structure.inserer_ligne_apres` « Insérer une ligne en dessous », `tableur.structure.supprimer_ligne` « Supprimer la ligne », `tableur.structure.inserer_col_avant` « Insérer une colonne à gauche », `tableur.structure.inserer_col_apres` « Insérer une colonne à droite », `tableur.structure.supprimer_col` « Supprimer la colonne ».
  - Confirmation : `tableur.structure.confirmer_ligne` « Supprimer la ligne {n} ? Son contenu sera perdu. », `tableur.structure.confirmer_col` « Supprimer la colonne {lettre} ? Son contenu sera perdu. ».
  - Erreurs : `tableur.structure.pleine` « Feuille pleine. Videz la dernière ligne (ou colonne) avant d'insérer. », `tableur.structure.verrou` « {nom} modifie cette cellule. Réessayez dans un instant. ».
  - Succès : pas de bandeau (la grille se met à jour).
- **Notifications** : aucune.
- **Liens** : PRO-TAB-04, PRO-TAB-07, PRO-TAB-10, PRO-TAB-11, PRO-TAB-13.
- **Réglages** : aucun propre (limites de PRO-TAB-12).
- **Journal admin** : oui, `sheet_structure` (feuille, axe, index, insertion/suppression).
- **Performance** : une transaction ; au plus `MaxRows × MaxCols` cellules relues en mémoire (la feuille est déjà en cache si elle est ouverte).
- **Cas limites** :
  - `=SOMME(B2:B10)` et insertion d'une ligne au-dessus de 5 → devient `=SOMME(B2:B11)`.
  - Suppression de la ligne 3 avec `=B3*2` en C5 → C4 contient `=#REF!*2` et affiche « #REF! ».
  - Deux Chefs insèrent en même temps → le second reçoit le message de verrou.
- **Critères d'acceptation** :
  - Étant donné `=SOMME(D2:D50)` en D51, quand j'insère une ligne au-dessus de la ligne 10, alors la formule est en D52 et vaut `=SOMME(D2:D51)`.
  - Étant donné une feuille de 200 lignes dont la ligne 200 est remplie, quand j'insère une ligne, alors je vois « La feuille est pleine… » et rien ne bouge.
  - Étant donné un Membre (lecture) qui envoie `sheets:remove` à la main, alors le serveur refuse `pas_droit`.

---

## 8. Stock (Gestion pro)

Tables communes :

`pop_tablet_stock_items`

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `id` | INT auto | oui | — | — |
| `company_id` | INT, index | oui | — | — |
| `name` | VARCHAR(40) | oui | 1–40 car., unique dans l'entreprise (non archivés) | — |
| `ref` | VARCHAR(20) | non | référence libre (ex. « PNEU-01 ») | NULL |
| `image` | VARCHAR(300) | non | C6 (`media:<id>` ou URL autorisée) | NULL |
| `price` | DECIMAL(10,2) | oui | 0 – `Config.Stock.MaxPrice` (1 000 000) | 0 |
| `quantity` | INT | oui | 0 – `Config.Stock.MaxQuantity` (999 999), jamais négatif | 0 |
| `threshold` | INT | oui | 0 – 99 999 ; 0 = pas d'alerte | 0 |
| `low_alerted` | TINYINT(1) | oui | 1 = alerte déjà envoyée pour ce passage sous le seuil | 0 |
| `auto_invoice` | TINYINT(1) | oui | 1 = déduit à chaque facture payée qui contient l'article | 0 |
| `inv_item` | VARCHAR(50) | non | nom d'objet de l'inventaire (lien coffre) | NULL |
| `stash_id` | VARCHAR(60) | non | identifiant du coffre (lien coffre) | NULL |
| `created_at`, `updated_at` | DATETIME | oui | — | maintenant |
| `archived_at` / `archived_by` | DATETIME / VARCHAR(60) | non | — | NULL |

`pop_tablet_stock_moves` (jamais modifiée ni supprimée)

| Champ | Type | Obligatoire | Limites | Défaut |
|---|---|---|---|---|
| `id` | BIGINT auto | oui | — | — |
| `item_id` | INT, index | oui | — | — |
| `company_id` | INT, index | oui | — | — |
| `type` | ENUM('entree','sortie','ajustement','facture','coffre_entree','coffre_sortie','creation') | oui | — | — |
| `delta` | INT | oui | ≠ 0 sauf `creation` | — |
| `qty_after` | INT | oui | ≥ 0 | — |
| `reason` | VARCHAR(100) | non | texte nettoyé | `''` |
| `invoice_id` | VARCHAR(40) | non | pour `facture`, clé unique (`invoice_id`, `item_id`) | NULL |
| `by_identifier` / `by_name` | VARCHAR(60) / VARCHAR(60) | oui | `system` pour les automatismes | — |
| `created_at` | DATETIME | oui | — | maintenant |

Limite `Config.Stock.MaxItemsPerCompany = 200`. Toute modification de quantité se fait par une requête atomique : `UPDATE pop_tablet_stock_items SET quantity = quantity + ? WHERE id = ? AND company_id = ? AND quantity + ? >= 0 AND quantity + ? <= ?` puis lecture de `qty_after` dans la même transaction, puis `INSERT` du mouvement.

### [PRO-STO-01] Liste des articles
- **But** : voir le stock de l'entreprise d'un coup d'œil.
- **Qui** : `stock.lire` (défaut Membre).
- **Où** : Accueil > branche Entreprises > Gestion pro > « Stock ».
- **Parcours** :
  1. Ouverture → `pop_tablet:stock:list { companyId, q = '', filter = 'tous', page = 1 }` (C16).
  2. Serveur : C3, C4, C7/C8, C15, renvoie 20 articles non archivés (image, nom, réf., prix, quantité, seuil, pastilles), tri : articles en stock bas d'abord, puis nom ; + compteur d'articles en stock bas ; quantités des articles liés à un coffre lues par PRO-STO-10.
  3. Écran : champ « Rechercher un article » (nom ou réf., 300 ms après frappe), filtres « Tous » / « Stock bas » / « Liés au coffre », bouton « + Nouvel article » (si `stock.modifier`), liste en lignes : vignette 40 px (icône carton si pas d'image), nom + réf. en gris, prix, quantité en grand ; pastille « Stock bas » (texte en couleur d'accent sur fond accent 20 %) si `threshold > 0` et `quantity ≤ threshold` ; pastille « Rupture » si `quantity = 0` ; icône coffre si lié.
  4. Clic sur une ligne → fiche de l'article : infos, boutons « Entrée » (PRO-STO-04), « Sortie » (PRO-STO-05), « Corriger le stock » (PRO-STO-06), « Modifier » (PRO-STO-02), « Historique » (PRO-STO-07), « Archiver » (PRO-STO-03) — chacun visible selon le droit.
  5. Pastille sur l'icône de l'app Stock = nombre d'articles en stock bas (pour qui a `stock.lire`), calculée à l'ouverture de la tablette.
- **Données** : affichage seul.
- **Règles serveur** : membre de l'entreprise, droit de lecture.
- **Textes et états** :
  - Vide : `stock.liste.vide` « Aucun article en stock. » + bouton `stock.liste.creer` « Ajouter un article » (si droit ; sinon `stock.liste.vide_lecture` « Aucun article pour l'instant. »).
  - `stock.recherche.placeholder` « Rechercher un article », filtres `stock.filtre.tous` « Tous », `stock.filtre.bas` « Stock bas », `stock.filtre.coffre` « Liés au coffre ».
  - Pastilles : `stock.pastille.bas` « Stock bas », `stock.pastille.rupture` « Rupture ».
  - Filtre sans résultat : `stock.liste.vide_filtre` « Aucun article ne correspond. ».
  - Pas le droit : icône grisée avec `commun.droit.grade_requis`.
- **Notifications** : aucune.
- **Liens** : PRO-STO-09 (pastille), PRO-STO-10.
- **Réglages** : `Config.Stock.PageSize = 20`, `Config.Stock.MaxItemsPerCompany = 200`.
- **Journal admin** : non.
- **Performance** : liste paginée ; images à la demande (OUT-GAL-02) ; quantités de coffre mises en cache 10 s.
- **Cas limites** :
  - Article lié à un coffre supprimé → quantité affichée « — » avec la bulle `stock.coffre.introuvable` « Coffre introuvable ».
  - 0 article en stock bas → filtre « Stock bas » affiche le message vide.
  - Joueur viré pendant l'affichage → appel suivant refusé, retour accueil.
- **Critères d'acceptation** :
  - Étant donné un article à 2 avec un seuil de 5, quand j'ouvre le Stock, alors il est en tête avec « Stock bas ».
  - Étant donné une Recrue (défaut), alors l'icône Stock est grisée.
  - Étant donné un client modifié qui demande le stock d'une autre entreprise, alors le serveur refuse.

### [PRO-STO-02] Créer ou modifier un article
- **But** : ajouter un article au stock ou changer ses infos.
- **Qui** : `stock.modifier` (défaut Chef).
- **Où** : Stock > « + Nouvel article » ; fiche d'un article > « Modifier ».
- **Parcours** :
  1. Formulaire : « Nom » (40), « Référence (facultatif) » (20), « Image » (bouton « Choisir dans ma galerie » → sélecteur OUT-GAL-06 sens inverse, ou champ « Lien de l'image »), « Prix unitaire » (nombre ≥ 0, 2 décimales), « Quantité de départ » (création seulement, entier ≥ 0 ; caché si lié à un coffre), « Alerte quand il reste » (entier, 0 = jamais), case « Retirer du stock à chaque facture payée » (visible si `Config.Stock.InvoiceLink = true`), section « Coffre » (PRO-STO-10, visible si inventaire compatible).
  2. `stock:save { companyId, id = nil|id, name, ref, image, price, quantity, threshold, autoInvoice, invItem, stashId, actionId }`.
  3. Serveur : C3, C4 (5 / 10 s), C7, C10, C5 sur les textes, C6 sur l'image, bornes numériques (entiers pour quantité et seuil, prix arrondi à 2 décimales), nom unique, limite d'articles (création), validation du lien coffre (PRO-STO-10).
  4. Création : `INSERT` + mouvement `creation` (`delta` = quantité de départ, raison « Création de l'article ») ; modification : `UPDATE` des champs (la quantité n'est **jamais** modifiée par ce formulaire : elle change seulement par mouvements).
  5. Si le seuil change, `low_alerted` est recalculé (`quantity ≤ threshold` → 1 sans notification, sinon 0).
  6. Bandeau succès, retour à la fiche.
- **Données** : voir table.
- **Règles serveur** : voir parcours.
- **Textes et états** :
  - Champs : `stock.form.nom` « Nom », `stock.form.ref` « Référence (facultatif) », `stock.form.image` « Image », `stock.form.galerie` « Choisir dans ma galerie », `stock.form.lien` « Lien de l'image », `stock.form.prix` « Prix unitaire », `stock.form.quantite` « Quantité de départ », `stock.form.seuil` « Alerte quand il reste », aide `stock.form.seuil_aide` « 0 = pas d'alerte », `stock.form.auto_facture` « Retirer du stock à chaque facture payée ».
  - Succès : `stock.succes.cree` « Article ajouté. », `stock.succes.modifie` « Article modifié. ».
  - Erreurs : `stock.erreur.nom_vide` « Nom de l'article requis. », `stock.erreur.nom_existe` « Un article porte déjà ce nom. », `stock.erreur.limite` « Limite de {max} articles atteinte. », `stock.erreur.prix` « Le prix doit être entre 0 et {max} $. », `stock.erreur.quantite` « La quantité doit être un nombre entier entre 0 et {max}. », `commun.erreur.image`.
- **Notifications** : aucune.
- **Liens** : Galerie (image), Factures (articles proposés dans les lignes de facture, PRO-STO-08), PRO-STO-10.
- **Réglages** : `Config.Stock.MaxPrice = 1000000`, `Config.Stock.MaxQuantity = 999999`, `Config.Stock.InvoiceLink = true`.
- **Journal admin** : oui, `stock_item_create` / `stock_item_update` (qui, article, avant/après).
- **Performance** : 1 transaction.
- **Cas limites** :
  - Prix « 12,345 » → arrondi à 12,35.
  - Quantité de départ 0 → mouvement `creation` avec `delta = 0` quand même (trace de création).
  - Double clic sur « Enregistrer » à la création → un seul article (C10).
- **Critères d'acceptation** :
  - Étant donné un Chef, quand il crée « Pneu » à 150 $ avec 20 en stock, alors l'article apparaît avec 20 et l'historique montre « Création de l'article (+20) ».
  - Étant donné un article existant, quand il change le prix, alors la quantité ne change pas.
  - Étant donné un client modifié qui envoie `quantity = 500` lors d'une modification, alors la quantité reste inchangée.
  - Étant donné un Membre avec un client modifié qui appelle `stock:save`, alors le serveur refuse.

### [PRO-STO-03] Archiver et restaurer un article
- **But** : retirer un article de la liste sans perdre son historique.
- **Qui** : archiver : `stock.modifier` ; restaurer : `stock.modifier`.
- **Où** : fiche d'un article > « Archiver » ; Stock > filtre « Archivés » (ajouté à la liste des filtres pour qui a `stock.modifier`) > « Restaurer ».
- **Parcours** :
  1. Confirmation « Archiver « {nom} » ? Il n'apparaîtra plus dans le stock ni dans les factures. Son historique est gardé. » → `stock:archive { id }` → `archived_at`, `archived_by`.
  2. Article archivé : plus proposé dans les factures, plus déduit automatiquement, plus d'alerte, lien coffre suspendu.
  3. « Restaurer » → `stock:restore { id }` → vérifie limite d'articles et unicité du nom (sinon ajoute « (restauré) »).
- **Données** : `archived_at`, `archived_by`.
- **Règles serveur** : droit ; jamais de suppression par un joueur.
- **Textes et états** :
  - `stock.archiver.confirmer` « Archiver « {nom} » ? Il n'apparaîtra plus dans le stock ni dans les factures. Son historique est gardé. ».
  - Succès : `stock.succes.archive` « Article archivé. », `stock.succes.restaure` « Article restauré. ».
  - Filtre : `stock.filtre.archives` « Archivés » ; vide `stock.archives.vide` « Aucun article archivé. ».
- **Notifications** : aucune.
- **Liens** : Factures, PRO-STO-08, PRO-STO-10.
- **Réglages** : aucun.
- **Journal admin** : oui, `stock_item_archive` / `stock_item_restore`.
- **Performance** : 1 requête.
- **Cas limites** :
  - Facture en attente de paiement contenant l'article archivé → au paiement, pas de déduction, mouvement non créé, ligne au journal `stock_skip_archived`.
  - Restauration avec 200 articles actifs → `stock.erreur.limite`.
  - Archivage d'un article lié à un coffre → le coffre n'est pas touché.
- **Critères d'acceptation** :
  - Étant donné un article archivé, alors il disparaît de la liste et du sélecteur d'articles des factures.
  - Étant donné le filtre « Archivés », quand je restaure l'article, alors il revient avec sa quantité et son historique.
  - Étant donné un client modifié qui envoie `stock:delete`, alors le serveur refuse (action inexistante pour un joueur).

### [PRO-STO-04] Entrée de stock
- **But** : enregistrer une arrivée de marchandise.
- **Qui** : `stock.modifier`.
- **Où** : fiche d'un article > « Entrée » ; liste > clic droit sur une ligne > « Entrée ».
- **Parcours** :
  1. Fenêtre : « Quantité reçue » (entier 1–99 999), « Motif (facultatif) » (100 car., suggestions : « Livraison », « Achat », « Retour client »), [Valider].
  2. `stock:move { itemId, type = 'entree', qty, reason, actionId }` → serveur : C3, C4 (10 / 10 s), C7, C10, article de l'entreprise, non archivé, **non lié à un coffre** (sinon refus : les entrées passent par le coffre), requête atomique (`quantity + qty ≤ MaxQuantity`), mouvement `entree`.
  3. Si la quantité repasse au-dessus du seuil → `low_alerted = 0`.
  4. Bandeau succès ; les autres employés qui regardent le Stock voient la nouvelle quantité (push aux spectateurs du Stock de l'entreprise, même principe que PRO-TAB-11).
- **Données** : mouvement (voir table).
- **Règles serveur** : voir parcours.
- **Textes et états** :
  - `stock.entree.titre` « Entrée de stock », `stock.entree.quantite` « Quantité reçue », `stock.mouvement.motif` « Motif (facultatif) ».
  - Succès : `stock.succes.entree` « +{n} {article}. Nouveau stock : {total}. ».
  - Erreurs : `stock.erreur.quantite_invalide` « Quantité entière supérieure à 0 requise. », `stock.erreur.max` « Le stock ne peut pas dépasser {max}. », `stock.erreur.lie_coffre` « Article géré par le coffre. Déposez les objets dans le coffre. ».
- **Notifications** : aucune.
- **Liens** : PRO-STO-07, PRO-STO-09.
- **Réglages** : `Config.Stock.MaxMoveQty = 99999`.
- **Journal admin** : non (le mouvement est déjà une trace) ; oui si `qty ≥ Config.Stock.LogAboveQty = 1000` (`stock_big_move`).
- **Performance** : 1 transaction ; push aux seuls spectateurs.
- **Cas limites** :
  - Deux entrées simultanées par deux employés → les deux s'ajoutent (requête atomique).
  - Double clic → C10, une seule entrée.
  - Quantité décimale envoyée (2,5) → refus `stock.erreur.quantite_invalide`.
- **Critères d'acceptation** :
  - Étant donné « Pneu » à 4, quand j'enregistre une entrée de 10 « Livraison », alors le stock passe à 14 et l'historique montre « Entrée +10 · Livraison · {mon nom} ».
  - Étant donné un article lié au coffre, alors le bouton « Entrée » est remplacé par le texte `stock.erreur.lie_coffre`.
  - Étant donné un client modifié qui envoie `qty = -50` en entrée, alors le serveur refuse.

### [PRO-STO-05] Sortie de stock
- **But** : enregistrer une utilisation, une perte ou une vente hors facture.
- **Qui** : `stock.modifier`.
- **Où** : fiche d'un article > « Sortie ».
- **Parcours** :
  1. Fenêtre : « Quantité sortie » (entier 1–99 999), « Motif (facultatif) » (suggestions : « Utilisé en atelier », « Vente au comptoir », « Casse », « Perte »), [Valider].
  2. `stock:move { itemId, type = 'sortie', qty, reason, actionId }` → serveur : mêmes contrôles qu'en entrée, requête atomique avec `quantity - qty ≥ 0`. Si 0 ligne modifiée → refus stock insuffisant.
  3. Mouvement `sortie` (`delta` négatif), puis contrôle du seuil (PRO-STO-09).
- **Données** : mouvement.
- **Règles serveur** : le stock ne devient jamais négatif.
- **Textes et états** :
  - `stock.sortie.titre` « Sortie de stock », `stock.sortie.quantite` « Quantité sortie ».
  - Succès : `stock.succes.sortie` « −{n} {article}. Nouveau stock : {total}. ».
  - Insuffisant : `stock.erreur.insuffisant` « Stock insuffisant : il reste {n}. ».
  - Lié au coffre : `stock.erreur.lie_coffre_sortie` « Article géré par le coffre. Prenez les objets dans le coffre. ».
- **Notifications** : PRO-STO-09 si le seuil est franchi.
- **Liens** : PRO-STO-07, PRO-STO-09.
- **Réglages** : ceux de PRO-STO-04.
- **Journal admin** : comme PRO-STO-04.
- **Performance** : 1 transaction.
- **Cas limites** :
  - Deux sorties simultanées de 3 sur un stock de 4 → la première passe (reste 1), la seconde est refusée « il reste 1 ».
  - Sortie de tout le stock → pastille « Rupture ».
  - Article archivé entre l'ouverture et la validation → refus `stock.erreur.archive` « Cet article est archivé. ».
- **Critères d'acceptation** :
  - Étant donné « Pneu » à 4, quand je sors 3, alors il reste 1.
  - Étant donné « Pneu » à 1, quand je sors 3, alors « Stock insuffisant : il reste 1. » et rien ne change.
  - Étant donné un client modifié qui envoie deux sorties de 3 en parallèle sur 4, alors une seule est acceptée.

### [PRO-STO-06] Corriger le stock (inventaire) (ajout)
- **But** : remettre la quantité réelle après un comptage.
- **Qui** : `stock.modifier`.
- **Où** : fiche d'un article > « Corriger le stock ».
- **Parcours** :
  1. Fenêtre : « Quantité comptée » (entier 0–999 999, pré-rempli avec la quantité actuelle), « Motif » (obligatoire, 3–100 car., placeholder « Ex. : inventaire du lundi »), aperçu « Écart : +{n} / −{n} ».
  2. `stock:adjust { itemId, counted, reason, expectedQty, actionId }` → serveur : contrôles de PRO-STO-04, `expectedQty` = quantité affichée au joueur : si la quantité a changé entre-temps → refus conflit ; sinon `UPDATE quantity = counted`, mouvement `ajustement` avec `delta = counted - ancienne`.
  3. Écart 0 → aucun mouvement, message « Aucun écart. ».
- **Données** : mouvement `ajustement`.
- **Règles serveur** : motif obligatoire ; contrôle de conflit.
- **Textes et états** :
  - `stock.ajuster.titre` « Corriger le stock », `stock.ajuster.compte` « Quantité comptée », `stock.ajuster.motif` « Motif », placeholder `stock.ajuster.motif_exemple` « Ex. : inventaire du lundi », `stock.ajuster.ecart` « Écart : {ecart} ».
  - Succès : `stock.succes.ajuste` « Stock corrigé : {total}. », `stock.ajuster.aucun_ecart` « Aucun écart. ».
  - Conflit : `stock.erreur.conflit` « Stock modifié entre-temps ({n} maintenant). ».
  - Motif manquant : `stock.erreur.motif` « Raison de la correction requise. ».
- **Notifications** : PRO-STO-09 si le seuil est franchi.
- **Liens** : PRO-STO-07.
- **Réglages** : aucun.
- **Journal admin** : oui, `stock_adjust` (qui, article, avant/après, motif) — les corrections sont la porte ouverte aux détournements.
- **Performance** : 1 transaction.
- **Cas limites** :
  - Article lié à un coffre → bouton caché (le coffre fait foi).
  - Comptage supérieur au maximum → refus `stock.erreur.max`.
  - Double clic → C10.
- **Critères d'acceptation** :
  - Étant donné 14 en stock, quand je corrige à 12 « inventaire », alors le stock est 12 et l'historique montre « Correction −2 · inventaire ».
  - Étant donné une sortie d'un collègue pendant ma saisie, alors ma correction est refusée avec le message de conflit.
  - Étant donné un client modifié qui omet le motif, alors le serveur refuse.

### [PRO-STO-07] Historique des mouvements
- **But** : savoir qui a fait entrer ou sortir quoi, et quand.
- **Qui** : `stock.lire`.
- **Où** : fiche d'un article > « Historique » ; Stock > bouton « Tous les mouvements » (en haut de la liste).
- **Parcours** :
  1. `stock:moves { companyId, itemId = nil|id, type = 'tous', from, to, page }` → serveur : C3, C4, C7, renvoie 20 mouvements par page, du plus récent au plus ancien.
  2. Chaque ligne : date, article (vue globale), type en clair, quantité signée (« +10 » / « −3 »), stock après, motif, auteur (`Prénom N.` ou « Automatique »), lien « Facture n° {n} » pour le type facture (ouvre la facture si droit).
  3. Filtres : type (Tous, Entrées, Sorties, Corrections, Factures, Coffre), période (7 jours, 30 jours, tout ; défaut 30 jours).
- **Données** : lecture de `pop_tablet_stock_moves`.
- **Règles serveur** : entreprise du joueur uniquement ; mouvements jamais modifiables.
- **Textes et états** :
  - Types : `stock.type.entree` « Entrée », `stock.type.sortie` « Sortie », `stock.type.ajustement` « Correction », `stock.type.facture` « Facture », `stock.type.coffre_entree` « Dépôt au coffre », `stock.type.coffre_sortie` « Retrait du coffre », `stock.type.creation` « Création de l'article ».
  - `stock.historique.auto` « Automatique », `stock.historique.facture` « Facture n° {n} ».
  - Vide : `stock.historique.vide` « Aucun mouvement sur cette période. ».
- **Notifications** : aucune.
- **Liens** : Factures.
- **Réglages** : `Config.Stock.MovesPageSize = 20`.
- **Journal admin** : non.
- **Performance** : index `(company_id, created_at)` et `(item_id, created_at)` ; pagination ; mouvements de plus de `Config.Stock.MovesKeepDays = 180` jours lisibles seulement par l'admin (non supprimés).
- **Cas limites** :
  - Article archivé → son historique reste visible depuis la vue globale (nom suivi de « (archivé) »).
  - Auteur qui a quitté l'entreprise → son nom reste affiché (`by_name` figé).
  - 10 000 mouvements → pagination, pas de chargement complet.
- **Critères d'acceptation** :
  - Étant donné 3 mouvements sur « Pneu », quand j'ouvre son historique, alors ils s'affichent du plus récent au plus ancien avec auteur et stock après.
  - Étant donné le filtre « Factures », alors seuls les mouvements de factures s'affichent.
  - Étant donné un client modifié qui demande les mouvements d'une autre entreprise, alors le serveur refuse.

### [PRO-STO-08] Déduction automatique par facture (option)
- **But** : retirer du stock ce qui est vendu, au paiement de la facture.
- **Qui** : système ; activé par article (`auto_invoice`) par `stock.modifier`, et globalement par `Config.Stock.InvoiceLink`.
- **Où** : Factures (branche Entreprises) > création d'une facture > ligne « Article du stock » ; déclenché au paiement.
- **Parcours** :
  1. Côté Factures (si `Config.Stock.InvoiceLink = true`) : en ajoutant une ligne, l'employé peut choisir « Article du stock » → liste des articles non archivés de l'entreprise (nom, prix, quantité dispo) → la ligne est pré-remplie (libellé = nom, prix unitaire = prix, quantité = 1 modifiable) et garde `item_id`. Le prix reste modifiable selon les règles de Factures (montant max, droit du grade).
  2. Au paiement, Factures émet `pop_tablet:invoicePaid` (format BASE-API-09 ; `lines[].itemId` = article Stock lié, `lines[].qty` = quantité).
  3. Stock écoute : pour chaque ligne avec `itemId` de **cette entreprise**, article non archivé et `auto_invoice = 1` : déduction atomique de `qty` ; si le stock est insuffisant, déduction jusqu'à 0 (la vente a déjà eu lieu), mouvement `facture` avec raison « Stock insuffisant à la facture n° {n} (manque {m}) » et ligne au journal admin `stock_invoice_short`.
  4. Article lié à un coffre : retrait dans le coffre (PRO-STO-10) au lieu de la quantité de la tablette.
  5. Idempotence : clé unique (`invoice_id`, `item_id`) dans les mouvements ; un événement rejoué ne déduit pas deux fois.
  6. Contrôle du seuil (PRO-STO-09).
- **Données** : mouvements `facture` (`by_identifier = 'system'`, `by_name` = employé qui a fait la facture).
- **Règles serveur** : jamais de déduction à la création de la facture, seulement au paiement ; facture annulée ou remboursée → aucun retour automatique en stock (une entrée manuelle reste possible).
- **Textes et états** :
  - Côté Factures : `stock.facture.choisir` « Article du stock », `stock.facture.dispo` « {n} en stock ».
  - Historique : raison `stock.facture.motif` « Facture n° {n} », `stock.facture.manque` « Stock insuffisant à la facture n° {n} (manque {m}) ».
- **Notifications** : stock insuffisant → employés avec `stock.modifier` en service : titre `stock.notif.manque` « Stock : vente de {article} sans stock suffisant », texte `stock.notif.manque_texte` « Facture n° {n} : il manquait {m}. ».
- **Liens** : Factures (signal écouté `pop_tablet:invoicePaid`), Tableur (même signal, PRO-TAB-08).
- **Réglages** : `Config.Stock.InvoiceLink = true`.
- **Journal admin** : oui pour `stock_invoice_short`.
- **Performance** : rien ne tourne en attente ; traitement sur l'événement, une transaction par facture.
- **Cas limites** :
  - Facture payée par un joueur inconscient au réveil (règle du contexte) → déduction au moment réel du paiement.
  - Article archivé entre la facture et le paiement → pas de déduction, journal `stock_skip_archived`.
  - `auto_invoice = 0` sur l'article → la ligne de facture garde l'article mais aucune déduction.
  - Événement reçu deux fois → une seule déduction.
- **Critères d'acceptation** :
  - Étant donné « Pneu » à 10 avec déduction auto, quand une facture de 4 pneus est payée, alors le stock passe à 6 avec un mouvement « Facture n° … ».
  - Étant donné « Pneu » à 2, quand une facture de 4 est payée, alors le stock passe à 0, la raison indique « manque 2 » et les responsables en service sont prévenus.
  - Étant donné un client modifié qui émet `pop_tablet:invoicePaid` côté client, alors rien ne se passe (événement serveur interne, jamais enregistré comme événement réseau).

### [PRO-STO-09] Alerte de seuil
- **But** : prévenir quand un article va manquer.
- **Qui** : reçoivent l'alerte : employés avec `stock.modifier`, en service, avec la tablette.
- **Où** : déclenchée après chaque mouvement ; affichée en notification et en pastille.
- **Parcours** :
  1. Après tout mouvement qui baisse la quantité : si `threshold > 0` et `quantity ≤ threshold` et `low_alerted = 0` → `low_alerted = 1` et envoi de l'alerte.
  2. Après tout mouvement qui monte la quantité au-dessus du seuil → `low_alerted = 0` (sans message).
  3. Si personne n'est en service : l'alerte n'est pas mise en attente ; la pastille de l'app (PRO-STO-01) et le filtre « Stock bas » suffisent.
- **Données** : `threshold`, `low_alerted`.
- **Règles serveur** : une alerte par passage sous le seuil ; jamais d'alerte pour un article archivé.
- **Textes et états** : notification (ci-dessous) ; pastille « Stock bas ».
- **Notifications** : titre `stock.notif.bas` « Stock bas : {article} », texte `stock.notif.bas_texte` « Il reste {n} (alerte à {seuil}). » ; si `quantity = 0` : titre `stock.notif.rupture` « Rupture : {article} », texte `stock.notif.rupture_texte` « Plus aucun en stock. ». Action : ouvrir la fiche de l'article.
- **Liens** : PRO-STO-04 à 08, 10.
- **Réglages** : `Config.Stock.NotifyLow = true`.
- **Journal admin** : non.
- **Performance** : calcul dans la même transaction que le mouvement ; notifications aux seuls concernés.
- **Cas limites** :
  - Seuil modifié à une valeur au-dessus du stock actuel → pas d'alerte immédiate (PRO-STO-02 met `low_alerted = 1`).
  - Stock qui oscille 5 → 4 → 6 → 4 avec seuil 5 → 2 alertes (une par passage sous le seuil).
  - 20 articles qui passent sous le seuil dans la même facture → notifications regroupées en une : « Stock bas : {n} articles ».
- **Critères d'acceptation** :
  - Étant donné un seuil de 5 et un stock de 6, quand je sors 2, alors les Chefs en service reçoivent « Stock bas : Pneu · Il reste 4 (alerte à 5). ».
  - Étant donné ensuite une nouvelle sortie de 1, alors aucune nouvelle alerte.
  - Étant donné un Membre hors service, alors il ne reçoit pas l'alerte.

### [PRO-STO-10] Lien avec le coffre de l'inventaire (si possible)
- **But** : que le stock de la tablette soit celui du coffre de l'entreprise dans le jeu.
- **Qui** : configurer : `stock.modifier` ; fonctionne pour tous automatiquement ensuite.
- **Où** : formulaire d'article (PRO-STO-02) > section « Coffre ».
- **Parcours** :
  1. Détection au démarrage : `ox_inventory` démarré → mode complet ; `qs-inventory` démarré → mode lecture ; sinon section cachée.
  2. Section : « Objet du jeu » (liste avec recherche des objets de l'inventaire : nom affiché + nom technique), « Coffre » (liste des coffres de l'entreprise : `Config.Stock.Stashes[job]`, par défaut `{ 'society_' .. job }`), interrupteur « Lier cet article au coffre ».
  3. Validation serveur : l'objet existe (`exports.ox_inventory:Items(name)`), le coffre appartient à l'entreprise (dans `Config.Stock.Stashes[job]`), un même couple objet + coffre n'est lié qu'à un seul article.
  4. **Quantité** d'un article lié = nombre de cet objet dans le coffre : `exports.ox_inventory:GetItemCount(stashId, invItem)` (ou somme des `amount` de `exports['qs-inventory']:GetStashItems(stashId)` pour qs), lu à l'ouverture de la liste/fiche, mis en cache 10 s ; la colonne `quantity` est mise à jour avec cette valeur. Les boutons Entrée / Sortie / Corriger sont cachés.
  5. **Traçage (ox_inventory)** : au démarrage, le serveur pose un crochet `exports.ox_inventory:registerHook('swapItems', fn, { inventoryFilter = { coffres liés }, itemFilter = { objets liés } })`. Le crochet ne bloque rien (`return true`) ; il enregistre un mouvement `coffre_entree` ou `coffre_sortie` (auteur = joueur qui déplace, quantité = `count`), met à jour `quantity` et applique PRO-STO-09. Le crochet est reposé à chaque changement de lien.
  6. **Traçage (qs-inventory, mode lecture)** : pas de crochet ; à chaque lecture, si la quantité lue diffère de la dernière quantité connue, un mouvement `ajustement` « Écart constaté au coffre » est enregistré (auteur « Automatique »).
  7. **Facture** (PRO-STO-08) sur un article lié : `exports.ox_inventory:RemoveItem(stashId, invItem, qty)` ; si le coffre en a moins, retire ce qu'il y a et applique la règle « manque ». En mode qs : `exports['qs-inventory']:RemoveItemIntoStash(stashId, invItem, qty)` si disponible, sinon pas de retrait et ligne au journal `stock_invoice_no_stash`.
- **Données** : `inv_item`, `stash_id` ; mouvements `coffre_entree` / `coffre_sortie` / `ajustement`.
- **Règles serveur** : coffre de l'entreprise uniquement ; jamais un coffre de joueur ; le crochet ne modifie pas l'action d'inventaire.
- **Textes et états** :
  - `stock.coffre.titre` « Coffre », `stock.coffre.objet` « Objet du jeu », `stock.coffre.coffre` « Coffre », `stock.coffre.lier` « Lier cet article au coffre ».
  - Fiche : `stock.coffre.gere` « Quantité gérée par le coffre « {coffre} ». ».
  - Erreurs : `stock.coffre.objet_inconnu` « Cet objet n'existe pas dans l'inventaire du serveur. », `stock.coffre.pas_a_toi` « Ce coffre n'appartient pas à l'entreprise. », `stock.coffre.deja_lie` « Cet objet de ce coffre est déjà lié à l'article « {article} ». ».
  - Mode lecture (qs) : aide `stock.coffre.lecture` « Les mouvements du coffre ne sont pas tracés un par un avec cet inventaire : seuls les écarts sont notés. ».
  - Coffre introuvable : `stock.coffre.introuvable` « Coffre introuvable ».
- **Notifications** : PRO-STO-09.
- **Liens** : ox_inventory / qs-inventory (via le bridge), PRO-STO-08.
- **Réglages** : `Config.Stock.Stashes = {}` (vide = `society_<job>`), `Config.Stock.StashCacheSec = 10`, `Config.Stock.InventoryLink = true`.
- **Journal admin** : oui, `stock_link` (qui, article, objet, coffre, avant/après).
- **Performance** : lecture du coffre seulement à l'ouverture de l'écran (cache 10 s) ; crochet filtré par coffres et objets (n'est appelé que pour eux) ; aucune boucle.
- **Cas limites** :
  - ox_inventory redémarré → le crochet est reposé quand `onResourceStart` de ox_inventory est reçu.
  - Objet retiré de l'inventaire du serveur → article affiché « Coffre introuvable », lien gardé, journal admin `stock_link_broken`.
  - Joueur qui vide le coffre entier d'un coup (swap de 50) → un seul mouvement `coffre_sortie −50`.
- **Critères d'acceptation** :
  - Étant donné « Pneu » lié à `society_mechanic` avec ox_inventory, quand un mécano dépose 5 pneus dans le coffre, alors la fiche montre +5 « Dépôt au coffre » avec son nom.
  - Étant donné une facture de 2 pneus payée, alors 2 pneus disparaissent du coffre.
  - Étant donné un client modifié qui lie un article au coffre `society_police` depuis le garage, alors le serveur refuse avec `stock.coffre.pas_a_toi`.

---

## 9. Planning (Gestion pro)

**Deux modes au choix du serveur** (`Config.Planning.TimeMode`) :
- `'reel'` (défaut) : créneaux datés en heure réelle du serveur (affichée avec le libellé `Config.Planning.TimeZoneLabel = 'heure du serveur'`), vue par semaine.
- `'jeu'` : créneaux en heure du jeu sur une **journée type** qui se répète à chaque journée du jeu (une journée du jeu dure 48 min réelles par défaut). Le serveur connaît l'heure du jeu grâce à une horloge de référence : à chaque ouverture de la tablette, le client envoie `GetClockHours()` / `GetClockMinutes()` ; le serveur garde `{ realMs, gameMin }` de la dernière valeur reçue et calcule `heureJeu(t) = (gameMin + (t - realMs) / Config.Planning.MsPerGameMinute) mod 1440` avec `MsPerGameMinute = 2000`. Si un script météo/heure exporte l'heure (`Config.Planning.GameClockExport = { resource = '', export = '' }`, ex. une ressource qui renvoie `{ hour, minute }`), il est utilisé à la place.

Les disponibilités et les absences sont **toujours en heure réelle** (ce sont les moments où le joueur est présent sur le serveur).

Tables communes :
- `pop_tablet_planning_slots` : `id` INT auto, `company_id` INT index, `mode` ENUM('reel','jeu'), `day` DATE NULL (mode réel), `start_min` SMALLINT 0–1439, `end_min` SMALLINT 0–1439 (si `end_min ≤ start_min`, le créneau finit le lendemain), `label` VARCHAR(30), `needed` TINYINT 0–20 (nombre de personnes voulues, 0 = pas d'objectif), `series_id` INT NULL (répétition), `created_by` VARCHAR(60), `created_at`, `archived_at` NULL.
- `pop_tablet_planning_assign` : `slot_id` INT, `identifier` VARCHAR(60), `name` VARCHAR(60), `reminded` TINYINT(1) défaut 0 ; clé (`slot_id`, `identifier`).
- `pop_tablet_planning_avail` : `id`, `identifier`, `company_id`, `weekday` TINYINT 1–7 (1 = lundi), `start_min`, `end_min`.
- `pop_tablet_planning_absences` : `id`, `identifier`, `company_id`, `from_day` DATE, `to_day` DATE, `reason` VARCHAR(100), `created_at`.
- Lu dans la base : `pop_tablet_ent_services` (`identifier`, `company_id`, `start_at`, `end_at` NULL si en cours) et, pour le mode jeu, `pop_tablet_connections` (`identifier`, `join_at`, `drop_at`), table créée par le Planning (ce fichier : `id` INT auto, `identifier` VARCHAR(64) index, `join_at` DATETIME, `drop_at` DATETIME NULL), remplie à la connexion (`pop_tablet:bridge:playerLoaded`) et à la déconnexion (`playerDropped`), purgée au démarrage des lignes de plus de 35 jours ; elle n'est écrite que si au moins une entreprise utilise le mode « heure du jeu ».

### [PRO-PLA-01] Voir le planning
- **But** : voir qui travaille quand.
- **Qui** : `planning.voir` (ajout, défaut Recrue : tous les employés).
- **Où** : Accueil > branche Entreprises > Gestion pro > « Planning ».
- **Parcours** :
  1. Mode réel : `planning:week { companyId, weekStart }` (lundi de la semaine, défaut semaine actuelle) → serveur : C3, C4, C7/C8, C15, renvoie les créneaux non archivés de la semaine, leurs affectés, le statut de présence des créneaux passés (PRO-PLA-07, résumé), les absences de la semaine.
  2. Écran mode réel : en-tête « Semaine du {date} au {date} » avec flèches ← → et bouton « Aujourd'hui » ; grille 7 colonnes (lun → dim), lignes de 00:00 à 24:00 (la vue s'ouvre sur 08:00, défilement vertical), graduations toutes les heures ; chaque créneau = bloc (libellé, horaire, initiales des affectés, « {n}/{voulu} » si `needed > 0` — en couleur d'accent si incomplet) ; ligne horizontale de l'heure actuelle. Les employés absents ont leurs initiales barrées.
  3. Mode jeu : `planning:day { companyId }` → écran « Journée type (heure du jeu) » : une seule colonne 00:00–24:00 avec les créneaux, indicateur de l'heure du jeu actuelle (calculée côté NUI à partir de la référence envoyée), mention « Une journée du jeu dure {n} min réelles. ».
  4. Interrupteur « Mes créneaux » : ne montre que les créneaux où le joueur est affecté.
  5. Clic sur un créneau → détail : libellé, horaire, affectés (nom, statut de présence si passé, mention « Absent » si absence déclarée), boutons « Modifier » / « Affecter » (si `planning.remplir`).
- **Données** : affichage seul.
- **Règles serveur** : membre de l'entreprise ; semaine demandée bornée à ± 26 semaines autour de l'actuelle.
- **Textes et états** :
  - `planning.semaine.titre` « Semaine du {debut} au {fin} », `planning.bouton.aujourdhui` « Aujourd'hui », `planning.filtre.mes_creneaux` « Mes créneaux ».
  - Jeu : `planning.jeu.titre` « Journée type (heure du jeu) », `planning.jeu.duree` « Une journée du jeu dure {n} min réelles. ».
  - Libellé de fuseau (mode réel) : `planning.fuseau` « Heures affichées : {fuseau} ».
  - Vide : `planning.vide` « Aucun créneau cette semaine. » + bouton `planning.creer` « Créer un créneau » (si droit ; sinon `planning.vide_lecture` « Aucun créneau prévu. »).
  - Incomplet : `planning.creneau.incomplet` « {n}/{voulu} ».
- **Notifications** : aucune.
- **Liens** : PRO-PLA-03 à 07.
- **Réglages** : `Config.Planning.TimeMode = 'reel'`, `Config.Planning.TimeZoneLabel = 'heure du serveur'`, `Config.Planning.WeekRange = 26`, `Config.Planning.MsPerGameMinute = 2000`.
- **Journal admin** : non.
- **Performance** : une semaine chargée à la fois ; présence calculée seulement pour les créneaux passés affichés et mise en cache 5 min par créneau terminé.
- **Cas limites** :
  - Créneau qui passe minuit (22:00 → 02:00) → affiché en deux morceaux (fin de jour + début du lendemain), un seul créneau en données.
  - Changement de mode par l'admin → les créneaux de l'autre mode restent en base mais ne s'affichent pas ; un bandeau admin le rappelle (`planning.mode_change` « Des créneaux de l'ancien mode sont masqués. »).
  - Semaine à +30 semaines demandée → ramenée à +26.
- **Critères d'acceptation** :
  - Étant donné 3 créneaux cette semaine, quand j'ouvre le Planning, alors ils sont dans les bonnes colonnes aux bonnes heures.
  - Étant donné « Mes créneaux » activé, alors seuls mes créneaux restent visibles.
  - Étant donné un client modifié qui demande le planning d'une autre entreprise, alors le serveur refuse.

### [PRO-PLA-02] Horloge du mode « heure du jeu » (ajout)
- **But** : que le serveur sache l'heure du jeu sans boucle, pour les rappels et la présence en mode jeu.
- **Qui** : système.
- **Où** : à chaque ouverture de tablette d'un joueur (mode jeu seulement).
- **Parcours** :
  1. Si `Config.Planning.GameClockExport.resource` est démarrée, le serveur appelle l'export à la demande et n'utilise pas les valeurs des clients.
  2. Sinon, à l'ouverture de la tablette, le client envoie `{ h = GetClockHours(), m = GetClockMinutes() }` avec l'ouverture normale de la tablette.
  3. Serveur : n'accepte une nouvelle référence que si elle diffère de l'heure calculée de plus de `Config.Planning.ClockTolerance = 15` minutes de jeu **et** si au moins 3 joueurs différents ont envoyé une valeur cohérente entre elles (± 5 min) dans les 2 dernières minutes réelles ; sinon garde l'ancienne. Au tout premier démarrage, la première valeur reçue est prise.
  4. `GameTime.Now()` renvoie l'heure du jeu en minutes ; `GameTime.NextOccurrence(min)` renvoie le moment réel de la prochaine occurrence d'une heure du jeu.
- **Données** : référence en mémoire (`realMs`, `gameMin`) ; sauvegardée dans le KVP serveur (`SetResourceKvp`) pour survivre à un redémarrage.
- **Règles serveur** : protection contre un client qui enverrait une fausse heure (accord de 3 joueurs).
- **Textes et états** : aucun.
- **Notifications** : aucune.
- **Liens** : PRO-PLA-06, PRO-PLA-07.
- **Réglages** : `Config.Planning.GameClockExport = { resource = '', export = '' }`, `Config.Planning.ClockTolerance = 15`, `Config.Planning.MsPerGameMinute = 2000`.
- **Journal admin** : non.
- **Performance** : aucune boucle ; un calcul à la demande.
- **Cas limites** :
  - Serveur sans joueur connecté → la référence continue d'être calculée par la formule.
  - Script météo qui fige l'heure (temps arrêté) → l'admin doit renseigner l'export ; sinon les rappels en mode jeu dérivent (signalé dans le guide admin).
  - Un seul joueur avec une heure différente → ignoré.
- **Critères d'acceptation** :
  - Étant donné 3 joueurs qui envoient 14:00 ± 2 min alors que le serveur calcule 10:00, alors la référence passe à 14:00.
  - Étant donné un seul client modifié qui envoie 03:00, alors la référence ne change pas.
  - Étant donné un export configuré, alors les valeurs des clients sont ignorées.

### [PRO-PLA-03] Créer, modifier, supprimer un créneau
- **But** : prévoir les horaires de travail.
- **Qui** : `planning.remplir` (défaut Chef).
- **Où** : Planning > glisser sur une zone vide de la grille (sélection d'horaire), ou bouton « + Créneau » ; détail d'un créneau > « Modifier » / « Supprimer ».
- **Parcours** :
  1. Fenêtre : « Libellé » (30 car., placeholder « Ex. : Ouverture »), « Jour » (date ; mode réel seulement), « Début » et « Fin » (pas de 15 min, sélecteurs HH:MM), « Personnes voulues » (0–20, 0 = pas d'objectif), « Répéter chaque semaine pendant » (Aucune / 2 / 4 / 8 semaines ; mode réel, création seulement), puis section Affectation (PRO-PLA-04).
  2. `planning:saveSlot { companyId, id = nil|id, label, day, startMin, endMin, needed, repeatWeeks, actionId }` → serveur : C3, C4 (5 / 10 s), C7, C10, C5 sur le libellé, durée entre 15 min et `Config.Planning.MaxSlotHours = 12` h, jour dans ± 26 semaines, pas plus de `Config.Planning.MaxSlotsPerWeek = 100` créneaux par semaine pour l'entreprise, création des copies hebdomadaires avec le même `series_id`.
  3. Modifier un créneau d'une série → question « Modifier seulement ce créneau ou aussi les suivants de la série ? » [Ce créneau] [Celui-ci et les suivants].
  4. Supprimer → confirmation « Supprimer ce créneau ? Les employés affectés seront prévenus. » (+ même choix série) → `archived_at` (archivé, gardé pour l'historique de présence).
  5. Créneau déjà commencé ou passé : seuls le libellé et l'objectif sont modifiables ; il ne peut pas être supprimé (le bouton est caché).
  6. Affectés prévenus en cas de changement d'horaire ou de suppression (Notifications).
- **Données** : `pop_tablet_planning_slots`.
- **Règles serveur** : voir parcours ; chevauchement de créneaux autorisé (deux postes en même temps).
- **Textes et états** :
  - `planning.form.libelle` « Libellé », placeholder `planning.form.libelle_exemple` « Ex. : Ouverture », `planning.form.jour` « Jour », `planning.form.debut` « Début », `planning.form.fin` « Fin », `planning.form.voulu` « Personnes voulues », `planning.form.repeter` « Répéter chaque semaine pendant », options `planning.form.repeter_non` « Aucune », `planning.form.repeter_n` « {n} semaines ».
  - Série : `planning.serie.question` « Modifier seulement ce créneau ou aussi les suivants de la série ? », `planning.serie.un` « Ce créneau », `planning.serie.suivants` « Celui-ci et les suivants ».
  - Suppression : `planning.supprimer.confirmer` « Supprimer ce créneau ? Les employés affectés seront prévenus. ».
  - Succès : `planning.succes.cree` « Créneau ajouté. », `planning.succes.crees` « {n} créneaux ajoutés. », `planning.succes.modifie` « Créneau modifié. », `planning.succes.supprime` « Créneau supprimé. ».
  - Erreurs : `planning.erreur.duree` « Un créneau dure entre 15 min et {max} h. », `planning.erreur.libelle` « Libellé du créneau requis. », `planning.erreur.trop` « Trop de créneaux cette semaine ({max} maximum). », `planning.erreur.passe` « Ce créneau a déjà commencé : seuls le libellé et l'objectif peuvent changer. ».
- **Notifications** : affectés (C14) : changement d'horaire → titre `planning.notif.modifie` « Planning : créneau modifié », texte `planning.notif.modifie_texte` « « {libelle} » est maintenant le {jour} de {debut} à {fin}. » ; suppression → titre `planning.notif.supprime` « Planning : créneau annulé », texte `planning.notif.supprime_texte` « « {libelle} » du {jour} à {debut} est annulé. ». (Mode jeu : `{jour}` omis.)
- **Liens** : PRO-PLA-06 (rappels recalculés), PRO-PLA-07.
- **Réglages** : `Config.Planning.MaxSlotHours = 12`, `Config.Planning.MaxSlotsPerWeek = 100`, `Config.Planning.StepMinutes = 15`, `Config.Planning.MaxRepeatWeeks = 8`.
- **Journal admin** : oui, `planning_slot_create` / `update` / `delete` (qui, créneau, avant/après).
- **Performance** : création d'une série en une requête multi-lignes ; recalcul du prochain rappel (PRO-PLA-06) seulement si le créneau est dans les 24 h.
- **Cas limites** :
  - Début 22:00, fin 02:00 → créneau de 4 h sur deux jours.
  - Fin = début → refus durée.
  - Double clic sur « Enregistrer » avec répétition 8 semaines → une seule série (C10).
- **Critères d'acceptation** :
  - Étant donné un Chef, quand il crée « Ouverture » lundi 08:00–12:00 répété 4 semaines, alors 4 créneaux apparaissent sur 4 lundis.
  - Étant donné un créneau avec 2 affectés, quand il passe à 09:00, alors les 2 reçoivent « Planning : créneau modifié ».
  - Étant donné un Membre avec un client modifié qui appelle `planning:saveSlot`, alors le serveur refuse.

### [PRO-PLA-04] Affecter des employés à un créneau
- **But** : dire qui travaille sur chaque créneau.
- **Qui** : `planning.remplir`.
- **Où** : fenêtre de créneau > section « Affectation » ; détail d'un créneau > « Affecter ».
- **Parcours** :
  1. Liste de tous les employés de l'entreprise (nom, grade), chacun avec une case. À côté de chaque nom, une pastille calculée par le serveur pour ce créneau : « Disponible » (dans ses disponibilités, PRO-PLA-05), « Pas disponible » (hors disponibilités déclarées), « Absent » (absence déclarée), « Sans info » (aucune disponibilité déclarée), « Déjà sur un autre créneau » (chevauchement).
  2. Cocher / décocher → `planning:assign { slotId, identifiers[] }` (liste complète voulue) → serveur : C3, C4, C7, chaque identifiant doit être employé de l'entreprise (les autres sont ignorés), 20 affectés max par créneau, créneau non commencé.
  3. Un employé « Absent » ou « Pas disponible » peut quand même être coché après une confirmation « {nom} n'est pas disponible sur ce créneau. L'affecter quand même ? ».
  4. Les nouveaux affectés et les retirés sont prévenus.
- **Données** : `pop_tablet_planning_assign` (`name` figé pour l'affichage historique).
- **Règles serveur** : voir parcours.
- **Textes et états** :
  - Pastilles : `planning.dispo.oui` « Disponible », `planning.dispo.non` « Pas disponible », `planning.dispo.absent` « Absent », `planning.dispo.inconnu` « Sans info », `planning.dispo.conflit` « Déjà sur un autre créneau ».
  - Confirmation : `planning.affecter.confirmer` « {nom} n'est pas disponible sur ce créneau. L'affecter quand même ? ».
  - Succès : `planning.succes.affecte` « Affectation enregistrée. ».
  - Limite : `planning.erreur.trop_affectes` « 20 personnes maximum par créneau. ».
- **Notifications** : ajouté → titre `planning.notif.affecte` « Planning : nouveau créneau », texte `planning.notif.affecte_texte` « Prévu le {jour} de {debut} à {fin} (« {libelle} »). » ; retiré → titre `planning.notif.retire` « Planning : créneau retiré », texte `planning.notif.retire_texte` « Créneau du {jour} à {debut} retiré. ».
- **Liens** : PRO-PLA-05, PRO-PLA-06.
- **Réglages** : `Config.Planning.MaxAssignees = 20`.
- **Journal admin** : non (affectation courante, pas sensible).
- **Performance** : liste des employés lue dans le cache de la branche Entreprises ; pastilles calculées en une passe.
- **Cas limites** :
  - Employé viré après affectation → affectation retirée automatiquement à son départ (écoute de l'événement de la branche Entreprises `pop_tablet:memberLeft`).
  - Employé hors ligne → reçoit la pastille de l'app à sa prochaine connexion (pas de notification hors ligne).
  - Client modifié qui affecte un joueur extérieur à l'entreprise → ignoré.
- **Critères d'acceptation** :
  - Étant donné Alice disponible le lundi matin, quand j'ouvre l'affectation du créneau du lundi 9 h, alors elle a la pastille « Disponible ».
  - Étant donné Bob absent, quand je le coche, alors la confirmation s'affiche.
  - Étant donné un identifiant extérieur envoyé par un client modifié, alors il n'est pas affecté.

### [PRO-PLA-05] Disponibilités et absences des employés
- **But** : que chaque employé dise quand il peut venir et quand il sera absent.
- **Qui** : chaque employé pour lui-même (`planning.voir`) ; un Chef voit celles de tous (`planning.remplir`).
- **Où** : Planning > onglet « Mes disponibilités » ; onglet « Équipe » (Chef+).
- **Parcours** :
  1. « Mes disponibilités » : 7 lignes (lundi → dimanche), chaque ligne avec 0 à 3 plages « de HH:MM à HH:MM » (pas de 15 min), boutons « + plage » et croix. Bouton « Enregistrer » → `planning:setAvail { companyId, ranges = [{ weekday, startMin, endMin }] }` (remplace tout) → serveur : C3, C4 (3 / 30 s), max 21 plages, plages valides (début < fin dans la journée, pas de chevauchement dans le même jour).
  2. Section « Absences » : liste des absences à venir + bouton « Déclarer une absence » → « Du », « Au » (dates, ≤ 60 jours, pas dans le passé), « Raison (facultatif) » (100 car.) → `planning:addAbsence` ; croix pour supprimer une absence future (`planning:deleteAbsence`). Max 10 absences à venir.
  3. Déclarer une absence qui couvre un créneau où l'employé est affecté → les responsables (`planning.remplir`, en service) sont prévenus.
  4. Onglet « Équipe » : tableau employés × jours avec les plages de chacun, et les absences de la semaine.
- **Données** : `pop_tablet_planning_avail`, `pop_tablet_planning_absences` (une absence passée n'est jamais supprimée : historique de présence).
- **Règles serveur** : chacun ne modifie que les siennes ; dates bornées.
- **Textes et états** :
  - Onglets : `planning.onglet.dispos` « Mes disponibilités », `planning.onglet.equipe` « Équipe ».
  - Jours : `commun.jour.1` « Lundi » … `commun.jour.7` « Dimanche ».
  - `planning.dispo.ajouter_plage` « + plage », `planning.dispo.aucune` « Pas disponible ».
  - Aide : `planning.dispo.aide` « Moments habituels de présence en ville (heure réelle). ».
  - Absences : `planning.absence.declarer` « Déclarer une absence », `planning.absence.du` « Du », `planning.absence.au` « Au », `planning.absence.raison` « Raison (facultatif) », vide `planning.absence.vide` « Aucune absence prévue. ».
  - Succès : `planning.succes.dispos` « Disponibilités enregistrées. », `planning.succes.absence` « Absence déclarée. », `planning.succes.absence_supprimee` « Absence supprimée. ».
  - Erreurs : `planning.erreur.plage` « Une plage doit commencer avant de finir, sans chevaucher une autre. », `planning.erreur.absence_dates` « Choisissez des dates à venir, sur 60 jours maximum. », `planning.erreur.absence_limite` « 10 absences à venir maximum. ».
- **Notifications** : absence sur un créneau affecté → responsables en service : titre `planning.notif.absence` « Planning : absence déclarée », texte `planning.notif.absence_texte` « {nom} sera absent du {du} au {au} ({n} créneau(x) concerné(s)). ».
- **Liens** : PRO-PLA-04 (pastilles), PRO-PLA-07 (« Absence prévue »).
- **Réglages** : `Config.Planning.MaxAvailRangesPerDay = 3`, `Config.Planning.MaxAbsenceDays = 60`, `Config.Planning.MaxFutureAbsences = 10`.
- **Journal admin** : non.
- **Performance** : écriture en une transaction (suppression + insertion des plages).
- **Cas limites** :
  - Absence déclarée après le début d'un créneau → ne change pas son statut de présence passé (« Absence prévue » seulement si déclarée avant le début).
  - Disponibilité 22:00–24:00 → saisie `22:00` à `00:00` acceptée comme fin de journée (1440).
  - Employé de deux entreprises → disponibilités séparées par entreprise.
- **Critères d'acceptation** :
  - Étant donné mes plages lundi 18:00–22:00, quand un Chef m'affecte lundi 19:00, alors je suis « Disponible ».
  - Étant donné une absence du 1er au 3e déclarée alors que je suis affecté le 2, alors les responsables en service sont prévenus.
  - Étant donné un client modifié qui modifie les disponibilités d'un autre identifiant, alors le serveur l'ignore et ne touche que les miennes.

### [PRO-PLA-06] Rappels avant un créneau
- **But** : prévenir l'employé avant le début de son créneau.
- **Qui** : employés affectés, connectés, avec la tablette.
- **Où** : notification ; aucun écran propre.
- **Parcours** :
  1. Mode réel : le serveur tient la liste des rappels des 24 prochaines heures (`start - Config.Planning.ReminderMinutes`), construite au démarrage et mise à jour à chaque création / modification / affectation, triée par heure. **Une seule** minuterie `SetTimeout` vise le plus proche de ces deux moments : le prochain rappel, ou la fin de la fenêtre de 24 h (rechargement de la liste) ; à son déclenchement, elle envoie les rappels dus, marque `reminded = 1`, recharge la liste si besoin, puis se reprogramme. **S'il n'existe aucun créneau futur avec un employé affecté, aucune minuterie n'existe** (elle est recréée à la première création / affectation). Pas de minuterie quotidienne fixe. C'est conforme à la règle « zéro boucle » de la base (BASE-MOT-13) : minuterie ponctuelle, déclenchée par un événement daté, arrêtée quand il n'y a plus rien à faire.
  2. Mode jeu : à chaque connexion d'un employé affecté et à chaque déclenchement, la minuterie vise la prochaine occurrence réelle (`GameTime.NextOccurrence(start_min) - ReminderGameMinutes × MsPerGameMinute`) parmi les employés connectés ; pas de `reminded` stocké (un rappel par occurrence, gardé en mémoire).
  3. À la connexion d'un employé (événement de la base `pop_tablet:bridge:playerLoaded`), si un de ses créneaux est **en cours** et qu'il n'est pas en service : notification « a commencé ».
  4. Rappel envoyé seulement si l'employé n'est pas déjà en service pour cette entreprise.
- **Données** : `reminded` (mode réel).
- **Règles serveur** : jamais de rappel à un ancien employé, à un employé absent (absence déclarée), ni pour un créneau archivé.
- **Textes et états** : aucun écran.
- **Notifications** :
  - Rappel : titre `planning.notif.rappel` « Rappel : créneau à {heure} », texte `planning.notif.rappel_texte` « « {libelle} » · prise de service à prévoir. », action : ouvrir l'écran de prise de service de l'entreprise.
  - Déjà commencé : titre `planning.notif.commence` « Créneau commencé à {heure} », texte `planning.notif.commence_texte` « « {libelle} » · service à prendre. ».
  - Mode jeu : `{heure}` suivi de « (heure du jeu) » (`planning.heure_jeu` « (heure du jeu) »).
- **Liens** : Prise de service (base), PRO-PLA-02.
- **Réglages** : `Config.Planning.ReminderMinutes = 15`, `Config.Planning.ReminderGameMinutes = 60` (= 2 min réelles), `Config.Planning.Reminders = true`.
- **Journal admin** : non.
- **Performance** : au plus une minuterie active pour toute la ressource (pas une par créneau ni par joueur), aucune s'il n'y a pas de rappel à venir ; aucun parcours régulier de la base.
- **Cas limites** :
  - Créneau créé 5 min avant son début → pas de rappel « avant » (déjà dans la fenêtre), mais rappel « a commencé » si l'employé n'est pas en service au début.
  - Redémarrage de la ressource → liste reconstruite, `reminded = 1` évite les doublons.
  - 30 employés à rappeler en même temps → un seul déclenchement, 30 notifications.
- **Critères d'acceptation** :
  - Étant donné un créneau à 20:00 et moi affecté, connecté, hors service, quand il est 19:45, alors je reçois « Rappel : créneau à 20:00 ».
  - Étant donné que je suis déjà en service à 19:45, alors aucun rappel.
  - Étant donné la tablette fermée, alors le serveur n'a qu'une minuterie active pour tous les rappels et aucun thread client ne tourne.

### [PRO-PLA-07] Présence comparée aux prises de service
- **But** : voir si les employés étaient en service pendant leurs créneaux.
- **Qui** : chacun voit sa propre présence (`planning.voir`) ; tout le monde : `planning.remplir`.
- **Où** : détail d'un créneau passé ; Planning > onglet « Présence ».
- **Parcours** :
  1. **Mode réel**, pour chaque couple (créneau terminé ou en cours, affecté) : le serveur lit les sessions de service de l'employé pour cette entreprise qui touchent la plage du créneau et calcule :
     - `couverture` = minutes en service dans la plage ÷ durée du créneau ;
     - `retard` = minutes entre le début du créneau et le début de la première session dans la plage (0 si déjà en service au début).
     Statut, dans cet ordre : « Absence prévue » (absence déclarée avant le début et couvrant le jour) ; « Absent » (couverture = 0) ; « Partiel » (couverture < 50 %) ; « En retard » (couverture ≥ 50 % et retard > `Config.Planning.LateToleranceMin = 10`) ; « Présent » (sinon). Créneau en cours : « En cours » avec la couverture déjà faite ; futur : « À venir ».
  2. **Mode jeu** : pour chaque occurrence du créneau (journée type) pendant la période choisie, **seulement pendant que l'employé était connecté** (table des connexions) : même calcul sur l'occurrence ; occurrences où il n'était pas connecté = ignorées. Résultat par employé : « {présent}/{occurrences connectées} occurrences en service ».
  3. Onglet « Présence » : période (Cette semaine / 4 dernières semaines ; mode jeu : 7 derniers jours réels), tableau employés : créneaux prévus, Présent, En retard, Partiel, Absent, Absence prévue, taux de présence = (Présent + En retard) ÷ (prévus − Absence prévue). Clic sur un employé → liste détaillée de ses créneaux avec statut, heure de prise et de fin de service.
  4. `planning:presence { companyId, period, identifier = nil }` → serveur : C3, C4 (3 / 10 s), droit (un joueur sans `planning.remplir` ne reçoit que lui-même).
- **Données** : calculées, non stockées (cache mémoire 5 min par créneau terminé) ; sources : sessions de service, connexions, absences, affectations.
- **Règles serveur** : calcul uniquement côté serveur à partir des sessions de service enregistrées par la base (le client n'envoie aucune heure) ; une session de service sans fin (en cours) compte jusqu'à maintenant ; une session coupée par une déconnexion se termine à l'heure de la déconnexion (règle de la base).
- **Textes et états** :
  - Statuts : `planning.presence.present` « Présent », `planning.presence.retard` « En retard ({n} min) », `planning.presence.partiel` « Partiel ({pct} %) », `planning.presence.absent` « Absent », `planning.presence.absence_prevue` « Absence prévue », `planning.presence.en_cours` « En cours », `planning.presence.a_venir` « À venir ».
  - Onglet : `planning.onglet.presence` « Présence », périodes `planning.periode.semaine` « Cette semaine », `planning.periode.4semaines` « 4 dernières semaines », `planning.periode.7jours` « 7 derniers jours ».
  - Colonnes : `planning.presence.prevus` « Prévus », `planning.presence.taux` « Taux de présence ».
  - Mode jeu : `planning.presence.occurrences` « {present}/{total} occurrences en service ».
  - Vide : `planning.presence.vide` « Aucun créneau terminé sur cette période. ».
- **Notifications** : aucune.
- **Liens** : Prise de service (base : sessions), PRO-PLA-05 (absences), branche Entreprises (fiche employé : le taux de présence 4 semaines y est repris).
- **Réglages** : `Config.Planning.LateToleranceMin = 10`, `Config.Planning.PartialBelowPct = 50`.
- **Journal admin** : non.
- **Performance** : calcul à la demande, sessions lues par une requête bornée à la période (index `(company_id, identifier, start_at)`) ; cache 5 min ; jamais de calcul en tâche de fond.
- **Cas limites** :
  - Employé en service sur deux sessions dans le même créneau (pause) → les minutes s'additionnent ; le retard se calcule sur la première.
  - Créneau qui passe minuit → calcul sur la plage complète des deux jours.
  - Employé retiré du créneau après sa fin → la ligne reste (affectation archivée avec le créneau, `name` figé).
- **Critères d'acceptation** :
  - Étant donné un créneau 14:00–18:00 et une prise de service à 14:25 jusqu'à 18:00, alors le statut est « En retard (25 min) ».
  - Étant donné aucune session pendant le créneau et aucune absence, alors « Absent ».
  - Étant donné un Membre avec un client modifié qui demande la présence de toute l'équipe, alors le serveur ne renvoie que la sienne.

---

## Décisions prises par défaut

1. **Données personnelles liées à la tablette** (C2, règle unique de BASE-OBJ-14) : notes, photos, favoris, historique, points de carte suivent le numéro de série ; perdues avec la tablette sauf remplacement par l'export `ReplaceTablet` (transfert, BASE-OBJ-08, appelé par la boutique du serveur) ; effacées par la réinitialisation.
2. **Gestion pro sans obligation de service** (C8) : Tableur, Stock et Planning s'utilisent hors service (`Config.Pro.RequireDuty = false`), car ce sont des outils de gestion ; le serveur peut l'imposer.
3. **Partage « à l'aveugle » entre joueurs proches** : la liste des joueurs proches affiche « Personne proche · 2,1 m » sans nom (`Config.Tools.ShowNearbyNames = false`) pour éviter le métagaming ; et le client ne reçoit jamais d'ID serveur, seulement un jeton à usage unique.
4. **Photos stockées sur le serveur du jeu par défaut** : capture demandée par le serveur (`screencapture` `serverCapture`), fichier sur le disque, images envoyées par événements latents en base64. Aucun hébergeur tiers, donc aucune IP de joueur exposée. Mode « hébergeur externe » optionnel, avec avertissement. Une photo partagée est une référence ; une photo envoyée en preuve est verrouillée à vie.
5. **Calculatrice** : 100 % locale, sans parenthèses, priorité × ÷ avant + −, 15 chiffres, 10 décimales, historique de 20 calculs dans le stockage local de la NUI.
6. **Adresses des sites** : `nom.rp` (extension réglable `Config.Sites.Suffix`), normalisées (majuscules, `https://`, `www.` tolérés) ; un mot seul tapé essaie `mot.rp` puis bascule sur la recherche ; sites cachés protégés par une limite de 10 adresses introuvables par minute.
7. **Tableur** : formules calculées **uniquement côté joueur** par un module JavaScript commun (le serveur stocke la saisie brute, une formule n'a aucun effet de jeu) ; séparateur d'arguments `;` ; fonctions françaises et anglaises acceptées ; pas de fonction imbriquée dans une autre ; une formule dont toutes les cellules sont vides affiche une cellule vide ; **insertion et suppression de lignes et de colonnes incluses** (PRO-TAB-15) : le serveur décale les cellules et réécrit les références des formules avec le même module de lecture des formules que la NUI (porté en Lua), en une transaction.
8. **Tableur, taille par défaut** : 200 lignes × 26 colonnes (A–Z), 20 feuilles par entreprise ; plafonds durs 1 000 lignes, 26 colonnes, 100 feuilles ; import « compte » relève automatiquement la feuille au niveau qui peut voir le compte.
9. **Stock** : quantité jamais négative en saisie manuelle ; la déduction par facture se fait **au paiement** et va jusqu'à 0 si le stock manque (la vente a eu lieu) avec alerte ; facture annulée = pas de retour automatique ; avec ox_inventory, un article lié au coffre prend la quantité du coffre et ses mouvements sont tracés par un crochet `swapItems` ; avec qs-inventory, lecture seule et écarts constatés.
10. **Planning** : mode **heure réelle par défaut**. Le mode « heure du jeu » utilise une **journée type** qui se répète à chaque journée du jeu, l'heure du jeu étant calculée par le serveur (référence envoyée par les clients, validée par 3 joueurs concordants, ou export d'un script d'heure), et la présence n'y est comptée que pendant les moments où l'employé était connecté. Rappels gérés par **au plus une minuterie ponctuelle** serveur, absente s'il n'y a aucun rappel à venir et sans minuterie quotidienne fixe (compatible « zéro boucle »). Présence : « Présent » si en service ≥ 50 % du créneau et retard ≤ 10 min.
11. **Droit ajouté** `planning.voir` (défaut Recrue) et `annuaire.fermer` (défaut Patron, fermeture temporaire forcée de l'entreprise dans l'annuaire) ; ces deux clés sont à ajouter à la grille de droits de la branche Entreprises.


> **Relecture croisée (24/11/2026)** : ce fichier a été aligné sur les 5 autres. Les noms communs (signaux, tables, réglages, droits, textes d'erreur, constantes) sont listés dans `00-sommaire.md`, qui fait foi en cas de doute.
