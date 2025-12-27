#!/bin/bash
# Title: Bluetooth Scanner
# Description: Scans for nearby Bluetooth devices (Classic and BLE) and displays results
# Author: Community
# Version: 1.0
# Category: Reconnaissance
#
# WARNING: For authorized testing only. Unauthorized use is illegal.
#
# This script uses hcitool to discover nearby Bluetooth devices.
# Results are saved to the loot folder in greppable format.

# ============================================
# OPTIONS - Configure before running
# ============================================

# Loot directory for saving scan results
LOOTDIR=/root/loot/bluetooth_scanner

# Default Bluetooth adapter
BT_ADAPTER="hci0"

# ============================================
# INTERNAL FILES - Temp files and state
# ============================================

TEMP_CLASSIC="/tmp/bt_scan_classic.txt"
TEMP_BLE="/tmp/bt_scan_ble.txt"
CANCEL_FLAG="/tmp/bt_scan_cancel"

# Process tracking (initialize early!)
SCAN_PID=""
LISTENER_PID=""
START_TIME=""

# Scan configuration (set by user)
SCAN_TYPE=""
SCAN_DURATION=""
DURATION_SECONDS=0

# ============================================
# CLEANUP - Set trap EARLY
# ============================================

# Cleanup function called on script exit.
# Kills background processes, resets adapter state, removes temp files.
cleanup() {
    LOG "Cleaning up..."
    
    # Kill background listener if running
    if [ -n "$LISTENER_PID" ] && kill -0 "$LISTENER_PID" 2>/dev/null; then
        kill "$LISTENER_PID" 2>/dev/null
        wait "$LISTENER_PID" 2>/dev/null
    fi
    
    # Kill scan process if running
    if [ -n "$SCAN_PID" ] && kill -0 "$SCAN_PID" 2>/dev/null; then
        kill "$SCAN_PID" 2>/dev/null
        wait "$SCAN_PID" 2>/dev/null
    fi
    
    # Stop any ongoing BLE scan (lescan keeps running until killed)
    pkill -f "hcitool lescan" 2>/dev/null
    
    # Clean temp files
    rm -f "$TEMP_CLASSIC" "$TEMP_BLE" "$CANCEL_FLAG"
}

trap cleanup EXIT

# ============================================
# HELPER FUNCTIONS
# ============================================

# Get elapsed time since START_TIME in MM:SS format.
# Returns: Formatted elapsed time string
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

# Check if required Bluetooth tools are installed.
# Returns: 0 if all dependencies present, 1 otherwise
check_dependencies() {
    local missing=""
    
    # Check for hcitool (BlueZ)
    if ! command -v hcitool &>/dev/null; then
        missing="$missing hcitool"
    fi
    
    # Check for hciconfig
    if ! command -v hciconfig &>/dev/null; then
        missing="$missing hciconfig"
    fi
    
    if [ -n "$missing" ]; then
        LOG red "Missing dependencies:$missing"
        return 1
    fi
    
    return 0
}

# Verify Bluetooth adapter is present and bring it up.
# Returns: 0 if adapter ready, 1 otherwise
check_bluetooth_adapter() {
    # Check if adapter exists
    if ! hciconfig "$BT_ADAPTER" &>/dev/null; then
        LOG red "Bluetooth adapter $BT_ADAPTER not found"
        return 1
    fi
    
    # Bring adapter up if down
    local status=$(hciconfig "$BT_ADAPTER" | grep -o "UP\|DOWN")
    if [ "$status" = "DOWN" ]; then
        LOG "Bringing up $BT_ADAPTER..."
        hciconfig "$BT_ADAPTER" up
        sleep 1
        
        # Verify it came up
        status=$(hciconfig "$BT_ADAPTER" | grep -o "UP\|DOWN")
        if [ "$status" != "UP" ]; then
            LOG red "Failed to bring up $BT_ADAPTER"
            return 1
        fi
    fi
    
    LOG green "Bluetooth adapter $BT_ADAPTER is UP"
    return 0
}

# Parse Bluetooth device class code into human-readable type.
# Args: class_hex - The device class in hex format
# Returns: Human-readable device type
parse_device_class() {
    local class_hex="$1"
    
    # Major device class is bits 8-12 of the class
    # We extract it from the hex value
    local major=$(( (0x$class_hex >> 8) & 0x1F ))
    
    case $major in
        1) echo "Computer" ;;
        2) echo "Phone" ;;
        3) echo "LAN/Network" ;;
        4) echo "Audio/Video" ;;
        5) echo "Peripheral" ;;
        6) echo "Imaging" ;;
        7) echo "Wearable" ;;
        8) echo "Toy" ;;
        9) echo "Health" ;;
        *) echo "Unknown" ;;
    esac
}

# Get manufacturer from OUI (first 3 bytes of MAC).
# Basic lookup for common manufacturers.
# Args: mac - The MAC address
# Returns: Manufacturer name or "Unknown"
get_manufacturer() {
    local mac="$1"
    local oui=$(echo "$mac" | tr ':' ' ' | awk '{print toupper($1$2$3)}')
    
    # Common Bluetooth OUIs
    case "$oui" in
        "001A7D"|"3C5A37"|"88C6") echo "Apple" ;;
        "001E4C"|"0019E3"|"30AED0") echo "Samsung" ;;
        "9C8CD8"|"B8D7AF"|"F0D4F6") echo "Sony" ;;
        "001378"|"001E7D"|"F8D0BD") echo "Bose" ;;
        "000272"|"A0143D"|"60AB67") echo "JBL" ;;
        "001558"|"94659C"|"D022BE") echo "Intel" ;;
        "00037A"|"000F00"|"001560") echo "Dell" ;;
        "0025BC"|"6CB7F4"|"F0B429") echo "HP" ;;
        "0018E4"|"30E171"|"F0DEF1") echo "Microsoft" ;;
        "0017C9"|"001D6B"|"3478D7") echo "Lenovo" ;;
        "FC253F"|"FCE998"|"00E091") echo "Google" ;;
        "94B86D"|"94E979"|"5C969D") echo "Xiaomi" ;;
        "1C66AA"|"20DBED"|"ECA86B") echo "Huawei" ;;
        "58404E"|"7CBB8A"|"D46E5C") echo "Logitech" ;;
        "6C72E7"|"E8D0FC"|"F0FE6B") echo "Beats" ;;
        *) echo "Unknown" ;;
    esac
}

# Perform Classic Bluetooth scan.
# Writes results to TEMP_CLASSIC file.
scan_classic_bluetooth() {
    LOG "Starting Classic Bluetooth scan..."
    
    # Run inquiry scan
    # hcitool scan outputs: MAC_ADDRESS   Device_Name
    if [ "$DURATION_SECONDS" -gt 0 ]; then
        # Timed scan (approximate - scan takes ~10s per inquiry)
        timeout "$DURATION_SECONDS" hcitool -i "$BT_ADAPTER" scan 2>/dev/null | tail -n +2 > "$TEMP_CLASSIC"
    else
        # Continuous until cancelled
        hcitool -i "$BT_ADAPTER" scan 2>/dev/null | tail -n +2 > "$TEMP_CLASSIC" &
        SCAN_PID=$!
    fi
}

# Perform BLE (Bluetooth Low Energy) scan.
# Writes results to TEMP_BLE file.
scan_ble_devices() {
    LOG "Starting BLE scan..."
    
    # lescan outputs continuously, so we capture unique devices
    # Format: MAC_ADDRESS (Device_Name or "unknown")
    if [ "$DURATION_SECONDS" -gt 0 ]; then
        # Timed scan
        timeout "$DURATION_SECONDS" stdbuf -oL hcitool -i "$BT_ADAPTER" lescan 2>/dev/null | \
            grep -v "^LE Scan" | sort -u > "$TEMP_BLE" &
        SCAN_PID=$!
        
        # Wait for scan to complete
        wait "$SCAN_PID" 2>/dev/null
        SCAN_PID=""
    else
        # Continuous until cancelled
        stdbuf -oL hcitool -i "$BT_ADAPTER" lescan 2>/dev/null | \
            grep -v "^LE Scan" | sort -u > "$TEMP_BLE" &
        SCAN_PID=$!
    fi
}

# Check if scan has been cancelled by user.
# Returns: 0 if cancelled, 1 otherwise
is_cancelled() {
    [ -f "$CANCEL_FLAG" ]
}

# Count lines in a file (0 if empty or doesn't exist).
# Args: file - Path to file
# Returns: Line count
count_lines() {
    local file="$1"
    if [ -f "$file" ] && [ -s "$file" ]; then
        wc -l < "$file" | tr -d ' '
    else
        echo "0"
    fi
}

# Write scan summary to file.
write_summary() {
    local scan_time=$(date -Is)
    local classic_count=$(count_lines "$LOOTDIR/classic_devices.txt")
    local ble_count=$(count_lines "$LOOTDIR/ble_devices.txt")
    local elapsed=$(get_elapsed_time)
    
    cat > "$LOOTDIR/summary.txt" <<EOF
SCAN_TIME=$scan_time
SCAN_TYPE=$SCAN_TYPE
SCAN_DURATION=$SCAN_DURATION
ELAPSED=$elapsed
CLASSIC_DEVICES=$classic_count
BLE_DEVICES=$ble_count
ADAPTER=$BT_ADAPTER
EOF
}

# ============================================
# MAIN SCRIPT
# ============================================

LOG "=== Bluetooth Scanner ==="
LOG ""

# Create loot directory
mkdir -p "$LOOTDIR"

# Check dependencies
LOG "Checking dependencies..."
if ! check_dependencies; then
    ERROR_DIALOG "Missing required tools. Install bluez package:\nopkg install bluez-utils bluez-tools"
    exit 1
fi
LOG green "Dependencies OK"

# Check Bluetooth adapter
LOG "Checking Bluetooth adapter..."
if ! check_bluetooth_adapter; then
    ERROR_DIALOG "Bluetooth adapter not available.\nEnsure Bluetooth hardware is present and enabled."
    exit 1
fi
LOG ""

# ============================================
# SELECT SCAN TYPE
# ============================================

PROMPT "Select scan type:\n\n1. Classic Bluetooth\n   - Traditional devices\n   - Phones, headphones, etc.\n\n2. BLE (Low Energy)\n   - IoT devices, beacons\n   - Fitness trackers\n\n3. Both\n   - Comprehensive scan"

scan_type_idx=$(NUMBER_PICKER "Select scan type (1-3)" "3")
case $? in
    $DUCKYSCRIPT_CANCELLED)
        LOG "User cancelled"
        exit 0
        ;;
    $DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        LOG "Dialog error"
        exit 1
        ;;
esac

# Validate and set scan type
case "$scan_type_idx" in
    1) SCAN_TYPE="classic" ;;
    2) SCAN_TYPE="ble" ;;
    3) SCAN_TYPE="both" ;;
    *)
        LOG yellow "Invalid selection, using 'both'"
        SCAN_TYPE="both"
        ;;
esac
LOG "Selected scan type: $SCAN_TYPE"
LOG ""

# ============================================
# SELECT DURATION
# ============================================

PROMPT "Select scan duration:\n\n1. Quick (10 sec)\n   - Fast discovery\n\n2. Normal (30 sec)\n   - Balanced scan\n\n3. Extended (60 sec)\n   - Thorough scan\n\n4. Continuous\n   - Until cancelled"

duration_idx=$(NUMBER_PICKER "Select duration (1-4)" "2")
case $? in
    $DUCKYSCRIPT_CANCELLED)
        LOG "User cancelled"
        exit 0
        ;;
    $DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        LOG "Dialog error"
        exit 1
        ;;
esac

# Validate and set duration
case "$duration_idx" in
    1)
        SCAN_DURATION="quick"
        DURATION_SECONDS=10
        ;;
    2)
        SCAN_DURATION="normal"
        DURATION_SECONDS=30
        ;;
    3)
        SCAN_DURATION="extended"
        DURATION_SECONDS=60
        ;;
    4)
        SCAN_DURATION="continuous"
        DURATION_SECONDS=0
        ;;
    *)
        LOG yellow "Invalid selection, using 'normal'"
        SCAN_DURATION="normal"
        DURATION_SECONDS=30
        ;;
esac

if [ "$DURATION_SECONDS" -gt 0 ]; then
    LOG "Selected duration: $SCAN_DURATION (${DURATION_SECONDS}s)"
else
    LOG "Selected duration: $SCAN_DURATION (until cancelled)"
fi
LOG ""

# ============================================
# CONFIRM AND START
# ============================================

confirm_msg="Start $SCAN_TYPE scan"
if [ "$DURATION_SECONDS" -gt 0 ]; then
    confirm_msg="$confirm_msg for ${DURATION_SECONDS}s?"
else
    confirm_msg="$confirm_msg (continuous)?"
fi

resp=$(CONFIRMATION_DIALOG "$confirm_msg")
case $? in
    $DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        LOG "Dialog error"
        exit 1
        ;;
esac

case "$resp" in
    $DUCKYSCRIPT_USER_CONFIRMED)
        LOG "Starting scan..."
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

# ============================================
# RUN SCAN
# ============================================

LOG ""
LOG "============================================"
LOG "=== Scanning for Bluetooth Devices ==="
LOG "============================================"
LOG ""
LOG "Type: $SCAN_TYPE"
if [ "$DURATION_SECONDS" -gt 0 ]; then
    LOG "Duration: ${DURATION_SECONDS} seconds"
else
    LOG "Duration: Continuous (press any button to stop)"
fi
LOG ""

# Initialize temp files
> "$TEMP_CLASSIC"
> "$TEMP_BLE"

# Initialize cancel flag
rm -f "$CANCEL_FLAG"

# Record start time
START_TIME=$(date +%s)

# Start background cancel listener for continuous mode
if [ "$DURATION_SECONDS" -eq 0 ]; then
    (
        resp=$(WAIT_FOR_INPUT)
        touch "$CANCEL_FLAG"
        LOG yellow "Cancel requested (pressed: $resp)..."
    ) &
    LISTENER_PID=$!
fi

# Run appropriate scan(s)
case "$SCAN_TYPE" in
    classic)
        scan_classic_bluetooth
        
        # For timed scans, wait with cancel check
        if [ "$DURATION_SECONDS" -gt 0 ]; then
            LOG "Scanning for ${DURATION_SECONDS}s... (this may take a moment)"
        else
            # Continuous mode - wait for cancel or completion
            while [ -n "$SCAN_PID" ] && kill -0 "$SCAN_PID" 2>/dev/null; do
                if is_cancelled; then
                    LOG yellow "Stopping scan..."
                    kill "$SCAN_PID" 2>/dev/null
                    wait "$SCAN_PID" 2>/dev/null
                    SCAN_PID=""
                    break
                fi
                sleep 1
            done
        fi
        ;;
    ble)
        scan_ble_devices
        
        # For continuous mode, monitor until cancelled
        if [ "$DURATION_SECONDS" -eq 0 ]; then
            while [ -n "$SCAN_PID" ] && kill -0 "$SCAN_PID" 2>/dev/null; do
                if is_cancelled; then
                    LOG yellow "Stopping scan..."
                    kill "$SCAN_PID" 2>/dev/null
                    wait "$SCAN_PID" 2>/dev/null
                    SCAN_PID=""
                    break
                fi
                # Show progress
                local ble_count=$(count_lines "$TEMP_BLE")
                LOG "Discovered: $ble_count BLE devices | Elapsed: $(get_elapsed_time)"
                sleep 3
            done
        else
            # Wait for timed scan to complete
            LOG "Scanning for ${DURATION_SECONDS}s..."
            wait "$SCAN_PID" 2>/dev/null
            SCAN_PID=""
        fi
        ;;
    both)
        # Run Classic first, then BLE
        LOG "Phase 1/2: Classic Bluetooth..."
        
        if [ "$DURATION_SECONDS" -gt 0 ]; then
            # Split time between Classic and BLE
            local half_duration=$((DURATION_SECONDS / 2))
            timeout "$half_duration" hcitool -i "$BT_ADAPTER" scan 2>/dev/null | tail -n +2 > "$TEMP_CLASSIC"
            
            if is_cancelled; then
                LOG yellow "Cancelled during Classic scan"
            else
                LOG "Phase 2/2: BLE..."
                timeout "$half_duration" stdbuf -oL hcitool -i "$BT_ADAPTER" lescan 2>/dev/null | \
                    grep -v "^LE Scan" | sort -u > "$TEMP_BLE"
            fi
        else
            # Continuous mode - alternate or run both
            scan_classic_bluetooth
            
            # Wait for classic scan to finish or cancel
            while [ -n "$SCAN_PID" ] && kill -0 "$SCAN_PID" 2>/dev/null; do
                if is_cancelled; then
                    LOG yellow "Stopping scan..."
                    kill "$SCAN_PID" 2>/dev/null
                    wait "$SCAN_PID" 2>/dev/null
                    SCAN_PID=""
                    break
                fi
                sleep 1
            done
            
            if ! is_cancelled; then
                LOG "Phase 2/2: BLE..."
                scan_ble_devices
                
                while [ -n "$SCAN_PID" ] && kill -0 "$SCAN_PID" 2>/dev/null; do
                    if is_cancelled; then
                        LOG yellow "Stopping scan..."
                        kill "$SCAN_PID" 2>/dev/null
                        wait "$SCAN_PID" 2>/dev/null
                        SCAN_PID=""
                        break
                    fi
                    sleep 1
                done
            fi
        fi
        ;;
esac

# Kill listener if still running
if [ -n "$LISTENER_PID" ] && kill -0 "$LISTENER_PID" 2>/dev/null; then
    kill "$LISTENER_PID" 2>/dev/null
    wait "$LISTENER_PID" 2>/dev/null
fi
LISTENER_PID=""

# Calculate elapsed time
elapsed=$(get_elapsed_time)

LOG ""
LOG "============================================"
LOG "=== Processing Results ==="
LOG "============================================"
LOG ""

# ============================================
# PARSE AND SAVE RESULTS
# ============================================

timestamp=$(date +%Y%m%d_%H%M%S)

# Process Classic Bluetooth results
> "$LOOTDIR/classic_devices.txt"
if [ -f "$TEMP_CLASSIC" ] && [ -s "$TEMP_CLASSIC" ]; then
    LOG "Processing Classic Bluetooth devices..."
    
    while IFS= read -r line; do
        # Format: MAC_ADDRESS   Device_Name
        local mac=$(echo "$line" | awk '{print $1}')
        local name=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^[[:space:]]*//')
        
        if [ -n "$mac" ]; then
            local manufacturer=$(get_manufacturer "$mac")
            
            # Save in greppable format: MAC:NAME:MANUFACTURER
            echo "$mac:$name:$manufacturer" >> "$LOOTDIR/classic_devices.txt"
            
            LOG green "  $mac - $name ($manufacturer)"
        fi
    done < "$TEMP_CLASSIC"
fi

# Process BLE results
> "$LOOTDIR/ble_devices.txt"
if [ -f "$TEMP_BLE" ] && [ -s "$TEMP_BLE" ]; then
    LOG "Processing BLE devices..."
    
    # BLE output format varies: MAC (name) or just MAC
    while IFS= read -r line; do
        local mac=$(echo "$line" | awk '{print $1}')
        local name=$(echo "$line" | sed 's/^[^ ]* *//' | tr -d '()')
        
        if [ -n "$mac" ] && [ "$mac" != "LE" ]; then
            local manufacturer=$(get_manufacturer "$mac")
            
            # Handle "(unknown)" name
            if [ "$name" = "unknown" ] || [ -z "$name" ]; then
                name="(unknown)"
            fi
            
            # Save in greppable format: MAC:NAME:MANUFACTURER
            echo "$mac:$name:$manufacturer" >> "$LOOTDIR/ble_devices.txt"
            
            LOG blue "  $mac - $name ($manufacturer)"
        fi
    done < "$TEMP_BLE"
fi

# Save raw combined scan
cat "$TEMP_CLASSIC" "$TEMP_BLE" 2>/dev/null > "$LOOTDIR/scan_${timestamp}.txt"

# Write summary
write_summary
LOG "Results saved to: $LOOTDIR"

# ============================================
# DISPLAY SUMMARY
# ============================================

LOG ""
LOG "============================================"
LOG "=== Scan Summary ==="
LOG "============================================"
LOG ""
LOG "Duration: $elapsed"
LOG "Scan Type: $SCAN_TYPE"
LOG ""

classic_count=$(count_lines "$LOOTDIR/classic_devices.txt")
ble_count=$(count_lines "$LOOTDIR/ble_devices.txt")
total_count=$((classic_count + ble_count))

if [ "$total_count" -eq 0 ]; then
    LOG yellow "No devices found"
else
    LOG "Devices discovered:"
    if [ "$SCAN_TYPE" = "classic" ] || [ "$SCAN_TYPE" = "both" ]; then
        if [ "$classic_count" -gt 0 ]; then
            LOG green "  Classic Bluetooth: $classic_count"
        else
            LOG "  Classic Bluetooth: 0"
        fi
    fi
    if [ "$SCAN_TYPE" = "ble" ] || [ "$SCAN_TYPE" = "both" ]; then
        if [ "$ble_count" -gt 0 ]; then
            LOG green "  BLE Devices: $ble_count"
        else
            LOG "  BLE Devices: 0"
        fi
    fi
    LOG ""
    LOG green "Total: $total_count devices"
fi

LOG ""
LOG "Output files:"
LOG "  $LOOTDIR/classic_devices.txt"
LOG "  $LOOTDIR/ble_devices.txt"
LOG "  $LOOTDIR/scan_${timestamp}.txt"
LOG "  $LOOTDIR/summary.txt"
LOG ""

# Final alert
ALERT "Scan complete: $total_count Bluetooth devices found"

