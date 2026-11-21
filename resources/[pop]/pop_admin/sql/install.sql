CREATE TABLE IF NOT EXISTS `pop_admin_bans` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `license`       VARCHAR(64)  NOT NULL,
    `identifiers`   TEXT         NOT NULL,             -- JSON : tableau des identifiants du joueur (sans IP)
    `name`          VARCHAR(64)  NOT NULL,
    `reason`        VARCHAR(255) NOT NULL,
    `admin`         VARCHAR(64)  NOT NULL,             -- nom affiché de l'admin (ou 'System' / by)
    `admin_license` VARCHAR(64)  NULL DEFAULT NULL,
    `created_at`    INT UNSIGNED NOT NULL,
    `expires_at`    INT UNSIGNED NULL DEFAULT NULL,    -- NULL = permanent
    `active`        TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    KEY `idx_active` (`active`),
    KEY `idx_license` (`license`)
);

CREATE TABLE IF NOT EXISTS `pop_admin_warns` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `license`       VARCHAR(64)  NOT NULL,
    `name`          VARCHAR(64)  NOT NULL,
    `reason`        VARCHAR(255) NOT NULL,
    `admin`         VARCHAR(64)  NOT NULL,
    `admin_license` VARCHAR(64)  NULL DEFAULT NULL,
    `created_at`    INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_license` (`license`)
);
