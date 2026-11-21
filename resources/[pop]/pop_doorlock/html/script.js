const body       = document.body;
const hubView    = document.getElementById('hub-view');
const formView   = document.getElementById('form-view');
const detailView = document.getElementById('detail-view');

const groupList  = document.getElementById('groupList');
const groupTotal = document.getElementById('groupTotal');

const doorCount     = document.getElementById('doorCount');
const labelInput    = document.getElementById('label');
const distanceInput = document.getElementById('distance');
const lockedInput   = document.getElementById('locked');
const errorBox      = document.getElementById('error');

const detailTitle      = document.getElementById('detailTitle');
const detailLabel      = document.getElementById('detailLabel');
const detailDistance   = document.getElementById('detailDistance');
const detailLocked     = document.getElementById('detailLocked');
const keyStatus        = document.getElementById('keyStatus');
const keyActions       = document.getElementById('key-actions');
const doorList         = document.getElementById('doorList');
const detailDoorTotal  = document.getElementById('detailDoorTotal');

const RESOURCE = 'pop_doorlock';
let currentGid = null;

function post(name, data) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).catch(() => {});
}

function showWindow() { body.classList.remove('hidden'); }
function hideAll() {
    body.classList.add('hidden');
    hubView.classList.add('hidden');
    formView.classList.add('hidden');
    detailView.classList.add('hidden');
}

/* ---------- HUB ---------- */
function renderHub(groups) {
    groups = groups || [];
    groupTotal.textContent = groups.length;
    groupList.innerHTML = '';

    if (groups.length === 0) {
        groupList.innerHTML = '<div class="empty">Aucun groupe.</div>';
    } else {
        groups.forEach((g) => {
            const li = document.createElement('li');
            li.style.cursor = 'pointer';
            li.title = 'Cliquer pour configurer ce groupe';
            li.onclick = () => post('openDetail', { gid: g.gid });

            const id = document.createElement('span');
            id.className = 'li-id';
            id.textContent = '#' + g.gid;
            li.appendChild(id);

            const meta = document.createElement('div');
            meta.className = 'li-meta';
            const access = g.hasKey ? '🔑 clé' : (g.source === 'config' ? 'job' : '—');
            const origin = g.source === 'config' ? 'config.lua' : 'doorbuilder';
            meta.innerHTML = `<div class="li-name">${g.label || ('Groupe ' + g.gid)}</div>
                <div class="li-sub">${g.count} porte(s) · ${access} · ${origin}</div>`;
            li.appendChild(meta);

            const actions = document.createElement('div');
            actions.className = 'li-actions';

            if (g.hasKey) {
                const giveBtn = document.createElement('button');
                giveBtn.className = 'mini key';
                giveBtn.textContent = '🔑';
                giveBtn.title = 'Recevoir la clé de ce groupe';
                giveBtn.onclick = (e) => { e.stopPropagation(); post('giveKey', { gid: g.gid }); };
                actions.appendChild(giveBtn);
            }

            const del = document.createElement('button');
            del.className = 'mini danger';
            del.textContent = '🗑';
            del.title = g.source === 'config' ? 'Désactiver ce groupe (config.lua)' : 'Supprimer ce groupe';
            del.onclick = (e) => {
                e.stopPropagation();
                const verb = g.source === 'config' ? 'Désactiver' : 'Supprimer';
                if (confirm(`${verb} le groupe "${g.label}" (${g.count} porte(s)) ?`)) {
                    post('deleteGroup', { gid: g.gid });
                }
            };
            actions.appendChild(del);

            li.appendChild(actions);
            groupList.appendChild(li);
        });
    }

    showWindow();
    formView.classList.add('hidden');
    detailView.classList.add('hidden');
    hubView.classList.remove('hidden');
}

/* ---------- FORMULAIRE (création) ---------- */
function showForm(count) {
    doorCount.textContent = count || 0;
    errorBox.classList.add('hidden');
    labelInput.value = '';
    distanceInput.value = '2.5';
    lockedInput.checked = true;

    showWindow();
    hubView.classList.add('hidden');
    detailView.classList.add('hidden');
    formView.classList.remove('hidden');
    setTimeout(() => labelInput.focus(), 30);
}

function saveForm() {
    const label = labelInput.value.trim();
    if (!label) {
        errorBox.classList.remove('hidden');
        labelInput.focus();
        return;
    }
    post('saveForm', {
        label: label,
        distance: parseFloat(distanceInput.value) || 2.5,
        locked: lockedInput.checked,
    });
    hideAll();
}

/* ---------- DÉTAIL / CONFIG D'UN GROUPE ---------- */
function renderDetail(detail) {
    if (!detail) { return; }
    currentGid = detail.gid;

    detailTitle.textContent = `#${detail.gid} — ${detail.label}`;
    detailLabel.value = detail.label;
    detailDistance.value = detail.distance;
    detailLocked.checked = !!detail.locked;

    keyActions.innerHTML = '';
    if (detail.hasKey) {
        keyStatus.textContent = 'ACTIVE';
        keyStatus.className = 'li-tag adm';

        const give = document.createElement('button');
        give.className = 'key';
        give.textContent = '🔑 Recevoir la clé';
        give.onclick = () => post('giveKey', { gid: currentGid });
        keyActions.appendChild(give);

        const regen = document.createElement('button');
        regen.className = 'danger';
        regen.textContent = '♻ Régénérer la clé';
        regen.title = 'Génère une nouvelle clé : les anciennes ne fonctionneront plus';
        regen.onclick = () => {
            if (confirm('Régénérer la clé ? Toutes les clés déjà distribuées pour ce groupe arrêteront de fonctionner.')) {
                post('regenKey', { gid: currentGid });
            }
        };
        keyActions.appendChild(regen);
    } else {
        keyStatus.textContent = detail.source === 'config' ? 'JOB' : 'AUCUNE';
        keyStatus.className = 'li-tag';

        const assign = document.createElement('button');
        assign.className = 'primary';
        assign.textContent = '+ Attribuer une clé à ce groupe';
        assign.title = 'Remplace la condition de job par une clé unique';
        assign.onclick = () => post('assignKey', { gid: currentGid });
        keyActions.appendChild(assign);
    }

    detailDoorTotal.textContent = detail.doors.length;
    doorList.innerHTML = '';
    detail.doors.forEach((d) => {
        const li = document.createElement('li');

        const id = document.createElement('span');
        id.className = 'li-id';
        id.textContent = '#' + d.doorId;
        li.appendChild(id);

        const meta = document.createElement('div');
        meta.className = 'li-meta';
        meta.innerHTML = `<div class="li-name">${d.model}</div>
            <div class="li-sub">${d.state ? 'Verrouillée' : 'Déverrouillée'}</div>`;
        li.appendChild(meta);

        const actions = document.createElement('div');
        actions.className = 'li-actions';
        const del = document.createElement('button');
        del.className = 'mini danger';
        del.textContent = '🗑';
        del.title = 'Retirer cette porte du groupe';
        del.onclick = () => {
            if (confirm('Retirer cette porte du groupe ?')) {
                post('removeDoor', { gid: currentGid, doorId: d.doorId });
            }
        };
        actions.appendChild(del);
        li.appendChild(actions);

        doorList.appendChild(li);
    });

    showWindow();
    hubView.classList.add('hidden');
    formView.classList.add('hidden');
    detailView.classList.remove('hidden');
}

function saveDetail() {
    if (!currentGid) return;
    post('updateGroup', {
        gid: currentGid,
        label: detailLabel.value.trim(),
        distance: parseFloat(detailDistance.value) || 2.5,
        locked: detailLocked.checked,
    });
}

/* ---------- MESSAGES NUI ---------- */
window.addEventListener('message', (e) => {
    const msg = e.data || {};
    if (msg.action === 'hub') renderHub(msg.groups);
    else if (msg.action === 'form') showForm(msg.count);
    else if (msg.action === 'detail') renderDetail(msg.detail);
});

/* ---------- BOUTONS ---------- */
document.getElementById('create').onclick     = () => { post('startSelection'); hideAll(); };
document.getElementById('closeHub').onclick   = () => { post('closeHub'); hideAll(); };
document.getElementById('saveForm').onclick   = saveForm;
document.getElementById('cancelForm').onclick = () => { post('cancelForm'); hideAll(); };

document.getElementById('backToHub').onclick   = () => post('backToHub');
document.getElementById('saveDetail').onclick  = saveDetail;
document.getElementById('deleteFromDetail').onclick = () => {
    if (!currentGid) return;
    if (confirm('Supprimer (ou désactiver) ce groupe entier et toutes ses portes ?')) {
        post('deleteGroup', { gid: currentGid });
    }
};

document.addEventListener('keyup', (e) => {
    if (!formView.classList.contains('hidden')) {
        if (e.key === 'Enter') saveForm();
        if (e.key === 'Escape') { post('cancelForm'); hideAll(); }
    } else if (!detailView.classList.contains('hidden')) {
        if (e.key === 'Escape') post('backToHub');
    } else if (!hubView.classList.contains('hidden')) {
        if (e.key === 'Escape') { post('closeHub'); hideAll(); }
    }
});
