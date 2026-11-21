/* Roue des armes façon GTA (TAB maintenu) : armes équipées + objets utilisables.
   Messages : wheelOpen { entries:[{ kind, slot|containerId, label, icon, qty, empty }] },
              wheelUpdate { entries }, wheelClose.
   Réponse  : POST wheelPick { entry } (null si rien de choisi). */
(function () {
  const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pop_inventory';
  const PER_PAGE = 8;
  const FIST_SVG = `<svg class="fist" viewBox="0 0 64 64" width="52" height="52" aria-hidden="true">
    <g fill="currentColor" stroke="var(--fist-line)" stroke-width="1.6" stroke-linejoin="round">
      <path d="M13 33 C13 29 15 27 18 27 L48 27 C51 27 53 29 53 33 L52 44 C51 51 46 56 39 57 L26 57 C19 56 14 51 13 44 Z"/>
      <rect x="14" y="14" width="10" height="17" rx="5"/>
      <rect x="23.5" y="11" width="10" height="20" rx="5"/>
      <rect x="33" y="12" width="10" height="19" rx="5"/>
      <rect x="42.5" y="16" width="9" height="15" rx="4.5"/>
      <path d="M11 37 C11 33 14 31 18 31 L33 31 C37 31 39 33 39 36 C39 39 37 41 33 41 L19 41 C14 41 11 40 11 37 Z"/>
    </g>
  </svg>`;

  const R_OUT = 250, R_IN = 105, GAP = 1.6; // rayons (px) et écart entre parts (degrés)

  const css = `
    #pop-wheel { position: fixed; inset: 0; display: none; z-index: 99999; user-select: none;
      font-family: 'Segoe UI', Arial, sans-serif; color: #fff; }
    #pop-wheel.show { display: block; }
    #pop-wheel svg { position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); overflow: visible; }
    #pop-wheel .wedge { fill: rgba(0, 0, 0, 0.55); stroke: rgba(255, 255, 255, 0.10); stroke-width: 1; transition: fill 80ms ease; }
    #pop-wheel .wedge.empty { fill: rgba(0, 0, 0, 0.30); }
    #pop-wheel .wedge.sel { fill: rgba(255, 255, 255, 0.85); }
    #pop-wheel .ring { fill: none; stroke: rgba(255, 255, 255, 0.25); stroke-width: 2; }
    #pop-wheel .hub { fill: rgba(0, 0, 0, 0.6); stroke: rgba(255, 255, 255, 0.15); stroke-width: 1; }
    #pop-wheel .icon { position: absolute; width: 74px; height: 58px; margin: -29px 0 0 -37px; display: flex;
      align-items: center; justify-content: center; pointer-events: none; transition: transform 80ms ease; }
    #pop-wheel .icon img { max-width: 70px; max-height: 54px; object-fit: contain; filter: drop-shadow(0 2px 3px rgba(0,0,0,.6)); }
    #pop-wheel .icon.empty img, #pop-wheel .icon.empty .ph { opacity: 0.25; }
    #pop-wheel .icon.sel { transform: scale(1.12); }
    #pop-wheel .icon.sel .ph { color: #111; }
    #pop-wheel .icon .ph { font-size: 30px; opacity: 0.8; }
    #pop-wheel .icon .fist { color: #fff; --fist-line: rgba(0,0,0,0.45); filter: drop-shadow(0 2px 3px rgba(0,0,0,.6)); }
    #pop-wheel .icon.sel .fist { color: #151515; --fist-line: rgba(255,255,255,0.55); filter: none; }
    #pop-wheel .qty { position: absolute; right: 2px; bottom: -4px; font-size: 12px; font-weight: 700; text-shadow: 0 1px 3px #000; }
    #pop-wheel .icon.sel .qty { color: #111; text-shadow: none; }
    #pop-wheel .center { position: absolute; left: 50%; top: 50%; width: 190px; margin-left: -95px; transform: translateY(-50%);
      text-align: center; pointer-events: none; }
    #pop-wheel .center .t { font-family: 'Segoe UI Black', 'Segoe UI', Arial, sans-serif; font-weight: 900; font-size: 18px;
      line-height: 1.15; text-transform: uppercase; text-shadow: 0 1px 4px rgba(0,0,0,.7); }
    #pop-wheel .center .s { margin-top: 4px; font-size: 12px; color: rgba(255,255,255,0.75); }
    #pop-wheel .center .p { margin-top: 8px; font-size: 11px; color: rgba(255,255,255,0.55); }
  `;
  const style = document.createElement('style');
  style.textContent = css;
  document.head.appendChild(style);

  const root = document.createElement('div');
  root.id = 'pop-wheel';
  document.documentElement.appendChild(root); // hors du <body> (caché quand l'inventaire est fermé)

  let entries = [];
  let page = 0;
  let selected = -1;
  let open = false;

  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const pages = () => Math.max(1, Math.ceil(entries.length / PER_PAGE));
  const pageEntries = () => entries.slice(page * PER_PAGE, page * PER_PAGE + PER_PAGE);

  function arcPath(a0, a1) {
    const rad = (d) => (d - 90) * Math.PI / 180;
    const p = (r, d) => [r * Math.cos(rad(d)), r * Math.sin(rad(d))];
    const [x0, y0] = p(R_OUT, a0), [x1, y1] = p(R_OUT, a1), [x2, y2] = p(R_IN, a1), [x3, y3] = p(R_IN, a0);
    const large = a1 - a0 > 180 ? 1 : 0;
    return `M${x0},${y0} A${R_OUT},${R_OUT} 0 ${large} 1 ${x1},${y1} L${x2},${y2} A${R_IN},${R_IN} 0 ${large} 0 ${x3},${y3} Z`;
  }

  function render() {
    const list = pageEntries();
    const n = PER_PAGE;
    const size = R_OUT * 2 + 20;
    let svg = `<svg width="${size}" height="${size}" viewBox="${-size / 2} ${-size / 2} ${size} ${size}">`;
    svg += `<circle class="ring" r="${R_OUT + 6}"/>`;
    for (let i = 0; i < n; i++) {
      const a0 = (360 / n) * i - 180 / n + GAP / 2;
      const a1 = (360 / n) * (i + 1) - 180 / n - GAP / 2;
      const e = list[i];
      svg += `<path class="wedge${!e || e.empty ? ' empty' : ''}${i === selected ? ' sel' : ''}" d="${arcPath(a0, a1)}"/>`;
    }
    svg += `<circle class="hub" r="${R_IN - 8}"/></svg>`;
    let icons = '';
    const cx = window.innerWidth / 2, cy = window.innerHeight / 2, rm = (R_OUT + R_IN) / 2;
    for (let i = 0; i < n; i++) {
      const e = list[i];
      if (!e) continue;
      const ang = ((360 / n) * i - 90) * Math.PI / 180;
      const visual = e.icon ? `<img src="${esc(e.icon)}" onerror="this.style.display='none'">`
        : (e.kind === 'unarmed' ? FIST_SVG : `<div class="ph">•</div>`);
      const qty = e.qty && e.qty > 1 ? `<div class="qty">x${e.qty}</div>` : '';
      icons += `<div class="icon${e.empty ? ' empty' : ''}${i === selected ? ' sel' : ''}" style="left:${cx + Math.cos(ang) * rm}px;top:${cy + Math.sin(ang) * rm}px">${visual}${qty}</div>`;
    }
    const cur = selected >= 0 ? list[selected] : null;
    const title = cur ? cur.label : 'Roue';
    const sub = cur ? (cur.kind === 'item' ? 'Utiliser' + (cur.qty > 1 ? ` · x${cur.qty}` : '') : (cur.kind === 'unarmed' ? 'Ranger son arme' : 'Équiper')) : 'Visez avec la souris';
    const pg = pages() > 1 ? `<div class="p">Molette : page ${page + 1}/${pages()}</div>` : '';
    root.innerHTML = svg + icons + `<div class="center"><div class="t">${esc(title)}</div><div class="s">${esc(sub)}</div>${pg}</div>`;
  }

  function pick(i) {
    if (selected === i) return;
    selected = i;
    render();
  }

  root.addEventListener('mousemove', (ev) => {
    if (!open) return;
    const dx = ev.clientX - window.innerWidth / 2, dy = ev.clientY - window.innerHeight / 2;
    if (Math.hypot(dx, dy) < R_IN - 20) { pick(-1); return; }
    const n = PER_PAGE;
    let deg = Math.atan2(dy, dx) * 180 / Math.PI + 90;
    deg = (deg + 360 + 180 / n) % 360;
    const i = Math.floor(deg / (360 / n));
    const e = pageEntries()[i];
    pick(e && !e.empty ? i : -1);
  });

  root.addEventListener('wheel', (ev) => {
    if (!open || pages() < 2) return;
    page = (page + (ev.deltaY > 0 ? 1 : -1) + pages()) % pages();
    selected = -1;
    render();
  });

  root.addEventListener('mousedown', () => { if (open && selected >= 0) close(true); });

  function close(send) {
    if (!open) return;
    open = false;
    root.classList.remove('show');
    const e = selected >= 0 ? pageEntries()[selected] : null;
    fetch(`https://${RES}/wheelPick`, { method: 'POST', body: JSON.stringify({ entry: send ? e : null, viaClick: send === true }) }).catch(() => {});
  }

  window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    if (d.action === 'wheelOpen') {
      entries = Array.isArray(d.entries) ? d.entries : [];
      page = 0; selected = -1; open = true;
      root.classList.add('show');
      render();
    } else if (d.action === 'wheelUpdate' && open) {
      entries = Array.isArray(d.entries) ? d.entries : [];
      if (page >= pages()) page = 0;
      selected = -1;
      render();
    } else if (d.action === 'wheelClose') {
      close('release');
    }
  });
})();
