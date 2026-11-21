-- pop_crew : tables (créées aussi automatiquement au démarrage de la ressource ; import facultatif).

CREATE TABLE IF NOT EXISTS `pop_crews` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name`       VARCHAR(32)  NOT NULL,
    `color`      CHAR(7)      NOT NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_pop_crews_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_crew_members` (
    `id`         INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `crew_id`    INT UNSIGNED     NOT NULL,
    `identifier` VARCHAR(64)      NOT NULL,
    `name`       VARCHAR(64)      NOT NULL DEFAULT '',
    `rank`       TINYINT UNSIGNED NOT NULL,
    `joined_at`  TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_pop_crew_members_identifier` (`identifier`),
    KEY `idx_pop_crew_members_crew` (`crew_id`),
    CONSTRAINT `fk_pop_crew_members_crew` FOREIGN KEY (`crew_id`) REFERENCES `pop_crews` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
