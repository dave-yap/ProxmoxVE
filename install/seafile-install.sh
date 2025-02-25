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
    sudo \
    mc \
    wget \
    memcached \
    libmemcached-dev \
    python3 \
    python3-dev \
    python3-setuptools \
    python3-pip \
    libmysqlclient-dev \
    ldap-utils \
    libldap2-dev
msg_ok "Installed Dependecies"

msg_info "Installing MariaDB"
$STD apt-get install -y mariadb-server
CCNET_DB="ccnet_db"
SEAFILE_DB="seafile_db"
SEAHUB_DB="seahub_db"
DB_USER="seafile"
DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | cut -c1-13)
DB_ADMIN_USER="root"
DB_ADMIN_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | cut -c1-13)
systemctl start mariadb
sudo -u mysql mysql -s -e "CREATE DATABASE $CCNET_DB CHARACTER SET utf8;"
sudo -u mysql mysql -s -e "CREATE DATABASE $SEAFILE_DB CHARACTER SET utf8;"
sudo -u mysql mysql -s -e "CREATE DATABASE $SEAHUB_DB CHARACTER SET utf8;"
sudo -u mysql mysql -s -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo -u mysql mysql -s -e "GRANT ALL PRIVILEGES ON $CCNET_DB.* TO '$DB_USER'@localhost;"
sudo -u mysql mysql -s -e "GRANT ALL PRIVILEGES ON $SEAFILE_DB.* TO '$DB_USER'@localhost;"
sudo -u mysql mysql -s -e "GRANT ALL PRIVILEGES ON $SEAHUB_DB.* TO '$DB_USER'@localhost;"
{
    echo "Application Credentials"
    echo "CCNET_DB: $CCNET_DB"
    echo "SEAFILE_DB: $SEAFILE_DB"
    echo "SEAHUB_DB: $SEAHUB_DB"
    echo "DB_USER: $DB_USER"
    echo "DB_PASS: $DB_PASS"
    echo "DB_ADMIN_USER: $DB_ADMIN_USER"
    echo "DB_ADMIN_PASS: $DB_ADMIN_PASS"
} >> ~/seafile.creds
msg_ok "Installed MariaDB"

msg_info "Installing Seafile Python Dependecies"
$STD sudo pip3 install --timeout=3600 \
    django==4.2.* \
    future==0.18.* \
    mysqlclient==2.1.* \
    pymysql \
    pillow==10.2.* \
    pylibmc \
    captcha==0.5.* \
    markupsafe==2.0.1 \
    jinja2 \
    sqlalchemy==2.0.18 \
    psd-tools \
    django-pylibmc \
    django_simple_captcha==0.6.* \
    djangosaml2==1.5.* \
    pysaml2==7.2.* \
    pycryptodome==3.16.* \
    cffi==1.15.1 \
    lxml \
    python-ldap==3.4.3
msg_ok "Installed Seafile Python Dependecies"

msg_info "Installing Seafile"
sudo mkdir /opt/seafile
sudo adduser seafile
sudo chown -R seafile: /opt/seafile
wget -qc https://s3.eu-central-1.amazonaws.com/download.seadrive.org/seafile-server_11.0.13_x86-64.tar.gz -O - | tar -xz
cd seafile-server_11.0.13
sudo su seafile
bash setup-seafile-mysql.sh
msg_ok "Installed Seafile"

msg_info "Setting up Memcached"
$STD sudo apt-get install -y \
    memcached \
    libmemcached-dev \
$STD sudo pip3 install --timeout=3600 \
    pylibmc \
    django-pylibmc
systemctl enable --now -q memcached
cat <<EOF >>/opt/seafile/conf/seahub_settings.py
CACHES = {
    'default': {
        'BACKEND': 'django_pylibmc.memcached.PyLibMCCache',
        'LOCATION': '127.0.0.1:11211',
    },
}
EOF
msg_ok "Memcached Started"

msg_info "Adjusting Conf files"
sed -i "0,/127.0.0.1/s/127.0.0.1/127.0.0.1:8000/" /opt/seafile/conf/seahub_settings.py
sed -i "0,/localhost/s/localhost/0.0.0.0/" /opt/seafile/gunicorn.conf.py
msg_ok "Conf files adjusted"

msg_info "Starting Seafile"
cd /opt/seafile/seafile-server-latest
./seafile.sh start
./seahub.sh start
msg_ok "Seafile started"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/seafile.service
[Unit]
Description=Seafile File-hosting
After=network.target mysql.service
Wants=mysql

[Service]
Type=forking
User=seafile
Group=seafile
WorkingDirectory=/opt/seafile

# Start Seafile
ExecStart=/opt/seafile/seafile-server-latest/seafile.sh start

# Start Seahub (web interface)
ExecStartPost=/opt/seafile/seafile-server-latest/seahub.sh start

# Stop Seahub
ExecStop=/opt/seafile/seafile-server-latest/seahub.sh stop

# Stop Seafile
ExecStop=/opt/seafile/seafile-server-latest/seafile.sh stop

Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q seafile.service
msg_ok "Created Services"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"