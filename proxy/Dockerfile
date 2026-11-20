FROM nginx:1.31.9-alpine AS nginx-patched
FROM nginxproxy/nginx-proxy:alpine

# nginx binary and dynamic modules must come from the same build to stay ABI compatible
COPY --from=nginx-patched /usr/sbin/nginx /usr/sbin/nginx
COPY --from=nginx-patched /usr/lib/nginx/modules/ /usr/lib/nginx/modules/

COPY uploadsize.conf /etc/nginx/conf.d/uploadsize.conf
