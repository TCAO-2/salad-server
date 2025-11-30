#!/bin/bash

# Loops through all SMART supported devices and checks their health.

# Stop the script on error.
set -e





################################################################################
# Main
################################################################################

DEVICES=$(smartctl --scan -j | jq -r .devices[].name)

for device in $DEVICES; do
    /opt/salad-server/scripts/check-disk-health.sh $device || {
        # Crash only if it was a code execution error
        # (return code 1 is for disk KO only and is a running code normal execution).
        if [ $? -ne 1 ]; then
            exit 10
        fi
    }
done
