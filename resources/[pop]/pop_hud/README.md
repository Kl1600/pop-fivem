# pop_hud

HUD du joueur : mini-carte ronde, vie, faim, soif, mode de voix et radio, heure, et bandeau des signalements admin.

## Fonctionnement
- Le HUD et la mini-carte restent cachés tant que le personnage n'est pas chargé, pendant le créateur de personnage (`LocalPlayer.state.charcreatorOpen`), en menu pause et sur la grande carte.
- Valeurs lues toutes les `Config.StatusRefresh` ms ; l'interface n'est prévenue que si une valeur change.
- Faim / soif : `esx_status` (automatique), ou évènements / exports ci-dessous.
- L'interface par défaut de pma-voice est masquée.

## Dépendances
Aucune obligatoire (framework détecté par le bridge). Optionnelles : `esx_status`, `pma-voice`.

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | réglages communs POP + fréquences, zoom et position de la mini-carte |
| `locales/fr.lua` | textes communs (le HUD n'affiche pas de texte propre) |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier) |
| `client/status.lua` | vie, faim, soif, voix, heure, bandeau admin |
| `client/minimap.lua` | mini-carte ronde, affichage selon l'état du joueur |
| `stream/circlemap.ytd` | masque rond de la mini-carte |
| `html/` | interface (inchangée) |

## Évènements et exports (client)
| Nom | Type | Rôle |
|---|---|---|
| `hud:toggleui` (show) | évènement | `false` cache le HUD (ex. menu Benny's) |
| `hud:setFood` / `hud:setWater` (0-100) | évènement | faim / soif |
| `setFood(v)` / `setWater(v)` | export | idem |
| `updateAdminOverlay(show, activeReports)` | export | bandeau des signalements (pop_admin) |

## Relancer
`restart pop_hud`
