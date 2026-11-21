-- Traductions. Chaque fichier de locales/ remplit Locales['<langue>'] = { clé = 'texte' }.
-- Ordre de recherche : Config.Locale, puis 'en', puis la clé brute.
-- Locales.<langue>._rtl = true indique une langue écrite de droite à gauche (arabe).

Locales = Locales or {}

local function lookup(key)
    local current = Locales[Config.Locale]
    local value = current and current[key]
    if value == nil and Locales.en then
        value = Locales.en[key]
    end
    return value
end

--- Renvoie le texte traduit de `key`, formaté avec string.format si des arguments sont donnés.
function L(key, ...)
    local value = lookup(key)
    if type(value) ~= 'string' then
        return tostring(key)
    end
    if select('#', ...) == 0 then
        return value
    end
    local ok, formatted = pcall(string.format, value, ...)
    return ok and formatted or value
end

--- Table complète des textes (anglais complété par la langue choisie) pour la NUI.
--- Contient `_rtl = true` si la langue s'écrit de droite à gauche.
function GetLocaleTable()
    local out = {}
    for k, v in pairs(Locales.en or {}) do out[k] = v end
    local current = Locales[Config.Locale]
    if current then
        for k, v in pairs(current) do out[k] = v end
    end
    out._rtl = current and current._rtl == true or false
    return out
end
