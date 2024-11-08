#!/bin/bash

# Stop the script on error.
set -e





################################################################################
# Parameters
################################################################################

DISK_ID=$1 # Device ID as in /dev/disk/by-id





################################################################################
# Constants
################################################################################

# These attributes ID are critical i.e. non null values are considered as failures.
# https://en.wikipedia.org/wiki/Self-Monitoring,_Analysis_and_Reporting_Technology
CRITICALS=(
    5       # Reallocated sectors count.
    196     # Reallocation Event Count.
    197     # Current pending sector count.
    198     # Uncorrectable sector count.
)





################################################################################
# Main
################################################################################

function logger {
    message=$1
    loglevel=$2
    /opt/salad-server/scripts/logger.sh "disk-health" "$message" "$loglevel"
}



# Check if the disk is detected as /dev/sdX.
{
    readlink "/dev/disk/by-id/${DISK_ID}" > /dev/null
} || {
    logger "${DISK_ID} missing" "ERROR"; exit 10
}
DEVICE=$(realpath "/dev/disk/by-id/${DISK_ID}")
logger "${DISK_ID} detected as ${DEVICE}" "TRACE"



# Check if SMART is enabled.
if ! smartctl -i $DEVICE > /dev/null; then
    logger "${DISK_ID} SMART not enabled" "ERROR"; exit 11
fi



# Assumed overall health status.
healthy=true



# Check SMART status.
SMART_STATUS=$(smartctl -aj /dev/sda | jq .smart_status.passed)
if [ $SMART_STATUS = "true" ]; then
    logger "${DISK_ID} SMART status OK" "TRACE"
else
    logger "${DISK_ID} SMART status KO" "ERROR"
    healthy=false
fi



# Check SMART selftests.
SMART_SELF_ERR=$(smartctl -jl selftest $DEVICE | jq .ata_smart_self_test_log.standard.error_count_total)
if [ $SMART_SELF_ERR = "null" ] || [ $SMART_SELF_ERR -eq 0 ]; then
    logger "${DISK_ID} SMART selftest OK" "TRACE"
else
    logger "${DISK_ID} SMART selftest error count: ${SMART_SELF_ERR}" "ERROR"
    healthy=false
fi



# Check SMART attributes.
SMART_ATTRIBUTES=$(sudo smartctl -aj $DEVICE | jq .ata_smart_attributes.table)
for attribute in $(echo "$SMART_ATTRIBUTES" | jq -c '.[] | {id, name, worst, thresh, raw_value: .raw.value}'); do
    id=$(echo "$attribute" | jq '.id')
    name=$(echo "$attribute" | jq -r '.name')
    worst=$(echo "$attribute" | jq '.worst')
    thresh=$(echo "$attribute" | jq '.thresh')
    raw_value=$(echo "$attribute" | jq '.raw_value')
    if [ $worst -le $thresh ]; then
        logger "${DISK_ID} SMART bad attribute: ${id} ${name} ${worst} <= ${thresh}" "ERROR"
        healthy=false
    fi
    if [ $raw_value -ne 0 ] && [[ $(echo "${CRITICALS[@]}" | fgrep -w $id) ]]; then
        logger "${DISK_ID} SMART bad raw attribute: ${id} ${name} ${raw_value}" "ERROR"
        healthy=false
    fi
done



# Log the overall health status.
if [ $healthy == true ]; then
    logger "${DISK_ID} health OK" "INFO"
else
    logger "${DISK_ID} health KO" "ERROR"
fi
