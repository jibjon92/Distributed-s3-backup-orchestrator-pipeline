#!/usr/bin/env bash

set -euo pipefail

# --- CONFIGURATION ---
BACKUP_DIR="/opt/backup/staging"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
GPG_PASSPHRASE="YourSuperSecretPassphraseChangeMe" 
S3_BUCKET="s3://ie-homelab-backup-vault-2026"
LOG_FILE="/var/log/homelab_backup.log"

declare -A TARGETS
TARGETS=(
    ["worker1"]="jsamuel@192.168.211.129:/etc /var/www"
    ["worker2"]="jsamuel@192.168.211.130:/etc /var/lib/docker/volumes"
    ["worker3"]="jsamuel@192.168.211.131:/etc /home/jsamuel/app/configs"
)

exec > >(tee -i ${LOG_FILE})
exec 2>&1

echo "========================================="
echo "STARTING BACKUP PIPELINE: ${TIMESTAMP}"
echo "========================================="

cleanup() {
    echo "Cleaning up local staging directory..."
    rm -rf "${BACKUP_DIR}/${TIMESTAMP}"
}

trap cleanup EXIT


mkdir -p "${BACKUP_DIR}/${TIMESTAMP}"


# --- DATA EXTRACTION & COMPRESSION ---
for SERVER in "${!TARGETS[@]}"; do
    SSH_CONN="${TARGETS[$SERVER]%%:*}"
    RAW_PATHS="${TARGETS[$SERVER]#*:}"
    
    echo "Processing ${SERVER}..."
    
    SERVER_STAGE="${BACKUP_DIR}/${TIMESTAMP}/${SERVER}"
    mkdir -p "${SERVER_STAGE}"
    
    read -r -a PATHS_ARRAY <<< "$RAW_PATHS"
    for TARGET_PATH in "${PATHS_ARRAY[@]}"; do
        echo "--> Pulling ${TARGET_PATH} from ${SERVER}..."
        rsync -aR --rsync-path="sudo rsync" -e "ssh -o StrictHostKeyChecking=accept-new" "${SSH_CONN}:${TARGET_PATH}" "${SERVER_STAGE}/"
    done
    
    echo "--> Packaging archive for ${SERVER}..."
    tar -czf "${BACKUP_DIR}/${TIMESTAMP}/${SERVER}_backup.tar.gz" -C "${SERVER_STAGE}" .
    rm -rf "${SERVER_STAGE}"
done


# --- ENCRYPTION & CLOUD UPLOAD ---
echo "Encrypting and uploading backups..."

for ARCHIVE in "${BACKUP_DIR}/${TIMESTAMP}"/*.tar.gz; do
    [ -e "$ARCHIVE" ] || continue
    FILENAME=$(basename "${ARCHIVE}")
    ENCRYPTED_FILE="${ARCHIVE}.gpg"
    
    echo "--> Encrypting ${FILENAME} with AES-256..."
    echo "${GPG_PASSPHRASE}" | gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 -o "${ENCRYPTED_FILE}" "${ARCHIVE}"

    echo "--> Uploading ${FILENAME}.gpg to S3 Vault..."
    aws s3 cp "${ENCRYPTED_FILE}" "${S3_BUCKET}/${TIMESTAMP}/${FILENAME}.gpg"

    rm -f "${ARCHIVE}" "${ENCRYPTED_FILE}"
done

echo "========================================="
echo "BACKUP PIPELINE SUCCESSFUL: $(date +%Y%m%d_%H%M%S)"
echo "========================================="
