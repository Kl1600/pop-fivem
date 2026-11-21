CREATE TABLE IF NOT EXISTS `pop_police_citizens` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64)  NOT NULL,
    `name`       VARCHAR(100) NOT NULL,
    `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_identifier` (`identifier`),
    KEY `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `pop_police_notes` (
    `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizen_id`        INT UNSIGNED NOT NULL,
    `text`              VARCHAR(500) NOT NULL,
    `author`            VARCHAR(100) NOT NULL,
    `author_identifier` VARCHAR(64)  NOT NULL,
    `created_at`        INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_citizen` (`citizen_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `pop_police_fines` (
    `id`                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizen_id`         INT UNSIGNED NOT NULL,
    `amount`             INT UNSIGNED NOT NULL,
    `reason`             VARCHAR(100) NOT NULL,
    `status`             VARCHAR(16)  NOT NULL,   -- paid | refused | unpaid | expired
    `officer`            VARCHAR(100) NOT NULL,
    `officer_identifier` VARCHAR(64)  NOT NULL,
    `created_at`         INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_citizen` (`citizen_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ESX uniquement (inventaire du framework), à décommenter si besoin :
-- INSERT IGNORE INTO `items` (`name`, `label`, `weight`) VALUES ('handcuffs', 'Handcuffs', 1);
