-- pop_doorlock : groupes de portes et portes.
-- Facultatif : la ressource crée aussi ces tables au démarrage si elles n'existent pas.
-- L'état courant (verrouillé / déverrouillé) n'est pas stocké : chaque porte reprend `locked` de son groupe au démarrage.

CREATE TABLE IF NOT EXISTS `pop_doorlock_groups` (
  `id`       INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  `label`    VARCHAR(32)      NOT NULL,
  `locked`   TINYINT(1)       NOT NULL DEFAULT 1,   -- état au démarrage du serveur
  `distance` FLOAT            NOT NULL DEFAULT 2.0,
  `security` TINYINT UNSIGNED NOT NULL DEFAULT 2,   -- 0 crochetable, 1 difficile, 2 impossible
  `alert`    TINYINT(1)       NOT NULL DEFAULT 0,
  `jobs`     LONGTEXT         NULL,                 -- JSON {"police":0,"sheriff":2}, NULL = aucun
  `key_id`   VARCHAR(16)      NULL,                 -- NULL = pas de clé
  PRIMARY KEY (`id`),
  UNIQUE KEY `key_id` (`key_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `pop_doorlock_doors` (
  `id`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `group_id` INT UNSIGNED NOT NULL,
  `x`        FLOAT        NOT NULL,                 -- centre de la porte
  `y`        FLOAT        NOT NULL,
  `z`        FLOAT        NOT NULL,
  `leaves`   LONGTEXT     NOT NULL,                 -- JSON [{"model":123,"x":0.0,"y":0.0,"z":0.0}] (1 ou 2)
  PRIMARY KEY (`id`),
  KEY `group_id` (`group_id`),
  CONSTRAINT `pop_doorlock_doors_group` FOREIGN KEY (`group_id`)
    REFERENCES `pop_doorlock_groups` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
