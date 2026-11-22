import type { DeviceSettings, StoreEntry } from '../kit';
// Contrat NUI <-> client (SPEC section 8). Seuls ces types décrivent ce que Lua envoie.
export interface ClockSnap {
  h: number;
  m: number;
  d: number;
  /** Mois 1 à 12 (le client ajoute 1 au natif GetClockMonth, 0 à 11). */
  mo: number;
  y: number;
  /** Millisecondes réelles par minute de jeu. */
  msPerMin: number;
}

export interface Weather {
  temp: number;
  /** clear | clouds | rain | thunder | fog | snow */
  kind: string;
  hi?: number;
  lo?: number;
  city?: string;
  rain?: number;
  wind?: number;
  deg?: number;
}

export type Settings = DeviceSettings;
export interface WidgetData {
  /** Prochains événements du calendrier (fournis par le serveur au démarrage). */
  events?: Array<{ title: string; time: string; color?: string }>;
  reminders?: Array<{ id: number | string; text: string; done: boolean }>;
}

/** Fiche d'une appli (catalogue de la Boutique, `store:list`). Les applis natives n'ont que id, cat, system, installed. */
export type StoreItem = StoreEntry;
export type ApiAppInfo = StoreItem & { api: true; name: string; page: string };

export interface Boot {
  serial: string;
  name: string;
  phone?: string;
  battery: number;
  settings: Settings;
  /** Identifiants des applis installées. */
  apps: string[];
  badges: Record<string, number>;
  /** Informations de l'appareil. */
  model?: string;
  os?: string;
  created?: number;
  lastOpen?: number;
  /** Fiches des applis d'autres ressources (RegisterApp) installées. */
  apiApps?: ApiAppInfo[];
  widgets?: WidgetData;
  music?: { title: string; artist: string; playing: boolean } | null;
}

export interface OpenData {
  serial?: string;
  needSetup?: boolean;
  locked?: boolean;
  boot?: Boot;
  locale?: Record<string, string | boolean>;
  rtl?: boolean;
  accent?: string;
  /** Langue de la tablette (à ajouter côté client : voir PROGRESS). */
  lang?: string;
  /** Afficher la coque (mode navigateur de développement). Absent en jeu : pas de coque. */
  shell?: boolean;
  clock: ClockSnap;
  weather?: Weather;
  app?: { app: string; data?: unknown };
}

export interface NotifyMsg {
  app: string;
  title?: string;
  titleKey?: string;
  bodyKey?: string;
  args?: Array<string | number>;
  text?: string;
  sound?: string;
}

export interface NuiEnvelope {
  action: string;
  data?: unknown;
}
