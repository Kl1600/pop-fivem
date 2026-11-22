# Ce qui manque pour finir la base POP (22/11/2026)

Analyse de tout ce qui tourne sur le serveur (ressources ESX + 36 scripts pop_*). Classé par priorité.

## 1. Bloquant : la ville ne tourne pas sans ça
| Manque | Constat | Proposition |
|---|---|---|
| ~~**Mort et réapparition**~~ ✅ pop_death (22/11) | Aucun script ne gère la mort. pop_loading coupe la réapparition automatique : un joueur mort reste au sol jusqu'à ce qu'on utilise un défibrillateur ou que l'admin le réanime. | `pop_death` : écran de mort, délai, appel EMS, réapparition à l'hôpital (perte d'objets réglable). |
| **Job EMS** | Les objets EMS existent (défibrillateur, civière, brancard, kit de soins) et pop_medexam fait l'examen, mais il n'y a pas de métier ambulancier (service, tenue, véhicule, réanimation). | `pop_ems`, branché sur pop_death et pop_medexam. |
| **Police** | Mise de côté. Sans elle, le contenu illégal (deal, weed, braquage de voitures, territoires) n'a aucun adversaire. | Reprendre pop_police au gabarit, avec menottes et fouille (déjà dans pop_inventory). |
| ~~**Carburant**~~ ✅ pop_fuel (22/11) | Le niveau d'essence est sauvegardé, mais rien ne le fait baisser et il n'y a pas de station. | `pop_fuel` : consommation et stations, avec paiement en espèces ou par carte. |

## 2. Important pour une ville complète
| Manque | Constat |
|---|---|
| **Banque à finir** | Reportée par le client : distributeurs (ATM), virements, comptes. |
| **Téléphone** | lb-phone retiré. **pop_tablet** (POP Tab, ajouté par Silvun) a une appli Téléphone : à décider si elle sert de téléphone ou s'il faut un `pop_phone`. |
| **Métiers légaux** | Seuls existent l'intérim (3 petits jobs), GoPostal et les entreprises de pop_management. Manquent : mécano/dépanneur (réparation, fourrière), taxi. |
| **Fourrière / garage** | Les véhicules restent garés dans le monde (pop_vehiclepersistence). Rien n'est prévu pour un véhicule perdu, détruit ou mal garé. |
| **Permis et prison** | Pas de permis de conduire ni d'auto-école. Pas de prison (à faire avec la police). |
| **Logs Discord** | Aucun log des actions admin, de l'argent ou des objets : impossible de repérer un abus ou une duplication. |
| **Météo et heure** | Réglables seulement à la main par l'admin, pas de cycle automatique. |

## 3. Confort, à faire ensuite
- Logements (achat ou location, coffre, tenue).
- Braquages de supérettes et de banque (ShopRobberies retiré car infecté).
- Liste des joueurs avec leur ID (scoreboard).
- Multi-personnages (facultatif).

## 4. Technique à terminer sur la base actuelle
- **Lot 1 au gabarit** : pop_admin, pop_management, pop_interim, pop_duiengine, pop_computer (Chef 1).
- **Test complet en jeu** après un redémarrage du serveur (la réorganisation n'a pas encore été testée sur la nouvelle version).
- **Langues et multi-framework** : prévus « plus tard » ; le bridge est prêt, il reste les fichiers de langue.
- **pop_tablet** : vérifier avec Silvun qu'il suit les règles du dépôt (KL, pas de rose, gabarit).
- Emotes : objets déclarés en double (sans effet en jeu).

## Ordre conseillé
1. pop_death + pop_ems
2. pop_fuel
3. Banque (ATM, virements)
4. Police + prison
5. Mécano / fourrière, puis taxi
6. Logs Discord
7. Logements, braquages, le reste
