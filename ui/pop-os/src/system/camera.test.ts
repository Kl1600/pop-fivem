import { describe, expect, it } from 'vitest';
import { cropOf, outputSize, sourceRect, visibleBox } from '../apps/camera/model';

const WIN = { w: 1920, h: 1080 };
// Viseur de la tablette plein écran : 1348 x 1019 mis à l'échelle de 1080/1019 puis centré (valeurs de la maquette).
const VF = { left: 24, top: 88, width: 1134, height: 897 };

describe('Appareil photo : rectangle de recadrage', () => {
  it('format photo : tout le viseur, en fractions de la fenêtre, dans les bornes du serveur', () => {
    const c = cropOf(visibleBox(VF, 'photo'), WIN)!;
    expect(c.x).toBeCloseTo(24 / 1920, 3);
    expect(c.y).toBeCloseTo(88 / 1080, 3);
    expect(c.w).toBeCloseTo(1134 / 1920, 3);
    expect(c.h).toBeCloseTo(897 / 1080, 3);
    expect(c.x).toBeGreaterThanOrEqual(0);
    expect(c.x + c.w).toBeLessThanOrEqual(1);
    expect(c.y + c.h).toBeLessThanOrEqual(1);
  });

  it('carré : les bandeaux de 116 px sont exclus, la zone est carrée en pixels', () => {
    const b = visibleBox(VF, 'square');
    expect(b.left).toBe(VF.left + 116);
    expect(b.width).toBe(VF.width - 232);
    const c = cropOf(b, WIN)!;
    expect(Math.abs(c.w * WIN.w - c.h * WIN.h)).toBeLessThan(8); // 902 x 897 : carré à 5 px près, comme le viseur affiché
  });

  it('panorama : les bandeaux du haut et du bas sont exclus, la zone est plus large que haute', () => {
    const b = visibleBox(VF, 'pano');
    expect(b.top).toBe(VF.top + 280);
    expect(b.height).toBe(VF.height - 560);
    const c = cropOf(b, WIN)!;
    expect(c.w * WIN.w / (c.h * WIN.h)).toBeGreaterThan(3);
  });

  it('l’échelle d’affichage (coque réduite) est appliquée aux bandeaux', () => {
    const b = visibleBox({ left: 0, top: 0, width: 567, height: 448 }, 'square', 0.5);
    expect(b.left).toBe(58);
    expect(b.width).toBe(567 - 116);
  });

  it('borne à la fenêtre, refuse les zones trop petites ou non finies', () => {
    const c = cropOf({ left: -50, top: -10, width: 5000, height: 5000 }, WIN)!;
    expect(c).toEqual({ x: 0, y: 0, w: 1, h: 1 });
    expect(cropOf({ left: 0, top: 0, width: 50, height: 600 }, WIN)).toBeNull();
    expect(cropOf({ left: NaN, top: 0, width: 500, height: 500 }, WIN)).toBeNull();
    expect(cropOf({ left: 0, top: 0, width: 500, height: 500 }, { w: 0, h: 0 })).toBeNull();
  });

  it('x + w et y + h ne dépassent jamais 1 (arrondi vers le bas)', () => {
    for (const left of [0.3, 100.7, 333.333, 1000.1]) {
      const c = cropOf({ left, top: left / 2, width: WIN.w - left, height: WIN.h - left / 2 }, WIN)!;
      expect(c.x + c.w).toBeLessThanOrEqual(1);
      expect(c.y + c.h).toBeLessThanOrEqual(1);
    }
  });
});

describe('Appareil photo : taille de la photo', () => {
  it('zone source en pixels et sortie à 960 px de large au plus, même proportion', () => {
    const c = cropOf(visibleBox(VF, 'square'), WIN)!;
    const { sw, sh } = sourceRect(c, 1920, 1080);
    expect(Math.abs(sw - sh)).toBeLessThan(8);
    const o = outputSize(sw, sh);
    expect(o.w).toBeLessThanOrEqual(960);
    expect(Math.abs(o.w / o.h - sw / sh)).toBeLessThan(0.01);
    const pano = sourceRect(cropOf(visibleBox(VF, 'pano'), WIN)!, 1920, 1080);
    const po = outputSize(pano.sw, pano.sh);
    expect(po.w).toBeLessThanOrEqual(960);
    expect(Math.abs(po.w / po.h - pano.sw / pano.sh)).toBeLessThan(0.05);
    expect(outputSize(3840, 1080, 960)).toEqual({ w: 960, h: 270 });
    expect(outputSize(400, 300)).toEqual({ w: 400, h: 300 }); // jamais agrandie
  });
});
