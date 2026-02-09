#!/usr/bin/env bash
# Role: HQ-CLI (Domain Join)
set -euo pipefail

DOMAIN="au-team.irpo"
REALM="AU-TEAM.IRPO"
DC_IP="192.168.200.2" # IP адрес BR-SRV
ADMINPASS="P@ssw0rd"

# 1. Установка пакетов
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y winbind libpam-winbind libnss-winbind krb5-user dnsutils libpam-mkhomedir

# 2. Настройка DNS для поиска домена
# ВАЖНО: Мы должны указывать на BR-SRV, чтобы найти SRV записи LDAP/Kerberos
cat <<EOF > /etc/resolv.conf
search ${DOMAIN}
nameserver ${DC_IP}
nameserver 8.8.8.8
EOF

# 3. Ввод в домен
# Проверяем, не введены ли мы уже (наличие keytab)
if [ ! -f /etc/krb5.keytab ]; then
    # Используем net ads join (через samba-tool тоже можно, но net ads классика для клиентов)
    # Предварительно настроим минимальный smb.conf для клиента
    cat <<EOF > /etc/samba/smb.conf
[global]
   workgroup = AU-TEAM
   security = ads
   realm = ${REALM}
   winbind refresh tickets = yes
   winbind use default domain = yes
   winbind offline logon = yes
   template shell = /bin/bash
   idmap config * : range = 10000-20000
   idmap config * : backend = tdb
EOF

    # Ввод в домен
    net ads join -U "administrator%${ADMINPASS}"
else
    echo "Already joined (keytab exists)."
fi

# 4. Настройка nsswitch (чтобы система видела winbind пользователей)
# Если строки winbind нет, добавляем её
if ! grep -q "winbind" /etc/nsswitch.conf; then
    sed -i 's/passwd:         files systemd/passwd:         files systemd winbind/' /etc/nsswitch.conf
    sed -i 's/group:          files systemd/group:          files systemd winbind/' /etc/nsswitch.conf
fi

# 5. Автосоздание домашних директорий (PAM)
# Включаем pam_mkhomedir
pam-auth-update --enable mkhomedir

# Перезапуск winbind для применения настроек
systemctl restart winbind
systemctl enable winbind

# 6. Настройка SUDO (Права для группы hq)
# Требование: cat, grep, id. Группы права не имеют (только пользователи группы).
# В sudoers %group означает группу.
# В AD группа hq может видеться как "hq" (из-за winbind use default domain = yes).
cat <<EOF > /etc/sudoers.d/hq-users
%hq ALL=(ALL) /usr/bin/cat, /usr/bin/grep, /usr/bin/id
EOF
chmod 0440 /etc/sudoers.d/hq-users

# === Проверка ===
echo "=== Testing User Visibility ==="
# Ждем пару секунд, пока winbind закэширует
sleep 5
wbinfo -u | grep hquser1 || echo "FAIL: hquser1 not found via wbinfo"
id hquser1 || echo "FAIL: hquser1 not found via id"

echo "=== Setup Complete ==="
