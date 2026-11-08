#!/bin/bash

# Loops through all SMART supported devices and checks their health.

# Stop the script on error.
set -e

LOGFILE_NAME="disk-health"
JSON_OUTPUT=1
ATTRIBUTES=1
SILENT=1

function logger {
    if [ $JSON_OUTPUT -eq 1 ]; then
        local message=$1
        local loglevel=$2
        /opt/salad-server/scripts/logger.sh "$LOGFILE_NAME" "$message" "$loglevel" 2>/dev/null \
        || echo "[${loglevel}] ${message}"
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
# Arguments
################################################################################

function usage {
    echo "Usage: check-all-disk-health.sh [-j] [-a] [-s] [-h]"
    echo "-j JSON output"
    echo "-a When -j is passed, also get all attributes"
    echo "-s Do not wake up disks from standby"
    echo "-h help"
    exit 0
}

json="{}"

while getopts "jash" arg; do
  case $arg in
    j) JSON_OUTPUT=0 ;;
    a) ATTRIBUTES=0 ;;
    s) SILENT=0 ;;
    h) usage ;;
    *) usage ;;
  esac
done





################################################################################
# Main
################################################################################

DEVICES=$(/sbin/smartctl --scan -j | jq -r .devices[].name)

for device in $DEVICES; do
    if [[ $device =~ ^/dev/nvme[0-9]+$ ]]; then
        for dev in /dev/nvmen[0-9]*; do
            [[ -b $dev ]] || continue
            [[ $(lsblk -dnro TYPE -- $dev) == disk ]] || continue
            device_udevadm=$dev
        done
    else
        device_udevadm=$device
    fi
    device_name=$(udevadm info --query=property --name=$device_udevadm | grep -Po '(?<=^ID_SERIAL=).*')
    if /sbin/hdparm -C $device | grep standby &> /dev/null; then standby=true
    else standby=false; fi
    json=$(echo $json | jq --arg device "$device" --arg device_name "$device_name" \
        --argjson standby "$standby" \
        '. += {$device_name:{device:$device,standby:$standby}}')
    if [ $SILENT -eq 0 ] && [[ "$standby" == "true" ]];then
        logger "Disk ${device} skipped (in standby)" "VERB"
    else
        if [ $JSON_OUTPUT -eq 0 ];then
            args=""
            if [ $JSON_OUTPUT -eq 0 ]; then args="$args -j"; fi
            if [ $ATTRIBUTES -eq 0 ]; then args="$args -a"; fi
            result=$(/opt/salad-server/scripts/check-disk-health.sh -d $device $args)
            json=$(echo $json | jq --arg device_name "$device_name" --argjson result "$result" \
                '.[$device_name] += $result')
        else
            /opt/salad-server/scripts/check-disk-health.sh -d $device || {
                # Crash only if it was a code execution error
                # (return code 1 is for disk KO only and is a running code normal execution).
                if [ $? -ne 1 ]; then
                    exit 10
                fi
            }
        fi
    fi
done
