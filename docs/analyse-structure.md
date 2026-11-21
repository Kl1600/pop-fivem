# Analyse de la base — structure et optimisation (22/11/2026)

But : rendre chaque script plus simple à corriger et à améliorer, sans changer son fonctionnement ni son style.

## Constats

### 1. Chaque script est rangé différemment
- 26 scripts sur 36 ont tout à la racine (`client.lua`, `server.lua`) ; les autres utilisent `client/ server/ shared/`.
- 13 scripts n'ont pas de `config.lua` (réglages écrits dans le code).
- Aucun script n'a de dossier `locales/` : tous les textes sont écrits en dur dans le code.
- 13 manifestes sans `lua54 'yes'`.

### 2. Le même code est réécrit dans chaque script
- ESX est chargé de 4 façons différentes (imports.lua, `exports['es_extended']`, `exports["es_extended"]`, ancien `TriggerEvent('esx:getSharedObject')`).
- 28 fonctions « notification » maison dans 13 scripts, alors que `pop_notify` existe.
- Base de données : deux styles mélangés (`exports.oxmysql:*` et `MySQL.*`).

### 3. Fichiers géants difficiles à corriger
- `pop_management/client.lua` 3 768 lignes, `server.lua` 2 619 lignes.
- `pop_inventory/config.lua` 2 919 lignes, `client.lua` 1 681, `items_client.lua` 1 321.
- `pop_vehiclepersistence/client.lua` 982 lignes.

### 4. Performance (resmon et téléchargement)
- `pop_inventory/remote_container.lua` : boucle à chaque image même quand on ne porte pas de carton → à mettre en veille.
- La boucle de `pop_inventory/client.lua` doit rester (elle bloque la roue native), mais elle peut être allégée.
- Poids téléchargé par les joueurs : `pop_emotes` 121 Mo, `pop_inventory` 21 Mo (images 12 Mo), `pop_loading` 16 Mo (musique 10 Mo), `pop_management` 13 Mo, `pop_passport` 6,7 Mo et `pop_idcard` 3,5 Mo (PNG de 3 Mo). Compresser les images (WebP) et la musique réduirait fortement le chargement.

### 5. Restes de l'ancienne base
- Anciens noms d'évènements : `vanguard_charcreator`, `vg_paint`, `vg_engine`, `tab_bank`, `tab_medexam`, `tab_admin`, `vg_crew` (7 scripts, surtout pop_inventory).
- `tab_douilles`, `tab_sabot`, `tab_chargeurs`, `tab_uvlight` sont probablement des noms d'objets en base de données : ne pas les renommer sans migration SQL.
- Messages console : 113 `print` dans pop_management, 47 dans pop_inventory → derrière `Config.Debug`.
- `pop_police` et `pop_police80` (hors projet) sont toujours lancés par `ensure [pop]`.

### 6. Rien n'explique comment marche chaque script
- Pas de README par script : commandes, touches, exports, évènements et réglages sont à chercher dans le code.

## Le gabarit POP (cible pour chaque script)

```
pop_<nom>/
  fxmanifest.lua      author 'KL', lua54 'yes', version
  config.lua          tous les réglages (positions, prix, touches, Config.Debug)
  locales/fr.lua      tous les textes affichés (prépare les langues)
  shared/bridge.lua   fichier identique dans chaque script : ESX, notification (pop_notify),
                      callbacks, Debug(), L('clé') pour les textes
  client/*.lua        découpé par fonction (menu.lua, zones.lua…), < 600 lignes par fichier
  server/*.lua        idem ; tout le SQL passe par MySQL.* (oxmysql)
  html/               NUI
  README.md           à quoi sert le script, commandes, touches, exports, évènements, réglages
```

Pourquoi un `bridge.lua` copié dans chaque script plutôt qu'une ressource commune : chaque script reste vendable seul (compatible tous serveurs), et le jour du multi-framework, on ne change que ce fichier.

## Plan proposé

Étape 1 — Chef 1 : écrit le gabarit (`docs/gabarit-pop.md`, `templates/bridge.lua`, exemple de README) et le teste sur pop_notify et pop_bank. Les autres Chefs attendent cette publication.

Étape 2 — chaque Chef applique le gabarit à son lot (mêmes lots que l'audit), script par script, un push par script, en testant qu'il démarre :
- Lot 1 Chef 1 : pop_admin, pop_management (découpage), pop_interim, pop_duiengine, pop_computer.
- Lot 2 Chef 2 : pop_inventory (découpage, boucle carton, anciens noms d'évènements, images), pop_charcreator, pop_clothes, pop_loading (musique), pop_idcard, pop_passport (images).
- Lot 3 Chef 3 : pop_grandtheftauto, pop_dealing, pop_weed, pop_crew, pop_territories, pop_bikerental, pop_voice_ui, pop_livraison.
- Lot 4 Chef 4 : pop_bank, pop_bennys, pop_enterprisegarage, pop_kilometrage, pop_vehiclepersistence, pop_speedometer, pop_v3dui, pop_doorlock, pop_affiche, pop_boards, pop_medexam, pop_chat, pop_emotes (poids), pop_hud, pop_notify.

Étape 3 — Chef 1 : `docs/scripts.md` (carte de tous les scripts et de leurs dépendances), vérification finale.

Règles : même fonctionnement, mêmes couleurs, aucun changement visible en jeu. Ne pas renommer les objets en base. Ne pas toucher aux dépendances tierces (utility_lib, ox_target, kq_lasers, object_gizmo, checksystem…).

À décider par le client :
- sortir pop_police et pop_police80 du dossier lancé ;
- supprimer des emotes et props custom peu utilisés pour alléger pop_emotes (121 Mo).
