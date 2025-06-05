#!/bin/bash
# Restores encrypted Docker volume backups from Google Cloud Storage using gsutil and service account
set -euo pipefail

SERVICE_ACCOUNT_JSON="$(dirname "$(realpath $0)")/google-application-credentials.json"
PRIVATE_KEY_FILE="$(dirname "$(realpath $0)")/backup-private.pem"
BACKUP_DIR="/tmp/docker_volume_backups"
GCS_BUCKET="gs://nextcloud-pembau-art-backup"

mkdir -p "$BACKUP_DIR"

# Download from Google Cloud Storage
echo "Downloading backups from $GCS_BUCKET"
docker run --rm \
  -v "$SERVICE_ACCOUNT_JSON:/service_account.json:ro" \
  -v "$BACKUP_DIR:/backup" \
  -e GOOGLE_APPLICATION_CREDENTIALS="/service_account.json" \
  google/cloud-sdk:stable sh -c "gcloud auth activate-service-account --key-file=/service_account.json && gcloud storage cp \"$GCS_BUCKET/*\" /backup/"

# Use a container to decrypt and decompress the backups
# Write them to Docker volumes
VOLUMES=$(ls "$BACKUP_DIR" | grep -E '^[^.]+\.tar\.gz\.enc$' | sed 's/\.tar\.gz\.enc$//')
for VOLUME in $VOLUMES; do
    if [ -n "$(docker volume ls -q | grep "^$VOLUME$")" ]; then
        echo "Volume $VOLUME already exists, skipping. Remove it first if you want to restore."
        continue
    fi
    docker volume create "$VOLUME"
    echo "Created empty Docker volume: $VOLUME"
    # Build the Docker container to decrypt and decompress the volume
    CONTAINER_HASH=$(docker build -q $(dirname "$(realpath $0)"))
    docker run --rm -v "$VOLUME:/$VOLUME" -v "$PRIVATE_KEY_FILE:/backup-private.pem:ro" -v "$BACKUP_DIR:/backup:ro" $CONTAINER_HASH sh -c "/decrypt_and_decompress.sh $VOLUME"
    echo "Restored volume $VOLUME from $BACKUP_DIR/${VOLUME}.tar.gz.enc"
done

# Cleanup
rm -rf "$BACKUP_DIR"

echo "Restore complete."
