import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'horloge',
  nameKey: 'app.horloge',
  domain: 'tools',
  load: () => import('./index'),
};
