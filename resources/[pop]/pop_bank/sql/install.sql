-- pop_bank : historique des opérations (créé aussi automatiquement au démarrage).
CREATE TABLE IF NOT EXISTS `pop_bank_transactions` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64)  NOT NULL,
    `type`       VARCHAR(16)  NOT NULL,
    `amount`     INT UNSIGNED NOT NULL,
    `balance`    BIGINT       NOT NULL DEFAULT 0,
    `other`      VARCHAR(64)  NULL DEFAULT NULL,
    `created_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_identifier_time` (`identifier`, `created_at`)
);
