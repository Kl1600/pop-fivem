# pop_v3dui

Brique d'affichage : prompts « E », textes et icônes posés dans le monde 3D, rendus en HTML/CSS. Utilisée par les autres scripts POP via ses exports.

## Fonctionnement
- Un élément n'est affiché que s'il est à portée (`drawDistance`) et à l'écran.
- À portée : positions envoyées toutes les `Config.RefreshNear` ms, seulement si l'élément a bougé à l'écran ; sinon le script dort `Config.RefreshIdle` ms.
- Les éléments d'une ressource arrêtée sont supprimés automatiquement.

## Dépendances
Aucune.

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | distance par défaut, fréquences, tolérances |
| `client/main.lua` | gestion des éléments et boucle d'affichage |
| `html/` | rendu (inchangé) |

## Exports (client)
| Export | Rôle |
|---|---|
| `Create({ coords, type, content, drawDistance?, offset?, style? })` → id | crée un élément (`type` : text, box, prompt, icon-text ; `content` : text, key, label, icon) |
| `Remove(id)` | supprime un élément |
| `Update(id, content)` | change le contenu |
| `UpdateCoords(id, coords)` | déplace l'élément |
| `ClearAll()` | supprime tout |

Exemple :
```lua
local id = exports.pop_v3dui:Create({ coords = vec3(0, 0, 72), type = 'prompt', content = { key = 'E', label = 'PARLER', icon = 'fas fa-comments' } })
exports.pop_v3dui:Remove(id)
```

## Relancer
`restart pop_v3dui` (les scripts qui l'utilisent recréent leurs prompts quand le joueur se rapproche ; sinon les relancer aussi).
