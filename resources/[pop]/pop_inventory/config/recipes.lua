-- Fabrication : recettes et établis.

-- ===== CRAFT =====

Config.Recipes = {
    {
        id = 'pochonweed',
        output = { defId = 'pochonweed', qty = 1 },
        ingredients = {
            { defId = 'weed', qty = 1 },
            { defId = 'pochon', qty = 1 },
        },
    },
    {
        id = 'safe',
        output = { defId = 'safe', qty = 1 },
        ingredients = {
            { defId = 'hotdog', qty = 8 }, -- avant : 6 + 1 + 1 sur trois lignes, mal compté
        },
    },
    {
        id = 'pistol',
        output = { defId = 'pistol', qty = 1 },
        ingredients = {
            { defId = 'cylindre', qty = 2 },
            { defId = 'plaque', qty = 4 },
            { defId = 'ressort', qty = 1 },
        },
    },
    {
        id = 'revolver',
        output = { defId = 'revolver', qty = 1 },
        ingredients = {
            { defId = 'cylindre', qty = 4 },
            { defId = 'plaque', qty = 6 },
            { defId = 'ressort', qty = 2 },
        },
    },
    {
        id = 'carabine',
        output = { defId = 'carabine', qty = 1 },
        ingredients = {
            { defId = 'cylindre', qty = 15 },
            { defId = 'plaque', qty = 25 },
            { defId = 'ressort', qty = 12 },
        },
    },
    {
        id = 'cassette_duz_it',
        output = { defId = 'cassette_duz_it', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 1 },
            { defId = 'bande_magnetique', qty = 1 },
        },
    },
    {
        id = 'cassette_tnt',
        output = { defId = 'cassette_tnt', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 1 },
            { defId = 'bande_magnetique', qty = 1 },
        },
    },
    {
        id = 'cassette_bad_boys',
        output = { defId = 'cassette_bad_boys', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 1 },
            { defId = 'bande_magnetique', qty = 1 },
        },
    },
    {
        id = 'cassette_smooth_criminal',
        output = { defId = 'cassette_smooth_criminal', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 1 },
            { defId = 'bande_magnetique', qty = 1 },
        },
    },
    {
        id = 'cassette_cant_c_me',
        output = { defId = 'cassette_cant_c_me', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 1 },
            { defId = 'bande_magnetique', qty = 1 },
        },
    },
    {
        id = 'cassette_think_about_the_way',
        output = { defId = 'cassette_think_about_the_way', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 1 },
            { defId = 'bande_magnetique', qty = 1 },
        },
    },
    {
        id = 'cassette_get_a_way',
        output = { defId = 'cassette_get_a_way', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 1 },
            { defId = 'bande_magnetique', qty = 1 },
        },
    },
    {
        id = 'walkman',
        output = { defId = 'walkman', qty = 1 },
        ingredients = {
            { defId = 'composant_cassette', qty = 3 },
            { defId = 'kit_reparation_vegatech', qty = 1 },
        },
    },

    -- ===== Lucky Plucker =====
    {
        id = 'seau_du_coq',
        output = { defId = 'seau_du_coq', qty = 1 },
        ingredients = {
            { defId = 'raw_chicken', qty = 3 },
            { defId = 'secret_breadcrumbs', qty = 1 },
            { defId = 'cooking_oil', qty = 1 },
            { defId = 'lucky_box', qty = 1 },
        },
    },
    {
        id = 'nuggets_poulailler',
        output = { defId = 'nuggets_poulailler', qty = 1 },
        ingredients = {
            { defId = 'raw_chicken', qty = 1 },
            { defId = 'bbq_sauce', qty = 1 },
            { defId = 'paper_bag', qty = 1 },
        },
    },
    {
        id = 'limonade_fermiere',
        output = { defId = 'limonade_fermiere', qty = 1 },
        ingredients = {
            { defId = 'lemon', qty = 2 },
            { defId = 'sparkling_water', qty = 1 },
            { defId = 'sugar_syrup', qty = 1 },
            { defId = 'plastic_cup', qty = 1 },
        },
    },

    -- ===== Pearls Seafood Restaurant =====
    {
        id = 'plateau_huitres',
        output = { defId = 'plateau_huitres', qty = 1 },
        ingredients = {
            { defId = 'fresh_oysters', qty = 3 },
            { defId = 'lemon_slice', qty = 1 },
            { defId = 'crushed_ice', qty = 1 },
            { defId = 'porcelain_plate', qty = 1 },
        },
    },
    {
        id = 'sandwich_homard',
        output = { defId = 'sandwich_homard', qty = 1 },
        ingredients = {
            { defId = 'fresh_lobster', qty = 1 },
            { defId = 'brioche_bun', qty = 1 },
            { defId = 'lemon_butter', qty = 1 },
            { defId = 'pearls_wrapper', qty = 1 },
        },
    },
    {
        id = 'mocktail_lagon_bleu',
        output = { defId = 'mocktail_lagon_bleu', qty = 1 },
        ingredients = {
            { defId = 'blue_curacao_syrup', qty = 1 },
            { defId = 'pineapple_juice', qty = 1 },
            { defId = 'tonic_water', qty = 1 },
            { defId = 'cocktail_glass', qty = 1 },
        },
    },

    -- ===== Drogues =====
    {
        id = 'meth_pure',
        output = { defId = 'meth_pure', qty = 1 },
        ingredients = {
            { defId = 'chemical_substance', qty = 1 },
            { defId = 'battery_acid', qty = 1 },
            { defId = 'empty_baggy', qty = 1 },
        },
    },
    {
        id = 'crack_rock',
        output = { defId = 'crack_rock', qty = 1 },
        ingredients = {
            { defId = 'cocaine_powder', qty = 1 },
            { defId = 'baking_soda', qty = 1 },
            { defId = 'empty_baggy', qty = 1 },
        },
    },
}

Config.CraftZones = {
    {
        coords = vector3(953.9382, -1254.5359, 27.0907), -- TODO: remplacer par les vraies coordonnées de l'établi
        radius = 2.0,
        label = 'Établi',
        recipes = { 'pochonweed', 'safe' },
    },

        {
        coords = vector3(753.0419, -1287.5027, 27.4669), -- TODO: remplacer par les vraies coordonnées de l'établi
        radius = 2.0,
        label = 'Établi',
        recipes = { 'pochonweed', 'safe' },
    },
    {
        coords = vector3(853.0880, -2381.1292, 31.5236),
        radius = 2.0,
        label = 'Établi du Warehouse',
        recipes = { 'pistol', 'revolver', 'carabine' },
    },
    {
        coords = vector3(2650.8787, 3467.1035, 55.6173),
        radius = 3.0,
        label = 'Établi Vega Tech',
        recipes = {
            'cassette_duz_it',
            'cassette_tnt',
            'cassette_bad_boys',
            'cassette_smooth_criminal',
            'cassette_cant_c_me',
            'cassette_think_about_the_way',
            'cassette_get_a_way',
            'walkman',
        },
    },
    {
        coords = vector3(0.0, 0.0, 0.0), -- TODO: coordonnées de la cuisine Lucky Plucker
        radius = 2.5,
        label = 'Cuisine Lucky Plucker',
        recipes = {
            'seau_du_coq',
            'nuggets_poulailler',
            'limonade_fermiere',
        },
    },
    {
        coords = vector3(0.0, 0.0, 0.0), -- TODO: coordonnées de la cuisine Pearls Seafood
        radius = 2.5,
        label = 'Cuisine Pearls Seafood',
        recipes = {
            'plateau_huitres',
            'sandwich_homard',
            'mocktail_lagon_bleu',
        },
    },
    {
        coords = vector3(0.0, 0.0, 0.0), -- TODO: coordonnées du laboratoire de drogue
        radius = 2.5,
        label = 'Laboratoire',
        recipes = {
            'meth_pure',
            'crack_rock',
        },
    },
}
