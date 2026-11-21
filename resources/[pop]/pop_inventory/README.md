# pop_inventory

Inventaire POP à slots et poids : metadata par item, hotbar 1-5, armes en items (série, munitions, durabilité),
sol, coffres et boîtes à gants par plaque, stockages, boutiques, fouille, argent physique optionnel.
Compatible ESX Legacy / ancien ESX, QBCore, Qbox (voir plus bas) et standalone. 10 langues, arabe en RTL.

## Installation

1. Dépendance : **oxmysql** (seule dépendance obligatoire).
2. Copier `pop_inventory` dans `resources/[pop]/`.
3. `sql/install.sql` est facultatif : les tables sont créées au démarrage.
4. `server.cfg` : **pop_inventory doit démarrer avant les autres scripts POP** (le Bridge détecte l'inventaire au démarrage) :
   ```
   ensure oxmysql
   ensure es_extended        # ou qb-core / qbx_core
   ensure pop_inventory
   ensure [pop]
   ```
5. Ne lancez **aucun autre inventaire** (ox_inventory, qs-inventory, qb-inventory, ps-inventory) : une erreur s'affiche
   en console sinon.
6. Admin : `add_ace group.admin pop.admin allow` (commande `/giveitem [id] [item] [count]`).

## Frameworks

- **ESX Legacy** : les fonctions d'inventaire de `xPlayer` (`addInventoryItem`, `getInventoryItem`…) sont redirigées vers
  pop_inventory (`Config.FrameworkHooks`). Redémarrer pop_inventory à chaud casse ces redirections pour les joueurs
  connectés : ils doivent se reconnecter.
  Dans la config d'es_extended, mettez **`Config.CustomInventory = true`** : sinon ESX charge et sauvegarde aussi son propre
  inventaire (avertissement rouge en console au démarrage). Valeur à vérifier selon votre version d'ESX (ne mettez pas `'ox'`).
- **Ancien ESX** : pas de mécanisme de redirection. Seuls les scripts qui passent par les exports ou le Bridge voient
  les items (avertissement en console).
- **QBCore** : les méthodes `Player.Functions.AddItem / RemoveItem / GetItemByName / GetItemsByName / GetItemBySlot /
  ClearInventory` sont redirigées, et `PlayerData.items` reste à jour.
- **Qbox** : `qbx_core` exige `ox_inventory`. Dans `fxmanifest.lua`, décommentez `-- provide 'ox_inventory'` et ne
  lancez pas ox_inventory. Mode à valider sur votre serveur : seuls les exports serveur courants d'ox_inventory sont fournis.
  Items utilisables : passez par `RegisterUsableItem` ; les items créés avec `exports.qbx_core:CreateUseableItem` sont
  appelés en repli (à vérifier selon la version de qbx_core).
- **Standalone** : aucun compte d'argent ; l'item d'argent (si configuré) est un item normal.

Au premier chargement d'un personnage, son ancien inventaire du framework est importé (`Config.ImportFramework`),
ainsi que les définitions d'items du framework absentes de `data/items.lua`.

## Items

- Définitions : `data/items.lua` (poids en grammes). Champs : `label`, `weight`, `stack`, `close`, `description`, `image`,
  `consume`, `weapon`, `ammo`, `clip`, `degrade`.
- `consume` (dans `data/items.lua`) : quantité retirée à chaque utilisation d'un item enregistré par `RegisterUsableItem`.
  Elle est retirée **avant** l'appel du callback et rendue si le callback renvoie `false` ou plante : un callback ne
  retire donc pas l'item lui-même quand `consume > 0` (laissez `consume = 0` si votre script gère le retrait).
- Libellés traduits : clé de locale `item_<nom>` (description : `desc_<nom>`) dans `locales/*.lua`.
- Images : `web/images/<nom>.png` (ou `image` / `metadata.image`), image par défaut sinon.
- Argent physique : `Config.CashItem = 'money'` synchronise l'item avec le compte `cash` du framework.

## Exports serveur

Mêmes noms que ox_inventory pour les fonctions courantes. `inv` = server id, id d'inventaire (`'stash:<id>'`,
`'trunk:<PLAQUE>'`, `'glovebox:<PLAQUE>'`), nom de stash, ou `{ id, owner }`.
Seuls les inventaires **chargés** sont accessibles (joueur en ligne, stash enregistré, coffre ouvert récemment) :
un export ne fait jamais de requête SQL.

| Export | Retour |
|---|---|
| `Items(name?)` | définition(s) |
| `AddItem(inv, item, count, metadata?, slot?)` | `true` \| `false, reason` |
| `RemoveItem(inv, item, count, metadata?, slot?)` | `true` \| `false, reason` |
| `GetItemCount(inv, item, metadata?, strict?)` | number |
| `Search(inv, 'count' \| 'slots', items, metadata?)` | comme ox |
| `CanCarryItem(inv, item, count, metadata?)` / `CanCarryWeight(inv, weight)` | bool |
| `GetItem`, `GetSlot`, `GetSlotWithItem`, `GetSlotsWithItem` | item(s) |
| `SetMetadata(inv, slot, metadata)` / `SetDurability(inv, slot, value)` | bool |
| `GetInventory(inv)` / `GetInventoryItems(inv)` / `ClearInventory(inv, keep?)` | |
| `RegisterStash(id, label, slots, maxWeight, owner?, groups?, coords?)` | bool |
| `RegisterShop(id, data)` | bool |
| `forceOpenInventory(src, invType, data)` | bool |
| `RegisterUsableItem(item, cb(src, item, metadata, slot))` | true |
| `GetCurrentWeapon(src)` | item de l'arme en main (comme `GetSlot`) \| `nil` |

`RegisterStash` est asynchrone pour un stockage partagé : il est chargé en tâche de fond (nouvel essai si la base répond
mal) ; juste après l'appel, les exports sur ce stockage peuvent encore renvoyer `not_loaded`.

Exemple :
```lua
exports.pop_inventory:AddItem(source, 'water_bottle', 2)
exports.pop_inventory:RegisterUsableItem('bandage', function(src, item, metadata, slot)
    -- ...
end)
```

Events serveur : `pop_inventory:usedItem (src, name, slot, metadata)`, `pop_inventory:openedInventory (src, invId)`,
`pop_inventory:closedInventory (src, invId)`. Client : `pop_inventory:itemCount (name, count)`,
`pop_inventory:currentWeapon (weapon | nil)`. Statebag `invBusy = true` : ouverture et utilisation refusées.

Export client `openInventory(type, data)` : renvoie `true` dès que la demande est envoyée au serveur
(pas quand l'interface est ouverte), `false` si les arguments sont invalides ou l'inventaire pas encore chargé.

## Configuration

Tout est dans `config.lua` (slots, poids, touches, sol, véhicules, stockages, boutiques, sauvegarde).
`Config.Inventory` doit rester `'none'`.

## Base de données

- Si les tables ne peuvent pas être créées, une erreur rouge s'affiche et **rien n'est chargé ni sauvegardé** ; nouvel essai
  toutes les 10 s. Un conteneur dont la lecture SQL échoue n'est pas ouvert (jamais remplacé par un inventaire vide).
- Redémarrage à chaud (`restart pop_inventory` avec des joueurs connectés) : la ressource attend ~1,5 s avant de recharger
  les inventaires, le temps que les dernières sauvegardes arrivent. Préférez tout de même un redémarrage serveur (voir ESX).

## Performance

Aucune boucle rapide côté serveur (sauvegarde toutes les `Config.SaveInterval` secondes, inventaires modifiés seulement).
Côté client, une boucle par frame n'existe que pendant qu'une arme est en main.
