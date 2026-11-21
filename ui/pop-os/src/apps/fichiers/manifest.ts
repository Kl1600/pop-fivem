import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'fichiers',
  nameKey: 'app.fichiers',
  domain: 'personal',
  load: () => import('./index'),
};
