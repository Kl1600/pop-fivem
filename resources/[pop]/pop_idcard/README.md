# pop_idcard

Carte d'identité américaine ou mexicaine, avec la photo du titulaire.

## Fonctionnement
- La carte est un objet pop_inventory (`idcard` ou `idcard_mx`) dont les métadonnées gardent prénom, nom, sexe, identifiant ESX du titulaire et type de carte.
- Elle est créée par pop_charcreator à la création du personnage (dans le portefeuille si fourni), ou par la commande admin `giveidcard`. Nationalité `nuevopaso` → carte mexicaine.
- À l'utilisation de l'objet, pop_inventory déclenche `pop_idcard:display` : la carte s'affiche en NUI.
- Photo : jamais stockée. Le client photographie le ped du titulaire (le sien, ou celui du titulaire s'il est connecté et à moins de 15 m, vérifié aussi côté serveur à 20 m). Sinon le fond gris par défaut reste affiché.
- Fermeture : Échap, Entrée ou retour arrière. La boucle de touches ne tourne que carte ouverte.

## Dépendances
es_extended, oxmysql (table `users` : firstname, lastname, skin), pop_inventory, pop_notify (notifications, facultatif).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | objets, nationalité mexicaine, distances et délai de la photo, durée des notifications |
| `locales/fr.lua` | tous les textes Lua |
| `client/photo.lua` | recherche du titulaire et photo (`IdCard.GetHolderPed`, `IdCard.TakeHeadshot`) |
| `client/main.lua` | affichage, fermeture, boucle Échap |
| `server/common.lua` | création de la carte (`IdCard.Issue`), accès ESX / pop_inventory directs |
| `server/main.lua` | évènements, photo côté serveur, commande `giveidcard` |
| `html/` | interface (cartes US en image `bg.webp`, MX en HTML/CSS) |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes
| Commande | Rôle |
|---|---|
| `giveidcard <id>` | groupe ESX admin ou console (id obligatoire depuis la console) : donne une carte au joueur |

## Évènements
| Nom | Sens | Rôle |
|---|---|---|
| `pop_idcard:display` (itemData) | serveur → client | affiche la carte (pop_inventory) |
| `pop_idcard:server:issueCardInternal` (targetId, containerId?, customData?) | serveur → serveur | crée la carte (pop_charcreator) |
| `pop_idcard:server:issueCard` (targetId) | serveur uniquement | crée la carte (refusé si envoyé par un client) |
| `pop_idcard:server:holder` (reqId, identifier) | client → serveur | demande le server id du titulaire proche |
| `pop_idcard:client:holder` (reqId, serverId) | serveur → client | réponse (0 si absent ou trop loin) |

## Relancer
`restart pop_idcard`
