import type { AppManifest } from '../../kit';

export const manifest: AppManifest = {
  id: 'messages',
  nameKey: 'app.messages',
  domain: 'communication',
  online: true,
  load: () => import('./index'),
};
