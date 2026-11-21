(() => {
  'use strict';

  window.addEventListener('message', ({ data }) => {
    if (data?.action !== 'pop_computer:screen') return;
    if (typeof data.accent === 'string' && /^#[0-9a-f]{3,8}$/i.test(data.accent)) {
      document.documentElement.style.setProperty('--pop-accent', data.accent);
    }
    document.documentElement.dir = data.rtl ? 'rtl' : 'ltr';
    document.getElementById('title').textContent = data.title || '';
    document.getElementById('status').textContent = data.status || '';
  });
})();
