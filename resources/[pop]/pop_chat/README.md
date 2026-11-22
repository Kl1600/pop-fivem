# pop_chat

Commande roleplay `/me` : l'action s'affiche au-dessus de la tête du joueur et dans le chat des joueurs proches.

## Fonctionnement
- Le joueur tape `/me <action>`. Le serveur limite à un message toutes les `Config.Cooldown` ms, retire `<` et `>`, coupe à `Config.MaxLength` caractères.
- Le nom affiché est le nom RP du personnage (bridge), sinon le nom du compte.
- Les joueurs à moins de `Config.Distance` m voient le texte 3D pendant `Config.DisplayTime` ms et le message dans leur chat.

## Dépendances
Aucune obligatoire (framework détecté par le bridge). `chat` pour l'affichage dans le chat.

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | réglages communs POP + distance, délai, longueur, durée d'affichage |
| `locales/fr.lua` | textes (suggestion de la commande) |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier) |
| `client/main.lua` | commande `/me`, affichage 3D |
| `server/main.lua` | contrôle, nom RP, diffusion aux joueurs proches |

## Commandes
| Commande | Rôle |
|---|---|
| `/me <action>` | affiche une action roleplay |

## Évènements
| Évènement | Côté | Rôle |
|---|---|---|
| `pop_chat:me` (message) | serveur | envoi d'un /me |
| `pop_chat:showMe` (serverId, nom, message) | client | affichage au-dessus de la tête |

## Relancer
`restart pop_chat`

## Chat staff
- `/staff message` (ou `/sc message`) : message visible **uniquement par le staff** (même règle que le menu admin : groupes admin, ACE, identifiants listés). Affiché en bleu : `[STAFF] KL : message`. Aussi écrit dans la console du serveur. Depuis la console : `staff message`.
- Les actions du menu admin sont annoncées au staff en gris : `[STAFF] KL a réanimé Dano` (tp, amener, geler, soigner, réanimer, tuer, kick, ban, argent, job, groupe, give, heure, météo, suppression de véhicule).
- Pour annoncer une action depuis un autre script : `exports.pop_chat:StaffLog(src, 'a fait ...')` (serveur).
- Réglages : `Config.StaffCommands`, `Config.StaffColor`, `Config.StaffLogColor`.
