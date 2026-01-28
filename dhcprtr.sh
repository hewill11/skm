#!/usr/bin/env bash
set -euo pipefail

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y isc-dhcp-server

# /etc/default/isc-dhcp-server -> INTERFACESv4="vlan200"
cfg_default="/etc/default/isc-dhcp-server"
if [ -f "${cfg_default}" ]; then
  if grep -Eq '^INTERFACESv4=' "${cfg_default}"; then
    sed -i 's/^INTERFACESv4=.*/INTERFACESv4="vlan200"/' "${cfg_default}"
  else
    printf '%s\n' 'INTERFACESv4="vlan200"' >> "${cfg_default}"
  fi
else
  install -m 0644 /dev/null "${cfg_default}"
  printf '%s\n' 'INTERFACESv4="vlan200"' >> "${cfg_default}"
fi

# /etc/dhcp/dhcpd.conf правим две строки и добавляем subnet-блок в конец (как в модуле)
dhcpd_cfg="/etc/dhcp/dhcpd.conf"

# option domain-name "au-team.irpo";
if grep -Eq '^[#[:space:]]*option[[:space:]]+domain-name[[:space:]]+' "${dhcpd_cfg}"; then
  sed -i 's/^[#[:space:]]*option[[:space:]]\+domain-name[[:space:]]\+.*/option domain-name "au-team.irpo";/' "${dhcpd_cfg}"
else
  printf '%s\n' 'option domain-name "au-team.irpo";' >> "${dhcpd_cfg}"
fi

# option domain-name-servers 192.168.100.2;
if grep -Eq '^[#[:space:]]*option[[:space:]]+domain-name-servers[[:space:]]+' "${dhcpd_cfg}"; then
  sed -i 's/^[#[:space:]]*option[[:space:]]\+domain-name-servers[[:space:]]\+.*/option domain-name-servers 192.168.100.2;/' "${dhcpd_cfg}"
else
  printf '%s\n' 'option domain-name-servers 192.168.100.2;' >> "${dhcpd_cfg}"
fi

# subnet block (если нет — добавляем в конец)
if ! grep -Eq '^[[:space:]]*subnet[[:space:]]+192\.168\.100\.32[[:space:]]+netmask[[:space:]]+255\.255\.255\.240' "${dhcpd_cfg}"; then
  cat >> "${dhcpd_cfg}" <<'EOF'

subnet 192.168.100.32 netmask 255.255.255.240 {
  range 192.168.100.34 192.168.100.47;
  option routers 192.168.100.33;
}
EOF
fi

systemctl restart isc-dhcp-server
