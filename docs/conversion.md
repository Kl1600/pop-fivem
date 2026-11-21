# Conversion tab → POP (même fonctionnement, même style)

Décision du propriétaire : on garde le **fonctionnement et le style d'origine** des scripts `tab`.
On les rend seulement **compatibles tous frameworks** (ESX Legacy/ancien, QBCore, Qbox, standalone)
et **traduits en 4 langues : fr (défaut), en, ar (RTL), de**. Les réécritures POP précédentes
sont archivées sous le tag git `pop-rewrite-v1`.

## Source
Ancienne base sur le Mac du propriétaire : `/Users/mayolraphael/Downloads/tab-main/...`
Lister : `mcp__remote-devices__device_list_dir` (recursive). Copier en local :
`mcp__remote-devices__device_stage_files` (50 fichiers max par appel) → arrive dans
`/mnt/user-data/uploads/tab-main/<même chemin>`. Certains fichiers y sont déjà.
Prends TOUT ce qui sert au script : Lua, html/css/js, images, sons, `stream/`, `.meta`, `data/`.
Ignore : `*.bak`, `*.zip`, `*.rar`, `.claude/`, `html_debug.txt`, scripts `.ps1/.bat`, `.dll` C#.

## Cible
`resources/[pop]/pop_<nom>/` (nom de la table ci-dessous). Même arborescence et mêmes fichiers
qu'à l'origine, plus : `bridge/server.lua`, `bridge/client.lua`, `shared/callback.lua`,
`shared/locale.lua` copiés À L'IDENTIQUE depuis `templates/pop_base/` (ne jamais les modifier),
et `locales/fr.lua`, `en.lua`, `ar.lua` (`_rtl = true`), `de.lua`.

## Règles (changement minimal)
1. **Ne change ni la logique, ni le gameplay, ni le HTML/CSS** (couleurs, polices, images, mises en page).
2. **fxmanifest** : garde-le, ajoute avant les scripts existants
   `shared_scripts { 'config.lua'(si existe), 'shared/locale.lua', 'shared/callback.lua', 'locales/*.lua' }`,
   `client_scripts { 'bridge/client.lua', ... }`, `server_scripts { 'bridge/server.lua', ... }`.
   Le Bridge lit `Config.Locale`, `Config.Framework`, `Config.Inventory`, `Config.Target`,
   `Config.Notify` (crée ces clés dans config.lua si absent : 'fr', 'auto', 'auto', 'auto', 'auto').
3. **Framework** → Bridge : `ESX.GetPlayerFromId`/`xPlayer.*` (argent, job, identifier, items,
   showNotification), `ESX.RegisterServerCallback` → `Callback.Register`,
   `ESX.TriggerServerCallback` → `Callback.Trigger`, `esx:playerLoaded`/`esx:setJob` →
   `Bridge.OnPlayerLoaded`/`Bridge.OnJobUpdate`, `getSharedObject` supprimé. API complète :
   `templates/pop_base/README.md`.
4. **Inventaire** : `exports.tab_inventory:*` → fonctions items du Bridge (`AddItem`, `RemoveItem`,
   `GetItemCount`, `HasItem`, `GetItems`, `RegisterUsableItem`…). Exception : pop_inventory lui-même.
5. **Notifications** : la ressource `notification` devient `pop_notify` et exporte
   `Notify(message, type, duration)` côté client. Les autres scripts appellent `Bridge.Notify`
   (qui utilise pop_notify en priorité s'il tourne, donc l'ancien style est conservé).
6. **Noms** : `tab_xxx`/`vg_xxx`/`vanguard_xxx` → `pop_xxx` partout (events, exports, dépendances).
7. **Textes** : chaque texte visible (notifications Lua, textes HTML/JS, labels config destinés au
   joueur) passe par les locales. Lua : `L('cle', ...)`. NUI : envoie `GetLocaleTable()` à la page
   à l'ouverture (ou au chargement) et remplace les textes par des clés (`data-i18n` + petite
   fonction JS). Garde le français d'origine comme valeur `fr`, traduis en en/ar/de. Arabe : ajoute
   `dir="rtl"` sur la page si `_rtl`.
8. **Dépendances** : `ox_lib`, `oxmysql`, `ox_target` peuvent rester si le script s'en sert
   beaucoup (les déclarer dans fxmanifest et le README). Toute autre dépendance tierce : remplace-la
   si l'usage est petit, sinon documente-la dans le README.
9. **Sécurité** : corrige seulement les failles évidentes côté serveur (montants ou items venant du
   client, events sans vérification de distance/job), sans changer le gameplay. Note-les dans le README.
10. **README.md** (anglais, court) : installation, dépendances, items, config, langues.
11. **Vérifs** : `luac5.4 -p` sur tous les .lua, `node --check` sur les .js, et
    `cmp` des fichiers bridge/shared avec le template. Aucune commande git.

## Table des conversions
| Source (tab-main) | Cible |
|---|---|
| [system]/[tab_inventory]/tab_inventory (avec ses modules : chargeurs, douilles, sabot, paint, radio, vehiclekeys, malette, uvpocketlight, weapon_preview, coffres…) | pop_inventory |
| [system]/[tab_basehud]/tab_hud | pop_hud |
| [system]/[tab_basehud]/speedometer | pop_speedometer |
| [system]/[tab_basehud]/notification | pop_notify |
| [system]/[tab_basehud]/loading | pop_loading |
| [system]/[tab_inventory]/tab_charcreator | pop_charcreator |
| [system]/[tab_inventory]/tab_clothes | pop_clothes |
| [system]/[tab_inventory]/vanguard_idcard | pop_idcard |
| [system]/[inventaire]/vanguard_passport | pop_passport |
| [system]/[tab_inventory]/v3dui | pop_v3dui (si c'est un script maison utilisé par dealing) |
| [illegal]/tab_dealing, tab_weed, tab_doorlock, vg_territories, vg_crew | pop_dealing, pop_weed, pop_doorlock, pop_territories, pop_crew |
| [illegal]/vanguard_bikerental, vanguard_voice_ui | pop_bikerental, pop_voiceui |
| [management]/tab_admin, tab_interim, tab_management, tab_duiengine, vg_computer | pop_admin, pop_interim, pop_management, pop_duiengine, pop_computer |
| [misc]/tab_affiche, tab_boards, tab_police (+ thème de tab_police80) | pop_affiche, pop_boards, pop_police |
| [system]/tab_bank, tab_bennys, tab_chat, tab_emotes, tab_enterprisegarage, tab_exchange, tab_kilometrage, tab_medexam | pop_bank, pop_bennys, pop_chat, pop_emotes, pop_enterprisegarage, pop_exchange, pop_kilometrage, pop_medexam |
| [system]/tab_vehiclepersistence (serveur : partir de server.lua.bak, pas du C#) | pop_vehiclepersistence |
| livraison | pop_livraison |

Non repris (tiers ou données) : natal_pausemenu, map-darkatlas, fivem-blips, lkrp_notepad,
mt_printers, nass_pedscaler, uz_AutoShot, scripts achetés.
