# POP FiveM

Scripts FiveM POP : sobres, simples, compatibles ESX / QBCore / Qbox / standalone, disponibles en 10 langues.

## Structure
```
resources/[pop]/       les scripts (un dossier pop_<nom> par script)
docs/                  direction artistique et méthode
.claude/agents/        consignes des agents Claude
.github/workflows/     déploiement automatique sur le serveur de test
```

## Serveur de test (OuiHeberg)

### Mise en place (une seule fois)
1. Crée la clé de licence gratuite sur https://portal.cfx.re
2. Commande l'offre FiveM Start (Marseille), colle la clé dans `FIVEM_LICENSE`, active txAdmin.
3. Dans txAdmin, installe une recette (ex. QBCore, ESX ou Qbox) avec la base MariaDB du panel.
4. Ajoute ton associé comme sous-utilisateur dans le panel.
5. Dans le panel, note les accès SFTP (hôte, port, identifiant, mot de passe).
6. Sur GitHub : **Settings > Secrets and variables > Actions > New repository secret**, crée :
   | Nom | Valeur |
   |---|---|
   | `SFTP_HOST` | adresse SFTP du panel |
   | `SFTP_PORT` | port SFTP du panel |
   | `SFTP_USER` | identifiant SFTP |
   | `SFTP_PASSWORD` | mot de passe SFTP |
   | `SFTP_REMOTE_PATH` | dossier `resources/[pop]` du serveur (chemin vu en SFTP) |
7. Dans `server.cfg`, ajoute la ligne `ensure [pop]`.

### Au quotidien
1. Un script est poussé sur `main`.
2. GitHub l'envoie tout seul sur le serveur (onglet **Actions** pour suivre).
3. Dans la console txAdmin : `refresh` puis `ensure pop_<nom>` (ou `restart pop_<nom>`).
