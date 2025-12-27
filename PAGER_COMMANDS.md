# WiFi Pineapple Pager DuckyScript Commands Reference

Complete list of all DuckyScript commands available on the WiFi Pineapple Pager.

## UI & Display Commands

### Dialogs & User Input

| Command | Description | Return Value |
|---------|-------------|--------------|
| `ALERT` | Show notification popup | None |
| `ALERT_RINGTONE` | Show alert with ringtone | None |
| `CONFIRMATION_DIALOG` | Yes/No question dialog | `$DUCKYSCRIPT_USER_CONFIRMED` or `$DUCKYSCRIPT_USER_DENIED` |
| `ERROR_DIALOG` | Show error popup | None |
| `PROMPT` | Display message and wait | None |

### Input Pickers

| Command | Description | Usage |
|---------|-------------|-------|
| `IP_PICKER` | IP address input | `resp=$(IP_PICKER "Enter IP:" "192.168.1.1")` |
| `MAC_PICKER` | MAC address input | `resp=$(MAC_PICKER "Enter MAC:" "00:11:22:33:44:55")` |
| `NUMBER_PICKER` | Numeric input | `resp=$(NUMBER_PICKER "Enter number:" "1")` |
| `PASSWORD` | Password input (masked) | `resp=$(PASSWORD "Enter password:")` |
| `TEXT_PICKER` | Text input | `resp=$(TEXT_PICKER "Enter text:" "default")` |

### Button Input

| Command | Description | Usage |
|---------|-------------|-------|
| `WAIT_FOR_BUTTON_PRESS` | Wait for specific button | `WAIT_FOR_BUTTON_PRESS UP` |
| `WAIT_FOR_INPUT` | Wait for any button press | `resp=$(WAIT_FOR_INPUT)` |

### Progress Indicators

| Command | Description | Usage |
|---------|-------------|-------|
| `START_SPINNER` | Start loading spinner | `id=$(START_SPINNER "Loading...")` |
| `STOP_SPINNER` | Stop loading spinner | `STOP_SPINNER $id` |

### Output & Logging

| Command | Description | Usage |
|---------|-------------|-------|
| `LOG` | Display message | `LOG "message"` or `LOG red "error"` |

Colors: `red`, `green`, `yellow`, `blue`

### Display Control

| Command | Description |
|---------|-------------|
| `DISABLE_DISPLAY` | Turn off display |
| `ENABLE_DISPLAY` | Turn on display |

### LED & Haptics

| Command | Description | Usage |
|---------|-------------|-------|
| `DPADLED` | Control D-pad LEDs | See DPADLED_CONFIG |
| `DPADLED_CONFIG` | Configure D-pad LED behavior | Advanced configuration |
| `LED` | Control device LEDs | `LED red` or `LED green` |
| `RINGTONE` | Play ringtone | `RINGTONE` |
| `VIBRATE` | Vibrate device | `VIBRATE` |

## WiFi Pineapple Commands

### Reconnaissance

| Command | Description | Usage |
|---------|-------------|-------|
| `PINEAPPLE_RECON_NEW` | Start new reconnaissance | Scans for networks |
| `PINEAPPLE_EXAMINE_BSSID` | Examine specific BSSID | Target specific AP |
| `PINEAPPLE_EXAMINE_CHANNEL` | Examine specific channel | Focus on channel |
| `PINEAPPLE_EXAMINE_RESET` | Reset examination | Clear examination mode |

### SSID Pool Management

| Command | Description |
|---------|-------------|
| `PINEAPPLE_SSID_POOL_ADD` | Add SSID to pool |
| `PINEAPPLE_SSID_POOL_CLEAR` | Clear all SSIDs from pool |
| `PINEAPPLE_SSID_POOL_DELETE` | Delete specific SSID from pool |
| `PINEAPPLE_SSID_POOL_LIST` | List all SSIDs in pool |
| `PINEAPPLE_SSID_POOL_START` | Start broadcasting pool SSIDs |
| `PINEAPPLE_SSID_POOL_STOP` | Stop broadcasting pool SSIDs |
| `PINEAPPLE_SSID_POOL_COLLECT_START` | Start collecting SSIDs |
| `PINEAPPLE_SSID_POOL_COLLECT_STOP` | Stop collecting SSIDs |

### SSID Filtering

| Command | Description |
|---------|-------------|
| `PINEAPPLE_SSID_FILTER_ADD` | Add SSID to filter |
| `PINEAPPLE_SSID_FILTER_CLEAR` | Clear SSID filter list |
| `PINEAPPLE_SSID_FILTER_DELETE` | Delete SSID from filter |
| `PINEAPPLE_SSID_FILTER_LIST` | List filtered SSIDs |
| `PINEAPPLE_SSID_FILTER_MODE` | Set filter mode (allow/deny) |

### MAC Filtering

| Command | Description |
|---------|-------------|
| `PINEAPPLE_MAC_FILTER_ADD` | Add MAC to filter |
| `PINEAPPLE_MAC_FILTER_CLEAR` | Clear MAC filter list |
| `PINEAPPLE_MAC_FILTER_DELETE` | Delete MAC from filter |
| `PINEAPPLE_MAC_FILTER_LIST` | List filtered MACs |
| `PINEAPPLE_MAC_FILTER_MODE` | Set filter mode (allow/deny) |

### Attack Commands

| Command | Description | Usage |
|---------|-------------|-------|
| `PINEAPPLE_DEAUTH_CLIENT` | Deauthenticate client | `PINEAPPLE_DEAUTH_CLIENT <MAC>` |
| `PINEAPPLE_SET_BANDS` | Set WiFi bands | Configure 2.4GHz/5GHz |

## WiFi Management Commands

### Client Mode (STA)

| Command | Description | Usage |
|---------|-------------|-------|
| `WIFI_CONNECT` | Connect to WiFi network | `WIFI_CONNECT "SSID" "password"` |
| `WIFI_DISCONNECT` | Disconnect from network | Disconnect client |
| `WIFI_CLEAR` | Clear saved networks | Remove all saved WiFi |
| `WIFI_WAIT` | Wait for WiFi connection | Block until connected |

### Access Point Modes

#### Management AP

| Command | Description |
|---------|-------------|
| `WIFI_MGMT_AP` | Configure management AP |
| `WIFI_MGMT_AP_CLEAR` | Clear management AP config |
| `WIFI_MGMT_AP_DISABLE` | Disable management AP |
| `WIFI_MGMT_AP_HIDE` | Hide management AP SSID |

#### Open AP

| Command | Description |
|---------|-------------|
| `WIFI_OPEN_AP` | Configure open AP |
| `WIFI_OPEN_AP_CLEAR` | Clear open AP config |
| `WIFI_OPEN_AP_DISABLE` | Disable open AP |
| `WIFI_OPEN_AP_HIDE` | Hide open AP SSID |

#### WPA AP

| Command | Description |
|---------|-------------|
| `WIFI_WPA_AP` | Configure WPA/WPA2 AP |
| `WIFI_WPA_AP_CLEAR` | Clear WPA AP config |
| `WIFI_WPA_AP_DISABLE` | Disable WPA AP |
| `WIFI_WPA_AP_HIDE` | Hide WPA AP SSID |

### Packet Capture

| Command | Description | Usage |
|---------|-------------|-------|
| `WIFI_PCAP_START` | Start packet capture | Begin capturing |
| `WIFI_PCAP_STOP` | Stop packet capture | End capturing |

## Network Tools

### DNS

| Command | Description |
|---------|-------------|
| `DNSSPOOF_ADD_HOST` | Add DNS spoof entry |
| `DNSSPOOF_CLEAR` | Clear all DNS spoof entries |
| `DNSSPOOF_DEL_HOST` | Delete DNS spoof entry |
| `DNSSPOOF_DISABLE` | Disable DNS spoofing |
| `DNSSPOOF_ENABLE` | Enable DNS spoofing |
| `SYSTEM_DNS` | Configure system DNS |

### Network Utilities

| Command | Description | Usage |
|---------|-------------|-------|
| `FIND_CLIENT_IP` | Find client IP address | Get connected client IP |

## VPN & Remote Access

### AutoSSH

| Command | Description |
|---------|-------------|
| `AUTOSSH_ADD_PORT` | Add port forwarding rule |
| `AUTOSSH_CLEAR` | Clear AutoSSH configuration |
| `AUTOSSH_CONFIGURE` | Configure AutoSSH |
| `AUTOSSH_DISABLE` | Disable AutoSSH |
| `AUTOSSH_ENABLE` | Enable AutoSSH |
| `SSH_ADD_KNOWN_HOST` | Add SSH known host |

### OpenVPN

| Command | Description |
|---------|-------------|
| `OPENVPN_CONFIGURE` | Configure OpenVPN |
| `OPENVPN_DISABLE` | Disable OpenVPN |
| `OPENVPN_ENABLE` | Enable OpenVPN |

### WireGuard

| Command | Description |
|---------|-------------|
| `WIREGUARD_CONFIGURE` | Configure WireGuard |
| `WIREGUARD_DISABLE` | Disable WireGuard |
| `WIREGUARD_ENABLE` | Enable WireGuard |

## GPS Commands

| Command | Description | Usage |
|---------|-------------|-------|
| `GPS_CONFIGURE` | Configure GPS settings | Setup GPS |
| `GPS_GET` | Get current GPS position | Retrieve coordinates |
| `GPS_LIST` | List GPS data | Show GPS info |

## WiGLE Integration

| Command | Description |
|---------|-------------|
| `WIGLE_LOGIN` | Login to WiGLE |
| `WIGLE_LOGOUT` | Logout from WiGLE |
| `WIGLE_START` | Start WiGLE wardriving |
| `WIGLE_STOP` | Stop WiGLE wardriving |
| `WIGLE_UPLOAD` | Upload data to WiGLE |

## Payload Management

| Command | Description | Usage |
|---------|-------------|-------|
| `PAYLOAD_DEL_CONFIG` | Delete payload config | Remove config |
| `PAYLOAD_GET_CONFIG` | Get payload config | Retrieve config |
| `PAYLOAD_SET_CONFIG` | Set payload config | Save config |

## USB Storage

| Command | Description |
|---------|-------------|
| `USB_EJECT` | Eject USB storage |
| `USB_FREE` | Check USB free space |
| `USB_STORAGE` | Manage USB storage |
| `USB_WAIT` | Wait for USB device |

## System Commands

| Command | Description |
|---------|-------------|
| `DEVELOPER_THEME_RELOAD` | Reload developer theme |
| `DO_A_BARREL_ROLL` | Easter egg command |
| `INSTALL_FIRMWARE` | Install firmware update |
| `SLA_ACCEPT` | Accept service agreement |
| `TOS_ACCEPT` | Accept terms of service |

## Return Codes

When using dialog commands, check the return code with `$?`:

```bash
resp=$(TEXT_PICKER "Enter value:" "default")
case $? in
    $DUCKYSCRIPT_CANCELLED)
        # User cancelled
        ;;
    $DUCKYSCRIPT_REJECTED)
        # Dialog rejected
        ;;
    $DUCKYSCRIPT_ERROR)
        # Error occurred
        ;;
esac
```

### Standard Return Values

| Variable | Description |
|----------|-------------|
| `$DUCKYSCRIPT_CANCELLED` | User cancelled operation |
| `$DUCKYSCRIPT_REJECTED` | Dialog/operation rejected |
| `$DUCKYSCRIPT_ERROR` | Error occurred |
| `$DUCKYSCRIPT_USER_CONFIRMED` | User confirmed (Yes) |
| `$DUCKYSCRIPT_USER_DENIED` | User denied (No) |

## Command Examples

### Basic Dialog Flow

```bash
# Ask for confirmation
resp=$(CONFIRMATION_DIALOG "Continue?")
case $? in
    $DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        LOG "Dialog error"
        exit 1
        ;;
esac

case "$resp" in
    $DUCKYSCRIPT_USER_CONFIRMED)
        LOG "User confirmed"
        ;;
    $DUCKYSCRIPT_USER_DENIED)
        LOG "User denied"
        exit 0
        ;;
esac
```

### Spinner Usage

```bash
spinner_id=$(START_SPINNER "Processing...")
# Do work here
sleep 5
STOP_SPINNER $spinner_id
```

### Logging with Colors

```bash
LOG "Normal message"
LOG red "Error occurred"
LOG green "Success!"
LOG yellow "Warning"
LOG blue "Information"
```

### WiFi Connection

```bash
WIFI_CONNECT "MyNetwork" "password123"
WIFI_WAIT
LOG green "Connected to WiFi"
```

### SSID Pool Management

```bash
# Add SSIDs to pool
PINEAPPLE_SSID_POOL_ADD "FreeWiFi"
PINEAPPLE_SSID_POOL_ADD "Guest"

# Start broadcasting
PINEAPPLE_SSID_POOL_START

# Stop after use
PINEAPPLE_SSID_POOL_STOP
```

## Notes

- All commands are UPPERCASE
- Commands return exit codes that should be checked
- Most commands output to stdout/stderr
- See individual payload examples in `library/user/examples/` for working code
- Commands are shell scripts located in `/usr/bin/`
- Full command documentation: Run `<COMMAND> --help` or read the command script

## Command Categories Summary

- **UI Commands**: 26 commands
- **WiFi Pineapple**: 24 commands  
- **WiFi Management**: 15 commands
- **Network Tools**: 7 commands
- **VPN/Remote**: 11 commands
- **GPS**: 3 commands
- **WiGLE**: 5 commands
- **Payload**: 3 commands
- **USB**: 4 commands
- **System**: 5 commands

**Total: 103 DuckyScript Commands**

