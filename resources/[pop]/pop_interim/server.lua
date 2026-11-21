-- pop_interim/server.lua
-- Applique le job ESX demandé depuis le menu d'intérim.
-- L'id reçu du client est validé contre la whitelist Config.Jobs : on ne
-- fait jamais confiance à un nom de job envoyé directement par le client.

-- Index id -> entrée de config (whitelist).
local JOB_BY_ID = {}
for _, entry in ipairs(Config.Jobs) do
    JOB_BY_ID[entry.id] = entry
end

-- Le joueur doit être à l'agence (ou sur la vue de prévisualisation d'un poste,
-- où le menu le téléporte) pour prendre un job.
local function isNearAgency(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local c = GetEntityCoords(ped)
    if #(c - Config.Location) < 30.0 then return true end
    for _, e in ipairs(Config.Jobs) do
        local p = e.pedPos or (type(e.camera) == 'table' and e.camera.pos) or e.camera
        if p and #(c - vector3(p.x, p.y, p.z)) < 50.0 then return true end
    end
    return false
end

RegisterNetEvent('pop_interim:setJob', function(id)
    local src = source
    local entry = JOB_BY_ID[id]
    if not entry then
        -- id inconnu = tentative invalide / config désynchronisée.
        return
    end
    if not isNearAgency(src) then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    -- Vérifie que le job existe côté ESX (évite un SetJob silencieusement ignoré).
    if type(ESX.DoesJobExist) == 'function' and not ESX.DoesJobExist(entry.job, entry.grade) then
        print(("[pop_interim] Job ESX introuvable : '%s' (grade %s). Vérifie ta table `jobs`."):format(entry.job, tostring(entry.grade)))
        TriggerClientEvent('notification:client:ShowNotify', src, {
            title    = 'Intérim',
            message  = "Ce métier n'est pas disponible pour le moment.",
            icon     = 'fas fa-triangle-exclamation',
            duration = 4000,
        })
        return
    end

    if entry.isJob2 and type(xPlayer.setJob2) == 'function' then
        xPlayer.setJob2(entry.job, entry.grade)
    else
        xPlayer.setJob(entry.job, entry.grade)
    end
    TriggerClientEvent('notification:client:ShowNotify', src, {
        title    = 'Intérim',
        message  = ('Tu es maintenant : %s.'):format(entry.label),
        icon     = 'fas fa-briefcase',
        duration = 4000,
    })
end)

-- Auto-creation of interim jobs at resource startup if they do not exist
CreateThread(function()
    while not ESX do Wait(100) end
    -- Wait for ESX Jobs to load (ESX.GetJobs sur les ESX récents, 30 s max)
    local function getJobs()
        if type(ESX.GetJobs) == 'function' then return ESX.GetJobs() end
        return ESX.Jobs
    end
    local tries = 0
    while (not getJobs() or next(getJobs()) == nil) and tries < 300 do Wait(100); tries = tries + 1 end
    local jobs = getJobs() or {}

    local jobsToCreate = {
        {
            name = 'pesticides',
            label = 'Répandeur de pesticides',
            grades = {
                { grade = 0, name = 'interim', label = 'Intérimaire', salary = 100 }
            }
        },
        {
            name = 'gopostal',
            label = 'Livreur GoPostal',
            grades = {
                { grade = 0, name = 'interim', label = 'Intérimaire', salary = 100 },
                { grade = 1, name = 'employee', label = 'Employé', salary = 150 }
            }
        },
        {
            name = 'transport_organe',
            label = "Transport d'urgence",
            grades = {
                { grade = 0, name = 'interim', label = 'Intérimaire', salary = 100 }
            }
        }
    }

    for _, jobData in ipairs(jobsToCreate) do
        if not jobs[jobData.name] and type(ESX.CreateJob) == 'function' then
            print(("[pop_interim] Job '%s' absent de la base de donnees. Creation en cours..."):format(jobData.name))
            ESX.CreateJob(jobData.name, jobData.label, jobData.grades)
        end
    end
end)

-- Logique brancard déplacée dans pop_inventory
