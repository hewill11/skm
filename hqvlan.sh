#!/usr/bin/env bash
set -euo pipefail

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y openvswitch-switch

# Создаем мост (если уже есть — не трогаем)
if ! ovs-vsctl br-exists hq-sw; then
  ovs-vsctl add-br hq-sw
fi

# Физические порты с тегами (как в модуле)
if ! ovs-vsctl list-ports hq-sw | grep -qx 'ens4'; then
  ovs-vsctl add-port hq-sw ens4 tag=100
else
  ovs-vsctl set port ens4 tag=100
fi

if ! ovs-vsctl list-ports hq-sw | grep -qx 'ens5'; then
  ovs-vsctl add-port hq-sw ens5 tag=200
else
  ovs-vsctl set port ens5 tag=200
fi

if ! ovs-vsctl list-ports hq-sw | grep -qx 'ens6'; then
  ovs-vsctl add-port hq-sw ens6 tag=999
else
  ovs-vsctl set port ens6 tag=999
fi

# Internal VLAN интерфейсы (как в модуле)
ensure_internal_vlan() {
  local ifname="$1"
  local tag="$2"

  if ! ovs-vsctl list-ports hq-sw | grep -qx "${ifname}"; then
    ovs-vsctl add-port hq-sw "${ifname}" tag="${tag}" -- set interface "${ifname}" type=internal
  else
    ovs-vsctl set port "${ifname}" tag="${tag}"
    ovs-vsctl set interface "${ifname}" type=internal
  fi
}

ensure_internal_vlan vlan100 100
ensure_internal_vlan vlan200 200
ensure_internal_vlan vlan999 999

# /etc/network/interfaces (ровно как в модуле по смыслу)
install -m 0644 /dev/null /etc/network/interfaces
cat > /etc/network/interfaces <<'EOF'
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto ens3
iface ens3 inet static
 address 172.16.1.2/28
 gateway 172.16.1.1

auto vlan100
iface vlan100 inet static
 address 192.168.100.1/27

auto vlan200
iface vlan200 inet static
 address 192.168.100.33/28

auto vlan999
iface vlan999 inet static
 address 192.168.100.49/29

post-up nft -f /etc/nftables.conf
post-up ip link set hq-sw up
EOF

# Поднимаем мост (как в модуле post-up)
ip link set hq-sw up || true

systemctl restart networking
