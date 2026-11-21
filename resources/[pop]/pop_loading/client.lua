local isJoinNuiActive = false
local hasClickedJoin = false
local transitionFinished = false

AddEventHandler("loadingscreen:saveData", function(varName, varValue)
	SendNUIMessage({ name = varName, value = varValue })
end)

RegisterNetEvent("vfw:loading:showJoinNUI")
AddEventHandler("vfw:loading:showJoinNUI", function()
    if hasClickedJoin then 
        return 
    end
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    isJoinNuiActive = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "showJoinScreen"
    })
end)

RegisterNUICallback('closeUI', function(data, cb)
    if hasClickedJoin then 
        if cb then cb('ok') end
        return 
    end
    hasClickedJoin = true

    -- Garantir la fermeture de l'écran natif si le clic a lieu tôt
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    -- Couper INSTANTANÉMENT le focus souris/clavier dès le clic
    SetNuiFocus(false, false)

    -- Transition : Écran noir avec spinner pendant le zoom arrière, puis révélation des nuages
    Citizen.CreateThread(function()
        -- S'assurer que le joueur reste gelé pendant toute la transition
        FreezeEntityPosition(PlayerPedId(), true)

        -- 1. Lancer la transition de caméra GTA Online vers le ciel (satellite zoom out)
        -- Cette opération se fait en arrière-plan sous l'écran noir de l'UI
        pcall(function()
            SwitchOutPlayer(PlayerPedId(), 0, 1)
        end)

        -- 2. Laisser le mini-chargement circulaire actif le temps que la caméra monte tout en haut (2.5 secondes)
        -- Le joueur ne voit que l'écran noir avec le spinner pendant l'ascension de la caméra
        Citizen.Wait(2500)

        -- 3. Une fois la caméra en haut dans les nuages, on cache enfin le NUI/spinner pour révéler la vue du ciel
        isJoinNuiActive = false
        SendNUIMessage({ action = "hide" })
        SendLoadingScreenMessage(json.encode({ action = "hide" }))
        -- Notifier le core que le joueur a validé la connexion
        TriggerEvent("vfw:loading:playerClickedJoin")

        -- Petit temps d'attente poétique dans les nuages (1.2 seconde)
        Citizen.Wait(1200)

        -- 4. Zoom avant vers le joueur (satellite zoom in)
        pcall(function()
            SwitchInPlayer(PlayerPedId())
        end)

        -- Attendre 5.5 secondes que la caméra redescende et se fixe derrière le joueur
        Citizen.Wait(5500)

        -- 5. Une fois arrivé au sol, on libère définitivement le joueur et on affiche le HUD
        transitionFinished = true
        
        Citizen.CreateThread(function()
            local playerId = PlayerId()
            
            -- S'assurer de fermer définitivement tout écran natif ou spinner restant
            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()
            if BusyspinnerIsOn() then
                BusyspinnerOff()
            end
            
            for i = 1, 10 do
                local ped = PlayerPedId()
                if ped and ped ~= 0 then
                    FreezeEntityPosition(ped, false)
                    SetEntityCollision(ped, true, true)
                    SetPlayerControl(playerId, true, 0)
                    SetEntityInvincible(ped, false)
                    SetEntityVisible(ped, true)
                    -- Clear any stuck tasks on the first few iterations
                    if i <= 3 then
                        ClearPedTasksImmediately(ped)
                    end
                end
                Citizen.Wait(500)
            end
        end)
        
        -- Activer le HUD (les bars de vie, faim, soif, etc.)
        TriggerEvent("esx:loadingScreenOff")
    end)
    
    -- NOTE : on n'appelle PAS spawnmanager:spawnPlayer() ici.
    -- Sur un serveur ESX, ESX.SpawnPlayer (déclenché via esx:playerLoaded) a déjà
    -- exécuté NetworkResurrectLocalPlayer aux coords sauvegardées du joueur.
    -- Appeler spawnmanager:spawnPlayer écraserait la position avec un point arbitraire.
    -- ShutdownLoadingScreen() / ShutdownLoadingScreenNui() sont déjà appelés plus haut
    -- (lignes 14, 32-33) et dans le thread de transition (lignes 79-80).
    
    if cb then cb('ok') end
end)

Citizen.CreateThread(function()
    -- Activer le contrôle manuel et le routage NUI pour l'écran de chargement natif
    SetManualShutdownLoadingScreenNui(true)
    
    -- Désactive l'auto-spawn de spawnmanager pour attendre le clic du joueur
    local state = GetResourceState('spawnmanager')
    if state == 'started' or state == 'starting' then
        exports.spawnmanager:setAutoSpawn(false)
    end
end)

Citizen.CreateThread(function()
    while not transitionFinished do
        Citizen.Wait(250)
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            FreezeEntityPosition(ped, true)
        end
    end
end)

-- Signaler périodiquement à l'UI que les scripts clients sont chargés et prêts à recevoir les callbacks NUI
Citizen.CreateThread(function()
    while not hasClickedJoin do
        -- Pour l'UI interactive (ui_page)
        SendNUIMessage({
            action = "clientReady"
        })
        -- Pour l'écran de chargement natif (loadscreen)
        SendLoadingScreenMessage(json.encode({
            action = "clientReady"
        }))
        Citizen.Wait(1000)
    end
end)

-- Safety fallback thread: If vfw:loading:showJoinNUI is not triggered within 15 seconds, force-trigger it.
-- This ensures that player can always join even if spawning events get delayed or fail.
Citizen.CreateThread(function()
    Citizen.Wait(15000)
    if not isJoinNuiActive and not hasClickedJoin then
        TriggerEvent("vfw:loading:showJoinNUI")
    end
end)