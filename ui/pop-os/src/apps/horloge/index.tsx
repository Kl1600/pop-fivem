import { useCallback, useEffect, useRef, useState } from 'react';
import { Glass, useClock, useSettingsApi, type AppProps, type NuiResult } from '../../kit';
import { PRESETS, TIMER_MIN, WEEKDAYS, ZONES, clampTotal, faceOf, fmtSw, lapRows, p2, polar, hasDay, repKind, sortAlarms, timerText, toggleDay, type Alarm } from './model';

const BTN = { all: 'unset', cursor: 'pointer' } as const;
const ORANGE = '#ff9500';
const D = {
  world: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18',
  alarm: 'M12 6a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM12 10v4l2 2M4 6l3-3M20 6l-3-3',
  sw: 'M12 7a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM12 11v4M10 3h4M12 3v4',
  timer: 'M6 3h12M6 21h12M7 3c0 6 10 6 10 9s-10 3-10 9',
};
type Tab = 'world' | 'alarm' | 'sw' | 'timer';
interface AlarmRes extends NuiResult { alarms?: Alarm[]; timers?: Array<{ id: number; label: string; remaining: number }> }
interface Edit { id: number | null; minute: number; label: string; mask: number }
interface Timer { total: number; left: number; running: boolean; end: number; done: boolean; id: number | null }
const TICKS = Array.from({ length: 12 }, (_, i) => ({ a: polar(i * 30, 90), b: polar(i * 30, 82) }));
const NUMS = ([[0, '12'], [90, '3'], [180, '6'], [270, '9']] as Array<[number, string]>).map(([deg, label]) => ({ ...polar(deg, 68), label }));

export default function App({ t, dark, nui }: AppProps) {
  const lang = useSettingsApi().lang;
  const { gameMs, setSchedule } = useClock();
  const c = dark
    ? { bg: '#000000', cell: '#1c1c1e', fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)', fill: '#3a3a3c' }
    : { bg: '#f2f2f7', cell: '#ffffff', fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)', fill: '#e3e3e8' };
  const [tab, setTab] = useState<Tab>('world');
  const [, tick] = useState(0);
  const [alarms, setAlarms] = useState<Alarm[]>([]);
  const [editMode, setEditMode] = useState(false);
  const [ed, setEd] = useState<Edit | null>(null);
  const [error, setError] = useState('');
  const [sw, setSw] = useState({ running: false, base: 0, start: 0, laps: [] as number[] });
  const [tm, setTm] = useState<Timer>({ total: 300, left: 300_000, running: false, end: 0, done: false, id: null });

  // Heure du jeu : on demande une resynchronisation au client tant que l'appli est ouverte (annulée en la quittant).
  useEffect(() => {
    void nui.post('resync', { active: true });
    return () => { void nui.post('resync', { active: false }); };
  }, [nui]);

  const fail = useCallback((r: NuiResult) => setError(r.err ? t(r.err) : t('hor.err')), [t]);
  const publish = useCallback((list: Alarm[]) => setSchedule('alarm', list.filter((a) => a.enabled).map((a) => ({ id: a.id, minute: a.minute }))), [setSchedule]);

  useEffect(() => {
    let live = true;
    void nui.call<AlarmRes>('clock:list').then((r) => {
      if (!live) return;
      if (!r.ok) return fail(r);
      setAlarms(r.alarms ?? []);
      const first = r.timers?.[0];
      if (first && first.remaining > 0) {
        const total = clampTotal(Math.max(first.remaining, TIMER_MIN));
        setTm({ total, left: first.remaining * 1000, running: true, end: performance.now() + first.remaining * 1000, done: false, id: first.id });
      }
    });
    return () => { live = false; };
  }, [nui, fail]);

  // Un seul minuteur navigateur : 1 s pour les cadrans, 50 ms seulement si chronomètre ou minuteur tourne.
  const active = (tab === 'world') || sw.running || tm.running;
  const fast = sw.running || tm.running;
  const tmRef = useRef(tm);
  tmRef.current = tm;
  useEffect(() => {
    if (!active) return undefined;
    const iv = setInterval(() => {
      const cur = tmRef.current;
      if (cur.running && performance.now() >= cur.end) setTm({ ...cur, running: false, left: 0, done: true, id: null });
      tick((n) => n + 1);
    }, fast ? 50 : 1000);
    return () => clearInterval(iv);
  }, [active, fast]);

  const now = performance.now();
  const g = gameMs();

  const saveAlarm = async () => {
    if (!ed) return;
    const label = ed.label.trim() || t('hor.alarm_default');
    const r = await nui.call<NuiResult & { id?: number }>('clock:saveAlarm', { ...(ed.id !== null ? { id: ed.id } : {}), label, minute: ed.minute, mask: ed.mask, enabled: true });
    if (!r.ok || r.id === undefined) return fail(r);
    const row: Alarm = { id: r.id, label, minute: ed.minute, mask: ed.mask, enabled: true };
    const next = ed.id === null ? [...alarms, row] : alarms.map((a) => (a.id === ed.id ? row : a));
    setAlarms(next);
    publish(next);
    setEd(null);
  };
  const flip = async (a: Alarm) => {
    const r = await nui.call('clock:saveAlarm', { id: a.id, label: a.label, minute: a.minute, mask: a.mask, enabled: !a.enabled });
    if (!r.ok) return fail(r);
    const next = alarms.map((x) => (x.id === a.id ? { ...x, enabled: !x.enabled } : x));
    setAlarms(next);
    publish(next);
  };
  const remove = async (a: Alarm) => {
    const r = await nui.call('clock:deleteAlarm', a.id);
    if (!r.ok) return fail(r);
    const next = alarms.filter((x) => x.id !== a.id);
    setAlarms(next);
    publish(next);
  };

  const repText = (mask: number): string => {
    const k = repKind(mask);
    if (k !== 'custom') return t(`hor.rep_${k}`);
    return [0, 1, 2, 3, 4, 5, 6].filter((d) => hasDay(mask, d)).map((d) => dayName(d, lang)).join(', ');
  };

  // Minuteur : démarré côté serveur (une seule échéance, tablette fermée comprise) ; la pause annule et garde le reste.
  const timerSetTotal = (sec: number) => setTm({ total: sec, left: sec * 1000, running: false, end: 0, done: false, id: null });
  const timerLeft = tm.running ? Math.max(0, tm.end - now) : tm.left;
  const timerToggle = async () => {
    if (tm.running) {
      if (tm.id !== null) await nui.call('clock:cancelTimer', tm.id);
      setTm({ ...tm, running: false, left: Math.max(0, tm.end - performance.now()), id: null });
      return;
    }
    const left = tm.done || tm.left <= 0 ? tm.total * 1000 : tm.left;
    const r = await nui.call<NuiResult & { id?: number }>('clock:startTimer', { seconds: Math.max(1, Math.ceil(left / 1000)) });
    if (!r.ok || r.id === undefined) return fail(r);
    setTm({ ...tm, running: true, done: false, left, end: performance.now() + left, id: r.id });
  };
  const timerReset = async () => {
    if (tm.running && tm.id !== null) await nui.call('clock:cancelTimer', tm.id);
    timerSetTotal(tm.total);
  };

  const swMs = sw.base + (sw.running ? now - sw.start : 0);
  const tabs: Array<[Tab, string]> = [['world', 'hor.world'], ['alarm', 'hor.alarms'], ['sw', 'hor.stopwatch'], ['timer', 'hor.timers']];
  const ringColor = tm.done ? '#ff383c' : ORANGE;
  const endAt = new Date(Date.now() + timerLeft);

  return (
    <div style={{ width: '100%', height: '100%', position: 'relative', background: c.bg, color: c.fg, overflow: 'hidden', letterSpacing: '-0.01em' }}>
      <Glass style={{ position: 'absolute', left: '50%', top: 26, transform: 'translateX(-50%)', height: 60, borderRadius: 30, display: 'flex', alignItems: 'center', gap: 4, padding: '0 8px', zIndex: 5 }}>
        {tabs.map(([id, key]) => (
          <button type="button" key={id} aria-pressed={tab === id} onClick={() => setTab(id)} style={{ ...BTN, height: 46, padding: '0 20px', borderRadius: 23, display: 'flex', alignItems: 'center', gap: 8, fontSize: 16, fontWeight: 600, background: tab === id ? ORANGE : 'transparent', color: tab === id ? '#ffffff' : c.fg }}>
            <svg aria-hidden="true" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={D[id]} /></svg>{t(key)}
          </button>
        ))}
      </Glass>
      {error ? <div role="alert" style={{ position: 'absolute', top: 92, left: 0, right: 0, textAlign: 'center', color: '#ff383c', fontSize: 15, zIndex: 6 }}>{error}</div> : null}

      {tab === 'world' ? (
        <div style={{ position: 'absolute', left: 0, right: 0, top: 110, bottom: 0, padding: '0 70px', overflowY: 'auto' }}>
          <span style={{ display: 'block', fontSize: 34, fontWeight: 700, paddingBottom: 20 }}>{t('hor.world')}</span>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '26px 40px' }}>
            {ZONES.map((z) => {
              const f = faceOf(g, z.offset);
              const ink = f.night ? '#ffffff' : '#000000';
              const day = f.dayDiff === 0 ? t('hor.today') : f.dayDiff > 0 ? t('hor.tomorrow') : t('hor.yesterday');
              return (
                <div key={z.name} style={{ display: 'flex', alignItems: 'center', gap: 28, padding: '18px 26px', borderRadius: 26, background: c.cell }}>
                  <svg aria-label={z.name} role="img" width="220" height="220" viewBox="0 0 200 200" style={{ flexShrink: 0 }}>
                    <circle cx="100" cy="100" r="97" fill={f.night ? '#1c1c1e' : '#ffffff'} stroke={c.sep} strokeWidth="2" />
                    {TICKS.map((tk, i) => <line key={i} x1={tk.a.x} y1={tk.a.y} x2={tk.b.x} y2={tk.b.y} stroke={ink} strokeWidth="3" strokeLinecap="round" />)}
                    {NUMS.map((n) => <text key={n.label} x={n.x} y={n.y} textAnchor="middle" dominantBaseline="central" fontSize="17" fontWeight="600" fill={ink}>{n.label}</text>)}
                    <line x1="100" y1="100" x2={f.hx} y2={f.hy} stroke={ink} strokeWidth="6" strokeLinecap="round" />
                    <line x1="100" y1="100" x2={f.mx} y2={f.my} stroke={ink} strokeWidth="4" strokeLinecap="round" />
                    <line x1={f.tx} y1={f.ty} x2={f.sx} y2={f.sy} stroke={ORANGE} strokeWidth="2" strokeLinecap="round" />
                    <circle cx="100" cy="100" r="5" fill={ORANGE} />
                  </svg>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                    <span style={{ fontSize: 24, fontWeight: 700 }}>{z.name}</span>
                    <span style={{ fontSize: 15, color: c.sub }}>{day}, +{z.offset} h</span>
                    <span data-testid={`digital-${z.name}`} style={{ fontSize: 40, fontWeight: 300, paddingTop: 8, fontVariantNumeric: 'tabular-nums' }}>{f.digital}</span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      ) : null}

      {tab === 'alarm' ? (
        <div style={{ position: 'absolute', left: 0, right: 0, top: 110, bottom: 0, padding: '0 150px', overflowY: 'auto' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: 18 }}>
            <span style={{ fontSize: 34, fontWeight: 700 }}>{t('hor.alarms')}</span>
            <span style={{ display: 'flex', gap: 10 }}>
              <Glass as="button" onClick={() => setEditMode((v) => !v)} style={{ ...BTN, height: 44, padding: '0 20px', borderRadius: 22, display: 'flex', alignItems: 'center', fontSize: 16, fontWeight: 600, color: ORANGE }}>{editMode ? t('hor.done') : t('hor.edit')}</Glass>
              <Glass as="button" aria-label={t('hor.add_alarm')} onClick={() => setEd({ id: null, minute: 480, label: '', mask: 0 })} style={{ ...BTN, width: 44, height: 44, borderRadius: 22, display: 'flex', alignItems: 'center', justifyContent: 'center', color: ORANGE }}>
                <svg aria-hidden="true" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round"><path d="M12 5v14M5 12h14" /></svg>
              </Glass>
            </span>
          </div>
          <div style={{ borderRadius: 20, background: c.cell, overflow: 'hidden' }}>
            {sortAlarms(alarms).map((a) => (
              <div key={a.id} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '14px 24px', borderBottom: `1px solid ${c.sep}` }}>
                {editMode ? (
                  <button type="button" aria-label={t('hor.remove_alarm')} onClick={() => void remove(a)} style={{ ...BTN, width: 26, height: 26, borderRadius: 13, background: '#ff383c', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <svg aria-hidden="true" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="3.4" strokeLinecap="round"><path d="M5 12h14" /></svg>
                  </button>
                ) : null}
                <button type="button" onClick={() => setEd({ id: a.id, minute: a.minute, label: a.label, mask: a.mask })} style={{ ...BTN, flexGrow: 1, display: 'flex', flexDirection: 'column', gap: 2, opacity: a.enabled ? 1 : 0.45 }}>
                  <span style={{ fontSize: 56, fontWeight: 300, fontVariantNumeric: 'tabular-nums', lineHeight: 1.1 }}>{p2(Math.floor(a.minute / 60))}:{p2(a.minute % 60)}</span>
                  <span style={{ fontSize: 16, color: c.sub }}>{a.label}, {repText(a.mask)}</span>
                </button>
                <button type="button" role="switch" aria-checked={a.enabled} aria-label={t('hor.enable_alarm')} onClick={() => void flip(a)} style={{ ...BTN, width: 54, height: 32, borderRadius: 16, background: a.enabled ? '#34c759' : dark ? '#39393d' : '#e3e3e8', position: 'relative' }}>
                  <span style={{ position: 'absolute', top: 2, left: 2, width: 28, height: 28, borderRadius: 14, background: '#fff', boxShadow: '0 2px 4px rgba(0,0,0,.25)', transform: `translateX(${a.enabled ? 22 : 0}px)`, transition: 'transform .2s' }} />
                </button>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {tab === 'sw' ? (
        <div style={{ position: 'absolute', left: 0, right: 0, top: 110, bottom: 0, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <span data-testid="sw-text" style={{ fontSize: 150, fontWeight: 200, fontVariantNumeric: 'tabular-nums', paddingTop: 40, lineHeight: 1 }}>{fmtSw(swMs)}</span>
          <div style={{ display: 'flex', gap: 70, padding: '40px 0 30px' }}>
            <button type="button" aria-label={t('hor.lap_reset')} onClick={() => (sw.running ? setSw({ ...sw, laps: [...sw.laps, swMs] }) : setSw({ running: false, base: 0, start: 0, laps: [] }))} style={{ ...BTN, width: 104, height: 104, borderRadius: 52, background: c.fill, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18, fontWeight: 600, color: c.fg }}>{sw.running ? t('hor.lap') : t('hor.reset')}</button>
            <button type="button" aria-label={t('hor.start_stop')} onClick={() => (sw.running ? setSw({ ...sw, running: false, base: swMs }) : setSw({ ...sw, running: true, start: performance.now() }))} style={{ ...BTN, width: 104, height: 104, borderRadius: 52, background: sw.running ? '#ff383c' : '#34c759', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18, fontWeight: 600, color: '#fff' }}>{sw.running ? t('hor.stop') : t('hor.start')}</button>
          </div>
          <div style={{ width: 760, maxWidth: '90%', flexGrow: 1, overflowY: 'auto', borderTop: `1px solid ${c.sep}` }}>
            {lapRows(sw.laps).map((l) => (
              <div key={l.n} style={{ display: 'flex', justifyContent: 'space-between', padding: '14px 6px', borderBottom: `1px solid ${c.sep}`, fontSize: 20, color: l.kind === 'best' ? '#34c759' : l.kind === 'worst' ? '#ff383c' : c.fg, fontVariantNumeric: 'tabular-nums' }}><span>{t('hor.lap_n', l.n)}</span><span>{fmtSw(l.d)}</span></div>
            ))}
          </div>
        </div>
      ) : null}

      {tab === 'timer' ? (
        <div style={{ position: 'absolute', left: 0, right: 0, top: 110, bottom: 0, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <div style={{ position: 'relative', width: 340, height: 340, marginTop: 10 }}>
            <svg aria-hidden="true" width="340" height="340" viewBox="0 0 340 340" style={{ transform: 'rotate(-90deg)' }}>
              <circle cx="170" cy="170" r="150" fill="none" stroke={c.fill} strokeWidth="12" />
              <circle cx="170" cy="170" r="150" fill="none" stroke={ringColor} strokeWidth="12" strokeLinecap="round" strokeDasharray="942.5" strokeDashoffset={942.5 * (1 - (tm.total ? Math.min(1, timerLeft / (tm.total * 1000)) : 0))} />
            </svg>
            <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
              <span data-testid="timer-text" style={{ fontSize: 72, fontWeight: 200, fontVariantNumeric: 'tabular-nums' }}>{timerText(timerLeft / 1000)}</span>
              <span style={{ fontSize: 16, color: c.sub }}>{tm.done ? t('hor.finished') : tm.running ? t('hor.ends_at', `${p2(endAt.getHours())}:${p2(endAt.getMinutes())}`) : t('hor.duration', Math.round(tm.total / 60))}</span>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 70, padding: '30px 0 26px' }}>
            <button type="button" aria-label={t('hor.cancel_timer')} onClick={() => void timerReset()} style={{ ...BTN, width: 96, height: 96, borderRadius: 48, background: c.fill, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18, fontWeight: 600, color: c.fg }}>{t('hor.cancel')}</button>
            <button type="button" aria-label={t('hor.start_pause')} onClick={() => void timerToggle()} style={{ ...BTN, width: 96, height: 96, borderRadius: 48, background: tm.running ? ORANGE : '#34c759', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18, fontWeight: 600, color: '#fff' }}>{tm.running ? t('hor.pause') : tm.done ? t('hor.restart') : t('hor.start')}</button>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <Glass as="button" aria-label={t('hor.minus_min')} onClick={() => timerSetTotal(clampTotal(tm.total - 60))} style={{ ...BTN, width: 44, height: 44, borderRadius: 22, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 26, color: c.fg }}>−</Glass>
            {PRESETS.map((p) => (
              <button type="button" key={p} onClick={() => timerSetTotal(p)} style={{ ...BTN, height: 44, padding: '0 20px', borderRadius: 22, fontSize: 16, fontWeight: 600, background: tm.total === p ? ORANGE : c.fill, color: tm.total === p ? '#ffffff' : c.fg }}>{p >= 3600 ? t('hor.hours', p / 3600) : t('hor.minutes', p / 60)}</button>
            ))}
            <Glass as="button" aria-label={t('hor.plus_min')} onClick={() => timerSetTotal(clampTotal(tm.total + 60))} style={{ ...BTN, width: 44, height: 44, borderRadius: 22, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 26, color: c.fg }}>+</Glass>
          </div>
          <div style={{ width: 560, maxWidth: '90%', marginTop: 28, borderRadius: 16, background: c.cell, display: 'flex', justifyContent: 'space-between', padding: '15px 20px', fontSize: 17, boxSizing: 'border-box' }}><span>{t('hor.at_end')}</span><span style={{ color: c.sub }}>{t('hor.ringtone')}</span></div>
        </div>
      ) : null}

      {ed ? (
        <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,.35)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10 }}>
          <Glass style={{ width: 520, borderRadius: 30, padding: 26, boxSizing: 'border-box', display: 'flex', flexDirection: 'column', gap: 18 }}>
            <span style={{ fontSize: 22, fontWeight: 700, textAlign: 'center' }}>{ed.id === null ? t('hor.new_alarm') : t('hor.edit_alarm')}</span>
            <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 16 }}>
              {(['h', 'm'] as const).map((unit, i) => {
                const value = unit === 'h' ? Math.floor(ed.minute / 60) : ed.minute % 60;
                const bump = (dir: number) => {
                  const h = Math.floor(ed.minute / 60);
                  const m = ed.minute % 60;
                  setEd({ ...ed, minute: unit === 'h' ? ((h + dir + 24) % 24) * 60 + m : h * 60 + ((m + dir * 5 + 60) % 60) });
                };
                return (
                  <span key={unit} style={{ display: 'contents' }}>
                    {i === 1 ? <span style={{ fontSize: 64, fontWeight: 300 }}>:</span> : null}
                    <span style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
                      <button type="button" aria-label={t(unit === 'h' ? 'hor.hour_up' : 'hor.min_up')} onClick={() => bump(1)} style={{ ...BTN, minWidth: 60, height: 36, borderRadius: 12, background: c.fill, textAlign: 'center', color: c.fg }}>▲</button>
                      <span style={{ fontSize: 72, fontWeight: 300, fontVariantNumeric: 'tabular-nums' }}>{p2(value)}</span>
                      <button type="button" aria-label={t(unit === 'h' ? 'hor.hour_down' : 'hor.min_down')} onClick={() => bump(-1)} style={{ ...BTN, minWidth: 60, height: 36, borderRadius: 12, background: c.fill, textAlign: 'center', color: c.fg }}>▼</button>
                    </span>
                  </span>
                );
              })}
            </div>
            <div style={{ display: 'flex', justifyContent: 'center', gap: 6 }}>
              {[0, 1, 2, 3, 4, 5, 6].map((d) => (
                <button type="button" key={d} aria-pressed={hasDay(ed.mask, d)} aria-label={dayName(d, lang)} onClick={() => setEd({ ...ed, mask: toggleDay(ed.mask, d) })} style={{ ...BTN, width: 56, height: 36, borderRadius: 18, textAlign: 'center', lineHeight: '36px', fontSize: 14, fontWeight: 600, background: hasDay(ed.mask, d) ? ORANGE : c.fill, color: hasDay(ed.mask, d) ? '#fff' : c.fg }}>{dayName(d, lang)}</button>
              ))}
            </div>
            <button type="button" onClick={() => setEd({ ...ed, mask: ed.mask === WEEKDAYS ? 0 : WEEKDAYS })} style={{ ...BTN, textAlign: 'center', fontSize: 15, color: ORANGE }}>{t('hor.rep_weekdays')}</button>
            <input aria-label={t('hor.alarm_name')} placeholder={t('hor.name')} maxLength={40} value={ed.label} onChange={(e) => setEd({ ...ed, label: e.target.value })} style={{ all: 'unset', height: 46, padding: '0 16px', borderRadius: 14, background: c.fill, fontSize: 17, color: c.fg }} />
            <div style={{ display: 'flex', gap: 10, justifyContent: 'space-between' }}>
              <button type="button" onClick={() => setEd(null)} style={{ ...BTN, flex: 1, height: 46, borderRadius: 23, background: c.fill, textAlign: 'center', lineHeight: '46px', fontSize: 17, fontWeight: 600, color: c.fg }}>{t('hor.cancel')}</button>
              <button type="button" onClick={() => void saveAlarm()} style={{ ...BTN, flex: 1, height: 46, borderRadius: 23, background: ORANGE, textAlign: 'center', lineHeight: '46px', fontSize: 17, fontWeight: 600, color: '#fff' }}>{t('hor.save')}</button>
            </div>
          </Glass>
        </div>
      ) : null}
    </div>
  );
}

/** Jour de la semaine abrégé (0 = lundi) dans la langue de la tablette. */
function dayName(d: number, lang: string): string {
  const base = new Date(Date.UTC(2026, 10, 23 + d)); // le 23/11/2026 est un lundi
  try {
    return new Intl.DateTimeFormat(lang, { weekday: 'short', timeZone: 'UTC' }).format(base);
  } catch {
    return new Intl.DateTimeFormat('en', { weekday: 'short', timeZone: 'UTC' }).format(base);
  }
}
