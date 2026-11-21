# Notes Chef 4 — Lot 4 (véhicules, banque et divers)

## Fait
- pop_vehiclepersistence : données client comparées à l'entité serveur (netId, modèle, plaque, position serveur), export `Forget(plate)` / `IsTracked(plate)`, connexion ≠ interaction, apparition à proximité (250 m), plus de doublon à la déconnexion, vehicleSpawned/despawnFailed contrôlés, décor fFuel déclaré.
- pop_enterprisegarage : rangement contrôlé (netId, plaque, modèle, 8 m, état out, une seule fois), Forget + clés reprises, véhicule détruit/disparu récupérable, plaques uniques.
- pop_kilometrage : valeur comparée à la base (hausse, 10 km max par envoi), requestMileage limité à 1/s.
- pop_boards : propriétaire enregistré, 5 tableaux max par joueur, distance 30 m, déplacement/suppression réservés au propriétaire ou aux admins, images limitées (dessin ou fichier du script, 10 Mo), délais anti-spam, DUI détruit au-delà de 60 m. pop_affiche : liens http(s) seulement, distance, délai 2 s, champs filtrés, DUI libéré à distance.
- pop_v3dui (envoi NUI toutes les 30 ms), pop_medexam (affichage limité, job `ambulance` au lieu de `youtool`), pop_hud (caché tant que le perso n'est pas chargé, vie juste pour un ped femme, pma-voice configuré une fois, callback closeChecklist), pop_notify (HTML filtré : span/br/b/strong/i/em), pop_doorlock (pcall, pop_notify), pop_chat (/me limité à 2 s, nom RP), manifests en cerulean + lua54.
- pop_emotes : plus d'objet réseau créé à chaque emote (fuite), .ytyp des props custom chargés, emote partagée relayée par son nom seulement (demande préalable, 10 m), seul le partenaire peut arrêter l'emote, deuxième prop corrigé.
- pop_bennys : prix recalculé côté serveur (items), distance au Benny's vérifiée, `/bennys` réservé aux admins (ACE `pop.admin`), texte de plaque non modifiable (style seulement), `lua54`.


## En attente du client
- pop_bank : chèque encaissé en cash (coffre) ou sur le compte `bank` ?

## Bugs connus / risques
- Persistance : véhicules non réseau (sans netId) plus sauvegardés. Comparaison du modèle modulo 2^32 à confirmer en jeu.
- pop_boards : les anciens tableaux n'ont pas de propriétaire (seuls les admins peuvent les déplacer). Peindre reste ouvert à tous (d'origine).
- pop_medexam : si le job médical s'appelle vraiment `youtool`, le remettre dans config.lua.
- Benny's : la peinture reste gratuite (d'origine). Un menu de triche peut toujours modifier un véhicule hors Benny's.
