let state = { inCrew: false, isOwner: false };

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
    const a = Array.isArray(c) ? c : [200, 70, 190];
    const h = n => Math.max(0, Math.min(255, Math.round(n || 0))).toString(16).padStart(2, '0');
    return `#${h(a[0])}${h(a[1])}${h(a[2])}`;
}

function hexToRgb(hex) {
    const m = String(hex).replace('#', '');
    return [parseInt(m.substr(0, 2), 16), parseInt(m.substr(2, 2), 16), parseInt(m.substr(4, 2), 16)];
}

window.addEventListener('message', (e) => {
    const d = e.data;
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
        $sub().textContent = 'Sans crew';
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
        body.insertAdjacentHTML('beforeend', `<div class="section-label">Invitation</div>`);
        const row = document.createElement('div');
        row.className = 'row';
        row.innerHTML = `<span>${esc(state.invite)}</span>`;
        body.appendChild(row);

        const accept = button('btn btn-primary', '<i class="fa-solid fa-check"></i> Accepter', () => post('accept'));
        const decline = button('btn btn-neutral', '<i class="fa-solid fa-xmark"></i> Refuser', () => post('decline'));
        body.appendChild(accept);
        body.appendChild(decline);
    }

    // Créer un crew
    body.insertAdjacentHTML('beforeend', `<div class="section-label">Créer un crew</div>`);
    body.insertAdjacentHTML('beforeend', `
        <div class="field"><input id="in-tag" maxlength="12" placeholder="Tag (ex: BLLS)"></div>
        <div class="field"><input id="in-label" maxlength="32" placeholder="Nom (ex: Ballas)"></div>
    `);
    const create = button('btn btn-primary', '<i class="fa-solid fa-plus"></i> Créer le crew', () => {
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
            `<div class="hint"><i class="fa-solid fa-crosshairs"></i>Cible un joueur proche et choisis <b>Recruter dans le crew</b> pour l'inviter.</div>`);

        body.insertAdjacentHTML('beforeend', `<div class="section-label">Couleur du crew</div>`);
        const crow = document.createElement('div');
        crow.className = 'row';
        crow.innerHTML = `<span>Couleur (blip / territoire)</span>
            <input type="color" id="crew-color" class="color-input" value="${rgbToHex(state.color)}">`;
        body.appendChild(crow);
        const ci = crow.querySelector('#crew-color');
        ci.addEventListener('change', () => post('setColor', { color: hexToRgb(ci.value) }));
    }

    body.insertAdjacentHTML('beforeend',
        `<div class="section-label">Membres · ${state.memberCount || 0}</div>`);

    (state.members || []).forEach(m => {
        const row = document.createElement('div');
        row.className = 'row';
        const isOwner = m.rank === 'owner';
        row.innerHTML = `<span>${esc(m.name)}</span>
            <span class="rank ${isOwner ? 'owner' : ''}">${isOwner ? 'Chef' : 'Membre'}</span>`;
        body.appendChild(row);
    });

    body.insertAdjacentHTML('beforeend', `<div class="section-label">Actions</div>`);
    if (state.isOwner) {
        body.appendChild(button('btn btn-danger', '<i class="fa-solid fa-ban"></i> Dissoudre le crew', () => post('disband')));
    } else {
        body.appendChild(button('btn btn-danger', '<i class="fa-solid fa-right-from-bracket"></i> Quitter le crew', () => post('leave')));
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
