-- Lieux de Plans. Données fictives du RP : noms propres (non traduits), coordonnées du jeu à valider en jeu.
-- `x, y, z` : coordonnées du monde (SetNewWaypoint) ; `mx, my` : position sur la carte stylisée de l'interface (2000 x 1500).
-- `cat` : clé de catégorie (texte côté interface, `pla.cat_<cat>`) ; `hours` : 'always', 'h24' ou le numéro de l'heure de fermeture.
-- `Config.Places` (config.lua) ajoute ou remplace des lieux : même format, un `id` en [a-z0-9_].

Tablet = Tablet or {}

Tablet.MaxPlaces = 60

Tablet.Places = {
    { id = 'home', name = '', short = '', area = 'Vinewood', cat = 'home', addr = '3 Vinewood Hills Dr', phone = '(555) 0113', hours = 'always', icon = 'house', col = '#0a84ff', x = -174.0, y = 502.0, z = 137.0, mx = 1210, my = 560 },
    { id = 'police', name = 'Mission Row Police Station', short = 'Police', area = 'Mission Row', cat = 'public', addr = '1 Sinner St, Mission Row', phone = '(555) 0100', hours = 'h24', icon = 'shield', col = '#30509c', x = 441.0, y = -982.0, z = 30.7, mx = 1090, my = 790 },
    { id = 'garage', name = 'La Mesa Garage', short = 'Garage', area = 'La Mesa', cat = 'garage', addr = '27 Popular St, La Mesa', phone = '(555) 0127', hours = '19', icon = 'wrench', col = '#ff8d28', x = 727.0, y = -1088.0, z = 22.2, mx = 1330, my = 930 },
    { id = 'pillbox', name = 'Pillbox Hospital', short = 'Hospital', area = 'Pillbox Hill', cat = 'hospital', addr = '8 Strawberry Ave', phone = '(555) 0112', hours = 'h24', icon = 'cross', col = '#ff383c', x = 298.0, y = -584.0, z = 43.3, mx = 1150, my = 700 },
    { id = 'fleeca', name = 'Fleeca Bank, Legion Square', short = 'Fleeca', area = 'Legion Square', cat = 'bank', addr = '4 Legion Square', phone = '(555) 0150', hours = '17', icon = 'bank', col = '#34c759', x = 149.0, y = -1040.0, z = 29.4, mx = 1020, my = 700 },
    { id = 'casino', name = 'Diamond Casino', short = 'Casino', area = 'Vinewood', cat = 'casino', addr = '1 Diamond Blvd', phone = '(555) 0199', hours = 'h24', icon = 'casino', col = '#cb30e0', x = 925.0, y = 46.0, z = 81.1, mx = 1520, my = 640 },
    { id = 'pier', name = 'Del Perro Pier', short = 'Pier', area = 'Del Perro', cat = 'tourist', addr = 'Del Perro Beach', phone = '(555) 0160', hours = 'always', icon = 'pier', col = '#00c0e8', x = -1850.0, y = -1230.0, z = 13.0, mx = 640, my = 760 },
    { id = 'customs', name = 'Los Santos Customs', short = 'Customs', area = 'La Mesa', cat = 'garage', addr = '12 Power St', phone = '(555) 0188', hours = '20', icon = 'wrench', col = '#ff8d28', x = -365.0, y = -131.0, z = 38.7, mx = 1250, my = 800 },
    { id = 'cafe', name = 'Vinewood Cafe', short = 'Cafe', area = 'Vinewood', cat = 'cafe', addr = '19 Vinewood Blvd', phone = '(555) 0131', hours = '23', icon = 'cup', col = '#a2845e', x = 291.0, y = 180.0, z = 104.0, mx = 1130, my = 540 },
}

--- Position approximative du joueur sur la carte stylisée (2000 x 1500) : transformation affine calée sur les lieux.
function Tablet.MapPoint(x, y)
    local mx = 1090 + (x - 441.0) * 0.17
    local my = 790 - (y + 982.0) * 0.17
    return math.max(60, math.min(1940, math.floor(mx + 0.5))), math.max(60, math.min(1440, math.floor(my + 0.5)))
end
