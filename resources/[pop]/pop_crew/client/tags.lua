-- pop_crew : repère à la couleur du crew au-dessus des membres proches (F9, option Config.ShowTags).
-- Un thread n'existe que si un autre membre est en ligne ; il dessine seulement quand quelqu'un est visible.

if not Config.ShowTags then return end
if not PopCrew then return end -- client/main.lua absent ou en erreur

local RES = GetCurrentResourceName()
local SCAN_INTERVAL = 500  -- ms entre deux recalculs de la liste visible
local IDLE_WAIT = 1000     -- ms quand personne n'est visible
local HEAD_BONE = 31086    -- SKEL_Head
local HEAD_OFFSET = 0.35
local SCALE = 0.15
local ALPHA = 200

local state = PopCrew -- défini par client/main.lua
local crew
local color = { 255, 255, 255 }
local token, active = 0, false

local function hexToRgb(hex)
    local r, g, b = tostring(hex):match('^#?(%x%x)(%x%x)(%x%x)$')
    if not r then return { 255, 255, 255 } end
    return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
end

local function hasOthers(c, myId)
    if not c or type(c.onlineIds) ~= 'table' then return false end
    for _, id in ipairs(c.onlineIds) do
        if id ~= myId then return true end
    end
    return false
end

-- Peds des autres membres en ligne, existants et à portée.
local function visiblePeds(c, myId)
    local list = {}
    local myPed = PlayerPedId()
    local myPos = GetEntityCoords(myPed)
    local maxDist = Config.TagDistance or 20.0
    for _, id in ipairs(c.onlineIds) do
        if id ~= myId then
            local player = GetPlayerFromServerId(id)
            if player ~= -1 then
                local ped = GetPlayerPed(player)
                if ped ~= 0 and ped ~= myPed and DoesEntityExist(ped) and IsEntityVisible(ped)
                    and #(myPos - GetEntityCoords(ped)) <= maxDist then
                    list[#list + 1] = ped
                end
            end
        end
    end
    return list
end

local function stop()
    token = token + 1
    active = false
end

local function start()
    if active then return end
    active = true
    token = token + 1
    local my = token
    CreateThread(function()
        local myId = GetPlayerServerId(PlayerId())
        while token == my do
            local c = crew
            if not hasOthers(c, myId) then break end
            local peds = visiblePeds(c, myId)
            if #peds == 0 then
                Wait(IDLE_WAIT)
            else
                local r, g, b = color[1], color[2], color[3]
                local untilTime = GetGameTimer() + SCAN_INTERVAL
                while token == my and GetGameTimer() < untilTime do
                    for i = 1, #peds do
                        local ped = peds[i]
                        if DoesEntityExist(ped) then
                            local head = GetPedBoneCoords(ped, HEAD_BONE, 0.0, 0.0, 0.0)
                            DrawMarker(2, head.x, head.y, head.z + HEAD_OFFSET,
                                0.0, 0.0, 0.0, 180.0, 0.0, 0.0,
                                SCALE, SCALE, SCALE, r, g, b, ALPHA,
                                false, true, 2, false, nil, nil, false)
                        end
                    end
                    Wait(0)
                end
            end
        end
        if token == my then active = false end
    end)
end

local function onCrew(c)
    crew = c
    if c then color = hexToRgb(c.color) end
    if hasOthers(c, GetPlayerServerId(PlayerId())) then start() else stop() end
end

state.listeners[#state.listeners + 1] = onCrew
if state.crew then onCrew(state.crew) end

AddEventHandler('onResourceStop', function(res)
    if res == RES then stop() end
end)
