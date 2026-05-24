# Changelog

## 1.0.21

### Improvements

- **Persistent device selection** — Dashboard remembers which controller was active when you press F5 or reload the page. Uses `localStorage` to persist the selection. Falls back to first device if saved index is invalid.
- **Background asset prefetch** — 3 seconds after the active device loads, the dashboard fetches HTML pages of other configured devices and adds `<link rel="prefetch">` tags for their CSS/JS bundles. This warms the browser cache so switching between devices feels near-instant.

## 1.0.20

### Bug Fixes

- Fixed backup files not being downloaded — checksum deduplication now also verifies the backup file exists on disk before skipping download
- Use fixed filename per device (`{slug}.tar.gz`) instead of date-based names to avoid accumulating old files
- Added `backup_post` hook to clean up temporary backup files from `/data/backup/` after HA packs them into the backup archive — saves disk space between backups

## 1.0.16

### Bug Fixes

- Fixed backup configs not included in HA backup archive — changed storage from `/backup/` to `/data/backup/` (Supervisor only includes `/data/` in addon backups)

## 1.0.15

### Bug Fixes

- Fixed `No exec command specified` error during backup — removed empty `backup_post` from config
- Detect old device firmware without backup API — log warning and skip instead of failing

## 1.0.14

### New Features

- Automatic config backup of all boneIO Black devices during HA backup
- Downloads device config via API before each HA backup (pre-hook)
- SHA256 checksum deduplication — skips download if config unchanged
- Optional authentication support (username/password per device)

### Bug Fixes

- Fixed backup script crash caused by bashio `set -e` — any curl failure would abort entire backup
- Handle bashio `null` for empty optional config fields (username, password)
- Added curl timeouts to prevent script hanging on unreachable devices
- Backup script always exits 0 so device failures don't block HA backup

## 1.0.13

### New Features

- Added `Cache-Control: no-store` headers to dashboard HTML, devices JSON API, and proxied responses
- Prevents Cloudflare Tunnel from caching stale addon pages and device configurations
- Fixes issue where addon showed outdated device URLs and old frontend versions after config changes
- Add option to add backup to Home Assistant backup in the future versions of the app

## 1.0.12

### Bug Fixes

- Fixed `init-nginx` crash: escape quotes in `Cache-Control` header inside `PROXY_LOCATIONS` bash string
- `no-cache,` was interpreted as a shell command instead of nginx directive

## 1.0.11

### Bug Fixes

- Added `Cache-Control: no-store` headers to dashboard HTML, devices JSON API, and proxied responses
- Prevents Cloudflare Tunnel from caching stale addon pages and device configurations
- Fixes issue where addon showed outdated device URLs and old frontend versions after config changes

## 1.0.10

### Bug Fixes

- Fixed large JS bundle (4MB+) being truncated by nginx proxy buffers
- Increased `proxy_buffers` and `proxy_max_temp_file_size` to handle boneIO frontend assets
- Root cause: `sub_filter` forces nginx to buffer entire response, but default 32KB buffers were too small

## 1.0.9

### Bug Fixes

- Fixed JS bundle corruption caused by `sub_filter` on `application/javascript`
- Removed `application/javascript` from `sub_filter_types` — only HTML is filtered now
- Added path rewriting for static files (`/boneio*`, `/sw.js`) in HTML responses
- Fixes black screen when accessing boneIO through Cloudflare Tunnel / remote access

## 1.0.8

### New Features

- Dark/light theme sync with Home Assistant
- Dashboard automatically detects HA theme via `prefers-color-scheme`
- Theme is passed to boneIO frontend via URL parameter
- Direct device access link in sidebar (external link icon opens device URL in new tab)

### Improvements

- Sidebar panel icon changed to `mdi:alpha-b-circle-outline`

## 1.0.7

### New Features

- Collapsible sidebar (desktop) with toggle button and state persistence
- Mobile overlay drawer with hamburger button and backdrop
- Hamburger button positioned at bottom-left on mobile

### Improvements

- Removed blue tap highlight on mobile menu button

## 1.0.5

### Bug Fixes

- Fixed ingress port conflict (changed from 5000 to 5100)
- Fixed frontend API calls through HA ingress proxy
- Injected `window.__BONEIO_BASE_PATH__` for dynamic base path detection
- Fixed React Router `basename` for proxy sub-path compatibility
- Fixed Nginx `sub_filter` for HTML injection
- Fixed Node-RED iframe URL to use base path in ingress mode

## 1.0.0

- Initial release
- Multi-device support with sidebar navigation
- Nginx reverse proxy with WebSocket support
- Works with HTTP and HTTPS boneIO devices
- Home Assistant ingress integration (sidebar panel)
