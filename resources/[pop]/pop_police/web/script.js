'use strict';

const element = id => document.getElementById(id);
const text = (id, value) => { element(id).textContent = value; };
const money = amount => Pop.t('money', amount);
const status = serverId => serverId ? Pop.t('mdt_online', serverId) : Pop.t('mdt_offline');
const pages = ['police-menu', 'police-fine', 'police-mdt'];
let selected = 0;
let menuButtons = [];
let version = 0;
let profileVersion = 0;
let citizenId;

function theme(data) {
  document.documentElement.dataset.theme = data.theme;
}

function showPage(id) {
  version += 1;
  for (const page of pages) {
    const panel = element(page);
    panel.inert = page !== id;
    Pop.show(panel, page === id);
  }
}

function node(tag, value, parent, className) {
  const child = document.createElement(tag);
  child.textContent = value;
  if (className) child.className = className;
  parent.appendChild(child);
  return child;
}

function select(index, focus) {
  if (!menuButtons.length) return;
  selected = (index + menuButtons.length) % menuButtons.length;
  for (const [i, button] of menuButtons.entries()) button.classList.toggle('selected', i === selected);
  if (focus) menuButtons[selected].focus();
}

let actionPending = false;
Pop.on('pop_police:menu', data => {
  theme(data);
  showPage('police-menu');
  text('menu-target', data.target ? Pop.t('menu_target', data.target.serverId) : Pop.t('menu_no_target'));
  const parent = element('menu-actions');
  parent.replaceChildren();
  actionPending = false;
  menuButtons = data.actions.map((id, index) => {
    const button = node('button', Pop.t('action_' + id), parent, id === 'panic' ? 'danger' : '');
    button.addEventListener('focus', () => select(index, false));
    button.addEventListener('click', async () => {
      if (actionPending) return;
      const current = version;
      actionPending = true;
      await Pop.post('action', { id });
      if (version === current) actionPending = false;
    });
    return button;
  });
  select(0, true);
});
element('police-menu').addEventListener('keydown', event => {
  if (event.key !== 'ArrowUp' && event.key !== 'ArrowDown') return;
  event.preventDefault();
  select(selected + (event.key === 'ArrowDown' ? 1 : -1), true);
});

const fineReason = element('fine-reason');
const fineAmount = element('fine-amount');
const fineSend = element('fine-send');
const fineCancel = element('fine-cancel');

Pop.on('pop_police:fineForm', data => {
  theme(data);
  showPage('police-fine');
  text('fine-target', Pop.t('menu_target', data.target.serverId));
  text('fine-bounds', Pop.t('fine_bounds', money(Math.min(...data.amounts)), money(Math.max(...data.amounts))));
  fineAmount.replaceChildren();
  for (const [index, amount] of data.amounts.entries()) {
    node('option', money(amount), fineAmount).value = String(index + 1);
  }
  fineReason.value = '';
  fineReason.classList.remove('invalid');
  fineSend.disabled = false;
  fineCancel.disabled = false;
  fineAmount.focus();
});
element('fine-form').addEventListener('submit', async event => {
  event.preventDefault();
  if (fineSend.disabled) return;
  const reason = fineReason.value.trim();
  const length = Array.from(reason).length;
  const invalid = length < 3 || length > 100;
  fineReason.classList.toggle('invalid', invalid);
  if (invalid) return;
  const current = version;
  fineSend.disabled = true;
  fineCancel.disabled = true;
  await Pop.post('fine', { option: Number(fineAmount.value), reason });
  if (version === current) {
    fineSend.disabled = false;
    fineCancel.disabled = false;
  }
});
fineCancel.addEventListener('click', () => Pop.post('close'));

const query = element('mdt-query');
const results = element('mdt-results');
const profile = element('mdt-profile');
const note = element('mdt-note');
const searchButton = element('mdt-search-btn');
const addNote = element('mdt-add-note');

function resultView() {
  profileVersion += 1;
  citizenId = undefined;
  profile.hidden = true;
  results.hidden = false;
}

Pop.on('pop_police:mdt', data => {
  theme(data);
  showPage('police-mdt');
  resultView();
  results.replaceChildren();
  query.value = '';
  query.placeholder = Pop.t('mdt_search_hint');
  query.setAttribute('aria-label', query.placeholder);
  note.placeholder = Pop.t('mdt_note_hint');
  note.setAttribute('aria-label', note.placeholder);
  searchButton.disabled = false;
  addNote.disabled = false;
  query.focus();
});

function formatDate(timestamp) {
  const date = new Date(Number(timestamp) * 1000);
  try { return date.toLocaleString(Pop.t('date_locale')); }
  catch (_) { return date.toLocaleString(); }
}

function renderProfile(data) {
  profileVersion += 1;
  citizenId = data.citizenId;
  note.value = '';
  addNote.disabled = false;
  text('mdt-name', data.name);
  text('mdt-status', status(data.serverId));
  text('mdt-unpaid', Pop.t('mdt_unpaid', money(data.unpaid)));
  element('mdt-unpaid').hidden = data.unpaid <= 0;
  const notes = element('mdt-notes');
  notes.replaceChildren();
  for (const entry of Array.isArray(data.notes) ? data.notes : []) {
    const row = node('div', '', notes);
    node('p', entry.text, row);
    node('p', entry.author + ' · ' + formatDate(entry.createdAt), row, 'pop-small');
    if (entry.canDelete) {
      const button = node('button', Pop.t('mdt_delete'), row, 'pop-button');
      button.addEventListener('click', () => mutate(button, 'mdtDeleteNote', { noteId: entry.id }));
    }
  }
  if (!notes.children.length) node('p', Pop.t('mdt_empty'), notes, 'pop-small');
  const fines = element('mdt-fines');
  fines.replaceChildren();
  for (const entry of Array.isArray(data.fines) ? data.fines : []) {
    const row = node('div', '', fines);
    node('p', money(entry.amount) + ' · ' + entry.reason, row);
    node('p', Pop.t('status_' + entry.status), row, entry.status === 'unpaid' ? 'danger' : 'pop-small');
    node('p', entry.officer + ' · ' + formatDate(entry.createdAt), row, 'pop-small');
  }
  if (!fines.children.length) node('p', Pop.t('mdt_empty'), fines, 'pop-small');
  results.hidden = true;
  profile.hidden = false;
}

async function mutate(button, action, payload) {
  if (button.disabled) return;
  const current = version;
  const selection = profileVersion;
  button.disabled = true;
  const reply = await Pop.post(action, payload);
  if (version !== current || profileVersion !== selection) return;
  button.disabled = false;
  if (reply && reply.ok) renderProfile(reply.profile);
}

element('mdt-search').addEventListener('submit', async event => {
  event.preventDefault();
  if (searchButton.disabled) return;
  const current = version;
  resultView();
  results.replaceChildren();
  searchButton.disabled = true;
  const reply = await Pop.post('mdtSearch', { query: query.value });
  if (version !== current) return;
  searchButton.disabled = false;
  if (!reply || !reply.ok) return;
  const rows = Array.isArray(reply.results) ? reply.results : [];
  for (const row of rows) {
    const button = node('button', row.name + ' · ' + status(row.serverId), results);
    button.addEventListener('click', async () => {
      const selection = ++profileVersion;
      const detail = await Pop.post('mdtProfile', row.citizenId ? { citizenId: row.citizenId } : { serverId: row.serverId });
      if (version === current && selection === profileVersion && detail && detail.ok) renderProfile(detail.profile);
    });
  }
  if (!rows.length) node('p', Pop.t('mdt_no_results'), results, 'pop-small');
});
element('mdt-note-form').addEventListener('submit', event => {
  event.preventDefault();
  if (citizenId) mutate(addNote, 'mdtAddNote', { citizenId, text: note.value.trim() });
});
element('mdt-back').addEventListener('click', resultView);
element('mdt-close').addEventListener('click', () => Pop.post('close'));
Pop.on('pop_police:close', () => showPage());

Pop.on('pop_police:fineRequest', data => {
  const card = element('police-fine-request');
  card.setAttribute('aria-hidden', String(!data.show));
  Pop.show(card, data.show);
  if (!data.show) return;
  theme(data);
  text('fr-amount', money(data.amount));
  text('fr-reason', data.reason);
  text('fr-officer', Pop.t('fine_from', data.officer));
  text('fr-accept', '[' + data.acceptKey + ']');
  text('fr-decline', '[' + data.declineKey + ']');
  const timer = element('fr-timer');
  timer.style.transition = 'none';
  timer.style.transform = 'scaleX(1)';
  void timer.offsetWidth;
  timer.style.transition = 'transform ' + data.timeout + 's linear';
  timer.style.transform = 'scaleX(0)';
});
