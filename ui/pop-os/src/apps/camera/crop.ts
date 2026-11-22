import { MAX_DATA_CHARS, MAX_WIDTH, outputSize, sourceRect, type Crop } from './model';

/** Recadre une capture (data URI) sur `crop`, la ramène à 960 px de large au plus et la ré-encode en webp (~0,85).
 *  Si le texte dépasse la limite du serveur, baisse la qualité puis la taille. Rejette si l'image ne se décode pas. */
export async function cropImage(src: string, crop: Crop): Promise<string> {
  const img = new Image();
  img.src = src;
  await img.decode();
  const { sx, sy, sw, sh } = sourceRect(crop, img.naturalWidth, img.naturalHeight);
  let width = outputSize(sw, sh, MAX_WIDTH).w;
  let out = '';
  for (let pass = 0; pass < 4; pass++) {
    const { w, h } = outputSize(sw, sh, width);
    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('canvas');
    ctx.drawImage(img, sx, sy, sw, sh, 0, 0, w, h);
    for (const q of [0.85, 0.7, 0.55]) {
      out = canvas.toDataURL('image/webp', q);
      if (out.length <= MAX_DATA_CHARS) return out;
    }
    width = Math.round(width * 0.75);
  }
  return out;
}
