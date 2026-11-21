/* pop_inventory : interface NUI (vanilla JS, aucune dépendance).
 * Le serveur fait autorité : la NUI n'écrit jamais elle-même dans les slots, seul 'pop_inventory:update' les change.
 * Texte inséré uniquement par textContent ; aucun texte en dur (locales via Pop.t / data-locale).
 */
(function () {
  'use strict';

  var HOTBAR = 5;
  var HOTBAR_TIME = 2500;
  var NOTIFY_TIME = 2500;
  var NOTIFY_MAX = 4;
  var TOOLTIP_DELAY = 250;
  var DRAG_THRESHOLD = 4; // px avant de considérer un glisser
  var DEFAULT_IMAGE = 'images/default.svg';
  var META_KEYS = ['durability', 'ammo', 'serial', 'plate', 'quality', 'registered'];
  var META_PERCENT = { durability: true, quality: true };

  var root = document.getElementById('inventory');
  var amountInput = document.getElementById('amount');
  var btnUse = document.getElementById('btn-use');
  var btnGive = document.getElementById('btn-give');
  var tooltip = document.getElementById('tooltip');
  var hotbar = document.getElementById('hotbar');
  var notify = document.getElementById('notify');

  var defs = {};
  var views = { player: null, secondary: null };
  var isOpen = false;

  /* ---------------- Utilitaires ---------------- */

  function el(tag, className, parent) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (parent) parent.appendChild(node);
    return node;
  }

  // json.encode({}) donne [] : un tableau est traité comme un objet vide.
  function meta(m) {
    return (m && typeof m === 'object' && !Array.isArray(m)) ? m : {};
  }

  function isNum(v) { return typeof v === 'number' && isFinite(v); }

  function kg(grams) { return ((Number(grams) || 0) / 1000).toFixed(1); }

  function defOf(name) { return defs[name] || {}; }

  function amount() {
    var n = parseInt(amountInput.value, 10);
    return (isNum(n) && n > 0) ? n : 0;
  }

  function safeFile(v) {
    return (typeof v === 'string' && /^[A-Za-z0-9_\-]+$/.test(v)) ? v : null;
  }

  function imageFile(name, md) {
    return safeFile(md.image) || safeFile(defOf(name).image) || safeFile(name) || 'default';
  }

  // Image de l'item ; repli unique sur default.svg (pas de boucle).
  function setImage(img, file) {
    if (img._file === file) return;
    img._file = file;
    img.onerror = function () {
      img.onerror = null;
      img.src = DEFAULT_IMAGE;
    };
    img.src = file === 'default' ? DEFAULT_IMAGE : 'images/' + file + '.png';
  }

  // Les items arrivent en liste (ou table indexée) : on les range par slot.
  function toSlotMap(items) {
    var map = {};
    if (!items || typeof items !== 'object') return map;
    Object.keys(items).forEach(function (k) {
      var it = items[k];
      if (it && typeof it === 'object' && typeof it.name === 'string' && isNum(it.slot)) map[it.slot] = it;
    });
    return map;
  }

  function normalizeView(v) {
    if (!v || typeof v !== 'object') return null;
    return {
      type: v.type,
      label: v.label || '',
      slots: Math.max(0, Math.floor(Number(v.slots) || 0)),
      maxWeight: Number(v.maxWeight) || 0,
      weight: Number(v.weight) || 0,
      items: toSlotMap(v.items)
    };
  }

  function isShop() { return !!(views.secondary && views.secondary.type === 'shop'); }

  function getItem(side, slot) {
    var v = views[side];
    return v ? v.items[slot] || null : null;
  }

  /* ---------------- Slots ---------------- */

  function createSlot(number) {
    var s = el('div', 'slot');
    s._img = el('img', 'slot-img', s);
    s._img.alt = '';
    s._img.draggable = false;
    if (number) el('span', 'slot-num', s).textContent = String(number);
    s._count = el('span', 'slot-count', s);
    s._price = el('span', 'slot-price', s);
    s._dura = el('div', 'slot-dura pop-hidden', s);
    s._duraFill = el('div', 'slot-dura-fill', s._dura);
    return s;
  }

  function fillSlot(s, item, shop) {
    if (!item) {
      s.classList.remove('has-item');
      s._count.textContent = '';
      s._price.textContent = '';
      s._dura.classList.add('pop-hidden');
      return;
    }
    var md = meta(item.metadata);
    s.classList.add('has-item');
    setImage(s._img, imageFile(item.name, md));
    s._count.textContent = (!shop && item.count > 1) ? 'x' + item.count : '';
    s._price.textContent = shop && isNum(item.price) ? Pop.t('ui_price', item.price) : '';
    if (isNum(md.durability)) {
      var d = Math.max(0, Math.min(100, md.durability));
      s._duraFill.style.width = d + '%';
      s._duraFill.classList.toggle('is-danger', d < 20);
      s._dura.classList.remove('pop-hidden');
    } else {
      s._dura.classList.add('pop-hidden');
    }
  }

  /* ---------------- Panneaux ---------------- */

  function makePanel(id, side) {
    var node = document.getElementById(id);
    return {
      side: side,
      el: node,
      label: node.querySelector('.inv-label'),
      weight: node.querySelector('.inv-weight'),
      fill: node.querySelector('.inv-bar-fill'),
      grid: node.querySelector('.inv-grid'),
      slots: {}
    };
  }

  var panels = {
    player: makePanel('panel-player', 'player'),
    secondary: makePanel('panel-secondary', 'secondary')
  };

  function renderHead(p) {
    var v = views[p.side];
    if (!v) return;
    p.label.textContent = v.label;
    p.label.title = v.label;
    if (v.type === 'shop') return;
    p.weight.textContent = Pop.t('ui_weight_value', kg(v.weight), kg(v.maxWeight));
    var ratio = v.maxWeight > 0 ? v.weight / v.maxWeight : 0;
    p.fill.style.width = Math.min(100, Math.max(0, ratio * 100)) + '%';
    p.fill.classList.toggle('is-danger', ratio > 0.9);
  }

  function renderPanel(p) {
    var v = views[p.side];
    p.el.classList.toggle('pop-hidden', !v);
    if (!v) return;
    var shop = v.type === 'shop';
    p.el.classList.toggle('is-shop', shop);
    renderHead(p);

    p.grid.textContent = '';
    p.slots = {};
    var frag = document.createDocumentFragment();
    for (var i = 1; i <= v.slots; i++) {
      var s = createSlot(p.side === 'player' && i <= HOTBAR ? i : 0);
      s.setAttribute('data-side', p.side);
      s.setAttribute('data-slot', String(i));
      fillSlot(s, v.items[i], shop);
      p.slots[i] = s;
      frag.appendChild(s);
    }
    p.grid.appendChild(frag);
    p.grid.scrollTop = 0;
  }

  function renderSlot(side, slot) {
    var s = panels[side].slots[slot];
    if (s) fillSlot(s, getItem(side, slot), side === 'secondary' && isShop());
  }

  /* ---------------- Ouverture / fermeture ---------------- */

  function open(data) {
    cancelDrag();
    hideTooltip();
    views.player = normalizeView(data.player);
    views.secondary = normalizeView(data.secondary);
    renderPanel(panels.player);
    renderPanel(panels.secondary);
    isOpen = true;
    hideHotbar();
    Pop.show(root, true);
  }

  function close() {
    cancelDrag();
    hideTooltip();
    isOpen = false;
    Pop.show(root, false);
  }

  /* ---------------- Mises à jour (serveur) ---------------- */

  function applyUpdate(data) {
    var changes = Array.isArray(data.changes) ? data.changes : [];
    changes.forEach(function (c) {
      if (!c || (c.side !== 'player' && c.side !== 'secondary')) return;
      var v = views[c.side];
      var slot = Number(c.slot);
      if (!v || !isNum(slot)) return;
      if (c.item && typeof c.item === 'object' && typeof c.item.name === 'string') {
        c.item.slot = slot;
        v.items[slot] = c.item;
      } else {
        delete v.items[slot];
      }
      renderSlot(c.side, slot);
      if (hoverSlot && hoverSlot.getAttribute('data-side') === c.side && Number(hoverSlot.getAttribute('data-slot')) === slot) {
        hideTooltip();
      }
    });
    var w = data.weights;
    if (w && typeof w === 'object') {
      ['player', 'secondary'].forEach(function (side) {
        if (views[side] && isNum(w[side])) {
          views[side].weight = w[side];
          renderHead(panels[side]);
        }
      });
    }
  }

  /* ---------------- Actions (Lua notifie les échecs) ---------------- */

  function doMove(from, fromSlot, to, toSlot) {
    var body = { from: from, fromSlot: fromSlot, to: to, count: amount() };
    if (toSlot) body.toSlot = toSlot;
    Pop.post('move', body);
  }

  function doBuy(index, toSlot) {
    var body = { index: index, count: amount() || 1 };
    if (toSlot) body.toSlot = toSlot;
    Pop.post('buy', body);
  }

  function doUse(slot) { Pop.post('use', { slot: slot }); }

  function doGive(slot) { Pop.post('give', { slot: slot, count: amount() }); }

  // Maj + clic : vers l'autre panneau, placement automatique.
  function quickMove(side, slot) {
    if (!views.secondary) return;
    if (side === 'secondary') {
      if (isShop()) doBuy(slot);
      else doMove('secondary', slot, 'player');
    } else if (!isShop()) {
      doMove('player', slot, 'secondary');
    }
  }

  function drop(side, slot, target) {
    if (!target) return;
    if (target === btnUse || target === btnGive) {
      if (side !== 'player') return;
      if (target === btnUse) doUse(slot); else doGive(slot);
      return;
    }
    var toSide = target.getAttribute('data-side');
    var toSlot = Number(target.getAttribute('data-slot'));
    if (!toSide || !isNum(toSlot)) return;
    if (side === 'secondary' && isShop()) {
      if (toSide === 'player') doBuy(slot, toSlot);
      return;
    }
    if (toSide === 'secondary' && isShop()) return;
    if (toSide === side && toSlot === slot) return;
    doMove(side, slot, toSide, toSlot);
  }

  /* ---------------- Glisser-déposer (souris, sans API HTML5) ---------------- */

  var press = null; // { side, slot, el, x, y }
  var drag = null;  // { side, slot, el, ghost }

  function slotFromEvent(e) {
    var s = e.target && e.target.closest ? e.target.closest('#inventory .slot') : null;
    return s && root.contains(s) ? s : null;
  }

  function dropTargetAt(x, y) {
    var node = document.elementFromPoint(x, y);
    if (!node || !node.closest) return null;
    var btn = node.closest('#btn-use, #btn-give');
    if (btn) return btn;
    var s = node.closest('#inventory .slot');
    return s || null;
  }

  function startDrag(e) {
    drag = { side: press.side, slot: press.slot, el: press.el };
    var ghost = el('div', 'inv-ghost', document.body);
    var img = el('img', '', ghost);
    img.alt = '';
    img.draggable = false;
    img.src = press.el._img.src || DEFAULT_IMAGE;
    drag.ghost = ghost;
    drag.el.classList.add('is-dragged');
    moveGhost(e.clientX, e.clientY);
    hideTooltip();
  }

  function moveGhost(x, y) {
    if (!drag) return;
    drag.ghost.style.left = x + 'px';
    drag.ghost.style.top = y + 'px';
  }

  function cancelDrag() {
    if (drag) {
      if (drag.ghost.parentNode) drag.ghost.parentNode.removeChild(drag.ghost);
      drag.el.classList.remove('is-dragged');
    }
    drag = null;
    press = null;
  }

  root.addEventListener('mousedown', function (e) {
    if (e.button !== 0 || !isOpen) return;
    var s = slotFromEvent(e);
    if (!s || !s.classList.contains('has-item')) return;
    e.preventDefault();
    press = {
      side: s.getAttribute('data-side'),
      slot: Number(s.getAttribute('data-slot')),
      el: s,
      x: e.clientX,
      y: e.clientY
    };
  });

  window.addEventListener('mousemove', function (e) {
    mouseX = e.clientX;
    mouseY = e.clientY;
    if (press && !drag) {
      if (Math.abs(e.clientX - press.x) + Math.abs(e.clientY - press.y) >= DRAG_THRESHOLD) startDrag(e);
    }
    if (drag) {
      moveGhost(e.clientX, e.clientY);
      return;
    }
    updateHover(e);
  });

  window.addEventListener('mouseup', function (e) {
    if (e.button !== 0) return;
    if (drag) {
      var d = drag;
      var target = dropTargetAt(e.clientX, e.clientY);
      cancelDrag();
      drop(d.side, d.slot, target);
      return;
    }
    if (press) {
      var p = press;
      press = null;
      if (e.shiftKey) quickMove(p.side, p.slot);
    }
  });

  root.addEventListener('dblclick', function (e) {
    if (e.shiftKey) return;
    var s = slotFromEvent(e);
    if (!s || s.getAttribute('data-side') !== 'player' || !s.classList.contains('has-item')) return;
    doUse(Number(s.getAttribute('data-slot')));
  });

  /* ---------------- Info-bulle ---------------- */

  var hoverSlot = null;
  var tipTimer = null;
  var tipVisible = false;
  var mouseX = 0;
  var mouseY = 0;

  function hideTooltip() {
    clearTimeout(tipTimer);
    tipTimer = null;
    hoverSlot = null;
    tipVisible = false;
    tooltip.classList.add('pop-hidden');
  }

  function updateHover(e) {
    if (!isOpen) return;
    var s = slotFromEvent(e);
    if (s !== hoverSlot) {
      hideTooltip();
      hoverSlot = s;
      if (s && s.classList.contains('has-item')) {
        tipTimer = setTimeout(showTooltip, TOOLTIP_DELAY);
      }
    } else if (tipVisible) {
      placeTooltip();
    }
  }

  function metaValue(key, value) {
    if (META_PERCENT[key] && isNum(value)) return Math.floor(value) + '%';
    if (isNum(value)) return String(Math.floor(value));
    return String(value);
  }

  function addRow(parent, label, value) {
    var row = el('div', 'tip-row', parent);
    el('span', '', row).textContent = label;
    el('span', '', row).textContent = value;
  }

  function showTooltip() {
    tipTimer = null;
    if (!hoverSlot || drag || !isOpen) return;
    var side = hoverSlot.getAttribute('data-side');
    var item = getItem(side, Number(hoverSlot.getAttribute('data-slot')));
    if (!item) return;
    var def = defOf(item.name);
    var md = meta(item.metadata);
    var shop = side === 'secondary' && isShop();

    tooltip.textContent = '';
    el('div', 'tip-label', tooltip).textContent = md.label || def.label || item.name;
    var desc = md.description || def.description;
    if (desc) el('div', 'tip-desc pop-small', tooltip).textContent = String(desc);

    var rows = el('div', 'tip-rows', tooltip);
    var count = shop ? 1 : (Number(item.count) || 1);
    addRow(rows, Pop.t('ui_weight'), Pop.t('ui_kg', kg((Number(def.weight) || 0) * count)));
    META_KEYS.forEach(function (key) {
      var v = md[key];
      if (v === undefined || v === null || v === '' || typeof v === 'object') return;
      addRow(rows, Pop.t('meta_' + key), metaValue(key, v));
    });
    if (shop && isNum(item.price)) el('div', 'tip-price', tooltip).textContent = Pop.t('ui_price', item.price);

    tooltip.classList.remove('pop-hidden');
    tipVisible = true;
    placeTooltip();
  }

  // Suit la souris sans sortir de l'écran.
  function placeTooltip() {
    var off = Math.round(window.innerHeight * 0.015);
    var w = tooltip.offsetWidth;
    var h = tooltip.offsetHeight;
    var rtl = document.documentElement.dir === 'rtl';
    var x = rtl ? mouseX - off - w : mouseX + off;
    var y = mouseY + off;
    if (x + w > window.innerWidth - off) x = mouseX - off - w;
    if (x < off) x = Math.min(mouseX + off, window.innerWidth - off - w);
    if (y + h > window.innerHeight - off) y = mouseY - off - h;
    if (y < off) y = off;
    tooltip.style.transform = 'translate(' + Math.round(x) + 'px,' + Math.round(y) + 'px)';
  }

  /* ---------------- Clavier ---------------- */

  window.addEventListener('keydown', function (e) {
    if (!isOpen) return;
    if (e.key === 'Escape') { close(); return; } // le kit prévient déjà Lua
    if (e.key === 'Tab' || e.code === 'KeyI') {
      e.preventDefault();
      if (e.repeat) return;
      close();
      Pop.post('close');
      return;
    }
    // Quantité au clavier sans avoir à cliquer dans le champ (le focus n'est pas modifié).
    if (e.target === amountInput) return;
    if (/^[0-9]$/.test(e.key)) {
      amountInput.value = (amountInput.value + e.key).replace(/^0+(?=\d)/, '').slice(0, 6);
    } else if (e.key === 'Backspace') {
      amountInput.value = amountInput.value.slice(0, -1);
    }
  });

  // Seulement des chiffres (pas de signe, pas de décimale).
  amountInput.addEventListener('input', function () {
    var clean = amountInput.value.replace(/[^0-9]/g, '').slice(0, 6);
    if (clean !== amountInput.value) amountInput.value = clean;
  });

  /* ---------------- Hotbar ---------------- */

  var hotbarSlots = [];
  var hotbarTimer = null;
  for (var h = 1; h <= HOTBAR; h++) hotbarSlots.push(hotbar.appendChild(createSlot(h)));

  function hideHotbar() {
    clearTimeout(hotbarTimer);
    hotbarTimer = null;
    Pop.show(hotbar, false);
  }

  function showHotbar(data) {
    var bySlot = {};
    var list = data.items && typeof data.items === 'object' ? data.items : [];
    var keys = Object.keys(list);
    keys.forEach(function (k, i) {
      var it = list[k];
      if (!it || typeof it !== 'object' || typeof it.name !== 'string') return;
      var slot = isNum(it.slot) && it.slot >= 1 && it.slot <= HOTBAR ? it.slot
        : (Array.isArray(list) ? i + 1 : Number(k));
      if (slot >= 1 && slot <= HOTBAR) bySlot[slot] = it;
    });
    hotbarSlots.forEach(function (s, i) {
      fillSlot(s, bySlot[i + 1] || null, false);
      s.classList.toggle('is-active', data.active === i + 1);
    });
    Pop.show(hotbar, true);
    clearTimeout(hotbarTimer);
    hotbarTimer = setTimeout(hideHotbar, HOTBAR_TIME);
  }

  /* ---------------- Rappels +2 / -1 ---------------- */

  function itemNotify(data) {
    if (isOpen || typeof data.name !== 'string') return;
    var count = Math.abs(Math.floor(Number(data.count) || 0));
    if (!count) return;
    while (notify.children.length >= NOTIFY_MAX) notify.removeChild(notify.firstChild);

    var row = el('div', 'inv-note pop-panel pop-fade' + (data.added ? '' : ' is-removed'), notify);
    var img = el('img', '', row);
    img.alt = '';
    setImage(img, imageFile(data.name, {}));
    var text = el('span', 'inv-note-text', row);
    el('span', 'inv-note-sign', text).textContent = (data.added ? '+' : '-') + count;
    text.appendChild(document.createTextNode(defOf(data.name).label || data.name));

    requestAnimationFrame(function () { Pop.show(row, true); });
    setTimeout(function () {
      Pop.show(row, false);
      setTimeout(function () { if (row.parentNode) row.parentNode.removeChild(row); }, 200);
    }, NOTIFY_TIME);
  }

  /* ---------------- Locales ---------------- */

  function applyLocale() {
    amountInput.placeholder = Pop.t('ui_amount_hint');
    renderHead(panels.player);
    renderHead(panels.secondary);
    if (views.secondary && views.secondary.type === 'shop') renderPanel(panels.secondary); // prix traduits
  }

  // Le kit appelle Pop.setLocale (pop:ready, pop:locale) : on complète pour le placeholder et les textes calculés.
  var baseSetLocale = Pop.setLocale;
  Pop.setLocale = function (table) {
    baseSetLocale.call(Pop, table);
    applyLocale();
  };
  applyLocale();

  /* ---------------- Messages Lua ---------------- */

  Pop.on('pop_inventory:items', function (d) {
    defs = (d.items && typeof d.items === 'object' && !Array.isArray(d.items)) ? d.items : {};
    if (isOpen) {
      renderPanel(panels.player);
      renderPanel(panels.secondary);
    }
  });

  Pop.on('pop_inventory:open', open);
  Pop.on('pop_inventory:close', close);
  Pop.on('pop_inventory:update', applyUpdate);
  Pop.on('pop_inventory:hotbar', showHotbar);
  Pop.on('pop_inventory:itemNotify', itemNotify);
})();
