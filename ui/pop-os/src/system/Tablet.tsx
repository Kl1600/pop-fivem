import { LazyMotion, MotionConfig, domAnimation } from 'motion/react';
import { useCallback, useEffect, useMemo } from 'react';
import { ClockContext, DarkContext, LayoutContext, NotifyContext, NuiContext, SettingsContext, TContext, WeatherContext, safeAccent, type SettingsApi } from '../kit';
import { Fit, SCREEN_H, SCREEN_W, SHELL_H, SHELL_W, Shell } from '../device/Shell';
import { makeT } from '../i18n';
import { fetchNui, nuiApi, onNuiMessage } from '../nui/bridge';
import { handleMessage, power, pushNotify, renameDevice, requestClose, setInstalled, setLanguage, setSetting, volume } from './actions';
import { gameMsNow } from './clock';
import { Screen } from './Screen';
import { ShareOffer } from './ShareOffer';
import { setSchedule } from './schedule';
import { useOS } from './store';

/** Écoute permanente des messages du client : seul élément actif tablette fermée (un écouteur, aucun minuteur). */
export function Host() {
  const open = useOS((s) => s.open);
  useEffect(() => {
    const off = onNuiMessage(handleMessage);
    // Équivalents de pop.js (non chargé) : `pop:ready` au démarrage ; `tablet:ready` pour recevoir l'ouverture en cours.
    void fetchNui('pop:ready');
    void fetchNui('tablet:ready');
    return off;
  }, []);
  return open ? <Tablet /> : null;
}

/** Tablette ouverte : fournisseurs, mise à l'échelle, coque (développement) et écran. */
export function Tablet() {
  const lang = useOS((s) => s.lang);
  const rtl = useOS((s) => s.rtl);
  const server = useOS((s) => s.server);
  const shell = useOS((s) => s.shell);
  const accent = useOS((s) => s.accent);
  const st = useOS((s) => s.settings);
  const dark = st.dark === true;
  const t = useMemo(() => makeT(lang, server), [lang, server]);
  const name = useOS((s) => s.name);
  const serial = useOS((s) => s.serial);
  const battery = useOS((s) => s.battery);
  const boot = useOS((s) => s.boot);
  const weather = useOS((s) => s.weather);
  const apps = useOS((s) => s.apps);
  const settingsApi: SettingsApi = useMemo(() => ({
    settings: st, name, serial: serial ?? '', battery, lang,
    set: setSetting,
    setLang: (l) => void setLanguage(l),
    changeCode: async (o, n) => { const r = await nuiApi.call('device:changeCode', { old: o, new: n }); return { ok: r.ok, err: r.err }; },
    rename: renameDevice,
    apps,
    install: (item) => setInstalled(item.id, true, item),
    uninstall: (id) => setInstalled(id, false),
    info: { phone: boot?.phone ?? '', model: boot?.model ?? '', os: boot?.os ?? '', created: boot?.created ?? 0, lastOpen: boot?.lastOpen ?? 0 },
  }), [st, name, serial, battery, lang, boot, apps]);
  const clockApi = useMemo(() => ({ gameMs: gameMsNow, setSchedule: (kind: 'alarm' | 'event' | 'reminder', items: Array<{ id: number; minute: number }>) => setSchedule(kind, items.map((i) => ({ ...i, kind }))) }), []);
  const notify = useCallback((n: { app: string; title: string; body: string }) => pushNotify({ app: n.app, text: n.body, titleKey: undefined }), []);

  // Échap rend le focus au jeu (équivalent de `close` du kit). L'écouteur n'existe que tablette ouverte.
  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') void requestClose(); };
    window.addEventListener('keydown', h);
    return () => window.removeEventListener('keydown', h);
  }, []);
  useEffect(() => {
    document.documentElement.dir = rtl ? 'rtl' : 'ltr';
    document.documentElement.lang = lang;
  }, [rtl, lang]);

  const a = safeAccent(accent);
  const vars = a ? ({ ['--accent' as string]: a } as React.CSSProperties) : undefined;
  const screen = <><Screen shell={shell} /><ShareOffer /></>;
  return (
    <LazyMotion features={domAnimation}><MotionConfig reducedMotion="user">
      <TContext.Provider value={t}>
        <LayoutContext.Provider value="regular">
          <DarkContext.Provider value={dark}>
            <NuiContext.Provider value={nuiApi}><ClockContext.Provider value={clockApi}><WeatherContext.Provider value={weather}>
              <NotifyContext.Provider value={notify}><SettingsContext.Provider value={settingsApi}>
                <div className={`pop ${dark ? 'dk' : ''}`} dir={rtl ? 'rtl' : 'ltr'} data-blur={st.blur === false ? 'off' : 'on'} data-bold={st.bold === true ? 'on' : 'off'} data-theme={dark ? 'dark' : 'light'} style={{ position: 'fixed', inset: 0, ...vars }}>
                  {shell ? (
                    <Fit w={SHELL_W} h={SHELL_H}>
                      <Shell powerLabel={t('hw.power')} volUpLabel={t('hw.vol_up')} volDownLabel={t('hw.vol_down')} onPower={power} onVolUp={() => volume(8)} onVolDown={() => volume(-8)}>
                        {screen}
                      </Shell>
                    </Fit>
                  ) : (
                    <Fit w={SCREEN_W} h={SCREEN_H}>{screen}</Fit>
                  )}
                </div>
              </SettingsContext.Provider></NotifyContext.Provider>
            </WeatherContext.Provider></ClockContext.Provider></NuiContext.Provider>
          </DarkContext.Provider>
        </LayoutContext.Provider>
      </TContext.Provider>
    </MotionConfig></LazyMotion>
  );
}
