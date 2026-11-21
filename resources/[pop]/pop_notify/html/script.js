window.addEventListener('message', function(event) {
    if (event.data.action === 'notify') {
        createNotification(event.data.data);
    } else if (event.data.action === 'setRaised') {
        // Positionne les notifications juste au-dessus de la checklist mécano.
        // event.data.bottom = position (px depuis le bas) calculée selon la hauteur
        // réelle de la liste ; absente -> on revient à la position par défaut (CSS).
        const c = document.getElementById('notify-container');
        if (c) {
            c.style.bottom = event.data.state ? ((event.data.bottom || 390) + 'px') : '';
        }
    } else if (event.data.action === 'checklist') {
        handleChecklistMessage(event.data);
    }
});

// --- Checklist persistante (livraisons GoPostal, etc.) intégrée dans la
// même pile que les notifications : mêmes dimensions/position/échelle,
// aucun calcul de superposition à faire depuis un autre script.
const checklistSteps = {};

function renderChecklistSteps() {
    const container = document.getElementById('checklist-steps');
    if (!container) return;
    container.innerHTML = '';
    Object.keys(checklistSteps).sort((a, b) => a - b).forEach((n) => {
        const s = checklistSteps[n];
        const row = document.createElement('div');
        row.className = 'checklist-step' + (s.done ? ' done' : '');
        row.innerHTML = '<span class="cl-check">' + (s.done ? '✔' : '-') + '</span>' + safeHtml(s.label);
        container.appendChild(row);
    });
}

function showChecklistCard(title) {
    if (document.getElementById('checklist-card')) return;
    const container = document.getElementById('notify-container');
    if (!container) return;
    container.insertAdjacentHTML('afterbegin', `
        <div class="notif-card checklist-style" id="checklist-card">
            <div class="checklist-title" id="checklist-title">${safeHtml(title || 'LIVRAISON')}</div>
            <div class="checklist-steps" id="checklist-steps"></div>
        </div>`);
}

function hideChecklistCard() {
    const el = document.getElementById('checklist-card');
    if (el) el.remove();
    for (const k in checklistSteps) delete checklistSteps[k];
}

function handleChecklistMessage(data) {
    if (data.type === 'show') {
        if (data.visible) {
            showChecklistCard(data.title);
        } else {
            hideChecklistCard();
        }
    } else if (data.type === 'reset') {
        for (const k in checklistSteps) delete checklistSteps[k];
        renderChecklistSteps();
    } else if (data.type === 'step') {
        const cur = checklistSteps[data.step] || { label: '' };
        checklistSteps[data.step] = { label: data.label !== undefined ? data.label : cur.label, done: !!data.done };
        renderChecklistSteps();
    }
}

// ── Sécurité : seul un HTML simple est accepté dans les textes ──────────────
// Balises autorisées : span (style color / font-weight / font-style), br, b, strong, i, em.
const ALLOWED_TAGS = { SPAN: true, BR: true, B: true, STRONG: true, I: true, EM: true };
const ALLOWED_STYLES = ['color', 'font-weight', 'font-style'];

function escapeHtml(str) {
    return String(str ?? '').replace(/[&<>"'`]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;', '`': '&#96;' }[c]));
}

function cleanNode(node, out) {
    node.childNodes.forEach(child => {
        if (child.nodeType === Node.TEXT_NODE) {
            out.appendChild(document.createTextNode(child.textContent));
        } else if (child.nodeType === Node.ELEMENT_NODE && ALLOWED_TAGS[child.tagName]) {
            const el = document.createElement(child.tagName.toLowerCase());
            if (child.tagName === 'SPAN' || child.tagName === 'I') {
                ALLOWED_STYLES.forEach(prop => {
                    const v = child.style.getPropertyValue(prop);
                    if (v && !/url\(|expression/i.test(v)) el.style.setProperty(prop, v);
                });
                // Icônes Font Awesome (<i class="fas fa-...">) : classes simples seulement
                if (child.tagName === 'I' && /^[\w\s-]+$/.test(child.className)) el.className = child.className;
            }
            cleanNode(child, el);
            out.appendChild(el);
        } else if (child.nodeType === Node.ELEMENT_NODE) {
            cleanNode(child, out); // balise refusée : on garde seulement son texte
        }
    });
}

function safeHtml(str) {
    if (str === undefined || str === null) return '';
    const tpl = document.createElement('template');
    tpl.innerHTML = String(str);
    const box = document.createElement('div');
    cleanNode(tpl.content, box);
    return box.innerHTML;
}

// Adresse d'image : nui://, https:// ou chemin local, sans guillemets
function safeUrl(str) {
    const v = String(str ?? '');
    if (/^(https?:\/\/|nui:\/\/|\.?\/?[\w-]+\/)/i.test(v) || /^[\w./-]+$/.test(v)) return escapeHtml(v);
    return '';
}

// Couleur CSS simple (#hex, rgb/rgba, nom)
function safeColor(str, fallback) {
    const v = String(str ?? '');
    return /^(#[0-9a-f]{3,8}|rgba?\([\d\s.,%]+\)|[a-z]+)$/i.test(v) ? v : fallback;
}

// Classe d'icône Font Awesome
function safeIcon(str, fallback) {
    const v = String(str ?? '');
    return /^[\w\s-]+$/.test(v) ? v : fallback;
}

let notifCounter = 0;
function createNotification(d) {
    const container = document.getElementById('notify-container');
    const id = ++notifCounter;
    const duration = d.duration || 5000;
    let html = "";

    if (d.image) {
        // --- STYLE : BIG IMAGE ---
        html = `
        <div class="notif-card big-image" id="notif-${id}">
            <img src="${safeUrl(d.image)}" class="img-bg">
            <div class="img-content">
                <div class="img-title">${safeHtml(d.title)}</div>
                <div class="img-message">${safeHtml(d.message)}</div>
            </div>
            <div class="progress" id="p-${id}"></div>
        </div>`;
    } else if (d.logo) {
        // --- STYLE : LOGO FUSIONNÉ ---
        html = `
        <div class="notif-card logo-style" id="notif-${id}">
            <div class="logo-container">
                <img src="${safeUrl(d.logo)}">
            </div>
            <div class="logo-text">
                <div class="logo-title">${safeHtml(d.title)}</div>
                <div class="logo-message">${safeHtml(d.message)}</div>
            </div>
            <div class="progress" id="p-${id}"></div>
        </div>`;
    }  else if (d.title) {
        // --- STYLE : ADVANCED ---
        // On n'utilise plus de boucle .map() ici pour éviter la répétition
        html = `
        <div class="notif-card advanced" id="notif-${id}">
            <div class="adv-header">
                <div class="adv-title-box">
                    <i class="${safeIcon(d.icon, 'fas fa-user')}"></i> 
                    <span class="adv-title">${safeHtml(d.title)}</span>
                </div>
                ${d.badge ? `<span class="adv-badge" style="background:${safeColor(d.badgeColor, '#e74c3c')}">${safeHtml(d.badge)}</span>` : ''}
            </div>
            <div class="adv-body">
                <div class="adv-msg-line">
                    <i class="fas fa-location-dot"></i>
                    <div>${safeHtml(d.message)}</div>
                </div>
            </div>
            ${d.sideText ? `<div class="adv-side">${safeHtml(d.sideText)}</div>` : ''}
            <div class="progress" id="p-${id}"></div>
        </div>`;
    // Remplacez la partie "STYLE : SIMPLE" dans votre script.js par ceci :
    } else {
        // --- STYLE : SIMPLE ---
        html = `
        <div class="notif-card simple" id="notif-${id}">
            <div class="simple-circle">
                <i class="${safeIcon(d.icon, 'fas fa-dollar-sign')}"></i>
            </div>
            <div class="simple-message">${safeHtml(d.message)}</div>
            <div class="progress" id="p-${id}"></div>
        </div>`;
    }

    container.insertAdjacentHTML('afterbegin', html);
    const pBar = document.getElementById(`p-${id}`);
    pBar.style.transition = `linear ${duration}ms`;
    setTimeout(() => { pBar.style.width = '0%'; }, 50);

    setTimeout(() => {
        const el = document.getElementById(`notif-${id}`);
        if (el) {
            el.style.animation = "slideOut 0.3s ease-in forwards";
            setTimeout(() => { el.remove(); }, 300);
        }
    }, duration);
}
