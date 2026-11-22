/* Mini-jeu « stop au bon moment » : un curseur va et vient, [E] (lu par le jeu côté Lua) l'arrête.
 * Le résultat est renvoyé au Lua ; le serveur reste seul juge (finalizeHack vérifie tout). */
(function () {
  'use strict';

  var card = document.getElementById('hack');
  var track = document.getElementById('hack-track');
  var zoneEl = document.getElementById('hack-zone');
  var cursorEl = document.getElementById('hack-cursor');
  var roundsEl = document.getElementById('hack-rounds');
  var failsEl = document.getElementById('hack-fails');

  var game = null;

  function cfgNum(v, def) { v = Number(v); return isFinite(v) ? v : def; }

  function renderRounds() {
    roundsEl.innerHTML = '';
    for (var i = 1; i <= game.rounds; i++) {
      var box = document.createElement('div');
      box.className = 'hack-round' + (i < game.round ? ' done' : '') + (i === game.round ? ' current' : '');
      box.innerHTML = '<i class="fas fa-check"></i>';
      roundsEl.appendChild(box);
    }
  }

  function renderFails() {
    failsEl.textContent = Pop.t('hack_ui_fails', game.fails, game.maxFails);
    failsEl.classList.toggle('warn', game.fails > 0);
  }

  // Nouvelle zone (position au hasard), largeur et vitesse selon la manche
  function newZone() {
    var r = game.round - 1;
    game.width = Math.max(0.08, game.zoneStart - r * game.zoneShrink);
    game.speed = game.speedStart + r * game.speedStep;
    var margin = 0.05;
    game.center = margin + game.width / 2 + Math.random() * (1 - 2 * margin - game.width);
    zoneEl.style.left = ((game.center - game.width / 2) * 100) + '%';
    zoneEl.style.width = (game.width * 100) + '%';
    game.t0 = performance.now();
    game.phase = Math.random(); // le curseur ne part pas toujours du bord
  }

  function cursorPos(now) {
    // aller-retour : 'speed' allers simples par seconde
    var x = game.phase + ((now - game.t0) / 1000) * game.speed;
    var m = x % 2;
    return m <= 1 ? m : 2 - m;
  }

  function frame(now) {
    if (!game) return;
    if (!game.paused) {
      game.pos = cursorPos(now);
      cursorEl.style.left = (game.pos * 100) + '%';
    }
    requestAnimationFrame(frame);
  }

  function finish(result) {
    var g = game;
    if (!g) return;
    g.paused = true;
    setTimeout(function () {
      Pop.show(card, false);
      game = null;
      Pop.post('hackResult', { result: result });
    }, result === 'success' ? 450 : 600);
  }

  function stop() {
    if (!game || game.paused) return;
    var hit = Math.abs(game.pos - game.center) <= game.width / 2;
    game.paused = true;
    track.classList.add(hit ? 'hit' : 'miss');

    if (hit) {
      game.round += 1;
      renderRounds();
      if (game.round > game.rounds) return finish('success');
    } else {
      game.fails += 1;
      renderFails();
      if (game.fails >= game.maxFails) return finish('fail');
    }

    // Manche suivante (ou même manche après une erreur) après un court retour visuel
    setTimeout(function () {
      if (!game) return;
      track.classList.remove('hit', 'miss');
      newZone();
      game.paused = false;
    }, hit ? 350 : 550);
  }

  Pop.on('hack:open', function (d) {
    game = {
      rounds: Math.max(1, cfgNum(d.rounds, 3)),
      zoneStart: cfgNum(d.zoneStart, 0.22),
      zoneShrink: cfgNum(d.zoneShrink, 0.04),
      speedStart: cfgNum(d.speedStart, 1.0),
      speedStep: cfgNum(d.speedStep, 0.25),
      maxFails: Math.max(1, cfgNum(d.maxFails, 3)),
      round: 1, fails: 0, pos: 0, paused: false
    };
    if (d.title) card.querySelector('.hack-title').textContent = d.title;
    track.classList.remove('hit', 'miss');
    renderRounds();
    renderFails();
    newZone();
    Pop.show(card, true);
    requestAnimationFrame(frame);
  });

  Pop.on('hack:stop', stop);

  Pop.on('hack:close', function () {
    game = null;
    Pop.show(card, false);
  });
})();
