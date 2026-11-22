import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'notes',
  nameKey: 'app.notes',
  domain: 'personal',
  load: () => import('./index'),
};
