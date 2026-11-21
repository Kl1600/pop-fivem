'use strict';

const markers = document.getElementById('markers');
const actions = document.getElementById('actions');
const markerNodes = new Map();
let previous = '';

function updateMarkers(entries) {
  const incoming = new Set();
  for (const entry of entries) {
    if (!Number.isFinite(entry.x) || !Number.isFinite(entry.y)) continue;
    incoming.add(entry.id);
    let label = markerNodes.get(entry.id);
    if (!label) {
      label = document.createElement('span');
      label.className = 'pop-panel';
      label.dir = 'auto';
      markers.append(label);
      markerNodes.set(entry.id, label);
    }
    if (label.textContent !== entry.text) label.textContent = entry.text;
    label.style.left = (entry.x * 100) + '%';
    label.style.top = (entry.y * 100) + '%';
  }
  for (const [id, label] of markerNodes) {
    if (!incoming.has(id)) {
      label.remove();
      markerNodes.delete(id);
    }
  }
}

Pop.on('pop_chat:frame', data => {
  updateMarkers(Array.isArray(data.markers) ? data.markers : []);
  const messages = Array.isArray(data.messages) ? data.messages : [];
  const signature = JSON.stringify(messages);
  if (signature === previous) return;
  previous = signature;
  actions.replaceChildren();
  for (const message of messages) {
    const row = document.createElement('p');
    row.dir = 'auto';
    row.textContent = message.text;
    actions.append(row);
  }
  Pop.show(actions, messages.length > 0);
});
