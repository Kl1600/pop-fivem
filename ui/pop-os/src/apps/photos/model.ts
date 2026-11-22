// Modèle de Photos : filtres, regroupement par année et par mois, aspect des formats. Fonctions pures, testées.

export interface PhotoItem {
  id: number;
  kind: string;
  rating: number;
  fav: boolean;
  fx: string;
  taken: number;
  thumb?: string | null;
}

export type FxId = 'none' | 'vivid' | 'mono' | 'drama' | 'sepia';
export const FX: Array<{ id: FxId; css: string }> = [
  { id: 'none', css: 'none' }, { id: 'vivid', css: 'saturate(1.6)' }, { id: 'mono', css: 'grayscale(1)' },
  { id: 'drama', css: 'contrast(1.4) saturate(1.2)' }, { id: 'sepia', css: 'sepia(.8)' },
];

/** Filtre CSS d'un identifiant de filtre (inconnu : aucun). */
export function fxCss(id: string): string {
  return FX.find((f) => f.id === id)?.css ?? 'none';
}

/** Rapport largeur / hauteur d'affichage selon le format de prise de vue. */
export function aspectOf(kind: string): string {
  if (kind === 'square') return '1 / 1';
  if (kind === 'portrait') return '3 / 4';
  if (kind === 'pano') return '21 / 9';
  return '4 / 3';
}

export interface Group { key: string; label: Date; items: PhotoItem[] }

/** Regroupe (déjà triées de la plus récente à la plus ancienne) par mois `AAAA-MM` ou par année `AAAA`. */
export function groupPhotos(items: PhotoItem[], by: 'month' | 'year'): Group[] {
  const out: Group[] = [];
  for (const p of items) {
    const d = new Date(p.taken * 1000);
    const key = by === 'year' ? String(d.getFullYear()) : `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    const last = out[out.length - 1];
    if (last && last.key === key) last.items.push(p);
    else out.push({ key, label: d, items: [p] });
  }
  return out;
}

export function monthLabel(d: Date, lang: string): string {
  try {
    return d.toLocaleDateString(lang, { month: 'long', year: 'numeric' });
  } catch {
    return `${d.getFullYear()}-${d.getMonth() + 1}`;
  }
}

export function dateLabel(seconds: number, lang: string): string {
  try {
    return new Date(seconds * 1000).toLocaleDateString(lang, { day: 'numeric', month: 'long', year: 'numeric' });
  } catch {
    return new Date(seconds * 1000).toISOString().slice(0, 10);
  }
}

/** Photo suivante ou précédente, en boucle. */
export function neighbour(ids: number[], current: number, step: 1 | -1): number | null {
  if (!ids.length) return null;
  const i = ids.indexOf(current);
  return ids[(i + step + ids.length) % ids.length] ?? null;
}

/** Réduit une image en vignette (canvas) ; null si le canvas n'est pas disponible. */
export async function makeThumb(src: string, max = 240): Promise<string | null> {
  try {
    const img = new Image();
    img.src = src;
    await img.decode();
    const k = Math.min(1, max / Math.max(img.width, img.height));
    const c = document.createElement('canvas');
    c.width = Math.max(1, Math.round(img.width * k));
    c.height = Math.max(1, Math.round(img.height * k));
    const ctx = c.getContext('2d');
    if (!ctx) return null;
    ctx.drawImage(img, 0, 0, c.width, c.height);
    const out = c.toDataURL('image/webp', 0.6);
    return out.startsWith('data:image/') && out.length <= 24000 ? out : null;
  } catch {
    return null;
  }
}
