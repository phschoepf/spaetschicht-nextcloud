#!/bin/sh

VOLUME=$1
PUBKEY_FILE="/backup-public.pem"
BACKUP_FILE="$VOLUME.tar.gz.enc"
echo "Starting backup for volume: $VOLUME"

# Generate a random symmetric key
openssl rand -base64 32 > /data_encryption_key && \

# Encrypt the symmetric key with the public RSA key
openssl pkeyutl -encrypt -pubin -inkey $PUBKEY_FILE -in "/data_encryption_key" -out "/backup/$VOLUME.key.enc" && \

# Compress the volume and encrypt it with the symmetric key
tar czf - -C $VOLUME . | openssl enc -aes-256-cbc -pbkdf2 -salt -pass file:/data_encryption_key -out "/backup/$BACKUP_FILE"
