import { fetchNui, nuiApi } from '../nui/bridge';
import { getApp } from '../apps/registry';
import type { Boot, ClockSnap, NotifyMsg, OpenData, Settings, StoreItem, Weather } from '../nui/types';
import { isLang, makeT } from '../i18n';
import { syncSchedule } from './schedule';
import { applyApiApps, applyOpen, bootPatch, os, ONLINE_APPS, type Notif } from './store';

// Actions du système : seuls endroits qui modifient le magasin. Les minuteurs ci-dessous sont courts (HUD, bannière)
// et tous annulés à la fermeture de la tablette.

let hudTimer: ReturnType<typeof setTimeout> | null = null;
let bannerTimer: ReturnType<typeof setTimeout> | null = null;
let pendingApp: { app: string; data?: unknown } | null = null;
let notifId = 1;

export const BANNER_MS = 5000;
export const HUD_MS = 1500;

function clearTimers(): void {
  if (hudTimer) clearTimeout(hudTimer);
  if (bannerTimer) clearTimeout(bannerTimer);
  hudTimer = null;
  bannerTimer = null;
}

export function langOf(d: OpenData): string {
  const l = d.lang ?? d.boot?.settings?.lang;
  return isLang(l) ? l : 'en';
}

export function handleOpen(d: OpenData): void {
  clearTimers();
  pendingApp = d.app && typeof d.app.app === 'string' ? d.app : null;
  applyOpen(d, langOf(d));
}

/** Fermeture : tout est remis à zéro, plus aucun minuteur ne reste. */
export function closeTablet(): void {
  clearTimers();
  pendingApp = null;
  os.reset();
}

/** Demande de fermeture venue de l'interface (Échap) : le client rend le focus, puis l'interface se démonte. */
export async function requestClose(): Promise<void> {
  await fetchNui('close');
  closeTablet();
}

export function closeOverlays(): void {
  os.set({ cc: false, nc: false, search: false, sw: false });
}

export function toggleOverlay(which: 'cc' | 'nc' | 'search' | 'sw'): void {
  const cur = os.get()[which];
  os.set({ cc: false, nc: false, search: false, sw: false, [which]: !cur });
}

/** Bouton du haut : éteint l'écran (et verrouille), ou rallume sur l'écran verrouillé. */
export function power(): void {
  const s = os.get();
  if (s.on) {
    void nuiApi.call('device:lock');
    os.set({ on: false, screen: s.needSetup ? 'setup' : 'lock', app: null, cc: false, nc: false, search: false, sw: false, edit: false, banner: null });
  } else {
    os.set({ on: true, screen: s.needSetup ? 'setup' : 'lock' });
  }
}

export function volume(delta: number): void {
  setVolume(os.get().vol + delta);
}

export function setVolume(v: number): void {
  os.set({ vol: Math.max(0, Math.min(100, Math.round(v))), hud: true });
  if (hudTimer) clearTimeout(hudTimer);
  hudTimer = setTimeout(() => os.set({ hud: false }), HUD_MS);
}

export function showCode(): void {
  os.set({ screen: 'code', codeError: null });
}

export function cancelCode(): void {
  os.set({ screen: 'lock', codeError: null });
}

export interface UnlockResult {
  ok: boolean;
  err?: string;
  wait?: number;
}

/** Envoie le code au serveur ; en cas de succès, l'accueil s'affiche et l'éventuelle appli demandée s'ouvre. */
export async function submitCode(code: string): Promise<UnlockResult> {
  const res = await nuiApi.call<{ ok: boolean; err?: string; wait?: number; boot?: Boot }>('device:unlock', code);
  if (res.ok && res.boot) {
    os.set({ screen: 'home', codeError: null, lockWait: 0, ...bootPatch(res.boot) });
    void syncSchedule(); // alarmes, alertes et rappels : une seule minuterie côté client
    if (pendingApp) {
      const p = pendingApp;
      pendingApp = null;
      if (os.get().apps.includes(p.app)) openApp(p.app, undefined, p.data);
    }
    return { ok: true };
  }
  const wait = typeof res.wait === 'number' ? res.wait : 0;
  os.set({ codeError: res.err ?? 'err_unavailable', lockWait: wait });
  return { ok: false, err: res.err, wait };
}

export interface SetupInput {
  code: string;
  name: string;
  lang: string;
  mail: string;
}

/** Premier allumage : le serveur crée le code haché, le nom et l'adresse mail. */
export async function submitSetup(input: SetupInput): Promise<UnlockResult> {
  const res = await nuiApi.call<{ ok: boolean; err?: string; boot?: Boot }>('device:setup', input);
  if (res.ok) {
    const boot = res.boot;
    os.set({ needSetup: false, screen: 'home', ...(boot ? bootPatch(boot) : { name: input.name }) });
    return { ok: true };
  }
  return { ok: false, err: res.err };
}

export function openApp(id: string, origin?: { x: number; y: number }, data?: unknown): void {
  const s = os.get();
  if (s.edit) return;
  const recents = [id, ...s.recents.filter((x) => x !== id)].slice(0, 4);
  const badges = { ...s.badges };
  delete badges[id];
  os.set({ app: id, appData: data ?? null, org: origin ?? { x: 674, y: 509 }, recents, badges, cc: false, nc: false, search: false, sw: false, banner: null, screen: 'home' });
}

export function closeApp(): void {
  if (os.get().app) os.set({ app: null, appData: null });
}

/** Barre d'accueil : ferme d'abord ce qui est ouvert, puis l'écran verrouillé demande le code. */
export function homeBar(): void {
  const s = os.get();
  if (!s.on) return;
  if (s.cc || s.nc || s.search || s.sw) return closeOverlays();
  if (s.screen === 'lock') return showCode();
  if (s.edit) return os.set({ edit: false });
  if (s.app) closeApp();
}

export function removeRecent(id: string): void {
  const s = os.get();
  os.set({ recents: s.recents.filter((x) => x !== id), ...(s.app === id ? { app: null, appData: null } : {}) });
}

/** Retire une appli de l'accueil (mode édition) : le serveur est prévenu, l'interface suit sans attendre. */
export function removeApp(id: string): void {
  const s = os.get();
  os.set({ apps: s.apps.filter((x) => x !== id) });
  void nuiApi.call('store:remove', id);
}

export type StoreResult = { ok: boolean; err?: string; items?: StoreItem[] };

/** Catalogue de la Boutique (natives + applis des autres ressources visibles pour le métier). Refusé hors ligne. */
export async function loadStore(): Promise<StoreResult> {
  const res = await nuiApi.call<{ ok: boolean; err?: string; items?: StoreItem[] }>('store:list');
  return res.ok ? { ok: true, items: res.items ?? [] } : { ok: false, err: res.err };
}

function applyInstalled(ids: string[], api?: StoreItem[]): void {
  if (api) applyApiApps(api.filter((a): a is StoreItem & { name: string; page: string } => a.api === true && typeof a.name === 'string' && typeof a.page === 'string'));
  os.set({ apps: ids });
}

/** Installe ou retire une appli : le serveur décide (métier, appli système, hors ligne) ; l'accueil suit sa réponse. */
export async function setInstalled(id: string, install: boolean, item?: StoreItem): Promise<{ ok: boolean; err?: string }> {
  const res = await nuiApi.call<{ ok: boolean; err?: string; apps?: string[] }>(install ? 'store:install' : 'store:remove', id);
  if (!res.ok || !res.apps) return { ok: false, err: res.err };
  if (install && item?.api && item.name && item.page) {
    const cur = os.get().boot?.apiApps ?? [];
    const infos = [...cur.filter((a) => a.id !== id), { ...item, installed: true } as NonNullable<typeof cur>[number]];
    os.set({ boot: os.get().boot ? { ...os.get().boot!, apiApps: infos } : null });
    applyInstalled(res.apps, infos);
  } else {
    applyInstalled(res.apps);
  }
  return { ok: true };
}

/** `tablet:apps` : le catalogue a changé (une ressource démarre ou s'arrête) : l'accueil relit la liste installée. */
export async function refreshApps(): Promise<void> {
  const r = await loadStore();
  if (!r.ok || !r.items) return;
  const items = r.items;
  const infos = items.filter((i) => i.api && i.installed) as NonNullable<Boot['apiApps']>;
  const boot = os.get().boot;
  applyApiApps(infos);
  os.set({ apps: items.filter((i) => i.installed).map((i) => i.id), boot: boot ? { ...boot, apiApps: infos } : boot });
}

/** Applique un réglage tout de suite, puis le fait enregistrer (un échec serveur n'annule pas l'effet local). */
export function setSetting(patch: Settings): void {
  const s = os.get();
  os.set({ settings: { ...s.settings, ...patch } });
  void nuiApi.call('settings:save', patch);
}

/** Renomme l'appareil : le serveur valide (1 à 32 caractères). */
export async function renameDevice(name: string): Promise<{ ok: boolean; err?: string }> {
  const res = await nuiApi.call<{ ok: boolean; err?: string; name?: string }>('settings:rename', name);
  if (res.ok) os.set({ name: res.name ?? name });
  return { ok: res.ok, err: res.err };
}

export async function setLanguage(lang: string): Promise<void> {
  if (!isLang(lang)) return;
  const res = await nuiApi.post<{ ok?: boolean; locale?: Record<string, unknown>; rtl?: boolean }>('tablet:locale', { lang });
  os.set({ lang, rtl: lang === 'ar' || res?.rtl === true, server: res?.ok && res.locale ? res.locale : os.get().server });
  setSetting({ lang });
}

export function networkOff(): boolean {
  const st = os.get().settings;
  return st.air === true || st.wifi === false;
}

export function isOnlineApp(id: string): boolean {
  return ONLINE_APPS.has(id);
}

export function pushNotify(m: NotifyMsg): void {
  const s = os.get();
  const t = makeT(s.lang, s.server);
  const title = m.title ?? (m.titleKey ? t(m.titleKey, ...(m.args ?? [])) : getApp(m.app)?.domain === 'api' ? t(`api.${m.app}`) : t(`app.${m.app}`));
  const body = m.text ?? (m.bodyKey ? t(m.bodyKey, ...(m.args ?? [])) : '');
  if (s.settings.notif?.[m.app] === false) return;
  const n: Notif = { id: notifId++, app: m.app, title, body, at: Date.now() };
  const focus = s.settings.focus === true;
  const showBanner = !focus && s.on && s.screen === 'home';
  os.set({
    notifs: [n, ...s.notifs].slice(0, 50),
    badges: { ...s.badges, [m.app]: (s.badges[m.app] ?? 0) + 1 },
    banner: showBanner ? n : s.banner,
  });
  if (showBanner) {
    if (bannerTimer) clearTimeout(bannerTimer);
    bannerTimer = setTimeout(() => os.set({ banner: null }), BANNER_MS);
  }
}

export function clearNotifs(): void {
  os.set({ notifs: [] });
}

export function dismissBanner(): void {
  if (bannerTimer) clearTimeout(bannerTimer);
  os.set({ banner: null });
}

/** Aiguille un message `tablet:<action>` du client. Les messages non utilisés ici (applis) sont ignorés sans erreur. */
export function handleMessage(action: string, data: unknown): void {
  switch (action) {
    case 'open':
      return handleOpen(data as OpenData);
    case 'close':
      return closeTablet();
    case 'openApp': {
      const d = data as { app?: string; data?: unknown } | null;
      if (!d || typeof d.app !== 'string' || !os.get().open) return;
      if (os.get().screen === 'home') openApp(d.app, undefined, d.data);
      else pendingApp = { app: d.app, data: d.data };
      return;
    }
    case 'notify':
      if (os.get().open) pushNotify(data as NotifyMsg);
      return;
    case 'clock':
      if (os.get().open && data) os.set({ clock: data as ClockSnap, clockAt: performance.now() });
      return;
    case 'apps':
      if (os.get().open && os.get().screen === 'home') void refreshApps();
      return;
    case 'appEvent':
      if (os.get().open) window.dispatchEvent(new CustomEvent('pop-app-event', { detail: data }));
      return;
    case 'share':
      if (os.get().open) window.dispatchEvent(new CustomEvent('pop-share-offer', { detail: data }));
      return;
    case 'market':
      if (os.get().open) window.dispatchEvent(new CustomEvent('pop-market', { detail: data }));
      return;
    case 'message': {
      const d = data as { read?: string; from?: string; body?: string; vm?: boolean } | null;
      if (!os.get().open || !d) return;
      window.dispatchEvent(new CustomEvent('pop-message', { detail: d }));
      if (!d.read && os.get().app !== 'messages') pushNotify({ app: d.vm ? 'telephone' : 'messages', title: d.from, text: d.body });
      return;
    }
    case 'call': {
      const d = data as { state?: string } | null;
      if (!os.get().open || !d) return;
      if (d.state === 'ring' && os.get().app !== 'telephone') {
        if (os.get().screen === 'home') openApp('telephone', undefined, { ring: d });
        else pendingApp = { app: 'telephone', data: { ring: d } };
      } else window.dispatchEvent(new CustomEvent('pop-call', { detail: d }));
      return;
    }
    case 'waypoint':
      if (os.get().open) window.dispatchEvent(new CustomEvent('pop-waypoint', { detail: data }));
      return;
    case 'weather':
      if (os.get().open && data) os.set({ weather: data as Weather });
      return;
    default:
      return;
  }
}

// Une appli (Messages, Contacts) demande à ouvrir une autre appli (Téléphone) : seulement tablette ouverte et écran d'accueil.
if (typeof window !== 'undefined') {
  window.addEventListener('pop-open-app', (e) => {
    const d = (e as CustomEvent).detail as { app?: string; data?: unknown } | null;
    if (d && typeof d.app === 'string' && os.get().open && os.get().screen === 'home') openApp(d.app, undefined, d.data);
  });
}
