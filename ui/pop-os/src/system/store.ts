import { useSyncExternalStore } from 'react';
import { setApiApps } from '../apps/registry';
import { setExtraText } from '../i18n';
import { setCustomIcon } from '../kit';
import type { Boot, ClockSnap, OpenData, Settings, Weather } from '../nui/types';

// État du système, hors React : un seul magasin, aucun timer. Il est remis à zéro à la fermeture de la tablette.

export type Screen = 'lock' | 'code' | 'setup' | 'home';

export interface Notif {
  id: number;
  app: string;
  title: string;
  body: string;
  /** Date réelle de réception (Date.now). */
  at: number;
}

export interface OS {
  open: boolean;
  shell: boolean;
  lang: string;
  rtl: boolean;
  accent: string | null;
  server: Record<string, unknown>;
  serial: string | null;
  needSetup: boolean;
  mailDomain: string;
  screen: Screen;
  on: boolean;
  name: string;
  battery: number;
  boot: Boot | null;
  settings: Settings;
  apps: string[];
  badges: Record<string, number>;
  weather: Weather | null;
  clock: ClockSnap | null;
  clockAt: number;
  app: string | null;
  appData: unknown;
  org: { x: number; y: number };
  recents: string[];
  cc: boolean;
  nc: boolean;
  search: boolean;
  sw: boolean;
  edit: boolean;
  vol: number;
  hud: boolean;
  banner: Notif | null;
  notifs: Notif[];
  lockWait: number;
  codeError: string | null;
}

export const initialOS: OS = {
  open: false, shell: false, lang: 'en', rtl: false, accent: null, server: {}, serial: null, needSetup: false, mailDomain: 'pop.ls',
  screen: 'lock', on: true, name: '', battery: 100, boot: null, settings: {}, apps: [], badges: {}, weather: null,
  clock: null, clockAt: 0, app: null, appData: null, org: { x: 674, y: 509 }, recents: [],
  cc: false, nc: false, search: false, sw: false, edit: false, vol: 55, hud: false, banner: null, notifs: [],
  lockWait: 0, codeError: null,
};

type Listener = () => void;
let state: OS = initialOS;
const listeners = new Set<Listener>();

export const os = {
  get: (): OS => state,
  set(patch: Partial<OS> | ((s: OS) => Partial<OS>)): void {
    state = { ...state, ...(typeof patch === 'function' ? patch(state) : patch) };
    listeners.forEach((l) => l());
  },
  reset(): void {
    state = initialOS;
    listeners.forEach((l) => l());
  },
  subscribe(l: Listener): () => void {
    listeners.add(l);
    return () => listeners.delete(l);
  },
};

/** Lit une valeur du système ; le sélecteur doit renvoyer une valeur stable (primitive ou objet du magasin). */
export function useOS<T>(selector: (s: OS) => T): T {
  return useSyncExternalStore(os.subscribe, () => selector(state), () => selector(state));
}

export const DEFAULT_APPS = ['calendrier', 'photos', 'camera', 'horloge', 'meteo', 'plans', 'rappels', 'notes', 'fichiers', 'tableau', 'calculette', 'dictaphone', 'traduire', 'bourse', 'contacts', 'boutique', 'messages', 'telephone', 'mail', 'navigateur', 'musique', 'reglages'];
/** Applis du dock, dans l'ordre de la maquette. */
export const DOCK = ['messages', 'telephone', 'mail', 'navigateur', 'musique', 'reglages'];

/** Applis qui exigent le réseau : coupées par Mode Avion et Wi-Fi coupé (SPEC section 0). */
export const ONLINE_APPS: ReadonlySet<string> = new Set(['messages', 'telephone', 'navigateur', 'boutique']) // Mail : lecture permise hors ligne, envoi bloqué par le serveur;

export function applyOpen(d: OpenData, lang: string): void {
  const boot = d.boot ?? null;
  os.set({
    open: true,
    shell: d.shell === true,
    lang,
    rtl: d.rtl === true,
    accent: typeof d.accent === 'string' ? d.accent : null,
    server: (d.locale ?? {}) as Record<string, unknown>,
    serial: d.serial ?? null,
    needSetup: d.needSetup === true,
    mailDomain: typeof d.mailDomain === 'string' && d.mailDomain ? d.mailDomain : 'pop.ls',
    // Le serveur décide : session encore déverrouillée (`locked:false` + boot) = accueil, sinon écran verrouillé.
    screen: d.needSetup ? 'setup' : d.locked === false && boot ? 'home' : 'lock',
    on: true,
    weather: d.weather ?? null,
    clock: d.clock,
    clockAt: performance.now(),
    app: null,
    cc: false, nc: false, search: false, sw: false, edit: false, banner: null,
    codeError: null, lockWait: 0,
    ...(boot ? bootPatch(boot) : {}),
  });
}

/** Enregistre les applis d'autres ressources : registre, nom traduisible (`api.<id>`) et icône générique. */
export function applyApiApps(items: ReadonlyArray<{ id: string; name: string; page: string; color?: string }>): void {
  for (const it of items) {
    setExtraText(`api.${it.id}`, it.name);
    setCustomIcon(it.id, it.name, it.color);
  }
  setApiApps(items);
}

export function bootPatch(boot: Boot): Partial<OS> {
  applyApiApps((boot.apiApps ?? []).filter((a) => a.installed !== false));
  return {
    boot, name: boot.name, battery: boot.battery, settings: boot.settings ?? {},
    apps: boot.apps && boot.apps.length ? boot.apps : DEFAULT_APPS, badges: boot.badges ?? {},
  };
}
