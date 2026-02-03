# BoneIO Home Assistant Add-ons

![BoneIO](https://boneio.eu/logo.png)

Add this repository to your Home Assistant instance to install BoneIO add-ons.

## Add-ons

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
6. Find "Demo Data Generator" and click **Install**

## Configuration

```yaml
db_host: core-timescaledb    # TimescaleDB add-on hostname
db_port: 5432
db_name: homeassistant
db_user: homeassistant
db_password: homeassistant
energy_years: 2              # Years of energy history
power_days: 60               # Days of power history
regenerate_on_start: true    # Regenerate on add-on start
daily_regeneration: true     # Enable daily regeneration
daily_regeneration_time: "03:00"  # Time for daily regeneration
```

## License

MIT License
