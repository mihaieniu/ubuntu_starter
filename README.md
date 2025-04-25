# Ubuntu Post-Install Script

This script sets up Zsh, Docker, Samba, Tailscale, and more on a fresh Ubuntu system.  

## Prerequisites

```bash
sudo apt update && sudo apt upgrade -y && sudo apt install -y curl
```

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/mihaieniu/ubuntu_starter/refs/heads/main/ubuntu_starter.sh | bash -s -- "<root_ssh_key>" "<new_user>" "<new_password>" "<tailscale_auth_key>" "<samba_network>"
```

Example:

```bash
curl -fsSL https://raw.githubusercontent.com/mihaieniu/ubuntu_starter/refs/heads/main/ubuntu_starter.sh | bash -s -- "ssh-ed25519 key" "user" "passwd" "tskey-auth-key" "192.168.100.0/24"
```

## Arguments

1. `<root_ssh_key>`: The SSH public key to be added to the root user.
2. `<new_user>`: The username for the new user to be created.
3. `<new_password>`: The password for the new user.
4. `<tailscale_auth_key>`: The Tailscale authentication key.
5. `<samba_network>`: The IP range allowed to access Samba shares using /CIDR.

## Features

- **Zsh Setup**: Installs Oh My Zsh with plugins and Powerlevel10k theme.
- **Docker Setup**: Installs Docker and sets up permissions for the new user.
- **Samba Setup**: Configures Samba with specified network access.
- **Tailscale Setup**: Installs and configures Tailscale with the provided authentication key.
- **User Creation**: Creates a new user with sudo privileges and sets up SSH access.

### Notes

- Ensure you run the script as `root` or with `sudo`.
- Replace the placeholders in the example command with your actual values.
