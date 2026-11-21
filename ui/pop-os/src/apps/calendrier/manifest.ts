import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'calendrier',
  nameKey: 'app.calendrier',
  domain: 'personal',
  load: () => import('./index'),
};
