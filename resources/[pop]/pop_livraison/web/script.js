/* pop_livraison : HUD de tournée. Le Lua envoie l'état chaque seconde pendant une tournée. */
(function () {
  'use strict';

  var DANGER_BELOW = 60;
  var STEPS = { drive: true, take: true, deliver: true, 'return': true };
  var panel = document.getElementById('delivery');
  var title = document.getElementById('delivery-title');
  var time = document.getElementById('delivery-time');
  var step = document.getElementById('delivery-step');

  function pad(n) { return (n < 10 ? '0' : '') + n; }

  Pop.on('pop_livraison:hud', function (data) {
    if (!data || !data.show) { Pop.show(panel, false); return; }

    var s = STEPS[data.step] ? data.step : 'drive';
    var left = Math.max(0, Math.floor(Number(data.timeLeft) || 0));

    title.textContent = s === 'return'
      ? Pop.t('hud_title_done')
      : Pop.t('hud_title', Number(data.index) || 0, Number(data.total) || 0);
    time.textContent = pad(Math.floor(left / 60)) + ':' + pad(left % 60);
    time.classList.toggle('is-danger', left < DANGER_BELOW);
    step.textContent = Pop.t('hud_' + s);

    Pop.show(panel, true);
  });
})();
