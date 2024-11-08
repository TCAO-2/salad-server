#!/bin/bash

# Stop the script on error.
set -e





################################################################################
# Constants
################################################################################

THRESHOLD_WARN=70
THRESHOLD_ERROR=90





################################################################################
# Main
################################################################################

function logger {
    message=$1
    loglevel=$2
    /opt/salad-server/scripts/logger.sh "disk-usage" "$message" "$loglevel"
}

# Get physical file system usage.
file_sys_usage="df -x devtmpfs -x tmpfs -x overlay --output=pcent,target"

# Loop over line results of format "use% target" looking for threshold exceeding.
$file_sys_usage | grep -v "^Use%" | while read line; do
    target=$(echo $line | grep -o "[^ ]*$")
    usage=$(echo $line | grep -o "^[^%]*")
    if [ $usage -gt $THRESHOLD_ERROR ]; then
        logger "${target} usage ${usage}% over ${THRESHOLD_ERROR}%." "ERROR"
    elif [ $usage -gt $THRESHOLD_WARN ]; then
        logger "${target} usage ${usage}% over ${THRESHOLD_WARN}%." "WARN"
    else
        logger "${target} usage ${usage}%" "INFO"
    fi
done
