#!/bin/bash
set -e

APP="qBittorrent"
INSTALL_DIR="/opt/qbittorrent"
SERVICE_FILE="/etc/systemd/system/qbittorrent-nox.service"
PORT=8090

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

install_dependencies() {
    log "Installing dependencies..."
    apt-get update
    apt-get install -y curl tar
}

download_qbittorrent() {
    log "Downloading the latest qBittorrent release..."
    FULLRELEASE=$(curl -fsSL https://api.github.com/repos/userdocs/qbittorrent-nox-static/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
    RELEASE=$(echo "$FULLRELEASE" | cut -c 9-13)
    curl -fsSL "https://github.com/userdocs/qbittorrent-nox-static/releases/download/${FULLRELEASE}/x86_64-qbittorrent-nox" -o qbittorrent-nox
}

install_qbittorrent() {
    log "Installing qBittorrent..."
    mkdir -p "$INSTALL_DIR"
    mv qbittorrent-nox "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/qbittorrent-nox"
    echo "$RELEASE" > "$INSTALL_DIR/version.txt"
}

create_service() {
    log "Creating systemd service for qBittorrent..."
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=qBittorrent Daemon
After=network.target

[Service]
ExecStart=$INSTALL_DIR/qbittorrent-nox
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable qbittorrent-nox
    systemctl start qbittorrent-nox
}

verify_installation() {
    log "Verifying qBittorrent installation..."
    if systemctl is-active --quiet qbittorrent-nox; then
        log "qBittorrent is running successfully."
        echo "Access qBittorrent at: http://$(hostname -I | awk '{print $1}'):$PORT"
    else
        log "qBittorrent installation failed."
        exit 1
    fi
}

# Main script execution
install_dependencies
download_qbittorrent
install_qbittorrent
create_service
verify_installation