-- pop_ems : objets pour ESX (table `items`). INSERT IGNORE : sans effet si l'objet existe déjà.
INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
    ('bandage', 'Bandage', 1, 0, 1),
    ('kitsoins', 'Kit de soins', 1, 0, 1),
    ('defib', 'Défibrillateur', 3, 0, 1);
