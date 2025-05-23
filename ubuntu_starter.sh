#!/bin/bash
set -e

# Args
ROOT_SSH_KEY="$1"
TAILSCALE_KEY="$2"
SAMBA_NETWORK="$3"
GIT_PRIVATE_KEY="$4"
NEW_USER="$5"
NEW_PASS="$6"
SETUP_SAMBA="$7"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if [ -z "$ROOT_SSH_KEY" ] || [ -z "$TAILSCALE_KEY" ] || [ -z "$SAMBA_NETWORK" ] || [ -z "$GIT_PRIVATE_KEY" ] || [ -z "$NEW_USER" ] || [ -z "$NEW_PASS" ] || [ -z "$SETUP_SAMBA" ]; then
    echo "Usage: sudo $0 \"<root_ssh_key>\" <tailscale_key> <samba_network> <git_private_key> <new_username> <new_password> <setup_samba (yes|no)>"
    exit 1
fi

PLUGINS="git sudo zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

install_dependencies() {
    log "Installing dependencies..."
    apt-get update
    apt-get install -y git curl zsh sudo ca-certificates gnupg lsb-release samba ufw wsdd
}

create_new_user() {
    log "Creating new user $NEW_USER..."
    useradd -m -s "$(which zsh)" -G sudo "$NEW_USER"
    echo "$NEW_USER:$NEW_PASS" | chpasswd
}

setup_tailscale() {
    log "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh || { echo "Tailscale installation failed"; exit 1; }

    log "Enabling and starting Tailscale service..."
    systemctl enable --now tailscaled || { echo "Failed to enable/start Tailscale service"; exit 1; }

    log "Configuring Tailscale..."
    tailscale up --hostname="$(hostname)" --accept-routes --ssh --auth-key="$TAILSCALE_KEY" || { echo "Tailscale configuration failed"; exit 1; }

    log "Tailscale setup completed successfully."
}

setup_docker() {
    log "Setting up Docker..."

    # Remove any old Docker versions
    apt-get remove -y docker docker-engine docker.io containerd runc || true

    # Install required dependencies
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker's repository
    UBUNTU_CODENAME=$(lsb_release -cs)
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $UBUNTU_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update package index and install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add the new user to the Docker group
    log "Adding $NEW_USER to the docker group..."
    groupadd -f docker
    usermod -aG docker "$NEW_USER"

    # Restart Docker to apply group changes
    log "Restarting Docker service..."
    systemctl restart docker

    # Verify Docker installation
    log "Verifying Docker installation..."
    su - "$NEW_USER" -c "docker run hello-world" || { echo "Docker is not configured correctly"; exit 1; }

    log "Docker setup completed successfully."
}

setup_user_environment() {
    local user="$1"
    local user_home="$2"
    local ssh_key="$3"
    local private_key="$4"

    # Add SSH key
    mkdir -p "$user_home/.ssh"
    chmod 700 "$user_home/.ssh"
    if ! grep -qF "$ssh_key" "$user_home/.ssh/authorized_keys" 2>/dev/null; then
        echo "$ssh_key" >> "$user_home/.ssh/authorized_keys"
    fi
    chmod 600 "$user_home/.ssh/authorized_keys"
    chown -R "$user:$user" "$user_home/.ssh"

    # Install Oh My Zsh
    rm -rf "$user_home/.oh-my-zsh" "$user_home/.zshrc"
    su - "$user" -c "curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | bash -s --"
    local zsh_custom="$user_home/.oh-my-zsh/custom"
    su - "$user" -c "git clone https://github.com/zsh-users/zsh-autosuggestions $zsh_custom/plugins/zsh-autosuggestions" || { echo "Failed to clone zsh-autosuggestions"; exit 1; }
    su - "$user" -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting $zsh_custom/plugins/zsh-syntax-highlighting" || { echo "Failed to clone zsh-syntax-highlighting"; exit 1; }
    su - "$user" -c "git clone https://github.com/zdharma-continuum/fast-syntax-highlighting $zsh_custom/plugins/fast-syntax-highlighting" || { echo "Failed to clone fast-syntax-highlighting"; exit 1; }
    su - "$user" -c "git clone https://github.com/marlonrichert/zsh-autocomplete $zsh_custom/plugins/zsh-autocomplete" || { echo "Failed to clone zsh-autocomplete"; exit 1; }
    su - "$user" -c "git clone https://github.com/romkatv/powerlevel10k $zsh_custom/themes/powerlevel10k" || { echo "Failed to clone powerlevel10k"; exit 1; }

    # Generate .zshrc with custom configuration
    cat <<EOM > "$user_home/.zshrc"
export LANG='en_US.UTF-8'
export LANGUAGE='en_US:en'
export LC_ALL='en_US.UTF-8'
[ -z "\$TERM" ] && export TERM=xterm

# Zsh/Oh-my-Zsh Configuration
export ZSH="$user_home/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=($PLUGINS)

# Custom left and right prompts
zsh_user_at_host(){
     echo -n "\$(whoami)@\$(hostname)"
 }
zsh_ip_address(){
    ip=\$(hostname -I | awk '{print \$1}')
    if [ -z "\$ip" ]; then
        echo "No IP"
    else
        echo "\$ip"
    fi
}
POWERLEVEL9K_CUSTOM_USER_AT_HOST="zsh_user_at_host"
POWERLEVEL9K_CUSTOM_IP="zsh_ip_address"
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(custom_user_at_host dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(custom_ip)


# Alias to start SSH agent and add Git signing key
alias start-ssh-agent='eval \$(ssh-agent) && ssh-add ~/.ssh/git_signing_key'
alias la='ls -alh --color=auto'

# Print "ubuntu" to terminal screen on startup
echo "       _                 _         "
echo " _   _| |__  _   _ _ __ | |_ _   _ "
echo "| | | | '_ \| | | | '_ \| __| | | |"
echo "| |_| | |_) | |_| | | | | |_| |_| |"
echo " \__,_|_.__/ \__,_|_| |_|\__|\__,_|"
eval \$(ssh-agent) > /dev/null 2>&1 && ssh-add ~/.ssh/git_signing_key > /dev/null 2>&1

source \$ZSH/oh-my-zsh.sh
EOM

    chown -R "$user:$user" "$user_home/.oh-my-zsh" "$user_home/.zshrc"
    chsh -s "$(which zsh)" "$user"

    # Configure Git signing
    echo "$private_key" > "$user_home/.ssh/git_signing_key"
    chmod 600 "$user_home/.ssh/git_signing_key"
    chown "$user:$user" "$user_home/.ssh/git_signing_key"
    su - "$user" -c "eval \$(ssh-agent) && ssh-add $user_home/.ssh/git_signing_key"
    su - "$user" -c "git config --global user.signingkey $user_home/.ssh/git_signing_key"
    su - "$user" -c "git config --global commit.gpgsign true"
}

setup_samba() {
    log "Setting up Samba..."
    mkdir -p /mnt/data /mnt/docker
    rm -rf /mnt/data/lost+found
    rm -rf /mnt/docker/lost+found
    chown -R "$NEW_USER:$NEW_USER" /mnt
    cd /etc/samba
    mv smb.conf smb.conf.old || true
    cat <<EOF > smb.conf
[global]
   server string = Media
   workgroup = WORKGROUP
   security = user
   map to guest = Bad User
   name resolve order = bcast host
   hosts allow = $SAMBA_NETWORK
   hosts deny = 0.0.0.0/0

[data]
   path = /mnt/data
   force user = $NEW_USER
   force group = $NEW_USER
   create mask = 0774
   force create mode = 0774
   directory mask = 0775
   force directory mode = 0775
   browseable = yes
   writable = yes
   read only = no
   guest ok = no

[docker]
   path = /mnt/docker
   force user = $NEW_USER
   force group = $NEW_USER
   create mask = 0774
   force create mode = 0774
   directory mask = 0775
   force directory mode = 0775
   browseable = yes
   writable = yes
   read only = no
   guest ok = no
EOF
    (echo "$NEW_PASS"; echo "$NEW_PASS") | smbpasswd -a "$NEW_USER"
    systemctl enable smbd nmbd
    systemctl restart smbd nmbd
    ufw enable || true
    ufw allow Samba || true
    ufw status
    apt install -y wsdd || { echo "Failed to install wsdd"; exit 1; }
}

# Run everything
install_dependencies
create_new_user
# setup_tailscale
setup_docker

if [ "$SETUP_SAMBA" = "yes" ]; then
    setup_samba
else
    log "Skipping Samba setup as per user request."
fi

setup_user_environment root /root "$ROOT_SSH_KEY" "$GIT_PRIVATE_KEY"
setup_user_environment "$NEW_USER" "/home/$NEW_USER" "$ROOT_SSH_KEY" "$GIT_PRIVATE_KEY"