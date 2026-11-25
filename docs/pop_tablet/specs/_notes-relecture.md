## 01-base (64 fiches, 9 ajouts)
- Code facultatif, haché ; blocage par numéro de série.
- F9 tablette, Y fenêtre simple ; batterie 120 min, recharge véhicule 30 min / chargeur 10 s.
- Point de vente 24/7 Innocence Blvd : reset 250$, tablette 1500$, chargeur 150$.
- Mode posée : lecture seule, vol possible.
- À confirmer : couleur d'accent #4FA3FF provisoire ; QB/Qbox en bêta ; apps tierces isolées.
## 02-entreprises (61 fiches, 12 ajouts)
- Part employé 10 % (max 50 %), figée ; liquide si employé en service à 3 m ; payée = non annulable.
- Impayés traités à la consultation (pas de minuteur), défaut : aucune sanction, 72 h.
- Annonce ville : 30 min/entreprise, 2 min global, gratuite. Demandes : 1 / 5 min / entreprise, 3 ouvertes max.
- CORRECTION à faire en relecture : pop_bank n'expose AUCUN export (vérifié dans le repo : agences + chèques seulement). Les exports supposés (GetSocietyBalance…) n'existent pas → la banque = comptes société ESX (esx_addonaccount / esx_society) ; pop_bank : rien à brancher, ou un adaptateur à écrire plus tard.
- Grades : créer/supprimer renumérote les grades ESX (risque, à revoir en relecture).
## 04-ems-mecano-justice-gang (47 fiches, 3 ajouts)
- Justice : avocat = job avocat ; procureur = justice grades 0-1 ; juge = justice grade 2+.
- Gang géré par la tablette, code perso par membre ; messages vraiment supprimés (1/6/24/72 h, 24 h défaut).
- Verdict définitif ; facture soins inconscient annulée après 60 min.
- Stock mécano décompté au paiement, négatif autorisé.
- ATTENTION : collisions de fichiers intermédiaires dans le scratchpad entre agents → vérifier l'intégrité de chaque livrable en relecture.
## 03-police (44 fiches, 4 ajouts : matricule, renfort, détresse, permis)
- Code pénal = barème ; agent baisse, jamais monte ; amende max 50 000 $, recrue 2 500 $, peine max 120 mois.
- Mandats validés par Chef ou juge, 7 jours ; avis de recherche 3 jours.
- Caméra piéton 300 m (max 400), sans son. Unités en mémoire seulement.
- Saisie de tablette nécessite ox/qs-inventory.
- INCOHÉRENCE à corriger : nom du signal prison = `pop_tablet:peinePrononcee` (police) vs `pop_tablet:sentencePronounced` (justice). Choisir un seul nom (anglais conseillé pour l'API publique).
## 05-sites-admin-apps-perso (57 fiches, 8 ajouts)
- Tablette peut créer un métier ESX ; Gestion obligatoire ; 1 app métier / entreprise.
- Sites : adresse .rp changeable 1x/7 j, 5 pages, 30 blocs, 20 versions ; images i.imgur.com + r2.fivemanage.com.
- Export/import JSON, jamais d'employés/argent ; import en brouillon.
- Numéro PT-XXXXXX. Apps perso : serveur sandboxé, pas de Lua client V1, guide = CLAUDE.md.
- INCOHÉRENCE : prix point de vente 500/250/100 $ (05) vs tablette 1500 $ / reset 250 $ / chargeur 150 $ (01). Unifier.
- INCOHÉRENCE possible : commande admin /tabletadmin vs ACE pop.tablet.admin (vérifier cohérence de nommage).
- Entreprise justice/gang par défaut ? 05 dit 5 par défaut sans justice : OK avec le contexte, mais à vérifier que les apps justice/gang sont activables.
## 06-outils-navigateur-gestion-pro (77 fiches, 14 ajouts)
- Notes/photos/favoris/historique/points = au PERSONNAGE (conflit possible avec 01 : données perso liées à l'objet / numéro de série).
- Photos via screencapture stockées sur disque serveur, envoyées par events (pas d'hébergeur) ; preuve = jamais supprimée.
- INCOHÉRENCE : adresses `nom.ls` (06) vs `.rp` (05, cadrage). Choisir.
- Tableur : formules côté client, 200x26, 20 feuilles, pas d'insertion de lignes V1 (contraire à « tout en V1 » ? à juger).
- Stock : déduction jusqu'à 0 (06) vs négatif autorisé (04 mécano). Unifier.
- Planning heure du jeu : « une seule minuterie serveur » → vérifier compatibilité avec la règle zéro boucle.
- Droits ajoutés : planning.voir, annuaire.fermer (+ 6 de 02).
- Calage carte à vérifier.

## Statut (24/11/2026)
Tous les points ci-dessus sont tranchés et corrigés dans les fichiers ; voir `00-sommaire.md` (référentiel unique, décisions consolidées, points à confirmer par le client).
