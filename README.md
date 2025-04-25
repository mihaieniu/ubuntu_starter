# Ubuntu Post-Install Script

This script sets up Zsh, Docker, Samba, Tailscale, and more on a fresh Ubuntu system.

## Prerequisites

```bash
sudo apt update && sudo apt upgrade -y && sudo apt install -y curl
```

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/mihaieniu/ubuntu_starter/refs/heads/main/ubuntu_starter.sh | bash -s -- "<root_ssh_key>" "<tailscale_auth_key>" "<samba_network>" "<git_private_key>" "<new_user>" "<new_password>"
```

Example:

```bash
curl -fsSL https://raw.githubusercontent.com/mihaieniu/ubuntu_starter/refs/heads/main/ubuntu_starter.sh | bash -s -- "ssh-ed25519 key" "tskey-auth-key" "192.168.100.0/24" "PRIVATE_KEY_CONTENT" "user" "passwd"
```

## Arguments

1. `<root_ssh_key>`: The SSH public key to be added to the root user.
2. `<tailscale_auth_key>`: The Tailscale authentication key.
3. `<samba_network>`: The IP range allowed to access Samba shares using /CIDR.
4. `<git_private_key>`: The private key used for Git signing configuration.
5. `<new_user>`: The username for the new user to be created.
6. `<new_password>`: The password for the new user.

## Features

- **Zsh Setup**: Installs Oh My Zsh with plugins and Powerlevel10k theme for both `root` and the new user.
- **Docker Setup**: Installs Docker and verifies the installation with a "Hello World" test.
- **Samba Setup**: Configures Samba with specified network access and ensures `/mnt` ownership is set for the new user.
- **Tailscale Setup**: Installs and ensures the `tailscaled` service is running.
- **User Creation**: Creates a new user with sudo privileges and sets up SSH access.
- **Git Signing**: Configures Git signing for the new user using the provided private key.

### Notes

- Ensure you run the script as `root` or with `sudo`.
- Replace the placeholders in the example command with your actual values.
- The script changes the default shell to Zsh for both `root` and the new user.
