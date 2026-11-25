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

## Gabarit POP (22/11/2026) — terminé
Modèle suivi : `templates/pop_base` + `docs/gabarit-pop.md` (bridge en `bridge/client.lua` + `bridge/server.lua`, `shared/locale.lua`, `shared/callback.lua`, copies exactes).
- Évènements renommés en `pop_` (vanguard_charcreator, vg_paint, tab_sabot, tab_douilles, tab_chargeurs, tab_uvlight, tab_interacts). `vg_engine:*` gardé (partagé avec ox_target). Objets et tables en base inchangés.
- **pop_charcreator** : client/ (camera, creator, appearance), server/ (common, save, instance), locales, README. luacheck 0/0.
- **pop_loading** : client/main.lua, musique 320 → 128 kbps, images WebP (16 Mo → 8 Mo). luacheck 0/0.
- **pop_idcard** : client/ (photo, main), server/ (common, main), images WebP (3,5 Mo → 0,6 Mo). luacheck 0/0.
- **pop_passport** : client/ (photo, main), server/ (common, main, commands), images WebP (6,9 Mo → 1,7 Mo). luacheck 0/0.
- **pop_clothes** : NUI dans html/, client/ (common, tattoos, camera, barber, shop, nui), server/ (common, tattoos, shop) ; paiement via Bridge (cash puis banque) ; `dependency 'pop_inventory'` (le bridge détecte l'inventaire au démarrage). luacheck 0/0.
- **pop_inventory** : config/ (items_1..5, clothing, shops, recipes, modules…), client/ et server/ découpés (< 600 lignes, même ordre de chargement), Bridge pour notifications / job, Callback pour chargeurs et douilles, textes en L(), prints derrière Config.Debug, carton en veille (Wait 500), images WebP (21 → 12 Mo). `Config.Inventory` (table) renommé `Config.InventorySettings`, `Config.Debug` (table) → `Config.DebugOptions`. luacheck 0/0 (78 fichiers).

### Reste / à savoir
- 33 PNG gardés dans pop_inventory/html/img : pop_bennys et pop_management pointent encore vers `nui://pop_inventory/html/img/*.png` (environ 4 Mo à gagner quand ils passeront en .webp).
- Icônes absentes depuis l'origine : bequille, civiere, defib, fauteuil, lucas, sabot (clamp utilisé), `img/vector*.svg` du CSS.
- Double `RegisterNUICallback('close')` (bridge + script) dans pop_inventory, pop_clothes, pop_idcard, pop_passport : sans effet attendu, à confirmer en jeu.

### À vérifier en jeu (gabarit)
- Inventaire : TAB court/maintenu (roue), radio puis I/TAB, carton, coffre de véhicule, capot, fouille, TPE, menottes, brancard, boutique, établi, casiers, chargeurs, douilles.
- Vêtements : achat cash puis carte, barbier, tatoueur, fermeture sans achat.
- Créateur, carte d'identité, passeport, écran de connexion (musique, touche M).

## Chantier 5 langues + tous serveurs (25/11/2026)
Méthode commune à mes scripts : `html/i18n.js` (petit fichier identique partout : demande `pop:ready` au bridge, remplit `data-i18n`, met `dir="rtl"` pour l'arabe, fonction `T()` pour le JS) ; `locales/fr|en|es|de|ar.lua` ; dossier `install/` (items_ox.lua, items_qb.lua, items_esx.sql, items_pop.lua, sql.sql, images/) ; README en + fr ; `version '1.0.0'` en fin de manifeste. Captures fr/ar faites avec Chrome sans interface (mock de `pop:ready`).
- **pop_idcard** : plus aucun appel ESX / pop_inventory obligatoire. Nom par `Bridge.GetName`, sexe par le modèle du ped, titulaire retrouvé par `Bridge.GetIdentifier`, commande `/giveidcard` en `RegisterCommand` + `Bridge.IsAdmin` (console OK), objets utilisables enregistrés par `Bridge.RegisterUsableItem` hors pop_inventory (sans métadonnées : carte du joueur lui-même). pop_inventory facultatif (portefeuille). Plus de dépendance oxmysql. Textes de la carte MX et consigne de fermeture en `data-i18n`. La carte US garde ses libellés imprimés dans l'image (fr/en).

