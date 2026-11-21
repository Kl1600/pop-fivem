/* pop_admin : menu liste façon GTA, piloté au clavier depuis Lua (messages "nav"). */
const RES = 'pop_admin';
const $ = (s) => document.querySelector(s);
const MAX_ROWS = 10;

function post(name, data = {}) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).then(r => r.json()).catch(() => ({}));
}

const S = {
    open: false,
    cfg: { keys: {}, weathers: [], pedModels: [], quickVehicles: [] },
    players: [], items: [], jobs: [], vehicles: [], chars: [], logs: [],
    tw: { hour: 12, minute: 0, frozen: false, weather: 'EXTRASUNNY', blackout: false },
    self: {},
};

const sel = {};    // index des listes ←→, par clé
const vals = {};   // valeurs saisies, par clé
let stack = [];    // pile de menus : { id, args, index }
let confirmKey = null;
let input = null;  // saisie en cours

const pad = (n) => String(n).padStart(2, '0');
const money = (n) => `${n > 0 ? '+' : ''}${n} $`;

/* ============== PERSONAS (positions sauvegardées, locales) ============== */
function loadPersonas() { try { return JSON.parse(localStorage.getItem('tab_admin_personas') || '[]'); } catch (e) { return []; } }
function savePersonas(a) { try { localStorage.setItem('tab_admin_personas', JSON.stringify(a)); } catch (e) {} }

/* ============== HELPERS D'ITEMS ============== */
const btn = (label, action, o = {}) => Object.assign({ type: 'button', label, action }, o);
const sub = (label, to, args, o = {}) => Object.assign({ type: 'sub', label, to, args }, o);
const sep = (label) => ({ type: 'sep', label });
const toggle = (label, checked, action, o = {}) => Object.assign({ type: 'toggle', label, checked: !!checked, action }, o);
const list = (label, key, options, o = {}) => Object.assign({ type: 'list', label, key, options }, o);
const field = (label, key, o = {}) => Object.assign({ type: 'input', label, key }, o);

function listIndex(key, options, def = 0) {
    if (!options.length) return 0;
    let i = sel[key];
    if (i === undefined) i = def;
    return Math.max(0, Math.min(options.length - 1, i));
}
function listValue(key, options, def = 0) {
    const o = options[listIndex(key, options, def)];
    return o === undefined ? undefined : (Array.isArray(o) ? o[1] : o);
}
const optLabel = (o) => (Array.isArray(o) ? o[0] : String(o));

const QTY = [1, 5, 10, 25, 50, 100];
const ACCOUNTS = [['Cash', 'money'], ['Banque', 'bank'], ['Argent sale', 'black_money']];
const GROUPS = ['user', 'mod', 'admin', 'superadmin'];
const DURATIONS = [['Permanent', 0], ['1 heure', 60], ['1 jour', 1440], ['1 semaine', 10080], ['1 mois', 43200]];

const findPlayer = (id) => S.players.find(p => p.id === id);
const findJob = (name) => S.jobs.find(j => j.name === name);

/* ============== DÉFINITION DES MENUS ============== */
const MENUS = {
    root: () => ({
        title: 'Administration', sub: 'Menu principal',
        items: [
            sub('Personnel', 'self', null, { desc: 'Noclip, godmode, soins, téléportation.' }),
            sub('Joueurs', 'players', null, { right: String(S.players.length), desc: 'Joueurs connectés et actions.', onEnter: () => post('requestPlayers') }),
            sub('Véhicules', 'vehicles', null, { desc: 'Apparition, réparation, véhicules persistants.' }),
            sub('Items', 'items', null, { desc: 'Donner un item à soi ou à un joueur.', onEnter: () => post('requestItems') }),
            sub('Jobs', 'jobs', null, { desc: 'Jobs, grades et argent des sociétés.', onEnter: () => post('requestJobs') }),
            sub('Monde', 'world', null, { desc: 'Heure, météo et blackout.' }),
            sub('Personnages', 'chars', null, { desc: 'Apparences staff, positions et modèles.', onEnter: () => post('charRequest') }),
            sub('Outils', 'tools', null, { desc: 'Éditeurs et logs de déconnexion.' }),
        ],
    }),

    self: () => {
        const q = (id) => () => post('quickAction', { id });
        return {
            title: 'Personnel', sub: 'Actions sur soi',
            items: [
                toggle('Noclip', S.self.noclip, q('noclip'), { desc: `Raccourci : [${S.cfg.keys.noclip || 'F7'}]. Shift rapide, Alt lent.` }),
                toggle('Godmode', S.self.godmode, q('godmode')),
                toggle('Invisible', S.self.invisible, q('invisible')),
                toggle('Afficher les noms', S.self.shownames, q('shownames')),
                btn('Mode spec', q('spec'), { desc: `Visez un joueur puis [${S.cfg.keys.spec || 'F'}] pour ses options.` }),
                sep('Soins'),
                btn('Se soigner', q('heal')),
                btn('Se réanimer', q('revive')),
                sep('Déplacement'),
                btn('Téléport au point GPS', q('tpm')),
                btn('Copier mes coordonnées', q('copycoords'), { desc: 'Copie un vector4 dans le presse-papiers.' }),
                btn('Nettoyer la zone (50 m)', q('cleararea')),
            ],
        };
    },

    players: () => {
        const items = [btn('Actualiser la liste', () => post('requestPlayers'))];
        const sorted = [...S.players].sort((a, b) => a.id - b.id);
        if (!sorted.length) items.push({ type: 'button', label: 'Aucun joueur', disabled: true });
        sorted.forEach(p => items.push(sub(`[${p.id}] ${p.name}`, 'player', { id: p.id, name: p.name }, {
            right: p.jobLabel || p.job || '',
            desc: `${p.jobLabel || p.job || ''} ${p.grade ? '· ' + p.grade : ''} · groupe ${p.group || 'user'}`,
        })));
        return { title: 'Joueurs', sub: `${S.players.length} connecté(s)`, items };
    },

    player: (a) => {
        const p = findPlayer(a.id) || { id: a.id, name: a.name || `Joueur ${a.id}` };
        const act = (action, extra = {}) => () => post('playerAction', Object.assign({ action, target: p.id }, extra));
        return {
            title: p.name, sub: `ID ${p.id}${p.jobLabel ? ' · ' + p.jobLabel : ''}`,
            items: [
                btn('Aller à', act('goto')),
                btn('Amener', act('bring')),
                btn('Spectate', act('spectate'), { desc: 'Suivre le joueur. [RETOUR] pour quitter.' }),
                btn('Geler', act('freeze')),
                btn('Dégeler', act('unfreeze')),
                btn('Soigner', act('heal')),
                btn('Réanimer', act('revive')),
                btn('Tuer', act('kill'), { confirm: true, danger: true }),
                btn('Expulser', act('kick', { reason: 'Expulsé par un admin' }), { confirm: true, danger: true }),
                sub('Bannir', 'ban', { id: p.id, name: p.name }, { danger: true }),
                sep('Gestion'),
                sub('Argent', 'money', { id: p.id, name: p.name }),
                sub('Job', 'pjob', { id: p.id, name: p.name }, { right: p.jobLabel || '' }),
                list('Groupe', `grp_${p.id}`, GROUPS, {
                    def: Math.max(0, GROUPS.indexOf(p.group || 'user')),
                    desc: '←→ pour choisir, [ENTRÉE] pour appliquer.',
                    action: () => post('playerAction', { action: 'setgroup', target: p.id, group: listValue(`grp_${p.id}`, GROUPS, Math.max(0, GROUPS.indexOf(p.group || 'user'))) }),
                }),
                sub('Donner un item', 'items', { target: p.id, name: p.name }, { onEnter: () => post('requestItems') }),
            ],
        };
    },

    ban: (a) => ({
        title: 'Bannir', sub: a.name,
        items: [
            field('Raison', 'ban_reason', { placeholder: 'Banni' }),
            list('Durée', 'ban_dur', DURATIONS),
            btn('Confirmer le bannissement', () => post('playerAction', {
                action: 'ban', target: a.id,
                reason: vals.ban_reason || 'Banni', minutes: listValue('ban_dur', DURATIONS),
            }), { confirm: true, danger: true }),
        ],
    }),

    money: (a) => ({
        title: 'Argent', sub: a.name,
        items: [
            list('Compte', 'mn_acc', ACCOUNTS),
            field('Montant', 'mn_amount', { numeric: true, desc: 'Négatif pour retirer.' }),
            btn('Valider', () => {
                const amount = parseInt(vals.mn_amount, 10) || 0;
                if (!amount) return;
                post('playerAction', { action: 'money', target: a.id, account: listValue('mn_acc', ACCOUNTS), amount });
            }, { right: vals.mn_amount ? money(parseInt(vals.mn_amount, 10) || 0) : '' }),
        ],
    }),

    pjob: (a) => {
        const jobs = S.jobs.map(j => [j.label, j.name]);
        const jobName = listValue(`pj_job`, jobs);
        const grades = ((findJob(jobName) || {}).grades || []).map(g => [`${g.grade} · ${g.label}`, g.grade]);
        return {
            title: 'Job', sub: a.name,
            items: [
                list('Job', 'pj_job', jobs, { onChange: () => { sel.pj_grade = 0; } }),
                list('Grade', 'pj_grade', grades.length ? grades : [['0', 0]]),
                btn('Définir', () => post('playerAction', {
                    action: 'setjob', target: a.id, job: jobName, grade: listValue('pj_grade', grades.length ? grades : [['0', 0]]),
                })),
            ],
        };
    },

    items: (a) => {
        a = a || {};
        const q = (vals.it_q || '').toLowerCase();
        const targets = [['Moi', null], ...S.players.map(p => [`[${p.id}] ${p.name}`, p.id])];
        const items = [field('Rechercher', 'it_q', { live: true })];
        items.push(list('Quantité', 'it_qty', QTY));
        if (!a.target) items.push(list('Cible', 'it_target', targets));
        items.push(sep(`Items${q ? ' · « ' + vals.it_q + ' »' : ''}`));
        const filtered = S.items.filter(it => !q || (it.label || '').toLowerCase().includes(q) || (it.id || '').toLowerCase().includes(q));
        if (!S.items.length) items.push({ type: 'button', label: 'Chargement / pop_inventory absent', disabled: true });
        filtered.forEach(it => items.push(btn(it.label || it.id, () => post('giveItem', {
            item: it.id, qty: listValue('it_qty', QTY),
            target: a.target || listValue('it_target', targets),
        }), { right: it.id })));
        return { title: 'Items', sub: a.target ? `Pour ${a.name}` : `${filtered.length} item(s)`, items };
    },

    vehicles: () => ({
        title: 'Véhicules', sub: 'Gestion',
        items: [
            field('Modèle', 'veh_model', { placeholder: 'adder' }),
            btn('Faire apparaître', () => post('quickAction', { id: 'spawnveh', model: (vals.veh_model || '').trim() || 'adder' })),
            btn('Réparer mon véhicule', () => post('quickAction', { id: 'fix' })),
            btn('Supprimer mon véhicule', () => post('quickAction', { id: 'dv' })),
            sub('Véhicules persistants', 'persist', null, { onEnter: () => post('requestVehicles') }),
            sep('Apparition rapide'),
            ...S.cfg.quickVehicles.map(m => btn(m, () => post('quickAction', { id: 'spawnveh', model: m }))),
        ],
    }),

    persist: () => {
        const items = [btn('Actualiser', () => post('requestVehicles'))];
        if (!S.vehicles.length) items.push({ type: 'button', label: 'Aucun véhicule persistant', disabled: true });
        S.vehicles.forEach(v => items.push(sub(v.plate, 'persistveh', { plate: v.plate }, { right: v.model || '', desc: v.owner ? `Propriétaire : ${v.owner}` : '' })));
        return { title: 'Persistants', sub: `${S.vehicles.length} véhicule(s)`, items };
    },

    persistveh: (a) => {
        const v = S.vehicles.find(x => x.plate === a.plate) || { plate: a.plate };
        return {
            title: v.plate, sub: v.model || 'Véhicule',
            items: [
                btn('Aller au véhicule', () => post('vehicleAction', { do_: 'goto', plate: v.plate, x: v.x, y: v.y, z: v.z })),
                btn('Supprimer', () => { post('vehicleAction', { do_: 'delete', plate: v.plate }); back(); }, { confirm: true, danger: true }),
            ],
        };
    },

    jobs: () => {
        const items = [sub('Créer un job', 'jobcreate')];
        items.push(sep(`${S.jobs.length} job(s)`));
        S.jobs.forEach(j => items.push(sub(j.label, 'job', { name: j.name }, { right: j.name })));
        return { title: 'Jobs', sub: 'Gestion des jobs', items };
    },

    jobcreate: () => ({
        title: 'Créer un job', sub: 'Nouveau job',
        items: [
            field('Nom technique', 'jc_name', { placeholder: 'mecano' }),
            field('Libellé', 'jc_label', { placeholder: 'Mécano' }),
            btn('Créer', () => {
                if (!vals.jc_name) return;
                post('jobAction', { do_: 'create', name: vals.jc_name.trim(), label: (vals.jc_label || vals.jc_name).trim() });
            }),
        ],
    }),

    job: (a) => {
        const j = findJob(a.name) || { name: a.name, label: a.name, grades: [] };
        const grades = (j.grades || []).map(g => [`${g.grade} · ${g.label}`, g.grade]);
        const gopts = grades.length ? grades : [['0', 0]];
        return {
            title: j.label, sub: j.name,
            items: [
                list('Grade', `jg_${j.name}`, gopts),
                btn('Me mettre ce job', () => post('jobAction', { do_: 'setself', job: j.name, grade: listValue(`jg_${j.name}`, gopts) })),
                sub('Ajouter un grade', 'jobgrade', { name: j.name, label: j.label }),
                field('Argent société', 'js_amount', { numeric: true, desc: 'Montant à ajouter (négatif pour retirer).' }),
                btn('Appliquer à la société', () => {
                    const amount = parseInt(vals.js_amount, 10) || 0;
                    if (amount) post('jobAction', { do_: 'society', job: j.name, amount });
                }),
                btn('Supprimer le job', () => { post('jobAction', { do_: 'delete', job: j.name }); back(); }, { confirm: true, danger: true }),
            ],
        };
    },

    jobgrade: (a) => ({
        title: 'Nouveau grade', sub: a.label,
        items: [
            field('Niveau', 'jg_level', { numeric: true, placeholder: '0' }),
            field('Nom technique', 'jg_name', { placeholder: 'recrue' }),
            field('Libellé', 'jg_label', { placeholder: 'Recrue' }),
            field('Salaire', 'jg_salary', { numeric: true, placeholder: '0' }),
            btn('Ajouter', () => {
                if (!vals.jg_name) return;
                post('jobAction', {
                    do_: 'addgrade', job: a.name, level: parseInt(vals.jg_level, 10) || 0,
                    gname: vals.jg_name.trim(), glabel: (vals.jg_label || vals.jg_name).trim(),
                    salary: parseInt(vals.jg_salary, 10) || 0,
                });
            }),
        ],
    }),

    world: () => {
        const hours = Array.from({ length: 24 }, (_, h) => [`${pad(h)} h`, h]);
        const minutes = [0, 15, 30, 45].map(m => [pad(m), m]);
        const weathers = S.cfg.weathers.length ? S.cfg.weathers : ['EXTRASUNNY'];
        return {
            title: 'Monde', sub: `${pad(S.tw.hour)}:${pad(S.tw.minute)} · ${S.tw.weather}`,
            items: [
                list('Heure', 'tw_h', hours, { def: S.tw.hour }),
                list('Minutes', 'tw_m', minutes, { def: Math.floor(S.tw.minute / 15) }),
                btn("Appliquer l'heure", () => post('setTime', {
                    hour: listValue('tw_h', hours, S.tw.hour), minute: listValue('tw_m', minutes, Math.floor(S.tw.minute / 15)), frozen: S.tw.frozen,
                })),
                toggle("Geler l'heure", S.tw.frozen, () => post('freezeTime', { frozen: !S.tw.frozen })),
                list('Météo', 'tw_w', weathers, {
                    def: Math.max(0, weathers.indexOf(S.tw.weather)),
                    desc: '←→ pour choisir, [ENTRÉE] pour appliquer.',
                    action: () => post('setWeather', { weather: listValue('tw_w', weathers, Math.max(0, weathers.indexOf(S.tw.weather))) }),
                }),
                toggle('Blackout', S.tw.blackout, () => post('setBlackout', { state: !S.tw.blackout })),
            ],
        };
    },

    chars: () => {
        const items = [
            field('Sauvegarder mon apparence', 'ch_label', {
                placeholder: 'Nom du personnage',
                desc: 'Saisissez un nom pour enregistrer votre apparence actuelle.',
                onSubmit: (v) => { if (v) { post('charSave', { label: v }); setTimeout(() => post('charRequest'), 600); } vals.ch_label = ''; },
            }),
            sub('Positions sauvegardées', 'positions'),
            sub('Modèles de ped', 'peds'),
            sep(`Apparences staff (${S.chars.length})`),
        ];
        S.chars.forEach(c => items.push(sub(c.label || c.name || `#${c.id}`, 'char', { id: c.id, label: c.label || c.name })));
        return { title: 'Personnages', sub: 'Staff', items };
    },

    char: (a) => ({
        title: a.label || 'Personnage', sub: 'Apparence staff',
        items: [
            btn('Incarner', () => post('charLoad', { id: a.id })),
            btn('Supprimer', () => { post('charDelete', { id: a.id }); back(); }, { confirm: true, danger: true }),
        ],
    }),

    positions: () => {
        const ps = loadPersonas();
        const items = [field('Sauvegarder ma position', 'pos_label', {
            placeholder: 'Nom de la position',
            onSubmit: (v) => {
                if (!v) return;
                post('persona', { do_: 'save' }).then(c => {
                    if (c && c.x !== undefined) {
                        const arr = loadPersonas();
                        arr.push({ label: v, x: c.x, y: c.y, z: c.z, h: c.h });
                        savePersonas(arr);
                        render();
                    }
                });
                vals.pos_label = '';
            },
        })];
        items.push(sep(`${ps.length} position(s)`));
        ps.forEach((p, i) => items.push(sub(p.label, 'position', { i })));
        return { title: 'Positions', sub: 'Téléportation rapide', items };
    },

    position: (a) => {
        const p = loadPersonas()[a.i] || {};
        return {
            title: p.label || 'Position', sub: p.x !== undefined ? `${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)}` : '',
            items: [
                btn('Aller', () => post('persona', { do_: 'goto', x: p.x, y: p.y, z: p.z, h: p.h, label: p.label })),
                btn('Supprimer', () => { const arr = loadPersonas(); arr.splice(a.i, 1); savePersonas(arr); back(); }, { confirm: true, danger: true }),
            ],
        };
    },

    peds: () => ({
        title: 'Modèles', sub: 'Incarner un ped',
        items: S.cfg.pedModels.map(p => btn(p.label, () => post('persona', { do_: 'model', model: p.model, label: p.label }), { right: p.model })),
    }),

    tools: () => ({
        title: 'Outils', sub: 'Éditeurs',
        items: [
            btn('Éditeur de zones (MapZones)', () => post('openMapZones')),
            btn('Éditeur de portes', () => post('openDoorbuilder')),
            sub('Logs de déconnexion', 'logs', null, { onEnter: () => post('requestLogs') }),
        ],
    }),

    logs: () => {
        const items = [
            btn('Actualiser', () => post('requestLogs')),
            btn('Vider les logs', () => post('clearLogs'), { confirm: true, danger: true }),
            sep(`${S.logs.length} entrée(s)`),
        ];
        S.logs.forEach(l => items.push(btn(l.name || l.ident || '?', () => {
            if (l.x !== undefined) post('logGoto', { x: l.x, y: l.y, z: l.z });
        }, { right: l.category || '', desc: `${l.reason || ''}${l.x !== undefined ? ' · [ENTRÉE] pour aller au point' : ''}` })));
        return { title: 'Logs', sub: 'Déconnexions', items };
    },
};

/* ============== MOTEUR DU MENU ============== */
function current() { return stack[stack.length - 1]; }

function build() {
    const c = current();
    if (!c) return null;
    const fn = MENUS[c.id];
    const m = fn ? fn(c.args) : { title: '?', sub: '', items: [] };
    m.items = m.items || [];
    return m;
}

const selectable = (it) => it && it.type !== 'sep' && !it.disabled;

function fixIndex(m, c, dir = 1) {
    const n = m.items.length;
    if (!n) { c.index = 0; return; }
    if (c.index >= n) c.index = n - 1;
    if (c.index < 0) c.index = 0;
    for (let k = 0; k < n && !selectable(m.items[c.index]); k++) {
        c.index = (c.index + dir + n) % n;
    }
}

function rightHtml(it, isSel) {
    switch (it.type) {
        case 'sub': return `${it.right ? `<span>${esc(it.right)}</span>` : ''}<span class="m-arrow">›</span>`;
        case 'toggle': return `<span class="m-check ${it.checked ? 'on' : ''}"></span>`;
        case 'list': {
            const opts = it.options || [];
            const label = opts.length ? optLabel(opts[listIndex(it.key, opts, it.def || 0)]) : '—';
            return `<span class="m-arrow lr">‹</span><span>${esc(label)}</span><span class="m-arrow lr">›</span>`;
        }
        case 'input': {
            const v = vals[it.key];
            return `<span>${v ? esc(v) : (isSel ? 'Saisir…' : '—')}</span>`;
        }
        default:
            if (confirmKey && isSel && it.confirm) return `<span style="color:var(--accent)">Confirmer ?</span>`;
            return it.right ? `<span>${esc(it.right)}</span>` : '';
    }
}

function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function render() {
    if (!S.open) return;
    const c = current();
    const m = build();
    if (!m) return;
    fixIndex(m, c);
    $('#m-sub').textContent = m.sub ? `${m.title} · ${m.sub}` : m.title;

    const n = m.items.length;
    const selCount = m.items.filter(selectable).length;
    const pos = m.items.slice(0, c.index + 1).filter(selectable).length;
    $('#m-count').textContent = selCount ? `${pos}/${selCount}` : '0/0';

    let start = 0;
    if (n > MAX_ROWS) start = Math.min(Math.max(0, c.index - Math.floor(MAX_ROWS / 2)), n - MAX_ROWS);
    const rows = [];
    for (let i = start; i < Math.min(n, start + MAX_ROWS); i++) {
        const it = m.items[i];
        const isSel = i === c.index;
        const cls = ['m-row'];
        if (it.type === 'sep') cls.push('sep');
        if (isSel) cls.push('sel');
        if (it.disabled) cls.push('disabled');
        if (it.danger) cls.push('danger');
        rows.push(`<div class="${cls.join(' ')}"><span class="m-label">${esc(it.label)}</span><span class="m-right">${it.type === 'sep' ? '' : rightHtml(it, isSel)}</span></div>`);
    }
    $('#m-list').innerHTML = rows.join('');
    $('#m-more').classList.toggle('hidden', n <= MAX_ROWS);

    const it = m.items[c.index];
    let desc = (it && it.desc) || '';
    if (it && it.confirm && confirmKey) desc = 'Appuyez encore sur [ENTRÉE] pour confirmer.';
    $('#m-desc').textContent = desc;
}

function push(id, args) {
    stack.push({ id, args, index: 0 });
    confirmKey = null;
    render();
}

function back() {
    confirmKey = null;
    if (stack.length > 1) {
        stack.pop();
        render();
        return;
    }
    const root = stack[0];
    if (root && root.spec) {
        // Retour au viseur du mode spec
        stack = [];
        hideMenu();
        post('specResume');
        return;
    }
    post('close');
}

function nav(key) {
    if (!S.open || input) return;
    const c = current();
    const m = build();
    if (!c || !m) return;
    fixIndex(m, c);
    const it = m.items[c.index];
    const n = m.items.length;

    if (key === 'up' || key === 'down') {
        const dir = key === 'up' ? -1 : 1;
        if (n) {
            c.index = (c.index + dir + n) % n;
            fixIndex(m, c, dir);
        }
        confirmKey = null;
        render();
    } else if ((key === 'left' || key === 'right') && it && it.type === 'list') {
        const opts = it.options || [];
        if (opts.length) {
            const i = listIndex(it.key, opts, it.def || 0);
            sel[it.key] = (i + (key === 'left' ? -1 : 1) + opts.length) % opts.length;
            if (it.onChange) it.onChange(sel[it.key]);
        }
        render();
    } else if (key === 'enter' && selectable(it)) {
        activate(it, c);
    } else if (key === 'back') {
        back();
    }
}

function activate(it, c) {
    if (it.confirm) {
        const k = `${c.id}:${c.index}`;
        if (confirmKey !== k) { confirmKey = k; render(); return; }
        confirmKey = null;
    }
    switch (it.type) {
        case 'sub':
            if (it.onEnter) it.onEnter();
            push(it.to, it.args);
            break;
        case 'input':
            openInput(it);
            break;
        default:
            if (it.action) it.action();
            render();
    }
}

/* ============== SAISIE TEXTE ============== */
function openInput(it) {
    input = it;
    const box = $('#m-input');
    const f = $('#m-input-field');
    $('#m-input-label').textContent = it.label;
    f.type = 'text';
    f.inputMode = it.numeric ? 'numeric' : 'text';
    f.placeholder = it.placeholder || '';
    f.value = vals[it.key] || '';
    box.classList.remove('hidden');
    post('inputFocus', { focus: true });
    setTimeout(() => { f.focus(); f.select(); }, 30);
}

function closeInput(submit) {
    if (!input) return;
    const it = input;
    const f = $('#m-input-field');
    let v = f.value.trim();
    if (submit) {
        if (it.numeric && v !== '' && isNaN(parseInt(v, 10))) v = '';
        vals[it.key] = v;
        if (it.onSubmit) it.onSubmit(v);
    }
    input = null;
    f.blur();
    $('#m-input').classList.add('hidden');
    post('inputFocus', { focus: false });
    render();
}

$('#m-input-field').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); closeInput(true); }
    else if (e.key === 'Escape') { e.preventDefault(); closeInput(false); }
});

/* ============== AFFICHAGE ============== */
function showMenu(reset) {
    S.open = true;
    if (reset || !stack.length || (stack[0] && stack[0].spec)) stack = [{ id: 'root', index: 0 }];
    $('#spec').classList.add('hidden');
    $('#menu').classList.remove('hidden');
    render();
}

function hideMenu() {
    S.open = false;
    if (input) { input = null; $('#m-input').classList.add('hidden'); }
    $('#menu').classList.add('hidden');
}

function copyText(text) {
    try {
        const ta = document.createElement('textarea');
        ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0';
        document.body.appendChild(ta); ta.focus(); ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
    } catch (e) {}
}

/* ============== MESSAGES DEPUIS LUA ============== */
window.addEventListener('message', (ev) => {
    const m = ev.data || {};
    switch (m.action) {
        case 'config':
            S.cfg = {
                keys: m.keys || {}, weathers: m.weathers || [],
                pedModels: m.pedModels || [], quickVehicles: m.quickVehicles || [],
            };
            $('#sp-hint').innerHTML = `Visez un joueur · <b>[${esc(S.cfg.keys.spec || 'F')}]</b> Options · <b>[${esc(S.cfg.keys.open || 'F6')}]</b> Quitter`;
            break;
        case 'open': showMenu(m.reset === true); break;
        case 'close': hideMenu(); $('#spec').classList.add('hidden'); break;
        case 'nav': nav(m.key); break;
        case 'players': S.players = m.list || []; render(); break;
        case 'items': S.items = m.list || []; render(); break;
        case 'jobs': S.jobs = m.list || []; render(); break;
        case 'vehicles': S.vehicles = m.list || []; render(); break;
        case 'staffChars': S.chars = m.list || []; render(); break;
        case 'logs': S.logs = m.list || []; render(); break;
        case 'timeWeather':
            S.tw = { hour: m.hour, minute: m.minute, frozen: m.frozen, weather: m.weather, blackout: m.blackout };
            render();
            break;
        case 'selfState': S.self = m; render(); break;
        case 'specMode':
            if (m.active) {
                hideMenu();
                $('#spec').classList.remove('hidden');
                $('#sp-target').classList.add('hidden');
            } else {
                $('#spec').classList.add('hidden');
            }
            break;
        case 'specTarget':
            if (!m.sid) { $('#sp-target').classList.add('hidden'); break; }
            $('#sp-target').classList.remove('hidden');
            $('#sp-name').textContent = `[${m.sid}] ${m.name}`;
            $('#sp-dist').textContent = `${m.dist} m`;
            break;
        case 'specOpen':
            $('#spec').classList.add('hidden');
            stack = [{ id: 'player', args: { id: m.sid, name: m.name }, index: 0, spec: true }];
            S.open = true;
            $('#menu').classList.remove('hidden');
            render();
            break;
        case 'copyText': copyText(m.text); break;
    }
});
