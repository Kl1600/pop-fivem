/* Roue des armes « maison » (TAB maintenu). Style de l'inventaire.
   Messages : wheelOpen { slots: [{ slot, label, icon, empty }] }, wheelClose.
   Réponse : POST wheelPick { slot } (slot = null si rien de choisi). */
(function () {
  const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pop_inventory';

  const css = `
    #pop-wheel { position: fixed; inset: 0; display: none; z-index: 99999; pointer-events: auto;
      background: radial-gradient(circle at 50% 50%, rgba(0,0,0,0.25) 0%, rgba(0,0,0,0.55) 70%);
      font-family: 'Segoe UI', Arial, sans-serif; color: #fff; user-select: none; }
    #pop-wheel.show { display: block; animation: popWheelIn 120ms ease-out; }
    @keyframes popWheelIn { from { opacity: 0; transform: scale(0.97); } to { opacity: 1; transform: scale(1); } }
    #pop-wheel .ring { position: absolute; left: 50%; top: 50%; width: 460px; height: 460px; margin: -230px 0 0 -230px;
      border-radius: 50%; border: 1px solid rgba(245,245,245,0.15); }
    #pop-wheel .center { position: absolute; left: 50%; top: 50%; width: 170px; height: 170px; margin: -85px 0 0 -85px;
      border-radius: 50%; background: rgba(245,245,245,0.10); border: 1px solid rgba(245,245,245,0.18);
      display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; padding: 14px; box-sizing: border-box; }
    #pop-wheel .center .t { font-family: 'Segoe UI Black', 'Segoe UI', Arial, sans-serif; font-weight: 900; font-size: 17px; line-height: 1.15; }
    #pop-wheel .center .s { margin-top: 6px; font-size: 11px; color: rgba(255,255,255,0.6); }
    #pop-wheel .seg { position: absolute; width: 112px; height: 92px; margin: -46px 0 0 -56px; box-sizing: border-box;
      background: rgba(245,245,245,0.15); border: 1px solid transparent; border-radius: 2px;
      display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px;
      transition: background 100ms ease, border-color 100ms ease, transform 100ms ease; }
    #pop-wheel .seg img { width: 54px; height: 44px; object-fit: contain; }
    #pop-wheel .seg .l { font-size: 11px; color: rgba(255,255,255,0.85); max-width: 100px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    #pop-wheel .seg .ph { font-size: 26px; opacity: 0.45; line-height: 44px; }
    #pop-wheel .seg.empty { opacity: 0.35; }
    #pop-wheel .seg.sel { background: rgba(255,255,255,0.32); border-color: rgba(255,255,255,0.8); transform: scale(1.06); }
  `;
  const style = document.createElement('style');
  style.textContent = css;
  document.head.appendChild(style);

  // Hors du <body> : le body de l'inventaire est caché quand il est fermé.
  const root = document.createElement('div');
  root.id = 'pop-wheel';
  root.innerHTML = '<div class="ring"></div><div class="center"><div class="t"></div><div class="s">Relâchez TAB pour équiper</div></div>';
  document.documentElement.appendChild(root);

  const centerTitle = root.querySelector('.center .t');
  const RADIUS = 175;
  let slots = [];
  let segEls = [];
  let selected = -1;
  let open = false;

  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  function render() {
    segEls.forEach((el) => el.remove());
    segEls = [];
    const n = slots.length;
    const cx = window.innerWidth / 2;
    const cy = window.innerHeight / 2;
    slots.forEach((s, i) => {
      const ang = (-90 + (360 / n) * i) * Math.PI / 180;
      const el = document.createElement('div');
      el.className = 'seg' + (s.empty ? ' empty' : '');
      el.style.left = (cx + Math.cos(ang) * RADIUS) + 'px';
      el.style.top = (cy + Math.sin(ang) * RADIUS) + 'px';
      const visual = s.icon ? `<img src="${esc(s.icon)}" onerror="this.style.display='none'">`
        : `<div class="ph">${s.slot === 'unarmed' ? '✋' : '—'}</div>`;
      el.innerHTML = visual + `<div class="l">${esc(s.empty ? s.label + ' (vide)' : s.label)}</div>`;
      root.appendChild(el);
      segEls.push(el);
    });
    select(-1);
  }

  function select(i) {
    selected = i;
    segEls.forEach((el, k) => el.classList.toggle('sel', k === i));
    centerTitle.textContent = i >= 0 ? slots[i].label : 'Armes';
  }

  root.addEventListener('mousemove', (e) => {
    if (!open || !slots.length) return;
    const dx = e.clientX - window.innerWidth / 2;
    const dy = e.clientY - window.innerHeight / 2;
    if (Math.hypot(dx, dy) < 60) { select(-1); return; }
    const n = slots.length;
    let deg = Math.atan2(dy, dx) * 180 / Math.PI + 90; // 0° = haut
    deg = (deg + 360 + 180 / n) % 360;
    const i = Math.floor(deg / (360 / n));
    select(slots[i] && !slots[i].empty ? i : -1);
  });

  // Clic = choisir tout de suite
  root.addEventListener('mousedown', () => { if (open && selected >= 0) close(true); });

  function close(send) {
    if (!open) return;
    open = false;
    root.classList.remove('show');
    const pick = selected >= 0 ? slots[selected].slot : null;
    fetch(`https://${RES}/wheelPick`, { method: 'POST', body: JSON.stringify({ slot: send ? pick : null, viaClick: send === true }) }).catch(() => {});
  }

  window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    if (d.action === 'wheelOpen') {
      slots = Array.isArray(d.slots) ? d.slots : [];
      open = true;
      root.classList.add('show');
      render();
    } else if (d.action === 'wheelClose') {
      close('release');
    }
  });
})();
