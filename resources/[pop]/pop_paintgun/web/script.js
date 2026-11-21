/* pop_paintgun : sélecteur de couleur. Vanilla JS, aucun texte en dur, DOM sans innerHTML. */
(function () {
  'use strict';

  var TARGETS = ['primary', 'secondary', 'both'];
  var HEX = /^#[0-9a-f]{3,8}$/i;

  var panel = document.getElementById('paint');
  var grid = document.getElementById('paint-grid');
  var applyBtn = document.getElementById('paint-apply');
  var cancelBtn = document.getElementById('paint-cancel');
  var targetBtns = panel.querySelectorAll('[data-target]');

  var state = { open: false, target: 'both', color: null, current: {} };

  function isInt(v) {
    return typeof v === 'number' && Math.floor(v) === v;
  }

  function refresh() {
    targetBtns.forEach(function (btn) {
      btn.classList.toggle('is-active', btn.getAttribute('data-target') === state.target);
    });

    var cur = state.current;
    Array.prototype.forEach.call(grid.children, function (sw) {
      var id = Number(sw.getAttribute('data-id'));
      var isCurrent = state.target === 'both'
        ? (id === cur.primary || id === cur.secondary)
        : id === cur[state.target];
      sw.classList.toggle('is-current', isCurrent);
      sw.classList.toggle('is-selected', id === state.color);
    });

    applyBtn.disabled = state.color === null;
  }

  function build(colors) {
    while (grid.firstChild) grid.removeChild(grid.firstChild);
    (Array.isArray(colors) ? colors : []).forEach(function (c) {
      if (!c || !isInt(c.id) || typeof c.hex !== 'string' || !HEX.test(c.hex)) return;
      var sw = document.createElement('button');
      sw.type = 'button';
      sw.className = 'paint-swatch';
      sw.style.background = c.hex;
      sw.setAttribute('data-id', String(c.id));
      grid.appendChild(sw);
    });
  }

  function hide() {
    state.open = false;
    Pop.show(panel, false);
  }

  Pop.on('pop_paintgun:open', function (d) {
    var cur = d.current || {};
    state.current = {
      primary: isInt(cur.primary) ? cur.primary : null,
      secondary: isInt(cur.secondary) ? cur.secondary : null
    };
    state.target = 'both';
    state.color = null;
    build(d.colors);
    Pop.translate(panel);
    refresh();
    state.open = true;
    Pop.show(panel, true);
  });

  Pop.on('pop_paintgun:close', hide);

  targetBtns.forEach(function (btn) {
    btn.addEventListener('click', function () {
      var t = btn.getAttribute('data-target');
      if (TARGETS.indexOf(t) === -1) return;
      state.target = t;
      refresh();
    });
  });

  grid.addEventListener('click', function (e) {
    var sw = e.target.closest('.paint-swatch');
    if (!sw || !grid.contains(sw)) return;
    state.color = Number(sw.getAttribute('data-id'));
    refresh();
  });

  applyBtn.addEventListener('click', function () {
    if (!state.open || state.color === null) return;
    Pop.post('pop_paintgun:apply', { color: state.color, target: state.target });
    hide();
  });

  cancelBtn.addEventListener('click', function () {
    if (!state.open) return;
    Pop.post('close');
    hide();
  });

  // Le kit envoie déjà 'close' sur Échap : on masque seulement le panneau.
  window.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && state.open) hide();
  });
})();
