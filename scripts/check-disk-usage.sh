#!/bin/bash

# Stop the script on error.
set -e

LOGFILE_NAME="disk-usage"

function logger {
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
}

trap 'logger "Unexpected error at line ${LINENO}: \"${BASH_COMMAND}\" returns ${?}." "ERROR"' ERR





################################################################################
# Constants
################################################################################

THRESHOLD_WARN=70
THRESHOLD_ERROR=90
VALID_ARGUMENTS="source target pcent size avail used"





################################################################################
# Arguments
################################################################################

function usage {
    echo "Usage: check-disk-usage.sh [-j] [-p] <str> [-a] [-h]"
    echo "-j JSON output"
    echo "-p <str> path of the filesystem"
    echo "-a <str> argument in [source,target,pcent,size,avail,used], used with -p"
    echo "-h help"
    exit 0
}

json=""
path=""
argument=""

while getopts "jp:a:h" arg; do
  case $arg in
    j) json="{}" ;;
    p) path=$OPTARG ;;
    a) argument=$OPTARG ;;
    h) usage ;;
    *) usage ;;
  esac
done





################################################################################
# Pre-checks
################################################################################

if [[ "$path" != "" ]] && ! [[ -d "$path" ]]; then
    # Check the filesystem exists if passed to avoid code injection.
    echo "\"$path\" path does not exist."
    exit 1
fi

if [[ "$argument" != "" ]] && ! echo "$VALID_ARGUMENTS" | grep -qw "$argument"; then
    # Check the argument exists if passed to avoid code injection.
    echo "Bad argument: \"$argument\" must be in [source,target,pcent,size,avail]."
    exit 1
fi





################################################################################
# Main
################################################################################

file_sys_usage="df -B 1 --output=source,target,pcent,size,avail,used $path"

# Loop over line results looking for threshold exceeding.
# We keep only results whith a source starting with "/dev" to keep only physical ones.
$file_sys_usage | grep '^/dev.*' | tr -s " " | ( while read line; do
    source=$(echo $line | cut -d " " -f 1)
    target=$(echo $line | cut -d " " -f 2)
    pcent=$(echo $line | cut -d " " -f 3 | sed 's/.\{1\}$//')
    size=$(echo $line | cut -d " " -f 4)
    avail=$(echo $line | cut -d " " -f 5)
    used=$(echo $line | cut -d " " -f 6)
    if [[ "$path" != "" ]] && [[ "$argument" != "" ]]; then
        echo ${!argument}
        exit 0
    fi
    log_filename=$(echo $target | sed 's/\//%/g')
    if [[ $json != "" ]]; then
        json=$(echo $json | jq --arg target $target --arg source $source --argjson pcent $pcent \
            --argjson size $size --argjson avail $avail --argjson used $used  \
            '. += {($target):{source:$source,pcent:$pcent,size:$size,avail:$avail,used:$used}}')
    else
        if [ $pcent -gt $THRESHOLD_ERROR ]; then
            logger "${target} usage ${pcent}% over ${THRESHOLD_ERROR}%." "ERROR" $log_filename
        elif [ $pcent -gt $THRESHOLD_WARN ]; then
            logger "${target} usage ${pcent}% over ${THRESHOLD_WARN}%." "WARN" $log_filename
        else
            logger "${target} usage ${pcent}%" "INFO" $log_filename
        fi
    fi
done
if [[ $json != "" ]]; then
    echo $json
fi )
