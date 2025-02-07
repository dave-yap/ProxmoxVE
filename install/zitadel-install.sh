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
$STD apt-get install -y postgresql postgresql-contrib
DB_NAME="zitadel"
DB_USER="zitadel"
DB_PASS="$(openssl rand -base64 18 | cut -c1-13)"
{
    echo "Application Credentials"
    echo "DB_NAME: $DB_NAME"
    echo "DB_USER: $DB_USER"
    echo "DB_PASS: $DB_PASS"
} >> ~/zitadel.creds
sudo systemctl enable -q --now postgresql
#$STD sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
#$STD sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
#$STD sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
#$STD sudo -u postgres psql -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"
#$STD sudo -u postgres psql -c "ALTER USER $DB_USER WITH SUPERUSER;"
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
wget -c https://github.com/zitadel/zitadel/releases/download/$LATEST/zitadel-linux-$ARCH.tar.gz -O -
tar -xz zitadel-linux-$ARCH.tar.gz
sudo mv zitadel-linux-$ARCH/zitadel /usr/local/bin
rm -rf zitadel-linux-$ARCH
msg_ok "Installed Zitadel"

msg_info "Setting up Zitadel Environments"
echo "/opt/zitadel/config.yaml" > "/opt/zitadel/.config"
echo "disabled" > "/opt/zitadel/.tlsmode"
echo "$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c32)" > "/opt/zitadel/.masterkey"
{
    echo "Config location: $(cat "/opt/zitadel/.config)"
    echo "TLS Mode: $(cat "/opt/zitadel/.tlsmode)"
    echo "Masterkey: $(cat "/opt/zitadel/.masterkey)"
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
Port: 8080 # ZITADEL_PORT
# ExternalPort is the port on which end users access ZITADEL.
# It can differ from Port e.g. if a reverse proxy forwards the traffic to ZITADEL
# Read more about external access: https://zitadel.com/docs/self-hosting/manage/custom-domain
ExternalPort: 8080 # ZITADEL_EXTERNALPORT
# ExternalDomain is the domain on which end users access ZITADEL.
# Read more about external access: https://zitadel.com/docs/self-hosting/manage/custom-domain
ExternalDomain: localhost # ZITADEL_EXTERNALDOMAIN
# ExternalSecure specifies if ZITADEL is exposed externally using HTTPS or HTTP.
# Read more about external access: https://zitadel.com/docs/self-hosting/manage/custom-domain
ExternalSecure: true # ZITADEL_EXTERNALSECURE
TLS:
  # If enabled, ZITADEL will serve all traffic over TLS (HTTPS and gRPC)
  # you must then also provide a private key and certificate to be used for the connection
  # either directly or by a path to the corresponding file
  Enabled: true # ZITADEL_TLS_ENABLED
  # Path to the private key of the TLS certificate, will be loaded into the key
  # and overwrite any existing value
  # E.g. /path/to/key/file.pem
  KeyPath: # ZITADEL_TLS_KEYPATH
  # Private key of the TLS certificate (KeyPath has a higher priority than Key)
  # base64 encoded content of a pem file
  Key: # ZITADEL_TLS_KEY
  # Path to the certificate for the TLS connection, will be loaded into the Cert
  # and overwrite any existing value
  # E.g. /path/to/cert/file.pem
  CertPath: # ZITADEL_TLS_CERTPATH
  # Certificate for the TLS connection (CertPath will this overwrite if specified)
  # base64 encoded content of a pem file
  Cert: # ZITADEL_TLS_CERT

Database: #Using Postgresql instead
  # CockroachDB is the default database of ZITADEL
  #cockroach:
    #Host: localhost # ZITADEL_DATABASE_COCKROACH_HOST
    #Port: 26257 # ZITADEL_DATABASE_COCKROACH_PORT
    #Database: zitadel # ZITADEL_DATABASE_COCKROACH_DATABASE
    #MaxOpenConns: 5 # ZITADEL_DATABASE_COCKROACH_MAXOPENCONNS
    #MaxIdleConns: 2 # ZITADEL_DATABASE_COCKROACH_MAXIDLECONNS
    #MaxConnLifetime: 30m # ZITADEL_DATABASE_COCKROACH_MAXCONNLIFETIME
    #MaxConnIdleTime: 5m # ZITADEL_DATABASE_COCKROACH_MAXCONNIDLETIME
    #Options: "" # ZITADEL_DATABASE_COCKROACH_OPTIONS
    #User:
      #Username: zitadel # ZITADEL_DATABASE_COCKROACH_USER_USERNAME
      #Password: "" # ZITADEL_DATABASE_COCKROACH_USER_PASSWORD
      #SSL:
        #Mode: disable # ZITADEL_DATABASE_COCKROACH_USER_SSL_MODE
        #RootCert: "" # ZITADEL_DATABASE_COCKROACH_USER_SSL_ROOTCERT
        #Cert: "" # ZITADEL_DATABASE_COCKROACH_USER_SSL_CERT
        #Key: "" # ZITADEL_DATABASE_COCKROACH_USER_SSL_KEY
    #Admin:
      # By default, ExistingDatabase is not specified in the connection string
      # If the connection resolves to a database that is not existing in your system, configure an existing one here
      # It is used in zitadel init to connect to cockroach and create a dedicated database for ZITADEL.
      #ExistingDatabase: # ZITADEL_DATABASE_COCKROACH_ADMIN_EXISTINGDATABASE
      #Username: root # ZITADEL_DATABASE_COCKROACH_ADMIN_USERNAME
      #Password: "" # ZITADEL_DATABASE_COCKROACH_ADMIN_PASSWORD
      #SSL:
        #Mode: disable # ZITADEL_DATABASE_COCKROACH_ADMIN_SSL_MODE
        #RootCert: "" # ZITADEL_DATABASE_COCKROACH_ADMIN_SSL_ROOTCERT
        #Cert: "" # ZITADEL_DATABASE_COCKROACH_ADMIN_SSL_CERT
        #Key: "" # ZITADEL_DATABASE_COCKROACH_ADMIN_SSL_KEY
  # Postgres is used as soon as a value is set
  # The values describe the possible fields to set values
  postgres:
    Host: localhost# ZITADEL_DATABASE_POSTGRES_HOST
    Port: 5432# ZITADEL_DATABASE_POSTGRES_PORT
    Database: zitadel# ZITADEL_DATABASE_POSTGRES_DATABASE
    #MaxOpenConns: # ZITADEL_DATABASE_POSTGRES_MAXOPENCONNS
    #MaxIdleConns: # ZITADEL_DATABASE_POSTGRES_MAXIDLECONNS
    #MaxConnLifetime: # ZITADEL_DATABASE_POSTGRES_MAXCONNLIFETIME
    #MaxConnIdleTime: # ZITADEL_DATABASE_POSTGRES_MAXCONNIDLETIME
    Options: # ZITADEL_DATABASE_POSTGRES_OPTIONS
    User:
      Username: zitadel# ZITADEL_DATABASE_POSTGRES_USER_USERNAME
      Password: zitadel# ZITADEL_DATABASE_POSTGRES_USER_PASSWORD
      SSL:
        Mode: disable# ZITADEL_DATABASE_POSTGRES_USER_SSL_MODE
        RootCert: ""# ZITADEL_DATABASE_POSTGRES_USER_SSL_ROOTCERT
        Cert: ""# ZITADEL_DATABASE_POSTGRES_USER_SSL_CERT
        Key: ""# ZITADEL_DATABASE_POSTGRES_USER_SSL_KEY
    Admin:
      # The default ExistingDatabase is postgres
      # If your db system doesn't have a database named postgres, configure an existing database here
      # It is used in zitadel init to connect to postgres and create a dedicated database for ZITADEL.
      ExistingDatabase: zitadel# ZITADEL_DATABASE_POSTGRES_ADMIN_EXISTINGDATABASE
      Username: zitadel# ZITADEL_DATABASE_POSTGRES_ADMIN_USERNAME
      Password: zitadel# ZITADEL_DATABASE_POSTGRES_ADMIN_PASSWORD
      SSL:
        Mode: disable# ZITADEL_DATABASE_POSTGRES_ADMIN_SSL_MODE
        RootCert: ""# ZITADEL_DATABASE_POSTGRES_ADMIN_SSL_ROOTCERT
        Cert: ""# ZITADEL_DATABASE_POSTGRES_ADMIN_SSL_CERT
        Key: ""# ZITADEL_DATABASE_POSTGRES_ADMIN_SSL_KEY
EOF
#sed -i '0,localhost//s/\${IP}/' /opt/zitadel/config.yaml
msg_info "Change the ExternalDomain value to your domain/hostname/IP"
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
ExecStart=/usr/local/bin/zitadel start --masterkey "$(cat /opt/zitadel/.masterkey)" --tlsMode "$(cat /opt/zitadel/.tlsmode)" --config "$(cat /opt/zitadel/.config)"
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
sudo systemctl enable -q --now zitadel.service
msg_ok "Created Services"

motd_ssh
customize

msg_info "Cleaning up"
rm -rf /opt/zitadel/zitadel-linux-$ARCH
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"