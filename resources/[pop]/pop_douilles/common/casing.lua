-- Constantes partagées client / serveur (non configurables : elles protègent l'équilibre et la sécurité).

Casing = {}
Casing.REPORT_INTERVAL = 1000  -- ms : client, envoi groupé des tirs ; serveur : refus si plus rapide (marge 200 ms)
Casing.MAX_SHOTS       = 30    -- tirs max acceptés par signalement
Casing.REPORT_DISTANCE = 4.0   -- serveur : position signalée / position du joueur
Casing.MERGE_DISTANCE  = 2.0   -- même arme à moins de 2 m → même tas
Casing.MAX_COUNT       = 99    -- douilles max dans un tas
Casing.MAX_PER_SIGNATURE = 15  -- tas max par signature (même tireur, même arme), avant Config.MaxCasings
Casing.PICKUP_DISTANCE = 2.5   -- serveur
Casing.TARGET_DISTANCE = 1.5   -- client
Casing.SEARCH_COOLDOWN = 5     -- secondes entre deux fouilles (serveur)
Casing.REPORT_TIME     = 12000 -- ms d'affichage de la carte rapport
