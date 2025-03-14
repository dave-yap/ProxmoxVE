#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/dave-yap/ProxmoxVE/refs/heads/test/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: dave-yap (dave-yap)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://seafile.com/

APP="Seafile"
var_tags="documents"
var_cpu="2"
var_ram="2048"
var_disk="20"
var_os="debian"
var_version="12"
var_unprivileged="1"

header_info "$APP"
base_settings

variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources
    if [[ ! -f /etc/systemd/system/seafile.service ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    RELEASE=$(curl -Ls "https://www.seafile.com/en/download/" | grep -oP 'seafile-server_\K[0-9]+\.[0-9]+\.[0-9]+(?=_.*\.tar\.gz)' | head -1)
    if [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt | grep -oP '\d+\.\d+\.\d+')" ]] || [[ ! -f /opt/${APP}_version.txt ]]; then
        msg_info "Stopping $APP"
        systemctl stop seafile
        msg_ok "Stopped $APP"

        msg_info "Making sure new dependencies are installed"
        $STD apt-get install -y \
            default-libmysqlclient-dev \
            build-essential \
            libsasl2-dev \
            pkg-config \
            libmemcached-dev \
            pwgen
        $STD pip3 install \
            future \
            mysqlclient \
            pillow \
            sqlalchemy \
            pillow_heif \
            gevent \
            captcha \
            django_simple_captcha \
            djangosaml2 \
            pysaml2 \
            pycryptodome \
            cffi \
            python-ldap
        msg_ok "New dependencies installed"

        msg_info "Updating $APP to ${RELEASE}"
        cd /tmp
        $STD su - seafile -c "wget -qc https://s3.eu-central-1.amazonaws.com/download.seadrive.org/seafile-server_${RELEASE}_x86-64.tar.gz"
        $STD su - seafile -c "tar -xzf seafile-server_${RELEASE}_x86-64.tar.gz -C /opt/seafile/"
        $STD su - seafile -c "expect <<EOF
        spawn bash /opt/seafile/seafile-server-${RELEASE}/upgrade/upgrade_11.0_12.0.sh
        expect {
            \"ENTER\" {
            send \"\r\"
            }
        }
        expect eof
        EOF"
        CCNET_DB=$(grep "CCNET_DB:" ~/seafile.creds | cut -d ":" -f2 | tr -d ' ')
        SEAFILE_DB=$(grep "SEAFILE_DB:" ~/seafile.creds | cut -d ":" -f2 | tr -d ' ')
        SEAHUB_DB=$(grep "SEAHUB_DB:" ~/seafile.creds | cut -d ":" -f2 | tr -d ' ')
        DB_USER=$(grep "DB_USER:" ~/seafile.creds | cut -d ":" -f2 | tr -d ' ')
        DB_PASS=$(grep "DB_PASS:" ~/seafile.creds | cut -d ":" -f2 | tr -d ' ')
        SEAFILE_SERVER_PROTOCOL=$(grep "SERVICE_URL =" /opt/seafile/conf/seahub_settings.py | sed -E 's/SERVICE_URL = "(.*)"/\1/' |  grep -o "^[^:]\+")
        SEAFILE_SERVER_HOSTNAME=$(grep "SERVICE_URL =" /opt/seafile/conf/seahub_settings.py | sed -E 's/SERVICE_URL = "(.*)"/\1/' | sed -e 's|^[^:]\+://||' -e 's|/.*$||')
        JWT_PRIVATE_KEY=$(grep "JWT_PRIVATE_KEY:" ~/seafile.creds | cut -d ":" -f2 | tr -d ' ')
        echo "TIME_ZONE=UTC" > /opt/seafile/conf/.env
        echo "JWT_PRIVATE_KEY=${JWT_PRIVATE_KEY}" >> /opt/seafile/conf/.env
        echo "SEAFILE_SERVER_PROTOCOL=$SEAFILE_SERVER_PROTOCOL" >> /opt/seafile/conf/.env
        echo "SEAFILE_SERVER_HOSTNAME=$SEAFILE_SERVER_HOSTNAME" >> /opt/seafile/conf/.env
        echo "SEAFILE_MYSQL_DB_HOST=127.0.0.1" >> /opt/seafile/conf/.env
        echo "SEAFILE_MYSQL_DB_PORT=3306" >> /opt/seafile/conf/.env
        echo "SEAFILE_MYSQL_DB_USER=${DB_USER}" >> /opt/seafile/conf/.env
        echo "SEAFILE_MYSQL_DB_PASSWORD=${DB_PASS}" >> /opt/seafile/conf/.env
        echo "SEAFILE_MYSQL_DB_CCNET_DB_NAME=${CCNET_DB}" >> /opt/seafile/conf/.env
        echo "SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=${SEAFILE_DB}" >> /opt/seafile/conf/.env
        echo "SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=${SEAHUB_DB}" >> /opt/seafile/conf/.env
        echo "${RELEASE}" > /opt/${APP}_version.txt
        msg_ok "Updated $APP to ${RELEASE}"

        msg_info "Starting $APP"
        systemctl start seafile
        msg_ok "Started $APP"

        msg_info "Cleaning Up"
        rm -rf /tmp/seafile-server_${RELEASE}_x86-64.tar.gz
        msg_ok "Cleanup completed"
        msg_ok "Update Successful"
    else
        msg_ok "No update required. ${APP} is already at ${RELEASE}"
    fi
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8000${CL}"