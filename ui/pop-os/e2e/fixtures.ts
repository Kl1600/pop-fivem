import { expect, test as base, type Locator, type Page } from '@playwright/test';

export interface NuiCall { name: string; data: unknown }

/** Outils d'un scénario : appels NUI enregistrés et ouverture de la tablette simulée. */
export interface Tablet {
  page: Page;
  /** Ouvre la tablette (déverrouillée par défaut, via le vrai code 1234). */
  open(opts?: { setup?: boolean; dark?: boolean; lang?: string; unlock?: boolean }): Promise<void>;
  /** Appels NUI enregistrés depuis le début (ou ceux dont le nom correspond). */
  calls(name?: string): Promise<NuiCall[]>;
  /** Attend qu'un appel NUI de ce nom soit parti ; renvoie le dernier. */
  waitCall(name: string, match?: (d: unknown) => boolean): Promise<NuiCall>;
  /** Ouvre une appli depuis l'accueil (clic sur son icône). */
  openApp(label: string): Promise<Locator>;
  /** Couche de l'appli ouverte. */
  app: Locator;
  home(): Promise<void>;
  /** Erreurs console attendues (artefact du navigateur de dev, pas de la tablette) : ignorées pour ce scénario. */
  ignoreErrors(re: RegExp): void;
  /** Écran de la tablette (coque exclue). */
  screen: Locator;
  /** Simule un message du jeu (`SendNUIMessage`) : `tablet:<action>`. */
  send(action: string, data?: unknown): Promise<void>;
}

export const test = base.extend<{ tab: Tablet }>({
  tab: async ({ page }, use) => {
    const errors: string[] = [];
    const ignored: RegExp[] = [];
    page.on('response', (r) => { if (r.status() >= 400) errors.push(`http ${r.status()}: ${r.url()}`); });
    page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
    page.on('console', (m) => { if (m.type() === 'error') errors.push(`console.error: ${m.text()}`); });
    await page.route('**/favicon.ico', (r) => r.fulfill({ status: 204 })); // le navigateur de dev le réclame ; absent en jeu
    const app = page.locator('[data-layer="app"]');
    const calls = async (name?: string): Promise<NuiCall[]> => {
      const all = await page.evaluate(() => (window as unknown as { __popCalls?: NuiCall[] }).__popCalls ?? []);
      return name ? all.filter((c) => c.name === name) : all;
    };
    const tab: Tablet = {
      page,
      app,
      calls,
      ignoreErrors: (re) => { ignored.push(re); },
      screen: page.locator('[data-screen="1"]'),
      async send(action, data) { await page.evaluate(([a, d]) => window.postMessage({ action: `tablet:${a}`, data: d }, '*'), [action, data] as const); },
      async open(opts = {}) {
        const q = new URLSearchParams();
        if (opts.setup) q.set('setup', '1');
        if (opts.dark) q.set('dark', '1');
        if (opts.lang) q.set('lang', opts.lang);
        await page.goto(`/?${q.toString()}`);
        await expect(page.locator('[data-screen="1"]')).toBeVisible();
        if (opts.setup || opts.unlock === false) return;
        await page.getByRole('button', { name: /barre d.accueil/i }).click();
        for (const d of '1234') await page.getByRole('button', { name: d, exact: true }).click();
        await expect(page.locator('[data-screen="1"]').getByRole('button', { name: 'Réglages' })).toBeVisible();
      },
      async waitCall(name, match) {
        let found: NuiCall | undefined;
        await expect.poll(async () => { found = (await calls(name)).filter((c) => !match || match(c.data)).at(-1); return !!found; }, { message: `appel NUI « ${name} » attendu` }).toBe(true);
        return found!;
      },
      async openApp(label) {
        await page.locator('[data-screen="1"]').getByRole('button', { name: label, exact: true }).first().click();
        await expect(app).toBeVisible();
        return app;
      },
      async home() {
        await page.getByRole('button', { name: /barre d.accueil/i }).click();
        await expect(app).toHaveCount(0);
      },
    };
    await use(tab);
    expect(errors.filter((e) => !ignored.some((re) => re.test(e))), 'erreurs console / pageerror pendant le scénario').toEqual([]);
  },
});

export { expect };
