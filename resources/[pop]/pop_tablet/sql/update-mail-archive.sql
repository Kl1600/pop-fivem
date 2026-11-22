-- Base déjà installée avant le dossier Archive du Mail : à lancer une fois (install.sql contient déjà la colonne à jour).
ALTER TABLE `pop_tablet_mails` MODIFY `folder` ENUM('inbox','sent','trash','draft','archive','flagged') NOT NULL DEFAULT 'inbox';
