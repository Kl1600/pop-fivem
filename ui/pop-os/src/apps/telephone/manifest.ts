import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'telephone',
  nameKey: 'app.telephone',
  domain: 'communication',
  online: true,
  load: () => import('./index'),
};
