import { useCallback, useEffect, useState } from 'react';
import { Glass, useClock, useSettingsApi, type AppProps, type NuiResult } from '../../kit';
import {
  LABELS, MAP_H, MAP_W, PARKS, ROADS, START, byId, clampPan, estimateKm, iconOf, kmText, mapPoint, mapStyle, pick, routePoints, search, tripOf,
  type MapKind, type Mode, type PlacePin, type Travel,
} from './model';

const BTN = { all: 'unset', cursor: 'pointer' } as const;
const BLUE = '#0a84ff';
const STAR = 'M12 3l2.7 5.6 6.1.8-4.5 4.2 1.1 6.1L12 16.8 6.6 19.7l1.1-6.1L3.2 9.4l6.1-.8z';

function Ico({ d, size = 24, color = 'currentColor', sw = 2, fill = 'none' }: { d: string; size?: number; color?: string; sw?: number; fill?: string }) {
  return <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>;
}

interface StateRes extends NuiResult { places?: PlacePin[]; favs?: string[]; recents?: string[] }
interface PosRes extends NuiResult { mx?: number; my?: number; street?: string; zone?: string }
interface RouteRes extends NuiResult { meters?: number }

export default function App({ t, dark, nui }: AppProps) {
  const c = dark
    ? { fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)', fill: 'rgba(120,120,128,.36)', cell: 'rgba(60,60,64,.6)' }
    : { fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)', fill: 'rgba(120,120,128,.16)', cell: 'rgba(255,255,255,.7)' };
  const lang = useSettingsApi().lang;
  const { gameMs } = useClock();
  const [places, setPlaces] = useState<PlacePin[]>([]);
  const [favs, setFavs] = useState<string[]>([]);
  const [recents, setRecents] = useState<string[]>([]);
  const [mode, setMode] = useState<Mode>('home');
  const [sel, setSel] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  const [pan, setPan] = useState({ tx: 0, ty: 0 });
  const [d3, setD3] = useState(false);
  const [kind, setKind] = useState<MapKind>('std');
  const [menu, setMenu] = useState(false);
  const [travel, setTravel] = useState<Travel>('car');
  const [here, setHere] = useState<{ mx: number; my: number; street: string; zone: string }>({ ...START, street: '', zone: '' });
  const [meters, setMeters] = useState<number | null>(null);
  const [wp, setWp] = useState<{ mx: number; my: number } | null>(null);
  const [error, setError] = useState('');

  const locate = useCallback(async () => {
    const r = await nui.post<PosRes>('map', { action: 'position' });
    if (r?.ok && typeof r.mx === 'number' && typeof r.my === 'number') setHere({ mx: r.mx, my: r.my, street: r.street ?? '', zone: r.zone ?? '' });
  }, [nui]);

  useEffect(() => {
    let live = true;
    void (async () => {
      const r = await nui.call<StateRes>('plans:state');
      if (!live) return;
      if (r.ok) { setPlaces(r.places ?? []); setFavs(r.favs ?? []); setRecents(r.recents ?? []); } else setError(r.err ? t(r.err) : t('pla.err'));
      await locate();
    })();
    // Point posé sur la carte du menu pause : affiché comme repère.
    const onWp = (e: Event) => {
      const d = (e as CustomEvent<{ x?: number; y?: number }>).detail;
      setWp(d && typeof d.x === 'number' && typeof d.y === 'number' ? mapPoint(d.x, d.y) : null);
    };
    window.addEventListener('pop-waypoint', onWp);
    return () => { live = false; window.removeEventListener('pop-waypoint', onWp); };
  }, [nui, t, locate]);

  const nameOf = useCallback((p: PlacePin) => (p.id === 'home' && !p.name ? t('pla.home') : p.name), [t]);
  const shortOf = (p: PlacePin) => (p.id === 'home' && !p.short ? t('pla.home') : p.short || p.name);
  const catLabel = useCallback((cat: string) => t(`pla.cat_${cat}`), [t]);
  const hoursText = (h: string) => (h === 'always' ? t('pla.h_always') : h === 'h24' ? t('pla.h_24') : t('pla.h_closes', h));
  const pl = sel ? byId(places, sel) : undefined;
  const q = query.trim();
  const found = search(places, query, catLabel, nameOf);
  const rows = q ? found : pick(places, recents);
  const g = new Date(gameMs());
  const km = pl ? (meters !== null && mode === 'nav' ? meters / 1000 : estimateKm(here, pl)) : 0;
  const trip = tripOf(km, travel, g.getUTCHours(), g.getUTCMinutes());
  const map = mapStyle(kind, dark);

  const choose = (p: PlacePin) => {
    const tt = clampPan(1200 - p.mx, 749 - p.my);
    setSel(p.id); setMode('place'); setPan(tt); setQuery(''); setMeters(null);
    setRecents((r) => [p.id, ...r.filter((x) => x !== p.id)].slice(0, 5));
    void nui.call('plans:recent', p.id);
  };
  const toggleFav = async () => {
    if (!pl) return;
    const on = !favs.includes(pl.id);
    const r = await nui.call<StateRes>('plans:fav', { id: pl.id, on });
    if (r.ok) setFavs(r.favs ?? []); else setError(r.err ? t(r.err) : t('pla.err'));
  };
  const start = async () => {
    if (!pl) return;
    const r = await nui.post<RouteRes>('map', { action: 'route', x: pl.x, y: pl.y, z: pl.z });
    if (!r?.ok) { setError(t('pla.err_route')); return; }
    setMeters(typeof r.meters === 'number' ? r.meters : null);
    setMode('nav');
  };
  const stop = async () => {
    await nui.post('map', { action: 'clear' });
    setMode('home'); setSel(null); setPan({ tx: 0, ty: 0 }); setMeters(null);
  };
  const home = () => { setMode('home'); setSel(null); setPan({ tx: 0, ty: 0 }); };

  const tf = d3 ? `perspective(1800px) rotateX(40deg) scale(1.35) translate(${pan.tx}px,${pan.ty}px)` : `translate(${pan.tx}px,${pan.ty}px)`;
  const routeOn = !!pl && (mode === 'route' || mode === 'nav');
  const nearM = pl ? Math.round((Math.abs(pl.my - here.my) * 4.2) / 10) * 10 : 0;
  const back = (label: string, onClick: () => void) => (
    <button onClick={onClick} aria-label={t('pla.back')} style={{ ...BTN, alignSelf: 'flex-start', display: 'flex', alignItems: 'center', gap: 4, fontSize: 17, color: '#0088ff', fontWeight: 600 }}>
      <Ico d="M15 5l-7 7 7 7" size={18} sw={2.6} />{label}
    </button>
  );
  const round = { ...BTN, width: 52, height: 52, borderRadius: 26, display: 'flex', alignItems: 'center', justifyContent: 'center', color: c.fg } as const;

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', overflow: 'hidden', background: map.land, color: c.fg, letterSpacing: '-0.01em' }}>
      <style>{'@keyframes pla-pulse{0%{r:10;opacity:.55}100%{r:34;opacity:0}}'}</style>
      <div data-testid="map" style={{ position: 'absolute', left: '50%', top: '50%', marginLeft: -MAP_W / 2, marginTop: -MAP_H / 2, width: MAP_W, height: MAP_H, transform: tf, transformOrigin: '50% 50%', transition: 'transform .8s cubic-bezier(.3,.7,.2,1)' }}>
        <svg aria-label={t('pla.map')} role="img" width={MAP_W} height={MAP_H} viewBox={`0 0 ${MAP_W} ${MAP_H}`}>
          <defs><pattern id="pla-rues" width="130" height="110" patternUnits="userSpaceOnUse" patternTransform="rotate(-9)"><path d="M0 0H130M0 0V110" stroke={map.minor} strokeWidth="6" fill="none" /></pattern></defs>
          <rect x="0" y="0" width={MAP_W} height={MAP_H} fill={map.land} />
          <rect x="0" y="0" width={MAP_W} height={MAP_H} fill="url(#pla-rues)" />
          {PARKS.map((p, i) => <rect key={i} x={p.x} y={p.y} width={p.w} height={p.h} rx={p.r} fill={map.park} />)}
          {ROADS.map(([d, w], i) => <path key={`c${i}`} d={d} fill="none" stroke={map.roadCase} strokeWidth={w + 6} strokeLinecap="round" />)}
          {ROADS.map(([d, w], i) => <path key={`r${i}`} d={d} fill="none" stroke={map.road} strokeWidth={w} strokeLinecap="round" />)}
          <path d="M0 0H570C530 150 610 260 550 380C490 500 570 600 510 720C450 840 530 960 470 1080C430 1180 490 1330 440 1500H0Z" fill={map.sea} />
          <path d="M570 0C530 150 610 260 550 380C490 500 570 600 510 720C450 840 530 960 470 1080C430 1180 490 1330 440 1500" fill="none" stroke={map.beach} strokeWidth="7" />
          <path d="M545 748H655M545 772H655" stroke={map.roadCase} strokeWidth="8" fill="none" />
          <g style={{ opacity: map.transit, transition: 'opacity .4s' }} fill="none" strokeWidth="9" strokeLinecap="round" strokeLinejoin="round">
            <path d="M700 380L900 540L1120 700L1300 940L1480 1060" stroke="#CB30E0" /><path d="M800 1000L1000 860L1260 700L1500 600" stroke="#34C759" />
          </g>
          {LABELS.map(([txt, x, y, fs]) => <text key={txt} x={x} y={y} textAnchor="middle" fontSize={fs} fontWeight="700" letterSpacing="2" fill={map.label}>{txt}</text>)}
          {pl && <>
            <polyline points={routePoints(here, pl)} fill="none" stroke="#ffffff" strokeWidth="22" strokeLinecap="round" strokeLinejoin="round" pathLength="1" style={{ strokeDasharray: 1, strokeDashoffset: routeOn ? 0 : 1, transition: 'stroke-dashoffset .9s ease' }} />
            <polyline data-testid="route-line" points={routePoints(here, pl)} fill="none" stroke={BLUE} strokeWidth="14" strokeLinecap="round" strokeLinejoin="round" pathLength="1" style={{ strokeDasharray: 1, strokeDashoffset: routeOn ? 0 : 1, transition: 'stroke-dashoffset .9s ease' }} />
          </>}
          {places.map((p) => {
            const on = sel === p.id;
            const label = on || ['home', 'police', 'garage'].includes(p.id) ? shortOf(p) : '';
            return (
              <g key={p.id} data-pin={p.id} transform={`translate(${p.mx},${p.my})`} style={{ cursor: 'pointer' }} onClick={() => choose(p)}>
                <circle cx="0" cy="0" r={on ? 24 : 16} fill={p.col} stroke="#ffffff" strokeWidth="4" />
                <circle cx="0" cy="0" r="6" fill="#ffffff" />
                <text x="0" y={on ? 50 : 40} textAnchor="middle" fontSize="19" fontWeight="700" fill={map.pinText} stroke={map.halo} strokeWidth="5" paintOrder="stroke">{label}</text>
              </g>
            );
          })}
          {wp && <g transform={`translate(${wp.mx},${wp.my})`}><circle cx="0" cy="0" r="14" fill="#ff383c" stroke="#fff" strokeWidth="4" /><text x="0" y="-26" textAnchor="middle" fontSize="19" fontWeight="700" fill={map.pinText} stroke={map.halo} strokeWidth="5" paintOrder="stroke">{t('pla.waypoint')}</text></g>}
          <g transform={`translate(${here.mx},${here.my})`}>
            <circle cx="0" cy="0" r="10" fill={BLUE} opacity=".5" style={{ animation: 'pla-pulse 2s ease-out infinite' }} />
            <circle cx="0" cy="0" r="12" fill={BLUE} stroke="#fff" strokeWidth="4" />
          </g>
        </svg>
      </div>

      <Glass aria-label={t('pla.panel')} style={{ position: 'absolute', left: 20, top: 20, bottom: 20, width: 380, borderRadius: 32, boxSizing: 'border-box', padding: '20px 18px', display: 'flex', flexDirection: 'column', gap: 14, overflow: 'hidden' }}>
        {error && <span role="alert" style={{ fontSize: 14, color: '#ff383c' }}>{error}</span>}
        {mode === 'home' && <>
          <label style={{ height: 46, borderRadius: 23, background: c.fill, display: 'flex', alignItems: 'center', gap: 8, padding: '0 14px', color: c.sub, flexShrink: 0 }}>
            <Ico d="M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-4-4" size={18} sw={2.4} />
            <input aria-label={t('pla.search')} placeholder={t('pla.search_ph')} value={query} onChange={(e) => setQuery(e.target.value)} style={{ all: 'unset', flexGrow: 1, fontSize: 17, color: c.fg }} />
          </label>
          <div style={{ flexGrow: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 6 }}>
            {!q && <>
              <span style={{ fontSize: 20, fontWeight: 700, padding: '6px 4px 2px' }}>{t('pla.favs')}</span>
              <div style={{ display: 'flex', gap: 8, paddingBottom: 8 }}>
                {pick(places, favs).slice(0, 4).map((f) => (
                  <button key={f.id} data-fav={f.id} onClick={() => choose(f)} style={{ ...BTN, flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, padding: '6px 0' }}>
                    <span style={{ width: 58, height: 58, borderRadius: 29, background: f.col, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d={iconOf(f)} size={28} color="#fff" /></span>
                    <span style={{ fontSize: 14, fontWeight: 600, textAlign: 'center' }}>{shortOf(f)}</span>
                    <span style={{ fontSize: 12, color: c.sub }}>{f.area}</span>
                  </button>
                ))}
              </div>
              <span style={{ fontSize: 20, fontWeight: 700, padding: '6px 4px 2px' }}>{t('pla.recents')}</span>
            </>}
            {rows.map((r) => (
              <button key={r.id} data-row={r.id} onClick={() => choose(r)} style={{ ...BTN, display: 'flex', alignItems: 'center', gap: 12, padding: '10px 6px', borderBottom: `1px solid ${c.sep}` }}>
                <span style={{ width: 40, height: 40, flexShrink: 0, borderRadius: 20, background: r.col, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d={iconOf(r)} size={20} color="#fff" /></span>
                <span style={{ display: 'flex', flexDirection: 'column', minWidth: 0, textAlign: 'start' }}>
                  <span style={{ fontSize: 16, fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{nameOf(r)}</span>
                  <span style={{ fontSize: 14, color: c.sub }}>{r.addr}</span>
                </span>
              </button>
            ))}
            {!rows.length && q && <span style={{ display: 'block', textAlign: 'center', padding: '40px 10px', color: c.sub, fontSize: 16 }}>{t('pla.no_result')}</span>}
          </div>
        </>}

        {mode === 'place' && pl && <>
          {back(t('app.plans'), home)}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4, padding: '0 4px' }}>
            <span style={{ fontSize: 30, fontWeight: 800, lineHeight: 1.1 }}>{nameOf(pl)}</span>
            <span style={{ fontSize: 16, color: c.sub }}>{catLabel(pl.cat)} · {kmText(km, lang)}</span>
          </div>
          <div style={{ display: 'flex', gap: 10 }}>
            <button onClick={() => setMode('route')} style={{ ...BTN, flex: 1, height: 54, borderRadius: 27, background: BLUE, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, fontSize: 18, fontWeight: 700 }}>
              <Ico d="M4 12l16-8-8 16-2-6z" size={20} sw={2.4} />{t('pla.route_eta', t('pla.min', trip.min))}
            </button>
            <button onClick={() => void toggleFav()} aria-label={t('pla.fav')} aria-pressed={favs.includes(pl.id)} style={{ ...BTN, width: 54, height: 54, borderRadius: 27, background: c.fill, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#ff9f0a' }}>
              <Ico d={STAR} fill={favs.includes(pl.id) ? 'currentColor' : 'none'} />
            </button>
          </div>
          <div style={{ borderRadius: 18, background: c.cell, overflow: 'hidden' }}>
            {[[t('pla.addr'), `${pl.addr}, ${pl.area}`], [t('pla.hours'), hoursText(pl.hours)], [t('pla.phone'), pl.phone]].map(([k, v]) => (
              <div key={k} style={{ display: 'flex', flexDirection: 'column', gap: 2, padding: '12px 16px', borderBottom: `1px solid ${c.sep}` }}><span style={{ fontSize: 13, color: c.sub }}>{k}</span><span style={{ fontSize: 16 }}>{v}</span></div>
            ))}
          </div>
        </>}

        {mode === 'route' && pl && <>
          {back(nameOf(pl), () => setMode('place'))}
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}><span style={{ width: 10, height: 10, borderRadius: 5, background: BLUE }} /><span style={{ fontSize: 16 }}>{here.street ? `${t('pla.my_pos')} · ${here.street}` : t('pla.my_pos')}</span></div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}><span style={{ width: 10, height: 10, borderRadius: 5, background: '#ff383c' }} /><span style={{ fontSize: 16, fontWeight: 600 }}>{nameOf(pl)}</span></div>
          <div style={{ display: 'flex', gap: 6, background: c.fill, borderRadius: 22, padding: 4 }}>
            {([['car', 'M5 13l1.5-5h11L19 13M4 13h16v4H4zM7 17v2M17 17v2'], ['walk', 'M12 4a1.5 1.5 0 1 0 0 .01M10 21l2-6-2-3 2-4 3 3 3 1M10 12l-3 1']] as Array<[Travel, string]>).map(([id, d]) => (
              <button key={id} aria-pressed={travel === id} onClick={() => setTravel(id)} style={{ ...BTN, flex: 1, height: 38, borderRadius: 19, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, fontSize: 15, fontWeight: 600, background: travel === id ? BLUE : 'transparent', color: travel === id ? '#fff' : c.fg, transition: 'background .2s' }}>
                <Ico d={d} size={18} />{t(`pla.${id}`)}
              </button>
            ))}
          </div>
          <div style={{ borderRadius: 18, background: c.cell, padding: 18, display: 'flex', flexDirection: 'column', gap: 4 }}>
            <span style={{ fontSize: 44, fontWeight: 700, lineHeight: 1 }}>{t('pla.min', trip.min)}</span>
            <span style={{ fontSize: 16, color: c.sub }}>{kmText(km, lang)} · {t('pla.arrival', trip.arrival)}</span>
          </div>
          <button onClick={() => void start()} style={{ ...BTN, height: 54, borderRadius: 27, background: '#34c759', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18, fontWeight: 700 }}>{t('pla.start')}</button>
        </>}

        {mode === 'nav' && pl && <>
          <div style={{ borderRadius: 22, background: BLUE, color: '#fff', padding: 18, display: 'flex', flexDirection: 'column', gap: 6 }}>
            <span style={{ fontSize: 14, opacity: 0.85 }}>{t('pla.nav_to', nameOf(pl))}</span>
            <span style={{ fontSize: 24, fontWeight: 700, lineHeight: 1.2 }}>{t('pla.step1', here.street || t('pla.road'), nearM)}</span>
          </div>
          <div style={{ borderRadius: 18, background: c.cell, padding: '14px 18px', display: 'flex', flexDirection: 'column', gap: 4 }}>
            <span style={{ fontSize: 13, color: c.sub }}>{t('pla.then')}</span>
            <span style={{ fontSize: 17 }}>{t(pl.mx > here.mx ? 'pla.step2_e' : 'pla.step2_w', pl.area)}</span>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 6px' }}>
            <span style={{ fontSize: 28, fontWeight: 700 }}>{t('pla.min', trip.min)}</span>
            <span style={{ fontSize: 17, color: c.sub, alignSelf: 'flex-end' }}>{kmText(km, lang)} · {trip.arrival}</span>
          </div>
          <button onClick={() => void stop()} style={{ ...BTN, height: 54, borderRadius: 27, background: '#ff383c', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18, fontWeight: 700 }}>{t('pla.end')}</button>
        </>}
      </Glass>

      <div style={{ position: 'absolute', right: 22, top: 24, display: 'flex', flexDirection: 'column', gap: 12, alignItems: 'flex-end' }}>
        <Glass as="button" aria-label={t('pla.map_type')} onClick={() => setMenu(!menu)} style={round}><Ico d="M12 3l9 5-9 5-9-5zM3 13l9 5 9-5" /></Glass>
        {menu && (
          <Glass style={{ width: 200, borderRadius: 22, padding: 8, display: 'flex', flexDirection: 'column' }}>
            {(['std', 'sat', 'tr'] as MapKind[]).map((k) => (
              <button key={k} onClick={() => { setKind(k); setMenu(false); }} style={{ ...BTN, display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 12px', borderRadius: 14, fontSize: 16, fontWeight: 600, background: kind === k ? 'rgba(10,132,255,.16)' : 'transparent', color: kind === k ? BLUE : c.fg }}>
                {t(`pla.kind_${k}`)}<span style={{ opacity: kind === k ? 1 : 0 }}>✓</span>
              </button>
            ))}
          </Glass>
        )}
        <Glass as="button" aria-label={t('pla.view3d')} aria-pressed={d3} onClick={() => setD3(!d3)} style={{ ...round, fontSize: 17, fontWeight: 800, color: d3 ? BLUE : c.fg }}>3D</Glass>
        <Glass as="button" aria-label={t('pla.locate')} onClick={() => { const tt = clampPan(1200 - here.mx, 749 - here.my); setPan(tt); void locate(); }} style={{ ...round, color: BLUE }}><Ico d="M4 12l16-8-8 16-2-6z" /></Glass>
        <Glass as="button" aria-label={t('pla.game_map')} onClick={() => void nui.post('map', { action: 'pause' })} style={round}><Ico d="M9 4L3 6v14l6-2 6 2 6-2V4l-6 2zM9 4v14M15 6v14" /></Glass>
      </div>
    </div>
  );
}
