// Thème : clair/sombre, transparence du verre, fonds d'écran. Fonctions pures (testées).
export function glassVars(glass: number): { ga: string; gad: string } {
  const g = Math.max(0, Math.min(100, glass)) / 100;
  return { ga: (0.12 + g * 0.6).toFixed(2), gad: (0.18 + g * 0.55).toFixed(2) };
}

/** Teinte d'accent reçue du jeu (`Config.AccentColor`) : seulement #rgb, #rrggbb ou #rrggbbaa. */
export function safeAccent(color: unknown): string | null {
  return typeof color === 'string' && /^#[0-9a-f]{3,8}$/i.test(color) ? color : null;
}

export function appBackground(dark: boolean): string {
  return dark ? '#000000' : '#f2f2f7';
}

export const WALL_AUTO = 'auto';

const AURORA_DARK =
  'radial-gradient(55% 75% at 12% 88%, #a3195f 0%, transparent 62%), radial-gradient(55% 70% at 88% 14%, #2a3fa8 0%, transparent 60%), radial-gradient(45% 55% at 62% 72%, #5e2290 0%, transparent 60%), linear-gradient(160deg,#090b20,#170818)';
const AURORA_LIGHT =
  'radial-gradient(55% 75% at 12% 88%, #ff6fb0 0%, transparent 62%), radial-gradient(55% 70% at 88% 14%, #6f9dff 0%, transparent 60%), radial-gradient(45% 55% at 62% 72%, #ffb067 0%, transparent 60%), linear-gradient(160deg,#c6d4ff,#f7c3df)';

/** Collection POP (Réglages > Fond d'écran). L'indice sert d'identifiant dans les réglages. */
export const WALLPAPERS: string[] = [
  'linear-gradient(160deg,#c6d4ff,#f7c3df)',
  'linear-gradient(160deg,#090b20,#170818)',
  'radial-gradient(70% 90% at 30% 80%, #ff2e88 0%, transparent 60%), linear-gradient(160deg,#1a0b2e,#0b1a3a)',
  'radial-gradient(60% 80% at 70% 30%, #ffd60a 0%, transparent 60%), linear-gradient(160deg,#ff8d28,#ff383c)',
  'radial-gradient(60% 80% at 20% 20%, #34c759 0%, transparent 60%), linear-gradient(160deg,#0b3a2e,#06201a)',
  'linear-gradient(160deg,#e3e3e8,#a3a3aa)',
  'radial-gradient(60% 80% at 80% 80%, #00c0e8 0%, transparent 60%), linear-gradient(160deg,#0a2a6b,#04102b)',
  'radial-gradient(60% 80% at 50% 50%, #cb30e0 0%, transparent 60%), linear-gradient(160deg,#2a0b3a,#120518)',
];

export function wallpaper(id: string | undefined, dark: boolean): string {
  const i = id === undefined || id === WALL_AUTO ? -1 : Number(id);
  if (Number.isInteger(i) && i >= 0 && i < WALLPAPERS.length) return WALLPAPERS[i] as string;
  return dark ? AURORA_DARK : AURORA_LIGHT;
}

/** Couleurs des Réglages et des applis « feuille » (maquette Reglages). */
export function palette(dark: boolean) {
  return dark
    ? { bg: '#000000', side: '#000000', cell: '#1c1c1e', fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)', fill: '#3a3a3c' }
    : { bg: '#f2f2f7', side: '#f2f2f7', cell: '#ffffff', fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)', fill: '#e3e3e8' };
}

export type Finish = 'Noir sidéral' | 'Argent' | 'Rose POP' | 'Bleu nuit';
export const FINISHES: Record<Finish, { body: string; edge: string; btn: string }> = {
  'Noir sidéral': { body: 'linear-gradient(135deg,#3a3a3d,#1b1b1d 45%,#2c2c2f)', edge: 'rgba(255,255,255,.12)', btn: '#2a2a2d' },
  Argent: { body: 'linear-gradient(135deg,#f1f2f4,#c9cbcf 45%,#e3e4e7)', edge: 'rgba(255,255,255,.7)', btn: '#c4c6ca' },
  'Rose POP': { body: 'linear-gradient(135deg,#ff7ab5,#d81b70 45%,#ff4f9b)', edge: 'rgba(255,255,255,.35)', btn: '#e0307f' },
  'Bleu nuit': { body: 'linear-gradient(135deg,#3b4a6b,#1a2238 45%,#2e3b58)', edge: 'rgba(255,255,255,.18)', btn: '#27324d' },
};
