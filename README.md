# boneIO Home Assistant Add-ons

![boneIO](https://boneio.eu/logo.png)

Add this repository to your Home Assistant instance to install boneIO add-ons.

## Add-ons

### boneIO Dashboard

Multi-device dashboard for boneIO Black controllers. Access all your boneIO devices from a single panel in Home Assistant sidebar.

**Features:**
- Sidebar with all your boneIO Black devices
- Nginx reverse proxy — no CORS or mixed-content issues
- WebSocket support for real-time updates
- Works with HTTP (port 8090) and HTTPS (port 8443) devices

### Demo Data Generator

Generates realistic historical energy data for demonstration and showcase purposes. Perfect for trade shows and demos.

**Features:**
- Generates 2 years of energy statistics (kWh)
- Generates 60 days of power statistics (5-minute intervals)
- Automatic regeneration on startup
- Daily scheduled regeneration
- Works with TimescaleDB add-on

## Installation

1. Go to **Settings → Add-ons → Add-on Store**
2. Click the three dots in the top right corner
3. Select **Repositories**
4. Add this URL: `https://github.com/boneio-eu/home-assistant-addons`
5. Click **Add**
6. Find the desired add-on and click **Install**

## License

MIT License
