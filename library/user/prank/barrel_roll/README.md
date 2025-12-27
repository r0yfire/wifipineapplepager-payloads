# Do A Barrel Roll 🛩️

A fun easter egg payload that executes the `DO_A_BARREL_ROLL` command to cycle the WiFi Pineapple Pager's LEDs in a barrel roll pattern.

## Description

This playful script demonstrates the WiFi Pineapple's easter egg command that creates a visual LED cycling effect. Perfect for showing off your Pineapple Pager or just having some fun with the device's LED capabilities.

## Features

- **Interactive prompts** - Confirm before executing
- **Sound effects** - Optional ringtone to accompany the barrel roll
- **Visual feedback** - Progress logging and completion alert
- **Safe execution** - Proper error handling and user cancellation

## Usage

1. Run the payload from the Pineapple Pager UI
2. Confirm you want to execute the barrel roll
3. Choose whether to play a sound effect
4. Watch the LED magic happen (and listen if you enabled sound)!

## Configuration

Edit the `OPTIONS` section in `payload.sh`:

```bash
# Play ringtone with barrel roll (true/false)
PLAY_SOUND=false
```

Set `PLAY_SOUND=true` to automatically play the ringtone without prompting.

## What It Does

The `DO_A_BARREL_ROLL` command is an easter egg built into the WiFi Pineapple Pager firmware. When executed, it cycles through the device's LEDs in a special pattern - a playful reference to the famous "Do a barrel roll!" meme.

The script also optionally plays the device's ringtone simultaneously for extra flair!

## Requirements

- WiFi Pineapple Pager (any firmware version with DO_A_BARREL_ROLL support)
- No additional dependencies

## Category

**Prank** - This is a fun, harmless easter egg script with no security or network impact.

## Notes

- This script has no practical security or networking purpose - it's purely for entertainment
- The LED cycling pattern is built into the firmware
- The ringtone plays in the background while the LEDs cycle
- Safe to run multiple times
- No network operations or system changes are performed

## Example Output

```
╔═══════════════════════════════════════╗
║      DO A BARREL ROLL! 🛩️             ║
╔═══════════════════════════════════════╗

Initiating barrel roll sequence...
Sound effect enabled

Executing barrel roll...

✓ Barrel roll complete!
```

## Author

WiFi Pineapple Community

## Version

1.1 - Added optional sound effect

