Config = {}

-- Commande debug/admin pour ouvrir le garage le plus proche.
Config.Command = 'entreprisegarage'

-- Touche d'ouverture quand on est dans la zone (38 = E).
Config.OpenKey = 38

-- Distance d'affichage du marker / texte d'aide.
Config.MarkerColor   = { 255, 46, 136 }
Config.DrawDistance  = 15.0

-- ─────────────────────────────────────────────────────────────────────────────
-- GARAGES ENTREPRISE
-- Chaque garage est réservé à un job ESX. Les véhicules sont une FLOTTE persistante
-- (table enterprise_garage_vehicles) : sortis du garage ils deviennent des véhicules
-- persistants gérés par pop_vehiclepersistence ; rangés, ils sont retirés du monde
-- et de la persistance jusqu'à la prochaine sortie.
--
--   job      = nom du job ESX autorisé
--   label    = nom affiché dans le menu
--   coords   = position du point d'interaction (marker)
--   spawn    = vector4 où les véhicules sortent (x,y,z,heading)
--   blip     = { sprite, color, scale } ou nil pour aucun blip
--   vehicles = flotte : une entrée = un véhicule { model = spawnName, label = nom }
-- ─────────────────────────────────────────────────────────────────────────────
Config.Garages = {
    {
        job    = 'police',
        label  = 'Garage LSPD',
        coords = vector3(454.6, -1017.4, 28.4),
        spawn  = vector4(438.6, -1018.6, 28.4, 90.0),
        blip   = { sprite = 357, color = 38, scale = 0.8 },
        vehicles = {
            { model = 'police',  label = 'Cruiser' },
            { model = 'police2', label = 'Buffalo' },
            { model = 'police3', label = 'Interceptor' },
            { model = 'policeb', label = 'Moto' },
        },
    },
    {
        job    = 'ambulance',
        label  = 'Garage EMS',
        coords = vector3(294.9, -574.6, 43.2),
        spawn  = vector4(294.6, -603.9, 43.1, 0.0),
        blip   = { sprite = 357, color = 1, scale = 0.8 },
        vehicles = {
            { model = 'ambulance', label = 'Ambulance' },
            { model = 'ambulance', label = 'Ambulance 2' },
        },
    },
}
