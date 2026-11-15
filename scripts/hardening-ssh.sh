#!/usr/bin/env bash
set -Eeuo pipefail

USERNAME="steff"
CONFIG="/etc/ssh/sshd_config.d/99-homelab.conf"
BACKUP=""
CREATED=0
APPLIED=0

log() { printf '%s\n' "$*"; }
restore_config() {
  if [[ "$APPLIED" -eq 1 ]]; then return; fi
  if [[ -n "$BACKUP" && -f "$BACKUP" ]]; then
    cp -a "$BACKUP" "$CONFIG"
  elif [[ "$CREATED" -eq 1 ]]; then
    rm -f "$CONFIG"
  fi
}
on_error() {
  log "ERROR: Hardening failed; restoring previous SSH config if necessary."
  restore_config
  systemctl restart ssh.service >/dev/null 2>&1 || true
  log "If SSH access is unavailable, use the Proxmox console."
}
trap on_error ERR

[[ $EUID -eq 0 ]] || { log "ERROR: Run as root."; exit 1; }
[[ -f /etc/os-release ]] || { log "ERROR: Missing /etc/os-release"; exit 1; }
. /etc/os-release
case "$ID" in debian|ubuntu) ;; *) log "ERROR: Unsupported OS: $ID"; exit 1 ;; esac
command -v sshd >/dev/null || { log "ERROR: openssh-server is not installed."; exit 1; }
command -v ss >/dev/null || { log "ERROR: 'ss' command missing."; exit 1; }
id "$USERNAME" >/dev/null 2>&1 || { log "ERROR: Missing user $USERNAME"; exit 1; }
id -nG "$USERNAME" | tr ' ' '\n' | grep -qx sudo || { log "ERROR: $USERNAME is not in sudo group"; exit 1; }
USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
KEYS="$USER_HOME/.ssh/authorized_keys"
[[ -s "$KEYS" ]] || { log "ERROR: $KEYS is empty or missing"; exit 1; }
ssh-keygen -lf "$KEYS" >/dev/null || { log "ERROR: No readable SSH public key in $KEYS"; exit 1; }

log "=== SSH Hardening: $(hostname) ==="
log "Before continuing: test a NEW Termix key-based login as $USERNAME and run 'sudo whoami'."
log "Keep an existing session and Proxmox Console available."
read -r -p 'Type YES only after both tests passed: ' CONFIRM
[[ "$CONFIRM" == YES ]] || { log "Cancelled: no changes made."; exit 0; }

mkdir -p /etc/ssh/sshd_config.d
if [[ -e "$CONFIG" ]]; then
  BACKUP="${CONFIG}.bak.$(date +%Y%m%d-%H%M%S)"
  cp -a "$CONFIG" "$BACKUP"
else
  CREATED=1
fi
cat > "$CONFIG" <<'CONF'
# Homelab SSH hardening - managed by hardening-ssh.sh
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
CONF

sshd -t
# Check global effective configuration and the named user, since Match rules may override it.
for context in "" "-C user=$USERNAME,host=localhost,addr=127.0.0.1"; do
  # shellcheck disable=SC2086
  EFFECTIVE="$(sshd -T $context)"
  for setting in 'permitrootlogin no' 'passwordauthentication no' 'kbdinteractiveauthentication no' 'pubkeyauthentication yes'; do
    if ! grep -Fxq "$setting" <<< "$EFFECTIVE"; then
      log "ERROR: Effective SSH setting does not match: $setting"
      restore_config
      CREATED=0
      BACKUP=""
      exit 1
    fi
  done
done

# Debian 13 installations may encounter reload failures with socket activation.
# Restart instead of reload, and move from socket activation to ordinary ssh.service.
systemctl disable --now ssh.socket 2>/dev/null || true
systemctl reset-failed ssh.service || true
systemctl enable ssh.service
systemctl restart ssh.service
systemctl is-active --quiet ssh.service
ss -lnt | grep -Eq '(:22[[:space:]])'
APPLIED=1
trap - ERR
log "SUCCESS: SSH hardening applied."
log "Open a NEW Termix connection and verify sudo before closing the current session."
