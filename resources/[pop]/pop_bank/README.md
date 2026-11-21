# pop_bank

Agences bancaires : compte personnel, compte d'entreprise (patron) et dépôt de chèques.

## Fonctionnement
- Deux agences (`Config.Locations`) avec une zone ox_target : **Compte personnel**, **Compte de l'entreprise** (patron uniquement), **Déposer un chèque**.
- Un compte est un coffre pop_inventory : `bank_personal_<identifier>` ou `bank_company_<job>`. L'id est toujours calculé par le serveur.
- Chèque encaissé : le bénéficiaire est crédité sur son compte ESX `bank`. Si le chèque est à l'ordre d'une entreprise (label exact SecuroServ), seul son patron peut l'encaisser et l'argent va dans le coffre de l'entreprise.
- L'émetteur est débité sur son compte `bank` (même hors ligne, solde vérifié) ou sur le coffre de son entreprise. Tout est annulé si une étape échoue.

## Dépendances
es_extended, oxmysql, ox_lib (menu de dépôt), ox_target, pop_inventory, checksystem (table `banking_checks`).

## Fichiers
| Fichier | Rôle |
|---|---|
| `config.lua` | agences, distance max, taille des comptes, durée des notifications |
| `locales/fr.lua` | tous les textes |
| `client/main.lua` | zones d'agence, menu de dépôt |
| `server/common.lua` | fonctions partagées (`Bank.*`) |
| `server/accounts.lua` | ouverture des comptes, liste des chèques |
| `server/cheques.lua` | dépôt d'un chèque |
| `bridge/`, `shared/` | fichiers communs POP (ne pas modifier ici : `templates/pop_base`) |

## Évènements et callbacks
| Nom | Sens | Rôle |
|---|---|---|
| `pop_bank:server:openAccount` (scope `personal`/`company`) | client → serveur | demande d'ouverture d'un compte |
| `pop_bank:client:openAccount` | serveur → client | ouvre le coffre validé |
| `pop_bank:getMyChecks` (Callback) | client → serveur | chèques portés |
| `pop_bank:depositCheque` (checkId) | client → serveur | dépôt d'un chèque |

## Relancer
`restart pop_bank`
