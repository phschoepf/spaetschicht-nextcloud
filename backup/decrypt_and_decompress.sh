#!/bin/sh

VOLUME=$1
PRIVATE_KEY_FILE="/backup-private.pem"
BACKUP_FILE="$VOLUME.tar.gz.enc"
echo "Starting restoring volume: $VOLUME"

# Decrypt the symmetric key
SYMKEY=$(openssl pkeyutl -decrypt -inkey $PRIVATE_KEY_FILE -in "/backup/$VOLUME.key.enc") && \

# Decrypt the backup using the symmetric key
openssl enc -d -aes-256-cbc -pbkdf2 -pass pass:"$SYMKEY" -in "/backup/$BACKUP_FILE" | tar xzf - -C "/$VOLUME"
