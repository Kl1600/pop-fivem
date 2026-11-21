/* pop_bikerental : minuteur de location. Le Lua n'envoie qu'un message par changement d'affichage. */
(function () {
  'use strict';

  var WARN_BEFORE = 120;
  var panel = document.getElementById('rent');
  var time = document.getElementById('rent-time');
  var endAt = 0;
  var interval = null;

  function stop() {
    if (interval) clearInterval(interval);
    interval = null;
    Pop.show(panel, false);
  }

  function pad(n) { return (n < 10 ? '0' : '') + n; }

  function render() {
    var left = Math.max(0, Math.round((endAt - Date.now()) / 1000));
    time.textContent = pad(Math.floor(left / 60)) + ':' + pad(left % 60);
    time.classList.toggle('is-danger', left <= WARN_BEFORE);
    if (left <= 0) stop();
  }

  Pop.on('pop_bikerental:timer', function (data) {
    if (!data || !data.show) { stop(); return; }
    var seconds = Number(data.seconds) || 0;
    endAt = Date.now() + seconds * 1000;
    if (interval) clearInterval(interval);
    interval = setInterval(render, 1000);
    render();
    if (interval) Pop.show(panel, true);
  });
})();
