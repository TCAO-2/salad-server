#!/bin/bash

# Stop the script on error.
set -e

LOGFILE_NAME="disk-usage"

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

# Get physical file system usage.
file_sys_usage="df -x devtmpfs -x tmpfs -x overlay --output=pcent,target"

# Loop over line results of format "use% target" looking for threshold exceeding.
$file_sys_usage | grep -v "^Use%" | while read line; do
    target=$(echo $line | grep -o "[^ ]*$")
    usage=$(echo $line | grep -o "^[^%]*")
    log_filename=$(echo $target | sed 's/\//%/g')
    if [ $usage -gt $THRESHOLD_ERROR ]; then
        logger "${target} usage ${usage}% over ${THRESHOLD_ERROR}%." "ERROR" $log_filename
    elif [ $usage -gt $THRESHOLD_WARN ]; then
        logger "${target} usage ${usage}% over ${THRESHOLD_WARN}%." "WARN" $log_filename
    else
        logger "${target} usage ${usage}%" "INFO" $log_filename
    fi
done
