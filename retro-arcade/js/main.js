import { VERSION } from './version.js';

import { app, AppScreen } from './shell/app.js';
import { menuScreen } from './shell/menu.js';
import { highScoresScreen } from './shell/highscores.js';
import { settingsScreen } from './shell/settings.js';
import { bootScreen } from './shell/boot.js';
import { gameManifest } from './games/manifest.js';

// Side-effect imports: register all games
import './games/snake/index.js';
import './games/breakout/index.js';
import './games/invaders/index.js';

document.addEventListener('DOMContentLoaded', () => {
  app.registerScreen(AppScreen.BOOT, bootScreen);
  app.registerScreen(AppScreen.MENU, menuScreen);
  app.registerScreen(AppScreen.HIGHSCORES, highScoresScreen);
  app.registerScreen(AppScreen.SETTINGS, settingsScreen);

  app.init();

  const ids = gameManifest.getGameIds();
  console.log(
    '%c' +
    '  ____  _____ _____ ____   ___     _    ____   ____    _    ____  _____  \n' +
    ' |  _ \\| ____|_   _|  _ \\ / _ \\   / \\  |  _ \\ / ___|  / \\  |  _ \\| ____| \n' +
    ' | |_) |  _|   | | | |_) | | | | / _ \\ | |_) | |     / _ \\ | | | |  _|   \n' +
    ' |  _ <| |___  | | |  _ <| |_| |/ ___ \\|  _ <| |___ / ___ \\| |_| | |___  \n' +
    ' |_| \\_|_____| |_| |_| \\_\\\\___//_/   \\_|_| \\_\\\\____/_/   \\_|____/|_____| \n' +
    `                                                            ${VERSION}  `,
    'color:#32e8ff;font-family:monospace'
  );
  console.log(`[Manifest] ${ids.length} games registered: ${ids.join(', ')}`);
  if (ids.length < 3) console.warn('[Manifest] Expected 3 games, got', ids.length);
});

document.fonts.ready.then(() => {
  document.documentElement.classList.add('fonts-loaded');
});

window.addEventListener('error', (e) => {
  console.error('[RetroArcade] Error:', e.message, e.filename, e.lineno);
});

window.addEventListener('unhandledrejection', (e) => {
  console.error('[RetroArcade] Unhandled rejection:', e.reason);
});

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('./sw.js').catch((e) => {
    console.warn('[SW] Registration failed:', e.message);
  });
}
