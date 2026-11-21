import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'plans',
  nameKey: 'app.plans',
  domain: 'tools',
  load: () => import('./index'),
};
