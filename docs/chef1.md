# Chef 1 — notes

## Fait (lot 1, 21/11)
- pop_management : bug Échap (laptopOpen posé seulement si ouverture réussie, remis à false partout), argent via l'objet cash, salaires hors ligne dans users.accounts, plaque/modèle du Port vérifiés côté serveur, achats société réservés au patron (3 s entre achats), clé key_d8 via pop_inventory, laptops en objets locaux, mt_printers absent signalé, rafraîchissements cr-laptop:forceUpdate.
- pop_admin : hiérarchie des groupes, Échap débloqué si la NUI cache le menu (callback menuHidden), spec/spectate sans envoi par frame, plus de requête job2, quantités 1-1000, diagnostic sauvegarde ESX en lecture seule.
- pop_interim : setJob2 → setJob, transitions sûres, /devpreview réservé aux admins.
- ox_target : notifications mécano → pop_notify, checklist sur pop_hud:client:showDamageChecklist, plus de math.randomseed global.
- pop_duiengine : TXD réutilisés, AttachPanelToBone corrigé. clm_ProgressBar : example.lua désactivé.

## Reste / à surveiller
- Événements vg_engine:* gardés (émis et écoutés par pop_inventory sous ce nom).
- Virement à un employé hors ligne qui se connecte au même moment : ESX peut écraser le crédit.
- Les employés non patrons ne peuvent plus acheter avec l'argent de la société (règle plus stricte).
