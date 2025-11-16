#!/bin/bash
# Backup Docker volumes, xz compress them, and upload to Google Cloud Storage using gsutil and service account
set -euo pipefail

SERVICE_ACCOUNT_JSON="$(dirname "$(realpath $0)")/google-application-credentials.json"
BACKUP_DIR="/tmp/docker_volume_backups"
GCS_BUCKET="gs://nextcloud-pembau-art-backup"

mkdir -p "$BACKUP_DIR"

# Use a alpine container to mount and compress each Docker volume
# Write the backup to a tgz file on the host
VOLUMES=$(docker volume ls -q)
for VOLUME in $VOLUMES; do
    BACKUP_FILE="$VOLUME.tar.gz"
    docker run --rm -v "$VOLUME:/volume:ro" -v "$BACKUP_DIR:/backup" alpine sh -c "cd /volume && tar czf /backup/${BACKUP_FILE} ."
    SIZE=$(du -sh "$BACKUP_DIR/${BACKUP_FILE}" | cut -f1)
    echo "Compressed volume $VOLUME to $BACKUP_DIR/${BACKUP_FILE} (size: $SIZE)"
done

# Upload with gsutil, using the service account
echo "Uploading backups to $GCS_BUCKET"
docker run --rm \
  -v "$SERVICE_ACCOUNT_JSON:/service_account.json" \
  -v "$BACKUP_DIR:/backup" \
  -e GOOGLE_APPLICATION_CREDENTIALS="/service_account.json" \
  google/cloud-sdk:stable sh -c "gcloud auth activate-service-account --key-file=/service_account.json && gcloud storage cp /backup/* \"$GCS_BUCKET/\""

# Cleanup
rm -rf "$BACKUP_DIR"

echo "Backup complete."
