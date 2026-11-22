import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { duration, gradOf, initials, splitName, whenOf } from '../kit';
import { mockOpen, resetMock } from '../nui/mock';
import { closeTablet, handleMessage, openApp, submitCode } from './actions';
import { os } from './store';
import { Host } from './Tablet';

async function unlock() {
  act(() => handleMessage('open', mockOpen()));
  await act(async () => { await submitCode('1234'); });
}

beforeEach(() => { resetMock(); closeTablet(); });
afterEach(() => { cleanup(); closeTablet(); vi.restoreAllMocks(); });

const push = (name: string, detail: unknown) => act(() => { window.dispatchEvent(new CustomEvent(name, { detail })); });
const t = (k: string) => k;

describe('com-01 aides communes', () => {
  it('nom, initiales, dégradé stable, durée', () => {
    expect(splitName('Lina Costa')).toEqual({ first: 'Lina', last: 'Costa' });
    expect(splitName('Garage Del Perro')).toEqual({ first: 'Garage', last: 'Del Perro' });
    expect(splitName('Madonna')).toEqual({ first: 'Madonna', last: '' });
    expect(initials('lina costa')).toBe('LC');
    expect(initials('')).toBe('?');
    expect(gradOf('555-0187')).toBe(gradOf('555-0187'));
    expect(duration(75)).toBe('1:15');
  });
  it('heure du jour, hier, date', () => {
    const now = new Date(2026, 10, 22, 12, 0, 0).getTime();
    expect(whenOf(now / 1000 - 3600, t, 'fr', now)).toBe('11:00');
    expect(whenOf(now / 1000 - 86400, t, 'fr', now)).toBe('com.yesterday');
    expect(whenOf(now / 1000 - 5 * 86400, t, 'fr', now)).toMatch(/\d/);
  });
});

describe('app-msg Messages', () => {
  it('conversations, fil, envoi, accusé Lu, pièces jointes', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('messages'));
    expect((await screen.findAllByText('Sam Leroy')).length).toBeGreaterThan(0);
    expect(screen.getByText('Équipe Mission Row')).toBeTruthy();
    fireEvent.click(screen.getAllByText('Sam Leroy')[0] as HTMLElement);
    expect(await screen.findByText('Briefing à Mission Row à 18h.')).toBeTruthy();
    fireEvent.change(screen.getByLabelText('Message'), { target: { value: 'Bien reçu' } });
    fireEvent.click(screen.getByRole('button', { name: 'Envoyer' }));
    expect((await screen.findAllByText('Bien reçu')).length).toBeGreaterThan(0);
    expect(screen.getByText('Distribué')).toBeTruthy();
    push('pop-message', { read: '555-0123' });
    expect(screen.getByText('Lu')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Ajouter' }));
    fireEvent.click(screen.getByRole('button', { name: 'Position' }));
    expect((await screen.findAllByLabelText('Position partagée')).length).toBeGreaterThan(0);
  });
  it('recherche et conversation épinglée', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('messages'));
    await screen.findByText('Équipe Mission Row');
    fireEvent.change(screen.getByLabelText('Rechercher'), { target: { value: 'zzzz' } });
    expect(screen.getByText('Aucun résultat.')).toBeTruthy();
    fireEvent.change(screen.getByLabelText('Rechercher'), { target: { value: 'Noah' } });
    fireEvent.click(await screen.findByText('Noah Petit'));
    fireEvent.click(await screen.findByRole('button', { name: 'Épingler' }));
    expect(await screen.findByRole('button', { name: 'Désépingler' })).toBeTruthy();
  });
  it('nouveau message : numéro saisi, puis groupe à trois', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('messages'));
    await screen.findByText('Équipe Mission Row');
    fireEvent.click(screen.getByRole('button', { name: 'Nouveau message' }));
    fireEvent.change(screen.getByLabelText('Nom ou numéro'), { target: { value: '555-0999' } });
    fireEvent.click(screen.getByRole('button', { name: 'Créer' }));
    expect(await screen.findByLabelText('Message')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Nouveau message' }));
    const sheet = within(screen.getByRole('dialog', { name: 'Nouveau message' }));
    fireEvent.click(sheet.getByRole('button', { name: 'Lina Costa' }));
    fireEvent.click(sheet.getByRole('button', { name: 'Sam Leroy' }));
    fireEvent.change(screen.getByLabelText('Nom du groupe'), { target: { value: 'Brigade' } });
    fireEvent.click(screen.getByRole('button', { name: 'Créer' }));
    expect((await screen.findAllByText('Brigade')).length).toBeGreaterThan(0);
  });
  it('message reçu tablette ouverte : notification, badge ; appli ouverte : fil relu', async () => {
    render(<Host />);
    await unlock();
    const before = os.get().notifs.length;
    act(() => handleMessage('message', { from: '555-0123', to: '555-0142', body: 'yo', kind: 'text', id: 99, at: 1 }));
    expect(os.get().notifs.length).toBe(before + 1);
    expect(os.get().notifs[0]?.app).toBe('messages');
    act(() => handleMessage('message', { read: '555-0123' }));
    expect(os.get().notifs.length).toBe(before + 1);
  });
});

describe('app-tel Téléphone', () => {
  it('composer, sonner, décrocher à distance, raccrocher', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('telephone'));
    fireEvent.click(await screen.findByRole('button', { name: 'Clavier' }));
    for (const d of '5550123') fireEvent.click(screen.getByRole('button', { name: d }));
    expect(screen.getByText('555-0123')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Appeler' }));
    const dlg = await screen.findByRole('dialog');
    expect(within(dlg).getByText('Sam Leroy')).toBeTruthy();
    expect(within(dlg).getByText('Ça sonne…')).toBeTruthy();
    push('pop-call', { id: 101, state: 'active', from: '555-0123' });
    expect(within(screen.getByRole('dialog')).getByText('0:00')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Raccrocher' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
  });
  it('fin d\'appel poussée par le serveur, numéro injoignable : message vocal', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('telephone'));
    fireEvent.click(await screen.findByRole('button', { name: 'Clavier' }));
    for (const d of '5550000') fireEvent.click(screen.getByRole('button', { name: d }));
    fireEvent.click(screen.getByRole('button', { name: 'Appeler' }));
    expect(await screen.findByLabelText('Votre message')).toBeTruthy();
    fireEvent.change(screen.getByLabelText('Votre message'), { target: { value: 'Rappelle-moi' } });
    fireEvent.click(screen.getByRole('button', { name: 'Envoyer' }));
    await waitFor(() => expect(screen.queryByLabelText('Votre message')).toBeNull());
  });
  it('appel entrant : ouvre le Téléphone, refuser puis accepter', async () => {
    render(<Host />);
    await unlock();
    act(() => handleMessage('call', { id: 7, state: 'ring', from: '555-0123' }));
    const dlg = await screen.findByRole('dialog', { name: 'Appel entrant' });
    expect(within(dlg).getByText('Sam Leroy')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Refuser' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    push('pop-call', { id: 8, state: 'ring', from: '555-0166' });
    fireEvent.click(await screen.findByRole('button', { name: 'Accepter' }));
    expect(await screen.findByRole('button', { name: 'Raccrocher' })).toBeTruthy();
    push('pop-call', { id: 8, state: 'end', why: 'hangup' });
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
  });
  it('récents, manqués, messagerie vocale', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('telephone'));
    expect(await screen.findAllByText('Appel manqué')).toHaveLength(2);
    fireEvent.click(screen.getByRole('button', { name: 'Manqués' }));
    expect(screen.queryByText('Appel sortant')).toBeNull();
    fireEvent.click(screen.getByRole('button', { name: 'Messagerie' }));
    expect(await screen.findByText('Rappelle-moi quand tu peux.')).toBeTruthy();
  });
});

describe('app-con Contacts', () => {
  it('liste alphabétique, fiche, ajout, modification, suppression', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('contacts'));
    expect(await screen.findByText('Costa')).toBeTruthy();
    expect(screen.getAllByText('12 Vinewood Boulevard, Vinewood').length).toBe(1);
    fireEvent.click(screen.getByRole('button', { name: 'Nouveau contact' }));
    fireEvent.change(screen.getByLabelText('Prénom'), { target: { value: 'Eli' } });
    fireEvent.change(screen.getByLabelText('Nom'), { target: { value: 'Garcia' } });
    fireEvent.change(document.querySelector('input[aria-label="Téléphone"]') as HTMLElement, { target: { value: '555-0150' } });
    fireEvent.click(screen.getByRole('button', { name: 'OK' }));
    expect(await screen.findByText('Garcia')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Modifier' }));
    fireEvent.click(screen.getByRole('button', { name: 'Supprimer le contact' }));
    await waitFor(() => expect(screen.queryByText('Garcia')).toBeNull());
  });
  it('groupes, recherche, favori, message ouvre Messages', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('contacts'));
    await screen.findByText('Costa');
    fireEvent.click(screen.getByRole('button', { name: 'LSPD' }));
    expect(screen.queryByText('Costa')).toBeNull();
    expect(screen.getByText('Leroy')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Tous' }));
    fireEvent.change(screen.getByLabelText('Rechercher'), { target: { value: '0199' } });
    expect(screen.queryByText('Costa')).toBeNull();
    expect(screen.getByText('Del Perro')).toBeTruthy();
    fireEvent.change(screen.getByLabelText('Rechercher'), { target: { value: '' } });
    fireEvent.click(await screen.findByText('Moreau'));
    fireEvent.click(screen.getByRole('button', { name: 'favori' }));
    await waitFor(() => expect(screen.getByRole('button', { name: 'favori' }).getAttribute('aria-pressed')).toBe('true'));
    fireEvent.click(screen.getByRole('button', { name: 'message' }));
    expect(await screen.findByLabelText('Message')).toBeTruthy();
  });
  it('partage de contact à proximité : feuille ouverte', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('contacts'));
    await screen.findByText('Costa');
    fireEvent.click(screen.getByRole('button', { name: 'partager' }));
    expect(await screen.findByText('Partager à proximité')).toBeTruthy();
  });
});
