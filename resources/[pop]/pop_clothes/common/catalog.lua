ClothesCatalog = {}

local male = joaat('mp_m_freemode_01') & 0xffffffff
local female = joaat('mp_f_freemode_01') & 0xffffffff
local categoryById = {}
for _, category in ipairs(Config.Catalog) do
    categoryById[category.id] = category
end

function ClothesCatalog.Model(hash)
    if type(hash) ~= 'number' then return end
    hash = hash & 0xffffffff
    if hash == male then return 'male' end
    if hash == female then return 'female' end
end

function ClothesCatalog.Option(categoryId, optionId, model, kind)
    if type(categoryId) ~= 'string' or #categoryId > 32 or type(optionId) ~= 'string' or #optionId > 32 then return end
    local category = categoryById[categoryId]
    if not category or (kind and category.kind ~= kind) then return end
    for _, option in ipairs(category.options) do
        if option.id == optionId and option[model] then
            local price = type(option.price) == 'number' and math.tointeger(option.price)
            if not price or price < 0 or price > 1000000 then return end
            return option, category
        end
    end
end
