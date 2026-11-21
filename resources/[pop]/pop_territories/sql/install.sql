-- pop_territories : import facultatif, le serveur crée aussi ces tables au démarrage.

CREATE TABLE IF NOT EXISTS `pop_territories` (
    `zone`       VARCHAR(32) NOT NULL,
    `crew`       VARCHAR(64) NOT NULL,              -- clé : 'crew:<id>' ou 'job:<name>'
    `influence`  FLOAT       NOT NULL DEFAULT 0,    -- 0 à 100
    `owner`      TINYINT(1)  NOT NULL DEFAULT 0,    -- 1 = propriétaire de la zone (au plus une ligne par zone)
    `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`zone`, `crew`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `pop_territories_crews` (
    `crew`       VARCHAR(64) NOT NULL,              -- même clé
    `label`      VARCHAR(32) NOT NULL,
    `color`      CHAR(7)     NOT NULL DEFAULT '#ffffff',
    `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`crew`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
