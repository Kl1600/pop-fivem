import type { AppManifest } from '../kit';
import { setApiPage } from './api/pages';
import { manifest as m_bourse } from './bourse/manifest';
import { manifest as m_boutique } from './boutique/manifest';
import { manifest as m_calculette } from './calculette/manifest';
import { manifest as m_calendrier } from './calendrier/manifest';
import { manifest as m_camera } from './camera/manifest';
import { manifest as m_contacts } from './contacts/manifest';
import { manifest as m_dictaphone } from './dictaphone/manifest';
import { manifest as m_fichiers } from './fichiers/manifest';
import { manifest as m_horloge } from './horloge/manifest';
import { manifest as m_mail } from './mail/manifest';
import { manifest as m_messages } from './messages/manifest';
import { manifest as m_meteo } from './meteo/manifest';
import { manifest as m_musique } from './musique/manifest';
import { manifest as m_navigateur } from './navigateur/manifest';
import { manifest as m_notes } from './notes/manifest';
import { manifest as m_photos } from './photos/manifest';
import { manifest as m_plans } from './plans/manifest';
import { manifest as m_rappels } from './rappels/manifest';
import { manifest as m_reglages } from './reglages/manifest';
import { manifest as m_tableau } from './tableau/manifest';
import { manifest as m_telephone } from './telephone/manifest';
import { manifest as m_traduire } from './traduire/manifest';

/** Registre unique des applis natives (une par dossier). Les applis de l'API (RegisterApp) s'ajoutent à l'exécution. */
export const NATIVE_APPS: AppManifest[] = [m_bourse, m_boutique, m_calculette, m_calendrier, m_camera, m_contacts, m_dictaphone, m_fichiers, m_horloge, m_mail, m_messages, m_meteo, m_musique, m_navigateur, m_notes, m_photos, m_plans, m_rappels, m_reglages, m_tableau, m_telephone, m_traduire];

const apiApps = new Map<string, AppManifest>();
/** Ids posés par `setApiApps` (le serveur) : seuls ceux-là sont remplacés à chaque mise à jour. */
const fromServer = new Set<string>();
export { setApiPage, apiPage } from './api/pages';

/** Applis ajoutées par d'autres ressources (catalogue envoyé par `tablet:apps`). */
export function registerApiApp(m: AppManifest): void {
  apiApps.set(m.id, m);
}

/** Remplace l'ensemble des applis API par les fiches reçues du serveur (démarrage, `tablet:apps`). */
export function setApiApps(items: ReadonlyArray<{ id: string; name: string; page: string; color?: string; icon?: string }>): void {
  for (const id of fromServer) apiApps.delete(id);
  fromServer.clear();
  for (const it of items) {
    setApiPage(it.id, { page: it.page, name: it.name, color: it.color, icon: it.icon });
    fromServer.add(it.id);
    apiApps.set(it.id, { id: it.id, nameKey: `api.${it.id}`, domain: 'api', online: false, load: () => import('./api/index') });
  }
}

export function getApp(id: string): AppManifest | undefined {
  return NATIVE_APPS.find((a) => a.id === id) ?? apiApps.get(id);
}

export function allApps(): AppManifest[] {
  return [...NATIVE_APPS, ...apiApps.values()];
}
