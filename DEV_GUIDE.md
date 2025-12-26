# WiFi Pineapple Pager Payload Development Guide

A reference guide for writing robust, user-friendly payload scripts based on lessons learned from developing the `deauth_flood` and `wifi_dictionary` attack payloads.

> **See Also:** For working examples of each DuckyScript command, refer to the `library/user/examples/` directory:
> - `ALERT/` - Popup notifications
> - `CONFIRMATION_DIALOG/` - Yes/No prompts
> - `ERROR_DIALOG/` - Error popups
> - `IP_PICKER/` - IP address input
> - `LOG/` - Logging with colors
> - `MAC_PICKER/` - MAC address input
> - `NUMBER_PICKER/` - Numeric input
> - `PROMPT/` - Display message and wait
> - `SPINNER/` - Loading indicators
> - `TEXT_PICKER/` - Text input
> - `WAIT_FOR_BUTTON_PRESS/` - Wait for specific button
> - `WAIT_FOR_INPUT/` - Wait for any button

---

## Table of Contents

1. [Script Structure](#script-structure)
2. [DuckyScript UI Commands](#duckyscript-ui-commands)
3. [Error Handling Patterns](#error-handling-patterns)
4. [Loot Folders](#loot-folders)
5. [Process Management & Crash Safety](#process-management--crash-safety)
6. [User Cancellation](#user-cancellation)
7. [Verbose Output](#verbose-output)
8. [Common Bugs to Avoid](#common-bugs-to-avoid)
9. [Configuration Patterns](#configuration-patterns)

---

## Script Structure

Use this standard structure for consistency:

```bash
#!/bin/bash
# Title: Payload Name
# Description: What it does
# Author: Your Name
# Version: 1.0
# Category: Attack/Recon/etc
#
# WARNING: For authorized testing only.

# ============================================
# OPTIONS - User configurable
# ============================================

LOOTDIR=/root/loot/payload_name
SOME_OPTION=""

# ============================================
# INTERNAL FILES - Temp files
# ============================================

TEMP_FILE="/tmp/payload_temp.txt"
STATUS_FILE="/tmp/payload_status.txt"

# Process tracking (initialize early!)
SOME_PID=""
LISTENER_PID=""

# ============================================
# CLEANUP - Set trap EARLY
# ============================================

cleanup() {
    # Kill processes, remove temp files
}
trap cleanup EXIT

# ============================================
# HELPER FUNCTIONS
# ============================================

# Your functions here...

# ============================================
# MAIN SCRIPT
# ============================================

# Your main logic here...
```

---

## DuckyScript UI Commands

### LOG - Progress Messages

```bash
LOG "Normal message"
LOG red "Error message"
LOG green "Success message"
LOG yellow "Warning message"
LOG blue "Info message"
```

### Dialogs - User Interaction

**TEXT_PICKER** - Text input with default value:
```bash
resp=$(TEXT_PICKER "Enter value:" "default")
case $? in
    $DUCKYSCRIPT_CANCELLED)
        LOG "User cancelled"
        exit 1
        ;;
    $DUCKYSCRIPT_REJECTED)
        LOG "Dialog rejected"
        exit 1
        ;;
    $DUCKYSCRIPT_ERROR)
        LOG "An error occurred"
        exit 1
        ;;
esac
# Use $resp here
```

**CONFIRMATION_DIALOG** - Yes/No question (TWO case statements required!):
```bash
resp=$(CONFIRMATION_DIALOG "Continue?")
# First: check for errors
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

# Second: check user response
case "$resp" in
    $DUCKYSCRIPT_USER_CONFIRMED)
        LOG "User said yes"
        ;;
    $DUCKYSCRIPT_USER_DENIED)
        LOG "User said no"
        exit 0
        ;;
    *)
        LOG "Unknown response: $resp"
        exit 1
        ;;
esac
```

**ERROR_DIALOG** - Show error popup:
```bash
ERROR_DIALOG "Something went wrong!"
```

**ALERT** - Show notification:
```bash
ALERT "Task complete!"
```

### Spinners - Long Operations

```bash
spinner_id=$(START_SPINNER "Loading...")
# Do work here
STOP_SPINNER $spinner_id
```

### User Input - Blocking Wait

**WAIT_FOR_INPUT** - Wait for any button:
```bash
resp=$(WAIT_FOR_INPUT)
LOG "User pressed: $resp"
```

**WAIT_FOR_BUTTON_PRESS** - Wait for specific button:
```bash
WAIT_FOR_BUTTON_PRESS UP
LOG "User pressed UP"
```

---

## Error Handling Patterns

### Always Check Return Codes

```bash
# WRONG - Ignores errors
resp=$(TEXT_PICKER "Value?" "")

# RIGHT - Handles all cases
resp=$(TEXT_PICKER "Value?" "")
case $? in
    $DUCKYSCRIPT_CANCELLED|$DUCKYSCRIPT_REJECTED|$DUCKYSCRIPT_ERROR)
        LOG "Input failed"
        exit 1
        ;;
esac
```

### Validate Early, Fail Fast

```bash
# Check requirements before doing work
if [ ! -f "$REQUIRED_FILE" ]; then
    ERROR_DIALOG "Required file not found"
    exit 1
fi

if [ -z "$INTERFACE" ]; then
    ERROR_DIALOG "No interface available"
    exit 1
fi
```

---

## Loot Folders

### Convention

```bash
LOOTDIR=/root/loot/payload_name
mkdir -p "$LOOTDIR"
```

### Timestamped Files

```bash
# For scan results, logs, etc.
loot_file="$LOOTDIR/scan_$(date +%Y%m%d_%H%M%S).txt"

# For credentials (append-friendly)
echo "[$timestamp] Data here" >> "$LOOTDIR/credentials.txt"
```

### Safe Filenames

```bash
# SSIDs may contain special characters
safe_name=$(echo "$ssid" | tr ' /' '__')
file="$LOOTDIR/${safe_name}_$(date +%Y%m%d_%H%M%S).txt"
```

---

## Process Management & Crash Safety

### Initialize Variables Early

```bash
# At top of script, BEFORE trap
PROCESS_PID=""
LISTENER_PID=""
```

### Set Trap Early

```bash
# Right after variable declarations
trap cleanup EXIT
```

### Cleanup Function Pattern

```bash
cleanup() {
    LOG "Cleaning up..."
    
    # Check if PID exists AND process is running
    if [ -n "$LISTENER_PID" ] && kill -0 "$LISTENER_PID" 2>/dev/null; then
        kill "$LISTENER_PID" 2>/dev/null
        wait "$LISTENER_PID" 2>/dev/null
    fi
    
    if [ -n "$PROCESS_PID" ] && kill -0 "$PROCESS_PID" 2>/dev/null; then
        kill "$PROCESS_PID" 2>/dev/null
        wait "$PROCESS_PID" 2>/dev/null
    fi
    
    # Clean temp files
    rm -f "$TEMP_FILE" "$STATUS_FILE"
}
```

### Background Process Tracking

```bash
# When starting background process
some_command &
PROCESS_PID=$!

# Multiple processes
command1 &
PIDS="$PIDS $!"
command2 &
PIDS="$PIDS $!"
```

---

## User Cancellation

### Pattern: Background Listener

For long-running operations where user should be able to cancel:

```bash
CANCEL_FLAG="/tmp/payload_cancel"
rm -f "$CANCEL_FLAG"

# Start background listener
(
    resp=$(WAIT_FOR_INPUT)
    touch "$CANCEL_FLAG"
    LOG yellow "Cancel requested..."
) &
LISTENER_PID=$!

# Check in your loop
is_cancelled() {
    [ -f "$CANCEL_FLAG" ]
}

while do_work; do
    if is_cancelled; then
        LOG "Cancelled by user"
        break
    fi
done

# Cleanup listener
kill "$LISTENER_PID" 2>/dev/null
wait "$LISTENER_PID" 2>/dev/null
```

### Pattern: Foreground Wait (Simpler)

For continuous background processes (like deauth):

```bash
# Start attack in background
attack_command &
ATTACK_PID=$!

LOG "Press any button to stop"
resp=$(WAIT_FOR_INPUT)

# Cleanup via trap handles killing ATTACK_PID
```

---

## Verbose Output

### Progress Indicators

```bash
# Show position in list
LOG "[$current/$total] Processing: $item"

# Show percentages for long operations
percent=$((current * 100 / total))
LOG "Progress: $percent% ($current/$total)"
```

### Section Headers

```bash
LOG ""
LOG "============================================"
LOG "=== Section Name ==="
LOG "============================================"
LOG ""
```

### Status Updates

```bash
# Track elapsed time
START_TIME=$(date +%s)

get_elapsed_time() {
    local now=$(date +%s)
    local elapsed=$((now - START_TIME))
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    printf "%02d:%02d" $mins $secs
}

LOG "Status: Running | Elapsed: $(get_elapsed_time)"
```

### Summary at End

```bash
LOG ""
LOG "============================================"
LOG "=== Summary ==="
LOG "============================================"
LOG "Items processed: $count"
LOG "Duration: $(get_elapsed_time)"
LOG green "Successes: $hits"
LOG ""
```

---

## Common Bugs to Avoid

### 1. Using `local` Outside Functions

```bash
# WRONG - will error
local var="value"

# RIGHT - only use local inside functions
my_function() {
    local var="value"
}
```

### 2. Forgetting to Initialize PIDs

```bash
# WRONG - cleanup will fail if variable undefined
cleanup() {
    kill $SOME_PID  # Error if never set
}

# RIGHT - initialize at top
SOME_PID=""
cleanup() {
    if [ -n "$SOME_PID" ]; then
        kill "$SOME_PID" 2>/dev/null
    fi
}
```

### 3. Heredoc Indentation

```bash
# WRONG - spaces become part of content
    cat > file <<EOF
    content
    EOF

# RIGHT - no indentation in heredoc
cat > file <<EOF
content
EOF
```

### 4. Special Characters in Config Files

```bash
# WRONG - breaks if SSID has quotes
ssid="$user_input"

# RIGHT - escape special chars
escape_string() {
    local str="$1"
    str="${str//\\/\\\\}"  # Escape backslashes first
    str="${str//\"/\\\"}"  # Then quotes
    echo "$str"
}
escaped=$(escape_string "$user_input")
```

### 5. Checking Process Status Wrong

```bash
# WRONG - returns true if PID var is set, not if running
if [ -n "$PID" ]; then

# RIGHT - check if process is actually running
if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
```

### 6. Not Quoting Variables

```bash
# WRONG - breaks on spaces/special chars
if [ $var = "value" ]; then

# RIGHT - always quote
if [ "$var" = "value" ]; then
```

---

## Configuration Patterns

### User Options at Top

```bash
# ============================================
# OPTIONS - Configure before running
# ============================================

# With comments explaining each
LOOTDIR=/root/loot/name      # Where to save results
TARGET=""                     # Leave empty for auto-detect
TIMEOUT=15                    # Seconds to wait
```

### Comma-Separated Lists

```bash
EXCLUDED_ITEMS="item1,item2,item3"

# Parse them
IFS=',' read -ra items <<< "$EXCLUDED_ITEMS"
for item in "${items[@]}"; do
    item=$(echo "$item" | tr -d ' ')  # Trim whitespace
    # Use $item
done
```

### Auto-Detection with Override

```bash
INTERFACE=""  # Leave empty for auto-detect

# In main script
if [ -z "$INTERFACE" ]; then
    LOG "Auto-detecting interface..."
    INTERFACE=$(detect_interface)
fi

if [ -z "$INTERFACE" ]; then
    ERROR_DIALOG "No interface found"
    exit 1
fi
```

---

## Checklist Before Submitting

- [ ] All PIDs initialized at top of script
- [ ] Trap set early, cleanup handles all PIDs
- [ ] All temp files cleaned up
- [ ] All dialogs check return codes properly
- [ ] CONFIRMATION_DIALOG has TWO case statements
- [ ] Variables quoted throughout
- [ ] Loot folder created with `mkdir -p`
- [ ] Version number updated
- [ ] Warning about authorized use included
- [ ] Tested cancel functionality
- [ ] Tested error conditions (missing files, no interface, etc.)

