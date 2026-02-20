#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Backup pre-hook: download config from all configured Black devices
# Called by HA Supervisor before creating a backup.
#
# For each device:
#   1. Optionally login (if username/password configured) to get JWT token
#   2. Check remote SHA256 checksum (skip download if unchanged)
#   3. Download config archive (.tar.gz) into /backup/boneio-dashboard/
# ==============================================================================

BACKUP_DIR="/backup/boneio-dashboard"
CHECKSUM_DIR="/data/checksums"
mkdir -p "${BACKUP_DIR}" "${CHECKSUM_DIR}"

DEVICE_COUNT=$(bashio::config 'devices | length')
bashio::log.info "Backup pre-hook: processing ${DEVICE_COUNT} device(s)..."

for i in $(seq 0 $((DEVICE_COUNT - 1))); do
    NAME=$(bashio::config "devices[${i}].name")
    URL=$(bashio::config "devices[${i}].url")
    USERNAME=$(bashio::config "devices[${i}].username")
    PASSWORD=$(bashio::config "devices[${i}].password")

    # Strip trailing slash from URL
    URL="${URL%/}"

    SLUG=$(echo "${NAME}" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')

    bashio::log.info "  Device ${i}: ${NAME} (${URL})"

    # 1. Login if credentials are provided
    TOKEN=""
    if [ -n "${USERNAME}" ] && [ -n "${PASSWORD}" ]; then
        bashio::log.info "    Authenticating with username '${USERNAME}'..."
        LOGIN_RESPONSE=$(curl -sk -X POST "${URL}/api/login" \
            -H "Content-Type: application/json" \
            -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\"}" \
            2>/dev/null)

        TOKEN=$(echo "${LOGIN_RESPONSE}" | jq -r '.token // empty' 2>/dev/null)

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
    if [ -n "${AUTH_HEADER}" ]; then
        CHECKSUM_RESPONSE=$(curl -sk -H "${AUTH_HEADER}" "${URL}/api/config/checksum" 2>/dev/null)
    else
        CHECKSUM_RESPONSE=$(curl -sk "${URL}/api/config/checksum" 2>/dev/null)
    fi

    REMOTE_SHA=$(echo "${CHECKSUM_RESPONSE}" | jq -r '.sha256 // empty' 2>/dev/null)
    LOCAL_SHA=$(cat "${CHECKSUM_DIR}/${SLUG}.sha256" 2>/dev/null)

    if [ -n "${REMOTE_SHA}" ] && [ "${REMOTE_SHA}" = "${LOCAL_SHA}" ]; then
        bashio::log.info "    Config unchanged (SHA256: ${REMOTE_SHA:0:12}...), skipping download"
        continue
    fi

    # 3. Download config backup
    FILENAME="${SLUG}_$(date +%Y%m%d_%H%M%S).tar.gz"
    TARGET_PATH="${BACKUP_DIR}/${FILENAME}"

    if [ -n "${AUTH_HEADER}" ]; then
        HTTP_CODE=$(curl -sk -o "${TARGET_PATH}" -w "%{http_code}" \
            -H "${AUTH_HEADER}" "${URL}/api/config/download" 2>/dev/null)
    else
        HTTP_CODE=$(curl -sk -o "${TARGET_PATH}" -w "%{http_code}" \
            "${URL}/api/config/download" 2>/dev/null)
    fi

    if [ "${HTTP_CODE}" = "200" ]; then
        # Save checksum for deduplication on next run
        if [ -n "${REMOTE_SHA}" ]; then
            echo "${REMOTE_SHA}" > "${CHECKSUM_DIR}/${SLUG}.sha256"
        fi
        FILE_SIZE=$(stat -c%s "${TARGET_PATH}" 2>/dev/null || echo "unknown")
        bashio::log.info "    Backup saved: ${FILENAME} (${FILE_SIZE} bytes)"
    else
        bashio::log.error "    Failed to backup ${NAME} (HTTP ${HTTP_CODE})"
        rm -f "${TARGET_PATH}"
    fi
done

bashio::log.info "Backup pre-hook completed"
