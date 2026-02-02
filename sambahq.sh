#!/usr/bin/env bash
set -euo pipefail

dhcpd_cfg="/etc/dhcp/dhcpd.conf"

# Меняем/добавляем DNS для DHCP: 192.168.3.2
# Учитываем возможные варианты строки (domain-name-servers / domain-name-server)
if grep -Eq '^[[:space:]]*option[[:space:]]+domain-name-servers[[:space:]]+' "$dhcpd_cfg"; then
  sed -i -E 's/^[[:space:]]*option[[:space:]]+domain-name-servers[[:space:]]+.*/option domain-name-servers 192.168.3.2;/' "$dhcpd_cfg"
elif grep -Eq '^[[:space:]]*option[[:space:]]+domain-name-server[[:space:]]+' "$dhcpd_cfg"; then
  sed -i -E 's/^[[:space:]]*option[[:space:]]+domain-name-server[[:space:]]+.*/option domain-name-server 192.168.3.2;/' "$dhcpd_cfg"
else
  printf '\n%s\n' 'option domain-name-servers 192.168.3.2;' >> "$dhcpd_cfg"
fi

systemctl restart isc-dhcp-server