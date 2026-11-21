# pop_vehiclepersistence — Configuration

Persistance **physique** des véhicules : tout véhicule conduit est sauvegardé (position,
état, mods, dégâts, carburant) et réapparaît **là où il a été laissé**, mais **uniquement
autour des joueurs** (rayon de 250 m) pour économiser les ressources.

> ⚠️ Ce script utilise sa **propre table** `persistent_vehicles`. Il ne lit ni n'écrit
> jamais dans la table ESX `owned_vehicles`. La propriété est suivie par **license**.

---

## Dépendances

| Ressource | Requis | Rôle |
|---|---|---|
| `oxmysql` | ✅ | Base de données |
| `utility_lib` | non | Plus requis (le serveur est désormais en Lua) |
| `pop_inventory` | optionnel | Système de clés (`Config.UseTabInventory = true`) |
| `ox_lib` | optionnel | Notifications (sinon fallback framework/chat) |

Aucun framework obligatoire : fonctionne en **ESX**, **QBCore**, **Qbox** ou **standalone**.

---

## Installation

1. Placer la ressource dans `resources/[system]/pop_vehiclepersistence`.
2. `ensure pop_vehiclepersistence` dans le `server.cfg` (après oxmysql / le framework).
3. La table SQL est créée et migrée **automatiquement** au démarrage. Rien à importer.

---

## Options (`config.lua`)

| Option | Valeurs | Défaut | Description |
|---|---|---|---|
| `UseTabInventory` | `true` / `false` | `true` | `true` : sauve seulement si le joueur a l'item `carkeys` (meta.plate) via pop_inventory. `false` : sauve tout véhicule conduit. |
| `MaxPersistenceDays` | nombre (jours) | `30` | Supprime un véhicule non utilisé depuis X jours. `0` = jamais d'expiration. |
| `Framework` | `'auto'` `'esx'` `'qb'` `'qbox'` `'standalone'` | `'auto'` | Détection auto du framework. À forcer seulement si la détection se trompe. |
| `Notification` | `'auto'` `'ox_lib'` `'esx'` `'qb'` `'chat'` | `'auto'` | Système de notification utilisé. `'auto'` = ox_lib si présent, sinon le framework, sinon le chat. |
| `OwnerKey` | `'license'` / `'framework'` | `'license'` | Identifiant stocké comme propriétaire (`owner_id`). `'license'` = universel. `'framework'` = identifier ESX / citizenid QB. |
| `CustomIdentifier` | `function(src)` ou `nil` | `nil` | (Avancé, serveur) Surcharge totale de l'identifiant propriétaire. |
| `CustomNotify` | `function(msg, type)` ou `nil` | `nil` | (Avancé, client) Surcharge totale des notifications. |
| `HasVehicleKey` | `function(src, plate)` ou `nil` | `nil` | (Avancé, serveur) Branche ton propre système de clés. `nil` = comportement par défaut (pop_inventory / tout). Si défini, remplace entièrement la vérif pop_inventory. |

---

## ⚠️ Les 2 réglages à ne pas rater

1. **`OwnerKey`** — à fixer **avant la mise en service**. Le changer sur une base existante
   « détache » les véhicules déjà enregistrés (leur `owner_id` ne correspondra plus → non
   rechargés). En cas de doute : laisser `'license'`.
2. **`UseTabInventory = true` sans pop_inventory installé = aucun véhicule sauvegardé**
   (la vérification de clé échoue toujours). Sans système de clés pop_inventory → mettre `false`.

---

## Profils types

**Base ESX existante (ne rien casser) :**
```lua
Config.UseTabInventory    = true       -- seulement si tu as pop_inventory + carkeys
Config.MaxPersistenceDays = 30         -- 0 pour le comportement strictement d'avant
Config.Framework          = 'auto'
Config.Notification       = 'auto'
Config.OwnerKey           = 'license'  -- NE PAS CHANGER
```

**Serveur ESX standard (sans pop_inventory) :**
```lua
Config.UseTabInventory    = false
Config.MaxPersistenceDays = 30
Config.Framework          = 'auto'
Config.Notification       = 'auto'
Config.OwnerKey           = 'license'
```

**Standalone (aucun framework) :**
```lua
Config.UseTabInventory    = false
Config.MaxPersistenceDays = 30
Config.Framework          = 'standalone'
Config.Notification       = 'chat'
Config.OwnerKey           = 'license'
```

---

## Base de données

Table créée automatiquement :

```sql
CREATE TABLE IF NOT EXISTS persistent_vehicles (
    plate        VARCHAR(64)  NOT NULL,
    owner_id     VARCHAR(250),
    vehicle_data LONGTEXT,
    last_seen    BIGINT       NOT NULL DEFAULT 0,
    PRIMARY KEY (plate),
    INDEX idx_owner (owner_id)
);
```

- `plate` : clé primaire (plaque normalisée, sans espaces, en majuscules).
- `owner_id` : propriétaire (license ou identifiant framework selon `OwnerKey`), préservé même si un détenteur de clé conduit le véhicule.
- `vehicle_data` : état complet du véhicule en JSON.
- `last_seen` : timestamp Unix de la dernière interaction (pour l'expiration). Compatible MySQL **et** MariaDB.

---

## Commandes

| Commande | Côté | Description |
|---|---|---|
| `/showvehicles` | joueur | Active/désactive le HUD admin + l'affichage 3D dans le monde. |
| `debug_persistence` | console / joueur | Affiche l'état (DB / spawnés / véhicules trackés). |
| `expire_test <plaque>` | console | Force une plaque comme expirée puis lance la purge (test). |
| `test_persistence_200` | joueur | Stress-test : injecte 200 véhicules. |
| `test_persistence_cleanup` | console / joueur | Supprime les véhicules de test. |

---

## Exports

| Export | Côté | Usage |
|---|---|---|
| `GetIdentifier(src)` | serveur | Identifiant propriétaire résolu (license ou framework). |
| `Notify(msg, type)` | client | Notification via le système configuré. |
| `OnKeyGranted(pid, plate)` | serveur | À appeler depuis pop_inventory quand un item `carkeys` est donné (resync). |
