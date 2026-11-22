import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { luaJson } from '../nui/lua-json';
import { mockOpen, resetMock } from '../nui/mock';
import { closeTablet, handleMessage, openApp, submitCode } from './actions';
import { currentSchedule, resetSchedule } from './schedule';
import { Host } from './Tablet';

// Le serveur Lua n'envoie pas une clé à nil : l'interface reçoit `undefined`, jamais `null`.
// Le simulateur (mock) passe déjà par luaJson ; ces tests vérifient que ce passage supprime bien la clé,
// puis que les applis la tolèrent (régression du commit c572cbc).

async function unlock() {
  act(() => handleMessage('open', mockOpen()));
  await act(async () => { await submitCode('1234'); });
}

beforeEach(() => { resetMock(); resetSchedule(); closeTablet(); });
afterEach(() => { cleanup(); closeTablet(); vi.restoreAllMocks(); });

describe('clé absente (nil Lua)', () => {
  it('la simulation retire bien les clés nil', () => {
    const r = luaJson({ events: [{ id: 2, alert: null, title: 'x' }], note: { folder: null, id: 1 } });
    expect('alert' in r.events[0]!).toBe(false);
    expect('folder' in r.note).toBe(false);
  });

  it("Calendrier : un événement sans clé `alert` s'affiche, n'ajoute aucune échéance et ne plante pas", async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('calendrier'));
    fireEvent.click(await screen.findByRole('button', { name: 'Semaine' }, { timeout: 15_000 }));
    fireEvent.click(await screen.findByRole('button', { name: 'Suivant' })); // l'événement sans alerte est le 24, la semaine suivante
    expect(await screen.findByText('Réunion au poste')).toBeTruthy();
    // Seule l'alerte de « Patrouille » existe : une alerte absente ne doit pas produire une échéance NaN.
    await waitFor(() => expect(currentSchedule().filter((i) => i.kind === 'event').map((i) => i.minute)).toEqual([465]));
    expect(screen.queryByText(/ne répond plus|a rencontré/i)).toBeNull();
  }, 30_000);

  it("Notes : une note sans clé `folder` est dans le dossier par défaut et s'ouvre", async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('notes'));
    expect(await screen.findByText('Courses', {}, { timeout: 15_000 })).toBeTruthy();
    fireEvent.click(await screen.findByRole('button', { name: /^Notes/ }));
    fireEvent.click(await screen.findByText('Courses'));
    expect(await screen.findByLabelText('Titre')).toBeTruthy();
    await waitFor(() => expect((screen.getByLabelText('Titre') as HTMLInputElement).value).toBe('Courses'));
  }, 30_000);
});
