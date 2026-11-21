let animations = {
    emotes: {},
    dances: {},
    props: {},
    walks: {},
    expressions: {},
    shared: {}
};

let currentCategory = 'emotes';

window.addEventListener('message', function (event) {
    if (event.data.type === "toggle") {
        if (event.data.display) {
            document.getElementById('app').style.display = 'flex';
            fetchAnimations();
        } else {
            document.getElementById('app').style.display = 'none';
        }
    }
});

function fetchAnimations() {
    fetch(`https://${GetParentResourceName()}/getAnimations`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({})
    })
        .then(resp => resp.json())
        .then(data => {
            if (data) {
                animations = data;
                renderList();
            }
        });
}

function renderList() {
    const list = document.getElementById('emote-list');
    const search = document.getElementById('search').value.toLowerCase();
    list.innerHTML = '';

    const items = animations[currentCategory];
    if (!items) return;

    // Filter and sort
    const keys = Object.keys(items).sort((a, b) => {
        const labelA = items[a] || a;
        const labelB = items[b] || b;
        return labelA.localeCompare(labelB);
    });

    keys.forEach(key => {
        const label = items[key];
        const displayLabel = label || key;

        if (displayLabel.toLowerCase().includes(search) || key.toLowerCase().includes(search)) {
            const div = document.createElement('div');
            div.className = 'emote-item';
            div.innerHTML = `
                <span>${displayLabel.toUpperCase()}</span>
                <i class="fa-solid fa-chevron-right favourite-icon"></i>
            `;
            div.onmouseenter = () => {
                fetch(`https://${GetParentResourceName()}/previewEmote`, {
                    method: 'POST',
                    body: JSON.stringify({ emote: key, category: currentCategory })
                });
            };
            div.onclick = () => playEmote(key, currentCategory);
            list.appendChild(div);
        }
    });
}

function playEmote(name, category) {
    if (name === 'c') {
        fetch(`https://${GetParentResourceName()}/playEmote`, {
            method: 'POST',
            body: JSON.stringify({ emote: 'c', category: category })
        });
        return;
    }

    fetch(`https://${GetParentResourceName()}/playEmote`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            emote: name,
            category: category
        })
    });
}

// Category selection
document.querySelectorAll('.cat-item').forEach(item => {
    item.addEventListener('click', function () {
        document.querySelectorAll('.cat-item').forEach(el => el.classList.remove('active'));
        this.classList.add('active');
        currentCategory = this.dataset.cat;
        document.getElementById('emote-list').parentElement.scrollTop = 0;
        renderList();
    });
});

// Search handler
const searchInput = document.getElementById('search');
searchInput.addEventListener('input', renderList);
searchInput.addEventListener('focus', () => {
    fetch(`https://${GetParentResourceName()}/inputFocus`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ focus: true })
    });
});
searchInput.addEventListener('blur', () => {
    fetch(`https://${GetParentResourceName()}/inputFocus`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ focus: false })
    });
});

// Close menu on ESC
window.addEventListener('keydown', function (event) {
    if (event.key === "Escape") {
        fetch(`https://${GetParentResourceName()}/close`, {
            method: 'POST',
            body: JSON.stringify({})
        });
    }
});
