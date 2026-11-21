import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'rappels',
  nameKey: 'app.rappels',
  domain: 'personal',
  load: () => import('./index'),
};
