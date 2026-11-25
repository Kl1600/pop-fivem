-- Vérifie que chaque locales/<langue>.lua d'un script a les mêmes clés que fr.lua.
-- Usage : lua5.4 tools/check-locales.lua "resources/[pop]/pop_xxx"
local dir = assert(arg[1], 'usage: check-locales.lua <dossier du script>')
local langs = { 'fr', 'en', 'es', 'de', 'ar' }
local function load(lang)
    Locales = {}
    local f = loadfile(dir .. '/locales/' .. lang .. '.lua')
    if not f then return nil end
    f()
    return Locales[lang]
end
local ref = load('fr') or error('fr.lua manquant')
local bad = 0
for _, lang in ipairs(langs) do
    local t = load(lang)
    if not t then print(lang .. '.lua : MANQUANT'); bad = bad + 1
    else
        for k in pairs(ref) do if k ~= '_rtl' and t[k] == nil then print(lang .. ' : clé manquante ' .. k); bad = bad + 1 end end
        for k in pairs(t) do if k ~= '_rtl' and ref[k] == nil then print(lang .. ' : clé en trop ' .. k); bad = bad + 1 end end
    end
end
print(bad == 0 and 'OK : 5 langues complètes' or (bad .. ' problème(s)'))
os.exit(bad == 0 and 0 or 1)
