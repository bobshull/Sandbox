const CACHE_NAME = 'retro-arcade-v2';

const ASSETS = [
  './',
  './index.html',
  './css/reset.css',
  './css/fonts.css',
  './css/theme.css',
  './css/crt.css',
  './css/layout.css',
  './js/main.js',
  './js/version.js',
  './js/platform/viewport.js',
  './js/platform/input.js',
  './js/platform/storage.js',
  './js/platform/audio.js',
  './js/platform/audio-sounds.js',
  './js/platform/music.js',
  './js/engine/loop.js',
  './js/engine/collision.js',
  './js/engine/pool.js',
  './js/engine/particles.js',
  './js/engine/state-machine.js',
  './js/render/renderer.js',
  './js/render/sprites.js',
  './js/render/sprite-draw.js',
  './js/render/text.js',
  './js/render/effects.js',
  './js/render/crt.js',
  './js/render/transitions.js',
  './js/shell/app.js',
  './js/shell/boot.js',
  './js/shell/menu.js',
  './js/shell/highscores.js',
  './js/shell/settings.js',
  './js/games/game-interface.js',
  './js/games/manifest.js',
  './js/games/snake/index.js',
  './js/games/snake/snake-config.js',
  './js/games/snake/snake-entities.js',
  './js/games/snake/snake-game.js',
  './js/games/snake/snake-logic.js',
  './js/games/snake/snake-renderer.js',
  './js/games/breakout/index.js',
  './js/games/breakout/breakout-config.js',
  './js/games/breakout/breakout-bricks.js',
  './js/games/breakout/breakout-entities.js',
  './js/games/breakout/breakout-collisions.js',
  './js/games/breakout/breakout-game.js',
  './js/games/breakout/breakout-renderer.js',
  './js/games/invaders/index.js',
  './js/games/invaders/invaders-config.js',
  './js/games/invaders/invaders-entities.js',
  './js/games/invaders/invaders-shields.js',
  './js/games/invaders/invaders-collisions.js',
  './js/games/invaders/invaders-game.js',
  './js/games/invaders/invaders-renderer.js',
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(ASSETS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  e.respondWith(
    caches.match(e.request).then((cached) => cached || fetch(e.request))
  );
});
