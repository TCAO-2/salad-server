#!/bin/bash

# Stop the script on error.
set -e

# $1 -> Event
# $2 -> Array
# $3 -> Disk

ERRORS="Fail FailSpare DegradedArray SparesMissing TestMessage"

if echo $ERRORS | grep $1; then
    LEVEL="ERROR"
else
    LEVEL="WARN"
fi

/opt/salad-server/scripts/logger.sh "mdadm/${2}" "${1} ${2} ${3}" $LEVEL
