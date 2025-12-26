#!/bin/bash
# Title: Vulnerability Scanner
# Description: Scans local network for vulnerable services, outputs greppable findings
# Author: Community
# Version: 1.0
# Category: Attack
#
# WARNING: For authorized testing only. Unauthorized use is illegal.
#
# This script uses nmap with vulners.nse to scan for open services and
# known vulnerabilities. Results are saved as greppable text files that
# other scripts can easily consume (e.g., ssh.txt for SSH bruteforce).

# ============================================
# OPTIONS - Configure before running
# ============================================

# Loot directory for saving scan results
LOOTDIR=/root/loot/vuln_scanner

# Scan profile: quick, common, or vuln
# - quick: Top 100 ports, no version detection (fast)
# - common: Top 1000 ports with version detection
# - vuln: Top 1000 ports with version + vulnerability detection
SCAN_PROFILE="vuln"

# Timing template (-T0 to -T5, higher = faster but noisier)
SCAN_AGGRESSIVITY="-T3"

# Hosts to exclude from scan (comma-separated IPs)
EXCLUDED_HOSTS=""

# ============================================
# INTERNAL FILES - Temp files and state
# ============================================

TEMP_SCAN="/tmp/vuln_scanner_temp.nmap"
CANCEL_FLAG="/tmp/vuln_scanner_cancel"

# Process tracking (initialize early!)
NMAP_PID=""
LISTENER_PID=""
START_TIME=""

# State variables
TARGET_SUBNET=""
VULNERS_AVAILABLE=false

# ============================================
# CLEANUP - Set trap EARLY
# ============================================

cleanup() {
    LOG "Cleaning up..."
    
    # Kill background listener if running
    if [ -n "$LISTENER_PID" ] && kill -0 "$LISTENER_PID" 2>/dev/null; then
        kill "$LISTENER_PID" 2>/dev/null
        wait "$LISTENER_PID" 2>/dev/null
    fi
    
    # Kill nmap if still running
    if [ -n "$NMAP_PID" ] && kill -0 "$NMAP_PID" 2>/dev/null; then
        kill "$NMAP_PID" 2>/dev/null
        wait "$NMAP_PID" 2>/dev/null
    fi
    
    # Clean temp files
    rm -f "$CANCEL_FLAG"
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

# Detect available subnets from network interfaces
detect_subnets() {
    ip -o -f inet addr show | awk '/scope global/ {print $4}'
}

# Build nmap arguments based on scan profile
build_nmap_args() {
    local args="$SCAN_AGGRESSIVITY -Pn"
    
    case "$SCAN_PROFILE" in
        quick)
            args="$args -F"
            ;;
        common)
            args="$args -sV"
            ;;
        vuln)
            args="$args -sV"
            if [ "$VULNERS_AVAILABLE" = true ]; then
                args="$args --script vulners.nse"
            fi
            ;;
    esac
    
    # Add exclusions if specified
    if [ -n "$EXCLUDED_HOSTS" ]; then
        args="$args --exclude $EXCLUDED_HOSTS"
    fi
    
    echo "$args"
}

# Parse nmap output and write per-service greppable files
parse_and_write_services() {
    local scan_file="$1"
    local current_host=""
    local current_port=""
    
    # Initialize empty service files
    > "$LOOTDIR/ssh.txt"
    > "$LOOTDIR/http.txt"
    > "$LOOTDIR/mysql.txt"
    > "$LOOTDIR/ftp.txt"
    > "$LOOTDIR/tftp.txt"
    > "$LOOTDIR/telnet.txt"
    > "$LOOTDIR/rdp.txt"
    > "$LOOTDIR/smb.txt"
    > "$LOOTDIR/vnc.txt"
    > "$LOOTDIR/other.txt"
    > "$LOOTDIR/vulns.txt"
    
    while IFS= read -r line; do
        # Track current host
        if echo "$line" | grep -q "^Nmap scan report for"; then
            current_host=$(echo "$line" | awk '{print $5}' | tr -d '()')
        fi
        
        # Parse open ports: "22/tcp open ssh OpenSSH 7.9p1"
        if echo "$line" | grep -qE "^[0-9]+/tcp.*open|^[0-9]+/udp.*open"; then
            current_port=$(echo "$line" | cut -d/ -f1)
            local service=$(echo "$line" | awk '{print $3}')
            local version=$(echo "$line" | awk '{$1=$2=$3=""; print $0}' | sed 's/^[[:space:]]*//' | tr ' ' '_')
            
            # Categorize and write to appropriate file
            case "$service" in
                ssh)
                    echo "$current_host:$current_port:$version" >> "$LOOTDIR/ssh.txt"
                    ;;
                http|https|http-proxy)
                    echo "$current_host:$current_port:$version" >> "$LOOTDIR/http.txt"
                    ;;
                mysql|mariadb)
                    echo "$current_host:$current_port:$version" >> "$LOOTDIR/mysql.txt"
                    ;;
                ftp)
                    echo "$current_host:$current_port:$version" >> "$LOOTDIR/ftp.txt"
                    ;;
                tftp)
                    echo "$current_host:$current_port:$version" >> "$LOOTDIR/tftp.txt"
                    ;;
                telnet)
                    echo "$current_host:$current_port:$version" >> "$LOOTDIR/telnet.txt"
                    ;;
                ms-wbt-server|rdp)
                    echo "$current_host:$current_port:$version" >> "$LOOTDIR/rdp.txt"
                    ;;
                netbios-ssn|microsoft-ds|smb)
                    echo "$current_host:$current_port:$version" >> "$LOOTDIR/smb.txt"
                    ;;
                vnc|vnc-http)
                    echo "$current_host:$current_port:$version" >> "$LOOTDIR/vnc.txt"
                    ;;
                *)
                    echo "$current_host:$current_port:$service:$version" >> "$LOOTDIR/other.txt"
                    ;;
            esac
        fi
        
        # Extract CVEs (appear in vulners output)
        if echo "$line" | grep -qE "CVE-[0-9]{4}-[0-9]+"; then
            local cves=$(echo "$line" | grep -oE "CVE-[0-9]{4}-[0-9]+")
            for cve in $cves; do
                echo "$current_host:$current_port:$cve" >> "$LOOTDIR/vulns.txt"
            done
        fi
    done < "$scan_file"
    
    # Remove duplicates from vulns file
    if [ -f "$LOOTDIR/vulns.txt" ]; then
        sort -u "$LOOTDIR/vulns.txt" -o "$LOOTDIR/vulns.txt"
    fi
}

# Count lines in a file (0 if empty or doesn't exist)
count_lines() {
    local file="$1"
    if [ -f "$file" ] && [ -s "$file" ]; then
        wc -l < "$file" | tr -d ' '
    else
        echo "0"
    fi
}

# Write summary file
write_summary() {
    local scan_time=$(date -Is)
    local hosts_up=$(grep -c "^Nmap scan report for" "$TEMP_SCAN" 2>/dev/null || echo "0")
    local total_ports=0
    
    # Count total ports across all service files
    for f in ssh http mysql ftp tftp telnet rdp smb vnc other; do
        local cnt=$(count_lines "$LOOTDIR/${f}.txt")
        total_ports=$((total_ports + cnt))
    done
    
    local total_vulns=$(count_lines "$LOOTDIR/vulns.txt")
    
    cat > "$LOOTDIR/summary.txt" <<EOF
SCAN_TIME=$scan_time
SUBNET=$TARGET_SUBNET
PROFILE=$SCAN_PROFILE
HOSTS_UP=$hosts_up
TOTAL_PORTS=$total_ports
TOTAL_VULNS=$total_vulns
EOF
}

# ============================================
# MAIN SCRIPT
# ============================================

LOG "=== Vulnerability Scanner ==="
LOG ""

# Create loot directory
mkdir -p "$LOOTDIR"

# Check nmap availability
if ! command -v nmap &>/dev/null; then
    ERROR_DIALOG "nmap is not installed"
    exit 1
fi
LOG green "nmap found"

# Check for vulners script
if nmap --script-help vulners &>/dev/null 2>&1; then
    VULNERS_AVAILABLE=true
    LOG green "vulners.nse available"
else
    VULNERS_AVAILABLE=false
    LOG yellow "WARNING: vulners.nse not found, CVE detection disabled"
fi
LOG ""

# Detect available subnets
LOG "Detecting network subnets..."
subnets=$(detect_subnets)
subnetArray=($subnets)

if [ ${#subnetArray[@]} -eq 0 ]; then
    ERROR_DIALOG "No network interfaces found"
    exit 1
fi

# Build subnet display list
subnetPrompt=""
idx=1
for subnet in "${subnetArray[@]}"; do
    subnetPrompt="${subnetPrompt}${idx}. ${subnet}\n"
    idx=$((idx + 1))
done

# Prompt user to select subnet
PROMPT "Available subnets:\n\n$subnetPrompt"
targetIndex=$(NUMBER_PICKER "Select target subnet" "1")
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

# Validate selection
if [ "$targetIndex" -lt 1 ] || [ "$targetIndex" -gt ${#subnetArray[@]} ]; then
    ERROR_DIALOG "Invalid subnet selection"
    exit 1
fi

TARGET_SUBNET="${subnetArray[$((targetIndex-1))]}"
LOG "Selected subnet: $TARGET_SUBNET"
LOG ""

# Ask about scan profile
LOG "Current profile: $SCAN_PROFILE"
resp=$(CONFIRMATION_DIALOG "Use '$SCAN_PROFILE' scan profile?")
case $? in
    $DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        LOG "Dialog error"
        exit 1
        ;;
esac

case "$resp" in
    $DUCKYSCRIPT_USER_CONFIRMED)
        LOG "Using profile: $SCAN_PROFILE"
        ;;
    $DUCKYSCRIPT_USER_DENIED)
        # Let user pick a different profile
        PROMPT "Scan profiles:\n\n1. quick - Fast, top 100 ports\n2. common - Top 1000 ports + versions\n3. vuln - Full vulnerability scan"
        profileIndex=$(NUMBER_PICKER "Select profile" "3")
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
        
        case "$profileIndex" in
            1) SCAN_PROFILE="quick" ;;
            2) SCAN_PROFILE="common" ;;
            3) SCAN_PROFILE="vuln" ;;
            *)
                LOG yellow "Invalid selection, using 'vuln'"
                SCAN_PROFILE="vuln"
                ;;
        esac
        LOG "Selected profile: $SCAN_PROFILE"
        ;;
    *)
        LOG "Unknown response: $resp"
        exit 1
        ;;
esac

LOG ""

# Final confirmation
resp=$(CONFIRMATION_DIALOG "Start $SCAN_PROFILE scan on $TARGET_SUBNET?")
case $? in
    $DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        LOG "Dialog error"
        exit 1
        ;;
esac

case "$resp" in
    $DUCKYSCRIPT_USER_CONFIRMED)
        LOG "User confirmed - starting scan"
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

# Build nmap command
NMAP_ARGS=$(build_nmap_args)
LOG ""
LOG "============================================"
LOG "=== Starting Scan ==="
LOG "============================================"
LOG ""
LOG "Target: $TARGET_SUBNET"
LOG "Profile: $SCAN_PROFILE"
LOG "Arguments: $NMAP_ARGS"
LOG ""

# Initialize cancel flag
rm -f "$CANCEL_FLAG"

# Record start time
START_TIME=$(date +%s)

# Run nmap in background
nmap $NMAP_ARGS -oN "$TEMP_SCAN" "$TARGET_SUBNET" &
NMAP_PID=$!
LOG green "Scan started (PID: $NMAP_PID)"
LOG ""
LOG "Press any button to cancel..."
LOG ""

# Start background cancel listener
(
    resp=$(WAIT_FOR_INPUT)
    touch "$CANCEL_FLAG"
    LOG yellow "Cancel requested (pressed: $resp)..."
) &
LISTENER_PID=$!

# Wait for nmap to finish OR cancel flag
while kill -0 "$NMAP_PID" 2>/dev/null; do
    if [ -f "$CANCEL_FLAG" ]; then
        LOG yellow "Cancelling scan..."
        kill "$NMAP_PID" 2>/dev/null
        wait "$NMAP_PID" 2>/dev/null
        break
    fi
    sleep 1
done

# Kill listener if still running
if kill -0 "$LISTENER_PID" 2>/dev/null; then
    kill "$LISTENER_PID" 2>/dev/null
    wait "$LISTENER_PID" 2>/dev/null
fi
LISTENER_PID=""

# Check if scan file exists
if [ ! -f "$TEMP_SCAN" ]; then
    ERROR_DIALOG "Scan failed - no output generated"
    exit 1
fi

# Calculate elapsed time
elapsed=$(get_elapsed_time)

LOG ""
LOG "============================================"
LOG "=== Parsing Results ==="
LOG "============================================"
LOG ""

# Copy raw scan to loot directory
timestamp=$(date +%Y%m%d_%H%M%S)
cp "$TEMP_SCAN" "$LOOTDIR/scan_${timestamp}.nmap"
LOG "Raw scan saved: scan_${timestamp}.nmap"

# Parse and categorize services
LOG "Parsing services..."
parse_and_write_services "$TEMP_SCAN"

# Write summary
write_summary
LOG "Summary written"

# Clean up temp file
rm -f "$TEMP_SCAN"

# Display summary
LOG ""
LOG "============================================"
LOG "=== Scan Summary ==="
LOG "============================================"
LOG ""
LOG "Duration: $elapsed"
LOG "Subnet: $TARGET_SUBNET"
LOG "Profile: $SCAN_PROFILE"
LOG ""

# Count and display results
ssh_count=$(count_lines "$LOOTDIR/ssh.txt")
http_count=$(count_lines "$LOOTDIR/http.txt")
mysql_count=$(count_lines "$LOOTDIR/mysql.txt")
ftp_count=$(count_lines "$LOOTDIR/ftp.txt")
tftp_count=$(count_lines "$LOOTDIR/tftp.txt")
telnet_count=$(count_lines "$LOOTDIR/telnet.txt")
rdp_count=$(count_lines "$LOOTDIR/rdp.txt")
smb_count=$(count_lines "$LOOTDIR/smb.txt")
vnc_count=$(count_lines "$LOOTDIR/vnc.txt")
other_count=$(count_lines "$LOOTDIR/other.txt")
vuln_count=$(count_lines "$LOOTDIR/vulns.txt")

# Calculate total before display
total_services=$((ssh_count + http_count + mysql_count + ftp_count + tftp_count + telnet_count + rdp_count + smb_count + vnc_count + other_count))

LOG "Services found:"
if [ "$total_services" -eq 0 ]; then
    LOG yellow "  No open ports detected"
else
    [ "$ssh_count" -gt 0 ] && LOG green "  SSH: $ssh_count"
    [ "$http_count" -gt 0 ] && LOG green "  HTTP: $http_count"
    [ "$mysql_count" -gt 0 ] && LOG green "  MySQL: $mysql_count"
    [ "$ftp_count" -gt 0 ] && LOG green "  FTP: $ftp_count"
    [ "$tftp_count" -gt 0 ] && LOG green "  TFTP: $tftp_count"
    [ "$telnet_count" -gt 0 ] && LOG yellow "  Telnet: $telnet_count"
    [ "$rdp_count" -gt 0 ] && LOG green "  RDP: $rdp_count"
    [ "$smb_count" -gt 0 ] && LOG green "  SMB: $smb_count"
    [ "$vnc_count" -gt 0 ] && LOG green "  VNC: $vnc_count"
    [ "$other_count" -gt 0 ] && LOG "  Other: $other_count"
fi
LOG ""

if [ "$vuln_count" -gt 0 ]; then
    LOG red "Vulnerabilities: $vuln_count CVEs found!"
else
    LOG "Vulnerabilities: None detected"
fi

LOG ""
LOG "Results saved to: $LOOTDIR"
LOG ""

# Final alert
if [ "$vuln_count" -gt 0 ]; then
    ALERT "Scan complete: $total_services ports, $vuln_count CVEs"
else
    ALERT "Scan complete: $total_services open ports found"
fi

