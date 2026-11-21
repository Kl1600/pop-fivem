(() => {
  'use strict';

  const resource = location.hostname.replace(/^cfx-nui-/, '');
  const key = new URLSearchParams(location.search).get('key');
  const maxBytes = 5 * 1024 * 1024;
  const rasterTypes = new Set(['image/png', 'image/jpeg', 'image/webp']);

  async function showImage(content, allowedHosts) {
    const url = new URL(content);
    if (url.protocol !== 'https:' || url.username || url.password || url.port
        || !Array.isArray(allowedHosts) || !allowedHosts.includes(url.hostname)) return;

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);
    try {
      const response = await fetch(url.href, {
        mode: 'cors',
        redirect: 'error',
        credentials: 'omit',
        referrerPolicy: 'no-referrer',
        signal: controller.signal,
      });
      const type = (response.headers.get('Content-Type') || '').split(';')[0].trim().toLowerCase();
      if (!response.ok || !rasterTypes.has(type) || !response.body
          || Number(response.headers.get('Content-Length')) > maxBytes) return;

      const reader = response.body.getReader();
      const chunks = [];
      let total = 0;
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        total += value.byteLength;
        if (total > maxBytes) return;
        chunks.push(value);
      }
      const localUrl = URL.createObjectURL(new Blob(chunks, { type }));
      const image = document.getElementById('art');
      function release() { URL.revokeObjectURL(localUrl); }
      image.addEventListener('load', release, { once: true });
      image.addEventListener('error', release, { once: true });
      image.src = localUrl;
    } finally {
      clearTimeout(timer);
      controller.abort();
    }
  }

  async function load() {
    if (!key) return;
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const response = await fetch('https://' + resource + '/surfaceReady', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ key })
      }).then(value => value.json()).catch(() => null);
      if (response && typeof response.content === 'string') {
        await showImage(response.content, response.allowedHosts).catch(() => {});
        return;
      }
      await new Promise(resolve => setTimeout(resolve, 200));
    }
  }

  load();
})();
