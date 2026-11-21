/* pop_territories : HUD de territoire. Aucun focus souris, aucun callback NUI propre au script.
 * Message reçu : { action: 'territory:hud', show, zone, owner, color, mine, influence, capture }
 * owner, color et influence peuvent être absents (undefined) : traités comme null.
 */
(function () {
  'use strict';

  var COLOR_RE = /^#[0-9a-f]{6}$/i;

  var app = document.getElementById('app');
  var zoneEl = app.querySelector('.territory-zone');
  var dotEl = app.querySelector('.territory-dot');
  var ownerEl = app.querySelector('.territory-owner-name');
  var influenceEl = app.querySelector('.territory-influence');
  var pctEl = app.querySelector('.territory-pct');
  var fillEl = app.querySelector('.territory-fill');
  var markEl = app.querySelector('.territory-mark');

  function clampPct(value, fallback) {
    var n = Number(value);
    if (!isFinite(n)) return fallback;
    return Math.max(0, Math.min(100, Math.round(n)));
  }

  // Texte traduit : data-locale permet au kit de le remettre à jour si la langue arrive après.
  function setLocaleText(el, key) {
    el.setAttribute('data-locale', key);
    el.textContent = Pop.t(key);
  }

  function setRawText(el, text) {
    el.removeAttribute('data-locale');
    el.textContent = text;
  }

  function render(d) {
    zoneEl.textContent = typeof d.zone === 'string' ? d.zone : '';

    // Ligne propriétaire.
    var color = typeof d.color === 'string' && COLOR_RE.test(d.color) ? d.color : '';
    var hasOwner = typeof d.owner === 'string' && d.owner !== '';
    if (!hasOwner) {
      setLocaleText(ownerEl, 'hud_unclaimed');
      dotEl.classList.add('pop-hidden');
    } else {
      if (d.mine === true) {
        setLocaleText(ownerEl, 'hud_your_turf');
      } else {
        setRawText(ownerEl, d.owner); // donnée joueur : textContent uniquement
      }
      dotEl.style.backgroundColor = color;
      dotEl.classList.remove('pop-hidden');
    }

    // Influence du crew du joueur.
    if (d.influence === null || d.influence === undefined) {
      influenceEl.classList.add('pop-hidden');
    } else {
      var value = clampPct(d.influence, 0);
      pctEl.textContent = value + '%';
      fillEl.style.width = value + '%';
      markEl.style.insetInlineStart = clampPct(d.capture, 60) + '%';
      influenceEl.classList.remove('pop-hidden');
    }
  }

  Pop.on('territory:hud', function (d) {
    if (d.show) render(d);
    Pop.show(app, !!d.show);
  });
})();
