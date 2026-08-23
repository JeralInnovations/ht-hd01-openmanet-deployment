const CACHE='bombs-camera-v1';
self.addEventListener('install',(event)=>{event.waitUntil(caches.open(CACHE).then((cache)=>cache.addAll(['./','index.html','app.css','app.js','manifest.webmanifest','icon-192.png','icon-512.png'])));self.skipWaiting();});
self.addEventListener('activate',(event)=>{event.waitUntil(self.clients.claim());});
self.addEventListener('fetch',(event)=>{if(event.request.method!=='GET')return;event.respondWith(fetch(event.request).catch(()=>caches.match(event.request)));});
