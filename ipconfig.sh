#!/bin/bash
# Define spam
# LSP (Linux Sanity Pack)
# Linux Sanity Pack — ipconfig (Windows-style for actual adults)
# Maintains sarcasm, parses reality.
#
#      I made this because I agree that Linux is built on the principles of freedom and choice—
#      so I choose the freedom to have a consistent and predictable user experience!
#
# Linux is incredibly powerful and endlessly customizable. But let's be honest—sometimes it's also incredibly annoying.
# Every distro has its own quirks, commands, and philosophies, meaning every switch forces users to relearn the basics again and again.
# If you’re coming from Windows (like most humans on Earth)—a system that has had the same core commands since 1993—
# this just feels unnecessarily painful.
#
# For over 20 years, the open-source community has claimed "we're finally going mainstream!"
# But they still refuse to accept that **people want a user-friendly experience.**
# Instead, Linux and most open-source projects remain stuck in a cycle of terminal dependency, endless config tweaking,
# and shortcut memorization. Sure, there are user-friendly exceptions, but **99% of Linux is still just a glorified
# terminal and or a shortcut simulator. (Thanks Blender 🖕)
#
# LSP aims to reduce that frustration by:
#
#      Providing Windows-like consistency in common commands (e.g., ipconfig, familiar Win+R shortcuts).
#      Eliminating the need to relearn basic operations when you switch distros.
#      Simplifying Linux without taking away any of its power.
#
# Because choosing Linux shouldn’t mean choosing constant frustration.
# Enjoy Linux your way—sanely, simply, consistently.
#

set -u

# --- Detect Interface ---
INTERFACE=$(ip route | awk '/^default/ {print $5; exit}')
[[ -z "$INTERFACE" ]] && INTERFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<NF;i++) if ($i=="dev") print $(i+1); exit}')
if [[ -z "$INTERFACE" || ! -d "/sys/class/net/$INTERFACE" ]]; then
    echo "[ERROR] Could not determine a usable network interface."
    exit 1
fi

# --- CIDR → Subnet ---
cidr_to_mask() {
    local i cidr=${1:-0} mask=""
    [[ "$cidr" -eq 0 ]] && { echo "0.0.0.0"; return; }
    
    for ((i=0; i<4; i++)); do
        local n=0
        if (( cidr >= 8 )); then
            n=8
        elif (( cidr > 0 )); then
            n=$cidr
        else
            n=0
        fi
        
        if (( n > 0 )); then
            mask+=$(( (256 - (1 << (8 - n))) & 255 ))
        else
            mask+="0"
        fi
        
        (( i < 3 )) && mask+="."
        (( cidr -= n ))
    done
    echo "$mask"
}

bytes_human() {
    awk -v b="$1" 'BEGIN {
        split("B KB MB GB TB", u); i=1;
        while (b>=1024 && i<5) { b/=1024; i++ }
        printf "%.2f %s", b, u[i]
    }'
}

# --- System Info ---
OS_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d \")
KERNEL=$(uname -r)
HOST=$(hostname)

# --- Interface Info ---
MAC=$(cat "/sys/class/net/$INTERFACE/address" | tr '[:lower:]' '[:upper:]')

# Simplified Description Logic
BUS_ID=$(basename "$(readlink "/sys/class/net/$INTERFACE/device" 2>/dev/null || echo "none")")
DESC=$(lspci -nn 2>/dev/null | grep -i "$BUS_ID" | head -1 | awk -F'[][]' '{print "0x"$2 " 0x"$4}')
[[ -z "$DESC" ]] && DESC="Network Adapter ($INTERFACE)"

# Grab IP and CIDR
IPV4_RAW=$(ip -4 addr show "$INTERFACE" | grep -oP 'inet \K[\d./]+' | head -n 1)
IPV4=${IPV4_RAW%/*}
CIDR=${IPV4_RAW#*/}
[[ "$CIDR" == "$IPV4" ]] && CIDR=32

MASK=$(cidr_to_mask "$CIDR")
GW=$(ip route | awk '/^default/ {print $3; exit}')
DNS=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | paste -sd' ' || echo "None")
DHCP=$(ip -o -4 addr show "$INTERFACE" | grep -q dynamic && echo "Yes" || echo "No")

# --- Output ---
echo -e "\nLinux Operating System"
echo "Copyright (c) 2025 Linux Foundation. All rights reserved."
echo
echo "Linux IP Configuration"
echo
echo "Operating System . . . . . . . . : $OS_NAME"
echo "Kernel Version . . . . . . . . . : $KERNEL"
echo "Host Name . . . . . . . . . . .  : $HOST"
echo
echo "Interface: $INTERFACE"
echo "Description . . . . . . . . . . . : $DESC"
echo "Physical Address. . . . . . . . . : $MAC"
echo "DHCP Enabled. . . . . . . . . . . : $DHCP"
echo "IPv4 Address. . . . . . . . . . . : $IPV4"
echo "Subnet Mask . . . . . . . . . . . : $MASK"
echo "Default Gateway . . . . . . . . . : ${GW:-None}"
echo "DNS Servers . . . . . . . . . . . : $DNS"
echo "NetBIOS over Tcpip. . . . . . . . : Microsoft Moment 69™"

if [[ "${1:-}" == "/all" ]]; then
    echo
    echo "Extended Network Information:"
    echo "--------------------------------"
    ip -o -6 addr show "$INTERFACE" | awk '{print $4}' | while read -r line; do
        printf "IPv6 Address. . . . . . . . . . . : %s\n" "$line"
    done
    echo "MTU Size. . . . . . . . . . . . . : $(cat "/sys/class/net/$INTERFACE/mtu")"
    echo "Interface State. . . . . . . . .  : $(cat "/sys/class/net/$INTERFACE/operstate")"
    RX=$(cat "/sys/class/net/$INTERFACE/statistics/rx_bytes")
    TX=$(cat "/sys/class/net/$INTERFACE/statistics/tx_bytes")
    echo "RX Bytes. . . . . . . . . . . . . : $(bytes_human "$RX") ($RX bytes)"
    echo "TX Bytes. . . . . . . . . . . . . : $(bytes_human "$TX") ($TX bytes)"
    echo "DHCP Lease Info. . . . . . . . .  : No lease information found."
fi
echo
