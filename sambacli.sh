#!/usr/bin/env bash
set -euo pipefail

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y samba smbclient winbind libnss-winbind krb5-user net-tools

# Бэкап smb.conf один раз
if [ -f /etc/samba/smb.conf ] && [ ! -f /etc/samba/smb.conf.bak ]; then
  mv /etc/samba/smb.conf /etc/samba/smb.conf.bak
fi

# Останавливаем службы (как в задании)
systemctl stop smbd nmbd winbind || true
systemctl stop samba-ad-dc || true

# Провижен домена выполняем только если домена ещё нет
# Признак существующего домена: sam.ldb
if [ ! -f /var/lib/samba/private/sam.ldb ]; then
  # ВНИМАНИЕ: команда интерактивная (как в твоём списке)
  samba-tool domain provision --use-rfc2307 --interactive
fi

# Старт служб (как в задании)
systemctl start smbd nmbd winbind
systemctl start samba-ad-dc

# Копируем kerberos конфиг (как в задании)
if [ -f /var/lib/samba/private/krb5.conf ]; then
  cp -f /var/lib/samba/private/krb5.conf /etc/krb5.conf
fi

# Создаём группу hq (если нет)
if ! samba-tool group list | grep -qx 'hq'; then
  samba-tool group add hq
fi

# Функции: создать пользователя если нет, и добавить в группу
ensure_user() {
  local u="$1"
  local p="$2"
  if ! samba-tool user list | grep -qx "$u"; then
    samba-tool user create "$u" "$p"
  fi
}

ensure_group_member() {
  local g="$1"
  local u="$2"
  if ! samba-tool group listmembers "$g" | grep -qx "$u"; then
    samba-tool group addmembers "$g" "$u"
  fi
}

# Пользователи (как в задании) + членство в группе
ensure_user hquser1 '1'
ensure_group_member hq hquser1

ensure_user hquser2 '1'
ensure_group_member hq hquser2

ensure_user hquser3 '1'
ensure_group_member hq hquser3

ensure_user hquser4 '1'
ensure_group_member hq hquser4

ensure_user hquser5 '1'
ensure_group_member hq hquser5