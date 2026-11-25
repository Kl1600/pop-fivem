# POP Tablet : contexte commun pour écrire les fiches

À lire en entier avant d'écrire une fiche. Les fiches servent à Claude Code pour développer **sans poser de question** : rien ne doit être laissé au hasard.

## Le produit
- Tablette FiveM **à vendre** (Tebex, code chiffré par l'escrow Cfx), pour serveurs **RP sérieux**.
- Tablette **de travail multi-métiers**, pas un téléphone (pas d'appels, SMS, réseaux sociaux). Doit cohabiter avec n'importe quel téléphone.
- **Tout est dans la V1**, construit en arbre : 1 la base → 2 branches (Entreprises, Outils, Sites web, Apps perso, Admin) → 3 apps au bout (Métiers : police, EMS, mécano, justice, gang ; Gestion pro : tableur, stock, planning ; Navigateur + annuaire).
- **Clé en main par défaut** : prête en 5 minutes, entreprises courantes déjà créées et reliées aux métiers du framework (ESX, QBCore ou Qbox). Le créateur d'entreprises est optionnel (niveau 2).
- **Claude friendly** : cœur chiffré ; ouverts : config, langues, dossier « mes apps », guide pour l'IA, API documentée, kit de style, apps d'exemple.
- Framework : **ESX, QBCore et Qbox dès la sortie, au même niveau et testés à fond** (aucune version expérimentale) ; pas de mode standalone (sans framework, la ressource s'arrête avec un message console) ; tout passe par un adaptateur unique (bridge). Métiers, grades et comptes société : ESX (`jobs` / `job_grades`, `esx_addonaccount`), QBCore (`QBCore.Shared.Jobs`, `qb-banking` ou `qb-management`), Qbox (`qbx_core`, `Renewed-Banking` ou `qb-banking`), détectés automatiquement. Base : **oxmysql** obligatoire. Optionnels détectés : ox_lib, ox_inventory / qs-inventory, ox_target / qb-target, screencapture, pop_bank.
- Langues : **10 langues à la sortie** (recherche du 24/11/2026) : en, pt-BR, fr, ar, de, th, tr, es, id, ro. **L'arabe s'écrit de droite à gauche** : toute l'interface doit savoir s'inverser (RTL). Chaque texte affiché a une clé de langue. Dans les fiches, écrire le texte français exact entre guillemets ; la clé de langue est `app.ecran.element` (ex. `factures.liste.vide`).

## Performance (non négociable, esprit « ~0,00 ms »)
- Tablette fermée = **zéro** boucle, zéro thread actif côté client et serveur.
- Aucune boucle permanente : tout est déclenché par une action ou un événement.
- On charge seulement l'écran ouvert, avec pagination (20 éléments par page par défaut).
- Le serveur garde en cache ce qui est très lu (sites, code pénal, listes d'entreprises) et écrit en base par paquets quand c'est possible.
- Notifications : envoyées seulement aux joueurs concernés qui ont la tablette sur eux.

## Sécurité / anti-triche (non négociable)
- Le client ne décide **jamais** : montant, cible, droit, distance sont revérifiés par le serveur.
- Toute action d'argent : montant max réglable, joueur réellement proche si requis (distance par défaut 3 m), droit du grade, protection anti double clic (identifiant unique d'action, une facture ne se paie qu'une fois).
- Limite de fréquence par joueur sur chaque action (réglable).
- Tout texte écrit par un joueur est nettoyé avant affichage (aucun HTML/script exécutable), longueur max.
- Images : uniquement depuis une liste de domaines autorisés par le serveur, ou hébergées par le serveur.
- Actions sensibles enregistrées dans le **journal admin** (qui, quoi, quand, avant/après), envoyable sur Discord (lien gardé côté serveur).
- Rien n'est vraiment effacé quand c'est sensible (casier, factures, mouvements d'argent) : suppression = archivage visible par l'admin.

## Style visuel
- Sobre façon HUD GTA 6 : fond sombre uni, texte blanc, une seule couleur d'accent réglable, police système, pas de dégradé ni flou, fondu 150 ms.
- Navigation souris + clavier (Échap ferme / retour, Entrée valide).
- Messages d'erreur simples et courts, jamais de code technique.
- **Ton des textes : style Apple** : formulations neutres et courtes en priorité (« Facture envoyée. », « Code incorrect. », « Aucune facture. ») ; **vouvoiement** quand une adresse directe est nécessaire (« Vous n'avez pas les droits nécessaires. ») ; jamais de tutoiement.

## Les 6 états d'écran (chaque écran)
Vide (phrase + bouton pour commencer) · Chargement (formes grises, au-delà de 5 s message + « Réessayer ») · Succès (bandeau 2 s) · Erreur (message clair) · Pas le droit (caché ou grisé avec grade requis) · Hors service (apps métier : seul « Prendre mon service » actif).

## Droits par défaut
4 niveaux par entreprise, rattachés aux grades du framework (ESX, QBCore ou Qbox) (plus bas = Recrue, plus haut = Patron, intermédiaires répartis en Membre/Chef). Le patron change tout case par case.
| Action | Recrue | Membre | Chef | Patron |
|---|---|---|---|---|
| Prendre son service | Oui | Oui | Oui | Oui |
| Voir/prendre un appel | Oui | Oui | Oui | Oui |
| Faire une facture | Plafonnée | Oui | Oui | Oui |
| Répondre aux demandes | Non | Oui | Oui | Oui |
| Publier une annonce | Non | Non | Oui | Oui |
| Annonce à toute la ville | Non | Non | Non | Oui |
| Voir le compte | Non | Non | Oui | Oui |
| Déposer/retirer | Non | Non | Non | Oui |
| Recruter | Non | Non | Oui | Oui |
| Promouvoir/rétrograder/virer | Non | Non | Sous son grade | Oui |
| Grades, salaires, droits | Non | Non | Non | Oui |
| Modifier le site | Non | Non | Oui | Oui |
| Tableur/stock lire | Non | Oui | Oui | Oui |
| Tableur/stock modifier | Non | Non | Oui | Oui |
| Planning remplir | Non | Non | Oui | Oui |
| Police : amende, rapport, casier | Oui | Oui | Oui | Oui |
| Police : créer mandat | Non | Oui | Oui | Oui |
| Police : valider mandat, caméras | Non | Non | Oui | Oui |
| Police : retirer casier, code pénal | Non | Non | Non | Oui |
| EMS : lire dossier médical | Oui | Oui | Oui | Oui |
| Justice : verdict | Non | Non | Juge | Juge |
L'admin serveur (ACE `pop.tablet.admin`) peut tout ; ses actions sont journalisées.

## Liens entre apps (le serveur fait passer l'info)
Police amende → Factures · Police rapport/preuves → Justice affaire · Justice verdict → Casier · Juge → mandats police · Factures impayées → Police (option) · Mécano carnet d'entretien → propriétaire (app « Carnet auto ») et garages (fiche véhicule police seulement en option, désactivée par défaut) · Devis mécano accepté → Factures · EMS certificats → fiche citoyen police · Formulaire site / annuaire → Demandes · Factures payées → compte entreprise + part employé, → Stock (option), → Tableur (import) · Prise de service → annuaire (ouvert/fermé), dispatch, planning (présence) · Annonces → site, annuaire, toutes les tablettes · Galerie → rapports, preuves, annonces, sites · Scripts tiers → dispatch (alertes, y compris ceux écrits pour ps-dispatch, cd_dispatch ou core_dispatch via les adaptateurs `bridge/dispatch/`) · Juge → mandats signés → preuves recevables / irrecevables dans l'affaire · Mandat d'infiltration → lecture secrète de la messagerie d'un gang · Police et EMS → tri des blessés partagé · Agence immobilière → cadastre (propriétés lues par la police) · Toutes les apps → journal admin.

## Oublis corrigés (à respecter)
- Signaux API pour les autres scripts : « peine prononcée » (prison), « facture payée » (immobilier, garages…).
- Joueur **sans tablette** : devis, factures et amendes lui arrivent en fenêtre simple à l'écran (accepter / refuser / payer).
- Joueur inconscient : la facture attend son réveil.
- Salaires : le framework (ESX, QBCore ou Qbox) les verse ; la tablette règle seulement le salaire du grade dans le framework, ne paie jamais en double.
- Pas de boutique dans la tablette : la vente de la tablette et du chargeur (prix compris) est gérée par le script de boutique du serveur. La tablette fournit les objets à déclarer, la réinitialisation par l'admin (commande et panneau Admin) et les exports `ResetTablet(serial)` et `ReplaceTablet(source, oldSerial)` (transfert des données) que n'importe quel script (boutique, réparateur) peut appeler.
- Demandes : **une seule boîte « Demandes » par entreprise** (dépannage, rendez-vous, devis, contact).
- Caméra piéton : fonctionne seulement dans un rayon autour de l'agent (limite du jeu, distance réglable).
- **Aucune fonction ne pénalise les biens des joueurs** (décision du client, véhicules souvent payés en argent réel) : pas de détection ni d'alerte automatique « véhicule volé », pas de drapeau « volé », pas de blocage d'un bien ; la police enregistre seulement une plainte écrite à la main.
- **Messages de gang jamais effacés** (décision du client) : l'auteur peut retirer son message (archivé, visible par l'admin seulement).
- **Mort et réveil** : toujours détectés par le bridge (`Bridge.OnPlayerDeath` / `Bridge.OnPlayerRevived`) pour ESX, QBCore et Qbox, sans boucle.
- **Tout se passe dans la tablette** : les fonctions métier n'exigent aucun autre script ; les éléments dans le monde (ex. casier à preuves physique) sont optionnels et désactivés par défaut.
