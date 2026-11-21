# pop_admin

Menu admin fenêtré (style MapZones) pour ESX Legacy.

## Ouverture
- **F6** : ouvrir / fermer (configurable `Config.OpenKey`)
- **TAB** : basculer menu rapide ⇄ menu complet
- **G** : révéler la fenêtre minimisée (`Config.RevealKey`)
- **F** (en mode spec) : ouvrir les options sur le joueur visé (`Config.SpecKey`)
- La fenêtre se déplace en glissant la barre de titre ; bouton **—** pour minimiser.

## Menu rapide
Noclip, godmode, invisible, soin, réanimation, réparation, TP GPS, nettoyage,
spawn véhicule et **Mode Spec** (point central ; viser un joueur affiche ses options).

## Menu complet (TAB)
- **Joueurs** : aller/amener/spectate/geler/soigner/réanimer/tuer/kick/ban, argent, job, groupe, give item.
- **Zones map** : ouvre l'éditeur **MapZones**.
- **Items** : catalogue (fourni par `pop_inventory`), give à soi ou à un joueur.
- **Personnages** :
  - *Double personnage (staff)* : sauvegarde l'apparence (skin) actuelle du staff côté serveur
    (fichier `staff_characters.json`, clé = licence) et permet de la **réincarner** à tout moment ;
    incarner applique le skin et le persiste comme apparence active (`esx_skin:save`).
  - *Positions enregistrées* : positions + modèles de ped (stockage local navigateur).
- **Véhicules** : liste des véhicules persistants (`persistent_vehicles`), aller / supprimer.
- **Temps & Météo** : heure, gel, blackout, météo — synchronisés à tous les joueurs.
- **Jobs** : se donner un job, créer un job, ajouter un grade, créditer la société, supprimer.
- **Logs** : journal des déconnexions — pour chaque joueur qui quitte, la raison est
  catégorisée (**Quitté / Alt+F4**, **Timeout**, **Crash**, **Kick**, **Ban**) avec l'heure,
  l'identifiant, et l'admin responsable pour les kick/ban. Filtres par catégorie, recherche,
  bouton « Aller » au point de déconnexion, et « Vider ». Persistés dans `disconnect_logs.json`
  (taille max : `Config.LogsMax`).

## Accès
Autorisé si groupe ESX ∈ `Config.AdminGroups`, ou permission ACE de `Config.AcePermissions`,
ou identifiant listé dans `Config.AdminIdentifiers`.

## Dépendances
- `es_extended`, `oxmysql` (requis)
- `skinchanger`, `esx_skin` (double personnage : lecture/écriture de l'apparence)
- `pop_inventory` (catalogue d'items ; les admins doivent aussi passer son contrôle
  `pop_inventory.admin` / `Config.AdminIdentifiers` pour que la liste d'items se charge)
- `pop_vehiclepersistence` (table `persistent_vehicles`)
- `MapZones`, `notification` (optionnels)

## Installation
Placer dans `[management]/pop_admin` puis `ensure pop_admin` (après es_extended et pop_inventory).
