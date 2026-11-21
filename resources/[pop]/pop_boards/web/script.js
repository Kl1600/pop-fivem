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
  const canvas = document.getElementById('art');
  const color = document.getElementById('color');
  const width = document.getElementById('brush');
  let strokes = [];
  let limits = { strokes: 0, points: 0 };
  let pointCount = 0;
  let pointer = null;

  function load(data) {
    strokes = Array.isArray(data.content) ? data.content : [];
    limits = { strokes: data.maxStrokes, points: data.maxPoints };
    pointCount = strokes.reduce((acc, stroke) => acc + stroke.points.length / 2, 0);
    pointer = null;
    drawArtwork(canvas, strokes);
  }

  function content() { return strokes; }

  function coordinates(event) {
    const bounds = canvas.getBoundingClientRect();
    const clamp = value => Math.max(0, Math.min(511, Math.floor(value)));
    return [clamp((event.clientX - bounds.left) * 512 / bounds.width),
      clamp((event.clientY - bounds.top) * 512 / bounds.height)];
  }

  canvas.addEventListener('pointerdown', event => {
    if (waiting || pointer !== null || event.button !== 0) return;
    if (strokes.length >= limits.strokes || pointCount >= limits.points) {
      status.textContent = Pop.t('limit');
      return;
    }
    pointer = event.pointerId;
    canvas.setPointerCapture(pointer);
    strokes.push({ color: color.value, width: Number(width.value), points: coordinates(event) });
    pointCount += 1;
    drawArtwork(canvas, strokes);
  });

  canvas.addEventListener('pointermove', event => {
    if (waiting || pointer !== event.pointerId || pointCount >= limits.points) return;
    const points = strokes[strokes.length - 1].points;
    const [x, y] = coordinates(event);
    if (x === points[points.length - 2] && y === points[points.length - 1]) return;
    points.push(x, y);
    pointCount += 1;
    drawArtwork(canvas, strokes);
  });

  function stopStroke(event) {
    if (event.pointerId === pointer) pointer = null;
  }

  canvas.addEventListener('pointerup', stopStroke);
  canvas.addEventListener('pointercancel', stopStroke);
  canvas.addEventListener('lostpointercapture', stopStroke);

  document.getElementById('erase').addEventListener('click', () => {
    strokes = [];
    pointCount = 0;
    pointer = null;
    status.textContent = '';
    drawArtwork(canvas, strokes);
  });

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
