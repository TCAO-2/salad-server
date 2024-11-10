#!/bin/bash

# Passing the disk ID as in /dev/disk/by-id ,
# checks SMART data for suspicious entries that could indicate an imminent faiure.

# Stop the script on error.
set -e





################################################################################
# Parameters
################################################################################

DISK_ID=$1 # Disk ID as in /dev/disk/by-id





################################################################################
# Constants
################################################################################

# These ID are critical i.e. non null raw values are considered as failures.
# https://en.wikipedia.org/wiki/Self-Monitoring,_Analysis_and_Reporting_Technology
ATA_CRITICALS=(
    5       # Reallocated sectors count.
    196     # Reallocation Event Count.
    197     # Current pending sector count.
    198     # Uncorrectable sector count.
)

# In hours, report an error if the last "Extended offline" selftest is older.
ATA_LATEST_SELFTEST=1000

# Metrics over these thresholds will trigger a warning.
declare -A NVME_WARNINGS=(
    [percentage_used]=90    # Percentage of drive life used.
    [warning_temp_time]=0   # Time in minutes running >= warning temperature.
)

# Metrics over these thresholds will trigger an error.
declare -A NVME_CRITICALS=(
    [critical_warning]=0    # Word composed of multiple error bits.
    [percentage_used]=99    # Percentage of drive life used.
    [media_errors]=0        # Unrecovered data integrity error occurences.
    [critical_comp_time]=0  # Time in minutes running >= critical temperature.
)





################################################################################
# Helper functions
################################################################################

function logger {
    message=$1
    loglevel=$2
    /opt/salad-server/scripts/logger.sh "disk-health" "$message" "$loglevel"
}

function check_status {
    local smart_report=$1
    local smart_status=$(echo $smart_report | jq .smart_status.passed)
    logger "${DISK_ID} smart_status: ${smart_status}" "TRACE"
    if [ $smart_status = "true" ]; then
        logger "${DISK_ID} SMART status OK" "VERB"
        return 0
    else
        logger "${DISK_ID} SMART status KO" "ERROR"
        return 1
    fi
}

function ata_check_selftests {
    local smart_report=$1
    local lifetime_hours=$(echo "$smart_report" | jq .power_on_time.hours)
    logger "${DISK_ID} lifetime_hours: ${lifetime_hours}" "TRACE"
    if echo "$smart_report" | jq .ata_smart_self_test_log.standard.table[] &> /dev/null; then
        local most_recent_extended_test=$(echo "$smart_report" \
        | jq '.ata_smart_self_test_log.standard.table[] | select(.type.string == "Extended offline") | .lifetime_hours' \
        | head -n 1)
    else
        # No selftest have already been run.
        local most_recent_extended_test=0
    fi
    logger "${DISK_ID} most_recent_extended_test: ${most_recent_extended_test}" "TRACE"
    local delta=$((lifetime_hours - most_recent_extended_test))
    if [ -n "$most_recent_extended_test" ] && [ $delta -le $ATA_LATEST_SELFTEST ]; then
        logger "${DISK_ID} last \"Extended offline\" selftest was ${delta} hours ago" "VERB"
    else
        logger "${DISK_ID} last \"Extended offline\" selftest was ${delta} > ${ATA_LATEST_SELFTEST} hours ago" "WARN"
    fi
    local smart_self_err=$(echo $smart_report | jq .ata_smart_self_test_log.standard.error_count_total)
    if [ $smart_self_err = "null" ] || [ $smart_self_err -eq 0 ]; then
        logger "${DISK_ID} SMART selftest OK" "VERB"
        return 0
    else
        logger "${DISK_ID} SMART selftest error count: ${smart_self_err}" "ERROR"
        return 1
    fi
}

function ata_check_attributes {
    local smart_report=$1
    local _healthy=true
    local smart_attributes=$(echo $smart_report | jq .ata_smart_attributes.table)
    local smart_json=$(echo $smart_attributes | jq -c '.[] | {id, name, value, worst, thresh, raw_value: .raw.value}')
    for attribute in $smart_json; do
        logger "${DISK_ID} SMART attribute ${attribute}" "TRACE"
        id=$(echo $attribute | jq '.id')
        name=$(echo $attribute | jq -r '.name')
        value=$(echo $attribute | jq '.value')
        worst=$(echo $attribute | jq '.worst')
        thresh=$(echo $attribute | jq '.thresh')
        raw_value=$(echo $attribute | jq '.raw_value')
        if [ $value -le $thresh ]; then
            logger "${DISK_ID} SMART bad current attribute: ${id} ${name} ${worst} <= ${thresh}" "ERROR"
            _healthy="false"
        elif [ $worst -le $thresh ]; then
            # If the current value is above the threshold
            # but have been below previously, report a warning only.
            logger "${DISK_ID} SMART bad worst attribute: ${id} ${name} ${worst} <= ${thresh}" "WARN"
        fi
        if [ $raw_value -ne 0 ] && [[ $(echo "${ATA_CRITICALS[@]}" | fgrep -w $id) ]]; then
            logger "${DISK_ID} SMART bad raw.value attribute: ${id} ${name} ${raw_value}" "ERROR"
            _healthy="false"
        fi
    done
    if [ $_healthy = "true" ];then
        logger "${DISK_ID} SMART attributes OK" "VERB"
        return 0
    else
        logger "${DISK_ID} SMART attributes KO" "ERROR"
        return 1
    fi
}

function nvme_check_attributes {
    local smart_report=$1
    local _healthy=true
    local smart_attributes=$(echo $smart_report | jq .nvme_smart_health_information_log)
    for name in $(echo "$smart_attributes" | jq -r 'keys[]'); do
        local value=$(echo "$smart_attributes" | jq -r ".$name")
        local warning_threshold=${NVME_WARNINGS[$name]}
        local critical_threshold=${NVME_CRITICALS[$name]}
        logger "${DISK_ID} SMART attribute {\"name\":\"${name}\",\"value\":${value}}" "TRACE"
        if [[ -n $critical_threshold && $value -gt $critical_threshold ]]; then
            logger "${DISK_ID} SMART bad attribute: ${name} ${value} > ${critical_threshold}" "ERROR"
            _healthy=false
        elif [[ -n $warning_threshold && $value -gt $warning_threshold ]]; then
            logger "${DISK_ID} SMART bad attribute: ${name} ${value} > ${warning_threshold}" "WARN"
        fi
    done
    if [ $_healthy = "true" ];then
        logger "${DISK_ID} SMART attributes OK" "VERB"
        return 0
    else
        logger "${DISK_ID} SMART attributes KO" "ERROR"
        return 1
    fi
}





################################################################################
# Main
################################################################################

# Disk detection.
DEVICE="/dev/disk/by-id/${DISK_ID}"

{
    readlink $DEVICE > /dev/null
} || {
    logger "${DISK_ID} missing" "ERROR"; exit 10
}
REALPATH=$(realpath "/dev/disk/by-id/${DISK_ID}")
logger "${DISK_ID} detected as ${REALPATH}" "VERB"



# SMART overview.
{
    SMART_REPORT=$(smartctl -aj $DEVICE)
    # Get the disk protocol (ATA or NVMe).
    DISK_PROTOCOL=$(echo $SMART_REPORT | jq -r .device.protocol)
} || {
    logger "${DISK_ID} SMART not enabled" "ERROR"; exit 11
}
logger "${DISK_ID} protocol is ${DISK_PROTOCOL}" "VERB"



# SMART checks.
healthy="true"

if [ $DISK_PROTOCOL == "ATA" ]; then
    check_status            "$SMART_REPORT" || healthy="false"
    ata_check_selftests     "$SMART_REPORT" || healthy="false"
    ata_check_attributes    "$SMART_REPORT" || healthy="false"
elif [ $DISK_PROTOCOL == "NVMe" ]; then
    check_status            "$SMART_REPORT" || healthy="false"
    # There are no selftest for NVMe devices, everything is managed by the controller.
    nvme_check_attributes   "$SMART_REPORT" || healthy="false"
else
    logger "${DISK_ID} is using an unknown protocol ${DISK_PROTOCOL}" "ERROR"; exit 12
fi

if [ $healthy = "true" ]; then
    logger "${DISK_ID} health OK" "INFO"
else
    logger "${DISK_ID} health KO" "ERROR"
fi
