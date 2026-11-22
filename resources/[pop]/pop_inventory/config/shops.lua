-- Boutiques et zones de boutique.

Config.Shops = {
  ["LTD"] = {
    { id = "bouteille", price = 40, label = "Bouteille d'eau", icon = "img/bouteille.webp" },
    { id = "hotdog", price = 50, label = "Hotdog", icon = "img/hotdog.webp" },
    { id = "jerry", price = 40, label = "Bidon d'essence", icon = "img/jerry.webp" },
    { id = "briefcase", price = 40, label = "Malette", icon = "img/briefcase.webp" },
    { id = "wallet", price = 40, label = "Portefeuille", icon = "img/wallet.webp" },
    { id = "pochon", price = 40, label = "Pochon", icon = "img/pochon.webp" },
    { id = "phone", price = 800, label = "Téléphone", icon = "img/phone.webp" },
    { id = "file", price = 800, label = "Dossier", icon = "img/file.webp" },
    { id = "notepad", price = 40, label = "Carnet", icon = "img/notepad.webp" },
  },
  ["24/7"] = {
    { id = "bouteille", price = 40, label = "Bouteille d'eau", icon = "img/bouteille.webp" },
    { id = "hotdog", price = 50, label = "Hotdog", icon = "img/hotdog.webp" },
    { id = "jerry", price = 40, label = "Bidon d'essence", icon = "img/jerry.webp" },
    { id = "briefcase", price = 40, label = "Malette", icon = "img/briefcase.webp" },
    { id = "wallet", price = 40, label = "Portefeuille", icon = "img/wallet.webp" },
    { id = "pochon", price = 40, label = "Pochon", icon = "img/pochon.webp" },
    { id = "phone", price = 800, label = "Téléphone", icon = "img/phone.webp" },
    { id = "file", price = 800, label = "Dossier", icon = "img/file.webp" },
  },
  ["ifruit"] = {
     { id = "phone", price = 1200, label = "iFruit 9ix", icon = "img/phone.webp" },
     { id = "sim_card", price = 150, label = "SIM iFruit Connect", icon = "img/sim_card.webp" },
  },

  ["vegatech"] = {
     { id = "cassette_duz_it", price = 150, label = "Cassette - Duz It", icon = "img/unknown.webp" },
     { id = "cassette_tnt", price = 150, label = "Cassette - TNT", icon = "img/unknown.webp" },
     { id = "cassette_bad_boys", price = 150, label = "Cassette - Bad Boys", icon = "img/unknown.webp" },
     { id = "cassette_smooth_criminal", price = 150, label = "Cassette - Smooth Criminal", icon = "img/unknown.webp" },
     { id = "cassette_cant_c_me", price = 150, label = "Cassette - Cant C Me", icon = "img/unknown.webp" },
     { id = "cassette_think_about_the_way", price = 150, label = "Cassette - Think About The Way", icon = "img/unknown.webp" },
     { id = "cassette_get_a_way", price = 150, label = "Cassette - Get A Way", icon = "img/unknown.webp" },
     { id = "walkman", price = 600, label = "Walkman", icon = "img/unknown.webp" },
  },

  ["BANK"] = {
     { id = "checkbook", price = 250, label = "Chéquier", icon = "img/checkbook.webp" },
  }
}


Config.ShopZones = {
    -- 24/7 Stores
    { id = 'SHOP_1', shopId = '24/7', label = '24/7', coords = vector3(372.6, 326.9, 103.5 + 1.0), radius = 3.5 },
    { id = 'SHOP_2', shopId = '24/7', label = '24/7', coords = vector3(2556.6, 380.8, 108.6 + 1.0), radius = 3.5 },
    { id = 'SHOP_3', shopId = '24/7', label = '24/7', coords = vector3(-3039.5, 584.3, 7.9 + 1.0), radius = 3.5 },
    { id = 'SHOP_4', shopId = '24/7', label = '24/7', coords = vector3(-3242.9, 1000.0, 12.8 + 1.0), radius = 3.5 },
    { id = 'SHOP_5', shopId = '24/7', label = '24/7', coords = vector3(549.1, 2670.8, 42.1 + 1.0), radius = 3.5 },
    { id = 'SHOP_6', shopId = '24/7', label = '24/7', coords = vector3(1959.8, 3740.4, 32.3 + 1.0), radius = 3.5 },
    { id = 'SHOP_7', shopId = '24/7', label = '24/7', coords = vector3(2677.4, 3279.7, 55.2 + 1.0), radius = 3.5 },
    { id = 'SHOP_8', shopId = '24/7', label = '24/7', coords = vector3(1728.0, 6415.6, 35.0 + 1.0), radius = 3.5 },
    { id = 'SHOP_9', shopId = '24/7', label = '24/7', coords = vector3(24.4, -1346.6, 29.5 + 1.0), radius = 3.5 },

    -- Robs Liquor (utilisent shopId LTD pour le moment)
    { id = 'SHOP_10', shopId = 'LTD', label = "Robs Liquor", coords = vector3(1134.2, -982.9, 46.4 + 1.0), radius = 3.5 },
    { id = 'SHOP_11', shopId = 'LTD', label = "Robs Liquor", coords = vector3(-1221.5, -908.1, 12.3 + 1.0), radius = 3.5 },
    { id = 'SHOP_12', shopId = 'LTD', label = "Robs Liquor", coords = vector3(-1486.5, -377.6, 40.1 + 1.0), radius = 3.5 },
    { id = 'SHOP_13', shopId = 'LTD', label = "Robs Liquor", coords = vector3(-2966.3, 391.4, 15.0 + 1.0), radius = 3.5 },
    { id = 'SHOP_14', shopId = 'LTD', label = "Robs Liquor", coords = vector3(1165.1, 2710.8, 38.1 + 1.0), radius = 3.5 },

    -- LTD Stores
    { id = 'SHOP_15', shopId = 'LTD', label = 'LTD', coords = vector3(-47.0, -1758.2, 29.4 + 1.0), radius = 3.5 },
    { id = 'SHOP_16', shopId = 'LTD', label = 'LTD', coords = vector3(1164.7, -322.9, 69.2 + 1.0), radius = 3.5 },
    { id = 'SHOP_17', shopId = 'LTD', label = 'LTD', coords = vector3(-706.0, -913.9, 19.2 + 1.0), radius = 3.5 },
    { id = 'SHOP_18', shopId = 'LTD', label = 'LTD', coords = vector3(-1820.0, 794.0, 138.0 + 1.0), radius = 3.5 },
    { id = 'SHOP_19', shopId = 'LTD', label = 'LTD', coords = vector3(1697.8, 4922.9, 42.0 + 1.0), radius = 3.5 },

    -- iFruit Store
    { id = 'SHOP_IFRUIT', shopId = 'ifruit', label = 'iFruit Store', coords = vector3(-1243.76, -805.85, 18.32), radius = 4.0 },

    -- Vega Tech Store
    { id = 'SHOP_VEGATECH', shopId = 'vegatech', label = 'Vega Tech Store', coords = vector3(2650.8787, 3467.1035, 55.6173), radius = 4.0 },

    -- Banques (achat de chéquier) -- USA : Fleeca Bank réelle (cf. pop_management Config.Blips)
    { id = 'SHOP_BANK_USA', shopId = 'BANK', label = 'Banque', coords = vector3(150.2, -1040.2, 29.3 + 1.0), radius = 3.5 },
    -- Mexique : emplacement provisoire (aucune banque modélisée dans la zone), à ajuster
    { id = 'SHOP_BANK_MEXICO', shopId = 'BANK', label = 'Banque', coords = vector3(2469.0, 4070.0, 38.0 + 1.0), radius = 3.5 },
}
