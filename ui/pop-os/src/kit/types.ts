// Contrat appareil <-> applis : tout ce qu'une appli a le droit de connaître.
export type Layout = 'regular' | 'compact';

export type TFn = (key: string, ...args: Array<string | number>) => string;

export interface NuiResult {
  ok: boolean;
  err?: string;
  [k: string]: unknown;
}

export interface NuiApi {
  /** Relais générique vers le callback serveur `pop_tablet:<name>` (liste blanche côté client). */
  call: <T extends NuiResult = NuiResult>(name: string, data?: unknown) => Promise<T>;
  /** Callback NUI direct (`tablet:<nom>`). */
  post: <T = unknown>(action: string, data?: unknown) => Promise<T | null>;
}

export interface NotifyInput {
  app: string;
  title: string;
  body: string;
}

export interface AppProps {
  id: string;
  layout: Layout;
  dark: boolean;
  t: TFn;
  nui: NuiApi;
  close: () => void;
  /** Données transmises par `OpenApp` (API). */
  data?: unknown;
}

export interface AppManifest {
  id: string;
  nameKey: string;
  domain: 'communication' | 'personal' | 'media' | 'tools' | 'api';
  /** Appli système : non retirable. */
  system?: boolean;
  /** Appli qui exige le réseau : coupée par Mode Avion / Wi-Fi coupé. */
  online?: boolean;
  load: () => Promise<{ default: React.ComponentType<AppProps> }>;
}

/** Réglages de l'appareil, partagés avec les applis (Réglages) par le contexte `SettingsContext`. */
export interface DeviceSettings {
  lang?: string;
  dark?: boolean;
  glass?: number;
  bright?: number;
  wall?: string;
  blur?: boolean;
  mail?: string;
  air?: boolean;
  wifi?: boolean;
  bt?: boolean;
  rot?: boolean;
  mirror?: boolean;
  share?: boolean;
  focus?: boolean;
  bold?: boolean;
  vol?: number;
  ring?: number;
  /** Notifications par appli : `false` = coupées. */
  notif?: Record<string, boolean>;
}

/** Fiche de la Boutique (réponse de `store:list`). Les applis natives n'ont que id, cat, system, installed. */
export interface StoreEntry {
  id: string;
  cat?: string;
  system?: boolean;
  installed: boolean;
  api?: boolean;
  name?: string;
  icon?: string;
  color?: string;
  page?: string;
}

export interface SettingsApi {
  settings: DeviceSettings;
  name: string;
  serial: string;
  battery: number;
  lang: string;
  /** Applique un réglage tout de suite et le fait enregistrer. */
  set: (patch: DeviceSettings) => void;
  setLang: (lang: string) => void;
  changeCode: (oldCode: string, newCode: string) => Promise<{ ok: boolean; err?: string }>;
  /** Identifiants des applis installées. */
  apps: string[];
  /** Retire une appli (le serveur refuse les applis système). */
  /** Installe une appli (le serveur vérifie le métier et le réseau). */
  install: (item: StoreEntry) => Promise<{ ok: boolean; err?: string }>;
  uninstall: (id: string) => Promise<{ ok: boolean; err?: string }>;
  rename: (name: string) => Promise<{ ok: boolean; err?: string }>;
  /** Informations de l'appareil (numéro, modèle, système, dates en secondes). */
  info: { phone: string; model: string; os: string; created: number; lastOpen: number };
}

export const LANGUAGES = ['en', 'fr', 'es', 'de', 'it', 'pt', 'nl', 'pl', 'tr', 'ar'] as const;
export const LANGUAGE_NAMES: Record<(typeof LANGUAGES)[number], string> = {
  en: 'English', fr: 'Français', es: 'Español', de: 'Deutsch', it: 'Italiano', pt: 'Português', nl: 'Nederlands', pl: 'Polski', tr: 'Türkçe', ar: 'العربية',
};
