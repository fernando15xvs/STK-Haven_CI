const CACHE_PREFIX = 'stk-haven-';
const CACHE_NAME = `${CACHE_PREFIX}shell-v9`;
const BIBLE_CACHE_NAME = `${CACHE_PREFIX}bible-rv1909-v2026-09-18`;
const ACTIVE_CACHES = new Set([CACHE_NAME, BIBLE_CACHE_NAME]);
const LEGACY_FLUTTER_CACHES = [
  'flutter-app-cache',
  'flutter-temp-cache',
  'flutter-app-manifest',
];

const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  './flutter.js',
  './flutter_bootstrap.js',
  './favicon-stk-haven.png',
  './icons/stk-haven-180.png',
  './icons/stk-haven-192.png',
  './icons/stk-haven-512.png',
  './icons/stk-haven-maskable-192.png',
  './icons/stk-haven-maskable-512.png',
  './splash/slf_logo.png',
];

const NETWORK_FIRST_FILES = new Set([
  'index.html',
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
  'main.dart.mjs',
  'main.dart.wasm',
  'manifest.json',
  'assets/AssetManifest.bin',
  'assets/AssetManifest.bin.json',
  'assets/FontManifest.json',
  'version.json',
]);

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await Promise.allSettled(
      APP_SHELL.map((url) => cache.add(new Request(url, { cache: 'reload' }))),
    );
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(
      keys
        .filter((key) =>
          (key.startsWith(CACHE_PREFIX) && !ACTIVE_CACHES.has(key)) ||
          LEGACY_FLUTTER_CACHES.includes(key),
        )
        .map((key) => caches.delete(key)),
    );
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  if (isPinnedBibleRequest(url)) {
    event.respondWith(bibleCacheFirst(request));
    return;
  }

  if (url.origin !== self.location.origin) return;

  const scopeUrl = new URL(self.registration.scope);
  const relativePath = url.pathname.startsWith(scopeUrl.pathname)
    ? url.pathname.slice(scopeUrl.pathname.length)
    : url.pathname.replace(/^\//, '');

  if (request.mode === 'navigate' || NETWORK_FIRST_FILES.has(relativePath)) {
    event.respondWith(networkFirst(request));
    return;
  }

  event.respondWith(cacheFirstWithRefresh(request));
});

function isPinnedBibleRequest(url) {
  const githubRaw =
    url.hostname === 'raw.githubusercontent.com' &&
    url.pathname.startsWith(
      '/BibleAquifer/ReinaValera1909/v2026-09-18/spa/json/',
    );
  const jsDelivr =
    url.hostname === 'cdn.jsdelivr.net' &&
    url.pathname.startsWith(
      '/gh/BibleAquifer/ReinaValera1909@v2026-09-18/spa/json/',
    );
  return (githubRaw || jsDelivr) && url.pathname.endsWith('.content.json');
}

async function bibleCacheFirst(request) {
  const cache = await caches.open(BIBLE_CACHE_NAME);
  const cached = await cache.match(request);
  if (cached) return cached;

  try {
    const response = await fetch(request);
    if (response.ok) {
      await cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    const fallback = await cache.match(request);
    if (fallback) return fallback;
    throw error;
  }
}

async function networkFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  try {
    const response = await fetch(new Request(request, { cache: 'no-store' }));
    if (response.ok) {
      await cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    const cached = await cache.match(request);
    if (cached) return cached;

    if (request.mode === 'navigate') {
      const shell = await cache.match('./index.html');
      if (shell) return shell;
    }
    throw error;
  }
}

async function cacheFirstWithRefresh(request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);

  const refresh = fetch(request)
    .then(async (response) => {
      if (response.ok) {
        await cache.put(request, response.clone());
      }
      return response;
    })
    .catch(() => null);

  if (cached) {
    refresh.catch(() => null);
    return cached;
  }

  const response = await refresh;
  if (response) return response;
  return Response.error();
}


self.addEventListener('push', (event) => {
  event.waitUntil((async () => {
    let payload = {};
    try {
      payload = event.data ? event.data.json() : {};
    } catch (_) {
      payload = { body: event.data ? event.data.text() : '' };
    }

    const title =
      typeof payload.title === 'string' && payload.title.trim()
        ? payload.title.trim()
        : 'STK Haven';
    const body =
      typeof payload.body === 'string' ? payload.body.trim() : '';
    const targetUrl =
      typeof payload.url === 'string' && payload.url.trim()
        ? payload.url.trim()
        : './';
    const tag =
      typeof payload.tag === 'string' && payload.tag.trim()
        ? payload.tag.trim()
        : 'stk-haven';

    await self.registration.showNotification(title, {
      body,
      icon: './icons/stk-haven-192.png',
      badge: './icons/stk-haven-192.png',
      tag,
      renotify: false,
      data: { url: targetUrl },
    });
  })());
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil((async () => {
    const target = new URL(
      event.notification?.data?.url || './',
      self.registration.scope,
    ).href;

    const windows = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });

    for (const client of windows) {
      if ('focus' in client) {
        if ('navigate' in client && client.url !== target) {
          try {
            await client.navigate(target);
          } catch (_) {}
        }
        await client.focus();
        return;
      }
    }

    if (self.clients.openWindow) {
      await self.clients.openWindow(target);
    }
  })());
});
