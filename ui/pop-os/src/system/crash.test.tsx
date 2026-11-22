import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { registerApiApp } from '../apps/registry';
import { mockOpen, resetMock } from '../nui/mock';
import { closeTablet, handleMessage, openApp, submitCode } from './actions';
import { os } from './store';
import { Host } from './Tablet';

function Boom(): never { throw new Error('boom'); }

beforeEach(() => { resetMock(); closeTablet(); vi.spyOn(console, 'error').mockImplementation(() => undefined); });
afterEach(() => { cleanup(); closeTablet(); vi.restoreAllMocks(); });

async function unlock() {
  render(<Host />);
  act(() => handleMessage('open', mockOpen()));
  await act(async () => { await submitCode('1234'); });
}

describe('filet de sécurité (ErrorBoundary)', () => {
  it('une appli qui plante affiche l’écran de secours, Fermer revient à l’accueil, le reste marche', async () => {
    registerApiApp({ id: 'boom', nameKey: 'boom', domain: 'api', load: async () => ({ default: Boom }) });
    await unlock();
    act(() => os.set({ apps: [...os.get().apps, 'boom'] }));
    act(() => openApp('boom'));
    const alert = await screen.findByRole('alert');
    expect(alert.textContent).toContain('Cette app a rencontré un problème');
    expect(console.error).toHaveBeenCalled();
    fireEvent.click(screen.getByRole('button', { name: 'Fermer' }));
    await waitFor(() => expect(os.get().app).toBeNull());
    await waitFor(() => expect(screen.queryByRole('alert')).toBeNull());
    // L'accueil reste utilisable : une autre appli s'ouvre normalement.
    act(() => openApp('calculette'));
    expect(os.get().app).toBe('calculette');
    expect(screen.queryByRole('alert')).toBeNull();
  });

  it('racine : si la tablette plante, Échap ferme, et elle se rouvre ensuite', async () => {
    await unlock();
    // Un état invalide fait planter l’écran (réglages absents).
    act(() => os.set({ settings: null as never }));
    expect(await screen.findByRole('alert')).toBeTruthy();
    fireEvent.keyDown(window, { key: 'Escape' });
    await waitFor(() => expect(screen.queryByRole('alert')).toBeNull());
    expect(os.get().open).toBe(false);
    act(() => handleMessage('open', mockOpen()));
    expect(document.querySelector('.pop')).not.toBeNull();
    expect(screen.queryByRole('alert')).toBeNull();
  });
});
