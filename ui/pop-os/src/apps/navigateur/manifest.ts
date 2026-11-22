import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'navigateur',
  nameKey: 'app.navigateur',
  domain: 'tools',
  online: true,
  load: () => import('./index'),
};
