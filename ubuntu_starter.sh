#!/bin/bash
set -e

# Args
ROOT_SSH_KEY="$1"
NEW_USER="$2"
NEW_PASS="$3"
TAILSCALE_KEY="$4"

if [ -z "$ROOT_SSH_KEY" ] || [ -z "$NEW_USER" ] || [ -z "$NEW_PASS" ] || [ -z "$TAILSCALE_KEY"]; then
    echo "Usage: sudo $0 "<root_ssh_key>" <new_username> <new_password>"
    exit 1
fi

THEME="default"
PLUGINS="git sudo zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete"

install_dependencies() {
    apt-get update
    apt-get install -y git curl zsh sudo ca-certificates gnupg lsb-release samba ufw wsdd
}

add_ssh_key() {
    local user_home="$1"
    local ssh_key="$2"
    local user="$3"
    mkdir -p "$user_home/.ssh"
    chmod 700 "$user_home/.ssh"
    echo "$ssh_key" >> "$user_home/.ssh/authorized_keys"
    chmod 600 "$user_home/.ssh/authorized_keys"
    chown -R "$user:$user" "$user_home/.ssh"
}

zshrc_template() {
    local _home="$1"
    local _theme="$2"
    local _plugins="$3"
    cat <<EOM
export ZSH="\$_home/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=($_plugins)
zsh_user_at_host(){
    echo -n "\$(whoami)@\$(hostname)"
}
zsh_ip_address(){
    hostname -I | awk '{print $1}'
}
POWERLEVEL9K_CUSTOM_USER_AT_HOST="zsh_user_at_host"
POWERLEVEL9K_CUSTOM_IP="zsh_ip_address"
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(custom_user_at_host dir)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(custom_ip)
source \$ZSH/oh-my-zsh.sh
EOM
}

powerline10k_config() {
    cat <<EOM
POWERLEVEL9K_SHORTEN_STRATEGY="truncate_to_last"
EOM
}

setup_ohmyzsh() {
    local user="$1"
    local user_home="$2"
    local ssh_key="$3"
    rm -rf "$user_home/.oh-my-zsh" "$user_home/.zshrc"
    su - "$user" -c "sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended"
    local zsh_custom="$user_home/.oh-my-zsh/custom"
    su - "$user" -c "
    git clone https://github.com/zsh-users/zsh-autosuggestions $zsh_custom/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting $zsh_custom/plugins/zsh-syntax-highlighting
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting $zsh_custom/plugins/fast-syntax-highlighting
    git clone https://github.com/marlonrichert/zsh-autocomplete $zsh_custom/plugins/zsh-autocomplete
    git clone https://github.com/romkatv/powerlevel10k $zsh_custom/themes/powerlevel10k
    "
    zshrc_template "$user_home" "$THEME" "$PLUGINS" > "$user_home/.zshrc"
    powerline10k_config >> "$user_home/.zshrc"
    chown "$user:$user" "$user_home/.zshrc"
    chsh -s "$(which zsh)" "$user"
    add_ssh_key "$user_home" "$ssh_key" "$user"
}

setup_tailscale() {
    curl -fsSL https://tailscale.com/install.sh | sh
    systemctl enable --now tailscaled
    echo "@reboot root tailscale up --auth-key=$TAILSCALE_KEY --accept-routes --ssh" >> /etc/crontab
}

create_new_user() {
    useradd -m -s "$(which zsh)" -G sudo "$NEW_USER"
    echo "$NEW_USER:$NEW_PASS" | chpasswd
}

setup_docker() {
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo       "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu       $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable"       | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    chown -R "$NEW_USER:$NEW_USER" /mnt || true
    [ -d /data ] && chown -R "$NEW_USER:$NEW_USER" /data
    [ -d /docker ] && chown -R "$NEW_USER:$NEW_USER" /docker
}

setup_samba() {
    cd /etc/samba
    mv smb.conf smb.conf.old || true
    cat <<EOF > smb.conf
[global]
   server string = Media
   workgroup = WORKGROUP
   security = user
   map to guest = Bad User
   name resolve order = bcast host
   hosts allow = 192.168.100.0/24
   hosts deny = 0.0.0.0/0

[data]
   path = /data
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
   path = /docker
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
    ufw allow Samba || true
    ufw status
}

# Run everything
install_dependencies
setup_ohmyzsh root /root "$ROOT_SSH_KEY"
create_new_user
setup_ohmyzsh "$NEW_USER" "/home/$NEW_USER" "$ROOT_SSH_KEY"
setup_tailscale
setup_docker
setup_samba
