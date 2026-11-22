import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { clearHist, fmt, initial, press, pickHist, type Calc } from '../apps/calculette/model';
import { ALERTS, alertMinute, blockOf, eventsOn, mondayOf, monthGrid, rangeFor, step, todayKey, weekDays, type CalEvent } from '../apps/calendrier/model';
import { clampTotal, fmtSw, faceOf, lapRows, repKind, timerText, toggleDay, WEEKDAYS } from '../apps/horloge/model';
import { countOf, dayDiff, defaultDue, inSel, visible, type Reminder } from '../apps/rappels/model';
import { mockOpen, resetMock } from '../nui/mock';
import { closeTablet, handleMessage, openApp, submitCode } from './actions';
import { alarmItems, currentSchedule, eventItems, minuteOf, reminderItems, resetSchedule } from './schedule';
import { Host } from './Tablet';

async function unlock() {
  act(() => handleMessage('open', mockOpen()));
  await act(async () => { await submitCode('1234'); });
}

beforeEach(() => { resetMock(); resetSchedule(); closeTablet(); });
afterEach(() => { cleanup(); closeTablet(); vi.restoreAllMocks(); });

const keys = (s: Calc, ...k: string[]) => k.reduce((acc, x) => press(acc, x), s);
const ev = (o: Partial<CalEvent>): CalEvent => ({ id: 1, title: 't', place: '', notes: '', start: '2026-11-22 08:00', stop: '2026-11-22 10:00', allDay: false, alert: null, color: '#ff383c', ...o });
const rem = (o: Partial<Reminder>): Reminder => ({ id: 1, list: 1, title: 'r', done: false, due: null, flag: false, ...o });

describe('modèles purs', () => {
  it('calculette : opérations, priorité par pile, erreur, historique', () => {
    expect(keys(initial(), '7', '×', '6', '=').cur).toBe('42');
    expect(keys(initial(), '1', '2', '÷', '0', '=').cur).toBe('Erreur');
    expect(keys(initial(), '2', '+', '(', '3', '×', '4', ')', '=').cur).toBe('14');
    expect(keys(initial(), '5', '%').cur).toBe('0.05');
    expect(keys(initial(), '9', 'sqrt').cur).toBe('3');
    expect(keys(initial(), '5', 'fact').cur).toBe('120');
    expect(keys(initial(), '9', '0', 'sin').cur).toBe('1');
    expect(keys(initial(), '4', 'inv').cur).toBe('0.25');
    expect(fmt('1250000.5')).toBe('1 250 000,5');
    const s = keys(initial(), '1', '+', '2', '=');
    expect(s.hist).toEqual([{ e: '1 + 2', r: '3' }]);
    expect(pickHist(clearHist(s), s.hist[0]).cur).toBe('3');
    expect(clearHist(s).hist).toEqual([]);
    const big = keys(initial(), ...'1234567890123'.split(''));
    expect(big.cur.length).toBe(12);
  });
  it('horloge : cadran, chronomètre, tours, minuteur, répétition', () => {
    const noon = Date.UTC(2026, 10, 22, 12, 0, 0);
    const f = faceOf(noon, 0);
    expect(f.digital).toBe('12:00');
    expect(f.hx).toBeCloseTo(100, 0);
    expect(f.night).toBe(false);
    expect(faceOf(noon, 9).digital).toBe('21:00');
    expect(faceOf(noon, 9).dayDiff).toBe(0);
    expect(faceOf(Date.UTC(2026, 10, 22, 20, 0, 0), 9).dayDiff).toBe(1);
    expect(fmtSw(61_230)).toBe('01:01,23');
    expect(lapRows([1000, 3000, 7000]).map((l) => [l.n, l.d, l.kind])).toEqual([[3, 4000, 'worst'], [2, 2000, 'normal'], [1, 1000, 'best']]);
    expect(lapRows([1000, 2000]).every((l) => l.kind === 'normal')).toBe(true);
    expect(timerText(300)).toBe('05:00');
    expect(timerText(3725)).toBe('1:02:05');
    expect(timerText(0.2)).toBe('00:01');
    expect(clampTotal(10)).toBe(60);
    expect(clampTotal(99999)).toBe(5940);
    expect([repKind(0), repKind(127), repKind(WEEKDAYS), repKind(96), repKind(1)]).toEqual(['never', 'daily', 'weekdays', 'weekend', 'custom']);
    expect(toggleDay(0, 2)).toBe(4);
    expect(toggleDay(4, 2)).toBe(0);
  });
  it('calendrier : grilles, plages, événements, alertes', () => {
    expect(mondayOf('2026-11-22')).toBe('2026-11-16');
    expect(weekDays('2026-11-22')[6]).toBe('2026-11-22');
    expect(monthGrid('2026-11-10')[0]).toBe('2026-10-26');
    expect(monthGrid('2026-11-10').length).toBe(42);
    expect(monthGrid('2026-02-10').length).toBe(35);
    expect(rangeFor('week', '2026-11-22')).toEqual({ from: '2026-11-16', to: '2026-11-22' });
    expect(rangeFor('year', '2026-11-22')).toBeNull();
    const r = rangeFor('month', '2026-11-22');
    expect(r).not.toBeNull();
    expect(step('month', '2026-11-22', 1)).toBe('2026-12-01');
    expect(step('week', '2026-11-22', -1)).toBe('2026-11-15');
    expect(todayKey(Date.UTC(2026, 10, 22, 23, 59))).toBe('2026-11-22');
    const list = [ev({ id: 1 }), ev({ id: 2, start: '2026-11-21 22:00', stop: '2026-11-22 01:00', color: '#0088ff' }), ev({ id: 3, start: '2026-11-23 09:00', stop: '2026-11-23 10:00' })];
    expect(eventsOn(list, '2026-11-22').map((e) => e.id)).toEqual([2, 1]);
    expect(eventsOn(list, '2026-11-22', { post: true }).map((e) => e.id)).toEqual([1]);
    expect(blockOf(ev({}), '2026-11-22')).toEqual({ top: 8 * 56, height: 2 * 56 - 2 });
    expect(blockOf(list[1], '2026-11-22').top).toBe(0);
    expect(blockOf(list[1], '2026-11-21').top).toBe((22 * 56));
    expect(alertMinute({ start: '2026-11-22 08:00', allDay: false, alert: 15 })).toBe(465);
    expect(alertMinute({ start: '2026-11-22 00:10', allDay: false, alert: 30 })).toBe(1420);
    expect(alertMinute({ start: '2026-11-22 08:00', allDay: false, alert: null })).toBeNull();
    expect(ALERTS).toContain(1440);
  });
  it('rappels : filtres, compteurs, recherche, écarts de jours, échéance par défaut', () => {
    const today = '2026-11-22';
    const l = [rem({ id: 1, due: '2026-11-22 18:00', flag: true }), rem({ id: 2, due: '2026-11-25 10:00' }), rem({ id: 3 }), rem({ id: 4, done: true, due: '2026-11-20 09:00' }), rem({ id: 5, due: '2026-11-18 09:00', title: 'Retard' })];
    expect(l.filter((r) => inSel(r, 'today', today)).map((r) => r.id)).toEqual([1, 5]);
    expect(l.filter((r) => inSel(r, 'sched', today)).map((r) => r.id)).toEqual([1, 2, 5]);
    expect(l.filter((r) => inSel(r, 'all', today)).length).toBe(4);
    expect(l.filter((r) => inSel(r, 'flag', today)).map((r) => r.id)).toEqual([1]);
    expect(l.filter((r) => inSel(r, 'done', today)).map((r) => r.id)).toEqual([4]);
    expect(countOf(l, 1, today)).toBe(4);
    expect(visible(l, 'all', today, '').map((r) => r.id)).toEqual([5, 1, 2, 3]);
    expect(visible(l, 'all', today, 'RETARD').map((r) => r.id)).toEqual([5]);
    expect(dayDiff('2026-11-21 10:00', today)).toBe(-1);
    expect(dayDiff('2026-11-23 10:00', today)).toBe(1);
    expect(defaultDue(today, 14 * 60 + 32)).toBe('2026-11-22 15:00');
    expect(defaultDue(today, 23 * 60 + 40)).toBe('2026-11-22 23:00');
  });
  it('échéances : réunion des trois sources, minute de la journée', () => {
    expect(minuteOf('2026-11-22 07:05')).toBe(425);
    expect(minuteOf('demain')).toBeNull();
    expect(alarmItems([{ id: 1, minute: 420, enabled: true }, { id: 2, minute: 60, enabled: false }])).toEqual([{ id: 1, kind: 'alarm', minute: 420 }]);
    expect(eventItems([{ id: 3, start: '2026-11-22 00:10', allDay: false, alert: 30 }, { id: 4, start: '2026-11-22 09:00', allDay: true, alert: 0 }, { id: 5, start: 'x', allDay: false, alert: 5 }]))
      .toEqual([{ id: 3, kind: 'event', minute: 1420 }, { id: 4, kind: 'event', minute: 0 }]);
    expect(reminderItems([{ id: 6, done: false, due: '2026-11-22 18:30' }, { id: 7, done: true, due: '2026-11-22 18:30' }, { id: 8, done: false, due: null }]))
      .toEqual([{ id: 6, kind: 'reminder', minute: 1110 }]);
  });
});

describe('déverrouillage : échéances', () => {
  it('une seule liste réunit alarmes, alertes et rappels de la tablette', async () => {
    render(<Host />);
    await unlock();
    await waitFor(() => expect(currentSchedule().map((i) => i.kind).sort()).toEqual(['alarm', 'event', 'reminder']));
    const byKind = Object.fromEntries(currentSchedule().map((i) => [i.kind, i.minute]));
    expect(byKind).toEqual({ alarm: 420, event: 465, reminder: 1080 });
  });
});

describe('app-calc Calculette', () => {
  it('7 × 6 = 42, historique, scientifique, effacement', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('calculette'));
    // L'appli est chargée à la demande (React.lazy) : sous charge, le module peut mettre plus que les 1 s par défaut de findBy.
    // On attend donc d'abord qu'elle soit montée, avec une marge large ; les vérifications suivantes restent strictes.
    await screen.findByTestId('calc-display', {}, { timeout: 15_000 });
    for (const k of ['7', '×', '6', '=']) fireEvent.click(await screen.findByRole('button', { name: k }));
    expect(screen.getByTestId('calc-display').textContent).toBe('42');
    expect(screen.getAllByText('7 × 6').length).toBeGreaterThan(0);
    fireEvent.click(screen.getByRole('button', { name: 'Effacer l’historique'.replace('’', "'") }));
    expect(screen.getByText('Aucun calcul.')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Scientifique' }));
    expect(screen.queryByRole('button', { name: 'sin' })).toBeNull();
  }, 30_000);
});

describe('app-hor Horloge', () => {
  it('horloges du monde, alarmes (créer, couper, supprimer), chronomètre, minuteur serveur', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('horloge'));
    expect(await screen.findByLabelText('Los Santos')).toBeTruthy();
    expect(screen.getByLabelText('Paris')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Alarmes' }));
    expect(await screen.findByText('Réveil, En semaine')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Ajouter une alarme' }));
    fireEvent.click(await screen.findByRole('button', { name: 'Enregistrer' }));
    expect(await screen.findByText('Alarme, Jamais')).toBeTruthy();
    await waitFor(() => expect(currentSchedule().filter((i) => i.kind === 'alarm').length).toBe(2));
    const switches = screen.getAllByRole('switch');
    fireEvent.click(switches[switches.length - 1]);
    await waitFor(() => expect(currentSchedule().filter((i) => i.kind === 'alarm').length).toBe(1));
    fireEvent.click(screen.getByRole('button', { name: 'Modifier' }));
    fireEvent.click(screen.getAllByRole('button', { name: "Supprimer l'alarme" })[0]);
    await waitFor(() => expect(screen.getAllByRole('switch').length).toBe(1));
    // Chronomètre
    fireEvent.click(screen.getByRole('button', { name: 'Chronomètre' }));
    expect(screen.getByTestId('sw-text').textContent).toBe('00:00,00');
    fireEvent.click(screen.getByRole('button', { name: 'Démarrer ou arrêter' }));
    fireEvent.click(await screen.findByRole('button', { name: 'Tour ou réinitialiser' }));
    expect(await screen.findByText('Tour 1')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Démarrer ou arrêter' }));
    fireEvent.click(screen.getByRole('button', { name: 'Tour ou réinitialiser' }));
    expect(screen.queryByText('Tour 1')).toBeNull();
    // Minuteur
    fireEvent.click(screen.getByRole('button', { name: 'Minuteurs' }));
    expect(screen.getByTestId('timer-text').textContent).toBe('05:00');
    fireEvent.click(screen.getByRole('button', { name: '10 min' }));
    expect(screen.getByTestId('timer-text').textContent).toBe('10:00');
    fireEvent.click(screen.getByRole('button', { name: 'Démarrer ou mettre en pause' }));
    expect(await screen.findByText('Pause')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Annuler le minuteur' }));
    await waitFor(() => expect(screen.queryByText('Pause')).toBeNull());
    expect(screen.getByTestId('timer-text').textContent).toBe('10:00');
  });
});

describe('app-rem Rappels', () => {
  it('tuiles, cocher, signaler, ajouter, nouvelle liste, recherche', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('rappels'));
    expect(await screen.findByText('Rédiger le rapport')).toBeTruthy();
    fireEvent.click(screen.getAllByRole('checkbox', { name: 'Terminer' })[0]);
    await waitFor(() => expect(screen.queryByText('Rédiger le rapport')).toBeNull());
    await waitFor(() => expect(currentSchedule().filter((i) => i.kind === 'reminder').length).toBe(0));
    fireEvent.click(screen.getByRole('button', { name: /Tous/ }));
    fireEvent.click(screen.getByRole('button', { name: 'Ajouter un rappel' }));
    const input = await screen.findByLabelText('Nouveau rappel');
    fireEvent.change(input, { target: { value: 'Faire le plein' } });
    fireEvent.keyDown(input, { key: 'Enter' });
    expect(await screen.findByText('Faire le plein')).toBeTruthy();
    fireEvent.click(screen.getAllByRole('button', { name: 'Signaler' })[0]);
    await waitFor(() => expect(screen.getAllByRole('button', { name: 'Signaler' })[0].getAttribute('aria-pressed')).toBe('true'));
    fireEvent.change(screen.getByLabelText('Rechercher'), { target: { value: 'plein' } });
    expect(screen.queryByText('Appeler Lina')).toBeNull();
    fireEvent.change(screen.getByLabelText('Rechercher'), { target: { value: '' } });
    fireEvent.click(screen.getByRole('button', { name: 'Ajouter une liste' }));
    fireEvent.change(await screen.findByLabelText('Nom de la liste'), { target: { value: 'Garage' } });
    fireEvent.click(screen.getByRole('button', { name: 'Enregistrer' }));
    expect((await screen.findAllByText('Garage')).length).toBeGreaterThan(0);
    fireEvent.click(screen.getByRole('button', { name: 'Supprimer la liste' }));
    await waitFor(() => expect(screen.queryByText('Garage')).toBeNull());
  });
});

describe('app-cal Calendrier', () => {
  it('semaine, mois, année, création, détail et suppression, calendriers masqués', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('calendrier'));
    expect(await screen.findByText('Patrouille')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Mois' }));
    expect(await screen.findByText('Patrouille')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Année' }));
    expect(await screen.findAllByText(/janvier/i)).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Semaine' }));
    fireEvent.click(await screen.findByText('Patrouille'));
    expect(await screen.findByText('Vinewood Boulevard')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Fermer' }));
    // Calendrier masqué : l'événement rouge disparaît
    fireEvent.click(screen.getByRole('button', { name: 'Patrouilles' }));
    await waitFor(() => expect(screen.queryByText('Patrouille')).toBeNull());
    fireEvent.click(screen.getByRole('button', { name: 'Patrouilles' }));
    expect(await screen.findByText('Patrouille')).toBeTruthy();
    // Création
    fireEvent.click(screen.getByRole('button', { name: 'Ajouter un événement' }));
    fireEvent.change(await screen.findByLabelText('Titre'), { target: { value: 'Brunch' } });
    fireEvent.click(screen.getByRole('button', { name: 'Enregistrer' }));
    expect(await screen.findByText('Brunch')).toBeTruthy();
    // Suppression
    fireEvent.click(screen.getByText('Brunch'));
    fireEvent.click(await screen.findByRole('button', { name: 'Supprimer' }));
    await waitFor(() => expect(screen.queryByText('Brunch')).toBeNull());
  });
  it('titre vide ou fin avant le début : refusé côté interface', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('calendrier'));
    fireEvent.click(await screen.findByRole('button', { name: 'Ajouter un événement' }));
    fireEvent.click(await screen.findByRole('button', { name: 'Enregistrer' }));
    expect(await screen.findByText('Donnez un titre')).toBeTruthy();
    fireEvent.change(screen.getByLabelText('Titre'), { target: { value: 'X' } });
    fireEvent.change(screen.getByLabelText('Début'), { target: { value: '18:00' } });
    fireEvent.change(screen.getByLabelText('Fin'), { target: { value: '17:00' } });
    fireEvent.click(screen.getByRole('button', { name: 'Enregistrer' }));
    expect(await screen.findByText('La fin doit suivre le début')).toBeTruthy();
  });
});
