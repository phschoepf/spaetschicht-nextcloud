FROM collabora/code:24.04.13.3.1

# Replace the default config with our custom one
COPY coolwsd.xml /etc/coolwsd/coolwsd.xml

# Fix ownership of the systemplate directory so it can be written by the jails at runtime
USER root
RUN chown -R cool:cool /opt/cool/systemplate
# Set the admin console password
RUN --mount=type=secret,id=collabora_admin,target=/run/secrets/collabora_admin \
     coolconfig set-admin-password --user=admin --password=$(cat /run/secrets/collabora_admin)
USER cool