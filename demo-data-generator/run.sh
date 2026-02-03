#!/bin/bash
# ==============================================================================
# Demo Data Generator - Run Script (Alpine version without bashio)
# ==============================================================================

set -e

# Read configuration from HA add-on options
OPTIONS_FILE="/data/options.json"

if [ ! -f "$OPTIONS_FILE" ]; then
    echo "[ERROR] Options file not found: $OPTIONS_FILE"
    exit 1
fi

DB_HOST=$(jq -r '.db_host' "$OPTIONS_FILE")
DB_PORT=$(jq -r '.db_port' "$OPTIONS_FILE")
DB_NAME=$(jq -r '.db_name' "$OPTIONS_FILE")
DB_USER=$(jq -r '.db_user' "$OPTIONS_FILE")
DB_PASSWORD=$(jq -r '.db_password' "$OPTIONS_FILE")
ENERGY_YEARS=$(jq -r '.energy_years' "$OPTIONS_FILE")
POWER_DAYS=$(jq -r '.power_days' "$OPTIONS_FILE")
REGENERATE_ON_START=$(jq -r '.regenerate_on_start' "$OPTIONS_FILE")
DAILY_REGENERATION=$(jq -r '.daily_regeneration' "$OPTIONS_FILE")
DAILY_TIME=$(jq -r '.daily_regeneration_time' "$OPTIONS_FILE")

DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Demo Data Generator starting..."
log "Database: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
log "Energy years: ${ENERGY_YEARS}, Power days: ${POWER_DAYS}"

run_regeneration() {
    log "Starting data regeneration..."
    python3 /regenerate_demo_data.py \
        --db-url "${DB_URL}" \
        --energy-years "${ENERGY_YEARS}" \
        --power-days "${POWER_DAYS}"
    
    if [ $? -eq 0 ]; then
        log "Data regeneration completed successfully!"
    else
        log "ERROR: Data regeneration failed!"
    fi
}

# Run on startup if enabled
if [ "$REGENERATE_ON_START" = "true" ]; then
    log "Regenerating data on startup..."
    # Wait for database to be ready
    sleep 10
    run_regeneration
fi

# Daily regeneration loop
if [ "$DAILY_REGENERATION" = "true" ]; then
    log "Daily regeneration enabled at ${DAILY_TIME}"
    
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
        log "Next regeneration in ${SLEEP_HOURS} hours"
        
        sleep ${SLEEP_SECS}
        run_regeneration
    done
else
    log "Daily regeneration disabled. Add-on will exit after initial run."
    # Keep container running for logs access
    tail -f /dev/null
fi
