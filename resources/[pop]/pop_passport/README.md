# pop_passport

Passeports américain (US) et mexicain (MX) : délivrance et affichage en NUI avec la photo du titulaire.

## Fonctionnement
- Les objets `passport_us` / `passport_mx` (pop_inventory) déclenchent `pop_passport:display:us|mx` à l'utilisation : le passeport s'affiche (page imprimée US ou MX).
- Les infos (nom, prénom, sexe, date de naissance, expiration, numéro) sont dans les métadonnées de l'objet. La photo n'est pas stockée : on photographie le ped du titulaire (le sien, ou celui du titulaire s'il est connecté et à portée). Sinon, le fond par défaut de la photo reste affiché.
- Fermeture : Échap / Entrée. La boucle Échap côté Lua ne tourne que passeport ouvert.
- Délivrance : par pop_charcreator (`pop_passport:server:issueInternal`, avec ou sans conteneur portefeuille) ou par la commande admin `givepassport`. Validité 10 ans, numéro `A` (US) / `G` (MX) + 8 chiffres.

## Dépendances
es_extended, oxmysql (table `users`), pop_inventory (exports `GiveItem`, `addItemToContainer`), pop_notify (notifications, via le bridge).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | portées de la photo, validité, durée des notifications |
| `locales/fr.lua` | tous les textes Lua |
| `client/photo.lua` | recherche du titulaire et photo (`Passport.GetHolderPed`, `Passport.TakeHeadshot`) |
| `client/main.lua` | affichage NUI, boucle Échap, fermeture |
| `server/common.lua` | fonctions partagées (`Passport.*`), délivrance d'un passeport |
| `server/main.lua` | évènements serveur (délivrance interne, titulaire pour la photo) |
| `server/commands.lua` | commande `givepassport` |
| `html/` | interface (images en WebP) |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes
| Commande | Rôle |
|---|---|
| `givepassport <id> [us/mx]` | groupe ESX `admin` ; utilisable en console (id obligatoire) |

## Évènements
| Nom | Sens | Rôle |
|---|---|---|
| `pop_passport:display:us` / `pop_passport:display:mx` (itemData) | serveur → client | affiche le passeport (appelé par pop_inventory) |
| `pop_passport:server:issueInternal` (targetId, type, containerId?, customData?) | serveur → serveur | délivre un passeport (appelé par pop_charcreator) |
| `pop_passport:server:holder` (reqId, identifier) | client → serveur | demande le server id du titulaire pour la photo |
| `pop_passport:client:holder` (reqId, serverId) | serveur → client | réponse (0 si absent ou trop loin) |

## Relancer
`restart pop_passport`
