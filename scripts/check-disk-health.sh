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

DEVICE_NAME=""
LOGFILE_NAME="disk-health"
JSON_OUTPUT=1
ATTRIBUTES=1

function logger {
    if [ $JSON_OUTPUT -eq 1 ]; then
        local message=$1
        local loglevel=$2
        local filename=$3
        if [ -z "${filename}" ]; then
            /opt/salad-server/scripts/logger.sh "$LOGFILE_NAME" "$message" "$loglevel" 2>/dev/null \
            || echo "[${loglevel}] ${message}"
        else
            /opt/salad-server/scripts/logger.sh "${LOGFILE_NAME}/${filename}" "$message" "$loglevel" 2>/dev/null \
            || echo "[${loglevel}] ${message}"
        fi
    fi
}

function json_output {
    if [ $JSON_OUTPUT -eq 0 ]; then
        echo $json
    fi
}

trap 'logger "Unexpected error at line ${LINENO}: \"${BASH_COMMAND}\" returns ${?}." "ERROR"' ERR
trap json_output EXIT





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
# Arguments
################################################################################

function usage {
    echo "Usage: check-disk-health.sh -d <str> [-j] [-a] [-h]"
    echo "-d device e.g. /dev/sda or /dev/disk/by-id/nvme-WD_Blue_x"
    echo "-j JSON output"
    echo "-a When -j is passed, also get all attributes"
    echo "-h help"
    exit 0
}

json="{}"
warning="false" # Global warning indicator for json output (at least one WARN log).

while getopts "d:jah" arg; do
  case $arg in
    d) DEVICE=$OPTARG ;;
    j) JSON_OUTPUT=0 ;;
    a) ATTRIBUTES=0 ;;
    h) usage ;;
    *) usage ;;
  esac
done

if ! [ -v DEVICE ]; then
    echo "Missing argument -d <str> (device)"; usage
fi





################################################################################
# Helper functions
################################################################################

function check_status {
    local smart_report=$1
    local smart_status=$(echo $smart_report | jq .smart_status.passed)
    logger "Disk ${DEVICE} smart_status: ${smart_status}" "TRACE"
    if [ $smart_status = "true" ]; then
        logger "Disk ${DEVICE} SMART status OK" "VERB"
        return 0
    else
        logger "Disk ${DEVICE} SMART status KO" "ERROR"
        return 1
    fi
}

function ata_check_selftests {
    local smart_report=$1
    local lifetime_hours=$(echo "$smart_report" | jq .power_on_time.hours)
    local temperature=$(echo "$smart_report" | jq .temperature.current)
    logger "Disk ${DEVICE} lifetime_hours: ${lifetime_hours}" "TRACE"
    if echo "$smart_report" | jq .ata_smart_self_test_log.standard.table[] &> /dev/null; then
        local most_recent_extended_test=$(echo "$smart_report" \
        | jq '.ata_smart_self_test_log.standard.table[] | select((.type.string == "Extended offline") and (.status.string | startswith("Completed"))) | .lifetime_hours' \
        | head -n 1)
    else
        # No selftest have already been run.
        local most_recent_extended_test=0
    fi
    logger "Disk ${DEVICE} most_recent_extended_test: ${most_recent_extended_test}" "TRACE"
    local delta=$((lifetime_hours - most_recent_extended_test))
    if [ -n "$most_recent_extended_test" ] && [ $delta -le $ATA_LATEST_SELFTEST ]; then
        logger "Disk ${DEVICE} last \"Extended offline\" selftest was ${delta} hours ago" "VERB"
    else
        logger "Disk ${DEVICE} last \"Extended offline\" selftest was ${delta} > ${ATA_LATEST_SELFTEST} hours ago" "WARN"; warning="true"
    fi
    local smart_self_err=$(echo $smart_report | jq .ata_smart_self_test_log.standard.error_count_total)
    # If a newer successful selftest is run, past failed selftest becomes outdated.
    local smart_self_err_outdated=$(echo $smart_report | jq .ata_smart_self_test_log.standard.error_count_outdated)
    json=$(echo $json | jq --argjson temperature $temperature --argjson power_on_hours $lifetime_hours --argjson ata_last_test_hours $delta \
        --argjson ata_test_error_count_total $smart_self_err --argjson ata_test_error_count_outdated $smart_self_err_outdated \
        '. += {temperature:$temperature,power_on_hours:$power_on_hours,ata_last_test_hours:$ata_last_test_hours,ata_test_error_count_total:$ata_test_error_count_total,ata_test_error_count_outdated:$ata_test_error_count_outdated}')
    if [ $smart_self_err = "null" ] || [ $smart_self_err -eq 0 ]; then
        logger "Disk ${DEVICE} SMART selftest OK" "VERB"
        return 0
    elif [ $smart_self_err -eq $smart_self_err_outdated ]; then
        # If there is only outdated selftest error (all new selftests are passing), only log a warning.
        logger "Disk ${DEVICE} SMART selftest error count (outdated): ${smart_self_err}" "WARN"; warning="true"
        return 0
    else
        logger "Disk ${DEVICE} SMART selftest error count: ${smart_self_err}" "ERROR"
        return 1
    fi
}

function ata_check_attributes {
    local smart_report=$1
    local _healthy=true
    local smart_attributes=$(echo $smart_report | jq .ata_smart_attributes.table)
    local smart_json=$(echo $smart_attributes | jq -c '.[] | {id, name, value, worst, thresh, raw_value: .raw.value}')
    if [ $ATTRIBUTES -eq 0 ]; then
        json=$(echo $json | jq '. += {ata_attributes:{}}')
    fi
    for attribute in $smart_json; do
        logger "Disk ${DEVICE} SMART attribute ${attribute}" "TRACE"
        id=$(echo $attribute | jq '.id')
        name=$(echo $attribute | jq -r '.name')
        value=$(echo $attribute | jq '.value')
        worst=$(echo $attribute | jq '.worst')
        thresh=$(echo $attribute | jq '.thresh')
        raw_value=$(echo $attribute | jq '.raw_value')
        if [ $ATTRIBUTES -eq 0 ]; then
            json=$(echo $json | jq --arg id $id --arg name "$name" --argjson value $value \
                --argjson worst $worst --argjson thresh $thresh --argjson raw_value $raw_value \
                '.ata_attributes += {$id:{name:$name,value:$value,worst:$worst,thresh:$thresh,raw_value:$raw_value}}')
        fi
        if [ $value -le $thresh ]; then
            logger "Disk ${DEVICE} SMART bad current attribute: ${id} ${name} ${worst} <= ${thresh}" "ERROR"
            _healthy="false"
        elif [ $worst -le $thresh ]; then
            # If the current value is above the threshold
            # but have been below previously, report a warning only.
            logger "Disk ${DEVICE} SMART bad worst attribute: ${id} ${name} ${worst} <= ${thresh}" "WARN"; warning="true"
        fi
        if [ $raw_value -ne 0 ] && [[ $(echo "${ATA_CRITICALS[@]}" | fgrep -w $id) ]]; then
            logger "Disk ${DEVICE} SMART bad raw.value attribute: ${id} ${name} ${raw_value}" "ERROR"
            _healthy="false"
        fi
    done
    if [ $_healthy = "true" ];then
        logger "Disk ${DEVICE} SMART attributes OK" "VERB"
        return 0
    else
        logger "Disk ${DEVICE} SMART attributes KO" "ERROR"
        return 1
    fi
}

function ata_check_errors {
    local smart_report=$1
    local smart_errors_count=$(echo $smart_report | jq .ata_smart_error_log.summary.count)
    json=$(echo $json | jq --argjson ata_errors_count $smart_errors_count \
        '. += {ata_errors_count:$ata_errors_count}')
    if [[ $smart_errors_count -gt 0 ]]; then
        logger "Disk ${DEVICE} SMART errors count: ${smart_errors_count}" "WARN"; warning="true"
    else
        logger "Disk ${DEVICE} SMART errors count: ${smart_errors_count}" "VERB"
    fi
}

function nvme_check_attributes {
    local smart_report=$1
    local _healthy=true
    local lifetime_hours=$(echo "$smart_report" | jq .power_on_time.hours)
    local temperature=$(echo "$smart_report" | jq .temperature.current)
    logger "Disk ${DEVICE} lifetime_hours: ${lifetime_hours}" "TRACE"
    local smart_attributes=$(echo $smart_report | jq .nvme_smart_health_information_log)
    for name in $(echo "$smart_attributes" | jq -r 'keys[]'); do
        local value=$(echo "$smart_attributes" | jq -r ".$name")
        local warning_threshold=${NVME_WARNINGS[$name]}
        local critical_threshold=${NVME_CRITICALS[$name]}
        logger "Disk ${DEVICE} SMART attribute {\"name\":\"${name}\",\"value\":${value}}" "TRACE"
        if [[ -n $critical_threshold && $value -gt $critical_threshold ]]; then
            logger "Disk ${DEVICE} SMART bad attribute: ${name} ${value} > ${critical_threshold}" "ERROR"
            _healthy=false
        elif [[ -n $warning_threshold && $value -gt $warning_threshold ]]; then
            logger "Disk ${DEVICE} SMART bad attribute: ${name} ${value} > ${warning_threshold}" "WARN"; warning="true"
        fi
    done
    json=$(echo $json | jq --argjson temperature $temperature --argjson power_on_hours $lifetime_hours \
        '. += {temperature:$temperature,power_on_hours:$power_on_hours}')
    if [ $_healthy = "true" ];then
        logger "Disk ${DEVICE} SMART attributes OK" "VERB"
        return 0
    else
        logger "Disk ${DEVICE} SMART attributes KO" "ERROR"
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
    logger "Disk ${DEVICE} is missing or not a device" "ERROR"; exit 11
fi



healthy="true"

# SMART overview.
{
    SMART_REPORT=$(/sbin/smartctl -aj $DEVICE)
    SMART_REPORT_RETURN_CODE=$?
    logger "Disk ${DEVICE} SMART_REPORT_RETURN_CODE=${SMART_REPORT_RETURN_CODE}" "TRACE"
    if [[ SMART_REPORT_RETURN_CODE -eq 0 ]]; then
        logger "Disk ${DEVICE} smartctl ran without error" "VERB"
    fi
    if (( SMART_REPORT_RETURN_CODE & 1 )); then
        logger "Disk ${DEVICE} smartctl command line parse error" "ERROR"; exit 12
    fi
    if (( SMART_REPORT_RETURN_CODE & 2 )); then
        logger "Disk ${DEVICE} smartctl device open failed" "ERROR"; exit 12
    fi
    if (( SMART_REPORT_RETURN_CODE & 4 )); then
        logger "Disk ${DEVICE} smartctl SMART command faile" "ERROR"; exit 12
    fi
    if (( SMART_REPORT_RETURN_CODE & 8 )); then
        logger "Disk ${DEVICE} smartctl status check returned DISK FAILING" "ERROR"; healthy="false"
    fi
    if (( SMART_REPORT_RETURN_CODE & 16 )); then
        logger "Disk ${DEVICE} smartctl found prefail attributes <= threshold" "ERROR"; healthy="false"
    fi
    if (( SMART_REPORT_RETURN_CODE & 32 )); then
        logger "Disk ${DEVICE} smartctl found prefail attributes <= threshold in the past" "WARN"; warning="true"
    fi
    if (( SMART_REPORT_RETURN_CODE & 64 )); then
        logger "Disk ${DEVICE} smartctl found device errors in logs" "WARN"; warning="true"
    fi
    if (( SMART_REPORT_RETURN_CODE & 128 )); then
        logger "Disk ${DEVICE} smartctl found selftest errors" "ERROR"; healthy="false"
    fi
    # Get the disk model name and S/N for physical identification.
    MODEL_NAME=$(echo $SMART_REPORT | jq -r .model_name)
    SERIAL_NUMBER=$(echo $SMART_REPORT | jq -r .serial_number)
    # Get the disk protocol (ATA or NVMe).
    DISK_PROTOCOL=$(echo $SMART_REPORT | jq -r .device.protocol)
} || {
    logger "Disk ${DEVICE} SMART not enabled" "ERROR"; exit 12
}

json=$(echo $json | jq --arg model_name "$MODEL_NAME" \
    --arg serial_number "$SERIAL_NUMBER" --arg protocol "$DISK_PROTOCOL" \
    '. += {model_name:$model_name,serial_number:$serial_number,protocol:$protocol}')
DEVICE_NAME=$(echo "${MODEL_NAME} ${SERIAL_NUMBER} ${DISK_PROTOCOL}" | sed 's/[^a-zA-Z0-9]/_/g')

# Overview entry log.
logger "Disk ${DEVICE} detected as ${DEVICE_NAME}" "VERB"



# SMART checks.
if [ $DISK_PROTOCOL == "ATA" ]; then
    check_status            "$SMART_REPORT" || healthy="false"
    ata_check_selftests     "$SMART_REPORT" || healthy="false"
    ata_check_attributes    "$SMART_REPORT" || healthy="false"
    ata_check_errors        "$SMART_REPORT"
elif [ $DISK_PROTOCOL == "NVMe" ]; then
    check_status            "$SMART_REPORT" || healthy="false"
    # There are no selftest for NVMe devices, everything is managed by the controller.
    nvme_check_attributes   "$SMART_REPORT" || healthy="false"
else
    logger "Disk ${DEVICE} is using an unknown protocol ${DISK_PROTOCOL}" "ERROR"; exit 13
fi

json=$(echo $json | jq --argjson warning $warning --argjson healthy $healthy \
    '. += {warning:$warning,healthy:$healthy}')

if [ $healthy = "true" ]; then
    logger "Disk ${DEVICE} health OK" "INFO"
else
    logger "Disk ${DEVICE} health KO" "ERROR"
    exit 1
fi
