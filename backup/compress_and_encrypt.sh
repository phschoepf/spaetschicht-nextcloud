#!/bin/sh

VOLUME=$1
PUBKEY_FILE="/backup-public.pem"
BACKUP_FILE="$VOLUME.tar.gz.enc"
echo "Starting backup for volume: $VOLUME"

# Generate a random symmetric key
SYMKEY=$(openssl rand -base64 32) && \

# Encrypt the symmetric key with the public RSA key
echo $SYMKEY | openssl pkeyutl -encrypt -pubin -inkey $PUBKEY_FILE -out "/backup/$VOLUME.key.enc" && \

# Compress the volume and encrypt it with the symmetric key
tar czf - -C $VOLUME . | openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:"$SYMKEY" -out "/backup/$BACKUP_FILE"
