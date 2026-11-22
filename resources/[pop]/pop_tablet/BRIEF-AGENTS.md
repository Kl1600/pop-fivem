# Brief commun des passages « applis » (pop_tablet)

Branche `feat/pop-tablet`. Jamais de push, jamais `main`.

## À lire d'abord
`PROGRESS.md`, `feature_list.json`, `SPEC.md` (la section 0 prime), `DECISIONS.md`, `docs/api-applis.md`,
`templates/pop_base/README.md`, puis le code existant : `server/`, `client/`, `ui/pop-os/src/` (kit, system, nui, apps),
et la maquette de chaque appli traitée : `ui/pop-os/design/<Appli>.dc.html` (référence visuelle et interactions à reproduire
fidèlement en React, clair et sombre, iPad paysage ; mise en page `regular`, prête pour `compact`).

## Règles
- Chaque appli = serveur (Lua, SQL si besoin) + client (Lua, natives) + interface (React) + textes, de bout en bout.
- Docs locales avant toute API : `python -I D:\dev\outils-dev\docs-locales\docs-locales.py chercher <lib> "<question>"`
  (fivem-natives, fivem, oxmysql, pma-voice, screencapture, screenshot-basic, esx, qbcore, qbox, ox_inventory, react, vite, motion).
  Aucune signature inventée.
- Natif d'abord, puis l'existant (pop_base Bridge, oxmysql, pma-voice, screencapture), sinon on construit.
- Performance : 0,00 ms au repos client et serveur ; aucune boucle permanente ; push sans polling ; un abonnement côté serveur
  seulement tant qu'une appli qui en a besoin est ouverte ; paquets minimes ; requêtes SQL indexées et préparées.
- Sécurité : le serveur vérifie tout (objet porté et tablette déverrouillée via la garde existante, propriété, anti-spam,
  tailles max, distance). Jamais de montant ou d'identité venant du client.
- 10 langues : clés de texte côté interface (fr et en remplis) et côté Lua (10 fichiers `locales/`), aucun texte en dur.
- Ne jamais modifier `bridge/`, `shared/callback.lua`, `shared/locale.lua`, `web/kit/`.

## Preuves et commits
- Vérifications à lancer en une commande groupée :
  `lua tests/run.lua` ; `luacheck "resources/[pop]/pop_tablet" templates` (0/0) ; `luac -p` sur les .lua modifiés ;
  dans `ui/pop-os` : `pnpm typecheck && pnpm test && pnpm build && pnpm verify`.
- Ajoute des tests (Lua avec faux natives dans `tests/`, vitest côté interface) pour chaque logique serveur et interface.
- `passes: true` seulement avec preuve collée dans `PROGRESS.md` ; ne modifie que ce champ ; une fonction qui demande le jeu
  reste `false` avec ce qui a été prouvé.
- Commits groupés par fonctions liées, message en anglais finissant par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  Les fichiers construits de `web/dist` sont commités.
- Économise les tours : plusieurs fichiers par tour, une commande de vérification groupée.

## Rapport
12 lignes maximum : fonctions passées, restées `false` et pourquoi, écarts avec la SPEC, décisions prises.
