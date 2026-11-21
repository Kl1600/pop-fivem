-- POP FiveM : toutes les tables des scripts POP en un seul import.
-- Sans risque à relancer : chaque table utilise CREATE TABLE IF NOT EXISTS.
-- Importer APRES le SQL du framework (ESX / QBCore / Qbox), dans la même base.

-- ===== pop_admin =====
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

-- ===== pop_affiche =====
CREATE TABLE IF NOT EXISTS `pop_affiche_surfaces` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `owner` VARCHAR(96) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `nx` DOUBLE NOT NULL,
    `ny` DOUBLE NOT NULL,
    `nz` DOUBLE NOT NULL,
    `revision` INT UNSIGNED NOT NULL DEFAULT 1,
    `content` VARCHAR(1024) NOT NULL,
    PRIMARY KEY (`id`)
);

-- ===== pop_bank =====
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

-- ===== pop_boards =====
CREATE TABLE IF NOT EXISTS `pop_boards_surfaces` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `owner` VARCHAR(96) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `nx` DOUBLE NOT NULL,
    `ny` DOUBLE NOT NULL,
    `nz` DOUBLE NOT NULL,
    `revision` INT UNSIGNED NOT NULL DEFAULT 1,
    `content` TEXT NOT NULL,
    PRIMARY KEY (`id`)
);

-- ===== pop_charcreator =====
CREATE TABLE IF NOT EXISTS pop_charcreator_profiles (
    identifier VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
    profile LONGTEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===== pop_clothes =====
CREATE TABLE IF NOT EXISTS pop_clothes_outfits (
    identifier VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
    model VARCHAR(8) NOT NULL,
    selections LONGTEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, model)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===== pop_crew =====
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

-- ===== pop_doorlock =====
-- pop_doorlock : groupes de portes et portes.
-- Facultatif : la ressource crée aussi ces tables au démarrage si elles n'existent pas.
-- L'état courant (verrouillé / déverrouillé) n'est pas stocké : chaque porte reprend `locked` de son groupe au démarrage.

CREATE TABLE IF NOT EXISTS `pop_doorlock_groups` (
  `id`       INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  `label`    VARCHAR(32)      NOT NULL,
  `locked`   TINYINT(1)       NOT NULL DEFAULT 1,   -- état au démarrage du serveur
  `distance` FLOAT            NOT NULL DEFAULT 2.0,
  `security` TINYINT UNSIGNED NOT NULL DEFAULT 2,   -- 0 crochetable, 1 difficile, 2 impossible
  `alert`    TINYINT(1)       NOT NULL DEFAULT 0,
  `jobs`     LONGTEXT         NULL,                 -- JSON {"police":0,"sheriff":2}, NULL = aucun
  `key_id`   VARCHAR(16)      NULL,                 -- NULL = pas de clé
  PRIMARY KEY (`id`),
  UNIQUE KEY `key_id` (`key_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `pop_doorlock_doors` (
  `id`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `group_id` INT UNSIGNED NOT NULL,
  `x`        FLOAT        NOT NULL,                 -- centre de la porte
  `y`        FLOAT        NOT NULL,
  `z`        FLOAT        NOT NULL,
  `leaves`   LONGTEXT     NOT NULL,                 -- JSON [{"model":123,"x":0.0,"y":0.0,"z":0.0}] (1 ou 2)
  PRIMARY KEY (`id`),
  KEY `group_id` (`group_id`),
  CONSTRAINT `pop_doorlock_doors_group` FOREIGN KEY (`group_id`)
    REFERENCES `pop_doorlock_groups` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===== pop_idcard =====
CREATE TABLE IF NOT EXISTS pop_idcard_documents (
    serial INT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner VARCHAR(80) COLLATE utf8mb4_bin NOT NULL,
    variant VARCHAR(8) COLLATE utf8mb4_bin NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    birth_date CHAR(10) NULL,
    sex VARCHAR(8) NULL,
    issued_at INT UNSIGNED NOT NULL,
    expires_at INT UNSIGNED NULL,
    PRIMARY KEY (serial),
    UNIQUE KEY owner_variant (owner, variant)
) DEFAULT CHARACTER SET utf8mb4;

-- ===== pop_inventory =====
-- pop_inventory : tables (aussi créées automatiquement au démarrage de la ressource).

CREATE TABLE IF NOT EXISTS `pop_inventory_players` (
  `identifier` VARCHAR(64) NOT NULL,
  `items`      LONGTEXT    NOT NULL,              -- JSON [{"slot":1,"name":"bread","count":2,"metadata":{...}}]
  `updated_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `pop_inventory_stashes` (
  `id`         VARCHAR(100) NOT NULL,             -- 'stash:police_locker', 'stash:police_locker:<identifier>', 'trunk:ABC123', 'glovebox:ABC123'
  `items`      LONGTEXT     NOT NULL,
  `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===== pop_kilometrage =====
-- pop_kilometrage : aussi créée automatiquement au démarrage de la ressource.
CREATE TABLE IF NOT EXISTS `pop_kilometrage` (
    `plate`      VARCHAR(8)   NOT NULL,
    `km`         DOUBLE       NOT NULL DEFAULT 0,
    `updated_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`plate`)
);

-- ===== pop_management =====
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

-- ===== pop_passport =====
CREATE TABLE IF NOT EXISTS pop_passport_documents (
    serial INT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner VARCHAR(80) COLLATE utf8mb4_bin NOT NULL,
    variant VARCHAR(8) COLLATE utf8mb4_bin NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    birth_date CHAR(10) NULL,
    sex VARCHAR(8) NULL,
    issued_at INT UNSIGNED NOT NULL,
    expires_at INT UNSIGNED NULL,
    PRIMARY KEY (serial),
    UNIQUE KEY owner_variant (owner, variant)
) DEFAULT CHARACTER SET utf8mb4;

-- ===== pop_police =====
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

-- ===== pop_territories =====
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

-- ===== pop_vehiclepersistence =====
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

-- ===== pop_weed =====
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

