import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'reglages',
  nameKey: 'app.reglages',
  domain: 'tools',
  system: true,
  load: () => import('./index'),
};
