import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'calculette',
  nameKey: 'app.calculette',
  domain: 'tools',
  load: () => import('./index'),
};
