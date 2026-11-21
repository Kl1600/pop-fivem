import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'bourse',
  nameKey: 'app.bourse',
  domain: 'tools',
  load: () => import('./index'),
};
