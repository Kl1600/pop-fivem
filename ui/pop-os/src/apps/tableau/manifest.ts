import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'tableau',
  nameKey: 'app.tableau',
  domain: 'personal',
  load: () => import('./index'),
};
