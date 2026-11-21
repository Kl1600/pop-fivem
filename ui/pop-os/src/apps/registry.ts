import type { AppManifest } from '../kit';
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

/** Applis ajoutées par d'autres ressources (catalogue envoyé par `tablet:apps`). */
export function registerApiApp(m: AppManifest): void {
  apiApps.set(m.id, m);
}

export function getApp(id: string): AppManifest | undefined {
  return NATIVE_APPS.find((a) => a.id === id) ?? apiApps.get(id);
}

export function allApps(): AppManifest[] {
  return [...NATIVE_APPS, ...apiApps.values()];
}
