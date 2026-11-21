/* pop_enterprisegarage : liste des véhicules de service. textContent uniquement. */
(function () {
  'use strict';

  var panel = document.getElementById('garage');
  var list = document.getElementById('garage-list');
  var count = document.getElementById('garage-count');
  var closeBtn = document.getElementById('garage-close');

  function hide() { Pop.show(panel, false); }

  function render(data) {
    var out = Number(data.out) || 0;
    var max = Number(data.max) || 0;
    var full = out >= max;
    list.textContent = '';

    (Array.isArray(data.vehicles) ? data.vehicles : []).forEach(function (v) {
      var row = document.createElement('div');
      row.className = 'garage-row';

      var name = document.createElement('span');
      name.className = 'garage-name';
      name.textContent = String(v.name || '');
      row.appendChild(name);

      var btn = document.createElement('button');
      btn.className = 'pop-button pop-small';
      btn.textContent = Pop.t('take_out');
      btn.disabled = full;
      btn.addEventListener('click', function () {
        if (btn.disabled) return;
        list.querySelectorAll('button').forEach(function (b) { b.disabled = true; });
        hide();
        Pop.post('pop_enterprisegarage:takeOut', { index: v.index });
      });
      row.appendChild(btn);

      list.appendChild(row);
    });

    count.textContent = Pop.t('out_count', out, max);
  }

  Pop.on('pop_enterprisegarage:open', function (data) {
    Pop.translate(panel);
    render(data);
    Pop.show(panel, true);
  });

  Pop.on('pop_enterprisegarage:close', hide);

  closeBtn.addEventListener('click', function () {
    hide();
    Pop.post('close');
  });

  // Le kit envoie déjà 'close' au Lua sur Échap : on masque seulement.
  window.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') hide();
  });
})();
