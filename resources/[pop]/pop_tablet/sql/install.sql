-- pop_tablet : tables (section 5 de SPEC.md). MariaDB 10.5+ / MySQL 8, InnoDB, utf8mb4.
-- Exécuté automatiquement au premier démarrage (server/db.lua) ; peut aussi être lancé à la main.
-- Dates : BIGINT = secondes epoch serveur ; colonnes game_* = date du jeu 'AAAA-MM-JJ HH:MM'.
-- Chaque instruction se termine par un point-virgule en fin de ligne (le découpage s'appuie dessus).

CREATE TABLE IF NOT EXISTS `pop_tablet_devices` (
  `serial`       CHAR(13)        NOT NULL,
  `phone`        CHAR(8)         NOT NULL,
  `code_hash`    CHAR(64)        NULL,
  `code_salt`    CHAR(16)        NOT NULL DEFAULT '',
  `fails`        TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `locked_until` BIGINT          NOT NULL DEFAULT 0,
  `name`         VARCHAR(32)     NOT NULL DEFAULT '',
  `settings`     JSON            NULL,
  `apps`         JSON            NULL,
  `battery`      TINYINT UNSIGNED NOT NULL DEFAULT 100,
  `battery_at`   BIGINT          NOT NULL DEFAULT 0,
  `owner_hint`   VARCHAR(64)     NULL,
  `created_at`   BIGINT          NOT NULL DEFAULT 0,
  `last_open_at` BIGINT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`serial`),
  UNIQUE KEY `uq_tablet_phone` (`phone`),
  KEY `idx_tablet_owner` (`owner_hint`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_tablet_mailboxes` (
  `address` VARCHAR(80) NOT NULL,
  `serial`  CHAR(13)    NOT NULL,
  PRIMARY KEY (`address`),
  UNIQUE KEY `uq_mailbox_serial` (`serial`),
  CONSTRAINT `fk_mailboxes_device` FOREIGN KEY (`serial`) REFERENCES `pop_tablet_devices` (`serial`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_tablet_note_folders` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `serial`     CHAR(13)        NOT NULL,
  `name`       VARCHAR(40)     NOT NULL DEFAULT '',
  `created_at` BIGINT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_note_folders_serial` (`serial`),
  CONSTRAINT `fk_note_folders_device` FOREIGN KEY (`serial`) REFERENCES `pop_tablet_devices` (`serial`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- body = blocs JSON (texte, liste à cocher, tableau, photo) ; excerpt = 120 premiers caractères du texte ; deleted_at = corbeille.
CREATE TABLE IF NOT EXISTS `pop_tablet_notes` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `serial`     CHAR(13)        NOT NULL,
  `folder_id`  BIGINT UNSIGNED NULL,
  `title`      VARCHAR(80)     NOT NULL DEFAULT '',
  `excerpt`    VARCHAR(480)    NOT NULL DEFAULT '',
  `hint`       VARCHAR(8)      NOT NULL DEFAULT '',
  `body`       TEXT            NULL,
  `pinned`     TINYINT(1)      NOT NULL DEFAULT 0,
  `deleted_at` BIGINT          NULL,
  `updated_at` BIGINT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_notes_serial` (`serial`, `deleted_at`, `pinned`, `updated_at`),
  CONSTRAINT `fk_notes_device` FOREIGN KEY (`serial`) REFERENCES `pop_tablet_devices` (`serial`) ON DELETE CASCADE,
  CONSTRAINT `fk_notes_folder` FOREIGN KEY (`folder_id`) REFERENCES `pop_tablet_note_folders` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_tablet_events` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `serial`     CHAR(13)        NOT NULL,
  `title`      VARCHAR(80)     NOT NULL DEFAULT '',
  `place`      VARCHAR(80)     NOT NULL DEFAULT '',
  `notes`      VARCHAR(500)    NOT NULL DEFAULT '',
  `start_game` CHAR(16)        NOT NULL,
  `end_game`   CHAR(16)        NOT NULL,
  `all_day`    TINYINT(1)      NOT NULL DEFAULT 0,
  `alert_min`  SMALLINT        NULL,
  `color`      VARCHAR(9)      NOT NULL DEFAULT '',
  `notified`   TINYINT(1)      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_events_serial_start` (`serial`, `start_game`),
  CONSTRAINT `fk_events_device` FOREIGN KEY (`serial`) REFERENCES `pop_tablet_devices` (`serial`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_tablet_reminder_lists` (
  `id`     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `serial` CHAR(13)        NOT NULL,
  `name`   VARCHAR(40)     NOT NULL DEFAULT '',
  `color`  VARCHAR(9)      NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_rlists_serial` (`serial`),
  CONSTRAINT `fk_rlists_device` FOREIGN KEY (`serial`) REFERENCES `pop_tablet_devices` (`serial`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_tablet_reminders` (
  `id`       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `serial`   CHAR(13)        NOT NULL,
  `list_id`  BIGINT UNSIGNED NOT NULL,
  `title`    VARCHAR(120)    NOT NULL DEFAULT '',
  `done`     TINYINT(1)      NOT NULL DEFAULT 0,
  `due_game` CHAR(16)        NULL,
  `flag`     TINYINT(1)      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_reminders_serial_list` (`serial`, `list_id`),
  KEY `idx_reminders_due` (`serial`, `due_game`),
  CONSTRAINT `fk_reminders_device` FOREIGN KEY (`serial`) REFERENCES `pop_tablet_devices` (`serial`) ON DELETE CASCADE,
  CONSTRAINT `fk_reminders_list` FOREIGN KEY (`list_id`) REFERENCES `pop_tablet_reminder_lists` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_tablet_files` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `serial`      CHAR(13)        NOT NULL,
  `parent_id`   BIGINT UNSIGNED NULL,
  `kind`        ENUM('folder','doc','photo','audio','board') NOT NULL DEFAULT 'doc',
  `name`        VARCHAR(80)     NOT NULL DEFAULT '',
  `body`        TEXT            NULL,
  `ref_id`      BIGINT UNSIGNED NULL,
  `size`        INT UNSIGNED    NOT NULL DEFAULT 0,
  `share_token` CHAR(12)        NULL,
  `tag`         VARCHAR(8)      NULL,
  `fav`         TINYINT(1)      NOT NULL DEFAULT 0,
  `updated_at`  BIGINT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_files_share` (`share_token`),
  KEY `idx_files_serial_parent` (`serial`, `parent_id`),
  CONSTRAINT `fk_files_device` FOREIGN KEY (`serial`) REFERENCES `pop_tablet_devices` (`serial`) ON DELETE CASCADE,
  CONSTRAINT `fk_files_parent` FOREIGN KEY (`parent_id`) REFERENCES `pop_tablet_files` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_tablet_boards` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `serial`     CHAR(13)        NOT NULL,
  `title`      VARCHAR(80)     NOT NULL DEFAULT '',
  `strokes`    MEDIUMTEXT      NULL,
  `updated_at` BIGINT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_boards_serial` (`serial`, `updated_at`),
  CONSTRAINT `fk_boards_device` FOREIGN KEY (`serial`) REFERENCES `pop_tablet_devices` (`serial`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- data et thumb = texte base64 (data URI webp) : MEDIUMTEXT et non BLOB, oxmysql rend les BLOB sous forme de tableau d'octets.
-- kind = format de prise de vue ; fx = filtre d'affichage ; deleted_at = corbeille (30 jours).
CREATE TABLE IF NOT EXISTS `pop_tablet_photos` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `serial`     CHAR(13)        NOT NULL,
  `url`        VARCHAR(255)    NULL,
  `data`       MEDIUMTEXT      NULL,
  `thumb`      MEDIUMTEXT      NULL,
  `kind`       VARCHAR(8)      NOT NULL DEFAULT 'photo',
  `rating`     TINYINT         NOT NULL DEFAULT 0,
  `fx`         VARCHAR(8)      NOT NULL DEFAULT 'none',
  `w`          SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `h`          SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `place`      VARCHAR(80)     NOT NULL DEFAULT '',
  `taken_at`   BIGINT          NOT NULL DEFAULT 0,
  `favorite`   TINYINT(1)      NOT NULL DEFAULT 0,
  `deleted_at` BIGINT          NULL,
  PRIMARY KEY (`id`),
  KEY `idx_photos_serial` (`serial`, `deleted_at`, `taken_at`),
  CONSTRAINT `fk_photos_device` FOREIGN KEY (`serial`) REFERENCES `pop_tablet_devices` (`serial`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_tablet_albums` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `serial`     CHAR(13)        NOT NULL,
  `name`       VARCHAR(40)     NOT NULL DEFAULT '',
  `created_at` BIGINT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_albums_serial` (`serial`),
  CONSTRAINT `fk_albums_device` FOREIGN KEY (`serial`) REFERENCES `pop_tablet_devices` (`serial`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_tablet_photo_albums` (
  `album_id` BIGINT UNSIGNED NOT NULL,
  `photo_id` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`album_id`, `photo_id`),
  KEY `idx_photo_albums_photo` (`photo_id`),
  CONSTRAINT `fk_pa_album` FOREIGN KEY (`album_id`) REFERENCES `pop_tablet_albums` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_pa_photo` FOREIGN KEY (`photo_id`) REFERENCES `pop_tablet_photos` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_tablet_recordings` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `serial`     CHAR(13)        NOT NULL,
  `title`      VARCHAR(80)     NOT NULL DEFAULT '',
  `seconds`    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `url`        VARCHAR(255)    NULL,
  `data`       MEDIUMBLOB      NULL,
  `created_at` BIGINT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_recordings_serial` (`serial`, `created_at`),
  CONSTRAINT `fk_recordings_device` FOREIGN KEY (`serial`) REFERENCES `pop_tablet_devices` (`serial`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Messages et appels : liés aux numéros (pas au serial) ; une ligne par message, lue par les deux numéros.
CREATE TABLE IF NOT EXISTS `pop_tablet_messages` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `from_phone` CHAR(8)         NOT NULL,
  `to_phone`   CHAR(8)         NOT NULL,
  `body`       TEXT            NOT NULL,
  `kind`       ENUM('text','photo','contact','location') NOT NULL DEFAULT 'text',
  `ref`        VARCHAR(255)    NULL,
  `sent_at`    BIGINT          NOT NULL DEFAULT 0,
  `read_at`    BIGINT          NULL,
  PRIMARY KEY (`id`),
  KEY `idx_messages_to_unread` (`to_phone`, `read_at`),
  KEY `idx_messages_thread` (`from_phone`, `to_phone`, `id`),
  KEY `idx_messages_sent` (`sent_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_tablet_calls` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `from_phone`  CHAR(8)         NOT NULL,
  `to_phone`    CHAR(8)         NOT NULL,
  `started_at`  BIGINT          NOT NULL DEFAULT 0,
  `answered_at` BIGINT          NULL,
  `ended_at`    BIGINT          NULL,
  `status`      ENUM('missed','answered','declined','busy') NOT NULL DEFAULT 'missed',
  PRIMARY KEY (`id`),
  KEY `idx_calls_from` (`from_phone`, `id`),
  KEY `idx_calls_to` (`to_phone`, `id`),
  KEY `idx_calls_started` (`started_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_tablet_mails` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `serial`     CHAR(13)        NOT NULL,
  `folder`     ENUM('inbox','sent','trash','draft','flagged') NOT NULL DEFAULT 'inbox',
  `from_addr`  VARCHAR(80)     NOT NULL,
  `to_addr`    VARCHAR(80)     NOT NULL,
  `subject`    VARCHAR(120)    NOT NULL DEFAULT '',
  `body`       TEXT            NULL,
  `read_at`    BIGINT          NULL,
  `flagged`    TINYINT(1)      NOT NULL DEFAULT 0,
  `created_at` BIGINT          NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_mails_serial_folder` (`serial`, `folder`, `id`),
  CONSTRAINT `fk_mails_device` FOREIGN KEY (`serial`) REFERENCES `pop_tablet_devices` (`serial`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_tablet_contacts` (
  `id`       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `serial`   CHAR(13)        NOT NULL,
  `name`     VARCHAR(60)     NOT NULL,
  `phone`    VARCHAR(16)     NOT NULL DEFAULT '',
  `mail`     VARCHAR(80)     NULL,
  `note`     VARCHAR(200)    NULL,
  `favorite` TINYINT(1)      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_contacts_serial` (`serial`, `name`),
  CONSTRAINT `fk_contacts_device` FOREIGN KEY (`serial`) REFERENCES `pop_tablet_devices` (`serial`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pop_tablet_alarms` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `serial`      CHAR(13)        NOT NULL,
  `kind`        ENUM('alarm','timer') NOT NULL DEFAULT 'alarm',
  `label`       VARCHAR(40)     NOT NULL DEFAULT '',
  `game_minute` SMALLINT        NULL,
  `repeat_mask` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `ends_at`     BIGINT          NULL,
  `enabled`     TINYINT(1)      NOT NULL DEFAULT 1,
  `sound`       VARCHAR(32)     NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `idx_alarms_serial` (`serial`, `kind`),
  KEY `idx_alarms_ends` (`ends_at`),
  CONSTRAINT `fk_alarms_device` FOREIGN KEY (`serial`) REFERENCES `pop_tablet_devices` (`serial`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Marché simulé : état persisté seulement toutes les 10 minutes avec abonnés, et à l'arrêt.
CREATE TABLE IF NOT EXISTS `pop_tablet_market` (
  `symbol`     VARCHAR(8)    NOT NULL,
  `price`      DECIMAL(12,2) NOT NULL DEFAULT 0,
  `prev_close` DECIMAL(12,2) NOT NULL DEFAULT 0,
  `trend`      FLOAT         NOT NULL DEFAULT 0,
  `updated_at` BIGINT        NOT NULL DEFAULT 0,
  PRIMARY KEY (`symbol`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sites du Navigateur créés par d'autres ressources (peut rester vide).
CREATE TABLE IF NOT EXISTS `pop_tablet_sites` (
  `domain`         VARCHAR(60)  NOT NULL,
  `title`          VARCHAR(80)  NOT NULL DEFAULT '',
  `owner_resource` VARCHAR(64)  NOT NULL DEFAULT '',
  `page`           VARCHAR(120) NOT NULL DEFAULT '',
  PRIMARY KEY (`domain`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
