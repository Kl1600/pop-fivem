# pop_crew

Crews (gangs) créés par les joueurs. Sobre, ~0.00 ms au repos, ESX / QBCore / Qbox / standalone, 10 langues.

## Installation

1. Dépendance : `oxmysql` (obligatoire). ox_lib, ox_target, etc. ne sont pas requis.
2. Copier `pop_crew` dans `resources/[pop]/`.
3. `server.cfg` : lancer le framework et oxmysql **avant** `[pop]` :
   ```
   ensure oxmysql
   ensure es_extended   # ou qb-core / qbx_core, ou rien en standalone
   ensure [pop]
   ```
4. Base de données : les tables sont créées automatiquement au premier démarrage.
   Import manuel possible : `sql/install.sql`.

## Utilisation

- `/crew` ou `F7` (modifiable dans Paramètres > Raccourcis > FiveM) : ouvre le panneau.
- Sans crew : créer (nom + couleur, coût `Config.CreateCost`, gratuit en standalone) ou répondre à une invitation.
- Dans un crew : liste des membres, inviter un joueur proche, promouvoir / rétrograder / exclure selon le rang,
  quitter, dissoudre (chef).

## Configuration (`config.lua`)

| Clé | Défaut | Rôle |
|---|---|---|
| `Config.Locale` | `'en'` | en, fr, es, de, it, pt, nl, pl, tr, ar |
| `Config.Command` / `Config.Key` | `'crew'` / `'F7'` | commande et touche par défaut |
| `Config.CreateCost` / `Config.CreateAccount` | `25000` / `'bank'` | prix de création (`'cash'` ou `'bank'`) |
| `Config.NameLength` | `{ min = 3, max = 20 }` | longueur du nom (max 32) |
| `Config.MaxMembers` | `20` | membres max par crew |
| `Config.InviteDistance` / `Config.InviteTimeout` | `5.0` / `60` | distance (m) et validité (s) d'une invitation |
| `Config.Colors` | 8 couleurs | palette proposée à la création |
| `Config.Ranks` | leader, officer, member, recruit | rangs du plus haut au plus bas ; permissions `invite`, `kick`, `manage` |
| `Config.ShowTags` / `Config.TagDistance` | `false` / `20.0` | repère au-dessus des membres proches |

Rangs : l'index 1 est le chef (toutes les permissions, dissolution, transfert). Le libellé vient de la clé
de locale `rank_<name>` : ajouter un rang = ajouter une ligne dans `Config.Ranks` et la clé dans les locales.

## Exports serveur

```lua
exports.pop_crew:GetPlayerCrew(src)      -- { id, name, color, rank, rankLabel } | nil
exports.pop_crew:GetCrewMembers(crewId)  -- { { id, identifier, name, rank, rankLabel, online, source }, ... }
exports.pop_crew:GetCrew(crewId)         -- { id, name, color, memberCount, onlineCount } | nil
exports.pop_crew:IsSameCrew(srcA, srcB)  -- boolean
```

Events serveur locaux (`AddEventHandler`, jamais déclenchables par un client) :

```lua
AddEventHandler('pop_crew:changed', function(src, crewId) end) -- crewId nil = le joueur n'a plus de crew
AddEventHandler('pop_crew:disbanded', function(crewId) end)
```

## Export client

```lua
exports.pop_crew:GetMyCrew() -- { id, name, color, rank, rankLabel } | nil
```

## Langues

`locales/<code>.lua`. Une clé absente retombe sur l'anglais. Ajouter une langue : copier `en.lua`,
changer le code, traduire, puis `Config.Locale = '<code>'`.
