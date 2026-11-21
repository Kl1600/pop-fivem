/* pop_weed : carte d'info de la plante et panneau de placement.
 * Aucun focus, aucun callback propre au script : affichage seul.
 * Tous les textes viennent des locales (data-locale / Pop.t).
 */
(function () {
  'use strict';

  function $(id) { return document.getElementById(id); }

  function pct(v) {
    var n = Math.round(Number(v));
    if (n !== n) n = 0;
    return Math.max(0, Math.min(100, n));
  }

  var info, place, lastInfo = null, lastPlace = null;

  function setBar(name, value, low) {
    var v = pct(value);
    var val = $('weed-' + name + '-val');
    var bar = $('weed-' + name + '-bar');
    val.textContent = v + '%';
    bar.style.transform = 'scaleX(' + (v / 100) + ')';
    val.classList.toggle('is-low', !!low);
    bar.classList.toggle('is-low', !!low);
  }

  function renderInfo(d) {
    var stage = $('weed-stage');
    var water = pct(d.water);
    if (d.ready) {
      stage.textContent = Pop.t('info_ready');
    } else {
      stage.textContent = Pop.t('info_stage', d.stage | 0, d.stages | 0);
    }
    stage.classList.toggle('is-ready', !!d.ready);

    setBar('growth', d.growth, false);
    setBar('water', water, water < 25);
    setBar('quality', d.quality, false);

    $('weed-fert').textContent = Pop.t(d.fertilized ? 'info_fertilized' : 'info_not_fertilized');
  }

  function renderPlace(d) {
    var reason = $('weed-reason');
    var invalid = !d.valid;
    $('weed-confirm-key').textContent = d.confirmKey || '';
    $('weed-cancel-key').textContent = d.cancelKey || '';
    reason.textContent = invalid && d.reason ? Pop.t(d.reason) : '';
    reason.classList.toggle('pop-hidden', !invalid);
    $('weed-confirm').classList.toggle('pop-hidden', invalid);
  }

  Pop.on('pop_weed:info', function (d) {
    if (d.show) {
      lastInfo = d;
      renderInfo(d);
    }
    Pop.show(info, d.show);
  });

  Pop.on('pop_weed:placement', function (d) {
    if (d.show) {
      lastPlace = d;
      renderPlace(d);
    }
    Pop.show(place, d.show);
  });

  // Langue reçue après coup (pop:ready ou pop:locale) : retraduire les textes dynamiques.
  var setLocale = Pop.setLocale;
  Pop.setLocale = function (table) {
    setLocale(table);
    if (lastInfo) renderInfo(lastInfo);
    if (lastPlace) renderPlace(lastPlace);
  };

  function init() {
    info = $('weed-info');
    place = $('weed-place');
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
