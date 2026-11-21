Config = {}

-- Prix de location (payé en item 'cash' pop_inventory)
Config.Price = 150

-- Points de location : partagés client/serveur (le serveur valide modèle + point de spawn)
Config.Locations = {
    -- Location 1 : LSX Bikerental (centre-ville)
    {
        spawnCoords = vector4(-512.2866, -251.1761, 34.7723, 202.7517),
        displayVehicles = {
            {
                model = 'ventoso',
                coords = vector4(-512.0535, -247.1877, 34.8154, 78.9902),
                label = 'Louer Ventoso (150$)'
            },
            {
                model = 'inductor',
                coords = vector4(-511.1458, -248.1631, 35.3218, 83.3264),
                label = 'Louer Vélo Inductor (150$)'
            }
        }
    },
    -- Location 2 : Vanguard Bikerental (Mexico)
    {
        spawnCoords = vector4(1882.6793, 3696.5371, 32.6095, 218.7509),
        displayVehicles = {
            {
                model = 'inductor',
                coords = vector4(1882.6793, 3696.5371, 32.6095, 218.7509),
                label = 'Louer Vélo (150$)'
            },
            {
                model = 'ventoso',
                coords = vector4(1883.6407, 3697.2202, 32.3260, 214.6081),
                label = 'Louer Ventoso (150$)'
            }
        }
    }
}
