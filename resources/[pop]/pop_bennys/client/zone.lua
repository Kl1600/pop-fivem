-- pop_bennys — client : point Benny's et touches

local bennysUiId = nil

CreateThread(function()
    local inZone = false
    while true do
        local ped  = PlayerPedId()
        local pos  = GetEntityCoords(ped)
        local dist = #(pos - Config.BennysCoords)

        if dist < Config.BennysRadius then
            if not inZone then
                inZone = true
                if bennysUiId then exports.pop_v3dui:Remove(bennysUiId) end
                bennysUiId = exports.pop_v3dui:Create({
                    coords       = Config.BennysCoords + vector3(0, 0, 1.2),
                    type         = 'prompt',
                    content      = { key = 'E', label = L('prompt_label'), icon = 'fas fa-wrench' },
                    drawDistance = Config.BennysRadius + 2.0,
                })
            end
            -- Touche E (38) pour ouvrir, Backspace/Escape (200) pour fermer
            if IsControlJustPressed(0, 38) and not Bennys.nuiOpen then
                Bennys.OpenMenu()
            elseif Bennys.nuiOpen and IsControlJustPressed(0, 200) then
                SendNUIMessage({ action = 'close' })
                Bennys.CloseMenu(false)
            end
            Wait(0)
        else
            if inZone then
                inZone = false
                if bennysUiId then exports.pop_v3dui:Remove(bennysUiId) end
                bennysUiId = nil
            end
            if Bennys.nuiOpen and IsControlJustPressed(0, 200) then
                SendNUIMessage({ action = 'close' })
                Bennys.CloseMenu(false)
            end
            Wait(500)
        end
    end
end)
