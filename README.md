# pettertech.com

Splash page for [pettertech.com](https://pettertech.com) – the GitHub Pages **user site** for `PetterTech`.
Plain HTML/CSS/JS, no build step, no cookies, no tracking.

- Dark/light theme: follows the OS by default; the toggle remembers the visitor's choice (localStorage), and
  picking the same as the OS goes back to "follow the OS".
- The YouTube card shows the newest upload. `latest.json` and the thumbnail (`latest-<id>.jpg`) are generated at
  deploy time by `tools/Update-LatestVideo.ps1` (YouTube RSS, no API key, Shorts skipped), so visitors never load
  anything from Google. If the feed is down it re-uses the live `latest.json`; if that fails too, the card simply
  shows without the video.
- Content-Security-Policy (meta tag in `index.html` and `404.html`): everything must come from this site. The inline
  theme script is allowed by its SHA-256 hash — **if you edit that one-liner, update the hash in the CSP of both
  files** (`printf '%s' '<script body>' | openssl dgst -sha256 -binary | base64`), or the theme will flash.
- Other repos with Pages enabled show up under this domain automatically (e.g. `PetterTech/blog` → `/blog/`).

## Layout

```
index.html, 404.html          the pages
assets/                       style.css, site.js, fonts (subset woff2), logos, photo, favicon, og.png
tools/Update-LatestVideo.ps1  writes latest.json + latest-<id>.jpg (used by the workflow)
tools/test/                   PowerShell + browser tests, fixtures
tools/og/og.html              source for assets/og.png (social preview, 1200x630)
.github/workflows/pages.yml   deploy on push, 3x daily (new videos) and manually
```

Only `index.html`, `404.html` and `assets/` are published; `tools/` stays in the repo.

## Local preview

```pwsh
./tools/Update-LatestVideo.ps1          # optional: writes ./latest.json + thumbnail (gitignored)
python3 -m http.server 8765             # then open http://127.0.0.1:8765
```

## Tests

With the local server running in the repo root:

```pwsh
pwsh -NoProfile -File ./tools/test/Run-Tests.ps1      # latest-video script: fixture, Shorts, æøå, feed down, fallback
bash ./tools/test/run-browser-tests.sh                # theme toggle, CSP, latest video card (headless Chromium)
```

## Maintenance notes

- GitHub disables scheduled workflows in public repos after 60 days without commits. If the latest video stops
  updating, re-enable the workflow in the Actions tab (GitHub sends an e-mail when it happens).
- Actions are pinned to commit SHAs with the tag in a comment (checkout v7.0.1, upload-pages-artifact v5.0.0,
  deploy-pages v5.0.1). Dependabot (monthly) bumps SHA + comment together. Job permissions are least-privilege:
  build gets `contents: read` only, deploy gets `pages: write` + `id-token: write`.
- New social preview: open `tools/og/og.html` at 1200x630 and save a screenshot as `assets/og.png`.
- Fonts: Montserrat (OFL) and DejaVu Sans Mono (licence in `assets/fonts/`), subset to Latin.
