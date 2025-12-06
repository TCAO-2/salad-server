#!/bin/bash

# Generate a report to check data integrity across backups
# using xxhash a non-cryptographic fast hash algorithm.
#
# Reports lines are of format:
#     hash timestamp relative/path/filename

# Stop the script on error.
set -e

function logger {
    local message=$1
    local loglevel=$2
    /opt/salad-server/scripts/logger.sh "create-data-integrity-report" "$message" "$loglevel" \
    || echo "[${loglevel}] ${message}"
}

trap 'logger "Unexpected error at line ${LINENO}: \"${BASH_COMMAND}\" returns ${?}." "ERROR"' ERR





################################################################################
# Parameters
################################################################################

function usage {
    echo "Usage:
    ./create-data-integrity-report.sh -d <src dir> -f <report file>"
}

while getopts ":d:f:h" opt; do
    case $opt in
    d)
        SRC_DIR=$OPTARG
        ;;
    f)
        FILE_REPORT=$OPTARG
        ;;
    h | *)
        usage
        exit 10
        ;;
    esac
done

if [[ -z $SRC_DIR ]] || [[ -z $FILE_REPORT ]]; then
    >&2 echo "-d (source directory) and -f (report file) are required."
    usage
fi





################################################################################
# Main
################################################################################

report_file=$(realpath "$FILE_REPORT")
if ls "$report_file" &> /dev/null; then
    >&2 echo "${report_file} already exists!"
    exit 11
fi

total_size=$(du -sb "$SRC_DIR" | awk '{print $1}')
processed_size=0
last_logged_percent=0

cd "$SRC_DIR" || exit

# Use find with -print0 to handle special characters in filenames
find . -type f -print0 | while IFS= read -r -d '' filepath; do
    # Get the timestamp and filesize using stat with -c for a single line output
    stat_output=$(stat -c "%Y %s" "$filepath")
    timestamp=$(echo "$stat_output" | awk '{print $1}')
    filesize=$(echo "$stat_output" | awk '{print $2}')

    # Compute the xxhash
    hash=$(xxh128sum "$filepath" | awk '{print $1}')
    echo "$hash $timestamp ${filepath#./}" >> "$report_file"

    # Log the current file as TRACE
    logger "${filepath#./}" "TRACE"

    # Update the processed size and calculate the current percentage
    processed_size=$((processed_size + filesize))
    current_percent=$((processed_size * 100 / total_size))

    # Log every percent advancement as INFO
    if (( current_percent > last_logged_percent )); then
        logger "${current_percent}% completed" "INFO"
        last_logged_percent=$current_percent
    fi
done
