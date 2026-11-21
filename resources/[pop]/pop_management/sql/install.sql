-- pop_management : tables created automatically at resource start.
-- Running this file manually is optional.
-- No framework table is created or altered.

CREATE TABLE IF NOT EXISTS `pop_management_accounts` (
    `society` VARCHAR(50)     NOT NULL,
    `balance` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`society`)
);

CREATE TABLE IF NOT EXISTS `pop_management_transactions` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `society`    VARCHAR(50)  NOT NULL,
    `type`       VARCHAR(16)  NOT NULL,
    `amount`     INT UNSIGNED NOT NULL,
    `actor`      VARCHAR(100) NOT NULL,
    `target`     VARCHAR(100) NULL DEFAULT NULL,
    `note`       VARCHAR(64)  NULL DEFAULT NULL,
    `created_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_society_time` (`society`, `created_at`)
);
