# pop_chargeurs : SPEC (contrat commun Serveur / Client)

> Référence unique : noms repris **à l'identique**. API commune : `Bridge.*`, `Callback.*`, `L()`
> (voir `templates/pop_base/README.md`). Modèle lu (pas copié) : `tab_inventory/chargeurs_*.lua`.

---

## 1. Description et fonctionnalités

Chargeurs en items : **utiliser un chargeur** recharge l'arme en main d'un nombre fixe de munitions.

- Chaque chargeur (`Config.Magazines`) a une quantité de munitions et une liste d'armes compatibles.
- Utiliser l'item, arme compatible en main → courte barre (on peut marcher, pas tirer) → le chargeur est consommé,
  les munitions sont ajoutées, animation de rechargement.
- Plafond de munitions par arme : `Config.MaxAmmo`.
- **Deux modes, choisis automatiquement** selon l'inventaire détecté :

| Mode | Inventaires | Où sont les munitions | Qui ajoute |
|---|---|---|---|
| `metadata` | ox_inventory, pop_inventory | métadonnée `ammo` de l'arme-item | le serveur (`SetMetadata`), le client aligne l'arme |
| `native` | qb-inventory, qs-inventory, ps-inventory, inventaire ESX / QBCore / Qbox | munitions du ped (sauvegardées par le framework / l'inventaire) | le client (`AddAmmoToPed`) après validation serveur |

**Plus simple que l'ancien script** : pas de chargeur inséré dans l'arme, pas de suivi balle par balle, pas de
boîtes de munitions pour remplir les chargeurs. Un chargeur = un rechargement.

**Performance** : aucune boucle. Tout se passe à l'utilisation de l'item.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_chargeurs/
  SPEC.md                 Architecte
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR
  README.md               SERVEUR   (items, modes, limites par inventaire)
  bridge/server.lua       SERVEUR   copie STRICTE du template
  bridge/client.lua       CLIENT    copie STRICTE
  shared/callback.lua     SERVEUR   copie STRICTE
  shared/locale.lua       SERVEUR   copie STRICTE
  locales/*.lua (10)      SERVEUR   kit commun + section 9 (ar : _rtl = true)
  server/weapons.lua      SERVEUR   adaptateur armes (seule exception au Bridge, section 3)
  server/main.lua         SERVEUR
  client/main.lua         CLIENT
  web/index.html          CLIENT    minimal : kit seul (sans #app, sans script.js)
  web/kit/pop.css, pop.js CLIENT    copie STRICTE
```

**Pas de NUI propre au script** (barre de progression du kit). Aucun Dev NUI.

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_chargeurs'
author 'POP'
version '1.0.0'
description 'POP Chargeurs - magazine items to reload weapons'

shared_scripts { 'config.lua', 'shared/*.lua', 'locales/*.lua' }
client_scripts { 'bridge/client.lua', 'client/*.lua' }
server_scripts { 'bridge/server.lua', 'server/weapons.lua', 'server/main.lua' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/**' }

escrow_ignore { 'config.lua', 'locales/*.lua', 'bridge/*.lua' }
```

---

## 3. Adaptateur armes : `server/weapons.lua` (Dev Serveur)

Le Bridge ne gère pas les armes. Plutôt que d'étendre le template pour un seul script, on isole ici les **deux seuls**
appels directs à un inventaire. Table globale `Weapons` :

```lua
Weapons = {}
Weapons.Mode = (Bridge.Inventory == 'ox_inventory' or Bridge.Inventory == 'pop_inventory') and 'metadata' or 'native'

--- Arme-item en main (mode metadata) : { slot = int, name = 'WEAPON_PISTOL', ammo = int } ou nil.
function Weapons.GetCurrent(src) end
-- exports[Bridge.Inventory]:GetCurrentWeapon(src) → item ; nil si pas d'arme ou metadata.ammo == nil
-- (arme sans munitions : mêlée, lancer). name en MAJUSCULES.

--- Fixe les munitions de l'arme-item (mode metadata). ok, attempted (attempted = false : rien envoyé à l'inventaire).
function Weapons.SetAmmo(src, slot, ammo) end
-- relit le slot (GetCurrentWeapon) pour récupérer la métadonnée complète, change seulement `ammo`,
-- puis exports[Bridge.Inventory]:SetMetadata(src, slot, metadata).
```
Format de `GetCurrentWeapon(src)` (ox_inventory et `exports.pop_inventory:GetCurrentWeapon(src)`) :
`{ slot, name, count, metadata, label, weight }`.
Tous les appels dans `pcall`. Si l'inventaire n'expose pas `GetCurrentWeapon` / `SetMetadata` → log console une
fois **par fonction** (anglais) et réponse `not_supported`. **Test au démarrage** (mode metadata) : après le démarrage
de l'inventaire (attente 10 s max), `pcall` sur `exports[inv].GetCurrentWeapon` et `.SetMetadata` → avertissement
console si absent. `-- NOTE:` dans le code : « pop_inventory doit exposer GetCurrentWeapon et
SetMetadata comme ox_inventory ».

---

## 4. Events

| Event | Sens | Paramètres | Destinataire | Rôle |
|---|---|---|---|---|
| `pop_chargeurs:client:reload` | S → C | `item` (string, nom du chargeur) | le joueur | Après pré-contrôle : barre puis callback |

Aucun event client → serveur.

---

## 5. Callbacks

| Nom | Paramètres | Retour |
|---|---|---|
| `pop_chargeurs:reload` | `item` (string), `currentAmmo` (int : munitions du ped, toujours envoyé) | `ok, reason, amount, total` |

- Mode `native` : `amount` = munitions à ajouter, `total` = nil → le client fait `AddAmmoToPed`.
- Mode `metadata` : `currentAmmo` est ignoré ; `amount` = ajoutées, `total` = nouvelles munitions de l'arme → le
  client fait `SetPedAmmo(total)`.
- Échec → le client notifie `L(reason or 'error', amount)` (3e valeur = argument). Succès → serveur notifie `reloaded`.

Raisons : `error`, `no_weapon`, `wrong_weapon`, `ammo_full`, `missing_item` (arg = `L('item_magazine')`),
`not_supported`, `busy`.

---

## 6. NUI

Pas de NUI propre.

---

## 7. Exports publics

Aucun.

---

## 8. config.lua

`config.lua` du template à l'identique, puis :

```lua
-- ─── pop_chargeurs ───────────────────────────────────────────

-- Chargeurs (items à déclarer dans votre inventaire, voir README) : munitions ajoutées et armes compatibles.
Config.Magazines = {
    pistol_magazine = {
        ammo = 12,
        weapons = { 'WEAPON_PISTOL', 'WEAPON_PISTOL_MK2', 'WEAPON_COMBATPISTOL', 'WEAPON_SNSPISTOL',
                    'WEAPON_HEAVYPISTOL', 'WEAPON_VINTAGEPISTOL', 'WEAPON_CERAMICPISTOL', 'WEAPON_PISTOL50' },
    },
    smg_magazine = {
        ammo = 30,
        weapons = { 'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_SMG_MK2', 'WEAPON_ASSAULTSMG', 'WEAPON_COMBATPDW',
                    'WEAPON_MINISMG', 'WEAPON_MACHINEPISTOL' },
    },
    rifle_magazine = {
        ammo = 30,
        weapons = { 'WEAPON_ASSAULTRIFLE', 'WEAPON_ASSAULTRIFLE_MK2', 'WEAPON_CARBINERIFLE', 'WEAPON_CARBINERIFLE_MK2',
                    'WEAPON_ADVANCEDRIFLE', 'WEAPON_SPECIALCARBINE', 'WEAPON_BULLPUPRIFLE', 'WEAPON_COMPACTRIFLE' },
    },
    shotgun_shells = {
        ammo = 8,
        weapons = { 'WEAPON_PUMPSHOTGUN', 'WEAPON_PUMPSHOTGUN_MK2', 'WEAPON_SAWNOFFSHOTGUN', 'WEAPON_BULLPUPSHOTGUN',
                    'WEAPON_HEAVYSHOTGUN', 'WEAPON_COMBATSHOTGUN' },
    },
}

-- Munitions max dans une arme après rechargement.
Config.MaxAmmo = 250

-- Durée du rechargement (ms).
Config.ReloadTime = 1500
```
Au démarrage, les deux côtés construisent `compatible[item][joaat(weapon)] = true`.

---

## 9. Locales

10 fichiers (écrits par le Dev Serveur).

| Clé | en | fr |
|---|---|---|
| `reloading` | Reloading... | Rechargement... |
| `reloaded` | +%s rounds | +%s munitions |
| `no_weapon` | Hold a weapon first | Prenez d'abord une arme en main |
| `wrong_weapon` | This magazine doesn't fit this weapon | Ce chargeur ne va pas sur cette arme |
| `ammo_full` | This weapon is already full | Cette arme est déjà pleine |
| `not_supported` | Your inventory doesn't support magazines | Votre inventaire ne gère pas les chargeurs |
| `item_magazine` | Magazine | Chargeur |

Clés de base réutilisées : `missing_item`, `busy`, `error`, `progress_cancelled`.

---

## 10. Schéma SQL

Aucun.

---

## 11. Comportement client (`client/main.lua`)

- **`reload(item)`** : ignoré si `Bridge.IsBusy()` ou rechargement en cours.
  `weapon = GetSelectedPedWeapon(ped)` ; non compatible avec `item` → notification `wrong_weapon`.
  `current = GetAmmoInPedWeapon(ped, weapon)` ; `max = math.min(Config.MaxAmmo, select(2, GetMaxAmmo(ped, weapon)))` ;
  `current >= max` → notification `ammo_full` (confort ; le serveur revérifie). Le client ne connaît pas le mode et
  n'en a pas besoin.
- `Bridge.Progress(L('reloading'), Config.ReloadTime, { disableMovement = false, disableCombat = true })` ; si
  terminée et même arme toujours en main → `Callback.Await('pop_chargeurs:reload', item, current)`.
- Succès : `total` non nil → `SetPedAmmo(ped, weapon, total)` ; sinon `AddAmmoToPed(ped, weapon, amount)`.
  Puis `MakePedReload(ped)`.
- Aucun thread permanent.

---

## 12. Sécurité serveur (`server/main.lua`)

**Items utilisables** : `Bridge.RegisterUsableItem(name, onUse)` pour chaque clé de `Config.Magazines`.
`onUse(src, item)` : arme serveur `GetSelectedPedWeapon(GetPlayerPed(src))` ; `WEAPON_UNARMED` → `no_weapon` ;
non compatible → `wrong_weapon` ; **mode metadata** : `Weapons.GetCurrent(src)` avant la barre (nil → `not_supported`
si l'export manque, sinon `no_weapon` ; nom différent de l'arme en main → `wrong_weapon` ; pleine → `ammo_full`)
(notifications serveur) ; sinon `reload` vers le client. Rien n'est retiré.

**`pop_chargeurs:reload(item, currentAmmo)`**
1. `item` est une clé de `Config.Magazines`, sinon `error`. Verrou `busy[src]` → `busy`.
2. Anti-abus : au plus un rechargement par `Config.ReloadTime - 200` ms et par joueur, sinon `busy`.
3. Arme **lue côté serveur** (`GetSelectedPedWeapon`) compatible, sinon `wrong_weapon` (`no_weapon` si mains vides).
4. `Bridge.HasItem(src, item)`, sinon `missing_item` + `L('item_magazine')`.
5. **Mode metadata** : `w = Weapons.GetCurrent(src)` (nil → `not_supported` si l'export manque, sinon `no_weapon`) ;
   `joaat(w.name)` doit être l'arme en main ; `w.ammo >= Config.MaxAmmo` → `ammo_full` ;
   `amount = math.min(mag.ammo, Config.MaxAmmo - w.ammo)` ; `Bridge.RemoveItem(src, item, 1)` (échec →
   `missing_item`) ; `Weapons.SetAmmo(src, w.slot, w.ammo + amount)` ; échec → `error`, et le chargeur n'est rendu
   (`Bridge.AddItem`) que si rien n'a été envoyé à l'inventaire, ou si la relecture montre le même slot avec `ammo`
   inchangé ; sinon log console (pas de remboursement : les munitions ont peut-être été écrites). Retour `true, nil, amount, w.ammo + amount`.
6. **Mode native** : `currentAmmo` entier ≥ 0 (sinon 0) ; `currentAmmo >= Config.MaxAmmo` → `ammo_full` ;
   `amount = math.min(mag.ammo, Config.MaxAmmo - currentAmmo)` ; `Bridge.RemoveItem(src, item, 1)` (échec →
   `missing_item`). Retour `true, nil, amount, nil`.
7. Notification `reloaded` (amount).

Le serveur ne reçoit jamais de nom d'arme du client. `busy` et l'horodatage nettoyés dans
`Bridge.OnPlayerDropped` / `Bridge.OnPlayerUnloaded`.

---

## 13. Limites (README, à écrire telles quelles)
- **Mode native** : le serveur ne peut pas lire les munitions du ped ; le plafond s'appuie sur la valeur envoyée par
  le client. Le chargeur est toujours retiré côté serveur avant tout ajout : impossible d'obtenir des munitions sans
  chargeur par ce script.
- **qb-inventory / qs-inventory** : les armes sont des items, mais leurs munitions sont relues sur le ped par
  l'inventaire (qb-weapons…) : le mode native fonctionne. Si votre version ne sauvegarde pas les munitions du ped,
  elles seront perdues à la déconnexion (comportement de l'inventaire, pas du script).
- **ox_inventory** : ses propres munitions (items `ammo-9`…, touche R) continuent de marcher ; les chargeurs sont un
  ajout. À valider en test : l'arme équipée reprend bien la nouvelle valeur après `SetMetadata` + `SetPedAmmo`
  (procédure dans le README, « In-game test »).
- **pop_inventory** : nécessite `GetCurrentWeapon` et `SetMetadata` (API ox), sinon `not_supported`.
- **Standalone sans inventaire** : aucun item, script inactif.

## 14. Checklist auditeur
- Copies strictes ; 10 locales ; aucun texte en dur.
- Aucune boucle ; `Wait(0)` seulement dans `Bridge.Progress`.
- Chargeur retiré avant l'ajout de munitions ; rendu seulement si l'écriture n'a sûrement pas eu lieu.
- Seul `server/weapons.lua` appelle directement un inventaire.
