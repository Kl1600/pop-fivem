# PROGRESS

Journal court. À relire au début de chaque session, avec `feature_list.json` et `SPEC.md`.

## État
- Fonctions validées : 6 / 120
- Prochaine fonction : socle-02
- Plafond de tours : 20 par session (par domaine : socle serveur, socle client, socle interface, puis applis)

## Ordre de construction
1. Socle serveur (`socle-*`) : copie de pop_base, manifeste, SQL, session, code, objet porté, API.
2. Socle client (`cli-*`) : ouverture, focus, touche, animation, locale, scheduler.
3. Socle interface (`ui-*`) : projet Vite, `sdk/`, système appareil.
4. Applis par domaine : communication (messages, téléphone, mail, contacts), personnel (notes, calendrier, rappels, fichiers, tableau), médias (photo, photos, musique, dictaphone), outils (horloge, calculette, météo, plans, traduire, bourse, navigateur, réglages, boutique).
5. API, performance, sécurité, langues, finition.

## Session 0 — 2026-11-22
- **Fait** : SPEC.md, feature_list.json, docs/api-applis.md, PROGRESS.md écrits par l'architecte (aucun code).
- **Preuve** : documents relus ; natives et exports cités vérifiés dans les docs locales (voir SPEC section 9, 16).
- **Commit** : aucun (demandé : pas de commit)
- **Pièges / décisions prises seul** : repli par propriétaire sans métadonnées ; Dictaphone dégradé si micro refusé ; Bluetooth/Wi-Fi/rotation retirés ; pas d'applis payantes ; Traduire masquée sans service.
- **Prochaine fonction** : socle-01

## Session 1 — 2026-11-22 (socle serveur, puis socle client)
- **Environnement** : `luac5.4` absent, `luac` = Lua 5.4.6 du PATH (`luac -p`) utilisé à la place. `luacheck resources templates` complet = 1529 avertissements hérités d'autres ressources (hors périmètre) : le contrôle porte sur `luacheck "resources/[pop]/pop_tablet" templates` = 0/0. Aucun serveur MySQL/MariaDB ni Docker actif sur le poste.
- `.luacheckrc` : ajout de la globale `Tablet` (espace de noms partagé), seul changement hors du dossier du script.
- Vérification bridge/shared : `diff -r` fichier par fichier (bridge/, shared/callback.lua, shared/locale.lua, web/kit/), car `shared/tablet.lua` est un ajout prévu par la SPEC.

### socle-01 — OK
- Preuve : diff bridge/shared/kit vide ; luacheck 0/0 sur 35 fichiers ; `luac -p` sur 17 fichiers sans erreur. Manifeste : oxmysql, `server/apps/*.lua`, `ui_page web/dist/index.html` (placeholder remplacé par le build de l'interface).

### Socle serveur : code écrit (server/*.lua, sql/install.sql, tests/) — commit groupé
Preuve commune : `lua tests/run.lua` = 134 réussis / 0 échec ; luacheck pop_tablet + templates = 0/0 sur 44 fichiers ; `luac -p` 26 fichiers sans erreur.
- **socle-02 : reste false.** `python -I tests/check_sql.py` : 17 tables, 23 index, FK et cascade OK, mais sous SQLite (conversion de dialecte). Aucun MariaDB/MySQL ni Docker sur le poste : l'exécution réelle de `install.sql` reste à faire. `server/db.lua` l'exécute au démarrage (`CREATE TABLE IF NOT EXISTS`).
- **socle-03 OK** : SHA-256 (vide, abc, 448 bits, 1 million de « a ») et HMAC RFC 4231 n°1, 2, 6 (clé > 64 octets) identiques ; 2000 itérations = 76 ms.
- **socle-04 OK** : 10 000 séries sans doublon, format `PT-[A-Z2-9]{10}`, collision forcée tirée à nouveau, numéros `###-####` avec 5 essais puis nil.
- **socle-07 OK** : `Tablet.Guard` refuse joueur inconnu, sans session, serial forgé, tablette verrouillée, session expirée, charge trop grande, objet perdu (+ `forceClose` poussé), joueur mort.
- **socle-12 OK** : charge/décharge sur durées simulées, plafond 100, plancher 0, batterie désactivée.
- **socle-13 OK** : chaque champ de la section 7.4 accepte N et rejette N+1 (ASCII et UTF-8), types, contrôle, enums, charges 16 Ko et 128 Ko, profondeur.
- **Restent false (partie « en jeu » non prouvable ici)** : socle-05 (conversion : logique prouvée avec faux inventaire, y compris retour arrière), socle-06 (mode repli codé, `D.Mode()`, message console), socle-08 (drop/arrêt prouvés avec faux Bridge ; commande `pop_tablet_sessions` sous `Config.Debug`), socle-09 (setup prouvé avec faux DB : haché, seconde config refusée ; reste le test sur vraie base), socle-10 (blocage 60 s puis x2 prouvé ; reste le message en jeu), socle-11 (idem), socle-14 (paquets < 1 Ko prouvés ; relevé en jeu à faire), socle-15 (scheduler prouvé avec faux `SetTimeout` ; minuteur 10 s en jeu), socle-16 (give prouvé avec faux Bridge ; ACE en jeu), socle-17 (`DB.Purge` écrit ; suppression réelle à voir sur base).
- **Décisions** : l'objet `pop_tablet` n'est pas ajouté à `pop_inventory` (la SPEC demande seulement de le documenter dans le README). Série du mode repli = dérivée de l'identifiant (SHA-256), sans stockage.

### Socle client (cli-01 à cli-09) : code écrit, tous restent false
Preuve commune : `lua tests/run.lua` = 186 réussis / 0 échec (faux natives, vrai code de `client/*.lua`) ; luacheck 0/0 sur 51 fichiers ; `luac -p` 33 fichiers.
Prouvé hors jeu : aucun thread ni boucle au chargement ; `RegisterKeyMapping('pop_tablet_toggle', texte traduit, 'keyboard', 'F5')` ; ouverture (focus true/true, `tablet:open` avec locale, rtl, accent, horloge) ; touche sans objet silencieuse ; relais `tablet:call` : liste blanche, `device:open`/`device:close`/noms inconnus/charge > 128 Ko rejetés, tablette fermée refusée ; fermeture (focus rendu, objet supprimé, serveur prévenu, double fermeture sans effet) ; mort (handler `gameEventTriggered` posé seulement pendant l'ouverture), `forceClose`, arrêt de la ressource ; resynchronisation 60 s en chaîne de `SetTimeout` coupée à la sortie ; scheduler client (délai en ms réelles, minuit, minute entamée, minuterie périmée sans effet, une seule minuterie).
- cli-01, 02, 03, 05, 06, 08, 09 : le test « en jeu » (touche, resmon 0,00 ms, prop/animation, restart pendant l'usage, objet retiré) reste à faire. cli-04 : RTL en jeu et vitest (interface) restent à faire. cli-07 : délai prouvé, alarme à +2 min jeu à voir en jeu.
- Valeurs à valider en jeu : `Config.Prop`, `Config.Anim`, `GetClockMonth` (supposé 0-11), `SetNuiFocus` (absente des docs locales, utilisée par le bridge).
- Fichiers client ajoutés par rapport à la SPEC : `client/anim.lua` (animation + objet, séparé de main.lua).

### Points de la SPEC à corriger ou décider
1. `luacheck resources templates` complet ne peut pas valoir 0/0 (1529 avertissements d'autres ressources) : la commande de contrôle doit viser `resources/[pop]/pop_tablet`.
2. Contrat NUI complété : `tablet:open` porte aussi `serial`, `needSetup`, `locked`, `app` ; ajout du message `tablet:openApp` (appli demandée alors que la tablette est déjà ouverte) et du callback `tablet:locale { lang }` ; callback serveur interne `pop_tablet:app:open` pour l'export client `OpenApp`.
3. Objet perdu : sans surveillance continue, la fermeture n'a lieu qu'au prochain appel serveur ; un événement d'inventaire (hook par inventaire) serait nécessaire pour fermer aussitôt (à décider).
4. `diff -r` de `shared/` ne peut pas être vide (ajout de `shared/tablet.lua`) : comparer fichier par fichier.
5. feature_list.json compte 120 entrées (PROGRESS annonçait 116).
6. Item `pop_tablet` non ajouté à `pop_inventory` (README seulement), à décider.
