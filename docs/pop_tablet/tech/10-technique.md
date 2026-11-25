# POP Tablet · 10 · Document technique (phase 3)

Version du 24/11/2026. Lecteur : Claude Code, qui développe la tablette seul à partir de ce fichier et des fiches `specs/`.
Ordre de priorité en cas de doute : **ce document pour tout ce qui est technique** (fichiers, formats, schéma, réseau, build, tests) > `specs/00-sommaire.md` (constantes, noms publics, droits, réglages) > fiches `01` à `06` (comportement). Une fiche décrit **quoi** faire, ce document dit **comment** et **où**.
Rien ici n'est ouvert : chaque ligne est une décision. Les rares valeurs qui dépendent d'un script tiers installé chez le client sont listées au § 10 avec leur parade (vérification en recette, pas « à définir »).

---

## 0. Décisions majeures et arbitrages

### 0.1 Les 8 décisions qui structurent tout

| # | Décision | Raison courte |
|---|---|---|
| D1 | La ressource **part de `templates/pop_base`** : `bridge/client.lua`, `bridge/server.lua`, `shared/callback.lua`, `shared/locale.lua`, `web/kit/pop.css`, `web/kit/pop.js` copiés **sans modification**. Tout le reste du bridge (banque société, mort/réveil, véhicules, grades, gangs…) est ajouté dans des **fichiers d'extension** `bridge/tablet/*`, `bridge/framework/*` et des dossiers d'adaptateurs (§ 6). | ESX / QBCore / Qbox / inventaires / target / callbacks déjà testés et communs aux scripts POP ; on n'édite jamais un fichier pop_base dans un script (`docs/methode.md`). |
| D2 | NUI = **Preact 10 + @preact/signals + TypeScript**, compilée par **esbuild** (une seule dépendance de build). Source hors ressource dans `ui/pop_tablet/`, sortie **committée** dans `resources/[pop]/pop_tablet/web/dist/`. Une seule page NUI ; apps officielles chargées à la demande (`import()`), apps perso et apps de ressources tierces dans des **iframes isolées** avec un SDK vanilla sans build. | ~60 écrans riches (MDT, tableur, éditeur de site) : composants + état réactif = moins de bugs qu'en DOM à la main ; runtime ~6 Ko ; Claude écrit très bien du Preact/TSX ; l'acheteur n'a jamais besoin de Node (§ 2). |
| D3 | **Un seul canal NUI → serveur** : callback `pop_tablet:request` (pop_base `Callback.*`), pipeline de 13 contrôles de BASE-MOT-01, idempotence par `actionId`, réponses `{ ok, data }` / `{ ok = false, err, args }`. Le **jeton de session reste dans le Lua client** (jamais dans la NUI). | Un seul point d'audit ; la NUI (devtools) ne peut rien forger que le serveur ne revérifie. |
| D4 | **100 tables** `pop_tablet_*` créées par des **migrations versionnées idempotentes** (`server/core/migrations.lua`), jamais de `DROP`. `sql/install.sql` = copie lisible générée de la v1. | Installation 5 minutes, mises à jour sans manipulation. |
| D5 | **Zéro boucle** : côté serveur, un **ordonnanceur unique** (tas d'échéances, un seul `SetTimeout` armé sur l'échéance la plus proche, aucun quand vide) + 3 files à minuterie auto-arrêtée (écriture SQL, Discord, nettoyage cache). Côté client, des fils créés à l'ouverture et tués à la fermeture. | Cible resmon 0,00 ms au repos, client et serveur (BASE-MOT-13). |
| D6 | **Textes en JSON par espace de noms** : `locales/<langue>/<app>.json`, lus par le serveur (`LoadResourceFile` + `json.decode`, à la demande) et par la NUI (`fetch` local, à l'ouverture de l'app). Les clés communes de pop_base restent dans `locales/<langue>.lua`. | Chargement paresseux côté NUI sans trafic réseau ; même format que les apps perso ; facile à traduire. |
| D7 | **Escrow** : seuls les `.lua` du cœur sont chiffrés (`client/`, `server/`, `shared/`). Ouverts : `config.lua`, `locales/`, `bridge/` (adaptateurs), `defaults/`, `apps_perso/` (SDK, modèle, exemples), `docs/`, `tools/`, `CLAUDE.md`, `AGENTS.md`. Le JavaScript n'est jamais chiffrable par l'escrow Cfx : la NUI est livrée **minifiée** (`web/dist/`), sans source. | Cœur protégé là où est la valeur (règles serveur) ; acheteur libre d'adapter tout ce qui touche son serveur. |
| D8 | **Tests sans serveur** : luacheck 0/0, `luac5.4 -p`, tests unitaires Lua des règles serveur (lanceur maison, mocks FiveM/oxmysql), tests NUI Playwright sur une page hôte simulée, `pop-check` sur les apps perso. Recette en jeu sur ESX, QBCore et Qbox avec la même grille. | Rien ne part sur `main` sans démarrer proprement (CLAUDE.md du dépôt). |

### 0.2 Arbitrages techniques entre fiches (font foi)

| # | Sujet | Écrit dans les fiches | Décision technique |
|---|---|---|---|
| A1 | Dossier « mes apps » | `apps/` (01, 05, sommaire) | **`apps_perso/`** (consigne produit). Toute mention `apps/<id>` des fiches se lit `apps_perso/<id>`. |
| A2 | Structure d'une app perso | BASE-API-01 (`app.lua` qui `return`, `ui/index.html`, `client.lua`, iframe `allow-same-origin`) vs PERSO-01..09 | **PERSO-01..09 fait foi** : `app.lua` = un seul `PopApp.register({...})`, `index.html` à la racine de l'app, pas de `client.lua`, iframe `sandbox="allow-scripts"` **sans** `allow-same-origin`, SDK `apps_perso/_sdk/pop-app.js`. Exemples livrés : `exemple_notes`, `exemple_tableau`, `exemple_pourboire` (PERSO-07). |
| A3 | Apps officielles en iframe | BASE-MOT-09 / BASE-MOT-13 parlent d'iframes pour « les écrans d'apps » | Iframes **seulement** pour les apps perso et les apps enregistrées par une autre ressource (`RegisterApp` avec `ui = 'nui://<res>/…'`). Les apps officielles sont des modules Preact chargés à la demande dans la page, **démontés** à la fermeture (même garantie : rien ne reste en mémoire active). |
| A4 | Format des langues | `locales/*.lua` avec `Locales['fr'] = { name, rtl, texts }` (BASE-MOT-16) | D6 : `locales/<code>/_meta.json` (`{ "name": "Français", "rtl": false }`) + `locales/<code>/<ns>.json` (clés plates `"factures.liste.vide": "Aucune facture."`). Repli : langue de la tablette → `Config.Locale` → `fr` → la clé. Paramètres `{nom}` et `%s`. `AddLocale(lang, table)` reste un export. |
| A5 | Codes de langue | pop_base : en, fr, es, de, it, pt, nl, pl, tr, ar | Tablette : **en, pt-BR, fr, ar, de, th, tr, es, id, ro** (`_contexte.md`). Les 10 fichiers `locales/<code>.lua` de clés communes pop_base sont fournis pour ces 10 codes (it, pt, nl, pl non livrés). |
| A6 | Portées de `pop_tablet_appdata` | `device/player/job/global` (BASE-API-06) vs `player/company/global` (PERSO-04) | ENUM **`device`, `player`, `company`, `global`** ; `job` des fiches = `company` (id d'entreprise). |
| A7 | Colonnes de service | `debut/fin` (02, 04) vs `start_at/end_at` (06) | **`debut` / `fin`** (02 fait foi) ; le Planning lit ces colonnes. |
| A8 | Champ `payload` des Demandes | utilisé par EMS (MET-EMS-14/16) et l'Annuaire, absent de 02 | Colonne **`payload JSON NULL`** ajoutée à `pop_tablet_ent_demandes`. |
| A9 | Identifiants de personnage | VARCHAR(60) ou (64) selon les fiches | **VARCHAR(64)** partout. |
| A10 | `Config.Framework` | `'esx' | 'qb' | 'qbx'` (01) vs `'esx' | 'qbcore' | 'qbox'` (pop_base) | Valeurs pop_base acceptées + alias `qb` → `qbcore`, `qbx` → `qbox` ; la console affiche `esx`, `qb`, `qbx` (BASE-MOT-19). `'standalone'` refusé : arrêt avec « [pop_tablet] No compatible framework found (ESX, QBCore, Qbox). ». |
| A11 | Fréquence globale | 30 / 10 s (BASE-MOT-11) vs 60 / 10 s (sommaire) | **60 / 10 s** (sommaire). |
| A12 | Intervalle Discord | 2 s (05) vs 5 s (01, sommaire) | **5 s**. |
| A13 | Nombre d'apps | `Config.Apps.Max = 96` (API-02) vs `30` (PERSO-01) | Deux clés : `Config.Apps.Max = 96` (registre total) et `Config.Apps.PersoMax = 30`. `Config.Apps.LoadExamples = true` remplace `Config.Apps.Examples`. |
| A14 | Requêtes JSON MySQL | `JSON_VALUE(job,'$.name')` (BASE-MOT-02) | **`JSON_UNQUOTE(JSON_EXTRACT(job,'$.name'))`** (JSON_VALUE absent de MySQL < 8.0.21). Minimum supporté : MySQL 5.7.8 / MariaDB 10.3. |
| A15 | Grades QBCore / Qbox persistés | `pop_tablet_company_grades (company_id, grade, label, level)` | Colonnes ajoutées : `name`, `salary`, `is_boss`, `managed` (1 = créé ou modifié par la tablette, réappliqué au démarrage). |
| A16 | Type de facture | signal `kind = invoice | fine | quote`, `externalRef` | Colonnes `kind ENUM('invoice','fine','quote')` et `external_ref VARCHAR(64)` ajoutées à `pop_tablet_factures`. |
| A17 | Couleur par défaut d'entreprise | `#3B82F6` (05) | `#4FA3FF` (accent produit validé). |
| A18 | Événement des photos | `pop_tablet:media:data` (06) | **`pop_tablet:client:media`** (préfixe serveur → client du sommaire). |
| A19 | Fichiers « ouverts » de données | `shared/sheet_templates.lua` ouvert (06), couleurs véhicules dans `config.lua` (03) | Dossier ouvert **`defaults/`** : `sheet_templates.lua`, `vehicle_colors.lua`, `penal_code.lua`, `report_templates.lua`, `price_lists.lua`, `mech_catalog.lua`, `police_training.lua`, `companies.lua`. `config.lua` reste le seul fichier de réglages. |
| A20 | Contrôle CSP des apps perso | non prévu | Règle `pop-check` ajoutée **MAN-06 (BLOQUANT)** : `index.html` doit contenir en premier enfant de `<head>` la balise CSP du modèle (§ 7.3). |
| A21 | Formules du tableur | `html/js/formula.js` | `ui/pop_tablet/src/apps/sheets/formula.ts` (même rôle : calcul côté NUI, déterministe, testé). |
| A22 | Anti-spam pop_base | `Config.CallbackRateLimit` = 10 appels/s par nom de callback | La tablette met **`Config.CallbackRateLimit = 0`** : la limitation est faite par `RateLimit` dans la passerelle (par action, globale, plafonnée). Un seul callback est enregistré. |

---

## 1. Arborescence de la ressource

Légende : **[C]** chiffré par l'escrow · **[O]** ouvert (`escrow_ignore`) · **[N]** non chiffrable (fichier web servi au client, livré minifié ou en clair) · **[R]** créé à l'exécution, jamais livré.

### 1.1 Dans le dépôt

```
resources/[pop]/pop_tablet/            ← la ressource livrée (Tebex) et déployée
ui/pop_tablet/                         ← source NUI + tests NUI (jamais livré, jamais déployé)
tests/pop_tablet/                      ← tests unitaires Lua (jamais livré, jamais déployé)
scripts/release-tablette.sh            ← fabrique le zip Tebex (contrôles + build + copie)
```

### 1.2 La ressource `resources/[pop]/pop_tablet/`

```
fxmanifest.lua                         [O] (jamais chiffré par Cfx)
config.lua                             [O] tous les réglages (un seul fichier)
CLAUDE.md                              [O] guide pour l'IA (§ 8.6), FR puis EN, ≤ 300 lignes
AGENTS.md                              [O] « Lisez CLAUDE.md. »
README.md                              [O] installation en 5 minutes
install/
  ox_inventory.lua                     [O] bloc d'objets à coller (pop_tablet, pop_tablet_charger)
  qb_items.lua  qbx_items.lua          [O] idem QBCore / Qbox
  esx_items.sql                        [O] INSERT des deux objets (ESX)
  server.cfg.txt                       [O] ensure, ACE pop.tablet.admin, convars Discord / upload
sql/install.sql                        [O] référence lisible de la v1 (générée, non exécutée par la ressource)
shared/
  callback.lua                         [C] copie pop_base, inchangée
  locale.lua                           [C] copie pop_base, inchangée (L / GetLocaleTable du bridge)
  constants.lua                        [C] ids d'apps, niveaux, codes d'erreur, enums, plafonds durs
  util.lua                             [C] uuid, json sûr, utf8len, deepcopy, round, clamp
locales/
  en.lua … ro.lua                      [O] 10 fichiers de clés communes pop_base (cancel, confirm…)
  <code>/_meta.json                    [O→N] nom de la langue, rtl (10 dossiers : en pt-BR fr ar de th tr es id ro)
  <code>/common.json                   [O→N] commun.*, base.*, notif.*
  <code>/<app>.json                    [O→N] un fichier par app officielle (§ 3.6) + admin.json, companies.json
defaults/                              [O] données par défaut modifiables (A19)
bridge/
  client.lua  server.lua               [O] copies pop_base, inchangées
  tablet/server.lua                    [O] extension Bridge.* commune aux 3 frameworks (§ 6.2)
  tablet/client.lua                    [O] extension client (mort/réveil, menottes, véhicule, état)
  framework/esx.lua                    [O] implémentation ESX des fonctions d'extension (s'active si Bridge.Framework == 'esx')
  framework/qbcore.lua                 [O] idem QBCore
  framework/qbox.lua                   [O] idem Qbox
  inventory/metadata.lua               [O] SetItemMetadata, HasItem(meta), FindSerial par inventaire
  bank/esx_addonaccount.lua            [O] compte société ESX
  bank/qb-banking.lua                  [O] QBCore v2 / Qbox
  bank/qb-management.lua               [O] QBCore ancien
  bank/renewed-banking.lua             [O] Qbox
  bank/custom.example.lua              [O] modèle (renommer en custom.lua pour l'activer, prioritaire)
  jail/esx_jail.lua qalle_jail.lua qb-prison.lua qbx_prison.lua rcore_prison.lua   [O]
  jail/custom.example.lua              [O]
  dispatch/server/ps-dispatch.lua cd_dispatch.lua core_dispatch.lua esx_service.lua  [O] faux exports/événements serveur
  dispatch/client/ps-dispatch.lua cd_dispatch.lua core_dispatch.lua                  [O] faux exports client
  fuel/ox_fuel.lua legacyfuel.lua cdn-fuel.lua ps-fuel.lua native.lua                [O]
  cuffs/default.lua                    [O] IsPedCuffed + state bag isHandcuffed + metadata ishandcuffed
  licenses/esx_license.lua qb_metadata.lua   [O] permis (police)
client/
  main.lua                             [C] commande /tablette, key mapping +poptablet (F9), +poptabletdoc (Y), ouverture/fermeture
  nui.lua                              [C] relais RegisterNUICallback ↔ Callback (req, close, ready, upload…)
  session.lua                          [C] jeton, état ouvert/fermé, registre des fils (debug)
  props.lua                            [C] animation en main, prop, tablette posée (objet réseau)
  conditions.lua                       [C] fil 500 ms tant que ouverte (mort, menotté, nage, vitesse)
  charge.lua                           [C] recharge véhicule (fil seulement en véhicule + ouverte ou chargement), chargeur (barre)
  network.lua                          [C] zones sans réseau (BASE-ECR-17), calcul à la demande
  simple.lua                           [C] fenêtre simple (joueur sans tablette), file de 5
  gps.lua                              [C] SetNewWaypoint, blips temporaires d'appels (retirés à la fermeture/expiration)
  camera_fixed.lua                     [C] caméras fixes (cam scriptée, fil seulement en visionnage)
  bodycam.lua                          [C] caméra piéton (fil seulement en visionnage)
  photo.lua                            [C] mode photo (fil seulement pendant le mode)
  map.lua                              [C] positions envoyées à la Carte quand elle est ouverte
  death.lua                            [C] relais pop_tablet:bridge:died / revived (événements, sans boucle)
  evidence_locker.lua                  [C] casier physique (chargé seulement si Config.Police.EvidenceLocker)
server/
  boot.lua                             [C] chargé en dernier : contrôle des dépendances (BASE-MOT-19), migrations, défauts, ready
  core/
    timers.lua                         [C] ordonnanceur unique (tas d'échéances) + registre des minuteries (debug)
    i18n.lua                           [C] T(key, params, lang), chargement paresseux des JSON, AddLocale
    cache.lua                          [C] Cache.Get/Set/Invalidate/InvalidateNs, LRU, TTL paresseux
    writequeue.lua                     [C] WriteQueue.Push / Upsert / Flush (BASE-MOT-04)
    migrations.lua                     [C] migrations versionnées + RegisterMigration
    db.lua                             [C] wrappers oxmysql (await, scalar, insert, transaction, pagination)
    sanitize.lua                       [C] Sanitize.text / imageUrl / plate / serial
    schema.lua                         [C] validation des données d'action (types, bornes, motifs, profondeur)
    ratelimit.lua                      [C] RateLimit(src, key, rate)
    idem.lua                           [C] actionId : mémoire 2 générations, réponses rejouées, en-cours partagé
    session.lua                        [C] Sessions[src] : jeton, série, état, app ouverte, abonnements push
    gateway.lua                        [C] callback pop_tablet:request (pipeline § 3.3)
    registry.lua                       [C] apps et actions (officielles, tierces, perso), accès par joueur
    perm.lua                           [C] niveaux, grille de droits, Perm.Has, Perm.Level
    companies.lua                      [C] cache entreprises / grades / correspondance métier → entreprise
    refs.lua                           [C] jetons opaques (identifiants, sources) valables 10 min
    near.lua                           [C] proximité serveur (distance, bucket, vivant)
    log.lua                            [C] Log() (journal unique), regroupement des refus suspects
    discord.lua                        [C] file webhook, embeds, 429
    notify.lua                         [C] Notify.Send, boîte d'attente, bandeau / natif
    push.lua                           [C] Push.To(src|liste|{company,…}, app, event, data)
    payments.lua                       [C] Pay() (BASE-API-07), verrous mémoire
    documents.lua                      [C] OfferDocument (fenêtre simple), attente au réveil
    device.lua                         [C] série, code (bcrypt via GetPasswordHash), blocage, batterie, réglages
    placed.lua                         [C] tablettes posées (objet réseau, spectateurs, 30 m)
    duty.lua                           [C] Service.Actifs, state bag popDuty, SetDuty, IsOnDuty, CountOnDuty
    signals.lua                        [C] émission des signaux publics + OnSentence / OnInvoicePaid
    media.lua                          [C] photos sur disque, LRU 32 Mo, envoi latent, miniatures
    perso/loader.lua                   [C] PopApp.register, chargement server.lua
    perso/sandbox.lua                  [C] environnement fermé, compteur d'instructions, coupure auto
    perso/check.lua                    [C] règles pop-check en Lua (PERSO-08)
  apps/                                [C] un dossier par app officielle : actions.lua (déclarations) + fichiers métier
    base/ settings/ gestion/ factures/ annonces/ demandes/
    police/ ems/ meca/ carnet/ justice/ gang/ immo/
    sites/ companies/ admin/ reports/
    notes/ map/ gallery/ nav/ directory/ sheets/ stock/ planning/
  api/exports.lua                      [C] tous les exports publics (§ 8.1)
  api/compat.lua                       [C] signaux écoutés (pop_tablet:dispatchAlert), adaptateurs dispatch
web/
  index.html                           [N] page unique (CSP, kit, dist)
  kit/pop.css  kit/pop.js              [O→N] copies pop_base (HUD prompt / progression / toast du bridge)
  kit/tokens.css                       [O→N] variables --pt-* (BASE-MOT-09) : seule source des couleurs
  kit/tablet.css                       [O→N] classes .pt-* (composants) – ≤ 25 Ko
  dist/main.js  dist/main.css          [N] cœur NUI minifié (généré)
  dist/chunks/*.js                     [N] un fichier par app officielle (généré, chargé à la demande)
  dist/package.json                    [N] {"type":"module"} (pour node --check du lint)
  icons/<app>.svg                      [N] icônes d'apps (≤ 20 Ko chacune)
  img/wallpapers/*.webp                [N] 6 fonds d'écran fournis (≤ 150 Ko chacun)
apps_perso/
  _sdk/pop-app.js  _sdk/pop-app.css    [O→N] SDK des apps perso (écrasé à chaque mise à jour)
  _modele/                             [O] app vide (template = true)
  exemple_notes/ exemple_tableau/ exemple_pourboire/   [O]
docs/
  api.md                               [O] exports, signaux, formats, exemples (boutique, prison, dispatch)
  api-apps.md                          [O] SDK PopApp + objet App (perso)
  kit-de-style.md                      [O] tokens et classes
  adaptateurs.md                       [O] écrire un adaptateur banque / prison / dispatch / essence / menottes
  installation.md  mise-a-jour.md      [O] (mise à jour : conserver data/, apps_perso/<vos apps>, config.lua)
tools/pop-check.js                     [O] vérificateur Node sans dépendance (PERSO-08)
data/photos/                           [R] photos de la Galerie (.webp + _t.webp)
data/exports/  data/imports/           [R] export / import JSON des entreprises (SITE-CRE)
```

### 1.3 `fxmanifest.lua` (contenu exact)

```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'pop_tablet'
author 'POP'
version '1.0.0'
description 'POP Tablet'

dependencies { 'oxmysql' }

shared_scripts {
    'config.lua',
    'shared/callback.lua', 'shared/locale.lua', 'locales/*.lua',
    'shared/constants.lua', 'shared/util.lua',
}
client_scripts {
    'bridge/client.lua', 'bridge/tablet/client.lua',
    'bridge/cuffs/*.lua', 'bridge/fuel/*.lua', 'bridge/dispatch/client/*.lua',
    'client/*.lua',
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua', 'bridge/tablet/server.lua', 'bridge/framework/*.lua',
    'bridge/inventory/*.lua', 'bridge/bank/*.lua', 'bridge/jail/*.lua',
    'bridge/licenses/*.lua', 'bridge/dispatch/server/*.lua',
    'defaults/*.lua',
    'server/core/*.lua', 'server/core/perso/*.lua',
    'server/apps/**/*.lua', 'server/api/*.lua',
    'apps_perso/*/app.lua',
    'server/boot.lua',
}

ui_page 'web/index.html'
files {
    'web/index.html', 'web/dist/**', 'web/kit/**', 'web/icons/*.svg', 'web/img/**',
    'locales/*/*.json',
    'apps_perso/_sdk/*',
    'apps_perso/*/*.html', 'apps_perso/*/*.js', 'apps_perso/*/*.css',
    'apps_perso/*/*.svg', 'apps_perso/*/*.png', 'apps_perso/*/locales/*.json',
}

escrow_ignore {
    'config.lua', 'locales/*.lua', 'bridge/**/*.lua', 'defaults/*.lua',
    'apps_perso/**/*.lua', 'install/*.lua',
}
```

Règles : les `.lua` des apps perso et du bridge ne sont **jamais** dans `files` (non envoyés aux clients) ; `bridge/bank/custom.lua` et `bridge/jail/custom.lua` sont pris par le motif s'ils existent ; chaque fichier d'adaptateur commence par un garde (`if not <condition> then return end`) et s'enregistre auprès du registre d'adaptateurs (§ 6.3). `server/boot.lua` est listé en dernier : il démarre la tablette quand tout est chargé.

---

## 2. Interface (NUI)

### 2.1 Choix du framework

| Critère | Vanilla JS modulaire (sans build) | Svelte 5 compilé | **Preact + signals + TS (esbuild)** |
|---|---|---|---|
| Poids du runtime | 0 | ~3–10 Ko selon usage | ~6 Ko (preact 4 Ko + signals 2 Ko) |
| Écrans riches (tableur 200×26, éditeur de site, MDT 17 onglets, carte) | code DOM à la main, état dispersé, risque de fuites | très bon | très bon (composants, rendu ciblé par signaux) |
| Perf ouverture / frappe | bonne si discipline parfaite | excellente | excellente (signaux = mise à jour fine sans re-render global) |
| Claude-friendly (génération et relecture fiables) | moyen (verbeux, bugs d'état) | moyen (runes récentes, moins d'exemples) | **excellent** (JSX/TS très représentés, types = erreurs vues au build) |
| Ouverture aux acheteurs qui ajoutent des apps | – | – | sans objet : les acheteurs utilisent le **SDK vanilla** des apps perso (iframe), jamais le cœur |
| Outillage | aucun | compilateur Svelte + plugin | **un binaire** (esbuild) + `tsc --noEmit` |
| Protection du cœur | code lisible | minifié | minifié, sans source livrée |

**Décision : Preact 10 + @preact/signals + TypeScript strict, bundle esbuild.** Le cœur n'est pas fait pour être modifié par l'acheteur ; les apps perso ont leur SDK sans build. Versions **exactes** figées dans `ui/pop_tablet/package.json` (pas de `^`), installation par `npm ci`. Dépendances autorisées : `preact`, `@preact/signals`, `esbuild`, `typescript`, `@playwright/test`. Rien d'autre (pas de routeur, de lib d'UI, de CSS-in-JS, de police).

### 2.2 Source et build

```
ui/pop_tablet/
  package.json  package-lock.json  tsconfig.json  build.mjs
  src/
    main.tsx                 point d'entrée : écoute des messages, montage du Shell
    core/
      bus.ts                 réception SendNUIMessage { type: 'pop:*' } → signaux
      rpc.ts                 request(app, action, data, { write }) : actionId, rid, délais 5 s / 15 s
      i18n.ts                t(key, params), chargement des namespaces, format {nom} et %s
      rtl.ts                 dir sur <html>, nombres latins (ar-u-nu-latn)
      theme.ts               accent, taille de texte, luminosité, contraste texte/accent
      router.ts              pile de navigation par app (voir 2.3)
      registry.ts            id → () => import('../apps/<id>/index') (apps officielles)
      store.ts               session, appareil, apps autorisées, notifications, service
      format.ts              montants, dates, durées (Intl, Config.Currency)
      timers.ts              useAppTimeout / useAppInterval : enregistrés par app, tués au démontage
      csp.ts                 insère la CSP img-src reçue au démarrage
      frames.ts              hôte des iframes (perso / tierces), pont postMessage
    shell/                   Frame, Lock, Welcome, Desktop, TopBar, NotifCenter, Toasts, Modal, SimpleWindow, AppHost, FrameHost
    kit/                     composants (2.5)
    apps/<id>/               index.tsx (AppDef) + screens/*.tsx + api.ts (actions typées)
    apps/sheets/formula.ts   moteur de formules (pur, testé)
  tests/
    unit/*.test.ts           node:test (formules, format, i18n, router)
    e2e/*.spec.ts            Playwright
    mock/host.html           page hôte qui remplace FiveM
    mock/server.ts           faux serveur : fixtures par app/action
```

`build.mjs` (esbuild) : entrée `src/main.tsx`, `bundle`, `splitting`, `format: 'esm'`, `minify`, `target: 'chrome103'` (Chromium embarqué de FiveM), `jsx: 'automatic'`, `jsxImportSource: 'preact'`, `entryNames: '[name]'`, `chunkNames: 'chunks/[name]-[hash]'`, `legalComments: 'none'`, `sourcemap: false`, sortie `../../resources/[pop]/pop_tablet/web/dist/` (vidée avant), puis écrit `dist/package.json` = `{"type":"module"}`.

Commandes : `npm run build` (tsc --noEmit puis esbuild), `npm run dev` (esbuild watch + serveur local de `tests/mock/host.html`), `npm test` (unitaires), `npm run e2e` (Playwright). **La sortie `web/dist/` est committée** et poussée avec la source ; on ne build jamais sur le VPS.

Budgets (vérifiés par `build.mjs`, build en échec si dépassés) : `main.js` ≤ 90 Ko, `main.css` ≤ 15 Ko, chunk d'app ≤ 60 Ko (police ≤ 140 Ko, sites ≤ 90 Ko, sheets ≤ 80 Ko), total `dist/` ≤ 900 Ko.

`web/index.html` (écrit à la main, chargé une fois au démarrage du client) :

```html
<!doctype html><html lang="fr" dir="ltr"><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self' https://pop_tablet; frame-src 'self'; object-src 'none'; base-uri 'none'">
<link rel="stylesheet" href="kit/pop.css"><link rel="stylesheet" href="kit/tokens.css">
<link rel="stylesheet" href="kit/tablet.css"><link rel="stylesheet" href="dist/main.css">
<script src="kit/pop.js"></script><script type="module" src="dist/main.js"></script>
</head><body><div id="root"></div></body></html>
```

La liste des domaines d'images autorisés (`Config.Images.AllowedDomains`) est ajoutée au démarrage par `csp.ts` (deuxième balise CSP `img-src 'self' data: blob: https://i.imgur.com https://r2.fivemanage.com`), avant tout affichage d'un contenu joueur. `kit/pop.js` (pop_base) garde ses messages HUD `pop:prompt`, `pop:progress`, `pop:notify`, `pop:locale` (prompt natif, barre du chargeur, toasts hors tablette).

### 2.3 Routeur d'apps

| Élément | Règle |
|---|---|
| État | `route = signal<{ app: string | null, stack: { screen, params }[] }>` ; aucune URL, aucun hash. |
| Ouvrir une app | `openApp(id, screen?, params?)` : refuse si `id` absent de `store.apps` (liste calculée par le serveur) ; officielle → `AppHost` (import paresseux) ; perso / tierce → `FrameHost` (iframe). |
| Écran | `push(screen, params)` / `replace` / `back()`. Échap : ferme la fenêtre modale ouverte, sinon `back()`, sinon retour bureau, sinon fermeture de la tablette (BASE-API-03, 03 §0.7). |
| Liens profonds | notifications, `OpenScreen`, `Open` : `{ app, screen, params }` (params ≤ 2 Ko, sérialisables). |
| Fermeture d'app | `dispose()` de l'app, démontage, abandon des requêtes en cours (rid périmé), arrêt des minuteries enregistrées, libération du cache images de l'app. |
| Fermeture de la tablette | toutes les apps démontées, iframes retirées du DOM, `store` vidé des données d'app (seuls les réglages restent), aucun `setInterval` actif (test e2e). |

Contrat d'une app officielle (TS) :

```ts
export interface AppDef {
  id: AppId; ns: string[];                    // namespaces de langue à charger avant le montage
  duty?: boolean;                             // affiche l'état Hors service si non en service
  screens: Record<string, ComponentType<{ params: any }>>; home: string;
  onPush?(event: string, data: unknown): void; // pushes serveur ciblés (3.5)
  dispose?(): void;
}
```

### 2.4 Chargement paresseux

1. Démarrage du client FiveM : `index.html` + `main.js` + `main.css` seulement (rien n'est affiché, `body` transparent).
2. Ouverture de la tablette : `common.json` de la langue (une fois), icônes de la page 1 du bureau.
3. Ouverture d'une app : `Promise.all([import(chunk), fetch(locales/<lang>/<ns>.json)])`, puis première requête de données (page 1, 20 éléments). État « Chargement » (formes grises) jusqu'au retour ; « Ça prend plus de temps que prévu. » à 5 s.
4. Chunk et namespace gardés en mémoire jusqu'au redémarrage du client (le navigateur les met aussi en cache) ; les **données** d'app sont jetées à la fermeture.

### 2.5 Kit de composants

`web/kit/tokens.css` (variables `--pt-*` exactes de BASE-MOT-09, accent par défaut `#4FA3FF`) et `web/kit/tablet.css` (classes `.pt-*`) sont la seule source de style. Les composants Preact de `src/kit/` ne font qu'appliquer ces classes.

| Composant | Classe | Points imposés |
|---|---|---|
| `Button` | `.pt-btn` `--primary/--ghost/--danger` | état `busy` automatique pendant une requête `write` (désactivé jusqu'à la réponse) ; texte du bouton principal `#0E0F12` si luminance de l'accent > 0,6 |
| `Field`, `TextArea` | `.pt-input` `.pt-textarea` | `maxLength` = limite serveur reçue ; compteur « %d / %d » ; message `base.texte.trop_long` avant envoi |
| `Select`, `Tabs`, `Card`, `Badge` | `.pt-select` `.pt-tabs` `.pt-card` `.pt-badge` | |
| `List`, `Table` | `.pt-list` `.pt-table` | en-tête collant ; virtualisation au-delà de 200 lignes (tableur, journal) |
| `Pager` | `.pt-pager` | « Précédent » / « Suivant », « Page %d sur %d » quand `total` est connu, sinon `hasMore` |
| `ScreenState` | `.pt-skeleton` `.pt-empty` | les 6 états : `loading`, `empty`, `error`, `forbidden`, `offduty`, contenu ; succès = `toast` 2 s |
| `Search` | `.pt-search` | requête 300 ms après la dernière frappe, minimum 2 caractères |
| `Confirm`, `Modal` | `.pt-modal` | focus piégé, Entrée = valider, Échap = annuler |
| `PlayerPicker` | `.pt-list` | liste des personnes proches **fournie par le serveur** (refs opaques), jamais saisie libre d'id |
| `ImageField` | `.pt-input` | accepte `media:<id>` (galerie) ou URL ; contrôle de forme local, contrôle réel serveur |
| `Money`, `DateTime`, `Duration` | – | `format.ts` (entiers, « 12 500 $ », JJ/MM/AAAA HH:MM selon la langue) |
| `UserText` | – | affichage d'un texte joueur : nœud texte uniquement, `dir="auto"` |

Interdits (contrôlés par `tests/e2e/static.spec.ts` qui scanne `src/`) : `dangerouslySetInnerHTML`, `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `document.write`, `eval`, `new Function`, `setInterval` hors `timers.ts`, couleurs en dur hors `tokens.css`, `left:`/`right:`/`margin-left`/`padding-right`… dans les CSS (propriétés logiques seulement).

### 2.6 Langues et droite-à-gauche

| Sujet | Règle |
|---|---|
| Sens | `document.documentElement.dir = meta.rtl ? 'rtl' : 'ltr'` et `lang = code`, appliqués avant le premier rendu de la tablette et à chaque changement de langue (BASE-ECR-15). |
| CSS | propriétés logiques uniquement (`margin-inline-start`, `inset-inline-end`, `text-align: start`, `border-inline-start`) ; icônes directionnelles (flèches, retour) avec `.pt-icon--dir` retournées en RTL. |
| Contenus restant LTR | grille du tableur et formules, carte, plaques, numéros de série, montants, codes (`dir="ltr"` local). |
| Texte joueur | `dir="auto"` (un message arabe dans une interface française s'affiche correctement). |
| Nombres | `Intl.NumberFormat(code === 'ar' ? 'ar-u-nu-latn' : code)` : chiffres latins partout ; montants entiers. |
| Polices | pile système `system-ui, -apple-system, "Segoe UI", Tahoma, "Leelawadee UI", Roboto, Arial, sans-serif` (arabe et thaï couverts par les polices Windows), aucune police téléchargée. |
| Contrôle | e2e : capture de chaque écran du shell et d'un écran par app en `fr`, `de` (textes longs), `ar` (RTL), `th` ; échec si un élément déborde horizontalement de son parent. |

### 2.7 Apps perso et apps de ressources tierces (iframes)

| Élément | Règle |
|---|---|
| Balise | `<iframe sandbox="allow-scripts" src="https://cfx-nui-pop_tablet/apps_perso/<id>/index.html">` (tierce : `https://cfx-nui-<res>/<chemin>`), créée à l'ouverture, retirée du DOM à la fermeture. |
| Identification | `frames.ts` garde `Map<Window, appId>` ; un message n'est accepté que si `event.source` est la `contentWindow` d'une iframe connue ; l'`appId` vient de cette table, jamais du message. |
| Protocole | messages `{ pop: 1, id, kind, payload }` ; `kind` ∈ `ready`, `call`, `storage.get/set/remove/list`, `notify`, `confirm`, `setTitle`, `pickImage`, `close` (iframe → tablette) ; `context`, `result`, `theme`, `show`, `hide`, `push` (tablette → iframe, `postMessage(msg, '*')` sur la seule iframe visée). |
| Textes | l'iframe a une origine opaque et ne peut pas `fetch` ses JSON : la tablette lit `apps_perso/<id>/locales/<lang>.json` (repli `fr`) et les passe dans `context.texts`. |
| Appels serveur | `call` et `storage.*` → `request('perso', '<kind>', { app: appIdDeLaTable, action, data })` ; le serveur applique les contrôles PERSO-04/06. |

---

## 3. Réseau

### 3.1 Les chemins

```
NUI (Preact)  --fetch https://pop_tablet/req-->  client Lua (nui.lua)  --Callback.Trigger('pop_tablet:request')-->  serveur (gateway.lua)
serveur  --TriggerClientEvent('pop_tablet:client:*')-->  client Lua  --SendNUIMessage({ type = 'pop:*' })-->  NUI
gros contenus : serveur --TriggerLatentClientEvent('pop_tablet:client:media')--> client ; client --TriggerLatentServerEvent('pop_tablet:upload')--> serveur
```

Le client Lua ne décide rien : il ajoute le jeton de session et relaie. Les seuls autres événements client → serveur sont ceux du sommaire § 3.2 (gestes du jeu), tous revérifiés (§ 7).

### 3.2 Format

Requête NUI → client (`RegisterNUICallback('req')`) : `{ rid, app, action, data, actionId? }`. Le client relaie au serveur `{ v = 1, token, app, action, data, actionId, rid }`.

| Champ | Type | Règle |
|---|---|---|
| `v` | entier | version du protocole, `1` ; autre valeur → `invalide` |
| `token` | chaîne 32 car. `[A-Za-z0-9]` | posé par le client Lua depuis `pop_tablet:client:open` ; **jamais transmis à la NUI** |
| `app` | chaîne ≤ 32 `[a-z0-9_]` | id d'app officielle (§ 3.6), `perso`, ou id d'app tierce |
| `action` | chaîne ≤ 48 `[a-z0-9_.]` | déclarée par l'app (`RegisterAction`) |
| `data` | table | ≤ 32 Ko sérialisée (`Config.Security.MaxPayload`), profondeur ≤ 5, clés chaînes ≤ 64 car. |
| `actionId` | UUID v4 (36 car.) | **obligatoire pour toute action `write`**, généré par `crypto.randomUUID()` au clic (un par clic de validation, réutilisé tel quel pour un « Réessayer » de la même action) |
| `rid` | entier | numéro de requête NUI ; renvoyé tel quel ; une réponse dont le `rid` n'est plus attendu est ignorée |

Réponse : `{ ok = true, data = <table|nil>, rid }` ou `{ ok = false, err = '<code|clé>', args = { … }, rid }`. `err` sans point = `commun.erreur.<code>` (liste du sommaire § 3.9 + `bdd`) ; avec point = clé de langue complète. Aucune trace Lua, aucun nom de table, aucun identifiant brut d'un autre joueur n'est jamais renvoyé. Réponse > 64 Ko = bug : le serveur renvoie `serveur` et journalise (les listes sont paginées, les gros contenus passent par le canal latent).

Délais : NUI « lent » à 5 s, abandon à 15 s (`Config.UI.SlowAfter`, `Config.UI.RequestTimeout`) ; pop_base `Callback` coupe à 10 s → `nil` → le client renvoie `{ ok = false, err = 'serveur' }`.

### 3.3 Pipeline serveur (gateway.lua, ordre strict, arrêt au premier échec)

| # | Contrôle | Erreur | Coût |
|---|---|---|---|
| 1 | taille ≤ 32 Ko, profondeur ≤ 5, `v == 1`, types des champs d'enveloppe | `invalide` | mémoire |
| 2 | joueur chargé (`Bridge.GetPlayer`) et ressource prête (`MySQL.ready` + migrations OK) | `session` / `bdd` | mémoire |
| 3 | `token` = `Sessions[src].token`, session `unlocked` (sauf actions `base.pin.*`) | `session` (+ journal si jeton faux) | mémoire |
| 4 | objet tablette avec la série de la session (`Bridge.HasTabletSerial`, cache 10 s) | `pas_tablette` + fermeture forcée | inventaire (caché) |
| 5 | batterie > 0 | `batterie` | mémoire |
| 6 | réseau si l'app n'est pas `offline` | `reseau` | mémoire |
| 7 | action déclarée pour cette app | `invalide` | mémoire |
| 8 | accès à l'app (`Registry.CanUse`, recalculé au changement de métier) puis droit de l'action (`Perm.Has` avec le métier et le grade **relus via le bridge**) | `pas_droit` (+ `args.grade`) | mémoire |
| 9 | `duty = true` → en service (`Service.Actifs[src]`) | `hors_service` | mémoire |
| 10 | `RateLimit` : action (`rate` de l'action ou `Config.RateLimit.Default`), puis globale `Config.RateLimit.Global` | `trop_vite` | mémoire |
| 11 | `actionId` (actions `write`) : déjà terminé → réponse mémorisée rejouée ; en cours → attente du même résultat ; vu pour un autre joueur → `doublon` | `doublon` | mémoire |
| 12 | schéma de l'action (types, `min`/`max`, `required`, `pattern`, `enum`) + nettoyage `Sanitize.text` / `imageUrl` des champs `text` / `image` | `invalide`, `trop_long`, `champ_requis`, `image` | CPU |
| 13 | gestionnaire dans `pcall`, durée mesurée (`os.clock`, onglet Admin > Performance) | `serveur` (trace console seulement) | métier |

Déclaration d'une action (format de BASE-MOT-01, complété) :

```lua
Registry.Action('factures', {
  name = 'creer', write = true, duty = false, permission = 'facture.creer',
  rate = { n = 5, s = 10 }, critical = true,
  schema = {
    target = { type = 'ref', required = true },                 -- jeton opaque de PlayerPicker
    lignes = { type = 'list', min = 1, max = 20, of = {
      article = { type = 'text', max = 60, required = true },
      quantite = { type = 'int', min = 1, max = 999, required = true },
      prix = { type = 'int', min = 1, max = 100000, required = true } } },
    note = { type = 'text', max = 200, multiline = false },
  },
  handler = function(src, data, ctx) ... end,                   -- ctx = { identifier, name, companyId, level, grade, isAdmin, serial, locale }
})
```

Types de schéma : `text`, `int`, `number`, `bool`, `enum`, `ref` (jeton `Refs`), `image`, `plate`, `serial`, `uuid`, `date` (Unix), `list`, `table`. Un champ non déclaré est **supprimé** avant le gestionnaire.

### 3.4 Limites de fréquence

| Portée | Défaut | Réglage |
|---|---|---|
| Par action (défaut) | 5 / 10 s | `Config.RateLimit.Default` |
| Lectures / recherches police | 15 / 10 s | `Config.Police.RateLimit.Lecture` |
| Écritures police | 5 / 10 s | `Config.Police.RateLimit.Ecriture` |
| Tableur (cellule) | 20 / 5 s | fiche PRO-TAB |
| Apps perso (appel) | 20 / 10 s par app | `Config.Apps.CallRate` |
| Globale par joueur | 60 / 10 s | `Config.RateLimit.Global` |
| Plafond qu'une action peut demander | 40 / 10 s | `Config.RateLimit.MaxPerAction` |
| Événements de gestes (§ 3.7) | 1 / s par événement (mort/réveil 1 / 5 s) | constantes |

Fenêtre glissante en mémoire (`GetGameTimer()`), listes ≤ 40 valeurs, supprimées au `playerDropped`. Plus de 3 dépassements en 60 s : `Log` niveau `alert`, catégorie `triche` (une ligne par minute et par joueur). `Config.RateLimit.KickOnAbuse = false`.

### 3.5 Push serveur → client (ciblé)

| Fonction serveur | Cible résolue | Envoi |
|---|---|---|
| `Push.To(src, app, event, data)` | un joueur | seulement si sa session est ouverte **et** abonnée à `app` (app affichée) |
| `Push.ToList(srcs, …)` | liste | idem, un `TriggerClientEvent` par joueur (jamais `-1`) |
| `Push.ToCompany(companyId, app, event, data, { onDutyOnly, minLevel })` | membres connectés | index mémoire `Members[companyId] = { [src] = true }` maintenu sur chargement / changement de métier / déconnexion |
| `Push.ToPolice(app, event, data)` | agents des `Config.Police.Jobs` en service | index `Duty.ByApp.police` |
| `Notify.Send(target, notif)` | voir BASE-API-04 | si tablette sur soi : ouverte → `pop_tablet:client:notify` (bandeau) ; fermée → notification native avec le texte **déjà traduit** dans la langue de la tablette ; toujours ajoutée à `pop_tablet_notifications` (groupé) ; hors ligne → boîte d'attente (`identifier`) |

Événements serveur → client (préfixe `pop_tablet:client:`) : `open` (jeton, série, réglages, apps, limites, langue, domaines d'images), `forceClose` (raison), `apps` (liste recalculée), `push` (`app, event, data`), `notify`, `duty`, `battery`, `cityBanner`, `cityBannerRemoved`, `media` (latent : `id, thumb, base64`), `simple` (fenêtre simple : document), `placed` / `placedRemoved`, `gps` (point d'appel), `camera` (ouvrir une caméra autorisée), `bodycam`. Tablette fermée : seuls `notify`, `simple`, `placed*`, `cityBanner*` et `open` peuvent arriver ; le client ne crée aucun fil pour eux (affichage NUI ou notification native, puis rien).

### 3.6 Domaines (apps) et fichiers

| app | Nom affiché | Fiches | Serveur | Chunk NUI | Service requis |
|---|---|---|---|---|---|
| `base` | verrou, bureau, notifications, posée | BASE-OBJ, BASE-ECR | `server/apps/base/` | (dans `main.js`) | non |
| `settings` | Réglages | BASE-ECR-10..16 | `settings/` | `settings` | non |
| `gestion` | Gestion (service, employés, grades, droits, compte) | ENT-GES | `gestion/` | `gestion` | non |
| `factures` | Factures | ENT-FAC | `factures/` | `factures` | non |
| `annonces` | Annonces | ENT-ANN | `annonces/` | `annonces` | non |
| `demandes` | Demandes | ENT-DEM | `demandes/` | `demandes` | non |
| `police` | Police (MDT) | MET-POL | `police/` (un fichier par section : dispatch, citoyens, rapports, amendes, casier, mandats, preuves, cameras, codepenal, formation, saisie, avis, carte, infiltration) | `police` | oui (sauf exceptions fiches) |
| `ems` | EMS | MET-EMS | `ems/` | `ems` | oui |
| `meca` | Mécano | MET-MEC-01..10 | `meca/` | `meca` | oui |
| `carnet` | Carnet auto | MET-MEC-11 | `carnet/` | `carnet` | non |
| `justice` | Justice | MET-JUS | `justice/` | `justice` | oui |
| `gang` | Gang (icône déguisée) | MET-GANG | `gang/` | `gang` | non |
| `immo` | Immobilier (cadastre) | MET-IMM | `immo/` | `immo` | non |
| `sites` | Éditeur de site | SITE-EDI | `sites/` | `sites` | non |
| `companies` | Créateur d'entreprises (dans Admin) | SITE-CRE | `companies/` | `admin` | non |
| `admin` | Admin | ADM | `admin/` | `admin` | non (ACE) |
| `reports` | Signalements | ADM-16 | `reports/` | (dans `nav`, `annonces`) | non |
| `notes` | Notes | OUT-NOT | `notes/` | `notes` | non |
| `calc` | Calculatrice | OUT-CAL | aucun (100 % NUI, `offline`) | `calc` | non |
| `map` | Carte | OUT-CAR | `map/` | `map` | non |
| `gallery` | Galerie (+ `media`) | OUT-GAL | `gallery/` | `gallery` | non |
| `nav` | Navigateur | NAV | `nav/` | `nav` | non |
| `directory` | Annuaire | ANNU | `directory/` | `directory` | non |
| `sheets` | Tableur | PRO-TAB | `sheets/` | `sheets` | `Config.Pro.RequireDuty` |
| `stock` | Stock | PRO-STO | `stock/` | `stock` | `Config.Pro.RequireDuty` |
| `planning` | Planning | PRO-PLA | `planning/` | `planning` | `Config.Pro.RequireDuty` |
| `perso` | passerelle des apps perso | PERSO | `core/perso/` | (iframes) | selon l'app |

Les notations des fiches `RPC gestion.service.prendre`, `pop_tablet:police:matricule`, `ems:duty:toggle`, `sheets:setCell` se traduisent : app = premier segment (`pop_tablet:` retiré), action = le reste avec `:` remplacé par `.` et le camelCase écrit en snake_case (`sheets:setCell` → app `sheets`, action `set_cell` ; `pop_tablet:sites:addBlock` → `sites` / `add_block`). Le namespace de langue de chaque app porte le même nom que l'app (`locales/fr/police.json`) ; `commun.*`, `base.*`, `notif.*` sont dans `common.json`.

### 3.7 Événements réseau dédiés (gestes du jeu)

| Événement (client → serveur) | Contrôle serveur |
|---|---|
| `pop_tablet:close` | session du joueur ; enregistre batterie et durée ; jamais d'autre effet |
| `pop_tablet:viewPlaced` / `pop_tablet:takePlaced` | tablette posée existante, joueur ≤ 2 m (coordonnées serveur), même bucket, vivant |
| `pop_tablet:vehicleCharge` | joueur dans un véhicule (`GetVehiclePedIsIn` serveur), pas un vélo (classe 13), recharge calculée par le temps serveur écoulé, jamais par une valeur client |
| `pop_tablet:chargerDone` | chargement démarré par le serveur il y a ≥ 10 s (horodatage mémoire), objet chargeur présent |
| `pop_tablet:docAnswer` | document en attente pour ce joueur (`documents.lua`), réponse ∈ `accept/refuse/pay/later`, une seule fois |
| `pop_tablet:dispatchFromClient` | adaptateur dispatch client (faux exports ps/cd/core) : 3 / 10 s, coordonnées remplacées par celles du ped côté serveur |
| `pop_tablet:bridge:died` / `revived` / `playerLoaded` | déclenchent seulement une vérification `Bridge.IsDead` / chargement ; 1 / 5 s |
| `pop_tablet:upload` (latent) | ticket d'envoi émis par une action (`gallery.thumb`, `companies.import`, `sheets.paste`), usage unique, 60 s, taille déclarée ≤ plafond de l'action, en-tête de fichier vérifié |


---

## 4. Base de données

### 4.1 Règles communes

| Règle | Valeur |
|---|---|
| Moteur / jeu de caractères | toutes les tables : `ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci` (suffixe omis ci-dessous, ajouté par `migrations.lua`) |
| Dates | tables des fichiers 01 et 02 : `INT UNSIGNED` (Unix, `os.time()`) ; tables 03 à 06 : `DATETIME` heure du serveur (sommaire § 3.5). Le code passe par `Db.now()` / `Db.unix()` pour ne jamais mélanger. |
| Identifiants | personnage `VARCHAR(64)` ; entreprise `company_id INT` = `pop_tablet_companies.id` ; gang `gang_id INT` = même valeur ; tablette `serial VARCHAR(12)` |
| Clés étrangères | **aucune contrainte FK** (suppression logique, imports, ordre de création libre) ; l'intégrité est vérifiée par le code et par les index |
| JSON | colonnes `JSON` sans valeur par défaut (MySQL < 8.0.13) : le code écrit toujours `'[]'` ou `'{}'` |
| Archivage | rien de sensible n'est supprimé : colonnes `archived`/`archive`, `archived_at`/`archive_le`, `archived_by`/`archive_par`, motif ; seules les données perso non sensibles (notes, favoris, historique, points, photos hors preuve) sont réellement supprimées |
| Requêtes | oxmysql, paramètres `?` uniquement ; `ORDER BY` / colonnes de tri choisis dans une liste blanche du code |
| Police (03) | toutes les tables `pop_tablet_police_*` ont `id INT AUTO_INCREMENT PRIMARY KEY` (sauf mention) et `cree_le DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP` ; les colonnes RC7 s'écrivent `archive TINYINT(1) NOT NULL DEFAULT 0, archive_par VARCHAR(64) NULL, archive_le DATETIME NULL, archive_motif VARCHAR(300) NULL` (notées `RC7` ci-dessous) |

### 4.2 Migrations versionnées

| Élément | Règle |
|---|---|
| Fichier | `server/core/migrations.lua` : `Migrations[1]` = schéma complet ci-dessous ; `Migrations[n]` suivantes = ajouts uniquement. |
| Démarrage | après `MySQL.ready` : lire `pop_tablet_meta.db_version` (absente = 0) ; appliquer chaque version manquante dans l'ordre ; écrire la version **après** la réussite de toutes ses étapes ; journal « migration appliquée ». |
| Idempotence (DDL non transactionnel en MySQL) | chaque étape est rejouable : `CREATE TABLE IF NOT EXISTS` ; `Migr.addColumn(t, c, def)`, `Migr.addIndex(t, name, cols)`, `Migr.modifyColumn` vérifient d'abord `information_schema` (aucun `ADD COLUMN IF NOT EXISTS`, absent de MySQL). Une migration interrompue reprend au redémarrage sans erreur. |
| Échec | arrêt des suivantes, console rouge « [pop_tablet] Migration %d failed: %s », tablette refusée (`bdd`) ; les données existantes ne sont jamais touchées. |
| Interdits | `DROP`, `TRUNCATE`, `RENAME TABLE`, suppression de colonne, changement de type qui perd des données. Les migrations d'apps (`RegisterMigration(appId, version, sql)`) : `CREATE TABLE IF NOT EXISTS` ou `ALTER TABLE … ADD` sur une table préfixée `pop_tablet_app_<appId>_` seulement ; mots `DROP`, `TRUNCATE`, `DELETE`, `UPDATE`, `GRANT` refusés ; version dans `pop_tablet_meta` clé `db_version_<appId>`. |
| Données par défaut | après les migrations : entreprises par défaut (une seule fois, `pop_tablet_settings.defaults_installed`), code pénal, modèles de rapport, tarifs EMS, catalogue mécano, parcours de formation, depuis `defaults/*.lua`. |
| `sql/install.sql` | généré par `tests/pop_tablet/gen_install_sql.lua` à partir de `Migrations[1]` (jamais écrit à la main) ; test : les deux sont identiques. |

### 4.3 Schéma consolidé v1 — 100 tables

#### Base (01) — 6 tables

```sql
CREATE TABLE IF NOT EXISTS pop_tablet_meta (
  meta_key VARCHAR(64) NOT NULL PRIMARY KEY, meta_value TEXT NOT NULL);           -- db_version, db_version_<app>, install_id

CREATE TABLE IF NOT EXISTS pop_tablet_devices (
  serial VARCHAR(12) NOT NULL PRIMARY KEY, owner_identifier VARCHAR(64) NULL,
  mode ENUM('item','character') NOT NULL, pin_hash VARCHAR(100) NULL,
  pin_fails TINYINT UNSIGNED NOT NULL DEFAULT 0, locked_until INT UNSIGNED NOT NULL DEFAULT 0,
  battery DECIMAL(5,2) NOT NULL DEFAULT 100.00, settings LONGTEXT NOT NULL,          -- JSON ≤ 16 Ko
  first_boot_done TINYINT(1) NOT NULL DEFAULT 0, disabled TINYINT(1) NOT NULL DEFAULT 0,
  created_at INT UNSIGNED NOT NULL, reset_at INT UNSIGNED NULL, last_used_at INT UNSIGNED NOT NULL,
  KEY idx_mode_owner (mode, owner_identifier));

CREATE TABLE IF NOT EXISTS pop_tablet_notifications (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, serial VARCHAR(12) NULL, identifier VARCHAR(64) NULL,
  app VARCHAR(32) NOT NULL, title VARCHAR(120) NOT NULL, body VARCHAR(320) NULL,
  params TEXT NULL, link TEXT NULL, priority TINYINT NOT NULL DEFAULT 0, is_read TINYINT(1) NOT NULL DEFAULT 0,
  created_at INT UNSIGNED NOT NULL,
  KEY idx_serial_created (serial, created_at), KEY idx_identifier (identifier), KEY idx_created (created_at));

CREATE TABLE IF NOT EXISTS pop_tablet_appdata (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, app_id VARCHAR(32) NOT NULL,
  scope_type ENUM('device','player','company','global') NOT NULL, scope_id VARCHAR(64) NOT NULL DEFAULT '',
  data_key VARCHAR(64) NOT NULL, data_value LONGTEXT NOT NULL, archived TINYINT(1) NOT NULL DEFAULT 0,
  updated_at INT UNSIGNED NOT NULL,
  UNIQUE KEY uq_scope_key (app_id, scope_type, scope_id, data_key), KEY idx_scope (app_id, scope_type, scope_id, updated_at));

CREATE TABLE IF NOT EXISTS pop_tablet_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, created_at INT UNSIGNED NOT NULL,
  actor_identifier VARCHAR(64) NULL, actor_name VARCHAR(80) NOT NULL, app VARCHAR(32) NOT NULL, action VARCHAR(48) NOT NULL,
  target VARCHAR(120) NULL, target_identifier VARCHAR(64) NULL, target_name VARCHAR(80) NULL, company_id INT NULL,
  summary VARCHAR(255) NULL, category VARCHAR(20) NOT NULL DEFAULT 'admin',
  before_data TEXT NULL, after_data TEXT NULL, level ENUM('info','warn','alert') NOT NULL DEFAULT 'info',
  resource VARCHAR(64) NOT NULL DEFAULT 'pop_tablet',
  KEY idx_created (created_at), KEY idx_actor (actor_identifier, created_at), KEY idx_app (app, created_at),
  KEY idx_target (target_identifier), KEY idx_company (company_id, created_at), KEY idx_cat (category, created_at));

CREATE TABLE IF NOT EXISTS pop_tablet_payments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, action_id VARCHAR(40) NOT NULL, app VARCHAR(32) NOT NULL,
  from_type VARCHAR(16) NOT NULL, from_id VARCHAR(64) NOT NULL, to_type VARCHAR(16) NOT NULL, to_id VARCHAR(64) NOT NULL,
  amount INT UNSIGNED NOT NULL, reason VARCHAR(255) NOT NULL,
  status ENUM('pending','done','refunded','failed') NOT NULL, created_at INT UNSIGNED NOT NULL,
  UNIQUE KEY uq_action (action_id), KEY idx_created (created_at), KEY idx_status (status, created_at));
```

#### Entreprises (02) — 9 tables

```sql
CREATE TABLE IF NOT EXISTS pop_tablet_ent_services (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, company_id INT NOT NULL, identifier VARCHAR(64) NOT NULL,
  nom VARCHAR(100) NOT NULL, grade INT NOT NULL, debut INT UNSIGNED NOT NULL, fin INT UNSIGNED NULL, duree INT UNSIGNED NULL,
  raison_fin ENUM('manuel','deconnexion','renvoi','changement_metier','force','arret','interrompu') NULL, force_par VARCHAR(64) NULL,
  KEY idx_company_debut (company_id, debut), KEY idx_identifier_debut (identifier, debut), KEY idx_open (fin));

CREATE TABLE IF NOT EXISTS pop_tablet_ent_invitations (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, company_id INT NOT NULL, par VARCHAR(64) NOT NULL, cible VARCHAR(64) NOT NULL,
  cible_nom VARCHAR(100) NOT NULL, ancien_metier VARCHAR(50) NOT NULL,
  statut ENUM('envoyee','acceptee','refusee','expiree') NOT NULL, cree_le INT UNSIGNED NOT NULL, repondu_le INT UNSIGNED NULL,
  KEY idx_company (company_id, cree_le), KEY idx_cible (cible, statut));

CREATE TABLE IF NOT EXISTS pop_tablet_ent_permissions (
  company_id INT NOT NULL, grade INT NOT NULL, cle VARCHAR(60) NOT NULL, valeur TINYINT(1) NOT NULL, plafond INT NULL,
  PRIMARY KEY (company_id, grade, cle));

CREATE TABLE IF NOT EXISTS pop_tablet_ent_reglages (
  company_id INT NOT NULL, cle VARCHAR(60) NOT NULL, valeur VARCHAR(100) NOT NULL,
  modifie_par VARCHAR(64) NOT NULL, modifie_le INT UNSIGNED NOT NULL, PRIMARY KEY (company_id, cle));

CREATE TABLE IF NOT EXISTS pop_tablet_ent_mouvements (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, company_id INT NOT NULL,
  type ENUM('depot','retrait','prime','facture','part_employe','annonce_ville','autre') NOT NULL,
  montant INT NOT NULL, solde_apres INT NULL, acteur VARCHAR(64) NULL, acteur_nom VARCHAR(100) NULL, cible_nom VARCHAR(100) NULL,
  libelle VARCHAR(120) NOT NULL, ref VARCHAR(40) NULL, cree_le INT UNSIGNED NOT NULL,
  KEY idx_company (company_id, cree_le));

CREATE TABLE IF NOT EXISTS pop_tablet_ent_annonces (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, company_id INT NOT NULL, type ENUM('entreprise','ville') NOT NULL DEFAULT 'entreprise',
  titre VARCHAR(60) NOT NULL, texte VARCHAR(500) NOT NULL, image VARCHAR(300) NULL,
  auteur VARCHAR(64) NOT NULL, auteur_nom VARCHAR(100) NOT NULL, debut INT UNSIGNED NOT NULL, fin INT UNSIGNED NOT NULL,
  statut ENUM('active','expiree','retiree') NOT NULL DEFAULT 'active', modifie_le INT UNSIGNED NULL, modifie_par VARCHAR(64) NULL,
  retiree_par VARCHAR(64) NULL, retiree_le INT UNSIGNED NULL, cout INT NOT NULL DEFAULT 0,
  KEY idx_company (company_id, statut, debut), KEY idx_active (type, statut, fin));

CREATE TABLE IF NOT EXISTS pop_tablet_ent_demandes (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, numero VARCHAR(12) NOT NULL, uid CHAR(36) NOT NULL, company_id INT NOT NULL,
  type ENUM('depannage','rendez_vous','devis','contact') NOT NULL, source ENUM('site','annuaire','api') NOT NULL,
  demandeur VARCHAR(64) NOT NULL, demandeur_nom VARCHAR(100) NOT NULL, contact VARCHAR(40) NULL, message VARCHAR(500) NOT NULL,
  payload JSON NULL,                                                                -- A8 : champs propres (EMS, annuaire)
  pos_x FLOAT NULL, pos_y FLOAT NULL, pos_z FLOAT NULL, lieu VARCHAR(100) NULL, date_souhaitee INT UNSIGNED NULL,
  statut ENUM('nouvelle','acceptee','refusee','cloturee','annulee') NOT NULL DEFAULT 'nouvelle',
  assigne_a VARCHAR(64) NULL, assigne_nom VARCHAR(100) NULL, assigne_par VARCHAR(64) NULL,
  pris_par VARCHAR(64) NULL, pris_par_nom VARCHAR(100) NULL, motif_refus VARCHAR(200) NULL, note_cloture VARCHAR(200) NULL,
  facture_numero VARCHAR(12) NULL, cree_le INT UNSIGNED NOT NULL, pris_le INT UNSIGNED NULL, refuse_le INT UNSIGNED NULL,
  cloture_le INT UNSIGNED NULL, annule_le INT UNSIGNED NULL,
  UNIQUE KEY uq_numero (numero), UNIQUE KEY uq_uid (uid),
  KEY idx_company (company_id, statut, cree_le), KEY idx_demandeur (demandeur, statut));

CREATE TABLE IF NOT EXISTS pop_tablet_factures (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, uid CHAR(36) NOT NULL, numero VARCHAR(12) NOT NULL, company_id INT NOT NULL,
  kind ENUM('invoice','fine','quote') NOT NULL DEFAULT 'invoice',                   -- A16
  auteur VARCHAR(64) NULL, auteur_nom VARCHAR(100) NOT NULL, client VARCHAR(64) NOT NULL, client_nom VARCHAR(100) NOT NULL,
  lignes JSON NOT NULL, sous_total INT NOT NULL, majoration INT NOT NULL DEFAULT 0, total INT NOT NULL, note VARCHAR(200) NULL,
  statut ENUM('attente','payee','refusee','annulee') NOT NULL DEFAULT 'attente', transmise_police TINYINT(1) NOT NULL DEFAULT 0,
  moyen ENUM('bank','money') NULL, payeur VARCHAR(64) NULL, part_pct TINYINT UNSIGNED NOT NULL DEFAULT 0,
  part_employe_montant INT NOT NULL DEFAULT 0, source ENUM('tablette','api') NOT NULL, source_script VARCHAR(50) NULL,
  external_ref VARCHAR(64) NULL, metadata JSON NULL, refus_autorise TINYINT(1) NOT NULL DEFAULT 1,
  echeance INT UNSIGNED NOT NULL, livree TINYINT(1) NOT NULL DEFAULT 0, relances TINYINT UNSIGNED NOT NULL DEFAULT 0,
  derniere_relance INT UNSIGNED NULL, refus_motif VARCHAR(100) NULL, cree_le INT UNSIGNED NOT NULL, paye_le INT UNSIGNED NULL,
  refuse_le INT UNSIGNED NULL, annule_le INT UNSIGNED NULL, annule_par VARCHAR(64) NULL,
  UNIQUE KEY uq_uid (uid), UNIQUE KEY uq_numero (numero),
  KEY idx_company (company_id, statut, cree_le), KEY idx_client (client, statut), KEY idx_auteur (auteur, cree_le),
  KEY idx_echeance (statut, echeance));

CREATE TABLE IF NOT EXISTS pop_tablet_factures_evenements (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, facture_id INT NOT NULL,
  type ENUM('creee','livree','relancee','payee','refusee','annulee','majoree','transmise_police') NOT NULL,
  par VARCHAR(64) NULL, details VARCHAR(200) NULL, cree_le INT UNSIGNED NOT NULL, KEY idx_facture (facture_id));
```

#### Entreprises, sites, admin (05) — 8 tables

```sql
CREATE TABLE IF NOT EXISTS pop_tablet_companies (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, slug VARCHAR(32) NOT NULL, name VARCHAR(40) NOT NULL, logo_url VARCHAR(255) NULL,
  color CHAR(7) NOT NULL DEFAULT '#4FA3FF', template VARCHAR(20) NOT NULL, job_name VARCHAR(50) NULL, apps JSON NOT NULL,
  is_default TINYINT(1) NOT NULL DEFAULT 0, archived TINYINT(1) NOT NULL DEFAULT 0, archived_at DATETIME NULL, archived_by VARCHAR(64) NULL,
  created_by VARCHAR(64) NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_slug (slug), UNIQUE KEY uq_job (job_name), KEY idx_template (template, archived));

CREATE TABLE IF NOT EXISTS pop_tablet_company_grades (
  company_id INT NOT NULL, grade INT NOT NULL, name VARCHAR(50) NOT NULL, label VARCHAR(40) NOT NULL,
  level ENUM('recrue','membre','chef','patron') NOT NULL, salary INT NOT NULL DEFAULT 0,
  is_boss TINYINT(1) NOT NULL DEFAULT 0, managed TINYINT(1) NOT NULL DEFAULT 0,          -- A15
  PRIMARY KEY (company_id, grade));

CREATE TABLE IF NOT EXISTS pop_tablet_sites (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, company_id INT NOT NULL, address VARCHAR(40) NOT NULL,
  site_type VARCHAR(20) NOT NULL DEFAULT 'entreprise', description VARCHAR(140) NULL, unlisted TINYINT(1) NOT NULL DEFAULT 0,
  maintenance TINYINT(1) NOT NULL DEFAULT 0, maintenance_message VARCHAR(200) NULL, address_changed_at DATETIME NULL,
  old_address VARCHAR(40) NULL, old_address_until DATETIME NULL,                     -- redirection 7 jours (05, décision 7)
  template VARCHAR(20) NOT NULL, draft JSON NOT NULL, published_version_id INT NULL,
  status ENUM('brouillon','publie','masque') NOT NULL DEFAULT 'brouillon',
  hidden_reason VARCHAR(200) NULL, hidden_by VARCHAR(64) NULL, hidden_at DATETIME NULL,
  lock_identifier VARCHAR(64) NULL, lock_name VARCHAR(60) NULL, lock_until DATETIME NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_company (company_id), UNIQUE KEY uq_address (address), KEY idx_old (old_address), KEY idx_list (status, unlisted, site_type));

CREATE TABLE IF NOT EXISTS pop_tablet_site_versions (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, site_id INT NOT NULL, number INT NOT NULL, content JSON NOT NULL,
  kind ENUM('publication','restauration','import') NOT NULL, author_identifier VARCHAR(64) NOT NULL, author_name VARCHAR(60) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE KEY uq_site_number (site_id, number));

CREATE TABLE IF NOT EXISTS pop_tablet_site_visits (
  site_id INT NOT NULL, day DATE NOT NULL, visits INT NOT NULL DEFAULT 0, PRIMARY KEY (site_id, day));

CREATE TABLE IF NOT EXISTS pop_tablet_reports (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, target_type ENUM('site','annonce') NOT NULL, target_id INT NOT NULL,
  reporter_identifier VARCHAR(64) NOT NULL, reason VARCHAR(40) NOT NULL, comment VARCHAR(300) NULL,
  status ENUM('ouvert','traite','rejete') NOT NULL DEFAULT 'ouvert', handled_by VARCHAR(64) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_one (target_type, target_id, reporter_identifier), KEY idx_open (status, target_type, target_id));

CREATE TABLE IF NOT EXISTS pop_tablet_settings (
  setting_key VARCHAR(64) NOT NULL PRIMARY KEY, value JSON NOT NULL, updated_by VARCHAR(64) NOT NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP);

CREATE TABLE IF NOT EXISTS pop_tablet_cameras (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, name VARCHAR(60) NOT NULL, zone VARCHAR(40) NULL,
  x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, rot_x FLOAT NOT NULL, rot_y FLOAT NOT NULL, rot_z FLOAT NOT NULL,
  fov FLOAT NOT NULL DEFAULT 60, companies JSON NOT NULL, active TINYINT(1) NOT NULL DEFAULT 1,
  max_rotation INT NOT NULL DEFAULT 45, night_vision TINYINT(1) NOT NULL DEFAULT 1, online TINYINT(1) NOT NULL DEFAULT 1,
  created_by VARCHAR(64) NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_name (name), KEY idx_active (active, zone));
```

#### Police (03) — 25 tables (`id` + `cree_le` implicites sauf mention, voir 4.1)

Notation compacte normative pour 03, 04 et 06 : chaque ligne = `CREATE TABLE IF NOT EXISTS <nom> (…)` ; `PK` = `NOT NULL PRIMARY KEY` ; `AI PK` = `INT NOT NULL AUTO_INCREMENT PRIMARY KEY` (ou `BIGINT` si écrit) ; `KEY (…)` sans nom = index nommé `idx_<colonnes>` par `migrations.lua` ; police : `id INT NOT NULL AUTO_INCREMENT PRIMARY KEY` en tête et `cree_le DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP` en fin, sauf tables marquées « sans id ».

```sql
pop_tablet_police_agents (identifier VARCHAR(64) PK, matricule VARCHAR(8) NOT NULL UNIQUE, maj_par VARCHAR(64) NOT NULL, maj_le DATETIME NOT NULL)  -- sans id
pop_tablet_police_appels (numero VARCHAR(12) NOT NULL UNIQUE, code VARCHAR(12) NOT NULL, titre VARCHAR(60) NOT NULL, description VARCHAR(500) NULL,
  x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, rue VARCHAR(80) NULL, priorite TINYINT NOT NULL, source ENUM('tiers','agent','detresse') NOT NULL,
  ressource VARCHAR(50) NULL, jobs JSON NOT NULL, signalements INT NOT NULL DEFAULT 1, statut ENUM('nouveau','pris','clos') NOT NULL DEFAULT 'nouveau',
  pris_par JSON NULL, clos_par VARCHAR(64) NULL, clos_le DATETIME NULL,
  cloture_motif ENUM('traite','fausse_alerte','sans_suite','transfere','expire') NULL, cloture_note VARCHAR(300) NULL, expire_le DATETIME NOT NULL,
  KEY (statut, cree_le), KEY (cree_le), KEY (x, y))                                    -- (x, y) : carte des crimes
pop_tablet_police_citoyens (identifier VARCHAR(64) PK, photo VARCHAR(255) NULL, empreinte CHAR(10) NOT NULL UNIQUE,
  empreinte_fichee TINYINT(1) NOT NULL DEFAULT 0, dangereux TINYINT(1) NOT NULL DEFAULT 0, maj_le DATETIME NOT NULL)       -- sans id
pop_tablet_police_notes (identifier VARCHAR(64) NOT NULL, auteur VARCHAR(64) NOT NULL, texte TEXT NOT NULL, importante TINYINT(1) NOT NULL DEFAULT 0, RC7,
  KEY (identifier, archive, cree_le))
pop_tablet_police_vehicules (plaque VARCHAR(8) PK, signale TINYINT(1) NOT NULL DEFAULT 0, motif VARCHAR(300) NULL,
  maj_par VARCHAR(64) NOT NULL, maj_le DATETIME NOT NULL)                                                                     -- sans id
pop_tablet_police_historique (cible_type ENUM('citoyen','vehicule') NOT NULL, cible_id VARCHAR(64) NOT NULL, type VARCHAR(30) NOT NULL,
  ref_id INT NULL, texte VARCHAR(300) NOT NULL, auteur VARCHAR(64) NOT NULL, KEY (cible_type, cible_id, cree_le))
pop_tablet_police_rapports (numero VARCHAR(12) NOT NULL UNIQUE, modele_id INT NULL, type VARCHAR(20) NOT NULL, titre VARCHAR(80) NOT NULL,
  faits_le DATETIME NOT NULL, lieu VARCHAR(100) NULL, x FLOAT NULL, y FLOAT NULL, sections JSON NOT NULL, photos JSON NULL,
  statut ENUM('brouillon','publie','transmis') NOT NULL DEFAULT 'brouillon', auteur VARCHAR(64) NOT NULL, affaire_justice VARCHAR(20) NULL,
  versions JSON NULL, RC7, KEY (auteur, statut), KEY (statut, faits_le), KEY (x, y))
pop_tablet_police_rapport_liens (rapport_id INT NOT NULL, cible_type ENUM('citoyen','vehicule','agent','preuve','appel') NOT NULL,
  cible_id VARCHAR(64) NOT NULL, role VARCHAR(20) NOT NULL, UNIQUE KEY (rapport_id, cible_type, cible_id, role), KEY (cible_type, cible_id))
pop_tablet_police_rapport_modeles (nom VARCHAR(50) NOT NULL UNIQUE, type VARCHAR(20) NOT NULL, sections JSON NOT NULL,
  actif TINYINT(1) NOT NULL DEFAULT 1, ordre INT NOT NULL DEFAULT 0, systeme TINYINT(1) NOT NULL DEFAULT 0)
pop_tablet_police_amendes (numero VARCHAR(12) NOT NULL UNIQUE, identifier VARCHAR(64) NOT NULL, agent VARCHAR(64) NOT NULL, infractions JSON NOT NULL,
  montant INT UNSIGNED NOT NULL, commentaire VARCHAR(300) NULL, facture_id INT NOT NULL, statut ENUM('impayee','payee','annulee') NOT NULL DEFAULT 'impayee',
  payee_le DATETIME NULL, rapport_id INT NULL, KEY (identifier, cree_le), KEY (facture_id))
pop_tablet_police_casier (identifier VARCHAR(64) NOT NULL, infractions JSON NOT NULL, amende INT UNSIGNED NOT NULL DEFAULT 0,
  peine_mois INT UNSIGNED NOT NULL DEFAULT 0, peine_executee TINYINT(1) NOT NULL DEFAULT 0, commentaire VARCHAR(1000) NULL,
  origine ENUM('police','justice','amende') NOT NULL, agent VARCHAR(64) NOT NULL, rapport_id INT NULL, amende_id INT NULL, affaire_justice VARCHAR(20) NULL,
  sentence_id VARCHAR(40) NULL, expunged TINYINT(1) NOT NULL DEFAULT 0, expunged_by VARCHAR(64) NULL, expunged_at DATETIME NULL, expunge_ref VARCHAR(16) NULL,
  RC7, KEY (identifier, archive, expunged, cree_le))
pop_tablet_police_mandats (numero VARCHAR(12) NOT NULL UNIQUE, type ENUM('arret','perquisition','infiltration') NOT NULL, identifier VARCHAR(64) NULL,
  gang_id INT NULL, adresse VARCHAR(100) NULL, motif VARCHAR(1000) NOT NULL, infractions JSON NULL, rapport_id INT NULL,
  statut ENUM('attente','actif','refuse','leve','expire') NOT NULL DEFAULT 'attente', demande_par VARCHAR(64) NOT NULL,
  valide_par VARCHAR(64) NULL, valide_le DATETIME NULL, valide_role ENUM('police','juge') NULL, sans_juge TINYINT(1) NOT NULL DEFAULT 0,
  signature_code VARCHAR(12) NULL, signe_le DATETIME NULL, refus_motif VARCHAR(300) NULL, prolongations TINYINT NOT NULL DEFAULT 0,
  expire_le DATETIME NULL, leve_par VARCHAR(64) NULL, leve_le DATETIME NULL, leve_motif VARCHAR(300) NULL,
  KEY (identifier, statut), KEY (gang_id, type, statut), KEY (statut, expire_le))
pop_tablet_police_avis (numero VARCHAR(12) NOT NULL UNIQUE, cible_type ENUM('citoyen','inconnu','vehicule') NOT NULL, identifier VARCHAR(64) NULL,
  plaque VARCHAR(8) NULL, description VARCHAR(1000) NULL, motif VARCHAR(300) NOT NULL, danger ENUM('faible','moyen','eleve') NOT NULL,
  photos JSON NULL, position VARCHAR(100) NULL, statut ENUM('attente','actif','leve','expire') NOT NULL DEFAULT 'attente', expire_le DATETIME NOT NULL,
  cree_par VARCHAR(64) NOT NULL, leve_par VARCHAR(64) NULL, leve_motif VARCHAR(300) NULL, KEY (statut, expire_le), KEY (identifier), KEY (plaque))
pop_tablet_police_codepenal (code VARCHAR(10) NOT NULL UNIQUE, libelle VARCHAR(80) NOT NULL, description VARCHAR(500) NULL,
  categorie ENUM('contravention','delit','crime') NOT NULL, amende INT UNSIGNED NOT NULL, peine_mois INT UNSIGNED NOT NULL,
  casier TINYINT(1) NOT NULL DEFAULT 1, actif TINYINT(1) NOT NULL DEFAULT 1, ordre INT NOT NULL DEFAULT 0)
pop_tablet_police_annonces (titre VARCHAR(80) NOT NULL, texte TEXT NOT NULL, importante TINYINT(1) NOT NULL DEFAULT 0, epinglee TINYINT(1) NOT NULL DEFAULT 0,
  jusqua DATETIME NULL, portee ENUM('police','entreprise') NOT NULL, job VARCHAR(30) NOT NULL, auteur VARCHAR(64) NOT NULL, RC7, KEY (portee, job, archive, cree_le))
pop_tablet_police_annonces_lues (annonce_id INT NOT NULL, identifier VARCHAR(64) NOT NULL, lu_le DATETIME NOT NULL, PRIMARY KEY (annonce_id, identifier))  -- sans id
pop_tablet_police_preuves (numero VARCHAR(12) NOT NULL UNIQUE, type ENUM('photo','objet','empreinte','document','tablette') NOT NULL, titre VARCHAR(80) NOT NULL,
  description VARCHAR(1000) NULL, images JSON NULL, objet JSON NULL, empreinte CHAR(10) NULL, lieu VARCHAR(100) NULL, casier_id INT NULL,
  statut ENUM('enregistree','au_casier','sortie','restituee','detruite') NOT NULL DEFAULT 'enregistree',
  cadre ENUM('voie_publique','flagrant_delit','consentement','mandat','saisie_tablette','infiltration','autre') NOT NULL, mandat_id INT NULL,
  recevable ENUM('recevable','irrecevable','contestee') NOT NULL, recevabilite_motif VARCHAR(300) NULL,
  responsable VARCHAR(64) NOT NULL, cree_par VARCHAR(64) NOT NULL, RC7, KEY (statut), KEY (mandat_id), KEY (cree_par, cree_le))
pop_tablet_police_preuves_casiers (numero VARCHAR(8) NOT NULL UNIQUE, titre VARCHAR(80) NOT NULL, rapport_id INT NULL, stash_id VARCHAR(40) NULL, RC7)
pop_tablet_police_preuves_journal (preuve_id INT NOT NULL, action VARCHAR(30) NOT NULL, agent VARCHAR(64) NOT NULL,
  role ENUM('police','procureur','juge','avocat','admin') NOT NULL, commentaire VARCHAR(300) NULL, KEY (preuve_id, cree_le))   -- jamais modifiée
pop_tablet_police_formation_etapes (job VARCHAR(30) NOT NULL, titre VARCHAR(60) NOT NULL, description VARCHAR(500) NULL,
  obligatoire TINYINT(1) NOT NULL DEFAULT 1, actif TINYINT(1) NOT NULL DEFAULT 1, ordre INT NOT NULL DEFAULT 0, KEY (job, actif, ordre))
pop_tablet_police_formation_suivi (identifier VARCHAR(64) NOT NULL, job VARCHAR(30) NOT NULL, formateur VARCHAR(64) NULL, validations JSON NOT NULL,
  statut ENUM('en_cours','terminee','dispensee') NOT NULL DEFAULT 'en_cours', entree_le DATETIME NOT NULL, fin_le DATETIME NULL, UNIQUE KEY (identifier, job))
pop_tablet_police_permis_historique (identifier VARCHAR(64) NOT NULL, type VARCHAR(30) NOT NULL, motif VARCHAR(300) NOT NULL, jours INT NULL,
  retire_par VARCHAR(64) NOT NULL, retire_le DATETIME NOT NULL, rendu_par VARCHAR(64) NULL, rendu_le DATETIME NULL, rapport_id INT NULL, KEY (identifier, retire_le))
pop_tablet_police_saisies (serie VARCHAR(12) NOT NULL, proprietaire VARCHAR(64) NOT NULL, agent VARCHAR(64) NOT NULL, preuve_id INT NOT NULL,
  essais INT NOT NULL DEFAULT 0, bloque_jusqua DATETIME NULL, code_trouve TINYINT(1) NOT NULL DEFAULT 0, UNIQUE KEY (serie, preuve_id))
pop_tablet_police_avis_publics (numero VARCHAR(10) NOT NULL UNIQUE, avis_id INT NOT NULL, titre VARCHAR(60) NOT NULL, description VARCHAR(500) NOT NULL,
  photo VARCHAR(255) NULL, nom_affiche VARCHAR(64) NULL, plaque VARCHAR(8) NULL, statut ENUM('actif','retire','expire') NOT NULL DEFAULT 'actif',
  debut_le DATETIME NOT NULL, fin_le DATETIME NOT NULL, cree_par VARCHAR(64) NOT NULL, retire_par VARCHAR(64) NULL, retire_motif VARCHAR(300) NULL,
  KEY (statut, fin_le))
pop_tablet_police_infiltration_journal (mandat_id INT NOT NULL, agent VARCHAR(64) NOT NULL, action ENUM('ouverture','page','preuve') NOT NULL,
  message_ids JSON NULL, preuve_id INT NULL, KEY (mandat_id, cree_le))
```

#### EMS, mécano, justice, gang, immobilier (04) — 34 tables (dates `DATETIME`)

```sql
pop_tablet_ems_alerts (id INT AI PK, type ENUM('a_terre','secours','externe') NOT NULL DEFAULT 'a_terre', victim_identifier VARCHAR(64) NULL,
  label VARCHAR(80) NOT NULL, x FLOAT, y FLOAT, z FLOAT, status ENUM('ouverte','prise','terminee','expiree') NOT NULL DEFAULT 'ouverte',
  taken_by VARCHAR(64) NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, closed_at DATETIME NULL, close_reason VARCHAR(32) NULL,
  KEY (status, created_at), KEY (victim_identifier, status))
pop_tablet_ems_records (identifier VARCHAR(64) PK, blood_type ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-','inconnu') NOT NULL DEFAULT 'inconnu',
  allergies VARCHAR(500) NOT NULL DEFAULT '', history TEXT NULL, treatments VARCHAR(500) NOT NULL DEFAULT '', emergency_contact VARCHAR(80) NOT NULL DEFAULT '',
  updated_by VARCHAR(64) NOT NULL, updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)
pop_tablet_ems_records_history (id INT AI PK, identifier VARCHAR(64) NOT NULL, snapshot JSON NOT NULL, changed_by VARCHAR(64) NOT NULL,
  changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, archived TINYINT(1) NOT NULL DEFAULT 0, KEY (identifier, archived, changed_at))
pop_tablet_ems_reports (id INT AI PK, company_id INT NOT NULL, patient_identifier VARCHAR(64) NULL, alert_id INT NULL, author VARCHAR(64) NOT NULL,
  responders JSON NOT NULL, location VARCHAR(80) NOT NULL, occurred_at DATETIME NOT NULL, template_version INT NOT NULL, fields JSON NOT NULL,
  summary VARCHAR(120) NOT NULL, images JSON NULL, addenda JSON NULL, archived TINYINT(1) NOT NULL DEFAULT 0, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY (company_id, archived, occurred_at), KEY (patient_identifier, occurred_at), KEY (author, occurred_at))
pop_tablet_report_templates (id INT AI PK, company_id INT NOT NULL, kind VARCHAR(16) NOT NULL, version INT NOT NULL DEFAULT 1, fields JSON NOT NULL,
  created_by VARCHAR(64) NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE KEY (company_id, kind, version))
pop_tablet_price_lists (company_id INT NOT NULL, act_key VARCHAR(32) NOT NULL, label VARCHAR(60) NOT NULL, price INT UNSIGNED NOT NULL,
  active TINYINT(1) NOT NULL DEFAULT 1, sort SMALLINT NOT NULL DEFAULT 0, PRIMARY KEY (company_id, act_key))
pop_tablet_ems_certificates (id INT AI PK, number VARCHAR(16) NOT NULL UNIQUE, identifier VARCHAR(64) NOT NULL, type ENUM('arme','conduite','deces') NOT NULL,
  result ENUM('apte','inapte','deces') NOT NULL, comment VARCHAR(300) NOT NULL DEFAULT '', valid_until DATETIME NULL,
  status ENUM('valide','remplace','revoque') NOT NULL DEFAULT 'valide', doctor VARCHAR(64) NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revoked_by VARCHAR(64) NULL, revoked_reason VARCHAR(200) NULL, revoked_at DATETIME NULL, KEY (identifier, type, status))
pop_tablet_appointments (id INT AI PK, company_id INT NOT NULL, request_id INT NULL, citizen VARCHAR(64) NOT NULL, staff VARCHAR(64) NOT NULL,
  at DATETIME NOT NULL, place VARCHAR(60) NOT NULL, status ENUM('prevu','annule','honore','absent','passe') NOT NULL DEFAULT 'prevu',
  reminded TINYINT(1) NOT NULL DEFAULT 0, KEY (company_id, status, at), KEY (citizen, at), KEY (staff, at))
pop_tablet_ems_triage (id INT AI PK, title VARCHAR(60) NOT NULL, x FLOAT, y FLOAT, z FLOAT, status ENUM('ouvert','ferme') NOT NULL DEFAULT 'ouvert',
  opened_by VARCHAR(64) NOT NULL, opened_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, closed_by VARCHAR(64) NULL, closed_at DATETIME NULL, KEY (status))
pop_tablet_ems_triage_victims (id INT AI PK, triage_id INT NOT NULL, identifier VARCHAR(64) NULL, description VARCHAR(100) NOT NULL DEFAULT '',
  color ENUM('vert','jaune','rouge','noir') NOT NULL DEFAULT 'jaune', note VARCHAR(200) NOT NULL DEFAULT '',
  status ENUM('en_attente','pris_en_charge','evacuee') NOT NULL DEFAULT 'en_attente', handled_by VARCHAR(64) NULL, x FLOAT, y FLOAT, z FLOAT,
  added_by VARCHAR(64) NOT NULL, added_role ENUM('ems','police') NOT NULL, updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (triage_id))
pop_tablet_vehicle_logbook (id INT AI PK, plate VARCHAR(8) NOT NULL, company_id INT NOT NULL, mechanic VARCHAR(64) NOT NULL,
  kind ENUM('reparation','entretien','diagnostic','note') NOT NULL, lines JSON NULL, diagnostic JSON NULL, note VARCHAR(500) NOT NULL DEFAULT '',
  amount INT UNSIGNED NOT NULL DEFAULT 0, invoice_id INT NULL, warranty_days TINYINT UNSIGNED NOT NULL DEFAULT 0, warranty_until DATETIME NULL,
  archived TINYINT(1) NOT NULL DEFAULT 0, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (plate, archived, created_at), KEY (company_id, created_at))
pop_tablet_quotes (id INT AI PK, number VARCHAR(16) NOT NULL UNIQUE, company_id INT NOT NULL, author VARCHAR(64) NOT NULL, client VARCHAR(64) NOT NULL,
  plate VARCHAR(8) NOT NULL DEFAULT '', warranty_days TINYINT UNSIGNED NOT NULL DEFAULT 0, lines JSON NOT NULL, total INT UNSIGNED NOT NULL,
  status ENUM('brouillon','envoye','accepte','refuse','expire','facture','annule') NOT NULL DEFAULT 'brouillon', expires_at DATETIME NULL,
  answered_at DATETIME NULL, refuse_reason VARCHAR(100) NOT NULL DEFAULT '', invoice_id INT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY (company_id, status, created_at), KEY (client, status))
pop_tablet_mech_catalog (id INT AI PK, part_key VARCHAR(32) NOT NULL, company_id INT NOT NULL, label VARCHAR(60) NOT NULL, category VARCHAR(20) NOT NULL DEFAULT 'autre',
  price INT UNSIGNED NOT NULL, stock_item_id INT NULL, stock_per_unit TINYINT UNSIGNED NOT NULL DEFAULT 1, active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY (company_id, part_key))
pop_tablet_justice_cases (id INT AI PK, number VARCHAR(16) NOT NULL UNIQUE, title VARCHAR(80) NOT NULL, kind ENUM('penale','civile') NOT NULL DEFAULT 'penale',
  summary TEXT NULL, status ENUM('ouverte','audience','jugee','classee') NOT NULL DEFAULT 'ouverte', judge VARCHAR(64) NULL, prosecutor VARCHAR(64) NULL,
  closed_reason VARCHAR(32) NULL, closed_text VARCHAR(1000) NULL, closed_by VARCHAR(64) NULL, closed_at DATETIME NULL,
  created_by VARCHAR(64) NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, archived TINYINT(1) NOT NULL DEFAULT 0,
  KEY (status, created_at), KEY (judge), KEY (prosecutor))
pop_tablet_justice_case_parties (case_id INT NOT NULL, identifier VARCHAR(64) NOT NULL, quality ENUM('accuse','plaignant','temoin','victime') NOT NULL,
  lawyer VARCHAR(64) NULL, lawyer_status ENUM('aucun','en_attente','confirme') NOT NULL DEFAULT 'aucun',
  PRIMARY KEY (case_id, identifier, quality), KEY (identifier), KEY (lawyer))
pop_tablet_justice_links (case_id INT NOT NULL, kind ENUM('rapport','preuve') NOT NULL, ref_id INT NOT NULL, linked_by VARCHAR(64) NOT NULL,
  linked_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (case_id, kind, ref_id), KEY (kind, ref_id))
pop_tablet_justice_transmissions (id INT AI PK, kind ENUM('rapport','preuve') NOT NULL, ref_id INT NOT NULL, message VARCHAR(300) NOT NULL DEFAULT '',
  from_officer VARCHAR(64) NOT NULL, status ENUM('nouvelle','rattachee','classee') NOT NULL DEFAULT 'nouvelle', case_id INT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (status, created_at))
pop_tablet_justice_hearings (id INT AI PK, case_id INT NOT NULL, at DATETIME NOT NULL, room VARCHAR(40) NOT NULL,
  subject ENUM('comparution','plaidoirie','delibere','autre') NOT NULL DEFAULT 'comparution', participants JSON NOT NULL,
  status ENUM('prevue','tenue','reportee','annulee') NOT NULL DEFAULT 'prevue', minutes TEXT NULL, reminded JSON NOT NULL, KEY (case_id), KEY (status, at))
pop_tablet_justice_verdicts (id INT AI PK, case_id INT NOT NULL UNIQUE, judge VARCHAR(64) NOT NULL, decisions JSON NOT NULL, reasoning TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)
pop_tablet_justice_notes (id INT AI PK, case_id INT NOT NULL, author VARCHAR(64) NOT NULL, role VARCHAR(16) NOT NULL, private TINYINT(1) NOT NULL DEFAULT 0,
  text VARCHAR(1000) NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (case_id, created_at))
pop_tablet_justice_clients (id INT AI PK, lawyer VARCHAR(64) NOT NULL, company_id INT NOT NULL, client VARCHAR(64) NOT NULL,
  status ENUM('propose','actif','refuse','termine') NOT NULL DEFAULT 'propose', created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, ended_at DATETIME NULL,
  KEY (lawyer, status), KEY (client, status))
pop_tablet_justice_expunges (id INT AI PK, number VARCHAR(16) NOT NULL UNIQUE, citizen VARCHAR(64) NOT NULL, entry_ids JSON NOT NULL,
  reason ENUM('rehabilitation','erreur','amnistie','autre') NOT NULL, text VARCHAR(1000) NOT NULL, judge VARCHAR(64) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (citizen))
pop_tablet_justice_contests (id INT AI PK, case_id INT NOT NULL, evidence_id INT NOT NULL, lawyer VARCHAR(64) NOT NULL,
  reason ENUM('sans_mandat','chaine_rompue','falsification','autre') NOT NULL, text TEXT NOT NULL, journal_ids JSON NULL,
  previous ENUM('recevable','irrecevable') NOT NULL, observations TEXT NULL, status ENUM('ouverte','acceptee','rejetee') NOT NULL DEFAULT 'ouverte',
  decided_by VARCHAR(64) NULL, decision_text VARCHAR(1000) NULL, decided_at DATETIME NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY (case_id, status), KEY (evidence_id))
pop_tablet_justice_deals (id INT AI PK, case_id INT NOT NULL, identifier VARCHAR(64) NOT NULL, prosecutor VARCHAR(64) NOT NULL, terms TEXT NOT NULL,
  revoke_terms VARCHAR(1000) NOT NULL DEFAULT '', reduction TINYINT UNSIGNED NOT NULL DEFAULT 50, text_hash CHAR(64) NOT NULL,
  status ENUM('proposee','signee','homologue','refuse_accuse','refuse_juge','expiree','retiree','revoque') NOT NULL DEFAULT 'proposee',
  expires_at DATETIME NOT NULL, signed_at DATETIME NULL, signature_code VARCHAR(12) NULL, judge VARCHAR(64) NULL, judge_text VARCHAR(1000) NULL,
  judged_at DATETIME NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (case_id, status), KEY (identifier))
pop_tablet_gangs (gang_id INT PK, vault INT UNSIGNED NOT NULL DEFAULT 0, settings JSON NOT NULL, updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)
pop_tablet_gang_members (gang_id INT NOT NULL, identifier VARCHAR(64) NOT NULL UNIQUE, rank TINYINT UNSIGNED NOT NULL DEFAULT 1, nickname VARCHAR(24) NOT NULL DEFAULT '',
  pin_hash VARCHAR(128) NULL, disguise ENUM('meteo','calculatrice') NOT NULL DEFAULT 'calculatrice', joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status ENUM('actif','exclu','parti') NOT NULL DEFAULT 'actif', PRIMARY KEY (gang_id, identifier), KEY (gang_id, status))
pop_tablet_gang_ranks (gang_id INT NOT NULL, rank TINYINT UNSIGNED NOT NULL, label VARCHAR(24) NOT NULL, perms JSON NOT NULL, withdraw_cap INT UNSIGNED NOT NULL DEFAULT 10000,
  PRIMARY KEY (gang_id, rank))
pop_tablet_gang_messages (id BIGINT AI PK, gang_id INT NOT NULL, author VARCHAR(64) NOT NULL, text VARCHAR(300) NOT NULL, withdrawn TINYINT(1) NOT NULL DEFAULT 0,
  withdrawn_at DATETIME NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (gang_id, withdrawn, id))          -- jamais purgée
pop_tablet_gang_vault_moves (id BIGINT AI PK, gang_id INT NOT NULL, identifier VARCHAR(64) NOT NULL, kind ENUM('depot','retrait','admin') NOT NULL,
  amount INT UNSIGNED NOT NULL, balance_after INT UNSIGNED NOT NULL, reason VARCHAR(60) NOT NULL DEFAULT '', action_id CHAR(36) NULL UNIQUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (gang_id, created_at), KEY (identifier, created_at))
pop_tablet_gang_territories (id INT AI PK, label VARCHAR(30) NOT NULL, x FLOAT, y FLOAT, z FLOAT, radius SMALLINT UNSIGNED NOT NULL DEFAULT 150, owner_gang INT NULL)
pop_tablet_gang_ledger (id BIGINT AI PK, gang_id INT NOT NULL, kind ENUM('entree','depense','dette','partage') NOT NULL, label VARCHAR(60) NOT NULL,
  amount INT UNSIGNED NOT NULL, direction ENUM('a_recevoir','a_payer') NULL, counterpart VARCHAR(40) NOT NULL DEFAULT '', member VARCHAR(64) NULL,
  shares JSON NULL, due_date DATE NULL, debt_status ENUM('ouverte','remboursee') NULL, vault_move_id BIGINT NULL, author VARCHAR(64) NOT NULL,
  archived TINYINT(1) NOT NULL DEFAULT 0, archive_reason VARCHAR(100) NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (gang_id, archived, id))
pop_tablet_immo_properties (id INT AI PK, ref VARCHAR(10) NOT NULL UNIQUE, company_id INT NOT NULL, address VARCHAR(100) NOT NULL,
  kind ENUM('maison','appartement','local','garage','terrain') NOT NULL DEFAULT 'maison', x FLOAT NULL, y FLOAT NULL, z FLOAT NULL, owner VARCHAR(64) NULL,
  ref_price INT UNSIGNED NOT NULL DEFAULT 0, status ENUM('libre','vendu','loue') NOT NULL DEFAULT 'libre', archived TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (owner), KEY (address, archived), KEY (company_id, status))
pop_tablet_immo_mutations (id INT AI PK, property_id INT NOT NULL, kind ENUM('creation','vente','correction') NOT NULL, from_owner VARCHAR(64) NULL,
  to_owner VARCHAR(64) NULL, price INT UNSIGNED NOT NULL DEFAULT 0, agent VARCHAR(64) NOT NULL, reason VARCHAR(300) NULL, sale_id INT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (property_id, created_at))
pop_tablet_immo_sales (id INT AI PK, property_id INT NOT NULL, company_id INT NOT NULL, agent VARCHAR(64) NOT NULL, seller VARCHAR(64) NULL,
  registered_owner VARCHAR(64) NULL, buyer VARCHAR(64) NOT NULL, price INT UNSIGNED NOT NULL, commission INT UNSIGNED NOT NULL DEFAULT 0,
  status ENUM('alerte','en_attente_signatures','enregistree','annulee') NOT NULL, seller_confirmed_at DATETIME NULL, buyer_confirmed_at DATETIME NULL,
  invoice_id INT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (property_id, status), KEY (company_id, created_at))
```
(`AI PK` = `NOT NULL AUTO_INCREMENT PRIMARY KEY` ; `x FLOAT, y FLOAT, z FLOAT` = `NOT NULL` sauf mention `NULL`.)

#### Outils, navigateur, gestion pro (06) — 18 tables (dates `DATETIME`, `owner` = numéro de série)

```sql
pop_tablet_notes (id INT AI PK, owner VARCHAR(12) NOT NULL, title VARCHAR(60) NOT NULL DEFAULT '', content TEXT NULL, pinned TINYINT(1) NOT NULL DEFAULT 0,
  shared_from VARCHAR(60) NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY (owner, pinned, updated_at))
pop_tablet_map_points (id INT AI PK, owner VARCHAR(12) NOT NULL, label VARCHAR(30) NOT NULL, icon VARCHAR(16) NOT NULL DEFAULT 'etoile', x FLOAT NOT NULL, y FLOAT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (owner))
pop_tablet_media (id CHAR(32) PK, storage ENUM('local','external') NOT NULL DEFAULT 'local', path_or_url VARCHAR(300) NOT NULL, bytes INT UNSIGNED NOT NULL,
  width SMALLINT UNSIGNED NOT NULL, height SMALLINT UNSIGNED NOT NULL, refs INT NOT NULL DEFAULT 1, locked TINYINT(1) NOT NULL DEFAULT 0,
  created_by VARCHAR(64) NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (created_by, created_at))
pop_tablet_media_links (media_id CHAR(32) NOT NULL, target_type VARCHAR(20) NOT NULL, target_id VARCHAR(40) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (media_id, target_type, target_id), KEY (target_type, target_id))
pop_tablet_gallery (id INT AI PK, owner VARCHAR(12) NOT NULL, media_id CHAR(32) NOT NULL, album_id INT NULL, caption VARCHAR(100) NOT NULL DEFAULT '',
  source ENUM('camera','link') NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (owner, album_id, created_at), KEY (media_id))
pop_tablet_gallery_albums (id INT AI PK, owner VARCHAR(12) NOT NULL, name VARCHAR(30) NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (owner))
pop_tablet_nav_history (id INT AI PK, owner VARCHAR(12) NOT NULL, address VARCHAR(40) NOT NULL, path VARCHAR(60) NOT NULL, title VARCHAR(60) NOT NULL,
  visited_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (owner, visited_at))
pop_tablet_nav_favorites (id INT AI PK, owner VARCHAR(12) NOT NULL, address VARCHAR(40) NOT NULL, path VARCHAR(60) NOT NULL DEFAULT '/', title VARCHAR(40) NOT NULL,
  position SMALLINT NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (owner, position))
pop_tablet_sheets (id INT AI PK, company_id INT NOT NULL, name VARCHAR(40) NOT NULL, template VARCHAR(20) NOT NULL DEFAULT 'vide', col_widths JSON NOT NULL,
  read_level TINYINT NULL, edit_level TINYINT NULL, import_source VARCHAR(10) NULL, import_paused TINYINT(1) NOT NULL DEFAULT 0, created_by VARCHAR(64) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, archived_at DATETIME NULL, archived_by VARCHAR(64) NULL,
  KEY (company_id, archived_at), KEY (import_source))
pop_tablet_sheet_cells (sheet_id INT NOT NULL, r SMALLINT UNSIGNED NOT NULL, c SMALLINT UNSIGNED NOT NULL, raw VARCHAR(500) NOT NULL DEFAULT '',
  fmt ENUM('auto','texte','nombre','montant','date') NOT NULL DEFAULT 'auto', bold TINYINT(1) NOT NULL DEFAULT 0, bg TINYINT UNSIGNED NOT NULL DEFAULT 0,
  updated_by VARCHAR(64) NOT NULL, updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (sheet_id, r, c))
pop_tablet_sheet_imports (sheet_id INT NOT NULL, source VARCHAR(10) NOT NULL, source_id VARCHAR(40) NOT NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (sheet_id, source, source_id))
pop_tablet_stock_items (id INT AI PK, company_id INT NOT NULL, name VARCHAR(40) NOT NULL, ref VARCHAR(20) NULL, image VARCHAR(300) NULL,
  price DECIMAL(10,2) NOT NULL DEFAULT 0, quantity INT UNSIGNED NOT NULL DEFAULT 0, threshold INT UNSIGNED NOT NULL DEFAULT 0, low_alerted TINYINT(1) NOT NULL DEFAULT 0,
  auto_invoice TINYINT(1) NOT NULL DEFAULT 0, inv_item VARCHAR(50) NULL, stash_id VARCHAR(60) NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, archived_at DATETIME NULL, archived_by VARCHAR(64) NULL, KEY (company_id, archived_at, name))
pop_tablet_stock_moves (id BIGINT AI PK, item_id INT NOT NULL, company_id INT NOT NULL,
  type ENUM('entree','sortie','ajustement','facture','coffre_entree','coffre_sortie','creation') NOT NULL, delta INT NOT NULL, qty_after INT UNSIGNED NOT NULL,
  reason VARCHAR(100) NOT NULL DEFAULT '', invoice_id VARCHAR(40) NULL, by_identifier VARCHAR(64) NOT NULL, by_name VARCHAR(60) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE KEY (invoice_id, item_id), KEY (item_id, created_at), KEY (company_id, created_at))
pop_tablet_planning_slots (id INT AI PK, company_id INT NOT NULL, mode ENUM('reel','jeu') NOT NULL, day DATE NULL, start_min SMALLINT UNSIGNED NOT NULL,
  end_min SMALLINT UNSIGNED NOT NULL, label VARCHAR(30) NOT NULL, needed TINYINT UNSIGNED NOT NULL DEFAULT 0, series_id INT NULL, created_by VARCHAR(64) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, archived_at DATETIME NULL, KEY (company_id, mode, day), KEY (series_id))
pop_tablet_planning_assign (slot_id INT NOT NULL, identifier VARCHAR(64) NOT NULL, name VARCHAR(60) NOT NULL, reminded TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (slot_id, identifier), KEY (identifier))
pop_tablet_planning_avail (id INT AI PK, identifier VARCHAR(64) NOT NULL, company_id INT NOT NULL, weekday TINYINT UNSIGNED NOT NULL,
  start_min SMALLINT UNSIGNED NOT NULL, end_min SMALLINT UNSIGNED NOT NULL, KEY (company_id, identifier))
pop_tablet_planning_absences (id INT AI PK, identifier VARCHAR(64) NOT NULL, company_id INT NOT NULL, from_day DATE NOT NULL, to_day DATE NOT NULL,
  reason VARCHAR(100) NOT NULL DEFAULT '', created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, KEY (company_id, from_day, to_day))
pop_tablet_connections (id INT AI PK, identifier VARCHAR(64) NOT NULL, join_at DATETIME NOT NULL, drop_at DATETIME NULL, KEY (identifier, join_at), KEY (join_at))
```

Récapitulatif : 01 = 6, 02 = 9, 05 = 8, 03 = 25, 04 = 34 (EMS 10, mécano 3, justice 11, gang 7, immobilier 3), 06 = 18 → **100 tables**. Les tables d'apps perso n'existent pas (stockage `pop_tablet_appdata`) ; les tables d'apps tierces enregistrées par `RegisterMigration` sont préfixées `pop_tablet_app_<appId>_`.


---

## 5. Cache serveur, écritures groupées, pagination, minuteries

### 5.1 Ce qui vit en mémoire

| Contenu | Module | Chargé | Durée / invalidation | Taille max |
|---|---|---|---|---|
| Sessions (`token`, série, état, app ouverte, abonnements) | `session.lua` | à l'ouverture | supprimée à la fermeture / déconnexion | 1 par joueur |
| Fiche appareil | `device.lua` | 1re ouverture | 10 min après la fermeture ; invalidée par reset / écriture | 20 000 entrées (cache global) |
| Possession de la tablette (série) | `bridge` + `Cache` | à la demande | 10 s ; invalidée par `RemoveItem` / `SetItemMetadata` du bridge | — |
| Apps enregistrées | `registry.lua` | démarrage | permanent ; enregistrement / retrait / arrêt de ressource | 96 |
| Apps autorisées par joueur | `registry.lua` | ouverture | jusqu'à `OnJobChange`, changement de droits, retrait d'app | 1 liste / joueur |
| Entreprises, grades, `job_name → companyId` | `companies.lua` | démarrage | permanent ; invalidé par toute écriture d'entreprise | toutes |
| Grille de droits par entreprise | `perm.lua` | 1re lecture | permanent ; invalidée par ENT-GES-18/19 (`permissionsChanged`) | toutes |
| Membres connectés par entreprise / app de service | `push.lua`, `duty.lua` | chargement joueur | mis à jour par événements | — |
| Services en cours (`Service.Actifs`) | `duty.lua` | prise de service | rechargés au démarrage depuis `ent_services WHERE fin IS NULL` | — |
| Métiers et grades du framework (`GetJobs`) | `bridge` | démarrage | 5 min ; `esx:refreshJobs` / `CreateJob` | — |
| Réglages admin (`pop_tablet_settings`) | `settings` | démarrage | permanent ; écriture admin | — |
| Code pénal, modèles de rapport, tarifs EMS, catalogue mécano | apps | 1re lecture | permanent ; écriture Patron | — |
| Appels police ouverts, unités, statuts d'agents | `police/` | démarrage (appels) | mémoire, base écrite à création / prise / clôture | — |
| Mandats actifs (index `identifier`, `gang_id`), avis publics actifs | `police/` | démarrage | invalidés à chaque écriture de mandat / avis | — |
| Sites publiés par adresse, résultats de recherche du navigateur | `sites/`, `nav/` | 1re lecture | LRU 200 sites, 10 min ; invalidés par publication / masquage | 200 |
| Annuaire (liste + ouvert/fermé) | `directory/` | 1re lecture | marqué « sale » par `dutyChanged` / réglages, reconstruit à la lecture suivante | — |
| Données d'apps `appdata` par (app, portée, propriétaire) | `Cache` | 1er accès | 10 min sans lecture | 200 clés / entrée |
| Photos (fichiers) | `media.lua` | 1re demande | LRU `Config.Gallery.ServerCacheMb = 32` Mo | 32 Mo |
| Jetons opaques (`Refs`) | `refs.lua` | à l'émission | 10 min (expiration paresseuse) | 50 000 |
| `actionId` traités | `idem.lua` | à l'exécution | 2 générations de 10 min (entrée gardée 10 à 20 min) | — |
| Compteurs de fréquence | `ratelimit.lua` | à la demande | supprimés au `playerDropped` | 40 valeurs / action |
| Totaux de pagination | `db.lua` | à la demande | 30 s par clé de requête | 500 |

`Cache.Get(ns, key)`, `Cache.Set(ns, key, value, ttl)`, `Cache.Invalidate(ns, key)`, `Cache.InvalidateNs(ns)` ; expiration paresseuse à la lecture ; LRU global 20 000 entrées (`Config.Cache.MaxEntries`). Toute écriture métier passe par le module qui possède le cache (jamais un `UPDATE` direct qui laisserait un cache faux).

### 5.2 Écritures

| Type | Exemples | Chemin |
|---|---|---|
| **Immédiate** (requête attendue avant de répondre) | code de verrouillage, échecs / blocage, paiements, factures (création, paiement, refus), mouvements du compte, service (prise / fin), casier, mandats, preuves et leur journal, verdicts, coffre de gang, ventes immobilières, stock (requête atomique), réinitialisation / transfert de tablette, tout ce qu'une action déclare `critical = true` | `Db.insert` / `Db.update` (`MySQL.*.await`) ; plusieurs tables → `MySQL.transaction.await` |
| **Groupée** (`WriteQueue`) | batterie, réglages de la tablette, ordre du bureau, notifications (insertion et « lu »), journal, `appdata` non critique, visites de sites, historique du navigateur, notes, points de carte, cellules du tableur, `connections` | `WriteQueue.Upsert(table, keyCols, row)` (la dernière valeur gagne par clé) ou `WriteQueue.Insert(table, row)` |

`WriteQueue` : file mémoire par table ; minuterie unique `SetTimeout(Config.Storage.FlushInterval * 1000)` armée quand la file passe de vide à non vide ; vidage en une `MySQL.transaction` avec `INSERT … VALUES (…),(…) ON DUPLICATE KEY UPDATE` par paquets de 200 lignes ; vidage forcé à 200 éléments, au `playerDropped` (lignes du joueur), à `onResourceStop` (`MySQL.transaction.await`, 5 s max) ; échec : les éléments restent, nouvel essai dans 10 s, 3 échecs → console rouge + `Log` niveau `alert`.

### 5.3 Pagination

| Règle | Valeur |
|---|---|
| Taille | `Config.Limits.PageSize = 20` (plafond 100) ; galerie 24 (fiche) |
| Requête | `LIMIT ? OFFSET ?` avec `page ≤ 500` pour les listes d'entreprise / citoyen (index composites ci-dessus) ; le serveur demande `PageSize + 1` lignes pour calculer `hasMore` |
| Total | `COUNT(*)` seulement où l'écran affiche « Page x sur y », mis en cache 30 s par clé (filtres compris) |
| Gros historiques | journal admin, messages de gang, mouvements de stock, notifications : **pagination par curseur** (`WHERE id < ? ORDER BY id DESC LIMIT 21`), sans total |
| Recherche | côté serveur, ≥ 2 caractères, `LIKE CONCAT(?, '%')` sur colonnes indexées (préfixe) ; recherche de nom de citoyen : table framework (`users` / `players`) via le bridge, 20 résultats max, cache 30 s |
| Réponse type | `{ items = {…}, page = n, hasMore = bool, total = n|nil }` |

### 5.4 Minuteries autorisées (liste fermée)

Aucune boucle permanente. Toute minuterie passe par `server/core/timers.lua` (serveur) ou `client/session.lua` (client), qui les compte pour `/tablette_debug`.

| Côté | Minuterie | Armée quand | S'arrête quand |
|---|---|---|---|
| Serveur | `Scheduler` : un seul `SetTimeout` sur l'échéance la plus proche d'un tas (expirations d'appels police et d'alertes EMS, fermeture auto du tri après 6 h, annulation de la facture de soins après 60 min d'inconscience, fin d'annonce ville, rappels de rendez-vous / audiences / planning, verrou d'édition de site, `App.setTimeout` des apps perso, contrôle de recharge en véhicule toutes les 60 s tant qu'au moins un joueur charge) | une échéance est ajoutée | le tas est vide |
| Serveur | `WriteQueue` flush 10 s | file non vide | file vide |
| Serveur | Discord 5 s | file Discord non vide | file vide |
| Serveur | nettoyage du cache 5 min | au moins une entrée avec TTL | plus aucune entrée avec TTL |
| Serveur | tablettes posées (30 m du propriétaire) 2 s | au moins une tablette posée | plus aucune |
| Client | conditions d'usage 500 ms | ouverture | fermeture |
| Client | spectateurs d'une tablette posée (affichage) | une tablette posée à ≤ 30 m | plus aucune à portée |
| Client | mode photo, caméra fixe, caméra piéton, placement de caméra (admin) | entrée dans le mode | sortie du mode |
| Client | barre du chargeur (10 s) | utilisation du chargeur | fin / annulation |
| NUI | un `setTimeout` par bandeau ; horloge alignée sur la minute (`setTimeout` relancé) | tablette ouverte | fermeture (tout est annulé par `timers.ts`) |

Les échéances « lisibles à la consultation » ne créent pas de minuterie : impayés (72 h), expiration des mandats, avis, devis, accords de repenti, certificats — calculées à la lecture (`WHERE … AND expire_le > NOW()`) et mises à jour à la volée.

---

## 6. Bridge et adaptateurs

### 6.1 Base pop_base : ce qui est repris tel quel

Serveur : `Bridge.Framework`, `Inventory`, `GetPlayer`, `GetIdentifier`, `GetName`, `GetJob`, `HasJob`, `GetMoney`, `AddMoney`, `RemoveMoney`, `GetItemCount`, `HasItem`, `CanCarry`, `AddItem`, `RemoveItem`, `GetItems`, `SupportsMetadata`, `RegisterUsableItem`, `Notify`, `GetPlayers`, `GetCoords`, `IsNear`, `IsDead`, `OnPlayerLoaded`, `OnPlayerUnloaded`, `OnPlayerDropped`. Client : `GetPlayerData`, `GetJob`, `IsLoaded`, `OnPlayerLoaded`, `OnJobUpdate`, `Notify`, `Target.*`, `Progress`, `CancelProgress`, `IsBusy`, `OnUiClose`. Callbacks : `Callback.Register/Await/Trigger`. Kit HUD : `web/kit/pop.css`, `pop.js`.

Réglages pop_base fixés par la tablette dans `config.lua` : `Config.Locale = 'fr'`, `Config.Framework = 'auto'`, `Config.Inventory = 'auto'`, `Config.Target = 'auto'`, `Config.Notify = 'auto'`, `Config.AccentColor = '#4FA3FF'`, `Config.CallbackRateLimit = 0` (A22).

Contrôle de dérive : test `tests/pop_tablet/pop_base_sync.lua` = les 6 fichiers copiés sont identiques octet pour octet à `templates/pop_base/` ; un correctif pop_base se fait dans le modèle puis se recopie.

### 6.2 Ce qui manque à pop_base pour la tablette (ajouté par extension, sans toucher pop_base)

| Manque | Fonction ajoutée (côté) | ESX | QBCore | Qbox | Fichier |
|---|---|---|---|---|---|
| Refus du mode sans framework | `Bridge.RequireFramework()` (S) | – | – | – | `tablet/server.lua` |
| Grade complet | `Bridge.GetJobFull(src)` → `{ name, label, grade, gradeName, gradeLabel, isBoss, onDuty }` (S) | `job.grade_name == 'boss'` sinon grade max | `grade.isboss` | idem (métier principal) | `framework/*.lua` |
| Liste des métiers | `Bridge.GetJobs()` → `{ [job] = { label, grades = { [n] = { name, label, salary, isBoss } } } }` (S) | `ESX.GetJobs()` sinon `jobs` + `job_grades` | `QBCore.Shared.Jobs` (clés `'0'` → nombres) | `exports.qbx_core:GetJobs()` | idem |
| Changement de métier serveur | `Bridge.OnJobChange(cb(src, job, oldJob))` (S) | `esx:setJob` | `QBCore:Server:OnJobUpdate` | idem (émis par qbx_core) | idem |
| Personnage hors ligne | `Bridge.GetCharName(identifier)`, `Bridge.GetCharInfo(identifier)` → `{ firstname, lastname, dob, sex, height }`, `Bridge.GetPlayerFromIdentifier(id)` (S) | `users` | `players.charinfo` (JSON) | idem | idem |
| Embauche / grade (en ligne ou non) | `Bridge.SetPlayerJob(srcOrIdentifier, job, grade)`, `Bridge.GetEmployees(job)` (S) | `setJob` / `UPDATE users` | `SetJob` / `players.job` (`JSON_UNQUOTE(JSON_EXTRACT())`) | `SetPlayerPrimaryJob` / `AddPlayerToJob` / `GetGroupMembers` | idem |
| Indicateur de service | `Bridge.SetDutyFlag(src, onDuty)` (S) | `setJob(job, grade, onDuty)` (Legacy) | `SetJobDuty` | `exports.qbx_core:SetJobDuty` | idem |
| Création de métiers et grades | `Bridge.CreateJob(job, label, grades)`, `Bridge.SaveGrades(job, grades)` (S) ; réapplication au démarrage depuis `company_grades.managed = 1` | `jobs` / `job_grades` + `ESX.RefreshJobs()` | `QBCore.Functions.AddJob` / `UpdateJob` | `CreateJob` / `UpsertJobGrade` / `RemoveJobGrade` | idem |
| Argent hors ligne | `Bridge.AddMoneyOffline(identifier, account, amount)` (S) | `users.accounts` | `players.money` | `exports.qbx_core:AddMoney(citizenid…)` | idem |
| Compte société | `Bridge.Society.GetMoney / AddMoney / RemoveMoney(companyId, amount, reason)` (S) → adaptateur banque (6.3) | `esx_addonaccount` `society_<job>` | `qb-banking` v2 sinon `qb-management` | `Renewed-Banking` sinon `qb-banking` | `tablet/server.lua` + `bank/*` |
| Argent sale | `Bridge.GetDirtyMoney / AddDirtyMoney / RemoveDirtyMoney(src, amount)` (S) | compte `black_money` | objet `markedbills` (`info.worth` / `metadata.worth`) | idem | `framework/*.lua` |
| Mort / réveil sans boucle | `Bridge.OnPlayerDeath(cb)`, `Bridge.OnPlayerRevived(cb)`, `Bridge.Down[src]` (S) ; relais client `death.lua` | client `esx:onPlayerDeath` / `esx:onPlayerSpawn`, `esx_ambulancejob:revive` | serveur `hospital:server:SetDeathStatus` / `SetLaststandStatus` ; client `QBCore:Player:SetPlayerData` | state bag `isDead` (qbx_medical) ; client `QBCore:Player:SetPlayerData` | `framework/*.lua`, `tablet/client.lua` |
| Véhicules | `Bridge.GetVehicles(identifier)`, `Bridge.FindPlate(plate)` (S) | `owned_vehicles` | `player_vehicles` | idem (qbx_vehicles) ; `Config.Vehicles.Table` | `framework/*.lua` |
| Objet tablette par série | `Bridge.HasTablet(src)`, `Bridge.HasTabletSerial(src, serial)`, `Bridge.GetTabletSerials(src)`, `Bridge.SetItemMetadata(src, slot, meta)` (S) | ox / qs / qb / pop_inventory ; inventaire ESX de base = mode personnage | idem | idem | `inventory/metadata.lua` |
| Permis | `Bridge.GetLicenses(identifier)`, `Bridge.SetLicense(identifier, type, has)` (S) | `esx_license` (`user_licenses`) | `metadata.licences` | idem | `licenses/*` |
| Gang natif | `Bridge.GetGang(src)`, `Bridge.SetGang(identifier, gang, grade)` (S, si `Config.Gang.Source = 'gang'`) | – (`job2` via `Config.Gang.Source = 'job2'`) | `PlayerData.gang`, `SetGang` | `AddPlayerToGang` | `framework/*.lua` |
| Prison | `Bridge.Jail.Send(target, minutes, data)` (S) → adaptateur prison | `esx_jail` / `qalle_jail` | `qb-prison` | `qbx_prison` / `rcore_prison` | `jail/*` |
| Dispatch tiers | faux exports et événements (6.3) | – | – | – | `dispatch/*` |
| Menottes | `Bridge.IsHandcuffed()` (C) | `IsPedCuffed` + state bag `isHandcuffed` | `metadata.ishandcuffed` | idem | `cuffs/default.lua` |
| Essence | `Bridge.GetFuel(vehicle)` (C) → `{ pct, estimated }` | ox_fuel (state bag `fuel`, lu côté serveur), LegacyFuel, cdn-fuel, ps-fuel (exports client), sinon `GetVehicleFuelLevel` | idem | idem | `fuel/*` |
| Entrée / sortie de véhicule | `Bridge.OnVehicleEnter(cb)` (C) | `gameEventTriggered` `CEventNetworkPlayerEnteredVehicle` (aucune boucle) | idem | idem | `tablet/client.lua` |
| Admin tablette | `Perm.IsAdmin(src)` = console ou `IsPlayerAceAllowed(src, 'pop.tablet.admin')` (le `Bridge.IsAdmin` de pop_base, ACE `pop.admin`, n'est pas utilisé) | – | – | – | `server/core/perm.lua` |
| Langue par joueur, JSON, `{nom}` | `T(key, params, lang)` (S) ; NUI `t()` | – | – | – | `server/core/i18n.lua` |
| OneSync | contrôle au démarrage `GetConvar('onesync', 'off') ~= 'off'`, sinon arrêt « [pop_tablet] OneSync is required. » | – | – | – | `server/boot.lua` |

À remonter plus tard dans `templates/pop_base` (utile à tous les scripts POP) : `GetJobFull`, `GetJobs`, `OnJobChange` serveur, `GetCharName/GetCharInfo`, `GetPlayerFromIdentifier`, `AddMoneyOffline`, `Society.*`, `OnPlayerDeath/OnPlayerRevived`, `GetVehicles/FindPlate`, `SetItemMetadata`, `IsHandcuffed`, `GetFuel`, option de limite par callback (`Callback.Register(name, fn, { rate })`), langues pt-BR / th / id / ro, `L(key, params, lang)`. Quand c'est fait, la fonction disparaît de l'extension de la tablette (le test 6.1 le signale).

### 6.3 Adaptateurs

Registre (défini dans `bridge/tablet/server.lua`, ouvert) :

```lua
-- bridge/bank/qb-banking.lua (exemple complet du format)
if not PopAdapters.wants('bank', 'qb-banking') then return end   -- valeur forcée dans Config, ou 'auto' + ressource démarrée
PopAdapters.register('bank', 'qb-banking', {
  GetMoney    = function(account) return exports['qb-banking']:GetAccountBalance(account) or 0 end,
  AddMoney    = function(account, amount, reason) return exports['qb-banking']:AddMoney(account, amount, reason) ~= false end,
  RemoveMoney = function(account, amount, reason) return exports['qb-banking']:RemoveMoney(account, amount, reason) ~= false end,
})
```

Choix : `custom.lua` s'il existe > valeur forcée dans `config.lua` > détection automatique dans l'ordre du tableau. Un adaptateur qui lève une erreur est désactivé (console une fois) et l'action renvoie une erreur propre (`fonds_entreprise` pour la banque).

| Catégorie | Réglage | Fournis (ordre de détection) | Interface à respecter | Sans adaptateur |
|---|---|---|---|---|
| Banque société | `Config.SocietyAccount = 'auto'` | ESX `esx_addonaccount` ; QBCore `qb-banking`, `qb-management` ; Qbox `Renewed-Banking`, `qb-banking` | `GetMoney(account)`, `AddMoney(account, n, reason)`, `RemoveMoney(account, n, reason)` → nombre / bool ; `account` = `society_<job>` (ESX) ou `<job>` | « Compte d'entreprise indisponible », actions d'argent du compte refusées, le reste marche |
| Prison | `Config.Signals.SentenceJail = 'none'` | `esx_jail`, `qalle_jail`, `qb-prison`, `qbx_prison`, `rcore_prison` | `Send({ source, identifier }, minutes, { reason, sentenceId })` → bool (joueur hors ligne : peine gardée et appliquée à sa connexion par l'adaptateur s'il le permet, sinon journal) | signal `pop_tablet:sentencePronounced` seul |
| Dispatch tiers | `Config.Dispatch.Compat = { 'ps-dispatch', 'cd_dispatch', 'core_dispatch' }` (+ `'esx_service'`) | chargés **seulement si la vraie ressource n'est pas démarrée** ; faux exports par `AddEventHandler('__cfx_export_<ressource>_<export>', function(setCb) setCb(fn) end)` et faux événements (`ps-dispatch:server:notify`, `cd_dispatch:AddNotification`, `core_dispatch:addCall`, `esx_service:*`) | convertir vers `DispatchAlert(alert)` (format BASE-API-10) ; coordonnées toujours relues côté serveur ; fréquence 3 / 10 s par joueur | appels manuels, détresse, `/secours`, export `DispatchAlert` |
| Inventaire | `Config.Inventory = 'auto'` | pop_base (pop_inventory, ox, qs, qb, ps, framework) + `inventory/metadata.lua` (série) | `HasTabletSerial`, `GetTabletSerials`, `SetItemMetadata` | mode « une tablette par personnage » (BASE-OBJ-15) |
| Ciblage | `Config.Target = 'auto'` | pop_base (ox_target, qb-target, prompt natif) | `Bridge.Target.*` | prompt natif |
| Essence | `Config.Fuel = 'auto'` | ox_fuel, LegacyFuel, cdn-fuel, ps-fuel, native | `Get(vehicle)` → `pct`, `estimated` | `GetVehicleFuelLevel`, marqué « estimation » |
| Menottes | `Config.Cuffs = 'auto'` | défaut (native + state bag + metadata) | `IsHandcuffed()` → bool | native seule |
| Permis | `Config.Licenses = 'auto'` | `esx_license`, metadata QBCore / Qbox | `Get(identifier)`, `Set(identifier, type, has)` | onglet permis caché |

Ajouter son adaptateur (documenté dans `docs/adaptateurs.md`, rappelé dans `CLAUDE.md`) : 1) copier `bridge/<catégorie>/custom.example.lua` en `custom.lua` ; 2) remplir les fonctions de l'interface (exports de son script) ; 3) `ensure pop_tablet` ; 4) la console affiche `bank: custom` (ligne de résumé BASE-MOT-19) et l'assistant d'installation (BASE-MOT-15) le montre en vert. Aucun fichier chiffré à toucher.

---

## 7. Anti-triche et sécurité

### 7.1 Modèle de menace

Hypothèse : le tricheur exécute du Lua arbitraire côté client (exécuteur), ouvre les devtools de la NUI, rejoue et forge n'importe quel événement réseau, modifie toute valeur envoyée. **Seul le serveur fait foi.**

| Menace | Exemple | Règle serveur (où) |
|---|---|---|
| Événement forgé | `TriggerServerEvent('pop_tablet:...')` inventé, ou callback avec faux jeton | un seul callback + 9 événements listés (§ 3.7) ; tout autre nom n'existe pas ; jeton 32 car. aléatoire (`math.random` réinitialisé par `os.time()` + compteur + `GetGameTimer()`, haché), lié à la source, détruit à la fermeture ; jeton faux → `session` + `Log` catégorie `triche` (`gateway.lua`) |
| NUI devtools | appeler `fetch('https://pop_tablet/req', …)` avec une action admin, réactiver un bouton grisé | la NUI n'a ni jeton ni identifiants ; chaque action revérifie accès, droit, service, admin ACE (`gateway.lua` 7–9) ; un bouton visible n'autorise rien |
| Usurpation d'identité ou de cible | envoyer `identifier`, `source`, `companyId`, `grade` dans `data` | champs non déclarés supprimés (schéma) ; identité = `ctx` construit depuis `source` ; cibles = jetons `Refs` émis par le serveur (10 min, liés au joueur qui les a reçus) ; `companyId` d'un sélecteur (C16) revérifié contre les métiers réels |
| Injection SQL | `'; DROP TABLE users; --` | requêtes préparées seulement ; tri sur liste blanche ; test unitaire de non-régression |
| Montant falsifié / négatif / énorme | facture de 999 999 999 $, quantité −5 | schéma `int` + bornes ; plafonds serveur (`MaxAmount`, plafond de grade `ent_permissions.plafond`, amende ≤ barème) ; totaux **recalculés** par le serveur à partir des lignes ; bridge refuse tout montant ≤ 0 |
| Double paiement / double clic / rejeu | deux clics « Payer », rejouer un `actionId`, deux joueurs paient la même facture | `idem.lua` (même réponse, en cours partagé) ; verrou mémoire `PayLock[factureId]` pendant le paiement ; `UPDATE … SET statut = 'payee' WHERE id = ? AND statut = 'attente'` (1 ligne attendue) ; unicité `uid`, `payments.action_id`, `gang_vault_moves.action_id`, `stock_moves (invoice_id, item_id)` ; remboursement automatique si l'ajout échoue après le retrait (`payments.lua`) |
| Distance | payer, recruter, soigner à 500 m | `near.lua` : `GetEntityCoords(GetPlayerPed())` des deux côtés, même `GetPlayerRoutingBucket`, cible vivante ; 3 m (`NearDistance`), prison 10 m, tri 10 m, posée 2 m ; caméra piéton 300 m |
| Abus de droits | Chef qui renvoie un Patron, recrue qui fait une amende de 50 000 $ | `Perm.Has` + niveau relu à chaque appel ; « sous son grade » comparé côté serveur ; plafonds par niveau ; ACE admin revérifiée à chaque appel admin ; actions admin journalisées `admin = true` |
| Objet tablette | dupliquer la série, ouvrir sans objet | série écrite **seulement** par le serveur (`SetItemMetadata`) ; possession revérifiée (cache 10 s) ; tablette `disabled` refusée ; aucun événement client n'ajoute d'objet |
| XSS / injection d'affichage | `<img src=x onerror=…>`, codes couleur GTA `~r~`, caractères invisibles RTL | `Sanitize.text` (contrôle, invisibles, codes GTA, longueur sans coupure) ; NUI Preact = texte échappé, aucun `innerHTML` (contrôle statique) ; sites rendus depuis des blocs JSON en liste blanche (aucun HTML libre) ; textes des notifications natives débarrassés de `~` et `^` ; CSP stricte |
| Images | lien piégé, traceur d'IP, SVG avec script, fichier énorme | `Sanitize.imageUrl` (https, domaine exact ou sous-domaine, extension png/jpg/jpeg/webp/gif, ≤ 300 car.) ; `media:<id>` vérifié en base ; CSP `img-src` limitée aux domaines autorisés ; captures : en-tête `RIFF….WEBP`, ≤ 600 Ko, miniature ≤ 40 Ko, 1 / 5 s, 30 / jour, quota 50 |
| Saturation | 1 000 requêtes / s, données de 5 Mo, JSON très imbriqué | 32 Ko, profondeur 5, fréquence action + globale, pagination plafonnée, envois latents avec ticket et taille déclarée |
| App perso malveillante ou boguée | boucle infinie, accès SQL, lecture d'une autre app, fuite d'IP | environnement Lua fermé + compteur d'instructions + coupure auto ; isolation `app_id` côté serveur ; iframe sans `allow-same-origin` ; CSP imposée par MAN-06 ; `pop-check` au démarrage (BLOQUANT = refus) |
| Fuite de secrets | webhook visible, clé d'upload | convars **`set`** (jamais `setr`, qui réplique aux clients) ; jamais envoyés au client ni écrits au journal ; avertissement si un lien est trouvé dans `config.lua` |
| Mort / menottes contournés | ouvrir la tablette mort via la NUI | le client refuse, **et** le serveur refuse les actions si `Bridge.Down[src]` (sauf lecture du code) et ferme la session à `OnPlayerDeath` |

### 7.2 Journal admin et Discord

| Élément | Règle |
|---|---|
| Écriture | `Log({ source, app, action, category, target, targetIdentifier, companyId, summary, before, after, level })` — seule fonction ; complétée côté serveur (acteur, nom RP ou « Console », date, `GetInvokingResource()`) ; `before`/`after` JSON ≤ 8 Ko ; jamais de code, mot de passe ou lien |
| Catégories | `admin`, `money`, `alert`, `police`, `service`, `sites`, `triche`, `moderation`, `perso` |
| Refus suspects | `session` (faux jeton), `pas_droit`, `doublon`, `invalide`, dépassements de fréquence : regroupés 1 ligne / minute / joueur avec compteur, catégorie `triche`, niveau `warn` (alert au-delà de 3 / min) |
| Lecture | app Admin > Journal : filtres app, catégorie, acteur, cible, entreprise, période ; curseur ; export CSV côté NUI de la page affichée |
| Discord | `discord.lua` : convars `pop_tablet_webhook` et `pop_tablet_webhook_<categorie>` ; catégories actives `Config.Discord.Categories` ; file, 10 embeds par message, 1 message / 5 s, `retry_after` sur 429, 404 → message console 1 / h et file vidée, > 1 000 en attente → les plus anciennes `info` abandonnées ; `allowed_mentions = { parse = {} }` (aucune mention) ; embed en `Config.Locale` |

### 7.3 CSP imposée aux apps perso (MAN-06)

Première balise de `<head>` de chaque `apps_perso/<id>/index.html` (copiée du modèle, vérifiée par `pop-check` et au démarrage) :

```html
<meta http-equiv="Content-Security-Policy" content="default-src 'self' https://cfx-nui-pop_tablet; script-src 'self' https://cfx-nui-pop_tablet; style-src 'self' 'unsafe-inline' https://cfx-nui-pop_tablet; img-src 'self' data: https://cfx-nui-pop_tablet; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
```

Les images externes d'une app perso passent par `PopApp.pickImage()` (galerie) : la tablette fournit une URL `data:` déjà contrôlée.

---

## 8. API pour développeurs et apps perso

### 8.1 Exports serveur (`exports.pop_tablet:<Nom>`)

Règles : chaque export renvoie `ok, resultat` ou `false, code` ; l'appelant est noté (`GetInvokingResource()`) ; une ressource n'agit que sur ses propres apps ; documentation et exemples dans `docs/api.md`.

| Export | Signature | Retour |
|---|---|---|
| `GetPlayer` / `GetPlayerByIdentifier` | `(source)` / `(identifier)` | `{ source, identifier, name, job = { name, label, grade, gradeLabel, level }, companyId, onDuty, hasTablet, serial }` |
| `IsOnDuty` · `SetDuty` · `CountOnDuty` · `GetWeeklyHours` | `(source)` · `(source, state)` · `(companyId)` · `(identifier, companyId, weekOffset?)` | `companyId|false` · `ok` · `n` · secondes |
| `HasAccess` · `HasPermission` | `(source, appId, permission?)` · `(source, companyId, key)` | bool |
| `RegisterApp` · `UnregisterApp` · `RegisterAction` | `(def)` (BASE-API-02) · `(appId)` · `(appId, actionDef)` (§ 3.3) | `ok, err` (`id_pris`, `id_invalide`, `champ_manquant:<champ>`) |
| `OpenScreen` · `Notify` | `(source, appId, screen, params)` · `(target, notif)` (BASE-API-04) | `ok` · `ok, n` |
| `Log` | `(entry)` | `ok` |
| `DataGet` · `DataSet` · `DataDelete` · `DataList` | `(appId, scope, key)` · `(appId, scope, key, value, opts)` · `(appId, scope, key)` · `(appId, scope, { prefix, page, pageSize })` | valeur · `ok` · `ok` · `{ items, total, page }` |
| `Pay` | `({ actionId, from, to, amount, reason, app, requireNear, payer })` | `ok, paymentId|code` (`pas_argent`, `trop_loin`, `doublon`, `montant`, `serveur`) |
| `CreateInvoice` · `GetInvoice` | `({ companyId, target, lines, note, kind, metadata, externalRef, refusable, actionId })` · `(idOrNumber)` | `ok, invoiceId` · facture |
| `EmitInvoicePaid` · `OnInvoicePaid` | réservé à la tablette (Factures) · `(cb(data))` | – · id d'abonnement |
| `EmitSentence` · `OnSentence` | `(data)` (BASE-API-08, police / justice) · `(cb(data))` | `ok, sentenceId` |
| `DispatchAlert` · `PoliceAlert` · `CreateEmsAlert` | `(alert)` (BASE-API-10) ; alias service police / EMS (accepte `titre`, `priorite` 1/2/3) | `ok, callNumber` |
| `HasActiveWarrant` · `VerifyWarrantSignature` · `CasierAdd` | `(identifier, type?)` → `{ actif, signe, numero }` · `(code)` · `(identifier, entry)` | |
| `SetCameraOnline` · `AddCamera` · `GetCertificate` | `(id, online)` · `(def)` · `(identifier, type)` | |
| `CreateRequest` | `(companyId, { type, message, demandeur, payload })` | `ok, numero` |
| `RegisterMigration` · `AddLocale` · `GetLimit` | `(appId, version, sql)` · `(lang, table)` · `(key)` | |
| `CompanyCreateFromJob` | `(job, opts)` | `ok, companyId` |
| `ResetTablet` · `ReplaceTablet` · `TransferTabletData` | `(serial, opts)` · `(source, oldSerial, opts)` · `(oldSerial, newSerial, opts)` | codes BASE-OBJ-08 |
| `IsVehicleFlagged` | `(plate)` | `{ signale, motif }` (jamais « volé ») |
| `GetPropertyOwner` · `GetPropertiesOf` | `(address|ref)` · `(identifier)` | |

Export client : `exports.pop_tablet:Open(appId, screen, params)`, `exports.pop_tablet:IsOpen()`. State bag répliqué : `Player(src).state.popDuty` (`companyId` ou `false`, écrit par le serveur seulement).

### 8.2 Signaux (événements serveur locaux, jamais déclenchables par un client)

Liste et formats : `00-sommaire.md` § 3.3 (fait foi). Implémentation : `signals.lua` émet `TriggerEvent('pop_tablet:<nom>', data)` **uniquement** côté serveur ; un `RegisterNetEvent` portant un de ces noms est interdit (contrôle statique). Les abonnements `OnSentence` / `OnInvoicePaid` appellent les rappels dans un `pcall` (une erreur d'un script tiers ne casse pas la tablette). Écoutés : `pop_tablet:dispatchAlert` (même format que `DispatchAlert`, émis côté serveur par un script tiers).

### 8.3 SDK NUI des apps perso (`apps_perso/_sdk/pop-app.js`, API version 1)

Liste fermée de PERSO-04 + PERSO-09 : `ready`, `context`, `t`, `call`, `storage.get/set/remove/list`, `notify`, `confirm`, `setTitle`, `pickImage`, `el`, `on`/`off` (`show`, `hide`, `theme`, `push`), `close`, `version`, `ui.empty`, `ui.skeleton`, `ui.error`. Script classique (pas de module ES : origine opaque), ≤ 20 Ko, aucune dépendance. Les apps de **ressources tierces** (`RegisterApp` avec `ui = 'nui://<res>/…'`) utilisent le même SDK en l'incluant par `https://cfx-nui-pop_tablet/apps_perso/_sdk/pop-app.js` ; leurs actions sont déclarées par `RegisterAction` (Lua complet de leur ressource, pas de bac à sable).

### 8.4 Contrat d'une app perso (manifeste)

Champs, formats et règles : PERSO-01 (`id`, `name`, `description`, `version`, `apiVersion = 1`, `author`, `icon`, `access`, `scopes`, `server`, `template`). Fichiers : `app.lua` (seulement `PopApp.register`), `index.html` (CSP MAN-06 en tête), `app.js`, `style.css`, `icon.svg|png`, `server.lua` (facultatif), `settings.lua` (facultatif, `return { … }`), `locales/<code>.json`. Chargement : `app.lua` exécuté par le manifeste ; `PopApp.register` relève le dossier par `debug.getinfo(2, 'S').source`, refuse si dossier ≠ `id` ; `server.lua` lu par `LoadResourceFile` et exécuté par `load(code, '@apps_perso/<id>/server.lua', 't', env)`. Objet serveur `App` : liste fermée PERSO-05 ; `ctx` marqué interne (table gardée dans une table faible du cœur, refusée si copiée). Environnement : PERSO-05 étape 1 ; compteur `debug.sethook(fn, '', 1000)` compté jusqu'à `Config.Apps.MaxInstructions` ; si `debug.sethook` est absent : coupure au-delà de 500 ms trois fois (PERSO-05).

### 8.5 Outil `tools/pop-check.js`

Node ≥ 18 sans dépendance ; règles MAN-01..06, PERF-01..06, SEC-01..06, ISO-01..02, LANG-01 (PERSO-08 + A20) ; même jeu de fixtures que la version Lua (`server/core/perso/check.lua`) : `tests/pop_tablet/fixtures/apps/<cas>/` avec le résultat attendu ; les deux implémentations doivent donner la même sortie (test de parité).

### 8.6 Guide IA livré (`pop_tablet/CLAUDE.md`)

Fichier bilingue (FR puis EN), ≤ 300 lignes, en tête « API version 1 · chemins relatifs à `pop_tablet/` ». Sections dans cet ordre :

| # | Section | Contenu exact |
|---|---|---|
| 1 | Ce qui peut être modifié | `config.lua`, `locales/`, `bridge/` (adaptateurs), `defaults/`, `apps_perso/` sauf `_sdk/` ; le reste est chiffré ; une mise à jour écrase `_sdk/` |
| 2 | Créer une app en 5 étapes | copier `_modele`, renommer l'id (= dossier), retirer `template = true`, écrire `index.html`/`app.js`/`server.lua`, `node tools/pop-check.js apps_perso/<id>`, `ensure pop_tablet` |
| 3 | Règles obligatoires | les 7 règles de PERSO-03 **mot pour mot** + « Gardez la balise CSP du modèle en tête de index.html. » |
| 4 | API | renvoi `docs/api-apps.md` + tableau d'une ligne par fonction `PopApp.*` et `App.*` |
| 5 | Exemples | `exemple_notes` (données perso), `exemple_tableau` (données d'équipe), `exemple_pourboire` (argent) : quoi copier selon le besoin |
| 6 | Adaptateurs | écrire `bridge/<catégorie>/custom.lua` (banque, prison, dispatch, essence, menottes, permis) : interface, exemple, test |
| 7 | Erreurs fréquentes | 8 erreurs + correction : `template = true` oublié, id ≠ dossier, `data.identifier` (SEC-04), `innerHTML` (SEC-01), `fetch` externe (SEC-03), `while true` (PERF-01), clé absente de `fr.json` (LANG-01), CSP retirée (MAN-06) |
| 8 | Vérifier avant de livrer | pop-check sans bloquant ; textes fr et en ; tablette fermée puis rouverte ; test à deux joueurs ; `resmon` à 0,00 ms tablette fermée |

---

## 9. Tests

### 9.1 Sans serveur (à lancer avant chaque push sur `main`)

`scripts/verifier-pop-tablet.sh` enchaîne, et s'arrête au premier échec :

| # | Vérification | Commande / outil | Critère |
|---|---|---|---|
| 1 | Lint Lua | `luacheck "resources/[pop]/pop_tablet" templates` (`.luacheckrc` complété : globales `Tablet`, `PopApp`, `PopAdapters`, `T`, `Sanitize`, `Log`, `Perm`, `Notify`, `RateLimit`, `WriteQueue`, `Cache`, `Push`, `Registry`, `Refs`, `Db`, `Timers`) | 0 avertissement, 0 erreur |
| 2 | Syntaxe Lua 5.4 | `luac5.4 -p` sur chaque `.lua` de la ressource | aucun échec (pas d'extension CfxLua : pas de `+=`, pas de hash entre accents graves) |
| 3 | Tests unitaires Lua | `lua5.4 tests/pop_tablet/run.lua` | 100 % verts |
| 4 | Types et build NUI | `cd ui/pop_tablet && npm ci && npm run build` | `tsc` sans erreur, budgets respectés, `web/dist` à jour (git diff vide après build) |
| 5 | Syntaxe JS | `node --check` sur `web/dist/**/*.js` (module grâce à `dist/package.json`), `apps_perso/**/*.js`, `tools/pop-check.js` | aucun échec |
| 6 | Tests unitaires NUI | `npm test` (node:test) | verts |
| 7 | Tests NUI Playwright | `npm run e2e` (Chromium) | verts |
| 8 | Apps perso | `node tools/pop-check.js apps_perso` | 0 bloquant, 0 alerte (modèle et exemples) |
| 9 | Contrôles statiques | `lua5.4 tests/pop_tablet/static.lua` | voir 9.2 |
| 10 | Langues | `lua5.4 tests/pop_tablet/locales.lua` | toutes les clés utilisées existent en `fr` et `en` ; JSON valides ; aucune clé orpheline ; liste des manques des 8 autres langues (avertissement) |
| 11 | Couverture des fiches | `lua5.4 tests/pop_tablet/coverage.lua` | chaque ID de fiche (363, hors 3 supprimées) apparaît au moins une fois dans un commentaire `-- [ID]` côté serveur ou `// [ID]` côté NUI, ou dans un test |

### 9.2 Contrôles statiques (`static.lua`, recherche de motifs sur le source)

Interdits hors fichiers autorisés : `while true`, `Wait(0)`, `CreateThread` (autorisé seulement dans `client/conditions.lua`, `props.lua`, `photo.lua`, `camera_fixed.lua`, `bodycam.lua`, `charge.lua`, `evidence_locker.lua`, `server/core/timers.lua`), `SetTimeout` hors `timers.lua`/`writequeue.lua`/`discord.lua`, appel direct `ESX.` / `QBCore.` / `qbx_core` hors `bridge/`, concaténation dans une chaîne SQL (`'SELECT …' ..`), `RegisterNetEvent` hors de la liste § 3.7, `TriggerClientEvent(…, -1, …)`, `GetConvar('pop_tablet_webhook` hors `discord.lua`, `setr` dans `install/server.cfg.txt`, `innerHTML`/`dangerouslySetInnerHTML` dans `ui/` et les exemples.

### 9.3 Tests unitaires Lua (`tests/pop_tablet/`)

Lanceur maison `run.lua` (aucune dépendance : `describe`/`it`/`expect` en 80 lignes) ; `mocks/fivem.lua` (`GetGameTimer` pilotable, `SetTimeout` sur horloge virtuelle, `TriggerEvent` enregistré, `GetPlayerPed`/`GetEntityCoords` sur positions fixées, `Player().state`, `IsPlayerAceAllowed`), `mocks/oxmysql.lua` (base en mémoire minimale : tables Lua, `insert/update/scalar/query/transaction`, contrôle des unicités), `mocks/bridge.lua` (3 profils ESX / QBCore / Qbox). Les modules du cœur sont écrits pour être chargés hors FiveM (`dofile`), sans effet de bord au chargement.

| Suite | Cas clés |
|---|---|
| `sanitize` | contrôle et invisibles retirés, `~r~` retiré, 61 car. dans 60 → `trop_long`, emoji = 1 caractère, espaces seuls → vide, URL d'image (imgur ok, `imgur.com.evil.com` refusé, `http://` refusé, `javascript:` refusé, extension) |
| `schema` | champs non déclarés supprimés, types, bornes, profondeur 6 refusée, 32 Ko + 1 refusé |
| `ratelimit` | 6e en 2 s refusée, passe après 10 s, globale 60, alerte au 3e dépassement |
| `idem` | même `actionId` → même réponse sans 2e exécution ; requête concurrente attend le résultat ; `actionId` d'un autre joueur → `doublon` ; rotation des générations |
| `gateway` | ordre des 13 contrôles (le premier échec gagne), erreur Lua → `serveur` sans trace renvoyée |
| `perm` | `autoLevels` (1 à 7 grades), Patron a tout, « sous son grade », plafond Recrue 500 $, admin |
| `payments` / `factures` | totaux recalculés, plafond, part employé 10 % figée, paiement unique sous double requête, remboursement si l'ajout échoue, majoration 10 % à la lecture après 72 h |
| `police` | amende ≤ barème, Recrue ≤ 2 500 $, peine ≤ 120 mois, mandat 7 jours / 2 prolongations, juge requis sauf aucun juge en service (`sans_juge`), recevabilité calculée, infiltration lisible seulement après signature |
| `justice` / `gang` / `immo` / `stock` | verdict unique, réduction de repenti 10–75 %, retrait coffre ≤ plafond et 3 × / 24 h, alerte vendeur ≠ propriétaire, stock jamais négatif (manque noté) |
| `writequeue` | 20 écritures → 1 transaction, dernière valeur gagne, vidage à 200, échec puis nouvel essai, vidage à l'arrêt |
| `timers` | ordonnanceur : une seule minuterie armée, aucune quand vide, ordre des échéances |
| `migrations` | base vide → v1 complète ; rejeu = aucun changement ; migration interrompue reprise ; `DROP` d'app refusé ; `install.sql` identique à `Migrations[1]` |
| `i18n` | repli langue → `Config.Locale` → `fr` → clé ; `{nom}` et `%s` ; paramètre `<b>` laissé en texte |
| `perso` | sandbox sans `MySQL`/`exports`/`load` ; `while true` interrompu ; coupure après 3 ; isolation `app_id` / owner ; parité pop-check Lua = Node sur les fixtures |
| `bridge` | par profil : `GetJobFull`, mort/réveil appelés une fois par changement, faux `revived` ignoré si `IsDead`, `AddMoney` négatif refusé, `FindPlate` normalisée |

### 9.4 Tests NUI (Playwright, page simulée)

`ui/pop_tablet/tests/mock/host.html` charge `web/index.html` de la ressource dans une page 1920×1080 et 2560×1440 ; définit `GetParentResourceName = () => 'pop_tablet'` ; intercepte `https://pop_tablet/*` (`page.route`) vers `mock/server.ts` (fixtures par app et action, latence réglable, erreurs injectables) ; envoie les messages `pop:*` par `window.postMessage`.

| Spécification | Vérifie |
|---|---|
| `shell.spec` | ouverture / fermeture en fondu 150 ms, verrou (code, 5 erreurs), bureau 6×4 et pages, Échap / Entrée, mise à l'échelle 85 % / 90 % |
| `states.spec` | pour chaque app : vide, chargement (formes grises, message à 5 s, « Réessayer »), succès 2 s, erreur, pas le droit (grisé + bulle), hors service |
| `double-click.spec` | double clic sur « Envoyer » → une seule requête, même `actionId` sur « Réessayer » |
| `xss.spec` | textes `<img src=x onerror=…>`, `<script>`, RTL override affichés en clair, aucun dialogue, aucune requête réseau sortante |
| `rtl.spec` | captures `fr`, `de`, `ar`, `th` ; `dir` correct ; aucun débordement horizontal |
| `lazy.spec` | au démarrage seul `main.js` est chargé ; chunk et namespace chargés à l'ouverture de l'app |
| `leaks.spec` | 50 ouvertures / fermetures : 0 minuterie active, 0 iframe, DOM et tas JS stables (± 5 %) |
| `perso.spec` | iframe sans `allow-same-origin` ; `window.parent.document` inaccessible ; message forgé avec `appId` d'une autre app → id réel utilisé ; CSP MAN-06 bloque `fetch` externe |
| `apps/*.spec` | parcours principal de chaque app sur fixtures (critères d'acceptation des fiches côté interface) |
| `static.spec` | interdits de 2.5 dans `src/` |

### 9.5 Recette en jeu

Serveur de test (déploiement manuel par l'action « Deploy to test server »), **trois passes identiques** : ESX Legacy + ox_inventory + ox_target ; QBCore + qb-inventory + qb-target ; Qbox + ox_inventory + ox_target + Renewed-Banking. Une quatrième passe courte : ESX avec inventaire de base (mode personnage) et prompt natif.

| Bloc | Contrôles |
|---|---|
| Démarrage | ligne de résumé verte, migrations, 7 entreprises par défaut, assistant `/tablette_setup`, OneSync absent → arrêt propre |
| Performance | `resmon 1` : 0,00 ms client tablette fermée (après 50 ouvertures), ≤ 0,05 ms ouverte ; 0,00 ms serveur au repos ; `/tablette_debug` « Fils actifs : 0 » |
| Fiches | critères d'acceptation de chaque fiche (grille générée depuis les fiches : `tests/pop_tablet/recette.csv`, une ligne par critère × framework) |
| Deux joueurs | facture, amende, recrutement, devis, soins, partage de note, fenêtre simple (joueur sans tablette, inconscient puis réveillé) |
| Triche | ressource de test `pop_tablet_devtest` (dans `tests/pop_tablet/devtest/`, jamais livrée) : rejoue des événements forgés, faux jetons, montants négatifs, `actionId` rejoué, cibles lointaines, 1 000 requêtes / s → tout refusé et journalisé |
| Adaptateurs | banque (3 systèmes), prison (au moins `qb-prison` et `esx_jail`), dispatch (script tiers appelant `ps-dispatch` sans ps-dispatch démarré), essence (ox_fuel), menottes |
| Langues | `fr`, `en`, `ar` (RTL) et `th` sur le bureau, Factures, Police |
| Mise à jour | redémarrage → aucune migration rejouée ; installation par-dessus une v précédente → données gardées |

---

## 10. Risques techniques (classés) et parades

| Rang | Risque | Effet | Parade |
|---|---|---|---|
| 1 | **Écarts entre ESX, QBCore et Qbox** (événements de mort, métiers en mémoire QBCore/Qbox, API bancaires, `player_groups`, `markedbills`) | fonctions qui marchent sur un seul framework | tout dans `bridge/framework/*` ; profils de mocks par framework ; recette triple ; valeurs à vérifier ci-dessous contrôlées en premier |
| 2 | **Volume** (363 fiches, ~100 tables, ~60 écrans) → oublis et incohérences | fonctionnalités manquantes ou divergentes | ordre de dev du sommaire (01 → 02 → 05 → 03/04/06) ; annotation `-- [ID]` + `coverage.lua` ; un dossier serveur et un chunk NUI par app ; tests par fiche |
| 3 | **Argent** : double paiement, remboursement raté, compte société indisponible | perte ou création d'argent | idempotence + verrous + mises à jour conditionnelles + unicités + remboursement automatique ; tests concurrents ; journal `money` sur Discord par défaut |
| 4 | **Zéro boucle violé** par un module ou une app | resmon > 0 au repos | minuteries seulement via `timers.lua` / `session.lua` (compteur `/tablette_debug`) ; contrôles statiques ; test e2e des fuites ; recette resmon |
| 5 | **Bac à sable des apps perso** : `app.lua` exécuté hors bac à sable par le manifeste ; `debug.sethook` absent | app malveillante active | `app.lua` limité à `PopApp.register` (MAN-04, refus d'enregistrement sinon) ; documentation « n'installez que des apps de confiance » ; repli de coupure à 500 ms |
| 6 | **Compatibilité MySQL / MariaDB** (JSON, DDL non transactionnel, versions) | installation qui échoue | minimum MySQL 5.7.8 / MariaDB 10.3 vérifié au démarrage (`SELECT VERSION()`) ; pas de `JSON_VALUE` ; migrations idempotentes par `information_schema` |
| 7 | **Faux exports dispatch** (`__cfx_export_…`) selon la version de FiveM | alertes tierces perdues | adaptateur chargé seulement si la vraie ressource est absente ; test de recette dédié ; événement `pop_tablet:dispatchAlert` et export `DispatchAlert` comme chemins garantis |
| 8 | **Photos sur disque** (`data/photos/`) écrasées lors d'une mise à jour qui remplace le dossier | photos et preuves perdues | `docs/mise-a-jour.md` (garder `data/`) ; avertissement console au démarrage si des lignes `pop_tablet_media` locales n'ont plus de fichier ; mode `external` disponible |
| 9 | **Mémoire de la NUI** sur de longues sessions (CEF), tableur 200×26, éditeur de site | ralentissements | démontage complet, virtualisation des grandes listes, cache images borné (40 entrées) et vidé à la fermeture, `leaks.spec` |
| 10 | **Traductions** (~5 000 clés × 10 langues, arabe RTL, thaï) | textes manquants ou cassés | repli `fr` puis clé ; `locales.lua` ; e2e RTL/thaï ; polices système couvrant arabe et thaï |
| 11 | **Dérive de pop_base** (fichiers copiés modifiés par erreur, ou corrigés dans le modèle sans recopie) | bugs différents d'un script à l'autre | `pop_base_sync.lua` (hash identiques) ; extensions dans des fichiers séparés |
| 12 | **Délai du callback pop_base (10 s)** sur une action lourde (import d'entreprise, gros collage dans le tableur) | réponse perdue alors que l'action a eu lieu | actions longues en deux temps : réponse immédiate `{ ticket }` puis `Push` du résultat ; `actionId` garantit l'absence de double exécution au « Réessayer » |
| 13 | **Escrow** : JS lisible, `load()` des fichiers ouverts | copie de l'interface | NUI minifiée sans source ; valeur métier dans le Lua serveur chiffré ; fichiers ouverts lus par `LoadResourceFile` (non chiffrés, donc lisibles) |
| 14 | **OneSync absent** ou routage par instances | distances fausses | arrêt au démarrage sans OneSync ; même bucket exigé dans `near.lua` |

Valeurs dépendant des scripts installés, à contrôler au premier jour de recette (sommaire § 5, fait foi) : ressource et export de prison Qbox ; state bag `isDead` de qbx_medical et émission de `QBCore:Player:SetPlayerData` ; événements `hospital:server:SetDeathStatus` / `SetLaststandStatus` ; exports et champs de ps-dispatch v2, cd_dispatch, core_dispatch ; rappels d'esx_service ; clé de valeur de `markedbills` ; colonnes de `player_vehicles` (qbx_vehicles). Chaque valeur est isolée dans **un seul** fichier d'adaptateur ouvert : la corriger ne demande jamais de toucher au cœur chiffré.
