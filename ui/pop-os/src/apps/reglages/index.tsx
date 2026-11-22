import { useState } from 'react';
import { AppIcon, Button, Field, LANGUAGES, LANGUAGE_NAMES, ListRow, Slider, SplitView, Switch, WALLPAPERS, WALL_AUTO, palette, type AppProps } from '../../kit';

import { useSettings, type SettingsApi } from './store';

// Réglages : toutes les rubriques de la maquette qui ont une fonction réelle. Chaque réglage est appliqué tout de suite
// puis validé et enregistré par le serveur (`settings:save`). L'appli ne connaît que le kit.

type Pane = 'air' | 'wifi' | 'bt' | 'battery' | 'notif' | 'sounds' | 'focus' | 'general' | 'cc' | 'display' | 'access' | 'wall' | 'privacy' | 'code' | 'store';
interface Item { id: Pane; nameKey: string; color: string; d: string }

const D = {
  air: 'M2 16l8-3V5a2 2 0 0 1 4 0v8l8 3v2l-8-2v4l2 2h-8l2-2v-4l-8 2z', wifi: 'M2 9a15 15 0 0 1 20 0M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0',
  bt: 'M7 7l10 10-5 4V3l5 4L7 17', bat: 'M3 8h16v8H3zM21 11v2M6 11h6', bell: 'M6 16v-5a6 6 0 0 1 12 0v5l2 2H4zM10 21h4', sound: 'M4 9h4l5-4v14l-5-4H4zM16 9a4 4 0 0 1 0 6',
  moon: 'M20 14.5A8.5 8.5 0 1 1 9.5 4a7 7 0 0 0 10.5 10.5z', gear: 'M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6zM12 2v3M12 19v3M2 12h3M19 12h3',
  cc: 'M4 6h7v7H4zM13 6h7v7h-7zM4 15h16v4H4z', sun: 'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2v2M12 20v2M2 12h2M20 12h2',
  acc: 'M12 4a2 2 0 1 0 0 .1M5 8h14M12 8v6M9 21l3-7 3 7', wall: 'M3 5h18v14H3zM3 16l6-6 5 5 3-3 4 4', hand: 'M8 13V5a2 2 0 0 1 4 0v6M12 11V4a2 2 0 0 1 4 0v8M16 9a2 2 0 0 1 4 0v5a7 7 0 0 1-14 0v-3',
  lock: 'M5 11h14v10H5zM8 11V8a4 4 0 0 1 8 0v3', store: 'M6 7h12l-1 13H7L6 7zM9 7a3 3 0 0 1 6 0',
};
const it = (id: Pane, nameKey: string, color: string, d: string): Item => ({ id, nameKey, color, d });
const GROUPS: Item[][] = [
  [it('air', 'set.air', '#ff8d28', D.air), it('wifi', 'set.wifi', '#0088ff', D.wifi), it('bt', 'set.bt', '#0088ff', D.bt), it('battery', 'set.battery', '#34c759', D.bat)],
  [it('notif', 'set.notif', '#ff383c', D.bell), it('sounds', 'set.sounds', '#ff2d55', D.sound), it('focus', 'set.focus', '#5e5ce6', D.moon)],
  [it('general', 'set.general', '#8e8e93', D.gear), it('cc', 'set.cc', '#8e8e93', D.cc), it('display', 'set.display', '#0088ff', D.sun), it('access', 'set.access', '#0088ff', D.acc), it('wall', 'set.wall', '#00c0e8', D.wall)],
  [it('privacy', 'set.privacy', '#0088ff', D.hand), it('code', 'set.code', '#ff383c', D.lock), it('store', 'set.store', '#ff2e88', D.store)],
];
const ALL = GROUPS.flat();
type Pal = ReturnType<typeof palette>;
interface PaneProps { p: AppProps; s: SettingsApi; c: Pal }

function Icon({ color, d }: { color: string; d: string }) {
  return <span style={{ width: 30, height: 30, borderRadius: 8, background: color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg></span>;
}

function Section({ title, children, c }: { title?: string; children: React.ReactNode; c: Pal }) {
  return (
    <>
      {title && <span style={{ display: 'block', fontSize: 13, color: c.sub, padding: '26px 16px 8px', textTransform: 'uppercase' }}>{title}</span>}
      <div style={{ borderRadius: 22, background: c.cell, padding: '0 20px' }}>{children}</div>
    </>
  );
}

function Row({ k, children, c, last }: { k: string; children: React.ReactNode; c: Pal; last?: boolean }) {
  return <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', minHeight: 52, borderBottom: last ? 'none' : `1px solid ${c.sep}`, gap: 16 }}><span style={{ fontSize: 17 }}>{k}</span>{children}</div>;
}

function Hint({ text, c }: { text: string; c: Pal }) {
  return <span style={{ display: 'block', fontSize: 13, color: c.sub, padding: '8px 16px 0' }}>{text}</span>;
}

function Display({ p, s, c }: PaneProps) {
  const { t, dark } = p;
  const radio = (on: boolean) => <span style={{ width: 24, height: 24, borderRadius: '50%', border: on ? 'none' : `2px solid ${c.sub}`, background: on ? 'var(--accent)' : 'transparent' }} />;
  const theme = (isDark: boolean, grad: string, bar: string, label: string) => (
    <button role="radio" aria-checked={dark === isDark} aria-label={label} onClick={() => s.set({ dark: isDark })} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
      <span style={{ width: 120, height: 90, borderRadius: 12, background: grad, border: `1px solid ${c.sep}`, position: 'relative', overflow: 'hidden' }}><span style={{ position: 'absolute', left: 12, right: 12, bottom: 10, height: 20, borderRadius: 6, background: bar }} /></span>
      <span style={{ fontSize: 16 }}>{label}</span>{radio(dark === isDark)}
    </button>
  );
  return (
    <>
      <Section title={t('set.appearance')} c={c}>
        <div role="radiogroup" style={{ display: 'flex', justifyContent: 'center', gap: 90, padding: '24px 0 18px' }}>
          {theme(false, 'linear-gradient(160deg,#c6d4ff,#f7c3df)', 'rgba(255,255,255,.8)', t('set.light'))}
          {theme(true, 'linear-gradient(160deg,#090b20,#170818)', 'rgba(40,40,46,.9)', t('set.dark'))}
        </div>
      </Section>
      <Section title={t('set.glass')} c={c}>
        <div style={{ padding: '18px 0' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 15, color: c.sub, marginBottom: 14 }}><span>{t('set.glass_clear')}</span><span>{t('set.glass_tinted')}</span></div>
          <Slider value={s.settings.glass ?? 50} onChange={(v) => s.set({ glass: v })} label={t('set.glass')} />
        </div>
        <div style={{ borderTop: `1px solid ${c.sep}` }}><Row k={t('set.blur')} c={c} last><Switch on={s.settings.blur !== false} onChange={(v) => s.set({ blur: v })} label={t('set.blur')} /></Row></div>
      </Section>
      <Hint text={t('set.glass_hint')} c={c} />
      <Section title={t('set.brightness')} c={c}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16, padding: '12px 0' }}>
          <svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={c.sub} strokeWidth="2" strokeLinecap="round"><circle cx="12" cy="12" r="4" /></svg>
          <Slider value={s.settings.bright ?? 100} min={15} onChange={(v) => s.set({ bright: v })} label={t('set.brightness')} />
          <svg aria-hidden="true" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={c.sub} strokeWidth="2" strokeLinecap="round"><circle cx="12" cy="12" r="4" /><path d="M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.5 1.5M17.5 17.5 19 19M5 19l1.5-1.5M17.5 6.5 19 5" /></svg>
        </div>
      </Section>
    </>
  );
}

function Wall({ p, s, c }: PaneProps) {
  const cur = s.settings.wall ?? WALL_AUTO;
  return (
    <>
      <Section c={c}><div style={{ padding: '14px 0' }}><Button kind={cur === WALL_AUTO ? 'primary' : 'plain'} onClick={() => s.set({ wall: WALL_AUTO })}>{p.t('set.wall_auto')}</Button></div></Section>
      <span style={{ display: 'block', fontSize: 13, color: c.sub, padding: '26px 16px 8px', textTransform: 'uppercase' }}>{p.t('set.wall_collection')}</span>
      <div role="radiogroup" style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 16 }}>
        {WALLPAPERS.map((w, i) => (
          <button key={i} role="radio" aria-checked={cur === String(i)} aria-label={`${p.t('set.wall')} ${i + 1}`} onClick={() => s.set({ wall: String(i) })} style={{ aspectRatio: '4 / 3', borderRadius: 14, background: w, outline: cur === String(i) ? '3px solid var(--accent)' : 'none', outlineOffset: 2 }} />
        ))}
      </div>
    </>
  );
}

/** Numéro de série masqué : le préfixe et les 4 derniers caractères seulement. */
export function maskSerial(serial: string): string {
  if (serial.length <= 7) return serial;
  return `${serial.slice(0, 3)}${'•'.repeat(serial.length - 7)}${serial.slice(-4)}`;
}

function General({ p, s, c }: PaneProps) {
  const { t } = p;
  const [name, setName] = useState(s.name);
  const [msg, setMsg] = useState<{ ok: boolean; key: string } | null>(null);
  const date = (sec: number) => (sec > 0 ? new Date(sec * 1000).toLocaleDateString(s.lang) : '-');
  const save = async () => {
    const r = await s.rename(name.trim());
    setMsg({ ok: r.ok, key: r.ok ? 'set.name_done' : 'set.name_invalid' });
  };
  return (
    <>
      <Section title={t('set.name')} c={c}>
        <div style={{ display: 'flex', gap: 12, alignItems: 'center', padding: '14px 0' }}>
          <Field value={name} onChange={setName} label={t('set.name')} placeholder={t('set.name')} maxLength={32} onEnter={() => void save()} />
          <Button disabled={name.trim() === '' || name.trim() === s.name} onClick={() => void save()}>{t('set.name_save')}</Button>
        </div>
        {msg && <span role="status" style={{ display: 'block', paddingBottom: 12, color: msg.ok ? '#34c759' : '#ff383c', fontSize: 15 }}>{t(msg.key)}</span>}
      </Section>
      <Section title={t('set.info')} c={c}>
        <Row k={t('set.model')} c={c}><span style={{ color: c.sub }}>{s.info.model}</span></Row>
        <Row k={t('set.os')} c={c}><span dir="ltr" style={{ color: c.sub }}>POP OS {s.info.os}</span></Row>
        <Row k={t('set.phone')} c={c}><span dir="ltr" style={{ color: c.sub }}>{s.info.phone}</span></Row>
        <Row k={t('set.mail')} c={c}><span dir="ltr" style={{ color: c.sub }}>{s.settings.mail ?? ''}</span></Row>
        <Row k={t('set.serial')} c={c}><span dir="ltr" style={{ color: c.sub }}>{maskSerial(s.serial)}</span></Row>
        <Row k={t('set.battery')} c={c}><span dir="ltr" style={{ color: c.sub }}>{Math.round(s.battery)} %</span></Row>
        <Row k={t('set.created')} c={c}><span style={{ color: c.sub }}>{date(s.info.created)}</span></Row>
        <Row k={t('set.last_open')} c={c} last><span style={{ color: c.sub }}>{date(s.info.lastOpen)}</span></Row>
      </Section>
      <Section title={t('set.language')} c={c}>
        <div role="radiogroup">
          {LANGUAGES.map((l, i) => <ListRow key={l} title={LANGUAGE_NAMES[l]} value={s.lang === l ? '✓' : ''} onClick={() => s.setLang(l)} last={i === LANGUAGES.length - 1} />)}
        </div>
      </Section>
    </>
  );
}

function Code({ p, s, c }: PaneProps) {
  const { t } = p;
  const [oldC, setOld] = useState('');
  const [newC, setNew] = useState('');
  const [msg, setMsg] = useState<{ ok: boolean; key: string } | null>(null);
  const valid = /^\d{4}$/.test(oldC) && /^\d{4}$/.test(newC);
  const submit = async () => {
    const r = await s.changeCode(oldC, newC);
    setMsg({ ok: r.ok, key: r.ok ? 'set.code_done' : r.err === 'err_code_wrong' ? 'code.wrong' : (r.err ?? 'err_unavailable') });
    if (r.ok) { setOld(''); setNew(''); }
  };
  return (
    <Section c={c}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12, padding: '18px 0' }}>
        <Field value={oldC} onChange={(v) => setOld(v.replace(/\D/g, '').slice(0, 4))} label={t('set.code_old')} placeholder={t('set.code_old')} type="password" inputMode="numeric" maxLength={4} />
        <Field value={newC} onChange={(v) => setNew(v.replace(/\D/g, '').slice(0, 4))} label={t('set.code_new')} placeholder={t('set.code_new')} type="password" inputMode="numeric" maxLength={4} onEnter={() => valid && void submit()} />
        <Button disabled={!valid} onClick={() => void submit()}>{t('set.code_change')}</Button>
        {msg && <span role="status" style={{ color: msg.ok ? '#34c759' : '#ff383c', fontSize: 15 }}>{t(msg.key)}</span>}
      </div>
    </Section>
  );
}

type ToggleId = 'air' | 'wifi' | 'bt' | 'focus' | 'share' | 'rot' | 'mirror' | 'bold';

function Toggle({ p, s, c, id, k, defaultOn = false, hint }: PaneProps & { id: ToggleId; k: string; defaultOn?: boolean; hint?: string }) {
  const on = s.settings[id] ?? defaultOn;
  return (
    <>
      <Section c={c}><Row k={p.t(k)} c={c} last><Switch on={on} onChange={(v) => s.set({ [id]: v })} label={p.t(k)} /></Row></Section>
      {hint && <Hint text={p.t(hint)} c={c} />}
    </>
  );
}

function Battery({ p, s, c }: PaneProps) {
  const pct = Math.max(0, Math.min(100, Math.round(s.battery)));
  return (
    <Section c={c}>
      <div style={{ padding: '22px 0', display: 'flex', flexDirection: 'column', gap: 14 }}>
        <span dir="ltr" style={{ fontSize: 44, fontWeight: 700 }}>{pct} %</span>
        <span role="progressbar" aria-label={p.t('set.battery')} aria-valuemin={0} aria-valuemax={100} aria-valuenow={pct} style={{ height: 10, borderRadius: 5, background: c.fill, overflow: 'hidden' }}>
          <span style={{ display: 'block', height: '100%', width: `${pct}%`, background: pct <= 20 ? '#ff383c' : '#34c759' }} />
        </span>
        <span style={{ fontSize: 15, color: c.sub }}>{p.t('set.battery_hint')}</span>
      </div>
    </Section>
  );
}

/** Nom affiché d'une appli : natives dans l'interface, applis d'autres ressources par leur nom enregistré. */
function appName(t: AppProps['t'], id: string): string {
  const n = t(`app.${id}`);
  return n === `app.${id}` ? t(`api.${id}`) : n;
}

function Notifications({ p, s, c }: PaneProps) {
  const map = s.settings.notif ?? {};
  return (
    <Section c={c}>
      {s.apps.map((id, i) => (
        <div key={id} style={{ display: 'flex', alignItems: 'center', gap: 14, height: 60, borderBottom: i < s.apps.length - 1 ? `1px solid ${c.sep}` : 'none' }}>
          <AppIcon appId={id} size={34} dark={p.dark} />
          <span style={{ display: 'flex', flexDirection: 'column', flexGrow: 1 }}><span style={{ fontSize: 17 }}>{appName(p.t, id)}</span><span style={{ fontSize: 14, color: c.sub }}>{p.t('set.notif_hint')}</span></span>
          <Switch on={map[id] !== false} onChange={(v) => s.set({ notif: { ...map, [id]: v } })} label={`${p.t('set.notif')} ${appName(p.t, id)}`} />
        </div>
      ))}
    </Section>
  );
}

function Sounds({ p, s, c }: PaneProps) {
  const ring = s.settings.ring ?? 1;
  return (
    <>
      <Section title={p.t('set.volume')} c={c}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16, padding: '12px 0' }}><Slider value={s.settings.vol ?? 55} onChange={(v) => s.set({ vol: v })} label={p.t('set.volume')} /></div>
      </Section>
      <Section title={p.t('set.ringtone')} c={c}>
        <div role="radiogroup">
          {[1, 2, 3, 4, 5].map((n) => <ListRow key={n} title={p.t(`set.ring_${n}`)} value={ring === n ? '✓' : ''} onClick={() => s.set({ ring: n })} last={n === 5} />)}
        </div>
      </Section>
    </>
  );
}

function Privacy({ p, s, c, goCode }: PaneProps & { goCode: () => void }) {
  return (
    <>
      <Section c={c}>
        <Row k={p.t('set.code')} c={c}><Button kind="plain" onClick={goCode}>{p.t('set.code_change')}</Button></Row>
        <Row k={p.t('set.lock_now')} c={c} last><Button kind="plain" onClick={() => void p.nui.call('device:lock').then((r) => { if (r.ok || r.err === 'err_locked') window.dispatchEvent(new CustomEvent('pop-device-locked')); })}>{p.t('set.lock_now_do')}</Button></Row>
      </Section>
      <Hint text={p.t('set.privacy_hint')} c={c} />
      <Toggle p={p} s={s} c={c} id="share" k="cc.share" />
    </>
  );
}

function StoreSettings({ p, s, c }: PaneProps) {
  const [msg, setMsg] = useState<string | null>(null);
  const remove = async (id: string) => {
    const r = await s.uninstall(id);
    setMsg(r.ok ? null : (r.err ?? 'err_unavailable'));
  };
  return (
    <>
      <Section title={p.t('set.installed')} c={c}>
        {s.apps.map((id, i) => (
          <div key={id} style={{ display: 'flex', alignItems: 'center', gap: 14, height: 56, borderBottom: i < s.apps.length - 1 ? `1px solid ${c.sep}` : 'none' }}>
            <AppIcon appId={id} size={32} dark={p.dark} />
            <span style={{ flexGrow: 1, fontSize: 17 }}>{appName(p.t, id)}</span>
            <Button kind="plain" onClick={() => void remove(id)} aria-label={`${p.t('set.remove')} ${appName(p.t, id)}`}>{p.t('set.remove')}</Button>
          </div>
        ))}
      </Section>
      {msg && <span role="status" style={{ display: 'block', padding: '12px 16px', color: '#ff383c', fontSize: 15 }}>{p.t(msg)}</span>}
    </>
  );
}

export default function Settings(p: AppProps) {
  const { t, dark, layout } = p;
  const c = palette(dark);
  const s = useSettings(p);
  const [sel, setSel] = useState<Pane>('display');
  const [showDetail, setShowDetail] = useState(false);
  const [query, setQuery] = useState('');
  const cur = ALL.find((x) => x.id === sel) ?? ALL[0]!;
  const q = query.trim().toLowerCase();
  const go = (id: Pane) => { setSel(id); setShowDetail(true); };
  const sidebar = (
    <>
      <span style={{ fontSize: 34, fontWeight: 700, padding: '0 8px' }}>{t('app.reglages')}</span>
      <label style={{ height: 40, borderRadius: 20, background: c.fill, display: 'flex', alignItems: 'center', gap: 8, padding: '0 12px', color: c.sub }}>
        <svg aria-hidden="true" width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round"><circle cx="11" cy="11" r="7" /><path d="M20 20l-4-4" /></svg>
        <input aria-label={t('home.search')} placeholder={t('home.search')} value={query} onChange={(e) => setQuery(e.target.value)} style={{ flexGrow: 1, minWidth: 0, fontSize: 17, color: c.fg }} />
      </label>
      <button onClick={() => go('general')} style={{ display: 'flex', gap: 14, alignItems: 'center', padding: '12px 14px', borderRadius: 16, background: c.cell, textAlign: 'start' }}>
        <span style={{ width: 58, height: 58, borderRadius: '50%', background: 'linear-gradient(135deg,#ff6aae,#ff2e88)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, fontWeight: 600 }}>{(s.name || 'P').slice(0, 2).toUpperCase()}</span>
        <span style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}><span style={{ fontSize: 19, fontWeight: 600 }}>{s.name}</span><span style={{ fontSize: 14, color: c.sub, overflow: 'hidden', textOverflow: 'ellipsis' }}>{s.settings.mail ?? ''}</span></span>
      </button>
      {GROUPS.map((g, gi) => {
        const items = g.filter((x) => q === '' || t(x.nameKey).toLowerCase().includes(q));
        if (items.length === 0) return null;
        return (
          <div key={gi} style={{ borderRadius: 16, overflow: 'hidden', background: c.cell }}>
            {items.map((x, i) => <ListRow key={x.id} icon={<Icon color={x.color} d={x.d} />} title={t(x.nameKey)} selected={layout === 'regular' && sel === x.id} last={i === items.length - 1} onClick={() => go(x.id)} />)}
          </div>
        );
      })}
    </>
  );
  const pp = { p, s, c };
  const detail = (
    <>
      <div style={{ height: 96, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 600, position: 'relative' }}>
        {layout === 'compact' && <button onClick={() => setShowDetail(false)} style={{ position: 'absolute', insetInlineStart: 0, color: 'var(--accent)' }}>{t('kit.back')}</button>}
        {t(cur.nameKey)}
      </div>
      {cur.id === 'air' && <Toggle {...pp} id="air" k="set.air" hint="set.air_hint" />}
      {cur.id === 'wifi' && <Toggle {...pp} id="wifi" k="set.wifi" defaultOn hint="set.wifi_hint" />}
      {cur.id === 'bt' && <Toggle {...pp} id="bt" k="set.bt" hint="set.bt_hint" />}
      {cur.id === 'battery' && <Battery {...pp} />}
      {cur.id === 'notif' && <Notifications {...pp} />}
      {cur.id === 'sounds' && <Sounds {...pp} />}
      {cur.id === 'focus' && <Toggle {...pp} id="focus" k="set.focus" hint="set.focus_hint" />}
      {cur.id === 'general' && <General {...pp} />}
      {cur.id === 'cc' && (
        <Section c={c}>
          <Row k={t('cc.share')} c={c}><Switch on={s.settings.share === true} onChange={(v) => s.set({ share: v })} label={t('cc.share')} /></Row>
          <Row k={t('cc.rotation')} c={c}><Switch on={s.settings.rot === true} onChange={(v) => s.set({ rot: v })} label={t('cc.rotation')} /></Row>
          <Row k={t('cc.mirror')} c={c} last><Switch on={s.settings.mirror === true} onChange={(v) => s.set({ mirror: v })} label={t('cc.mirror')} /></Row>
        </Section>
      )}
      {cur.id === 'display' && <Display {...pp} />}
      {cur.id === 'access' && <Toggle {...pp} id="bold" k="set.bold" hint="set.bold_hint" />}
      {cur.id === 'wall' && <Wall {...pp} />}
      {cur.id === 'privacy' && <Privacy {...pp} goCode={() => setSel('code')} />}
      {cur.id === 'code' && <Code {...pp} />}
      {cur.id === 'store' && <StoreSettings {...pp} />}
    </>
  );
  return <SplitView sidebar={sidebar} detail={detail} showDetail={showDetail} />;
}
