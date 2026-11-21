import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'boutique',
  nameKey: 'app.boutique',
  domain: 'tools',
  system: true,
  online: true,
  load: () => import('./index'),
};
