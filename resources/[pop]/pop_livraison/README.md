# pop_livraison

Preview de décor pour les livraisons (outil de dev).

## Fonctionnement
- `/previewlivraison` (admins seulement) crée ou supprime la scène, uniquement pour le joueur qui tape la commande (entités locales, non réseau).
- Scène 1 (docks) : Boxville4, Rumpo porte ouverte, trois postiers (carton, chariot, bloc-notes).
- Scène 2 (Quickie Pharm) : deux Sentinel5 aux couleurs et livrée Quickie Pharm, trois postiers (inspection, attente, mallette).
- Tout est supprimé à l'arrêt de la ressource.

## Dépendances
Aucune obligatoire (le bridge détecte ESX pour le groupe admin).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | commande, délai de chargement, véhicules et peds de la scène |
| `locales/fr.lua` | clés communes (la preview n'affiche aucun texte) |
| `client/preview.lua` | création / suppression de la scène (`Livraison.*`) |
| `client/main.lua` | évènement de bascule, nettoyage à l'arrêt |
| `server/main.lua` | commande admin |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Commandes / touches
| Commande | Droits | Rôle |
|---|---|---|
| `/previewlivraison` | `Bridge.IsAdmin` : ACE `pop.admin` ou groupe admin/superadmin/god | affiche / retire la preview |

## Évènements
| Nom | Sens | Rôle |
|---|---|---|
| `pop_livraison:togglePreview` | serveur → client | crée ou supprime la scène |

## Relancer
`restart pop_livraison`
