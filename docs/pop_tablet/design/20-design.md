# POP Tablet · 20 · Design

Référence visuelle : `maquette.html` (même dossier, ouvrir dans un navigateur). Captures : `captures/`. Les valeurs ci-dessous sont celles de la maquette ; le kit `web/kit/pop.css` les reprend en variables CSS.

## 1. Jetons

### Couleurs
| Jeton | Valeur | Usage |
|---|---|---|
| `--bg` | `#0E0F12` | fond de l'écran de la tablette |
| `--s1` | `#15171C` | barre latérale, cartes, listes |
| `--s2` | `#1C1F26` | champs, boutons secondaires, survol |
| `--s3` | `#262A33` | survol de `--s2`, onglet actif, bandeau |
| `--line` / `--line2` | blanc 7 % / 13 % | séparateurs / bords de fenêtre |
| `--tx` / `--tx2` / `--tx3` | blanc 100 % / 62 % / 38 % | texte principal / secondaire / discret |
| `--ac` | `#4FA3FF` | **seule couleur d'accent** (réglable) : bouton principal, sélection, payé, en service |
| `--ac-s` | accent 14 % | fond des pastilles et de l'élément de menu actif |
| `--ac-on` | `#04111F` | texte posé sur l'accent (contraste lisible) |
| `--danger` | `#E5484D` | erreur, « En retard », « Dangereux », batterie ≤ 10 % |
| `--warn` | `#F5A524` | batterie ≤ 20 % seulement |
| Scène / cadre | `#060709` / `#000` | fond du jeu derrière, bord de l'appareil |

Aucun dégradé, aucun flou (pas de `backdrop-filter`). Les sites du navigateur suivent le même accent dans la maquette.

### Typographie (police système)
| Rôle | Taille / graisse |
|---|---|
| Heure de l'écran verrouillé | 104 px / 200 |
| Grand chiffre (solde, météo) | 40 px / 700 (météo 120 px / 200) |
| Titre d'écran | 24 px / 700 |
| Titre de fenêtre, nom de fiche | 19–24 px / 700 |
| Texte courant | 14 px / 400 |
| Libellé d'icône, onglet | 13 px / 500 |
| Secondaire, colonnes, barre du haut | 12 px |
| Chiffres | `tabular-nums` ; montants « 12 500 $ » (espace fine) |

### Espacements, tailles, rayons, ombres, durées
| Jeton | Valeur |
|---|---|
| Échelle d'espacement | 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48 px |
| Marge du contenu d'app | 32 px (en-tête 72 px de haut) |
| Écran / cadre | 1180 × 760 px, bord noir 14 px, ≤ 85 % hauteur et 90 % largeur |
| Barre du haut | 28 px |
| Barre latérale d'app | 232 px |
| Icône d'app | 72 px, grille 6 × 4, rangée de 136 px |
| Hauteurs de contrôle | 30 (petit) · 38 (normal) · 42 (champ) · 48 (grand) px |
| Ligne de liste | 56 px min |
| Rayons | 8 (petit bouton, puce) · 10 (bouton, champ, menu) · 12 (bandeau) · 16 (carte, liste) · 18 (écran) · 20 (icône, fenêtre) · 999 (pastille) |
| Ombre | `0 18px 48px rgba(0,0,0,.55)` : fenêtres, bandeau, volet notifications uniquement |
| Fondu | 150 ms linéaire (écrans, fenêtres, bandeau) |
| Bandeau succès | visible 2 s |
| Erreur du code | secousse 80 ms × 3 |
| Appui long | 600 ms (ranger) · 1 s (champ caché de Météo) |
| Chargement long | message après 5 s |

## 2. Composants
| Composant | Rendu | États |
|---|---|---|
| Bouton principal | fond accent, texte `--ac-on`, 600 | survol plus clair · désactivé 38 % |
| Bouton secondaire | fond `--s2`, texte blanc | survol `--s3` |
| Bouton discret | texte accent, sans fond | survol `--ac-s` |
| Bouton danger | fond rouge 14 %, texte rouge | — (retirer, supprimer) |
| Bouton sans droit | grisé + « Grade requis : {grade} » sous le bouton, icône cadenas | jamais cliquable |
| Liste | carte `--s1`, lignes 56 px séparées par `--line` | survol `--s2` · sélection `--s2` + trait accent 3 px côté début |
| Tableau | en-têtes 12 px `--tx3`, cellules 14 px, montants alignés à la fin | ligne cliquable au survol |
| Champ | fond `--s2`, 42 px, rayon 10 | focus : bord accent · erreur : bord rouge + texte rouge dessous |
| Case / radio | 20 px, cochée = accent | — |
| Onglets (segments) | groupe `--s1`, actif `--s3` | compteur entre parenthèses |
| Onglets soulignés | texte `--tx2`, actif blanc + trait accent 2 px | fiche citoyen |
| Pastilles | 22 px : accent (payé, urgent, en service), blanche (en attente, impayé), contour (refusé, clos), rouge (en retard, dangereux) | point 6 px en option |
| Bandeau (succès / erreur) | en haut au centre sur la barre du haut, `--s3`, trait 3 px accent (rouge si erreur), icône | 2 s puis disparaît |
| Fenêtre | 440 px, `--s1`, rayon 20, voile noir 60 % | Échap ou clic hors fenêtre ferme ; boutons à la fin : Annuler puis action |
| Volet notifications | 340 px sous la cloche | clic sur une ligne ouvre l'app |
| Barre latérale | marque (icône + nom + sous-titre), menu 40 px, carte d'identité en bas | élément actif fond accent 14 % |
| Barre du haut | heure · nom de l'app au centre · service, réseau, cloche, batterie | « En service » point accent / « Hors service » point gris, cliquable |

### Les 6 états (barre « Maquette » en haut de la page)
| État | Rendu |
|---|---|
| Vide | icône ronde, titre, phrase, bouton pour commencer (« Aucune facture pour ces critères. » + « Nouvelle facture ») |
| Chargement | lignes en formes grises ; après 5 s « Le chargement prend plus de temps que prévu. » + « Réessayer » |
| Succès | bandeau 2 s (« Facture F-2026-0143 envoyée à Ana Ruiz. ») |
| Erreur | icône rouge, « Un problème est survenu. Réessayez dans un instant. » + « Réessayer » |
| Pas le droit | boutons grisés + « Grade requis : Patron » (Entreprise > Compte) ; sur le bureau les apps interdites sont cachées |
| Hors service | « Hors service. » + seul bouton actif « Prendre mon service », menu grisé (Police) |

## 3. RTL (arabe)
| Règle | Application |
|---|---|
| Sens | `dir="rtl"` sur `<html>` quand la langue est déclarée `rtl = true` |
| Mise en page | uniquement des propriétés logiques (`margin-inline-start`, `inset-inline-end`, `text-align: start`, `border-inline-start`) : grille, menus, barre du haut et pastilles s'inversent seuls |
| Icônes de sens | flèches retour / suivant / envoyer retournées (`.flip`) |
| Restent de gauche à droite | heure, montants, numéros de série, plaques, adresses `.rp`, codes, barres réseau et batterie (`.ltr`, `direction: ltr`) |
| Sélection | le trait accent passe du côté droit |
| Police | `"Noto Sans Arabic"` dans la pile système |
| Hors tablette | la barre de maquette et les éléments du jeu ne s'inversent pas |
