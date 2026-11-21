# pop_dealing

Vente de drogue aux PNJ, façon GTA 6 : `/sell` dans une zone de deal, un client à la fois vient vers vous,
vous négociez le prix (3 tentatives), attention aux flics infiltrés et aux témoins.

## Installation

1. Copier `pop_dealing` dans `resources/[pop]/`.
2. Dans `server.cfg`, lancer le framework, l'inventaire, le target et le dispatch **avant** `[pop]` :
   ```cfg
   ensure es_extended   # ou qb-core / qbx_core (facultatif)
   ensure ox_inventory  # facultatif
   ensure [pop]
   ```
3. Aucune dépendance obligatoire. Pas de SQL, pas d'oxmysql.

**OneSync requis** (activé par défaut sur FXServer) : le serveur lit la position du PNJ client et compte les PNJ proches.

## Items

Les noms par défaut de `Config.Drugs` sont ceux de QBCore (`weed_white-widow`, `cokebaggy`, `meth`).
Remplacez-les par les items de votre inventaire :

```lua
Config.Drugs = {
    ['weed_pooch'] = { label = 'drug_weed', price = 80, amount = { 1, 3 } },
}
```

`label` est une **clé de locale**. Pour une nouvelle drogue avec une nouvelle clé, ajoutez-la au moins dans
`locales/en.lua` (sinon la clé brute s'affiche), idéalement dans les 10 fichiers :

```lua
drug_lean = 'Lean',
```

## Paiement

`Config.Payment.type` :
- `'black'` : argent sale (compte `black_money` ESX). Si le framework n'a pas ce compte (QBCore par défaut), repli sur `cash`.
- `'cash'` : argent liquide.
- `'item'` : un item, par exemple `black_money` d'ox_inventory (`Config.Payment.item`).

En standalone (sans framework), utilisez `'item'` (avec ox_inventory par exemple) : il n'y a pas de compte d'argent.

## Zones de vente

`Config.Zones` : cercles `coords` + `radius`, `mult` = multiplicateur du prix de la rue. Liste vide = vente partout.
Les zones par défaut couvrent les territoires par défaut de pop_territories : Forum Drive (`-165, -1620`, rayon 110)
et Sandy Shores (`1850, 3700`, rayon 250) reprennent exactement le centre et le rayon de son `config.lua`, et Vespucci Beach
est placée dans son polygone `vespucci`, Davis dans le cercle `grove`. Si vous modifiez les territoires, alignez ces zones.

**Cumul des multiplicateurs** : si pop_territories est lancé, il applique son propre multiplicateur (`price` du territoire)
au montant déjà calculé avec le `mult` de la zone pop_dealing. Les deux se multiplient : c'est pourquoi toutes les zones
ont `mult = 1.0` par défaut (Vespucci a déjà `price = 1.2` dans pop_territories). Ne mettez un `mult` différent de 1.0
que sur une zone hors territoire, ou si pop_territories n'est pas utilisé.

## Intégrations optionnelles

- **Dispatch** : ps-dispatch, cd_dispatch ou qs-dispatch détectés automatiquement (`Config.Police.dispatch = 'auto'`),
  sinon notification + blip aux policiers en service. Les formats d'appel sont dans `server/police.lua`.
- **pop_territories** : s'il est lancé, chaque vente lui est déclarée (`RecordDrugSale`) et il peut ajuster le montant final
  (plafonné à 3 fois le montant calculé par sécurité).
- **Target** : ox_target ou qb-target, sinon prompt natif (touche E).

## Hook serveur

```lua
AddEventHandler('pop_dealing:sold', function(src, item, qty, amount, coords) end)
```

## Exports

```lua
exports.pop_dealing:IsSelling(src)    -- serveur, boolean
exports.pop_dealing:StopSelling(src)  -- serveur, boolean
exports.pop_dealing:IsSelling()       -- client, boolean
```

## Langues

`Config.Locale` : en, fr, es, de, it, pt, nl, pl, tr, ar. Une clé absente retombe sur l'anglais.
Ajouter une langue : copier `locales/en.lua` et changer le code.
