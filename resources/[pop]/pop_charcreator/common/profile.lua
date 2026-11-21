CharacterProfile = {}

CharacterProfile.Models = { 'mp_m_freemode_01', 'mp_f_freemode_01' }

local fields = {
    { key = 'mother', min = 21, max = 41, default = 21 },
    { key = 'father', min = 0, max = 20, default = 0 },
    { key = 'blend', min = 0, max = 100, default = 50 },
    { key = 'skin', min = 0, max = 100, default = 50 },
    { key = 'nose', min = -100, max = 100, default = 0 },
    { key = 'jaw', min = -100, max = 100, default = 0 },
    { key = 'chin', min = -100, max = 100, default = 0 },
    { key = 'eyes', min = 0, max = 31, default = 0 },
    { key = 'hair', min = 0, default = 0 },
    { key = 'hairColor', min = 0, default = 0 },
}

function CharacterProfile.Limits(model)
    local limits = Config.Models[model]
    if not limits or (model ~= CharacterProfile.Models[1] and model ~= CharacterProfile.Models[2]) then return end
    local output = {}
    for i, field in ipairs(fields) do
        output[i] = { key = field.key, min = field.min, max = field.max or limits[field.key], default = field.default }
    end
    return output
end

function CharacterProfile.Appearance(raw)
    if type(raw) ~= 'table' or type(raw.model) ~= 'string' or #raw.model > 20 then return end
    local limits = CharacterProfile.Limits(raw.model)
    if not limits then return end
    local clean = { model = raw.model }
    for _, field in ipairs(limits) do
        local value = type(raw[field.key]) == 'number' and math.tointeger(raw[field.key])
        if not value or value < field.min or value > field.max then return end
        clean[field.key] = value
    end
    return clean
end

function CharacterProfile.Default()
    local model = CharacterProfile.Models[1]
    local output = { model = model }
    for _, field in ipairs(CharacterProfile.Limits(model)) do output[field.key] = field.default end
    return output
end
