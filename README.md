# Spätschicht Nextcloud Setup on Hetzner

*Forked from https://github.com/phschoepf/pembau-nextcloud on 2026-01-28*

## Infrastructure
* CX22 instance (2 vCPU, 4GB RAM) in Falkenstein locoation
* Debian 12
* Add public IPv4 address
* Add SSH key
* Firewall: allow `tcp:22,80,443`, `icmp`

## Setup
### DNS
In order for the Let's Encrypt auto-setup to work, you need to have a public domain, not only an IP. Set up a *two* DNS A records at your DNS provider pointing to your server's public IP. One will point to the Nextcloud instance, the other to the Collabora Online server for Nextcloud Office.
We will use `nextcloud.spaetschicht.art`  for Nextcloud, and `collabora.nextcloud.spaetschicht.art` for Collabora Online.

### Set up Docker prerequisites
1. SSH into the instance using the SSH identity whose public key we registered at VM creation: `ssh root@<external_ip> -i ~/.ssh/<private_key>`
2. Update the installed packages: `apt update && apt upgrade -y`
3. Install docker using the official docs: https://docs.docker.com/engine/install/debian/#install-using-the-repository
4. Configure Docker logging: create a file `/etc/docker/daemon.json` with the following content:

```json
{
  "log-driver": "local"
}
```

5. Restart the Docker service: `systemctl restart docker`

### Drop root privileges
1. Set a strong root password: `sudo passwd`
2. Create a new user: `adduser dockeruser --disabled-password --gecos ""`
3. Add the user to the `docker` group: `usermod -aG docker dockeruser`
4. Copy root's SSH public key to the new user: `mkdir /home/dockeruser/.ssh && cp ~/.ssh/authorized_keys /home/dockeruser/.ssh/ && chown -R dockeruser:dockeruser /home/dockeruser/.ssh`
5. Exit the root session and reconnect as the new user: `ssh dockeruser@<external_ip> -i ~/.ssh/<private_key>`
6. Get root privileges with `su` and the root password
7. As the root user, disable root SSH login: `nano /etc/ssh/sshd_config` and set `PermitRootLogin no`, `PasswordAuthentication no`, and comment out `Subsystem sftp /usr/lib/openssh/sftp-server`
8. Restart SSH service: `systemctl restart sshd`

Trying to log in with `ssh root@<external_ip> -i ~/.ssh/<private_key>` should now fail.

### Install Nextcloud
1. Create a directory for the Nextcloud setup: `mkdir nextcloud && cd nextcloud`
2. From the local machine, copy all files from this repo into the directory using `scp -r <path_to_repo>/* dockeruser@<external_ip>:~/nextcloud/`
3. Create files `creds/db_root`, `creds/db_user`, `creds/nc_admin` with credentials for the MySQL root user, the Nextcloud MySQL user, and the Nextcloud admin user, respectively. The files should each contain a single line with the password. You can e.g. use `openssl rand -base64 32 > creds/db_root` to generate a random password.
4. Protect the credentials: `chmod 600 creds/*`
5. Run `docker compose up --build -d` to start the Nextcloud service. The first startup will take a few minutes.

The Nextcloud Web UI should now be reachable at the VM's external IP (`http://<external_ip>`).
You can log in with the username `admin` and the password from the `creds/nc_admin` file.

## After Setup
### Secure the admin account
1. Add a 2FA method to the admin account in the Nextcloud Web UI
2. Disable the profile in the Nextcloud Web UI

### Customize config
Most config will be set in the `var/www/html/config/config.php` file. To edit it, open a terminal in the Nextcloud container: `docker exec -it -u www-data nextcloud-app-1 /bin/bash`. 
Then use `php occ config:system:set ...` to set the config values. Some recommended changes:

* Always use HTTPS: `php occ config:system:set overwriteprotocol --value=https`
* Set overwrite.cli.url to the public URL: `php occ config:system:set overwrite.cli.url --value=https://nextcloud.spaetschicht.art`
* Configure trusted proxies: `php occ config:system:set trusted_proxies 0 --value=172.16.0.0/12` (adds local proxies to the trusted list)
* Disable demo/template files for new users: `php occ config:system:set skeletondirectory --value=""`
* Configure a maintenance window for cronjobs: `php occ config:system:set maintenance_window_start --type=integer --value=1`
* Set a default phone region: `php occ config:system:set default_phone_region --value=AT`
* Migrate MIME types to the new format: `php occ maintenance:repair --include-expensive`
* Add optional DB indexes: `php occ db:add-missing-indices`

### Set up Collabora Online
1. Add the Nextcloud Office app from the app list in the Nextcloud Web UI.
2. In Administration Settings -> Office, select "Use your own server" and set the  URL to `collabora.nextcloud.spaetschicht.art` (the VIRTUAL_HOST from the `docker-compose.yml` file).
3. Restrict WOPI (Nextcloud Office protocol) access to servers in the local network: `php occ config:app:set richdocuments wopi_allowlist --value=172.16.0.0/12`


# Migration (2025-02-27)
1. Download all files (cloud.zip, database.zip, config.zip) from the Hetzner Export to a local machine
2. Copy the files to the new host via `scp`: `scp -r cloud.zip database.zip config.zip dockeruser@<new_ip>:~/nextcloud/migration/`
3. Check the SHA256 checksums of the files on the new host
4. Put the new Nextcloud instance into maintenance mode: `docker exec -itu www-data nextcloud-app-1 php occ maintenance:mode --on`

## Recreate the database
1. Extract the `database.zip` file on the new host: `unzip migration/database.zip`
2. Drop the existing database and create a new, empty database. Then import the backup file.

```bash
docker exec -i nextcloud-db-1 mysql -u nextcloud -p[db_user_pw] -e "DROP DATABASE nextcloud"
docker exec -i nextcloud-db-1 mysql -u nextcloud -p[db_user_pw] -e "CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"
(docker exec -i nextcloud-db-1 mysql -u nextcloud -p[db_user_pw] nextcloud) < backup.sql
```

## Add the files
We will create a `html` folder on the host machine and bind the Nextcloud container's `var/www/html` directory to it. This way, we can copy the files directly to the host machine and then use them in the container.

1. Extract the `cloud.zip` and `config.zip` files on the new host, and change the owner to `www-data`. We add our user to the `www-data` group to be able to access the files, and set write permissions for the `config` folder.
```bash
su
unzip migration/cloud.zip -d html
unzip migration/config.zip -d html/config
chown -R www-data:www-data html
chmod 775 html/config
chmod 664 html/config/*
adduser dockeruser www-data
```

2. Move the existing Docker volume to a backup location to free up the volume name.

```bash
su
docker volume create nextcloud-nextcloud-old
rm -r /var/lib/docker/volumes/nextcloud-nextcloud-old/_data
mv /var/lib/docker/volumes/nextcloud-nextcloud/_data /var/lib/docker/volumes/nextcloud-nextcloud-old/_data
docker volume rm nextcloud-nextcloud
```

3. Bind the `html` folder to the Nextcloud volume in Docker Compose. Add the following to the `compose.yml` file:

```yaml
volumes:
  nextcloud:
    driver: local
    driver_opts:
      type: none
      device: /home/dockeruser/nextcloud/html
      o: bind
```

## Adapt the configuration
1. Make sure the Docker version matches the one on the old host. Check the version in the `html/version.php` file, and adapt the `compose.yaml` file to pull the appropriate version (e.g. `nextcloud:29.0.9-apache`).
2. In the `html/config/config.php` file, change the credentials and location (host/port) of the database and the Redis server.
3. Start the Nextcloud container with the new volume: `docker-compose up -d`. Check if you can log in using the credentials from the old deployment.
4. Set up Collabora Online as described above again
5. Customize the config as described above again

## Change the hostname
1. Add an A record for both the Nextcloud and Collabora Online hostnames under a new domain
2. Remove the old A records
3. Change all occurrences of the old hostname in the `compose.yaml` file to the new hostname
4. Restart the Nextcloud container to regenerate the Let's Encrypt certificates: `docker-compose restart`

(Tip: You can add a user to the admin group temporarily to access the admin settings in the Web UI: `docker exec -itu www-data nextcloud-app-1 php occ group:adduser admin <username>`)
