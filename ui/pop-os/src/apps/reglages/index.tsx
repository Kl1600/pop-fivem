import { useState } from 'react';
import { AppIcon, Button, Field, LANGUAGES, LANGUAGE_NAMES, ListRow, Slider, SplitView, Switch, WALLPAPERS, WALL_AUTO, palette, type AppProps } from '../../kit';

import { useSettings, type SettingsApi } from './store';

// Réglages : thème, verre, luminosité, fond d'écran, langue, code. Le reste des rubriques attend un passage dédié.
// L'appli ne connaît que le kit : les réglages passent par le relais NUI (`settings:save`) et un petit magasin local.

type Pane = 'display' | 'wall' | 'general' | 'code' | 'air' | 'other';
interface Item { id: string; nameKey: string; color: string; d: string; pane: Pane }

const D = {
  air: 'M2 16l8-3V5a2 2 0 0 1 4 0v8l8 3v2l-8-2v4l2 2h-8l2-2v-4l-8 2z', wifi: 'M2 9a15 15 0 0 1 20 0M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0',
  bt: 'M7 7l10 10-5 4V3l5 4L7 17', bell: 'M6 16v-5a6 6 0 0 1 12 0v5l2 2H4zM10 21h4', sound: 'M4 9h4l5-4v14l-5-4H4zM16 9a4 4 0 0 1 0 6',
  moon: 'M20 14.5A8.5 8.5 0 1 1 9.5 4a7 7 0 0 0 10.5 10.5z', gear: 'M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6zM12 2v3M12 19v3M2 12h3M19 12h3',
  cc: 'M4 6h7v7H4zM13 6h7v7h-7zM4 15h16v4H4z', sun: 'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2v2M12 20v2M2 12h2M20 12h2',
  wall: 'M3 5h18v14H3zM3 16l6-6 5 5 3-3 4 4', lock: 'M5 11h14v10H5zM8 11V8a4 4 0 0 1 8 0v3', store: 'M6 7h12l-1 13H7L6 7zM9 7a3 3 0 0 1 6 0',
};
const GROUPS: Item[][] = [
  [{ id: 'air', nameKey: 'set.air', color: '#ff8d28', d: D.air, pane: 'air' }, { id: 'wifi', nameKey: 'set.wifi', color: '#0088ff', d: D.wifi, pane: 'air' }, { id: 'bt', nameKey: 'set.bt', color: '#0088ff', d: D.bt, pane: 'air' }],
  [{ id: 'notif', nameKey: 'set.notif', color: '#ff383c', d: D.bell, pane: 'other' }, { id: 'sons', nameKey: 'set.sounds', color: '#ff2d55', d: D.sound, pane: 'other' }, { id: 'focus', nameKey: 'set.focus', color: '#5e5ce6', d: D.moon, pane: 'other' }],
  [{ id: 'general', nameKey: 'set.general', color: '#8e8e93', d: D.gear, pane: 'general' }, { id: 'ccset', nameKey: 'set.cc', color: '#8e8e93', d: D.cc, pane: 'other' }, { id: 'display', nameKey: 'set.display', color: '#0088ff', d: D.sun, pane: 'display' }, { id: 'wall', nameKey: 'set.wall', color: '#00c0e8', d: D.wall, pane: 'wall' }],
  [{ id: 'code', nameKey: 'set.code', color: '#ff383c', d: D.lock, pane: 'code' }, { id: 'shop', nameKey: 'set.store', color: '#ff2e88', d: D.store, pane: 'other' }],
];
const ALL = GROUPS.flat();

function Icon({ color, d }: { color: string; d: string }) {
  return <span style={{ width: 30, height: 30, borderRadius: 8, background: color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg></span>;
}

function Section({ title, children, c }: { title?: string; children: React.ReactNode; c: ReturnType<typeof palette> }) {
  return (
    <>
      {title && <span style={{ display: 'block', fontSize: 13, color: c.sub, padding: '26px 16px 8px', textTransform: 'uppercase' }}>{title}</span>}
      <div style={{ borderRadius: 22, background: c.cell, padding: '0 20px' }}>{children}</div>
    </>
  );
}

function Row({ k, children, c, last }: { k: string; children: React.ReactNode; c: ReturnType<typeof palette>; last?: boolean }) {
  return <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', minHeight: 52, borderBottom: last ? 'none' : `1px solid ${c.sep}`, gap: 16 }}><span style={{ fontSize: 17 }}>{k}</span>{children}</div>;
}

function Display({ p, s, c }: { p: AppProps; s: SettingsApi; c: ReturnType<typeof palette> }) {
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
      <span style={{ display: 'block', fontSize: 13, color: c.sub, padding: '8px 16px 0' }}>{t('set.glass_hint')}</span>
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

function Wall({ p, s, c }: { p: AppProps; s: SettingsApi; c: ReturnType<typeof palette> }) {
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

function General({ p, s, c }: { p: AppProps; s: SettingsApi; c: ReturnType<typeof palette> }) {
  const { t } = p;
  return (
    <>
      <Section c={c}>
        <Row k={t('set.name')} c={c}><span style={{ color: c.sub }}>{s.name}</span></Row>
        <Row k={t('set.serial')} c={c}><span dir="ltr" style={{ color: c.sub }}>{s.serial}</span></Row>
        <Row k={t('set.battery')} c={c} last><span dir="ltr" style={{ color: c.sub }}>{Math.round(s.battery)} %</span></Row>
      </Section>
      <Section title={t('set.language')} c={c}>
        <div role="radiogroup">
          {LANGUAGES.map((l, i) => <ListRow key={l} title={LANGUAGE_NAMES[l]} value={s.lang === l ? '✓' : ''} onClick={() => s.setLang(l)} last={i === LANGUAGES.length - 1} />)}
        </div>
      </Section>
    </>
  );
}

function Code({ p, s, c }: { p: AppProps; s: SettingsApi; c: ReturnType<typeof palette> }) {
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

function Network({ p, s, c }: { p: AppProps; s: SettingsApi; c: ReturnType<typeof palette> }) {
  const { t } = p;
  return (
    <Section c={c}>
      <Row k={t('set.air')} c={c}><Switch on={s.settings.air === true} onChange={(v) => s.set({ air: v })} label={t('set.air')} /></Row>
      <Row k={t('set.wifi')} c={c}><Switch on={s.settings.wifi !== false} onChange={(v) => s.set({ wifi: v })} label={t('set.wifi')} /></Row>
      <Row k={t('set.bt')} c={c} last><Switch on={s.settings.bt === true} onChange={(v) => s.set({ bt: v })} label={t('set.bt')} /></Row>
    </Section>
  );
}

export default function Settings(p: AppProps) {
  const { t, dark, layout } = p;
  const c = palette(dark);
  const s = useSettings(p);
  const [sel, setSel] = useState('display');
  const [showDetail, setShowDetail] = useState(false);
  const cur = ALL.find((x) => x.id === sel) ?? ALL[0]!;
  const sidebar = (
    <>
      <span style={{ fontSize: 34, fontWeight: 700, padding: '0 8px' }}>{t('app.reglages')}</span>
      <div style={{ display: 'flex', gap: 14, alignItems: 'center', padding: '12px 14px', borderRadius: 16, background: c.cell }}>
        <span style={{ width: 58, height: 58, borderRadius: '50%', background: 'linear-gradient(135deg,#ff6aae,#ff2e88)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, fontWeight: 600 }}>{(s.name || 'P').slice(0, 2).toUpperCase()}</span>
        <span style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}><span style={{ fontSize: 19, fontWeight: 600 }}>{s.name}</span><span style={{ fontSize: 14, color: c.sub, overflow: 'hidden', textOverflow: 'ellipsis' }}>{s.settings.mail ?? ''}</span></span>
      </div>
      {GROUPS.map((g, gi) => (
        <div key={gi} style={{ borderRadius: 16, overflow: 'hidden', background: c.cell }}>
          {g.map((it, i) => <ListRow key={it.id} icon={<Icon color={it.color} d={it.d} />} title={t(it.nameKey)} selected={layout === 'regular' && sel === it.id} last={i === g.length - 1} onClick={() => { setSel(it.id); setShowDetail(true); }} />)}
        </div>
      ))}
    </>
  );
  const detail = (
    <>
      <div style={{ height: 96, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 600, position: 'relative' }}>
        {layout === 'compact' && <button onClick={() => setShowDetail(false)} style={{ position: 'absolute', insetInlineStart: 0, color: 'var(--accent)' }}>{t('kit.back')}</button>}
        {t(cur.nameKey)}
      </div>
      {cur.pane === 'display' && <Display p={p} s={s} c={c} />}
      {cur.pane === 'wall' && <Wall p={p} s={s} c={c} />}
      {cur.pane === 'general' && <General p={p} s={s} c={c} />}
      {cur.pane === 'code' && <Code p={p} s={s} c={c} />}
      {cur.pane === 'air' && <Network p={p} s={s} c={c} />}
      {cur.pane === 'other' && (
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10, paddingTop: 120, color: c.sub }}>
          <AppIcon appId="reglages" size={64} dark={dark} />
          <span style={{ fontSize: 16 }}>{t('set.soon')}</span>
        </div>
      )}
    </>
  );
  return <SplitView sidebar={sidebar} detail={detail} showDetail={showDetail} />;
}
