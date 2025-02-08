FROM nextcloud:apache

# Install ffmpeg, ghostscript, imagemagick and libreoffice
RUN set -ex; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        ghostscript \
        libmagickcore-6.q16-6-extra \
        libreoffice \
    ; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*
