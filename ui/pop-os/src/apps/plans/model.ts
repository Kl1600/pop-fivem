// Plans : lieux (envoyés par le serveur), recherche, durée et distance d'un trajet, carte stylisée.

export interface PlacePin {
  id: string;
  name: string;
  short: string;
  area: string;
  cat: string;
  addr: string;
  phone: string;
  /** 'always', 'h24' ou l'heure de fermeture. */
  hours: string;
  icon: string;
  col: string;
  x: number;
  y: number;
  z: number;
  mx: number;
  my: number;
}

export type Mode = 'home' | 'place' | 'route' | 'nav';
export type Travel = 'car' | 'walk';
export type MapKind = 'std' | 'sat' | 'tr';

/** Position de départ de la carte stylisée tant que le jeu n'a pas répondu (point de la maquette). */
export const START = { mx: 1000, my: 860 };
export const MAP_W = 2000;
export const MAP_H = 1500;

export const ICONS: Record<string, string> = {
  house: 'M4 11l8-7 8 7v9H4zM10 20v-6h4v6', shield: 'M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6z', wrench: 'M15 5a4 4 0 0 0-4 5L4 17l3 3 7-7a4 4 0 0 0 5-4l-3 3-2-1-1-2z',
  cross: 'M9 4h6v5h5v6h-5v5H9v-5H4V9h5z', bank: 'M3 10l9-6 9 6M5 10v8M9 10v8M15 10v8M19 10v8M3 20h18', casino: 'M5 5h14v14H5zM9 9h.01M15 9h.01M9 15h.01M15 15h.01M12 12h.01',
  pier: 'M3 17h18M6 17v-6M12 17v-6M18 17v-6M3 11h18', cup: 'M5 9h12v6a4 4 0 0 1-4 4H9a4 4 0 0 1-4-4zM17 10h2a2 2 0 0 1 0 4h-2', pin: 'M12 21s7-6 7-11a7 7 0 1 0-14 0c0 5 7 11 7 11zM12 7a3 3 0 1 0 0 6 3 3 0 0 0 0-6z',
};

export const iconOf = (p: PlacePin): string => ICONS[p.icon] ?? ICONS.pin!;

/** Recherche dans le nom, la catégorie (texte traduit), l'adresse et le quartier. `catLabel` donne le texte de la catégorie. */
export function search(places: PlacePin[], query: string, catLabel: (cat: string) => string, nameOf: (p: PlacePin) => string): PlacePin[] {
  const q = query.trim().toLowerCase();
  if (!q) return [];
  return places.filter((p) => `${nameOf(p)} ${catLabel(p.cat)} ${p.addr} ${p.area}`.toLowerCase().includes(q));
}

export const byId = (places: PlacePin[], id: string): PlacePin | undefined => places.find((p) => p.id === id);
export const pick = (places: PlacePin[], ids: string[]): PlacePin[] => ids.map((id) => byId(places, id)).filter((p): p is PlacePin => !!p);

/** Distance à vol d'oiseau en kilomètres, estimée sur la carte stylisée (échelle de la maquette). */
export function estimateKm(from: { mx: number; my: number }, to: { mx: number; my: number }): number {
  return (Math.abs(to.mx - from.mx) + Math.abs(to.my - from.my)) * 0.0042;
}

export interface Trip { km: number; min: number; arrival: string }

/** Durée (voiture 38 km/h de moyenne en ville, à pied 5 km/h) et heure d'arrivée à partir de l'heure locale. */
export function tripOf(km: number, travel: Travel, hour: number, minute: number): Trip {
  const min = Math.max(1, Math.round((km / (travel === 'walk' ? 5 : 38)) * 60));
  const total = hour * 60 + minute + min;
  const h = Math.floor(total / 60) % 24;
  return { km, min, arrival: `${String(h).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}` };
}

export const kmText = (km: number, lang: string): string => `${new Intl.NumberFormat(lang, { minimumFractionDigits: 1, maximumFractionDigits: 1 }).format(km)} km`;

/** Position d'un point du monde sur la carte stylisée (même transformation affine que shared/places.lua). */
export function mapPoint(x: number, y: number): { mx: number; my: number } {
  return { mx: Math.max(60, Math.min(1940, Math.round(1090 + (x - 441) * 0.17))), my: Math.max(60, Math.min(1440, Math.round(790 - (y + 982) * 0.17))) };
}

export const clampPan = (tx: number, ty: number): { tx: number; ty: number } => ({ tx: Math.max(-326, Math.min(326, tx)), ty: Math.max(-240, Math.min(240, ty)) });

export interface MapStyle { land: string; sea: string; park: string; road: string; roadCase: string; minor: string; beach: string; label: string; halo: string; pinText: string; transit: number }

export function mapStyle(kind: MapKind, dark: boolean): MapStyle {
  if (kind === 'sat') return { land: '#4a5a3c', sea: '#143a52', park: '#2d5a2a', road: '#938d7d', roadCase: '#5c574b', minor: '#5d6a4b', beach: '#c4b48a', label: '#ffffff', halo: '#2b3320', pinText: '#ffffff', transit: 0 };
  if (kind === 'tr') {
    return dark
      ? { land: '#1c1d20', sea: '#0e2433', park: '#1e3a2b', road: '#34363b', roadCase: '#26282c', minor: '#25272b', beach: '#2a4a5e', label: '#8e8e93', halo: '#1c1d20', pinText: '#e5e5ea', transit: 1 }
      : { land: '#f5f3ee', sea: '#b3d9e6', park: '#d6ebca', road: '#ececec', roadCase: '#dcd8cc', minor: '#f8f6f2', beach: '#e6d9b0', label: '#7a7466', halo: '#f5f3ee', pinText: '#2b2b2b', transit: 1 };
  }
  return dark
    ? { land: '#1f2124', sea: '#0e2433', park: '#1e3a2b', road: '#44474e', roadCase: '#2b2d31', minor: '#2a2c30', beach: '#2a4a5e', label: '#8e8e93', halo: '#1f2124', pinText: '#e5e5ea', transit: 0 }
    : { land: '#f1eee5', sea: '#a9d4e2', park: '#cde8bf', road: '#ffffff', roadCase: '#d8d3c5', minor: '#faf8f3', beach: '#e6d9b0', label: '#7a7466', halo: '#f1eee5', pinText: '#2b2b2b', transit: 0 };
}

export const ROADS: Array<[string, number]> = [
  ['M610 200C640 420 590 560 640 700S700 960 640 1260', 16], ['M700 540C1000 520 1300 560 1760 500', 20], ['M1000 160C1010 600 990 900 1010 1360', 22],
  ['M700 1000C900 900 1100 820 1300 760S1600 700 1760 660', 22], ['M760 380C900 600 1000 800 1100 1300', 14], ['M1300 200C1320 500 1340 800 1380 1300', 14],
];
export const PARKS = [{ x: 780, y: 280, w: 300, h: 190, r: 60 }, { x: 1180, y: 330, w: 340, h: 150, r: 70 }, { x: 1120, y: 1040, w: 230, h: 140, r: 50 }, { x: 1440, y: 800, w: 190, h: 120, r: 40 }];
export const LABELS: Array<[string, number, number, number]> = [
  ['VINEWOOD', 1260, 450, 22], ['ROCKFORD HILLS', 920, 500, 20], ['DEL PERRO', 760, 860, 22], ['VESPUCCI', 740, 1060, 22], ['DOWNTOWN', 1040, 640, 22],
  ['MISSION ROW', 1090, 860, 18], ['LA MESA', 1360, 1010, 22], ['DAVIS', 960, 1180, 22], ['MIRROR PARK', 1480, 420, 20], ['OCÉAN', 300, 760, 28],
];

/** Tracé de l'itinéraire sur la carte stylisée : en L (vertical puis horizontal), comme la maquette. */
export function routePoints(from: { mx: number; my: number }, to: { mx: number; my: number }): string {
  return `${from.mx},${from.my} ${from.mx},${to.my} ${to.mx},${to.my}`;
}
