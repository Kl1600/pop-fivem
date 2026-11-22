// Modèle de l'Appareil photo : formats de prise de vue et minuteur. Fonctions pures, testées.

export type ShotKind = 'photo' | 'square' | 'portrait' | 'pano';

/** Formats proposés, dans l'ordre de la roue (les mêmes identifiants que le serveur accepte). */
export const MODES: Array<{ id: ShotKind }> = [{ id: 'photo' }, { id: 'square' }, { id: 'portrait' }, { id: 'pano' }];

/** Minuteur : aucun -> 3 s -> 10 s -> aucun. */
export function nextTimer(current: number): number {
  return current === 0 ? 3 : current === 3 ? 10 : 0;
}
