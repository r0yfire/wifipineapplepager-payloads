# Payload Library for the [WiFi Pineapple Pager](https://hak5.org/products/wifi-pineapple-pager) by [Hak5](https://hak5.org)

The official repository can be found [here](https://github.com/hak5/wifipineapplepager-payloads).

This unofficial repository contains payloads, themes and ringtones for the Hak5 WiFi Pineapple Pager.

### Unofficial Payloads

**Attack**

- [Scanner](./library/user/attack/scanner/payload.sh) - Scan for vulnerable hosts on a network using `nmap`
- [Deauth Flood](./library/user/attack/deauth_flood/payload.sh) - Uses `mdk4` or `aircrack-ng` to deauth all clients around you
- [WiFi Dictionary](./library/user/attack/wifi_dictionary/payload.sh) - Bruteforce password attacks on WiFi access points

**Info**

- [Ifconfig](./library/user/info/ifconfig/payload.sh) - Simple UI to show your network interfaces
- [Public IP](./library/user/info/public_ip/payload.sh) - Display your public IP address and location

**Prank**

- [Barrel Roll](./library/user/prank/barrel_roll/payload.sh) - Execute the easter egg command to cycle the Pager's LEDs in a barrel roll pattern
- [Text Adventure](./library/user/prank/text_adventure/payload.sh) - AI-powered cyberpunk text adventure inspired by Snow Crash

**Reconnaissance**

- [Bluetooth Scanner](./library/user/reconnaissance/bluetooth_scanner/payload.sh) - Scan for nearby Bluetooth devices (Classic and BLE) with manufacturer identification
- [Nmap Host Discovery](./library/user/reconnaissance/nmap_host_discovery/payload.sh) - Discover hosts on a network using nmap
- [Nmap Subnet](./library/user/reconnaissance/nmap_subnet/payload.sh) - Scan a subnet for open ports and services
- [Query Shodan Internet DB](./library/user/reconnaissance/query_shodan_internet_db/payload.sh) - Query the Shodan database for Internet-connected devices

---

[Hak5 Software License Agreement](https://shop.hak5.org/pages/software-license-agreement)
	
[Terms of Service](https://shop.hak5.org/pages/terms-of-service)

# Disclaimer
<h3><b>As with any script, you are advised to proceed with caution.</h3></b>
<h3><b>Generally, payloads may execute commands on your device. As such, it is possible for a payload to damage your device. Payloads from this repository are provided AS-IS without warranty. While Hak5 makes a best effort to review payloads, there are no guarantees as to their effectiveness.</h3></b>
