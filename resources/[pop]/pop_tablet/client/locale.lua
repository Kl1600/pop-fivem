-- Textes de l'interface : anglais + langue de LA TABLETTE (réglage de l'appareil), pas Config.Locale du serveur.
-- Le client lit Locales[lang] directement : shared/locale.lua n'est pas modifié.

Tablet = Tablet or {}
Tablet.Client = Tablet.Client or {}
local C = Tablet.Client

local cache = {} -- [langue] = table de textes (construite une fois)

--- Table complète des clés pour `lang` (anglais complété par la langue), avec `_rtl` pour l'arabe.
function C.LocaleTable(lang)
    if not Tablet.LanguageSet[lang] then lang = Config.Locale end
    local cached = cache[lang]
    if cached then return cached end
    local out = {}
    for k, v in pairs(Locales.en or {}) do out[k] = v end
    local current = Locales[lang]
    if current then
        for k, v in pairs(current) do out[k] = v end
    end
    out._rtl = current ~= nil and current._rtl == true
    cache[lang] = out
    return out
end
