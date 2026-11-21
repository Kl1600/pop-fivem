-- pop_bennys — client : ouverture, fermeture, paiement

function Bennys.OpenMenu()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not DoesEntityExist(veh) or veh == 0 then
        local coords = GetEntityCoords(ped)
        veh = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 70)
    end
    if not DoesEntityExist(veh) or veh == 0 then
        Bridge.Notify({ icon = 'fas fa-circle-info', message = L('no_vehicle_near'), duration = 3000 })
        return
    end

    SetVehicleModKit(veh, 0)
    Bennys.SaveOrig(veh)
    Bennys.vehicle = veh
    Bennys.nuiOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action      = 'open',
        vehicle     = Bennys.BuildVehicleData(veh),
        itemCosts   = Config.ItemCosts,
        itemDb      = Bennys.BuildItemDb(),
        unknownIcon = Config.ItemIconBase .. Config.UnknownIcon,
    })

    -- Vue initiale = première catégorie du menu (jantes).
    Bennys.FocusCamera('wheels')

    -- Masque HUD + minimap (pop_hud) + speedometer le temps du menu.
    TriggerEvent('hud:toggleui', false)
    DisplayRadar(false)
end

-- Base des items référencés par les recettes : pour chaque defId, on résout son
-- label, sa vraie icône et la quantité possédée par le joueur.
-- L'icône/label viennent de pop_inventory (export GetItemDef) si dispo, sinon des
-- valeurs du config ; si rien n'existe -> icône '?'. Robuste si l'export manque.
local function safeExport(fn, default)
    local ok, res = pcall(fn)
    if ok then return res end
    return default
end

function Bennys.BuildItemDb()
    local inv = exports[Config.ItemsResource]
    local base, unknown = Config.ItemIconBase, Config.UnknownIcon
    local db = {}
    for _, recipe in pairs(Config.ItemCosts) do
        for _, need in ipairs(recipe) do
            if db[need.item] == nil then
                local def   = safeExport(function() return inv:GetItemDef(need.item) end, nil)
                local owned = safeExport(function() return inv:getItemCount(need.item) end, 0) or 0
                local icon  = (def and def.icon) or need.icon or unknown
                db[need.item] = {
                    label = (def and def.label) or need.label or need.item,
                    icon  = base .. icon,
                    owned = owned,
                }
            end
        end
    end
    return db
end

function Bennys.CloseMenu(apply)
    if not Bennys.nuiOpen then return end
    Bennys.nuiOpen = false
    SetNuiFocus(false, false)
    Bennys.DestroyCamera()
    if not apply then Bennys.RevertAll() end
    Bennys.vehicle = 0

    -- Restaure HUD + minimap + speedometer.
    TriggerEvent('hud:toggleui', true)
    DisplayRadar(true)
end

-- ─────────────────────────────────────────────
-- NUI callbacks
-- ─────────────────────────────────────────────

-- 'close' (Échap / bouton) : callback NUI du bridge, qui rend déjà le focus.
Bridge.OnUiClose(function() Bennys.CloseMenu(false) end)

RegisterNUICallback('focusCamera', function(data, cb)
    Bennys.FocusCamera(data.cat)
    cb('ok')
end)

local payPending = false
RegisterNUICallback('apply', function(_, cb)
    cb('ok')
    if not DoesEntityExist(Bennys.vehicle) or payPending then return end
    -- Le texte de plaque n'est jamais modifiable ici (copie de plaque impossible)
    SetVehicleNumberPlateText(Bennys.vehicle, Bennys.origMods.plateText)
    local cats = Bennys.ChangedCategories(Bennys.vehicle)
    if next(cats) == nil then
        Bennys.CloseMenu(true)
        return
    end
    payPending = true
    TriggerServerEvent('pop_bennys:payItems', cats)
end)

RegisterNetEvent('pop_bennys:payResult', function(ok)
    payPending = false
    if ok then
        Bennys.CloseMenu(true)
        Bridge.Notify({ icon = 'fas fa-circle-info', message = L('mods_applied'), duration = 3000 })
    else
        Bennys.CloseMenu(false)
        Bridge.Notify({ icon = 'fas fa-circle-info', message = L('not_enough_items'), duration = 3000 })
    end
end)

-- ─────────────────────────────────────────────
-- Trigger
-- ─────────────────────────────────────────────

-- /bennys : réservé aux admins (contrôle côté serveur), sinon passer par le point Benny's
RegisterNetEvent('pop_bennys:adminOpen', function()
    if not Bennys.nuiOpen then Bennys.OpenMenu() end
end)

exports('open', Bennys.OpenMenu)
