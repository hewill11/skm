#!/usr/bin/env bash
set -euo pipefail

hn="$(hostname -s 2>/dev/null || true)"
hn_fqdn="$(hostname -f 2>/dev/null || true)"

is_hq_srv=0
is_br_srv=0
is_hq_rtr=0
is_br_rtr=0

case "${hn}" in
  hq-srv) is_hq_srv=1 ;;
  br-srv) is_br_srv=1 ;;
  hq-rtr) is_hq_rtr=1 ;;
  br-rtr) is_br_rtr=1 ;;
esac

# Если hostname задан FQDN'ом или отличается, дополнительно пытаемся матчить по fqdn
case "${hn_fqdn}" in
  hq-srv.*) is_hq_srv=1 ;;
  br-srv.*) is_br_srv=1 ;;
  hq-rtr.*) is_hq_rtr=1 ;;
  br-rtr.*) is_br_rtr=1 ;;
esac

set_password() {
  local user="$1"
  local pass="$2"
  chpasswd <<<"${user}:${pass}"
}

ensure_user() {
  local user="$1"
  local uid="${2:-}"
  local shell="${3:-/bin/bash}"

  if id -u "${user}" >/dev/null 2>&1; then
    if [ -n "${uid}" ]; then
      # Если UID не совпадает — меняем (аккуратно, только если возможно)
      cur_uid="$(id -u "${user}")"
      if [ "${cur_uid}" != "${uid}" ]; then
        usermod -u "${uid}" "${user}"
      fi
    fi
    usermod -s "${shell}" "${user}"
  else
    if [ -n "${uid}" ]; then
      useradd -m -s "${shell}" -u "${uid}" -U "${user}"
    else
      useradd -m -s "${shell}" -U "${user}"
    fi
  fi
}

ensure_sudo_nopasswd() {
  local user="$1"
  usermod -aG sudo "${user}"

  install -d -m 0755 /etc/sudoers.d
  local f="/etc/sudoers.d/${user}-nopasswd"
  umask 022
  cat > "${f}" <<EOF
${user} ALL=(ALL:ALL) NOPASSWD:ALL
EOF
  chmod 0440 "${f}"

  visudo -cf /etc/sudoers
  visudo -cf "${f}"
}

# Выполняем строго по заданию на нужных устройствах
if [ "${is_hq_srv}" -eq 1 ] || [ "${is_br_srv}" -eq 1 ]; then
  ensure_user "sshuser" "2026" "/bin/bash"
  set_password "sshuser" "P@ssw0rd"
  ensure_sudo_nopasswd "sshuser"
fi

if [ "${is_hq_rtr}" -eq 1 ] || [ "${is_br_rtr}" -eq 1 ]; then
  ensure_user "net_admin" "" "/bin/bash"
  set_password "net_admin" "P@ssw0rd"
  ensure_sudo_nopasswd "net_admin"
fi

exit 0
