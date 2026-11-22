import { useSettingsApi, type AppProps, type SettingsApi } from '../../kit';

export type { SettingsApi };
/** Réglages de l'appareil fournis par le contexte du kit. */
export function useSettings(_p: AppProps): SettingsApi {
  return useSettingsApi();
}
