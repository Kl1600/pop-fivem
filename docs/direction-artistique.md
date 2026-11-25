# Direction artistique POP

## Gameplay — esprit GTA 6
- Pas d'action en un seul bouton : plusieurs étapes courtes et réalistes (repérer → ouvrir → démarrer).
- Des choix : discret mais lent, ou rapide mais bruyant.
- Les outils comptent : le bon objet pour la bonne situation, tout ne marche pas partout.
- Des conséquences : alarme, témoins, alerte police.
- Fluide : mini-jeux de quelques secondes, jamais pénibles.

## Visuel — HUD façon GTA 6
- Discret et contextuel : l'info apparaît seulement quand c'est utile, puis disparaît.
- Petit et placé sur le côté, jamais de grosse fenêtre au centre.
- Style du serveur choisi par le client (22/11/2026), le même que pop_notify : carte en verre sombre flouté rgba(10,10,12,.4) avec blur(12px), bordure blanche à 10 %, rayon de 4px, police TT Firs Neue, icônes dans un rond blanc, accent bleu #5d90ec. Pas de rose.
- Pas de dégradés, fondu de 150 ms.
- Touches affichées simplement : « [E] Crocheter ».

## Immersion (exigence du client, 25/11/2026)
Chaque script doit donner l'impression d'être dans le jeu, pas dans un menu.
- **Le geste avant l'interface.** Chaque action a une animation et un objet en main : bandage, défibrillateur, clé à molette, menottes, carnet. Elle dure quelques secondes avec `Bridge.Progress`, et on peut l'annuler.
- **On interagit avec le monde par le menu d'interaction du serveur** (ox_target restylé, clic gauche). Pas de nouvelle grande fenêtre : les choix sont des options ox_target, avec sous-menus si besoin.
- **L'interface est diégétique quand c'est possible** : un bipeur, une radio, une tablette, un ticket ou une facture qui s'affiche comme un vrai papier. Sinon, une petite carte au style pop_notify sur le côté, qui disparaît d'elle-même.
- **Le son** : bips, radio, sirène, outils. Volume léger, réglable dans la config.
- **Le monde réagit** : PNJ qui regardent ou fuient, portes de l'ambulance ouvertes, gyrophares, objets posés au sol puis ramassés.
- **Pas de téléportation visible.** Si on doit déplacer le joueur : écran noir court (fondu de 300 ms) ou caméra.
- **Les infos se lisent comme dans la vraie vie** : une silhouette du corps avec les zones touchées, plutôt qu'une liste de pourcentages.
- Toujours ~0,00 ms au repos : les animations et les sons ne se chargent qu'au moment de l'action.

## Idées en réserve
- Vol de véhicule inspiré GTA 6 : niveaux de sécurité, Slim Jim (discret) ou vitre cassée (bruyant), câblage, cloneur de clé pour voitures sans clé, alerte police.
