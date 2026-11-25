# pop_v3dui

## English

3D world UI: "E" prompts, texts and icons placed in the world, rendered in HTML/CSS. Used by the other POP scripts through its exports. Runs on any server (no framework needed).

### Installation
1. Drop `pop_v3dui` into your `resources` folder.
2. Add `ensure pop_v3dui` to your `server.cfg`, before the scripts that use it.
3. Set your language in `config.lua` (`Config.Locale`: fr, en, es, de, ar).

### Configuration (`config.lua`)
| Key | Default | Role |
|---|---|---|
| `Locale` | `'fr'` | language (en is the fallback) |
| `Debug` | `false` | debug prints |
| `DefaultDrawDistance` | `15.0` | draw distance when the element gives none |
| `RefreshNear` | `30` | ms between updates when an element is in range |
| `RefreshIdle` | `500` | ms when nothing is in range |
| `OffscreenGrace` | `250` | ms an off-screen element is kept (no flicker) |
| `PosEpsilon` | `0.0005` | minimum on-screen move before a new update |

Texts shown in prompts come from the calling script. pop_v3dui only translates its own defaults (fallback key, icon label) and switches to right-to-left for Arabic.

### Exports (client)
| Export | Role |
|---|---|
| `Create({ coords, type, content, drawDistance?, offset?, style? })` → id | creates an element (`type`: text, box, prompt, icon-text; `content`: text, key, label, icon) |
| `Remove(id)` | removes an element |
| `Update(id, content)` | changes the content |
| `UpdateCoords(id, coords)` | moves the element |
| `ClearAll()` | removes everything |

```lua
local id = exports.pop_v3dui:Create({ coords = vec3(0, 0, 72), type = 'prompt', content = { key = 'E', label = 'TALK', icon = 'fas fa-comments' } })
exports.pop_v3dui:Remove(id)
```

Elements of a stopped resource are removed automatically. Performance: ~0.00 ms when nothing is in range.

## Français

Interface 3D : prompts « E », textes et icônes posés dans le monde, rendus en HTML/CSS. Utilisée par les autres scripts POP via ses exports. Marche sur n'importe quel serveur (aucun framework requis).

### Installation
1. Mets `pop_v3dui` dans ton dossier `resources`.
2. Ajoute `ensure pop_v3dui` dans ton `server.cfg`, avant les scripts qui l'utilisent.
3. Choisis la langue dans `config.lua` (`Config.Locale` : fr, en, es, de, ar).

### Configuration
Voir le tableau ci-dessus : mêmes clés. Les textes des prompts viennent du script appelant ; pop_v3dui ne traduit que ses textes par défaut (touche de secours, libellé d'icône) et passe en droite-à-gauche pour l'arabe.

### Exports
Mêmes exports que ci-dessus : `Create`, `Remove`, `Update`, `UpdateCoords`, `ClearAll`. Les éléments d'une ressource arrêtée sont supprimés automatiquement.

### Relancer
`restart pop_v3dui` (les scripts qui l'utilisent recréent leurs prompts quand le joueur se rapproche).
