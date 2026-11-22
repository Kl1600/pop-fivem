import type { NuiResult } from '../kit';
import { nuiApi } from '../nui/bridge';

// Échéances envoyées au client (alarmes, alertes du calendrier, rappels). Le client n'a qu'UNE minuterie et remplace
// toute la liste à chaque envoi : on garde donc les trois sources ici et on envoie leur réunion (<= 100 éléments).

export type SchedKind = 'alarm' | 'event' | 'reminder';
export interface SchedItem { id: number; kind: SchedKind; minute: number }

const MAX = 100;
const sources: Record<SchedKind, SchedItem[]> = { alarm: [], event: [], reminder: [] };

/** Dernier envoi (lu par les tests). */
export function currentSchedule(): SchedItem[] {
  return [...sources.alarm, ...sources.event, ...sources.reminder].slice(0, MAX);
}

function push(): void {
  void nuiApi.post('schedule', { items: currentSchedule() });
}

/** Remplace les échéances d'une source et renvoie la liste complète au client. */
export function setSchedule(kind: SchedKind, items: SchedItem[]): void {
  sources[kind] = items;
  push();
}

export function resetSchedule(): void {
  sources.alarm = [];
  sources.event = [];
  sources.reminder = [];
}

/** Minute de la journée (0..1439) d'un horodatage du jeu 'AAAA-MM-JJ HH:MM', ou null. */
export function minuteOf(stamp: string | null | undefined): number | null {
  const m = typeof stamp === 'string' ? /^\d{4}-\d{2}-\d{2} (\d{2}):(\d{2})$/.exec(stamp) : null;
  if (!m) return null;
  const v = Number(m[1]) * 60 + Number(m[2]);
  return v >= 0 && v < 1440 ? v : null;
}

export function alarmItems(alarms: Array<{ id: number; minute: number; enabled: boolean }>): SchedItem[] {
  return alarms.filter((a) => a.enabled).map((a) => ({ id: a.id, kind: 'alarm' as const, minute: a.minute }));
}

/** Alerte d'événement : minute de début (0 si toute la journée) moins l'avance, ramenée dans la journée. */
export function eventItems(alerts: Array<{ id: number; start: string; allDay: boolean; alert: number | null }>): SchedItem[] {
  const out: SchedItem[] = [];
  for (const a of alerts) {
    const start = a.allDay ? 0 : minuteOf(a.start);
    if (start === null || a.alert === null) continue;
    out.push({ id: a.id, kind: 'event', minute: (((start - a.alert) % 1440) + 1440) % 1440 });
  }
  return out;
}

export function reminderItems(items: Array<{ id: number; done: boolean; due: string | null }>): SchedItem[] {
  const out: SchedItem[] = [];
  for (const r of items) {
    const m = r.done ? null : minuteOf(r.due);
    if (m !== null) out.push({ id: r.id, kind: 'reminder', minute: m });
  }
  return out;
}

/** Relit les trois sources au déverrouillage (une seule fois par ouverture) et envoie les échéances au client. */
export async function syncSchedule(): Promise<void> {
  const [clock, cal, rem] = await Promise.all([
    nuiApi.call<NuiResult & { alarms?: Array<{ id: number; minute: number; enabled: boolean }> }>('clock:list'),
    nuiApi.call<NuiResult & { alerts?: Array<{ id: number; start: string; allDay: boolean; alert: number | null }> }>('calendar:list', { from: '2026-01-01', to: '2026-01-02' }),
    nuiApi.call<NuiResult & { items?: Array<{ id: number; done: boolean; due: string | null }> }>('reminders:list'),
  ]);
  if (clock.ok) sources.alarm = alarmItems(clock.alarms ?? []);
  if (cal.ok) sources.event = eventItems(cal.alerts ?? []);
  if (rem.ok) sources.reminder = reminderItems(rem.items ?? []);
  push();
}
