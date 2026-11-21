# pop_crew

Système de crew minimal : créer un crew, recruter, quitter, dissoudre, choisir une couleur. Base d'appartenance pour la guerre de territoires (pop_territories).

## Fonctionnement
- `/crew` ouvre le menu NUI : créer un crew (tag 2 à 12 caractères + nom), accepter / refuser une invitation, voir les membres, quitter ou dissoudre, changer la couleur (chef).
- Recrutement : le chef vise un joueur proche avec ox_target, option **Recruter dans le crew**. Le serveur vérifie que la cible est à moins de 10 m (`Config.RecruitMaxDistance`).
- Données en base : tables `crews` et `crew_members` (créées au démarrage si absentes), gardées en mémoire côté serveur.
- Un crew dissous ou recoloré prévient pop_territories par évènement serveur.

## Dépendances
es_extended (via le bridge), oxmysql, ox_target, pop_notify (notifications, via le bridge).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | commande, longueur du tag / nom, couleur par défaut, distances, durée des notifications |
| `locales/fr.lua` | textes du jeu (notifications, option ox_target) ; ceux du menu sont dans `html/app.js` |
| `client/main.lua` | menu NUI, cache d'état, option ox_target de recrutement |
| `server/common.lua` | fonctions partagées (`Crew.*`) : notifications, nettoyage tag / nom, état du menu |
| `server/database.lua` | création des tables et chargement |
| `server/exports.lua` | exports pour les autres scripts |
| `server/actions.lua` | créer, inviter, accepter, refuser, quitter, dissoudre, couleur ; callback d'état |
| `html/` | menu NUI |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes / touches
| Commande | Rôle |
|---|---|
| `/crew` (`Config.Command`) | ouvre / ferme le menu (ignorée si F7 est enfoncée, ancien raccourci) |

## Évènements, callbacks et exports
| Nom | Sens | Rôle |
|---|---|---|
| `pop_crew:getState` (Callback) | client → serveur | état du joueur pour le menu |
| `pop_crew:state` | serveur → client | nouvel état après une action |
| `pop_crew:create` (tag, label) / `accept` / `decline` / `leave` / `disband` / `invite` (targetId) / `setColor` (color) | client → serveur | actions du menu |
| `pop_crew:disbanded` (crewId) | serveur (local) | crew dissous (pop_territories) |
| `pop_crew:colorChanged` (crewId, rgb) | serveur (local) | couleur changée (pop_territories) |
| `exports.pop_crew:getCrew(src)` | serveur | `{ id, name, label, color }` ou nil |
| `exports.pop_crew:getCrewById(crewId)` | serveur | idem |
| `exports.pop_crew:getCrewIdByIdentifier(identifier)` | serveur | id du crew ou nil |
| `exports.pop_crew:getOnlineMemberSources(crewId)` | serveur | sources des membres connectés |

## Relancer
`restart pop_crew`
