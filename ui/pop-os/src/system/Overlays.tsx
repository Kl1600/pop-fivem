import { AnimatePresence, m } from 'motion/react';
import { useEffect, useRef, useState, type PointerEvent as RPointerEvent } from 'react';
import { AppIcon, BlurLayer, Glass, useT } from '../kit';
import { getApp } from '../apps/registry';
import { nuiApi } from '../nui/bridge';
import { formatDate, formatTime, useGameDate } from './clock';
import { clearNotifs, closeOverlays, openApp, removeRecent, setSetting, setVolume } from './actions';
import { relTime } from './format';
import { originOf } from './Home';
import { useOS } from './store';

const EASE = [0.2, 0.9, 0.25, 1.02] as const;
const fadeT = { duration: 0.3 };

// ---------- Centre de notifications ----------
export function NotificationCenter() {
  const t = useT();
  const open = useOS((s) => s.nc);
  const lang = useOS((s) => s.lang);
  const notifs = useOS((s) => s.notifs);
  const [expanded, setExpanded] = useState<Record<string, boolean>>({});
  const d = useGameDate();
  const groups: Array<{ app: string; items: typeof notifs }> = [];
  for (const n of notifs) {
    const g = groups.find((x) => x.app === n.app);
    if (g) g.items.push(n); else groups.push({ app: n.app, items: [n] });
  }
  return (
    <AnimatePresence>
      {open && (
        <m.div key="nc" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={fadeT} style={{ position: 'absolute', inset: 0, zIndex: 7 }}>
          <BlurLayer style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,.18)', WebkitBackdropFilter: 'blur(36px) saturate(160%)', backdropFilter: 'blur(36px) saturate(160%)' }} onClick={closeOverlays}>
            <m.div initial={{ y: -60 }} animate={{ y: 0 }} exit={{ y: -60 }} transition={{ duration: 0.55, ease: EASE }} style={{ position: 'absolute', inset: 0 }}>
              <div style={{ position: 'absolute', top: 70, left: 0, right: 0, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                <span style={{ fontSize: 24, fontWeight: 600 }}>{formatDate(d, lang, 'long')}</span>
                <span dir="ltr" style={{ fontSize: 120, fontWeight: 700, letterSpacing: -4, lineHeight: 1, color: 'rgba(255,255,255,.88)' }}>{formatTime(d)}</span>
              </div>
              <div onClick={(e) => e.stopPropagation()} style={{ position: 'absolute', top: 330, left: '50%', marginLeft: -280, width: 560, display: 'flex', flexDirection: 'column', gap: 10 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 4px' }}>
                  <span style={{ fontSize: 22, fontWeight: 700 }}>{t('nc.title')}</span>
                  <Glass kind="gw" as="button" aria-label={t('nc.clear')} onClick={clearNotifs} style={{ width: 30, height: 30, borderRadius: '50%', textAlign: 'center', lineHeight: '30px', fontSize: 16, fontWeight: 700, background: 'rgba(255,255,255,.2)' }}>✕</Glass>
                </div>
                {groups.length === 0 && <span style={{ textAlign: 'center', opacity: 0.7, fontSize: 17, padding: 30 }}>{t('nc.empty')}</span>}
                {groups.map((g) => {
                  const ex = !!expanded[g.app];
                  const shown = ex ? g.items : g.items.slice(0, 1);
                  const stacked = !ex && g.items.length > 1;
                  return (
                    <button key={g.app} onClick={() => setExpanded((m) => ({ ...m, [g.app]: !ex }))} style={{ display: 'flex', flexDirection: 'column', gap: 8, textAlign: 'start' }}>
                      {shown.map((n) => (
                        <Glass key={n.id} kind="gw" style={{ borderRadius: 26, padding: '14px 16px', display: 'flex', gap: 12, alignItems: 'center' }}>
                          <AppIcon appId={g.app} size={40} />
                          <span style={{ display: 'flex', flexDirection: 'column', flexGrow: 1 }}>
                            <span style={{ display: 'flex', justifyContent: 'space-between', fontSize: 15, fontWeight: 600 }}><span>{n.title}</span><span style={{ fontWeight: 400, opacity: 0.7, fontSize: 13 }}>{relTime(n.at, Date.now(), t)}</span></span>
                            <span style={{ fontSize: 15, opacity: 0.92 }}>{n.body}</span>
                          </span>
                        </Glass>
                      ))}
                      {stacked && <span aria-hidden="true" style={{ display: 'block', margin: '-14px 14px 0', height: 12, borderRadius: '0 0 18px 18px', background: 'rgba(255,255,255,.22)' }} />}
                      {stacked && <span style={{ fontSize: 13, opacity: 0.75, paddingInlineStart: 16 }}>{g.items.length - 1 === 1 ? t('nc.more_one') : t('nc.more_many', g.items.length - 1)}</span>}
                    </button>
                  );
                })}
              </div>
            </m.div>
          </BlurLayer>
        </m.div>
      )}
    </AnimatePresence>
  );
}

// ---------- Centre de contrôle ----------
const P = {
  air: 'M2 16l8-3V5a2 2 0 0 1 4 0v8l8 3v2l-8-2v4l2 2h-8l2-2v-4l-8 2z',
  wifi: 'M2 9a15 15 0 0 1 20 0M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0M12 19.5h.01',
  bt: 'M7 7l10 10-5 4V3l5 4L7 17',
  share: 'M12 13a2 2 0 1 0 0-.1M8 17a6 6 0 1 1 8 0M5 20a10 10 0 1 1 14 0',
  rot: 'M12 4a8 8 0 1 0 8 8M20 4v5h-5M10 11h4v5h-4zM11 11V9.5a1 1 0 0 1 2 0V11',
  mirror: 'M3 5h18v11H3zM8 21h8M12 16v5',
  dark: 'M12 3v18M12 3a9 9 0 0 1 0 18',
  timer: 'M12 8v5l3 2M9 2h6M12 4a9 9 0 1 0 0 18 9 9 0 0 0 0-18z',
  calc: 'M6 3h12v18H6zM9 7h6M9 12h.01M12 12h.01M15 12h.01M9 16h.01M12 16h.01M15 16h.01',
  cam: 'M3 8h4l2-3h6l2 3h4v12H3zM12 11a3 3 0 1 0 0 6 3 3 0 0 0 0-6z',
  note: 'M5 4h10l4 4v12H5zM9 12h6M9 16h4',
  rec: 'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z',
  moon: 'M20 14.5A8.5 8.5 0 1 1 9.5 4a7 7 0 0 0 10.5 10.5z',
  sun: 'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.5 1.5M17.5 17.5 19 19M5 19l1.5-1.5M17.5 6.5 19 5',
  vol: 'M4 9h4l5-4v14l-5-4H4zM17 9a4 4 0 0 1 0 6',
};

function Ico({ d, size, stroke = '#fff' }: { d: string; size: number; stroke?: string }) {
  return <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={stroke} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>;
}

function VSlider({ value, onChange, label, path, min = 0 }: { value: number; onChange: (v: number) => void; label: string; path: string; min?: number }) {
  const drag = (e: RPointerEvent<HTMLDivElement>) => {
    if (e.type === 'pointermove' && !e.buttons) return;
    const r = e.currentTarget.getBoundingClientRect();
    if (!r.height) return;
    onChange(Math.max(min, Math.round(Math.max(0, Math.min(1, (r.bottom - e.clientY) / r.height)) * 100)));
  };
  return (
    <Glass kind="gw" style={{ height: '100%', borderRadius: 34 }}>
      <div role="slider" tabIndex={0} aria-label={label} aria-valuemin={min} aria-valuemax={100} aria-valuenow={value} onPointerDown={drag} onPointerMove={drag} onKeyDown={(e) => { if (e.key === 'ArrowUp') onChange(Math.min(100, value + 5)); if (e.key === 'ArrowDown') onChange(Math.max(min, value - 5)); }} style={{ position: 'absolute', inset: 0, borderRadius: 34, overflow: 'hidden', cursor: 'ns-resize', touchAction: 'none' }}>
        <span style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: `${value}%`, background: '#fff' }} />
        <span style={{ position: 'absolute', bottom: 18, left: 34 }}><Ico d={path} size={28} stroke={value > 18 ? '#8e8e93' : '#fff'} /></span>
      </div>
    </Glass>
  );
}

export function ControlCenter() {
  const t = useT();
  const open = useOS((s) => s.cc);
  const st = useOS((s) => s.settings);
  const vol = useOS((s) => s.vol);
  const music = useOS((s) => s.boot?.music ?? null);
  const dark = st.dark === true;
  const on = (v: boolean | undefined, c: string) => (v ? c : 'rgba(255,255,255,.18)');
  const conn: Array<{ name: string; d: string; bg: string; toggle: () => void; pressed: boolean }> = [
    { name: t('cc.airplane'), d: P.air, bg: on(st.air, '#ff8d28'), toggle: () => setSetting({ air: !st.air }), pressed: st.air === true },
    { name: t('cc.wifi'), d: P.wifi, bg: on(st.wifi !== false && !st.air, '#0088ff'), toggle: () => setSetting({ wifi: st.wifi === false }), pressed: st.wifi !== false && !st.air },
    { name: t('cc.bluetooth'), d: P.bt, bg: on(st.bt, '#0088ff'), toggle: () => setSetting({ bt: !st.bt }), pressed: st.bt === true },
    { name: t('cc.share'), d: P.share, bg: on(st.share, '#0088ff'), toggle: () => setSetting({ share: !st.share }), pressed: st.share === true },
  ];
  const openFrom = (id: string) => (e: React.MouseEvent) => openApp(id, originOf(e.currentTarget));
  const record = async () => {
    await nuiApi.call('photos:capture');
    closeOverlays();
  };
  const tiles: Array<{ name: string; d: string; bg: string; fg: string; act: (e: React.MouseEvent) => void }> = [
    { name: t('cc.rotation'), d: P.rot, bg: st.rot ? '#fff' : 'rgba(255,255,255,.18)', fg: st.rot ? '#ff383c' : '#fff', act: () => setSetting({ rot: !st.rot }) },
    { name: t('cc.mirror'), d: P.mirror, bg: st.mirror ? '#fff' : 'rgba(255,255,255,.18)', fg: st.mirror ? '#000' : '#fff', act: () => setSetting({ mirror: !st.mirror }) },
    { name: t('cc.dark'), d: P.dark, bg: dark ? '#fff' : 'rgba(255,255,255,.18)', fg: dark ? '#000' : '#fff', act: () => setSetting({ dark: !dark }) },
    { name: t('cc.timer'), d: P.timer, bg: 'rgba(255,255,255,.18)', fg: '#fff', act: openFrom('horloge') },
    { name: t('cc.calc'), d: P.calc, bg: 'rgba(255,255,255,.18)', fg: '#fff', act: openFrom('calculette') },
    { name: t('cc.camera'), d: P.cam, bg: 'rgba(255,255,255,.18)', fg: '#fff', act: openFrom('camera') },
    { name: t('cc.quick_notes'), d: P.note, bg: 'rgba(255,255,255,.18)', fg: '#fff', act: openFrom('notes') },
    { name: t('cc.record'), d: P.rec, bg: 'rgba(255,255,255,.18)', fg: '#fff', act: () => void record() },
  ];
  return (
    <AnimatePresence>
      {open && (
        <m.div key="cc" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={fadeT} style={{ position: 'absolute', inset: 0, zIndex: 7 }}>
          <BlurLayer onClick={closeOverlays} style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,.28)', WebkitBackdropFilter: 'blur(30px) saturate(150%)', backdropFilter: 'blur(30px) saturate(150%)' }}>
            <m.div initial={{ scale: 0.9 }} animate={{ scale: 1 }} exit={{ scale: 0.9 }} transition={{ duration: 0.55, ease: EASE }} onClick={(e) => e.stopPropagation()} style={{ position: 'absolute', top: 76, insetInlineEnd: 60, display: 'grid', gridTemplateColumns: 'repeat(4, 96px)', gridAutoRows: '96px', gap: 18, transformOrigin: 'top right' }}>
              <Glass kind="gw" style={{ gridColumn: 'span 2', gridRow: 'span 2', borderRadius: 34, display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', placeItems: 'center', padding: 14 }}>
                {conn.map((c) => (
                  <button key={c.name} aria-label={c.name} aria-pressed={c.pressed} onClick={c.toggle} style={{ width: 66, height: 66, borderRadius: '50%', background: c.bg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d={c.d} size={30} /></button>
                ))}
              </Glass>
              <Glass kind="gw" style={{ gridColumn: 'span 2', gridRow: 'span 2', borderRadius: 34, padding: 20, display: 'flex', flexDirection: 'column' }}>
                <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                  <span style={{ width: 58, height: 58, borderRadius: 12, background: 'linear-gradient(135deg,#ff2e88,#7a2bff)', flexShrink: 0 }} />
                  <span style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}>
                    <span style={{ fontSize: 15, fontWeight: 600 }}>{music ? music.title : t('cc.nothing_playing')}</span>
                    <span style={{ fontSize: 14, opacity: 0.7 }}>{music ? music.artist : ''}</span>
                  </span>
                </div>
                <div style={{ flexGrow: 1 }} />
                <button aria-label={t('app.musique')} onClick={openFrom('musique')} style={{ alignSelf: 'center', fontSize: 15, fontWeight: 600, opacity: 0.9 }}>{t('cc.open_music')}</button>
              </Glass>
              <Glass kind="gw" style={{ gridColumn: 'span 2', borderRadius: 34, display: 'flex', alignItems: 'center', gap: 12, padding: '0 18px' }}>
                <span style={{ width: 44, height: 44, borderRadius: '50%', background: st.focus ? '#5e5ce6' : 'rgba(255,255,255,.18)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d={P.moon} size={22} /></span>
                <button aria-pressed={st.focus === true} onClick={() => setSetting({ focus: !st.focus })} style={{ fontSize: 16, fontWeight: 600 }}>{st.focus ? t('cc.dnd') : t('cc.focus')}</button>
              </Glass>
              <div style={{ gridRow: 'span 2', position: 'relative' }}><VSlider value={st.bright ?? 100} min={15} onChange={(v) => setSetting({ bright: v })} label={t('cc.brightness')} path={P.sun} /></div>
              <div style={{ gridRow: 'span 2', position: 'relative' }}><VSlider value={vol} onChange={setVolume} label={t('cc.volume')} path={P.vol} /></div>
              {tiles.map((x) => (
                <Glass key={x.name} kind="gw" as="button" aria-label={x.name} className="cc" onClick={x.act} style={{ borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', background: x.bg }}><Ico d={x.d} size={32} stroke={x.fg} /></Glass>
              ))}
            </m.div>
          </BlurLayer>
        </m.div>
      )}
    </AnimatePresence>
  );
}

// ---------- Recherche ----------
interface Hit { id: string | number; title: string; sub?: string }

export function SearchOverlay() {
  const t = useT();
  const open = useOS((s) => s.search);
  const apps = useOS((s) => s.apps);
  const [q, setQ] = useState('');
  const [contacts, setContacts] = useState<Hit[]>([]);
  const [notes, setNotes] = useState<Hit[]>([]);
  const ref = useRef<HTMLInputElement>(null);
  const query = q.trim().toLowerCase();

  useEffect(() => { if (open) ref.current?.focus(); else { setQ(''); setContacts([]); setNotes([]); } }, [open]);
  // Contacts et notes : deux appels après une courte pause de frappe, seulement tant que la recherche est ouverte.
  useEffect(() => {
    if (!open || query.length < 2) { setContacts([]); setNotes([]); return; }
    let alive = true;
    const id = setTimeout(() => {
      void nuiApi.call<{ ok: boolean; items?: Array<{ id: number; name?: string; phone?: string; title?: string; excerpt?: string }> }>('contacts:list').then((r) => {
        if (alive && r.ok) setContacts((r.items ?? []).filter((c) => (c.name ?? '').toLowerCase().includes(query)).map((c) => ({ id: c.id, title: c.name ?? '', sub: c.phone })).slice(0, 5));
      });
      void nuiApi.call<{ ok: boolean; notes?: Array<{ id: number; title?: string; excerpt?: string; deleted?: boolean }> }>('notes:list').then((r) => {
        if (alive && r.ok) setNotes((r.notes ?? []).filter((n) => !n.deleted && (n.title ?? '').toLowerCase().includes(query)).map((n) => ({ id: n.id, title: n.title ?? '', sub: n.excerpt })).slice(0, 5));
      });
    }, 250);
    return () => { alive = false; clearTimeout(id); };
  }, [open, query]);

  const nameOf = (id: string) => t(getApp(id)?.nameKey ?? `app.${id}`);
  const installed = apps.filter((id) => getApp(id));
  const list = (query ? installed.filter((id) => nameOf(id).toLowerCase().includes(query)) : ['messages', 'notes', 'reglages', 'photos', 'calendrier', 'boutique'].filter((id) => installed.includes(id))).slice(0, 12);
  return (
    <AnimatePresence>
      {open && (
        <m.div key="sr" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={fadeT} style={{ position: 'absolute', inset: 0, zIndex: 7 }}>
          <BlurLayer onClick={closeOverlays} style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,.2)', WebkitBackdropFilter: 'blur(34px) saturate(160%)', backdropFilter: 'blur(34px) saturate(160%)' }}>
            <m.div initial={{ y: -30 }} animate={{ y: 0 }} exit={{ y: -30 }} transition={{ duration: 0.55, ease: EASE }} onClick={(e) => e.stopPropagation()} style={{ position: 'absolute', top: 90, left: '50%', marginLeft: -330, width: 660, display: 'flex', flexDirection: 'column', gap: 22 }}>
              <Glass kind="g" as="label" style={{ height: 54, borderRadius: 27, display: 'flex', alignItems: 'center', gap: 12, padding: '0 20px' }}>
                <svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round"><circle cx="11" cy="11" r="7" /><path d="M20 20l-4-4" /></svg>
                <input ref={ref} aria-label={t('search.placeholder')} placeholder={t('search.placeholder')} value={q} maxLength={60} onChange={(e) => setQ(e.target.value)} style={{ flexGrow: 1, fontSize: 18, color: 'inherit' }} />
              </Glass>
              <span style={{ fontSize: 15, fontWeight: 600, opacity: 0.8, paddingInlineStart: 8 }}>{query ? t('search.results') : t('search.suggestions')}</span>
              <Glass kind="g" style={{ borderRadius: 30, padding: 22, display: 'grid', gridTemplateColumns: 'repeat(6, minmax(0, 1fr))', rowGap: 20 }}>
                {list.map((id) => (
                  <button key={id} onClick={(e) => openApp(id, originOf(e.currentTarget))} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, fontSize: 13 }}><AppIcon appId={id} size={70} />{nameOf(id)}</button>
                ))}
                {list.length === 0 && contacts.length === 0 && notes.length === 0 && query && <span style={{ gridColumn: '1 / -1', textAlign: 'center', opacity: 0.8 }}>{t('search.none')}</span>}
              </Glass>
              {[{ k: 'app.contacts', items: contacts, app: 'contacts' }, { k: 'app.notes', items: notes, app: 'notes' }].map((g) => g.items.length > 0 && (
                <Glass key={g.k} kind="g" style={{ borderRadius: 24, padding: '10px 18px' }}>
                  <div style={{ fontSize: 13, fontWeight: 600, opacity: 0.8, padding: '6px 0' }}>{t(g.k)}</div>
                  {g.items.map((h) => (
                    <button key={h.id} onClick={(e) => openApp(g.app, originOf(e.currentTarget))} style={{ display: 'flex', width: '100%', justifyContent: 'space-between', padding: '8px 0', fontSize: 16 }}><span>{h.title}</span><span style={{ opacity: 0.7 }}>{h.sub}</span></button>
                  ))}
                </Glass>
              ))}
            </m.div>
          </BlurLayer>
        </m.div>
      )}
    </AnimatePresence>
  );
}

// ---------- Sélecteur d'applis ----------
export function Switcher() {
  const t = useT();
  const open = useOS((s) => s.sw);
  const recents = useOS((s) => s.recents);
  const dark = useOS((s) => s.settings.dark === true);
  const startY = useRef<number | null>(null);
  const dragged = useRef(false);
  return (
    <AnimatePresence>
      {open && (
        <m.div key="sw" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={fadeT} style={{ position: 'absolute', inset: 0, zIndex: 7 }}>
          <BlurLayer onClick={closeOverlays} style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,.3)', WebkitBackdropFilter: 'blur(30px)', backdropFilter: 'blur(30px)' }}>
            <div style={{ position: 'absolute', top: 300, left: 0, right: 0, display: 'flex', justifyContent: 'center', gap: 46, pointerEvents: 'none' }}>
              {recents.length === 0 && <span style={{ fontSize: 18, opacity: 0.8 }}>{t('sw.empty')}</span>}
              {recents.map((id) => (
                <div key={id} style={{ display: 'flex', flexDirection: 'column', gap: 12, pointerEvents: 'auto' }} onClick={(e) => e.stopPropagation()}>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 16, fontWeight: 600 }}><AppIcon appId={id} size={34} />{t(getApp(id)?.nameKey ?? `app.${id}`)}</span>
                  <button
                    onClick={(e) => { if (dragged.current) { dragged.current = false; return; } openApp(id, originOf(e.currentTarget)); }}
                    onPointerDown={(e) => { startY.current = e.clientY; }}
                    onPointerUp={(e) => { if (startY.current !== null && startY.current - e.clientY > 60) { dragged.current = true; removeRecent(id); } startY.current = null; }}
                    style={{ cursor: 'grab', width: 360, height: 272, borderRadius: 22, background: dark ? '#1c1c1e' : '#f2f2f7', boxShadow: '0 20px 50px rgba(0,0,0,.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', touchAction: 'none' }}
                  ><AppIcon appId={id} size={90} dark={dark} /></button>
                  <span style={{ textAlign: 'center', fontSize: 12, opacity: 0.7 }}>{t('sw.close_hint')}</span>
                </div>
              ))}
            </div>
          </BlurLayer>
        </m.div>
      )}
    </AnimatePresence>
  );
}
