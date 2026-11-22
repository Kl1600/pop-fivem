import { useCallback, useEffect, useMemo, useState } from 'react';
import { Glass, useSettingsApi, type AppProps, type NuiResult } from '../../kit';
import { NEWS_GRADS, PERIODS, applyTick, changeOf, fmt, linePath, newsKeys, series, sign, spark, type Period, type Stock } from './model';

const BTN = { all: 'unset', cursor: 'pointer' } as const;
const GREEN = '#34c759';
const RED = '#ff3b30';
const W = 916;
const H = 330;

/** Cours du paquet push `pop-market` (un tableau de centimes par symbole). */
const tickOf = (e: Event): unknown => (e as CustomEvent).detail?.p;

interface SubRes extends NuiResult { items?: Stock[]; watch?: string[] }
interface WatchRes extends NuiResult { watch?: string[] }

export default function App({ t, dark, nui }: AppProps) {
  const c = dark
    ? { bg: '#000000', cell: '#1c1c1e', fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)', sel: '#2c2c2e', seg: '#3a3a3c' }
    : { bg: '#f2f2f7', cell: '#ffffff', fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)', sel: '#ffffff', seg: '#ffffff' };
  const lang = useSettingsApi().lang;
  const [items, setItems] = useState<Stock[]>([]);
  const [watch, setWatch] = useState<string[]>([]);
  const [sel, setSel] = useState('');
  const [period, setPeriod] = useState<Period>(2);
  const [hover, setHover] = useState<number | null>(null);
  const [pct, setPct] = useState(true);
  const [edit, setEdit] = useState(false);
  const [error, setError] = useState('');

  // Abonnement serveur tant que l'appli est ouverte : le serveur n'envoie des cours (et ne simule) que pour les abonnés.
  useEffect(() => {
    let live = true;
    void (async () => {
      const r = await nui.call<SubRes>('stocks:subscribe');
      if (!live) return;
      if (!r.ok) { setError(r.err ? t(r.err) : t('bou.err')); return; }
      const list = r.items ?? [];
      setItems(list);
      setWatch(r.watch ?? list.map((s) => s.sym));
      setSel((cur) => cur || (r.watch?.[0] ?? list[0]?.sym ?? ''));
    })();
    const onTick = (e: Event) => setItems((cur) => applyTick(cur, tickOf(e)));
    window.addEventListener('pop-market', onTick);
    return () => {
      live = false;
      window.removeEventListener('pop-market', onTick);
      void nui.call('stocks:unsubscribe');
    };
  }, [nui, t]);

  const toggleWatch = useCallback(async (sym: string) => {
    const r = await nui.call<WatchRes>('stocks:watch', { sym, on: !watch.includes(sym) });
    if (r.ok) setWatch(r.watch ?? []); else setError(r.err ? t(r.err) : t('bou.err'));
  }, [nui, watch, t]);

  const order = useMemo(() => new Map(items.map((s, i) => [s.sym, i])), [items]);
  const list = items.filter((s) => watch.includes(s.sym));
  const cur = items.find((s) => s.sym === sel) ?? list[0] ?? items[0];
  const ci = cur ? order.get(cur.sym) ?? 0 : 0;
  const ser = useMemo(() => (cur ? series(ci, period, cur) : []), [cur, ci, period]);

  if (!cur || ser.length < 2) {
    return <div style={{ width: '100%', height: '100%', background: c.bg, color: c.sub, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17 }}>{error || t('bou.loading')}</div>;
  }

  const chart = linePath(ser, W, H, 20, 20);
  const col = changeOf(cur, period) >= 0 ? GREEN : RED;
  const hk = hover === null ? ser.length - 1 : hover;
  const hv = ser[hk]!;
  const hp = ((hv - ser[0]!) / ser[0]!) * 100;
  const px = (hk / (ser.length - 1)) * W;
  const py = 20 + ((chart.max - hv) / (chart.max - chart.min || 1)) * (H - 40);
  const grid = [0, 1, 2, 3].map((g) => ({ y: 20 + (g * (H - 40)) / 3, v: chart.max - ((chart.max - chart.min) * g) / 3 }));
  const day = series(ci, 0, cur);
  const y1 = series(ci, 4, cur);
  const facts: Array<[string, string]> = [
    [t('bou.f_open'), fmt(cur.open, lang)], [t('bou.f_high'), fmt(Math.max(...day), lang)], [t('bou.f_low'), fmt(Math.min(...day), lang)],
    [t('bou.f_volume'), t('bou.millions', fmt(cur.volume, lang, 1))], [t('bou.f_cap'), cur.cap === undefined ? '—' : t('bou.billions', fmt(cur.cap, lang, 1))],
    [t('bou.f_per'), cur.per === undefined ? '—' : fmt(cur.per, lang, 1)], [t('bou.f_div'), cur.div === undefined ? '—' : `${fmt(cur.div, lang, 1)} %`],
    [t('bou.f_hi52'), fmt(Math.max(...y1), lang)], [t('bou.f_lo52'), fmt(Math.min(...y1), lang)],
    [t('bou.f_ch1m'), `${sign(changeOf(cur, 2), lang)} %`], [t('bou.f_ch1y'), `${sign(changeOf(cur, 4), lang)} %`], [t('bou.f_ch5y'), `${sign(changeOf(cur, 5), lang)} %`],
  ];
  const news = newsKeys(cur);
  const xlabels = t(`bou.x_${PERIODS[period]}`).split('|');
  const onMove = (e: React.PointerEvent<SVGSVGElement>) => {
    const r = e.currentTarget.getBoundingClientRect();
    const k = Math.round(((e.clientX - r.left) / (r.width || 1)) * (ser.length - 1));
    setHover(Math.max(0, Math.min(ser.length - 1, k)));
  };

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', display: 'flex', overflow: 'hidden', background: c.bg, color: c.fg, letterSpacing: '-0.01em' }}>
      <nav aria-label={t('bou.watchlist')} style={{ width: 360, flexShrink: 0, height: '100%', boxSizing: 'border-box', background: c.bg, borderRight: `1px solid ${c.sep}`, padding: '46px 14px 20px', display: 'flex', flexDirection: 'column', gap: 4 }}>
        <span style={{ fontSize: 34, fontWeight: 700, padding: '0 10px 4px' }}>{t('app.bourse')}</span>
        <span style={{ fontSize: 14, color: c.sub, padding: '0 10px 10px' }}>{t('bou.subtitle')}</span>
        {error && <span role="alert" style={{ fontSize: 13, color: RED, padding: '0 10px' }}>{error}</span>}
        <div style={{ flexGrow: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 2 }}>
          {(edit ? items : list).map((s) => {
            const i = order.get(s.sym) ?? 0;
            const d = changeOf(s, 0);
            const color = d >= 0 ? GREEN : RED;
            const on = watch.includes(s.sym);
            return (
              <div key={s.sym} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                {edit && <button onClick={() => void toggleWatch(s.sym)} aria-label={on ? t('bou.unwatch', s.sym) : t('bou.watch', s.sym)} aria-pressed={on} style={{ ...BTN, width: 26, height: 26, borderRadius: 13, background: on ? '#ff3b30' : GREEN, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18, fontWeight: 800 }}>{on ? '−' : '+'}</button>}
                <button data-sym={s.sym} onClick={() => { setSel(s.sym); setHover(null); }} style={{ ...BTN, flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 10, padding: '11px 12px', borderRadius: 12, background: cur.sym === s.sym ? c.sel : 'transparent' }}>
                  <span style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', textAlign: 'start' }}>
                    <span style={{ fontSize: 17, fontWeight: 700 }}>{s.sym}</span>
                    <span style={{ fontSize: 13, color: c.sub, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{s.index ? t('bou.index', s.name) : s.name}</span>
                  </span>
                  <svg aria-hidden="true" width="70" height="30" viewBox="0 0 70 30"><path d={spark(series(i, 0, s))} fill="none" stroke={color} strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" /></svg>
                  <span style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 3 }}>
                    <span data-testid={`price-${s.sym}`} style={{ fontSize: 16, fontWeight: 600, fontVariantNumeric: 'tabular-nums' }}>{fmt(s.price, lang)}</span>
                    <span style={{ minWidth: 64, textAlign: 'center', padding: '2px 6px', borderRadius: 6, background: color, color: '#fff', fontSize: 14, fontWeight: 600 }}>{pct ? `${sign(d, lang)} %` : sign(s.price - s.open, lang)}</span>
                  </span>
                </button>
              </div>
            );
          })}
          {!edit && !list.length && <span style={{ textAlign: 'center', padding: '40px 10px', color: c.sub, fontSize: 16 }}>{t('bou.empty')}</span>}
        </div>
        <button onClick={() => setPct(!pct)} style={{ ...BTN, textAlign: 'center', padding: 10, fontSize: 15, color: '#0088ff' }}>{pct ? t('bou.show_value') : t('bou.show_pct')}</button>
        <button onClick={() => setEdit(!edit)} aria-pressed={edit} style={{ ...BTN, textAlign: 'center', padding: 6, fontSize: 15, color: '#0088ff' }}>{edit ? t('bou.done') : t('bou.edit')}</button>
      </nav>

      <main style={{ flexGrow: 1, minWidth: 0, height: '100%', overflowY: 'auto', padding: '46px 36px 40px', boxSizing: 'border-box', background: c.cell }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <span style={{ fontSize: 34, fontWeight: 800 }}>{cur.sym}</span>
            <span style={{ fontSize: 17, color: c.sub }}>{cur.index ? t('bou.index', cur.name) : cur.name}</span>
          </div>
          <Glass style={{ display: 'flex', gap: 2, padding: 4, borderRadius: 22 }}>
            {PERIODS.map((k, i) => (
              <button key={k} onClick={() => { setPeriod(i as Period); setHover(null); }} aria-pressed={period === i} style={{ ...BTN, minWidth: 44, height: 36, borderRadius: 18, textAlign: 'center', lineHeight: '36px', fontSize: 15, fontWeight: 700, background: period === i ? c.seg : 'transparent', color: period === i ? c.fg : c.sub, transition: 'background .2s' }}>{t(`bou.p_${k}`)}</button>
            ))}
          </Glass>
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 14, padding: '14px 0 10px' }}>
          <span data-testid="shown-price" style={{ fontSize: 56, fontWeight: 700, fontVariantNumeric: 'tabular-nums' }}>{fmt(hv, lang)}</span>
          <span style={{ fontSize: 20, fontWeight: 600, color: col }}>{sign(hover === null ? changeOf(cur, period) : hp, lang)} %</span>
          <span style={{ fontSize: 15, color: c.sub }}>{hover === null ? t(`bou.full_${PERIODS[period]}`) : t('bou.since_start')}</span>
        </div>
        <div style={{ position: 'relative', width: '100%', maxWidth: W }}>
          <svg aria-label={t('bou.chart')} role="img" width="100%" viewBox={`0 0 ${W} ${H}`} onPointerMove={onMove} onPointerLeave={() => setHover(null)} style={{ display: 'block', touchAction: 'none' }}>
            <defs><linearGradient id="bou-aire" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={col} stopOpacity=".32" /><stop offset="1" stopColor={col} stopOpacity="0" /></linearGradient></defs>
            {grid.map((g, i) => <g key={i}><line x1="0" y1={g.y} x2={W} y2={g.y} stroke={c.sep} strokeWidth="1" /><text x={W - 4} y={g.y - 5} textAnchor="end" fontSize="12" fill={c.sub}>{fmt(g.v, lang)}</text></g>)}
            <path d={chart.area} fill="url(#bou-aire)" />
            <path data-testid="chart-line" d={chart.line} fill="none" stroke={col} strokeWidth="2.6" strokeLinejoin="round" strokeLinecap="round" />
            <line x1={px} y1="0" x2={px} y2={H} stroke={c.sub} strokeWidth="1" opacity={hover === null ? 0 : 1} />
            <circle cx={px} cy={py} r="6" fill={col} stroke={c.cell} strokeWidth="3" opacity={hover === null ? 0 : 1} />
          </svg>
        </div>
        <div style={{ width: '100%', maxWidth: W, display: 'flex', justifyContent: 'space-between', fontSize: 13, color: c.sub, paddingTop: 6 }}>
          {xlabels.map((x, i) => <span key={i}>{x}</span>)}
        </div>

        <span style={{ display: 'block', fontSize: 22, fontWeight: 700, padding: '30px 0 10px' }}>{t('bou.key_figures')}</span>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '0 24px', width: '100%', maxWidth: W }}>
          {facts.map(([k, v]) => <div key={k} style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 0', borderTop: `1px solid ${c.sep}`, fontSize: 15 }}><span style={{ color: c.sub }}>{k}</span><span style={{ fontWeight: 600, fontVariantNumeric: 'tabular-nums' }}>{v}</span></div>)}
        </div>

        <span style={{ display: 'block', fontSize: 22, fontWeight: 700, padding: '30px 0 10px' }}>{t('bou.news')}</span>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, width: '100%', maxWidth: W }}>
          {news.map((n, i) => (
            <div key={i} style={{ display: 'flex', gap: 16, padding: 12, borderRadius: 18, background: c.bg }}>
              <span style={{ width: 120, height: 80, flexShrink: 0, borderRadius: 12, background: NEWS_GRADS[i] }} />
              <span style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 4 }}>
                <span style={{ fontSize: 13, fontWeight: 700, color: c.sub }}>{n.src} · {n.ago[1] === undefined ? t(n.ago[0]) : t(n.ago[0], n.ago[1])}</span>
                <span style={{ fontSize: 18, fontWeight: 600, lineHeight: 1.25 }}>{t(n.key, cur.name)}</span>
              </span>
            </div>
          ))}
        </div>
      </main>
    </div>
  );
}
