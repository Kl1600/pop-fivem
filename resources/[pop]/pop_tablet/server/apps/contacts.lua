-- Contacts : carnet par tablette (300 au plus). Adresse, notes et groupe sont rangés en JSON dans la colonne `note`
-- ({ a, n, g }, 200 octets au plus) : pas de colonne de plus à migrer. Le partage de contact passe par share:* (kind 'contact').

Tablet = Tablet or {}
Tablet.Contacts = {}
local K = Tablet.Contacts
local C = Tablet.Comm

local BIG = 4294967295

local function item(r)
    local meta = Tablet.Device.Decode(r.note, {})
    return { id = tonumber(r.id), name = r.name, phone = r.phone or '', mail = r.mail or '', fav = tonumber(r.favorite) == 1,
        addr = type(meta.a) == 'string' and meta.a or '', notes = type(meta.n) == 'string' and meta.n or '', grp = type(meta.g) == 'string' and meta.g or '' }
end

--- pop_tablet:contacts:list : contacts triés par nom
function K.List(src)
    local s, err = Tablet.Guard(src, nil, { name = 'conList', rate = 3 })
    if not s then return Tablet.Fail(err) end
    local items = {}
    for _, r in ipairs(Tablet.DB.ListContacts(s.serial)) do items[#items + 1] = item(r) end
    return { ok = true, items = items }
end

local function text(v, max)
    if v == nil then return '' end
    if type(v) ~= 'string' then return nil end
    local len = utf8.len(v)
    if not len or len > max then return nil end
    for i = 1, #v do local b = v:byte(i) if b < 32 or b == 127 then return nil end end
    return v
end

--- pop_tablet:contacts:save  { id?, name, phone, mail?, addr?, notes?, grp?, fav? } : crée ou modifie
function K.Save(src, data)
    local s, err = Tablet.Guard(src, nil, { name = 'conSave', rate = 3, payload = data, maxBytes = 1024 })
    if not s then return Tablet.Fail(err) end
    if type(data) ~= 'table' then return Tablet.Fail('err_payload') end
    local ok, ferr = Tablet.Limits.Field('contact', data.name, { min = 1 })
    if not ok then return Tablet.Fail(ferr) end
    if data.phone ~= '' and not Tablet.Device.PhoneValid(data.phone, Config.Phone.Format) then return Tablet.Fail('err_payload') end
    local mail, addr, notes = text(data.mail, 80), text(data.addr, C.contactAddr), text(data.notes, C.contactNotes)
    if not mail or not addr or not notes then return Tablet.Fail('err_payload') end
    local grp = data.grp
    if grp ~= nil and grp ~= '' and not Tablet.ContactGroups[grp] then return Tablet.Fail('err_payload') end
    local meta = json.encode({ a = addr, n = notes, g = grp or '' })
    if type(meta) ~= 'string' or #meta > C.contactNote then return Tablet.Fail('err_too_large') end
    local row = { name = data.name, phone = data.phone, mail = mail ~= '' and mail or nil, note = meta, favorite = data.fav == true }
    if data.id ~= nil then
        local id = Tablet.Limits.Int(data.id, 1, BIG)
        if not id or not Tablet.DB.UpdateContact(s.serial, id, row) then return Tablet.Fail('err_not_found') end
        return { ok = true, id = id }
    end
    if Tablet.DB.CountContacts(s.serial) >= C.contacts then return Tablet.Fail('err_limit') end
    return { ok = true, id = Tablet.DB.InsertContact(s.serial, row) }
end

--- pop_tablet:contacts:delete  id
function K.Delete(src, id)
    local s, err = Tablet.Guard(src, nil, { name = 'conSave', rate = 3, payload = id, maxBytes = 64 })
    if not s then return Tablet.Fail(err) end
    local n = Tablet.Limits.Int(id, 1, BIG)
    if not n or not Tablet.DB.DeleteContact(s.serial, n) then return Tablet.Fail('err_not_found') end
    return { ok = true }
end

Callback.Register('pop_tablet:contacts:list', function(src) return K.List(src) end)
Callback.Register('pop_tablet:contacts:save', function(src, data) return K.Save(src, data) end)
Callback.Register('pop_tablet:contacts:delete', function(src, id) return K.Delete(src, id) end)
