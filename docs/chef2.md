# Notes du Chef 2

## Lot 2 (audit du 21/11/2026)
Scripts : pop_inventory, checksystem, pop_charcreator, pop_clothes, pop_loading, pop_idcard, pop_passport.

### Fait
- **Tenue en caleçon** (pop_inventory) :
  - la tenue est réappliquée après chaque rechargement du skin (`skinchanger:loadSkin`, `skinchanger:modelLoaded`, `esx:onPlayerSpawn`, `playerSpawned`), sauf pendant la création de perso ;
  - en ESX, plus de repli sur la `license:` : l'inventaire n'est demandé qu'une fois le joueur ESX chargé (sinon il était vide) ; identifiant gardé en cache pour la sauvegarde à la déconnexion ;
  - `drawable` / `texture` convertis en nombres ;
  - t-shirt corrigé (composant 38 inexistant, t-shirt femme qui mettait torse nu) ; les bras choisis ne remplacent plus ceux d'un haut porté.
- `playerReady` ne recharge plus un inventaire déjà en mémoire (duplication).
- Sauvegarde de tous les inventaires à l'arrêt de la ressource.
- Plus de `print` à chaque `getIdentifier`.

### Reste
- Points « Haute » et « Moyenne » restants du Lot 2.

### À vérifier en jeu
- T-shirt (homme et femme) : numéros de vêtements choisis par défaut (haut 0).
