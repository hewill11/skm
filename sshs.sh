#!/usr/bin/env bash
set -euo pipefail

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server

# Баннер (как на скрине: рамка из звездочек и текст)
install -m 0644 /dev/null /etc/ssh_banner
cat > /etc/ssh_banner <<'EOF'
****************************
*  Authorized access only  *
****************************
EOF

sshd_cfg="/etc/ssh/sshd_config"

# Гарантируем наличие нужных директив (один-в-один по смыслу со скрином)
# 1) Port 2026
# 2) AllowUsers sshuser
# 3) MaxAuthTries 2
# 4) Banner /etc/ssh_banner
ensure_sshd_kv() {
  local key="$1"
  local val="$2"

  if grep -Eq "^[#[:space:]]*${key}[[:space:]]+" "${sshd_cfg}"; then
    sed -i -E "s|^[#[:space:]]*${key}[[:space:]]+.*|${key} ${val}|g" "${sshd_cfg}"
  else
    printf '%s %s\n' "${key}" "${val}" >> "${sshd_cfg}"
  fi
}

ensure_sshd_kv "Port" "2026"
ensure_sshd_kv "AllowUsers" "sshuser"
ensure_sshd_kv "MaxAuthTries" "2"
ensure_sshd_kv "Banner" "/etc/ssh_banner"

# Проверяем конфиг и перезапускаем SSH (как на скрине)
sshd -t
systemctl restart ssh
