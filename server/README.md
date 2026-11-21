# Serveur de test

## Installation recommandée
Utiliser **txAdmin** avec une recette officielle (QBCore, ESX Legacy ou Qbox) et la base MariaDB du panel :
la recette installe le framework, oxmysql, ox_lib, ox_target, ox_inventory et pma-voice, et crée la base.
Ensuite, comparer le `server.cfg` généré avec `server.cfg.example` et vérifier :
- `ensure [pop]` est la **dernière** ligne `ensure` (le framework et l'inventaire doivent démarrer avant) ;
- `add_ace group.admin pop.admin allow` est présent ;
- aucune clé de licence ni mot de passe n'est copié dans ce dépôt.

## Tester un autre framework
Les scripts POP détectent tout seuls le framework au démarrage. Pour en tester un autre :
1. Installer ses ressources (ou une seconde instance txAdmin avec une autre recette, plus simple).
2. Dans `server.cfg`, ne garder qu'**un seul** framework actif (`es_extended`, `qb-core` ou `qbx_core`) ;
   tous commentés = mode standalone.
3. Redémarrer le serveur (pas seulement `restart pop_<nom>`) : la détection se fait au démarrage de chaque script.
4. Pour forcer un système sans toucher au `server.cfg` : `Config.Framework`, `Config.Inventory`, `Config.Target`,
   `Config.Notify` dans le `config.lua` du script.
5. Mettre `Config.Debug = true` : la console affiche le framework, l'inventaire et le target détectés.
