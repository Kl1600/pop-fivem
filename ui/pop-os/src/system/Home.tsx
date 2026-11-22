import { useRef, useState, type PointerEvent as RPointerEvent } from 'react';
import { AppIcon, Glass, useT } from '../kit';
import { getApp } from '../apps/registry';
import { useGameDate, weekdayLong } from './clock';
import { openApp, removeApp, toggleOverlay } from './actions';
import { nuiApi } from '../nui/bridge';
import { DOCK, os, useOS } from './store';


/** Position du centre d'un élément dans le repère de l'écran 1348 x 1019 (indépendant du zoom). */
export function originOf(el: Element): { x: number; y: number } {
  const scr = el.closest('[data-screen]');
  if (!scr) return { x: 674, y: 509 };
  const r = scr.getBoundingClientRect();
  const k = r.width / 1348 || 1;
  const b = el.getBoundingClientRect();
  return { x: (b.left + b.width / 2 - r.left) / k, y: (b.top + b.height / 2 - r.top) / k };
}

const PAGE_SIZE = 16;
const SYSTEM_APPS = new Set(['reglages', 'boutique']);

function WeatherWidget() {
  const t = useT();
  const w = useOS((s) => s.weather);
  return (
    <div style={{ width: 270, height: 270, borderRadius: 34, padding: '20px 22px', background: 'linear-gradient(180deg,#3d8cf0,#2a6fd8)', boxShadow: 'inset 0 1px 0 rgba(255,255,255,.4), 0 10px 30px rgba(0,0,0,.15)', display: 'flex', flexDirection: 'column', color: '#fff' }}>
      <span style={{ fontSize: 17, fontWeight: 600 }}>{w?.city ?? t('widget.city')} ➤</span>
      <span style={{ fontSize: 64, fontWeight: 300, lineHeight: 1.05, letterSpacing: -2 }}>{w ? `${Math.round(w.temp)}°` : '–'}</span>
      <div style={{ flexGrow: 1 }} />
      <svg aria-hidden="true" width="34" height="34" viewBox="0 0 24 24" fill="#ffd60a"><circle cx="12" cy="12" r="5" /><path d="M12 1v3M12 20v3M1 12h3M20 12h3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1" stroke="#ffd60a" strokeWidth="2" strokeLinecap="round" /></svg>
      <span style={{ fontSize: 16, fontWeight: 600, marginTop: 6 }}>{w ? t(`weather.${w.kind}`) : ''}</span>
      <span style={{ fontSize: 16, fontWeight: 500, opacity: 0.9 }}>{w && w.hi !== undefined && w.lo !== undefined ? t('widget.high_low', Math.round(w.hi), Math.round(w.lo)) : ''}</span>
    </div>
  );
}

function CalendarWidget() {
  const t = useT();
  const lang = useOS((s) => s.lang);
  const events = useOS((s) => s.boot?.widgets?.events);
  const d = useGameDate();
  return (
    <Glass kind="wg" style={{ width: 270, height: 270, borderRadius: 34, padding: '20px 22px', display: 'flex', flexDirection: 'column', gap: 4 }}>
      <span style={{ fontSize: 14, fontWeight: 700, color: '#ff383c', letterSpacing: 0.5, textTransform: 'uppercase' }}>{weekdayLong(d, lang)}</span>
      <span style={{ fontSize: 52, fontWeight: 400, lineHeight: 1, letterSpacing: -1 }}>{d.getUTCDate()}</span>
      <div style={{ flexGrow: 1 }} />
      {(events ?? []).slice(0, 2).map((e, i) => (
        <div key={i} style={{ display: 'flex', gap: 8, marginTop: i ? 8 : 0 }}>
          <span style={{ width: 4, borderRadius: 2, background: e.color ?? '#0088ff' }} />
          <span style={{ display: 'flex', flexDirection: 'column' }}><span style={{ fontSize: 15, fontWeight: 600 }}>{e.title}</span><span className="sub" style={{ fontSize: 14 }}>{e.time}</span></span>
        </div>
      ))}
      {!events?.length && <span className="sub" style={{ fontSize: 14 }}>{t('widget.no_event')}</span>}
    </Glass>
  );
}

function RemindersWidget() {
  const t = useT();
  const list = useOS((s) => s.boot?.widgets?.reminders);
  const [done, setDone] = useState<Record<string, boolean>>({});
  const items = (list ?? []).map((r) => ({ ...r, done: done[String(r.id)] ?? r.done }));
  const left = items.filter((r) => !r.done).length;
  const toggle = (id: string | number, cur: boolean) => {
    setDone((m) => ({ ...m, [String(id)]: !cur }));
    void nuiApi.call('reminders:toggle', { id });
  };
  return (
    <Glass kind="wg" style={{ width: 580, height: 270, borderRadius: 34, padding: '20px 24px', display: 'flex', gap: 24 }}>
      <div style={{ width: 150, display: 'flex', flexDirection: 'column' }}>
        <span style={{ width: 44, height: 44, borderRadius: '50%', background: '#ff8d28', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <svg aria-hidden="true" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.4" strokeLinecap="round"><path d="M9 6h11M9 12h11M9 18h11" /><circle cx="4" cy="6" r="1.3" fill="#fff" /><circle cx="4" cy="12" r="1.3" fill="#fff" /><circle cx="4" cy="18" r="1.3" fill="#fff" /></svg>
        </span>
        <div style={{ flexGrow: 1 }} />
        <span style={{ fontSize: 44, fontWeight: 600, lineHeight: 1 }}>{left}</span>
        <span style={{ fontSize: 17, fontWeight: 600, color: '#ff8d28' }}>{t('app.rappels')}</span>
      </div>
      <div style={{ flexGrow: 1, minWidth: 0, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 14 }}>
        {items.slice(0, 4).map((r) => (
          <button key={r.id} onClick={() => toggle(r.id, r.done)} style={{ display: 'flex', alignItems: 'center', gap: 12, fontSize: 16 }}>
            <span style={{ width: 22, height: 22, borderRadius: '50%', border: `2px solid ${r.done ? '#ff8d28' : 'rgba(60,60,67,.35)'}`, background: r.done ? '#ff8d28' : 'transparent', flexShrink: 0 }} />
            <span style={{ opacity: r.done ? 0.45 : 1, textDecoration: r.done ? 'line-through' : 'none', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.text}</span>
          </button>
        ))}
        {!items.length && <span className="sub" style={{ fontSize: 16 }}>{t('widget.no_reminder')}</span>}
      </div>
    </Glass>
  );
}

export function HomeLayer({ active, appVisible, overlay, hidden = false }: { active: boolean; appVisible: boolean; overlay: boolean; hidden?: boolean }) {
  const t = useT();
  const dark = useOS((s) => s.settings.dark === true);
  const apps = useOS((s) => s.apps);
  const edit = useOS((s) => s.edit);
  const badges = useOS((s) => s.badges);
  const recents = useOS((s) => s.recents);
  const rtl = useOS((s) => s.rtl);
  const [page, setPage] = useState(0);
  const press = useRef<ReturnType<typeof setTimeout> | null>(null);
  const fired = useRef(false);
  const swipeX = useRef<number | null>(null);

  const installed = apps.filter((id) => getApp(id));
  const dock = DOCK.filter((id) => installed.includes(id));
  const grid = installed.filter((id) => !DOCK.includes(id));
  const pages = Math.max(1, Math.ceil(grid.length / PAGE_SIZE));
  const cur = Math.min(page, pages - 1);
  const recentsDock = recents.filter((id) => !dock.includes(id) && getApp(id)).slice(0, 2);
  const name = (id: string) => t(getApp(id)?.nameKey ?? `app.${id}`);
  const open = (id: string, el: Element) => {
    if (fired.current) { fired.current = false; return; }
    openApp(id, originOf(el));
  };
  const down = (e: RPointerEvent) => {
    if (press.current) clearTimeout(press.current);
    press.current = setTimeout(() => { fired.current = true; os.set({ edit: true }); }, 550);
    swipeX.current = e.clientX;
  };
  const up = () => { if (press.current) clearTimeout(press.current); press.current = null; };
  const swipeEnd = (e: RPointerEvent) => {
    if (swipeX.current === null) return;
    const dx = e.clientX - swipeX.current;
    swipeX.current = null;
    if (Math.abs(dx) < 70) return;
    const forward = rtl ? dx > 0 : dx < 0;
    setPage((p) => Math.max(0, Math.min(pages - 1, p + (forward ? 1 : -1))));
    fired.current = true;
  };
  const badge = (id: string, size: number) => badges[id] ? (
    <span aria-label={String(badges[id])} style={{ position: 'absolute', top: -6, insetInlineEnd: -6, minWidth: size, height: size, borderRadius: size, padding: '0 6px', background: '#ff383c', color: '#fff', fontSize: 13, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 2px 6px rgba(0,0,0,.3)' }}>{badges[id]}</span>
  ) : null;

  return (
    <div className="tr" data-layer="home" aria-hidden={!active || appVisible || overlay} inert={!active || appVisible || overlay} style={{ position: 'absolute', inset: 0, visibility: hidden ? 'hidden' : 'visible', opacity: active ? 1 : 0, transform: active ? (appVisible ? 'scale(.92)' : 'none') : 'scale(1.12)', pointerEvents: active && !appVisible && !overlay ? 'auto' : 'none' }}>
      {edit && (
        <div style={{ position: 'absolute', top: 44, insetInline: 40, display: 'flex', justifyContent: 'flex-end', zIndex: 3 }}>
          <Glass kind="g" as="button" onClick={() => os.set({ edit: false })} style={{ padding: '9px 22px', borderRadius: 20, fontSize: 15, fontWeight: 600, color: dark ? '#fff' : '#000' }}>{t('home.done')}</Glass>
        </div>
      )}
      <div style={{ position: 'absolute', insetInlineStart: 70, top: 96, width: 580, display: 'flex', flexDirection: 'column', gap: 40 }}>
        <div style={{ display: 'flex', gap: 40 }}><WeatherWidget /><CalendarWidget /></div>
        <RemindersWidget />
      </div>

      <div onPointerUp={swipeEnd} style={{ position: 'absolute', left: rtl ? undefined : 700, right: rtl ? 700 : undefined, top: 100, width: 600, overflow: 'visible' }}>
        <div style={{ display: 'flex', width: 600, direction: 'ltr', transform: `translateX(${-cur * 600 * (rtl ? -1 : 1)}px)`, transition: 'transform .35s cubic-bezier(.2,.9,.25,1)' }}>
          {Array.from({ length: pages }, (_, p) => (
            <div key={p} style={{ width: 600, flexShrink: 0, display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', rowGap: 36, direction: rtl ? 'rtl' : 'ltr', alignContent: 'start', height: 640 }}>
              {grid.slice(p * PAGE_SIZE, (p + 1) * PAGE_SIZE).map((id, i) => (
                <div key={id} style={{ position: 'relative', display: 'flex', justifyContent: 'center' }}>
                  <button className={edit ? (i % 2 ? 'jig2' : 'jig') : ''} onClick={(e) => open(id, e.currentTarget)} onContextMenu={(e) => { e.preventDefault(); os.set({ edit: true }); }} onPointerDown={down} onPointerUp={up} onPointerLeave={up} style={{ position: 'relative', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, width: 120 }}>
                    <span style={{ position: 'relative', display: 'flex' }}><AppIcon appId={id} size={88} dark={dark} />{badge(id, 22)}</span>
                    <span style={{ fontSize: 13, fontWeight: 500, textShadow: '0 1px 6px rgba(0,0,0,.35)' }}>{name(id)}</span>
                  </button>
                  {edit && !SYSTEM_APPS.has(id) && (
                    <button aria-label={t('home.remove', name(id))} onClick={() => removeApp(id)} style={{ position: 'absolute', top: -8, insetInlineStart: 6, width: 26, height: 26, borderRadius: '50%', background: 'rgba(120,120,128,.85)', color: '#fff', fontSize: 20, fontWeight: 700, lineHeight: '24px', textAlign: 'center', boxShadow: '0 2px 6px rgba(0,0,0,.3)' }}>−</button>
                  )}
                </div>
              ))}
            </div>
          ))}
        </div>
      </div>
      {pages > 1 && (
        <div role="tablist" style={{ position: 'absolute', left: 700, width: 600, bottom: 196, display: 'flex', justifyContent: 'center', gap: 10 }}>
          {Array.from({ length: pages }, (_, p) => (
            <button key={p} role="tab" aria-selected={p === cur} aria-label={String(p + 1)} onClick={() => setPage(p)} style={{ width: 9, height: 9, borderRadius: '50%', background: p === cur ? '#fff' : 'rgba(255,255,255,.4)' }} />
          ))}
        </div>
      )}

      <Glass kind="g" as="button" onClick={() => toggleOverlay('search')} style={{ position: 'absolute', left: '50%', bottom: 150, transform: 'translateX(-50%)', padding: '8px 18px', borderRadius: 18, display: 'flex', gap: 8, alignItems: 'center', fontSize: 15, fontWeight: 600, color: dark ? '#fff' : '#000' }}>
        <svg aria-hidden="true" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round"><circle cx="11" cy="11" r="7" /><path d="M20 20l-4-4" /></svg>{t('home.search')}
      </Glass>

      <Glass kind="g" style={{ position: 'absolute', left: '50%', bottom: 24, transform: 'translateX(-50%)', padding: 13, borderRadius: 36, display: 'flex', alignItems: 'center', gap: 16 }}>
        {dock.map((id) => (
          <button key={id} aria-label={name(id)} onClick={(e) => open(id, e.currentTarget)} style={{ display: 'flex', position: 'relative' }}><AppIcon appId={id} size={76} dark={dark} />{badge(id, 22)}</button>
        ))}
        {recentsDock.length > 0 && <span style={{ width: 1, height: 60, background: dark ? 'rgba(255,255,255,.25)' : 'rgba(0,0,0,.15)' }} />}
        {recentsDock.map((id) => (
          <button key={id} aria-label={name(id)} onClick={(e) => open(id, e.currentTarget)} style={{ display: 'flex' }}><AppIcon appId={id} size={76} dark={dark} /></button>
        ))}
      </Glass>
    </div>
  );
}

