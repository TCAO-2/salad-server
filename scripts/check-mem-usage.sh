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
    /opt/salad-server/scripts/logger.sh "mem-usage" "$message" "$loglevel"
}

# Loop over line results looking for threshold exceeding.
free | grep -v "total" | while read line; do
    target=$(echo $line | grep -o "^[^:]*")
    usage=$(echo $line | awk '{printf "%.0f\n", ($3/$2)*100}')
    if [ $usage -gt $THRESHOLD_ERROR ]; then
        logger "${target} usage ${usage}% over ${THRESHOLD_ERROR}%." "ERROR"
    elif [ $usage -gt $THRESHOLD_WARN ]; then
        logger "${target} usage ${usage}% over ${THRESHOLD_WARN}%." "WARN"
    else
        logger "${target} usage ${usage}%" "INFO"
    fi
done
