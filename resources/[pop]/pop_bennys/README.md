# pop_bennys

Menu de personnalisation Benny's Motor Works : peinture, jantes, carrosserie, performances, néons, vitres, style de plaque, livrées et extras, payés en objets.

## Fonctionnement
- Point Benny's (`Config.BennysCoords`) avec un prompt 3D (pop_v3dui) : touche **E** pour ouvrir le menu sur le véhicule occupé ou le plus proche (5 m).
- Chaque option a sa caméra (`Config.Cameras`) et un aperçu en direct. Fermer sans valider remet le véhicule comme avant.
- **Appliquer** : le client calcule les catégories modifiées en comparant au véhicule d'origine ; le serveur recalcule seul le coût en objets (`Config.ItemCosts`), vérifie la distance au Benny's (`Config.PayDistance`) et que tout est disponible, puis retire les objets.
- Le texte de la plaque n'est pas modifiable (seul le style l'est). La peinture est gratuite.

## Dépendances
pop_v3dui (prompt). pop_inventory pour les objets (icônes, quantités, paiement via le bridge).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | coûts en objets, point Benny's, caméras, commande |
| `locales/fr.lua` | tous les textes |
| `client/vehicle.lua` | état d'origine, restauration, données NUI, catégories modifiées |
| `client/camera.lua` | caméra par catégorie |
| `client/menu.lua` | ouverture, fermeture, application et résultat du paiement |
| `client/preview.lua` | aperçus (callbacks NUI `preview_*`) |
| `client/zone.lua` | point Benny's, prompt et touches |
| `server/payment.lua` | calcul et retrait des objets |
| `server/admin.lua` | `/bennys` (admins) |
| `html/` | interface du menu |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes et touches
| Commande / touche | Rôle |
|---|---|
| `E` au point Benny's | ouvre le menu |
| `Retour arrière` / `Échap` | ferme sans appliquer |
| `/bennys` (`Config.Command`) | ouverture à distance, admins seulement (ACE `pop.admin` ou groupe admin) |

## Évènements et exports
| Nom | Sens | Rôle |
|---|---|---|
| `pop_bennys:payItems` (cats) | client → serveur | paiement des catégories modifiées |
| `pop_bennys:payResult` (ok) | serveur → client | applique ou annule |
| `pop_bennys:adminOpen` | serveur → client | ouverture par `/bennys` |
| `exports.pop_bennys:open()` | client | ouvre le menu |
| `hud:toggleui` (bool) | évènement local émis | masque / réaffiche le HUD pendant le menu |

## Relancer
`restart pop_bennys`
