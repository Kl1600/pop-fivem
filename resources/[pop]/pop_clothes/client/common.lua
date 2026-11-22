-- État partagé du client pop_clothes (chargé en premier, voir fxmanifest).

Clothes = {
    cam = nil,
    inMenu = false,
    camHeading = 0.0,
    camRadius = 2.5,
    camHeight = 0.2,
    currentShopType = 'clothing',
    currentShop = nil,
    pedRestoreCoords = nil,
    pedRestoreHeading = nil,
    originalSkin = {},
    currentTattoos = {},
    openedFromCreator = false,
    purchaseCompleted = false,
}

function Clothes.HasFixedCam()
    local shop = Clothes.currentShop
    return shop and shop.cam and shop.cam.coords
end

-- Lit la tenue réellement portée sur le ped (composants + props) sous forme
-- de table compatible skinchanger. Sert à figer dans skinchanger les habits
-- choisis dans le menu du créateur (sinon ils sont écrasés au prochain
-- skinchanger:change, ex. réglage du visage).
function Clothes.ReadWornClothes(ped)
    return {
        mask_1   = GetPedDrawableVariation(ped, 1),  mask_2   = GetPedTextureVariation(ped, 1),
        arms     = GetPedDrawableVariation(ped, 3),  arms_2   = GetPedTextureVariation(ped, 3),
        pants_1  = GetPedDrawableVariation(ped, 4),  pants_2  = GetPedTextureVariation(ped, 4),
        bags_1   = GetPedDrawableVariation(ped, 5),  bags_2   = GetPedTextureVariation(ped, 5),
        shoes_1  = GetPedDrawableVariation(ped, 6),  shoes_2  = GetPedTextureVariation(ped, 6),
        chain_1  = GetPedDrawableVariation(ped, 7),  chain_2  = GetPedTextureVariation(ped, 7),
        tshirt_1 = GetPedDrawableVariation(ped, 8),  tshirt_2 = GetPedTextureVariation(ped, 8),
        bproof_1 = GetPedDrawableVariation(ped, 9),  bproof_2 = GetPedTextureVariation(ped, 9),
        decals_1 = GetPedDrawableVariation(ped, 10), decals_2 = GetPedTextureVariation(ped, 10),
        torso_1  = GetPedDrawableVariation(ped, 11), torso_2  = GetPedTextureVariation(ped, 11),
        helmet_1  = GetPedPropIndex(ped, 0), helmet_2  = GetPedPropTextureIndex(ped, 0),
        glasses_1 = GetPedPropIndex(ped, 1), glasses_2 = GetPedPropTextureIndex(ped, 1),
        ears_1    = GetPedPropIndex(ped, 2), ears_2    = GetPedPropTextureIndex(ped, 2),
    }
end
