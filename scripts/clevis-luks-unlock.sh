#!/bin/bash

# Check if the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
    logger -p user.warning "Warning: This script must be run as root."
    echo "This script must be run as root." >&2
    exit 1
fi

# Define the device UUID (check /etc/crypttab)
UUID= enter id here

# Define the command to unlock the LUKS device using the UUID
COMMAND="/usr/bin/clevis-luks-unlock -d /dev/disk/by-uuid/$UUID"

# Function to get the device path from a UUID
get_device_path_by_uuid() {
    local uuid=$1
    local device_path="/dev/disk/by-uuid/$uuid"

    if [ -e "$device_path" ]; then
        # Resolve the symlink to get the actual device path
        readlink -f "$device_path"
    else
        echo "Device with UUID $uuid not found." >&2
        logger -p user.warning "Warning: Device with UUID $uuid not found."
        exit 1
    fi
}

# Get the device path using the UUID
DEVICE_PATH=$(get_device_path_by_uuid "$UUID")

# Print the device path
echo "Resolved device path: $DEVICE_PATH"

echo "Unlocking device with UUID $UUID ($DEVICE_PATH) using Clevis...."
logger -p user.info "Unlocking device with UUID $UUID ($DEVICE_PATH) using Clevis...."

# Try running the command
$COMMAND
RESULT=$?

# Check if the command was successful
if [ $RESULT -eq 0 ]; then
    # On success, log a warning-level message indicating success
    logger -p user.info "Successfully unlocked device with UUID $UUID ($DEVICE_PATH) using Clevis."
    exit 0
else
    # On failure, log a warning-level message with the return code
    logger -p user.warning "Warning: Failed to unlock device with UUID $UUID ($DEVICE_PATH) using Clevis. Return code: $RESULT"
    exit $RESULT
fi
