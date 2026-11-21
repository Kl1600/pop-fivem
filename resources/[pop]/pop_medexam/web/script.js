/* pop_medexam : mini-jeu, consentement et carte du certificat. */
(function () {
  'use strict';

  var CYCLE = 1400;   // aller-retour complet du curseur (ms)
  var TIMEOUT = 4000; // échec sans appui (ms)
  var RESULT = 300;   // affichage du résultat (ms)
  var BAR = 240;      // largeur de la barre (px)

  function $(id) { return document.getElementById(id); }

  /* ---------------- Mini-jeu ---------------- */

  var skill = $('med-skill');
  var zoneEl = $('med-skill-zone');
  var cursorEl = $('med-skill-cursor');
  var game = null; // { key, start, from, to, done, frame, timer }

  function position(now) {
    var p = ((now - game.start) % CYCLE) / (CYCLE / 2);
    return p > 1 ? 2 - p : p;
  }

  function tick(now) {
    if (!game || game.done) return;
    cursorEl.style.transform = 'translateX(' + (position(now) * (BAR - 2)) + 'px)';
    game.frame = requestAnimationFrame(tick);
  }

  function finish(success) {
    if (!game || game.done) return;
    var current = game;
    current.done = true;
    cancelAnimationFrame(current.frame);
    clearTimeout(current.timer);
    zoneEl.classList.add(success ? 'is-success' : 'is-fail');
    setTimeout(function () {
      if (game === current) Pop.post('pop_medexam:skillResult', { success: success });
    }, RESULT);
  }

  function stopSkill() {
    if (game) {
      cancelAnimationFrame(game.frame);
      clearTimeout(game.timer);
    }
    game = null;
    Pop.show(skill, false);
  }

  function startSkill(data) {
    stopSkill();
    var zone = Math.min(Math.max(Number(data.zone) || 0.15, 0.02), 0.6);
    var min = 0.35;
    var max = Math.max(min, 0.95 - zone);
    var from = min + Math.random() * (max - min);

    $('med-skill-label').textContent = Pop.t(String(data.label || ''));
    $('med-skill-key').textContent = String(data.key || 'E');
    zoneEl.className = 'med-zone';
    zoneEl.style.left = (from * 100) + '%';
    zoneEl.style.width = (zone * 100) + '%';
    cursorEl.style.transform = 'translateX(0px)';

    game = {
      key: String(data.key || 'E').toUpperCase(),
      start: performance.now(),
      from: from,
      to: from + zone,
      done: false
    };
    game.timer = setTimeout(function () { finish(false); }, TIMEOUT);
    game.frame = requestAnimationFrame(tick);
    Pop.show(skill, true);
  }

  window.addEventListener('keydown', function (e) {
    if (!game || game.done || e.repeat) return;
    if (e.key === 'Escape') { stopSkill(); return; } // le kit prévient Lua (échec)
    if (typeof e.key !== 'string' || e.key.toUpperCase() !== game.key) return;
    var pos = position(performance.now());
    finish(pos >= game.from && pos <= game.to);
  });

  Pop.on('pop_medexam:skill', function (data) {
    if (data.show) startSkill(data); else stopSkill();
  });

  /* ---------------- Consentement ---------------- */

  var consent = $('med-consent');

  Pop.on('pop_medexam:consent', function (data) {
    if (!data.show) { Pop.show(consent, false); return; }
    $('med-consent-text').textContent = Pop.t('consent_text', String(data.doctor || ''), Pop.t('money', Number(data.price) || 0));
    $('med-accept-key').textContent = String(data.acceptKey || 'E');
    $('med-refuse-key').textContent = String(data.refuseKey || 'X');
    Pop.show(consent, true);
  });

  /* ---------------- Carte ---------------- */

  var card = $('med-card');

  Pop.on('pop_medexam:certificate', function (data) {
    if (!data.show) { Pop.show(card, false); return; }
    var hasExpiry = data.expires !== null && data.expires !== undefined && data.expires !== '';
    $('med-card-name').textContent = Pop.t('card_name', String(data.name || ''));
    $('med-card-issued').textContent = Pop.t('card_issued', String(data.issued || ''));
    $('med-card-expires').textContent = hasExpiry ? Pop.t('card_expires', String(data.expires)) : Pop.t('card_no_expiry');
    $('med-card-doctor').textContent = Pop.t('card_doctor', String(data.doctor || ''));
    var status = $('med-card-status');
    status.textContent = Pop.t(data.valid ? 'card_valid' : 'card_expired');
    status.classList.toggle('is-expired', !data.valid);
    Pop.show(card, true);
  });
})();
