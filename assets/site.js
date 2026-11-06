// pettertech.com – theme toggle + latest YouTube video. No cookies, no tracking.
(() => {
  // ---------- theme: follows the OS until the visitor picks one ----------
  const root = document.documentElement;
  const mq = matchMedia('(prefers-color-scheme: light)');
  const btn = document.getElementById('theme-toggle');
  const metaColor = document.querySelector('meta[name="theme-color"]');
  const systemTheme = () => (mq.matches ? 'light' : 'dark');
  const stored = () => {
    try { const t = localStorage.getItem('theme'); return t === 'light' || t === 'dark' ? t : null; } catch { return null; }
  };
  const store = (value) => {
    try { value ? localStorage.setItem('theme', value) : localStorage.removeItem('theme'); } catch { /* private mode */ }
  };
  function apply(theme) {
    root.dataset.theme = theme;
    if (metaColor) metaColor.content = theme === 'light' ? '#f2f2f2' : '#232323';
    if (btn) {
      const next = theme === 'dark' ? 'light' : 'dark';
      btn.setAttribute('aria-label', `Switch to ${next} mode`);
      btn.title = `Switch to ${next} mode`;
    }
  }
  apply(stored() || systemTheme());
  btn?.addEventListener('click', () => {
    const next = root.dataset.theme === 'dark' ? 'light' : 'dark';
    // Picking the same as the OS means "follow the OS again".
    store(next === systemTheme() ? null : next);
    apply(next);
  });
  mq.addEventListener('change', () => { if (!stored()) apply(systemTheme()); });

  // ---------- latest video (latest.json is written at deploy time) ----------
  (async () => {
    if (!document.getElementById('yt')) return;
    try {
      const res = await fetch('/latest.json', { cache: 'no-store' });
      if (!res.ok) return;
      const v = await res.json();
      if (!/^[\w-]{11}$/.test(v.id || '')) return;
      const link = document.getElementById('latest');
      link.href = 'https://www.youtube.com/watch?v=' + v.id;
      // Thumbnail is self-hosted at deploy time (no requests to Google from visitors).
      const img = document.getElementById('latest-img');
      img.onerror = () => { img.onerror = null; img.removeAttribute('src'); };   // grey box + play button
      if (v.thumbnail !== false) img.src = '/latest-' + v.id + '.jpg';
      const title = String(v.title || 'Latest video').slice(0, 200);
      document.getElementById('latest-title').textContent = title;
      link.setAttribute('aria-label', 'Watch the latest video: ' + title);
      if (v.published) {
        const when = new Date(v.published);
        const days = Math.floor((Date.now() - when) / 864e5);
        document.getElementById('latest-date').textContent =
          days < 1 ? 'New today' : days < 2 ? 'New yesterday' : days < 14 ? `New · ${days} days ago`
          : 'Latest · ' + when.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
      }
      link.hidden = false;
      document.getElementById('yt').classList.add('has-latest');
    } catch { /* keep the plain YouTube card */ }
  })();
})();
