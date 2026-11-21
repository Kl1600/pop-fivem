# pop_clothes

Magasins de vêtements, barbiers et tatoueurs. Les vêtements achetés deviennent des objets pop_inventory, portés aussitôt.

## Fonctionnement
- Magasins dans `Config.Shops` (types `clothing`, `barber`, `tattoo`). Prompt pop_v3dui « [E] OUVRIR <NOM> » à moins de 2,5 m. Les blips sont gérés par pop_management (`Config.Blips`).
- Cabine d'essayage : caméra devant le joueur, cadrage par catégorie, rotation à la souris, zoom, flou d'arrière-plan. Caméra fixe possible par magasin (`pedCoords`, `pedHeading`, `cam`).
- Aperçu : la tenue d'origine est rendue à la fermeture si rien n'est acheté.
- Achat (serveur) : panier vérifié (valeurs entières bornées, tatouages limités à `tattoos.json`), joueur près d'un magasin du bon type, prix de `Config.Prices` + TVA (`GlobalState.tva`, 20 % par défaut) versée au compte `Config.GouvUSAccount` (esx_addonaccount, sinon écriture SQL).
- Paiement : d'abord l'argent liquide (objet `cash` de pop_inventory) s'il suffit, sinon le compte bancaire.
- Vêtements : `exports.pop_inventory:GiveAndEquip`. Barbier : choix reportés dans skinchanger puis `esx_skin:save`, tenue de l'inventaire remise (`RefreshEquipment`). Tatouages : variable ESX `tattoos` + colonne `users.tattoos` (créée au démarrage si absente).
- Créateur de personnage (pop_charcreator) : ouverture vêtements / tatouages, tatouages gratuits seulement dans l'instance du créateur (bucket `src + 1000`), retour au créateur à la fermeture.

## Dépendances
es_extended, oxmysql, pop_inventory, skinchanger / esx_skin, pop_v3dui (prompt), pop_notify (notifications). `pop_inventory` doit être lancé avant `[pop]` (objet `cash` détecté par le bridge).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | réglages communs POP, magasins, catégories, prix, composants, notifications |
| `locales/fr.lua` | tous les textes Lua |
| `client/common.lua` | état partagé (`Clothes.*`), tenue portée |
| `client/tattoos.lua` | liste des tatouages, tatouages portés |
| `client/camera.lua` | caméra et cadrage par catégorie |
| `client/barber.lua` | choix du barbier reportés dans skinchanger |
| `client/shop.lua` | ouverture du magasin, prompt, ouverture depuis le créateur |
| `client/nui.lua` | callbacks NUI (aperçu, achat, fermeture, caméra) |
| `server/common.lua` | fonctions partagées : notification, TVA, distance, paiement |
| `server/tattoos.lua` | liste `tattoos.json`, tatouages du joueur, colonne SQL |
| `server/shop.lua` | achat du panier, mode créateur |
| `html/index.html` | interface NUI |
| `tattoos.json` | catalogue des tatouages |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Évènements
| Nom | Sens | Rôle |
|---|---|---|
| `clothes:buy_all` | client → serveur | achat du panier |
| `clothes:purchaseSuccess` | serveur → client | achat validé |
| `clothes:requestTattooList` / `clothes:setTattooList` | client ↔ serveur | catalogue des tatouages |
| `clothes:requestTattoos` / `clothes:applyTattoos` | client ↔ serveur | tatouages du joueur |
| `clothes:clearTattoos` | client → serveur | retire tous les tatouages |
| `pop_clothes:server:setCreatorMode` | client → serveur | mode créateur (tatouages gratuits) |
| `clothes:openFromCreator` / `tattoos:openFromCreator` | pop_charcreator → client | ouverture depuis le créateur |
| `pop_charcreator:reopen` | client → pop_charcreator | retour au créateur |

## Relancer
`restart pop_clothes`
