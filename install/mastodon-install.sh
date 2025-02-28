#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: dave-yap
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://docs.joinmastodon.org/admin/

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
    wget \
    gnupg \
    apt-transport-https \
    lsb-release \
    ca-certificates \
    sudo \
    expect \
    git \
    mc
msg_ok "Installed Dependecies"

msg_info "Installing Node.JS"
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
$STD apt-get update -y
$STD apt-get install -y nodejs
corepack enable
msg_ok "Installed Node.JS"

msg_ok "Installing Mastodon Dependecies"
$STD apt-get install -y \
    imagemagick \
    ffmpeg \
    libvips-tools \
    libpq-dev \
    libxml2-dev \
    libxslt1-dev \
    file \
    g++ \
    libprotobuf-dev \
    protobuf-compiler \
    pkg-config \
    gcc \
    autoconf \
    bison build-essential \
    libssl-dev \
    libyaml-dev \
    libreadline6-dev \
    zlib1g-dev \
    libncurses5-dev \
    libffi-dev \
    libgdbm-dev \
    nginx \
    redis-server \
    redis-tools \
    certbot \
    python3-certbot-nginx \
    libidn11-dev \
    libicu-dev \
    libjemalloc-dev
corepack enable
useradd mastodon
mkdir -p /home/mastodon
mkdir -p /opt/mastodon
chown mastodon: /home/mastodon
chown mastodon: /opt/mastodon
msg_ok "Installed Mastodon Dependencies"

msg_info "Installing PostgreSQL"
wget -qO /usr/share/keyrings/postgresql.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc
echo "deb [signed-by=/usr/share/keyrings/postgresql.asc] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/postgresql.list
$STD apt-get update -y
$STD apt-get install -y postgresql
systemctl -q start postgresql
msg_ok "Installed PostgreSQL"

msg_info "Setting up PostgreSQL"
DB_USER="mastodon"
DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | cut -c1-13)
DB_ADMIN_USER="root"
DB_ADMIN_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | cut -c1-13)
$STD sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS' CREATEDB;"
$STD sudo -u postgres psql -c "CREATE USER $DB_ADMIN_USER WITH PASSWORD '$DB_ADMIN_PASS' SUPERUSER;"
{
    echo "Application Credentials"
    echo "DB_USER: $DB_USER"
    echo "DB_PASS: $DB_PASS"
    echo "DB_ADMIN_USER: $DB_ADMIN_USER"
    echo "DB_ADMIN_PASS: $DB_ADMIN_PASS"
} >> ~/mastodon.creds
msg_ok "PostgreSQL setup for Mastodon"

msg_info "Installing Ruby"
RUBY_RELEASE=$(curl -si https://github.com/rbenv/rbenv/releases/latest | grep location: | cut -d '/' -f 8 | tr -d '\r')
RUBY_BUILD_RELEASE=$(curl -si https://github.com/rbenv/ruby-build/releases/latest | grep location: | cut -d '/' -f 8 | tr -d '\r')
su - mastodon -c 'bash' << EOF
cd ~
wget -qc https://github.com/rbenv/rbenv/archive/refs/tags/$RUBY_RELEASE.tar.gz
tar -xzf $RUBY_RELEASE.tar.gz
mv rbenv-*/ /home/mastodon/.rbenv
echo 'export PATH="/home/mastodon/.rbenv/bin:$PATH"' >> ~/.bashrc
echo "export PATH="/home/mastodon/.rbenv/shims:$PATH"" >> ~/.bashrc
echo "export RBENV_SHELL=bash" >> ~/.bashrc
echo 'eval "$(/home/mastodon/.rbenv/bin/rbenv init -)"' >> ~/.bashrc
wget -qc https://github.com/rbenv/ruby-build/archive/refs/tags/$RUBY_BUILD_RELEASE.tar.gz
tar -xzf $RUBY_BUILD_RELEASE.tar.gz
mkdir -p /home/mastodon/.rbenv/plugins/ruby-build
cp -r ruby-build-*/* /home/mastodon/.rbenv/plugins/ruby-build
RUBY_CONFIGURE_OPTS=--with-jemalloc ~/.rbenv/bin/rbenv install 3.4.2
/home/mastodon/.rbenv/bin/rbenv global 3.4.2
/home/mastodon/.rbenv/shims/gem install bundler --no-document
/home/mastodon/.rbenv/bin/rbenv rehash
EOF
#su - mastodon -c "wget -qc https://github.com/rbenv/rbenv/archive/refs/tags/$RUBY_RELEASE.tar.gz"
#su - mastodon -c "tar -xzf $RUBY_RELEASE.tar.gz"
#su - mastodon -c "mv rbenv-*/ ~/.rbenv"
#su - mastodon -c "echo 'export PATH="~/.rbenv/bin:$PATH"' >> ~/.bashrc"
#su - mastodon -c 'echo "export PATH="/home/mastodon/.rbenv/shims:$PATH"" >> ~/.bashrc'
#su - mastodon -c 'echo "export RBENV_SHELL=bash" >> ~/.bashrc'
#su - mastodon -c 'eval "$(~/.rbenv/bin/rbenv init -)"'
#su - mastodon -c "wget -qc https://github.com/rbenv/ruby-build/archive/refs/tags/$RUBY_BUILD_RELEASE.tar.gz"
#su - mastodon -c "tar -xzf $RUBY_BUILD_RELEASE.tar.gz"
#su - mastodon -c "mkdir -p /home/mastodon/.rbenv/plugins/ruby-build"
#su - mastodon -c "cp -r ruby-build-*/* /home/mastodon/.rbenv/plugins/ruby-build"
#su - mastodon -c "RUBY_CONFIGURE_OPTS=--with-jemalloc ~/.rbenv/bin/rbenv install 3.4.2"
#su - mastodon -c "/home/mastodon/.rbenv/bin/rbenv global 3.4.2"
#su - mastodon -c "/home/mastodon/.rbenv/shims/gem install bundler --no-document"
#su - mastodon -c "/home/mastodon/.rbenv/bin/rbenv rehash"
msg_ok "Installed Ruby"

msg_info "Installing Mastodon"
RELEASE=$(curl -si https://github.com/mastodon/mastodon/releases/latest | grep location: | cut -d '/' -f 8 | tr -d '\r')
su - mastodon -c 'bash' << EOF
cd ~
wget -qc https://github.com/mastodon/mastodon/archive/refs/tags/$RELEASE.tar.gz
tar -xzf $RELEASE.tar.gz
cp -r mastodon-*/* /opt/mastodon
cd /opt/mastodon && /home/mastodon/.rbenv/shims/bundle config deployment 'true'
cd /opt/mastodon && /home/mastodon/.rbenv/shims/bundle config without 'development test'
cd /opt/mastodon && /home/mastodon/.rbenv/shims/bundle install -j$(getconf _NPROCESSORS_ONLN)
yes | su - mastodon -c "cd /opt/mastodon && yarn install"
EOF
su - mastodon -c "expect <<EOF
spawn RAILS_ENV=production /opt/mastodon/bin/rails mastodon:setup
EOF"
#su - mastodon -c "wget -qc https://github.com/mastodon/mastodon/archive/refs/tags/$RELEASE.tar.gz"
#su - mastodon -c "tar -xzf $RELEASE.tar.gz"
#su - mastodon -c "cp -r mastodon-*/* /opt/mastodon"
#su - mastodon -c "cd /opt/mastodon && /home/mastodon/.rbenv/shims/bundle config deployment 'true'"
#su - mastodon -c "cd /opt/mastodon && /home/mastodon/.rbenv/shims/bundle config without 'development test'"
#su - mastodon -c "cd /opt/mastodon && /home/mastodon/.rbenv/shims/bundle install -j$(getconf _NPROCESSORS_ONLN)"
#yes | su - mastodon -c "cd /opt/mastodon && yarn install"
#$STD su - mastodon -c "expect <<EOF
#spawn RAILS_ENV=production /opt/mastodon/bin/rails mastodon:setup
#EOF"
msg_ok "Installed Mastodon"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/mastodon-sidekiq.service
[Unit]
Description=mastodon-sidekiq
After=network.target

[Service]
Type=simple
User=mastodon
WorkingDirectory=/opt/mastodon
Environment="RAILS_ENV=production"
Environment="DB_POOL=25"
Environment="MALLOC_ARENA_MAX=2"
Environment="LD_PRELOAD=libjemalloc.so"
ExecStart=/home/mastodon/.rbenv/shims/bundle exec sidekiq -c 25
TimeoutSec=15
Restart=always
# Proc filesystem
ProcSubset=pid
ProtectProc=invisible
# Capabilities
CapabilityBoundingSet=
# Security
NoNewPrivileges=true
# Sandboxing
ProtectSystem=strict
PrivateTmp=true
PrivateDevices=true
PrivateUsers=true
ProtectHostname=true
ProtectKernelLogs=true
ProtectKernelModules=true
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_INET
RestrictAddressFamilies=AF_INET6
RestrictAddressFamilies=AF_NETLINK
RestrictAddressFamilies=AF_UNIX
RestrictNamespaces=true
LockPersonality=true
RestrictRealtime=true
RestrictSUIDSGID=true
RemoveIPC=true
PrivateMounts=true
ProtectClock=true
# System Call Filtering
SystemCallArchitectures=native
SystemCallFilter=~@cpu-emulation @debug @keyring @ipc @mount @obsolete @privileged @setuid
SystemCallFilter=@chown
SystemCallFilter=pipe
SystemCallFilter=pipe2
ReadWritePaths=/home/mastodon/live

[Install]
WantedBy=multi-user.target
EOF
cat <<EOF >/etc/systemd/system/mastodon-streaming.service
[Unit]
Description=mastodon-streaming
After=network.target
Wants=mastodon-streaming@4000.service

[Service]
Type=oneshot
ExecStart=/bin/echo "mastodon-streaming exists only to collectively start and stop mastodon-streaming@ instances, shimming over the migration to templated mastodon-streaming systemd unit"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
cat <<EOF >/etc/systemd/system/mastodon-streaming@.service
[Unit]
Description=mastodon-streaming on port %I
After=network.target
# handles using `systemctl restart mastodon-streaming`
PartOf=mastodon-streaming.service
ReloadPropagatedFrom=mastodon-streaming.service

[Service]
Type=simple
User=mastodon
WorkingDirectory=/opt/mastodon
Environment="NODE_ENV=production"
Environment="PORT=%i"
ExecStart=/usr/bin/node ./streaming
TimeoutSec=15
Restart=always
LimitNOFILE=65536
# Proc filesystem
ProcSubset=pid
ProtectProc=invisible
# Capabilities
CapabilityBoundingSet=
# Security
NoNewPrivileges=true
# Sandboxing
ProtectSystem=strict
PrivateTmp=true
PrivateDevices=true
PrivateUsers=true
ProtectHostname=true
ProtectKernelLogs=true
ProtectKernelModules=true
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_INET
RestrictAddressFamilies=AF_INET6
RestrictAddressFamilies=AF_NETLINK
RestrictAddressFamilies=AF_UNIX
RestrictNamespaces=true
LockPersonality=true
RestrictRealtime=true
RestrictSUIDSGID=true
RemoveIPC=true
PrivateMounts=true
ProtectClock=true
# System Call Filtering
SystemCallArchitectures=native
SystemCallFilter=~@cpu-emulation @debug @keyring @ipc @memlock @mount @obsolete @privileged @resources @setuid
SystemCallFilter=pipe
SystemCallFilter=pipe2
ReadWritePaths=/home/mastodon/live

[Install]
WantedBy=multi-user.target mastodon-streaming.service
EOF
cat <<EOF >/etc/systemd/system/mastodon-web.service
[Unit]
Description=mastodon-web
After=network.target

[Service]
Type=simple
User=mastodon
WorkingDirectory=/opt/mastodon
Environment="RAILS_ENV=production"
Environment="PORT=3000"
Environment="LD_PRELOAD=libjemalloc.so"
ExecStart=/home/mastodon/.rbenv/shims/bundle exec puma -C config/puma.rb
ExecReload=/bin/kill -SIGUSR1 $MAINPID
TimeoutSec=15
Restart=always
# Proc filesystem
ProcSubset=pid
ProtectProc=invisible
# Capabilities
CapabilityBoundingSet=
# Security
NoNewPrivileges=true
# Sandboxing
ProtectSystem=strict
PrivateTmp=true
PrivateDevices=true
PrivateUsers=true
ProtectHostname=true
ProtectKernelLogs=true
ProtectKernelModules=true
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_INET
RestrictAddressFamilies=AF_INET6
RestrictAddressFamilies=AF_NETLINK
RestrictAddressFamilies=AF_UNIX
RestrictNamespaces=true
LockPersonality=true
RestrictRealtime=true
RestrictSUIDSGID=true
RemoveIPC=true
PrivateMounts=true
ProtectClock=true
# System Call Filtering
SystemCallArchitectures=native
SystemCallFilter=~@cpu-emulation @debug @keyring @ipc @mount @obsolete @privileged @setuid
SystemCallFilter=@chown
SystemCallFilter=pipe
SystemCallFilter=pipe2
ReadWritePaths=/home/mastodon/live

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q mastodon-web mastodon-sidekiq mastodon-streaming
msg_ok "Created Services"

msg_info "Create nginx-setup.sh"
cat <<EOF >~/nginx-setup.sh
if [ -z "$1" ]; then
    echo "Error: Please provide a domain name"
    echo "Usage: $0 domain.com"
    exit 1
fi

certbot certonly --nginx -d $1
cp /opt/mastodon/dist/nginx.conf /etc/nginx/sites-available/mastodon
ln -s /etc/nginx/sites-available/mastodon /etc/nginx/sites-enabled/mastodon
rm /etc/nginx/sites-enabled/default

sed -i "s,example.com,$1,g" /etc/nginx/sites-enabled/mastodon
sed -i "s|# ssl_certificate\s*/etc/letsencrypt/live/example.com/fullchain.pem;|ssl_certificate     /etc/letsencrypt/live/$2/fullchain.pem;|" /etc/nginx/sites-enabled/mastodon
sed -i "s|# ssl_certificate\s*/etc/letsencrypt/live/example.com/privkey.pem;|ssl_certificate     /etc/letsencrypt/live/$2/privkey.pem;|" /etc/nginx/sites-enabled/mastodon

chmod o+x /opt/mastodon

systemctl restart nginx
EOF
msg_ok "Bash script for semi-automating nginx setup"

msg_info "Starting Mastodon"
systemctl start mastodon-*
msg_ok "Mastodon started"

motd_ssh
customize

msg_info "Cleaning up"
su - mastodon -c "rm -rf ~/ruby* ~/rbenv* ~/mastodon*"
su - mastodon -c "rm -rf ~/*.tar.gz"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"