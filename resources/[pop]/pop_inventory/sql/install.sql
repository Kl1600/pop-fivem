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
