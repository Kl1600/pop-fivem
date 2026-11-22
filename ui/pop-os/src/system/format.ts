import type { TFn } from '../kit';

/** Âge d'une notification : « maintenant », « 12 min », « 2 h », « 3 j ». */
export function relTime(at: number, now: number, t: TFn): string {
  const min = Math.floor(Math.max(0, now - at) / 60_000);
  if (min < 1) return t('time.now');
  if (min < 60) return t('time.min', min);
  const h = Math.floor(min / 60);
  if (h < 24) return t('time.hour', h);
  return t('time.day', Math.floor(h / 24));
}
