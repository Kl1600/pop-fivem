// Modèle de l'Appareil photo : formats de prise de vue et minuteur. Fonctions pures, testées.

export type ShotKind = 'photo' | 'square' | 'portrait' | 'pano';

/** Formats proposés, dans l'ordre de la roue (les mêmes identifiants que le serveur accepte). */
export const MODES: Array<{ id: ShotKind }> = [{ id: 'photo' }, { id: 'square' }, { id: 'portrait' }, { id: 'pano' }];

/** Minuteur : aucun -> 3 s -> 10 s -> aucun. */
export function nextTimer(current: number): number {
  return current === 0 ? 3 : current === 3 ? 10 : 0;
}

/** Bandeaux noirs du viseur (px de mise en page) : de chaque côté en carré, en haut et en bas en panorama. */
export const SQUARE_BAR = 116;
export const PANO_BAR = 280;
/** Largeur maximale de la photo enregistrée (px) et poids maximal du texte base64 accepté par le serveur. */
export const MAX_WIDTH = 960;
export const MAX_DATA_CHARS = 140_000;

export interface Box { left: number; top: number; width: number; height: number }
/** Zone de la fenêtre en fractions 0..1 (le contrat de `photos:capture`). */
export interface Crop { x: number; y: number; w: number; h: number }

/** Partie du viseur réellement visible selon le format (hors bandeaux noirs). `k` = échelle d'affichage (px écran / px de mise en page). */
export function visibleBox(vf: Box, mode: ShotKind, k = 1): Box {
  const dx = mode === 'square' ? SQUARE_BAR * k : 0;
  const dy = mode === 'pano' ? PANO_BAR * k : 0;
  return { left: vf.left + dx, top: vf.top + dy, width: vf.width - 2 * dx, height: vf.height - 2 * dy };
}

const down = (v: number): number => Math.floor(v * 10000) / 10000;

/** Zone `box` (px fenêtre) en fractions de la fenêtre, bornée à 0..1 ; null si elle est trop petite ou non finie (le serveur exige w, h > 0,05). */
export function cropOf(box: Box, win: { w: number; h: number }): Crop | null {
  if (![box.left, box.top, box.width, box.height, win.w, win.h].every(Number.isFinite) || win.w <= 0 || win.h <= 0) return null;
  const clamp = (v: number): number => Math.min(1, Math.max(0, v));
  const x0 = clamp(box.left / win.w);
  const y0 = clamp(box.top / win.h);
  const x1 = clamp((box.left + box.width) / win.w);
  const y1 = clamp((box.top + box.height) / win.h);
  const c = { x: down(x0), y: down(y0), w: down(x1 - x0), h: down(y1 - y0) };
  return c.w > 0.05 && c.h > 0.05 ? c : null;
}

/** Zone source en pixels de l'image capturée pour un recadrage en fractions. */
export function sourceRect(c: Crop, imgW: number, imgH: number): { sx: number; sy: number; sw: number; sh: number } {
  return { sx: Math.round(c.x * imgW), sy: Math.round(c.y * imgH), sw: Math.max(1, Math.round(c.w * imgW)), sh: Math.max(1, Math.round(c.h * imgH)) };
}

/** Taille de sortie : même proportion que la zone source, largeur au plus `maxW`. */
export function outputSize(sw: number, sh: number, maxW = MAX_WIDTH): { w: number; h: number } {
  const w = Math.max(1, Math.min(sw, maxW));
  return { w, h: Math.max(1, Math.round((sh * w) / sw)) };
}
