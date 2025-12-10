#!/bin/bash

# Passing the device path e.g. /dev/sda
# or any symlink pointing to a device e.g. /dev/disk/by-id/nvme-WD_Blue_x .
#
# Checks SMART data for suspicious entries that could indicate an imminent faiure.
#
# Return code 0 if the disk health is OK.
# Return code 1 if the disk health is KO.
# Return code 1x if there was an execution error during the test.


# You can use "smartctl --scan" to list all supported devices.

# Stop the script on error.
set -e

function logger {
    local message=$1
    local loglevel=$2
    /opt/salad-server/scripts/logger.sh "disk-health" "$message" "$loglevel" \
    || echo "[${loglevel}] ${message}"
}

trap 'logger "Unexpected error at line ${LINENO}: \"${BASH_COMMAND}\" returns ${?}." "ERROR"' ERR





################################################################################
# Parameters
################################################################################

DEVICE=$1 # Disk device e.g. /dev/sda or /dev/disk/by-id/nvme-WD_Blue_x .





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

function check_status {
    local smart_report=$1
    local smart_status=$(echo $smart_report | jq .smart_status.passed)
    logger "${DEVICE} smart_status: ${smart_status}" "TRACE"
    if [ $smart_status = "true" ]; then
        logger "${DEVICE} SMART status OK" "VERB"
        return 0
    else
        logger "${DEVICE} SMART status KO" "ERROR"
        return 1
    fi
}

function ata_check_selftests {
    local smart_report=$1
    local lifetime_hours=$(echo "$smart_report" | jq .power_on_time.hours)
    logger "${DEVICE} lifetime_hours: ${lifetime_hours}" "TRACE"
    if echo "$smart_report" | jq .ata_smart_self_test_log.standard.table[] &> /dev/null; then
        local most_recent_extended_test=$(echo "$smart_report" \
        | jq '.ata_smart_self_test_log.standard.table[] | select(.type.string == "Extended offline") | .lifetime_hours' \
        | head -n 1)
    else
        # No selftest have already been run.
        local most_recent_extended_test=0
    fi
    logger "${DEVICE} most_recent_extended_test: ${most_recent_extended_test}" "TRACE"
    local delta=$((lifetime_hours - most_recent_extended_test))
    if [ -n "$most_recent_extended_test" ] && [ $delta -le $ATA_LATEST_SELFTEST ]; then
        logger "${DEVICE} last \"Extended offline\" selftest was ${delta} hours ago" "VERB"
    else
        logger "${DEVICE} last \"Extended offline\" selftest was ${delta} > ${ATA_LATEST_SELFTEST} hours ago" "WARN"
    fi
    local smart_self_err=$(echo $smart_report | jq .ata_smart_self_test_log.standard.error_count_total)
    # If a newer successful selftest is run, past failed selftest becomes outdated.
    local smart_self_err_outdated=$(echo $smart_report | jq .ata_smart_self_test_log.standard.error_count_outdated)
    if [ $smart_self_err = "null" ] || [ $smart_self_err -eq 0 ]; then
        logger "${DEVICE} SMART selftest OK" "VERB"
        return 0
    elif [ $smart_self_err -eq $smart_self_err_outdated ]; then
        # If there is only outdated selftest error (all new selftests are passing), only log a warning.
        logger "${DEVICE} SMART selftest error count (outdated): ${smart_self_err}" "WARN"
        return 0
    else
        logger "${DEVICE} SMART selftest error count: ${smart_self_err}" "ERROR"
        return 1
    fi
}

function ata_check_attributes {
    local smart_report=$1
    local _healthy=true
    local smart_attributes=$(echo $smart_report | jq .ata_smart_attributes.table)
    local smart_json=$(echo $smart_attributes | jq -c '.[] | {id, name, value, worst, thresh, raw_value: .raw.value}')
    for attribute in $smart_json; do
        logger "${DEVICE} SMART attribute ${attribute}" "TRACE"
        id=$(echo $attribute | jq '.id')
        name=$(echo $attribute | jq -r '.name')
        value=$(echo $attribute | jq '.value')
        worst=$(echo $attribute | jq '.worst')
        thresh=$(echo $attribute | jq '.thresh')
        raw_value=$(echo $attribute | jq '.raw_value')
        if [ $value -le $thresh ]; then
            logger "${DEVICE} SMART bad current attribute: ${id} ${name} ${worst} <= ${thresh}" "ERROR"
            _healthy="false"
        elif [ $worst -le $thresh ]; then
            # If the current value is above the threshold
            # but have been below previously, report a warning only.
            logger "${DEVICE} SMART bad worst attribute: ${id} ${name} ${worst} <= ${thresh}" "WARN"
        fi
        if [ $raw_value -ne 0 ] && [[ $(echo "${ATA_CRITICALS[@]}" | fgrep -w $id) ]]; then
            logger "${DEVICE} SMART bad raw.value attribute: ${id} ${name} ${raw_value}" "ERROR"
            _healthy="false"
        fi
    done
    if [ $_healthy = "true" ];then
        logger "${DEVICE} SMART attributes OK" "VERB"
        return 0
    else
        logger "${DEVICE} SMART attributes KO" "ERROR"
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
        logger "${DEVICE} SMART attribute {\"name\":\"${name}\",\"value\":${value}}" "TRACE"
        if [[ -n $critical_threshold && $value -gt $critical_threshold ]]; then
            logger "${DEVICE} SMART bad attribute: ${name} ${value} > ${critical_threshold}" "ERROR"
            _healthy=false
        elif [[ -n $warning_threshold && $value -gt $warning_threshold ]]; then
            logger "${DEVICE} SMART bad attribute: ${name} ${value} > ${warning_threshold}" "WARN"
        fi
    done
    if [ $_healthy = "true" ];then
        logger "${DEVICE} SMART attributes OK" "VERB"
        return 0
    else
        logger "${DEVICE} SMART attributes KO" "ERROR"
        return 1
    fi
}





################################################################################
# Main
################################################################################

# Checks that we are using the root account.
if ! [ "$(whoami)" == "root" ]; then
    logger "Must be root for using smartctl." "ERROR"; exit 12
fi

# Check that the disk exists.
DEVICES=$(/sbin/smartctl --scan -j | jq -r .devices[].name)
if ! [[ ${DEVICES[@]} =~ $(realpath "${DEVICE}") ]]; then
    logger "${DEVICE} is missing or not a device" "ERROR"; exit 11
fi

# SMART overview.
{
    SMART_REPORT=$(/sbin/smartctl -aj $DEVICE)
    # Get the disk model name and S/N for physical identification.
    MODEL_NAME=$(echo $SMART_REPORT | jq -r .model_name)
    SERIAL_NUMBER=$(echo $SMART_REPORT | jq -r .serial_number)
    # Get the disk protocol (ATA or NVMe).
    DISK_PROTOCOL=$(echo $SMART_REPORT | jq -r .device.protocol)
} || {
    logger "${DEVICE} SMART not enabled" "ERROR"; exit 12
}

# Overview entry log.
logger "${DEVICE} detected as ${MODEL_NAME} ${SERIAL_NUMBER} ${DISK_PROTOCOL}" "VERB"



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
    logger "${DEVICE} is using an unknown protocol ${DISK_PROTOCOL}" "ERROR"; exit 13
fi

if [ $healthy = "true" ]; then
    logger "${DEVICE} health OK" "INFO"
else
    logger "${DEVICE} health KO" "ERROR"
    exit 1
fi
