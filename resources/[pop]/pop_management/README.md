# Tab Management (Tabernac Gestion)

Un script complet et immersif pour FiveM permettant la gestion d'entreprise (SecuroServ) et l'achat de véhicules professionnels (PDM) via une interface d'ordinateur portable en 3D (DUI). 

## 🌟 Fonctionnalités Principales

### 1. Interface Ordinateur 3D (DUI)
* Rendu 3D immersif de l'écran directement dans le jeu via le moteur **pop_duiengine**.
* Interaction fluide à la souris sans menu 2D bloquant l'écran.
* OS virtuel avec applications SecuroServ et Premium Deluxe Motorsport (PDM).

### 2. Gestion d'Entreprise (SecuroServ)
* **Tableau de bord :** Vue d'ensemble des fonds, des effectifs et des dernières transactions.
* **Employés :** Liste du personnel, versement de primes, promotions, rétrogradations et licenciements.
* **Finances :** Dépôts, retraits et historique complet des transactions bancaires de la société.
* **Flotte de Véhicules :** Suivi des véhicules de l'entreprise (modèle, plaque, statut garage/sorti).
* **Commandes :** Suivi en temps réel de l'acheminement des véhicules importés (barre de progression).

### 3. Concessionnaire PDM
* Catalogue de véhicules classés par catégories avec sélection des couleurs.
* Achat avec les fonds de la société.
* Support d'achats ciblés : si un concessionnaire commande un véhicule de fonction (ex: Police), il sera directement assigné au script Police.
* Système d'importation réaliste : livraison des véhicules avec délai au port commercial.
* Menu de réclamation au port avec apparition (spawn) physique du véhicule.

### 4. Flexibilité, Compatibilité & Sécurité
* **100% Plug & Play ESX :** Supporte nativement les nouvelles versions ESX (exports) ainsi que les versions Legacy (TriggerEvent).
* **Base de données optimisée :** Requêtes sécurisées utilisant `oxmysql`.
* **Clés de véhicules configurables :** 
  * Compatible avec le système d'inventaire avancé **pop_inventory** pour donner des clés physiques (items) aux joueurs.
  * Option `Config.UseTabInventoryKeys` pour désactiver l'utilisation de clés physiques de l'inventaire pop_inventory et adapter le script aux systèmes ESX classiques.
  * UI dynamique : l'onglet "Véhicules" du SecuroServ s'affiche ou se masque automatiquement selon la configuration des clés.
* **Persistance Totale :** Enregistrement immédiat dans `owned_vehicles` (et `persistent_vehicles` si utilisé) dès la sortie du port.

## 📦 Dépendances
* `es_extended` (Toutes versions)
* `oxmysql`
* `pop_duiengine` (Moteur d'interface 3D)

## 🛠️ Installation
1. Téléchargez et placez le dossier `pop_management` dans votre répertoire `resources`.
2. Assurez-vous d'avoir démarré `pop_duiengine` et `oxmysql`.
3. Importez le fichier `orders.sql` (ou les requêtes manuelles) dans votre base de données pour créer les tables requises (si elles n'y sont pas déjà).

### ⚠️ Prérequis Base de données (Très Important)
Pour que le script reconnaisse les droits de gestionnaire (et affiche certaines options), le plus haut grade de votre entreprise **DOIT s'appeler `boss`**. 
- Dans la table `job_grades`, la colonne `name` pour le grade le plus élevé (grade 3, 4, etc.) doit impérativement être structurée ainsi : `name = 'boss'`. 
- Sans cela, le script ne reconnaîtra pas le joueur comme patron.
- L'argent de l'entreprise fonctionnera avec le compte `society_nomdujob` (assurez-vous que vos comptes de société suivent ce standard ESX dans `addon_account_data`).

4. Configurez le fichier `config.lua` selon les besoins de votre serveur :
   * Temps de livraison (`Config.DeliveryTime`)
   * Position des ordinateurs (`Config.Laptops`)
   * Système de clés (`Config.UseTabInventoryKeys`)
   * Notifications (`Config.NotificationType`)
5. Ajoutez `ensure pop_management` dans votre `server.cfg`.

## ⚙️ Configuration (`config.lua`)
Le paramétrage est simple et détaillé dans `config.lua` :
* Modifiez `Config.UseTabInventoryKeys = false` si votre serveur n'utilise pas l'inventaire `pop_inventory` ou si vous utilisez un système de clé basique natif à ESX.
* Choisissez votre style d'alertes via `Config.NotificationType` (`'custom'` ou `'esx'`).

## 💻 Commandes Principales
* **`/lapclose`** : Ferme l'interaction en cours avec l'ordinateur.
* **`/lapside`** : Inverse le côté de rendu de l'écran en 3D.
* Touches de navigation classiques (clic gauche, molette) pour interagir avec le DUI.
