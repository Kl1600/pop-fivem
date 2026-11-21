(() => {
  'use strict';

  const byId = id => document.getElementById(id);
  const all = selector => [...document.querySelectorAll(selector)];
  const show = (element, visible) => element.classList.toggle('pop-hidden', !visible);
  const text = (id, value) => { byId(id).textContent = value ?? ''; };
  const protectedActions = new Set(['freeze', 'warn', 'kick', 'ban']);
  const confirmActions = new Set(['kick', 'ban', 'unban']);
  let panel, tab, selected, refresh, confirmed, confirmTimer, pending, revision = 0;
  let players = [];

  function cancelConfirmation() {
    clearTimeout(confirmTimer);
    if (confirmed) confirmed.button.textContent = confirmed.label;
    confirmed = null;
  }

  function button(label, handler) {
    const element = document.createElement('button');
    element.type = 'button';
    element.textContent = label;
    element.addEventListener('click', handler);
    return element;
  }

  function renderPlayers() {
    const list = byId('player-list');
    const query = byId('search').value.trim().toLocaleLowerCase();
    const matches = players.filter(row => String(row.id).startsWith(query)
      || String(row.name ?? '').toLocaleLowerCase().includes(query)
      || String(row.fivem ?? '').toLocaleLowerCase().includes(query));
    list.replaceChildren(...matches.map(row => {
      const element = button('', () => {
        cancelConfirmation();
        selected = row.id;
        byId('reason').value = '';
        renderPlayers();
      });
      element.className = 'adm-player';
      for (const [label, className] of [
        ['#' + row.id, 'pop-small'], [row.name, 'adm-ellipsis'], [Pop.t('ping_ms', row.ping), 'pop-small'],
      ]) {
        const cell = document.createElement('span');
        cell.className = className;
        cell.dir = 'auto';
        cell.textContent = label;
        element.appendChild(cell);
      }
      return element;
    }));
    show(byId('no-players'), matches.length === 0);

    const row = players.find(item => item.id === selected);
    if (!row) selected = null;
    show(byId('player-browse'), !row);
    show(byId('player-card'), Boolean(row));
    if (!row) return;
    text('card-name', row.name);
    text('card-fivem', row.fivem);
    text('card-id', '#' + row.id);
    text('card-ping', Pop.t('ping_ms', row.ping));
    text('card-warns', Pop.t('player_warns', row.warns));
    show(byId('card-frozen'), row.frozen);

    const sanction = row.id !== panel.self && ['warn', 'kick', 'ban'].some(key => panel.perms[key]);
    show(byId('sanction'), sanction);
    show(byId('duration-field'), sanction && panel.perms.ban);
    for (const control of all('#player-card [data-act]')) {
      const action = control.dataset.act;
      const selfAllowed = action === 'heal' || action === 'revive';
      show(control, panel.perms[action] && (row.id !== panel.self || selfAllowed));
      control.disabled = !!pending || (protectedActions.has(action) && row.admin);
      if (action === 'freeze') control.textContent = Pop.t(row.frozen ? 'act_unfreeze' : 'act_freeze');
    }
  }

  async function loadPlayers() {
    const snapshot = revision;
    const response = await Pop.post('players');
    if (!panel || tab !== 'players' || snapshot !== revision) return;
    players = Array.isArray(response?.players) ? response.players : [];
    renderPlayers();
  }

  async function loadBans() {
    const snapshot = revision;
    const response = await Pop.post('bans');
    if (!panel || tab !== 'bans' || snapshot !== revision) return;
    const rows = Array.isArray(response?.bans) ? response.bans : [];
    byId('ban-list').replaceChildren(...rows.map(row => {
      const item = document.createElement('article');
      item.className = 'adm-ban';
      const name = document.createElement('strong');
      name.textContent = row.name;
      name.dir = 'auto';
      const reason = document.createElement('div');
      reason.textContent = row.reason;
      reason.dir = 'auto';
      const details = document.createElement('div');
      details.className = 'pop-small';
      details.textContent = Pop.t('ban_by', row.admin) + ' · '
        + (row.expiresAt ? Pop.t('ban_until', row.expiresAt) : Pop.t('ban_permanent'));
      const unban = button(Pop.t('act_unban'), event => {
        send(event.currentTarget, { action: 'unban', data: { banId: row.id } });
      });
      unban.className = 'pop-button adm-danger';
      unban.dataset.act = 'unban';
      unban.disabled = !!pending;
      item.append(name, reason, details, unban);
      return item;
    }));
    show(byId('bans-empty'), rows.length === 0);
  }

  function openTab(next) {
    revision += 1;
    cancelConfirmation();
    clearInterval(refresh);
    tab = next;
    for (const control of all('[data-tab]')) {
      const active = control.dataset.tab === tab;
      control.classList.toggle('is-active', active);
      control.setAttribute('aria-selected', String(active));
    }
    for (const view of all('[data-view]')) show(view, view.dataset.view === tab);
    if (tab === 'players') {
      loadPlayers();
      refresh = setInterval(loadPlayers, 5000);
    } else if (tab === 'bans') {
      loadBans();
    }
  }

  function options(id, rows) {
    byId(id).replaceChildren(...rows.map(([value, label]) => new Option(label, value)));
  }

  function setModes(modes) {
    for (const mode of ['noclip', 'invisible']) {
      const control = byId('toggle-' + mode);
      control.setAttribute('aria-checked', String(!!modes[mode]));
      control.querySelector('.adm-state').textContent = Pop.t(modes[mode] ? 'state_on' : 'state_off');
    }
  }

  function translateInputs() {
    for (const [id, key] of Object.entries({
      search: 'search', reason: 'reason', 'vehicle-model': 'vehicle_model', 'announce-text': 'announce_placeholder',
    })) {
      byId(id).placeholder = Pop.t(key);
      byId(id).setAttribute('aria-label', Pop.t(key));
    }
  }

  function formatDuration(hours) {
    if (hours === 0) return Pop.t('duration_permanent');
    return hours % 24 === 0 ? Pop.t('duration_days', hours / 24) : Pop.t('duration_hours', hours);
  }

  function configure(data) {
    const p = data.perms;
    const has = keys => keys.some(key => p[key]);
    const tabs = {
      players: true,
      self: has(['noclip', 'invisible', 'heal', 'revive', 'vehicle']),
      server: has(['world', 'announce']),
      bans: p.unban,
    };
    for (const control of all('[data-tab]')) show(control, tabs[control.dataset.tab]);
    for (const [id, visible] of Object.entries({
      'toggle-noclip': p.noclip, 'toggle-invisible': p.invisible, 'self-heal': p.heal, 'self-revive': p.revive,
      'vehicle-block': p.vehicle, 'world-block': p.world, 'world-off': !data.worldSync, 'world-form': data.worldSync,
      'announce-block': p.announce,
    })) show(byId(id), visible);

    options('duration', data.banDurations.map(hours => [hours, formatDuration(hours)]));
    options('world-weather', data.weathers.map(weather => {
      const key = 'weather_' + weather.toLowerCase();
      const label = Pop.t(key);
      return [weather, label === key ? weather : label];
    }));
    byId('world-weather').value = data.world.weather;
    byId('world-hour').value = data.world.hour;
    byId('world-minute').value = data.world.minute;
    byId('world-freeze').checked = data.world.frozen;
    setModes(data.modes);
    translateInputs();
  }

  async function send(control, request) {
    if (!panel || pending || control.disabled) return;
    if (confirmActions.has(request.action)) {
      const signature = JSON.stringify(request);
      if (confirmed?.button !== control || confirmed.signature !== signature) {
        cancelConfirmation();
        confirmed = { button: control, signature, label: control.textContent };
        control.textContent = Pop.t('confirm');
        confirmTimer = setTimeout(cancelConfirmation, 3000);
        return;
      }
    }
    cancelConfirmation();
    const controls = all('#admin [data-act]').filter(element => !element.disabled);
    const token = {};
    pending = token;
    controls.forEach(element => { element.disabled = true; });
    try {
      const response = await Pop.post('action', request);
      if (!panel || pending !== token || !response?.ok) return;
      if (tab === 'players') await loadPlayers();
      if (tab === 'bans') await loadBans();
    } finally {
      if (pending === token) {
        pending = null;
        all('#admin [data-act]').forEach(element => { element.disabled = false; });
        if (panel && tab === 'players') renderPlayers();
      }
    }
  }

  function act(event) {
    const control = event.currentTarget;
    const action = control.dataset.act;
    const request = { action };
    if (tab === 'players') request.target = selected;
    if (tab === 'self' && ['heal', 'revive'].includes(action)) request.target = panel.self;
    if (['warn', 'kick', 'ban'].includes(action)) request.data = { reason: byId('reason').value };
    if (action === 'ban') request.data.duration = Number(byId('duration').value);
    if (action === 'vehicle_spawn') request.data = { model: byId('vehicle-model').value };
    if (action === 'announce') request.data = { message: byId('announce-text').value };
    if (action === 'world') {
      request.data = {
        weather: byId('world-weather').value, hour: byId('world-hour').valueAsNumber,
        minute: byId('world-minute').valueAsNumber, frozen: byId('world-freeze').checked,
      };
    }
    send(control, request);
  }

  function banner(id, field, data, value) {
    const element = byId(id);
    let timeout;
    Pop.on(data, payload => {
      clearTimeout(timeout);
      text(field, payload[value]);
      show(element, true);
      Pop.show(element, true);
      timeout = setTimeout(() => Pop.show(element, false), payload.duration);
    });
  }

  Pop.on('pop_admin:open', data => {
    panel = data;
    pending = null;
    all('#admin [data-act]').forEach(element => { element.disabled = false; });
    selected = null;
    players = [];
    byId('search').value = '';
    configure(data);
    openTab('players');
    renderPlayers();
    Pop.show(byId('admin'), true);
  });

  Pop.on('pop_admin:close', () => {
    panel = null;
    pending = null;
    revision += 1;
    cancelConfirmation();
    clearInterval(refresh);
    Pop.show(byId('admin'), false);
  });

  Pop.on('pop_admin:modes', setModes);
  Pop.on('pop_admin:hud', data => {
    const hud = byId('admin-hud');
    const lines = [];
    if (data.noclip) lines.push(Pop.t('hud_noclip'),
      '[W A S D] ' + Pop.t('hud_move') + ' · [Q / E] ' + Pop.t('hud_updown'),
      '[SHIFT] ' + Pop.t('hud_fast') + ' · [ALT] ' + Pop.t('hud_slow'));
    if (data.invisible) lines.push(Pop.t('hud_invisible'));
    if (data.spectate) lines.push(Pop.t('hud_spectating', data.spectate.name, data.spectate.id),
      '[' + data.stopKey + '] ' + Pop.t('hud_stop'));
    hud.replaceChildren(...lines.map(line => {
      const element = document.createElement('div');
      element.textContent = line;
      return element;
    }));
    Pop.show(hud, lines.length > 0);
  });

  banner('admin-announce', 'announce-message', 'pop_admin:announce', 'message');
  banner('admin-warn', 'warn-reason', 'pop_admin:warn', 'reason');

  byId('close').addEventListener('click', () => Pop.post('close'));
  byId('refresh').addEventListener('click', loadPlayers);
  byId('search').addEventListener('input', renderPlayers);
  byId('reason').addEventListener('input', cancelConfirmation);
  byId('duration').addEventListener('change', cancelConfirmation);
  byId('back').addEventListener('click', () => {
    cancelConfirmation();
    selected = null;
    renderPlayers();
  });
  all('[data-tab]').forEach(control => control.addEventListener('click', () => openTab(control.dataset.tab)));
  all('[data-act]').forEach(control => control.addEventListener('click', act));
})();
