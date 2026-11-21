import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'musique',
  nameKey: 'app.musique',
  domain: 'media',
  load: () => import('./index'),
};
