import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'camera',
  nameKey: 'app.camera',
  domain: 'media',
  load: () => import('./index'),
};
