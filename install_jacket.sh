#!/bin/bash
set -e

APP="Jackett"
INSTALL_DIR="/opt/Jackett"
SERVICE_FILE="/etc/systemd/system/jackett.service"
PORT=9117

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

install_dependencies() {
    log "Installing dependencies..."
    apt-get update
    apt-get install -y curl tar
}

download_jackett() {
    log "Downloading the latest Jackett release..."
    RELEASE=$(curl -fsSL https://github.com/Jackett/Jackett/releases/latest | grep "title>Release" | cut -d " " -f 4)
    curl -fsSL "https://github.com/Jackett/Jackett/releases/download/$RELEASE/Jackett.Binaries.LinuxAMDx64.tar.gz" -o Jackett.Binaries.LinuxAMDx64.tar.gz
}

install_jackett() {
    log "Installing Jackett..."
    mkdir -p "$INSTALL_DIR"
    tar -xzf Jackett.Binaries.LinuxAMDx64.tar.gz -C "$INSTALL_DIR"
    rm -f Jackett.Binaries.LinuxAMDx64.tar.gz
    echo "$RELEASE" > "$INSTALL_DIR/version.txt"
}

create_service() {
    log "Creating systemd service for Jackett..."
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Jackett Daemon
After=network.target

[Service]
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/Jackett
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable jackett
    systemctl start jackett
}

verify_installation() {
    log "Verifying Jackett installation..."
    if systemctl is-active --quiet jackett; then
        log "Jackett is running successfully."
        echo "Access Jackett at: http://$(hostname -I | awk '{print $1}'):$PORT"
    else
        log "Jackett installation failed."
        exit 1
    fi
}

# Main script execution
install_dependencies
download_jackett
install_jackett
create_service
verify_installation