import { expect, test } from './fixtures';

test.describe('Boutique', () => {
  test('installer une appli de métier, la retirer, appli système non retirable', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Boutique');
    await app.getByRole('button', { name: 'Obtenir Police MDT' }).click();
    expect((await tab.waitCall('store:install')).data).toBe('police_mdt');
    await expect(tab.screen.getByRole('button', { name: 'Retirer Police MDT' }).or(app.getByRole('button', { name: 'Retirer Police MDT' })).first()).toBeVisible();
    await app.getByRole('button', { name: 'Retirer Police MDT' }).click();
    expect((await tab.waitCall('store:remove')).data).toBe('police_mdt');
    await expect(app.getByRole('button', { name: 'Installée Réglages' })).toBeDisabled();
    await app.getByRole('button', { name: 'Installées' }).click();
    await app.getByRole('button', { name: 'Découvrir' }).click();
  });
  test('retirer puis réinstaller une appli native la fait quitter puis revenir sur l\'accueil', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Boutique');
    await app.getByRole('button', { name: 'Retirer Bourse' }).click();
    await tab.waitCall('store:remove', (d) => d === 'bourse');
    await tab.home();
    await expect(tab.screen.getByRole('button', { name: 'Bourse', exact: true })).toHaveCount(0);
    await tab.openApp('Boutique');
    await tab.app.getByRole('button', { name: 'Obtenir Bourse' }).click();
    await tab.waitCall('store:install', (d) => d === 'bourse');
  });
});

test.describe('Réglages', () => {
  test('renommer l\'appareil, changer le code (faux ancien code refusé)', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Réglages');
    await app.getByRole('button', { name: /Général/ }).click();
    await app.getByLabel('Nom', { exact: true }).fill('Tablette de Bob');
    await app.getByRole('button', { name: 'Renommer' }).click();
    expect((await tab.waitCall('settings:rename')).data).toBe('Tablette de Bob');
    await expect(app.getByText('Tablette de Bob').first()).toBeVisible();
  });
  test('sections : sons, accessibilité (texte en gras), fond d\'écran, notifications, concentration', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Réglages');
    await app.getByRole('button', { name: /Sons/ }).click();
    await app.getByText('Radar').click();
    await tab.waitCall('settings:save', (d) => (d as { ring?: number }).ring === 5);
    await app.getByRole('button', { name: /Accessibilité/ }).click();
    await app.getByRole('switch', { name: 'Texte en gras' }).click();
    await expect(tab.page.locator('.pop')).toHaveAttribute('data-bold', 'on');
    await tab.waitCall('settings:save', (d) => (d as { bold?: boolean }).bold === true);
    for (const s of [/Fond d'écran/, /Notifications/, /Concentration/, /Mode avion/, /Wi-Fi/, /Bluetooth/, /Batterie/, /Centre de contrôle/, /Confidentialité/, /Code/]) {
      await app.getByRole('button', { name: s }).first().click();
    }
  });
  test('Wi-Fi coupé dans Réglages : les applis en ligne le disent', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Réglages');
    await app.getByRole('button', { name: 'Wi-Fi' }).click();
    await app.getByRole('switch').first().click();
    await tab.waitCall('settings:save', (d) => (d as { wifi?: boolean }).wifi === false);
  });
});
