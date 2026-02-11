#!/usr/bin/env bash
# Role: BR-SRV
# Task: Cleanup previous Samba AD DC provisioning + related changes
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  printf "Error: must be root\n" >&2
  exit 1
fi

HOST_SHORT="br-srv"
LAN_IP="192.168.200.2"

printf "BR-SRV cleanup: start\n"

# --- Stop/disable services that were enabled ---
systemctl stop samba-ad-dc >/dev/null 2>&1 || true
systemctl disable samba-ad-dc >/dev/null 2>&1 || true

systemctl stop smbd nmbd winbind >/dev/null 2>&1 || true
systemctl disable smbd nmbd winbind >/dev/null 2>&1 || true

# --- Backup current configs once (for safety) ---
ts="$(date +%Y%m%d-%H%M%S)"
for f in /etc/samba/smb.conf /etc/krb5.conf /etc/resolv.conf /etc/hosts; do
  if [[ -f "$f" && ! -f "${f}.bak" ]]; then
    cp -a "$f" "${f}.bak"
  fi
done

# --- Restore smb.conf if orig exists, otherwise remove it (so new script provisions cleanly) ---
if [[ -f /etc/samba/smb.conf.orig ]]; then
  mv -f /etc/samba/smb.conf.orig /etc/samba/smb.conf
else
  rm -f /etc/samba/smb.conf
fi

# --- Remove Samba AD DC databases/sysvol (THIS is the real reset) ---
rm -rf /var/lib/samba/private \
       /var/lib/samba/sysvol \
       /var/cache/samba \
       /var/run/samba \
       /var/lib/samba/*.tdb \
       /var/lib/samba/*.ldb  >/dev/null 2>&1 || true

# --- Remove machine secrets/keytabs that often break re-provisioning ---
rm -f /etc/krb5.keytab >/dev/null 2>&1 || true

# --- Reset hostname to expected short (neutral) ---
cur_host="$(hostname -s || true)"
if [[ "$cur_host" != "$HOST_SHORT" ]]; then
  hostnamectl set-hostname "$HOST_SHORT"
fi

# --- Reset /etc/hosts to neutral baseline (no realm binding) ---
cat <<EOF > /etc/hosts
127.0.0.1       localhost
${LAN_IP}       ${HOST_SHORT}
EOF

# --- Reset resolv.conf to neutral (Internet DNS). New setup script will set it as needed ---
# If systemd-resolved stub exists, prefer symlink back; else write plain file.
if [[ -e /run/systemd/resolve/stub-resolv.conf ]]; then
  rm -f /etc/resolv.conf
  ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
else
  rm -f /etc/resolv.conf
  cat <<EOF > /etc/resolv.conf
nameserver 8.8.8.8
EOF
fi

printf "BR-SRV cleanup: done\n"
printf "Backups (if created): *.bak in /etc\n"