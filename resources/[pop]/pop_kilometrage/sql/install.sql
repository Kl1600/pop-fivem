-- pop_kilometrage : aussi créée automatiquement au démarrage de la ressource.
CREATE TABLE IF NOT EXISTS `pop_kilometrage` (
    `plate`      VARCHAR(8)   NOT NULL,
    `km`         DOUBLE       NOT NULL DEFAULT 0,
    `updated_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`plate`)
);
