# Modèle de fiche fonctionnalité (à copier pour chaque fonctionnalité)

### [ID] Nom de la fonctionnalité
ID = `BRANCHE-APP-NN` (ex. `ENT-FAC-01`). Un ID par fonctionnalité, jamais réutilisé.

- **But** : une phrase.
- **Qui** : rôles et niveau de droit minimum (cf. tableau des droits) ; réglable ou non.
- **Où** : app > écran > élément qui déclenche (bouton, onglet, touche).
- **Parcours** : étapes numérotées, du clic au résultat final, côté joueur ET côté serveur.
- **Données** : tableau `Champ | Type | Obligatoire | Limites | Défaut`. Inclure ce qui est stocké en base et ce qui est affiché.
- **Règles serveur** : chaque vérification (droit, distance, montant, fréquence, doublon, nettoyage), avec la valeur par défaut.
- **Textes et états** : textes exacts en français entre guillemets avec leur clé de langue, pour : vide, succès, chaque erreur possible, pas le droit, hors service (si applicable).
- **Notifications** : qui reçoit quoi, texte exact.
- **Liens** : autres apps touchées, signaux API émis ou écoutés.
- **Réglages** : clés de config `Config.App.Cle = défaut` (ou « aucun »).
- **Journal admin** : oui/non, ce qui est enregistré.
- **Performance** : ce qui est chargé, quand, pagination/cache.
- **Cas limites** : au moins 3 (joueur déconnecté, double clic, données vides, limite atteinte, joueur trop loin, entreprise archivée…), avec le comportement attendu.
- **Critères d'acceptation** : liste testable « Étant donné… quand… alors… », au moins 3, dont 1 de triche refusée.

Règles d'écriture : français simple, précis, aucune formule vague (« etc. », « selon les besoins », « à définir » interdits : décide et écris la valeur). Si une décision est vraiment structurante et incertaine, écris ton choix ET ajoute-la à une section finale « Décisions prises par défaut » du fichier.
