#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/dave-yap/ProxmoxVE/refs/heads/test/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: dave-yap (dave-yap)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://zitadel.com/

# App Default Values
APP="Seafile"
var_tags="documents"
var_cpu="2"
var_ram="2048"
var_disk="20"
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
    if [[ ! -f /etc/systemd/system/seafile.service ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    msg_ok "No upgrade path available now."
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8000${CL}"