import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'mail',
  nameKey: 'app.mail',
  domain: 'communication',
  load: () => import('./index'),
};
