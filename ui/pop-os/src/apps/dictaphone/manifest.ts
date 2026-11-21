import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'dictaphone',
  nameKey: 'app.dictaphone',
  domain: 'media',
  load: () => import('./index'),
};
