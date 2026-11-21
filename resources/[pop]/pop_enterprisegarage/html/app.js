const app = document.getElementById('app');

function post(name, data) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    });
}

function render(vehicles) {
    const list = document.getElementById('list');
    list.innerHTML = '';
    if (!vehicles || vehicles.length === 0) {
        list.innerHTML = '<div class="empty">Aucun véhicule dans cette flotte.</div>';
        return;
    }
    vehicles.forEach(v => {
        const card = document.createElement('div');
        card.className = 'veh-card';

        const info = document.createElement('div');
        info.className = 'veh-info';
        info.innerHTML = `<div class="veh-name">${v.label || v.model}</div><div class="veh-plate">${v.plate}</div>`;

        const action = document.createElement('div');
        if (v.state === 'in') {
            action.className = 'veh-action take';
            action.textContent = 'Sortir';
            action.onclick = () => post('takeOut', { plate: v.plate });
        } else {
            action.className = 'veh-action out';
            action.textContent = 'Dehors';
        }

        card.appendChild(info);
        card.appendChild(action);
        list.appendChild(card);
    });
}

function storeVehicle() { post('store', {}); }
function closeMenu() { post('close', {}); }

window.addEventListener('message', (e) => {
    const d = e.data;
    if (d.action === 'open') {
        document.getElementById('garage-name').textContent = d.garage || '—';
        render(d.vehicles);
        app.style.display = 'block';
    } else if (d.action === 'close') {
        app.style.display = 'none';
    }
});

document.addEventListener('keyup', (e) => {
    if (e.key === 'Escape') closeMenu();
});
