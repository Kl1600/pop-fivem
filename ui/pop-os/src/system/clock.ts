import { useEffect, useState } from 'react';
import { os } from './store';
import type { ClockSnap } from '../nui/types';

// Horloge du jeu : l'interface part d'un instantané (`tablet:open` / `tablet:clock`) et avance seule.
// Un seul minuteur, armé uniquement tant qu'un composant lit l'heure (tablette ouverte), calé sur la minute de jeu suivante.

const DEFAULT_SNAP: ClockSnap = { h: 12, m: 0, d: 1, mo: 1, y: 2026, msPerMin: 2000 };

/** Minutes de jeu écoulées depuis l'instantané. */
export function elapsedGameMinutes(snap: ClockSnap, fromMs: number, nowMs: number): number {
  const per = snap.msPerMin > 0 ? snap.msPerMin : 2000;
  return Math.floor(Math.max(0, nowMs - fromMs) / per);
}

/** Date de jeu (UTC, sans fuseau) à l'instant `nowMs` (performance.now). */
export function gameDate(snap: ClockSnap | null, fromMs: number, nowMs: number): Date {
  const s = snap ?? DEFAULT_SNAP;
  const base = Date.UTC(s.y, s.mo - 1, s.d, s.h, s.m, 0);
  return new Date(base + elapsedGameMinutes(s, fromMs, nowMs) * 60_000);
}

/** Temps du jeu continu (ms, UTC sans fuseau) : avance de 60 000 ms par minute de jeu écoulée. */
export function gameMsNow(): number {
  const s = os.get();
  const snap = s.clock ?? DEFAULT_SNAP;
  const per = snap.msPerMin > 0 ? snap.msPerMin : 2000;
  return Date.UTC(snap.y, snap.mo - 1, snap.d, snap.h, snap.m, 0) + (Math.max(0, performance.now() - s.clockAt) / per) * 60_000;
}

/** Délai (ms réelles) jusqu'à la prochaine minute de jeu. */
export function msToNextMinute(snap: ClockSnap | null, fromMs: number, nowMs: number): number {
  const per = snap && snap.msPerMin > 0 ? snap.msPerMin : 2000;
  const into = Math.max(0, nowMs - fromMs) % per;
  return Math.max(16, per - into);
}

const subscribers = new Set<() => void>();
let timer: ReturnType<typeof setTimeout> | null = null;

function schedule(): void {
  if (timer !== null || subscribers.size === 0) return;
  const s = os.get();
  timer = setTimeout(() => {
    timer = null;
    subscribers.forEach((f) => f());
    schedule();
  }, msToNextMinute(s.clock, s.clockAt, performance.now()));
}

function subscribe(f: () => void): () => void {
  subscribers.add(f);
  schedule();
  return () => {
    subscribers.delete(f);
    if (subscribers.size === 0 && timer !== null) {
      clearTimeout(timer);
      timer = null;
    }
  };
}

/** Nombre de minuteurs d'horloge armés (0 tablette fermée : vérifié par les tests). */
export function clockTimerActive(): boolean {
  return timer !== null;
}

/** Date de jeu courante, rafraîchie à chaque minute de jeu. */
export function useGameDate(): Date {
  const [, tick] = useState(0);
  useEffect(() => subscribe(() => tick((n) => n + 1)), []);
  const s = os.get();
  return gameDate(s.clock, s.clockAt, performance.now());
}

export function formatTime(d: Date): string {
  return `${String(d.getUTCHours()).padStart(2, '0')}:${String(d.getUTCMinutes()).padStart(2, '0')}`;
}

export function formatDate(d: Date, lang: string, style: 'long' | 'short'): string {
  const opts: Intl.DateTimeFormatOptions = style === 'long' ? { weekday: 'long', day: 'numeric', month: 'long', timeZone: 'UTC' } : { weekday: 'short', day: 'numeric', month: 'short', timeZone: 'UTC' };
  try {
    return new Intl.DateTimeFormat(lang, opts).format(d);
  } catch {
    return new Intl.DateTimeFormat('en', opts).format(d);
  }
}

export function weekdayLong(d: Date, lang: string): string {
  try {
    return new Intl.DateTimeFormat(lang, { weekday: 'long', timeZone: 'UTC' }).format(d);
  } catch {
    return new Intl.DateTimeFormat('en', { weekday: 'long', timeZone: 'UTC' }).format(d);
  }
}
