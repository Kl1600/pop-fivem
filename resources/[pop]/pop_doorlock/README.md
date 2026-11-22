# pop_doorlock

Portes verrouillables (système de portes natif de GTA) et **Doorbuilder** pour les admins : créer des groupes de portes et distribuer une clé (objet `cle` de pop_inventory).

Base d'origine : XD_Doorlock (LielXD), édition Doorbuilder.

## Fonctionnement
- Les portes viennent de `Config.Doors` (statiques) et de `doors.json` (créées au Doorbuilder). Le serveur garde l'état et le synchronise.
- Ciblage ox_target sur une porte : **Verrouiller** (rouge) ou **Déverrouiller** (vert). Le serveur vérifie la distance et l'accès, puis confirme (animation de télécommande + notification).
- Accès, par priorité : clé Doorbuilder (objet `cle` avec `meta.doorgroup`) > objet simple (legacy) > métier (`Jobs`).
- Doorbuilder : ouvert depuis pop_admin (onglet « Portes »). Sélection des portes visées (E), validation (Entrée), annulation (X), puis nom, distance et verrouillage par défaut. Gestion des groupes : renommer, retirer une porte, attribuer/régénérer/recevoir la clé, supprimer.
- Les groupes de `config.lua` ne sont jamais modifiés : les changements vont dans `overrides.json`.

## Dépendances
es_extended, ox_target (options colorées), pop_inventory (clés et objets), pop_admin (facultatif : même liste d'admins), pop_notify (facultatif).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | objet clé, droits admin, touches du Doorbuilder, portes statiques |
| `locales/fr.lua` | tous les textes |
| `client/doors.lua` | état des portes (`Doorlock.*`), synchronisation, options ox_target |
| `client/builder.lua` | Doorbuilder : sélection par visée et hub NUI |
| `server/common.lua` | état, persistance, droits admin, contrôle d'accès (`Doorlock.*`) |
| `server/doors.lua` | chargement, liste des portes, changement d'état |
| `server/builder.lua` | actions du Doorbuilder |
| `doors.json`, `overrides.json` | données enregistrées par le Doorbuilder (créées automatiquement) |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Évènements et callbacks
| Nom | Sens | Rôle |
|---|---|---|
| `pop_doorlock:getDoors` (Callback) | client → serveur | liste des portes |
| `pop_doorlock:changeState` | client → serveur | verrouiller / déverrouiller |
| `pop_doorlock:builder:request` | client → serveur | ouverture du Doorbuilder (utilisé par pop_admin) |
| `pop_doorlock:getGroups` / `getGroupDetail` (Callback) | client → serveur | hub du Doorbuilder (admins) |
| `pop_doorlock:builder:save` / `updateGroup` / `removeDoor` / `assignkey` / `regenkey` / `givekey` / `delete` | client → serveur | actions du Doorbuilder (admins) |
| `pop_doorlock:addDoors` / `removeDoors` / `changeDoorState` | serveur → client | synchronisation |

## Relancer
`restart pop_doorlock`
