import { useEffect, useMemo, useState } from 'react';
import { useClock, useSettingsApi, useWeather, type AppProps } from '../../kit';
import {
  PLACES, SKY_GRAD_DARK, SKY_GRAD_LIGHT, SKY_ICON, SKY_ICON_COLOR, bars, forecast, hourly, placeNow, tempColor, toUnit, type Sky,
} from './model';

const BTN = { all: 'unset', cursor: 'pointer' } as const;
const SKIES: Sky[] = ['S', 'C', 'R', 'N'];
const CLOUDS: Record<Sky, { n: number; rgb: string; op: number }> = {
  S: { n: 2, rgb: '255,255,255', op: 0.32 }, C: { n: 6, rgb: '238,242,248', op: 0.5 }, R: { n: 6, rgb: '52,64,84', op: 0.6 }, N: { n: 5, rgb: '255,255,255', op: 0.45 },
};
const GAUGE = 'linear-gradient(90deg,#34c759,#ffd60a,#ff9500,#ff3b30)';
const KEYFRAMES = `@keyframes met-drift{from{transform:translateX(-520px)}to{transform:translateX(1500px)}}
@keyframes met-fall{from{background-position:0 0}to{background-position:-90px 480px}}
@keyframes met-snow{from{background-position:0 0}to{background-position:40px 300px}}
@keyframes met-glow{0%,100%{transform:scale(1);opacity:.9}50%{transform:scale(1.08);opacity:1}}`;

function Ico({ d, size = 24, color = 'currentColor', sw = 1.8 }: { d: string; size?: number; color?: string; sw?: number }) {
  return <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>;
}

export default function App({ t, dark, nui }: AppProps) {
  const c = dark
    ? { bg: '#000000', fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)', fill: '#3a3a3c', card: 'rgba(0,0,0,.28)', cardLine: 'rgba(255,255,255,.12)' }
    : { bg: '#f2f2f7', fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)', fill: '#e3e3e8', card: 'rgba(255,255,255,.2)', cardLine: 'rgba(255,255,255,.28)' };
  const lang = useSettingsApi().lang;
  const { gameMs } = useClock();
  const weather = useWeather();
  const [loc, setLoc] = useState('ls');
  const [query, setQuery] = useState('');
  const [fahrenheit, setFahrenheit] = useState(false);

  // Resynchronisation du jeu (météo et heure) tant que l'appli est ouverte, coupée en la quittant.
  useEffect(() => {
    void nui.post('resync', { active: true });
    return () => { void nui.post('resync', { active: false }); };
  }, [nui]);

  const ms = gameMs();
  const hour = new Date(ms).getUTCHours();
  const place = PLACES.find((p) => p.id === loc) ?? PLACES[0]!;
  const w = weather ?? { temp: 24, kind: 'clear' };
  const now = useMemo(() => placeNow(w, place, hour), [w.temp, w.kind, w.hi, w.lo, w.wind, w.deg, place, hour]); // eslint-disable-line react-hooks/exhaustive-deps
  const grads = dark ? SKY_GRAD_DARK : SKY_GRAD_LIGHT;
  const T = (v: number) => toUnit(v, fahrenheit);
  const q = query.trim().toLowerCase();
  const list = PLACES.filter((p) => !q || p.name.toLowerCase().includes(q));
  const clock = `${String(hour).padStart(2, '0')}:${String(new Date(ms).getUTCMinutes()).padStart(2, '0')}`;
  const hours = hourly(now, hour);
  const days = forecast(now, place);
  const dayBars = bars(days);
  const dayName = (i: number) => (i === 0 ? t('met.today') : new Intl.DateTimeFormat(lang, { weekday: 'short', timeZone: 'UTC' }).format(new Date(ms + i * 86_400_000)));
  const cl = CLOUDS[now.sky];
  const clouds = Array.from({ length: cl.n }, (_, i) => ({ top: 30 + ((i * 97) % 380), w: 320 + (i % 3) * 90, h: 90 + (i % 2) * 40, dur: 70 + i * 17, delay: -(i * 23) }));
  const uvLabel = now.uv >= 8 ? t('met.uv_vhigh') : now.uv >= 6 ? t('met.uv_high') : now.uv >= 3 ? t('met.uv_mid') : t('met.uv_low');
  const visLabel = now.vis >= 15 ? t('met.vis_great') : now.vis >= 8 ? t('met.vis_good') : t('met.vis_low');
  const summary = t(`met.sum_${now.sky}`, t(`met.dir_${now.dir}`));
  const card = { background: c.card, border: `1px solid ${c.cardLine}`, backdropFilter: 'blur(24px) saturate(160%)', WebkitBackdropFilter: 'blur(24px) saturate(160%)' } as const;

  const tiles: Array<{ k: string; d: string; value: string | number; unit: string; sub: string; bar?: number }> = [
    { k: 'uv', d: SKY_ICON.S, value: now.uv, unit: '', sub: uvLabel, bar: Math.min(100, now.uv * 9) },
    { k: 'wind', d: 'M3 8h10a3 3 0 1 0-3-3M3 12h15a3 3 0 1 1-3 3M3 16h7', value: now.wind, unit: 'km/h', sub: t('met.wind_dir', t(`met.dir_${now.dir}`), now.deg) },
    { k: 'hum', d: 'M12 3c4 5 6 8 6 11a6 6 0 0 1-12 0c0-3 2-6 6-11z', value: now.hum, unit: '%', sub: t('met.dew', T(now.dew)) },
    { k: 'vis', d: 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7zM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z', value: now.vis, unit: 'km', sub: visLabel },
    { k: 'pres', d: 'M12 4a8 8 0 1 0 0 16 8 8 0 0 0 0-16zM12 12l4-4', value: now.pres, unit: 'hPa', sub: now.pres < 1008 ? t('met.pres_down') : t('met.pres_stable') },
    { k: 'sun', d: 'M3 18h18M7 18a5 5 0 0 1 10 0M12 6v4M5 11l2 2M19 11l-2 2', value: place.rise, unit: '', sub: t('met.sunset', place.set) },
  ];

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', display: 'flex', overflow: 'hidden', background: c.bg, color: c.fg, letterSpacing: '-0.01em' }}>
      <style>{KEYFRAMES}</style>
      <nav aria-label={t('met.places')} style={{ width: 320, flexShrink: 0, height: '100%', boxSizing: 'border-box', background: c.bg, borderRight: `1px solid ${c.sep}`, padding: '46px 14px 20px', display: 'flex', flexDirection: 'column', gap: 12, zIndex: 3 }}>
        <span style={{ fontSize: 34, fontWeight: 700, padding: '0 8px' }}>{t('app.meteo')}</span>
        <label style={{ height: 40, borderRadius: 20, background: c.fill, display: 'flex', alignItems: 'center', gap: 8, padding: '0 12px', color: c.sub, margin: '0 4px' }}>
          <Ico d="M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-4-4" size={17} sw={2.4} />
          <input aria-label={t('met.search')} placeholder={t('met.search')} value={query} onChange={(e) => setQuery(e.target.value)} style={{ all: 'unset', flexGrow: 1, fontSize: 17, color: c.fg }} />
        </label>
        <div style={{ flexGrow: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 10, padding: '0 4px' }}>
          {list.map((p) => {
            const pn = placeNow(w, p, hour);
            return (
              <button key={p.id} data-place={p.id} onClick={() => setLoc(p.id)} style={{ ...BTN, height: 100, borderRadius: 22, boxSizing: 'border-box', padding: '12px 16px', background: grads[pn.sky], color: '#fff', display: 'flex', justifyContent: 'space-between', outline: `3px solid ${p.id === loc ? (dark ? '#ffffff' : '#0088ff') : 'transparent'}`, outlineOffset: 2, flexShrink: 0 }}>
                <span style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between', textAlign: 'start' }}>
                  <span><span style={{ display: 'block', fontSize: 20, fontWeight: 700 }}>{p.name}</span><span style={{ display: 'block', fontSize: 14, opacity: 0.85 }}>{clock}</span></span>
                  <span style={{ fontSize: 14 }}>{t(`met.sky_${pn.sky}`)}</span>
                </span>
                <span style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between', alignItems: 'flex-end' }}>
                  <span style={{ fontSize: 44, fontWeight: 300, lineHeight: 1 }}>{T(pn.temp)}°</span>
                  <span style={{ fontSize: 14 }}>{t('met.maxmin', T(pn.hi), T(pn.lo))}</span>
                </span>
              </button>
            );
          })}
          {!list.length && <span style={{ textAlign: 'center', padding: '40px 10px', color: c.sub, fontSize: 16 }}>{t('met.none')}</span>}
        </div>
      </nav>

      <main style={{ flexGrow: 1, minWidth: 0, height: '100%', position: 'relative', overflow: 'hidden', color: '#fff' }}>
        {SKIES.map((k) => <div key={k} style={{ position: 'absolute', inset: 0, background: grads[k], opacity: now.sky === k ? 1 : 0, transition: 'opacity .9s' }} />)}
        <div aria-hidden="true" style={{ position: 'absolute', inset: 0, overflow: 'hidden', pointerEvents: 'none' }}>
          {now.sky === 'S' && <div style={{ position: 'absolute', right: 90, top: 40, width: 260, height: 260, borderRadius: '50%', background: 'radial-gradient(circle, rgba(255,236,160,.95) 0%, rgba(255,214,90,.5) 35%, rgba(255,214,90,0) 70%)', animation: 'met-glow 6s ease-in-out infinite' }} />}
          {clouds.map((k, i) => <div key={i} style={{ position: 'absolute', left: 0, top: k.top, width: k.w, height: k.h, borderRadius: '50%', background: `rgba(${cl.rgb},${cl.op})`, filter: 'blur(22px)', animation: `met-drift ${k.dur}s linear ${k.delay}s infinite` }} />)}
          {now.sky === 'R' && <div style={{ position: 'absolute', inset: 0, backgroundImage: 'repeating-linear-gradient(105deg, rgba(255,255,255,.28) 0 2px, transparent 2px 30px)', backgroundSize: '90px 160px', animation: 'met-fall .7s linear infinite' }} />}
          {now.sky === 'N' && <div style={{ position: 'absolute', inset: 0, backgroundImage: 'radial-gradient(circle, rgba(255,255,255,.95) 2.5px, transparent 3px), radial-gradient(circle, rgba(255,255,255,.7) 1.8px, transparent 2.2px)', backgroundSize: '90px 90px, 57px 57px', backgroundPosition: '0 0, 30px 20px', animation: 'met-snow 7s linear infinite' }} />}
        </div>

        <div style={{ position: 'absolute', inset: 0, overflowY: 'auto', padding: '34px 30px 40px' }}>
          <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: -20, position: 'relative', zIndex: 2 }}>
            <button onClick={() => setFahrenheit(!fahrenheit)} aria-label={t('met.unit')} style={{ ...BTN, ...card, height: 40, padding: '0 18px', borderRadius: 20, display: 'flex', alignItems: 'center', fontSize: 16, fontWeight: 600, color: '#fff' }}>{fahrenheit ? '°F' : '°C'}</button>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 6, textShadow: '0 2px 14px rgba(0,0,0,.2)' }}>
            <span style={{ fontSize: 38, fontWeight: 600 }}>{loc === 'ls' && weather?.city ? weather.city : place.name}</span>
            <span data-testid="met-temp" style={{ fontSize: 190, fontWeight: 200, lineHeight: 1.02, letterSpacing: '-0.04em', paddingInlineStart: 28 }}>{T(now.temp)}°</span>
            <span style={{ fontSize: 26, fontWeight: 500 }}>{t(`met.sky_${now.sky}`)}</span>
            <span style={{ fontSize: 20, fontWeight: 500, paddingTop: 4 }}>{t('met.maxmin', T(now.hi), T(now.lo))}</span>
          </div>

          <div style={{ ...card, marginTop: 28, borderRadius: 24, padding: '14px 18px 16px' }}>
            <span style={{ display: 'block', fontSize: 14, fontWeight: 600, opacity: 0.8, paddingBottom: 10 }}>{summary}</span>
            <div style={{ display: 'flex', gap: 6, overflowX: 'auto', borderTop: '1px solid rgba(255,255,255,.25)', paddingTop: 12 }}>
              {hours.map((h, i) => {
                const k = h.moon ? 'M' : h.sky;
                return (
                  <div key={i} style={{ width: 76, flexShrink: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
                    <span style={{ fontSize: 15, fontWeight: 600 }}>{h.label === 'now' ? t('met.now') : t('met.hour', h.label)}</span>
                    <Ico d={SKY_ICON[k]} size={30} color={SKY_ICON_COLOR[k]} />
                    <span style={{ fontSize: 12, fontWeight: 700, color: '#8fd3ff', height: 14 }}>{h.pct === null ? '' : `${h.pct}%`}</span>
                    <span style={{ fontSize: 20, fontWeight: 600 }}>{T(h.temp)}°</span>
                  </div>
                );
              })}
            </div>
          </div>

          <div style={{ display: 'flex', gap: 20, marginTop: 20, alignItems: 'flex-start' }}>
            <div style={{ ...card, flex: 1.35, borderRadius: 24, padding: '14px 20px 8px' }}>
              <span style={{ display: 'block', fontSize: 14, fontWeight: 600, opacity: 0.8, paddingBottom: 6, borderBottom: '1px solid rgba(255,255,255,.25)' }}>{t('met.ten_days')}</span>
              {days.map((d, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', height: 52, borderBottom: '1px solid rgba(255,255,255,.15)' }}>
                  <span style={{ width: 120, fontSize: 18, fontWeight: 600 }}>{dayName(i)}</span>
                  <Ico d={SKY_ICON[d.sky]} size={26} color={SKY_ICON_COLOR[d.sky]} />
                  <span style={{ width: 44, textAlign: 'end', fontSize: 18, opacity: 0.7 }}>{T(d.lo)}°</span>
                  <span style={{ flexGrow: 1, height: 6, borderRadius: 3, background: 'rgba(0,0,0,.25)', margin: '0 12px', position: 'relative' }}>
                    <span style={{ position: 'absolute', top: 0, bottom: 0, left: `${dayBars[i]!.left}%`, width: `${dayBars[i]!.width}%`, borderRadius: 3, background: `linear-gradient(90deg,${tempColor(d.lo)},${tempColor(d.hi)})` }} />
                  </span>
                  <span style={{ width: 40, fontSize: 18, fontWeight: 600 }}>{T(d.hi)}°</span>
                </div>
              ))}
            </div>
            <div style={{ flex: 1, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
              {tiles.map((x) => (
                <div key={x.k} data-tile={x.k} style={{ ...card, borderRadius: 22, padding: '12px 16px', height: 172, boxSizing: 'border-box', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 600, opacity: 0.8 }}><Ico d={x.d} size={16} sw={2} />{t(`met.tile_${x.k}`)}</span>
                  <span style={{ fontSize: 34, fontWeight: 500, lineHeight: 1.1 }}>{x.value}<span style={{ fontSize: 17, fontWeight: 500 }}> {x.unit}</span></span>
                  <span style={{ display: 'block', position: 'relative', height: 6, borderRadius: 3, background: x.bar === undefined ? 'transparent' : GAUGE }}>
                    {x.bar !== undefined && <span style={{ position: 'absolute', top: -3, left: `${x.bar}%`, width: 12, height: 12, marginLeft: -6, borderRadius: 6, background: '#fff', boxShadow: '0 0 0 2px rgba(0,0,0,.25)' }} />}
                  </span>
                  <span style={{ fontSize: 14, lineHeight: 1.25 }}>{x.sub}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
