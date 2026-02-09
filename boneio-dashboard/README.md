# Home Assistant Add-on: boneIO Dashboard

![Supports aarch64 Architecture][aarch64-shield] ![Supports amd64 Architecture][amd64-shield] ![Supports armhf Architecture][armhf-shield] ![Supports armv7 Architecture][armv7-shield] ![Supports i386 Architecture][i386-shield]

Multi-device dashboard for boneIO Black controllers. Access all your boneIO devices from a single panel in Home Assistant sidebar.

## How it works

This addon creates an nginx reverse proxy that:

1. Adds a **boneIO** panel to your Home Assistant sidebar
2. Shows a **sidebar with all your boneIO devices**
3. Proxies traffic to each device — no CORS or mixed-content issues
4. Supports **WebSocket** connections (required by boneIO frontend)
5. Works with both **HTTP** (port 8090) and **HTTPS** (port 8443) devices

## Installation

1. Go to **Settings → Add-ons → Add-on Store**
2. Click the three dots in the top right corner
3. Select **Repositories**
4. Add: `https://github.com/boneio-eu/home-assistant-addons`
5. Find **boneIO Dashboard** and click **Install**

## Configuration

```yaml
devices:
  - name: "Living Room"
    url: "http://192.168.1.10:8090"
  - name: "Kitchen"
    url: "https://blk123456.black.boneio.app:8443"
```

### Options

| Option | Description |
|--------|-------------|
| `devices[].name` | Display name for the device in the sidebar |
| `devices[].url` | Full URL to the boneIO Black web interface (HTTP or HTTPS) |

### Finding your device URL

- **HTTP**: `http://<device-ip>:8090` (default boneIO web interface)
- **HTTPS**: `https://blk<serial>.black.boneio.app:8443` (if registered with boneIO cloud)

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[i386-shield]: https://img.shields.io/badge/i386-yes-green.svg
