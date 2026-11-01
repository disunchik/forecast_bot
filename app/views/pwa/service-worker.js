self.addEventListener("install", () => self.skipWaiting())
self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()))

// Offline-кэш и Web Push намеренно не включены в первой версии.
// Service Worker уже зарегистрирован, поэтому push можно добавить без переделки приложения.
