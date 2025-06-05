# Using nginx because it has openssl pre-installed
FROM nginx:latest

COPY compress_and_encrypt.sh /compress_and_encrypt.sh
COPY decrypt_and_decompress.sh /decrypt_and_decompress.sh
RUN chmod +x /compress_and_encrypt.sh
RUN chmod +x /decrypt_and_decompress.sh