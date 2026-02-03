# Demo Data Generator Add-on

Generates realistic historical energy and power statistics for Home Assistant Energy Dashboard demos.

## Features

- **Automatic Sensor Installation**: Installs 24 demo sensors on first run
- **Energy Statistics**: Generates 2 years of hourly energy data (kWh)
- **Power Statistics**: Generates 60 days of 5-minute power data (W)
- **Synchronized Data**: All sensors derive from master calculation for consistency
- **Daily Regeneration**: Optionally regenerate data daily at scheduled time

## Quick Start

1. Install and start the add-on
2. Check the logs - it will install sensor package automatically
3. Add to your `configuration.yaml`:
   ```yaml
   homeassistant:
     packages:
       demo_sensors: !include packages/demo_sensors.yaml
   ```
4. Restart Home Assistant
5. Configure Energy Dashboard with the new sensors

## Sensors Included

### Energy (kWh)
- Solar Production, Battery In/Out, Grid Consumption/Return
- Heat Pump, Induction Cooktop, Water Heater, AC
- Lighting, Washing Machine, EV Charger
- Water Consumption (House + Garden)

### Power (W)
- Solar, Battery, Grid Power
- Individual device power (7 devices)

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| db_host | core-timescaledb | TimescaleDB hostname |
| db_port | 5432 | Database port |
| db_name | homeassistant | Database name |
| db_user | homeassistant | Database user |
| db_password | homeassistant | Database password |
| energy_years | 2 | Years of energy history to generate |
| power_days | 60 | Days of power history to generate |
| regenerate_on_start | true | Regenerate data on add-on start |
| daily_regeneration | true | Enable daily regeneration |
| daily_regeneration_time | 03:00 | Time for daily regeneration |

## Support

For issues: https://github.com/boneio-eu/home-assistant-addons/issues
