/* Code NUI propre au script. Exemple : afficher / masquer #app. */
(function () {
  'use strict';

  var app = document.getElementById('app');

  // Lua : SendNUIMessage({ action = 'open' }) + SetNuiFocus(true, true)
  Pop.on('open', function () { Pop.show(app, true); });
  Pop.on('close', function () { Pop.show(app, false); });

  // Le bouton et Échap demandent la fermeture au Lua (Bridge.OnUiClose).
  document.getElementById('close').addEventListener('click', function () {
    Pop.show(app, false);
    Pop.post('close');
  });
  window.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') Pop.show(app, false);
  });
})();
