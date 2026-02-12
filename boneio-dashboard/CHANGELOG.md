# Changelog

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
