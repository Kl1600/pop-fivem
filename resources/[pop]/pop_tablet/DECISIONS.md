# pop_tablet : décisions de départ (22/11/2026)

Entrée pour l'architecte, qui en tire `SPEC.md` et `feature_list.json`. Maquettes de référence :
canevas Claude Design « POP Tablet maquettes » (fichiers `.dc.html` copiés dans `ui/pop-os/design/` (hors déploiement)).

## Produit (décidé par l'utilisateur)
- Tablette façon iPad récent (iPadOS 27, verre liquide), plein écran, paysage uniquement, thème clair et sombre.
- Aucun nom, icône, police ni fond d'Apple. Système « POP OS », appareil « POP Tab ».
- Données liées à l'OBJET : une tablette volée garde ses données ; il faut son code (4 chiffres, choisi au premier allumage).
- Ouverture : utiliser l'objet dans l'inventaire, ou touche réglable (F2 par défaut ; F5 = menu emotes) si l'on en porte une.
- TOUTES les applis fonctionnent vraiment en jeu : Réglages, Boutique, Appareil photo, Photos, Notes, Calendrier,
  Rappels, Fichiers, Tableau (dessin), Horloge (alarmes, minuteur, chrono, horloges), Calculette, Météo (météo du jeu),
  Plans (carte GTA, recherche de lieux, itinéraire GPS natif), Dictaphone, Traduire, Bourse (marché simulé serveur),
  Messages et Téléphone (numéro propre à chaque tablette, SMS et appels entre tablettes), Mail (adresses en jeu),
  Contacts, Navigateur (sites en jeu + liens autorisés), Musique (radios / flux configurables).
- Plateforme : API pour que d'autres ressources ajoutent leurs applis (id, nom, icône, page NUI, jobs autorisés),
  envoient une notification, ouvrent une appli. Applis métier (police…) hors V1, viendront par cette API.
- Le projet Pulse (téléphone d'une autre session) n'a AUCUN rapport. Un futur téléphone POP réutilisera les applis
  de la tablette : l'interface doit séparer le « système appareil » des applis (mise en page `regular` / `compact`).

## Règles POP (non négociables)
- ESX, QBCore, Qbox, standalone via l'API Bridge de pop_base ; ne jamais modifier bridge/, shared/, web/kit/.
- 10 langues (en, fr, es, de, it, pt, nl, pl, tr, ar + RTL). Aucun texte en dur, côté Lua comme côté interface.
- Sécurité côté serveur : le serveur vérifie tout (objet porté, code, propriétaire, anti-spam, tailles, distance).
- Performance extrême : 0,00 ms au repos côté client ET serveur ; aucune boucle permanente ; aucun `Wait(0)` hors
  besoin réel pendant l'ouverture ; envois réseau minimes (pas de polling, push uniquement, paquets petits).
- Hiérarchie : natif GTA/FiveM d'abord (RegisterKeyMapping, TaskPlayAnim + prop, CreateMobilePhone/CellCam,
  SetNewWaypoint, GetClockHours, météo du jeu…), puis l'existant (pop_base, oxmysql, pma-voice, screencapture),
  sinon on construit.
- Interface : React + TypeScript + Vite. Source hors déploiement : `ui/pop-os/` à la racine du dépôt.
  Les fichiers construits vont dans `resources/[pop]/pop_tablet/web/dist/` et sont versionnés. Jamais de build
  sur le serveur.
- Lint avant push : `luacheck resources templates` 0/0, `luac5.4 -p`, `node --check`, `tsc --noEmit`, build Vite.
- Branche `feat/pop-tablet` ; aucun push sur main, aucun déploiement.
- Docs locales obligatoires avant d'utiliser une API : `python -I D:\dev\outils-dev\docs-locales\docs-locales.py chercher <lib> "<question>"`
  (fivem-natives, fivem, fivem-lls, pma-voice, screencapture, screenshot-basic, oxmysql, esx, qbcore, qbox,
  ox_inventory, react, vite, motion, lua54).
