# Notes du Chef 2

## Lot 2 (audit du 21/11/2026) — terminé (points Haute et Moyenne)
Scripts : pop_inventory, checksystem, pop_charcreator, pop_clothes, pop_loading, pop_idcard, pop_passport.

### Fait
**Tenue en caleçon** (pop_inventory)
- Tenue réappliquée après chaque rechargement du skin (`skinchanger:loadSkin`, `skinchanger:modelLoaded`, `esx:onPlayerSpawn`, `playerSpawned`), sauf pendant la création de perso (`LocalPlayer.state.charcreatorOpen`).
- En ESX, plus de repli sur la `license:` ; inventaire demandé une fois le joueur ESX chargé ; identifiant gardé en cache pour la sauvegarde à la déconnexion.
- `drawable` / `texture` convertis en nombres ; t-shirt corrigé ; les bras choisis ne remplacent plus ceux d'un haut porté.

**pop_inventory**
- `playerReady` ne recharge plus un inventaire déjà en mémoire (duplication).
- Un seul joueur à la fois par coffre (véhicule, coffre statique), refermé si le joueur s'éloigne de plus de 10 m.
- `openStaticChest` : liste blanche `Config.StaticChests` + distance serveur (exceptions gardées : coffres pop_bank, armytanker/brickadeta près du véhicule).
- Brancard : distance + cible morte (santé ≤ 101 ou state bag) ou menottée.
- Sauvegarde de tous les inventaires à l'arrêt de la ressource ; un seul thread de sauvegarde, seulement les inventaires modifiés.
- `startMovingBox` déclaré avant usage ; objet perdu sur case occupée corrigé ; renommage nettoyé (30 caractères, sans HTML).
- Paiement TPE : la demande attend la réponse (E accepter, Retour arrière refuser, 15 s).
- Boutique : distance à `Config.ShopZones`, remboursement si inventaire plein.
- Stockage perso portable (30 cases) désactivé ; requête `job2` et ajout auto des grades 0/4 retirés.
- Admins de l'inventaire : ACE `pop.admin` / `pop_inventory.admin` ou admin `pop_admin` (plus de licences dans le dépôt).
- Appel `pop_clothes:openAdmin` protégé ; `/testshop` désactivé ; plus de `print` dans `getIdentifier`.

**pop_charcreator / pop_loading / papiers**
- Notifications via `pop_notify` (`notification:client:ShowNotify`).
- Créateur rouvert tant que le perso n'a pas de prénom en base.
- Instance du créateur réservée à une vraie création (ou réouverture admin).
- Commandes caméra qui ne s'arrêtent plus après être passé par les vêtements.
- pop_loading : suite déclenchée en fin de transition, ne touche plus au créateur ouvert.
- `imports.lua` chargé une seule fois.

**pop_clothes**
- Achat : distance au magasin, valeurs typées, tatouages de `tattoos.json` seulement, Décals à 25 $.
- Taxe avec repli SQL sans `esx_addonaccount`.
- Barbier : coupe payée enregistrée dans skinchanger (puis tenue réappliquée).
- Vignettes `uz_AutoShot` désactivées (`USE_AUTOSHOT` dans index.html) ; export `openAdmin` retiré.

**checksystem** : réessais limités (5) si la base est en erreur.

### Points Basse (22/11/2026) — faits
- **pop_inventory** : paiement en pesos retiré (serveur, client, config, interface boutique ; l'objet « pesos » reste défini pour que les anciens restent visibles et jetables) ; PNJ iFruit supprimé à l'arrêt de la ressource ; recette « safe » = 8 hotdogs sur une ligne, quantités additionnées par objet côté serveur ; un seul `playerDropped` (sv_exports.lua) ; exports `GiveItem` et `getItemCount` en double retirés (ceux réellement utilisés sont gardés).
- **pop_clothes** : Binco Vespucci (Y -10517 → -1073) et Discount Store Route 68 (Z 189 → 18) corrigés.
- **pop_idcard / pop_passport** : boucle Échap active seulement carte ouverte (fermeture Échap, clic droit ou Retour arrière) ; photo du titulaire (sa propre carte, ou le titulaire s'il est à moins de 15 m, sinon fond gris) ; `giveidcard` / `givepassport` ne plantent plus depuis la console.
- **pop_charcreator** : sauvegarde refusée si le ped n'est pas `mp_m_freemode_01` / `mp_f_freemode_01` ou si une valeur du skin ou de la tenue sort des limites (nombres de -1 à 1000, taille 80 à 120) ; le joueur revient alors dans le créateur. Onglet « PEDS » retiré.

### À vérifier en jeu
- Les deux magasins de vêtements corrigés (Binco Vespucci, Discount Store Route 68).
- Carte d'identité / passeport : photo du titulaire, fermeture par Échap.
- Création de perso complète (la nouvelle vérification du skin ne doit rien refuser à tort).
- Tenue au spawn, après le coiffeur et après un restart de pop_inventory.
- T-shirt homme et femme (haut 0 par défaut).
- Coffre de véhicule à deux joueurs (le second doit être refusé).
- Licences `70523d55…` et `fc88a542…` retirées de la liste admin de l'inventaire : à ajouter dans pop_admin si besoin.
