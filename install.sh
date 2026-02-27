#!/bin/bash
# install.sh - Master AI OS Bootstrap & Optimizer
set -e

# Define your repo to pull configs from
REPO_URL="https://raw.githubusercontent.com/ConradTheunissen/TNSN-DESK-/main"

echo "1. Updating Ubuntu base..."
sudo apt update && sudo apt upgrade -y

echo "2. Installing Wayland stack, tools, and optimization packages..."
sudo apt install -y sway alacritty chromium-browser curl git zram-tools

echo "3. Applying Kernel and ZRAM Optimizations..."
# Configure ZRAM for 50% of total memory using lz4 compression
echo -e "ALGO=lz4\nPERCENT=50" | sudo tee /etc/default/zramswap
sudo systemctl restart zramswap

# Reduce kernel swappiness to prioritize physical RAM
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "4. Purging unnecessary background bloat..."
# Disable snapd, modem manager, and print spoolers to free up CPU cycles
sudo systemctl disable snapd ModemManager cups || true

echo "5. Bypassing login screen on tty1..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat <<EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin \$USER --noclear %I \$TERM
EOF

echo "6. Injecting Sway auto-start into bash profile..."
# Ensure Sway only launches on the first terminal to prevent boot loops
if ! grep -q "exec sway" ~/.bash_profile 2>/dev/null; then
cat <<'EOF' >> ~/.bash_profile
if [ -z "\$DISPLAY" ] && [ "\$XDG_VTNR" = 1 ]; then
  exec sway
fi
EOF
fi

echo "7. Pulling custom UI configuration..."
mkdir -p ~/.config/sway
curl -sL "$REPO_URL/sway-config" -o ~/.config/sway/config

echo "Installation complete. Type 'sudo reboot' to launch.
