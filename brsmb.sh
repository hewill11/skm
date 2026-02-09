#!/usr/bin/env bash
# Role: BR-SRV (Samba AD DC)
set -euo pipefail

DOMAIN="au-team.irpo"
REALM="AU-TEAM.IRPO"
ADMINPASS="P@ssw0rd" # Пароль администратора домена

# 1. Установка пакетов (без интерактива для Kerberos)
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y acl attr samba samba-dsdb-modules samba-vfs-modules winbind libpam-winbind libnss-winbind krb5-user dnsutils

# 2. Подготовка сети и hostname
# Для AD критично, чтобы имя резолвилось в IP.
# IP BR-SRV = 192.168.200.2 (из Модуля 1)
hostnamectl set-hostname br-srv
cat <<EOF > /etc/hosts
127.0.0.1       localhost
192.168.200.2   br-srv.au-team.irpo br-srv
EOF

# 3. Очистка старого конфига Samba (если есть)
if [ -f /etc/samba/smb.conf ]; then
    mv /etc/samba/smb.conf /etc/samba/smb.conf.bak
fi

# 4. Провиженинг домена
# Только если база данных еще не существует
if [ ! -f /var/lib/samba/private/sam.ldb ]; then
    samba-tool domain provision \
        --use-rfc2307 \
        --realm="${REALM}" \
        --domain="AU-TEAM" \
        --server-role=dc \
        --dns-backend=SAMBA_INTERNAL \
        --adminpass="${ADMINPASS}"
else
    echo "Domain already provisioned."
fi

# 5. Настройка DNS (Forwarder на 8.8.8.8)
# Добавляем форвардер в smb.conf, если его нет
if ! grep -q "dns forwarder" /etc/samba/smb.conf; then
    sed -i "/\[global\]/a \ \ dns forwarder = 8.8.8.8" /etc/samba/smb.conf
fi

# 6. Переключение локального резолва на себя
cat <<EOF > /etc/resolv.conf
search ${DOMAIN}
nameserver 127.0.0.1
EOF

# 7. Запуск сервисов
# Для DC нужно отключить стандартные smbd/nmbd/winbind и включить samba-ad-dc
systemctl stop smbd nmbd winbind || true
systemctl disable smbd nmbd winbind || true
systemctl unmask samba-ad-dc
systemctl enable --now samba-ad-dc

# Даем время на старт
sleep 10

# 8. Создание пользователей и групп
# Создаем группу hq
samba-tool group add hq || echo "Group hq exists"

# Создаем 5 пользователей hquser1..hquser5
for i in {1..5}; do
    USER="hquser$i"
    samba-tool user create "$USER" "$ADMINPASS" || echo "User $USER exists"
    # Добавляем в группу
    samba-tool group addmembers hq "$USER" || echo "User $USER already in group"
done

# Проверка
echo "=== Samba DC Status ==="
samba-tool domain level show
echo "=== Users in group hq ==="
samba-tool group listmembers hq
