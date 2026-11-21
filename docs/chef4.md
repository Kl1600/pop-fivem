# Notes Chef 4 — Lot 4 (véhicules, banque et divers)

## Fait
- pop_bank (choix du client) : un chèque encaissé arrive sur le compte ESX `bank` du bénéficiaire. Le chèque perso débite le compte `bank` de l'émetteur (solde vérifié côté serveur, en ligne ou hors ligne via la base). Chèque d'entreprise ou à l'ordre d'une entreprise : coffre entreprise, comme avant. Remboursement de l'émetteur si le crédit échoue.
- pop_vehiclepersistence : données client comparées à l'entité serveur (netId, modèle, plaque, position serveur), export `Forget(plate)` / `IsTracked(plate)`, connexion ≠ interaction, apparition à proximité (250 m), plus de doublon à la déconnexion, vehicleSpawned/despawnFailed contrôlés, décor fFuel déclaré.
- pop_enterprisegarage : rangement contrôlé (netId, plaque, modèle, 8 m, état out, une seule fois), Forget + clés reprises, véhicule détruit/disparu récupérable, plaques uniques.
- pop_kilometrage : valeur comparée à la base (hausse, 10 km max par envoi), requestMileage limité à 1/s.
- pop_boards : propriétaire enregistré, 5 tableaux max par joueur, distance 30 m, déplacement/suppression réservés au propriétaire ou aux admins, images limitées (dessin ou fichier du script, 10 Mo), délais anti-spam, DUI détruit au-delà de 60 m. pop_affiche : liens http(s) seulement, distance, délai 2 s, champs filtrés, DUI libéré à distance.
- pop_v3dui (envoi NUI toutes les 30 ms), pop_medexam (affichage limité, job `ambulance` au lieu de `youtool`), pop_hud (caché tant que le perso n'est pas chargé, vie juste pour un ped femme, pma-voice configuré une fois, callback closeChecklist), pop_notify (HTML filtré : span/br/b/strong/i/em), pop_doorlock (pcall, pop_notify), pop_chat (/me limité à 2 s, nom RP), manifests en cerulean + lua54.
- pop_emotes : plus d'objet réseau créé à chaque emote (fuite), .ytyp des props custom chargés, emote partagée relayée par son nom seulement (demande préalable, 10 m), seul le partenaire peut arrêter l'emote, deuxième prop corrigé.
- pop_bennys : prix recalculé côté serveur (items), distance au Benny's vérifiée, `/bennys` réservé aux admins (ACE `pop.admin`), texte de plaque non modifiable (style seulement), `lua54`.


## Gabarit POP (restructuration)
- pop_hud : gabarit complet (client/status.lua, client/minimap.lua), chargement du perso via Bridge.OnPlayerLoaded, exports inchangés.
- pop_chat : gabarit complet (bridge, config, locales, client/server, README), nom RP via Bridge.GetName.
- pop_speedometer : gabarit (config.lua, client/main.lua, README), sans bridge comme pop_notify.
- pop_v3dui : gabarit (config.lua, client/main.lua, README), exports Create/Remove/Update/UpdateCoords/ClearAll inchangés.

## Bugs connus / risques
- Persistance : véhicules non réseau (sans netId) plus sauvegardés. Comparaison du modèle modulo 2^32 à confirmer en jeu.
- pop_boards : les anciens tableaux n'ont pas de propriétaire (seuls les admins peuvent les déplacer). Peindre reste ouvert à tous (d'origine).
- pop_medexam : si le job médical s'appelle vraiment `youtool`, le remettre dans config.lua.
- Benny's : la peinture reste gratuite (d'origine). Un menu de triche peut toujours modifier un véhicule hors Benny's.

## pop_emotes — poids (décision du client en attente pour le reste)
Total 121 Mo (stream : props 63 Mo, emotes custom 58 Mo).

Par pack :
| Pack | Poids |
|---|---|
| Custom Emotes / Vision (danses de boîte de nuit, breakdance) | 39,7 Mo |
| Props / Crowded1337 (sac à main) | 23,2 Mo |
| Props / PataMods (nourriture de Noël, gâteaux) | 13,4 Mo |
| Custom Emotes / BoringNeptune (danses) | 10,8 Mo |
| Props / KayKayMods (peluches) | 7,3 Mo |
| Props / Brummiee | 6,1 Mo |
| Custom Emotes / Alpha | 5,2 Mo |
| Props / TayMcKenzieNZ | 4,0 Mo |
| Tous les autres packs | < 2,5 Mo chacun |

Fichiers les plus lourds :
| Fichier | Poids | Utilisé par |
|---|---|---|
| Vision/…crowddance_facedj@.ycd | 12,9 Mo | 6 emotes |
| BoringNeptune/dancing_wave_part_one@anim.ycd | 8,4 Mo | 15 emotes |
| Crowded1337/lambert1_normal.dds | 8,0 Mo | aucune (fichier .dds : non chargé par FiveM, poids mort) |
| Crowded1337/lambert1_albedo.dds | 8,0 Mo | aucune (idem) |
| Crowded1337/prop_amb_handbag_01.ydr | 7,2 Mo | 3 emotes |
| Vision/…crowddance_single_props@.ycd | 6,3 Mo | 5 emotes |
| Vision/…crowddance_groups@groupd@.ycd | 4,0 Mo | 1 emote |
| PataMods/pata_christmasfood6.ydr | 3,1 Mo | 1 emote |
| KayKayMods/gremlin_plush.ydr | 3,1 Mo | 1 emote |
| Vision/divined@breakdances@new.ycd | 2,9 Mo | 15 emotes |
| Vision/divined@brdancesv2@new.ycd | 2,3 Mo | 12 emotes |
| Vision/divined@dances@new.ycd | 2,0 Mo | 13 emotes |
| PataMods/pata_cake.ydr | 2,0 Mo | 2 emotes |

**Fait (accord du client) : les deux .dds (16 Mo) sont supprimés, ainsi que 3 emotes lourdes (≈10 Mo) : `danceclubj` (Dance Club 10, groupd), `xmascc` (cupcake, pata_christmasfood6), `teddy2` (peluche Gremlin).** Total gagné ≈ 26 Mo.
