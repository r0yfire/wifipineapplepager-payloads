#!/bin/bash
# Title: Do A Barrel Roll
# Description: Executes the easter egg barrel roll command to cycle LEDs with optional sound
# Author: WiFi Pineapple Community
# Version: 1.1
# Category: Prank
#
# A fun easter egg that cycles the device LEDs in a barrel roll pattern.

# ============================================
# OPTIONS - User configurable
# ============================================

# Play ringtone with barrel roll (true/false)
PLAY_SOUND=false

# ============================================
# CLEANUP - Set trap EARLY
# ============================================

cleanup() {
    # No background processes to clean up for this simple script
    true
}
trap cleanup EXIT

# ============================================
# MAIN SCRIPT
# ============================================

LOG ""
LOG blue "╔═══════════════════════════════════════╗"
LOG blue "║      DO A BARREL ROLL! 🛩️             ║"
LOG blue "╔═══════════════════════════════════════╗"
LOG ""

# Ask for confirmation
resp=$(CONFIRMATION_DIALOG "Execute barrel roll?")

# Check for dialog errors
case $? in
    $DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        ERROR_DIALOG "Dialog error occurred"
        exit 1
        ;;
esac

# Check user response
case "$resp" in
    $DUCKYSCRIPT_USER_DENIED)
        LOG yellow "Barrel roll cancelled"
        exit 0
        ;;
    $DUCKYSCRIPT_USER_CONFIRMED)
        LOG green "Initiating barrel roll sequence..."
        ;;
    *)
        ERROR_DIALOG "Unknown response: $resp"
        exit 1
        ;;
esac

# Ask if user wants sound effects
resp=$(CONFIRMATION_DIALOG "Play sound effect?")
case $? in
    $DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        # If dialog fails, just continue without sound
        LOG yellow "Sound dialog error, continuing without sound"
        PLAY_SOUND=false
        ;;
    *)
        # Check user response
        case "$resp" in
            $DUCKYSCRIPT_USER_CONFIRMED)
                PLAY_SOUND=true
                LOG blue "Sound effect enabled"
                ;;
            $DUCKYSCRIPT_USER_DENIED)
                PLAY_SOUND=false
                ;;
            *)
                PLAY_SOUND=false
                ;;
        esac
        ;;
esac

LOG ""
LOG green "Executing barrel roll..."
LOG ""

# Play ringtone if enabled
if [ "$PLAY_SOUND" = true ]; then
    RINGTONE &
fi

# Execute the easter egg command
DO_A_BARREL_ROLL

LOG ""
LOG green "✓ Barrel roll complete!"
LOG ""
VIBRATE
ALERT "Barrel roll executed successfully!"

exit 0

