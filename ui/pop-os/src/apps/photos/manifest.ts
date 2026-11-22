import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'photos',
  nameKey: 'app.photos',
  domain: 'media',
  load: () => import('./index'),
};
