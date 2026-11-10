
#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Run this script as root"
    exit 1
fi

if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: Cannot identify OS"
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

echo "=================================="
echo " Homelab Node Exporter Installer"
echo "=================================="
echo "Hostname: $(hostname)"
echo "OS: $PRETTY_NAME"
echo

echo "[1/4] Updating package lists..."
apt-get update

echo "[2/4] Installing basic tools..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    wget \
    nano \
    ca-certificates \
    dnsutils \
    iputils-ping

echo "[3/4] Installing Node Exporter..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    prometheus-node-exporter

echo "[4/4] Enabling Node Exporter..."
systemctl enable --now prometheus-node-exporter

echo
if curl -fsS --max-time 5 \
    http://127.0.0.1:9100/metrics >/dev/null; then
    echo "SUCCESS: Node Exporter is running!"
else
    echo "ERROR: Node Exporter is not responding"
    exit 1
fi

echo
echo "Hostname: $(hostname)"
echo "IP addresses:"
hostname -I 2>/dev/null || true
echo
echo "Metrics port: 9100"
echo "Installation completed."
