Config = {}

-- Modèle de Ped par défaut pour les PNJ du bureau de change
Config.PedModel = "s_m_m_cntrybar_01"

-- Taux de change
Config.Rates = {
    UsdToPesos = 20.0, -- 1 Dollar ($) donne 20 Pesos (₱)
    PesosToUsd = 0.045 -- 1 Peso (₱) donne 0.045 Dollar ($) (soit environ 22.2 Pesos pour 1 Dollar)
}

-- Emplacements des bureaux de change
Config.Locations = {
    {
        coords = vec3(-639.0726, -180.4707, 37.6832), -- Près de la bijouterie / zone centrale
        heading = 33.0,
        name = "Bureau de change principal",
        blip = {
            enabled = true,
            sprite = 108, -- Dollar sign ($) instead of Biker Counterfeit Cash
            color = 2, -- Vert
            scale = 0.8,
            label = "Bureau de Change"
        }
    }
}

-- Paramètres de notification / textes
Config.Translate = {
    target_label = "Parler au changeur",
    menu_title = "BUREAU DE CHANGE",
    buy_pesos = "Acheter des Pesos",
    buy_dollars = "Acheter des Dollars",
    exchange_success = "Transaction réussie !",
    exchange_failed = "Transaction échouée.",
    not_enough_money = "Vous n'avez pas assez d'argent.",
    invalid_amount = "Montant invalide.",
}
