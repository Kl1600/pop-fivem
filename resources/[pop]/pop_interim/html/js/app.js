const app = document.getElementById('app');
const carousel = document.getElementById('carousel');
const loader = document.getElementById('loader');

// Décalage horizontal (vw) du centre d'une case selon son rang vs la sélection.
// Repris exactement de la maquette : 1er cran 24.3vw (74.3%), suivants 22.8vw.
function offsetX(off) {
    if (off === 0) return 0;
    const sign = off > 0 ? 1 : -1;
    return sign * (24.3 + (Math.abs(off) - 1) * 22.8);
}

let jobs = [];
let cards = [];
let selected = 0;
let previewed = -1;

function resName() {
    return (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pop_interim';
}

function post(name, data) {
    return fetch(`https://${resName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {})
    }).catch(() => {});
}

function showLoader() { loader.classList.remove('hidden'); }
function hideLoader() { loader.classList.add('hidden'); }

function build() {
    carousel.innerHTML = '';
    cards = jobs.map((job, i) => {
        const card = document.createElement('div');
        card.className = 'card';
        card.innerHTML = `
            <div class="card-img" style="background-image:url('${job.image || ''}')"></div>
            <div class="card-overlay"></div>
            <div class="card-grad"></div>
            <div class="card-text">
                <div class="card-title">${job.label || job.id}</div>
                <div class="card-sub">${job.description || ''}</div>
            </div>
        `;
        card.onclick = () => onCardClick(i);
        carousel.appendChild(card);
        return card;
    });
}

// Positionne chaque case selon son décalage par rapport à la sélection.
// Valeurs reprises exactement de la maquette : l'opacité porte sur l'image
// (le texte reste blanc plein), la taille passe par la classe .selected.
function layout() {
    cards.forEach((card, i) => {
        const off = i - selected;
        const a = Math.abs(off);
        const imgOpacity = a >= 2 ? 0.50 : 0.75;
        const overlay = off === 0 ? 0.29 : (a === 1 ? 0.24 : 0.54);
        card.style.setProperty('--x', `${offsetX(off)}vw`);
        card.style.zIndex = String(20 - a);
        card.classList.toggle('selected', off === 0);
        card.querySelector('.card-img').style.opacity = imgOpacity;
        card.querySelector('.card-overlay').style.background = `rgba(0,0,0,${overlay})`;
    });
}

function doPreview(i) {
    if (previewed === i) return;
    previewed = i;
    showLoader();
    post('previewJob', { id: jobs[i].id });
}

// Amène la case i au centre (rotation) + prévisualise.
function goTo(i, preview) {
    if (i < 0 || i >= jobs.length) return;
    selected = i;
    layout();
    if (preview) doPreview(i);
}

function accept() {
    if (selected < 0 || !jobs[selected]) return;
    post('selectJob', { id: jobs[selected].id });
}

function onCardClick(i) {
    if (i === selected) {
        accept();          // clic sur la case déjà centrée = valider
    } else {
        goTo(i, true);     // clic sur une case latérale = rotation + aperçu
    }
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.type === 'open') {
        jobs = data.jobs || [];
        selected = 0;
        previewed = -1;
        build();
        layout();
        app.style.display = 'block';
        hideLoader();
        if (jobs.length) doPreview(0); // aperçu auto de la 1re mission
    } else if (data.type === 'close') {
        app.style.display = 'none';
        hideLoader();
    } else if (data.type === 'sceneReady') {
        hideLoader();
    }
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        post('close');
    } else if (event.key === 'ArrowRight') {
        event.preventDefault();
        goTo(Math.min(selected + 1, jobs.length - 1), true);
    } else if (event.key === 'ArrowLeft') {
        event.preventDefault();
        goTo(Math.max(selected - 1, 0), true);
    } else if (event.key === 'Enter') {
        event.preventDefault();
        accept();
    }
});
