import { useCallback, useEffect, useRef, useState } from 'react';
import { Glass, Sheet, useClock, useSettingsApi, type AppProps, type NuiResult } from '../../kit';
import { ALERTS, CALS, DEFAULT_COLOR, PX, alertMinute, blockOf, calOf, dateOf, dayPart, draftFor, eventsOn, firstOfMonth, monthGrid, nowMinute, rangeFor, stampOf, step, timePart, titleOf, todayKey, weekDays, type CalEvent, type View } from './model';

const BTN = { all: 'unset', cursor: 'pointer' } as const;
const RED = '#ff383c';
interface ListRes extends NuiResult { events?: CalEvent[]; alerts?: Array<{ id: number; start: string; allDay: boolean; alert: number | null }> }
interface Draft { id: number | null; title: string; place: string; notes: string; date: string; from: string; to: string; allDay: boolean; alert: number | null; color: string }

function fmtDay(key: string, lang: string, o: Intl.DateTimeFormatOptions): string {
  try { return new Intl.DateTimeFormat(lang, { ...o, timeZone: 'UTC' }).format(dateOf(key)); } catch { return new Intl.DateTimeFormat('en', { ...o, timeZone: 'UTC' }).format(dateOf(key)); }
}

export default function App({ t, dark, nui }: AppProps) {
  const lang = useSettingsApi().lang;
  const { gameMs, setSchedule } = useClock();
  const c = dark
    ? { side: '#000000', cell: '#000000', fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)', hi: '#2c2c2e', fill: '#3a3a3c' }
    : { side: '#f2f2f7', cell: '#ffffff', fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)', hi: '#e3e3e8', fill: '#e3e3e8' };
  const today = todayKey(gameMs());
  const [view, setView] = useState<View>('week');
  const [anchor, setAnchor] = useState(today);
  const [mini, setMini] = useState(firstOfMonth(today));
  const [hidden, setHidden] = useState<Record<string, boolean>>({});
  const [events, setEvents] = useState<CalEvent[]>([]);
  const [sel, setSel] = useState<{ id: number; day: string } | null>(null);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [error, setError] = useState('');
  const scroller = useRef<HTMLDivElement | null>(null);

  const fail = useCallback((r: NuiResult) => setError(r.err ? t(r.err) : t('cal.err')), [t]);

  const load = useCallback(async () => {
    const range = rangeFor(view, anchor);
    const r = await nui.call<ListRes>('calendar:list', range ?? { from: firstOfMonth(anchor), to: firstOfMonth(anchor) });
    if (!r.ok) return fail(r);
    setEvents(range ? r.events ?? [] : []);
    const items: Array<{ id: number; minute: number }> = [];
    for (const a of r.alerts ?? []) { const m = alertMinute(a); if (m !== null) items.push({ id: a.id, minute: m }); }
    setSchedule('event', items);
  }, [nui, view, anchor, fail, setSchedule]);
  useEffect(() => { void load(); }, [load]);

  // La grille jour/semaine s'ouvre sur 7 h (ou sur l'heure courante).
  useEffect(() => { if (scroller.current) scroller.current.scrollTop = 7 * PX; }, [view]);

  const goDay = (key: string) => { setAnchor(key); setView('day'); setMini(firstOfMonth(key)); };
  const move = (n: number) => { const k = step(view, anchor, n); setAnchor(k); setMini(firstOfMonth(k)); };
  const open = (e: CalEvent, day: string) => setSel({ id: e.id, day });
  const startDraft = (e?: CalEvent) => {
    if (e) { setDraft({ id: e.id, title: e.title, place: e.place, notes: e.notes, date: dayPart(e.start), from: e.allDay ? '09:00' : timePart(e.start), to: e.allDay ? '10:00' : timePart(e.stop), allDay: e.allDay, alert: e.alert, color: e.color || DEFAULT_COLOR }); return; }
    setDraft({ id: null, title: '', place: '', notes: '', alert: null, color: DEFAULT_COLOR, allDay: false, ...draftFor(anchor, nowMinute(gameMs()) + 60) });
  };
  const save = async () => {
    if (!draft) return;
    const start = stampOf(draft.date, draft.allDay ? '00:00' : draft.from);
    const stop = stampOf(draft.date, draft.allDay ? '23:59' : draft.to);
    if (!draft.title.trim()) return setError(t('cal.err_title'));
    if (stop < start) return setError(t('cal.err_time'));
    const r = await nui.call('calendar:save', { ...(draft.id !== null ? { id: draft.id } : {}), title: draft.title.trim(), place: draft.place, notes: draft.notes, start, stop, allDay: draft.allDay, ...(draft.alert !== null ? { alert: draft.alert } : {}), color: draft.color });
    if (!r.ok) return fail(r);
    setError('');
    setDraft(null);
    setSel(null);
    await load();
  };
  const remove = async () => {
    if (!sel) return;
    const r = await nui.call('calendar:delete', sel.id);
    if (!r.ok) return fail(r);
    setSel(null);
    await load();
  };

  const shades = (color: string) => ({ bg: color + (dark ? '55' : '2e'), fg: dark ? '#fff' : color });
  const dayName = (key: string, style: 'short' | 'narrow') => fmtDay(key, lang, { weekday: style });
  const heads = weekDays(today).map((k) => dayName(k, 'narrow'));
  const cols = view === 'day' ? [anchor] : weekDays(anchor);
  const selEv = sel ? events.find((e) => e.id === sel.id) : undefined;
  const miniDays = monthGrid(mini);
  const views: View[] = ['day', 'week', 'month', 'year'];
  const nowTop = (nowMinute(gameMs()) / 60) * PX;

  return (
    <div style={{ width: '100%', height: '100%', display: 'flex', background: c.cell, color: c.fg, overflow: 'hidden', position: 'relative', letterSpacing: '-0.01em' }}>
      <nav aria-label={t('cal.calendars')} style={{ width: 300, flexShrink: 0, height: '100%', boxSizing: 'border-box', background: c.side, borderRight: `1px solid ${c.sep}`, padding: '46px 18px 20px', display: 'flex', flexDirection: 'column', gap: 6 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 4px 8px' }}>
          <span style={{ fontSize: 20, fontWeight: 700 }}>{fmtDay(mini, lang, { month: 'long', year: 'numeric' })}</span>
          <span style={{ display: 'flex', gap: 14, fontSize: 22, color: RED }}>
            <button type="button" aria-label={t('cal.prev_month')} onClick={() => setMini((m) => step('month', m, -1))} style={BTN}>‹</button>
            <button type="button" aria-label={t('cal.next_month')} onClick={() => setMini((m) => step('month', m, 1))} style={BTN}>›</button>
          </span>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', rowGap: 4, textAlign: 'center' }}>
          {heads.map((h, i) => <span key={i} style={{ fontSize: 12, fontWeight: 600, color: c.sub }}>{h}</span>)}
          {miniDays.map((k) => {
            const isToday = k === today;
            const isSel = k === anchor;
            return (
              <button type="button" key={k} aria-label={fmtDay(k, lang, { day: 'numeric', month: 'long' })} onClick={() => { setAnchor(k); if (view === 'year') setView('day'); }} style={{ ...BTN, justifySelf: 'center', width: 34, height: 34, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16, fontWeight: isToday || isSel ? 700 : 400, background: isToday ? RED : isSel ? c.hi : 'transparent', color: isToday ? '#fff' : k.slice(0, 7) === mini.slice(0, 7) ? c.fg : c.sub }}>{Number(k.slice(8))}</button>
            );
          })}
        </div>
        <span style={{ fontSize: 13, fontWeight: 600, color: c.sub, padding: '26px 4px 6px', textTransform: 'uppercase' }}>{t('cal.on_tablet')}</span>
        {CALS.map((k) => (
          <button type="button" key={k.id} aria-pressed={!hidden[k.id]} onClick={() => setHidden((h) => ({ ...h, [k.id]: !h[k.id] }))} style={{ ...BTN, display: 'flex', alignItems: 'center', gap: 12, height: 40, padding: '0 4px', fontSize: 17 }}>
            <span style={{ width: 22, height: 22, borderRadius: '50%', boxSizing: 'border-box', border: `2px solid ${k.color}`, background: hidden[k.id] ? 'transparent' : k.color, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg aria-hidden="true" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" style={{ opacity: hidden[k.id] ? 0 : 1 }}><path d="M5 12l5 5 9-10" /></svg>
            </span>{t(k.key)}
          </button>
        ))}
      </nav>

      <main style={{ flexGrow: 1, minWidth: 0, height: '100%', display: 'flex', flexDirection: 'column', position: 'relative' }}>
        <div style={{ flexShrink: 0, padding: '40px 24px 12px', display: 'flex', alignItems: 'center', gap: 16 }}>
          <span style={{ fontSize: 34, fontWeight: 700, flexGrow: 1, whiteSpace: 'nowrap', textTransform: 'capitalize' }}>{titleOf(view, anchor, lang)}</span>
          <Glass style={{ display: 'flex', padding: 3, borderRadius: 20 }}>
            {views.map((v) => (
              <button type="button" key={v} aria-pressed={view === v} onClick={() => setView(v)} style={{ ...BTN, height: 34, padding: '0 16px', borderRadius: 17, fontSize: 15, fontWeight: 600, background: view === v ? RED : 'transparent', color: view === v ? '#fff' : c.fg }}>{t(`cal.view_${v}`)}</button>
            ))}
          </Glass>
          <Glass as="span" style={{ display: 'flex', alignItems: 'center', height: 40, borderRadius: 20, padding: '0 6px', gap: 2, fontSize: 16, fontWeight: 600 }}>
            <button type="button" aria-label={t('cal.prev')} onClick={() => move(-1)} style={{ ...BTN, width: 32, textAlign: 'center', fontSize: 22 }}>‹</button>
            <button type="button" onClick={() => { setAnchor(today); setMini(firstOfMonth(today)); }} style={{ ...BTN, padding: '0 8px' }}>{t('cal.today')}</button>
            <button type="button" aria-label={t('cal.next')} onClick={() => move(1)} style={{ ...BTN, width: 32, textAlign: 'center', fontSize: 22 }}>›</button>
          </Glass>
          <Glass as="button" aria-label={t('cal.add')} onClick={() => startDraft()} style={{ ...BTN, width: 40, height: 40, borderRadius: 20, display: 'flex', alignItems: 'center', justifyContent: 'center', color: RED, fontSize: 28, fontWeight: 300 }}>+</Glass>
        </div>
        {error ? <div role="alert" style={{ color: RED, fontSize: 15, padding: '0 24px 6px' }}>{error}</div> : null}

        {view === 'day' || view === 'week' ? (
          <>
            <div style={{ display: 'flex', flexShrink: 0, paddingLeft: 56, borderBottom: `1px solid ${c.sep}` }}>
              {cols.map((k) => (
                <div key={k} style={{ flex: 1, textAlign: 'center', padding: '6px 0 8px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
                  <span style={{ fontSize: 13, fontWeight: 600, color: c.sub, textTransform: 'uppercase' }}>{dayName(k, 'short')}</span>
                  <span style={{ width: 36, height: 36, borderRadius: '50%', background: k === today ? RED : 'transparent', color: k === today ? '#fff' : c.fg, fontSize: 22, fontWeight: 500, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{Number(k.slice(8))}</span>
                </div>
              ))}
            </div>
            <div ref={scroller} style={{ flexGrow: 1, overflowY: 'auto', position: 'relative' }}>
              <div style={{ display: 'flex', height: 24 * PX, position: 'relative' }}>
                <div style={{ width: 56, flexShrink: 0, position: 'relative' }}>
                  {Array.from({ length: 24 }, (_, h) => <span key={h} style={{ position: 'absolute', right: 8, top: h * PX, fontSize: 12, color: c.sub, transform: 'translateY(-7px)' }}>{h}:00</span>)}
                </div>
                <div style={{ flexGrow: 1, position: 'relative', display: 'flex' }}>
                  {Array.from({ length: 24 }, (_, h) => <span key={h} style={{ position: 'absolute', left: 0, right: 0, top: h * PX, borderTop: `1px solid ${c.sep}` }} />)}
                  {cols.map((k) => (
                    <div key={k} style={{ flex: 1, position: 'relative', borderLeft: `1px solid ${c.sep}` }}>
                      {eventsOn(events, k, hidden).map((e) => {
                        const b = blockOf(e, k);
                        const color = e.color || DEFAULT_COLOR;
                        const s = shades(color);
                        return (
                          <button type="button" key={e.id} onClick={() => open(e, k)} style={{ ...BTN, position: 'absolute', left: 3, right: 3, top: b.top, height: b.height, boxSizing: 'border-box', borderRadius: 8, padding: '5px 8px', borderLeft: `4px solid ${color}`, background: s.bg, color: s.fg, overflow: 'hidden', fontSize: 13, fontWeight: 600, lineHeight: 1.25 }}>
                            <span style={{ display: 'block' }}>{e.title}</span>
                            <span style={{ display: 'block', fontWeight: 400, opacity: 0.8 }}>{e.allDay ? t('cal.all_day') : `${timePart(e.start)} – ${timePart(e.stop)}`}</span>
                          </button>
                        );
                      })}
                      {k === today ? <span style={{ position: 'absolute', left: 0, right: 0, top: nowTop, borderTop: `2px solid ${RED}` }}><span style={{ position: 'absolute', left: -5, top: -6, width: 10, height: 10, borderRadius: '50%', background: RED }} /></span> : null}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </>
        ) : null}

        {view === 'month' ? (
          <>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', borderBottom: `1px solid ${c.sep}`, flexShrink: 0 }}>
              {weekDays(today).map((k) => <span key={k} style={{ textAlign: 'center', fontSize: 13, fontWeight: 600, color: c.sub, padding: '6px 0', textTransform: 'uppercase' }}>{dayName(k, 'short')}</span>)}
            </div>
            <div style={{ flexGrow: 1, display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gridAutoRows: '1fr', overflow: 'hidden' }}>
              {monthGrid(anchor).map((k) => {
                const inMonth = k.slice(0, 7) === anchor.slice(0, 7);
                return (
                  <div key={k} style={{ borderRight: `1px solid ${c.sep}`, borderBottom: `1px solid ${c.sep}`, padding: 6, display: 'flex', flexDirection: 'column', gap: 3, minWidth: 0, overflow: 'hidden', opacity: inMonth ? 1 : 0.4 }}>
                    <button type="button" aria-label={fmtDay(k, lang, { day: 'numeric', month: 'long' })} onClick={() => goDay(k)} style={{ ...BTN, alignSelf: 'flex-end', width: 28, height: 28, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15, background: k === today ? RED : 'transparent', color: k === today ? '#fff' : c.fg }}>{Number(k.slice(8))}</button>
                    {eventsOn(events, k, hidden).slice(0, 3).map((e) => {
                      const s = shades(e.color || DEFAULT_COLOR);
                      return <button type="button" key={e.id} onClick={() => open(e, k)} style={{ ...BTN, borderRadius: 5, padding: '2px 6px', fontSize: 12, fontWeight: 600, background: s.bg, color: s.fg, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{e.title}</button>;
                    })}
                  </div>
                );
              })}
            </div>
          </>
        ) : null}

        {view === 'year' ? (
          <div style={{ flexGrow: 1, overflowY: 'auto', display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 20, padding: '10px 28px 30px' }}>
            {Array.from({ length: 12 }, (_, mi) => {
              const first = `${anchor.slice(0, 4)}-${String(mi + 1).padStart(2, '0')}-01`;
              const current = today.slice(0, 7) === first.slice(0, 7);
              return (
                <button type="button" key={first} onClick={() => { setAnchor(first); setView('month'); setMini(first); }} style={{ ...BTN, display: 'flex', flexDirection: 'column', gap: 6 }}>
                  <span style={{ fontSize: 18, fontWeight: 700, color: current ? RED : c.fg, textTransform: 'capitalize' }}>{fmtDay(first, lang, { month: 'long' })}</span>
                  <span style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', rowGap: 3, textAlign: 'center', fontSize: 11 }}>
                    {monthGrid(first).map((k) => {
                      const inMonth = k.slice(0, 7) === first.slice(0, 7);
                      return <span key={k} style={{ width: 20, height: 20, lineHeight: '20px', borderRadius: '50%', background: k === today ? RED : 'transparent', color: k === today ? '#fff' : c.fg }}>{inMonth ? Number(k.slice(8)) : ''}</span>;
                    })}
                  </span>
                </button>
              );
            })}
          </div>
        ) : null}

        {selEv && sel ? (
          <>
            <div onClick={() => setSel(null)} style={{ position: 'absolute', inset: 0 }} />
            <Glass style={{ position: 'absolute', left: '50%', top: 170, marginLeft: -190, width: 380, borderRadius: 22, padding: 22, boxSizing: 'border-box', display: 'flex', flexDirection: 'column', gap: 10 }}>
              <span style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
                <span style={{ width: 6, alignSelf: 'stretch', borderRadius: 3, background: selEv.color || DEFAULT_COLOR }} />
                <span style={{ display: 'flex', flexDirection: 'column', gap: 2, flexGrow: 1 }}>
                  <span style={{ fontSize: 22, fontWeight: 700 }}>{selEv.title}</span>
                  <span style={{ fontSize: 16, color: c.sub }}>{fmtDay(sel.day, lang, { day: 'numeric', month: 'numeric', year: 'numeric' })} · {selEv.allDay ? t('cal.all_day') : `${timePart(selEv.start)} – ${timePart(selEv.stop)}`}</span>
                </span>
              </span>
              {selEv.place ? <span style={{ fontSize: 16 }}>{selEv.place}</span> : null}
              <span style={{ fontSize: 15, color: c.sub }}>{t('cal.calendar_of', t(calOf(selEv.color).key))}</span>
              {selEv.notes ? <span style={{ fontSize: 15, color: c.sub }}>{selEv.notes}</span> : null}
              <span style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 0 0' }}>
                <button type="button" onClick={() => void remove()} style={{ ...BTN, fontSize: 16, fontWeight: 600, color: RED }}>{t('cal.delete')}</button>
                <button type="button" onClick={() => startDraft(selEv)} style={{ ...BTN, fontSize: 16, fontWeight: 600, color: '#0088ff' }}>{t('cal.edit')}</button>
                <button type="button" onClick={() => setSel(null)} style={{ ...BTN, fontSize: 16, fontWeight: 600, color: '#0088ff' }}>{t('cal.close')}</button>
              </span>
            </Glass>
          </>
        ) : null}
      </main>

      <Sheet open={draft !== null} onClose={() => { setDraft(null); setError(''); }} title={draft?.id === null ? t('cal.new_event') : t('cal.edit_event')}>
        {draft ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <input aria-label={t('cal.title')} placeholder={t('cal.title')} maxLength={80} value={draft.title} onChange={(e) => setDraft({ ...draft, title: e.target.value })} style={{ all: 'unset', height: 44, padding: '0 14px', borderRadius: 12, background: c.fill, color: c.fg, fontSize: 17 }} />
            <input aria-label={t('cal.place')} placeholder={t('cal.place')} maxLength={80} value={draft.place} onChange={(e) => setDraft({ ...draft, place: e.target.value })} style={{ all: 'unset', height: 44, padding: '0 14px', borderRadius: 12, background: c.fill, color: c.fg, fontSize: 17 }} />
            <label style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 16 }}>
              <input type="checkbox" checked={draft.allDay} onChange={(e) => setDraft({ ...draft, allDay: e.target.checked })} />{t('cal.all_day')}
            </label>
            <div style={{ display: 'flex', gap: 10 }}>
              <input aria-label={t('cal.date')} type="date" value={draft.date} onChange={(e) => setDraft({ ...draft, date: e.target.value })} style={{ height: 40, borderRadius: 10, border: 'none', background: c.fill, color: c.fg, padding: '0 8px' }} />
              {!draft.allDay ? <input aria-label={t('cal.from')} type="time" value={draft.from} onChange={(e) => setDraft({ ...draft, from: e.target.value })} style={{ height: 40, borderRadius: 10, border: 'none', background: c.fill, color: c.fg, padding: '0 8px' }} /> : null}
              {!draft.allDay ? <input aria-label={t('cal.to')} type="time" value={draft.to} onChange={(e) => setDraft({ ...draft, to: e.target.value })} style={{ height: 40, borderRadius: 10, border: 'none', background: c.fill, color: c.fg, padding: '0 8px' }} /> : null}
            </div>
            <label style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 16 }}>{t('cal.alert')}
              <select aria-label={t('cal.alert')} value={draft.alert === null ? '' : String(draft.alert)} onChange={(e) => setDraft({ ...draft, alert: e.target.value === '' ? null : Number(e.target.value) })} style={{ height: 40, borderRadius: 10, border: 'none', background: c.fill, color: c.fg, padding: '0 8px' }}>
                {ALERTS.map((a) => <option key={String(a)} value={a === null ? '' : String(a)}>{a === null ? t('cal.alert_none') : a === 0 ? t('cal.alert_at_start') : t('cal.alert_before', a >= 1440 ? `${a / 1440} d` : a >= 60 ? `${a / 60} h` : `${a} min`)}</option>)}
              </select>
            </label>
            <div style={{ display: 'flex', gap: 10 }}>
              {CALS.map((k) => <button type="button" key={k.id} aria-label={t(k.key)} aria-pressed={draft.color === k.color} onClick={() => setDraft({ ...draft, color: k.color })} style={{ ...BTN, width: 34, height: 34, borderRadius: '50%', background: k.color, outline: draft.color === k.color ? `3px solid ${c.fg}` : 'none', outlineOffset: 2 }} />)}
            </div>
            <textarea aria-label={t('cal.notes')} placeholder={t('cal.notes')} maxLength={500} value={draft.notes} onChange={(e) => setDraft({ ...draft, notes: e.target.value })} style={{ minHeight: 70, borderRadius: 12, border: 'none', background: c.fill, color: c.fg, padding: 12, fontSize: 16, resize: 'none' }} />
            <button type="button" onClick={() => void save()} style={{ ...BTN, height: 46, borderRadius: 23, background: RED, color: '#fff', textAlign: 'center', lineHeight: '46px', fontSize: 17, fontWeight: 600 }}>{t('cal.save')}</button>
          </div>
        ) : null}
      </Sheet>
    </div>
  );
}

