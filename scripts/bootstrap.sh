
#!/usr/bin/env bash
set -Eeuo pipefail

BASE_URL="https://raw.githubusercontent.com/steffbp/homelab-scripts/main/scripts"

if (( EUID != 0 )); then
    echo "ERROR: Run this script as root." >&2
    exit 1
fi

if [[ ! -r /etc/os-release ]]; then
    echo "ERROR: Cannot identify OS." >&2
    exit 1
fi

. /etc/os-release

case "${ID:-}" in
    debian|ubuntu) ;;
    *)
        echo "ERROR: Unsupported OS: ${ID:-unknown}" >&2
        exit 1
        ;;
esac

echo "=== Homelab Server Bootstrap ==="
echo "Hostname: $(hostname)"
echo "OS: $PRETTY_NAME"
echo
echo "Take a snapshot before making changes."
read -r -p "Snapshot completed? Type YES: " CONFIRM

if [[ "$CONFIRM" != "YES" ]]; then
    echo "Cancelled. No changes made."
    exit 1
fi

ask_yes_no() {
    local prompt="$1" default="$2" answer

    while true; do
        read -r -p "$prompt" answer
        answer="${answer,,}"
        [[ -z "$answer" ]] && answer="$default"

        case "$answer" in
            y|yes|ja|j) return 0 ;;
            n|no|nej) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

SETUP_SSH=false
SETUP_NODE=false

if ask_yes_no "Set up SSH user steff? [Y/n]: " y; then
    SETUP_SSH=true
fi

if ask_yes_no "Install Node Exporter? [y/N]: " n; then
    SETUP_NODE=true
fi

echo
echo "[1/3] Updating APT package lists..."
apt-get update

echo "[2/3] Installing standard tools..."
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

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

run_script() {
    local name="$1"
    local file="$WORKDIR/$name"

    echo "Downloading $name..."
    wget -qO "$file" "$BASE_URL/$name"

    test -s "$file"
    bash -n "$file"

    echo "Running $name..."
    bash "$file"
}

echo "[3/3] Installing selected components..."

if [[ "$SETUP_SSH" == true ]]; then
    run_script "setup-ssh-user.sh"
    id steff >/dev/null
    systemctl is-active --quiet ssh.service
fi

if [[ "$SETUP_NODE" == true ]]; then
    run_script "install-node-exporter.sh"
    systemctl is-active --quiet prometheus-node-exporter
fi

echo
echo "=== SUCCESS: Bootstrap completed ==="
echo "Hostname: $(hostname)"
echo "IP addresses: $(hostname -I 2>/dev/null || true)"
echo "SSH setup: $SETUP_SSH"
echo "Node Exporter: $SETUP_NODE"

echo
echo "NEXT STEPS:"
echo "1. Test Termix login as steff."
echo "2. Verify sudo whoami."
echo "3. Run SSH hardening separately."
echo "4. Add Node Exporter to Prometheus if installed."
