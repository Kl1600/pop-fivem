-- pop_crew : these tables are also created automatically when the resource starts.
-- (Ces tables sont aussi créées automatiquement au démarrage de la ressource.)

CREATE TABLE IF NOT EXISTS `crews` (
    `id`         INT AUTO_INCREMENT PRIMARY KEY,
    `name`       VARCHAR(16) NOT NULL UNIQUE,
    `label`      VARCHAR(32) NOT NULL,
    `owner`      VARCHAR(64) NOT NULL,
    `color`      VARCHAR(24) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `crew_members` (
    `identifier` VARCHAR(64) PRIMARY KEY,
    `crew_id`    INT NOT NULL,
    `rank`       VARCHAR(16) DEFAULT 'member',
    `name`       VARCHAR(64) DEFAULT NULL,
    `joined_at`  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
