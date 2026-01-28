#!/usr/bin/env bash
set -euo pipefail

install -m 0644 /dev/null /etc/network/interfaces
cat > /etc/network/interfaces <<'EOF'
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

auto ens3
iface ens3 inet static
 address 172.16.1.2/28
 gateway 172.16.1.1

post-up nft -f /etc/nftables.conf
EOF

install -d -m 0755 /etc/sysctl.d
if [ ! -f /etc/sysctl.d/sysctl.conf ]; then
  install -m 0644 /dev/null /etc/sysctl.d/sysctl.conf
fi
grep -v '^net\.ipv4\.ip_forward=' /etc/sysctl.d/sysctl.conf > /tmp/sysctl.conf.$$ || true
printf '%s\n' 'net.ipv4.ip_forward=1' >> /tmp/sysctl.conf.$$
install -m 0644 /tmp/sysctl.conf.$$ /etc/sysctl.d/sysctl.conf
rm -f /tmp/sysctl.conf.$$

sysctl --system

# NAT по модулю тоже делается на HQ-RTR (из задания 8)
install -m 0644 /dev/null /etc/nftables.conf
cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f

flush ruleset

table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        meta l4proto { gre, ipip, ospf } counter return
        masquerade
    }
}

table inet filter {
    chain input {
        type filter hook input priority filter;
    }

    chain forward {
        type filter hook forward priority filter;
    }

    chain output {
        type filter hook output priority filter;
    }
}
EOF

nft -f /etc/nftables.conf
systemctl restart networking

#На следующем этапе вписываем на br-rtr
#auto ens3
#iface ens3 inet static
# address 172.16.2.2/28
# gateway 172.16.2.1
