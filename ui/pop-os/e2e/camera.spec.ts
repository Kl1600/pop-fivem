import { expect, test } from './fixtures';

test.describe('Appareil photo : coque opaque et recadrage', () => {
  test('en mode caméra, la coque est 100 % opaque (même fond qu’en mode normal) et seul le viseur est transparent', async ({ tab }) => {
    const { page } = tab;
    await tab.open();
    const normal = await page.evaluate(() => {
      const el = document.querySelector('[data-shell="1"] > div[style*="border-radius: 56px"]') as HTMLElement;
      const cs = getComputedStyle(el);
      return { image: cs.backgroundImage, opacity: cs.opacity };
    });
    expect(normal.opacity).toBe('1');
    await tab.openApp('Appareil photo');
    await expect(page.locator('html')).toHaveAttribute('data-cam', 'live');
    const cam = await page.evaluate(() => {
      const el = document.querySelector('[data-shell-frame="1"]') as HTMLElement;
      const cs = getComputedStyle(el);
      const chain: string[] = [];
      for (let n: HTMLElement | null = el; n; n = n.parentElement) {
        const c = getComputedStyle(n);
        if (c.opacity !== '1' || c.mixBlendMode !== 'normal' || c.backdropFilter !== 'none' || (c.maskImage && c.maskImage !== 'none')) chain.push(n.tagName);
      }
      return { image: cs.backgroundImage, opacity: cs.opacity, clip: cs.clipPath, chain };
    });
    expect(cam.opacity).toBe('1');
    expect(cam.image).toBe(normal.image);
    expect(cam.image).not.toContain('rgba(');
    expect(cam.clip).toContain('path');
    expect(cam.chain).toEqual([]);
    // Un point de la coque (bord gauche du cadre) est peint par le cadre ; un point du viseur ne l'est pas.
    const hit = await page.evaluate(() => {
      const f = document.querySelector('[data-shell-frame="1"]')!.getBoundingClientRect();
      const v = document.querySelector('[data-viewfinder="1"]')!.getBoundingClientRect();
      return { frameW: f.width, viewfinderW: v.width };
    });
    expect(hit.viewfinderW).toBeLessThan(hit.frameW);
  });

  test('la photo est recadrée sur le viseur : capture avec zone, puis enregistrement avec jeton et image de la bonne proportion', async ({ tab }) => {
    const { page } = tab;
    await tab.open();
    const app = await tab.openApp('Appareil photo');
    await tab.waitCall('tablet:camera');
    await app.getByRole('option', { name: 'Carré' }).click();
    await app.getByRole('button', { name: 'Prendre une photo' }).click();
    await expect(app.getByRole('status')).toHaveText('Photo enregistrée', { timeout: 15_000 });

    const cap = (await tab.waitCall('photos:capture')).data as { kind: string; crop: { x: number; y: number; w: number; h: number } };
    expect(cap.kind).toBe('square');
    const { x, y, w, h } = cap.crop;
    for (const v of [x, y, w, h]) expect(Number.isFinite(v)).toBe(true);
    expect(x).toBeGreaterThanOrEqual(0);
    expect(y).toBeGreaterThanOrEqual(0);
    expect(w).toBeGreaterThan(0.05);
    expect(h).toBeGreaterThan(0.05);
    expect(x + w).toBeLessThanOrEqual(1);
    expect(y + h).toBeLessThanOrEqual(1);
    // Le viseur carré est carré à l'écran : w * largeur fenêtre ≈ h * hauteur fenêtre.
    const win = await page.evaluate(() => ({ w: innerWidth, h: innerHeight }));
    expect(Math.abs(w * win.w - h * win.h)).toBeLessThan(12);

    // photos:capture puis photos:save, dans cet ordre.
    const names = (await tab.calls()).map((c) => c.name).filter((n) => n === 'photos:capture' || n === 'photos:save');
    expect(names).toEqual(['photos:capture', 'photos:save']);
    const save = (await tab.waitCall('photos:save')).data as { token: string; img: string };
    expect(save.token).toMatch(/^t\d+$/);
    expect(save.img).toMatch(/^data:image\/(webp|png);base64,/);
    // L'image enregistrée a la proportion de la zone recadrée (la capture simulée est un PNG 16 x 9).
    const dims = await page.evaluate(async (src) => {
      const im = new Image();
      im.src = src;
      await im.decode();
      return { w: im.naturalWidth, h: im.naturalHeight };
    }, save.img);
    const expected = (w * 16) / (h * 9);
    expect(Math.abs(dims.w / dims.h - expected) / expected).toBeLessThan(0.2); // 16 x 9 px : l'arrondi à l'entier pèse beaucoup
    await app.getByRole('button', { name: 'Dernière photo' }).click();
    await expect(app.getByRole('img', { name: 'Dernière photo' })).toBeVisible();
  });
});
