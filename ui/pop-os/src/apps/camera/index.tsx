import { useCallback, useEffect, useRef, useState, type PointerEvent } from 'react';
import { Glass, type AppProps, type NuiResult } from '../../kit';
import { cropImage } from './crop';
import { MODES, PANO_BAR, SQUARE_BAR, cropOf, nextTimer, visibleBox, type Crop, type ShotKind } from './model';

const YELLOW = '#ffd60a';
/** Bandeaux noirs autour du viseur (px) : haut sous la barre d'état, bas au-dessus de la barre d'accueil, colonne de droite pour les commandes. */
const BAR = { top: 88, bottom: 34, left: 24, right: 190 } as const;
interface Caps { ok: boolean; mode?: string; zoom?: boolean; selfie?: boolean }
interface LookMsg { on?: boolean }
interface CapRes extends NuiResult { id?: number; token?: string; img?: string; crop?: Crop }
interface GetRes extends NuiResult { photo?: { data: string } }

function Ico({ d, size = 22, fill = 'none' }: { d: string; size?: number; fill?: string }) {
  return <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>;
}

export default function App(p: AppProps) {
  const { t, nui } = p;
  const [caps, setCaps] = useState<Caps | null>(null);
  const [mode, setMode] = useState<ShotKind>('photo');
  const [zoom, setZoom] = useState(2);
  const [flash, setFlash] = useState(false);
  const [timer, setTimer] = useState(0);
  const [count, setCount] = useState(0);
  const [selfie, setSelfie] = useState(false);
  const [shooting, setShooting] = useState(false);
  const [white, setWhite] = useState(false);
  const [thumb, setThumb] = useState<string | null>(null);
  const [viewer, setViewer] = useState(false);
  const [msg, setMsg] = useState('');
  const [looking, setLooking] = useState(false);
  const timers = useRef<Array<ReturnType<typeof setTimeout>>>([]);
  const look = useRef({ dx: 0, dy: 0, raf: 0 });
  const vfRef = useRef<HTMLDivElement>(null);

  const later = (fn: () => void, ms: number) => { timers.current.push(setTimeout(fn, ms)); };

  // Démarrage et arrêt de la caméra : l'appli la possède tant qu'elle est ouverte.
  useEffect(() => {
    let live = true;
    void nui.post<Caps>('camera', { action: 'start' }).then((r) => {
      if (!live) return;
      setCaps(r ?? { ok: false });
      if (r?.ok) document.documentElement.dataset.cam = 'live';
    });
    const pending = timers.current;
    const lk = look.current;
    return () => {
      live = false;
      delete document.documentElement.dataset.cam;
      for (const x of pending) clearTimeout(x);
      cancelAnimationFrame(lk.raf);
      void nui.post('camera', { action: 'stop' });
    };
  }, [nui]);

  const take = useCallback(async () => {
    setShooting(true);
    await new Promise((r) => setTimeout(r, 80));
    // La photo = ce que montre le viseur : zone visible (hors bandeaux du format) en fractions de la fenêtre.
    const vf = vfRef.current;
    let crop: Crop | null = null;
    if (vf) {
      const b = vf.getBoundingClientRect();
      crop = cropOf(visibleBox(b, mode, vf.offsetWidth > 0 ? b.width / vf.offsetWidth : 1), { w: window.innerWidth, h: window.innerHeight });
    }
    const r = await nui.call<CapRes>('photos:capture', crop ? { kind: mode, crop } : { kind: mode });
    setWhite(true);
    later(() => setWhite(false), flash ? 400 : 90);
    setShooting(false);
    const fail = (e?: string) => setMsg(!e || e === 'err_unavailable' ? t('cam.err') : t(e));
    if (!r.ok) { fail(r.err); return; }
    if (r.token && r.img) {
      // Le serveur a rendu la capture entière : recadrage et ré-encodage ici, puis enregistrement par jeton.
      let out: string;
      try { out = await cropImage(r.img, r.crop ?? crop ?? { x: 0, y: 0, w: 1, h: 1 }); } catch { fail(); return; }
      const sv = await nui.call<CapRes>('photos:save', { token: r.token, img: out });
      if (!sv.ok) { fail(sv.err); return; }
      setMsg(t('cam.saved'));
      setThumb(out);
      return;
    }
    if (r.id === undefined) { fail(r.err); return; }
    setMsg(t('cam.saved'));
    const g = await nui.call<GetRes>('photos:get', r.id);
    if (g.ok && g.photo) setThumb(g.photo.data);
  }, [nui, mode, flash, t]);

  const shutter = () => {
    if (count > 0 || shooting) return;
    if (timer === 0) { void take(); return; }
    let n = timer;
    setCount(n);
    const tick = () => { n -= 1; if (n <= 0) { setCount(0); void take(); } else { setCount(n); later(tick, 1000); } };
    later(tick, 1000);
  };

  // Orientation libre : Alt l'active (le jeu rend la main à la souris), Alt la termine côté jeu puis prévient l'interface.
  const startLook = () => { void nui.post<NuiResult>('camera', { action: 'look_mode', on: true }).then((r) => { if (r?.ok) setLooking(true); }); };
  const keys = useRef({ shutter, startLook, looking, viewer, live: false });
  keys.current = { shutter, startLook, looking, viewer, live: caps?.ok === true };
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const k = keys.current;
      if (e.key === 'Alt') {
        e.preventDefault();
        if (!e.repeat && k.live && !k.looking && !k.viewer) k.startLook();
      } else if (e.key === 'Enter') {
        e.preventDefault();
        if (k.viewer) setViewer(false); else if (!e.repeat) k.shutter();
      }
    };
    const onLook = (e: Event) => { const d = (e as CustomEvent).detail as LookMsg | null; setLooking(d?.on === true); };
    window.addEventListener('keydown', onKey);
    window.addEventListener('pop-camera-look', onLook);
    return () => { window.removeEventListener('keydown', onKey); window.removeEventListener('pop-camera-look', onLook); };
  }, []);

  const flip = () => { const on = !selfie; setSelfie(on); void nui.post('camera', { action: 'selfie', on }); };
  const setZ = (lvl: number) => { setZoom(lvl); void nui.post('camera', { action: 'zoom', level: lvl }); };

  // Glissement sur le viseur : oriente la vue, un envoi par image au plus.
  const drag = (e: PointerEvent<HTMLDivElement>) => {
    if (!e.buttons) return;
    const lk = look.current;
    lk.dx += e.movementX * 0.15;
    lk.dy += e.movementY * 0.15;
    if (!lk.raf) lk.raf = requestAnimationFrame(() => { lk.raf = 0; const { dx, dy } = lk; lk.dx = 0; lk.dy = 0; void nui.post('camera', { action: 'look', dx, dy }); });
  };

  const idx = MODES.findIndex((m) => m.id === mode);
  const live = caps?.ok === true;
  const ui = { opacity: shooting ? 0 : 1, transition: 'opacity .1s' } as const;
  const zooms = [[1, '0,5×'], [2, '1×'], [3, '2×']] as Array<[number, string]>;
  const pill = { background: 'rgba(255,255,255,.14)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' } as const;

  // Disposition d'un appareil photo en paysage : bandeaux noirs opaques (haut, bas, gauche, droite), viseur transparent au centre.
  // Le viseur est un rectangle arrondi sans fond ; son ombre étalée peint en noir tout le reste de l'écran.
  return (
    <div data-app="camera" onPointerMove={drag} style={{ position: 'absolute', inset: 0, color: '#fff', overflow: 'hidden', fontFamily: 'inherit', background: live ? 'transparent' : 'linear-gradient(180deg,#2b1a5e,#b8326f 40%,#ff7a45 65%,#14101c)', touchAction: 'none' }}>
      <div data-viewfinder="1" ref={vfRef} style={{ position: 'absolute', left: BAR.left, right: BAR.right, top: BAR.top, bottom: BAR.bottom, borderRadius: 28, overflow: 'hidden', boxShadow: '0 0 0 2000px #000', background: 'transparent' }}>
        {mode === 'square' && <><div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: SQUARE_BAR, background: '#000' }} /><div style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: SQUARE_BAR, background: '#000' }} /></>}
        {mode === 'pano' && <><div style={{ position: 'absolute', left: 0, right: 0, top: 0, height: PANO_BAR, background: '#000' }} /><div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: PANO_BAR, background: '#000' }} /></>}
        {mode === 'portrait' && <><div style={{ position: 'absolute', left: '50%', top: '50%', margin: '-170px 0 0 -250px', width: 500, height: 340, border: `2px solid ${YELLOW}`, borderRadius: 16 }} /><Glass className="dk" style={{ position: 'absolute', top: 20, left: '50%', marginLeft: -70, padding: '6px 16px', borderRadius: 16, fontSize: 14, fontWeight: 600, ...ui }}>{t('cam.depth')}</Glass></>}
        <div style={{ position: 'absolute', left: '50%', top: '50%', margin: '-40px 0 0 -40px', width: 80, height: 80, border: '1.5px solid rgba(255,214,10,.9)', borderRadius: 6, opacity: shooting ? 1 : 0, transition: 'opacity .3s' }} />
        {count > 0 && <div aria-live="assertive" style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 160, fontWeight: 800, textShadow: '0 4px 30px rgba(0,0,0,.4)' }}>{count}</div>}
        {caps?.zoom && (
          <div style={{ position: 'absolute', left: '50%', bottom: 18, marginLeft: -75, display: 'flex', gap: 10, alignItems: 'center', ...ui }}>
            {zooms.map(([lvl, label]) => (
              <Glass as="button" className="dk" key={lvl} aria-label={`${t('cam.zoom')} ${label}`} aria-pressed={zoom === lvl} onClick={() => setZ(lvl)} style={{ width: zoom === lvl ? 54 : 42, height: zoom === lvl ? 54 : 42, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15, fontWeight: 700, color: zoom === lvl ? YELLOW : '#fff' }}>{zoom === lvl ? label : label.replace('×', '')}</Glass>
            ))}
          </div>
        )}
        {live && <span data-look-hint="1" style={{ position: 'absolute', left: 18, bottom: 22, padding: '6px 14px', borderRadius: 14, background: 'rgba(0,0,0,.5)', fontSize: 14, fontWeight: 600, color: looking ? YELLOW : '#fff', ...ui }}>{looking ? t('cam.look_end') : t('cam.look_start')}</span>}
        {msg && <span role="status" onClick={() => setMsg('')} style={{ position: 'absolute', top: 20, left: '50%', transform: 'translateX(-50%)', padding: '8px 18px', borderRadius: 18, background: 'rgba(0,0,0,.55)', fontSize: 15, ...ui }}>{msg}</span>}
        <div aria-hidden="true" style={{ position: 'absolute', inset: 0, background: '#fff', opacity: white ? 1 : 0, transition: `opacity ${white ? '0s' : '.4s'}`, pointerEvents: 'none' }} />
      </div>

      <div style={{ position: 'absolute', left: BAR.left, top: 44, display: 'flex', gap: 12, ...ui }}>
        <button type="button" aria-label={t('cam.flash')} onClick={() => setFlash(!flash)} style={{ ...pill, width: 40, height: 40, borderRadius: 20, color: flash ? YELLOW : '#fff' }}><Ico d="M13 2L4 14h7l-1 8 9-12h-7z" size={20} fill={flash ? YELLOW : 'none'} /></button>
        <button type="button" aria-label={t('cam.timer')} onClick={() => setTimer(nextTimer(timer))} style={{ ...pill, height: 40, minWidth: 40, padding: '0 12px', boxSizing: 'border-box', borderRadius: 20, gap: 6, fontWeight: 600, color: timer ? YELLOW : '#fff' }}>
          <Ico d="M12 5a8 8 0 1 0 0 16 8 8 0 0 0 0-16zM12 9v4l3 2M9 2h6" size={20} />{timer ? t('cam.sec', timer) : ''}
        </button>
      </div>

      <div data-camera-controls="1" style={{ position: 'absolute', right: 0, top: BAR.top, bottom: BAR.bottom, width: BAR.right, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 26, ...ui }}>
        <div role="listbox" aria-label={t('cam.mode')} style={{ height: 250, width: 120, overflow: 'hidden', position: 'relative' }}>
          <div style={{ position: 'absolute', left: 0, right: 0, top: 0, transform: `translateY(${100 - idx * 50}px)`, transition: 'transform .3s', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            {MODES.map((m) => (
              <button key={m.id} role="option" aria-selected={mode === m.id} onClick={() => setMode(m.id)} style={{ height: 50, display: 'flex', alignItems: 'center', fontSize: mode === m.id ? 19 : 16, fontWeight: 700, color: mode === m.id ? YELLOW : 'rgba(255,255,255,.75)' }}>{t(`cam.${m.id}`)}</button>
            ))}
          </div>
        </div>
        <button aria-label={t('cam.shutter')} onClick={shutter} style={{ width: 88, height: 88, borderRadius: '50%', border: '4px solid #fff', boxSizing: 'border-box', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><span style={{ width: 70, height: 70, borderRadius: '50%', background: '#fff' }} /></button>
        <button type="button" aria-label={t('cam.flip')} aria-pressed={selfie} onClick={flip} style={{ ...pill, width: 52, height: 52, borderRadius: 26 }}><Ico d="M20 8a8 8 0 0 0-14-2M4 4v3h3M4 16a8 8 0 0 0 14 2M20 20v-3h-3" size={24} /></button>
        <button aria-label={t('cam.last')} onClick={() => setViewer(true)} style={{ width: 64, height: 64, borderRadius: 12, border: '2px solid #fff', boxSizing: 'border-box', overflow: 'hidden', background: 'linear-gradient(160deg,#4a3a6a,#14101c)', transform: `scale(${white ? 0.8 : 1})`, transition: 'transform .25s' }}>
          {thumb && <img alt="" src={thumb} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}
        </button>
      </div>

      {viewer && (
        <div role="dialog" aria-label={t('cam.last')} onClick={() => setViewer(false)} style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,.85)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 16 }}>
          {thumb ? <img alt={t('cam.last')} src={thumb} style={{ maxWidth: 760, maxHeight: 570, borderRadius: 18 }} /> : <span style={{ fontSize: 18 }}>{t('cam.none')}</span>}
          <span style={{ fontSize: 16, color: 'rgba(255,255,255,.7)' }}>{t('cam.close_hint')}</span>
        </div>
      )}
    </div>
  );
}
