const RES = 'pop_admin';
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));

function post(name, data = {}) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).then(r => r.json()).catch(() => ({}));
}

const state = {
    cfg: { keys: {}, weathers: [], pedModels: [], quickVehicles: [] },
    players: [],
    items: [],
    jobs: [],
    vehicles: [],
    selPlayer: null,
    selItem: null,
    selJob: null,
    tw: { hour: 12, minute: 0, frozen: false, weather: 'EXTRASUNNY', blackout: false },
};

const win = $('#window');
const pill = $('#pill');
const spec = $('#spec');

/* ============== AFFICHAGE GÉNÉRAL ============== */
function showWindow(view) {
    document.body.classList.remove('hidden');
    pill.classList.add('hidden');
    spec.classList.add('hidden');
    win.classList.remove('hidden');
    setView(view || (win.classList.contains('full') ? 'full' : 'quick'));
}

function setView(view) {
    if (view === 'full') {
        win.classList.add('full');
        $('#quick-view').classList.add('hidden');
        $('#full-view').classList.remove('hidden');
        $('#mode-badge').textContent = 'COMPLET';
    } else {
        win.classList.remove('full');
        $('#full-view').classList.add('hidden');
        $('#quick-view').classList.remove('hidden');
        $('#mode-badge').textContent = 'RAPIDE';
    }
    post('switchView', { view });
}

function toggleView() {
    setView(win.classList.contains('full') ? 'quick' : 'full');
}

function closeAll() {
    document.body.classList.add('hidden');
    win.classList.add('hidden');
    pill.classList.add('hidden');
    spec.classList.add('hidden');
    $('#spec-panel').classList.add('hidden');
}

function minimize() {
    win.classList.add('hidden');
    pill.classList.remove('hidden');
    document.body.classList.remove('hidden');
    post('minimize');
}

/* ============== MESSAGES DEPUIS LUA ============== */
window.addEventListener('message', (ev) => {
    const m = ev.data || {};
    switch (m.action) {
        case 'config': applyConfig(m); break;
        case 'open': showWindow(m.view); break;
        case 'close': closeAll(); break;
        case 'restore': showWindow(); break;
        case 'players': renderPlayers(m.list || []); break;
        case 'items': renderItems(m.list || []); break;
        case 'jobs': renderJobs(m.list || []); break;
        case 'vehicles': renderVehicles(m.list || []); break;
        case 'staffChars': renderStaffChars(m.list || []); break;
        case 'logs': renderLogs(m.list || []); break;
        case 'timeWeather': applyTimeWeather(m); break;
        case 'selfState': applySelfState(m); break;
        case 'specMode': specMode(m.active); break;
        case 'specTarget': specTarget(m); break;
        case 'specOpen': specOpen(m); break;
        case 'copyText': copyText(m.text, m.label); break;
    }
});

let toastTimer = null;
function toast(title, sub) {
    let t = $('#toast');
    if (!t) { t = document.createElement('div'); t.id = 'toast'; document.body.appendChild(t); }
    t.innerHTML = `<b>${esc(title)}</b>${sub ? `<div class="muted small">${esc(sub)}</div>` : ''}`;
    if (toastTimer) clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { if (t) t.remove(); }, 2600);
}

function copyText(text, label) {
    const fallback = () => {
        try {
            const ta = document.createElement('textarea');
            ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0';
            document.body.appendChild(ta); ta.focus(); ta.select();
            document.execCommand('copy');
            document.body.removeChild(ta);
        } catch (e) {}
    };
    try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text).catch(fallback);
        } else { fallback(); }
    } catch (e) { fallback(); }
    toast(label || 'Copié', text);
}

function applyConfig(c) {
    state.cfg = {
        keys: c.keys || {},
        weathers: c.weathers || [],
        pedModels: c.pedModels || [],
        quickVehicles: c.quickVehicles || [],
    };
    $('#pill-key').textContent = state.cfg.keys.reveal || 'G';
    $('#spec-key-hint').textContent = state.cfg.keys.spec || 'F';
    // chips véhicules rapides
    const chips = $('#q-veh-chips');
    chips.innerHTML = '';
    (state.cfg.quickVehicles || []).forEach(v => {
        const c2 = document.createElement('div');
        c2.className = 'chip';
        c2.textContent = v;
        c2.onclick = () => { $('#q-veh').value = v; post('quickAction', { id: 'spawnveh', model: v }); };
        chips.appendChild(c2);
    });
    // modèles persona
    const sel = $('#pe-model');
    sel.innerHTML = '<option value="">— aucun —</option>';
    (state.cfg.pedModels || []).forEach(p => {
        const o = document.createElement('option');
        o.value = p.model; o.textContent = p.label;
        sel.appendChild(o);
    });
    // météos
    const wc = $('#tw-weathers');
    wc.innerHTML = '';
    (state.cfg.weathers || []).forEach(w => {
        const c3 = document.createElement('div');
        c3.className = 'chip';
        c3.dataset.w = w;
        c3.textContent = w;
        c3.onclick = () => post('setWeather', { weather: w });
        wc.appendChild(c3);
    });
    highlightWeather();
    renderPersonas();
}

/* ============== VUE RAPIDE ============== */
$$('.q-btn').forEach(b => {
    b.onclick = () => {
        post('quickAction', { id: b.dataset.q }).then(r => {
            if (r) applySelfState({ noclip: r.noclip, godmode: r.godmode, invisible: r.invisible }, true);
        });
    };
});
$('#q-veh-go').onclick = () => {
    const m = $('#q-veh').value.trim() || 'adder';
    post('quickAction', { id: 'spawnveh', model: m });
};
$('#q-veh').addEventListener('keydown', e => { if (e.key === 'Enter') $('#q-veh-go').click(); });

function applySelfState(s, partial) {
    const map = { noclip: 'noclip', godmode: 'godmode', invisible: 'invisible', spec: 'spec', shownames: 'shownames' };
    Object.keys(map).forEach(k => {
        if (s[k] === undefined) return;
        const btn = $(`.q-btn[data-q="${k}"]`);
        if (btn) btn.classList.toggle('active', !!s[k]);
    });
}

/* ============== TITLEBAR ============== */
$('#btn-close').onclick = () => { closeAll(); post('close'); };
$('#btn-min').onclick = minimize;
$('#btn-tab').onclick = toggleView;

/* drag */
(function dragWindow() {
    const bar = $('#titlebar');
    let dragging = false, ox = 0, oy = 0;
    bar.addEventListener('mousedown', (e) => {
        if (e.target.closest('button')) return;
        dragging = true;
        const r = win.getBoundingClientRect();
        ox = e.clientX - r.left; oy = e.clientY - r.top;
        e.preventDefault();
    });
    window.addEventListener('mousemove', (e) => {
        if (!dragging) return;
        let x = e.clientX - ox, y = e.clientY - oy;
        x = Math.max(0, Math.min(window.innerWidth - 80, x));
        y = Math.max(0, Math.min(window.innerHeight - 40, y));
        win.style.left = x + 'px'; win.style.top = y + 'px';
        pill.style.left = x + 'px'; pill.style.top = y + 'px';
    });
    window.addEventListener('mouseup', () => {
        if (!dragging) return;
        dragging = false;
        try { localStorage.setItem('tab_admin_pos', JSON.stringify({ x: win.style.left, y: win.style.top })); } catch (e) {}
    });
    try {
        const p = JSON.parse(localStorage.getItem('tab_admin_pos') || 'null');
        if (p && p.x) { win.style.left = p.x; win.style.top = p.y; pill.style.left = p.x; pill.style.top = p.y; }
    } catch (e) {}
})();

/* ============== NAVIGATION ONGLETS ============== */
$$('.nav-item').forEach(n => {
    n.onclick = () => {
        $$('.nav-item').forEach(x => x.classList.remove('active'));
        n.classList.add('active');
        const tab = n.dataset.tab;
        $$('.panel').forEach(p => p.classList.toggle('hidden', p.dataset.panel !== tab));
        if (tab === 'players') post('requestPlayers');
        else if (tab === 'items') post('requestItems');
        else if (tab === 'jobs') post('requestJobs');
        else if (tab === 'vehicles') post('requestVehicles');
        else if (tab === 'personas') post('charRequest');
        else if (tab === 'logs') post('requestLogs');
    };
});

/* ============== CLAVIER ============== */
document.addEventListener('keydown', (e) => {
    const tag = (document.activeElement && document.activeElement.tagName) || '';
    const inField = tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA';
    const revealKey = (state.cfg.keys.reveal || 'G').toLowerCase();

    if (e.key === 'Escape') {
        if (!$('#spec-panel').classList.contains('hidden')) { specBack(); return; }
        closeAll(); post('close');
    } else if (e.key === 'Tab') {
        if (inField) return;
        e.preventDefault();
        if (!win.classList.contains('hidden')) toggleView();
    } else if (e.key.toLowerCase() === revealKey) {
        // Même touche que le "—" : réduit la fenêtre quand elle est visible.
        if (inField) return;
        if (!win.classList.contains('hidden') && spec.classList.contains('hidden')) {
            e.preventDefault();
            minimize();
        }
    }
});

/* ============== JOUEURS ============== */
$('#pl-refresh').onclick = () => post('requestPlayers');
$('#pl-search').addEventListener('input', () => renderPlayers(state.players));

function renderPlayers(list) {
    state.players = list;
    $('#pl-count').textContent = `(${list.length})`;
    const q = $('#pl-search').value.toLowerCase();
    const ul = $('#pl-list');
    ul.innerHTML = '';
    list.filter(p => !q || p.name.toLowerCase().includes(q) || String(p.id).includes(q))
        .forEach(p => {
            const li = document.createElement('li');
            li.dataset.id = p.id;
            if (state.selPlayer === p.id) li.classList.add('active');
            const adm = ['owner', 'superadmin', 'admin', 'mod'].includes(p.group);
            li.innerHTML = `
                <span class="li-id">${p.id}</span>
                <div class="li-meta">
                    <div class="li-name">${esc(p.name)}</div>
                    <div class="li-sub">${esc(p.jobLabel || p.job || '')} · ${p.ping}ms</div>
                </div>
                <span class="li-tag ${adm ? 'adm' : ''}">${esc(p.group)}</span>`;
            li.onclick = () => { state.selPlayer = p.id; renderPlayers(state.players); renderPlayerDetail(p); };
            ul.appendChild(li);
        });
    // remplit aussi le select destinataire items
    const tg = $('#it-target');
    const cur = tg.value;
    tg.innerHTML = '<option value="">Moi-même</option>';
    list.forEach(p => {
        const o = document.createElement('option');
        o.value = p.id; o.textContent = `[${p.id}] ${p.name}`;
        tg.appendChild(o);
    });
    tg.value = cur;
    const sel = state.players.find(p => p.id === state.selPlayer);
    if (sel) renderPlayerDetail(sel);
}

function renderPlayerDetail(p) {
    const acts = [
        ['goto', 'Aller à'], ['bring', 'Amener'], ['spectate', 'Spectate'],
        ['freeze', 'Geler'], ['unfreeze', 'Dégeler'], ['heal', 'Soigner'],
        ['revive', 'Réanimer'], ['kill', 'Tuer'], ['kick', 'Kick'],
    ];
    const groups = ['user', 'mod', 'admin', 'superadmin'];
    const accounts = [['money', 'Cash'], ['bank', 'Banque'], ['black_money', 'Sale']];
    const jobOpts = state.jobs.map(j => `<option value="${esc(j.name)}">${esc(j.label)}</option>`).join('');
    const d = $('#pl-detail');
    d.innerHTML = `
        <div class="dt-name">${esc(p.name)}</div>
        <div class="dt-sub">ID ${p.id} · ${esc(p.jobLabel || p.job)} (${esc(p.grade || '')}) · groupe ${esc(p.group)}</div>
        <div class="act-grid">
            ${acts.map(a => `<button class="mini" data-act="${a[0]}">${a[1]}</button>`).join('')}
        </div>
        <div class="form-block">
            <h3>Bannir</h3>
            <div class="row gap wrap">
                <input id="pd-ban-reason" type="text" placeholder="raison">
                <input id="pd-ban-min" type="number" placeholder="minutes (0 = perm)" min="0" style="max-width:140px">
                <button class="danger" id="pd-ban" style="width:auto">Bannir</button>
            </div>
        </div>
        <div class="form-block">
            <h3>Argent</h3>
            <div class="row gap">
                <select id="pd-acc">${accounts.map(a => `<option value="${a[0]}">${a[1]}</option>`).join('')}</select>
                <input id="pd-amount" type="number" placeholder="montant (+/-)">
                <button id="pd-money">OK</button>
            </div>
        </div>
        <div class="form-block">
            <h3>Job</h3>
            <div class="row gap">
                <select id="pd-job">${jobOpts}</select>
                <input id="pd-grade" type="number" value="0" min="0" style="max-width:80px">
                <button id="pd-setjob">Définir</button>
            </div>
        </div>
        <div class="form-block">
            <h3>Groupe</h3>
            <div class="row gap">
                <select id="pd-group">${groups.map(g => `<option value="${g}" ${g === p.group ? 'selected' : ''}>${g}</option>`).join('')}</select>
                <button id="pd-setgroup">Définir</button>
            </div>
        </div>
        <div class="form-block">
            <h3>Donner un item</h3>
            <div class="row gap">
                <input id="pd-item" type="text" placeholder="id item">
                <input id="pd-item-qty" type="number" value="1" min="1" style="max-width:80px">
                <button id="pd-give">Donner</button>
            </div>
        </div>`;
    d.querySelectorAll('button[data-act]').forEach(b => {
        b.onclick = () => {
            const a = b.dataset.act;
            if (a === 'kick') {
                post('playerAction', { action: 'kick', target: p.id, reason: 'Expulsé par un admin' });
            } else {
                post('playerAction', { action: a, target: p.id });
            }
        };
    });
    $('#pd-ban').onclick = () => post('playerAction', {
        action: 'ban', target: p.id,
        reason: $('#pd-ban-reason').value || 'Banni', minutes: parseInt($('#pd-ban-min').value) || 0,
    });
    $('#pd-money').onclick = () => post('playerAction', {
        action: 'money', target: p.id, account: $('#pd-acc').value, amount: parseInt($('#pd-amount').value) || 0,
    });
    $('#pd-setjob').onclick = () => post('playerAction', {
        action: 'setjob', target: p.id, job: $('#pd-job').value, grade: parseInt($('#pd-grade').value) || 0,
    });
    $('#pd-setgroup').onclick = () => post('playerAction', {
        action: 'setgroup', target: p.id, group: $('#pd-group').value,
    });
    $('#pd-give').onclick = () => post('giveItem', {
        item: $('#pd-item').value.trim(), qty: parseInt($('#pd-item-qty').value) || 1, target: p.id,
    });
}

/* ============== ITEMS ============== */
$('#it-search').addEventListener('input', () => renderItems(state.items));
$('#it-give').onclick = () => {
    if (!state.selItem) return;
    post('giveItem', {
        item: state.selItem, qty: parseInt($('#it-qty').value) || 1,
        target: $('#it-target').value || null,
    });
};

function renderItems(list) {
    state.items = list;
    const q = $('#it-search').value.toLowerCase();
    const g = $('#it-grid');
    g.innerHTML = '';
    list.filter(it => !q || (it.label || '').toLowerCase().includes(q) || (it.id || '').toLowerCase().includes(q))
        .forEach(it => {
            const c = document.createElement('div');
            c.className = 'cell' + (state.selItem === it.id ? ' active' : '');
            c.innerHTML = `<div class="c-label">${esc(it.label || it.id)}</div><div class="c-id">${esc(it.id)}</div>`;
            c.onclick = () => {
                state.selItem = it.id;
                $('#it-selected').value = it.label || it.id;
                renderItems(state.items);
            };
            g.appendChild(c);
        });
}

/* ============== PERSONAS ============== */
function loadPersonas() { try { return JSON.parse(localStorage.getItem('tab_admin_personas') || '[]'); } catch (e) { return []; } }
function savePersonas(a) { try { localStorage.setItem('tab_admin_personas', JSON.stringify(a)); } catch (e) {} }

$('#pe-save').onclick = () => {
    const name = $('#pe-name').value.trim();
    if (!name) return;
    const model = $('#pe-model').value;
    post('persona', { do_: 'save' }).then(r => {
        if (!r || r.x === undefined) return;
        const arr = loadPersonas();
        arr.push({ label: name, x: r.x, y: r.y, z: r.z, h: r.h, model });
        savePersonas(arr);
        $('#pe-name').value = '';
        renderPersonas();
    });
};

function renderPersonas() {
    const arr = loadPersonas();
    const ul = $('#pe-list');
    ul.innerHTML = '';
    if (!arr.length) { ul.innerHTML = '<div class="detail-empty">Aucun perso enregistré.</div>'; return; }
    arr.forEach((p, i) => {
        const li = document.createElement('li');
        li.innerHTML = `
            <div class="li-meta">
                <div class="li-name">${esc(p.label)}</div>
                <div class="li-sub">${p.model ? esc(p.model) : 'position seule'} · ${Math.round(p.x)}, ${Math.round(p.y)}</div>
            </div>
            <div class="li-actions">
                <button class="mini" data-go>Aller</button>
                ${p.model ? '<button class="mini" data-model>Incarner</button>' : ''}
                <button class="mini danger" data-del style="width:auto">✕</button>
            </div>`;
        li.querySelector('[data-go]').onclick = () => post('persona', { do_: 'goto', x: p.x, y: p.y, z: p.z, h: p.h, label: p.label });
        const mb = li.querySelector('[data-model]');
        if (mb) mb.onclick = () => post('persona', { do_: 'model', model: p.model, label: p.label });
        li.querySelector('[data-del]').onclick = () => { const a = loadPersonas(); a.splice(i, 1); savePersonas(a); renderPersonas(); };
        ul.appendChild(li);
    });
}

/* ============== DOUBLE PERSONNAGE (STAFF) ============== */
state.staffChars = [];

$('#sc-refresh').onclick = () => post('charRequest');
$('#sc-save').onclick = () => {
    const label = $('#sc-name').value.trim();
    post('charSave', { label }).then(r => {
        if (r && r.ok) { $('#sc-name').value = ''; }
    });
};

function fmtDate(epoch) {
    if (!epoch) return '';
    const d = new Date(epoch * 1000);
    const p = n => String(n).padStart(2, '0');
    return `${p(d.getDate())}/${p(d.getMonth() + 1)} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

function renderStaffChars(list) {
    state.staffChars = list;
    const ul = $('#sc-list');
    ul.innerHTML = '';
    if (!list.length) {
        ul.innerHTML = '<div class="detail-empty">Aucun personnage sauvegardé.</div>';
        return;
    }
    list.forEach(c => {
        const li = document.createElement('li');
        const sex = c.sex === 1 ? 'Femme' : 'Homme';
        li.innerHTML = `
            <div class="li-meta">
                <div class="li-name">${esc(c.label)}</div>
                <div class="li-sub">${sex}${c.name ? ' · ' + esc(c.name) : ''} · ${esc(fmtDate(c.savedAt))}</div>
            </div>
            <div class="li-actions">
                <button class="mini" data-load>Incarner</button>
                <button class="mini danger" data-del style="width:auto">✕</button>
            </div>`;
        li.querySelector('[data-load]').onclick = () => post('charLoad', { id: c.id });
        li.querySelector('[data-del]').onclick = () => post('charDelete', { id: c.id });
        ul.appendChild(li);
    });
}

/* ============== LOGS DÉCONNEXION ============== */
state.logs = [];
state.logCat = '';

const LOG_CATS = {
    quit:    { label: 'Quitté / Alt+F4', color: '154, 167, 255' },
    timeout: { label: 'Timeout', color: '224, 162, 59' },
    crash:   { label: 'Crash', color: '239, 91, 106' },
    kick:    { label: 'Kick', color: '224, 123, 59' },
    ban:     { label: 'Ban', color: '239, 91, 106' },
    other:   { label: 'Autre', color: '138, 143, 153' },
};
function logBadgeStyle(rgb) {
    return `color:rgb(${rgb});background:rgba(${rgb},0.16);border:1px solid rgba(${rgb},0.45)`;
}

$('#lg-refresh').onclick = () => post('requestLogs');
$('#lg-clear').onclick = () => {
    if (confirm('Vider tous les logs de déconnexion ?')) post('clearLogs');
};
$('#lg-search').addEventListener('input', () => renderLogs(state.logs));

function logTime(epoch) {
    if (!epoch) return '';
    const d = new Date(epoch * 1000);
    const p = n => String(n).padStart(2, '0');
    return `${p(d.getDate())}/${p(d.getMonth() + 1)} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
}

function renderLogFilters() {
    const wrap = $('#lg-filters');
    wrap.innerHTML = '';
    const mk = (key, label) => {
        const c = document.createElement('div');
        c.className = 'chip' + (state.logCat === key ? ' active' : '');
        c.textContent = label;
        c.onclick = () => { state.logCat = state.logCat === key ? '' : key; renderLogs(state.logs); };
        wrap.appendChild(c);
    };
    mk('', 'Tous');
    Object.keys(LOG_CATS).forEach(k => mk(k, LOG_CATS[k].label));
}

function renderLogs(list) {
    state.logs = list;
    $('#lg-count').textContent = `(${list.length})`;
    renderLogFilters();
    const q = $('#lg-search').value.toLowerCase();
    const ul = $('#lg-list');
    ul.innerHTML = '';
    const filtered = list.filter(l => {
        if (state.logCat && l.category !== state.logCat) return false;
        if (!q) return true;
        return (l.name || '').toLowerCase().includes(q)
            || (l.reason || '').toLowerCase().includes(q)
            || (l.ident || '').toLowerCase().includes(q)
            || String(l.id || '').includes(q);
    });
    if (!filtered.length) {
        ul.innerHTML = '<div class="detail-empty">Aucune déconnexion enregistrée.</div>';
        return;
    }
    filtered.forEach(l => {
        const cat = LOG_CATS[l.category] || LOG_CATS.other;
        const hasPos = l.x !== undefined && l.x !== null;
        const li = document.createElement('li');
        li.innerHTML = `
            <span class="log-badge" style="${logBadgeStyle(cat.color)}">${esc(l.catLabel || cat.label)}</span>
            <div class="li-meta">
                <div class="li-name">${esc(l.name || '?')} <span class="muted small">[${l.id || '?'}]</span></div>
                <div class="li-sub">${esc(logTime(l.time))}${l.by ? ' · par ' + esc(l.by) : ''}${l.ident ? ' · ' + esc(l.ident) : ''}</div>
                <div class="li-sub log-reason">${esc(l.reason || '')}</div>
            </div>
            <div class="li-actions">
                ${hasPos ? '<button class="mini" data-go>Aller</button>' : ''}
            </div>`;
        const gb = li.querySelector('[data-go]');
        if (gb) gb.onclick = () => post('logGoto', { x: l.x, y: l.y, z: l.z });
        ul.appendChild(li);
    });
}

/* ============== VÉHICULES ============== */
$('#ve-refresh').onclick = () => post('requestVehicles');
$('#ve-search').addEventListener('input', () => renderVehicles(state.vehicles));

function renderVehicles(list) {
    state.vehicles = list;
    $('#ve-count').textContent = `(${list.length})`;
    const q = $('#ve-search').value.toLowerCase();
    const ul = $('#ve-list');
    ul.innerHTML = '';
    list.filter(v => !q || (v.plate || '').toLowerCase().includes(q) || (v.model || '').toLowerCase().includes(q))
        .forEach(v => {
            const li = document.createElement('li');
            li.innerHTML = `
                <div class="li-meta">
                    <div class="li-name">${esc(v.plate)} <span class="muted small">${esc(String(v.model || ''))}</span></div>
                    <div class="li-sub">${esc(v.owner || '?')} · ${Math.round(v.x)}, ${Math.round(v.y)}</div>
                </div>
                <div class="li-actions">
                    <button class="mini" data-go>Aller</button>
                    <button class="mini danger" data-del style="width:auto">Suppr</button>
                </div>`;
            li.querySelector('[data-go]').onclick = () => post('vehicleAction', { do_: 'goto', plate: v.plate, x: v.x, y: v.y, z: v.z });
            li.querySelector('[data-del]').onclick = () => post('vehicleAction', { do_: 'delete', plate: v.plate });
            ul.appendChild(li);
        });
}

/* ============== TEMPS & MÉTÉO ============== */
$('#tw-hour').addEventListener('input', updateClockPreview);
$('#tw-min').addEventListener('input', updateClockPreview);
$('#tw-apply').onclick = () => post('setTime', {
    hour: parseInt($('#tw-hour').value), minute: parseInt($('#tw-min').value), frozen: $('#tw-freeze').checked,
});
$('#tw-freeze').addEventListener('change', () => post('freezeTime', { frozen: $('#tw-freeze').checked }));
$('#tw-blackout').addEventListener('change', () => post('setBlackout', { state: $('#tw-blackout').checked }));

function updateClockPreview() {
    const h = parseInt($('#tw-hour').value), m = parseInt($('#tw-min').value);
    $('#tw-h-val').textContent = h;
    $('#tw-m-val').textContent = String(m).padStart(2, '0');
    $('#tw-clock').textContent = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

function applyTimeWeather(m) {
    state.tw = { hour: m.hour, minute: m.minute, frozen: m.frozen, weather: m.weather, blackout: m.blackout };
    $('#tw-hour').value = m.hour;
    $('#tw-min').value = m.minute;
    $('#tw-freeze').checked = !!m.frozen;
    $('#tw-blackout').checked = !!m.blackout;
    updateClockPreview();
    highlightWeather();
}

function highlightWeather() {
    $$('#tw-weathers .chip').forEach(c => c.classList.toggle('active', c.dataset.w === state.tw.weather));
}

/* ============== JOBS ============== */
$('#jb-refresh').onclick = () => post('requestJobs');
$('#jb-self').onclick = () => { if (state.selJob) post('jobAction', { do_: 'setself', job: state.selJob, grade: parseInt($('#jb-self-grade').value) || 0 }); };
$('#jb-create').onclick = () => post('jobAction', { do_: 'create', name: $('#jb-new-name').value.trim(), label: $('#jb-new-label').value.trim() });
$('#jb-addgrade').onclick = () => { if (state.selJob) post('jobAction', { do_: 'addgrade', job: state.selJob, level: parseInt($('#jb-g-level').value) || 0, gname: $('#jb-g-name').value.trim(), glabel: $('#jb-g-label').value.trim(), salary: parseInt($('#jb-g-salary').value) || 0 }); };
$('#jb-society').onclick = () => { if (state.selJob) post('jobAction', { do_: 'society', job: state.selJob, amount: parseInt($('#jb-soc-amount').value) || 0 }); };
$('#jb-delete').onclick = () => { if (state.selJob) post('jobAction', { do_: 'delete', job: state.selJob }); };

function renderJobs(list) {
    state.jobs = list;
    $('#jb-count').textContent = `(${list.length})`;
    const ul = $('#jb-list');
    ul.innerHTML = '';
    list.forEach(j => {
        const li = document.createElement('li');
        if (state.selJob === j.name) li.classList.add('active');
        li.innerHTML = `<div class="li-meta"><div class="li-name">${esc(j.label)}</div><div class="li-sub">${esc(j.name)} · ${(j.grades || []).length} grades</div></div>`;
        li.onclick = () => { state.selJob = j.name; $('#jb-selected-label').textContent = `Job sélectionné : ${j.label} (${j.name})`; renderJobs(state.jobs); };
        ul.appendChild(li);
    });
}

/* ============== MAPZONES ============== */
$('#open-mapzones').onclick = () => post('openMapZones');

/* ============== DOORBUILDER ============== */
$('#open-doorbuilder').onclick = () => post('openDoorbuilder');

/* ============== MODE SPEC ============== */
function specMode(active) {
    if (active) {
        document.body.classList.remove('hidden');
        win.classList.add('hidden');
        pill.classList.add('hidden');
        spec.classList.remove('hidden');
        $('#spec-panel').classList.add('hidden');
        $('#spec-target').classList.add('hidden');
    } else {
        spec.classList.add('hidden');
        $('#spec-panel').classList.add('hidden');
    }
}

function specTarget(m) {
    const t = $('#spec-target');
    if (!m.sid) { t.classList.add('hidden'); return; }
    t.classList.remove('hidden');
    t.querySelector('.st-name').textContent = m.name;
    t.querySelector('.st-dist').textContent = `${m.dist}m`;
}

function specOpen(m) {
    const acts = [
        ['spectate', 'Spectate'], ['goto', 'Aller à'], ['bring', 'Amener'],
        ['freeze', 'Geler'], ['unfreeze', 'Dégeler'], ['heal', 'Soigner'],
        ['revive', 'Réanimer'], ['kill', 'Tuer'], ['kick', 'Kick'],
    ];
    $('#sp-name').textContent = m.name;
    const g = $('#sp-actions');
    g.innerHTML = '';
    acts.forEach(a => {
        const b = document.createElement('button');
        b.className = 'mini';
        b.textContent = a[1];
        b.onclick = () => {
            post('playerAction', { action: a[0], target: m.sid, reason: 'Expulsé par un admin' });
            specBack();
        };
        g.appendChild(b);
    });
    $('#spec-target').classList.add('hidden');
    $('#spec-panel').classList.remove('hidden');
}

function specBack() {
    $('#spec-panel').classList.add('hidden');
    post('specResume');
}
$('#sp-back').onclick = specBack;

/* ============== UTIL ============== */
function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

/* ============== INPUT FOCUS HANDLERS ============== */
document.addEventListener('focusin', (e) => {
    const tag = e.target.tagName;
    const type = e.target.type;
    const isInput = tag === 'INPUT' && (type === 'text' || type === 'number' || type === 'password' || type === 'search');
    if (isInput || tag === 'TEXTAREA') {
        post('inputFocus', { focus: true });
    }
});

document.addEventListener('focusout', (e) => {
    const tag = e.target.tagName;
    const type = e.target.type;
    const isInput = tag === 'INPUT' && (type === 'text' || type === 'number' || type === 'password' || type === 'search');
    if (isInput || tag === 'TEXTAREA') {
        post('inputFocus', { focus: false });
    }
});

