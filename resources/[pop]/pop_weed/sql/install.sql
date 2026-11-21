-- pop_weed : table créée automatiquement au démarrage de la ressource (aucune action manuelle requise).

CREATE TABLE IF NOT EXISTS `pop_weed_plants` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `owner`      VARCHAR(64)  NOT NULL,
    `x`          FLOAT        NOT NULL,
    `y`          FLOAT        NOT NULL,
    `z`          FLOAT        NOT NULL,
    `heading`    FLOAT        NOT NULL DEFAULT 0,
    `planted_at` INT UNSIGNED NOT NULL,
    `water`      FLOAT        NOT NULL DEFAULT 0,
    `water_at`   INT UNSIGNED NOT NULL,
    `dry`        INT UNSIGNED NOT NULL DEFAULT 0,
    `fertilized` TINYINT(1)   NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_owner` (`owner`)
);

-- ESX uniquement (inventaire du framework), à décommenter si besoin :
-- INSERT IGNORE INTO `items` (`name`, `label`, `weight`) VALUES
--   ('weed_pot', 'Pot', 1), ('weed_seed', 'Cannabis seed', 1), ('water_bottle', 'Water bottle', 1),
--   ('weed_fertilizer', 'Fertilizer', 1), ('weed', 'Weed', 1);
