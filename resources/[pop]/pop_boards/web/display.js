(() => {
  'use strict';
  const resource = location.hostname.replace(/^cfx-nui-/, '');
  const key = new URLSearchParams(location.search).get('key');

  async function load() {
    if (!key) return;
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const response = await fetch('https://' + resource + '/surfaceReady', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ key })
      }).then(value => value.json()).catch(() => null);
      if (response && response.content !== undefined) {
        drawArtwork(document.getElementById('art'), response.content);
        return;
      }
      await new Promise(resolve => setTimeout(resolve, 200));
    }
  }

  load();
})();
