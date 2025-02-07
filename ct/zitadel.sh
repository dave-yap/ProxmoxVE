#!/usr/bin/env bash
#source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
source <(curl -s https://raw.githubusercontent.com/dave-yap/ProxmoxVE/refs/heads/test/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: dave-yap (dave-yap)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://zitadel.com/

# App Default Values
APP="Zitadel"
var_tags="identity-provider"
var_cpu="2"
var_ram="2048"
var_disk="12"
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
    current_version=$(zitadel -v | grep -oP '\d+\.\d+\.\d+')
    if [[ "${current_version} != "$(cat /opt/${APP}_version.txt" ]] || [[ ! -f /opt/${APP}_version.txt ]]; then
        msg_info 'Updating ${APP} (Patience)'
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
        wget -qc https://github.com/zitadel/zitadel/releases/download/$LATEST/zitadel-linux-$ARCH.tar.gz -O -
        tar -xz zitadel-linux-$ARCH.tar.gz
        systemctl stop zitadel.service
        sudo mv zitadel-linux-$ARCH/zitadel /usr/local/bin
        rm -rf zitadel-linux-$ARCH
        MASTERKEY=$(cat /opt/${APP}/.masterkey)
        TLSMODE=$(cat /opt/${APP}/.tlsmode)
        CONFIG=$(cat /opt/${APP}/.config)
        zitadel setup --masterkey ${MASTERKEY} --tlsMode ${TLSMODE} --config ${CONFIG} --init-projections=true
        systemctl start zitadel.service
        echo "v$(current_version)" > /opt/${APP}_version.txt
        msg_ok "Updated ${APP} to v${current_version}"
    else
        msg_ok "No update required. ${APP} is already at v${current_version}"
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