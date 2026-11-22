# pop_emotes

Menu d'animations discret (base RPEmotes) : emotes, danses, objets, démarches, expressions et emotes à deux, avec aperçu du personnage.

## Fonctionnement
- **F5** (ou `/animenu`) ouvre le menu à droite de l'écran, avec un aperçu du personnage qui joue l'animation survolée. On peut marcher menu ouvert.
- Les listes viennent de `shared/emotes.lua` et `shared/emotes_custom.lua` (format RPEmotes, 1 823 emotes). Les animations et objets personnalisés sont dans `stream/`.
- **Emote à deux** (`/nearby <nom>`) : le joueur le plus proche (3 m) reçoit une demande et accepte avec **Y** (5 s). Le serveur ne transmet que le nom de l'emote, vérifie la demande (15 s) et la distance (10 m). Seul le partenaire peut arrêter l'emote de l'autre.
- **Copier / cloner** l'emote d'un joueur proche (export `CopyEmoteFromPlayer`, utilisé par pop_inventory) : même contrôle de demande et de distance.
- **S'accroupir** : Ctrl gauche. La démarche choisie et les favoris sont gardés sur le PC du joueur (KVP).
- En parlant à la radio (pma-voice), l'emote `radio2` se joue automatiquement.

## Dépendances
Aucune obligatoire. pop_notify pour les notifications (sinon notification du framework), pma-voice pour l'animation radio.

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | touches (menu, accroupi), distances et délais des emotes à deux |
| `locales/fr.lua` | textes des notifications et des touches |
| `client/emote.lua` | jouer / arrêter une emote, objets attachés, aperçu du personnage |
| `client/menu.lua` | menu NUI (ouverture, liste, aperçu, lancement) |
| `client/events.lua` | commandes `/e`, `/walk`, `/nearby`, emotes à deux, copie |
| `client/favorites.lua` | favoris (KVP) |
| `client/crouch.lua` | s'accroupir |
| `client/radio_anim.lua` | animation en parlant à la radio |
| `server/main.lua` | relais et contrôles des emotes à deux, du clonage et de la copie |
| `shared/emotes.lua`, `shared/emotes_custom.lua` | listes d'emotes (données, ne pas renommer les clés) |
| `stream/` | animations et objets personnalisés (`.ycd`, `.ydr`, `.ytyp`) |
| `html/` | menu |
| `bridge/`, `shared/callback.lua`, `shared/locale.lua` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes et touches
| Commande | Touche | Rôle |
|---|---|---|
| `/animenu` | F5 | menu des animations |
| `/e <nom>` / `/e c` | — | jouer une emote / l'arrêter |
| `/walk <nom>` | — | démarche |
| `/nearby <nom>` | — | proposer une emote à deux au joueur le plus proche |
| `+crouch` / `/crouch` | Ctrl gauche | s'accroupir |

Les touches sont des raccourcis FiveM : chaque joueur peut les changer dans Paramètres > Raccourcis > FiveM.

## Évènements et exports
| Nom | Type | Rôle |
|---|---|---|
| `GetCurrentEmoteName()` | export client | nom de l'emote en cours |
| `CopyEmoteFromPlayer(serverId)` | export client | copie l'emote d'un joueur proche (pop_inventory) |
| `IsPlayerCrouched()` | export client | joueur accroupi ? |
| `pop_emotes:AskForSharedEmote`, `AcceptSharedEmote`, `PlaySharedEmote`, `StopEmote` | évènements | emote à deux |
| `pop_emotes:CloneEmote`, `RequestCloneEmote`, `GiveEmoteCloned`, `PlayEmote` | évènements | cloner l'emote d'un joueur |
| `pop_emotes:CopyEmoteFromPlayer`, `RequestCopyEmote`, `GiveCopiedEmote`, `ReceiveCopiedEmote` | évènements | copie (export) |
| statebag `currentEmote` | — | nom de l'emote en cours, visible des autres scripts |

## Relancer
`restart pop_emotes`
