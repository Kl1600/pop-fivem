# pop_territories

Guerre de territoires entre crews : influence par zone, prise de contrôle, bonus de prix pour pop_dealing.
ESX (Legacy et ancien), QBCore, Qbox, standalone. 10 langues. ~0.00 ms au repos.

## Installation

1. Dépendance : `oxmysql`. Optionnel : `pop_crew` (crews de joueurs), `pop_dealing` (ventes).
2. Copier `pop_territories` dans `resources/[pop]/`.
3. `server.cfg` (framework et oxmysql **avant** `[pop]`) :
   ```
   ensure oxmysql
   ensure es_extended   # ou qb-core / qbx_core
   ensure [pop]
   add_ace group.admin pop.admin allow
   ```
4. Tables : créées automatiquement au démarrage (`sql/install.sql` pour un import manuel facultatif).

## Appartenance à un crew

Évaluée à chaque appel :
1. `pop_crew` lancé : son crew (`GetPlayerCrew`) ; sans crew dans pop_crew = pas de crew.
2. Sinon `Config.UseJobsAsCrews = true` (ESX, QBCore, Qbox) : les jobs listés dans `Config.JobCrews` servent de crews.
3. Sinon (y compris en standalone sans pop_crew) : influence désactivée (zones, blips et HUD restent actifs).

## Fonctionnement

- Influence de 0 à 100 par crew et par zone, total d'une zone ≤ 100.
- Vente dans la zone : `+PerSale` (une vente comptée par joueur toutes les `SaleCooldown` s).
- Présence (par minute, membre vivant ; les joueurs morts / à terre ne comptent pas) : `+PerTick`, sans dépasser `Capture` sauf pour le propriétaire.
- Absence : `-Decay` par minute.
- Prise à `Capture` (60), maintien tant que l'influence reste ≥ `Keep` (30).
- Prix : `zone.price`, puis `Prices.Owner` (vendeur propriétaire) ou `Prices.Rival` (zone tenue par un autre).
  Ces multiplicateurs **se cumulent** avec le `mult` de la zone de vente pop_dealing (appliqué avant) :
  ex. Vespucci = 1.2 (pop_dealing) × 1.0 (`zone.price`) × 1.25 (propriétaire). Laissez `price = 1.0` si pop_dealing gère déjà le prix du quartier.

## Avec pop_dealing

Seule la vente permet de prendre une zone (la présence plafonne sous `Capture`). Les **zones de vente de pop_dealing
(`Config.Zones` de pop_dealing) doivent recouvrir les territoires** : un territoire où l'on ne peut pas vendre est imprenable.
En ajoutant ou déplaçant un territoire, ajoutez une zone de vente pop_dealing qui le couvre.

## Configuration (`config.lua`)

| Clé | Rôle |
|---|---|
| `UseJobsAsCrews`, `JobCrews` | crews par job (sans pop_crew) : `job = '#rrggbb'` |
| `Influence` | `PerSale`, `PerTick`, `Decay`, `Capture` (51-100), `Keep` (< Capture), `SaleCooldown` |
| `Prices` | `Owner`, `Rival` |
| `RivalAlertCooldown` | secondes entre deux alertes rivales par zone (0 = désactivé) |
| `ZoneBlips` | zones colorées sur la carte |
| `HudDuration` | secondes d'affichage du HUD (0 = tant qu'on est dans la zone) |
| `Commands` | `Info` (`/territory`), `Admin` (`/territoryadmin`) |
| `Zones` | `{ id, label, center, radius }` ou `{ id, label, points = { vec2, ... } }`, `price` optionnel (0.1-10) |

`label` est une clé de traduction (ajoutez-la dans `locales/*.lua`) ou un texte brut.

## Exports serveur

```lua
-- À appeler AVANT de payer : renvoie le montant final (entier) et des infos.
local final, info = exports.pop_territories:RecordDrugSale(source, coords, amount)
-- info = { zone = 'grove' | nil, owner = { key, label, color } | nil, mult = 1.25, rival = false }

local zoneId, label = exports.pop_territories:GetZoneAt(coords)
local owner = exports.pop_territories:GetZoneOwner('grove') -- { key, label, color } | nil
```

Event serveur local : `AddEventHandler('pop_territories:ownerChanged', function(zoneId, newOwner, oldOwner) end)`.

## Export client

```lua
local zoneId = exports.pop_territories:GetCurrentZone()
```

## Commande admin

`/territoryadmin` (ACE `pop.admin`, groupe admin du framework, ou console) :
- `info [zone]` : propriétaire et influences (zone actuelle si omise).
- `reset <zone|all>` : remet la ou les zones à zéro.
- `set <zone> <crew> <0-100>` : `crew` = `crew:<id>` ou `job:<nom>`.

## Sécurité

Aucun event client → serveur. Zone calculée depuis la position serveur, montant validé, crew relu côté serveur,
influence de vente limitée par joueur, requêtes SQL paramétrées. pop_territories ne donne jamais d'argent.
