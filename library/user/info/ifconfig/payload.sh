#!/bin/bash
# Title: Network Interfaces
# Description: Display all network interfaces with status, IP, and MAC address
# Author: WiFi Pineapple Pager
# Version: 1.1
# Category: Info

# ============================================
# HELPER FUNCTIONS
# ============================================

# Get interface status
get_status() {
    local iface="$1"
    if ip link show "$iface" 2>/dev/null | grep -q "state UP"; then
        echo "UP"
    elif ip link show "$iface" 2>/dev/null | grep -q "state DOWN"; then
        echo "DOWN"
    else
        echo "UNKNOWN"
    fi
}

# Get interface MAC address
get_mac() {
    local iface="$1"
    ip link show "$iface" 2>/dev/null | grep -oE 'link/[a-z]+ [0-9a-f:]+' | awk '{print $2}' | head -n 1
}

# Get interface IPv4 address
get_ipv4() {
    local iface="$1"
    ip -4 addr show "$iface" 2>/dev/null | grep -oE 'inet [0-9.]+' | awk '{print $2}' | head -n 1
}

# Get wireless interface type (if applicable)
get_wireless_type() {
    local iface="$1"
    if command -v iw >/dev/null 2>&1; then
        iw dev "$iface" info 2>/dev/null | grep -oE 'type [a-z]+' | awk '{print $2}'
    fi
}

# ============================================
# MAIN SCRIPT
# ============================================

LOG "=== Network Interfaces ==="
LOG ""

# Check if ip command is available
if ! command -v ip >/dev/null 2>&1; then
    ERROR_DIALOG "Command 'ip' not found"
    LOG red "ERROR: 'ip' command not available"
    exit 1
fi

# Get list of interfaces
interfaces=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | cut -d'@' -f1)

if [ -z "$interfaces" ]; then
    LOG yellow "No network interfaces found"
    exit 0
fi

# Count interfaces
count=$(echo "$interfaces" | wc -l | tr -d ' ')
LOG blue "Found $count interface(s)"
LOG ""
LOG "============================================"

# Display each interface
for iface in $interfaces; do
    LOG ""
    
    # Get interface details
    status=$(get_status "$iface")
    mac=$(get_mac "$iface")
    ipv4=$(get_ipv4 "$iface")
    wireless_type=$(get_wireless_type "$iface")
    
    # Interface name with status color
    case "$status" in
        UP)
            LOG green "[$iface]"
            ;;
        DOWN)
            LOG red "[$iface]"
            ;;
        *)
            LOG yellow "[$iface]"
            ;;
    esac
    
    # Status
    LOG "  Status: $status"
    
    # Wireless type (if applicable)
    if [ -n "$wireless_type" ]; then
        LOG "  Type:   $wireless_type"
    fi
    
    # IP Address
    if [ -n "$ipv4" ]; then
        LOG "  IP:     $ipv4"
    else
        LOG "  IP:     (none)"
    fi
    
    # MAC Address
    if [ -n "$mac" ]; then
        LOG "  MAC:    $mac"
    else
        LOG "  MAC:    (unavailable)"
    fi
done

LOG ""
LOG "============================================"
LOG "Scan complete"
