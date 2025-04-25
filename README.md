# Ubuntu Post-Install Script

This script sets up Zsh, Docker, Samba, Tailscale, and more on a fresh Ubuntu system.  
Just run:

```bash
curl -fsSL https://raw.githubusercontent.com/<your-username>/ubuntu-postinstall/main/ubuntu_postinstall.sh | bash -s -- "<root_ssh_key>" <new_user> <new_password> <tailscale_auth_key>
