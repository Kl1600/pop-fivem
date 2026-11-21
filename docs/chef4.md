# Notes Chef 4 — Lot 4 (véhicules, banque et divers)

## Fait
- pop_emotes : plus d'objet réseau créé à chaque emote (fuite), .ytyp des props custom chargés, emote partagée relayée par son nom seulement (demande préalable, 10 m), seul le partenaire peut arrêter l'emote, deuxième prop corrigé.
- pop_bennys : prix recalculé côté serveur (items), distance au Benny's vérifiée, `/bennys` réservé aux admins (ACE `pop.admin`), texte de plaque non modifiable (style seulement), `lua54`.


## En cours
- pop_enterprisegarage, pop_vehiclepersistence, pop_kilometrage : duplication, réapparition, contrôles serveur.
- pop_boards, pop_affiche : droits, distance, quotas, DUI détruits à distance.
- pop_v3dui, pop_medexam, pop_hud, pop_notify, pop_doorlock, pop_chat, pop_speedometer : points Moyenne/Basse.

## En attente du client
- pop_bank : chèque encaissé en cash (coffre) ou sur le compte `bank` ?

## Bugs connus / risques
- Benny's : la peinture reste gratuite (d'origine). Un menu de triche peut toujours modifier un véhicule hors Benny's.
