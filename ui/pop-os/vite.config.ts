import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import { fileURLToPath } from 'node:url';

// Sortie versionnée de la ressource FiveM : jamais de build sur le VPS.
const outDir = fileURLToPath(new URL('../../resources/[pop]/pop_tablet/web/dist', import.meta.url));

export default defineConfig({
  base: './',
  plugins: [
    react(),
    // Le serveur de développement injecte des scripts en ligne et un WebSocket : la CSP n'est gardée que dans le build.
    { name: 'dev-sans-csp', apply: 'serve', transformIndexHtml: (html: string) => html.replace(/<meta http-equiv="Content-Security-Policy"[^>]*>\s*/, '') },
  ],
  build: {
    outDir,
    emptyOutDir: true,
    target: 'chrome103',
    modulePreload: { polyfill: false },
    assetsInlineLimit: 0,
    sourcemap: false,
  },
  test: {
    environment: 'jsdom',
    include: ['src/**/*.test.{ts,tsx}'],
    setupFiles: ['src/test/setup.ts'],
    globals: false,
  },
});
