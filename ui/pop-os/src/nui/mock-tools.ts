// Plans, Traduire, Bourse et carte simulés (mémoire seulement) : mêmes réponses que les callbacks du serveur et du client.
type Json = Record<string, unknown>;

const PLACES = [
  { id: 'home', name: '', short: '', area: 'Vinewood', cat: 'home', addr: '3 Vinewood Hills Dr', phone: '(555) 0113', hours: 'always', icon: 'house', col: '#0a84ff', x: -174, y: 502, z: 137, mx: 1210, my: 560 },
  { id: 'police', name: 'Mission Row Police Station', short: 'Police', area: 'Mission Row', cat: 'public', addr: '1 Sinner St, Mission Row', phone: '(555) 0100', hours: 'h24', icon: 'shield', col: '#30509c', x: 441, y: -982, z: 30.7, mx: 1090, my: 790 },
  { id: 'garage', name: 'La Mesa Garage', short: 'Garage', area: 'La Mesa', cat: 'garage', addr: '27 Popular St, La Mesa', phone: '(555) 0127', hours: '19', icon: 'wrench', col: '#ff8d28', x: 727, y: -1088, z: 22.2, mx: 1330, my: 930 },
  { id: 'pillbox', name: 'Pillbox Hospital', short: 'Hospital', area: 'Pillbox Hill', cat: 'hospital', addr: '8 Strawberry Ave', phone: '(555) 0112', hours: 'h24', icon: 'cross', col: '#ff383c', x: 298, y: -584, z: 43.3, mx: 1150, my: 700 },
  { id: 'fleeca', name: 'Fleeca Bank, Legion Square', short: 'Fleeca', area: 'Legion Square', cat: 'bank', addr: '4 Legion Square', phone: '(555) 0150', hours: '17', icon: 'bank', col: '#34c759', x: 149, y: -1040, z: 29.4, mx: 1020, my: 700 },
  { id: 'casino', name: 'Diamond Casino', short: 'Casino', area: 'Vinewood', cat: 'casino', addr: '1 Diamond Blvd', phone: '(555) 0199', hours: 'h24', icon: 'casino', col: '#cb30e0', x: 925, y: 46, z: 81.1, mx: 1520, my: 640 },
  { id: 'pier', name: 'Del Perro Pier', short: 'Pier', area: 'Del Perro', cat: 'tourist', addr: 'Del Perro Beach', phone: '(555) 0160', hours: 'always', icon: 'pier', col: '#00c0e8', x: -1850, y: -1230, z: 13, mx: 640, my: 760 },
  { id: 'customs', name: 'Los Santos Customs', short: 'Customs', area: 'La Mesa', cat: 'garage', addr: '12 Power St', phone: '(555) 0188', hours: '20', icon: 'wrench', col: '#ff8d28', x: -365, y: -131, z: 38.7, mx: 1250, my: 800 },
  { id: 'cafe', name: 'Vinewood Cafe', short: 'Cafe', area: 'Vinewood', cat: 'cafe', addr: '19 Vinewood Blvd', phone: '(555) 0131', hours: '23', icon: 'cup', col: '#a2845e', x: 291, y: 180, z: 104, mx: 1130, my: 540 },
];

const STOCKS = [
  { sym: 'BAWS', name: 'Bawsaq', index: true, price: 11842.3, open: 11794.9, volume: 1800, ch: [0.9, 2.2, 4.1, 9.3, 55] },
  { sym: 'MAZE', name: 'Maze Bank', price: 412.6, open: 405.3, volume: 4.2, cap: 86.4, per: 14.2, div: 2.1, ch: [3.1, 5.4, 9.8, 22.5, 140] },
  { sym: 'FLCA', name: 'Fleeca Bank', price: 87.35, open: 87.9, volume: 2.9, cap: 21.7, per: 11.8, div: 3.4, ch: [-1.2, 0.8, -3.4, 6.1, 35] },
  { sym: 'LIFI', name: 'LifeInvader', price: 156.2, open: 151.3, volume: 9.6, cap: 54, per: 32.5, ch: [6.5, -2.1, 14, 48, 310] },
  { sym: 'PISS', name: 'Pisswasser', price: 64.8, open: 65.7, volume: 3.1, cap: 12.3, per: 17, div: 4.8, ch: [-0.3, -4.8, -7.9, -12.6, -20] },
  { sym: 'AMMU', name: 'Ammu-Nation', price: 203.45, open: 201.6, volume: 1.4, cap: 29.8, per: 19.4, div: 1.6, ch: [1.7, 3.3, 5.2, 11.4, 60] },
  { sym: 'VAPD', name: 'Vapid Motors', price: 98.1, open: 96.1, volume: 5.5, cap: 33.2, per: 9.7, div: 2.9, ch: [2.4, 7.7, 12.3, 30.2, 85] },
];

interface Fav { src: string; dst: string; s: string; t: string }
let favPlaces: string[] = [];
let recents: string[] = [];
let favTr: Fav[] = [];
let watch: string[] = [];
let route = false;
let service = false;

export function seedTools(): void {
  favPlaces = ['home', 'police', 'garage'];
  recents = [];
  favTr = [];
  watch = STOCKS.map((s) => s.sym);
  route = false;
  service = false;
}
seedTools();

/** Simule un service de traduction configuré sur le serveur (tests). */
export function setTranslateService(on: boolean): void { service = on; }
export const routeActive = (): boolean => route;

export const TOOLS_CALLS = new Set([
  'plans:state', 'plans:fav', 'plans:recent', 'translate:run', 'translate:favs', 'translate:fav', 'stocks:subscribe', 'stocks:unsubscribe', 'stocks:watch',
]);

export function toolsCall(name: string, raw: unknown): unknown {
  const a = (typeof raw === 'object' && raw ? raw : {}) as Json;
  switch (name) {
    case 'plans:state': return { ok: true, places: PLACES, favs: favPlaces, recents };
    case 'plans:fav': {
      if (!PLACES.some((p) => p.id === a.id) || typeof a.on !== 'boolean') return { ok: false, err: 'err_payload' };
      favPlaces = favPlaces.filter((x) => x !== a.id);
      if (a.on) favPlaces = [...favPlaces, String(a.id)];
      return { ok: true, favs: favPlaces };
    }
    case 'plans:recent':
      if (!PLACES.some((p) => p.id === raw)) return { ok: false, err: 'err_payload' };
      recents = [String(raw), ...recents.filter((x) => x !== raw)].slice(0, 5);
      return { ok: true, recents };
    case 'translate:run': return service ? { ok: true, text: `[service] ${String(a.text)}`, cached: false } : { ok: false, err: 'err_unavailable' };
    case 'translate:favs': return { ok: true, items: favTr };
    case 'translate:fav': {
      const f = { src: String(a.src), dst: String(a.dst), s: String(a.s), t: String(a.t) };
      favTr = favTr.filter((x) => !(x.src === f.src && x.dst === f.dst && x.s === f.s));
      if (a.on) favTr = [...favTr, f];
      return { ok: true, items: favTr };
    }
    case 'stocks:subscribe': return { ok: true, items: STOCKS, watch, tick: 5 };
    case 'stocks:unsubscribe': return { ok: true };
    case 'stocks:watch': {
      if (!STOCKS.some((s) => s.sym === a.sym) || typeof a.on !== 'boolean') return { ok: false, err: 'err_payload' };
      watch = watch.filter((x) => x !== a.sym);
      if (a.on) watch = [...watch, String(a.sym)];
      return { ok: true, watch };
    }
    default: return { ok: false, err: 'err_unavailable' };
  }
}

/** Callback NUI `tablet:map` (client/map.lua) : position fixe, itinéraire à vol d'oiseau. */
export function mapCall(raw: unknown): unknown {
  const a = (typeof raw === 'object' && raw ? raw : {}) as Json;
  if (a.action === 'position') return { ok: true, x: 0, y: 0, z: 0, mx: 1000, my: 860, street: 'Alta St', zone: 'Alta' };
  if (a.action === 'route') { route = true; return { ok: true, meters: 1500, road: true }; }
  if (a.action === 'clear') { route = false; return { ok: true }; }
  if (a.action === 'pause') return { ok: true };
  return { ok: false, err: 'err_payload' };
}
