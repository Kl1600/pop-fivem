# PROGRESS

Journal court. À relire au début de chaque session, avec `feature_list.json` et `SPEC.md`.

## État
- Fonctions validées : 14 / 120 (dont ui-01 à ui-05, ui-17, arb-01, arb-02)
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

## Session 2 — 2026-11-22 (socle interface, ui-01 à ui-17)
Preuve commune (ui/pop-os) : `pnpm typecheck` OK ; `pnpm test` = 39 réussis / 0 échec (2 fichiers : kit.test.tsx, system.test.tsx) ; `pnpm build` OK vers web/dist ; `pnpm check` (check-imports + check-strings) OK ; `pnpm verify` = 27 fichiers, 23 JS, 395,7 Ko de JS, `node --check` OK sur chaque JS, 0 URL externe dans index.html. Captures Chrome headless (écran verrouillé clair et sombre) relues.
- **ui-01 OK** : Vite 8 + React 19 + TS + motion, pnpm + lockfile, base './', dist 395,7 Ko JS (<= 450), dist commité.
- **ui-02 OK** : `scripts/check-imports.mjs` (apps -> kit seul ; kit sans device/system/apps/nui ; device sans apps/system) + test vitest.
- **ui-03 OK** : kit (Glass, BlurLayer, Button, Switch, Slider, ListRow, Field, Sheet, SplitView, NavStack, TabBar, AppWaiting, VirtualList, AppIcon, hooks useT/useNui/useNotify/useLayout) rendus en regular et compact (vitest).
- **ui-04 OK** : `scripts/check-strings.mjs` = 0 chaîne en dur ; fr et en identiques en clés ; es/de/it/pt/nl/pl/tr/ar vides (repli anglais) ; dir=rtl pour l'arabe (vitest).
- **ui-05 OK** : thème clair/sombre, accent `Config.AccentColor` (liste blanche #hex), curseur de verre (0,12 + g*0,6), flou coupable, prefers-reduced-motion (CSS + MotionConfig) ; vitest + captures.
- **ui-17 OK** : VirtualList, 1000 éléments = au plus 60 lignes dans le DOM.
- **Restent false** : ui-06 (test en jeu, console NUI vide), ui-07 à ui-15 (code et tests vitest faits, mais « capture comparée à la maquette » impossible : `support.js` de la maquette absent de ui/pop-os/design, elle ne se rend pas ; seul le portage du code a été fait ; ui-09, 10, 13 demandent aussi un test en jeu), ui-16 (relevé de profil NUI en jeu).
- **Écarts SPEC** : `src/kit/` au lieu de `src/sdk/` (demande) ; écran de référence 1348x1019 mis à l'échelle (transform) au lieu de vh/vw ; flou : un backdrop-filter par couche surchargée (panneaux dans un centre/recherche à plat), mais plusieurs sur l'accueil (widgets, dock) ; Wi-Fi/Bluetooth/rotation/recopie gardés (section 0 prime sur 6.3) ; « + Ajouter un widget » et pastilles de page du centre de contrôle retirés (sans fonction) ; flou animé (filter) remplacé par un fond flouté en fondu d'opacité.
- **Contrat à compléter côté client/serveur** : `tablet:open` doit porter `lang` (écran verrouillé sans `boot`) et `shell` (absent = pas de coque) ; clés de `settings:save` à autoriser : lang, dark, glass, bright, wall, blur, air, wifi, bt, rot, mirror, share, focus ; `boot.widgets` ({events, reminders}) et `boot.music` à fournir ; `tablet:weather` {temp, kind, hi, lo, city} ; les textes de l'interface sont dans le bundle (la table Lua ne contient pas ces clés).

## Session 3 - 2026-11-22 (Système + API : contrat, Réglages, Boutique, API, arb-01/02)
Preuve commune : `lua tests/run.lua` = 284 réussis / 0 échec ; luacheck pop_tablet + templates = 0/0 sur 54 fichiers ; `luac -p` sur tous les .lua ; ui/pop-os : `pnpm typecheck` OK, `pnpm test` = 51 réussis (3 fichiers), `pnpm check` OK, `pnpm build` OK (dist JS 418,2 Ko), `pnpm verify` OK.
- **Contrat aligné** (SPEC 7.2, 7.3, 8 mis à jour) : `tablet:open` porte `lang`, `weather`, `shell` (seulement si `Config.Shell`) ; `settings:save` valide et stocke 17 clés ; `boot.widgets`, `boot.music`, `boot.apiApps`, informations de l'appareil ; `tablet:weather` {temp, kind, hi, lo, city}.
- **arb-01 OK** : vitest (Mode Avion et Wi-Fi coupé remplacent Boutique, Messages, Téléphone, Mail, Navigateur) + test Lua (`store:*` refusé `err_offline`, Réglages encore possibles, option `online` de la garde).
- **arb-02 OK (chemin serveur)** : `photos:capture` (faux `screencapture`) : photo enregistrée, 1 prise / 3 s, > 150 Ko rejetée, plafond `Config.Photos.Max`. Il reste à voir en jeu que la capture contient bien l'écran voulu.
- **Restent false** : app-set-01 et app-set-02 (code et vitest faits, pas de capture comparée à la maquette ni de test en jeu), app-sto-01, api-01 à api-05 (logique prouvée avec faux Bridge/DB, test en jeu avec une vraie ressource manquant), api-06 (`RegisterSite` et `MarketShock` non faits : Navigateur et Bourse pas construits), api-07 (aucun exemple d'appli API écrit).
- **À valider en jeu** : natives météo (`GetWeatherTypeTransition` renvoie bien 3 valeurs en Lua), iframe `nui://` d'une autre ressource, `SetNuiFocus`, usage de l'objet via pop_inventory (`onUse`), `screencapture` hors NUI.
- **Décisions** : voir SPEC section 15 bis (ids d'applis français, Notify tablette fermée = notification du jeu, `texts` par langue, rubriques de Réglages sans fonction retirées).

## Session 4 - 2026-11-22 (médias et personnel : Appareil photo, Photos, Notes, Fichiers)
Preuve commune : `lua tests/run.lua` = 356 réussis / 0 échec ; luacheck pop_tablet = 0/0 sur 39 fichiers ; `luac -p` sur client/ et server/apps/ ; `python -I tests/check_sql.py` = 20 tables, 26 index (SQLite, pas MariaDB) ; ui/pop-os : `pnpm typecheck` OK, `pnpm test` = 60 réussis (4 fichiers), `pnpm check` OK, `pnpm build` OK. `pnpm verify` ECHEC : 491,4 Ko de JS au total pour un plafond de 450 Ko (entrée 416,8 Ko, applis en morceaux chargés à la demande) ; plafond non modifié, à décider.
- **Serveur** : photos (capture avec format, liste paginée 30 + compteurs, get, favori, étoiles 0-5, filtre, vignette, albums, corbeille 30 jours, suppression définitive qui remet le fond d'écran en automatique), notes (blocs texte/liste à cocher/tableau/photo validés, dossiers <= 10, 200 notes, corbeille), fichiers (arbre, profondeur 6, 500 entrées, tags, favoris, déplacement sans cycle, jeton de partage de 12 caractères, ouverture d'un jeton), réglage `wall = 'photo:<id>'` (propriété vérifiée).
- **Client** : `client/camera.lua` (CreateMobilePhone + CellCamActivate, repli CreateCam, selfie, zoom scripté, orientation par glissement, arrêt à la fermeture et à l'arrêt de la ressource, aucune boucle) ; callback NUI `tablet:camera`.
- **Interface** : Appareil photo, Photos, Notes, Fichiers (maquettes portées, vitest) ; fond d'écran tiré d'une photo (Screen.tsx) ; recherche globale lit désormais `notes` du serveur.
- **Restent false** : app-cam-01, 02, 03, app-pho-01, app-not-01, app-fil-01, 02 (test en jeu, capture comparée à la maquette). app-cam-03 (mode remote) non codé.
- **Écarts SPEC** : tables photos/notes/fichiers étendues (albums, étoiles, filtre, corbeille, dossiers de notes, tag, favori) ; data/thumb en MEDIUMTEXT (oxmysql rend les BLOB en tableaux d'octets) ; vidéo, Personnes, Souvenirs, Collections, POP Drive, Dessin des notes et « Partager » de Photos non repris (sans fonction) ; vignettes produites par l'interface (canvas) puis enregistrées.
- **À valider en jeu** : CellCam avec `prop_cs_tablet`, repli scripté, orientation (SetGameplayCamRelativeHeading/Pitch), transparence NUI sur la vue du jeu, capture screencapture sans l'interface.

## Session 5 - 2026-11-22 (productivité : Calendrier, Rappels, Horloge, Calculette)
Preuve commune : `lua tests/run.lua` = 416 réussis / 0 échec ; luacheck pop_tablet + templates = 0/0 sur 60 fichiers ; ui/pop-os : `pnpm typecheck`, `pnpm check` (imports, chaînes), `pnpm test` = 71 réussis (5 fichiers), `pnpm build`, `pnpm verify` (entrée 418,0 Ko <= 450 Ko, total 558,4 Ko <= 2 Mo, 0 URL externe).
- **Plafond du bundle** : point d'entrée <= 450 Ko, total <= 2 Mo (décision du chef, SPEC 5, `scripts/verify-dist.mjs`).
- **Serveur** : `server/apps/calendar.lua` (<= 500 événements, plage <= 90 jours, alertes), `reminders.lua` (<= 20 listes, <= 200 rappels), `clock.lua` (<= 20 alarmes, <= 5 minuteurs <= 24 h, UNE échéance `Tablet.Scheduler`, réarmée au démarrage) ; requêtes SQL indexées dans `server/db.lua` ; limites dans `Tablet.Productivity`.
- **Échéances** : le client signale `pop_tablet:server:due(id, kind, date du jeu)` ; chaque gestionnaire revérifie propriété, activation, jour de répétition, heure (+2 min) ; une alerte ne sonne qu'une fois. Tablette fermée = notification du jeu (`Tablet.DueNotify`). Une seule minuterie client : l'interface réunit alarmes, alertes et rappels (`system/schedule.ts`) et relit les trois sources au déverrouillage.
- **Interface** : Calendrier (jour/semaine/mois/année, calendriers par couleur, détail, éditeur), Rappels (tuiles intelligentes, listes, signalement, ajout rapide), Horloge (cadrans, alarmes avec répétition, chronomètre, minuteur serveur avec pause = annulation + reste), Calculette (pile de parenthèses, scientifique, historique). Nouveau `ClockContext` dans `kit/`.
- **app-calc-01 OK** : vitest (7 × 6 = 42, division par zéro = Erreur, parenthèses, fonctions, historique). **Restent false** : app-cal-01/02, app-rem-01, app-hor-01/02/03 (logique serveur et interface prouvées par tests, mais capture comparée à la maquette et test en jeu impossibles ici).
- **Écarts SPEC** : pas de sous-tâches dans Rappels (aucune colonne) ; répétition d'alarme par jours (masque) en plus de la maquette ; Calendrier : le calendrier d'un événement = sa couleur (4 couleurs fixes) ; minuteur : la pause annule l'échéance serveur et la relance repart du reste ; alarmes et alertes ne sont armées qu'après une première ouverture/déverrouillage de la tablette depuis la connexion.
- **À signaler** : `client/device.lua` envoie `mo` de 1 à 12 alors que `ui/pop-os/src/system/clock.ts` (et le mock) traitent `mo` comme 0 à 11 (`Date.UTC`) : décalage d'un mois à corriger d'un côté. Dictaphone, Tableau et `share:*` : passage suivant.

## Session 6 - 2026-11-22 (Tableau, Dictaphone, partage de proximité, convention du mois)
Preuve commune : `lua tests/run.lua` = 448 réussis / 0 échec ; luacheck pop_tablet + templates = 0/0 sur 63 fichiers ; `luac -p` sur les .lua modifiés ; ui/pop-os : `pnpm typecheck`, `pnpm check`, `pnpm test` = 78 réussis (6 fichiers), `pnpm build`, `pnpm verify` (entrée 428,2 Ko <= 450 Ko, total 597,3 Ko).
- **Mois** : convention unique 1-12 (client envoie `GetClockMonth()+1`, l'interface soustrait 1 pour `Date.UTC`). Les docs locales ne donnent pas la plage du natif : le 0-11 reste à confirmer en jeu. Tests : lua (GameStamp `2026-06`) et vitest (30 novembre vers 1er décembre).
- **Serveur** : `board.lua` (<= 30 tableaux, JSON `{items, strokes}` validé, <= 128 Ko, <= 10 000 points), `dictaphone.lua` (audio par morceaux de 32 Ko, <= 120 s, <= 400 Ko, mémos dictés stockés `memo:<texte>`), `share.lua` (offres en mémoire 30 s, distance serveur à l'envoi et à l'acceptation via `Bridge.GetCoords`, copie chez le destinataire, réglage `share` respecté).
- **Client** : `tablet:micro` enregistre `granted`/`denied` (l'interface teste getUserMedia, aucun audio ne passe par Lua).
- **Interface** : Tableau (post-it, formes, texte, image factice, flèches, crayon, annuler, liste et vignettes, enregistrement différé 800 ms), Dictaphone (test du micro, enregistrement MediaRecorder si accordé, sinon mémo dicté + synthèse vocale), `NearbySheet` (kit) et `ShareOffer` (système), bouton « Partager à proximité » dans Fichiers (document, photo, tableau). Les sélecteurs Tableau et Dictaphone de Fichiers existaient : ils fonctionnent maintenant avec `board:list` et `rec:list`.
- **arb-04 passe à true** (vitest : choix du mode et écran dégradé rendu). **Restent false** : app-tab-01, app-dic-00, app-dic-01, app-fil-02 (test en jeu : micro CEF, rechargement fidèle, deux joueurs).
- **Écarts SPEC** : `pop_tablet_recordings.data` en MEDIUMTEXT (comme photos) ; `rec:get`, `rec:rename` ajoutés ; distance calculée avec `Bridge.GetCoords` (pas `IsNear`, pour ne pas dépendre de vector3 dans les tests). Test `system.test.tsx` (Mode avion) : l'appli d'attente citée en exemple est passée de `dictaphone` (construite) à `plans` (toujours en attente), la vérification est la même.
- **Pas fait** : partage depuis Notes et Photos (seul Fichiers et Tableau ont le bouton), partage d'un enregistrement (type absent de la SPEC), aperçu des tableaux et audios dans Fichiers, capture comparée aux maquettes.

## Session 7 - 2026-11-22 (Météo, Plans, Traduire, Bourse)
Preuve commune : `lua tests/run.lua` = 498 réussis / 0 échec ; luacheck pop_tablet + templates = 0/0 sur 70 fichiers ; `python -I tests/check_sql.py` = 21 tables ; ui/pop-os : `pnpm typecheck`, `pnpm check`, `pnpm test` = 92 réussis (7 fichiers), `pnpm build`, `pnpm verify` (entrée 443,9 Ko <= 450 Ko, total 686,5 Ko).
- **Météo** : `client/device.lua` ajoute vent (GetWindSpeed km/h, GetWindDirection cap) et pluie à `tablet:weather` ; l'interface dérive lieux (4 de la maquette), 12 heures, 10 jours, indices (UV, humidité, visibilité, pression) sans hasard (`apps/meteo/model.ts`) ; `WeatherContext` dans le kit.
- **Plans** : `shared/places.lua` + `Config.Places`, `server/apps/plans.lua` (état, favoris <= 12, récents <= 5, ids connus seulement), `client/map.lua` (`tablet:map` : position + rue/quartier, SetNewWaypoint + CalculateTravelDistanceBetweenPoints, SetWaypointOff, carte du menu pause avec focus rendu puis repris et point posé relu) ; carte stylisée SVG, 3 types, 3D, itinéraire en L.
- **Traduire** : dictionnaire embarqué 10 langues (26 phrases RP, 199 mots, mots composés) dans l'interface ; `server/apps/translate.lua` service HTTP optionnel (`Config.Translate.Url`, clé en convar, cache, limites, mode avion = err_offline) et favoris ; modes Texte, Conversation, Favoris.
- **Bourse** : `shared/market.lua`, `server/apps/stocks.lua` (marche aléatoire bornée [5 %, 10x], UNE échéance `Tablet.Scheduler` seulement avec abonné, push `{p = centimes}` <= 200 octets aux abonnés, persistance 10 min, export `MarketShock(symbole, %)` borné à 50 %), liste de suivi par tablette ; `pop_tablet_appdata` (nouvelle table) pour favoris et suivi.
- **app-bou-01 et arb-03 passent à true** (tests). **Restent false** : app-met-01, app-pla-01/02/03, app-tra-01, app-bou-02, app-bou-03, api-06 (RegisterSite non fait ; test en jeu pour MarketShock).
- **Écarts SPEC** : dictionnaire de 199 mots, pas 500 ; coordonnées des lieux et transformation monde -> carte stylisée approximatives ; test `tablet:map` de run.lua (réponse `err_unavailable` en attendant Plans) remplacé par les vrais contrats ; test Mode avion (system.test.tsx) : appli d'attente `plans` -> `musique`.
- **À valider en jeu** : natives de vent (cap, unités), PauseMenuceptionGoDeeper + ActivateFrontendMenu avec focus NUI, CalculateTravelDistanceBetweenPoints, resmon 0,00 ms sans abonné, paquets réseau, promesse + PerformHttpRequest du service.

## Session 8 - 2026-11-22 (Messages, Téléphone, Contacts)
Preuve commune : `lua tests/run.lua` = 537 réussis / 0 échec ; luacheck pop_tablet + templates = 0/0 ; `tests/check_sql.py` = 23 tables ; ui/pop-os : `pnpm typecheck && pnpm check && pnpm test` = 105 réussis (+13), `pnpm build`, `pnpm verify` : entrée 449,6 Ko (plafond 450, marge très faible).
- **Messages** : `server/apps/messages.lua` + `comm.lua` (conversations à deux et de groupe `g<id>`, texte, photo lue chez l'expéditeur, position donnée par le serveur, Lu/Distribué, non-lus + badge, épinglées en appdata, notification du jeu tablette fermée, garde `online`). UI `apps/messages` (chargée à la demande, `kit/comm.ts` partagé).
- **Téléphone** : `server/apps/phone.lua` (appel, sonnerie `Config.Phone.RingSeconds`, accepter/refuser/raccrocher, manqués, historique, messagerie vocale texte, pma-voice `setPlayerCall` canal `ChannelBase + id`). Fermer la tablette (`device:close`), perdre l'objet ou partir termine l'appel tout de suite ; contrôle de l'objet toutes les 20 s pendant l'appel seulement (filet). Sonnerie reçue : `actions.ts` ouvre le Téléphone (écran d'accueil) ou garde l'appli en attente (écran verrouillé).
- **Contacts** : `server/apps/contacts.lua` (adresse, notes, groupe en JSON dans `note`), partage de contact par `share:*` (kind `contact`). UI `apps/contacts`.
- **app-msg-01, app-tel-01, app-con-01 passent à true** (tests Lua et vitest). **Restent false** : app-msg-02 (contact en pièce jointe d'un message non fait, seul le partage de proximité existe), app-msg-03 (remise à la prochaine ouverture : badge et fils relus, pas de test de démarrage), app-tel-02 (voix pma-voice : à valider en jeu), app-tel-03 (sans pma-voice : aucune erreur claire, `setPlayerCall` ignoré sans message).
- **Écarts SPEC** : 2 tables de groupe ; mocks de l'interface chargés à la demande pour tenir le plafond du point d'entrée ; silence, haut-parleur et clavier de l'appel sont visuels (pas d'effet voix) ; pas de badge Téléphone.
- **À valider en jeu** : voix sur le canal, sonnerie en notification tablette fermée, capture comparée aux maquettes (non faite).

## Session 9 - 2026-11-22 (bundle, Mail)
Preuve : `lua tests/run.lua` = 560 réussis / 0 échec ; luacheck 0/0 ; check_sql OK ; ui/pop-os `pnpm typecheck && pnpm check && pnpm test` = 107 réussis, `pnpm build && pnpm verify` = entrée 334,8 Ko (plafond ramené à 380 Ko).
- **Bundle** : mocks (`nui/mock*`), `DevHost` (hors jeu seulement) et calques centres/recherche/multitâche (`system/OverlayLayer.tsx`, chargé à la première ouverture) sortis du point d'entrée par import dynamique : 449,6 -> 334,6 Ko.
- **Mail** : `server/apps/mail.lua` (boîtes Réception, Envoyés, Brouillons, Archive, Corbeille, vue Drapeau ; 300 mails, 5000 caractères ; push `mail` ou notification du jeu ; badge ; export `SendMail(to, subject, body, from?)`). `sql/update-mail-archive.sql` pour une base déjà installée. UI `apps/mail` (lecture, rédaction, répondre, transférer, drapeau, archive, corbeille).
- **app-mai-01 et app-mai-02 restent false** : test en jeu à deux joueurs requis (logique prouvée par tests Lua et vitest). Pas de dossiers personnalisés.
