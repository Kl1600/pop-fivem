# 👕 Clothes

**Clothes** est un magasin de vêtements (Clothing Store) complètement revu pour fournir une interface élégante qui intègre le système d'items de **pop_inventory**. Contrairement aux magasins classiques qui se contentent de modifier le personnage, ce script vous permet d'acheter de la garde-robe physique (sous forme d'items ajoutés à vos sacs) que vous pourrez enfiler, modifier ou retirer via le pop_inventory !

## ⚙️ Compatibilité des Frameworks
Gérez la ligne suivante présente au tout début du fichier `config.lua` :
```lua
Config.Framework = 'esx' -- Options possibles: 'esx', 'qbcore', 'none'
```
Le serveur vérifiera le prix de vos articles, et prendra l'argent *physique* (l'item argenté) nécessaire de l'inventaire via les exports de `pop_inventory`. Si la transaction réussit, ou échoue, il notifiera le côté client avec la mécanique appropriée (`esx:showNotification` ou `QBCore:Notify` ou chat de base par défaut).

## 🚀 Fonctionnalités principales
- **UI en NUI Interactive** : Catégories intuitives, sélection de textures.
- **Caméra de cabine d'essayage intelligente** : Se positionne en face du joueur, calcule les zooms dynamiques, pivote.
- **Transformation en "Items physiques"** : L'achat d'un élément (masque, chaîne, torse, chaussure, ...) va appeler `exports.pop_inventory:GiveAndEquip` pour convertir cet accessoire en un item glissant de `pop_inventory` assigné au joueur.
- **Mémorisation et Aperçu** : Si vous testez un vêtement et sortez du magasin sans l'acheter, l'application réinitialise votre personnage aux vêtements d'origine (sauvegardés lors de l'ouverture de l'UI).
- **Support des Props & Components** : Gère la distinction technique du jeu (lunettes, chapeaux sont des "props" ; t-shirts, pantalons sont des "components").

## ⌨️ Commandes
| Commande | Description |
| :--- | :--- |
| `/vetement` | Force l'ouverture du magasin de vêtements (généralement utilisé pour débogage ; *l'ouverture normale se fait via des zones Blip*). |
| `/bras` | Ouvre une pop-up minifiée spécifique pour régler ses bras (pour éviter les manches manquantes avec de nouveaux hauts sans avoir à payer un Ponsonbys complet). |
| `/fixui` | Commande de secours si jamais la NUI ou la Caméra venait à se figer inopinément sans échappatoire. |

## 📍 Magasins et Positions
L'ajout de nouveaux magasins est géré dans `config.lua` -> `Config.Shops`.
Une fonction gère l'apparition d'une invitation *"E : OUVRIR MAGASIN"* si vous êtes à portée (et intègre le prompt personnalisé `pop_v3dui` si actif, remplaçant les textes bruts classiques).

## 💰 Modèle de Paiement
Dans le script `server.lua`, on intercepte les requêtes provenant du panier (tous les items souhaités).
L'action est vérifiée côté serveur :
```lua
local cashCount = exports.pop_inventory:getItemCount(src, 'cash')
if cashCount >= totalCost then
    exports.pop_inventory:removeItem(src, 'cash', totalCost)
    -- Donner via un export !
```
Si vous désirez utiliser de l'argent digital banquier via ESX/QBCore plutôt que de l'item liquide (`cash`), c'est dans `server.lua @clothes:buy` que la condition doit être réécrite pour valider un paiement virtuel.
