#!/bin/bash
# Title: SetSSIDPool
# Author: MonsieurMarc
# Description: Payload to reset your SSID pool to a set of APs that you want to reuse. For example you may have a set of SSIDs that you use in your home lab.
# Version: 1.0
# Options
# Put your desired SSIDS in the following Array
SSIDS=("Free Public WiFi" "wifi" "dlink")

LOG "Clearing old pool"
PINEAPPLE_SSID_POOL_CLEAR
LOG "Adding new SSIDs"
for SSID in "${SSIDS[@]}"; do
        LOG "Adding $SSID"
        PINEAPPLE_SSID_POOL_ADD $SSID
done
LOG "Added all SSIDs"
