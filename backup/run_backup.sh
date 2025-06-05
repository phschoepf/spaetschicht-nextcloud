#!/bin/bash
# Backup Docker volumes, gz compress them, and upload to Google Cloud Storage using gsutil and service account
set -euo pipefail

SERVICE_ACCOUNT_JSON="$(dirname "$(realpath $0)")/google-application-credentials.json"
PUBKEY_FILE="$(dirname "$(realpath $0)")/backup-public.pem"
BACKUP_DIR="/tmp/docker_volume_backups"
GCS_BUCKET="gs://nextcloud-pembau-art-backup"

mkdir -p "$BACKUP_DIR"

# Use a container to mount and compress each Docker volume
# Write the backup to a tgz file on the host
VOLUMES=$(docker volume ls -q)
for VOLUME in $VOLUMES; do
    BACKUP_FILE="$VOLUME.tar.gz.enc"
    # Build the Docker container to compress and encrypt the volume
    CONTAINER_HASH=$(docker build -q $(dirname "$(realpath $0)"))
    docker run --rm -v "$VOLUME:/$VOLUME:ro" -v "$PUBKEY_FILE:/backup-public.pem:ro" -v "$BACKUP_DIR:/backup" $CONTAINER_HASH sh -c "/compress_and_encrypt.sh $VOLUME"
    SIZE=$(du -sh "$BACKUP_DIR/${BACKUP_FILE}" | cut -f1)
    echo "Saved RSA-encrypted symmetric key to $BACKUP_DIR/${VOLUME}.key.enc"
    echo "Compressed and encrypted volume $VOLUME to $BACKUP_DIR/${BACKUP_FILE} (size: $SIZE)"
done

# Upload with gsutil, using the service account
echo "Uploading backups to $GCS_BUCKET"
docker run --rm \
  -v "$SERVICE_ACCOUNT_JSON:/service_account.json:ro" \
  -v "$BACKUP_DIR:/backup:ro" \
  -e GOOGLE_APPLICATION_CREDENTIALS="/service_account.json" \
  google/cloud-sdk:stable sh -c "gcloud auth activate-service-account --key-file=/service_account.json && gcloud storage cp /backup/* \"$GCS_BUCKET/\""

# Cleanup
rm -rf "$BACKUP_DIR"

echo "Backup complete."
