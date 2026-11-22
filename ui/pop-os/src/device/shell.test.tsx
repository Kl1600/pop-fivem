import { cleanup, render } from '@testing-library/react';
import { afterEach, describe, expect, it } from 'vitest';
import { FINISHES } from '../kit';
import { Shell } from './Shell';

afterEach(cleanup);

function draw(clear: boolean) {
  const { container } = render(<Shell powerLabel="p" volUpLabel="u" volDownLabel="d" onPower={() => undefined} onVolUp={() => undefined} onVolDown={() => undefined} clear={clear}><i data-screen-slot="1" /></Shell>);
  return container;
}

/** Fond opaque de la coque : le calque `data-shell-frame` en mode caméra, le cadre extérieur sinon. */
function bodyLayer(root: HTMLElement, clear: boolean): HTMLElement {
  const el = clear ? root.querySelector<HTMLElement>('[data-shell-frame]') : root.querySelector<HTMLElement>('[data-shell] > div[style*="border-radius: 56px"]');
  if (!el) throw new Error('cadre introuvable');
  return el;
}

describe('coque en mode caméra : 100 % opaque, comme hors mode caméra', () => {
  it('le cadre garde le fond opaque de la finition, sans opacité, flou, mélange ni masque', () => {
    for (const finish of Object.keys(FINISHES) as Array<keyof typeof FINISHES>) {
      cleanup();
      const normal = draw(false);
      const normalStyle = bodyLayer(normal, false).getAttribute('style') ?? '';
      cleanup();
      const cam = render(<Shell finish={finish} powerLabel="p" volUpLabel="u" volDownLabel="d" onPower={() => undefined} onVolUp={() => undefined} onVolDown={() => undefined} clear><i /></Shell>).container;
      const frame = bodyLayer(cam, true);
      const css = getComputedStyle(frame);
      expect(css.opacity === '' ? '1' : css.opacity).toBe('1');
      const style = frame.getAttribute('style') ?? '';
      // Même fond que le mode normal (même gradient de la finition), jamais transparent.
      expect(style).toContain(FINISHES[finish].body.slice(0, 20));
      expect(style).not.toMatch(/transparent|opacity|backdrop|mix-blend|mask/);
      if (finish === 'Noir sidéral') expect(normalStyle).toContain(FINISHES[finish].body.slice(0, 20));
    }
  });

  it("aucun élément de la coque n'est translucide : ni opacité < 1, ni filtre, ni fusion", () => {
    const cam = draw(true);
    for (const el of Array.from(cam.querySelectorAll<HTMLElement>('*'))) {
      const s = el.style;
      expect(s.opacity === '' || s.opacity === '1').toBe(true);
      expect(`${s.getPropertyValue('backdrop-filter')}${s.getPropertyValue('mix-blend-mode')}${s.getPropertyValue('filter')}${s.getPropertyValue('mask')}`).toBe('');
    }
  });

  it("le cadre est un calque percé (evenodd) à la forme de l'écran et ne capte pas la souris ; le liseré noir de l'écran reste peint", () => {
    const cam = draw(true);
    const frame = cam.querySelector<HTMLElement>('[data-shell-frame]')!;
    expect(frame.style.pointerEvents).toBe('none');
    expect(frame.style.clipPath).toContain('evenodd');
    const ring = Array.from(cam.querySelectorAll<HTMLElement>('div')).find((d) => d.style.boxShadow.includes('20px'));
    expect(ring?.style.boxShadow).toContain('rgb(5, 5, 6)');
  });

  it("hors mode caméra, aucun calque supplémentaire", () => {
    expect(draw(false).querySelector('[data-shell-frame]')).toBeNull();
  });
});
