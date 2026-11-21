# PROGRESS

Journal court. À relire au début de chaque session, avec `feature_list.json` et `SPEC.md`.

## État
- Fonctions validées : 1 / 120
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
