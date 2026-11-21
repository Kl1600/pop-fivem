-- Barbier : choix en attente d'achat, reportés dans skinchanger à l'achat.

-- Choix du barbier en attente d'achat : reportés dans skinchanger à l'achat
-- (les natives seules ne mettent pas à jour le skin sauvegardé : coupe perdue).
Clothes.barberPending = {}

-- composant d'overlay -> clés skinchanger (index, opacité, couleur)
local OVERLAY_KEYS = {
    [1] = { 'beard_1', 'beard_2', 'beard_3' },
    [2] = { 'eyebrows_1', 'eyebrows_2', 'eyebrows_3' },
    [4] = { 'makeup_1', 'makeup_2', 'makeup_3' },
    [5] = { 'blush_1', 'blush_2', 'blush_3' },
    [8] = { 'lipstick_1', 'lipstick_2', 'lipstick_3' },
    [10] = { 'chest_1', 'chest_2', 'chest_3' },
}

function Clothes.CommitBarberToSkin()
    for _, sel in pairs(Clothes.barberPending) do
        if sel.kind == 'clothing' and sel.component == 2 then
            TriggerEvent('skinchanger:change', 'hair_1', sel.index == -1 and 0 or sel.index)
            TriggerEvent('skinchanger:change', 'hair_2', sel.texture)
            TriggerEvent('skinchanger:change', 'hair_color_1', sel.texture)
            TriggerEvent('skinchanger:change', 'hair_color_2', sel.texture)
        elseif sel.kind == 'overlay' and OVERLAY_KEYS[sel.component] then
            local k = OVERLAY_KEYS[sel.component]
            if sel.index == -1 then
                TriggerEvent('skinchanger:change', k[1], 0)
                TriggerEvent('skinchanger:change', k[2], 0)
            else
                TriggerEvent('skinchanger:change', k[1], sel.index)
                TriggerEvent('skinchanger:change', k[2], 10)
                TriggerEvent('skinchanger:change', k[3], sel.texture)
            end
        end
    end
    Clothes.barberPending = {}
    -- skinchanger réapplique tout le skin (« nu ») : on remet la tenue de l'inventaire.
    if GetResourceState('pop_inventory') == 'started' then
        pcall(function() exports.pop_inventory:RefreshEquipment() end)
    end
end
