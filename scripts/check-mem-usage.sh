#!/bin/bash

# Stop the script on error.
set -e

LOGFILE_NAME="mem-usage"

function logger {
    local message=$1
    local loglevel=$2
    local filename=$3
    if [ -z "${filename}" ]; then
        /opt/salad-server/scripts/logger.sh "$LOGFILE_NAME" "$message" "$loglevel" \
        || echo "[${loglevel}] ${message}"
    else
        /opt/salad-server/scripts/logger.sh "${LOGFILE_NAME}/${filename}" "$message" "$loglevel" \
        || echo "[${loglevel}] ${message}"
    fi
}

trap 'logger "Unexpected error at line ${LINENO}: \"${BASH_COMMAND}\" returns ${?}." "ERROR"' ERR





################################################################################
# Constants
################################################################################

THRESHOLD_WARN=70
THRESHOLD_ERROR=90





################################################################################
# Main
################################################################################

# Loop over line results looking for threshold exceeding.
free | grep -v "total" | while read line; do
    target=$(echo $line | grep -o "^[^:]*")
    usage=$(echo $line | awk '{printf "%.0f\n", ($3/$2)*100}')
    if [ $usage -gt $THRESHOLD_ERROR ]; then
        logger "${target} usage ${usage}% over ${THRESHOLD_ERROR}%." "ERROR" "$target"
    elif [ $usage -gt $THRESHOLD_WARN ]; then
        logger "${target} usage ${usage}% over ${THRESHOLD_WARN}%." "WARN" "$target"
    else
        logger "${target} usage ${usage}%" "INFO" "$target"
    fi
done
