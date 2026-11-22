import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'traduire',
  nameKey: 'app.traduire',
  domain: 'tools',
  load: () => import('./index'),
};
