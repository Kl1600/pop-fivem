import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { checkImports } from '../../scripts/check-imports.mjs';
import { checkStrings, findLiterals } from '../../scripts/check-strings.mjs';
import { registerApiApp } from '../apps/registry';
import { LANGUAGES, makeT, missingKeys } from '../i18n';
import en from '../i18n/en';
import fr from '../i18n/fr';
import { mockOpen, resetMock } from '../nui/mock';
import { clockTimerActive, formatDate, formatTime, gameDate, msToNextMinute } from './clock';
import { closeApp, closeTablet, handleMessage, openApp, pushNotify, submitCode } from './actions';
import { os } from './store';
import { Host } from './Tablet';

function openTablet(over: Parameters<typeof mockOpen>[0] = {}, dark = false) {
  const data = mockOpen(over);
  if (data.boot) data.boot = { ...data.boot, settings: { ...data.boot.settings, dark } };
  act(() => handleMessage('open', data));
}
async function typeCode(code: string) {
  for (const d of code) fireEvent.click(screen.getAllByRole('button', { name: d })[0]!);
}

beforeEach(() => { resetMock(); closeTablet(); });
afterEach(() => { cleanup(); closeTablet(); vi.restoreAllMocks(); delete (window as unknown as { GetParentResourceName?: unknown }).GetParentResourceName; });

describe('ui-02 architecture', () => {
  it('aucune importation interdite entre device/, system/, kit/, apps/', () => {
    expect(checkImports()).toEqual([]);
  });
});

describe('ui-04 i18n', () => {
  it('aucune chaîne visible en dur dans les composants', () => {
    expect(checkStrings()).toEqual([]);
    expect(findLiterals('<span>Bonjour le monde</span>').length).toBe(1);
    expect(findLiterals('<button aria-label="Fermer" />').length).toBe(1);
  });
  it('les 10 langues ont les mêmes clés que l’anglais (détail dans i18n/i18n.test.ts) ; une clé inconnue retombe sur la clé', () => {
    expect(Object.keys(fr).sort()).toEqual(Object.keys(en).sort());
    for (const l of LANGUAGES) expect(missingKeys(l)).toEqual([]);
    expect(makeT('es')('code.enter')).not.toBe('Enter passcode');
    expect(makeT('fr')('code.wait', 7)).toBe('Réessayez dans 7 s');
    expect(makeT('fr', { err_x: 'Texte du client' })('err_x')).toBe('Texte du client');
    expect(makeT('fr')('cle.inconnue')).toBe('cle.inconnue');
  });
  it('arabe : dir=rtl sur la tablette ouverte', () => {
    render(<Host />);
    openTablet({ lang: 'ar', rtl: true });
    expect(document.querySelector('.pop')?.getAttribute('dir')).toBe('rtl');
    expect(document.documentElement.dir).toBe('rtl');
  });
});

describe('ui-05 thème', () => {
  it('clair et sombre, accent du jeu, flou coupé', () => {
    render(<Host />);
    openTablet({ accent: '#ff2e88' }, true);
    const root = document.querySelector('.pop') as HTMLElement;
    expect(root.className).toContain('dk');
    expect(root.dataset.theme).toBe('dark');
    expect(root.style.getPropertyValue('--accent')).toBe('#ff2e88');
    const scr = document.querySelector('[data-screen]') as HTMLElement;
    expect(scr.style.getPropertyValue('--gad')).toBe('0.46');
    act(() => os.set({ settings: { dark: false, glass: 100, blur: false } }));
    expect(root.dataset.theme).toBe('light');
    expect(root.dataset.blur).toBe('off');
    expect(scr.style.getPropertyValue('--ga')).toBe('0.72');
  });
});

describe('ui-06 page et pont NUI', () => {
  it('aucune ressource externe dans la page ni dans les sources', async () => {
    const { readFileSync, readdirSync, statSync } = await import('node:fs');
    const { join } = await import('node:path');
    const root = join(__dirname, '../..');
    expect(readFileSync(join(root, 'index.html'), 'utf8')).not.toMatch(/https?:\/\//);
    const walk = (d: string): string[] => readdirSync(d).flatMap((n) => (statSync(join(d, n)).isDirectory() ? walk(join(d, n)) : [join(d, n)]));
    for (const f of walk(join(root, 'src')).filter((p) => /\.(ts|tsx|css)$/.test(p) && !/\.test\./.test(p))) {
      expect(readFileSync(f, 'utf8'), f).not.toMatch(/googleapis|gstatic|unpkg|jsdelivr|cdnjs|https?:\/\/(?!\$\{)/);
    }
  });
  it('pop:ready au démarrage, close sur Échap, messages du kit ignorés', async () => {
    (window as unknown as { GetParentResourceName: () => string }).GetParentResourceName = () => 'pop_tablet';
    const calls: string[] = [];
    vi.stubGlobal('fetch', vi.fn(async (url: string) => { calls.push(url); return { json: async () => ({ ok: true }) }; }));
    render(<Host />);
    await waitFor(() => expect(calls).toContain('https://pop_tablet/pop:ready'));
    for (const action of ['pop:prompt', 'pop:progress', 'pop:notify', 'pop:locale']) {
      window.dispatchEvent(new MessageEvent('message', { data: { action, data: { show: true } } }));
    }
    expect(os.get().open).toBe(false);
    openTablet();
    expect(os.get().open).toBe(true);
    fireEvent.keyDown(window, { key: 'Escape' });
    await waitFor(() => expect(calls).toContain('https://pop_tablet/close'));
    await waitFor(() => expect(os.get().open).toBe(false));
    vi.unstubAllGlobals();
  });
  it('en jeu la coque n’est pas affichée ; en développement elle l’est', () => {
    render(<Host />);
    openTablet({ shell: false });
    expect(document.querySelector('[data-shell]')).toBeNull();
    act(() => closeTablet());
    openTablet({ shell: true });
    expect(document.querySelector('[data-shell]')).toBeTruthy();
  });
});

describe('ui-07 boutons matériels et barre d’accueil', () => {
  it('bouton du haut : éteint et verrouille ; volume : jauge ; barre : demande le code', async () => {
    render(<Host />);
    openTablet();
    fireEvent.click(screen.getByRole('button', { name: 'Volume plus' }));
    expect(os.get().vol).toBe(63);
    expect(os.get().hud).toBe(true);
    fireEvent.click(screen.getByRole('button', { name: 'Volume moins' }));
    expect(os.get().vol).toBe(55);
    fireEvent.click(screen.getByRole('button', { name: "Barre d'accueil" }));
    expect(os.get().screen).toBe('code');
    fireEvent.click(screen.getByRole('button', { name: 'Bouton du haut (verrouiller)' }));
    // L'écran verrouillé n'apparaît qu'après la réponse du serveur à device:lock (asynchrone).
    await waitFor(() => expect(os.get().on).toBe(false));
    expect(os.get().screen).toBe('lock');
    expect(document.querySelector('[data-off="1"]')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Bouton du haut (verrouiller)' }));
    expect(os.get().on).toBe(true);
  });
});

describe('ui-08 écran verrouillé', () => {
  it('heure et date du jeu, widgets, notifications', () => {
    render(<Host />);
    openTablet();
    expect(screen.getAllByText('14:32').length).toBeGreaterThan(0);
    expect(screen.getByText('dimanche 22 novembre')).toBeTruthy();
    expect(screen.getByText('24° · Ensoleillé')).toBeTruthy();
    expect(screen.getByText('87 %', { selector: '[data-layer="lock"] span' })).toBeTruthy();
    act(() => handleMessage('notify', { app: 'messages', titleKey: undefined, text: 'On se retrouve ?' }));
    expect(within(document.querySelector('[data-layer="lock"]') as HTMLElement).getByText('On se retrouve ?')).toBeTruthy();
  });
  it('horloge de jeu : avance minute par minute, minuteur arrêté à la fermeture', () => {
    const snap = { h: 23, m: 59, d: 30, mo: 11, y: 2026, msPerMin: 2000 };
    expect(formatTime(gameDate(snap, 0, 0))).toBe('23:59');
    expect(formatTime(gameDate(snap, 0, 2000))).toBe('00:00');
    expect(formatDate(gameDate(snap, 0, 2000), 'fr', 'long')).toBe('mardi 1 décembre');
    expect(msToNextMinute(snap, 0, 500)).toBe(1500);
    render(<Host />);
    openTablet();
    expect(clockTimerActive()).toBe(true);
    act(() => closeTablet());
    expect(clockTimerActive()).toBe(false);
  });
});

describe('ui-09 code', () => {
  it('mauvais code : secousse, puis compteur de blocage après 5 échecs ; bon code : accueil', async () => {
    render(<Host />);
    openTablet();
    fireEvent.click(screen.getByRole('button', { name: "Barre d'accueil" }));
    await typeCode('0000');
    await waitFor(() => expect(document.querySelector('[data-testid="dots"]')?.className).toContain('shake'));
    expect(screen.getByRole('status').textContent).toBe('Code incorrect');
    for (let i = 0; i < 4; i++) {
      await waitFor(() => expect(document.querySelector('[data-testid="dots"]')?.className).not.toContain('shake'), { timeout: 2000 });
      await typeCode('0000');
      await waitFor(() => expect(os.get().codeError).not.toBeNull());
    }
    await waitFor(() => expect(os.get().lockWait).toBe(60));
    expect(screen.getByRole('status').textContent).toBe('Réessayez dans 60 s');
    expect((await submitCode('1234')).ok).toBe(false);
  });
  it('bon code', async () => {
    render(<Host />);
    openTablet();
    fireEvent.click(screen.getByRole('button', { name: "Barre d'accueil" }));
    await typeCode('1234');
    await waitFor(() => expect(os.get().screen).toBe('home'));
    expect(os.get().apps.length).toBeGreaterThan(10);
  });
});

describe('ui-10 premier allumage', () => {
  it('langue, code, confirmation, nom, adresse mail puis accueil', async () => {
    render(<Host />);
    openTablet({ needSetup: true, locked: true });
    expect(os.get().screen).toBe('setup');
    fireEvent.click(screen.getByRole('button', { name: 'English' }));
    await waitFor(() => expect(os.get().lang).toBe('en'));
    fireEvent.click(screen.getByRole('button', { name: 'Continue' }));
    await typeCode('2468');
    await waitFor(() => expect(screen.getByRole('status').textContent).toBe('Confirm your passcode'));
    await typeCode('2468');
    await waitFor(() => expect(screen.getByRole('status').textContent).toBe('Device name'));
    fireEvent.click(screen.getByRole('button', { name: 'Continue' }));
    fireEvent.change(screen.getByLabelText('Email address'), { target: { value: 'alex@exemple.fr' } });
    fireEvent.click(screen.getByRole('button', { name: 'Finish' }));
    await waitFor(() => expect(os.get().screen).toBe('home'));
    expect(os.get().needSetup).toBe(false);
  });
  it('adresse mail : domaine fixe, partie avant @ gardée, erreur avant envoi', async () => {
    render(<Host />);
    openTablet({ needSetup: true, mailDomain: 'exemple.test' });
    fireEvent.click(screen.getByRole('button', { name: 'English' }));
    await waitFor(() => expect(os.get().lang).toBe('en'));
    fireEvent.click(screen.getByRole('button', { name: 'Continue' }));
    await typeCode('2468');
    await waitFor(() => expect(screen.getByRole('status').textContent).toBe('Confirm your passcode'));
    await typeCode('2468');
    await waitFor(() => expect(screen.getByRole('status').textContent).toBe('Device name'));
    fireEvent.click(screen.getByRole('button', { name: 'Continue' }));
    expect(screen.getByTestId('mail-domain').textContent).toBe('@exemple.test');
    const input = screen.getByLabelText('Email address') as HTMLInputElement;
    fireEvent.change(input, { target: { value: 'Silvun@silvun.com' } });
    expect(input.value).toBe('Silvun');
    fireEvent.change(input, { target: { value: 'ab' } });
    fireEvent.click(screen.getByRole('button', { name: 'Finish' }));
    await waitFor(() => expect(screen.getByRole('alert').textContent).toContain('name@exemple.test'));
    expect(os.get().needSetup).toBe(true);
  });
  it('codes différents : message et retour à la saisie', async () => {
    render(<Host />);
    openTablet({ needSetup: true });
    fireEvent.click(screen.getByRole('button', { name: 'Continuer' }));
    await typeCode('1111');
    await waitFor(() => expect(screen.getByRole('status').textContent).toBe('Confirmez votre code'));
    await typeCode('2222');
    await waitFor(() => expect(screen.getByRole('alert').textContent).toBe('Les codes ne correspondent pas'));
  });
});

async function unlock() {
  render(<Host />);
  openTablet();
  await act(async () => { await submitCode('1234'); });
}

describe('ui-11 accueil', () => {
  it('grille, dock, widgets réels', async () => {
    await unlock();
    expect(screen.getAllByRole('button', { name: 'Messages' }).length).toBeGreaterThan(0);
    expect(screen.getAllByText('Patrouille centre').length).toBeGreaterThan(0);
    expect(screen.getByText('Récupérer le dossier Leroy')).toBeTruthy();
    expect(screen.getByText('H:27° B:18°')).toBeTruthy();
    expect(screen.getAllByText('3').length).toBeGreaterThan(0); // rappels restants
    expect(document.querySelectorAll('[data-layer="home"] [role="tab"]').length).toBe(0);
  });
  it('grille paginée au-delà de 16 applis', async () => {
    for (let i = 0; i < 20; i++) registerApiApp({ id: `api${i}`, nameKey: `api${i}`, domain: 'api', load: async () => ({ default: () => null }) });
    await unlock();
    act(() => os.set({ apps: [...os.get().apps, ...Array.from({ length: 20 }, (_, i) => `api${i}`)] }));
    expect(document.querySelectorAll('[data-layer="home"] [role="tab"]').length).toBe(3);
  });
  it('mode édition : bouton OK, suppression, applis système protégées', async () => {
    await unlock();
    const photos = screen.getAllByText('Photos')[0]!.closest('button')!;
    fireEvent.contextMenu(photos);
    expect(os.get().edit).toBe(true);
    expect(screen.queryByRole('button', { name: 'Supprimer Réglages' })).toBeNull();
    fireEvent.click(screen.getByRole('button', { name: 'Supprimer Photos' }));
    expect(os.get().apps).not.toContain('photos');
    fireEvent.click(screen.getByRole('button', { name: 'OK' }));
    expect(os.get().edit).toBe(false);
  });
});

describe('ui-12 barre d’état', () => {
  it('heure du jeu, batterie, application au premier plan, réseau', async () => {
    await unlock();
    const bar = () => document.querySelector('[data-screen] > div[style*="height: 34px"]') as HTMLElement;
    expect(bar().textContent).toContain('14:32');
    expect(bar().textContent).toContain('dim. 22 nov.');
    expect(bar().textContent).toContain('87 %');
    act(() => openApp('notes'));
    expect(bar().textContent).toContain('Notes');
    act(() => os.set({ battery: 15 }));
    expect(bar().textContent).toContain('15 %');
    act(() => os.set({ settings: { ...os.get().settings, air: true } }));
    expect(within(bar()).getByRole('img', { name: 'Mode avion' })).toBeTruthy();
  });
});

describe('ui-13 notifications', () => {
  it('bannière puis centre, groupées par appli, effaçables', async () => {
    await unlock();
    act(() => pushNotify({ app: 'messages', text: 'Salut', titleKey: undefined }));
    act(() => pushNotify({ app: 'messages', text: 'Tu es là ?' }));
    expect(os.get().banner?.body).toBe('Tu es là ?');
    expect(screen.getAllByText('Tu es là ?').length).toBeGreaterThan(0);
    fireEvent.click(screen.getByRole('button', { name: 'Centre de notifications' }));
    await waitFor(() => expect(screen.getByText('1 notification de plus')).toBeTruthy());
    fireEvent.click(screen.getByText('1 notification de plus'));
    await waitFor(() => expect(within(document.querySelector('[data-blur-layer]') as HTMLElement).getByText('Salut')).toBeTruthy());
    fireEvent.click(screen.getByRole('button', { name: 'Tout effacer' }));
    await waitFor(() => expect(screen.getByText('Aucune ancienne notification')).toBeTruthy());
  });
  it('concentration : pas de bannière', async () => {
    await unlock();
    act(() => os.set({ settings: { ...os.get().settings, focus: true } }));
    act(() => pushNotify({ app: 'mail', text: 'x' }));
    expect(os.get().banner).toBeNull();
    expect(os.get().notifs.length).toBe(1);
  });
});

describe('ui-14 centre de contrôle', () => {
  it('chaque bascule agit sur un réglage réel', async () => {
    await unlock();
    fireEvent.click(screen.getByRole('button', { name: 'Centre de contrôle' }));
    const air = await screen.findByRole('button', { name: 'Mode avion' });
    fireEvent.click(air);
    expect(os.get().settings.air).toBe(true);
    expect(screen.getByRole('button', { name: 'Wi-Fi' }).getAttribute('aria-pressed')).toBe('false');
    fireEvent.click(screen.getByRole('button', { name: 'Mode sombre' }));
    expect(os.get().settings.dark).toBe(true);
    fireEvent.click(screen.getByRole('button', { name: 'Concentration' }));
    expect(os.get().settings.focus).toBe(true);
    fireEvent.click(screen.getByRole('button', { name: 'Verrouillage de la rotation' }));
    expect(os.get().settings.rot).toBe(true);
    expect(screen.getByText('Rien en lecture')).toBeTruthy();
    fireEvent.keyDown(screen.getByRole('slider', { name: 'Volume' }), { key: 'ArrowUp' });
    expect(os.get().vol).toBe(60);
    fireEvent.click(within(document.querySelector('[data-blur-layer]') as HTMLElement).getByRole('button', { name: 'Calculette' }));
    expect(os.get().app).toBe('calculette');
    expect(os.get().cc).toBe(false);
  });
  it('Mode avion coupe les applis en ligne', async () => {
    await unlock();
    act(() => os.set({ settings: { ...os.get().settings, air: true } }));
    act(() => openApp('messages'));
    await waitFor(() => expect(document.querySelector('[data-offline="messages"]')).toBeTruthy());
    act(() => openApp('navigateur'));
    await waitFor(() => expect(document.querySelector('[data-offline="navigateur"]')).toBeTruthy());
  });
});

describe('ui-15 recherche et sélecteur', () => {
  it('recherche d’applis, contacts, notes', async () => {
    await unlock();
    fireEvent.click(screen.getByRole('button', { name: 'Rechercher' }));
    const input = await screen.findByLabelText('Rechercher ou demander');
    fireEvent.change(input, { target: { value: 'sam' } });
    await waitFor(() => expect(screen.getByText('Sam Leroy')).toBeTruthy(), { timeout: 3000 });
    fireEvent.change(input, { target: { value: 'cour' } });
    await waitFor(() => expect(screen.getByText('Courses')).toBeTruthy(), { timeout: 3000 });
    fireEvent.change(input, { target: { value: 'calc' } });
    await waitFor(() => expect(screen.getAllByText('Calculette').length).toBeGreaterThan(0));
  });
  it('sélecteur : applis récentes, vide sinon', async () => {
    await unlock();
    fireEvent.doubleClick(screen.getByRole('button', { name: "Barre d'accueil" }));
    await waitFor(() => expect(screen.getByText('Aucune appli ouverte')).toBeTruthy());
    act(() => os.set({ sw: false }));
    act(() => openApp('photos'));
    act(() => os.set({ sw: true }));
    await waitFor(() => expect(screen.getByText('Glisser vers le haut pour fermer')).toBeTruthy());
  });
});

describe('ui-16 transitions', () => {
  it('ouverture et fermeture d’une appli, rien ne reste actif tablette fermée', async () => {
    await unlock();
    act(() => openApp('photos', { x: 100, y: 100 }));
    await waitFor(() => expect(document.querySelector('[data-layer="app"]')).toBeTruthy());
    act(() => closeApp());
    await waitFor(() => expect(document.querySelector('[data-layer="app"]')).toBeNull(), { timeout: 3000 });
    act(() => handleMessage('close', {}));
    expect(os.get().open).toBe(false);
    expect(clockTimerActive()).toBe(false);
    expect(document.querySelector('.pop')).toBeNull();
  });
  it('les animations du verre et des couches ne touchent que transform et opacity', async () => {
    const { readFileSync } = await import('node:fs');
    const { join } = await import('node:path');
    const css = readFileSync(join(__dirname, '../kit/tokens.css'), 'utf8');
    const tr = css.match(/\.tr\{transition:([^}]*)\}/)![1]!;
    expect(tr).toMatch(/transform/);
    expect(tr).toMatch(/opacity/);
    expect(tr).not.toMatch(/filter|width|height|top|left/);
    expect(css).toMatch(/prefers-reduced-motion: reduce/);
  });
});
