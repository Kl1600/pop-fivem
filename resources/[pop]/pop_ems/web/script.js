/* pop_ems : NUI (appels, menu de soins, diagnostic). Vanilla JS, s'appuie sur kit/pop.js. */
(function () {
  'use strict';

  var $ = function (id) { return document.getElementById(id); };
  var ACTIONS = ['diagnose', 'bandage', 'kit', 'revive', 'load'];
  var PARTS = ['head', 'torso', 'leftArm', 'rightArm', 'leftLeg', 'rightLeg'];
  var DIAG_MS = 10000;

  var callsEl = $('calls'), callList = $('callList'), callFooter = $('callFooter'), callKey = $('callKey');
  var menuEl = $('menu'), menuList = $('menuList');
  var diagEl = $('diag'), diagList = $('diagList');
  var diagTimer = null;
  var lastCalls = null;

  // Texte traduit ; '%%' (format Lua) devient '%'.
  function tr() {
    return Pop.t.apply(null, arguments).replace(/%%/g, '%');
  }

  function el(tag, className, text, parent) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    if (parent) parent.appendChild(node);
    return node;
  }

  function icon(parent) {
    var wrap = el('span', 'ems-icon', null, parent);
    wrap.setAttribute('aria-hidden', 'true');
    wrap.innerHTML = '<svg viewBox="0 0 16 16"><path d="M6.5 2h3v4.5H14v3H9.5V14h-3V9.5H2v-3h4.5z"/></svg>';
    return wrap;
  }

  // Fondu 150 ms (kit) puis retrait du flux, pour que le diagnostic remonte sous le menu.
  function fade(node, visible) {
    clearTimeout(node.fadeTimer);
    if (visible) {
      node.classList.remove('pop-hidden');
      void node.offsetWidth; // applique display avant de lancer le fondu
      Pop.show(node, true);
    } else {
      Pop.show(node, false);
      node.fadeTimer = setTimeout(function () { node.classList.add('pop-hidden'); }, 160);
    }
  }

  function int(v) {
    v = Number(v);
    return isFinite(v) ? Math.round(v) : 0;
  }

  /* ---------------- Appels ---------------- */

  function renderCalls(data) {
    data = data || {};
    lastCalls = data;
    var calls = Array.isArray(data.calls) ? data.calls : [];

    if (!calls.length) {
      Pop.show(callsEl, false);
      return; // contenu laissé en place pendant le fondu
    }

    var frag = document.createDocumentFragment();
    var hasPending = false;

    calls.forEach(function (c) {
      if (!c) return;
      var card = el('div', 'ems-panel ems-call', null, frag);

      var top = el('div', 'ems-call-top', null, card);
      icon(top);
      el('span', 'ems-title', tr('call_title'), top);
      var age = int(c.age);
      el('span', 'ems-muted ems-call-age', age <= 0 ? tr('call_age_now') : tr('call_age', age), top);

      var body = el('div', 'ems-call-body', null, card);
      var place = el('div', 'ems-call-street', null, body);
      place.textContent = (c.street ? c.street + ' · ' : '') + tr('call_distance', int(c.distance));

      if (c.mine) {
        el('div', 'ems-accent', tr('call_status_mine'), body);
        el('div', 'ems-call-bar', null, card);
      } else if (c.status === 'taken') {
        el('div', 'ems-muted', tr('call_status_taken', c.medic || ''), body);
      } else {
        el('div', 'ems-muted', tr('call_status_pending'), body);
        hasPending = true;
      }
    });

    callList.replaceChildren(frag);
    callKey.textContent = data.acceptKey || 'Y';
    callFooter.classList.toggle('pop-hidden', !hasPending);
    Pop.show(callsEl, true);
  }

  /* ---------------- Menu de soins ---------------- */

  function hideMenu() {
    if (!menuEl.classList.contains('pop-hidden')) fade(menuEl, false);
  }

  function renderMenu(data) {
    data = data || {};
    if (!data.show) {
      hideMenu();
      return;
    }

    var enabled = {};
    (Array.isArray(data.actions) ? data.actions : []).forEach(function (a) {
      if (a && ACTIONS.indexOf(a.id) !== -1) enabled[a.id] = !!a.enabled;
    });

    var frag = document.createDocumentFragment();
    ACTIONS.forEach(function (id) {
      if (!(id in enabled)) return;
      var btn = el('button', 'ems-btn', null, frag);
      btn.type = 'button';
      btn.disabled = !enabled[id];
      btn.dataset.id = id;
      var label = el('span', 'ems-btn-label', null, btn);
      label.setAttribute('data-locale', 'menu_' + id);
      var hint = el('span', 'ems-muted', null, btn);
      hint.setAttribute('data-locale', 'menu_hint_' + id);
    });
    menuList.replaceChildren(frag);
    Pop.translate(menuList);

    hideDiag(); // nouveau patient : l'ancien diagnostic disparaît
    fade(menuEl, true);
  }

  menuList.addEventListener('click', function (e) {
    var btn = e.target.closest('.ems-btn');
    if (!btn || btn.disabled || !menuEl.classList.contains('is-visible')) return;
    hideMenu();
    Pop.post('menuAction', { id: btn.dataset.id });
  });

  $('menuClose').addEventListener('click', function () {
    hideMenu();
    Pop.post('close');
  });

  // Échap : le kit envoie déjà 'close' au Lua ; on masque tout de suite.
  window.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') hideMenu();
  });

  /* ---------------- Diagnostic ---------------- */

  function hideDiag() {
    if (diagTimer) clearTimeout(diagTimer);
    diagTimer = null;
    if (!diagEl.classList.contains('pop-hidden')) fade(diagEl, false);
  }

  function line(text, critical) {
    el('li', critical ? 'ems-accent' : '', text, diagList);
  }

  function renderDiag(d) {
    d = d || {};
    if (diagTimer) clearTimeout(diagTimer);
    diagList.replaceChildren();

    var health = Math.max(0, Math.min(100, int(d.health)));
    line(tr(d.dead ? 'diag_unconscious' : 'diag_conscious'), !!d.dead);
    line(tr('diag_health', health), health < 50);
    line(tr(d.bleeding ? 'diag_bleeding' : 'diag_no_bleeding'), !!d.bleeding);
    if (d.limp) line(tr('diag_limp'), true);

    if (d.parts && typeof d.parts === 'object') {
      var firstPart = true;
      PARTS.forEach(function (p) {
        if (d.parts[p] === undefined || d.parts[p] === null) return;
        var v = Math.max(0, Math.min(100, int(d.parts[p])));
        line(tr('diag_part', tr('part_' + p), v), v < 50);
        if (firstPart) { diagList.lastChild.classList.add('ems-sep'); firstPart = false; }
      });
    }

    fade(diagEl, true);
    diagTimer = setTimeout(hideDiag, DIAG_MS);
  }

  /* ---------------- Messages Lua ---------------- */

  Pop.on('calls', function (msg) { renderCalls(msg.data); });
  Pop.on('menu', function (msg) { renderMenu(msg.data); });
  Pop.on('diagnosis', function (msg) { renderDiag(msg.data); });

  // Changement de langue : les textes formatés des appels sont recalculés.
  Pop.on('pop:locale', function () {
    if (lastCalls) renderCalls(lastCalls);
  });
})();
