# pop_tablet — Banque d'idées inspirées de faits réels et de films/séries

Recherche du 24/11/2026. 35 idées réparties sur 6 métiers, pensées pour un script FiveM (pas de vraie IA, pas de vraie crypto réseau : tout est simulé côté serveur). On reste au niveau du jeu : aucune idée ne décrit une vraie méthode criminelle.

Lecture :
- **Inspiré de** : le fait ou l'œuvre d'origine, avec renvoi vers la source ([S1], [S2]… liste en bas).
- **Waouh** : de 1 à 5, l'effet sur les joueurs.
- **Complexité** : simple (quelques jours, surtout de l'interface), moyen (logique serveur et base de données), gros (plusieurs systèmes reliés, ou dépendance à d'autres scripts).
- **Concurrence** : notée sous chaque tableau. « Vérifié » = vu sur la page du produit pendant la recherche ; « non vérifié » = connu mais pas contrôlé ici.

---

## 1. Police / LSPD (7 idées)

| Idée | Inspiré de | Ce que ça fait | Interaction RP | Waouh | Complexité |
|---|---|---|---|---|---|
| P1. Lecteur de plaques (« hotlist ») | Les lecteurs automatiques de plaques (ALPR) photographient les plaques et alertent la police si une plaque figure sur une liste de véhicules recherchés [S8][S9] | La police inscrit une plaque recherchée ; les caméras fixes aux carrefours et la voiture de patrouille enregistrent les passages. La tablette affiche l'historique (« vue à Vinewood, 21 h 14 »). | Les gangs font changer leurs plaques chez un mécano véreux. La police remonte un trajet pour retrouver une planque. | 4 | moyen |
| P2. Alerte coups de feu par zone | ShotSpotter : des micros sur les lampadaires repèrent un tir et envoient l'heure et la position approximative à la police [S10] | Chaque tir non silencieux en ville déclenche une alerte sur la carte : un cercle approximatif, pas un point exact, et parfois une fausse alerte (pétard, raté de moteur). | La police doit ratisser la zone et interroger les témoins. Les gangs ont intérêt à éviter les tirs en ville ou à s'équiper autrement. | 3 | simple |
| P3. Traceur GPS de poursuite | StarChase : la voiture de patrouille tire un projectile GPS collant sur le véhicule en fuite, ce qui permet de suivre à distance sans poursuite dangereuse [S6] | Pendant une poursuite, la police « tague » le véhicule. La tablette montre sa position toutes les X secondes, avec une batterie limitée. | Le fuyard peut lâcher la voiture, ou demander à un mécano de chercher le traceur (voir M4). Les poursuites deviennent tactiques au lieu de finir en carambolage. | 5 | moyen |
| P4. Tableau CompStat (carte de chaleur) | CompStat, créé par le NYPD en 1994 : statistiques quotidiennes par quartier et réunions hebdomadaires où les commandants rendent des comptes [S11] | Une carte de chaleur des crimes de la semaine (vols, tirs, braquages) et les chiffres par secteur. Le chef imprime un rapport pour la réunion. | Elle crée de la pression hiérarchique et des réunions RP dans la police. Le maire ou la presse peuvent demander les chiffres. | 3 | simple |
| P5. Alerte enlèvement / avis de recherche public | AMBER Alert : les autorités diffusent une alerte sur les téléphones de la zone pour retrouver un enfant enlevé [S12] | La police pousse une alerte (photo, véhicule, plaque) sur toutes les tablettes et tous les téléphones, avec un bouton « signaler anonymement ». | Toute la ville participe. Les civils deviennent témoins ; les gangs peuvent envoyer de faux signalements pour détourner les patrouilles. | 4 | simple |
| P6. Demande d'images aux commerces | Ring (Amazon) : via l'appli Neighbors, la police demandait aux particuliers leurs vidéos de sonnette ; depuis 2024 il lui faut un mandat ou un accord volontaire [S13] | La police envoie une demande aux joueurs qui possèdent une caméra (commerce, maison) : ils acceptent ou refusent. En cas de refus, il faut un mandat (J1). | Elle lie police, entreprises et justice. Un commerçant de mèche avec un gang peut « avoir effacé » ses images, ce qui devient un indice en soi. | 4 | moyen |
| P7. Journal bodycam horodaté | Les règlements bodycam des polices américaines prévoient l'activation à l'intervention et un pré-enregistrement de quelques secondes [S14] | La tablette tient un journal automatique de chaque policier (arme sortie, menottes, tir, fouille), avec l'heure et le lieu, et un bouton « activer bodycam ». | L'avocat demande le journal au procès. Une bodycam coupée pendant une bavure devient une affaire interne. | 4 | moyen |

Concurrence : les MDT police du marché (LB Tablet : dispatch, rapports, mandats, dossiers, casier ; vérifié [S30]) couvrent la base. Les alertes « coups de feu » existent dans les scripts de dispatch (non vérifié). Le lecteur de plaques existe sous forme de radar en voiture (Wraith ARS 2X, non vérifié), mais pas, à notre connaissance, en réseau de caméras fixes avec historique de trajets (non vérifié). Le traceur de poursuite façon StarChase n'est pas courant (non vérifié).

---

## 2. EMS / médecins (5 idées)

| Idée | Inspiré de | Ce que ça fait | Interaction RP | Waouh | Complexité |
|---|---|---|---|---|---|
| E1. Triage « plan blanc » | Le triage START : en afflux massif de victimes, chaque blessé reçoit une couleur (vert, jaune, rouge, noir) selon la marche, la respiration, le pouls et la conscience [S15] | Après une fusillade ou un carambolage, l'EMS pose un bracelet de couleur sur chaque blessé depuis la tablette. La carte et la liste partagée montrent qui évacuer en premier. | L'EMS coordonne avec la police (qui sécurise) et avec les autres ambulances. Les joueurs blessés vivent un vrai moment de tension. | 4 | moyen |
| E2. Alerte « Bon samaritain » | PulsePoint : en cas d'arrêt cardiaque, les citoyens formés aux premiers secours à moins de six pâtés de maisons reçoivent une alerte et la position du défibrillateur le plus proche [S16] | L'EMS délivre un « brevet de secourisme » aux civils (RP de formation). Ces civils reçoivent les alertes d'urgence vitale proches et voient les défibrillateurs sur la carte. | L'EMS donne des formations payantes, les civils peuvent agir avant l'arrivée de l'ambulance, et il y a plus de jeu quand l'EMS est peu nombreux. | 4 | moyen |
| E3. Tableau des urgences | The Pitt (HBO Max, 2025), urgences en temps réel ; Grey's Anatomy et le tableau du bloc [S17][S18] | Un tableau partagé de l'hôpital : patients, box, état (en attente, en soins, au bloc, sorti), médecin assigné, et blocs réservés. | La famille demande des nouvelles à l'accueil. La police est prévenue d'une blessure par balle et vient interroger le patient, que le médecin peut déclarer « pas en état ». | 4 | simple |
| E4. Rapport médico-légal | La recherche du Golden State Killer, résolue en 2018 en recoupant l'ADN de la scène avec un site de généalogie [S5] | Le légiste remplit un rapport (cause du décès, calibre, distance de tir, heure estimée) lié au dossier de police. Une analyse de profil ADN prend un temps réel en jeu. | Le légiste devient un maillon EMS → police → justice. L'avocat peut contester les conclusions. | 4 | moyen |
| E5. Liste d'attente de greffe | UNOS : un algorithme apparie organes et receveurs selon la compatibilité, l'urgence, la distance et le temps d'attente [S19] | Le dossier patient inclut le consentement au don. Une liste d'attente RP avec compatibilité simulée ; une alerte « greffon disponible » lance un transport urgent. | Le transport d'organe sous escorte police donne une mission EMS + police. On peut mettre en scène des passe-droits (corruption) qui feront scandale. | 3 | moyen |

Concurrence : LB Tablet propose une appli EMS (dispatch, rapports, journaux ; vérifié [S30]). Le triage par couleur, l'alerte secouriste civile et le tableau des urgences en temps réel ne sont pas, à notre connaissance, proposés en standard (non vérifié).

---

## 3. Mécanos (5 idées)

| Idée | Inspiré de | Ce que ça fait | Interaction RP | Waouh | Complexité |
|---|---|---|---|---|---|
| M1. Carnet du véhicule par numéro de série | La fraude au compteur : plus de 450 000 voitures vendues chaque année aux États-Unis avec un faux kilométrage ; on la détecte par l'historique d'entretien et les rapports liés au numéro de série [S20] | Chaque voiture a un carnet : entretiens, réparations, accidents, kilométrage relevé à chaque passage au garage. Le mécano y écrit ; le concessionnaire et l'acheteur le consultent. | Un mécano véreux peut « reculer » le compteur contre paiement, mais une incohérence dans le carnet trahit la fraude. La police et la justice peuvent poursuivre. | 4 | moyen |
| M2. Contrôle technique et « mode test » | Le Dieselgate : Volkswagen avait un logiciel qui détectait les tests d'émissions et n'activait la dépollution que pendant le test (jusqu'à 40 fois la norme sur route) [S21] | La tablette du mécano fait le contrôle technique (préparations moteur légales ou non). Un mécano peut installer un module qui masque les préparations illégales pendant le contrôle. | Un contrôle routier de la police avec analyseur peut démasquer le module, puis procès du garage. Une affaire « Dieselgate » à l'échelle de la ville. | 4 | moyen |
| M3. Gravure des pièces | La vague de vols de pots catalytiques : certains États imposent un registre aux ferrailleurs et testent la gravure de numéros sur les pièces [S22] | Le mécano grave le numéro de la voiture sur les pièces chères. Les pièces démontées à la casse gardent leur numéro, consultable par la police. | Les gangs qui désossent des voitures volées risquent d'être tracés. La police enquête sur les casses ; l'assurance baisse pour les voitures gravées. | 3 | moyen |
| M4. Balayage anti-traceur | StarChase [S6] et Heat (1995), où la bande de McCauley flaire la surveillance de l'équipe de Hanna [S23] | Le mécano (ou un spécialiste de gang) scanne une voiture : il trouve ou non un traceur de police (P3) ou d'un gang rival, et peut le retirer ou le laisser pour tendre un piège. | C'est la contre-mesure directe de P3. La police doit choisir quand taguer ; le mécano devient un allié recherché. | 4 | simple |
| M5. Protection antivol sans clé | Les vols de voitures sans clé « par relais » signalés par la police et Crimestoppers au Royaume-Uni [S24] | Les voitures haut de gamme peuvent être volées avec un gadget de jeu (mini-jeu). Le mécano vend et installe un module « anti-relais » qui rend le vol beaucoup plus dur. | Il crée un marché pour les mécanos et les assureurs, une course entre voleurs et garages, et des plaintes à la police. | 3 | simple |

Concurrence : beaucoup de scripts de mécano gèrent la réparation et le tuning (non vérifié), mais un carnet par numéro de série consultable par le concessionnaire et la police, et le « mode test » au contrôle technique, ne sont pas courants à notre connaissance (non vérifié).

---

## 4. Justice : avocats, juges, procureurs (6 idées)

| Idée | Inspiré de | Ce que ça fait | Interaction RP | Waouh | Complexité |
|---|---|---|---|---|---|
| J1. Mandats numériques signés par un juge | Le principe du mandat (Ring : depuis 2024 la police doit passer par un mandat pour obtenir les vidéos [S13]) ; ANOM, où l'interception a été montée pour respecter des contraintes légales [S1] | La police remplit une demande de mandat (perquisition, écoute, accès à une messagerie cryptée, traceur). Le juge la signe ou la refuse avec un motif. Une preuve obtenue sans mandat est marquée « irrecevable ». | C'est le pivot de toute l'interaction police ↔ justice : sans juge, pas d'enquête lourde. Les avocats attaquent les mandats bâclés. | 5 | simple |
| J2. Chaîne de possession des preuves | Making a Murderer et Serial, où la défense conteste la manipulation des preuves et la façon dont elles ont été obtenues [S25][S26] | Chaque scellé a son historique : qui l'a ramassé, déposé, consulté, transféré, à quelle heure. Une rupture dans la chaîne s'affiche en rouge. | L'avocat peut faire tomber une preuve. Les policiers doivent être rigoureux, et un policier corrompu qui « égare » un scellé laisse une trace. | 5 | moyen |
| J3. Réouverture d'affaire | Innocence Project : des centaines de condamnés innocentés par l'ADN aux États-Unis, souvent après une erreur d'identification par un témoin [S27] ; Golden State Killer [S5] | Les affaires classées restent consultables. Un avocat dépose une demande de révision avec une nouvelle preuve ; le juge peut rouvrir l'affaire. | Un « cold case » relance d'anciennes histoires, par exemple un innocent emprisonné ou un vrai coupable qui se croyait tranquille. | 3 | simple |
| J4. Collaborateur de justice | ANOM : l'informateur « Afgoo » a coopéré avec le FBI en échange d'une réduction de peine [S1] | Le procureur propose un accord écrit (peine réduite contre informations, témoignage ou infiltration). Il est signé dans la tablette et visible seulement par le procureur, le juge et l'avocat. | C'est de la paranoïa pure dans les gangs : qui a signé ? Il existe un risque de fuite si un greffier ou un policier corrompu consulte le dossier. | 5 | simple |
| J5. Rôle d'audience et jury citoyen | Les procès filmés de Making a Murderer [S25] ; le fonctionnement classique des cours américaines | Le juge planifie les audiences. Les citoyens tirés au sort reçoivent une convocation de juré ; vote à la fin, avec un verdict enregistré au casier. | Les civils sans métier participent à la justice, et une pression ou un achat de juré par un gang devient possible (mais traçable). | 4 | moyen |
| J6. Cabinet d'avocats et barreau | Suits (faux avocat sans diplôme dans un grand cabinet) et Better Call Saul (avocat marketing et combines) [S28][S29] | Gestion du cabinet : clients, dossiers, heures facturées, publicités. Le barreau (juge en chef) tient la liste des avocats inscrits et peut suspendre ou radier. | Les avocats deviennent un vrai métier rentable, avec des enquêtes du barreau sur un « avocat » sans licence et des clients de gangs fidèles. | 3 | simple |

Concurrence : les mandats et dossiers existent déjà dans LB Tablet (vérifié [S30]) et dans la plupart des MDT. Les sacs de preuves avec identifiant de suivi existent dans r14-evidence (vérifié [S31]), mais sans chaîne de possession exploitable au tribunal ; le développeur annonce une base de données de preuves pour plus tard. Accords de collaboration, jury et barreau : pas vus chez les concurrents (non vérifié).

---

## 5. Gangs / criminels (7 idées)

| Idée | Inspiré de | Ce que ça fait | Interaction RP | Waouh | Complexité |
|---|---|---|---|---|---|
| G1. Messagerie cryptée infiltrable | EncroChat (environ 60 000 utilisateurs, 6 558 arrestations après que la gendarmerie a contourné le chiffrement sur des serveurs en France) [S2] ; Sky ECC [S3] ; ANOM, téléphones distribués par le FBI lui-même (environ 11 800 appareils, plus de 800 arrestations en 2021) [S1][S4] | Un terminal « crypté » acheté au marché noir donne une messagerie de gang hors du téléphone normal. Avec mandat (J1) et une enquête (indices accumulés), la police peut infiltrer le serveur et lire les messages à partir de ce moment, jamais l'historique avant. Variante ANOM : la police met en vente via un indic des terminaux piégés dès le départ. Le tout est simulé côté serveur. | C'est le duel le plus fort entre police et gangs : les gangs ne savent jamais si le réseau est compromis. Un « grand coup de filet » simultané devient possible le jour J, et le gang doit changer de réseau. | 5 | gros |
| G2. Code de bipeur | The Wire, épisode « The Pager » : les numéros des bipeurs du clan Barksdale sont codés, et l'équipe de surveillance doit casser le code [S7] | Le gang choisit un code simple (permutation de chiffres) pour ses messages courts. La police, avec mandat, intercepte les messages bruts (codés) et doit trouver la règle (mini-énigme). | Une énigme jouée entre joueurs : un policier « Prez » qui casse le code devient une légende. Le gang change de code s'il se sent grillé. | 4 | moyen |
| G3. Livre de comptes saisissable | Al Capone condamné en 1931 pour fraude fiscale (11 ans) grâce à des registres de paris avec ses initiales, trouvés par l'agent Frank Wilson [S32][S33] | Le gang tient sa compta dans la tablette (entrées, dettes, parts). En perquisition, la tablette ou le carnet peut être saisi ; le procureur voit alors les montants et les initiales. | On attrape les chefs par l'argent, pas par les armes. Le trésorier du gang devient une cible et un rôle clé. | 5 | simple |
| G4. Blanchiment par façade | Breaking Bad (Skyler et le lavage auto A1A) [S34] ; Narcos/Escobar et ses montagnes de liquide (des milliards perdus, mangés par les rats selon son frère) [S35] | Le gang s'associe à une entreprise de joueur (lavage, bar, garage) et y injecte de l'argent sale, plafonné par un chiffre d'affaires crédible. Au-delà, le risque d'audit grimpe. | Le lien gang ↔ entreprise ↔ justice : un contrôle fiscal du procureur, un chef d'entreprise complice ou victime de chantage. | 5 | moyen |
| G5. Guetteurs et contre-filature | Heat (1995), filatures et contre-filatures entre l'équipe de Hanna et la bande de McCauley [S23] ; The Wire [S7] | Les guetteurs du gang signalent depuis la tablette une « voiture suspecte » (plaque, modèle) près du territoire. La liste partagée du gang rassemble les plaques de voitures banalisées repérées. | La police doit varier ses véhicules et ses planques, et une planque grillée devient un moment fort. Des rôles se créent pour les petits membres de gang. | 3 | simple |
| G6. Tableau de préparation de braquage | Ocean's Eleven (fausses images de la salle forte, coupure de courant) [S36] ; braquage d'Anvers en 2003, gang retrouvé grâce à des déchets jetés près de l'autoroute et à un sandwich portant de l'ADN [S37] | Un tableau de plan pour le gang : rôles, matériel à réunir, repérages (photos), horaires. Une préparation bâclée laisse des indices sur place (déchets, ADN), que la police peut ramasser. | Le gang planifie en RP au lieu de foncer. Il y a un lien direct avec les preuves de la police (J2), et les erreurs coûtent cher. | 4 | moyen |
| G7. Marché caché | Silk Road : en 2013, le FBI arrête son fondateur dans une bibliothèque en le distrayant pour saisir son ordinateur ouvert avant qu'il ne puisse le chiffrer [S38] | Une boutique anonyme dans la tablette (pseudo, réputation des vendeurs). Si le gérant est arrêté tablette déverrouillée, la police récupère tout. Si elle est verrouillée, elle ne récupère rien sans enquête longue. | Elle crée un vrai « moment Ulbricht » : la police monte une diversion pour saisir la tablette ouverte. Les gérants deviennent prudents (verrouillage auto). | 5 | moyen |

Concurrence : les messageries de gang existent (BYLOCK : messagerie « style crypté », sans interception policière décrite ; vérifié [S39]). Les téléphones de vente de drogue avec blanchiment, relations entre gangs et indics existent (Envi Trap Phone ; vérifié [S40]). Aucun produit vu ne propose une infiltration policière progressive de la messagerie façon EncroChat/ANOM ; c'est le principal point de différenciation (non vérifié de façon exhaustive). Le tableau de braquage est un classique de GTA Online (non vérifié pour FiveM).

---

## 6. Entreprises : agence immobilière, concessionnaire, sociétés (5 idées)

| Idée | Inspiré de | Ce que ça fait | Interaction RP | Waouh | Complexité |
|---|---|---|---|---|---|
| B1. Cadastre et alerte de fraude au titre | Le FBI alerte sur les « voleurs de titres » qui vendent ou hypothèquent des maisons dont ils ne sont pas propriétaires, souvent des biens sans prêt en cours [S41] | L'agence immobilière enregistre chaque vente au cadastre. Un escroc peut tenter de vendre la maison d'un joueur absent avec de faux papiers. Le vrai propriétaire reçoit une alerte, et le juge ou le notaire peut annuler. | Elle lie agent immo, escroc, police et juge. Les agents sérieux vérifient les identités ; les agents véreux ferment les yeux. | 4 | moyen |
| B2. Dossier de crédit immobilier | The Big Short et la crise des subprimes, avec des prêts accordés sans vérifier les revenus [S42] | La banque ou l'agence monte un dossier (revenus déclarés, apport). Un agent peut gonfler un dossier ; en cas d'impayés, il y a saisie et remise en vente par l'agence. | Il crée des saisies dramatiques, du travail pour les avocats, et des enquêtes sur un agent qui a « arrangé » des dossiers. | 3 | moyen |
| B3. Reprise et contrôle « véhicule volé » | La fraude au compteur et les rapports d'historique par numéro de série [S20] ; les fraudes au titre des véhicules [S43] | Avant une reprise, le concessionnaire consulte le carnet du véhicule (M1) et la base police (volé, gagé, fourrière). Il édite un certificat de vente. | Le receleur se fait prendre au comptoir. Le concessionnaire honnête prévient la police, et celui de mèche avec un gang devient une piste d'enquête. | 4 | simple |
| B4. Bourse de la ville | GTA V : la bourse LCN réagit aux événements du jeu, et les missions d'assassinat de Lester font bouger les cours [S44] | Les entreprises de joueurs ont une action dont le cours bouge selon des événements (braquage d'une banque, gros contrat, scandale). Les joueurs achètent et vendent. | Le délit d'initié devient du RP : un gang parie contre la banque qu'il va braquer. Le procureur enquête sur des achats suspects juste avant. | 4 | gros |
| B5. Comptabilité, broyeuse et lanceur d'alerte | Enron et la destruction massive de documents par Arthur Andersen [S45] ; Madoff, dénoncé en vain pendant des années par Harry Markopolos [S46] ; Theranos [S47] | Une compta d'entreprise dans la tablette. Supprimer des documents laisse une trace « document détruit le… ». Un employé peut envoyer un signalement anonyme au procureur. | Il crée des scandales d'entreprise, des perquisitions financières et des obstructions à la justice prouvables, et c'est un rôle pour les employés lambda. | 4 | moyen |

Concurrence : les agences immobilières et concessionnaires FiveM gèrent en général la vente et les clés (non vérifié). Le cadastre avec contrôle de fraude, la bourse liée aux événements du serveur et la piste d'audit des documents ne sont pas courants à notre connaissance (non vérifié).

---

## Top 10 recommandé

On a retenu les idées qui créent le plus d'interactions entre métiers, pour un coût raisonnable.

1. **G1. Messagerie cryptée infiltrable (EncroChat / ANOM)** : la signature du produit ; c'est le duel police ↔ gangs ↔ juge que personne ne propose.
2. **J1. Mandats numériques signés par un juge** : le socle simple dont dépendent G1, G2, P3 et P6 ; il donne du travail aux juges.
3. **J2. Chaîne de possession des preuves** : chaque preuve devient un enjeu au procès entre police et avocat.
4. **P3 + M4. Traceur GPS de poursuite et balayage anti-traceur** : des poursuites tactiques, avec une contre-mesure qui fait vivre les mécanos.
5. **G3. Livre de comptes saisissable (Capone)** : très simple, énorme effet ; on attrape les chefs par l'argent.
6. **G4. Blanchiment par façade (Breaking Bad)** : lie gangs, entreprises de joueurs et contrôle fiscal du procureur.
7. **J4. Collaborateur de justice (l'indic d'ANOM)** : simple à faire, crée de la paranoïa et des trahisons dans les gangs.
8. **P1. Lecteur de plaques en réseau** : un outil d'enquête concret qui alimente aussi le travail des mécanos (plaques).
9. **E1. Triage « plan blanc »** : donne à l'EMS son grand moment pendant les fusillades, coordonné avec la police.
10. **M1 + B3. Carnet du véhicule et contrôle à la reprise** : relie mécano, concessionnaire et police, et la fraude au compteur devient une enquête.

Ordre de construction conseillé : J1 → J2 → G3 → J4 (simples, socle), puis P1, P3/M4, E1, M1/B3, G4, et enfin G1 (gros, s'appuie sur les mandats et les dossiers).

---

## Sources

- [S1] Operation Trojan Shield (ANOM), Wikipedia : https://en.wikipedia.org/wiki/Operation_Trojan_Shield
- [S2] Eurojust, bilan EncroChat (27/06/2023) : https://www.eurojust.europa.eu/news/dismantling-encrypted-criminal-encrochat-communications-6-500-arrests-900-eur-seized
- [S3] Eurojust, nouvelles interventions contre les messageries cryptées (Sky ECC) : https://www.eurojust.europa.eu/new-major-interventions-block-encrypted-communications-criminal-networks
- [S4] FBI, résultats de l'opération Trojan Shield : https://www.fbi.gov/news/stories/fbi-global-partners-announce-results-of-operation-trojan-shield-060821 ; Europol : https://europol.europa.eu/newsroom/news/800-criminals-arrested-in-biggest-ever-law-enforcement-operation-against-encrypted-communication
- [S5] NPR, Golden State Killer et GEDmatch : https://www.npr.org/sections/thetwo-way/2018/04/27/606624218
- [S6] NIJ, étude de cas StarChase : https://nij.ojp.gov/topics/articles/case-study-gps-tracking-tool-designed-aid-police-vehicle-pursuits
- [S7] The Wire, épisode « The Pager » : https://en.wikipedia.org/wiki/The_Pager
- [S8] EFF, lecteurs automatiques de plaques : https://sls.eff.org/technologies/automated-license-plate-readers-alprs
- [S9] NIJ/OJP, lecteurs de plaques (rapport) : https://www.ojp.gov/pdffiles1/nij/grants/239605.pdf
- [S10] EFF, détection acoustique des tirs : https://sls.eff.org/technologies/gunshot-detection
- [S11] CompStat, Wikipedia : https://en.wikipedia.org/wiki/CompStat
- [S12] AMBER Alert, FAQ officielle : https://amberalert.ojp.gov/about/faqs
- [S13] NPR, Ring arrête les demandes de vidéos de la police (2024) : https://www.npr.org/2024/01/25/1226942087/ring-will-no-longer-allow-police-to-request-doorbell-camera-footage
- [S14] BJA, tendances des règlements bodycam : https://bja.ojp.gov/sites/bja/files/media/document/key-trends-in-bwc-policy-and-practice-2017.pdf
- [S15] HHS CHEMM, algorithme de triage START : https://chemm.hhs.gov/startalgotext.htm
- [S16] Ville de San Francisco, lancement de PulsePoint : https://www.sf.gov/news--san-francisco-launches-use-pulsepoint-mobile-app-help-save-lives-press-release
- [S17] The Pitt, Wikiwand : https://www.wikiwand.com/en/articles/The_Pitt
- [S18] Grey's Anatomy, IMDb : https://www.imdb.com/title/tt0413573/
- [S19] UNOS, appariement des organes : https://unos.org/about/how-we-match-organs/
- [S20] NHTSA, fraude au compteur : https://www.nhtsa.gov/odometer-fraud
- [S21] EPA, infractions de Volkswagen : https://epa.gov/vw/learn-about-volkswagen-violations
- [S22] Pew/Stateline, vols de pots catalytiques et lois des États : https://www.pewtrusts.org/research-and-analysis/blogs/stateline/2021/11/04/surging-catalytic-converter-thefts-spur-state-crackdowns
- [S23] Heat (1995), Wikipedia : https://en.wikipedia.org/wiki/Heat_(1995_film)
- [S24] Crimestoppers UK, hausse des vols sans clé : https://crimestoppers-uk.org/news-campaigns/news/2024/aug/the-invisible-threat-the-rise-in-keyless-vehicle-theft
- [S25] Making a Murderer, Wikipedia : https://en.wikipedia.org/wiki/Making_a_Murderer
- [S26] PBS, Serial et le système judiciaire : https://www.pbs.org/newshour/show/serial-shined-light-troubled-justice-system
- [S27] Innocence Project, exonérations par l'ADN : https://innocenceproject.org/dna-exonerations-in-the-united-states/
- [S28] Suits, Wikipedia : https://en.wikipedia.org/wiki/Suits_(American_TV_series)
- [S29] Better Call Saul, épisode « RICO » : https://en.wikipedia.org/wiki/RICO_(Better_Call_Saul)
- [S30] LB Tablet, forum Cfx.re : https://forum.cfx.re/t/lb-tablet-tablet-with-mdt-for-ems-police/5294249
- [S31] r14-evidence, forum Cfx.re : https://forum.cfx.re/t/paid-qb-r14-evidence-an-expanded-and-enhanced-evidence-script-for-qb-core/4860062
- [S32] Mob Museum, Capone et la fraude fiscale : https://prohibition.themobmuseum.org/the-history/enforcing-the-prohibition-laws/prohibition-mob-bosses-tripped-tax-laws/
- [S33] IRS, documents historiques sur Al Capone : https://www.irs.gov/privacy-disclosure/historical-documents-relating-to-alphonse-al-capone-chicago
- [S34] Saul Goodman / Breaking Bad, Wikipedia : https://en.wikipedia.com/wiki/Saul_Goodman ; Looper, le lavage auto A1A : https://www.looper.com/943546/the-big-question-some-breaking-bad-fans-still-have-about-the-a1a-car-wash
- [S35] Business Insider, Escobar et les milliards perdus : https://www.businessinsider.in/legendary-drug-lord-pablo-escobar-lost-2-1-billion-in-cash-each-year-and-it-didnt-matter/articleshow/48905816.cms
- [S36] Ocean's Eleven (2001), Wikipedia : https://en.wikipedia.org/wiki/Ocean%27s_Eleven
- [S37] Braquage d'Anvers (2003), Wikipedia : https://en.wikipedia.org/wiki/Antwerp_diamond_heist
- [S38] Ross Ulbricht (Silk Road), Wikipedia : https://en.wikipedia.org/wiki/Ross_Ulbricht
- [S39] BYLOCK V6, Tebex : https://ertancstudio.tebex.io/package/7467477
- [S40] Envi Trap Phone, documentation : https://envi-scripts-organization.gitbook.io/documentation/premium-scripts/envi-trap-phone
- [S41] CBS News, alerte du FBI sur la fraude au titre de propriété : https://www.cbsnews.com/news/fbi-deed-land-scam-property-theft-new-england ; ALTA : https://alta.org/news-and-publications/news/20250410-FBI-Boston-Issues-Quit-Claim-Deed-Fraud-Warning
- [S42] Fed de New York, à propos de The Big Short : https://libertystreeteconomics.newyorkfed.org/2016/04/hey-economist-what-did-you-make-of-the-big-short
- [S43] Washington DOL, fraude au titre des véhicules : https://dol.wa.gov/vehicles-and-boats/vehicles/vehicle-registration/vehicle-title/title-fraud
- [S44] GamesRadar, bourse de GTA V et missions de Lester : https://gamesradar.com/gta-5-stock-market-guide
- [S45] Britannica, chute d'Enron : https://www.britannica.com/event/Enron-scandal/Downfall-and-bankruptcy ; PBS, procès Andersen : https://www.pbs.org/newshour/economy/business-jan-june02-andersen_05-14
- [S46] Harry Markopolos, Wikipedia : https://en.wikipedia.org/wiki/Harry_Markopolos
- [S47] Theranos, Britannica : https://www.britannica.com/topic/Theranos-Inc
