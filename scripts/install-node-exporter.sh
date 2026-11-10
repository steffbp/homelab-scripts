
#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Run this script as root"
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
echo "Hostname: $(hostname)"
echo "OS: $PRETTY_NAME"

echo "[1/3] Updating package lists..."
apt-get update

echo "[2/3] Installing Node Exporter..."
DEBIAN_FRONTEND=noninteractive \
    apt-get install -y curl prometheus-node-exporter

echo "[3/3] Enabling service..."
systemctl enable --now prometheus-node-exporter

if curl -fsS --max-time 5 \
    http://127.0.0.1:9100/metrics >/dev/null; then
    echo "SUCCESS: Node Exporter is running"
else
    echo "ERROR: Node Exporter is not responding"
    exit 1
fi

echo
echo "Hostname: $(hostname)"
hostname -I 2>/dev/null || true
echo "Port: 9100"
echo "Installation completed."
