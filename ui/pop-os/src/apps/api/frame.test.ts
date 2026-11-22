import { describe, expect, it } from 'vitest';
import { FRAME_TARGET, frameTrusted } from './index';

const frame = (src: string | null) => ({ getAttribute: () => src });

describe('cadre des applis API', () => {
  it('relaie seulement tant que le cadre est celui de la page de l\'appli (une charge, même URL)', () => {
    expect(frameTrusted(frame('nui://pop_demo/web/index.html'), 'nui://pop_demo/web/index.html', 1)).toBe(true);
  });
  it('refuse si le cadre a été rechargé ailleurs (2e charge)', () => {
    expect(frameTrusted(frame('nui://pop_demo/web/index.html'), 'nui://pop_demo/web/index.html', 2)).toBe(false);
  });
  it('refuse avant la première charge et si l\'URL du cadre a changé', () => {
    expect(frameTrusted(frame('nui://pop_demo/web/index.html'), 'nui://pop_demo/web/index.html', 0)).toBe(false);
    expect(frameTrusted(frame('https://pirate.example/'), 'nui://pop_demo/web/index.html', 1)).toBe(false);
    expect(frameTrusted(frame(null), 'nui://pop_demo/web/index.html', 1)).toBe(false);
  });
  it('la cible est « * » : le cadre sandbox a une origine opaque, aucune origine exacte n\'existe', () => {
    expect(FRAME_TARGET).toBe('*');
  });
});

describe('CSP de la page', () => {
  it('limite les scripts, les images et les cadres', async () => {
    const { readFileSync } = await import('node:fs');
    const { join } = await import('node:path');
    const html = readFileSync(join(__dirname, '../../../index.html'), 'utf8');
    const csp = html.match(/http-equiv="Content-Security-Policy" content="([^"]+)"/)?.[1] ?? '';
    expect(csp).toContain("default-src 'none'");
    expect(csp).toMatch(/img-src [^;]*'self'[^;]*data:[^;]*blob:/);
    expect(csp).toMatch(/frame-src nui: https:;/);
    expect(csp).toMatch(/script-src 'self' nui:;/);
    expect(csp).not.toContain('unsafe-eval');
    expect(csp.match(/script-src[^;]*/)?.[0]).not.toContain('unsafe-inline');
  });
});
