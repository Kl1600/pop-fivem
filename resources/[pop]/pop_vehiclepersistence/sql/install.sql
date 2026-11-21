-- pop_vehiclepersistence (also created automatically on resource start)
CREATE TABLE IF NOT EXISTS `pop_vehiclepersistence` (
    `plate`   VARCHAR(8)   NOT NULL,
    `plate_text` VARCHAR(8) NULL, -- texte brut de la plaque (espaces compris)
    `owner`   VARCHAR(64)  NOT NULL,
    `model`   BIGINT       NOT NULL,
    `vtype`   VARCHAR(16)  NOT NULL DEFAULT 'automobile',
    `x`       FLOAT        NOT NULL,
    `y`       FLOAT        NOT NULL,
    `z`       FLOAT        NOT NULL,
    `heading` FLOAT        NOT NULL DEFAULT 0,
    `locked`  TINYINT(1)   NOT NULL DEFAULT 1,
    `props`   LONGTEXT     NULL,
    `seen`    INT UNSIGNED NOT NULL,
    PRIMARY KEY (`plate`),
    KEY `idx_owner` (`owner`)
);

-- Upgrade from an older version (also done automatically on resource start):
-- ALTER TABLE `pop_vehiclepersistence` ADD COLUMN `plate_text` VARCHAR(8) NULL AFTER `plate`;
