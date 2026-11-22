-- Bourse : symboles fictifs et bornes de la simulation (marche aléatoire, serveur). Aucune donnée réelle.
-- `price` : cours de base (la simulation reste entre 5 % et 10 fois ce cours) ; `vol` : volatilité par pas ;
-- `ch` : variations indicatives en % sur 1 semaine, 1 mois, 3 mois, 1 an, 5 ans (la variation du jour est calculée).
-- vol (millions de titres), cap (milliards de $), per, div (%) : chiffres clés fictifs, nil = sans objet.

Tablet = Tablet or {}

Tablet.StockBounds = { min = 0.05, max = 10 }
Tablet.StockPersistSeconds = 600
Tablet.StockMaxShock = 50

Tablet.StockDefs = {
    { sym = 'BAWS', name = 'Bawsaq', index = true, price = 11842.3, vol = 0.0012, volume = 1800.0, ch = { 0.9, 2.2, 4.1, 9.3, 55 } },
    { sym = 'MAZE', name = 'Maze Bank', price = 412.6, vol = 0.0030, volume = 4.2, cap = 86.4, per = 14.2, div = 2.1, ch = { 3.1, 5.4, 9.8, 22.5, 140 } },
    { sym = 'FLCA', name = 'Fleeca Bank', price = 87.35, vol = 0.0030, volume = 2.9, cap = 21.7, per = 11.8, div = 3.4, ch = { -1.2, 0.8, -3.4, 6.1, 35 } },
    { sym = 'LIFI', name = 'LifeInvader', price = 156.2, vol = 0.0050, volume = 9.6, cap = 54.0, per = 32.5, ch = { 6.5, -2.1, 14, 48, 310 } },
    { sym = 'PISS', name = 'Pisswasser', price = 64.8, vol = 0.0030, volume = 3.1, cap = 12.3, per = 17.0, div = 4.8, ch = { -0.3, -4.8, -7.9, -12.6, -20 } },
    { sym = 'AMMU', name = 'Ammu-Nation', price = 203.45, vol = 0.0030, volume = 1.4, cap = 29.8, per = 19.4, div = 1.6, ch = { 1.7, 3.3, 5.2, 11.4, 60 } },
    { sym = 'VAPD', name = 'Vapid Motors', price = 98.1, vol = 0.0040, volume = 5.5, cap = 33.2, per = 9.7, div = 2.9, ch = { 2.4, 7.7, 12.3, 30.2, 85 } },
}

Tablet.StockIndex = {}
for i, d in ipairs(Tablet.StockDefs) do Tablet.StockIndex[d.sym] = i end
