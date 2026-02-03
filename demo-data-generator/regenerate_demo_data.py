#!/usr/bin/env python3
"""
Unified statistics regeneration script for Home Assistant Demo.

This script regenerates ALL historical statistics:
- Energy statistics (kWh) in `statistics` table
- Short-term power statistics (5-min) in `statistics_short_term` table

Run this on startup or via cron to ensure demo always has fresh data.

Usage:
    python3 regenerate_demo_data.py
    python3 regenerate_demo_data.py --energy-years 2 --power-days 60
"""

import argparse
import math
import random
from datetime import datetime, timedelta

try:
    import psycopg2
    from psycopg2.extras import execute_values
except ImportError:
    print("Please install psycopg2-binary: pip install psycopg2-binary")
    exit(1)


# ============================================
# SENSOR DEFINITIONS
# ============================================

ENERGY_SENSORS = {
    "sensor.demo_boneio_solar_production": {"unit": "kWh", "has_mean": False, "has_sum": True, "name": "Demo Solar Production"},
    "sensor.demo_boneio_battery_energy_in": {"unit": "kWh", "has_mean": False, "has_sum": True, "name": "Demo Battery Energy In"},
    "sensor.demo_boneio_battery_energy_out": {"unit": "kWh", "has_mean": False, "has_sum": True, "name": "Demo Battery Energy Out"},
    "sensor.demo_boneio_grid_consumption": {"unit": "kWh", "has_mean": False, "has_sum": True, "name": "Demo Grid Consumption"},
    "sensor.demo_boneio_grid_return": {"unit": "kWh", "has_mean": False, "has_sum": True, "name": "Demo Grid Return"},
    "sensor.demo_boneio_heat_pump_energy": {"unit": "kWh", "has_mean": False, "has_sum": True, "name": "Demo Heat Pump Energy"},
    "sensor.demo_boneio_induction_energy": {"unit": "kWh", "has_mean": False, "has_sum": True, "name": "Demo Induction Energy"},
    "sensor.demo_boneio_water_heater_energy": {"unit": "kWh", "has_mean": False, "has_sum": True, "name": "Demo Water Heater Energy"},
    "sensor.demo_boneio_ac_energy": {"unit": "kWh", "has_mean": False, "has_sum": True, "name": "Demo AC Energy"},
    "sensor.demo_boneio_lighting_energy": {"unit": "kWh", "has_mean": False, "has_sum": True, "name": "Demo Lighting Energy"},
    "sensor.demo_boneio_washing_energy": {"unit": "kWh", "has_mean": False, "has_sum": True, "name": "Demo Washing Energy"},
    "sensor.demo_boneio_ev_energy": {"unit": "kWh", "has_mean": False, "has_sum": True, "name": "Demo EV Energy"},
    "sensor.demo_boneio_water_total": {"unit": "L", "has_mean": False, "has_sum": True, "name": "Demo Water Total"},
    "sensor.demo_boneio_water_house": {"unit": "L", "has_mean": False, "has_sum": True, "name": "Demo Water House"},
    "sensor.demo_boneio_water_garden": {"unit": "L", "has_mean": False, "has_sum": True, "name": "Demo Water Garden"},
}

POWER_SENSORS = {
    "sensor.demo_boneio_solar_power": {"unit": "W", "has_mean": True, "has_sum": False, "name": "Demo Solar Power"},
    "sensor.demo_boneio_battery_power": {"unit": "W", "has_mean": True, "has_sum": False, "name": "Demo Battery Power"},
    "sensor.demo_boneio_grid_power": {"unit": "W", "has_mean": True, "has_sum": False, "name": "Demo Grid Power"},
    "sensor.demo_boneio_heat_pump_power": {"unit": "W", "has_mean": True, "has_sum": False, "name": "Demo Heat Pump Power"},
    "sensor.demo_boneio_induction_power": {"unit": "W", "has_mean": True, "has_sum": False, "name": "Demo Induction Power"},
    "sensor.demo_boneio_water_heater_power": {"unit": "W", "has_mean": True, "has_sum": False, "name": "Demo Water Heater Power"},
    "sensor.demo_boneio_ac_power": {"unit": "W", "has_mean": True, "has_sum": False, "name": "Demo AC Power"},
    "sensor.demo_boneio_lighting_power": {"unit": "W", "has_mean": True, "has_sum": False, "name": "Demo Lighting Power"},
    "sensor.demo_boneio_washing_power": {"unit": "W", "has_mean": True, "has_sum": False, "name": "Demo Washing Power"},
    "sensor.demo_boneio_ev_power": {"unit": "W", "has_mean": True, "has_sum": False, "name": "Demo EV Power"},
}


# ============================================
# HELPER FUNCTIONS
# ============================================

def get_seasonal_factor(dt: datetime) -> float:
    day_of_year = dt.timetuple().tm_yday
    return 0.3 + 0.7 * (0.5 + 0.5 * math.sin(2 * math.pi * (day_of_year - 80) / 365))


def get_heating_factor(dt: datetime) -> float:
    m = dt.month
    if m in [12, 1, 2]: return 1.0
    if m in [3, 11]: return 0.6
    if m in [4, 10]: return 0.3
    return 0.1


def get_cooling_factor(dt: datetime) -> float:
    m = dt.month
    h = dt.hour
    if m in [6, 7, 8] and 12 <= h <= 22:
        return max(0, 1 - abs(h - 16) / 8)
    return 0


class SmoothValue:
    def __init__(self, initial=0, smoothing=0.9):
        self.value = initial
        self.smoothing = smoothing
    
    def update(self, target):
        self.value = self.value * self.smoothing + target * (1 - self.smoothing)
        return self.value


# ============================================
# POWER CALCULATION (synchronized)
# ============================================

def calculate_power(dt: datetime, smoothers: dict) -> dict:
    """Calculate all power values for a given time (synchronized).
    
    Energy balance: Grid + Solar + Battery_out = Sum of all devices
    """
    hour = dt.hour + dt.minute / 60
    seasonal = get_seasonal_factor(dt)
    heating = get_heating_factor(dt)
    cooling = get_cooling_factor(dt)
    
    # ============================================
    # FIRST: Calculate all device consumption
    # ============================================
    
    # Heat pump (biggest base load)
    hp_target = (1200 if 6 <= dt.hour <= 21 else 600) * heating
    heat_pump = smoothers['heat_pump'].update(hp_target)
    
    # Induction (meal times only)
    if dt.hour == 7 and 20 <= dt.minute <= 50:
        ind_target = 1200
    elif dt.hour == 12 and dt.minute <= 40:
        ind_target = 1500
    elif dt.hour in [18, 19] and ((dt.hour == 18 and dt.minute >= 30) or (dt.hour == 19 and dt.minute <= 30)):
        ind_target = 2000
    else:
        ind_target = 0
    induction = smoothers['induction'].update(ind_target)
    
    # Water heater (morning/evening)
    wh_target = 1200 if dt.hour in [6, 7, 8, 19, 20, 21] else 80
    water_heater = smoothers['water_heater'].update(wh_target)
    
    # AC (summer afternoons only)
    ac_target = 1500 * cooling
    ac = smoothers['ac'].update(ac_target)
    
    # Lighting
    if 18 <= dt.hour <= 23:
        light_target = 200
    elif 6 <= dt.hour <= 8:
        light_target = 120
    else:
        light_target = 30
    lighting = smoothers['lighting'].update(light_target)
    
    # Washing (weekend and evening cycles)
    wd = dt.weekday()
    if (wd >= 5 and dt.hour in [10, 11, 14, 15]) or (wd < 5 and dt.hour == 19 and dt.minute <= 30):
        wash_target = 800
    else:
        wash_target = 0
    washing = smoothers['washing'].update(wash_target)
    
    # EV Charger (night only, reduced to be more realistic)
    ev_target = 3500 if dt.hour in [23, 0, 1, 2, 3, 4] else 0
    ev = smoothers['ev'].update(ev_target)
    
    # Other/base load (fridge, standby, etc.) - implicit in grid calculation
    base_load = 150
    
    # ============================================
    # TOTAL CONSUMPTION = sum of all devices
    # ============================================
    total_consumption = (heat_pump + induction + water_heater + ac + 
                         lighting + washing + ev + base_load)
    
    # ============================================
    # SOLAR PRODUCTION
    # ============================================
    if hour < 6 or hour > 20:
        solar_target = 0
    else:
        solar_factor = max(0, math.exp(-((hour - 12.5) ** 2) / 18))
        solar_target = 6000 * seasonal * solar_factor
    solar = smoothers['solar'].update(solar_target)
    
    # ============================================
    # BATTERY: charges from excess solar, discharges when needed
    # ============================================
    solar_excess = max(0, solar - total_consumption)
    solar_deficit = max(0, total_consumption - solar)
    
    if solar_excess > 500:
        # Charge battery from excess solar
        battery_target = -min(2500, solar_excess * 0.8)
    elif solar_deficit > 500 and (17 <= dt.hour <= 22):
        # Discharge battery in evening when solar is low
        battery_target = min(1500, solar_deficit * 0.6)
    elif solar_deficit > 0 and (dt.hour >= 22 or dt.hour < 6):
        # Small discharge at night
        battery_target = min(300, solar_deficit * 0.3)
    else:
        battery_target = 0
    battery = smoothers['battery'].update(battery_target)
    
    # ============================================
    # GRID = Total consumption - Solar used - Battery discharge
    # ============================================
    solar_used = min(solar, total_consumption)  # Can't use more solar than we produce
    battery_discharge = max(0, battery)  # Only positive = discharge
    
    grid = total_consumption - solar_used - battery_discharge
    
    return {
        "sensor.demo_boneio_solar_power": solar,
        "sensor.demo_boneio_battery_power": max(0, battery),  # Only show discharge (positive) for power graph
        "_battery_raw": battery, # Add this for energy calculation
        "sensor.demo_boneio_grid_power": grid,
        "sensor.demo_boneio_heat_pump_power": heat_pump,
        "sensor.demo_boneio_induction_power": induction,
        "sensor.demo_boneio_water_heater_power": water_heater,
        "sensor.demo_boneio_ac_power": ac,
        "sensor.demo_boneio_lighting_power": lighting,
        "sensor.demo_boneio_washing_power": washing,
        "sensor.demo_boneio_ev_power": ev,
    }


def calculate_energy(dt: datetime, power: dict) -> dict:
    """Calculate hourly energy from power values."""
    return {
        "sensor.demo_boneio_solar_production": power["sensor.demo_boneio_solar_power"] / 1000,
        "sensor.demo_boneio_battery_energy_in": max(0, -power.get("_battery_raw", 0)) / 1000,
        "sensor.demo_boneio_battery_energy_out": max(0, power["sensor.demo_boneio_battery_power"]) / 1000,
        "sensor.demo_boneio_grid_consumption": max(0, power["sensor.demo_boneio_grid_power"]) / 1000,
        "sensor.demo_boneio_grid_return": max(0, -power["sensor.demo_boneio_grid_power"]) / 1000,
        "sensor.demo_boneio_heat_pump_energy": power["sensor.demo_boneio_heat_pump_power"] / 1000,
        "sensor.demo_boneio_induction_energy": power["sensor.demo_boneio_induction_power"] / 1000,
        "sensor.demo_boneio_water_heater_energy": power["sensor.demo_boneio_water_heater_power"] / 1000,
        "sensor.demo_boneio_ac_energy": power["sensor.demo_boneio_ac_power"] / 1000,
        "sensor.demo_boneio_lighting_energy": power["sensor.demo_boneio_lighting_power"] / 1000,
        "sensor.demo_boneio_washing_energy": power["sensor.demo_boneio_washing_power"] / 1000,
        "sensor.demo_boneio_ev_energy": power["sensor.demo_boneio_ev_power"] / 1000,
    }


def calculate_water(dt: datetime) -> dict:
    """Calculate hourly water consumption (L)."""
    h = dt.hour
    m = dt.month
    
    if 7 <= h <= 9:
        house = 18
    elif 18 <= h <= 21:
        house = 13
    else:
        house = 2.5
    
    summer = m in [5, 6, 7, 8, 9]
    watering = h in [6, 7, 19, 20]
    garden = 25 if summer and watering else 0
    
    return {
        "sensor.demo_boneio_water_total": house + garden,
        "sensor.demo_boneio_water_house": house,
        "sensor.demo_boneio_water_garden": garden,
    }


# ============================================
# DATABASE FUNCTIONS
# ============================================

def ensure_metadata(conn, sensors: dict) -> dict:
    """Create or update statistics_meta entries."""
    cursor = conn.cursor()
    id_map = {}
    
    for sensor_id, meta in sensors.items():
        cursor.execute("SELECT id FROM statistics_meta WHERE statistic_id = %s", (sensor_id,))
        result = cursor.fetchone()
        
        if result:
            cursor.execute(
                "UPDATE statistics_meta SET has_mean = %s, has_sum = %s WHERE id = %s",
                (meta["has_mean"], meta["has_sum"], result[0])
            )
            id_map[sensor_id] = result[0]
        else:
            cursor.execute(
                """INSERT INTO statistics_meta 
                (statistic_id, source, unit_of_measurement, has_mean, has_sum, name, mean_type)
                VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id""",
                (sensor_id, "recorder", meta["unit"], meta["has_mean"], meta["has_sum"], meta.get("name"), 0)
            )
            id_map[sensor_id] = cursor.fetchone()[0]
    
    conn.commit()
    return id_map


def generate_energy_statistics(start: datetime, end: datetime, meta_ids: dict) -> list:
    """Generate hourly energy statistics."""
    stats = []
    current = start
    sums = {k: 0 for k in meta_ids.keys()}
    
    smoothers = {
        'solar': SmoothValue(0, 0.92), 'battery': SmoothValue(0, 0.88),
        'grid': SmoothValue(1000, 0.85), 'heat_pump': SmoothValue(500, 0.90),
        'induction': SmoothValue(0, 0.70), 'water_heater': SmoothValue(0, 0.80),
        'ac': SmoothValue(0, 0.90), 'lighting': SmoothValue(50, 0.85),
        'washing': SmoothValue(0, 0.75), 'ev': SmoothValue(0, 0.95),
    }
    
    total = int((end - start).total_seconds() / 3600)
    i = 0
    
    while current < end:
        power = calculate_power(current, smoothers)
        energy = calculate_energy(current, power)
        water = calculate_water(current)
        
        ts = current.timestamp()
        
        for sensor_id in meta_ids.keys():
            if sensor_id in energy:
                value = energy[sensor_id]
            elif sensor_id in water:
                value = water[sensor_id]
            else:
                continue
            
            sums[sensor_id] += value
            stats.append((ts, meta_ids[sensor_id], ts, None, None, None, None, value, sums[sensor_id]))
        
        current += timedelta(hours=1)
        i += 1
        if i % 2000 == 0:
            print(f"  Energy: {i}/{total} hours ({100*i//total}%)")
    
    return stats


def generate_power_statistics(start: datetime, end: datetime, meta_ids: dict) -> list:
    """Generate 5-minute power statistics."""
    stats = []
    current = start
    interval = timedelta(minutes=5)
    
    smoothers = {
        'solar': SmoothValue(0, 0.92), 'battery': SmoothValue(0, 0.88),
        'grid': SmoothValue(1000, 0.85), 'heat_pump': SmoothValue(500, 0.90),
        'induction': SmoothValue(0, 0.70), 'water_heater': SmoothValue(0, 0.80),
        'ac': SmoothValue(0, 0.90), 'lighting': SmoothValue(50, 0.85),
        'washing': SmoothValue(0, 0.75), 'ev': SmoothValue(0, 0.95),
    }
    
    total = int((end - start).total_seconds() / 300)
    i = 0
    
    while current < end:
        power = calculate_power(current, smoothers)
        ts = current.timestamp()
        
        for sensor_id, meta_id in meta_ids.items():
            if sensor_id in power:
                mean = power[sensor_id]
                stats.append((ts, meta_id, ts, mean, mean * 0.95, mean * 1.05, None, None))
        
        current += interval
        i += 1
        if i % 5000 == 0:
            print(f"  Power: {i}/{total} intervals ({100*i//total}%)")
    
    return stats


def insert_energy_stats(conn, stats: list, meta_ids: dict):
    """Insert energy statistics."""
    cursor = conn.cursor()
    
    print("  Clearing old energy stats...")
    # Get ALL metadata_ids for energy sensors from DB
    sensor_names = tuple(ENERGY_SENSORS.keys())
    cursor.execute(
        "SELECT id FROM statistics_meta WHERE statistic_id IN %s",
        (sensor_names,)
    )
    all_meta_ids = [row[0] for row in cursor.fetchall()]
    
    for meta_id in all_meta_ids:
        cursor.execute("DELETE FROM statistics WHERE metadata_id = %s", (meta_id,))
    conn.commit()
    print(f"    Cleared {len(all_meta_ids)} sensors")
    
    # Deduplicate stats (keep last occurrence)
    seen = {}
    for s in stats:
        key = (s[1], s[2])  # (metadata_id, start_ts)
        seen[key] = s
    unique_stats = list(seen.values())
    
    print(f"  Inserting {len(unique_stats)} records (deduped from {len(stats)})...")
    batch_size = 5000
    for i in range(0, len(unique_stats), batch_size):
        batch = unique_stats[i:i + batch_size]
        execute_values(
            cursor,
            """INSERT INTO statistics 
            (created_ts, metadata_id, start_ts, mean, min, max, last_reset_ts, state, sum)
            VALUES %s""",
            batch
        )
        if (i + batch_size) % 50000 == 0:
            print(f"    Inserted {i + len(batch)}/{len(unique_stats)}...")
    
    conn.commit()
    print(f"  Inserted {len(stats)} energy records")


def insert_power_stats(conn, stats: list, meta_ids: dict):
    """Insert short-term power statistics."""
    cursor = conn.cursor()
    
    print("  Clearing old power stats...")
    for meta_id in meta_ids.values():
        cursor.execute("DELETE FROM statistics_short_term WHERE metadata_id = %s", (meta_id,))
    conn.commit()
    
    print(f"  Inserting {len(stats)} records...")
    batch_size = 5000
    for i in range(0, len(stats), batch_size):
        execute_values(
            cursor,
            """INSERT INTO statistics_short_term 
            (created_ts, metadata_id, start_ts, mean, min, max, last_reset_ts, state)
            VALUES %s
            ON CONFLICT (metadata_id, start_ts) DO UPDATE SET
                mean = EXCLUDED.mean,
                min = EXCLUDED.min,
                max = EXCLUDED.max,
                created_ts = EXCLUDED.created_ts""",
            stats[i:i + batch_size]
        )
    
    conn.commit()
    print(f"  Inserted {len(stats)} power records")


# ============================================
# MAIN
# ============================================

def main():
    parser = argparse.ArgumentParser(description="Regenerate all demo statistics")
    parser.add_argument("--db-url", default="postgresql://homeassistant:homeassistant@localhost:5432/homeassistant")
    parser.add_argument("--energy-years", type=float, default=2.0, help="Years of energy history")
    parser.add_argument("--power-days", type=int, default=60, help="Days of power history")
    args = parser.parse_args()
    
    print("🔄 Home Assistant Demo Data Regeneration")
    print("=" * 50)
    
    conn = psycopg2.connect(args.db_url)
    
    now = datetime.now().replace(minute=0, second=0, microsecond=0)
    energy_start = now - timedelta(days=int(args.energy_years * 365))
    power_start = now - timedelta(days=args.power_days)
    power_start = power_start.replace(minute=(power_start.minute // 5) * 5)
    
    # Create/update metadata
    print("\n📝 Ensuring metadata...")
    all_sensors = {**ENERGY_SENSORS, **POWER_SENSORS}
    meta_ids = ensure_metadata(conn, all_sensors)
    print(f"   {len(meta_ids)} sensors configured")
    
    # Generate energy statistics
    print(f"\n⚡ Generating energy statistics ({args.energy_years} years)...")
    energy_meta = {k: meta_ids[k] for k in ENERGY_SENSORS.keys() if k in meta_ids}
    energy_stats = generate_energy_statistics(energy_start, now, energy_meta)
    insert_energy_stats(conn, energy_stats, energy_meta)
    
    # Generate power statistics
    print(f"\n🔌 Generating power statistics ({args.power_days} days)...")
    power_meta = {k: meta_ids[k] for k in POWER_SENSORS.keys() if k in meta_ids}
    power_stats = generate_power_statistics(power_start, now, power_meta)
    insert_power_stats(conn, power_stats, power_meta)
    
    conn.close()
    
    print("\n✅ Done!")
    print(f"   Energy: {len(energy_stats):,} records")
    print(f"   Power: {len(power_stats):,} records")


if __name__ == "__main__":
    main()
