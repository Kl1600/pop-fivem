-- Preuves hors jeu (revue statique) : perf-01/02/07, sec-01/03/04/05/08/09, i18n-01.
-- Chargé par tests/run.lua : `return function(check, section)`. Lit les sources, ne lance rien.

local function read(path)
    local f = assert(io.open(path, 'rb'))
    local s = f:read('a')
    f:close()
    return (s:gsub('\r\n', '\n')) -- fichiers parfois en CRLF sous Windows
end

-- Sans commentaires de ligne ni chaînes : évite les faux positifs sur « while » dans un texte.
local function code(path)
    local out = {}
    for line in read(path):gmatch('[^\n]*') do
        line = line:gsub("'[^'\n]*'", "''"):gsub('"[^"\n]*"', '""'):gsub('%-%-.*$', '')
        out[#out + 1] = line
    end
    return table.concat(out, '\n')
end

local function count(s, pat)
    local n = 0
    for _ in s:gmatch(pat) do n = n + 1 end
    return n
end

local function files()
    local list = {}
    local windows = package.config:sub(1, 1) == '\\'
    local p = io.popen(windows and 'dir /b /s client\\*.lua server\\*.lua shared\\*.lua' or 'find client server shared -name "*.lua" | sort')
    for l in p:lines() do
        l = l:gsub('\r', ''):gsub('\\', '/')
        l = l:match('/pop_tablet/(.+)$') or l -- `dir /s` donne des chemins absolus
        if l ~= 'shared/callback.lua' and l ~= 'shared/locale.lua' then list[#list + 1] = l end
    end
    p:close()
    table.sort(list)
    return list
end

return function(check, section)
    local all = files()

    ------------------------------------------------------------------
    section('audit : i18n-01 clés des 10 locales Lua')
    local enKeys, nEn = {}, 0
    for k in pairs(Locales.en) do enKeys[k] = true nEn = nEn + 1 end
    for _, lang in ipairs({ 'fr', 'es', 'de', 'it', 'pt', 'nl', 'pl', 'tr', 'ar' }) do
        local missing, extra = {}, {}
        for k in pairs(enKeys) do
            if Locales[lang][k] == nil then missing[#missing + 1] = k end
        end
        for k, v in pairs(Locales[lang]) do
            if k ~= '_rtl' and not enKeys[k] then extra[#extra + 1] = k end
            if type(v) == 'string' and v == '' then extra[#extra + 1] = k .. '(vide)' end
        end
        check('locale ' .. lang .. ' : aucune clé manquante ni en trop', #missing == 0 and #extra == 0,
            table.concat(missing, ',') .. '|' .. table.concat(extra, ','))
    end
    check('locale ar : _rtl = true', Locales.ar._rtl == true)

    ------------------------------------------------------------------
    section('audit : perf-01/02/07 boucles, attentes, minuteries')
    -- Chaque occurrence autorisée est justifiée ; tout le reste échoue.
    local LOOPS = {
        ['client/anim.lua']      = { ['while'] = 1, wait = 1, thread = 0, why = 'attente du chargement d\'un asset, bornée à 100 essais x 10 ms, seulement à l\'ouverture' },
        ['client/map.lua']       = { ['while'] = 1, wait = 2, thread = 1, why = 'attente de fermeture du menu pause, bornée par PAUSE_MAX_MS, seulement sur demande de l\'utilisateur' },
        ['client/main.lua']      = { thread = 1, why = 'CreateThread(C.Anim.Start) : démarrage ponctuel de l\'animation (la boucle bornée est dans anim.lua)' },
        ['server/main.lua']      = { thread = 1, why = 'repli de démarrage sans MySQL.ready : une fois, sans boucle' },
        ['server/hash.lua']      = { ['while'] = 1, why = 'génération des 64 premiers nombres premiers, bornée, au chargement' },
        ['server/apps/files.lua'] = { ['while'] = 2, why = 'remontée de l\'arbre des dossiers, compteur de garde 50' },
    }
    for _, path in ipairs(all) do
        local c = code(path)
        local lim = LOOPS[path] or {}
        local w = count(c, '%f[%w_]while%f[^%w_]')
        local waits = count(c, '[^%w_%.:]Wait%(')
        local th = count(c, 'CreateThread%(')
        check(path .. ' : while = ' .. (lim['while'] or 0), w == (lim['while'] or 0), w)
        check(path .. ' : Wait = ' .. (lim.wait or 0), waits == (lim.wait or 0), waits)
        check(path .. ' : CreateThread = ' .. (lim.thread or 0), th == (lim.thread or 0), th)
        check(path .. ' : ni while true, ni SetInterval, ni RegisterTick, ni repeat', count(c, 'while%s+true') == 0
            and count(c, 'SetInterval') == 0 and count(c, 'RegisterTick') == 0 and count(c, '%f[%w_]repeat%f[^%w_]') == 0)
    end
    -- Les boucles autorisées portent leur borne dans le texte.
    check('anim.lua : borne tries < 100', read('client/anim.lua'):find('tries < 100', 1, true) ~= nil)
    check('map.lua : borne PAUSE_MAX_MS', read('client/map.lua'):find('waited < PAUSE_MAX_MS', 1, true) ~= nil)
    check('hash.lua : borne #primes < 64', read('server/hash.lua'):find('#primes < 64', 1, true) ~= nil)
    check('files.lua : gardes > 50', count(read('server/apps/files.lua'), 'guard > 50') == 2)

    -- Minuteries : jamais de boucle, chaque SetTimeout est ponctuelle ou en chaîne gardée par une génération.
    local TIMERS = {
        ['client/device.lua'] = 2, ['client/scheduler.lua'] = 1, ['server/apps/photos.lua'] = 1,
        ['server/apps/translate.lua'] = 1, ['server/scheduler.lua'] = 1,
    }
    for _, path in ipairs(all) do
        local n = count(code(path), 'SetTimeout%(')
        check(path .. ' : SetTimeout = ' .. (TIMERS[path] or 0), n == (TIMERS[path] or 0), n)
    end
    local dev = read('client/device.lua')
    check('device.lua : la chaîne de resynchronisation s\'arrête si la génération change, si coupée ou fermée',
        dev:find('mine ~= resyncGeneration or not resyncActive or not C.IsOpen()', 1, true) ~= nil)
    check('device.lua : resync lue en local (natives), aucun envoi au serveur',
        not code('client/device.lua'):find('TriggerServerEvent') and not code('client/device.lua'):find('Callback%.Trigger'))
    local sched = code('server/scheduler.lua')
    check('scheduler serveur : minuterie portée par un numéro de génération', sched:find('gen') ~= nil)

    ------------------------------------------------------------------
    section('audit : sec-01/04/09 callbacks serveur passent par la garde')
    -- Callbacks dont la garde est interne à la fonction appelée : nom de fonction -> pourquoi c'est sûr.
    local OWN_SESSION = {
        ['D.Open'] = 'ouverture : vérifie joueur, objet porté (hint revérifié), pas de session préalable',
        ['D.Close'] = 'fermeture : ne touche que la session de src',
        ['D.Setup'] = 'premier allumage : session et objet porté revérifiés dans la fonction',
        ['D.Unlock'] = 'déverrouillage : verrouillage par essais + objet porté',
        ['D.ChangeCode'] = 'code actuel exigé',
        ['D.Lock'] = 'ne touche que la session de src',
        ['Store.Install'] = 'via change() : Tablet.Guard dans change (vérifié plus bas)',
        ['Store.Remove'] = 'via change() : Tablet.Guard dans change (vérifié plus bas)',
    }
    local unguarded, total = {}, 0
    for _, path in ipairs(all) do
        if path:match('^server/') then
            local text = read(path)
            for fn in text:gmatch("Callback%.Register%('pop_tablet:[%w_:]+',%s*function%b()%s*return%s+([%w_%.]+)%(") do
                total = total + 1
                -- corps de la fonction : du « function X.Fn( » à la prochaine ligne « end » en colonne 0
                local body = text:match('\nfunction ' .. fn:gsub('%.', '%%.') .. '%b().-\nend\n')
                    or text:match('\nlocal function ' .. fn:gsub('%.', '%%.') .. '%b().-\nend\n')
                local ok = body and (body:find('Tablet.Guard(', 1, true) or body:find('Tablet.Device.Guard(', 1, true)
                    or body:find('D.Guard(', 1, true)) ~= nil
                if not ok and not OWN_SESSION[fn] then unguarded[#unguarded + 1] = path .. ':' .. fn end
            end
        end
    end
    check('callbacks serveur : toutes gardées (' .. total .. ' trouvées)', #unguarded == 0 and total > 80, table.concat(unguarded, ', '))
    check('store.lua : change() est gardée', (read('server/apps/store.lua'):match('local function change%b().-\nend\n') or ''):find('Tablet.Guard(', 1, true) ~= nil)
    -- Le relais NUI refuse tout nom hors liste blanche et borne la charge.
    local nui = read('client/nui.lua')
    check('relais NUI : liste blanche Tablet.RelaySet + tablette ouverte + charge bornée',
        nui:find('Tablet.RelaySet[data.name]', 1, true) and nui:find('C.IsOpen()', 1, true) and nui:find('MAX_RELAY_BYTES', 1, true))
    -- Chaque callback NUI hors relais exige la tablette ouverte ou ne lit qu'un état local sans effet.
    local NUI_OPEN_OR_LOCAL = { ['tablet:ready'] = true, ['tablet:close'] = true, ['tablet:locale'] = true, ['tablet:micro'] = true }
    local nuiUnsafe = {}
    for name, body in nui:gmatch("RegisterNUICallback%('([%w:]+)'(.-\nend%))") do
        if not (NUI_OPEN_OR_LOCAL[name] or body:find('C.IsOpen()', 1, true)) then nuiUnsafe[#nuiUnsafe + 1] = name end
    end
    check('callbacks NUI : tablette ouverte exigée (sauf état local)', #nuiUnsafe == 0, table.concat(nuiUnsafe, ','))
    -- L'échéance envoyée par le client est revérifiée côté serveur.
    local main = read('server/main.lua')
    check('pop_tablet:server:due : anti-spam, types, session et objet porté vérifiés',
        main:find("Tablet.Limits.Rate(src, 'due'", 1, true) and main:find('Tablet.Device.Carries(src, s.serial)', 1, true))

    ------------------------------------------------------------------
    section('audit : sec-03/05/08 propriété, tailles, SQL')
    -- Aucun montant : la ressource ne touche pas à l'argent.
    local money = {}
    for _, path in ipairs(all) do
        local c = code(path)
        if c:find('AddMoney') or c:find('RemoveMoney') or c:find('Bridge%.[%w]*Money') or c:find('[Bb]alance') then money[#money + 1] = path end
    end
    check('aucun accès à l\'argent côté serveur ni client', #money == 0, table.concat(money, ','))
    -- Aucune identité lue dans la charge envoyée par le client.
    local ident = {}
    for _, path in ipairs(all) do
        if path:match('^server/') then
            local c = code(path)
            if c:find('%f[%w_]data%.serial') or c:find('%f[%w_]data%.identifier') or c:find('%f[%w_]data%.citizenid') or c:find('%f[%w_]data%.owner')
                or c:find('%f[%w_]data%.license') or c:find('%f[%w_]data%.sender') or c:find('%f[%w_]data%.from_phone') then
                ident[#ident + 1] = path
            end
        end
    end
    -- (`data.phone` est le correspondant choisi par l'utilisateur, pas l'expéditeur : l'expéditeur vient de la session.)
    check('aucune identité (serial, identifiant, propriétaire, expéditeur) lue dans la charge client', #ident == 0, table.concat(ident, ','))
    -- SQL : tout WHERE/UPDATE/DELETE portant sur des données de tablette contient serial ou phone (messages) ; valeurs en ?.
    local db = read('server/db.lua')
    local badSql = {}
    local lines = {}
    for l in db:gmatch('[^\n]*') do lines[#lines + 1] = l end
    for i, l in ipairs(lines) do
        if l:find("'UPDATE ", 1, true) or l:find("'DELETE ", 1, true) then
            local stmt, j = l, i + 1
            while lines[j] and lines[j]:match('^%s*%.%.') do stmt = stmt .. lines[j] j = j + 1 end
            -- portée : le serial (ou le numéro de téléphone pour les messages), ou une ligne enfant d'une ligne déjà possédée (sous-requête serial),
            -- ou une purge par date, ou un appel (id d'appel vérifié par phone.lua contre les deux numéros).
            if not (stmt:find('serial', 1, true) or stmt:find('phone', 1, true) or stmt:find('<', 1, true)
                or stmt:find('pop_tablet_calls', 1, true)
                or stmt:find('pop_tablet_photo_albums WHERE album_id', 1, true)) then -- lien album/photo : photos.lua exige AlbumOwned et PhotoOwned avant
                badSql[#badSql + 1] = stmt:sub(1, 70)
            end
        end
    end
    check('SQL : chaque UPDATE/DELETE est restreint par serial/phone, purge datée ou appel', #badSql == 0, table.concat(badSql, ' | '))
    local inlined = {}
    for line in db:gmatch('[^\n]+') do
        -- une variable concaténée dans la requête n'est tolérée que si c'est un nom de colonne/ORDER BY interne (cols, where, order, field)
        if line:find('MySQL%.') then
            for var in line:gmatch("'%s*%.%.%s*([%w_]+)") do
                if not ({ cols = 1, COLUMNS = 1, where = 1, order = 1, field = 1, gid = 1 })[var] then inlined[#inlined + 1] = var end
            end
        end
    end
    check('SQL : aucune valeur concaténée (seulement colonnes/tri internes)', #inlined == 0, table.concat(inlined, ','))

    -- Tailles : la garde borne la charge, les limites existent et les enregistrements les appliquent.
    local lim = read('server/limits.lua')
    check('limits : Size, Payload, Field, Int, Enum, Trim, Rate définis',
        lim:find('function Limits.Size', 1, true) and lim:find('function Limits.Payload', 1, true) and lim:find('function Limits.Field', 1, true)
        and lim:find('function Limits.Int', 1, true) and lim:find('function Limits.Enum', 1, true)
        and lim:find('function Limits.Trim', 1, true) and lim:find('function Limits.Rate', 1, true))
    local noPayload = {}
    for _, path in ipairs(all) do
        if path:match('^server/apps/') then
            local text = read(path)
            -- une garde qui reçoit des données du client doit porter `payload =` ; les gardes sans donnée (listes) sont exemptées
            for guard in text:gmatch('Tablet%.Guard%(src, nil, (%b{})') do
                if guard:find('name = \'[%w]*Save\'') and not guard:find('payload') then noPayload[#noPayload + 1] = path end
            end
        end
    end
    check('toute garde d\'écriture (…Save) borne la charge (payload =)', #noPayload == 0, table.concat(noPayload, ','))
    check('Config : tailles max déclarées (Tablet.Max)', read('shared/tablet.lua'):find('Tablet.Max', 1, true) ~= nil)

    ------------------------------------------------------------------
    section('audit : sec-02/06 secrets')
    local secrets = {}
    for _, path in ipairs(all) do
        local text = read(path)
        if text:find('setr%s+') or text:find('[Aa]pi[_]?[Kk]ey%s*=%s*[\'"][%w]') or text:find('password%s*=%s*[\'"][%w]') then secrets[#secrets + 1] = path end
    end
    check('aucun secret ni setr dans le code', #secrets == 0, table.concat(secrets, ','))
    local dev2 = read('server/device.lua')
    check('code jamais journalisé ni renvoyé (aucun print/return du code)', not dev2:find('print%b()[^\n]*code') or dev2:find('print%b()[^\n]*code') == nil)
end
