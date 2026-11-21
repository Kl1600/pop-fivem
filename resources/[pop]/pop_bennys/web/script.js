/* pop_bennys : panneau de personnalisation. Vanilla JS, DOM construit sans innerHTML. */
(function () {
  'use strict';

  var panel = document.getElementById('bennys');
  var tabsEl = document.getElementById('bennys-tabs');
  var itemsEl = document.getElementById('bennys-items');
  var totalEl = document.getElementById('bennys-total');
  var confirmBtn = document.getElementById('bennys-confirm');
  var cancelBtn = document.getElementById('bennys-cancel');

  var TYPES = { list: true, toggle: true, color: true, neon: true, neoncolor: true };
  var HEX = /^#[0-9a-f]{3,8}$/i;

  var state = {
    open: false,
    pending: false,
    colors: [],
    neonColors: [],
    prices: {},
    categories: [], // [{ id, keys: [] }]
    meta: {},       // key -> { type, min, max, category }
    original: {},
    current: {},
    active: null,
    rows: {}        // key -> fonction de rafraîchissement de la ligne affichée
  };

  /* ---------------- Utilitaires ---------------- */

  function el(tag, className, parent) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (parent) parent.appendChild(node);
    return node;
  }

  function clear(node) {
    while (node.firstChild) node.removeChild(node.firstChild);
  }

  function clone(v) {
    return Array.isArray(v) ? v.slice() : v;
  }

  function same(a, b) {
    if (Array.isArray(a) && Array.isArray(b)) {
      if (a.length !== b.length) return false;
      for (var i = 0; i < a.length; i++) if (!same(a[i], b[i])) return false;
      return true;
    }
    return a === b;
  }

  function num(v) {
    return typeof v === 'number' && isFinite(v) ? v : 0;
  }

  function byte(v) {
    return Math.max(0, Math.min(255, Math.floor(num(v))));
  }

  function rgb(c) {
    return 'rgb(' + byte(c[0]) + ', ' + byte(c[1]) + ', ' + byte(c[2]) + ')';
  }

  function isModified(key) {
    return !same(state.current[key], state.original[key]);
  }

  /* Même règle que Bennys.Price : liste -> prix du niveau, toggle -> prix si actif, sinon le nombre. */
  function linePrice(key) {
    if (!isModified(key)) return 0;
    var p = state.prices[key];
    var v = state.current[key];
    if (Array.isArray(p)) return typeof v === 'number' && v >= 0 ? num(p[v]) : 0;
    if (typeof v === 'boolean') return v ? num(p) : 0;
    return num(p);
  }

  function modifiedKeys() {
    var out = [];
    state.categories.forEach(function (cat) {
      cat.keys.forEach(function (key) { if (isModified(key)) out.push(key); });
    });
    return out;
  }

  /* ---------------- Totaux ---------------- */

  function refreshFooter() {
    var keys = modifiedKeys();
    var total = 0;
    keys.forEach(function (key) { total += linePrice(key); });
    totalEl.textContent = Pop.t('total', total);
    confirmBtn.disabled = keys.length === 0 || state.pending;
  }

  /* ---------------- Aperçu ---------------- */

  function applyUpdates(updates) {
    if (!Array.isArray(updates)) return;
    updates.forEach(function (u) {
      if (!u || typeof u.key !== 'string' || !state.meta[u.key]) return;
      var m = state.meta[u.key];
      if (typeof u.min === 'number') m.min = u.min;
      if (typeof u.max === 'number') m.max = u.max;
      if (u.value !== undefined) state.current[u.key] = clone(u.value);
      if (state.rows[u.key]) state.rows[u.key]();
    });
  }

  function setValue(key, value) {
    if (!state.open) return;
    var m = state.meta[key];
    if (m && m.type === 'list') {
      if (typeof value !== 'number' || !isFinite(value) || m.max < m.min) return;
      value = Math.max(m.min, Math.min(m.max, Math.round(value)));
    }
    var previous = clone(state.current[key]);
    state.current[key] = clone(value);
    if (state.rows[key]) state.rows[key]();
    refreshFooter();

    Pop.post('pop_bennys:preview', { key: key, value: value }).then(function (res) {
      if (!state.open || !res) return;
      if (res.ok === false) {
        // Refusé par le Lua : on revient à la valeur précédente si aucun autre changement n'a eu lieu entre-temps.
        if (same(state.current[key], value)) {
          state.current[key] = previous;
          if (state.rows[key]) state.rows[key]();
        }
      } else {
        applyUpdates(res.updates);
      }
      refreshFooter();
    });
  }

  /* ---------------- Contrôles ---------------- */

  function listText(key, v, m) {
    if (v === -1) return Pop.t('stock');
    if (key === 'wheels') return Pop.t('wheel_type_' + v);
    if (key === 'windowTint') return Pop.t('tint_' + v);
    if (m.category === 'performance') return Pop.t('level', v + 1);
    return Pop.t('option', v + 1, m.max + 1);
  }

  function buildList(key, parent) {
    var m = state.meta[key];
    var box = el('div', 'bennys-stepper', parent);
    var prev = el('button', 'pop-button bennys-step', box);
    var value = el('span', 'bennys-value', box);
    var next = el('button', 'pop-button bennys-step', box);
    prev.type = next.type = 'button';
    prev.textContent = '‹';
    next.textContent = '›';

    prev.addEventListener('click', function () {
      var v = num(state.current[key]);
      if (v > m.min) setValue(key, Math.max(m.min, v - 1));
    });
    next.addEventListener('click', function () {
      var v = num(state.current[key]);
      if (v < m.max) setValue(key, Math.min(m.max, v + 1));
    });

    return function () {
      var v = num(state.current[key]);
      value.textContent = listText(key, v, m);
      prev.disabled = v <= m.min;
      next.disabled = v >= m.max;
    };
  }

  function buildToggle(key, parent) {
    var box = el('div', 'bennys-choices', parent);
    var btn = el('button', 'pop-button pop-small bennys-opt', box);
    btn.type = 'button';
    btn.addEventListener('click', function () { setValue(key, !state.current[key]); });

    return function () {
      var on = state.current[key] === true;
      btn.textContent = Pop.t(on ? 'on' : 'off');
      btn.classList.toggle('is-on', on);
    };
  }

  function buildNeon(key, parent) {
    var box = el('div', 'bennys-choices', parent);
    var buttons = [];
    for (var i = 0; i < 4; i++) {
      (function (side) {
        var btn = el('button', 'pop-button pop-small bennys-opt', box);
        btn.type = 'button';
        btn.addEventListener('click', function () {
          var v = Array.isArray(state.current[key]) ? state.current[key].slice() : [false, false, false, false];
          while (v.length < 4) v.push(false);
          v[side] = !v[side];
          setValue(key, v);
        });
        buttons.push(btn);
      })(i);
    }

    return function () {
      var v = Array.isArray(state.current[key]) ? state.current[key] : [];
      buttons.forEach(function (btn, side) {
        btn.textContent = Pop.t('neon_' + side);
        btn.classList.toggle('is-on', v[side] === true);
      });
    };
  }

  function buildSwatches(key, parent, entries, valueOf, cssOf) {
    var box = el('div', 'bennys-swatches', parent);
    var swatches = [];
    entries.forEach(function (entry) {
      var btn = el('button', 'bennys-swatch', box);
      btn.type = 'button';
      btn.style.backgroundColor = cssOf(entry);
      btn.addEventListener('click', function () {
        var v = valueOf(entry);
        if (!same(state.current[key], v)) setValue(key, v);
      });
      swatches.push({ btn: btn, value: valueOf(entry) });
    });

    return function () {
      swatches.forEach(function (s) { s.btn.classList.toggle('is-on', same(state.current[key], s.value)); });
    };
  }

  function buildColor(key, parent) {
    return buildSwatches(key, parent, state.colors,
      function (c) { return c.id; },
      function (c) { return c.hex; });
  }

  function buildNeonColor(key, parent) {
    return buildSwatches(key, parent, state.neonColors,
      function (c) { return [byte(c[0]), byte(c[1]), byte(c[2])]; },
      rgb);
  }

  var BUILDERS = {
    list: buildList,
    toggle: buildToggle,
    neon: buildNeon,
    color: buildColor,
    neoncolor: buildNeonColor
  };

  /* ---------------- Rendu ---------------- */

  function buildRow(key) {
    var m = state.meta[key];
    var row = el('div', 'bennys-row', itemsEl);
    var head = el('div', 'bennys-row-head', row);
    var label = el('span', 'bennys-label', head);
    var price = el('span', 'bennys-price', head);
    label.textContent = Pop.t('label_' + key);

    var refreshControl = BUILDERS[m.type](key, row);

    state.rows[key] = function () {
      refreshControl();
      price.textContent = isModified(key) ? Pop.t('price', linePrice(key)) : '';
    };
    state.rows[key]();
  }

  function renderTabs() {
    clear(tabsEl);
    state.categories.forEach(function (cat) {
      var btn = el('button', 'pop-button pop-small bennys-opt', tabsEl);
      btn.type = 'button';
      btn.textContent = Pop.t('cat_' + cat.id);
      btn.classList.toggle('is-on', cat.id === state.active);
      btn.addEventListener('click', function () { selectTab(cat.id); });
    });
  }

  function renderItems() {
    clear(itemsEl);
    state.rows = {};
    itemsEl.scrollTop = 0;
    var cat = null;
    state.categories.forEach(function (c) { if (c.id === state.active) cat = c; });
    if (cat) cat.keys.forEach(buildRow);
  }

  function render() {
    renderTabs();
    renderItems();
    refreshFooter();
  }

  function selectTab(id) {
    if (!state.open || id === state.active) return;
    state.active = id;
    renderTabs();
    renderItems();
    Pop.post('pop_bennys:camera', { category: id });
  }

  /* ---------------- Ouverture / fermeture ---------------- */

  function parse(data) {
    state.colors = (Array.isArray(data.colors) ? data.colors : []).filter(function (c) {
      return c && typeof c.id === 'number' && typeof c.hex === 'string' && HEX.test(c.hex);
    });
    state.neonColors = (Array.isArray(data.neonColors) ? data.neonColors : []).filter(function (c) {
      return Array.isArray(c) && c.length >= 3;
    });
    state.prices = data.prices && typeof data.prices === 'object' ? data.prices : {};
    state.categories = [];
    state.meta = {};
    state.original = {};
    state.current = {};

    (Array.isArray(data.categories) ? data.categories : []).forEach(function (cat) {
      if (!cat || typeof cat.id !== 'string' || !Array.isArray(cat.items)) return;
      var keys = [];
      cat.items.forEach(function (it) {
        if (!it || typeof it.key !== 'string' || !TYPES[it.type] || state.meta[it.key]) return;
        state.meta[it.key] = {
          type: it.type,
          min: num(it.min),
          max: num(it.max),
          category: cat.id
        };
        state.original[it.key] = clone(it.value);
        state.current[it.key] = clone(it.value);
        keys.push(it.key);
      });
      if (keys.length) state.categories.push({ id: cat.id, keys: keys });
    });
  }

  function open(data) {
    parse(data);
    state.active = state.categories.length ? state.categories[0].id : null;
    state.pending = false;
    state.open = true;
    render();
    document.body.classList.add('bennys-open');
    Pop.show(panel, true);
  }

  function hide() {
    state.open = false;
    state.pending = false;
    document.body.classList.remove('bennys-open');
    Pop.show(panel, false);
  }

  function cancel() {
    if (!state.open) return;
    Pop.post('close');
    hide();
  }

  function confirm() {
    if (!state.open || state.pending) return;
    var changes = modifiedKeys().map(function (key) {
      return { key: key, value: clone(state.current[key]) };
    });
    if (!changes.length) return;

    state.pending = true;
    refreshFooter();
    Pop.post('pop_bennys:confirm', { changes: changes }).then(function (res) {
      if (!state.open) return;
      state.pending = false;
      if (res && res.ok) {
        hide();
      } else {
        refreshFooter(); // échec : le Lua notifie, le menu reste ouvert
      }
    });
  }

  confirmBtn.addEventListener('click', confirm);
  cancelBtn.addEventListener('click', cancel);

  // Échap : le kit envoie déjà 'close' au Lua, on masque seulement.
  window.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && state.open) hide();
  });

  Pop.on('pop_bennys:open', open);
  Pop.on('pop_bennys:close', hide);

  // Changement de langue pendant la session : textes dynamiques reconstruits.
  Pop.on('pop:locale', function () {
    if (!state.open) return;
    var scroll = itemsEl.scrollTop;
    render();
    itemsEl.scrollTop = scroll;
  });
})();
