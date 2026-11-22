# pop_inventory

Inventaire du serveur POP : conteneurs imbriqués (sacs, portefeuille, mallette…), équipement porté (vêtements, armes), sol, coffres de véhicule et capot, coffres fixes, casiers, fouille, boutiques, fabrication et objets RP (TPE, menottes, AED, brancard, roues, radio, douilles, sabot, pistolet à peinture, lampe UV…).

C'est **l'inventaire détecté par le bridge** des autres scripts POP : `ensure pop_inventory` avant `ensure [pop]`.

## Fonctionnement
- **TAB** : appui court = inventaire, maintenu = roue façon GTA (armes équipées + objets utilisables). **I** ouvre / ferme aussi l'inventaire. La roue d'armes native de GTA est bloquée.
- **1 à 4** : arme de poing, tazer, arme blanche, outil. Une arme lourde équipée reste en main.
- Glisser un objet hors de l'inventaire : don au joueur visé ou dépôt sur une cible enregistrée (`registerDragTarget`).
- Le serveur est autoritaire : il garde l'inventaire de chaque joueur (table `tab_inventory_inventories`) et le sol (`tab_inventory_ground`), sauvegardés régulièrement.
- Coffres de véhicule (`/coffre`), capot moteur (`/capot`), coffres fixes et casiers (`config/chests.lua`), cartons et coffres-forts posés (ox_target).
- Boutiques et établis : zones de `config/shops.lua` et `config/recipes.lua` (prompt pop_v3dui ou aide GTA).
- Notifications : pop_notify via le bridge, même style qu'avant (titre, icône, badge).

## Dépendances
oxmysql, es_extended, ox_target, utility_lib (props au sol). Optionnels : pop_notify, pop_v3dui, pop_clothes, pop_management (casiers, codes), pma-voice (radio), object_gizmo (déplacement des cartons), lb-phone, pop_dealing.

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | réglages communs POP + réglages généraux (sol, persistance, aide, debug) |
| `config/items_1.lua` … `items_5.lua` | `Config.Items`, chargés dans l'ordre |
| `config/attachments.lua` | accessoires d'armes (complète `Config.Items`) |
| `config/props.lua` | props au sol, coffres de véhicule |
| `config/clothing.lua` | animations de port, restrictions, tenue « nue », vêtements |
| `config/shops.lua`, `chests.lua`, `recipes.lua` | boutiques, coffres fixes / casiers, recettes / établis |
| `config/paint.lua`, `chargeurs.lua`, `vehiclekeys.lua`, `douilles.lua`, `sabot.lua` | réglages des modules |
| `locales/fr.lua` | tous les textes affichés par le Lua |
| `client/common.lua` | table `Inv`, ESX direct, notifications |
| `client/main.lua`, `wheel.lua`, `admin.lua`, `drag.lua`, `state.lua`, `equipment.lua`, `zones.lua` | inventaire, roue, menu admin, glisser-déposer, état et exports, tenue et armes, établis / boutiques |
| `client/containers/` | port des cartons / coffres, cibles ox_target |
| `client/items/` | objets utilisables, menottes et escorte, roues, brancard |
| `client/standby.lua`, `radio.lua`, `interactions.lua`, autres `client/*.lua` | coffres, radio, interactions, modules |
| `server/common.lua` | socle serveur (`TabInventory`, `Inv`, ESX direct, état global) |
| `server/sv_*.lua` | cœur de l'inventaire, même ordre de chargement qu'avant (globales partagées) |
| `server/items/`, autres `server/*.lua` | objets et modules côté serveur |
| `html/` | NUI (images en WebP) |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes et touches
| Commande | Touche | Rôle |
|---|---|---|
| `+pop_inventory_key` | TAB | inventaire / roue |
| `pop_inventory_alt` | I | inventaire |
| `pop_inventory` | – | inventaire (utilisée par d'autres scripts) |
| `pop_inventory_slot1` … `slot4` | 1 à 4 | armes des petites cases |
| `+radio`, `+volumeUp`, `+volumeDown` | P, Page haut, Page bas | radio |
| `+levermain` | X | lever les mains |
| `fouiller` (`DouillesConfig.Search.Command`) | – | chercher des douilles |
| `coffre`, `capot` | – | coffre / capot du véhicule proche |
| `carton_deplacer_mode` | – | déplacer un carton posé |
| `givekey` | – | donner la clé du véhicule proche |
| `pop_inventory-give [id] [objet] [qté]`, `pop_inventory-cleardrops` | – | admin |
| `showcasings`, `popjobschema` | – | admin (douilles visibles, schéma SQL) |

## Exports
Serveur : `getItemCount`, `addItem`, `GiveItem`, `removeItem`, `RemoveItem`, `removeItemById`, `GiveAndEquip`, `addItemToContainer`, `ClearPlayerStore`, `GetPlayerItems`, `getInventory`, `getStore`, `GetItemMetadata`, `UpdateItemMetadata`, `GiveCardboardBoxWithItems`, `openContainer`, `AddItemToStaticChest`, `GetStaticChestItemCount`, `RemoveItemFromStaticChest`, `SetPlayerHandcuffed`, `onUseAmmo`, `onUseDouille`.

Client : `IsInventoryOpen`, `getItemCount`, `GetPlayerItems`, `GetItemDef`, `RefreshEquipment`, `registerDragTarget`, `unregisterDragTarget`, `OpenStaticChestUI`, `isUVLightOn`.

Le bridge des autres scripts utilise `getItemCount`, `addItem`, `removeItem`, `getInventory`. pop_inventory, lui, n'appelle jamais `Bridge.AddItem` / `GetMoney` (il est l'inventaire) : le bridge ne sert ici qu'aux notifications, au joueur et au job.

## Évènements utiles
| Nom | Sens | Rôle |
|---|---|---|
| `pop_inventory:client:notify` (message) | serveur / scripts → client | notification simple |
| `pop_inventory:client:forceClose`, `pop_inventory:client:openInventory` | client | fermer / ouvrir l'inventaire |
| `pop_inventory:client:applyEquipment` | serveur → client | tenue et armes |
| `vg_engine:*` | partagés avec ox_target | moteur / capot |

Les callbacks internes (`pop_chargeurs:getRounds`, `pop_douilles:search`) passent par `shared/callback.lua`.

## Images
Icônes, torses et radio en WebP. Les PNG encore présents dans `html/img/` ne servent qu'à **pop_bennys** (`config.lua`) et **pop_management** (`html/app.js`), qui pointent vers `nui://pop_inventory/html/img/<nom>.png` : à supprimer quand ces deux scripts passeront en `.webp`.

## Relancer
`restart pop_inventory` (puis relancer les scripts qui dépendent de ses exports si besoin).
