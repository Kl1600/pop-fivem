# pop_tablet : POP Tab

Tablette en objet d'inventaire (système « POP OS », 22 applis, 10 langues dont l'arabe en RTL). Les données (code, réglages, applis, notes, photos...) sont liées à l'objet, pas au joueur.
Cahier des charges : `SPEC.md`. Avancement : `PROGRESS.md`, `feature_list.json`. API pour les autres ressources : `docs/api-applis.md`. Exemple de ressource tierce : `examples/pop_tablet_example/` (à la racine du dépôt, hors `resources/`).

## Dépendances

- **Obligatoire** : `oxmysql` (stockage). Framework (ESX, QBCore, Qbox ou standalone), inventaire et target sont détectés par `bridge/` (`Config.Framework`, `Config.Inventory`, `Config.Target` = `auto` par défaut).
- **Optionnelles** (la fonction concernée refuse proprement si la ressource est absente) :
  - `pma-voice` : voix des appels du Téléphone. Absente : l'appel est refusé avec le message `err_no_voice`.
  - `screencapture` : photos de l'appareil (mode `database`). Absente : `err_unavailable`.
  - `ox_lib`, `ox_target` / `qb-target` : notifications et interaction, sinon repli natif.

## Installation

1. `ensure oxmysql`, le framework et l'inventaire **avant** `ensure [pop]`, puis `ensure pop_tablet` (et `ensure pma-voice`, `ensure screencapture` si voulus).
2. Base de données : les tables sont créées au premier démarrage (`sql/install.sql`, aussi exécutable à la main).
3. `server.cfg` :
   - `set pop_tablet_pepper "<chaîne aléatoire longue>"` (jamais `setr`). Sans elle, un poivre aléatoire est généré et conservé dans le KVP du serveur, avec un avertissement en console. Changer le poivre invalide tous les codes.
   - `add_ace group.admin pop.admin allow` pour `/pop_tablet_give`.
4. Jamais de build sur le serveur : l'interface construite est versionnée dans `web/dist/`.

## L'objet `pop_tablet`

À ajouter à l'inventaire du serveur : utilisable, non empilable, avec métadonnées. Le numéro de série voyage dans `metadata.serial` ; l'usage de l'objet est enregistré par la ressource.

- **ox_inventory** (`data/items.lua`) : `['pop_tablet'] = { label = 'POP Tab', weight = 500, stack = false, close = true }`
- **qb-inventory / ps-inventory / qs-inventory** (`shared/items.lua`) : `['pop_tablet'] = { name = 'pop_tablet', label = 'POP Tab', weight = 500, type = 'item', image = 'pop_tablet.png', unique = true, useable = true, shouldClose = true, description = 'Tablette POP Tab' }`
- **pop_inventory** : l'objet est déjà dans `Config.Items`. Sans métadonnées (`Bridge.SupportsMetadata()` faux), le mode « une tablette par personnage » s'applique, annoncé en console au démarrage. Même repli pour ESX de base et standalone.

## Configuration (`config.lua`)

Tout est commenté dans le fichier. Les réglages utiles :

| Clé | Rôle |
| --- | --- |
| `Config.Locale` | langue par défaut (10 langues : en, fr, es, de, it, pt, nl, pl, tr, ar) |
| `Config.Item`, `Config.Key` | nom de l'objet, touche d'ouverture (F5, réglable dans les touches de FiveM) |
| `Config.Session.IdleLockSeconds` | verrouillage après inactivité |
| `Config.Security` | itérations du hachage, essais avant blocage, durées de blocage |
| `Config.Battery`, `Config.Phone`, `Config.Mail` | batterie, format et canal des numéros, domaine des adresses |
| `Config.Photos`, `Config.Camera`, `Config.Share` | photos (`database`), caméra native, distance du partage |
| `Config.Apps`, `Config.Browser.AllowedHosts` | applis activables, hôtes `https` autorisés (Navigateur, applis API) |
| `Config.Music.Stations`, `Config.Places`, `Config.Translate`, `Config.Market` | radios, lieux de Plans, service de traduction, Bourse |
| `Config.Retention.Days` | purge des données anciennes (90 jours) |

## Utilisation

- Utiliser l'objet dans l'inventaire, ou la touche `Config.Key` si l'on porte une tablette.
- Premier allumage : code à 4 chiffres, nom, adresse mail.
- `/pop_tablet_give [id]` (admin ACE `pop.admin`, ou console) : crée une tablette avec son numéro de série.
- Langues : textes de l'interface dans `ui/pop-os/src/i18n/`, textes Lua dans `locales/` (mêmes clés dans les 10 fichiers).

## API pour les autres ressources

`exports.pop_tablet:RegisterApp`, `Notify`, `OpenApp`, `AppEvent` (et `UnregisterApp`, `GetSerial`, `RegisterSite`, `MarketShock`, `GetApiVersion`). Contrat complet et exemple : `docs/api-applis.md`, `examples/pop_tablet_example/`.

## Performance et sécurité

- Aucune boucle permanente ni polling : tout part d'un événement. Les rares attentes sont bornées et listées avec leur justification dans `tests/audit.lua`.
- Le serveur revérifie tout (objet porté, tablette déverrouillée, propriété par `serial`, taille, anti-spam). Aucun montant ni identité n'est lu dans ce qui vient du client ; la ressource ne touche pas à l'argent.
- `bridge/`, `shared/callback.lua`, `shared/locale.lua` et `web/kit/` sont copiés de `templates/pop_base` : ne pas les modifier ici.

## Commandes de vérification

Depuis ce dossier :

```
lua tests/run.lua                       # tests Lua avec faux natives + revue statique (tests/audit.lua)
luacheck "resources/[pop]/pop_tablet" templates examples   # depuis la racine du dépôt : 0 warnings / 0 errors
luac -p <fichier.lua>                   # syntaxe de chaque .lua modifié
```

Depuis `ui/pop-os` : `pnpm typecheck && pnpm test && pnpm build && pnpm verify && pnpm check` (types, vitest dont la parité des 10 langues, construction vers `web/dist`, taille et syntaxe du build, textes en dur).

## Limites connues (à valider en jeu)

Rien de ce qui suit n'a pu être prouvé hors du jeu :
- Objet tenu en main, animation, positions (`Config.Prop`, `Config.Anim`) et caméra native.
- Natives d'horloge, de météo et de vent (mois, vent, type de météo), carte de Plans (`PauseMenuceptionGoDeeper`), coordonnées des lieux.
- Conversion d'un objet sans `serial` et comportement avec chaque inventaire ; mode « une tablette par personnage ».
- Création des tables sur une base réelle (`sql/install.sql`) et plans de requêtes (EXPLAIN).
- Voix des appels (pma-voice), capture des photos (screencapture), micro du Dictaphone dans la NUI.
- Consommation (resmon) : 0,00 ms au repos, usage normal et caméra ; paquets réseau.
- Rendu RTL de chaque écran en arabe (le code utilise des bordures logiques, non vérifié visuellement), mise en page `compact` de chaque appli.
- Affichage réel d'une appli API dans la tablette (exemple `examples/pop_tablet_example/`).
