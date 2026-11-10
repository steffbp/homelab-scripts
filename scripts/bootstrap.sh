
#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run as root."
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
        echo "Unsupported OS: $ID"
        exit 1
        ;;
esac

echo "=== Homelab Bootstrap ==="
echo "Host: $(hostname)"
echo "OS: $PRETTY_NAME"

echo "[1/2] Updating APT package lists..."
apt-get update

echo "[2/2] Installing basic tools..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    wget \
    nano \
    vim-tiny \
    dnsutils \
    iputils-ping \
    traceroute \
    jq \
    htop \
    git

echo
echo "SUCCESS: Bootstrap completed."
