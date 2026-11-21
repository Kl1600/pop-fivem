const uiElements = new Map();
const pendingRemovals = new Map();

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'create':
            createElement(data.id, data.type, data.content, data.style);
            break;
        case 'update':
            updateElement(data.id, data.content);
            break;
        case 'updatePosition':
            updatePosition(data.id, data.x, data.y);
            break;
        case 'updatePositions':
            for (const id in data.positions) {
                const pos = data.positions[id];
                updatePosition(id, pos.x, pos.y);
            }
            break;
        case 'remove':
            removeElement(data.id);
            break;
        case 'clear':
            clearAll();
            break;
    }
});

function createElement(id, type, content, customStyle = {}) {
    const pending = pendingRemovals.get(id);
    if (pending) {
        clearTimeout(pending.timer);
        pending.element.remove();
        pendingRemovals.delete(id);
    }
    const existing = uiElements.get(id);
    if (existing) {
        existing.remove();
        uiElements.delete(id);
    }

    const container = document.getElementById('ui-container');
    const element = document.createElement('div');
    element.id = `ui-${id}`;
    element.className = 'ui-element fade-in';

    // Build content based on type
    switch (type) {
        case 'text':
            element.innerHTML = `<div class="ui-text">${content.text}</div>`;
            break;

        case 'box':
            element.innerHTML = `<div class="ui-box">${content.text}</div>`;
            break;

        case 'prompt':
            const iconHtml = content.icon
                ? `<i class="${content.icon} ui-prompt-icon"></i>`
                : '';
            element.innerHTML = `
                <div class="ui-prompt">
                    <div class="ui-prompt-key">${content.key}</div>
                    <div class="ui-prompt-content">
                        ${content.label}
                        ${iconHtml}
                    </div>
                </div>
            `;
            break;

        case 'icon-text':
            element.innerHTML = `
                <div class="ui-icon-text">
                    ${content.icon ? `<img src="${content.icon}" alt="icon">` : ''}
                    <span>${content.text}</span>
                </div>
            `;
            break;

        default:
            element.innerHTML = `<div class="ui-text">${content.text || content}</div>`;
    }

    // Apply custom styles
    if (customStyle.color) {
        element.style.color = customStyle.color;
    }
    if (customStyle.fontSize) {
        element.style.fontSize = customStyle.fontSize;
    }
    if (customStyle.backgroundColor) {
        const firstChild = element.firstElementChild;
        if (firstChild) firstChild.style.backgroundColor = customStyle.backgroundColor;
    }

    container.appendChild(element);
    uiElements.set(id, element);
}

function updateElement(id, content) {
    const element = uiElements.get(id);
    if (!element) return;

    const textElement = element.querySelector('.ui-text, .ui-box span, .ui-prompt-label, .ui-icon-text span');
    if (textElement) {
        textElement.textContent = content.text || content;
    }
}

function updatePosition(id, x, y) {
    const element = uiElements.get(id);
    if (!element) return;

    element.style.left = `${x * 100}%`;
    element.style.top = `${y * 100}%`;
}

function removeElement(id) {
    const element = uiElements.get(id);
    if (!element) return;

    uiElements.delete(id);

    const existing = pendingRemovals.get(id);
    if (existing) clearTimeout(existing.timer);

    element.classList.remove('fade-in');
    element.classList.add('fade-out');

    const timer = setTimeout(() => {
        const pending = pendingRemovals.get(id);
        if (pending && pending.element === element) {
            element.remove();
            pendingRemovals.delete(id);
        }
    }, 300);

    pendingRemovals.set(id, { element, timer });
}

function clearAll() {
    Array.from(uiElements.keys()).forEach((id) => removeElement(id));
}
