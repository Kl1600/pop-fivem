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
