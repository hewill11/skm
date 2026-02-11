#!/usr/bin/env bash
# Role: HQ-CLI
# Task: Cleanup previous domain join + winbind + sudo restrictions
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  printf "Error: must be root\n" >&2
  exit 1
fi

DOMAIN_LOWER="au-team.irpo"
ADMIN_USER="Administrator"
ADMIN_PASS="P@ssw0rd"

printf "HQ-CLI cleanup: start\n"

# --- Backup key configs once ---
for f in /etc/samba/smb.conf /etc/nsswitch.conf /etc/pam.d/common-session /etc/resolv.conf; do
  if [[ -f "$f" && ! -f "${f}.bak" ]]; then
    cp -a "$f" "${f}.bak"
  fi
done

# --- Try to leave domain gracefully (if it was joined) ---
# net ads testjoin returns 0 if joined
if command -v net >/dev/null 2>&1; then
  if net ads testjoin >/dev/null 2>&1; then
    printf "Leaving domain...\n"
    net ads leave -U "${ADMIN_USER}%${ADMIN_PASS}" >/dev/null 2>&1 || true
  fi
fi

# --- Stop/disable winbind ---
systemctl stop winbind >/dev/null 2>&1 || true
systemctl disable winbind >/dev/null 2>&1 || true

# --- Remove Samba/winbind join artifacts ---
rm -f /etc/samba/smb.conf >/dev/null 2>&1 || true
rm -f /etc/krb5.keytab >/dev/null 2>&1 || true
rm -rf /var/lib/samba /var/cache/samba /var/run/samba >/dev/null 2>&1 || true

# --- Remove sudoers policy added by script ---
rm -f /etc/sudoers.d/hq_policy >/dev/null 2>&1 || true

# --- Revert nsswitch.conf lines to "files" only (remove winbind if present) ---
if [[ -f /etc/nsswitch.conf ]]; then
  # Replace any "files winbind" or "files  winbind" with just "files"
  sed -i -E 's/^(passwd:\s*.*)files(\s+winbind\b.*)$/passwd:         files/g' /etc/nsswitch.conf
  sed -i -E 's/^(group:\s*.*)files(\s+winbind\b.*)$/group:          files/g' /etc/nsswitch.conf

  # If the above didn’t match (format differs), do a simpler cleanup:
  sed -i -E 's/\s+winbind\b//g' /etc/nsswitch.conf
fi

# --- Disable mkhomedir that pam-auth-update enabled (remove pam_mkhomedir line) ---
if [[ -f /etc/pam.d/common-session ]]; then
  sed -i -E '/pam_mkhomedir\.so/d' /etc/pam.d/common-session
fi

# --- Reset resolv.conf back to systemd-resolved stub if exists, else neutral DNS ---
if [[ -e /run/systemd/resolve/stub-resolv.conf ]]; then
  rm -f /etc/resolv.conf
  ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
else
  rm -f /etc/resolv.conf
  cat <<EOF > /etc/resolv.conf
nameserver 8.8.8.8
EOF
fi

# --- Optional: purge packages installed by join script (оставил выключенным, чтобы не сломать другие зависимости) ---
# apt-get purge -y -q winbind libpam-winbind libnss-winbind krb5-user dnsutils libpam-mkhomedir samba-common-bin || true
# apt-get autoremove -y -q || true

printf "HQ-CLI cleanup: done\n"
printf "Backups (if created): *.bak in /etc\n"