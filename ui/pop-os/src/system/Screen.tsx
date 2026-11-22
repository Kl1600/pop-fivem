import { AnimatePresence, m } from 'motion/react';
import { Suspense, lazy, useEffect, useMemo, useState, type ComponentType } from 'react';
import { AppIcon, appBackground, glassVars, wallpaper, useT, type AppProps } from '../kit';
import { getApp } from '../apps/registry';
import { nuiApi } from '../nui/bridge';
import { formatDate, formatTime, useGameDate } from './clock';
import { closeApp, dismissBanner, homeBar, isOnlineApp, openApp, power, toggleOverlay } from './actions';
import { CodeLayer, LockLayer, SetupLayer } from './Lock';
import { HomeLayer, originOf } from './Home';
import { ControlCenter, NotificationCenter, SearchOverlay, Switcher } from './Overlays';
import { useOS } from './store';

const lazyCache = new Map<string, ComponentType<AppProps>>();
function appComponent(id: string): ComponentType<AppProps> | null {
  const m = getApp(id);
  if (!m) return null;
  let c = lazyCache.get(id);
  if (!c) { c = lazy(m.load); lazyCache.set(id, c); }
  return c;
}

/** Fond d'écran tiré d'une photo (`photo:<id>`) : lu au serveur une fois la tablette déverrouillée ; sinon fond automatique. */
function useWallPhoto(wall: string | undefined, locked: boolean): string | null {
  const [src, setSrc] = useState<string | null>(null);
  useEffect(() => {
    const m = /^photo:(\d+)$/.exec(wall ?? '');
    if (!m || locked) { if (!m) setSrc(null); return; }
    let live = true;
    void nuiApi.call<{ ok: boolean; photo?: { data: string } }>('photos:get', Number(m[1])).then((r) => { if (live) setSrc(r.ok && r.photo ? r.photo.data : null); });
    return () => { live = false; };
  }, [wall, locked]);
  return src;
}

function StatusBar({ light, appName }: { light: boolean; appName: string }) {
  const lang = useOS((s) => s.lang);
  const battery = useOS((s) => s.battery);
  const st = useOS((s) => s.settings);
  const screen = useOS((s) => s.screen);
  const d = useGameDate();
  const t = useT();
  const hideLeft = screen !== 'home';
  const net = st.air ? 'air' : st.wifi === false ? 'off' : 'wifi';
  const pct = Math.max(0, Math.min(100, Math.round(battery)));
  return (
    <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 34, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 30px', fontSize: 15, fontWeight: 600, color: light ? '#000' : '#fff', pointerEvents: 'none', zIndex: 5 }}>
      <span style={{ opacity: hideLeft ? 0 : 1 }}><span dir="ltr">{formatTime(d)}</span> &#160;{formatDate(d, lang, 'short')}<span style={{ opacity: 0.7 }}>{appName ? ` · ${appName}` : ''}</span></span>
      <span style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
        {net === 'wifi' && <svg role="img" aria-label={t('cc.wifi')} width="19" height="15" viewBox="0 0 24 18" fill="currentColor"><path d="M12 3c3.9 0 7.4 1.5 10 4l-2 2.1C17.9 7 15.1 5.8 12 5.8S6.1 7 4 9.1L2 7c2.6-2.5 6.1-4 10-4zm0 5.6c2.4 0 4.5.9 6.1 2.4l-2 2.1c-1.1-1-2.5-1.6-4.1-1.6s-3 .6-4.1 1.6l-2-2.1c1.6-1.5 3.7-2.4 6.1-2.4zm0 5.6c.9 0 1.7.3 2.3.9L12 17.4l-2.3-2.3c.6-.6 1.4-.9 2.3-.9z" /></svg>}
        {net === 'air' && <svg role="img" aria-label={t('cc.airplane')} width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M2 16l8-3V5a2 2 0 0 1 4 0v8l8 3v2l-8-2v4l2 2h-8l2-2v-4l-8 2z" /></svg>}
        <span dir="ltr">{pct} %</span>
        <svg aria-hidden="true" width="28" height="14" viewBox="0 0 28 14" fill="none"><rect x="1" y="1" width="23" height="12" rx="3.5" stroke="currentColor" strokeOpacity=".45" strokeWidth="1.2" /><rect x="3" y="3" width={Math.max(1, (17 * pct) / 100)} height="8" rx="2" fill={pct <= 20 ? '#ff383c' : 'currentColor'} /><path d="M26 5v4" stroke="currentColor" strokeOpacity=".45" strokeWidth="1.6" strokeLinecap="round" /></svg>
      </span>
    </div>
  );
}

function Offline({ id, dark }: { id: string; dark: boolean }) {
  const t = useT();
  return (
    <div data-offline={id} style={{ width: '100%', height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 12, color: dark ? '#fff' : '#000' }}>
      <AppIcon appId={id} size={90} dark={dark} />
      <span style={{ fontSize: 24, fontWeight: 700 }}>{t('net.offline')}</span>
      <span style={{ fontSize: 16, opacity: 0.6 }}>{t('net.offline_hint')}</span>
    </div>
  );
}

function AppLayer() {
  const app = useOS((s) => s.app);
  const org = useOS((s) => s.org);
  const data = useOS((s) => s.appData);
  const dark = useOS((s) => s.settings.dark === true);
  const lang = useOS((s) => s.lang);
  const server = useOS((s) => s.server);
  const t = useT();
  const off = useOS((s) => s.settings.air === true || s.settings.wifi === false);
  const Comp = app ? appComponent(app) : null;
  const props: AppProps | null = useMemo(() => (app ? { id: app, layout: 'regular', dark, t, nui: nuiApi, close: closeApp, data: data ?? undefined } : null), [app, dark, t, data, lang, server]);
  const ox = org.x - 674, oy = org.y - 509;
  return (
    <AnimatePresence>
      {app && Comp && props && (
        <m.div
          key={app}
          data-layer="app"
          initial={{ x: ox, y: oy, scale: 0.065, opacity: 1 }}
          animate={{ x: 0, y: 0, scale: 1, opacity: 1 }}
          exit={{ x: ox, y: oy, scale: 0.065, opacity: 0 }}
          transition={{ duration: 0.5, ease: [0.2, 0.9, 0.25, 1.02] }}
          style={{ position: 'absolute', inset: 0, borderRadius: 30, overflow: 'hidden', background: appBackground(dark), zIndex: 2 }}
        >
          {off && isOnlineApp(app) ? <Offline id={app} dark={dark} /> : <Suspense fallback={null}><Comp {...props} /></Suspense>}
        </m.div>
      )}
    </AnimatePresence>
  );
}

export function Screen({ shell }: { shell: boolean }) {
  const t = useT();
  const s = {
    on: useOS((x) => x.on), screen: useOS((x) => x.screen), app: useOS((x) => x.app), banner: useOS((x) => x.banner),
    cc: useOS((x) => x.cc), nc: useOS((x) => x.nc), search: useOS((x) => x.search), sw: useOS((x) => x.sw), edit: useOS((x) => x.edit),
    hud: useOS((x) => x.hud), vol: useOS((x) => x.vol), st: useOS((x) => x.settings), lang: useOS((x) => x.lang),
  };
  const dark = s.st.dark === true;
  const { ga, gad } = glassVars(s.st.glass ?? 50);
  const overlay = s.cc || s.nc || s.search || s.sw;
  const blurWall = s.screen === 'code' || s.screen === 'setup' || overlay;
  const home = s.screen === 'home';
  const appVisible = !!s.app;
  const wallPhoto = useWallPhoto(s.st.wall, s.screen === 'lock' || s.screen === 'code' || s.screen === 'setup');
  const wall = wallPhoto ? `url("${wallPhoto}") center / cover` : wallpaper(s.st.wall, dark);
  const inLightApp = appVisible && !dark && !overlay;
  const bright = Math.max(15, s.st.bright ?? 100);
  const appName = s.app ? t(getApp(s.app)?.nameKey ?? `app.${s.app}`) : '';
  const hot = s.on && s.screen !== 'code' && s.screen !== 'setup';
  const bn = s.banner;
  const bannerApp = bn ? getApp(bn.app) : null;
  return (
    <div data-screen="1" className={dark ? 'dk' : ''} style={{ position: 'relative', width: 1348, height: 1019, borderRadius: shell ? 30 : 0, overflow: 'hidden', background: '#000', color: '#fff', ['--ga' as string]: ga, ['--gad' as string]: gad }}>
      <div aria-hidden="true" style={{ position: 'absolute', inset: -40, background: wall }} />
      <div aria-hidden="true" className="tr" style={{ position: 'absolute', inset: -40, background: wall, filter: 'blur(34px) saturate(140%)', transform: 'scale(1.08)', opacity: blurWall ? 1 : 0, transitionProperty: 'opacity' }} />

      <LockLayer active={s.screen === 'lock'} toCode={s.screen === 'code'} />
      <CodeLayer active={s.screen === 'code'} />
      <SetupLayer active={s.screen === 'setup'} />
      <HomeLayer active={home} appVisible={appVisible} overlay={overlay} />
      <AppLayer />
      <StatusBar light={inLightApp} appName={appName} />

      <AnimatePresence>
        {bn && (
          <m.div key={bn.id} role="button" tabIndex={0} onClick={(e) => { dismissBanner(); openApp(bn.app, originOf(e.currentTarget)); }} initial={{ y: -140, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -140, opacity: 0 }} transition={{ duration: 0.45, ease: [0.2, 0.9, 0.25, 1.02] }} className="g" style={{ position: 'absolute', top: 14, left: '50%', marginLeft: -270, width: 540, borderRadius: 28, padding: '13px 16px', display: 'flex', gap: 12, alignItems: 'center', color: dark ? '#fff' : '#000', cursor: 'pointer', zIndex: 6 }}>
            <AppIcon appId={bn.app} size={40} dark={dark} />
            <span style={{ display: 'flex', flexDirection: 'column', flexGrow: 1, minWidth: 0 }}>
              <span style={{ display: 'flex', justifyContent: 'space-between', fontSize: 15, fontWeight: 600 }}><span>{bn.title}</span><span className="sub" style={{ fontWeight: 400, fontSize: 13 }}>{t('time.now')}</span></span>
              <span style={{ fontSize: 15 }}>{bn.body || (bannerApp ? t(bannerApp.nameKey) : '')}</span>
            </span>
          </m.div>
        )}
      </AnimatePresence>

      <NotificationCenter />
      <ControlCenter />
      <SearchOverlay />
      <Switcher />

      <AnimatePresence>
        {s.hud && (
          <m.div key="hud" aria-hidden="true" className="g" initial={{ x: 30, opacity: 0 }} animate={{ x: 0, opacity: 1 }} exit={{ x: 30, opacity: 0 }} transition={{ duration: 0.25 }} style={{ position: 'absolute', insetInlineEnd: 16, top: 130, width: 16, height: 170, borderRadius: 8, overflow: 'hidden', zIndex: 8 }}>
            <span style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: `${s.vol}%`, background: '#fff' }} />
          </m.div>
        )}
      </AnimatePresence>

      {hot && <button aria-label={t('hw.nc')} className="hot" onClick={() => toggleOverlay('nc')} style={{ position: 'absolute', top: 0, insetInlineStart: 120, width: 460, height: 34, borderRadius: '0 0 16px 16px', zIndex: 9 }} />}
      {hot && <button aria-label={t('hw.cc')} className="hot" onClick={() => toggleOverlay('cc')} style={{ position: 'absolute', top: 0, insetInlineEnd: 0, width: 300, height: 34, borderRadius: '0 0 0 16px', zIndex: 9 }} />}
      {hot && (
        <button aria-label={t('hw.home_bar')} onClick={homeBar} onDoubleClick={() => { if (s.screen === 'home') toggleOverlay('sw'); }} style={{ position: 'absolute', bottom: 0, left: '50%', marginLeft: -170, width: 340, height: 30, zIndex: 9, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <span style={{ width: 200, height: 6, borderRadius: 3, background: inLightApp ? '#000' : '#fff' }} />
        </button>
      )}

      <div aria-hidden="true" style={{ position: 'absolute', inset: 0, background: '#000', pointerEvents: 'none', zIndex: 20, opacity: (100 - bright) * 0.006 }} />
      <div className="fade" onClick={power} data-off={s.on ? '0' : '1'} style={{ position: 'absolute', inset: 0, background: '#000', zIndex: 21, opacity: s.on ? 0 : 1, pointerEvents: s.on ? 'none' : 'auto' }} />
    </div>
  );
}
