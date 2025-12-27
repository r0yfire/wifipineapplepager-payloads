#!/bin/bash
# Title: Public IP
# Description: Display your public IP address and geolocation info
# Author: Community
# Version: 1.2
# Category: Info
#
# Zero-click info script - just run and see results!

# ============================================
# OPTIONS
# ============================================

API_URL="https://www.autohost.ai/api/myip.json"
CURL_TIMEOUT=10

# ============================================
# INTERNAL - Process tracking (initialize early!)
# ============================================

# ============================================
# CLEANUP - Set trap EARLY
# ============================================

cleanup() {
    # Nothing to clean up for this simple script
    true
}
trap cleanup EXIT

# ============================================
# HELPER FUNCTIONS
# ============================================

# Check if device has a valid IP address (not loopback, not management network)
# Args: ip - IP address to validate
# Returns: 0 if valid, 1 if invalid
is_valid_ip() {
    local ip="$1"
    # Reject empty or loopback
    if [ -z "$ip" ] || [ "$ip" = "127.0.0.1" ]; then
        return 1
    fi
    # Exclude 172.16.52.0/24 subnet (Pineapple management network)
    if echo "$ip" | grep -qE '^172\.16\.52\.'; then
        return 1
    fi
    return 0
}

# Check if device has network connectivity
# Returns: 0 if connected, 1 if not
check_network() {
    local has_ip=false
    
    # Try hostname -I first
    if command -v hostname >/dev/null 2>&1; then
        local ip_addr
        ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
        if is_valid_ip "$ip_addr"; then
            has_ip=true
        fi
    fi
    
    # Fallback to ip command
    if [ "$has_ip" = false ] && command -v ip >/dev/null 2>&1; then
        for ip_addr in $(ip -4 addr show | grep -E 'inet [0-9]' | awk '{print $2}' | cut -d'/' -f1); do
            if is_valid_ip "$ip_addr"; then
                has_ip=true
                break
            fi
        done
    fi
    
    [ "$has_ip" = true ]
}

# ============================================
# MAIN SCRIPT
# ============================================

# Display header
LOG ""
LOG blue "=== Your Public IP ==="
LOG ""

# Step 1: Check network connectivity
if ! check_network; then
    ERROR_DIALOG "No network connection"
    LOG red "ERROR: No valid network connection detected"
    LOG "Please connect to a network and try again"
    exit 1
fi

# Step 2: Fetch public IP (no spinner - just like Shodan script)
LOG "Fetching your public IP..."

# Make API request with timeout
response=$(curl -s --connect-timeout 10 --max-time "$CURL_TIMEOUT" -w "\n%{http_code}" "$API_URL" 2>/dev/null)
curl_exit=$?

# Check if curl failed
if [ $curl_exit -ne 0 ]; then
    ERROR_DIALOG "Network request failed"
    LOG red "ERROR: Could not reach the API"
    LOG "Check your internet connection"
    exit 1
fi

# Parse response and HTTP code
http_code=$(echo "$response" | tail -n1)
json_body=$(echo "$response" | sed '$d')

# Check HTTP status
if [ "$http_code" != "200" ]; then
    ERROR_DIALOG "API error (HTTP $http_code)"
    LOG red "ERROR: API returned HTTP $http_code"
    exit 1
fi

# Check for empty response
if [ -z "$json_body" ]; then
    ERROR_DIALOG "Empty API response"
    LOG red "ERROR: Received empty response from API"
    exit 1
fi

# Step 3: Parse JSON with jq
ip=$(echo "$json_body" | jq -r '.ip // empty')
city=$(echo "$json_body" | jq -r '.city // empty')
region=$(echo "$json_body" | jq -r '.regionName // empty')
country=$(echo "$json_body" | jq -r '.countryName // empty')
country_code=$(echo "$json_body" | jq -r '.countryCode // empty')
lat=$(echo "$json_body" | jq -r '.latitude // empty')
lon=$(echo "$json_body" | jq -r '.longitude // empty')
timezone=$(echo "$json_body" | jq -r '.timezone // empty')

# Validate we got an IP
if [ -z "$ip" ]; then
    ERROR_DIALOG "Could not parse IP"
    LOG red "ERROR: Failed to parse IP from response"
    exit 1
fi

# Step 4: Display results in a fun format
LOG ""
LOG green "    $ip"
LOG ""

# Location line (city, region if available)
if [ -n "$city" ] && [ -n "$region" ]; then
    LOG "Location: $city, $region"
elif [ -n "$city" ]; then
    LOG "Location: $city"
fi

# Country line
if [ -n "$country" ] && [ -n "$country_code" ]; then
    LOG "Country:  $country ($country_code)"
elif [ -n "$country" ]; then
    LOG "Country:  $country"
fi

# Coordinates line (rounded to 2 decimal places for readability)
if [ -n "$lat" ] && [ -n "$lon" ]; then
    # Round coordinates using printf
    lat_short=$(printf "%.2f" "$lat" 2>/dev/null || echo "$lat")
    lon_short=$(printf "%.2f" "$lon" 2>/dev/null || echo "$lon")
    LOG "Coords:   $lat_short, $lon_short"
fi

# Timezone line
if [ -n "$timezone" ]; then
    LOG "Timezone: $timezone"
fi

LOG ""
LOG blue "========================"

# Fun feedback - vibrate on success!
VIBRATE 2>/dev/null

# Wait for user to dismiss
LOG ""
LOG "Press any button to exit"
WAIT_FOR_INPUT >/dev/null

LOG "Done!"
