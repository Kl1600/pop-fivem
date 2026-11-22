import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'contacts',
  nameKey: 'app.contacts',
  domain: 'communication',
  load: () => import('./index'),
};
