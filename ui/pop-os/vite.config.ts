import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { fileURLToPath } from 'node:url';

// Sortie versionnée de la ressource FiveM : jamais de build sur le VPS.
const outDir = fileURLToPath(new URL('../../resources/[pop]/pop_tablet/web/dist', import.meta.url));

export default defineConfig({
  base: './',
  plugins: [react()],
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
