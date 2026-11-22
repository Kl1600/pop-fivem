import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { AppIcon, AppWaiting, BlurLayer, Button, Field, Glass, ICON_IDS, KitProvider, ListRow, NavStack, Sheet, Slider, SplitView, Switch, TabBar, VirtualList, WALLPAPERS, appBackground, glassVars, palette, safeAccent, wallpaper, type Layout } from './index';

const LAYOUTS: Layout[] = ['regular', 'compact'];

// ui-03 : chaque composant du kit se rend sans erreur en regular et en compact.
describe.each(LAYOUTS)('kit (%s)', (layout) => {
  const wrap = (ui: React.ReactNode) => render(<KitProvider layout={layout} dark={false}>{ui}</KitProvider>);
  it('Glass, BlurLayer, Button, Switch, Slider, ListRow, Field, Sheet', () => {
    wrap(
      <div>
        <Glass kind="g">verre</Glass>
        <BlurLayer>couche</BlurLayer>
        <Button onClick={() => {}}>ok</Button>
        <Switch on label="sw" onChange={() => {}} />
        <Slider value={40} label="sl" onChange={() => {}} />
        <ListRow title="ligne" value="v" />
        <Field value="a" label="champ" onChange={() => {}} />
        <Sheet open onClose={() => {}} title="feuille">contenu</Sheet>
      </div>,
    );
    expect(screen.getByText('verre')).toBeTruthy();
    expect(screen.getByRole('slider').getAttribute('aria-valuenow')).toBe('40');
    expect(screen.getByRole('dialog')).toBeTruthy();
  });
  it('SplitView, NavStack, TabBar, AppWaiting', () => {
    wrap(
      <div>
        <SplitView sidebar={<span>liste</span>} detail={<span>detail</span>} showDetail={false} />
        <NavStack pages={[{ key: 'a', title: 'A', content: <span>pa</span> }, { key: 'b', title: 'B', content: <span>pb</span> }]} onBack={() => {}} />
        <TabBar tabs={[{ id: 'x', label: 'X' }, { id: 'y', label: 'Y' }]} value="x" onChange={() => {}} />
        <AppWaiting id="notes" dark={false} t={(k) => k} close={() => {}} />
      </div>,
    );
    expect(document.querySelector(`[data-split="${layout}"]`)).toBeTruthy();
    expect(document.querySelector(`[data-tabbar="${layout}"]`)).toBeTruthy();
    expect(document.querySelector(`[data-nav="${layout}"]`)).toBeTruthy();
  });
  it('SplitView compact montre un seul volet', () => {
    wrap(<SplitView sidebar={<span>liste</span>} detail={<span>detail</span>} showDetail />);
    expect(screen.queryByText('detail')).toBeTruthy();
    if (layout === 'compact') expect(screen.queryByText('liste')).toBeNull();
    else expect(screen.queryByText('liste')).toBeTruthy();
  });
});

describe('AppIcon', () => {
  it('rend chaque icône en clair et en sombre', () => {
    for (const id of ICON_IDS) {
      const { container, unmount } = render(<><AppIcon appId={id} size={88} /><AppIcon appId={id} size={88} dark /></>);
      expect(container.querySelectorAll('svg').length).toBe(2);
      unmount();
    }
    expect(ICON_IDS.length).toBeGreaterThanOrEqual(25);
  });
});

// ui-05 : thème, verre, accent.
describe('thème', () => {
  it('curseur de verre : bornes et valeurs de la maquette', () => {
    expect(glassVars(50)).toEqual({ ga: '0.42', gad: '0.46' });
    expect(glassVars(0)).toEqual({ ga: '0.12', gad: '0.18' });
    expect(glassVars(100)).toEqual({ ga: '0.72', gad: '0.73' });
    expect(glassVars(500)).toEqual(glassVars(100));
  });
  it('palette et fond selon clair/sombre', () => {
    expect(palette(true).bg).toBe('#000000');
    expect(palette(false).bg).toBe('#f2f2f7');
    expect(appBackground(true)).toBe('#000000');
    expect(wallpaper('auto', true)).not.toBe(wallpaper('auto', false));
    expect(wallpaper('3', false)).toBe(WALLPAPERS[3]);
    expect(wallpaper('999', false)).toBe(wallpaper('auto', false));
  });
  it("l'accent n'accepte que #hex", () => {
    expect(safeAccent('#ff2e88')).toBe('#ff2e88');
    expect(safeAccent('red; background:url(x)')).toBeNull();
    expect(safeAccent(undefined)).toBeNull();
  });
  it('un seul backdrop-filter par couche : le verre est à plat dans BlurLayer', () => {
    const { container } = render(<><Glass kind="gw">dehors</Glass><BlurLayer><Glass kind="gw">dedans</Glass></BlurLayer></>);
    const out = screen.getByText('dehors');
    const inn = screen.getByText('dedans');
    expect(out.className).not.toContain('flat');
    expect(inn.className).toContain('flat');
    expect(container.querySelectorAll('[data-blur-layer] .gw:not(.flat)').length).toBe(0);
  });
});

// ui-17 : listes virtualisées.
describe('VirtualList', () => {
  it('1000 éléments : au plus 60 nœuds de ligne dans le DOM', () => {
    const items = Array.from({ length: 1000 }, (_, i) => i);
    const { container } = render(<VirtualList items={items} rowHeight={48} height={600} getKey={(n) => n} render={(n) => <span>ligne {n}</span>} />);
    const rows = container.querySelectorAll('[role="list"] > div > div');
    expect(rows.length).toBeGreaterThan(0);
    expect(rows.length).toBeLessThanOrEqual(60);
    expect(container.querySelectorAll('*').length).toBeLessThanOrEqual(200);
  });
});
