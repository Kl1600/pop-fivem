import { describe, expect, it } from 'vitest';
import { fitEncoding, MAX_DATA_CHARS } from './model';

/** Encodeur factice : le poids dépend de la largeur et de la qualité, sans canvas. */
const fake = (calls: Array<[number, number]>, weight: (w: number, q: number) => number) => (w: number, q: number): string => {
  calls.push([w, q]);
  return 'x'.repeat(weight(w, q));
};

describe('Appareil photo : boucle de réduction', () => {
  it('tient du premier coup : 960 px, qualité 0,85', () => {
    const calls: Array<[number, number]> = [];
    const out = fitEncoding(fake(calls, () => 1000), 1500);
    expect(out.length).toBe(1000);
    expect(calls).toEqual([[960, 0.85]]);
  });

  it('baisse la qualité avant la largeur', () => {
    const calls: Array<[number, number]> = [];
    const out = fitEncoding(fake(calls, (_, q) => (q > 0.6 ? 200_000 : 100_000)), 1500);
    expect(out.length).toBeLessThanOrEqual(MAX_DATA_CHARS);
    expect(calls.map((c) => c[0])).toEqual([960, 960, 960]);
  });

  it('réduit la largeur (960, 720, 540) quand la qualité ne suffit pas', () => {
    const calls: Array<[number, number]> = [];
    const out = fitEncoding(fake(calls, (w) => (w > 600 ? 300_000 : 90_000)), 1500);
    expect(out.length).toBe(90_000);
    expect(calls.map((c) => c[0])).toEqual([960, 960, 960, 720, 720, 720, 540]);
  });

  it('si rien ne passe : dernier essai (540 px, qualité la plus basse), le serveur refusera', () => {
    const calls: Array<[number, number]> = [];
    const out = fitEncoding(fake(calls, () => 500_000), 1500);
    expect(out.length).toBe(500_000);
    expect(calls[calls.length - 1]).toEqual([540, 0.55]);
    expect(calls.length).toBe(9);
  });

  it('source étroite : pas de palier en double ni d\'agrandissement', () => {
    const calls: Array<[number, number]> = [];
    fitEncoding(fake(calls, () => 500_000), 600);
    expect(calls.map((c) => c[0])).toEqual([600, 600, 600, 540, 540, 540]);
  });
});
