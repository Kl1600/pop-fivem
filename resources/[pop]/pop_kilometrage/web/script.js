/* pop_kilometrage : affichage du compteur (Lua -> JS uniquement, aucun focus). */
(function () {
  'use strict';

  var km = document.getElementById('km');
  var valueEl = document.getElementById('km-value');
  var unitEl = document.getElementById('km-unit');

  // 12345.6 -> "12 345.6" (espace fine insécable entre les milliers).
  function format(value) {
    var tenths = Math.round(Math.max(0, Number(value) || 0) * 10);
    var int = String(Math.floor(tenths / 10)).replace(/\B(?=(\d{3})+(?!\d))/g, '\u202F');
    return int + '.' + (tenths % 10);
  }

  Pop.on('pop_kilometrage:hud', function (d) {
    if (d.show) {
      valueEl.textContent = format(d.value);
      unitEl.textContent = Pop.t(d.unit === 'mi' ? 'unit_mi' : 'unit_km');
    }
    Pop.show(km, !!d.show);
  });
})();
