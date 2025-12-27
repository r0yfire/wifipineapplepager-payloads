# Bluetooth Scanner

Scans for nearby Bluetooth devices (both Classic Bluetooth and Bluetooth Low Energy) and displays results with manufacturer identification.

## Features

- **Dual-Mode Scanning**: Supports Classic Bluetooth and BLE (Low Energy) devices
- **Flexible Duration**: Quick (10s), Normal (30s), Extended (60s), or Continuous modes
- **Manufacturer Lookup**: Identifies common device manufacturers from MAC OUI
- **Greppable Output**: Results saved in parseable format for automation
- **Cancel Support**: Press any button to stop continuous scans

## Requirements

### Dependencies

The following packages must be installed:

```bash
opkg update
opkg install bluez-utils bluez-tools
```

### Hardware

- WiFi Pineapple Pager with Bluetooth 5.2 / BLE 4.2 support
- Bluetooth adapter must be enabled and functional

## Usage

1. Run the payload from the Pager interface
2. Select scan type:
   - **Classic Bluetooth**: Traditional devices (phones, headphones, speakers)
   - **BLE**: Low Energy devices (IoT, beacons, fitness trackers)
   - **Both**: Comprehensive scan of all Bluetooth devices
3. Select duration:
   - **Quick (10s)**: Fast discovery for nearby devices
   - **Normal (30s)**: Balanced scan time
   - **Extended (60s)**: Thorough scanning
   - **Continuous**: Runs until you press any button
4. Confirm to start scanning
5. View discovered devices in real-time
6. Results are automatically saved to loot folder

## Output

Results are saved to `/root/loot/bluetooth_scanner/`:

| File | Description |
|------|-------------|
| `classic_devices.txt` | Classic Bluetooth devices (greppable) |
| `ble_devices.txt` | BLE devices (greppable) |
| `scan_YYYYMMDD_HHMMSS.txt` | Raw combined scan output |
| `summary.txt` | Scan metadata and statistics |

### Output Format

Device files use a greppable colon-separated format:

```
MAC_ADDRESS:DEVICE_NAME:MANUFACTURER
```

Example:
```
00:1A:7D:DA:71:13:iPhone:Apple
9C:8C:D8:12:34:56:WH-1000XM4:Sony
94:B8:6D:AA:BB:CC:Mi Band 6:Xiaomi
```

### Summary File

```
SCAN_TIME=2024-01-15T10:30:00+00:00
SCAN_TYPE=both
SCAN_DURATION=normal
ELAPSED=00:30
CLASSIC_DEVICES=5
BLE_DEVICES=12
ADAPTER=hci0
```

## Scan Types Explained

### Classic Bluetooth

Traditional Bluetooth scanning discovers devices in "discoverable" mode. This includes:
- Smartphones and tablets
- Bluetooth headphones and speakers
- Car audio systems
- Wireless keyboards and mice

**Note**: Many devices disable discoverability by default for privacy.

### Bluetooth Low Energy (BLE)

BLE scanning discovers low-power devices that broadcast advertisements:
- Fitness trackers and smartwatches
- IoT sensors and beacons
- Smart home devices
- AirTags and Tile trackers
- Medical devices

BLE devices are often more visible as they continuously advertise.

## Technical Details

### Tools Used

- `hcitool scan`: Classic Bluetooth device discovery
- `hcitool lescan`: BLE advertisement scanning
- `hciconfig`: Bluetooth adapter management

### Adapter Management

The script automatically:
1. Detects the Bluetooth adapter (`hci0`)
2. Brings the adapter up if it's down
3. Cleans up and stops scans on exit

### Known Manufacturers

The script includes OUI lookups for common manufacturers:
- Apple, Samsung, Sony, Google
- Bose, JBL, Beats
- Intel, Dell, HP, Lenovo, Microsoft
- Xiaomi, Huawei
- Logitech

Unknown manufacturers display as "Unknown".

## Troubleshooting

### No Bluetooth adapter found

```
ERROR: Bluetooth adapter hci0 not found
```

**Solution**: Ensure Bluetooth hardware is present and the bluez packages are installed:
```bash
opkg install bluez-utils bluez-tools kmod-bluetooth
```

### Adapter won't come up

```
ERROR: Failed to bring up hci0
```

**Solution**: Check for hardware issues or conflicting processes:
```bash
hciconfig -a
rfkill list
rfkill unblock bluetooth
```

### No devices found

- Ensure target devices are in discoverable/pairing mode
- Try extended duration for better coverage
- Move closer to target devices
- Some devices may not respond to scans (privacy features)

### BLE scan shows many duplicates

BLE devices continuously advertise, so the same device may appear multiple times. The script deduplicates results automatically.

## Security Considerations

- This tool is for **authorized security testing only**
- Bluetooth scanning may be detectable by nearby devices
- Some jurisdictions regulate wireless scanning activities
- Always obtain proper authorization before scanning

## Version History

| Version | Changes |
|---------|---------|
| 1.0 | Initial release with Classic BT and BLE support |

