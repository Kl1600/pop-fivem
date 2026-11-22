// Modèle du Dictaphone : choix du mode (enregistrement ou mémo dicté), durées, découpage, forme d'onde. Fonctions pures (testées).

export type MicState = 'unknown' | 'granted' | 'denied';
export type Mode = 'testing' | 'record' | 'memo';

export const MAX_SECONDS = 120;
export const MAX_BYTES = 409600;
export const CHUNK = 32768;
export const MAX_RECS = 30;

export interface RecRow { id: number; title: string; seconds: number; created: number; memo: boolean }

/** Mode d'écran : test du micro en cours, enregistrement (micro accordé et MediaRecorder présent), sinon mémo dicté. */
export function chooseMode(mic: MicState, hasRecorder: boolean): Mode {
  if (mic === 'unknown') return 'testing';
  return mic === 'granted' && hasRecorder ? 'record' : 'memo';
}

export function mmss(sec: number): string {
  const t = Math.max(0, Math.floor(sec));
  return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, '0')}`;
}

/** Chrono d'enregistrement 00:00,0 */
export function recClock(ms: number): string {
  const t = Math.max(0, Math.floor(ms / 1000));
  return `${String(Math.floor(t / 60)).padStart(2, '0')}:${String(t % 60).padStart(2, '0')},${Math.floor(Math.max(0, ms) / 100) % 10}`;
}

/** Découpe un texte en morceaux d'au plus `size` caractères. */
export function chunks(text: string, size = CHUNK): string[] {
  const out: string[] = [];
  for (let i = 0; i < text.length; i += size) out.push(text.slice(i, i + size));
  return out;
}

/** Forme d'onde stable d'un enregistrement (n barres entre 0,08 et 1), même tirage qu'à la maquette. */
export function wave(id: number, n: number, amps?: number[]): number[] {
  if (amps && amps.length > 0) return Array.from({ length: n }, (_, i) => amps[Math.min(amps.length - 1, Math.floor((i * amps.length) / n))] as number);
  const out: number[] = [];
  let x = id * 7919 + 13;
  for (let i = 0; i < n; i++) {
    x = (x * 9301 + 49297) % 233280;
    const env = 0.3 + 0.7 * Math.abs(Math.sin(i / 8 + id));
    out.push(Math.max(0.08, (x / 233280) * env + 0.05));
  }
  return out;
}

/** Une durée enregistrable : 1 à 120 s. */
export const clampSeconds = (ms: number): number => Math.max(1, Math.min(MAX_SECONDS, Math.round(ms / 1000)));

/** Le contenu audio (data URI) tient dans la limite du serveur. */
export const audioFits = (dataUri: string): boolean => dataUri.length <= MAX_BYTES;

export const SPEEDS = [0.5, 1, 1.5, 2] as const;
export const nextSpeed = (r: number): number => SPEEDS[(SPEEDS.indexOf(r as (typeof SPEEDS)[number]) + 1) % SPEEDS.length] as number;

export const speechAvailable = (): boolean => typeof window !== 'undefined' && 'speechSynthesis' in window && typeof SpeechSynthesisUtterance !== 'undefined';
