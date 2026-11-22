// Météo : le jeu donne le type, la pluie, le vent et l'heure ; tout le reste (autres lieux, prévisions, indices) est dérivé
// de façon déterministe (aucun hasard) pour qu'une même météo donne toujours le même affichage.

export type Sky = 'S' | 'C' | 'R' | 'N';

export interface WeatherIn {
  temp: number;
  kind: string;
  hi?: number;
  lo?: number;
  wind?: number;
  deg?: number;
  rain?: number;
}

export interface Place {
  id: string;
  name: string;
  /** Écart de température avec le lieu de référence. */
  dt: number;
  hum: number;
  vis: number;
  pres: number;
  windMul: number;
  windAdd: number;
  rise: string;
  set: string;
  /** Motif de ciel des 10 jours (la première lettre est remplacée par le ciel actuel). */
  pat: string;
}

export const PLACES: Place[] = [
  { id: 'ls', name: 'Los Santos', dt: 0, hum: 48, vis: 16, pres: 1016, windMul: 1, windAdd: 0, rise: '06:24', set: '17:08', pat: 'SSCSSSCSSS' },
  { id: 'ss', name: 'Sandy Shores', dt: 9, hum: 14, vis: 24, pres: 1011, windMul: 0.7, windAdd: 2, rise: '06:19', set: '17:12', pat: 'SSSSCSSSSS' },
  { id: 'pb', name: 'Paleto Bay', dt: -9, hum: 82, vis: 7, pres: 1004, windMul: 1.6, windAdd: 8, rise: '06:31', set: '17:01', pat: 'RCRCCRCCSC' },
  { id: 'mc', name: 'Mont Chiliad', dt: -24, hum: 71, vis: 5, pres: 968, windMul: 1.3, windAdd: 6, rise: '06:27', set: '17:04', pat: 'NNCNCNNCNN' },
];

/** Famille du jeu (clear, clouds, rain, thunder, fog, snow) vers les 4 ciels de la maquette. */
export function skyOf(kind: string): Sky {
  if (kind === 'snow') return 'N';
  if (kind === 'rain' || kind === 'thunder') return 'R';
  if (kind === 'clear') return 'S';
  return 'C';
}

const STEP_WET: Record<Sky, Sky> = { S: 'C', C: 'R', R: 'R', N: 'N' };
const STEP_COLD: Record<Sky, Sky> = { S: 'C', C: 'N', R: 'N', N: 'N' };
const MILD: Record<Sky, Sky> = { S: 'S', C: 'S', R: 'C', N: 'C' };

/** Le jeu n'a qu'une météo : les autres lieux en déduisent la leur (plus sec au désert, plus humide au nord, plus froid en altitude). */
export function placeSky(kind: string, id: string): Sky {
  const s = skyOf(kind);
  if (id === 'ss') return MILD[s];
  if (id === 'pb') return STEP_WET[s];
  if (id === 'mc') return STEP_COLD[s];
  return s;
}

export interface Now {
  sky: Sky;
  temp: number;
  hi: number;
  lo: number;
  wind: number;
  /** Cap du vent en degrés. */
  deg: number;
  /** Point cardinal (0 = N, 1 = NE, ... 7 = NO). */
  dir: number;
  hum: number;
  vis: number;
  pres: number;
  uv: number;
  dew: number;
}

const HUM: Record<Sky, number> = { S: 0, C: 10, R: 30, N: 15 };
const VIS: Record<Sky, number> = { S: 0, C: 3, R: 6, N: 5 };
const PRES: Record<Sky, number> = { S: 0, C: 4, R: 10, N: 6 };
const UV: Record<Sky, number> = { S: 8, C: 4, R: 2, N: 1 };

export const isNight = (h: number): boolean => h >= 19 || h < 6;
export const compass = (deg: number): number => Math.round((((deg % 360) + 360) % 360) / 45) % 8;

export function placeNow(w: WeatherIn, place: Place, hour: number): Now {
  const sky = placeSky(w.kind, place.id);
  const temp = Math.round(w.temp + place.dt);
  const hi = Math.round((w.hi ?? w.temp + 4) + place.dt);
  const lo = Math.round((w.lo ?? w.temp - 4) + place.dt);
  const deg = Math.round(w.deg ?? 270);
  const hum = Math.max(5, Math.min(99, place.hum + HUM[sky]));
  const uvBase = UV[sky] + (place.id === 'ss' ? 2 : place.id === 'mc' ? 1 : 0);
  return {
    sky, temp, hi, lo, deg, dir: compass(deg), hum,
    wind: Math.max(0, Math.round((w.wind ?? 10) * place.windMul + place.windAdd)),
    vis: Math.max(1, place.vis - VIS[sky]),
    pres: place.pres - PRES[sky],
    uv: isNight(hour) ? 0 : Math.max(1, Math.min(11, uvBase)),
    dew: Math.round(temp - (100 - hum) / 5),
  };
}

export interface HourRow { label: 'now' | number; moon: boolean; sky: Sky; temp: number; pct: number | null }

/** 12 heures à partir de l'heure locale : courbe de température sinusoïdale (maximum vers 15 h), lune la nuit par ciel dégagé. */
export function hourly(n: Now, hour: number): HourRow[] {
  const mid = (n.hi + n.lo) / 2;
  const amp = (n.hi - n.lo) / 2;
  const rows: HourRow[] = [];
  for (let i = 0; i < 12; i++) {
    const h = (hour + i) % 24;
    rows.push({
      label: i === 0 ? 'now' : h,
      moon: isNight(h) && n.sky === 'S',
      sky: n.sky,
      temp: Math.round(mid + amp * Math.sin(((h - 9) / 24) * 2 * Math.PI)),
      pct: n.sky === 'R' ? 40 + ((i * 13) % 50) : null,
    });
  }
  return rows;
}

const DH = [0, 1, -1, 2, 0, -2, -1, 1, 2, 0];
const DL = [0, 0, -1, 1, 0, -1, -2, 0, 1, 0];

export interface DayRow { sky: Sky; hi: number; lo: number }

/** Prévisions sur 10 jours : le jour 0 est le ciel actuel, les suivants viennent du motif du lieu et de petits écarts fixes. */
export function forecast(n: Now, place: Place): DayRow[] {
  return place.pat.split('').map((c, i) => ({ sky: (i === 0 ? n.sky : (c as Sky)), hi: n.hi + DH[i]!, lo: n.lo + DL[i]! }));
}

export function tempColor(v: number): string {
  return v <= 5 ? '#5ac8fa' : v <= 14 ? '#30d158' : v <= 22 ? '#ffd60a' : v <= 30 ? '#ff9f0a' : '#ff453a';
}

export const toUnit = (v: number, fahrenheit: boolean): number => (fahrenheit ? Math.round((v * 9) / 5 + 32) : Math.round(v));

/** Barre de température d'un jour : position et largeur (en %) dans l'étendue des 10 jours. */
export function bars(rows: DayRow[]): Array<{ left: number; width: number }> {
  const gmin = Math.min(...rows.map((r) => r.lo));
  const gmax = Math.max(...rows.map((r) => r.hi));
  const span = gmax - gmin || 1;
  return rows.map((r) => ({ left: Math.round(((r.lo - gmin) / span) * 100), width: Math.max(8, Math.round(((r.hi - r.lo) / span) * 100)) }));
}

export const SKY_GRAD_LIGHT: Record<Sky, string> = {
  S: 'linear-gradient(180deg,#2c7be5 0%,#5aaef0 55%,#a9d8f7 100%)', C: 'linear-gradient(180deg,#5d6f88 0%,#8798ae 55%,#b6c3d3 100%)',
  R: 'linear-gradient(180deg,#34445c 0%,#52657f 55%,#7a8ca3 100%)', N: 'linear-gradient(180deg,#6f86a3 0%,#a8bbd1 55%,#dfe8f1 100%)',
};
export const SKY_GRAD_DARK: Record<Sky, string> = {
  S: 'linear-gradient(180deg,#0b1f4d 0%,#17408a 55%,#2d6bb8 100%)', C: 'linear-gradient(180deg,#1c2430 0%,#2c3646 55%,#3f4c60 100%)',
  R: 'linear-gradient(180deg,#10161f 0%,#1d2836 55%,#2b394b 100%)', N: 'linear-gradient(180deg,#2a3646 0%,#44566c 55%,#6a7f97 100%)',
};

export const SKY_ICON: Record<Sky | 'M', string> = {
  S: 'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4',
  C: 'M7 18a4 4 0 0 1-.5-8A6 6 0 0 1 18 9.5 4.3 4.3 0 0 1 17 18z',
  R: 'M7 15a4 4 0 0 1-.5-8A6 6 0 0 1 18 6.5 4.3 4.3 0 0 1 17 15zM8 18l-1 3M12 18l-1 3M16 18l-1 3',
  N: 'M7 15a4 4 0 0 1-.5-8A6 6 0 0 1 18 6.5 4.3 4.3 0 0 1 17 15zM8 19h.01M12 19h.01M16 19h.01M10 21.5h.01M14 21.5h.01',
  M: 'M20 14.5A8 8 0 1 1 9.5 4 6.5 6.5 0 0 0 20 14.5z',
};
export const SKY_ICON_COLOR: Record<Sky | 'M', string> = { S: '#ffd60a', C: '#ffffff', R: '#cfe8ff', N: '#ffffff', M: '#e8e8ff' };
