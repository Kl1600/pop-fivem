// Bourse : le marché est simulé par le serveur (cours en direct) ; les historiques des graphiques sont reconstruits ici de façon
// déterministe (même symbole et même période = même courbe), calés pour finir sur le cours en direct.

export interface Stock {
  sym: string;
  name: string;
  index?: boolean;
  price: number;
  /** Clôture de référence du jour. */
  open: number;
  /** Millions de titres échangés. */
  volume: number;
  /** Milliards de $. */
  cap?: number;
  per?: number;
  div?: number;
  /** Variations indicatives en % : 1 semaine, 1 mois, 3 mois, 1 an, 5 ans. */
  ch: number[];
}

export const PERIODS = ['1d', '1w', '1m', '3m', '1y', '5y'] as const;
export type Period = 0 | 1 | 2 | 3 | 4 | 5;
export const POINTS = [48, 56, 60, 70, 80, 90];
const VOL = [0.35, 0.6, 1.2, 2, 3.5, 5].map((v) => v / 100);

/** Variation en % sur la période : le jour est calculé sur le cours en direct, les autres viennent du serveur. */
export function changeOf(s: Stock, p: Period): number {
  if (p === 0) return s.open ? (s.price / s.open - 1) * 100 : 0;
  return s.ch[p - 1] ?? 0;
}

/** Série de la période `p` pour l'ordre `i` du symbole : marche pseudo-aléatoire fixe, ramenée à la variation visée et au cours courant. */
export function series(i: number, p: Period, s: Stock): number[] {
  const n = POINTS[p]!;
  const vol = VOL[p]!;
  const target = changeOf(s, p) / 100;
  let x = (i + 1) * 1237 + p * 911;
  const w = [1];
  for (let k = 1; k < n; k++) {
    x = (x * 9301 + 49297) % 233280;
    w.push(w[k - 1]! * (1 + (x / 233280 - 0.5) * 2 * vol));
  }
  const r = ((1 + target) * w[0]!) / w[n - 1]!;
  const v = w.map((q, k) => q * Math.pow(r, k / (n - 1)));
  const sc = s.price / v[n - 1]!;
  return v.map((q) => q * sc);
}

/** Courbe SVG (chemin) dans un cadre w x h avec des marges haute et basse. */
export function linePath(ser: number[], w: number, h: number, top: number, bot: number): { line: string; area: string; min: number; max: number } {
  const mn = Math.min(...ser);
  const mx = Math.max(...ser);
  const rng = mx - mn || 1;
  const px = (k: number) => (k / (ser.length - 1)) * w;
  const py = (q: number) => top + ((mx - q) / rng) * (h - top - bot);
  const line = ser.map((q, k) => `${k ? 'L' : 'M'}${px(k).toFixed(1)} ${py(q).toFixed(1)}`).join('');
  return { line, area: `${line}L${w} ${h}L0 ${h}Z`, min: mn, max: mx };
}

export function spark(ser: number[], w = 70, h = 30): string {
  const mn = Math.min(...ser);
  const mx = Math.max(...ser);
  return ser.map((q, k) => `${k ? 'L' : 'M'}${((k / (ser.length - 1)) * w).toFixed(1)} ${(3 + ((mx - q) / (mx - mn || 1)) * (h - 6)).toFixed(1)}`).join('');
}

/** Applique un paquet push `{ p: [cours en centimes] }` (ordre des symboles reçus à l'abonnement). Ignore un paquet invalide. */
export function applyTick(items: Stock[], p: unknown): Stock[] {
  if (!Array.isArray(p) || p.length !== items.length || !p.every((v) => typeof v === 'number' && Number.isFinite(v) && v > 0)) return items;
  return items.map((s, i) => ({ ...s, price: (p[i] as number) / 100 }));
}

export const fmt = (v: number, lang: string, d = 2): string => new Intl.NumberFormat(lang, { minimumFractionDigits: d, maximumFractionDigits: d }).format(v);
export const sign = (v: number, lang: string): string => `${v >= 0 ? '+' : '−'}${fmt(Math.abs(v), lang)}`;

/** Clés de texte des actualités : modèles par type de symbole et sens de la variation (le nom du titre se glisse dans le texte). */
export function newsKeys(s: Stock): Array<{ src: string; ago: [string, number?]; key: string }> {
  if (s.index) {
    return [
      { src: 'Weazel News', ago: ['bou.ago_h', 1], key: 'bou.news_idx1' }, { src: 'Bawsaq Daily', ago: ['bou.ago_h', 3], key: 'bou.news_idx2' },
      { src: 'Los Santos Standard', ago: ['bou.yesterday'], key: 'bou.news_idx3' },
    ];
  }
  const up = changeOf(s, 0) >= 0;
  const up3 = (s.ch[2] ?? 0) >= 0;
  return [
    { src: 'Weazel News', ago: ['bou.ago_h', 2], key: up ? 'bou.news_up1' : 'bou.news_down1' },
    { src: 'Bawsaq Daily', ago: ['bou.ago_h', 5], key: up3 ? 'bou.news_up2' : 'bou.news_down2' },
    { src: 'Los Santos Standard', ago: ['bou.yesterday'], key: 'bou.news_any3' },
  ];
}

export const NEWS_GRADS = ['linear-gradient(135deg,#ffae3d,#b8326f)', 'linear-gradient(135deg,#2c7be5,#56ccf2)', 'linear-gradient(135deg,#34c759,#0a6b4a)'];
