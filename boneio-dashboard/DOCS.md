# boneIO Dashboard - Documentation

## Overview

The boneIO Dashboard addon provides a unified interface to manage multiple boneIO Black controllers from within Home Assistant. It appears as a panel in the HA sidebar and uses nginx to proxy connections to your devices.

## Architecture

```
Home Assistant Ingress → Addon (nginx:5000) → Dashboard page
                                                ├─ /proxy/0/ → Device 1
                                                ├─ /proxy/1/ → Device 2
                                                └─ /proxy/N/ → Device N
```

- The addon runs **nginx** as a reverse proxy
- Each configured device gets a proxy path (`/proxy/0/`, `/proxy/1/`, etc.)
- The dashboard page shows a sidebar with device names
- Clicking a device loads its frontend via iframe through the proxy
- WebSocket connections are fully supported (required for boneIO real-time updates)

## Authentication

Each boneIO device has its own authentication. When you first access a device through the dashboard, you'll need to log in to that device. The session cookie is stored per proxy path, so you only need to log in once per browser session.

## Troubleshooting

### Device not loading

1. Check that the device URL is correct and accessible from the HA host
2. Check addon logs: **Settings → Add-ons → boneIO Dashboard → Log**
3. Try accessing the device URL directly in your browser

### Mixed content warnings

If your HA instance uses HTTPS but the device uses HTTP, the proxy handles this transparently — no mixed content issues since all traffic goes through the ingress proxy.

### WebSocket connection issues

The proxy is configured with long timeouts (86400s) and WebSocket upgrade support. If you experience disconnections, check your network connectivity to the device.
