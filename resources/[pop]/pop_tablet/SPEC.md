# pop_tablet : cahier des charges

Version du 22/11/2026. Branche `feat/pop-tablet`. Source des décisions : `DECISIONS.md` (prime sur tout le reste).
Maquettes de référence : `ui/pop-os/design/*.dc.html` (hors déploiement). Liste des fonctions à valider : `feature_list.json`. Journal : `PROGRESS.md`. API d'applis : `docs/api-applis.md`.

## 0. Arbitrages du chef de projet (priment sur les sections suivantes)

- **Centre de contrôle complet, comme la maquette** : Wi-Fi, Bluetooth, verrouillage de rotation, recopie et enregistrement
  restent visibles. Mode Avion = réel (coupe SMS, appels, mails, Navigateur et Boutique de cette tablette). Wi-Fi coupé = même
  effet réseau que Mode Avion pour les services en ligne. Bluetooth, rotation, recopie : état mémorisé, effet visuel seulement.
  Enregistrement d'écran : capture une photo de l'écran vers Photos (même chemin que l'Appareil photo).
- **Traduire hors ligne par défaut** : dictionnaire embarqué (phrases RP courantes et ~500 mots usuels) dans les 10 langues,
  traduction mot à mot avec les phrases connues en priorité. Le service HTTP configurable reste une option. L'appli n'est jamais masquée.
- **Dictaphone toujours visible** : test du micro NUI au premier usage ; si refusé, mode « mémo dicté » (saisie texte horodatée
  + lecture par synthèse vocale du navigateur si disponible). `Config.Apps.dictaphone` vaut `'on'` par défaut.
- **Appareil photo** : d'abord les natives `CellCam*` ; si le modèle de téléphone gêne, caméra scriptée native (`CreateCam`)
  à la position de la tablette. Le choix se fait au test en jeu, les deux chemins sont codés derrière `Config.Camera.mode`.
- **Lint** : si `luac5.4` manque, utiliser `luac` 5.4 du PATH ou `lua -e "loadfile(...)"` en 5.4 ; le noter dans PROGRESS.md.

## 1. Objectif

Une tablette « POP Tab » (système « POP OS ») utilisable en jeu : plein écran, paysage, thème clair/sombre, style verre liquide, sans aucun élément d'Apple.
La tablette est un **objet d'inventaire**. Ses données (code, réglages, notes, photos, messages...) sont liées à l'objet, pas au joueur : une tablette volée garde ses données, il faut son code.
22 applis fonctionnent vraiment. Une API laisse d'autres ressources ajouter leurs applis.

## 2. Règles (non négociables)

1. ESX, QBCore, Qbox, standalone via `Bridge.*` (pop_base). Jamais de modification de `bridge/`, `shared/`, `web/kit/`.
2. 10 langues : en, fr, es, de, it, pt, nl, pl, tr, ar (RTL). Aucun texte en dur, Lua et interface. Le serveur envoie des **clés** (`key` + `args`), l'interface traduit.
3. Le serveur vérifie tout : objet porté, code, propriétaire, anti-spam, tailles, distance. Aucune valeur de confiance venant du client.
4. Performance : 0,00 ms au repos, client et serveur (voir section 11).
5. Hiérarchie : natif GTA/FiveM, puis existant (pop_base, oxmysql, pma-voice, screencapture), puis construire.
6. Jamais de build sur le VPS : `web/dist/` est construit sur le poste/CI et **versionné**.
7. Aucune clé, mot de passe ou jeton dans le dépôt. Les secrets sont des convars `set` (jamais `setr`).
8. Aucun nom, icône, police ni fond d'Apple. Police : Inter ou police système (à embarquer dans `dist`, pas de CDN : les maquettes chargent Google Fonts, à remplacer).
9. Branche `feat/pop-tablet` ; aucun push sur `main`, aucun déploiement.

## 3. Hors périmètre V1

- Applis métier (police, EMS, etc.) : viendront via l'API (`docs/api-applis.md`).
- Le téléphone POP (futur) : seulement préparé par la séparation système/applis et la mise en page `compact`.
- Achat/vente d'actions et toute opération d'argent (Bourse = suivi et marché simulé, aucun `Bridge.AddMoney`/`RemoveMoney`).
- Achat d'applis payantes dans la Boutique (la Boutique installe/retire des applis gratuites ; prix : hors V1).
- Écran en rotation (paysage seulement), FaceTime/visio, AirDrop réel (remplacé par le partage de proximité de la section 9).
- Projet Pulse : aucun rapport.

## 4. Arborescence

Départ : `cp -r templates/pop_base "resources/[pop]/pop_tablet"` puis renommer (voir README de pop_base). Le `README.md` de base est réécrit.

```
resources/[pop]/pop_tablet/
  fxmanifest.lua        name 'pop_tablet', @oxmysql/lib/MySQL.lua, ui_page 'web/dist/index.html',
                        server_scripts + 'server/*.lua' + 'server/apps/*.lua' (le glob de base ne descend pas),
                        files { 'web/dist/**' }, dependency 'oxmysql'
  config.lua            clés communes de pop_base + clés Tablet (section 12)
  README.md  SPEC.md  DECISIONS.md  PROGRESS.md  feature_list.json
  bridge/ client.lua server.lua            copiés tels quels
  shared/ callback.lua locale.lua          copiés tels quels
          tablet.lua                        constantes partagées : liste des applis natives, limites (tailles max), noms d'events
          places.lua                        lieux de Plans (nom = clé de locale, coords, catégorie)
  client/ main.lua        ouverture/fermeture, focus NUI, touche, animation + prop, clavier
          nui.lua           tous les RegisterNUICallback (proxy vers le serveur ou les natives)
          device.lua        horloge/date du jeu, météo, position, luminosité plein écran
          camera.lua        CreateMobilePhone, CellCam, capture
          map.lua           Plans : waypoint, carte du menu pause
          scheduler.lua     une seule minuterie pour la prochaine alarme/rappel/événement (SetTimeout)
          locale.lua        TabletLocaleTable(lang) : en + langue de la tablette
          api.lua           exports client
  server/ main.lua        démarrage, joueurs, nettoyage
          device.lua        numéro de série, sessions, code, objet porté
          db.lua            toutes les requêtes oxmysql
          hash.lua          SHA-256 pur Lua + HMAC (code)
          limits.lua        tailles max, validations
          push.lua          envoi des events vers les clients
          scheduler.lua     prochaine échéance côté serveur (SetTimeout), pas de boucle
          api.lua           exports serveur (RegisterApp, Notify, OpenApp)
          apps/ settings.lua store.lua photos.lua notes.lua calendar.lua reminders.lua files.lua board.lua
                clock.lua maps.lua dictaphone.lua translate.lua stocks.lua messages.lua phone.lua
                mail.lua contacts.lua browser.lua music.lua share.lua
  sql/install.sql
  locales/ en.lua fr.lua es.lua de.lua it.lua pt.lua nl.lua pl.lua tr.lua ar.lua
  web/ dist/              interface construite (versionnée) : index.html, assets/*.js, *.css, polices, sons
       kit/               copié tel quel (non chargé par la page React, voir section 6.4)
  tests/ run.lua          tests Lua purs (hash, validations, marché, numéros) : lua tests/run.lua
```

Source de l'interface, hors déploiement : `ui/pop-os/` (voir section 6).

## 5. Données : `sql/install.sql`

Moteur InnoDB, utf8mb4. Toutes les tables portent `serial` (série de la tablette). `ON DELETE CASCADE` depuis `pop_tablet_devices`. Les identifiants sont des `BIGINT UNSIGNED AUTO_INCREMENT`. Les dates sont des `BIGINT` (epoch secondes serveur) sauf `game_*` (date du jeu, texte `AAAA-MM-JJ HH:MM`).

### 5.1 Lien objet <-> données

- Item `Config.Item = 'pop_tablet'`. Chaque tablette porte en **métadonnée** `serial = 'PT-' .. 10 caractères [A-Z2-9]` (aléatoire serveur, unique, vérifié en base).
- `Bridge.SupportsMetadata()` = true : le serial est lu via `Bridge.GetItems(src, 'pop_tablet')[i].metadata.serial`. Un objet sans serial (donné par un admin/boutique) est converti à la première utilisation : `RemoveItem(slot)` puis `AddItem` avec le serial, sous verrou par joueur (échec : rien n'est créé en base).
- `Bridge.SupportsMetadata()` = false (inventaire ESX de base, standalone, none) : **repli par propriétaire**. Le serial est dérivé du propriétaire (`Bridge.GetIdentifier`), une tablette par personnage, les données suivent le personnage et non l'objet. Limite connue : une tablette volée ne garde pas ses données dans ce mode. Le mode est annoncé dans la console au démarrage.
- Commande admin `/pop_tablet_give [id]` (`Bridge.IsAdmin`) : crée l'objet avec serial. L'objet doit aussi exister dans l'inventaire du serveur (item `pop_tablet`, à ajouter à `items.lua` ou équivalent : documenté dans le README).

### 5.2 Tables

| Table | Colonnes principales |
|---|---|
| `pop_tablet_devices` | `serial` PK, `phone` CHAR(8) UNIQUE (numéro), `code_hash` CHAR(64) NULL, `code_salt` CHAR(16), `fails` TINYINT, `locked_until` BIGINT, `name` VARCHAR(32), `settings` JSON (lang, dark, wallpaper, glass 0-100, brightness, volume, ringtone, dock, home layout, widgets, focus, mail address, weather city, world clocks, stocks watchlist), `apps` JSON (ids installés), `battery` TINYINT, `battery_at` BIGINT, `owner_hint` VARCHAR(64) (identifiant du créateur, mode repli), `created_at`, `last_open_at` |
| `pop_tablet_notes` | id, serial, title(80), body(TEXT <= 10 000), pinned, updated_at |
| `pop_tablet_events` | id, serial, title(80), place(80), notes(500), start_game, end_game, all_day, alert_min, color, notified |
| `pop_tablet_reminders` | id, serial, list_id, title(120), done, due_game NULL, flag |
| `pop_tablet_reminder_lists` | id, serial, name(40), color |
| `pop_tablet_files` | id, serial, parent_id NULL, kind ENUM('folder','doc','photo','audio','board'), name(80), body(TEXT <= 20 000) NULL, ref_id NULL (photo/audio/board), size, share_token CHAR(12) NULL UNIQUE, updated_at |
| `pop_tablet_boards` | id, serial, title(80), strokes(MEDIUMTEXT <= 131 072 octets, points quantifiés), updated_at |
| `pop_tablet_photos` | id, serial, url VARCHAR(255) NULL, data MEDIUMBLOB NULL (repli base, webp <= 150 Ko), w, h, place VARCHAR(80), taken_at, favorite |
| `pop_tablet_recordings` | id, serial, title(80), seconds, url VARCHAR(255) NULL, data MEDIUMBLOB NULL (<= 400 Ko), created_at |
| `pop_tablet_messages` | id, from_phone, to_phone, body(TEXT <= 1000), kind ENUM('text','photo','contact','location'), ref VARCHAR(255) NULL, sent_at, read_at NULL ; index (to_phone, read_at), (from_phone, to_phone, id) ; une ligne par message, lecture par les deux numéros |
| `pop_tablet_calls` | id, from_phone, to_phone, started_at, answered_at NULL, ended_at NULL, status ENUM('missed','answered','declined','busy') |
| `pop_tablet_mails` | id, serial, folder ENUM('inbox','sent','trash','draft','flagged'), from_addr, to_addr, subject(120), body(TEXT <= 5000), read_at NULL, flagged, created_at |
| `pop_tablet_contacts` | id, serial, name(60), phone(16), mail(80) NULL, note(200) NULL, favorite |
| `pop_tablet_alarms` | id, serial, kind ENUM('alarm','timer'), label(40), game_minute SMALLINT NULL (0-1439), repeat_mask TINYINT, ends_at BIGINT NULL (minuteur, epoch serveur), enabled, sound |
| `pop_tablet_market` | symbol VARCHAR(8) PK, price DECIMAL(12,2), prev_close DECIMAL(12,2), trend FLOAT, updated_at (état persisté seulement toutes les 10 min et à l'arrêt) |
| `pop_tablet_sites` | domain VARCHAR(60) PK, title, owner_resource, page VARCHAR(120) (page NUI interne `pop://domaine`) : sites créés par d'autres ressources via l'API ; peut rester vide |
| `pop_tablet_mailboxes` | address VARCHAR(80) PK, serial UNIQUE : adresses uniques `<nom>@<Config.Mail.Domain>` |

Contraintes : numéro de téléphone `Config.Phone.Format` (défaut `###-####` chiffres, génération aléatoire avec 5 essais, échec = erreur claire), unique par tablette. Aucun montant d'argent en base. Nettoyage : `DELETE` des messages/appels plus vieux que `Config.Retention.Days` à chaque démarrage seulement (pas de boucle).

## 6. Interface : `ui/pop-os/`

### 6.1 Pile et sortie

Vite + React + TypeScript + `motion` (animations). Sortie : `resources/[pop]/pop_tablet/web/dist/` (`build.outDir`, `base: './'`). `dist` est versionné ; aucun build au déploiement.
`ui/pop-os/package.json` : scripts `dev`, `build`, `typecheck` (`tsc --noEmit`), `test` (vitest). Gestionnaire : pnpm + lockfile.
Dépendances minimales : react, react-dom, motion. Pas de bibliothèque de composants, pas de CDN, pas de requête réseau au chargement. Bundle visé : `dist` JS total <= 450 Ko non compressé hors polices (mesuré par la commande de build, voir feature `perf-bundle`).

### 6.2 Séparation système appareil / applis (obligatoire)

```
ui/pop-os/src/
  device/    système appareil : verrouillage, code, écran d'accueil, dock, centre de notifications, centre de
             contrôle, recherche, sélecteur d'applis, barre d'état, boutons matériels, fonds d'écran, thèmes, verre
  sdk/       contrat appareil <-> applis : AppProps, hooks useLayout, useT, useNui, useNotify, composants communs
             (barre de navigation, liste, bouton, champ, feuille)
  apps/<id>/ une appli = un dossier (index.tsx + composants + tests). Aucune importation depuis device/ ;
             seulement depuis sdk/. Une appli reçoit { layout: 'regular' | 'compact', dark, t, nui, close }.
  registry.ts  liste des applis natives + applis API (RegisterApp) : { id, nameKey, icon, domain }
  i18n/      lecture de la table de textes (clés) envoyée par le client
  nui/       post/on typés (voir section 8)
```

`layout` : `regular` = paysage tablette (1348 x 1019 de référence, ajustable au ratio de l'écran), `compact` = portrait téléphone. Chaque appli fournit les deux ; seule `regular` est montée en V1, `compact` est testée (vitest, rendu sans erreur) pour le futur téléphone. Un futur `pop_phone` réutilise `apps/` et `sdk/` en remplaçant `device/`.
L'interface s'adapte à la résolution via `vh/vw` et `clamp` (pas de valeurs pixel figées de 1348 px).

### 6.3 Système appareil (écrans)

Verrouillage (heure, date, widgets, notifications) ; saisie du code 4 chiffres (secousse si faux, compteur de blocage) ; premier allumage (langue, choix du code, nom de l'appareil, adresse mail) ; accueil (grille paginée, dossiers non requis, dock, widgets, mode édition) ; barre d'état (heure du jeu, batterie, signal fictif **interdit** : afficher seulement ce qui est réel) ; centre de notifications ; centre de contrôle (luminosité, volume, mode sombre, concentration, minuteur, calculette, appareil photo, notes rapides, lecteur Musique, partage de proximité) ; recherche (applis, contacts, notes) ; sélecteur d'applis ; bouton du haut (verrouille), volume +/-. Bannière de notification.
Éléments des maquettes **sans fonction réelle** à retirer ou à rendre réels : rotation, recopie d'écran, Bluetooth/Wi-Fi/données (retirés en V1 ; `Partage à proximité` reste, section 9), « Enregistrement » d'écran (retiré).

### 6.4 Page, kit et bridge

La page est `web/dist/index.html` : elle ne charge **pas** `web/kit/pop.js` (non modifiable, pensé pour un HUD). L'interface implémente elle-même, avec les mêmes noms : appel `pop:ready` au démarrage, `close` (le bridge rend le focus et appelle `Bridge.OnUiClose`). Les messages `pop:prompt`, `pop:progress`, `pop:notify`, `pop:locale` du kit sont ignorés proprement par la page. La table de textes vient de `client/locale.lua` (langue de la tablette), pas de `pop:ready` (qui ne renvoie que `Config.Locale`).
`.luacheckrc` : les globales du script sont ajoutées dans `.luacheckrc` du dépôt seulement si nécessaire (sinon `-- luacheck: globals`).

### 6.5 Style

Verre liquide : `backdrop-filter` flou/saturation, reflets internes, coins arrondis. **Contredit** `docs/direction-artistique.md` (« pas de glassmorphism ») : DECISIONS.md prévaut pour cette appli, la règle sobre reste valable pour les autres scripts. Accent par défaut `Config.AccentColor` (#ff2e88). Animations `motion` courtes ; `prefers-reduced-motion` respecté ; flou désactivable (réglage « Transparence ») pour les PC faibles.
Performance NUI : une seule couche `backdrop-filter` par plan visible ; pas d'animation continue quand l'écran est éteint (démonter) ; `React.memo` sur les listes ; listes virtualisées au-delà de 100 éléments.

## 7. Contrat client <-> serveur

Convention : callbacks `pop_tablet:<domaine>:<action>` (module `Callback`, anti-spam `Config.CallbackRateLimit` par joueur et par callback ; limites plus basses par callback ci-dessous quand utile). Events serveur -> client `pop_tablet:client:<nom>`. Events client -> serveur : uniquement pour l'alarme (`pop_tablet:server:due`, avec limite) ; tout le reste passe par callback.
Réponse standard : `{ ok = true, ... }` ou `{ ok = false, err = 'cle_locale' }`. Les erreurs sont des **clés** de locale.

### 7.1 Contrôles communs (fonction `Tablet.Guard(src, serial, opts)` côté serveur)

À **chaque** appel (pas de cache de confiance) :
1. `src` est un joueur chargé (`Bridge.GetPlayer`), vivant sauf `opts.allowDead` (`Bridge.IsDead`).
2. L'objet est porté : `Bridge.GetItems(src, Config.Item)` contient une pile dont `metadata.serial == serial` (mode repli : serial dérivé du propriétaire et `Bridge.HasItem(src, Config.Item)`).
3. La session de `src` existe pour ce serial, est **déverrouillée** (sauf `opts.public` pour `device:unlock`, `device:setup`) et n'a pas expiré (`Config.Session.IdleLockSeconds`, contrôle à l'appel, pas de minuterie).
4. Charge utile : types, longueurs maximales (section 7.4), énumérations connues, `tonumber` + bornes sur tout nombre. Le serial vient du serveur (session), jamais d'un argument client.
5. Propriété : toute ligne lue/modifiée/supprimée a `serial = session.serial` dans la clause `WHERE`.
6. Distance : actions de partage uniquement (`Bridge.IsNear`).
7. Journal de refus : `Config.Debug` seulement.

### 7.2 Callbacks (client -> serveur), tous passent par `Tablet.Guard`

| Callback | Arguments | Retour / effet | Contrôles propres |
|---|---|---|---|
| `pop_tablet:device:open` | `serial?` | `{ ok, serial, needSetup, locked, boot }` ; crée la session ; `boot` = réglages, applis, batterie, badges (non lus) | objet porté (étape 2) ; si plusieurs tablettes : `serial` doit être celui d'une pile portée, sinon la première ; batterie > `Config.Battery.MinToOpen` |
| `pop_tablet:device:close` | | `{ ok }` ; enregistre la batterie | |
| `pop_tablet:device:setup` | `{ code, name, lang, mail }` | crée le code haché, le nom, l'adresse mail | une seule fois (`code_hash` NULL) ; code `^%d%d%d%d$` ; adresse valide et libre |
| `pop_tablet:device:unlock` | `code` | `{ ok, boot }` ou `{ ok=false, err, wait }` | 5 échecs -> blocage 60 s, puis x2 (max 1 h) ; comparaison à temps constant ; `Config.CallbackRateLimit` 2 |
| `pop_tablet:device:changeCode` | `old, new` | `{ ok }` | ancien code vérifié ; mêmes limites que le déverrouillage |
| `pop_tablet:device:lock` | | verrouille la session | |
| `pop_tablet:settings:save` | `patch` (clés blanches uniquement) | `{ ok }` | taille <= 4 Ko ; valeurs énumérées (langue parmi les 10, fond parmi la liste) |
| `pop_tablet:settings:rename` | `name` | | <= 32 caractères |
| `pop_tablet:store:list` | | catalogue : natives + applis API visibles par job (`Bridge.HasJob`) | |
| `pop_tablet:store:install` / `:remove` | `appId` | met à jour `apps` | id connu, appli système non retirable, job autorisé |
| `pop_tablet:notes:list` / `:save` / `:delete` | `{ id?, title, body, pinned }` / `id` | liste (titres + extrait 120 car.) ; `:get` renvoie le corps | <= 200 notes, corps <= 10 000 |
| `pop_tablet:calendar:list` | `{ from, to }` (dates jeu) | événements de la plage (<= 90 jours) | |
| `pop_tablet:calendar:save` / `:delete` | | | <= 500 événements |
| `pop_tablet:reminders:list` / `:save` / `:delete` / `:toggle` / `:listSave` | | | <= 20 listes, 200 rappels |
| `pop_tablet:files:list` / `:save` / `:delete` / `:move` / `:share` / `:open` | `parentId` / ... | `:share` crée `share_token` ; `:open` ouvre un jeton reçu | <= 500 entrées ; profondeur <= 6 |
| `pop_tablet:board:list` / `:get` / `:save` / `:delete` | `{ id?, title, strokes }` | | `strokes` <= 128 Ko, <= 10 000 points, <= 30 tableaux |
| `pop_tablet:clock:list` / `:saveAlarm` / `:deleteAlarm` / `:startTimer` / `:cancelTimer` | | alarmes, minuteurs ; recalcule la prochaine échéance | <= 20 alarmes, <= 5 minuteurs |
| `pop_tablet:photos:capture` | | prend la capture côté serveur (section 9), `{ ok, photo }` | 1 / 3 s ; <= `Config.Photos.Max` photos ; joueur sans menu pause/en vol |
| `pop_tablet:photos:list` | `{ offset }` | 30 miniatures-ids par page | |
| `pop_tablet:photos:get` | `id` | une photo (url ou base64) | |
| `pop_tablet:photos:delete` / `:favorite` | `id` | | |
| `pop_tablet:rec:save` | `{ title, seconds, chunks }` | voir Dictaphone | durée <= 120 s, <= 400 Ko |
| `pop_tablet:rec:list` / `:delete` | | | |
| `pop_tablet:messages:threads` | | liste des conversations (dernier message + non lus) | |
| `pop_tablet:messages:thread` | `{ phone, before? }` | 30 messages | |
| `pop_tablet:messages:send` | `{ to, body, kind?, ref? }` | `{ ok, msg }` ; pousse au destinataire s'il porte la tablette | numéro existe ; corps <= 1000 ; 1 msg/s ; `kind` photo : l'id appartient à l'expéditeur |
| `pop_tablet:messages:read` | `{ phone }` | marque lu | |
| `pop_tablet:phone:call` | `{ to }` | `{ ok, callId }` | numéro existant ; destinataire porte la tablette ; ni occupé ni soi-même ; 1 appel / 5 s |
| `pop_tablet:phone:answer` / `:decline` / `:hangup` | `callId` | | l'appel existe et `src` en est un participant |
| `pop_tablet:phone:history` | | 50 derniers appels | |
| `pop_tablet:mail:folders` / `:list` / `:get` / `:send` / `:move` / `:flag` / `:delete` | | | adresse destinataire existante ; objet <= 120, corps <= 5000 ; 1 envoi / 3 s ; <= 300 mails par boîte |
| `pop_tablet:contacts:list` / `:save` / `:delete` | | | <= 300 ; numéro `Config.Phone.Format` |
| `pop_tablet:browser:sites` | | sites en jeu + favoris | |
| `pop_tablet:music:stations` | | stations de `Config.Music.Stations` | |
| `pop_tablet:translate:run` | `{ text, from, to }` | `{ ok, text }` | <= 500 car. ; langues parmi les 10 ; 1 / 2 s ; cache mémoire 200 entrées |
| `pop_tablet:stocks:subscribe` / `:unsubscribe` | | `subscribe` renvoie l'instantané complet (<= 16 symboles) | |
| `pop_tablet:stocks:watch` | `{ symbol, on }` | liste de suivi dans les réglages | symbole connu |
| `pop_tablet:share:nearby` | | `{ { id, name } }` joueurs < `Config.Share.Distance` portant une tablette (nom d'appareil, jamais le nom du personnage) | |
| `pop_tablet:share:send` | `{ target, kind, id }` | offre envoyée | `Bridge.IsNear` des deux côtés ; ressource de l'expéditeur ; 1 / 5 s |
| `pop_tablet:share:accept` / `:refuse` | `offerId` | copie la ressource chez le destinataire | l'offre existe, n'a pas expiré (30 s), même couple src ; distance revérifiée |
| `pop_tablet:app:call` | `{ appId, action, data }` | route vers le gestionnaire enregistré par `RegisterApp` | appli installée ; job ; <= 4 Ko |

Callbacks serveur -> client (`Callback.Await` côté serveur) : `pop_tablet:client:ping` (le client confirme que la tablette est ouverte/fermée) seulement si nécessaire pour la Bourse ; sinon aucun.

### 7.3 Events serveur -> client (push, aucun polling)

| Event | Arguments | Quand |
|---|---|---|
| `pop_tablet:client:notify` | `{ app, titleKey, bodyKey, args, text?, sound? }` | message reçu, alarme, rappel, mail, appel manqué, `Notify` de l'API |
| `pop_tablet:client:message` | `{ msg }` | SMS reçu pendant que la tablette est ouverte |
| `pop_tablet:client:mail` | `{ mail }` | mail reçu |
| `pop_tablet:client:call` | `{ callId, state, number, name? }` ; `state` = `ringing`, `connected`, `ended` | appel entrant / état |
| `pop_tablet:client:market` | `{ t, p = { [index] = prix }, n? }` | seulement aux tablettes abonnées |
| `pop_tablet:client:share` | `{ offerId, kind, name }` | proposition reçue |
| `pop_tablet:client:open` | `{ app?, data? }` | `OpenApp` de l'API |
| `pop_tablet:client:forceClose` | `{ reason }` | objet perdu, joueur mort, tablette volée en cours d'usage |
| `pop_tablet:client:apps` | | catalogue d'applis API modifié (démarrage/arrêt d'une ressource) |

Chaque `notify` et `message` est un petit paquet (< 1 Ko). Aucun paquet n'est envoyé à un joueur dont la tablette n'est pas dans sa session (hors `notify` ciblé par numéro/serial).

### 7.4 Limites (aussi dans `server/limits.lua`)

Chaînes : nom d'appareil 32, titre 80, note 10 000, message 1000, mail 5000, contact 60, recherche 60. Listes : 30 éléments par page. Charge NUI -> serveur <= 128 Ko (tableau), <= 16 Ko ailleurs. Rejet immédiat si dépassement (jamais de troncature silencieuse pour les données utilisateur).

### 7.5 Exports (serveur et client)

Voir `docs/api-applis.md` : `RegisterApp`, `UnregisterApp`, `Notify`, `OpenApp`, `GetSerial`, `RegisterSite`, `MarketShock`. Côté client : `IsOpen`, `Close`, `OpenApp`.

## 8. Contrat NUI <-> client

Lua -> NUI : `SendNUIMessage({ action = 'tablet:<nom>', data = ... })`. NUI -> Lua : `RegisterNUICallback('tablet:<nom>', fn(data, cb))`, `cb({ ok, ... })` immédiat (aucun traitement lourd dans le callback NUI).

| Sens | Nom | Données |
|---|---|---|
| Lua -> NUI | `tablet:open` | `{ boot, locale = { ...table }, rtl, accent, clock = { h, m, d, mo, y, msPerMin }, weather, player = { coords, street } }` |
| Lua -> NUI | `tablet:close` | (animation de fermeture) |
| Lua -> NUI | `tablet:notify` | relais de `pop_tablet:client:notify` |
| Lua -> NUI | `tablet:message` / `:mail` / `:call` / `:market` / `:share` | relais des events 7.3 |
| Lua -> NUI | `tablet:clock` | resynchronisation (voir 11) |
| Lua -> NUI | `tablet:weather` | idem |
| Lua -> NUI | `tablet:camera` | `{ state = 'on' | 'off' | 'flash' }` |
| Lua -> NUI | `tablet:apps` | catalogue |
| NUI -> Lua | `tablet:call` | `{ name, data }` : relais **générique** vers le callback serveur `pop_tablet:<name>` (liste blanche des noms de la section 7.2 ; sinon rejet). Réponse `{ ok, ... }` |
| NUI -> Lua | `tablet:close` | ferme (rend le focus) ; équivalent de `close` du bridge |
| NUI -> Lua | `tablet:ready` | l'interface est montée, le client envoie `tablet:open` |
| NUI -> Lua | `tablet:camera` | `{ action = 'start' | 'stop' | 'shutter' | 'flip' }` |
| NUI -> Lua | `tablet:map` | `{ action = 'waypoint' | 'clear' | 'pause' | 'locate', x?, y? }` |
| NUI -> Lua | `tablet:schedule` | `{ items }` après modification d'alarmes/événements (nouvelle échéance) |
| NUI -> Lua | `tablet:micro` | `{ state }` résultat du test micro du Dictaphone |
| NUI -> Lua | `tablet:resync` | demande d'horloge/météo (ouverture des applis Horloge/Météo seulement) |

Focus : `SetNuiFocus(true, true)` à l'ouverture, `SetNuiFocus(false, false)` à la fermeture (utilisé par `bridge/client.lua` ; **cette native n'a pas été trouvée dans les docs locales** `fivem`/`fivem-natives` : elle est déjà employée par le bridge, à confirmer sur docs.fivem.net avant la première utilisation). `SetNuiFocusKeepInput` : non utilisé (le joueur ne bouge pas, tablette en main).
Touche d'ouverture : `RegisterKeyMapping('pop_tablet_toggle', <clé de locale>, 'keyboard', Config.Key)` (signature vérifiée : `RegisterKeyMapping(commande, description, 'keyboard', touche)`), défaut `F5`. La commande appelle `pop_tablet:device:open` ; le serveur refuse sans objet. Description du keybinding : texte traduit au chargement.
Animation + prop : `RequestAnimDict`/`TaskPlayAnim` + objet tenu attaché par `AttachEntityToEntity` (signature vérifiée), supprimés à la fermeture et à `onResourceStop`. Prop : `Config.Prop` (modèle de tablette ; défaut un modèle du jeu, à valider en jeu).

## 9. Applis : natif / existant / à construire

Légende : **N** natif GTA/FiveM, **E** existant (pop_base, oxmysql, pma-voice, screencapture), **C** à construire.

| Appli (id) | Nature | Fonctionnement réel |
|---|---|---|
| Réglages (`settings`) | C + E | Nom, code, langue (10), thème, fond, transparence, luminosité, volume, sonnerie, batterie ; sauvegarde via `settings:save` |
| Boutique (`store`) | C | Catalogue = applis natives + applis API visibles pour le job ; installer/retirer = liste `apps` |
| Appareil photo (`camera`) | **N** + E | `CreateMobilePhone(0)`, `CellCamActivate(true, true)`, `CellCamActivateSelfieMode(toggle)` (natives vérifiées) ; fermeture `DestroyMobilePhone`. Obturateur : le client masque l'interface, le serveur appelle `exports.screencapture:remoteUpload(source, url, options, cb)` ou `serverCapture(source, options, cb)` (exports serveur vérifiés) |
| Photos (`photos`) | C | Galerie, favoris, suppression ; `url` si hébergeur configuré, sinon repli base de données (webp réduit) |
| Notes (`notes`) | C | CRUD, épinglage |
| Calendrier (`calendar`) | C + N | Dates du jeu (`GetClockDayOfMonth`, `GetClockMonth`, `GetClockYear`, `GetClockHours`, `GetClockMinutes`, vérifiées) ; alerte par `scheduler` |
| Rappels (`reminders`) | C | Listes, échéances (date jeu), alerte |
| Fichiers (`files`) | C | Dossiers, documents texte, raccourcis vers photos/enregistrements/tableaux, lien de partage (jeton) |
| Tableau (`board`) | C | Dessin canvas côté NUI, traits quantifiés, sauvegarde serveur |
| Horloge (`clock`) | N + C | Heure du jeu (`GetClockHours/Minutes`) ; alarmes, minuteur : échéance dans `scheduler` ; chronomètre 100 % NUI ; horloges du monde = fuseaux fictifs `Config.Clock.Zones` (décalage en heures sur l'heure du jeu) |
| Calculette (`calculator`) | C | 100 % NUI, aucune donnée |
| Météo (`weather`) | **N** | Type de météo du jeu : `GetPrevWeatherTypeHashName`, `GetNextWeatherTypeHashName`, `GetWeatherTypeTransition` ; pluie `GetRainLevel`, vent `GetWindSpeed` (natives vérifiées) ; prévision = enchaînement jeu actuel -> suivant (pas d'invention) ; heure du jeu pour le jour/nuit |
| Plans (`maps`) | **N** | Position `GetEntityCoords` + rue `GetStreetNameAtCoord` ; recherche dans `shared/places.lua` ; itinéraire `SetNewWaypoint(x, y)` (GPS natif) ; `SetWaypointOff` ; carte : `ActivateFrontendMenu(hash, false, -1)` ouvre la carte du menu pause (le hash de la page carte du menu pause est à valider en jeu) ; au retour, `IsWaypointActive` + `GetFirstBlipInfoId(8)` + `GetBlipInfoIdCoord` donnent le point choisi (sprite 8 = marqueur, à valider). Pas de carte dessinée dans la NUI |
| Dictaphone (`dictaphone`) | **à vérifier** | Voir 9.1 |
| Traduire (`translate`) | C + E (HTTP) | Conversation à deux langues parmi les 10 ; le serveur appelle un service configurable (`Config.Translate.Url`, API compatible LibreTranslate ; clé en convar `set pop_tablet_translate_key`) via `PerformHttpRequest` ; sans service configuré l'appli est masquée |
| Bourse (`stocks`) | C | Voir 9.2 |
| Messages (`messages`) | C | SMS entre numéros de tablettes, photos/contacts/position en pièce jointe ; livraison par push, stockage sinon |
| Téléphone (`phone`) | C + E | Voir 9.3 |
| Mail (`mail`) | C | Adresse `nom@pop.ls` (domaine configurable) ; dossiers ; envoi entre tablettes |
| Contacts (`contacts`) | C | CRUD ; appeler/écrire en un geste ; partage de proximité |
| Navigateur (`browser`) | C | Pages internes `pop://<domaine>` (sites enregistrés par l'API, `pop_tablet_sites`) + liens externes de `Config.Browser.AllowedHosts` ouverts dans une `iframe` sandbox ; beaucoup de sites interdisent l'intégration (message d'erreur clair) ; historique et favoris en local NUI (non stockés) |
| Musique (`music`) | C | Radios/flux de `Config.Music.Stations` lus par un élément `audio` dans la NUI ; continue tablette fermée ; mini-lecteur dans le centre de contrôle |

### 9.1 Dictaphone : ce qui est possible

- Enregistrer le micro du joueur dans la NUI suppose `navigator.mediaDevices.getUserMedia`. **Rien dans les docs locales ne dit que la NUI FiveM (CEF) accorde le micro** : à tester en premier (fonction `dict-spike`). Test : à l'ouverture de l'appli, la NUI tente `getUserMedia({ audio: true })` et renvoie `tablet:micro` (`granted`/`denied`).
- Si `granted` : enregistrement `MediaRecorder` (opus, <= 120 s, <= 400 Ko), envoi au serveur par morceaux de 32 Ko via `pop_tablet:rec:save`, stockage `data` (base) ou `url` (hébergeur configuré).
- Si `denied` (cas probable) : **solution dégradée** assumée : l'appli reste dans le catalogue mais l'écran d'enregistrement affiche un message clair ; les mémos existants se lisent. Aucune solution native de capture micro vers fichier n'existe dans FiveM (pma-voice ne donne pas d'audio brut). Décision attendue de l'utilisateur : masquer l'appli (`Config.Apps.dictaphone = 'auto'` la masque si le test est `denied`) ou la garder visible en mode dégradé.
- La fonction n'est donc **pas garantie** ; la définition de « fini » l'accepte avec la preuve du test micro et la solution dégradée.

### 9.2 Bourse : marché simulé serveur

- 12 à 16 symboles fictifs dans `Config.Market.Symbols` (`{ id, nameKey, price, volatility }`), pas de société réelle.
- Simulation : marche aléatoire bornée (`price = price * (1 + volatility * gauss + trend)`), plancher 5 % du prix initial, borne haute 10x. Aucune boucle permanente : la minuterie `SetTimeout` (pas de `while true`) n'existe **que lorsqu'au moins une tablette est abonnée** (`stocks:subscribe` à l'ouverture de l'appli, `unsubscribe` à sa fermeture, abonné retiré à `playerDropped`/fermeture). Zéro abonné = aucune minuterie.
- Au premier abonné après une pause : rattrapage calculé en un bloc (<= 120 pas), sans envoi.
- Chaque pas (`Config.Market.TickSeconds`, 30 par défaut) envoie `pop_tablet:client:market` uniquement aux abonnés, avec les variations par **index** de symbole (tableau court, pas de noms).
- Persistance : `pop_tablet_market` écrite toutes les 10 minutes si abonnés, et à l'arrêt de la ressource.
- Actualités : titres tirés de modèles de locale (`stocks_news_*`) selon les variations > 3 %.
- Choc de marché depuis une autre ressource : export `MarketShock(symbol, pct)`.

### 9.3 Téléphone : appels

- Numéro propre à la tablette, affiché dans Réglages et Contacts.
- Appel : le serveur trouve la tablette appelée parmi les joueurs en ligne (`numberToSrc`, construite à l'ouverture et au chargement, **revérifiée** par `Bridge.GetItems`) ; sonnerie par `pop_tablet:client:call`.
- À la réponse : le serveur choisit `channel = Config.Phone.ChannelBase + callId` et appelle `exports['pma-voice']:setPlayerCall(source, channel)` pour les deux joueurs (export serveur vérifié) ; à la fin ou à la déconnexion : `setPlayerCall(source, 0)` (valeur de sortie **à confirmer** dans le code de pma-voice avant la première livraison).
- Sans pma-voice démarré (`GetResourceState`) : les appels sont refusés avec `err = 'phone_voice_missing'`, SMS inchangés.
- Fin automatique : non décroché après `Config.Phone.RingSeconds` (une `SetTimeout` par appel), `playerDropped`, objet perdu.
- Un joueur dans un seul appel à la fois (`busy`). Appel manqué = notification + ligne `missed`.

### 9.4 Photo : hébergeur et clé

- `Config.Photos.Mode = 'database'` (défaut, aucun secret) ou `'remote'`.
- `remote` : `Config.Photos.Url`, `Config.Photos.FormField`, `Config.Photos.UrlPath` (chemin dans la réponse JSON, défaut `url`). Clé API : `set pop_tablet_photo_key "..."` dans le `server.cfg` (**jamais `setr`**, jamais lisible par le client), lue par `GetConvar('pop_tablet_photo_key', '')` côté serveur et passée dans `options.headers`.
- Le serveur n'utilise **jamais** `requestScreenshotUpload` côté client (la doc de screencapture signale que les jetons y sont exposés).
- Attention : `remoteUpload` ajoute par défaut des en-têtes d'identité du serveur (`X-Screencapture-Server-Name`...), à signaler dans le README.
- Mode `database` : capture réduite (`maxWidth` 960), `encoding = 'webp'`, rejetée au-delà de 150 Ko.

## 10. API pour les autres ressources

Détail : `docs/api-applis.md`. Résumé : `RegisterApp({ id, nameKey|name, icon, page, jobs, ... })`, `Notify(target, notification)`, `OpenApp(src, appId, data)`. Les applis API ne s'exécutent que sur appel : aucune boucle ajoutée par POP.

## 11. Performance (chiffrée)

| Contexte | Cible mesurée |
|---|---|
| Client, tablette fermée | **0,00 ms** : aucun `CreateThread` avec boucle, aucun `Wait`. Seulement : handlers d'events, `RegisterKeyMapping`, 1 `SetTimeout` de `scheduler.lua` (0 s à 1 par joueur) |
| Serveur, aucun joueur ou tablettes fermées | **0,00 ms** : pas de `while true`, pas de `SetInterval`. Au plus 1 `SetTimeout` de `scheduler`, et 1 pour la Bourse seulement avec abonné |
| Client, tablette ouverte | Aucune boucle par défaut. **Une seule** boucle autorisée, uniquement pendant l'ouverture, et seulement si une native par image est indispensable : désactivation des contrôles de jeu (`DisableControlAction`) et mode caméra (`Wait(0)` pendant `camera`). Hors caméra, utiliser `SetNuiFocus(true, true)` qui bloque déjà les contrôles : **pas de boucle** |
| Horloge / météo | Envoyées à l'ouverture (1 snapshot), la NUI avance l'heure seule (`setInterval` navigateur à 1 s, pas de Lua) ; resynchronisation par une minuterie de 60 s **seulement tant que Horloge/Météo est l'appli au premier plan**, annulée à la fermeture |
| Réseau | Aucun polling. Push seulement : message, mail, appel, notification, marché (abonnés). Paquet <= 1 Ko, hors réponses de liste (<= 16 Ko, 30 éléments) et photos (une à la fois) |
| Bourse | Pas = 30 s, charge utile <= 200 octets par abonné |
| Serveur, appel | Une requête SQL maximum par callback ; index sur tout filtre ; pas de `SELECT *` sur les colonnes BLOB/TEXT lourdes dans les listes |
| Cache | Session par joueur en mémoire (série, déverrouillé, dernière activité) ; table `numberToSrc` ; réglages lus à l'ouverture ; invalidation à la fermeture/`playerDropped`/`OnPlayerUnloaded` |
| Mesure | `resmon` : client et serveur à 0,00 ms au repos, <= 0,05 ms pendant l'usage normal, <= 0,10 ms en caméra ; mémoire client < 40 Mo avec la NUI ouverte (chiffres à relever en jeu, section 14) |

Alarmes, minuteur, rappels, événements : `scheduler.lua` (client) calcule la prochaine échéance (en minutes de jeu -> millisecondes réelles via `Config.Clock.MsPerGameMinute`, défaut 2000), pose **une** `SetTimeout`, re-lit l'heure du jeu à l'échéance, déclenche `pop_tablet:server:due` (le serveur revérifie l'objet porté et l'existence de l'alarme, puis pousse la notification) et recalcule. Désynchronisation (script de temps externe) : re-planification, 3 essais. Côté serveur, `scheduler.lua` ne sert qu'aux minuteurs en secondes réelles (`ends_at`).
Batterie : calculée **paresseusement** par horodatage (`battery`, `battery_at`) : usage = -1 % / `Config.Battery.DrainMinutes` ouvertes, recharge = +1 % / `Config.Battery.ChargeMinutes` fermées. Aucune minuterie.

## 12. Configuration : `config.lua`

Clés de pop_base conservées (Locale, Debug, Framework, Inventory, Target, Notify, AccentColor, Keys, CallbackRateLimit), puis :

```lua
Config.Item = 'pop_tablet'
Config.Key = 'F5'                       -- touche par défaut (modifiable par le joueur)
Config.Prop = { model = 'prop_cs_tablet', bone = 28422, offset = vec3(0,0,0), rot = vec3(0,0,0) } -- à valider en jeu
Config.Anim = { dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', clip = 'base' } -- à valider en jeu
Config.Session = { IdleLockSeconds = 120 }
Config.Battery = { Enabled = true, MinToOpen = 5, DrainMinutes = 6, ChargeMinutes = 1 }
Config.Phone = { Format = '###-####', ChannelBase = 9000, RingSeconds = 25 }
Config.Mail = { Domain = 'pop.ls' }
Config.Clock = { Source = 'game', MsPerGameMinute = 2000, Zones = { ... } }
Config.Photos = { Mode = 'database', Url = '', FormField = 'file', UrlPath = 'url', Max = 200 }
Config.Translate = { Url = '' }         -- clé : convar set pop_tablet_translate_key
Config.Music = { Stations = { { name = 'Radio ...', url = 'https://...' } } }
Config.Browser = { AllowedHosts = {} }
Config.Market = { TickSeconds = 30, Symbols = { ... } }
Config.Share = { Distance = 3.0 }
Config.Apps = { dictaphone = 'auto', translate = 'auto' }  -- 'on' | 'off' | 'auto' (masqué si indisponible)
Config.Retention = { Days = 90 }
Config.Places = 'shared/places.lua'
```

Valeurs marquées « à valider en jeu » : anim/prop/hash de carte (dépendent des fichiers de jeu, pas dans les docs).

## 13. Sécurité : liste de contrôle

- Objet porté vérifié à chaque appel (7.1) ; serial jamais cru depuis le client.
- Code haché : `HMAC-SHA256(pepper, salt .. code)` itéré 2 000 fois (SHA-256 en Lua pur, `server/hash.lua` ; Lua 5.4 a les opérateurs binaires). `pepper` = convar serveur `set pop_tablet_pepper` (jamais `setr`) ; absent : généré et conservé dans `GetResourceKvpString`, avertissement console. Comparaison à temps constant. Blocage progressif. Le code n'est jamais journalisé ni renvoyé. Limite : 10 000 codes possibles, le hachage ne protège pas d'une fuite de base **et** du pepper ; l'objectif réel est le blocage en ligne.
- Anti-spam : `Callback` (taux par callback) + limites par action (7.2).
- Tailles max (7.4) ; échappement : l'interface n'utilise jamais `dangerouslySetInnerHTML` ; texte utilisateur affiché en texte seul ; liens externes seulement dans `AllowedHosts`.
- SQL : uniquement des requêtes paramétrées (`?`).
- Distance : `Bridge.IsNear` pour le partage, deux fois (envoi et acceptation).
- Appli API : `pop_tablet:app:call` ne route que vers la ressource propriétaire de l'appli, qui revérifie.
- Pas d'argent, pas d'inventaire modifié hors conversion du serial.
- Fermeture forcée si l'objet quitte l'inventaire (contrôle au prochain appel et à `OnPlayerUnloaded`/mort, pas de surveillance continue).

## 14. Définition de « fini »

1. Toutes les entrées de `feature_list.json` ont `passes: true` avec preuve dans `PROGRESS.md` (ou, pour une fonction impossible, la solution dégradée acceptée est écrite).
2. Vérifications automatiques vertes (section 15).
3. Interface de référence : chaque écran de `ui/pop-os/design/` existe, en clair et sombre, avec capture comparée.
4. En jeu (serveur de test) : tablette ouverte/fermée sans erreur, SMS et appel entre deux joueurs, photo prise, `resmon` à 0,00 ms au repos client et serveur (relevés notés).
5. Aucun texte en dur : script de contrôle des clés (10 fichiers de locales ont les mêmes clés ; l'interface n'a aucune chaîne littérale visible).
6. README du script à jour (installation, item, convars, config).

## 15. Commandes de vérification

Depuis la racine du dépôt :

```bash
luacheck resources templates                       # 0 avertissement, 0 erreur
for f in $(find "resources/[pop]/pop_tablet" -name '*.lua'); do luac5.4 -p "$f" || echo "ECHEC $f"; done
node --check "resources/[pop]/pop_tablet/web/kit/pop.js"
lua tests/run.lua                                   # depuis resources/[pop]/pop_tablet
cd ui/pop-os && pnpm install --frozen-lockfile
pnpm typecheck       # tsc --noEmit
pnpm test            # vitest run
pnpm build           # sortie vers resources/[pop]/pop_tablet/web/dist ; git diff doit se limiter à dist
node --check sur tout script .js de tooling éventuel
```

Note d'environnement relevée : sur ce poste `luac5.4` n'est pas dans le PATH (seuls `lua` et `luacheck` le sont) : installer `luac5.4` ou utiliser `lua -e "loadfile(...)"` à défaut ; à régler avant le premier `luac5.4 -p`.
`node --check` ne vérifie pas les `.tsx` : c'est `tsc --noEmit` qui les couvre.

## 16. Contradictions et points ouverts (à décider)

1. **Verre liquide** (DECISIONS) contre « pas de glassmorphism » (direction-artistique) : DECISIONS suivi, propre à cette appli.
2. **Objet <-> données** impossible sans métadonnées d'inventaire : repli par propriétaire (section 5.1). Une tablette volée ne garde pas ses données dans ce mode.
3. **`Config.Locale` unique** du bridge contre langue par tablette : résolu sans toucher `shared/` (le client lit `Locales[lang]` directement, `client/locale.lua`).
4. **Dictaphone** : micro NUI non garanti (9.1).
5. **Caméra** : `CreateMobilePhone` affiche un téléphone, pas une tablette ; à accepter ou masquer en jeu (non garanti).
6. **Plans** : carte du menu pause natif et récupération du point : hash et sprite à valider en jeu.
7. **Traduire** : exige un service HTTP externe configuré (sinon masquée) ; aucune traduction hors-ligne en V1.
8. **Appels** : exigent `pma-voice` ; valeur de sortie de `setPlayerCall` à confirmer.
9. **Bluetooth, Wi-Fi, rotation, recopie, enregistrement d'écran** des maquettes : retirés (sans fonction réelle).
10. **Boutique** : pas d'applis payantes en V1.
11. `SetNuiFocus` absente des docs locales (utilisée par le bridge).
12. `luac5.4` absent du PATH du poste.
