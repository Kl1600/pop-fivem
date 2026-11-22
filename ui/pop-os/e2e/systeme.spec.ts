import { expect, test } from './fixtures';

const HOME_BAR = /barre d.accueil/i;

test.describe('Premier allumage', () => {
  test('Bonjour, langue, apparence, code, nom, mail, fond, bienvenue', async ({ tab }) => {
    const { page } = tab;
    await tab.open({ setup: true });
    await expect(page.getByText('Bonjour')).toBeVisible();
    await page.getByRole('button', { name: /Glisser vers le haut/ }).click();
    await page.getByRole('button', { name: 'Français' }).click();
    await page.getByRole('button', { name: 'Continuer' }).click();
    await expect(page.getByRole('status').filter({ hasText: 'Apparence' })).toBeVisible();
    await page.getByRole('button', { name: 'Continuer' }).click();
    await expect(page.getByRole('status').filter({ hasText: 'Choisissez un code' })).toBeVisible();
    for (const d of '2468') await page.getByRole('button', { name: d, exact: true }).click();
    await expect(page.getByRole('status').filter({ hasText: 'Confirmez' })).toBeVisible();
    for (const d of '2468') await page.getByRole('button', { name: d, exact: true }).click();
    const name = page.getByLabel("Nom de l'appareil");
    await expect(name).toBeVisible();
    await name.fill('Tablette Test');
    await page.getByRole('button', { name: 'Continuer' }).click();

    // Adresse mail : suffixe fixe @domaine, validation avant l'envoi.
    await expect(page.getByTestId('mail-domain')).toHaveText('@pop.ls');
    const mail = page.getByLabel('Adresse mail');
    await mail.fill('ab');
    await page.getByRole('button', { name: 'Continuer' }).click();
    await expect(page.getByRole('alert')).toContainText('3 à 32 caractères');
    await mail.fill('a..b');
    await page.getByRole('button', { name: 'Continuer' }).click();
    await expect(page.getByRole('alert')).toBeVisible();
    await mail.fill('moi.test@autre.fr'); // tout ce qui suit « @ » est ignoré : le domaine est imposé
    await expect(mail).toHaveValue('moi.test');
    await page.getByRole('button', { name: 'Continuer' }).click();
    expect(await tab.calls('device:setup')).toHaveLength(0);
    await page.getByRole('button', { name: 'Fond d’écran 4' }).click();
    await page.getByRole('button', { name: 'Continuer' }).click();
    await expect(page.getByRole('status').filter({ hasText: 'Bienvenue sur POP Tab' })).toBeVisible();
    await page.getByRole('button', { name: 'Commencer' }).click();
    await expect(tab.screen.getByRole('button', { name: 'Réglages' })).toBeVisible();
    const call = await tab.waitCall('device:setup');
    expect(call.data).toMatchObject({ code: '2468', name: 'Tablette Test', lang: 'fr', mail: 'moi.test', dark: false, wall: '3' });
  });

  test('code de confirmation différent : message et retour à la saisie', async ({ tab }) => {
    const { page } = tab;
    await tab.open({ setup: true });
    await page.getByRole('button', { name: /Glisser vers le haut/ }).click();
    await page.getByRole('button', { name: 'Continuer' }).click();
    await page.getByRole('button', { name: 'Continuer' }).click();
    for (const d of '1111') await page.getByRole('button', { name: d, exact: true }).click();
    await expect(page.getByRole('status').filter({ hasText: 'Confirmez' })).toBeVisible();
    for (const d of '2222') await page.getByRole('button', { name: d, exact: true }).click();
    await expect(page.getByRole('alert')).toContainText('ne correspondent pas');
    await expect(page.getByRole('status').filter({ hasText: 'Choisissez un code' })).toBeVisible();
    expect(await tab.calls('device:setup')).toHaveLength(0);
  });

  test('choix de langue : envoyé au client et textes traduits', async ({ tab }) => {
    await tab.open({ setup: true });
    await tab.page.getByRole('button', { name: /Glisser vers le haut/ }).click();
    await tab.page.getByRole('button', { name: 'English' }).click();
    await tab.waitCall('tablet:locale');
    await expect(tab.page.getByRole('status').filter({ hasText: 'Choose your language' })).toBeVisible();
    await expect(tab.page.getByRole('button', { name: 'Continue' })).toBeVisible();
  });

  test('choix Sombre : écran sombre, accueil sombre, réglages conservés à la réouverture', async ({ tab }) => {
    const { page } = tab;
    await tab.open({ setup: true });
    await page.getByRole('button', { name: /Glisser vers le haut/ }).click();
    await page.getByRole('button', { name: 'English' }).click();
    await page.getByRole('button', { name: 'Continue' }).click();
    await expect(page.locator('.pop')).toHaveAttribute('data-theme', 'light');
    await page.getByRole('button', { name: 'Dark' }).click();
    await expect(page.locator('.pop')).toHaveAttribute('data-theme', 'dark');
    await page.getByRole('button', { name: 'Continue' }).click();
    for (const d of '2468') await page.getByRole('button', { name: d, exact: true }).click();
    await expect(page.getByRole('status').filter({ hasText: 'Confirm your passcode' })).toBeVisible();
    for (const d of '2468') await page.getByRole('button', { name: d, exact: true }).click();
    await page.getByLabel('Device name').fill('Nuit');
    await page.getByRole('button', { name: 'Continue' }).click();
    await page.getByLabel('Email address').fill('nuit.test');
    await page.getByRole('button', { name: 'Continue' }).click();
    await page.getByRole('button', { name: 'Continue' }).click();
    await page.getByRole('button', { name: 'Get started' }).click();
    await expect(tab.screen.getByRole('button', { name: 'Settings' })).toBeVisible();
    await expect(page.locator('.pop')).toHaveAttribute('data-theme', 'dark');
    expect((await tab.waitCall('device:setup')).data).toMatchObject({ lang: 'en', dark: true });

    // Réouverture : écran verrouillé sombre, code choisi, accueil sombre et en anglais.
    await page.keyboard.press('Escape');
    await page.getByRole('button', { name: 'POP Tab', exact: true }).click();
    await expect(page.locator('.pop')).toHaveAttribute('data-theme', 'dark');
    await page.getByRole('button', { name: /home bar/i }).click();
    for (const d of '2468') await page.getByRole('button', { name: d, exact: true }).click();
    await expect(tab.screen.getByRole('button', { name: 'Settings' })).toBeVisible();
    await expect(page.locator('.pop')).toHaveAttribute('data-theme', 'dark');
  });
});

test.describe('Écran verrouillé et code', () => {
  test('écran verrouillé : heure, météo, aucune appli accessible', async ({ tab }) => {
    await tab.open({ unlock: false });
    await expect(tab.screen).toContainText('14:32');
    await expect(tab.screen).toContainText('Ensoleillé');
    await expect(tab.screen).toContainText('Glisser vers le haut');
    await expect(tab.screen.getByRole('button', { name: 'Calculette' })).toHaveCount(0);
  });

  test('un faux code est refusé, le bon déverrouille (vérifié par le serveur)', async ({ tab }) => {
    const { page } = tab;
    await tab.open({ unlock: false });
    await page.getByRole('button', { name: HOME_BAR }).click();
    for (const d of '0000') await page.getByRole('button', { name: d, exact: true }).click();
    await expect(page.getByRole('status').filter({ hasText: 'Code incorrect' })).toBeVisible();
    expect((await tab.calls('device:unlock')).map((c) => c.data)).toEqual(['0000']);
    await expect(tab.screen.getByRole('button', { name: 'Calculette' })).toHaveCount(0); // toujours verrouillée
    await expect(page.getByTestId('dots').locator('[data-filled="1"]')).toHaveCount(0); // saisie effacée après la secousse
    for (const d of '1234') await page.getByRole('button', { name: d, exact: true }).click();
    await expect(tab.screen.getByRole('button', { name: 'Calculette' })).toBeVisible();
    expect((await tab.calls('device:unlock')).map((c) => c.data)).toEqual(['0000', '1234']);
  });

  test('cinq codes faux de suite : blocage avec compte à rebours', async ({ tab }) => {
    const { page } = tab;
    await tab.open({ unlock: false });
    await page.getByRole('button', { name: HOME_BAR }).click();
    for (let i = 0; i < 5; i++) {
      for (const d of '9999') await page.getByRole('button', { name: d, exact: true }).click();
      await expect.poll(async () => (await tab.calls('device:unlock')).length).toBe(i + 1);
      await expect(page.getByTestId('dots').locator('[data-filled="1"]')).toHaveCount(0);
    }
    await expect(page.getByRole('status').filter({ hasText: /Réessayez dans \d+ s/ })).toBeVisible();
    for (const d of '1234') await page.getByRole('button', { name: d, exact: true }).click();
    expect(await tab.calls('device:unlock')).toHaveLength(5); // pendant le blocage, le bon code n'est même pas envoyé
  });

  test('Annuler ramène à l\'écran verrouillé ; le clavier physique saisit aussi le code', async ({ tab }) => {
    const { page } = tab;
    await tab.open({ unlock: false });
    await page.getByRole('button', { name: HOME_BAR }).click();
    await page.getByRole('button', { name: 'Annuler' }).click();
    await expect(tab.screen).toContainText('Glisser vers le haut');
    await page.getByRole('button', { name: HOME_BAR }).click();
    await page.keyboard.type('1234');
    await expect(tab.screen.getByRole('button', { name: 'Calculette' })).toBeVisible();
  });

  test('bouton du haut : le serveur verrouille (device:lock), au rallumage le code est redemandé', async ({ tab }) => {
    const { page } = tab;
    await tab.open();
    await page.getByRole('button', { name: 'Bouton du haut (verrouiller)' }).click();
    await tab.waitCall('device:lock');
    await page.getByRole('button', { name: 'Bouton du haut (verrouiller)' }).click(); // rallume
    await expect(tab.screen).toContainText('Glisser vers le haut');
    await expect(tab.screen.getByRole('button', { name: 'Calculette' })).toHaveCount(0);
  });
});

test.describe('Accueil', () => {
  test('toutes les applis, le dock, les widgets et la recherche', async ({ tab }) => {
    await tab.open();
    for (const n of ['Calendrier', 'Photos', 'Appareil photo', 'Horloge', 'Météo', 'Plans', 'Rappels', 'Notes', 'Fichiers', 'Tableau', 'Calculette', 'Dictaphone', 'Traduire', 'Bourse', 'Contacts', 'Boutique', 'Messages', 'Téléphone', 'Mail', 'Navigateur', 'Musique', 'Réglages']) {
      await expect(tab.screen.getByRole('button', { name: n, exact: true }).first(), n).toBeVisible();
    }
    await expect(tab.screen).toContainText('Patrouille centre');
    await expect(tab.screen).toContainText('Récupérer le dossier Leroy');
    await expect(tab.screen.getByRole('button', { name: 'Messages' })).toContainText('2'); // pastille
  });

  test('une appli ouverte se ferme avec la barre d\'accueil et revient à l\'accueil', async ({ tab }) => {
    await tab.open();
    await tab.openApp('Calculette');
    await tab.home();
    await expect(tab.screen.getByRole('button', { name: 'Calculette', exact: true }).first()).toBeVisible();
  });
});

test.describe('Centres et multitâche', () => {
  test('centre de contrôle : mode sombre, Wi-Fi, mode avion, luminosité, concentration', async ({ tab }) => {
    const { page } = tab;
    await tab.open();
    await page.getByRole('button', { name: 'Centre de contrôle' }).click();
    await expect(page.getByRole('button', { name: 'Wi-Fi' })).toHaveAttribute('aria-pressed', 'true');
    await page.getByRole('button', { name: 'Mode sombre' }).click();
    expect((await tab.waitCall('settings:save', (d) => (d as { dark?: boolean }).dark === true)).data).toMatchObject({ dark: true });
    await expect(tab.screen).toHaveClass(/dk/);
    await page.getByRole('button', { name: 'Mode sombre' }).click();
    await tab.waitCall('settings:save', (d) => (d as { dark?: boolean }).dark === false);
    await expect(tab.screen).not.toHaveClass(/dk/);
    await page.getByRole('button', { name: 'Wi-Fi' }).click();
    await tab.waitCall('settings:save', (d) => (d as { wifi?: boolean }).wifi === false);
    await expect(page.getByRole('button', { name: 'Wi-Fi' })).toHaveAttribute('aria-pressed', 'false');
    await page.getByRole('button', { name: 'Mode avion' }).click();
    await tab.waitCall('settings:save', (d) => (d as { air?: boolean }).air === true);
    await page.getByRole('button', { name: 'Concentration' }).click();
    await tab.waitCall('settings:save', (d) => (d as { focus?: boolean }).focus === true);
    const lum = page.getByRole('slider', { name: 'Luminosité' });
    const box = (await lum.boundingBox())!;
    await page.mouse.click(box.x + box.width / 2, box.y + box.height * 0.7); // curseur vertical : plus bas = plus sombre
    await tab.waitCall('settings:save', (d) => typeof (d as { bright?: number }).bright === 'number');
    await page.getByRole('button', { name: HOME_BAR }).click(); // ferme le centre
    await expect(page.getByRole('button', { name: 'Mode sombre' })).toHaveCount(0);
  });

  test('sans réseau, les applis en ligne affichent « hors ligne »', async ({ tab }) => {
    const { page } = tab;
    await tab.open();
    await page.getByRole('button', { name: 'Centre de contrôle' }).click();
    await page.getByRole('button', { name: 'Mode avion' }).click();
    await page.getByRole('button', { name: HOME_BAR }).click();
    await tab.openApp('Messages');
    await expect(tab.app.locator('[data-offline="messages"]')).toBeVisible();
  });

  test('centre de notifications : bannière, liste, tout effacer', async ({ tab }) => {
    const { page } = tab;
    await tab.open();
    await tab.send('notify', { app: 'mail', title: 'Lina', text: 'Bonjour test' });
    await expect(page.getByRole('button').filter({ hasText: 'Bonjour test' })).toBeVisible(); // bannière
    await page.getByRole('button', { name: 'Centre de notifications' }).click();
    await expect(page.getByText('Bonjour test').first()).toBeVisible();
    await page.getByRole('button', { name: 'Tout effacer' }).click();
    await expect(page.getByText('Aucune ancienne notification')).toBeVisible();
  });

  test('recherche : trouver et ouvrir une appli', async ({ tab }) => {
    const { page } = tab;
    await tab.open();
    await page.getByRole('button', { name: 'Rechercher', exact: true }).first().click();
    await page.getByRole('textbox', { name: 'Rechercher ou demander' }).fill('Calcu');
    await page.getByRole('button', { name: 'Calculette' }).first().click();
    await expect(tab.app).toBeVisible();
    await expect(tab.app.getByRole('button', { name: '7', exact: true })).toBeVisible();
  });

  test('multitâche : deux applis ouvertes, le sélecteur les liste, l\'une se rouvre', async ({ tab }) => {
    const { page } = tab;
    await tab.open();
    await tab.openApp('Calculette');
    await tab.home();
    await tab.openApp('Horloge');
    await tab.home();
    await page.getByRole('button', { name: HOME_BAR }).dblclick();
    await expect(tab.screen.getByText('Calculette', { exact: true }).first()).toBeVisible();
    await expect(tab.screen.getByText('Horloge', { exact: true }).first()).toBeVisible();
    const cards = tab.screen.locator('button[style*="width: 360px"]');
    await expect(cards).toHaveCount(2);
    await cards.first().click(); // la plus récente : Horloge
    await expect(tab.app).toBeVisible();
    await expect(tab.app.getByRole('button', { name: 'Alarmes' })).toBeVisible();
  });
});

test.describe('Apparence', () => {
  test('mode clair puis sombre depuis Réglages, coque et barre d\'état restent affichées', async ({ tab }) => {
    const { page } = tab;
    await tab.open();
    await tab.openApp('Réglages');
    await tab.app.getByRole('button', { name: 'Luminosité et affichage' }).click();
    await expect(tab.app.getByRole('radio', { name: 'Clair' })).toBeChecked();
    await tab.app.getByRole('radio', { name: 'Sombre' }).click();
    await tab.waitCall('settings:save', (d) => (d as { dark?: boolean }).dark === true);
    await expect(tab.screen).toHaveClass(/dk/);
    await tab.app.getByRole('radio', { name: 'Clair' }).click();
    await tab.waitCall('settings:save', (d) => (d as { dark?: boolean }).dark === false);
    await expect(tab.screen).not.toHaveClass(/dk/);
    await expect(page.locator('[data-shell="1"]')).toBeVisible();
    await expect(tab.screen).toContainText('14:32');
  });

  test('ouverture en mode sombre (?dark=1) : coque visible', async ({ tab }) => {
    await tab.open({ dark: true });
    await expect(tab.screen).toHaveClass(/dk/);
    await expect(tab.page.locator('[data-shell="1"]')).toBeVisible();
    await expect(tab.page.locator('[data-shell="1"]')).not.toHaveAttribute('data-clear', '1');
  });
});
