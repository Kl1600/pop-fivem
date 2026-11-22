import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { mockOpen, resetMock } from '../nui/mock';
import { closeTablet, handleMessage, openApp, submitCode } from './actions';
import { Host } from './Tablet';
import { quote, type MailItem } from '../apps/mail';

beforeEach(() => { resetMock(); closeTablet(); });
afterEach(() => { cleanup(); closeTablet(); });

describe('app-mai Mail', () => {
  it('quote : répondre garde l\'expéditeur, transférer vide le destinataire, un seul préfixe', () => {
    const m: MailItem = { id: 1, from: 'a@pop.ls', to: 'moi@pop.ls', subject: 'Salut', body: 'l1\nl2', at: 0, read: true, flag: false, folder: 'inbox' };
    const t = (k: string) => (k === 'mail.re' ? 'Re:' : k === 'mail.fwd' ? 'Fwd:' : 'From');
    expect(quote(m, 'reply', t, 'moi@pop.ls')).toMatchObject({ to: 'a@pop.ls', subject: 'Re: Salut' });
    expect(quote(m, 'forward', t, 'moi@pop.ls')).toMatchObject({ to: '', subject: 'Fwd: Salut' });
    expect(quote({ ...m, subject: 'Re: Salut' }, 'reply', t, 'x').subject).toBe('Re: Salut');
    expect(quote(m, 'reply', t, 'moi@pop.ls').body).toContain('> l2');
  });

  it('lecture, drapeau, archive, rédaction et envoi', async () => {
    render(<Host />);
    act(() => handleMessage('open', mockOpen()));
    await act(async () => { await submitCode('1234'); });
    act(() => openApp('mail'));
    await waitFor(() => expect(screen.getByText('Votre véhicule est prêt')).toBeTruthy());
    fireEvent.click(screen.getByLabelText('Votre véhicule est prêt'));
    await waitFor(() => expect(screen.getByText(/prêt à être récupéré/)).toBeTruthy());
    fireEvent.click(screen.getByText('Marquer d\'un drapeau'));
    await waitFor(() => expect(screen.getByText('Retirer le drapeau')).toBeTruthy());
    fireEvent.click(within(screen.getByRole('article')).getByText('Archive'));
    await waitFor(() => expect(screen.queryByText(/prêt à être récupéré/)).toBeNull());
    fireEvent.click(screen.getByRole('button', { name: 'Nouveau mail' }));
    fireEvent.change(await screen.findByLabelText('À'), { target: { value: 'lina.costa@pop.ls' } });
    fireEvent.change(screen.getByLabelText('Objet'), { target: { value: 'Test' } });
    fireEvent.change(screen.getByLabelText('Message'), { target: { value: 'Corps' } });
    fireEvent.click(screen.getByText('Envoyer'));
    await waitFor(() => expect(screen.getByText('Mail envoyé')).toBeTruthy());
  });
});
