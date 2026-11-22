import { existsSync } from 'node:fs';
import { defineConfig } from '@playwright/test';

// Robot de bout en bout : aucun navigateur n'est téléchargé, on utilise le Edge (ou le Chrome) déjà installé.
const EDGE = ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Microsoft/Edge/Application/msedge.exe'];
const channel = process.env.POP_BROWSER ?? (EDGE.some(existsSync) ? 'msedge' : 'chrome');
const PORT = 5199;

export default defineConfig({
  testDir: './e2e',
  timeout: 60_000,
  expect: { timeout: 8_000 },
  fullyParallel: true,
  workers: process.env.CI ? 2 : 4,
  retries: 0,
  reporter: [['list']],
  outputDir: './e2e/.sortie',
  use: {
    baseURL: `http://127.0.0.1:${PORT}`,
    channel,
    headless: true,
    viewport: { width: 1500, height: 1100 },
    trace: 'off',
    screenshot: 'only-on-failure',
  },
  webServer: {
    command: `pnpm exec vite --host 127.0.0.1 --port ${PORT} --strictPort`,
    url: `http://127.0.0.1:${PORT}`,
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
});
