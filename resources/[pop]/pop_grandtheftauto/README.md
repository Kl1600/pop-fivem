# 🚘 GrandTheftAuto (Mission de Vol de Véhicules)

Ce script gère une mission complète et synchronisée en coopération pour pirater et subtiliser des véhicules de haute valeur (type Benefactor). Le script intègre désormais un support complet des différents frameworks (ESX, QBCore) et systèmes d'inventaire (`pop_inventory`).

## ⚙️ Configuration
Toute la configuration modifiable se trouve dans `shared/config.lua`.
Vous n'avez plus besoin de toucher au code pour adapter la dépendance de l'inventaire ou de votre base serveur.

```lua
Config.Framework = 'esx' -- Options: 'esx', 'qbcore', ou 'none' (Standalone partiel)
Config.Inventory = 'pop_inventory' -- Options: 'pop_inventory', 'esx', 'qbcore'
Config.Notifications = 'notification' -- Options: 'notification' (script custom), 'esx', 'qbcore'
Config.UI = 'pop_v3dui' -- Options: 'pop_v3dui' (script custom pour les touches interactives E), 'esx', 'qbcore'
```

- **Framework** gère la détection de la police et l'enregistrement des objets utilisables (`ESX.RegisterUsableItem` ou `QBCore.Functions.CreateUseableItem`).
- **Inventory** cible spécifiquement la logique utilisée pour vérifier l'existence (et/ou la suppression) des objets requis (`pcb` / `flipper`). Ainsi, le script n'est plus rigoureusement lié à ESX.
- **Notifications & UI** permettent de jongler entre vos affichages custom ou ceux natifs des bannières ESX / QBCore.

## 🚀 Déroulement de la Mission
1. Rencontre du NPC Svetlana pour activer la file d'attente (Dépôt d'un véhicule).
2. Localisation du QG / Garage (`keys / hack`).
3. Piratage du terminal extérieur nécessite un `flipper`.
4. Récupération des clés.
5. Intégration du module `pcb` sur l'un (ou les) véhicules et résolution du minijeu de hack (Scaleform).
6. Alertes Police dynamiques avec système expérimental de Tracking ("GPS Tracker").
7. Livraison du véhicule au Point Drop déterminé.

## ⌨️ Objets et Commandes (Interaction)
### Par l'inventaire :
- Double clic ou "Utiliser" sur l'item `pcb` lance la même action que la commande, ciblant un véhicule à plaque correspondante à proximité. (Le Pcb est ensuite supprimé selon la configuration de votre callback serveur).

### Commandes Manuelles et Dev :
| Commande | Rôle |
| :--- | :--- |
| `/voler_auto` | Invoque la logique du `pcb` sur le véhicule Benefactor le plus proche et vérifie si le joueur possède l'item. |
| `/voler_auto_dev` | Force le commencement du piratage de véhicule sans avoir le NPC ni les items. Déplace le personnage devant le capot. (Pour test de Scaleform et caméras). |

## 🛠️ Sync et Coopératif
Le script est pensé pour fonctionnenr en escouade. Dès que l'Owner (celui qui amorce ou hack en 1er) effectue une action décisive (terminer le hacking, ramasser les clés, ouvrir la porte de garage), la progression est synchronisée côté serveur `(mission:server:relay / mission:server:registerEntity)`. Si des retardataires de l'équipe ont besoin de voir la porte ouverte ou le blip des clés supprimé, tout est mis à jour dynamiquement via `ActiveHacks` et `CompletedMissions`. 
