import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'meteo',
  nameKey: 'app.meteo',
  domain: 'tools',
  load: () => import('./index'),
};
