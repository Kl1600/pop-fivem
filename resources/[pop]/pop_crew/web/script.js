/* pop_crew : panneau NUI. Vanilla JS, aucune dépendance (kit/pop.js chargé avant).
 * Messages reçus : crew:open, crew:update, crew:close (SPEC §5.1).
 * Callbacks envoyés : create, nearby, invite, respond, leave, kick, setRank, disband, close (SPEC §5.2).
 * Noms (crew, membres) toujours insérés avec textContent.
 */
(function () {
  'use strict';

  var CONFIRM_MS = 3000;
  var HEX = /^#[0-9a-f]{6}$/i;

  var $ = function (id) { return document.getElementById(id); };
  var app = $('app');
  var ui = {
    invite: $('view-invite'), inviteDot: $('invite-dot'), inviteName: $('invite-name'),
    inviteExpires: $('invite-expires'), inviteAccept: $('invite-accept'), inviteDecline: $('invite-decline'),
    create: $('view-create'), createName: $('create-name'), createColors: $('create-colors'),
    createCost: $('create-cost'), createSubmit: $('create-submit'),
    crew: $('view-crew'), crewDot: $('crew-dot'), crewName: $('crew-name'), crewRank: $('crew-rank'),
    crewCount: $('crew-count'), crewMembers: $('crew-members'),
    crewInvite: $('crew-invite'), crewLeave: $('crew-leave'), crewDisband: $('crew-disband'),
    nearby: $('view-nearby'), nearbyList: $('nearby-list'), nearbyNone: $('nearby-none'), nearbyBack: $('nearby-back'),
    close: $('close')
  };

  var state = {
    open: false,
    data: null,
    view: 'main',          // 'main' | 'nearby'
    color: null,           // couleur choisie à la création
    inviteLeft: 0,         // secondes restantes de l'invitation
    busy: false
  };

  var inviteTimer = null;
  var armed = [];          // { key, btn, label, timer, until } : confirmations en attente
  var rearm = {};          // [key] = échéance : confirmations à reprendre pendant un re-rendu (crew:update)

  /* ---------------- Utilitaires ---------------- */

  function el(tag, className, parent, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    if (parent) parent.appendChild(node);
    return node;
  }

  function setVisible(node, visible) { node.classList.toggle('pop-hidden', !visible); }

  function setSwatch(node, color) { node.style.backgroundColor = HEX.test(color || '') ? color : ''; }

  function clear(node) { while (node.firstChild) node.removeChild(node.firstChild); }

  // Longueur en caractères (points de code), comme utf8.len côté serveur.
  function charLength(str) { return Array.from(str).length; }

  function normalizeName(str) { return String(str || '').trim().replace(/\s+/g, ' '); }

  function disarmAll() {
    armed.forEach(function (a) {
      clearTimeout(a.timer);
      a.btn.classList.remove('is-armed');
      a.btn.textContent = a.label;
    });
    armed = [];
  }

  function arm(btn, key, label, ms) {
    var entry = { key: key, btn: btn, label: label, until: Date.now() + ms };
    entry.timer = setTimeout(function () {
      btn.classList.remove('is-armed');
      btn.textContent = label;
      armed = armed.filter(function (a) { return a !== entry; });
    }, ms);
    armed.push(entry);
    btn.classList.add('is-armed');
    btn.textContent = Pop.t('confirm');
  }

  // Action destructrice : 1er clic -> « confirm » pendant 3 s ; 2e clic -> envoi.
  // `key` identifie la cible (ex. 'kick:7') : une confirmation survit à un re-rendu si la cible existe toujours.
  function confirmable(btn, key, label, fn) {
    btn.classList.remove('is-armed');
    btn.textContent = label;
    btn.onclick = function () {
      for (var i = 0; i < armed.length; i++) {
        if (armed[i].btn === btn) {
          disarmAll();
          fn();
          return;
        }
      }
      disarmAll();
      arm(btn, key, label, CONFIRM_MS);
    };
    var left = key && rearm[key] ? rearm[key] - Date.now() : 0;
    if (left > 0) arm(btn, key, label, left);
  }

  // Envoie un callback en évitant les doubles clics ; la mise à jour arrive ensuite par crew:update.
  function send(name, body) {
    if (state.busy) return Promise.resolve(null);
    state.busy = true;
    app.classList.add('is-busy');
    return Pop.post(name, body).then(function (res) {
      state.busy = false;
      app.classList.remove('is-busy');
      return res;
    });
  }

  function hide() {
    state.open = false;
    state.view = 'main';
    disarmAll();
    stopInviteTimer();
    Pop.show(app, false);
    if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
  }

  /* ---------------- Invitation ---------------- */

  function stopInviteTimer() {
    if (inviteTimer) clearInterval(inviteTimer);
    inviteTimer = null;
  }

  function renderInviteExpires() {
    ui.inviteExpires.textContent = Pop.t('invite_expires', Math.max(0, state.inviteLeft));
  }

  function renderInvite(invite) {
    stopInviteTimer();
    setSwatch(ui.inviteDot, invite.color);
    ui.inviteName.textContent = String(invite.crew || '');
    state.inviteLeft = Math.max(0, Math.floor(Number(invite.expires) || 0));
    renderInviteExpires();
    ui.inviteAccept.textContent = Pop.t('accept');
    ui.inviteDecline.textContent = Pop.t('decline');
    inviteTimer = setInterval(function () {
      state.inviteLeft -= 1;
      if (state.inviteLeft <= 0) {
        stopInviteTimer();
        setVisible(ui.invite, false);
        return;
      }
      renderInviteExpires();
    }, 1000);
  }

  /* ---------------- Création ---------------- */

  function updateCreateButton() {
    var c = state.data && state.data.create;
    if (!c) return;
    var len = charLength(normalizeName(ui.createName.value));
    ui.createSubmit.disabled = !(len >= (c.nameMin || 1) && len <= (c.nameMax || 32)) || !state.color;
  }

  function renderCreate(c) {
    var colors = Array.isArray(c.colors) ? c.colors.filter(function (x) { return HEX.test(x); }) : [];
    if (colors.indexOf(state.color) === -1) state.color = colors[0] || null;

    if (c.nameMax) ui.createName.maxLength = c.nameMax;

    clear(ui.createColors);
    colors.forEach(function (color) {
      var b = el('button', 'crew-color' + (color === state.color ? ' is-selected' : ''), ui.createColors);
      b.type = 'button';
      b.style.backgroundColor = color;
      b.setAttribute('aria-label', color);
      b.onclick = function () {
        state.color = color;
        Array.prototype.forEach.call(ui.createColors.children, function (n) { n.classList.toggle('is-selected', n === b); });
        updateCreateButton();
      };
    });

    var cost = Number(c.cost) || 0;
    ui.createCost.textContent = cost > 0
      ? Pop.t('create_cost', Pop.t('money', cost.toLocaleString()))
      : Pop.t('create_free');

    ui.createSubmit.textContent = Pop.t('create_button');
    updateCreateButton();
  }

  /* ---------------- Crew ---------------- */

  function renderMember(crew, m, parent) {
    var row = el('div', 'crew-member' + (m.online ? '' : ' is-offline'), parent);

    var line = el('div', 'crew-line', row);
    var dot = el('span', 'crew-status' + (m.online ? ' is-online' : ''), line);
    dot.title = Pop.t(m.online ? 'online' : 'offline');
    el('span', 'crew-name', line, String(m.name || ''));
    el('span', 'crew-meta pop-small', line,
      String(m.rankLabel || '') + (m.me ? ' · ' + Pop.t('you') : ''));

    if (!m.canPromote && !m.canDemote && !m.canKick) return;

    var actions = el('div', 'crew-actions', row);
    var rank = Number(m.rank) || 0;

    if (m.canPromote) {
      var promote = el('button', 'pop-button', actions);
      promote.type = 'button';
      if (rank === 2 && crew.rank === 1) {
        confirmable(promote, 'transfer:' + m.id, Pop.t('transfer'), function () { send('setRank', { memberId: m.id, rank: 1 }); });
      } else {
        promote.textContent = Pop.t('promote');
        promote.onclick = function () { send('setRank', { memberId: m.id, rank: rank - 1 }); };
      }
    }
    if (m.canDemote) {
      var demote = el('button', 'pop-button', actions, Pop.t('demote'));
      demote.type = 'button';
      demote.onclick = function () { send('setRank', { memberId: m.id, rank: rank + 1 }); };
    }
    if (m.canKick) {
      var kick = el('button', 'pop-button crew-danger', actions);
      kick.type = 'button';
      confirmable(kick, 'kick:' + m.id, Pop.t('kick'), function () { send('kick', { memberId: m.id }); });
    }
  }

  function renderCrew(crew) {
    var members = Array.isArray(crew.members) ? crew.members : [];
    var perms = crew.perms || {};

    setSwatch(ui.crewDot, crew.color);
    ui.crewName.textContent = String(crew.name || '');
    ui.crewRank.textContent = String(crew.rankLabel || '');
    ui.crewCount.textContent = Pop.t('members_count', members.length, crew.maxMembers || members.length);

    clear(ui.crewMembers);
    members.forEach(function (m) { renderMember(crew, m, ui.crewMembers); });

    ui.crewInvite.textContent = Pop.t('invite_button');
    setVisible(ui.crewInvite, !!perms.invite);

    var canLeave = crew.rank !== 1 || members.length <= 1;
    setVisible(ui.crewLeave, canLeave);
    confirmable(ui.crewLeave, canLeave ? 'leave' : null, Pop.t('leave'), function () { send('leave'); });

    setVisible(ui.crewDisband, !!perms.disband);
    confirmable(ui.crewDisband, perms.disband ? 'disband' : null, Pop.t('disband'), function () { send('disband'); });
  }

  /* ---------------- Joueurs proches ---------------- */

  function renderNearby(players) {
    clear(ui.nearbyList);
    setVisible(ui.nearbyNone, players.length === 0);
    players.forEach(function (p) {
      var id = Number(p.id);
      if (!Number.isInteger(id)) return;
      var row = el('div', 'crew-nearby', ui.nearbyList);
      el('span', 'crew-name', row, Pop.t('player_id', id));
      el('span', 'pop-small', row, Pop.t('distance', Math.round(Number(p.dist) || 0)));
      var b = el('button', 'pop-button', row, Pop.t('invite_button'));
      b.type = 'button';
      b.onclick = function () {
        send('invite', { id: id }).then(function (res) {
          if (res && res.ok) b.disabled = true;
        });
      };
    });
  }

  function loadNearby() {
    clear(ui.nearbyList);
    setVisible(ui.nearbyNone, false);
    Pop.post('nearby').then(function (res) {
      if (!state.open || state.view !== 'nearby') return;
      renderNearby(res && Array.isArray(res.players) ? res.players : []);
    });
  }

  /* ---------------- Rendu global ---------------- */

  // keepArmed : reprend les confirmations dont la cible existe encore après le re-rendu.
  function render(keepArmed) {
    var d = state.data || {};
    var crew = d.crew || null;

    rearm = {};
    if (keepArmed) armed.forEach(function (a) { if (a.key) rearm[a.key] = a.until; });
    disarmAll();

    if (!crew || !(crew.perms && crew.perms.invite)) state.view = 'main';

    var showInvite = !crew && !!d.invite;
    setVisible(ui.invite, showInvite);
    if (showInvite) renderInvite(d.invite); else stopInviteTimer();

    var showCreate = !crew && !!d.create;
    setVisible(ui.create, showCreate);
    if (showCreate) renderCreate(d.create);

    setVisible(ui.crew, !!crew && state.view === 'main');
    if (crew) renderCrew(crew);

    setVisible(ui.nearby, !!crew && state.view === 'nearby');

    ui.close.textContent = Pop.t('close');
    rearm = {};
  }

  /* ---------------- Événements UI ---------------- */

  ui.inviteAccept.onclick = function () { send('respond', { accept: true }); };
  ui.inviteDecline.onclick = function () { send('respond', { accept: false }); };

  ui.createName.addEventListener('input', updateCreateButton);
  ui.createName.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' && !ui.createSubmit.disabled) ui.createSubmit.click();
  });
  ui.createSubmit.onclick = function () {
    if (ui.createSubmit.disabled || !state.color) return;
    send('create', { name: normalizeName(ui.createName.value), color: state.color }).then(function (res) {
      if (res && res.ok) ui.createName.value = '';
    });
  };

  ui.crewInvite.onclick = function () {
    state.view = 'nearby';
    disarmAll();
    setVisible(ui.crew, false);
    setVisible(ui.nearby, true);
    loadNearby();
  };
  ui.nearbyBack.onclick = function () {
    state.view = 'main';
    render();
  };

  ui.close.onclick = function () {
    hide();
    Pop.post('close');
  };

  // Échap : le kit envoie déjà 'close' au Lua ; on masque seulement le panneau.
  window.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && state.open) hide();
  });

  /* ---------------- Messages Lua ---------------- */

  Pop.on('crew:open', function (msg) {
    state.data = msg.data || {};
    state.view = 'main';
    state.open = true;
    render();
    Pop.show(app, true);
  });

  Pop.on('crew:update', function (msg) {
    state.data = msg.data || {};
    if (!state.open) return;
    render(true);
  });

  Pop.on('crew:close', hide);

  // Changement de langue à chaud : re-rendu des textes dynamiques.
  Pop.on('pop:locale', function () { if (state.open) render(true); });
})();
