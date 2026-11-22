# Travaux en cours

Une ligne par script en cours de modification : `pop_xxx : Chef N (tâche)`.
Ajouter sa ligne avant de commencer, la retirer quand c'est fini.
Répartition de l'audit (`docs/audit.md`) : démarrage au GO du client.

- pop.cfg, .github/, CLAUDE.md, docs/coordination-chefs.md : Chef 1 (coordination)
- pop_chat : Chef 3 (position de la saisie, texte coupé)
- Hors travaux : pop_police (mis de côté par le client). pop_police80 supprimé (copie de pop_police, demande du client).
- Plus tard (décision du client) : système bancaire complet (pop_bank + chéquier pop_inventory au même comptoir). Ne pas y toucher pour l'instant.
- Pour le Chef 1 (gabarit, signalé par le Chef 2) : 1) le bridge détecte l'inventaire au démarrage ; dans `[pop]`, un script qui paie via `Bridge.*Money(src, 'cash')` doit déclarer `dependency 'pop_inventory'` (sinon l'argent ESX est débité si pop_inventory démarre après). 2) `templates/pop_base/README.md` (« Contrat de pop_inventory ») cite des exports GetItemCount/AddItem/Search… que pop_inventory n'a pas ; le bridge utilise bien getItemCount/addItem/removeItem/getInventory.
