(() => {
  'use strict';

  const STORAGE_KEY = 'bombs-camera-password';
  const status = document.querySelector('#status');
  const setup = document.querySelector('#setup');
  const launcher = document.querySelector('#launcher');
  const passwordInput = document.querySelector('#camera-password');
  const openButton = document.querySelector('#open-camera');
  const resetButton = document.querySelector('#change-password');

  function makeIntent(password) {
    const user = encodeURIComponent('admin');
    const pass = encodeURIComponent(password);
    const target = `${user}:${pass}@10.41.0.51:8554/profile1`;
    return `intent://${target}#Intent;scheme=rtsp;package=org.videolan.vlc;action=android.intent.action.VIEW;type=video/*;S.title=Bombs%20Camera;end`;
  }

  function launch(password) {
    status.textContent = 'Opening full-screen video in VLC…';
    window.location.href = makeIntent(password);
    window.setTimeout(() => { status.textContent = 'Tap below if VLC did not open.'; }, 1400);
  }

  function showSetup() {
    setup.hidden = false;
    launcher.hidden = true;
    status.textContent = 'One-time setup';
    passwordInput.focus();
  }

  function showLauncher(password, autoLaunch) {
    setup.hidden = true;
    launcher.hidden = false;
    openButton.onclick = () => launch(password);
    status.textContent = 'Camera ready';
    if (autoLaunch && /Android/i.test(navigator.userAgent)) {
      window.setTimeout(() => launch(password), 250);
    }
  }

  setup.addEventListener('submit', (event) => {
    event.preventDefault();
    const password = passwordInput.value;
    if (!password) return;
    localStorage.setItem(STORAGE_KEY, password);
    passwordInput.value = '';
    showLauncher(password, false);
    launch(password);
  });

  resetButton.addEventListener('click', () => {
    localStorage.removeItem(STORAGE_KEY);
    showSetup();
  });

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('sw.js').catch(() => undefined);
  }

  const savedPassword = localStorage.getItem(STORAGE_KEY);
  if (savedPassword) showLauncher(savedPassword, true);
  else showSetup();
})();
