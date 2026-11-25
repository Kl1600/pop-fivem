-- pop_ems : objet à ajouter dans pop_inventory/config/items_2.lua.
-- Copiez la ligne `bandage = { ... },` (sans le `return {` ni la dernière accolade) dans la table des objets.
-- 'kitsoins' existe déjà dans items_2.lua et 'defib' dans items_1.lua : rien à ajouter pour eux.
-- Non utilisable seul : il s'emploie via le menu de soins EMS.
-- Image : copier install/images/bandage.webp dans le dossier img/ de pop_inventory.

return {
    bandage = { label = 'Bandage', weight = 0.1, maxStack = 10, icon = 'img/bandage.webp', tags = { 'ems', 'medical' }, gradientColor = 'rgba(50, 230, 50, 0.4)' },
}
