
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

echo "=== Homelab Node Exporter Installer ==="
echo "Host: $(hostname)"
echo "OS: $PRETTY_NAME"

echo "[1/3] Updating APT package lists..."
apt-get update

echo "[2/3] Installing Node Exporter..."
DEBIAN_FRONTEND=noninteractive \
    apt-get install -y prometheus-node-exporter

echo "[3/3] Enabling Node Exporter..."
systemctl enable --now prometheus-node-exporter

echo
if systemctl is-active --quiet prometheus-node-exporter; then
    echo "SUCCESS: Node Exporter is running."
else
    echo "ERROR: Node Exporter failed."
    exit 1
fi

echo "Hostname: $(hostname)"
echo "IP addresses:"
hostname -I 2>/dev/null || true
echo "Metrics port: 9100"
