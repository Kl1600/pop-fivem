-- Données propres à une appli, par tablette (favoris de Plans, favoris de Traduire, liste de suivi de la Bourse).
-- Un texte JSON par tablette et par appli : chaque appli valide son contenu avant d'écrire, ce module ne fait que borner la taille.

Tablet = Tablet or {}
Tablet.AppData = {}
local A = Tablet.AppData

local MAX_BYTES = 16384

--- Contenu enregistré (table), ou `default`.
function A.Get(serial, app, default)
    return Tablet.Device.Decode(Tablet.DB.GetAppData(serial, app), default or {})
end

--- Enregistre `data` ; false si le texte dépasse la limite.
function A.Set(serial, app, data)
    local text = json.encode(data)
    if type(text) ~= 'string' or #text > MAX_BYTES then return false end
    Tablet.DB.SetAppData(serial, app, text)
    return true
end
