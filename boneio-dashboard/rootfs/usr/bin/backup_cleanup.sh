#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Backup post-hook: clean up temporary backup files from /data/backup/
# Called by HA Supervisor after creating a backup.
#
# The backup archive already contains /data/backup/ contents, so we can
# safely remove them to avoid wasting disk space between backups.
# ==============================================================================

set +e

BACKUP_DIR="/data/backup"

if [ -d "${BACKUP_DIR}" ]; then
    FILE_COUNT=$(find "${BACKUP_DIR}" -type f | wc -l)
    if [ "${FILE_COUNT}" -gt 0 ]; then
        bashio::log.info "Backup post-hook: cleaning up ${FILE_COUNT} temporary backup file(s)..."
        rm -rf "${BACKUP_DIR:?}"/*
        bashio::log.info "Backup post-hook: cleanup done"
    else
        bashio::log.info "Backup post-hook: nothing to clean up"
    fi
fi

exit 0
