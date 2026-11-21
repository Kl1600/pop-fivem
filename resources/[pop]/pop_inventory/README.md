# 🎒 Tab Inventory

---

### 🏷️ Fiche Produit & Caractéristiques
* **Prix** : `79.99€`
* **Preview Vidéo** : 🎥 [Regarder sur YouTube](https://www.youtube.com/watch?v=6hjfBYaP9TA)
* **Optimisation** : ⚡ `0.1 ms` (Activement optimisé)
* **Licence** : 🔓 **Open Source (Unlock)** — En achetant, vous bénéficiez d'un accès complet au code source de l'inventaire pour le modifier, l'adapter et le configurer à votre convenance.

---

**Tab Inventory** est un système complet et configurable d'inventaire container (gestion des vêtements, du torse, livré avec les items essentiels au RP, gestion des armes, drag&drop et plus). Il est hautement personnalisable et supporte plusieurs frameworks nativement.

## 🌟 Fonctionnalités Commerciales
* **Système de Craft** intégré pour permettre la fabrication d'items directement dans l'interface.
* **Magasin de Vêtements** complet intégré à l'inventaire.
* **Création de Personnage Avancée** (taille persistante, transidentité, choix de vêtements, détails approfondis du visage, etc.).
* **Coffres Polyvalents** (propriétés, véhicules, coffres de stockage).
* **Cartes d'Identités et Licences** gérées nativement sous forme d'items physiques ou virtuels.
* **Glisser-Déposer (Drag & Drop)** fluide et performant (y compris les raccourcis admin rapides).
* **Conteneurs Distants** (gestion des inventaires des autres joueurs, des coffres et contenants distants).
* **Clés en Item & Verrouillage des Véhicules** pour une meilleure immersion RP.
* **Vêtements en Item** : équipez-vous/déséquipez-vous à la volée.
* **Items Essentiels RP Livrés Clé en Main** : menottes, kit de réparation (`repakit`), cash physique, cartes de crédit, défibrillateur (`aed`), clés de voiture, armes en items et bien plus !


## 📦 Dépendances
- **oxmysql** : Pour toutes les sauvegardes et la persistance des objets des joueurs et des objets au sol en base de données.
- **ox_target** : Utilisé pour les interactions de type "ciblage" sur le terrain (ouverture des coffres, de la fouille des autres joueurs, ou du ramassage/interaction avec de plus gros containers).

## ⚙️ Compatibilité des Frameworks
Le script est pensé pour être "Plug & Play" avec **ESX** et **QBCore**, ou même utilisé en mode Standalone. Configurez simplement le framework désiré dans `config.lua` :
```lua
Config.Framework = 'esx' -- Options possibles: 'esx', 'qbcore', 'none'
```
Il intègre les fonctions de récupération de joueur (`ESX.GetPlayerFromId` ou `QBCore.Functions.GetPlayer`), l'affichage de notifications, et la gestion des comptes bancaires (pour le TPE).

## 🚀 Fonctionnalités principales
- **UI Avancée** : Glissez-déposez, raccourcis clavier. Support d'une vue transparente et d'interactions avec l'environnement.
- **Conteneurs Imbriqués** : Placez un portefeuille dans un sac à dos, ou des objets dans une veste tactique. Chaque conteneur dispose de restrictions (ex: le portefeuille ne prend que de l'argent et des cartes).
- **Équipement** : Emplacements dédiés pour s'équiper physiquement des vêtements (qui modifient le Ped) et des armes.
- **Interaction "Drag to World"** : Glissez un item d'un conteneur vers un joueur à proximité pour lui donner.
- **Items Utilisables** : Exemples préconfigurés (AED, TPE, Menottes, Nourriture).
- **Menu Admin Intuitif** :
  - **Glisser-Déposer Direct** : Glissez un item depuis la liste admin (à droite) vers la partie gauche de l'écran pour vous octroyer instantanément **1** unité de cet item de manière ultra-rapide.
  - **Clic-Gauche Quantité** : Effectuez un clic gauche sur un item de la liste admin pour ouvrir la boîte de dialogue classique de quantité personnalisée.
  - **Ergonomie Admin** : Le glissement vers le haut de l'écran (`clientY < 180`) ne masque plus l'interface par erreur.
- **Persistance** : Sauvegarde des inventaires joueurs, et sauvegarde potentielle des objets au sol en base de données selon configuration.

## ⌨️ Commandes
| Commande | Touche(s) par défaut | Description |
| :--- | :--- | :--- |
| `/pop_inventory` | `TAB` ou `I` | Ouvre/ferme l'interface de l'inventaire principal. |
| `/tab_inventory_slot1` | `1` | Équipe/Déséquipe l'arme courte (pistolet) du slot rapide 1. |
| `/tab_inventory_slot2` | `2` | Équipe/Déséquipe l'arme longue du slot rapide 2. |
| `/tab_inventory_slot3` | `3` | Équipe/Déséquipe l'arme tazer du slot rapide 3. |
| `/pop_inventory-give` | (Admin) | `pop_inventory-give [ID joueur] [item] [quantité]`. S'attribue à soi-même si pas d'ID. |
| `/pop_inventory-cleardrops` | (Admin) | Nettoie et supprime tous les items laissés au sol par les joueurs. |
| `/carton_deplacer_mode` | - | Active ou désactive le mode permettant de déplacer à la main des gros cartons/coffres prop. |

## 🛠️ Exports Disponibles

### Client (`client.lua`)
Renvoie le nombre (la quantité totale) d'un item spécifique que possède le joueur (dans son équipement et dans n'importe lequel de ses conteneurs).
```lua
local count = exports['pop_inventory']:getItemCount("nom_de_l_item")
```

### Serveur (`server.lua`)
Le serveur possède ses propres exports pour interagir finement avec l'inventaire des joueurs.

```lua
-- Obtenir la quantité d'un objet (équipé ou dans des sacs)
local count = exports['pop_inventory']:getItemCount(source, itemDefId)

-- Supprimer un montant d'un objet depuis l'inventaire du joueur
-- Retourne true si l'objet a été supprimé avec succès
local success = exports['pop_inventory']:removeItem(source, itemDefId, qty)

-- Donner un objet à un joueur de manière générique
exports['pop_inventory']:GiveItem(target, defId, qty, meta)
exports['pop_inventory']:addItem(source, itemDefId, qty, meta) -- Alias de GiveItem

-- Donner un vêtement/arme et forcer le joueur à s'en équiper instantanément
exports['pop_inventory']:GiveAndEquip(target, defId, qty, meta)

-- Ajouter de force un objet MÊME SI l'inventaire/le conteneur spécifique est plein.
exports['pop_inventory']:addItemToContainer(source, containerId, defId, qty, meta)

-- Obtenir une table brute contenant tous les objets correspondant à un defId donné 
local itemsTable = exports['pop_inventory']:GetPlayerItems(source, itemDefId)

-- Obtenir l'objet store complet d'un joueur contenant tous ses items, containers et équipements 
local playerStore = exports['pop_inventory']:getInventory(source)
```

## 📦 Items Intégrés
Le fichier `items_client.lua` / `items_server.lua` démontre l'utilisation d'objets interactifs et gère la logique de manière compatible (ESX / QBCore) :
- **TPE (`tpe`)** : Permet de facturer une somme à un joueur proche via une interface de confirmation (l'argent est prélevé de la `bank`).
- **Menottes (`menottes`)** : Restreint les mouvements et contrôle du joueur menotté.
- **Défibrillateur / Kit de soin (`aed` / `medikit`)** : Animation de réanimation et de soins (`NetworkResurrectLocalPlayer` ou modification de l'entité de vie).
- **Nourriture (`hotdog`)** : Restauration de la faim (compatible `esx_basicneeds` ou `consumables:client:Eat` sous QBCore).
