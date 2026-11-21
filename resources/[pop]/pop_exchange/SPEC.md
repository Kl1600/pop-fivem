# pop_exchange : SPEC (contrat commun Serveur / Client / NUI)

> Ce document est **la référence unique**. Les noms (fichiers, events, callbacks, clés de config, clés de locale,
> champs de données, messages NUI) doivent être repris **à l'identique**. En cas de doute : ce fichier fait foi.
> API commune à utiliser telle quelle : `Bridge.*`, `Callback.*`, `L()` (voir `templates/pop_base/README.md`).

---

## 1. Description et fonctionnalités

Bureau de change : un PNJ échange une monnaie contre une autre à un **taux fixe** (config). Le modèle d'origine
change des dollars (espèces) contre des pesos (item) et inversement. POP généralise simplement : chaque **offre**
convertit un compte d'argent (`cash`, `bank`, `black`) ou un item vers un autre compte ou item. Cela couvre :
- le change de devises (dollars ⇄ pesos) ;
- le **blanchiment** (argent sale → espèces, taux défavorable, risque d'alerte police) dans un lieu discret ;
- la revente d'un item contre de l'argent si le serveur le souhaite.

**Boucle de jeu**
1. Parler au changeur (`[E] Parler au changeur`).
2. Petit panneau à droite : offres du lieu, solde de la monnaie donnée, choix du montant, aperçu « Vous recevez »,
   limite restante de l'heure.
3. Confirmer → le serveur vérifie et échange. Panneau mis à jour.

**Règles**
- Taux par offre ; montant entier ; résultat arrondi à l'inférieur (au moins 1, sinon refus).
- **Limite par heure** (fenêtre glissante, en mémoire) par joueur et par offre, exprimée dans la monnaie donnée.
- Une offre peut alerter la police (`alert` = probabilité par transaction) : choix GTA 6 « rapide mais risqué ».
- Chaque lieu ne propose que ses offres (`offers`) : le blanchiment se fait ailleurs que le bureau public.

**UI** : panneau sobre à droite (≈ 300 px), focus NUI pendant l'ouverture.

**Performance** : PNJ local par distance (boucle 1000/2500 ms) ; aucun `Wait(0)`. Serveur : aucune boucle (les
fenêtres de limite sont purgées à la lecture).

**Hors périmètre** : taux variables, caméra cinématique, stocks du changeur, persistance des limites.

---

## 2. Arborescence et attribution

```
resources/[pop]/pop_exchange/
  SPEC.md                 Architecte (ce fichier)
  fxmanifest.lua          SERVEUR
  config.lua              SERVEUR   (clés communes de pop_base + section 8)
  README.md               SERVEUR   (en ANGLAIS : installation, écrire une offre, item pesos, compte black)
  locales/en.lua … ar.lua SERVEUR   10 fichiers, ar : _rtl = true
  server/main.lua         SERVEUR
  client/main.lua         CLIENT    blips, PNJ, target, ouverture, callbacks NUI, alerte police
  web/index.html          NUI
  web/script.js           NUI
  web/style.css           NUI
```
`bridge/`, `shared/callback.lua`, `shared/locale.lua`, `web/kit/` : **copiés par l'intégrateur**.

### fxmanifest.lua (exact)
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pop_exchange'
author 'POP'
version '1.0.0'
description 'POP Exchange - currency exchange and money laundering'

shared_scripts {
    'config.lua',
    'shared/*.lua',
    'locales/*.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/*.lua',
}

server_scripts {
    'bridge/server.lua',
    'server/*.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/**',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'bridge/*.lua',
}
```
Pas d'oxmysql.

---

## 3. Données

### Monnaie (dans la config)
```lua
{ money = 'cash' }   -- compte : 'cash' | 'bank' | 'black'
{ item = 'pesos' }   -- item d'inventaire
```
Libellé d'une monnaie : locale `currency_<nom>` (`currency_cash`, `currency_black`, `currency_pesos`…).

### `OfferView` (serveur → client → NUI)
```lua
{
    id        = 'usd_pesos',
    from      = 'cash',     -- nom de la monnaie donnée (compte ou item)
    to        = 'pesos',    -- nom de la monnaie reçue
    rate      = 20.0,       -- number
    balance   = 1250,       -- int : solde du joueur dans la monnaie donnée
    presets   = { { id = 'preset_4', amount = 100 } }, -- options choisies par le serveur
    remaining = 1250,       -- int : quantité encore échangeable cette heure (min(limite restante, solde))
}
```
Jamais de champ `alert` envoyé au client.

---

## 4. Events

### Serveur → Client
| Event | Paramètres | Destinataire | Rôle |
|---|---|---|---|
| `pop_exchange:client:policeAlert` | `coords` (`{ x, y, z }`) | chaque policier en service | Notification + blip temporaire |

Aucun `RegisterNetEvent` serveur propre au script. Le verrou et la limite horaire sont indexés par identifiant
de personnage. Une déconnexion n’interrompt pas le verrou détenu par une opération en cours.

---

## 5. Callbacks (`shared/callback.lua`)

| Nom | Paramètres (client → serveur) | Retour |
|---|---|---|
| `pop_exchange:getOffers` | `loc` (int) | `ok, reason, arg, offers` (tableau séquentiel d'OfferView, dans l'ordre de `offers` du lieu) |
| `pop_exchange:exchange` | `loc` (int), `id` (string), `preset` (string) | `ok, reason, arg, offers` (à jour, si le personnage est encore à portée) |

Échec → message `L(reason or 'error', arg)` ; succès → `reason = 'exchanged'`, `arg = { given, received }` : le client
traduit avec `L(reason, table.unpack(type(arg) == 'table' and arg or { arg }))`. Le résultat est affiché **dans le
panneau** (ligne d'état), pas en notification.

Raisons : `error`, `busy`, `too_far`, `invalid_amount`, `offer_unknown`, `not_enough`, `amount_too_low`,
`hourly_limit` (arg = quantité restante), `inventory_full`.

---

## 6. Messages NUI

Focus `SetNuiFocus(true, true)` à l'ouverture. Échap → kit `close` → `Bridge.OnUiClose` → `pop_exchange:close`.

### Lua → JS
```json
{ "action": "pop_exchange:open", "offers": [
  { "id": "usd_pesos", "from": "cash", "to": "pesos", "rate": 20.0, "balance": 1250, "remaining": 1250 } ] }
```
```json
{ "action": "pop_exchange:close" }
```

### JS → Lua
| Nom | Données | Réponse |
|---|---|---|
| `pop_exchange:exchange` | `{ "id": "usd_pesos", "preset": "preset_4" }` | `{ "ok": true, "message": "You gave 100 Dollars and received 2000 Pesos", "offers": [ ... ] }` |
| `close` | (kit) | bridge |

Le client garde l'index du lieu, transmet l’identifiant `preset`, appelle
`pop_exchange:exchange` et répond avec le message déjà traduit. Pendant l'attente, le JS bloque le bouton.

### Interface (Dev NUI)
- `web/index.html` : `style.css` après `kit/pop.css`. `#exchange` (`pop-panel pop-fade`, masqué) :
  - titre `data-locale="ui_title"`, bouton `#ex-close` (`close`) ;
  - liste d'offres `#ex-offers` (une ligne cliquable par offre) : `Pop.t('currency_' + from) → Pop.t('currency_' + to)`
    et en petit `Pop.t('ui_rate', '1', Pop.t('currency_' + from), rate, Pop.t('currency_' + to))` ; première offre
    sélectionnée par défaut ;
  - `Pop.t('ui_balance', balance)`, `Pop.t('ui_remaining', remaining)` (petit) ;
  - sélecteur `#ex-amount` (entrées de `OfferView.presets`) ; bouton `Max` sélectionne l’option `max` ;
  - aperçu `#ex-preview` : `Pop.t('ui_receive', Math.floor(amount * rate), Pop.t('currency_' + to))` en accent ;
  - bouton `#ex-confirm` (`confirm`), désactivé si l'aperçu vaut 0 ou `amount > remaining` ;
  - ligne `#ex-status` (`--pop-danger` si `ok = false`).
- Nombres : `toLocaleString()`. Aucun texte en dur. Entrée = valider.
- `web/style.css` : `position: fixed; right: 24px; top: 50%; transform: translateY(-50%); width: 300px;` offre
  sélectionnée = `border-inline-start: 2px solid var(--pop-accent)`. RTL : `right: auto; left: 24px`.

---

## 7. Exports publics

Serveur :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_exchange:GetRate(id)` | number \| nil | taux d'une offre |
| `exports.pop_exchange:ResetLimits(src)` | bool | efface les limites horaires du joueur |

Client :
| Export | Retour | Rôle |
|---|---|---|
| `exports.pop_exchange:IsOpen()` | bool | panneau ouvert |

---

## 8. config.lua (contenu exact)

Reprend **à l'identique** le `config.lua` de `templates/pop_base`, puis ajoute :

```lua
-- ─── pop_exchange ───────────────────────────────────────────

-- Offres. from / to : { money = 'cash' | 'bank' | 'black' } ou { item = 'nom' }.
-- rate  : quantité reçue pour 1 donnée (résultat arrondi à l'inférieur).
-- limit : quantité max donnée par heure et par joueur.
-- alert : chance d'alerter la police à chaque échange (0 = jamais).
-- Libellés des monnaies : locales currency_<nom>.
Config.Offers = {
    usd_pesos = { from = { money = 'cash' }, to = { item = 'pesos' },  rate = 20.0,  limit = 10000,  alert = 0.0 },
    pesos_usd = { from = { item = 'pesos' }, to = { money = 'cash' },  rate = 0.045, limit = 200000, alert = 0.0 },
    launder   = { from = { money = 'black' }, to = { money = 'cash' }, rate = 0.7,   limit = 20000,  alert = 0.15 },
}

-- Bureaux. offers = ids proposés ici. ped = modèle du PNJ (false : zone). blip = afficher sur la carte.
Config.Amounts = { 1, 10, 25, 100, 500, 1000, 5000, 10000 } -- surcharge par offre via amounts
Config.Locations = {
    { coords = vector4(-639.07, -180.47, 37.68, 33.0), ped = 's_m_m_cntrybar_01', blip = true,
      offers = { 'usd_pesos', 'pesos_usd' } },
    { coords = vector4(474.05, -1309.83, 29.21, 115.0), ped = 'g_m_m_armboss_01', blip = false,
      offers = { 'launder' } },
}

Config.Blip = { sprite = 500, color = 2, scale = 0.8 }

Config.Police = {
    jobs     = { 'police', 'sheriff' }, -- format Bridge.HasJob ; doivent être en service
    blipTime = 60,                      -- durée du blip d'alerte (secondes)
}
```

Constantes (code) : `ACTION_DISTANCE = 3.0`, `TARGET_DISTANCE = 2.0`, `PED_DISTANCE = 40.0`, `HOUR = 3600`.
NOTE : `black` n'existe pas par défaut en QBCore/Qbox (le bridge renvoie 0 / false) : README l'explique et propose
une offre `{ item = 'markedbills' }`.

---

## 9. Locales

10 fichiers (en, fr, es, de, it, pt, nl, pl, tr, ar `_rtl = true`). Bloc « Kit commun » + clés ci-dessous.

| Clé | en | fr |
|---|---|---|
| `blip_name` | Currency exchange | Bureau de change |
| `target_talk` | Talk to the money changer | Parler au changeur |
| `ui_title` | Currency exchange | Bureau de change |
| `ui_rate` | %s %s = %s %s | %s %s = %s %s |
| `ui_balance` | You have: %s | Vous avez : %s |
| `ui_remaining` | Available this hour: %s | Disponible cette heure : %s |
| `ui_amount` | Amount | Montant |
| `ui_max` | Max | Max |
| `ui_receive` | You receive: %s %s | Vous recevez : %s %s |
| `currency_cash` | Dollars | Dollars |
| `currency_bank` | Dollars (bank) | Dollars (banque) |
| `currency_black` | Dirty money | Argent sale |
| `currency_pesos` | Pesos | Pesos |
| `exchanged` | You gave %s and received %s | Vous avez donné %s et reçu %s |
| `invalid_amount` | Invalid amount | Montant invalide |
| `offer_unknown` | This exchange isn't available here | Cet échange n'est pas proposé ici |
| `not_enough` | You don't have enough | Vous n'en avez pas assez |
| `amount_too_low` | Amount too low | Montant trop faible |
| `hourly_limit` | Hourly limit reached (%s left) | Limite horaire atteinte (reste %s) |
| `police_alert` | Suspicious money exchange reported | Échange d'argent suspect signalé |
| `police_blip` | Suspicious exchange | Échange suspect |

Clés de base réutilisées : `confirm`, `close`, `too_far`, `inventory_full`, `busy`, `error`.
`exchanged` reçoit deux textes déjà composés côté serveur : `('%d %s'):format(n, L('currency_' .. nom))`.

---

## 10. Schéma SQL

Aucun. README : déclaration de l'item `pesos` (ox_inventory, qb/qs-inventory, ESX `items`).

---

## 11. Comportement attendu

### Serveur
- Fonctions locales : `balance(src, cur)` (`cur.money` → `Bridge.GetMoney` ; `cur.item` → `Bridge.GetItemCount`),
  `take(src, cur, n)` (`RemoveMoney` / `RemoveItem`), `give(src, cur, n)` (`AddMoney` / `AddItem`),
  `canReceive(src, cur, n)` (`true` pour l'argent, `Bridge.CanCarry` pour un item), `name(cur)` (= `cur.money or cur.item`).
- Limites : `history[identifier][id] = { { t = os.time(), n = 100 }, ... }` ; `used = somme des n où t > now - HOUR`
  (entrées plus anciennes supprimées à la lecture) ; `remaining = max(0, limit - used)`.
- Au démarrage : vérification de la config (print anglais pour tout id de `Config.Locations[].offers` absent de
  `Config.Offers`, ou offre invalide. Une offre mal configurée reste masquée. Les entrées expirées sont purgées après une heure d’inactivité).
- Alerte : si `math.random() < offer.alert` après un échange réussi → `pop_exchange:client:policeAlert` avec
  `{ x, y, z }` du lieu à chaque `src` de `Bridge.GetPlayers()` tel que `Bridge.HasJob(src, Config.Police.jobs)` et
  `Bridge.GetJob(src).onDuty`.

### Client
- Blips (`Config.Blip`, nom `L('blip_name')`) pour `blip = true`. PNJ locaux par distance (boucle unique
  `Wait(nearest < PED_DISTANCE and 1000 or 2500)`, RequestModel timeout 3 s, figé, invincible, scénario
  `WORLD_HUMAN_STAND_IMPATIENT`), `Bridge.Target.AddLocalEntity` ; lieux sans PNJ : `AddBoxZone('pop_exchange_' .. i,
  xyz, vec3(1.5, 1.5, 2.0), w, opts)`.
- Option : `{ label = L('target_talk'), icon = 'fa-solid fa-money-bill-transfer', distance = TARGET_DISTANCE }`.
- Ouverture : ignorée si ouvert ou `Bridge.IsBusy()` ; `Callback.Await('pop_exchange:getOffers', i)` ; focus +
  `pop_exchange:open`. Surveillance 500 ms (distance > 3.0, mort → fermeture).
- Alerte police : `Bridge.Notify(L('police_alert'), 'warning')` + blip (sprite 500, couleur 1, nom
  `L('police_blip')`) supprimé après `Config.Police.blipTime` s.
- Arrêt : PNJ, blips, `pop_exchange:close`.

---

## 12. Règles de sécurité (serveur, obligatoires)

Le client envoie un index de lieu, un id d’offre et un identifiant de montant. Taux, montants, monnaies et limites
viennent de la configuration et du serveur.
1. `loc` entier valide ; `Bridge.IsNear(src, lieu, ACTION_DISTANCE)`, sinon `too_far`.
2. `id` string présente dans `Config.Locations[loc].offers` **et** dans `Config.Offers`, sinon `offer_unknown`.
3. Résoudre `preset` via la configuration ou calculer le maximum côté serveur. Le montant obtenu est un
   entier de 1 à 10 000 000, sinon `invalid_amount`.
4. `received = math.floor(amount * offer.rate)` ; `received < 1` → `amount_too_low`. La configuration borne aussi le résultat à 10 000 000.
5. Limite : `amount > remaining` → `hourly_limit` (arg = remaining).
6. `balance(src, from) >= amount`, sinon `not_enough`.
7. `canReceive(src, to, received)`, sinon `inventory_full`.
8. Ordre : `take` (échec → `not_enough`) → `give` (échec → **rendre** `amount` via `give(src, from, amount)` et
   `error`) → enregistrer `{ t, n = amount }` dans la limite.
9. Verrou par identifiant → `busy`, libéré dans tous les cas ; joueur mort → `error` ; `Bridge.GetIdentifier` non nil.
   Anti-spam du template actif.
10. Aucune information d'alerte ou de probabilité envoyée au client.

---

## 13. Checklist de livraison (auditeur)
- `luacheck resources templates` : 0 erreur ; `node --check web/script.js`.
- `bridge/`, `shared/`, `web/kit/` identiques à `templates/pop_base`.
- 10 locales complètes ; aucun texte en dur.
- Aucun `Wait(0)` ; focus rendu (Échap, éloignement, mort, arrêt).
- Montants invalides refusés ; échange atomique (rien perdu si `give` échoue).
- ESX (black_money), QBCore/Qbox (offre markedbills documentée) ; ox / qb / qs-inventory et inventaire du framework.
