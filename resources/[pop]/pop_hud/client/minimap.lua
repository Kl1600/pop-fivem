-- Mini-carte ronde (texture circlemap) et masquage du HUD sur la grande carte / le menu pause.

local minimapScaleform = RequestScaleformMovie("minimap")

local function InitMinimap()
    RequestStreamedTextureDict("circlemap", false)
    while not HasStreamedTextureDictLoaded("circlemap") do
        Wait(100)
    end
    AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "circlemap", "radarmasksm")
    SetMinimapClipType(1)

    -- Position des tuiles de la carte derrière le masque
    for _, c in ipairs(Config.Minimap) do
        SetMinimapComponentPosition(c[1], c[2], c[3], c[4], c[5], c[6], c[7])
    end

    -- Rafraîchissement (grande carte activée puis désactivée)
    DisplayRadar(true)
    SetRadarBigmapEnabled(true, false)
    Wait(50)
    SetRadarBigmapEnabled(false, false)
end

-- Masque et fond de la mini-carte, sans flou
local uiHidden = false
CreateThread(function()
    InitMinimap()

    while true do
        -- Ces réglages radar sont des propriétés persistantes : les réappliquer
        -- ~5x/s suffit (au lieu de chaque frame) → gros gain resmon sans changement visuel.
        Wait(Config.RadarRefresh)
        -- Radar caché en menu pause, HUD désactivé, perso non chargé ou créateur de personnage
        local pauseActive = IsPauseMenuActive()
        if pauseActive or not Hud.show or not Hud.ready or LocalPlayer.state.charcreatorOpen then
            DisplayRadar(false)
        else
            DisplayRadar(true)
        end
        -- Zoom fixe : évite que les tuiles disparaissent à faible vitesse / à pied
        SetRadarZoom(Config.RadarZoom)

        if not HasStreamedTextureDictLoaded("circlemap") then
            RequestStreamedTextureDict("circlemap", false)
            AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "circlemap", "radarmasksm")
        end

        BeginScaleformMovieMethod(minimapScaleform, "SETUP_HEALTH_ARMOUR")
        ScaleformMovieMethodAddParamInt(3)
        EndScaleformMovieMethod()

        -- HUD caché sur la grande carte, radar masqué ou menu pause
        if IsBigmapActive() or IsRadarHidden() or pauseActive then
            if not uiHidden then
                SendNUIMessage({ action = "hideUI" })
                uiHidden = true
            end
        elseif uiHidden then
            SendNUIMessage({ action = "displayUI" })
            uiHidden = false
        end
    end
end)

-- Personnage chargé : HUD autorisé, mini-carte réinitialisée (évite la carte rectangulaire par défaut).
-- Si la ressource redémarre en jeu (perso déjà chargé), on affiche sans réinitialiser.
local alreadyLoaded = Bridge.IsLoaded()
Bridge.OnPlayerLoaded(function()
    Hud.ready = true
    if alreadyLoaded then
        alreadyLoaded = false
        return
    end
    Wait(2000) -- attendre la fin du spawn
    InitMinimap()
end)

-- Retour au choix du personnage : HUD caché (ESX direct, le bridge client n'a pas cet évènement)
RegisterNetEvent('esx:onPlayerLogout')
AddEventHandler('esx:onPlayerLogout', function()
    Hud.ready = false
end)

RegisterNetEvent('playerSpawned')
AddEventHandler('playerSpawned', function()
    CreateThread(function()
        Wait(2000) -- attendre la fin du spawn
        InitMinimap()
    end)
end)
