# Demo Data Generator Add-on

Generates realistic historical energy and power statistics for Home Assistant Energy Dashboard demos.

## Features

- **Energy Statistics**: Generates 2 years of hourly energy data (kWh) for solar, battery, grid, and device sensors
- **Power Statistics**: Generates 60 days of 5-minute power data (W) for Power Sources graph
- **Synchronized Data**: All sensors derive from a master calculation for realistic, consistent data
- **Automatic Regeneration**: Runs on startup and optionally daily to ensure fresh data
- **TimescaleDB Support**: Works with the official TimescaleDB add-on

## Sensors Generated

### Energy Sensors (kWh)
- Solar Production
- Battery In/Out
- Grid Consumption/Return
- Heat Pump, Induction Cooktop, Water Heater
- Air Conditioning, Lighting, Washing Machine, EV Charger
- Water Consumption (House + Garden)

### Power Sensors (W)
- Solar Power
- Battery Power
- Grid Power
- Individual device power (7 devices)

## Requirements

1. **TimescaleDB Add-on** must be installed and running
2. **Home Assistant recorder** configured to use TimescaleDB

## Usage

1. Install and start the add-on
2. Wait for initial data generation (takes 2-3 minutes)
3. Open Energy Dashboard - you'll see 2 years of history!

## Support

For issues, please visit: https://github.com/boneio-eu/home-assistant-addons/issues
