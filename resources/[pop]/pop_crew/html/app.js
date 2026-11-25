let state = { inCrew: false, isOwner: false };
let locale = {};
let opts = { maxTag: 12, maxLabel: 32, targetMode: 'ox_target', keyLabel: 'E' };

// Texte traduit (envoyé par le Lua : GetLocaleTable), avec %s / %d remplacés dans l'ordre
function T(key, ...args) {
    let s = locale[key];
    if (typeof s !== 'string') return key;
    let i = 0;
    return s.replace(/%[sd]/g, () => (i < args.length ? String(args[i++]) : ''));
}

function applyLocale(data) {
    locale = data || {};
    document.documentElement.dir = locale._rtl ? 'rtl' : 'ltr';
    document.documentElement.lang = locale._lang || 'fr';
    document.querySelectorAll('[data-i18n]').forEach(el => { el.textContent = T(el.dataset.i18n); });
}

const $app = () => document.getElementById('app');
const $body = () => document.getElementById('body');
const $sub = () => document.getElementById('subtitle');

function post(name, data) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {})
    });
}

function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[c]));
}

function rgbToHex(c) {
    const a = Array.isArray(c) ? c : [93, 144, 236];
    const h = n => Math.max(0, Math.min(255, Math.round(n || 0))).toString(16).padStart(2, '0');
    return `#${h(a[0])}${h(a[1])}${h(a[2])}`;
}

function hexToRgb(hex) {
    const m = String(hex).replace('#', '');
    return [parseInt(m.substr(0, 2), 16), parseInt(m.substr(2, 2), 16), parseInt(m.substr(4, 2), 16)];
}

window.addEventListener('message', (e) => {
    const d = e.data;
    if (d.action === 'locale' || d.type === 'locale') {
        applyLocale(d.data);
        if (d.opts) opts = Object.assign(opts, d.opts);
        if ($app().style.display !== 'none') render();
        return;
    }
    if (d.type === 'open') {
        state = d.state || {};
        $app().style.display = 'flex';
        render();
    } else if (d.type === 'state') {
        state = d.state || {};
        if ($app().style.display !== 'none') render();
    } else if (d.type === 'close') {
        $app().style.display = 'none';
    }
});

function render() {
    const body = $body();
    body.innerHTML = '';

    // Sous-titre
    if (state.inCrew) {
        $sub().innerHTML = `<span class="crew-dot" style="background:${rgbToHex(state.color)}"></span>${esc(state.label)}<span class="tag">[${esc(state.tag)}]</span>`;
    } else {
        $sub().textContent = T('ui_no_crew');
    }

    if (!state.inCrew) {
        renderNoCrew(body);
    } else {
        renderInCrew(body);
    }
}

function renderNoCrew(body) {
    // Invitation en attente
    if (state.invite) {
        body.insertAdjacentHTML('beforeend', `<div class="section-label">${esc(T('ui_invitation'))}</div>`);
        const row = document.createElement('div');
        row.className = 'row';
        row.innerHTML = `<span>${esc(state.invite)}</span>`;
        body.appendChild(row);

        const accept = button('btn btn-primary', `<i class="fa-solid fa-check"></i> ${esc(T('ui_accept'))}`, () => post('accept'));
        const decline = button('btn btn-neutral', `<i class="fa-solid fa-xmark"></i> ${esc(T('ui_decline'))}`, () => post('decline'));
        body.appendChild(accept);
        body.appendChild(decline);
    }

    // Créer un crew
    body.insertAdjacentHTML('beforeend', `<div class="section-label">${esc(T('ui_create_section'))}</div>`);
    body.insertAdjacentHTML('beforeend', `
        <div class="field"><input id="in-tag" maxlength="${opts.maxTag}" placeholder="${esc(T('ui_tag_placeholder'))}"></div>
        <div class="field"><input id="in-label" maxlength="${opts.maxLabel}" placeholder="${esc(T('ui_label_placeholder'))}"></div>
    `);
    const create = button('btn btn-primary', `<i class="fa-solid fa-plus"></i> ${esc(T('ui_create_btn'))}`, () => {
        const tag = (document.getElementById('in-tag').value || '').trim();
        const label = (document.getElementById('in-label').value || '').trim();
        if (tag.length < 2) return;
        post('create', { tag, label: label || tag });
    });
    body.appendChild(create);
}

function renderInCrew(body) {
    if (state.isOwner) {
        body.insertAdjacentHTML('beforeend',
            `<div class="hint"><i class="fa-solid fa-crosshairs"></i>${opts.targetMode === 'prompt'
                ? esc(T('ui_hint_key', opts.keyLabel))
                : T('ui_hint_target', '<b>' + esc(T('target_recruit')) + '</b>')}</div>`);

        body.insertAdjacentHTML('beforeend', `<div class="section-label">${esc(T('ui_color_section'))}</div>`);
        const crow = document.createElement('div');
        crow.className = 'row';
        crow.innerHTML = `<span>${esc(T('ui_color_label'))}</span>
            <input type="color" id="crew-color" class="color-input" value="${rgbToHex(state.color)}">`;
        body.appendChild(crow);
        const ci = crow.querySelector('#crew-color');
        ci.addEventListener('change', () => post('setColor', { color: hexToRgb(ci.value) }));
    }

    body.insertAdjacentHTML('beforeend',
        `<div class="section-label">${esc(T('ui_members', state.memberCount || 0))}</div>`);

    (state.members || []).forEach(m => {
        const row = document.createElement('div');
        row.className = 'row';
        const isOwner = m.rank === 'owner';
        row.innerHTML = `<span>${esc(m.name)}</span>
            <span class="rank ${isOwner ? 'owner' : ''}">${esc(isOwner ? T('ui_rank_owner') : T('ui_rank_member'))}</span>`;
        body.appendChild(row);
    });

    body.insertAdjacentHTML('beforeend', `<div class="section-label">${esc(T('ui_actions'))}</div>`);
    if (state.isOwner) {
        body.appendChild(button('btn btn-danger', `<i class="fa-solid fa-ban"></i> ${esc(T('ui_disband'))}`, () => post('disband')));
    } else {
        body.appendChild(button('btn btn-danger', `<i class="fa-solid fa-right-from-bracket"></i> ${esc(T('ui_leave'))}`, () => post('leave')));
    }
}

function button(cls, html, onClick) {
    const b = document.createElement('div');
    b.className = cls;
    b.innerHTML = html;
    b.onclick = onClick;
    return b;
}

document.getElementById('close-btn').onclick = () => post('close');

window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') post('close');
});
