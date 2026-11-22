# Gabarit POP — convertir un script existant

But : tous les scripts rangés pareil, plus simples à corriger et à améliorer. **Aucun changement visible en jeu** : même fonctionnement, mêmes couleurs, mêmes textes.

Modèle de référence : `templates/pop_base` (bridge, callbacks, textes). Exemple converti : `resources/[pop]/pop_bank`. Petit script d'affichage sans framework : `resources/[pop]/pop_notify` (manifeste seulement).

## 1. Arborescence

```
pop_<nom>/
  fxmanifest.lua     name 'pop_<nom>', author 'KL', lua54 'yes', version, description
  config.lua         bloc « Réglages communs POP » (copié de pop_bank) + réglages du script
  locales/fr.lua     clés communes + tous les textes du script
  bridge/client.lua  copie exacte de templates/pop_base/bridge/client.lua
  bridge/server.lua  copie exacte de templates/pop_base/bridge/server.lua
  shared/locale.lua  copie exacte (fonction L)
  shared/callback.lua copie exacte (Callback.Register / Trigger / Await)
  client/*.lua       découpé par fonction, < 600 lignes par fichier
  server/*.lua       idem ; fonctions communes dans server/common.lua (table <Nom> = {})
  html/              NUI d'origine, inchangée
  README.md          fiche du script (modèle : pop_bank/README.md)
```

Copie des fichiers communs :
```bash
cd "resources/[pop]/pop_<nom>"
mkdir -p bridge shared locales
cp ../../../templates/pop_base/bridge/*.lua bridge/
cp ../../../templates/pop_base/shared/*.lua shared/
```
Les fichiers `bridge/` et `shared/` ne se modifient **jamais** dans un script. Un bug dedans → prévenir le Chef 1, qui corrige `templates/pop_base` et le recopie partout.

Seulement `locales/fr.lua` pour l'instant (les autres langues viendront plus tard ; `L()` retombe sur la clé si une langue manque).

## 2. fxmanifest.lua

Ordre de chargement obligatoire :
```lua
shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua' }
client_scripts { --[[ '@ox_lib/init.lua' si utilisé ]] 'bridge/client.lua', 'client/....lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'bridge/server.lua', 'server/common.lua', 'server/....lua' }
escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
```
Lister les fichiers serveur/client **dans l'ordre** quand l'un dépend d'un autre (sinon `*.lua` charge par ordre alphabétique). Garder les `dependencies` d'origine. Retirer `@es_extended/imports.lua` si plus rien n'utilise la variable globale `ESX`.

## 3. Remplacements

| Avant | Après |
|---|---|
| `exports['es_extended']:getSharedObject()` pour notifier / job / argent | `Bridge.*` |
| fonction notify maison / `TriggerClientEvent('notification:client:ShowNotify', src, data)` | serveur `Bridge.Notify(src, data)`, client `Bridge.Notify(data)` — `data` = la même table `{ title, message, image, icon, duration }` : le style d'origine est gardé |
| `ESX.RegisterServerCallback` / `ESX.TriggerServerCallback` | `Callback.Register(name, function(source, ...) return ... end)` / `Callback.Trigger(name, cb, ...)` |
| `exports.ox_target:addBoxZone({...})` | `Bridge.Target.AddBoxZone(id, coords, size, heading, options)` (mêmes options : label, icon, canInteract, onSelect) |
| distance joueur ↔ point côté serveur | `Bridge.IsNear(src, coords, dist)` |
| argent liquide (`exports.pop_inventory:getItemCount(src, 'cash')` …) | `Bridge.GetMoney(src, 'cash')`, `Bridge.AddMoney`, `Bridge.RemoveMoney` (objet `cash` de pop_inventory) |
| compte bancaire ESX | `Bridge.GetMoney(src, 'bank')` / `AddMoney` / `RemoveMoney` |
| `MySQL.Async.*`, `exports.oxmysql:*` | `MySQL.query`, `MySQL.single`, `MySQL.update`, `MySQL.insert` (+ `.await` dans un thread) |
| texte en dur `'Pas assez d\'argent'` | `L('not_enough_money')` ; texte avec valeur : `L('check_cashed', amount)` (`%s` dans fr.lua) |
| `print(...)` de debug | `if Config.Debug then print(...) end` |

API complète : `templates/pop_base/README.md`.

Ce que le bridge ne couvre pas (ex. `ESX.GetJobs()`, joueur par identifier, compte hors ligne en SQL, coffres statiques pop_inventory) : garder l'appel ESX/pop_inventory direct, regroupé dans `server/common.lua` avec un commentaire « ESX direct ». Ne pas réécrire une logique qui marche juste pour passer par le bridge.

## 4. Ne pas changer
- Noms d'évènements utilisés par d'autres scripts (sauf renommage vanguard_/vg_/tab_ → pop_ demandé, fait partout en même temps).
- Noms d'objets en base (`tab_douilles`, `tab_sabot`, …), tables SQL, ids de coffres.
- HTML/CSS/JS de la NUI (sauf allègement d'images sans perte visible).
- Dépendances tierces : utility_lib, ox_target, object_gizmo, checksystem, interact-sound, chHyperSound, pma_voice_challenge, clm_ProgressBar.

## 5. Vérifier avant chaque push
```bash
luacheck "resources/[pop]/pop_<nom>"          # 0 warning / 0 erreur
find "resources/[pop]/pop_<nom>" -name '*.lua' -exec luac5.4 -p {} \;
find "resources/[pop]/pop_<nom>" -name '*.js' -exec node --check {} \;
```
Puis : relire le diff ligne à ligne (même comportement), fetch + rebase + push sur main, et dire au client `restart pop_<nom>` + quoi tester en jeu.

## 6. README.md du script
Sections : à quoi il sert, fonctionnement, dépendances, fichiers (tableau), commandes / touches, évènements et exports (tableau), comment relancer. Modèle : `resources/[pop]/pop_bank/README.md`.
