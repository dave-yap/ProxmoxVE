#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: dave-yap
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies (Patience)"
$STD apt-get install -y \
    curl \
    ca-certificates \
    wget \
    sed
msg_ok "Installed Dependecies"

msg_info "Installing Postgresql"
$STD apt-get install -y postgresql postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
DB_NAME="zitadel"
DB_USER="zitadel"
DB_PASS="zitadel"
{
    echo "Application Credentials"
    echo "DB_NAME: $DB_NAME"
    echo "DB_USER: $DB_USER"
    echo "DB_PASS: $DB_PASS"
} >> ~/zitadel.creds
systemctl enable -q --now postgresql
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
sudo -u postgres psql -c "ALTER USER $DB_USER WITH SUPERUSER;"
msg_ok "Installed PostgreSQL"

msg_info "Installing Zitadel"
LATEST=$(curl -i https://github.com/zitadel/zitadel/releases/latest | grep location: | cut -d '/' -f 8 | tr -d '\r')
ARCH=$(uname -m)
case $ARCH in
    armv5*) ARCH="armv5";;
    armv6*) ARCH="armv6";;
    armv7*) ARCH="arm";;
    aarch64) ARCH="arm64";;
    x86) ARCH="386";;
    x86_64) ARCH="amd64";;
    i686) ARCH="386";;
    i386) ARCH="386";;
esac
wget -c https://github.com/zitadel/zitadel/releases/download/$LATEST/zitadel-linux-$ARCH.tar.gz -O - | tar -xz
mv zitadel-linux-$ARCH/zitadel /usr/local/bin
rm -rf zitadel-linux-$ARCH
msg_ok "Installed Zitadel"

msg_info "Setting up Zitadel Environments"
mkdir -p /opt/zitadel
echo "/opt/zitadel/config.yaml" > "/opt/zitadel/.config"
echo "$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c32)" > "/opt/zitadel/.masterkey"
{
    echo "Config location: $(cat "/opt/zitadel/.config")"
    echo "Masterkey: $(cat "/opt/zitadel/.masterkey")"
} >> ~/zitadel.creds
#wget -c https://raw.githubusercontent.com/zitadel/zitadel/refs/heads/main/cmd/defaults.yaml -O /opt/zitadel/config.yaml
#sed -i '0,/ExternalDomain: localhost/s//ExternalDomain: ${IP}/' /opt/zitadel/config.yaml
#sed -i '0,/Enabled: True/s//Enabled: False/' /opt/zitadel/config.yaml
#sed -i '1,/Host: /s//Host: localhost/'
#sed -i '1,/Port: /s//Port: 5432/'
#sed -i '2,/Username: /s//Username: zitadel/'
#sed -i '2,/Password: /s//Password: zitadel/'
#sed -i '2,/Mode: /s//Mode: disable/'
cat <<EOF >/opt/zitadel/config.yaml
Port: 8080
ExternalPort: 8080
ExternalDomain: localhost
ExternalSecure: false
TLS:
  Enabled: false
  KeyPath: ""
  Key: ""
  CertPath: ""
  Cert: ""

Database:
  postgres:
    Host: localhost
    Port: 5432
    Database: zitadel
    User:
      Username: zitadel
      Password: zitadel
      SSL:
        Mode: disable
        RootCert: ""
        Cert: ""
        Key: ""
    Admin:
      Username: root
      Password: postgres
      SSL:
        Mode: disable
        RootCert: ""
        Cert: ""
        Key: ""
EOF
IP=$(ip a s dev eth0 | awk '/inet / {print $2}' | cut -d/ -f1)
sed -i "0,/localhost/s/localhost/${IP}/" /opt/zitadel/config.yaml
msg_ok "Installed Zitadel Enviroments"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/zitadel.service
[Unit]
Description=ZITADEL Identiy Server
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=zitadel
Group=zitadel
ExecStart=/usr/local/bin/zitadel start --masterkey "$(cat /opt/zitadel/.masterkey)" --config "$(cat /opt/zitadel/.config)"
Restart=always
RestartSec=5
TimeoutStartSec=0

# Security Hardening options
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q zitadel.service
msg_ok "Created Services"

msg_info "Start up Zitadel initial setup"
zitadel start-from-init --masterkeyFile /opt/zitadel/.masterkey --config /opt/zitadel/config.yaml
msg_ok "Zitadel started"

motd_ssh
customize

msg_info "Cleaning up"
rm -rf /opt/zitadel/zitadel-linux-$ARCH
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"