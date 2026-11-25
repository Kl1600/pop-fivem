-- ESX (inventaire de base) : objets de la table `items`.
-- Note : l'inventaire de base d'ESX ne garde pas les métadonnées ; la carte affiche alors
-- celle du joueur qui l'utilise. Avec ox_inventory, utiliser install/items_ox.lua.
INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
    ('idcard', 'ID card', 1, 0, 1),
    ('idcard_mx', 'Credencial INE', 1, 0, 1);
