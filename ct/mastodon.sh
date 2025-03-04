#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/dave-yap/ProxmoxVE/refs/heads/test/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: dave-yap (dave-yap)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://docs.joinmastodon.org/admin/

APP="Mastodon"
var_tags="social-media"
var_cpu="2"
var_ram="4096"
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
    if [[ ! -f /etc/systemd/system/mastodon-web.service ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    RELEASE=$(curl -si https://github.com/mastodon/mastodon/releases/latest | grep location: | cut -d '/' -f 8 | tr -d '\r')
    if [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]] || [[ ! -f /opt/${APP}_version.txt ]]; then
        msg_info "Stopping $APP"
        systemctl stop mastodon-*
        msg_ok "Stopped $APP"

        msg_info "Updating $APP to ${RELEASE}"
        $STD su - mastodon -c 'bash' << EOF
        cd /tmp
        wget -qc https://github.com/mastodon/mastodon/archive/refs/tags/$RELEASE.tar.gz -O - | tar -xz
        cp -r mastodon-*/* /opt/mastodon
        cd /opt/mastodon
        RAILS_ENV=production bundle install
        RAILS_ENV=production bundle exec rails db:migrate
        RAILS_ENV=production bundle exec rails assets:precompile
EOF
        echo "${RELEASE}" >/opt/${APP}_version.txt
        msg_ok "Updated $APP to ${RELEASE}"

        msg_info "Starting $APP"
        systemctl restart mastodon-sidekiq
        systemctl reload mastodon-web
        systemctl restart mastodon-streaming
        msg_ok "Started $APP"

        msg_info "Cleaning up"
        rm -rf /tmp/mastodon-*
        msg_ok "Cleanup Completed"
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
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}${CL}"