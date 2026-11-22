import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { PHRASES, WORDS, ORDER } from '../apps/traduire/dict';
import { bubble, suggest, translate } from '../apps/traduire/model';
import { PLACES, bars, compass, forecast, hourly, placeNow, placeSky, skyOf } from '../apps/meteo/model';
import { estimateKm, mapPoint, search, tripOf, type PlacePin } from '../apps/plans/model';
import { applyTick, changeOf, series, type Stock } from '../apps/bourse/model';
import { mockOpen, resetMock } from '../nui/mock';
import { routeActive } from '../nui/mock-tools';
import { closeTablet, handleMessage, openApp, submitCode } from './actions';
import { Host } from './Tablet';

async function unlock() {
  act(() => handleMessage('open', mockOpen()));
  await act(async () => { await submitCode('1234'); });
}

beforeEach(() => { resetMock(); closeTablet(); });
afterEach(() => { cleanup(); closeTablet(); vi.restoreAllMocks(); });

describe('arb-03 Traduire hors ligne : fonction de traduction', () => {
  it('phrase connue : fr vers en, en vers es, sans accents ni ponctuation', () => {
    expect(translate('Où est le poste de police ?', 'fr', 'en')).toMatchObject({ kind: 'phrase', text: 'Where is the police station?' });
    expect(translate('where is the police station', 'en', 'es')).toMatchObject({ kind: 'phrase', text: '¿Dónde está la comisaría?' });
    expect(translate('OU EST LE POSTE DE POLICE', 'fr', 'ar').text).toBe('أين مركز الشرطة؟');
  });
  it('mot à mot, mots composés et mots inconnus', () => {
    expect(translate('bonjour merci', 'fr', 'en')).toMatchObject({ kind: 'words', text: 'hello thanks', unknown: 0 });
    expect(translate('tout droit', 'fr', 'de').text).toBe('geradeaus');
    const mixed = translate('police zzz', 'fr', 'es');
    expect(mixed).toMatchObject({ kind: 'words', text: 'policía zzz', unknown: 1 });
    expect(translate('xyzzy plugh', 'fr', 'en')).toMatchObject({ kind: 'none', text: '' });
  });
  it('texte vide, même langue, langue inconnue', () => {
    expect(translate('  ', 'fr', 'en').kind).toBe('empty');
    expect(translate('Bonjour', 'fr', 'fr')).toMatchObject({ kind: 'same', text: 'Bonjour' });
    expect(translate('Bonjour', 'fr', 'xx').kind).toBe('none');
  });
  it('dictionnaire complet : 10 langues partout, suggestions, bulles', () => {
    expect(ORDER.length).toBe(10);
    for (const r of [...PHRASES, ...WORDS]) for (const l of ORDER) expect(r[l], `${r.en} / ${l}`).toBeTruthy();
    expect(PHRASES.length).toBeGreaterThanOrEqual(25);
    expect(WORDS.length).toBeGreaterThanOrEqual(190);
    expect(suggest('comb', 'fr')).toContain('Combien ça coûte ?');
    expect(suggest('c', 'fr')).toEqual([]);
    expect(bubble('a', 'fr', 'en', 'Combien ça coûte ?')).toMatchObject({ ok: true, out: 'How much is it?' });
    expect(bubble('b', 'fr', 'en', 'qsdfgh')).toMatchObject({ ok: false, out: '' });
  });
});

describe('app-tra Traduire', () => {
  it('traduit, met en favori, retrouve le favori ; le service du serveur est absent sans effet', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('traduire'));
    const input = await screen.findByLabelText('Texte à traduire');
    fireEvent.change(input, { target: { value: 'Combien ça coûte ?' } });
    expect(screen.getByTestId('tra-out').textContent).toBe('How much is it?');
    fireEvent.click(screen.getByRole('button', { name: 'Ajouter aux favoris' }));
    await waitFor(() => expect(screen.getByRole('button', { name: 'Ajouter aux favoris' }).getAttribute('aria-pressed')).toBe('true'));
    fireEvent.click(screen.getByRole('button', { name: /Favoris/ }));
    expect(await screen.findByText('Combien ça coûte ?')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Retirer des favoris' }));
    expect(await screen.findByText(/Aucun favori/)).toBeTruthy();
  });
  it('conversation : deux sens, phrase inconnue signalée', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('traduire'));
    fireEvent.click(await screen.findByRole('button', { name: /Conversation/ }));
    fireEvent.change(screen.getByLabelText('Message'), { target: { value: 'Merci' } });
    fireEvent.click(screen.getByRole('button', { name: 'Français' }));
    expect(await screen.findByText('thanks')).toBeTruthy();
    fireEvent.change(screen.getByLabelText('Message'), { target: { value: 'qwerty' } });
    fireEvent.click(screen.getByRole('button', { name: 'English' }));
    expect(await screen.findByText('Traduction indisponible hors connexion')).toBeTruthy();
  });
});

describe('modèle Météo', () => {
  it('familles du jeu, lieux dérivés, vent et boussole', () => {
    expect(['clear', 'clouds', 'fog', 'rain', 'thunder', 'snow'].map(skyOf)).toEqual(['S', 'C', 'C', 'R', 'R', 'N']);
    expect(placeSky('clear', 'pb')).toBe('C');
    expect(placeSky('rain', 'mc')).toBe('N');
    expect(compass(270)).toBe(6);
    expect(compass(-45)).toBe(7);
    const w = { temp: 24, kind: 'clear', hi: 27, lo: 18, wind: 10, deg: 270 };
    const ls = placeNow(w, PLACES[0]!, 14);
    const ss = placeNow(w, PLACES[1]!, 14);
    expect(ls).toMatchObject({ sky: 'S', temp: 24, hi: 27, lo: 18, wind: 10, dir: 6 });
    expect(ss.temp).toBe(33);
    expect(placeNow(w, PLACES[0]!, 23).uv).toBe(0);
    expect(placeNow(w, PLACES[0]!, 14)).toEqual(ls);
  });
  it('prévisions déterministes : 12 heures, 10 jours, barres bornées', () => {
    const n = placeNow({ temp: 20, kind: 'rain', hi: 23, lo: 15 }, PLACES[2]!, 22);
    const h = hourly(n, 22);
    expect(h).toHaveLength(12);
    expect(h[0]).toMatchObject({ label: 'now', pct: 40 });
    expect(hourly(placeNow({ temp: 20, kind: 'clear' }, PLACES[0]!, 22), 22)[0]!.moon).toBe(true);
    const d = forecast(n, PLACES[2]!);
    expect(d).toHaveLength(10);
    expect(d[0]).toMatchObject({ sky: n.sky, hi: n.hi, lo: n.lo });
    expect(forecast(n, PLACES[2]!)).toEqual(d);
    for (const b of bars(d)) { expect(b.left).toBeGreaterThanOrEqual(0); expect(b.width).toBeGreaterThanOrEqual(8); }
  });
});

describe('app-met Météo', () => {
  it('suit la météo du jeu, change de lieu et d\'unité', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('meteo'));
    expect((await screen.findByTestId('met-temp')).textContent).toBe('24°');
    expect(screen.getAllByText('Ensoleillé').length).toBeGreaterThan(0);
    fireEvent.click(document.querySelector('[data-place="ss"]') as HTMLElement);
    expect(screen.getByTestId('met-temp').textContent).toBe('33°');
    fireEvent.click(screen.getByRole('button', { name: 'Changer d’unité' }));
    expect(screen.getByTestId('met-temp').textContent).toBe('91°');
    act(() => handleMessage('weather', { temp: 15, kind: 'rain', hi: 18, lo: 11, wind: 30, deg: 90, city: 'Los Santos' }));
    fireEvent.click(document.querySelector('[data-place="ls"]') as HTMLElement);
    expect(screen.getByTestId('met-temp').textContent).toBe('59°');
    expect(screen.getAllByText('Pluvieux').length).toBeGreaterThan(0);
    fireEvent.change(screen.getByLabelText('Rechercher un lieu'), { target: { value: 'zzz' } });
    expect(screen.getByText('Aucun lieu.')).toBeTruthy();
  });
});

describe('modèle Plans', () => {
  const pins: PlacePin[] = [
    { id: 'a', name: 'Banque Centrale', short: 'B', area: 'Alta', cat: 'bank', addr: '1 Main St', phone: '', hours: 'h24', icon: 'bank', col: '#000', x: 0, y: 0, z: 0, mx: 1000, my: 860 },
    { id: 'b', name: 'Café du Port', short: 'C', area: 'Port', cat: 'cafe', addr: '2 Quai', phone: '', hours: '23', icon: 'cup', col: '#000', x: 0, y: 0, z: 0, mx: 1100, my: 900 },
  ];
  it('recherche (nom, catégorie, adresse), trajet, carte', () => {
    const cat = (c: string) => (c === 'bank' ? 'Banque' : 'Café');
    expect(search(pins, 'banque', cat, (p) => p.name).map((p) => p.id)).toEqual(['a']);
    expect(search(pins, 'quai', cat, (p) => p.name).map((p) => p.id)).toEqual(['b']);
    expect(search(pins, '  ', cat, (p) => p.name)).toEqual([]);
    expect(estimateKm(pins[0]!, pins[1]!)).toBeCloseTo(0.588, 3);
    expect(tripOf(38, 'car', 14, 32)).toEqual({ km: 38, min: 60, arrival: '15:32' });
    expect(tripOf(0.01, 'walk', 23, 59)).toMatchObject({ min: 1, arrival: '00:00' });
    expect(mapPoint(441, -982)).toEqual({ mx: 1090, my: 790 });
    expect(mapPoint(99999, 99999)).toEqual({ mx: 1940, my: 60 });
  });
});

describe('app-pla Plans', () => {
  it('favoris, lieu, itinéraire natif puis annulation', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('plans'));
    expect(await screen.findByText('Favoris')).toBeTruthy();
    await waitFor(() => expect(document.querySelectorAll('[data-fav]').length).toBe(3));
    fireEvent.change(screen.getByLabelText('Rechercher un lieu'), { target: { value: 'banque' } });
    fireEvent.click(await screen.findByText('Fleeca Bank, Legion Square'));
    expect(await screen.findByText(/Banque ·/)).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Favori' }));
    await waitFor(() => expect(screen.getByRole('button', { name: 'Favori' }).getAttribute('aria-pressed')).toBe('true'));
    fireEvent.click(screen.getByRole('button', { name: /^Itinéraire/ }));
    expect(routeActive()).toBe(false);
    fireEvent.click(screen.getByRole('button', { name: 'Démarrer' }));
    expect(await screen.findByRole('button', { name: 'Terminer' })).toBeTruthy();
    expect(routeActive()).toBe(true);
    expect(screen.getByText(/Alta St/)).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Terminer' }));
    await waitFor(() => expect(routeActive()).toBe(false));
    expect(await screen.findByText('Récents')).toBeTruthy();
    expect(document.querySelectorAll('[data-row]').length).toBe(1);
  });
});

describe('modèle Bourse', () => {
  const s: Stock = { sym: 'MAZE', name: 'Maze Bank', price: 412.6, open: 405.3, volume: 4.2, ch: [3.1, 5.4, 9.8, 22.5, 140] };
  it('séries déterministes calées sur le cours en direct et la variation', () => {
    for (const p of [0, 1, 2, 3, 4, 5] as const) {
      const a = series(1, p, s);
      expect(a[a.length - 1]).toBeCloseTo(412.6, 6);
      expect(series(1, p, s)).toEqual(a);
      const pct = (a[a.length - 1]! / a[0]! - 1) * 100;
      expect(pct).toBeCloseTo(changeOf(s, p), 4);
    }
    expect(changeOf(s, 0)).toBeCloseTo((412.6 / 405.3 - 1) * 100, 6);
    expect(changeOf(s, 2)).toBe(5.4);
  });
  it('paquet push : appliqué par index, paquet invalide ignoré', () => {
    const items = [s, { ...s, sym: 'FLCA', price: 87.35 }];
    expect(applyTick(items, [42000, 8800]).map((x) => x.price)).toEqual([420, 88]);
    expect(applyTick(items, [42000])).toBe(items);
    expect(applyTick(items, [42000, -1])).toBe(items);
    expect(applyTick(items, 'x')).toBe(items);
  });
});

describe('app-bou Bourse', () => {
  it('abonnement, cours poussés, liste de suivi, période et survol', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('bourse'));
    expect(await screen.findByTestId('price-MAZE')).toBeTruthy();
    expect(screen.getByTestId('price-MAZE').textContent).toBe('412,60');
    act(() => { window.dispatchEvent(new CustomEvent('pop-market', { detail: { p: [1184230, 42000, 8735, 15620, 6480, 20345, 9810] } })); });
    expect(screen.getByTestId('price-MAZE').textContent).toBe('420,00');
    fireEvent.click(document.querySelector('[data-sym="FLCA"]') as HTMLElement);
    expect(screen.getAllByText('Fleeca Bank').length).toBeGreaterThan(0);
    const before = screen.getByTestId('chart-line').getAttribute('d');
    fireEvent.click(screen.getByRole('button', { name: '1A' }));
    expect(screen.getByTestId('chart-line').getAttribute('d')).not.toBe(before);
    expect(screen.getByText('Chiffres clés')).toBeTruthy();
    expect(screen.getByText('Actualités')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Modifier la liste' }));
    fireEvent.click(screen.getByRole('button', { name: 'Ne plus suivre PISS' }));
    await waitFor(() => expect(screen.getByRole('button', { name: 'Suivre PISS' })).toBeTruthy());
    fireEvent.click(screen.getByRole('button', { name: 'Terminé' }));
    expect(document.querySelector('[data-sym="PISS"]')).toBeNull();
    expect(document.querySelector('[data-sym="MAZE"]')).not.toBeNull();
  });
});
