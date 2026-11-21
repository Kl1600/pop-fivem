(() => {
  'use strict';

  const byId = id => document.getElementById(id);

  byId('close').addEventListener('click', () => Pop.post('close'));
  Pop.on('pop_computer:open', data => {
    byId('user').textContent = data.name || '';
    byId('role').textContent = data.job || '';
    byId('role-row').classList.toggle('pop-hidden', !data.job);
    byId('time').textContent = data.time || '';
    Pop.show(byId('terminal'), true);
  });
  Pop.on('pop_computer:close', () => Pop.show(byId('terminal'), false));
})();
