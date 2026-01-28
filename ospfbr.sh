#!/usr/bin/env bash
set -euo pipefail

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y frr

# Включаем ospfd
sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons

systemctl restart frr

# Конфигурация OSPF (как в модуле)
vtysh <<'EOF'
conf t
 router ospf
  router-id 2.2.2.2
  no passive-interface default
  network 192.168.200.0/28 area 0
  network 10.10.0.0/30 area 0
  area 0 authentication
 exit
 interface tun1
  no ip ospf passive
  no ip ospf network broadcast
  ip ospf authentication
  ip ospf authentication-key password
 exit
end
write
EOF

reboot
#После установки и применение скриптов, прописать на каждом устройстве строку
#nano /etc/frr/daemons -> zebra=yes
#systemctl restart frr
