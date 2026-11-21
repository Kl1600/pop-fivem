'use strict';

const element = id => document.getElementById(id);
const menu = element('menu');
const controls = element('items');
const invitation = element('invitation');
const filter = element('only-favorites');
let catalog = [];
let favorites = {};
let pending;
let current;
let version = 0;
let choosing = false;

function renderInvite() {
  invitation.hidden = !pending;
  if (!pending) return;
  element('inviter').textContent = Pop.t('invite_title', pending.name, Pop.t(pending.label));
  element('accept').disabled = false;
  element('decline').disabled = false;
}

function renderItems() {
  controls.replaceChildren();
  const items = catalog.filter(item => !filter.checked || favorites[item.id]);
  for (const item of items) {
    const row = document.createElement('div');
    const button = document.createElement('button');
    const favorite = document.createElement('button');
    row.className = 'item';
    button.className = 'play';
    button.textContent = Pop.t(item.label);
    if (item.shared) {
      const shared = document.createElement('small');
      shared.className = 'pop-small';
      shared.textContent = Pop.t('shared');
      button.append(shared);
    }
    if (current === item.id) button.classList.add('current');
    favorite.className = 'favorite';
    const isFavorite = Boolean(favorites[item.id]);
    favorite.textContent = isFavorite ? '★' : '☆';
    favorite.title = Pop.t(isFavorite ? 'remove_favorite' : 'add_favorite');
    favorite.setAttribute('aria-label', favorite.title);
    favorite.setAttribute('aria-pressed', String(isFavorite));
    row.append(button, favorite);
    controls.append(row);

    button.addEventListener('click', async () => {
      if (choosing) return;
      choosing = true;
      const currentVersion = version;
      await Pop.post('play', { id: item.id });
      if (version === currentVersion) choosing = false;
    });
    favorite.addEventListener('click', async () => {
      if (favorite.disabled) return;
      const currentVersion = version;
      favorite.disabled = true;
      const reply = await Pop.post('favorite', { id: item.id });
      if (version !== currentVersion) return;
      favorite.disabled = false;
      if (reply && reply.ok) {
        favorites[item.id] = reply.favorite;
        renderItems();
      }
    });
  }
  if (items.length === 0) {
    const empty = document.createElement('p');
    empty.className = 'pop-small';
    empty.textContent = Pop.t('no_favorites');
    controls.append(empty);
  }
}

Pop.on('pop_emotes:menu', data => {
  version += 1;
  choosing = false;
  catalog = data.catalog;
  favorites = { ...data.favorites };
  pending = data.invite;
  current = data.current;
  element('stop').hidden = !current;
  renderItems();
  renderInvite();
  menu.inert = false;
  Pop.show(menu, true);
});

Pop.on('pop_emotes:close', () => {
  version += 1;
  menu.inert = true;
  Pop.show(menu, false);
});

Pop.on('pop_emotes:invite', data => {
  pending = data;
  renderInvite();
});

Pop.on('pop_emotes:inviteClosed', data => {
  if (pending && pending.ticket === data.ticket) {
    pending = undefined;
    renderInvite();
  }
});

async function reply(accept) {
  if (!pending) return;
  const ticket = pending.ticket;
  element('accept').disabled = true;
  element('decline').disabled = true;
  const result = await Pop.post('respond', { ticket, accept });
  if ((!result || !result.ok) && pending && pending.ticket === ticket) renderInvite();
}

filter.addEventListener('change', renderItems);
element('accept').addEventListener('click', () => reply(true));
element('decline').addEventListener('click', () => reply(false));
element('close').addEventListener('click', () => Pop.post('close'));
element('stop').addEventListener('click', () => Pop.post('stop'));
