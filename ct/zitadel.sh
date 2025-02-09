#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: dave-yap (dave-yap)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://zitadel.com/

# App Default Values
APP="Zitadel"
var_tags="identity-provider"
var_cpu="1"
var_ram="1024"
var_disk="8"
var_os="debian"
var_version="12"
var_unprivileged="1"

# App Output & Base Settings
header_info "$APP"
base_settings

# Core
variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources
    if [[ ! -f /etc/systemd/system/zitadel.service ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    RELEASE=$(curl -si https://github.com/zitadel/zitadel/releases/latest | grep location: | cut -d '/' -f 8 | tr -d '\r')
    if [[ "${RELEASE}" != "$(cat /opt/zitadel_version.txt | grep -oP '\d+\.\d+\.\d+')" ]] || [[ ! -f /opt/zitadel_version.txt ]]; then
        msg_info "Updating ${APP} (Patience)"
        wget -qc https://github.com/zitadel/zitadel/releases/download/$LATEST/zitadel-linux-amd64.tar.gz -O - | tar -xz &>/dev/null
        systemctl stop zitadel.service
        sudo mv zitadel-linux-amd64/zitadel /usr/local/bin
        rm -rf zitadel-linux-amd64
        zitadel setup --masterkeyFile /opt/zitadel/.masterkey --config /opt/zitadel/config.yaml --init-projections=true &>/dev/null
        systemctl start zitadel.service
        echo "v${RELEASE}" > /opt/zitadel_version.txt
        msg_ok "Updated ${APP} to v${RELEASE}"
    else
        msg_ok "No update required. ${APP} is already at v${RELEASE}"
    fi
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080/ui/console${CL}"