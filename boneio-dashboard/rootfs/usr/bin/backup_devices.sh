#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Backup pre-hook: download config from all configured Black devices
# Called by HA Supervisor before creating a backup.
#
# For each device:
#   1. Optionally login (if username/password configured) to get JWT token
#   2. Check remote SHA256 checksum (skip download if unchanged)
#   3. Download config archive (.tar.gz) into /data/backup/
#      (Supervisor includes /data/ in addon backups automatically)
#
# NOTE: This script must ALWAYS exit 0 so HA backup is not blocked.
# Individual device failures are logged as warnings but do not abort.
# ==============================================================================

# Disable exit-on-error — we handle errors per device and must not block HA backup
set +e

# Debug marker — check if this file exists to confirm script ran
echo "$(date -Iseconds) backup_devices.sh started" >> /data/backup_debug.log

BACKUP_DIR="/data/backup"
CHECKSUM_DIR="/data/checksums"
mkdir -p "${BACKUP_DIR}" "${CHECKSUM_DIR}"

DEVICE_COUNT=$(bashio::config 'devices | length')
echo "DEBUG: DEVICE_COUNT='${DEVICE_COUNT}'" >> /data/backup_debug.log
echo "DEBUG: options.json content:" >> /data/backup_debug.log
cat /data/options.json >> /data/backup_debug.log 2>&1
echo "" >> /data/backup_debug.log

if [ -z "${DEVICE_COUNT}" ] || [ "${DEVICE_COUNT}" -eq 0 ] 2>/dev/null; then
    bashio::log.info "Backup pre-hook: no devices configured, nothing to do"
    echo "DEBUG: exiting - no devices" >> /data/backup_debug.log
    exit 0
fi

bashio::log.info "Backup pre-hook: processing ${DEVICE_COUNT} device(s)..."

FAILED=0

for i in $(seq 0 $((DEVICE_COUNT - 1))); do
    NAME=$(bashio::config "devices[${i}].name")
    URL=$(bashio::config "devices[${i}].url")
    USERNAME=$(bashio::config "devices[${i}].username")
    PASSWORD=$(bashio::config "devices[${i}].password")

    # bashio::config returns literal "null" for empty optional fields (str?, password?)
    [ "${USERNAME}" = "null" ] && USERNAME=""
    [ "${PASSWORD}" = "null" ] && PASSWORD=""

    # Strip trailing slash from URL
    URL="${URL%/}"

    SLUG=$(echo "${NAME}" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')

    bashio::log.info "  Device ${i}: ${NAME} (${URL})"
    echo "DEBUG: Device ${i}: NAME='${NAME}' URL='${URL}' USER='${USERNAME}' SLUG='${SLUG}'" >> /data/backup_debug.log

    # 1. Login if credentials are provided
    TOKEN=""
    if [ -n "${USERNAME}" ] && [ -n "${PASSWORD}" ]; then
        bashio::log.info "    Authenticating with username '${USERNAME}'..."
        LOGIN_RESPONSE=$(curl -sk --connect-timeout 10 --max-time 30 \
            -X POST "${URL}/api/login" \
            -H "Content-Type: application/json" \
            -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}" \
            2>/dev/null) || true

        TOKEN=$(echo "${LOGIN_RESPONSE}" | jq -r '.token // empty' 2>/dev/null) || true

        if [ -z "${TOKEN}" ]; then
            bashio::log.warning "    Authentication failed for ${NAME}, trying without auth..."
        else
            bashio::log.info "    Authentication successful"
        fi
    fi

    # Build auth header
    AUTH_HEADER=""
    if [ -n "${TOKEN}" ]; then
        AUTH_HEADER="Authorization: Bearer ${TOKEN}"
    fi

    # 2. Check remote checksum — skip download if config unchanged
    #    Also used to detect old firmware that doesn't support backup API yet.
    if [ -n "${AUTH_HEADER}" ]; then
        CHECKSUM_RESPONSE=$(curl -sk --connect-timeout 10 --max-time 15 -w "\n%{http_code}" \
            -H "${AUTH_HEADER}" "${URL}/api/config/checksum" 2>/dev/null) || true
    else
        CHECKSUM_RESPONSE=$(curl -sk --connect-timeout 10 --max-time 15 -w "\n%{http_code}" \
            "${URL}/api/config/checksum" 2>/dev/null) || true
    fi

    # Split response body and HTTP status code
    CHECKSUM_HTTP=$(echo "${CHECKSUM_RESPONSE}" | tail -n1)
    CHECKSUM_BODY=$(echo "${CHECKSUM_RESPONSE}" | sed '$d')

    echo "DEBUG: Device ${i}: CHECKSUM_HTTP='${CHECKSUM_HTTP}' CHECKSUM_BODY='${CHECKSUM_BODY}'" >> /data/backup_debug.log

    # Detect old software without backup API support
    if [ "${CHECKSUM_HTTP}" = "404" ] || [ "${CHECKSUM_HTTP}" = "000" ] || [ -z "${CHECKSUM_HTTP}" ]; then
        bashio::log.warning "    Device ${NAME} does not support config backup yet (HTTP ${CHECKSUM_HTTP:-no response}). Please update the device software."
        echo "DEBUG: Device ${i}: SKIPPED - old firmware (HTTP ${CHECKSUM_HTTP:-empty})" >> /data/backup_debug.log
        continue
    fi

    REMOTE_SHA=$(echo "${CHECKSUM_BODY}" | jq -r '.sha256 // empty' 2>/dev/null) || true
    LOCAL_SHA=$(cat "${CHECKSUM_DIR}/${SLUG}.sha256" 2>/dev/null) || true

    EXPECTED_FILE="${BACKUP_DIR}/${SLUG}.tar.gz"
    echo "DEBUG: Device ${i}: REMOTE_SHA='${REMOTE_SHA}' LOCAL_SHA='${LOCAL_SHA}' FILE_EXISTS=$([ -f "${EXPECTED_FILE}" ] && echo yes || echo no)" >> /data/backup_debug.log
    if [ -n "${REMOTE_SHA}" ] && [ "${REMOTE_SHA}" = "${LOCAL_SHA}" ] && [ -f "${EXPECTED_FILE}" ]; then
        bashio::log.info "    Config unchanged (SHA256: ${REMOTE_SHA:0:12}...), skipping download"
        echo "DEBUG: Device ${i}: SKIPPED - checksum unchanged and file exists" >> /data/backup_debug.log
        continue
    fi

    # 3. Download config backup
    FILENAME="${SLUG}.tar.gz"
    TARGET_PATH="${BACKUP_DIR}/${FILENAME}"

    echo "DEBUG: Device ${i}: REMOTE_SHA='${REMOTE_SHA}' LOCAL_SHA='${LOCAL_SHA}' AUTH_HEADER='${AUTH_HEADER}'" >> /data/backup_debug.log
    echo "DEBUG: Device ${i}: about to download from ${URL}/api/config/download to ${TARGET_PATH}" >> /data/backup_debug.log

    if [ -n "${AUTH_HEADER}" ]; then
        HTTP_CODE=$(curl -sk --connect-timeout 10 --max-time 120 \
            -o "${TARGET_PATH}" -w "%{http_code}" \
            -H "${AUTH_HEADER}" "${URL}/api/config/download" 2>/dev/null) || true
    else
        HTTP_CODE=$(curl -sk --connect-timeout 10 --max-time 120 \
            -o "${TARGET_PATH}" -w "%{http_code}" \
            "${URL}/api/config/download" 2>/dev/null) || true
    fi

    echo "DEBUG: Device ${i}: DOWNLOAD HTTP_CODE='${HTTP_CODE}' TARGET='${TARGET_PATH}'" >> /data/backup_debug.log

    if [ "${HTTP_CODE}" = "200" ]; then
        # Save checksum for deduplication on next run
        if [ -n "${REMOTE_SHA}" ]; then
            echo "${REMOTE_SHA}" > "${CHECKSUM_DIR}/${SLUG}.sha256"
        fi
        FILE_SIZE=$(stat -c%s "${TARGET_PATH}" 2>/dev/null || echo "unknown")
        bashio::log.info "    Backup saved: ${FILENAME} (${FILE_SIZE} bytes)"
    else
        bashio::log.warning "    Failed to backup ${NAME} (HTTP ${HTTP_CODE:-000})"
        rm -f "${TARGET_PATH}"
        FAILED=$((FAILED + 1))
    fi
done

if [ "${FAILED}" -gt 0 ]; then
    bashio::log.warning "Backup pre-hook completed with ${FAILED} failed device(s)"
else
    bashio::log.info "Backup pre-hook completed successfully"
fi

# Always exit 0 — device backup failures must not block HA backup
exit 0
