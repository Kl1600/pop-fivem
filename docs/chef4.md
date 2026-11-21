# Notes Chef 4 — Lot 4 (véhicules, banque et divers)

## Fait
- pop_v3dui (envoi NUI toutes les 30 ms), pop_medexam (affichage limité, job `ambulance` au lieu de `youtool`), pop_hud (caché tant que le perso n'est pas chargé, vie juste pour un ped femme, pma-voice configuré une fois, callback closeChecklist), pop_notify (HTML filtré : span/br/b/strong/i/em), pop_doorlock (pcall, pop_notify), pop_chat (/me limité à 2 s, nom RP), manifests en cerulean + lua54.
- pop_emotes : plus d'objet réseau créé à chaque emote (fuite), .ytyp des props custom chargés, emote partagée relayée par son nom seulement (demande préalable, 10 m), seul le partenaire peut arrêter l'emote, deuxième prop corrigé.
- pop_bennys : prix recalculé côté serveur (items), distance au Benny's vérifiée, `/bennys` réservé aux admins (ACE `pop.admin`), texte de plaque non modifiable (style seulement), `lua54`.


## En cours
- pop_enterprisegarage, pop_vehiclepersistence, pop_kilometrage : duplication, réapparition, contrôles serveur.
- pop_boards, pop_affiche : droits, distance, quotas, DUI détruits à distance.

## En attente du client
- pop_bank : chèque encaissé en cash (coffre) ou sur le compte `bank` ?

## Bugs connus / risques
- pop_medexam : si le job médical s'appelle vraiment `youtool`, le remettre dans config.lua.
- Benny's : la peinture reste gratuite (d'origine). Un menu de triche peut toujours modifier un véhicule hors Benny's.
