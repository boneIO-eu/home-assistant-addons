#!/usr/bin/with-contenv bashio
# ==============================================================================
# Demo Data Generator - Run Script
# ==============================================================================

# Read configuration using bashio
DB_HOST=$(bashio::config 'db_host')
DB_PORT=$(bashio::config 'db_port')
DB_NAME=$(bashio::config 'db_name')
DB_USER=$(bashio::config 'db_user')
DB_PASSWORD=$(bashio::config 'db_password')
ENERGY_YEARS=$(bashio::config 'energy_years')
POWER_DAYS=$(bashio::config 'power_days')
REGENERATE_ON_START=$(bashio::config 'regenerate_on_start')
DAILY_REGENERATION=$(bashio::config 'daily_regeneration')
DAILY_TIME=$(bashio::config 'daily_regeneration_time')

DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

# Install sensor package if not exists
PACKAGE_DIR="/config/packages"
PACKAGE_FILE="${PACKAGE_DIR}/demo_sensors.yaml"
SOURCE_FILE="/demo_sensors.yaml"

if [ ! -f "${PACKAGE_FILE}" ]; then
    bashio::log.info "Installing demo sensors package..."
    mkdir -p "${PACKAGE_DIR}"
    cp "${SOURCE_FILE}" "${PACKAGE_FILE}"
    bashio::log.warning "Sensor package installed! Please restart Home Assistant to activate sensors."
    bashio::log.warning "Then add to configuration.yaml:"
    bashio::log.warning "  homeassistant:"
    bashio::log.warning "    packages:"
    bashio::log.warning "      demo_sensors: !include packages/demo_sensors.yaml"
else
    bashio::log.info "Sensor package already installed."
fi

bashio::log.info "Demo Data Generator starting..."
bashio::log.info "Database: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
bashio::log.info "Energy years: ${ENERGY_YEARS}, Power days: ${POWER_DAYS}"

run_regeneration() {
    bashio::log.info "Starting data regeneration..."
    python3 /regenerate_demo_data.py \
        --db-url "${DB_URL}" \
        --energy-years "${ENERGY_YEARS}" \
        --power-days "${POWER_DAYS}"
    
    if [ $? -eq 0 ]; then
        bashio::log.info "Data regeneration completed successfully!"
    else
        bashio::log.error "Data regeneration failed!"
    fi
}

# Run on startup if enabled
if bashio::var.true "${REGENERATE_ON_START}"; then
    bashio::log.info "Regenerating data on startup..."
    # Wait for database to be ready
    sleep 10
    run_regeneration
fi

# Daily regeneration loop
if bashio::var.true "${DAILY_REGENERATION}"; then
    bashio::log.info "Daily regeneration enabled at ${DAILY_TIME}"
    
    while true; do
        # Get current time and target time
        CURRENT_HOUR=$(date +%H)
        CURRENT_MIN=$(date +%M)
        TARGET_HOUR=$(echo "${DAILY_TIME}" | cut -d: -f1)
        TARGET_MIN=$(echo "${DAILY_TIME}" | cut -d: -f2)
        
        # Calculate seconds until target time
        CURRENT_SECS=$((10#${CURRENT_HOUR} * 3600 + 10#${CURRENT_MIN} * 60))
        TARGET_SECS=$((10#${TARGET_HOUR} * 3600 + 10#${TARGET_MIN} * 60))
        
        if [ ${TARGET_SECS} -le ${CURRENT_SECS} ]; then
            # Target time already passed today, wait until tomorrow
            SLEEP_SECS=$((86400 - CURRENT_SECS + TARGET_SECS))
        else
            SLEEP_SECS=$((TARGET_SECS - CURRENT_SECS))
        fi
        
        SLEEP_HOURS=$((SLEEP_SECS / 3600))
        bashio::log.info "Next regeneration in ${SLEEP_HOURS} hours"
        
        sleep ${SLEEP_SECS}
        run_regeneration
    done
else
    bashio::log.info "Daily regeneration disabled. Add-on will exit after initial run."
    # Keep container running for logs access
    tail -f /dev/null
fi
