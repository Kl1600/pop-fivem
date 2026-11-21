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
