(() => {
  'use strict';

  const panel = document.getElementById('surface');
  const status = document.getElementById('status');
  const form = document.getElementById('editor');
  const remove = document.getElementById('remove');
  const controls = [...form.querySelectorAll('button, input')];
  let revision = 0;
  let waiting = false;
  let deleting = false;
  let removeTimer;
  const url = document.getElementById('url');
  function load(data) { url.value = data.content || ''; }
  function content() { return url.value.trim(); }

  function setWaiting(value) {
    waiting = value;
    controls.forEach(control => { control.disabled = value; });
  }

  function cancelDelete() {
    clearTimeout(removeTimer);
    deleting = false;
    remove.textContent = Pop.t('remove');
  }

  function hide() {
    revision += 1;
    cancelDelete();
    setWaiting(false);
    Pop.show(panel, false);
  }

  async function submit(callback, payload) {
    if (waiting) return;
    const requestRevision = revision;
    cancelDelete();
    setWaiting(true);
    status.textContent = '';
    const response = await Pop.post(callback, payload);
    if (requestRevision !== revision) return;
    setWaiting(false);
    if (!response?.ok) status.textContent = response?.message || Pop.t('error');
  }

  Pop.on('open', data => {
    revision += 1;
    setWaiting(false);
    cancelDelete();
    status.textContent = '';
    document.getElementById('title').textContent = data.title;
    remove.classList.toggle('pop-hidden', !data.editing);
    load(data);
    Pop.show(panel, true);
  });
  Pop.on('hide', hide);

  form.addEventListener('submit', event => {
    event.preventDefault();
    submit('save', { content: content() });
  });
  document.getElementById('close').addEventListener('click', () => Pop.post('close'));
  remove.addEventListener('click', () => {
    if (deleting) {
      submit('remove');
    } else {
      deleting = true;
      remove.textContent = Pop.t('confirm');
      removeTimer = setTimeout(cancelDelete, 3000);
    }
  });
})();
