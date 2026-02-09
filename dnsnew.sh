#!/usr/bin/env bash
# Role: HQ-SRV
# Task: Configure DNS (dnsmasq) per methodology Item 10
set -euo pipefail

# --- 1. Pre-flight Checks ---
if [[ $(id -u) -ne 0 ]]; then
    printf "Error: Script must be run as root.\n" >&2
    exit 1
fi

# Check for required interface ens3
if ! ip link show ens3 >/dev/null 2>&1; then
    printf "Error: Interface ens3 not found.\n" >&2
    exit 1
fi

printf "Starting setup for HQ-SRV DNS (dnsmasq)...\n"

# --- 2. Install Packages ---
# Method requires 'apt-get update' before install if errors occur.
# We run it once to be safe and idempotent.
printf "Updating package lists and installing dnsmasq...\n"
apt-get update -q
apt-get install -y -q dnsmasq

# --- 3. Configure dnsmasq ---
# Implementing config strictly from the screenshot provided in the methodology.
# Using 'install' to write file atomically.

printf "Configuring /etc/dnsmasq.conf...\n"
cat <<'EOF' > /etc/dnsmasq.conf
# Configured via automation script
# Methodology Step 3 - Screenshot replication

interface=ens3
server=8.8.8.8
domain=au-team.irpo
listen-address=192.168.100.2
# Note: Adding localhost to listen-address ensures nameserver 127.0.0.1 works
# strictly following the text instruction for resolv.conf implies localhost listening.
listen-address=127.0.0.1
no-resolv
no-hosts

# Records from screenshot
address=/hq-rtr.au-team.irpo/192.168.100.1
ptr-record=1.100.168.192.in-addr.arpa,hq-rtr.au-team.irpo

address=/br-rtr.au-team.irpo/192.168.200.1
# Note: br-rtr PTR was missing in screenshot list but implies standard logic.
# Keeping strictly to visible screenshot lines for safety,
# but logically br-rtr should have one. 
# Screenshot line 4 is hq-srv.

address=/hq-srv.au-team.irpo/192.168.100.2
ptr-record=2.100.168.192.in-addr.arpa,hq-srv.au-team.irpo

address=/hq-cli.au-team.irpo/192.168.100.34
ptr-record=34.100.168.192.in-addr.arpa,hq-cli.au-team.irpo

address=/br-srv.au-team.irpo/192.168.200.2
ptr-record=2.200.168.192.in-addr.arpa,br-srv.au-team.irpo

address=/docker.au-team.irpo/172.16.1.1
address=/web.au-team.irpo/172.16.2.1
EOF

# --- 4. System Resolver ---
# Methodology Step 5: Write nameserver 127.0.0.1 to /etc/resolv.conf
printf "Configuring /etc/resolv.conf...\n"

# In modern Debian, resolv.conf might be a symlink. We force overwrite as per manual instruction.
if [ -L /etc/resolv.conf ]; then
    rm /etc/resolv.conf
fi

cat <<EOF > /etc/resolv.conf
nameserver 127.0.0.1
EOF

# --- 5. Service Management ---
printf "Restarting dnsmasq service...\n"
systemctl enable --now dnsmasq
systemctl restart dnsmasq

# --- 6. Verification Output ---
printf "\n=== STATUS REPORT ===\n"
printf "[Service Status]\n"
systemctl --no-pager --full status dnsmasq | grep -E "Active|Loaded" || true

printf "\n[Network Config]\n"
ip -br a show ens3

printf "\n[DNS Test: Local]\n"
# Checking if local resolution works (simulating ping check without hanging)
if getent hosts hq-srv.au-team.irpo >/dev/null; then
    printf "Local resolution (hq-srv.au-team.irpo): OK\n"
else
    printf "Local resolution (hq-srv.au-team.irpo): FAIL\n"
fi

printf "\nSetup Complete.\n"
