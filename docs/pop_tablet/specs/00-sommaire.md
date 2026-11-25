# POP Tablet · 00 · Sommaire et référentiel unique

Point d'entrée du développeur. Ce fichier résume la relecture croisée des 6 fichiers de fiches (24/11/2026). **En cas de doute entre deux fichiers, ce référentiel fait foi.** Toutes les incohérences repérées ont été corrigées directement dans les fichiers ; ce qui suit est l'état final.

---

## 1. Ordre de lecture

1. `_contexte.md` : produit, performance, sécurité, style, droits par défaut (règles non négociables).
2. `00-sommaire.md` (ce fichier) : noms communs, constantes, décisions.
3. `01-base.md` : l'objet, l'écran, le moteur (bridge, porte d'entrée unique, journal, cache, file d'écriture), l'API. **À coder en premier** : tous les autres fichiers s'appuient dessus.
4. `02-entreprises.md` : Gestion (service, employés, grades, droits, compte), Factures, Annonces, Demandes. À coder en deuxième (service, droits et factures servent à tous les métiers).
5. `05-sites-admin-apps-perso.md` : table des entreprises (`pop_tablet_companies`), entreprises par défaut, éditeur de site, Admin, apps perso. À coder en troisième (l'identifiant d'entreprise vient d'ici).
6. `03-police.md`, `04-ems-mecano-justice-gang.md`, `06-outils-navigateur-gestion-pro.md` : apps au bout de l'arbre, codables en parallèle.

`_modele.md` décrit le format d'une fiche ; `_notes-relecture.md` garde l'historique des points repérés (tous tranchés ci-dessous).

## 2. Les 6 fichiers

| Fichier | Préfixes d'ID | Fiches |
|---|---|---|
| `01-base.md` | `BASE-OBJ` (18), `BASE-ECR` (17), `BASE-MOT` (19), `BASE-API` (11) | 65 |
| `02-entreprises.md` | `ENT-GES` (26), `ENT-FAC` (19), `ENT-ANN` (7), `ENT-DEM` (9) | 61 |
| `03-police.md` | `MET-POL` (47) | 47 |
| `04-ems-mecano-justice-gang.md` | `MET-EMS` (17), `MET-MEC` (11), `MET-JUS` (13), `MET-GANG` (11), `MET-IMM` (2) | 54 |
| `05-sites-admin-apps-perso.md` | `SITE-CRE` (12), `SITE-EDI` (21), `ADM` (16), `PERSO` (9) | 58 |
| `06-outils-navigateur-gestion-pro.md` | `OUT-NOT` (8), `OUT-CAL` (8), `OUT-CAR` (5), `OUT-GAL` (8), `NAV` (12), `ANNU` (5), `PRO-TAB` (15), `PRO-STO` (10), `PRO-PLA` (7) | 78 |
| **Total** | | **363** (dont 3 supprimées) |

Trois fiches sont **supprimées** sur décision du client ; leur ID est gardé pour ne pas décaler la numérotation : `BASE-OBJ-18` (acheter une tablette) et `ADM-15` (vente de tablettes), mention « (supprimée : géré par la boutique du serveur) » ; `MET-GANG-05` (réglage d'effacement des messages de gang), mention « (supprimée : messages jamais effacés, décision client) ». `BASE-OBJ-08` devient « Réinitialiser ou remplacer une tablette depuis un autre script (exports) ».

Deux fiches ont été ajoutées pendant la relecture (« tout est dans la V1 ») : `SITE-EDI-21` (réglages du site : type, description, site caché, maintenance, demandés par le navigateur) et `PRO-TAB-15` (insérer / supprimer des lignes et des colonnes du tableur).

Onze fiches ajoutées après l'audit et les décisions du client (24/11/2026) :

| ID | Fiche | Fichier |
|---|---|---|
| `BASE-API-11` | Adaptateurs de compatibilité dispatch (ps-dispatch, cd_dispatch, core_dispatch, esx_service) | 01 |
| `MET-POL-45` | Avis de recherche public sur toutes les tablettes | 03 |
| `MET-POL-46` | Carte des crimes de la semaine | 03 |
| `MET-POL-47` | Infiltration de la messagerie d'un gang (mandat signé par un juge) | 03 |
| `MET-EMS-17` | Tri des blessés par couleur (liste partagée EMS et police) | 04 |
| `MET-MEC-11` | Carnet d'entretien côté propriétaire (app « Carnet auto ») | 04 |
| `MET-JUS-12` | Contester une preuve (avocat) et trancher (juge) | 04 |
| `MET-JUS-13` | Accord de repenti | 04 |
| `MET-GANG-11` | Livre de comptes du gang | 04 |
| `MET-IMM-01` | Cadastre : registre des biens et de leurs propriétaires | 04 |
| `MET-IMM-02` | Enregistrer une vente (alerte si le vendeur n'est pas le propriétaire enregistré) | 04 |

Fiches complétées ou réécrites au même moment : `BASE-MOT-02` (mort / réveil, véhicules, argent sale), `BASE-OBJ-16`, `BASE-API-08` (adaptateur `qbx_prison`), `BASE-API-10`, `ENT-FAC-07`, `MET-POL-13`, `15`, `19`, `20` (plainte écrite, plus de « volé »), `21`, `22` (position du rapport), `28`, `29` (signature du juge), `36` (cadre d'obtention, recevabilité, chaîne de possession), `38` (optionnel, désactivé), `44`, `MET-EMS-03`, `09`, `MET-MEC-05`, `06`, `07` (carnet simple, garantie), `MET-JUS-03`, `06`, `07`, `MET-GANG-04` (messagerie jamais effacée), `07` (argent sale par framework), `10`.

---

## 3. Référentiel unique

### 3.1 Ressource, objets, commandes, admin

| Élément | Valeur |
|---|---|
| Ressource | `pop_tablet` (dossier `resources/[pop]/pop_tablet/`) |
| Objet tablette | `pop_tablet` (« Tablette », 500 g, non empilable, métadonnée `serial`) · réglage `Config.Item.Name = 'pop_tablet'` |
| Objet chargeur | `pop_tablet_charger` (« Chargeur de tablette », 200 g, empilable) |
| Vente | **aucune boutique dans la tablette** : les deux objets sont déclarés dans l'inventaire du serveur (blocs fournis par l'assistant, BASE-MOT-15) ; leur prix et leur vente sont gérés par le script de boutique du serveur |
| Réinitialisation / remplacement | admin : `/tablette_reset` et Admin > Tablettes (BASE-OBJ-09, ADM-04) ; tout script : exports serveur `ResetTablet(serial, opts)`, `ReplaceTablet(source, oldSerial, opts)`, `TransferTabletData(oldSerial, newSerial, opts)` (BASE-OBJ-08) |
| Numéro de série | `PT-XXXX-XXXX` (alphabet sans 0, O, 1, I ; `VARCHAR(12)` ; généré par le serveur à la 1re utilisation ; `Config.Serial.Prefix = 'PT'`) |
| Droit admin | ACE `pop.tablet.admin` (revérifié à chaque appel ; la console est admin) |
| Commandes | `/tablette` (ouvrir), touche `F9` (`+poptablet`), touche `Y` (fenêtre simple) · admin : `/tablette_admin`, `/tablette_donner [id]`, `/tablette_reset`, `/tablette_setup`, `/tablette_locales`, `/tablette_debug`, `/tablette_camera` · joueur : `/secours` (EMS) · aucune commande de boutique |
| Réglages des commandes | `Config.Open.Command = 'tablette'`, `Config.Admin.Command = 'tablette_admin'`, `Config.Admin.GiveCommand = 'tablette_donner'`, `Config.Admin.ResetCommand = 'tablette_reset'`, `Config.EMS.HelpCommand = 'secours'` |
| Secrets | liens Discord en convars `server.cfg` : `pop_tablet_webhook` et `pop_tablet_webhook_<categorie>` (`admin`, `money`, `alert`, `police`, `sites`) ; jamais dans `config.lua` ni le dépôt |
| Fichiers ouverts (hors escrow) | `config.lua` (un seul fichier de config, les réglages métiers y compris), `locales/*.lua`, `apps/**`, `web/kit/**`, `docs/**`, `bridge/**` (dont `bridge/jail/` et `bridge/bank/custom.lua`) |

### 3.2 Échanges client ↔ serveur

- **Une seule porte d'entrée pour toutes les demandes de la NUI** : callback `pop_tablet:request` (via `Callback.*`, sans ox_lib) avec `{ token, app, action, data, actionId }`. Réponse `{ ok = true, data }` ou `{ ok = false, err, args }`.
- Dans les fiches, `RPC gestion.service.prendre`, `pop_tablet:sites:addBlock`, `ems:duty:toggle`, `sheets:setCell` sont des **actions** de ce callback (app = premier segment, action = le reste), jamais des événements réseau séparés.
- `err` sans point = code commun (`commun.erreur.<code>`, § 3.9) ; `err` avec point = clé de langue complète.
- `actionId` = UUID v4 ; mémoire serveur **10 min** ; un `actionId` déjà vu renvoie la même réponse sans rien refaire (tous fichiers).
- Événements réseau dédiés (gestes du client de jeu, définis en 01) : `pop_tablet:close`, `pop_tablet:viewPlaced`, `pop_tablet:takePlaced`, `pop_tablet:vehicleCharge`, `pop_tablet:chargerDone`, `pop_tablet:docAnswer`, `pop_tablet:dispatchFromClient`. Tous revérifiés par le serveur.
- Serveur → client : préfixe `pop_tablet:client:` (ex. `pop_tablet:client:notify`, `pop_tablet:client:apps`, `pop_tablet:client:forceClose`, `pop_tablet:client:cityBanner`, `pop_tablet:client:cityBannerRemoved`).
- Événements internes du bridge : `pop_tablet:bridge:died` (chute), `pop_tablet:bridge:revived` (réveil), `pop_tablet:bridge:playerLoaded` (personnage chargé). Les deux premiers, envoyés par le client, ne font que déclencher une vérification serveur `Bridge.IsDead` (BASE-MOT-02) ; côté serveur, utiliser `Bridge.OnPlayerDeath` / `Bridge.OnPlayerRevived`.
- State bag : `popDuty` = id de l'entreprise en service, ou `false` (écrit par le serveur seulement).

### 3.3 Signaux API publics (serveur, `TriggerEvent` local, jamais déclenchables par un client)

| Signal | Émis par | Format |
|---|---|---|
| `pop_tablet:sentencePronounced` | Police (casier, MET-POL-26) et Justice (verdict, MET-JUS-06) via `exports.pop_tablet:EmitSentence` | BASE-API-08 : `sentenceId, identifier, source, jailMinutes, fine, communityService, charges, judge, caseId, at` (+ `origin`) ; abonnement `OnSentence(cb)` |
| `pop_tablet:invoicePaid` | Factures (ENT-FAC-18) via `EmitInvoicePaid` | BASE-API-09 : `invoiceId, number, uid, paymentId, amount, subtotal, surcharge, method, payer, company, employee, lines, metadata, externalRef, sourceScript, kind, at` ; abonnement `OnInvoicePaid(cb)` |
| `pop_tablet:invoiceRefused` · `invoiceCancelled` · `invoiceUnpaid` · `invoiceClosed` | Factures (02) | même format que `invoicePaid` sans `paymentId`, `method` |
| `pop_tablet:dutyChanged` | Service (ENT-GES-01/02/03) via `SetDuty` | `(source, { identifier, companyId, job, onDuty })` |
| `pop_tablet:memberLeft` | Gestion (02) | entreprise, identifiant, raison |
| `pop_tablet:requestCreated` · `requestClosed` | Demandes (02) | demande |
| `pop_tablet:permissionsChanged` | Droits (ENT-GES-18/19) | entreprise |
| `pop_tablet:announcementChanged` | Annonces / réglages Demandes (02) | entreprise |
| `pop_tablet:accountMovement` | Compte d'entreprise (02, à chaque ligne de `pop_tablet_ent_mouvements`) | `movementId, companyId, type, label, amountIn, amountOut, byName, at` |
| `pop_tablet:callCreated` · `reportPublished` | Police (03) | numéro, données |
| `pop_tablet:emsAlert` · `deathCertificate` · `gangVaultMove` | EMS, Gang (04) | voir fiches |
| `pop_tablet:sitePublished` · `siteHidden` · `siteRestored` · `siteAddressChanged` | Sites (05) | adresse, site |
| `pop_tablet:tabletReset` | export `ResetTablet` (BASE-OBJ-08) et admin | `serial, by, source` |
| `pop_tablet:tabletReplaced` | export `ReplaceTablet` / `TransferTabletData` (BASE-OBJ-08) | `oldSerial, newSerial, source, by` |
| `pop_tablet:opened` · `closed` · `ready` | Base (01) | voir BASE-OBJ-01, BASE-API-02 |
| `pop_tablet:dispatchAlert` (écouté) | scripts tiers → dispatch | même format que `DispatchAlert` |
| exports et événements de ps-dispatch, cd_dispatch, core_dispatch, esx_service (repris) | adaptateurs `bridge/dispatch/` (BASE-API-11) | convertis au format `DispatchAlert` |

Exports publics (anglais) : `GetPlayer`, `GetPlayerByIdentifier`, `IsOnDuty`, `SetDuty`, `CountOnDuty`, `GetWeeklyHours`, `HasAccess`, `HasPermission`, `RegisterApp`, `UnregisterApp`, `RegisterAction`, `OpenScreen`, `Open`, `Notify`, `Log`, `DataGet` / `DataSet` / `DataDelete` / `DataList`, `Pay`, `EmitSentence`, `OnSentence`, `EmitInvoicePaid`, `OnInvoicePaid`, `CreateInvoice`, `GetInvoice`, `DispatchAlert` (alias `PoliceAlert` = service police, `CreateEmsAlert` = service ems), `HasActiveWarrant`, `CasierAdd`, `SetCameraOnline`, `AddCamera`, `GetCertificate`, `CreateRequest`, `RegisterMigration`, `AddLocale`, `CompanyCreateFromJob`, `GetLimit`, `ResetTablet`, `ReplaceTablet`, `TransferTabletData`, `IsVehicleFlagged` (lecture : `{ signale, motif }`, jamais « volé »), `VerifyWarrantSignature`, `GetPropertyOwner`, `GetPropertiesOf`. `HasActiveWarrant` renvoie aussi `signe` (signé par un juge). **Aucun export `ReportStolen`** (supprimé, décision du client).

### 3.4 Noms internes uniques (Lua serveur)

| Nom unique | Autres écritures rencontrées dans les fiches (même fonction) |
|---|---|
| `Callback.*` (porte `pop_tablet:request`) | `lib.callback`, `PopTablet.Callback`, `PopCb` |
| `Sanitize.text(texte, max, multiline)` · `Sanitize.imageUrl(url)` | `Sanitize()`, `PopTablet.Sanitize.*` |
| `Log({ source, app, action, category, target, targetIdentifier, companyId, summary, before, after, level })` | `Journal.Ecrire` (02), `AdminLog` (04), RC8 (03), `PopTablet.Log.add` (05) |
| `Perm.Has(src, companyId, cle)` | `Perms.Has` (06) |
| `Notify.Send(cible, { app, titre, texte, action })` | `Notify(identifier, app, titre, texte)` (04), `Bridge.Notify` (01) |
| `RateLimit(src, cle)` | RC2 (03) |
| `WriteQueue.Push(sql, params)` | file d'écriture BASE-MOT-04 |
| `Bridge.Society.GetMoney / AddMoney / RemoveMoney(companyId, montant, motif)` | `Bridge.GetSocietyMoney / AddSocietyMoney / RemoveSocietyMoney(job, montant)` (01) : la version par entreprise appelle la version par job avec `job_name` (colonne renommée : anciennement `esx_job`) |
| `Bridge.HasTablet(src)` | `Bridge.HasItem(src, Config.Item.Name)` |
| `Bridge.OnPlayerDeath(cb)` / `Bridge.OnPlayerRevived(cb)` | `esx:onPlayerDeath` / `esx:onPlayerSpawn` écrits en dur, `ems:alert:down`, `Config.Bridge.EvenementMort` / `EvenementReveil` (anciens noms) |
| `Bridge.GetVehicles(identifier)` · `Bridge.FindPlate(plate)` | requêtes directes sur `owned_vehicles` (ESX) ou `player_vehicles` (QBCore / Qbox) |
| `Bridge.GetDirtyMoney / AddDirtyMoney / RemoveDirtyMoney(src, montant)` | `Bridge.RemoveMoney(src, 'black_money', …)`, `Config.Gang.Vault.Account` (ancien nom) |

### 3.5 Tables SQL (préfixe `pop_tablet_`, InnoDB, `utf8mb4`, `CREATE TABLE IF NOT EXISTS` + migrations BASE-MOT-17)

Identifiant d'entreprise partout : **`company_id INT` = `pop_tablet_companies.id`** (`gang_id` pour les tables de gang, même valeur). Dates : tables de 01 et 02 en `INT UNSIGNED` (Unix, `os.time()`) ; tables de 03 à 06 en `DATETIME` à l'heure du serveur (jamais UTC).

| Table(s) | Défini par | Rôle |
|---|---|---|
| `meta`, `devices` (+ colonne `disabled` : tablette remplacée), `notifications`, `appdata`, `logs`, `payments` | 01 (BASE-MOT-17) | technique (versions), tablettes (série, code, batterie, réglages), historique des notifications (50, 7 j), données d'apps par portée, **journal unique**, paiements |
| `ent_services` | 02 (ENT-GES-01) | **seule table de service** (lue par police, EMS, mécano, justice, planning, annuaire) |
| `ent_invitations`, `ent_permissions`, `ent_reglages`, `ent_mouvements`, `ent_annonces`, `ent_demandes` | 02 | recrutement, **droits par grade (toutes les clés de tous les fichiers)**, réglages d'entreprise, mouvements du compte, annonces, boîte Demandes unique |
| `factures`, `factures_evenements` | 02 | factures, amendes, honoraires, soins, devis acceptés |
| `companies`, `company_grades` | 05 (§0.4) | entreprises (slug, nom, `job_name`, briques), niveau de chaque grade (sans droits) |
| `sites`, `site_versions`, `site_visits`, `reports` | 05 | sites (`.rp`, type, description, caché, maintenance), versions, visites, signalements |
| `settings` | 05 | réglages modifiés par l'admin en jeu (limites, `defaults_installed`) — `meta` (01) reste réservé aux versions et données techniques |
| `cameras` | 05 (+ colonnes police `max_rotation`, `night_vision`, `online`) | **seule table des caméras fixes** (Admin et Police) |
| `police_*` (`agents`, `appels`, `citoyens`, `notes`, `vehicules`, `historique`, `rapports`, `rapport_liens`, `rapport_modeles`, `amendes`, `casier`, `mandats`, `avis`, `codepenal`, `annonces`, `annonces_lues`, `preuves`, `preuves_casiers`, `preuves_journal`, `formation_etapes`, `formation_suivi`, `permis_historique`, `saisies`, `avis_publics`, `infiltration_journal`) | 03 | MDT ; `police_mandats` est **la seule table de mandats** (Justice y écrit) |
| `ems_records`, `ems_records_history`, `ems_reports`, `report_templates`, `price_lists`, `ems_certificates`, `ems_alerts`, `appointments`, `ems_triage`, `ems_triage_victims` | 04 | EMS (rendez-vous créés à partir de la boîte Demandes) |
| `vehicle_logbook` (avec garantie), `quotes`, `mech_catalog` | 04 | mécano (carnet d'entretien simple, sans drapeau « volé ») |
| `justice_cases`, `justice_case_parties`, `justice_links`, `justice_hearings`, `justice_verdicts`, `justice_transmissions`, `justice_notes`, `justice_clients`, `justice_expunges`, `justice_contests`, `justice_deals` | 04 | justice |
| `gangs`, `gang_members`, `gang_ranks`, `gang_messages` (jamais purgée), `gang_vault_moves`, `gang_territories`, `gang_ledger` | 04 | gang (`gangs` = réglages du gang, clé `gang_id` = entreprise de modèle `gang`) |
| `immo_properties`, `immo_mutations`, `immo_sales` | 04 | immobilier (cadastre) |
| `notes`, `map_points`, `media`, `media_links`, `gallery`, `gallery_albums`, `nav_history`, `nav_favorites` | 06 | Outils et Navigateur (colonne `owner` = numéro de série) |
| `sheets`, `sheet_cells`, `sheet_imports`, `stock_items`, `stock_moves`, `planning_slots`, `planning_avail`, `planning_assign`, `planning_absences`, `connections` | 06 | Tableur, Stock, Planning (`connections` seulement si une entreprise utilise l'heure du jeu) |

### 3.6 Clés de config principales (globales)

| Clé | Défaut | Rôle |
|---|---|---|
| `Config.Item.Name` · `Config.Item.Metadata` | `'pop_tablet'` · `'auto'` | objet, mode métadonnées |
| `Config.Limits.NearDistance` | `3.0` m | « joueur proche » pour toute la tablette (factures, amendes, recrutement, partage, devis, soins) |
| `Config.Limits.PageSize` | `20` | pagination de toutes les listes |
| `Config.Limits.MaxAmount` | `100000` $ | plafond de tout paiement |
| `Config.RateLimit.Default` · `.Global` · `.MaxPerAction` · `.KickOnAbuse` | `{ n = 5, s = 10 }` · `{ n = 60, s = 10 }` · `{ n = 40, s = 10 }` · `false` | fréquence (format `{ n, s }` partout) ; une fiche peut fixer sa limite dans le plafond |
| `Config.Images.AllowedDomains` · `.Extensions` · `.UploadDomain` | `{ 'i.imgur.com', 'r2.fivemanage.com' }` · png, jpg, jpeg, webp, gif · `''` | images ; photos de la Galerie = `media:<id>` stockées sur le disque du serveur |
| `Config.Notify.Duration` · `.HistoryMax` · `.HistoryDays` | `4000` ms · `50` · `7` j | notifications |
| `Config.Lock.MaxFails` · `.LockSeconds` · `.MinLength` · `.MaxLength` | `5` · `300` (5 min) · `4` · `6` | code de verrouillage |
| `Config.Battery.*` | 120 min d'usage, recharge véhicule 30 min, chargeur 10 s | batterie |
| `Config.Storage.FlushInterval` · `.FlushMax` | `10` s · `200` | file d'écriture groupée (minuterie seulement si la file n'est pas vide) |
| `Config.Log.RetentionDays` · `Config.Discord.Categories` · `Config.Discord.Interval` | `0` (jamais effacé) · `{ admin, money, alert = true, police = false }` · `5` s | journal et Discord |
| `Config.Signals.SentenceJail` · `.SentenceEmitters` · `.InvoiceEmitters` | `'none'` · `{}` · `{}` | **seul réglage prison** (adaptateurs `bridge/jail/` : `esx_jail`, `qalle_jail`, `qb-prison`, `qbx_prison`, `rcore_prison`) |
| `Config.Dispatch.Compat` | `{ 'ps-dispatch', 'cd_dispatch', 'core_dispatch' }` | adaptateurs `bridge/dispatch/` chargés seulement si le vrai script n'est pas démarré ; `'esx_service'` en option (BASE-API-11) |
| `Config.Bridge.DeathEvent` · `.ReviveEvent` | `'auto'` · `'auto'` | mort et réveil détectés par le bridge pour le framework détecté (BASE-MOT-02) |
| `Config.Gang.DirtyMoney` | `'auto'` | ESX `{ type = 'account', name = 'black_money' }` ; QBCore / Qbox `{ type = 'item', name = 'markedbills' }` (valeur en métadonnées) |
| `Config.Police.EvidenceLocker` | `false` | casier à preuves physique dans le monde (MET-POL-38), optionnel |
| `Config.Police.Mandats.JugeRequis` | `{ 'perquisition', 'infiltration' }` | types de mandat qui exigent la signature d'un juge |
| `Config.Mechanic.Logbook.PoliceCanRead` | `false` | carnet d'entretien visible par la police (sinon : propriétaire et garages seulement) |
| `Config.Duty.SyncFrameworkDuty` | `true` | le métier n'est jamais basculé (pas de job `off…`) ; seul l'indicateur de service du framework suit la tablette (QBCore / Qbox `job.onduty`, ESX Legacy `onDuty`) |
| `Config.Framework` · `Config.SocietyAccount` | `'auto'` · `'auto'` | framework (`esx`, `qb`, `qbx`) et système de compte société détectés (BASE-MOT-02) |
| `Config.Service.Frequence` · `.DureeMax` | `10` s · `43200` s | prise de service (tous métiers) |
| `Config.Currency.Symbol` · `.Position` | `'$'` · `'after'` | montants entiers « 12 500 $ » |
| `Config.Sites.Suffix` | `'rp'` | extension des adresses (sites et navigateur) |
| `Config.Companies.CreateDefaults` | `true` | 7 entreprises par défaut |
| `Config.Police.Jobs` · `Config.EMS.Jobs` · `Config.Mechanic.Jobs` · `Config.Justice.Roles` · `Config.Gang.Source` | `{ 'police' }` · `{ 'ambulance' }` · `{ 'mechanic' }` · avocat/procureur/juge · `'tablet'` | rattachement des apps métier |
| `Config.Entreprises.Liste[<slug>]` | — | valeurs par défaut par entreprise (clé = `pop_tablet_companies.slug`), remplacées par `pop_tablet_ent_reglages` |

Les clés propres à une app (`Config.Factures.*`, `Config.Police.*`, `Config.EMS.*`, `Config.Sheets.*`…) restent celles écrites dans leur fiche.

### 3.7 Grille complète des droits (fusionnée)

Niveaux : Recrue (grade le plus bas du métier, ESX, QBCore ou Qbox), Membre / Chef (intermédiaires : moitié basse = Membre, moitié haute = Chef), Patron (grade le plus haut, a toujours tout). Le Patron règle chaque case dans Gestion > Droits (ENT-GES-18), stockée dans `pop_tablet_ent_permissions`. L'admin (`pop.tablet.admin`) a tout, journalisé.

| Clé | Libellé | Fichier | Recrue | Membre | Chef | Patron |
|---|---|---|---|---|---|---|
| `service` | Prendre son service | 02 | Oui | Oui | Oui | Oui |
| `facture.creer` | Faire une facture | 02 | Plafond 500 $ | Oui | Oui | Oui |
| `facture.voir_toutes` | Voir toutes les factures | 02 | Non | Non | Oui | Oui |
| `facture.regler` | Régler les factures (part, impayés) | 02 | Non | Non | Non | Oui |
| `demandes.repondre` | Répondre aux demandes | 02 | Non | Oui | Oui | Oui |
| `demandes.assigner` | Assigner les demandes | 02 | Non | Non | Oui | Oui |
| `annonce.publier` | Publier une annonce | 02 | Non | Non | Oui | Oui |
| `annonce.ville` | Annonce à toute la ville | 02 | Non | Non | Non | Oui |
| `compte.voir` | Voir le compte | 02 | Non | Non | Oui | Oui |
| `compte.mouvement` | Déposer / retirer | 02 | Non | Non | Non | Oui |
| `compte.prime` | Verser une prime | 02 | Non | Non | Non | Oui |
| `ventes.voir` | Historique des ventes | 02 | Non | Non | Oui | Oui |
| `employes.voir` | Voir les employés | 02 | Non | Non | Oui | Oui |
| `recruter` | Recruter | 02 | Non | Non | Oui | Oui |
| `membres.gerer` | Promouvoir / rétrograder / virer | 02 | Non | Non | Sous son grade | Oui |
| `grades.gerer` | Grades, salaires, droits | 02 | Non | Non | Non | Oui |
| `site.modifier` | Modifier le site (l'adresse : Patron seul) | 05 | Non | Non | Oui | Oui |
| `tableur.lire` · `stock.lire` | Lire tableur / stock | 06 | Non | Oui | Oui | Oui |
| `tableur.modifier` · `stock.modifier` | Modifier tableur / stock | 06 | Non | Non | Oui | Oui |
| `planning.voir` | Voir le planning | 06 | Oui | Oui | Oui | Oui |
| `planning.remplir` | Remplir le planning | 06 | Non | Non | Oui | Oui |
| `annuaire.fermer` | Fermer l'entreprise dans l'annuaire | 06 | Non | Non | Non | Oui |
| `police.service` · `police.appels` · `police.citoyens.lire` · `police.vehicules.lire` · `police.notes` · `police.vehicules.signaler` · `police.amende` (Recrue ≤ 2 500 $) · `police.rapport` · `police.casier.ajouter` · `police.preuves` · `police.saisie` | Terrain police | 03 | Oui | Oui | Oui | Oui |
| `police.unites.gerer` · `police.permis` · `police.mandat.creer` | Unités, permis, mandats | 03 | Non | Oui | Oui | Oui |
| `police.mandat.valider` · `police.annonce` · `police.heures.tous` · `police.preuves.gerer` · `police.cameras` · `police.camerapieton` · `police.formation.former` · `police.matricule` | Encadrement police | 03 | Non | Non | Oui | Oui |
| `police.avis.public` · `police.carte` · `police.infiltration` | Avis public, carte des crimes, lecture sous mandat d'infiltration | 03 | Non | Non | Oui | Oui |
| `police.rapport.modeles` · `police.casier.retirer` · `police.codepenal.modifier` · `police.formation.parcours` | Commandement police | 03 | Non | Non | Non | Oui |
| `ems.record.read` | EMS : lire dossier médical | 04 | Oui | Oui | Oui | Oui |
| `ems.record.write` · `ems.certificate.create` | EMS : écrire dossier, certificat d'aptitude | 04 | Non | Oui | Oui | Oui |
| `ems.certificate.death` · `ems.certificate.revoke` · `ems.hours.team` | EMS : décès, révocation, heures de l'équipe | 04 | Non | Non | Oui | Oui |
| `ems.template.edit` · `ems.prices.edit` | EMS : modèle de rapport, tarifs | 04 | Non | Non | Non | Oui |
| `meca.hours.team` | Mécano : heures de l'équipe | 04 | Non | Non | Oui | Oui |
| `justice.case.create` | Ouvrir une affaire | 04 | rôle procureur ou juge | | | |
| `justice.hearing.set` | Planifier une audience | 04 | rôle juge (ouvrable au procureur) | | | |
| Verdict | Prononcer un verdict | 04 | rôle juge seulement, non réglable | | | |
| Contestation de preuve · accord de repenti | Déposer / proposer · trancher / homologuer | 04 | avocat confirmé · procureur · juge (non réglable) | | | |
| `immo.cadastre.lire` | Consulter le cadastre | 04 | Oui | Oui | Oui | Oui |
| `immo.biens.gerer` · `immo.ventes` | Créer un bien, enregistrer une vente | 04 | Non | Oui | Oui | Oui |
| `immo.proprietaire.corriger` | Corriger le propriétaire enregistré | 04 | Non | Non | Oui | Oui |

Gang (rangs propres : Recrue, Soldat, Lieutenant, Chef ; table `pop_tablet_gang_ranks`) : voir membres, messagerie, déposer au coffre = tous ; voir le coffre = Soldat+ ; `gang.recruit` et retirer du coffre (plafond 10 000 $ par retrait) = Lieutenant et Chef ; exclure = Chef (Lieutenant sur les rangs inférieurs) ; `gang.settings` = Chef ; livre de comptes (lire, écrire) = Lieutenant et Chef ; retirer un message = son auteur seulement.

### 3.8 Constantes

| Sujet | Valeur |
|---|---|
| Proximité (argent, recrutement, partage) | 3 m (`Config.Limits.NearDistance`) ; envoi en prison 10 m ; caméra piéton 300 m (max 400) ; tablette posée : rangée au-delà de 30 m du propriétaire |
| Pagination | 20 par page ; recherche après 300 ms et 2 caractères |
| Fréquence | défaut 5 / 10 s par action ; global 60 / 10 s ; plafond par action 40 / 10 s |
| Anti double clic | `actionId` UUID v4 gardé 10 min |
| Batterie | 120 min ; recharge véhicule 30 min (vélos exclus) ; chargeur 10 s |
| Code | 4 à 6 chiffres, 5 erreurs → 5 min de blocage |
| Montants | entiers, max 100 000 $ par paiement ; facture Recrue 500 $ ; amende max 50 000 $ (Recrue 2 500 $) ; peine max 120 « mois » (1 mois = 1 min de prison) ; part employé 10 % (max 50 %) |
| Impayés | 72 h, mode par défaut « Rien », majoration unique 10 %, traités à la lecture |
| Annonces ville | 30 min par entreprise, 2 min pour toute la ville, gratuites, visibles 1 h |
| Demandes | 1 / 5 min par entreprise, 3 ouvertes max par demandeur |
| Mandats / avis | mandat 7 jours, 2 prolongations, demande expirée après 3 jours ; avis de recherche 3 jours |
| Sites | adresse 3 à 24 caractères + `.rp`, changeable 1 fois / 7 jours ; 5 pages, 30 blocs par page, 20 versions, 64 Ko |
| Tableur | 200 lignes × 26 colonnes, 20 feuilles (plafonds 1 000 / 26 / 100) |
| Notifications | bandeau 4 s, historique 50 / 7 jours |
| Gang | messages jamais effacés ; pagination 20 ; l'auteur peut retirer son message (archivé, visible par l'admin) |
| Infiltration (mandat) | défaut 72 h, max 168 h, 2 prolongations ; lecture à partir de la signature du juge seulement |
| Avis de recherche public | 24 h par défaut, max 72 h, 5 actifs max |
| Tri des blessés | 3 afflux ouverts max, 60 victimes par afflux, ajout à ≤ 10 m, fermeture automatique après 6 h |
| Garantie du garage | 0 à 90 jours |
| Accord de repenti | réduction 10 à 75 % (défaut 50 %), offre valable 1 à 72 h (défaut 24 h) |
| Inconscient | facture de soins annulée après 60 min sans réveil |

### 3.9 Textes d'erreur communs (clé `commun.erreur.<code>`, ton style Apple : neutre, vouvoiement si besoin)

`session` « La tablette a été fermée. Rouvrez-la pour continuer. » · `pas_tablette` « Tablette introuvable dans l'inventaire. » · `pas_droit` « Vous n'avez pas les droits nécessaires. » (+ bulle `commun.droit.grade_requis` « Grade requis : {grade} ») · `trop_vite` « Trop d'actions. Réessayez dans quelques secondes. » · `doublon` « Cette action a déjà été faite. » · `invalide` « Certaines informations ne sont pas valides. » · `trop_loin` « La personne est trop loin. » · `serveur` « Un problème est survenu. Réessayez dans un instant. » · `reseau` « Aucun réseau. » · `batterie` « Batterie vide. Rechargez la tablette. » · `hors_service` « Service requis pour utiliser cette app. » · `hors_ligne` « Cette personne n'est plus en ville. » · `trop_long` « Texte trop long : {max} caractères maximum. » · `champ_requis` « Champ requis : « {champ} ». » · `image` « Image refusée. Utilisez une photo de la galerie ou un lien d'un site autorisé. » · `introuvable` « Élément introuvable. Il a peut-être été archivé. » · `jeton_expire` « Fiche expirée. Relancez la recherche. » · `fonds_entreprise` « Le compte de l'entreprise n'a pas assez d'argent. » · `admin_requis` « Réservé aux administrateurs du serveur. » · `lecture_seule` « Lecture seule. ».

Textes d'écran communs (fiche 01 §0) : `commun.chargement.long`, `commun.bouton.reessayer`, `commun.succes`, `commun.succes.enregistre`, `commun.hors_service.titre` / `.bouton`, `commun.bouton.*`, `commun.pagination.*`, `commun.entreprise.archivee`.

---

## 4. Décisions par défaut consolidées

1. **Une seule porte d'entrée** `pop_tablet:request` ; anti double clic 10 min avec renvoi de la même réponse ; fréquence au format `{ n, s }`.
2. **Noms publics en anglais** : signaux (`sentencePronounced`, `invoicePaid`, `dutyChanged`…) et exports (`CreateInvoice`, `IsOnDuty`, `HasPermission`…). Anciens noms français et variantes supprimés des fiches.
3. **Banque** : compte société du framework détecté : ESX `esx_addonaccount` / `esx_society` ; QBCore `qb-banking` (v2) sinon `qb-management` ; Qbox `Renewed-Banking` sinon `qb-banking` (`Config.SocietyAccount = 'auto'`) ; aucun système trouvé → « Compte d'entreprise indisponible », le reste fonctionne. `pop_bank` n'expose aucun export : rien n'est branché ; adaptateur optionnel non fourni dans `bridge/bank/custom.lua`. Exports `GetSocietyBalance` & co retirés.
4. **Données perso = à la tablette** (numéro de série) pour tous les fichiers : code, réglages, notifications, notes, photos, favoris, historique, points de carte. Celui qui tient la tablette (vol, saisie) les voit ; perdues avec la tablette sauf remplacement par l'export `ReplaceTablet` / `TransferTabletData` (transfert, appelé par la boutique du serveur) ; effacées par la réinitialisation. Confirmé par le client. Exceptions : gang (au personnage), entreprise (à l'entreprise).
5. **Identifiant d'entreprise** = `pop_tablet_companies.id` (`company_id INT`) partout ; une entreprise peut ne pas être reliée à un métier ; colonne `pop_tablet_companies.job_name` (anciennement `esx_job`).
6. **Service** : une seule implémentation (ENT-GES-01 à 03), une seule table, le métier n'est jamais basculé, le framework (ESX, QBCore ou Qbox) paie les salaires ; seul l'indicateur de service du framework est synchronisé.
7. **Droits** : une seule grille (§ 3.7) dans `pop_tablet_ent_permissions` ; `droits.gerer` fusionné dans `grades.gerer`, `site.edit` renommé `site.modifier`.
8. **Mandats** : règles et table de la police (7 jours, 2 prolongations, attente 3 jours, validation Chef ou juge) ; l'app Justice est un deuxième écran.
9. **Prison** : signal seul ; un seul réglage `Config.Signals.SentenceJail` pour police et justice ; format de données unique.
10. **Stock jamais négatif** : il s'arrête à 0, le manque est noté et signalé (mécano compris).
11. **Zéro boucle** : aucune boucle permanente ; seules sont permises des minuteries ponctuelles déclenchées par un événement et arrêtées quand il n'y a plus rien à faire (file d'écriture, Discord, tablettes posées, rappels du Planning). Le Planning n'a plus de minuterie quotidienne fixe ; il n'y a plus de boutique dans la tablette (ni PNJ ni zone).
12. **Adresses de site en `.rp`** (`Config.Sites.Suffix`), 3 à 24 caractères, pour l'éditeur et le navigateur.
13. **Pas de boutique dans la tablette** (décision du client) : prix et vente de la tablette et du chargeur gérés par le script de boutique du serveur ; plus de PNJ, de prix, de `Config.Shop`, de table `pop_tablet_shops` ni d'onglet Admin. Réinitialisation par l'admin (commande et panneau) et par l'export `ResetTablet(serial)` ; remplacement / transfert de données par les exports `ReplaceTablet` et `TransferTabletData` (BASE-OBJ-08).
14. **Numéro de série** `PT-XXXX-XXXX` (base) pour l'admin, la saisie police et les exports.
15. **Images** : imgur et fivemanage seulement (liens Discord exclus car ils expirent) ; png, jpg, jpeg, webp, gif ; Galerie = `media:<id>`.
16. **Notifications** gardées 7 jours en base (50 max), bandeau 4 s.
17. **Textes trop longs refusés** côté serveur (`trop_long`), jamais coupés en silence ; la NUI bloque la saisie au-delà.
18. **Ton des textes : style Apple** (décision du client). Formulations neutres et courtes en priorité, sans sujet quand c'est possible (« Facture envoyée. », « Code incorrect. », « Aucune facture. ») ; **vouvoiement** quand une adresse directe est nécessaire (« Vous n'avez pas les droits nécessaires. ») ; jamais de tutoiement. Les fiches ont été converties ; tout nouveau texte suit cette règle.
19. **7 entreprises par défaut** : police, EMS, mécano, immobilier, concession, Tribunal, Cabinet d'avocats ; non reliées si le métier n'existe pas ; aucun gang par défaut. **Tribunal et Cabinet d'avocats** : l'assistant de premier démarrage les détecte (étape « Justice », BASE-MOT-15) et, s'ils n'existent pas, propose de créer le métier (présélectionné), de le relier à un métier existant ou de ne pas les utiliser ; le nom de métier retenu est gardé dans `pop_tablet_settings.justice_roles`.
20. **Caméras fixes** : une table et un écran de placement (Admin), la police ajoute aperçu, coupure et API.
21. **Tout dans la V1** : insertion de lignes/colonnes du tableur et réglages de site ajoutés ; les autres « pas en V1 » sont devenus des choix définitifs (pas de quiz de formation, pas de déplacement de bloc entre pages, catalogue de site non relié au stock, pas de code client Lua pour les apps perso).
22. **ESX, QBCore et Qbox au même niveau dès la sortie** (décision du client), testés à fond avec les mêmes critères d'acceptation, aucune version expérimentale : correspondance complète dans le bridge (BASE-MOT-02 : joueurs, métiers, grades, argent, comptes société, mort, notifications, création de métiers et de grades) ; métiers et grades créés dans la tablette sur QBCore / Qbox gardés dans `pop_tablet_company_grades` et réappliqués à chaque démarrage ; gang natif QBCore / Qbox utilisable (`Config.Gang.Source = 'gang'`). Pas de mode standalone : sans framework, la ressource s'arrête avec un message console.
23. **Créer ou supprimer un grade au milieu** : autorisé (confirmé par le client), avec un avertissement avant validation : « Les numéros des grades situés au-dessus vont changer. Les scripts qui utilisent ces numéros peuvent être affectés. » (`gestion.grades.avertissement_renumerotation`), bouton « Créer quand même » (ENT-GES-14, ENT-GES-17).
24. **Messages de gang jamais effacés** (décision du client, 24/11/2026) : plus de délai ni de purge ; l'auteur peut retirer son message (archivé, visible par l'admin seulement) ; `MET-GANG-05` supprimée.
25. **Aucune fonction ne pénalise les biens des joueurs** (décision du client) : plus de drapeau, de détection ni d'alerte « véhicule volé », plus d'export `ReportStolen` ; carnet d'entretien simple (réparations, factures, garantie) visible par le propriétaire et les garages ; la police enregistre seulement une plainte écrite (`MET-POL-20`).
26. **Compatibilité dispatch** : adaptateurs `bridge/dispatch/` (ps-dispatch, cd_dispatch, core_dispatch par défaut ; esx_service en option) ; sans eux, le dispatch marche avec les appels manuels, la détresse, `/secours` et l'export `DispatchAlert` (`BASE-API-11`).
27. **Mort, réveil, véhicules, argent sale par le bridge** : `Bridge.OnPlayerDeath` / `OnPlayerRevived` (sans boucle), `Bridge.GetVehicles` / `FindPlate` (ESX `owned_vehicles`, QBCore / Qbox `player_vehicles`), `Config.Gang.DirtyMoney` détecté par framework (`BASE-MOT-02`).
28. **Mandats signés et preuves recevables** : perquisition et infiltration exigent la signature d'un juge ; chaque preuve porte son cadre d'obtention et une recevabilité calculée par le serveur (« Irrecevable » sans mandat valide) ; chaîne de possession complète ; contestation tranchée par le juge (`MET-POL-29`, `MET-POL-36`, `MET-JUS-12`).
29. **Tout dans la tablette** : les éléments placés dans le monde sont optionnels et désactivés par défaut (casier à preuves physique, `Config.Police.EvidenceLocker = false`).
30. Les décisions propres à chaque fichier restent dans sa section « Décisions prises par défaut ».
31. Format d'alerte dispatch unique (fait foi sur MET-POL-13) : celui de BASE-API-10, champs `title` et `priority` (`high` / `normal` / `low`). L'export `PoliceAlert` accepte aussi `titre` et `priorite` 1 / 2 / 3, convertis en `high` / `normal` / `low`.

## 5. Points à faire confirmer par le client

Tranchés par le client le 24/11/2026 et appliqués dans toutes les fiches : pas de boutique dans la tablette, ton style Apple (neutre, vouvoiement si besoin), ESX / QBCore / Qbox au même niveau, grade au milieu avec avertissement, Tribunal et Cabinet détectés par l'assistant, notes et photos liées à la tablette.

1. **Couleur d'accent** : bleu `#4FA3FF` validé par le client (24/11/2026), réglable par le serveur.
2. **Messages de gang** : tranché par le client (24/11/2026) : jamais effacés, retrait par l'auteur = archivage visible par l'admin (`MET-GANG-04`).
3. **Comptes société sur QBCore / Qbox** : tranché par Claude (le produit est vendu à tous les serveurs) : détection automatique du premier système trouvé (`qb-banking`, sinon `qb-management` ; sur Qbox `Renewed-Banking`, sinon `qb-banking`), les trois testés.
4. **Indicateur de service du framework** : tranché par Claude : `Config.Duty.SyncFrameworkDuty = true` par défaut.
5. **Lecture du carnet d'entretien par la police** : tranché par Claude : désactivée par défaut (`Config.Mechanic.Logbook.PoliceCanRead = false`), réglable.
6. **Signalement « recherché » d'une plaque** (`MET-POL-20`) : tranché par Claude : gardé (manuel, sans effet sur le véhicule, visible seulement dans l'app Police).
7. **Perquisition et infiltration** : tranché par Claude : signature d'un juge obligatoire **si au moins un juge est en service** ; sinon un Chef police (niveau Chef) peut valider seul, et le mandat est marqué « Validé sans juge » (visible par les juges et l'avocat). Réglage `Config.Police.Mandats.JugeRequis = { 'perquisition', 'infiltration' }` et `Config.Police.Mandats.SansJugeSiAucunEnService = true`. Raison : un serveur sans juge connecté ne doit pas bloquer la police.

Il ne reste aucun point ouvert côté client.

### Valeurs techniques à vérifier pendant le développement (non vérifiables sans les scripts installés)

| Sujet | Valeur écrite dans les fiches | À vérifier |
|---|---|---|
| Adaptateur prison Qbox | `'qbx_prison'` (`bridge/jail/qbx_prison.lua`) | nom exact de la ressource de prison Qbox utilisée et son événement / export d'envoi en prison |
| Mort / réveil Qbox | state bag `isDead` posé par qbx_medical ; `QBCore:Player:SetPlayerData` émis côté client par qbx_core | nom exact du state bag et émission de l'événement de compatibilité dans la version de qbx_core / qbx_medical installée |
| Mort / réveil QBCore | `hospital:server:SetDeathStatus`, `hospital:server:SetLaststandStatus` (qb-ambulancejob) | noms dans la version installée |
| ps-dispatch | exports client `CustomAlert` + alertes prêtes (`StoreRobbery`, `VehicleShooting`…), événement `ps-dispatch:server:notify`, champs `dispatchCode`, `message`, `jobs` (`leo`, `ems`) | liste et champs de la version installée (v2) |
| cd_dispatch | événement `cd_dispatch:AddNotification` (`job_table`, `coords`, `title`, `message`, `flash`, `blip`), export client `GetPlayerInfo` | format de la version installée |
| core_dispatch | export client `addCall(code, title, extraInfo, coords, job, cooldown, sprite, color)`, événement `core_dispatch:addCall` | ordre et noms des arguments |
| esx_service | rappels `esx_service:isInService`, `esx_service:getInServiceList`, événements `esx_service:activateService` / `disableService` | noms dans la version d'esx_service utilisée |
| Argent sale QBCore / Qbox | objet `markedbills`, valeur `info.worth` (qb-inventory) ou `metadata.worth` (ox_inventory) | clé de valeur sur le serveur du client |
| Véhicules Qbox | table `player_vehicles` (qbx_vehicles), colonnes `plate`, `vehicle`, `citizenid`, `state` | colonnes de la version installée |
