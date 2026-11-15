
#!/usr/bin/env bash
set -euo pipefail

USERNAME="steff"
KEY_URL="https://raw.githubusercontent.com/steffbp/homelab-scripts/main/keys/termix.pub"

echo "=== Homelab SSH User Setup ==="

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: Cannot detect OS."
    exit 1
fi

. /etc/os-release

case "$ID" in
    debian|ubuntu) ;;
    *)
        echo "ERROR: Unsupported OS: $ID"
        exit 1
        ;;
esac

echo "Host: $(hostname)"
echo "OS: $PRETTY_NAME"
echo

echo "[1/5] Installing required packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    openssh-server \
    sudo \
    ca-certificates \
    wget

echo "[2/5] Creating user..."
if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME already exists."
else
    useradd -m -s /bin/bash "$USERNAME"
    echo "Set a unique password for $USERNAME:"
    passwd "$USERNAME"
fi

echo "[3/5] Configuring sudo..."
usermod -aG sudo "$USERNAME"

echo "[4/5] Installing Termix SSH public key..."

USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

TEMP_KEY="$(mktemp)"
trap 'rm -f "$TEMP_KEY"' EXIT

wget -qO "$TEMP_KEY" "$KEY_URL"

if ! ssh-keygen -lf "$TEMP_KEY" >/dev/null 2>&1; then
    echo "ERROR: Invalid SSH public key."
    exit 1
fi

install -d -m 700 "$SSH_DIR"
touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

PUBLIC_KEY="$(cat "$TEMP_KEY")"

if grep -Fxq "$PUBLIC_KEY" "$AUTHORIZED_KEYS"; then
    echo "SSH key already installed."
else
    printf '%s\n' "$PUBLIC_KEY" >> "$AUTHORIZED_KEYS"
    echo "SSH key installed."
fi

chown -R "$USERNAME:$(id -gn "$USERNAME")" "$SSH_DIR"

echo "[5/5] Enabling SSH..."
systemctl enable --now ssh

echo
echo "=== Setup Completed ==="
echo "Hostname: $(hostname)"
echo "Username: $USERNAME"
echo "SSH port: 22"
echo "Sudo group: enabled"
echo "SSH public key: installed"
echo
echo "IMPORTANT:"
echo "Test SSH login and sudo before disabling root access."
