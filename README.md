# Pembau Nextcloud Setup on Hetzner

## Infrastructure
* CX22 instance (2 vCPU, 4GB RAM) in Falkenstein locoation
* Debian 12
* Add public IPv4 address
* Add SSH key
* Firewall: allow `tcp:22,80,443`, `icmp`

## Setup
SSH into the instance using the SSH identity whose public key we registered at VM creation: `ssh root@<external_ip> -i ~/.ssh/<private_key>`

### Set up Docker prerequisites
1. Update the installed packages: `apt update && apt upgrade -y`
2. Install docker using the official docs: https://docs.docker.com/engine/install/debian/#install-using-the-repository

### Drop root privileges
1. Set a strong root password: `sudo passwd`
2. Create a new user: `adduser dockeruser --disabled-password --gecos ""`
3. Add the user to the `docker` group: `usermod -aG docker dockeruser`
4. Copy root's SSH public key to the new user: `mkdir /home/dockeruser/.ssh && cp ~/.ssh/authorized_keys /home/dockeruser/.ssh/ && chown -R dockeruser:dockeruser /home/dockeruser/.ssh`
5. Exit the root session and reconnect as the new user: `ssh dockeruser@<external_ip> -i ~/.ssh/<private_key>`
6. Get root privileges with `sudo su` and the root password
7. As the root user, disable root SSH login: `nano /etc/ssh/sshd_config` and set `PermitRootLogin no`
8. Restart SSH service: `systemctl restart sshd`

Trying to log in with `ssh root@<external_ip> -i ~/.ssh/<private_key>` should now fail.

### Install Nextcloud
1. Create a directory for the Nextcloud setup: `mkdir nextcloud && cd nextcloud`
2. From the local machine, copy all files from this repo into the directory using `scp -r <path_to_repo>/* dockeruser@<external_ip>:~/nextcloud/`
3. Create files `creds/db_root`, `creds/db_user`, `creds/nc_admin` with credentials for the MySQL root user, the Nextcloud MySQL user, and the Nextcloud admin user, respectively. The files should each contain a single line with the password. You can e.g. use `openssl rand -base64 32 > creds/db_root` to generate a random password.
4. Run `docker compose up -d` to start the Nextcloud service. The first startup will take a few minutes.

The Nextcloud Web UI should now be reachable at the VM's external IP (`http://<external_ip>`).
You can log in with the username `admin` and the password from the `creds/nc_admin` file.
