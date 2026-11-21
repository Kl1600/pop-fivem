Config = {}

-- Commande principale (sous-commandes : create / invite / accept / decline / leave / disband / info)
Config.Command   = 'crew'

-- Longueur max du tag (name) et du label affiché
Config.MaxTagLen   = 12   -- identifiant court unique, ex: "BLLS"
Config.MaxLabelLen = 32   -- nom affiché, ex: "Ballas"

-- Couleur par défaut d'un crew { r, g, b } (utilisée par pop_territories pour colorer la map)
Config.DefaultColor = { 200, 70, 190 }
